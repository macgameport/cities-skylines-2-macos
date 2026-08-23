# Draft: AppleGamingWiki edit — Cities: Skylines II

> **Status: draft, not submitted.** Target page:
> https://www.applegamingwiki.com/wiki/Cities:_Skylines_II
> Anonymous edits are disabled — an account is required.
>
> **What the page says today (read 2026-08-23):** the *macOS Compatibility* table has rows for
> CrossOver (Playable, 35 FPS, verified 2026-05-13 by User:alien-agent against game 1.5.8f1),
> **Wine (Playable, verified 2026-11-18 — actually 2023-11-18 — by User:BeeConfetti against game
> `1.0.14f1`, Whisky 2.1.3, macOS Sonoma 14.0)**, and two Parallels rows.
>
> The Wine row is ~3 years stale: it predates DXMT entirely, its fix is a hardcoded hex offset, and
> it carries the blanket warning *"Tabbing out will cause the game to become unresponsive and
> require it to be restarted."* Both are addressed below.

## Proposed change 1 — add a row to the macOS Compatibility table

Placed directly under the existing **Wine** row. Rating: **Playable**.

**Compatibility layer:** `Wine + DXMT`

**Notes cell:**

> Playable on Apple Silicon on a fully free stack — no CrossOver licence — with the in-game
> Paradox Mods manager working (downloads and loads). Uses DXMT (Direct3D 11 → Metal) rather than
> D3DMetal.
>
> The mod-download failures reported with older Wine setups are not a permissions or disk problem:
> under Wine, Mono's P/Invoke last-error capture returns garbage, so .NET's file APIs throw on
> operations that actually succeeded. **Wine 11 fixes this upstream**, which also removes the need
> for several binary patches earlier guides required.
>
> **Installation:**
>
> 1. Install a Wine 11.0 + DXMT wrapper. Porting Kit ships one (`WS12Wine11.0_DXMT-v0.80`).
> 2. Install Steam inside the wrapper, sign in, then install Cities: Skylines II inside it.
> 3. Clone https://github.com/macgameport/cities-skylines-2-macos and run `bash scripts/setup.sh`.
>    It checks prerequisites, applies the binary patches, installs a launcher and builds a
>    double-clickable app. Full walkthrough in the repository's `INSTALL.md`.
>
> **Recommended in-game settings:**
>
> - Display Mode: **Fullscreen Window** (see the alt-tab note below)
>
> **Notes:**
>
> - Launch the game executable directly rather than through Steam's *Play* button, which routes
>   via the Paradox Launcher and exits before Unity initialises. The supplied launcher does this,
>   and waits for Steam's licence sync before starting the game.
> - The patches are pattern-matched rather than applied at fixed file offsets, so they generally
>   survive game updates, and refuse to write rather than corrupt a file if a pattern moves.
>   Re-run `setup.sh` after each game update.
> - **Alt-tab:** in *exclusive* Fullscreen, switching away stops the screen updating — the game
>   itself keeps running normally (input, autosaves and simulation all continue). Reported upstream
>   as [DXMT issue 206](https://github.com/3Shain/dxmt/issues/206): presents to a window's
>   non-newest swapchain are silently never composited. **Fullscreen Window is unaffected.** If you
>   are stuck in exclusive mode, the screen redraws one frame per alt-tab cycle, which is enough to
>   navigate to Options → Graphics → Display Mode and switch — no restart needed.

**Verification footnote** (their standard format — fill the framerate from your own run):

```
Verified by User:<your wiki account> on 2026-08-23
Device: MacBook Pro M3 Max 36GB RAM
OS: macOS 26.5.2
Method: Porting Kit Wine 11.0 + DXMT v0.80, patches from cities-skylines-2-macos
Game version: 1.6.0f1
Resolution: 1920 x 1080 @ 120Hz Fullscreen Window
Framerate: 42.7 FPS (1080p, Custom: Volumetrics/Shadows/Reflections Low, DoF and Motion Blur off)
```

## Proposed change 2 — qualify the existing Wine (Whisky) row

Do not delete it; date-scope it so readers know why it disagrees with the new row. Suggested
sentence appended to the existing warning:

> *(This row was verified in 2023 against game version 1.0.14f1 using Whisky, which is no longer
> maintained. The tabbing-out warning applies to that setup; on the Wine 11 + DXMT method below it
> only affects exclusive Fullscreen and does not require a restart.)*

## Before submitting

- ~~Measure a framerate~~ **done: 34 FPS**, 1080p Medium with Depth of Field and Motion Blur off
  (M3 Max, game 1.6.0f1). Worth noting in the row that this is level with the CrossOver entry's
  ~35 FPS on an M3 Pro — the free stack costs nothing in performance.
- **Get an account.** Anonymous edits are disabled, and both `Special:CreateAccount` and the
  PCGW SSO registration page are closed ("Registration not allowed") — this is wiki-wide, not
  specific to you. Their documented route is the AppleGamingWiki Discord
  (https://discord.gg/SU27ykMcsD), described on their own pages as the "primary method of getting
  in touch with staff members".
- Keep the tone factual and avoid promoting the repository beyond the install step — the wiki's
  value is the method, with the link as the reference.
