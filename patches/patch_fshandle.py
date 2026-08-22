#!/usr/bin/env python3
"""
patch_fshandle.py — let Wine's handle-0 through mscorlib's FileStream handle guard.

SYMPTOM: every boot, a dialog:
    [ERROR] Failed to read settings file with GUID '<...>': Invalid handle.
    Parameter name: handle
    at System.IO.FileStream.Init (SafeFileHandle safeHandle, ...)
    at System.IO.LongFile+FileStreamWithDisposeCallback..ctor

CAUSE: Wine returns file handle value 0 for a VALID open file. .NET's SafeFileHandle derives from
`SafeHandleZeroOrMinusOneIsInvalid` — a class whose entire premise ("zero is invalid") is wrong in
this environment — so `IsInvalid` is true and FileStream.Init throws.
`patch_longfile` already NOPs Colossal.IO's own throw in LongFile.GetFileHandle, so the handle now
survives that far, but mscorlib's FileStream.Init validates it AGAIN and throws. Second site.

WHY FileStream.Init AND NOT SafeHandleZeroOrMinusOneIsInvalid.get_IsInvalid:
  get_IsInvalid is a 2-byte fix but has SIX subclasses riding on it — SafeLibraryHandle,
  SafeRegistryHandle, SafeFileHandle, SafeFindHandle, SafeWaitHandle, SafeBuffer. Making zero
  "valid" for registry/wait/buffer handles is a far wider blast radius than the bug warrants.
  FileStream.Init is scoped to file streams, which is exactly where Wine's handle-0 appears.

THE PATCH (in place, 4 bytes in / 4 out, no relocation, no offset or EH shifts):
  FileStream.Init IL 0x0000:
      0000: ldarg.s 6           0e 06     ; isConsoleWrapper
      0002: brtrue.s -> 0021    2d 1d     ; skip guard when console wrapper
      0004: ldarg.1             03
      0005: callvirt get_IsInvalid
      000a: brfalse.s -> 0021             ; skip throw when handle is fine
      000c: ldstr "Invalid handle." ... 0020: throw
  becomes an unconditional jump straight past the guard:
      0000: br.s -> 0021        2b 1f
      0002: nop                 00
      0003: nop                 00
  Stack-neutral (nothing pushed, nothing to pop). The guard body 0x04-0x20 becomes unreachable
  dead code, which is legal IL. Every downstream offset is untouched.

TRADE-OFF (stated plainly): a genuinely invalid handle will no longer be rejected here with a clean
ArgumentException; it will fail later, deeper, with a less obvious error. Accepted because under
Wine the "invalid" verdict is itself unreliable — which is the whole bug.

Usage:  patch_fshandle.py <game-dir-or-mscorlib.dll> [--dry-run] [--revert]
Idempotent; pattern-matched (refuses if the IL moved); writes mscorlib.dll.bak if absent.
"""
import sys, os, shutil

ORIG  = bytes([0x0e, 0x06, 0x2d, 0x1d])   # ldarg.s 6 ; brtrue.s -> 0x21
PATCH = bytes([0x2b, 0x1f, 0x00, 0x00])   # br.s -> 0x21 ; nop ; nop
# IL 0x0005 must be `callvirt` (0x6f) and IL 0x000c `ldstr` (0x72) — fingerprint the guard.
FINGERPRINT = {4: 0x03, 5: 0x6f, 10: 0x2c, 12: 0x72}


def find_dll(arg):
    if arg.lower().endswith(".dll"):
        return arg
    for p in (os.path.join(arg, "Cities2_Data", "Managed", "mscorlib.dll"),
              os.path.join(arg, "mscorlib.dll")):
        if os.path.exists(p):
            return p
    sys.exit(f"ERROR: could not find mscorlib.dll under {arg}")


def locate(data):
    """Find FileStream.Init's guard by its byte fingerprint. Returns file offset or None."""
    hits = []
    start = 0
    while True:
        i = data.find(ORIG, start)
        if i < 0:
            break
        start = i + 1
        if all(data[i + off] == val for off, val in FINGERPRINT.items()):
            # confirm the ldstr at +12 is followed by a throw within the guard window
            if 0x7a in data[i + 12: i + 0x25]:
                hits.append(i)
    return hits


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry, revert = "--dry-run" in sys.argv, "--revert" in sys.argv
    if not args:
        sys.exit(__doc__)
    dll = find_dll(args[0])
    data = bytearray(open(dll, "rb").read())

    if revert:
        bak = dll + ".bak"
        if not os.path.exists(bak):
            sys.exit("ERROR: no .bak to revert from")
        orig = open(bak, "rb").read()
        n = 0
        for i in range(len(data) - 4):
            if bytes(data[i:i + 4]) == PATCH and orig[i:i + 4] == ORIG:
                data[i:i + 4] = ORIG; n += 1
        if not dry:
            open(dll, "wb").write(bytes(data))
        print(f"reverted {n} site(s): {dll}")
        return

    hits = locate(bytes(data))
    if not hits:
        # already patched?
        for i in range(len(data) - 4):
            if bytes(data[i:i + 4]) == PATCH and data[i + 5] == 0x6f and data[i + 12] == 0x72:
                print(f"already patched at {i:#x}: {dll}")
                return
        sys.exit("ERROR: FileStream.Init guard not found — IL has moved. Re-derive with:\n"
                 "  dis_pdx.py <mscorlib.dll> FileStream Init")
    if len(hits) != 1:
        sys.exit(f"ERROR: {len(hits)} candidate sites {[hex(h) for h in hits]} — refusing "
                 f"(expected exactly 1). Inspect before patching.")

    off = hits[0]
    bak = dll + ".bak"
    if not os.path.exists(bak) and not dry:
        shutil.copy2(dll, bak); print(f"wrote backup: {bak}")
    print(f"  site      : {off:#x} (FileStream.Init IL 0x0000)")
    print(f"  replacing : {bytes(data[off:off+4]).hex()}  (ldarg.s 6 ; brtrue.s ->0x21)")
    print(f"  with      : {PATCH.hex()}  (br.s ->0x21 ; nop ; nop)")
    if dry:
        print("DRY RUN — no bytes written."); return
    data[off:off + 4] = PATCH
    open(dll, "wb").write(bytes(data))
    print(f"PATCHED: {dll}  (FileStream no longer rejects Wine's handle-0)")


if __name__ == "__main__":
    main()
