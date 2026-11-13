# Surviving Mars: Relaunched on Apple Silicon

A launcher and a few tools that run the Windows build of *Surviving Mars: Relaunched* (Steam app
3215050) on an Apple Silicon Mac, inside a Wine wrapper, with saves travelling by Steam Cloud.

**To install it: [INSTALL.md](INSTALL.md).** One line in Terminal makes the wrapper, fetches what it
needs from its publishers, and builds the game's app. No CrossOver and no other game is needed.

**This is one person's integration glue, not a product.** It grew out of the
[Cities: Skylines II](../cities-skylines-2/README.md) port in this repository. If you own CrossOver 26,
the simpler answer is to run the game in CrossOver. What transfers to any setup is the *findings* section.

## What it does

- `scripts/install.sh` — the installer ([INSTALL.md](INSTALL.md)): seven steps from nothing to the game's
  app, each skipped when done, on the installer core this repository's games share
  (`../common/install-core.sh`). `scripts/setup.sh` is its last step, and the way to update: it puts the
  launcher and the click helper in the game's state folder and builds the app to run that copy.
- `tools/fetch-d3dmetal.sh` — fetches the pinned archive that holds Apple's D3DMetal 3.0 from Gcenx's
  release page, takes the six pieces out, and checks them: Apple's signature on the framework and the
  library, a fixed SHA-256 on each of the four DLLs.
- `launch-relaunched.sh` — starts Steam in the game's wrapper, waits for a fresh sign-in and for
  Steam Cloud to pull the latest saves, checks whether Steam has a game update waiting (and offers
  it), runs `Mars.exe` directly, and on exit waits for the cloud upload and shuts Steam down cleanly.
  It refuses to start on a cloud conflict (which would otherwise silently block every later upload)
  or on D3DMetal 2.1, and holds a per-prefix lock so two launches cannot race.
- `tools/split-wrapper.sh` — how the first two Macs were set up, before there was an installer: it built
  `~/Applications/SurvivingMars.app` from the two cs2 wrappers the game used to be spread across
  (`docs/plans/one-wrapper-per-game.md`). An install from nothing does not use it.
- `tools/make-engine.sh --install <wrapper>` — puts D3DMetal 3.0 into a wrapper's own Wine 10 in place
  of its D3DMetal 2.1, keeping the original as `wine.d3dm21-BAK`. The pieces come from the folder named
  by `CX_GPTK` (the installer gives it the one `fetch-d3dmetal.sh` leaves), or, when that is not set,
  from a CrossOver 26 on the Mac. Without `--install` it builds a standalone engine in
  `~/Library/Developer/1launcher/surviving-mars-relaunched/engine/`, for trying another game on
  D3DMetal 3.0.
- `tools/frame-fix.exe` (from `frame-fix.c`) — fixes the click offset the game starts with. It is the one
  built program in this repository: an install needs it and a player has no compiler for it.
  `tools/frame-fix.build` records what built it, `tools/test-frame-fix-build.sh` holds it to its source,
  and `tools/LICENSE-mingw-w64` is the licence of the runtime linked into it.
- `tools/game-input.exe` (from `game-input.c`) — sends clicks to the game from inside its Wine
  session, for testing without a human at the keyboard.
- `make-app.sh` — builds a double-click `Surviving Mars Relaunched.app` that runs the launcher and shows a
  small progress window while the game starts (compiled from `../common/launch-progress.swift`; without the
  Xcode Command Line Tools the app posts notifications instead). It runs the launcher it was built
  with and never pulls: `scripts/setup.sh` builds it to run the copy in the state folder.
- `tools/test-*.sh` and `scripts/test-*.sh` — tests for the launcher's parsing and guards, the installer,
  setup, the fetch and the engine scripts. Each has `MUTANT=<n>` modes that must fail. `tools/licence-wait-probe.sh <s> [runs]` launches the real game that many times at a
  shorter `SM_LICENCE_WAIT` and judges each run from the game's log (plan C2).

## What it assumes

- Apple Silicon and Rosetta 2. Run on macOS 27.2 only; Apple's D3DMetal 3.0 does not load below
  macOS 14, and macOS 28 will not run it. See [Compatibility](../README.md#compatibility).
- A Steam account that owns the game, and about 20 GB of free disk space.
- Apple's Command Line Tools, which the installer asks Apple for when they are missing: the engine swap
  and the app's icon and progress window need them.
- The game's own wrapper, `~/Applications/SurvivingMars.app` (not to be confused with
  `Surviving Mars Relaunched.app`, the double-click app). The installer makes it. The game, its Steam,
  saves, mods and Paradox login all live in it.
- One Steam on this Steam account at a time, across all wrappers and Macs: a second one signing in
  replaces the first's session, and the replaced one skips the cloud upload at exit. Buy and browse in
  the cs2 project's `S734M.app`, the Windows Steam, only while the game is closed.
- The rest of this repository beside this folder, at install time: the shared installer in `../common/`,
  and [`pe-icon.py`](../cities-skylines-2/scripts/pe-icon.py), with which `make-app.sh` takes the app's
  icon from the game (without it the icon is generic).

**This project passes on nothing of Apple's or CodeWeavers'.** No file of theirs is in this repository:
the installer fetches each from its publisher, and the engine is built on the player's Mac and may not be
redistributed. The one built program here is the click helper, `tools/frame-fix.exe`, with its runtime's
licence beside it.

## Setup

The installer does it: [INSTALL.md](INSTALL.md). From a clone it is

```bash
git clone https://github.com/macgameport/1launcher.git ~/github/1launcher
bash ~/github/1launcher/surviving-mars-relaunched/scripts/install.sh
```

Then double-click **Surviving Mars Relaunched** in Applications. The app runs a copy of the launcher kept
in `~/Library/Application Support/1launcher/surviving-mars-relaunched/`, so it does not need the clone;
after `git pull`, run `bash surviving-mars-relaunched/scripts/setup.sh` to renew that copy. For terminal
output, run `bash launch-relaunched.sh` from the clone. Logs: `~/Library/Logs/sm-relaunched-launcher.log`
and the state folder's `runs/`.

The first two Macs were set up before the installer existed, with `tools/split-wrapper.sh` and a
CrossOver 26 as the source of D3DMetal 3.0. On them the installer finds every step done and runs setup.
To rebuild the helper (needs Homebrew's `mingw-w64`; the result must be the committed file):

```bash
x86_64-w64-mingw32-gcc -O2 -Wall -s -Wl,--no-insert-timestamp -o tools/frame-fix.exe tools/frame-fix.c
```

Overrides, all optional: `SM_STATE` (where backups and run logs go, default
`~/Library/Application Support/1launcher/surviving-mars-relaunched`), `SM_WORK` (where `make-engine.sh` builds a standalone
engine, default `~/Library/Developer/1launcher/surviving-mars-relaunched`), `SM_QUIET=1` (alerts, and the progress window or notifications, instead of terminal output), `SM_PANEL=1` (set by the app when its progress window is up),
`SM_UPDATE=ask|apply|skip` (a waiting game update; default asks), `SM_LICENCE_WAIT` (seconds after
sign-in, default 15), `SM_WRAPPER`, `SM_ENGINE`, `SM_STEAM_ENGINE` (launcher); `ENGINE_SRC`,
`CX_GPTK` (make-engine.sh); `SPLIT_*` (split-wrapper.sh, for its test).

On a Mac whose D3DMetal came from CrossOver, after CrossOver updates it: `bash tools/make-engine.sh --install ~/Applications/SurvivingMars.app --rebuild`.

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
  looks like a mismatch in winemac's per-window record. Details: [`EXPERIMENTS.md`](../cities-skylines-2/EXPERIMENTS.md) C83.
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

Surviving Mars joined this repository on 2026-11-09, from a single public commit made on 2026-11-08
in a separate repository. The development history before that is kept privately, so the commit hashes cited in `docs/plans/one-wrapper-per-game.md` and
`tools/archive/wine11/README.md` do not resolve here. Log lines in the test fixtures are copied from
real Steam logs with account identifiers, save names, hashes and batch IDs replaced.
