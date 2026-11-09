# Binary patches

16 idempotent, self-verifying patches for **Cities: Skylines II `1.6.2f1`** (re-derived 2026-10-10; 1.6.0f1 before that) running
under Wine on macOS. Each is a workaround for a defect in Wine (mostly), Colossal.IO, or the
Paradox SDK — see [`../docs/patch-inventory.md`](../docs/patch-inventory.md) for what each one
fixes and who owns the real bug.

```sh
bash ../repatch.sh /path/to/steamapps/common/Cities\ Skylines\ II
# or
CS2_GAME_DIR="/path/to/Cities Skylines II" bash ../repatch.sh
```

## ⚠️ Read this before you start

**These will not, on their own, get the game to the main menu.** A 17th patch — bypassing the
Coherent Gameface licence signature check — is **deliberately not published here**. CS2's embedded
Gameface licence is valid; Wine's `BCryptVerifySignature` simply fails on it (root cause **R3**), so
cohtml aborts with `Invalid License key used!` before the menu.

A signature-check bypass for commercial middleware reads as circumvention whatever the intent, so
it isn't in this repo and PRs adding it will be declined. **The correct fix is in Wine** — see
[`../docs/wine-bugs/`](../docs/wine-bugs/). Fix R3 and the 17th patch stops being necessary at all.

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
python3 -m venv revenv && ./revenv/bin/pip install dnfile capstone pefile
./revenv/bin/python3 dis_pdx.py <path/to/PDX.SDK.dll> '<CreateFileStream>d__25' MoveNext
```

Method rules that kept this from going wrong, the hard way:

- **Prefer in-place edits** (identical byte count) over relocating a method body — no branch-target,
  offset or exception-clause shifts to get wrong.
- **Never relocate a `.ctor`** — it breaks early-init type resolution even when the IL is valid.
- **Check stack balance on both branch paths**, or you get `Invalid IL at IL_xxxx` at runtime, not
  at patch time.
- **Boot-verify anything touching `mscorlib`** — it is on the boot path.
