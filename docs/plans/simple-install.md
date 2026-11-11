# A one-step install for Cities: Skylines II

> **Status:** Triple-checked 2026-11-10 — build-ready-with-fixes, corrections folded (pass 1: four lenses;
> pass 1b: a fitted check of that fold, one blocker, folded too). Written 2026-11-10.
>
> **🔧 As-built (2026-11-11):** PARTIAL: N1 to N6a are built on the local branch `simple-install` (`86c83d8`, and
> `a9eeaa7` for a defect the first live step found), not merged and not pushed; nothing is published. NL1
> passed on 2026-11-11 (the last paragraph of this header); no other live step has been run. Tests, each with `HOME` at a
> scratch folder: NT1 59 cases and 10 mutants; NT2 94 cases, mutants 17 to 21 beside the sixteen older ones;
> NT3 96 cases and 25 mutants; NT4 31 cases and 5 mutants; NT5 with NT7 42 cases and 7 mutants;
> `common/test-launch-lock.sh` 24 cases and its mutant, with the installer as its third file. All 52 new
> mutants and the 17 older ones were applied and seen red. NT6's gates were run and are green: links (0
> unresolved), identifiers (at the residual of 9), the experiments ledger, `bash -n`, and the three launcher
> suites. Deviations: (1) NT3 found a defect while it was being built: on a new install, where Steam has no
> log yet, `wc -l < "$BOOTLOG" 2>/dev/null` printed the log's whole path into the player's Terminal; the file
> is now tested first (`cities-skylines-2/GOTCHAS.md`). (2) The mutant "a copied function run with an empty
> `WINEPREFIX`" could not go red on a wrong result: with no prefix the variable is unset and `set -u` stops
> the copied function inside its own pipeline, so the game is never taken for ours either way. What the
> guard saves is the shell's "unbound variable" line, and that is what the case now asserts. (3) The stray
> sweep's `kill` goes through `L1_KILL` (default `kill`), so that no test signals a real process; and NT1's
> launcher-failure case makes a whole prefix before it exits 1, so that only the exit code tells. (4)
> `cities-skylines-2/GOTCHAS.md` has the four planned entries (the fourth, Steam and a closed Terminal window,
> written from NL1), one the tests found, one the live run found, and one on `steam://install` from NL1's
> second half. N6a carries picture 3 only, as planned; picture 4 was added at NL1. (5) The
> experiments ledger gained a row for the probe's evidence folder (`exp_a934dc`): its gate was red on `main`
> without one. (6) N1, N2 and most of N3 were written on Opus 5.5; N3's last fix, N4, N5, N6a and this header
> on Fable 5.2; NL1's second half and its records on Opus 5.5. Still to come, each on James's word: NL2 to NL5,
> and N6b after the release exists. Verify
> against: `install.sh`, `cities-skylines-2/scripts/install.sh`, `cities-skylines-2/scripts/make-wrapper.sh`,
> `cities-skylines-2/scripts/setup.sh`, `common/make-installer-app.sh`, their five tests,
> `common/test-launch-lock.sh`, `cities-skylines-2/INSTALL.md`.
>
> **NL1 so far (the Studio, 2026-11-11; evidence `~/cs2-patch/evidence/simple-install-NL1-20261111/`, ledger
> row `exp_ceec08`).** Measured: both real downloads passed their checksums and the wrapper was made (1.3 GB);
> Steam's installer had the tested checksum; the installer started Steam twice (the first start ended 24 s
> later at the "download location" line) and Steam's sign-in window was up about 115 s after the installer
> was opened; Control-C's signal twice and the Terminal window closed once each stopped the installer and left Steam
> holding the prefix with its window on screen, the lock released and `caffeinate` ended; opened again with
> Steam up, the installer went straight to its sign-in words and did not start Steam again. Found and fixed
> in `a9eeaa7`: after Control-C the installer said "Done."; it now traps INT, TERM and HUP and says it was
> stopped (two GOTCHAS entries; the guide gained one sentence).
>
> **NL1, second half (the Studio, the same afternoon, after a restart; runs 4 to 6, same evidence folder).**
> With Steam already updated, Steam's sign-in window was up 10 to 23 s after the installer was opened. A
> closed Terminal window (the red button, then Terminate) left Steam up, signed in and untouched, for the 53 s
> it was watched (run 5); the two earlier Steam exits that looked like the window's doing were James closing
> Steam's sign-in window, which quits a Steam that is not signed in (he confirmed run 4's). macOS's box for the
> closed window lists `steam.exe` among the processes it "will terminate"; it is wrong about Steam, but the
> installer keeps "Leave this window open" for now (a decision for James, below). Opened again after the
> closed window, the installer said "Steam for Windows is open." and did not start Steam again. James signed
> in with a code and "Remember me"; Steam signed itself in again at its next start. Pressing Install started
> the real 92 GB download, which James paused and uninstalled. `steam://install/949230`, sent with the game not
> installed, opened Steam's Install box inside the main window; Cancel left nothing (a GOTCHAS entry). Picture
> 4 was cropped from Steam's window to the Install button alone (`AUDIT.md` row, the guide's step 4). With the
> installer polling, the real game folder was cloned in with `cp -Rc` (96 GB in 1 s, no disk used) and then
> its manifest: the installer saw the game within one poll and said "The game is installed. Closing Steam.";
> counted from the manifest's arrival, Steam was gone in order at 7 s and the wineserver at 11 s; the
> installer stopped before step 6 with exit code 0.
> `boot-verify.sh` on the scratch wrapper: PASS (main menu 89 s after launch, graceful exit, Steam down, no
> `.crash`; `~/cs2-patch/boot-verify/20261111-154440`). The after-listing differs from the before-listing only
> by the wrapper itself and a Bitwarden extension that is not ours: the install writes nothing else to the
> Desktop, Documents or two levels of `~/Library`, as the guide's Uninstall says. Steam was then signed out in
> the scratch wrapper (its token store empty, `-shutdown` exit code 0 when run by hand) and `CS2fresh.app`
> went to the Trash. Not recorded: the exit code of the installer's own `-shutdown`, which it discards.
> Found, not fixed: after the player uninstalls mid-download the installer does not say "Waiting for you to
> choose Install" again, and its last line stays the download's "0.0 of 92.4 GB (0%)". **For James:** whether
> the last line may now say that closing the window is safe (perhaps with Steam started in its own session, so
> that macOS's box no longer names it), and whether a later slice has the installer open Steam's Install box
> itself with `steam://install/949230` (2.9).
>
> Tracking: issue #22. File and line references are as of `a749425`; none of the cited files changed up to
> `580cf4e`. A path is relative to the repository root. Every number marked "measured" was measured on the
> Studio (M5 Max, macOS 27.2) on 2026-11-10; the probe's scripts, logs, captures and a `NOTES.md` are in
> `~/cs2-patch/evidence/simple-install-probe-20261110/`. This plan's steps are N1 to N6, its tests NT1 to
> NT7, its live steps NL1 to NL5 and its decisions ND1 to ND13. "The guide" is `cities-skylines-2/INSTALL.md`;
> "setup" is `cities-skylines-2/scripts/setup.sh`; "the launcher" is
> `cities-skylines-2/launchers/launch-cs2-dxmt11.sh`.

## 0. What James asked for (2026-11-10)

| # | His words | What this plan does with it |
|---|---|---|
| K1 | "is the initial install very easy for a typical user? many osx app you just drag to the application folder. is our install this easy (ok if it is a different process as long as it is simple)?" | It is not (1.1). The install becomes: open one icon, sign in to Steam, let the game download |
| K2 | "Let's make it simpler and and can double clicking an icon run the install script? Plan check build" | A script does the wrapper and Steam steps (2.2, 2.3); a small app in a ZIP starts it by double-click (2.5) |
| K3 | First run, of three routes: "Free, approve once" | The app is not signed with a paid Apple Developer ID. macOS blocks it once and the user presses Open Anyway (1.5, 2.5). A one-line Terminal paste is the other way in |
| K4 | The installer's downloads from their makers' own pages: "Yes, and draft a note" | The engine and the wrapper template come from Porting Kit's GitHub releases, Steam's installer from Valve, each fetched on the user's Mac and never re-hosted (2.2, 2.3). A courtesy note for Porting Kit's developers is drafted for James to send or not (NL3) |
| K5 | A probe of the mechanism on the Studio before the plan: "Yes, run it now" | Done; its measurements are 1.4 and the design rests on them |
| K6 | "Is there going to be a page on GitHub with a step by dry install guide", then "With screenshots" | The guide's first section walks through it with four pictures (2.7) |
| K7 | Which code the app runs each time it is opened: "A release branch" | The app and the pasted line fetch a branch named `release`, which moves forward only on purpose and on James's word (2.4, 2.8) |
| K8 | Downloading the wrapper template to test its unpacking: "Yes, download and test" | Done; it is a real 7-Zip file holding a tar, and its files carry a quarantine attribute (1.4) |

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

- The launcher's `find_wrapper` (`launch-cs2-dxmt11.sh:33-45`) takes `CS2_WRAPPER`, else
  `~/Applications/CS2dxmt11.app`, `~/Applications/CS2.app` and `/Applications/CS2dxmt11.app` (the first with
  a prefix folder), else the first `~/Applications/*.app` holding `Cities2.exe`. Setup's rule is narrower:
  `CS2_WRAPPER`, else the first two names (`setup.sh:95-102`). The game's app does not tell the launcher
  which wrapper to use (`cities-skylines-2/scripts/make-shortcut.sh:118-146`), so at play time the
  launcher's rule decides.
- Of the bundle the launcher uses `Contents/SharedSupport/wine/bin/wine64` and `bin/wineserver`,
  `Contents/SharedSupport/prefix`, `Contents/Frameworks` plus `wine/lib` as its library path, and the
  bundle's name (`:93-98`, `:405`, `:422`). `cities-skylines-2/repatch.sh:59-64` looks for the Windows user
  folder `drive_c/users/Wineskin` first.
- Setup tests four paths and one program before it changes anything: the prefix folder, `wine64`,
  `steam.exe` and `Cities2.exe` (`setup.sh:94-118`), and a working `python3` (`:121`). A missing one is
  `MISSING` with a line pointing at the guide's step (`:104`, `:116`, `:118`), and setup stops (`:126-130`).
- After setup, nothing an install runs reads the checkout. The launcher and patches are copies in
  `~/cs2-patch` (`setup.sh:30`, `:146-159`); the game's app starts that copy (`setup.sh:211`); 14unch3r is a
  compiled program with `games.tsv` copied into it (`common/make-launcher-app.sh:62-76`). So a checkout can
  be a temporary folder. Setup's own words do name the checkout: `:67`, `:128`, `:206`, `:260`, `:287`.
- Every launcher that uses a prefix's Steam holds `<prefix>/.launcher.lock` for its whole run
  (`launch-cs2-dxmt11.sh:191-219`); `common/test-launch-lock.sh` keeps the copies of those functions
  identical. Setup takes no lock and copies over the deployed launcher (`setup.sh:152`).
- `common/make-launcher-app.sh` replaces only a bundle it generated, builds in a hidden folder inside the
  destination and swaps the finished bundle in (`:15-19`); `make-shortcut.sh` has the same own-bundle rule
  (`:47-60`, `:107`).
- Wine must be started with `DYLD_FALLBACK_LIBRARY_PATH` exported in the calling shell and never through
  `nohup` or `env`: macOS strips the variable on the way (`launch-cs2-dxmt11.sh:262-268`,
  `cities-skylines-2/scripts/make-steam-shortcut.sh:179-185`). A bash stub on `PATH` does not receive the
  variable either (measured by the builder lens), so no stub test can see it.
- The launcher's shutdown of Steam is `-shutdown`, 20 s of waiting, `wineserver -k` and 10 s more if Steam
  is still there, then a sweep of stray helpers with a plain `kill` (`:392-424`). Its process tests match
  `steam.exe` in lower case (`:166-175`); Valve's installer writes `Steam.exe` (1.4).

### 1.3 Where the pieces are published (read 2026-11-10)

| Piece | Address | Bytes | sha256 | Uploaded |
|---|---|---|---|---|
| Engine | `https://github.com/vitor251093/porting-kit-engines/releases/download/wineskin/WS12Wine11.0_DXMT-v0.80.tar.7z` | 180,784,324 | `afdaab97e84ec7064b8fddf47192c95b18b8bbb9cc3aa4d81060a57d7b4dced0` | 2026-06-08, updated 06-12 |
| Its successor, not used (ND4) | the same release, `WS12Wine11.0_1_DXMT-v0.80.tar.7z` | 180,383,624 | `5d7a09ab65a434607898307d9a382a864823edaf7daf11b8572ff6090c4f1589` | 2026-09-04 |
| Wrapper template | `https://github.com/vitor251093/porting-kit-wrappers/releases/download/Wineskin-3.0.6-2/Wineskin.app.tar.7z` | 53,110,672 | `fbe276bba96d5582b99c511117abb1e035a988b8c1aeefe27c32df266a07907a` | 2025-11-06 |
| Steam's installer | `https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe`; the same file at `cdn.akamai.steamstatic.com` | 2,380,800 | `7d3654531c32d941b8cae81c4137fc542172bfa9635f169cb392f245a0a12bcb` | 2024-05-20 |

- The three GitHub rows are from GitHub's releases API, read twice (the planner and the security lens). The
  engine archive Porting Kit left on the Studio has the first row's size and sha256, and the template was
  downloaded and matches its row (both measured).
- Both releases can be changed by their owners. The engine's tag, `wineskin`, is a rolling release of 300
  files. The template's release was published on 2025-10-27 and its file uploaded ten days later, so that
  tag has changed once too. Neither repository has a licence file or says anything about other programs
  fetching its files. Wineskin's source is LGPL-2.1; Wine is LGPL-2.1-or-later; DXMT v0.80 is MIT.
- Steam's installer is at the address Valve's own download button uses. The file downloaded in the probe
  has the size above and the sha256 Microsoft's winget manifest records for Steam 2.10.91.91. It is an NSIS
  installer; it starts `MZ` and holds the bytes `Valve Corp`. Valve publishes no checksum, and the address
  is not versioned: the file can be replaced in place.

### 1.4 The probe (measured)

What ran, three times on clean scratch wrappers in `~/Applications`, with no Porting Kit app involved:
Porting Kit's unpacked copy of the template copied; the engine archive unpacked with `/usr/bin/tar -xf` and
moved to `Contents/SharedSupport/wine`; `Contents/MacOS/wineskinlauncher WSS-wineprefixcreate`, the call
Wineskin Winery itself makes (`Wineskin_WineryAppDelegate.m:931-996` in
`The-Wineskin-Project/wineskin-source`); `wine64 SteamSetup.exe /S`; Steam started as
`make-steam-shortcut.sh:185` starts it.

| | Run 1 | Run 2 | Run 3 |
|---|---|---|---|
| Engine unpacked by `/usr/bin/tar` (5,220 entries, 802 MB) | 6 s | 6 s | 6 s |
| Prefix: exit code, time | 0, 31 s | 0, 27 s | 0, 26 s |
| `SteamSetup.exe /S`: exit code, time | 0, 6 s | 0, 7 s | 0, 6 s |
| First start of Steam | fatal after 25 s | fatal after 25 s | fatal after 25 s |
| A later start | start 2: sign-in window after 51 s | start 2: client up after 35 s, sign-in window 10 s later | start 3: client up after 20 s, sign-in window 10 s later |
| `steam.exe -shutdown` at the sign-in window | exit 0, gone in 2 s | exit 0, gone in 2 s | exit 0, gone in 3 s |

- **The first start of Steam in a new prefix failed 3 times out of 3.** The installer Valve serves is from
  2024. Its updater downloads the first stage, logs `Error: Download of package (...) failed after 0 bytes`
  one to three times, and stops at a box headed "Steam - Fatal Error" that stays until something ends it.
  The last line of `logs/bootstrap_log.txt` was one of these two, exactly:
  `Error: Failed to determine download location for universe 1` (runs 1 and 3) and
  `Error: Steam needs to be online to update. Please confirm your network connection and try again.` (run 2).
  Started again, Steam carries on: the log shows the updater of 2024, then of January 2026, then of October
  2026, then the sign-in window. A start that works logs no `Error:` line.
- Run 3 was the whole mechanism unattended, from nothing to the sign-in window and Steam shut down again,
  in 111 s, from a local copy of the template and a local archive: no download was in it. Its start 2 was a
  false "Steam is gone": while the updater replaced itself, one poll found no Steam process holding the
  prefix. How long that gap lasts was not measured (NL1 records it).
- A wrapper made this way is 3.1 GB with Steam updated (engine 802 MB, template 215 MB, prefix 336 MB,
  Steam 1.7 GB). Renamed afterwards, it still brought Steam to the sign-in window, in 21 s. Its prefix has
  `drive_c/users/Wineskin` and a link from the Mac user's name to it, as the real wrapper has. The prefix
  step's output ends with `chmod: .../Contents/wine: No such file or directory`, at exit 0.
- `wineserver -k` without the library path exits 134 (`libinotify.0.dylib` not loaded); with it, 0.
- With `winemenubuilder.exe=d` the Desktop was unchanged. The template launcher writes the bundle's name
  and identifier into its `Info.plist` from the folder name at the time the prefix is made. Its output
  holds the Mac user's name four times, as home paths and as `drive_c/users/<name>`.
- **The two archives are different things under one file type.** The engine is XZ data: one `tar -xf`
  unpacks it. The template is a real 7-Zip file holding one file, `Wineskin.app.tar` (226 MB): `tar -xf`
  gives that file in 2 s, and a second `tar -xf` gives `Wineskin-3.0.6-2.app` (215 MB). Unpacked plainly,
  1,037 of its files carry `com.apple.quarantine` (written by the packager's own unarchiver and stored in
  the archive). Unpacked with `--no-mac-metadata` none does, and every file equals Porting Kit's copy (which
  only adds 1,045 `._` files). The template holds `libfreetype`, `libgnutls` and `libinotify` in
  `Contents/Frameworks`; its launcher is an Intel program, ad hoc signed.
- A file fetched with `curl` carries no quarantine attribute.
- **Not measured, and so live steps:** a sign-in, a game install, the game starting from such a wrapper,
  whether Steam outlives its Terminal window (NL1); what macOS does with the downloaded app (NL2); the
  Rosetta and Command Line Tools stages, which both Macs already have (2.9).

### 1.5 What macOS does with a downloaded installer (read 2026-11-10)

- Since macOS 15 a blocked item can no longer be opened with Control-click then Open. The user tries to open
  it once, then presses Open Anyway under System Settings, Privacy & Security, within about an hour, and
  gives the login password; Apple's page is the same for macOS 15, 26 and 27
  (`support.apple.com/guide/mac-help/mh40616`, `developer.apple.com/news/?id=saqachfa`).
- Whether Open Anyway works for a double-clicked script file is not documented, and one user on macOS 15
  reported that it did nothing (`discussions.apple.com/thread/255806364`). For an app it is the documented
  path. This is why the front door is an app (2.5). That it works for an app whose program is a script is
  a reasonable reading, not a measurement: NL2 measures it on macOS 27.2.
- A file fetched with `curl` is not quarantined, and Gatekeeper acts on quarantined items
  (`developer.apple.com/forums/thread/666452`, `/765139`; the two forum pages were read by the researcher
  and could not be re-read by the security lens). An app built on the Mac itself opens with no question
  (`eclecticlight.co/2024/08/10/gatekeeper-and-notarization-in-sequoia/`). Whether a file written by a
  quarantined app is itself quarantined has no primary source: NL2 reads the attribute.
- A script cannot be notarized; an app can, with a Developer ID certificate: 99 USD a year, issued in the
  holder's legal name (`developer.apple.com/programs/enroll/`). Declined (K3).
- macOS 26.4 and later can refuse a pasted Terminal command with "Possible malware, paste blocked"; the user
  can override it, and the trigger is not documented
  (`helpnetsecurity.com/2026/03/31/apple-macos-clickfix-attacks-terminal-warning/`). NL4 measures the
  pasted line.

## 2. Design

### 2.1 The parts

| File | What it is |
|---|---|
| `cities-skylines-2/scripts/make-wrapper.sh` (new) | Makes the Wine wrapper from the two public archives, with no Porting Kit app |
| `cities-skylines-2/scripts/install.sh` (new) | From nothing to playable: six stages, each skipped when already done, ending in setup |
| `install.sh` at the root (new) | For a Mac with no checkout: fetches the repository and hands over to a game's `scripts/install.sh` |
| `common/make-installer-app.sh` (new) | Builds the double-click app and its ZIP. The app is not in the tree |
| `cities-skylines-2/scripts/setup.sh` (changed) | One new option, two variables read, a helper for printed paths, three hint lines (2.6) |
| `common/test-launch-lock.sh` (changed) | The lock functions now have a third copy to hold identical |
| The guide, three READMEs, the root `CLAUDE.md`, `cities-skylines-2/GOTCHAS.md`, four pictures | 2.7 |

Someone with a clone can run `bash cities-skylines-2/scripts/install.sh` and never see the other two. Setup
keeps working alone, as today, for anyone who made a wrapper by hand. The three scripts that run on a
user's Mac (`make-wrapper.sh` and both `install.sh`) refuse to run as root (exit 1): `sudo` keeps `HOME`,
and root-owned files in a home folder break every later run. Every path they print has the home folder
written as `~`. What other programs print is left as it is: the template launcher's and Wine's output
(kept in a log, shown only on failure, and holding `drive_c/users/<name>`), and the paths printed by
setup's helpers (`cities-skylines-2/repatch.sh:45`, `:137`; `make-shortcut.sh:96`, `:259`;
`common/make-launcher-app.sh:54`, `:143`). So the guide says to look for the Mac's user name before
pasting Terminal output anywhere public (2.7).

### 2.2 `make-wrapper.sh`

```
bash scripts/make-wrapper.sh [--wrapper <path of the wrapper to make>] [--check]
exit 0 = made (or, with --check, could be made); 1 = refused or failed, said why, nothing left; 2 = a wrong option;
3 = another install is making a wrapper in that folder
```

1. The target is `--wrapper`, else `$CS2_WRAPPER`, else `~/Applications/CS2dxmt11.app` (ND5). It must be an
   absolute path whose last part matches `^[A-Za-z0-9._ -]+\.app$` (the template launcher writes that name
   into `Info.plist`), and it must not exist in any form (`-e` or `-L`): this script never replaces anything.
2. The target's folder: `~/Applications` is made if absent (a new account may not have it), except under
   `--check`; any other folder must exist. The folder, or under `--check` its nearest existing parent, must
   be found again under its own path in capitals: the test that the volume ignores case, made without
   writing anything (measured: on a case-sensitive disk image the capitals are not found, on the home
   volume they are). Setup and the launcher test `steam.exe` where Valve's installer writes `Steam.exe`.
   The volume must have 6 GB free (`df -k`). Each refusal says what it found.
3. Older build folders, `<folder>/.l1-wrapper.*`: one whose `pid` file names a live process is another
   install at work, and the script exits 3; any other is a build that died, and is removed. Then a build
   folder `<folder>/.l1-wrapper.XXXXXX` (`mktemp -d`) with this process's id in its `pid` file. The `EXIT`
   trap is set only once `mktemp` has succeeded; it ends the build prefix's `wineserver` (`wineserver -k`
   with the exports of step 8) and then removes the build folder. Everything below happens inside it.
4. Both archives of 1.3 are fetched with `curl --proto '=https' --tlsv1.2 -fL --retry 2`, with a progress
   bar when standard output is a terminal. The address, byte count and sha256 of each are six constants at
   the top of the script. A fetch that fails with an HTTP error says the file is no longer published at
   that address and asks for an issue; any other failure says to check the network. A file whose size or
   `shasum -a 256` differs is deleted and the script stops with both checksums and a request to open an
   issue. `L1_DOWNLOADS=<folder>` names a folder of already downloaded archives: a file there of the right
   name is copied into the build folder, and the copy is used only if its size and sha256 match; otherwise
   it is dropped with a line saying so and the file is fetched. (For the tests and the live steps, as
   `L1_WINDOW_SRC` is for the window's.)
5. The template, as measured: `/usr/bin/tar -xf` into `t1/`. If that gives exactly one file ending `.tar`,
   it is unpacked again with `/usr/bin/tar --no-mac-metadata -xf` into `t/`; if it gives an app directly,
   that is used. Any non-zero `tar` exit is a failure. Then `xattr -dr com.apple.quarantine` on the result,
   the call Wineskin Winery makes at this point: a no-op after `--no-mac-metadata`, and the second of two
   guards against a launcher macOS would refuse to run. The result must be exactly one `*.app`, a real
   folder, with `Contents/MacOS/wineskinlauncher` executable and `libfreetype`, `libgnutls` and
   `libinotify` under `Contents/Frameworks`. It is renamed, inside the build folder, to the target's own
   name, so that step 7 writes the right name into `Info.plist`.
6. The engine: `/usr/bin/tar --no-mac-metadata -xf` into `e/`. It must hold `wswine.bundle/bin/wine64` and
   `bin/wineserver`, executable. `wswine.bundle` is moved to `Contents/SharedSupport/wine`.
7. The prefix: `Contents/MacOS/wineskinlauncher WSS-wineprefixcreate`, its output sent to a file in the
   build folder. It must exit 0 and leave `prefix/system.reg`, `prefix/drive_c/windows` and
   `prefix/drive_c/users/Wineskin`. Then `wineserver -w`, so that nothing of the build is still running.
8. `wine64 --version`, with `WINEPREFIX` and `DYLD_FALLBACK_LIBRARY_PATH` exported as the launcher exports
   them (`launch-cs2-dxmt11.sh:96`, `:98`), must print a line starting `wine-`.
9. The target is tested again for existence; then the bundle is moved to it with `mv`; then
   `<target>/Contents/MacOS/wineskinlauncher` must exist. (A target that appeared in between is refused
   before the move, or shows as a missing launcher after it: `mv` onto a folder nests the bundle.)
10. It prints the wrapper's path and size, and one credit line: the engine and the template are Porting
    Kit's, with its address.

When a step fails, the last twenty lines of that step's output are printed, home folder as `~`. `--check`
does steps 1 and 2 without writing anything, says what it would download, and exits 0 when the wrapper
could be made and 1 when not.

### 2.3 `cities-skylines-2/scripts/install.sh`

```
bash scripts/install.sh [--check] [--yes] [--desktop] [--no-setup]
exit 0 = done; 1 = a stage failed, said why; 2 = a wrong option; 3 = stopped at a question (answered no, or
nobody to ask) or because the game or another install is running; 4 = it cannot go on by itself: open the
installer again to carry on. --check exits 0 after its report, or 1 or 3 for the refusals that come before it.
```

It opens with three lines: what is needed (a Steam account that owns Cities: Skylines II, about 105 GB
free, and time for a download of about 100 GB), that it can be opened again at any point to carry on, and
that it keeps the Mac awake while it runs (`caffeinate -i -w $$ &`, not under `--check`). Each stage then
prints one line, `Step n of 6`, with its name and `OK`, or what it is doing. A stage whose result is
already there is skipped, so running it again after any stop carries on from where it stopped, and running
it on a finished install is the way to update (stage 6 runs every time). It ends with one of three lines,
by exit code (not under `--check`, which ends with its report, or `--no-setup`, which ends with "Stopped
before step 6, as asked."): 0, "Done. Start the game from Applications: Cities Skylines II, or 14unch3r."; 4, what
stopped and "Open the installer again: it carries on from here."; anything else, "The install stopped. The
lines above say why. Open the installer again to carry on from that step."

**Which wrapper.** Before stage 1 the script works out the wrapper, once, with a copy of the launcher's
own `find_wrapper` (1.2), which NT3 holds identical to the launcher's:

- `CS2_WRAPPER` set: that path, made in stage 3 if it does not exist.
- The function finds `~/Applications/CS2dxmt11.app`: that.
- It finds another wrapper that holds `Cities2.exe`: that, with a line naming it. (This is the install
  under another name, which the guide allows at `:39-40`, and the launcher would pick it too.)
- It finds nothing, or a wrapper that does not hold the game (someone's other `CS2.app`): the wrapper is
  `~/Applications/CS2dxmt11.app`, to be made. The launcher prefers that name to every other.

`CS2_WRAPPER` must be an absolute path, or the script exits 2. A wrapper that exists is resolved (`cd`
and `pwd -P`); one still to be made is used as given, and resolved once stage 3 has made it. The result is
exported as `CS2_WRAPPER` for everything after, so setup uses the same one, and `WINEPREFIX` is set from
it. No copied function is called while `WINEPREFIX` is empty: an empty pattern makes `_owns` match every
process (measured). A wrapper that exists must have an executable `wine64` and `wineserver` and a prefix
folder; if not, the script says it looks incomplete, to move it to the Trash and open the installer again,
and exits 1. It deletes nothing. If the wrapper exists and the game is running in it (the launcher's
`game_running`, `:190`), it says to quit the game and open the installer again, and exits 3.

**The lock.** From stage 4 to the end it holds `<prefix>/.launcher.lock`, with copies of the launcher's
`LOCK=` line and `lock_holder`, `acquire_lock` and `release_lock` (`:200-217`), called as `acquire_lock 1`:
one try, 2 s (measured). Held by a live process, it says another launch or install is using this wrapper,
and exits 3. `acquire_lock` needs `step`, `die` and `game_running`: in this script `step` prints nothing
and `die` prints its line and exits 3. Released by the `EXIT` trap. `common/test-launch-lock.sh` gains
this script as a third file whose copies must be identical (measured: it takes a third file and stays
green).

| # | Stage | Done when | What it does otherwise |
|---|---|---|---|
| 1 | This Mac | `setup.sh --mac-only` exits 0 | `setup.sh --mac-only`, with `--yes` and `--check` passed on (2.6), prints the Mac's lines and asks its one question on a Mac outside what has been tested. Exit 1 there means Rosetta is missing: the script says what Rosetta is, that the game cannot run without it and that installing it accepts Apple's licence for it; it asks `[y/N]`, and on `y` (or with `--yes`) runs `softwareupdate --install-rosetta --agree-to-license` and runs `--mac-only` again. On anything else, or with no terminal, it prints the command and exits 3 |
| 2 | Apple's Command Line Tools | `xcode-select -p` succeeds, and then the `python3` test of `setup.sh:121` passes (that order: without the tools, running `python3` itself opens Apple's window) | If `xcode-select -p` succeeds and the `python3` test fails, the tools are installed but broken: it says so and exits 1, without asking Apple for them again. Otherwise it runs `xcode-select --install`, says that a box from Apple has opened, perhaps behind this window, to press Install and then Agree there, and that this window goes on by itself; polls every 5 s for up to 60 minutes. On time-out (which is also what pressing Cancel in Apple's box leads to) it exits 4 |
| 3 | Wine | the wrapper exists | `make-wrapper.sh --wrapper <the path>`; its failure is this stage's, and its exit 3 is passed on |
| 4 | Steam for Windows | `Steam/steam.exe` or `Steam/Steam.exe` is in the prefix | Below |
| 5 | The game | `Cities2.exe` exists | Below |
| 6 | The Mac fixes and the game's app | never skipped | Below |

Before stage 3 it prints the free space of the home volume beside what the game takes; under 110 GB free
this is a `CAUTION` line, not a stop.

**Stage 4.** Steam's installer is fetched into a `mktemp -d` folder (removed after) with the `curl`
options of 2.2, from the first address of 1.3 and, if that fails, the second. The file must be larger than
1 MB, start with `MZ` and contain the bytes `Valve Corp`: this catches a wrong file (an error page, a cut
download), not a forged one (ND8). Its sha256 is printed; when it is not the one of 1.3, a `CAUTION` line
says it is a newer installer than the one this was tested with. Then `wine64 SteamSetup.exe /S`, with the
launcher's exports (`:95-98`, `:101`) and `WINEDLLOVERRIDES=winemenubuilder.exe=d`, then `wineserver -w`,
then the test of the "done when" column.

**Stage 5.** Three states, read from `Cities2.exe` and `StateFlags` in `appmanifest_949230.acf` with a
copy of the launcher's `acf_field` (`:302-304`):

- **Installed** (`Cities2.exe` present, `StateFlags` 4): the stage is done.
- **Update waiting** (`Cities2.exe` present, `StateFlags` with its bit 4 set and another bit too, for
  example 6): it says "Steam has a game update waiting. The game's app offers it at the next start." and
  the stage is done. Updates are the launcher's (`:297-379`).
- **Not installed** (`Cities2.exe` absent; or present with no manifest, or with a `StateFlags` that lacks
  bit 4, which is a first download that stopped part way, for example 1026): the steps below.

1. *Steam up.* "The client is up" means a `steamwebhelper` process holds the prefix (the launcher's
   `webhelper_up`, a copy). "A Steam process" means a process whose command matches `[Ss]team\.exe`, not a
   web helper, holds the prefix: the launcher's `steam_exe_up` matches lower case only and would miss the
   first starts. If the client is up, go to step 3. If a Steam process is there without the client for
   twelve polls (60 s), it is stuck at its box: end it and start. Otherwise start.
2. *Starting, at most five times.* Remove a stale `.crash` (`:260-261`); note the length of
   `logs/bootstrap_log.txt`; start Steam (`steam.exe`, else `Steam.exe`) in its own process group with
   hang-up ignored, so that Control-C or closing the window does not reach it:
   `set -m; ( trap '' HUP; exec "$WINE" "$STEAM_EXE" -no-cef-sandbox ) </dev/null >/dev/null 2>&1 & disown; set +m`.
   Then poll every 5 s. The client up: done. A new log line matching
   `Error: (Failed to determine download location|Steam needs to be online)`: end this Steam and start
   again. No Steam process for three polls in a row: start again. Ten minutes without the client: end it
   and start again. "End" is `wineserver -k`, then a wait of up to 10 s until nothing holds the prefix.
   After five starts the stage ends Steam, prints the last twenty log lines and exits 1. With
   `L1_TRACE=<file>` each poll of steps 1, 2 and 4 writes one line there: the time, the count of Steam
   processes holding the prefix, and whether the client is up (for NL1).
3. *What to do*, printed once (the words are 2.7's).
4. *Waiting*, with no time limit, polling every 5 s. `Cities2.exe` present and `StateFlags` 4: go on. No
   manifest yet: one line, "Waiting for you to choose Install in Steam". A manifest with `BytesToDownload`
   0: one line, "Steam is getting the download ready". Otherwise a line each time the whole percent
   changes: `BytesDownloaded` of `BytesToDownload`, in GB with one decimal (computed by `awk`; the divisor
   is never 0 here). No Steam process and no client for three polls in a row: it says Steam closed before
   the game finished downloading, and exits 4.
5. *Closing Steam*, as the launcher does it (`:392-424`): `steam.exe -shutdown`; up to 20 s for the Steam
   process to go; if it is still there, `wineserver -k` and up to 10 s more; then the sweep of everything
   still holding the prefix (the launcher's `steam_family`, a copy): `wineserver -k`, 2 s, a plain `kill`
   of what is left. Never `kill -9`. Last, `wineserver -w` for up to 15 s, so stage 6 meets no Wine
   process. Every `wineserver` call is made with `${WINEPREFIX:?}`.

Any exit 1 from stage 5 ends Steam first.

**Stage 6.** If the game is running, exit 3 as above. If the checkout's own files are gone (a temporary
checkout can be cleaned by macOS during a wait of days): `scripts/setup.sh`, `repatch.sh`, `patches/` and
`../common/make-launcher-app.sh` are tested, and a missing one is exit 4. Then `setup.sh`, with `--yes`
and `--desktop` passed on when given and `CS2_VIA_INSTALLER=1` in its environment (2.6). Its exit code is
this script's. With `--no-setup` the script stops before this stage and says so.

`--check` prints the state of every stage and what it would do. It starts nothing, downloads nothing,
asks nothing and changes nothing; with Rosetta missing it says so and that it would be offered. It exits 0
after its report; as root it exits 1, and with the game or another install running 3, as without it.

**Copies held together.** `find_wrapper`, `_owns`, `webhelper_up`, `steam_family`, `game_running` and
`acf_field` are copies of the launcher's functions; NT3 cuts each out of both files and requires them
equal. The `LOCK=` line and the three lock functions are held by `common/test-launch-lock.sh`. The `python3` test line is
compared with `setup.sh:121`. The Steam-process test and the start and shutdown sequences are this
script's own, for the reasons given in stage 5.

### 2.4 `install.sh` at the root

```
/bin/bash -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/macgameport/1launcher/release/install.sh)"
bash install.sh [<game folder> [<ref>]] [options for the game's installer ...]
```

- The whole body is one function, `main`, called on the last line: a download cut short then runs nothing.
- Leading words that do not start with `-` are the game (default `cities-skylines-2`) and the ref (default
  `release`); everything from the first option on goes to the game's installer. The game must match
  `^[a-z0-9][a-z0-9-]*$`. The ref must match `^[A-Za-z0-9._/-]+$`, must not start with `-` or `/`, and
  must hold neither `..` nor `//` (measured: without this a ref can lead `curl` to another repository).
  A bad one is exit 2 with nothing fetched.
- **The clone's case** is decided by `${BASH_SOURCE[0]:-}` alone: when it names an existing file with
  `<game>/scripts/install.sh` in the same folder, that installer is run, a line says this checkout is being
  used, and the ref is ignored. Under `bash -c` the variable is empty (measured), so the pasted line and
  the app always fetch, whatever folder Terminal is in.
- Otherwise it fetches `https://github.com/macgameport/1launcher/archive/<ref>.tar.gz` into a `mktemp -d`
  folder with the `curl` options of 2.2 and unpacks it with `tar -xzf`, whose non-zero exit is a failure.
  The result must be exactly one top entry, a real folder and not a link, holding
  `<game>/scripts/install.sh`. A game folder without that file gets a line naming the games that have one.
- It prints the commit it fetched, read from the archive's own header (`comment=<40 hex digits>` in the
  first 1024 bytes of the unpacked stream; measured at byte 515), or "commit not read". GitHub serves the
  script itself from a cache of up to five minutes, so for that long after `release` moves, the script and
  the archive can be one commit apart; the commit printed is the archive's.
- It exports `L1_FETCHED_REF=<ref>` (2.6), runs the game's installer with the remaining arguments, removes
  the temporary folder whatever the result (an `EXIT` trap), and exits with the installer's code.
- The pasted form is the one above, not `curl ... | bash`: with a pipe the script's questions would have no
  terminal to read from. To pass options with it, the words after the closing quote are the script's name
  and then its arguments: `1launcher-install cities-skylines-2 release --check`. A third leading word that
  is not an option is exit 2.

### 2.5 The installer app

`common/make-installer-app.sh --dest <folder> --game <folder> [--ref <ref>] (--icns <file> | --no-icon)`
writes `<dest>/Install <title>.app` and its ZIP (`ditto -c -k --keepParent`; the name with hyphens for
spaces), and prints the ZIP's size and sha256. The title is the game's row in `common/games.tsv` without
its colon: `Install Cities Skylines II.app`, `Install-Cities-Skylines-II.zip`. The ref defaults to
`release` and is checked by 2.4's rule. An icon must be given or expressly declined: a published app is
never built without one by accident. It builds in a hidden folder inside `--dest` and swaps the finished
bundle in, and replaces only a bundle carrying its own marker line and identifier,
`local.1launcher.installer` (the rule of `common/make-launcher-app.sh:15-19`).

The bundle holds three files: `Contents/Info.plist` (with `LSArchitecturePriority` naming `arm64`, so that
macOS does not offer Rosetta for a script's sake; not verified, and harmless), the icon (ND6), and
`Contents/MacOS/install`, a bash script with the game, the ref and the title written in at build time
(below as `<game>`, `<ref>` and `<title>`):

```bash
#!/bin/bash
# Generated by common/make-installer-app.sh -- run that again instead of editing this file.
D="$(mktemp -d "${TMPDIR:-/tmp}/1launcher-install.XXXXXX" 2>/dev/null)" \
  || D="$(mktemp -d /tmp/1launcher-install.XXXXXX 2>/dev/null)" || {
  osascript -e 'on run a' -e 'display alert ("Install " & item 1 of a) message "A temporary folder could not be made. Restart the Mac, then open the installer again." as critical' -e 'end run' -- "<title>"
  exit 1
}
C="$D/Install <title>.command"
cat > "$C" <<'EOS'
#!/bin/bash
trap 'rm -f "$0"; rmdir "$(dirname "$0")" 2>/dev/null' EXIT
clear
echo "Fetching the installer from github.com/macgameport/1launcher ..."
S="$(curl --proto '=https' --tlsv1.2 -fsSL "https://raw.githubusercontent.com/macgameport/1launcher/<ref>/install.sh")"; rc=$?
if [ "$rc" = 0 ]; then
  /bin/bash -c "$S" 1launcher-install <game> "<ref>"
elif [ "$rc" = 22 ]; then
  echo "This installer has been withdrawn or has moved. The guide has the current one:"
  echo "  https://github.com/macgameport/1launcher/blob/main/<game>/INSTALL.md"
else
  echo "GitHub could not be reached. Check the network, then open the installer again."
fi
echo; echo "You can close this window."
EOS
chmod +x "$C"
open -a Terminal "$C"
```

- **The app holds no code of the repository (ND7).** It fetches `install.sh` of its ref each time, so one
  published app keeps installing the current release, and opening it again later is the update.
- The `.command` file is written fresh, not copied out of the bundle: a copy would carry the bundle's
  quarantine attribute, and Terminal would be stopped a second time. It removes only itself, and then its
  folder if that is empty: a recursive delete in a file that can be copied anywhere and opened is how a
  Desktop gets deleted.
- The word after `"$S"` is the script's `$0`, and is not a path: the clone's case of 2.4 can never be met
  by accident.
- The app reads and writes nothing inside its own bundle, so it does not matter that macOS runs a
  downloaded app from a read-only copy elsewhere.
- First open, as the guide describes it (2.7): macOS says it could not verify the app; the user presses
  Done, opens System Settings, Privacy & Security, presses Open Anyway and confirms. NL2 measures this. If
  the app cannot be approved this way, it is not published and the guide keeps the pasted line as the one
  way in (ND1), which is built and tested either way.
- The ZIP is the one asset of a GitHub release tagged `installer-1`, created with `--latest=false` (ND9),
  at NL3 and on James's word. The guide links
  `https://github.com/macgameport/1launcher/releases/download/installer-1/Install-Cities-Skylines-II.zip`.
  A later change to the app is `installer-2`: a published tag is never moved
  (`docs/plans/local-files-layout.md:146`).

### 2.6 `setup.sh`

- `--mac-only`: after the macOS lines (`:71-92`) it stops. Rosetta missing: the "prerequisite(s) missing"
  lines and exit 1. A caution: the caution paragraph (`:132-137`), then its question (`:139-142`), asked as
  today only with a terminal and without `--yes`, and never with `--check`; then exit 0. Otherwise exit 0.
  It is in `--help`.
- `CS2_VIA_INSTALLER=1` in the environment: the question of `:139-142` is not asked again (stage 1 asked
  it; the lines are still printed), and two lines speak of the installer instead of setup: `:260` becomes
  "no shortcut made. To add one, open the installer again and answer y", and `:287` "After a game update:
  open the installer again (updates reset the patched DLLs)."
- `L1_FETCHED_REF` set: the checkout is a temporary one. `:67` prints
  `repo: a temporary copy of macgameport/1launcher at <ref>`; `:128` prints the guide's `https://` address;
  `:204-206` says to open the installer again, which fetches the current scripts, where it now says to
  update this checkout with `git pull`.
- Every path setup itself prints (`$DEST` at `:146`, the wrapper where it is printed whole) goes through
  one helper that writes the home folder as `~`. Its helpers' own lines (2.1) are not changed.
- The three hint lines (`:104`, `:116`, `:118`) gain "or run bash scripts/install.sh, which does this for
  you", without backticks: they are inside double quotes. The header's "cannot be scripted" (`:4-6`) is
  replaced by one line naming `install.sh`.
- Nothing else changes, and the sixteen mutants of `test-setup.sh` must still apply and still be red: each
  refuses with exit 2 when its line is no longer there. (The builder lens made these changes in a scratch
  copy and saw all sixteen red.)

### 2.7 The guide, its pictures, and the other documents

**The guide** gains a first section, "The quick way". It lands in two commits (3, N6): first with the
pasted line as the way in; then, once the release exists, leading with the app.

1. What is needed: an Apple Silicon Mac on macOS 26 or 27, a Steam account that owns the game, about
   105 GB free, and that the installer downloads from three places (Porting Kit's two files on GitHub,
   Valve's installer) and from Apple if Rosetta or the Command Line Tools are missing.
2. Download the installer (the ZIP's link) and double-click "Install Cities Skylines II". If the browser
   left a `.zip`, double-click that first. macOS says it was not opened: press Done, not Move to Trash.
   *Picture 1.*
3. Open System Settings, Privacy & Security, scroll to the bottom, and press Open Anyway beside its name.
   The button is there for about an hour. Press Open Anyway again and give the Mac's password. macOS asks
   this once. *Picture 2.*
4. A Terminal window opens: that is the installer. It works through six steps and says what each is
   doing. Leave it open.
5. When Steam's sign-in window appears, sign in with the account that owns the game, with "Remember me"
   ticked. Steam may ask for a code from email or the Steam app. *Picture 3.*
6. In Steam, click Library, then Cities: Skylines II, then Install. Do not press Play there: it does not
   work from inside Steam. *Picture 4.* The download is about 100 GB. When it finishes the installer
   closes Steam by itself and finishes the last step.
7. Play from Cities Skylines II in Applications, or from 14unch3r.

Under the list: the pasted line as the other way in, and what to do if Terminal says "Possible malware,
paste blocked"; that the installer runs Porting Kit's Wine and Valve's installer as they come, with no
check by macOS, the first against fixed checksums; that opening the installer again carries on after any
stop and is also how to update; and that Terminal's output can show the Mac's user name inside file paths,
so to look for it before pasting the output anywhere public.

**The installer's words in Terminal**, stage 5 step 3:

```
Steam for Windows is starting. A small box headed "Steam - Fatal Error" can appear once or twice
and close again. That is expected: Steam is updating itself. Click nothing in it.
When Steam's sign-in window appears:
  1. Sign in with the Steam account that owns Cities: Skylines II. Tick "Remember me".
     Steam may ask for a code from your email or the Steam app on your phone.
  2. Click Library, then Cities: Skylines II, then the blue Install button, then Install.
     The download is about 100 GB and takes hours.
  3. When it finishes Steam shows a green Play button. Do not press it: it does not work from
     inside Steam. This window sees the download finish, closes Steam, and goes on to step 6.
Leave this window open. The Mac is kept awake while it runs.
```

The last line says "leave this window open" until NL1 has measured what closing it does; if Steam is shown
to outlive the window, it may say that closing it and opening the installer again later is safe.

**The four pictures**, in `cities-skylines-2/docs/images/`, each with a row in that folder's `AUDIT.md`
(what is visible, and the file's sha256 prefix; `check-experiments.py` enforces it):

| # | What | From | Kept out of it |
|---|---|---|---|
| 1 | macOS's "not opened" message for the app | NL2 | nothing personal is on it |
| 2 | Open Anyway in System Settings | NL2 | the password box, which shows the Mac's user name |
| 3 | Steam's sign-in window | the probe's capture | the QR code is covered with a plain box: it is a sign-in token, expired, and not ours to publish |
| 4 | The Install button on the game's page in Steam | NL1 | a crop to the button: no Steam name, no library |

**The rest of the guide.** Its numbered sections 1 to 5 stay, under one new sentence saying they do the
same by hand, so the anchors and setup's hints still point at something. Its size line (`:14`) and the
installer use one number: about 100 GB with all DLC (103 GB by Steam's count on the test Mac). "After a
game update" (`:284-313`) gains: or open the installer again. Uninstall (`:333-342`) gains one sentence:
Rosetta and Apple's Command Line Tools stay, and are Apple's to remove.

**Other documents.**

- The root `README.md` quick start (`:26-44`) and `cities-skylines-2/README.md`'s (`:25-37`, the page
  14unch3r's "not set up" tiles open, `common/games.tsv`) lead with the installer; the three `git clone`
  lines stay as "with git".
- `cities-skylines-2/scripts/README.md`: rows for the two new scripts and their tests.
- The root `CLAUDE.md`: a `Layout` row for the root `install.sh`; `common/` gains the installer builder
  and its test; and a short "Published addresses" paragraph. It says that `release/install.sh`,
  `cities-skylines-2/scripts/install.sh` and the repository's own name are fetched by every published
  installer and every pasted line, so the files are never moved without a forwarding file left behind, and
  the names `macgameport` and `1launcher` are never renamed or given up (a freed name can be claimed by
  anyone); that `release` only moves forward, by a deliberate push after the tests and on James's word,
  never by the automatic push to `main`; and that installer apps are released as `installer-<n>` with
  `--latest=false`. No new place outside the repository (ND10).
- `docs/plans/local-files-layout.md`: one pointer line. Its `v0.1.0` is "the first numbered release"
  (`installer-1` may come first), its tag tests leave `installer-*` tags alone, and once its L1 lands a
  plain setup also moves the install folder, which stage 5's last `wineserver -w` already allows for.
  Whichever of the two plans is built second gets a fitted re-check.
- `cities-skylines-2/GOTCHAS.md`: four entries, each with its measurement: the first start of Steam in a
  new prefix fails and a later one works; the two archives are XZ and 7-Zip under one file type, and the
  template carries a quarantine attribute inside it; `wineserver` needs the library path too; and what
  NL1 finds about Steam and a closed Terminal window.
- This plan's as-built header.

### 2.8 The release branch

`release` is an ordinary branch of this repository that always points at a commit of `main`. It is created
at NL3 and moved only by `git push origin <commit>:release`, a fast-forward, after the test suites pass on
that commit and on James's word; never by force. Until it is moved, a push to `main` reaches nobody who
uses the installer. After a game update that needs new patches, the fix reaches them when `release` is
moved, and the guide's "After a game update" says so. Protecting the branch on GitHub against forced and
deleted pushes, and turning on immutable releases, are settings James changes at NL3 if he wants them.

### 2.9 What this plan leaves alone, and what it cannot test

- The Wine 11.16 engine build (the guide's section 6) stays a separate, optional hour. Surviving Mars
  needs CrossOver and has no installer. 14unch3r's "not set up" tiles keep opening a guide page. Where an
  install keeps its files (`~/cs2-patch`) and the first `v`-numbered release are
  `docs/plans/local-files-layout.md`'s.
- `steam://install/949230`, which might open Steam's install box by itself, is measured at NL1 and built
  only in a later slice if it works.
- Nothing watches the two pinned files. If Porting Kit removes or changes one, every new install stops at
  stage 3 with the message of 2.2 step 4 until `release` carries a new pin. NL3's note asks whether old
  engines are kept. A scheduled check of the two addresses is a follow-up, not part of this.
- Stages 1 and 2 are tested with stubs only: Rosetta and Apple's tools are installed on both of the
  maintainer's Macs, for every account, so no live step can reach them.
- A Steam library on another drive hides the game from stage 5 and from setup, as today.
- A wrapper under another name is found by the installer and the launcher, but the mod badge patch only
  knows `~/Applications/CS2dxmt11.app` (`setup.sh:169-170`, and setup says so at `:176-177`), as today.

## 3. Steps

| # | What | Tests |
|---|---|---|
| N1 | `make-wrapper.sh` | NT1 |
| N2 | `setup.sh`: `--mac-only`, the two variables, the path helper, the hint lines | NT2 |
| N3 | `cities-skylines-2/scripts/install.sh`, and its copy of the lock in `common/test-launch-lock.sh` | NT3 |
| N4 | The root `install.sh` | NT4 |
| N5 | `common/make-installer-app.sh` | NT5 |
| N6a | The documents of 2.7 with the pasted line as the way in; picture 3 | NT6, NT7 |
| N6b | The guide and the READMEs lead with the app; pictures 1, 2 and 4. Committed only after NL3's release exists | NT6, NT7 |

Built on a branch, `simple-install`, in a scratch worktree. N1 and N2 touch different files and can go in
either order; N3 needs both; N4 and N5 need N3's interface only. The builder lens's scratch build of N1 to
N5 (`/tmp/si-sim`, built from the plan before the fold) may be used as a starting point; every file in it
is to be brought to this text. New scripts are committed with mode 755, like their neighbours. Nothing is
merged, released or linked before NL3; NL2 needs the branch pushed to GitHub, as a branch only.

## 4. Test plan

Every test runs with `HOME` and `TMPDIR` at a scratch folder, on a scratch copy of the scripts (the form
of `cities-skylines-2/scripts/test-setup.sh:26-34`), with stubs on `PATH` that record their arguments and
the environment they were given. No network, no Wine, no real download. Each test file ends by comparing a
listing of everything outside its own scratch folder that it could have written (the real `~/Applications`
names and `/tmp` names made by the scripts under test) with the listing taken at its start
(`test-setup.sh:107`'s `snap`). Each mutant is applied to the scratch copy by a `sed` that refuses when it
did not apply, and must be seen red. The library path cannot be seen by a stub (1.2): NT1 and NT3 instead
grep the script under test for the launcher's export line, and NL1 shows the rest. Every test file greps
its scripts for the absence of `nohup`, `env `, `setsid` and `kill -9` on any line that is not a comment.

| # | Script | Cases | Mutants (each must exit 1) |
|---|---|---|---|
| NT1 | `cities-skylines-2/scripts/test-make-wrapper.sh` | A stub `curl` that copies fixture archives: the engine a tar under its `.tar.7z` name, the template a tar inside a tar, made from files that carry a quarantine attribute (`xattr -w`, packed by `/usr/bin/tar`); the pins rewritten in the scratch copy. **Made:** the wrapper is at the target with `wine/bin/wine64`, `prefix/system.reg`, `prefix/drive_c/users/Wineskin` and `Frameworks`; no file in it carries the quarantine attribute; the launcher stub was called once with `WSS-wineprefixcreate` from a bundle named as the target; `curl` was called twice with exactly the two addresses of 1.3, and the six constants in the real script equal the six literals written in the test. **Refused, with nothing made, no build folder left and `curl` not called:** the target exists as a folder, as a file, as a dangling link; a relative path; a name not ending `.app` or holding `/`-unsafe characters; a folder that does not exist (other than `~/Applications`, which is made); a folder on a 20 MB case-sensitive disk image made with `hdiutil` and mounted inside the scratch folder
(no administrator needed; measured); too little space (stub `df`); another build folder with a live `pid` (exit 3); run as root (stub `id`); a wrong option exits 2. **Failed, with nothing made and no build folder left:** `curl` fails with an HTTP error (the "no longer published" line) and otherwise (the network line); a wrong sha256 of the engine; of the template; a wrong size; a template with two apps, with no launcher, without `libfreetype`, without `libgnutls`, without `libinotify`; an engine without `wine64`; the launcher stub exits 1; it leaves no `system.reg`; no `users/Wineskin`; `wine64 --version` prints nothing; the target appears while the prefix is being made (the stub makes it). A stale build folder with a dead `pid` is removed and the wrapper made. `L1_DOWNLOADS`: a matching file is used and `curl` not called for it; a non-matching one is dropped and `curl` called. `--check` writes nothing, does not make a missing
`~/Applications`, and exits 0 or 1. The wrapper's path is printed with `~` | the sha256 not compared; an existing target replaced (step 1's test removed: caught by "`curl` not called"); step 9's second test removed (caught by "the target appears"); the build folder left behind on failure; a failed prefix still moved to the target; `L1_DOWNLOADS` used without the sha256; the bundle not renamed before the prefix is made; both quarantine guards removed; a live build folder removed; a pin changed in the script alone |
| NT2 | `cities-skylines-2/scripts/test-setup.sh`, new cases | `--mac-only`: exits before any wrapper line is printed; 0 on a tested Mac; 1 with Rosetta missing; on macOS 15 with a terminal (the `pty` helper, `:183`) asks and exits 0; with `--yes`, and with `--check`, does not ask. `CS2_VIA_INSTALLER=1` with a terminal on macOS 15: a full setup does not ask, and prints the two installer lines; without it, it asks and prints today's lines. `L1_FETCHED_REF=release`: the `repo:` line, the guide's address, and no "git pull" in the failed-patch lines. No line setup.sh itself prints (the `Installing launcher` line, the wrapper line, the `repo:` line) holds the scratch `HOME` whole; lines from `repatch.sh` and the builders are not asserted (2.1). The sixteen existing mutants, run again | 17: `--mac-only` goes on to the wrapper checks; 18: `CS2_VIA_INSTALLER` is ignored; 19: `--mac-only` exits 0 with Rosetta missing; 20: `L1_FETCHED_REF` is ignored; 21: the path helper returns its argument unchanged |
| NT3 | `cities-skylines-2/scripts/test-install.sh` | Recording stubs for `make-wrapper.sh`, `setup.sh`, `wine64`, `wineserver`, `curl`, `softwareupdate`, `xcode-select`, `python3`, `caffeinate`, `id`, `df`, `pgrep`, `ps`, `lsof` and `sleep` (which advances a scenario file and a clock, one line per poll); a fixture prefix; its own copy of a helper shaped like `ptya` (`test-setup.sh:233`), which types a given line, for the questions. **Wrapper rule:** for each fixture home (none; `CS2dxmt11.app`; `CS2.app` with the game; `CS2.app` without; the game under another name; two holding the game; `CS2_WRAPPER` set to a path with a space), the wrapper install.sh uses equals what the launcher's own `find_wrapper`, cut out of the launcher and run in the same home, answers once the wrapper exists, both sides resolved with `pwd -P` (`/tmp` is `/private/tmp`); a wrapper without `wine64`, and one without a prefix folder, exit 1 and nothing is deleted; a relative `CS2_WRAPPER` exits 2; a wrapper still to be made is passed to `make-wrapper.sh` as given and no copied function runs before it exists. **Copies:** the six functions of 2.3 equal the launcher's; the `python3` line equals setup's. **All done:** only setup runs, with `CS2_VIA_INSTALLER=1` and `CS2_WRAPPER` in its environment, and `--yes` and `--desktop` when given; the exit code is setup's (0, then 1); the closing line is the one for that code. **Nothing done:** the six stages in order. Stage 1: `--mac-only` exit 1 then `n`, Return, and no terminal each exit 3 with `softwareupdate` not called; `y` and `--yes` call it with exactly `--install-rosetta --agree-to-license`; still missing afterwards exits 1. Stage 2: `python3` is not run before `xcode-select -p` succeeds; tools present with a broken `python3` exit 1 and `xcode-select --install` is not called; `xcode-select --install` is called once, then the stage goes on when the stub starts to succeed; a time-out (the limit lowered in the copy) exits 4. Stage 4: the second address is tried when the first fails; a file not starting `MZ`, one without `Valve Corp`, one under 1 MB (each failing that one test only), an installer exit of 1, and no `steam.exe` afterwards each exit 1 before stage 5; an unknown sha256 prints the `CAUTION` line and goes on; `Steam.exe` alone counts as present; `wine64` was given `winemenubuilder.exe=d`. Stage 5: game present with `StateFlags` 4 skips it; with 6 prints the update line and goes to setup; present with no manifest, and present with 1026, take the not-installed path; a fatal line of each of the two kinds (the exact lines of 1.4) ends that Steam (`wineserver -k` recorded, with the fixture's prefix) and starts another; a one-poll gap does not start another, a three-poll gap does; exactly five starts are recorded before exit 1, and Steam is ended first; a stale `.crash` is gone before each start; a Steam process with no client for twelve polls is ended and started; ten minutes without the client ends that start and starts another; a client already up is not started again and goes straight to the words; no manifest prints the "choose Install" line once; `BytesToDownload` 0 prints the "getting ready" line and does not fall through; 41 percent prints one line for 41; the game arriving goes on, with `-shutdown` recorded before setup and no `wineserver` call without the prefix; a Steam still there after `-shutdown` gets `wineserver -k`, and a stray still holding the prefix after that gets a plain `kill`, never `-9`; `L1_TRACE` gets one line per poll; Steam gone for three polls exits 4 and setup is not run. Stage 6: a missing checkout file exits 4; the game running exits 3. Under 110 GB free prints the `CAUTION` line and goes on. `caffeinate` is started with `-i -w` and the script's own process id, and not under `--check`. Every path it prints has the home folder as `~`. **Guards:** the game running exits 3 before anything else; a live lock holder exits 3; the lock is released on exit; run as root it refuses. `--no-setup` stops before setup with its own line. `--check` records no call that changes anything and asks nothing, exits 0 with no closing "Done" line, with the tools missing does not run `python3`, and with Rosetta missing reports it and exits 0 | Rosetta installed on Return; setup run when the game is absent; the wrapper made when one exists; Steam's installer run when Steam is present; the fatal line not acted on; a one-poll gap restarts Steam; `-shutdown` left out; exit 0 when Steam is gone; `--check` starts Steam; the `MZ` test left out; the lock not taken; the running-game test left out; the update-waiting state treated as not installed; `BytesToDownload` 0 divides; `CS2_VIA_INSTALLER` not passed to setup; `winemenubuilder.exe=d` dropped; the `.crash` left; the start limit raised to six; a copied function changed in install.sh alone; the update state matched on any value other than 4; a client already up started again; the ten-minute limit removed; a copied function run with an empty `WINEPREFIX`; a broken `python3` sent to `xcode-select --install` |
| NT4 | `common/test-bootstrap.sh` | A stub `curl` serving a fixture `tar.gz` whose game installer records its arguments and environment. The pasted form (`bash -c "$(cat install.sh)"`), run from an empty folder and again from a folder that holds a game installer: both fetch the address of the ref, run the fixture's installer with the options passed on and `L1_FETCHED_REF` set, remove the temporary folder, and exit with the installer's code (0, then 7). As a file beside a game folder: `curl` is not called and the ref is ignored. `bash install.sh --check`: `--check` reaches the installer and the game is the default. A third leading word that is not an option exits 2. A ref holding a space, `;`, `..`, `//`, or starting `-` or `/`, and a game named `../x`, each exit 2 with nothing fetched. A failed fetch, a `tar` failure, an archive with two top folders, one whose top entry is a link, and a game without an installer each exit 1 with a line, and leave no folder. Run as root it refuses. The file's last line is the call of `main` | the temporary folder kept; the installer's exit code dropped; a ref with `..` fetched; the clone's case decided by `$0`; `L1_FETCHED_REF` not set |
| NT5 | `common/test-make-installer-app.sh` | Built into a scratch folder with a stub `open`: the three files, the identifier, the marker line, the game, the ref and the title in every place, the alert's title passed to `osascript` as an argument; the name and the ZIP's name from `games.tsv`; the ZIP unpacked with `ditto -x -k` keeps the script executable. The script run with the bundle's files carrying a quarantine attribute: the `.command` it writes has none, and `open` is called with `-a Terminal` and that path. The `.command` run with a stub `curl`: `bash -c` gets `1launcher-install`, the game and the ref; `curl` exit 22 prints the withdrawn lines, any other failure the network line; afterwards the file and its folder are gone. The `.command` copied into a folder beside another file and run: the other file is still there. With `TMPDIR` naming no folder, `/tmp` is used. A bad ref exits 2. Neither `--icns` nor `--no-icon` exits 2. A target that is not this builder's own bundle is refused and left as it was | the `.command` copied from the bundle (the attribute travels); `open` given a file inside the bundle; a foreign bundle replaced; the ref not checked; the recursive delete put back; the `$0` word given as `install.sh` |
| NT6 | The repository's gates | `python3 common/check-links.py` (0 unresolved); `bash common/check-identifiers.sh` at the recorded residual; `python3 cities-skylines-2/scripts/check-experiments.py` (the pictures' audit rows); `bash -n` on every new script; `bash common/test-launch-lock.sh` with its three files; the existing suites `test-setup.sh`, `common/test-launcher-builders.sh`, `common/test-make-launcher-app.sh`, `common/test-launcher-parity.sh` green | none: they are gates |
| NT7 | In NT5's file, on scratch copies of the root `README.md`, `cities-skylines-2/README.md` and `cities-skylines-2/INSTALL.md` | In those three files every occurrence of `raw.githubusercontent.com/macgameport/1launcher/` is the one string ending `release/install.sh`, and each file has at least one; the app built with the default ref fetches that string. From N6b on: every occurrence of `releases/download/installer-` in them names `installer-1` and the ZIP's exact name | the root README's line changed alone |

Not testable without a real Mac state, and so live: the real archives through the real script, Wine,
Steam, a sign-in, the game, a closed Terminal window, and Gatekeeper.

## 5. Live steps, each on James's word

- **NL1. The mechanism, for real, into a scratch wrapper on the Studio.** With no game, Steam or launcher
  running, and the real game's `StateFlags` 4. Before and after, a listing of the names in `~/Desktop`, `~/Documents` and two levels of
  `~/Library` (what the template launcher and Steam write outside the wrapper: ND10, and the guide's
  "Nothing is installed outside those paths", `:342`). From the branch's worktree, in Terminal:
  `CS2_WRAPPER=~/Applications/CS2fresh.app bash cities-skylines-2/scripts/install.sh --no-setup`. It
  downloads the two archives, makes the wrapper, installs Steam and rides out the first-start failure;
  with `L1_TRACE` set, the count of Steam processes at each poll is recorded through the updater's
  self-replace (the three-poll rule). At the sign-in window, before signing in: Control-C in the Terminal window, then the installer
  again; then the window closed, then the installer again. Each time: does Steam still hold the prefix 30 s
  later, and is a `.crash` left? The words of 2.7 follow the result. James signs in. Then, once: whether
  `wine64 steam.exe steam://install/949230` opens the install box (press Cancel in it). Picture 4 is taken.
  With the installer still polling, from another shell the game folder and then its manifest are cloned
  from `CS2dxmt11.app` with `cp -Rc` (no download, almost no disk): recorded are the installer seeing the
  game, the exit code of `-shutdown`, the seconds until Steam is gone and what is left holding the prefix.
  Last, `CS2_WRAPPER=~/Applications/CS2fresh.app bash cities-skylines-2/scripts/boot-verify.sh` must reach
  the main menu (the cloned game is already patched; no save is loaded). A visible game start: James is
  told before it. Steam is then signed out in the scratch wrapper and `CS2fresh.app` goes to the Trash.
  `--no-setup` keeps setup, and so the apps and `~/cs2-patch`, out of it; the launcher's badge step, where
  it was turned on, checks the real wrapper's `Game.dll` as at every launch.
- **NL2. The front door.** With no game, Steam or launcher running, the branch rebased on `main` and
  pushed, the deployed files equal to `main`'s, and the game's `StateFlags` 4.
  `make-installer-app.sh --ref simple-install` builds the ZIP, which is served from the Studio by a local
  web server so that Safari downloads and quarantines it as it would from GitHub. James downloads it, opens
  the app, and reports each thing macOS says; Open Anyway; the Terminal window; the fetch of the branch.
  Recorded: every dialog's words; `spctl --status`; `xattr -l` on the unpacked app; the path the app ran
  from; `xattr -l` on the `.command` while it runs (no `com.apple.quarantine` is the pass); any other
  question macOS asks. Pictures 1 and 2 are taken. On the Studio every stage is done, so it ends in setup
  on the real install, from the branch's code: the "open it again to update" path. If the app cannot be
  approved, ND1's other half applies (2.5).
- **NL3. Publish.** First the note to Porting Kit's developers: the draft is `portingkit-note-draft.md` in
  the probe's evidence folder, and James sends it, changes it or drops it before anything is public; an
  answer is recorded here. Then, with James's word for each public act: the branch is merged with
  `--no-ff` (N1 to N5 and N6a), and `main` and `release` are pushed in one atomic push
  (`git push --atomic origin <merge>:main <merge>:refs/heads/release`), so the documents never name a
  `release` that does not exist (2.8); the pasted line is run once in Terminal with `--check`; when NL2 passed, the `installer-1` release with the ZIP built for `release`, whose link must
  download a file with the sha256 the builder printed; then N6b is committed and `release` moved to it;
  then the issue #22 note.
- **NL4. A Mac account with nothing in it.** A new macOS user account (James makes it) or any Mac without
  the wrapper. From the public page: the ZIP downloaded, the app opened and approved, the installer run to
  Steam's sign-in window; and the pasted line, copied from Safari into Terminal, with what macOS says of
  it. Every question macOS asks is recorded. These are required: it is the only step in which the
  published ZIP is opened, and the first fresh install since the folders moved. Whether the game is
  downloaded there is James's call; if it is, how often Steam writes `BytesDownloaded` is recorded.
- **NL5. After the first week.** Whether the two pinned files are still published, and anything a user
  reported, recorded in the as-built header.

## 6. Exit criteria

- N1 to N6a are committed on the branch; NT1 to NT7 pass; every listed mutant was applied and seen red,
  with the count in the as-built header; the sixteen older mutants of `test-setup.sh` and the mutant of
  `test-launch-lock.sh` are still red.
- NL1 passed: a wrapper made by the script from the two real downloads, Steam signed in, the game found
  while the installer polled, Steam closed by the installer, the main menu reached; the listing shows what
  an install writes outside the wrapper, and the guide's Uninstall says the same.
- NL2 passed, or failed and the guide keeps the pasted line as the one way in.
- NL3 done: the note decided, the merge, `release`, the release when NL2 passed, N6b, the link checked.
- NL4's required part is done.
- The as-built header is written, with the deviations, and NL5 is recorded there when it comes.

## 7. Rollback

- **Before NL3:** the branch is all there is in the repository. On the Studio, NL2 ran setup from the
  branch's code on the real install: run `bash cities-skylines-2/scripts/setup.sh` from `main` to put
  `main`'s files back in `~/cs2-patch` and rebuild the apps.
- **After NL3:** a `git revert` of N6b, then `git revert -m 1` of the merge (a `--no-ff` merge, NL3),
  takes the scripts and the documents back on `main`, with one exception: the root `install.sh` is kept as a short file that prints "This installer has been
  withdrawn" and the guide's address, and `release` is moved forward to that commit. Every published app
  and every pasted line then says so instead of failing; an app whose fetch finds nothing at all says the
  same from its own text (2.5).
- A published release is not deleted: its notes gain a first line saying it is withdrawn, and the README
  no longer links it.
- Nothing on a user's Mac needs undoing. An install made by the installer has the name, the shape and
  the Steam that the guide's steps make; its Wine is the June build where Porting Kit now gives the
  September one (ND4). A wrapper someone no longer wants goes to the Trash, as the guide's Uninstall says.

## 8. Decisions

| # | Decision | By |
|---|---|---|
| ND1 | The first run is free: an unsigned app approved once with Open Anyway, and a pasted Terminal line as the other way. If NL2 shows the app cannot be approved, only the pasted line is published | James (K3); the fallback is this plan's |
| ND2 | The installer fetches the engine, the template and Steam's installer from their makers' own pages, and a courtesy note is drafted | James (K4) |
| ND3 | The mechanism was probed before the plan was written, and the template archive downloaded to test its unpacking | James (K5, K8) |
| ND4 | The engine pinned is `WS12Wine11.0_DXMT-v0.80` of June 2026: the one the Studio's Wine 11.0 measurements and the probe ran on. Its successor `11.0_1` is what Porting Kit 6.7.0 fetches today and one user has run it (issue #15); moving the pin is a later change with its own run | this plan |
| ND5 | The wrapper keeps the name and the shape every script and document already knows: `~/Applications/CS2dxmt11.app`, a whole Wineskin wrapper, its prefix made by the template's own launcher | this plan |
| ND6 | The installer app carries the 14unch3r mark as its icon | this plan |
| ND7 | The app holds no code of the repository and fetches `install.sh` each time, so a published app never goes stale when a game update needs new patches | this plan |
| ND8 | Steam's installer is not pinned by checksum: Valve replaces the file in place, a stale pin would stop every install, and Steam replaces itself from Valve within a minute of its first start anyway. It comes over HTTPS from Valve's own address; the `MZ` and `Valve Corp` test catches a wrong file, not a forged one; its sha256 is printed, with a caution when it is not the tested one | this plan |
| ND9 | The app is released under its own tag, `installer-1`, not marked latest, apart from the `v0.1.0` that `docs/plans/local-files-layout.md` owns | this plan |
| ND10 | No new place outside the repository. Downloads, logs of a build and the temporary checkout live in `mktemp` folders that are removed; the wrapper is where wrappers already are. NL1 lists what the template launcher and Steam themselves write elsewhere | this plan |
| ND11 | The guide's quick way has four pictures, each audited, none showing a Steam name, a Mac user name or a live sign-in code | James (K6) |
| ND12 | The app and the pasted line follow a branch named `release`, which moves forward only on purpose and on James's word; `main` reaches no installer user by itself | James (K7) |
| ND13 | The installer finds a wrapper by the launcher's own rule and uses an install under another name. It puts Steam only into a wrapper it made, one that holds the game, `~/Applications/CS2dxmt11.app` (the name every guide and script uses, so a resumed install finds it), or one named with `CS2_WRAPPER` | this plan |

## Review corrections (triple-check 2026-11-10)

Pass 1 was four lenses: architecture, rollout and words (A); security and outside facts (B); correctness
and the test plan (C); a builder who built N1 to N5 in a scratch copy and ran every gate (D). Each said
build-ready-with-fixes. Three blockers, each checked against the code before it was accepted:

| # | Finding | Lens | Where it landed |
|---|---|---|---|
| R1 | No lock and no running-game test: two installers, or an installer beside a launch, in one prefix; setup copying over a launcher in use | A, B, C | 2.3 (the lock, the guards), NT3, the `test-launch-lock.sh` row of 2.1 |
| R2 | The `.command` ended with a recursive delete of its own folder: copied to a Desktop and opened, it deletes the Desktop | B, C | 2.5 (the trap), NT5 and its mutant |
| R3 | A wrapper under another name, which the guide allows, got a second wrapper built beside it, and the launcher then preferred the empty one | C, A | 2.3 (which wrapper), ND13, NT3's wrapper cases |

Should-fixes that changed the design:

| # | Finding | Lens | Where it landed |
|---|---|---|---|
| R4 | The template is a real 7-Zip holding a tar (the engine is XZ), so one `tar` does not unpack it; measured after the review, with the quarantine attribute it carries | C, D | 1.4, 2.2 steps 5 and 6, NT1's fixtures, the GOTCHAS entry |
| R5 | Steam started the plan's way dies when its Terminal window closes or on Control-C, and "safe to close" was unmeasured | A, B, C | 2.3 stage 5 step 2, 2.7's last line, NL1 |
| R6 | A Steam already running but stuck at its box was taken as ready, and the wait had no limit | A, D | 2.3 stage 5 step 1 |
| R7 | An installed game with an update waiting was told to "choose Install" | A, C | 2.3 stage 5's three states |
| R8 | `BytesToDownload` 0 and an absent manifest were undefined; a division by zero falls out of the loop to "installed" | C | 2.3 stage 5 step 4, NT3 |
| R9 | The app and the pasted line ran whatever was on `main`, which is pushed automatically | B, A | K7, ND12, 2.4, 2.8 |
| R10 | The clone's case could be met by accident from Terminal's current folder; the ref pattern let `..` through to another repository; a cut-off download would still run | B, C, D | 2.4, 2.5 (the `$0` word), NT4 |
| R11 | Setup's words name a checkout that is a temporary folder; output shows the Mac user's name | A, B, C, D | 2.6, 2.1's last sentence, NT2 |
| R12 | Documents would have gone live before the release they link; the rollback left every published app saying "check the network" for ever | A | N6a and N6b, NL3, 7, 2.5's exit 22 |
| R13 | NL1 could not see what it claimed (the game found, Steam closed), and NL2 had no preconditions | A | NL1, NL2 |
| R14 | Stage 2's own test would open Apple's window; a temporary checkout can be cleaned during a long wait; the Mac can sleep during the download | B, A | 2.3 stages 2 and 6, the opening lines |
| R15 | Copies of the launcher's functions with nothing holding them together; three wrapper rules | A, C | 2.3 (copies held together), NT3 |
| R16 | Test gaps: mutants no case killed, behaviours with no test, a library path no stub can see, `ptya` named for a case only `pty` can run | C, D | 4, throughout |

Smaller corrections folded without a row: the shifted line references and "five paths" in 1.2; the upload
dates and the winget wording in 1.3; the exact fatal lines and what the 111 s covered in 1.4; `--wrapper`
and `--dest` in the usual sense; one number for the game's size; the second address for Steam's installer;
root refused by all three scripts; `~/Applications` made when absent; a case-sensitive volume refused; the
14unch3r guide page among the documents; the pointer line for the other plan; the note to Porting Kit
moved before anything is public. Rejected: nothing was rejected outright. Two proposals were taken in a
different form: a `setup.sh --print-wrapper` option (the launcher's own function is used instead, so the
rule is one), and a `mkdir` lock (the launcher's existing lock is used instead).

### Fold check (pass 1b, 2026-11-10)

One agent checked the fold above against the code and by measurement. It confirmed: the counts against
their lists; every cite of 2.3 and 2.6; that the nine copied functions can be cut out by name and their
dependencies; that `find_wrapper` returns what 2.3 assumes; that `common/test-launch-lock.sh` takes a third
file and stays green; `acquire_lock 1` (one try, 2 s); the shim of 2.5 under `/bin/bash` 3.2 in all its
paths; that `BASH_SOURCE` is empty under `bash -c`; that `/usr/bin/tar` keeps a quarantine attribute on a
plain unpack and drops it with `--no-mac-metadata`; the start line's own process group; the later order of
NL3. One blocker and seven should-fixes, folded:

| # | Finding | Where it landed |
|---|---|---|
| F1 | NT2's "the scratch `HOME` never appears whole" cannot pass: `repatch.sh` and the two builders print paths of their own, and 2.6 left them unchanged (measured: six lines) | 2.1 names them and the guide says to look before pasting; NT2 asserts setup's own lines only |
| F2 | "If the client is up, go to step 2" restarted a Steam that was ready | 2.3 stage 5 step 1 |
| F3 | A wrapper still to be made cannot be resolved with `cd`, and an empty prefix makes `_owns` match every process | 2.3 which wrapper, NT3 and a mutant |
| F4 | "Update waiting" included no manifest and a first download that stopped part way | 2.3 stage 5's states, NT3 and a mutant |
| F5 | Tools present with a broken `python3` asked Apple again and waited an hour, on every opening | 2.3 stage 2, NT3 and a mutant |
| F6 | `--check` and `--no-setup` had no exit code or closing line, and `make-wrapper.sh --check` would have written | 2.2, 2.3, NT1, NT3 |
| F7 | NL3 left a window in which the documents named a `release` not yet pushed; a rebased branch merges without a merge commit; the rollback left N6b in place | NL3 (one atomic push, `--no-ff`), 7 |
| F8 | Behaviour with no case: the ten-minute limit, `~` in the new scripts' output, the shutdown's later tiers, stage 6's game test, the space caution, `caffeinate`, `--check` with Rosetta missing | NT1, NT3 |

Also folded: `acquire_lock`'s needs (`step`, `die`, the `LOCK=` line) and its cite; a `ptya`-shaped helper
for NT3's typed answers; NT7 limited to three named files; the export-line grep limited to NT1 and NT3;
the old-engines question added to the note's draft; ND13's exception for the usual wrapper name; the
title as a placeholder in the shim; `1launcher-install` in 2.4's example; which scripts refuse root; the
branch pushed for NL2; NL1's `StateFlags` precondition and `L1_TRACE`; the prefix folder in the
completeness test. The case test of 2.2 was measured for this fold on a case-sensitive disk image.

## Review log

Key paths: `cities-skylines-2/scripts/setup.sh`, `cities-skylines-2/scripts/test-setup.sh`,
`cities-skylines-2/launchers/launch-cs2-dxmt11.sh`, `cities-skylines-2/repatch.sh`,
`cities-skylines-2/scripts/make-steam-shortcut.sh`, `cities-skylines-2/scripts/make-shortcut.sh`,
`common/make-launcher-app.sh`, `common/test-launch-lock.sh`, `common/games.tsv`,
`cities-skylines-2/INSTALL.md`, `README.md`, `cities-skylines-2/README.md`.

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-10 | 1 | architecture, rollout and words; security and outside facts; correctness and test plan; builder simulation | four agents, each blocker re-read in the code by the planner; one measurement added (the template archive) | Fable 5.2 for three lenses and the fold, Opus 5.5 for the builder | `580cf4e` | build-ready-with-fixes |
| 2026-11-10 | 1b | fitted fold check | one agent, its citations re-read and one measurement added by the planner (the case test) | Fable 5.2 for the check; Opus 5.5 for its fold, at James's word ("Continue on opus") | `82f8533` | build-ready-with-fixes |
