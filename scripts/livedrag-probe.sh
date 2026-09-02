#!/bin/bash
# livedrag-probe.sh — measure hosted-layer gaps during a REAL mouse drag.
#
# scripts/shimmer-probe.sh drives SetWindowPos. A human dragging a window edge goes through macOS
# live-resize instead, which the harness cannot reach — so "live-drag flicker" could only ever be
# assessed by eye. This closes that: it waits for you to start dragging, samples hard while you do,
# and scores each frame the same way (near-black interior while the chrome still renders = a gap).
#
#   bash scripts/livedrag-probe.sh
#   -> it waits, you drag a window edge for ~15s, it reports.
#
# Same three guards as shimmer-probe, plus one more: it will not score unless the window size
# ACTUALLY CHANGED, so "I forgot to drag" comes back as VOID rather than as a clean bill of health.
set -u
SS=$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport
out="${OUT_DIR:-/tmp/livedrag}"; rm -rf "$out"; mkdir -p "$out"
FRAMES="${FRAMES:-60}"; WAIT="${WAIT:-90}"

[ -x /tmp/pixel-probe ] || swiftc -O "$(dirname "$0")/pixel-probe.swift" -o /tmp/pixel-probe || exit 1
# winlist too: without it the known-good capture below fails first and the abort reads "instrument
# blind" — a misdiagnosis, not a result (verification-instruments.md I2, 2026-09-03)
[ -x /tmp/winlist ] || swiftc -O "$(dirname "$0")/winlist.swift" -o /tmp/winlist || exit 1

if python3 -c "import subprocess,sys; sys.exit(0 if 'CGSSessionScreenIsLocked' in subprocess.run(['ioreg','-n','Root','-d1','-a'],capture_output=True,text=True).stdout else 1)"; then
  echo "  ABORT: screen locked — screencapture is blind"; exit 1; fi

GID=$(/tmp/winlist 2>/dev/null | grep -iE "owner=(Ghostty|Terminal|Claude|Finder)" | head -1 | sed -E 's/^id=([0-9]+).*/\1/')
rm -f /tmp/kg.png; [ -n "$GID" ] && screencapture -x -o -l "$GID" /tmp/kg.png 2>/dev/null
kg=0; [ -s /tmp/kg.png ] && kg=1
# That capture is of an arbitrary terminal or Claude window. Its only datum is "the instrument
# sees", now held in $kg — delete it before anything else can happen (privacy, EXPERIMENTS.md).
rm -f /tmp/kg.png
[ "$kg" = 1 ] || { echo "  ABORT: known-good capture failed — instrument blind, nothing here would be evidence"; exit 1; }

line=$(/tmp/winlist 2>/dev/null | grep "title=Steam$")
ID=$(echo "$line" | sed -E 's/^id=([0-9]+).*/\1/')
[ -z "$ID" ] && { echo "  ABORT: no Steam window"; exit 1; }
# Wait for the window to STOP moving before arming. Steam resizes itself while it starts up, and
# an unstabilised probe latches onto that and calls it a drag — observed 2026-08-31.
for i in $(seq 1 40); do
  a=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+'); sleep 1
  b=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+'); sleep 1
  c=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+')
  [ "$a" = "$b" ] && [ "$b" = "$c" ] && break
done
base=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+')
echo "  ready — Steam window settled at $base"
echo "  DRAG A WINDOW EDGE NOW (any edge, ~15 seconds of movement). Waiting up to ${WAIT}s…"

started=0
for i in $(seq 1 $((WAIT*2))); do
  now=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+')
  [ -n "$now" ] && [ "$now" != "$base" ] && { started=1; echo "  drag detected: $base -> $now — sampling $FRAMES frames"; break; }
  sleep 0.5
done
[ "$started" = 0 ] && { echo "  VOID: window never changed size — no drag happened, so this measures nothing"; exit 1; }

: > "$out/sizes.txt"
for i in $(seq 1 "$FRAMES"); do
  screencapture -x -o -l "$ID" "$out/f$i.png" 2>/dev/null
  /tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+' >> "$out/sizes.txt"
done

echo "  distinct window sizes seen while sampling: $(sort -u "$out/sizes.txt" | wc -l | tr -d ' ')  (1 = the drag had stopped; treat as weak)"
python3 - "$out" <<'PY'
import sys, glob, subprocess, re, os
d=sys.argv[1]; rows=[]
for f in sorted(glob.glob(d+"/f*.png"), key=lambda x:int(re.search(r'f(\d+)',x).group(1))):
    o=subprocess.run(["/tmp/pixel-probe",f,"1"],capture_output=True,text=True).stdout
    m=re.findall(r"lum (\d+)",o)
    if m: rows.append((os.path.basename(f), int(m[0]), int(m[1])))
if not rows: print("  VOID: no frames scored"); sys.exit(1)
mins=[min(a,b) for _,a,b in rows]
dark=[f for f,a,b in rows if min(a,b)<15]
print("  frames %d · interior-lum min %d / median %d / max %d" % (len(rows), min(mins), sorted(mins)[len(mins)//2], max(mins)))
print("  GAPS (near-black interior, <15): %d %s" % (len(dark), dark[:8]))
if dark: print("  -> open one and check: a GAP shows Steam's CHROME rendering with a black content area.")
PY
