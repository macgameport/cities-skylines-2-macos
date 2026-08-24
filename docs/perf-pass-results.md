# Perf-pass results — measured table

> Protocol: [docs/plans/perf-pass.md](plans/perf-pass.md) §2. Instrument: the game's built-in
> benchmark (`-benchmark`, patch 1.5.7f1) — verified working under Wine 11.16 + DXMT 2026-08-23:
> auto-loads a bundled stress city at boot, runs ~1,994 frames, writes structured results
> (min/avg/max/p95 + full per-frame series) to `Benchmark.coc`. All readings below are **R-bench**
> (autonomous cycles via `scripts/perf-bench.sh`); raw run logs live outside the repo.

## Scene + regime facts (R-bench)

- The benchmark scene is **far heavier than the daily city** (~22 FPS vs 44.9) and is
  **predominantly CPU/sim-bound**: `gpuBoundPercent` 11.6–16.6% across runs, ~2.9 sim ticks per
  frame, CPU-game spikes to 457 ms. It stresses exactly the late-game regime.
- **Consequence — primary metric per lever class on this scene:** GPU levers are judged on
  **gpuMs avg/p95** (which responds directly) rather than averageFps (diluted when only ~15% of
  frames are GPU-bound); CPU-sim levers on **averageFps + cpuGameMs**; pacing levers on the
  frame-time stdev / 1%-low — and pacing verdicts are confirmed on the lighter daily scene, where
  the cap actually binds.

## Noise floor (M0 on the benchmark scene) — 2026-08-23/24

⚠ Caveat: these samples ran on the **current pre-pin profile** (DynamicRes=Automatic still on;
texture setting unconfirmed). They establish the working floor for tonight's cells; M0 re-runs
after the settings pin (autonomous, cheap).

| cell | avgFps | gpuMs avg / p95 | cpuMs avg / p95 | frame stdev | 1%-low FPS | load s |
|---|---|---|---|---|---|---|
| m0-baseline-1 | 22.35 | 44.3 / 65.5 | 33.5 / 48.8 | 13.5 | 15.4 | 45.7 |
| m0-baseline-2 | 21.62 | 44.2 / 61.6 | 35.1 / 51.3 | 11.7 | 16.0 | 47.0 |
| m0-baseline-3 | 22.65 | 39.3 / 52.2 | 32.7 / 45.1 | 11.8 | 16.7 | 45.4 |

**Noise floor (avgFps): max−min = 1.03 FPS ≈ 4.6% of the 22.2 mean. KEEP margin = max(floor,
1 FPS) = 1.03 FPS on this scene (≈4.7%), per plan §2.** Note gpuMs avg spread is wider
(39.3–44.3, ~11%) — GPU-lever verdicts on this scene need either a delta beyond that spread or
more samples per cell.

## Lever cells

| lever | value | load-verified? | reading (R-bench) | verdict | notes |
|---|---|---|---|---|---|
| B1 `d3d11.preferredMaxFrameRate` | 40 | ✅ `Found config env: d3d11.preferredMaxFrameRate=40` (both DLLs) | avgFps 22.75 · gpuMs 40.8/54.5 · stdev 12.8 · 1%-low 17.2 | **mechanism VERIFIED · effect here DEAD (expected)** | The cap only binds on frames faster than 25 ms; this scene averages ~44 ms GPU, so a null avgFps result is the *predicted* outcome (plan §3B). 1%-low was the best of all four runs — consistent with mild tail-smoothing, but within noise. Pacing judgment happens on the daily scene per plan; the cell's real yield is proving the DXMT_CONFIG → load-verify → measure chain end to end. |

## Cycle mechanics (measured)

One autonomous cycle ≈ 5–6 min: Steam cold start + 45 s licence + boot + 45 s benchmark load +
~90 s run + teardown (SIGTERM at idle menu exits cleanly; launcher then shuts Steam down
gracefully). Chain of three ran unattended, zero failures.

## Next cells (blocked on a 30-second settings visit)

1. **Pin DynamicRes Off** (Options → Graphics) → re-run M0 ×3 (autonomous) → clean floor.
2. Confirm/record the texture-quality state the baseline ran at.
3. Then: A1 (in-game 720p) needs a resolution change in Options; A2/A3 add the MetalFX env on
   top (autonomous once the resolution is set).
