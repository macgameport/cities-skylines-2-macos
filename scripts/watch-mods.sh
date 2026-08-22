#!/bin/bash
# Watch whether the Paradox Launcher's CPatch actually downloads CS2 mod bytes (Idea 0).
# Streams the launcher's DownloadManager/CPatch/Patch log lines AND polls the on-disk mod
# folders for real bytes. Ctrl-C to stop.  See MODS-TESTING.md.
set -u

BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/Steam"
GAME="$BOTTLE/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"
MODS="$GAME/.cache/Mods/pdx_mods"
DL="$MODS/.downloading"
LOGDIR="$BOTTLE/drive_c/users/crossover/AppData/Local/Paradox Interactive/launcher-v2/logs"
# 4 target mods:  Move It=74324_36  UIL=74417_17  Anarchy=74604_39  Traffic=80095_28

newest_log() { ls -t "$LOGDIR"/launcher-2*.log 2>/dev/null | head -1; }

sizeof() { du -sh "$1" 2>/dev/null | cut -f1; }

echo "=== BASELINE $(date '+%H:%M:%S') ==="
echo "pdx_mods:      $(sizeof "$MODS")   ($(find "$MODS" -type f 2>/dev/null | wc -l | tr -d ' ') files)"
echo ".downloading:  $(sizeof "$DL")   ($(find "$DL" -type f 2>/dev/null | wc -l | tr -d ' ') files)"
echo "log:           $(newest_log)"
echo
echo "=== polling on-disk bytes every 5s + streaming download log lines (Ctrl-C to stop) ==="
echo

# Poll on-disk mod bytes in the background.
(
  while true; do
    sleep 5
    printf '[%s] pdx_mods=%s (%s files)  .downloading=%s (%s files)\n' \
      "$(date '+%H:%M:%S')" \
      "$(sizeof "$MODS")" "$(find "$MODS" -type f 2>/dev/null | wc -l | tr -d ' ')" \
      "$(sizeof "$DL")"   "$(find "$DL"   -type f 2>/dev/null | wc -l | tr -d ' ')"
  done
) &
POLL_PID=$!
trap 'kill $POLL_PID 2>/dev/null; exit 0' INT TERM

# Stream the interesting log lines from whatever the current launcher log is.
LOG="$(newest_log)"
if [ -n "$LOG" ]; then
  tail -n0 -F "$LOG" 2>/dev/null | grep --line-buffered -iE "DownloadManager|CPatch|PatchService|mod|download|pdx_mods|error|fail"
else
  echo "(no launcher log yet — open the launcher first, then re-run)"
  wait $POLL_PID
fi
