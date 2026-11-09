# Setup that tells the truth, an opt-in badge patch, and retiring the Wine 10 fallback

> **Status: Checked on 2026-11-09 by two lenses, 2 blockers and 13 groups of other fixes folded (first-pass block). The
> fold changes how the library is supplied (section 8, O1), so it is new material: a fitted re-check of the
> fold is required before any build.**
> Written 2026-11-09. Tracking: issue #23 (the setup defect, F1).
> Scope: Cities: Skylines II only. File and line references are as of `11ece32`, relative to
> `cities-skylines-2/` unless they start with `common/`, `docs/plans/` or `surviving-mars-relaunched/`, or are
> called the root's.

## 0. Decisions already made (James, 2026-11-09)

| # | Decision | His words |
|---|---|---|
| D1 | Fix `setup.sh` now | "Fix the setup script now?" "yes" |
| D2 | The project keeps no way around the Wine 10 licence-check failure, and every mention is made consistent | "Delete the private licence-check tool?" "yes" |
| D3 | Retire the Wine 10 fallback from this repository | "Retire the older Wine 10 fallback from the public repo?" "yes" |
| D4 | The badge patch becomes opt-in | "Make the cosmetic badge patch opt-in?" "yes" |
| D5 | Setup checks compatibility and lets a player go on, with a caution, where a Mac is outside what has been tested | "Are there compatibility checks and procede with caution for noncompatibilty warndings in the script?" |

One choice here is the planner's and has not been put to him (section 8, O1): how setup gets the Python
library the patches need.

## 1. Where things are today (measured 2026-11-09)

**F1. A fresh install applies 5 of the 10 patches and prints "setup complete".** Five patchers
(`patches/patch_mkparent.py`, `patch_lockbypass.py`, `patch_longdelete.py`, `patch_createfile.py`,
`patch_lockleak.py`) import `dnfile`. Each re-executes itself under `~/cs2-patch/revenv/bin/python3` when that
exists and otherwise exits with `ERROR: needs dnfile` (`patches/patch_mkparent.py:35-42`, the same head in all
five). Nothing creates that environment. `repatch.sh:7` is `set -e`, so it stops at `:114`, the first of the
five, after `patch_cohtml`, `patch_colossal_io`, `patch_longfile`, `patch_asset_database` and `patch_fshandle`.
`scripts/setup.sh:115-120` then blames a game update and `:127-129` prints `=== setup complete ===`.
Reproduced with a scratch home folder and a target that does not exist. Since `11ece32` the install guide and
both quick starts carry a manual line that creates the environment; this plan removes the need for it.

**F2. The launcher hides the same failure.** `launchers/launch-cs2-dxmt11.sh:179-199` (`ensure_patches`) writes
`WARNING: repatch reported an issue` to a log the player never opens. The call at `:199` says nothing more; the
call at `:316`, after a game update, already raises a notice.

**F3. `--stack d3dmetal` is advertised and half works.** `scripts/setup.sh:10,37` and
`scripts/make-shortcut.sh:17,48-49` offer it. Setup installs the fallback launcher and builds a working app,
but `setup.sh:115` passes the word to `repatch.sh`, whose `case` (`repatch.sh:26-29`) knows only `free` and
`dxmt11`, so the patch step prints `ERROR: no Cities2.exe under: d3dmetal`. Issue #20 records that the fallback
launcher's own `repatch.sh free` call patches nothing.

**F4. What "the fallback" is.** `launchers/launch-cs2.sh` (221 lines), `launchers/Cities Skylines II
(D3DMetal).command`, the `free` target and the `COHTML_LICENSE` flag in `repatch.sh:24-29,63-80`, the `--stack`
option in `setup.sh` and `make-shortcut.sh`, one column of the stack table (`README.md:47-56`), and the
"Stack (fallback)" lines of `docs/patch-inventory.md:6-9`. It has no install guide. `repatch.sh:14` still
defaults, with no argument, to a CrossOver bottle and all 16 patches.

**F5. The six errno patches are not only the fallback's.** `repatch.sh:31-48` documents
`CS2_ERRNO_PATCHES=1 bash repatch.sh dxmt11` for Wine 11 builds that bring the errno defect back
(`docs/wine-bugs/FINDING-wine11.16-tradeoff.md`). They stay. The launcher never passes that variable
(`launch-cs2-dxmt11.sh:182`), so on such an engine a game update drops the six until they are applied by hand;
that is true today and is not changed here.

**F6. The badge patch.** `scripts/setup.sh:108` has copied `scripts/patch-modconflict-badge.py` into every
install folder since `d3edce3` (2026-08-27), and `launch-cs2-dxmt11.sh:192-196` applies it before every boot
when that file and the environment are both present. It edits the studio's `Game.dll` to hide a keybinding
badge and writes `Game.dll.bak-modconflict-<stamp>` first (`scripts/patch-modconflict-badge.py:176-177`). It is a preference, not a
compatibility fix. Where the environment is missing it has never run. So every install has the file, most
have never run it, and fixing F1 would switch it on for all of them unless it is gated first. It hard-codes
`~/Applications/CS2dxmt11.app` (`:52-56`). `INSTALL.md` describes the badge two ways.

**F7. Three older `setup.sh` defects** that `docs/plans/local-files-layout.md` section 7 lists and does not
fix: `--dest` or `--stack` with no value loops for ever (`setup.sh:28-29`; `scripts/make-shortcut.sh` has the same arms); "setup complete" when the app
builder fails (`:124-129`); a symlinked install folder (that plan's own matter, left to it).

**F8. Setup checks almost nothing about the Mac.** `setup.sh:52-56` exits off macOS and prints `NO — Intel is
untested, continuing anyway` on Intel. It checks neither Rosetta nor the macOS version, so without Rosetta it
prints `wine64 in the wrapper () OK`. Its `python3` check (`:85`) is `command -v`, which Apple's stub passes
before the Command Line Tools are installed. The launcher checks Rosetta (`launch-cs2-dxmt11.sh:73-83`) and
nothing else. What is compatible is in the root `README.md`, "Compatibility": tested on macOS 26 and 27;
the DXMT library in the Porting Kit engine is built for macOS 26; Rosetta ends after macOS 27.

**F9. Words.** After `11ece32`, "bypass" appears 43 times in 18 files outside the root `docs/plans/`, matching case. Three places say
that a private copy exists or where: `CONTRIBUTING.md:30`, `GOTCHAS.md:2710` and `GOTCHAS.md:2908-2910`.
Counts of "17" patches are in `README.md:44,52,188,199,228-229`, `docs/patch-inventory.md:15-28,37`,
`docs/wine-bugs/README.md:6,9,18`, `patches/README.md:15-22` and `repatch.sh:17,22-23`.

**F10. The library is small and can ship here.** `dnfile` 0.18.0 and `pefile` 2024.8.26 are MIT-licensed,
pure Python and import only the standard library and each other. The wheels PyPI serves are
`dnfile-0.18.0-py3-none-any.whl` (sha256 `7579fe2d6bb1d854aa154929c309fbf34e70b622053a043a51d42f079fad1772`)
and `pefile-2024.8.26-py3-none-any.whl` (sha256 `76f8b485dcd3b1bb8166f1128d395fa3d87af26360c2358fb75b80019b957c6f`).
What the patches need from them is 15 files, about 540 KB: `dnfile/` (10), `ordlookup/` (4) and `pefile.py`;
`peutils.py` is referenced by none of them. Those `.py` files are byte-identical to the copies in the test
Mac's environment, which is what the patches have run on since October. Copied into a folder by themselves
they import under Apple's Python 3.9.6 and Homebrew's 3.14.7, isolated mode, nothing installed. One of the
15 has CRLF line endings, which `.gitattributes` would rewrite. Measured for comparison: a hash-checked
`pip install` of the same two pins into a fresh environment takes 1 to 2 seconds under either Python,
refuses a changed hash, and fails in 1 to 9 seconds with no network.

**F11. Four patchers report success when their pattern is missing.** Run against files that hold no
pattern, `patches/patch_cohtml.py` (`:112`) and `patches/patch_longfile.py` (`:76`) print a warning and exit
0, and `patches/patch_colossal_io.py` (`:95`) and `patches/patch_asset_database.py` (`:93`) print "may
already be patched" and exit 0; the last two cannot tell a patched file from one a game update changed. So
a count of scripts that exited 0 is not a count of patches applied. `repatch.sh:54` also carries a user
name as a literal in the loop that finds the Wine user folder.

**Tests today.** `scripts/test-update-check.sh` 25 passed, `scripts/test-rosetta-preflight.sh` and
`scripts/test-p4-signals.sh` ALL PASS, `scripts/check-experiments.py` exit 0, `common/test-launch-lock.sh` 24
PASS over three launchers. `setup.sh`, `repatch.sh` and `ensure_patches` have no test. On the Studio all 22
deployed files equal the checkout, and pristine `.bak` copies sit beside all five patched files of the
default wrapper (1, 46, 4, 4 and 154 bytes different from the live files).

## 2. Target

- `bash scripts/setup.sh` on a Mac that has never seen this project needs no network and no second command:
  it applies all ten patches and says so. When anything fails it says what, exits non-zero, and does not print
  "setup complete".
- Setup says whether this Mac is inside what has been tested. Outside it, it prints a caution and lets the
  player go on. It stops only for what cannot work.
- The launcher tells the player when patching failed, and once when the Mac is outside what has been tested.
- The badge patch runs only where the player asked for it or it has already run.
- One stack. `launch-cs2.sh`, its `.command`, the `free` target, the `COHTML_LICENSE` flag and `--stack` are
  gone from the tree. The 16 patch scripts stay: ten applied by default, six behind `CS2_ERRNO_PATCHES=1`.
- One statement about licence checks, in `patches/README.md`, that every other page agrees with.
- The three quick starts go back to three commands.

## 3. Stages

**Build order: B, then A, then C.** B goes first because A makes the badge patch runnable on every Mac, and it
must be gated before that. The letters keep the names the two reviews used. Each stage is one commit of code
and tests, green before the next; documents ride with the stage that makes them true. Nothing here launches a
game except S12.

### Stage B — the badge patch is opt-in

B1. `scripts/setup.sh`, decided before the patch step:
- `--hide-mod-badges` installs `scripts/patch-modconflict-badge.py` into the install folder. It prints a
  warning when the wrapper is not `~/Applications/CS2dxmt11.app`, which is the only one the script edits (F6).
- `--show-mod-badges` removes the installed copy and prints the two ways back to an unedited `Game.dll`:
  Steam's "Verify integrity of game files", or the newest `Game.dll.bak-modconflict-*` beside it.
- With neither flag: an installed copy is kept and refreshed only where the patch has run on this Mac, which
  is where a `Game.dll.bak-modconflict-*` exists beside `Cities2_Data/Managed/Game.dll`. Otherwise an
  installed copy is removed and setup prints `mod badge patch: off (it has never run here);
  --hide-mod-badges turns it on`.
The installed file is the switch, and it is already one of the names `local-files-layout.md` moves.
B2. `scripts/patch-modconflict-badge.py:2,15`: "Neuter" becomes "Hide", and the badge is the one "a player
sees". Comments only.
B3. `INSTALL.md` "Mod keybinding ⚠ badges": optional, off by default, the two flags, what it edits, that it
takes effect at the next launch, how to undo. The troubleshooting row agrees with the section. `scripts/README.md:29` and `CLAUDE.md:17` say opt-in.

### Stage A — setup tells the truth

A1. **The library ships in the tree** (O1). New folder `patches/_vendor/`: `dnfile/`, `ordlookup/` and
`pefile.py` exactly as the two wheels of F10 unpack them, `LICENSE-dnfile` and `LICENSE-pefile` copied from
the wheels, `MANIFEST.sha256` (one line per vendored file), and a `README.md` giving the two versions, the two
wheel hashes, the upstream addresses, the rule that the files are never edited here, and the steps to update
them. `.gitattributes` gains `cities-skylines-2/patches/_vendor/** -text` so no byte is rewritten.

A2. **The patchers use it.** In the five patchers the `_REVENV` block (`patch_mkparent.py:35-42`) becomes two
lines, identical in all five: put `_vendor`, beside the script, first on `sys.path`; `import dnfile`. No
re-exec, no environment, any `python3` from 3.8 up. `patches/dis_pdx.py` gets the same first line and keeps
its own need for `capstone`, a maintainer's matter. `scripts/patch-modconflict-badge.py` adds the first that
exists of `patches/_vendor` beside itself (an install folder) and `../patches/_vendor` (a checkout). The
usage lines that speak of `revenv` (`patch_mkparent.py:30`, the badge patch's `:41`) follow.

A3. `scripts/setup.sh`:
- Options: a value-taking option whose value is missing or empty exits 2 with `<option> needs a value` (F7;
  an empty `--dest` would otherwise copy into `/`). `--yes` answers the caution prompt below. `--help`
  prints the header down to `set -u` instead of a fixed range of lines. The two badge flags together exit 2.
- **Compatibility** (D5), first in the preflight. Each line is `OK`, `CAUTION` or `MISSING`:
  - `Apple Silicon`: `OK` on arm64; otherwise `CAUTION — an Intel Mac. Not supported: nothing here has been
    run on one.`
  - `macOS <version>`: `OK (tested)` for 26 and 27. For 14 to 25, `CAUTION — older than anything this has
    been run on. The engine's graphics library is built for macOS 26 and may not load.` Below 14, `CAUTION —
    below the minimum of DXMT, the graphics layer (macOS 14).` For 28 and later, `CAUTION — newer than
    anything this has been run on. Apple has said macOS 27 is the last release with general Rosetta support.`
  - `Rosetta 2`, on Apple Silicon only: `arch -x86_64 /usr/bin/true`. `MISSING` with `softwareupdate --install-rosetta
    --agree-to-license`. This is the one compatibility line that stops setup: without Rosetta nothing runs.
  - `python3`: `python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 8))'`, `MISSING` with
    `xcode-select --install`.
- After the preflight, when any line is `CAUTION`: one paragraph saying this Mac is outside what has been
  tested, that setup changes only what the install guide names and can be undone by its Uninstall section,
  and a pointer to the root README's Compatibility section. Then, when standard input is a terminal and
  neither `--yes` nor `--check` was given, `Press Return to continue, or Control-C to stop.` With no terminal
  it continues. `--check` prints the cautions and exits 0: a caution is not a failure, and is not counted in
  `All <n> checks passed`.
- The copy block (`:99-111`) also copies `patches/_vendor` (`cp -R`, replacing the installed one).
- A problem counter. A non-zero `repatch.sh` and a non-zero `make-shortcut.sh` each add one and print what
  failed and what to do. The closing text is `=== setup complete ===` only at zero; otherwise `=== setup
  finished with <n> problem(s): see the lines marked !! above ===` and exit 1, without the closing "Play"
  text. The repatch failure text no
  longer guesses at a game update: `repatch.sh` names the patches that failed.

A4. `repatch.sh`: `run <patcher> <args>` replaces each bare `python3 "$HERE/…"` line. A failure no longer
stops the run: each patch finds its own method by name or pattern, verifies it and writes or refuses by
itself, none reads another's result, and stopping at the first left a game update that moved one pattern with
every later fix unapplied. It ends, after the JetBrains stub lines, with `<n> of <expected> patch scripts finished without error`, and
when any failed, `FAILED: <names>` and exit 1. `<expected>` is 10, or 16 with `CS2_ERRNO_PATCHES=1`, worked
out after that override is read; a count that is not the expected one also exits 1. Counters use
`n=$((n + 1))`, and `run` tests the patcher in an `if`, so nothing depends on `set -e`. The line says
"finished without error" and not "applied" because of F11. `patch_cohtml.py` and `patch_longfile.py`, which
can tell their patched bytes from a file that has neither form, exit 1 for the second; the two that cannot
tell keep exit 0 (section 7).

A5. `launchers/launch-cs2-dxmt11.sh`, with no line added or removed in `ensure_patches`:
- `:182` keeps `repatch.sh`'s output instead of discarding it, and `:185`, still an `echo`, ends with its
  `FAILED:` line, so the log names the patch. `:153`'s comment says two launchers share the lock code, not
  "cs2's two". `:199` becomes `ensure_patches || note "Some patches could not be applied, so mods
  may not download. Update and run setup: INSTALL.md, After a game update."` `:316` is unchanged, so one
  notice per failure, at the start or after an update.
- `:192-193`: the badge step runs `python3`, and its condition is the installed file alone.
- After `# <<< rosetta-preflight`, a marked block `compat-note`: read the macOS major version; when it is not
  26 or 27 and `$PATCH_DIR/.compat-noted-<major>` does not exist, `note` one sentence (`This Mac runs macOS
  <version>, which this has not been tested on. See the README's Compatibility section.`) and create the
  marker. Never fatal. The marker is new in the install folder; `local-files-layout.md` treats it as
  workspace, which costs one repeated notice after that move.

A6. Documents: the manual environment line and its note leave `README.md` (root), `README.md` and
`INSTALL.md`; `INSTALL.md` "You need" says setup checks the Mac and what a caution means; the root README's
licence note names the two MIT libraries in `patches/_vendor/`; `patches/README.md` "If a game update breaks
them" keeps the maintainer's `capstone` line for `dis_pdx.py`.

### Stage C — one stack

C1. Removed with `git rm`: `launchers/launch-cs2.sh`, `launchers/Cities Skylines II (D3DMetal).command`.
C2. `repatch.sh`: the `free` target, `CX_GAME`, `FREE_GAME`, `COHTML_LICENSE` and the block at `:63-80` go, and
the header (`:1-23`) is rewritten for one stack. With no argument, or `dxmt11`, the target is the default
wrapper's game folder (or `CS2_GAME_DIR`); a path argument is that game folder. Both apply the ten. A path
argument also prints `ten patches (the Wine 11 set). An engine with the errno defect, Wine 10 included,
needs CS2_ERRNO_PATCHES=1`, and the echo at `:102` says the same. `free`, `FREE`, `d3dmetal` and `wine10` exit 2 with: `The Wine 10 + D3DMetal stack was retired on 2026-11-09.
Its last version is commit <sha>.` `<sha>` is the Stage A commit as pushed, the parent of Stage C's; it is
written once that commit exists and never amended. `wine11` and `DXMT11` stay as names for the default. The
loop at `:54` that finds the Wine user folder tries `Wineskin`, `$USER` and `crossover`, and no longer a
user's name. The comments at `:31-32`, `:51` and `:58` follow.
C3. `scripts/setup.sh` and `scripts/make-shortcut.sh`: `--stack dxmt11` and `--stack wine11` are accepted and
ignored; `--stack d3dmetal` and `--stack wine10` exit 2 with the same sentence. Both exit while reading
options, before anything is copied. The usage text drops the option, and setup stops passing it to
`make-shortcut.sh`. `WRAPPERS` is `CS2dxmt11.app CS2.app`. `make-shortcut.sh` keeps `STACK="dxmt11"` inside, so
the app's bundle identifier stays `local.cs2.dxmt11.launcher` (`:258`); its value-taking options get the
check of A3, since `--dest` with no value loops there too.
C4. `common/test-launch-lock.sh`: two launchers, `surviving-mars-relaunched/launch-relaunched.sh` and
`cities-skylines-2/launchers/launch-cs2-dxmt11.sh`; exit 2 unless both are found; header (`:2-9`) says two. The root `CLAUDE.md:13` says two launchers share
the lock code.
C5. Comments and live lines that name what is removed: `scripts/boot-verify.sh:93,99-100` (`CS2_ENGINE` and
`CS2_LAUNCHER` stay as overrides); `launchers/Cities Skylines II (DXMT Wine 11).command:6`;
`surviving-mars-relaunched/launch-relaunched.sh:19,129,135`; `surviving-mars-relaunched/tools/make-engine.sh`
(`:8`, `:10` and `:20`, the header's sentences about cs2's fallback, reworded with the line count unchanged,
since unification T14 cites `:48`; standalone mode stays); `surviving-mars-relaunched/README.md` (the clause
about the fallback, and "launchers" at `:59-60`); `PLAN.md:6-8`; `launchers/archive-dead-stacks/README.md:14`,
which names the removed `.command` as the one live launcher; `scripts/README.md`, which gains rows for the
new tests and for `patches/_vendor/`.
C6. Documents:
- `patches/README.md` "Which patches the game needs" is the one statement, in these words: the default stack
  needs ten of these and nothing else, and `setup.sh` and the launcher apply exactly those; the other six
  tolerate a file-error defect that Wine 10 had and some third-party Wine 11 builds bring back, off by
  default behind `CS2_ERRNO_PATCHES=1`; licence checks are out of scope: Wine 10 also failed a valid
  signature in `BCryptVerifySignature` (R3), so on that engine the game's UI middleware rejected its own
  valid licence, Wine 11 fixed that and that is the fix; this repository has never contained a way around
  that check, the project keeps none, and pull requests adding one are declined. Its first line counts 16.
- `README.md`: "Two stacks work" (`:43`) and "10 patches instead of 17" (`:44`) become one stack and ten
  patches; the stack table loses its Fallback column and its middle cell loses the licence clause (`:52`);
  the file table says "All 16 patches" (`:188`) and "The 16 binary patches" (`:199`); the paragraph at
  `:202-210` becomes two sentences that agree with the statement; `:228-229` says that Wine 11 also verifies
  the middleware's signature correctly.
- `docs/patch-inventory.md`: the two "Stack" lines become one; `:15-28` (which points at the row being
  removed, and says `repatch.sh` can only warn) and the R3 row at `:37` say that R3 forces no patch in this
  repository; section 4 keeps R3 as a root cause and loses its patch row and its
  box; "Applied by" names one command; the upstream list's item 3 says R3 is fixed in Wine 11.
- `docs/wine-bugs/README.md:6,9,18`: the counts lose "seventeen" and "17", and the R3 row says "fixed
  upstream in Wine 11 (measured 2026-08-22)".
- `CONTRIBUTING.md` "Out of scope": the statement in two sentences.
- `GOTCHAS.md:2710`: "and the unpublished `patch_cohtml_license`" becomes "and one workaround that was never
  published and that the project no longer keeps". `GOTCHAS.md:2909-2910`: "`old-patchers/patch_cohtml_license.py`
  found no fingerprint in the November `cohtml.WindowsDesktop.dll` and wrote nothing" becomes "The Wine 10
  era's workaround, which the project no longer keeps, found no fingerprint in the November
  `cohtml.WindowsDesktop.dll` and wrote nothing"; the measured result after it stays. Every other dated
  entry keeps the words it was written with.
- `INSTALL.md` troubleshooting, "Mods won't download": the patches are not all applied; run setup again and
  read its last lines.
- `CLAUDE.md` (this game's) rows `:14,16,22,23` and the root `CLAUDE.md:26-30`: what describes the
  maintainer's own machines (the fallback wrapper's state, the private mirrors) moves to the untracked
  `CLAUDE.local.md` at the repo root, which each Mac keeps for itself; the tracked rows keep what a contributor
  needs, and the root file keeps one line saying that private mirrors of two source trees exist, as its own
  rule about places outside the repo asks.
C7. Left alone on purpose: the six errno patch scripts; the S734M wrapper on anyone's Mac, which Surviving
Mars's tools still read; the reports under `docs/wine-bugs/` other than its `README.md`; dated entries in
`GOTCHAS.md`, `EXPERIMENTS.md`, `CONFIG-TRIALS.md` and `MODS-TESTING.md`; every plan under `docs/plans/`,
`cities-skylines-2/docs/plans/` and `surviving-mars-relaunched/docs/plans/`; `launchers/archive-dead-stacks/`,
`launchers/login-helpers/` and `archive/` (section 7); the name `patch_lockbypass`, which is about a file
lock (section 7); any `launch-cs2.sh` already in someone's install folder, which setup neither updates nor
deletes.

## 4. Who notices what

| Who | What changes | Mitigation |
|---|---|---|
| A new player | Three commands, no network at setup, all ten patches | The quick starts |
| A player who set up between 2026-10-10 and now | Nothing until they run setup again: `git pull` changes no installed file, and the new notices arrive with that same run. Then all ten apply and mods download | Issue #23, with "mods" in its text; the installed launcher's existing notice after a game update points at `INSTALL.md` "After a game update", which says pull and run setup |
| A player on a Mac outside the tested range | A caution and a prompt at setup; one notice from the launcher | The README's Compatibility section |
| A player without Rosetta | Setup stops with the command to install it, where it used to report the engine as fine | The line itself |
| An install where the badge patch has run | Nothing: the installed copy stays and stays current | `--show-mod-badges` |
| An install that has the badge file and has never run it (every install since 2026-08-27 without the environment) | The file is removed and one line says so | `--hide-mod-badges` |
| Anyone using `--stack d3dmetal` or `repatch.sh free` | A retirement message and exit 2. An app built that way keeps working from the launcher already in its install folder, whose own patch step was already failing (#20) | The message names the last commit |
| Anyone passing a bare game path to `repatch.sh` | Ten patches where it was sixteen, and a line saying so | `CS2_ERRNO_PATCHES=1` |
| An install made with `--dest` or `CS2_PATCH_DIR` | Setup and its patches now work there. The app still looks in `~/cs2-patch` (`make-shortcut.sh:106`, `launch-cs2-dxmt11.sh:71`), as today | `local-files-layout.md` L1 |
| The maintainer's Macs | The deployed fallback launcher stays on disk, unmaintained. The environment in `~/cs2-patch/revenv` is no longer used by anything but `dis_pdx.py` | Section 6 |

## 5. Test plan

Each new test file lands with the first stage that needs it and grows with the next: `test-setup.sh` starts
in Stage B with the clean run, the badge cases and mutant (b); Stage A adds the compatibility, failure and
option cases and mutants (a), (c), (d), and brings `test-repatch.sh` without its retirement and path cases,
`test-launcher-notes.sh` and `test-vendor.sh`; Stage C adds the retirement, path and `--stack` cases, S3 and
S9. Every test unsets `CS2_PATCH_DIR`, `CS2_WRAPPER`, `CS2_GAME_DIR` and `CS2_ERRNO_PATCHES`, which a
maintainer's shell may export, and puts a stub `xcrun` first on `PATH` so the app builder compiles nothing
and writes no compiler cache outside the scratch folder.

| # | Test | Passes when | Mutant, applied and seen red |
|---|---|---|---|
| S1 | `scripts/test-repatch.sh` (new): a scratch copy of `repatch.sh` beside a `patches/` of stub patchers that record how they were run | all succeed: `10 of 10 patch scripts finished without error`, exit 0, in today's order · `CS2_ERRNO_PATCHES=1`: `16 of 16` · one stub fails: the others still run, `9 of 10`, `FAILED: patch_mkparent.py`, exit 1 · `free` and `d3dmetal`: the retirement sentence, exit 2, no stub run · a path argument: ten, in that folder, with the errno line | (a) `run` ignores the exit status: the failing case prints `10 of 10` · (b) one `run` line removed: `9 of 10` and exit 1 with no `FAILED` name |
| S2 | `scripts/test-setup.sh` (new): `HOME` at a scratch folder holding a fake wrapper (a stub `wine64`, empty `steam.exe`, `Cities2.exe` and `Game.dll`), a scratch copy of `scripts/`, `launchers/`, `repatch.sh` and stub `patches/` with a `_vendor`, and a `PATH` that starts with stubs for `sw_vers`, `uname`, `arch`, `swiftc` and `open` | clean run on a stubbed macOS 27, arm64: exit 0, `setup complete`, no `CAUTION`, launcher, `repatch.sh`, patches and `_vendor` in `$HOME/cs2-patch`, an app in `$HOME/Applications`, no badge file · stubbed macOS 15: a `CAUTION` line, the paragraph, exit 0, and with no terminal no prompt · stubbed Intel: `CAUTION` · stubbed `arch` failing: `Rosetta 2 … MISSING`, exit 1, nothing copied · `--check` on macOS 15: the caution, exit 0, nothing written · `--hide-mod-badges`: badge file present; `--show-mod-badges` removes it · a badge file already installed with no `Game.dll.bak-modconflict-*`: removed, the `off` line · the same with one such backup: kept and refreshed · a failing patcher stub: exit 1, `finished with 1 problem`, no `setup complete` · a failing `make-shortcut.sh` stub: the same · `--dest` with no value: exit 2 at once · `--stack d3dmetal`: the sentence, exit 2, nothing copied · `--stack dxmt11`: as the clean run | (a) print `setup complete` unconditionally · (b) keep the badge file whenever a copy exists: the never-ran case fails · (c) today's `--dest` arm restored (`DEST="${2:-}"; shift 2`): the test's 5-second timer kills a loop · (d) treat macOS 15 as tested: the caution case fails |
| S3 | `common/test-launch-lock.sh` | 16 PASS: 14 cases and 2 parity lines | `MUTANT=1` exits 1; `acquire_lock` altered in one launcher of a scratch copy: a parity line differs; one launcher removed: exit 2 |
| S4 | `scripts/test-launcher-notes.sh` (new), in the manner of `test-update-check.sh`: `ensure_patches` and the `compat-note` block taken from the launcher by name and marker, with a stub `repatch.sh`, a stub `sw_vers` and a recording `note` | a `repatch.sh` that exits 1: the call line raises exactly one note, and the function alone raises none · macOS 27: no compat note · macOS 15: one note and a marker; a second run: none | (a) the call line without `|| note`: no note · (b) the marker never written: a note on the second run |
| S5 | `scripts/test-vendor.sh` (new) | `shasum -a 256 -c` on `patches/_vendor/MANIFEST.sha256` passes; `patch_cohtml.py` and `patch_longfile.py`, given a scratch file with neither form of their bytes, exit 1; the manifest lists every file under `_vendor` but itself and the two docs; `/usr/bin/python3 -I` and `python3 -I` each import `dnfile` from `_vendor` and report 0.18.0; each of the five patchers and the badge patch, run with a scratch `HOME` and a target that does not exist, gets past its import | one byte changed in a scratch copy of one vendored file: the check fails |
| S6 | By hand, once, when the wheels are unpacked: the 15 vendored files against the two wheels of F10 | each wheel's sha256 is F10's; every vendored file is byte-identical to its wheel member; recorded in the as-built header | none: a measurement |
| S7 | By hand on the Studio, no game or Steam running: a scratch folder holding an APFS clone of the default wrapper's `Cities2_Data/Managed` and `Cities2_Data/Plugins/x86_64`, each of the five patched files restored from its `.bak`; a scratch copy of `repatch.sh` and the real `patches/`; run with `/usr/bin/python3` first on `PATH`, then with the default | first run `10 of 10`, and each of the five files then equals the live, patched file of the real install; second run `10 of 10` with nothing written; the real install is not touched | none: a live measurement on copies |
| S8 | On the Studio, which has the wrapper two of them read. The standing tests and gates: `test-update-check.sh`, `test-rosetta-preflight.sh`, `test-p4-signals.sh`, `check-experiments.py`, the seven Surviving Mars tests, `common/check-links.py`, `ACCEPT=9 common/check-identifiers.sh`, `bash -n` on every `.sh` and `.command`, `py_compile` on every `.py` | each as before: 25 passed, ALL PASS, ALL PASS, exit 0, seven green, 0 unresolved, 9 | none: unchanged tests |
| S9 | Words, by `git grep`. Over every tracked file but the three plan folders (`':!docs/plans' ':!*/docs/plans/*'`): `patch_cohtml_license`, `private set`, `COHTML_LICENSE`. Over the same less the dated files C7 names: `withh`, `unpublished`, `17th`, `instead of 17`, `publishable`, `licence bypass`, `license bypass`. In any `.sh`, `.py` or `.command` outside the archives: `launch-cs2.sh`. `git grep -n -i -E 'd3dmetal|wine10'` in `repatch.sh`, `scripts/setup.sh` and `scripts/make-shortcut.sh`. `git cat-file -e <sha>:cities-skylines-2/launchers/launch-cs2.sh` | 0 hits each for the word lists; the `d3dmetal` search shows the retirement arms and sentence and nothing else; `has never contained a way around that check` is in `patches/README.md` once; the `cat-file` succeeds | none: a count |
| S10 | On the Studio, no game or Steam running, after a `cmp` of the 22 deployed files against the checkout shows nothing there is newer: `bash scripts/setup.sh` from the checkout | exit 0; the preflight shows `macOS 27.2 … OK (tested)` and `Rosetta 2 … OK`; `10 of 10 patch scripts finished without error`; `setup complete`; the 21 files setup deploys, and `_vendor`, equal the checkout; the installed badge file is still there and current | none: a live run |
| S11 | A clone of the checkout under `/tmp`: the README quick start with `--check` appended | prints the preflight and stops | none: unification T11 re-run |
| S12 | Visible, James warned first, the MacBook's Steam closed: `scripts/boot-verify.sh` on the Studio | PASS | none: a live run |

## 6. What this changes in the two other plans

Both were checked against a tree that had the fallback and an environment. Neither is re-checked here; each
already requires a fitted re-check before its next phase is built, and this list is for that pass.

- `docs/plans/1launcher-unification.md`. Its Phase 3 exit was judged and recorded on 2026-11-09 (`8c39d69`),
  before any of this is built. After Stage C: T2 reads 21 of 21 and its file list (`:264`) loses one launcher;
  T8 reads 16 PASS over two launchers; the exit `git grep` for the old Surviving Mars home prints nothing;
  Phase 4's exit (`:242`) and Phase 5's outline speak of what was three launchers. Also touched: `:81`,
  `:86`, `:88`, `:216`, `:270`, `:285`.
- `docs/plans/local-files-layout.md`. `launch-cs2.sh` stays among the seven runtime names, as a file an older
  install may hold; the repo no longer ships it, so its 3.2 row for `launch-cs2.sh:102-103` (`:113`) has no
  file to edit and must say what the move does with a stale copy. Its 3.2 row for the five patchers' head
  (`:114`) and its 3.5 rule about `revenv/bin/python3 -m pip` fall away: the patchers no longer use an
  environment, and `revenv` becomes a maintainer's folder. `:119` ("copies both launchers"), defect (2) at
  `:51` and B2 at `:273` go. LT3 and LT4 read 21 files, and LT3's mutant needs a new form; LT2, LT12 and LT14
  count one `.command` wrapper, and LT14's four files become three; LT10's cites into the launcher move with
  the `compat-note` block. The counts at `:30`, `:40`, `:41` and `:66`. Its section 7 item on three older
  defects is down to one. A new name appears in the install folder, `.compat-noted-<major>`. Its counts of
  `cs2-patch` lines (LT12) and its cites into `INSTALL.md` moved with `11ece32` and move again here.

## 7. Not in this plan

- An install guide for someone who has never used Terminal, with screenshots; a double-click installer; setup
  installing Steam into the wrapper; a wrapper built without Porting Kit's interface. Each needs its own plan.
- CI and branch protection.
- `LSMinimumSystemVersion` in the three generated apps (13.0 today). A wrong value there blocks the app with
  no way on, which is the opposite of D5; the checks of A3 and A5 do the job.
- Renaming `patch_lockbypass`, which a reader can take for something it is not.
- `patch_colossal_io.py` and `patch_asset_database.py` cannot tell a moved pattern from an applied patch
  (F11): an issue.
- `launchers/archive-dead-stacks/`, `launchers/login-helpers/` and `archive/`: dead scripts, one of which asks
  for a Steam password in a dialog. Whether they stay in the tree is the maintainer's call.
- `CS2_WRAPPER` and `CS2_PATCH_DIR` not carried into the app; the launcher not passing `CS2_ERRNO_PATCHES`;
  the engine build's unlisted requirements; the uninstall section's gaps; recovery from an expired Steam
  sign-in on the 11.16 engine. Each wants an issue.
- The MacBook: whether a copy of the deleted tool is in its scratch folder, and its own `setup.sh` run, both
  at its next visit.

## 8. Decisions (James)

| # | Question | Recommendation |
|---|---|---|
| O1 | How setup gets the Python library five patches need: (a) ship the two MIT libraries in the tree, 15 files and about 540 KB, checked against PyPI's wheels once and by a manifest ever after; or (b) have setup create an environment and download them, pinned and hash-checked, each time a Mac is set up | **(a)**, and the plan is written for it. It needs no network, no environment that goes stale when a Python is upgraded, and no second interpreter; it works from a checkout and from any install folder; and it is what a player who has never used Terminal can least get wrong. Its cost is third-party code in this repository, updated by hand. (b) was measured and works (F10); the first review found four things it would also need: wheels only, a rebuilt environment when one goes stale, a real `python3` check, and a way to reach the environment from every place a patcher runs |

## Rollback

Revert the stage's commit and run `setup.sh` again: the deployed files follow the checkout. A removed badge
file comes back with `--hide-mod-badges`. The deleted private tool (D2) is not coming back, by design.

## Review corrections (first pass, 2026-11-09)

Two lenses read the first draft at `ba03834`. A builder built Stages A to C on a scratch clone, wrote the two
test files and ran them with every mutant; a second reader traced what each kind of player would see, the
security of the install step, and the two other plans. Both said build-ready-with-fixes. Each blocker was
re-read against the code before folding.

| # | Finding | Lens | Folded into |
|---|---|---|---|
| B1 | **Blocker.** "Keep the badge file when a copy is already there" would have switched the patch on for every existing install: setup has copied the file into every install since 2026-08-27, and the launcher runs it as soon as it can | rollout | Stage B (B1), section 4, S2 |
| B2 | **Blocker.** Stage A made the patch runnable before Stage B gated it | builder | build order B, A, C |
| S1 | Downloading the library needed four more things to be safe: wheels only, an environment rebuilt when it goes stale, a real `python3` check, and a way to reach the environment from every place a patcher runs. Shipping the two MIT libraries removes all four | rollout | A1, A2, F10, O1 |
| S2 | "10 of 10 patches applied" can be false: four patchers exit 0 when their pattern is missing | builder | F11, A4, section 7 |
| S3 | Stopping at the first failure left a game update that moved one pattern with every later fix unapplied | rollout | A4 |
| S4 | The launcher's new notice fired twice after an update and gave advice that could not help; the launcher also threw away the line that names the failed patch | both | A5 |
| S5 | The player who most needs the fix hears nothing until the setup run that also fixes it | rollout | section 4, issue #23 |
| S6 | The statement claimed that every copy of the private tool was gone, which a second Mac makes unprovable | rollout | C6 ("the project keeps none"), section 7 |
| S7 | Live lines that would still point at removed pieces: 14 files beyond the first list | both | C5, C6 |
| S8 | The word check could not see its own edits, searched for a string that occurs nowhere, and named no phrase to count | both | S9 |
| S9 | The retirement sentence's commit was undefined; `make-shortcut.sh` keeps the same endless loop; an empty `--dest` copies into `/` | builder | C2, C3, A3 |
| S10 | A path argument silently went from sixteen patches to ten | rollout | C2 |
| S11 | Tests missing: the real patchers end to end, the launcher's notices, a failing app builder, the compatibility lines, `--stack dxmt11`, a miscount with no failure | both | S1, S2, S4, S5, S7 |
| S12 | Eleven line cites off by one to three | builder | sections 1 and 3 |
| m | The header's path rule; which `CLAUDE.local.md`; `--help` tied to line numbers; a user's name as a literal in `repatch.sh:54`; both badge flags at once; the opt-in flag silent for other wrappers; the test Mac's `python3` is Homebrew's 3.14 while the environment was Apple's 3.9; tests must unset the maintainer's `CS2_*` variables and stub `xcrun` | both | throughout |

Not folded: carrying `CS2_ERRNO_PATCHES`, `CS2_WRAPPER` and `CS2_PATCH_DIR` from setup into the app
(section 7); a third lens for design, since no page a player sees in a browser changes shape.

Measured for the fold: the two wheels' hashes and contents (F10); both install routes under both Pythons;
pristine backups beside all five patched files on the Studio, which makes S7 possible; the deleted tool was
the only copy on the Studio and no installed game file carried its change.

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-09 | 1 (fitted lenses) | builder simulation + correctness + test plan · rollout + security of the install step + consistency with the two other plans | 2 agents; the builder built Stages A to C on a scratch clone and ran the tests with every mutant; both blockers re-read inline; folded and audited two-sided | Fable 5.2 | `ba03834` | build-ready-with-fixes (2 blockers) |

Key paths: `cities-skylines-2/scripts/setup.sh` · `cities-skylines-2/scripts/make-shortcut.sh` ·
`cities-skylines-2/repatch.sh` · `cities-skylines-2/patches/` · `cities-skylines-2/launchers/` ·
`cities-skylines-2/scripts/patch-modconflict-badge.py` · `common/test-launch-lock.sh` ·
`cities-skylines-2/INSTALL.md` · `cities-skylines-2/README.md` · `cities-skylines-2/docs/patch-inventory.md`.
