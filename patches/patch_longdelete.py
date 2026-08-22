#!/usr/bin/env python3
"""patch_longdelete.py — make PdxSdk's OWN long-path delete family graceful on Wine garbage-errno (the SECOND
IO layer). DiskIODefaultWindows.DeleteDirectory routes long paths (.cpatch/<guid>/... ) to DeleteLongPathDirectory,
which recurses via its own DeleteFile/RemoveDirectory (Win32) and throws on failure. Two throws:
  DeleteLongPathFile      @IL0x13 file 0x2d3f (DeleteFileW failed)
  DeleteLongPathDirectory @IL0x85 file 0x2dd5 (RemoveDirectory failed)
Both are `newobj Exception; throw; ret` -> change throw (0x7a) to pop (0x26) so it falls to ret (delete treated as
done). Was blocking StartModDownload's cleanup delete of .downloading/<id>. Reversible via .bak."""
import sys,os,shutil
def main():
    p=sys.argv[1]
    if os.path.isdir(p): p=os.path.join(p,"Cities2_Data","Managed","PDX.SDK.dll")
    d=bytearray(open(p,'rb').read()); done=[]
    for O,nm in [(0x2d3f,"DeleteLongPathFile"),(0x2dd5,"DeleteLongPathDirectory")]:
        if d[O]==0x26: print(f"  already patched: {nm}"); continue
        if d[O]!=0x7a: print(f"  UNEXPECTED 0x{d[O]:02x} at 0x{O:x} ({nm})"); sys.exit(1)
        if d[O+1]!=0x2a: print(f"  next not ret at {nm}; abort"); sys.exit(1)
        done.append((O,nm))
    if not done: print("nothing to do"); return
    if not os.path.exists(p+".bak"): shutil.copy2(p,p+".bak")
    for O,nm in done: d[O]=0x26; print(f"  patched 0x{O:x}: 7a->26 ({nm} graceful)")
    open(p,'wb').write(d)
if __name__=="__main__": main()
