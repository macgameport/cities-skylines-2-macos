#!/bin/bash
# Run the STRIPPED reproducer (minrepro3: windowed, no minimize, no fullscreen, no focus change)
# and print numeric pixel verdicts. Leave the (100,100)-(900,700) region unobstructed.
# Usage: bash scripts/run-minrepro3.sh [outdir]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
TS=$(date +%Y%m%d-%H%M%S); OUT="${1:-/tmp/cs2-minrepro3-$TS}"; mkdir -p "$OUT"
SS="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport"
export WINEPREFIX="$SS/prefix" WINEDEBUG="${WINEDEBUG:--all}"
LOG="$OUT/log.txt"
[ -f "$HERE/minrepro3.exe" ] || { echo "build first: x86_64-w64-mingw32-gcc $HERE/minrepro3.c -o $HERE/minrepro3.exe -ld3d11 -ldxgi -ldxguid -luuid"; exit 1; }
"$SS/wine/bin/wine64" "$HERE/minrepro3.exe" > "$LOG" 2>&1 &
WPID=$!
snap(){ screencapture -x -R120,160,760,500 "$OUT/$1.png" 2>/dev/null; }
waitfor(){ for _i in $(seq 1 $(( $2*2 ))); do grep -q "$1" "$LOG" 2>/dev/null && return 0; sleep 0.5; done; echo "TIMEOUT $1"; }
waitfor PHASE1 30    && { sleep 1.5; snap P1-magenta; }
waitfor "PHASE2 " 20 && { sleep 1.5; snap P2-cycling; }
waitfor PHASE2B 20   && { sleep 2; snap P2B-red-on-sc1; sleep 3; snap P2B2-red-on-sc1; }
waitfor PHASE2C 20   && { sleep 1.5; snap P2C-cycling-again; }
wait $WPID 2>/dev/null
grep -E "PHASE|Create|fps" "$LOG" | tail -18
python3 - "$OUT" << 'PYEOF'
import sys, glob, zlib, subprocess, os
from struct import unpack
for p in sorted(glob.glob(sys.argv[1] + '/P*.png')):
    subprocess.run(['sips','-c','8','8','--out','/tmp/px-mr3.png',p],capture_output=True)
    d=open('/tmp/px-mr3.png','rb').read(); pos,idat=8,b''
    while pos<len(d):
        ln=unpack('>I',d[pos:pos+4])[0]; t=d[pos+4:pos+8]
        if t==b'IDAT': idat+=d[pos+8:pos+8+ln]
        pos+=12+ln
    print(' ', os.path.basename(p), 'RGB =', tuple(zlib.decompress(idat)[1:4]))
PYEOF
echo "VERDICT: P2B == P2B2 and neither red while sc1 presented red at 120fps = BUG REPRODUCED"
echo "done: $OUT"
