#!/bin/bash
# stage2-tests.sh — the stage-2 rows of docs/plans/exposed-edge-live-resize.md, now that a drag can
# be synthesised (win-resize-driver.exe sizedrag runs win32u's own SC_SIZE loop, 2026-09-04).
#
#   bash scripts/stage2-tests.sh          # every row below, ~20 min, the Steam prefix is exclusive
#   ROWS="S-A S-D" bash scripts/stage2-tests.sh
#
#   S-A  prod s2b, synthetic drag   — the mechanism: root passes read the loop, stretches fire, the
#                                     end-of-loop re-derive runs once per segment; T6; bands
#   S-B  diag s2b, synthetic drag   — the same drag with the colours, so any black left is attributed
#   S-C  MUTANT E4' sig-off, synth  — the loop is never seen: 0 stretches, every pass reads loop 0.
#                                     Must come out RED, or S-A's stretches are not the signal's.
#   S-D  prod s2b, churn (T10)      — a SetWindowPos churn never enters the loop: 0 stretches,
#                                     loop 0 on every pass. The containment guard, now a real control.
#   S-E  MUTANT E4 sig-on, churn    — the arming guard DROPPED: the churn must stretch (T10 RED), or
#                                     the guard in S-D is an accident of the fixture.
#                                     ⚠ E4 drops the guard rather than forcing the flag TRUE. A
#                                     forced flag is correctly REFUSED by the hwndMoveSize pairing
#                                     (`07cd84d`) -- measured 2026-09-04, `return TRUE` left the
#                                     churn at 0 stretches, which would have read as T10 green from
#                                     a mutant that never bound. See signal-mutants.py.
#
# Every row leaves its full run dir behind; the summary here is a digest, not the evidence.
#
# ⚠ WHILE THIS RUNS, TOUCH NOTHING IT READS. It re-reads drag-session.sh per row and re-reads the
# four ~/cs2-patch/winemac.so.s2b* modules as it installs them, and bash reads a script
# incrementally. On 2026-09-04 an edit to drag-session.sh landed in the instant row S-C launched
# and the row died on "unexpected EOF" (exit 2, no evidence); the same run had its modules rebuilt
# underneath it, so S-D/S-E could not say which build they measured. Finish the run, then edit.
# stage1-tests.sh does NOT restore the daily driver on exit (drag-session.sh does), so the runner
# restores it itself, last -- a mutant left installed is the failure class GOTCHAS 2026-09-03 names.
# Run it DETACHED with a log: a tool timeout kills the process group and Steam with it.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SS="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}/Contents/SharedSupport"
INST="$SS/wine/lib/wine/x86_64-unix/winemac.so"
DAILY="$HOME/cs2-patch/winemac.so.stage1"
OUT="${STAGE2_OUT:-$HOME/cs2-patch/stage2-tests/$(date +%Y%m%d-%H%M%S)}"
ROWS="${ROWS:-S-A S-B S-C S-D S-E}"
TAG="$(basename "$OUT")"
mkdir -p "$OUT"
restore() { cp "$DAILY" "$INST" && echo "daily driver restored: $(shasum -a 256 "$INST" | cut -c1-16)"; }
trap restore EXIT
echo "########## stage 2 tests $(date '+%F %T')  run dir $OUT"
for m in s2b s2b-diag s2b-sigoff s2b-sigon; do
  f="$HOME/cs2-patch/winemac.so.$m"; [ -f "$f" ] || { echo "missing $f"; exit 2; }
  echo "  $m  $(shasum -a 256 "$f" | cut -c1-16)"
done

digest() {   # digest <log> <stdout.txt>  -- the lines a reader needs, from the row's own outputs
  grep -E "^  (SC_SIZE|GUI_INMOVESIZE|root passes|stage-2 stretches|bands|  right band|T6|VOID|ABORT|EXPOSED|distinct|frames [0-9])" "$1" 2>/dev/null | sed 's/^/   /'
  grep -E "EXPOSED-EDGE|VOID|ABORT|distinct scales|T6" "$1" 2>/dev/null | grep -v "^  " | sed 's/^/   /'
  if [ -f "$2" ]; then
    printf '    trace: root passes loop=1 %s · loop=0 %s · stretched %s · declined %s · size_move_ended %s · SysCommand SC_SIZE %s\n' \
      "$(grep -c 'size/move loop 1' "$2")" "$(grep -c 'size/move loop 0' "$2")" "$(grep -c 'live resize)' "$2")" \
      "$(grep -c 'not full-client' "$2")" "$(grep -c 'macdrv_size_move_ended' "$2")" "$(grep -cE 'macdrv_SysCommand .*, f00[1-8], ' "$2")"
  else
    echo "    trace: (no stdout.txt)"
  fi
}
row() {   # row <id> <cmd...>
  local id="$1"; shift
  case " $ROWS " in *" $id "*) ;; *) return 0 ;; esac
  echo "=== $id  $(date '+%T')"
  "$@" > "$OUT/$id.log" 2>&1; echo "    exit $?"
}
row S-A env DRAG=synth TRACE=+err,+macdrv,+cursor DRAG_OUT="$OUT/S-A-$TAG" bash "$REPO/scripts/drag-session.sh" t3
digest "$OUT/S-A.log" "$OUT/S-A-$TAG/stdout.txt"
row S-B env DRAG=synth TRACE=+err,+macdrv,+cursor DRAG_OUT="$OUT/S-B-$TAG" bash "$REPO/scripts/drag-session.sh" t2b
digest "$OUT/S-B.log" "$OUT/S-B-$TAG/stdout.txt"
row S-C env DRAG=synth TRACE=+err,+macdrv,+cursor MODULE="$HOME/cs2-patch/winemac.so.s2b-sigoff" DRAG_OUT="$OUT/S-C-$TAG" bash "$REPO/scripts/drag-session.sh" t3
digest "$OUT/S-C.log" "$OUT/S-C-$TAG/stdout.txt"
row S-D env CHURNS=1 MODULE="$HOME/cs2-patch/winemac.so.s2b" STAGE1_OUT="$OUT/S-D-$TAG" bash "$REPO/scripts/stage1-tests.sh"
digest "$OUT/S-D.log" "$OUT/S-D-$TAG/stdout.txt"
row S-E env CHURNS=1 MUTANT=1 MODULE="$HOME/cs2-patch/winemac.so.s2b-sigon" STAGE1_OUT="$OUT/S-E-$TAG" bash "$REPO/scripts/stage1-tests.sh"
digest "$OUT/S-E.log" "$OUT/S-E-$TAG/stdout.txt"
echo "########## done $(date '+%F %T') — $OUT"
