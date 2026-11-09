/* game-input.exe -- mouse and key input for the game's window, sent from INSIDE its wine session.
 * Run with the same WINEPREFIX and WINEESYNC/WINEMSYNC as the game's wineserver (see frame-fix.c).
 *
 * Why: the game's window belongs to a bare wine64 process with no bundle ID, so macOS-side UI
 * automation cannot be granted control of it. Input sent with SendInput inside the prefix reaches
 * the game through wineserver instead. Wine also warps the real Mac pointer to the click point.
 * Coordinates are in the game window's CLIENT space (`rect` prints its size). frame-fix.c records
 * that a SendInput Alt+Enter from another process did not toggle the game. Clicks DO reach it:
 * measured 2026-11-07 (Studio, D3DMetal 3.0 engine), main menu > Load Game > a save loaded the save.
 * Keys are untested. Pair it with `screencapture -l <CGWindowID>` to see the window.
 *
 * Build:  x86_64-w64-mingw32-gcc -O2 -Wall -o tools/game-input.exe tools/game-input.c
 * Usage:  wine game-input.exe rect
 *         wine game-input.exe click <x> <y>
 *         wine game-input.exe key <scancode-hex>      (e.g. 01 = Esc, 1c = Enter)
 */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static HWND game(void)
{
    return FindWindowW(NULL, L"Surviving Mars Relaunched");
}

static void send1(INPUT *in)
{
    if (!SendInput(1, in, sizeof(*in)))
        fprintf(stderr, "SendInput failed, error %lu\n", (unsigned long)GetLastError());
}

int main(int argc, char **argv)
{
    HWND h = game();
    if (!h) { fprintf(stderr, "no game window\n"); return 2; }

    if (argc > 1 && !strcmp(argv[1], "rect")) {
        RECT w, c; POINT o = {0, 0};
        GetWindowRect(h, &w); GetClientRect(h, &c); ClientToScreen(h, &o);
        printf("hwnd %p window %ld,%ld %ldx%ld client origin %ld,%ld size %ldx%ld foreground %s\n",
               (void *)h, w.left, w.top, w.right - w.left, w.bottom - w.top, o.x, o.y,
               c.right, c.bottom, GetForegroundWindow() == h ? "yes" : "no");
        return 0;
    }

    if (argc > 3 && !strcmp(argv[1], "click")) {
        POINT p = {atoi(argv[2]), atoi(argv[3])}, got;
        INPUT in = {0};
        int vx = GetSystemMetrics(SM_XVIRTUALSCREEN), vy = GetSystemMetrics(SM_YVIRTUALSCREEN);
        int vw = GetSystemMetrics(SM_CXVIRTUALSCREEN), vh = GetSystemMetrics(SM_CYVIRTUALSCREEN);
        ClientToScreen(h, &p);
        SetForegroundWindow(h);
        in.type = INPUT_MOUSE;
        in.mi.dx = (LONG)((p.x - vx) * 65535LL / (vw - 1));
        in.mi.dy = (LONG)((p.y - vy) * 65535LL / (vh - 1));
        in.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK;
        send1(&in);
        Sleep(120);
        in.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
        send1(&in);
        Sleep(80);
        in.mi.dwFlags = MOUSEEVENTF_LEFTUP;
        send1(&in);
        GetCursorPos(&got);
        printf("clicked screen %ld,%ld (cursor now %ld,%ld)\n", p.x, p.y, got.x, got.y);
        return 0;
    }

    if (argc > 2 && !strcmp(argv[1], "key")) {
        INPUT in = {0};
        SetForegroundWindow(h);
        in.type = INPUT_KEYBOARD;
        in.ki.wScan = (WORD)strtoul(argv[2], NULL, 16);
        in.ki.dwFlags = KEYEVENTF_SCANCODE;
        send1(&in);
        Sleep(80);
        in.ki.dwFlags = KEYEVENTF_SCANCODE | KEYEVENTF_KEYUP;
        send1(&in);
        printf("key scancode 0x%02x sent\n", in.ki.wScan);
        return 0;
    }

    fprintf(stderr, "usage: game-input.exe rect | click <x> <y> | key <scancode-hex>\n");
    return 64;
}
