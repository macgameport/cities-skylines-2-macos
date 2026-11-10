# Launch experience: one progress window, no doubled pop-ups, a measured licence wait

> **Status:** review pass 1 is folded (2026-11-10) and the fold is being re-checked. No build starts
> until this line carries a dated verdict.
> Written 2026-11-10. Tracking: issue #22. This is the first slice of Phase 5 of
> `docs/plans/1launcher-unification.md`, whose outline holds the findings this plan starts from.
> File and line references are as of `dc2b584`.

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
  case "$2" in ''|*[!0-9]*|?????*) w=$3 ;; *) w=$((10#$2)) ;; esac
  echo "Licence wait: $w s"
  while [ "$w" -gt 0 ]; do
    step "$1" "Steam is confirming the game licence, about $w seconds left…"
    if [ "$w" -gt 15 ]; then sleep 15; w=$((w - 15)); else sleep "$w"; w=0; fi
  done
}
# <<< launch-feedback
```

Measured on this Mac's `/bin/bash` 3.2.57 and `osascript`: a text holding `"` and `\` arrives unchanged
through the `on run` form; both statements compile; `08` reads as 8, and `abc`, an empty value and five
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
| 3 | Steam is confirming the game licence, about N seconds left… | `licence_wait 3 "${CS2_LICENCE_WAIT:-}" 45`, replacing `:249-259` | `note` |
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
`common/test-launch-lock.sh:51` gains a `step` stub beside its `note` stub.

In both update-check blocks each of the three progress messages becomes a plain `echo` of the detail,
for the log, followed by a short `step 4` for the player:

| Today, as `note` | The log keeps, as `echo` | The player sees, as `step 4` |
|---|---|---|
| Updating the game through Steam (build A -> B)… | the same line | Updating the game. This can take several minutes… |
| Still updating the game — N min so far (StateFlags …, … bytes). | the same line | Updating the game: N min so far, 3.4 of 5.1 GB… and, when Steam gives no total, Updating the game: N min so far… |
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
in. The widest above measures 312 points in a 368 point label.

### 3.3 The window

`common/launch-progress.swift` is the heredoc of `make-shortcut.sh:158-243`, moved out and changed:

1. **It reads `LP_TITLE` and `LP_LOG` from the environment, never from its arguments.** A game's name on
   a helper's command line is how a watcher came to be taken for the game (`make-shortcut.sh:88-91`).
2. **It parses step lines.** The session is the text after the last line that starts with `===== `, or
   the whole log if there is none. The log is decoded leniently, so one bad byte does not blank it. A
   line that starts `ERROR:` ends the window. Otherwise the last line matching
   `^\[([0-9]{1,2})/([0-9]{1,2})\] (.*)$` with n from 0 to N sets the bar and the text. Once a step with
   n equal to N has been seen, later lines are ignored: the game's own output follows it in the same log.
3. **It ends by what the log says, with no process matching.** It closes 5 seconds after the final step,
   at once on `ERROR:`, 15 minutes after the log last grew, 75 minutes after it started, and when its
   parent process is no longer the shim that started it. The longest designed silence is the Surviving
   Mars cloud sync, 5 minutes.
4. **Two modes for tests, both returning before any window object is made.** `--parse <log>` prints
   `<n> <N> <text>`, `error` or `0 0`. `--decide <log> <seconds since the log grew> <seconds since the
   final step, or -1> <seconds since start>` prints `show` or `close`. The window's timer calls the same
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
the source is missing, or when the launcher it was given has no `# >>> launch-feedback` line. The last
case is a new app over an older installed launcher: no step would ever arrive. `make-app.sh` gains the
"skipped" line that `make-shortcut.sh:250` has, and its compile step sits inside an `if`, because it
runs under `set -eu`.

Both shims do the same thing, in this order, after the `=====` line they already write
(`make-shortcut.sh:102`, `make-app.sh:46`):

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
  unquoted heredoc (`:77`), so every `$` above is escaped there except `${HUD_ENV}`. The Surviving Mars
  line is `SM_QUIET=1 SM_PANEL=$PANEL bash "$SCRIPT" >> "$LOG" 2>&1`.
- **One alert for one failure.** The shim's "Launch failed" alert (`make-shortcut.sh:113-116`,
  `make-app.sh:49-52`) shows only when the session holds no `ERROR:` line, because `die` has already
  shown its own.

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
detached, as `boot-verify.sh:9-12` requires of a boot. It refuses when the installed launcher has no
`launch-feedback` block, and when the game or this wrapper's Steam is running. It never stops Steam
itself. Between runs it waits up to 30 seconds for this wrapper's Steam to be gone, and stops if it is not.

`--judge <run dir> <seconds> <boot-verify exit>` gives one run's verdict with no launch, in this order:

1. boot-verify exit 2 or 64: the probe stops, "refused" or "setup". It is not a run.
2. The launcher log does not hold exactly one line `Licence wait: <seconds> s`: **VOID**, with the first
   `ERROR:` line quoted as the reason.
3. boot-verify exit 3: **VOID**.
4. `platform service integration failed` in the run's `SceneFlow.log` or `Player.log`: **FAIL**.
5. boot-verify exit 1: **OTHER**, with boot-verify's reason. The boot failed for a reason that is not the
   licence.
6. Otherwise **PASS**.

"5 of 5" means five PASS. A VOID run and a first OTHER run are repeated and not counted. Three VOID in a
row, or a second OTHER, stop the probe.

The wait has a second job (`launch-cs2-dxmt11.sh:261-265`): it gives Steam time to refresh the game's
record before the update check reads it. So each run also records the seconds from Steam's logon answer
(`connection_log.txt`) to its `UpdatesJob: finished` line (`appinfo_log.txt`); on 2026-11-09 that was 3.
The default never goes below the largest value seen plus 5. And while the MacBook's game still has its
update waiting, every run there must show the launcher's `game update waiting` line; a run without it is
a FAIL of the second job.

The rule, written before any run:

1. **A control run at 0 seconds, on the Studio.** It is expected to FAIL with the signature. If it
   passes, the race did not show at all, the probe cannot tell 15 seconds from none, and the measurement
   stops there for James to decide.
2. 5 of 5 at 30 on the Studio, then 5 of 5 at 15 on the Studio, then 5 of 5 at 15 on the MacBook.
3. All fifteen pass: the default becomes 15. A FAIL at 15 with 30 clean: the default becomes 30 after
   5 of 5 at 30 on the MacBook. Any FAIL at 30: the default stays 45 and the failing run is recorded.

A run takes about four minutes with the game on screen. The Studio's eleven runs are about 45 minutes and
the MacBook's five about 20. Each batch is on James's word, with Steam closed on the other Mac.

What fifteen clean runs show: with 95 per cent confidence, a failure rate below about 18 per cent, on one
account and one network. The setting stays, so 45 can be put back by anyone.

A change of default is its own commit. It touches the launcher's call line, the recorded default in the
parity test, `cities-skylines-2/INSTALL.md:109` and a troubleshooting row there,
`cities-skylines-2/scripts/setup.sh:226`, and the "cs2's … is 45" note at `launch-relaunched.sh:61`.

### 3.7 Keeping the two launchers the same

`common/test-launcher-parity.sh` fails when:

1. the `launch-feedback` blocks differ by a byte;
2. the update-check blocks differ in any line that is not in the test's own list, or a listed line no
   longer differs. Both blocks are taken with `sed -n '/^# >>> update-check/,/^# <<< update-check/p'` and
   made equal with `sed -E 's/CS2_|SM_/X_/g; s/949230|3215050/APPID/g; s/Cities: Skylines II|Surviving
   Mars: Relaunched/TITLE/g; s/cs2-patch|sm-patch/DIR/g'`. The list starts as today's 15 lines, each with
   its reason;
3. a launcher's `step` calls use a number outside 0 to `STEPS`, leave one of 1 to `STEPS` unused, or use
   0 outside `acquire_lock`;
4. a `licence_wait` call line is not the recorded one: `3 "${CS2_LICENCE_WAIT:-}" 45` and
   `2 "${SM_LICENCE_WAIT:-}" 15` today, each with the measurement behind it;
5. a launcher's `note` call sites are not the test's list, so a start-up milestone cannot go back to a
   pop-up unseen;
6. a `step` or `note` literal holds `"` or `\`, or is longer than 62 characters;
7. a `die` does not begin by printing `ERROR: `, or a second `note` or `step` is defined outside the
   markers;
8. a probe's `Licence wait:` pattern does not match the line the block prints.

The test file is the table of differences kept on purpose. The lock stays in `common/test-launch-lock.sh`.

## 4. Phases

### Before A1

1. **Phase 4 of the unification plan is closed**: its last item is two commands of James's on the Studio.
   Or James says to start without it.
2. **The build happens on a branch in a second worktree**, `git worktree add /tmp/1launcher-lx -b
   launch-experience`, pushed as a branch. `main` does not move until live step 1. The Surviving Mars app
   runs the launcher in the main checkout, a launcher is never edited while it runs, and one can be
   running for hours and then spend minutes uploading saves.
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
| A7 | Docs: `cities-skylines-2/README.md:198`, `cities-skylines-2/scripts/README.md`, the Surviving Mars README (the app's window, `SM_PANEL`), root `CLAUDE.md:13`, `CS2_LICENCE_WAIT` and `CS2_PANEL` in the launcher's header, the poll target at `cities-skylines-2/docs/plans/retina-swapchain-experiment.md:254-255`, the launcher line numbers in `boot-verify.sh`'s header, the as-built header here | docs |
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
| LX1 | `common/test-launch-progress.sh`: compiles the panel, then `--parse` and `--decide` on fixtures. Exit 2 with a reason if `swiftc` is missing, which is not a pass | no step: `0 0`; the last step wins; an earlier session holding a step and `ERROR:` with an empty last session: `0 0`; `ERROR:` before a later step in one session: `error`; `ERROR:` or `===== ` in mid-line: no effect; game lines such as `[UnityMemory] …` after the final step: still `5 5 text`; `[6/5] x` and `[0/0] x` ignored; `[0/5] x` accepted; no `===== ` line: the whole log; no file: `0 0`; a bad byte in an earlier session: the last still parses. `--decide`: `show`, then `close` at 5 s after the final step, on `ERROR:`, at 900 s of silence, at 4500 s since start | the first step wins; the whole file is read; `ERROR:` is ignored; n above N accepted; the final step does not latch; each of the four limits removed |
| LX2 | `common/test-launch-feedback.sh`: the config and block of each launcher, under `set -u`, driven by `CS2_QUIET`/`CS2_PANEL` and `SM_QUIET`/`SM_PANEL`, with a recording `osascript` and `sleep` | quiet with the panel: `step` posts 0, `note` posts 1; quiet without: 1 and 1; not quiet: 0 and 0; the line reads `[n/N] text`; the title passed is that game's; a text with `"` and `\` arrives as one unchanged argument; both AppleScript statements pass `osacompile`. `licence_wait`: unset gives sleeps 15, 15, 15 and lines at 45, 30, 15; `20` gives 15, 5 and lines at 20, 5; `15` gives one of each; `0` gives the `Licence wait: 0 s` line, no step, no sleep; `08` is 8; `abc`, empty and `99999` are the default; the plain line is printed once | `step` ignores `PANEL`; `note` is silenced by `PANEL`; the `PANEL=` line deleted; `SM_PANEL` in the Cities: Skylines II launcher; the text pasted into the source again; the setting ignored; the remainder dropped; validation removed |
| LX3 | `common/test-launcher-parity.sh` | the eight rules of 3.7 | one byte changed in one copy of the block; a new differing line in an update-check block; a listed line made equal; a step numbered past `STEPS`; a step number unused; a wait call line changed; a milestone put back to `note`; a quote added to a step text; a probe pattern changed |
| LX4 | Both `test-update-check.sh`, with `UPDATE_TICK` at 1 and a stub `step() { echo "STEP $1: $2"; }` | `^STEP 4: Updating the game\. This`; at least one `^STEP 4: Updating the game: .* so far`; `^STEP 4: The game is updated`; no `^NOTE: ` line for any of the three; a total of 0 bytes gives the text with no size and no error; the existing assertions still pass | each of the three messages through `note` again; a division by a zero total |
| LX5 | `test-make-shortcut.sh` (new) and `test-make-app.sh`: build into a scratch folder | the stub panel starts once, after the `=====` line, with `LP_TITLE` and `LP_LOG` set and no arguments; the launcher sees `PANEL=1`, and `CS2_HUD=1` when built with `--hud`; a stub that exits at once: the launcher sees `PANEL=0`; a stub that ended before the launcher returned: the shim signals nothing; the other game's stub is still running when this shim returns; no panel file: `PANEL=0`; stub `xcrun` exits 1, the compile fails, the source is missing, or the launcher has no block: the builder exits 0, the app is complete, the reason is printed; a fake launcher that prints `ERROR: x` and exits 1: 0 shim alerts; one that exits 1 in silence: 1 | `PANEL=1` whether or not a process is alive; a plain `kill "$PANEL_PID"`; `pkill -f launch-progress`; the panel started before the `=====` line; the title passed as an argument; `${HUD_ENV}` dropped; the compile outside its `if` in `make-app.sh`; the shim always alerts |
| LX6 | `cities-skylines-2/scripts/test-licence-wait-probe.sh`: `--judge` on fixture run folders, and the probe against a stub `boot-verify.sh` | a log made with 45 judged at 15: VOID; no wait line plus `ERROR:`: VOID with the reason; the signature with boot-verify 0: FAIL; boot-verify 3: VOID; boot-verify 1 with no signature: OTHER; 2 or 64: the probe stops with exit 2; three VOID in a row stop it; a launcher without the block: refused | the wait line matched loosely; exit 3 counted as FAIL; exit 1 counted as FAIL |
| LX7 | Every existing suite that starts nothing real, 14 of the 16 files: all of `cities-skylines-2/scripts/test-*.sh`, `surviving-mars-relaunched/tools/test-*.sh` and `common/test-*.sh` bar `test-make-engine-install.sh` and `test-rosetta-preflight.sh` | each exits 0, and each of their own mutants still exits 1, not 2 | their own |
| LX8 | `bash -n` on every changed script; `ACCEPT=9 bash common/check-identifiers.sh`; `python3 common/check-links.py` | exit 0; the residual stays 9; 0 unresolved | none |
| LX9 | The live steps of section 6 | as listed there | none |

## 6. Live steps, each on James's word

1. **Merge, on the Studio, with no launcher running.** This check, wherever a step says so:

   ```bash
   for w in ~/Applications/CS2dxmt11.app ~/Applications/SurvivingMars.app; do h=$(readlink "$w/Contents/SharedSupport/prefix/.launcher.lock" 2>/dev/null); [ -n "$h" ] && kill -0 "$h" 2>/dev/null && echo "STOP: a launcher still runs in ${w##*/}"; done
   ```

   It must print nothing. A launcher outlives its game by up to five minutes while saves upload. Then the
   branch is merged into `main` and pushed.
2. **Install.** `bash scripts/setup.sh`, then the 21-file comparison of `docs/plans/1launcher-unification.md`
   step 4.4. `bash surviving-mars-relaunched/make-app.sh`. Both apps hold
   `Contents/Resources/launch-progress`. `test-game-running.sh` again, since it reads the installed shim.
   The two suites that start an Intel program, with one Rosetta notice each.
3. **A rehearsal of the real window against a scripted log.** Every step text of both games, the
   `ERROR:` close and the 5 second close. I capture the window's own region in light and in dark, never
   the whole screen. James starts it once from a full-screen Space and closes it once by its button.
4. **One boot check.** `bash scripts/boot-verify.sh`, detached: PASS. The launcher changed, so this is owed.
5. **Each game started once from its app, by James, with Focus off.** The launcher log of the run shows
   `[1/5]` to `[5/5]` in order. No panel process is left once the game's window exists. James confirms no
   banner before the game and the closing banner after it; the closing banner is the control, and only he
   can see either. The gap from the window closing to the game's window appearing is recorded.
6. **The wait probe**, per 3.6.
7. **The MacBook.** The check of step 1, `git pull`, `bash scripts/setup.sh`, `bash
   surviving-mars-relaunched/make-app.sh`, step 5, and its probe runs. `boot-verify.sh` needs
   `~/cs2-patch/win-resize-driver.exe` there; it passed on that Mac on 2026-11-09.
8. **After a change of default.** Setup, the 21-file comparison and one boot check on each Mac.

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

`git revert` of the merge, then, after the check of live step 1, `bash scripts/setup.sh` and `bash
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

## Review log

Key paths: `cities-skylines-2/launchers/launch-cs2-dxmt11.sh`, `surviving-mars-relaunched/launch-relaunched.sh`,
`cities-skylines-2/scripts/make-shortcut.sh`, `surviving-mars-relaunched/make-app.sh`,
`cities-skylines-2/scripts/setup.sh`, `cities-skylines-2/scripts/boot-verify.sh`, both `test-update-check.sh`,
`cities-skylines-2/scripts/test-launcher-notes.sh`, `surviving-mars-relaunched/tools/licence-wait-probe.sh`,
`surviving-mars-relaunched/tools/test-make-app.sh`, `common/`.

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-10 | 1, full | correctness; architecture and security; builder simulation (A1 to A6 built in a scratch copy, 14 existing suites green before and after); tests and design | four agents, then each blocker re-run or re-read inline | Claude Fable 5.2 | `cce7efb` (code as of `dc2b584`) | build-ready-with-fixes, four times; folded |
