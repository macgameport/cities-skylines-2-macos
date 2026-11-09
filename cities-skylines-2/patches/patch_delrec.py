#!/usr/bin/env python3
"""patch_delrec.py — make mscorlib FileSystem.RemoveDirectoryInternal graceful on Wine garbage-errno.
Directory.Delete's final removal (and non-recursive delete) throws "I/O error occurred" when Wine returns a
garbage errno that matches none of the expected codes (2/3/5). Change the generic throw (IL 0x52 @ file
0x1546ca, 0x7a) to pop -> falls to the ret at 0x1546cb (0x2a) -> delete treated as done. Complements
patch_dirdel (recursive post-loop) + patch_delfile (File.Delete). Was aborting StartModDownload's cleanup
delete of .downloading/<id>, blocking the content download."""
import sys,os,shutil
def main():
    p=sys.argv[1]
    if os.path.isdir(p): p=os.path.join(p,"Cities2_Data","Managed","mscorlib.dll")
    d=bytearray(open(p,'rb').read()); O=0x1546ca
    if d[O]==0x26: print("already patched"); return
    if d[O]!=0x7a: print(f"UNEXPECTED 0x{d[O]:02x} at 0x{O:x}"); sys.exit(1)
    if d[O+1]!=0x2a: print(f"WARN next byte not ret (0x{d[O+1]:02x}) — aborting"); sys.exit(1)
    if not os.path.exists(p+".bak"): shutil.copy2(p,p+".bak")
    d[O]=0x26; open(p,'wb').write(d)
    print(f"patched 0x{O:x}: 7a->26 (RemoveDirectoryInternal graceful; falls to ret)")
if __name__=="__main__": main()
