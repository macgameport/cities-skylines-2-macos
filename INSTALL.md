# Install guide

Getting **Cities: Skylines II** running on an Apple Silicon Mac, free — no CrossOver licence.
Mods included.

**Time:** about 20 minutes of clicking, plus however long the game takes to download.
**You need:** an Apple Silicon Mac (M1 or newer) on macOS 13+, the game already owned on Steam, and
roughly 40 GB free.

> Tested on an M3 Max running macOS 26 with game version 1.6.0f1. Intel Macs are untested. A game
> update can move the patch offsets — see [After a game update](#after-a-game-update).

---

## 1. Install the Wine wrapper

The stack is ordinary Wine plus **DXMT**, which translates the game's Direct3D 11 calls to Metal.
The easiest way to get a Wine build with the pieces DXMT needs is
**[Porting Kit](https://www.portingkit.com/)** — free, and it ships the engine this project is
built on (`WS12Wine11.0_DXMT-v0.80`).

1. Download and install Porting Kit.
2. Create a new wrapper using the **Wine 11.0 + DXMT** engine.
3. Name it `CS2dxmt11` — the scripts look for `~/Applications/CS2dxmt11.app` by default. Any name
   works if you pass `CS2_WRAPPER=/path/to/Wrapper.app` later.

Porting Kit's UI changes between versions, so follow their current instructions for creating a
wrapper. What matters is the end state: **`~/Applications/CS2dxmt11.app` exists and contains
`Contents/SharedSupport/prefix`**.

*If Porting Kit is doing something useful for you, donate to them — this project only exists
because they publish that engine.*

## 2. Install Steam inside the wrapper

Steam has to live **inside** the wrapper's Windows prefix, not your Mac's Steam.

1. Download the Windows Steam installer (`SteamSetup.exe`).
2. Run it inside the wrapper (Porting Kit's "Install software into wrapper", or from a terminal:
   `WINEPREFIX=~/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix \
    ~/Applications/CS2dxmt11.app/Contents/SharedSupport/wine/bin/wine64 ~/Downloads/SteamSetup.exe`)
3. Launch Steam inside the wrapper and **sign in**, letting the library finish loading. Tick "remember
   me" so later launches sign in on their own.

## 3. Install the game

In that same in-wrapper Steam, install **Cities: Skylines II** and let it download fully.

Don't press **Play** when it finishes — it won't work. Steam's Play button routes through the
Paradox Launcher, which exits before the game starts. The launcher this project installs runs the
game executable directly, which is the whole trick.

## 4. Run setup

```bash
git clone https://github.com/macgameport/cities-skylines-2-macos.git
cd cities-skylines-2-macos
bash scripts/setup.sh
```

That checks your prerequisites, installs the launcher into `~/cs2-patch/`, applies the binary
patches, and builds a double-clickable **Cities Skylines II.app** in `~/Applications` using the
game's own icon.

Want to look before it touches anything? `bash scripts/setup.sh --check` runs the checks and stops.

## 5. Play

Double-click **~/Applications/Cities Skylines II.app**.

The first launch starts Steam inside the wrapper and waits about 45 seconds for Steam to confirm
your licence — skipping that wait causes a flood of errors and no main menu. When Steam is already
running, the wait is skipped.

**One setting to change, in-game:** Options → Graphics → **Display Mode → Fullscreen Window**.

Exclusive Fullscreen has a presentation bug on this stack: alt-tab away and the screen stops
updating, even though the game is still running fine underneath. It's
[reported upstream](https://github.com/3Shain/dxmt/issues/206); Fullscreen Window looks identical
and is immune. (If you ever do get stuck in exclusive mode, you're not dead — the screen redraws
one frame per alt-tab, so you can alt-tab your way to Options and switch modes.)

---

## 6. Recommended: build the wine 11.16 engine (kills the alt-tab freeze)

The base stack above runs on Porting Kit's wine 11.0 engine, which has one real defect: in
exclusive Fullscreen, switching away (Cmd-Tab, or just clicking another window/display)
permanently freezes the render ([dxmt#206](https://github.com/3Shain/dxmt/issues/206)). Wine
**11.16 fixed it upstream**, but no prebuilt clean-base 11.16 DXMT engine exists yet — so this
repo builds one, locally, from the official Wine source:

```bash
bash scripts/build-engine-1116.sh
```

⚠ **One trade-off, decided by measurement:** the 11.16 engine kills the alt-tab freeze and is
faster, but **Steam's visible storefront window is black on it** (the game, its login, licences
and Paradox Mods downloads are all unaffected — the daily flow runs Steam in tray mode). The
build script handles this for you: it preserves the wine 11.0 wrapper as `CS2dxmt11-pk110.app`
(an APFS clone — under a minute, ~no extra disk, the game install stripped from the clone) and
installs **CS2 Steam Store.app** in `~/Applications`. Play from **Cities Skylines II.app**; buy
DLC and browse from **CS2 Steam Store.app** — licences are account-level, so purchases cross
over immediately. One account holds one online Steam session, so opening the store while
playing steals the session from the game's Steam; measured harmless — the game keeps running,
and the next game launch takes the session back. Built the engine before this existed?
`bash scripts/make-steam-shortcut.sh` retrofits the wrapper + shortcut. Cause and the full
list of attempted workarounds: [GOTCHAS.md](GOTCHAS.md) and
[dxmt#141](https://github.com/3Shain/dxmt/issues/141).

Roughly an hour, mostly unattended compile. It redistributes nothing: the Wine source comes
sha256-verified from winehq.org, the winemac DXMT patch is in this repo (aquadran's, with
attribution), and the DXMT binaries + x86_64 support dylibs are reused from *your own* wrapper.
Your old engine is kept beside the new one (`wine.pk11.0-BAK`) — rollback is one `mv`, printed
at the end of the script.

What you get, measured (M3 Max, 2026-08-23): the freeze gone — minimize/restore and alt-tab in
exclusive Fullscreen come back live; **Direct** presentation (the 11.0 stack composited);
~45 FPS where the same city/settings measured 42.7 before; in-game mod downloads still work
(same 10 patches — the file-IO probe is identical to 11.0). Exclusive Fullscreen becomes the
mode to use; Fullscreen Window remains fine too. You also get **CS2 Steam Store.app** — the
storefront, one double-click away in the preserved 11.0 wrapper.

Validated on one machine so far — if it misbehaves on yours, roll back and open an issue with
`~/Library/Logs/cs2-launcher.log`.

## Measuring performance

The game has no usable built-in FPS counter, so use Metal's own HUD. From a terminal:

```bash
CS2_HUD=1 bash ~/cs2-patch/launch-cs2-dxmt11.sh
```

You get Apple's Metal performance HUD (frame rate, frame time, GPU time) with DXMT's own lines
added underneath — commit, sync and encode timings, plus render-pass counts. That breakdown is what
tells you whether you're GPU-bound or stalling on the CPU side before you start changing settings.

**Measured:** 34 FPS at 1080p on an M3 Max with just Depth of Field and Motion Blur off, rising to
**42.7 FPS** with Volumetrics, Shadows and Reflections on Low (game 1.6.0f1). For comparison the
CrossOver route reports ~35 FPS on comparable hardware — the free stack costs you nothing in
performance, and this machine is GPU-bound, so lowering effects keeps paying.

Two things that move the number most on this stack, in order: **Depth of Field** and **Motion
Blur** off, then **Volumetrics** and **Shadows** down. Resolution matters less than you'd expect —
1080p on a 120 Hz display is a good starting point.

Experimental: `CS2_METALFX=1` renders through a MetalFX spatially-upscaled swapchain (upscale factor
from DXMT's `d3d11.metalSpatialUpscaleFactor`, default 2). It may buy frames at the cost of some
sharpness. Untested here — report what you find.

## After a game update

Game updates replace the patched DLLs, so the fixes need re-applying:

```bash
cd cities-skylines-2-macos && git pull && bash scripts/setup.sh
```

The patches are pattern-matched rather than hardcoded to file offsets, so they usually survive
updates. Each one refuses to write if it can't find its pattern — it will never corrupt a file. If
one does report a miss, please open an issue.

## Troubleshooting

| Symptom | What's happening |
|---|---|
| "Steam did not auto-login" | The saved token expired. Open Steam inside the wrapper, sign in until the library loads, then relaunch. |
| Game exits immediately, launch fails with code 1 | A stale `.crash` marker from a force-kill. The launcher clears it automatically now; if it persists, delete `.../Steam/.crash` inside the prefix. |
| Black screen with a working cursor | The Coherent Gameface UI fix didn't apply. Re-run `bash scripts/setup.sh` and check its patch output. |
| Mods won't download ("Preparing 2%", IO errors) | You're on Wine 10 rather than Wine 11, or the patches aren't applied. Wine 11 fixes the underlying bug — check the wrapper's engine. |
| Screen freezes after alt-tab | Exclusive Fullscreen. Switch to Fullscreen Window (see step 5). |
| "IOEXCEPTION — Failed to read settings file with GUID ... Invalid handle to path [Unknown]" | **Cosmetic — press Continue.** The game asks for optional settings files that were never created; on Wine an absent file surfaces as an invalid handle instead of a clean not-found, so the game shows its error dialog. Your settings are still applied and saved. Most common right after changing graphics options or at boot. |
| Mods show a ⚠ badge | Keybinding conflicts, not a port problem — same on Windows. Options → Keybinds. |
| Second display goes black | Refresh-rate mismatch. Match both displays' refresh rates. |
| Steam's store/library window is black (game still works) | Expected on the wine 11.16 engine — upstream limitation ([dxmt#141](https://github.com/3Shain/dxmt/issues/141)), not a setup error. Double-click **CS2 Steam Store.app** (installed by the engine build; retrofit with `bash scripts/make-steam-shortcut.sh`) — it opens Steam in the preserved wine 11.0 wrapper; licences are account-level so purchases apply to both. See README "Three things worth knowing". |

More traps, each with its root cause, in **[GOTCHAS.md](GOTCHAS.md)**. What every patch does and why
is in **[docs/patch-inventory.md](docs/patch-inventory.md)**.

## Uninstall

```bash
rm -rf ~/Applications/"Cities Skylines II.app" ~/Applications/"CS2 Steam Store.app" ~/cs2-patch
```

Then delete the wrappers (`~/Applications/CS2dxmt11.app`, and `~/Applications/CS2dxmt11-pk110.app`
if the engine build created it) via Porting Kit or the Finder. Nothing is installed outside those
paths.
