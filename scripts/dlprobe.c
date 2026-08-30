/* dlprobe.c — does this dylib actually resolve, under the env a cell will run with?
 *
 * The whole point: wine dlopens its optional deps by BARE SONAME (config.h
 * SONAME_LIBFREETYPE etc.). If the name does not resolve, win32u prints one
 * WINE_MESSAGE and carries on with no font backend at all — the run then
 * renders art and no glyphs, which reads exactly like a GPU/compositing bug.
 * 39 of 41 render cells were measured in that state before anyone noticed
 * (2026-08-30). This probe makes it a precondition instead of a surprise.
 *
 * Build:  clang -arch x86_64 -o /tmp/dlprobe scripts/dlprobe.c
 * Use  :  dlprobe libfreetype.dylib libgnutls.dylib libMoltenVK.dylib
 * Exit :  0 = all resolved, 1 = at least one failed (prints which)
 *
 * -arch x86_64 is deliberate: the engine is x86_64, and an arm64 probe would
 * happily resolve an arm64 dylib the engine can never load.
 */
#include <dlfcn.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    int bad = 0;
    for (int i = 1; i < argc; i++)
    {
        void *h = dlopen(argv[i], RTLD_NOW);
        printf("%s\t%s\n", h ? "OK" : "FAIL", argv[i]);
        if (!h) { printf("\tdlerror: %s\n", dlerror()); bad = 1; }
        else dlclose(h);
    }
    return bad;
}
