#!/bin/bash
# Diagnostic launch for the alt-tab freeze: the canonical dxmt11 launcher plus
# winemac-side tracing, with everything captured to a timestamped /tmp log.
#
# Terminal only — do NOT wire this into the .app icon. One run costs fps and
# writes a large trace; use it to reproduce the freeze once, not to play.
#
# Procedure (needs a human at the keyboard — automation cannot deliver a real
# macOS focus loss to a Wine window):
#   1. bash scripts/diag-launch-dxmt11.sh
#   2. reach the main menu (or a city), note the wall clock, then alt-tab /
#      click another window; wait ~5s; come back to the game
#   3. if frozen: bash scripts/capture-freeze.sh     (read-only forensics)
#   4. recover (Steam quit, else wineserver -k as printed by capture-freeze)
#
# Channels: macdrv (window/view state sync), display (mode set/restore),
# event (APP_(DE)ACTIVATED, WINDOW_DID_MINIMIZE/UNMINIMIZE delivery).
# 'cursor' deliberately NOT enabled — per-frame mouse spam.
# 'timestamp' prefixes each line so the freeze moment can be correlated.
TS=$(date +%Y%m%d-%H%M%S)
LOG="/tmp/cs2-diag-$TS.log"
export WINEDEBUG="timestamp,+macdrv,+display,+event"
export DXMT_LOG_LEVEL=info
unset CS2_QUIET
echo "=== diagnostic run — wine/macdrv trace → $LOG ==="
date "+launch wall clock: %F %T"
bash "$HOME/cs2-patch/launch-cs2-dxmt11.sh" 2>&1 | tee "$LOG"
