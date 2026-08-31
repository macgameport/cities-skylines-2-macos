/* win-resize-driver.c -- scripted, repeatable window resizes inside the wine prefix.
 *
 * Interactive dragging cannot answer the resize question: you cannot tell a transient race from a
 * steady-state geometry bug when every sample is a different size at an unknown moment. This
 * applies EXACT sizes, waits for the window to settle, and stamps each step on the same wall clock
 * as winemac.drv's dxmt-rsz diagnostics, so the two streams can be read together.
 *
 * Build:  x86_64-w64-mingw32-gcc -O2 -o win-resize-driver.exe scripts/win-resize-driver.c -lgdi32
 * Usage:  wine win-resize-driver.exe list
 *         wine win-resize-driver.exe drive <hwnd-hex> <WxH> [WxH ...]   (settle 1500ms each)
 *         wine win-resize-driver.exe churn <hwnd-hex> <WxH> <WxH> <n>   (alternate, 60ms apart)
 *
 * (macgameport, 2026-08-31)
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static double now_ms(void)
{
    FILETIME ft; ULARGE_INTEGER u;
    GetSystemTimeAsFileTime(&ft);
    u.LowPart = ft.dwLowDateTime; u.HighPart = ft.dwHighDateTime;
    /* FILETIME is 100ns since 1601; fold to the same "seconds mod 1000, in ms" clock the
     * winemac diagnostic uses so the two streams interleave meaningfully. */
    unsigned long long ms = (u.QuadPart - 116444736000000000ULL) / 10000ULL;
    return (double)(ms % 1000000ULL);
}

#define STAMP(fmt, ...) fprintf(stderr, "dxmt-rsz: %8.1f DRIVER      " fmt, \
                                (double)((unsigned long long)now_ms() % 1000000ULL) / 1.0, ## __VA_ARGS__)

static BOOL CALLBACK enum_cb(HWND hwnd, LPARAM lp)
{
    wchar_t cls[128] = {0}, title[256] = {0};
    RECT r;
    DWORD pid = 0;

    if (!IsWindowVisible(hwnd)) return TRUE;
    if (!GetWindowRect(hwnd, &r)) return TRUE;
    if ((r.right - r.left) < 200 || (r.bottom - r.top) < 200) return TRUE;

    GetClassNameW(hwnd, cls, 127);
    GetWindowTextW(hwnd, title, 255);
    GetWindowThreadProcessId(hwnd, &pid);
    printf("%p  pid=%-6lu  %5ldx%-5ld at %5ld,%-5ld  class=%ls  title=%ls\n",
           hwnd, (unsigned long)pid, r.right - r.left, r.bottom - r.top, r.left, r.top,
           cls, title);
    (void)lp;
    return TRUE;
}

static void dump_children(HWND root, int depth)
{
    HWND c = GetWindow(root, GW_CHILD);
    while (c)
    {
        RECT r; wchar_t cls[128] = {0};
        DWORD pid = 0;
        GetWindowRect(c, &r);
        GetClassNameW(c, cls, 127);
        GetWindowThreadProcessId(c, &pid);
        printf("%*s child %p pid=%-6lu %5ldx%-5ld at %5ld,%-5ld class=%ls\n", depth * 2, "",
               c, (unsigned long)pid, r.right - r.left, r.bottom - r.top, r.left, r.top, cls);
        if (depth < 3) dump_children(c, depth + 1);
        c = GetWindow(c, GW_HWNDNEXT);
    }
}

static void report(HWND h, const char *tag)
{
    RECT r;
    if (GetWindowRect(h, &r))
        STAMP("%-8s root %p now %ldx%ld\n", tag, h, r.right - r.left, r.bottom - r.top);
}

static void apply(HWND h, int w, int hgt, int settle_ms)
{
    STAMP("REQUEST  %p -> %dx%d\n", h, w, hgt);
    SetWindowPos(h, NULL, 0, 0, w, hgt, SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
    Sleep(settle_ms);
    report(h, "SETTLED");
}

/* Sizes must be in RAW PIXELS, not logical units. A DPI-unaware process sees the window as
 * 1209x791 when its real rect is 2417x1581, because wine rounds the 0.5 away -- which makes the
 * ODD sizes that produce the artifact unreachable. Become per-monitor aware so SetWindowPos and
 * GetWindowRect both speak raw pixels. */
static void become_dpi_aware(void)
{
    HMODULE u32 = GetModuleHandleW(L"user32.dll");
    BOOL (WINAPI *pSetCtx)(HANDLE) = (void *)GetProcAddress(u32, "SetProcessDpiAwarenessContext");
    BOOL (WINAPI *pSetAware)(void) = (void *)GetProcAddress(u32, "SetProcessDPIAware");

    if (pSetCtx && pSetCtx((HANDLE)(INT_PTR)-4 /* PER_MONITOR_AWARE_V2 */)) return;
    if (pSetAware) pSetAware();
}

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "usage: list | drive <hwnd> <WxH>... | churn <hwnd> <WxH> <WxH> <n>\n"); return 2; }
    become_dpi_aware();

    if (!strcmp(argv[1], "list"))
    {
        printf("=== visible top-level windows >=200x200 ===\n");
        EnumWindows(enum_cb, 0);
        return 0;
    }

    if (!strcmp(argv[1], "cursor") && argc < 3)
    {
        /* Global mapping only -- no window needed, so this works with nothing running. */
        POINT pt;
        GetCursorPos(&pt);
        printf("wine GetCursorPos (screen px) : %ld,%ld\n", pt.x, pt.y);
        return 0;
    }

if (argc < 3) { fprintf(stderr, "need an hwnd for %s\n", argv[1]); return 2; }
    HWND h = (HWND)(UINT_PTR)strtoull(argv[2], NULL, 16);
    if (!IsWindow(h)) { fprintf(stderr, "not a window: %s\n", argv[2]); return 1; }

    if (!strcmp(argv[1], "front"))
    {
        /* screencapture -l refuses a window with no imageable backing store ("could not create
         * image from window"), which happens when it is occluded or not being composited. Raising
         * it is the difference between a measurement and a void run. */
        STAMP("FRONT    raising %p\n", h);
        SetWindowPos(h, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
        SetForegroundWindow(h);
        return 0;
    }

    if (!strcmp(argv[1], "close"))
    {
        /* A graceful WM_CLOSE, not a signal. The project rule is "never signal steam.exe" (a TERM
         * leaves the same 0-byte .crash marker a KILL does); the same courtesy costs nothing for
         * the game, and this is repeatable from a script where clicking a window is not. */
        STAMP("CLOSE    posting WM_CLOSE to %p\n", h);
        PostMessageW(h, WM_CLOSE, 0, 0);
        return 0;
    }

        if (!strcmp(argv[1], "cursor"))
    {
        /* Ask WINE where the pointer is, and where that lands in the window's CLIENT space --
         * which is exactly what gets handed to the app for hit-testing. Compare against the macOS
         * pointer position (CGEvent) and the Cocoa window origin, and the offset stops being a
         * description and becomes a subtraction. Needs no accessibility permission and no user:
         * wherever the pointer happens to be sitting is a valid sample. */
        POINT pt; RECT wr, cr;
        GetCursorPos(&pt);
        GetWindowRect(h, &wr);
        GetClientRect(h, &cr);
        printf("wine GetCursorPos (screen px) : %ld,%ld\n", pt.x, pt.y);
        printf("window rect (screen px)       : %ld,%ld %ldx%ld\n", wr.left, wr.top,
               wr.right - wr.left, wr.bottom - wr.top);
        ScreenToClient(h, &pt);
        printf("ScreenToClient  (client px)   : %ld,%ld    <== what the app hit-tests with\n", pt.x, pt.y);
        printf("client size     (px)          : %ldx%ld\n", cr.right - cr.left, cr.bottom - cr.top);
        return 0;
    }

    if (!strcmp(argv[1], "rects"))
    {
        /* WINDOW rect vs CLIENT rect for a top-level window. The hosted-layer frame is computed
         * relative to the root's WINDOW rect, but the layer is placed inside the CONTENT VIEW,
         * whose origin is the CLIENT area. On a window with a title bar those differ, and the
         * layer lands that far off -- visible as the cursor hit-testing above where it looks. */
        RECT wr, cr; POINT tl = {0, 0};
        GetWindowRect(h, &wr);
        GetClientRect(h, &cr);
        ClientToScreen(h, &tl);
        printf("window rect : %ld,%ld  %ldx%ld\n", wr.left, wr.top, wr.right - wr.left, wr.bottom - wr.top);
        printf("client rect : %ldx%ld  (client origin on screen: %ld,%ld)\n",
               cr.right - cr.left, cr.bottom - cr.top, tl.x, tl.y);
        printf("CLIENT OFFSET INSIDE WINDOW: dx=%ld  dy=%ld   <== a hosted layer is wrong by this\n",
               tl.x - wr.left, tl.y - wr.top);
        {
            /* Does this window ASK to be decorated? A frameless app (Electron/CEF drawing its own
             * titlebar) has no WS_CAPTION. If the host window manager decorates it anyway, the
             * client area it reports and the view that actually shows it stop agreeing. */
            LONG st = GetWindowLongW(h, GWL_STYLE), ex = GetWindowLongW(h, GWL_EXSTYLE);
            printf("style   : 0x%08lx  ", (unsigned long)st);
            if (st & WS_CAPTION)     printf("WS_CAPTION ");
            if (st & WS_THICKFRAME)  printf("WS_THICKFRAME ");
            if (st & WS_BORDER)      printf("WS_BORDER ");
            if (st & WS_DLGFRAME)    printf("WS_DLGFRAME ");
            if (st & WS_POPUP)       printf("WS_POPUP ");
            if (st & WS_SYSMENU)     printf("WS_SYSMENU ");
            if (st & WS_MINIMIZEBOX) printf("WS_MINIMIZEBOX ");
            if (st & WS_MAXIMIZEBOX) printf("WS_MAXIMIZEBOX ");
            printf("\nexstyle : 0x%08lx\n", (unsigned long)ex);
            /* winemac's get_window_features_for_style() suppresses the title bar when the window
             * is SHAPED (has a window region). That is how one WS_CAPTION window can end up
             * undecorated while another gets a real macOS title bar. */
            HRGN rgn = CreateRectRgn(0, 0, 0, 0);
            int rc = GetWindowRgn(h, rgn);
            printf("region  : %s\n", rc == ERROR ? "NONE (not shaped)" : "present (SHAPED)");
            DeleteObject(rgn);
            printf("VERDICT : %s\n", (st & WS_CAPTION) == WS_CAPTION
                   ? "asks for a caption - a title bar is correct"
                   : "NO WS_CAPTION - this window asked to be FRAMELESS");
        }
        return 0;
    }

    if (!strcmp(argv[1], "tree"))
    {
        /* Read-only: the hosted-layer z-order question is an ANCESTRY question, and guessing at it
         * from frame rectangles is how you build a fix on a coincidence. */
        report(h, "TREE");
        dump_children(h, 1);
        return 0;
    }

    if (argc < 4) return 2;
    if (!strcmp(argv[1], "drive"))
    {
        report(h, "START");
        printf("=== child tree at start ===\n"); dump_children(h, 1); fflush(stdout);
        for (int i = 3; i < argc; i++)
        {
            int w = 0, hgt = 0;
            if (sscanf(argv[i], "%dx%d", &w, &hgt) != 2) continue;
            apply(h, w, hgt, 1500);
        }
        printf("=== child tree at end ===\n"); dump_children(h, 1);
        return 0;
    }

    if (!strcmp(argv[1], "churn") && argc >= 6)
    {
        int w1, h1, w2, h2, n = atoi(argv[5]);
        if (sscanf(argv[3], "%dx%d", &w1, &h1) != 2) return 2;
        if (sscanf(argv[4], "%dx%d", &w2, &h2) != 2) return 2;
        STAMP("CHURN    %d alternations %dx%d <-> %dx%d at 60ms\n", n, w1, h1, w2, h2);
        for (int i = 0; i < n; i++)
        {
            SetWindowPos(h, NULL, 0, 0, (i & 1) ? w2 : w1, (i & 1) ? h2 : h1,
                         SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
            Sleep(60);
        }
        Sleep(2000);
        report(h, "POST");
        return 0;
    }

    return 2;
}
