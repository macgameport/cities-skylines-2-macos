#!/usr/bin/env python3
"""patch_delchild.py — make mscorlib FileSystem.RemoveDirectoryRecursive not rethrow a child file/subdir
delete failure. Inside the recursive walk, UnityDeleteFile failures (Wine garbage-errno) are saved to a local
and rethrown post-loop at IL 0x14d. Change that throw (0x7a) to pop -> the saved exception is discarded and
the walk continues to the (graceful) RemoveDirectoryInternal. Completes making RemoveDirectoryRecursive fully
Wine-tolerant (with patch_dirdel 0x163 + patch_dirrec_nx 0x2c). Was blocking StartModDownload's cleanup delete."""
import sys,os,shutil
def main():
    p=sys.argv[1]
    if os.path.isdir(p): p=os.path.join(p,"Cities2_Data","Managed","mscorlib.dll")
    d=bytearray(open(p,'rb').read()); O=0x154609
    if d[O]==0x26: print("already patched"); return
    if d[O]!=0x7a: print(f"UNEXPECTED 0x{d[O]:02x} at 0x{O:x}"); sys.exit(1)
    if not os.path.exists(p+".bak"): shutil.copy2(p,p+".bak")
    d[O]=0x26; open(p,'wb').write(d)
    print(f"patched 0x{O:x}: 7a->26 (child-delete failure not rethrown; recursive delete fully graceful)")
if __name__=="__main__": main()
