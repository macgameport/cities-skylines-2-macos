# The deep performance pass — squeeze the promoted 11.16 stack

> **Status: DRAFT — research folded 2026-08-23, not yet triple-checked. Run `check it` before executing.**
> Tracking: PLAN.md § "Performance: the deep optimization pass" (personal-tier repo, no issue tracker).

James, 2026-08-23: *"take a deep hard look at optimizing efficiency"* — serious token budget
approved, and the goal restated at kickoff: **make the experience awesome, squeeze every
performance drop out of each setting we uncover, and codify this as our ethos.** This doc is both
the plan and the codification. The lever matrix below was produced by a four-domain research
fan-out (DXMT v0.80 source · CS2 settings data · Wine/Rosetta/macOS host · Unity boot.config),
every DXMT claim cited to `file:line` against the upstream v0.80 tag (commit `589adb7`).

## 0. The ethos

Standing principles for all performance work on this stack. Earned here (the ledger has the
receipts); they outlive this pass:

1. **Measure, then move.** No lever is touched without a baseline number, and no lever is kept
   without a delta. A change that "feels faster" but doesn't move the HUD is reverted. The unit of
   progress is a row in the results table, not a config edit.
2. **One variable at a time.** Every run changes exactly one lever against the fixed scene. Two
   levers changed together produce a number that belongs to neither (the refresh-rate/
   CaptureDisplays confound in GOTCHAS is the cautionary tale).
3. **Judge runs by timestamp.** Only a run whose logs postdate the change tests the change. Never
   conclude — and especially never *revert* — off a stale run.
4. **A lever that didn't provably load measured nothing.** DXMT echoes `Found config env:` but
   never prints the *parsed* result (`logOptions` is dead code in v0.80 — `config.cpp:390-394`);
   a typo'd key fails silently. Every config cell verifies its own load signal (log line, HUD
   line, boot marker) before its numbers count.
5. **The experience is the target, not the peak number.** Smoothness beats a higher average:
   frame-time consistency, input latency, no hitching, stable presentation. A lever that adds
   2 FPS but adds shimmer or judder loses. The GPU-ms spread matters as much as the FPS line.
6. **Free wins before visual trades.** Exhaust the levers that cost nothing visually before
   spending image quality — and take free *quality* wins (Texture Med→High) with the same
   discipline as free speed wins.
7. **Negative results are results.** Game Mode: Off, closed. `dxgi.handleAltTab`: structurally
   inert, proven. A pass that closes five levers as "no effect, don't revisit" produced value.
   §3E is where they rest.
8. **Every change has a one-line revert.** Env vars unset; in-game settings re-select; file edits
   (boot.config) get their revert path written *before* the edit, like the binary patches.
9. **A harness that prints a conclusion it didn't compute is a liability** (GOTCHAS,
   measurement-bugs). The results table records what the HUD showed, not what the row expected.
10. **Know which bound you're attacking.** We are GPU-bound at 23.1 ms today; a CPU-side lever
    measuring flat is *expected*, not failed. The regime flips in big cities (sim/pathfinding);
    levers are tagged GPU / CPU-sim / pacing / validity, and each is judged in its own regime.

## 1. Measured facts — the starting position (do not re-derive)

| Fact | Value | Source |
|---|---|---|
| Stack | self-built stock Wine 11.16 + DXMT (PK fork v0.80-17-g79f6279), 10 patches | PLAN.md, build plan |
| Baseline FPS / GPU ms | **44.86 / 23.1 ms** — ⚠ captured at DynamicRes=**Automatic**, so internal res was floating; **must re-baseline** (§2) | V3 + research fold |
| Bound | **GPU-bound** at baseline settings | Metal HUD, ledger |
| Baseline settings | 1080p@120Hz · Global=Custom · DynamicRes=Automatic · AA=Low SMAA · Clouds=Med · Fog=on · Volumetrics=Low · AO=Med · GI=Off · Reflections=Med · DoF=Off · MotionBlur=Off · Shadows=Low · Terrain/Water/LOD/Texture=Med | V3 row, ledger |
| Presentation | Direct; DXMT always sets `displaySyncEnabled=false` — ALL pacing is `presentDrawableAfterMinimumDuration` (`dxmt_presenter.cpp:19`) | V-session + source |
| Unity / game build | **Unity 2022.3.71f1**, game 1.6.0f1, Mono 6.13; maintained by Iceflake Studios since the 2026 perf push | globalgamemanagers + Player.log |
| `WINEESYNC=1 WINEMSYNC=1` | **INERT** — stock winehq wine has never shipped esync/msync (whole-tree grep: zero hits); launcher vars are Porting-Kit habit. What runs is wineserver socket sync | research, measured |
| `gfx-enable-native-gfx-jobs=1` | **no-op on D3D11** — Player.log: `Rendering Threading Mode: LegacyJobified`; don't spend a run on it, don't turn plain gfx-jobs off | Player.log, measured |
| Allocator telemetry | ~17M failed fast-path (bucket) allocs per session in Player.log's allocator report | Player.log, measured |
| Refresh rate | game must run 120 Hz (DELL U2424H) or a mode change blanks display 2 | GOTCHAS |
| Game Mode | Off even in exclusive fullscreen — closed, negative | V5 |
| `CS2_METALFX=1` | wired in launcher, never tested; **default factor 2.0 is a trap at 1080p** (renders a 4K drawable — §3A) | launcher + source |
| Benchmark mode | game ships `-benchmark` since patch 1.5.7f1 (2026-04-29) — untested under Wine/DXMT | Iceflake notes |
| CrossOver parity reference | ~35 fps (M3 Pro, AppleGamingWiki) | PLAN.md |
| Hardware | 14" M3 Max (Mac15,10 — supports High Power Mode), 36 GB, macOS 26 | system |

**DXMT config surface (fork ≈ upstream v0.80; only master-only addition is `d3d11.maxFeatureLevel` — do NOT use):**
11 config options + 12 env vars, enumerated with mechanisms in the research record. `DXMT_CONFIG`
is `;`-separated `key=value`, floats plain decimal, file (`DXMT_CONFIG_FILE`) parsed first then env
overrides, read ONCE per process — every change needs a relaunch. Verify via `Found config env:`
in the launcher's captured stderr.

## 2. Measurement protocol (the harness for every row)

**Instrument order of preference:**
1. **`-benchmark` mode** (P0 tests it): if the built-in benchmark runs under Wine/DXMT, it is the
   fixed scene — repeatable, no camera discipline needed.
2. **Fallback — fixed save + fixed camera:** one city save, one camera bookmark, same in-game
   time-of-day, framing screenshot recorded in the results file header.

**Readings:** Metal HUD via `CS2_HUD=1`; add `MTL_HUD_LOGGING_ENABLED=1` to capture HUD samples
for post-hoc stats instead of eyeballing (⚠ exact var name; `MTL_HUD_LOG_ENABLED` is wrong). Two
readings per cell: **R-paused** (sim paused — pure render, primary for GPU levers) and
**R-running** (sim 1×, ≥60 s after load settles — the real experience, primary for CPU levers and
the README number). ≥30 s per reading, record min/typ/max.

**Standing run rules:**
- One lever per launch; DXMT config is read once per process, so there is no in-session toggling.
- Log timestamps must postdate the change (ethos #3); every DXMT cell greps its `Found config
  env:` line before counting (ethos #4).
- **Pin DynamicRes off/Constant for every cell** — Automatic floats internal resolution and
  poisons one-variable discipline (this invalidated the original 44.9 baseline as an absolute).
- V-Sync **off** during measurement cells (verify the toggle doesn't drop 120 Hz); re-decide
  vsync for the daily profile in P3 on pacing grounds.
- `caffeinate` wraps unattended runs (display sleep already killed one measurement in this
  project). HUD state identical across compared cells.
- Discard the first run after any engine rebuild or macOS update — Rosetta re-translates the AOT
  cache and the run is unrepresentative. Same for the first run after anything that invalidates
  the shader cache (metal-version/shader-flag changes).
- A run that crashes or shows artifacts records that as its result.

**HUD interpretation (from source, `d3d11_swapchain.cpp:813-892`):** the Metal HUD's own GPU time
is the GPU number; DXMT's lines are CPU-side: `Commit avg` = game thread blocked on the 32-slot
chunk ring (submission back-pressure); `Sync … lat` = game thread waiting at the present boundary
for frame N-3 — **this is the number that grows when GPU-bound**; `Encode a+b+c` = encoder-thread
translate/flush/drawable-wait (c = compositor back-pressure). All-dashes on the compat line =
full native support for what CS2 uses.

**M0 — re-baseline + noise floor.** Set DynamicRes=Constant (or Off) at 1080p, then run the
identical configuration **twice** (separate launches). This yields (a) the *clean* baseline the
old 44.9 lacked, (b) the noise floor a lever must beat to earn KEEP. If spread > ~1 FPS, tighten
the protocol before proceeding.

**M1 — one GPU frame capture, early.** `MTL_CAPTURE_ENABLED=1 DXMT_CAPTURE_EXECUTABLE=<exe base
name> DXMT_CAPTURE_FRAME=<N in-game>` writes a `.gputrace` (needs Xcode to open). One capture of
a representative city frame shows where the 23.1 ms actually goes (fragment vs vertex vs post) —
it predicts whether resolution levers pay 40% or 10%, and directs the whole pass. Trace files are
GBs; delete after reading.

**Results land in `docs/perf-pass-results.md`** — created at execution start; row format:
`lever | value | load-verified? | R-paused FPS + GPU ms | R-running FPS + GPU ms | verdict (KEEP / REVERT / TRADE / DEAD) | notes`.

## 3. Lever matrix

Tags: **[GPU]** attacks the GPU bound · **[CPU-sim]** pays in big-city/sim regime · **[pacing]**
frame-time consistency & latency · **[validity]** measurement infrastructure · **[quality]** free
visual upgrade. Confidence: measured / documented (source-read) / community / speculative.

### 3A. Resolution levers — the main GPU-bound play (Phase P1)

The only remaining big GPU levers are all resolution-shaped, since DLSS is absent without the
NVEXT spoof and settings are already lean. **All cells: DynamicRes pinned off.**

| # | Lever | Design | Confidence |
|---|---|---|---|
| A1 | **[GPU]** In-game 1280×720, no MetalFX | The control arm. DXMT's present blit already linearly scales when game res ≠ drawable (`dxmt_presenter.cpp:153-186`), so this isolates the pure render-resolution gain (720p = 44% of 1080p pixels; GPU ms could drop toward ~12–15 if the frame is fragment-dominated). | documented |
| A2 | **[GPU]** MetalFX spatial: `CS2_METALFX=1` + `DXMT_CONFIG="d3d11.metalSpatialUpscaleFactor=1.5"` + in-game 1280×720 | Renders 720p, MetalFX-upscales to exactly 1920×1080. ⚠ **Never at default factor 2.0 with 1080p in-game — that creates a 4K drawable and strictly REGRESSES** (`d3d11_swapchain.cpp:142`). Verify: HUD `MetalFX: Spatial` + `Scale: 1280x720->1920x1080`. Risk: spatial artifacts; **UI text upscales too** (soft UI in a text-heavy game). | documented |
| A3 | **[GPU]** MetalFX spatial, milder: in-game 1600×900 + factor 1.2 | The quality-conscious point on the same curve (69% of pixels). | documented |
| A4 | **[GPU][speculative]** DLSS→MetalFX-Temporal: `DXMT_ENABLE_NVEXT=1` + `dxgi.customVendorId=10de` (+ DeviceId/Desc) | DXMT v0.80 ships nvapi/nvngx mapping DLSS onto `MTLFXTemporalScaler` (`nvngx.cpp:45-150`). If CS2's DLSS option appears under the NVIDIA spoof: temporal reconstruction at ~67% scale **with native-res UI** (Unity composites UI after upscale) — the highest-quality version of the lever. Preconditions checked first (read-only): nvngx/nvapi64 DLLs present in prefix + overrides. Highest risk: spoof can flip unknown game branches; ghosting; never leave the spoof set outside this experiment. | speculative |

Decision shape after P1: A2/A3/A4 are TRADE verdicts — James eyeballs the artifacts at the FPS
gained and picks the daily point. A1 is pure sizing data.

### 3B. DXMT tunables — pacing + closed switches (Phases P1/P3)

| # | Lever | Design | Confidence |
|---|---|---|---|
| B1 | **[pacing]** `d3d11.preferredMaxFrameRate=40` | Metal-coordinated cap via `presentDrawableAfterMinimumDuration` (`d3d11_swapchain.cpp:762-766`): trades ~5 avg FPS for a flat 25.0 ms cadence (40 divides 120). Test AFTER the GPU levers land — if P1 gets us near a stable 60, cap at 60 instead. Judged on feel + frame-time graph, not FPS. | documented |
| B2 | **[pacing]** In-game "reduced input latency"/max-frames-ahead option, if present | DXMT's frame-latency depth (default 3 ≈ 67 ms at 45 FPS) has NO config knob (`dxmt_command_queue.hpp:153`), but the game-side `SetMaximumFrameLatency` path works (`d3d11_device.cpp:1244-1245`). Check the game's options; if present, test at 2. | documented |
| B3 | **[validity]** Keep-off inventory | `sampleNaNToZero`, `defuseFma` (add ALU work; other games' workarounds), `ignoreMapFlagNoWait` (adds stalls), `forceSDR` (no-op on SDR panel), `handleAltTab` (inert for CS2 + freeze is fixed upstream), `shaderMetalVersion` (already max; setting it orphans the shader cache), `DXMT_SHADER_CACHE=0` (never), `DXMT_USE_DEFAULT_METAL_CACHE` (leave), `DXMT_LOG_LEVEL` (leave at info — `none` hides the load-verification lines). No cells spent; closed by source read. | documented |

### 3C. In-game settings — visual trades + free quality (Phase P2)

Windows-measured percentages don't transfer to Apple TBDR GPUs under translation — that's why we
re-measure. Baseline block is already lean (GI Off, DoF Off, MotionBlur Off, Volumetrics Low,
Shadows Low).

| # | Lever | Design | Confidence |
|---|---|---|---|
| C1 | **[GPU]** DynamicRes Automatic→Constant/off | The M0 prerequisite, and itself a lever: Constant beats Automatic for consistency. If A2/A3 land, DRS stays off (MetalFX owns scaling). | community |
| C2 | **[GPU]** Level of Detail Med→Low | One of the two biggest remaining tickets (GamersNexus ~29% at launch; ~21% in a 2026 pass — Windows numbers, re-measure here). Cost: pop-in. | community |
| C3 | **[GPU]** Shadows Low→Disabled — *sizing cell* | GN measured 37% disabling shadows entirely at launch. Probably not the daily setting (flat look); the cell tells us what Low still costs and bounds the headroom. | community |
| C4 | **[GPU]** Combined small-ticket sweep: Clouds Off + Fog Off + AO Off + SSR Off + Terrain/Water Low | Expected ~0.2–1 ms each; one combined A/B cell, decompose only if the combined delta exceeds ~2 ms. | community |
| C5 | **[quality]** Texture Quality Med→High | Expected ~0 GPU ms with 36 GB unified — a free visual upgrade if flat. Watch for virtual-texturing streaming stalls under DXMT; revert on hitching. | community |
| C6 | **[validity]** Regime guard | As FPS rises, watch for the GPU-bound→CPU-bound crossover (GPU ms < 1000/FPS and FPS stops responding to GPU levers — plausibly around 55–80 FPS here). Past it, C-levers read flat and that's the *regime*, not the lever. | documented |

### 3D. Unity boot.config + host — CPU-side, late-game insurance (Phase P4)

boot.config discipline: `cp boot.config boot.config.bak` before first edit; verify boot after
each change; a game update may rewrite it (if any KEEP lands, fold the check into the launcher's
repatch step). These pay in the big-city sim regime, measured on a **late-game save, R-running**.

| # | Lever | Design | Confidence |
|---|---|---|---|
| D1 | **[CPU-sim]** `job-worker-count=10` (then 8) | Unity spawns workers = cores-1; measured census: ~45+ runnable threads (13 job + 16 background + 14 PhysX + …) on 14 Rosetta cores. Capping cuts context-switch/spin waste. Key string confirmed present in this UnityPlayer.dll. Can only lower, never raise. | community |
| D2 | **[CPU-sim]** `memorysetup-bucket-allocator-block-count=4` | Best-evidenced CPU lever: ~17M failed fast-path allocs/session measured in Player.log. +12 MB memory. Boot-path risk: verify boot. | measured |
| D3 | **[CPU-sim]** `memorysetup-temp-allocator-size-main=8388608` | ~0.4 overflows/frame average with bursts; +4 MB. Separate cell from D2. | measured |
| D4 | **[GPU?]** Second display disconnected during play | Cheap A/B; plausibly 0–1 ms if scanout/compositing shares GPU resources; may be zero since presentation is Direct. Don't re-plug mid-session (mode-change class). | speculative |
| D5 | **[validity]** High Power Mode for long sessions | Not an FPS lever; thermal-sag insurance on the 14" chassis. Loud fans. One soak cell: 45 min, does GPU ms creep? | documented |

### 3E. Closed — measured/proven dead, do not revisit

- **esync/msync**: env vars inert on stock wine (never shipped there). Porting marzent's msync
  patchset = a *future* CPU-side lever, wrong bound today; parked.
- **Game Mode** (measured Off, Rosetta categorization) · **`dxgi.handleAltTab`** (inert + fixed
  upstream) · **taskpolicy/QoS** (GPU-bound; renice needs sudo, marginal) · **Rosetta tunables**
  (none exist; only the first-run-after-rebuild rule) · **App Nap** (already disabled by stock
  wine) · **winemac.drv registry knobs** (no perf switches; touching CaptureDisplaysForFullscreen
  risks the mode-change freeze class) · **memory pressure** (non-issue at 36 GB).
- **`preload-shaders`** (string absent from this UnityPlayer.dll) · **`gc-max-time-slice`**
  (already Unity's default 3) · **gfx-jobs toggles** (native no-op on D3D11; plain off = pure
  regression) · **`-nolog`** (kills our diagnostics for a sub-1% CPU win — permanent decline) ·
  **`-force-d3d12`** (no backend in DXMT — broken launch) · **in-game DLSS without the spoof**
  (option absent on Apple GPU) · **DXMT frame-latency config knob** (doesn't exist in v0.80) ·
  **`d3d11.maxFeatureLevel`** (master-only, not in the fork).

## 4. Phases

| Phase | What | Gate to next |
|---|---|---|
| **P0** | Create results file · test `-benchmark` under Wine/DXMT (instrument choice) · **M0 re-baseline + noise floor** (DRS pinned) · **M1 GPU frame capture** read in Xcode | clean baseline + noise floor + "where the 23.1 ms goes" recorded |
| **P1** | Resolution levers A1→A2→A3 (A4 if preconditions hold), one per launch | curve measured; James picks the quality/FPS point |
| **P2** | Settings matrix C1–C5 on top of the chosen P1 point | all C-rows verdicts |
| **P3** | Pacing & experience: B1 (cap at the sustainable rate), B2 if present, vsync decision, D4/D5 | pacing chosen on feel + frame-time graph |
| **P4** | CPU-side D1–D3 on a late-game save | verdicts or explicit skip |
| **P5** | **Compose + re-measure**: baseline + every KEEP as one profile (levers may not compose additively); ship | composed profile beats clean baseline by stated margin |

**P5 ships:** launcher defaults for unconditional KEEPs (same override pattern as `CS2_HUD`) ·
launcher hygiene (drop the inert `WINEESYNC/WINEMSYNC` line — game must not be running during the
edit) · README numbers + settings table · as-built header here · AppleGamingWiki draft · PLAN.md
pointer to §0 as the standing ethos.

## 5. Exit criteria

1. Clean re-baseline + noise floor recorded (M0); frame capture read (M1).
2. Every §3A–§3D lever has a results row with a verdict and a load-verification mark — measured,
   not reasoned.
3. Composed profile re-measured as a whole; beats clean baseline by a stated margin (target:
   ≥25% FPS at a quality point James accepts — else the pass documents why not).
4. P5 ship list complete; no stale numbers in README/PLAN; §3E closures recorded in GOTCHAS if
   any surprised us.
5. Any *defect* discovered (vs tuning) gets its own ledger entry and, if upstream-worthy, a note
   to dxmt#206 / the wiki draft.

## 6. Rollback

P1–P3: unset env var / re-select in Options → Graphics (never hand-edit `Settings.coc` —
GOTCHAS). NVEXT experiment (A4): also delete the fake NVIDIA registry keys it writes and unset
the spoof vars — one launch with them unset confirms the adapter reads Apple again. P4:
`boot.config.bak` copy-back. Launcher edits only while the game is not running (standing rule).

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | research folded; not yet checked |

Key paths: `~/cs2-patch/launch-cs2-dxmt11.sh` · `scripts/build-engine-1116.sh` ·
`docs/plans/build-wine1116-dxmt-engine.md` · `GOTCHAS.md` · game `boot.config` · DXMT v0.80
source refs per row (research record: workflow wf_8c0e742b-43e, 2026-08-23).
