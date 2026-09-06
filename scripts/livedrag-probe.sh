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
#   video             `screencapture -v` over a rect covering the window's whole travel, scored by
#                     scripts/video-blue.swift. A DURATION instrument, not a rate one: it answers
#                     "how long was the diagnostic colour on screen", which neither other mode can
#                     -- they sample every ~113 ms, so a single hit bounds an event only to "under
#                     ~226 ms" (issue #12 / C56 caught blue on 2 frames of 3,900 that way). It
#                     writes rec.mov + video-frames.txt and NO f*.png, so it produces no bands.txt
#                     and is not comparable with the C35/C38/C50/C51 rows. ⚠ The recording is
#                     change-driven, not fixed-rate: a static region yielded 2 frames in 3 s
#                     (measured 2026-09-06), so the run must report its own achieved cadence
#                     before any duration read off it means anything.
# A frame that is black in `window` and lit in `screen` is a capture artifact and no user ever saw
# it; black in both is a real display gap. ⚠ That inference is sound ONLY for a whole-host
# signature (issue #12's 100 % black top band). It is INVALID for an EDGE signature (issue #7's
# strip): the region is frozen at the rect read before the capture, the window grows 25-75 px under
# it during the ~88 ms, and those are the same growing frames the strip appears on -- so screen mode
# crops the strip out of its own right band. `rects.txt` records the before/after size per frame so
# the affected frames are identifiable rather than silent. The anchor that settles it: the strip was
# seen BY EYE (issue #7, 2026-09-03), so it is on the display, whatever a region capture reports. Measured 2026-09-05 on a 1054x972 window: both modes
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
FRAMES="${FRAMES:-60}"; WAIT="${WAIT:-90}"; CAPTURE="${CAPTURE:-window}"; VIDSEC="${VIDSEC:-45}"
case "$CAPTURE" in window|screen|video) ;; *) echo "  ABORT: CAPTURE must be window, screen or video"; exit 1 ;; esac

[ -x /tmp/pixel-probe ] || swiftc -O "$(dirname "$0")/pixel-probe.swift" -o /tmp/pixel-probe || exit 1
# winlist too: without it the known-good capture below fails first and the abort reads "instrument
# blind" — a misdiagnosis, not a result (verification-instruments.md I2, 2026-09-03)
[ -x /tmp/winlist ] || swiftc -O "$(dirname "$0")/winlist.swift" -o /tmp/winlist || exit 1

# A locked SESSION is not a blind instrument: `screencapture -l` reads a window's backing store, and
# that works under the lock screen as long as the DISPLAY is awake (measured 2026-09-05: 1.3 MB,
# real luminance, session locked). It is display sleep that blinds it, and the 2026-08-24 entry
# conflated the two. So: wake the display, say so, and let the known-good capture below decide.
# The WINE Steam window, and only that one. ⚠ The native macOS Steam client titles its main window
# "Steam" as well, so a title-only selector matches both -- and line 94's `ID=` extraction takes
# EVERY match, so two windows yield a two-line id and the capture goes wrong or goes to the wrong
# app (a privacy problem too: the native client shows the persona name). The wine window is
# `owner=wine`, recorded in every windows.txt in the evidence store. Same reasoning as CLAUDE.md's
# rule for PROCESSES -- attribute by what actually distinguishes them, never by a label both share.
steamwin() { grep 'owner=wine .*title=Steam$'; }
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
# Layer-0 windows intersecting an ARBITRARY rect. The overlaps() above asks about Steam's own
# rect, which is the right question for `-l` and for `screen` mode. Video mode records a rect
# COVERING THE WHOLE DRAG -- larger than Steam at any instant, and larger than Steam's final size --
# so it can sweep in a window that never overlaps Steam at all. Counts only, never a title or an
# owner: naming what it found would defeat the point of refusing to record it (EXPERIMENTS.md).
overlaps_rect() {
  /tmp/winlist 2>/dev/null | python3 -c '
import sys, re
x, y, w, h = (int(v) for v in sys.argv[1:5])
n = 0
for ln in sys.stdin:
    m = re.match(r"id=(\d+) pid=(\d+) layer=(-?\d+) owner=(.*?) size=(\d+)x(\d+) at=(-?\d+),(-?\d+) title=(.*)$", ln.rstrip("\n"))
    if not m: continue
    g = m.groups()
    if int(g[2]) != 0 or g[8] == "Steam": continue
    W, H, X, Y = (int(v) for v in g[4:8])
    if X < x + w and X + W > x and Y < y + h and Y + H > y: n += 1
print(n)
' "$1" "$2" "$3" "$4"
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

line=$(/tmp/winlist 2>/dev/null | steamwin)
ID=$(echo "$line" | sed -E 's/^id=([0-9]+).*/\1/')
[ -z "$ID" ] && { echo "  ABORT: no Steam window"; exit 1; }
# Wait for the window to STOP moving before arming. Steam resizes itself while it starts up, and
# an unstabilised probe latches onto that and calls it a drag — observed 2026-08-31.
for i in $(seq 1 40); do
  a=$(/tmp/winlist 2>/dev/null | steamwin | grep -oE 'size=[0-9]+x[0-9]+'); sleep 1
  b=$(/tmp/winlist 2>/dev/null | steamwin | grep -oE 'size=[0-9]+x[0-9]+'); sleep 1
  c=$(/tmp/winlist 2>/dev/null | steamwin | grep -oE 'size=[0-9]+x[0-9]+')
  [ "$a" = "$b" ] && [ "$b" = "$c" ] && break
done
base=$(/tmp/winlist 2>/dev/null | steamwin | grep -oE 'size=[0-9]+x[0-9]+')
echo "  ready — Steam window settled at $base"
echo "  DRAG A WINDOW EDGE NOW (any edge, ~15 seconds of movement). Waiting up to ${WAIT}s…"

started=0
for i in $(seq 1 $((WAIT*2))); do
  now=$(/tmp/winlist 2>/dev/null | steamwin | grep -oE 'size=[0-9]+x[0-9]+')
  [ -n "$now" ] && [ "$now" != "$base" ] && { started=1; echo "  drag detected: $base -> $now — sampling $FRAMES frames"; break; }
  sleep 0.5
done
[ "$started" = 0 ] && { echo "  VOID: window never changed size — no drag happened, so this measures nothing"; exit 1; }

: > "$out/sizes.txt"
echo "$CAPTURE" > "$out/capture-mode.txt"   # a bare run dir must say which instrument made it
lock0=no; locked && lock0=yes; ov0=$(overlaps)
if [ "$CAPTURE" = video ]; then
  # A rect covering the window's WHOLE travel, so the growing edge is never cropped (C53). The
  # window only grows right and up under drag-session's synthetic drag, so the superset is the
  # current rect widened by SYNTH_DX and raised by SYNTH_DY, plus a margin -- then clamped to the
  # display, because screencapture -R silently returns nothing for a rect that leaves the screen.
  # ⚠ Refuse a locked session HERE, not after the fact. `screencapture -v` composites the DISPLAY,
  # so with the session locked it records the LOCK SCREEN -- and on 2026-09-06 that came back as
  # 1073 frames at a clean 60 fps with no diagnostic colour anywhere, which reads exactly like a
  # good run of a build that had no defect. `-l` keeps working locked, which is why only the
  # region-based modes carry this hazard. Costs 45 s and a 38 MB recording of the lock screen to
  # learn nothing, so it is worth catching before the recording rather than after.
  if [ "$lock0" = yes ]; then
    echo "  VOID (video mode): the session is LOCKED — screencapture -v would record the lock screen,"
    echo "  -> and a lock-screen recording scores as a clean run. Unlock the session and re-run."
    printf 'mode=video locked=yes refused=locked\n' > "$out/capture-state.txt"
    exit 1
  fi
  g=$(/tmp/winlist 2>/dev/null | steamwin | head -1)
  read -r vw vh vx vy <<<"$(echo "$g" | sed -nE 's/.*size=([0-9]+)x([0-9]+) at=(-?[0-9]+),(-?[0-9]+).*/\1 \2 \3 \4/p')"
  read -r dw dh <<<"$(system_profiler SPDisplaysDataType 2>/dev/null | sed -nE 's/.*Resolution: ([0-9]+) x ([0-9]+).*/\1 \2/p' | head -1)"
  : "${dw:=5120}" "${dh:=2880}"
  m=40
  rx=$((vx - m)); ry=$((vy - ${SYNTH_DY:-350} - m))
  rw=$((vw + ${SYNTH_DX:-650} + 2*m)); rh=$((vh + ${SYNTH_DY:-350} + 2*m))
  [ "$rx" -lt 0 ] && { rw=$((rw + rx)); rx=0; }
  [ "$ry" -lt 0 ] && { rh=$((rh + ry)); ry=0; }
  [ $((rx + rw)) -gt "$dw" ] && rw=$((dw - rx))
  [ $((ry + rh)) -gt "$dh" ] && rh=$((dh - ry))
  ovr=$(overlaps_rect "$rx" "$ry" "$rw" "$rh")
  if [ "${ovr:-0}" != 0 ]; then
    echo "  VOID (video mode): $ovr other window(s) lie inside the rect this would record."
    echo "  -> the rect covers the window's whole travel, so it is larger than Steam and can sweep"
    echo "     in windows that never overlap Steam itself. Move or close them and re-run."
    printf 'mode=video refused=overlap-in-record-rect n=%s\n' "$ovr" > "$out/capture-state.txt"
    exit 1
  fi
  echo "  recording ${VIDSEC}s over ${rw}x${rh} at ${rx},${ry} (window ${vw}x${vh} at ${vx},${vy})"
  printf 'rect=%s,%s,%s,%s window=%sx%s at %s,%s vidsec=%s\n' "$rx" "$ry" "$rw" "$rh" "$vw" "$vh" "$vx" "$vy" "$VIDSEC" > "$out/video-rect.txt"
  screencapture -v -V"$VIDSEC" -R"$rx,$ry,$rw,$rh" "$out/rec.mov" 2>"$out/video-capture.err"
  echo "$base" >> "$out/sizes.txt"
  /tmp/winlist 2>/dev/null | steamwin | grep -oE 'size=[0-9]+x[0-9]+' >> "$out/sizes.txt"
else
for i in $(seq 1 "$FRAMES"); do
  if [ "$CAPTURE" = screen ]; then
    # One winlist serves both the region and sizes.txt, so screen mode is not the slower sampler
    # (126 ms/frame against window's 151). ⚠ Its size is therefore read just BEFORE its capture,
    # where window mode reads just after: a growing-frame join can differ by one step between the
    # modes. Irrelevant to "does a black frame occur at all", which is what this mode is for.
    g=$(/tmp/winlist 2>/dev/null | steamwin | head -1)
    echo "$g" | grep -oE 'size=[0-9]+x[0-9]+' >> "$out/sizes.txt"
    r=$(echo "$g" | sed -nE 's/.*size=([0-9]+)x([0-9]+) at=(-?[0-9]+),(-?[0-9]+).*/\3,\4,\1,\2/p')
    [ -n "$r" ] && screencapture -x -o -R"$r" "$out/f$i.png" 2>/dev/null
    # ⚠ The region is frozen at the rect read ABOVE, but the capture takes ~88 ms and the window
    # keeps growing under it: measured 2026-09-05, 25-75 px (mean 28) on ~15 % of frames at
    # 25 px / 120 ms. Those are exactly the GROWING frames, and the growing edge is where issue
    # #7's strip lives -- so a screen-mode run systematically crops the strip out of its own right
    # band and its EDGE numbers are NOT comparable with window mode's. Recording the after-rect
    # makes that visible per frame instead of silent. A whole-host signature (issue #12's 100 %
    # black TOP band) is unaffected: a 28 px crop off the right cannot hide it.
    a=$(/tmp/winlist 2>/dev/null | steamwin | head -1 | grep -oE 'size=[0-9]+x[0-9]+')
    printf 'f%d before=%s after=%s\n' "$i" "$(echo "$g" | grep -oE 'size=[0-9]+x[0-9]+')" "$a" >> "$out/rects.txt"
  else
    screencapture -x -o -l "$ID" "$out/f$i.png" 2>/dev/null
    /tmp/winlist 2>/dev/null | steamwin | grep -oE 'size=[0-9]+x[0-9]+' >> "$out/sizes.txt"
  fi
done
fi
lock1=no; locked && lock1=yes; ov1=$(overlaps)
echo "  capture mode: $CAPTURE · session locked before/after: $lock0/$lock1 · windows over Steam before/after: $ov0/$ov1"
printf 'mode=%s locked=%s/%s overlaps=%s/%s\n' "$CAPTURE" "$lock0" "$lock1" "$ov0" "$ov1" > "$out/capture-state.txt"
if [ "$CAPTURE" = screen ] && { [ "$lock0" = yes ] || [ "$lock1" = yes ] || [ "${ov0:-0}" != 0 ] || [ "${ov1:-0}" != 0 ]; }; then
  echo "  VOID (screen mode): a locked session or a window over Steam means these frames are not of Steam"
  echo "  -> the numbers below describe the capture, not the app; do not read them as a result"
fi
if [ "$CAPTURE" = video ] && { [ "$lock1" = yes ] || [ "${ov0:-0}" != 0 ] || [ "${ov1:-0}" != 0 ]; }; then
  # Video mode EXITS rather than warning. A screen-mode run still leaves per-frame PNGs a reader
  # can open and judge; a video run leaves one summary line, and "no episodes" is indistinguishable
  # from a clean result unless the run refuses outright.
  echo "  VOID (video mode): the session locked mid-run, or a window came over Steam — this"
  echo "  -> recording is not of Steam, and its colour episodes would be of something else."
  exit 1
fi

echo "  distinct window sizes seen while sampling: $(sort -u "$out/sizes.txt" | wc -l | tr -d ' ')  (1 = the drag had stopped; treat as weak)"

if [ "$CAPTURE" = video ]; then
  # Duration, not rate. Report the achieved cadence FIRST: the recording is change-driven, so the
  # gap between frames is the resolution limit on every interval below it, and a run whose median
  # gap is 100 ms has measured nothing the ~113 ms frame probe did not already.
  [ -s "$out/rec.mov" ] || { echo "  VOID: no recording produced — $(head -1 "$out/video-capture.err" 2>/dev/null)"; exit 1; }
  [ -x /tmp/video-blue ] || swiftc -O "$(dirname "$0")/video-blue.swift" -o /tmp/video-blue -framework AVFoundation 2>/dev/null || exit 1
  /tmp/video-blue "$out/rec.mov" > "$out/video-frames.txt" 2>"$out/video-score.err"
  python3 - "$out" <<'PYV'
import sys, re, os
d = sys.argv[1]
rows = []
for ln in open(os.path.join(d, 'video-frames.txt')):
    m = re.match(r'f(\d+) t=([0-9.]+) (\d+)x(\d+) blue=([0-9.]+) blueloose=([0-9.]+) green=([0-9.]+) magenta=([0-9.]+)', ln)
    if m:
        rows.append((float(m.group(2)), float(m.group(5)), float(m.group(6)), float(m.group(7)), float(m.group(8))))
if len(rows) < 2:
    print('  VOID: %d video frames -- nothing to time' % len(rows)); sys.exit(1)
gaps = sorted((rows[i+1][0] - rows[i][0]) * 1000 for i in range(len(rows) - 1))
med = gaps[len(gaps)//2]
span = rows[-1][0] - rows[0][0]
print('  video: %d frames over %.1f s - inter-frame gap median %.1f ms, p90 %.1f ms, max %.1f ms'
      % (len(rows), span, med, gaps[int(0.9*len(gaps))], gaps[-1]))
print('  -> the resolution limit on every duration below is that gap: %.1f ms' % med)
for name, idx in (('blue (S3, child layer pre-drawable)', 1), ('green (S1, host larger than content)', 3),
                  ('magenta (S2, deferred create)', 4)):
    hits = [i for i, r in enumerate(rows) if r[idx] > 0]
    if not hits:
        print('  %-38s absent' % name); continue
    runs, cur = [], [hits[0]]
    for i in hits[1:]:
        if i == cur[-1] + 1: cur.append(i)
        else: runs.append(cur); cur = [i]
    runs.append(cur)
    durs = []
    for r in runs:
        end = rows[r[-1]+1][0] if r[-1]+1 < len(rows) else rows[r[-1]][0]
        durs.append((end - rows[r[0]][0]) * 1000)
    peak = max(rows[i][idx] for i in hits)
    print('  %-38s %d frame(s) in %d episode(s) - duration median %.0f ms, max %.0f ms - peak %.2f%% of the recorded area'
          % (name, len(hits), len(runs), sorted(durs)[len(durs)//2], max(durs), peak))
PYV
  echo "  frames: $out/video-frames.txt - recording: $out/rec.mov"
  exit 0
fi

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
