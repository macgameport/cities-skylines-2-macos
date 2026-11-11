# Surviving Mars: Relaunched from nothing, without CrossOver, on one shared installer

> **Status:** written 2026-11-11. Not checked: run `check it` before any code is written from this.
>
> Tracking: issue #22. The installer this builds on exists only on the branch `simple-install`; references
> to `install.sh`, `cities-skylines-2/scripts/install.sh`, `make-wrapper.sh`, `common/make-installer-app.sh`
> and their tests are as of that branch at `6a66416`. Every other reference is as of `main` at `efcd2cd`;
> nothing under `surviving-mars-relaunched/`, and neither `common/games.tsv` nor
> `common/launcher-window.swift`, differs between the two. A path is relative to the repository root.
> "The installer plan" is `docs/plans/simple-install.md`, with its steps N1 to N6 and live steps NL1 to NL5.
> This plan's steps are M0 to M8, its tests MT1 to MT10, its live steps ML1 to ML7 and its decisions MD1 to
> MD8. Every number marked "measured" was measured on the Studio (M5 Max, macOS 27.2.1) on 2026-11-11; the
> records are in `~/Library/Application Support/1launcher/surviving-mars-relaunched/runs/d3dmetal-source-probe-20261111/`
> (`SUMMARY.txt` first).

## 0. What James asked for (2026-11-11)

"should we have one installer handle everything?", then, on hearing what Surviving Mars depends on: "we
need SMR to run without needing crossover or the launcher is still just a cs2 wrapper, not a launcher".
After the probe of section 1.4: "Write the plan".

So two things, and the second serves the first:

1. A person with an Apple Silicon Mac and a Steam account that owns Surviving Mars: Relaunched can install
   and play it with nothing else: no CrossOver, no wrapper of another game already on the Mac, no compiler.
2. The installer is one program with a short list of settings per game, not one program per game.

## 1. What is true today (read or measured)

### 1.1 How the game is set up today

- There is no install from nothing. `surviving-mars-relaunched/README.md:44` says so: the one-time setup,
  `tools/split-wrapper.sh`, makes `~/Applications/SurvivingMars.app` by cloning one Cities: Skylines II
  wrapper and moving the game out of another (its header, phases A0 to A4b).
- D3DMetal 3.0 comes from a CrossOver 26 on the same Mac (`README.md:58`). `tools/make-engine.sh:57` looks
  in `CX_GPTK`, then in the two places CrossOver installs to, and `:74` stops without one. What it takes is
  six pieces (`:86-92`): `external/D3DMetal.framework`, `external/libd3dshared.dylib`, and
  `wine/x86_64-windows/` `atidxx64.dll`, `d3d11.dll`, `d3d12.dll`, `dxgi.dll`.
- The game is DirectX 12 only (`README.md`, "Findings"; `launch-relaunched.sh:4-5`), so it needs D3DMetal:
  DXMT, the Cities: Skylines II engine, is Direct3D 11. Under D3DMetal 2.1 a landscaping project turns the
  whole map black; 3.0 renders it. The launcher refuses anything but 3.0 (`launch-relaunched.sh:139-143`).
- The click-offset helper, `tools/frame-fix.exe`, is built with Homebrew's `mingw-w64` (`README.md:60`,
  `:75`) and is not in the repository (`surviving-mars-relaunched/.gitignore:9`). Without it the launcher
  goes on and tells the player to press Option+Return twice (`launch-relaunched.sh:377`).
- The double-click app runs the launcher inside the checkout (`make-app.sh:22`; "It runs the scripts in
  this checkout and never pulls", `README.md`). An install made from a temporary copy of the repository
  would leave an app that points at a folder macOS later removes.

### 1.2 What the launcher needs from a wrapper

Read from `launch-relaunched.sh`: a wrapper at `~/Applications/SurvivingMars.app` or `SM_WRAPPER` (`:71`);
in it `Contents/SharedSupport/wine` with D3DMetal 3.0 (`:76`, `:139`), `Contents/Frameworks` (`:79`), and a
prefix holding Steam for Windows signed in and the game at
`steamapps/common/Project Spark/Mars.exe` (`:73`, `:145`) with `appmanifest_3215050.acf` (`:95`). The
launcher writes `steam_appid.txt` itself (`:363`) and sets its own environment (`:79-84`). It asks nothing
of the wrapper's own launcher or `Info.plist`.

### 1.3 Where the pieces are published (read 2026-11-11)

| Piece | Published by | File | Bytes | sha256 |
|---|---|---|---|---|
| Wrapper template | Porting Kit, `vitor251093/porting-kit-wrappers`, release `Wineskin-3.0.6-2` | `Wineskin.app.tar.7z` | 53,110,672 | `fbe276bb...907a` (the installer plan's pin, `make-wrapper.sh:21-23`) |
| Wine 10 | Porting Kit, `vitor251093/porting-kit-engines`, release `wineskin` | `WS12WineSikarugir10.0_2_D3DMetal-v2.1.tar.7z` | 183,963,888 | `a2f9322f3e6160453d9b31891e91d17a7c1f0b752c1804416880792c37d125d2` (GitHub's digest; not downloaded) |
| D3DMetal 3.0 | Gcenx, `Gcenx/game-porting-toolkit`, release `Game-Porting-Toolkit-3.0-3` (2026-03-03) | `game-porting-toolkit-3.0-3.tar.xz` | 239,200,808 | `d377683937340f914823dbb2e1252b329cbf834ff58907d0293db8cebf0e392e` (downloaded, matches) |
| Steam for Windows | Valve | `SteamSetup.exe` | 2,380,800 | the installer plan's tested value (`cities-skylines-2/scripts/install.sh:25-26`) |

The wrapper's own Wine names itself: `wine.d3dm21-BAK/version` reads "wine sikarugir 10.0 (revision 2
D3DMetal-v2.1)", which is the name of the second row. That the published file is the same Wine is not
measured (ML1). No published engine has D3DMetal 3.0 built in: Porting Kit's newest D3DMetal engine is
v2.1, and the engines of `Sikarugir-App/Engines` are plain Wine.

### 1.4 The probe (measured)

- Gcenx's archive holds one folder, `Game Porting Toolkit.app`, 6,041 entries, none absolute and none with
  `..`. The six pieces are under `Contents/Resources/wine/lib/`, in the layout `make-engine.sh` reads
  (`external/`, `wine/x86_64-windows/`). Nothing from the archive was run.
- `D3DMetal.framework`: all 10 files are byte-identical to the copy the game runs on today, which came from
  CrossOver 26.2. Version 3.0 in both. `codesign --verify --strict` passes on the downloaded copy; its
  identifier is `com.apple.D3DMetal` and its authority chain is Software Signing, Apple Code Signing
  Certification Authority, Apple Root CA.
- `libd3dshared.dylib`: byte-identical.
- The four DLLs: every PE section, the link stamp, the imports and the exports are equal. CrossOver's
  copies carry a certificate table of 7,744 bytes at the end (CodeWeavers' signature); within the length
  of Gcenx's file 7 bytes differ, the header's checksum and the entry that points at that table.
- `CX_GPTK=<the archive's lib folder> bash tools/make-engine.sh <out>` ran for the first time and built an
  engine. `diff -rq` against the installed engine: the four DLLs and nothing else, 4,789 files on each
  side. It is kept as `~/Library/Developer/1launcher/surviving-mars-relaunched/engine/wine-d3dm30-gcenx`.
- `tools/frame-fix.exe`: two plain builds differ in 2 bytes (the link stamp); two builds with
  `-Wl,--no-insert-timestamp` are byte-identical (149,913 bytes, `x86_64-w64-mingw32-gcc` 16.2.0). The
  result holds no `/Users/` string.
- The game is 10,816,563,427 bytes on disk by Steam's count (build 25579348).

### 1.5 Apple's licence for the toolkit (read in full)

The release notes of Gcenx's archive link Apple's "Software License Agreement for Game Porting Toolkit"
(EA18380, 8/17/2023); the archive itself holds no copy. What it says, by section:

- 2A(i): the software may be installed and used for developing, testing or evaluating video games for
  Apple-branded products. It does not name playing.
- 2A(iii) and 2C: it may be distributed for non-commercial purposes only. The framework as a whole, and
  any part of the toolkit's `/redist` folder, may be distributed apart from the rest.
- 2C: only on Apple-branded hardware. 2D: no modification and no reverse engineering. 5: Apple may end
  the licence with notice.

Porting Kit's D3DMetal engines rest on the same wording, the 2.1 engine this game's wrapper already
starts from among them. `README.md:66-67` says today that nothing from Apple is in this repository and
that the engine built from it may not be redistributed; both stay true, since the installer fetches the
archive from its publisher and builds the engine on the player's Mac. This is a reading of the text, not
legal advice.

### 1.6 The installer as it is built, and what in it belongs to one game

`cities-skylines-2/scripts/install.sh` (446 lines) is six stages, each skipped when done. What names
Cities: Skylines II in it:

- the wrapper's default path and the candidates looked through (`:88-99`, `:209-235`), and `CS2_WRAPPER`;
- the game's folder, program and manifest (`:109`, `:157-158`, `:172-181`);
- stage 1's check of the Mac, which is `setup.sh --mac-only` (`:241-243`), and stage 6, which is `setup.sh`
  (`:435-446`);
- the words: the title lines, "about 100 GB", "about 235 MB", the closing line, the free-space caution
  (`NEED_GB`, `:33`).

Everything else is about a Mac, a wrapper, Steam, and a game identified by its Steam app ID: the options,
the traps, the lock, the Steam helpers, stage 2 (Apple's tools), stage 4 (Steam's installer, checked and
run), and stage 5 (start Steam through its first-start failure, wait for the download by the manifest,
close Steam). `make-wrapper.sh` (177 lines) names the game in its engine pin (`:18-20`), its default
target (`:31`) and its first comment line; the rest makes any wrapper from a template and an engine.

The root `install.sh` already takes the game as its first word and hands over to
`<game>/scripts/install.sh` (`:78-85`); `common/make-installer-app.sh` already takes `--game` and names the
app from `common/games.tsv` (`:46-51`). The 14unch3r window shows a game with no app as "Not set up" and
opens its guide (`common/launcher-window.swift:165`, `:755`).

The lock code is held identical in three files by `common/test-launch-lock.sh:19-20`; the installer's
copies of the launcher's Steam helpers are held identical to the Cities: Skylines II launcher by
`cities-skylines-2/scripts/test-install.sh` (its mutant 19).

### 1.7 What is not known

1. Whether the game starts on an engine made from Gcenx's pieces, whose DLLs lack CodeWeavers' signature.
   Nothing in Wine reads it; whether the game or Steam does is unmeasured (ML3).
2. Whether the published Wine 10 archive is the Wine in the wrapper (ML1).
3. Whether a prefix made from nothing runs Steam and the game. The wrapper in use is a clone of one that
   Porting Kit's Steam port made; whatever that port put in its prefix beyond a plain one is unlisted (ML2).
4. Whether Steam's installer and Steam's first start behave on Wine 10 with D3DMetal 3.0 as they did on
   Wine 11 with DXMT, where the first start failed and the second worked (the installer plan, 1.4).
5. Whether `steam://install/3215050` is needed. The header of the launcher calls it "the route
   (unmeasured)" for a Mac with no copy of the game (`launch-relaunched.sh:35`). For Cities: Skylines II
   the player's own click on Install worked and the URL opened Steam's Install box (the installer plan's
   NL1); this plan uses the click.

## 2. Design

### 2.1 The parts

| File | New or changed | What it is |
|---|---|---|
| `common/install-core.sh` | new, from `cities-skylines-2/scripts/install.sh` | the shared installer: everything of 1.6 that is not one game's, as functions a game's installer calls in order |
| `common/make-wrapper.sh` | moved from `cities-skylines-2/scripts/` | takes the engine as three required options; the template pin stays in it |
| `common/fetch.sh` | new, from `make-wrapper.sh` | `fetch <url> <bytes> <sha256> <file>` with `L1_DOWNLOADS`, and `sha`, for both callers |
| `cities-skylines-2/scripts/install.sh` | reduced | the game's settings, then the core's stages, then `setup.sh` |
| `surviving-mars-relaunched/scripts/install.sh` | new | the same shape with seven stages |
| `surviving-mars-relaunched/scripts/setup.sh` | new | `--mac-only`; puts the launcher and the helper where the app can keep them; builds the app and 14unch3r |
| `surviving-mars-relaunched/tools/fetch-d3dmetal.sh` | new | fetches the pinned archive, takes the six pieces out, checks them, prints their folder |
| `surviving-mars-relaunched/tools/frame-fix.exe` | new in the repository | the built helper, with a test that rebuilds and compares (MD3) |
| `surviving-mars-relaunched/INSTALL.md` | new | the guide: the quick way, what is downloaded and from whom, Apple's terms, uninstall |
| `surviving-mars-relaunched/launch-relaunched.sh`, `make-app.sh`, `README.md` | changed | words that assume a checkout or CrossOver (2.6, 2.7) |
| `tools/make-engine.sh` | unchanged in what it does | its error line and header name the installer as the usual source |

`tools/split-wrapper.sh` stays as it is: it is how the two existing Macs got their wrapper, and it is not
part of an install from nothing.

### 2.2 The shared installer

`common/install-core.sh` is read with `.` by a game's installer after the game's settings are set, and is
never run by itself. The game's file stays the address the bootstrap hands over to
(`<game>/scripts/install.sh`), so `install.sh` at the root and the installer app do not change.

The settings a game gives:

| Setting | Cities: Skylines II | Surviving Mars: Relaunched |
|---|---|---|
| title | Cities: Skylines II | Surviving Mars: Relaunched |
| Steam app ID | 949230 | 3215050 |
| folder under `steamapps/common` | `Cities Skylines II` | `Project Spark` |
| program | `Cities2.exe` | `Mars.exe` |
| wrapper, and the variable that overrides it | `~/Applications/CS2dxmt11.app`, `CS2_WRAPPER` | `~/Applications/SurvivingMars.app`, `SM_WRAPPER` |
| other wrappers looked through | the launcher's list (`find_wrapper`) | none |
| engine: file, bytes, sha256 | `WS12Wine11.0_DXMT-v0.80.tar.7z`, as pinned today | the second row of 1.3 |
| number of steps | 6 | 7 |
| download, in words | about 100 GB, hours | about 10 GB |
| free space wanted | 110 GB | 20 GB |
| the Mac check | `scripts/setup.sh --mac-only` | the same contract, its own `setup.sh` |
| `game_running` | its launcher's, held identical by test | its launcher's (`launch-relaunched.sh:149`), held identical by test |
| closing line | "Cities Skylines II, or 14unch3r" | "Surviving Mars Relaunched, or 14unch3r" |

The core's functions, in the order a game calls them: begin (options, the opening lines, the wrapper
chosen, the running-game refusal, `caffeinate`), the Mac, Apple's tools, the wrapper, Steam, the game. A
game puts its own stages between them and after them. The step number printed comes from the game's count.

Rules for the move:

- **Cities: Skylines II's installer prints and does exactly what it does at `6a66416`.** The move changes
  where lines live, not one word of output and not one exit code. MT1 holds this.
- The lock code in the core is the copy `common/test-launch-lock.sh` holds identical to both launchers.
  The Steam helpers in the core (`_owns`, `webhelper_up`, `steam_family`) stay the copies held identical
  to the Cities: Skylines II launcher; Surviving Mars's launcher spells the same functions differently
  (`launch-relaunched.sh:190-198`) and is not changed for this.
- `game_running` and the wrapper search are the game's, not the core's.
- Every line the player reads that names a game or a size comes from a setting. No line of the core holds
  either game's name; MT2 greps for it.

`common/make-wrapper.sh` takes `--engine-url`, `--engine-bytes` and `--engine-sha`, all three or it exits
2, and `--wrapper`. It has no default target and no default engine. Nothing it prints names a game or an
engine today, so its output does not change.

### 2.3 `tools/fetch-d3dmetal.sh`

`bash tools/fetch-d3dmetal.sh --into <folder>` leaves `<folder>/lib/external/` and
`<folder>/lib/wine/x86_64-windows/` holding the six pieces and prints `<folder>/lib`, the value
`make-engine.sh` takes as `CX_GPTK`. The folder must not exist; on any failure nothing is left.

1. The archive is fetched with `common/fetch.sh` against the size and sha256 of 1.3. A file that is no
   longer published, or not the pinned one, stops with the words `make-wrapper.sh` uses for its two files.
2. Its listing is read first (`tar -tf`). Any name that is absolute or holds `..` stops the script.
3. Only the members under `Game Porting Toolkit.app/Contents/Resources/wine/lib/external/` and the four
   DLLs are taken out, with `--no-mac-metadata`. Nothing else in the archive touches the disk, and nothing
   from it is run.
4. Checks, each stopping the script: the framework's version reads 3.0; `codesign --verify --strict` passes
   on the framework and its signature satisfies `anchor apple`; `libd3dshared.dylib` and the four DLLs are
   there, the DLLs beginning `MZ`.

The sha256 pin already fixes every byte. The signature check is there because it says something the pin
cannot: that the framework is Apple's own build, whoever published the archive.

### 2.4 The installer for Surviving Mars

Seven stages, each skipped when done:

1. **This Mac.** Apple Silicon, Rosetta 2 (offered as today), macOS 14.6 or later (`README.md:41-42`).
2. **Apple's Command Line Tools.** As for Cities: Skylines II. Here they give the app its icon and its
   progress window (`make-app.sh:24`, `:115-121`), not the game (MD6).
3. **Wine.** `common/make-wrapper.sh` with this game's engine, into `SurvivingMars.app`.
4. **Apple's D3DMetal 3.0.** Skipped when the wrapper's framework reads 3.0, by the launcher's own
   expression (`launch-relaunched.sh:139-140`). Otherwise `fetch-d3dmetal.sh` into a temporary folder, then
   `make-engine.sh --install <wrapper>` with `CX_GPTK` set to what it printed, then the folder removed. It
   says where the files come from and that installing them accepts Apple's licence, with the licence's
   address. If the framework does not read 3.0 afterwards it stops. A CrossOver on the Mac is not looked
   for: one source, the pinned one.
5. **Steam for Windows.** The core's.
6. **The game.** The core's, with this game's words.
7. **The game's app.** `scripts/setup.sh`.

Stage 4 comes before Steam is installed, so that no Wine process is using the wrapper when its engine is
swapped (`make-engine.sh` refuses otherwise) and Steam is first started on the engine it will keep.

`make-engine.sh --install` keeps the Wine it started from as `wine.d3dm21-BAK` inside the wrapper. It is
an APFS clone and costs almost no disk; it stays, because `--rebuild` builds from it.

### 2.5 `surviving-mars-relaunched/scripts/setup.sh`

- `--mac-only`: the checks of stage 1, with the exit codes the core reads (0 ready, 1 Rosetta missing).
- Otherwise: it copies `launch-relaunched.sh` and `tools/frame-fix.exe` into the game's state folder,
  `~/Library/Application Support/1launcher/surviving-mars-relaunched/` (`SM_STATE`, where `runs/` and
  `backup/` already are), keeping the `tools/` level so the launcher finds the helper where it looks
  (`launch-relaunched.sh:74`); builds the app with `make-app.sh` told to run that copy (`SM_SCRIPT`,
  `make-app.sh:22`); and builds `14unch3r.app` with `common/make-launcher-app.sh`. It never touches
  `runs/` or `backup/`. It prints the home folder as `~`.
- It does this on every Mac, a maintainer's included (MD4): one way of running, which is the one a
  stranger gets. After `git pull`, a maintainer runs setup again, as for Cities: Skylines II.
- No Desktop shortcut is offered by this setup. The one alias the repository allows on the Desktop is
  14unch3r's, and Cities: Skylines II's setup makes it.

No new place outside the repository: the state folder is already in the root `CLAUDE.md`'s list.

### 2.6 `tools/frame-fix.exe` in the repository

The helper is built once with `-Wl,--no-insert-timestamp` and committed, with a line added to
`.gitignore` to let that one file through; `tools/game-input.exe`, a testing tool, stays out. A text file
beside it, `tools/frame-fix.build`, records the compiler's version line and the file's sha256. The build
line in the header of `frame-fix.c` gains the flag. MT7 holds the file to its source.

The launcher's line for a missing helper (`:377`) loses "is not built (see its header)": the file is now
part of the install, and its absence is a damaged install.

### 2.7 The documents

- `surviving-mars-relaunched/INSTALL.md`: the quick way (the app or the pasted line, as in the Cities:
  Skylines II guide, with that guide's pictures of macOS's messages reused by link); what the installer
  downloads and from whom, in a table like 1.3; a paragraph on Apple's licence in plain words, with its
  address: what it allows, that it is non-commercial, and that it speaks of evaluating games; the one
  Steam at a time rule; uninstall, which names the wrapper, the app, the state folder and 14unch3r.
- `surviving-mars-relaunched/README.md`: "What it assumes" loses the three lines that need another game's
  wrappers, CrossOver and `mingw-w64` (`:44`, `:58`, `:60`); Setup leads with the installer;
  `split-wrapper.sh` is described as the way the first two Macs were set up. `:66-67` gains the helper as
  the one binary in the repository.
- `launch-relaunched.sh:143`: the refusal on D3DMetal 2.1 says to open the installer again, and gives the
  `make-engine.sh` line for a checkout second. Its header's "On another Mac" paragraph (`:31-35`) is
  replaced by a pointer to the guide.
- `common/games.tsv`: the guide address of Surviving Mars becomes its `INSTALL.md`.
- The root `README.md` and `CLAUDE.md`: Surviving Mars has an installer; `common/` gains the three shared
  files; and where `CLAUDE.md` lists what the game's state folder holds (`backup/` and `runs/`), it gains
  the launcher's copy and the helper.
- `cities-skylines-2/GOTCHAS.md` is not the place for this game's findings; they go in the README's
  "Findings" list, with their measurements.

### 2.8 What this plan leaves alone, and what it cannot test

- 14unch3r's "Not set up" tile keeps opening the guide. Having it start the installer is a later slice
  (MD8).
- `steam://install/<id>` is not used (1.7, item 5).
- The Cities: Skylines II installer gains nothing but the move.
- macOS 28 and Macs without Rosetta: no route for this game (cs2 #21), and none is made here.
- A second source for D3DMetal. If Gcenx's file goes, stage 4 stops with the "no longer published" words
  until a new pin is committed; MD1 covers asking him.
- Stages 1 and 2 are tested with stubs only, as in the installer plan (its 2.9).

## 3. Steps

- **M0. The two probes that decide the design, before any code** (ML1, ML2). If the published Wine is not
  the wrapper's Wine, or a wrapper from nothing does not run the game, the difference is written into this
  plan as a step and the plan is checked again. ML3 runs beside them.
- **M1. `common/fetch.sh` and `common/make-wrapper.sh`.** The move and the three options. MT5.
- **M2. `common/install-core.sh`, and Cities: Skylines II's installer reduced to its settings.** MT1, MT2.
- **M3. `tools/fetch-d3dmetal.sh`.** MT4.
- **M4. `tools/frame-fix.exe` committed, with `frame-fix.build`.** MT7.
- **M5. `surviving-mars-relaunched/scripts/setup.sh`, and `make-app.sh` and the launcher's words.** MT6, MT8.
- **M6. `surviving-mars-relaunched/scripts/install.sh`.** MT3.
- **M7. The documents of 2.7**, and the installer app's test for this game (MT9).
- **M8. The live steps ML4 to ML6, then the as-built header.**

The work is done on a branch cut from `simple-install`. Whether that branch is merged first is MD5.

## 4. Test plan

Every test runs with `HOME` at a scratch folder and every outside program a recording stub, as
`cities-skylines-2/scripts/test-install.sh` does. Each mutant is applied to the real source, seen red, and
removed; a mutant whose line is gone refuses with exit 2.

| # | Test | What it shows | Mutants, each must turn it red |
|---|---|---|---|
| MT1 | A one-time gate at M2, run and recorded in the as-built header: the installer of `6a66416` and the reduced one, each run against the same stub world for every scenario of `test-install.sh` | the output and the exit code are identical, scenario by scenario | one word changed in a core message; one exit code changed; a stage's skip test inverted |
| MT2 | `cities-skylines-2/scripts/test-install.sh`, its 96 cases, with only the paths of moved lines changed | the installer still does what NT3 showed | its 25 mutants, each applied where its line now lives; new: the core holds a game's name; a setting read before it is set |
| MT3 | `surviving-mars-relaunched/scripts/test-install.sh` | seven stages, each skipped when done; stage 4 skipped at 3.0, run at 2.1 and with no framework; stage 4 before Steam's installer; a wrapper not reading 3.0 after the swap stops it; the game found by `Project Spark/Mars.exe` and manifest `3215050` at `StateFlags` 4; `--check` changes nothing; no line says "Cities"; the lock; the running-game refusal by this game's test | stage 4 skipped at 2.1; stage 4 after Steam; the 3.0 check after the swap removed; the manifest of the other game accepted; `--check` fetching; the lock not taken; setup run with the game absent; CrossOver looked for |
| MT4 | `surviving-mars-relaunched/tools/test-fetch-d3dmetal.sh`, with small archives the test makes | the six pieces land and the folder is printed; wrong size, wrong sha256, a piece missing, a framework reading 2.1, a failed signature check, and a member named with `..` or from `/` each stop it with nothing left; a planted extra member never reaches the disk; a matching copy in `L1_DOWNLOADS` is used and a non-matching one is not; curl's 22 gives the "no longer published" words; nothing from the archive is run | the sha256 test removed; the version test removed; the signature test removed; the `..` test removed; the whole archive unpacked; the folder left behind on failure |
| MT5 | `common/test-make-wrapper.sh`, the 59 cases moved | as NT1; and: no engine options exits 2, two of three exits 2, the Wine 10 archive's layout is accepted | its 10 mutants; new: a default engine put back |
| MT6 | `surviving-mars-relaunched/scripts/test-setup.sh` | the launcher and the helper are in the scratch state folder; the app's program names that copy and not the checkout; `runs/` and `backup/` are untouched, files in them included; `--mac-only` gives 0, and 1 without Rosetta; from a temporary copy the app still names the state folder; the 14unch3r builder is called | the app pointed at the checkout; the helper not copied; a file in `runs/` removed; `--mac-only` going on to copy |
| MT7 | `surviving-mars-relaunched/tools/test-frame-fix-build.sh` | the committed file has the recorded sha256 and no `/Users/` string; where the recorded compiler is installed, a rebuild is byte-identical; elsewhere it says the rebuild was skipped and why | one byte of the file changed; the flag dropped from the build line |
| MT8 | The launcher's existing tests, with two cases added | the refusal on 2.1 names the installer and holds no checkout path; a missing helper is reported without "not built" | either line put back |
| MT9 | `common/test-launch-lock.sh`, `common/test-bootstrap.sh`, `common/test-make-installer-app.sh` with a case for this game, `common/test-launcher-parity.sh`, the eight `tools/test-*.sh`, `tools/test-make-app.sh` | the lock code is identical in the core and both launchers; the bootstrap hands over to either game; the app is "Install Surviving Mars Relaunched"; nothing else moved | the lock test's own mutant, with the core as its third file |
| MT10 | The gates: `common/check-links.py`, `common/check-identifiers.sh` at its residual of 9, `cities-skylines-2/scripts/check-experiments.py`, `bash -n` on every script | no dead link, no identifier, the ledger whole | none: they are gates |

## 5. Live steps, each on James's word

- **ML1. The published Wine.** The second row of 1.3 is downloaded (184 MB), checked against its digest,
  unpacked beside the probe's folder, and compared with `SurvivingMars.app`'s `wine.d3dm21-BAK` by
  `diff -rq`. Recorded: identical, or every file that differs.
- **ML2. A wrapper from nothing, by hand, on the Studio.** With no game, Steam or launcher running, and
  the last exit upload of the game ok. A copy of `make-wrapper.sh` with the three pin lines changed makes
  `~/Applications/SMfresh.app`; `make-engine.sh --install` with the probe's pieces; Steam's installer;
  Steam started, with what its first start does recorded. James signs in. The game's folder and then its
  manifest are cloned from `SurvivingMars.app` with `cp -Rc` (no download, almost no disk).
  `SM_WRAPPER=~/Applications/SMfresh.app bash launch-relaunched.sh` must reach the menu; James loads the
  save with a landscaping project and looks at the map. A visible game start: he is told before it.
  Recorded besides: what the old prefix holds that the new one does not (the registry's override and
  uninstall keys, `system32` files that are not Wine's), kept with the run; the cloud upload at exit; that
  the real wrapper's next launch pulls with no conflict. Then Steam is signed out there and `SMfresh.app`
  goes to the Trash.
- **ML3. The real wrapper on the published pieces.** `make-engine.sh --install ~/Applications/SurvivingMars.app
  --rebuild` with `CX_GPTK` at the probe's pieces; James plays a session with landscaping. The way back is
  the same line without `CX_GPTK`, which takes CrossOver's copies again.
- **ML4. The installer, for real, on the Studio**, after M6: from the branch's worktree into a scratch
  wrapper named by `SM_WRAPPER`, through every stage, the game cloned in while it polls, as NL1 did; then
  the launcher to the menu. And once more for Cities: Skylines II after the move: the installer into a
  scratch wrapper, the game cloned in, `boot-verify.sh` to the main menu.
- **ML5. The MacBook.** The installer on a Mac whose wrapper was made the old way: every stage reports done
  except setup, and the app runs the copy in the state folder. Then the game.
- **ML6. A Mac account with nothing in it**, with NL4 of the installer plan: the published app or pasted
  line for this game, to Steam's sign-in window; whether the game is downloaded there is James's call.
- **ML7. After the first week:** whether the three pinned files are still published, and anything a player
  reported.

## 6. Exit criteria

- M0's three probes are recorded, and the design is unchanged by them or the change was checked.
- M1 to M7 are committed; MT1 was run and its result is in the as-built header; MT2 to MT10 pass; every
  listed mutant was applied and seen red, with the count in the header.
- ML4 passed for both games; ML5 passed.
- A Mac with neither CrossOver nor a wrapper of another game installs and starts Surviving Mars: ML6, or
  ML4 on an account with neither if ML6 waits for the release.
- `README.md` no longer lists CrossOver, another game's wrappers or `mingw-w64` under "What it assumes".
- The as-built header is written, with the deviations.

## 7. Rollback

- Nothing here changes a file inside a game's prefix or a save. The engine swap keeps the Wine it replaced
  inside the wrapper, and ML3 names its way back.
- The move of M1 and M2 is one revert: the installer of `6a66416` is whole in the history, and MT1 exists
  to show the two behave alike before anything depends on the new one.
- An install made by the new installer is removed by the guide's uninstall: the wrapper, the app, the
  state folder, 14unch3r.
- Once `release` carries this, a pin that stops being published is fixed by a commit and a move of
  `release`; until then stage 3 or 4 stops with words that say so.

## 8. Decisions, each James's

**Decided 2026-11-11: all eight as recommended.** Asked whether he accepted them, with MD5 named as the
one that costs time, James answered: "That's fine, no one is waiting for any of this. We're just doing it
for the sake of doing it." So nothing here is traded against a date: where a step can be done properly or
quickly, it is done properly. The sections above already describe the recommended choices.

| # | Decision | Decided as recommended |
|---|---|---|
| MD1 | Where D3DMetal 3.0 comes from | Gcenx's release page, pinned by size and sha256, fetched by the installer and never re-hosted, as for Porting Kit's two files; the guide and stage 4 state Apple's terms. A short note to Gcenx, drafted for James to send or not, asking whether old releases stay published. The other sources are Apple's own download, which needs a signed-in Apple Account and cannot be scripted, and CrossOver |
| MD2 | What the guide says about Apple's licence | What 1.5 says, in plain words, with the licence's address: allowed non-commercially, written for evaluating games, Apple-branded hardware only. No claim that it permits more |
| MD3 | The helper in the repository | Commit `tools/frame-fix.exe`, 150 KB, built without a link stamp, with MT7. The other ways are a compiler on the player's Mac, or going without the helper |
| MD4 | The app runs a copy in the state folder on every Mac | Yes. It replaces the unification plan's O3 (c) for this game: after `git pull`, run setup |
| MD5 | Order against the installer plan | NL2 goes ahead as planned. NL3, the first public release, waits for ML4, so that what is first published installs both games and the shared files have their final addresses before anyone depends on them. The other order is to publish Cities: Skylines II now and move `release` forward later |
| MD6 | Apple's Command Line Tools for this game | Asked for, as for Cities: Skylines II: one behaviour, and the app gets its icon and progress window. The other way is to skip the stage and accept a generic icon |
| MD7 | One shared installer, or a second script held alike by a test | One (2.2). The second is how the two launchers share code today, and costs nothing in Cities: Skylines II's installer, but leaves two 400-line files |
| MD8 | 14unch3r's "Not set up" tile starts the installer | A later slice, with its own plan: it changes the window app and its tests |

## Review log

Not checked yet.

Key paths: `install.sh`, `common/` (`install-core.sh`, `make-wrapper.sh`, `fetch.sh`,
`make-installer-app.sh`, `games.tsv`, `test-launch-lock.sh`), `cities-skylines-2/scripts/` (`install.sh`,
`setup.sh`, `make-wrapper.sh`, `test-install.sh`, `test-make-wrapper.sh`), `surviving-mars-relaunched/`
(`launch-relaunched.sh`, `make-app.sh`, `README.md`, `tools/make-engine.sh`, `tools/frame-fix.c`).
