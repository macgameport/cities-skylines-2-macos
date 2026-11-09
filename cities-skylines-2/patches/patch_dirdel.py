#!/usr/bin/env python3
# patch_dirdel.py — NOP the spurious "garbage-errno after successful op" throw in Unity mscorlib's
# System.IO.FileSystem.RemoveDirectoryRecursive (fixes Directory.Delete(path, recursive:true) under Wine,
# where Wine leaves GetLastError garbage after the FindNextFile loop and Mono throws instead of removing the dir).
# One of several such sites (Directory.Move, File.Delete also affected — same root). Idempotent; writes .bak.
# Usage: patch_dirdel.py <path-to-Cities2_Data/Managed/mscorlib.dll>
import sys, shutil, os
p = sys.argv[1]
d = bytearray(open(p, 'rb').read())
OFF = 0x15461f  # the `throw` (0x7A) at IL 0x0163 of FileSystem.RemoveDirectoryRecursive; next byte 0xDE=leave.s
if d[OFF] == 0x00:
    print("already patched (nop)"); sys.exit(0)
if d[OFF] != 0x7a:
    print(f"UNEXPECTED byte 0x{d[OFF]:02x} at 0x{OFF:x} (expected 0x7a throw) — IL moved? aborting"); sys.exit(1)
if not os.path.exists(p + ".bak"): shutil.copy(p, p + ".bak")
d[OFF] = 0x00  # throw -> nop; execution falls to leave -> RemoveDirectoryInternal (non-recursive, works on Wine)
open(p, 'wb').write(d)
print(f"patched 0x{OFF:x}: 7a -> 00 (RemoveDirectoryRecursive spurious throw NOP'd)")
