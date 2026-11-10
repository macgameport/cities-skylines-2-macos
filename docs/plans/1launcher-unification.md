# 1launcher — one repo for every game port, games as peer folders

> **Status: Triple-checked 2026-11-08 — build-ready-with-fixes (pass 1, 4 lenses, 5 blockers folded;
> fitted re-check the same day, no blocker, its 10 fixes folded).** O9 was amended on 2026-11-09 for `engine/`
> and the amendment re-checked by a fitted pass the same day (third-pass block). Section 8 was answered on
> 2026-11-08 ("Ok go ahead with recs"). Phase 3 was re-checked against the renamed tree before its build by a
> fourth fitted pass on 2026-11-09 (1 blocker, folded with five other findings and a group of thirteen
> smaller ones; fourth-pass block). Phase 4 was rewritten on 2026-11-09 and re-checked the same day by a fifth
> fitted pass (1 blocker, folded with seven other findings and a group of smaller ones; fifth-pass block).
> Written 2026-11-08. Tracking: issue #22.
> **🔧 As-built (2026-11-08):** PARTIAL. Phases 0, 1 and 2 are built (Phase 2 on 2026-11-09); Phase 3 is built and its exit criteria pass (2026-11-09), with
> retirement (3.7) still to do; Phase 4 is not started.
> Phase 1 is commit `270ca2a` (211 renames at 100%, nothing else) and the commit that adds this line.
> Measured on the real checkout after both: T1 0 of 107 · T2 22 of 22 and `setup.sh --check` exit 0 ·
> T3 every gate exit 0, lock test 17 PASS, 102 files syntax-clean · T4 · T6 9 · T11 · T13 · T15 5 of 5 ·
> every mutant applied and seen red. Deviations: (1) **T12 ran on 2026-11-09 and passed**, a day after the rest: a fresh
> desktop session James started at the repo root and a headless `claude -p` run from the same place each
> quoted the CS2-only line and the root-only line without reading a file, and `/context all` listed
> `cities-skylines-2/CLAUDE.md` once (13 instruction files; 12 without the import).
> (2) The accepted identifier residual is 9 lines, not 6: the scan also counts three mentions of the
> placeholder Steam display name in `docs/images/AUDIT.md`, which is public by design; it skips a computer
> name that is only the product name, and `[U:1:0]`, Steam's logged-off id. (3) `setup.sh`'s own usage text
> (`:8-10,141`) is unchanged: it reads correctly from the game folder. (4) The community-watch task was
> switched back on after this session with its paths corrected, instead of staying off until 2.2; it must
> be disabled again before the folder is renamed. (5) The separate Surviving Mars repo is private (O2).
> (6) The nine links in this repo's own issues (the body of #1, four comments on #7, #13 and #16) were
> first refused by the session's permission layer and were edited on 2026-11-09 with James's OK: the old
> form reads 0 and the new form 9, and T15's second half reads 8 of 8. (7) GitHub now
> reports the licence as MIT. Phase 0 step 4 (the two dotfiles) was done by James on
> 2026-11-09 and read back: each file names the new path once.
> **Phase 2 (2026-11-09): built.** 2.1: the repo is `macgameport/1launcher`; the old address answers
> `git ls-remote` and its web page redirects (301); description and topics updated, the game's name kept in
> both; `1a8973f`, pushed from the old folder, changes 43 occurrences of the old name in 16 files and leaves
> three lines as written (this plan's two and the posted DXMT comment record). 2.2: repo-local include added;
> folder renamed; T5 passed from the new path, all five values the project identity, and its mutant (a
> scratch clone outside the keyed paths) named the other identity; `user.name` lists the project value from
> the path-keyed include and from the repo-local one; T2 22 of 22 and `setup.sh --check` exit 0; 24 memory
> files copied, two rewritten, the pointer note updated; a headless session started at the new path loads
> the memory index from the new project directory and both `CLAUDE.md` files; the community-watch task,
> paused for the phase, has its six lines edited and is enabled again. Deviations: (a) the move ran with one
> idle terminal session still open in the checkout, against Phase 0 step 2: it had been asked closed and
> waited on for 30 minutes, held nothing in the tree but its working directory, and had last written its
> transcript 43 minutes earlier. (b) An empty folder at the new path, made that morning by something other
> than this build, was removed with `rmdir` first. (c) The bare-`gh` half of T5 ran in a fresh interactive
> shell: the building session's tool shell carries a copy of the shell profile from before the Phase 0
> step 4 edit, so its own bare `gh` at the new path still names the other account and it keeps passing the
> project config directory. (d) The commit that adds this paragraph is the first push from the new path,
> not Phase 3's first commit, so the anonymous read-back of the author that the exit criteria ask for is
> made on this commit. (e) 2.1 counted 42 occurrences in 17 files; the tree held 45 lines in 18 files, two
> of the lines this plan's own.
> **Phase 3 (2026-11-09): built to T10.** After the fourth-pass fold (`ee9c9f4`): 3.1 is `340f4ef` (26 files,
> T6 0 on the game folder and 9 on the repo); 3.2 to 3.4 are `0e753a6`; 3.6 is `e9a6abf`. 3.5 moved `runs/`
> (91 entries) and `backup/` (4) to the Application Support folder and `engine/` to the Developer folder,
> sizes equal before and after, and the two helpers into `tools/`; `make-app.sh`, re-run from the new folder,
> built a shim that names the new launcher, pulls nothing and has its icon. Measured on the real tree: T7 seven
> of seven green, each `MUTANT=1` red; T8 24 PASS, its three mutants as written; T14 19 checks green, both
> mutants red for the reasons the row names; T1 0 unresolved; the exit `git grep` one line; T2 22 of 22;
> `check-experiments.py` exit 0. The bare `hub` repo holds the 42 private commits (`refs/archive/pre-public`),
> so 3.7 loses nothing. **T10 passed the same day:** James launched the game from the rebuilt app on the
> Studio with the MacBook's Steam closed, and it ran. The app's log shows sign-in, "saves up to date", the
> launch, exit code 0 and "saves uploaded"; the run log and its `.frame-fix` companion (one fix, at 2.7 s) are
> under the new state folder; the old checkout's `runs/` was not recreated; the app has its icon; the shim
> names the new launcher. With that every exit criterion of Phase 3 passes. Open: 3.7, retiring the old
> checkout (James's approval) and the separate GitHub repo (his click).
> Verify against: `common/` · root `scripts/` · `cities-skylines-2/scripts/check-experiments.py` ·
> `.gitignore` · `LICENSE` · root `README.md`, `INSTALL.md`, `CLAUDE.md`.
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

Local checkout: `~/github/1launcher` on both Macs. Surviving Mars's local state (`runs/`, `backup/`, `engine/`) lives outside the checkout (O9, as amended for `engine/`). Unchanged: `~/cs2-patch` (name, place, role), the wrappers in `~/Applications`, one wrapper per game, both engines, CS2's deploy model, and **every deployed CS2 byte**: no CS2 launcher, patch or helper is edited in Phases 1 to 4, so the 22-file comparison (T2) must read 22 of 22 at the end of every phase. `~/cs2-patch` moves later, under `docs/plans/local-files-layout.md`: that plan follows Phase 3, is the first to edit a deployed CS2 file, and redeploys them; from then on the 22-file comparison is that plan's LT4, read against the folder the scripts resolve.

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

3.1 `mkdir surviving-mars-relaunched && git -C <sm checkout> archive 14df074 | tar -x -C surviving-mars-relaunched/`, one commit. Assert 26 files. An archive cannot carry untracked or ignored files, editor backups or later edits. Its own `.gitignore` comes along and stays: measured, it is the file that ignores `backup/`, `runs/`, `scratch/` and `engine/` there, and the root `*.exe` covers the helpers. T6 runs on the staged tree, the file names and the commit message before the push: `bash common/check-identifiers.sh --dir surviving-mars-relaunched --message <msg>` reads 0, and `ACCEPT=9 bash common/check-identifiers.sh --cached --message <msg>` reads 9.

3.2 Make its scripts find themselves, and give them one state variable, `SM_STATE`: set by one identical line in each shell script that needs it, defaulting to O9's Application Support folder, overridable from the environment. `patch-window-origin.py` takes the same default in Python: `os.path.join(os.environ.get("SM_STATE") or os.path.expanduser("~/Library/Application Support/1launcher/surviving-mars-relaunched"), "backup")` (its `:94` already creates the folder). `tools/make-engine.sh` needs no `SM_STATE`; it gets a variable of its own, `SM_WORK`, set the same way and defaulting to `~/Library/Developer/1launcher/surviving-mars-relaunched` (O9 as amended). **Code paths come from the script's own location.** `launch-relaunched.sh` has none today: add it after `set -u` (`:67`) and derive `HELPER` (`:71`) and the two messages (`:103`, `:110`) from it; in `tools/inject-ab.sh`, the tools folder (`T` at `:12`) and the two `patch-window-origin.py` calls (`:23-24`). **State paths come from `SM_STATE`:** `RUNS` (`launch-relaunched.sh:72`), the scratch and runs folders in `tools/inject-ab.sh:12` (`S`, `R`), `tools/steam-judge.sh:11` and `patch-window-origin.py:52`; and the two scripts that write state through `$HERE`, which merged into the game folder would put saves, `userdata/<acct>` and manifests inside the public checkout: `tools/split-wrapper.sh:25-26` (`RUNS="${SPLIT_RUNS:-$SM_STATE/runs}"` and `BACKUP="${SPLIT_BACKUP:-$SM_STATE/backup/one-wrapper-…}"`; its test passes both overrides, so it is unchanged) and `tools/licence-wait-probe.sh:70` (`OUT="$SM_STATE/runs/licence-$SECS"`). Where each new line goes: `launch-relaunched.sh` after `set -u` (`:67`); `tools/inject-ab.sh` before `:12`; `tools/steam-judge.sh`, `tools/split-wrapper.sh` and `tools/licence-wait-probe.sh` after their `set -u` or `set -eu`; `SM_WORK` in `tools/make-engine.sh` after `set -eu` (`:24`), before its use at `:48`. None of the names is taken. **The engine comes from `SM_WORK`:** the default output of `tools/make-engine.sh:48` is `$SM_WORK/engine/wine-d3dm30` (the script's own `HERE` is defined later, at `:65`, and is `tools/`), and its usage line (`:3`) says so. The header comments that say where logs and backups go (`tools/inject-ab.sh:8`, `tools/steam-judge.sh:7`, `tools/split-wrapper.sh:8,13`, `tools/licence-wait-probe.sh:29`) follow. T14 checks each path, which the test files do not: none of them executes these lines.

3.3 `common/test-launch-lock.sh`: `git mv cities-skylines-2/scripts/test-launch-lock.sh common/`, find the three launchers by relative path, exit 2 unless all three are found, drop the `$HOME` sibling loop, and rewrite the header (`:2-9`), which speaks of two repos; launchers given as arguments (`:16`) still replace the list, and the exit-2 rule applies to the list it finds by itself. Delete the Surviving Mars copy. `launch-relaunched.sh:133-135`, which says the test lives in either repo, names `common/test-launch-lock.sh`. The lock functions stay in the launchers until Phase 5.

3.4 `make-app.sh`: the icon tool by relative path (`:17`); the launch-time pull per O3.

| O3 | Shim | `tools/test-make-app.sh` |
|---|---|---|
| (c), decided | the pull block and its comments (`:7-10`, `:49-66`) are removed; the header's icon note (`:5-6`) and the alert the shim shows when its launcher is missing (`:32`, which names `sm-patch/make-app.sh`) name the new places | reduced to its one case that is not about the pull, "make-app.sh builds the app" (`:40`), plus a new case: the built shim exits 0 and the log holds exactly one `LAUNCHED v1` from a fake launcher given through `SM_SCRIPT`; the other eight cases, the header (`:2-7`) and the git, `hub` and `GIT_AUTHOR` set-up go; a new mutant, below |
| (b) | remote stays `hub`; the guard `[ -d "$REPO/.git" ]` (`:57`) becomes `git -C "$REPO" rev-parse --git-dir`, because the launcher's folder is no longer the repo root and the present guard skips the pull without a word (measured: 6 cases red with the old guard, 0 with the new) | the launcher moves into a subfolder of its throwaway repo, 5 lines |
| (a) | as (b), plus remote `origin`, a hard timer on the pull (the present 5 s bound is an ssh option and does nothing over HTTPS; an unroutable address was still hanging at 12 s), and a rewritten trust comment | as (b), plus 8 lines naming the remote, and an offline case |

Under (c) the test's mutant changes: the old one edits the pull line, so against the new `make-app.sh` it prints `REFUSED: mutant did not apply` and exits 2 (measured). The new one turns the built shim's `SM_QUIET=1 bash "$SCRIPT"` line into `SM_QUIET=1 true "$SCRIPT"`, so the shim never runs the launcher: 1 FAIL, exit 1 (measured on a scratch build).

3.5 Local state on the Studio: move `runs/` and `backup/` to the `SM_STATE` folder of 3.2, `engine/` to its `SM_WORK` folder, and the two `.exe` helpers into `surviving-mars-relaunched/tools/`; the old checkout's `scratch/` is empty and is not moved. Then re-run `make-app.sh` so the shim names the new launcher. Before the move, `git check-ignore -q surviving-mars-relaunched/tools/x.exe` passes. After it, `git status --porcelain` is empty. T7 runs after the `make-app.sh` re-run: `test-game-running.sh` reads the installed shim, so before it the test would read the old, pulling one. `test-make-engine-install.sh` makes a temporary, ignored `surviving-mars-relaunched/scratch/install-test.*` that clones S734M's Wine.

3.6 Docs, none of them deployed files: the Surviving Mars README (its title, `:1`; `:7`, the old CS2 address, which 2.1's sweep could not reach because the file was not here yet, becomes a relative link to `../cities-skylines-2/README.md`, which T1 checks; the pull paragraph, `:29-33`, becomes one sentence: the app runs the scripts in this checkout and never pulls; the clone lines, `:63-64`, become `git clone https://github.com/macgameport/1launcher.git ~/github/1launcher` and `cd ~/github/1launcher/surviving-mars-relaunched`, without the `~/sm-patch` comment; `:70-72` lose the pull and the `scripts:` line and name the new `runs/`; History, `:119-124`, says the game joined this repository on its date and that its earlier history is kept privately; the `engine/` pointer at `:24`; the cs2-checkout lines, `:53-55`, become links to `../cities-skylines-2/scripts/pe-icon.py` and `../common/test-launch-lock.sh`; per O4 the sentence at `:57-58`, reworded so that "may not be redistributed" names the engine only; and a sentence on where the checkout may not live, citing `cities-skylines-2/scripts/setup.sh:14-15`); the root README's games table (`:6-8`) and path table (`:32-37`) gain Surviving Mars, and its licence note gains Surviving Mars's third parties (O4); the root `CLAUDE.md`'s Layout table (`:9-14`) and "In progress" line (`:16`) gain the game folder, and its `:3`, "Each game keeps its own `CLAUDE.md`", is reworded, since Surviving Mars arrives without one; the Surviving Mars row, `cities-skylines-2/CLAUDE.md:23` (its old address, "public since", the `hub` pull and `~/sm-patch/runs/`), and the engine path in the row above it (`:22`, which becomes `CS2_ENGINE=~/Library/Developer/1launcher/surviving-mars-relaunched/engine/wine-d3dm30`, the `SM_WORK` default of 3.2); `cities-skylines-2/GOTCHAS.md` path pointers (`:2797`, `:2844`, `:2871`, `:2926`) and the plan path at `:2851`; the evidence path in `cities-skylines-2/EXPERIMENTS.md` C83 (`:1049`); the root README index; the root `CLAUDE.md`'s list of places outside the repo (`:19-20`) gains `~/Library/Developer/1launcher/` (Surviving Mars's `engine/`: a Wine tree, kept off paths with a space) and `~/Library/Application Support/1launcher/surviving-mars-relaunched/` (its `backup/` and `runs/`: saves and logs kept out of a public repo, O9), committed before 3.5 creates them. `cities-skylines-2/scripts/cell-fingerprint.sh:60` counts uncommitted files across the whole repo: scope it to the game folder with `status --porcelain -- .`, or Surviving Mars edits will show in CS2's cell records (scratch build: 5 changed files in the game folder against 15 in the repo). Left alone on purpose, because "sm-patch" stays the project's name in its history: the comments in both CS2 launchers (deployed files; Phase 5 touches them), dated entries and commit hashes in `GOTCHAS.md` and `EXPERIMENTS.md`, Surviving Mars's shipped plan `docs/plans/one-wrapper-per-game.md`, name-only mentions in its scripts' comments, and the bundle identifier at `make-app.sh:104`, which is a key.

3.7 Retire, only after the exit criteria pass: the old checkout; the separate repo, private since Phase 1 (O2; deleting is James's click). The pre-publication history stays private and is never pushed. Keep the bare `hub` repo on the Studio: it holds the only other copy of those 42 commits, and the MacBook's app pulls from it until Phase 4.

**Exit criteria.** Working tree clean. T7, after 3.5's `make-app.sh` re-run: Surviving Mars's seven test files green from the new location and each `MUTANT=1` red (`test-make-engine-install.sh` runs the real engine's `wine64 --version`, so it runs on the Studio). T8 reads 24 PASS. T6 reads 0 on the staged Surviving Mars tree and, over the whole repo, only what O11 accepts. T14 passes. Under O3 (a) or (b), T9 passes. T2 reads 22 of 22. T10, one visible launch from the app on the Studio, James warned first and the MacBook's Steam closed: menu reached; the log is under the new state folder and has its `.frame-fix` companion; the old checkout's `runs/` is not recreated; the app has its icon; graceful exit with the Steam Cloud line. `git grep -n -e '~/sm-patch' -e 'HOME/sm-patch' -- '*.sh' '*.py' '*.c'` prints one line, the comment at `cities-skylines-2/launchers/launch-cs2.sh:5`; the `.md` hits are all in the dated documents 3.6 lists as left alone and in the two plans under `docs/plans/`.

**Rollback.** Revert the commits. The old checkout exists until the exit criteria pass; move its state and `engine/` back and re-run its `make-app.sh` (its icon stays generic: the icon tool's old path went with Phase 2).

### Phase 4 — the MacBook, one visit

Rewritten on 2026-11-09 for the tree as it now is, and re-checked the same day by a fifth fitted pass whose
findings are folded in (fifth-pass block). Since this phase was first written the
repo was renamed, Surviving Mars joined it, setup learned to check the Mac and to ship its own libraries, and
the Wine 10 fallback was retired (`docs/plans/setup-correctness-and-fallback-retirement.md`). Until this phase
the MacBook's Surviving Mars keeps pulling its private remote and its CS2 keeps working through the redirect
and its deployed copies.

**Who does it.** A session on the MacBook, with James there. That session writes no Claude auto-memory (global
rule): what is worth keeping goes into this file's as-built header, committed. It cannot see the Studio.

**Before the visit.** The setup plan's live steps have passed on the Studio (its S10 to S12), so `main` is
known to install and boot. The Studio's checkout has nothing ahead of `origin/main` (`git status -sb`), so the
script that 4.1 fetches is the tested one. The Studio's game builds, for 4.4 to compare with, read from its
own inventory on 2026-11-09: Cities: Skylines II 25127643, Surviving Mars 25579348; if a game updates on the
Studio before the visit, this line is corrected first. No game, Steam or launcher is running on either Mac,
and Steam on the Studio stays closed until 4.8 is over: one Steam on the account at a time.

4.1 **Look first.** From the MacBook's CS2 checkout, wherever it is:
`git fetch origin && git show origin/main:common/mac-inventory.sh | bash`. The fetch adds objects and remote
refs inside `.git` and changes no file in the working tree. The script is read-only, starts no Intel program,
and prints nothing that identifies an account or a computer: entries in the two dotfiles for folders of other
projects are counted, not shown. It trusts no folder it looks into: it runs git inside a checkout only when
that checkout's own settings file holds plain keys alone, pinned to that checkout's `.git` folder, and it
never runs a credential helper (`common/test-mac-inventory.sh`, T16, plants programs in such settings and
requires that none starts). Read it against section 6. Stop and ask James if it shows anything this phase does
not expect:

- a checkout with uncommitted work, or with commits that are not on origin (`[ahead N]` in its status);
- a third checkout, or a `could not look inside` line, which means a checkout could be there unseen;
- a checkout marked `NOT EXAMINED FURTHER`, which names what held it back;
- an install folder that is a symlink, or a Wine wrapper the script does not know;
- a count of Wine, Steam or game processes other than 0;
- a scheduled task or launch agent that names an old path: this phase has no step for one (2.2 step 6 was
  the Studio's);
- an old Surviving Mars checkout whose helper programs are not 2.

4.2 **The two dotfiles, by James** (Phase 0 step 4, for this Mac): the include for `~/github/1launcher/` and
the pattern in the `gh` wrapper. A session may not edit those files. Additive: nothing matches until the
folder exists. The inventory's identity lines show what is there now: the include entries for this project's
folders with the file each names, and the wrapper's patterns. The two commands assume an include that names
`~/.gitconfig-cs2` and a wrapper pattern `"$HOME/github/cs2/"*`, wherever in its line that pattern sits; if
the inventory shows another file name or another path, the same two edits are made by hand:

```bash
git config --global "includeIf.gitdir:$HOME/github/1launcher/.path" "$HOME/.gitconfig-cs2"
grep -q 'github/1launcher' ~/.zshrc || sed -i '' 's#"$HOME/github/cs2/"\*#"$HOME/github/cs2/"*|"$HOME/github/1launcher/"*#' ~/.zshrc
```

Tried on four arrangements of the wrapper's line (the old pattern first, alone, last, and with spaces around
the bar): each gains the new pattern and still parses. A `~/.zshrc` that is a symlink makes `sed -i` refuse
aloud and change nothing. A new shell, then the inventory again: it must list the new include with
`the file exists`, and the new pattern.

4.3 **The checkout.** With no change to a tracked file: `git pull` (it follows the redirect), then
`git remote set-url origin https://github.com/macgameport/1launcher.git`. A pull moves what git tracks and
leaves every other file where it was, ignored or merely untracked, so list what the restructure left at old
places:

```bash
git status --porcelain --ignored | grep '^[!?][!?]' | grep -v -e ' cities-skylines-2/' -e ' surviving-mars-relaunched/' -e ' \.env$' -e ' CLAUDE\.local\.md$' -e ' \.claude/$'
```

`MODS-GUIDE.md` and `logs/` go into `cities-skylines-2/`. Anything it prints under `archive/`, `docs/`,
`launchers/`, `patches/` or `scripts/` goes to the same path under `cities-skylines-2/`. `__pycache__` folders
are deleted. Anything else (`revenv/`, `scratchpad/`, `dumps/`) is shown to James. Move with `mv -n` and stop
if a destination exists: in the re-check's trial a plain `mv` replaced an existing `MODS-GUIDE.md` without
asking. Then `rmdir archive launchers patches 2>/dev/null` and the listing again: it prints only what James
chose to leave. `.env`, `CLAUDE.local.md` and `.claude/` stay at the root. Then Phase 2.2 steps 2 to 4 for
this Mac: the repo-local identity include, `git -C <checkout> config --local include.path "~/.gitconfig-cs2"`;
from a shell whose working directory is elsewhere, `mv <checkout> ~/github/1launcher` (if the checkout was
under `~/Documents` this is also what takes it out: an app cannot run scripts there, and Surviving Mars runs
from its checkout); then the identity gate (T5) before any commit, push or other `gh` call.

4.4 **Cities: Skylines II.** From `~/github/1launcher/cities-skylines-2`:
`bash scripts/setup.sh 2>&1 | tee /tmp/setup.out`. It checks this Mac first (Rosetta has been removed by
macOS updates twice: if it says MISSING, run the command it prints), installs the launcher, `repatch.sh`,
`cs2-display-profile.sh`, the patch scripts and `patches/_vendor` into `~/cs2-patch`, runs the ten patch
scripts, and rebuilds the app, whose shim names `~/cs2-patch/launch-cs2-dxmt11.sh`. It must print
`10 of 10 patch scripts finished without error` and `=== setup complete ===`, each once; neither is its last
line, and it prints the second only when nothing went wrong:
`grep -c -e '^10 of 10 patch scripts finished without error$' -e '^=== setup complete ===$' /tmp/setup.out`
prints 2. If it names a failed patch, stop: this Mac's game may be on a build the Studio's is not (the
inventory printed this Mac's; "Before the visit" has the Studio's), and `cities-skylines-2/GOTCHAS.md` (the
entries of 2026-11-02 to 2026-11-07) has what was found last time. The badge patch stays on here only if it
has run here; setup says which, and where it says `off (it has never run here)` it removes
`~/cs2-patch/patch-modconflict-badge.py` on purpose. Do not pass `--hide-mod-badges` to make a count come
out: that option edits `Game.dll`. Setup keeps the old launcher beside the new one as
`launch-cs2-dxmt11.sh.bak`, and leaves in `~/cs2-patch/patches` any patch script the repo no longer has, so
its `patches:` line can count more scripts than the repo holds. The retired fallback launcher and the old
Python environment `revenv` stay in `~/cs2-patch`: nothing uses them, and the rollback below needs `revenv`.
Then T2, from `~/github/1launcher/cities-skylines-2`:

```bash
found=0; same=0
for f in launchers/launch-cs2-dxmt11.sh repatch.sh scripts/cs2-display-profile.sh scripts/patch-modconflict-badge.py patches/*.py; do
  case "$f" in patches/*) d="$HOME/cs2-patch/$f" ;; *) d="$HOME/cs2-patch/$(basename "$f")" ;; esac
  [ -f "$d" ] || { echo "not installed: $f"; continue; }
  found=$((found + 1)); cmp -s "$f" "$d" && same=$((same + 1))
done
echo "$found found, $same identical"
diff -r patches/_vendor "$HOME/cs2-patch/patches/_vendor" && echo "_vendor equal"
```

It reads `21 found, 21 identical` where setup said the badge patch is on; `20 found, 20 identical`, with one
`not installed` line for the badge file, where setup said it is off; and `_vendor equal` either way.

4.5 **Surviving Mars.** Quit the game. The old checkout (the inventory says where, and what it holds outside
git; `~/sm-patch` on the Studio) has `runs/`, `backup/`, perhaps `engine/`, and two `.exe` helpers that no
repo has and that only Homebrew's `mingw-w64` can rebuild: they are moved, never left behind. The launcher
skips its click-offset fix without failing when `tools/frame-fix.exe` is missing, so a lost helper would go
unnoticed until clicks miss. The inventory must have printed `absent` for both new places. `scratch/` is not
moved: if the inventory showed it with entries, ask James. As 3.5:

```bash
S=~/sm-patch        # the old checkout, as the inventory printed it
ST="$HOME/Library/Application Support/1launcher/surviving-mars-relaunched"
WK="$HOME/Library/Developer/1launcher/surviving-mars-relaunched"
N="$HOME/github/1launcher/surviving-mars-relaunched"
git -C ~/github/1launcher check-ignore -q surviving-mars-relaunched/tools/x.exe && echo "git will ignore the helpers"
for d in runs backup engine; do [ -d "$S/$d" ] && echo "before: $d $(find "$S/$d" -type f | wc -l | tr -d ' ')"; done; ls "$S"/tools/*.exe
mkdir -p "$ST" "$WK"
for d in runs backup; do [ -d "$S/$d" ] && mv -n "$S/$d" "$ST/"; done
[ -d "$S/engine" ] && mv -n "$S/engine" "$WK/"
mv -n "$S"/tools/*.exe "$N/tools/"
for d in runs backup; do [ -d "$ST/$d" ] && echo "after: $d $(find "$ST/$d" -type f | wc -l | tr -d ' ')"; done
[ -d "$WK/engine" ] && echo "after: engine $(find "$WK/engine" -type f | wc -l | tr -d ' ')"
ls "$N/tools/frame-fix.exe"                        # must exist
git -C ~/github/1launcher status --porcelain       # must not list the helpers
bash "$N/make-app.sh"
grep -c pull "$HOME/Applications/Surviving Mars Relaunched.app/Contents/MacOS/launch"    # must print 0
```

Each `after` count equals its `before` count. `make-app.sh` needs the app not to be running; for the game's
icon it reads `Mars.exe` in `~/Applications/SurvivingMars.app`, and without it still exits 0 with a generic
icon. The rebuilt shim names the checkout's launcher and has no line that pulls.

4.6 **The tool the project no longer keeps.** If the inventory showed `patch_cohtml_license.py` in
`~/cs2-patch/old-patchers/`, James decided on 2026-11-09 that the project keeps none. Ask him in that
session, then delete that one file and note it in that folder's `README.md`, created if it is not there, as
on the Studio.

4.7 **Checks without a game.** From `cities-skylines-2/scripts/`: `test-setup.sh`, `test-repatch.sh`,
`test-launcher-notes.sh` and `test-vendor.sh`. From the repo root: `bash common/test-launch-lock.sh` and
`bash common/test-mac-inventory.sh`. From `surviving-mars-relaunched/tools/`, after 4.5 because one of them
reads the rebuilt app: `test-cloud-outcome.sh`, `test-game-running.sh`, `test-make-app.sh`,
`test-signin-sync.sh`, `test-split-wrapper.sh` and `test-update-check.sh`. Each of the twelve exits 0, and
none starts an Intel program. Surviving Mars's seventh test, `test-make-engine-install.sh`, does start one and
reads a wrapper of the Studio's: it is not run here. Then the inventory again: no app runs a launcher at an
old path.

4.8 **Both games, once each, from their apps** (visible; James starts them): Cities: Skylines II to its main
menu, then quit; Surviving Mars to its menu, then quit from the game's own menu. As T10: Surviving Mars's app
log shows sign-in, the launch, exit code 0 and the Steam Cloud upload; its run log is under the new state
folder and has its `.frame-fix` companion, which is what shows the moved helper ran; the old checkout's
`runs/` is not recreated; the app has the game's icon.

4.9 **Retire, only after 4.8.** The old Surviving Mars checkout, to the Trash, on James's word. The old-path
entries in the two dotfiles on both Macs, by James, once nothing is left at the old path:

```bash
git config --global --unset "includeIf.gitdir:$HOME/github/cs2/.path"
sed -i '' -e 's#"$HOME/github/cs2/"\* *| *##' -e 's# *| *"$HOME/github/cs2/"\*##' ~/.zshrc
grep -c 'github/cs2/"' ~/.zshrc     # must print 0
```

If the entries were keyed to another path, `--unset` exits 5 and the `sed` changes nothing, both without a
word: the two edits are then made by hand. Then the inventory a last time. The Studio's bare `sm-patch.git`
stays: once nothing pulls it, it is the archive of the private history.

4.10 **Record.** The as-built header of this file gains Phase 4, committed and pushed from the MacBook as the
project identity (the first push from there is read back anonymously and must show that identity), or the
results are given to James for the Studio's session to record.

Not in this phase: moving `~/cs2-patch` into `~/Library` on the MacBook, which is L3 of
`docs/plans/local-files-layout.md` and waits for that plan's L1 and L2.

**Exit.** The identity gate passed there. Setup printed `10 of 10` and `setup complete`. T2 reads 21 of 21
there, or 20 of 20 where setup said the badge patch is off, and `patches/_vendor` equals the checkout's. The
twelve tests of 4.7 exit 0. Both games launched once from their apps, Surviving Mars as T10. The last
inventory, after 4.9, shows: one checkout, `~/github/1launcher`; each app `runs` a path that exists and is
under neither the old Surviving Mars checkout nor an old CS2 path; `~/sm-patch: absent`; no `github/cs2` in
the include or wrapper-pattern lines; and no `patch_cohtml_license.py`.

**Rollback.** The checkout: `mv` back and `git remote set-url` back; the old address still redirects. Cities:
Skylines II: the files of the commit this Mac was on before 4.3, which the first inventory printed as HEAD:
`git -C ~/github/1launcher archive <that commit> scripts launchers repatch.sh patches | tar -x -C <an empty folder under /tmp>`,
then `bash scripts/setup.sh` in that folder (those are the paths before the restructure; after it they sit
under `cities-skylines-2/`). Tried with `1a48b0a` and stand-in patch scripts: exit 0, the old launcher back,
`patches/_vendor` left in place and unused, the badge file installed again. The old patch scripts run under
`~/cs2-patch/revenv`, which is why 4.4 leaves it. Not measured: that the game's files end byte-identical to
before, since seven of the ten patch scripts changed after that commit; Steam's Verify integrity of game
files is the sure way back to the game's own. Surviving Mars: until 4.9 the old checkout is intact apart from
what 4.5 moved out of it; move those back and run its own `make-app.sh`, whose icon stays generic because
the icon tool's old path went with 4.3. After 4.9 the way back is the Trash.

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
| T2 | From `cities-skylines-2/`: `cmp -s` `launchers/launch-cs2-dxmt11.sh`, `repatch.sh`, `scripts/cs2-display-profile.sh`, `scripts/patch-modconflict-badge.py` and each `patches/*.py` against its copy in `~/cs2-patch`; plus `setup.sh --check` exits 0. From the layout plan's L1 on this is its LT4, against the folder `common/paths.sh` resolves | With 4.4's commands, which give each copy's place in `~/cs2-patch`: `21 found, 21 identical` where setup said the badge patch is on; `20 found, 20 identical` where it said `off (it has never run here)`, because setup then removes the badge file from the install folder on purpose. Either way `patches/_vendor` equals the checkout's by `diff -r` (22 of 22 until the fallback launcher was retired on 2026-11-09) | leave `scripts/cs2-display-profile.sh` at the old root in a scratch tree: one fewer found (20, or 19 with the badge patch off) |
| T3 | CS2 gates from the new paths, counts as in Phase 1's exit criteria | all exit 0 with those counts | delete one row of `docs/images/AUDIT.md` in a scratch tree: `check-experiments.py` exits 1. Remove `cwd=REPO`: it exits 1 from `/tmp` |
| T4 | For `README.md`, `INSTALL.md`, `CLAUDE.md`, `GOTCHAS.md` and `scripts/setup.sh` at their new paths: the oldest commit that `git log --follow --format=%h` prints | it is the file's first commit from before the move (`a162423` for `README.md`, `CLAUDE.md` and `GOTCHAS.md`; `831cce6` for `INSTALL.md` and `setup.sh`). Straight after commit A each count is the old one plus 1 (34, 20, 40, 154 and 4 before); later commits add to it. `git blame` on the moved README shows more than one commit | drop `--follow`: the oldest commit printed is commit A |
| T5 | Identity gate (2.2 step 4) | every value names the project identity | a scratch clone outside the keyed paths with no repo-local include: the gate names the other identity |
| T6 | `common/check-identifiers.sh` (written in Phase 0, committed in Phase 1): reads the real identifiers from the machine at run time (Steam ID64, login and display name from a wrapper's `config/loginusers.vdf`; the account id from its `userdata/` folder, also as `[U:1:n]`; the personal GitHub login and addresses from the global git config; the short user name from `id -un`, as `/Users/<name>`; host names from `scutil` and the ssh config) plus the pattern `7656119[0-9]{10}`; scans a tree, its file names and a commit message; prints counts only | 0 hits on the Surviving Mars tree (`--dir surviving-mars-relaunched --message <msg>`); on the whole repo, only the hits O11 accepts (9 lines; run it with `ACCEPT=9`) | plant one literal of each class in a scratch copy: 1 hit each. (A bare 17-digit pattern is wrong: `tools/frame-fix.c:11` holds an 18-digit forum thread number) |
| T7 | Surviving Mars's seven test files from `surviving-mars-relaunched/` | each exits 0 | each file's own `MUTANT=1`: exits 1 |
| T8 | `common/test-launch-lock.sh` | 16 PASS: 14 cases and 2 parity lines, for two launchers (24 PASS for three, until the fallback launcher was retired on 2026-11-09; Phase 3's exit and the fourth-pass block keep the count of their day) | `MUTANT=1`: exits 1. Alter `acquire_lock` in one launcher of a scratch copy: a parity line differs. Remove one launcher: exits 2 |
| T9 | Under O3 (a) or (b): the shim with the launcher in a subfolder of a repo | the log's `scripts:` line says current or updated | restore the old guard: no `scripts:` line |
| T10 | Live: Surviving Mars from the app, Studio then MacBook | as in Phase 3's exit criteria | none: a live run |
| T11 | In a clone of the local checkout under `/tmp` (the public repo does not have the commits yet): the README quick start as printed with `--check` appended, and the old update path, `bash scripts/setup.sh --check` from the clone root. **Always with `--check`**: without it `setup.sh` patches the real game and rebuilds the app, even from `/tmp` | both print `setup.sh`'s first check line | leave out the `cd` in the README, or delete the forwarder: `No such file or directory` |
| T12 | A fresh session started at the repo root by James, and one subagent spawned there by the builder, each quote one line that exists only in the CS2 file and one only in the root file; `/context` lists the CS2 file | both quote both; if the CS2 file is listed twice, use the fallback of 1.4 | remove the import line: the CS2-only line is not quoted before a CS2 file is read |
| T13 | `git check-ignore -q` after the move | ignored: `cities-skylines-2/MODS-GUIDE.md`, `cities-skylines-2/logs/x`, `cities-skylines-2/scripts/x.png`, `.env`; not ignored: `cities-skylines-2/docs/images/x.png` and `x.jpg` | leave the prefix off the negation: the image is ignored |
| T14 | On the Studio after 3.5: source each path-setting line of the seven Surviving Mars scripts that set one (for `patch-window-origin.py`, evaluate its line in `python3`) and print what it resolves to | every code path is inside `surviving-mars-relaunched/` and exists; every state path is inside the `SM_STATE` folder, whose `runs/` and `backup/` exist; the engine default is `~/Library/Developer/1launcher/surviving-mars-relaunched/engine/wine-d3dm30`: it has no space in it, is not under the `SM_STATE` folder, exists, and its `bin/wine64 --version` prints a version | use the wrong directory level in one `tools/` script: its code path does not exist; point `tools/make-engine.sh:48` at `$SM_STATE`: the engine default has a space |
| T15 | Each compatibility file names a target that exists: the forwarder, the three pointer files and the root `INSTALL.md`. After the push, each of the eight edited issue links returns its file (`gh api repos/…/contents/<path>`) | 5 of 5, then 8 of 8 | point one at a misspelt path: 4 of 5 |
| T16 | `common/test-mac-inventory.sh`: a throwaway home folder holding sixteen checkouts that carry the project's address, twelve of them booby-trapped through their git settings, with the two dotfiles, a folder that cannot be read and a wrapper the script does not know | 54 PASS: no planted program runs; each trapped checkout is left unexamined and says why; the four honest ones are examined; the report's lines read as planted and name neither the home folder nor another project's folder; and, as a control, plain git does start every trap | `MUTANT=1` to `9`, each exits 1: six let a planted program run (every key plain, any include, an unnoticed `commondir`, nested repositories, a credential helper asked, git left to find the repository), three drop a line or name another project's folder |

## 6. MacBook inventory (run there; paste **redacted** output: home folder as `~`, accounts as project or personal)

`common/mac-inventory.sh` prints all of this, read-only and already redacted (4.1 gives the command that runs it without changing a file in the working tree). What it covers: where the checkouts are and whether any is under `~/Documents`; each one's remotes and, where its own git settings are plain, its `status -sb`; whether `git var GIT_AUTHOR_IDENT` names the project identity in each, and which settings file names the GitHub credential helper there (it must be the project's identity file alone; the helper itself is never run); what a pull left at old places, and what an old Surviving Mars checkout holds outside git; any of `~/Documents`, `~/Desktop` and `~/Downloads` it could not look inside; `whence -w gh`; the wrapper's patterns and the `includeIf` entries for this project's folders, each include with the file it names and whether that file exists (entries for other folders are counted, not shown); the `SCRIPT=` line of each game's app shim; the wrappers, the game builds in them, and any wrapper it does not know; whether `~/cs2-patch` exists there and its launcher's date; any scheduled task or launch agent naming an old path.

## 7. Not in this plan: one engine

Measured on 2026-11-07: Surviving Mars is DirectX 12 only and needs D3DMetal 3.0; D3DMetal 3.0 does not run on this repo's Wine 11.16 engine (`EXPERIMENTS.md` C83); CS2 on Wine 10 with D3DMetal 3.0 reaches the main menu, with a loaded city, performance and long sessions untested (C82), and that engine is not the free route this repo documents. So the repo, the layout and later the launcher code unify; the engine stays a per-game choice until a loaded-city run on a shared engine says otherwise.

## 8. Decisions (James)

**Decided 2026-11-08, in his words "Ok go ahead with recs": every recommendation in this table is accepted.**

| # | Question | Recommendation |
|---|---|---|
| O1 | Game folder names | `cities-skylines-2/` and `surviving-mars-relaunched/`: a visitor reads them first. Short forms (`cs2/`, `sm/`) are the alternative |
| O2 | The separate Surviving Mars repo published today | Make it private now; delete it when Phase 3 passes |
| O3 | Surviving Mars's launch-time pull once it lives here. Its own shim says the pull is acceptable only from a private repo James alone controls. Every option ends up running what is on public `main`, which is unprotected and writable with any credential of either of his identities on either Mac; `--ff-only` refuses rewritten history and authenticates nothing. They differ in the last step: **(a)** pull `origin main` at launch: one commit on public `main` runs on both Macs at the next double-click, unattended, with no diff shown. **(b)** a private remote for this repo, pushed alongside: the commit must first be pulled and pushed on the Studio. **(c)** no pull at launch: it must first be pulled by hand on that Mac, as CS2 already requires | **(c)**. It drops a feature built this morning and costs one manual pull on the MacBook. (b) keeps the feature and its rule at the price of a second remote. (a) only with a check the pulled commit must pass, which is Phase 5 work |
| O4 | Licence | One MIT licence for the repo; Surviving Mars's code becomes MIT by moving in. GitHub reports this repo's licence as unrecognised today because of the note appended to `LICENSE`: move the note to the root README and rename the holder line (1.5); then extend the note to Surviving Mars's third parties and reword the Surviving Mars README's "nothing built from it may be redistributed" so it names the engine only (3.6) |
| O5 | A public tracking issue for this plan | Yes, this repo's practice for umbrella work |
| O6 | Go ahead with the rename and the index front page, given the audience in section 1? The alternative is to leave this repo's name and front page alone and start `1launcher` as a new repo for Surviving Mars and later games | Go ahead, with the mitigations in section 4. The cost that remains is a possible drop in search ranking, which nothing here can measure in advance |
| O7 | `~/cs2-patch` (153 G, in the home folder) | Superseded 2026-11-09: it moves out of the home folder under its own plan, `docs/plans/local-files-layout.md`. Not part of this plan's phases |
| O8 | When | Phase 1 rewrites every CS2 path, so not while other CS2 work is in flight |
| O9 | Where Surviving Mars's local state lives: saves and Steam manifests in `backup/`, logs in `runs/`, a vendor's graphics library in `engine/` | Outside the checkout, in `~/Library/Application Support/1launcher/surviving-mars-relaunched/`. Inside the game folder, a `.gitignore` would be the only thing between them and a public repo; CS2 keeps its evidence outside the repo for the same reason. **Amended 2026-11-09** (`docs/plans/local-files-layout.md`, O4, "that's fine"): `engine/` goes to `~/Library/Developer/1launcher/surviving-mars-relaunched/` instead, because it is a Wine tree and that plan keeps those off paths with a space; `backup/` and `runs/` stay as written |
| O10 | Compatibility files at old paths: the forwarding `scripts/setup.sh`, three pointer files and a root `INSTALL.md` pointer | Keep them for now. The alternative is a cleaner root and broken links for 128 recent cloners and one upstream thread |
| O11 | Personal identifiers already in this repo: the personal GitHub login in four files (three kept records of upstream comments and the September hygiene plan, which lists them as an accepted residual), and an absolute home path in `scripts/run-60262-repro.sh` | Leave the accepted four; replace the home path with `$HOME` in Phase 1. As built the scan reads 9 lines: those six, plus three mentions of the placeholder Steam display name in `docs/images/AUDIT.md`, public by design |

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

### Third pass: O9 amended for `engine/` (fitted, 2026-11-09)

James accepted the layout plan's O4 ("that's fine"): Surviving Mars's `engine/` goes to `~/Library/Developer/1launcher/surviving-mars-relaunched/`, through a second variable `SM_WORK`, and `backup/` and `runs/` stay under Application Support. Seven sentences changed (section 2, 3.2, 3.5, T14, the O9 row). One agent re-read them against the Surviving Mars code and the rest of this plan: every edit true to the code, nothing stale left, no blocker. Its fixes:

| # | Finding | Folded into |
|---|---|---|
| A | The root `CLAUDE.md`'s list of places allowed outside the repo did not include the new folder, and nothing added it before 3.5 creates it | 3.6 |
| B | T14's new clause compared the script with its own variable, had no mutant, and did not assert the one property the amendment exists for, no space in the engine's path | T14 |
| C | 3.6 told the builder to update the engine path in the CS2 `CLAUDE.md` without giving the value | 3.6 |
| m | "The folder of O9" was ambiguous once O9 names two; `make-engine.sh` needs only `SM_WORK`; the rollback and Phase 4 said "state" for what are now two folders; the Surviving Mars README's `engine/` pointer (`:24`) was not on 3.6's list | 3.2, 3.5, T14, Phase 3 rollback, Phase 4, 3.6 |

Verified with it: nothing else reads the standalone engine's default place (the launcher's `SM_ENGINE` defaults to the wrapper's own engine, and the install test uses `--install`); `~/Library` and `~/Applications` are one volume, so `tools/make-engine.sh:76` still clones; `:75` creates the new parent. Not measured: that a Wine tree at the new place runs, which T14 now checks.

### Fourth pass: Phase 3 before its build (fitted, 2026-11-09)

Phases 1 and 2 were built under Phase 3 (seven commits since the third pass, among them the rename), so one agent re-read Phase 3 against the tree at `1e870f5` and Surviving Mars at `14df074`, and built 3.1 to 3.4 and 3.6 on a scratch clone, running the gates and tests that touch no Wine and no real app. Its blocker was re-read inline before folding.

| # | Finding | Folded into |
|---|---|---|
| A | **Blocker.** 3.2 listed five scripts; two more write state through `$HERE`, `tools/split-wrapper.sh:25-26` (saves, `userdata/<acct>`, manifests) and `tools/licence-wait-probe.sh:70`. Merged into the game folder they write inside the public checkout with only `.gitignore` in the way, which O9 exists to prevent, and T14, the exit `git grep` and T6 could not see it. Measured with the fix: `test-split-wrapper.sh` 31 PASS, both mutants red | 3.2, T14, the layout plan's L1 step 1.6 |
| B | Under O3 (c) the old `test-make-app.sh` mutant edits a line that is gone and exits 2, so T7 could not pass as written | 3.4 |
| C | 3.6 still expected the old CS2 address at the README's `:7` to "arrive after 2.1's sweep"; 2.1 is done and could not reach a file that was not here | 3.6 |
| D | The README's pull paragraph (`:29-33`) and run-log lines (`:70-72`) were not on 3.6's list | 3.6 |
| E | "This repo's `CLAUDE.md`" was ambiguous with two files; the row is `cities-skylines-2/CLAUDE.md:23`; the root `CLAUDE.md` Layout table, "In progress" line and `:3`, and the root README's two tables, were not listed | 3.6 |
| F | 3.7 did not say that the bare `hub` repo keeps the private history and serves the MacBook until Phase 4, and still called the separate repo public | 3.7 |
| m | `mkdir` before 3.1's `tar`; T6's exact commands; "one identical line" cannot hold in Python; 3.3's source path, header and argument rule; 3.4's lines are `:5-6` and `:32`, not `:11`; the exit `.md` clause omitted the two plans; 3.5's clause for state inside the game folder was dead; the rollback's icon note could never come true; History and the README title; `launch-relaunched.sh:133-135`; the `cities-skylines-2/` prefix on 3.6's CS2 paths; T7 runs after the `make-app.sh` re-run; Application Support joins the root `CLAUDE.md`'s list of places outside the repo beside the Developer folder (the shared rule asks for every such place) | 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, exit criteria, rollback, T6, T14 |

Measured on the scratch build: T1 0 unresolved; T6 0 on the Surviving Mars tree and 9 on the repo; T8 24 PASS, its three mutants as written; the five Surviving Mars tests it ran green and red under `MUTANT=1`; the rewritten `test-make-app.sh` green and its new mutant red; the exit `git grep` one line; T2 22 of 22. The fold itself was audited two-sided inline and is checked by the build, which runs every gate and test on the real tree, rather than by a fifth reading pass.

### Fifth pass: Phase 4 after its rewrite (fitted, 2026-11-09)

Phase 4 was rewritten after the rename, the merge and the setup plan's build, so one agent re-read it against the tree (it started at `8713363`; the inventory script moved under it to `57ebbd5`) and ran it: the pull in scratch clones of two old states, the inventory in a scratch home built as the MacBook, the dotfile commands on eight arrangements of the wrapper's function, the current `setup.sh` over a simulated old install with and without a badge backup, and 4.5's moves with `make-app.sh` pointed at scratch. It started no Wine, Steam, game or Intel program. Its blocker was re-read inline against `cities-skylines-2/scripts/setup.sh:186-188` before folding, and every command the fold adds or changes was run inline in scratch before it was written down.

| # | Finding | Folded into |
|---|---|---|
| A | **Blocker.** "T2 reads 21 of 21" cannot be met where the badge patch never ran: setup then removes the badge file from the install folder on purpose, and T2 finds 20. The one way to force 21 edits `Game.dll`. The T2 row did not say where the copies sit, and its mutant's value had become its pass value | 4.4, T2, Exit |
| B | 4.2's `sed` changed nothing, without a word, unless the old pattern was followed by a bar; 4.9's left the old pattern in place when it stood last | 4.2, 4.9 |
| C | A pull leaves every file git does not track where it was: more than the three that 4.3 named, and a plain `mv` replaced an existing guide. Found while folding: files that are untracked without being ignored are left too, so the listing takes both | 4.3 |
| D | The inventory could not show two of 4.1's stop conditions: a wrapper it did not know, and a checkout in a folder the terminal may not read | `common/mac-inventory.sh`, T16, 4.1, section 6 |
| E | 4.5 had no commands and no check that the helpers arrived, and a chain of moves would have stopped at an old checkout with no `engine/`; 4.8 asked for less than T10 | 4.5, 4.8, Exit |
| F | Phase 4 ran none of Surviving Mars's tests, though 4.5 rebuilds its app | 4.7, Exit |
| G | "The second inventory" named a run at which the old places are still there by design, and "no old path in use" is not a line the script prints | 4.7, 4.9, Exit |
| H | The MacBook session cannot see the Studio, yet has to compare game builds and to trust the script it fetches | Before the visit |
| m | T8's count; "must end" where neither line is last; what setup leaves in the install folder; the rollback's commit, command and limits; the icon after a Surviving Mars rollback; 4.1's stop list (commits not on origin, running processes, scheduled tasks, helper count); "change nothing" beside a fetch; the inventory's labels for kept files and for the old Surviving Mars checkout, and what that checkout holds outside git; the include lines now show the file each names, and entries for other projects are counted instead of shown; "other `gh` call" and the include's command; a `README.md` created if absent | T8, 4.4, Rollback, 4.1, section 6, `common/mac-inventory.sh`, 4.3, 4.6 |

While the agent ran, the inventory script also changed for three security reviews (`709b74c`, `57ebbd5`, `8975cbf`): it reads each checkout's settings file without running git inside it, runs git there only when the keys are plain and then pinned to that `.git` folder, and never runs a credential helper. T16 is its test.

Measured inline for the fold: the new 4.2 and 4.9 commands on four arrangements of the wrapper's line (new pattern present, old pattern 0 after removal, each parses); T2's commands on the Studio (21 found); 4.3's listing on a scratch clone pulled from `1a48b0a` (the six planted leftovers, one of them untracked) and on the Studio's checkout (nothing); 4.5's moves in scratch under bash and zsh with no `engine/` (counts equal, nothing left behind); the six Surviving Mars tests of 4.7 on the Studio (each exit 0); T16 (54 PASS twelve runs in a row, nine mutants red). Not measured, because only the MacBook can show it: its paths, its badge state, its game builds, and whether the Surviving Mars tests find there what they read.

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-08 | 1 (full) | architecture + rollout · security + identity + platform facts · correctness + test plan · builder simulation | 4 agents in one batch; the builder executed Phases 1 and 3 on scratch clones and ran the gates; every blocker re-read inline | Fable 5.1 | this repo `cc66a90` (plan at `cc5d3cb`) · Surviving Mars `14df074` | build-ready-with-fixes |
| 2026-11-08 | 2 (fitted) | fold verification: each correction's normative home · every new fact · the renames re-run · read as the builder | 1 agent; its findings spot-checked inline, then folded and audited two-sided, not re-checked by a third pass | Fable 5.1 | this repo `6df9d08` · Surviving Mars `14df074` | build-ready-with-fixes |
| 2026-11-09 | 3 (fitted, the O9 amendment) | the seven changed sentences against the Surviving Mars code · the rest of this plan for anything stale · consistency with the layout plan · two-sided audit | 1 agent; findings folded and audited two-sided inline | Fable 5.1 | this repo `997a91b` · Surviving Mars `14df074` | build-ready-with-fixes |
| 2026-11-09 | 4 (fitted, Phase 3 before its build) | every cite of Phase 3 in both trees · what the rename made stale · builder simulation of 3.1 to 3.4 and 3.6 on a scratch clone with the gates and the Wine-free tests run, mutants included | 1 agent; the blocker re-read inline; folded and audited two-sided inline; the build is the check of the fold | Opus 5.5 | this repo `1e870f5` (scratch build at `0e5317a`) · Surviving Mars `14df074` | build-ready-with-fixes |
| 2026-11-09 | 4b (re-read of the fourth pass's fold) | the fold of pass 4 against the tree as built, and against itself | inline: the fold was written while the session was on another model, and a fold is a judgment surface. One defect: the status line counted "12 other fixes" where the block lists five findings and thirteen smaller ones | Fable 5.2 | this repo `1840c08` | no change to the verdict |
| 2026-11-09 | 5 (fitted, Phase 4 after its rewrite) | every step of Phase 4 run in scratch: the pull from two old states · the inventory in a scratch home · the dotfile commands · setup over a simulated old install · 4.5's moves · what state each stopping point leaves · the document against itself | 1 agent; its blocker re-read inline; folded and audited two-sided inline, every added or changed command run in scratch first | Fable 5.2 | this repo `8713363` to `57ebbd5` (the fold is the commit that adds this row) | build-ready-with-fixes |

Key paths: `scripts/setup.sh` · `scripts/make-shortcut.sh` · `scripts/check-experiments.py` · `scripts/test-launch-lock.sh` · `scripts/cell-fingerprint.sh` · `launchers/` · `.gitignore` · `LICENSE` · `README.md` · `INSTALL.md` · `CLAUDE.md` · `docs/agent-brief.md` · Surviving Mars: `launch-relaunched.sh`, `make-app.sh`, `tools/` · Phase 4: `common/mac-inventory.sh`, `common/test-mac-inventory.sh`, `cities-skylines-2/scripts/setup.sh`, `cities-skylines-2/repatch.sh`.
