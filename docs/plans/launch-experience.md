# Launch experience: one progress window, no doubled pop-ups, a measured licence wait

> **Status:** Triple-checked 2026-11-10 — build-ready-with-fixes, corrections folded. Pass 1 was four
> lenses; pass 1b was a fifth agent checking the fold, and its findings are folded too. The build waits
> only for the items under "Before A1".
> Written 2026-11-10. Tracking: issue #22. This is the first slice of Phase 5 of
> `docs/plans/1launcher-unification.md`, whose outline holds the findings this plan starts from.
> File and line references are as of `dc2b584`.
> **🔧 As-built (2026-11-10):** PARTIAL. A1 to A7 are built and merged (branch `launch-experience`): `7a6bd5e` the
> window, `6ebe9df` the block and step lines, `52533c6` the update messages, `77ee07b` builders and shims,
> `b212935` the parity test, `50cbbc9` the probe, and the docs commit after them. Every new test passes and
> every mutant of section 5 exits 1 (95 in all); the 14 existing suites that start nothing real pass before
> and after. Live steps 1 and 2 are done on the Studio
> (2026-11-10): merged as `a64801d` with no launcher running; setup exit 0 with both of its closing lines;
> 21 files found and 21 identical, `_vendor` equal; both apps hold `launch-progress`; `test-game-running.sh`,
> `test-rosetta-preflight.sh` and `test-make-engine-install.sh` pass. Live step 3 is done: the real window,
> run against a scripted log, was up before any step, still up 4 s after the final step and gone by 7.5 s,
> ignored an `ERROR:` and game output written after the final step, and closed within 2.5 s of an `ERROR:`
> in a fresh session. Captured in dark mode, every text fits or is cut with an ellipsis. James saw it over a
> full-screen app, and closed it by its button (gone at once). Not captured in light mode. Live step 4:
> `boot-verify.sh` PASS, run `20261110-030513`, its log holding steps 1 to 5 in order and the 45 s wait.
> Live step 5: James started each game from its app; both logs hold steps 1 to 5 in order, both exited
> cleanly with Steam down, and Surviving Mars uploaded its saves. He saw the window and no banner before
> either game, and the game's usual exit dialog (the cosmetic IO error of `cities-skylines-2/GOTCHAS.md`).
> **The banner half of step 5 is not yet evidence**: he was using the Studio by Screen Sharing from
> another Mac and saw neither the closing banner nor two test banners posted the old way and the new way,
> so banners were not reaching him at all. It is repeated at the Studio itself. Live step 6 stopped at its control run, as
> 3.6 says: `licence-wait-probe.sh 0 1` on the Studio, run `20261110-031919-1`, was a **PASS**. Steam started
> fresh, the launcher logged `Licence wait: 0 s` and went straight to steps 4 and 5, the game started 30 s
> after the boot began and reached its menu, and neither of its logs holds `platform service integration
> failed`. Steam's app information was in 1 s after sign-in. The race of `GOTCHAS.md` section 11 did not
> show, so the series at 30 and 15 cannot tell those waits from none; the decision is James's. He chose
> five more at 0 s, with this rule: all pass, and the default becomes 15 once five runs at 15 on the MacBook
> pass too; any failure, and the series at 30 and 15 runs as planned. `licence-wait-probe.sh 0 5`: **5 of 5
> PASS** (runs `20261110-032650-1` to `20261110-033756-5`), Steam client 1792618285 throughout, Steam's app
> information in 0 or 1 s after sign-in. Six boots with no wait at all, six menus, no licence failure. The
> change of default was prepared on branch `licence-wait-15`. Live step 7, MacBook part: the check of step 1, `git pull`, `setup.sh` (exit 0) and `make-app.sh` (exit 0), then `licence-wait-probe.sh --expect-update 15 5`: **5 of 5 PASS** (runs `20261110-043522-1` to `20261110-044734-5`, game 1.6.0f1 with its update waiting, Steam client 1792618285), each logging `Licence wait: 15 s` and `game update waiting`. The probe was the one from before `1b399ce`, so no run recorded the record before its boot; it read `waiting` after them (`StateFlags 1046`), so these runs show the update check ran and do not test the wait's second job. James accepted them as they stand, and `licence-wait-15` is merged: the default is 15. Step 8 on the MacBook: `setup.sh` (exit 0, the installed launcher's default 15), T2 `21 found, 21 identical` and `_vendor equal` (badge patch on), `boot-verify.sh` **PASS** (menu reached, graceful exit). Step 5 on the MacBook, Surviving Mars: started by James from its app at 05:19, a cold start; the launcher log shows `[1/5]` to `[5/5]` in order with `Licence wait: 15 s`, no panel process was left, and James saw the closing banner as expected. The gap from the window closing to the game's window was not recorded. Step 5 on the MacBook for Cities: Skylines II, and step 8 on the Studio, are not done. Deviations: (1) the widest
> step text measures 357 points in the 368 point label, not the 312 this plan first said; both labels cut a
> longer text with an ellipsis. (2) Rule 8 of 3.7 lists the Surviving Mars probe at A5 and gains the
> Cities: Skylines II one at A6, since that probe does not exist earlier. (3) The probe stops at its first
> FAIL, and carries the MacBook rule as `--expect-update`. (4) The "so far" text takes its size from a
> variable, so that the literal stays inside rule 6. Verify against: `common/launch-progress.swift`, the
> `launch-feedback` blocks of both launchers, `common/test-launcher-parity.sh`,
> `cities-skylines-2/scripts/licence-wait-probe.sh`.

## 1. Why

Three things James saw on 2026-11-09 and 2026-11-10, each confirmed in the code:

1. Cities: Skylines II shows a progress window while it starts. Surviving Mars shows notifications only.
2. Cities: Skylines II shows the window and a notification for the same milestone, five times on a cold start.
3. Cities: Skylines II waits a fixed 45 seconds after sign-in. Surviving Mars waits 15, a number it measured.

And one question: how the two launchers are kept the same where they are meant to be.

Phase A below is what gets built from this document. Phases B to D are an outline: each needs its own
measurements, plan text and check before it is built.

## 2. What is true today

| Fact | Where |
|---|---|
| The Cities: Skylines II app compiles a Swift panel from a heredoc and starts it beside the launcher | `cities-skylines-2/scripts/make-shortcut.sh:146-250`, shim `:103-112` |
| The panel finds its step by matching the launcher's message text; no test names those strings | `make-shortcut.sh:218-232`; `grep -l 'Almost ready' */scripts/test-*.sh common/test-*.sh` prints nothing |
| The panel stops after 8 minutes whatever is happening; a game update is allowed 60 | `make-shortcut.sh:213`; launcher `UPDATE_TIMEOUT`, `:269` |
| The shim sets `CS2_QUIET=1`, so `note` posts each milestone as a notification as well | shim `:108`; `launch-cs2-dxmt11.sh:54-58` |
| Start-up `note` calls on a cold start: 5 (`:227`, `:251`, `:254` twice, `:340`), and one at close (`:380`) | launcher |
| The Surviving Mars app has no panel; its shim sets `SM_QUIET=1` | `surviving-mars-relaunched/make-app.sh:22-54` |
| **The Surviving Mars app runs the launcher in this checkout**, so an edit to it is live at the next launch | `make-app.sh:7-8`, `:13` |
| The Cities: Skylines II app runs a copy that setup installs; `boot-verify.sh` starts that installed copy | `cities-skylines-2/scripts/setup.sh:148`; `boot-verify.sh:94` |
| The 45 s wait is three fixed 15 s sleeps with no setting | `launch-cs2-dxmt11.sh:249-259` |
| The game-update check sits after that wait so that Steam has had time to refresh the game's record | `launch-cs2-dxmt11.sh:261-265` |
| Surviving Mars has `SM_LICENCE_WAIT`, default 15, from 10 of 10 clean runs. It is not validated: `sleep abc` returns at once | `launch-relaunched.sh:61-65`, `:219-220` |
| The Surviving Mars probe finds its run by the player's text, `Waiting N s` | `surviving-mars-relaunched/tools/licence-wait-probe.sh:102` |
| The record behind 45 is one failure signature and a 40 s fix, with no run count | `cities-skylines-2/GOTCHAS.md:192-200` |
| One Studio boot, run `20261109-210108`: sign-in answered 21:01:43, Steam's app information done 21:01:46, game started 21:02:37, menu 21:03:34 | the parent outline |
| `boot-verify.sh` starts the launcher with the caller's environment and takes `--out`. Exits: 0 PASS, 1 FAIL, 2 REFUSED, 3 VOID, 64 setup | `boot-verify.sh:242-246`, `:112`, `:64-65` |
| The lock functions are compared byte for byte across the two launchers | `common/test-launch-lock.sh:76-80` |
| The two update-check blocks differ in 15 lines once names, app ids and titles are made equal: 13 inside the markers and the 2 opening marker lines | measured; the exact `sed` is in 3.7 |
| The update-check tests stub `note` and `die` in four places and assert one of the three progress messages | `cities-skylines-2/scripts/test-update-check.sh:71-74,150-151,124`; `surviving-mars-relaunched/tools/test-update-check.sh:63-64,140,115,150` |
| `test-launcher-notes.sh` takes `ensure_patches`, the one line that calls it, and the compat block out of the launcher, and supplies its own `note` | `cities-skylines-2/scripts/test-launcher-notes.sh:24-26,41` |
| Every message is pasted into AppleScript source. One Surviving Mars failure text holds a `"`, so its alert can never show | both `note` and `die`; `launch-relaunched.sh:112` |
| Two existing suites start an Intel program: one whole, one in its fourth case | `surviving-mars-relaunched/tools/test-make-engine-install.sh`; `cities-skylines-2/scripts/test-rosetta-preflight.sh:59-64` |

## 3. Design of Phase A

### 3.1 One block in both launchers

Each launcher sets its own three values, then carries a block that is the same text in both. The block
goes straight after `QUIET=` (`launch-cs2-dxmt11.sh:43`, `launch-relaunched.sh:95`), before `die`.

```bash
# >>> launch-feedback-config (this launcher's own values)
STEPS=5
TITLE="Cities: Skylines II"
PANEL="${CS2_PANEL:-0}"
# <<< launch-feedback-config
# >>> launch-feedback (the same in both launchers: common/test-launcher-parity.sh compares the copies)
_notify() { osascript -e 'on run a' -e 'display notification (item 1 of a) with title (item 2 of a)' -e 'end run' -- "$1" "$TITLE" >/dev/null 2>&1; }
_alert() {   # <text> [warning]: the text travels as an argument, never as AppleScript source
  if [ "${2:-}" = warning ]; then osascript -e 'on run a' -e 'display alert (item 2 of a) message (item 1 of a) as warning' -e 'end run' -- "$1" "$TITLE" >/dev/null 2>&1
  else osascript -e 'on run a' -e 'display alert (item 2 of a) message (item 1 of a) as critical' -e 'end run' -- "$1" "$TITLE" >/dev/null 2>&1; fi
}
step() {   # <n> <text>: a start-up milestone. The progress window reads these lines from the log.
  echo "[$1/$STEPS] $2"
  [ "$QUIET" = 1 ] && [ "$PANEL" != 1 ] && _notify "$2"
  return 0
}
note() {   # something the player should see even while the progress window is up
  echo "$1"
  [ "$QUIET" = 1 ] && _notify "$1"
  return 0
}
licence_wait() {   # <step> <seconds as set, may be empty> <default>: the wait after a fresh sign-in
  local w
  case "$2" in ''|*[!0-9]*|????*) w=$3 ;; *) w=$((10#$2)) ;; esac
  echo "Licence wait: $w s"
  while [ "$w" -gt 0 ]; do
    step "$1" "Steam is confirming the game licence, about $w seconds left…"
    if [ "$w" -gt 15 ]; then sleep 15; w=$((w - 15)); else sleep "$w"; w=0; fi
  done
}
# <<< launch-feedback
```

Measured on this Mac's `/bin/bash` 3.2.57 and `osascript`: a text holding `"` and `\` arrives unchanged
through the `on run` form; both statements compile; `08` reads as 8, and `abc`, an empty value and four
digits or more read as the default.

`die` stays as each launcher has it, because the Cities: Skylines II one pauses for a key in a terminal
(`:45-53`; that game ships `.command` files whose Terminal window closes on exit). Each `die`, and the
Surviving Mars cloud alert at `:364`, calls `_alert` in place of its own `osascript` line. That repairs
the alert at `launch-relaunched.sh:112`.

No `note` or `step` is defined anywhere else in a launcher.

### 3.2 Step lines

A start-up milestone is one line in the launcher's output: `[n/N] text`. A person reads it in a terminal
as it is, and the window reads it from the log.

Cities: Skylines II, `STEPS=5`:

| n | Text | Where | Today |
|---|---|---|---|
| 0 | Waiting for the last session to finish closing… | `acquire_lock`, `:180` | `note` |
| 1 | Checking the Mac fixes for the game… | a new line of its own before `:213` | the panel matched `Wrapper:` (`:154`) |
| 2 | Starting Steam and signing in… | `:227` | `note` |
| 2 | Steam is already running… | `:223` | `note` |
| 3 | Steam is confirming the game licence, about N seconds left… | `licence_wait 3 "${CS2_LICENCE_WAIT:-}" 45` in place of `:250-256`, inside the `if` at `:249`, which stays; the `else` line at `:258` loses its `45s` | `note` |
| 4 | Checking for a game update… | a new line before `:333` | nothing |
| 5 | Starting Cities: Skylines II. The menu takes about a minute… | `:340` | `note` |

Surviving Mars, `STEPS=5`:

| n | Text | Where | Today |
|---|---|---|---|
| 0 | Waiting for the last session to finish closing… | `acquire_lock`, `:148` | `note` |
| 1 | Starting Steam and signing in… | `:206` | `note` |
| 1 | Steam is already running… | `:204` | `note` |
| 2 | Steam is confirming the game licence, about N seconds left… | `licence_wait 2 "${SM_LICENCE_WAIT:-}" 15`, replacing `:219-220` | `note` |
| 3 | Checking saves with Steam Cloud… | a new line before the loop at `:228` | nothing |
| 3 | Syncing saves with Steam Cloud. This can take a few minutes… | `:231` | `note` |
| 4 | Checking for a game update… | a new line before `:312` | nothing |
| 5 | Starting Surviving Mars: Relaunched… | `:316` | `note` |

The lock functions stay identical in both launchers, so the step 0 line changes in both, and
`common/test-launch-lock.sh:51` gains a `step` stub beside its `note` stub. The comment on `acquire_lock`
that says it needs `note` changes with it.

In both update-check blocks each of the three progress messages becomes a plain `echo` of the detail,
for the log, followed by a short `step 4` for the player:

| Today, as `note` | The log keeps, as `echo` | The player sees, as `step 4` |
|---|---|---|
| Updating the game through Steam (build A -> B)… | the same line | Updating the game. This can take several minutes… |
| Still updating the game — N min so far (StateFlags …, … bytes). | the same line | Updating the game: N min so far, 3.4 of 5.1 GB… The size is left out when Steam gives no total or the two numbers are equal, which is what an idle record keeps from the last update |
| Game updated to build B. | the same line | The game is updated… |

The 60 seconds between "still updating" lines becomes a variable in both blocks,
`UPDATE_TICK="${CS2_UPDATE_TICK:-60}"` and its `SM_` twin, so a test can reach that message.

Everything else stays `note`: a patch that failed (`:213`, `:330`; its text is asserted by
`test-launcher-notes.sh` and is left alone), the compat note, the update that was declined, the missing
click helper, both cloud warnings and the closing line. The closing line tells a player with two Macs
that Steam is down here.

The new line for step 1 goes on its own line. `test-launcher-notes.sh` requires exactly one line that
starts with `ensure_patches` and is not the definition, its first mutant is keyed to that line as it is,
and it does not define `step`.

No step text holds a `"` or a `\`, and none is longer than 62 characters before its numbers are filled
in. The widest above measures 357 points in a 368 point label (computed in the build; an earlier figure
of 312 was wrong), and both labels cut a longer text with an ellipsis.

### 3.3 The window

`common/launch-progress.swift` is the heredoc of `make-shortcut.sh:158-243`, moved out and changed:

1. **It reads `LP_TITLE` and `LP_LOG` from the environment, never from its arguments.** A game's name on
   a helper's command line is how a watcher came to be taken for the game (`make-shortcut.sh:88-91`).
2. **It parses step lines.** The session is the text after the last line that starts with `===== `, or
   the whole log if there is none. The log is decoded leniently, so one bad byte does not blank it. A
   line that starts `ERROR:` ends the window. Otherwise the last line matching
   `^\[([0-9]{1,2})/([0-9]{1,2})\] (.*)$` with N from 1 to 99 and n from 0 to N sets
   the bar and the text. Once a step with
   n equal to N has been seen, later lines are ignored: the game's own output follows it in the same log.
3. **It ends by what the log says, with no process matching.** It closes 5 seconds after the final step,
   at once on `ERROR:`, 15 minutes after the log last grew, 90 minutes after it started, and when its
   parent process is no longer the shim that started it. A game update is allowed 60 minutes and can
   run a little past that. The longest designed silence is the Surviving
   Mars cloud sync, 5 minutes.
4. **Two modes for tests, both returning before any window object is made.** `--parse <log>` prints
   `<n> <N> <text>`, `error` or `0 0`. `--decide <log> <seconds since the log grew> <seconds since the
   final step, or -1> <seconds since start> <1 if the parent is still the starter, else 0>` prints `show`
   or `close`. The window's timer calls the same
   two functions.
5. **What it shows.** The bold line reads `<TITLE> is starting`, and `<TITLE> is starting: step n of N`
   once n is 1 or more, so step 4 of 5 during a long update reads as a step and not as 80 per cent done.
   The second line is the step's text, cut with an ellipsis if too long; before any step it reads
   `Getting ready…`. Each new text is announced to VoiceOver.
6. **The window itself.** 400 by 96 points, titled and now closable, floating, top right, no Dock icon,
   never taking focus, system label colours. It gains `.fullScreenAuxiliary` beside `.canJoinAllSpaces`,
   so it can show over a full-screen app; whether it does is seen in the rehearsal of section 6.

### 3.4 The builders and the shims

Both builders compile the source into `Contents/Resources/launch-progress`, each resolving `common/` from
its own path. A builder skips the panel, and says which reason applies, when `swiftc` is missing, when
the source is missing, or when the launcher it was given has no line starting `# >>> launch-feedback (`. The last
case is a new app over an older installed launcher: no step would ever arrive. `make-app.sh` gains the
"skipped" line that `make-shortcut.sh:250` has, and its compile step sits inside an `if`, because it
runs under `set -eu`.

Both shims do the same thing, in this order, after the `=====` line they already write
(`make-shortcut.sh:102`, `make-app.sh:46`). `PROGRESS` is `"$APPDIR/Resources/launch-progress"`:
`make-shortcut.sh:105-106` has the two lines under the old name, and the `make-app.sh` shim gains both.

```bash
PANEL=0; PANEL_PID=""
if [ -x "$PROGRESS" ]; then
  LP_TITLE="Cities: Skylines II" LP_LOG="$LOG" "$PROGRESS" >/dev/null 2>&1 &
  PANEL_PID=$!; sleep 0.3
  if jobs -pr | grep -qx "$PANEL_PID"; then PANEL=1; else PANEL_PID=""; fi
fi
stop_panel() { [ -n "$PANEL_PID" ] && jobs -pr | grep -qx "$PANEL_PID" && kill "$PANEL_PID" 2>/dev/null; return 0; }
trap stop_panel EXIT
CS2_QUIET=1 CS2_PANEL=$PANEL${HUD_ENV} bash "$SCRIPT" >> "$LOG" 2>&1
rc=$?
stop_panel
```

- **Why `jobs -pr`.** The launcher returns when the game exits, hours after the window closed itself.
  Measured: bash has reaped the child by then and the number is free for another process, so a plain
  `kill "$PANEL_PID"` could signal a stranger. `jobs -pr` lists a live child and not an ended one.
- **`PANEL=1` means a window process is alive**, 0.3 seconds after its start, not that a file exists.
- **`${HUD_ENV}` stays** (`make-shortcut.sh:76`, `:108`). In `make-shortcut.sh` the shim is written by an
  unquoted heredoc (`:77`), so every `$` above is escaped there except `${HUD_ENV}`. The `make-app.sh` heredoc
  (`:22`) is unquoted too. The Surviving Mars
  line is `SM_QUIET=1 SM_PANEL=$PANEL bash "$SCRIPT" >> "$LOG" 2>&1`.
- **One alert for one failure.** The shim's "Launch failed" alert (`make-shortcut.sh:113-116`,
  `make-app.sh:49-52`) shows only when this session, the text after the last `=====` line, holds no
  `ERROR:` line, because `die` has already shown its own.

### 3.5 What still pops up

With the window up, a cold start posts no notification before the game. Warnings, the update question,
failure alerts and the closing line are unchanged. Where the window was not built, each step posts a
notification: two more per cold start than today in each game.

### 3.6 The licence wait: a setting, then a measurement

The wait is `licence_wait` in the shared block, so both games get the same validation and the same
countdown. Cities: Skylines II gains `CS2_LICENCE_WAIT`, default 45. **The default does not change in
this build.** The block prints one plain line, `Licence wait: N s`, and both probes find their run by
that line and not by the player's text. `surviving-mars-relaunched/tools/licence-wait-probe.sh:102` and
its header (`:8`) change to match.

`cities-skylines-2/scripts/licence-wait-probe.sh <seconds> [runs]`, default 5 runs. Each run is
`CS2_LICENCE_WAIT=<seconds> bash scripts/boot-verify.sh --out <dir>`, with `<dir>` under
`~/cs2-patch/boot-verify/licence-<seconds>/`, outside this public checkout. The operator starts the probe
detached, as `boot-verify.sh:9-12` requires of a boot. It takes plain seconds from 0 to 999 with no
leading zero. It refuses when the installed launcher has no line starting `# >>> launch-feedback (`, and
when the game or this wrapper's Steam is running. It never stops Steam
itself. Between runs it waits up to 30 seconds for this wrapper's Steam to be gone, and stops if it is not.

`--judge <run dir> <seconds> <boot-verify exit>` gives one run's verdict with no launch, in this order:

1. boot-verify exit 2 or 64: the probe stops, "refused" or "setup". It is not a run.
2. The launcher log does not hold exactly one line `Licence wait: <seconds> s`: **VOID**, with the first
   `ERROR:` line quoted as the reason.
3. boot-verify exit 3: **VOID**.
4. `platform service integration failed`, in any letter case, in the run's `SceneFlow.log` or
   `Player.log`: **FAIL**, whatever the exit. A real failure reaches no menu, so boot-verify exits 1.
5. boot-verify exit 1: **OTHER**, with boot-verify's reason. The boot failed for a reason that is not the
   licence.
6. boot-verify exit 0: **PASS**.
7. Any other exit: **VOID**, with the code.

No kept log holds the signature, so its spelling comes from `cities-skylines-2/GOTCHAS.md:193`. The
control run below is also what confirms it.

"5 of 5" means five PASS. A VOID run and a first OTHER run are repeated and not counted. Three VOID in a
row, or a second OTHER, stop the probe.

The wait has a second job (`launch-cs2-dxmt11.sh:261-265`): it gives Steam time to refresh the game's
record before the update check reads it. So each run also records the seconds from the first
`RecvMsgClientLogOnResponse() : … 'OK'` line of `connection_log.txt` stamped at or after the run's start
to the last `UpdatesJob: finished OK` line of `appinfo_log.txt` in the 120 seconds after it; one sign-in
can log several. On 2026-11-09 that was 3. None, or `finished Timeout`, is recorded as `none`, and such a
run cannot support a lower default. The default never goes below the largest value seen plus 5. This
times Steam's app information, a stand-in for the rewrite of the game's record; nothing here times that
rewrite itself.

While the MacBook's game still has its update waiting, every run there must show the launcher's `game
update waiting` line. **Corrected 2026-11-10, from conclusion C74 in `cities-skylines-2/EXPERIMENTS.md`:**
the record does not always keep a waiting update between sessions. On 2026-11-07 the MacBook's record read
current before launch (`StateFlags 4`, `buildid` equal to `TargetBuildID`) and the freshly started Steam
rewrote it inside the 45 s wait. So each MacBook run first reads `StateFlags`, `buildid` and
`TargetBuildID` from `appmanifest_949230.acf` with Steam down, and records them. Where they read current,
the run **does** measure the second job: the line shows Steam rewrote the record within the wait, and a
run without it is a **FAIL** of the second job, not a VOID, since a shorter wait would then hide the
update from the player. Where they already show the update, the line shows only that the check ran, and
a run without it is VOID. The probe reads the record before each boot, the way the installed
launcher does, into `manifest-before.txt`, and with `--expect-update` judges by it (built 2026-11-10).

The rule, written before any run:

1. **A control run at 0 seconds, on the Studio.** It is expected to FAIL with the signature. If it
   passes, the race did not show at all, the probe cannot tell 15 seconds from none, and the measurement
   stops there for James to decide.
2. 5 of 5 at 30 on the Studio, then 5 of 5 at 15 on the Studio, then 5 of 5 at 15 on the MacBook.
3. All fifteen pass: the default becomes 15. A FAIL at 15 with 30 clean: the default becomes 30 after
   5 of 5 at 30 on the MacBook: ten runs in all, a failure rate below about 26 per cent. Any FAIL at 30: the default stays 45 and the failing run is recorded.

A run takes about four minutes with the game on screen. The Studio's eleven runs are about 45 minutes and
the MacBook's five about 20. Each batch is on James's word, with Steam closed on the other Mac.

What fifteen clean runs show: with 95 per cent confidence, a failure rate below about 18 per cent, on one
account and one network. The setting stays, so 45 can be put back by anyone.

A change of default is its own commit. It touches the launcher's call line, the recorded default in the
parity test, `cities-skylines-2/INSTALL.md:109` and a new troubleshooting row there,
`cities-skylines-2/scripts/setup.sh:226`, `cities-skylines-2/GOTCHAS.md:192-200`, and the "cs2's … is 45" note at `launch-relaunched.sh:61`.

### 3.7 Keeping the two launchers the same

`common/test-launcher-parity.sh` fails when:

1. the `launch-feedback` blocks differ by a byte. Each is taken with
   `sed -n '/^# >>> launch-feedback (/,/^# <<< launch-feedback$/p'`, because the config's markers begin
   with the same words;
2. the update-check blocks differ in any line that is not in the test's own list, or a listed line no
   longer differs. Both blocks are taken with `sed -n '/^# >>> update-check/,/^# <<< update-check/p'` and
   made equal with `sed -E 's/CS2_|SM_/X_/g; s/949230|3215050/APPID/g; s/Cities: Skylines II|Surviving
   Mars: Relaunched/TITLE/g; s/cs2-patch|sm-patch/DIR/g'`. The list starts as today's 15 lines, each with
   its reason;
3. the numbers a launcher sends to `step`, which are the first argument of each `step` call outside the
   block and of each `licence_wait` call, include one outside 0 to `STEPS`, leave one of 1 to `STEPS`
   unused, or use 0 outside `acquire_lock`;
4. a `licence_wait` call line is not the recorded one: `3 "${CS2_LICENCE_WAIT:-}" 45` and
   `2 "${SM_LICENCE_WAIT:-}" 15` today, each with the measurement behind it and each recorded with its
   indent, so a call moved out of its `if` fails;
5. a launcher's `note` call sites are not the test's list, so a start-up milestone cannot go back to a
   pop-up unseen;
6. a `step` or `note` literal holds `"` or `\`, or a `step` literal is longer than 62 characters as
   written in the source. `note` literals have no length limit; the filled-in widths are seen in the
   rehearsal, live step 3;
7. a `die` does not begin by printing `ERROR: `; a launcher calls `osascript` outside the block anywhere
   but the update question (`launch-cs2-dxmt11.sh:314`, `launch-relaunched.sh:294`); or a second `note`
   or `step` is defined outside the markers;
8. a probe's `Licence wait:` pattern does not match the line the block prints.

The test file is the table of differences kept on purpose. The lock stays in `common/test-launch-lock.sh`.

## 4. Phases

### Before A1

1. **Phase 4 of the unification plan is closed**: its last item is two commands of James's on the Studio.
   Or James says to start without it.
2. **The build happens on a branch in a second worktree**, `git worktree add /tmp/1launcher-lx -b
   launch-experience`, pushed as a branch. `main` does not move until live step 1. The Surviving Mars app
   runs the launcher in the main checkout, a launcher is never edited while it runs, and one can be
   running for hours and then spend minutes uploading saves. The worktree has no `CLAUDE.local.md`:
   it is copied from the main checkout before the first push (root `CLAUDE.md:35-37`). `/tmp` is emptied
   by a restart, so each step is committed and pushed as it is finished.
3. **The layout plan is re-checked after Phase A's last commit**, not before: both plans edit the same
   files and its line references move.

### Phase A: build order

| Step | What | Files |
|---|---|---|
| A1 | The panel source with `--parse` and `--decide`, and its test | `common/launch-progress.swift`, `common/test-launch-progress.sh` |
| A2 | The config and block in both launchers; `step`, `licence_wait`, `_alert` in use; step 0 in both lock functions; the plain `Licence wait:` line in the Surviving Mars probe | both launchers; `common/test-launch-feedback.sh`; `common/test-launch-lock.sh`; `surviving-mars-relaunched/tools/licence-wait-probe.sh` |
| A3 | The update messages as `echo` plus `step 4`, and `UPDATE_TICK`, in both update-check blocks; a `step` stub beside each `note` stub; new assertions | both launchers; both `test-update-check.sh` |
| A4 | Both builders compile the shared panel; both shims as in 3.4 | `make-shortcut.sh`, `make-app.sh`, `cities-skylines-2/scripts/test-make-shortcut.sh` (new), `surviving-mars-relaunched/tools/test-make-app.sh` |
| A5 | The parity test | `common/test-launcher-parity.sh` |
| A6 | The probe and the test of its judge | `cities-skylines-2/scripts/licence-wait-probe.sh`, `cities-skylines-2/scripts/test-licence-wait-probe.sh` |
| A7 | Docs: `cities-skylines-2/README.md:198`, `cities-skylines-2/scripts/README.md`, the Surviving Mars README (the app's window, `SM_PANEL`), root `CLAUDE.md:13`, `CS2_LICENCE_WAIT` and `CS2_PANEL` in the launcher's header, the poll target at `cities-skylines-2/docs/plans/retina-swapchain-experiment.md:254-255`, the launcher line numbers in `boot-verify.sh`'s header, the Phase 5 outline of `docs/plans/1launcher-unification.md`, the as-built header here | docs |
| A8 | Merge, install and live checks, section 6 | none |

`test-make-app.sh` needs two edits beyond new cases: its existing mutant (`:24-25`) is keyed to the old
shim line, and its existing case (`:28`) runs a freshly built shim, which would now open a real window.
The stub panel goes in before any shim runs.

### Phases B to D: outline only

James, 2026-11-10: "Maybe instead of all these icons what we need to do is pop up a small window that has
a collection of the apps that can be run. And then you just select the one you want."

- **B. One window for the group.** One app. Its window lists the installed games; choosing one turns the
  same window into the progress window, which is the panel of Phase A grown a list. It also holds what
  the games share. It replaces the two per-game apps and `CS2 Steam Store.app`, and the wrappers leave
  `~/Applications` in the same slice. Its plan must answer: how a game registers itself, with a key that
  is not its name; one game at a time, since an account holds one Steam session; Return to play the last
  game; and whether per-game shortcuts are offered, off by default.
- **C. Steam in the game's own wrapper.** The default engine build applies the two published patches, a
  button in the window opens the game's own Steam to sign in, and the store wrapper is retired. To
  measure first: the build with the Command Line Tools alone, and the sign-in window in a clone of a
  wrapper with no saved sign-in.
- **D. Updates at launch.** The window checks for a newer signed release before it starts a launcher. It
  needs releases to exist, which is the first step of `docs/plans/local-files-layout.md`, and a signing
  key, which is James's to create.

## 5. Test plan

Every mutant is applied to real source, seen red, and restored green. No test starts Wine, Steam, a game
or the real window: shims run with stub `osascript` and `pgrep` first on `PATH`, a scratch `HOME`, a stub
in place of the panel, and fake launchers that sleep one second.

| # | Test | Passes when | Mutants, each must exit 1 |
|---|---|---|---|
| LX1 | `common/test-launch-progress.sh`: compiles the panel, then `--parse` and `--decide` on fixtures. Exit 2 with a reason if `swiftc` is missing, which is not a pass | no step: `0 0`; the last step wins; an earlier session holding a step and `ERROR:` with an empty last session: `0 0`; `ERROR:` before a later step in one session: `error`; `ERROR:` or `===== ` in mid-line: no effect; game lines such as `[UnityMemory] …` after the final step: still `5 5 text`; `[6/5] x` and `[0/0] x` ignored; `[0/5] x` accepted; no `===== ` line: the whole log; no file: `0 0`; a bad byte in an earlier session: the last still parses. `--decide`: `show`, then `close` at 5 s after the final step, on `ERROR:`, at 900 s of silence, at 5400 s since start, and with the parent gone | the first step wins; the whole file is read; `ERROR:` is ignored; n above N accepted; the final step does not latch; each of the five limits removed |
| LX2 | `common/test-launch-feedback.sh`: the `QUIET=` line, the config and the block of each launcher, under `set -u`, driven by `CS2_QUIET`/`CS2_PANEL` and `SM_QUIET`/`SM_PANEL`, with a recording `osascript` and `sleep` | quiet with the panel: `step` posts 0, `note` posts 1; quiet without: 1 and 1; not quiet: 0 and 0; the line reads `[n/N] text`; the title passed is that game's; a text with `"` and `\` arrives as one unchanged argument; both AppleScript statements pass `osacompile`. `licence_wait`: unset gives sleeps 15, 15, 15 and lines at 45, 30, 15; `20` gives 15, 5 and lines at 20, 5; `15` gives one of each; `0` gives the `Licence wait: 0 s` line, no step, no sleep; `08` is 8; `abc`, empty, `9999` and `99999` are the default; the plain line is printed once | `step` ignores `PANEL`; `note` is silenced by `PANEL`; the `PANEL=` line deleted; `SM_PANEL` in the Cities: Skylines II launcher; the text pasted into the source again; the setting ignored; the remainder dropped; validation removed |
| LX3 | `common/test-launcher-parity.sh` | the eight rules of 3.7 | one byte changed in one copy of the block; a new differing line in an update-check block; a listed line made equal; a step numbered past `STEPS`; a step number unused; a wait call line changed; a milestone put back to `note`; a quote added to a step text; a probe pattern changed; the wait made unconditional; a `die` with no `ERROR:`; a `die` with its own `osascript` line; a second `note`; `step 0` outside `acquire_lock`; a 63-character step text |
| LX4 | Both `test-update-check.sh`, with `UPDATE_TICK` at 1 and a stub `step() { echo "STEP $1: $2"; }` | `^STEP 4: Updating the game\. This`; at least one `^STEP 4: Updating the game: .* so far`; `^STEP 4: The game is updated`; no `^NOTE: ` line for any of the three; a total of 0 bytes gives the text with no size and no error; the existing assertions still pass | each of the three messages through `note` again; the zero-total guard removed |
| LX5 | `test-make-shortcut.sh` (new) and `test-make-app.sh`: build into a scratch folder | the stub panel starts once, after the `=====` line, with `LP_TITLE` and `LP_LOG` set and no arguments; the launcher sees `PANEL=1`, and `CS2_HUD=1` when built with `--hud`; a stub that exits at once: the launcher sees `PANEL=0`; kills are recorded by an exported function, `kill() { echo "KILL $*" >> "$REC"; builtin kill "$@"; }; export -f kill`: no `KILL` line where the stub had ended before the launcher returned, at least one where it was alive (the `EXIT` trap can send a second); the other game's stub is still running when this shim returns; no panel file: `PANEL=0`; stub `xcrun` exits 1, the compile fails, the source is missing, or the launcher has no block: the builder exits 0, the app is complete, the reason is printed; a fake launcher that prints `ERROR: x` and exits 1: 0 shim alerts; one that exits 1 in silence: 1, also when an earlier session holds `ERROR:` | `PANEL=1` whether or not a process is alive; a plain `kill "$PANEL_PID"`; `pkill -f launch-progress`; the panel started before the `=====` line; the title passed as an argument; `${HUD_ENV}` dropped; the compile outside its `if` in `make-app.sh`; the shim always alerts; the whole log searched for `ERROR:` |
| LX6 | `cities-skylines-2/scripts/test-licence-wait-probe.sh`: `--judge` on fixture run folders, and the probe against a stub `boot-verify.sh` | a log made with 45 judged at 15: VOID; no wait line plus `ERROR:`: VOID with the reason; the signature with boot-verify 0: FAIL; boot-verify 3: VOID; the signature with boot-verify 1: FAIL; boot-verify 1 with no signature: OTHER; exit 143 with a wait line: VOID; 2 or 64: the probe stops with exit 2; three VOID in a row stop it; a second OTHER stops it; a VOID and a first OTHER are not counted toward five; with `--expect-update`, a record that read current before the boot and a launcher that says current: FAIL, a record already waiting and no update line: VOID, no record file: VOID; a launcher without the block, a game running, or Steam running: refused; the second-job seconds from fixture logs: 3, and `none` on `finished Timeout` | the wait line matched loosely; exit 3 counted as FAIL; exit 1 counted as FAIL; rules 4 and 5 swapped; an unknown exit counted as PASS; the record before the boot ignored |
| LX7 | Every existing suite that starts nothing real, 14 of the 16 files: all of `cities-skylines-2/scripts/test-*.sh`, `surviving-mars-relaunched/tools/test-*.sh` and `common/test-*.sh` bar `test-make-engine-install.sh` and `test-rosetta-preflight.sh` | each exits 0, and each of their own mutants still exits 1, not 2 | their own |
| LX8 | `bash -n` on every changed script; `ACCEPT=9 bash common/check-identifiers.sh`; `python3 common/check-links.py` | exit 0; the residual stays 9; 0 unresolved | none |
| LX9 | The live steps of section 6 | as listed there | none |

## 6. Live steps, each on James's word

1. **Merge, on the Studio, with no launcher running.** This check, wherever a step says so:

   ```bash
   for w in ~/Applications/CS2dxmt11.app ~/Applications/SurvivingMars.app; do h=$(readlink "$w/Contents/SharedSupport/prefix/.launcher.lock" 2>/dev/null); [ -n "$h" ] && kill -0 "$h" 2>/dev/null && echo "STOP: a launcher still runs in ${w##*/}"; done
   ```

   It must print nothing. A launcher outlives its game by up to five minutes while saves upload. Then
   `git merge --no-ff launch-experience` on `main`, and push.
2. **Install**, after the check of step 1. `bash scripts/setup.sh`, then the file comparison of
   `docs/plans/1launcher-unification.md` T2: 21 files with the badge patch, 20 without. `bash surviving-mars-relaunched/make-app.sh`. Both apps hold
   `Contents/Resources/launch-progress`. `test-game-running.sh` again, since it reads the installed shim.
   The two suites that start an Intel program, with one Rosetta notice each.
3. **A rehearsal of the real window against a scripted log.** Every step text of both games, the
   `ERROR:` close and the 5 second close. I capture the window's own region in light and in dark, never
   the whole screen. James starts it once from a full-screen Space and closes it once by its button.
4. **One boot check.** `bash scripts/boot-verify.sh`, detached: PASS. The launcher changed, so this is owed.
5. **Each game started once from its app, by James, with Focus off.** On a cold start the launcher log of the run
   shows `[1/5]` to `[5/5]` in order; with Steam already running the licence step is absent. No panel process is left once the game's window exists. James confirms no
   banner before the game and the closing banner after it; the closing banner is the control, and only he
   can see either. The gap from the window closing to the game's window appearing is recorded.
6. **The wait probe**, per 3.6.
7. **The MacBook.** The check of step 1, `git pull`, `bash scripts/setup.sh`, `bash
   surviving-mars-relaunched/make-app.sh`, step 5, and its probe runs. `boot-verify.sh` needs
   `~/cs2-patch/win-resize-driver.exe` there; it passed on that Mac on 2026-11-09.
8. **After a change of default**, and after the check of step 1. Setup, the file comparison and one boot
   check on each Mac.

The update path cannot be forced live. It is covered by LX4 and by the rehearsal's scripted log, and the
MacBook's waiting update shows it for real if James takes it after step 7.

## 7. Exit criteria for Phase A

- LX1 to LX8 exit 0, every mutant seen red and restored. LX1's exit 2 does not count.
- Live steps 1 to 5 pass on the Studio and step 7 on the MacBook.
- The probe has run and the default is decided by the rule of 3.6, whichever way it falls; step 8 follows
  if it changed.
- The rehearsal's captures show the window readable in light and dark, and what happened over a
  full-screen Space is written down.
- The as-built header here is written, the unification plan's Phase 5 outline points at this document for
  its first four items, and issue #22 has a line once James allows the post.

## 8. Rollback

`git revert -m 1` of the merge commit of live step 1, then, after the check of that step, `bash scripts/setup.sh` and `bash
surviving-mars-relaunched/make-app.sh` on each Mac. `launch-cs2-dxmt11.sh.bak` is only the copy that
setup replaced last, and not a way back by itself. No game file, save or setting is touched by this plan.

## 9. Decisions

| # | Question | Recommendation |
|---|---|---|
| D1 | Should the closing notification stay? | Yes. It is the only sign that Steam is down on this Mac |
| D2 | Should the update messages move into the window? | Yes, shortened as in 3.2. An update is the longest wait |
| D3 | How much evidence changes the default? | The control run and fifteen clean runs across both Macs, as in 3.6, knowing what fifteen runs can and cannot show |
| D4 | Does the first release wait for Phase A? | Yes. `v0.1.0` then includes the window |
| D5 | The order of the later phases | The group window first, then Steam, then updates, since both become buttons in it |

## Review corrections (pass 1, 2026-11-10)

Four reviewers, each returning build-ready-with-fixes. Their blockers, each confirmed against the code
before it was folded:

| # | Finding | Lens | Folded into |
|---|---|---|---|
| R1 | Rewording the Surviving Mars sign-in line broke that game's probe, which matches the player's text, and no gate saw it | all four | 3.6 (a plain `Licence wait:` line), A2, rule 8 of 3.7 |
| R2 | The claim that the first seven steps touch nothing installed was false: the Surviving Mars app runs this checkout's launcher | correctness, architecture | section 2, "Before A1" item 2, live step 1 |
| R3 | `kill "$PANEL_PID"` hours later can signal another process; measured on bash 3.2.57 | all four | 3.4, LX5 |
| R4 | Two of the three update messages are asserted nowhere, so they could stay pop-ups with every test green | tests | 3.2, A3, LX4 |

Should-fix findings folded: `${HUD_ENV}` dropped from the shim sample (3.4, LX5); `PANEL=1` meant a file
and not a window (3.4); the config lines were tested by nothing, and an unset `PANEL` under `set -u`
killed an app launch that every gate passed (3.1, LX2); the end conditions were untested (`--decide`,
LX1); a new app over an old launcher left the window stuck (3.4, the 75 minute limit); the probe's
verdicts did not follow boot-verify's exit codes, a 45 second run could count for 15, and there was no
control run (3.6, LX6); the wait's second job (3.6); `08` and five digits (3.1); text pasted into
AppleScript source (3.1); the update texts did not fit the label (3.2); the lock wait left the window
blank (step 0); a failure popped up twice (3.4); the window could not be closed (3.3); "games closed" was
the wrong test (live step 1); a second suite starts an Intel program (LX7); `test-make-app.sh`'s mutant
and its first case (section 4); 15 lines is 13 plus 2 (section 2); a run is four minutes, not three (3.6).

Not taken, with the reason:

- **"Mac fixes" in the failed-patch notes too.** That text is asserted by `test-launcher-notes.sh` and
  quoted in the install guide. Only the new step uses the wording.
- **An offset for a second game's window.** One account holds one Steam session, so two games do not
  start together in ordinary use.
- **A run after a restart, for a cold cache.** It asks James to restart each Mac for one data point. The
  Steam client's version is recorded with every run in its place.
- **`die` made identical in both launchers.** The key pause is a real difference; both now share `_alert`.

Reported and outside this plan: `boot-verify.sh`'s header cites launcher lines that were already stale
(refreshed in A7 because this build moves them again).

### Fold check (pass 1b, 2026-11-10)

One agent checked the rewrite against the code and against itself, and tried every mechanism it
specifies: the block under `set -u`, the shim fragment, both update-check blocks with their tests, and the
lock test. All of them worked. Its findings were text, and each is folded with its own wording:

| # | Finding | Folded into |
|---|---|---|
| F1 | The length rule covered `note` literals, and eight notes that stay are longer than 62 characters | rule 6 of 3.7 |
| F2 | The step-number rule counted `step` calls only, but the licence step reaches `step` through `licence_wait` | rule 3 of 3.7 |
| F3 | The first fold's line range for the wait took the `if` with it, so every warm start would have waited | 3.2, rule 4, an LX3 mutant |
| F4 | The judge passed any exit it did not know, and its test lacked a real failure's shape: the signature with exit 1 | 3.6 rules 4 to 7, LX6 |
| F5 | The second-job timing did not say which lines of two cumulative logs belong to a run, and the MacBook rule could not fail for its stated reason | 3.6 |
| F6 | A shim that should signal nothing could not be seen doing so by a test | LX5 |
| F7 | Nothing checked that `die` and the cloud alert call `_alert`, or that the parent check works | rule 7 of 3.7, `--decide`, LX1, LX3 |
| F8 | The worktree has no identity file, and a fast-forward leaves no merge to revert | "Before A1" item 2, live step 1, section 8 |

Smaller ones folded: `[0/0]`; the marker that is a prefix of the config's marker; `PROGRESS` undefined in
the fragment; an older session's `ERROR:`; a stale size in an idle record; the hard limit raised and the
setting capped at three digits; 21 files or 20; the cold-start wording of live step 5; the file lists.

## Review log

Key paths: `cities-skylines-2/launchers/launch-cs2-dxmt11.sh`, `surviving-mars-relaunched/launch-relaunched.sh`,
`cities-skylines-2/scripts/make-shortcut.sh`, `surviving-mars-relaunched/make-app.sh`,
`cities-skylines-2/scripts/setup.sh`, `cities-skylines-2/scripts/boot-verify.sh`, both `test-update-check.sh`,
`cities-skylines-2/scripts/test-launcher-notes.sh`, `surviving-mars-relaunched/tools/licence-wait-probe.sh`,
`surviving-mars-relaunched/tools/test-make-app.sh`, `common/`.

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-10 | 1, full | correctness; architecture and security; builder simulation (A1 to A6 built in a scratch copy, 14 existing suites green before and after); tests and design | four agents, then each blocker re-run or re-read inline | Claude Fable 5.2 | `cce7efb` (code as of `dc2b584`) | build-ready-with-fixes, four times; folded |
| 2026-11-10 | 1b, fitted | the fold: every mechanism tried in scratch, cross-references, counts, superseded ideas | one agent; its corrections folded with a two-sided audit, not re-read by a further agent | Claude Fable 5.2 | `07b69c3` (code as of `dc2b584`) | build-ready-with-fixes; folded |
