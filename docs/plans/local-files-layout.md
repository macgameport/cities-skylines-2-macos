# Local files — out of the home folder, into the places macOS sets aside

> **Status: written 2026-11-09, not yet checked.** No code starts from this file until it carries a dated verdict.
> Tracking: issue #22 (the umbrella for `1launcher-unification.md`), one checkbox per phase (O9).
> File and line references are as of `adc5900`. A path that does not start with a root folder is relative to
> `cities-skylines-2/`. Surviving Mars references are to its public commit `14df074`. "The unification plan"
> is `docs/plans/1launcher-unification.md`; its phases are "Phase 1" to "Phase 5", this plan's are L0 to L3.

## 0. Decisions already made (James, 2026-11-09)

| # | Decision | His words |
|---|---|---|
| D1 | Game files should not sit in the home folder, and should be unified like the launcher | "Is there a more appropriate directory for game files than home? Since the launcher is unified should the game files be too?" |
| D2 | Follow the operating system's own standard | "Is there an osx standard for applications that should be followed?" |
| D3 | Plan it, then check it | "Plan it and check it" |

This replaces the unification plan's O7 ("out of scope"). Everything else in section 8 is a recommendation.

## 1. Where things are today (measured 2026-11-09 on the Studio, macOS 27.2)

| Thing | State |
|---|---|
| `~/cs2-patch` | 153 G, 71 loose files and 43 folders, four kinds mixed together. **(1) What the game runs:** the 22 deployed files, `revenv/` (a 17 M Python virtual environment that the badge patch and five patchers need) and `change-ledger.txt`. **(2) Evidence and run folders** (`evidence/` with 304 cells, `boot-verify/`, `perf-runs/` and others), outside the repo because captures carry the Steam display name. **(3) Four source-and-build trees, 12.9 G:** `build-1116` 5.0, `build-1116-unify` 7.2, `dxmt-fork` 0.4, `dxmt-v080` 0.3. **(4) One 91 G rollback copy** of an older game build |
| `~/sm-patch` | 1.6 G: the checkout plus `engine/` 0.93, `backup/` 0.57, `runs/` 0.06. Leaves the home folder in Phase 3 (unification O9) |
| Wrappers and double-click apps | `~/Applications`, the standard place. Each game sits inside its own wrapper |
| Launcher logs | `~/Library/Logs/cs2-launcher.log` and `sm-relaunched-launcher.log`, the standard place |
| `~/Library/Application Support/1launcher`, `~/Library/Caches/1launcher` | neither exists |

**What names `~/cs2-patch`** (everything a move can break):

| Item | Measured |
|---|---|
| Tracked files | 72 files, 291 lines: 41 under `scripts/`, `launchers/`, `patches/` and `repatch.sh` (102 lines; 62 of the `scripts/` lines are not comments), 31 documents (189 lines) |
| Deployed files that hold the path as code | `launchers/launch-cs2-dxmt11.sh:71` (`PATCH_DIR`, default the old folder; its six uses at `:88-193` are all quoted); `launchers/launch-cs2.sh:102-103` (the same default written inline twice); the five PDX patchers' shared block (`_REVENV` and its error text, e.g. `patches/patch_createfile.py:37,44`; the block has one checksum across the five). `repatch.sh:8` and the other twelve patches already use their own location |
| Overrides that exist | `CS2_PATCH_DIR` (`scripts/setup.sh:23`, both launchers), `CS2_BUILD_DIR` (`scripts/build-winemac-visibility.sh:23`), and single-purpose ones: `CS2_LAUNCHER`, `CS2_DRIVER`, `CS2_PERF_DIR`, `WINEMAC_SRC`, `WINEMAC_BUILD`, `DXMT_FORK_DIR`, `DXMT_WINE_INSTALL`, `CS2_VANILLA_DIR`. 37 of the 41 files carry neither `CS2_PATCH_DIR` nor `CS2_BUILD_DIR` |
| The CS2 app | its shim holds the launcher's absolute path (`scripts/make-shortcut.sh:78`, called from `scripts/setup.sh:124`) |
| Two `.command` wrappers in `launchers/` | `exec bash "$HOME/cs2-patch/launch-…sh"` |
| Seven scripts name a build tree in code (10 lines) | `build-dxmt-fork.sh:25-26`, `build-winemac-visibility.sh:23`, `build-winemac.sh:32-33`, `hosting-layer-tests.sh:52-53`, `make-vanilla-wrapper.sh:29`, `regen-winemac-patches.sh:22`, `steam-vanilla-d3d-split.sh:40` |
| Gates that read the folder | `scripts/check-experiments.py:37` (the evidence store: a ledger row whose cell folder is gone is an error) and, called from it, `scripts/regen-winemac-patches.sh:22` (a git repo nested in `build-1116`; absent is exit 64). **Two tests weaken without a word if their path is wrong:** `scripts/test-update-check.sh:165` reads the rollback copy's manifest only if it is there (25 passed with it, 24 without), and `scripts/test-p4-signals.sh:76` reads real perf logs only if they are there (`pass live: 41 real logs`) |
| Outside the repo | the scheduled task `reddit-watch-cs2` (10 lines of its `SKILL.md`); 13 Claude memory files (45 lines); Claude project entries keyed to the folder and to one folder inside `build-1116`; 7 untracked scripts and notes loose in the folder itself |
| Not keyed to it | launch agents, cron, shell profiles, the git identity includes, every wrapper (0 symlinks into it, 0 config lines naming it), every sibling repo |
| The MacBook | not visible from the Studio; the unification plan's section 6 already asks whether the folder exists there |

**A defect that exists today.** `setup.sh --dest <dir>` (or `CS2_PATCH_DIR`) deploys somewhere else and builds the app to start the launcher there, but the shim starts it without that variable (`scripts/make-shortcut.sh:106`), so the deployed launcher still looks for `repatch.sh`, the display profile and the badge patch in `~/cs2-patch`. Section 3.2 removes it.

**What cannot simply be moved:**

- **The build trees hold their own absolute path.** Four `build.ninja` files carry it on 10 to 22 lines each, and `build-1116-unify/wine-1116-build/config.status` on 18; the other build folders were not opened. After any move a tree must be configured again before it builds.
- **Three of them are the only copy of something.** `build-1116/wine-11.16-dxmt/dlls/winemac.drv` is a git repo with 12 branches and no remote: the source of the three published winemac patches, and what the drift gate reads. `build-1116/wine-11.16-stockcore` is a git repo with no remote and 26 uncommitted files. `dxmt-fork`'s remote is another person's fork, and it has 3 uncommitted files. The Studio has no Time Machine destination.
- **`revenv/` is a virtual environment.** See P1.

**Probes** (scratch copies, removed afterwards):

| # | Probe | Result |
|---|---|---|
| P1 | A throwaway app, started the way a double-click starts one, whose shim runs a script in a folder under `~/Library/Application Support/` | exit 0, no permission prompt. The script found its own folder, ran a helper beside it, ran the system Python on a file in `patches/`, ran an APFS clone of `revenv` (`dnfile`, `capstone` and `pefile` import; `sys.prefix` is the new place) and wrote a file there. The clone's console scripts (`bin/pip`) still start through the old folder's path |
| P2 | `git bundle create --all` of the nested winemac repo, restored by `git clone` | 277 KB; the same 12 branch tips. The drift gate against the restore **fails** (three DRIFT, three FAIL) until the repo's two local settings are copied too (`diff.srcprefix` = `a/dlls/winemac.drv/`, `diff.dstprefix` = `b/dlls/winemac.drv/`); then it exits 0 |
| P3 | Does Wine's `configure` refuse a path with a space? | It has no such check (read, not run). Whether the `gmake` build then works at such a path was **not tested**: section 2 keeps builds off any path with a space, so nothing here depends on the answer |

## 2. Target

Apple's file-system guidance gives each kind of file a place and asks apps not to create folders at the top of the home folder.

| Kind | Standard place | Used for |
|---|---|---|
| The apps | `~/Applications` | wrappers and double-click apps (unchanged) |
| Files an app keeps for itself | `~/Library/Application Support/<name>/` | what a game runs, its state, and anything that must stay private |
| Things that can be made again | `~/Library/Caches/<name>/` | source-and-build trees, engines (O3, O4) |
| Logs | `~/Library/Logs/` | the two launcher logs (unchanged) |

```
~/Library/Application Support/1launcher/      the data root
├── cities-skylines-2/                         today's ~/cs2-patch, every name inside unchanged, minus the four trees
└── surviving-mars-relaunched/                 backup/ and runs/ (unification O9)
~/Library/Caches/1launcher/                    the build root: no space in its path
├── cities-skylines-2/                         build-1116/  build-1116-unify/  dxmt-fork/  dxmt-v080/
└── surviving-mars-relaunched/                 engine/ (O4)
```

**One rule maps every old path:** `~/cs2-patch/X` becomes `<data root>/cities-skylines-2/X`, except the four trees, which become `<build root>/cities-skylines-2/X`. Nothing inside is renamed or regrouped. On the Studio the home folder ends with neither `~/cs2-patch` nor, after Phase 3, `~/sm-patch`.

Unchanged: the wrappers, one wrapper per game, both engines, the two log paths, CS2's deploy model (copies outside the repo, because an app may not run scripts from a clone under `~/Documents`: `scripts/setup.sh:14-15`), and Surviving Mars running from its checkout.

## 3. Design

**3.1 The folders are named once.** A new sourced file, `common/paths.sh`, is the only tracked code that spells either root. It sets `L1_DATA_ROOT` and `L1_BUILD_ROOT` (each overridable from the environment), `CS2_DATA` (override: the existing `CS2_PATCH_DIR`; default by the rule in 3.3) and `CS2_BUILD` (`$L1_BUILD_ROOT/cities-skylines-2`). Repo-side shell scripts source it by their own location and write every path as `"$CS2_DATA/…"` or `"$CS2_BUILD/…"`; each single-purpose override keeps its name and only its default changes. Python callers ask it (`bash -c '. <repo>/common/paths.sh; printf %s "$CS2_DATA"'`) so the rule is not written a second time. The root is named after the repo, and the repo's name is a label: with one definition and a generated app shim, renaming it is one line, one `mv` and one `setup.sh` run (LT13).

**3.2 Deployed files find themselves.** They cannot source a repo file, and do not need to: they sit in the data folder.

| File | Change |
|---|---|
| `launchers/launch-cs2-dxmt11.sh:71` | `PATCH_DIR="${CS2_PATCH_DIR:-$(cd "$(dirname "$0")" && pwd)}"`; header lines `:9-10`, `:14` reworded |
| `launchers/launch-cs2.sh:102-103` | one `PATCH_DIR` line of the same form, used twice; comments at `:5` (the engine path, per O4), `:12`, `:100` |
| the five PDX patchers' shared block | `_REVENV` is `revenv/bin/python3` beside the `patches/` folder the script is in; the error text names that path. Edited identically in all five (LT5) |
| `repatch.sh:6`, `scripts/cs2-display-profile.sh:4`, `scripts/patch-modconflict-badge.py:41` | comments only |

This also removes the `--dest` defect of section 1. One behaviour changes: a launcher started straight from the repo's `launchers/` folder no longer finds the helpers. It prints its existing "no … in $PATCH_DIR" notes and skips the patch check, where today it finds `~/cs2-patch`. Every caller in the repo starts the deployed copy (`scripts/boot-verify.sh:94`, `scripts/perf-run.sh:23`, `scripts/diag-launch-dxmt11.sh:28`, the two `.command` wrappers), and the `:9` header already says to install it with `setup.sh`.

**3.3 An install made before this keeps working where it is.** The default for `CS2_DATA` is the new folder, unless the new folder does not exist and `~/cs2-patch` does: then it is `~/cs2-patch`. `scripts/setup.sh:23` takes its default from `common/paths.sh` and prints the folder under its `repo:` line, so `--check` shows which one it will use. The two `.command` wrappers carry the same three-line rule inline, because people copy them out of the repo. `INSTALL.md` gains a short "moving an existing install" paragraph: quit the game, `mkdir -p` the data root, `mv` the old folder to the new name, run `setup.sh`. Nobody's folder is moved for them. 128 people cloned this repo in the 14 days to 2026-11-08.

**3.4 What makes the build root safe to empty.** Before any tree moves, L2 writes into `<data>/source-snapshots/`, for each of the three repos of section 1: a bundle of every ref, the repo's local `diff.*` settings, and for the two with uncommitted files a `git diff HEAD` plus an archive of the untracked files. LT7 restores the winemac snapshot and runs the drift gate against the restore, the way P2 did. From then on everything under the build root can be made again from a vendor download plus the snapshots, which is what the Caches folder is for; a cleanup tool that empties it costs a rebuild and loses nothing. The trees themselves move unconfigured: `CLAUDE.md` § Where things live records that each needs its configure step again before the next build, and that a rebuilt module is not byte-identical to the installed one, because the build path is compiled in.

**3.5 Documents.** Living documents are rewritten to the new paths: both `CLAUDE.md` files, `INSTALL.md` (`:74`, `:200`, `:213`, `:222`, `:293`; commands a reader types run from the checkout wherever a repo copy exists, and the full path appears quoted where it must), `scripts/README.md`, `docs/agent-brief.md`, `docs/patch-inventory.md`, `docs/images/AUDIT.md`, `MODS-TESTING.md:194` and `PLAN.md`. Dated records keep the path they were written with: `EXPERIMENTS.md`, `GOTCHAS.md`, everything under `docs/plans/`, `docs/dxmt-bugs/` and `docs/wine-bugs/`, `docs/perf-pass-results.md`, `docs/steam-ui-investigation.md`, `docs/test-matrix.md` (generated) and the rest of `MODS-TESTING.md`. One sentence giving the mapping rule of section 2 goes at the top of `EXPERIMENTS.md` and `GOTCHAS.md` and into `CLAUDE.md` § Where things live. The root `CLAUDE.md`'s list of places allowed outside the repo changes to the two roots.

## 4. Phases

Each phase ends green before the next starts. L1 and L2 start after Phase 3 of the unification plan is green on the Studio (O5): Surviving Mars is the small pilot for the data root, and the two plans then never edit the same files at the same time.

### L0 — decisions, and what they change in the unification plan (no code)

1. James answers section 8.
2. Already done with this plan: the unification plan's O7 row and its section 2 "Unchanged" sentence point here.
3. If O4 is accepted, before Phase 3 is built: in the unification plan, `engine/` goes to `<build root>/surviving-mars-relaunched/` in the O9 row, in 3.2 (the default output at `tools/make-engine.sh:48`), in 3.5 (the move) and in T14 (which then expects `runs/` and `backup/` under the data root and `engine/` under the build root). That edit is new material in a checked plan: it is audited two-sided and re-checked by one fitted pass before Phase 3 starts.

### L1 — the repo (public; one commit for code and tests, one for documents)

1.1 `common/paths.sh` and `common/test-paths.sh` (LT1, LT13).
1.2 The deployed files, per 3.2. Never edited in place in the data folder: the repo copy is edited and `setup.sh` copies it.
1.3 Every other script: source `common/paths.sh`; replace each path by the rule of section 2; quote every use (LT2). The four lines found unquoted today (`scripts/run-60262-repro.sh:12,13,16`, `scripts/shimmer-probe.sh:26`) are fixed here. `scripts/check-experiments.py:37` asks `common/paths.sh`.
1.4 `scripts/setup.sh` per 3.3; `scripts/make-shortcut.sh:46,48` take their default launcher from `common/paths.sh`; the two `.command` wrappers.
1.5 If Phase 3 is built: Surviving Mars's five scripts take `SM_STATE` and the engine default from `common/paths.sh` in place of their own identical line (unification 3.2), and T14 is run again.
1.6 Documents, per 3.5.
1.7 On the Studio, the old folder still in place: `bash scripts/setup.sh` from the game folder. It resolves to `~/cs2-patch` by the rule of 3.3, copies the new files, runs the idempotent patch pass and rebuilds the app. Then LT10. This is the path every existing user takes after `git pull`.

**Exit criteria.** Working tree clean. LT1, LT2, LT3, LT5, LT13 pass. LT4 reads 22 of 22 at `~/cs2-patch`. LT6 reads its pinned numbers. LT9 names `~/cs2-patch/launch-cs2-dxmt11.sh`. LT10 passes. LT11 prints only its allowed list. LT12 passes. The unification plan's gates that still apply are green.

**Rollback.** Revert both commits and run `setup.sh` again; the folder has not moved, so the old launcher finds it.

### L2 — the Studio's folders

1. Preflight. Nothing running: no game, Steam, launcher or `wineserver`. The scheduled task disabled. **No Claude session and no shell has its working directory inside `~/cs2-patch`**; this phase is run from the checkout. The data folder for CS2 does not exist. `~` and `~/Library` are on one volume, so every `mv` is a rename. Record LT6's numbers and `ls -A ~/cs2-patch | wc -l` (114).
2. Snapshots, per 3.4, into `~/cs2-patch/source-snapshots/`; LT7.
3. `mkdir -p` both roots and the two game folders under the build root. `mv` the four trees to `<build root>/cities-skylines-2/`, then `mv ~/cs2-patch "<data root>/cities-skylines-2"`.
4. `bash scripts/setup.sh` from the game folder: it now resolves to the new folder, copies the 22 files, runs the patch pass and rebuilds the app with the new launcher path. LT4, LT8, LT9.
5. What names the old path outside the repo: the scheduled task's 10 lines, then enable it; the 13 memory files and the pointer note in the `~/cs2-patch` Claude project; the 7 loose untracked files, by hand, or left with a note if dead (`queue-s2b.sh` already is).
6. LT6 again, then LT10, then LT11.

**Exit criteria.** `ls -d ~/cs2-patch` finds nothing. The data folder lists 111 entries: 114, less the four trees, plus `source-snapshots`. LT4 22 of 22 at the new place; LT6 the same numbers as before the move; LT7, LT8, LT9, LT10 pass; `git status --porcelain` empty.

**Rollback.** Quit everything; `mv` the data folder back to `~/cs2-patch` and the four trees back inside it; run `setup.sh` (the rule of 3.3 picks the old folder again, and the self-locating launcher runs from either). Undo step 5 by hand.

### L3 — the MacBook

In the same visit as the unification plan's Phase 4 where that is still ahead; otherwise a visit of its own. Its inventory first (does `~/cs2-patch` exist there, what is in it, what is running). Then L2 steps 1 and 3 to 6 for what it has; step 2 only if it holds a repo with no remote. No Claude auto-memory is written there (global rule).

Exit: the same criteria, measured there; both games started once from their apps.

## 5. Who notices what

| Audience | Effect | Mitigation |
|---|---|---|
| People with an existing install | none until they choose: `git pull && bash scripts/setup.sh` keeps using `~/cs2-patch` | 3.3, LT1, L1 step 1.7 |
| New installs | files land under `~/Library/Application Support/1launcher/`, which Finder hides | `setup.sh` prints the folder; the install guide gives `open "<path>"` |
| Anyone typing a path | it now contains a space | 3.5: commands run from the checkout; the full path is shown quoted |
| James, browsing evidence | the folder is no longer one click from home | a Finder sidebar entry, his to add |
| Claude sessions | a session started in `~/cs2-patch` has no folder afterwards; memory and one scheduled task name the old path | L2 steps 1 and 5 |
| The next engine build | each tree needs its configure step again | 3.4 |

## 6. Test plan

| # | Test | Passes when | Mutant, applied and seen red |
|---|---|---|---|
| LT1 | `common/test-paths.sh`, with `HOME` set to a scratch folder: `CS2_DATA` when neither folder exists, when only the old one does, when both do, and with `CS2_PATCH_DIR` set; `CS2_BUILD` contains no space | new · old · new · the override; no space | invert the old-install test in `common/paths.sh`: the second case is red |
| LT2 | `shellcheck` (O7) over every tracked `.sh` and `.command`: SC2086 reports on a line that names `CS2_DATA`, `CS2_BUILD`, `L1_DATA_ROOT`, `L1_BUILD_ROOT`, `PATCH_DIR` or `DEST` | 0 | drop the quotes at one site: 1 |
| LT3 | No game, no setup run: copy the 22 deployable files and an APFS clone of `revenv` into a scratch folder whose path has a space, laid out as `setup.sh:105-110` lays them out; clone the game's `Cities2_Data/Managed` folder beside an empty `Cities2.exe` in a second scratch folder; with `HOME` set to a third, run `CS2_GAME_DIR=<game scratch> bash "<scratch>/repatch.sh" dxmt11` | exit 0, and the same output as the same run from a folder with no space, paths normalised | restore the old `_REVENV` line in one patcher: `ERROR: needs dnfile` |
| LT4 | The unification plan's T2 (`cmp` of the 22 deployable files) against the folder `common/paths.sh` resolves; `setup.sh --check` prints that folder | 22 found, 22 identical | `CS2_PATCH_DIR` at an empty folder: 0 found |
| LT5 | The shared block of the five PDX patchers, from its marker line to `def die` | one checksum | edit one patcher only: two |
| LT6 | Pinned numbers, recorded before L1 and read again after L1 and after L2: `check-experiments.py` exits 0 with the same cell count (304 today); `test-update-check.sh` prints 25 passed; `test-p4-signals.sh` prints a `pass live:` line with at least 41 logs; `regen-winemac-patches.sh --check` exits 0; the lock test's count (17, or 24 once it is `common/test-launch-lock.sh`) | all | `CS2_PATCH_DIR` and `WINEMAC_SRC` at empty folders: `check-experiments.py` exits 1, the update check prints 24, the live line is missing, the drift gate exits 64 |
| LT7 | Restore each snapshot into a scratch folder; for the winemac one apply the recorded settings and run the drift gate with `WINEMAC_SRC` at the restore | 12 branch tips equal; exit 0 | leave the two settings out: three DRIFT lines, exit 1 (measured in P2) |
| LT8 | After the move: `"<data>/revenv/bin/python3" -c "import dnfile, capstone, pefile"`, and `… -m pip --version` | both succeed; pip names the new folder | the system `python3` in its place: `ModuleNotFoundError` |
| LT9 | The CS2 app's shim | its `SCRIPT=` line names the launcher in the folder LT4 used, and that file exists | `make-shortcut.sh --launcher` at a missing file: exits 1 (`:60`) |
| LT10 | Live, James warned first and the MacBook's Steam closed: `scripts/boot-verify.sh`, detached with a log, its launcher the shim's `SCRIPT` | `VERDICT: PASS` and `GRACEFUL: yes`; the launcher log has the display-profile line and none of the three "no … in" notes (`launch-cs2-dxmt11.sh:91`, `:188`, and the badge step) | none: a live run. Run twice: end of L1 from the old folder, end of L2 from the new |
| LT11 | `git grep -c 'cs2-patch'` | only the old-install rule (`common/paths.sh`, its test, the two `.command` wrappers, the `INSTALL.md` paragraph), the mapping sentences, and the record files of 3.5; the list and its counts are written into this file at L1 | add one mention to a living document: one more line |
| LT12 | The unification plan's T1 (links), T6 (identifiers, `ACCEPT=9`) and T13 (ignore rules) | as there | theirs |
| LT13 | With `L1_DATA_ROOT` and `L1_BUILD_ROOT` set to scratch folders: LT1's resolver and `setup.sh --check`; and `git grep -l 'Application Support/1launcher' -- '*.sh' '*.py' '*.command'` | both show the scratch folders; one file, `common/paths.sh` | write the root into one more script: two files |

## 7. Not in this plan

- **Moving the wrappers.** `~/Applications` is the standard place; 38 tracked files here and 9 in Surviving Mars name a wrapper path.
- **Regrouping what is inside the CS2 folder**, or the log paths. A pure rename keeps every recorded path one rule away.
- **Disk space.** The 91 G rollback copy moves with the folder; the 103 G test wrapper `CS2child-test.app` stays in `~/Applications`. The Studio's disk is 90% full. Deleting either is James's call (O8).
- **Rebuilding an engine** from a moved tree, and proving a Wine build at a path with a space.
- **A remote for the three source repos.** The snapshots of 3.4 are the backup.

## 8. Decisions (James)

| # | Question | Recommendation |
|---|---|---|
| O1 | The data root | `~/Library/Application Support/1launcher/<game>/`, the standard he asked for and where the unification plan already puts Surviving Mars. Its costs are a space in the path (quoted, tested, and kept away from builds) and a folder Finder hides |
| O2 | Who gets the new default | Everyone who installs from now on; an existing install stays where it is until its owner moves it (3.3). The alternative, James's Macs only, leaves 37 scripts defaulting to a folder that no longer exists here |
| O3 | Where the four source-and-build trees go | `~/Library/Caches/1launcher/cities-skylines-2/`, after the snapshots of 3.4: the standard place for what can be made again, no space in the path, and nothing private inside a public repo's working tree. Alternatives: **(b)** a folder beside the checkout in `~/github/`: survives any cleanup tool, costs a second folder there. **(c)** an ignored `build/` inside the game folder: no new place at all, but 12.9 G whose logs hold home paths would sit behind one `.gitignore` line in a public repo, the folder rename of unification 2.2 would break the trees a second time, and a clone under `~/Documents` would put a Wine tree where iCloud can sync it |
| O4 | Surviving Mars's `engine/` (unification O9 sends it to the data root) | The build root: `tools/make-engine.sh` rebuilds it in seconds from the wrapper and CrossOver, and it is a Wine tree, which this plan keeps off paths with a space. `backup/` and `runs/` stay as O9 says |
| O5 | When | L1 and L2 after the unification plan's Phase 3; L3 in the MacBook visit of its Phase 4 |
| O6 | Dated records | Keep the paths they were written with and add the one mapping sentence (3.5). Rewriting 27 lines of `EXPERIMENTS.md` and 16 of `GOTCHAS.md` would alter records to save a reader one substitution |
| O7 | `shellcheck` as a build-time check (`brew install shellcheck`; not installed today) | Yes. The alternative is reading every touched line by hand, and the space is this plan's main risk |
| O8 | The 91 G rollback copy and the 103 G test wrapper | Leave both to a separate decision |
| O9 | Tracking | Three checkboxes on issue #22, not a new issue |

## Review log

Not yet checked.

Key paths: `scripts/setup.sh` · `scripts/make-shortcut.sh` · `launchers/` · `patches/` (the five PDX patchers) · `repatch.sh` · `scripts/check-experiments.py` · `scripts/regen-winemac-patches.sh` · `scripts/test-update-check.sh` · `scripts/test-p4-signals.sh` · `scripts/boot-verify.sh` · `common/` · `INSTALL.md` · both `CLAUDE.md` · `docs/plans/1launcher-unification.md`.
