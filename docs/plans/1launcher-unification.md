# 1launcher — one repo for every game port, games as peer folders

> **Status: Triple-checked 2026-11-08 — build-ready-with-fixes (pass 1, 4 lenses; 5 blockers and the
> should-fixes folded; fitted re-check pending).** The build still waits on section 8: decisions O3, O6,
> O9 and O10 change what gets built.
> Written 2026-11-08. Tracking: none yet (opening an issue is a public post; decision O5).
> File and line references are as of `cc66a90`; after Phase 1 every CS2 path gains the prefix
> `cities-skylines-2/`. Surviving Mars references are to its public commit `14df074`.

## 0. Decisions already made (James, 2026-11-08)

| # | Decision | His words |
|---|---|---|
| D1 | One repo for all ports, neutral top level, games as peer folders | "closer to macgameports/unified/ with sub folders for cs2 and sm? It's still messy to have cs2/smr" |
| D2 | The repo is called `1launcher` | "1launcher maybe?" |
| D3 | Surviving Mars belongs in it, not in a repo of its own | "I had intended this to go in the cs2 repo" |
| D4 | The checkout lives with the other repos, not in the home folder | "I don't want it in my home directory I want it with all the other repos" |

D1 and D2 were made before this repo's traffic was measured (section 1); O6 puts the numbers beside them.
Nothing in this plan unifies the *engines*; section 7 says why.

## 1. Where things are today (measured 2026-11-08)

| Thing | State |
|---|---|
| This repo (`macgameport/cities-skylines-2-macos`) | 218 tracked files, 503 commits, 1 branch, 0 tags, 0 open PRs, 10 open issues, 11 stars, 0 forks, no Pages, no workflows, no git hooks, `main` unprotected. Everything is CS2 and sits at the top level: 10 root `.md` files, `archive/` (5), `docs/` (58), `launchers/` (14), `patches/` (18), `scripts/` (106), `repatch.sh` |
| Its audience, 14 days to 2026-11-08 | 250 clones by 128 unique cloners; 524 views by 326 unique visitors; 163 of them arrive from Google; 271 land on the front page, 26 open `README.md`, 17 `INSTALL.md` |
| `~/cs2-patch` | CS2's deploy and scratch folder, **outside the repo on purpose** (`CLAUDE.md` § Where things live). `scripts/setup.sh:105-109` copies one launcher, `repatch.sh`, `patches/*.py` and two helpers into it; the double-click CS2 app runs `~/cs2-patch/launch-cs2-dxmt11.sh`, never a repo file. The 22 deployable files (2 launchers, `repatch.sh`, 2 helpers, 17 patches) are byte-identical to their deployed copies today |
| Surviving Mars (`sm-patch`) | 26 tracked files. Public since today as its own repo with one scrubbed commit. Its checkout is in the home folder and is also its runtime: `runs/`, `backup/`, `engine/` and two built `.exe` helpers live in it, untracked, and its app's shim holds the launcher's absolute path (`make-app.sh:27`). Its 42 pre-publication commits stay private; the MacBook's app pulls a private remote at every launch |

The two already behave as one project:

- The launcher lock (`LOCK`, `lock_holder`, `acquire_lock`, `release_lock`) is the same code in three launchers, and `test-launch-lock.sh` is one file kept identical in both repos (its line 7 says so; `cmp` agrees).
- sm-patch's `make-app.sh:17` takes its icon tool from this repo's `scripts/pe-icon.py` by a fixed path.
- This repo's `launchers/launch-cs2.sh:4-5` documents running CS2 on the engine sm-patch builds.
- Surviving Mars findings already live here: `GOTCHAS.md`, `EXPERIMENTS.md` C82 and C83.

They differ in one thing this plan does **not** change: CS2 runs from deployed copies outside the repo, Surviving Mars runs from its checkout.

**How this repo's scripts find it.** 37 use their own location. One uses a fixed path (`scripts/test-launch-lock.sh:73`). One depends on the working directory: `scripts/check-experiments.py:310` runs `bash scripts/regen-winemac-patches.sh` with no `cwd`, so it passes only when started from the folder that holds `scripts/`.

**What is keyed to the checkout's path** (everything a folder rename can break):

| Keyed item | Where |
|---|---|
| Project git identity: commit author and push credential | a git include keyed to this checkout's path (`CLAUDE.local.md`). Measured: a clone outside the keyed path commits and pushes as the other identity; a repo-local include of the identity file restores all three values (name, email, credential) |
| The `gh` wrapper that selects the project account | a shell function keyed to the same path. It **is** active in Claude's tool shell here (measured: bare `gh` inside the checkout is the project account, outside it is not), so a bare `gh` in a renamed folder posts under the wrong account |
| Claude's project memory (24 files) and its per-project trust entry | both derived from the checkout path |
| Scheduled task `reddit-watch-cs2` | its `SKILL.md` names the path (4 lines), two root files by name (`:72-73`), and the repo address (`:8`) |
| The Surviving Mars app shim | holds the launcher's absolute path |
| `scripts/test-launch-lock.sh:73` (both copies), sm-patch `make-app.sh:17` | fixed paths to the sibling checkout |
| All of the above again on the MacBook | not visible from the Studio; section 6 |

Not keyed to it: the CS2 app and both CS2 launchers (they name neither the repo nor GitHub). `~/cs2-patch/queue-s2b.sh` names a path that no longer exists and is already dead. One private sibling repo cites this repo's address in prose.

## 2. Target

```
macgameport/1launcher            (this repo, renamed: same issues, stars and history)
├── README.md                    index: one row per game, plus CS2's quick start
├── CLAUDE.md                    cross-game rules; imports the games' files
├── CONTRIBUTING.md  LICENSE  .gitignore  .gitattributes  .github/  .env.example
├── docs/plans/                  repo-level plans (this file)
├── scripts/                     compatibility only (O10): a forwarding setup.sh and three pointer files
├── common/                      shared code; holds only the lock test until Phase 5
├── cities-skylines-2/           everything CS2, internal layout unchanged
└── surviving-mars-relaunched/   sm-patch's files, internal layout unchanged
```

Local checkout: `~/github/1launcher` on both Macs. Surviving Mars's local state (`runs/`, `backup/`, `engine/`) lives outside the checkout (O9). Unchanged: `~/cs2-patch` (name, place, role), the wrappers in `~/Applications`, one wrapper per game, both engines, CS2's deploy model, and **every deployed CS2 byte**: no CS2 launcher, patch or helper is edited in Phases 1 to 4, so the 22-file comparison (T2) must read 22 of 22 at the end of every phase.

## 3. Phases

Phases 1 to 4 are built from this document. Phase 5 is an outline only and needs its own plan and check. Each phase ends green before the next starts.

### Phase 0 — preflight (no repo changes)

1. James answers section 8.
2. Nothing running: no game, Steam or launcher on the Studio; no other Claude session in either checkout; `git worktree list` shows one entry; the `reddit-watch-cs2` task is paused until Phase 2 ends.
3. Both repos clean and level with their remotes.
4. **James adds the new path beside the old one in the two path-keyed dotfiles**: a second include for `~/github/1launcher/` and a second pattern in the `gh` wrapper. Additive: nothing matches until the folder exists. Measured: with the path pre-registered even a fresh clone there commits as the project identity. The old entries go in Phase 4.
5. Outside-link inventory, to be completed (wine bug 60263 has not been read). Measured so far:

| Linked from | Paths on `main` |
|---|---|
| The upstream DXMT thread (two comments) | `scripts/dxgiprobe.c`, `scripts/winemac-crossprocess-remote-layer.patch`, `scripts/dxmt-remote-layer-fallback.patch` |
| Wine bug 60263, per `scripts/regen-winemac-patches.sh:11,82` | one of the winemac patch files |
| This repo's own issues (#1, #7, #13, #16) | eight files under `docs/plans/` |
| Posted texts kept locally (`~/cs2-patch/community-watch/`, the wiki edit) | the repo root only |
| Traffic, most opened | `README.md`, `INSTALL.md`, `docs/perf-pass-results.md`, `launchers/`, `docs/plans/arm64-migration.md` |

   Scope to finish: the kept records under `docs/dxmt-bugs/` and `docs/wine-bugs/`, the live upstream threads, and `gh api …/traffic/popular/paths`.
6. Identifier scan of the whole repo (T6) and a decision on what it finds (O11).

Exit: answers and inventory recorded in this file, with accounts and home paths redacted.

### Phase 1 — restructure this repo in place (two commits, pushed together, no rename)

1.0 Rehearse the whole phase in a scratch clone and run every test of section 5 there first. (The check did this once: 211 renames, the gates as listed below.)

1.1 **Commit A, renames only.** `git mv CLAUDE.md CONFIG-TRIALS.md EXPERIMENTS.md GOTCHAS.md INSTALL.md MODS-TESTING.md PLAN.md README.md REFERENCES.md archive launchers patches scripts repatch.sh docs cities-skylines-2/`, then move this plan back to `docs/plans/`. Measured: 211 renames, all at 100% similarity when nothing else is in the commit; with the new root files in the same commit git records 209 and `git blame` on the moved README collapses to one commit. Stay at the root: `LICENSE`, `CONTRIBUTING.md` (GitHub reads it from the root), `.gitignore`, `.gitattributes`, `.github/` (issue templates must be there), `.env.example`. Untracked files inside a moved folder ride along with `git mv`. By hand on each Mac: `MODS-GUIDE.md` and `logs/` follow CS2; `.env`, `CLAUDE.local.md` and `.claude/` stay at the root.

1.2 **Commit B, everything else.** New root `README.md`: the games table, then CS2's quick start in full, because 271 of 326 visitors land here.

1.3 Old paths that others hold (O10):

| Held by | Kept working by |
|---|---|
| People with an existing clone, whose documented update is `git pull && bash scripts/setup.sh` (`INSTALL.md:265`) | a root `scripts/setup.sh` that execs `cities-skylines-2/scripts/setup.sh "$@"` |
| The three upstream-linked files | a pointer file at each old path naming the new one. The upstream comments are not edited, and the kept record `docs/dxmt-bugs/comment-141-split-plus-pair.md:354` stays as posted |
| The eight plan links in this repo's own issues | the issue text is edited to the new paths (a public edit, approved with the build). No stubs in root `docs/plans/`: the checked-plan audit would read them as unchecked plans |

1.4 `CLAUDE.md`, split by moving, not copying. To the root file: the layout, GitHub identity (`:59`), Personal info (`:120`), Model tier (`:154`), Deliberate deviations (`:190`). The rest moves with CS2. The root file imports it (`@cities-skylines-2/CLAUDE.md`; an import resolves relative to the importing file) and says the imported file's paths are relative to that folder. Test T12. Fallback: drop the import and rely on the game folder's file loading when a file there is first read, the pattern three sibling repos use.

1.5 What the move breaks, and the fix:

| Breaks | Fix |
|---|---|
| The published commands: `README.md:31`, `INSTALL.md:70`, `INSTALL.md:265`, `.github/ISSUE_TEMPLATE/not-working.md:18`, `scripts/setup.sh:8-10,141` all say `bash scripts/setup.sh` from the clone root | the docs gain `cd cities-skylines-2`; the forwarder of 1.3 covers anyone who does not re-read them (T11) |
| `scripts/check-experiments.py:310` is red from the repo root | add `cwd=REPO` to that `subprocess.run` (measured: exit 0 from the root and from `/tmp`) |
| `.gitignore:30` `!docs/images/*.png` no longer matches | replace it with the prefixed path. `:31` (`!docs/images/*.jpg`) is already dead because `*.jpg` at `:32` follows it: move the prefixed negation below `:33` |
| `reddit-watch-cs2` reads `README.md` and `GOTCHAS.md` at the root (`SKILL.md:72-73`) | game-folder prefix on both, in this phase, not in Phase 2 |
| `CONTRIBUTING.md`, the issue template, the `LICENSE` holder line | wording for a multi-game repo (O4) |
| `scripts/run-60262-repro.sh` holds an absolute home path on three lines (found by the check; predates this plan) | `$HOME` (O11) |
| This file's own references | prefix them |
| The lock test's fixed paths (`:73`) | nothing yet. Until Phase 3 this repo's copy still covers three launchers (17 PASS: 14 cases and 3 parity lines) and sm-patch's copy compares its launcher only with itself. Do not re-run sm-patch's `make-app.sh` in that window: its icon tool is gone and it falls back to a generic icon without a word |

Not broken, by measurement: all 107 relative links in 56 `.md` files, 84 of them to `.md` targets (0 unresolved before and after); `setup.sh` (own location); every `.gitignore` pattern for a personal or secret file (`MODS-GUIDE.md`, `logs/`, `.env`, `CLAUDE.local.md`, `.claude/`, `*.png`, `*.exe` all still match one level down).

1.6 Deploy identity (T2). **Never run `setup.sh` into a scratch folder**: it has no copy-only mode, and after the copy it patches the real game (`:115`) and rebuilds the CS2 app to point at whatever folder it was given (`:124`, `make-shortcut.sh:68,78`).

**Exit criteria.** Working tree clean. Commit A is 211 renames at 100%. From `cities-skylines-2/`: `check-experiments.py` exits 0 from the repo root, the game folder and `/tmp`; `test-launch-lock.sh` exits 0 with 17 PASS; `test-update-check.sh`, `test-p4-signals.sh` and `test-rosetta-preflight.sh` exit 0; a syntax pass over every moved `.sh` and `.py`. T1 reads 0 unresolved. T2 reads 22 of 22. T4, T11 and T12 pass. `git check-ignore` gives the answers in T13. No CS2 launch is needed: T2 is the measurement that no deployed byte changed.

**Rollback.** `git revert` both commits, clean until Phase 2.1 edits the same files; after that, fix forward. The by-hand moves are undone by hand.

### Phase 2 — rename: GitHub first, then the Studio's folder

2.1 GitHub: rename the repo to `1launcher` under the project identity. Update description and topics, keeping the game's name in both. `git remote set-url origin` on the Studio. The old address appears 42 times in 17 files: the 36 URLs get the new name (32 issue links, 2 clone lines, 1 root link, 1 file link inside the kept record, which stays as posted); of the 6 others, the three `cd cities-skylines-2-macos` commands change with the URL, and `LICENSE:3` and two lines of posted wiki text are decided with O4 and left. Search for the full string: `cities-skylines-2/` is now a folder with the same prefix. What GitHub redirects after a rename: web pages, issues, stars, and `git clone`, `fetch` and `push`. ⚠ The redirect ends if a repo named `cities-skylines-2-macos` is ever created in the org again. Whether renaming back restores everything is unverified: treat the rename as one-way.

2.2 The Studio's folder, in this order:

1. Confirm Phase 0 step 4 is done: both dotfiles name the new path.
2. Add a repo-local include of the project identity file, so identity no longer depends on the path at all.
3. From a terminal or a session whose working directory is elsewhere: `mv ~/github/cs2 ~/github/1launcher`.
4. **Identity gate, before any commit, push or `gh` call from the new path.** All must name the project identity:
   - `git var GIT_AUTHOR_IDENT` and `git var GIT_COMMITTER_IDENT`, name and address;
   - `printf 'protocol=https\nhost=github.com\n\n' | git credential fill | sed -n 's/^username=//p'` (never unfiltered: the raw output carries the token);
   - `gh api user --jq .login`, bare and again with the project config directory.
5. Claude memory: copy the 24 files to the directory derived from the new path; rewrite the three whose content the merge makes wrong (the layout note and the two that name the old path); update the pointer memory in the `~/cs2-patch` project; start a session in the new folder and confirm the index loads. Transcripts stay behind. The new path is a new project to Claude Code, so it asks for trust again.
6. `reddit-watch-cs2`: the folder name and the repo address in its `SKILL.md`; un-pause it.

**Exit criteria.** Old address redirects for the web page and `git ls-remote`. Gate passed and recorded before the first push; the first push is then read back anonymously and shows the project identity as author. `git config --show-origin --get-all user.name` lists the project value from both the path-keyed include and the repo-local one. Memory index loads in a new session. T2 reads 22 of 22.

**Rollback.** `mv` back; the repo-local include and the extra dotfile entries are harmless either way. The GitHub rename is not counted on to reverse.

### Phase 3 — Surviving Mars comes in

3.1 `git -C <sm checkout> archive 14df074 | tar -x -C surviving-mars-relaunched/`, one commit. Assert 26 files. An archive cannot carry untracked or ignored files, editor backups or later edits. Its own `.gitignore` comes along and stays: measured, it is the file that ignores `backup/`, `runs/`, `scratch/` and `engine/` there, and the root `*.exe` covers the helpers. T6 runs on the staged tree, the file names and the commit message before the push.

3.2 Make its scripts find themselves, with one state variable. `launch-relaunched.sh` has no self-location today: add it after `set -u` (`:67`) and derive `HELPER` (`:71`) and the two messages (`:103`, `:110`) from it. `RUNS` (`:72`), `tools/make-engine.sh:48` (whose own `HERE` is defined later, at `:65`, and is `tools/`), `tools/inject-ab.sh:12,23-24`, `tools/steam-judge.sh:11` and `patch-window-origin.py:52` take the state folder of O9. T14 checks the directory level of each, which the test files do not: none of them executes these lines.

3.3 `common/test-launch-lock.sh`: `git mv` this repo's copy, find the three launchers by relative path, exit 2 unless all three are found, drop the `$HOME` sibling loop; delete the Surviving Mars copy. The lock functions stay in the launchers until Phase 5.

3.4 `make-app.sh`: the icon tool by relative path (`:17`); the launch-time pull per O3.

| O3 | Shim | `tools/test-make-app.sh` |
|---|---|---|
| (c), recommended | the pull block and its comments (`:7-10`, `:49-65`) are removed | deleted: every case in it is about the pull |
| (b) | remote stays `hub`; the guard `[ -d "$REPO/.git" ]` (`:57`) becomes `git -C "$REPO" rev-parse --git-dir`, because the launcher's folder is no longer the repo root and the present guard skips the pull without a word (measured: 6 cases red with the old guard, 0 with the new) | the launcher moves into a subfolder of its throwaway repo, 5 lines |
| (a) | as (b), plus remote `origin`, a hard timer on the pull (the present 5 s bound is an ssh option and does nothing over HTTPS; an unroutable address was still hanging at 12 s), and a rewritten trust comment | as (b), plus 8 lines naming the remote, and an offline case |

3.5 Local state on the Studio: move `runs/`, `backup/` and `engine/` to the folder of O9 and the two `.exe` helpers into `surviving-mars-relaunched/tools/`; then re-run `make-app.sh` so the shim names the new launcher. Before the move, `git check-ignore -q` passes for a path under each state folder and for `tools/x.exe`; after it, `git status --porcelain` is empty.

3.6 Docs, none of them deployed files: the Surviving Mars README (clone address, the private-remote paragraph, History, the cs2-checkout line at `:53`, and a sentence on where the checkout may not live, citing `setup.sh:14-15`); this repo's `CLAUDE.md` row for Surviving Mars and the engine path in the row above it; `GOTCHAS.md` path pointers (`:2797`, `:2844`, `:2871`, `:2926`) and the plan path at `:2851`; the evidence path in `EXPERIMENTS.md` C83; the root README index. `scripts/cell-fingerprint.sh:60` counts uncommitted files across the whole repo: scope it to the game folder, or Surviving Mars edits will show in CS2's cell records. Left alone on purpose: the comments in both CS2 launchers that say "sm-patch" (deployed files; Phase 5 touches them), the sm-patch commit hashes cited in `GOTCHAS.md` (dated, private history), and the bundle identifier at `make-app.sh:104`, which is a key.

3.7 Retire, only after the exit criteria pass: the old checkout; the separate public repo (O2; deleting is James's click). The pre-publication history stays private and is never pushed.

**Exit criteria.** Working tree clean. Surviving Mars's test files green from the new location and each `MUTANT=1` red: six under (c), seven under (a) or (b) (`test-make-engine-install.sh` runs the real engine's `wine64 --version`, so it runs on the Studio). T8 reads 24 PASS. T6 reads 0. T14 passes. T2 reads 22 of 22. One visible launch from the app on the Studio, James warned first and the MacBook's Steam closed: menu reached; the log is under the new state folder and has its `.frame-fix` companion; the old `~/sm-patch/runs` is not recreated; the app has its icon; graceful exit with the Steam Cloud line. `git grep sm-patch` returns only the mentions 3.6 lists as left alone.

**Rollback.** Revert the commits. The old checkout exists until the exit criteria pass; move its state back and re-run its `make-app.sh` (the icon is generic until the icon tool's old path exists again).

### Phase 4 — the MacBook, one visit

Until this phase its Surviving Mars keeps pulling its private remote and its CS2 keeps working through the redirect and its deployed copies; pulling Phase 1 early is safe for play. Then: section 6's inventory; Phase 0 step 4 for its own dotfiles; `git remote set-url` and pull; the by-hand moves of 1.1; Phase 2.2 steps 2 to 4 for its own path; Surviving Mars state as in 3.5 and `make-app.sh`; remove its old checkout; drop the old-path entries from the dotfiles on both Macs. If its checkout is under `~/Documents`, it moves out first: macOS blocks an app from running scripts there (`setup.sh:14-15`), and Surviving Mars runs from its checkout. No Claude auto-memory is written there (global rule).

Exit: identity gate passed there; both games launched once from their apps; T2 reads 22 of 22 there or the difference is explained by an older deploy.

### Phase 5 — shared launcher core (outline only)

Candidates, by measurement: the lock (identical three times), Steam attribution by open files, sign-in and licence wait, the update check, graceful Steam stop, the cloud verdict, the app builders, `pe-icon.py` (a peer reaching into a peer after 3.4), the engine builders. Its plan must answer: how a shared file reaches CS2's deployed copies, given the rule never to edit a launcher in place; what the per-game config holds; whether the two run models merge; and whether the launch-time pull returns with a check the pulled commit must pass.

## 4. Who notices what

| Audience | Effect | Mitigation |
|---|---|---|
| Visitors from search (163 of 326) | They land on an index instead of CS2's README, and the repo name no longer contains the game's name | the root README carries CS2's quick start; description and topics keep the name (O6) |
| People with a clone (128 unique cloners in 14 days) | Their update command names a path that moved | the forwarder of 1.3 (T11) |
| Readers of upstream threads | Three file links on `main` | pointer files (O10) |
| James's Macs | The keyed items in section 1 | Phases 0, 2 and 4 |
| Claude sessions | Memory, trust and one scheduled task follow the path | Phase 0 step 2, 1.5, 2.2 |
| Plan audits | Three `docs/plans/` folders exist afterwards | audits must glob `docs/plans/*.md` and `*/docs/plans/*.md` |

## 5. Test plan

| # | Test | Passes when | Mutant, applied and seen red |
|---|---|---|---|
| T1 | Relative-link resolver over every tracked `.md` (to be written; fenced and inline code excluded) | 0 unresolved (baseline 0 of 107) | move `docs/patch-inventory.md` up one level in a scratch tree: 7 unresolved |
| T2 | From `cities-skylines-2/`: `cmp -s` `launchers/launch-cs2-dxmt11.sh`, `launchers/launch-cs2.sh`, `repatch.sh`, `scripts/cs2-display-profile.sh`, `scripts/patch-modconflict-badge.py` and each `patches/*.py` against its copy in `~/cs2-patch`; plus `setup.sh --check` exits 0 | 22 found, 22 identical (baseline 22 of 22) | leave `scripts/cs2-display-profile.sh` at the old root in a scratch tree: 21 found |
| T3 | CS2 gates from the new paths, counts as in Phase 1's exit criteria | all exit 0 with those counts | delete one row of `docs/images/AUDIT.md` in a scratch tree: `check-experiments.py` exits 1. Remove `cwd=REPO`: it exits 1 from `/tmp` |
| T4 | `git log --follow --oneline` on `README.md`, `INSTALL.md`, `CLAUDE.md`, `GOTCHAS.md`, `scripts/setup.sh` | each count is the pre-move count plus 1 (`GOTCHAS.md` 154 to 155, `setup.sh` 4 to 5); `git blame` on the moved README shows more than one commit | drop `--follow`: the count is 1 |
| T5 | Identity gate (2.2 step 4) | every value names the project identity | a scratch clone outside the keyed paths with no repo-local include: the gate names the other identity |
| T6 | `common/check-identifiers.sh` (to be written): reads the real identifiers from the machine at run time (Steam ID64, account id, `[U:1:n]`, Steam login and display name, the personal GitHub login and addresses, the short user name in `/Users/<name>`, the host names) plus the pattern `7656119[0-9]{10}`; scans a tree, its file names and a commit message; prints counts only | 0 hits on the staged Surviving Mars tree; on the whole repo, only the hits O11 accepts | plant one literal of each class in a scratch copy: 1 hit each. (A bare 17-digit pattern is wrong: `tools/frame-fix.c:11` holds an 18-digit forum thread number) |
| T7 | Surviving Mars's test files from `surviving-mars-relaunched/` | each exits 0 | each file's own `MUTANT=1`: exits 1 |
| T8 | `common/test-launch-lock.sh` | 24 PASS: 21 cases and 3 parity lines | `MUTANT=1`: exits 1. Alter `acquire_lock` in one launcher of a scratch copy: a parity line differs. Remove one launcher: exits 2 |
| T9 | Under O3 (a) or (b): the shim with the launcher in a subfolder of a repo | the log's `scripts:` line says current or updated | restore the old guard: no `scripts:` line |
| T10 | Live: Surviving Mars from the app, Studio then MacBook | as in Phase 3's exit criteria | none: a live run |
| T11 | Fresh clone in `/tmp`: the README quick start typed as printed, through `setup.sh --check`; and the old update command through the forwarder | both reach `setup.sh`'s first check line | leave out the `cd` in the README, or delete the forwarder: `No such file or directory` |
| T12 | A fresh session at the repo root, and one subagent, each quote one line that exists only in the CS2 file and one only in the root file; `/context` lists the CS2 file | both quote both; if the CS2 file is listed twice, use the fallback of 1.4 | remove the import line: the CS2-only line is not quoted before a CS2 file is read |
| T13 | `git check-ignore -q` after the move | ignored: `cities-skylines-2/MODS-GUIDE.md`, `cities-skylines-2/logs/x`, `cities-skylines-2/scripts/x.png`, `.env`; not ignored: `cities-skylines-2/docs/images/x.png` and `x.jpg` | leave the prefix off the negation: the image is ignored |
| T14 | Source each path-setting line of the five Surviving Mars scripts in a scratch copy and print what it resolves to | every path is inside `surviving-mars-relaunched/` or the O9 state folder, and exists | use the wrong directory level in one `tools/` script: its path does not exist |

## 6. MacBook inventory (run there; paste **redacted** output: home folder as `~`, accounts as project or personal)

Where the two checkouts are and whether either is under `~/Documents`; `git -C <each> remote -v` and `status -sb`; whether `git var GIT_AUTHOR_IDENT` and the filtered credential username name the project identity in each; `whence -w gh` and the wrapper's path patterns; `git config --global --get-regexp '^includeif'`; the `SCRIPT=` line of each game's app shim; whether `~/cs2-patch` exists there and its launcher's date; any scheduled task naming either path.

## 7. Not in this plan: one engine

Measured on 2026-11-07: Surviving Mars is DirectX 12 only and needs D3DMetal 3.0; D3DMetal 3.0 does not run on this repo's Wine 11.16 engine (`EXPERIMENTS.md` C83); CS2 on Wine 10 with D3DMetal 3.0 reaches the main menu, with a loaded city, performance and long sessions untested (C82), and that engine is not the free route this repo documents. So the repo, the layout and later the launcher code unify; the engine stays a per-game choice until a loaded-city run on a shared engine says otherwise.

## 8. Open decisions (James)

| # | Question | Recommendation |
|---|---|---|
| O1 | Game folder names | `cities-skylines-2/` and `surviving-mars-relaunched/`: a visitor reads them first. Short forms (`cs2/`, `sm/`) are the alternative |
| O2 | The separate Surviving Mars repo published today | Make it private now; delete it when Phase 3 passes |
| O3 | Surviving Mars's launch-time pull once it lives here. Its own shim says the pull is acceptable only from a private repo James alone controls. Every option ends up running what is on public `main`, which is unprotected and writable with any credential of either of his identities on either Mac; `--ff-only` refuses rewritten history and authenticates nothing. They differ in the last step: **(a)** pull `origin main` at launch: one commit on public `main` runs on both Macs at the next double-click, unattended, with no diff shown. **(b)** a private remote for this repo, pushed alongside: the commit must first be pulled and pushed on the Studio. **(c)** no pull at launch: it must first be pulled by hand on that Mac, as CS2 already requires | **(c)**. It drops a feature built this morning and costs one manual pull on the MacBook. (b) keeps the feature and its rule at the price of a second remote. (a) only with a check the pulled commit must pass, which is Phase 5 work |
| O4 | Licence | One MIT licence for the repo; Surviving Mars's code becomes MIT by moving in. GitHub reports this repo's licence as unrecognised today because of the note appended to `LICENSE`: move the note to the root README, extend it to Surviving Mars's third parties, rename the holder line, and reword the Surviving Mars README's "nothing built from it may be redistributed" so it names the engine only |
| O5 | A public tracking issue for this plan | Yes, this repo's practice for umbrella work |
| O6 | Go ahead with the rename and the index front page, given the audience in section 1? The alternative is to leave this repo's name and front page alone and start `1launcher` as a new repo for Surviving Mars and later games | Go ahead, with the mitigations in section 4. The cost that remains is a possible drop in search ranking, which nothing here can measure in advance |
| O7 | `~/cs2-patch` (153 G, in the home folder) | Out of scope; Phase 5's plan decides |
| O8 | When | Phase 1 rewrites every CS2 path, so not while other CS2 work is in flight |
| O9 | Where Surviving Mars's local state lives: saves and Steam manifests in `backup/`, logs in `runs/`, a vendor's graphics library in `engine/` | Outside the checkout, in `~/Library/Application Support/1launcher/surviving-mars-relaunched/`. Inside the game folder, a `.gitignore` would be the only thing between them and a public repo; CS2 keeps its evidence outside the repo for the same reason |
| O10 | Compatibility files at old paths: the forwarding `scripts/setup.sh` and three pointer files | Keep them for now. The alternative is a cleaner root and broken links for 128 recent cloners and one upstream thread |
| O11 | Personal identifiers already in this repo: the personal GitHub login in four files (three kept records of upstream comments and the September hygiene plan, which lists them as an accepted residual), and an absolute home path in `scripts/run-60262-repro.sh` | Leave the accepted four; replace the home path with `$HOME` in Phase 1 |

## Review corrections (triple-check 2026-11-08)

Pass 1, four lenses, all `build-ready-with-fixes`. Every blocker was re-read against the code before it was accepted.

| # | Finding | Lenses | Folded into |
|---|---|---|---|
| B1 | The deploy test told the builder to run `setup.sh` into a scratch folder; it has no copy-only mode and would have re-patched the game and repointed the CS2 app | correctness, architecture, builder | 1.6, T2 |
| B2 | The move breaks the published install and update commands, and the plan did not list them | correctness, architecture, builder | 1.2, 1.3, 1.5, section 4, T11 |
| B3 | The outside-link inventory was scoped too narrowly and its "kept texts link only the root" claim was false: three upstream-linked files and eight issue-linked plans | correctness, architecture | Phase 0 step 5, 1.3, O10 |
| B4 | `check-experiments.py` was called own-location; one call in it depends on the working directory and is red from the repo root after the move | builder, correctness, architecture | section 1, 1.5, T3 |
| B5 | O3 recommended pulling the public repo at launch, reversing the shim's own trust rule without saying so, and understated who can write to `main` | security | O3, 3.4, Phase 5 |
| S1 | The dotfile update came after the folder move, leaving `gh` guarded by prose; the wrapper is live in Claude's tool shell | security | Phase 0 step 4, 2.2 |
| S2 | The identity gate could not run as written and checked a label; the exit criterion measured after the public push | security, correctness | 2.2 step 4, Phase 2 exit, T5 |
| S3 | The identifier scan named no tool and no classes, and its mutant contradicted its pass condition | security, correctness, builder | T6, Phase 0 step 6, O11 |
| S4 | One commit hides two renames and collapses `git blame` on the README | builder, architecture | 1.1, T4 |
| S5 | The lock test and the icon lookup weaken silently between Phase 1 and Phase 3 | builder, correctness, architecture | 1.5 |
| S6 | Phase 3 edited a deployed launcher, creating drift | builder, correctness | section 2 invariant, 3.6 |
| S7 | "Eight test files" contradicted the step that moves one out; the pull's test needs more than one added case | all four | 3.3, 3.4, Phase 3 exit, T7, T8 |
| S8 | A root `.gitignore` step that has no effect; the `.jpg` exception that never worked | builder, security | 3.1, 1.5, T13 |
| S9 | Local state would sit inside a public repo's working tree; the checkout may not live under `~/Documents` | security, architecture | O9, 3.2, 3.5, Phase 4 |
| S10 | The scheduled task reads two root files by name | architecture | Phase 0 step 2, 1.5, 2.2 |
| S11 | The `CLAUDE.md` step said both "moves unchanged" and "root holds the shared rules" | architecture, security | 1.4, T12 |
| S12 | The audience was not measured; the search cost was "accepted" without numbers | architecture | section 1, section 4, O6 |
| S13 | The plan named a private sibling repo and attributed a blocked edit to "his settings" | security | section 1, 2.2 |
| M | Ten root `.md` files, not nine; `make-app.sh:17`, not `:16`; `--follow` counts are plus 1; `scratch/` does not exist; the licence is not detected as MIT; the per-project trust entry; a dead `queue-s2b.sh` | several | throughout |

Rejected: adding a `--copy-only` flag to `setup.sh` (a `cmp` loop measures the same thing without touching a deploy script); pulling the lock-test merge forward into Phase 1 (it needs Surviving Mars in the tree).

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-08 | 1 (full) | architecture + rollout · security + identity + platform facts · correctness + test plan · builder simulation | 4 agents in one batch; the builder executed Phases 1 and 3 on scratch clones and ran the gates; every blocker re-read inline | Fable 5.1 | this repo `cc66a90` (plan at `cc5d3cb`) · Surviving Mars `14df074` | build-ready-with-fixes |

Key paths: `scripts/setup.sh` · `scripts/make-shortcut.sh` · `scripts/check-experiments.py` · `scripts/test-launch-lock.sh` · `scripts/cell-fingerprint.sh` · `launchers/` · `.gitignore` · `LICENSE` · `README.md` · `INSTALL.md` · `CLAUDE.md` · `docs/agent-brief.md` · Surviving Mars: `launch-relaunched.sh`, `make-app.sh`, `tools/`.
