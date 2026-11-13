# Surviving Mars: Relaunched from nothing, without CrossOver, on one shared installer

> **Status:** Triple-checked 2026-11-11 — build-ready-with-fixes, corrections folded (pass 1: four lenses;
> pass 1b: a fitted check of that fold, one blocker, folded too). Four changes were folded after the check
> ("After the check", below) and checked the same evening by one agent; its findings are folded. Re-checked 2026-11-13 against the
> shared installer as built (pass 3: a reference lens and a builder; "Third-pass re-check", below):
> build-ready-with-fixes, folded; that fold was checked by one agent the same day (pass 3b), and its
> findings are folded too. Written 2026-11-11.
>
> Tracking: issue #22. The installer this builds on exists only on the branch `simple-install`, where
> the shared-installer plan is built; references to `install.sh`, `common/install-core.sh`,
> `common/make-wrapper.sh`, `common/fetch.sh`, `cities-skylines-2/scripts/install.sh`,
> `common/make-installer-app.sh`, their tests, and `common/test-launch-lock.sh` with the core as its third
> file, are as of that branch at `4d339dd` (pass 3). Every other reference is as of `main` at `8ee1ad2`;
> nothing under `surviving-mars-relaunched/`, and neither `common/games.tsv` nor
> `common/launcher-window.swift`, differs between the two. A path is relative to the repository root. "The installer plan" is
> `docs/plans/simple-install.md`, with its steps N1 to N6 and live steps NL1 to NL5. This plan's steps are
> M0 to M8, its tests MT1 to MT10, its live steps ML1 to ML7 (with ML4b) and its decisions MD1 to MD10. Since
> 2026-11-11 the shared installer is a plan of its own, `docs/plans/shared-installer.md` ("the
> shared-installer plan"): step M1 and tests MT1, MT2 and MT5 are there. Of the live steps, ML1 (2026-11-11), ML2
> (2026-11-13) and ML3 (2026-11-13) are done; their records are in 1.4, and what ML2 found besides is section 5a. Every number
> marked "measured" was measured on the Studio (M5 Max, macOS 27.2.1) on 2026-11-11; the records are in
> `~/Library/Application Support/1launcher/surviving-mars-relaunched/runs/d3dmetal-source-probe-20261111/`
> (`SUMMARY.txt` first).

## 0. What James asked for (2026-11-11)

"should we have one installer handle everything?", then, on hearing what Surviving Mars depends on: "we
need SMR to run without needing crossover or the launcher is still just a cs2 wrapper, not a launcher".
After the probe of section 1.4: "Write the plan". And of the time it takes: "no one is waiting for any of
this. We're just doing it for the sake of doing it. And doing it well." At the session's close: "is our
path to the best solution?", and of the four changes then offered, "Fold all four".

So two things, and the second serves the first:

1. A person with an Apple Silicon Mac and a Steam account that owns Surviving Mars: Relaunched can install
   and play it with nothing else: no CrossOver, no wrapper of another game already on the Mac, no compiler.
2. The installer is one program with a short list of settings per game, not one program per game.

## 1. What is true today (read or measured)

### 1.1 How the game is set up today

- There is no install from nothing. `surviving-mars-relaunched/README.md:44` says so: the one-time setup,
  `tools/split-wrapper.sh`, makes `~/Applications/SurvivingMars.app` by cloning one Cities: Skylines II
  wrapper and moving the game out of another (its header, phases A0 to A4b). `README.md:47-57` describes
  those wrappers and the Steam app of that project.
- D3DMetal 3.0 comes from a CrossOver 26 on the same Mac (`README.md:58`). `tools/make-engine.sh:57-61`
  looks in `CX_GPTK` and then in the two places CrossOver installs to, taking the first that holds the
  framework, so a `CX_GPTK` folder that is wrong is passed over without a word; `:74` stops with none. What
  it takes is six pieces (`:86-92`): `external/D3DMetal.framework`, `external/libd3dshared.dylib`, and
  `wine/x86_64-windows/` `atidxx64.dll`, `d3d11.dll`, `d3d12.dll`, `dxgi.dll`. It also runs `nm` (`:63`),
  which on macOS is a stand-in until Apple's Command Line Tools are installed (measured: `/usr/bin/nm`
  links `libxcselect`; `codesign` and `plutil` do not).
- The game is DirectX 12 only (`README.md`, "Findings"; `launch-relaunched.sh:4-5`), so it needs D3DMetal:
  DXMT, the Cities: Skylines II engine, is Direct3D 11. Under D3DMetal 2.1 a landscaping project turns the
  whole map black; 3.0 renders it. The launcher refuses a version below 3 (`launch-relaunched.sh:139-143`;
  the pattern at `:142` is `[3-9].*`).
- The click-offset helper, `tools/frame-fix.exe`, is built with Homebrew's `mingw-w64` (`README.md:63`,
  `:78`) and is not in the repository (`surviving-mars-relaunched/.gitignore:9`). Without it the launcher
  goes on and tells the player to press Option+Return twice (`launch-relaunched.sh:373-378`).
- The double-click app runs the launcher inside the checkout (`make-app.sh:22`; "It runs the scripts in
  this checkout and never pulls", `README.md:32-33`). An install made from a temporary copy of the
  repository would leave an app that points at a folder macOS later removes.

### 1.2 What the launcher needs from a wrapper

Read from `launch-relaunched.sh`: a wrapper at `~/Applications/SurvivingMars.app` or `SM_WRAPPER` (`:71`);
in it `Contents/SharedSupport/wine` with D3DMetal 3 or later (`:76`, `:139-142`), `Contents/Frameworks`
(`:79`), and a prefix holding Steam for Windows signed in and the game at
`steamapps/common/Project Spark/Mars.exe` (`:73`, `:145`) with `appmanifest_3215050.acf` (`:95`). The
launcher writes `steam_appid.txt` itself (`:363`) and sets its own environment (`:77-84`), which includes
`WINEESYNC=1 WINEMSYNC=1`; a Wine program started without them against a Wine server that has them dies
(`:80-82`). It asks nothing of the wrapper's own launcher or `Info.plist`.

Two things about Steam decide how a test of it must be run. The launcher uses a Steam that is already
running and does not sign in again (`:234-235`). And Steam pulls a game's cloud saves at sign-in only when
the game is installed in it (`:44-46`, `README.md:112`). So a Steam that was signed in before the game was
there never pulls, and the game then starts on an empty save folder and writes a new settings file, which
is the silent-conflict case of `:41-43`.

### 1.3 Where the pieces are published (read 2026-11-11, each row checked against GitHub by a reviewer)

| Piece | Published by | File | Bytes | sha256 |
|---|---|---|---|---|
| Wrapper template | Porting Kit, `vitor251093/porting-kit-wrappers`, release `Wineskin-3.0.6-2` | `Wineskin.app.tar.7z` | 53,110,672 | `fbe276bb...907a` (the installer plan's pin, `common/make-wrapper.sh:19-21`) |
| Wine 10 | Porting Kit, `vitor251093/porting-kit-engines`, release `wineskin` | `WS12WineSikarugir10.0_2_D3DMetal-v2.1.tar.7z` | 183,963,888 | `a2f9322f3e6160453d9b31891e91d17a7c1f0b752c1804416880792c37d125d2` (downloaded at ML1, matches) |
| D3DMetal 3.0 | Gcenx, `Gcenx/game-porting-toolkit`, release `Game-Porting-Toolkit-3.0-3` (2026-03-03) | `game-porting-toolkit-3.0-3.tar.xz` | 239,200,808 | `d377683937340f914823dbb2e1252b329cbf834ff58907d0293db8cebf0e392e` (downloaded, matches) |
| Steam for Windows | Valve | `SteamSetup.exe` | 2,380,800 (the installer plan, `docs/plans/simple-install.md:201`) | the tested value at `common/install-core.sh:25` |

Each file's address is `https://github.com/<repository>/releases/download/<release>/<file>`.

The wrapper's own Wine names itself: `wine.d3dm21-BAK/version` reads "wine sikarugir 10.0 (revision 2
D3DMetal-v2.1)", which is the name of the second row, and ML1 measured that the published file is that
Wine (1.4). No published engine names D3DMetal 3.0: of the 300 files
of Porting Kit's `wineskin` release 16 name D3DMetal and the highest is v2.1; `Sikarugir-App/Engines` has
none (by file name; contents not inspected). That repository also publishes `WS12WineSikarugir10.0_2.tar.xz`
(166,278,716 bytes), the same Wine by name with no D3DMetal in it; ML1 measured it to be another build
(1.4), and it is not used.

Porting Kit's `wineskin` is one rolling release whose files can be replaced in place; Gcenx makes a new
release per build, and every older one still has its file.

### 1.4 The probe (measured)

- Gcenx's archive holds one folder, `Game Porting Toolkit.app`: 6,041 entries (5,235 files, 563 folders,
  243 links), none absolute, no name with a `..` part, no hard link, no set-user or set-group bit. The six
  pieces are under `Contents/Resources/wine/lib/`, in the layout `make-engine.sh` reads (`external/`,
  `wine/x86_64-windows/`). Taken out, they are 15 files (10 in the framework, the library, 4 DLLs) and 3
  links, all inside the framework: `D3DMetal -> Versions/Current/D3DMetal`,
  `Resources -> Versions/Current/Resources`, `Versions/Current -> A`. Nothing from the archive was run.
- `D3DMetal.framework`: all 10 files are byte-identical to the copy the game runs on today, which came from
  CrossOver 26.2. Version 3.0 in both; its lowest macOS is 14.0. This passes on the downloaded copy:
  `codesign --verify --strict -R '=identifier "com.apple.D3DMetal" and anchor apple' <framework>`. The
  leading `=` is needed: without it `codesign` takes the words for a file name and fails.
- `libd3dshared.dylib`: byte-identical, and signed by Apple too: the same command with
  `com.apple.libd3dshared` passes.
- **What the signature does not notice:** a copy of the framework with a file added at `Versions/B/` still
  passes the check at its root. A byte changed inside `Versions/A` fails it.
- The four DLLs are not signed in Gcenx's archive. Against CrossOver's: every PE section, the link stamp,
  the imports and the exports are equal. CrossOver's copies carry a certificate table of 7,744 bytes at the
  end (CodeWeavers' signature); within the length of Gcenx's file 7 bytes differ, the header's checksum and
  the entry that points at that table. Their sha256, with the library's:

  | File | Bytes | sha256 |
  |---|---|---|
  | `libd3dshared.dylib` | 95,952 | `5131e631eee8b542eadf48f4df9fd662d9aeeb59139137e0e6e14047dc434995` |
  | `atidxx64.dll` | 106,496 | `bd004dd9e41415b0e1395d51a2ded762a02c7731491e74ed6076f3648ae9ea7f` |
  | `d3d11.dll` | 106,496 | `05fa6f700fb5ee5561dc3a46d98f0aed845d4fa8ab274bff1dc604b0b3f6edd1` |
  | `d3d12.dll` | 114,688 (CrossOver's: 122,432) | `27dcf69bedb20ed557a83953e356ab2477b688c2a2c631f880b7583f30ff0705` |
  | `dxgi.dll` | 86,016 | `249711d3d786a9b0bb7c3558f36e472ab07ee21b8dbf118e34c975046832f9a2` |

- `CX_GPTK=<the archive's lib folder> bash tools/make-engine.sh <out>` ran for the first time and built an
  engine. `diff -rq` against the installed engine: the four DLLs and nothing else, 4,789 files on each
  side. It is kept as `~/Library/Developer/1launcher/surviving-mars-relaunched/engine/wine-d3dm30-gcenx`.
- `tools/frame-fix.exe`: built as the header says, it holds the compiler package's own build paths in its
  debug sections (64 strings under `/private/tmp/mingw-w64`, 18 under `/opt/homebrew/Cellar/mingw-w64`),
  and two builds differ in 2 bytes (the link stamp). Built with `-s` and `-Wl,--no-insert-timestamp` it is
  17,920 bytes, two builds are byte-identical, and it holds none of those strings and no `/Users/`
  (`mingw-w64` 14.0.0_3 from Homebrew, gcc 16.2.0). The stripped helper works, and from a folder whose
  path holds spaces (ML2, below).
- The game is 10,816,563,427 bytes on disk by Steam's count (build 25579348).
- **ML1 (2026-11-11; records in the game's `runs/ml1-wine10-20261111/`).** Porting Kit's Wine 10 archive
  matches GitHub's digest and unpacks to one folder, `wswine.bundle`, holding `bin/wine64` and
  `bin/wineserver`, which is the layout `make-wrapper.sh` expects. Every one of its 4,703 files is in the
  wrapper's `wine.d3dm21-BAK`, byte for byte, and no file differs. The wrapper's Wine holds 86 files
  more, all libraries directly in `lib/`, each byte-identical to the file of the same name in the
  wrapper's own `Contents/Frameworks`: copies of the template's libraries, made after the Wine was
  unpacked. The Cities: Skylines II wrapper shows the same. Both launchers put `Contents/Frameworks`
  first on the library path. The archive without D3DMetal is another build: 1,543 of its files differ,
  its program is `bin/wine` with no `bin/wine64`, and it has none of D3DMetal's pieces.
- **ML2 (2026-11-12 and 2026-11-13; records in the game's `runs/ml2-20261112/`, `notes.md` first).** A
  wrapper made from nothing ran the game. In the order of the step:
  - **The wrapper.** The branch's `common/make-wrapper.sh` (at `d16156d`) was run as it is, with the engine
    given as options, so no changed copy was needed. It made a 1.4 G wrapper with wine-10.0 (Sikarugir) and
    no quarantine attribute. **It did not return for 85 minutes:** the template's
    `wineskinlauncher WSS-wineprefixcreate` finished the prefix within a minute and then waited until no
    process named `wineserver` ran anywhere on the Mac (`killall -0 wineserver` in its own loop). A
    storefront Steam was open in another wrapper; 23 s after it was quit the build returned with exit 0.
  - **The 86 library copies** are not made: the new wrapper's Wine holds the archive's 4,703 files and
    nothing more. The game runs without them.
  - **D3DMetal 3.0** went in with `make-engine.sh --install` and `CX_GPTK` at Gcenx's pieces in one second;
    `d3d12.dll` is 114,688 bytes. The first Wine start after it took 7 s and did not update the prefix
    (`.update-timestamp` unchanged).
  - **Steam.** Its installer ran in 7 s. Its first start failed on its own update exactly as at the
    shared-installer plan's SL1: the default route was a VPN tunnel, the update (336 MB from
    `cdn.steamstatic.com`) reached about 21 MB in 83 s, then every package "failed after 0 bytes" and Steam
    stopped at "Steam needs to be online to update"; a transfer of one package by `curl` was cut twice.
    `-shutdown` did not end that Steam within 30 s; `wineserver -k` did, and left the 0-byte `.crash`
    marker. With the VPN paused, one start carried Steam through two updates of itself to its sign-in
    window in 53 s, with no restart by hand: the "first start fails, the second works" of Cities:
    Skylines II did not show.
  - **The sign-in and the clone.** James signed in with "Remember me". The game's folder and manifest were
    cloned in under a second with no disk used, and `-shutdown` closed Steam in 6 s.
  - **The game.** The scratch copy of the launcher printed "Steam Cloud: saves up to date." on both starts;
    Steam signed in by itself with no window; all eight saves were pulled. The game's process was the new
    wrapper's `wine64` with its 3.0 `d3d12.dll`. The stripped helper, beside the launcher in a folder whose
    path holds spaces, logged `found`, `stale`, `fixed ... client 2560x1440` at 1.7 s. James loaded the
    save with the landscaping project and said "Map is fine". Each exit uploaded with result OK.
  - **A mod.** The first start opened with "The following mods couldn't be loaded ...
    SMR_CommunityFixPack". The mod is a Paradox Mods download in
    `AppData/Roaming/Surviving Mars Relaunched/PdxMods/`, outside Steam and Steam Cloud. The game fetched
    its file again by itself during that start, but from then on the mod was switched off: the game's log
    at the save's load says "present, but not loaded" and has none of the mod's 44 "applied" lines, and the
    cloud-synced `account.dat` shrank from 4,633 to about 4,600 bytes. The real wrapper pulled that file
    and started with the mod off too. It came on again while James was in the game's mod manager (he found
    it "Already on"; the log shows the 44 lines at that moment), and `account.dat` is 4,634 bytes again. So
    the save of step 7 was looked at without its mod; the save James then played and saved in the real
    wrapper had it.
  - **What the old prefix holds besides** (`step8-prefix-compare.txt`): 30 library overrides in the
    registry (the Visual C++ runtimes of 2010 to 2022, `d3dcompiler_47`), 27 uninstall keys against 2,
    85 files in `system32` and 84 in `syswow64` that are not Wine's, and a `winetricks.log` naming
    `vcrun2010`, `2012`, `2013`, `2022`, `ucrtbase2019`, `d3dcompiler_47`, `corefonts` and `steam`. The new
    prefix has none of it and reached the menu, loaded the save and showed the map. A session of play in
    such a prefix is not measured.
  - **After.** The real wrapper's next launch printed "Steam Cloud: saves up to date." with no conflict.
    Steam was signed out in the scratch wrapper (its `loginusers.vdf` no longer holds the account) and
    `SMfresh.app` is in the Trash. At the real wrapper's next start after that sign-out (ML3, below) Steam
    signed in by itself.
  - Sizes: the scratch wrapper 14 G by `du` with the game cloned in, Steam alone 1.7 G; the real wrapper 17 G.
- **ML3 (2026-11-13; records in the game's `runs/ml3-20261113/`, `notes.md` first).** The real wrapper ran
  the game on the engine made from the public pieces, with nothing in the wrapper replaced.
  - **Before.** No Wine or Steam process ran. `d3d12.dll` in that engine is 114,688 bytes, against 122,432
    in the wrapper's own; `diff -rq` between the two engines names `atidxx64.dll`, `d3d11.dll`,
    `d3d12.dll` and `dxgi.dll` and nothing else.
  - **The start.** `SM_ENGINE=<that engine> bash surviving-mars-relaunched/launch-relaunched.sh`, at
    `b0a776a`, from the session's shell with its output in a file, not from Terminal. The launcher printed
    "Steam Cloud: saves up to date." and found the game's build current. The game, Steam, the helper and
    `wineserver` were all processes of that engine, and the game had that engine's `d3d12.dll`, `dxgi.dll`,
    `D3DMetal.framework` and `libd3dshared.dylib` open. Wine did not update the prefix
    (`.update-timestamp` unchanged, at the start and after the exit).
  - **The game.** Its log names `wine-10.0 (Sikarugir)`, `d3d12` and feature level 12.1. The mod was loaded
    from the start (its 44 "applied" lines, no "present, but not loaded"). The game then sat at its menu
    for 1 h 46 min, James being away. He loaded the save with the landscaping project, played 4 min 48 s,
    saved it and quit. Asked afterwards: the landscaped terrain "Drew correctly", and against his normal
    game "Nothing different". He let that length stand as the step's session.
  - **Against the wrapper's own engine.** The launcher's Wine log of this start has 152 lines, 3 `err:`
    lines (Kerberos and NTLM, at Steam's start) and 2 lines of D3DMetal's "Unsupported API" (`EndQuery`
    and `ResolveQueryData`, type 2). The six logs of starts on the wrapper's own engine from 2026-11-11
    to 2026-11-13 have the same counts (one has 154 lines).
  - **The exit.** The game ended with code 0; Steam uploaded the save and the account file with result OK
    (change number 75 to 76); the launcher returned 0, with no process and no `.crash` marker left.
- The builder lens of this plan's check built the shared installer (now the shared-installer plan's S2) and
  M3 in a scratch tree: the reduced Cities: Skylines II
  installer passes the 96 cases of `test-install.sh` (run again by the planner), and its per-case output
  equals the installer's of `6a66416` once the scratch folder's name is replaced; the fetch script, run on
  the real archive with no network, took 14.5 s and left the same pieces the probe took out by hand.

### 1.5 Apple's licence for the toolkit (read in full)

The release notes of Gcenx's archive link Apple's "Software License Agreement for Game Porting Toolkit"
(EA18380, 8/17/2023) as a file attached to that release page; the archive itself holds no copy, and the
address is Gcenx's, not Apple's. The text is of 2023 and the framework was signed in November 2025;
whether Apple's own download of 3.0 carries newer terms, and whether the five pieces outside the framework
sit in Apple's `/redist` folder, are not verified (M0). What the text says, by section:

- **Use is limited by purpose.** 1A: only for the purposes the agreement names. 2A(i): to install,
  internally use and test it for the sole purpose of developing, testing or evaluating video games for
  Apple-branded products. It does not name playing. By using it one agrees (the preamble).
- **Passing it on is limited to non-commercial purposes** (2A(iii)), with Apple's notices kept on every
  copy (2A). The framework as a whole, and any part of the toolkit's `/redist` folder, may be passed on
  apart from the rest (2C). 2C also says the software may not be hosted.
- 2C: only on Apple-branded hardware. 2D: no copying beyond the grant, no modification, no reverse
  engineering, no derived work.
- 5: the licence ends when Apple says so, and without notice on any breach; all copies must then be
  destroyed. 6: the user indemnifies Apple.

Porting Kit's D3DMetal engines rest on the same text, the 2.1 engine this game's wrapper already starts
from among them. This project passes on nothing of Apple's: the installer fetches each file from its
publisher and builds the engine on the player's Mac. `README.md:69-70` says today that nothing from Apple
or CodeWeavers is in this repository; that stays true. This is a reading of the text, not legal advice.

### 1.6 The installer this is built on

The installer of the branch `simple-install`, and what in it belongs to one game, is described in
`docs/plans/shared-installer.md` ("the shared-installer plan", its 1.1), which moved it into a shared core
before this plan's code was written. What this plan relies on from there: a game's installer is
`<game>/scripts/install.sh`, which the bootstrap reaches through the game's row in `common/games.tsv`; it
sets its settings and calls the core's stages in order, with its own between them; the lock is taken
after the wrapper stage and held to the end; and `common/make-wrapper.sh` takes the engine as options.
The 14unch3r window shows a game with no app as "Not set up" and opens its guide
(`common/launcher-window.swift:165`, `:755`).

### 1.7 What is not known

1. Answered by ML3 (1.4): the game and Steam run on an engine made from Gcenx's pieces, whose DLLs lack
   CodeWeavers' signature. Measured for one start and a session of under five minutes.
2. Answered by ML2 (1.4): a wrapper made from nothing does not get the 86 library copies, and the game
   does not need them.
3. Answered by ML2 as far as the menu, a save's load and the map: a prefix made from nothing runs Steam
   and the game, without the Visual C++ runtimes and the rest that the old prefix holds. **Still not
   known:** whether a session of play needs any of it.
4. Answered by ML2: Steam's installer and its first start work in one go on Wine 10 with D3DMetal 3.0 when
   the route to Valve's server holds, and the first Wine start after the engine swap does not update the
   prefix.
5. Answered by ML2: the helper works stripped, from a folder whose path holds spaces.
6. Whether Play inside Steam works for this game. For Cities: Skylines II it does not; here it is
   unmeasured, and the installer's words do not depend on it (the shared-installer plan, 2.1).
7. Whether `steam://install/3215050` is needed. The header of the launcher calls it "the route
   (unmeasured)" for a Mac with no copy of the game (`launch-relaunched.sh:35`). For Cities: Skylines II
   the player's own click on Install worked (the installer plan's NL1); this plan uses the click.
8. Found at ML2, not known: where the game keeps a mod's on-or-off state (the account file is inferred
   from its size), and whether the mod manager turns a mod on again by itself or only on a click. At ML3 the game started
   with the mod loaded.

## 2. Design

### 2.1 The parts

| File | New or changed | What it is |
|---|---|---|
| `common/install-core.sh`, `common/make-wrapper.sh`, `common/fetch.sh`, and Cities: Skylines II's installer reduced to its settings | the shared-installer plan's, built | the shared installer this game's installer is written on |
| `surviving-mars-relaunched/scripts/install.sh` | new | the same shape with seven stages |
| `surviving-mars-relaunched/scripts/setup.sh` | new | `--mac-only`; puts the launcher and the helper where the app can keep them; builds the app and 14unch3r |
| `surviving-mars-relaunched/tools/fetch-d3dmetal.sh` | new | fetches the pinned archive, takes the six pieces out, checks them |
| `surviving-mars-relaunched/tools/make-engine.sh` | changed | a `CX_GPTK` that is given is the only place looked in; an interrupted swap is finished; a swap is guarded against a second run; root is refused |
| `surviving-mars-relaunched/tools/frame-fix.exe`, `frame-fix.build`, the runtime's licence text | new in the repository | the built helper, its build record, and the licence of what is linked into it (MD3) |
| `surviving-mars-relaunched/INSTALL.md` | new | the guide: the quick way, what is downloaded and from whom, Apple's terms, uninstall |
| `surviving-mars-relaunched/launch-relaunched.sh`, `make-app.sh`, `README.md` | changed | words that assume a checkout, CrossOver or another game's wrappers (2.7) |

`tools/split-wrapper.sh` stays as it is: it is how the two existing Macs got their wrapper, and it is not
part of an install from nothing.

### 2.2 The shared installer, and what this game gives it

The design of `common/install-core.sh`, its rules, and the table of the settings each game gives are in
the shared-installer plan (its 2.1); the Surviving Mars column of that table is this game's settings. That
plan is built (M1). This game's own are its seven stages (2.4), its `game_running` and its Wine
environment, copied from its launcher and held identical by test (MT3), its engine pin (1.3), and its
`setup.sh` (2.5). The installer holds the lock from after stage 3 to the end, stage 7 included
(`core_lock`; the core's exit trap releases it). What is
published for this game carries its Steam app ID, 3215050, and not its folder's name (that plan's 2.2).

Four things the core as built asks of this game's file (pass 3; lines of `common/install-core.sh`):

- **The Wine environment.** `game_env` sets `ENGINE="$SS/wine"`, then the launcher's lines `:77-84` word
  for word, then `WINE` as the launcher's `:85`: the launcher's lines read `$ENGINE` and set no
  `WINE`, and the core starts Steam with `"$WINE"` (`:145`, `:317`, `:402`). The installer does not read
  `SM_ENGINE`: it installs into the wrapper's own Wine, and the core's `wineserver` is the wrapper's
  (`:127`).
- **The caller's `SM_WRAPPER`.** The core exports that variable itself once a wrapper is chosen (`:140`).
  So the game's file records, before `core_begin`, whether the caller gave one, and the wrapper's path as
  the launcher would spell it (the caller's `SM_WRAPPER`, else the default). The first decides 2.4's stop
  before stage 7. The second is for `game_running`, which is the launcher's function word for word (MT3)
  and reads `GAME`: `game_env` sets `GAME` from that spelling and not from the core's resolved `$APP`
  (`:209`), since a game started by the app shows the path its launcher was given.
- **The exit trap is the core's** (`:61-75`). A second `trap ... EXIT` in the game's file would replace
  it, and with it the closing line and the release of the lock. The core gains one line, the last of its
  `on_exit`, after the lock is released and the closing line printed:
  `declare -F game_cleanup > /dev/null && game_cleanup`. A game's `game_cleanup` prints nothing, never
  calls `exit`, sets neither `rc` nor `END`, and is safe when its stage never ran: it runs at every exit,
  those before stage 4 included, and after a signal. This game's removes stage 4's temporary folder, and
  is the only place that does. With no `game_cleanup` defined the core behaves as before (measured at
  pass 3b: exit code and closing line unchanged; after a signal the hook runs and the code stays 143).
  It is a change to the shared core, so Cities: Skylines II's `test-install.sh`, with its recorded
  transcript, and `common/test-launch-lock.sh` are run with it; the core's header (`:10-14`) and the
  shared-installer plan's as-built header each gain a line for the optional function.
- **`die` is the lock code's and exits 3** (`:60`). This game's stages do not use it for a failure, which
  exits 1.

### 2.3 `tools/fetch-d3dmetal.sh`

`bash tools/fetch-d3dmetal.sh --into <folder>` leaves `<folder>/lib/external/` and
`<folder>/lib/wine/x86_64-windows/` holding the six pieces, and nothing else in `<folder>`. `<folder>/lib`
is the value `make-engine.sh` takes as `CX_GPTK`; the script's last line prints it, and a caller that
chose the folder does not need to read it. It exits 0 when done, 1 when it refused or failed (with
nothing left behind), and 2 for a wrong option.

1. It refuses to run as root. The folder must be an absolute path that does not exist, in a folder that
   does; the script makes it, and only after that arms the cleanup that removes it on any failure. A
   folder that exists is refused and left as it was.
2. The archive is fetched with `common/fetch.sh` against the size and sha256 of 1.3, into a work folder
   inside `<folder>`. A file that is no longer published, or not the pinned one, stops with the words
   `make-wrapper.sh` uses for its two files.
3. Its listing is read first (`tar -tf`). Any name that is absolute, or has `..` as one of its parts,
   stops the script.
4. Only the members under `Game Porting Toolkit.app/Contents/Resources/wine/lib/external/` and the four
   DLLs are taken out, into the work folder, with `--no-mac-metadata --no-same-owner
   --no-same-permissions`. Nothing else in the archive touches the disk, and nothing from it is run.
5. What was taken out must be exactly the 15 files and 3 links of 1.4, the links with those three
   targets. Anything more, anything missing, or a link with another target stops the script. The files,
   under `lib/`: `external/libd3dshared.dylib`; `atidxx64.dll`, `d3d11.dll`, `d3d12.dll` and `dxgi.dll`
   under `wine/x86_64-windows/`; and under `external/D3DMetal.framework/Versions/A/`: `D3DMetal`,
   `_CodeSignature/CodeResources`, and in `Resources/` `Info.plist`, `LICENSE`, `default.metallib`,
   `libdxccontainer.dylib`, `libdxcompiler.dylib`, `libdxilconv.dylib`, `libmetalirconverter.dylib` and
   `version.plist`. The links, in the framework: `D3DMetal` to `Versions/Current/D3DMetal`, `Resources`
   to `Versions/Current/Resources`, and `Versions/Current` to `A`.
6. Checks, each stopping the script: the framework's version reads 3.0; the framework's root passes
   `codesign --verify --strict -R '=identifier "com.apple.D3DMetal" and anchor apple'`; the library passes
   the same with `com.apple.libd3dshared`; each of the four DLLs has the sha256 of 1.4, written in the
   script one to a line as `NAME=value`, like the archive's own pin, so that MT4 can run a copy of the
   script against its small archives with the values rewritten (as `common/test-make-wrapper.sh:113`
   does).
7. `lib` is moved into `<folder>` and the work folder, with the archive in it, is removed.

**What rests on what.** The pin of step 2 already fixes every byte of the archive. The signature shows
more than the pin can: that the framework and the library are Apple's own builds, whoever published the
archive. It does not cover the four DLLs, which are unsigned: they rest on their sha256 and on 1.4's
comparison with CrossOver 26.2's copies. And it does not notice an added file, which is what step 5 is
for.

### 2.4 The installer for Surviving Mars

Seven stages, each skipped when done:

1. **This Mac.** Apple Silicon and macOS 14 or later are required, since the framework will not load
   below 14.0; Rosetta 2 is offered as today; a macOS other than the tested one gets the caution Cities:
   Skylines II's setup gives.
2. **Apple's Command Line Tools.** Stage 4 needs them (`nm`, `make-engine.sh:63`), and so do the app's
   icon and progress window (`make-app.sh:24`, `:115-121`).
3. **Wine.** `common/make-wrapper.sh` with this game's engine, into `SurvivingMars.app`.
   **Before anything of Apple's is fetched, the installer asks (MD9).** Both this stage's engine and the
   next stage's archive hold Apple's D3DMetal. It says that Wine for this game comes with Apple's
   D3DMetal, part of Apple's Game Porting Toolkit; that version 2.1 comes inside Porting Kit's Wine and
   version 3.0 from Gcenx's release page, neither from Apple directly; where Apple's licence is linked
   (that release page, `https://github.com/Gcenx/game-porting-toolkit/releases/tag/Game-Porting-Toolkit-3.0-3`);
   and what it allows in one sentence (1.5). To go on the player types `y`; anything else stops with exit
   3. `--yes` answers it, with nobody to ask it stops, and `--check` only says it would ask. It is asked
   once, and not at all when both stages are done. It is printed above the heading "Step 3 of 7": the
   core's Wine stage prints its heading and makes the wrapper in one function
   (`common/install-core.sh:280-291`).
4. **Apple's D3DMetal 3.0.**
   - Skipped when the wrapper's framework reads 3 or later, by the launcher's own expression and pattern
     (`launch-relaunched.sh:139-142`), held identical by test.
   - It runs with the lock held. It waits up to 10 s for nothing of Wine to hold the wrapper, by
     `make-engine.sh`'s own test (`:38-40`); if Steam is open in it (the core's `steam_proc_up`), it says
     so and stops with exit 3.
   - `fetch-d3dmetal.sh --into <temporary>/pieces`, the temporary folder made with `mktemp -d` and removed
     at exit by `game_cleanup` (2.2). The fetch script's lines are shown as they come, its last one
     included, so that the download keeps its progress bar (`common/fetch.sh:16`). Then `make-engine.sh --install <wrapper>` with `CX_GPTK` at
     `<temporary>/pieces/lib`, never empty, and with `--rebuild` when the wrapper already holds
     `wine.d3dm21-BAK`. Its `source Wine :` and `D3DMetal    :` lines (`make-engine.sh:77-78` before M2) are shown, the
     home folder as `~`; the rest of its output is kept in a file in the temporary folder and shown only
     if it fails.
   - Afterwards the framework must read 3 or later, and the library and the four DLLs in the wrapper must
     equal the fetched ones byte for byte. The temporary folder goes at exit, by `game_cleanup` and
     nowhere else. (The 239 MB archive went earlier, at the fetch script's last step.)
5. **Steam for Windows.** The core's, started with this game's environment.
6. **The game.** The core's, with this game's words.
7. **The game's app.** `scripts/setup.sh`.

**With `SM_WRAPPER` given by the caller, the installer stops before stage 7**, as `--no-setup` does, and
says why: the app
starts the default wrapper (its program passes no `SM_WRAPPER`, `make-app.sh:99`, and the launcher then
takes its default, `launch-relaunched.sh:71`), so an install into another one is a test, and gets no app.
"Given by the caller" is what the game's file recorded before `core_begin` (2.2), not whether the variable
is set afterwards. It exits 0 without the core's closing line, which would say to start the game from
Applications.

**Stopped part way through the swap.** `make-engine.sh --install` builds the new Wine as a clone beside
the old one, then moves the old one aside as `wine.d3dm21-BAK` and the new one in (`:99-100`). Three
states can be left:

- stopped while cloning: a folder `wine.new.tmp.<number>` is left. `make-engine.sh` removes any at its
  start.
- stopped after the new Wine was finished: a finished `wine.new` and the BAK, with `wine/` gone (the
  first swap, between the two moves), half removed (a rebuild, which removes the old `wine/` at `:99`) or
  still whole (a rebuild stopped just before `:99`). `make-engine.sh --install` finishes it at its start:
  after its test that nothing of Wine uses the wrapper (`:38-40`) and before its test that the wrapper
  has a `wine/` (`:35`, which moves below), it removes what is left of `wine/` and moves `wine.new` to
  `wine`. Without `--rebuild` it then prints a `finished    :` line and exits 0; with `--rebuild` it goes
  on and rebuilds from the BAK. It is safe in every case: `wine.new` gets its name only when it is whole
  (`:97`). A `wine.new` with no BAK is a first swap stopped before its first move; nothing is finished,
  and the next run replaces it.

  **A second run at the same moment.** The finish removes a `wine/` and moves another in, so two runs
  of `make-engine.sh --install` on one wrapper must not overlap: the second could remove the Wine the
  first has just moved in. After its test for a Wine process, the script takes a guard of its own, a
  link `Contents/SharedSupport/.engine-swap` that holds its process number, made with `ln -s` (which
  fails when the link exists), and removes it at its exit. A guard that names a live process stops a
  second run with exit 1 and nothing changed; one left by a process that is gone is replaced. It guards
  every swap, the installer's and one run by hand.

  **In the installer.** The core judges the wrapper inside `core_begin`, straight after it calls
  `game_wrapper` (`common/install-core.sh:207-214`), before its tests of the lock and of a running game
  (`:216-224`), and under `--check` as well. A wrapper whose `wine/bin/wine64` or `wine/bin/wineserver`
  is not there to run (the core's test, `:210`) would be called incomplete, with the words "Move it to
  the Trash" (`:212`), which is wrong for a wrapper that may hold a game. So this game's `game_wrapper`,
  whenever a finished `wine.new` and the BAK are there, whatever is left of `wine/`, does one of three
  things:
  - When the wrapper's lock names a live process other than this one, which may be the install that is
    making the swap, it stops with the core's own words for that ("Another launch or install is using
    this wrapper") and exit 3. It reads the link `Contents/SharedSupport/prefix/.launcher.lock` itself:
    `LOCK` and `WINEPREFIX` are not set at that point (`:206`).
  - Under `--check` it says that an engine swap was stopped part way and that the installer would finish
    it, and changes nothing. If the wrapper's Wine fails the core's test it then exits 0, before the core
    can call the wrapper incomplete; if it passes, the report goes on.
  - Otherwise it finishes the swap with `make-engine.sh --install <wrapper>`, with no `--rebuild` and no
    `CX_GPTK`: it fetches nothing and needs no source. The wrapper then reads 3, stage 4 is skipped, and
    the question of MD9 is not asked on its account. If `make-engine.sh` refuses, because something of
    Wine uses the wrapper or another run holds its guard, its line is shown and the installer stops with
    exit 3; it never goes on to the core's test with the swap unfinished. The installer's lock is not
    held here, since the core takes it later; the script's own two tests are what make the finish safe.
- a BAK, and a `wine/` that does not read 3: stage 4 passes `--rebuild`.

`make-engine.sh` itself changes in four ways: when `CX_GPTK` is set, that folder is the only place looked
in, and one that does not hold the framework, or a `CX_GPTK` that is set and empty, stops it with exit 1;
an interrupted swap is finished as above; a swap is guarded against a second run; and it refuses to run
as root. Its way of finding CrossOver when `CX_GPTK` is not set stays, for
the existing Macs and for ML4b's way back.

### 2.5 `surviving-mars-relaunched/scripts/setup.sh`

- `--mac-only`, with `--yes` and `--check` as the core passes them: the checks of stage 1. It exits 0
  when the Mac is ready, 1 when only Rosetta is missing, and 3 with its own words on an Intel Mac or a
  macOS below 14. A caution is printed and, with a terminal and without `--yes`, asked about once, as
  Cities: Skylines II's setup does.
- Otherwise: it copies `launch-relaunched.sh` and `tools/frame-fix.exe` into the game's state folder,
  `~/Library/Application Support/1launcher/surviving-mars-relaunched/` (`SM_STATE`, where `runs/` and
  `backup/` already are), keeping the `tools/` level so the launcher finds the helper where it looks
  (`launch-relaunched.sh:74`); builds the app with `make-app.sh` told to run that copy (`SM_SCRIPT`,
  `make-app.sh:22`); and builds `14unch3r.app` with `common/make-launcher-app.sh`, beside the game's app:
  in `~/Applications`, or with `--dest` at the folder of `SM_APP` when that is set, so that a test builds
  nothing in the real place.
- **A copy is never written over a file in place.** Each is written beside the old one under another name
  and then renamed over it, because a launcher goes on reading its own file after the game exits
  (`launch-relaunched.sh:379-415`). And setup refuses, with exit 3, while the game runs, or while the
  wrapper's lock names a live process other than the installer that started it.
- **Run by the installer** (`SM_VIA_INSTALLER=1`): the installer holds the lock through stage 7 (2.2), so
  a lock that names setup's own parent process is passed; without the variable, or with any other live
  holder, it is refused. The Mac caution's question is not asked again, since stage 1 asked it, and the
  lines that say how to update speak of the installer, as Cities: Skylines II's setup does.
- It refuses a state folder that is not the user's own, or that others can write to. It never touches
  `runs/` or `backup/`. A copy that is already there is replaced by the current one. It prints the home
  folder as `~`. It refuses to run as root.
- It does this on every Mac, a maintainer's included (MD4): one way of running, which is the one a
  stranger gets. After `git pull`, a maintainer runs setup again, as for Cities: Skylines II.
- No Desktop shortcut is offered by this setup. The one alias the repository allows on the Desktop is
  14unch3r's, and Cities: Skylines II's setup makes it.

No new place outside the repository: the state folder is already in the root `CLAUDE.md`'s list.

### 2.6 `tools/frame-fix.exe` in the repository

The helper is built once with `-s -Wl,--no-insert-timestamp` and committed (17,920 bytes), with a line
added to `.gitignore` to let that one file through; `tools/game-input.exe`, a testing tool, stays out. The
build line in the header of `frame-fix.c` gains the two flags. `tools/frame-fix.build` records that build
line, the version lines of the compiler and the linker, what `brew list --versions mingw-w64` says, and
the sha256 of `frame-fix.c` and of the program. MT7 holds the file to its source.

The program has parts of the mingw-w64 runtime and of the compiler's support library linked into it. The
runtime's licence text is committed beside it, as `patches/_vendor/` keeps the licences of what it holds,
and the README names it. The terms of the compiler's support library are read at M4, before the commit;
if they cannot be met this way, MD3 goes back to James.

The launcher's line for a missing helper (`:377`) loses "is not built (see its header)": the file is now
part of the install, and its absence is a damaged install. `common/test-launcher-parity.sh` records that
line among the launcher's notes (`:176-177`); its list changes with the line (M5).

### 2.7 The documents

- `surviving-mars-relaunched/INSTALL.md`: the quick way (the app or the pasted line, as in the Cities:
  Skylines II guide, with that guide's pictures of macOS's messages reused by link); what the installer
  downloads and from whom, in a table like 1.3. On Apple's licence, in plain words and with the address
  of 2.4: that using the toolkit is allowed for developing, testing or evaluating games on a Mac and that
  the text does not name playing; that it may be passed on only non-commercially; that it ends on any
  breach, and that the user answers to Apple for their own use of it; and that this project passes on
  nothing of Apple's. The one Steam at a time rule, and that the installer can check it only on this Mac.
  Uninstall: the wrapper; the app; in the state folder the launcher's copy and `tools/`, with a warning
  that `backup/` holds copies of saves and `runs/` logs; `~/Library/Logs/sm-relaunched-launcher.log`;
  14unch3r and its preferences file only when no other game here uses them; and any folder given as
  `L1_DOWNLOADS`.
- `surviving-mars-relaunched/README.md`: "What it assumes" loses what needs another game's wrappers and
  Steam app, CrossOver and `mingw-w64` (`:44-63`), and its first line says macOS 14 where it says 14.6
  (`:41-42`); Setup leads with the installer; `split-wrapper.sh` is
  described as the way the first two Macs were set up. `:69-71` says that this project does not pass on
  Apple's or CodeWeavers' files, and names the helper as the one program in the repository, with its
  runtime's licence.
- `launch-relaunched.sh`: the lines that name a file of the checkout or the script's own header say what
  to do from an install instead, and give the checkout's line second where there is one: `:136`
  (`split-wrapper.sh`), `:143` (the refusal below 3: open the installer again), `:145`, `:269` and `:397`
  ("see the header", "the top of launch-relaunched.sh"), `:377`. Its header's "On another Mac" paragraph
  (`:31-35`) is replaced by a pointer to the guide.
- `make-app.sh`: `:10-11`, `:68`, `:119` and `:184` name the checkout's own files; each says to open the
  installer again, or to run setup from a checkout.
- `tools/make-engine.sh`: its header (`:5-6`, `:25`) and its line for no source (`:74`) name the
  installer's fetched pieces as the usual source and CrossOver as the other.
- For MD10: done by the shared-installer build (`cities-skylines-2/INSTALL.md:45`, and the header of that
  game's installer at `cities-skylines-2/scripts/install.sh:14-15`).
- `common/games.tsv`: the guide address of Surviving Mars becomes its `INSTALL.md`.
- For the moved script: done by the shared-installer build (`cities-skylines-2/scripts/README.md:31`,
  `cities-skylines-2/GOTCHAS.md:3055`, and the installer plan's as-built header).
- `docs/plans/1launcher-unification.md`: the O3 row gains a dated line that this game's app runs a copy in
  the state folder (MD4). `docs/plans/local-files-layout.md`: one pointer line.
- The root `README.md` and `CLAUDE.md`: Surviving Mars has an installer; the root `README.md`'s row for
  the game no longer says "taken from a local CrossOver 26 install" (`:22`), and its "macOS before 14.6"
  for this game becomes 14 (`:61`); and where `CLAUDE.md` lists what the game's state folder holds
  (`backup/` and `runs/`), it gains the launcher's copy and the helper. (`CLAUDE.md`'s row for `common/`
  already names the three shared files.)
- `cities-skylines-2/GOTCHAS.md` is not the place for this game's findings; they go in the README's
  "Findings" list, with their measurements.

### 2.8 What this plan leaves alone, and what it cannot test

- 14unch3r's "Not set up" tile keeps opening the guide. Having it start the installer is a later slice
  (MD8).
- `steam://install/<id>` is not used (1.7, item 7).
- Cities: Skylines II's installer is not changed by this plan; the shared-installer plan changes it.
- **No way to sign in again.** When the saved sign-in lapses, the launcher says to open Steam in the
  wrapper and sign in (`launch-relaunched.sh:249`), and nothing opens that Steam: the installer skips
  Steam once the game is installed. This is so today for both games and is not changed here.
- macOS 28 and Macs without Rosetta: no route for this game (cs2 #21), and none is made here.
- A second source for D3DMetal. If Gcenx's file goes, stage 4 stops with the "no longer published" words
  until a new pin is committed. A lost pin is never mended by this project publishing the file itself
  (1.5, 2C); MD1 covers asking him. If Porting Kit or Gcenx publishes a Wine 10 engine with D3DMetal 3.0
  built in, which MD1's notes also ask, stage 4 and the fetch script are not needed for a new install, and
  a later slice takes them out; until then the swap is the way.
- Nothing watches the pins. Porting Kit's release can replace a file in place (1.3), which stops stage 3
  with the "not the file this was tested with" words. A scheduled check is a follow-up, as in the
  installer plan (its 2.9).
- Stages 1 and 2 are tested with stubs only, as in the installer plan (its 2.9).

## 3. Steps

- **M0. The probes that decide the design, before any code** (ML1, then ML2 and ML3, which can share one sitting: ML3 replaces nothing in the wrapper).
  ML1 is done (1.4): the pin stands, and the design is unchanged by it. ML2 is done (1.4, 2026-11-13): a
  wrapper from nothing runs the game, so the design stands; what it found besides is in section 5a. ML3
  is done (1.4, 2026-11-13): the game runs on the engine made from the public pieces, in the real wrapper.
  All three probes are done, and none changed the design.
  If the published Wine is not the wrapper's Wine, or a wrapper from nothing does not run the game, the
  difference is written into this plan as a step and the plan is checked again. Beside them, if James
  wants it: Apple's own download of the toolkit, which needs his Apple Account, read for its licence and
  for where the five pieces outside the framework sit (1.5).
- **M1. The shared installer.** It is the shared-installer plan (`docs/plans/shared-installer.md`), built
  on its own on 2026-11-11: it needed none of this plan's probes.
- **M2. `tools/make-engine.sh`: the four changes of 2.4.** MT8.
- **M3. `tools/fetch-d3dmetal.sh`.** MT4.
- **M4. `tools/frame-fix.exe` committed, with `frame-fix.build` and the licence text.** MT7.
- **M5. `surviving-mars-relaunched/scripts/setup.sh`, and `make-app.sh`'s and the launcher's words**, with
  the parity test's list (2.6). MT6, MT8.
- **M6. `surviving-mars-relaunched/scripts/install.sh`, and the one line in the core (2.2).** MT3.
- **M7. The documents of 2.7**, and the installer app's test for this game (MT9).
- **M8. The live steps ML4 to ML6, then the as-built header.**

The work is done on the branch `surviving-mars-install`, cut on 2026-11-13 from `simple-install` at
`4d339dd`, where the shared-installer plan is built and `main`, which holds this plan, is merged in (no
branch of this repository is rebased once pushed).

## 4. Test plan

Every test runs with `HOME` at a scratch folder and every outside program a recording stub, as
`cities-skylines-2/scripts/test-install.sh` does, except where a row says the real program is run. Each
mutant is applied to the real source, seen red, and removed; a mutant whose line is gone refuses with
exit 2.

| # | Test | What it shows | Mutants, each must turn it red |
|---|---|---|---|
| MT1 | Moved to the shared-installer plan as its ST1 | the recorded transcript of Cities: Skylines II's installer | there |
| MT2 | Moved to the shared-installer plan as its ST2 | Cities: Skylines II's installer on the core, and another wrapper's Steam (MD10) | there |
| MT3 | `surviving-mars-relaunched/scripts/test-install.sh`, with its own fixture maker (a wrapper whose framework reads 2.1, 3.0 or is absent) and stubs for the fetch and engine scripts that write to the one record of calls | seven stages, each skipped when done; the question of MD9: declined, or with nobody to ask, nothing is fetched and it exits 3, `--yes` answers it, `--check` only says, and it is not asked when stages 3 and 4 are done; stage 2 before stage 4 and stage 4 before Steam's installer, by the order of the record; stage 4 skipped at 3.0, run at 2.1 and with no framework, with `--rebuild` when a BAK exists, with the lock held, and with the temporary folder gone afterwards; a wrapper whose pieces differ from the fetched ones after the swap stops it; a half-finished swap is finished and not called incomplete; Steam open in the wrapper stops stage 4 with exit 3; the game found by `Project Spark/Mars.exe` and manifest `3215050` at `StateFlags` 4; with `SM_WRAPPER` given by the caller it stops before stage 7, with exit 0 and without the core's closing line; a relative `SM_WRAPPER` exits 2 by that name; `--desktop` exits 2; the installer's own files gone exits 4; `--check` with no wrapper names stages 4 to 7 and changes nothing; no line holds a word of the other game; this game's `game_running` and engine pin; its exports equal the launcher's lines `:77-84` and its `WINE` the launcher's `:85`, both at the wrapper's own Wine with `SM_ENGINE` set by the caller and not followed, and its version expression and pattern equal `:139-142`; `SM_VIA_INSTALLER=1` reaches setup; the two lines of `make-engine.sh` that are shown name the temporary folder; a `--mac-only` that exits 3 stops the install, setup's words above the core's; after a failure in stage 4 the closing line is the core's "The install stopped", the lock is released and the temporary folder is gone; with no `SM_WRAPPER` given, setup is run although the core has exported the variable; a wrapper with a finished `wine.new` and the BAK, its `wine/` gone, without `wineserver`, or whole, is finished by one call of the engine script with no `--rebuild` and no `CX_GPTK`, nothing is fetched, the question is not asked and stage 4 is skipped; under `--check` it is only reported and nothing changes, with exit 0 at once when its Wine is gone and the report going on when its Wine is whole; with a live holder of its lock it stops with exit 3, is not called incomplete, and the swap is left as it was, `wine.new` still there and no call of the engine script in the record; when the engine script refuses the finish the installer stops with exit 3 under that script's line; `GAME` is spelled as the launcher would spell it, in a scratch home whose path resolves to another, and `game_running` equals the launcher's `:149-156`; Cities: Skylines II's `test-install.sh` passes with the core's new line | stage 4 skipped at 2.1; stage 4 after Steam; the comparison after the swap removed; the question removed; the question asked again when done; the lock taken after stage 4; the half-finished swap left; the manifest of the other game accepted; `--check` fetching; setup run with the game absent; setup run with `SM_WRAPPER` set; `WINEMSYNC` dropped from the exports; the pattern made `3.0`; `SM_VIA_INSTALLER` not passed; `--rebuild` never passed; the wait for Wine to let go removed; `game_cleanup`'s removal taken out; `game_cleanup` not called by the core; a `trap ... EXIT` in the game's file; `SM_WRAPPER` read after `core_begin`; `WINE` left out of `game_env`; `ENGINE` taken from `SM_ENGINE`; `GAME` taken from the resolved path; the swap finished under `--check`; the lock's holder not looked at before the finish; the finish made only when `wine64` is gone; a refused finish passed on to the core's test |
| MT4 | `surviving-mars-relaunched/tools/test-fetch-d3dmetal.sh`, with small archives the test makes (Python's `tarfile` for a name with `..`, which macOS's `tar` will not write) | the six pieces land and the last line is the folder; each of these stops it with nothing left: a wrong sha256 at the right size, a wrong size, a piece missing, an extra file among the pieces, a link among the pieces with another target, a framework reading 2.1, a DLL with another sha256, and a name that is absolute or has a `..` part placed outside the members taken; a `..` link elsewhere in the archive is accepted, as the real one has 29; a folder that exists is refused and keeps its files; a matching copy in `L1_DOWNLOADS` is used and a non-matching one is not; curl's 22 gives the "no longer published" words; nothing from the archive is run; the exit codes 0, 1 and 2. The test runs a copy of the script with the pins rewritten for its archives. **The signature, with the real `codesign`:** a look-alike framework the test builds and signs itself, with Apple's identifier and version 3.0, must be refused; the stub records that the script's two `codesign` lines carry `--verify --strict`, the two requirements, and as their paths the framework's root and the library; and where a real framework is on the Mac (the probe's, or a wrapper's) the script's own lines must pass on it, else the test prints SKIP for that case | the sha256 test removed; the version test removed; `-R` dropped from a `codesign` line; the check pointed at `Versions/A`; the fixed list removed; a DLL's sha256 test removed; the `..` test removed; the whole archive unpacked; the cleanup armed before the folder is made |
| MT5 | Moved to the shared-installer plan as its ST3 | the wrapper script with the engine as options | there |
| MT6 | `surviving-mars-relaunched/scripts/test-setup.sh` | the launcher and the helper are in the scratch state folder; the app's program names that copy and not the checkout; an older copy there is replaced; `runs/` and `backup/` are untouched, files in them included; a held lock, or the game running, refuses with exit 3 and copies nothing; a state folder others can write to is refused; `--mac-only` gives 0, 1 without Rosetta, 3 on Intel and below macOS 14, takes `--yes` and `--check`, and copies nothing; from a temporary copy the app still names the state folder; the 14unch3r builder is called, and with `SM_APP` set it builds in that app's folder and nothing in the real one; run by the installer (`SM_VIA_INSTALLER=1`, its parent holding the lock) it goes on, and the same lock without the variable, or held by another live process, exits 3 | the app pointed at the checkout; the helper not copied; copied only when absent; written in place; a file in `runs/` removed; the lock test removed; the parent's lock refused; any live holder passed; 14unch3r built in the real folder with `SM_APP` set; the test of who may write to the state folder removed; the running-game test removed; `--mac-only` going on to copy |
| MT7 | `surviving-mars-relaunched/tools/test-frame-fix-build.sh` | everywhere: `frame-fix.c` and the program have the sha256 values in `frame-fix.build`, and the program holds no `/Users/`, `/private/tmp` or `/opt/homebrew` string; where `brew list --versions mingw-w64` equals the record, the header's own build line gives a byte-identical file; elsewhere it prints SKIP for the rebuild, with the reason, and does not call it a pass | one byte of the program changed; one byte of `frame-fix.c` changed; `-s` dropped from the build line (red only where the rebuild runs) |
| MT8 | `tools/test-make-engine-install.sh` and `tools/test-engine-source.sh`, with cases added; and a source gate on the launcher and `make-app.sh` | `CX_GPTK` set to a folder without the framework, or set and empty, stops with exit 1 even with a CrossOver planted in the scratch home; a half-finished swap is finished, with `wine/` gone, half removed or whole, and then exits 0 with the `finished` line, or with `--rebuild` rebuilds from the BAK; a wrapper in use is refused before the finish and keeps its `wine.new`; a guard that names a live process refuses a second run with exit 1 and nothing changed, and one that names a dead process is replaced; no guard is left after a run; stale clone folders are removed; root is refused. `test-make-engine-install.sh` takes its D3DMetal pieces from `CX_GPTK` when that is given and otherwise from the `wine/lib` of the installed `SurvivingMars.app` when its framework reads 3.0, which then has that folder's shape; it passes the folder to the script as `CX_GPTK`, and compares what was installed with that folder, not with the fetch script's pins (on the Studio the wrapper's DLLs are CrossOver's until ML4b). With neither, a wrapper that reads 2.1 included, it refuses with exit 2, as it does with no Wine to clone (`:16`). Before this it needed a CrossOver on the Mac: without one, 8 of its 14 cases fail. The source gate, which is a grep and is named as one: the lines of 2.7 no longer name a file of the checkout or the header | the fall-through to CrossOver put back; the finishing move removed; the finishing move placed before the test for a Wine process; the finish falling through to the refusal for an installed engine; the guard removed; a dead process's guard obeyed; an empty `CX_GPTK` taken as not set; stale clone folders left; the root refusal removed; one old line put back |
| MT9 | `common/test-launch-lock.sh` with the core as its third file, `common/test-bootstrap.sh` with a case for this game, `common/test-make-installer-app.sh` with a case for this game, `common/test-launcher-parity.sh`, and the eight `tools/test-*.sh` | the lock code is identical in the core and both launchers (the core is already the test's third file, and this game's installer holds no lock code); the bootstrap hands over to either game, with a fixture of its own for this game's case (the test's present use of 3215050 as an ID with no installer, `:54`, `:129-131`, `:165`, is a fixture folder and stays); the app is "Install Surviving Mars Relaunched", and its guide's pasted line carries 3215050, in a case that names this game's own guide and ZIP (`common/test-make-installer-app.sh:37-38`, `:158` and `:163` hold Cities: Skylines II's); the parity test passes with the launcher's reworded note in its list (2.6); nothing else moved | the lock test's own mutant |
| MT10 | The gates: `common/check-links.py`, `common/check-identifiers.sh` at its residual of 9, `cities-skylines-2/scripts/check-experiments.py`, `bash -n` on every script | no dead link, no identifier, the ledger whole | none: they are gates |

The uninstall the guide describes is prose and has no test; ML6 follows it by hand at its end.

## 5. Live steps, each on James's word

For every step that starts Steam or the game: no Steam is using the account anywhere, on either Mac, the
Steam of macOS included; and the game's last exit upload was ok.

- **ML1. The published Wine. Done 2026-11-11; the result is in 1.4.** The second row of 1.3 is downloaded (184 MB), checked against its digest,
  unpacked beside the probe's folder, and compared with `SurvivingMars.app`'s `wine.d3dm21-BAK` by
  `diff -rq`. Recorded: the archive's top folder, and identical or every file that differs. Then the
  archive without D3DMetal (1.3; 166 MB), compared the same way: if it is that Wine less D3DMetal, it can
  be the pin, and stage 3 then fetches nothing of Apple's.
- **ML2. A wrapper from nothing, by hand, on the Studio.** *Done 2026-11-13; the record is in 1.4. It
  departed from the steps below in four ways: no changed copy of `make-wrapper.sh` was needed (the branch's
  takes the engine as options); step 3 took two starts of Steam, a day apart, because of the VPN route;
  step 6 was done twice, the second time after the mod's folder and the real wrapper's `LocalStorage.lua`
  were copied into the new prefix (the folder turned out to be unneeded: the game had fetched it); and in
  step 9 James played and saved in the real wrapper.*
  1. Before: the real wrapper's `Saved Games/Surviving Mars Relaunched/<its account folder>/` and
     `userdata/<its account folder>/3215050/` are copied into the state folder's `backup/`.
  2. A copy of `make-wrapper.sh` with the three pin lines changed, kept with the run, makes
     `~/Applications/SMfresh.app`. `make-engine.sh --install` with the probe's pieces; what the first Wine
     start after it does is recorded. Steam's installer. The helper, built stripped, is put beside a copy
     of the launcher in a scratch folder whose path holds a space.
  3. Steam is started with the launcher's own environment (`launch-relaunched.sh:77-84`); what its first
     start does is recorded. James signs in, with "Remember me" ticked: step 6's launcher starts Steam
     with no window and waits for it to sign in by itself (`launch-relaunched.sh:242-249`).
  4. The game's folder and then its manifest are cloned from `SurvivingMars.app` with `cp -Rc` (no
     download, almost no disk).
  5. **Steam is closed with `-shutdown`, and the step waits until nothing holds the prefix.** Without
     this the launcher would use the Steam that signed in before the game was there, and no saves would
     be pulled (1.2).
  6. `SM_WRAPPER=~/Applications/SMfresh.app bash <the scratch copy of the launcher>`. A visible game
     start: James is told before it. **The launcher must print "Steam Cloud: saves up to date."** With
     any other cloud line James quits at the menu and loads nothing.
  7. At the menu James loads the save with a landscaping project and looks at the map; then quits.
     Recorded: the menu reached; the map; the helper's log showing it watching; the cloud upload at exit;
     the sizes of the wrapper and of Steam in it.
  8. Recorded besides: what the old prefix holds that the new one does not (the registry's override and
     uninstall keys, `system32` files that are not Wine's), and whether the new wrapper's `wine/lib` holds
     the 86 library copies of 1.4; kept with the run.
  9. After: the real wrapper's next launch prints the same cloud line, with no conflict. If there is a
     conflict, the way back is the launcher's own recipe (`launch-relaunched.sh:49-56`) and the copies of
     step 1. Then Steam is signed out in `SMfresh.app` and it goes to the Trash; that the real wrappers'
     saved sign-in still works is seen at their next start.
- **ML3. The game on the published pieces, the wrapper unchanged.** *Done 2026-11-13; the record is in
  1.4. It departed from the words below in one way: it was started from the session's shell with its
  output in a file, not from Terminal.* With nothing running, the real
  wrapper is started once with `SM_ENGINE` at the engine of 1.4
  (`~/Library/Developer/1launcher/surviving-mars-relaunched/engine/wine-d3dm30-gcenx`), which the launcher
  then uses for Steam and for the game (`launch-relaunched.sh:76`, `:90`). Nothing in the wrapper is
  replaced; its prefix is used, and whether Wine updates it at that start is recorded. It is started from
  Terminal, `SM_ENGINE=<that folder> bash surviving-mars-relaunched/launch-relaunched.sh`, not from the
  app. Recorded first, so that the step shows which engine ran: `d3d12.dll` in that engine at 114,688
  bytes, and that the running game's process is that engine's `bin/wine64`. Then: the menu; the
  landscaping save; and James plays a session. The way back is the next start without the variable. It
  can share ML2's sitting, after ML2's step 9 has been seen on the wrapper's own engine, so that the two
  changes are not in one start.
- **ML4. The installer, for real, on the Studio**, after M6. Before it starts, no other Wine runs on the
  Mac (`pgrep -lf wineserver` prints nothing: MF1) and, if Steam's update is cut, the VPN is paused (MF2);
  after it, James opens the mod manager in the real game before he loads a save (MF3). For this game: from the branch's worktree
  into a scratch wrapper named by `SM_WRAPPER` (so it stops before setup), through every stage, the game
  cloned in while it polls, as NL1 did; recorded with `make-engine.sh`'s `D3DMetal    :` line and the size of `d3d12.dll` in the
  wrapper (114,688 bytes). Then the launcher with that
  wrapper to the menu, under ML2's steps 1, 6 and 9; step 5's work is done by the installer, which closes
  Steam when it finds the game (`common/install-core.sh:401-403`). Then setup on its own
  with `SM_APP` and `SM_STATE` at scratch folders, and the scratch app started once: it starts the real
  wrapper, since the app passes no `SM_WRAPPER`, so it is a real launch on the account, under this
  section's rule, and is the "next launch" of ML2's step 9. (Cities: Skylines II's installer after the move is the shared-installer plan's SL1.)
- **ML4b. The Studio moved to the copy in the state folder (MD4).** The installer for real, with no
  `SM_WRAPPER`: every stage reports done, then stage 7 runs setup with the installer's lock held, which is
  the first time the two meet outside a test. The app then runs the state folder's launcher, and the game
  is started once from it. The way back: `make-app.sh` and `common/make-launcher-app.sh` run from a
  checkout of `main`, and the two copies removed from the state folder. Then, with the game closed and
  nothing of Wine running, so that the Studio runs what is published: the wrapper's present `wine/` is
  cloned to
  `~/Library/Developer/1launcher/surviving-mars-relaunched/engine/wine-d3dm30-crossover`, because a rebuild
  removes it (`make-engine.sh:99`), and `make-engine.sh --install ~/Applications/SurvivingMars.app
  --rebuild` is run with `CX_GPTK` at the folder `tools/fetch-d3dmetal.sh` leaves, run for this and removed
  afterwards (at ML4b every stage reports done, so the installer fetches nothing). Recorded: its
  `D3DMetal    :` line, and `d3d12.dll` in the wrapper at 114,688 bytes. Then the game is started once
  from the app to the menu, with the landscaping save. The way back is that clone moved into place, or the same
  line without `CX_GPTK` while CrossOver 26 is still installed.
- **ML5. The MacBook.** The installer on a Mac whose wrapper was made the old way: every stage reports done
  except setup, and the app runs the copy in the state folder. Then the game.
- **ML6. A Mac account with nothing in it**, with NL4 of the installer plan: the published app or pasted
  line for this game, to Steam's sign-in window; whether the game is downloaded there is James's call. At
  its end the guide's uninstall is followed, and what is left is listed.
- **ML7. After the first week:** whether the three pinned files are still published, and anything a player
  reported.

## 5a. Found at ML2 (2026-11-13): not planned in detail, not checked, not built

ML2 answered its questions (1.4, 1.7) and the design of section 2 stands. It also showed four things a
player would meet. The rows SF1, SF2 and SF8 named below are in section 9 of the shared-installer plan,
which exists on the branch `simple-install` only. Each needs its place in a step and its test, and this section needs a check before any
of it is built.

| # | What was seen | What is wanted |
|---|---|---|
| MF1 | `make-wrapper.sh` did not return while any other Wine ran on the Mac: the template's own program waits for every `wineserver` to exit. A player with another game's wrapper, a storefront Steam or CrossOver open would see "making the Wine prefix (about 30 s)" for as long as that stays open | The shared installer's, not this game's: the shared-installer plan's SF8. For this game it matters twice over, because this project's own second game or its Steam app may be the Wine that is open |
| MF2 | Steam's update was cut on the VPN route a second time, on another day and on Wine 10 with D3DMetal 3.0; paused, it worked at once. A Steam whose update failed did not close on `-shutdown` within 30 s | The shared-installer plan's SF1 and SF2 apply to this game unchanged. New: how the installer closes a Steam stuck at its update box (SF1's row there) |
| MF3 | A player who already has the game elsewhere with a Paradox mod: the first start warns that the mod could not be loaded, the game fetches it again by itself, and it stays switched off, here and, through Steam Cloud, on the player's other installs, until the mod manager is opened. A save loaded meanwhile runs without its mod | One paragraph in this game's guide and one line where the installer ends: after a new install, open the mod manager before loading a save if you use mods. Measured first: 1.7's item 8 |
| MF4 | The new prefix has none of the Visual C++ runtimes, `d3dcompiler_47` and fonts that the old one holds, and the game reached the map | Nothing is added to the installer for them on this evidence. ML4 includes a session of play in such a prefix (ML3's was in the old prefix, which holds them, so it measured nothing here); if it fails for a missing runtime, the runtime's source and licence are a decision of their own |

## 6. Exit criteria

- M0's three probes are recorded, and the design is unchanged by them or the change was checked. (ML1:
  recorded, unchanged.)
- The shared-installer plan is built and its SL1 passed. M2 to M7 are committed; MT3, MT4 and MT6 to
  MT10 pass; every listed mutant was applied and seen red, with the count
  in the as-built header.
- ML4, ML4b and ML5 passed.
- **A wrapper made by the installer from the three downloads starts the game.** That is ML4 for this
  game, and its record holds the two things that show where the engine came from: `make-engine.sh`'s
  `D3DMetal    :` line naming the fetched folder, and `d3d12.dll` in the wrapper at 114,688 bytes, the size
  of the published file and not of CrossOver's.
- `README.md`'s "What it assumes" no longer lists CrossOver, another game's wrappers or Steam app, or
  `mingw-w64`.
- The as-built header is written, with the deviations.

## 7. Rollback

- **Saves.** No step changes a file in a prefix by hand. But ML2 and ML4 start the game from a second
  prefix on James's account, which uploads to Steam Cloud what the real wrapper then pulls. ML2's steps 1,
  5, 6 and 9 are what keep that safe, and they name the way back.
- **The engine.** The swap keeps the Wine it replaced inside the wrapper. ML3 replaced nothing in the wrapper, and Wine did not update its prefix (1.4). ML4b replaces a working engine, so it clones that first and names two ways back.
- **MD4 on the two existing Macs.** ML4b names the way back for the Studio; it is the same on the
  MacBook after ML5.
- **The shared installer** has its own way back, in its plan.
- An install made by the new installer is removed by the guide's uninstall.
- Once `release` carries this, a pin that stops being published is fixed by a commit and a move of
  `release`; until then stage 3 or 4 stops with words that say so.

## 8. Decisions, each James's

**Decided 2026-11-11: MD1 to MD8, all as recommended.** Asked whether he accepted them, with MD5 named as
the one that costs time, James answered: "That's fine, no one is waiting for any of this. We're just
doing it for the sake of doing it." So nothing here is traded against a date: where a step can be done
properly or quickly, it is done properly. **MD9 and MD10 came out of the check; decided the same
evening, both as recommended** (James: "Accept both"). **After the check he took four changes ("Fold all
four"); they are listed under "After the check".**

| # | Decision | Recommendation | Decided |
|---|---|---|---|
| MD1 | Where D3DMetal 3.0 comes from | Gcenx's release page, pinned by size and sha256, fetched by the installer and never re-hosted, as for Porting Kit's two files; the guide and the installer state Apple's terms. Short notes to Gcenx and to Porting Kit, drafted for James to send or not, asking whether old releases stay published and whether a Wine 10 engine with D3DMetal 3.0 built in could be published, which would make the swap unnecessary. The one to Porting Kit rides with the note the installer plan already has drafted (its K4). The other sources are Apple's own download, which needs a signed-in Apple Account and cannot be scripted, and CrossOver | as recommended |
| MD2 | What the guide says about Apple's licence | What 1.5 says, in plain words, with the address it is linked from. No claim that it permits more | as recommended |
| MD3 | The helper in the repository | Commit `tools/frame-fix.exe`, built stripped and without a link stamp (18 KB), with its build record, its runtime's licence text and MT7. The other ways are a compiler on the player's Mac, or going without the helper | as recommended |
| MD4 | The app runs a copy in the state folder on every Mac | Yes. It replaces the unification plan's O3 (c) for this game: after `git pull`, run setup | as recommended |
| MD5 | Order against the installer plan | NL2 goes ahead once the shared-installer plan is built and its SL1 passed (SD2 there), on the app that plan's builder makes. NL3, the first public release, waits for ML4, so that what is first published installs both games and the shared files have their final addresses before anyone depends on them | as recommended |
| MD6 | Apple's Command Line Tools for this game | Asked for. The engine swap needs them, so there is no other way for this game | as recommended |
| MD7 | One shared installer, or a second script held alike by a test | One (2.2) | as recommended |
| MD8 | 14unch3r's "Not set up" tile starts the installer | A later slice, with its own plan: it changes the window app and its tests | as recommended |
| MD9 | A question before Apple's software is fetched (2.4, stage 3) | Yes, once, answered no by default, as the installer already asks before Rosetta. The licence says not to install it if one does not agree; a line of text that scrolls past is less than that. The other way is the line of text | as recommended |
| MD10 | The installer stops when another wrapper's Steam is open on this Mac (2.2) | Yes, in the core, so for both games: two Steams on one account make the first skip its cloud upload. Cities: Skylines II's installer gains it in the shared-installer plan (its 2.1 and 2.3). The other way is a sentence in the guide | as recommended |

## Review corrections (triple-check 2026-11-11)

Pass 1: four lenses. A: architecture, sequencing, rollback and live-step safety. B: security, supply chain
and outside facts. C: correctness and test plan. D: a builder, who built M1, M3 and part of M6 in a
scratch tree and ran the tests. Each said build-ready-with-fixes. Three blockers, each re-read in the code
or re-measured by the planner; all folded above.

| # | Correction | Found by | Folded into |
|---|---|---|---|
| R1 | **Blocker.** ML2 signed in before the game was in the wrapper, so the launcher would have used that Steam, pulled no saves, and started the game on an empty save folder that could then conflict with the cloud | A | 1.2, ML2 (steps 1, 5, 6, 9), ML4, section 7 |
| R2 | **Blocker.** MT4 stubbed `codesign`, so the signature check was never run by a test; and the check alone passes a framework with a file added (measured) | B | 1.4, 2.3 (steps 5, 6, "What rests on what"), MT4 |
| R3 | **Blocker.** MT1 could not be run as worded (the test copies one file; its output holds random names), and as a one-time gate it said nothing of the core that ships after M6 edits it | C, D | 1.6, 2.1, 2.2, M1, MT1 |
| R4 | The Wine environment and Steam's start line are each launcher's own and differ; the core's were Cities: Skylines II's | A, C, D | 1.2, 1.6, 2.2 (table, rules), ML2 step 3 |
| R5 | The core's list missed the places where the flow crosses stages: the `--check` report, the lock, step numbers in words, the own-files list, two variable names, the options passed to setup | A, C, D | 1.6, 2.2 (table, functions, rules), MT3 |
| R6 | Setup could write over a launcher that is still running | A, B, C | 2.5, MT6 |
| R7 | ML4 would have rebuilt the real app, the real state folder and 14unch3r from an unmerged branch, and redeployed Cities: Skylines II's files | A, C | 2.4 (`SM_WRAPPER`), ML4, ML4b |
| R8 | "A CrossOver on the Mac is not looked for" was false of `make-engine.sh`, which falls through to it; a broken hand-over would have passed on the owner's Mac | A, B, C, D | 1.1, 2.1, 2.4, MT8, ML3, ML4, exit criteria |
| R9 | The Command Line Tools are needed by the engine swap (`nm`), not only by the app's looks | B, C, D | 1.1, 2.2, 2.4 (stage 2), MD6, MT3 |
| R10 | The licence summary was loose: non-commercial limits passing on, purpose limits use; it left out the end on breach, the indemnity, the notices and "host"; the address is Gcenx's | B | 1.5, 2.7, 2.8, MD1, MD2 |
| R11 | Consent: the installer stated where Rosetta's stage asks, and one stage late, since the Wine archive already holds D3DMetal 2.1 | B | 2.4 (stage 3), MT3, MD9 |
| R12 | The signature covers the framework and the library only; the four DLLs rest on the pin; `tar -tf` shows no link targets | B | 1.4 (table), 2.3 |
| R13 | The helper as built held the compiler package's build paths and would rebuild alike on one package only; the runtime linked into it has its own licence | B | 1.4, 2.6, MD3, MT7 |
| R14 | Stage 4 stopped part way leaves three states, one of which the core would have called "move it to the Trash" | A, B, C | 2.4, MT3, MT8 |
| R15 | A second installer makes two Steams on one account likely; nothing stopped it | C | 2.2, 2.7, MT2, MD10 |
| R16 | The hand-over by "what it printed" would have hidden the download's progress | C, D | 2.3, 2.4 |
| R17 | `--mac-only` takes `--yes` and `--check`, and the plan did not say what refuses and what cautions; 14.6 was the old donor wrapper's need, the framework's is 14.0 | B, C | 2.4 (stage 1), 2.5, MT6 |
| R18 | Lines of the launcher and `make-app.sh` that assume a checkout were missed | A, B, C | 2.7, MT8 |
| R19 | Section 7 said no save was touched, had no way back for MD4, and ML3 had no clone of the engine it replaces | A | ML3, ML4b, section 7 |
| R20 | Exit criterion 4 could not be checked: ML6 stops at the sign-in window | A | section 6 |
| R21 | M1 could not be committed alone; MT5 was not a plain move; its "Wine 10 layout" case assumed what ML1 has yet to measure | A, C, D | M1, MT5, ML1 |
| R22 | The uninstall named the whole state folder, which holds save backups; it left out the log, the preferences file and downloads kept by `L1_DOWNLOADS` | B, C | 2.7, ML6 |
| R23 | MT8's helper case had no harness: it is a grep, and is now named as one | C | MT8 |
| R24 | Documents that name the moved script; the unification O3 row; README lines `:47-57` | A, C, D | 1.1, 2.7 |
| R25 | Smaller: the launcher takes 3 or later, not only 3.0; `:79-84` was `:77-84`; the BAK is the moved original; `make-wrapper.sh --help` names an engine; Sikarugir's files named GPTK 1.1; the Steam row's source; the Wine archive without D3DMetal; the rolling release; no way to sign in again; the branch cut after a rebase | A, B, C | 1.1, 1.2, 1.3, 2.2, 2.4, 2.8, M0, section 3 |

Not taken: nothing was rejected. Left for the build to settle, and named above: the terms of the
compiler's support library (2.6), and Apple's own download (M0).

### Second-pass re-check (2026-11-11)

Pass 1b: one agent, briefed to check the fold above and nothing else. It found every `file:line` the fold
added to be true, re-ran the two `codesign` lines, the sha256 table and the count of pieces, and confirmed
the swap's folder names and order in `make-engine.sh`. One blocker and eight smaller defects, all in the
fold itself, all folded:

| # | Defect in the fold | Folded into |
|---|---|---|
| S1 | **Blocker.** 2.2 holds the lock through stage 7 and 2.5 had setup refuse while the lock names a live process: the installer would have refused itself. No test or early live step would have shown it | 2.5 ("Run by the installer"), MT3, MT6, ML4b |
| S2 | `SM_VIA_INSTALLER` was set and never read | 2.5, MT3 |
| S3 | Stage 4 hid the line ML4 and the exit criterion need | 2.4 (stage 4), MT3 |
| S4 | ML4's "setup on its own" would still have built the real 14unch3r, and its "scratch app" starts the real wrapper | 2.5, MT6, ML4 |
| S5 | M1 moves the lock code and did not name the lock test | M1 |
| S6 | The recorded transcript could not hold MD10's new cases | MT1 |
| S7 | The per-game Wine environment and version test had no test | MT3 |
| S8 | ML2 did not say "Remember me", which the launcher's own start of Steam needs | ML2 step 3 |
| S9 | A rebuild stopped while removing the old Wine was a fourth state | 2.4 |
| S10 | Smaller: the archive is gone before the temporary folder; `--mac-only`'s exit 3 against "the same contract"; README's 14.6; `make-engine.sh`'s own words; a wrong line for why the app ignores `SM_WRAPPER`; MD10 under `--check` and in the other game's documents; mutants missing for nine cases; the fetch script missing from the own-files list; the way back for the MacBook; ML4 against ML2's step 5 | 2.2, 2.4, 2.7, MT2, MT3, MT4, MT6, MT8, ML4, ML4b, section 7 |

### After the check (2026-11-11): four changes, checked the same evening

At the session's close James asked whether this path was the best one. Four changes were offered and he
took all of them. Sections 1.6 and 2.2, step M1 and tests MT1, MT2 and MT5 moved to the shared-installer
plan with the third; where a row above names them, read that plan's sections 1.1 and 2.1, its step S2 and
its tests ST1 to ST3. (The rows S1 to S10 above are the second pass's, not that plan's steps.)

| # | Change | Why | Folded into |
|---|---|---|---|
| P1 | ML3 starts the real wrapper on the published engine with `SM_ENGINE`; the rebuild of its engine moves to ML4b | nothing to put back, and it fits ML2's sitting | M0, ML3, ML4b, section 7 |
| P2 | What is published names a game by its Steam app ID, with no default game | the repository's own rule on keys and labels, in the one place that cannot be changed after a release | the shared-installer plan (1.2, 2.2, S3, ST5, ST6); 2.2 here |
| P3 | The shared installer is a plan of its own, built first, before the installer plan's NL2 | it needs none of this plan's probes, it is already built once in a scratch tree, and this plan was 742 lines | the shared-installer plan; 1.6, 2.1, 2.2, M1, MT1, MT2, MT5, ML4, sections 6 and 7 here |
| P4 | The notes to Gcenx and Porting Kit also ask for a Wine 10 engine with D3DMetal 3.0 built in | it would take the swap, and one download, out of every install | MD1, 2.8 |

A fitted check of these four changes and of the split (one agent, the same evening) found two blockers,
one in each plan, and these defects here, all folded:

| # | Defect | Folded into |
|---|---|---|
| T1 | **Blocker.** MD5 still sent NL2 ahead "as planned", against the shared-installer plan's order | MD5 |
| T2 | ML3 recorded nothing that shows which engine ran, since the two lines that did moved to ML4b | ML3 |
| T3 | ML4b's rebuild named pieces that are not fetched at that point, did not close the game first, and started nothing afterwards | ML4b |
| T4 | ML3 in ML2's sitting would have changed the engine and the cloud's state in one start | ML3 |
| T5 | MD10's row and 2.8 disagreed on which plan changes Cities: Skylines II's installer | MD10 |
| T6 | Smaller: "changes nothing in the wrapper" (the prefix is used); a pointer in 1.7 that landed on nothing; the pasted line's ID in MT9; the note to Porting Kit rides with the installer plan's; step names against second-pass rows | M0, 1.7, MT9, MD1, section 7, this section |

The builder lens broke one of its rules once: a test run without its stub `curl` fetched the public
archive of 1.3 a second time, then deleted it. Nothing else left its scratch tree.

### Third-pass re-check (2026-11-13): the plan against the shared installer as built

The checks above were made before the shared installer existed. It was built on `simple-install` on
2026-11-11 (the shared-installer plan's S1 to S3), which moved code this plan cites, so the plan was
checked again before its first commit. Two lenses on Fable 5.2: a reference lens, which opened every cite
of sections 1.6 to 5 and asked of each thing this plan needs of the core whether the core as built gives
it; and a builder, which built M2, M3 and M6 in a scratch copy (`/private/tmp/sm-buildsim`) and ran them:
the fetch script on the real pinned archive with no network (exit 0 in 14.8 s; the 15 files and 3 links,
both signature requirements, the version and the four sha256 values all passed as 2.3 words them), stage 4
end to end with the real fetch and engine scripts on a fixture wrapper, and thirty cases of the installer
under a scratch home. Both: build-ready-with-fixes, no blocker. The planner re-read U1, U2, U3 and U5 in
the core before folding.

| # | Finding | Lens | Folded into |
|---|---|---|---|
| U1 | The core owns the only exit trap and has no hook, so "removed by the installer's exit trap" could not be built without losing the closing line and the lock's release; no case of MT3 would have gone red | both | 2.2 (`game_cleanup`, one line in the core), 2.4 stage 4, M6, MT3 and its mutants |
| U2 | The core exports `SM_WRAPPER` itself, so "with `SM_WRAPPER` set" was always true: setup would never have run on any Mac | both | 2.2, 2.4, MT3 and its mutants |
| U3 | "Before the core judges the wrapper" is inside `game_wrapper`, which runs before the core's tests of the lock and of a running game, and under `--check`; a second installer could have finished a swap the first was still making | both | 2.4 ("In the installer"), MT3 and its mutants |
| U4 | `make-engine.sh`'s finishing move had no place among its tests (its wrapper test refuses a wrapper with no `wine/` first) and no exit for a finished swap without `--rebuild` | builder | 2.4, MT8 and its mutants |
| U5 | The launcher lines named for the exports set no `WINE`, which the core calls, and read an `ENGINE` set above them | both | 2.2, MT3 and its mutants |
| U6 | `test-make-engine-install.sh` needs a CrossOver on the Mac: without one 8 of 14 cases fail, which is the state this plan aims for | builder | MT8 |
| U7 | The parity test pins the launcher line that 2.6 rewords; MT9 said nothing else moved | builder | 2.6, M5, MT9 |
| U8 | Cites moved by the shared-installer build and by an edit of the game's README | both | the header, 1.1, 1.2, 1.3, 1.5, 2.4, 2.7, ML4, the key paths |
| U9 | Two bullets of 2.7 were already done by the shared-installer build; the root `README.md` still names CrossOver and 14.6 for this game; the game's README said the game had not been started on the engine from the public pieces | reference | 2.7; the README's sentence was corrected with this fold, since ML3 made it false |
| U10 | The question of MD9 cannot sit inside step 3; the fetch script had no exit codes, no list of its 15 files, and pins a test could not rewrite; the installer-app and bootstrap tests need their own fixtures for this game; section 3 said "rebased" | both | 2.3, 2.4, 3, MT4, MT9 |
| U11 | ML4 did not carry what ML2 found: another Wine open stalls the wrapper's making, the VPN cuts Steam's update, and a new prefix switches a mod off | planner | ML4 |

Not changed: after a Mac check that exits 3 (an Intel Mac, a macOS below 14), the core's closing line says
to open the installer again, which is poor advice there; it is as the shared-installer plan's table words
it, and belongs to that plan. The builder's choices that this fold takes as they are: the `CX_GPTK`
refusal stands where the search was; the test that Apple's tools work is `nm` run on a system file; with
`SM_WRAPPER` given the installer ends quietly with exit 0. The words of the question, the free-space
sizes (from ML2's record in 1.4) and the tested macOS number are written at M5 and M6.

**Pass 3b, the same day: a fitted check of that fold**, by one agent on Fable 5.2. Every cite of the fold
held, and it confirmed that the installed wrapper's `wine/lib` has the shape `make-engine.sh` takes as
`CX_GPTK`. Its findings, each folded:

| # | Finding | Folded into |
|---|---|---|
| V1 | Two of the fold's MT3 mutants could never be seen red: with the lock's holder not looked at, the core's own test gives the same words and exit; and the temporary folder had two removals, so taking one out showed nothing | MT3: the case now requires the swap left as it was; 2.4 and 2.2: `game_cleanup` is the only removal |
| V2 | "After it has read the exit code" allowed the hook before the lock's release, where a failing `game_cleanup` would keep the lock; a `game_cleanup` could change the exit code or the closing line | 2.2: the hook is the last line of `on_exit`, with its contract; MT3's mutant for a second exit trap |
| V3 | The finish was triggered by a missing `wine64` only, and the core also rejects a missing `wineserver`; a whole `wine/` beside a finished `wine.new` was left to a stage 4 that is skipped at 3.0, or that asked, fetched and rebuilt where the finish alone would do | 2.4: `game_wrapper` finishes whenever a finished `wine.new` and the BAK are there; MT3 |
| V4 | The lock cannot be read through the core's `lock_holder` in `game_wrapper`; the finish ran with no lock, so two installers opened together could each remove the Wine the other had moved in; nothing said what happens when the engine script refuses | 2.4: the link is read directly; `make-engine.sh` gains its own guard (its fourth change); a refusal stops the installer with exit 3; MT3, MT8 |
| V5 | "Held identical by test" and "looks for the game under both paths" cannot both hold for `game_running` | 2.2: the launcher's function word for word, with `GAME` spelled as the launcher would; MT3 |
| V6 | Small: `WINE` cannot be both the launcher's line and exported; no mutant for `SM_ENGINE` not followed, for the finish's exit 0, or for an empty `CX_GPTK`; a 2.1 wrapper is not a source of pieces for the engine test, which must compare with its source and not with the pins; the core's header and the shared-installer plan's as-built header need a line for the new function; three sentences still spoke of the shared installer as not yet built | 2.2, MT3, MT8, 1.6, 2.1, section 3 |

The guard in `make-engine.sh` is the planner's answer to V4 and was not in the checker's report, which
offered taking the installer's lock for the finish or resting on the script's test for a Wine process.
The guard was chosen because it also covers a swap run by hand, and because the installer's lock code is
held identical in three files and is not copied into a fourth. It is new with this fold: MT8 carries its
cases and mutants, and the builder of M2 sees them red.

## Review log

Key paths: `install.sh`, `common/` (`install-core.sh`, `make-wrapper.sh`, `fetch.sh`,
`make-installer-app.sh`, `games.tsv`, `test-launch-lock.sh`, `test-make-wrapper.sh`,
`test-launcher-parity.sh`, `test-bootstrap.sh`, `test-make-installer-app.sh`), `cities-skylines-2/scripts/`
(`install.sh`, `setup.sh`, `test-install.sh`), `surviving-mars-relaunched/`
(`launch-relaunched.sh`, `make-app.sh`, `README.md`, `tools/make-engine.sh`, `tools/frame-fix.c`).

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-11 | 1 | architecture, sequencing, rollback and live steps; security, supply chain and outside facts; correctness and test plan; builder simulation | four agents; each blocker re-read in the code or re-measured by the planner; the builder's test results re-run by the planner; seven measurements added to the probe's records | Fable 5.2 for three lenses and the fold, Opus 5.5 for the builder | `04936e7` on `main`, `6a66416` on `simple-install` | build-ready-with-fixes |
| 2026-11-11 | 1b | fitted fold check | one agent; its blocker and four of its facts re-read in the code by the planner, one measurement re-read and recorded (the transcript mutant) | Fable 5.2 for the check and its fold | `8465248` on `main`, `6a66416` on `simple-install` | build-ready-with-fixes |
| 2026-11-11 | 2 | fitted check of the four changes after the check, and of the split | one agent; its two blockers re-read by the planner | Fable 5.2 for the check and its fold | `3f80932` on `main`, `7ef565f` on `simple-install` | build-ready-with-fixes |
| 2026-11-13 | 3 | re-check against the shared installer as built: references and what the core gives; builder simulation of M2, M3 and M6 | two agents; the builder ran its scripts (the fetch on the real archive, stage 4 end to end on a fixture, thirty installer cases, the existing tests before and after); four findings re-read in the core by the planner, every corrected cite opened | Fable 5.2 for both lenses and the fold | `8ee1ad2` on `main`, `4d339dd` on `simple-install` | build-ready-with-fixes |
| 2026-11-13 | 3b | fitted check of pass 3's fold | one agent; it opened every cite of the fold, walked six states of an interrupted swap through `core_begin`, and measured the hook in bash 3.2; its findings re-read by the planner against `core_begin` and the lock code | Fable 5.2 for the check and its fold | the working tree of `main` over `8ee1ad2`, `4d339dd` on `surviving-mars-install` | build-ready-with-fixes |
