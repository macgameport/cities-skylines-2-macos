# 1launcher — one repo for every game port, games as peer folders

> **Status: Triple-checked 2026-11-08 — build-ready-with-fixes (pass 1, 4 lenses, 5 blockers folded;
> fitted re-check the same day, no blocker, its 10 fixes folded).** The build still waits on section 8:
> decisions O3, O6, O9 and O10 change what gets built.
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
├── INSTALL.md                   three-line pointer to cities-skylines-2/INSTALL.md
├── CLAUDE.md                    cross-game rules; imports the games' files
├── CONTRIBUTING.md  LICENSE  .gitignore  .gitattributes  .github/  .env.example
├── docs/plans/                  repo-level plans (this file)
├── scripts/                     compatibility only (O10): a forwarding setup.sh and three pointer files
├── common/                      shared code: two check scripts from Phase 1, the lock test from Phase 3
├── cities-skylines-2/           everything CS2, internal layout unchanged
└── surviving-mars-relaunched/   sm-patch's files, internal layout unchanged
```

Local checkout: `~/github/1launcher` on both Macs. Surviving Mars's local state (`runs/`, `backup/`, `engine/`) lives outside the checkout (O9). Unchanged: `~/cs2-patch` (name, place, role), the wrappers in `~/Applications`, one wrapper per game, both engines, CS2's deploy model, and **every deployed CS2 byte**: no CS2 launcher, patch or helper is edited in Phases 1 to 4, so the 22-file comparison (T2) must read 22 of 22 at the end of every phase.

## 3. Phases

Phases 1 to 4 are built from this document. Phase 5 is an outline only and needs its own plan and check. Each phase ends green before the next starts.

### Phase 0 — preflight (no commits)

1. James answers section 8.
2. Nothing running: no game, Steam or launcher on the Studio; no other Claude session in either checkout; `git worktree list` shows one entry; the `reddit-watch-cs2` task is disabled in the scheduler and stays disabled, across any gap between phases, until 2.2 step 6.
3. Both repos clean and level with their remotes.
4. **James adds the new path beside the old one in the two path-keyed dotfiles**: a second include for `~/github/1launcher/` and a second pattern in the `gh` wrapper. Additive: nothing matches until the folder exists. Measured: with the path pre-registered even a fresh clone there commits as the project identity. The old entries go in Phase 4.
5. Outside-link inventory. Measured:

| Linked from | Paths on `main` |
|---|---|
| The upstream DXMT thread (two comments) | `scripts/dxgiprobe.c`, `scripts/winemac-crossprocess-remote-layer.patch`, `scripts/dxmt-remote-layer-fallback.patch` |
| Wine bug 60263 (read during the re-check; `scripts/regen-winemac-patches.sh:11,82`) | `scripts/winemac-crossprocess-remote-layer.patch` only |
| This repo's own issues (#1, #7, #13, #16) | eight files under `docs/plans/` |
| Posted texts kept locally (`~/cs2-patch/community-watch/`) | the repo root only |
| Traffic, most opened | `README.md` (26 visitors) and `INSTALL.md` (17): each keeps a root file. `docs/perf-pass-results.md` (4), `launchers/` (4), `docs/plans/arm64-migration.md` (3): nothing kept, a recorded decline; the last is fixed at its source in issue #16 |

   Left for the day of the build: re-run `gh api …/traffic/popular/paths`, and read any kept record under `docs/dxmt-bugs/` and `docs/wine-bugs/` posted since.
6. Identifier scan of the whole repo (T6) and a decision on what it finds (O11). The scan script is written here and run uncommitted; it is committed in Phase 1 beside the link resolver.

Exit: answers and inventory recorded in this file, with accounts and home paths redacted.

### Phase 1 — restructure this repo in place (two commits, pushed together, no rename)

1.0 Rehearse the whole phase in a scratch clone first, and run there the tests that need no live system: T1, T2, T3, T4, T11, T13. (The check did this once.) One number differs in a rehearsal: the lock test reads 19 PASS there, because its fixed paths still find the real checkout's launchers. It reads 17 only after the real move.

1.1 **Commit A, renames only.** `mkdir cities-skylines-2`, then `git mv CLAUDE.md CONFIG-TRIALS.md EXPERIMENTS.md GOTCHAS.md INSTALL.md MODS-TESTING.md PLAN.md README.md REFERENCES.md archive launchers patches scripts repatch.sh docs cities-skylines-2/`, then `mkdir -p docs/plans` and `git mv` this plan back. Measured: 211 renames, all at 100% similarity when nothing else is in the commit; with the new root files in the same commit git records 209 and `git blame` on the moved README collapses to one commit. Stay at the root: `LICENSE`, `CONTRIBUTING.md` (GitHub reads it from the root), `.gitignore`, `.gitattributes`, `.github/` (issue templates must be there), `.env.example`. Untracked files inside a moved folder ride along with `git mv`. By hand on each Mac: `MODS-GUIDE.md` and `logs/` follow CS2; `.env`, `CLAUDE.local.md` and `.claude/` stay at the root.

1.2 **Commit B, everything else.** New root `README.md`: the games table (one row until Phase 3 adds the second), then a copy of CS2's quick start, its lead-in sentence and the block at `README.md:29-33` with `cd cities-skylines-2` added, because 271 of 326 visitors land here. CS2's own README keeps its copy. Also in commit B: `common/check-links.py` (T1), `common/check-identifiers.sh` (T6), and a three-line root `INSTALL.md` pointing at `cities-skylines-2/INSTALL.md`.

1.3 Old paths that others hold (O10):

| Held by | Kept working by |
|---|---|
| People with an existing clone, whose documented update is `git pull && bash scripts/setup.sh` (`INSTALL.md:265`) | a root `scripts/setup.sh` that execs `cities-skylines-2/scripts/setup.sh "$@"` |
| The three upstream-linked files | a pointer file at each old path: one line naming the new path, a C comment in the `.c` file and plain text in the two `.patch` files, so `git apply` on a pointer fails loudly. The upstream comments are not edited, and the kept record `docs/dxmt-bugs/comment-141-split-plus-pair.md:354` stays as posted |
| The eight plan links in this repo's own issues (#1, #7, #13, #16; bodies and comments) | the text is edited to the new paths after the push, so the links resolve (a public edit, approved with the build). No stubs in root `docs/plans/`: the checked-plan audit would read them as unchecked plans |

1.4 `CLAUDE.md`, split by moving, not copying. To the root file: a new section giving the tree of section 2, then GitHub identity (`:59`), Personal info (`:120`), Model tier (`:154`), Deliberate deviations (`:190`). The rest moves with CS2. The root file imports it (`@cities-skylines-2/CLAUDE.md`; an import resolves relative to the importing file) and says the imported file's paths are relative to that folder. Test T12. Fallback: drop the import and rely on the game folder's file loading when a file there is first read, the pattern three sibling repos use.

1.5 What the move breaks, and the fix:

| Breaks | Fix |
|---|---|
| The published commands say `bash scripts/setup.sh` from the clone root: `README.md:31-32`, `INSTALL.md:70-71`, `:78`, `:265`, `:279`, `.github/ISSUE_TEMPLATE/not-working.md:18`, `scripts/setup.sh:8-10,141`, the draft wiki text at `docs/applegamingwiki-edit.md:37`, and two messages inside the deployed `launchers/launch-cs2-dxmt11.sh` (`:9`, `:188`) | the docs gain `cd cities-skylines-2`. The launcher's two messages cannot change without changing a deployed file, so they rely on the forwarder of 1.3, which also covers anyone who does not re-read the docs (T11) |
| `scripts/check-experiments.py:310` is red from the repo root | add `cwd=REPO` to that `subprocess.run` (measured: exit 0 from the root and from `/tmp`) |
| `.gitignore:30` `!docs/images/*.png` no longer matches | replace it with the prefixed path. `:31` (`!docs/images/*.jpg`) is already dead because `*.jpg` at `:32` follows it: move the prefixed negation below `:33` |
| `reddit-watch-cs2` reads `README.md` and `GOTCHAS.md` at the root (`SKILL.md:72-73`) | game-folder prefix on both, in this phase, not in Phase 2 |
| `CONTRIBUTING.md`, the issue template, `LICENSE` | wording for a multi-game repo. Per O4: the note at `LICENSE:23-29` moves to the root README so GitHub can recognise the licence, and the holder line at `:3` is renamed |
| `scripts/run-60262-repro.sh` holds an absolute home path on three lines (found by the check; predates this plan) | `$HOME` (O11) |
| This file's own references | prefix them |
| The lock test's fixed paths (`:73`) | nothing yet. Until Phase 3 this repo's copy still covers three launchers (17 PASS: 14 cases and 3 parity lines) and sm-patch's copy compares its launcher only with itself. Do not re-run sm-patch's `make-app.sh` in that window: its icon tool is gone and it falls back to a generic icon without a word |

Not broken, by measurement: all 107 relative links in the tracked `.md` files (56 files with this plan), 84 of them to `.md` targets (0 unresolved before and after); `setup.sh` (own location); every `.gitignore` pattern for a personal or secret file (`MODS-GUIDE.md`, `logs/`, `.env`, `CLAUDE.local.md`, `.claude/`, `*.png`, `*.exe` all still match one level down).

1.6 Deploy identity (T2). **Never run `setup.sh` into a scratch folder**: it has no copy-only mode, and after the copy it patches the real game (`:115`) and rebuilds the CS2 app to point at whatever folder it was given (`:124`, `make-shortcut.sh:68,78`).

**Exit criteria.** Working tree clean. Commit A is 211 renames at 100% and nothing else. T3: `check-experiments.py` exits 0 started from the repo root, from the game folder and from `/tmp`; `test-launch-lock.sh` exits 0 with 17 PASS; `test-update-check.sh`, `test-p4-signals.sh` and `test-rosetta-preflight.sh` exit 0; `bash -n` on the 43 `.sh` and 15 `.command` files and `python3 -m py_compile` on the 41 `.py` files report nothing. T1 reads 0 unresolved. T2 reads 22 of 22. T4, T11, T12, T13 and T15 pass. T6 over the whole repo reads only what O11 accepts. No CS2 launch is needed: T2 is the measurement that no deployed byte changed.

**Rollback.** `git revert` both commits, clean until Phase 2.1 edits the same files; after that, fix forward. The by-hand moves are undone by hand.

### Phase 2 — rename: GitHub first, then the Studio's folder

2.1 GitHub: rename the repo to `1launcher` under the project identity. Update description and topics, keeping the game's name in both. `git remote set-url origin` on the Studio. The edits of this step are committed and pushed from the old folder, before 2.2. The old address appears 42 times in 17 files: the 36 URLs get the new name (32 issue links, 2 clone lines, 1 root link, 1 file link inside the kept record, which stays as posted); of the 6 others, the three `cd cities-skylines-2-macos` commands change with the URL, `LICENSE:3` was renamed in Phase 1, and the two lines in `docs/applegamingwiki-edit.md` (`:66`, `:78`) change too: that file's header says it is a draft that was never submitted, so all of it is live text. Search for the full string: `cities-skylines-2/` is now a folder with the same prefix. What GitHub redirects after a rename: web pages, issues, stars, and `git clone`, `fetch` and `push`. ⚠ The redirect ends if a repo named `cities-skylines-2-macos` is ever created in the org again. Whether renaming back restores everything is unverified: treat the rename as one-way.

2.2 The Studio's folder, in this order:

1. Confirm Phase 0 step 4 is done: both dotfiles name the new path.
2. Add a repo-local include of the project identity file, so identity no longer depends on the path at all.
3. From a terminal or a session whose working directory is elsewhere: `mv ~/github/cs2 ~/github/1launcher`.
4. **Identity gate, before any commit, push or `gh` call from the new path.** All must name the project identity:
   - `git var GIT_AUTHOR_IDENT` and `git var GIT_COMMITTER_IDENT`, name and address;
   - `printf 'protocol=https\nhost=github.com\n\n' | git credential fill | sed -n 's/^username=//p'` (never unfiltered: the raw output carries the token);
   - `gh api user --jq .login`, bare and again with the project config directory.
5. Claude memory: copy the 24 files to the directory derived from the new path; rewrite the three whose content the merge makes wrong (the note that records this decision and the two that name the old path); update the pointer memory in the `~/cs2-patch` project; start a session in the new folder and confirm the index loads. Transcripts stay behind. The new path is a new project to Claude Code, so it asks for trust again.
6. `reddit-watch-cs2`: the folder name (4 lines) and the repo address (`:8`, `:54`) in its `SKILL.md`; enable it again.

**Exit criteria.** Old address redirects for the web page and `git ls-remote`. The gate (T5) passed and recorded. Phase 2 pushes nothing from the new path; the first push from it, Phase 3's first commit, is read back anonymously and must show the project identity as author. `git config --show-origin --get-all user.name` lists the project value from both the path-keyed include and the repo-local one. Memory index loads in a new session. T2 reads 22 of 22.

**Rollback.** `mv` back; the repo-local include and the extra dotfile entries are harmless either way. The GitHub rename is not counted on to reverse.

### Phase 3 — Surviving Mars comes in

3.1 `git -C <sm checkout> archive 14df074 | tar -x -C surviving-mars-relaunched/`, one commit. Assert 26 files. An archive cannot carry untracked or ignored files, editor backups or later edits. Its own `.gitignore` comes along and stays: measured, it is the file that ignores `backup/`, `runs/`, `scratch/` and `engine/` there, and the root `*.exe` covers the helpers. T6 runs on the staged tree, the file names and the commit message before the push.

3.2 Make its scripts find themselves, and give them one state variable, `SM_STATE`: set by one identical line in each script that needs it, defaulting to the folder of O9, overridable from the environment. **Code paths come from the script's own location.** `launch-relaunched.sh` has none today: add it after `set -u` (`:67`) and derive `HELPER` (`:71`) and the two messages (`:103`, `:110`) from it; in `tools/inject-ab.sh`, the tools folder (`T` at `:12`) and the two `patch-window-origin.py` calls (`:23-24`). **State paths come from `SM_STATE`:** `RUNS` (`launch-relaunched.sh:72`), the default output of `tools/make-engine.sh:48` (its own `HERE` is defined later, at `:65`, and is `tools/`), the scratch and runs folders in `tools/inject-ab.sh:12` (`S`, `R`), `tools/steam-judge.sh:11` and `patch-window-origin.py:52`. The two header comments that say where logs go (`tools/inject-ab.sh:8`, `tools/steam-judge.sh:7`) follow. T14 checks each path, which the test files do not: none of them executes these lines.

3.3 `common/test-launch-lock.sh`: `git mv` this repo's copy, find the three launchers by relative path, exit 2 unless all three are found, drop the `$HOME` sibling loop; delete the Surviving Mars copy. The lock functions stay in the launchers until Phase 5.

3.4 `make-app.sh`: the icon tool by relative path (`:17`); the launch-time pull per O3.

| O3 | Shim | `tools/test-make-app.sh` |
|---|---|---|
| (c), recommended | the pull block and its comments (`:7-10`, `:49-66`) are removed, and the header line that names the test (`:11`) is corrected | reduced to its one case that is not about the pull, "make-app.sh builds the app" (`:40`), plus a new case that the built shim runs the launcher it was given; the other eight cases go |
| (b) | remote stays `hub`; the guard `[ -d "$REPO/.git" ]` (`:57`) becomes `git -C "$REPO" rev-parse --git-dir`, because the launcher's folder is no longer the repo root and the present guard skips the pull without a word (measured: 6 cases red with the old guard, 0 with the new) | the launcher moves into a subfolder of its throwaway repo, 5 lines |
| (a) | as (b), plus remote `origin`, a hard timer on the pull (the present 5 s bound is an ssh option and does nothing over HTTPS; an unroutable address was still hanging at 12 s), and a rewritten trust comment | as (b), plus 8 lines naming the remote, and an offline case |

3.5 Local state on the Studio: move `runs/`, `backup/` and `engine/` to the folder of O9 and the two `.exe` helpers into `surviving-mars-relaunched/tools/`; the old checkout's `scratch/` is empty and is not moved. Then re-run `make-app.sh` so the shim names the new launcher. Before the move, `git check-ignore -q surviving-mars-relaunched/tools/x.exe` passes and, only if O9 keeps state inside the game folder, so does a path under each state folder. After it, `git status --porcelain` is empty.

3.6 Docs, none of them deployed files: the Surviving Mars README (the old CS2 address at `:7`, which arrives after 2.1's sweep; the clone address; the private-remote paragraph; History; the cs2-checkout line at `:53`; per O4 the sentence at `:57-58`, reworded so that "may not be redistributed" names the engine only; and a sentence on where the checkout may not live, citing `setup.sh:14-15`); the root README's licence note gains Surviving Mars's third parties (O4); this repo's `CLAUDE.md` row for Surviving Mars and the engine path in the row above it; `GOTCHAS.md` path pointers (`:2797`, `:2844`, `:2871`, `:2926`) and the plan path at `:2851`; the evidence path in `EXPERIMENTS.md` C83; the root README index. `scripts/cell-fingerprint.sh:60` counts uncommitted files across the whole repo: scope it to the game folder, or Surviving Mars edits will show in CS2's cell records. Left alone on purpose, because "sm-patch" stays the project's name in its history: the comments in both CS2 launchers (deployed files; Phase 5 touches them), dated entries and commit hashes in `GOTCHAS.md` and `EXPERIMENTS.md`, Surviving Mars's shipped plan `docs/plans/one-wrapper-per-game.md`, name-only mentions in its scripts' comments, and the bundle identifier at `make-app.sh:104`, which is a key.

3.7 Retire, only after the exit criteria pass: the old checkout; the separate public repo (O2; deleting is James's click). The pre-publication history stays private and is never pushed.

**Exit criteria.** Working tree clean. T7: Surviving Mars's seven test files green from the new location and each `MUTANT=1` red (`test-make-engine-install.sh` runs the real engine's `wine64 --version`, so it runs on the Studio). T8 reads 24 PASS. T6 reads 0 on the staged Surviving Mars tree and, over the whole repo, only what O11 accepts. T14 passes. Under O3 (a) or (b), T9 passes. T2 reads 22 of 22. T10, one visible launch from the app on the Studio, James warned first and the MacBook's Steam closed: menu reached; the log is under the new state folder and has its `.frame-fix` companion; the old checkout's `runs/` is not recreated; the app has its icon; graceful exit with the Steam Cloud line. `git grep -n -e '~/sm-patch' -e 'HOME/sm-patch' -- '*.sh' '*.py' '*.c'` prints one line, the comment at `cities-skylines-2/launchers/launch-cs2.sh:5`; the `.md` hits are all in the dated documents 3.6 lists as left alone.

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
| T1 | `common/check-links.py`, a relative-link resolver over every tracked `.md` (written in Phase 1; fenced and inline code excluded) | 0 unresolved (baseline 0 of 107) | move `docs/patch-inventory.md` up one level in a scratch tree: 7 unresolved |
| T2 | From `cities-skylines-2/`: `cmp -s` `launchers/launch-cs2-dxmt11.sh`, `launchers/launch-cs2.sh`, `repatch.sh`, `scripts/cs2-display-profile.sh`, `scripts/patch-modconflict-badge.py` and each `patches/*.py` against its copy in `~/cs2-patch`; plus `setup.sh --check` exits 0 | 22 found, 22 identical (baseline 22 of 22) | leave `scripts/cs2-display-profile.sh` at the old root in a scratch tree: 21 found |
| T3 | CS2 gates from the new paths, counts as in Phase 1's exit criteria | all exit 0 with those counts | delete one row of `docs/images/AUDIT.md` in a scratch tree: `check-experiments.py` exits 1. Remove `cwd=REPO`: it exits 1 from `/tmp` |
| T4 | For `README.md`, `INSTALL.md`, `CLAUDE.md`, `GOTCHAS.md` and `scripts/setup.sh` at their new paths: the oldest commit that `git log --follow --format=%h` prints | it is the file's first commit from before the move (`a162423` for `README.md`, `CLAUDE.md` and `GOTCHAS.md`; `831cce6` for `INSTALL.md` and `setup.sh`). Straight after commit A each count is the old one plus 1 (34, 20, 40, 154 and 4 before); later commits add to it. `git blame` on the moved README shows more than one commit | drop `--follow`: the oldest commit printed is commit A |
| T5 | Identity gate (2.2 step 4) | every value names the project identity | a scratch clone outside the keyed paths with no repo-local include: the gate names the other identity |
| T6 | `common/check-identifiers.sh` (written in Phase 0, committed in Phase 1): reads the real identifiers from the machine at run time (Steam ID64, login and display name from a wrapper's `config/loginusers.vdf`; the account id from its `userdata/` folder, also as `[U:1:n]`; the personal GitHub login and addresses from the global git config; the short user name from `id -un`, as `/Users/<name>`; host names from `scutil` and the ssh config) plus the pattern `7656119[0-9]{10}`; scans a tree, its file names and a commit message; prints counts only | 0 hits on the staged Surviving Mars tree; on the whole repo, only the hits O11 accepts (4 files, 6 lines) | plant one literal of each class in a scratch copy: 1 hit each. (A bare 17-digit pattern is wrong: `tools/frame-fix.c:11` holds an 18-digit forum thread number) |
| T7 | Surviving Mars's seven test files from `surviving-mars-relaunched/` | each exits 0 | each file's own `MUTANT=1`: exits 1 |
| T8 | `common/test-launch-lock.sh` | 24 PASS: 21 cases and 3 parity lines | `MUTANT=1`: exits 1. Alter `acquire_lock` in one launcher of a scratch copy: a parity line differs. Remove one launcher: exits 2 |
| T9 | Under O3 (a) or (b): the shim with the launcher in a subfolder of a repo | the log's `scripts:` line says current or updated | restore the old guard: no `scripts:` line |
| T10 | Live: Surviving Mars from the app, Studio then MacBook | as in Phase 3's exit criteria | none: a live run |
| T11 | In a clone of the local checkout under `/tmp` (the public repo does not have the commits yet): the README quick start as printed with `--check` appended, and the old update path, `bash scripts/setup.sh --check` from the clone root. **Always with `--check`**: without it `setup.sh` patches the real game and rebuilds the app, even from `/tmp` | both print `setup.sh`'s first check line | leave out the `cd` in the README, or delete the forwarder: `No such file or directory` |
| T12 | A fresh session started at the repo root by James, and one subagent spawned there by the builder, each quote one line that exists only in the CS2 file and one only in the root file; `/context` lists the CS2 file | both quote both; if the CS2 file is listed twice, use the fallback of 1.4 | remove the import line: the CS2-only line is not quoted before a CS2 file is read |
| T13 | `git check-ignore -q` after the move | ignored: `cities-skylines-2/MODS-GUIDE.md`, `cities-skylines-2/logs/x`, `cities-skylines-2/scripts/x.png`, `.env`; not ignored: `cities-skylines-2/docs/images/x.png` and `x.jpg` | leave the prefix off the negation: the image is ignored |
| T14 | On the Studio after 3.5: source each path-setting line of the five Surviving Mars scripts and print what it resolves to | every code path is inside `surviving-mars-relaunched/` and exists; every state path is inside the O9 folder, whose `runs/`, `backup/` and `engine/` exist | use the wrong directory level in one `tools/` script: its code path does not exist |
| T15 | Each compatibility file names a target that exists: the forwarder, the three pointer files and the root `INSTALL.md`. After the push, each of the eight edited issue links returns its file (`gh api repos/…/contents/<path>`) | 5 of 5, then 8 of 8 | point one at a misspelt path: 4 of 5 |

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
| O4 | Licence | One MIT licence for the repo; Surviving Mars's code becomes MIT by moving in. GitHub reports this repo's licence as unrecognised today because of the note appended to `LICENSE`: move the note to the root README and rename the holder line (1.5); then extend the note to Surviving Mars's third parties and reword the Surviving Mars README's "nothing built from it may be redistributed" so it names the engine only (3.6) |
| O5 | A public tracking issue for this plan | Yes, this repo's practice for umbrella work |
| O6 | Go ahead with the rename and the index front page, given the audience in section 1? The alternative is to leave this repo's name and front page alone and start `1launcher` as a new repo for Surviving Mars and later games | Go ahead, with the mitigations in section 4. The cost that remains is a possible drop in search ranking, which nothing here can measure in advance |
| O7 | `~/cs2-patch` (153 G, in the home folder) | Out of scope; Phase 5's plan decides |
| O8 | When | Phase 1 rewrites every CS2 path, so not while other CS2 work is in flight |
| O9 | Where Surviving Mars's local state lives: saves and Steam manifests in `backup/`, logs in `runs/`, a vendor's graphics library in `engine/` | Outside the checkout, in `~/Library/Application Support/1launcher/surviving-mars-relaunched/`. Inside the game folder, a `.gitignore` would be the only thing between them and a public repo; CS2 keeps its evidence outside the repo for the same reason |
| O10 | Compatibility files at old paths: the forwarding `scripts/setup.sh`, three pointer files and a root `INSTALL.md` pointer | Keep them for now. The alternative is a cleaner root and broken links for 128 recent cloners and one upstream thread |
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
| M | Ten root `.md` files, not nine; `make-app.sh:17`, not `:16`; `--follow` counts are plus 1 straight after the move; `scratch/` is empty; the licence is not detected as MIT; the per-project trust entry; a dead `queue-s2b.sh` | several | throughout |

Rejected: adding a `--copy-only` flag to `setup.sh` (a `cmp` loop measures the same thing without touching a deploy script); pulling the lock-test merge forward into Phase 1 (it needs Surviving Mars in the tree).

### Second-pass re-check (fitted, 2026-11-08)

One agent re-read the rewritten plan against the code and re-ran the renames in a scratch clone. No blocker; every new fact it could test was true except three line references. Its fixes:

| # | Finding | Folded into |
|---|---|---|
| D1 | The new quick-start test named the old update command without `--check`, which would have run a real setup: the first blocker returning through the test table | T11 |
| D2 | The `--follow` "plus 1" holds only straight after the rename commit | T4 |
| D3 | A rehearsal cannot read the lock test's 17, and cannot run the live tests | 1.0 |
| D4 | The two check scripts had no home and no creating step | section 2, Phase 0 step 6, 1.2, T1, T6 |
| D5 | T9 was in no exit criterion; four tests were referenced by content only | Phase 1, 2 and 3 exit criteria |
| D6 | The state step sent code paths to the state folder, and its test required folders nothing creates | 3.2, T14 |
| D7 | "`git grep sm-patch` returns only…" could not pass: 59 lines exist | 3.6, Phase 3 exit |
| D8 | The wiki text was called posted; its header says draft, never submitted | Phase 0 step 5, 1.5, 2.1 |
| D9 | The licence edits had no step, and one line had three instructions | 1.5, 2.1, 3.6, O4 |
| D10 | The most-opened paths had no disposition, and the pointer files and issue edits no test | Phase 0 step 5, 1.2, T15, O10 |
| m | The pull block ends at `:66`; one of the pull test's nine cases is not about the pull, so the file is reduced, not deleted, and the count is seven under every option; the `cd` lines are `:31` and `:70`, the commands `:32` and `:71`; four more places print the setup command; `mkdir` before `git mv`; the task names the address twice; `scratch/` exists and is empty | 1.1, 1.5, 2.2, 3.4, 3.5 |

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-08 | 1 (full) | architecture + rollout · security + identity + platform facts · correctness + test plan · builder simulation | 4 agents in one batch; the builder executed Phases 1 and 3 on scratch clones and ran the gates; every blocker re-read inline | Fable 5.1 | this repo `cc66a90` (plan at `cc5d3cb`) · Surviving Mars `14df074` | build-ready-with-fixes |
| 2026-11-08 | 2 (fitted) | fold verification: each correction's normative home · every new fact · the renames re-run · read as the builder | 1 agent; its findings spot-checked inline, then folded and audited two-sided, not re-checked by a third pass | Fable 5.1 | this repo `6df9d08` · Surviving Mars `14df074` | build-ready-with-fixes |

Key paths: `scripts/setup.sh` · `scripts/make-shortcut.sh` · `scripts/check-experiments.py` · `scripts/test-launch-lock.sh` · `scripts/cell-fingerprint.sh` · `launchers/` · `.gitignore` · `LICENSE` · `README.md` · `INSTALL.md` · `CLAUDE.md` · `docs/agent-brief.md` · Surviving Mars: `launch-relaunched.sh`, `make-app.sh`, `tools/`.
