#!/bin/bash
# boot-verify.sh — boot the game through the canonical launcher, dwell, close it gracefully, judge
# the run from the logs it flushes on exit, and say PASS / FAIL / VOID in one line.
#
#   bash scripts/boot-verify.sh [--dwell N] [--hwnd HEX] [--out DIR]     # a full boot cycle
#   bash scripts/boot-verify.sh --judge-only DIR --t0 EPOCH|now          # the judge alone
#   bash scripts/boot-verify.sh --selftest                                # every judge branch, no launch
#
# ⚠ Never run a boot cycle inside a tool call that can time out. Run it detached with a log and
#   read the log from short commands. A killed process group took Steam down with it on
#   2026-09-02 and left the .crash marker behind. (`nohup`/`&` around THIS script are fine — see
#   the detachment note below; the rule that forbids them is about the launcher's Steam line.)
#
# WHY THIS EXISTS. The 2026-09-02 boot verification took three attempts, every one a harness fact:
# the script polled a log at the wrong path, ran the resize driver against the wrong prefix, matched
# the driver's CRLF output with a `$` anchor (and closed the wrong window), and was killed by a tool
# timeout that took Steam with it. Plan: docs/plans/verification-instruments.md § I1. Seed:
# ~/cs2-patch/harness-2026-09-02/boot2.sh (outside the repo).
#
# FACTS ENCODED (measured 2026-09-02; launcher/driver line numbers re-read 2026-09-03):
#   - SceneFlow.log lives at <LocalLow>/Cities Skylines II/Logs/SceneFlow.log — not the Steam game
#     dir, not the LocalLow root. It is WRITTEN LIVE, line by line: T3 left 67 lines on disk at the
#     SIGTERM, the last one 11 s before it, mtime = that line. (The 2026-09-02 belief that it is
#     "flushed on graceful exit" came from polling the wrong path — GOTCHAS 2026-09-03.) The new
#     file appears ~6 s after the game pid, so a run killed later than that leaves a FRESH, TRUNCATED
#     log (→ FAIL), and only a run that never wrote a line leaves the previous log in place (→ VOID).
#     Its first line carries [YYYY-MM-DD HH:MM:SS,mmm] in local time; `MainMenu reached` appears
#     once; `GameManager destroyed` is written only on a graceful exit. Player.log has no MainMenu.
#   - The launcher (launch-cs2-dxmt11.sh) runs Cities2.exe in the FOREGROUND (:194), then shuts
#     Steam down itself (:200-232). Never shut Steam down from here. It always exits 0 (:234); the
#     game's rc is only in its `Game exited (rc=N)` line (:200); `die` exits 1 (:48). With
#     CS2_QUIET=1 `die` shows a MODAL alert (:44) that would hang a headless run; with QUIET=0 and
#     stdin from /dev/null its `read -n1` fails and it exits at once — so it runs QUIET=0 </dev/null.
#   - The game window is class=UnityWndClass title=Cities: Skylines II. `win-resize-driver.exe close`
#     POSTS WM_CLOSE (:142) after an IsWindow refusal (:123, rc 1) and returns 0 at once (:143); the
#     game exits ~10 s later. The driver needs WINEPREFIX exported. Its output is stripped of \r here
#     regardless of the binary (the .exe is gitignored: a caller can always be running one older than
#     the source). Its pid= field is a Win32 pid, never a kill target.
#   - Attribute processes by open files against the PREFIX (`lsof -p`), never by command line —
#     webhelpers and a self-restarted steam.exe carry Windows-style argv. Never `lsof +D` the prefix
#     (91 GB). The pgrep patterns are only the candidate list; `_owns` decides.
#   - The launcher is detached into its own SESSION so a killed caller cannot take it, and Steam,
#     down. macOS ships no `setsid`; perl's POSIX::setsid does the same job. perl and bash are both
#     SIP-protected, so DYLD_* is purged on their exec — harmless: the launcher re-exports
#     DYLD_FALLBACK_LIBRARY_PATH itself (:63) before wine runs. The launcher's own "never
#     nohup/setsid" rule (:157-162) is about ITS Steam line, not about how it is started.
#   - A failed `close` (driver rc != 0, or no window found) goes straight to the SIGTERM fallback —
#     nothing was posted, so there is nothing to wait 120 s for. The signal goes to the GAME pids
#     only, never steam.exe (a TERM leaves the same .crash marker a KILL does).
#
# THE JUDGE (--judge-only DIR --t0 EPOCH runs only this; DIR is shaped like the LocalLow game dir:
# DIR/Logs/SceneFlow.log and DIR/Player.log):
#   VOID  no judged artifact for THIS run — SceneFlow.log missing, empty, unparseable, or its first
#         line's timestamp <= t0 (the previous run's log, still in place: nothing was written this run)
#   FAIL  fresh log but no `MainMenu reached`, no `GameManager destroyed`, or Player.log carries an
#         InvalidProgramException
#   PASS  otherwise
#   GRACEFUL: yes|no is derived from the log (`GameManager destroyed` present); a launch-time SIGTERM
#   fallback overrides it to `no`. A VOID run with no override prints `unknown`: the judge has no
#   artifact for the run and will not report a stale log's exit as this run's.
#   "mod logs touched" = Logs/*.log with mtime > t0 minus the engine set (SceneFlow, FileSystem,
#   Automation, Modding). The names are arbitrary; the count is informational.
#
# EXIT CODE: 0 PASS · 1 FAIL · 2 REFUSED (something already runs against the prefix; pids listed)
#            · 3 VOID · 64 usage/setup
#
# RUN DIR: ~/cs2-patch/boot-verify/<stamp>/ (--out overrides): launcher.log, the driver's window list
# and stamps, copies of the judged logs. Deliberately NOT under ~/cs2-patch/evidence/ — the ledger
# checker treats every directory there as a render cell that needs an index row.
#
# TESTS (docs/plans/verification-instruments.md T1–T3), run 2026-09-02 19:11–19:20 on module 310f13d0:
#   T1  full cycle, dwell 120: game pid +105 s · WM_CLOSE posted · exit +15 s · launcher EXIT:0 ·
#       Steam down, no .crash · SceneFlow fresh (t0+115 s), MainMenu 19:15:32, GameManager destroyed
#       1, InvalidProgramException 0 → GRACEFUL: yes, VERDICT: PASS, exit 0 (run 20260902-191156).
#       Launch-free judge fixtures: `--selftest` 8/8 — the real dir with t0=now → VOID; an empty dir,
#       a zero-byte and a timestamp-less SceneFlow → VOID; no MainMenu → FAIL; no GameManager
#       destroyed → FAIL + GRACEFUL: no; InvalidProgramException in Player.log → FAIL; intact → PASS.
#   T2  busy prefix: a symlink named wineserver → /bin/sleep holding system.reg open on fd 3
#       (`cp /bin/sleep` never appeared in ps on macOS 26, and bash tail-execs a lone `sleep` so an
#       `exec -a` name is lost — GOTCHAS 2026-09-03) → REFUSED, the pid listed, exit 2.
#   T3  `--hwnd 1 --dwell 60`: driver `not a window: 1` rc 1 → SIGTERM to the two game pids only →
#       exit at once · launcher `Game exited (rc=143)`, Steam down, EXIT:0, no .crash · judge:
#       SceneFlow FRESH but truncated (67 lines, no MainMenu) → GRACEFUL: no, VERDICT: FAIL, exit 1
#       (run 20260902-191631). Pre-registered as VOID on the "flushed on exit" belief; the run
#       corrected the belief (FACTS above). Residue: no save in flight; the truncated log is what the
#       next run's judge sees as stale.
set -u

usage() { sed -n '5,7p' "$0" >&2; exit 64; }

APP="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
SS="$APP/Contents/SharedSupport"
LAUNCHER="${CS2_LAUNCHER:-$HOME/cs2-patch/launch-cs2-dxmt11.sh}"
DRV="${CS2_DRIVER:-$HOME/cs2-patch/win-resize-driver.exe}"
export WINEPREFIX="$SS/prefix" WINEDEBUG=-all
export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"
WINE="$SS/wine/bin/wine64"
GAMEDIR="$WINEPREFIX/drive_c/users/Wineskin/AppData/LocalLow/Colossal Order/Cities Skylines II"
STEAMDIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
ENGINE_LOGS="SceneFlow FileSystem Automation Modding"

DWELL=120; HWND=""; JUDGE_DIR=""; T0=""; OUT=""; SELFTEST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dwell) shift; DWELL="${1:-}" ;;
    --hwnd) shift; HWND="${1:-}" ;;
    --out) shift; OUT="${1:-}" ;;
    --judge-only) shift; JUDGE_DIR="${1:-}" ;;
    --t0) shift; T0="${1:-}" ;;
    --selftest) SELFTEST=1 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
  shift
done
[ "$T0" = now ] && T0=$(date +%s)
case "$DWELL" in ''|*[!0-9]*) echo "--dwell wants seconds, got '$DWELL'" >&2; usage ;; esac

ts() { date '+%H:%M:%S'; }

# ---- the judge ------------------------------------------------------------------------------
judge() {   # judge <dir> <t0-epoch> <graceful-override: no|"">  -> report on stdout; returns 0/1/3
  local dir="$1" t0="$2" over="$3"
  local sf="$dir/Logs/SceneFlow.log" pl="$dir/Player.log"
  local verdict="" why="" graceful=unknown first="" tstamp="" fe="" menu="" destroyed=0 ipe=0
  echo "--- judge: $dir"
  echo "t0                      : $t0 ($(date -r "$t0" '+%F %T'))"
  if [ ! -f "$sf" ]; then verdict=VOID; why="SceneFlow.log absent"
  elif [ ! -s "$sf" ]; then verdict=VOID; why="SceneFlow.log is empty"
  else
    first=$(head -1 "$sf" | tr -d '\r')
    tstamp=$(printf '%s' "$first" | sed -nE 's/^\[([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}).*/\1/p')
    fe=""; [ -n "$tstamp" ] && fe=$(date -j -f '%Y-%m-%d %H:%M:%S' "$tstamp" +%s 2>/dev/null)
    if [ -z "$fe" ]; then verdict=VOID; why="SceneFlow.log first line carries no timestamp: ${first:0:80}"
    elif [ "$fe" -le "$t0" ]; then verdict=VOID; why="SceneFlow.log is STALE — first line $tstamp is $((t0 - fe))s before t0 (the previous run's log)"
    else
      echo "SceneFlow first line    : $tstamp (fresh, t0+$((fe - t0))s)"
      menu=$(grep -m1 'MainMenu reached' "$sf" | tr -d '\r')
      destroyed=$(grep -c 'GameManager destroyed' "$sf")
      ipe=0; [ -f "$pl" ] && ipe=$(grep -c 'InvalidProgramException' "$pl")
      echo "MainMenu reached        : ${menu:-NONE}"
      echo "GameManager destroyed   : $destroyed"
      echo "InvalidProgramException : $ipe$([ -f "$pl" ] || echo ' (Player.log absent)')"
      if [ "$destroyed" -gt 0 ]; then graceful=yes; else graceful=no; fi
      if [ -z "$menu" ]; then verdict=FAIL; why="no 'MainMenu reached'"
      elif [ "$destroyed" -eq 0 ]; then verdict=FAIL; why="no 'GameManager destroyed' — log truncated, the exit was not graceful"
      elif [ "$ipe" -gt 0 ]; then verdict=FAIL; why="$ipe InvalidProgramException line(s) in Player.log"
      else verdict=PASS; why="menu reached, graceful exit, 0 InvalidProgramException"; fi
    fi
  fi
  local n=0 names="" f b
  for f in "$dir"/Logs/*.log; do
    [ -f "$f" ] || continue
    b=$(basename "$f" .log)
    case " $ENGINE_LOGS " in *" $b "*) continue ;; esac
    [ "$(stat -f %m "$f")" -gt "$t0" ] && { n=$((n + 1)); names="$names,$b"; }
  done
  echo "mod logs touched        : $n${names:+ (${names#,})}"
  [ "$over" = no ] && graceful=no
  echo "reason                  : $why"
  echo "GRACEFUL: $graceful"
  echo "VERDICT: $verdict"
  case "$verdict" in PASS) return 0 ;; FAIL) return 1 ;; *) return 3 ;; esac
}

# ---- selftest: every judge branch from synthetic fixtures, plus the real dir as the stale case ----
mkfix() { mkdir -p "$1/Logs"; printf '%s\n' "$2" > "$1/Logs/SceneFlow.log"; : > "$1/Player.log"; }
selftest() {
  local tmp fails=0 t0 base
  tmp=$(mktemp -d /tmp/boot-verify-selftest.XXXXXX)
  base="[2026-09-02 16:24:23,008] [INFO]  Odin Serializer ArchitectureInfo initialization
[2026-09-02 16:25:25,182] [INFO]  MainMenu reached
[2026-09-02 16:26:25,618] [INFO]  GameManager destroyed (4392.995ms)"
  t0=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-09-02 16:00:00' +%s)
  mkfix "$tmp/pass" "$base"
  mkfix "$tmp/nomenu" "$(printf '%s\n' "$base" | grep -v 'MainMenu reached')"
  mkfix "$tmp/nodestroy" "$(printf '%s\n' "$base" | grep -v 'GameManager destroyed')"
  mkfix "$tmp/ipe" "$base"; echo "InvalidProgramException: Invalid IL code in Some.Mod:Method (): IL_0000" >> "$tmp/ipe/Player.log"
  mkdir -p "$tmp/empty" "$tmp/zero/Logs"; : > "$tmp/zero/Logs/SceneFlow.log"
  mkfix "$tmp/nots" "no timestamp on this line
[2026-09-02 16:25:25,182] [INFO]  MainMenu reached"
  expect() {   # expect <name> <dir> <t0> <verdict> <graceful> <rc>
    local out rc v g
    out=$(judge "$2" "$3" "" 2>&1); rc=$?
    v=$(printf '%s\n' "$out" | sed -n 's/^VERDICT: //p'); g=$(printf '%s\n' "$out" | sed -n 's/^GRACEFUL: //p')
    if [ "$v" = "$4" ] && [ "$g" = "$5" ] && [ "$rc" = "$6" ]; then echo "  ok   $1: VERDICT $v, GRACEFUL $g, rc $rc"
    else echo "  FAIL $1: got VERDICT '$v' GRACEFUL '$g' rc $rc — wanted $4 / $5 / $6"; printf '%s\n' "$out" | sed 's/^/       /'; fails=$((fails + 1)); fi
  }
  echo "selftest: fixtures in $tmp"
  expect real-dir-stale "$GAMEDIR" "$(date +%s)" VOID unknown 3
  expect empty-dir      "$tmp/empty"     "$t0" VOID unknown 3
  expect zero-byte-log  "$tmp/zero"      "$t0" VOID unknown 3
  expect no-timestamp   "$tmp/nots"      "$t0" VOID unknown 3
  expect no-mainmenu    "$tmp/nomenu"    "$t0" FAIL yes 1
  expect no-destroyed   "$tmp/nodestroy" "$t0" FAIL no 1
  expect ipe-in-player  "$tmp/ipe"       "$t0" FAIL yes 1
  expect pass           "$tmp/pass"      "$t0" PASS yes 0
  rm -rf "$tmp"
  if [ "$fails" = 0 ]; then echo "selftest: 8/8 ok"; return 0; fi
  echo "selftest: $fails FAILED"; return 1
}

if [ "$SELFTEST" = 1 ]; then selftest; exit $?; fi
if [ -n "$JUDGE_DIR" ]; then
  [ -n "$T0" ] || { echo "--judge-only needs --t0 EPOCH|now" >&2; usage; }
  judge "$JUDGE_DIR" "$T0" ""; exit $?
fi

# ---- a boot cycle ----------------------------------------------------------------------------
[ -x "$WINE" ]     || { echo "ERROR: no wine at $WINE" >&2; exit 64; }
[ -f "$LAUNCHER" ] || { echo "ERROR: no launcher at $LAUNCHER" >&2; exit 64; }
[ -f "$DRV" ]      || { echo "ERROR: no driver at $DRV — build line in scripts/win-resize-driver.c" >&2; exit 64; }

_owns() { lsof -p "$1" 2>/dev/null | grep -q "$WINEPREFIX"; }
prefix_pids() { local p; for p in $(pgrep -f 'steam|wine|Cities2|wineserver' 2>/dev/null); do [ "$p" = "$$" ] && continue; _owns "$p" && echo "$p"; done; }
game_pids()   { local p; for p in $(pgrep -f 'Cities2' 2>/dev/null); do _owns "$p" && echo "$p"; done; }
game_up()     { [ -n "$(game_pids)" ]; }
steam_up()    { local p; for p in $(pgrep -f 'steam.exe' 2>/dev/null); do _owns "$p" && return 0; done; return 1; }
alive()       { kill -0 "$1" 2>/dev/null && [ "$(ps -o stat= -p "$1" 2>/dev/null | cut -c1)" != Z ]; }   # a zombie child answers kill -0
drv()         { "$WINE" "$DRV" "$@" 2>>"$OUT/driver.err" | tr -d '\r'; return "${PIPESTATUS[0]}"; }
void_exit()   { echo "reason                  : $1"; echo "GRACEFUL: unknown"; echo "VERDICT: VOID"; exit 3; }

# 1) refuse a busy prefix
busy=$(prefix_pids)
if [ -n "$busy" ]; then
  echo "REFUSED: something already runs against $WINEPREFIX:"
  for p in $busy; do echo "  pid $p  $(ps -o command= -p "$p" 2>/dev/null | cut -c1-110)"; done
  exit 2
fi

# 2) launch, detached into its own session
OUT="${OUT:-$HOME/cs2-patch/boot-verify/$(date +%Y%m%d-%H%M%S)}"; mkdir -p "$OUT"
LOG="$OUT/launcher.log"
t0=$(date +%s)
echo "boot-verify             : run dir $OUT"
echo "t0                      : $t0 ($(date -r "$t0" '+%F %T'))"
CMD="CS2_QUIET=0 bash \"$LAUNCHER\"; echo \"EXIT:\$?\""
if command -v setsid >/dev/null 2>&1; then
  setsid bash -c "$CMD" </dev/null >"$LOG" 2>&1 &
else
  perl -MPOSIX -e 'POSIX::setsid() or warn "setsid: $!\n"; exec @ARGV or die "exec: $!\n"' -- bash -c "$CMD" </dev/null >"$LOG" 2>&1 &
fi
LP=$!
echo "launcher                : pid $LP (own session), log $LOG"

gp=""; waited=0
while [ "$waited" -lt 240 ]; do
  sleep 5; waited=$((waited + 5))
  gp=$(game_pids | head -1); [ -n "$gp" ] && break
  alive "$LP" || void_exit "launcher exited before the game started — $(grep -m1 '^ERROR:' "$LOG" || tail -1 "$LOG" | cut -c1-120); $(grep -m1 '^EXIT:' "$LOG")"
done
[ -n "$gp" ] || void_exit "no game process in ${waited}s; launcher still running (pid $LP, left alone). Log tail: $(tail -2 "$LOG" | tr '\n' ' ' | cut -c1-160)"
echo "game                    : pid $gp up at +${waited}s ($(ts))"

# 3) dwell
sleep "$DWELL"
echo "dwell                   : ${DWELL}s done at $(ts); game $(game_up && echo still up || echo GONE)"

# 4) close through the right prefix; SIGTERM the game (only) if that cannot work
over=""
drv list > "$OUT/windows.txt"
H="$HWND"
[ -n "$H" ] || H=$(grep -i 'class=UnityWndClass' "$OUT/windows.txt" | grep -i 'title=Cities' | awk '{print $1}' | head -1)
closed=0
if [ -n "$H" ]; then
  drv close "$H" >> "$OUT/driver.out"; rc=$?
  if [ "$rc" = 0 ]; then closed=1; echo "close                   : WM_CLOSE posted to $H at $(ts)"
  else echo "close                   : driver refused '$H' (rc $rc) — nothing posted"; fi
else
  echo "close                   : no UnityWndClass window in this prefix — nothing to post"
fi
if [ "$closed" = 1 ]; then
  w=0; while game_up && [ "$w" -lt 120 ]; do sleep 5; w=$((w + 5)); done
  game_up || echo "game exit               : +${w}s after WM_CLOSE ($(ts))"
fi
if game_up; then
  pids=$(game_pids | tr '\n' ' ')
  echo "game still up           : SIGTERM $pids(the GAME pids only, never steam.exe) at $(ts)"
  kill -TERM $pids 2>/dev/null; over=no
  w=0; while game_up && [ "$w" -lt 60 ]; do sleep 5; w=$((w + 5)); done
  if game_up; then echo "game STILL UP           : +${w}s after SIGTERM — left running; the judge will say VOID"
  else echo "game exit               : +${w}s after SIGTERM ($(ts))"; fi
fi

# 5) let the launcher finish its own Steam shutdown, then judge
w=0; while alive "$LP" && [ "$w" -lt 180 ]; do sleep 5; w=$((w + 5)); done
wait "$LP" 2>/dev/null
if alive "$LP"; then echo "launcher                : STILL RUNNING after ${w}s (pid $LP)"
else echo "launcher                : finished at $(ts) — $(grep -m1 '^Game exited' "$LOG" | tr -d '\r'); $(grep -m1 '^EXIT:' "$LOG")"; fi
echo "steam after             : $(steam_up && echo UP || echo down); crash marker: $([ -e "$STEAMDIR/.crash" ] && echo PRESENT || echo none)"
cp "$GAMEDIR/Logs/SceneFlow.log" "$OUT/SceneFlow.log" 2>/dev/null
cp "$GAMEDIR/Player.log" "$OUT/Player.log" 2>/dev/null
judge "$GAMEDIR" "$t0" "$over"
