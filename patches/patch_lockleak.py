#!/usr/bin/env python3
"""
patch_lockleak.py — release the per-path file lock that PdxSdk leaks on any IO exception.

ROOT CAUSE (verified 2026-08-21 by disassembly + EH-table read, supersedes the
"reader->writer upgrade deadlock" theory in change-ledger.txt):

  PDX.SDK.dll  <CreateFileStream>d__25.MoveNext   (FileIO::CreateFileStream state machine)

  IL 0x6c-0x87:  if (access == Read) AcquireReaderLock else AcquireWriterLock
                 -> the two are MUTUALLY EXCLUSIVE branches. There is no reader->writer
                    upgrade, so there is no self-deadlock. All four prior lock patches
                    (locksem / writenowait / readerinit / readerskip) targeted a bug that
                    does not exist, which is why each failed or broke boot.

  The lock is NOT released by this method on success -- it is wrapped into the returned
  stream (IL 0x197-0x19e) and released when the caller disposes that stream.

  Exception-handler table for the method:
      [0] CATCH try 0x0049..0x01a6  handler 0x01a6..0x01d6  (Exception)
      [1] CATCH try 0x000e..0x01d6  handler 0x01d6..0x01ef  (Exception)
      -> NO finally clause anywhere.

  The lock is acquired at 0x78/0x82, INSIDE try[0]. The FileNotFound path disposes it
  correctly (IL 0x11e-0x120: ldloc.s 5; callvirt Dispose). The CATCH handler does NOT.

  So when Wine's garbage-errno makes CreateDirectory (0x16f) or the real
  CreateFileStream (0x192) throw, the per-path lock is leaked forever. Every later
  operation on that same path then waits on a lock nobody holds a release for; because
  FileIO::GetLockToken builds a CancellationTokenSource(TimeSpan.FromSeconds(N)) --
  a TIMEOUT -- the wait is cancelled and SemaphoreSlim.WaitAsync THROWS. That is exactly
  the observed Player.log stack:
      AcquireWriterLockInner d__8 -> SemaphoreSlim.WaitUntilCountOrTimeoutAsync -> SetException

  It also explains why manifests/thumbnails wrote fine (different paths, never leaked)
  and why neutering the lock globally crashed boot (Colossal.IO.AssetDatabase relies on
  real locking -- the locking is correct, only the leak is the bug).

THE FIX (in-place, no relocation, no EH edits, stack-neutral):

  Overwrite the catch handler's redundant inner Log call (IL 0x1af..0x1cc, 30 bytes)
  with a null-guarded dispose of the lock + nop padding:

      ldloc.s   5              11 05      ; the AcquireLockResult (null if we threw before 0xe9)
      brfalse.s +7             2c 07      ; skip if never acquired
      ldloc.s   5              11 05
      callvirt  Dispose        6f <tok>   ; same token the 0x120 path already uses
      nop * 19                 00 ...

  Exactly 30 bytes in, 30 bytes out -> every IL offset, branch target and EH clause
  offset is unchanged. The error still propagates: CreateIoResultFromException (0x1aa)
  already ran, and the caller logs the failure, so diagnosis is preserved.

Usage:  patch_lockleak.py <game-dir-or-PDX.SDK.dll> [--dry-run] [--revert]
Idempotent. Writes PDX.SDK.dll.bak on first run if absent.
"""
import sys, os, shutil

# IL 0x1af..0x1cc of <CreateFileStream>d__25.MoveNext, as file offsets in CS2 1.6.0f1.
# Verified against the shipped DLL; the script pattern-matches rather than trusting these.
LOG_START = 0x2FBFF   # IL 0x1af  (ldloc.1)
LOG_LEN   = 30        # through IL 0x1cc inclusive; IL 0x1cd (ldnull) must follow
DISPOSE_CALLSITE = 0x2FB70  # IL 0x120: callvirt Dispose -> token at +1

# Original 30 bytes: ldloc.1 / ldfld / ldloc.s 8 / callvirt ToString / ldc.i4.3 /
#                    ldarg.0 / ldfld / ldstr / callvirt Log
ORIG_PREFIX = bytes([0x07, 0x7B])          # ldloc.1 ; ldfld
ORIG_TAIL   = bytes([0x14])                # IL 0x1cd = ldnull (must follow the run)


def build_patch(dispose_tok: bytes) -> bytes:
    body = bytes([0x11, 0x05,              # ldloc.s 5
                  0x2C, 0x07,              # brfalse.s -> skip (7 bytes ahead)
                  0x11, 0x05]) + \
           bytes([0x6F]) + dispose_tok     # callvirt Dispose
    assert len(body) == 11, len(body)
    return body + b"\x00" * (LOG_LEN - len(body))


def find_dll(arg: str) -> str:
    if arg.lower().endswith(".dll"):
        return arg
    p = os.path.join(arg, "Cities2_Data", "Managed", "PDX.SDK.dll")
    if os.path.exists(p):
        return p
    p2 = os.path.join(arg, "PDX.SDK.dll")
    if os.path.exists(p2):
        return p2
    sys.exit(f"ERROR: could not find PDX.SDK.dll under {arg}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    revert = "--revert" in sys.argv
    if not args:
        sys.exit(__doc__)
    dll = find_dll(args[0])
    data = bytearray(open(dll, "rb").read())

    if len(data) < LOG_START + LOG_LEN + 1:
        sys.exit("ERROR: file too small — wrong DLL?")

    run = bytes(data[LOG_START:LOG_START + LOG_LEN])
    nxt = bytes(data[LOG_START + LOG_LEN:LOG_START + LOG_LEN + 1])

    # Read the Dispose token from the callsite the game already uses at IL 0x120.
    if data[DISPOSE_CALLSITE] != 0x6F:
        sys.exit(f"ERROR: expected callvirt (0x6f) at {DISPOSE_CALLSITE:#x}, "
                 f"found {data[DISPOSE_CALLSITE]:#04x} — IL has moved; re-derive offsets.")
    dispose_tok = bytes(data[DISPOSE_CALLSITE + 1:DISPOSE_CALLSITE + 5])
    patched = build_patch(dispose_tok)

    if run == patched:
        print(f"already patched: {dll}")
        if not revert:
            return
    if revert:
        bak = dll + ".bak"
        if not os.path.exists(bak):
            sys.exit("ERROR: no .bak to revert from")
        orig = open(bak, "rb").read()
        data[LOG_START:LOG_START + LOG_LEN] = orig[LOG_START:LOG_START + LOG_LEN]
        if not dry:
            open(dll, "wb").write(bytes(data))
        print(f"reverted lockleak region from .bak: {dll}")
        return

    if nxt != ORIG_TAIL or run[:2] != ORIG_PREFIX:
        sys.exit(
            f"ERROR: pattern mismatch at {LOG_START:#x} — refusing to patch.\n"
            f"  found run[:2] = {run[:2].hex()} (want {ORIG_PREFIX.hex()})\n"
            f"  found next    = {nxt.hex()} (want {ORIG_TAIL.hex()})\n"
            f"  The game likely updated; re-derive with dis_pdx.py "
            f"'<CreateFileStream>d__25' MoveNext."
        )

    bak = dll + ".bak"
    if not os.path.exists(bak) and not dry:
        shutil.copy2(dll, bak)
        print(f"wrote backup: {bak}")

    print(f"  Dispose token : {dispose_tok[::-1].hex()} (from IL 0x120 callsite)")
    print(f"  replacing     : {run.hex()}")
    print(f"  with          : {patched.hex()}")
    if dry:
        print("DRY RUN — no bytes written.")
        return
    data[LOG_START:LOG_START + LOG_LEN] = patched
    open(dll, "wb").write(bytes(data))
    print(f"PATCHED: {dll}  (catch handler now releases the leaked per-path file lock)")


if __name__ == "__main__":
    main()
