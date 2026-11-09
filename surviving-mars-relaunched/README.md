# sm-patch — Surviving Mars: Relaunched on Apple Silicon

A launcher and a few tools that run the Windows build of *Surviving Mars: Relaunched* (Steam app
3215050) on an Apple Silicon Mac, inside a Wine wrapper, with saves travelling by Steam Cloud.

**This is one person's integration glue, not a product.** It grew out of the
[cities-skylines-2-macos](https://github.com/macgameport/cities-skylines-2-macos) wrappers, and its
one-time setup still starts from them (see *What it assumes*). If you own CrossOver 26, the simpler
answer is to run the game in CrossOver. What transfers to any setup is the *findings* section.

## What it does

- `launch-relaunched.sh` — starts Steam in the game's wrapper, waits for a fresh sign-in and for
  Steam Cloud to pull the latest saves, checks whether Steam has a game update waiting (and offers
  it), runs `Mars.exe` directly, and on exit waits for the cloud upload and shuts Steam down cleanly.
  It refuses to start on a cloud conflict (which would otherwise silently block every later upload)
  or on D3DMetal 2.1, and holds a per-prefix lock so two launches cannot race.
- `tools/split-wrapper.sh` — the one-time setup: builds `~/Applications/SurvivingMars.app`, the
  game's own wrapper, from the two cs2 wrappers it used to be spread across
  (`docs/plans/one-wrapper-per-game.md`). It refuses to start unless nothing is running and the
  cloud holds the latest saves, and backs up the saves and both Steam manifests first.
- `tools/make-engine.sh --install <wrapper>` — puts D3DMetal 3.0 (taken from a local CrossOver 26
  install) into a wrapper's own Wine 10 in place of its D3DMetal 2.1, keeping the original as
  `wine.d3dm21-BAK`. Without `--install` it builds a standalone engine (`engine/`), which the cs2
  project uses to try its own fallback on 3.0.
- `tools/frame-fix.exe` (from `frame-fix.c`) — fixes the click offset the game starts with.
- `tools/game-input.exe` (from `game-input.c`) — sends clicks to the game from inside its Wine
  session, for testing without a human at the keyboard.
- `make-app.sh` — builds a double-click `Surviving Mars Relaunched.app` that runs the launcher. Each
  launch first runs `git pull --ff-only hub main`. `hub` is a private remote of my own, which a second
  Mac follows; a clone with no remote of that name logs `pull failed` and runs the installed scripts,
  as it does offline. The app runs whatever it pulls, so only ever name a repo `hub` that you alone
  control. A change to `make-app.sh` itself still needs a re-run.
- `tools/test-*.sh` — tests for the launcher's parsing and guards. Each has a `MUTANT=1` mode that
  must fail. `tools/licence-wait-probe.sh <s> [runs]` launches the real game that many times at a
  shorter `SM_LICENCE_WAIT` and judges each run from the game's log (plan C2).

## What it assumes

- Apple Silicon, macOS 27, Rosetta installed (`softwareupdate --install-rosetta`).
- The game's own wrapper, `~/Applications/SurvivingMars.app` (not to be confused with
  `Surviving Mars Relaunched.app`, the double-click launcher `make-app.sh` builds). It is made once by
  `tools/split-wrapper.sh` from two cs2 wrappers: a Kegworks/Sikarugir "Steambuild Metal" wrapper
  (Wine 10 + D3DMetal 2.1) at `~/Applications/S734M.app` with Steam signed in, and the storefront
  wrapper `~/Applications/CS2dxmt11-pk110.app` whose Steam installed the game. After the split the
  game, its Steam, saves, mods and Paradox login all live in `SurvivingMars.app`.
- One Steam on this Steam account at a time, across all wrappers: a second one signing in replaces
  the first's session, and the replaced one skips the cloud upload at exit. Buy and browse in the
  cs2 project's "CS2 Steam Store" app only while the game is closed.
- CrossOver 26 installed, as the local source of D3DMetal 3.0. `CX_GPTK=<dir>` points
  `make-engine.sh` at another `apple_gptk`-shaped directory (Apple's Game Porting Toolkit; untested).
- Homebrew `mingw-w64` to build the two `.exe` helpers (build lines in their headers).
- Optional: a checkout of the cs2 project at `~/github/cs2`. `make-app.sh` uses its
  `scripts/pe-icon.py` for the app icon (without it the icon is generic), and
  `tools/test-launch-lock.sh` also compares the lock code with cs2's launchers when they are there.

**Nothing from Apple or CodeWeavers is in this repository, and nothing built from it may be
redistributed.** `engine/` and the built binaries are gitignored on purpose.

## Setup

```bash
git clone https://github.com/macgameport/surviving-mars-relaunched-macos ~/sm-patch   # the scripts expect ~/sm-patch
cd ~/sm-patch
x86_64-w64-mingw32-gcc -O2 -Wall -o tools/frame-fix.exe tools/frame-fix.c
bash tools/split-wrapper.sh        # once: builds ~/Applications/SurvivingMars.app (seconds; APFS clones)
bash make-app.sh                   # ~/Applications/Surviving Mars Relaunched.app
```

Then double-click the app, or run `bash launch-relaunched.sh` for terminal output (the terminal path
does not pull; `git pull` yourself). Logs: `~/Library/Logs/sm-relaunched-launcher.log`
(each launch starts with a `scripts:` line saying whether it pulled) and `runs/`.

Overrides, all optional: `SM_QUIET=1` (notifications instead of terminal output),
`SM_UPDATE=ask|apply|skip` (a waiting game update; default asks), `SM_LICENCE_WAIT` (seconds after
sign-in, default 15), `SM_WRAPPER`, `SM_ENGINE`, `SM_STEAM_ENGINE` (launcher); `ENGINE_SRC`,
`CX_GPTK` (make-engine.sh); `SPLIT_*` (split-wrapper.sh, for its test).

After CrossOver updates its D3DMetal: `bash tools/make-engine.sh --install ~/Applications/SurvivingMars.app --rebuild`.

## Findings that apply to any Wine or Proton setup

- **The game is DirectX 12 only** (`Mars.exe` loads `d3d12.dll`, no D3D11 or Vulkan path), so on
  macOS it needs D3DMetal; DXMT is D3D11-only.
- **D3DMetal 2.1 blacks out the map whenever a landscaping project exists** (RC Dozer: Flatten,
  Ramp, ...), and a save holding one loads black every time. D3DMetal 3.0 renders it. So the
  Kegworks/Whisky-era wrappers fail here and CrossOver 26 does not.
- **Clicks land sideways at start.** The fullscreen window keeps a stale frame allowance from the
  style it was created with; `SetWindowPos(SWP_FRAMECHANGED)` recomputes it. Toggling window mode
  twice (Alt+Enter) does the same, which is the workaround the Proton forum thread uses.
- **Launched outside Steam, a cloud conflict blocks every upload without a word.** Steam only asks
  "keep local or cloud?" when it launches the game itself. Read `logs/cloud_log.txt` after exit.
- **Steam only pulls a game's cloud saves at sign-in if the game is installed in that Steam.**
- **Without its cloud cache (`userdata/<id>/<appid>/remotecache.vdf`), Steam re-downloads every cloud
  file at sign-in** (measured: 10 files, 22 s, no conflict when the local copies matched). It holds the
  SHA-1 of every file as Steam last synced it, and Steam stamps a downloaded file with its cloud time, so a
  save that differs from its entry, or has none, is one the cloud does not have.
- **D3DMetal 3.0 does not run on Wine 11.** Its DLLs import `ntdll.__wine_unix_call`, which
  Wine 11 dropped; supplying it another way gets the DLLs loaded, but the game then crashes on what
  looks like a mismatch in winemac's per-window record. Details: cs2 `EXPERIMENTS.md` C83.
- **One launcher per Wine prefix.** Relaunching while the previous launcher is still shutting Steam
  down reuses the dying Steam and the game crashes at start.
- **The game does not need cs2's 45 s after sign-in.** Started 17 s or 32 s after sign-in (5 runs
  each), `Mars.exe` initialised Steam at once and owned both DLCs every time; the menu came at
  sign-in + 39 s and + 54 s, against + 57 s with a 45 s wait.
- **The game sometimes stalls a fixed 13.5 s at start**, between `Build branch` and `Account storage
  loaded` in its log: 17 of 33 logged start-ups took 12.3–13.6 s there, the other 16 took 2.1–9.7 s.
  It happened in 10 of 10 runs started within 32 s of sign-in and 7 of 23 started at 46 s. Cause not
  identified: Steam's logs and Wine's output are the same in stalled and quick runs, and sessions
  that stalled played normally. (It is not a wait for a moment after sign-in; with a 30 s wait it
  merely happens to end at sign-in + 48 s.)

## Known limits

- Steam Workshop subscriptions are untested; Paradox Mods work from the in-game Mod Manager.
- No frame cap is saved by default; set VSync or a limit in Options > Video if the Mac runs hot.
- There is no arm64 path: D3DMetal is not in CrossOver's ARM64 preview (cs2 #21).

## History

This repository starts from a single commit on 2026-11-08. The development history before that is
kept privately, so the commit hashes cited in `docs/plans/one-wrapper-per-game.md` and
`tools/archive/wine11/README.md` do not resolve here. Log lines in the test fixtures are copied from
real Steam logs with account identifiers, save names, hashes and batch IDs replaced.
