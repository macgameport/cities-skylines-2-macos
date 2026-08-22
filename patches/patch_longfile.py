#!/usr/bin/env python3
"""
Patches Colossal.IO.dll -> System.IO.LongFile.GetFileHandle (CS2 macOS/Wine fix).

Symptom: an in-game "IOException ... <settings file>.coc: Success." dialog when
reading settings (e.g. adjusting music volume), coming from LongFile.GetFileHandle
-> LongFile.Open -> LongFile.OpenRead -> FileSystemDataSource.GetReadStream.

Root cause: under Wine on macOS, CreateFile returns a *handle value of 0* for a
successfully opened file. .NET's SafeFileHandle.IsInvalid treats 0 as invalid, so
GetFileHandle throws even though GetLastWin32Error() == 0 ("Success") and the
handle is actually usable by Wine's ReadFile. (Same class of Wine errno/handle
bug the enumerate-iterator patch fixes, but in a method that patch doesn't cover.)

Fix: NOP out the throw block so a "0-but-valid" handle is returned instead of
thrown. The IsInvalid check and the dup'd isAppend bool on the stack are left
intact, so both paths reach the append-seek check (IL 0037) with a balanced stack.

IL (verified against game 1.6.0f1):
    ...
    callvirt SafeFileHandle::get_IsInvalid   6f xx xx xx xx
    brfalse.s +7  (skip throw when "valid")   2c 07
    ldarg.0                                    02
    call GetExceptionFromLastWin32Error        28 xx xx xx xx
    throw                                      7a
    brfalse.s ... (isAppend -> SetFilePointer) 2c 0a
Patched: the 7 bytes  02 28 xx xx xx xx 7a  ->  00 00 00 00 00 00 00  (nops)
"""

import sys, os, shutil

EXPECTED_MATCHES = 1

# 6f <tok> 2c 07 02 28 <tok> 7a   (None = wildcard token bytes)
PATTERN = [0x6f, None, None, None, None, 0x2c, 0x07, 0x02, 0x28, None, None, None, None, 0x7a]
NOP_START = 7   # index of ldarg.0 within the pattern
NOP_END   = 14  # exclusive -> nops indices 7..13 (ldarg.0 + call(5) + throw = 7 bytes)


def matches_at(data, i, pat):
    for j, p in enumerate(pat):
        if p is not None and data[i + j] != p:
            return False
    return True


def find_pattern(data, pat):
    return [i for i in range(len(data) - len(pat)) if matches_at(data, i, pat)]


def is_patched(data):
    patched = list(PATTERN)
    for k in range(NOP_START, NOP_END):
        patched[k] = 0x00
    return len(find_pattern(data, patched)) > 0


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    game_root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(script_dir)
    dll = os.path.join(game_root, "Cities2_Data", "Managed", "Colossal.IO.dll")

    if not os.path.exists(dll):
        print(f"ERROR: Cannot find {dll}", file=sys.stderr)
        sys.exit(1)

    print(f"Patching: {dll}")
    data = bytearray(open(dll, 'rb').read())

    if is_patched(data):
        print("  Already patched (GetFileHandle throw NOP'd).")
        return

    matches = find_pattern(data, PATTERN)
    if not matches:
        print("  WARNING: GetFileHandle throw pattern not found — game may have")
        print("  updated its LongFile IL. No change made.")
        return
    if len(matches) != EXPECTED_MATCHES:
        print(f"  WARNING: expected {EXPECTED_MATCHES} match, found {len(matches)}; patching all.")

    # Preserve the pristine original backup made by patch_colossal_io.py; only
    # create .bak here if none exists (standalone use).
    bak = dll + ".bak"
    if not os.path.exists(bak):
        shutil.copy2(dll, bak)
        print(f"  Backup created: {bak}")

    for m in matches:
        print(f"  Patching GetFileHandle throw at file offset 0x{m + NOP_START:X} (7 bytes -> nop)")
        for k in range(NOP_START, NOP_END):
            data[m + k] = 0x00

    open(dll, 'wb').write(data)
    print("\nSuccess! Colossal.IO.dll LongFile.GetFileHandle patched.")


if __name__ == '__main__':
    main()
