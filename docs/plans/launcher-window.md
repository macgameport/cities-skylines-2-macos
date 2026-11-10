# 14unch3r: one window that lists the games

> **Status:** Draft, not yet checked. Run `check it` before any build.
> Written 2026-11-10. Tracking: issue #22. This is Phase B of `docs/plans/launch-experience.md`, the second
> slice of Phase 5 of `docs/plans/1launcher-unification.md`. It replaces the Phase B paragraph of that
> outline where the two differ (section 9 says where). File and line references are as of `509bc56`.
> A path is relative to the repository root.

## 0. What James asked for (2026-11-10)

| # | His words | What this plan does with it |
|---|---|---|
| J1 | "pop up a small window that has a collection of the apps that can be run. And then you just select the one you want." | One app, `14unch3r.app`, whose window lists the games and starts the one chosen |
| J2 | "could the 1launcher inventory ported games in steam and only show shortcuts for games the user has licenses for?" | Rows are the games set up on this Mac. Games the account owns and this project ports, but that are not set up, are offered below them. Nothing unowned is shown (3.5) |
| J3 | "should the 1launcher window just be aliases to the games stored in applications so the spotlight could find them there also?" | Yes. Each game keeps its own small app in Applications, and that app is the game's entry in the window (3.1) |
| J4 | "can the steam app label somehow note that it is the WINE/windows steam? should it call it S734M?" | The Steam app is named for what it is and found by typing "steam" (3.4, D5) |
| J5 | "I still like 14unch3r even though you liked 1launcher better." | The app, its window and its icon are named 14unch3r. The repository and its folders keep `1launcher` (D4) |
| J6 | "let's plan for the above and check the plan after" | This document, then `check it` |

## 1. What is true today (measured on the Studio, 2026-11-10)

- **Seven bundles of this project sit in `~/Applications` for two games.** Two per-game apps
  (`Cities Skylines II.app`, `Surviving Mars Relaunched.app`), `CS2 Steam Store.app`, and four Wine wrappers
  (`CS2dxmt11.app`, `CS2dxmt11-pk110.app`, `S734M.app`, `SurvivingMars.app`). Valve's own `Steam.app` is in
  `/Applications`.
- **A per-game app is a generated shim.** `cities-skylines-2/scripts/make-shortcut.sh` and
  `surviving-mars-relaunched/make-app.sh` each write a bash executable `Contents/MacOS/launch`, an
  `Info.plist` (`make-shortcut.sh:185-200`, `make-app.sh:109-125`), an icon taken from the game's own exe, and
  the Phase A progress window. The shim writes a `=====` line, starts the progress window, and runs the
  launcher. This path has been started by hand on both Macs for both games (the as-built header of
  `docs/plans/launch-experience.md`).
- **The Steam app opens a third wrapper.** `cities-skylines-2/scripts/make-steam-shortcut.sh` builds
  `CS2 Steam Store.app` (`:31`), whose shim starts `steam.exe` in `CS2dxmt11-pk110.app` (`:32`) and exits.
  It has no test. Its shim must never be wrapped in `nohup`, `env` or `bash -c`: macOS strips `DYLD_*` and
  Steam then draws no text (`:119-124`, `:130-135`).
- **`S734M.app` is a wrapper, and it is still in use.** `surviving-mars-relaunched/tools/make-engine.sh:48`
  and `tools/split-wrapper.sh:23` read it. So no other bundle in that folder can be called `S734M.app`.
- **One lock per wrapper, none across games.** Each launcher holds `<prefix>/.launcher.lock`, a symlink
  whose target is its own process number, from its start until it exits
  (`cities-skylines-2/launchers/launch-cs2-dxmt11.sh:200-219`, `surviving-mars-relaunched/launch-relaunched.sh:168-185`).
  It exits after the game has closed, Steam has shut down and, for Surviving Mars, the saves have uploaded.
- **Two Steam sessions of one account swap.** `cities-skylines-2/GOTCHAS.md`, "Same-account Steam sessions
  SWAP, they don't stack" (2026-08-24): a second sign-in takes the session, the first Steam goes offline
  and does not reconnect, and a running Cities: Skylines II keeps running. Not measured: what a Surviving
  Mars exit upload does when its Steam was displaced.
- **Installed games are certain.** Each wrapper's Steam has `steamapps/appmanifest_<appid>.acf` per
  installed game: 949230 for Cities: Skylines II, 3215050 for Surviving Mars: Relaunched.
- **Owned games are readable from Steam's own cache.** `<prefix>/drive_c/Program Files (x86)/Steam/appcache/packageinfo.vdf`
  exists in every wrapper that has signed in. A 30-line parser read the Studio's two copies to their last
  byte: 150 packages, 573 distinct app ids, each ported game listed by exactly one package, and app 730,
  which the account has never added, not listed. So the file is the account's packages and not all of
  Steam's. Layout as read: a 32-bit magic `0x06565528` and a 32-bit universe; then per package a 32-bit id,
  20 bytes, a 32-bit change number and an 8-byte token; then one binary key-value tree whose node types
  were 0 (nested), 1 (string), 2 (32-bit integer), 7 (64-bit integer) and 8 (end); the list ends with id
  `0xFFFFFFFF`. A package's app ids are the integer children of its `appids` node. `config/licensecache`
  is absent in all three wrappers.
- **Spotlight honours alternate names for an app of ours.** A throwaway unsigned app with
  `CFBundleAlternateNames` in its `Info.plist` got them as `kMDItemAlternateNames`, and a plain `mdfind` for
  one of those names returned the app. Apple's System Settings uses the same key for "System Preferences".
- **`plutil -insert` writes a key into an XML plist in place** and escapes `&` and `<` in a string value;
  `-integer` and `-json` values work too. The plist stays XML and passes `plutil -lint`.

## 2. Design

### 2.1 Each game's app is its entry: three keys in its `Info.plist`

There is no registry file. The window finds the games by reading the apps, so the window, Finder and
Spotlight can never disagree about what is installed, and deleting an app removes its row.

| Key | Type | Value | Written by |
|---|---|---|---|
| `L1Role` | string | `game`, or `steam` for the Steam app | all three builders |
| `L1SteamAppID` | integer | 949230 or 3215050 | the two game builders |
| `L1Prefix` | string | the Wine prefix the app's game or Steam lives in | all three, when known |
| `CFBundleAlternateNames` | array of strings | other names Spotlight should answer to | all three, and the window's own builder |

- **The game's key is its Steam app id** (D3). It is Valve's number, not a name, and never changes. It is
  also what the two Steam files are looked up by. The title on a row is `CFBundleDisplayName`, a label.
- **`L1Prefix`.** `make-shortcut.sh` takes it from `GAME_EXE` (`:57`): the text up to and including
  `/Contents/SharedSupport/prefix` when the path holds that, else the key is left out. `make-app.sh` does
  the same with its `GAME_EXE` (`:17`). `make-steam-shortcut.sh` writes `$SS/prefix` (`:45`).
- **How the keys are written.** `L1Role`, `L1SteamAppID` and the alternate names are constants and go into
  the heredoc as XML. `L1Prefix` is a path, so it is added after the heredoc with
  `plutil -insert L1Prefix -string "$prefix" "$APP/Contents/Info.plist"`, which escapes it. Each builder
  ends with `plutil -lint` on the file; `make-app.sh:126` has that line already.
- **Alternate names.** Cities: Skylines II: `CS2`, `Cities Skylines 2`, `Cities: Skylines II`. Surviving
  Mars: `Surviving Mars`, `Surviving Mars: Relaunched`, `SMR`. The Steam app and the window: 2.4 and 2.3.
- **Bundle identifiers do not change** (`local.cs2.dxmt11.launcher`, `local.sm-patch.relaunched.launcher`,
  `local.cs2.steamstore`). macOS keys its consent records and Dock entries by them.

### 2.2 The window: `common/launcher-window.swift`

One Swift file, compiled by `swiftc` alone as the progress window is. Run with no argument it is the
window. Every other mode prints and returns before any window object is made, and the window calls the
same functions.

| Mode | Prints |
|---|---|
| `--list [--games <tsv>] <folder>...` | one line per row: role, app id or `-`, state, title, path, tab-separated |
| `--default <last app id or -> <folder>...` | the path of the row Return would start, or nothing |
| `--second <app path> <folder>...` | `go`, or `ask` and the title of the game that is in use |
| `--owned <app id> <packageinfo.vdf>...` | `owned`, `not-owned` or `unknown` |
| `--icon <out.png>` | nothing; writes the icon of 2.6 |

**Finding rows.** The folders are `~/Applications`, `/Applications` and the folder that holds the window's
own app, each once. In each, every direct child named `*.app` whose `Contents/Info.plist` is at most 1 MB,
parses, and has `L1Role` equal to `game` or `steam` is a row. A `game` row also needs `L1SteamAppID`, an
integer from 1 to 2147483647. Anything else is not a row and is passed over without a word: the wrappers,
Valve's Steam and every other app have no `L1Role`.

**A row's state**, from files alone, with no process matching:

| State | When | What the row says |
|---|---|---|
| `busy` | `<L1Prefix>/.launcher.lock` is a symlink to a process number above 1 that is alive | "Running, or still closing" |
| `absent` | not busy, `L1Prefix` is set, and the game's `appmanifest_<appid>.acf` (for `steam`: `steam.exe`) is not there | "Not installed in its wrapper. Run that game's setup again." |
| `ready` | not busy, `L1Prefix` is set, and that file is there | nothing |
| `unknown` | there is no `L1Prefix` | nothing |

A state is advice. Every row can be started in every state, and the game's own app and launcher decide
what happens, as they do when it is started from Finder.

**Order.** Games by title, then Steam apps by title, then offers (2.5) by title, under the headings
"Games", "Steam" and "You also own".

**Starting a row.** The window asks LaunchServices to open the row's app
(`NSWorkspace.shared.openApplication(at:configuration:)`), exactly what a double-click in Finder does. On
success it records the game's app id as the last one played and quits. On failure it stays and shows the
system's error text. It never runs a shim or a launcher itself (D1): the app keeps its own process tree,
its own environment, its own consent records and its own progress window, and one start path is tested
instead of two.

**The last game.** The row selected when the window opens is the game whose app id was recorded last, if
it is listed, else the first game. Return starts the selected row; so do a double-click and the Play
button. The record is one integer in the window's own preferences domain, `local.1launcher.window`.

**One game at a time** (D6). When the chosen row is not the busy one and some game row is busy, the window
asks first:

> **<busy game> is still running or closing.**
> Starting <chosen> now signs <busy game> out of Steam. It keeps running, but its saves may not reach
> Steam Cloud. Wait until it has closed, or start anyway.
> [ Wait ] [ Start anyway ]

"Wait" is the default button and leaves everything as it is. Choosing the busy row itself asks nothing:
its own app brings the game forward or says it is running (`make-shortcut.sh:93-100`, `make-app.sh:45-48`).
This guards the window only. A start from Spotlight or Finder is not asked; a guard in the launchers is
section 8's first item.

**What it looks like.** A titled, closable window, 420 points wide, title "14unch3r", centred. A table
with one column and no header: rows 52 points high with the app's own icon at 32 points, the title in the
system font at 13 points semibold and the state line at 11 points in the secondary label colour; heading
rows as group rows. A "Play" button at the bottom right, the default button. Escape and the close button
quit. It is a regular app with a Dock icon while open, and a one-item menu so that Command-Q works. All
colours are the system's label and background colours, so light and dark follow the system. A state is
always words, never colour alone. Nothing animates. With no row at all it shows "No games are set up on
this Mac yet." and the address of the repository's README.

### 2.3 The window's app and its builder: `common/make-launcher-app.sh`

`bash common/make-launcher-app.sh [--dest <folder>] [--name <name>]` builds `14unch3r.app`, by default in
`~/Applications`.

- It compiles the source into `Contents/MacOS/launcher-window`, copies `common/games.tsv` (2.5) into
  `Contents/Resources/`, draws the icon (2.6), and writes an `Info.plist`: `CFBundleName` and
  `CFBundleDisplayName` `14unch3r`, `CFBundleIdentifier` `local.1launcher.window`,
  `CFBundleAlternateNames` `1launcher`, `launcher`, `game launcher`, `games`.
- It builds into a scratch folder beside the target and swaps the finished bundle in, so a failed compile
  leaves an older window app as it was.
- When `swiftc` or the source is missing, or the compile fails, it says which, builds nothing and exits 0.
  The per-game apps do not need the window.
- `cities-skylines-2/scripts/setup.sh` runs it after the game's app is built (`:207-211`). A failure there
  is said and is not counted as a setup problem. `surviving-mars-relaunched/make-app.sh` does not run it:
  its last lines say to run `bash common/make-launcher-app.sh` when no `14unch3r.app` is beside the app it
  built. `surviving-mars-relaunched/README.md` gains the same step.

### 2.4 The Steam app is named for what it is

`make-steam-shortcut.sh` changes in four ways, and gains its first test (W4).

1. **Its default name** (`:31`) becomes `S734M Windows Steam` (D5). The file name itself holds "Steam" and
   "Windows", so Spotlight and Finder need no help to find or explain it, and it cannot be taken for
   Valve's `Steam.app`. Alternate names: `Steam`, `Windows Steam`, `Steam Store`, `CS2 Steam Store`.
2. **Its `Info.plist`** (`:166-181`) gains `L1Role` `steam` and `L1Prefix`.
3. **Its texts** (`:99` and the two notifications below it) name the app by the name it was built with.
   The shim's first heredoc gains `TITLE="$APPNAME"`, and each `osascript` call passes its text as an
   argument in the `on run` form of the launchers' `launch-feedback` block, never as AppleScript source.
4. **The old bundle.** After a build under a new name, `$DEST/CS2 Steam Store.app` is removed if, and only
   if, its `Contents/MacOS/launch` holds the line `Generated by scripts/make-steam-shortcut.sh`. The
   builder says that it removed it, and that a Dock entry for the old app must be dragged out by hand.

What the app opens does not change here: the store wrapper's Steam. Opening a game's own Steam is Phase C.

### 2.5 What the account owns but this Mac has not set up

`common/games.tsv` lists every game this repository ports: app id, folder, title and the address of its
set-up guide, tab-separated, one line per game, `#` lines ignored. Two lines today.

For each line whose app id has no `game` row, the window asks whether the account owns it:

- **The reader** takes every `packageinfo.vdf` under the `L1Prefix` of every row and parses it by the
  layout of section 1. The low byte of the magic decides the record header: `0x27` has no token, `0x28` has
  the 8-byte token; the other three bytes must be `0x065655`. Node types 0, 1, 2, 7 and 8 are read; any
  other type, a read past the end, a nesting deeper than 8, a file over 16 MB, or a list that does not end
  with `0xFFFFFFFF` makes the whole file `unknown`.
- **`owned`** means one cleanly parsed file lists the id under some package's `appids`. A depot id of the
  same number does not count. **`not-owned`** means at least one file parsed cleanly and none lists it.
  **`unknown`** means no file parsed: no sign-in yet, or a format this reader does not know.
- **Only `owned` adds a row**, under "You also own": the title, the line "This project runs it. Open the
  set-up guide.", and a start action that opens the guide's address in the browser. `not-owned` and
  `unknown` add nothing.
- **A game that is set up is never hidden** (D7). A shared library or a second account can make a game
  playable without its package being in this file, and Steam decides the licence at launch.
- The window reads these files and sends nothing anywhere. It opens an address only when the player
  chooses that row.

### 2.6 The icon

`launcher-window --icon <out.png>` draws a 1024-point square: a rounded rectangle in a dark neutral grey
and the characters "14" in white, in the system's bold rounded font. The builder turns it into an `.icns`
with `sips` and `iconutil`, as the game builders do with a game's icon. No image file is added to the
repository (D8). If any step fails the app keeps the generic icon and the builder says so.

## 3. Phases

Built in this order, each ending with its tests green and every mutant of its rows seen red and restored.

| Step | What | Files |
|---|---|---|
| B1 | The three keys and the alternate names in the two game builders; `plutil -lint` in `make-shortcut.sh` | `cities-skylines-2/scripts/make-shortcut.sh`, `surviving-mars-relaunched/make-app.sh`, and their tests |
| B2 | The window: finding rows, states, order, the last game, the question, starting a row | `common/launcher-window.swift`, `common/test-launcher-window.sh` |
| B3 | The window's builder, and `setup.sh` running it; `make-app.sh`'s closing hint | `common/make-launcher-app.sh`, `common/test-make-launcher-app.sh`, `cities-skylines-2/scripts/setup.sh`, `surviving-mars-relaunched/make-app.sh` |
| B4 | The Steam app: name, keys, texts, the old bundle | `cities-skylines-2/scripts/make-steam-shortcut.sh`, `cities-skylines-2/scripts/test-make-steam-shortcut.sh` |
| B5 | The offers: `common/games.tsv`, the reader, the third heading | `common/games.tsv`, `common/launcher-window.swift`, `common/test-launcher-window.sh` |
| B6 | The icon | `common/launcher-window.swift`, `common/make-launcher-app.sh` |
| B7 | Documents: the root `README.md` and `CLAUDE.md` (the `common/` row, the in-progress line), both games' READMEs, `cities-skylines-2/INSTALL.md`, `cities-skylines-2/CLAUDE.md` and `PLAN.md` where they name the store app, `cities-skylines-2/scripts/README.md`; the as-built header here | those |

Built on a branch in a scratch worktree and merged with `--no-ff` in live step 1, as Phase A was. No
launcher changes, so the launcher parity test and the installed launcher are untouched.

## 4. Test plan

Fixtures are apps made in a scratch folder: an `Info.plist`, and where a state needs it a fake prefix with
a lock symlink or a manifest file. No game, no Steam, no Wine, no window. A test that needs `swiftc` exits
2 without it, which is not a pass.

| # | Test | What it shows | Mutants, each seen red |
|---|---|---|---|
| W1 | `common/test-launcher-window.sh`, `--list` | A `game` app is listed with its id, title and path. An app with no `L1Role`, with another role, with a missing, zero, negative or non-numeric id, with a plist that does not parse or is over 1 MB, and a symlink named `*.app` are not. The title is the display name, then the bundle name, then the file name. Order is games, Steam, offers, each by title. The same app reached through two folder arguments is listed once | the role test dropped; a non-numeric id accepted; the title taken from the file name first; the order by path |
| W2 | same file, states | `busy` for a lock naming a live process; `ready` for a lock naming a dead one, for a lock that is a plain file, and for a target that is not a number; `absent` without the manifest; `unknown` without `L1Prefix`; a busy row without a manifest is `busy` | a dead holder read as busy; the manifest test dropped; `absent` winning over `busy` |
| W3 | same file, `--default` and `--second` | Return starts the last game when it is listed, else the first game, and nothing when no game is listed. `--second` prints `go` when nothing is busy, `go` for the busy row itself, `ask` and the busy title for another game or the Steam app | the last id ignored; the busy row itself asked; a busy game not asked for the Steam app |
| W4 | `cities-skylines-2/scripts/test-make-steam-shortcut.sh`, new | Around a fixture wrapper whose `wine64` is a stub that prints a version: the app is built under the new default name and under `--name`; its plist holds the role, the prefix and the four alternate names and passes `plutil -lint`; the shim passes `bash -n` and names the app it was built as; an old `CS2 Steam Store.app` with the generated line is removed and one without it is left, each said. The shim is never run | the old bundle removed without the generated line; the role key dropped; the title left as the old name |
| W5 | `cities-skylines-2/scripts/test-make-shortcut.sh` and `surviving-mars-relaunched/tools/test-make-app.sh`, added cases | Each built app's plist holds `L1Role` `game`, its own app id, the prefix cut from the game path, its alternate names, and passes `plutil -lint`. A game path without the prefix segment leaves `L1Prefix` out. A prefix path holding `&` survives | the id of the other game; the prefix key written unescaped; the role dropped |
| W6 | `common/test-make-launcher-app.sh`, new | The app is built into a scratch folder with its plist, its alternate names, the copied `games.tsv` and an icon; `--list` run from inside the bundle works. Without `swiftc`, and with a source that does not compile, nothing is left behind, an older app in the target is untouched, the reason is said and the exit is 0 | the build written straight into the target; a failed compile exiting 1 |
| W7 | `common/test-launcher-window.sh`, `--owned` and offers | Files written by the test, in both header forms: an id under `appids` is `owned`; the same number only under `depotids` is `not-owned`; a truncated file, random bytes, an unknown magic, an unknown node type, a nesting of 9, and a list with no end mark are `unknown`; no file is `unknown`. With `--games`, a ported game that has no app and is owned is listed as an offer; one that is not owned, or unknown, is not; one that has an app is never an offer | a search for the id's bytes in place of the parse; `depotids` counted; a failed parse read as `not-owned`; an offer for a game that has an app |
| W8 | `common/test-launcher-window.sh`, the builders together | Both game apps and the Steam app, built by their own builders into one scratch folder, come out of `--list` as two games and one Steam app, and each game's id and title equal its line in `common/games.tsv` | a game's line removed from `games.tsv` |

W8 is what holds the builders, the table and the window together: none of the three can change its keys
alone and stay green.

## 5. Live steps, each on James's word

1. **Merge, on the Studio, with no launcher running.** The check of live step 1 of
   `docs/plans/launch-experience.md` prints nothing; then `git merge --no-ff`, and push.
2. **Build.** `bash scripts/setup.sh` from `cities-skylines-2/` (it now builds the window too), the file
   comparison T2, `bash surviving-mars-relaunched/make-app.sh`, `bash cities-skylines-2/scripts/make-steam-shortcut.sh`.
   `~/Applications` then holds `14unch3r.app`, the two game apps and `S734M Windows Steam.app`, and no
   `CS2 Steam Store.app`. `launcher-window --list ~/Applications` prints two games and one Steam app.
3. **Spotlight, by James.** Typing `launcher`, `14`, `steam`, `cs2` and `mars` each brings up the right
   app. Before that, `mdls -name kMDItemAlternateNames` on each of the four.
4. **The window, looked at.** Captures of the window's own region in light and in dark. James moves through
   it with the arrow keys, Return and Escape, and once with VoiceOver on.
5. **Each game started from the window, by James.** The window closes, the game's progress window appears,
   the game starts. The next time, the game played last is selected and Return starts it.
6. **One at a time.** With one game running, its row says so; choosing the other game asks; "Wait" leaves
   both as they were. "Start anyway" is not exercised.
7. **The Steam row** opens the Windows Steam.
8. **The offers.** Both games are set up on both Macs, so the heading does not appear. It is shown once
   with `--list --games` and a scratch table naming an app the account owns and this Mac has no app for.
9. **The MacBook.** The check of step 1, `git pull`, steps 2, 3 and 5. The Steam app is rebuilt there only
   if that Mac has a store wrapper.

No launcher changes, so no boot check is owed; step 5 starts each rebuilt app once.

## 6. Exit criteria

- W1 to W8 exit 0, with every mutant seen red and restored. An exit 2 does not count.
- Live steps 1 to 8 pass on the Studio and step 9 on the MacBook.
- The design gate: the captures show the window readable in light and in dark; every state is words; the
  keyboard reaches everything; VoiceOver reads a row's title and state.
- The as-built header here is written; the Phase B paragraph of `docs/plans/launch-experience.md` and the
  Phase 5 outline of `docs/plans/1launcher-unification.md` point here; issue #22 has a line once James
  allows the post.

## 7. Rollback

`git revert -m 1` of the merge of live step 1, then, after the check of that step, `bash scripts/setup.sh`,
`bash surviving-mars-relaunched/make-app.sh` and `bash cities-skylines-2/scripts/make-steam-shortcut.sh` on
each Mac, and `14unch3r.app` and `S734M Windows Steam.app` moved to the Trash by hand. The reverted
builders rebuild `CS2 Steam Store.app`. No launcher, game file, save or setting is touched by this plan.

## 8. Not in this plan

- **A guard in the launchers** against starting a second game from Spotlight or Finder. It changes the
  shared lock code of both launchers, and what breaks without it is not measured (section 1).
- **Moving the wrappers out of `~/Applications`.** After this plan that folder holds eight of this
  project's bundles, one more than today, four of them wrappers. `docs/plans/local-files-layout.md`,
  section 7, counts about 50 tracked files that name a wrapper path.
- **Opening a game's own Steam to sign in** (Phase C), and **updates at launch** (Phase D).
- **One setup for every ported game the account owns.** It needs Phase C: ownership can be read only after
  a sign-in in some wrapper.
- **The window turning into the progress window.** Section 9, D1.
- **Renaming the repository or its folders.**

## 9. Decisions (James)

| # | Question | Recommendation |
|---|---|---|
| D1 | Does the window run the game itself and turn into the progress window, as the Phase B outline said? | No. It opens the game's own app and quits, and that app shows the Phase A progress window. One start path, already proven on both Macs, serves Finder, Spotlight, the Dock and the window. The cost: the list closes and the progress window appears a moment later at the top right |
| D2 | Do the per-game apps stay? The outline said the window replaces them, with shortcuts "off by default" | They stay, by J3, and they are the entries. The window adds one app and one Dock icon |
| D3 | What is a game's key? | Its Steam app id. A minted id of our own would be a second key to keep in step, and every game here is a Steam game. To be looked at again when a game without one arrives |
| D4 | The name | `14unch3r` on the app, the window and the icon. `1launcher` stays the name of the repository, its folders and its paths: links, clones and four plans are built from it, and it was renamed two days ago. Typing "launcher" finds the app by its alternate names |
| D5 | The Steam app's name | `S734M Windows Steam`. Plain `S734M` is taken in that folder by the wrapper of that name. Other choices: `Windows Steam`; or plain `S734M` once that wrapper has left the folder |
| D6 | A second game while one runs | Ask, with "Wait" as the default. Not refuse: a running game survives the swap, and the player may know better |
| D7 | Can the ownership file hide a game that is set up? | Never. It only adds offers |
| D8 | The icon | Drawn by the builder, "14" on a dark rounded square, until James supplies art |
| D9 | Is B5, the offers, built now? | Yes, last. It is what J2 asked for beyond what the rows already give, it is small, and it cannot block a launch. It will show nothing on James's two Macs |

## Review log

Not yet checked.

Key paths: `common/launch-progress.swift`, `cities-skylines-2/scripts/make-shortcut.sh`,
`cities-skylines-2/scripts/make-steam-shortcut.sh`, `cities-skylines-2/scripts/setup.sh`,
`surviving-mars-relaunched/make-app.sh`, the lock block of both launchers, `docs/plans/launch-experience.md`.
