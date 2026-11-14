# What a new player meets: the findings of the installers' live steps

> **Status:** Draft, 2026-11-13. Not yet checked: its probes (section 3) come first, because three of its
> slices cannot be designed until something is measured (a fourth, H, was measured the same day). No code is built from this before a check.
>
> Tracking: issue #22. The code it speaks of exists only on the branch `surviving-mars-install` (cut from
> `simple-install`): every `file:line` below is as of that branch at `75470c9`. A path is relative to the
> repository's root. The findings were recorded where they were seen, and stay there as the record:
> SF1 to SF9 in section 9 of `docs/plans/shared-installer.md` (on the branches), MF1 to MF4 in section 5a
> of `docs/plans/surviving-mars-install.md`. This plan is where they are planned.

## 0. What this is for

The live steps of the three installer plans passed, and each showed things a new player would meet that
the plans had not foreseen. They are wanted before the first release (the installer plan's NL3). They
were written down as rows, not planned. This plan groups them into slices, says what must be measured
before each can be designed, designs the ones that can be designed now, and names the decisions that are
James's.

## 1. The findings, grouped

| Slice | Findings | What a player meets | Can be designed now |
|---|---|---|---|
| A. Steam's own update is cut | SF1, SF2, MF2 | Steam is started five times in 90 s, then twenty lines of its log and "Steam did not start after 5 tries" | yes (2.1) |
| B. Steam's updater on screen | SF3 | Steam's own update windows and its "Fatal Error" box, on every start | no: probe P1 |
| C. curl's own words | SF4 | `curl: (18) Transferred a partial file` although the next address worked | yes (2.2) |
| D. The macOS 28 notice | SF5 | "App Update Required ... will not open in macOS 28" at the wrapper's first start, and nothing says it is expected | yes (2.3) |
| E. The downloaded app's approval | SF6 | Finder's "not responding" after the approval was stranded | no: James's ND1 first |
| F. A fix not yet available for a new game build | SF7 | "setup finished with 1 problem(s)" and "The install stopped", the same on every later run | words yes; one decision (2.4) |
| G. The wrapper's making waits for every other Wine | SF8, MF1 | "making the Wine prefix (about 30 s)" for as long as any other Wine is open | no: probe P2; a fallback is designed (2.5) |
| H. A line of bash's in the installer's output | SF9 | perhaps `child setpgid (...): Operation not permitted`; and a test that fails now and then | yes, since P3 (2.9) |
| I. A mod switched off by a new install | MF3 | a save runs, and is saved, without its Paradox mod, here and on the player's other install | in part (2.6); probes P4 and P5 |
| J. Runtimes the new prefix lacks | MF4 | nothing so far | nothing to build (2.7) |
| K. Small things seen at ML4 and at the re-check | | two lines that say something untrue | yes (2.8) |

## 2. What is true today, and the design where one can be made

### 2.1 Slice A: Steam's own update is cut

**True today.** A new Steam downloads its update (305 to 336 MB) from `cdn.steamstatic.com`. When that
path cuts transfers, Steam's `logs/bootstrap_log.txt` gains lines `Error: Download of package (<name>)
failed after 0 bytes` (29 of them in ML2's failed start) and then `Error: Steam needs to be online to
update. Please confirm your network connection and try again.` The core knows the last line:
`FATAL='Error: (Failed to determine download location|Steam needs to be online)'`
(`common/install-core.sh:35`). On it, `start_until_up` ends that Steam and starts another
(`:180`, `end_steam; continue 2`), up to `MAX_STARTS` (5). When all five have failed the installer prints
"!! Steam did not start after 5 tries. The last lines of its log:" and twenty lines of the log
(`:362-367`), and exits 1. Seen twice: at SL1 and at ML2, both with the default route on a VPN's tunnel;
with the VPN paused the same update ran in one start both times, and at ML4 (49 s). At ML2 a transfer of
one package by `curl` was cut twice with curl's exit 18, after 1.1 MB in 6.0 s and after 12.9 MB in
11.7 s. A Steam left at its error box did not close on `-shutdown` within 30 s; `wineserver -k` closed
it and left the 0-byte `.crash` marker, which `start_until_up` already removes before each start (`:172`).

**The two fatal lines are not one case.** "Failed to determine download location" was the reason for the
restart loop in the first place: at the installer plan's probe a new prefix's Steam failed with it on its
first start and worked on the second (3 of 3). That case keeps its restarts.

**Design.**

1. `start_until_up` tells the two lines apart. On "Steam needs to be online to update" it ends that
   Steam, as today, and does not start another: it returns a third code, and the caller goes to step 2.
   On "Failed to determine download location" it does what it does today.
2. The caller tests the server once, with a transfer of its own: the first address Steam's log names in
   an `Add pending download:` line since that start, fetched to nowhere with `curl` for at most 20 s
   (`--max-time 20`). The transfer counts as cut when curl exits with 18 or 56, and as working when it
   exits 0, or 28 (the time ran out) with at least 20 MB received. The size is curl's own
   `%{size_download}`. Anything else (no address in the log, no route at all, curl's 6 or 7) counts as
   "not known".
3. The words, which James has seen (the shared-installer plan's section 9: "ok"). When the transfer was
   cut or its result is not known, and the Mac's default route is a tunnel (`route -n get default` names
   an interface that begins `utun`):

   ```
     !! Steam could not download its own update: the connection to Valve's server keeps being cut.
        This Mac is using a VPN, which may be the cause. Change the VPN's server or pause it,
        then open the installer again. It carries on from this step.
   ```

   With no tunnel, the first line and then `Open the installer again in a few minutes. It carries on from
   this step.` When the installer's own transfer worked although Steam's did not, the first line is
   `!! Steam could not download its own update, although this Mac reaches Valve's server.` and the second
   is the "in a few minutes" line: the VPN is not named, since nothing points at it.
4. No log lines are printed. The path of Steam's log is given in one line, the home folder as `~`, for
   someone who asks for help. Exit 4, not 1: "it cannot go on by itself: open the installer again to
   carry on", which is what the header of each installer says 4 means and what is true here.
5. A VPN that works is never mentioned, and nothing is tested before a failure.

**Not designed here:** a box instead of a line. It is looked at again only if probe P1 finds that Steam's
own error box cannot be hidden and would cover the installer's window (SF2's row).

### 2.2 Slice C: curl's own words

**True today.** Steam's installer is fetched from two addresses in turn with
`curl --proto '=https' --tlsv1.2 -fsSL --retry 2 -o ...` (`common/install-core.sh:310-311`). `-S` makes
curl print its error for an address that fails even when the next one works; at SL1 that was
`curl: (18) Transferred a partial file`.

**Design.** Each try's error output goes to a file in the stage's temporary folder. It is shown, under
the installer's own sentence, only when every address has failed. The sentence stays as it is (`:313`).

### 2.3 Slice D: the macOS 28 notice

**True today.** At a wrapper's first Wine start macOS 27 showed: "App Update Required. This version of
"CS2fresh" includes a component that will not open in macOS 28, the next major release. An update may be
available on the developer's website." (SL1; James: "don't forget this.") `cities-skylines-2/README.md`
and the root `README.md` say that macOS 28 will not run these games (issue #16); the quick way of each
guide and the installer say nothing of the notice. Whether Surviving Mars's wrapper shows the same notice
was not written down at ML2 or ML4: probe P6 asks James.

**Design.** One line where Wine first starts, in `common/make-wrapper.sh` before "making the Wine prefix"
(`:135`), printed only on macOS 27:

```
  macOS may show "App Update Required ... will not open in macOS 28". That is expected: nothing needs
  updating, and the game needs this Mac to stay on macOS 27.
```

And one sentence in the quick way of each guide (`cities-skylines-2/INSTALL.md`,
`surviving-mars-relaunched/INSTALL.md`), with the link to the Compatibility section.

### 2.4 Slice F: a fix not yet available for a new game build (Cities: Skylines II)

**True today.** When the game is a build newer than the patches know, one patch script finds no pattern,
`repatch.sh` reports it, `setup.sh` ends "=== setup finished with 1 problem(s): see the lines marked !!
above ===" with exit 1 (`cities-skylines-2/scripts/setup.sh:303`), and the core adds "The
install stopped. The lines above say why. Open the installer again to carry on from that step."
(`common/install-core.sh:74`). Opening it again gives the same until a new pattern is published (seen at
SL2, with `patch_cohtml.py` on build 26404411; fixed on 2026-11-12, `e14bbae`).

**Design, in words; the decision is FD1.** The run is told apart from a failed one: when every patch
script either applied or reported "no pattern for this build" and nothing else went wrong, setup says

```
  The game has updated to build <n>. One fix is not yet available for it: <the script's own name for it>.
  Everything else is in place, and both apps are built. <One sentence on whether the game can be played
  meanwhile, from the patch's own record.> Look for news: <the repository's front page>.
  Open the installer again once a fix is published: it applies it.
```

Whether such a run exits 0 or keeps exit 1 is James's (FD1). "Whether the game can be played meanwhile"
is not known in general: it differs by patch, and the sentence is written per patch script, beside its
pattern, or left out where it is not known.

### 2.5 Slice G: the wrapper's making waits for every other Wine

**True today.** `common/make-wrapper.sh:136` runs the template's
`Contents/MacOS/wineskinlauncher WSS-wineprefixcreate`. The prefix is complete within a minute; the
program then waits until no process named `wineserver` runs anywhere on the Mac (`killall -0 wineserver`
in its own loop). At ML2 that was 85 minutes, ended 23 s after a Steam in another wrapper was quit. For
this project it matters twice over: its own second game, or its Steam app, may be the Wine that is open.

**Design, in two parts. The first rests on probe P2.**

1. If P2 finds a way to make the prefix that does not wait and gives the same prefix, the installer uses
   it, and the rest of this slice is not needed.
2. Otherwise, and in any case until P2 is done, the fallback: before the step, `make-wrapper.sh` looks
   for a `wineserver` (`pgrep -x wineserver`), finds the wrapper each belongs to (`lsof -p`, the first
   path that ends `.app/Contents/SharedSupport/prefix`), and says

   ```
     Another Windows program is open on this Mac: <the wrapper's name, or "CrossOver", or "another Wine">.
     The next step waits until it is closed. Quit it now, or leave this window open and quit it later.
   ```

   and, while the step runs longer than 60 s, says once a minute that it is still waiting and for what.
   It does not close anything itself: another game may be running.

### 2.6 Slice I: a mod switched off by a new install (Surviving Mars)

**True today**, from ML2 and ML4 (the Surviving Mars plan's 1.4):

- Which mods are on is kept with the player's account. `account.dat` in the saves folder travels by
  Steam Cloud; it is a container the tools cannot read (it begins `BPUL`; 28 printable strings in 4,633
  bytes), so its size is the only sign: 4,633 to 4,690 bytes with the mod on, 4,585 to 4,609 with it off.
- A prefix's own `AppData/Roaming/Surviving Mars Relaunched/LocalStorage.lua` is text. It holds
  `ModIdCache`, a table from a mod's folder to its id, once the mod's file has been fetched there. A new
  prefix has neither that key nor the mod's file.
- In a new prefix the game reads the account 17 s after its start and fetches the mod's file from Paradox
  Mods at about 23 s, by itself. A save loaded then runs without the mod ("Savegame references Mod ...
  which is not present"), the mod is left switched off, and the switched-off account file is uploaded at
  exit.
- The player's other install pulls that file. There the mod's definition loads (4 s) and its 44 "applied"
  lines do not, and a save loaded in that state logs nothing about the mod at all (ML4; at ML2 it logged
  "present, but not loaded").
- Opening the game's Mod Manager switches the mod on again, with no click: seen twice.
- At ML4 a save was written with the mod off in both installs.

**What the installer and the launcher can do, without reading the account file.**

1. **Say it at the moment it matters.** The launcher knows a first start in a prefix: there is no
   `LocalStorage.lua` in it yet. On that start, and only then, it shows one note before the game starts
   (its `note`, so a line in a terminal and a notification or the progress window from the app):

   ```
   First start in this install. If you use mods from Paradox Mods, the game starts with them switched off:
   open its Mod Manager before you load or continue a save.
   ```

   The installer's closing lines for this game say the same in one line.
2. **Say afterwards what happened.** After the game exits, the launcher reads the game's newest log and
   looks for a save loaded while a mod was off:
   - a line `Savegame references Mod <name> ... which is not present`, or `... present, but not loaded`;
   - or, for each `[mod] Loaded mod def <name> (id <id>, ...)`, no `Loaded mod items for: <id>` before the
     first `Load Game`.

   When it finds one, its closing words name the mod and say that the session ran without it, that a save
   made in it was made without it, and to open the Mod Manager before the next load. From the app this is
   an alert, since nobody reads a log.
3. **The guide** already says it (`surviving-mars-relaunched/INSTALL.md`, "Good to know").

**P4, answered 2026-11-13.** The game does not go to a save by itself: it stops at its menu, where the
player chooses Load Game and then a save (James, with a capture of the menu; the menu's own row has
"Mod Manager (1)", the number of mods). So the loads 24 s and 12 s after the start at ML4 were his, and
a note before the game starts can be acted on: the Mod Manager is one click from the same menu.

**What rests on a probe.** Whether the launcher can keep the account file from being uploaded in its
switched-off state depends on P5; it is not designed here.

### 2.7 Slice J: runtimes the new prefix lacks

Nothing is built. A prefix made by the installer has none of the Visual C++ runtimes, `d3dcompiler_47`
or fonts the first wrapper holds, and the game ran in it through a session of 8 minutes (ML4). If longer
play fails for a missing runtime, its source and licence are a decision of their own.

### 2.8 Slice K: two lines that say something untrue

- `surviving-mars-relaunched/scripts/setup.sh` ends with "The game: <app>, also in Spotlight and
  Launchpad" for any app path. That holds only for an app in `~/Applications` or `/Applications`. The
  clause is printed only then.
- After a Mac check that exits 3 (an Intel Mac, a macOS below 14) the core's closing line is "The install
  stopped. The lines above say why. Open the installer again to carry on from that step."
  (`common/install-core.sh:253`, `:74`). Opening it again cannot help. The core ends quietly there
  (`END=quiet`), since setup's own words have said why. Cities: Skylines II's setup never exits 3 from
  `--mac-only`, so its recorded transcript does not change.

### 2.9 Slice H: a line of bash's in the installer's output

**True, from probe P3 (done 2026-11-13; records in the game's `runs/p3-setpgid-20261113/`).** The core
starts Steam with job control switched on for one line, so that Steam gets a process group of its own
(`common/install-core.sh:147-151`). Those lines, with a stub as the program, printed bash's
`child setpgid (<n> to <n>): Operation not permitted` in 4 of 3,200 starts with no terminal, and in 0 of
3,200 under a terminal. The line is written by the forked child before its own redirections take effect,
so it goes wherever the installer's error output goes. With the whole block's error output sent to
`/dev/null` at the outer level it was printed in 0 of 6,400 starts, with and without a terminal; that
part holds by construction, since the child inherits the redirected descriptor. Why the call is refused
was not found. That a player in a Terminal window cannot see the line is not shown, only not seen
(0 against 4 of 3,200 is a small difference).

**Design.** `start_steam`'s three lines stand inside `{ ...; } 2> /dev/null`. Nothing else of the
installer's output is lost by it: the three lines print nothing of their own, and Steam's output already
goes to `/dev/null`. Its test is in two parts, and the plan says which is which: a source gate (the
block's error output is sent away), which a mutant turns red every time; and 3,000 starts of the core's
own function with a stub program and no terminal, which must print nothing, and which the same mutant
turns red only most of the time (about 98 in 100, from the rate measured). The transcript of Cities:
Skylines II's installer needs no change.

## 3. Probes, before the design of slices B, G and I

Each is recorded in a run folder of the game it concerns, with a `notes.md`. None changes the real
wrappers. P1, P2 and P5 start Wine or Steam, so they wait until nothing else of Wine runs on the Mac and
are done on James's word.

| # | Question | How | Needs |
|---|---|---|---|
| P1 | Can Steam's updater and its error box be kept off screen in a new prefix? | A scratch wrapper with Steam's installer run and Steam never started. Started once each way with the launcher's environment: plain, `-silent`, and with the update files already in place from a copy of another prefix's `package/` folder. Recorded with a capture of the Steam windows' region only: what appears, and whether the client comes up | Wine; no sign-in |
| P2 | Can the prefix be made without the template's wait, and is it the same prefix? | With another Wine open (this project's Steam app), in a scratch folder: (a) the template's program, timed, as the control; (b) `wineboot -u` of the engine in a prefix folder made by hand, then what the template's program adds found by `diff -r` of the two prefixes and of the wrapper's `Info.plist`; (c) the template's program ended once the prefix is complete (its log line, or `system.reg` present and `wineserver -w` returned for that prefix). Then Steam's installer run in the result of (b) | Wine; another Wine open on purpose |
| P3 (done 2026-11-13: 2.9) | Why does bash print `child setpgid (...): Operation not permitted`, and can a player see it? | `cities-skylines-2/scripts/test-install.sh` run 30 times, counting the runs that hold the line; then `start_steam` (`common/install-core.sh:147-151`) in a ten-line script of its own, 200 times each: with and without a terminal, and with the block's error output sent to `/dev/null` at the outer level. No Wine: a stub program | nothing: can run at any time |
| P4 (done 2026-11-13: 2.6) | Does the game go to the last save by itself at its start? | James is asked. If he does not know: one start of the real game with nothing pressed for two minutes, and the log read after exit | James |
| P5 | When is the switched-off account file written: at the menu, at the load of a save, or at exit? | In a scratch prefix signed in with James's account, under ML2's steps 1, 5, 6 and 9: the size and time of `account.dat` read every second from the start; quit at the menu with nothing loaded. It uploads a switched-off file once more, so James opens the Mod Manager in the real game afterwards | Wine; James's sign-in; his word |
| P6 | Does Surviving Mars's new wrapper show the macOS 28 notice? | James is asked what he saw at ML4; else it is looked for at the next wrapper made | James |

## 4. Steps

- **F0. The probes of section 3.** P3 and P4 are done. Then P6 (a question), then P1, P2 and P5 in one
  sitting on James's word. Their results are written into section 2, slices B, G and I are designed, and **the plan is checked** (`check it`) before F1.
- **F1. Slice A** in `common/install-core.sh`, with its cases in both games' `test-install.sh` and the
  recorded transcript of Cities: Skylines II recorded again on purpose.
- **F2. Slices C and D** (the core, `common/make-wrapper.sh`, both guides).
- **F3. Slice G**, as P2 decides.
- **F4. Slice H**, as P3 decides.
- **F5. Slice I** in `surviving-mars-relaunched/launch-relaunched.sh` and the game's installer, with the
  parity test's list.
- **F6. Slice F**, after FD1; and slice K.
- **F7. Slice B**, as P1 decides.
- **F8. Live: the installer once for each game on the Studio with the VPN on**, to see slice A's words
  where they belong, and whatever F3 and F7 changed. On James's word.

The work is done on a branch cut from `surviving-mars-install`.

## 5. Test plan

Every test runs with `HOME` at a scratch folder and every outside program a recording stub, as the two
`test-install.sh` files do. Each mutant is applied to the real source, seen red, and removed. Rows for
slices B and G are written after their probes.

| # | Test | What it shows | Mutants, each must turn it red |
|---|---|---|---|
| FT1 | both `test-install.sh`, cases added | "Steam needs to be online" in the log after a start: no second start; one transfer of the installer's own, to the address the log named, with `--max-time 20`; cut (curl 18, and 56) with a tunnel as the default route gives the three lines with the VPN sentence; cut with no tunnel gives the "in a few minutes" line and no word of a VPN; the transfer working (exit 0; exit 28 with 20 MB or more) gives the "although this Mac reaches" line; no address in the log, and curl's 7, count as not known; no line of Steam's log is printed; the log's path is, with `~`; exit 4; "Failed to determine download location" still restarts, up to five times; a Steam that comes up is never followed by a transfer or a word of a VPN | a second start after "needs to be online"; the restart removed for "download location"; the VPN sentence with no tunnel; the VPN sentence when the transfer worked; the transfer made before any failure; the log's lines printed; exit 1; 28 with 1 MB counted as working |
| FT2 | both `test-install.sh` | the first address of Steam's installer failing with words on its error output and the second working: none of those words on screen; both failing: the installer's sentence and both tries' words | curl's words printed when the second address works; nothing printed when both fail |
| FT3 | `common/test-make-wrapper.sh` | the macOS 28 line is printed on macOS 27 before the prefix step and not on 26; with a `wineserver` in the process list the wrapper it belongs to is named before the step, and the minute line comes while the step runs long; with none, neither line | the line printed on every macOS; the other Wine not looked for; the wrong wrapper named; something closed by the script |
| FT4 | `surviving-mars-relaunched/tools/test-mod-notes.sh`, new, on log fixtures cut from the four real logs of ML2, ML3 and ML4 with identifiers replaced | first start (no `LocalStorage.lua`): the note is shown once, before the game starts, and not on a second start; the log of ML4's scratch session: the closing words name the mod and "not present"; ML4's real session (definition loaded, items loaded only after the load): named; ML3's session (items loaded before the load): no words; a log with no mod at all: no words; no log: no words and no failure | the note on every start; the "not present" line not looked for; the order of items and load not looked at; a healthy session named; a missing log stops the launcher |
| FT4b | `common/test-start-steam.sh`, new | the source gate: `start_steam`'s block sends its error output away; and 3,000 starts of the core's own function with a stub program and no terminal print nothing | the redirection removed: the gate every time, the starts about 98 times in 100 |
| FT5 | `surviving-mars-relaunched/scripts/test-setup.sh`, both `test-install.sh` | "also in Spotlight and Launchpad" only for an app in an Applications folder; after a Mac check that exits 3 there is no "Open the installer again" line, and Cities: Skylines II's transcript is unchanged | the clause for a scratch app; the closing line put back |
| FT6 | the gates: `common/check-links.py`, `common/check-identifiers.sh` at its residual, `cities-skylines-2/scripts/check-experiments.py`, `bash -n` on every script, `common/test-launcher-parity.sh` with its list | no dead link, no identifier, the ledger whole, the launchers' kept differences listed | the parity test's own |

## 6. Exit criteria

- The six probes are recorded, and slices B, G and I are designed from them or dropped with the reason.
- The plan was checked after the probes and before F1, and its verdict line is dated.
- F1 to F7 are committed; FT1 to FT6 pass; every listed mutant was applied and seen red.
- F8 passed: with the VPN on, the installer says slice A's three lines once, starts Steam once, and
  exits 4; with it paused, the same run goes on.
- The rows SF1 to SF9 and MF1 to MF4 each say, where they are recorded, which slice built them or why
  not.

## 7. Rollback

- Every change is to the installers, the launcher's words and the guides: a revert of the commit puts the
  old behaviour back, and no prefix or save is changed by any step.
- P5 and F8 start Steam on James's account from a scratch prefix; ML2's steps 1, 5, 6 and 9 (the
  Surviving Mars plan) keep that safe and name the way back.
- P2 makes prefixes in scratch folders only, and its other Wine is this project's Steam app, opened and
  closed for the purpose.

## 8. Decisions, each James's

| # | Decision | Recommendation |
|---|---|---|
| FD1 | A run in which the only problem is a fix not yet available for a new game build: exit 0 or 1 | 0, with the words of 2.4. Everything the installer can do is done, and "stopped" sends the player round a loop that cannot end |
| FD2 | If the game goes to the last save by itself (P4): what then | Not needed: P4 found that it does not |
| FD3 | Whether the launcher keeps a copy of the saves folder before the first start in a new prefix | Yes: it is small (about 100 MB for three saves), it is the way back the guide can point at, and it is made once per install |
| ND1 | The app is published, or only the pasted line (the installer plan's; slice E waits for it) | open |

## Review log

Not yet checked. Key paths: `common/install-core.sh`, `common/make-wrapper.sh`,
`cities-skylines-2/scripts/` (`setup.sh`, `test-install.sh`), `surviving-mars-relaunched/`
(`launch-relaunched.sh`, `scripts/install.sh`, `scripts/setup.sh`, `scripts/test-install.sh`, `INSTALL.md`),
`cities-skylines-2/INSTALL.md`.
