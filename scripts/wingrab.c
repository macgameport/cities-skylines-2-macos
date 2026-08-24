/* wingrab.c — Win32-side window-tree dump + content grab, run INSIDE the wine prefix.
 *
 * Purpose: decide WHERE a black window loses its pixels. Run this against a window that the
 * macOS side captures as all-black (see scripts/winlist.swift + `screencapture -l`):
 *
 *   - Win32 grab shows REAL CONTENT, macOS capture black  -> the app painted; the pixels are
 *     lost between Wine and the macOS window server (winemac.drv surface path — the family the
 *     alt-tab freeze lived in).
 *   - Both black                                          -> the app genuinely never painted;
 *     look at the app/renderer, not at the presentation layer.
 *
 * Build:  x86_64-w64-mingw32-gcc scripts/wingrab.c -o scripts/wingrab.exe -lgdi32 -luser32
 * Run:    wine wingrab.exe "<window title substring>"   (writes <out>-blt.bmp / -print.bmp)
 *
 * Written 2026-08-24 for the Steam black-CEF-window investigation (GOTCHAS.md
 * "Steam black UI is NOT the Vulkan failure").
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>

static const char *g_match;
static HWND g_found;

static void describe(HWND h, int depth)
{
    char cls[128] = "", title[256] = "";
    RECT r; GetWindowRect(h, &r);
    GetClassNameA(h, cls, sizeof cls);
    GetWindowTextA(h, title, sizeof title);
    LONG style = GetWindowLongA(h, GWL_STYLE), ex = GetWindowLongA(h, GWL_EXSTYLE);
    printf("%*s hwnd=%p cls=%-24s %4ldx%-4ld at %5ld,%-5ld vis=%d style=%08lx ex=%08lx  \"%s\"\n",
           depth * 2, "", (void *)h, cls,
           (long)(r.right - r.left), (long)(r.bottom - r.top), (long)r.left, (long)r.top,
           IsWindowVisible(h), (unsigned long)style, (unsigned long)ex, title);
}

static BOOL CALLBACK child_cb(HWND h, LPARAM depth)
{
    describe(h, (int)depth);
    EnumChildWindows(h, child_cb, depth + 1);
    return TRUE;
}

static BOOL CALLBACK top_cb(HWND h, LPARAM unused)
{
    char title[256] = "";
    (void)unused;
    GetWindowTextA(h, title, sizeof title);
    if (*title && strstr(title, g_match)) {
        if (!g_found) g_found = h;
        describe(h, 0);
        EnumChildWindows(h, child_cb, 1);
    }
    return TRUE;
}

/* Save a 32bpp top-down DIB as a BMP. */
static int save_bmp(const char *path, const void *bits, int w, int h)
{
    BITMAPFILEHEADER fh; BITMAPINFOHEADER ih;
    DWORD sz = (DWORD)w * h * 4;
    FILE *f = fopen(path, "wb");
    if (!f) return 0;
    memset(&fh, 0, sizeof fh); memset(&ih, 0, sizeof ih);
    fh.bfType = 0x4D42;
    fh.bfOffBits = sizeof fh + sizeof ih;
    fh.bfSize = fh.bfOffBits + sz;
    ih.biSize = sizeof ih; ih.biWidth = w; ih.biHeight = -h;   /* top-down */
    ih.biPlanes = 1; ih.biBitCount = 32; ih.biCompression = BI_RGB; ih.biSizeImage = sz;
    fwrite(&fh, sizeof fh, 1, f); fwrite(&ih, sizeof ih, 1, f); fwrite(bits, sz, 1, f);
    fclose(f);
    return 1;
}

/* Grab hwnd's pixels via `how` (0 = BitBlt from window DC, 1 = PrintWindow) and report
 * how many of them are non-black — that number IS the measurement. */
static void grab(HWND hwnd, const char *out, int how)
{
    RECT r; GetWindowRect(hwnd, &r);
    int w = r.right - r.left, h = r.bottom - r.top;
    if (w <= 0 || h <= 0) { printf("  %s: zero-size window\n", out); return; }

    HDC src = GetWindowDC(hwnd);
    HDC mem = CreateCompatibleDC(src);
    BITMAPINFO bi; void *bits = NULL;
    memset(&bi, 0, sizeof bi);
    bi.bmiHeader.biSize = sizeof bi.bmiHeader;
    bi.bmiHeader.biWidth = w; bi.bmiHeader.biHeight = -h;
    bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    HBITMAP dib = CreateDIBSection(src, &bi, DIB_RGB_COLORS, &bits, NULL, 0);
    HGDIOBJ old = SelectObject(mem, dib);
    /* prime with magenta so "nothing was written at all" is distinguishable from "wrote black" */
    for (int i = 0; i < w * h; i++) ((DWORD *)bits)[i] = 0x00FF00FF;

    BOOL ok = how ? PrintWindow(hwnd, mem, 2 /* PW_RENDERFULLCONTENT */)
                  : BitBlt(mem, 0, 0, w, h, src, 0, 0, SRCCOPY);

    long nonblack = 0, magenta = 0;
    for (int i = 0; i < w * h; i++) {
        DWORD p = ((DWORD *)bits)[i] & 0x00FFFFFF;
        if (p == 0x00FF00FF) magenta++;
        else if (p != 0) nonblack++;
    }
    printf("  %-28s ok=%d  %dx%d  non-black=%ld (%.2f%%)  untouched-magenta=%ld (%.2f%%)\n",
           out, ok, w, h, nonblack, 100.0 * nonblack / (w * (double)h),
           magenta, 100.0 * magenta / (w * (double)h));
    save_bmp(out, bits, w, h);

    SelectObject(mem, old); DeleteObject(dib); DeleteDC(mem); ReleaseDC(hwnd, src);
}

int main(int argc, char **argv)
{
    HWND target;
    /* wingrab.exe --hwnd 0x10198   grabs one specific window (e.g. a CEF child) */
    if (argc > 2 && !strcmp(argv[1], "--hwnd")) {
        target = (HWND)(ULONG_PTR)strtoull(argv[2], NULL, 0);
        printf("=== grabbing explicit hwnd %p ===\n", (void *)target);
        describe(target, 0);
    } else {
        g_match = argc > 1 ? argv[1] : "Steam";
        printf("=== window tree matching \"%s\" ===\n", g_match);
        EnumWindows(top_cb, 0);
        if (!g_found) { printf("no top-level window matched\n"); return 1; }
        target = g_found;
        printf("=== grabbing %p ===\n", (void *)target);
    }
    grab(target, "wingrab-blt.bmp", 0);
    grab(target, "wingrab-print.bmp", 1);
    return 0;
}
