/* monohost.c — run a managed assembly under CS2's EXACT Unity Mono (MonoBleedingEdge),
 * to test whether Unity's forked mono-2.0-bdwgc.dll surfaces the handle-0 bug on a plain
 * FileStream under Wine — where raw Win32, MS .NET, and standard Mono 6.12 all do NOT.
 *
 * Build:  x86_64-w64-mingw32-gcc -O2 -o scripts/monohost.exe scripts/monohost.c
 * Run (under CO wine, Steam bottle):
 *   wine monohost.exe 'Z:\...\filetest_net.exe' 'C:\monotest2'
 */
#include <windows.h>
#include <stdio.h>

#define GAME "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Cities Skylines II"
#define EMBED   GAME "\\MonoBleedingEdge\\EmbedRuntime"
#define MONODLL EMBED "\\mono-2.0-bdwgc.dll"
#define MANAGED GAME "\\Cities2_Data\\Managed"
#define MONOETC GAME "\\MonoBleedingEdge\\etc"

typedef void* MonoDomain;
typedef void* MonoAssembly;
typedef MonoDomain  (*fn_jit_init_version)(const char*, const char*);
typedef MonoAssembly(*fn_assembly_open)(MonoDomain, const char*);
typedef int         (*fn_jit_run)(MonoDomain, MonoAssembly, int, char**);
typedef void        (*fn_set_dirs)(const char*, const char*);
typedef void        (*fn_set_assemblies_path)(const char*);
typedef void        (*fn_config_parse)(const char*);

static FARPROC need(HMODULE m, const char *n) {
    FARPROC p = GetProcAddress(m, n);
    if (!p) printf("!! missing export: %s\n", n);
    return p;
}

int main(int argc, char **argv) {
    const char *asmpath = argc > 1 ? argv[1] : "Z:\\Users\\js\\Documents\\github\\cs2\\scripts\\filetest_net.exe";
    const char *basearg = argc > 2 ? argv[2] : "C:\\monotest2";

    printf("== monohost: loading Unity's mono runtime ==\n  %s\n", MONODLL);
    SetDllDirectoryA(EMBED);
    HMODULE m = LoadLibraryA(MONODLL);
    if (!m) { printf("!! LoadLibrary failed, GetLastError=%lu\n", GetLastError()); return 2; }

    fn_set_dirs            set_dirs   = (fn_set_dirs)            need(m, "mono_set_dirs");
    fn_set_assemblies_path set_asmdir = (fn_set_assemblies_path)need(m, "mono_set_assemblies_path");
    fn_config_parse        cfg_parse  = (fn_config_parse)       need(m, "mono_config_parse");
    fn_jit_init_version    jit_init   = (fn_jit_init_version)   need(m, "mono_jit_init_version");
    fn_assembly_open       asm_open   = (fn_assembly_open)      need(m, "mono_domain_assembly_open");
    fn_jit_run             jit_run    = (fn_jit_run)            need(m, "mono_jit_exec");
    if (!set_dirs || !set_asmdir || !jit_init || !asm_open || !jit_run) return 3;

    printf("== configuring: MONO_PATH=%s  etc=%s ==\n", MANAGED, MONOETC);
    set_asmdir(MANAGED);
    set_dirs(GAME "\\MonoBleedingEdge", MONOETC);
    if (cfg_parse) cfg_parse(NULL);

    printf("== mono_jit_init_version(v4.0.30319) ==\n");
    MonoDomain dom = jit_init("monohost", "v4.0.30319");
    if (!dom) { printf("!! jit_init returned NULL (runtime failed to start)\n"); return 4; }

    printf("== open assembly: %s ==\n", asmpath);
    MonoAssembly a = asm_open(dom, asmpath);
    if (!a) { printf("!! assembly_open returned NULL (couldn't load the exe)\n"); return 5; }

    printf("== running Main under Unity mono ==\n----------\n");
    char *margv[2]; margv[0] = (char*)asmpath; margv[1] = (char*)basearg;
    int rc = jit_run(dom, a, 2, margv);
    printf("----------\n== returned %d ==\n", rc);
    return rc;
}
