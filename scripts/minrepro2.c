// minrepro2.c — v2 of the alt-tab freeze reproducer: mirrors CS2's traced sequence faithfully.
// v1 (minrepro.c) proved create-swapchain-while-minimized ALONE does not reproduce on a plain
// windowed window. v2 adds the ingredients v1 lacked, straight from the WINEDEBUG trace of the
// real freeze (docs/dxmt-bugs/DRAFT-focus-loss-freeze.md § Live-freeze measurements):
//   - swapchain #1 is EXCLUSIVE FULLSCREEN (Windowed=FALSE, 1920x1080, FLIP_SEQUENTIAL) — DXMT
//     runs EnterFullscreenMode at creation (the boot "Setting display mode" line)
//   - the app self-minimizes while the fullscreen state is still held (no SetFullscreenState(FALSE))
//   - swapchain #2 is created on the same HWND while minimized (client rect empty), Windowed=TRUE
//   - on restore, fullscreen is re-asserted through DXGI (SetFullscreenState(TRUE) + ResizeTarget →
//     exactly the double "Setting display mode" the trace shows per restore cycle)
//   - both swapchains stay alive; presents then target #2 (cycling) and afterwards #1 (red pulse)
//     to discriminate WHICH layer, if either, reaches the screen
//
// ⚠ Takes over the whole main display (~30s). Native-res mode set only (no real mode change).
//
// Build: x86_64-w64-mingw32-gcc minrepro2.c -o minrepro2.exe -ld3d11 -ldxgi -ldxguid -luuid
#include <windows.h>
#include <d3d11.h>
#include <dxgi.h>
#include <stdio.h>
#include <math.h>

static DWORD g_t0;
static void logmsg(const char *s) { printf("[%6lums] %s\n", (unsigned long)(GetTickCount() - g_t0), s); }

static LRESULT CALLBACK WndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
    switch (m) {
        case WM_SIZE:
            printf("[%6lums] MSG WM_SIZE %s\n", (unsigned long)(GetTickCount() - g_t0),
                   w == SIZE_MINIMIZED ? "MINIMIZED" : w == SIZE_RESTORED ? "RESTORED" : "other");
            break;
        case WM_ACTIVATEAPP:
            printf("[%6lums] MSG WM_ACTIVATEAPP %s\n",
                   (unsigned long)(GetTickCount() - g_t0), w ? "ACTIVATED" : "DEACTIVATED");
            break;
        case WM_DESTROY: PostQuitMessage(0); return 0;
    }
    return DefWindowProc(h, m, w, l);
}

static void pump(DWORD ms) {
    DWORD end = GetTickCount() + ms;
    MSG msg;
    while (GetTickCount() < end) {
        while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessage(&msg); }
        Sleep(10);
    }
}

// color: 0 = solid magenta, 1 = green<->blue cycle, 2 = red<->black pulse
static void present_loop(ID3D11DeviceContext *ctx, IDXGISwapChain *sc,
                         ID3D11RenderTargetView *rtv, int seconds, int color) {
    DWORD t0 = GetTickCount(), last = t0;
    unsigned long frames = 0, at_last = 0;
    MSG msg;
    while ((GetTickCount() - t0) / 1000 < (DWORD)seconds) {
        while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessage(&msg); }
        float c[4] = {1.0f, 0.0f, 1.0f, 1.0f};
        float p = (float)((GetTickCount() - t0) % 1000) / 1000.0f;
        float s = 0.5f + 0.5f * (float)sin(p * 6.28318f);
        if (color == 1) { c[0] = 0.0f; c[1] = s; c[2] = 1.0f - s; }
        else if (color == 2) { c[0] = s; c[1] = 0.0f; c[2] = 0.0f; }
        ctx->lpVtbl->ClearRenderTargetView(ctx, rtv, c);
        HRESULT hr = sc->lpVtbl->Present(sc, 1, 0);
        frames++;
        DWORD now = GetTickCount();
        if (now - last >= 1000) {
            printf("[%6lums] presenting: %lu fps  hr=0x%08lx\n",
                   (unsigned long)(now - g_t0), frames - at_last, (unsigned long)hr);
            last = now; at_last = frames;
        }
    }
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    g_t0 = GetTickCount();
    int W = 1920, H = 1080;

    WNDCLASS wc = {0};
    wc.lpfnWndProc = WndProc; wc.hInstance = GetModuleHandle(NULL);
    wc.lpszClassName = "minrepro2"; wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClass(&wc);
    HWND hwnd = CreateWindow("minrepro2", "minrepro2",
        WS_OVERLAPPEDWINDOW, 0, 0, W, H, NULL, NULL, wc.hInstance, NULL);
    ShowWindow(hwnd, SW_SHOW);
    pump(300);

    DXGI_SWAP_CHAIN_DESC sd = {0};
    sd.BufferCount = 2;
    sd.BufferDesc.Width = W; sd.BufferDesc.Height = H;
    sd.BufferDesc.RefreshRate.Numerator = 120; sd.BufferDesc.RefreshRate.Denominator = 1;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = hwnd;
    sd.SampleDesc.Count = 1;
    sd.Windowed = FALSE;                                 // exclusive fullscreen, like CS2's boot
    sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;

    ID3D11Device *dev = NULL; ID3D11DeviceContext *ctx = NULL; IDXGISwapChain *sc1 = NULL;
    D3D_FEATURE_LEVEL fl;
    HRESULT hr = D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0,
        NULL, 0, D3D11_SDK_VERSION, &sd, &sc1, &dev, &fl, &ctx);
    printf("[%6lums] CreateDeviceAndSwapChain(fullscreen) hr=0x%08lx\n",
           (unsigned long)(GetTickCount() - g_t0), (unsigned long)hr);
    if (FAILED(hr)) return 1;
    pump(500);

    ID3D11Texture2D *bb1 = NULL; ID3D11RenderTargetView *rtv1 = NULL;
    sc1->lpVtbl->GetBuffer(sc1, 0, &IID_ID3D11Texture2D, (void**)&bb1);
    dev->lpVtbl->CreateRenderTargetView(dev, (ID3D11Resource*)bb1, NULL, &rtv1);

    logmsg("PHASE1 presenting MAGENTA on fullscreen swapchain#1 (4s)");
    present_loop(ctx, sc1, rtv1, 4, 0);

    logmsg("MINIMIZE self-minimizing with fullscreen state held (like the game); presenting 1s more on #1");
    ShowWindow(hwnd, SW_MINIMIZE);
    present_loop(ctx, sc1, rtv1, 1, 0);
    pump(1000);   // let Cocoa finish the genie (real trace: DID_MINIMIZE ~0.6s after)
    {
        RECT r; GetClientRect(hwnd, &r);
        printf("[%6lums] client rect while minimized: (%ld,%ld)-(%ld,%ld)\n",
               (unsigned long)(GetTickCount() - g_t0), r.left, r.top, r.right, r.bottom);
    }

    logmsg("CREATE2 windowed swapchain#2 on same HWND while minimized");
    IDXGIDevice *dxdev = NULL; IDXGIAdapter *adapter = NULL; IDXGIFactory *factory = NULL;
    dev->lpVtbl->QueryInterface(dev, &IID_IDXGIDevice, (void**)&dxdev);
    dxdev->lpVtbl->GetAdapter(dxdev, &adapter);
    adapter->lpVtbl->GetParent(adapter, &IID_IDXGIFactory, (void**)&factory);
    DXGI_SWAP_CHAIN_DESC sd2 = sd;
    sd2.Windowed = TRUE;
    IDXGISwapChain *sc2 = NULL;
    hr = factory->lpVtbl->CreateSwapChain(factory, (IUnknown*)dev, &sd2, &sc2);
    printf("[%6lums] CreateSwapChain#2 hr=0x%08lx %s\n",
           (unsigned long)(GetTickCount() - g_t0), (unsigned long)hr, FAILED(hr) ? "FAILED" : "ok");
    if (FAILED(hr)) return 1;
    ID3D11Texture2D *bb2 = NULL; ID3D11RenderTargetView *rtv2 = NULL;
    sc2->lpVtbl->GetBuffer(sc2, 0, &IID_ID3D11Texture2D, (void**)&bb2);
    dev->lpVtbl->CreateRenderTargetView(dev, (ID3D11Resource*)bb2, NULL, &rtv2);
    // swapchain#1 deliberately stays alive, still believing it is fullscreen (like CS2)

    logmsg("RESTORE SW_RESTORE, then re-assert fullscreen through DXGI on #2");
    ShowWindow(hwnd, SW_RESTORE);
    pump(500);
    hr = sc2->lpVtbl->SetFullscreenState(sc2, TRUE, NULL);          // mode-set #1
    printf("[%6lums] SetFullscreenState(#2,TRUE) hr=0x%08lx\n",
           (unsigned long)(GetTickCount() - g_t0), (unsigned long)hr);
    DXGI_MODE_DESC md = sd.BufferDesc;
    hr = sc2->lpVtbl->ResizeTarget(sc2, &md);                       // mode-set #2 (the trace's pair)
    printf("[%6lums] ResizeTarget(#2) hr=0x%08lx\n",
           (unsigned long)(GetTickCount() - g_t0), (unsigned long)hr);
    pump(300);

    logmsg("PHASE2 presenting CYCLING green<->blue on swapchain#2 (8s) — stale magenta = BUG");
    present_loop(ctx, sc2, rtv2, 8, 1);

    logmsg("PHASE2B presenting RED pulse on old fullscreen swapchain#1 (5s) — which layer shows?");
    present_loop(ctx, sc1, rtv1, 5, 2);

    logmsg("PHASE3 one more minimize/restore, then 6s cycling on #2 (one-refresh-per-cycle check)");
    ShowWindow(hwnd, SW_MINIMIZE);
    present_loop(ctx, sc2, rtv2, 2, 1);
    ShowWindow(hwnd, SW_RESTORE);
    pump(500);
    logmsg("PHASE3_PRESENTING");
    present_loop(ctx, sc2, rtv2, 6, 1);

    logmsg("CLEANUP leaving fullscreen");
    sc2->lpVtbl->SetFullscreenState(sc2, FALSE, NULL);
    sc1->lpVtbl->SetFullscreenState(sc1, FALSE, NULL);
    pump(300);
    logmsg("DONE");
    return 0;
}
