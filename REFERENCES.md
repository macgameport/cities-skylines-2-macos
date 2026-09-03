# References — CS2 on macOS (Wine, DXVK, DXMT, D3DMetal)

> **Reference index, compiled 2026-07-04.** External links are still valid, but the *emphasis* is
> from when GPTK and DXVK were being evaluated. The stack that won is **Wine 10 Sikarugir +
> D3DMetal** via Kegworks — see [`../README.md`](README.md).


Reliable-looking sources found while solving this. ⭐ = directly useful/verified against our experience.
Note: the community consensus (below) is that **CS2 does not run on Mac** — we got it to the menu anyway,
so treat "it's impossible" posts as *outdated*, but they're accurate about the default GPTK/CrossOver/Whisky paths.

## Core tooling (the stuff we actually use)
- ⭐ **Gcenx/DXVK-macOS releases** — the macOS DXVK fork; we use `v1.10.3-20230507` (full build).
  https://github.com/Gcenx/DXVK-macOS/releases
  - Note from their docs: use `v1.10.x` — MoltenVK doesn't expose the Vulkan 1.3 extensions upstream DXVK 2.x needs.
- ⭐ **Gcenx/macOS_Wine_builds** — prebuilt Wine for macOS; we use `wine-staging-11.10-osx64`.
  https://github.com/Gcenx/macOS_Wine_builds/releases
- **Gcenx/game-porting-toolkit** (prebuilt GPTK, Wine 7.7) — the dead-end for us (too old for modern Steam), but
  bundles Apple's D3DMetal. https://github.com/Gcenx/game-porting-toolkit
- **mbeckenbach/Cities-Skylines-2-MacOS-Patcher** — binary-patches CS2 DLLs for Wine file-API bugs (the CrossOver
  fix; some patches still relevant). https://github.com/mbeckenbach/Cities-Skylines-2-MacOS-Patcher
- **MelonForAll/vineport** — brand-new (2 stars) "open-source Wine + GPTK D3DMetal for Steam" launcher; concept is
  right (newer Wine + D3DMetal + a steamwebhelper wrapper) but unproven. https://github.com/MelonForAll/vineport

## VK_ERROR_DEVICE_LOST / MoltenVK stability ⭐ (our current blocker)
- ⭐ **Confirms our fix:** "for DXVK/Vulkan on macOS use `export MVK_CONFIG_RESUME_LOST_DEVICE=1` because Wine
  doesn't handle VK_ERROR_DEVICE_LOST correctly." (surfaced repeatedly in Gcenx/DXVK-macOS docs & guides)
- ⭐ **MoltenVK releases** — https://github.com/KhronosGroup/MoltenVK/releases — checked 2026-07-04: latest is
  **v1.4.1 (2025-11-30)**, which is exactly what Wine-staging 11.10 bundles. So "use a newer MoltenVK" is NOT a
  lever — we're already current. The device-loss is the tooling ceiling, not an outdated layer.
- **MoltenVK issue #1811** — VK_ERROR_DEVICE_LOST on Apple Silicon, works on older macOS.
  https://github.com/KhronosGroup/MoltenVK/issues/1811
- **MoltenVK issue #1180** — device-lost crash with a MoltenVK version bump.
  https://github.com/KhronosGroup/MoltenVK/issues/1180
- **MoltenVK modified w/ DXVK patches (libMoltenVK.dylib)** — a community-patched MoltenVK; worth trying if the
  stock one keeps losing the device. https://community.pcgamingwiki.com/files/file/2417-moltenvk-modified-with-dxvk-patches-for-macos-libmoltenvkdylib/
- **WineHQ Forums — Building Wine / MoltenVK on macOS arm64.** https://forum.winehq.org/viewtopic.php?t=41375

## GPTK 3 / D3DMetal path (the old "real fix for reliable play" route — historical)
- **Apple Game Porting Toolkit** (official) — Wine + Apple's **D3DMetal** (DX11 *and* DX12 → Metal directly).
  https://developer.apple.com/games/game-porting-toolkit/ · repo: https://github.com/apple/game-porting-toolkit
- ⭐ **Gcenx/game-porting-toolkit** — the Homebrew cask we'd install (`brew install gcenx/wine/game-porting-toolkit`).
  Newer GPTK uses `wine64`, not `wine`. https://github.com/Gcenx/game-porting-toolkit/releases
- ⭐ **WinSteamOnMac (domschl)** — recipe for running Windows Steam under GPTK; **the steamwebhelper workaround** that
  de-risks P4's biggest blocker. https://github.com/domschl/WinSteamOnMac
- ⭐ **mybyways — "Running Steam in Game Porting Toolkit"** — companion walkthrough for Steam-under-GPTK.
  https://mybyways.com/blog/running-steam-in-game-porting-toolkit
- **AppleInsider — how to install/use GPTK in Xcode.** https://appleinsider.com/inside/macos-sonoma/tips/how-to-install-and-use-game-porting-toolkit-in-xcode
- Note (2026-07-04): GPTK **3.0** exists (Tahoe-era; enabled Starfield/Star Wars Outlaws via CrossOver Preview per
  Notebookcheck). `steamwebhelper` "not responding" is STILL a known GPTK+latest-Steam issue — hence the recipes above.

## General Wine-gaming-on-Mac guides ⭐
- ⭐ **Kiran's blog — "How to Run Windows Games and Programs on Mac"** — solid DXVK-macOS + MoltenVK + Wine setup
  walkthrough; matches our approach. https://blog.lynkos.dev/posts/play-windows-games/
- **Andre's blog — "Debugging game on macOS via Wine"** — good WINEDEBUG / crash-hunting techniques.
  https://an-pro.org/posts/13-wine-debug-success-story.html

## CS2-specific (mostly "it doesn't work" — outdated but useful context)
- **AppleGamingWiki — Cities: Skylines II** — compatibility/troubleshooting hub; says no native port, x64-only.
  https://www.applegamingwiki.com/wiki/Cities:_Skylines_II
- **Paradox Forums — "Cities: Skylines 2 on mac"** — community reports of failures (black screen + crash, incl.
  Whisky + `dotnet48`). https://forum.paradoxplaza.com/forum/threads/cities-skylines-2-on-mac.1851929/
- **MacStories — "I Tried to Run Cities: Skylines 2 on My M2 MacBook Air via GPTK…"** — documents the GPTK failure.
  https://www.macstories.net/stories/i-tried-to-run-cities-skylines-2-on-my-m2-macbook-air-via-apples-game-porting-toolkit-and-i-discovered-a-great-app-instead/

## Steam client UI under Wine on macOS (the black-CEF problem) — added 2026-08-29
- ⭐⭐ **notpop/steam-on-m1-wine** — **the most relevant source to this project, and it was missing
  from this index until 2026-08-29.** Runs Windows Steam + D3D11 games on Apple Silicon, and its
  Steam UI *renders with text*. Two ingredients we do not have: `winemac.so` rebuilt with
  `-fvisibility=default` (`scripts/08-patch-wine-visibility.sh` — "to make macdrv's public API
  callable by third-party Metal layers", gated on `nm -g` ≥100 public text symbols), and a **DXMT
  fork** rewriting `_CreateMetalViewFromHWND`. https://github.com/notpop/steam-on-m1-wine
- ⭐ **notpop/dxmt @ `debug/present-path-tracing`** (`924a607`) — the fork, ~150 lines over upstream,
  working around two Wine 11 bugs: `macdrv_win_data` not exposing a usable NSView at swap-chain
  creation, and an `OnMainThread` re-entrance deadlock. https://github.com/notpop/dxmt
- **BCD1210/soju** — the vanilla-wined3d-for-the-client split (client on wined3d, games on DXMT).
  Built and measured here 2026-08-28/29: **does not work on this stack** (wined3d caps at FL 9_3).
  https://github.com/BCD1210/soju
- **3Shain/dxmt#141** — cross-process swapchain; our four evidence comments live here.
  https://github.com/3Shain/dxmt/issues/141

> ⚠ **Lesson (2026-08-29):** three of the steamwebhelper-specific sources already listed below
> (`domschl/WinSteamOnMac`, `mybyways`, `MelonForAll/vineport`) were never revisited once the
> black-CEF problem was actually characterised, and `notpop` was never listed at all — while a
> month of measurement went into re-deriving the problem locally. **Re-read the source index when
> the problem statement changes**, not just when starting out.

## Reference / background
- **AppleGamingWiki — CrossOver** (the paid baseline). https://www.applegamingwiki.com/wiki/CrossOver
- **AppleGamingWiki — Game Porting Toolkit.** https://www.applegamingwiki.com/wiki/Game_Porting_Toolkit
- **Whisky maintenance notice** — why Whisky is discontinued (relies on CrossOver's paid Wine-on-Mac work).
  https://docs.getwhisky.app/maintenance-notice
- **Steam CEF remote debugging** — enable with a `.cef-enable-remote-debugging` file in the Steam dir; DevTools on
  `http://localhost:8080/json`. (How we drove the black login. General Steam/CEF knowledge, widely documented.)

## Search terms that worked
`Gcenx DXVK-macOS`, `MVK_CONFIG_RESUME_LOST_DEVICE`, `wine gaming apple silicon MoltenVK`,
`steamwebhelper not responding wine`, `macOS OpenGL deprecated GL_INVALID_FRAMEBUFFER_OPERATION`.

> If you post this recipe publicly (r/macgaming, AppleGamingWiki, the Paradox thread): the novel bits are
> (1) DXVK beats the macOS-26 dead-GL black screen, (2) driving Steam's black CEF login via CDP, and
> (3) the direct-launch + 40s license-sync-wait recipe. Those aren't documented elsewhere as of 2026-07.
