# 14unch3r: one window that lists the games

> **Status:** Triple-checked 2026-11-10 — build-ready-with-fixes, corrections folded. Pass 1 was four
> lenses; pass 1b was a fifth agent checking the fold, and its findings are folded too. Five decisions
> James made the same day are in section 9; the two made after the check changed 2.4's last paragraph, W12
> and live step 2, as the note at the end of the corrections says. He said go the same day.
> Written 2026-11-10. Tracking: issue #22. This is Phase B of `docs/plans/launch-experience.md`, the second
> slice of Phase 5 of `docs/plans/1launcher-unification.md`. It differs from the Phase B paragraph of that
> outline in three ways, listed under D1, D2 and section 8. File and line references are as of `509bc56`;
> no code file they name has changed since. A path is relative to the repository root.
> **🔧 As-built (2026-11-10):** PARTIAL: B1 to B7 built, and merged as `1a782fb`. Live steps 0 to 2 are done on
> the Studio. Step 0, before the merge: the built `--owned` on the real `packageinfo.vdf` of all four wrappers
> read 949230 and 3215050 `owned` and 730 `not-owned`, in each file alone and in all four together. Step 1: the
> lock check printed nothing and no Wine process ran. Step 2: the wrapper `S734M.app` went to the Trash with
> `/usr/bin/trash`; `test-make-engine-install.sh` exit 0 from the kept copy, 14 cases; `setup.sh` exit 0 with
> both closing lines, 14unch3r built with its icon; T2 21 of 21 and `_vendor` equal; `make-app.sh` exit 0, no
> hint since 14unch3r is beside it; `make-steam-shortcut.sh` exit 0, `S734M.app` built and `CS2 Steam Store.app`
> removed. `~/Applications` holds the four apps and three wrappers of this project; `--list` there gives two
> games and one Steam app, all `ready`; Spotlight's record of each app carries its other names. Step 3 passed,
> by James (Spotlight, 2026-11-10); step 4 was replaced by live step L2 of `docs/plans/launcher-window-look.md`,
> passed the same day. Steps 5 to 8 are still to come. `65c799c` B1 (the game builders), `01e783e` B4 (the Steam app, the engine source, the
> inventory), `667f727` B2 and `34d1c21` B5 (the window and the offers, built in parallel on a second branch and
> merged as `598459c`), `66b6847` B3 and B6 (the window's builder, setup's call, the icon), `158f347` W8, and the
> documents commit after them. Every listed mutant was applied and exited 1, 98 in all: W1 to W3, W7 and W9 in
> `test-launcher-window.sh` (114 cases, mutants 1 to 30), `test-make-shortcut.sh` (48, 14), `test-make-app.sh`
> (47, 16), `test-make-steam-shortcut.sh` (27, 8), `test-engine-source.sh` (10, 3), `test-mac-inventory.sh` (62,
> 10), `test-setup.sh` (61, 8), `test-make-launcher-app.sh` (25, 7), `test-launcher-builders.sh` (6, 2); parity,
> progress, feedback, lock, links and identifiers pass. Deviations: (1) two of W2's cases could not make their
> mutants fail, since there is no process 7 and process 1 is outside 2 to 99999: `+<a live pid>` and a live
> process of another user stand in. (2) `--list` drops a duplicate app by its resolved path, and folders are not
> merged, or W1's mutant 7 could never fail. (3) The offers are asked of their children all at once: one after
> another, two games take 10 s against W7's 7. (4) An AppKit alert button cannot answer both Return and Escape,
> so a key monitor maps Escape to "Don't Start". (5) W8 is its own file, `common/test-launcher-builders.sh`, so
> that the window test's 30 mutants need no builder. (6) The Steam builder tests its target before it would
> clone a store wrapper, and all four of its options now need a value: a bare `--name` looped for ever. (7) The
> inventory says when a listed app is still a wrapper, as the Studio's `S734M.app` is until live step 2. (8) After
> live step 2, at James's word: one click on a row starts it and the button is gone, and Return still starts the
> selected row; the list's height is read from the table, which pads it 10 points above and below and 20 above
> each later heading, so two games and Steam no longer scroll. Found
> while building and not yet in the design: once the Trash is emptied, `wine.d3dm21-BAK` in `SurvivingMars.app`
> is the only copy of that Wine, and the rollback of
> `surviving-mars-relaunched/docs/plans/one-wrapper-per-game.md` renames it back to `wine`, after which the two
> tools stop with a clear error; and between the merge and live step 2, `build-engine-1116.sh` step 7 refuses,
> without stopping the build, to replace the wrapper of that name. Verify against: `common/launcher-window.swift`,
> `common/make-launcher-app.sh`, `common/games.tsv`, the three builders, `cities-skylines-2/scripts/setup.sh`.

## 0. What James asked for (2026-11-10)

| # | His words | What this plan does with it |
|---|---|---|
| J1 | "pop up a small window that has a collection of the apps that can be run. And then you just select the one you want." | One app, `14unch3r.app`, whose window lists the games and starts the one chosen |
| J2 | "could the 1launcher inventory ported games in steam and only show shortcuts for games the user has licenses for?" | Rows are the games set up on this Mac. Games the account owns and this project ports, but that are not set up, are offered below them. Nothing unowned is shown (2.5) |
| J3 | "should the 1launcher window just be aliases to the games stored in applications so the spotlight could find them there also?" | Yes. Each game keeps its own small app in Applications, and that app is the game's entry in the window (2.1) |
| J4 | "can the steam app label somehow note that it is the WINE/windows steam? should it call it S734M?" | The Steam app is named `S734M`, says what it is in the window, and answers to "steam" in Spotlight (2.4, D5) |
| J5 | "I still like 14unch3r even though you liked 1launcher better." | The app, its window and its icon are named 14unch3r. The repository and its folders keep `1launcher` (D4) |
| J6 | "let's plan for the above and check the plan after" | This document, then `check it` |
| J7 | "2) S734M", and "1&3 will go with for now" | D5 is decided as plain `S734M`; D1 and D8 stand for now |
| J8 | "1) ok", and of the Studio's wrapper: "why keep it? if we have move past it, trash it, if it still serves a purpose keep it" | D10 is decided. D11: nothing still needs that wrapper, so it goes to the Trash (section 1, 2.4) |

## 1. What is true today (measured on the Studio, 2026-11-10, unless a date says otherwise)

**The apps**

- **Seven bundles of this project sit in `~/Applications` for two games.** Two per-game apps
  (`Cities Skylines II.app`, `Surviving Mars Relaunched.app`), `CS2 Steam Store.app`, and four Wine wrappers
  (`CS2dxmt11.app`, `CS2dxmt11-pk110.app`, `S734M.app`, `SurvivingMars.app`). Valve's own `Steam.app` is in
  `/Applications`, and macOS has its own `/System/Applications/Games.app`.
- **A per-game app is a generated shim.** `cities-skylines-2/scripts/make-shortcut.sh` and
  `surviving-mars-relaunched/make-app.sh` each write a bash executable `Contents/MacOS/launch`, an
  `Info.plist` (`make-shortcut.sh:185-200`, `make-app.sh:109-125`), an icon taken from the game's own exe, and
  the Phase A progress window. The shim writes a `=====` line, starts the progress window, and runs the
  launcher, and it lives as long as the launcher does.
- **The Steam app opens a third wrapper.** `cities-skylines-2/scripts/make-steam-shortcut.sh` builds
  `CS2 Steam Store.app` (`:30`), whose shim starts `steam.exe` in `CS2dxmt11-pk110.app` (`:31`) and exits.
  It has no test. Its two start lines must never be wrapped in `nohup`, `env` or `bash -c`: macOS strips
  `DYLD_*` and Steam then draws no text (`:119-124`, `:130-135`).
- **Every builder removes whatever is at its target, unseen.** `rm -rf "$APP"` at `make-shortcut.sh:71`,
  `make-app.sh:22` and `make-steam-shortcut.sh:86`, where `$APP` comes from `--name`, `--dest` or `SM_APP`.
  `--name CS2dxmt11` would delete a wrapper today.
- **A generated shim says so near its top.** The two game apps carry `# Generated by scripts/make-shortcut.sh`
  and `# Generated by surviving-mars-relaunched/make-app.sh` on line 2. The Studio's `CS2 Steam Store.app`
  carries `# Generated by scripts/make-steam-shortcut.sh` on line 5, after three lines added by hand on
  2026-08-30. None of the three has a `Contents/SharedSupport`; every wrapper has one.
- **An app's name goes into its plist unescaped** (`make-shortcut.sh:190`, `make-steam-shortcut.sh:171-172`):
  a name holding `&` gives a plist that does not parse, with exit 0.
- **`S734M.app` is a wrapper.** On the Studio it is 101 G by `du`, last used on 2026-11-07, and nothing
  reads it when a game runs. It is the default source of three Surviving Mars tools
  (`tools/make-engine.sh:48`, `tools/split-wrapper.sh:23`, `tools/test-make-engine-install.sh:11`), the
  first two with an override, and `surviving-mars-relaunched/README.md:50` names it. Six registry lines in
  its prefix name its own path, all of them font entries; the clone `SurvivingMars.app` has the same six
  with its own path, so Wine rewrites them on a start. No symlink in any wrapper points into it. Nothing
  in it is the only copy any more: its Wine is in `SurvivingMars.app` as `wine.d3dm21-BAK`, 4789 files
  and none differing; its Surviving Mars saves are all in that wrapper too; its second install of Cities:
  Skylines II is on the build the play wrapper has; and the two autosaves of 2026-08-22 that were in its
  prefix alone were copied to the evidence store on 2026-11-10, each file compared equal. The MacBook's
  copy went to the Trash on 2026-11-10 (`docs/plans/local-files-layout.md`, O8).

**Locks and Steam sessions**

- **One lock per wrapper, none across games.** Each launcher holds `<prefix>/.launcher.lock`, a symlink
  whose target is its own process number, from its start until it exits
  (`cities-skylines-2/launchers/launch-cs2-dxmt11.sh:200-219`, `surviving-mars-relaunched/launch-relaunched.sh:168-187`).
  It exits after the game has closed, Steam has shut down and, for Surviving Mars, the saves have uploaded.
  A launcher that finds the lock held counts the holder dead when `kill -0` fails for any reason, a
  refusal included (`launch-cs2-dxmt11.sh:207`), and then waits up to 180 s for a live one.
- **Two Steam sessions of one account swap, and the displaced game's cloud save is lost to the cloud.**
  `cities-skylines-2/GOTCHAS.md`, "Same-account Steam sessions SWAP, they don't stack" (2026-08-24, and its
  2026-11-01 addition): a second sign-in takes the session; the first Steam goes offline and stays so until
  its game exits; a running game keeps running; and Surviving Mars's exit upload then fails, so that
  session's saves stay on the Mac. Its launcher says so when the game closes
  (`launch-relaunched.sh:399-400`), and its header says never to run two Steams on one account (`:15-16`).
  A game started while the store wrapper's Steam is open puts that Steam into offline mode, which harms
  nothing.

**Steam's files**

- **Installed games are certain.** A wrapper's Steam has `steamapps/appmanifest_<appid>.acf` per installed
  game: 949230 for Cities: Skylines II, 3215050 for Surviving Mars: Relaunched.
- **Owned games are readable from Steam's own cache.**
  `<prefix>/drive_c/Program Files (x86)/Steam/appcache/packageinfo.vdf` is in all four wrappers. A 30-line
  parser read two of them to their last byte: each ported game is listed by exactly one package, and app
  730, which the account has never added, is not listed. So the file is the account's packages and not all
  of Steam's. Layout as read, every number little-endian: a 32-bit magic `0x06565528` and a 32-bit
  universe; then per package a 32-bit id, 20 bytes, a 32-bit change number and an 8-byte token; then one
  tree, `00 "<package id>" 00 … 08 08`, whose node types were 0 (nested: a zero-ended name, then children
  up to an 8), 1 (name, zero-ended string), 2 (name, 32-bit integer), 7 (name, 64-bit integer) and 8 (end);
  the list ends with id `0xFFFFFFFF`, and nothing follows it. A package's app ids are the integer children
  of the `appids` node directly under its root. `config/licensecache` is in none of the four.

**macOS**

- **Spotlight honours alternate names for an app of ours.** A throwaway unsigned app with
  `CFBundleAlternateNames` got them as `kMDItemAlternateNames`, and a plain `mdfind` for a whole word of
  one of them, the second word included, returned the app. What Spotlight shows while a word is half
  typed was not measured. Apple's System Settings uses the same key for "System Preferences".
- **`plutil -replace <key> -string|-integer|-json` writes a key into an XML plist in place**, creates it
  when missing, and escapes `&`, `<` and `"`. It rewrites the whole file, so a test reads a key with
  `plutil -extract`, never with `grep`. `plutil -insert` fails on a key that exists.
- **Starting an app from another program.** `/usr/bin/open <app>` and `NSWorkspace.shared.open(url)` both
  return at once, and the app starts even if the caller exits straight after. For a bundle with no
  executable `open` exits 1 with a sentence on its error output. While an app whose executable is a script
  is still alive, a second plain open starts nothing; `open -n` starts a second copy.
  `NSWorkspace.openApplication(at:configuration:completionHandler:)` does not fit: for a script app its
  handler ran when the script ended, 14 s later in the measurement, and a caller that exits before the
  handler starts nothing.
- **Preferences.** An unsigned, unsandboxed bundled program reads and writes `UserDefaults.standard` at
  `~/Library/Preferences/<bundle id>.plist`. Inside the bundle, `UserDefaults(suiteName:)` given the app's
  own identifier is nil. `defaults delete` leaves an empty file behind.
- **Reading a plist number.** A Swift `as? Int` accepts `<true/>` as 1 and `<real>5</real>` as 5.
- **`kill(pid, 0)`**: 0 for a live process of this user; -1 with "no such process" for a dead number; -1
  with "not permitted" for process 1 and for another user's process.
- **`NSHomeDirectory()` ignores `$HOME`.** The house test style sets `HOME` to a scratch folder.
- **Colours.** The system's secondary label colour on a window background measures 3.95 to 1 in light mode
  and 5.89 to 1 in dark; the label colour measures 14.94 and 12.23. Text at 11 points needs 4.5.
- **Drawing.** A program with no window draws a 1024-pixel PNG with AppKit in 0.03 s, and `sips` and
  `iconutil` accept it. An image drawn with `lockFocus` at 1024 points is 2048 pixels on this screen.
- **`mv` of a bundle onto an existing bundle** exits 0 and puts it inside (`X.app/X.app`).
- **`swiftc -O`** compiled a 257-line skeleton of 2.2's text modes in 1.3 s, and the bundle it sits in
  starts through `open` with no signing step.

## 2. Design

### 2.1 Each game's app is its entry: three keys and its other names, in its `Info.plist`

There is no registry file. The window finds the games by reading the apps in the folders of 2.2, so
deleting an app removes its row. An app kept in some other folder is in Spotlight and not in the window.

| Key | Type | Value | Written by |
|---|---|---|---|
| `L1Role` | string | `game`, or `steam` for the Steam app | all three builders |
| `L1SteamAppID` | integer | 949230 or 3215050 | the two game builders |
| `L1Prefix` | string | the Wine prefix the app's game or Steam lives in | all three, when it is there |
| `CFBundleAlternateNames` | array of strings | other names Spotlight should answer to | all three, and the window's own builder |

- **The game's key is its Steam app id** (D3). It is Valve's number, not a name, and never changes. The
  title on a row is a label.
- **`L1Prefix`** is the text of the game path up to and including the first `/Contents/SharedSupport/prefix`
  that is followed by `/`. `make-shortcut.sh` cuts it from `GAME_EXE` (`:57`), which `setup.sh:207-208`
  passes as `--game`; `make-app.sh` from its `GAME_EXE` (`:17`), which gains an override, `SM_GAME_EXE`,
  beside `SM_APP` and `SM_SCRIPT` (`:12`); `make-steam-shortcut.sh` writes `$SS/prefix` (`:45`). The key is
  written only when the path is absolute and that folder exists. It records what the builder was told: a
  launcher steered by `CS2_WRAPPER` or `SM_WRAPPER` uses another prefix, and then a row's state is wrong
  and its start is not.
- **How a plist is written.** The heredoc keeps the constants: `L1Role`, `L1SteamAppID`, the alternate
  names. Everything that comes from an argument or a path is written after it with
  `plutil -replace <key> -string`: `CFBundleName` and `CFBundleDisplayName` where they hold `--name`, and
  `L1Prefix`. Then `plutil -lint`. If any of those calls fails the builder prints
  `ERROR: <file> is not a valid property list; the app was not built`, removes the bundle it was building
  and exits 1; in `make-app.sh`, which runs under `set -eu`, each call is the condition of an `if`.
- **A name is checked before anything is removed.** `--name` must not be empty, hold `/` or a control
  character, or start with `.` or `-`; otherwise the builder says so and exits 2.
- **A builder replaces only its own bundle.** Before its `rm -rf`, each builder tests the target. Absent
  is fine. Otherwise all of these must hold, or it prints
  `ERROR: <path> exists and was not built by this script; nothing removed` and exits 1: the target is a
  folder and not a symlink; it has no `Contents/SharedSupport`; `Contents/MacOS/launch` is a plain file
  and not a symlink; one of that file's first ten lines begins `# Generated by <the builder's path as it
  writes it>`; and the plist's `CFBundleIdentifier` is that builder's own. The bundle identifiers do not
  change (`local.cs2.dxmt11.launcher`, `local.sm-patch.relaunched.launcher`, `local.cs2.steamstore`):
  macOS keeps its consent records by them, and this test relies on them. The marker lines do not change
  either. A trailing slash is taken off the target before the test. A build that was interrupted leaves a
  bundle its builder then refuses, so the error has a second line: `If it is a leftover of this script,
  move it to the Trash and run this again.`
- **Left as it is:** the game shims' `SCRIPT=` and `GAME_EXE=` lines (`make-app.sh:28-29`, and the same
  line of the `make-shortcut.sh` shim) still go through an unquoted heredoc. They hold paths that setup or
  the builder made, `test-setup.sh:80` and `common/mac-inventory.sh:129` read that line as it is, and
  quoting it belongs with the shims' move into shared code.
- **Alternate names.** Cities: Skylines II: `CS2`, `Cities Skylines 2`, `Cities: Skylines II`. Surviving
  Mars: `Surviving Mars`, `Surviving Mars: Relaunched`, `SMR`. The Steam app and the window: 2.4 and 2.3.

### 2.2 The window: `common/launcher-window.swift`

One Swift file, compiled by `swiftc` alone as the progress window is. Every mode but the window prints
and returns before any window object is made, and the window calls the same functions.

| Mode | Prints |
|---|---|
| `[--games <tsv>] [<folder>...]` | nothing: this is the window. With no folder it uses the two folders below. Without `--games` it uses `Contents/Resources/games.tsv` of its own bundle, and no table when run bare |
| `--list [--games <tsv>] <folder>...` | one line per row: role, app id or `-`, state, title, path, tab-separated. No headings. With `--games` it asks about ownership through the same child call as the window (2.5); without it there are no offers |
| `--default <last app id or -> <folder>...` | the path column of the row selected when the window opens, or nothing |
| `--second <app path> <folder>...` | `go`, or `ask`, a tab and the title of the game in use |
| `--start <app path> [new]` | `started`, or `failed`, a tab and the system's sentence; exit 0 or 1 |
| `--owned <app id> <packageinfo.vdf>...` | `owned`, `not-owned` or `unknown` |
| `--folders` | the folders the window would use, one per line |
| `--icon <out.png>` | nothing; writes the icon of 2.6 |

A mode given no folder where one is needed, or any other wrong use, prints a usage line and exits 2.

**The folders** are `~/Applications`, with `$HOME` when it is set and the account's home otherwise, and
the folder that holds the window's own app when the program runs from inside a bundle. `/Applications` is
not read: no builder writes there by default, and it is where other software installs. Two arguments that
are the same folder count once.

**A row** is a direct child of a folder whose name ends `.app` in any letter case, that is a folder and
not a symlink, and whose `Contents/Info.plist` is a plain file of at most 1,048,576 bytes that parses, in
either plist form, and has `L1Role` equal to `game` or `steam`. A `game` row also needs `L1SteamAppID`
stored as a whole number, not a boolean and not a real, from 1 to 2147483647. `L1Prefix` counts only when
it is absolute and ends `/Contents/SharedSupport/prefix`; otherwise the row has none. Anything else is
passed over without a word. Rows are told apart by their resolved path, so one app reached twice is one
row and two apps for one game are two rows.

The list is not a boundary of trust. Whoever can put an app into `~/Applications` can also edit the
unsigned shims that are already there, and a start goes through LaunchServices as a double-click does.

**Title and order.** The title is `CFBundleDisplayName`, else `CFBundleName`, else the file name without
`.app`; a tab or a line break in it becomes a space. Rows with the same title also show their file name.
Games come first, then Steam apps, then offers (2.5), each group by title without regard to case and then
by path, under the headings "Games", "Steam" and "You also own".

**A row's state**, from files alone, with no process matching. The paths are
`<L1Prefix>/.launcher.lock`, `<L1Prefix>/drive_c/Program Files (x86)/Steam/steamapps/appmanifest_<appid>.acf`
and, for a Steam app, `<L1Prefix>/drive_c/Program Files (x86)/Steam/steam.exe`.

| State | When | The row's second line |
|---|---|---|
| `busy` | a `game` row whose lock is a symlink, whose target is digits only and a number from 2 to 99999, and for which `kill(pid, 0)` returns 0 | "In use: starting, running or closing" |
| `absent` | not busy, there is a prefix, and the manifest (for a Steam app: `steam.exe`) is not there | "Game files not found. See its set-up guide." For a Steam app: "Windows Steam not found. Build this app again." |
| `ready` | not busy, there is a prefix, and that file is there | nothing. For a Steam app: "Steam for Windows, run under Wine" |
| `unknown` | there is no prefix | nothing |

A game now reads "Not installed in Steam. See its set-up guide." at `absent` (`docs/plans/launcher-window-look.md`, 2.4).

- "Alive" is the launchers' own rule, a `kill` that succeeds. A number that now belongs to another
  user's process is not alive to either.
- A Steam app is never `busy`: nothing locks the store wrapper.
- Known and left: a lock that is a plain file, or names 0, reads `ready` here while a launcher would wait
  180 s on it and stop; and a dead launcher's number taken by a new process of this user reads `busy`
  until a launcher next clears it; and a row that reads `ready` while its shim is still alive, as when its
  failure alert is still up, is opened plainly, which starts nothing. Each costs one question, one wait or
  one more click.
- States are read when the window opens, each time it becomes the active app, and again just before a
  start. A state is advice: every row can be started in every state.

**The selected row** when the window opens is the game whose app id was recorded last, if it is listed
(by path order if two apps share it), else the first game, else the first row of any kind, else none.

**Starting a row.** The window runs `/usr/bin/open <path>`, with the path as an argument and no shell,
which is what a double-click does, and waits for it to return. For a `busy` row it runs `/usr/bin/open -n
<path>`, because a plain open of an app that is still alive starts nothing: the second copy of the shim
then does what it was written to do, bring the game forward or say it is running
(`make-shortcut.sh:93-100`, `make-app.sh:45-48`), or, when the game has gone and its launcher is still
closing, wait for the lock and start the game again. On exit 0 the window records the app id, for a
`game` row only, and quits. Otherwise it stays and shows `open`'s sentence in an alert. It never runs a
shim or a launcher itself (D1): the app keeps its own process tree, environment, consent records and
progress window.

**The record** is one integer, `lastAppID`, in `UserDefaults.standard`, which for this app is
`~/Library/Preferences/local.1launcher.window.plist` (D10). No test reads or writes it: `--default`
takes the id as an argument, and live step 5 shows the record working.

**One game at a time** (D6). When the chosen row is a game or a Steam app, and a `game` row with a
different prefix is `busy`, the window asks first, naming the first such row by title:

> **<busy game> is still in use.**
> Starting <chosen> now takes <busy game>'s Steam offline. <busy game> can keep running, but saves it has
> not uploaded yet stay on this Mac and do not reach Steam Cloud.
> [ Don't Start ] [ Start Anyway ]

"Don't Start" is the default button, Escape means it, and it leaves everything as it is. A row with the
busy row's own prefix is never asked about, and neither is an offer. This guards the window only: a start
from Spotlight or Finder is not asked, and a game started while the Windows Steam is open is not asked
either, which costs nothing (section 1).

**What it looks like.** Superseded 2026-11-10 by `docs/plans/launcher-window-look.md`, sections 2.1 to 2.4 and
2.7: tiles, a dark window, fixed colours. What follows is the table window as first built.

- A titled, closable window, 420 points wide, centred, title "14unch3r", accessibility title "14unch3r
  game launcher". Opening the app while it is open brings this window forward.
- A table with one column and no header. Rows are 52 points high: the app's own icon at 32 points, the
  title in the system font at 13 points semibold, and the second line at 11 points regular in the label
  colour, not the secondary one. Headings are group rows and cannot be selected.
- No button (James, after live step 2). One click on a row starts it; a click on a heading or below the
  last row does nothing. Return starts the selected row. Escape and the close button quit, except in the
  question. The window is as tall as its list, up to a point, so a short list never scrolls.
- A regular app with a Dock icon while open, and a one-item menu so that Command-Q works.
- Every colour is a system colour, so light and dark follow the system. A state is always words. Nothing
  animates. The question and a failed start are alerts attached to the window.
- For VoiceOver each row has one label, "<title>, <second line>", or the title alone; the icon is not an
  element of its own; an offer's label ends "opens the set-up guide in your browser".
- With no row at all it shows "No games are set up on this Mac yet." and the address of the repository's
  README. An app built before this plan has no keys and is not listed until its builder has run again.

### 2.3 The window's app and its builder: `common/make-launcher-app.sh`

`bash common/make-launcher-app.sh [--dest <folder>] [--name <name>]` builds `14unch3r.app`, by default in
`~/Applications`. `--name` is checked as in 2.1 and names the file, `CFBundleName` and
`CFBundleDisplayName`.

- **What it builds.** `Contents/MacOS/launcher-window` from the source; `Contents/Resources/games.tsv`
  copied from `common/games.tsv`, without which the app is built with no offers and the builder says so;
  the copy is as old as the last build, and a pull alone does not renew it;
  the icon (2.6, from B6 on); and an `Info.plist` with `CFBundleName` and `CFBundleDisplayName` `14unch3r`,
  `CFBundleIdentifier` `local.1launcher.window`, `CFBundleExecutable` `launcher-window`,
  `CFBundlePackageType` `APPL`, `CFBundleVersion` `1.0`, `LSMinimumSystemVersion` `13.0`,
  `NSHighResolutionCapable`, and `CFBundleAlternateNames` `1launcher`, `launcher`, `game launcher`.
- **It replaces only its own app.** The target must be absent, or a folder that is not a symlink, has no
  `Contents/SharedSupport`, and whose `CFBundleIdentifier` is `local.1launcher.window`; else it prints the
  error line of 2.1 and exits 1.
- **It never leaves a half-built app.** It builds in `mktemp -d "$DEST/.14unch3r-build.XXXXXX"`, removed
  by an `EXIT` trap. To swap, it moves the old bundle into that folder, moves the new one into place, and
  puts the old one back if that second move fails. It never moves a bundle onto a bundle.
- **Exit 3 means skipped:** `swiftc` or the source is missing, or the compile failed. It says which,
  builds nothing and leaves an older app as it was. The per-game apps do not need the window.
- **`cities-skylines-2/scripts/setup.sh` runs it** after the game's app was built (`:207-211`), and only
  then. On exit 0 setup adds nothing. On any other exit it prints `window: not built (see the line above)`
  and does not count it as a problem. When `common/make-launcher-app.sh` is not in the checkout it prints
  `window: not built (common/make-launcher-app.sh is not in this checkout)`.
- **`surviving-mars-relaunched/make-app.sh` does not run it.** When no `14unch3r.app` is beside the app it
  built, its last line says to run `bash common/make-launcher-app.sh`.
  `surviving-mars-relaunched/README.md` gains that step.

### 2.4 The Steam app is `S734M`

`make-steam-shortcut.sh` changes as follows, and gains its first test (W4).

1. **Its default name** (`:30`) becomes `S734M` (D5, decided). Alternate names: `Windows Steam`,
   `Steam Store`, `CS2 Steam Store`. Plain `Steam` is not one: it is Valve's app's own name. The row in the
   window reads "S734M" and, under it, "Steam for Windows, run under Wine".
2. **It replaces only its own bundle**, by the test of 2.1 with `scripts/make-steam-shortcut.sh` and
   `local.cs2.steamstore`. This is what keeps a wrapper named `S734M.app` from being deleted. When the
   target fails the test and has a `Contents/SharedSupport`, the error adds: `A Wine wrapper of that name
   is in this folder. Move or remove it (see surviving-mars-relaunched/README.md), or build under another
   name with --name.`
3. **Its `Info.plist`** (`:166-181`) gains `L1Role` `steam` and `L1Prefix`, and its name keys are written
   by `plutil` (2.1).
4. **Its texts** (`:99`, `:126`, `:137`) name the app by the name it was built with and say "Windows
   Steam" where they said "storefront wrapper". Between the shim's two heredocs the builder writes
   `printf 'TITLE=%q\n' "$APPNAME"`, and `WRAPPER=` (`:93`) the same way, so that no character of a name or
   a path is ever run. Each `osascript` call passes its text and `"$TITLE"` as arguments in the `on run`
   form of the launchers' `launch-feedback` block (`launch-cs2-dxmt11.sh:55-58`). The two `wine64` lines
   (`:125`, `:136`) do not change.
5. **The old bundle.** After the new app has passed `plutil -lint` and `bash -n`,
   `$DEST/CS2 Steam Store.app` is removed if it is not the app just built (`-ef`, since the volume ignores
   letter case) and passes the test of item 2. The builder says that it removed it, and that a Dock entry
   for the old app must be dragged out by hand.
6. **Its header, `--help` range (`:40`) and closing lines (`:184-187`)**, and the two lines of
   `cities-skylines-2/scripts/build-engine-1116.sh` that name the app (`:227`, `:242`), follow the name.

**The wrapper named `S734M.app`.** The name is free on the MacBook. On the Studio the wrapper goes to the
Trash first, in live step 2 (D11): section 1 shows that nothing in it is the only copy. Two tools took
their Wine from it and take the kept copy once it is gone: `tools/make-engine.sh:48` and
`tools/test-make-engine-install.sh:11` use `~/Applications/S734M.app/Contents/SharedSupport/wine` when that
folder exists and `~/Applications/SurvivingMars.app/Contents/SharedSupport/wine.d3dm21-BAK` otherwise;
`ENGINE_SRC` still overrides the first. `tools/split-wrapper.sh` does not change: it makes the Surviving
Mars wrapper from a donor, and a Mac that has that wrapper has no more use for one. `README.md:50` says
that a donor may have any name and place, given as `SPLIT_DONOR`, that it can be removed once the split is
done, and that `S734M.app` in `~/Applications` is now the Steam app's name. `common/mac-inventory.sh`
lists the new app names (`:127`); gives `14unch3r.app` a line of its own, since that app has no shim to
read (`:128`); and counts a bundle in its wrapper loop only when it has `Contents/SharedSupport`
(`:133-136`), so that the app `S734M.app` is not reported as a wrapper.

What the Steam app opens does not change here: the store wrapper's Steam. Opening a game's own Steam is
Phase C, which will rework this builder again.

### 2.5 What the account owns but this Mac has not set up

`common/games.tsv` lists every game this repository ports: app id, folder, title and the address of its
set-up guide, tab-separated, one line per game, `#` lines ignored. Two lines today, created in B2.

For each line whose app id has no `game` row, the window asks whether the account owns it.

- **Which files.** `<L1Prefix>/drive_c/Program Files (x86)/Steam/appcache/packageinfo.vdf` of every row
  that has a prefix, and no other path. Each must be a plain file, not a symlink, of at most 16,777,216
  bytes as read from the opened file.
- **The reader** follows the layout of section 1. The low byte of the magic decides the record header:
  `0x27` has no token, `0x28` has the 8-byte token; the other three bytes must be `0x065655`. Every number
  is put together from bytes, little-endian and unsigned, and every read is checked against the end of
  the file. A name or string is read up to its zero, within the file and within 256 bytes for a name.
  Node types 0, 1, 2, 7 and 8 are read, the package's root node counting as depth 1 and depth 8 as the
  deepest allowed. Any other type, any read past the end, a deeper nesting, a missing end mark, or a byte
  after the end mark makes the whole file `unknown`.
- **`owned`**: a cleanly read file lists the id as an integer child of an `appids` node directly under a
  package's root. The same number under `depotids`, or deeper, does not count. **`not-owned`**: at least
  one file read cleanly and none lists it; a clean file with no package at all is one of those.
  **`unknown`**: no file read cleanly.
- **Neither the window nor `--list` reads these files in its own process.** Each runs the program named
  by `L1_OWNED_HELPER`, by default its own executable, with `--owned`, once per offered game, as a child
  with a 5 s limit; the window does so once it is on screen. A child that crashes or runs out of time is
  `unknown`. So no file can stop the window or hold up its list.
- **Only `owned` adds a row**, under "You also own": the title, the line "Not set up on this Mac. Opens
  the set-up guide.", and a start that runs `/usr/bin/open <address>`, which opens it in the browser, and leaves the window
  open. Its
  `--list` line has role `offer`, the id, state `owned`, the title, and the address in the path column.
  An address that does not start `https://github.com/` drops the row.
- **A game that is set up is never hidden** (D7). A shared library or a second account can make a game
  playable without its package being in this file, and Steam decides the licence at launch.
- The window sends nothing anywhere. No test fixture is copied or cut from a real `packageinfo.vdf`: the
  tests write their own. A Mac with no game set up has no prefix to read and so shows no offer.

### 2.6 The icon

Superseded 2026-11-10 by `docs/plans/launcher-window-look.md`, 2.5 and 2.6: the icon carries the mark, and one
SVG of it is in `docs/images/`.

`launcher-window --icon <out.png>` draws into a bitmap of exactly 1024 by 1024 pixels: a rounded square
824 pixels wide, centred, corner radius 185, in a dark neutral grey that is lighter at its top edge, and
the characters "14" in white in the system's bold rounded font. The builder turns it into an `.icns` with
`sips` and `iconutil`, as the game builders do. No image file is added to the repository (D8). If any
step fails the app keeps the generic icon, has no `CFBundleIconFile`, and the builder says so.

## 3. Phases

Built in this order on a branch in a scratch worktree, merged with `--no-ff` in live step 1, as Phase A
was. A step is done when the tests named for it in section 4 exit 0, every mutant of those rows has been
seen red and restored, and every suite that passed before still passes.

| Step | What | Files |
|---|---|---|
| B1 | The game builders: keys, alternate names, names and prefix through `plutil`, the name check, the own-bundle test, `SM_GAME_EXE` | `cities-skylines-2/scripts/make-shortcut.sh`, `surviving-mars-relaunched/make-app.sh`, their two tests |
| B2 | The window without offers: folders, rows, states, order, the selected row, the question's rule, starting a row; the table of games | `common/launcher-window.swift`, `common/games.tsv`, `common/test-launcher-window.sh` |
| B3 | The window's builder, without the icon; `setup.sh` running it; `make-app.sh`'s last line | `common/make-launcher-app.sh`, `common/test-make-launcher-app.sh`, `cities-skylines-2/scripts/setup.sh`, `cities-skylines-2/scripts/test-setup.sh`, `surviving-mars-relaunched/make-app.sh` and its test |
| B4 | The Steam app; the engine builder's two lines; where two Surviving Mars tools take their Wine from; the inventory's lists | `cities-skylines-2/scripts/make-steam-shortcut.sh`, `cities-skylines-2/scripts/test-make-steam-shortcut.sh`, `cities-skylines-2/scripts/build-engine-1116.sh`, `surviving-mars-relaunched/tools/make-engine.sh`, `tools/test-make-engine-install.sh` and a new `tools/test-engine-source.sh`, `common/mac-inventory.sh` and its test |
| B5 | The offers: the reader, the child process, the third heading, the address rule | `common/launcher-window.swift`, `common/test-launcher-window.sh` |
| B6 | The icon | `common/launcher-window.swift`, `common/make-launcher-app.sh`, `common/test-make-launcher-app.sh` |
| B7 | Documents: the root `README.md`; the root `CLAUDE.md` (the `common/` row, the in-progress line, and the sentence on places outside the repo, which gains the generated apps in `~/Applications` and the preferences file, each with its reason); both games' READMEs; `cities-skylines-2/INSTALL.md`, `CLAUDE.md` and `PLAN.md` where they name the store app; `cities-skylines-2/scripts/README.md`; the comment at `surviving-mars-relaunched/launch-relaunched.sh:14`; the as-built header here | those |

`docs/plans/local-files-layout.md`, not yet built, also edits `make-shortcut.sh` and `setup.sh` (its step 1.4)
and counts every spelling of the old install folder's name in the repo (its LT12). So no new file of this
plan spells that name, and whichever of the two plans is built second re-reads its line references first.

`launch-relaunched.sh:14` is the one launcher line this plan touches, and it is a comment. No launcher
code changes, the marked blocks that `common/test-launcher-parity.sh` compares are untouched, and nothing
is deployed by it: Surviving Mars runs its launcher from the checkout.

## 4. Test plan

Fixtures are apps made in a scratch folder: an `Info.plist`, and where a state needs it a fake prefix. No
game, no Steam, no Wine, no window, and never a real Steam file. A test that needs `swiftc` exits 2
without it, which is not a pass. Each mutant is one changed line in a copy of the source, and a mutant
that does not apply exits 2.

| # | Step | Test | Cases | Mutants, each seen red |
|---|---|---|---|---|
| W1 | B2 | `common/test-launcher-window.sh`: `--list`, `--folders` | A `game` app is listed with its id, title and path. Not listed: no `L1Role`; another role; an id that is missing, 0, negative, text, `<true/>` or a real; a plist that does not parse; a plist over 1,048,576 bytes that is otherwise a valid `game` plist; a symlink named `*.app`. `.APP` is listed. A binary plist is listed. The title falls back from display name to bundle name to file name; a tab in it becomes a space. Two apps with one title each show their file name. Order: games, then Steam apps, each by title without case and then by path, with a fixture whose path order differs from its title order. One app reached through `/tmp` and `/private/tmp` is one row. A relative `L1Prefix`, and one not ending in the prefix segment, give `unknown`. `--folders` with `HOME` set prints that folder's `Applications` and nothing else when run bare | the role test dropped; a text id accepted; a boolean id accepted; the title from the file name first; order by path; the size limit dropped; rows told apart by the path as given |
| W2 | B2 | same file: states | `busy` for a lock naming a live process, and for a lock taken by the real `acquire_lock` copied out of a launcher as `common/test-launch-lock.sh` copies it. `ready` for a lock naming a dead number, process 1, 0, `+7`, text, and for a lock that is a plain file. `absent` without the manifest; `ready` with it; `unknown` without a prefix; a busy row without a manifest is `busy`. A Steam app is `ready` with `steam.exe`, `absent` without it, and never `busy` | a refused `kill` read as alive; the manifest test dropped; `absent` winning over `busy`; `+7` read as 7; a Steam app read as busy |
| W3 | B2 | same file: `--default`, `--second` | The selected row is the last game when listed, even `absent` or `busy`; else the first game; else the first Steam app; nothing with no row; a last id that is not a number counts as none; with two apps for the last id, the first by path. `--second`: `go` when nothing is busy; `go` for the busy row and for another app with the same prefix; `ask` and the busy title for a game with another prefix and for a Steam app; with two busy games, the first by title; `go` for a path that is no row | the last id ignored; a row with the busy prefix asked; the Steam app not asked; the second busy title given |
| W9 | B2 | same file: `--start` | Around a fixture app marked `LSUIElement` whose shim appends its process number to a file and sleeps 30 s: `--start` prints `started`, exits 0, and the number is there within 10 s. With that process shown alive by `kill -0` just before each: a plain `--start` adds no number, and one with `new` adds a second. A bundle with no executable: `failed` and a sentence, exit 1. The path is one argument: an app in a folder named with a space and a `;` starts. The recorded processes are stopped at exit. Where `open` cannot start the fixture at all, as it may not over ssh, the test exits 2 | `-n` passed always; `-n` never passed; exit 0 on a failed open; the path passed through a shell |
| W5 | B1 | `cities-skylines-2/scripts/test-make-shortcut.sh`, `surviving-mars-relaunched/tools/test-make-app.sh`: added cases, every key read with `plutil -extract` | Each built plist holds `L1Role` `game`, its own app id as an integer, its three alternate names, and passes `plutil -lint`. `L1Prefix` is the fixture wrapper's prefix when that folder exists; it is left out when the folder is missing, when the game path has no prefix segment, and for `…/prefix-old/…`; a prefix holding `&` survives. Built with `SM_GAME_EXE` in a scratch folder, the Surviving Mars app never records a real path. `make-shortcut.sh --name` with `"`, `&`, `$(touch x)` and a backtick: the plist holds that exact name and no file `x` appears; an empty name, one with `/`, one starting `-` or `.`, and one holding a control character exit 2 with the old app untouched. With a stub `plutil` that fails, each builder prints the error line of 2.1, leaves no bundle and exits 1. A target given with a trailing slash is tested as the bundle it names. The target is refused, exit 1 and untouched, when it is a wrapper-shaped bundle, a bundle with another identifier, one whose marker is past line 10, a symlink to a bundle, or one whose shim is a symlink; a bundle built by the same builder is replaced | the other game's id; the name written into the heredoc; the role dropped; the own-bundle test dropped; the name check after the removal; `SM_GAME_EXE` ignored; a failed `plutil` ignored |
| W6 | B3, icon cases B6 | `common/test-make-launcher-app.sh` | B3: the app is built into a scratch folder with its plist keys, three alternate names and the copied `games.tsv`; `--folders` run from inside the bundle with a scratch `HOME` prints that folder's `Applications` and the bundle's own folder, and one line when the two are the same; `--list` given the bundle's folder prints the fixture rows beside it. An empty name, one holding `/` and one starting `-` exit 2 with nothing changed. Built over an older app of its own: one bundle, no bundle inside it, no build folder left. Without `swiftc`, with no source, and with a source that does not compile: exit 3, the reason said, an older app byte-identical, nothing left behind. A target that is a wrapper-shaped bundle or has another identifier: exit 1, untouched. Without `common/games.tsv`: built, and said. B6: the icon file is in the bundle, its source PNG is 1024 pixels wide by `sips -g pixelWidth`, and the plist names it; with a stub `iconutil` that fails, the app is built, has no `CFBundleIconFile`, and says so | the build written straight into the target; the new bundle moved onto the old; a skipped build exiting 0; the own-app test dropped; the own folder not added; the name check after the swap; B6: `CFBundleIconFile` written when the icon failed |
| W10 | B3 | `cities-skylines-2/scripts/test-setup.sh`: added cases, with a recording stub at `common/make-launcher-app.sh` beside its scratch repo, where `setup.sh` looks (`$REPO/../common`) | The stub is run once, after the game's app. With the stub exiting 1, and exiting 3: setup exits 0, prints `=== setup complete ===`, counts no problem, and its line about the window has no `!!`. With no `common/` at all: the same, with the line of 2.3. When `make-shortcut.sh` failed, the stub is not run and the problem counts stay as `:155-157` expect | the call dropped; its failure counted as a problem; the call made when the game's app was not built |
| W11 | B3 | `surviving-mars-relaunched/tools/test-make-app.sh`: added cases | The last line names `common/make-launcher-app.sh` when no `14unch3r.app` is beside the built app, and is not printed when one is | the line always printed |
| W4 | B4 | `cities-skylines-2/scripts/test-make-steam-shortcut.sh`, new. Every call passes a fixture `--wrapper`, whose `wine64` is a stub printing a version, and a `--from` that does not exist | The app is built as `S734M.app` by default and under `--name`. Its plist holds the role, the prefix, the three alternate names, the name written by `plutil`, and lints. The shim passes `bash -n`, and its two `wine64` lines are byte-for-byte those of the source. With the fixture's `steam.exe` deleted and a recording `osascript` first on `PATH`, the shim exits 1 before either `wine64` line and records one alert whose title argument is exactly a name holding an apostrophe, `"`, `$(touch x)` and `&`, and no file `x` appears. A wrapper-shaped `S734M.app` at the target: exit 1, the extra sentence of 2.4, the bundle byte-identical. An old `CS2 Steam Store.app` with the marker on line 5, as the Studio's has it: removed and said; one with another identifier, and one with no marker: left and said. Built as `--name "cs2 steam store"`: the app just built is still there. An empty name, one holding `/` and one starting `-` exit 2 with nothing removed | the own-bundle test dropped; the old bundle removed without the test; the `-ef` test dropped; the title written into the heredoc; the title put into AppleScript source; `nohup` added to a start line; the role dropped; the name check after the removal |
| W12 | B4 | `surviving-mars-relaunched/tools/test-engine-source.sh`, new, and `common/test-mac-inventory.sh`: added cases | With a scratch `HOME` and fixture bundles that hold no Wine: `make-engine.sh`, run plain, names in its `ERROR: no Wine engine at` line (`:57`) the `wine` folder of a wrapper-shaped `S734M.app` when that is there; the kept copy in `SurvivingMars.app` when `S734M.app` is a shim app, and when it is absent; and `ENGINE_SRC` when that is set. `test-make-engine-install.sh` names the same choice in its `REFUSED` line (`:12`). The inventory reports a shim `S734M.app` as an app and not as a wrapper, and `14unch3r.app` on a line of its own | the kept copy not looked at; `ENGINE_SRC` ignored; `S734M` left in the inventory's wrapper list |
| W7 | B5 | `common/test-launcher-window.sh`: `--owned`, offers. Files written by the test from fixed bytes, in both header forms | An id under a root's `appids` is `owned`; the same number only under `depotids`, and under an `appids` one level deeper, is `not-owned`; a valid file with no package is `not-owned`. `unknown`: a truncated file, a fixed block of noise, another magic, a node type 3, a nesting of 9, no end mark, a byte after the end mark, a valid owning file padded inside a string node past 16,777,216 bytes, a symlink to a valid file, and no file. A nesting of 8 is read. Several files: one bad and one owning is `owned`; one bad and one clean without the id is `not-owned`. A loop of 200 single-byte changes to a valid file from a fixed seed: every answer is one of the three words with exit 0. With `--games`: an owned ported game with no app is an `offer` line in the form of 2.5; a not-owned or unknown one is not; one that has an app is never; a `file:` address and an `http:` one drop the row; offers come after Steam apps. With `L1_OWNED_HELPER` naming a script that sleeps 8 s, `--list --games` prints its rows within 7 s and no offer; with one that exits 1 without a word, no offer | the `appids` name test dropped; `depotids` counted; a failed read answered `not-owned`; the token always read; the size limit dropped; only the first file read; an offer for a game that has an app; a `file:` address accepted; the time limit dropped; the files read in the list's own process |
| W8 | B5 | same file: the builders together | Both game apps and the Steam app, built by their own builders into one scratch folder with fixture paths, come out of `--list` as two games and one Steam app, and each game's id and title equal its line in `common/games.tsv` | a game's line removed from `games.tsv`; `L1Role` renamed in one builder |

Only a person sees the following, in the live steps named: that the window quits after a start and
stays after a failure (4); both buttons of the question (4, 6); the record being written and read (5);
the Steam row (7); an offer's click (4); states read again when the window comes forward and before a
start (4); a row in use getting a second copy of its app (6); the icon in the Dock; Command-Q; VoiceOver.

## 5. Live steps, each on James's word

Records of these steps carry counts and verdict words only, never a `--list` line, which holds a home
path. Captures go to the evidence store and are not committed; one that is needs its row in
`cities-skylines-2/docs/images/AUDIT.md`.

0. **Before the merge, the reader on real files.** On the Studio, the built `launcher-window --owned 949230`
   and `--owned 730`, given the real `packageinfo.vdf` of each wrapper, print `owned` and `not-owned`.
1. **Merge, on the Studio, with no launcher running.** The check of live step 1 of
   `docs/plans/launch-experience.md` prints nothing; then `git merge --no-ff`, and push.
2. **Free the name, then build.** With no `wineserver` running, that check extended to its prefix, and
   nothing of its name in `~/.Trash`, the wrapper `~/Applications/S734M.app` is moved to the Trash (2.4,
   D11). It can be put back until the Trash is emptied, and emptying it is James's.
   `bash surviving-mars-relaunched/tools/test-make-engine-install.sh` then exits 0 on the Studio, from the
   kept copy. It starts an Intel program from a clone of that copy, which macOS may hold for some minutes
   while it verifies it (`cities-skylines-2/GOTCHAS.md:2597-2600`). Then
   `bash scripts/setup.sh` from `cities-skylines-2/`, which now builds the window too; T2 of
   `docs/plans/1launcher-unification.md`; `bash surviving-mars-relaunched/make-app.sh`;
   `bash cities-skylines-2/scripts/make-steam-shortcut.sh`. `~/Applications` then holds `14unch3r.app`, the
   two game apps and `S734M.app`, the app, and no `CS2 Steam Store.app`.
   `~/Applications/14unch3r.app/Contents/MacOS/launcher-window --list ~/Applications` gives two games and
   one Steam app.
3. **Spotlight, by James.** For `launcher`, `14`, `steam`, `s734m`, `cs2` and `mars`, the app meant is in
   the list and can be told from the others by its name. What appears while a word is half typed is
   noted. Before that, `mdls -name kMDItemAlternateNames` on each of the four.
4. **A rehearsal on stand-in apps.** Replaced by live step L2 of `docs/plans/launcher-window-look.md`. The window is opened on a scratch folder of fixture apps: one whose
   lock names a live `sleep`, one whose shim writes a file, one with no executable, one `absent`, and a
   table with a test-made `packageinfo.vdf` in one fixture's prefix, which together make an offer. Captured in light and in dark, the window's own region only: the list with
   every kind of second line, the offer, the question, the failed-start alert, and the empty window of an
   empty folder. "Don't Start" writes no file; "Start Anyway" writes it and the window quits; the failed
   start keeps the window. A lock made from Terminal while the window is open shows on its row once the
   window is clicked again, and Return on another row then asks. The text of every capture measures at least 4.5 to 1 against its background,
   and "14" can be read at 16 pixels. James moves through it with the arrow keys, Return and Escape, and
   once with VoiceOver on.
5. **Each game started from the window, by James.** The window closes, the game's progress window
   appears, the game starts. After Surviving Mars was the last one started, the window opens with it
   selected, and Return starts it.
6. **One at a time, on the real games.** With one game running its row says so. Choosing the other asks;
   "Don't Start" leaves both as they were. Choosing the running game's own row brings it forward or says
   it is running; what happened is written down. "Start Anyway" is not pressed here.
7. **The Steam row** opens the Windows Steam.
8. **The MacBook.** The check of step 1, `git pull`, the builds of step 2 without the move, and steps 3
   and 5. The Steam app is built there only if that Mac has a store wrapper: without one the builder
   would clone the play wrapper to make it (`make-steam-shortcut.sh:49-70`). An app there that its builder
   refuses as not its own is moved to the Trash by hand and built again.
   `tools/test-make-engine-install.sh` is run there too: it passes if that Mac's Surviving Mars wrapper has
   the kept copy and exits 2 if not, and which is written down.

No launcher code changes, so no boot check is owed; step 5 starts each rebuilt app once.

## 6. Exit criteria

- W1 to W12 exit 0, with every mutant seen red and restored. An exit 2 does not count.
- Every suite that passed before still exits 0: `test-make-shortcut.sh`, `test-make-app.sh`,
  `test-setup.sh`, `test-split-wrapper.sh`, `common/test-mac-inventory.sh`, `common/test-launcher-parity.sh`,
  `common/test-launch-progress.sh`, `common/test-launch-feedback.sh`, `common/test-launch-lock.sh`,
  `python3 common/check-links.py`, and
  `ACCEPT=9 bash common/check-identifiers.sh`.
- Live steps 0 to 7 pass on the Studio and step 8 on the MacBook.
- The design gate: step 4's captures show every string readable in light and in dark at the measured
  ratio; every state is words; the keyboard reaches everything; VoiceOver reads a row's title and state.
- The as-built header here is written, and issue #22 has a line once James allows the post.

## 7. Rollback

`git revert -m 1` of the merge of live step 1; then, after the check of that step, `bash scripts/setup.sh`
and `bash surviving-mars-relaunched/make-app.sh` on each Mac, and
`bash cities-skylines-2/scripts/make-steam-shortcut.sh` only on a Mac that has a store wrapper, where it
rebuilds `CS2 Steam Store.app`. By hand: `14unch3r.app` and the app `S734M.app` to the Trash, their Dock
entries dragged out, `defaults delete local.1launcher.window` and the empty file it leaves in
`~/Library/Preferences` removed. The Studio's wrapper can be put back from the Trash, once the app of that
name has left the folder, until the Trash is emptied; after that there is no way back for it, and by
section 1 this plan needs none. No launcher code, game file, save or setting is touched by this plan.

## 8. Not in this plan

- **A guard in the launchers** against starting a second game from Spotlight or Finder. It changes the
  shared lock code of both launchers. What it would prevent is measured (section 1).
- **Moving the play wrappers out of `~/Applications`.** After this plan that folder holds, on the Studio,
  seven of this project's bundles as before: one wrapper leaves and `14unch3r.app` arrives. Three are
  still wrappers. `docs/plans/local-files-layout.md`, section 7, counts about 50 tracked files that name a
  wrapper path.
- **Phases C and D, and what D1 and D2 mean for them.** The outline has "a button in the window" open a
  game's own Steam and has "the window" check for a release before it starts a launcher. With the games
  started from Spotlight too, and a window that starts no launcher, both belong in what every start
  passes through: each app's shim, or a step the shims share. The window can offer the same action, and
  cannot be the only door to it.
- **One setup for every ported game the account owns.** It needs Phase C: ownership can be read only after
  a sign-in in some wrapper.
- **The window turning into the progress window** (D1), and **renaming the repository or its folders**.

## 9. Decisions (James)

| # | Question | Recommendation, or what was decided |
|---|---|---|
| D1 | Does the window run the game itself and turn into the progress window, as the outline said? | **Stands for now (2026-11-10: "will go with for now").** No: it opens the game's own app and quits, and that app shows the Phase A progress window. One start path serves Finder, Spotlight, the Dock and the window. The cost: the list closes and the progress window appears a moment later at the top right |
| D2 | Do the per-game apps stay? The outline said the window replaces them, with shortcuts "off by default" | They stay, by J3, and they are the entries |
| D3 | What is a game's key? | Its Steam app id. A minted id of our own would be a second key to keep in step, and every game here is a Steam game. To be looked at again when a game without one arrives |
| D4 | The name | `14unch3r` on the app, the window and the icon. `1launcher` stays the name of the repository, its folders and its paths: links, clones and four plans are built from it, and it was renamed on 2026-11-09. Typing "launcher" finds the app by its alternate names |
| D5 | The Steam app's name | **Decided 2026-11-10: `S734M`.** It needs the own-bundle test of 2.1 and D11 |
| D6 | A second game while one is in use | Ask, with "Don't Start" as the default. Not refuse. What it costs is known: the game in use keeps running and its saves of that session stay off Steam Cloud, which its launcher reports when it closes |
| D7 | Can the ownership file hide a game that is set up? | Never. It only adds offers |
| D8 | The icon | **Stands for now (2026-11-10).** Drawn by the builder, "14" on a dark rounded square, until James supplies art. See D12 and D19 of `docs/plans/launcher-window-look.md` |
| D9 | Is B5, the offers, built now? | Yes, last. It is what J2 asked for beyond what the rows already give, and it cannot block or delay a launch. It will show nothing on James's two Macs, and it is the one part that reads a file format of Valve's, which is why live step 0 runs it on real files before the merge |
| D10 | Two new places outside the repo, which `CLAUDE.md` asks James's word for | **Decided 2026-11-10: "ok".** `~/Applications/14unch3r.app`, a generated app beside the two that are there, and `~/Library/Preferences/local.1launcher.window.plist`, one number, where macOS keeps every app's preferences. B7 writes both into `CLAUDE.md` |
| D11 | The Studio's wrapper `S734M.app`, whose name the Steam app now takes | **Decided 2026-11-10, by James's rule:** "if we have move past it, trash it, if it still serves a purpose keep it". Measured the same day (section 1): nothing reads it when a game runs, its Wine is kept byte for byte in the Surviving Mars wrapper, and the two saves found only in it are copied out. So it goes to the Trash in live step 2, and the two tools that took their Wine from it take the kept copy |

## Review corrections (pass 1, 2026-11-10)

Four lenses on Fable 5.2, each a fresh agent, against `87f46c3`: correctness; architecture and security;
builder simulation and platform facts, which built the plan in a scratch copy; tests and design. All four
said build-ready-with-fixes. Two blockers, both cheap, and what else changed the design:

| # | Finding | Lens | Where it is folded |
|---|---|---|---|
| B1 | Tests were tied to no step, and three needed a later step's work | tests, architecture, correctness | Section 4's Step column; `games.tsv` made in B2; the icon cases in B6 |
| B2 | A preferences file and a new app outside the repo, with no decision and no `CLAUDE.md` line | architecture | D10, B7, section 7 |
| S1 | "Not measured: a Surviving Mars exit upload when its Steam was displaced" was false: measured 2026-11-01 | correctness | Section 1; the question's text; D6; section 8 |
| S2 | `rm -rf` on a path built from `--name`; `--name S734M` would delete a wrapper | architecture, and James's D5 the same hour | The own-bundle test of 2.1, 2.3, 2.4; W4, W5, W6 |
| S3 | The marker rule "holds the line" would never match, and the Studio's old Steam app has it on line 5 | correctness, builder; line 5 measured in the fold | 2.1 "one of its first ten lines begins"; W4 |
| S4 | A name was run as code from the unquoted heredoc, and broke the plist | architecture, builder | `printf %q`, `plutil -replace`, the name check; W4, W5 |
| S5 | "Records and quits on success" rested on a call whose handler runs when a script app ends | builder; measured further in the fold | `/usr/bin/open`, `-n` for a busy row; W9; section 1 |
| S6 | "Alive" was unspecified, and the usual reading disagrees with the launchers | correctness, architecture | 2.2's state table; W2, with the launchers' own `acquire_lock` |
| S7 | The reader was specified loosely and tested only on files of its own making; a crash would kill the window | architecture, builder, tests | 2.5; the child process; W7; live step 0 |
| S8 | `make-app.sh` could not be given a game path, so a test would record a real one | all four | `SM_GAME_EXE` |
| S9 | `setup.sh`'s new call had no test, and the test's scratch repo has no `common/` | correctness, tests, builder | 2.3; W10 |
| S10 | Section 4 asserted rules section 2 never stated: symlinks, the title's fall-back, one row per app, an offer's line | correctness, tests | 2.2, 2.5 |
| S11 | The second line of a row measured 3.95 to 1 in light mode; "Play" was wrong for two kinds of row; "Wait" could read as "wait, then start"; VoiceOver had nothing specified | tests and design | 2.2 |
| S12 | "Start anyway is not exercised" left the question's buttons untested before real games | tests and design | Live step 4, on stand-in apps |
| S13 | Files that go stale and were not listed: `common/mac-inventory.sh`, `build-engine-1116.sh`, a launcher comment, the builder's own header | correctness, tests | B4, B7 |
| S14 | Rollback ran the Steam builder on a Mac with no store wrapper, where it clones one | architecture | Section 7, live step 8 |
| S15 | D1 and D2 move where Phases C and D must live | architecture | Section 8 |
| S16 | `games` is the name of an Apple app; a bare `Steam` could outrank Valve's | tests and design | 2.3, 2.4 |
| S17 | `/Applications` is where other software installs | architecture | 2.2's folders |

Not taken: the heading "Owned, not set up" in place of "You also own", since the row's own line says it
is not set up. Declined as unneeded: a marker or identifier test before a row is listed, since the list
is not a boundary of trust (2.2). Removed in the fold: two counts of the account's Steam library that the
draft gave in section 1.

### Fold check (pass 1b, 2026-11-10)

One fresh agent on Fable 5.2 against `19a266f`. It typed the own-bundle test for bash 3.2 and ran it on 17
fixtures and, reading only, on the three real apps, which pass, and on the wrapper `S734M.app`, which
fails; it built the Steam shim with ten hostile names; it measured `open` again; and it found every cited
line right. Verdict: build-ready-with-fixes, no design change. Folded:

| # | Finding | Where it is folded |
|---|---|---|
| F1 | Blocker: W4's "no line holds `nohup`" is red on a correct build, since the shim's own comments name it | W4: the case is gone; the byte-for-byte case and its mutant stay |
| F2 | W9's 3 s fixture ended before the cases that need it alive, and one first start took 3.09 s | W9: 30 s, a wait of up to 10 s, `kill -0` before each case |
| F3 | The child process and its limit had no case, and `--list --games` did not say how it asks | 2.2, 2.5 (`L1_OWNED_HELPER`), W7 |
| F4 | Two of the three donor edits were never run by any test | W12 in a new test file; live step 2 runs the engine-install test. Both were reworked when D11 was decided: the note below |
| F5 | The inventory would report the app `S734M.app` as a wrapper and `14unch3r.app` as absent | 2.4, W12 |
| F6 | "No file inside it names its own path" was false: the count came from a command that zsh never ran | Section 1 |
| F7 | The name check was tested in one builder of three | W4, W6 |
| F8 | The window's own folder had no case, and W6's `--list` wording gave no folder | W6 |
| F9 | Reading states again had no test and no step | Live step 4; section 4's last paragraph |
| F10 | Smaller: the move's `mkdir`, volume and destination checks; the marker lines frozen; an interrupted build; a trailing slash; setup's line per exit code; how an address is opened; where the table comes from; the `plutil` failure case; `test-launch-feedback.sh` in section 6; the Steam row's second line read as a status | 2.1, 2.2, 2.3, 2.5, W5, W10, live steps 2, 4 and 8, section 6 |

Left as it is, and said in 2.1: the game shims' `SCRIPT=` and `GAME_EXE=` lines.

### After the check: D10 and D11 decided (2026-11-10)

James agreed to D10 and gave D11 a rule, and the measurements now in section 1 settled it as the Trash.
That replaced a planned move of the wrapper to a folder under `~/Library/Developer` and took that move's
consequences out again: no new folder, no edit to `split-wrapper.sh`, and W12 tests where two tools take
their Wine from. The change is in section 1, 2.4's last paragraph and item 2, B4, B7, W12, live steps 2
and 8, section 7 and D11. The planner made it after pass 1b and read it against
`tools/make-engine.sh:28-49` and `tools/test-make-engine-install.sh:1-40`. No agent has reviewed it.

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-10 | 1 | correctness; architecture and security; builder simulation and platform facts; tests and design | four fresh agents, the third building in a scratch copy; findings spot-checked and three measured further in the fold | Fable 5.2 | `87f46c3` | build-ready-with-fixes from all four; folded |
| 2026-11-10 | 1b | the fold: every correction against the normative text, every cited line, the own-bundle test and the shim's quoting run for real | one fresh agent; its blocker spot-checked | Fable 5.2 | `19a266f` | build-ready-with-fixes, no design change; folded |

Key paths: `common/launch-progress.swift`, `cities-skylines-2/scripts/make-shortcut.sh`,
`cities-skylines-2/scripts/make-steam-shortcut.sh`, `cities-skylines-2/scripts/setup.sh`,
`cities-skylines-2/scripts/build-engine-1116.sh`, `surviving-mars-relaunched/make-app.sh`,
`surviving-mars-relaunched/tools/make-engine.sh`, `surviving-mars-relaunched/tools/split-wrapper.sh`,
`common/mac-inventory.sh`, the lock block of both launchers, `docs/plans/launch-experience.md`.
