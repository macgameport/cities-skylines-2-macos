# The deep performance pass — squeeze the promoted 11.16 stack

> **Status: DRAFT — not yet triple-checked. Run `check it` before executing.**
> Tracking: PLAN.md § "Performance: the deep optimization pass" (personal-tier repo, no issue tracker).

James, 2026-08-23: *"take a deep hard look at optimizing efficiency"* — serious token budget
approved, and the goal restated at kickoff: **make the experience awesome, squeeze every
performance drop out of each setting we uncover, and codify this as our ethos.** This doc is both
the plan and the codification.

## 0. The ethos

These are the standing principles for all performance work on this stack. They were earned here
(the ledger has the receipts) and they outlive this pass:

1. **Measure, then move.** No lever is touched without a baseline number, and no lever is kept
   without a delta. A change that "feels faster" but doesn't move the HUD is reverted. The unit of
   progress is a row in the results table, not a config edit.
2. **One variable at a time.** Every run changes exactly one lever against the fixed scene. Two
   levers changed together produce a number that belongs to neither (the refresh-rate/
   CaptureDisplays confound in GOTCHAS is the cautionary tale — we had to keep both forever
   because we couldn't attribute the fix).
3. **Judge runs by timestamp.** Only a run whose logs postdate the change tests the change. Never
   conclude — and especially never *revert* — off a stale run. (Standing async discipline;
   the launcher change-then-old-log trap.)
4. **The experience is the target, not the peak number.** Smoothness beats a higher average:
   frame-time consistency, no hitching, no input lag, stable presentation (Direct, not
   Composited). A lever that adds 2 FPS but introduces judder or artifacts loses. The HUD's
   GPU-ms spread matters as much as the FPS line.
5. **Free wins before visual trades.** Exhaust the levers that cost nothing visually (host env,
   DXMT config, scheduling) before spending image quality. When quality is spent, spend it where
   the eye doesn't notice at city scale.
6. **Negative results are results.** Game Mode: measured Off, closed. `dxgi.handleAltTab`:
   structurally inert, proven. Each dead lever gets recorded so no future session re-derives it.
   A pass that closes five levers as "no effect, don't revisit" has produced real value.
7. **Every change has a one-line revert.** Env vars revert by unsetting; in-game settings revert
   in the menu; anything that edits a file on disk (boot.config) needs its revert path written
   down *before* the edit, same as the binary patches.
8. **A harness that prints a conclusion it didn't compute is a liability.** (GOTCHAS,
   measurement-bugs section.) The results table records what the HUD showed, not what the row
   was expected to show.

## 1. Measured facts — the starting position (do not re-derive)

| Fact | Value | Source |
|---|---|---|
| Stack | self-built stock Wine 11.16 + DXMT (PK fork v0.80-17-g79f6279), 10 patches | PLAN.md, build plan |
| Baseline FPS | **44.86** (was 42.7 on wine 11.0) | V3, ledger 2026-08-23 |
| GPU frame time | **23.1 ms** (was 25.9–26.6) | V3 |
| Bound | **GPU-bound** at baseline settings (GPU ms ≥ frame interval) | Metal HUD, ledger |
| Presentation | **Direct** (was Composited on 11.0) | V-session |
| Baseline settings | 1080p@120Hz · Global=Custom · DynamicRes=Automatic · AA=Low SMAA · Clouds=Med · Fog=on · Volumetrics=Low · AO=Med · GI=Off · Reflections=Med · DoF=Off · MotionBlur=Off · Shadows=Low · Terrain/Water/LOD/Texture=Med | V3 row, ledger |
| Settings progression on record | 34 → ~40 fps (+18%) via Volumetrics Low + Shadows Low → 42.7 | ledger |
| Game Mode | **Off even in exclusive fullscreen — closed, negative** | V5 |
| Refresh rate | game MUST run 120 Hz to match the DELL U2424H or a mode change blanks display 2 | GOTCHAS |
| `dxgi.handleAltTab` | structurally inert for CS2 (needs !minimized; CS2 self-minimizes) | ledger 2026-08-22 |
| `CS2_METALFX=1` | wired in launcher, **never tested** | launcher |
| CrossOver parity reference | ~35 fps (M3 Pro, AppleGamingWiki) | PLAN.md |

## 2. Measurement protocol (the harness for every row)

**Fixed scene:** one city save, one camera position, defined once in the results file header
(save name + a screenshot of the camera framing so it's re-findable). Same time-of-day in game.
Two readings per run:

- **R-paused** — simulation paused: isolates pure render cost. Primary number for GPU levers.
- **R-running** — simulation at 1× for ≥60 s after load settles: the real experience. Primary
  number for CPU/scheduling levers and the number that goes in the README.

**Instrument:** `CS2_HUD=1` (Metal HUD: FPS, GPU ms; DXMT stat lines: encode/commit breakdown).
Read for ≥30 s per reading, record min/typ/max, not a glance.

**Run discipline:** one lever per launch · log timestamps must postdate the change · a run that
crashes or shows artifacts records that as its result. Every row in the results table:
`lever | value | R-paused FPS + GPU ms | R-running FPS + GPU ms | verdict (KEEP / REVERT / TRADE) | notes`.

**M0 — noise floor first.** Before any lever: run the identical baseline **twice** (separate
launches). The spread between them is the noise floor; a lever must beat it to earn KEEP. Expected
~±1 FPS; if it's bigger, fix the protocol (longer settle, stricter camera) before proceeding.

**Results land in `docs/perf-pass-results.md`** (created at execution start; the table IS the
deliverable — README gets the summary, AppleGamingWiki draft gets the final numbers).

## 3. Lever matrix

> Populated from the four-domain research fan-out (DXMT source · CS2 settings · Wine/macOS host ·
> Unity boot.config). Each lever carries: mechanism, expected effect on a GPU-bound stack,
> risk, and confidence. ⏳ RESEARCH IN FLIGHT — this section is folded when it returns.

### 3A. Free wins — no visual cost (Phase P1)

⏳ pending research fold

### 3B. DXMT tunables (Phase P2)

⏳ pending research fold

### 3C. In-game settings — visual trades (Phase P3)

⏳ pending research fold

### 3D. Unity boot.config + player args — riskier, boot-path (Phase P4)

⏳ pending research fold

### 3E. Closed / out of scope

- Game Mode (measured negative), `dxgi.handleAltTab` (structurally inert).
- Rebuilding DXMT from source (LLVM-15 burden), alternative translation layers, Rosetta-level
  experiments — until measurement justifies them.

## 4. Phases

| Phase | What | Gate to next |
|---|---|---|
| **P0** | Create `docs/perf-pass-results.md`, define the fixed scene, run M0 noise floor | noise floor recorded |
| **P1** | Free wins: host env + scheduling levers, one per launch | all 3A rows measured |
| **P2** | DXMT tunables incl. the untested `CS2_METALFX=1` | all 3B rows measured |
| **P3** | In-game settings matrix, one setting at a time from the baseline block | all 3C rows measured |
| **P4** | boot.config levers (backup + revert path written first) | all 3D rows measured or explicitly skipped |
| **P5** | Synthesis: the recommended profile = baseline + every KEEP; re-measure the composed profile (the levers may not compose additively); ship it | composed profile measured |

**P5 ships:** launcher defaults updated for unconditional KEEPs (with the same
override-var pattern as `CS2_HUD`) · README numbers + settings table updated · this doc's
as-built header · AppleGamingWiki draft updated · ethos section referenced from PLAN.md.

## 5. Exit criteria

1. Noise floor measured and recorded (M0).
2. Every lever in §3 has a results-table row with a verdict — measured, not reasoned.
3. The composed recommended profile is re-measured as a whole (guards against non-additive
   levers) and beats baseline by a stated margin.
4. Ship list from P5 complete; no stale numbers left in README/PLAN.
5. Anything discovered that is a *defect* (not a tuning) gets its own ledger entry and, if
   upstream-worthy, a note against dxmt#206 / the wiki draft.

## 6. Rollback

Everything in P1–P3 reverts by unsetting an env var or re-selecting the old value in Options →
Graphics (never by editing `Settings.coc` — GOTCHAS). P4 (boot.config) requires: copy the file to
`boot.config.bak` beside it before the first edit; revert = copy back. A game update may rewrite
boot.config — if P4 produces a KEEP, it joins the repatch/relaunch check the same way the binary
patches did.

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | not yet checked |

Key paths: `~/cs2-patch/launch-cs2-dxmt11.sh` · `scripts/build-engine-1116.sh` ·
`docs/plans/build-wine1116-dxmt-engine.md` · `GOTCHAS.md` · game `boot.config`.
