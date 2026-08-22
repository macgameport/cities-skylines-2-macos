#!/usr/bin/env python3
"""
patch_dirhandle.py — make Unity mscorlib's
System.IO.Enumeration.FileSystemEnumerator`1.CreateDirectoryHandle enumerate an
un-openable directory as EMPTY instead of throwing, working around Wine's garbage
Win32 last-error (CS2 macOS/Wine Paradox-Mods download fix).

Symptom: subscribed Paradox mods never install. PdxSdk.log floods with
    [ModsPatching.PrepareFolderForPatching][PerformDiskOperationAndCatch] System.IO.IOException: Success
    ... at FileSystemEnumerator`1.CreateDirectoryHandle (path, ignoreNotFound)
    ... at Directory.GetDirectories(path)  <- ClearFolderAndKeepPatchFile <- PrepareFolderForPatching
so the download aborts before it ever fetches content.

Flow: PrepareFolderForPatching calls ClearFolderAndKeepPatchFile (which does
Directory.GetDirectories on `.cache/Mods/pdx_mods/.downloading/<id>`) BEFORE it creates
that folder. On a fresh download the folder does not exist, so CreateDirectoryHandle's
CreateFile(OPEN_EXISTING) fails and it runs:
    err = GetLastWin32Error();
    if (ContinueOnDirectoryError(err, ignoreNotFound)) return IntPtr.Zero;  // benign -> enumerate empty
    if (err == 2) err = 3;
    throw GetExceptionForWin32Error(err, path);
On Windows err would be 2/3 (not-found) and ContinueOnDirectoryError returns true ->
graceful empty enumeration. Under Wine the failed CreateFile leaves GetLastError =
UNINITIALISED GARBAGE (observed values: 0/"Success", 0x8ac04080, 0xa37076d0, ... — it
varies per call), so ContinueOnDirectoryError(garbage, ...) returns FALSE and it THROWS.
Same "Wine returns bad Win32 values" class as patch_longfile, but the garbage is
NON-DETERMINISTIC, so an err==specific-value fix does not work.

Fix: force the graceful path. At IL 0x38 the result of ContinueOnDirectoryError is tested
with `brfalse.s -> throw-path`. Replace it with `pop ; nop` so the (unreliable) decision is
discarded and execution always falls through to the existing `return IntPtr.Zero` at IL 0x3a.
The FileSystemEnumerator ctor already treats a null handle as "empty enumeration" (this is
CoreFX's own ignoreNotFound behaviour), so an un-openable dir now enumerates empty instead of
throwing. Successful opens (nonzero handle) are unaffected — they never reach this branch, so
normal enumeration of real directories is unchanged (verified: probe [11] all-OK).

Behaviour change: Directory.GetDirectories/GetFiles/Enumerate* on a directory that cannot be
opened now returns empty instead of throwing DirectoryNotFound/IOException. Benign for the mod
pipeline (missing `.downloading/<id>` -> nothing to clear -> proceed to create + download) and
for typical callers (which check Exists first). Vanilla is the safety net either way.

Verified against game 1.6.0f1: CreateDirectoryHandle IL @ file 0x16cc68;
ContinueOnDirectoryError brfalse.s @ IL 0x38 / file 0x16cca0.
Idempotent; writes .bak. (Also self-heals the earlier handle-0 / errno-0 experiments if present.)
"""
import sys, os, shutil

# revert the two earlier experimental edits (handle-0 @0x1a, errno-0 @0x40) back to stock, then
# apply the real fix (@0x38). Each entry: (offset, from_bytes, to_bytes, desc)
REVERTS = [
    (0x16cc82, bytes([0x26, 0x00]), bytes([0x2d, 0x0e]), "revert handle-0 experiment (IL 0x1a)"),
    (0x16cca8, bytes([0x07, 0x2c, 0xf7, 0x00, 0x00, 0x00]),
               bytes([0x07, 0x18, 0x33, 0x02, 0x19, 0x0b]), "revert errno-0 experiment (IL 0x40)"),
]
FIX = (0x16cca0, bytes([0x2c, 0x06]), bytes([0x26, 0x00]),
       "force graceful empty on any dir-open error (IL 0x38 brfalse.s -> pop;nop)")

def main():
    if len(sys.argv) < 2:
        print("usage: patch_dirhandle.py <path-to-mscorlib.dll | game-dir>"); sys.exit(2)
    p = sys.argv[1]
    if os.path.isdir(p):
        p = os.path.join(p, "Cities2_Data", "Managed", "mscorlib.dll")
    if not os.path.isfile(p):
        print(f"mscorlib.dll not found at {p}"); sys.exit(1)
    d = bytearray(open(p, "rb").read())
    if not os.path.exists(p + ".bak"):
        shutil.copy2(p, p + ".bak")

    # self-heal earlier experiments (no-op if never applied)
    for off, frm, to, desc in REVERTS:
        if bytes(d[off:off+len(frm)]) == frm:
            d[off:off+len(to)] = to
            print(f"  reverted 0x{off:x}: {desc}")

    off, orig, patched, desc = FIX
    cur = bytes(d[off:off+len(orig)])
    if cur == patched:
        print(f"  already patched: {desc}")
    elif cur != orig:
        print(f"  UNEXPECTED bytes {cur.hex()} at 0x{off:x} (expected {orig.hex()}) — "
              f"IL moved / different build? aborting [{desc}]"); sys.exit(1)
    else:
        d[off:off+len(patched)] = patched
        print(f"  patched 0x{off:x}: {orig.hex()} -> {patched.hex()}  ({desc})")

    open(p, "wb").write(d)
    print("CreateDirectoryHandle now enumerates un-openable dirs as empty (Wine garbage-errno tolerant).")

if __name__ == "__main__":
    main()
