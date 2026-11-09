/* crossblit.c — measures whether CROSS-PROCESS GDI painting reaches the screen under a given
 * wine engine. This is the primitive Chromium's software compositor relies on (the viz process
 * blits into the browser process's HWND), and the suspected reason embedded-Chromium UIs are
 * blank on stock wine's winemac while they render on CrossOver-lineage builds.
 *
 * parent mode: creates a 400x300 white window "CROSSBLIT-TARGET", paints it GREEN in its own
 *              WM_PAINT (in-process control), pumps messages ~40s, then exits.
 * child mode:  finds that window, GetDC + FillRect a RED 200x150 block (cross-process paint),
 *              then GetPixel-verifies its own write locally and reports.
 *
 * Judge from the macOS side (screencapture of the window):
 *   GREEN + RED  -> cross-process GDI reaches the screen (primitive works)
 *   GREEN only   -> the child's paint landed in a per-process shadow surface and was never
 *                   composited (the suspected stock-winemac behavior; child still reports
 *                   local success, which is what makes the failure silent)
 *
 * Build: x86_64-w64-mingw32-gcc scripts/crossblit.c -o crossblit.exe -lgdi32 -luser32
 * Run:   wine crossblit.exe parent &   then   wine crossblit.exe child
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>

static LRESULT CALLBACK wndproc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    if (m == WM_PAINT) {
        PAINTSTRUCT ps; HDC dc = BeginPaint(h, &ps);
        HBRUSH b = CreateSolidBrush(RGB(0, 200, 0));
        RECT r; GetClientRect(h, &r);
        FillRect(dc, &r, b);           /* in-process control: GREEN background */
        DeleteObject(b); EndPaint(h, &ps);
        return 0;
    }
    if (m == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProcA(h, m, w, l);
}

int main(int argc, char **argv)
{
    if (argc > 1 && !strcmp(argv[1], "parent")) {
        WNDCLASSA wc = {0};
        wc.lpfnWndProc = wndproc; wc.hInstance = GetModuleHandleA(NULL);
        wc.lpszClassName = "crossblit"; wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
        RegisterClassA(&wc);
        HWND h = CreateWindowExA(WS_EX_TOPMOST, "crossblit", "CROSSBLIT-TARGET",
                                 WS_POPUP | WS_VISIBLE,   /* popup: no titlebar; topmost: region-capturable */
                                 200, 200, 400, 300, NULL, NULL, wc.hInstance, NULL);
        printf("parent: hwnd=%p\n", (void *)h); fflush(stdout);
        MSG msg; DWORD t0 = GetTickCount();
        while (GetTickCount() - t0 < 120000) {
            while (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
                TranslateMessage(&msg); DispatchMessageA(&msg);
            }
            Sleep(50);
        }
        return 0;
    }
    /* child: cross-process paint */
    HWND h = FindWindowA(NULL, "CROSSBLIT-TARGET");
    if (!h) { printf("child: window not found\n"); return 1; }
    HDC dc = GetDC(h);
    if (!dc) { printf("child: GetDC failed\n"); return 1; }
    HBRUSH b = CreateSolidBrush(RGB(255, 0, 0));
    RECT r = { 50, 50, 250, 200 };
    BOOL ok = FillRect(dc, &r, b);
    GdiFlush();
    COLORREF px = GetPixel(dc, 100, 100);   /* local readback of our own write */
    printf("child: FillRect ok=%d local GetPixel(100,100)=%06lx (expect 0000ff BGR-red)\n",
           ok, (unsigned long)px);
    DeleteObject(b); ReleaseDC(h, dc);
    return 0;
}
