#!/bin/bash
# perf-run.sh — measurement-cell wrapper for the perf pass (docs/plans/perf-pass.md §2).
#
# Every measurement cell launches through this, from a terminal — never the dock app (fixed env,
# no capture). It provides, per run: display-sleep protection (caffeinate), full stderr capture
# (DXMT's load-verification lines reach wine stderr), a DXMT-side log copy (DXMT_LOG_PATH), and
# an automatic post-run grep of the load signals. The run log's timestamped name is what ethos #3
# ("judge runs by timestamp") judges by.
#
# Usage:
#   [CELL_ENV…] CS2_HUD=1 bash scripts/perf-run.sh <cell-name>
# Examples:
#   CS2_ARGS=-benchmark CS2_HUD=1 bash scripts/perf-run.sh p0-benchmark-probe
#   CS2_METALFX=1 DXMT_CONFIG="d3d11.metalSpatialUpscaleFactor=1.5" CS2_HUD=1 \
#     bash scripts/perf-run.sh a2-metalfx-720p15
#
# Run logs land in ~/cs2-patch/perf-runs/ (outside the repo, on purpose — raw logs may carry
# paths/IDs; only reduced numbers go into docs/perf-pass-results.md, per the publishability rule).
set -u

CELL="${1:?usage: [CELL_ENV…] bash scripts/perf-run.sh <cell-name>}"
RUNDIR="${CS2_PERF_DIR:-$HOME/cs2-patch/perf-runs}"
LAUNCHER="${CS2_LAUNCHER:-$HOME/cs2-patch/launch-cs2-dxmt11.sh}"
mkdir -p "$RUNDIR"
TS=$(date '+%Y%m%d-%H%M%S')
LOG="$RUNDIR/$CELL-$TS.log"

[ -f "$LAUNCHER" ] || { echo "ERROR: launcher not found: $LAUNCHER"; exit 1; }
# Two wrappers exist (promoted + parked). A stray CS2_WRAPPER silently measures the wrong engine.
[ -n "${CS2_WRAPPER:-}" ] && echo "⚠ CS2_WRAPPER=$CS2_WRAPPER — measuring THAT wrapper, not the default. Unset unless intended."

# DXMT writes its own per-DLL logs here as the belt-and-braces copy of the load signals.
export DXMT_LOG_PATH="$RUNDIR"

echo "=== perf cell: $CELL"
echo "    started:  $TS"
echo "    log:      $LOG"
env | grep -E '^(DXMT_|MTL_|CS2_)' | sed 's/^/    env:      /'
echo "==="

caffeinate -dis bash "$LAUNCHER" 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}

echo
echo "=== cell $CELL finished (launcher rc=$rc) — $(date '+%Y%m%d-%H%M%S')"
echo "--- load signals in $LOG:"
grep -E "Found config (env|file)|MetalFX|Scale:|DXMT capture enabled|^Engine:|Vendor extension enabled" "$LOG" \
  | sed 's/^/    /' || echo "    (none found — a DXMT cell without its signal measured NOTHING; see plan §0 ethos #4)"
echo "--- next: record HUD readings + verdict in docs/perf-pass-results.md (protocol: plan §2)"
exit "$rc"
