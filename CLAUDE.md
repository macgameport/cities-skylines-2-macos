# Claude Instructions — macOS game ports, one folder per game

One repository, one folder per game. A game may keep its own `CLAUDE.md` (Cities: Skylines II does,
Surviving Mars does not yet); the rules in this file hold for all of them. Personal-tier project: **no phases, no SPEC.md**; GitHub Issues are enabled and used
for umbrella work.

## Layout

| Path | What |
|---|---|
| `cities-skylines-2/` | Cities: Skylines II: notes, patches, launchers, and its own `CLAUDE.md`, `GOTCHAS.md`, `EXPERIMENTS.md` and `docs/` |
| `surviving-mars-relaunched/` | Surviving Mars: Relaunched: launcher, tools and tests, `README.md`, `docs/plans/`; no `CLAUDE.md` of its own. Its state is outside the repo (below) |
| `common/` | checks and tests shared by every game: `check-links.py`, `check-identifiers.sh`, `test-launch-lock.sh` (the lock code two launchers share), `mac-inventory.sh` (a read-only, redacted report of what a Mac holds of the project) and its test `test-mac-inventory.sh`, `launch-progress.swift` (the start-up progress window both apps compile) with `test-launch-progress.sh`, `test-launch-feedback.sh` (the feedback block two launchers share) and `test-launcher-parity.sh` (fails when the two launchers drift apart; it is also the table of differences kept on purpose); `launcher-window.swift` (14unch3r, the window that lists the games and starts one), `make-launcher-app.sh` (builds `14unch3r.app`; `setup.sh` runs it) and `games.tsv` (every game this repo ports), with `test-launcher-window.sh`, `test-make-launcher-app.sh` and `test-launcher-builders.sh`; `make-installer-app.sh` (builds the double-click installer app of a game and its ZIP for a release page; the app is not in the tree) with `test-make-installer-app.sh`, and `test-bootstrap.sh` (the root `install.sh`); `install-core.sh` (the shared installer: the stages every game's `scripts/install.sh` calls, read with `.` after the game's settings), `make-wrapper.sh` (makes a game's Wine wrapper from Porting Kit's two public files, the engine given as options) with `fetch.sh` (a download checked against a fixed size and sha256) and `test-make-wrapper.sh` |
| `docs/plans/` | repo-level plans. A game's own plans are in `<game>/docs/plans/`, so a plan audit must look in both |
| `docs/images/` | `14unch3r.svg`, the mark the root `README.md` shows. It is written by `launcher-window --svg`, and `test-launcher-window.sh` (W16) fails when the file and the program's output differ |
| `scripts/` | compatibility only: a forwarding `setup.sh` and pointer files at paths that older clones and outside links still use. Nothing new goes here |
| `install.sh` | the way in for a Mac with no checkout (`docs/plans/simple-install.md`, `docs/plans/shared-installer.md`): given a game's Steam app ID, it fetches the repository into a temporary folder, finds the game's folder in `common/games.tsv`, and hands over to that game's `scripts/install.sh`. Run from a checkout it uses the checkout. It has no default game |

In progress: `docs/plans/1launcher-unification.md` (renamed `1launcher` on 2026-11-09; Surviving Mars joined as a second folder the same day; the MacBook moved over on 2026-11-09 and 2026-11-10; shared launcher code is Phase 5) and its first Phase 5 slice, `docs/plans/launch-experience.md` (one progress window and step lines for both games, built and installed on both Macs on 2026-11-10, with the licence wait of Cities: Skylines II at 15 seconds; a banner check at the Studio itself and a capture in light mode are still to come). Built and installed on both Macs 2026-11-10, with Spotlight and the window rehearsal passed and the real games started from the window (and Spotlight on the MacBook) still to come: `docs/plans/launcher-window.md` (14unch3r, one app whose window lists the games; the Steam app becomes `S734M`). Built 2026-11-10, all five live steps passed on both Macs: `docs/plans/launcher-window-look.md` (the window as desktop icons over a dark background with the mark, the mark as the icon and on the README, and a Desktop shortcut that setup offers). Planned, not started: `docs/plans/local-files-layout.md` (moving `~/cs2-patch` and the build trees into `~/Library`). Checked 2026-11-11 (build-ready-with-fixes, two passes folded, all ten decisions made), not started: `docs/plans/surviving-mars-install.md` (Surviving Mars from nothing and without CrossOver, on one installer shared by both games; its probes ML1 and ML2 are done: at ML2, on 2026-11-13, a wrapper made from nothing with the public D3DMetal 3.0 pieces ran the game, and what it found besides is the plan's section 5a, not checked and not built; ML3 comes before any code). Split out of it the same day, and built first: `docs/plans/shared-installer.md` (the installer of `simple-install` made a shared core with per-game settings, and what is published named by Steam app ID instead of folder; checked 2026-11-11, and its steps S1 to S3 built the same day on the branch `simple-install`, which holds the code and the plan's as-built header; its live step SL1 passed the same day, and what that run showed a new player would meet is the plan's section 9, not built; SL2, the installer plan's NL2, ran on 2026-11-12 and met its pass condition, with one finding: the first approval with Open Anyway was stranded by macOS and Finder then said the app was not responding, which bears on whether the app or only the pasted line is published). That branch, pushed 2026-11-11 and not merged, is also where `docs/plans/simple-install.md` is built through its first live step (NL1 and NL2 passed, NL2 with the finding above, recorded in that plan's header on the branch; its first release waits for the Surviving Mars plan's ML4).

**Published addresses.** Every pasted installer line and every installer app that has been published fetches
`https://raw.githubusercontent.com/macgameport/1launcher/release/install.sh` and hands it a game's Steam app
ID; that script fetches this repository, finds the ID's row in `common/games.tsv`, and runs
`<that row's folder>/scripts/install.sh`. **A published thing names a game by its Steam app ID and never by
its folder**, so a game's folder may be renamed by changing its row. So: the root `install.sh` and
`common/games.tsv` are never moved, and a row's first field never changes; the names
`macgameport` and `1launcher` are never renamed or given up (a freed name can be claimed by anyone, and every
published installer would fetch from it); the branch `release` only ever moves forward, by a deliberate
`git push origin <commit>:release` after the test suites pass on that commit and on James's word, never by
force and never by the automatic push to `main`; and installer apps are released as `installer-<n>`, created
with `--latest=false`, a tag that is never moved.

**A new game is a new folder in this repo:** never a new repo, never a new folder in the home directory.
The only places outside the repo are `~/cs2-patch` (deployed copies and evidence), the wrappers in
`~/Applications` and the apps the builders generate beside them (each game's app, `S734M.app` for the Windows
Steam and `14unch3r.app`: macOS and Spotlight look for apps there), the one preferences file of
`14unch3r.app`, `~/Library/Preferences/local.1launcher.window.plist` (the last game started: where macOS keeps
every app's preferences; agreed 2026-11-10), one alias `~/Desktop/14unch3r`, made by `setup.sh` only when
someone says yes (James asked for a Desktop shortcut on 2026-11-10; it is never written over anything), each game's state folder under `~/Library/Application Support/1launcher/` (Surviving Mars's holds
`backup/` and `runs/`: saves and logs kept out of a public repo), and each game's Wine trees under
`~/Library/Developer/1launcher/` (Surviving Mars's standalone `engine/`, and the `probe-*` folders its install plan's probes downloaded into: kept off paths with a space). Anything
else outside needs James's say-so first, and a line here saying where it is and why.

**Private mirrors.** Two source trees in the workspace hold commits no public remote has; each has a private
mirror on the maintainer's own git server. Where, and the push that keeps them level, is in the untracked
`CLAUDE.local.md`.

**Paths.** The sections below were written when Cities: Skylines II was the whole repo. A path in them,
or in a game's own file, that does not start with a folder from the table is relative to `cities-skylines-2/`.

## GitHub identity

Identity detail lives in the untracked `CLAUDE.local.md` — if that file is absent you are on a
clone or a git worktree: do not push or post until identity is set up; the `gh` invocation rule is
`cities-skylines-2/docs/agent-brief.md` § If you run `gh`.

## Personal info

Repo is intended to be publishable. Keep Steam IDs, `[U:1:<n>]` account ids, real usernames and
absolute `/Users/<name>` paths **out of committed files** — use `$HOME`, `$WINEUSER`, `<REDACTED>`.

**Test artifacts (audited 2026-08-30 — full table in `EXPERIMENTS.md` § Privacy):**

- `stdout.txt` / `windows.txt` — verified clean (only `C:\` / `Z:\` wine-internal paths). Quotable.
- `win-*.png` — Steam client windows carry the **persona name twice** (top-right, and as a nav
  item) plus the avatar. Evidence store only, **never committed unmasked**.
- `known-good.png` — a capture of whatever browser/terminal window was frontmost. **Not retained**;
  only its byte size is. It is the largest accidental-disclosure surface in the harness and its
  only datum is "the capture worked". `scripts/salvage-cells.sh` drops it automatically.
- Evidence lives in **`~/cs2-patch/evidence/`**, outside the repo, same reasoning as
  `change-ledger.txt`. `/tmp` is volatile — salvage before a reboot eats the week's evidence.
- ⚠ **Committed images are gated by [`docs/images/AUDIT.md`](cities-skylines-2/docs/images/AUDIT.md)** — a row per
  image saying what is visible, plus its sha256 prefix, enforced by `check-experiments.py`. A new
  image with no row, or one replaced since its audit, fails `button up`. All **four** were audited
  2026-08-30 and are clean. The root `docs/images/14unch3r.svg` is not a capture and has no row: it is drawn
  by the program, and W16 checks it holds no text, image, script or link.
  The two Steam captures among them are clean only because the glyph bug was active — Steam rendered
  no text, so there was no persona name to leak — and that would have expired the moment glyphs work.
- ✅ **Handled at source 2026-08-30: the Steam persona is now a generic placeholder.** The name is a
  *label*, freely editable, so this cost nothing; and it is **account-level**, so it lands in the
  native macOS Steam app and all three wine wrappers alike, protecting captures **whether or not text
  renders**. Verify it in the **native macOS app** — no wine, so the check can't be confounded by our
  own rendering bugs (and a rendered-text shot from there says nothing about wine's glyph handling).
  Don't rename back while capture work continues, and don't re-propose this — it is done.
  Not retroactive: pre-rename captures in `~/cs2-patch/evidence/` still carry the real name, which is
  precisely why that store sits outside the repo. Captures stay there unless deliberately promoted.
  Never mask: a mask you got wrong is worse than no mask.
- **Cheapest durable fix:** the Steam persona name is a *label*, freely editable. Set it to
  something generic while doing capture work and new captures are clean at source. A mask you got
  wrong is worse than no mask, because it looks safe.

## Model tier — this repo is where the rule was earned

> The rule is now global (`.claude/rules/engineering.md` § *Escalate the model tier by SURFACE, not
> by task*), promoted 2026-09-03 after cs2 → homeOne → isnotus. The condensed evidence lives there.
> Kept here: the two in-repo instances in full, because this is where they happened, and cs2's own
> ungated surfaces.

**Instance 1 (2026-09-03).** Execution found the behavioural defects at any tier — three hunks
carrying vendor context rather than the predicted two, `assert()` baking `__LINE__` into the object
so a comment-only edit is not byte-identical, a probe leaking a running churn on its abort path,
the exact anchor a relocated hunk needs. Every one surfaced from a build, a mutant or a
byte-compare. **The gate was the reviewer.** The top tier found what no gate can reach: a plan
asserting a 131-entry unixlib table that is really 132 — its own test gate would have failed red
for the wrong reason; an install step whose `codesign` contradicted the same plan's `cmp` outcome
test; a test stating a pass condition absent from the tool's vocabulary; cites off by one after a
table grew; five nested items missed in a census. First label use:
[#6](https://github.com/macgameport/1launcher/issues/6) — comment accuracy in the
published winemac reference, where `strip-comments.py`, the object comparison and the whole C29
battery all pass while saying nothing about whether the surviving comments are TRUE.

**Instance 2 (2026-09-03).** `check it` on `exposed-edge-live-resize.md` ran six lenses at Fable
5.1, then one fitted Opus 5 agent over the *fold*. The fitted pass found a blocker no gate could
reach: a test's pass condition named the wrong band and the wrong black-threshold for a signature
measured two sections earlier, so **its mutant could never be observed red** while the exit
criteria demanded it red. Pure cross-referencing — the plan against itself.

**cs2's own ungated surfaces:** anything published upstream (wine/DXMT patches and their commit
messages — a maintainer acts on prose, and `git apply --check` says nothing about whether a comment
is true); `check it` folds; claims about Apple/wine platform behaviour drawn from a trace rather
than from docs. **Gated — cheapest tier:** ninja builds, mutants, `cmp`/byte-compares, the C29
battery, `boot-verify.sh`.

⚠ **Promoted on FIT, not on confirmation.** At promotion nothing had been reviewed under the rule
outside this repo, so its whole evidence base is the two instances above. **Do not cite the
three-repo count as three data points.** If it fails to earn its cost somewhere, demote it.

## Deliberate deviations from sibling-repo practice

- **`.claude/rules/` in `.prettierignore`** (from meritmap, declined 2026-08-26) — Python / C / shell (20 py, 17 sh, 16 c); no package.json anywhere, so prettier can never run here. The guard exists because a repo `.prettierrc` whose `printWidth` differs from the global source's default 80 makes format-on-commit fight the session-start sync forever (diagnosed in meritmap, where it had run since 2026-08-14). Adopted in bespoke-tr, isnotus and homeOne, which have a JS toolchain that could grow a `.prettierrc`. Here it would configure a tool that will never exist. **Revisit if this repo ever gains a `package.json`.**

@cities-skylines-2/CLAUDE.md
