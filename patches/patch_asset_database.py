#!/usr/bin/env python3
"""
Patches Colossal.IO.AssetDatabase.dll to skip reading .priority files.

Under Wine on macOS, File.Exists() returns incorrect results, causing
FileSystemDataSource.PopulateFromDirectory to attempt reading .priority
files that don't exist, throwing FileNotFoundException.

The fix: in PopulateFromDirectory, replace 'call File::Exists' with
'pop + ldc.i4.0 + nops', so the subsequent brfalse always branches
(skipping the .priority block). This is stack-correct: pop consumes
the path argument, ldc.i4.0 pushes false for brfalse to consume.

IL before:
    ldloc.s V_7                     // push ".priority" path
    call File::Exists               // 28 xx xx xx xx  (pop path, push bool)
    brfalse IL_019F                 // 39 xx xx xx xx  (pop bool, branch if false)
    ldloc.s V_7
    call File::ReadAllLines         // 28 xx xx xx xx

IL after:
    ldloc.s V_7                     // push ".priority" path
    pop; ldc.i4.0; nop; nop; nop    // 26 16 00 00 00  (pop path, push 0)
    brfalse IL_019F                 // 39 xx xx xx xx  (pop 0 → always branches)
    ldloc.s V_7
    call File::ReadAllLines         // (now unreachable)
"""

import sys
import os
import shutil
import struct

EXPECTED_MATCHES = 1


def find_priority_file_exists_pattern(data):
    """Find the File.Exists + brfalse pattern for .priority in PopulateFromDirectory."""
    matches = []

    for i in range(len(data) - 15):
        # Look for: call (28) followed by brfalse (39) 5 bytes later
        if data[i] != 0x28 or data[i + 5] != 0x39:
            continue

        # Check if ~2 bytes after brfalse there's ldloc.s (11) then call (28)
        # brfalse is at i+5, takes 5 bytes (opcode + 4-byte offset)
        # So next instruction is at i+10
        brfalse_pos = i + 5

        # ldloc.s is at i+10 (opcode 11 xx = 2 bytes)
        if i + 10 >= len(data) or data[i + 10] != 0x11:
            continue

        # call ReadAllLines at i+12 (opcode 28 xx xx xx xx)
        if i + 12 >= len(data) or data[i + 12] != 0x28:
            continue

        # Verify this is the right context by checking for ".priority" ldstr nearby
        # Look backward for ldstr (72) within ~20 bytes
        has_priority_ldstr = False
        for back in range(5, 25):
            if i - back >= 0 and data[i - back] == 0x72:
                has_priority_ldstr = True
                break

        # Also check for Path::Combine call between ldstr and File::Exists
        has_combine_call = False
        for back in range(1, 10):
            if i - back >= 0 and data[i - back] == 0x28:
                has_combine_call = True
                break

        if has_priority_ldstr and has_combine_call:
            offset = struct.unpack_from('<i', data, brfalse_pos + 1)[0]
            matches.append({
                'file_exists_pos': i,
                'brfalse_pos': brfalse_pos,
                'brfalse_offset': offset,
            })

    return matches


def patch_dll(dll_path):
    """Patch Colossal.IO.AssetDatabase.dll to skip .priority file reading."""
    with open(dll_path, 'rb') as f:
        data = bytearray(f.read())

    matches = find_priority_file_exists_pattern(data)

    if len(matches) == 0:
        print("  No File.Exists/.priority patterns found. DLL may already be patched.")
        return False

    if len(matches) != EXPECTED_MATCHES:
        print(f"  WARNING: Expected {EXPECTED_MATCHES} pattern(s) but found {len(matches)}.")
        print(f"  The game may have been updated. Review carefully.")

    print(f"  Found {len(matches)} pattern(s) to patch.")

    for idx, match in enumerate(matches):
        file_exists_pos = match['file_exists_pos']

        print(f"  Patching pattern {idx+1}: call File::Exists at 0x{file_exists_pos:X}")

        # Replace 'call File::Exists' (5 bytes: 28 xx xx xx xx) with:
        #   pop          (26)  — consume the path argument from ldloc.s
        #   ldc.i4.0     (16)  — push false for brfalse to consume
        #   nop          (00)
        #   nop          (00)
        #   nop          (00)
        data[file_exists_pos]     = 0x26  # pop
        data[file_exists_pos + 1] = 0x16  # ldc.i4.0
        data[file_exists_pos + 2] = 0x00  # nop
        data[file_exists_pos + 3] = 0x00  # nop
        data[file_exists_pos + 4] = 0x00  # nop
        # brfalse stays unchanged — it will always branch since we pushed 0

    with open(dll_path, 'wb') as f:
        f.write(data)

    return True


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    game_root = os.path.dirname(script_dir)

    if len(sys.argv) > 1:
        game_root = sys.argv[1]

    dll_path = os.path.join(game_root, "Cities2_Data", "Managed", "Colossal.IO.AssetDatabase.dll")
    backup_path = dll_path + ".bak"

    if not os.path.exists(dll_path):
        print(f"ERROR: Cannot find {dll_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Patching: {dll_path}")

    # Create or refresh backup when DLL is unpatched (has patterns to fix)
    needs_patch = len(find_priority_file_exists_pattern(open(dll_path, 'rb').read())) > 0

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
        print("\nSuccess! Colossal.IO.AssetDatabase.dll has been patched.")
    else:
        print("\nNo changes needed.")


if __name__ == '__main__':
    main()
