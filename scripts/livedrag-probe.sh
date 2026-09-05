#!/bin/bash
# livedrag-probe.sh — measure hosted-layer gaps during a REAL mouse drag.
#
# scripts/shimmer-probe.sh drives SetWindowPos. A human dragging a window edge goes through a
# different path -- on this stack win32u's own SC_SIZE loop, not macOS live-resize (ledger C46/C47)
# -- which the churn harness cannot reach, so "live-drag flicker" could only ever be assessed by
# eye. This closes that: it waits for the window to start changing size, samples hard while it
# does, and scores each frame the same way (near-black interior while the chrome still renders =
# a gap). It does not care who is dragging: a hand, or `win-resize-driver.exe sizedrag`
# (drag-session.sh DRAG=synth).
#
#   bash scripts/livedrag-probe.sh
#   -> it waits, you drag a window edge for ~15s, it reports.
#   CAPTURE=screen bash scripts/livedrag-probe.sh   # the control: same rect off the COMPOSITED display
#
# CAPTURE picks where the pixels come from, and that is the whole point of the control (issue #12).
#   window (default)  `screencapture -l <id>` -- the window server's stored representation of that
#                     window. Sees it even when occluded; this is what every run before 2026-09-05
#                     used, so it is the only mode comparable with C35/C38/C50/C51.
#   screen            `screencapture -R x,y,w,h` over the window's current rect -- the composited
#                     display, i.e. what a camera pointed at the screen would see.
# A frame that is black in `window` and lit in `screen` is a capture artifact and no user ever saw
# it; black in both is a real display gap. Measured 2026-09-05 on a 1054x972 window: both modes
# return IDENTICAL pixel dimensions (so darkboxes' outer-10% bands mean the same thing in each),
# -R costs 88 ms against -l's 113 ms.
# ⚠ Two things only `screen` can get wrong, so it checks both before and after sampling and records
# the answers: a LOCKED session (a region capture would return the lock screen, where -l keeps
# working as long as the display is awake), and an OVERLAPPING window in front of Steam (-l sees
# through it, -R cannot). Either one makes the run's frames VOID rather than evidence.
#
# Same three guards as shimmer-probe, plus one more: it will not score unless the window size
# ACTUALLY CHANGED, so "I forgot to drag" comes back as VOID rather than as a clean bill of health.
set -u
SS=$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport
out="${OUT_DIR:-/tmp/livedrag}"; rm -rf "$out"; mkdir -p "$out"
# WAIT is the drag window. 90 s suits a human at the keyboard; an agent running this FOR a human
# who reads messages intermittently should set WAIT=1800 — the 2026-09-03 run voided at 240 s and
# passed at 1800 s, with the drag itself taking fifteen seconds.
FRAMES="${FRAMES:-60}"; WAIT="${WAIT:-90}"; CAPTURE="${CAPTURE:-window}"
case "$CAPTURE" in window|screen) ;; *) echo "  ABORT: CAPTURE must be window or screen"; exit 1 ;; esac

[ -x /tmp/pixel-probe ] || swiftc -O "$(dirname "$0")/pixel-probe.swift" -o /tmp/pixel-probe || exit 1
# winlist too: without it the known-good capture below fails first and the abort reads "instrument
# blind" — a misdiagnosis, not a result (verification-instruments.md I2, 2026-09-03)
[ -x /tmp/winlist ] || swiftc -O "$(dirname "$0")/winlist.swift" -o /tmp/winlist || exit 1

# A locked SESSION is not a blind instrument: `screencapture -l` reads a window's backing store, and
# that works under the lock screen as long as the DISPLAY is awake (measured 2026-09-05: 1.3 MB,
# real luminance, session locked). It is display sleep that blinds it, and the 2026-08-24 entry
# conflated the two. So: wake the display, say so, and let the known-good capture below decide.
locked() { python3 -c "import subprocess,sys; sys.exit(0 if 'CGSSessionScreenIsLocked' in subprocess.run(['ioreg','-n','Root','-d1','-a'],capture_output=True,text=True).stdout else 1)"; }
# Layer-0 windows IN FRONT of Steam that intersect its rect. `-l` sees through them, `-R` cannot,
# so in CAPTURE=screen a nonzero count means the frames may be of something else. Counts only --
# never prints a title or an owner (privacy, EXPERIMENTS.md).
overlaps() {
  /tmp/winlist 2>/dev/null | python3 -c '
import sys, re
rows = []
for ln in sys.stdin:
    m = re.match(r"id=(\d+) pid=(\d+) layer=(-?\d+) owner=(.*?) size=(\d+)x(\d+) at=(-?\d+),(-?\d+) title=(.*)$", ln.rstrip("\n"))
    if m: rows.append(m.groups())
me = [i for i, r in enumerate(rows) if r[8] == "Steam"]
if not me:
    print(-1); raise SystemExit
i = me[0]
w, h, x, y = (int(v) for v in rows[i][4:8])
n = 0
for r in rows[:i]:
    if int(r[2]) != 0: continue
    W, H, X, Y = (int(v) for v in r[4:8])
    if X < x + w and X + W > x and Y < y + h and Y + H > y: n += 1
print(n)
'
}
if locked; then
  echo "  note: session is locked — waking the display; the known-good capture decides whether the instrument sees"
  caffeinate -u -t 3; sleep 1
fi

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
echo "$CAPTURE" > "$out/capture-mode.txt"   # a bare run dir must say which instrument made it
lock0=no; locked && lock0=yes; ov0=$(overlaps)
for i in $(seq 1 "$FRAMES"); do
  if [ "$CAPTURE" = screen ]; then
    # One winlist serves both the region and sizes.txt, so screen mode is not the slower sampler
    # (126 ms/frame against window's 151). ⚠ Its size is therefore read just BEFORE its capture,
    # where window mode reads just after: a growing-frame join can differ by one step between the
    # modes. Irrelevant to "does a black frame occur at all", which is what this mode is for.
    g=$(/tmp/winlist 2>/dev/null | grep "title=Steam$" | head -1)
    echo "$g" | grep -oE 'size=[0-9]+x[0-9]+' >> "$out/sizes.txt"
    r=$(echo "$g" | sed -nE 's/.*size=([0-9]+)x([0-9]+) at=(-?[0-9]+),(-?[0-9]+).*/\3,\4,\1,\2/p')
    [ -n "$r" ] && screencapture -x -o -R"$r" "$out/f$i.png" 2>/dev/null
  else
    screencapture -x -o -l "$ID" "$out/f$i.png" 2>/dev/null
    /tmp/winlist 2>/dev/null | grep "title=Steam$" | grep -oE 'size=[0-9]+x[0-9]+' >> "$out/sizes.txt"
  fi
done
lock1=no; locked && lock1=yes; ov1=$(overlaps)
echo "  capture mode: $CAPTURE · session locked before/after: $lock0/$lock1 · windows over Steam before/after: $ov0/$ov1"
printf 'mode=%s locked=%s/%s overlaps=%s/%s\n' "$CAPTURE" "$lock0" "$lock1" "$ov0" "$ov1" > "$out/capture-state.txt"
if [ "$CAPTURE" = screen ] && { [ "$lock0" = yes ] || [ "$lock1" = yes ] || [ "${ov0:-0}" != 0 ] || [ "${ov1:-0}" != 0 ]; }; then
  echo "  VOID (screen mode): a locked session or a window over Steam means these frames are not of Steam"
  echo "  -> the numbers below describe the capture, not the app; do not read them as a result"
fi

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

# Per-edge true black (issue #7). Added 2026-09-03 after the score above reported a clean run
# for captures in which the right tenth of the window was 93% pure black: the interior stayed lit
# and a mean over the whole perimeter diluted one black side to nothing. The human at the mouse
# saw what the number hid. Frames stay in "$out" — a score without frames cannot be re-read.
# Over-flags on purpose: the bottom band can be crossed by the page's own black artwork (the
# store's tiles), so treat a RIGHT/TOP hit as exposure and a bottom-only hit as "go and look".
[ -x /tmp/darkboxes ] || swiftc -O "$(dirname "$0")/darkboxes.swift" -o /tmp/darkboxes || exit 1
/tmp/darkboxes 6 "$out"/f*.png | awk '{for(i=1;i<=NF;i++){ if($i ~ /^L=/) split($i,l,"="); if($i ~ /^R=/) split($i,r,"="); if($i ~ /^T=/) split($i,t,"="); if($i ~ /^B=/) split($i,b,"=") } m=l[2]+0; if(r[2]+0>m)m=r[2]+0; if(t[2]+0>m)m=t[2]+0; if(b[2]+0>m)m=b[2]+0; if(m>=20)n++; if(m>mx)mx=m} END{printf "  EXPOSED-EDGE frames (an outer-10%% band >=20%% true black, lum<6): %d of %d, worst band %.0f%%\n", n+0, NR, mx+0; if(n>0) print "  -> the hosted child lagged the resize and the host background showed; a clean interior does NOT clear the run (issue #7)"}'
