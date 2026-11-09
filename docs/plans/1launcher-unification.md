# 1launcher — one repo for every game port, games as peer folders

> **Status: Not yet triple-checked — run `check it` before build.** Written 2026-11-08.
> Tracking: none yet (opening an issue is a public post; decision O5).
> Verified against: this repo `cc66a90` · the Surviving Mars repo's public commit `14df074`.

## 0. Decisions already made (James, 2026-11-08)

| # | Decision | His words |
|---|---|---|
| D1 | One repo for all ports, neutral top level, games as peer folders | "closer to macgameports/unified/ with sub folders for cs2 and sm? It's still messy to have cs2/smr" |
| D2 | The repo is called `1launcher` | "1launcher maybe?" |
| D3 | Surviving Mars belongs in it, not in a repo of its own | "I had intended this to go in the cs2 repo" |
| D4 | The checkout lives with the other repos, not in the home folder | "I don't want it in my home directory I want it with all the other repos" |

Still open: section 8. Nothing in this plan unifies the *engines*; section 7 says why.

## 1. Where things are today (measured 2026-11-08)

| Thing | State |
|---|---|
| This repo (`macgameport/cities-skylines-2-macos`) | 218 tracked files, 503 commits, 1 branch, 0 open PRs, 10 open issues, 11 stars, 0 forks, no Pages, no git hooks. Everything is CS2 and sits at the top level: 9 root `.md` files, `archive/` (5), `docs/` (58), `launchers/` (14), `patches/` (18), `scripts/` (106), `repatch.sh` |
| `~/cs2-patch` | CS2's deploy and scratch folder, **outside the repo on purpose** (`CLAUDE.md` § Where things live). `scripts/setup.sh:20-23,105-109` copies the launcher, `repatch.sh`, `patches/*.py` and two helpers into it; the double-click CS2 app runs `~/cs2-patch/launch-cs2-dxmt11.sh`, never a repo file |
| Surviving Mars (`sm-patch`) | 26 tracked files. Public since today as its own repo with one scrubbed commit. Its checkout is in the home folder and is also its runtime: `runs/`, `backup/`, `engine/` and two built `.exe` helpers live in it, untracked, and its double-click app runs the launcher inside the checkout. A private bare repo on the Studio holds the 42 pre-publication commits; the MacBook's app pulls that repo at every launch |

The two already behave as one project:

- The launcher lock (`LOCK`, `lock_holder`, `acquire_lock`, `release_lock`) is the same code in three launchers, and `test-launch-lock.sh` is one file kept identical in both repos (its line 7 says so).
- sm-patch's `make-app.sh:16` takes its icon tool from this repo's `scripts/pe-icon.py` by a fixed path.
- This repo's `launchers/launch-cs2.sh:4-5` documents running CS2 on the engine sm-patch builds.
- Surviving Mars findings already live here: `GOTCHAS.md` (three pointers into sm-patch), `EXPERIMENTS.md` C82 and C83.

They differ in one thing this plan does **not** change: CS2 runs from deployed copies outside the repo, Surviving Mars runs from its checkout.

**What is keyed to the checkout's path** (everything a folder rename can break):

| Keyed item | Where |
|---|---|
| Project git identity: commit author and push credential | a git include keyed to this checkout's path (`CLAUDE.local.md`) |
| The interactive `gh` wrapper that selects the project account | James's shell profile, keyed to the same path |
| Claude's project memory (24 files) | a directory derived from the checkout path |
| Scheduled task `reddit-watch-cs2` | its `SKILL.md` names the path |
| `~/cs2-patch/queue-s2b.sh` | names the path |
| `scripts/test-launch-lock.sh:73` (both copies), sm-patch `make-app.sh:16` | fixed paths to the sibling checkout |
| One mention in a sibling repo (isnotus) | prose |
| All of the above again on the MacBook | not visible from the Studio; section 6 |

Not keyed to it: the CS2 app (runs `~/cs2-patch`), `setup.sh` and `check-experiments.py` (both find the repo from their own location; 37 scripts do, 1 does not).

## 2. Target

```
macgameport/1launcher            (this repo, renamed: same issues, stars and history)
├── README.md                    index: one row per game, status, link
├── CLAUDE.md                    short: layout, cross-game rules, imports the games' files
├── CONTRIBUTING.md  LICENSE  .gitignore  .gitattributes  .github/  .env.example
├── docs/plans/                  repo-level plans (this file)
├── common/                      shared code; holds only the lock test until Phase 5
├── cities-skylines-2/           everything CS2, internal layout unchanged
└── surviving-mars-relaunched/   sm-patch's 26 files, internal layout unchanged
```

Local checkout: `~/github/1launcher` on both Macs. Unchanged: `~/cs2-patch` (name, place, role), the wrappers in `~/Applications`, one wrapper per game, both engines, CS2's deploy model.

## 3. Phases

Phases 1 to 4 are built from this document. Phase 5 is an outline only and needs its own plan and check. Each phase ends green before the next starts.

### Phase 0 — preflight (no changes)

1. James answers section 8.
2. No game, Steam or launcher running on the Studio; no other Claude session open in either checkout.
3. Both repos clean and level with their remotes.
4. Outside-link inventory: list every `/blob/main/<path>` or `/tree/main/<path>` link to this repo in (a) issue and comment bodies of this repo, (b) texts posted elsewhere and kept locally (`docs/applegamingwiki-edit.md`, `~/cs2-patch/reddit-reply-*.txt`, `~/cs2-patch/bug60263-comment-2.txt`, `~/cs2-patch/community-watch/`). Measured so far: the kept texts link only the repo root. The result is the stub list for 1.3.

Exit: answers recorded in this file; inventory pasted into it.

### Phase 1 — restructure this repo in place (one commit, no rename)

1.1 `git mv` into `cities-skylines-2/`: `CLAUDE.md`, `CONFIG-TRIALS.md`, `EXPERIMENTS.md`, `GOTCHAS.md`, `INSTALL.md`, `MODS-TESTING.md`, `PLAN.md`, `README.md`, `REFERENCES.md`, `archive/`, `launchers/`, `patches/`, `scripts/`, `repatch.sh`, and `docs/` except this plan. Stay at the root: `LICENSE`, `CONTRIBUTING.md` (GitHub surfaces it from the root), `.gitignore`, `.gitattributes`, `.github/`, `.env.example`. By hand on each Mac, because they are untracked: `MODS-GUIDE.md` and `logs/` follow CS2; `.env`, `CLAUDE.local.md` and `.claude/` stay at the root.

1.2 New root `README.md`: a short index. CS2's README moves untouched, so its title and text keep the game's name.

1.3 Pointer stubs at old root paths, only for paths the Phase 0 inventory found linked from outside, plus `INSTALL.md`. A stub is three lines naming the new path. Section anchors do not survive a stub.

1.4 `CLAUDE.md`: the current file moves with CS2 unchanged, so every relative reference in it stays true. The new root `CLAUDE.md` is short: the layout, the rules that hold for every game (personal info, the identity pointer), and an `@cities-skylines-2/CLAUDE.md` import with one line saying the imported file's paths are relative to that folder. Fallback if the import does not load as expected: keep the full file at the root and prefix its repo paths instead.

1.5 What the move breaks, and the fix:

| Breaks | Fix |
|---|---|
| `.gitignore:30-31` `!docs/images/*.png` and `*.jpg` no longer match | prefix both with `cities-skylines-2/` |
| the one absolute link to a file, `…/blob/main/scripts/dxgiprobe.c` | new path |
| `scripts/test-launch-lock.sh:73` fixed sibling paths | handled in Phase 3 (the file moves to `common/`) |
| `.github/ISSUE_TEMPLATE/not-working.md`, `CONTRIBUTING.md`, the `LICENSE` holder line | wording for a multi-game repo (O4) |
| anything else that reaches the old root | found by running the gates on the moved tree, not by reading |

Not broken, by measurement: the 84 relative links between `.md` files (every doc moves together); `setup.sh` and `check-experiments.py` (own-location lookup).

1.6 Deploy check: run `cities-skylines-2/scripts/setup.sh`'s copy step into a scratch folder (`CS2_PATCH_DIR=<scratch>`) and `cmp` each file against what `~/cs2-patch` holds now.

**Exit criteria.** Working tree clean. `git log --follow` on three moved files shows their pre-move history. Gates green from the new paths: `check-experiments.py`, `test-launch-lock.sh`, `test-update-check.sh`, `test-p4-signals.sh`, `test-rosetta-preflight.sh`. Relative-link check: the count of unresolved relative links is the same before and after (T1). Every file `setup.sh` deploys is byte-identical to the deployed copy (T2). No CS2 launch is needed: no deployed byte changes, and T2 is the measurement of that.

**Rollback.** `git revert` the commit; it is renames plus the listed edits.

### Phase 2 — rename: GitHub first, then the Studio's folder

2.1 GitHub: rename the repo to `1launcher` under the project identity (`docs/agent-brief.md` § If you run `gh`). Update description and topics, keeping `cities-skylines-2`. `git remote set-url origin` on the Studio. In this repo the old address appears 42 times in 17 files: the 36 URLs get the new name (32 are issue links, which also work through the redirect); the 6 prose mentions are read one by one, because a dated sentence about the old name should stay true. ⚠ Never create a repo named `cities-skylines-2-macos` in the org again: it would capture the redirect.

2.2 The Studio's folder, in this order:

1. Make identity independent of the path: add a repo-local include of the project identity file, so the rename cannot change who commits.
2. Close every session and editor in the checkout. `mv ~/github/cs2 ~/github/1launcher`.
3. **Identity gate, before any commit or push from the new path:** `git config user.name` and `git credential fill | grep '^username='` both name the project identity.
4. James updates the two path-keyed dotfiles (the include and the `gh` wrapper); Claude's edits to them are blocked by his settings. Until he has, no bare `gh` in the new folder: pass the project config directory explicitly.
5. Claude memory: copy the 24 files from the old project directory to the one derived from the new path; update the pointer memory in the `~/cs2-patch` project; start a session in the new folder and confirm the index loads.
6. Update the path in the `reddit-watch-cs2` task and in `~/cs2-patch/queue-s2b.sh`; read the isnotus mention and fix it if it is a live pointer.

**Exit criteria.** Old address redirects for web and `git ls-remote`. Identity gate passed and recorded. A test commit pushed from the new path shows the project identity as author and as pusher when read anonymously. Memory index loads in a new session. `grep` for the old folder path in the keyed items returns nothing.

**Rollback.** GitHub rename back (the redirect then reverses). `mv` back; the repo-local include is harmless either way.

### Phase 3 — Surviving Mars comes in

3.1 Copy sm-patch's 26 tracked files at `14df074` into `surviving-mars-relaunched/`, one commit, plain files. The tree was scrubbed today; the identifier scan runs again on the staged tree before the push (T6).

3.2 Make its scripts find themselves. Five files hard-code the old checkout: `launch-relaunched.sh:71-72,103,110`, `tools/make-engine.sh:48`, `tools/inject-ab.sh:12,23-24`, `tools/steam-judge.sh:11`, `patch-window-origin.py:52`. Each derives the path from its own location instead.

3.3 `common/test-launch-lock.sh`: the one copy, finding all three launchers by relative path; both per-game copies are deleted. The lock functions themselves stay in the launchers until Phase 5.

3.4 `make-app.sh`: icon tool by relative path (`:16`). The launch-time pull per O3. Under the recommended option it pulls `origin main`, and its guard `[ -d "$REPO/.git" ]` must become `git -C "$REPO" rev-parse --git-dir`, because the launcher's folder is no longer the repo root and the present guard would skip the pull without a word. `tools/test-make-app.sh` gains that case.

3.5 Root `.gitignore`: sm-patch's entries with the folder prefix (`backup/`, `runs/`, `scratch/`, `engine/`, `tools/*.exe`).

3.6 Local state on the Studio: `mv` `runs/`, `backup/`, `engine/`, `scratch/` and the two `.exe` files from the old checkout into `surviving-mars-relaunched/` (same volume). Re-run `make-app.sh` so the app's shim names the new launcher path.

3.7 Docs: sm README (clone address, the private-remote paragraph, History), this repo's `CLAUDE.md` row for Surviving Mars, the three `GOTCHAS.md` path pointers, `launchers/launch-cs2.sh:5`, the root README index.

3.8 Retire, only after the exit criteria pass: the old checkout; the separate public repo (O2; deleting is James's click); the private bare repo stays as the archive of the 42 pre-publication commits and is never pushed anywhere.

**Exit criteria.** All eight sm test files green from the new location, and each `MUTANT=1` run red. The lock test covers three launchers and their parity. Identifier scan: 0. One visible launch of Surviving Mars from the app on the Studio, James warned first and the MacBook's Steam closed: menu reached, the launcher log's `scripts:` and Steam Cloud lines as expected, graceful exit. `git grep sm-patch` returns only mentions that are read and judged historical.

**Rollback.** Revert the commits. The old checkout still exists until the exit criteria pass; re-running its `make-app.sh` restores the app.

### Phase 4 — the MacBook, one visit

Its Surviving Mars keeps pulling the old private repo, and its CS2 keeps working through the redirect, until this phase. Then: run section 6's inventory; `git remote set-url` and pull; Phase 2.2 steps 1 to 4 for its own path; move its Surviving Mars state as in 3.6 and re-run `make-app.sh`; remove its old checkout. No Claude auto-memory is written there (global rule).

Exit: identity gate passed there; both games launched once from their apps.

### Phase 5 — shared launcher core (outline only)

Candidates, by measurement: the lock (identical three times), Steam attribution by open files (`steam_exe_up`, `steam_family`), sign-in and licence wait, the update check (each game has a `test-update-check.sh`), graceful Steam stop, the cloud verdict (Surviving Mars only today), the app builders (`make-app.sh` was modelled on `make-steam-shortcut.sh`), `pe-icon.py`, the engine builders. Its plan must answer: how a shared file reaches CS2's deployed copies in `~/cs2-patch`, given the rule never to edit a launcher in place; what the per-game config holds; and whether the two run models merge.

## 4. Who notices what

| Audience | Effect | Mitigation |
|---|---|---|
| Visitors with the old address | Redirected. Root shows an index, CS2 one click away | CS2 README unchanged in its folder; stubs per 1.3 |
| Deep links from outside | A link to a moved file on `main` breaks unless stubbed; links pinned to a commit keep working | Phase 0 inventory |
| Search | The repo name no longer contains the game's name | Description and topics keep it (O6) |
| James's Macs | The keyed items in section 1 | Phases 2 and 4 |
| Claude sessions | Memory directory and one scheduled task follow the path | 2.2 steps 5 and 6 |

## 5. Test plan

| # | Test | Passes when | Mutant, applied and seen red |
|---|---|---|---|
| T1 | Relative-link resolver over every tracked `.md` | unresolved count after Phase 1 equals the count before | move one doc out of its folder in a scratch tree: count rises |
| T2 | `setup.sh` copy step into a scratch folder, `cmp` against `~/cs2-patch` | every deployed file identical | change one byte of a launcher in the scratch tree: `cmp` fails |
| T3 | CS2 gates from the new paths (list in Phase 1) | all exit 0 | delete one row of `docs/images/AUDIT.md` in a scratch tree: `check-experiments.py` fails |
| T4 | `git log --follow` on three moved files | commit counts equal the pre-move counts | none: a read |
| T5 | Identity gate (2.2 step 3) | both values name the project identity | a scratch clone outside the keyed path with no repo-local include: the gate reports the other identity |
| T6 | Identifier scan of the staged Surviving Mars tree: the account's real identifiers read from the machine, counts only | 0 hits | plant a 17-digit ID in a scratch copy: 1 hit |
| T7 | The eight sm test files from `surviving-mars-relaunched/` | each exits 0 | each file's own `MUTANT=1`: exits 1 |
| T8 | `common/test-launch-lock.sh` | three launchers, parity same | alter one launcher's `acquire_lock` in a scratch copy: parity differs |
| T9 | `make-app.sh` shim from a subfolder of a repo | the log's `scripts:` line says current or updated | restore the `[ -d "$REPO/.git" ]` guard: no `scripts:` line |
| T10 | Live: Surviving Mars launched from the app, Studio then MacBook | menu, cloud line, graceful exit | none: a live run |

## 6. MacBook inventory (run there, paste the output into this file)

Where the two checkouts are; `git -C <each> remote -v` and `status -sb`; `git -C <each> config user.name`; the `SCRIPT=` line of each game's app shim; whether `~/cs2-patch` exists there and its launcher's date; any scheduled task or shell profile line naming either path.

## 7. Not in this plan: one engine

Measured on 2026-11-07: Surviving Mars is DirectX 12 only and needs D3DMetal 3.0; D3DMetal 3.0 does not run on this repo's Wine 11.16 engine (`EXPERIMENTS.md` C83); CS2 on Wine 10 with D3DMetal 3.0 reaches the main menu, with a loaded city, performance and long sessions untested (C82), and that engine is not the free route this repo documents. So the repo, the layout and later the launcher code unify; the engine stays a per-game choice until a loaded-city run on a shared engine says otherwise.

## 8. Open decisions (James)

| # | Question | Recommendation |
|---|---|---|
| O1 | Game folder names | `cities-skylines-2/` and `surviving-mars-relaunched/`: a visitor reads them first. Short forms (`cs2/`, `sm/`) are the alternative |
| O2 | The separate Surviving Mars repo published today | Make it private now; delete it when Phase 3 passes |
| O3 | Surviving Mars's launch-time pull once it lives here | (a) pull this repo's `origin main`: one remote, the feature stays, and a stolen GitHub token would then mean code running at the next launch rather than at the next manual pull. (b) a private remote for this repo, pushed alongside: the old trust model, two pushes. (c) no pull at launch, as CS2 works today. Recommended: (a) |
| O4 | Licence | One MIT licence for the repo, holder line renamed; Surviving Mars's code becomes MIT by moving in |
| O5 | A public tracking issue for this plan | Yes, this repo's practice for umbrella work |
| O6 | The repo name loses the game's name | Accept; description and topics carry it |
| O7 | `~/cs2-patch` (153 G, in the home folder) | Out of scope; Phase 5's plan decides |
| O8 | When | Phase 1 rewrites every CS2 path, so not while other CS2 work is in flight |

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| | | | | | | |

Key paths: `scripts/setup.sh` · `scripts/check-experiments.py` · `scripts/test-launch-lock.sh` · `launchers/` · `.gitignore` · `CLAUDE.md` · `docs/agent-brief.md` · sm-patch: `launch-relaunched.sh`, `make-app.sh`, `tools/`.
