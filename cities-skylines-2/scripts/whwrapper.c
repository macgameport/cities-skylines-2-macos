/* steamwebhelper.exe wrapper: relaunch the real webhelper with extra Chromium flags
 * that force SOFTWARE compositing (so it presents via GDI, which works on macOS 26),
 * instead of ANGLE GPU compositing (which needs a DXVK interface DXVK 1.10.3 lacks). */
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

int WINAPI WinMain(HINSTANCE hi, HINSTANCE hp, LPSTR cmdA, int show) {
    wchar_t *full = GetCommandLineW();

    /* Skip our own argv0 (handle quotes) to get just the args Steam passed. */
    wchar_t *args = full;
    if (*args == L'"') { args++; while (*args && *args != L'"') args++; if (*args == L'"') args++; }
    else { while (*args && *args != L' ') args++; }

    /* Real webhelper is beside us as steamwebhelper_real.exe */
    wchar_t self[MAX_PATH]; GetModuleFileNameW(NULL, self, MAX_PATH);
    wchar_t *slash = wcsrchr(self, L'\\');
    wchar_t dir[MAX_PATH] = {0};
    if (slash) { size_t n = (size_t)(slash - self); if (n < MAX_PATH) { for (size_t i=0;i<n;i++) dir[i]=self[i]; dir[n]=0; } }
    wchar_t realexe[MAX_PATH];
    _snwprintf(realexe, MAX_PATH, L"%s\\steamwebhelper_real.exe", dir);

    /* Rebuild the command line + force software compositing / disable GPU + dcomp */
    static wchar_t newcmd[65536];
    _snwprintf(newcmd, 65536,
        L"\"%s\"%s --disable-gpu --disable-gpu-compositing --disable-direct-composition --disable-gpu-rasterization",
        realexe, args);

    STARTUPINFOW si; ZeroMemory(&si, sizeof(si)); si.cb = sizeof(si);
    PROCESS_INFORMATION pi;
    /* Inherit handles so Steam's IPC pipes (passed by handle value) reach the real webhelper. */
    if (!CreateProcessW(realexe, newcmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi))
        return 100;
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 0; GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hProcess); CloseHandle(pi.hThread);
    return (int)code;
}
