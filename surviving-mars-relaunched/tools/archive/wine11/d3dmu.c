/* d3dmu.c -- d3dmu.dll: lets D3DMetal's prebuilt DLLs run on Wine 11.
 *
 * D3DMetal's four Windows-side DLLs (atidxx64, d3d11, d3d12, dxgi; Game Porting Toolkit / CrossOver
 * 26) import exactly two functions from ntdll: NtQueryVirtualMemory and __wine_unix_call. Wine 11
 * stopped exporting __wine_unix_call (its header makes it an inline over __wine_unix_call_dispatcher),
 * so on Wine 11.16 the game aborts at start with "unimplemented function ntdll.dll.__wine_unix_call".
 * Re-adding that export to ntdll is no fix: Steam then crashes at start (A/B on the unified-stack
 * probe, 2026-11-07). So ntdll stays stock, and tools/make-engine.sh renames the import in those four
 * DLLs, in the engine copy only, from "ntdll.dll" to "d3dmu.dll" (same length, the only occurrence in
 * each). This DLL forwards NtQueryVirtualMemory to ntdll and implements __wine_unix_call the way
 * Wine 10's ntdll did: a call through the dispatcher pointer ntdll still exports.
 *
 * Build:  x86_64-w64-mingw32-gcc -O2 -Wall -shared -nostdlib -o tools/d3dmu.dll tools/d3dmu.c \
 *           tools/d3dmu.def -lkernel32
 *         then make-engine.sh stamps "Wine builtin DLL" at 0x40, as winebuild --builtin does, so Wine
 *         loads it from the engine's lib/wine/x86_64-windows like the DLLs that import it.
 */
#include <windows.h>

typedef UINT64 unixlib_handle_t;
typedef LONG (WINAPI *unix_call_fn)( unixlib_handle_t, unsigned int, void * );

static unix_call_fn dispatcher;

LONG WINAPI d3dmu_unix_call( unixlib_handle_t handle, unsigned int code, void *args )
{
    if (!dispatcher)
    {
        /* ntdll exports the pointer variable itself, set by its unix side at process start */
        unix_call_fn *p = (unix_call_fn *)GetProcAddress( GetModuleHandleW( L"ntdll.dll" ),
                                                          "__wine_unix_call_dispatcher" );
        if (!p || !*p) return 0xc0000002;   /* STATUS_NOT_IMPLEMENTED */
        dispatcher = *p;
    }
    return dispatcher( handle, code, args );
}

BOOL WINAPI DllMainCRTStartup( HINSTANCE inst, DWORD reason, void *reserved )
{
    return TRUE;
}
