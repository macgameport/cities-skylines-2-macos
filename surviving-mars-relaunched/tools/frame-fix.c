/* frame-fix.exe [--dry | --once | --watch]  -- run INSIDE the game's wine prefix, with the same
 * WINEESYNC/WINEMSYNC as the wineserver (a mismatched client dies with SIGFPE at start).
 *
 * Surviving Mars: Relaunched under Wine 10 Sikarugir + D3DMetal 2.1 starts with every click
 * landing a constant distance sideways of the pointer. Measured 2026-11-01: the fullscreen window
 * is 1512x982 with a frameless style (0x160a0000: no WS_CAPTION, no WS_THICKFRAME) but its client
 * rect is 1506x950 -- a stale frame allowance left over from the style the window was created
 * with. SetWindowPos(SWP_FRAMECHANGED) makes Windows recompute it: client 1512x982, and the
 * clicks land under the pointer (confirmed by hand on the running game). Toggling window mode
 * twice (Alt+Enter) fixes it the same way, which is the workaround the Proton thread reports
 * (steamcommunity.com/app/3215050/discussions/0/660467372238632420/). SendInput Alt+Enter from
 * another process did NOT toggle the game, so this does not inject keys.
 *
 *   --dry    find the window, print its rects, change nothing
 *   --once   fix it once if stale, print before/after
 *   --watch  (default) fix whenever stale, until the window is gone; for the launcher
 *
 * Build:  x86_64-w64-mingw32-gcc -O2 -Wall -s -Wl,--no-insert-timestamp -o tools/frame-fix.exe tools/frame-fix.c
 * (-s leaves out the debug sections, which hold the compiler package's own build paths, and
 * --no-insert-timestamp the link stamp, so two builds are the same bytes. The built program is committed:
 * tools/frame-fix.build records what built it, tools/test-frame-fix-build.sh holds it to this source, and
 * tools/LICENSE-mingw-w64 is the licence of the runtime linked into it.)
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>

static const WCHAR TITLE[] = L"Surviving Mars Relaunched";
static DWORD t0;

static void show(const char *tag, HWND h)
{
    RECT wr, cr;
    GetWindowRect(h, &wr);
    GetClientRect(h, &cr);
    printf("%7.1fs %-6s hwnd %p  window %ld,%ld %ldx%ld  client %ldx%ld  style %08lx\n",
           (GetTickCount() - t0) / 1000.0, tag, (void *)h, wr.left, wr.top, wr.right - wr.left,
           wr.bottom - wr.top, cr.right, cr.bottom, (unsigned long)GetWindowLongW(h, GWL_STYLE));
    fflush(stdout);
}

/* Frameless by style, yet the client rect does not fill the window: the stale-frame state.
 * A real windowed mode has WS_CAPTION or WS_THICKFRAME and is left alone. */
static int stale(HWND h)
{
    RECT wr, cr;
    LONG style = GetWindowLongW(h, GWL_STYLE);
    if (style & (WS_CAPTION | WS_THICKFRAME)) return 0;
    if (!GetWindowRect(h, &wr) || !GetClientRect(h, &cr)) return 0;
    return cr.right != wr.right - wr.left || cr.bottom != wr.bottom - wr.top;
}

static void fix(HWND h)
{
    SetWindowPos(h, NULL, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                 SWP_FRAMECHANGED);
}

static HWND find(int tries)
{
    HWND h = NULL;
    for (int i = 0; i < tries && !(h = FindWindowW(NULL, TITLE)); i++) Sleep(500);
    return h;
}

int main(int argc, char **argv)
{
    const char *mode = argc > 1 ? argv[1] : "--watch";
    t0 = GetTickCount();
    if (strcmp(mode, "--dry") && strcmp(mode, "--once") && strcmp(mode, "--watch"))
    {
        fprintf(stderr, "usage: frame-fix.exe [--dry | --once | --watch]\n");
        return 2;
    }
    HWND h = find(240);   /* up to 2 min for the game to create its window */
    if (!h) { printf("no window titled \"Surviving Mars Relaunched\" after 120 s\n"); return 1; }
    show("found", h);
    if (!strcmp(mode, "--dry")) return 0;
    if (!strcmp(mode, "--once"))
    {
        if (!stale(h)) { printf("not stale, nothing to do\n"); return 0; }
        fix(h);
        Sleep(300);
        show("fixed", h);
        return stale(h);
    }
    int fixes = 0;
    for (;;)
    {
        if (!IsWindow(h) && !(h = find(10))) break;   /* gone, or recreated: look for 5 s */
        if (stale(h))
        {
            show("stale", h);
            fix(h);
            Sleep(300);
            show("fixed", h);
            fixes++;
        }
        Sleep(500);
    }
    printf("%7.1fs window gone; %d fix(es)\n", (GetTickCount() - t0) / 1000.0, fixes);
    return 0;
}
