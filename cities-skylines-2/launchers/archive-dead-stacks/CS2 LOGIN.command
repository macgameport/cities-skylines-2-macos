#!/bin/bash
# Steam login. Disable dcomp so Chromium presents the swapchain DIRECTLY (DXVK shows it).
export WINE="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin/wine"
export WINEPREFIX="$HOME/cs2-mac/prefix"
export PATH="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin:$PATH"
export WINEDEBUG=-all WINEESYNC=1 MVK_CONFIG_LOG_LEVEL=0
# Disable DirectComposition -> Chromium falls back to direct swapchain present (visible via DXVK)
export WINEDLLOVERRIDES="dcomp=;winemenubuilder.exe=d"
STEAMEXE="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
echo "Steam login (dcomp disabled -> direct DXVK present). Login should be VISIBLE now."
n=0
while [ $n -lt 3 ]; do
  "$WINE" "$STEAMEXE" -no-cef-sandbox
  [ $? -eq 42 ] || break
  n=$((n+1)); sleep 2
done
