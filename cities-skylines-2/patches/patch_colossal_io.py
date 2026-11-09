#!/usr/bin/env python3
"""
Automated patcher for Colossal.IO.dll (Cities: Skylines II macOS/Wine fix)

Removes the Win32 error check after FindNextFile in the
EnumerateFileSystemIterator and EnumerateFileSystemIteratorRecursive methods.

Under Wine on macOS, Marshal.GetLastWin32Error() returns random values after
FindNextFile, causing a crash on startup. This patch replaces the error check
with a branch directly to the normal "no more files" code path.

The IL pattern patched (in both methods):
    call Marshal::GetLastWin32Error()   // 28 xx xx xx xx
    stloc[.s] <var>                     // 0D or 11 xx
    ldloc[.s] <var>                     // 09 or 11 xx
    ldc.i4.s 18                         // 1F 12
    beq.s <target>                      // 2E xx
    ldloc[.s] <var>                     // 09 or 11 xx
    ldnull                              // 14
    ldstr "path"                        // 72 xx xx xx xx
    call GetExceptionFromWin32Error     // 28 xx xx xx xx
    throw                               // 7A

Replaced with:
    br.s <target>                       // 2B xx  (branch to same target as beq.s)
    nop * (remaining bytes)             // 00 ...
"""

import sys
import os
import shutil
import hashlib

EXPECTED_MATCHES = 2  # One per iterator method


def file_hash(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def find_error_check_patterns(data):
    """Find all instances of the GetLastWin32Error + throw pattern."""
    matches = []

    for i in range(len(data) - 3):
        # Look for: ldc.i4.s 18; beq.s
        if data[i] != 0x1F or data[i + 1] != 0x12 or data[i + 2] != 0x2E:
            continue

        # Look backward for 'call' opcode (0x28) within 15 bytes
        call_start = None
        for back in range(1, 15):
            if i - back >= 0 and data[i - back] == 0x28:
                call_start = i - back
                break

        if call_start is None:
            continue

        # Look forward for 'throw' opcode (0x7A) within 30 bytes
        throw_pos = None
        for fwd in range(3, 30):
            if i + fwd < len(data) and data[i + fwd] == 0x7A:
                throw_pos = i + fwd
                break

        if throw_pos is None:
            continue

        # beq.s target offset is relative to the next instruction
        beq_s_pos = i + 2  # position of beq.s opcode
        beq_s_operand = data[beq_s_pos + 1]  # signed offset

        matches.append({
            'call_start': call_start,
            'throw_pos': throw_pos,
            'beq_s_pos': beq_s_pos,
            'beq_s_target_offset': beq_s_operand,
            'length': throw_pos - call_start + 1,
            'original': bytes(data[call_start:throw_pos + 1]),
        })

    return matches


def patch_dll(dll_path):
    """Patch Colossal.IO.dll to remove Win32 error checks."""
    with open(dll_path, 'rb') as f:
        data = bytearray(f.read())

    matches = find_error_check_patterns(data)

    if len(matches) == 0:
        print("  No error check patterns found. DLL may already be patched.")
        return False

    if len(matches) != EXPECTED_MATCHES:
        print(f"  WARNING: Expected {EXPECTED_MATCHES} patterns but found {len(matches)}.")
        print(f"  The game may have been updated. Review carefully.")

    print(f"  Found {len(matches)} error check pattern(s) to patch.")

    for idx, match in enumerate(matches):
        start = match['call_start']
        end = match['throw_pos'] + 1
        length = match['length']

        # Calculate the br.s offset: we want to jump to the same target as beq.s
        # beq.s is at match['beq_s_pos'], its target = beq_s_pos + 2 + offset
        # br.s will be at 'start', its target = start + 2 + new_offset
        # So: start + 2 + new_offset = beq_s_pos + 2 + beq_s_offset
        # new_offset = beq_s_pos + beq_s_offset - start
        beq_target_absolute = match['beq_s_pos'] + 2 + match['beq_s_target_offset']
        br_s_offset = beq_target_absolute - (start + 2)

        if br_s_offset < 0 or br_s_offset > 127:
            print(f"  WARNING: Pattern {idx+1} at 0x{start:X} - branch offset {br_s_offset} out of range for br.s, skipping")
            continue

        print(f"  Patching pattern {idx+1} at file offset 0x{start:X} ({length} bytes)")

        # Replace with: br.s <offset>, then NOPs for the rest
        data[start] = 0x2B  # br.s
        data[start + 1] = br_s_offset & 0xFF
        for i in range(start + 2, end):
            data[i] = 0x00  # nop

    with open(dll_path, 'wb') as f:
        f.write(data)

    return True


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    game_root = os.path.dirname(script_dir)

    if len(sys.argv) > 1:
        game_root = sys.argv[1]

    dll_path = os.path.join(game_root, "Cities2_Data", "Managed", "Colossal.IO.dll")
    backup_path = dll_path + ".bak"

    if not os.path.exists(dll_path):
        print(f"ERROR: Cannot find {dll_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Patching: {dll_path}")

    # Create or refresh backup. If the DLL has patterns to patch (unpatched),
    # always update the backup so it matches the current game version.
    needs_patch = len(find_error_check_patterns(open(dll_path, 'rb').read())) > 0

    if needs_patch:
        shutil.copy2(dll_path, backup_path)
        if os.path.exists(backup_path):
            print(f"Backup refreshed: {backup_path}")
        else:
            print(f"Backup created: {backup_path}")
    elif not os.path.exists(backup_path):
        print(f"  (no backup needed — DLL already patched)")
    else:
        print(f"Backup exists: {backup_path}")

    if patch_dll(dll_path):
        print("\nSuccess! Colossal.IO.dll has been patched.")
    else:
        print("\nNo changes needed.")


if __name__ == '__main__':
    main()
