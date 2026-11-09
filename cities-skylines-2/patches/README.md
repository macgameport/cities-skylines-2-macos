# Binary patches

16 idempotent, self-verifying patches for **Cities: Skylines II `1.6.2f1`** (re-derived 2026-10-10; 1.6.0f1 before that) running
under Wine on macOS. Each is a workaround for a defect in Wine (mostly), Colossal.IO, or the
Paradox SDK — see [`../docs/patch-inventory.md`](../docs/patch-inventory.md) for what each one
fixes and who owns the real bug.

```sh
# the default stack (Wine 11 + DXMT): the ten patches it needs, and only those
bash ../repatch.sh dxmt11
# a game folder somewhere else
CS2_GAME_DIR="/path/to/Cities Skylines II" bash ../repatch.sh dxmt11
```

`setup.sh` and the launcher run exactly this. A bare folder path instead of `dxmt11` selects all 16,
which is the Wine 10 set: do not use it on Wine 11 (`repatch.sh` says how to undo it).

## Which patches the game needs

**On the default stack (Wine 11) these ten are everything the game needs.** With them it reaches
the main menu, loads a city and downloads mods (boot-verified on 1.6.2f1, 2026-10-10). Nothing
unpublished is involved.

The other six patches, and the rest of this section, concern the older **Wine 10 fallback** only.
Wine 10's `BCryptVerifySignature` fails on a valid signature (root cause **R3**), so on that engine
the game's UI middleware, Coherent Gameface, rejected its own valid embedded licence and aborted with
`Invalid License key used!` before the menu. Getting past that on Wine 10 took a 17th patch that
skipped the signature check. That patch has never been in this repository: a signature-check bypass
for commercial middleware reads as circumvention whatever the intent, and PRs adding one will be
declined. **The correct fix was in Wine**, and Wine 11 has it (measured 2026-08-22, see
[`../docs/wine-bugs/`](../docs/wine-bugs/)). On the current game build the Wine 10 fallback reached
the main menu without it as well (Steam build 25127643, two boots, 2026-11-03), which covers one
build on one engine.

## Safety properties

- **Self-verifying.** Every patch checks exactly what it is about to change before writing — a byte
  fingerprint, or (the five `PDX.SDK.dll` patches since 1.6.2f1) the target method found **by name**
  with its full original IL matched. A game update that moves or changes the code makes the patch
  **refuse and tell you** rather than corrupt the binary.
- **Backed up.** First run writes `<file>.bak` — the pristine original.
- **Idempotent.** Re-running is a no-op.
- **Revertible.** `patch_fshandle.py <dir> --revert`, or restore from `.bak`.
- **Dry-runnable.** Several accept `--dry-run`.

## If a game update breaks them

Offsets need re-deriving. `dis_pdx.py` is the IL disassembler used to find them:

```sh
python3 dis_pdx.py <path/to/PDX.SDK.dll> '<CreateFileStream>d__25' MoveNext
```

It reads the file with `dnfile`, which ships in [`_vendor/`](_vendor/README.md) beside the patch scripts: no
virtual environment and no `pip`.

Method rules that kept this from going wrong, the hard way:

- **Prefer in-place edits** (identical byte count) over relocating a method body — no branch-target,
  offset or exception-clause shifts to get wrong.
- **Never relocate a `.ctor`** — it breaks early-init type resolution even when the IL is valid.
- **Check stack balance on both branch paths**, or you get `Invalid IL at IL_xxxx` at runtime, not
  at patch time.
- **Boot-verify anything touching `mscorlib`** — it is on the boot path.
