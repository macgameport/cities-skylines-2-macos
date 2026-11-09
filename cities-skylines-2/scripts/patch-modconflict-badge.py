#!/usr/bin/env python3
"""Neuter CS2's per-boot mod keybinding-conflict ⚠ badges (Options rows/tabs).

Mechanism (disassembled 2026-08-27, game 1.6.0f1): during boot each mod's
AddActions triggers InputManager.CheckConflicts BEFORE the per-user .coc
binding overrides settle, so the mods' factory-default chords (which do
collide: FindIt/Traffic Ctrl+R, Traffic display/quicksave Ctrl+S, …) get
flagged into ProxyBinding's cached conflict state. Two UI surfaces read that
stale state:

  P1  InputManager.SetModConflictNotification — pushes a per-mod
      "KeyBindingConflict" notification (menu notification center).
  P2  InputBindingField.get_warning — per-keybind-row widget warning =
      (binding.hasConflicts & mask) != 0; the Options tab ⚠ and mod-row ⚠
      aggregate from these rows. THIS is the badge James sees.

Opening a badged section re-runs CheckConflicts against the settled (clean)
bindings, which is why badges clear on view and re-arm every launch.

Patches (both required; P1 alone was proven insufficient 2026-08-27):
  P1  ldarg.2 (0x04) → ldc.i4.0 (0x16) before the brfalse: the notification
      call always takes its pop/clear path.
  P2  the 11-byte hasConflicts load (ldarg.0; ldflda; call) → ldc.i4.0 +
      10×nop: get_warning computes (0 & mask) != 0 = false with all original
      control flow intact. The interactive rebind conflict dialog is NOT
      affected — it reads ProxyBinding.hasConflicts directly.

⚠ IL-surgery lessons (cost three crashed/limped boots, 2026-08-27):
  1. Never flip a branch opcode — brfalse POPS its condition, br does not;
     the orphaned slot is invalid IL (InvalidProgramException at JIT).
  2. Never truncate a body — Mono linearly decodes ALL bytes: stale tail
     bytes must still decode, and a nop tail falls off the method end (the
     decoder runs into the next method's header).
  3. The safe primitive is VALUE SUBSTITUTION inside unchanged flow:
     ldarg/ldflda/call sequences → ldc + nops of identical length.

Usage:
  python3 patch-modconflict-badge.py            # verify only (safe while game runs)
  python3 patch-modconflict-badge.py apply      # backup + patch (game must be down)

Run via ~/cs2-patch/revenv/bin/python3 (needs dnfile). Re-run after any CS2
game update (Steam replaces Game.dll; methods are re-resolved by name).
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


def method_body_range(pe, type_name, method_name):
    md = pe.net.mdtables
    for t in md.TypeDef:
        if str(t.TypeName) != type_name:
            continue
        try:
            methods = list(t.MethodList)
        except Exception:
            continue
        for m in methods:
            if str(m.row.Name) != method_name or not m.row.Rva:
                continue
            off = None
            for s in pe.sections:
                if s.VirtualAddress <= m.row.Rva < s.VirtualAddress + s.Misc_VirtualSize:
                    off = m.row.Rva - s.VirtualAddress + s.PointerToRawData
                    break
            if off is None:
                continue
            first = pe.__data__[off]
            if first & 3 == 2:
                return off + 1, first >> 2
            return off + 12, struct.unpack_from("<I", pe.__data__, off + 4)[0]
    return None, None


def p1_state(blob):
    """SetModConflictNotification: ldarg.2+brfalse(+0xF4) → ldc.i4.0+brfalse."""
    live, patched = blob.count(bytes.fromhex("0439f4000000")), blob.count(bytes.fromhex("1639f4000000"))
    if blob.count(bytes.fromhex("0438f4000000")):
        return "BROKEN-V1", None
    if patched == 1 and live == 0:
        return "PATCHED", None
    if live == 1:
        return "PRISTINE", blob.index(bytes.fromhex("0439f4000000"))
    return f"UNEXPECTED({live}/{patched})", None


def p1_write(f, body, size, idx):
    f.seek(body + idx)
    assert f.read(1) == b"\x04"
    f.seek(body + idx)
    f.write(b"\x16")


P2_SUB = b"\x16" + b"\x00" * 10  # ldc.i4.0 + 10×nop, same 11-byte footprint


def p2_state(blob):
    """get_warning: replace the 11-byte hasConflicts load (ldarg.0; ldflda;
    call) with ldc.i4.0 + nops — the method then computes (0 & mask) != 0
    with ALL original control flow, stack shapes and the final ret intact.

    Truncation does NOT work here, measured twice (2026-08-27 rounds 4+5):
    Mono linearly decodes the whole body, so (a) stale tail bytes must still
    decode (round 4: old token byte → bne.un.s with bogus target) and (b) a
    nop tail falls off the end of the method — the last decoded instruction
    must be a terminator (round 5: decoder ran into the NEXT method's header,
    'IL_0021: beq.s IL_0095' = its 0x2E 0x72). Value-substitution inside the
    original flow sidesteps the entire class.
    """
    if blob[:11] == P2_SUB and len(blob) >= 12 and blob[11] == 0x02:
        return "PATCHED", None
    if blob[:2] == b"\x16\x2a":
        return "BROKEN-TRUNCATED", None  # v2a/v2b: restore a backup first
    if len(blob) >= 12 and blob[:2] == b"\x02\x7c" and blob[6] == 0x28 and blob[11] == 0x02:
        return "PRISTINE", 0
    return f"UNEXPECTED(head={blob[:2].hex()})", None


def p2_write(f, body, size, idx):
    f.seek(body)
    assert f.read(2) == b"\x02\x7c"
    f.seek(body)
    f.write(P2_SUB)


PATCHES = [
    ("P1 notification", "InputManager", "SetModConflictNotification", p1_state, p1_write),
    ("P2 row-warning", "InputBindingField", "get_warning", p2_state, p2_write),
]


def main():
    apply = len(sys.argv) > 1 and sys.argv[1] == "apply"
    if not GAME_DLL.exists():
        sys.exit(f"FAIL: {GAME_DLL} not found")
    if apply:
        # must run BEFORE dnfile opens the DLL — our own mmap handle shows up in lsof
        lsof = subprocess.run(["lsof", "--", str(GAME_DLL)], capture_output=True, text=True)
        if lsof.stdout.strip():
            sys.exit("FAIL: Game.dll is open (game running?) — exit the game first")

    pe = dnfile.dnPE(str(GAME_DLL))
    plan = []
    for name, tname, mname, state_fn, write_fn in PATCHES:
        body, size = method_body_range(pe, tname, mname)
        if body is None:
            sys.exit(f"FAIL: {tname}.{mname} not found (game updated? re-derive)")
        state, idx = state_fn(bytes(pe.__data__[body : body + size]))
        print(f"{name}: {state}  ({tname}.{mname} @0x{body:x}, {size}B)")
        if state in ("BROKEN-V1", "BROKEN-TRUNCATED"):
            sys.exit(f"FAIL: {state} patch present — restore the Game.dll backup first")
        if state.startswith("UNEXPECTED"):
            sys.exit("FAIL: unexpected bytes — game updated? re-derive before patching")
        if state in ("PRISTINE", "REPAIR"):
            plan.append((name, body, size, idx, write_fn))
    pe.close()

    if not plan:
        print("all patches present — nothing to do")
        return
    if not apply:
        print(f"{len(plan)} patch(es) pending; run with 'apply'")
        return

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = GAME_DLL.with_suffix(f".dll.bak-modconflict-{stamp}")
    backup.write_bytes(GAME_DLL.read_bytes())
    with open(GAME_DLL, "r+b") as f:
        for name, body, size, idx, write_fn in plan:
            write_fn(f, body, size, idx)
            print(f"APPLIED {name}")
    print(f"backup: {backup.name}")
    print("Boot-verify next launch: clean main menu, no ⚠ badges on mod rows.")


if __name__ == "__main__":
    main()
