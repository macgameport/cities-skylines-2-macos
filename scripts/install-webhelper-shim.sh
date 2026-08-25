#!/bin/bash
# install-webhelper-shim.sh — make Steam's visible UI render on a stock-Wine + DXMT engine.
#
# WHY: Steam's CEF creates its GPU-process swapchain for an HWND owned by ANOTHER process.
# DXMT can't serve that (3Shain/dxmt#141, "cross-process swapchain not supported yet"), the
# GPU process fastfails 0xC0000409, and Chromium's software fallback dies on the same wall —
# so every Steam window is black. `--in-process-gpu` moves the GPU into the browser process,
# making the swapchain same-process: the path DXMT already handles for the game.
#
# WHY A SHIM: steam.exe FILTERS --in-process-gpu (and --disable-gpu) from its own command line
# (measured against logs/webhelper.txt child cmdlines), so the flag has to be injected at the
# webhelper itself. Steam has no -cef- switch for it either (its full set: -cef-disable-gpu,
# -cef-disable-gpu-sandbox, -cef-disable-sandbox, -cef-disable-seccomp-sandbox,
# -cef-force-accessibility, -cef-force-gpu).
#
# WHY PADDED: Steam verifies its install on startup and its bootstrap log says
# "Verifying file sizes only" — so the shim is zero-padded to the ORIGINAL's exact byte count
# and passes. An unpadded shim gets silently restored and Steam exits 42 (the failure that
# makes this look impossible). If Valve ever switches to hashes, this stops working.
#
# Usage:  bash scripts/install-webhelper-shim.sh [--revert] [--wrapper /path/to/Wrapper.app]
# Re-run after any Steam client update (the update restores the original webhelper).
set -u

APP="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
REVERT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --revert) REVERT=1 ;;
    --wrapper) shift; APP="$1" ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
  shift
done

S="$APP/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam"
CEF="$S/bin/cef/cef.win64"
SHIM_SRC="$(cd "$(dirname "$0")" && pwd)/steamwebhelper-shim.c"
[ -d "$CEF" ] || { echo "ERROR: no Steam CEF dir at $CEF"; exit 1; }
for _p in $(pgrep -f "steam" 2>/dev/null); do   # open-file attribution: cmdline can be Windows-style
  lsof -p "$_p" 2>/dev/null | grep -q "$APP/Contents/SharedSupport/prefix" && \
    { echo "ERROR: Steam is running in this wrapper — quit it first (steam.exe -shutdown; never kill -9)."; exit 1; }
done

if [ "$REVERT" = 1 ]; then
  [ -f "$CEF/steamwebhelper_real.exe" ] || { echo "nothing to revert (no steamwebhelper_real.exe)"; exit 0; }
  mv -f "$CEF/steamwebhelper_real.exe" "$CEF/steamwebhelper.exe"
  echo "reverted: original webhelper restored ($(stat -f%z "$CEF/steamwebhelper.exe") bytes)"
  exit 0
fi

if [ -f "$CEF/steamwebhelper_real.exe" ]; then
  echo "shim already installed (steamwebhelper_real.exe present). Re-run with --revert to undo."
  exit 0
fi

command -v x86_64-w64-mingw32-gcc >/dev/null || { echo "ERROR: mingw-w64 needed (brew install mingw-w64)"; exit 1; }
TARGET=$(stat -f%z "$CEF/steamwebhelper.exe") || exit 1
TMP=$(mktemp -d)
x86_64-w64-mingw32-gcc -O2 -mwindows -municode "$SHIM_SRC" -o "$TMP/shim.exe" || { echo "ERROR: build failed"; exit 1; }
CUR=$(stat -f%z "$TMP/shim.exe")
[ "$CUR" -le "$TARGET" ] || { echo "ERROR: shim ($CUR) larger than original ($TARGET) — cannot size-match"; exit 1; }
dd if=/dev/zero bs=1 count=$((TARGET - CUR)) >> "$TMP/shim.exe" 2>/dev/null
[ "$(stat -f%z "$TMP/shim.exe")" = "$TARGET" ] || { echo "ERROR: padding failed"; exit 1; }

mv "$CEF/steamwebhelper.exe" "$CEF/steamwebhelper_real.exe"
cp "$TMP/shim.exe" "$CEF/steamwebhelper.exe"
rm -rf "$TMP"
echo "installed: shim $(stat -f%z "$CEF/steamwebhelper.exe") bytes (size-matched to the original)"
echo "original kept as steamwebhelper_real.exe — revert with: bash $0 --revert"
