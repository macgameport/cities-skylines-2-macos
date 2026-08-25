/* steamwebhelper-shim.c — self-built replacement for the community shim on 3Shain/dxmt#141.
 *
 * Purpose: Steam's visible UI is blank under stock Wine + DXMT because CEF's GPU process
 * creates a swapchain for another process's HWND (cross-process present — unsupported, see
 * dxmt#141) and the software fallback dies on the same wall. `--in-process-gpu` moves the GPU
 * into the browser process, making the swapchain same-process — the path DXMT already handles.
 * steam.exe FILTERS that switch from its own command line (measured 2026-08-24), so it must be
 * injected where Steam can't strip it: replace steamwebhelper.exe itself.
 *
 * Install (per cef dir the client actually uses — cef.win64 for the Aug-2026 client):
 *   move steamwebhelper.exe steamwebhelper_real.exe
 *   copy this shim in as steamwebhelper.exe
 * A Steam client update restores the original — re-apply (candidate for repatch.sh).
 *
 * Mechanics that matter:
 *  - lpCmdLine (wWinMain) excludes the program name: forward it VERBATIM — Chromium passes
 *    live IPC/crashpad handle values on the command line, and inherited handles keep their
 *    values in the child, so bInheritHandles=TRUE + untouched args = working IPC.
 *  - Chromium's own subprocesses are spawned via the *running* executable's path
 *    (steamwebhelper_real.exe), so they bypass the shim; only the top-level launch is wrapped.
 *  - No wsprintf: Windows command lines run to ~32K chars, far past its 1K limit.
 *
 * Build: x86_64-w64-mingw32-gcc -O2 -mwindows -municode scripts/steamwebhelper-shim.c -o steamwebhelper.exe
 */
#include <windows.h>

#define APPEND L" --in-process-gpu"       /* default; override with SHIM_ARGS for testing */
#define CMDMAX 32768

int WINAPI wWinMain(HINSTANCE hi, HINSTANCE hp, PWSTR args, int ns)
{
    WCHAR real[MAX_PATH];
    GetModuleFileNameW(NULL, real, MAX_PATH);
    WCHAR *slash = wcsrchr(real, L'\\');
    if (!slash) return 126;
    lstrcpyW(slash + 1, L"steamwebhelper_real.exe");

    static WCHAR cmd[CMDMAX];
    lstrcpyW(cmd, L"\"");
    lstrcatW(cmd, real);
    lstrcatW(cmd, L"\" ");
    /* SHIM_ARGS lets a test run swap the injected switches without rebuilding + re-padding */
    static WCHAR extra[1024];
    if (!GetEnvironmentVariableW(L"SHIM_ARGS", extra, 1024)) lstrcpyW(extra, APPEND);
    if (lstrlenW(cmd) + lstrlenW(args) + lstrlenW(extra) + 1 >= CMDMAX) return 125;
    lstrcatW(cmd, args);
    lstrcatW(cmd, extra);

    /* optional: log the exact relaunch so a test can confirm the flag landed */
    if (GetEnvironmentVariableW(L"SHIM_LOG", NULL, 0)) {
        HANDLE lf = CreateFileW(L"C:\\shim.log", FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
                                NULL, OPEN_ALWAYS, 0, NULL);
        if (lf != INVALID_HANDLE_VALUE) {
            char buf[CMDMAX]; int n = 0;
            for (int i = 0; cmd[i] && n < CMDMAX - 2; i++) buf[n++] = (char)cmd[i];
            buf[n++] = '\n';
            DWORD wr; WriteFile(lf, buf, n, &wr, NULL); CloseHandle(lf);
        }
    }

    STARTUPINFOW si;
    GetStartupInfoW(&si);            /* forward std handles / window state as we received them */
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi;
    if (!CreateProcessW(real, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi))
        return 127;
    CloseHandle(pi.hThread);
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 0;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hProcess);
    return (int)code;
}
