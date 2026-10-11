# The deep performance pass — squeeze the promoted 11.16 stack

> **Status: check-it'd 2026-10-10 — P3 build-ready-with-fixes, P4 + P5 needs-rework (pass 2, a
> re-check after the move to the Mac Studio; corrections folded below, § Review corrections pass 2).
> P3 may start once Studio M0 (§2) has run; P4/P5 need the instrument rework named there and a
> fitted re-check before building.** Pass 1: check-it'd 2026-08-23 — build-ready-with-fixes.
> **🔧 As-built (2026-08-24):** P0–P2 executed and substantially measured — instrument = the
> game's own `-benchmark` (structured per-frame output; autonomous cycles via
> `scripts/perf-bench.sh`); settings cells went fully autonomous after the Settings.coc
> edit experiment (GOTCHAS refined). §3A closed by live adjudication (borderless locks
> backbuffer res). Composed profile measured +11.6% avg / +55% 1%-low on the stress scene.
> Deviations from plan: MetalFX A-cells impossible in the pinned display mode (replaced by
> DRS/filter cells); HUD-logging instrument dead (benchmark series superseded it); settings
> edits via file (not menu) after the controlled experiment. Remaining: P3 pacing cells,
> P4 late-game CPU cells (M0-L), P5 ship. Verify against: docs/perf-pass-results.md ·
> scripts/perf-bench.sh · ~/cs2-patch/perf-runs/settings-series.py · GOTCHAS.md.
> ⚠ (2026-10-10) `settings-series.py` is **unrunnable as-is**: `REPO` points at the retired
> `~/Documents/github/cs2`, it has no dry mode (any run copies Settings.coc over `.series-base`),
> and its August cell regexes do not match today's base. Fix or drop it before P3 relies on it.
> Tracking: PLAN.md § "Performance: the deep optimization pass" (personal-tier repo; GitHub issues were not in use when this shipped — enabled 2026-09-02).

James, 2026-08-23: *"take a deep hard look at optimizing efficiency"* — serious token budget
approved, and the goal restated at kickoff: **make the experience awesome, squeeze every
performance drop out of each setting we uncover, and codify this as our ethos.** This doc is both
the plan and the codification. The lever matrix came from a four-domain research fan-out (DXMT
v0.80 source · CS2 settings data · Wine/Rosetta/macOS host · Unity boot.config); a six-lens
adversarial check pass then verified it against the machine and its corrections are folded below.
DXMT claims cite `file:line` against the upstream v0.80 tag (commit `589adb7`) — durable sources;
⚠ the *running* engine is the PK fork, 17 unread commits ahead (see §1).

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
   never prints the *parsed* result (`logOptions` is dead code in v0.80 — `config.cpp:396-403`,
   zero call sites); a typo'd key fails silently. Unity silently ignores unknown boot.config
   keys. Every cell verifies its own load signal (log line, HUD line, thread census, allocator
   echo) before its numbers count.
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
| Baseline FPS / GPU ms | **44.86 / 23.1 ms** — ⚠ captured at DynamicRes=**Automatic**, so internal res was floating; **must re-baseline** (§2 M0) | V3 + research fold |
| Bound | **GPU-bound** at baseline settings | Metal HUD, ledger |
| Baseline settings | 1080p@120Hz · Global=Custom · DynamicRes=Automatic · AA=Low SMAA · Clouds=Med · Fog=on · Volumetrics=Low · AO=Med · GI=Off · Reflections=Med · DoF=Off · MotionBlur=Off · Shadows=Low · Terrain/Water/LOD/Texture=Med · Display Mode=Fullscreen Window | V3 row, ledger |
| Presentation | Direct; DXMT always sets `displaySyncEnabled=false` — ALL pacing is `presentDrawableAfterMinimumDuration` (`dxmt_presenter.cpp:19`) | V-session + source |
| Unity / game build | **Unity 2022.3.71f1**, game 1.6.0f1 → **1.6.2f1 since 2026-10-10** (Unity unchanged, LegacyJobified unchanged); maintained by Iceflake Studios since the 2026 perf push (external claim) | globalgamemanagers + Player.log |
| `WINEESYNC=1 WINEMSYNC=1` | **INERT** — stock winehq wine has never shipped esync/msync (whole-tree grep: zero hits); launcher vars were Porting-Kit habit | research, measured |
| `gfx-enable-native-gfx-jobs=1` | **no-op on D3D11** — Player.log: `Rendering Threading Mode: LegacyJobified`; don't spend a run on it, don't turn plain gfx-jobs off | Player.log, measured |
| Allocator telemetry | ~17M failed fast-path (bucket) allocs per session in Player.log's allocator report — **session-length dependent** (2026-10-10 boot-verify session: ~1.77M per dump); re-derive at M0-L, never quote. ⚠ The report is written **only on a graceful exit** (absent from every SIGTERM'd perf-bench Player.log) | Player.log, measured |
| Refresh rate | ~~120 Hz (DELL U2424H)~~ **2026-10-10: both displays 60 Hz** (Studio Display main, U2720Q portrait); the game must keep the main panel's refresh or a mode change blanks display 2. ⚠ **At 60 Hz, in-game VSync is a 60 FPS cap**: with SyncInterval 1 DXMT's minimum present duration is 1/refresh (`d3d11_swapchain.cpp:762-766`) | GOTCHAS + source |
| Game Mode | Off even in exclusive fullscreen — closed, negative | V5 |
| `CS2_METALFX=1` | wired in launcher, never tested; **default factor 2.0 is a trap at 1080p** (renders a 4K drawable — §3A) | launcher + source |
| Benchmark mode | game ships a benchmark since patch 1.5.7f1 (2026-04-29): **both** a `-benchmark` launch param and a main-menu Options entry; output format + whether it forces its own profile undocumented — P0 answers | Iceflake notes (external) |
| A4 preconditions | **measured ABSENT 2026-08-23**: no nvngx.dll/nvapi64.dll anywhere (prefix system32/syswow64, engine PE dirs, both sibling wrappers). DXMT builds them off by default (`meson.options` `enable_nvapi`/`enable_nvngx`) | find, read-only |
| Xcode | ~~not installed~~ **installed on the Studio** (`xcode-select -p` → `/Applications/Xcode.app`, 2026-10-10) — M1's .gputrace is readable | measured |
| Hardware | ~~14" M3 Max (Mac15,10), 36 GB, macOS 26, 14 cores~~ **since 2026-10: Mac Studio M5 Max (Mac17,14), 18 cores (6 + 12), 64 GB, macOS 27.0.1** — Rosetta/wine see all 18 (PhysX 18 workers; 17 `Job.Worker`s). **No High Power Mode** (`pmset -g cap` lists only `lowpowermode`) | system |
| boot.config path | `<game dir>/Cities2_Data/boot.config` (NOT the game root) | measured |

**DXMT config surface — fork is a SUPERSET of upstream v0.80** (strings-verified on the shipping
`d3d11.dll`/`dxgi.dll`): the 11 v0.80 config options + 12 env vars, **plus** `d3d11.maxFeatureLevel`
(in the fork binary — behavior undocumented, still do NOT use) and fork-only env vars
`DXMT_RESOURCE_RESIDENCY` and `DXMT_NVEXT_GUID` (semantics unknown — do not touch). All `file:line`
cites are v0.80; the fork's 17 commits are unread — runtime-verify any mechanism-critical behavior
via its load signal rather than trusting the cite. `DXMT_CONFIG` is `;`-separated `key=value`,
floats plain decimal, file (`DXMT_CONFIG_FILE`) parsed first then env overrides, read ONCE per
process — every change needs a relaunch.

## 2. Measurement protocol (the harness for every row)

**Every measurement cell launches from a terminal via `scripts/perf-run.sh`** — never the dock
app (the dock shim runs a fixed env: no per-cell `DXMT_CONFIG`, no caffeinate, quiet mode). The
harness wraps the canonical launcher as:

```
<CELL_ENV> CS2_HUD=1 bash scripts/perf-run.sh <cell-name>
```

and provides, per run: `caffeinate -dis` (display sleep already killed one measurement here) ·
stderr capture via `2>&1 | tee ~/cs2-patch/perf-runs/<cell>-<ts>.log` (DXMT logs reach wine
stderr; `WINEDEBUG=-all` stays — the diag launcher's `+macdrv` costs fps and is NOT for
measurement) · `DXMT_LOG_PATH` pointed at the run dir as the belt-and-braces copy · automatic
post-run grep of the load signals (`Found config env:`, `MetalFX: Spatial`, `Scale:`, engine
line) · the run timestamp that ethos #3 judges by. ⚠ Do not set `CS2_WRAPPER` in the measuring
shell — two wrappers exist and a stray override silently measures the parked engine.

**Game args:** the launcher passes `${CS2_ARGS:-}` through to `Cities2.exe` (added for this pass;
the `-benchmark` cell is `CS2_ARGS=-benchmark`).

**Instrument order of preference:**
1. **Benchmark mode** (P0 tests it — try the `-benchmark` param AND the main-menu entry): if it
   runs under Wine/DXMT, honors the current graphics settings (verify — if it forces its own
   profile it cannot serve), and yields readable numbers, it is the fixed scene for **all of
   P0–P3 including M0**. Its readings are their own class — record as **R-bench** and never
   compare an R-bench number against a fixed-save number inside one verdict.
2. **Fallback — fixed save + fixed camera:** one city save, one camera bookmark, same in-game
   date/time, framing screenshot recorded in the results dir.

**Readings (fixed-save mode):** Metal HUD via `CS2_HUD=1`. Two readings per cell:
**R-paused** (sim paused — pure render; assumption to verify once: pause freezes time-of-day/
weather/traffic so render load is static) and **R-running** (sim 1×, read the **fixed window
T+60s→T+90s** after load — lower-bounded windows sample different in-game weather/daylight;
record in-game date/time + weather per row and discard readings during a visible weather
transition). Record min/typ/max, not a glance.

**Instrument-validation cell — RESOLVED (measured 2026-08-24, see results doc):** Apple HUD
post-hoc logging is dead under Wine on macOS 26 (`MTL_HUD_LOGGING_ENABLED` emits nothing;
`MTL_HUD_PATH` writes nothing). The benchmark's own per-frame series is the primary stats
instrument; daily-scene readings fall back to HUD-eyeball min/typ/max over the fixed window,
stated per row.

**Standing run rules:**
- One lever per launch; DXMT config is read once per process — no in-session toggling.
- **Display Mode = Fullscreen Window pinned for every cell** (exclusive-fullscreen changes the
  swapchain/resolution machinery and the mode-change/blanking class lives there — GOTCHAS).
- Any resolution selection must keep the main panel's refresh (**60 Hz** on the Studio Display and
  the U2720Q since 2026-10); after any resolution/vsync change, verify no mode change: display 2
  did not blank and the HUD refresh did not change.
- **Pin DynamicRes off/Constant for every cell** (Automatic floats internal resolution — it
  invalidated the original 44.9 baseline as an absolute).
- V-Sync **off** during measurement cells; re-decide vsync for the daily profile in P3.
  ⚠ **Not optional on a 60 Hz panel** — vsync-on there is a 60 FPS min-duration cap that compresses
  every delta near 60. Every saved base carries `"vSync": true` and the 2026-10-10 Studio series
  (C75) ran with it on: set `"vSync": false` as a complete-value edit (GOTCHAS § "Settings.coc:
  complete value edits ARE honored") before each P3–P5 cell unless vsync is the lever.
- Discard the first run after any engine rebuild or macOS update (Rosetta AOT re-translation),
  and after anything that invalidates the shader cache (metal-version/shader-flag changes). A
  macOS point update mid-pass re-baselines: repeat M0's control before counting further cells.
- **Session control:** every measurement session opens with a re-run of the current base config;
  if it deviates from the recorded base by more than the noise floor, resolve before counting
  cells (thermal state, background churn, silent updates).
- **Crash rule:** on crash, restore config, one clean relaunch of the same cell; a second crash =
  verdict **CRASH**, lever quarantined (revert applied + verified), move on. The launcher already
  clears the stale `.crash` marker.
- A run that shows artifacts records that as its result.

**Verdict definitions (two people, same numbers, same verdict):**
- **KEEP** — primary-reading delta beats the session noise floor, no quality/pacing cost.
  *Exception for [quality] cells (C5):* KEEP = FPS flat within the floor AND no hitching — the
  win is visual, not numeric.
- **TRADE** — delta beats the floor WITH a quality cost → James adjudicates the point. Every
  TRADE cell saves a screenshot at the fixed framing into the results dir (side-by-side
  comparison, not memory across relaunches).
- **REVERT** — regression beyond the floor, or artifacts/hitching at any FPS.
- **DEAD** — |delta| ≤ floor: no effect; recorded and closed.
- **CRASH** — per the crash rule. **CLOSED/SKIP** — not a cell by design (cite: source-read,
  precondition failed, regime guard).

**M0 — re-baseline + noise floor.** DynamicRes pinned, then **≥3 identical runs** (separate
launches). Noise floor = max−min; **KEEP margin = max(floor, ~1 FPS), expressed as % of baseline**
so it scales with regime; re-establish with one repeat pair if the working point moves >~30% FPS
from baseline. Record the floor for BOTH reading classes (R-running adds sim jitter). The
composed-profile margin (§4 P5) is fixed in writing at the end of P0.
**Studio M0 (added 2026-10-10, gates P3):** ⚠ needs the session UNLOCKED — a locked session blanks
the panel after 30 s whatever `caffeinate` asserts, and a dark panel moves the numbers (GOTCHAS);
perf-bench records `display_awake` and flags dark cycles VOID. Also: the game rewrites
`Settings.coc` on a graceful exit with `"vSync": true`, so the vsync-off edit is re-applied before
every cycle (game not running) and the backup restored after the series. the P0 floor (1.03 FPS ≈ 4.7 %) was measured on the M3
Max at 22 FPS and does not transfer. Before any P3 cell: one discarded warm-up run (new hardware,
new Metal pipeline cache), then **≥3 consecutive perf-bench runs of the current daily driver with
vsync off**, then **≥3 of the clean baseline** (`Settings.coc.series-base`, vsync off) for P5 to
compare against. Floor, KEEP margin and composed margin are re-fixed **in writing** from those
runs; the P0 numbers become the M3 Max stratum.

**M1 — GPU frame capture (best-effort, NON-gating: Xcode isn't installed).**
`MTL_CAPTURE_ENABLED=1 DXMT_CAPTURE_EXECUTABLE=Cities2` (exact — `getExeBaseName` strips `.exe`;
mismatch silently never arms), run from a scratch dir with tens of GB free, then **press F10 at
the framed scene** (v0.80's hotkey path — `DXMT_CAPTURE_FRAME=<N>` counts from process start and
is guesswork past menus; fallback only). Load signal: `DXMT capture enabled` in the run log.
The `.gputrace` is *taken now, read when Xcode lands* — it predicts whether resolution levers pay
40% or 10%, but P1 proceeds on A1's empirical sizing regardless.

**Results land in `docs/perf-pass-results.md`** — row format:
`lever | value | load-verified? | R-paused | R-running (or R-bench) | verdict | notes`.
Publishability (repo CLAUDE.md): all committed paths `$HOME`-/repo-relative or `<REDACTED>`;
quoted log lines get path prefixes stripped; committed screenshots show city view only (no
account-bearing menus/overlays). Raw run logs and `.gputrace` stay in `~/cs2-patch/perf-runs/`
(outside the repo), only reduced numbers are committed.

## 3. Lever matrix

Tags: **[GPU]** attacks the GPU bound · **[CPU-sim]** pays in big-city/sim regime · **[pacing]**
frame-time consistency & latency · **[validity]** measurement infrastructure · **[quality]** free
visual upgrade. Confidence: measured / documented (source-read) / community / speculative.

### 3A. Resolution levers — **FAMILY CLOSED 2026-08-24** (adjudicated live; see results doc)

The feasibility question was answered by measurement: **Fullscreen Windowed locks the backbuffer
to desktop resolution** — the in-game resolution dropdown is inert in borderless, so A1–A3 as
designed cannot run in the pinned display mode. MetalFX works mechanically (HUD-verified) but only
as supersampling here, which measured softer AND slower. Street names are world-rendered, so every
scaling route (DRS included) softens them. James adjudicated the whole family by eye: daily driver
= **native 1080p + High SMAA, DRS Disabled**; DRS-Constant@75–80% remains an optional FPS-back
dial. Full verdict table + mechanism findings: docs/perf-pass-results.md. GOTCHAS has the traps.

| # | Lever | Design | Confidence |
|---|---|---|---|
| A1 | **[GPU]** In-game 1280×720, no MetalFX | The sizing control arm. DXMT's present blit scales via **nearest-neighbor** sampling when game res ≠ drawable (`dxmt_presenter.cpp:153-186`; constexpr sampler defaults, `dxmt_command.metal:293,322-324`) — expect visibly blocky output at non-integer 1.5×; this cell is FPS data (720p = 44% of 1080p pixels), not a quality candidate. | documented |
| A2 | **[GPU]** MetalFX spatial: `CS2_METALFX=1` + `DXMT_CONFIG="d3d11.metalSpatialUpscaleFactor=1.5"` + in-game 1280×720 | Renders 720p, MetalFX-upscales to exactly 1920×1080. ⚠ **Never at default factor 2.0 with 1080p in-game — 4K drawable, strict regression** (`d3d11_swapchain.cpp:142`). Verify: HUD `MetalFX: Spatial` + `Scale: 1280x720->1920x1080`; if `Scale:` reads `1920x1080->…`, the swapchain did not follow the in-game resolution — investigate, don't count. Risk: spatial artifacts; **UI upscales too** (soft text). | documented |
| A3 | **[GPU]** MetalFX spatial, milder: in-game 1600×900 + factor 1.2 | The quality-conscious point on the same curve (69% of pixels). Same verification. | documented |
| A4 | **[GPU]** DLSS→MetalFX-Temporal via NVEXT spoof — **PARKED: preconditions measured ABSENT** | DXMT v0.80 maps DLSS onto `MTLFXTemporalScaler` (`nvngx.cpp:45-150`) behind `DXMT_ENABLE_NVEXT=1` + NVIDIA adapter spoof — potentially the highest-quality resolution lever (native-res UI). But nvngx.dll/nvapi64.dll are build products the PK fork build did not ship (measured; `meson.options` defaults off). Executing A4 = its own prep project: rebuild the fork with `-Denable_nvapi=true -Denable_nvngx=true`, install both DLLs + overrides. Not part of this pass unless P1's spatial results disappoint enough to justify it. | speculative |

Decision shape after P1: A2/A3 are TRADE verdicts — James eyeballs the saved comparison
screenshots at the FPS gained and picks the daily point. A1 is pure sizing data.

### 3B. DXMT tunables — pacing + closed switches (Phases P1/P3)

| # | Lever | Design | Confidence |
|---|---|---|---|
| B1 | **[pacing]** `d3d11.preferredMaxFrameRate` = **30 or 60** (re-derived 2026-10-10; ~~40, which divided 120~~ — 40 does **not** divide 60 and would judder) | Metal-coordinated cap via `presentDrawableAfterMinimumDuration` (`d3d11_swapchain.cpp:762-766`; works with vsync off; mechanism load-verified 2026-08-24, results:55). On 60 Hz, vsync-on ≡ cap 60. Pick 30 vs uncapped/60 only after the Studio live-city HUD reading (#2); test against vsync off. Judged on feel + frame-time consistency over the fixed window (instrument per P0's validation; eyeball fallback stated per row). | documented |
| B2 | **[pacing]** In-game max-frame-latency slider — **present** (Options, set 2 — results:100-101; no Settings.coc key, set it in-game) — **still needs a measured cell** | DXMT's frame-latency depth (default 3 ≈ 67 ms at 45 FPS) has NO config knob (`dxmt_command_queue.hpp:153`), but the game-side `SetMaximumFrameLatency` path works (`d3d11_device.cpp:1244-1245`). Check the options; if present, test at 2. | documented |
| B3 | **[validity]** Keep-off inventory — CLOSED by source read, no cells | `sampleNaNToZero`, `defuseFma` (add ALU work), `ignoreMapFlagNoWait` (adds stalls), `forceSDR` (no-op on SDR panel), `handleAltTab` (inert + fixed upstream), `shaderMetalVersion` (already max; orphans shader cache), `DXMT_SHADER_CACHE=0` (never), `DXMT_USE_DEFAULT_METAL_CACHE` (leave), `DXMT_LOG_LEVEL` (leave at info — `none` hides load signals), fork-only `DXMT_RESOURCE_RESIDENCY`/`DXMT_NVEXT_GUID` (semantics unknown). | documented |

### 3C. In-game settings — visual trades + free quality (Phase P2)

Windows-measured percentages don't transfer to Apple TBDR under translation — that's why we
re-measure. P2 cells run **on top of the chosen P1 point** (still one variable per cell against
that measured base). If James isn't available to adjudicate P1's TRADE, P2 proceeds provisionally
on the highest-FPS artifact-free point, re-adjudicated later.

| # | Lever | Design | Confidence |
|---|---|---|---|
| C1 | **[GPU]** DynamicRes Automatic→Constant/off | The M0 prerequisite, and itself a lever: Constant beats Automatic for consistency. If A2/A3 land, DRS stays off (MetalFX owns scaling). | community |
| C2 | **[GPU]** Level of Detail Med→Low | One of the two biggest remaining tickets (GN ~29% launch-era; ~21% 2026 — Windows numbers). Cost: pop-in. TRADE screenshots per protocol. | community |
| C3 | **[GPU]** Shadows Low→Disabled — *sizing cell* | GN 37% launch-era disabling entirely. Probably not the daily setting; bounds the headroom Low still costs. | community |
| C4 | **[GPU]** Combined small-ticket sweep: Clouds Off + Fog Off + AO Off + SSR Off + Terrain/Water Low | ~0.2–1 ms each expected; one combined A/B cell, decompose only if the combined delta exceeds ~2 ms. | community |
| C5 | **[quality]** Texture Quality Med→High | Expected ~0 GPU ms with 36 GB unified — KEEP per the [quality] verdict rule (flat FPS + no hitching). Watch for virtual-texturing streaming stalls; hitching = REVERT. *James live-tested Med→High mid-session 2026-08-23 with no observed FPS change — encouraging, not yet a controlled cell.* | community |
| C6 | **[validity]** Regime guard | As FPS rises, watch for the GPU→CPU-bound crossover (GPU ms < 1000/FPS and FPS stops responding to GPU levers; plausibly ~55–80 FPS here). Past it, C-levers read flat and that's the *regime*, not the lever. Mark such rows CLOSED(regime), not DEAD. | documented |

### 3D. Unity boot.config + host — CPU-side, late-game insurance (Phase P4)

boot.config lives at **`<game dir>/Cities2_Data/boot.config`**. Discipline: game NOT running for
any edit; `cp boot.config boot.config.bak` beside it before the first edit; verify boot after
each change; a game update may rewrite it (a KEEP joins the launcher's repatch-style check).
⚠ **2026-10-10: the 1.6.2f1 update DID rewrite it** (only `build-guid` changed), and launcher step
2b's `steam://validate` restores depot files too — so `cat boot.config` after every launch, re-take
`.bak` after any update, and note that no launcher re-assert exists yet (a D-row KEEP needs one
built before P5 can ship it).
**P4 opens with M0-L:** late-game save, unmodified config, R-running, ≥2 runs — the scene-specific
baseline + noise floor that all D-verdicts are computed against (never the P0-scene numbers).
⚠ **Instrument (2026-10-10):** `-benchmark` loads a save hard-coded by content id (`Game.dll`:
`kBenchmarkSaveCid`; no save argument), and its scene is already the sim-bound late-game regime
(gpuBound 18–20 % on the Studio). So **M0-L = R-bench on the bundled save, ≥3 runs**; a user
late-game save is an optional James-run HUD cross-check, named by file before the run, its path
never committed. **Every D-cell must end in a graceful quit**, never perf-bench's SIGTERM
(`perf-bench.sh:78-80`): the allocator report and the `Job.Worker` list are written only on a
clean exit (0 `Memory Statistics` lines in every SIGTERM'd Player.log, 2026-10-10). Use
`win-resize-driver.exe close` as `scripts/boot-verify.sh` does; a D-cell whose Player.log lacks
`Game terminated successfully` + `Memory Statistics:` is **VOID**. **BUILT 2026-10-10:** `perf-bench.sh` now ends with
WM_CLOSE (SIGTERM only as fallback) and records `teardown` + `graceful` in each row, copying
Player.log beside the run log — tested: `teardown-test-wmclose` graceful=yes (allocator report +
17 `Job.Worker`s), `CS2_TEARDOWN=sigterm` mutant graceful=no.
Unity ignores unknown keys silently, so each D-row has its own load signal:

| # | Lever | Design + load signal | Confidence |
|---|---|---|---|
| D1 | **[CPU-sim]** `job-worker-count` = values **re-derived for 18 cores** before the cell (~~10, then 8 — sized for 14~~) | Workers = cores−1 = **17** on the Studio (allocator report lists `Job.Worker 0…16`; PhysX 18). Can only lower, never raise. **Load signal: the highest `[ALLOC_TEMP_Job.Worker N]` in the graceful-exit allocator report = configured − 1** (cheaper and validated, unlike `sample` under Rosetta). | community |
| D2 | **[CPU-sim]** `memorysetup-bucket-allocator-block-count=4` | Best-evidenced CPU lever: failed fast-path allocs (count re-derived at M0-L). +12 MB. **Load signal: `[ALLOC_BUCKET]` `Used Block count` > 1 and summed `Failed count` drops vs M0-L** (the report has no configured-value echo). | measured |
| D3 | **[CPU-sim]** `memorysetup-temp-allocator-size-main=8388608` | Overflows/frame re-derived at M0-L (~~0.4~~; the 2026-10-10 boot-verify scene shows ~1.7). +4 MB. Separate cell from D2. **Load signal: `[ALLOC_TEMP_MAIN]` `Initial Block Size 8.0 MB` (default 4.0 MB) + Overflow Count vs M0-L.** | measured |
| D4 | **[GPU?]** Second display disconnected during play | Cheap A/B; plausibly 0–1 ms; may be zero (presentation is Direct). Don't re-plug mid-session (mode-change class). James unplugs the U2720Q before launch (human step); both arms assert `Player.log` `Window resolution: 2560x1440` (the U2720Q's unrotated 3840×2160 has leaked into a resolution reading before). Scheduled in P3 (§4). | speculative |
| D5 | **[validity]** ~~High Power Mode for long sessions~~ **CLOSED/SKIP (precondition absent, 2026-10-10)** | The Mac Studio has no High Power Mode (`pmset -g cap`: `lowpowermode` only) and the desktop chassis removes the 14" thermal-sag premise. A plain 45-min soak for GPU-ms creep stays optional, recorded as a curve. | measured |

### 3E. Closed — measured/proven dead, do not revisit

- **esync/msync**: env vars inert on stock wine (never shipped there); launcher line removed as
  part of this pass's harness edit. Porting marzent's msync = *future* CPU-side lever, wrong
  bound today; parked.
- **Game Mode** (measured Off) · **`dxgi.handleAltTab`** (inert + fixed upstream) ·
  **taskpolicy/QoS** (GPU-bound; renice needs sudo, marginal) · **Rosetta tunables** (none exist;
  only the first-run-after-rebuild rule) · **App Nap** (disabled by stock wine per source read —
  local tree not retained; unverified-local, low stakes) · **winemac.drv registry knobs** (no
  perf switches; CaptureDisplaysForFullscreen touches the mode-change freeze class) · **memory
  pressure** (non-issue at 36 GB; 64 GB on the Studio).
- **`preload-shaders`** (string absent from this UnityPlayer.dll) · **`gc-max-time-slice`**
  (already Unity's default 3) · **gfx-jobs toggles** (native no-op on D3D11; plain off = pure
  regression) · **`-nolog`** (kills diagnostics for a sub-1% CPU win — permanent decline) ·
  **`-force-d3d12`** (no backend in DXMT) · **in-game DLSS without the spoof** (option absent on
  Apple GPU) · **DXMT frame-latency config knob** (doesn't exist in v0.80) ·
  **`d3d11.maxFeatureLevel`** (present in the fork binary, strings-verified; behavior
  undocumented — still do NOT use).

## 4. Phases

| Phase | What | Gate to next |
|---|---|---|
| **P0** | Harness live (`perf-run.sh` + `CS2_ARGS` passthrough — DONE with this fold) · benchmark probe (param + menu; settings-honoring check) · instrument-validation cell (HUD logging) · **M0 re-baseline + noise floor (≥3 runs, both reading classes)** · KEEP margin + composed margin fixed in writing · M1 capture taken (non-gating) | clean baseline + floor + instrument decision recorded |
| **P1** | Resolution levers A1→A2→A3, one per launch (A4 parked) | curve measured; TRADE screenshots saved; point picked (provisionally if James away) |
| **P2** | Settings matrix C1–C5 on top of the chosen P1 point | all C-rows verdicts |
| **P3** | **Studio M0 first (§2)**, then pacing & experience: B1 (cap 30 / 60), B2 (slider present), vsync decision, D4 — every cell vsync off unless vsync is the lever | pacing chosen on feel + frame-time consistency |
| **P4** | ~~Graceful-quit teardown built first (§3D)~~ (built 2026-10-10), then **M0-L** (R-bench, ≥3), then D1–D3 (boot.config; game-not-running edits; `cat` after each launch) · ~~D5 soak~~ CLOSED | verdicts or explicit CLOSED/SKIP |
| **P5** | **Compose + re-measure**: baseline + every KEEP as one profile, ≥2 runs; if P4 produced any KEEP, re-measure on BOTH scenes (bench scene vs the Studio clean baseline; late-game vs M0-L); ship | composed profile beats the **Studio** clean baseline by the margin fixed at **Studio M0** |

**P5 ships:** launcher defaults for unconditional KEEPs (same override pattern as `CS2_HUD`) ·
README numbers + settings table (**every number labelled with its machine**; reduced numbers only, no raw logs, no SteamID-named paths) · as-built header here · AppleGamingWiki draft (**a draft in the repo — posting it is James's manual step**) · a launcher re-assert for any boot.config KEEP · PLAN.md pointer
to §0 as the standing ethos. *(Launcher hygiene — the inert `WINEESYNC/WINEMSYNC` line — was
pulled forward into the P0 harness edit, game-not-running verified.)*

## 5. Exit criteria

1. Clean re-baseline + noise floors (both reading classes) recorded; instrument decision
   recorded; M1 capture taken (read deferred until Xcode).
2. Every §3A–§3D lever row carries either a **measured verdict + load-verification mark**, or an
   explicit **CLOSED/SKIP mark citing its reason** (source-read, precondition failed, regime
   guard) — an auditor can tell "unmeasured" from "deliberately not a cell".
3. Composed profile re-measured as a whole (both scenes if P4 kept anything); beats the Studio
   clean baseline by the margin fixed at Studio M0 (§2) (aspiration: ≥25% FPS at a quality point James accepts —
   else the pass documents why not, which is itself a valid outcome).
4. P5 ship list complete; no stale numbers in README/PLAN; new GOTCHAS entries for anything that
   surprised us.
5. Any *defect* discovered (vs tuning) gets its own ledger entry and, if upstream-worthy, a note
   to dxmt#206 / the wiki draft.

## 6. Rollback

P1–P3: unset env var / re-select in Options → Graphics, or restore the saved `Settings.coc` base
(complete-value edits are honoured — GOTCHAS 2026-08-24; partial flips are the trap). A4 (if ever unpacked): unset the spoof vars — the next launch auto-deletes the spoofed
registry values itself (`dxgi.cpp:34-37`); verify the adapter reads Apple in that same launch
(the empty NVIDIA parent keys remain, cosmetic). P4: delete the added key line, game not running —
**not** a blind `.bak` copy, which after an intervening game update would write a stale
`build-guid` over the new build (the update changed exactly that line, 2026-10-10). Launcher edits only while the game is not running (standing rule).

## Review corrections (triple-check 2026-08-23, pass 1)

Six lenses (correctness · methodology · platform-facts · builder-sim · test-plan · publishability),
all six verdicts build-ready-with-fixes; folded above. The load-bearing corrections:
harness mechanics didn't exist (no stderr capture, no game-args passthrough → `perf-run.sh` +
`CS2_ARGS`, now normative in §2) · `MTL_HUD_LOGGING_ENABLED` existence is *contested between
lenses* → settled empirically by P0's instrument-validation cell (`MTL_HUD_PATH` exists in the
binaries; semantics unknown) · Xcode absent → M1 demoted to non-gating · A4 preconditions
measured absent → parked with remediation path · D-rows had no load signals → census/allocator
echoes added + M0-L late-game baseline · verdict definitions, crash rule, ≥3-run floor, session
control, fixed reading windows, Fullscreen-Window pin, TRADE screenshots, publishability rules
added · A1 blit is nearest-neighbor (not "linear") · fork config surface is a superset of v0.80
(`maxFeatureLevel` present; 2 unknown env vars) · NVEXT rollback simplified (auto-delete on
unset) · boot.config full path + game-not-running symmetry · exit criterion 2 rewritten to admit
CLOSED/SKIP · ephemeral workflow citation demoted in favor of the durable file:line cites.


## Review corrections (re-check 2026-10-10, pass 2 — the Mac Studio)

Re-check of the **remaining** work (P3–P5) after the move from the M3 Max MacBook (120 Hz external)
to the Mac Studio M5 Max (60 Hz Studio Display, macOS 27.0.1, game 1.6.2f1). Two lenses (premises;
builder-simulation + test-plan), read-only, no launches; every BLOCKER spot-checked inline. All
corrections below are already folded into §1–§6.

- **[BLOCKER] No valid floor or baseline on this machine** — P0's 1.03 FPS floor is the M3 Max at
  22 FPS; the Studio has 2 clean samples. → Studio M0 (§2), P5 gate and exit criterion 3 re-pointed.
- **[BLOCKER] Vsync-on is a 60 FPS cap at 60 Hz** (`d3d11_swapchain.cpp:762-766`; spot-checked in
  the fork) and every saved base + the C75 Studio series ran `"vSync": true`. → vsync-off rule made
  mandatory; C75 annotated (the cap can only have held numbers down, so its verdict stands).
- **[BLOCKER] D-row load signals are destroyed by SIGTERM** — 0 `Memory Statistics` lines in the
  SIGTERM'd Player.log / Player-prev.log, 1 in boot-verify's graceful-exit log (spot-checked).
  → graceful-quit teardown is P4's first task; D-cells without it are VOID.
- **[BLOCKER] M0-L cannot load a user save through `-benchmark`** (hard-coded content id). → M0-L =
  R-bench on the bundled save; user save is an optional James-run cross-check.
- **[SHOULD-FIX]** B1's 40 does not divide 60 → 30 / 60. D1's values sized for 14 cores → re-derive
  for 18; load signal = highest `Job.Worker N`. D5 impossible (no High Power Mode; spot-checked
  `pmset -g cap`) → CLOSED/SKIP. boot.config rewritten by the update and restorable by step 2b's
  validate → `cat` after each launch, `.bak` re-taken, rollback by line delete. `settings-series.py`
  unrunnable → flagged in the header. `perf-run.sh`'s "signal missing" warning could never print
  (`||` bound to `sed`) → fixed in the same commit as this fold.
- **[MINOR]** B2's slider is present (needs a cell, not discovery); D2/D3 load-signal wording;
  allocator counts session-dependent; Xcode now installed; 36 → 64 GB; §6's Settings.coc rule
  brought in line with GOTCHAS; README numbers to be machine-labelled; AGW draft posting is James's.
- Verified unchanged: boot.config path and key set, Unity 2022.3.71f1 / LegacyJobified, the DXMT
  B1/B2 source cites in both v0.80 and the fork, B1's key in the shipping `d3d11.dll`, the
  launcher's `CS2_HUD` / `CS2_ARGS` hooks.

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-08-23 | triple-check pass 1 | correctness · methodology · platform-facts · builder-sim · test-plan · publishability | Workflow fan-out, 6 agents, structured findings; BLOCKERs spot-checked inline | Fable 5 | `2cf8f5e` | **build-ready-with-fixes — corrections folded, build may start** |
| 2026-10-10 | **pass 2 — re-check after the machine change** (P3–P5 only) | premises (architecture + correctness + platform-facts) · builder-simulation + test-plan (+ security/publishability in both) | 2 independent agents, read-only, ~20 tool calls each; every BLOCKER spot-checked inline | Opus 5.5 ×2 + Opus 5.5 synthesis | `9a953c1` on the Mac Studio | **P3 build-ready-with-fixes (after Studio M0) · P4 + P5 needs-rework** — corrections folded |

Key paths: `~/cs2-patch/launch-cs2-dxmt11.sh` · `scripts/perf-run.sh` · `scripts/make-shortcut.sh` ·
`docs/plans/build-wine1116-dxmt-engine.md` · `GOTCHAS.md` · `<game dir>/Cities2_Data/boot.config` ·
DXMT v0.80 source refs per row.
