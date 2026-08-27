# Retina / native-swapchain sharpness experiment (laptop panel)

> **Status: Triple-checked 2026-08-26 — build-ready-with-fixes (pass 1 + fitted pass 1b, all corrections folded).**
> **🔧 As-built (2026-08-26, same session):** executed b0 ×3 · r0-native ×3 · accidental 1920×1200
> ×1; **r1/r2 not run** — r0 passed its gate (median gpuMs.average 36.42 vs b0 32.31 = **1.127× ≤
> 1.15**, shots sharp, UI normal-sized), making DRS-assisted native moot. **Outcome: matrix row 4,
> full revert, byte-verified** — not on quality (native passed every gate) but because stable
> adoption needs a pre-boot `Screenmanager Resolution Use Native=1` assert in the launcher, outside
> this plan's declared blast radius ("launcher scripts are not touched"). Deviations: (1) the
> results-row `resolution` field measures Unity's emulated *display-mode* view, not the swapchain —
> arbiter moved live to `Player.log` "Window resolution" + HUD (validity-table criterion as
> mis-specified); (2) the game's saved-1920×1200 ratchet (GOTCHAS § Retina mode, trap 2) — re-derived
> and re-persisted to both layers on every exit, surviving pre-boot fixes of both — is the adoption
> blocker; (3) shot cadence trimmed to 1/run after b0. Verify against: `~/cs2-patch/perf-runs/`
> results.jsonl rt- rows · GOTCHAS § "Retina mode" · docs/perf-pass-results.md § "Retina series".
> **Decision pending James** (PLAN.md § Decision pending): launcher assert (3 lines, one-line
> revert) vs attended in-game dropdown test.
> Tracking: PLAN.md § "Retina / native-swapchain experiment" (section created at build time;
> personal-tier repo, no issue tracker). Raw run artifacts stay in `~/cs2-patch/perf-runs/` per the
> publishability rule; only reduced numbers and decisions land here.

James, 2026-08-26: playing on the built-in panel (no external display), *"resolution has changed on
my laptop screen and things dont look very clear"* — then, after diagnosis: *"run the retina +
metalfx experiment."* Scoping note up front: **the MetalFX half of that phrasing is dropped, with
receipts** (§2). What survives is the half that can work: flip winemac.drv into Retina mode so the
borderless swapchain becomes the panel-native 3024×1964, and let the game's own DRS + upscale
filter manage render cost at that swapchain — measured against a fresh same-day baseline.

## 0. Why it's soft today (verified mechanism, 2026-08-26)

Presentation chain on the built-in panel, as measured this session:

```
internal render (DRS×swapchain) → [EASU when DRS on] → swapchain 1512×982
  → CAMetalLayer at contentsScale 1 → compositor ×2 upscale → panel 3024×1964
```

Numbered facts, each read from disk/system/source this session (not recalled):

1. Panel native 3024×1964 Retina (`system_profiler SPDisplaysDataType`); macOS desktop logical
   1512×982 at default scaling (Finder desktop bounds `0,0,1512,982`). One display connected.
2. **Wine Retina mode has never been enabled in this prefix**: `RetinaMode` = 0 hits in both
   `user.reg` and `system.reg` (the `[Software\\Wine\\Mac Driver]` key exists, valueless for this
   option); no mention in `~/cs2-patch/change-ledger.txt`. The engine's retina *machinery* is
   present (byte-search of `…/wine/lib/wine/x86_64-unix/winemac.so`: `setRetinaMode:` selectors on
   WineWindow/WineContentView/WineMetalView + both clip-cursor handlers); the option *parse* is
   verified against upstream wine-11.16 `dlls/winemac.drv/macdrv_main.c` `setup_options()` —
   `get_config_key(hkey, NULL, "RetinaMode", …)`, truthy = first char `y/Y/t/T/1`, read once per
   process at `macdrv_init`.
3. Game display mode is Unity **FullScreenWindow with native sizing** (`user.reg`:
   `Screenmanager Fullscreen mode…=dword:1`, `Screenmanager Resolution Use Native…=dword:1`,
   stored res `0x5e8×0x3d6` = 1512×982, refresh `0x1d4c0/0x3e8` = 120000/1000 = 120 Hz). The exe
   manifest declares `PerMonitorV2` DPI awareness (measured), so the game sees real pixels; under
   Retina mode, "native" follows the enlarged Wine desktop automatically — no in-game change
   needed. Local precedent: the swapchain already re-sized itself twice purely from desktop
   changes (1920×1080 external era → 1512×982 panel), no in-game edit either time.
4. Borderless pins the swapchain to desktop resolution; the in-game resolution dropdown is inert in
   this mode (GOTCHAS.md § "Resolution scaling on this stack", adjudicated live 2026-08-24). The
   `Settings.coc` saved `resolution` 1920×1200 (external-monitor era) is ignored on this panel.
5. Current `Settings.coc` (fresh read after James's 2026-08-26 session): DRS block
   `{enabled: false, isAdaptive: false, upscaleFilter: "EdgeAdaptiveScaling", minScale: 0.75}` —
   James disabled DRS in-game this morning. SMAA High + `outlinesMSAA: MSAA8x` retained; vSync on.
6. The HUD confirms the chain: live screenshot this morning showed `1512x982`, 40.28 FPS,
   GPU 25.43 ms (rain, ~4.1k pop city).

So today's blur = a 1512-wide render shown on a 3024-wide panel through a dumb compositor ×2 —
plus, whenever DRS was on, a second (internal) downscale below even that.

## 1. The change under test

Enable winemac.drv Retina mode so Wine's desktop = 3024×1964 physical pixels, making the borderless
swapchain panel-native (compositor scale stage disappears; DXMT presents 1:1 — its present blit
only resamples when game res ≠ drawable, `dxmt_presenter.cpp:153-186` via docs/plans/perf-pass.md
§3A/A1). DPI companion raised to 192 so DPI-aware Windows-side surfaces scale correctly.

**Scoping fact (wine 11.x, upstream-verified): RetinaMode deliberately ignores
`AppDefaults` per-app keys** (`setup_options()` passes `appkey=NULL` with the comment that DPI and
monitor sizes must be consistent prefix-wide). Prefix-global is the *only* scope — a future session
must not "improve" this into `AppDefaults\Cities2.exe` and conclude retina is broken. Blast radius
is acceptable: the only co-resident is the invisible `-silent` tray Steam; the visible store
wrapper (`CS2dxmt11-pk110.app`) is a separate APFS-cloned prefix (`make-steam-shortcut.sh` clones
the whole app) and is unaffected. Launcher scripts are not touched (env per-run only).

**Prefix-cold sweep — run before every registry write and every Settings.coc edit** (lsof-vs-prefix
attribution per the launcher's `_owns()`; never bare pgrep — argv attribution is the documented
trap, and `settings-series.py`'s `pgrep` guard is game-only, insufficient for registry work):

```bash
P="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport"
for p in $(pgrep -f 'steam|wine|Cities2' 2>/dev/null); do
  lsof -p "$p" 2>/dev/null | grep -q "$P/prefix" && echo "LIVE: $p"
done   # expect ZERO lines; any hit = stop, shut down via the launcher's documented path
```

The flip (after a clean sweep). `Fonts\LogPixels` currently **exists at dword:60 (96)** — a modify,
not an add. `Control Panel\Desktop\LogPixels` is the **primary** DPI source on wine 11.x
(win32u `sysparams.c`; the Fonts value is a legacy font-DPI fallback — written for hygiene, but CPD
is the lever if DPI ever misbehaves):

```bash
cp "$P/prefix/user.reg" "$P/prefix/user.reg.pre-retina-$(date +%Y%m%d-%H%M%S)"   # forensics only
WINEPREFIX="$P/prefix" "$P/wine/bin/wine64" reg add 'HKCU\Software\Wine\Mac Driver' /v RetinaMode /t REG_SZ /d y /f
WINEPREFIX="$P/prefix" "$P/wine/bin/wine64" reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d 192 /f
WINEPREFIX="$P/prefix" "$P/wine/bin/wine64" reg add 'HKCU\Software\Wine\Fonts' /v LogPixels /t REG_DWORD /d 192 /f
WINEPREFIX="$P/prefix" "$P/wine/bin/wineserver" -w    # flush registry to disk before reading it back
```

Verify + record (paste query output into the ledger entry):

```bash
WINEPREFIX="$P/prefix" "$P/wine/bin/wine64" reg query 'HKCU\Software\Wine\Mac Driver' /v RetinaMode
WINEPREFIX="$P/prefix" "$P/wine/bin/wine64" reg query 'HKCU\Control Panel\Desktop' /v LogPixels
WINEPREFIX="$P/prefix" "$P/wine/bin/wine64" reg query 'HKCU\Software\Wine\Fonts' /v LogPixels
WINEPREFIX="$P/prefix" "$P/wine/bin/wineserver" -w
```

**In-flight breadcrumb (same moment as the flip):** append to `~/cs2-patch/change-ledger.txt` —
`EXPERIMENT IN FLIGHT: retina ON (RetinaMode=y, LogPixels 192/192), revert = plan §1 revert block`
— closed out at finish. A mid-experiment session death must never leave James launching a changed
daily driver with no breadcrumb anywhere.

**Full revert** (also the rollback path at any stop-point) — targeted deletes/restores only:

```bash
P="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport"
WINEPREFIX="$P/prefix" "$P/wine/bin/wine64" reg delete 'HKCU\Software\Wine\Mac Driver' /v RetinaMode /f
WINEPREFIX="$P/prefix" "$P/wine/bin/wine64" reg delete 'HKCU\Control Panel\Desktop' /v LogPixels /f
WINEPREFIX="$P/prefix" "$P/wine/bin/wine64" reg add 'HKCU\Software\Wine\Fonts' /v LogPixels /t REG_DWORD /d 96 /f
WINEPREFIX="$P/prefix" "$P/wine/bin/wineserver" -w
```

Revert notes: (a) `user.reg.pre-retina-*` is forensics only — **never bulk-restore it after Steam
has run** (Steam continuously rewrites HKCU session state); the targeted commands above restore the
byte-exact pre-state (Desktop value didn't exist; Fonts was 96; Mac Driver key existed valueless).
(b) Retina runs will have rewritten Unity's `Screenmanager Resolution Width/Height` to 3024×1964 in
`user.reg` — benign and **not** a sign of incomplete revert: `Use Native=1` re-follows the desktop
and the first post-revert launch self-corrects the stored values. (c) Settings.coc restores from
its own `.exp-base` snapshot (§3), never from registry-era backups.

## 2. What we are NOT doing, and why

- **No MetalFX cells.** DXMT's spatial swapchain sizes the drawable at *game-res × factor*, factor
  clamped **≥ 1.0** at source (`d3d11_swapchain.cpp` @ v0.80 tag 589adb7: `scale_factor =
  max(getOption(…, 2), 1.0f)`; layer size = `desc_.Width × scale_factor`) — cited by
  docs/plans/perf-pass.md §3A cell A2 and re-verified upstream this session. Borderless pins
  game-res to desktop res (GOTCHAS, fact §0.4), so MetalFX can only *supersample* — measured
  2026-08-24 as softer AND slower; the perf pass formally replaced its MetalFX A-cells for exactly
  this reason (as-built header, perf-pass.md). Retina makes the pinned input *bigger* (3024×1964),
  so any factor > 1 is a >panel drawable — strictly worse. The launcher's `CS2_METALFX=1` hook
  stays parked for a future in-game-Windowed investigation, outside this experiment's scope.
- **No exclusive fullscreen.** Mode-change/blanking class (GOTCHAS § second-display refresh
  mismatch) and the alt-tab presentation freeze both live there; the launcher's standing
  instruction is FULLSCREEN WINDOW. All cells stay borderless.
- **No in-game menu automation.** All settings changes are file edits under the sanctioned
  protocol (GOTCHAS § "complete value edits ARE honored": game closed, snapshot first,
  unique-anchor regex, single-match asserted, persistence verified after the run) — the same
  machinery `~/cs2-patch/perf-runs/settings-series.py` already ran seven cells through. Edit
  vehicle per cell = the series' python pattern (read → `re.findall` count == 1 assert per edit →
  `re.sub` → write); restore-between-configs = `cp Settings.coc.exp-base Settings.coc`.

## 3. Cells

Bench instrument: `scripts/perf-bench.sh <cell>` (autonomous: `-benchmark` auto-runs the bundled
stress save, returns to menu; harness is mtime-gated on `Benchmark.coc`, TERMs the game at the idle
menu, appends one row to `~/cs2-patch/perf-runs/results.jsonl` whose **`resolution` field** —
sourced from Benchmark.coc's `screenResolution` — **is the per-cell arbiter proving which swapchain
actually ran**). Runner: `scripts/perf-run.sh` (caffeinate -dis, timestamped logs — judge-by-
timestamp is built in). All cells run `CS2_HUD=1` so screenshots carry the HUD. perf-bench.sh
exits non-zero on timeout/early-exit (`[ "$ok" = 1 ]` last line), but the row-append python is not
itself gated (no `set -e`) — gate every run on exit status **and** the new row's presence, never
the exit code alone. It blocks foreground ~4-6 min per run; the screenshot loop (§4) runs
concurrently from a background shell.

⚠ **Historical results.jsonl rows are NOT comparable** — every 2026-08-23/24 row's `resolution` is
`"1920x1080 @120Hz"` (external-display era; 15/15 measured). This experiment's rows all start
`rt-` (namespace measured collision-free) and are only compared to each other.

**Run counts (noise-floor finding, folded from review):** identical-config baseline triplets spread
1.50× on `gpuFrame.avg` and 1.13× on `gpuMs.average` (m0-baseline-1/2/3, measured) — a single run
cannot support a 1.10× gate. Therefore **b0 ×3 and r1 ×3, compared on medians; primary metric =
`gpuMs.average` (tightest CV), sanity secondary = `averageFps`; `gpuFrame` p99_ms / fps_1pct_low
reported as descriptive only.** r0 ×1 (its expected ~4× pixel effect dwarfs noise) — but if r0's
single `gpuMs.average` lands ≤ 1.25 × median(b0), extend r0 to ×3 before any retina-alone adoption:
a gate may only bind above the noise floor. r2 ×1, report-only.

| cell | runs | state | Settings.coc edits (from `.exp-base`) | expected swapchain | internal render | purpose |
|---|---|---|---|---|---|---|
| `rt-b0-{1,2,3}` | 3 | non-retina (as found) | none | 1512×982 | 1512×982 (DRS off) | fresh same-panel baseline |
| `rt-r0` | 1 (→3 if near-gate) | retina | none | 3024×1964 | 3024×1964 | native cost ceiling + UI-size probe |
| `rt-r1-{1,2,3}` | 3 | retina | DRS on, Constant 0.5, CAS | 3024×1964 | 1512×982 (= b0 pixels) | **headline**: b0's render cost, native presentation |
| `rt-r2` | 1 | retina | DRS on, Constant 0.65, CAS | 3024×1964 | ~1966×1277 | cost-curve point, report-only (prices the 0.65 option; never auto-adopted). Conditional: only if r1 passes its gate |

Cell edit regexes (each asserted == 1 match before writing — all three measured == 1 against the
live file this session; bare `"enabled": false` occurs 4×, the `isAdaptive` anchor is what makes it
unique to the DRS block; `isAdaptive` stays `false` = Constant mode; GOTCHAS records the menu's
Constant-scale living in `minScale`):

- r1: `"enabled": false(,\s*"isAdaptive")` → `"enabled": true\1` ·
  `"minScale": 0.75` → `"minScale": 0.5` ·
  `"upscaleFilter": "EdgeAdaptiveScaling"` → `"upscaleFilter": "ContrastAdaptiveSharpen"`
  (enum names per GOTCHAS § Settings.coc, from the menu-mapping table)
- r2 (from base, not from r1's file): `"enabled": false(,\s*"isAdaptive")` → `"enabled": true\1` ·
  `"minScale": 0.75` → `"minScale": 0.65` · same filter edit

Sequence with stop-points:

1. **Prep:** prefix-cold sweep (§1, zero lines) · snapshot `Settings.coc` →
   `Settings.coc.exp-base` (name measured collision-free) · `mkdir -p
   ~/cs2-patch/perf-runs/rt-shots` · **display-wake + TCC content probe**: `caffeinate -u -t 3`,
   then one `screencapture -x` with a distinctive window on screen and *inspect the content* — a
   pure-black shot = display still asleep (wake, retry); a wallpaper-only shot = Screen Recording
   permission missing for the invoking host = **STOP-fix-permission** (silent TCC degradation on
   this macOS, confirmed upstream), not a reshoot. Probe shot goes to `rt-shots/probe-tcc.png`,
   is inspected, then **deleted in the same prep step** — it images the desktop, so it is never
   committed and never a chat deliverable (deliverables are game-content cell shots only).
2. Run `rt-b0-1..3` (no edits between — identical config). **STOP if** any b0 row's `resolution` ≠
   `1512x982 @120Hz` — the panel/mode model is wrong; investigate before touching anything. Record
   b0's exact suffix (`@…Hz`) as `SUFFIX_B0` — the r-cell arbiter matches `3024x1964` as prefix
   and expects `SUFFIX_B0` as suffix (a suffix-only mismatch = investigate, not auto-STOP: the
   retina branch doesn't touch frequency).
3. In-flight ledger breadcrumb + registry flip + queries recorded (§1). Run `rt-r0` (wake display
   first: `caffeinate -u -t 3`). **STOP + revert if** its `resolution` prefix ≠ `3024x1964`
   (retina didn't take) or the UI in shots is unusable (§5 matrix).
4. Restore base, apply r1 edits, run `rt-r1-1..3` — persistence-check after *every* run using the
   **anchored expected-value patterns**, each == 1: `"enabled": true(,\s*"isAdaptive")` ·
   `"minScale": 0.5` (0.65 for r2) · `"upscaleFilter": "ContrastAdaptiveSharpen"` — bare-value
   greps can false-green off the other `"enabled"` blocks. (The game rewrites Settings.coc on
   exit; the sanctioned-protocol precedent measured edits surviving, but a mid-series regression
   invalidates the remaining runs. Re-arm: restore `.exp-base` → re-apply edits → re-assert == 1 →
   single retry.)
5. If r1 passes its gate (median `gpuMs.average` ≤ 1.10 × b0 median): restore base, apply r2
   edits, run `rt-r2` (curve point).
6. Decide per §5; set final machine state; write ledger + GOTCHAS + docs; commit.

Between runs the game is confirmed exited (harness TERMs it; residual sweep is the launcher's).
One retry per run on a missing result row (inspect the cell log first); two misses = stop, revert.

## 4. Evidence collection

- **Numbers**: `rt-*` rows in results.jsonl — gate on **median `gpuMs.average`** (b0 vs r1),
  sanity-check with median `averageFps`; report `gpuFrame` `p99_ms` / `fps_1pct_low` as
  descriptive. (`gpuFrame.avg` alone spreads 1.50× run-to-run at fixed config — measured; never
  gate on it.)
- **Sharpness**: 3 screenshots per run into `~/cs2-patch/perf-runs/rt-shots/<cell>-tN.png` via
  `screencapture -x`, from a background shell that live-polls the cell log (the log has no per-line
  timestamps — poll `until grep -q 'Launching Cities: Skylines II' "$LOG"`, substring match, no
  end-anchor; the verbatim line is `Launching Cities: Skylines II (Wine 11 + DXMT)…` with a U+2026
  ellipsis). Offsets **+80 s / +105 s / +130 s** after the launch line (flythrough = measured
  89.5 s starting ~43 s post-line + boot; +150 s risks the post-bench menu). After b0-1, calibrate:
  flythrough end ≈ Benchmark.coc mtime bump, start ≈ end − 89.5 s — adjust r-cell offsets if b0's
  shots show menu/loading instead of the flythrough. `caffeinate -u -t 3` before each shot window
  (the runner's caffeinate *prevents* display sleep; it does not cure sleep already begun —
  probe-measured today: an asleep panel yields a full-size pure-black capture). Shots stay outside
  the repo; deliver side-by-side pairs in chat.
- **Artifacts manifest**: outside repo (never committed) — `user.reg` + `.pre-retina-*` backup,
  `Settings.coc` + `.exp-base`, `Benchmark.coc` (transient, overwritten per run — nothing depends
  on it), `rt-*` run logs + `results.jsonl` appends + `rt-shots/*.png` + DXMT per-DLL logs,
  change-ledger entries. In repo (committed) — this doc's as-built header, GOTCHAS.md entry,
  `docs/perf-pass-results.md` rt- series, PLAN.md section, INSTALL.md (adoption only).
- **Validity table** (the mutant-analog for a measurement plan — each row would go red if the
  experiment were broken):

| check | arbiter | on fail |
|---|---|---|
| retina actually engaged | r-cell row `resolution` prefix `3024x1964` (suffix expected `SUFFIX_B0`; suffix-only mismatch → investigate) | STOP, investigate, revert |
| baseline honest | every b0 row `resolution == "1512x982 @120Hz"` | STOP (model wrong) |
| edits reached the game | post-run re-grep after every edited run: anchored expected-value patterns (§3 step 4), each exactly once | run invalid → re-arm + 1 retry |
| run freshness | harness mtime gate + timestamped log names (built-in) | trust (measured 2026-08-24) |
| shots real | probe **content-verified** at prep (TCC passes wallpaper-only shots at full dims/size — size checks cannot catch it); per-shot: non-black, game content visible | wake + reshoot once; else "no visual evidence" → §5 default |
| gate resolvable | b0 triplet spread sanity: if b0 `gpuMs.average` max/min > 1.3×, bench is noisier than history — extend b0, ×5 max | still > 1.3× at ×5 ⇒ stop |
| no cross-contamination | prefix-cold sweep (§1) before every registry write / settings edit | abort cell |

## 5. Decision matrix + final state

Rows evaluated **in order — first match wins**; medians throughout.

| # | outcome | action |
|---|---|---|
| 1 | UI half-size/broken in r0/r1 shots | Full revert (§1 revert + `.exp-base` restore). Finding: retina needs an attended UI session; park. First attended diagnostic: retina + CPD LogPixels 96 half-cell to split retina-vs-DPI attribution (§6). |
| 2 | r0 ≤ 1.15 × b0 (after its mandatory ×3 extension — a near-gate single run never adopts) AND r0 shots content-verified with UI normal-sized (no usable r0 shots → row 4) | Adopt **r0** (retina alone, DRS stays off) — sharpest possible, no scaling at all, and it *preserves* James's same-day DRS-off choice. James's next real session is final acceptance, including the §6 bottom-edge click check. |
| 3 | r1 ≤ 1.10 × b0 AND shots visibly sharper AND UI normal-sized | Adopt **r1** as daily: leave retina + r1 settings live. ⚠ Report MUST state: this **re-enables the DRS James turned off this morning** — semantics differ under retina (Constant 0.5 × 3024 = the same 1512×982 internal render he has now, presented natively instead of compositor-doubled). James's next real session is final acceptance (async rule: judged only on a run postdating this change), including the §6 bottom-edge click check — a cursor offset there is a known-class revert trigger, not a mystery. |
| 4 | **Any outcome not matching a row above** (incl. r1 in-budget but shots not visibly sharper, or shots unavailable/black) | **Full revert + report** — revert-not-adopt is the default on every ambiguity. Present the measured cost curve (b0/r0/r1/r2) so James chooses with numbers; nothing is left adopted that he hasn't accepted. |

Whatever the outcome: ledger close-out ("experiment done: <state>"), GOTCHAS.md entry (what retina
does/costs on this stack — standing knowledge either way), `docs/perf-pass-results.md` gains the
rt- series numbers, this doc gets its as-built header, PLAN.md section closed out, the user-level
memory index (`MEMORY.md`) updated (stack facts change on adoption), repo committed + pushed.
INSTALL.md gains the retina recipe only on adoption. Snapshot disposition: `user.reg.pre-retina-*`
and `Settings.coc.exp-base` are **kept until James accepts or reverts the outcome** (listed in the
report), then deletable.

## 6. Risks

- **UI element size under retina + DPI 192**: no UI-scale key found in `Settings.coc` (searched);
  cohtml/Unity behavior at 192 DPI is unknowable offline → probed empirically by the r0 shots
  before anything else runs. Known limitation: LogPixels 192 is applied *with* retina from the
  start, so a broken UI in r0 can't be attributed between the two — acceptable scope cut; the
  attended follow-up half-cell (retina + CPD 96) is the attribution splitter if row 1 fires.
- **Screenshot channel**: two silent failure modes, both probed at prep — display-asleep = black
  full-size capture (measured today); missing Screen Recording TCC = wallpaper-only capture at
  full dims (confirmed for this macOS generation). Neither is detectable by size/dims checks.
- **Cursor hit-testing under retina**: nothing in the campaign exercises input (`-benchmark` is
  zero-input; menu automation is banned by §2). Low risk — the GOTCHAS §5b offset class came from
  `/desktop=WxH` virtual-desktop mismatch, which this experiment doesn't use, and the engine's
  clip-cursor handlers are retina-aware (§0.2) — but it is *unmeasured* here, so first-session
  acceptance explicitly includes clicking bottom-edge UI (the SELECT MODE symptom); an offset ⇒
  revert one-liners.
- **Bench noise**: MTLCommandBuffer "Impacting Interactivity" device errors appeared in prior cell
  logs (s7) without invalidating results — expected noise, not a stop signal.
- **Cold-start variance**: first run pays Steam login + 45 s licence wait — affects
  `loadingTimeSecs` only, never the flythrough GPU metrics; the launch-line anchor absorbs it for
  shot timing.
- **Bench scene ≠ live city**: the stress save is heavier than James's city; deltas transfer
  directionally (precedent: composed-profile bench gains matched live acceptance, 2026-08-24).
- **Thermals/power**: on AC (verified, charging); runs are sequential with idle gaps.
- **Steam session swap**: same-account swap measured harmless 2026-08-24; store wrapper closed.
- **vSync/120 Hz**: no material distortion of GPU-time metrics at 10–40 FPS (3×+ below cap,
  adaptive panel, identical setting in every cell); `averageFps` used as sanity only.

## 7. Exit criteria

1. 7–10 `rt-*` rows in results.jsonl (b0 ×3–5, r0 ×1–3, r1 ×3, r2 ×0–1), every executed run's
   `resolution` arbiter correct, every edited run persistence-verified.
2. Content-verified screenshot sets for every executed cell (or the explicit "no visual evidence"
   degradation with matrix row 4 applied); b0-vs-candidate pair delivered in chat.
3. Machine left in exactly one matrix state, stated explicitly in the report, with revert
   one-liners re-stated and snapshot disposition listed.
4. Ledger breadcrumb opened at flip and closed at finish; GOTCHAS + perf-pass-results + PLAN.md
   updated; this doc carries an as-built header; user-level MEMORY.md updated; repo committed and
   pushed.
5. Prefix cold at finish (§1 sweep = 0 lines).

## Review corrections (triple-check 2026-08-26)

Pass 1 (4 lenses: correctness · platform-facts · builder-simulation · architecture; all
build-ready-with-fixes; 1 BLOCKER). Folded: results-row field is `resolution` not
`screenResolution` (arbiters + exit criteria); `gpuFrame` keys are `p99_ms`/`fps_1pct_low`;
**BLOCKER: 1.10× gate vs measured 1.50× single-run `gpuFrame.avg` spread → b0/r1 ×3 with medians,
`gpuMs.average` primary** (spread re-verified inline: 6.398–9.613 gpuFrame.avg, 39.30–44.33
gpuMs.average on the m0 triplet); matrix re-ordered (UI-broken first, r0 before r1, catch-all
revert default; r0 near-gate ×3 extension); prefix-cold sweep spelled (settings-series' bare-pgrep
guard documented as insufficient for registry work); `rt-shots/` mkdir; shot offsets +150→+130 with
b0 calibration (flythrough measured 89.5 s); display-wake protocol + TCC content probe (both
failure modes probed live today: asleep panel = black capture; TCC = wallpaper-only, invisible to
size checks); in-flight ledger breadcrumb; RetinaMode option-parse evidence corrected to upstream
source (selector strings ≠ option parse); per-app AppDefaults deliberately unsupported (upstream
comment) recorded; CPD LogPixels = primary DPI lever; Screenmanager self-correction note;
`SUFFIX_B0` suffix handling; DRS-override disclosure required in report; PLAN.md + MEMORY.md added
to aftermath; artifacts manifest; snapshot disposition.

Pass 1b (fitted post-fold: test-plan audit · publishability; both build-ready-with-fixes). Folded:
matrix row 2 gains the visual-evidence conjunct + acceptance mirror (no-shots numeric pass was
reaching adopt via first-match-wins); §7 row arithmetic 7–9 → 7–10 (r0-extension and r2 are
independent); persistence checks specified as anchored expected-value patterns (bare-value greps
false-green off the file's other `"enabled"` blocks) + re-arm procedure; cursor-hit-testing named
as unmeasured with the bottom-edge click check added to §6 and both adopt rows (GOTCHAS §5b class);
perf-bench exit-status wording corrected (row-append not gated — check exit AND row); b0-extension
bounded at ×5; TCC probe shot given a path and delete-in-prep disposition (it images the desktop;
never committed, never delivered).

## Review log

| date | pass | lenses | method | model | verified-against | verdict |
|---|---|---|---|---|---|---|
| 2026-08-26 | 1 (full) | correctness · platform-facts · builder-sim · architecture | 4 read-only agents + inline BLOCKER/probe rechecks (TCC probe, variance re-read) | Fable 5 | `088f0c0` | build-ready-with-fixes |
| 2026-08-26 | 1b (fitted post-fold) | test-plan audit · publishability | 2 read-only agents on the folded doc; corrections folded same session | Fable 5 | `088f0c0` | build-ready-with-fixes |

Key paths: `scripts/perf-bench.sh` · `scripts/perf-run.sh` · `~/cs2-patch/launch-cs2-dxmt11.sh` ·
`~/cs2-patch/perf-runs/settings-series.py` · GOTCHAS.md §§ resolution-scaling / Settings.coc /
second-display / screencapture · docs/plans/perf-pass.md §3A · prefix `user.reg` + `Settings.coc`.
