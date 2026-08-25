// Minimal DX11: create a window + swapchain, clear to magenta, present in a loop.
// If Wine 11 can present accelerated frames, the window shows solid MAGENTA.
// If presentation is broken on macOS 26, it stays BLACK.
#include <windows.h>
#include <d3d11.h>
#include <dxgi.h>

static LRESULT CALLBACK WndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
    if (m == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProc(h, m, w, l);
}

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE p, LPSTR cmd, int show) {
    WNDCLASS wc = {0};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInst;
    wc.lpszClassName = "dxtest";
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClass(&wc);
    HWND hwnd = CreateWindow("dxtest", "DX11 present test - should be MAGENTA",
        WS_OVERLAPPEDWINDOW, 100, 100, 800, 600, NULL, NULL, hInst, NULL);
    ShowWindow(hwnd, SW_SHOW);

    DXGI_SWAP_CHAIN_DESC sd = {0};
    sd.BufferCount = 2;
    sd.BufferDesc.Width = 800;
    sd.BufferDesc.Height = 600;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = hwnd;
    sd.SampleDesc.Count = 1;
    sd.Windowed = TRUE;
    sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;

    ID3D11Device *dev = NULL; ID3D11DeviceContext *ctx = NULL; IDXGISwapChain *sc = NULL;
    D3D_FEATURE_LEVEL fl;
    HRESULT hr = D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0,
        NULL, 0, D3D11_SDK_VERSION, &sd, &sc, &dev, &fl, &ctx);
    if (FAILED(hr)) { MessageBox(hwnd, "D3D11CreateDeviceAndSwapChain FAILED", "err", 0); return 1; }

    ID3D11Texture2D *bb = NULL;
    sc->lpVtbl->GetBuffer(sc, 0, &IID_ID3D11Texture2D, (void**)&bb);
    ID3D11RenderTargetView *rtv = NULL;
    dev->lpVtbl->CreateRenderTargetView(dev, (ID3D11Resource*)bb, NULL, &rtv);

    float magenta[4] = {1.0f, 0.0f, 1.0f, 1.0f};
    MSG msg; int running = 1;
    while (running) {
        while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) running = 0;
            TranslateMessage(&msg); DispatchMessage(&msg);
        }
        ctx->lpVtbl->ClearRenderTargetView(ctx, rtv, magenta);
        sc->lpVtbl->Present(sc, 1, 0);
    }
    return 0;
}
