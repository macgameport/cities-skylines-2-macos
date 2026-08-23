#!/bin/bash
# Capture the state of a hung in-game Paradox Mods download ("Preparing 2%") to localize
# the stall: network fetch vs async-completion vs patch-apply. Run WHILE the game is hung.
# ⚠ CrossOver-era tool: paths target the dead CrossOver bottle (licence expired 2026-08-21).
# Kept for the record; for the current dxmt11 stack see capture-freeze.sh (alt-tab freeze).
set -u
SP="${1:-/tmp/cs2-hang-$(date +%s 2>/dev/null || echo now)}"; mkdir -p "$SP" 2>/dev/null
GAME="$HOME/Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"
DL="$GAME/.cache/Mods/pdx_mods/.downloading"
LL="$HOME/Library/Application Support/CrossOver/Bottles/Steam/drive_c/users/crossover/AppData/LocalLow/Colossal Order/Cities Skylines II"

PID=$(pgrep -f "Cities2.exe" | head -1)
echo "=== Cities2.exe pid: ${PID:-NOT FOUND} ==="
[ -z "$PID" ] && { echo "game not running — launch + reach the hang first"; exit 1; }

echo; echo "=== [1] .downloading bytes (is content landing?) ==="
find "$DL" -type f -exec ls -la {} \; 2>/dev/null | awk '{print "  "$5"B  "$NF}'
echo "  total: $(du -sh "$DL" 2>/dev/null | cut -f1)  files: $(find "$DL" -type f 2>/dev/null | wc -l | tr -d ' ')"

echo; echo "=== [2] open mod/download files + network sockets (lsof) ==="
echo "--- mod-related open files ---"
lsof -p "$PID" 2>/dev/null | grep -iE "pdx_mods|downloading|\.cache/Mods" | awk '{print "  "$4" "$NF}' | head -20
echo "--- network connections (CDN fetch alive?) ---"
lsof -nP -p "$PID" -i 2>/dev/null | grep -iE "TCP|UDP" | head -20 || echo "  (none)"

echo; echo "=== [3] PdxSdk.log tail (last stage before the hang) ==="
tail -25 "$LL/Logs/PdxSdk.log" 2>/dev/null

echo; echo "=== [4] thread-stack sample (8s) → where are threads blocked? ==="
sample "$PID" 8 -file "$SP/sample.txt" >/dev/null 2>&1
echo "  saved: $SP/sample.txt"
echo "--- threads blocked in read/recv/wait/completion (the tell) ---"
grep -iE "recv|read|WaitFor|NtWaitForSingleObject|Sleep|poll|kevent|completion|semaphore|Monitor|Socket" "$SP/sample.txt" 2>/dev/null | sed 's/^ *//' | sort | uniq -c | sort -rn | head -20
echo; echo "  (full stacks in $SP/sample.txt)"
