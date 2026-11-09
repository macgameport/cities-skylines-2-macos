/* errtest.c — does GetLastError() report the CORRECT Win32 error on FAILURE paths?
 * This is the core claim of the R1 bug report. Pure Win32; no .NET, no graphics.
 * Build: x86_64-w64-mingw32-gcc -O2 -o errtest.exe errtest.c
 * Run:   wine errtest.exe C:\errprobe
 */
#include <windows.h>
#include <stdio.h>

static int fails = 0, total = 0;
static void chk(const char *what, DWORD got, DWORD want, const char *wantname) {
    total++;
    int ok = (got == want);
    if (!ok) fails++;
    printf("  %-46s GetLastError=%-6lu expected=%-6lu %-22s %s\n",
           what, got, want, wantname, ok ? "OK" : "<<< WRONG");
}

int main(int argc, char **argv) {
    char base[MAX_PATH]; snprintf(base, sizeof base, "%s", argc > 1 ? argv[1] : "C:\\errprobe");
    CreateDirectoryA(base, NULL);

    char nx[MAX_PATH], nxdir[MAX_PATH], f[MAX_PATH], sub[MAX_PATH];
    snprintf(nx,    sizeof nx,    "%s\\does_not_exist.bin", base);
    snprintf(nxdir, sizeof nxdir, "%s\\no_such_dir",        base);
    snprintf(f,     sizeof f,     "%s\\held.bin",           base);
    snprintf(sub,   sizeof sub,   "%s\\sub",                base);

    printf("== failure-path GetLastError fidelity ==\n");

    /* 1. open a missing file */
    SetLastError(0xDEADBEEF);
    HANDLE h = CreateFileA(nx, GENERIC_READ, 0, NULL, OPEN_EXISTING, 0, NULL);
    chk("CreateFile(missing file)", GetLastError(), ERROR_FILE_NOT_FOUND, "FILE_NOT_FOUND(2)");
    if (h != INVALID_HANDLE_VALUE) CloseHandle(h);

    /* 2. open a file under a missing directory */
    char deep[MAX_PATH]; snprintf(deep, sizeof deep, "%s\\x.bin", nxdir);
    SetLastError(0xDEADBEEF);
    h = CreateFileA(deep, GENERIC_READ, 0, NULL, OPEN_EXISTING, 0, NULL);
    chk("CreateFile(under missing dir)", GetLastError(), ERROR_PATH_NOT_FOUND, "PATH_NOT_FOUND(3)");
    if (h != INVALID_HANDLE_VALUE) CloseHandle(h);

    /* 3. delete a missing file */
    SetLastError(0xDEADBEEF);
    DeleteFileA(nx);
    chk("DeleteFile(missing)", GetLastError(), ERROR_FILE_NOT_FOUND, "FILE_NOT_FOUND(2)");

    /* 4. enumerate a missing directory */
    char pat[MAX_PATH]; snprintf(pat, sizeof pat, "%s\\*", nxdir);
    WIN32_FIND_DATAA fd;
    SetLastError(0xDEADBEEF);
    HANDLE fh = FindFirstFileA(pat, &fd);
    chk("FindFirstFile(missing dir)", GetLastError(), ERROR_PATH_NOT_FOUND, "PATH_NOT_FOUND(3)");
    if (fh != INVALID_HANDLE_VALUE) FindClose(fh);

    /* 5. THE ONE THAT BREAKS .NET: error after a FindNextFile loop runs to completion */
    CreateDirectoryA(sub, NULL);
    char sp[MAX_PATH]; snprintf(sp, sizeof sp, "%s\\*", sub);
    fh = FindFirstFileA(sp, &fd);
    if (fh != INVALID_HANDLE_VALUE) {
        while (FindNextFileA(fh, &fd)) { }
        DWORD e = GetLastError();
        chk("GetLastError after FindNextFile exhausted", e, ERROR_NO_MORE_FILES, "NO_MORE_FILES(18)");
        FindClose(fh);
    } else { printf("  (could not enumerate %s)\n", sub); }

    /* 6. remove a non-empty directory */
    char inner[MAX_PATH]; snprintf(inner, sizeof inner, "%s\\inner", sub);
    CreateDirectoryA(inner, NULL);
    SetLastError(0xDEADBEEF);
    RemoveDirectoryA(sub);
    chk("RemoveDirectory(non-empty)", GetLastError(), ERROR_DIR_NOT_EMPTY, "DIR_NOT_EMPTY(145)");

    /* 7. sharing violation: open exclusively, then open again */
    h = CreateFileA(f, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
    if (h != INVALID_HANDLE_VALUE) {
        SetLastError(0xDEADBEEF);
        HANDLE h2 = CreateFileA(f, GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
        chk("CreateFile(already held exclusively)", GetLastError(), ERROR_SHARING_VIOLATION, "SHARING_VIOLATION(32)");
        if (h2 != INVALID_HANDLE_VALUE) CloseHandle(h2);
        SetLastError(0xDEADBEEF);
        DeleteFileA(f);
        chk("DeleteFile(open handle)", GetLastError(), ERROR_SHARING_VIOLATION, "SHARING_VIOLATION(32)");
        CloseHandle(h);
        DeleteFileA(f);
    }

    /* 8. remove a missing directory */
    SetLastError(0xDEADBEEF);
    RemoveDirectoryA(nxdir);
    chk("RemoveDirectory(missing)", GetLastError(), ERROR_FILE_NOT_FOUND, "FILE_NOT_FOUND(2)");

    RemoveDirectoryA(inner); RemoveDirectoryA(sub);
    printf("\n== %d/%d correct, %d WRONG ==\n", total - fails, total, fails);
    return fails;
}
