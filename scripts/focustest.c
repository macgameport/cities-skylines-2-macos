/* focustest.c — does presentation survive losing window focus?
 *
 * Minimal DX11 present loop built to isolate ONE variable: the swap effect. CS2 asks for
 * DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL (3) and DXMT logs "unsupported swap effect 3", falls back
 * silently, and the game then freezes permanently the moment another window takes focus
 * (input still registers, nothing ever re-presents). This reproduces that setup in ~150 lines.
 *
 * Console subsystem on purpose: stdout is the instrument. A frozen present loop shows up as
 * stdout going quiet, so the freeze is detectable without looking at the screen.
 *
 * Build (mingw-w64):
 *   x86_64-w64-mingw32-gcc focustest.c -o focustest.exe -ld3d11 -ldxgi -municode
 * Run under the wrapper's wine, then click another window / alt-tab and watch the output:
 *   --flip        use FLIP_SEQUENTIAL (3), what the game asks for   [default: DISCARD (0)]
 *   --fullscreen  request exclusive fullscreen instead of windowed
 *   --seconds N   run for N seconds then exit (default 90)
 *
 * Expected if healthy: FOCUS lines keep printing at a steady rate across a focus change,
 * and Present keeps returning 0x0 (or 0x087A0001 DXGI_STATUS_OCCLUDED while hidden, which is
 * normal and recoverable). A reproduction of the bug looks like: output stops entirely, or
 * Present starts taking hundreds of ms, or an hr that never returns to 0 after refocus. */
#include <windows.h>
#include <d3d11.h>
#include <dxgi.h>
#include <stdio.h>
#include <string.h>

static DWORD g_t0;
/* Wine's GetForegroundWindow() tracks Wine's own window list, not macOS focus, so polling it
 * reports focus=1 even while another Mac app is frontmost. The activation MESSAGES are the
 * signal that actually crosses the boundary — log them. */
static LRESULT CALLBACK WndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
    switch (m) {
        case WM_ACTIVATEAPP:
            printf("[%6lums] MSG WM_ACTIVATEAPP %s\n",
                   (unsigned long)(GetTickCount() - g_t0), w ? "ACTIVATED" : "DEACTIVATED"); break;
        case WM_ACTIVATE:
            printf("[%6lums] MSG WM_ACTIVATE %s\n", (unsigned long)(GetTickCount() - g_t0),
                   LOWORD(w) == WA_INACTIVE ? "INACTIVE" : "ACTIVE"); break;
        case WM_KILLFOCUS:
            printf("[%6lums] MSG WM_KILLFOCUS\n", (unsigned long)(GetTickCount() - g_t0)); break;
        case WM_SETFOCUS:
            printf("[%6lums] MSG WM_SETFOCUS\n", (unsigned long)(GetTickCount() - g_t0)); break;
        case WM_SIZE:
            printf("[%6lums] MSG WM_SIZE %s\n", (unsigned long)(GetTickCount() - g_t0),
                   w == SIZE_MINIMIZED ? "MINIMIZED" : w == SIZE_RESTORED ? "RESTORED" : "other"); break;
        case WM_DESTROY: PostQuitMessage(0); return 0;
    }
    return DefWindowProc(h, m, w, l);
}

static const char *hr_name(HRESULT hr) {
    switch ((unsigned long)hr) {
        case 0x00000000UL: return "S_OK";
        case 0x087A0001UL: return "DXGI_STATUS_OCCLUDED";
        case 0x087A0007UL: return "DXGI_STATUS_MODE_CHANGED";
        case 0x087A0008UL: return "DXGI_STATUS_MODE_CHANGE_IN_PROGRESS";
        case 0x887A0001UL: return "DXGI_ERROR_INVALID_CALL";
        case 0x887A0005UL: return "DXGI_ERROR_DEVICE_REMOVED";
        case 0x887A0006UL: return "DXGI_ERROR_DEVICE_HUNG";
        case 0x887A0007UL: return "DXGI_ERROR_DEVICE_RESET";
        default: return "?";
    }
}

int main(int argc, char **argv) {
    int use_flip = 0, fullscreen = 0, seconds = 90, sync = 1;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--flip")) use_flip = 1;
        else if (!strcmp(argv[i], "--fullscreen")) fullscreen = 1;
        else if (!strcmp(argv[i], "--seconds") && i + 1 < argc) seconds = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--sync") && i + 1 < argc) sync = atoi(argv[++i]);
    }
    setvbuf(stdout, NULL, _IONBF, 0);   // unbuffered: a freeze must not hide in a buffer
    g_t0 = GetTickCount();
    printf("focustest: swap_effect=%s mode=%s sync_interval=%d seconds=%d\n",
           use_flip ? "FLIP_SEQUENTIAL(3)" : "DISCARD(0)",
           fullscreen ? "exclusive-fullscreen" : "windowed", sync, seconds);

    WNDCLASS wc = {0};
    wc.lpfnWndProc = WndProc; wc.hInstance = GetModuleHandle(NULL);
    wc.lpszClassName = "focustest"; wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClass(&wc);
    HWND hwnd = CreateWindow("focustest", "focustest - MAGENTA = presenting",
        WS_OVERLAPPEDWINDOW, 100, 100, 800, 600, NULL, NULL, wc.hInstance, NULL);
    ShowWindow(hwnd, SW_SHOW);

    DXGI_SWAP_CHAIN_DESC sd = {0};
    sd.BufferCount = 2;
    sd.BufferDesc.Width = 800; sd.BufferDesc.Height = 600;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = hwnd;
    sd.SampleDesc.Count = 1;
    sd.Windowed = fullscreen ? FALSE : TRUE;
    sd.SwapEffect = use_flip ? DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL : DXGI_SWAP_EFFECT_DISCARD;

    ID3D11Device *dev = NULL; ID3D11DeviceContext *ctx = NULL; IDXGISwapChain *sc = NULL;
    D3D_FEATURE_LEVEL fl;
    HRESULT hr = D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0,
        NULL, 0, D3D11_SDK_VERSION, &sd, &sc, &dev, &fl, &ctx);
    if (FAILED(hr)) { printf("FATAL: CreateDeviceAndSwapChain hr=0x%08lx\n", (unsigned long)hr); return 1; }
    printf("device ok, feature level 0x%x\n", (unsigned)fl);

    ID3D11Texture2D *bb = NULL;
    sc->lpVtbl->GetBuffer(sc, 0, &IID_ID3D11Texture2D, (void**)&bb);
    ID3D11RenderTargetView *rtv = NULL;
    dev->lpVtbl->CreateRenderTargetView(dev, (ID3D11Resource*)bb, NULL, &rtv);

    float magenta[4] = {1.0f, 0.0f, 1.0f, 1.0f};
    MSG msg; int running = 1;
    DWORD t0 = GetTickCount(), last_report = t0;
    unsigned long frames = 0, frames_at_last_report = 0;
    int had_focus = (GetForegroundWindow() == hwnd);
    HRESULT last_hr = 0;

    while (running) {
        while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) running = 0;
            TranslateMessage(&msg); DispatchMessage(&msg);
        }
        ctx->lpVtbl->ClearRenderTargetView(ctx, rtv, magenta);

        DWORD pt0 = GetTickCount();
        hr = sc->lpVtbl->Present(sc, sync, 0);
        DWORD pdt = GetTickCount() - pt0;
        frames++;
        last_hr = hr;

        /* a single Present that blocks is the interesting event — report it immediately */
        if (pdt > 500)
            printf("[%6lums] SLOW Present: %lums  hr=0x%08lx %s  frame=%lu\n",
                   (unsigned long)(GetTickCount() - t0), (unsigned long)pdt,
                   (unsigned long)hr, hr_name(hr), frames);

        int has_focus = (GetForegroundWindow() == hwnd);
        if (has_focus != had_focus) {
            printf("[%6lums] FOCUS %s  hr=0x%08lx %s  frame=%lu\n",
                   (unsigned long)(GetTickCount() - t0), has_focus ? "GAINED" : "LOST",
                   (unsigned long)hr, hr_name(hr), frames);
            had_focus = has_focus;
        }

        DWORD now = GetTickCount();
        if (now - last_report >= 1000) {
            printf("[%6lums] alive: %lu fps (total %lu)  focus=%d  hr=0x%08lx %s\n",
                   (unsigned long)(now - t0), frames - frames_at_last_report, frames,
                   has_focus, (unsigned long)hr, hr_name(hr));
            last_report = now; frames_at_last_report = frames;
        }
        if ((now - t0) / 1000 >= (DWORD)seconds) running = 0;
    }
    printf("done: %lu frames, last hr=0x%08lx %s\n",
           frames, (unsigned long)last_hr, hr_name(last_hr));
    if (fullscreen && sc) sc->lpVtbl->SetFullscreenState(sc, FALSE, NULL);
    return 0;
}
