#!/usr/bin/env python3
"""
patch_mkparent.py — make PdxSdk's DiskIODefaultWindows.CreateFileStream create the parent
directory before opening the stream (CS2 macOS/Wine Paradox-Mods download fix).

Root cause: the mod download writes into nested dirs (.downloading/<id>/.metadata/,
.cpatch/<guid>/<ver>/-1_to_<ver>/) that PdxSdk never creates on this stack, so
FileStream throws DirectoryNotFoundException and the download aborts (thumbnail/manifest/
.zip never land). An external mkdir watcher can't win the in-process create->write race.
Fix it in-process: prepend  Directory.CreateDirectory(Path.GetDirectoryName(path))  to
DiskIODefaultWindows.CreateFileStream so the parent always exists before the write. Race-free,
idempotent (CreateDirectory is a no-op if the dir exists).

Mechanics (verified game 1.6.0f1, PDX.SDK.dll): CreateFileStream = MethodDef#278, tiny header,
no EH, instance method (this,path,mode,access,share). Original 38-byte IL:
  ldarg.0; ldarg.1; call IsLongPath; brtrue.s L; ldarg.0; ldarg.1; call GetCleanPath;
  ldarg.2; ldarg.3; ldarg.s 4; newobj FileStream; ret; L: ...CreateLongPathFileStream...; ret
We PREPEND (12 bytes, no branches so the original's relative brtrue is unaffected):
  ldarg.1; call Path.GetDirectoryName(0a0000f1); call Directory.CreateDirectory(0a0000ed); pop
New body (50 IL bytes) still fits a TINY header. Since a method body can't grow in place, we
RELOCATE it into .text zero-slack and repoint MethodDef#278's RVA. Fully reversible via .bak.
"""
import sys, os, shutil, struct

METHOD_ROW_RVA_OFF = 0x982d0     # file offset of MethodDef#278's 4-byte RVA field
OLD_RVA            = 0x4a42
OLD_HDR_OFF        = 0x2c42      # tiny header of the original body
ORIG_IL = bytes.fromhex(
    "020328250100062d110203282701000604050e0473ee00000a2a020304050e0428240100062a")
NEW_BODY_FILE_OFF  = 0x191868    # 4-byte-aligned .text slack
NEW_BODY_RVA       = 0x193668

# prelude: ldarg.1 ; call Path.GetDirectoryName ; call Directory.CreateDirectory ; pop
PRELUDE = bytes.fromhex("03" + "28f100000a" + "28ed00000a" + "26")
NEW_IL  = PRELUDE + ORIG_IL
assert len(PRELUDE)==12, len(PRELUDE)
assert len(ORIG_IL)==38, len(ORIG_IL)
assert len(NEW_IL)==50, len(NEW_IL)
TINY_HDR = bytes([ (len(NEW_IL) << 2) | 0x02 ])   # 0xCA
NEW_METHOD = TINY_HDR + NEW_IL                    # 51 bytes

def main():
    if len(sys.argv) < 2:
        print("usage: patch_mkparent.py <PDX.SDK.dll | game-dir>"); sys.exit(2)
    p = sys.argv[1]
    if os.path.isdir(p): p = os.path.join(p, "Cities2_Data", "Managed", "PDX.SDK.dll")
    if not os.path.isfile(p): print("PDX.SDK.dll not found:", p); sys.exit(1)
    d = bytearray(open(p, "rb").read())

    cur_rva = struct.unpack_from("<I", d, METHOD_ROW_RVA_OFF)[0]
    if cur_rva == NEW_BODY_RVA:
        print("already patched (RVA repointed)."); return
    if cur_rva != OLD_RVA:
        print(f"UNEXPECTED MethodDef#278 RVA 0x{cur_rva:x} (expected 0x{OLD_RVA:x}) — different build? aborting"); sys.exit(1)
    # verify original body header+IL
    if d[OLD_HDR_OFF] != ((38<<2)|0x02):
        print(f"UNEXPECTED tiny header 0x{d[OLD_HDR_OFF]:02x} at 0x{OLD_HDR_OFF:x} (expected 0x9a) — aborting"); sys.exit(1)
    if bytes(d[OLD_HDR_OFF+1:OLD_HDR_OFF+1+38]) != ORIG_IL:
        print("UNEXPECTED original IL — aborting"); sys.exit(1)
    # verify slack is free (zero)
    if bytes(d[NEW_BODY_FILE_OFF:NEW_BODY_FILE_OFF+len(NEW_METHOD)]) != bytes(len(NEW_METHOD)):
        print("slack not zero — aborting to avoid clobbering"); sys.exit(1)

    if not os.path.exists(p + ".bak"):
        shutil.copy2(p, p + ".bak")
    d[NEW_BODY_FILE_OFF:NEW_BODY_FILE_OFF+len(NEW_METHOD)] = NEW_METHOD
    struct.pack_into("<I", d, METHOD_ROW_RVA_OFF, NEW_BODY_RVA)
    open(p, "wb").write(d)
    print(f"patched: relocated CreateFileStream body to RVA 0x{NEW_BODY_RVA:x} (+CreateDirectory prelude);"
          f" MethodDef#278 RVA 0x{OLD_RVA:x} -> 0x{NEW_BODY_RVA:x}")

if __name__ == "__main__":
    main()
