#!/usr/bin/env python3
"""patch_lockbypass.py — make PdxSdk AcquireLockResult.GetError always return null so the mod download
proceeds past the AsyncReaderWriterLock's Wine-flaky acquire (SemaphoreSlim.WaitAsync throws -> "ERR_0 UNKNOWN
- Failed to acquire reader lock" -> content .zip never downloads). GetError(status) switches: 1->reader-err,
2->writer-err, 3->null(ok). Force it to ldnull;ret so the caller's `if(GetError()!=null) fail` always passes.
Lock Release runs in a finally after the op, so content downloads even if release is a no-op/throws (each mod's
files are separate -> no corruption risk). 2 bytes @ file 0x18658 (02 45 -> 14 2a). Reversible via .bak."""
import sys,os,shutil
def main():
    p=sys.argv[1]
    if os.path.isdir(p): p=os.path.join(p,"Cities2_Data","Managed","PDX.SDK.dll")
    d=bytearray(open(p,'rb').read()); O=0x18658
    if d[O:O+2]==bytes([0x14,0x2a]): print("already patched"); return
    if d[O]!=0x02 or d[O+1]!=0x45: print(f"UNEXPECTED {d[O]:02x} {d[O+1]:02x} at 0x{O:x} (want 02 45)"); sys.exit(1)
    if not os.path.exists(p+".bak"): shutil.copy2(p,p+".bak")
    d[O]=0x14; d[O+1]=0x2a; open(p,'wb').write(d)
    print(f"patched 0x{O:x}: 02 45 -> 14 2a (GetError always returns null; lock-failure check bypassed)")
if __name__=="__main__": main()
