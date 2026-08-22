#!/usr/bin/env python3
"""patch_dirrec_nx.py — make mscorlib FileSystem.RemoveDirectoryRecursive graceful when the target dir
doesn't exist (Wine garbage-errno). On a nonexistent dir, UnityFindFirstFile returns invalid -> the code
throws (IL 0x26: ldarg.0; call GetExceptionForLastWin32Error; throw). Redirect that to the method's own
leave (IL 0x164 -> finally -> RemoveDirectoryInternal, now graceful via patch_delrec) so it no-ops instead
of aborting. In-place 7->7 bytes (EH offsets unchanged). Fixes StartModDownload's cleanup delete of the
not-yet-created .downloading/<id>, which was blocking the content download. Verified game 1.6.0f1."""
import sys,os,shutil
def main():
    p=sys.argv[1]
    if os.path.isdir(p): p=os.path.join(p,"Cities2_Data","Managed","mscorlib.dll")
    d=bytearray(open(p,'rb').read()); O=0x1544e2
    orig=bytes.fromhex("0228d66600067a"); new=bytes.fromhex("38390100000000")
    if bytes(d[O:O+7])==new: print("already patched"); return
    if bytes(d[O:O+7])!=orig: print(f"UNEXPECTED {bytes(d[O:O+7]).hex()} at 0x{O:x}"); sys.exit(1)
    if not os.path.exists(p+".bak"): shutil.copy2(p,p+".bak")
    d[O:O+7]=new; open(p,'wb').write(d)
    print(f"patched 0x{O:x}: FindFirstFile-invalid throw -> br to graceful leave (nonexistent recursive delete = no-op)")
if __name__=="__main__": main()
