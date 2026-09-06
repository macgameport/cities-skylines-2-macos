#!/bin/bash
# video-gap-battery.sh — N drags on the stage-1 DIAG build, recorded, to TIME the diagnostic colours.
#
# Everything issue #12 knows about the S3 gap comes from single captured frames: 2 blue frames out
# of 3,900 across 13 diag runs (C56). That establishes the state exists and is really on the
# display, and bounds its duration only to "shorter than about 226 ms" -- which is not a number any
# fix decision can rest on. #13 needs to know whether this is 3 ms or 100 ms, and T3 needs to know
# what James should be looking for.
#
#   bash scripts/video-gap-battery.sh          # 12 runs, ~45 min
#   N=4 bash scripts/video-gap-battery.sh      # a short version
#
# Only the diag build is worth recording: a prod build paints no colours, so there would be nothing
# to time. Green/magenta/blue are scored together because the same recording carries all three, and
# green (S1, issue #7's strip) is far commoner than blue -- present in every diag run on disk.
#
# ⚠ WHILE THIS RUNS, TOUCH NOTHING IT READS, and keep windows off Steam: this records the
# COMPOSITED DISPLAY, so a window in front of Steam lands in the recording. The probe counts
# overlaps before and after and writes them to capture-state.txt; a row with a nonzero count is
# not evidence. Run it DETACHED with a log. drag-session.sh restores the daily driver every row.
# (macgameport, 2026-09-06)
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
N="${N:-12}"
OUT="${VID_OUT:-$HOME/cs2-patch/video-gap/$(date +%Y%m%d-%H%M%S)}"
TAG="$(basename "$OUT")"
mkdir -p "$OUT"
export SYNTH_PX=25 SYNTH_MS=120 SYNTH_REPEAT=3 SYNTH_PAUSE=3 PRESIZE=1000x650 SYNTH_DX=650 SYNTH_DY=350
export CAPTURE=video VIDSEC="${VIDSEC:-45}"

echo "########## video gap battery  $(date '+%F %T')  run dir $OUT"
echo "  N=$N · role t0 (stage 1 + diag colours) · recording ${VIDSEC}s per drag · 25 px / 120 ms"
# ⚠ THIS BATTERY NEEDS THE SESSION UNLOCKED, and that is the one precondition it cannot wait out.
# `screencapture -v` composites the display, so a locked session records the lock screen -- and a
# lock-screen recording scores as a flawless run (measured 2026-09-06: 1073 frames, 60 fps, no
# diagnostic colour). The window-capture modes are unaffected and run locked quite happily; only
# this one cares. Refuse up front rather than spending twelve rows finding out.
if python3 -c "import subprocess,sys; sys.exit(0 if 'CGSSessionScreenIsLocked' in subprocess.run(['ioreg','-n','Root','-d1','-a'],capture_output=True,text=True).stdout else 1)"; then
  echo "  REFUSED: the session is LOCKED. Every row would record the lock screen and report a"
  echo "  clean run. Unlock the screen and start this again — it needs no hands after that."
  exit 3
fi
f="$HOME/cs2-patch/winemac.so.s1-diag"
[ -f "$f" ] || { echo "missing $f"; exit 2; }
echo "  s1diag  $(shasum -a 256 "$f" | cut -c1-16)"

for r in $(seq 1 "$N"); do
  id="r${r}-s1diag"; rd="$OUT/$TAG-$id"
  # Same two reasons a row is worth waiting for rather than spending (see strip-module-ab.sh): a
  # refused row costs 4 s against a real row's 3.5 min, so a transient outage drains the queue.
  for w in $(seq 1 60); do
    ping -c1 -W2000 1.1.1.1 >/dev/null 2>&1 && break
    [ "$w" = 1 ] && echo "    network down — holding this row until it returns (up to 30 min)"
    sleep 30
  done
  # A loaded machine lengthens every interval this battery is trying to measure, so a row taken
  # under load would report a gap that is partly the machine's, not the compositor's.
  for w in $(seq 1 40); do
    l=$(uptime | sed -E 's/.*load averages?: ([0-9.]+).*/\1/')
    awk -v l="$l" 'BEGIN{exit !(l+0 < 12)}' && break
    [ "$w" = 1 ] && echo "    loadavg $l — holding this row until it settles (up to 20 min)"
    sleep 30
  done
  echo "=== $id  $(date '+%T')"
  DRAG=synth TRACE=+err,+macdrv,+cursor,+timestamp DRAG_OUT="$rd" \
    bash "$REPO/scripts/drag-session.sh" t0 > "$OUT/$id.log" 2>&1
  rc=$?
  if [ "$rc" != 0 ] && grep -qE "VOID:.*(network|FATAL)" "$OUT/$id.log" 2>/dev/null; then
    echo "    exit $rc — precondition VOID, retrying this row once after 60 s"
    sleep 60
    DRAG=synth TRACE=+err,+macdrv,+cursor,+timestamp DRAG_OUT="$rd" \
      bash "$REPO/scripts/drag-session.sh" t0 > "$OUT/$id.log" 2>&1
    rc=$?
  fi
  echo "    exit $rc"
  sed -n '/video:/,/magenta (S2/p' "$OUT/$id.log" 2>/dev/null | sed "s/^/   $id · /"
  grep -h 'mode=video' "$rd/frames/capture-state.txt" 2>/dev/null | sed "s/^/   $id · guards: /"
done

echo "########## tally $(date '+%F %T')"
python3 - "$OUT" "$TAG" "$N" <<'PY'
import sys, os, re
out, tag, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
allrows, cadence, voids = {}, [], []
for r in range(1, n + 1):
    d = os.path.join(out, f"{tag}-r{r}-s1diag", "frames")
    fp = os.path.join(d, "video-frames.txt")
    st = os.path.join(d, "capture-state.txt")
    if not os.path.exists(fp):
        voids.append(f"r{r}"); continue
    ov = ""
    if os.path.exists(st):
        m = re.search(r'overlaps=(\S+)', open(st).read())
        if m and m.group(1) not in ('0/0',):
            voids.append(f"r{r}(overlap {m.group(1)})"); continue
    rows = []
    for ln in open(fp):
        m = re.match(r'f(\d+) t=([0-9.]+) (\d+)x(\d+) blue=([0-9.]+) blueloose=([0-9.]+) green=([0-9.]+) magenta=([0-9.]+)', ln)
        if m:
            rows.append((float(m.group(2)), float(m.group(5)), float(m.group(7)), float(m.group(8))))
    if len(rows) < 2:
        voids.append(f"r{r}(no frames)"); continue
    gaps = sorted((rows[i+1][0]-rows[i][0])*1000 for i in range(len(rows)-1))
    cadence.append(gaps[len(gaps)//2])
    for name, idx in (('blue', 1), ('green', 2), ('magenta', 3)):
        hits = [i for i, x in enumerate(rows) if x[idx] > 0]
        if not hits: continue
        runs, cur = [], [hits[0]]
        for i in hits[1:]:
            if i == cur[-1]+1: cur.append(i)
            else: runs.append(cur); cur = [i]
        runs.append(cur)
        for g in runs:
            end = rows[g[-1]+1][0] if g[-1]+1 < len(rows) else rows[g[-1]][0]
            allrows.setdefault(name, []).append((end - rows[g[0]][0])*1000)
if cadence:
    cadence.sort()
    print("  achieved cadence across %d valid runs: median inter-frame gap %.1f ms (range %.1f-%.1f)"
          % (len(cadence), cadence[len(cadence)//2], cadence[0], cadence[-1]))
    print("  -> every duration below is resolved to about that; a median near 113 ms would mean")
    print("     this battery measured nothing the frame probe did not already.")
for name in ('blue', 'green', 'magenta'):
    v = sorted(allrows.get(name, []))
    if not v:
        print("  %-8s no episodes in %d runs" % (name, len(cadence))); continue
    print("  %-8s %d episodes over %d runs (%.1f per run) · duration median %.0f ms · p90 %.0f ms · max %.0f ms"
          % (name, len(v), len(cadence), len(v)/max(1, len(cadence)), v[len(v)//2], v[int(0.9*len(v))], v[-1]))
if voids: print("  VOID rows (not counted): %s" % ", ".join(voids))
PY
echo "########## done — $OUT"
