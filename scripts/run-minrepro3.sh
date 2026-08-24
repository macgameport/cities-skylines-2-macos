#!/bin/bash
# Run the STRIPPED reproducer (minrepro3: windowed, no minimize, no fullscreen, no focus change)
# and print numeric pixel verdicts. Leave the (100,100)-(900,700) region unobstructed.
# Usage: bash scripts/run-minrepro3.sh [outdir]
# Env seams (for testing a candidate engine without editing this file):
#   CS2_WINE=/path/to/bin/wine64      wine binary to use (default: the daily wrapper's)
#   CS2_PREFIX=/path/to/prefix       WINEPREFIX (default: the daily wrapper's)
# Hardened 2026-08-23 (check-it pass 1): waitfor now FAILS on timeout and the run aborts —
# previously a dead process still produced snapshots and pixel "results" from stale screen
# content. The verdict is now computed from the sampled pixels, not a hardcoded echo.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
TS=$(date +%Y%m%d-%H%M%S); OUT="${1:-/tmp/cs2-minrepro3-$TS}"; mkdir -p "$OUT"
SS="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport"
WINEBIN="${CS2_WINE:-$SS/wine/bin/wine64}"
export WINEPREFIX="${CS2_PREFIX:-$SS/prefix}" WINEDEBUG="${WINEDEBUG:--all}"
LOG="$OUT/log.txt"
[ -f "$HERE/minrepro3.exe" ] || { echo "build first: x86_64-w64-mingw32-gcc $HERE/minrepro3.c -o $HERE/minrepro3.exe -ld3d11 -ldxgi -ldxguid -luuid"; exit 1; }
[ -x "$WINEBIN" ] || { echo "no wine binary at $WINEBIN"; exit 1; }
echo "engine: $WINEBIN"; echo "prefix: $WINEPREFIX"
"$WINEBIN" "$HERE/minrepro3.exe" > "$LOG" 2>&1 &
WPID=$!
abort(){ echo "ABORTED: $1 — pixel data would be meaningless, no verdict"; kill $WPID 2>/dev/null; exit 1; }
# snap aborts on a failed/empty capture: screencapture fails when the display is locked or
# asleep, and pixels sampled from a dead capture are exactly the false-verdict trap this
# script was hardened against. G1 protocol: display awake + unlocked, sample region unobstructed.
snap(){ screencapture -x -R120,160,760,500 "$OUT/$1.png" 2>/dev/null; [ -s "$OUT/$1.png" ] || abort "screencapture produced nothing for $1 (display locked/asleep? region obstructed?)"; }
waitfor(){ for _i in $(seq 1 $(( $2*2 ))); do grep -q "$1" "$LOG" 2>/dev/null && return 0; sleep 0.5; done; echo "TIMEOUT waiting for $1"; return 1; }
waitfor PHASE1 30 || abort "PHASE1 never reached (launch failed?)"
sleep 1.5; snap P1-magenta
waitfor "PHASE2 " 20 || abort "PHASE2 never reached"
sleep 1.5; snap P2-cycling
waitfor PHASE2B 20 || abort "PHASE2B never reached"
sleep 2; snap P2B-red-on-sc1; sleep 3; snap P2B2-red-on-sc1
waitfor PHASE2C 20 || abort "PHASE2C never reached"
sleep 1.5; snap P2C-cycling-again
wait $WPID 2>/dev/null
grep -E "PHASE|Create|fps" "$LOG" | tail -18
python3 - "$OUT" << 'PYEOF'
import sys, glob, zlib, subprocess, os
from struct import unpack
px = {}
for p in sorted(glob.glob(sys.argv[1] + '/P*.png')):
    subprocess.run(['sips','-c','8','8','--out','/tmp/px-mr3.png',p],capture_output=True)
    d=open('/tmp/px-mr3.png','rb').read(); pos,idat=8,b''
    while pos<len(d):
        ln=unpack('>I',d[pos:pos+4])[0]; t=d[pos+4:pos+8]
        if t==b'IDAT': idat+=d[pos+8:pos+8+ln]
        pos+=12+ln
    rgb = tuple(zlib.decompress(idat)[1:4])
    px[os.path.basename(p).split('-')[0]] = rgb
    print(' ', os.path.basename(p), 'RGB =', rgb)
a, b = px.get('P2B'), px.get('P2B2')
if a is None or b is None:
    print('VERDICT: INCOMPLETE — P2B/P2B2 snapshots missing'); sys.exit(1)
reddish = lambda t: t[0] > max(t[1], t[2]) + 30
if a == b:
    print('VERDICT: STALE — P2B == P2B2, presents to sc1 never composite (bug PRESENT)')
elif reddish(a) or reddish(b):
    print('VERDICT: LIVE — sc1 red pulse reaches the screen (fix PRESENT)')
else:
    print('VERDICT: INCONCLUSIVE — samples differ but neither is red; inspect PNGs')
PYEOF
echo "done: $OUT"
