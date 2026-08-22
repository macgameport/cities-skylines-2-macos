#!/usr/bin/env python3
"""patch_createfile.py — base PdxSdk's LongPathFileExists/LongPathDirectoryExists on CreateFile (opening
the file) instead of GetFileAttributesW/FindFirstFile (querying metadata). THE CS2 macOS/Wine download fix.

WHY (proven 2026-07-09): under the game's concurrent IO, BOTH metadata-query APIs return a false
"exists" for a MISSING file (GetFileAttributesW -> small garbage attrs; FindFirstFile -> non-invalid
handle). So PathExists(missing .zip) is a false positive -> CheckIntegrity reads a not-yet-downloaded
file -> FileNotFound -> DownloadContent aborts before PerformDownload. BUT the very FileNotFound we see
is thrown by CreateFileStream -> new FileStream(Open) -> CreateFile, which detects the missing file
CORRECTLY every time under the same concurrency. Opening is reliable; querying is not.

FIX: rewrite both existence checks to CreateFile(OPEN_EXISTING) + SafeHandle.IsInvalid.
  LongPathFileExists : CreateFile(path, access=0, share=7, sec=0, OPEN_EXISTING, flags=0,           tmpl=0); return !IsInvalid
  LongPathDirectoryExists: same but flags=FILE_FLAG_BACKUP_SEMANTICS(0x02000000) so a DIRECTORY opens.
The returned SafeFileHandle is only queried for IsInvalid then dropped (finalizer closes it — PdxSdk has
no CloseHandle P/Invoke, and its existing CreateFile caller relies on the same GC-close). No locals
needed (IsInvalid is called on the stack result) -> TINY method header.

Tokens (PDX.SDK.dll 1.6.0f1): GetLongPath 0x06000126, CreateFile 0x0600012b (-> SafeFileHandle),
SafeHandle::get_IsInvalid 0x0a00010c. Param order verified from the sole CreateFile call site @0x30d1:
  (string name, int access, int share, IntPtr sec, int disposition, int flags, IntPtr template).
IntPtr.Zero pushed as ldc.i4.0; conv.i. Relocates both bodies into fresh .text slack, repoints
MethodDef#281/#282 RVA. Reversible via .bak. Idempotent."""
import sys, os, struct, shutil

DELTA = 0x1e00  # file-off -> RVA

# common prefix: ldarg.0; ldarg.1; call GetLongPath; ldc.i4.0(access); ldc.i4.s 7(share);
#                ldc.i4.0; conv.i (sec=Zero); ldc.i4.s 3 (OPEN_EXISTING);
PRE = bytes.fromhex("0203" "2826010006" "16" "1f07" "16d3" "1f03")
# suffix: <flags already pushed>; ldc.i4.0; conv.i (template=Zero); call CreateFile;
#         callvirt get_IsInvalid; ldc.i4.0; ceq; ret   -> !IsInvalid == exists
SUF = bytes.fromhex("16d3" "282b010006" "6f0c01000a" "16" "fe01" "2a")

FILE_IL = PRE + bytes.fromhex("16")         + SUF    # flags = 0
DIR_IL  = PRE + bytes.fromhex("2000000002") + SUF    # flags = 0x02000000 (BACKUP_SEMANTICS)
assert len(FILE_IL) == 31, len(FILE_IL)
assert len(DIR_IL)  == 35, len(DIR_IL)

def tiny(il):
    return bytes([(len(il) << 2) | 0x02]) + il

# (rvaField, il, newFileOff)
T = [(0x98306, FILE_IL, 0x191e0c),   # LongPathFileExists  (MethodDef#281)
     (0x98318, DIR_IL,  0x191e2c)]    # LongPathDirectoryExists (MethodDef#282)

def main():
    p = sys.argv[1]
    if os.path.isdir(p): p = os.path.join(p, "Cities2_Data", "Managed", "PDX.SDK.dll")
    d = bytearray(open(p, 'rb').read())
    for rvaField, il, nbo in T:
        newRVA = nbo + DELTA
        if struct.unpack_from('<I', d, rvaField)[0] == newRVA:
            print(f"  already patched (RVA {newRVA:#x})"); return
        body = tiny(il)
        if bytes(d[nbo:nbo+len(body)]) != bytes(len(body)):
            print(f"  slack at 0x{nbo:x} not free; abort"); sys.exit(1)
    if not os.path.exists(p + ".bak"): shutil.copy2(p, p + ".bak")
    for rvaField, il, nbo in T:
        body = tiny(il); newRVA = nbo + DELTA
        d[nbo:nbo+len(body)] = body
        struct.pack_into('<I', d, rvaField, newRVA)
        print(f"  relocated body -> 0x{nbo:x} (RVA {newRVA:#x}); RVA field @0x{rvaField:x} -> {newRVA:#x}  (tiny, il={len(il)}B)")
    open(p, 'wb').write(d)
    print("LongPath*Exists now use CreateFile/OPEN_EXISTING (open-based existence; reliable under Wine concurrency).")

if __name__ == "__main__":
    main()
