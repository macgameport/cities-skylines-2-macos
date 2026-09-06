#!/bin/bash
# strip-module-ab.sh — baseline vs stage 1 vs stage 2 over the WHOLE drag (ledger C50 re-measured).
#
# C50 compared the three modules at FRAMES=60, which samples 8-9 s of a 35.4 s drag (C53). Its A/B
# is internally consistent but it is a FIRST-QUARTER comparison, and the numbers it produced do not
# survive contact with full coverage: stage 2 scored a growing-frame right-band mean of 5.2 % there
# and 39.6 % here on the same module and cadence. Nothing about which module is better can rest on
# that until the comparison is re-run over the whole drag.
#
# It also re-opens C51's control. "0 of 7 stage-1 / baseline runs showed the black full-client
# frame" was ALSO measured at quarter coverage, and two of the three black frames C53 found sat at
# frames 130 and 180 -- unreachable at 60. So this battery scores the TOP band per module too: if
# the black frame turns up on stage 1 or on the baseline at full coverage, it is not a stage-2
# defect at all and issue #12's premise goes with it.
#
#   bash scripts/strip-module-ab.sh              # 5 runs per module, interleaved, ~55 min
#   N=2 bash scripts/strip-module-ab.sh          # a short version
#
# Window capture throughout: it is the mode every prior row used, and C53 measured the region
# capture's tracking lag attenuating exactly this signal.
#
# ⚠ WHILE THIS RUNS, TOUCH NOTHING IT READS. Run it DETACHED with a log. drag-session.sh restores
# the stage-1 daily driver on its own way out, every row.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
N="${N:-5}"
# Which arms to run. Default is C54's three-way. `MODULES="baseline s1diag" N=10` is the
# follow-up: does the black frame occur on the pre-stage-1 baseline at all (C54 left that at
# Fisher p = 0.444, unclaimed), and on the stage-1 DIAG build what colour is the black region --
# green = a host reframed larger than its content, blue = the child's own layer before its first
# drawable, magenta = the deferred create path, black with no colour = nothing hosting it. The
# T* colour columns are already in bands.txt, so this needs no new scoring.
MODULES="${MODULES:-baseline stage1 s2b}"
OUT="${AB_OUT:-$HOME/cs2-patch/strip-ab/$(date +%Y%m%d-%H%M%S)}"
TAG="$(basename "$OUT")"
mkdir -p "$OUT"
export SYNTH_PX=25 SYNTH_MS=120 SYNTH_REPEAT=3 SYNTH_PAUSE=3 PRESIZE=1000x650 SYNTH_DX=650 SYNTH_DY=350
export FRAMES="${FRAMES:-300}" CAPTURE=window

echo "########## strip module A/B (whole drag)  $(date '+%F %T')  run dir $OUT"
echo "  N=$N per module · FRAMES=$FRAMES · 25 px / 120 ms · window capture"
for m in $MODULES; do
  case "$m" in s1diag) f="$HOME/cs2-patch/winemac.so.s1-diag" ;; *) f="$HOME/cs2-patch/winemac.so.$m" ;; esac; [ -f "$f" ] || { echo "missing $f"; exit 2; }
  echo "  $m  $(shasum -a 256 "$f" | cut -c1-16)"
done

digest() {   # digest <rundir> <label> <diag: 1 if the module paints diagnostic colours>
  local d="$1"
  local l="$2"
  local dg="${3:-0}"
  local b="$d/bands.txt"
  if [ ! -s "$b" ]; then echo "   $l: NO BANDS"; return; fi
  python3 "$REPO/scripts/band-counts.py" "$b" 2>/dev/null | sed "s/^/   $l · /"
  awk -v L="$l" '{for(i=1;i<=NF;i++) if($i ~ /^T=/){split($i,t,"="); if(t[2]+0>=50) n++; if(t[2]+0>mx) mx=t[2]+0}}
    END{printf "   %s · TOP>=50%% (the C51 black frame): %d frames, max %.0f%%\n", L, n+0, mx+0}' "$b"
  # On a DIAG build the host backgrounds are painted, so a black frame that carries a colour names
  # its own mechanism: green = a host reframed larger than its content, blue = the child's own layer
  # before its first drawable, magenta = the deferred create path. All-zero = nothing is hosting the
  # area at all. These columns are already in darkboxes' output; nothing new is computed here.
  # ⚠ Only a DIAG build paints them. On a prod module every colour reads 0 by construction, so the
  # "nothing hosts it" note would be a false inference -- it is gated on $dg, not on the numbers.
  awk -v L="$l" -v DG="$dg" '{
      T=""; for(i=1;i<=NF;i++) if($i ~ /^T=/){split($i,t,"="); T=t[2]+0}
      if (T>=50) { g=r=b=m=0
        for(i=1;i<=NF;i++){ if($i ~ /^Tgreen=/){split($i,x,"="); g=x[2]+0}
                            if($i ~ /^Tred=/){split($i,x,"="); r=x[2]+0}
                            if($i ~ /^Tblue=/){split($i,x,"="); b=x[2]+0}
                            if($i ~ /^Tmagenta=/){split($i,x,"="); m=x[2]+0} }
        if (DG+0 == 1)
          printf "   %s ·   %s top band: black %.0f%% · green %.0f%% · blue %.0f%% · magenta %.0f%% · red %.0f%%%s\n",
                 L, $1, T, g, b, m, r, (g<1 && b<1 && m<1 ? "   <- no diagnostic colour: NOTHING hosts that area" : "   <- attributed")
        else
          printf "   %s ·   %s top band: black %.0f%% (prod build -- no colours painted, attribution needs the diag arm)\n", L, $1, T }
    }' "$b"
}

for r in $(seq 1 "$N"); do
  for m in $MODULES; do
    case "$m" in
      s1diag)   role=t0; mod="" ;;
      baseline) role=s1; mod="$HOME/cs2-patch/winemac.so.baseline" ;;
      stage1)   role=s1; mod="" ;;
      s2b)      role=t3; mod="" ;;
    esac
    id="r${r}-${m}"; rd="$OUT/$TAG-$id"      # unique for all time -- see GOTCHAS on merged cells
    echo "=== $id  $(date '+%T')"
    if [ -n "$mod" ]; then
      DRAG=synth MODULE="$mod" TRACE=+err,+macdrv,+cursor,+timestamp DRAG_OUT="$rd" \
        bash "$REPO/scripts/drag-session.sh" "$role" > "$OUT/$id.log" 2>&1
    else
      DRAG=synth TRACE=+err,+macdrv,+cursor,+timestamp DRAG_OUT="$rd" \
        bash "$REPO/scripts/drag-session.sh" "$role" > "$OUT/$id.log" 2>&1
    fi
    echo "    exit $?"
    case "$m" in s1diag) dg=1 ;; *) dg=0 ;; esac
    digest "$rd" "$id" "$dg"
  done
done

echo "########## tally $(date '+%F %T')"
for m in $MODULES; do
  python3 - "$OUT" "$TAG" "$m" "$N" "$REPO" <<'PY'
import sys, os, re, subprocess
out, tag, mod, n, repo = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
# Parse band-counts.py rather than recomputing: C50's growing-frame metric is DEFINED by that
# script (it joins bands to frames/sizes.txt), and a re-implementation that classifies "growing"
# from the captured image width instead scores the same file 41.2% where band-counts says 39.6%.
# The point of this battery is comparability with C50, so the number must come from the same code.
means, tops, hits, runs = [], [], 0, 0
for r in range(1, n+1):
    d = os.path.join(out, f"{tag}-r{r}-{mod}")
    b = os.path.join(d, "bands.txt")
    if not os.path.exists(b): continue
    runs += 1
    o = subprocess.run(["python3", os.path.join(repo, "scripts/band-counts.py"), b],
                       capture_output=True, text=True).stdout
    m = re.search(r"growing frames \(\d+ of \d+\): mean ([\d.]+)%", o)
    if m: means.append(float(m.group(1)))
    t = 0.0
    for ln in open(b):
        mt = re.search(r" T=([\d.]+)", ln)
        if mt: t = max(t, float(mt.group(1)))
    tops.append(t)
    if t >= 50: hits += 1
avg = sum(means)/len(means) if means else 0
print("  %-9s runs %d · growing-frame right band, mean of run means: %5.1f%% (n=%d) · worst top band %3.0f%% · runs with the black frame: %d"
      % (mod, runs, avg, len(means), max(tops) if tops else 0, hits))
PY
done
echo "########## done — $OUT"
