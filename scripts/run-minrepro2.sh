#!/bin/bash
# Run minrepro2.exe (fullscreen variant) with full-display captures per phase.
# ⚠ TAKES OVER THE MAIN DISPLAY for ~30s (magenta fullscreen, then color phases).
# Usage: bash scripts/run-minrepro2.sh   [outdir]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
TS=$(date +%Y%m%d-%H%M%S)
OUT="${1:-/tmp/cs2-minrepro2-$TS}"; mkdir -p "$OUT"
SS="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport"
WINE="$SS/wine/bin/wine64"
export WINEPREFIX="$SS/prefix"
export WINEDEBUG="${WINEDEBUG:--all}"
LOG="$OUT/minrepro2.log"

[ -f "$HERE/minrepro2.exe" ] || { echo "minrepro2.exe missing — build: x86_64-w64-mingw32-gcc $HERE/minrepro2.c -o $HERE/minrepro2.exe -ld3d11 -ldxgi -ldxguid -luuid"; exit 1; }

echo "=== minrepro2 → $OUT ==="
"$WINE" "$HERE/minrepro2.exe" > "$LOG" 2>&1 &
WPID=$!

snap() { screencapture -x -m "$OUT/$1.png" 2>/dev/null; echo "  snap $1 @ $(date +%H:%M:%S)"; }
waitfor() {
  for _i in $(seq 1 $(( $2 * 2 ))); do grep -q "$1" "$LOG" 2>/dev/null && return 0; sleep 0.5; done
  echo "  TIMEOUT waiting for $1"; return 1
}

waitfor "PHASE1" 40            && { sleep 2; snap P1-magenta-fs; }
waitfor "PHASE2 " 40           && { sleep 2; snap P2a-cycling; sleep 3; snap P2b-cycling; }
waitfor "PHASE2B" 20           && { sleep 2; snap P2c-redpulse-sc1; }
waitfor "PHASE3_PRESENTING" 30 && { sleep 1; snap P3a-postcycle; sleep 3; snap P3b-postcycle; }
wait $WPID 2>/dev/null

echo "=== log ==="; cat "$LOG"
echo "=== md5s ==="
for f in "$OUT"/*.png; do echo "  $(basename "$f")  $(md5 -q "$f")"; done
echo "done: $OUT  (verdict = look at the PNGs)"
