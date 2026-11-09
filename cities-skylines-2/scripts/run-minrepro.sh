#!/bin/bash
# Run minrepro.exe under the dxmt11 wrapper's wine and capture screenshots at each phase.
# Fully automated — no human interaction needed (the trigger is programmatic).
# ⚠ The window appears at (100,100)-(900,700) on the main display: leave that region unobstructed,
#   or the phase-1 magenta check will be invalid (capture shows whatever covers it).
# Usage: bash scripts/run-minrepro.sh   [outdir]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
TS=$(date +%Y%m%d-%H%M%S)
OUT="${1:-/tmp/cs2-minrepro-$TS}"; mkdir -p "$OUT"
SS="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport"
WINE="$SS/wine/bin/wine64"
export WINEPREFIX="$SS/prefix"
export WINEDEBUG="${WINEDEBUG:--all}"
LOG="$OUT/minrepro.log"

[ -f "$HERE/minrepro.exe" ] || { echo "minrepro.exe missing — build: x86_64-w64-mingw32-gcc $HERE/minrepro.c -o $HERE/minrepro.exe -ld3d11 -ldxgi -ldxguid -luuid"; exit 1; }

echo "=== minrepro → $OUT ==="
"$WINE" "$HERE/minrepro.exe" > "$LOG" 2>&1 &
WPID=$!

# capture the window's client area (window at 100,100 size 800x600; skip ~40px of chrome)
snap() { screencapture -x -R120,160,760,500 "$OUT/$1.png" 2>/dev/null; echo "  snap $1 @ $(date +%H:%M:%S)"; }
waitfor() { # waitfor <marker> <timeout_s>
  for _i in $(seq 1 $(( $2 * 2 ))); do grep -q "$1" "$LOG" 2>/dev/null && return 0; sleep 0.5; done
  echo "  TIMEOUT waiting for $1"; return 1
}

waitfor "PHASE1" 30        && { sleep 2; snap P1-magenta; }
waitfor "PHASE2" 30        && { sleep 2; snap P2a-cycling; sleep 3; snap P2b-cycling; }
waitfor "PHASE3_PRESENTING" 30 && { sleep 1; snap P3a-postcycle; sleep 3; snap P3b-postcycle; }
wait $WPID 2>/dev/null

echo "=== log tail ==="; tail -12 "$LOG"
echo "=== verdict hints (authoritative check = look at the PNGs) ==="
for a in P2a-cycling P2b-cycling P3a-postcycle P3b-postcycle; do
  [ -f "$OUT/$a.png" ] && echo "  $a  md5=$(md5 -q "$OUT/$a.png")"
done
echo "  P2a==P2b md5 → screen static during cycling presents = BUG REPRODUCED (if P1 shows magenta)"
echo "  P2 shows green/blue → NOT reproduced in this window shape"
echo "done: $OUT"
