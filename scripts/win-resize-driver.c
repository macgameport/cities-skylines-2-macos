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

    if (argc < 3) return 2;
    HWND h = (HWND)(UINT_PTR)strtoull(argv[2], NULL, 16);
    if (!IsWindow(h)) { fprintf(stderr, "not a window: %s\n", argv[2]); return 1; }

    if (!strcmp(argv[1], "close"))
    {
        /* A graceful WM_CLOSE, not a signal. The project rule is "never signal steam.exe" (a TERM
         * leaves the same 0-byte .crash marker a KILL does); the same courtesy costs nothing for
         * the game, and this is repeatable from a script where clicking a window is not. */
        STAMP("CLOSE    posting WM_CLOSE to %p\n", h);
        PostMessageW(h, WM_CLOSE, 0, 0);
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
