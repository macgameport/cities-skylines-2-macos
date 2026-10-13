#!/bin/bash
# perf-bench.sh — one fully autonomous benchmark measurement cycle (perf pass, plan §2 R-bench).
#
# Launches the game with -benchmark through perf-run.sh (capture + caffeinate + load-signal grep),
# waits for the game to write a NEW result into Benchmark.coc (the benchmark auto-runs a bundled
# save at boot and returns to the main menu — measured 2026-08-23), parses the result into one
# JSON line, then ends the session at the idle menu (see Teardown below), which lets the
# launcher run its normal graceful Steam shutdown; wineserver -k only as escalation.
#
# Usage:  [CELL_ENV…] CS2_HUD=1 bash scripts/perf-bench.sh <cell-name>
# Teardown: WM_CLOSE to the game window (win-resize-driver.exe close, as boot-verify.sh does), so
#   Unity writes its graceful-exit report (allocator stats, Job.Worker list) into Player.log; SIGTERM
#   only if that fails. CS2_TEARDOWN=sigterm restores the old SIGTERM-only ending. The row records
#   `teardown` and `graceful`; Player.log is copied beside the run log.
#   Also wakes the display first and records `display_awake` / `locked` (a sleeping panel changes
#   the numbers — see the state block below). Added 2026-10-10 (perf-pass
#   re-check: a SIGTERM'd Player.log carries none of P4's load signals).
# Output: human summary on stdout; one JSON row appended to ~/cs2-patch/perf-runs/results.jsonl
#         (frame-time series reduced to stats — raw series stays in Benchmark.coc until the next run
#         overwrites it; the run log names which cell owned it).
set -u

CELL="${1:?usage: [CELL_ENV…] bash scripts/perf-bench.sh <cell-name>}"
WRAPPER="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
PREFIX="$WRAPPER/Contents/SharedSupport/prefix"
LOCALLOW="$PREFIX/drive_c/users/Wineskin/AppData/LocalLow/Colossal Order/Cities Skylines II"
BC="$LOCALLOW/Benchmark.coc"
RUNDIR="${CS2_PERF_DIR:-$HOME/cs2-patch/perf-runs}"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$RUNDIR"

BC_BEFORE=$(stat -f %m "$BC" 2>/dev/null || echo 0)
T_START=$(date +%s)

# Display + session state are part of the measurement (2026-10-10): runs with the panels ASLEEP read
# GPU-bound 2-9 % and gpuMs ~21.5 where the same config with them awake read 18-20 % and 17.5 —
# perf-run's `caffeinate -dis` stops idle sleep but never wakes a panel that is already off. So wake
# it (`caffeinate -u` declares user activity; it does not unlock), and record both states in the row.
{ [ -x /tmp/winlist ] && [ /tmp/winlist -nt "$SELF_DIR/winlist.swift" ]; } \
  || swiftc -O "$SELF_DIR/winlist.swift" -o /tmp/winlist 2>/dev/null
caffeinate -u -t 5 >/dev/null 2>&1 &
sleep 3
main_awake() { /tmp/winlist --displays 2>/dev/null | grep -q 'main=1 .*asleep=0'; }
is_locked() { ioreg -n Root -d1 -a 2>/dev/null | grep -q CGSSessionScreenIsLocked; }
AWAKE_START=no; main_awake && AWAKE_START=yes
LOCKED=no; is_locked && LOCKED=yes
# A Screen Sharing viewer streams the display, which costs GPU/CPU: the same config read ~43 FPS with
# one connected (2026-10-10 22:40-23:05) against 47.8 without (C75). Recorded, not refused.
SHARED=no; pmset -g assertions 2>/dev/null | grep -q "Remote user is connected" && SHARED=yes
echo "    display awake at start: $AWAKE_START · session locked: $LOCKED · screen sharing: $SHARED"
echo "=== bench cycle: $CELL (previous Benchmark.coc mtime: $BC_BEFORE)"

CS2_ARGS="-benchmark${CS2_ARGS:+ $CS2_ARGS}" bash "$SELF_DIR/perf-run.sh" "$CELL" &
RUNPID=$!

# Benchmark takes ~3-5 min end to end (boot + 45s scene load + ~2 min run). 15 min ceiling.
ok=0
for i in $(seq 1 180); do
  sleep 5
  kill -0 "$RUNPID" 2>/dev/null || break   # launcher died early (its log has the reason)
  NOW=$(stat -f %m "$BC" 2>/dev/null || echo 0)
  [ "$NOW" -gt "$BC_BEFORE" ] && { ok=1; break; }
done

AWAKE_END=no; main_awake && AWAKE_END=yes   # sampled as the result lands, before teardown
DISPLAY_AWAKE=no; [ "$AWAKE_START" = yes ] && [ "$AWAKE_END" = yes ] && DISPLAY_AWAKE=yes
[ "$DISPLAY_AWAKE" = yes ] || echo "  ⚠ VOID as a measurement: the main display was ASLEEP during this cycle (start=$AWAKE_START end=$AWAKE_END)"
[ "$ok" = 1 ] && sleep 10   # let the file finish writing and the menu settle

# End the session at the idle menu. WM_CLOSE first, so the game exits the way a player's Quit does
# and Unity appends its graceful-exit report to Player.log (perf-pass §3D: the D-rows' load signals
# live only there); the launcher then shuts Steam down on its own. SIGTERM is the fallback, and the
# row says which one ran. '/Cities2.exe' leading-slash scoping per GOTCHAS (self-match class).
WINE="$WRAPPER/Contents/SharedSupport/wine/bin/wine64"
DRV="${CS2_DRIVER:-$HOME/cs2-patch/win-resize-driver.exe}"
PL="$LOCALLOW/Player.log"
TEARDOWN=none
game_gone() { ! pgrep -f "$PREFIX.*/Cities2.exe" >/dev/null 2>&1; }
GPID=$(pgrep -f "$PREFIX.*/Cities2.exe" | head -1)
if [ -n "${GPID:-}" ] && [ "${CS2_TEARDOWN:-graceful}" != sigterm ] && [ -f "$DRV" ]; then
  # The driver needs the launcher's wine environment (WINEPREFIX exported, or it targets the default
  # prefix; the DYLD path, or wine cannot load its own dylibs). Its output is CRLF.
  H=$(WINEPREFIX="$PREFIX" WINEDEBUG=-all \
      DYLD_FALLBACK_LIBRARY_PATH="$WRAPPER/Contents/Frameworks:$WRAPPER/Contents/SharedSupport/wine/lib:/usr/lib:/usr/local/lib" \
      "$WINE" "$DRV" list 2>/dev/null | tr -d '\r' | grep -i 'class=UnityWndClass' | grep -i 'title=Cities' | awk '{print $1}' | head -1)
  if [ -n "$H" ] && WINEPREFIX="$PREFIX" WINEDEBUG=-all \
      DYLD_FALLBACK_LIBRARY_PATH="$WRAPPER/Contents/Frameworks:$WRAPPER/Contents/SharedSupport/wine/lib:/usr/lib:/usr/local/lib" \
      "$WINE" "$DRV" close "$H" >/dev/null 2>&1; then
    for i in $(seq 1 24); do sleep 5; game_gone && break; done
    game_gone && TEARDOWN=wm_close
    echo "  teardown: WM_CLOSE posted to $H — game $(game_gone && echo exited || echo STILL UP after 120 s)"
  else
    echo "  teardown: no game window found / driver refused — falling back to SIGTERM"
  fi
fi
if [ -n "${GPID:-}" ] && ! game_gone; then
  kill -TERM "$GPID" 2>/dev/null
  for i in $(seq 1 12); do sleep 5; game_gone && break; done
  TEARDOWN=sigterm
  if ! game_gone; then
    echo "  game ignored TERM — ending the wine session for this prefix (documented fallback)"
    WINEPREFIX="$PREFIX" "$WRAPPER/Contents/SharedSupport/wine/bin/wineserver" -k 2>/dev/null
    TEARDOWN=wineserver-k
  fi
fi
GRACEFUL=no
sleep 3
# Only THIS cycle's Player.log counts: a game that never started leaves the previous run's log,
# which may well carry both markers.
[ "$(stat -f %m "$PL" 2>/dev/null || echo 0)" -gt "$T_START" ] \
  && grep -q 'Game terminated successfully' "$PL" && grep -q 'Memory Statistics' "$PL" && GRACEFUL=yes
cp "$PL" "$RUNDIR/$CELL-$(date '+%Y%m%d-%H%M%S')-Player.log" 2>/dev/null
echo "  teardown=$TEARDOWN graceful=$GRACEFUL (Player.log: exit marker + allocator report $([ "$GRACEFUL" = yes ] && echo present || echo ABSENT))"

if [ "$ok" = 1 ]; then
  python3 - "$BC" "$CELL" "$RUNDIR/results.jsonl" "$TEARDOWN" "$GRACEFUL" "$DISPLAY_AWAKE" "$LOCKED" "$SHARED" <<'PY'
import json, sys, statistics, datetime
bc, cell, out, teardown, graceful, awake, locked, shared = sys.argv[1:9]
raw = open(bc, encoding='utf-8', errors='replace').read()
d = json.loads(raw[raw.index('{'):])['latestResult']
def series_stats(name):
    xs = d.get(name) or []
    xs = [float(x) for x in xs if isinstance(x, (int, float))]
    if not xs: return None
    xs_sorted = sorted(xs)
    p99 = xs_sorted[min(len(xs)-1, int(len(xs)*0.99))]
    return {'avg': round(sum(xs)/len(xs), 3), 'stdev': round(statistics.pstdev(xs), 3),
            'p99_ms': round(p99, 3), 'fps_1pct_low': round(1000.0/p99, 2) if p99 else None}
row = {
    'cell': cell,
    'recorded': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
    'averageFps': d.get('averageFps'), 'framesRendered': d.get('framesRendered'),
    'gpuBoundPercent': d.get('gpuBoundPercent'), 'simulationTicks': d.get('simulationTicks'),
    'loadingTimeSecs': d.get('loadingTimeSecs'),
    'gpuMs': d.get('gpuMs'), 'cpuMs': d.get('cpuMs'),
    'cpuGameMs': d.get('cpuGameMs'), 'cpuRenderMs': d.get('cpuRenderMs'),
    'gpuFrame': series_stats('gpuFrameTimes'), 'cpuFrame': series_stats('cpuFrameTimes'),
    'quality': d.get('graphicsQuality'), 'resolution': d.get('screenResolution'),
    'gameVersion': d.get('gameVersion'),
    'teardown': teardown, 'graceful': graceful == 'yes',
    'display_awake': awake == 'yes', 'locked': locked == 'yes', 'screen_shared': shared == 'yes',
}
with open(out, 'a') as f:
    f.write(json.dumps(row) + '\n')
print('--- parsed result:')
print(json.dumps({k: v for k, v in row.items() if k not in ('gameVersion',)}, indent=1))
PY
else
  echo "⚠ NO new benchmark result (timeout or early exit) — inspect the newest $RUNDIR/$CELL-*.log"
fi

wait "$RUNPID" 2>/dev/null
rc=$?
echo "=== bench cycle $CELL done (launcher rc=$rc, result=$([ "$ok" = 1 ] && echo OK || echo MISSING))"
[ "$ok" = 1 ]
