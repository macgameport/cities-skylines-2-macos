# Binary patches

16 idempotent, self-verifying patches for **Cities: Skylines II `1.6.2f1`** (re-derived 2026-10-10; 1.6.0f1 before that) running
under Wine on macOS. Each is a workaround for a defect in Wine (mostly), Colossal.IO, or the
Paradox SDK — see [`../docs/patch-inventory.md`](../docs/patch-inventory.md) for what each one
fixes and who owns the real bug.

```sh
bash ../repatch.sh                                   # the default wrapper's game folder
CS2_GAME_DIR="/path/to/Cities Skylines II" bash ../repatch.sh   # a game folder somewhere else
```

`setup.sh` and the launcher run exactly this.

## Which patches the game needs

**The game needs ten of these and nothing else.** With them it reaches the main menu, loads a city and
downloads mods (boot-verified on 1.6.2f1, 2026-10-10). `setup.sh` and the launcher apply exactly those ten.

The other six tolerate a file-error defect that Wine 10 had and that some third-party Wine 11 builds bring
back. They are off by default; `CS2_ERRNO_PATCHES=1 bash ../repatch.sh` applies all sixteen.

**Licence checks are out of scope.** Wine 10 also failed a valid signature in `BCryptVerifySignature` (root
cause **R3**), so on that engine the game's UI middleware rejected its own valid licence. Wine 11 fixed that,
and that is the fix: see [`../docs/wine-bugs/`](../docs/wine-bugs/).
This repository has never contained a way around that check, the project keeps none, and pull requests
adding one are declined.

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
