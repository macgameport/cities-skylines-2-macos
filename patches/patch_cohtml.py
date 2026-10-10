#!/usr/bin/env python3
"""
Patches cohtml_Unity3DPlugin.dll to fix a crash during UI rendering under Wine/GPTK.

What the patched code actually is (re-derived 2026-10-10 against 1.6.0f1 and
1.6.2f1 by disassembly; the "IAllocator initialization" wording inherited from
the community fix does not match the code):

The plugin wraps each UI draw in a save/restore of Unity's D3D11 pipeline
state. A state-block object (0x52B0 bytes) captures the state with the
ID3D11DeviceContext *Get* methods (vtable +0x240..+0x368: OMGetBlendState,
RSGetState, VS/PS/GS/HS/DS/CSGetShaderResources/Samplers/ConstantBuffers, ...)
and sets a byte flag at +0x10. Restore replays the *Set* methods and then calls
the function patched here, which -- if the flag is set -- calls Release()
(vtable +0x10) on every captured COM reference and nulls the slot:

    push rsi ; sub rsp,30h
    cmp  byte ptr [rcx+10h], 0      ; state captured?
    mov  rsi, rcx
    je   return                     ; <- 0F 84: this byte becomes 0F 85
    ... ~100 x { if (p) p->Release(); p = NULL; } ...

Flipping je -> jne makes the captured-state case return without releasing
anything, i.e. the patch deliberately LEAKS the references the Get* calls
handed out. That avoids an over-release (access violation) when the D3D11
translation layer's Get* methods do not AddRef the way native D3D11 does.

Patterns (each must match exactly once; None = wildcard):
  legacy  - manolz1/cities2-gptk-fix signature, anchored on the int3 padding
            before the function. Matches 1.6.0f1 at file 0xC2CF.
  fn      - the function's own prologue + test + je + first load. Matches
            1.6.0f1 (0xC2D0) and 1.6.2f1 (0xDFB0). 1.6.2f1 has no int3 padding
            before the function (the preceding Restore grew 0x17 bytes from
            codegen changes and now ends flush on the 16-byte boundary), which
            is why the legacy pattern stopped matching; the function body
            itself is byte-identical (1604 bytes) between the two builds.
"""

import sys
import os
import shutil

ORIGINAL_BYTE = 0x84  # je  (0F 84 rel32)
PATCHED_BYTE = 0x85   # jne (0F 85 rel32)

# (name, pattern, offset of the 0x84/0x85 byte within the pattern)
PATTERNS = [
    ("legacy",
     [0xCC, 0x40, None, 0x48, None, None, None, 0x80, None, None, None, 0x48, None, None, 0x0F, 0x84],
     15),
    ("fn",
     [0x40, 0x56, 0x48, 0x83, 0xEC, 0x30,            # push rsi ; sub rsp,30h
      0x80, 0x79, 0x10, 0x00,                        # cmp byte ptr [rcx+10h],0
      0x48, 0x8B, 0xF1,                              # mov rsi,rcx
      0x0F, 0x84, None, None, None, None,            # je  rel32
      0x48, 0x8B, 0x89, 0x98, 0x00, 0x00, 0x00],     # mov rcx,[rcx+98h]
     14),
]


def _matches(data, pattern):
    first = pattern[0]
    out = []
    i = data.find(bytes([first]))
    end = len(data) - len(pattern)
    while i != -1 and i <= end:
        if all(p is None or data[i + j] == p for j, p in enumerate(pattern)):
            out.append(i)
        i = data.find(bytes([first]), i + 1)
    return out


def find_sites(data, byte):
    """Return {file offset of the je/jne byte: [pattern names]} for the given variant."""
    sites = {}
    for name, pattern, off in PATTERNS:
        variant = list(pattern)
        variant[off] = byte
        for m in _matches(data, variant):
            sites.setdefault(m + off, []).append(name)
    return sites


def classify(data):
    """('unpatched', site) | ('patched', site) | ('notfound', None) | ('ambiguous', detail)."""
    unpatched = find_sites(data, ORIGINAL_BYTE)
    patched = find_sites(data, PATCHED_BYTE)
    if len(unpatched) + len(patched) == 0:
        return "notfound", None
    if len(unpatched) + len(patched) > 1:
        return "ambiguous", {"unpatched": unpatched, "patched": patched}
    if unpatched:
        site, names = next(iter(unpatched.items()))
        return "unpatched", (site, names)
    site, names = next(iter(patched.items()))
    return "patched", (site, names)


def patch_dll(dll_path):
    """Patch cohtml_Unity3DPlugin.dll in place. Returns True if a byte was written."""
    with open(dll_path, 'rb') as f:
        data = bytearray(f.read())

    state, detail = classify(data)

    if state == "patched":
        site, names = detail
        print(f"  Already patched (je -> jne) at 0x{site:X} [{', '.join(names)}].")
        return False

    if state == "notfound":
        print("  WARNING: Pattern not found. The game may have been updated.")
        print("  Check https://github.com/manolz1/cities2-gptk-fix for updates.")
        return False

    if state == "ambiguous":
        print("  WARNING: Patterns matched more than one site; refusing to guess.")
        for kind, sites in detail.items():
            for site, names in sites.items():
                print(f"    {kind}: 0x{site:X} [{', '.join(names)}]")
        return False

    target, names = detail
    print(f"  Pattern found [{', '.join(names)}], patching byte at 0x{target:X}")
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

    needs_patch = classify(check_data)[0] == "unpatched"

    if needs_patch:
        had_backup = os.path.exists(backup_path)
        shutil.copy2(dll_path, backup_path)
        print(f"Backup {'refreshed' if had_backup else 'created'}: {backup_path}")
    elif not os.path.exists(backup_path):
        print(f"  (no backup made — DLL not in an unpatched state)")
    else:
        print(f"Backup exists: {backup_path}")

    if patch_dll(dll_path):
        print("\nSuccess! cohtml_Unity3DPlugin.dll has been patched.")
    else:
        print("\nNo changes needed.")


if __name__ == '__main__':
    main()
