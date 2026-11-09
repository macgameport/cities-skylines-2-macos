# Local files — out of the home folder, into the places macOS sets aside

> **Status: Triple-checked 2026-11-09 — build-ready-with-fixes (pass 1, 4 lenses, 7 blockers, the design
> reworked in the fold; fitted re-check the same day, no blocker, its fixes folded).** Only L0 can start now: L1 to L3 follow
> Phase 3 of the unification plan, which moves the files cited here, so they need a fitted re-check against
> the tree as it stands then. Section 8: O3, O4, O5 and O7 are decided and O7 is done; O2, O6, O8 and O9 are open.
> Written 2026-11-09. Tracking: issue #22 (the umbrella for the unification plan), four checkboxes (O9).
> File and line references are as of `adc5900`. A path is relative to `cities-skylines-2/` unless it starts
> with `common/`, `~` or `docs/plans/1launcher`, or is this file. Surviving Mars references are to its public
> commit `14df074`. "The unification plan" is `docs/plans/1launcher-unification.md`; its phases are
> "Phase 1" to "Phase 5" and its tests T1 to T15; this plan's are L0 to L3 and LT1 to LT16.

## 0. Decisions already made (James, 2026-11-09)

| # | Decision | His words |
|---|---|---|
| D1 | Game files should not sit in the home folder, and should be unified like the launcher | "Is there a more appropriate directory for game files than home? Since the launcher is unified should the game files be too?" |
| D2 | Follow the operating system's own standard | "Is there an osx standard for applications that should be followed?" |
| D3 | Plan it, then check it | "Plan it and check it" |

This replaces the unification plan's O7 ("out of scope"). Everything in section 8 is a recommendation.

## 1. Where things are today (measured 2026-11-09 on the Studio, macOS 27.2)

**`~/cs2-patch` is two different things in one folder** (153 G, 114 entries: 71 files, 43 folders):

| | What | Size |
|---|---|---|
| **What the game runs** | the 22 deployed files (2 launchers, `repatch.sh`, 2 helpers, 17 patches in `patches/`) and `revenv/`, the Python virtual environment the badge patch and five patchers need. Seven names at the top level, plus one launcher backup `setup.sh` left beside them. The deployed scripts write nothing here, and read nothing from the rest of the folder: the launch lock is in the wrapper (`launchers/launch-cs2-dxmt11.sh:155`) | 17 M plus the scripts |
| **A developer's workspace** | everything else, 106 names: `evidence/` (304 cells; captures carry the Steam display name, which is why it is outside the repo), run folders (`boot-verify/`, `perf-runs/` and more), `change-ledger.txt`, 71 loose logs, scripts and notes, a 91 G rollback copy of an older game build, and four source-and-build trees (12.9 G: `build-1116` 5.0, `build-1116-unify` 7.2, `dxmt-fork` 0.4, `dxmt-v080` 0.3) | the rest |

Elsewhere: `~/sm-patch` (1.6 G: the checkout plus `engine/` 0.93, `backup/` 0.57, `runs/` 0.06) leaves the home folder in Phase 3. The wrappers and double-click apps are in `~/Applications` and the two launcher logs in `~/Library/Logs`, both the standard places. No `1launcher` folder exists anywhere under `~/Library`.

**What names `~/cs2-patch`:**

| Item | Measured |
|---|---|
| Tracked files | 72 files, 291 lines: 41 under `scripts/`, `launchers/`, `patches/` and `repatch.sh` (102 lines), 31 documents (189 lines). This file and one line in the root `CLAUDE.md` have since made it 73 and 312 |
| Deployed files that hold the path as code | `launchers/launch-cs2-dxmt11.sh:71` (`PATCH_DIR`; it appears on 8 lines at `:88-193`, quoted every time); `launchers/launch-cs2.sh:102-103` (the same default inline, twice); the five PDX patchers' shared head (`_REVENV` and its error text, e.g. `patches/patch_createfile.py:37,44`; from its marker line to `def die` the five have one checksum). `repatch.sh:8` finds `patches/` from its own location |
| Overrides that exist | `CS2_PATCH_DIR` (`scripts/setup.sh:23`, both launchers), and single-purpose ones: `CS2_BUILD_DIR` (one tree; `build-winemac-visibility.sh:23`), `CS2_LAUNCHER`, `CS2_DRIVER`, `CS2_PERF_DIR`, `WINEMAC_SRC`, `WINEMAC_BUILD`, `DXMT_FORK_DIR`, `DXMT_WINE_INSTALL`, `CS2_VANILLA_DIR`. 37 of the 41 files carry neither of the first two |
| The CS2 app | its shim holds the launcher's absolute path (`scripts/make-shortcut.sh:78`, called from `scripts/setup.sh:124`) |
| Two `.command` wrappers in `launchers/` | `exec bash "$HOME/cs2-patch/launch-…sh"` |
| Every caller of a launcher | starts the deployed copy by absolute path: `scripts/boot-verify.sh:94`, `scripts/perf-run.sh:23`, `scripts/diag-launch-dxmt11.sh:28`, the two wrappers. The tests only read marked regions of the repo copy |
| Gates that read the folder | `scripts/check-experiments.py:37` (the evidence store: with the folder missing it exits 1 with 304 drift items). **Three weaken without a word if their path is wrong:** `scripts/regen-winemac-patches.sh:22` exits 64 without its nested repo, and `scripts/check-experiments.py:312-313` turns that 64 into a note and still exits 0; `scripts/test-update-check.sh:165` reads the rollback copy's manifest only if it is there (25 passed with it, 24 without); `scripts/test-p4-signals.sh:76` reads real perf logs only if they are there (`pass live: 41 real logs`, else `skip live`) |
| Outside the repo | the scheduled task `reddit-watch-cs2` (10 lines of its `SKILL.md`, which also calls the folder its working notes); 15 Claude memory files (49 lines; 13 in the repo's project, 2 in the folder's own); two Claude project entries keyed to the folder; 26 loose text files in the folder that name it (6 deployed copies, 16 logs, 4 others) |
| Not keyed to it | launch agents, cron, shell profiles, the git identity includes, every wrapper (0 symlinks into it, 0 config lines naming it), every sibling repo |
| Working directories | 9 processes had theirs inside the folder when this was measured, the planning session among them |
| The MacBook | not visible from the Studio; the unification plan's section 6 already asks whether the folder exists there |

**Two defects that exist today.** (1) `setup.sh --dest <dir>` (or `CS2_PATCH_DIR`) deploys elsewhere and builds the app to start the launcher there, but the shim starts it without that variable (`scripts/make-shortcut.sh:106`), so the deployed launcher still looks for `repatch.sh`, the display profile and the badge patch in `~/cs2-patch`. (2) `scripts/setup.sh:36-37,105` copies one launcher per run, the one for `--stack`; the other deployed launcher is only as new as the last run for its stack.

**The workspace holds work that exists nowhere else, and cannot be treated as rebuildable:**

| Tree | What is in it |
|---|---|
| `build-1116/wine-11.16-dxmt/dlls/winemac.drv` | a git repo with no remote: 12 branches, 6 tags, 44 commits on its branches, 65 more that no branch or tag reaches, and local `diff.*` and `user.*` settings. The source of the three published winemac patches, and what the drift gate reads. Mirrored since 2026-11-09 (O7) |
| `dxmt-v080` | 2 commits on a local branch that no remote had. Mirrored since 2026-11-09 (O7) |
| `dxmt-fork` | a shallow clone of another person's fork with 3 modified files |
| `build-1116/wine-11.16-stockcore` | a git repo with no commit, around a copy of the vendor tree plus 4 entries |
| `build-1116-unify` | no repo at all: two Wine source files that differ from the vendor tree, `ntdll-variants/` (two built DLLs and a patch), `probe-logs/`, build logs |
| all four | built engines that other scripts take as input (`build-dxmt-fork.sh:26`, `make-vanilla-wrapper.sh:29`, `steam-vanilla-d3d-split.sh:40`); every `build.ninja` and `config.status` opened holds the tree's absolute path (10 to 22 lines each), so a moved tree must be configured again before it builds |

The Studio has no Time Machine destination. A cleanup tool that empties caches (OnyX) is installed, and Time Machine excludes `~/Library/Caches`.

**Probes** (scratch copies, removed afterwards):

| # | Probe | Result |
|---|---|---|
| P1 | A throwaway app, started the way a double-click starts one, whose shim runs a script in a folder under `~/Library/Application Support/` | exit 0, no permission prompt. The script found its own folder, ran a helper beside it, ran the system Python on a file in `patches/`, ran an APFS clone of `revenv` (`dnfile`, `capstone`, `pefile` import; `sys.prefix` is the new place) and wrote a file there. The clone's console scripts (`bin/pip`, the activation scripts) still hold the old folder's path |
| P2 | Can the nested repos be backed up and restored as bundles? | Not as a general recipe. The winemac repo's bundle restores its 12 branch tips, but the drift gate fails against the restore until the two `diff.*` settings are copied; a bundle of the shallow clone cannot be cloned; a repo with no commit cannot be bundled at all. A rename loses none of this, which is why section 2 moves the trees and copies nothing |
| P3 | Does a Wine build work at a path with a space? | Not tested. `configure` has no check that refuses one (read). Section 2 keeps the workspace off any such path, so nothing depends on the answer |
| P4 | The check's scratch build of the first draft's L1 (42 files: 2 added, 40 changed) | every gate that needs no live system exited 0 with the numbers of LT6, once the trees had the same old-install rule as the deployed files |

## 2. Target

Apple's file-system guidance gives each kind of file a place under `~/Library` and tells apps to keep the files they create themselves there, by convention in a subfolder named for the app's bundle identifier. This project is several apps, so it uses its own name, as Porting Kit does on this Mac.

| Kind | Place | Used for |
|---|---|---|
| The apps | `~/Applications` | wrappers and double-click apps (unchanged) |
| Files an app keeps for itself | `~/Library/Application Support/<name>/` | **the runtime folder**: what a game runs, and a game's own state |
| Logs | `~/Library/Logs/` | the two launcher logs (unchanged) |
| Things an app can make again | `~/Library/Caches/<name>/` | nothing of ours: section 1 shows the workspace is not that |
| "Data used by Xcode and other developer tools" (Apple's table, the `Developer` row) | `~/Library/Developer/` | **the workspace** (O3) |

```
~/Library/Application Support/1launcher/      the data root
├── cities-skylines-2/                         the runtime folder: the 22 deployed files and revenv/
└── surviving-mars-relaunched/                 backup/ and runs/ (unification O9)
~/Library/Developer/1launcher/                 the work root: durable, and no space in its path
├── cities-skylines-2/                         the workspace: everything else in today's ~/cs2-patch, names unchanged
└── surviving-mars-relaunched/                 engine/ (O4)
```

**Two rules map every old path.** The seven runtime names (`launch-cs2-dxmt11.sh`, `launch-cs2.sh`, `repatch.sh`, `cs2-display-profile.sh`, `patch-modconflict-badge.py`, `patches/`, `revenv/`), and any launcher backup beside them (`launch-cs2*.sh.bak`), become `<data root>/cities-skylines-2/<name>`. Every other `~/cs2-patch/X` becomes `<work root>/cities-skylines-2/X`. Nothing is renamed or regrouped, and the four trees stay beside each other. On the Studio the home folder ends with neither `~/cs2-patch` nor, after Phase 3, `~/sm-patch`.

Why two places. The runtime folder is what the standard's Application Support is for, and P1 shows an app can run scripts there. The workspace is not an app's support files: it is 153 G of evidence, experiment output and live source, written by the harness scripts under `scripts/`, which were never made safe for a path with a space (an upper bound of 50 unquoted lines in 18 files), and it includes Wine trees. It needs a durable folder with no space in its path; O3 says where.

Unchanged: the wrappers, one wrapper per game, both engines, the two log paths, CS2's deploy model (copies outside the repo, because an app may not run scripts from a clone under `~/Documents`: `scripts/setup.sh:14-15`), and Surviving Mars running from its checkout.

## 3. Design

**3.1 The folders are named once.** A new file, `common/paths.sh`, sets `L1_DATA_ROOT` and `L1_WORK_ROOT`, `CS2_DATA` (override: the existing `CS2_PATCH_DIR`) and `CS2_WORK` (override: `CS2_WORK_DIR`), by the rule in 3.3. From L1 step 1.6 on it also sets `SM_STATE` (`<data root>/surviving-mars-relaunched`) and `SM_WORK` (`<work root>/surviving-mars-relaunched`), each overridable by its own name and outside the old-install rule. Sourced, it sets them, under `set -eu` too. Run (`bash common/paths.sh`), it prints them as `KEY=value` lines, which is how a person, an agent or a Python script learns where things are; `scripts/check-experiments.py:37` reads the evidence store's place that way and stops if the call fails. Repo-side shell scripts source it by their own location (`"$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)/common/paths.sh"`) and take every default from `"$CS2_DATA"` or `"$CS2_WORK"`; each single-purpose override keeps its name and meaning, and only its default changes (`CS2_BUILD_DIR` stays one tree, default `$CS2_WORK/build-1116`). It exports nothing, so a child script sources it again; it warns on stderr if `CS2_WORK` contains a space. The only tracked code that spells either root is this file, its test, and the two `.command` wrappers (3.3). The roots are named after the repo, and the repo's name is a label: with the name written in four files and the app shim generated, renaming it is those edits, two `mv` and one `setup.sh` run (LT14).

**3.2 Deployed files find themselves.** They cannot source a repo file and do not need to: they are in the runtime folder.

| File | Change |
|---|---|
| `launchers/launch-cs2-dxmt11.sh:71` | `PATCH_DIR="${CS2_PATCH_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}"`; header lines `:9-10`, `:14` reworded without changing the line count, so the launcher lines this plan cites stay put |
| `launchers/launch-cs2.sh:102-103` | one `PATCH_DIR` line of the same form, used twice; comments at `:5` (the engine path; O4), `:12`, `:100` |
| the five PDX patchers' shared head | `_REVENV` is the first that exists of `revenv/bin/python3` beside the script's own `patches/` folder and, when `CS2_PATCH_DIR` is set, `$CS2_PATCH_DIR/revenv/bin/python3`; the error text names both. Edited identically in all five (LT5). Also the usage line `patches/patch_mkparent.py:30` |
| `repatch.sh:6`, `scripts/cs2-display-profile.sh:4`, `scripts/patch-modconflict-badge.py:41` | comments only |

This removes defect (1) of section 1. Two behaviours change, both for copies run straight from the checkout, which no caller in the repo does: a launcher started from `launchers/` prints its two "NOTE: no … in" lines (`:91`, `:188`), skips the badge step without a line (`:192-196`) and skips the patch check, where today it finds `~/cs2-patch`; and `bash repatch.sh` from the checkout stops at the first PDX patcher with "needs dnfile" unless `CS2_PATCH_DIR` is set, where today the patcher re-starts itself under `~/cs2-patch/revenv`. A launcher reached through a symlink looks beside the link. The documents say to run the deployed copies.

**3.3 An install made before this keeps working where it is, as one folder.** If `<data root>/cities-skylines-2` does not exist, and `~/cs2-patch` is a real folder (not a symlink), and neither root has been set to something other than its default, then `CS2_DATA` and `CS2_WORK` are both `~/cs2-patch`. Otherwise they are the two new folders. One observable decides both, so an old install is never half-moved by a default; and because a root counts as set only when it differs from its default, sourcing the file twice, or inheriting its values, changes nothing. `scripts/setup.sh` takes its folder from `common/paths.sh`, prints `data:` and `work:` lines under its `repo:` line (so `--check` shows them), copies **both** launchers (the app still starts the `--stack` one), which removes defect (2), and warns when `~/cs2-patch` exists beside the new runtime folder. That state means a clone at an older commit ran `setup.sh` and recreated the old folder; the warning says to remove it once it is seen to hold nothing but freshly deployed copies, and `scripts/check-experiments.py` reports the state as a problem until then. The two `.command` wrappers carry the rule inline, because people copy them out of the repo (LT2).

**3.4 The move is a script, not typed commands.** `scripts/move-install.sh` does for anyone what L2 does on the Studio. It refuses, moving nothing, if `pgrep -x wineserver` finds a process or a wrapper's launch lock (`<wrapper>/Contents/SharedSupport/prefix/.launcher.lock`) names a live one; if `lsof -a -d cwd` shows any of the user's processes with its working directory inside `~/cs2-patch` (the system does not refuse such a rename: the process is carried along under a path that no longer exists); if either target exists; if the old folder is a symlink; or if the old folder and the nearest existing parent of each target are not on one volume. Then, if the old folder holds anything besides the runtime names, `.DS_Store` aside, it renames the whole folder to the workspace first and lifts the runtime names out of it into the runtime folder; if it holds nothing else, it moves them and removes the old folder, and makes no workspace. In that order the rule of 3.3 never names a folder that is not there. A run that stops part-way prints the command that finishes it, and a second run finishes it: an absent old folder and a workspace that still holds runtime names is a state it recognises. It takes its targets from `$L1_DATA_ROOT` and `$L1_WORK_ROOT`, never from `CS2_DATA`, which names the old folder until it has run. It changes nothing else; its last line says to run `setup.sh`. `--dry-run` prints the refusals and the moves. Its test replaces the two process probes through one documented variable and takes the folders it expects from `bash common/paths.sh`, so it spells neither root. Nobody's folder is moved for them: `INSTALL.md` gains a short paragraph naming this script. 128 people cloned this repo in the 14 days to 2026-11-08.

**3.5 Nothing is copied, snapshotted or rebuilt.** Every move is a rename on one volume, so each repo keeps its reflog, settings, shallow boundary and uncommitted files, and LT7 checks that. `CLAUDE.md` § Where things live records what the move does cost: each tree must be configured again before its next build, a rebuilt module is not byte-identical to the installed one because the build path is compiled in, and `revenv`'s console scripts and activation scripts hold the old path, so `revenv/bin/python3 -m pip` is the way to add a package. That the four trees are the only copy of their work is as true after the move as before it (section 7).

**3.6 Documents.** Comments, usage text and living documents name a place by its role ("the runtime folder", "the workspace", `<workspace>/evidence/…`) and give `bash common/paths.sh` as the way to print both, so they are true before and after a Mac's folders move. Living documents: both `CLAUDE.md` files, `INSTALL.md` (`:74`, `:200`, `:213`, `:222`, `:293`; the three commands a reader types against the runtime folder show the path quoted, and the uninstall line names both the old folder and the two new ones), `scripts/README.md`, `patches/README.md` (`:9,11` tell a reader to run `repatch.sh` from the checkout, `:41` says where `revenv` is made), `docs/agent-brief.md`, `docs/patch-inventory.md`, `docs/images/AUDIT.md`, `MODS-TESTING.md:194` and `PLAN.md`. Dated records keep the path they were written with: `EXPERIMENTS.md`, `GOTCHAS.md`, the 13 game plans under `docs/plans/`, `docs/dxmt-bugs/`, `docs/wine-bugs/`, `docs/perf-pass-results.md`, `docs/steam-ui-investigation.md`, `docs/test-matrix.md` (generated), the rest of `MODS-TESTING.md`, and the two root plans. The two mapping rules of section 2 go in one sentence at the top of `EXPERIMENTS.md` and of `GOTCHAS.md` and into `CLAUDE.md` § Where things live. Both `CLAUDE.md` files and the agent brief also say: never search or grant access above a `1launcher` folder, because `~/Library/Application Support` holds other apps' private data. The root `CLAUDE.md` names the old folder on five lines (`:16`, `:19`, `:23`, `:51`, `:65`): in L1 four are reworded by role, and its list of places allowed outside the repo (`:19`) names both roots for both games beside the old folder (the work root is on that list since Phase 3, for Surviving Mars's `engine/`); L2 drops the old folder from that line, when that becomes true on the Studio.

## 4. Phases

Each phase ends green before the next starts. L1 and L2 start after Phase 3 of the unification plan is green on the Studio (O5): Surviving Mars is the small pilot for the data root, and the two plans then never edit the same files at the same time.

### L0 — decisions, and what they change in the unification plan (no code)

1. James answers section 8. Done on 2026-11-09 for O3, O4, O5 and O7.
2. Done with this plan: the unification plan's O7 row, its section 2 "Unchanged" sentence and its T2 row point here.
3. O4 is accepted, so before Phase 3 is built: in the unification plan, `engine/` goes to `<work root>/surviving-mars-relaunched/`, through a second variable `SM_WORK`, in the O9 row, in section 2's sentence, in 3.2 (the default output at `tools/make-engine.sh:48`), in 3.5 (the move) and in T14 (which then expects `runs/` and `backup/` under the data root and `engine/` under the work root). Done 2026-11-09. That edit is new material in a checked plan: it is audited two-sided and re-checked by one fitted pass before Phase 3 starts.
4. Three places where the two plans meet, and how the order settles each. The unification plan's Phase 3 exit expects one remaining `sm-patch` line at `launchers/launch-cs2.sh:5` and its 3.6 leaves the CS2 launcher comments alone: both are judged before L1, which then edits that comment. Its T2 compares against `~/cs2-patch`: from L1 on it is read as LT4, against the folder `common/paths.sh` resolves. Its Phase 4 exit on the MacBook is recorded before L3 starts in the same visit.

### L1 — the repo (public; one commit for code and tests, one for documents)

1.1 `common/paths.sh` and `common/test-paths.sh` (LT1, LT14).
1.2 The deployed files, per 3.2. Never edited in place in the runtime folder: the repo copy is edited and `setup.sh` copies it.
1.3 Every other script that names the old folder (23 shell scripts here and two more in 1.4, `scripts/check-experiments.py`, and comments in `scripts/dump-binding-attrs.py:21` and `scripts/win-resize-driver.c:9`): source `common/paths.sh` and take each default from `"$CS2_DATA"` (a launcher path, and the display-profile helper at `scripts/t1-spike.sh:99`) or `"$CS2_WORK"` (everything else), per the two rules of section 2 (LT15). The harness scripts' own unquoted uses are left as they are: the workspace has no space in its path.
1.4 `scripts/setup.sh` per 3.3; `scripts/make-shortcut.sh:46,48` take their default launcher from `common/paths.sh`; the two `.command` wrappers (LT2); `common/check-deploy.sh`, the 22-file comparison as a script (LT4).
1.5 `scripts/move-install.sh` and `scripts/test-move-install.sh` (LT16).
1.6 Surviving Mars's five scripts take `SM_STATE` (four of them; `patch-window-origin.py` by running `bash common/paths.sh`) or `SM_WORK` (`tools/make-engine.sh`) from `common/paths.sh`, in place of the line Phase 3 gave each (unification 3.2); T14 is run again.
1.7 Documents, per 3.6.
1.8 On the Studio, the old folder still in place and nothing running (the two probes of 3.4: `pgrep -x wineserver` finds nothing, no launch lock names a live process): `bash scripts/setup.sh` from the game folder. It resolves to `~/cs2-patch` by the rule of 3.3, copies the new files, runs the idempotent patch pass and rebuilds the app. Then LT10. This is the path every existing user takes after `git pull`.

**Exit criteria.** Working tree clean. LT1, LT2, LT3, LT5, LT14, LT15 and LT16 pass. LT4 reads 22 of 22 at `~/cs2-patch`. LT6 reads its pinned numbers. LT9 names `~/cs2-patch/launch-cs2-dxmt11.sh`. LT10 passes. LT12 prints only its allowed list. LT13 passes.

**Rollback.** On the Studio: revert both commits and run `setup.sh` again; the folder has not moved, so the old launcher finds it. For everyone else the phase rolls forward: someone who installed fresh between the push and a revert has a runtime folder that the reverted code does not look in.

### L2 — the Studio's folders

1. Preflight. The scheduled task disabled in the scheduler. `lsof -a -d cwd | grep -c "$HOME/cs2-patch"` prints 0: this phase is run from a session in the checkout, and every session and shell in the old folder is closed first. O7's mirrors are level with their sources (`git log --branches --not --remotes` prints nothing in either repo). Record LT6's numbers, LT7's listing and fingerprints, and `bash scripts/move-install.sh --dry-run`.
2. `bash scripts/move-install.sh`, which repeats the refusals of 3.4. LT7. Then one line in `<work root>/README.txt`, new unless Phase 3 left one: this folder is not Xcode's, and its trees are the only copy of the work in them.
3. `bash scripts/setup.sh` from the game folder: it now resolves to the runtime folder, copies the 22 files, runs the patch pass and rebuilds the app with the new launcher path. LT4, LT8, LT9.
4. What names the old path outside the repo. The scheduled task's `SKILL.md`: its 10 lines by the two rules, and the sentence that calls the folder its working notes; then enable it. The 13 memory files in the repo's Claude project (`grep -rl cs2-patch` over its `memory/` folder); the 2 in the old folder's own project are dropped with a line in the repo's index, since no session starts there again. The 4 loose scripts and notes in the workspace that name the old path, by hand, or left with a note where dead (`queue-s2b.sh` already is); the 16 logs are records. The old folder's own `.claude/` moves with the workspace and is inert. The old folder's `.metadata_never_index` marker moves with the workspace too. Last, a document commit: the root `CLAUDE.md`'s list of allowed places.
5. LT6 again, then LT10, LT11, LT12, LT13 and the second half of LT15.

**Exit criteria.** `ls -d ~/cs2-patch` finds nothing. LT7 passes. LT4 reads 22 of 22 at the runtime folder. LT6 reads the same numbers as before the move. LT8, LT9, LT10, LT11, LT12, LT13 and LT15 pass. A count of `cs2-patch` over the task's `SKILL.md` and the repo project's `memory/` folder reads 0, or each remaining line is a dated record. `git status --porcelain` is empty.

**Rollback.** Quit everything, and check that `~/cs2-patch` does not exist. Rename the workspace back to `~/cs2-patch`, move the runtime names and any launcher backup back into it and remove the emptied runtime folder, so the rule of 3.3 picks the old folder again. Run `setup.sh`. Undo step 4 by hand.

### L3 — the MacBook

In the same visit as the unification plan's Phase 4, after that phase's exit is recorded; or a visit of its own. Its inventory first: does `~/cs2-patch` exist there, what is in it, is any tree in it a repo with work its remote lacks, what is running. Then L2 steps 1 to 5 for what it has. LT6's numbers are the ones recorded there before its move, not the Studio's. No Claude auto-memory is written there (global rule).

Exit: the same criteria, measured there; both games started once from their apps. Rollback: as L2.

## 5. Who notices what

| Audience | Effect | Mitigation |
|---|---|---|
| People with an existing install | none until they choose: `git pull && bash scripts/setup.sh` keeps using `~/cs2-patch`, and now also refreshes the second launcher | 3.3, LT1, L1 step 1.8 |
| New installs | the 22 files land under `~/Library/Application Support/1launcher/`, which Finder hides | `setup.sh` prints the folder; the install guide gives `open "<path>"` |
| Anyone typing a runtime path | it contains a space | 3.6: the three such commands show it quoted |
| James, browsing evidence | the workspace is no longer one click from home | a Finder sidebar entry, his to add |
| Claude sessions | a session started in `~/cs2-patch` has no folder afterwards; memory and one scheduled task name the old path | L2 steps 1 and 4 |
| The next engine build | each tree needs its configure step again | 3.5 |

## 6. Test plan

| # | Test | Passes when | Mutant, applied and seen red |
|---|---|---|---|
| LT1 | `common/test-paths.sh`, with `HOME` at a scratch folder. States: neither folder; only the old one; only the new runtime folder; both; the data root present but its game folder absent, with the old one present; the old one a symlink. Then `CS2_PATCH_DIR` set, `CS2_WORK_DIR` set, one root set to another folder, a root set to its own default, a root set empty. It sources the file twice in one shell and again in a child that inherited the values, under `set -eu`; runs it and reads the printed lines; checks that the default `CS2_WORK` and `SM_WORK` have no space; and prints `SM_STATE` and `SM_WORK` at their defaults and overridden | new · old · new · new · old · new for both variables; each override wins for its own variable; a root set elsewhere turns the old-install rule off, a root at its default or empty does not; the second sourcing and the child print what the first did; the two Surviving Mars variables are under the data root and the work root, and each override wins | invert the old-install test in `common/paths.sh`: the old-only state is red. Treat any set root as explicit: the twice-sourced case is red (measured in the re-check's scratch) |
| LT2 | Each `.command` wrapper under three scratch homes holding a stub launcher that prints its own path; and the root each wrapper spells against the one in `common/paths.sh` | new · old · new; the two strings are equal | change the folder name in one wrapper: unequal |
| LT3 | No game, no setup run. Lay the 22 deployable files and an APFS clone of `revenv` out in a scratch folder whose path has a space, as `setup.sh:105-110` does. For the game, a scratch folder holding an empty `Cities2.exe`, a clone of `Cities2_Data/Managed` and a clone of `Cities2_Data/Plugins/x86_64/cohtml_unity3dplugin.dll` (the first patch needs it: `patches/patch_cohtml.py:142-147`). With `HOME` at a third scratch folder: `CS2_GAME_DIR=<game scratch> bash "<scratch>/repatch.sh" dxmt11`. Then the same from a folder with no space, against a fresh clone of the game scratch | exit 0 both times, and the same output with the paths normalised. By reading, nothing is written outside the game scratch (`repatch.sh:52,144-145`) | restore the old `_REVENV` line in one patcher: `ERROR: needs dnfile` |
| LT4 | `common/check-deploy.sh`: `cmp` of the 22 deployable files against `CS2_DATA` | 22 found, 22 identical. T2 also ran `setup.sh --check`; this is the comparison alone. Measured in the check's build of the first draft: 12 identical before the deploy, and 21 after a `setup.sh` that copies one launcher | `CS2_PATCH_DIR` at an empty folder: 0 found |
| LT5 | The five PDX patchers' shared head, from its marker line to `def die` | one checksum | edit one patcher only: two |
| LT6 | Pinned numbers, recorded before L1 and read again after L1 and after L2, each from its own command: `check-experiments.py` exits 0 with the same cell count (304 today); `test-update-check.sh` prints 25 passed; `test-p4-signals.sh` prints a `pass live:` line with at least 41 logs; `regen-winemac-patches.sh --check` exits 0; the lock test's count (17, or 24 once it is `common/test-launch-lock.sh`) | all five | `CS2_WORK_DIR` at an empty folder under `/tmp`: exit 1 with 304 drift items, 24 passed, `skip live`, exit 64 (measured in the check's build with the equivalent override) |
| LT7 | Nothing lost in the move. Before and after, with `GIT_OPTIONAL_LOCKS=0`: the sorted top-level names of the old folder against the workspace plus the runtime folder, `.DS_Store` ignored; and for each of the four repos, the checksum of `git for-each-ref`, of `git status --porcelain`, of `git config --local --list`, the line count of `.git/logs/HEAD` (0 where the file is absent), the stash count and the shallow flag. All of these run today on all four, the repo with no commit included | the names equal the recorded listing; every fingerprint is equal; the repo with no commit still has none and the same 26 status lines | delete one name from the saved listing: reported |
| LT8 | After the move: `"<runtime folder>/revenv/bin/python3" -c "import dnfile, capstone, pefile"`, and `… -m pip --version` | both succeed; pip names the runtime folder | none worth the name: the system `python3` cannot import `dnfile` |
| LT9 | The CS2 app's shim | its `SCRIPT=` line names the launcher in the folder LT4 used, and that file exists | point `SCRIPT=` at a missing file in a scratch copy of the app: its own guard shows the alert path (`make-shortcut.sh:82-85`) |
| LT10 | Live, James warned first and the MacBook's Steam closed: `scripts/boot-verify.sh`, detached with a log, its launcher the shim's `SCRIPT` | `VERDICT: PASS` and `GRACEFUL: yes`; and `<run dir>/launcher.log`, the file `boot-verify` writes (`boot-verify.sh:238`), has `Patches ensured (10, dxmt11 target).` (`launch-cs2-dxmt11.sh:183`), a `Badge patch:` line (`:194`) and a `Display profile:` line, and none of the launcher's lines at `:89`, `:185`, `:195` or a line starting `NOTE: no`. The `WARNING: game update waiting` line (`:312`) is not a failure: a waiting update prints it on a healthy run | none: a live run. Run twice: end of L1 from the old folder, end of L2 from the runtime folder |
| LT11 | Live, after L2, James warned: one start through the app itself (`open` on it, or his double-click), closed by him from the game's menu | after a fresh `=====` stamp, `~/Library/Logs/cs2-launcher.log` has the three lines of LT10 and none of the lines LT10 forbids | none: a live run. It is the only test that starts the real shim through LaunchServices |
| LT12 | `git grep -c 'cs2-patch' -- . ':!docs/plans/local-files-layout.md' ':!docs/plans/1launcher-unification.md'` | exactly: the old-install rule (`common/paths.sh`, `common/test-paths.sh`, `scripts/move-install.sh` and its test, the two `.command` wrappers, `scripts/setup.sh`, `scripts/check-experiments.py`); the `INSTALL.md` paragraph and uninstall line; one line in the root `CLAUDE.md` until L2 and one mapping sentence in the game's; and the 23 record files with 153 lines (`EXPERIMENTS.md` 28 and `GOTCHAS.md` 17, each with its mapping sentence; 13 game plans 84; `docs/dxmt-bugs/` 5; `docs/wine-bugs/` 6; `docs/perf-pass-results.md` 6; `docs/steam-ui-investigation.md` 2; `docs/test-matrix.md` 2; `MODS-TESTING.md` 3). Every other file reads 0 | add one mention to a living document: one more file |
| LT13 | The unification plan's T1 (links), T6 (identifiers, `ACCEPT=9`) and T13 (ignore rules) | as there | theirs |
| LT14 | Rename on a whim: with `L1_DATA_ROOT` and `L1_WORK_ROOT` set to scratch folders, LT1's resolver and `setup.sh --check` (run with the real `HOME`); and `git grep -l -e 'Application Support/1launcher' -e 'Developer/1launcher' -- '*.sh' '*.py' '*.command' '*.c'` | both print the scratch folders; four files: `common/paths.sh`, its test, the two wrappers | write a root into one more script: five files |
| LT15 | The two roots are not swapped. For every match of `\$\{?CS2_(DATA\|WORK)\}?/[A-Za-z0-9_.-]+` in tracked `.sh`, `.command` and `.py` files: the name after the slash is a runtime name exactly when the variable is `CS2_DATA`. Second half, after L2: every such name that existed in the old folder exists in the matching new one. Paths a Python script builds by joining are outside its reach; LT6's cell count covers the evidence store | no mismatch (today's 29 names: 5 runtime, 24 workspace, none ambiguous) | point one script's `evidence` at `$CS2_DATA`: reported |
| LT16 | `scripts/test-move-install.sh`, with `HOME` at a scratch folder holding a fake old folder: a full one with a nested git repo, a dotfile and a name with a space; the same with the work root already present and holding another game's folder, as on the Studio after Phase 3; one with only the runtime names, a launcher backup and a `.DS_Store`; each target already present; a process whose working directory is inside it; a stubbed `wineserver`; a live launch lock; a symlinked old folder; a run stopped after the rename and then run again; `--dry-run` | moved as section 2 maps it, the nested repo's fingerprints equal, in both · runtime moved, the old folder removed, no workspace made · refused, nothing moved, in each of the next five · finished by the second run · nothing moved, the refusals and moves printed | remove the target-exists refusal: the folder is nested inside the existing workspace and the case is red (measured in the re-check's scratch) |

## 7. Not in this plan

- **Moving the wrappers.** `~/Applications` is the standard place; about 40 tracked files here and about 10 in Surviving Mars name a wrapper path.
- **Regrouping what is inside the workspace**, the log paths, and making the harness scripts safe for a space.
- **A second disk.** O7's mirrors cover the two repos that have commits of their own, and sit on the same disk as the originals. Still in one copy only: `dxmt-fork`'s 3 modified files, the two changed Wine source files and `ntdll-variants/` in `build-1116-unify`, and the 4 extra entries in the repo with no commit.
- **Disk space.** The 91 G rollback copy moves with the workspace; the 103 G test wrapper `CS2child-test.app` stays in `~/Applications`. The Studio's disk is 90% full (O8).
- **Rebuilding an engine** from a moved tree, and proving a Wine build at a path with a space.
- **A launcher warning when `CS2_PATCH_DIR` points away from its own folder.** The variable is honoured today and still is.

## 8. Decisions (James)

**Decided 2026-11-09.** His answers to the four questions put to him: O3, "library" and then "Follow best practices"; O7, "ok"; O4, "that's fine"; O5, "ok". O1 is the standard that D2 asks for and is read as decided with O3; that reading is the planner's. O2, O6, O8 and O9 are still recommendations.

| # | Question | Recommendation |
|---|---|---|
| O1 | Where the runtime folder goes | `~/Library/Application Support/1launcher/<game>/`: the standard he asked for, and where the unification plan already puts Surviving Mars's state. Its cost is a space in the path, which the deployed files already handle (P1, LT3) |
| O2 | Who gets the new default | Everyone who installs from now on. An existing install stays where it is, whole, until its owner runs the move script (3.3, 3.4) |
| O3 | Where the workspace goes | `~/Library/Developer/1launcher/<game>/`. Apple's table of `Library` folders has a `Developer` row: "Contains data used by Xcode and other developer tools." It is durable, has no space, is the same on every Mac, is included by Time Machine, and keeps everything of this project that is not in the repo under `~/Library`. Its risk is habit: people empty parts of that folder to win back Xcode's space, and the Studio's disk is 90% full, so the work root carries a note saying what it is and O7 comes first. Alternatives: **(b)** `~/github/1launcher-work/`, beside his other repos and one click away. It would need an untracked settings file read by `common/paths.sh` on each of his Macs, because other people's Macs have no such folder, and anything that walks `~/github` would then walk 153 G. **(c)** `~/Library/Caches/1launcher/`, the standard place for what an app can make again: rejected by measurement, because the trees hold work that exists nowhere else, a cleanup tool that empties caches is installed, and Time Machine excludes it. **(d)** One folder under Application Support for everything: every harness script would have to be made safe for a space, and Wine builds are unproven there |
| O4 | Surviving Mars's `engine/` (unification O9 sends it to the data root) | The work root: it is a Wine tree, and this plan keeps those off paths with a space. `backup/` and `runs/` stay as the unification plan's O9 says |
| O5 | When | L1 and L2 after the unification plan's Phase 3; L3 in the MacBook visit of its Phase 4 |
| O6 | Dated records | Keep the paths they were written with and add the mapping sentence (3.6): 151 lines in 23 files stay as written |
| O7 | The four trees are the only copy of their work | Open an issue for a backup or a private remote, and do it before L2 for the two repos with commits no remote has (the winemac repo's whole history is under 300 KB). The move itself neither helps nor hurts; the new folder's risk is the one O3 names. **Done 2026-11-09**, on the Studio's private git server as remote `hub`: `~/git/cs2-winemac-drv.git` (18 refs) and `~/git/cs2-dxmt-v080.git` (22 refs), each equal to its source ref for ref, and a clone of the first passes the drift gate once the two `diff.*` settings are set. No issue was opened: the root `CLAUDE.md` records the mirrors and the push that keeps them level |
| O8 | The 91 G rollback copy and the 103 G test wrapper | Leave both to a separate decision |
| O9 | Tracking | Four checkboxes on issue #22, one per phase, not a new issue |

## Review corrections (triple-check 2026-11-09)

Pass 1, four lenses, each `build-ready-with-fixes`. Every blocker was re-read against the files before it was accepted. Seven survived; three of them (B1, B3, B5) had one cause, a folder treated as one thing when it is two, so the fold reworked the design: the first draft had a data root and a build root in `~/Library/Caches`, with a snapshot step and a lint tool to make that safe.

| # | Finding | Lenses | Folded into |
|---|---|---|---|
| B1 | The build trees had no old-install rule: after L1 the drift gate exits 64, and `check-experiments.py` turns that into a note | architecture, correctness, builder (measured) | 3.3 (one rule decides both folders), LT1, LT6, section 1 (three silent gates) |
| B2 | `setup.sh` copies one launcher per run, so "22 of 22" could not be reached after both launchers are edited | architecture, correctness, builder (measured: 21) | section 1 defect (2), 3.3, 1.4, LT4 |
| B3 | The snapshot recipe could not run: one repo has no commit, one is a shallow clone, a fourth repo with local commits was missed, and two changed source files sit in no repo. "A cleanup loses nothing" was false | architecture, security, builder | section 1 table, P2, section 2 (workspace), 3.5, LT7, O3, O7 |
| B4 | The spaced-folder patch test could not exit 0: the first patch needs a file outside the folder it cloned | correctness, builder | LT3 |
| B5 | The quoting check looked only at lines naming six variables; the harness scripts pass the path through local names, and a lint tool installed by Homebrew could move the engine toolchain | correctness, security, builder | section 2 (the workspace has no space), 1.3; the tool is dropped |
| B6 | The live test could pass with the patch check broken: the badge step prints nothing when it skips, a failed patch pass is one WARNING line, and "the launcher log" named the wrong file | architecture, security, correctness | LT10, LT11 |
| B7 | The rename test expected one file to spell the root where 3.3 itself makes it four, and a scratch root fell back to the real old folder | correctness, builder (measured) | 3.1, 3.3, LT14 |
| S1 | "The new folder" was undefined once Surviving Mars creates the data root; explicit roots and the fallback were unspecified | architecture, security, builder | 3.3, LT1 |
| S2 | A hand-typed `mv` nests silently if the target exists; nine processes had their working directory in the folder; no command was given | all four | 3.4, L2 steps 1 and 2, LT16 |
| S3 | A second behaviour change was unlisted: `repatch.sh` from the checkout loses its Python | architecture, correctness, builder | 3.2 |
| S4 | The two plans met in three places the first draft did not name | architecture, correctness | L0 step 4; the unification plan's section 2 and T2 row |
| S5 | Living documents changed in L1 while the Studio's folders moved in L2 | architecture | 3.6 (places named by role; `bash common/paths.sh`) |
| S6 | `revenv` keeps the old path in its console and activation scripts | architecture, security, correctness | P1, 3.5, LT8 |
| S7 | No test covered the wrappers' rule, the residue list was to be written from the output under test, the MacBook was held to the Studio's numbers, and L3 had no rollback | correctness, builder | LT2, LT12, L3 |
| S8 | L1's live step had no "nothing running" check; the 22-file comparison had no script; the real app was never started through LaunchServices | architecture, security, builder | 1.8, 1.4, LT11 |
| S9 | Apple's guidance was overstated; a path was spliced into shell code; self-location can break under `CDPATH` | security | section 2, 3.1, 3.2 |
| M | 8 lines, not six; one checksum only to `def die`; 57 executable lines; 15 memory files; 26 loose text files; an entry count that a `.DS_Store` would break; `patch_mkparent.py:30`, a `.c` and a `.py` comment unlisted; an argument about the folder rename that the phase order makes void | several | throughout |

Rejected: bare mirrors with a push-before-`button up` gate, to keep the trees in Caches (a standing chore to protect a choice nothing forces); copying both launchers by hand after `setup.sh` (it breaks the rule that deployed files are only ever copied by `setup.sh`); creating `common/paths.sh` inside the unification plan's Phase 3 (it couples a checked plan to this one for five lines).

### Second-pass re-check (fitted, 2026-11-09)

One agent re-read the reworked plan against the files, ran the new commands on the four real repos read-only, and wrote the move script and its test from this text alone in a scratch home. No blocker. Its fixes:

| # | Finding | Folded into |
|---|---|---|
| D1 | The old-install rule switched itself off: the file sets both roots, so a second sourcing, or a child that inherited them, read "a root is set" and resolved the new folders on an old install. The first pass's B1 by another door | 3.3, 3.1, LT1 |
| D2 | L1's exit could not be reached: the residue test allowed no line in the root `CLAUDE.md`, whose list of allowed places keeps the old folder until L2 | 3.6, LT12 |
| D3 | The live tests could be red on a healthy run: a waiting game update prints a `WARNING:` line | LT10, LT11 |
| D4 | `patches/README.md:9,11` tells readers to run `repatch.sh` from the checkout, which 3.2 breaks, and names no old path, so no test saw it | 3.6 |
| D5 | One fingerprint command fails on the repo with no commit; "114 in all" was a number, not the recorded listing | LT7 |
| D6 | The swap test's pattern matched almost nothing | LT15 |
| D7 | `~/Library/Developer` was called undocumented; Apple's table lists it for developer tools. The same folder is one people empty by habit | section 2, O3, O7, L2 steps 1 and 2 |
| D8 | The move script was under-specified: process detection by command line over-matches, a failure between its two moves left the rule naming an absent workspace, an ordinary install's one launcher backup created a workspace of its own, and the system does not refuse to rename a folder that holds a working directory | 3.4, section 2, L2 rollback, LT16 |
| m | The sourcing snippet lacked the `CDPATH` guard that 3.2 has; "three files" against LT14's four; 23 scripts in 1.3, not 26; the "57 executable lines" count did not reproduce and is gone; LT13 and half of LT15 were in no L2 criterion; "one checkbox per phase" against "three"; the mapping sentences were missing from LT12's counts | 3.1, 1.3, L2, LT12, O9 |

Not folded: making `move-install.sh` undo its own move (L2's rollback is three typed moves with one check, used at most once).

A third fitted pass, on the unification plan's `engine/` amendment (its third-pass block), also corrected this file: `SM_STATE` and `SM_WORK` in 3.1, 1.6 and LT1; the root `CLAUDE.md` count in 3.6; L0 step 3; and the Studio's state after Phase 3 in LT16 and L2 step 2.

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-09 | 1 (full) | architecture + rollout · security + privacy + platform facts · correctness + test plan · builder simulation | 4 agents in one batch; the builder built L1 in a scratch clone (4 local commits) and ran every gate that needs no live system; every blocker re-read inline | Fable 5.1 | this repo `7922bee` (plan references as of `adc5900`) · Surviving Mars `14df074` | build-ready-with-fixes |
| 2026-11-09 | 2 (fitted) | fold verification: each correction's normative home · the new facts · the move script written and tested from the text in a scratch home · read as the builder | 1 agent; its findings spot-checked inline (Apple's table fetched and read), then folded and audited two-sided, not re-checked by a third pass | Fable 5.1 | this repo `093f648` · Surviving Mars `14df074` | build-ready-with-fixes |
| 2026-11-09 | 3 (fitted, O4's amendment to the unification plan) | the amendment against the Surviving Mars code and both plans | 1 agent; its corrections to this file folded and audited inline | Fable 5.1 | this repo `997a91b` · Surviving Mars `14df074` | build-ready-with-fixes |

Key paths: `scripts/setup.sh` · `scripts/make-shortcut.sh` · `launchers/` · `patches/` (the five PDX patchers) · `repatch.sh` · `scripts/check-experiments.py` · `scripts/regen-winemac-patches.sh` · `scripts/test-update-check.sh` · `scripts/test-p4-signals.sh` · `scripts/boot-verify.sh` · `common/` · `INSTALL.md` · both `CLAUDE.md` · `docs/plans/1launcher-unification.md`.
