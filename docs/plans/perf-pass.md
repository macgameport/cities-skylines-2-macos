# The deep performance pass — squeeze the promoted 11.16 stack

> **Status: check-it'd 2026-10-13 — P4 build-ready-with-fixes (pass 3, a fitted re-check of P4; corrections
> folded below, § Review corrections pass 3). P4 = D2 (**ran 2026-10-13: DEAD**), then D1 at pre-registered values (**D1a = 12 ran 2026-10-14: DEAD; D1b = 16 next**), each in a
> control-bracketed session; D3 CLOSED by measurement; no separate M0-L series.**
> Pass 2: check-it'd 2026-10-10 — P3 build-ready-with-fixes, P4 + P5 needs-rework (a
> re-check after the move to the Mac Studio; corrections folded below, § Review corrections pass 2).
> **Studio M0 RAN 2026-10-12** (floor 0.13 / 0.18 FPS; KEEP + composed margin 1 FPS ≈ 2.2 % of the
> clean baseline 45.02; ledger C76) — **P3 may start**. **P3 2026-10-12/13: B1 (cap 30, cap 60) and B2 (latency 1) measured, no lever kept (C77 tail drift, C78); remaining P3: the vsync decision on feel, and D4.** P5 was re-checked only where P4 touches it
> (one scene; the boot.config re-assert and its off-switch) — re-check P5's ship list before P5 starts. Pass 1: check-it'd 2026-08-23 — build-ready-with-fixes.
> **🔧 As-built (2026-08-24):** P0–P2 executed and substantially measured — instrument = the
> game's own `-benchmark` (structured per-frame output; autonomous cycles via
> `scripts/perf-bench.sh`); settings cells went fully autonomous after the Settings.coc
> edit experiment (GOTCHAS refined). §3A closed by live adjudication (borderless locks
> backbuffer res). Composed profile measured +11.6% avg / +55% 1%-low on the stress scene.
> Deviations from plan: MetalFX A-cells impossible in the pinned display mode (replaced by
> DRS/filter cells); HUD-logging instrument dead (benchmark series superseded it); settings
> edits via file (not menu) after the controlled experiment. Remaining: P3 pacing cells,
> P4 CPU cells (D2, D1 — baseline = Studio M0's scene, controls in every session), P5 ship. Verify against: docs/perf-pass-results.md ·
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
| Bound | **GPU-bound** at baseline settings — **the M3 Max finding.** On the Studio bench the frame is mostly CPU-frame-bound: gpuBound 13–28 %, cpuFrame avg 13.4–15.2 ms against a ~21 ms frame (2026-10-12/13, pass 3) | Metal HUD, ledger, results.jsonl |
| Baseline settings | 1080p@120Hz · Global=Custom · DynamicRes=Automatic · AA=Low SMAA · Clouds=Med · Fog=on · Volumetrics=Low · AO=Med · GI=Off · Reflections=Med · DoF=Off · MotionBlur=Off · Shadows=Low · Terrain/Water/LOD/Texture=Med · Display Mode=Fullscreen Window | V3 row, ledger |
| Presentation | Direct; DXMT always sets `displaySyncEnabled=false` — ALL pacing is `presentDrawableAfterMinimumDuration` (`dxmt_presenter.cpp:19`) | V-session + source |
| Unity / game build | **Unity 2022.3.71f1**, game 1.6.0f1 → **1.6.2f1 since 2026-10-10** (Unity unchanged, LegacyJobified unchanged); maintained by Iceflake Studios since the 2026 perf push (external claim) | globalgamemanagers + Player.log |
| `WINEESYNC=1 WINEMSYNC=1` | **INERT** — stock winehq wine has never shipped esync/msync (whole-tree grep: zero hits); launcher vars were Porting-Kit habit | research, measured |
| `gfx-enable-native-gfx-jobs=1` | **no-op on D3D11** — Player.log: `Rendering Threading Mode: LegacyJobified`; don't spend a run on it, don't turn plain gfx-jobs off | Player.log, measured |
| Allocator telemetry | Failed fast-path (bucket) allocs in Player.log's allocator report — **session-length dependent**; read the FIRST `[ALLOC_BUCKET]` section only (one shared allocator printed four times, identically — summing all four quadruples it, the likely source of the old ~17M). Daily-driver bench sessions: 5.99–6.66 M ≈ 1020–1061 per frame (pass 3; per frame = ÷ the total of `[ALLOC_TEMP_MAIN]`'s `Peak usage frame count` histogram — process frames, ~5.7k–6.4k per run, NOT results.jsonl `framesRendered` (~4,300)); compare per frame, same config, same session. ⚠ The report is written **only on a graceful exit** (absent from every SIGTERM'd perf-bench Player.log) | Player.log, measured |
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
- **`CS2_PROFILE=off` (to keep the launcher profile off a cell's DRS block) must be paired with
  Screenmanager "Use Native"=1 written before every cycle** — the profile is two writes, the game
  resets Use Native to 0 on exit, and without it the cell runs at the last in-game size (1920×1080 on
  2026-10-12, a VOID series). Gate every cycle on Player.log `Window resolution`. (results.jsonl's
  `resolution` field is NOT the render size — it read `1920x1080 @60Hz` on every verified 2560×1440 run.)
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
  cells (thermal state, background churn, silent updates). **For control-bracketed P4 sessions (pass 3)
  the opening pair is checked against the recorded base with the 1 FPS KEEP margin, not the floor** —
  unmodified runs spread 0.75 FPS within one day (2026-10-13), so the 0.13 floor from M0's three runs
  trips on ordinary noise; verdicts then use that session's controls only (§2 [CPU-sim] rule).
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
- **[CPU-sim] rows (P4; pass 3):** the primary reading is `averageFps` against the same-session
  bracketing controls, with the 1 FPS margin (six unmodified runs on 2026-10-13 spread 0.75 FPS).
  Guard: `simulationTicks` saturates near 8,300 whatever the frame rate (latency 1 at 41.5 FPS still
  read 8,316) and cannot show a sim gain; **a lever cycle more than 60 ticks below the session controls'
  minimum is flagged sim-slowed and cannot be a KEEP** (unmodified rows span 8,237–8,340 across three
  days, a same-session pair 17–20; cap 30 read 8,036 / 8,226). `cpuGameMs` and
  `cpuFrame` corroborate only against same-session controls; tails are advisory (C77). A key not
  applied (signal at its default) makes the cell VOID, never DEAD.

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
**✅ Ran 2026-10-12 (C76, `docs/perf-pass-results.md` § Studio M0):** daily driver 47.75 FPS (floor
0.13), clean baseline 45.02 (floor 0.18), all at 2560×1440 with vsync off. **KEEP margin = composed
margin = 1 FPS ≈ 2.2 % of 45.02** (floors under the 1 FPS minimum; the KEEP rule applied to both).

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
| B1 | **[pacing]** `d3d11.preferredMaxFrameRate` = **30 or 60** (re-derived 2026-10-10; ~~40, which divided 120~~ — 40 does **not** divide 60 and would judder) | Metal-coordinated cap via `presentDrawableAfterMinimumDuration` (`d3d11_swapchain.cpp:762-766`; works with vsync off; mechanism load-verified 2026-08-24, results:55). On 60 Hz, vsync-on ≡ cap 60. Pick 30 vs uncapped/60 only after the Studio live-city HUD reading (#2); test against vsync off. Judged on feel + frame-time consistency over the fixed window (instrument per P0's validation; eyeball fallback stated per row). **Bench 2026-10-12: cap 30 engages exactly (29.99 / 29.77) but frame-time stdev is 1.3–2.5× uncapped and simTicks 1–3 % lower — no bench case for 30; decision on feel (results § P3 B1). Bench 2026-10-13: cap 60 vs a same-session uncapped control — average −0.17 FPS (inside the margin), tails inside the spread of four same-day uncapped runs — indistinguishable from uncapped; no bench case for 60 either.** | measured (bench); feel pending |
| B2 | **[pacing]** In-game max-frame-latency slider — **present** (Options → Graphics → Main, under VSync; results:100-101) — **stored in Settings.coc as `"maxFrameLatency": N` beside `"vSync"`, written ONLY when not the default 2** (found 2026-10-13 by snapshot diff when James moved it 2 → 1; ~~no Settings.coc key, set it in-game~~ — the August "set 2" was the default, so no key appeared) — cells can be set by a complete-value edit. **Bench 2026-10-13: latency 1 = 41.6 FPS vs 48.1 at the default 2 (−13 %), 99 % GPU-bound — REVERT; keep the default (results § P3 B2).** | DXMT's frame-latency depth (default 3 ≈ 67 ms at 45 FPS) has NO config knob (`dxmt_command_queue.hpp:153`), but the game-side `SetMaximumFrameLatency` path works (`d3d11_device.cpp:1244-1245`). Check the options; if present, test at 2. | documented |
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
any edit; before the first edit record the pre-series sha256 + `build-guid` and keep a reference copy in
`~/cs2-patch/perf-runs/` (never a restore source — rollback is the line delete, §6); verify boot after
each change; a game update may rewrite it (a KEEP joins the launcher's repatch-style check).
⚠ **2026-10-10: the 1.6.2f1 update DID rewrite it** (only `build-guid` changed), and launcher step
2b's `steam://validate` restores depot files too. Validate fires only inside `apply_game_update`
(launcher `:244`) — an update pending AND the answer "update" — so **every P4 cycle runs with
`CS2_UPDATE=skip`**. **Mechanical asserts replace the eyeball `cat` (pass 3):** before and after every
cycle the key line count is 1 on a lever cycle and 0 on a control cycle, and `build-guid` equals the
pre-series value — a changed `build-guid` means an update ran and stops the series. Add a key by
appending `key=value\n` without normalising the file (mixed endings: LF lines, last line CRLF); remove
it by deleting that line, then assert sha256 = the pre-series hash. The reference copy lives in
`~/cs2-patch/perf-runs/`, outside the depot dir, and is never a restore source. The series' EXIT trap
waits for `Cities2.exe` to be gone before restoring `Settings.coc` and deleting the key line (the game
rewrites `Settings.coc` on exit). No launcher re-assert exists yet (a D-row KEEP needs one built before
P5 can ship it).
**P4's baseline is Studio M0's scene — no separate M0-L series (pass 3, 2026-10-13).** `-benchmark`
loads a save hard-coded by content id (`Game.dll`: `kBenchmarkSaveCid`; no save argument) — the same
bundled save P0–P3 used — and on the Studio it is the CPU-frame-bound regime (gpuBound 13–28 %).
The graceful logs already fix the defaults every D-row's load signal is read against (29/29 logs,
three days: 2026-10-10, -12, -13): `[ALLOC_TEMP_Job.Worker 0…16]`; `[ALLOC_TEMP_MAIN]` Initial 4.0 MB / Current 8.0 MB /
Overflow Count 9036; first `[ALLOC_BUCKET]` section Used Block count 1, Failed-count sum ≈ 1020–1061 per
frame on the daily driver (÷ the total of `[ALLOC_TEMP_MAIN]`'s `Peak usage frame count` histogram — process frames, ~5.7k–6.4k per run, NOT results.jsonl `framesRendered` (~4,300)) (the clean baseline reads 1269–1307 — compare the same config only). Tails and
`cpuGameMs` drift between sessions while FPS stays flat (C77; `cpuGameMs` 9.9 ms on 10-12, 10.5–11.2 on
10-13), so **every D-session is bracketed — 2 unmodified control cycles, 2 lever cycles per value, 2
controls (C C L L C C, or C C L L C C L L C C when levers share controls) — and verdicts compare against
that session's controls only.** The D-cells use the daily-driver `Settings.coc` under §2's guards. A user
late-game save stays an optional James-run HUD cross-check, named by file before the run, its path never
committed. **Every D-cell must end in a graceful quit**, never perf-bench's SIGTERM fallback
(`perf-bench.sh:97`): the allocator report and the `Job.Worker` list are written only on a
clean exit (0 `Memory Statistics` lines in every SIGTERM'd Player.log, 2026-10-10). Use
`win-resize-driver.exe close` as `scripts/boot-verify.sh` does; a D-cell whose Player.log lacks
`Game terminated successfully` + `Memory Statistics:` is **VOID**. **BUILT 2026-10-10:** `perf-bench.sh` now ends with
WM_CLOSE (SIGTERM only as fallback) and records `teardown` + `graceful` in each row, copying
Player.log beside the run log — tested: `teardown-test-wmclose` graceful=yes (allocator report +
17 `Job.Worker`s), `CS2_TEARDOWN=sigterm` mutant graceful=no.
Unity ignores unknown keys silently, so each D-row has its own load signal. **Read every signal
section-scoped, by an extractor that gates each cycle** (built with P4, with three mutants observed: a
SIGTERM'd log reads MISSING; a synthetic applied log reads the configured value; an unanchored regex
misreads) — not only perf-bench's two-marker graceful check, which a truncated report passes. The
field names are exact but not unique (`Overflow Count` / `Initial Block Size` in every temp section,
`Used Block Count` also under `[ALLOC_TEMP_JOB_ASYNC (Background)]`, four `[ALLOC_BUCKET]` copies,
`Background Job.Worker` lines). **A D-cell whose signal reads the default is VOID — recorded CLOSED
"key not honoured", never DEAD.**

| # | Lever | Design + load signal | Confidence |
|---|---|---|---|
| D1 | **[CPU-sim]** `job-worker-count` — **values pre-registered 2026-10-13 (pass 3):** D1a = **12** (the Performance-cluster count; frees 6 of 18 cores for the main/render/Background/PhysX threads and DXMT's encoder). D1b by a rule written before any result: D1a KEEP → **6**; otherwise → **16** (a minimal cut, in case 12 starves parallelism where a small cut relieves contention); D1b not a KEEP either → D1 CLOSED. Never ≥ 17 (indistinguishable from an ignored key). ~~10, then 8 — sized for 14~~ | Default 17 workers (`[ALLOC_TEMP_Job.Worker 0…16]` in 29/29 graceful logs; PhysX 18; `hw.logicalcpu` 18 = 6 Super + 12 Performance). Fewer workers can only help by cutting contention (17 Job + 16 Background + 18 PhysX workers plus main/render on 18 cores, under Rosetta). **Load signal: the highest `[ALLOC_TEMP_Job.Worker N]` = configured − 1**, anchored on the `[ALLOC_TEMP_` prefix (unanchored, `Background Job.Worker 15` matches — mutant observed: a configured 11 misread as 15). Lowest prior: run after D2. **D1a ran 2026-10-14: load-verified (12 workers), −0.15 FPS vs same-session controls — DEAD; cpuGameMs −5 % but FPS flat (results § P4 D1a). Next by the rule: D1b = 16.** | community |
| D2 | **[CPU-sim]** `memorysetup-bucket-allocator-block-count=4` | Best-evidenced CPU lever: the bucket allocator is full at its single block (`Used Block count 1`, `Peak Allocated bytes 4.0 MB` = `Large Block size 4.0 MB` in every graceful log) and fails to the slow path ≈ 1020–1061 times per frame on the daily driver. +12 MB. **Load signal: `Used Block count` > 1 in the FIRST `[ALLOC_BUCKET]` section, and that section's Failed-count sum (8 size classes) ÷ the total of `[ALLOC_TEMP_MAIN]`'s `Peak usage frame count` histogram — process frames, ~5.7k–6.4k per run, NOT results.jsonl `framesRendered` (~4,300) falls by > 4 % vs the same-session controls** (no configured-value echo; the four sections are identical copies). **Run 2026-10-13: load-verified (Used Blocks 1 → 4, failed/frame −18 %), +0.32 FPS vs same-session controls — DEAD, closed (results § P4 D2).** | measured |
| D3 | **[CPU-sim]** ~~`memorysetup-temp-allocator-size-main=8388608`~~ **CLOSED/SKIP — precondition absent, measured (pass 3, 2026-10-13)** | `[ALLOC_TEMP_MAIN] Overflow Count` is **9036 in all 29 graceful bench logs** (every config, three days, 5.7k–6.5k process frames) and 8964 in a 127k-frame live session: the overflows happen at boot/load, not per frame ("~1.7/frame" was a constant divided by a frame count). Steady-state main temp use is 32–64 KB; 10 frames per bench peak at 4–8 MB, and the block already grows to 8.0 MB. It cannot move averageFps, and a load-time cell (`loadingTimeSecs`, spread 30.8–36.4 s) would almost surely read DEAD. If re-opened: applied = `Initial Block Size 8.0 MB` + Overflow Count well below 9036; at 4.0 MB try the alias key `memorysetup-allocator-temp-initial-block-size-main` (also in the DLL) before calling it ignored. | measured |
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
| **P4** | Graceful-quit teardown (built 2026-10-10) · **pass-3 build:** the section-scoped load-signal extractor + its mutants, and a series script from the P3 template (boot.config append / assert / line-delete, `CS2_UPDATE=skip`, extractor gate) · then **D2**, then **D1a = 12 → D1b by the pre-registered rule**, each in a control-bracketed session · D3 CLOSED/SKIP · ~~M0-L series~~ (retired: same scene as Studio M0) · ~~D5 soak~~ CLOSED | verdicts or explicit CLOSED/SKIP, each D-cell load-verified |
| **P5** | **Compose + re-measure**: baseline + every KEEP as one profile, ≥2 runs; re-measured on the bench scene against the Studio clean baseline (one scene since pass 3; a user late-game save is an optional James-run HUD cross-check); ship | composed profile beats the **Studio** clean baseline by the margin fixed at **Studio M0** |

**P5 ships:** launcher defaults for unconditional KEEPs (same override pattern as `CS2_HUD`) ·
README numbers + settings table (**every number labelled with its machine**; reduced numbers only, no raw logs, no SteamID-named paths) · as-built header here · AppleGamingWiki draft (**a draft in the repo — posting it is James's manual step**) · a launcher re-assert for any boot.config KEEP (an idempotent line-add inside `ensure_patches()` — launcher `:147`, re-run by step 2b after an update — never a file copy, with an env off-switch in the `CS2_HUD` pattern that also removes the line) · PLAN.md pointer
to §0 as the standing ethos. *(Launcher hygiene — the inert `WINEESYNC/WINEMSYNC` line — was
pulled forward into the P0 harness edit, game-not-running verified.)*

## 5. Exit criteria

1. Clean re-baseline + noise floors (both reading classes) recorded; instrument decision
   recorded; M1 capture taken (read deferred until Xcode).
2. Every §3A–§3D lever row carries either a **measured verdict + load-verification mark**, or an
   explicit **CLOSED/SKIP mark citing its reason** (source-read, precondition failed, regime
   guard) — an auditor can tell "unmeasured" from "deliberately not a cell".
3. Composed profile re-measured as a whole (one scene since pass 3); beats the Studio
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
`build-guid` over the new build (the update changed exactly that line, 2026-10-10); after the delete, assert sha256 = the pre-series hash. **Once P5 ships a re-assert, a bare line delete is re-added on the next launch — rollback is then the re-assert's off-switch, or removing the re-assert.** Launcher edits only while the game is not running (standing rule).

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

## Review corrections (re-check 2026-10-13, pass 3 — P4)

Fitted re-check of **P4** after P3's cells ran. Two lenses, read-only, no launches: premises +
correctness + architecture; builder-simulation + test-plan (a draft series script dry-run on a /tmp copy
of boot.config, a load-signal extractor run over 29 graceful Player.logs, mutants observed). Both
verdicts build-ready-with-fixes; every BLOCKER spot-checked inline. All corrections folded into §1–§6:

- **[BLOCKER] M0-L defined twice, contradictorily** ("late-game save, R-running, ≥2 runs … never the
  P0-scene numbers" vs "R-bench on the bundled save, ≥3 runs") — and the bundled save IS the P0–P3 scene.
  → M0-L series retired; defaults table from 29 logs in §3D; every D-session control-bracketed (C77).
- **[BLOCKER] No primary reading for [CPU-sim] rows**, and `simulationTicks` saturates (~8,300 even at
  −13 % FPS). → §2 rule: averageFps vs same-session controls, sim ticks as a guard.
- **[BLOCKER] D1 named no values.** → pre-registered D1a = 12, D1b = 6 or 16 by a written rule.
- **[SHOULD-FIX] D3's premise falsified:** Overflow Count 9036 in 29/29 logs, a boot/load constant. → CLOSED/SKIP.
- **[SHOULD-FIX]** Load-signal names exact but not unique → section-scoped extractor gates each cycle;
  default-reading = VOID. `cat` after launch → mechanical key-count + `build-guid` asserts, `CS2_UPDATE=skip`.
  §6 vs a P5 re-assert → off-switch. §1 "GPU-bound" = M3 Max only. "~17M" = four copies summed.
  Stale `perf-bench.sh:78-80` cite → `:97`; perf-bench's header comment corrected in the same commit.
- **[MINOR]** The P3 series template's EXIT trap restores `Settings.coc` while the game may still be up
  (the game's exit write would win) → the P4 trap waits for `Cities2.exe` to be gone. A GOTCHAS entry for
  boot.config (rewritten by updates, restorable by validate) lands with the P4 build.
- Rejected / not folded: the reviewers' two D1 value sets (12 → 6, and 16 / 11) were merged into one
  pre-registered rule rather than picking either; an untested `CS2_ARGS=-job-worker-count` command-line
  route is noted as an idea, not a plan step.
- Verified unchanged: boot.config path and contents (no D-key present), the three key strings in this
  `UnityPlayer.dll`, 18 cores (6 + 12), PhysX 18, the WM_CLOSE teardown 29/29, validate's trigger path.

### Fold verification (same day, one fitted agent over `b9b50b0`)

Verdict fold-needs-fixes, no blockers; all fixed in the next commit and spot-checked inline: the old
"`cp boot.config boot.config.bak` beside it" survived in §3D's discipline line (→ reference copy outside
the depot, never a restore source); "per frame" named no denominator (→ the `[ALLOC_TEMP_MAIN]` frame
histogram total, ~6.2k, not `framesRendered` ~4.3k — measured 6,605,892 / 6,239 = 1,059); §2's session
control still demanded the 0.13 floor (→ 1 FPS margin for bracketed P4 sessions); the sim-ticks guard had
no tolerance (→ 60 ticks below the controls' minimum = sim-slowed, cannot KEEP); C79's tick range missed
the 10-10 rows (8,237); 0.76 → 0.75; "three sessions" → three days; gpuBound 13–27 → 13–28 %; PLAN.md's
"P5 unblocked" phrase; results.jsonl `resolution` is not the render size (noted in §2).

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-08-23 | triple-check pass 1 | correctness · methodology · platform-facts · builder-sim · test-plan · publishability | Workflow fan-out, 6 agents, structured findings; BLOCKERs spot-checked inline | Fable 5 | `2cf8f5e` | **build-ready-with-fixes — corrections folded, build may start** |
| 2026-10-10 | **pass 2 — re-check after the machine change** (P3–P5 only) | premises (architecture + correctness + platform-facts) · builder-simulation + test-plan (+ security/publishability in both) | 2 independent agents, read-only, ~20 tool calls each; every BLOCKER spot-checked inline | Opus 5.5 ×2 + Opus 5.5 synthesis | `9a953c1` on the Mac Studio | **P3 build-ready-with-fixes (after Studio M0) · P4 + P5 needs-rework** — corrections folded |
| 2026-10-13 | **pass 3 — fitted re-check of P4** (P5 only where P4 touches it) | premises + correctness + architecture (+ publishability) · builder-simulation + test-plan | 2 independent agents, read-only, ~20 tool calls each; draft series dry-run + extractor over 29 logs + mutants; every BLOCKER spot-checked inline | Opus 5.5 ×2 + Opus 5.5 synthesis | `a2237f0` on the Mac Studio | **P4 build-ready-with-fixes** — corrections folded; fold verified by one fitted agent (Opus 5.5) → 8 text fixes, re-folded |

Key paths: `~/cs2-patch/launch-cs2-dxmt11.sh` · `scripts/perf-run.sh` · `scripts/make-shortcut.sh` ·
`docs/plans/build-wine1116-dxmt-engine.md` · `GOTCHAS.md` · `<game dir>/Cities2_Data/boot.config` ·
DXMT v0.80 source refs per row · (pass 3) `scripts/perf-bench.sh` · `launchers/launch-cs2-dxmt11.sh` (`ensure_patches`, `apply_game_update`) · `<game dir>/UnityPlayer.dll` key strings · `~/cs2-patch/perf-runs/*-Player.log`.
