#!/usr/bin/env python3
"""
Patches cohtml_Unity3DPlugin.dll to fix a crash during UI initialization.

The Cohtml rendering plugin has a branch in its IAllocator initialization
that takes the wrong code path under Wine/GPTK on macOS, causing a crash
before the game reaches the main menu.

The fix: flip a 'je' (jump if equal, 0F 84) to 'jne' (jump if not equal,
0F 85) so the correct code path is taken.

Pattern (from https://github.com/manolz1/cities2-gptk-fix):
    CC 40 ?? 48 ?? ?? ?? 80 ?? ?? ?? 48 ?? ?? 0F 84
                                                  ^^
    The byte at offset +15 (0x84) is changed to 0x85.
"""

import sys
import os
import shutil

EXPECTED_MATCHES = 1

# Pattern bytes: None = wildcard
PATTERN = [0xCC, 0x40, None, 0x48, None, None, None, 0x80, None, None, None, 0x48, None, None, 0x0F, 0x84]
PATCH_OFFSET = 15  # Offset within the pattern to patch
ORIGINAL_BYTE = 0x84
PATCHED_BYTE = 0x85


def find_pattern(data):
    """Find all occurrences of the signature pattern."""
    matches = []
    for i in range(len(data) - len(PATTERN)):
        match = True
        for j, p in enumerate(PATTERN):
            if p is not None and data[i + j] != p:
                match = False
                break
        if match:
            matches.append(i)
    return matches


def find_patched(data):
    """Check if the pattern has already been patched (0x85 instead of 0x84)."""
    patched = list(PATTERN)
    patched[PATCH_OFFSET] = PATCHED_BYTE
    for i in range(len(data) - len(patched)):
        match = True
        for j, p in enumerate(patched):
            if p is not None and data[i + j] != p:
                match = False
                break
        if match:
            return True
    return False


def patch_dll(dll_path):
    """Patch cohtml_Unity3DPlugin.dll."""
    with open(dll_path, 'rb') as f:
        data = bytearray(f.read())

    if find_patched(data):
        print("  Already patched (je -> jne).")
        return False

    matches = find_pattern(data)

    if len(matches) == 0:
        print("  WARNING: Pattern not found. The game may have been updated.")
        print("  Check https://github.com/manolz1/cities2-gptk-fix for updates.")
        return False

    if len(matches) != EXPECTED_MATCHES:
        print(f"  WARNING: Expected {EXPECTED_MATCHES} match but found {len(matches)}. Patching first only.")

    target = matches[0] + PATCH_OFFSET
    print(f"  Pattern found at 0x{matches[0]:X}, patching byte at 0x{target:X}")
    print(f"  Changing 0x{ORIGINAL_BYTE:02X} (je) -> 0x{PATCHED_BYTE:02X} (jne)")

    data[target] = PATCHED_BYTE

    with open(dll_path, 'wb') as f:
        f.write(data)

    return True


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    game_root = os.path.dirname(script_dir)

    if len(sys.argv) > 1:
        game_root = sys.argv[1]

    dll_path = os.path.join(game_root, "Cities2_Data", "Plugins", "x86_64", "cohtml_unity3dplugin.dll")
    backup_path = dll_path + ".bak"

    if not os.path.exists(dll_path):
        print(f"ERROR: Cannot find {dll_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Patching: {dll_path}")

    # Read once to check if patching is needed
    with open(dll_path, 'rb') as f:
        check_data = f.read()

    needs_patch = len(find_pattern(check_data)) > 0

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
        print("\nSuccess! cohtml_Unity3DPlugin.dll has been patched.")
    else:
        print("\nNo changes needed.")


if __name__ == '__main__':
    main()
