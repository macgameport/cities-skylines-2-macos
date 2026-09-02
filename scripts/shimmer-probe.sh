#!/bin/bash
# shimmer-probe.sh — measure hosted-layer GAPS during resize churn, against a static control.
#
# WHY THIS EXISTS: a post-settle capture cannot see the shimmer. Every earlier attempt to judge it
# screenshotted after the window stopped moving and found nothing, which is why it stayed open for
# a day. This samples CONTINUOUSLY while a churn runs and scores each frame, so a layer that blinks
# out for a frame is caught.
#
#   bash scripts/shimmer-probe.sh static   # control: no churn
#   bash scripts/shimmer-probe.sh churn    # 240 SetWindowPos alternations at 60ms
#
# A gap shows as a frame whose interior is near-black while Steam's CHROME still renders — menu bar,
# nav, URL bar, bottom bar. Open a flagged frame and look; a merely dark page is not a gap.
#
# THREE GUARDS, each earned by a run that produced a confident wrong answer:
#   1. Select the top-level by CLASS (SDL_app). Driving a non-top-level HWND resizes nothing, every
#      frame comes back identical, and it looks like "no gaps" — it is "no test".
#   2. ASSERT the window actually changed size before scoring. Same reason.
#   3. Refuse to score if the window id is empty or the screen is locked. `screencapture -l` fails
#      for EVERY window on a locked screen, including a known-good non-wine one, and a blind sensor
#      reads exactly like a black window. (Harness trap 2, steam-render-cell.sh.)
set -u
SS=$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport
export WINEPREFIX="$SS/prefix" WINEDEBUG=-all
export DYLD_FALLBACK_LIBRARY_PATH="$HOME/Applications/CS2dxmt11.app/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"
W="$SS/wine/bin/wine64"; DRV=$HOME/cs2-patch/win-resize-driver.exe
mode="${1:-churn}"; out="${OUT_DIR:-/tmp/shimmer-$mode}"; rm -rf "$out"; mkdir -p "$out"
N="${SAMPLES:-40}"

[ -x /tmp/pixel-probe ] || swiftc -O "$(dirname "$0")/pixel-probe.swift" -o /tmp/pixel-probe || exit 1

# guard 3a — locked screen makes every capture fail
if python3 -c "import subprocess,sys; sys.exit(0 if 'CGSSessionScreenIsLocked' in subprocess.run(['ioreg','-n','Root','-d1','-a'],capture_output=True,text=True).stdout else 1)"; then
  echo "  ABORT: screen is locked — screencapture is blind, any reading would be void"; exit 1
fi

H=$("$W" "$DRV" list 2>/dev/null | grep "class=SDL_app" | grep -i "title=Steam" | awk '{print $1}' | head -1)
[ -z "$H" ] && { echo "  ABORT: no SDL_app top-level Steam window"; exit 1; }
ID=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | sed -E 's/^id=([0-9]+).*/\1/')
[ -z "$ID" ] && { echo "  ABORT: no 'Steam' window (sign-in still up?) — refusing to score 0 frames"; exit 1; }
before=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+')

if [ "$mode" = churn ]; then
  "$W" "$DRV" churn "$H" 2400x1500 2200x1360 240 >/dev/null 2>&1 &
  sleep 1
  mid=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+')
  sleep 0.09
  mid2=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+')
  # guard 2 — if nothing moved, this measures nothing. TWO samples 90 ms apart (2026-09-02): the
  # churn alternates every 60 ms, so a single sample taken while the window happens to sit at its
  # starting size read as "did not take" and aborted a valid run half the time when the window
  # started at one of the two churn sizes.
  [ "$mid" = "$before" ] && [ "$mid2" = "$before" ] && { echo "  ABORT: window never changed size ($before) — churn did not take"; exit 1; }
  echo "  churn live: $before -> $mid -> $mid2"
fi

for i in $(seq 1 "$N"); do screencapture -x -o -l "$ID" "$out/f$i.png" 2>/dev/null; done
wait 2>/dev/null
python3 - "$out" <<'PY'
import sys, glob, subprocess, re, os
d=sys.argv[1]; rows=[]
for f in sorted(glob.glob(d+"/f*.png"), key=lambda x:int(re.search(r'f(\d+)',x).group(1))):
    o=subprocess.run(["/tmp/pixel-probe",f,"1"],capture_output=True,text=True).stdout
    m=re.findall(r"lum (\d+)",o)
    if m: rows.append((os.path.basename(f), int(m[0]), int(m[1])))
if not rows: print("  no frames scored — VOID, not a result"); sys.exit(1)
mins=[min(a,b) for _,a,b in rows]
dark=[f for f,a,b in rows if min(a,b)<15]
print("  frames %d · distinct %d · interior-lum min %d / median %d / max %d"
      % (len(rows), len({open(d+"/"+f,'rb').read() for f,_,_ in rows}),
         min(mins), sorted(mins)[len(mins)//2], max(mins)))
print("  GAPS (near-black interior, <15): %d %s" % (len(dark), dark[:8]))
PY
