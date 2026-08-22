# CS2-on-macOS — Plan & Open Avenues

Roadmap for running Cities: Skylines II on macOS 26 / Apple Silicon **for free** (no CrossOver).
Companion to README/GOTCHAS/CONFIG-TRIALS (the *what happened*); this is the *what's next*.

> **Status 2026-07-04: THE RENDER WALL IS BEATEN.** With the **private-API MoltenVK 1.4.1** swap, CS2
> renders gameplay (reached "Creating ECS world", zero `VK_ERROR_DEVICE_LOST`). This is the free equivalent
> of what CrossOver's D3DMetal provides. Novel; documented nowhere else as of this date.

## The known-good recipe (reproduce the win)
1. Wine 11 (Gcenx staging 11.10) + DXVK-macOS 1.10.3 (full) — DX11→Vulkan→MoltenVK→Metal.
2. **libMoltenVK.dylib = the `MoltenVK-macos-privateapi.tar` build of v1.4.1** (universal, x86_64 slice used under
   Rosetta). Backed up as `libMoltenVK.dylib.privateapi-WORKING`; stock is `.stock141`. **This is the keystone fix.**
3. `dxvk.conf`: `dxgi.maxDeviceMemory=16384` + `maxSharedMemory=16384` (report honest VRAM, not the 128 MB default).
4. `Settings.coc`: Low preset, shadows off, `maxLightCount 256`, `minScale 0.3`, **`displayMode Fullscreen`**.
5. Registry: resolution forced 1280×720, `Use Native = 0`.
6. Mods OFF (`playset_config.json` all `isEnabled:false`).
7. Launch: Steam (auto-login, 40s license wait) → `explorer /desktop=CS2-GAME,1280x720 Cities2.exe`.

## Open avenues (priority order)

### P1 — Stabilize the gameplay render
- **Symptom:** device-loss is now the *exception*, not the rule, but not fully gone. The 14:01 run reached ECS
  world clean; a later run device-lost during load. Suspects: (a) **macOS screenshot in exclusive-FS crashes the
  swapchain** — confirmed pattern, avoid it / use a phone photo; (b) residual non-determinism (GPU thermal/state
  after many launches); (c) async-shader-compile timing on first frames.
- **Actions:** confirm a clean no-screenshot run reaches the playable city + is interactive; test whether a true
  non-exclusive window (Borderless actually took? log still showed `Exclusive FS: 1`) makes screenshots safe;
  try `dxvk.enableAsync=False` to remove first-frame shader-compile timing as a variable; reboot for clean GPU.
- **Exit criteria:** load a small map, move camera, place a road, save — no device-loss across 3 consecutive runs.

### P2 — Walk graphics back up
- The shadows/lights/resolution/GI cuts were all to fight the *now-solved* device-loss. On an M3 Max they're
  overkill. Raise one axis at a time (resolution → shadows → lights → effects), retest for device-loss/FPS after
  each. Find the comfortable ceiling. Keep a ✅/❌ table in CONFIG-TRIALS.
- **Exit criteria:** documented "recommended settings" that hold stable at a playable framerate.

### P3 — Steam client UI display (low value; hard)
Steam's UI is black — a **different** problem than the game (CEF/Chromium GPU compositor queries a D3D11
shared-texture interface `f8fb5c27-…` that DXVK 1.10.3 lacks). The MoltenVK win does **not** transfer. We don't
*need* it (headless login + direct launch work), but to exhaust it:
- **S1 (cheap):** retest software CEF now — `-cef-disable-gpu -cef-disable-gpu-compositing -cef-in-process-gpu`.
  Low odds it shifted, 2 min to confirm.
- **S2 (aligned):** hunt a DXVK-macOS **1.10.x point release** that adds the missing interface while staying
  Vulkan 1.2 (MoltenVK-compatible). If found, Steam CEF renders through the same path the game does.
- **S3 (deep):** **Zink** (OpenGL-on-Vulkan) so Wine's dead-on-macOS-26 GL routes through Vulkan→MoltenVK→Metal.
  The "correct" fix for the dead-GL black screen, but a serious Mesa-in-Wine build project.
- **S4:** accept headless. Manage store/downloads/friends via the Steam mobile app or a browser.

### P4 — GPTK 3 / D3DMetal rebuild (the "real fix" — reliable, not dice-roll)
**Why:** P1 proved the render wall is beatable (private-API MoltenVK) but NOT reliably — it's an intermittent
MoltenVK fault during VT/gameplay GPU compute, ~1-in-8, uncured by any config (mods, cache, settings, reboot all
ruled out 2026-07-04). **D3DMetal (`DX11 → Metal` directly, Apple's own) handles the passes MoltenVK faults on** —
it's *why* CrossOver is stable. This is the only path to reliable free play. It's a fresh, isolated prefix — **zero
risk to the working MoltenVK stack.** CrossOver ($50, owned) is the proof the destination exists and the fallback.

**Sequence — probe cheaply BEFORE investing in the 89 GB CS2 setup:**

- **P4.0 — Feasibility probe (do this FIRST, ~1 hr, cheap):** Install GPTK 3 and answer one question — *does its
  Wine run modern Steam's client at all?* This is the make-or-break; everything else is downstream.
  1. `brew install gcenx/wine/game-porting-toolkit` (Gcenx cask; Homebrew dual-install — `/usr/local` Rosetta +
     `/opt/homebrew` ARM). Newer GPTK uses **`wine64`**, not `wine`.
  2. Fresh probe prefix: `WINEPREFIX=~/gptk-probe $(brew --prefix game-porting-toolkit)/bin/wine64 winecfg`
  3. Install Windows Steam into it; try to reach a logged-in client.
  4. If `steamwebhelper` chokes (likely — still a known GPTK issue), apply the **documented community recipes**:
     [WinSteamOnMac](https://github.com/domschl/WinSteamOnMac) + [mybyways guide](https://mybyways.com/blog/running-steam-in-game-porting-toolkit).
     Our own CDP-login + direct-launch tricks are a further fallback.
  - **Exit:** logged-in Steam on GPTK's Wine → P4 is GO. Can't get Steam up after the recipes → P4 stalls; fall
    back to the P1 dice-roll or CrossOver, and log the specific failure here.

- **P4.1 — Bring CS2 in:** APFS-clone the existing install into the GPTK prefix (fast, ~zero disk) or reinstall;
  re-point the prefix. Reuse our known-good bits (steam_appid.txt, 40s license wait, overlay-disable, Low settings).

- **P4.2 — Route DX11 through D3DMetal** (not DXVK). GPTK's `game-porting-toolkit` wrapper sets the DLL overrides;
  otherwise manual `WINEDLLOVERRIDES` + D3DMetal env. Remove our DXVK d3d11/dxgi native overrides in THIS prefix.

- **P4.3 — Test render + stability.** The payoff: if it renders, it should be *stable* (no MoltenVK fault). Load a
  map, move the camera, save. Exit criteria: 3 consecutive clean runs (the bar P1 can't meet).

**Open unknowns (verify during P4.0, don't assume):** exact current GPTK 3 version + whether it's macOS-26/Tahoe-
clean (GPTK 3 predates Tahoe; D3DMetal is Metal-based so the dead-GL issue shouldn't hit the *game*, but Steam's
CEF UI stays black either way — CDP login as now). The irony to keep in view: P4 is hand-rebuilding the D3DMetal +
Steam-capable-Wine + macOS-26 integration that CrossOver ships pre-assembled; the risk is exactly the glue
CodeWeavers gets paid for.

## "check it" concept for this project
Before committing to a big avenue (P3-Zink, P4-GPTK3), run a lightweight adversarial review — three lenses:
1. **Feasibility** — has anyone done this on macOS 26 + Apple Silicon + Rosetta? (search AppleGamingWiki, GitHub
   issues, r/macgaming). Don't burn a night on a known dead end.
2. **Regression risk** — does it threaten the *working* stack? (P4 = fresh prefix, safe; swapping DXVK for Steam
   could break the game — isolate in a copied prefix first.)
3. **Value** — does it move "can I play CS2?" or just polish? (Steam-display is polish; render-stability is core.)
Verdict: pursue / park / drop. Keep a one-line log per avenue below.

## Review log
- 2026-07-04 — private-API MoltenVK swap → render wall beaten (reached ECS world). P1 stability + P2 graphics next.
- 2026-07-04 — P1 exhausted: device-loss is an intermittent MoltenVK fault (~1-in-8), uncured by mods/cache/settings/
  reboot (all ruled out). DXVK state cache plateaus at "menu-ready" (188 entries) — confirms it's not a compile race.
  P4 promoted to the real path. Researched GPTK 3: steamwebhelper wall has documented recipes (WinSteamOnMac, mybyways)
  → P4's biggest risk is mitigated. Wrote P4.0 feasibility probe as the cheap first step.
- 2026-07-04 — **P4.0 probe RUN.** GPTK 3.0 installed (Gcenx cask; bundles wine-7.7 — Apple never rebased). **D3DMetal
  RENDERS on macOS 26: CONFIRMED** — dxtest.exe (DX11→magenta) creates device + present-loops under GPTK wine64 w/
  builtin d3d11 (=D3DMetal shim). So P4's render half is PROVEN; **the sole wall left is Steam-on-GPTK-Wine-7.7**
  (steamwebhelper: `-cef-force-32bit` got the CEF debug port up but the helper stays unstable). Probe prefix
  ~/gptk-probe (Steam+CS2 COW-cloned). Next: finish the mybyways Steam recipe, or sidestep the live-client license.
