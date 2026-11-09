/* frameless-window-repro.c — minimal reproducer for R4 (docs/wine-bugs/R4-frameless-window-decorated.md)
 *
 * winemac gives a macOS title bar to a window that reclaimed its caption area via WM_NCCALCSIZE —
 * the frameless-but-resizable pattern used by Electron, CEF and the Paradox launcher. The window
 * then carries two title bars, and every mouse coordinate lands ~28 points low because Win32's
 * client rect and the Cocoa content view disagree by the caption height.
 *
 * Everything reported so far came from the Paradox launcher, which is a large closed-source app.
 * This is the same thing in 60 lines, so a wine developer can reproduce it without Steam, CS2 or
 * DXMT installed.
 *
 * Build:  x86_64-w64-mingw32-gcc -O2 -o frameless-repro.exe scripts/frameless-window-repro.c -lgdi32
 * Run:    wine frameless-repro.exe
 *
 * Expected on a correct driver: client size == window size, dy == 0, and NO title bar drawn.
 * On winemac: a title bar appears and the Cocoa content view is ~28pt shorter than the client rect
 * Win32 reports, which is what displaces hit-testing.
 * (macgameport, 2026-08-31)
 */
#include <windows.h>
#include <stdio.h>

static LRESULT CALLBACK wndproc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    switch (m)
    {
    case WM_NCCALCSIZE:
        /* THE WHOLE POINT, and the geometry has to match the real case exactly.
         *
         * Reserve a RESIZE BORDER on the left, right and bottom, and ZERO on the top. That is what
         * the Paradox launcher does -- measured: window 2570x1346, client 2560x1341, so dx=5 dy=0 --
         * and it is what Electron's frameless-but-resizable windows do generally: keep the border
         * for hit-testing, take the caption back for your own chrome.
         *
         * Reclaiming the WHOLE rect instead (dx=0 dy=0) does NOT reproduce the bug: winemac's
         * `EqualRect(rects.window, rects.visible)` guard then fires and the window is left
         * undecorated -- which is exactly why Steam's own window is fine. Measured here first, and
         * the naive version would have "proved" there is no bug. */
        if (w)
        {
            NCCALCSIZE_PARAMS *p = (NCCALCSIZE_PARAMS *)l;
            p->rgrc[0].left   += 5;
            p->rgrc[0].right  -= 5;
            p->rgrc[0].bottom -= 5;
            /* top deliberately untouched: no caption reserved */
            return 0;
        }
        break;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(h, m, w, l);
}

int main(void)
{
    WNDCLASSEXW wc = { .cbSize = sizeof(wc), .lpfnWndProc = wndproc,
                       .hInstance = GetModuleHandleW(NULL), .lpszClassName = L"FramelessRepro",
                       .hbrBackground = (HBRUSH)(COLOR_WINDOW + 1) };
    HWND h;
    RECT wr, cr;
    POINT tl = { 0, 0 };
    MSG msg;
    int i;

    HMODULE u32 = GetModuleHandleW(L"user32.dll");
    BOOL (WINAPI *pSetCtx)(HANDLE) = (void *)GetProcAddress(u32, "SetProcessDpiAwarenessContext");
    if (pSetCtx) pSetCtx((HANDLE)(INT_PTR)-4);   /* per-monitor aware: report RAW pixels */

    RegisterClassExW(&wc);
    h = CreateWindowExW(0, L"FramelessRepro", L"frameless repro",
                        WS_OVERLAPPEDWINDOW,          /* == WS_CAPTION|WS_THICKFRAME|... */
                        100, 100, 800, 600, NULL, NULL, wc.hInstance, NULL);
    if (!h) { fprintf(stderr, "CreateWindow failed\n"); return 1; }

    /* REQUIRED, and easy to miss: WM_NCCALCSIZE alone does not retroactively change a frame that
     * was already computed at creation. SWP_FRAMECHANGED forces the recalculation, which is what
     * makes the client area actually swallow the caption. Without this the window keeps a normal
     * caption (measured: dy=30) and the test proves nothing. */
    SetWindowPos(h, NULL, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    ShowWindow(h, SW_SHOW);

    /* let the driver settle before measuring */
    for (i = 0; i < 40; i++)
    {
        while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessageW(&msg); }
        Sleep(25);
    }

    GetWindowRect(h, &wr);
    GetClientRect(h, &cr);
    ClientToScreen(h, &tl);
    printf("style        : 0x%08lx  (WS_CAPTION %s)\n",
           (unsigned long)GetWindowLongW(h, GWL_STYLE),
           (GetWindowLongW(h, GWL_STYLE) & WS_CAPTION) == WS_CAPTION ? "SET" : "clear");
    printf("window rect  : %ld,%ld  %ldx%ld\n", wr.left, wr.top, wr.right - wr.left, wr.bottom - wr.top);
    printf("client size  : %ldx%ld  (client origin on screen %ld,%ld)\n",
           cr.right - cr.left, cr.bottom - cr.top, tl.x, tl.y);
    printf("NON-CLIENT   : dx=%ld dy=%ld\n", tl.x - wr.left, tl.y - wr.top);
    printf("\nEXPECTED: dx=5 dy=0 (border kept, caption reclaimed) and NO title bar drawn.\n");
    printf("ON winemac: a macOS title bar is drawn anyway, and the Cocoa content view ends up\n");
    printf("            ~28pt shorter than the client rect above, displacing all hit-testing.\n");
    printf("\nLook at the window: if it has a title bar, the bug is present.\n");
    if (tl.y - wr.top != 0)
        printf("\n!! dy != 0 -- this run did NOT reproduce the frameless case; the caption was\n"
               "   never reclaimed, so nothing below it is evidence about the driver.\n");

    for (i = 0; i < 400; i++)   /* stay up ~10s so the decoration can be observed/captured */
    {
        while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessageW(&msg); }
        Sleep(25);
    }
    return 0;
}
