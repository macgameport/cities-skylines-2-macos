#!/bin/bash
# licence-wait-probe.sh [--expect-update] <seconds> [runs]    does a shorter licence wait still reach the menu?
# licence-wait-probe.sh --judge [--expect-update] <run dir> <seconds> <boot-verify exit>
#                                                             one run's verdict, no launch
#
# The launcher waits after a fresh Steam sign-in before it starts the game (CS2_LICENCE_WAIT, default 45:
# one failure signature and a 40 s fix, with no run count, GOTCHAS section 11). This runs <runs> (default 5)
# boots at <seconds>, each one `CS2_LICENCE_WAIT=<seconds> bash scripts/boot-verify.sh --out <dir>`, and
# judges each from what the boot left. <seconds> is plain, 0 to 999, no leading zero. The plan, the rule
# for changing the default (written before any run) and what fifteen clean runs can show:
# docs/plans/launch-experience.md, 3.6.
#
# ⚠ Start it detached, with a log, as boot-verify.sh's header requires of a boot (a killed tool call took
#   Steam down with it on 2026-09-02). A run takes about four minutes with the game on screen.
#
# Every boot starts Steam fresh (the launcher shuts it down at exit), so each run pays the wait. It
# refuses (exit 2) when the installed launcher has no launch-feedback block, since an older launcher
# ignores the setting, and when the game or this wrapper's Steam is running. It never stops Steam
# itself: between runs it waits up to 30 s for this wrapper's Steam to be gone, and stops if it is not.
#
# THE VERDICT of one run, in this order (the first that applies):
#   1. boot-verify exit 2 or 64   STOP: refused, or setup. Not a run; the probe exits 2.
#   2. the launcher log does not hold exactly one line `Licence wait: <seconds> s`
#                                 VOID, quoting the log's first ERROR: line. The wait under test did not
#                                 happen: Steam was already up, the launch died first, or the log is of
#                                 another setting.
#      with --expect-update, for a Mac whose game has an update waiting, and no `game update waiting`
#      line in the launcher log:
#                                 FAIL when the game's record read current before the boot and the
#                                 launcher logged `Game build N is current.`: Steam had not rewritten the
#                                 record within the wait, so a player would not be told of the update
#                                 (the wait's second job, below). Otherwise VOID: the run did not test it.
#   3. boot-verify exit 3         VOID: it had no log of this run to judge.
#   4. `platform service integration failed`, in any letter case, in the run's SceneFlow.log or Player.log
#                                 FAIL, whatever the exit. This is the licence race (GOTCHAS section 11;
#                                 no kept log holds it, so the spelling is from there, and the control
#                                 run at 0 s is what confirms it). A real one reaches no menu, so
#                                 boot-verify exits 1.
#   5. boot-verify exit 1         OTHER, with boot-verify's reason: the boot failed, and not on the licence.
#   6. boot-verify exit 0         PASS
#   7. any other exit             VOID, with the code.
# "5 of 5" is five PASS. A VOID run and a first OTHER run are repeated and not counted. Three VOID in a
# row or a second OTHER stop the probe (exit 3). A FAIL ends it at once (exit 1): the rule needs no more
# than one.
#
# THE SECOND JOB. The wait also gives Steam time to refresh the game's record before the launcher's
# update check reads it (launch-cs2-dxmt11.sh, 2b). So each run records the seconds from the first
# `RecvMsgClientLogOnResponse() : … 'OK'` line of Steam's connection_log.txt stamped at or after the
# run's start to the last `UpdatesJob: finished OK` line of appinfo_log.txt in the 120 s after it (one
# sign-in can log several). 2026-11-09: 3 s. No such line, or a `finished Timeout` in that window, is
# recorded as `none`, and such a run cannot support a lower default. The default never goes below the
# largest value seen plus 5. This times Steam's app information, a stand-in for the rewrite of the
# game's record. The rewrite itself is tested, not timed, by --expect-update: before each boot, with
# Steam down, the probe reads the record as the installed launcher does (its own acf_field and
# update_pending) into manifest-before.txt. The record does not always keep a waiting update between
# sessions: on 2026-11-07 the MacBook's read current before launch and Steam rewrote it inside the 45 s
# wait (cities-skylines-2/EXPERIMENTS.md, C74). A run whose record read current and whose launcher still
# showed the update is the evidence; one whose record already showed it proves only that the check ran.
# Each verdict line ends `record before: current`, `waiting` or `unreadable` when the file is there.
#
# RUN DIRS: ~/cs2-patch/boot-verify/licence-<seconds>/<stamp>-<attempt>/, outside this public checkout:
# what boot-verify leaves (launcher.log, SceneFlow.log, Player.log), its output as boot-verify.out,
# manifest-before.txt, and this run's lines of Steam's two logs, which carry the account id. One summary line per run, with the
# Steam client's version. Exit 0 = every run passed.
#
# Tests: scripts/test-licence-wait-probe.sh (the judge on fixture run dirs, the loop against a stub
# boot-verify.sh; nothing is launched).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BV="$HERE/boot-verify.sh"
usage() { sed -n '2,4p' "$0" | sed 's/^# //' >&2; exit 64; }

# How many times a launcher log says it waited <seconds>: the plain line that licence_wait prints (the
# launcher's launch-feedback block), never the player's text, which is free to be reworded. The Surviving
# Mars probe holds the same function, and common/test-launcher-parity.sh runs both against the block.
wait_lines() { grep -c "^Licence wait: $2 s\$" "$1"; }   # <launcher log> <seconds>

epoch() { date -j -f '%Y-%m-%d %H:%M:%S' "$1" +%s 2>/dev/null; }   # a log stamp, local time
stamp() { date -r "$1" '+%Y-%m-%d %H:%M:%S'; }
second_job() {   # <run dir> -> seconds from sign-in to Steam's last finished app-info update, or `none`
  local d="$1" t0 signin last
  t0=$(sed -n 's/^t0 *: *\([0-9][0-9]*\).*/\1/p' "$d/boot-verify.out" 2>/dev/null | head -1)
  [ -n "$t0" ] || { echo none; return; }
  signin=$(awk -v t="$(stamp "$t0")" 'substr($0, 2, 19) >= t && /RecvMsgClientLogOnResponse\(\) : .*'"'"'OK'"'"'/ { print substr($0, 2, 19); exit }' "$d/connection_log.txt" 2>/dev/null)
  [ -n "$signin" ] || { echo none; return; }
  last=$(awk -v a="$signin" -v z="$(stamp $(($(epoch "$signin") + 120)))" '
    substr($0, 2, 19) < a || substr($0, 2, 19) > z { next }
    /UpdatesJob: finished Timeout/ { bad = 1 }
    /UpdatesJob: finished OK/ { ok = substr($0, 2, 19) }
    END { if (!bad && ok != "") print ok }' "$d/appinfo_log.txt" 2>/dev/null)
  [ -n "$last" ] || { echo none; return; }
  echo "$(($(epoch "$last") - $(epoch "$signin"))) s"
}

record() {   # <run dir> -> what manifest-before.txt says the game's record read before the boot, or nothing
  sed -n 's/^record before the boot: \([a-z]*\).*/\1/p' "$1/manifest-before.txt" 2>/dev/null | head -1
}

EXPECT_UPDATE=0
judge() {   # <run dir> <seconds> <boot-verify exit> -> one line that starts PASS, FAIL, VOID, OTHER or STOP
  local d="$1" s="$2" rc="$3" n r tail=""
  r=$(record "$d"); [ -n "$r" ] && tail=" | record before: $r"
  case "$rc" in
    2)  echo "STOP refused: something already runs against the wrapper (boot-verify exit 2)"; return ;;
    64) echo "STOP setup: boot-verify could not start a boot (exit 64)"; return ;;
  esac
  n=$(wait_lines "$d/launcher.log" "$s" 2>/dev/null)
  [ "${n:-0}" = 1 ] || { echo "VOID the launcher log holds ${n:-0} line(s) 'Licence wait: $s s', not one: $(grep -m1 '^ERROR:' "$d/launcher.log" 2>/dev/null | cut -c1-120)"; return; }
  if [ "$EXPECT_UPDATE" = 1 ] && ! grep -q 'game update waiting' "$d/launcher.log"; then
    if [ "$r" = current ] && grep -q '^Game build [0-9]* is current\.$' "$d/launcher.log"; then
      echo "FAIL the update check called the game current, and its record read current before the boot: Steam had not rewritten it within the wait (the wait's second job) | second job: $(second_job "$d")$tail"; return
    fi
    echo "VOID the launcher log has no 'game update waiting' line, and the record before the boot read ${r:-nothing}: the run did not test the update check"; return
  fi
  [ "$rc" = 3 ] && { echo "VOID boot-verify had no log of this run to judge (exit 3)"; return; }
  grep -qi 'platform service integration failed' "$d/SceneFlow.log" "$d/Player.log" 2>/dev/null && { echo "FAIL platform service integration failed (boot-verify exit $rc) | second job: $(second_job "$d")$tail"; return; }
  [ "$rc" = 1 ] && { echo "OTHER boot-verify failed, and not on the licence: $(sed -n 's/^reason *: *//p' "$d/boot-verify.out" 2>/dev/null | head -1 | cut -c1-120) | second job: $(second_job "$d")$tail"; return; }
  [ "$rc" = 0 ] && { echo "PASS | second job: $(second_job "$d")$tail"; return; }
  echo "VOID boot-verify exit $rc is not one of its own"
}

[ "${1:-}" = --judge ] && { JUDGE=1; shift; } || JUDGE=0
[ "${1:-}" = --expect-update ] && { EXPECT_UPDATE=1; shift; }
seconds_ok() { case "$1" in 0|[1-9]|[1-9][0-9]|[1-9][0-9][0-9]) return 0 ;; esac; echo "seconds: 0 to 999, no leading zero (got '$1')" >&2; return 1; }
if [ "$JUDGE" = 1 ]; then
  [ $# = 3 ] && seconds_ok "$2" || usage
  v=$(judge "$1" "$2" "$3"); echo "$v"
  case "$v" in STOP*) exit 2 ;; esac
  exit 0
fi

SECS="${1:-}"; RUNS="${2:-5}"
seconds_ok "$SECS" || usage
case "$RUNS" in ''|0*|*[!0-9]*) echo "runs: a count from 1 (got '$RUNS')" >&2; usage ;; esac
[ $# -le 2 ] || usage

# the same places boot-verify.sh uses, and its own tests for what runs in this wrapper
APP="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
LAUNCHER="${CS2_LAUNCHER:-$HOME/cs2-patch/launch-cs2-dxmt11.sh}"
WINEPREFIX="$APP/Contents/SharedSupport/prefix"
SLOGS="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs"
[ -f "$BV" ] || { echo "REFUSED: no boot-verify.sh beside this script"; exit 2; }
for f in _owns game_pids game_up steam_up; do
  eval "$(grep "^$f() " "$BV")"
  [ "$(type -t $f)" = function ] || { echo "REFUSED: $f not found in boot-verify.sh"; exit 2; }
done
[ -f "$LAUNCHER" ] || { echo "REFUSED: no installed launcher at $LAUNCHER (run scripts/setup.sh)"; exit 2; }
grep -q '^# >>> launch-feedback (' "$LAUNCHER" || { echo "REFUSED: the installed launcher has no launch-feedback block, so it ignores CS2_LICENCE_WAIT: run scripts/setup.sh"; exit 2; }
# The game's update record, read the way the installed launcher reads it (its 2b), before each boot.
MANIFEST="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/appmanifest_949230.acf"
for f in acf_field update_pending; do
  body=$(sed -n "/^$f() {/,/^}/p" "$LAUNCHER")   # not inside "$(...)": bash 3.2 then brace-expands {/,/^}
  eval "$body"
  [ "$(type -t $f)" = function ] || { echo "REFUSED: $f not found in the installed launcher"; exit 2; }
done
record_before() {   # <run dir>: what the launcher's update check would read now, with Steam down
  local w
  update_pending
  case "$?" in 0) w=waiting ;; 1) w=current ;; *) w=unreadable ;; esac
  echo "record before the boot: $w (StateFlags $(acf_field StateFlags), buildid $(acf_field buildid), TargetBuildID $(acf_field TargetBuildID))" > "$1/manifest-before.txt"
}
game_up && { echo "REFUSED: the game is running"; exit 2; }
steam_up && { echo "REFUSED: this wrapper's Steam is running"; exit 2; }

OUT="$HOME/cs2-patch/boot-verify/licence-$SECS"; mkdir -p "$OUT"
since() {   # <Steam log> <epoch> <copy>: the log's lines stamped at or after that moment
  awk -v t="$(stamp "$2")" 'substr($0, 1, 1) == "[" && substr($0, 2, 19) >= t' "$1" > "$3" 2>/dev/null
}
passes=0; voids=0; others=0; n=0
echo "licence wait $SECS s, $RUNS run(s), $(date '+%Y-%m-%d %H:%M'), host $(scutil --get LocalHostName 2>/dev/null), output $OUT"
while [ "$passes" -lt "$RUNS" ]; do
  n=$((n + 1)); D="$OUT/$(date +%Y%m%d-%H%M%S)-$n"; mkdir -p "$D"; record_before "$D"; t0=$(date +%s)
  CS2_LICENCE_WAIT="$SECS" bash "$BV" --out "$D" > "$D/boot-verify.out" 2>&1; rc=$?
  since "$SLOGS/connection_log.txt" "$t0" "$D/connection_log.txt"
  since "$SLOGS/appinfo_log.txt" "$t0" "$D/appinfo_log.txt"
  v=$(judge "$D" "$SECS" "$rc")
  echo "  attempt $n: $v | steam client $(sed -n 's/.*Client version: *//p' "$D/connection_log.txt" 2>/dev/null | tail -1) | ${D##*/}"
  case "$v" in
    STOP*)  echo "stopped: not a run. $passes of $RUNS passed at CS2_LICENCE_WAIT=$SECS"; exit 2 ;;
    PASS*)  passes=$((passes + 1)); voids=0 ;;
    FAIL*)  echo "FAIL at CS2_LICENCE_WAIT=$SECS, after $passes pass(es): the failing run is $D"; exit 1 ;;
    VOID*)  voids=$((voids + 1))
            [ "$voids" -ge 3 ] && { echo "stopped: three VOID runs in a row. $passes of $RUNS passed at CS2_LICENCE_WAIT=$SECS"; exit 3; } ;;
    OTHER*) others=$((others + 1)); voids=0
            [ "$others" -ge 2 ] && { echo "stopped: a second boot failed for a reason that is not the licence. $passes of $RUNS passed at CS2_LICENCE_WAIT=$SECS"; exit 3; } ;;
  esac
  for _ in $(seq 1 30); do steam_up || break; sleep 1; done
  steam_up && { echo "stopped: this wrapper's Steam is still up 30 s after attempt $n, and this never stops it. $passes of $RUNS passed at CS2_LICENCE_WAIT=$SECS"; exit 3; }
done
echo "$passes of $RUNS passed at CS2_LICENCE_WAIT=$SECS ($n attempt(s))"
exit 0
