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

⚠ Caveat: these samples ran on the **pre-pin profile** (DynamicRes=Automatic still on). Settings
confirmed by screenshot 2026-08-24 09:29 (after James's pin): Global=Custom ·
**DynamicRes=Disabled (pinned)** · AA=Low SMAA · Clouds=Med · Fog=on · Volumetrics=Low · AO=Med ·
GI=Off · **Reflections=Low** (drifted from the V3 block's "Med" at some point — one more reason
the clean re-baseline matters) · DoF=Off · MotionBlur=Off · Shadows=Low · Terrain/Water/LOD=Med ·
**Texture=Med**. The `m0-clean-*` rows below are the authoritative floor; the Benchmark tab also
exists in Options (menu entry confirmed).

| cell | avgFps | gpuMs avg / p95 | cpuMs avg / p95 | frame stdev | 1%-low FPS | load s |
|---|---|---|---|---|---|---|
| m0-baseline-1 | 22.35 | 44.3 / 65.5 | 33.5 / 48.8 | 13.5 | 15.4 | 45.7 |
| m0-baseline-2 | 21.62 | 44.2 / 61.6 | 35.1 / 51.3 | 11.7 | 16.0 | 47.0 |
| m0-baseline-3 | 22.65 | 39.3 / 52.2 | 32.7 / 45.1 | 11.8 | 16.7 | 45.4 |

**Noise floor (avgFps): max−min = 1.03 FPS ≈ 4.6% of the 22.2 mean. KEEP margin = max(floor,
1 FPS) = 1.03 FPS on this scene (≈4.7%), per plan §2.** Note gpuMs avg spread is wider
(39.3–44.3, ~11%) — GPU-lever verdicts on this scene need either a delta beyond that spread or
more samples per cell.

## Instrument validation (plan §2 cell) — RESOLVED 2026-08-24

One probe cycle with `MTL_HUD_LOGGING_ENABLED=1` + `MTL_HUD_PATH=<dir>` set: the path dir stayed
**empty** and the unified log shows **zero** `metal-HUD` samples — Apple's HUD post-hoc logging
is **dead under Wine on macOS 26** (the check pass's binary-scan lens was right; the tech-talk
documentation does not apply here). Verdict: **the benchmark's own per-frame series is the
primary stats instrument** (strictly better anyway); daily-scene readings fall back to
HUD-eyeball min/typ/max over the fixed window, stated per row. The probe's benchmark result
(22.68 avgFps, gpuMs 41.6) sits inside the floor band — the HUD vars don't perturb measurements.

## Lever cells

| lever | value | load-verified? | reading (R-bench) | verdict | notes |
|---|---|---|---|---|---|
| B1 `d3d11.preferredMaxFrameRate` | 40 | ✅ `Found config env: d3d11.preferredMaxFrameRate=40` (both DLLs) | avgFps 22.75 · gpuMs 40.8/54.5 · stdev 12.8 · 1%-low 17.2 | **mechanism VERIFIED · effect here DEAD (expected)** | The cap only binds on frames faster than 25 ms; this scene averages ~44 ms GPU, so a null avgFps result is the *predicted* outcome (plan §3B). 1%-low was the best of all four runs — consistent with mild tail-smoothing, but within noise. Pacing judgment happens on the daily scene per plan; the cell's real yield is proving the DXMT_CONFIG → load-verify → measure chain end to end. |

## Cycle mechanics (measured)

One autonomous cycle ≈ 5–6 min: Steam cold start + 45 s licence + boot + 45 s benchmark load +
~90 s run + teardown (SIGTERM at idle menu exits cleanly; launcher then shuts Steam down
gracefully). Chain of three ran unattended, zero failures.

## Resolution-lever family (§3A + C1) — ADJUDICATED LIVE 2026-08-24, family closed

James ran the whole quality/FPS trade himself in one morning session (live HUD + eyeballs; exact
per-view FPS numbers are scene-dependent and not comparable to R-bench rows). Mechanism findings
first — all measured, all new for this stack:

1. **Fullscreen Windowed locks the backbuffer to desktop resolution.** The in-game Screen
   Resolution dropdown is INERT in borderless: 1280×720 saved to Settings.coc, confirmed across
   a relaunch, HUD input res stayed 1920×1080. Unity-standard borderless behavior, now verified
   under Wine/DXMT.
2. **Therefore the MetalFX spatial swapchain is unusable in borderless** — the input resolution
   can never drop below desktop res, so the only reachable configs are supersampling (input
   1080p → 1620p target: measured live — softer AND slower; the factor trap in its display-mode
   form). MetalFX itself WORKS (HUD `Scaling: Spatial` + input/target lines confirmed) — the
   route dies on display-mode grounds, not DXMT grounds.
3. **Street names are world-rendered (painted on roads), not UI-layer text** — every scaling
   route softens them. This killed the "DRS keeps text sharp" hypothesis for the one text class
   that matters most in play.
4. **DRS Constant defaults to 50% scale** (`minScale: 0.5`, filter `EdgeAdaptiveScaling` in
   Settings.coc) — the scale control only appears with DRS=Constant + SHOW ADVANCED.

Verdicts (James as TRADE judge):

| Config | Look | Verdict |
|---|---|---|
| Native 1080p, Low SMAA | sharp, "a bit jagged" edges | superseded by AA bump |
| 720p / 900p nearest-neighbor stretch | "not as good" / "ok, not great" | REVERT |
| MetalFX supersample (1080→1620, borderless-forced) | soft, unreadable street text | REVERT |
| DRS Constant @ default 50% | "looks bad" at ~50 FPS | REVERT |
| **Native 1080p + High SMAA (+ outline MSAA8x), DRS Disabled** | **"looks good"** | **KEEP — the daily driver** |
| DRS Constant @ 75–80% (slider) | untried | OPEN — optional FPS-back dial |

**Current daily config on record:** 1920×1080 Fullscreen Windowed @120Hz · DRS Disabled ·
**AA High SMAA** (up from Low — the one quality *spend* of the day) · VSync on · max frame
latency 2 · rest of the settings block unchanged. Benchmark cells for this config: pending the
next idle window (nothing auto-arms — post-collision protocol).

Also visually confirmed from the Options screens: the **max-frame-latency slider exists** (B2
live, set 2) · the **DLSS upscaler entry is present but greyed** on Apple GPU (A4 gating seen in
the UI) · **VSync-on doesn't bind** at sub-40 FPS on a 120 Hz panel (kept on, consistent across
cells).

## The autonomous settings series (P2 matrix) — 2026-08-24, 9 cells, zero human input

**Method unlock first:** a controlled experiment proved complete value edits to `Settings.coc`
are honored by the game (functional proof: edited `minScale` 0.75→0.5 → benchmark gpuMs dropped
−17%, file persisted, config restored byte-for-byte; GOTCHAS refined — the old trap is *partial*
flips). That made the whole settings matrix autonomous: per cell, backup → unique-anchor regex
edit → benchmark cycle → persistence check → restore (`~/cs2-patch/perf-runs/settings-series.py`).

**Base config** (James's adjudicated finalist): 1080p Fullscreen Windowed · DRS Custom 75%
FSR1.0/EASU · High SMAA · the lean settings block. Base R-bench: **24.02 FPS · gpuMs 40.5 ·
cpuGameMs 25.9 · 1%-low 15.2**. (Beats the pre-pin 22.2 baseline while looking better.)
Noise: avgFps floor 1.03; gpuMs spread ~±2.3.

| Cell | avgFps Δ | gpuMs Δ | Verdict |
|---|---|---|---|
| s2 LOD 0.5→0.25 | **+4.74** | **−6.4** (and cpuGame −5.5!) | **WINNER — a double lever** (GPU + CPU); best 1%-lows (22.9). Cost: pop-in — **accepted** (James, 2026-08-24: "pretty solid") |
| s3 Shadows off | +3.52 | −6.4 | big/ugly; a half-res-shadows middle cell is queued for later |
| s4 Small-ticket sweep | +0.91 | −4.2 | real GPU ms, diluted on the CPU-heavy scene; marginal per visual cost |
| s5 Texture up (mipbias 1→0) | +0.43 | −3.7 | **free quality win — KEEP** |
| s6 AA High→Low SMAA | +0.23 | −4.7 | High SMAA costs ~5 gpuMs; the jaggedness fix's known price, kept |
| s1 DRS off (native) | −1.11 | +1.0 | **finalists tie within noise → sharpness is free → native wins** |
| s0 Upscale filter TAAU | −1.62 | **+9.2, p95 110 ms, 1%-low 8.0** | **LANDMINE — never use TAAU under DXMT** (temporal path pathological) |

**s7 composed** (native + High SMAA + LOD 0.25 + mipbias 0): **26.80 FPS (+11.6%) · gpuMs 35.9 ·
cpuGameMs 20.3 · 1%-low 23.59 (+55% vs base — better than the base config's *average* feel).**
Sub-additive vs the naive sum (expected; native returns DRS's savings), CPU win survives
composition. On the GPU-bound daily scene the average-FPS gain should exceed the stress-scene's.

**Recommended daily driver (CONFIRMED — James's pop-in verdict 2026-08-24: "pretty solid", accepted):** DRS **Disabled** · **High SMAA** ·
**levelOfDetail 0.25** · **mipbias 0** · everything else per the lean block. Revert = restore
any `.bak`/series-base snapshot or re-select in Options.
