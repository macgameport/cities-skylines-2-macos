#!/bin/bash
# issue12-capture-control.sh — is stage 2's black full-client frame on the DISPLAY, or only in the
# CAPTURE? (issue #12, ledger C51)
#
# C51 measured one frame per run, in 2 of 3 stage-2 prod runs at 25 px / 120 ms, with the
# full-client host entirely black (top band 100 %, interior lit, the inset page child complete at
# the new width) and none in 7 stage-1 / baseline runs. Two mechanisms fit it and nothing measured
# so far separates them: a real display gap (the stretched host is retired at its replacement's
# CREATE before the replacement has presented), or an artifact of `screencapture -l`, which reads
# the window server's stored representation of a window carrying a non-identity transform.
#
# This battery separates them by changing ONLY where the pixels come from:
#   window  `-l <id>`          the stored representation — every run C35 through C51 used this
#   screen  `-R x,y,w,h`       the composited display, over the window's own rect
# Same module, same cadence, same scorer, interleaved so machine drift hits both arms alike.
#
#   black in BOTH arms   -> a display gap. Stage 2 has a real defect; it does not get promoted.
#   black in WINDOW only -> a capture artifact. Nobody ever saw it, and C51's consequence lifts.
#   black in NEITHER     -> 2-of-3 was chance; the run count is the answer, not the mechanism.
#
#   bash scripts/issue12-capture-control.sh          # 3 pairs, ~45 min, the Steam prefix is exclusive
#   N=1 bash scripts/issue12-capture-control.sh      # one pair — a smoke test of the instrument
#
# ⚠ WHILE THIS RUNS, TOUCH NOTHING IT READS (drag-session.sh, livedrag-probe.sh, the s2b module):
# bash reads a script incrementally and a mid-run edit kills the row. Run it DETACHED with a log —
# a tool timeout kills the process group and Steam with it. drag-session.sh restores the stage-1
# daily driver on its own way out, every row.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
N="${N:-3}"
OUT="${I12_OUT:-$HOME/cs2-patch/issue12/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"
# C50's calibrated coarse cadence, unchanged — this battery may only vary the capture method.
export SYNTH_PX=25 SYNTH_MS=120 SYNTH_REPEAT=3 SYNTH_PAUSE=3 PRESIZE=1000x650 SYNTH_DX=650 SYNTH_DY=350

echo "########## issue #12 capture control  $(date '+%F %T')  run dir $OUT"
echo "  module s2b $(shasum -a 256 "$HOME/cs2-patch/winemac.so.s2b" | cut -c1-16) · ${N} pair(s) · 25 px / 120 ms"

# ⚠ Each `local` on its own line. Under `set -u`, bash declares every name in a single `local`
# BEFORE evaluating any of its assignments, so `local d="$1" b="$d/x"` dies on "d: unbound
# variable" -- which is what killed this script's first run (2026-09-05).
digest() {   # digest <rundir> <label> <rowlog>
  local d="$1"
  local l="$2"
  local g="$3"
  local b="$d/bands.txt"
  local st="$d/frames/capture-state.txt"   # the probe's own out dir, not the run root
  if [ ! -s "$b" ]; then echo "   $l: NO BANDS — the row produced no frames"; return; fi
  awk -v L="$l" -v S="$(cat "$st" 2>/dev/null)" '
    { for (i=1;i<=NF;i++) {
        if ($i ~ /^T=/) { split($i,t,"="); if (t[2]+0 >= 50) tn++; if (t[2]+0 > tmx) tmx = t[2]+0 }
        if ($i ~ /^R=/) { split($i,r,"="); if (r[2]+0 >= 20) rn++; if (r[2]+0 > rmx) rmx = r[2]+0 } } }
    END { printf "   %-16s frames %2d · TOP>=50%%: %d (max %.0f%%) · right>=20%%: %d (max %.0f%%) · %s\n",
                 L, NR, tn+0, tmx+0, rn+0, rmx+0, S }' "$b"
  grep -q "VOID (screen mode)" "$d/probe.txt" 2>/dev/null && echo "      ^ VOID: locked session or a window over Steam — not evidence"
  grep -hoE "T6 (PASS|FAIL|N/A)[^·]*" "$g" 2>/dev/null | head -1 | sed 's/^/      /'
}

for r in $(seq 1 "$N"); do
  for mode in window screen; do
    id="p${r}-${mode}"; rd="$OUT/$id"
    echo "=== $id  $(date '+%T')"
    DRAG=synth CAPTURE="$mode" TRACE=+err,+macdrv,+cursor,+timestamp DRAG_OUT="$rd" \
      bash "$REPO/scripts/drag-session.sh" t3 > "$OUT/$id.log" 2>&1
    echo "    exit $?"
    digest "$rd" "$id" "$OUT/$id.log"
  done
done

echo "########## tally $(date '+%F %T')"
for mode in window screen; do
  tot=0; hit=0; void=0
  for r in $(seq 1 "$N"); do
    b="$OUT/p${r}-${mode}/bands.txt"; [ -s "$b" ] || continue
    tot=$((tot+1))
    grep -q "VOID (screen mode)" "$OUT/p${r}-${mode}/probe.txt" 2>/dev/null && void=$((void+1))
    awk '{for(i=1;i<=NF;i++) if($i ~ /^T=/){split($i,t,"="); if(t[2]+0>=50) f=1}} END{exit !f}' "$b" && hit=$((hit+1))
  done
  printf '  %-7s runs with a TOP band >= 50%% black: %d of %d   (VOID rows: %d)\n' "$mode" "$hit" "$tot" "$void"
done
echo "  read it against C51's 2 of 3 on window capture, and against 0 of 7 on stage 1 / baseline"
echo "########## done — $OUT"
