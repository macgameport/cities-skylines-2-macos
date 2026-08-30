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
 *   scripts/install-webhelper-shim.sh   (targets cef.win64 — the dir the Aug-2026 client runs)
 * Installed, it is a NO-OP unless SHIM_ARGS is set: it relaunches the real webhelper with the
 * command line untouched. That is deliberate — see APPEND below.
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
 * Env: SHIM_ARGS=<switches to inject> · SHIM_LOG=1 (log the relaunch) · SHIM_FONTPROBE=1
 *      (count GDI + DirectWrite families from inside Steam's tree — see font_probe below).
 * Build: x86_64-w64-mingw32-gcc -O2 -mwindows -municode scripts/steamwebhelper-shim.c \
 *          -o steamwebhelper.exe -ldwrite -lole32 -lgdi32
 */
#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <dwrite.h>

/* Default is PASS-THROUGH (inject nothing): `--in-process-gpu` was measured 2026-08-28/30 to
 * be what kills glyphs, so an installed shim must not arm it behind the daily driver's back.
 * A test cell asks for switches explicitly via SHIM_ARGS. */
#define APPEND L""
#define CMDMAX 32768

static int CALLBACK gdi_cb(const LOGFONTA *lf, const TEXTMETRICA *tm, DWORD type, LPARAM p)
{
    (void)lf; (void)tm; (void)type;
    (*(int *)p)++;
    return 1;
}

/* SHIM_FONTPROBE — count fonts from INSIDE Steam's process tree.
 *
 * This is the measurement nothing else could make. scripts/fonttest.c answers the same question but
 * runs standalone, and standalone PEs were measured 2026-08-30 to resolve their libraries fine on
 * every engine — so it has never once run under the condition that fails. The shim is a direct child
 * of steam.exe, spawned by Steam, with whatever environment Steam's tree actually has. If DirectWrite
 * reports 0 families here while fonttest.exe reports hundreds from a shell, the process tree IS the
 * variable and we can stop guessing at DYLD.
 *
 * Chromium renders text through DirectWrite (GetSystemFontCollection). An empty collection means no
 * glyphs and unaffected images/layout — exactly what a "broken" Steam client looks like. GDI is
 * counted alongside because the two can disagree, and which one is empty narrows the cause.
 */
static void log_line(const char *msg)
{
    HANDLE lf = CreateFileW(L"C:\\shim.log", FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
                            NULL, OPEN_ALWAYS, 0, NULL);
    if (lf == INVALID_HANDLE_VALUE) return;
    DWORD wr; WriteFile(lf, msg, lstrlenA(msg), &wr, NULL);
    CloseHandle(lf);
}

static void font_probe(void)
{
    char buf[512];
    HDC dc = GetDC(NULL);
    int gdi = 0;
    LOGFONTA lf; ZeroMemory(&lf, sizeof(lf)); lf.lfCharSet = DEFAULT_CHARSET;
    EnumFontFamiliesExA(dc, &lf, gdi_cb, (LPARAM)&gdi, 0);
    ReleaseDC(NULL, dc);

    UINT32 dw = 0; HRESULT hr;
    IDWriteFactory *f = NULL;
    hr = DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, &IID_IDWriteFactory, (IUnknown **)&f);
    if (SUCCEEDED(hr) && f) {
        IDWriteFontCollection *c = NULL;
        if (SUCCEEDED(IDWriteFactory_GetSystemFontCollection(f, &c, TRUE)) && c) {
            dw = IDWriteFontCollection_GetFontFamilyCount(c);
            IDWriteFontCollection_Release(c);
        } else hr = E_FAIL;
        IDWriteFactory_Release(f);
    }
    wsprintfA(buf, "[fontprobe] pid=%lu GDI=%d DWrite=%u hr=0x%08lx  (DWrite 0 => Chromium draws no text)\n",
              (unsigned long)GetCurrentProcessId(), gdi, dw, (unsigned long)hr);
    log_line(buf);
}

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
        static char buf[CMDMAX]; int n = 0;
        for (int i = 0; cmd[i] && n < CMDMAX - 2; i++) buf[n++] = (char)cmd[i];
        buf[n++] = '\n'; buf[n] = 0;
        log_line(buf);
    }

    /* SHIM_FONTPROBE: measure fonts HERE, inside Steam's tree, before handing off. Must run before
       CreateProcessW — after it we block in WaitForSingleObject until the client exits. */
    if (GetEnvironmentVariableW(L"SHIM_FONTPROBE", NULL, 0)) {
        CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
        font_probe();
        CoUninitialize();
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
