// minrepro.c — minimal reproducer for the DXMT alt-tab presentation freeze.
//
// The measured CS2 trigger (see docs/dxmt-bugs/DRAFT-focus-loss-freeze.md, "Live-freeze
// measurements"): on focus loss the game minimizes itself, then creates a SECOND swapchain on the
// same HWND while the window is miniaturized with an empty client rect. That swapchain's
// CAMetalLayer never enters live compositing — presents complete at full speed but the screen
// only updates once per subsequent minimize/restore cycle.
//
// This reproduces the sequence with NO human interaction (the old focustest.c wall — needing a
// real macOS focus loss — does not apply: the trigger is programmatic):
//
//   PHASE1   window + swapchain#1 (FLIP_SEQUENTIAL, 2 buffers, like CS2), present solid MAGENTA
//   MINIMIZE ShowWindow(SW_MINIMIZE), keep presenting (CS2 does), pump messages 2s
//   CREATE2  create swapchain#2 on the same HWND while minimized (client rect is (0,0)-(0,0));
//            swapchain#1 stays alive (CS2 keeps both until exit)
//   RESTORE  ShowWindow(SW_RESTORE), pump
//   PHASE2   present COLOR-CYCLING frames (green<->blue) on swapchain#2 for 8s
//   PHASE3   one more programmatic minimize/restore, then 6 more seconds of cycling
//
// Verdict comes from screenshots taken by scripts/run-minrepro.sh:
//   healthy:  P1 magenta, P2 cycling colors           (bug NOT reproduced)
//   the bug:  P1 magenta, P2 STILL MAGENTA and static (swapchain#2 output never composites);
//             P3's first capture may show ONE newer frame (the one-refresh-per-cycle behavior)
//
// Build (mingw-w64):
//   x86_64-w64-mingw32-gcc minrepro.c -o minrepro.exe -ld3d11 -ldxgi -ldxguid -luuid
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

// present `seconds` worth of frames; color: 0 = solid magenta, 1 = green<->blue cycle
static void present_loop(ID3D11DeviceContext *ctx, IDXGISwapChain *sc,
                         ID3D11RenderTargetView *rtv, int seconds, int cycle) {
    DWORD t0 = GetTickCount(), last = t0;
    unsigned long frames = 0, at_last = 0;
    MSG msg;
    while ((GetTickCount() - t0) / 1000 < (DWORD)seconds) {
        while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessage(&msg); }
        float c[4] = {1.0f, 0.0f, 1.0f, 1.0f};                       // magenta
        if (cycle) {                                                 // green<->blue, ~1s period
            float p = (float)((GetTickCount() - t0) % 1000) / 1000.0f;
            float s = 0.5f + 0.5f * (float)sin(p * 6.28318f);
            c[0] = 0.0f; c[1] = s; c[2] = 1.0f - s;
        }
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

    WNDCLASS wc = {0};
    wc.lpfnWndProc = WndProc; wc.hInstance = GetModuleHandle(NULL);
    wc.lpszClassName = "minrepro"; wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClass(&wc);
    HWND hwnd = CreateWindow("minrepro", "minrepro - MAGENTA=sc1 CYCLING=sc2",
        WS_OVERLAPPEDWINDOW, 100, 100, 800, 600, NULL, NULL, wc.hInstance, NULL);
    ShowWindow(hwnd, SW_SHOW);
    pump(300);

    DXGI_SWAP_CHAIN_DESC sd = {0};
    sd.BufferCount = 2;
    sd.BufferDesc.Width = 800; sd.BufferDesc.Height = 600;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = hwnd;
    sd.SampleDesc.Count = 1;
    sd.Windowed = TRUE;
    sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;   // what CS2 asks for

    ID3D11Device *dev = NULL; ID3D11DeviceContext *ctx = NULL; IDXGISwapChain *sc1 = NULL;
    D3D_FEATURE_LEVEL fl;
    HRESULT hr = D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0,
        NULL, 0, D3D11_SDK_VERSION, &sd, &sc1, &dev, &fl, &ctx);
    if (FAILED(hr)) { printf("FATAL: CreateDeviceAndSwapChain hr=0x%08lx\n", (unsigned long)hr); return 1; }

    ID3D11Texture2D *bb1 = NULL; ID3D11RenderTargetView *rtv1 = NULL;
    sc1->lpVtbl->GetBuffer(sc1, 0, &IID_ID3D11Texture2D, (void**)&bb1);
    dev->lpVtbl->CreateRenderTargetView(dev, (ID3D11Resource*)bb1, NULL, &rtv1);

    logmsg("PHASE1 presenting MAGENTA on swapchain#1 (4s)");
    present_loop(ctx, sc1, rtv1, 4, 0);

    logmsg("MINIMIZE ShowWindow(SW_MINIMIZE), presenting continues on #1 (2s)");
    ShowWindow(hwnd, SW_MINIMIZE);
    present_loop(ctx, sc1, rtv1, 2, 0);
    {
        RECT r; GetClientRect(hwnd, &r);
        printf("[%6lums] client rect while minimized: (%ld,%ld)-(%ld,%ld)\n",
               (unsigned long)(GetTickCount() - g_t0), r.left, r.top, r.right, r.bottom);
    }

    logmsg("CREATE2 creating swapchain#2 on the same HWND while minimized");
    IDXGIDevice *dxdev = NULL; IDXGIAdapter *adapter = NULL; IDXGIFactory *factory = NULL;
    dev->lpVtbl->QueryInterface(dev, &IID_IDXGIDevice, (void**)&dxdev);
    dxdev->lpVtbl->GetAdapter(dxdev, &adapter);
    adapter->lpVtbl->GetParent(adapter, &IID_IDXGIFactory, (void**)&factory);
    IDXGISwapChain *sc2 = NULL;
    DXGI_SWAP_CHAIN_DESC sd2 = sd;                       // same shape as #1
    hr = factory->lpVtbl->CreateSwapChain(factory, (IUnknown*)dev, &sd2, &sc2);
    printf("[%6lums] CreateSwapChain#2 hr=0x%08lx %s\n",
           (unsigned long)(GetTickCount() - g_t0), (unsigned long)hr, FAILED(hr) ? "FAILED" : "ok");
    if (FAILED(hr)) return 1;
    ID3D11Texture2D *bb2 = NULL; ID3D11RenderTargetView *rtv2 = NULL;
    sc2->lpVtbl->GetBuffer(sc2, 0, &IID_ID3D11Texture2D, (void**)&bb2);
    dev->lpVtbl->CreateRenderTargetView(dev, (ID3D11Resource*)bb2, NULL, &rtv2);
    // NOTE: swapchain#1 deliberately stays alive — CS2 keeps both until process exit.

    logmsg("RESTORE ShowWindow(SW_RESTORE)");
    ShowWindow(hwnd, SW_RESTORE);
    pump(500);

    logmsg("PHASE2 presenting CYCLING green<->blue on swapchain#2 (8s) — screen should cycle; stale magenta = BUG");
    present_loop(ctx, sc2, rtv2, 8, 1);

    logmsg("PHASE3 one more minimize/restore cycle, then 6s more cycling on #2");
    ShowWindow(hwnd, SW_MINIMIZE);
    present_loop(ctx, sc2, rtv2, 2, 1);
    ShowWindow(hwnd, SW_RESTORE);
    pump(500);
    logmsg("PHASE3_PRESENTING");
    present_loop(ctx, sc2, rtv2, 6, 1);

    logmsg("DONE");
    return 0;
}
