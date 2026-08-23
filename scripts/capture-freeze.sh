#!/bin/bash
# Forensics for the CS2 alt-tab presentation freeze (DXMT/Wine 11 stack).
# RUN WHILE THE GAME IS FROZEN, before any wineserver -k. Read-only: kills nothing.
# Usage:  bash scripts/capture-freeze.sh  [outdir]
#
# Why these probes (see docs/dxmt-bugs/DRAFT-focus-loss-freeze.md for the theory):
# the freeze has two live mechanism candidates, and they separate cleanly on
# CPU + thread stacks:
#   A. orphaned layer  — DXMT keeps presenting full speed into a CAMetalLayer that
#      is no longer composited -> game burns CPU, sample shows no blocking.
#   B. drawable starvation — presentDrawableAfterMinimumDuration wedges the layer's
#      drawable pool while the window is un-composited; afterwards nextDrawable
#      blocks 1s/frame and returns nil forever (DXMT never checks or logs it)
#      -> near-idle CPU, sample shows CAMetalLayer nextDrawable / semaphore waits
#      on the encoder thread.
set -u
TS=$(date +%Y%m%d-%H%M%S)
OUT="${1:-/tmp/cs2-freeze-$TS}"; mkdir -p "$OUT"

PID=$(pgrep -f "Cities2.exe" | head -1)
[ -z "$PID" ] && { echo "Cities2.exe not running — reproduce the freeze first."; exit 1; }
echo "=== Cities2.exe pid $PID → $OUT ==="

# [1] Is anything reaching the screen? Two centre-region captures, 4s apart.
#     (Centre region only: the menu-bar clock would make full-screen captures
#     always differ. The game is fullscreen, so the centre is game surface.)
screencapture -x -R400,300,800,400 "$OUT/centre-1.png" 2>/dev/null
sleep 4
screencapture -x -R400,300,800,400 "$OUT/centre-2.png" 2>/dev/null
H1=$(md5 -q "$OUT/centre-1.png" 2>/dev/null || echo a)
H2=$(md5 -q "$OUT/centre-2.png" 2>/dev/null || echo b)
if [ "$H1" = "$H2" ]; then echo "[1] screen centre: STATIC (identical 4s apart) — freeze active"
else echo "[1] screen centre: UPDATING — freeze not active (or partial); captures kept anyway"; fi

# [2] CPU: full-speed-into-dead-layer (theory A) vs blocked-in-nextDrawable (theory B)
echo "[2] process + per-thread CPU:"
ps -o pid,pcpu,time,comm -p "$PID" | tee "$OUT/cpu.txt"
ps -M "$PID" > "$OUT/threads.txt" 2>/dev/null
awk 'NR<=12' "$OUT/threads.txt"

# [3] 5-second thread-stack sample. PE-side (d3d11.dll) frames will not
#     symbolicate under Rosetta; the unix side (winemetal.so, CoreAnimation,
#     Metal, AppKit) will — and that is where the discriminating frames live.
echo "[3] sampling 5s…"
sample "$PID" 5 -file "$OUT/sample.txt" >/dev/null 2>&1
echo "    signature scan of sample.txt:"
for sig in nextDrawable CAMetalLayer presentDrawable winemetal MTLDrawable \
           semaphore_wait ulock_wait psynch_cvwait usleep mach_msg; do
  n=$(grep -c "$sig" "$OUT/sample.txt" 2>/dev/null | tr -d ' ')
  [ "${n:-0}" != "0" ] && printf "      %-22s %s\n" "$sig" "$n"
done

# [4] wineserver sample (is win32 event routing itself alive?)
WS=$(pgrep -f "CS2dxmt11.app.*wineserver" | head -1)
[ -n "$WS" ] && sample "$WS" 3 -file "$OUT/sample-wineserver.txt" >/dev/null 2>&1

# [5] log tails: game side + the diag wine/macdrv trace if this run used
#     scripts/diag-launch-dxmt11.sh
LL="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix/drive_c/users/Wineskin/AppData/LocalLow/Colossal Order/Cities Skylines II"
tail -60 "$LL/Player.log"           > "$OUT/Player.log.tail"    2>/dev/null
tail -30 "$LL/Logs/SceneFlow.log"   > "$OUT/SceneFlow.log.tail" 2>/dev/null
DIAG=$(ls -t /tmp/cs2-diag-*.log 2>/dev/null | head -1)
if [ -n "$DIAG" ]; then
  tail -600 "$DIAG" > "$OUT/winedebug.tail"
  echo "[5] winedebug tail taken from $DIAG"
else
  echo "[5] no /tmp/cs2-diag-*.log — run was not launched with scripts/diag-launch-dxmt11.sh"
fi

echo
echo "=== done: $OUT ==="
echo "Recover afterwards with the usual: quit via Steam if possible, else"
echo "  WINEPREFIX=\"\$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix\" \\"
echo "    \"\$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport/wine/bin/wineserver\" -k"
echo "(never kill -9 — it leaves a .crash marker; the launcher clears stale ones anyway)"
