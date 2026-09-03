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
# winlist too: without it the window lookup below reads as "no Steam window" — a misdiagnosis, not
# a result (verification-instruments.md I2, 2026-09-03)
[ -x /tmp/winlist ] || swiftc -O "$(dirname "$0")/winlist.swift" -o /tmp/winlist || exit 1

# guard 3a — locked screen makes every capture fail
if python3 -c "import subprocess,sys; sys.exit(0 if 'CGSSessionScreenIsLocked' in subprocess.run(['ioreg','-n','Root','-d1','-a'],capture_output=True,text=True).stdout else 1)"; then
  echo "  ABORT: screen is locked — screencapture is blind, any reading would be void"; exit 1
fi

H=$("$W" "$DRV" list 2>/dev/null | grep "class=SDL_app" | grep -i "title=Steam" | awk '{print $1}' | head -1)
[ -z "$H" ] && { echo "  ABORT: no SDL_app top-level Steam window"; exit 1; }
ID=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | sed -E 's/^id=([0-9]+).*/\1/')
if [ -z "$ID" ]; then
  # Distinguish "no Steam window" from "Steam's window is not on the visible space". winlist uses
  # CGWindowListCopyWindowInfo with .optionOnScreenOnly, so a fullscreen app on another Space hides
  # every window behind it — including this one — while the Win32 side still lists it perfectly.
  # Reported as "no Steam window (sign-in still up?)" on 2026-09-03 while a fullscreen game was
  # running, which sent the diagnosis in entirely the wrong direction.
  if [ -n "$H" ]; then
    echo "  ABORT: Win32 sees the Steam window ($H) but macOS does not list it on screen."
    echo "         Something fullscreen is covering it, or it is on another Space. Not a Steam"
    echo "         problem and not a render problem — the capture layer cannot see it."
  else
    echo "  ABORT: no 'Steam' window (sign-in still up?) — refusing to score 0 frames"
  fi
  exit 1
fi
before=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+')

if [ "$mode" = churn ]; then
  "$W" "$DRV" churn "$H" 2400x1500 2200x1360 240 >/dev/null 2>&1 &
  CHURN=$!
  # guard 2 — if nothing moved, this measures nothing. POLL for the change rather than sampling at
  # a fixed instant (2026-09-03): wine needs about a second to start, so two samples at t=1.00 s
  # and t=1.09 s can both land before the first resize and abort a run that was about to be valid.
  # Earlier still it was a single sample, which aborted half the time when the window happened to
  # start at one of the two churn sizes.
  mid=""; mid2=""
  for _ in $(seq 40); do
    sleep 0.15
    now=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+')
    [ -n "$now" ] && [ "$now" != "$before" ] && { mid="$now"; sleep 0.09
      mid2=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+'); break; }
  done
  if [ -z "$mid" ]; then
    # ⚠ kill the churn before leaving. It runs 240 alternations at 60 ms = ~14 s, and an abort that
    # left it running poisoned the NEXT probe in the same session: a "static control" measured
    # during an orphaned churn reported 39 distinct frames of 40 and a near-black frame, which
    # reads exactly like a real gap (2026-09-03, the C29 re-run for the core/glue split).
    kill "$CHURN" 2>/dev/null; wait "$CHURN" 2>/dev/null
    echo "  ABORT: window never changed size ($before) — churn did not take; churn killed"; exit 1
  fi
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

# Per-edge true black (issue #7). Added 2026-09-03 after the score above reported a clean run
# for captures in which the right tenth of the window was 93% pure black: the interior stayed lit
# and a mean over the whole perimeter diluted one black side to nothing. The human at the mouse
# saw what the number hid. Frames stay in "$out" — a score without frames cannot be re-read.
[ -x /tmp/darkboxes ] || swiftc -O "$(dirname "$0")/darkboxes.swift" -o /tmp/darkboxes || exit 1
/tmp/darkboxes 6 "$out"/f*.png | awk '{split($4,l,"=");split($5,r,"=");split($6,t,"=");split($7,b,"="); m=l[2]+0; if(r[2]+0>m)m=r[2]+0; if(t[2]+0>m)m=t[2]+0; if(b[2]+0>m)m=b[2]+0; if(m>=20)n++; if(m>mx)mx=m} END{printf "  EXPOSED-EDGE frames (an outer-10%% band >=20%% true black, lum<6): %d of %d, worst band %.0f%%\n", n+0, NR, mx+0; if(n>0) print "  -> the hosted child lagged the resize and the host background showed; a clean interior does NOT clear the run (issue #7)"}'
