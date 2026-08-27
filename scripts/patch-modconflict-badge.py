#!/usr/bin/env python3
"""Neuter CS2's per-boot mod keybinding-conflict badge (the mod-row ⚠ in Options).

Mechanism (disassembled 2026-08-27, game 1.6.0f1): at boot, InitializeUI →
InputManager.CheckConflicts evaluates bindings BEFORE per-user .coc overrides
apply, sees the mods' factory-default chords colliding, and pushes a
"KeyBindingConflict" notification per mod input map (the ⚠ badge). Opening the
section re-runs CheckConflicts against the overridden (clean) state and pops
it — which is why the badge clears on view and returns every launch.

Patch: in InputManager.SetModConflictNotification the IL reads
    ldarg.2 (0x04) ; brfalse -> pop-branch (0x39 F4 00 00 00)
i.e. "if not active, clear the notification". Flipping brfalse (0x39) to br
(0x38) makes EVERY call take the clear path — the badge can never arm. The
real conflict displays inside the rebind UI are separate code and untouched.

Usage:
  python3 patch-modconflict-badge.py            # verify only (safe while game runs)
  python3 patch-modconflict-badge.py apply      # backup + patch (game must be down)

Run via ~/cs2-patch/revenv/bin/python3 (needs dnfile).
"""
import struct
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import dnfile

GAME_DLL = Path.home() / (
    "Applications/CS2dxmt11.app/Contents/SharedSupport/prefix/drive_c/"
    "Program Files (x86)/Steam/steamapps/common/Cities Skylines II/"
    "Cities2_Data/Managed/Game.dll"
)
# ldarg.2 ; brfalse +0xF4  — the "if (!active) → pop" branch in SetModConflictNotification
SIG = bytes.fromhex("0439f4000000")
PATCHED_SIG = bytes.fromhex("0438f4000000")


def method_body_range(pe: dnfile.dnPE, type_name: str, method_name: str):
    md = pe.net.mdtables
    rows = []
    for t in md.TypeDef:
        if str(t.TypeName) == type_name:
            try:
                rows.extend((m.row, str(m.row.Name)) for m in t.MethodList)
            except Exception:
                pass
    for row, name in rows:
        if name != method_name or not row.Rva:
            continue
        off = None
        for s in pe.sections:
            if s.VirtualAddress <= row.Rva < s.VirtualAddress + s.Misc_VirtualSize:
                off = row.Rva - s.VirtualAddress + s.PointerToRawData
                break
        if off is None:
            continue
        data = pe.__data__
        first = data[off]
        if first & 3 == 2:  # tiny header
            return off + 1, first >> 2
        size = struct.unpack_from("<I", data, off + 4)[0]  # fat header
        return off + 12, size
    return None, None


def main():
    apply = len(sys.argv) > 1 and sys.argv[1] == "apply"
    if not GAME_DLL.exists():
        sys.exit(f"FAIL: {GAME_DLL} not found")

    pe = dnfile.dnPE(str(GAME_DLL))
    body, size = method_body_range(pe, "InputManager", "SetModConflictNotification")
    if body is None:
        sys.exit("FAIL: InputManager.SetModConflictNotification not found (game updated? re-derive)")

    blob = bytes(pe.__data__[body : body + size])
    live, patched = blob.count(SIG), blob.count(PATCHED_SIG)
    if patched == 1 and live == 0:
        print(f"ALREADY PATCHED  (method body @0x{body:x}, size {size})")
        return
    if live != 1:
        sys.exit(f"FAIL: expected exactly 1 signature hit, got {live} (game updated? re-derive offsets)")
    target = body + blob.index(SIG) + 1  # the brfalse opcode byte
    print(f"PATCHABLE  brfalse @file 0x{target:x} (method body @0x{body:x}, size {size})")
    if not apply:
        print("verify-only; run with 'apply' to patch")
        return

    # refuse while any process has the DLL (or its dir's prefix) open
    lsof = subprocess.run(["lsof", "--", str(GAME_DLL)], capture_output=True, text=True)
    if lsof.stdout.strip():
        sys.exit("FAIL: Game.dll is open (game running?) — exit the game first")

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = GAME_DLL.with_suffix(f".dll.bak-modconflict-{stamp}")
    backup.write_bytes(GAME_DLL.read_bytes())
    with open(GAME_DLL, "r+b") as f:
        f.seek(target)
        assert f.read(1) == b"\x39"
        f.seek(target)
        f.write(b"\x38")
    print(f"PATCHED  0x39→0x38 @0x{target:x}; backup: {backup.name}")
    print("Boot-verify next launch: badges should not appear; game must reach main menu cleanly.")


if __name__ == "__main__":
    main()
