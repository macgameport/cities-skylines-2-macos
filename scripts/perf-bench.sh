#!/bin/bash
# perf-bench.sh — one fully autonomous benchmark measurement cycle (perf pass, plan §2 R-bench).
#
# Launches the game with -benchmark through perf-run.sh (capture + caffeinate + load-signal grep),
# waits for the game to write a NEW result into Benchmark.coc (the benchmark auto-runs a bundled
# save at boot and returns to the main menu — measured 2026-08-23), parses the result into one
# JSON line, then ends the session: SIGTERM to the game process at the idle menu, which lets the
# launcher run its normal graceful Steam shutdown; wineserver -k only as escalation.
#
# Usage:  [CELL_ENV…] CS2_HUD=1 bash scripts/perf-bench.sh <cell-name>
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

if [ "$ok" = 1 ]; then
  sleep 10   # let the file finish writing and the menu settle
  python3 - "$BC" "$CELL" "$RUNDIR/results.jsonl" <<'PY'
import json, sys, statistics, datetime
bc, cell, out = sys.argv[1], sys.argv[2], sys.argv[3]
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
}
with open(out, 'a') as f:
    f.write(json.dumps(row) + '\n')
print('--- parsed result:')
print(json.dumps({k: v for k, v in row.items() if k not in ('gameVersion',)}, indent=1))
PY
else
  echo "⚠ NO new benchmark result (timeout or early exit) — inspect the newest $RUNDIR/$CELL-*.log"
fi

# End the session: TERM the game's wine process at the idle menu; launcher then shuts Steam down
# gracefully on its own. '/Cities2.exe' leading-slash scoping per GOTCHAS (self-match class).
GPID=$(pgrep -f "$PREFIX.*/Cities2.exe" | head -1)
if [ -n "${GPID:-}" ]; then
  kill -TERM "$GPID" 2>/dev/null
  for i in $(seq 1 12); do sleep 5; kill -0 "$GPID" 2>/dev/null || break; done
  if kill -0 "$GPID" 2>/dev/null; then
    echo "  game ignored TERM — ending the wine session for this prefix (documented fallback)"
    WINEPREFIX="$PREFIX" "$WRAPPER/Contents/SharedSupport/wine/bin/wineserver" -k 2>/dev/null
  fi
fi
wait "$RUNPID" 2>/dev/null
rc=$?
echo "=== bench cycle $CELL done (launcher rc=$rc, result=$([ "$ok" = 1 ] && echo OK || echo MISSING))"
[ "$ok" = 1 ]
