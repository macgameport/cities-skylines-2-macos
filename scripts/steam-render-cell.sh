#!/bin/bash
# steam-render-cell.sh — run ONE measured "does Steam's visible UI render?" cell and judge it
# by per-window capture, not by logs.
#
# WHY: every revisit of the Steam-UI thread (PLAN.md § "Steam's visible UI") re-derives the same
# scaffolding — shut Steam down cleanly, clear the traps, launch visibly, find the window, capture
# it, revert. Three traps make an ad-hoc run give a WRONG answer rather than no answer:
#
#   1. A stale Chromium `SingletonLock` in htmlcache silently turns the next launch into `--silent`
#      — no window at all, which reads exactly like a render failure. (From BCD1210/soju's writeup
#      on dxmt#141, 2026-08-28.) Purged per cell below.
#   2. `screencapture` produces NO FILE when the display sleeps or locks, and the black-window
#      readings this whole thread turns on are file SIZES. So every cell also captures a
#      known-good window; if that one fails too, the instrument is blind and the cell is VOID,
#      not black. `caffeinate` holds the display up for the run.
#   3. A steam.exe re-exec'd by its own updater carries a Windows-style argv, so no .app-path
#      pgrep matches it — attribute by open files against the PREFIX (`_owns`), never by cmdline.
#
# Calibration measured 2026-08-28 on the same two windows: black ≈ 15–41 KB, rendered ≈ 0.7–2.0 MB.
#
# Usage:
#   bash scripts/steam-render-cell.sh --label control
#   bash scripts/steam-render-cell.sh --label single --shim-args " --single-process"
#   bash scripts/steam-render-cell.sh --label anglegl --steam-args "--use-angle=gl"
#
# --shim-args needs the webhelper shim installed (scripts/install-webhelper-shim.sh); it is how
# switches steam.exe FILTERS (`--in-process-gpu`, `--disable-gpu`, `--single-process`) reach CEF.
# --steam-args goes on steam.exe's own command line, which forwards `--use-angle` unfiltered.
# Results land in /tmp/steam-cell-<label>/ ; the cell shuts Steam down again on the way out.
set -u

LABEL="cell"; SHIM_ARGS=""; STEAM_ARGS=""; WAIT=95; KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --label) shift; LABEL="$1" ;;
    --shim-args) shift; SHIM_ARGS="$1" ;;
    --steam-args) shift; STEAM_ARGS="$1" ;;
    --wait) shift; WAIT="$1" ;;
    --keep-running) KEEP=1 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
  shift
done

APP="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
SS="$APP/Contents/SharedSupport"
[ -x "$SS/wine/bin/wine64" ] || { echo "ERROR: no wine at $SS/wine/bin/wine64"; exit 1; }
export WINE="$SS/wine/bin/wine64"
export WINEPREFIX="$SS/prefix"
export PATH="$SS/wine/bin:$PATH"
export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d;winemenubuilder.exe=d"
S="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
OUT="/tmp/steam-cell-$LABEL"; mkdir -p "$OUT"

_owns() { lsof -p "$1" 2>/dev/null | grep -q "$WINEPREFIX"; }          # trap 3
steam_up() { for p in $(pgrep -f "steam.exe" 2>/dev/null); do _owns "$p" && return 0; done; return 1; }
shutdown_steam() {
  steam_up || return 0
  "$WINE" "$S/steam.exe" -shutdown >/dev/null 2>&1                      # never kill -9 (GOTCHAS)
  for _ in $(seq 25); do steam_up || break; sleep 1; done
  steam_up && { WINEPREFIX="$WINEPREFIX" "$SS/wine/bin/wineserver" -k >/dev/null 2>&1; sleep 3; }
  for p in $(pgrep -f "steamwebhelper" 2>/dev/null); do
    _owns "$p" && { WINEPREFIX="$WINEPREFIX" "$SS/wine/bin/wineserver" -k >/dev/null 2>&1; sleep 2; break; }
  done
}

WL=/tmp/winlist
[ -x "$WL" ] || swiftc -O "$(cd "$(dirname "$0")" && pwd)/winlist.swift" -o "$WL" || { echo "ERROR: winlist build failed"; exit 1; }

echo "=== CELL: $LABEL ==="
echo "  shim-args : '${SHIM_ARGS}'   (needs the shim installed to take effect)"
echo "  steam-args: '${STEAM_ARGS}'"

shutdown_steam
rm -f "$S/.crash" "$WINEPREFIX/drive_c/shim.log" 2>/dev/null      # stale .crash => steam exits 1
find "$S" \( -name "SingletonLock" -o -name "SingletonCookie" -o -name "SingletonSocket" \) 2>/dev/null \
  | while read -r f; do echo "  purged (trap 1): $f"; rm -f "$f"; done

caffeinate -d -i -u -t $((WAIT + 120)) &                          # trap 2
CAF=$!
SHIM_ARGS="$SHIM_ARGS" SHIM_LOG=1 nohup "$WINE" "$S/steam.exe" -no-cef-sandbox $STEAM_ARGS \
  >"$OUT/stdout.txt" 2>&1 &
sleep "$WAIT"

echo "--- processes in this prefix ---"
for p in $(pgrep -f "steam" 2>/dev/null); do
  _owns "$p" && echo "  pid=$p $(ps -o comm= -p "$p" 2>/dev/null | sed 's|.*/||')  cpu=$(ps -o %cpu= -p "$p" 2>/dev/null | tr -d ' ')"
done
n=0; for p in $(pgrep -f "[-]-type=gpu-process" 2>/dev/null); do _owns "$p" && n=$((n+1)); done
echo "--- gpu-process children in this prefix: $n  (0 = in-process mode took effect) ---"
echo "--- gpu-process crashes this launch ---"
grep -c "GPU process has crashed" "$S/logs/cef_log.txt" 2>/dev/null || echo 0
echo "--- switches on the real webhelper cmdline (proves the flag survived steam.exe) ---"
ps auxww 2>/dev/null | grep "[s]teamwebhelper" | head -1 | tr ' ' '\n' \
  | grep -E "^--(use-angle|single-process|in-process-gpu|disable-gpu)" | sort -u | tr '\n' ' '; echo

echo "--- instrument validation (trap 2) ---"
GID=$("$WL" 2>/dev/null | grep -iE "owner=(Firefox|Safari|Claude|DuckDuckGo|Terminal) " | head -1 | sed -E 's/^id=([0-9]+).*/\1/')
BLIND=1
if [ -n "${GID:-}" ]; then
  screencapture -x -o -l "$GID" "$OUT/known-good.png" 2>/dev/null
  [ -s "$OUT/known-good.png" ] && { BLIND=0; echo "  known-good window captured ($(stat -f%z "$OUT/known-good.png") B) — instrument OK"; }
fi
[ "$BLIND" = 1 ] && echo "  ⚠ known-good capture FAILED (display asleep/locked?) — any black reading below is VOID"

echo "--- steam windows ---"
"$WL" 2>/dev/null | grep -iE "owner=(wine|steam)" | tee "$OUT/windows.txt"
"$WL" 2>/dev/null | grep -iE "owner=(wine|steam)" | while read -r line; do
  id=$(echo "$line" | sed -E 's/^id=([0-9]+).*/\1/')
  screencapture -x -o -l "$id" "$OUT/win-$id.png" 2>/dev/null
  if [ -s "$OUT/win-$id.png" ]; then
    sz=$(stat -f%z "$OUT/win-$id.png")
    verdict="RENDERED"; [ "$sz" -lt 120000 ] && verdict="black/near-empty"
    [ "$BLIND" = 1 ] && verdict="VOID (instrument blind)"
    echo "  win-$id.png  $sz B  -> $verdict"
  fi
done
echo "    (calibration 2026-08-28: black 15–41 KB · rendered 0.7–2.0 MB. A big capture is NOT a"
echo "     pass — open it and look for GLYPHS; in-process-GPU modes render art with no text.)"

kill "$CAF" 2>/dev/null
[ "$KEEP" = 1 ] || shutdown_steam
echo "=== cell done: $OUT ==="
