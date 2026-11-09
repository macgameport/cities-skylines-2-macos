# Setup that tells the truth, an opt-in badge patch, and retiring the Wine 10 fallback

> **Status: not yet checked. Run `check it` before building.**
> Written 2026-11-09. Tracking: none yet; an issue for the setup defect (section 1, F1) is proposed.
> Scope: Cities: Skylines II only. File and line references are as of `11ece32`, relative to
> `cities-skylines-2/` unless they start with `common/`, `docs/` or `surviving-mars-relaunched/`.

## 0. Decisions already made (James, 2026-11-09)

| # | Decision | His words |
|---|---|---|
| D1 | Fix `setup.sh` now, and test it by installing its Python package in a scratch folder | "Fix the setup script now?" "yes" |
| D2 | The project keeps no workaround for the Wine 10 licence-check failure. The one private copy was deleted on 2026-11-09 and every mention is made consistent | "Delete the private licence-check tool?" "yes" |
| D3 | Retire the Wine 10 fallback from this repository | "Retire the older Wine 10 fallback from the public repo?" "yes" |
| D4 | The badge patch becomes opt-in | "Make the cosmetic badge patch opt-in?" "yes" |

## 1. Where things are today (measured 2026-11-09)

**F1. A fresh install applies 5 of the 10 patches and prints "setup complete".** Five patchers
(`patches/patch_mkparent.py`, `patch_lockbypass.py`, `patch_longdelete.py`, `patch_createfile.py`,
`patch_lockleak.py`) import `dnfile`. Each re-executes itself under `~/cs2-patch/revenv/bin/python3` when that
exists and otherwise exits with `ERROR: needs dnfile` (`patches/patch_mkparent.py:35-42`, the same head in all
five). Nothing creates that environment: the only instruction was in `patches/README.md` under "If a game
update breaks them". `repatch.sh:7` is `set -e`, so it stops at `:114`, the first of the five, after
`patch_cohtml`, `patch_colossal_io`, `patch_longfile`, `patch_asset_database` and `patch_fshandle`.
`scripts/setup.sh:115-120` then blames a game update and `:127-129` prints `=== setup complete ===`.
Reproduced with a scratch home folder and a target that does not exist:
`HOME=<scratch> python3 patches/patch_mkparent.py <no such folder>` prints the error and exits 1. The system
`python3` on the test Mac has no `dnfile`. Since `11ece32` the install guide and both quick starts carry a
manual line that creates the environment; this plan removes the need for it.

**F2. The launcher hides the same failure.** `launchers/launch-cs2-dxmt11.sh:179-199` (`ensure_patches`) writes
`WARNING: repatch reported an issue` to a log the player never opens (`scripts/make-shortcut.sh:106` redirects
everything there).

**F3. `--stack d3dmetal` is advertised and does not work.** `scripts/setup.sh:10,37` and
`scripts/make-shortcut.sh:17,48-49` offer it; `setup.sh:115` passes the word to `repatch.sh`, whose `case`
(`repatch.sh:26-29`) knows only `free` and `dxmt11`, so it prints `ERROR: no Cities2.exe under: d3dmetal`.
Issue #20 records that the fallback launcher's own `repatch.sh free` call patches nothing.

**F4. What "the fallback" is.** `launchers/launch-cs2.sh` (221 lines), `launchers/Cities Skylines II
(D3DMetal).command`, the `free` target and the `COHTML_LICENSE` flag in `repatch.sh:24-29,63-80`, the `--stack`
option in `setup.sh` and `make-shortcut.sh`, one column of the stack table (`README.md:47-55`), and the
"Stack (fallback)" lines of `docs/patch-inventory.md:6-10`. It has no install guide. `repatch.sh:14` still
defaults, with no argument, to a CrossOver bottle and all 16 patches.

**F5. The six errno patches are not only the fallback's.** `repatch.sh:31-38` documents
`CS2_ERRNO_PATCHES=1 bash repatch.sh dxmt11` for Wine 11 builds that bring the errno defect back. They stay.

**F6. The badge patch is on by default wherever the environment exists.** `scripts/setup.sh:108` always copies
`scripts/patch-modconflict-badge.py` into the install folder, and `launch-cs2-dxmt11.sh:192-196` applies it
before every boot when that file and the environment are both present. It edits the studio's `Game.dll` to hide
a keybinding badge, and writes `Game.dll.bak-modconflict-<stamp>` first (`:176-177`). It is a preference, not a
compatibility fix. On a Mac without the environment it has never run, so fixing F1 would switch it on for
every new player unless it is gated first. `INSTALL.md` describes the badge two ways: not a real conflict in
its own section, a real one in the troubleshooting table.

**F7. Three older `setup.sh` defects** that `docs/plans/local-files-layout.md` section 7 lists and does not
fix: `--dest` or `--stack` with no value loops for ever (`setup.sh:27-29`: `shift 2` with one argument left
shifts nothing); "setup complete" when the app builder fails (`:124-129`); a symlinked install folder (that
plan's own matter, left to it).

**F8. Setup checks neither Rosetta nor the macOS version** (`setup.sh:52-86`); without Rosetta it prints
`wine64 in the wrapper () OK`.

**F9. Words.** After `11ece32`, "bypass" appears 43 times in 18 files outside `docs/plans/`. Three places say
that a private copy exists or where: `CONTRIBUTING.md:29` ("One patch in the private set"), `GOTCHAS.md:2710`
and `GOTCHAS.md:2908-2910`.

**Tests today.** `scripts/test-update-check.sh` 25 passed, `scripts/test-rosetta-preflight.sh` and
`scripts/test-p4-signals.sh` ALL PASS, `scripts/check-experiments.py` exit 0, `common/test-launch-lock.sh` 24
PASS over three launchers. `setup.sh` and `repatch.sh` have no test.

## 2. Target

- `bash scripts/setup.sh` on a Mac that has never seen this project creates what the patches need, applies all
  ten, and says so. When anything fails it says what, exits non-zero, and does not print "setup complete".
- The launcher tells the player when patching failed.
- The badge patch is installed only when the player asks.
- One stack. `launch-cs2.sh`, its `.command`, the `free` target, the `COHTML_LICENSE` flag and `--stack` are
  gone from the tree. The 16 patch scripts stay: ten applied by default, six behind `CS2_ERRNO_PATCHES=1`.
- One statement about licence checks, in `patches/README.md`, that every other page points to.
- The three quick starts go back to three commands.

## 3. Stages

Each stage is one commit of code and tests, green before the next. Documents ride with the stage that makes
them true. Nothing here launches a game except S9.

### Stage A — setup tells the truth

A1. `scripts/requirements-patchers.txt`: `dnfile==0.18.0` and `pefile==2024.8.26` (the versions in the test
Mac's environment, under Python 3.9.6), each with every `--hash=sha256:` that PyPI publishes for it, read
with `pip download` and `pip hash` during the build and recorded in the as-built header. `capstone` is not
installed by setup: only `patches/dis_pdx.py`, a maintainer's tool, imports it.

A2. `scripts/setup.sh`:
- Options: a value-taking option with no value exits 2 with `<option> needs a value` (F7).
- Preflight gains two lines after "Apple Silicon". `Rosetta 2`: `arch -x86_64 /usr/bin/true`, MISSING with the
  `softwareupdate --install-rosetta --agree-to-license` line. `macOS <version>`: informational, never fatal;
  `OK` for 26 and 27, otherwise `untested` with one line pointing at the root README's Compatibility section.
- After the copy block (`:99-111`), `ensure_pyenv`: if `$DEST/revenv/bin/python3 -c 'import dnfile'` succeeds,
  print `python environment: present`. Otherwise print that it is being created and that this downloads two
  small packages from PyPI, then run `python3 -m venv "$DEST/revenv"` and
  `"$DEST/revenv/bin/pip" install --quiet --disable-pip-version-check --require-hashes -r "$REPO/scripts/requirements-patchers.txt"`.
  `CS2_ENSURE_PYENV=<command>` replaces the function, for `scripts/test-setup.sh` only, as the Surviving Mars
  scripts' `SPLIT_*` variables do.
- A problem counter. A failed `ensure_pyenv`, a non-zero `repatch.sh` and a non-zero `make-shortcut.sh` each
  add one and print what failed and what to do. The closing text is `=== setup complete ===` only at zero;
  otherwise `=== setup finished with <n> problem(s): see the lines marked !! above ===` and exit 1.
- The repatch failure text no longer guesses at a game update: `repatch.sh` now says which patch stopped it.

A3. `repatch.sh`:
- One interpreter for every patcher: `$HERE/../revenv/bin/python3` when it can import `dnfile`, else `python3`.
  In an install folder that is the environment beside `patches/`, wherever the folder is; in a checkout there
  is none and the patchers' own re-exec still applies.
- `run <patcher> <args>` replaces each bare `python3 "$HERE/…"` line. It stops at the first failure, as
  `set -e` does today, and prints `FAILED at <patcher>: <n> of <expected> applied, the rest not attempted`.
  `<expected>` is 10, or 16 with `CS2_ERRNO_PATCHES=1`. Success ends with `<n> of <n> patches applied or
  already in place`, and a count that is not the expected one exits 1.
- The five patchers' shared head: the error text becomes `ERROR: the Python package dnfile is missing. Run
  scripts/setup.sh again: it installs it.` Identical in all five. `_REVENV` is not touched here;
  `local-files-layout.md` 3.2 moves it.

A4. `launchers/launch-cs2-dxmt11.sh:185`: the warning becomes a `note`, which is a notification under the
double-click app: `Some patches could not be applied, so mods may not download. Run setup again (INSTALL.md,
step 4).` The boot continues, as today.

A5. Documents: the manual environment line and its note leave `README.md` (root), `README.md` and
`INSTALL.md`; `INSTALL.md` step 4 says setup downloads two small Python packages the first time;
`patches/README.md` "If a game update breaks them" keeps its maintainer's line for `dis_pdx.py`.

### Stage B — the badge patch is opt-in

B1. `scripts/setup.sh`: `--hide-mod-badges` copies `scripts/patch-modconflict-badge.py` into the install
folder; without the flag it is copied only when a copy is already there, so an existing install keeps what it
has and stays current. `--show-mod-badges` removes the installed copy and prints the two ways back to an
unedited `Game.dll`: Steam's "Verify integrity of game files", or the newest `Game.dll.bak-modconflict-*`
beside it. The installed file is the switch: the launcher's test at `launch-cs2-dxmt11.sh:192` is unchanged,
and the file is already one of the names `local-files-layout.md` moves.
B2. `scripts/patch-modconflict-badge.py:2,15`: "Neuter" becomes "Hide", and the badge is the one "a player
sees". Comments only.
B3. `INSTALL.md` "Mod keybinding ⚠ badges": optional, off by default, the two flags, what it edits, how to
undo. The troubleshooting row agrees with the section. `scripts/README.md:29` says opt-in.

### Stage C — one stack

C1. Removed with `git rm`: `launchers/launch-cs2.sh`, `launchers/Cities Skylines II (D3DMetal).command`.
C2. `repatch.sh`: the `free` target, `CX_GAME`, `FREE_GAME`, `COHTML_LICENSE` and the block at `:63-80` go.
With no argument, or `dxmt11`, the target is the default wrapper's game folder (or `CS2_GAME_DIR`); a path
argument is that game folder. Both apply the ten. `free` and `d3dmetal` exit 2 with: `The Wine 10 + D3DMetal
stack was retired on 2026-11-09. Its last version is commit <sha>.` One comment line replaces the block:
Wine 11 verifies the game's UI middleware licence correctly (R3, `docs/wine-bugs/`), and nothing here touches
it.
C3. `scripts/setup.sh` and `scripts/make-shortcut.sh`: `--stack dxmt11` and `--stack wine11` are accepted and
ignored; `--stack d3dmetal` and `--stack wine10` exit 2 with the same sentence. The usage text drops the
option. `WRAPPERS` is `CS2dxmt11.app CS2.app`.
C4. `common/test-launch-lock.sh`: two launchers, `surviving-mars-relaunched/launch-relaunched.sh` and
`cities-skylines-2/launchers/launch-cs2-dxmt11.sh`; exit 2 unless both are found; header says two.
`surviving-mars-relaunched/launch-relaunched.sh:135` says "the Cities: Skylines II launcher".
C5. Comments that name the removed launcher: `scripts/boot-verify.sh:93,99-100` (`CS2_ENGINE` and
`CS2_LAUNCHER` stay as overrides), `surviving-mars-relaunched/launch-relaunched.sh:19`,
`surviving-mars-relaunched/tools/make-engine.sh` (its header's two sentences about cs2's fallback; standalone
mode stays), and the Surviving Mars README's clause about the fallback.
C6. Documents:
- `README.md`: the stack table loses its Fallback column; "10 patches instead of 17" becomes ten; the
  paragraph at `:201-208` becomes two sentences that point at `patches/README.md`.
- `patches/README.md` "Which patches the game needs" is the one statement: ten on Wine 11; six more for
  engines with the errno defect, behind `CS2_ERRNO_PATCHES=1`; Wine 10 failed a valid signature (R3) and
  Wine 11 does not; no workaround for that check is in this repository or kept by the project, the one
  private copy from the Wine 10 era having been deleted on 2026-11-09; pull requests adding one are declined.
- `docs/patch-inventory.md`: the two "Stack" lines become one; section 4 keeps R3 as a root cause and loses
  its patch row and its "do not publish" box, pointing at the statement; "Applied by" names one command; the
  upstream list's item 3 says R3 is fixed in Wine 11.
- `CONTRIBUTING.md` "Out of scope": the same statement in two sentences; "private set" goes.
- `GOTCHAS.md:2710` and `:2908-2910`, dated entries: the tool's location and the record of running it are
  replaced by "a workaround that was never published and no longer exists (deleted 2026-11-09)"; the measured
  result at `:2910-2913` stays. Every other dated entry keeps the words it was written with.
- `INSTALL.md` troubleshooting, "Mods won't download": the patches are not all applied; run setup again and
  read its last lines.
- `CLAUDE.md` (this game's) rows `:16,22,23` and the root `CLAUDE.md:26-30`: what describes the maintainer's
  own machines (the fallback wrapper's state, the private mirrors) moves to the untracked `CLAUDE.local.md`;
  the tracked rows keep what a contributor needs.
C7. Left alone on purpose: the six errno patch scripts; `docs/wine-bugs/R3-bcrypt-verifysignature.md`, a Wine
bug analysis; dated entries in `GOTCHAS.md`, `EXPERIMENTS.md` and `CONFIG-TRIALS.md`; dated plans under
`docs/plans/`; `launchers/archive-dead-stacks/`, `launchers/login-helpers/` and `archive/` (section 7); any
`launch-cs2.sh` already in someone's install folder, which setup neither updates nor deletes.

## 4. Who notices what

| Who | What changes | Mitigation |
|---|---|---|
| A new player | Setup downloads two packages from PyPI (about 1 MB) and all ten patches apply | Stated in step 4; pinned and hash-checked |
| A player who set up between 2026-10-10 and now | The next `setup.sh` creates the environment and applies the other five; mods start downloading | The launcher's new notice tells them to run it |
| A player offline at setup | `ensure_pyenv` fails; setup says so and exits 1 with five patches applied, as today, but no longer claims success | Re-run when online |
| Anyone using `--stack d3dmetal` or `repatch.sh free` | A retirement message and exit 2. Both were already broken (F3) | The message names the last commit |
| Anyone passing a bare game path to `repatch.sh` | Ten patches where it was sixteen | `CS2_ERRNO_PATCHES=1`, already documented |
| An install that has the badge patch | Nothing: the installed copy stays and stays current | `--show-mod-badges` |
| A new install | No badge patch unless asked | `--hide-mod-badges` |
| The maintainer's Macs | The deployed fallback launcher stays on disk, unmaintained. T2 compares 21 files, not 22 | Section 6 |

## 5. Test plan

| # | Test | Passes when | Mutant, applied and seen red |
|---|---|---|---|
| S1 | `scripts/test-repatch.sh` (new): a scratch copy of `repatch.sh` beside a `patches/` of stub patchers that record how they were run | all succeed: `10 of 10`, exit 0, in today's order · `CS2_ERRNO_PATCHES=1`: `16 of 16` · the sixth stub fails: `FAILED at patch_mkparent.py: 5 of 10`, exit 1, later stubs not run · a `revenv/bin/python3` stub that imports `dnfile` is the interpreter for all; without it, `python3` · `free` and `d3dmetal`: the retirement sentence, exit 2, no stub run · a path argument: ten, in that folder | (a) `run` ignores the exit status: the failing case prints `10 of 10` · (b) always `python3`: the interpreter case fails |
| S2 | `scripts/test-setup.sh` (new): `HOME` at a scratch folder holding a fake wrapper (a stub `wine64`, empty `steam.exe` and `Cities2.exe`), a scratch copy of `scripts/`, `launchers/`, `repatch.sh` and stub `patches/`, `CS2_ENSURE_PYENV` set to a stub | clean run: exit 0, `setup complete`, launcher, `repatch.sh` and patches in `$HOME/cs2-patch`, an app in `$HOME/Applications`, no badge file · `--hide-mod-badges`: badge file present; a plain re-run keeps and refreshes it; `--show-mod-badges` removes it · a failing patcher stub: exit 1, `finished with 1 problem`, no `setup complete` · a failing `CS2_ENSURE_PYENV`: the same, and the text says mods will not download · `--dest` with no value: exit 2 at once · `--stack d3dmetal`: the sentence, exit 2, nothing copied · `--check`: nothing written | (a) print `setup complete` unconditionally · (b) copy the badge file unconditionally · (c) drop the value check: the test's 5-second timer kills a loop |
| S3 | `common/test-launch-lock.sh` | 16 PASS: 14 cases and 2 parity lines | `MUTANT=1` exits 1; `acquire_lock` altered in one launcher of a scratch copy: a parity line differs; one launcher removed: exit 2 |
| S4 | The standing tests and gates: `test-update-check.sh`, `test-rosetta-preflight.sh`, `test-p4-signals.sh`, `check-experiments.py`, the seven Surviving Mars tests, `common/check-links.py`, `ACCEPT=9 common/check-identifiers.sh`, `bash -n` on every `.sh` and `.command`, `py_compile` on every `.py` | each as before: 25 passed, ALL PASS, ALL PASS, exit 0, seven green, 0 unresolved, 9 | none: unchanged tests |
| S5 | The real `ensure_pyenv`, once, by hand, with the network: `HOME` at a scratch folder, the function run alone | the environment exists, `import dnfile` succeeds in it, and its `pip list` shows the two pinned versions | change one character of one hash in a scratch copy of the requirements file: `pip` refuses and the function fails |
| S6 | Words, by `git grep` outside `docs/plans/` and outside the dated files C7 names | 0 hits each: `private set`, `old-patchers/patch_cohtml_license`, `COHTML_LICENSE`, `launch-cs2.sh` in any `.sh`, `.py` or `.command`, `--stack d3dmetal` outside the two retirement messages · the statement of C6 is in `patches/README.md` once | none: a count |
| S7 | On the Studio, game closed: `bash scripts/setup.sh` from the checkout | exit 0; the preflight shows Rosetta and macOS lines; `python environment: present`; `10 of 10 patches applied or already in place`; `setup complete`; T2 reads 21 found, 21 identical; the installed badge file is still there and current | none: a live run |
| S8 | A clone of the checkout under `/tmp`: the README quick start with `--check` appended | prints the preflight and stops | none: unification T11 re-run |
| S9 | Visible, James warned first: `scripts/boot-verify.sh` on the Studio | PASS | none: a live run |

## 6. What this changes in the two other plans

Both were checked against a tree that had the fallback. Neither is re-checked here; each already requires a
fitted re-check before its next phase is built, and this list is for that pass.

- `docs/plans/1launcher-unification.md`: T2 reads 21 of 21 after Stage C. T8 reads 16 PASS over two
  launchers. Phase 3's exit `git grep` for the old Surviving Mars home prints nothing once `launch-cs2.sh` is
  gone. Phase 5's outline speaks of three launchers.
- `docs/plans/local-files-layout.md`: `launch-cs2.sh` stays among the seven runtime names, as a file an older
  install may hold, but the repo no longer ships it. Its 3.2 row for the five patchers' head now starts from
  the error text of A3. `setup.sh` gains `ensure_pyenv` and the problem counter before L1 rewrites it, and
  `--stack` is gone. Its section 7 item on three older defects is down to one. Its counts of `cs2-patch`
  lines (LT12) and its cites into `INSTALL.md` moved with `11ece32` and move again here.

## 7. Not in this plan

- An install guide for someone who has never used Terminal, with screenshots; a double-click installer; setup
  installing Steam into the wrapper; a wrapper built without Porting Kit's interface. Each needs its own plan.
- CI and branch protection.
- `LSMinimumSystemVersion` in the three generated apps (13.0 today).
- `launchers/archive-dead-stacks/`, `launchers/login-helpers/` and `archive/`: dead scripts, one of which asks
  for a Steam password in a dialog. Whether they stay in the tree is the maintainer's call.
- `CS2_WRAPPER` not carried into the app; the engine build's unlisted requirements; the uninstall section's
  gaps; recovery from an expired Steam sign-in on the 11.16 engine. Each wants an issue.
- Revealing the new app in Finder at the end of setup.

## 8. Decisions (James)

None open. D1 to D4 decide what is built.

## Rollback

Revert the stage's commit and run `setup.sh` again: the deployed files follow the checkout. The environment
setup created is harmless and stays. The deleted private tool (D2) is not coming back, by design.

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|

Key paths: `cities-skylines-2/scripts/setup.sh` · `cities-skylines-2/scripts/make-shortcut.sh` ·
`cities-skylines-2/repatch.sh` · `cities-skylines-2/patches/` · `cities-skylines-2/launchers/` ·
`cities-skylines-2/scripts/patch-modconflict-badge.py` · `common/test-launch-lock.sh` ·
`cities-skylines-2/INSTALL.md` · `cities-skylines-2/README.md` · `cities-skylines-2/docs/patch-inventory.md`.
