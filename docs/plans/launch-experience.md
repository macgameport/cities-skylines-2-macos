# Launch experience: one progress window, no doubled pop-ups, a measured licence wait

> **Status:** draft, not yet checked. Run `check it` before any build.
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
| The 45 s wait is three fixed `sleep 15` calls with no setting | `launch-cs2-dxmt11.sh:249-259` |
| Surviving Mars has `SM_LICENCE_WAIT`, default 15, from 10 of 10 clean runs | `launch-relaunched.sh:61-65`, `:219-220`; `tools/licence-wait-probe.sh` |
| The record behind 45 is one failure signature and a 40 s fix, with no run count | `cities-skylines-2/GOTCHAS.md` section 11 |
| One Studio boot, run `20261109-210108`: sign-in answered 21:01:43, game started 21:02:37, menu 21:03:34. Steam logged nothing about licences during the wait | this plan's parent outline |
| `boot-verify.sh` starts the launcher with the caller's environment, so a setting reaches it | `cities-skylines-2/scripts/boot-verify.sh:242-246` |
| The lock functions are compared byte for byte across the two launchers | `common/test-launch-lock.sh` |
| The two update-check blocks differ in 15 lines once names, app ids and titles are made equal | measured with `sed` and `diff` on the marked blocks |
| The update-check tests stub `note` and `die` in four places | `cities-skylines-2/scripts/test-update-check.sh:71-74,150-151`; `surviving-mars-relaunched/tools/test-update-check.sh:63-64,140` |
| `test-launcher-notes.sh` takes `ensure_patches`, the one line that calls it, and the compat block out of the launcher, and supplies its own `note` | `cities-skylines-2/scripts/test-launcher-notes.sh` |

## 3. Design of Phase A

### 3.1 Step lines

A start-up milestone is one line in the launcher's output: `[n/N] text`. A person reads it in a terminal
as it is, and the window reads it from the log. Each launcher sets three values before the block:
`STEPS` (its count), `TITLE` (the game's name) and `PANEL` (`${CS2_PANEL:-0}` or `${SM_PANEL:-0}`).

The block is the same text in both launchers, between markers:

```bash
# >>> launch-feedback (the same in both launchers: common/test-launcher-parity.sh compares the copies)
step() {   # <n> <text>: a start-up milestone. The progress window reads these lines from the log.
  echo "[$1/$STEPS] $2"
  [ "$QUIET" = 1 ] && [ "$PANEL" != 1 ] && osascript -e "display notification \"$2\" with title \"$TITLE\"" >/dev/null 2>&1
  return 0
}
note() {   # something the player should see even while the progress window is up
  echo "$1"
  [ "$QUIET" = 1 ] && osascript -e "display notification \"$1\" with title \"$TITLE\"" >/dev/null 2>&1
  return 0
}
# <<< launch-feedback
```

It replaces `note` at `launch-cs2-dxmt11.sh:54-58` and `launch-relaunched.sh:97`. `die` stays as each
launcher has it: the Cities: Skylines II one pauses for a key in a terminal (`:45-53`), because that game
ships `.command` files whose Terminal window closes on exit.

Cities: Skylines II, `STEPS=5`:

| n | Text | Where | Today |
|---|---|---|---|
| 1 | Checking the game's fixes… | a new line before `:213` | the panel matched `Wrapper:` (`:154`) |
| 2 | Starting Steam and signing in… | `:227` | `note` |
| 2 | Steam is already running… | `:223` | `note` |
| 3 | Confirming the licence with Steam, about N seconds… | `:251` | `note` |
| 3 | Confirming the licence, about N seconds left… | `:254` | `note` |
| 4 | Checking for a game update… | a new line before `:333` | nothing |
| 5 | Starting Cities: Skylines II… | `:340` | `note` |

Surviving Mars, `STEPS=5`:

| n | Text | Where | Today |
|---|---|---|---|
| 1 | Starting Steam and signing in… | `:206` | `note` |
| 1 | Steam is already running… | `:204` | `note` |
| 2 | Confirming the licence with Steam, about N seconds… | `:219` | `note` |
| 3 | Checking saves with Steam Cloud… | a new line before the loop at `:228` | nothing |
| 3 | Syncing saves with Steam Cloud… | `:231` | `note` |
| 4 | Checking for a game update… | a new line before `:312` | nothing |
| 5 | Starting Surviving Mars: Relaunched… | `:316` | `note` |

In both update-check blocks the three progress messages become `step 4`: "Updating the game through
Steam…", "Still updating the game…" and "Game updated…". Everything else stays `note`: the lock wait,
a patch that failed, the compat note, the update that was declined, the missing click helper, both cloud
warnings and the closing line. The closing line tells a player with two Macs that Steam is down here.

The new line for step 1 goes on its own line. `test-launcher-notes.sh` requires exactly one line that
starts with `ensure_patches` and is not the definition, and it does not define `step`.

### 3.2 One progress window

`common/launch-progress.swift` is the heredoc of `make-shortcut.sh:158-243`, moved out and changed in
four ways:

1. **It reads `LP_TITLE` and `LP_LOG` from the environment, never from its arguments.** A game's name on
   a helper's command line is how a watcher came to be taken for the game (`make-shortcut.sh:88-91`).
2. **It parses step lines.** The current session is the text after the last line that starts with `===== `.
   In it, a line starting `ERROR:` ends the window at once. Otherwise the last line matching
   `^\[([0-9]+)/([0-9]+)\] (.*)$` sets the bar's value, its maximum and the text.
3. **It ends by what the log says, with no process matching.** It closes 5 seconds after a step whose n
   equals its N, at once on `ERROR:`, and 15 minutes after the log last grew. The longest designed silence
   is the Surviving Mars cloud sync, 5 minutes.
4. **`--parse <log>` prints `<n> <N> <text>`, `error` or `0 0` and exits with no window.** The tests use it.

The window keeps its look: 400 by 96 points, titled, floating, top right, no Dock icon, system label
colours. The first line of text is `<TITLE> is starting`.

Both builders compile it into `Contents/Resources/launch-progress`. Each resolves `common/` from its own
path. If `swiftc` or the source is missing the builder prints the existing "skipped" line and the app
falls back to notifications.

Both shims then do the same thing: start the panel if its file is there, keep its PID, pass `PANEL=1` to
the launcher only in that case, and stop that PID when the launcher returns.

```bash
PANEL=0; PANEL_PID=""
if [ -x "$PROGRESS" ]; then
  LP_TITLE="Cities: Skylines II" LP_LOG="$LOG" "$PROGRESS" >/dev/null 2>&1 &
  PANEL_PID=$!; PANEL=1
fi
CS2_QUIET=1 CS2_PANEL=$PANEL bash "$SCRIPT" >> "$LOG" 2>&1
rc=$?
[ -n "$PANEL_PID" ] && kill "$PANEL_PID" 2>/dev/null
```

The PID replaces `pkill -f 'Resources/cs2-progress'` (`:112`), which would also stop the other game's
window. `make-app.sh` runs under `set -eu`, so its compile step sits inside an `if`.

### 3.3 Pop-ups

With the window up, a cold start posts no notification before the game. Warnings, the update question,
failure alerts and the closing line are unchanged. Where the window was not built, the app behaves as
today.

### 3.4 The licence wait becomes a setting, and is then measured

`CS2_LICENCE_WAIT`, default 45, digits only (anything else reads as 45). The wait sits between
`# >>> licence-wait` and `# <<< licence-wait`, sleeps in pieces of 15 seconds and prints a `step 3` line
after each piece, with the seconds left. **The default does not change in this build.**

`cities-skylines-2/scripts/licence-wait-probe.sh <seconds> [runs]`, default 5 runs, follows the method of
`surviving-mars-relaunched/tools/licence-wait-probe.sh`. Each run is
`CS2_LICENCE_WAIT=<seconds> bash scripts/boot-verify.sh --out <dir>`, started detached as that script's
header requires. A run counts as:

- **PASS** when `boot-verify.sh` exits 0, the run's launcher log holds the step 3 line with that number,
  and neither `SceneFlow.log` nor `Player.log` of the run holds `platform service integration failed`.
- **VOID** when the launcher log lacks that step 3 line: Steam was already running, so the wait never ran.
- **FAIL** otherwise. The probe stops at the first FAIL.

It refuses while the game or this wrapper's Steam is running, and it never stops Steam itself.

The rule for the default, written before any run: 5 of 5 at 30 seconds on the Studio, then 5 of 5 at 15
on the Studio, then 5 of 5 at 15 on the MacBook. All fifteen pass: the default becomes 15. A FAIL at 15
with 30 clean: the default becomes 30 after 5 of 5 at 30 on the MacBook. Any FAIL at 30: the default stays
45 and the failing run is recorded. The change of default is its own commit, with the install guide's
"about 45 seconds" (`cities-skylines-2/INSTALL.md:109`).

### 3.5 Keeping the two launchers the same

`common/test-launcher-parity.sh` fails when:

1. the `launch-feedback` blocks differ by a byte;
2. the update-check blocks, with names, app ids and titles made equal, differ in any line that is not in
   the test's own list. The list starts as the 15 lines measured today, each with its reason;
3. a launcher's `step` calls use a number outside 1 to `STEPS`, or leave one of them unused;
4. a licence wait default is not the recorded one: 45 and 15 today, each with the measurement behind it.

The test file is the table of differences kept on purpose. The lock stays in `common/test-launch-lock.sh`.

## 4. Phases

### Phase A: build order

| Step | What | Files |
|---|---|---|
| A1 | The panel source, with `--parse`, and its test | `common/launch-progress.swift`, `common/test-launch-progress.sh` |
| A2 | The `launch-feedback` block and the step lines in both launchers; the wait as a setting | both launchers; `cities-skylines-2/scripts/test-licence-wait.sh`; `common/test-launch-feedback.sh` |
| A3 | `step` in both update-check blocks; a `step` stub beside each `note` stub, and the three messages' assertions moved to it | both launchers; both `test-update-check.sh` |
| A4 | Both builders compile the shared panel; both shims start and stop it by PID | `make-shortcut.sh`, `make-app.sh`, `cities-skylines-2/scripts/test-make-shortcut.sh` (new), `surviving-mars-relaunched/tools/test-make-app.sh` |
| A5 | The parity test | `common/test-launcher-parity.sh` |
| A6 | The probe script | `cities-skylines-2/scripts/licence-wait-probe.sh` |
| A7 | Docs: `cities-skylines-2/README.md:198`, `cities-skylines-2/scripts/README.md`, the Surviving Mars README (the app's window, `SM_PANEL`), root `CLAUDE.md:13`, the as-built header here | docs |
| A8 | Install and live checks, section 6 | none |

A1 to A7 change no installed file. Nothing reaches a game until A8.

### Phases B to D: outline only

- **B. Steam in the game's own wrapper.** The default engine build applies the two published patches, a
  sign-in path opens the game's own Steam through the launcher, and the store wrapper is retired. To
  measure first: the build with the Command Line Tools alone, and the sign-in window in a clone of a
  wrapper with no saved sign-in.
- **C. Updates at launch.** The app checks for a newer signed release before it starts the launcher. It
  needs releases to exist, which is the first step of `docs/plans/local-files-layout.md`, and a signing
  key, which is James's to create.
- **D. One app for the group.** Steam, updates and the health checks in one place, replacing
  `CS2 Steam Store.app`.

## 5. Test plan

Every mutant is applied to real source, seen red, and restored green.

| # | Test | Passes when | Mutants, each must exit 1 |
|---|---|---|---|
| LX1 | `common/test-launch-progress.sh`: compiles the panel and runs `--parse` on fixture logs. Exits 2 with a reason if `swiftc` is missing | no step: `0 0`; the last step wins; only the last session counts; `ERROR:` after a step: `error`; brackets in the text survive | the first step wins; the whole file is read; `ERROR:` is ignored |
| LX2 | `common/test-launch-feedback.sh`: the block from each launcher, with a recording `osascript` first on `PATH` | quiet with the panel: `step` posts 0 and `note` posts 1; quiet without: 1 and 1; not quiet: 0 and 0; the line reads `[n/N] text` | `step` ignores `PANEL`; `note` is silenced by `PANEL` |
| LX3 | `common/test-launcher-parity.sh` | the four rules of 3.5 | one byte changed in one copy of the block; a new differing line in an update-check block; a step numbered past `STEPS`; a wait default changed |
| LX4 | `cities-skylines-2/scripts/test-licence-wait.sh`: the marked block with a recording `sleep` | unset: 15, 15, 15 and two "left" lines; `15`: one sleep, no "left" line; `20`: 15 then 5; `abc` or empty: as unset; Steam already running: no sleep, no step 3 | the setting is ignored |
| LX5 | `test-make-shortcut.sh` and new cases in `test-make-app.sh`: build into a scratch folder, replace the panel with a recording stub, run the shim with a fake launcher | the panel starts once with `LP_TITLE` and `LP_LOG` set; the launcher sees `PANEL=1`; the stub is no longer running when the shim returns. With no panel file: the launcher sees `PANEL=0` | `PANEL=1` whether or not the file is there; the panel is never stopped |
| LX6 | Every existing suite, 16 files: `cities-skylines-2/scripts/test-*.sh`, `surviving-mars-relaunched/tools/test-*.sh`, `common/test-*.sh`, bar `test-make-engine-install.sh`, which starts an Intel program | each exits 0 | their own |
| LX7 | `bash -n` on every changed script; `ACCEPT=9 bash common/check-identifiers.sh`; `python3 common/check-links.py` | exit 0; the residual stays 9; 0 unresolved | none |
| LX8 | The live checks of section 6 | as listed there | none |

## 6. Live steps, each on James's word

1. **Install on the Studio, games closed.** `bash scripts/setup.sh`, then the 21-file comparison of
   `docs/plans/1launcher-unification.md` step 4.4: 21 found, 21 identical. `bash
   surviving-mars-relaunched/make-app.sh`. Both apps hold `Contents/Resources/launch-progress`.
2. **One boot check.** `bash scripts/boot-verify.sh`, detached: PASS. The launcher changed, so this is owed.
3. **Each game started once from its app, by James.** The window steps through its lines and closes as the
   game appears; no notification before the game; the closing notification still comes. I take a
   window-region capture of the panel, never the whole screen.
4. **The wait probe**, per 3.4. About three minutes a run, with the game on screen and a Rosetta notice at
   each start. Steam must be closed on the other Mac.
5. **The MacBook.** `git pull`, `bash scripts/setup.sh`, `bash surviving-mars-relaunched/make-app.sh`, then
   steps 3 and, if 3.4 calls for it, 4.

## 7. Exit criteria for Phase A

- LX1 to LX7 exit 0, every mutant seen red and restored.
- Live steps 1 to 3 pass on the Studio and step 5 on the MacBook.
- The probe has run and the default is decided by the rule of 3.4, whichever way it falls.
- The as-built header here is written, and the unification plan's Phase 5 outline points at this document
  for its first four items.

## 8. Rollback

`git revert` of the build commits, then `bash scripts/setup.sh` and `bash
surviving-mars-relaunched/make-app.sh` on each Mac, games closed. Setup also leaves the previous launcher
beside the new one as `launch-cs2-dxmt11.sh.bak`. No game file, save or setting is touched by this plan.

## 9. Open decisions

| # | Question | Recommendation |
|---|---|---|
| D1 | Should the closing notification stay? | Yes. It is the only sign that Steam is down on this Mac |
| D2 | Should the three update messages move into the window? | Yes, as written. An update is the longest wait |
| D3 | How many clean runs change the default? | Fifteen across both Macs, as in 3.4 |

## Review log

Key paths: `cities-skylines-2/launchers/launch-cs2-dxmt11.sh`, `surviving-mars-relaunched/launch-relaunched.sh`,
`cities-skylines-2/scripts/make-shortcut.sh`, `surviving-mars-relaunched/make-app.sh`,
`cities-skylines-2/scripts/setup.sh`, `cities-skylines-2/scripts/boot-verify.sh`, both `test-update-check.sh`,
`cities-skylines-2/scripts/test-launcher-notes.sh`, `common/`.

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
