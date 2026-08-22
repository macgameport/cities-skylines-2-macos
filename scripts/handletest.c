/* handletest.c — does CreateFile ever return handle value 0 for a VALID file?
 * R2's claim, tested under concurrency (the condition it was originally observed under).
 * Pure Win32; no .NET. Build: x86_64-w64-mingw32-gcc -O2 -o handletest.exe handletest.c
 * Run: wine handletest.exe C:\htprobe [threads] [iters]
 */
#include <windows.h>
#include <stdio.h>

#define MAXT 16
static char base[MAX_PATH];
static volatile LONG zeros = 0, invalids = 0, opens = 0;
static UINT_PTR minh = (UINT_PTR)-1;
static CRITICAL_SECTION cs;

static DWORD WINAPI worker(LPVOID p) {
    int id = (int)(INT_PTR)p, iters = 400;
    char f[MAX_PATH];
    snprintf(f, sizeof f, "%s\\t%d.bin", base, id);
    /* create the file once so every subsequent open is of a VALID existing file */
    HANDLE c = CreateFileA(f, GENERIC_WRITE, FILE_SHARE_READ|FILE_SHARE_WRITE, NULL, CREATE_ALWAYS, 0, NULL);
    if (c != INVALID_HANDLE_VALUE) { DWORD w; WriteFile(c, "x", 1, &w, NULL); CloseHandle(c); }

    for (int i = 0; i < iters; i++) {
        HANDLE h = CreateFileA(f, GENERIC_READ, FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,
                               NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
        InterlockedIncrement(&opens);
        if (h == INVALID_HANDLE_VALUE) { InterlockedIncrement(&invalids); continue; }
        UINT_PTR v = (UINT_PTR)h;
        if (v == 0) InterlockedIncrement(&zeros);
        EnterCriticalSection(&cs); if (v < minh) minh = v; LeaveCriticalSection(&cs);
        /* interleave other file ops to stir concurrency, like the real workload */
        DWORD attr = GetFileAttributesA(f); (void)attr;
        WIN32_FIND_DATAA fd; HANDLE fh = FindFirstFileA(f, &fd);
        if (fh != INVALID_HANDLE_VALUE) FindClose(fh);
        CloseHandle(h);
    }
    return 0;
}

int main(int argc, char **argv) {
    snprintf(base, sizeof base, "%s", argc > 1 ? argv[1] : "C:\\htprobe");
    int nt = argc > 2 ? atoi(argv[2]) : 8;
    if (nt < 1) nt = 1; if (nt > MAXT) nt = MAXT;
    CreateDirectoryA(base, NULL);
    InitializeCriticalSection(&cs);

    printf("== R2 probe: does CreateFile return handle 0 for a valid file? ==\n");
    printf("   %d threads, 400 opens each, with interleaved GetFileAttributes/FindFirstFile\n\n", nt);

    HANDLE th[MAXT];
    for (int i = 0; i < nt; i++) th[i] = CreateThread(NULL, 0, worker, (LPVOID)(INT_PTR)i, 0, NULL);
    WaitForMultipleObjects(nt, th, TRUE, INFINITE);
    for (int i = 0; i < nt; i++) CloseHandle(th[i]);

    printf("   total opens attempted : %ld\n", opens);
    printf("   INVALID_HANDLE_VALUE  : %ld\n", invalids);
    printf("   handle == 0           : %ld   %s\n", zeros,
           zeros ? "<<< R2 REPRODUCED" : "(R2 not reproduced)");
    printf("   smallest handle seen  : 0x%llx (%llu)\n",
           (unsigned long long)minh, (unsigned long long)minh);
    printf("\n== %s ==\n", zeros ? "R2 REPRODUCED" : "R2 NOT reproduced under concurrency");
    return zeros ? 1 : 0;
}
