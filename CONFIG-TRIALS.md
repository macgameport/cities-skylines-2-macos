# Config trials & errors — Wine 11 + DXVK stack (historical)

> **Historical trials log (2026-07-03 → 07-04).** Records configuration permutations tried on the
> **Wine 11 + DXVK + MoltenVK** stack, most of which existed to fight `VK_ERROR_DEVICE_LOST` — a
> failure mode the current **D3DMetal** stack does not have. Do not copy these settings; several
> (GI off, shadows off, `maxLightCount 256`, low resolution scale) were device-loss mitigations that
> now only cost image quality. Set graphics in-game instead.
> Current setup: [`../README.md`](README.md)


Everything tried, and the result. ✅ = worked, ❌ = didn't, ⚠️ = partial/side-effect.
Saves re-testing dead ends. Chronological-ish within each problem.

---

## A. Which Wine/translation layer

| Approach | Result |
|---|---|
| Apple GPTK (Gcenx cask, Wine 7.7 + bundled D3DMetal) | ❌ Wine too old — steamwebhelper hangs, no Steam login |
| Whisky | ❌ discontinued 2024, frozen Wine, untested on macOS 26 |
| Free CrossOver-sourced Wine build | ❌ only `wine-crossover 23.7.1` exists free (pre-macOS-26); no longer casked |
| **Wine-staging 11.10** (Gcenx macOS_Wine_builds) | ✅ runs on macOS 26, fixes webhelper hang, bundles MoltenVK 1.4 |
| CrossOver 26 (paid) | ✅ works out-of-box (D3DMetal) — the $50 baseline we were avoiding |

## B. DX rendering path (the black-screen fight)

| Approach | Result |
|---|---|
| Wine builtin d3d11 (wined3d → OpenGL) | ❌ **black**; `glClear` → `GL_INVALID_FRAMEBUFFER_OPERATION` (GL dead on macOS 26) |
| wined3d with `renderer=vulkan` | ❌ **crashes** (dxtest exits; webhelper crashes → steam.exe exits) |
| GPTK's D3DMetal on Wine 11 | ❌ ABI-locked to Wine 7.7, won't load on Wine 11 |
| **DXVK-macOS v1.10.3 (full)** → native d3d11/dxgi | ✅ **magenta renders** — Vulkan→MoltenVK→Metal. THE fix. |
| DXVK-macOS "-repack"/"-builtin" (no dxgi) | ❌ `D3D11CreateDevice` fails, **exit 53** |

## C. Steam client UI rendering (never solved — worked around)

| Approach | Result |
|---|---|
| Default (GPU/ANGLE) | ❌ black |
| `-cef-disable-gpu` (software) | ❌ black |
| `-cef-disable-gpu -cef-disable-gpu-compositing` | ❌ black |
| `WINEDLLOVERRIDES="dcomp="` (disable DirectComposition) | ❌ black (`f8fb5c27` interface still queried) | *[2026-08-22: that GUID is `ID3D11Texture1D`, not a shared-texture interface — querying it is benign type-discovery. The black screen had another cause.]*
| Virtual desktop (`explorer /desktop`) | ❌ black rectangle appears, no content |
| Big Picture (`-gamepadui`) | ❌ black — but **had AUDIO** (proves render works, present fails) |
| Per-app builtin d3d11 for `steamwebhelper.exe` + `renderer=vulkan` | ❌ black + crashes |
| mingw `steamwebhelper.exe` wrapper injecting `--disable-gpu-compositing` | ⚠️ ran (via `steam.cfg BootStrapperInhibitAll`) but flags didn't take, fragile IPC |
| Blind login into invisible-but-interactive form (3 attempts) | ❌ can't hit fields you can't see (`[U:1:0]`) |
| **CEF remote debugging + CDP** (fill form via debug channel) | ✅ **logged in.** `Page.captureScreenshot` even shows the UI. |

## D. Getting Steam logged in

| Approach | Result |
|---|---|
| Import CrossOver bottle's `config.vdf`/`loginusers.vdf` for auto-login | ❌ token machine-bound, rejected (`[U:1:0]`) |
| QR code login (scan screenshot with Steam mobile) | ❌ QR rotates faster than screenshot→scan round-trip |
| CDP: fill username/password (React native-setter) + click Sign in | ✅ reached Steam Guard |
| Steam Guard: mobile-app approve | ✅ logged in |
| **After 1st login: headless auto-login (cached token)** | ✅ reliable, no UI needed |

## E. Launching the game

| Approach | Result |
|---|---|
| `steam -applaunch 949230` | ❌ game exits before Unity init (no Player.log) |
| `steam -applaunch` + overlay disabled | ❌ still exits early |
| **Direct `Cities2.exe`** + `steam_appid.txt` + Steam running | ⚠️ runs, but platform-init **racy** |
| Direct launch, Steam up only a few seconds | ❌ `platform service integration failed` (license not synced) |
| **Direct launch after Steam up ~40–60s** | ✅ platform init OK, loads to menu |
| `SteamAppId=SteamGameId=SteamOverlayGameId=949230` env | ✅ needed for SteamAPI to connect on direct launch |
| Disable overlay `gameoverlayrenderer64=d` | ✅ prevents a game crash |

## F. Input (SOLVED)

| Approach | Result |
|---|---|
| Reached fully-rendered main menu | ✅ (cohtml UI + 3D skyline render on M3 Max) |
| Clicks at menu (exclusive fullscreen) | ❌ don't register (Wine input-routing quirk) |
| `-screen-fullscreen 0` to force windowed | ❌ ignored (game uses saved settings) |
| `Settings.coc displayMode: "Windowed"` | ❌ game thrashes display modes → `VK_ERROR_DEVICE_LOST` before menu |
| **Virtual-desktop mode** (`explorer /desktop=CS2,WxH Cities2.exe`) | ✅ clicks register |
| Virtual desktop at wrong res (1600x1000 vs game 1512x982) | ⚠️ clicks work but cursor **offset** — can't hit bottom UI (SELECT MODE) |
| **Virtual desktop matched to render res (1512x982)** | ✅ cursor aligned, SELECT MODE clickable |

## G. GPU stability / device-loss (map-load SOLVED; first-frame IN PROGRESS)

| Approach | Result |
|---|---|
| `MVK_CONFIG_RESUME_LOST_DEVICE=1` | ✅ keep (but doesn't recover once DXVK `waitForIdle` fails) |
| `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1` | ✅ keep |
| `dxvk.conf` `dxgi.maxDeviceMemory`/`maxSharedMemory = 8192` cap | ❌ was a red herring; not the cause either way |
| `dxgi.maxDeviceMemory` / `maxSharedMemory = 16384` | ✅ keep — effective in DXVK, harmless (doesn't change Unity's `VRAM: 128 MB` report) |
| **CS2 graphics → Low** (volumetrics/GI/SSAO/SSR/DoF/blur off, LOD 0.4) | ✅ reaches menu reliably |
| **Turn MODS OFF** (`playset_config.json` all `isEnabled:false`, clear `.downloading`) | ✅✅ **got PAST the loading screen** — mod downloads+VT churn were the map-load killer |
| Reboot for clean GPU state | ✅ helps (Metal state degrades over many launches) |
| **Map loads to gameplay** (audio + ~206k objects, clean unload) | ✅ **DONE** — the map-load device-loss is beaten |
| First full-city frame render | ❌ **device-lost** (`waitForIdle failed`) — black screen + music. Current blocker. |
| Shadows OFF + `maxLightCount` 4096→256 + `minScale` 0.5→0.3 | ⏳ applied, UNTESTED — aims to survive first-frame |
| NEW small/flat map vs built save | ⏳ recommended — empty first frame is ~10× lighter |

## Key env / files (the working set)
```
export MVK_CONFIG_RESUME_LOST_DEVICE=1
export MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1
export SteamAppId=949230 SteamGameId=949230 SteamOverlayGameId=949230
export WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d;winemenubuilder.exe=d"
export WINEESYNC=1 ROSETTA_ADVERTISE_AVX=1
# DllOverrides (registry): d3d11,dxgi,d3d10core,d3d9 = native (DXVK)
# steam_appid.txt = 949230 in game dir
# dxvk.conf: d3d11.maxFeatureLevel=11_0 ; dxvk.enableAsync=True ; dxgi.maxDeviceMemory=16384 ; dxgi.maxSharedMemory=16384
# Settings.coc: displayMode "Fullscreen", Low graphics, shadows OFF, maxLightCount 256, minScale 0.3
# MODS OFF (playset_config.json all isEnabled:false) — the map-load device-loss fix
# LAUNCH: start Steam → wait for login → sleep 40s → wine explorer /desktop=CS2,1512x982 Cities2.exe
#   (virtual desktop for input; resolution MUST match the game's render res or cursor is offset)
```
