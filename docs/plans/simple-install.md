# A one-step install for Cities: Skylines II

> **Status:** Not yet checked: run `check it` before any build. Written 2026-11-10.
> Tracking: issue #22. File and line references are as of `a749425`. A path is relative to the repository
> root. Every number marked "measured" was measured on the Studio (M5 Max, macOS 27.2) on 2026-11-10; the
> probe's scripts, logs and two captures are in `~/cs2-patch/evidence/simple-install-probe-20261110/`.
> This plan's steps are N1 to N6, its tests NT1 to NT7, its live steps NL1 to NL5 and its decisions ND1 to
> ND10. "The guide" is `cities-skylines-2/INSTALL.md`; "setup" is `cities-skylines-2/scripts/setup.sh`.

## 0. What James asked for (2026-11-10)

| # | His words | What this plan does with it |
|---|---|---|
| K1 | "is the initial install very easy for a typical user? many osx app you just drag to the application folder. is our install this easy (ok if it is a different process as long as it is simple)?" | It is not (1.1). The install becomes: open one icon, sign in to Steam, let the game download |
| K2 | "Let's make it simpler and and can double clicking an icon run the install script? Plan check build" | A script does the wrapper and Steam steps (2.2, 2.3); a small app in a ZIP starts it by double-click (2.5) |
| K3 | First run, of three routes: "Free, approve once" | The app is not signed with a paid Apple Developer ID. macOS blocks it once and the user presses Open Anyway (1.5, 2.5). A one-line Terminal paste stays as the other way in |
| K4 | The installer's downloads from their makers' own pages: "Yes, and draft a note" | The engine and the wrapper template come from Porting Kit's GitHub releases, Steam's installer from Valve, each fetched on the user's Mac and never re-hosted (2.2, 2.3). A courtesy note for Porting Kit's developers is drafted for James to send or not (NL5) |
| K5 | A probe of the mechanism on the Studio before the plan: "Yes, run it now" | Done; its measurements are 1.4 and the design rests on them |

## 1. What is true today (read or measured)

### 1.1 The install as it is

| # | What the guide asks | How |
|---|---|---|
| 1 | Rosetta 2 | one Terminal command (`cities-skylines-2/INSTALL.md:11-12`) |
| 2 | A Wine wrapper | Porting Kit's app: pick the Wine 11.0 + DXMT engine, name the wrapper exactly `CS2dxmt11` (`:30-44`). Porting Kit 6.7.0 fails here until one archive is copied to a second name in Terminal (`:46-54`, issue #15) |
| 3 | Steam for Windows inside the wrapper | a download, then Porting Kit's menu or one long Terminal line (`:59-72`) |
| 4 | The game | Steam's own window (`:74-80`) |
| 5 | Setup | `git clone` and `bash scripts/setup.sh` in Terminal (`:82-108`); the first `git` makes macOS offer Apple's Command Line Tools (`:18-19`) |
| 6 | Play | double-click the app setup built (`:110-125`) |

Setup's own header says of steps 2 to 4 that "they need a GUI and cannot be scripted"
(`cities-skylines-2/scripts/setup.sh:4-6`). The probe (1.4) shows that steps 2 and 3 can be.

### 1.2 What the code needs from a wrapper

- The launcher finds a wrapper by `CS2_WRAPPER`, else `~/Applications/CS2dxmt11.app`, `CS2.app`, then any
  wrapper holding the game (`cities-skylines-2/launchers/launch-cs2-dxmt11.sh:33-43`). Of the bundle it uses
  `Contents/SharedSupport/wine/bin/wine64`, `Contents/SharedSupport/prefix`, and `Contents/Frameworks` plus
  `wine/lib` as its library path (`:93-98`). Nothing else.
- Setup tests five paths before it changes anything: the prefix folder, `wine64`, `steam.exe` and
  `Cities2.exe` (`setup.sh:94-118`), and a working `python3` (`:121`). A missing one is `MISSING` with a line
  pointing at the guide's step (`:104`, `:116`, `:118`), and setup stops (`:126-130`).
- After setup, nothing an install runs reads the checkout. The launcher and patches are copies in
  `~/cs2-patch` (`setup.sh:30`, `:146`); the game's app starts that copy (`setup.sh:211`); 14unch3r is a
  compiled program with `games.tsv` copied into it (`common/make-launcher-app.sh:62-76`). So a checkout can be
  a temporary folder, removed when setup has finished.
- Builders here replace only a bundle they generated (`cities-skylines-2/scripts/make-shortcut.sh:48-55`,
  `:107`; `common/make-launcher-app.sh:14-18`), build in a hidden folder inside the destination and swap the
  finished bundle in.
- Wine must be started with `DYLD_FALLBACK_LIBRARY_PATH` exported in the calling shell and never through
  `nohup` or `env`: macOS strips the variable on the way (`launch-cs2-dxmt11.sh:262-268`,
  `cities-skylines-2/scripts/make-steam-shortcut.sh:180-185`).

### 1.3 Where the pieces are published (read 2026-11-10)

| Piece | Address | Bytes | sha256 | Dated |
|---|---|---|---|---|
| Engine | `https://github.com/vitor251093/porting-kit-engines/releases/download/wineskin/WS12Wine11.0_DXMT-v0.80.tar.7z` | 180,784,324 | `afdaab97e84ec7064b8fddf47192c95b18b8bbb9cc3aa4d81060a57d7b4dced0` | 2026-06-12 |
| Its successor, not used (ND4) | the same release, `WS12Wine11.0_1_DXMT-v0.80.tar.7z` | 180,383,624 | `5d7a09ab65a434607898307d9a382a864823edaf7daf11b8572ff6090c4f1589` | 2026-09-04 |
| Wrapper template | `https://github.com/vitor251093/porting-kit-wrappers/releases/download/Wineskin-3.0.6-2/Wineskin.app.tar.7z` | 53,110,672 | `fbe276bba96d5582b99c511117abb1e035a988b8c1aeefe27c32df266a07907a` | 2025-11-06 |
| Steam's installer | `https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe` | 2,380,800 | `7d3654531c32d941b8cae81c4137fc542172bfa9635f169cb392f245a0a12bcb` | 2024-05-20 |

- The three GitHub rows are from GitHub's releases API (name, size, digest, date). The engine archive that
  Porting Kit left on the Studio on 2026-07-04 has the first row's size and sha256 (measured). The template
  address answered a HEAD request with 200 and the size above (measured), and is the pattern in Porting Kit's
  own settings file on the Studio (`wine/macos/wineskinWrapper/downloadBaseUrl`).
- Both releases can be changed by their owners: the engine's tag, `wineskin`, is a rolling release. Neither
  repository has a licence file or says anything about other programs fetching its files. Wineskin's source
  is LGPL-2.1 (`The-Wineskin-Project/wineskin-source`); Wine is LGPL-2.1-or-later; DXMT v0.80 is MIT.
- Steam's installer is at the address Valve's own download button uses. The downloaded file matched the size
  and sha256 above, which are also those in Microsoft's winget manifest for Steam 2.10.91.91. It is an NSIS
  installer whose certificate table names Valve Corp. Valve publishes no checksum, and the address is not
  versioned: the file can be replaced in place.

### 1.4 The probe (measured)

What ran, three times on clean scratch wrappers in `~/Applications`, with no Porting Kit app involved:
Porting Kit's unpacked copy of the template (`Wineskin-3.0.6-2.app`) copied; the engine archive unpacked with
`/usr/bin/tar -xf` and moved to `Contents/SharedSupport/wine`; `Contents/MacOS/wineskinlauncher
WSS-wineprefixcreate`, the call Wineskin Winery itself makes (`Wineskin_WineryAppDelegate.m:931-996` in
`wineskin-source`); `wine64 SteamSetup.exe /S`; Steam started as `make-steam-shortcut.sh:185` starts it.

| | Run 1 | Run 2 | Run 3 |
|---|---|---|---|
| Engine unpacked by `/usr/bin/tar` (5,220 entries, 802 MB) | 6 s | 6 s | 6 s |
| Prefix: exit code, time | 0, 31 s | 0, 27 s | 0, 26 s |
| `SteamSetup.exe /S`: exit code, time | 0, 6 s | 0, 7 s | 0, 6 s |
| First start of Steam | fatal after 25 s | fatal after 25 s | fatal after 25 s |
| Its last log line | `Failed to determine download location for universe 1` | `Steam needs to be online to update` | `Failed to determine download location for universe 1` |
| A later start | start 2: sign-in window after 51 s | start 2: client up after 35 s, sign-in window 10 s later | start 3: client up after 20 s, sign-in window 10 s later |
| `steam.exe -shutdown` at the sign-in window | exit 0, gone in 2 s | exit 0, gone in 2 s | exit 0, gone in 3 s |

- **The first start of Steam in a new prefix failed 3 times out of 3.** The installer Valve serves is from
  2024; its updater downloads the first stage, logs `Error: Download of package (...) failed after 0 bytes`
  one to three times, and stops at a "Fatal Error" box. Started again, it carries on: the log shows the
  updater of 2024, then of January 2026, then of October 2026, then the sign-in window. The box does not go
  away by itself, so the installer has to end that Steam and start it again (2.3, stage 5).
- Run 3 was the whole mechanism unattended, from nothing to the sign-in window, in 111 s. Its start 2 was a
  false "Steam is gone": the updater was replacing itself and for one 5-second poll no Steam process held a
  file of the prefix open. The loop in 2.3 waits for three such polls.
- A wrapper made this way is 3.1 GB with Steam updated (engine 802 MB, template 217 MB, prefix 336 MB, Steam
  1.7 GB). Renamed afterwards, it still brought Steam to the sign-in window, in 21 s.
- `wineserver -k` without the library path exits 134 (`libinotify.0.dylib` not loaded); with it, 0.
- A file fetched with `curl` carries no quarantine attribute. With `winemenubuilder.exe=d` the Desktop was
  unchanged. The template launcher writes the bundle's name and identifier into its `Info.plist` from the
  folder name at the time the prefix is made.
- **Not measured, and so live steps:** unpacking the public template archive (the probe used Porting Kit's
  unpacked copy), a sign-in, a game install, the game starting from such a wrapper (NL1), and what macOS does
  with the downloaded installer app (NL2).

### 1.5 What macOS does with a downloaded installer (read 2026-11-10)

- Since macOS 15 a blocked item can no longer be opened with Control-click then Open. The user tries to open
  it once, then presses Open Anyway under System Settings, Privacy & Security, and gives the login password;
  Apple's page is the same for macOS 15, 26 and 27 (`support.apple.com/guide/mac-help/mh40616`,
  `developer.apple.com/news/?id=saqachfa`).
- Whether Open Anyway works for a double-clicked script file is not documented, and one user on macOS 15
  reported that it did nothing (`discussions.apple.com/thread/255806364`). For an app it is the documented
  path. This is why the front door is an app (2.5).
- A file fetched with `curl` is not quarantined, and Gatekeeper acts on quarantined items
  (`developer.apple.com/forums/thread/666452`, `/765139`). An app built on the Mac itself opens with no
  question (`eclecticlight.co/2024/08/10/gatekeeper-and-notarization-in-sequoia/`).
- A script cannot be notarized; an app can, with a Developer ID certificate: 99 USD a year, issued in the
  holder's legal name (`developer.apple.com/programs/enroll/`, `developer.apple.com/forums/thread/740541`).
  Declined (K3).
- macOS 26.4 and later can refuse a pasted Terminal command with "Possible malware, paste blocked"; the user
  can override it. The trigger is not documented
  (`helpnetsecurity.com/2026/03/31/apple-macos-clickfix-attacks-terminal-warning/`).

## 2. Design

### 2.1 The parts

| File | What it is |
|---|---|
| `cities-skylines-2/scripts/make-wrapper.sh` (new) | Makes the Wine wrapper from the two public archives, with no Porting Kit app |
| `cities-skylines-2/scripts/install.sh` (new) | From nothing to playable: six stages, each skipped when already done, ending in setup |
| `install.sh` at the root (new) | For a Mac with no checkout: fetches the repository and hands over to a game's `scripts/install.sh` |
| `common/make-installer-app.sh` (new) | Builds the double-click app and its ZIP. The app is not in the tree |
| `cities-skylines-2/scripts/setup.sh` (changed) | One new option, `--mac-only`; one variable that keeps a question from being asked twice; three hint lines |
| The guide, the root `README.md`, `cities-skylines-2/scripts/README.md`, the root `CLAUDE.md`, `cities-skylines-2/GOTCHAS.md` | 2.7 |

Someone with a clone can run `bash cities-skylines-2/scripts/install.sh` and never see the other two. Setup
keeps working alone, exactly as today, for anyone who made a wrapper by hand.

### 2.2 `make-wrapper.sh`

```
bash scripts/make-wrapper.sh [--dest <path of the wrapper to make>] [--check]
exit 0 = made (or, with --check, could be made); 1 = refused or failed, said why, nothing left; 2 = a wrong option
```

1. The target is `--dest`, else `$CS2_WRAPPER`, else `~/Applications/CS2dxmt11.app` (ND5). It must not
   exist in any form (`-e` or `-L`): this script never replaces anything. Its name must end in `.app`.
2. The target's volume must have 6 GB free (`df -k`), else it refuses and says how much it found.
3. A build folder `<target's folder>/.l1-wrapper.XXXXXX` (`mktemp -d`), removed by an `EXIT` trap whatever
   happens. Everything below happens inside it.
4. Both archives of 1.3 are fetched with `curl --proto '=https' --tlsv1.2 -fL --retry 2`, with a progress
   bar when standard output is a terminal. The address, byte count and sha256 of each are six constants at
   the top of the script. A file whose size or `shasum -a 256` differs is deleted and the script stops with
   both checksums and a request to open an issue. `L1_DOWNLOADS=<folder>` names a folder of already
   downloaded archives: a file there of the right name is used only if its sha256 matches, and is otherwise
   ignored with a line saying so. (For the tests and the live steps, as `L1_WINDOW_SRC` is for the window's.)
5. The template is unpacked with `/usr/bin/tar -xf` into `t/`. It must hold exactly one `*.app` at its top,
   with `Contents/MacOS/wineskinlauncher` executable and `libfreetype` and `libgnutls` under
   `Contents/Frameworks` (the two libraries `build-engine-1116.sh:44-47` requires of a donor). That bundle is
   renamed, inside the build folder, to the target's own name, so that the launcher of step 7 writes the
   right name into its `Info.plist` (1.4).
6. The engine is unpacked into `e/`. It must hold `wswine.bundle/bin/wine64` and `bin/wineserver`,
   executable. `wswine.bundle` is moved to `Contents/SharedSupport/wine`.
7. The prefix: `Contents/MacOS/wineskinlauncher WSS-wineprefixcreate`, as measured. It must exit 0 and
   leave `Contents/SharedSupport/prefix/system.reg` and `prefix/drive_c/windows`.
8. `wine64 --version`, with `DYLD_FALLBACK_LIBRARY_PATH` exported as the launcher does (1.2), must print a
   line starting `wine-`.
9. The target is tested again for existence, and the bundle is moved to it with `mv`. A bundle is never
   moved onto a bundle (`common/make-launcher-app.sh:17-18`).
10. It prints the wrapper's path and size, and one credit line: the engine and the template are Porting
    Kit's, with its address.

`--check` does steps 1 and 2 and says what it would download. No `xattr` call is made anywhere: nothing
`curl` fetched is quarantined (1.4).

### 2.3 `cities-skylines-2/scripts/install.sh`

```
bash scripts/install.sh [--check] [--yes] [--desktop] [--no-setup]
exit 0 = done; 1 = a stage failed, said why; 2 = a wrong option; 3 = stopped at a question (answered no, or
nobody to ask); 4 = Steam ended before the game was installed: open the installer again to carry on
```

It refuses to run as root. Each stage prints one line, `Step n of 6`, with its name and `OK`, or what it is
doing. A stage whose result is already there is skipped, so running it again after any stop carries on
from where it stopped, and running it on a finished install is the way to update (stage 6 runs every time).

| # | Stage | Done when | What it does otherwise |
|---|---|---|---|
| 1 | This Mac | Apple Silicon has Rosetta; then `setup.sh --mac-only` exits 0 | Rosetta missing: says what it is and that installing it accepts Apple's licence for it, asks `[y/N]`, and on `y` (or with `--yes`) runs `softwareupdate --install-rosetta --agree-to-license` and tests again. On no, or with no terminal, it prints the command and exits 3. Then `setup.sh --mac-only` (2.6) prints the Mac's lines and asks its one question on a Mac outside what has been tested |
| 2 | Apple's Command Line Tools | `xcode-select -p` succeeds and the `python3` test of `setup.sh:121` passes | Runs `xcode-select --install`, which opens Apple's own window, says to press Install there, and polls every 5 s for up to 60 minutes. On time-out it says to open the installer again when Apple's has finished, and exits 1 |
| 3 | The Wine wrapper | a wrapper is found by setup's own rule (`setup.sh:95-102`) | `make-wrapper.sh`; its failure is this stage's |
| 4 | Steam for Windows | `Steam/steam.exe` or `Steam/Steam.exe` is in the prefix | Fetches Steam's installer into a `mktemp -d` folder (removed after), with the `curl` options of 2.2. It must be larger than 1 MB, start with `MZ` and contain the bytes `Valve Corp` (ND8); its sha256 is printed, with "the installer this was tested with" when it is the one of 1.3. Then `wine64 SteamSetup.exe /S` with the launcher's four exports (1.2) and `winemenubuilder.exe=d`, `wineserver -w`, and the test of the "done when" column |
| 5 | The game | `appmanifest_949230.acf` has `StateFlags` 4 and `Cities2.exe` exists | Below |
| 6 | Patches and apps | never skipped | `setup.sh`, with `--yes` and `--desktop` passed on when given, `CS2_CAUTION_SEEN=1` in its environment (2.6), and `CS2_WRAPPER` when that was set. Its exit code is this script's. With `--no-setup` the script stops before this stage and says so |

Before stage 3 it prints the free space of the home volume beside what the game takes (about 100 GB with
all its DLC, `SizeOnDisk` 103,074,454,651 on the Studio); under 110 GB free this is a `CAUTION` line, not a
stop.

**Stage 5, in order.**

1. If no Steam process holds a file of this prefix open (the launcher's rule,
   `launch-cs2-dxmt11.sh:165-175`), Steam is started until its client is up: remove a stale `.crash`
   (`:260-261`), note the length of `logs/bootstrap_log.txt`, start
   `wine64 steam.exe -no-cef-sandbox` in the background with `disown`, and poll every 5 s. The client is
   up when a `steamwebhelper` process holds the prefix. If a new log line matches
   `Error: (Failed to determine download location|Steam needs to be online)`, that Steam is ended with
   `wineserver -k` for this prefix and started again. If no Steam process holds the prefix for three polls
   in a row, it is started again. At most five starts, ten minutes each; after that the stage fails with the
   last twenty log lines. While this goes on the stage's line says "Steam is updating itself; this can take
   a few starts".
2. It prints what to do, once: sign in, in Steam's window, with "Remember me" ticked; then, in Library,
   choose Cities: Skylines II and Install; do not press Play there; this window goes on by itself when the
   download is done, and it is safe to close it and open the installer again later.
3. It polls the manifest every 5 s and prints a line when the whole percent changes:
   `BytesDownloaded` of `BytesToDownload`, in GB. No time limit: a download takes hours.
4. If Steam is gone for three polls in a row before the game is installed, it says that opening the
   installer again carries on from here, and exits 4.
5. When the game is installed, Steam is shut down as the launcher does it (`:392-424`):
   `steam.exe -shutdown`, a wait of up to 60 s for the prefix's Steam processes, then `wineserver -k` for
   this prefix if any is left. Never `kill -9`.

`--check` prints the state of every stage and what it would do, starts nothing and changes nothing.

### 2.4 `install.sh` at the root

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/macgameport/1launcher/main/install.sh)"
bash install.sh [<game folder> [<ref> [options for the game's installer ...]]]
```

- The game defaults to `cities-skylines-2` and the ref to `main`. A ref must match `^[A-Za-z0-9._/-]+$`.
- Run as a file that has `<game>/scripts/install.sh` beside it, it hands over to that file and fetches
  nothing: this is the clone's case. Otherwise (the pasted line, the app) it fetches
  `https://github.com/macgameport/1launcher/archive/<ref>.tar.gz` into a `mktemp -d` folder with the `curl`
  options of 2.2, unpacks it with `tar -xzf`, and requires exactly one top folder holding
  `<game>/scripts/install.sh`. A game folder without that file gets a line naming the games that have one.
- It prints the commit it fetched, read from the archive's own header (`comment=<40 hex digits>` in the
  first 1024 bytes of the unpacked stream), or "commit not read" when that is absent.
- It runs the game's installer with the remaining arguments, removes the temporary folder whatever the
  result (an `EXIT` trap), and exits with the installer's code.
- The pasted form is the one above, not `curl ... | bash`: with a pipe the script's questions would have no
  terminal to read from.

### 2.5 The installer app

`common/make-installer-app.sh --out <folder> [--ref <ref>] [--icns <file>]` writes
`<out>/Install Cities Skylines II.app` and `<out>/Install-Cities-Skylines-II.zip` (`ditto -c -k
--keepParent`), and prints the ZIP's size and sha256. It follows the builders' rule (1.2): it replaces only
a bundle carrying its own marker line and identifier, `local.1launcher.installer`.

The bundle holds three files: `Contents/Info.plist`, the icon, and `Contents/MacOS/install`, a bash script.
The icon is `--icns`, else the one in `~/Applications/14unch3r.app` (ND6); with neither it builds without an
icon and says so. The script, with the ref written in at build time:

```bash
#!/bin/bash
# Generated by common/make-installer-app.sh -- run that again instead of editing this file.
D="$(mktemp -d "${TMPDIR:-/tmp}/1launcher-install.XXXXXX")" || exit 1
C="$D/Install Cities Skylines II.command"
cat > "$C" <<'EOS'
#!/bin/bash
clear
echo "Fetching the installer from github.com/macgameport/1launcher ..."
if S="$(curl --proto '=https' --tlsv1.2 -fsSL "https://raw.githubusercontent.com/macgameport/1launcher/<ref>/install.sh")"; then
  /bin/bash -c "$S" install.sh cities-skylines-2 "<ref>"
else
  echo "GitHub could not be reached. Check the network, then open the installer again."
fi
rm -rf "$(dirname "$0")"
echo; echo "You can close this window."
EOS
chmod +x "$C"
open -a Terminal "$C"
```

- **The app holds no code of the repository (ND7).** It fetches `install.sh` of its ref each time, so one
  published app keeps installing the current code, and opening it again later is the update.
- The `.command` file is written fresh, not copied out of the bundle: a copy would carry the bundle's
  quarantine attribute, and Terminal would be stopped a second time.
- The install shows in a Terminal window, where its questions can be answered.
- First open, as the guide will describe it: macOS says it could not verify the app; the user opens System
  Settings, Privacy & Security, presses Open Anyway and confirms; this is asked once. NL2 measures it. If
  Open Anyway does not work for this kind of app, the app is not published and the guide leads with the
  pasted line (ND1's other half), which is built and tested either way.
- The ZIP is published as the one asset of a GitHub release tagged `installer-1`, created with
  `--latest=false` (ND9), at NL3 and on James's word. The guide links
  `https://github.com/macgameport/1launcher/releases/download/installer-1/Install-Cities-Skylines-II.zip`.
  A later change to the app is `installer-2`: a published tag is never moved
  (`docs/plans/local-files-layout.md:146`).

### 2.6 `setup.sh`

- `--mac-only`: after the macOS lines (`:71-92`) it stops. Rosetta missing: the "prerequisite(s) missing"
  lines and exit 1. A caution: the caution paragraph (`:132-137`) and its question (`:139-142`, asked as
  today only with a terminal and without `--yes`), then exit 0. Otherwise exit 0. It is in `--help`.
- `CS2_CAUTION_SEEN=1` in the environment: the question of `:139-142` is not asked. The lines are still
  printed. `install.sh` sets it for stage 6, so a Mac outside the tested range is asked once per install.
- The three hint lines (`:104`, `:116`, `:118`) gain "or run `bash scripts/install.sh`, which does this
  for you". The header's "cannot be scripted" (`:4-6`) is replaced by one line naming `install.sh`.
- Nothing else changes, and the sixteen mutants of `test-setup.sh` must still apply and still be red: each
  refuses with exit 2 when its line is no longer there.

### 2.7 Guides and other documents

- **The guide** gains a first section, "The quick way": download the installer (the ZIP's link), open it,
  the Open Anyway steps, what the six steps do and what they download from whom, the sign-in and the game,
  and the pasted line as the other way in. Its numbered sections 1 to 5 stay, under one new sentence saying
  they do the same by hand, so the anchors and setup's hints still point at something. "After a game
  update" (`:284-313`) gains: or open the installer again. Uninstall (`:333-342`) is unchanged: the
  installer adds no place.
- **The root `README.md`** quick start (`:26-44`) leads with the installer link and the pasted line; the
  three `git clone` lines stay as "with git". Its status table and compatibility are unchanged.
- `cities-skylines-2/scripts/README.md`: rows for the two new scripts and their tests.
- **The root `CLAUDE.md`**: a `Layout` row for the root `install.sh`; `common/` gains the installer
  builder and its test; one sentence that the installer app is released under its own tag. No new place
  outside the repository (ND10): the paragraph listing those places is unchanged.
- `cities-skylines-2/GOTCHAS.md`: three entries, each with its measurement: the first start of Steam in a
  new prefix fails and a second works; `/usr/bin/tar` unpacks the `.tar.7z` engine; `wineserver` needs the
  library path too.
- This plan's as-built header, and one line in the parent `docs/plans/1launcher-unification.md` Phase 5
  list if that list names its slices.

### 2.8 What this plan leaves alone

The Wine 11.16 engine build (the guide's section 6) stays a separate, optional hour. Surviving Mars needs
CrossOver and has no installer. 14unch3r's "not set up" tiles keep opening the guide. Where an install keeps
its files (`~/cs2-patch`) is `docs/plans/local-files-layout.md`'s, and so is the first `v`-numbered release.
`steam://install/949230`, which might open Steam's install box by itself, is measured at NL1 and built only
in a later slice if it works.

## 3. Steps

| # | What | Tests |
|---|---|---|
| N1 | `make-wrapper.sh` | NT1 |
| N2 | `setup.sh`: `--mac-only`, `CS2_CAUTION_SEEN`, the hint lines | NT2 |
| N3 | `cities-skylines-2/scripts/install.sh` | NT3 |
| N4 | The root `install.sh` | NT4 |
| N5 | `common/make-installer-app.sh` | NT5 |
| N6 | The documents of 2.7, and the as-built header | NT6, NT7 |

Built on a branch, `simple-install`, in a scratch worktree. N1 and N2 touch different files and can go in
either order; N3 needs both; N4 and N5 need N3's interface only. Nothing is merged or published before NL3.

## 4. Test plan

Every test runs with `HOME` at a scratch folder, on a scratch copy of the scripts (the form of
`cities-skylines-2/scripts/test-setup.sh:27-36`), with stubs on `PATH` that record their arguments. No
network, no Wine, no real download, nothing written outside the scratch folder. Each mutant is applied to
the scratch copy by a `sed` that refuses when it did not apply, and must be seen red.

| # | Script | Cases | Mutants (each must exit 1) |
|---|---|---|---|
| NT1 | `cities-skylines-2/scripts/test-make-wrapper.sh` | A stub `curl` that copies fixture archives (plain tar files under the real names; the pins rewritten in the scratch copy). Made: the wrapper is at the target with `wine/bin/wine64`, `prefix/system.reg`, `Frameworks`, the launcher stub called once with `WSS-wineprefixcreate` from a bundle named as the target; `curl` called twice with the two addresses of 1.3 (read from the real script, not the copy). Refused with nothing made and no build folder left: target exists as a folder, as a file, as a dangling link; a name not ending `.app`; too little space (stub `df`); `curl` fails; wrong sha256 of the engine; of the template; wrong size; a template with two apps, with no launcher, without `libfreetype`; an engine without `wine64`; the launcher stub exits 1; it leaves no `system.reg`; `wine64 --version` prints nothing. `L1_DOWNLOADS`: a matching file is used and `curl` not called for it; a non-matching one is ignored and `curl` called. `--check` writes nothing | the sha256 of the engine not compared; of the template not compared; an existing target replaced; the build folder left behind on failure; a failed prefix still moved to the target; `L1_DOWNLOADS` used without the sha256; the bundle not renamed before the prefix is made |
| NT2 | `cities-skylines-2/scripts/test-setup.sh`, new cases | `--mac-only`: exits before any wrapper line is printed; 0 on a tested Mac; 1 with Rosetta missing; on macOS 15 with a terminal (the `ptya` helper) asks and exits 0, with `--yes` does not ask. `CS2_CAUTION_SEEN=1` with a terminal on macOS 15: a full setup does not ask; without it, it asks. The sixteen existing mutants, run again | 17: `--mac-only` goes on to the wrapper checks; 18: `CS2_CAUTION_SEEN` is ignored; 19: `--mac-only` exits 0 with Rosetta missing |
| NT3 | `cities-skylines-2/scripts/test-install.sh` | Recording stubs for `make-wrapper.sh`, `setup.sh`, `wine64`, `wineserver`, `curl`, `softwareupdate`, `xcode-select`, `arch`, `sysctl`, `sw_vers`, `df`, `pgrep` and `lsof`; a fixture prefix. All done: only setup runs, and the exit code is setup's (0, then 1). Nothing done: the six stages in order. Rosetta missing: `n`, Return and no terminal each exit 3 with `softwareupdate` not called; `y` and `--yes` call it with exactly `--install-rosetta --agree-to-license`; still missing afterwards exits 1. Tools missing: `xcode-select --install` called once, then goes on when the stub starts to succeed; a time-out (the limit lowered in the copy) exits 1. Steam: a failed fetch, a file not starting `MZ`, one without `Valve Corp`, an installer exit of 1, and no `steam.exe` afterwards each exit 1 before stage 5; `Steam.exe` alone counts as present. Stage 5 with fixture logs and manifests: a fatal line of each of the two kinds ends that Steam (`wineserver -k` recorded) and starts another; a one-poll gap does not start another, a three-poll gap does; five fatal starts exit 1; a manifest at 41 percent prints one line for 41; `StateFlags` 4 with `Cities2.exe` goes on, and `-shutdown` is recorded before setup; Steam gone for three polls exits 4 and setup is not run; Steam already up is not started again. `--no-setup` stops before setup. `--check` records no call that changes anything. Run as root (stub `id`) it refuses. The source holds no `kill -9`, `nohup` or `env ` before a Wine call | Rosetta installed on Return; setup run when the game is absent; the wrapper made when one exists; Steam's installer run when Steam is present; the fatal line not acted on; a one-poll gap restarts Steam; `-shutdown` left out; exit 0 when Steam is gone; `--check` starts Steam; the `MZ` test left out |
| NT4 | `common/test-bootstrap.sh` | A stub `curl` serving a fixture `tar.gz` whose game installer records its arguments. The pasted form (`bash -c "$(cat install.sh)"`): fetches the address of the ref, runs the fixture's installer with the options passed on, removes its temporary folder, exits with the installer's code (0, then 7). As a file beside a game folder: `curl` is not called. A ref with a space or `;` exits 2 with nothing fetched. A failed fetch, an archive with two top folders, and a game without an installer each exit 1 with a line, and leave no folder | the temporary folder kept; the installer's exit code dropped; a bad ref fetched; the clone's case fetches |
| NT5 | `common/test-make-installer-app.sh` | Built into a scratch folder with a stub `open`: the three files, the identifier, the marker line, the ref in both places; the ZIP unpacked with `ditto -x -k` keeps the script executable. The script run with the bundle's files carrying a quarantine attribute (`xattr -w`): the `.command` it writes has none, `open` is called with `-a Terminal` and that path. A ref that fails 2.4's pattern exits 2. A target that is not this builder's own bundle is refused and left as it was. Without an icon it still builds and says so | the `.command` copied from the bundle (the attribute travels); `open` given a file inside the bundle; a foreign bundle replaced; the ref not checked |
| NT6 | The repository's gates | `python3 common/check-links.py` (0 unresolved); `bash common/check-identifiers.sh` at the recorded residual; `bash -n` on every new script; the existing suites `test-setup.sh`, `common/test-launcher-builders.sh`, `common/test-make-launcher-app.sh` green | none: they are gates |
| NT7 | In NT5's file | The address in the root `README.md`'s pasted line, the one in the guide, and the one the app's script fetches with ref `main` are the same string; the release address in both documents names `installer-1` and the ZIP's exact name | the README's line changed alone |

Not testable without a real Mac state, and so live: the real archives, Wine, Steam, a sign-in, the game, and
Gatekeeper.

## 5. Live steps, each on James's word

- **NL1. The mechanism, for real, into a scratch wrapper on the Studio.** With no game, Steam or launcher
  running: from the branch's worktree, in Terminal,
  `CS2_WRAPPER=~/Applications/CS2fresh.app bash cities-skylines-2/scripts/install.sh --no-setup`. It
  downloads the two archives (the first real unpack of the template), makes the wrapper, installs Steam and
  rides out the first-start failure. James signs in. Then, once: whether
  `wine64 steam.exe steam://install/949230` opens the install box (2.8). Steam is shut down, the game folder
  and its manifest are cloned from `CS2dxmt11.app` with `cp -Rc` (no download, almost no disk), and the
  installer is run again: it must find the game, shut Steam down and stop before setup. Last,
  `CS2_WRAPPER=~/Applications/CS2fresh.app bash ~/cs2-patch/launch-cs2-dxmt11.sh` must reach the main menu
  (the cloned game is already patched). A visible game start: James is told before it. `CS2fresh.app` goes
  to the Trash afterwards. The real install is not touched: `--no-setup` keeps setup, and so the apps and
  `~/cs2-patch`, out of it.
- **NL2. The front door.** The branch is pushed. `make-installer-app.sh --ref simple-install` builds the
  ZIP, which is served from the Studio by a local web server so that Safari downloads and quarantines it as
  it would from GitHub. James downloads it, opens the app, and reports each thing macOS says; Open Anyway;
  the Terminal window; the fetch of the branch. On the Studio every stage is done, so it ends in setup on
  the real install, from the branch's code: the "open it again to update" path. Recorded: every dialog's
  words, whether Open Anyway worked, whether macOS asked anything else. If the app cannot be opened this
  way, ND1's other half applies (2.5).
- **NL3. Publish.** The branch is merged. With James's word for each public act: the `installer-1` release
  with the ZIP built for `main`, then the issue #22 note. The link in the guide and the README is opened in
  a browser and must download the ZIP whose sha256 the builder printed.
- **NL4. A Mac with nothing on it.** A new macOS user account (James makes it) or any Mac without the
  wrapper: the guide's quick way from the public page, to Steam's sign-in window at least. Whether the game
  is downloaded there is James's call. This is the first fresh install since the folders moved.
- **NL5. The note to Porting Kit's developers.** The draft is `portingkit-note-draft-20261110.md` in the
  session folder. James sends it, changes it or drops it; an answer is recorded here.

## 6. Exit criteria

- N1 to N6 are committed on the branch; NT1 to NT7 pass; every listed mutant was applied and seen red, with
  the count in the as-built header; the sixteen older mutants of `test-setup.sh` are still red.
- NL1 passed: a wrapper made by the script, Steam signed in, the game found, the main menu reached.
- NL2 passed, or failed and the guide leads with the pasted line instead.
- NL3 done: the merge, the release when NL2 passed, the documents live, the link checked.
- NL4 and NL5 are done or James has said to leave them, and the header says which.
- The as-built header is written, with the deviations.

## 7. Rollback

Before NL3 there is nothing to undo but the branch. After it: `git revert -m 1` of the merge takes the
scripts and the documents back; setup then behaves as before (its changes are one option and one variable).
A published release is not deleted: its notes gain a first line saying it is withdrawn, and the README no
longer links it. Nothing on a user's Mac needs undoing, because an install made by the installer is an
install the guide's steps would have made: the same wrapper name, the same Steam, the same setup. A wrapper
someone no longer wants goes to the Trash, as the guide's Uninstall says.

## 8. Decisions

| # | Decision | By |
|---|---|---|
| ND1 | The first run is free: an unsigned app approved once with Open Anyway, and a pasted Terminal line as the other way. If NL2 shows the app cannot be approved, only the pasted line is published | James (K3); the fallback is this plan's |
| ND2 | The installer fetches the engine, the template and Steam's installer from their makers' own pages, and a courtesy note is drafted | James (K4) |
| ND3 | The mechanism was probed before the plan was written | James (K5) |
| ND4 | The engine pinned is `WS12Wine11.0_DXMT-v0.80` of June 2026: the one the Studio's Wine 11.0 measurements and the probe ran on. Its successor `11.0_1` is what Porting Kit 6.7.0 fetches today and one user has run it (issue #15); moving the pin is a later change with its own run | this plan |
| ND5 | The wrapper keeps the name and the shape every script and document already knows: `~/Applications/CS2dxmt11.app`, a whole Wineskin wrapper, its prefix made by the template's own launcher. An install by the installer and one by hand are then the same thing | this plan |
| ND6 | The installer app carries the 14unch3r mark as its icon | this plan |
| ND7 | The app holds no code of the repository and fetches `install.sh` of `main` each time. A published app then never goes stale when a game update needs new patches | this plan |
| ND8 | Steam's installer is not pinned by checksum: Valve replaces the file in place, and a stale pin would stop every install. It comes over HTTPS from Valve's own address, must be a Windows program naming Valve Corp, and its sha256 is printed | this plan |
| ND9 | The app is released under its own tag, `installer-1`, not marked latest, apart from the `v0.1.0` that `docs/plans/local-files-layout.md` owns | this plan |
| ND10 | No new place outside the repository. Downloads and the temporary checkout live in `mktemp` folders that are removed; the wrapper is where wrappers already are | this plan |

## Review log

Key paths: `cities-skylines-2/scripts/setup.sh`, `cities-skylines-2/scripts/test-setup.sh`,
`cities-skylines-2/launchers/launch-cs2-dxmt11.sh`, `cities-skylines-2/scripts/make-steam-shortcut.sh`,
`cities-skylines-2/scripts/make-shortcut.sh`, `common/make-launcher-app.sh`, `cities-skylines-2/INSTALL.md`,
`README.md`.

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
