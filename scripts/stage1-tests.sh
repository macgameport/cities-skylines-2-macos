#!/bin/bash
# stage1-tests.sh — the stage-1 rows of docs/plans/exposed-edge-live-resize.md, in one command.
#
#   bash scripts/stage1-tests.sh                 # T2a (churn x3) + T4 seam + T6 trace
#   CHURNS=1 bash scripts/stage1-tests.sh        # one churn, for a quick read
#   T7=1 bash scripts/stage1-tests.sh            # T7 instead: width churn then height churn, x1 each
#   DIAG=1 MODULE=~/cs2-patch/winemac.so.diagfix bash scripts/stage1-tests.sh
#                                              # T2a proper: a colour build, scored per SOURCE
#
# Steam is brought up ONCE through the cell harness (so every run is fingerprinted and a run with no
# font library is refused, EXPERIMENTS.md) and left up for every row; shimmer-probe.sh does not
# launch Steam itself, and pointing it at a dead prefix aborts with "no SDL_app top-level window".
#
# The STORE page is the fixture: two hosted CefBrowserWindow siblings and black artwork in the lower
# tiles, which is what C35/C36 measured. The library has one host and cannot show S4.
#
# Run it DETACHED with a log — a tool timeout kills the process group and takes Steam with it.
# (macgameport, 2026-09-03)
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SS="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}/Contents/SharedSupport"
W="$SS/wine/bin/wine64"; S="$SS/prefix/drive_c/Program Files (x86)/Steam"
DRV="${CS2_DRIVER:-$HOME/cs2-patch/win-resize-driver.exe}"
INST="$SS/wine/lib/wine/x86_64-unix/winemac.so"
# ⚠ NOT named OUT_DIR. shimmer-probe.sh reads OUT_DIR and `rm -rf`s it (its line 29), so a runner
# that exports OUT_DIR has its own run directory deleted at the start of every churn -- the probe
# log vanishes, the frame copy finds nothing, and the scorer silently reads whatever was left in
# /tmp/shimmer-churn from an EARLIER run. Measured 2026-09-03: four churns across two modules all
# returned byte-identical band counts, which is what an unchanged stale directory looks like.
OUT="${STAGE1_OUT:-$HOME/cs2-patch/stage1-tests/$(date +%Y%m%d-%H%M%S)}"
CHURNS="${CHURNS:-3}"
MODULE="${MODULE:-}"        # optional: install this .so first (A/B against a saved build)
mkdir -p "$OUT"
export WINEPREFIX="$SS/prefix"
export DYLD_FALLBACK_LIBRARY_PATH="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"

_owns() { lsof -p "$1" 2>/dev/null | grep -q "$WINEPREFIX"; }
steam_up() { for p in $(pgrep -f "steam.exe" 2>/dev/null); do _owns "$p" && return 0; done; return 1; }
steam_family() { for p in $(pgrep -f "steam" 2>/dev/null); do _owns "$p" && echo "$p"; done; }
down() {   # never kill -9 steam.exe: a 0-byte .crash makes the next launch exit 1
  steam_up && WINEDEBUG=-all "$W" "$S/steam.exe" -shutdown >/dev/null 2>&1
  for _ in $(seq 30); do steam_up || break; sleep 1; done
  steam_up && { "$SS/wine/bin/wineserver" -k >/dev/null 2>&1; sleep 3; }
  local left; left=$(steam_family | tr '\n' ' ')
  [ -n "$left" ] && { "$SS/wine/bin/wineserver" -k >/dev/null 2>&1; sleep 2
                      left=$(steam_family | tr '\n' ' '); [ -n "$left" ] && kill $left 2>/dev/null; }
  return 0
}
CAF=""
cleanup() { [ -n "$CAF" ] && kill "$CAF" 2>/dev/null; down; }
trap cleanup EXIT
caffeinate -d -i -u -t 5400 & CAF=$!
drv() { WINEDEBUG=-all "$W" "$DRV" "$@" 2>/dev/null | tr -d '\r'; }

down                        # a module swap needs Steam down: down() first, install second
[ -n "$MODULE" ] && { cp "$MODULE" "$INST" || exit 1; }
echo "########## stage 1 tests $(date '+%F %T')  module $(shasum -a 256 "$INST" | cut -c1-16)"
echo "  run dir: $OUT"
# One cell label per RUN. The label alone names the cell directory, so a fixed label means every
# run overwrites the previous run's config.json -- and a fingerprint that does not belong to the
# result it sits beside is worse than none. EXPERIMENTS.md carries the caveat this repairs: four
# A/B sessions on 2026-09-03 all recorded under the single label `stage1`.
CELL="stage1-$(basename "$OUT")"
WINEDEBUG=+err,+macdrv bash "$REPO/scripts/steam-render-cell.sh" \
    --label "$CELL" --keep-running >"$OUT/cell.txt" 2>&1
steam_up || { echo "  VOID: $(grep -m1 FATAL "$OUT/cell.txt" | cut -c1-120)"; exit 1; }
WINEDEBUG=-all "$W" "$S/steam.exe" steam://store >/dev/null 2>&1; sleep 15
H=$(drv list | grep 'class=SDL_app' | grep 'title=Steam$' | awk '{print $1}' | head -1)
[ -z "$H" ] && { echo "  VOID: no Steam SDL_app window after navigating to the store"; exit 1; }
drv tree "$H" > "$OUT/tree.txt"; echo "  hosted children:"; sed 's/^/    /' "$OUT/tree.txt"

[ -x /tmp/darkboxes ] || swiftc -O "$REPO/scripts/darkboxes.swift" -o /tmp/darkboxes || exit 1
run_probe() {   # run_probe <label> [env assignments...]
  local label="$1"; shift
  echo "=== $label"
  # Each churn gets its own OUT_DIR: the probe wipes whatever it is pointed at, and two churns
  # sharing one directory means the second silently overwrites the first's frames.
  ( eval "$@" OUT_DIR="$OUT/$label" bash "$REPO/scripts/shimmer-probe.sh" churn ) \
      >"$OUT/$label.log" 2>&1
  grep -E "EXPOSED-EDGE|gaps|frames|ABORT|VOID" "$OUT/$label.log" | sed 's/^/    /'
  # The probe's own EXPOSED-EDGE line ORs all four bands, and its B band over-flags on the store
  # page's own black artwork. C35/C36 scored the RIGHT band; so does this -- per band, frames kept.
  local n; n=$(ls "$OUT/$label"/f*.png 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" = 0 ] && { echo "    VOID: the probe wrote no frames to $OUT/$label"; return 1; }
  # A window that renders NOTHING scores every band 100% black and every diagnostic colour 0 --
  # which reads as "no S1, no S2, no S3", i.e. exactly like a fix that worked. Measured
  # 2026-09-03: a Steam boot whose GPU process never posted a remote layer produced
  # `GREEN 0 | MAGENTA 0 | BLUE 0 | BLACK 35/40` and looked like a pass. The interior is the
  # discriminator -- a real store page has lit pixels in the middle whatever the edges do.
  # ⚠ On a MUTANT run a black window can be the RESULT, not a void: mutant E5 (anchor at the
  # opposite corner) places every layer off-screen, so the window is black with ~2050 placement
  # traces behind it. Set MUTANT=1 and the guard reports without failing the row -- the trace count
  # below is what separates "nothing rendered" from "rendered somewhere invisible".
  local imax; imax=$(sed -nE 's/.*interior-lum .*max ([0-9]+).*/\1/p' "$OUT/$label.log" | tail -1)
  if [ -n "$imax" ] && [ "$imax" -eq 0 ] 2>/dev/null; then
    if [ "${MUTANT:-0}" = 1 ]; then
      echo "    interior max luminance 0 -- expected for a mutant that hides content; not void"
    else
      echo "    VOID: interior max luminance 0 -- the whole window is black, nothing rendered"
      return 1
    fi
  fi
  /tmp/darkboxes 6 "$OUT/$label"/f*.png > "$OUT/$label-bands.txt" 2>/dev/null
  python3 "$REPO/scripts/band-counts.py" "$OUT/$label-bands.txt" | sed 's/^/    /'
  # T2a's criteria are per COLOUR, not just per band: green = S1 (an existing host placed larger
  # than its content), magenta = S2 (create path), blue = S3 (the child's own layer). Only a DIAG
  # build paints them -- on a prod module every black frame scores S4 by construction, so asking
  # for the split there would read as a result when it is an artefact. Hence opt-in.
  if [ "${DIAG:-0}" = 1 ]; then
    python3 "$REPO/scripts/darkboxes-attrib.py" 6 "$OUT/$label"/f*.png \
        > "$OUT/$label-attrib.txt" 2>&1
    tail -1 "$OUT/$label-attrib.txt" | sed 's/^/    /'
  fi
}

if [ "${T7:-0}" = 1 ]; then
  run_probe t7-width  "CHURN_A=2200x1500 CHURN_B=2400x1500 CHURN_N=240"
  run_probe t7-height "CHURN_A=2400x1360 CHURN_B=2400x1500 CHURN_N=240"
else
  i=1; while [ "$i" -le "$CHURNS" ]; do run_probe "t2a-churn-$i"; i=$((i+1)); done
  echo "=== T4 seam — the blackout sizes, at rest and while scaled"
  for sz in 2400x1500 2399x1499 2400x1500; do
    drv drive "$H" "$sz" >/dev/null; sleep 2
    id=$(/tmp/winlist 2>/dev/null | grep 'title=Steam$' | head -1 | sed -E 's/^id=([0-9]+).*/\1/')
    [ -n "$id" ] && { screencapture -x -o -l "$id" "$OUT/t4-$sz.png" 2>/dev/null
                      echo "    $sz  $(/tmp/pixel-probe "$OUT/t4-$sz.png" 2>/dev/null | tr '\n' ' ' | cut -c1-160)"; }
  done
  echo "=== static control"
  ( OUT_DIR="$OUT/static" bash "$REPO/scripts/shimmer-probe.sh" static ) >"$OUT/static.log" 2>&1
  grep -E "gaps|frames|ABORT|VOID" "$OUT/static.log" | sed 's/^/    /'
  # T2a's own criterion is "static 0 gaps". A static window showing an exposed edge is not a
  # finding about the resize path -- it means this session never rendered, and the churns above
  # are void with it.
  grep -qE "EXPOSED-EDGE frames .*: 0 of" "$OUT/static.log" ||
      echo "    ${MUTANT:+(mutant) }VOID: the STATIC control shows an exposed edge -- this session did not render"
fi
# The cell's log keeps growing while Steam stays up, so it is copied LAST -- copying it right
# after the cell captured only the boot and made every T6 trace invisible (2026-09-03).
cp "/tmp/steam-cell-$CELL/stdout.txt" "$OUT/stdout.txt" 2>/dev/null
echo "=== T6 trace — scale, last 12 lines"
grep -E "context [0-9]+ frame .* scale" "$OUT/stdout.txt" 2>/dev/null | tail -12 | sed 's/^/    /'
echo "  distinct scales seen: $(grep -oE 'scale [0-9.]+,[0-9.]+' "$OUT/stdout.txt" 2>/dev/null | sort | uniq -c | tr '\n' ' ')"
# No placement trace at all means no hosted layer was ever placed, so nothing above measured the
# hosting path. Stated last because it condemns the whole run, not one row.
NSCALE=$(grep -c 'scale [0-9]' "$OUT/stdout.txt" 2>/dev/null || echo 0)
[ "$NSCALE" -eq 0 ] && echo "  VOID: 0 placement traces -- no remote layer was created this session"
echo "########## done $(date '+%F %T')"
