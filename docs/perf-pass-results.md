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

## Retina series (rt-, 2026-08-26/27) — laptop panel, current daily config

> Protocol + full mechanism: [docs/plans/retina-swapchain-experiment.md](plans/retina-swapchain-experiment.md).
> Baseline = the accepted daily driver (DRS Disabled · High SMAA · LOD 0.25 · mipbias 0) on the
> **built-in panel** (no external display) — the first rt- rows ever measured there (every earlier
> row in this doc ran 1920×1080 external-era; not comparable). ⚠ The results-row `resolution`
> field reports Unity's *display-mode* view, not the swapchain (GOTCHAS § Retina mode, trap 1);
> render resolution below is from `Player.log` "Window resolution" + HUD.

| cell | render res | gpuMs avg | avgFps | 1%-low | note |
|---|---|---|---|---|---|
| rt-b0-1/2/3 | 1512×982 | 35.56 / 27.84 / 32.31 (**median 32.31**) | 29.25–31.21 | 26.3–35.0 | fresh same-panel baseline |
| rt-r0, r0-3, r0-4 | **3024×1964 native** | 36.42 / 42.11 / 34.70 (**median 36.42**) | 24.7–25.2 | ~23 | **+12.7% median gpuMs for 4× pixels** — scene is sim-bound; expect ~+4 ms absolute on GPU-bound daily play |
| rt-r0-2 | 1920×1200 (saved-res latch) | 33.52 | 26.59 | — | accidental curve point (GOTCHAS trap 2) |
| rt-profile-mobile | **3024×1964 native + DRS 0.5 + CAS** | 36.50 | 24.73 | 22.53 | **the shipped MOBILE profile**, E2E boot through the launcher hook (2026-08-27). ⚠ 0.5's saving is invisible on this sim-bound scene — see the probe row and the live-city table |
| rt-drsprobe-025 | native + DRS **0.25** (discriminator) | **32.64** | **29.22** | **32.6** | proves DRS-by-disk is live (every metric moved far beyond repeat noise) + prices the 0.25 option |

**Live-city spot readings** (HUD, James's session 2026-08-26 — the GPU-bound regime where the
bench's sim-bound numbers understate pixel cost):

| config | GPU ms | FPS |
|---|---|---|
| 1512×982 swapchain (pre-retina daily) | 25.4 | 40.3 |
| 3024×1964 native, DRS off | 45.9 | 22.4 |
| 3024×1964 + DRS 0.5 + CAS (mobile profile) | ≈ the 1512 cost by construction (same internal pixels) — James's next session is the confirming read | ~40 expected |

| rt-home-1 | 3840×2160 (⚠ retina-doubled 1× Dell — the T10 defect) | 75.35 | 14.49 | — | first dock: RetinaMode doubles ALL displays globally, so the 1080p external rendered 4K supersampled (GOTCHAS third addendum) |
| rt-home-2 | **1920×1080 native 1:1 (the fixed HOME profile)** | **36.49** | **27.25** | 24.13 | v2 helper flips retina off pre-boot on home; all three resolution instruments agree for the first time |

**Resolution of the series (2026-08-27):** retina ADOPTED — James's in-game dropdown selection
persisted the full tuple and holds across relaunch (verified by the rt-profile-mobile boot), so
the earlier "not adopted / launcher assert" verdict is superseded. The launcher auto-asserts per
display context (`cs2-display-profile.sh` v2: **mobile = retina on + native swapchain + DRS 0.5
CAS · home/external = retina off + DRS off, true native 1:1** —
docs/plans/launcher-display-profiles.md). T10 (first dock, 2026-08-27) found and fixed the home
defect above; both configs now carry measured rows. The 2026-08-23/24 1920×1080 rows further up
ran a different quality profile and don't transfer.

## Studio series (2026-10-10) — Mac Studio M5 Max, Apple Studio Display, `home` profile

> First rows on this machine (every row above ran on the M3 Max MacBook) and on this panel. Game
> 1.6.2f1, engine wine-11.16 + DXMT, launcher `b5fb8ac`. Settings read from `Settings.coc` before
> the run = the accepted daily driver (DRS **disabled**, High SMAA, LOD 0.25, mipbias 0). Render
> resolution from `Player.log` on every cycle: `Window resolution: 2560x1440` (the results row's
> `resolution` field says 1920×1080 — GOTCHAS § Retina mode, TRAP 1). Issue #2.

| cell | avgFps | gpuMs avg / p95 | cpuGameMs | 1%-low (cpuFrame p99) | gpuBound % | load s |
|---|---|---|---|---|---|---|
| studio-home-1440-1 | 44.11 | 22.6 / 55.3 | 11.7 | 14.9 | 20.4 | 34.4 |
| studio-home-1440-2 | 47.78 | 17.4 / 22.1 | 10.5 | 41.1 | 19.6 | 31.7 |
| studio-home-1440-3 | 47.87 | 17.5 / 22.4 | 10.2 | 40.2 | 18.2 | 31.3 |

- **Cycle 1 is a warm-up outlier** (p99 67 ms vs 24 ms): first benchmark on new hardware, whose new
  Metal `pipelineCacheUUID` means shader caches rebuild (ledger 2026-10-10). Repeat spread of 2–3
  is 0.09 FPS. Quote the median of 2–3: **47.8 FPS · gpuMs 17.5 · cpuGame 10.4 · 1%-low ~41.**
- **Against the accepted daily driver** (s7 composed: 26.80 FPS · gpuMs 35.9 · cpuGame 20.3 ·
  1%-low 23.6 — M3 Max, 1920×1080): **+78 % FPS at 1.78× the pixels**, gpuMs roughly halved,
  cpuGame halved. Hardware and resolution both changed, so this is not a lever reading — it says the
  new working point is far above the one James accepted, not why.
- ⚠ **These ran with in-game VSync ON** (`"vSync": true`, as every saved base), which on a 60 Hz
  panel is a 60 FPS min-duration cap (`d3d11_swapchain.cpp:762-766`) — against the plan's
  vsync-off rule (found by the 2026-10-10 re-check). The cap can only hold numbers DOWN, so the
  verdict below stands; the rows are not a noise floor and not P3–P5 baselines (Studio M0 is).
- **Display state (added 2026-10-10 22:1x):** these three ran with the display AWAKE (user activity
  18:22:06, display on 18:22:07–18:43:20). Later rows `teardown-test-*`, `studio-m0-vsoff-warmup` and
  `studio-awake-control-vson` ran with the panel ASLEEP under a locked session (gpuBound 2–9 %,
  gpuMs 21–24) and are **VOID as measurements** — GOTCHAS § Measurement traps (locked display).
- **Verdict for #2's `home-hidpi` row: not needed for performance on this machine** — at native
  2560×1440 the scene stays sim-dominated (gpuBound 18–20 %) and every metric beats the accepted
  baseline. ⚠ The bench understates pixel cost on the GPU-bound live city (retina series: 25.4 →
  45.9 ms live for 4× pixels on the M3 Max), so the closing measurement is one live-city HUD reading
  (`CS2_HUD=1`) in James's next session.

### Studio M0 attempt 2 (2026-10-10 22:40–23:05) — unlocked, display awake, but SCREEN-SHARED

All five cycles: display awake, session unlocked, graceful WM_CLOSE exit — and a Screen Sharing viewer
connected throughout (`screensharingd` "Remote user is connected" from 22:40:00). Vsync-off was applied
before each cycle (the game writes `true` back on every graceful exit); Settings.coc restored after.

| cell | vSync | avgFps | gpuMs avg | gpuBound % | cpuGameMs | 1%-low (cpuFrame p99) |
|---|---|---|---|---|---|---|
| studio-m0-vson-control | on | 43.24 | 22.1 | 14.6 | 12.8 | 32.6 |
| studio-m0-vsoff-warmup | off | 43.56 | 22.6 | 2.8 | 11.6 | 36.8 |
| studio-m0-vsoff-1 | off | 43.32 | 20.6 | 5.9 | 11.9 | 36.3 |
| studio-m0-vsoff-2 | off | 41.22 | 26.8 | 17.5 | 14.2 | 15.6 |
| studio-m0-vsoff-3 | off | 42.68 | 22.0 | 17.4 | 13.2 | 30.7 |

- **~10 % below C75 (47.8) at the same config with the display awake** — the difference is the
  Screen Sharing stream (C75 had none: no `screensharingd` assertion 17:00–18:45). **Not a Studio
  M0**: it is a floor for the screen-shared condition only (vsync-off 1–3: 41.22–43.32, 2.1 FPS ≈ 5 %).
- **Vsync has no measurable effect here**: the vsync-on control sits inside the vsync-off spread —
  expected, a 60 FPS cap does not bind on ~23 ms frames. Whether the edit is honoured at all is still
  unproven (no effect either way to see), so P3's vsync cell needs a scene that reaches 60.
- `gpuBoundPercent` swings 2.8–17.5 % between identical vsync-off runs — **not a stable metric**; do
  not use it as a regime indicator.
- Valid M0 conditions, now recorded per row by perf-bench (`display_awake`, `locked`,
  `screen_shared`): display awake, session unlocked, **no Screen Sharing viewer**.


### Studio M0 (2026-10-12 15:20–15:52) — VALID. Floor and margins fixed (ledger C76)

Conditions, recorded per row by perf-bench: display awake, session unlocked, **no Screen Sharing**,
graceful WM_CLOSE teardown, Player.log `Window resolution: 2560x1440` on every cycle (the series
stops otherwise). Each cycle: `"vSync": false` and `"displayMode": "FullscreenWindow"` set as
complete-value edits with the game closed; `CS2_PROFILE=off` so the launcher profile cannot rewrite
the baseline's DRS block; Screenmanager "Use Native"=1 written by the series (the profile's other
half). Settings.coc restored after the series (sha256). Script: `~/cs2-patch/perf-runs/studio-m0-20261012.sh`.

| cell | avgFps | gpuMs avg / p95 | cpuGameMs | cpuMs p95 | gpuBound % | cpuFrame 1%-low | simTicks |
|---|---|---|---|---|---|---|---|
| warm-up (daily, discarded) | 47.62 | 17.1 / 19.0 | 10.0 | 17.3 | 12.8 | 45.2 | 8338 |
| daily-1 | 47.69 | 17.0 / 18.6 | 9.9 | 16.8 | 15.7 | 46.7 | 8310 |
| daily-2 | 47.73 | 17.1 / 19.4 | 9.9 | 16.9 | 13.5 | 45.2 | 8330 |
| daily-3 | 47.82 | 17.2 / 19.8 | 9.9 | 16.9 | 12.8 | 47.2 | 8309 |
| base-1 | 44.91 | 17.2 / 20.2 | 10.2 | 19.1 | 22.8 | 40.8 | 8304 |
| base-2 | 45.09 | 17.4 / 23.5 | 10.1 | 19.3 | 22.5 | 40.4 | 8309 |
| base-3 | 45.06 | 17.0 / 18.8 | 10.2 | 19.2 | 24.0 | 40.7 | 8312 |

- **Noise floor (avgFps max−min): daily driver 0.13 FPS (0.3 %), clean baseline 0.18 FPS (0.4 %).**
  Both are under the plan's ~1 FPS minimum, so **KEEP margin = 1 FPS ≈ 2.2 % of the clean baseline
  (45.02)**, and the **composed-profile margin for P5 is fixed at the same 1 FPS (2.2 %)** — the plan
  names no separate rule for it, so the KEEP rule is applied to both (2026-10-12; revisit if P5 wants
  a stricter bar). The M3 Max P0 floor (1.03 FPS ≈ 4.7 %) becomes the M3 Max stratum.
- Daily driver beats the clean baseline by **+2.73 FPS (+6.1 %)**, with a better 1%-low (45–47 vs ~40.6).
- Vsync off reads the same as C75's vsync-on 47.8: the bench never reaches the 60 FPS cap here.
- `gpuBoundPercent` was stable this time (daily 13–16, base 22–24) — unlike the screen-shared attempt.
- ⚠ **`CS2_PROFILE=off` is not "settings untouched":** the profile is two writes, and off also drops
  "Use Native"=1. The game resets that to 0 on exit (after any in-game resolution change it remembers
  the old size), so a first attempt without it ran at **1920×1080** and is VOID (TS 151106, 2 cycles).


### P3 B1 — frame cap 30 on the bench (2026-10-12 16:20–16:30)

`DXMT_CONFIG="d3d11.preferredMaxFrameRate=30"`, daily driver, same guards as Studio M0 (vsync off,
FullscreenWindow, `CS2_PROFILE=off` + Use Native=1, `Window resolution: 2560x1440` gated, display awake,
unlocked, not shared). Script `~/cs2-patch/perf-runs/p3-b1-cap30-20261012.sh`.

| cell | avgFps | cpuFrame stdev / p99 ms / 1%-low | gpuFrame stdev / p99 ms | simTicks |
|---|---|---|---|---|
| p3-b1-cap30-1 | 29.99 | 4.76 / 26.1 / 38.4 | 10.86 / 31.2 | 8226 |
| p3-b1-cap30-2 | 29.77 | 9.05 / 37.7 / 26.6 | 14.58 / 32.8 | 8036 |
| uncapped (Studio M0 daily-1..3) | 47.69–47.82 | 3.45–3.91 / 21.2–22.1 / 45.2–47.2 | — | 8309–8330 |

- **The cap engages exactly** (29.99 / 29.77) — mechanism load-verified on the Studio.
- **Pacing is not smoother at the cap on this scene**: frame-time stdev 1.3–2.5× uncapped, p99 up, and
  the two runs disagree (run 2 clearly worse). ⚠ Under a cap part of each frame is the deliberate present
  wait, and the bench's frame stats may count it differently — indicative, not a verdict.
- simTicks 1–3 % lower than uncapped over the same fixed window.
- ~~A cap of 60 cannot bind on a 48 FPS bench (≡ uncapped here)~~ — **measured 2026-10-13, see the next section:** the average is unchanged, but cpuFrame averages ~14 ms, so single fast frames are held and the tail moves a little. On 60 Hz, vsync-on ≡ cap 60 in play (not measured as a cell).
- **B1 stays a feel decision (plan §3 B1)**, but the bench gives no reason to prefer 30: live play on
  the Studio already holds 60 with vsync on in the cities that exist (#2). Candidate for the daily
  profile: vsync on (= cap 60), no `preferredMaxFrameRate`.

### P3 B1 — frame cap 60, with a same-session control (2026-10-13 13:32–13:51)

`DXMT_CONFIG="d3d11.preferredMaxFrameRate=60"` ×2, then the **uncapped daily driver ×2 as the session
control** (plan §2), same guards as the cap-30 cells. Scripts `~/cs2-patch/perf-runs/p3-b1-cap60-20261013.sh`,
`p3-ctl-uncapped-20261013.sh`. ⚠ The control ran *after* the cap cells: the session opened without it
(an omission, caught on reading the cap rows). Order would favour the cap, not the control (cooler machine first).

| cell | avgFps | cpuFrame stdev / p99 ms / 1%-low | gpuFrame stdev / p99 ms / 1%-low | gpuBound % | simTicks |
|---|---|---|---|---|---|
| p3-b1-cap60-1 | 47.87 | 4.10 / 25.9 / 38.6 | 7.91 / 23.2 / 43.1 | 23.8 | 8301 |
| p3-b1-cap60-2 | 47.47 | 4.75 / 26.5 / 37.8 | 8.16 / 23.8 / 42.0 | 23.8 | 8330 |
| control uncapped-1 | 47.77 | 3.85 / 24.8 / 40.3 | 7.46 / 22.9 / 43.6 | 21.0 | 8320 |
| control uncapped-2 | 47.91 | 3.57 / 24.1 / 41.5 | 7.21 / 22.3 / 44.8 | 19.1 | 8303 |
| later control uncapped-1 (14:32, B2 session) | 47.74 | 4.52 / 26.0 / 38.4 | 7.64 / 22.8 / 43.8 | 20.3 | 8282 |
| later control uncapped-2 (14:37) | 47.38 | 4.66 / 30.2 / 33.1 | 9.22 / 29.3 / 34.1 | 27.5 | 8301 |
| Studio M0 daily-1..3 (2026-10-12) | 47.69–47.82 | 3.45–3.91 / 21.2–22.1 / 45.2–47.2 | 5.94–6.29 / 18.1–19.0 / 52.8–55.1 | 12.8–15.7 | 8309–8330 |

- **Session control passes on the average** (mean 47.84 vs M0 47.75, inside the 0.13 floor), so the cells count.
- **But the tails drifted between days with the average flat:** today's uncapped cpuFrame p99 is 24–25 ms vs
  21–22, 1%-low 40–42 vs 45–47, gpuBound 19–21 % vs 13–16 %. Cause unknown. **Compare tail metrics only
  against a same-session control** — the cap-60 rows read against M0 alone looked like a 4–5 ms tail cost,
  of which most is this drift (EXPERIMENTS C77).
- ~~**Cap 60 vs its own control:** … the two cap runs sit outside both control runs on each tail metric … may cost a
  little at the tail.~~ **Withdrawn 14:41 the same day:** two more uncapped runs (the B2 session's control, rows above)
  read cpuFrame p99 26.0 / 30.2 ms and 1%-low 38.4 / 33.1. Today's four uncapped runs span p99 24.1–30.2 and 1%-low
  33.1–41.5; the cap runs (25.9 / 26.5, 38.6 / 37.8) sit inside that spread. **Cap 60 is indistinguishable from
  uncapped on this scene, average and tails.** The earlier "outside both control runs" was two control runs read as
  if they bounded the spread.
- B1 is measured at both values. The daily choice stays on feel; nothing here argues for `preferredMaxFrameRate`.
  Next in P3: B2 (in-game max-frame-latency slider), then the vsync decision.

### P3 B2 — in-game Maximum frame latency 1 vs the default 2 (2026-10-13 15:19–15:38)

James found the slider (Options → Graphics → Main, under VSync; it read **2**), set **1** and quit. A snapshot diff
showed it lands in `Settings.coc` as `"maxFrameLatency": 1` beside `"vSync"` and is **written only when not the default 2**.
Series `~/cs2-patch/perf-runs/p3-b2-20261013.sh`: lat 1 ×2 (the key as the game wrote it), then the default ×2 with the key
removed — the bracketing control — same guards as B1 (vsync off, FullscreenWindow, `CS2_PROFILE=off` + Use Native,
2560×1440 gated, graceful, awake, unlocked, not shared). Settings.coc restored to James's lat-1 file (sha256).
Session control before it (14:32): 47.74 / 47.38.

| cell | avgFps | cpuFrame avg / stdev / p99 ms / 1%-low | gpuFrame avg / p99 ms / 1%-low | gpuBound % | gpuMs avg | simTicks |
|---|---|---|---|---|---|---|
| p3-b2-lat1-1 | 41.54 | 15.13 / 3.78 / 24.3 / 41.2 | 24.03 / 36.9 / 27.1 | 99.1 | 24.03 | 8316 |
| p3-b2-lat1-2 | 41.71 | 15.03 / 4.00 / 25.8 / 38.7 | 23.93 / 36.5 / 27.4 | 99.1 | 23.93 | 8317 |
| p3-b2-lat2ctl-1 (default) | 47.97 | 14.41 / 3.62 / 23.3 / 43.0 | 3.96 / 22.2 / 45.1 | 21.4 | 17.26 | 8320 |
| p3-b2-lat2ctl-2 (default) | 48.14 | 14.38 / 3.46 / 23.4 / 42.8 | 3.90 / 22.3 / 44.9 | 20.8 | 17.43 | 8340 |

- **Latency 1 = −6.4 FPS (−13 %), REVERT.** Far outside the 1 FPS margin and every spread seen today; both pairs are tight.
- The mechanism shows in the columns: at 1 the frame goes **99 % GPU-bound** and the measured GPU time rises 17.3 → 24.0 ms —
  with one frame in flight the CPU and GPU stop overlapping, so each frame pays both in series. CPU-side times barely move.
- Input latency would drop by about one frame (~21 ms at 48 FPS); for a city builder that is not worth 13 %.
- **The default 2 stays.** B2 closed. ⚠ James's `Settings.coc` still carries `"maxFrameLatency": 1` until it is set back.
- The bracketing control (47.97 / 48.14) sits at or above M0 (47.75); the 14:32 control's slow run (47.38) did not recur.

