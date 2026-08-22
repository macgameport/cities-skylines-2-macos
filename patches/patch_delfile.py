#!/usr/bin/env python3
"""patch_delfile.py — make mscorlib System.IO.FileSystem.DeleteFile tolerant of Wine's garbage
GetLastError. UnityDeleteFile fails on Wine with a garbage errno (not 2/FILE_NOT_FOUND), so File.Delete
throws spuriously (the delete really succeeded or the file was already gone) and aborts the mod download
before the content .zip is fetched. Change the throw (IL 0x1a @ file 0x15409e, 0x7a) to pop (0x26); it
then falls to the ret at 0x15409f -> delete failure treated as done. Same graceful class as patch_dirhandle."""
import sys,os,shutil
def main():
    p=sys.argv[1]
    if os.path.isdir(p): p=os.path.join(p,"Cities2_Data","Managed","mscorlib.dll")
    d=bytearray(open(p,'rb').read()); OFF=0x15409e
    if d[OFF]==0x26: print("already patched"); return
    if d[OFF]!=0x7a: print(f"UNEXPECTED 0x{d[OFF]:02x} at 0x{OFF:x}"); sys.exit(1)
    if not os.path.exists(p+".bak"): shutil.copy2(p,p+".bak")
    d[OFF]=0x26; open(p,'wb').write(d)
    print(f"patched 0x{OFF:x}: 7a->26 (File.Delete graceful on Wine garbage-errno)")
if __name__=="__main__": main()
