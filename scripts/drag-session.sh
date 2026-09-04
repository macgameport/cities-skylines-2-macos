#!/bin/bash
# drag-session.sh — one live-drag measurement, set up end to end.
#
#   bash scripts/drag-session.sh t0      # diag-pre : stage 1 + colours   (issue #7 T0's live half)
#   bash scripts/drag-session.sh t2b     # diag-fix : stage 2 + colours   (T2b)
#   bash scripts/drag-session.sh t3      # prod     : stage 2, no colours (T3 — James's verdict)
#
# A live drag is the ONLY measurement that reaches stage 2: shimmer-probe drives SetWindowPos, which
# is not a live resize, so `in_live_resize` is never set and the stretch never fires. That is why
# these three runs cannot be automated away.
#
# It shuts Steam down, installs the right module, brings Steam up through the cell harness (so the
# run is fingerprinted and a run with no font library is refused), navigates to the store, then
# waits for you. Drag, and it scores. The daily driver is restored on the way out, always.
#
# THE DRAG, the same every time so runs compare:
#   1. grab the RIGHT edge, pull out ~300 px over about 5 seconds, hold a moment
#   2. grab the TOP edge, pull up ~150 px
#   3. let go
# Slow and steady beats fast: the defect is a lag, and a quick flick can outrun the sampler.
# (macgameport, 2026-09-03)
set -u
ROLE="${1:?usage: drag-session.sh t0|t2b|t3}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SS="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}/Contents/SharedSupport"
W="$SS/wine/bin/wine64"; S="$SS/prefix/drive_c/Program Files (x86)/Steam"
INST="$SS/wine/lib/wine/x86_64-unix/winemac.so"
DAILY="$HOME/cs2-patch/winemac.so.stage1"

case "$ROLE" in
  t0)  MOD="$HOME/cs2-patch/winemac.so.s1-diag"; WHAT="diag-pre — stage 1 + colours" ;;
  t2b) MOD="$HOME/cs2-patch/winemac.so.s2-diag"; WHAT="diag-fix — stage 2 + colours" ;;
  t3)  MOD="$HOME/cs2-patch/winemac.so.s2";      WHAT="prod — stage 2, no colours" ;;
  *)   echo "unknown role '$ROLE' (t0|t2b|t3)"; exit 2 ;;
esac
[ -f "$MOD" ] || { echo "missing module $MOD — build it first"; exit 2; }

OUT="${DRAG_OUT:-$HOME/cs2-patch/drag/$ROLE-$(date +%Y%m%d-%H%M%S)}"
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
restore() {                      # ALWAYS leave the machine on the daily driver
  [ -n "$CAF" ] && kill "$CAF" 2>/dev/null
  down
  cp "$DAILY" "$INST" 2>/dev/null &&
    echo "  daily driver restored: $(shasum -a 256 "$INST" | cut -c1-16)"
}
trap restore EXIT
caffeinate -d -i -u -t 5400 & CAF=$!

echo "########## drag session $ROLE — $WHAT"
echo "  run dir: $OUT"
down
cp "$MOD" "$INST" || exit 1
echo "  module:  $(shasum -a 256 "$INST" | cut -c1-16)"

WINEDEBUG=+err,+macdrv bash "$REPO/scripts/steam-render-cell.sh" \
    --label "drag-$ROLE-$(basename "$OUT")" --keep-running >"$OUT/cell.txt" 2>&1
steam_up || { echo "  VOID: $(grep -m1 FATAL "$OUT/cell.txt" | cut -c1-120)"; exit 1; }
WINEDEBUG=-all "$W" "$S/steam.exe" steam://store >/dev/null 2>&1; sleep 15

# Shrink the window first, so the drag has somewhere to GROW. The defect is on the growing edge, and
# the first run (2026-09-04, t0) opened at 1853x994 with little headroom: the drag oscillated
# between 1561 and 1852 and ended near where it started, producing 1 exposed frame in 60 against a
# 19/60 baseline. A drag that cannot grow measures the wrong half of the problem.
DH=$(WINEDEBUG=-all "$W" "$DRV" list 2>/dev/null | tr -d '\r' \
     | grep 'class=SDL_app' | grep 'title=Steam$' | awk '{print $1}' | head -1)
if [ -n "${DH:-}" ]; then
  WINEDEBUG=-all "$W" "$DRV" drive "$DH" "${PRESIZE:-1400x900}" >/dev/null 2>&1
  sleep 3
  echo "  pre-sized to ${PRESIZE:-1400x900} — room to pull outward"
fi

cat <<'MSG'

  ---------------------------------------------------------------
   Steam is up on the store page. When the probe says it is armed:

     1. grab the RIGHT edge, pull out ~300 px over about 5 seconds
     2. hold a moment
     3. grab the TOP edge, pull up ~150 px
     4. let go

   Slow and steady. It waits up to 30 minutes, so there is no rush.
  ---------------------------------------------------------------

MSG
OUT_DIR="$OUT/frames" WAIT=1800 FRAMES=60 bash "$REPO/scripts/livedrag-probe.sh" 2>&1 | tee "$OUT/probe.txt"

echo
echo "########## scoring"
[ -x /tmp/darkboxes ] || swiftc -O "$REPO/scripts/darkboxes.swift" -o /tmp/darkboxes
n=$(ls "$OUT/frames"/f*.png 2>/dev/null | wc -l | tr -d ' ')
if [ "$n" = 0 ]; then echo "  VOID: no frames captured"; else
  /tmp/darkboxes 6 "$OUT/frames"/f*.png > "$OUT/bands.txt" 2>/dev/null
  python3 "$REPO/scripts/band-counts.py" "$OUT/bands.txt" | sed 's/^/  /'
  [ "$ROLE" != t3 ] && python3 "$REPO/scripts/darkboxes-attrib.py" 6 "$OUT/frames"/f*.png \
      > "$OUT/attrib.txt" 2>&1 && tail -1 "$OUT/attrib.txt" | sed 's/^/  /'
  cp /tmp/steam-cell-drag-$ROLE-$(basename "$OUT")/stdout.txt "$OUT/stdout.txt" 2>/dev/null
  echo "  stage-2 stretches fired: $(grep -c 'live resize' "$OUT/stdout.txt" 2>/dev/null || echo 0)"
  python3 "$REPO/scripts/t6-scale-at-rest.py" "$OUT/stdout.txt" 2>&1 | tail -2 | sed 's/^/  /'
fi
echo "########## done — $OUT"
