# Claude Instructions — macOS game ports, one folder per game

One repository, one folder per game. Each game keeps its own `CLAUDE.md`; the rules in this file hold
for all of them. Personal-tier project: **no phases, no SPEC.md**; GitHub Issues are enabled and used
for umbrella work.

## Layout

| Path | What |
|---|---|
| `cities-skylines-2/` | Cities: Skylines II: notes, patches, launchers, and its own `CLAUDE.md`, `GOTCHAS.md`, `EXPERIMENTS.md` and `docs/` |
| `common/` | checks shared by every game: `check-links.py`, `check-identifiers.sh` |
| `docs/plans/` | repo-level plans. A game's own plans are in `<game>/docs/plans/`, so a plan audit must look in both |
| `scripts/` | compatibility only: a forwarding `setup.sh` and pointer files at paths that older clones and outside links still use. Nothing new goes here |

In progress: `docs/plans/1launcher-unification.md` (the rename to `1launcher`, and Surviving Mars joining as a second folder). Planned, not started: `docs/plans/local-files-layout.md` (moving `~/cs2-patch` and the build trees into `~/Library`).

**A new game is a new folder in this repo:** never a new repo, never a new folder in the home directory.
The only places outside the repo are `~/cs2-patch` (deployed copies and evidence), the wrappers in
`~/Applications`, and each game's state folder under `~/Library/Application Support/1launcher/`. Anything
else outside needs James's say-so first, and a line here saying where it is and why.

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
  2026-08-30 and are clean.
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
[#6](https://github.com/macgameport/cities-skylines-2-macos/issues/6) — comment accuracy in the
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
