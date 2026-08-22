/* filetest.c — pure-Win32 reproducer for the CS2-on-Wine "handle 0" mod-download wall.
 *
 * Mirrors what PdxSdk does when it downloads a mod: create a 2-level nested dir
 * (.downloading/<id>_<ver>/), CreateFile a content file there for WRITE, write bytes,
 * then reopen for READ. At every step it prints the RAW HANDLE VALUE returned by Wine's
 * kernel32 so we can see, with zero managed-runtime confound, whether Wine ever hands back
 * a handle of 0 (which .NET/Mono's SafeHandleZeroOrMinusOneIsInvalid rejects → the bug).
 *
 * Also dumps the std handles (STD_INPUT_HANDLE etc.) so we can test the fd-0/stdin-closed
 * theory: run this with stdin open vs closed and see if handle values shift.
 *
 * Build (on the Mac):  x86_64-w64-mingw32-gcc -O2 -o scripts/filetest.exe scripts/filetest.c
 * Run  (under CO wine, in the Steam bottle):  wine filetest.exe 'C:\some\base\dir'
 *   (no arg → uses the Windows TEMP dir). Point the arg at the real mod cache to test that path:
 *   'C:\Program Files (x86)\Steam\steamapps\common\Cities Skylines II\.cache\Mods\pdx_mods'
 */
#include <windows.h>
#include <stdio.h>

static void show_handle(const char *label, HANDLE h) {
    unsigned long long v = (unsigned long long)(ULONG_PTR)h;
    const char *verdict;
    if (h == INVALID_HANDLE_VALUE)      verdict = "INVALID_HANDLE_VALUE (-1)";
    else if (h == NULL)                 verdict = "*** NULL / 0  <-- the handle-0 bug ***";
    else                                verdict = "ok (nonzero, not -1)";
    printf("    %-22s = 0x%llx  (%llu)  %s\n", label, v, v, verdict);
}

/* Recursively ensure a directory (and all parents) exist, like `mkdir -p`. */
static void ensure_dir(const char *path) {
    char tmp[MAX_PATH]; snprintf(tmp, sizeof tmp, "%s", path);
    for (char *p = tmp + 3; *p; p++) {              /* skip drive "C:\" */
        if (*p == '\\') { *p = 0; CreateDirectoryA(tmp, NULL); *p = '\\'; }
    }
    CreateDirectoryA(tmp, NULL);
}

int main(int argc, char **argv) {
    /* stdin/fd-0 theory: what are the std handles right now? */
    printf("== std handles at startup ==\n");
    show_handle("STD_INPUT_HANDLE",  GetStdHandle(STD_INPUT_HANDLE));
    show_handle("STD_OUTPUT_HANDLE", GetStdHandle(STD_OUTPUT_HANDLE));
    show_handle("STD_ERROR_HANDLE",  GetStdHandle(STD_ERROR_HANDLE));

    /* [0] sanity: open a file that DEFINITELY exists (our own exe) for read.
     *     Proves what a *successful* CreateFile handle looks like on this Wine. */
    char selfp[MAX_PATH]; GetModuleFileNameA(NULL, selfp, sizeof selfp);
    printf("\n[0] sanity CreateFileA READ (self, must succeed): %s\n", selfp);
    HANDLE hs = CreateFileA(selfp, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    printf("    GetLastError=%lu\n", GetLastError());
    show_handle("self read handle", hs);
    if (hs != INVALID_HANDLE_VALUE && hs != NULL) CloseHandle(hs);

    char base[MAX_PATH];
    if (argc > 1) { snprintf(base, sizeof base, "%s", argv[1]); }
    else {
        char tmp[MAX_PATH]; GetTempPathA(sizeof tmp, tmp);
        snprintf(base, sizeof base, "%sfiletest", tmp);
    }
    ensure_dir(base);   /* make sure the base (and parents) exist so [1]/[2] test real nesting */
    printf("\n== base dir (ensured to exist): %s ==\n", base);

    char lvl1[MAX_PATH], lvl2[MAX_PATH], file[MAX_PATH];
    snprintf(lvl1, sizeof lvl1, "%s\\.downloading",         base);
    snprintf(lvl2, sizeof lvl2, "%s\\.downloading\\74324_36", base);
    snprintf(file, sizeof file, "%s\\content.bin",          lvl2);

    /* 1) single-level dir create */
    printf("\n[1] CreateDirectoryA level-1: %s\n", lvl1);
    BOOL d1 = CreateDirectoryA(lvl1, NULL);
    printf("    ret=%d  GetLastError=%lu %s\n", d1, GetLastError(),
           (d1 || GetLastError()==ERROR_ALREADY_EXISTS) ? "(ok/exists)" : "(FAILED)");

    /* 2) nested (2-level) dir create — PdxSdk reportedly fails HERE under Wine */
    printf("\n[2] CreateDirectoryA level-2 (nested): %s\n", lvl2);
    BOOL d2 = CreateDirectoryA(lvl2, NULL);
    printf("    ret=%d  GetLastError=%lu %s\n", d2, GetLastError(),
           (d2 || GetLastError()==ERROR_ALREADY_EXISTS) ? "(ok/exists)" : "(FAILED)");

    /* 3) CreateFile for WRITE in the nested dir — the mod-content write */
    printf("\n[3] CreateFileA WRITE: %s\n", file);
    HANDLE hw = CreateFileA(file, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    printf("    GetLastError=%lu\n", GetLastError());
    show_handle("write handle", hw);
    if (hw != INVALID_HANDLE_VALUE && hw != NULL) {
        const char *msg = "hello from filetest\n";
        DWORD wrote = 0; BOOL wr = WriteFile(hw, msg, (DWORD)strlen(msg), &wrote, NULL);
        printf("    WriteFile ret=%d wrote=%lu GetLastError=%lu\n", wr, wrote, GetLastError());
        CloseHandle(hw);
    } else {
        printf("    -> could not open for write; skipping WriteFile\n");
    }

    /* 4) CreateFile for READ (the settings-read / re-open path) */
    printf("\n[4] CreateFileA READ: %s\n", file);
    HANDLE hr = CreateFileA(file, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    printf("    GetLastError=%lu\n", GetLastError());
    show_handle("read handle", hr);
    if (hr != INVALID_HANDLE_VALUE && hr != NULL) {
        char buf[64]; DWORD got = 0; BOOL rd = ReadFile(hr, buf, sizeof buf - 1, &got, NULL);
        if (rd) { buf[got] = 0; }
        printf("    ReadFile ret=%d got=%lu GetLastError=%lu content=\"%.*s\"\n",
               rd, got, GetLastError(), (int)got, rd ? buf : "");
        CloseHandle(hr);
    } else {
        printf("    -> could not open for read; skipping ReadFile\n");
    }

    printf("\n== done ==\n");
    return 0;
}
