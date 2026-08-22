#!/bin/bash
# Cities: Skylines II — free stack (Wine 11 + DXVK). MoltenVK device-loss recovery + input fix.
export WINE="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin/wine"
export WINEPREFIX="$HOME/cs2-mac/prefix"
export PATH="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin:$PATH"
export WINEESYNC=1 ROSETTA_ADVERTISE_AVX=1 WINEDEBUG=-all
# MoltenVK: try to recover from GPU device loss instead of crashing; ease Metal pressure
export MVK_CONFIG_RESUME_LOST_DEVICE=1
export MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1
export MVK_CONFIG_LOG_LEVEL=0
export DXVK_CONFIG_FILE="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II/dxvk.conf"
export SteamAppId=949230 SteamGameId=949230 SteamOverlayGameId=949230
export WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d;winemenubuilder.exe=d"
STEAM="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
GDIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"
CL="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs/connection_log.txt"
PLOG="$WINEPREFIX/drive_c/users/$WINEUSER/AppData/LocalLow/Colossal Order/Cities Skylines II/Player.log"
echo "949230" > "$GDIR/steam_appid.txt"
if ! pgrep -f "cs2-mac/prefix.*steam.exe" >/dev/null 2>&1; then
  echo "Starting Steam..."; nohup "$WINE" "$STEAM" -no-cef-sandbox -silent >/dev/null 2>&1 &
fi
echo "Waiting for Steam login..."
for i in $(seq 1 25); do grep -qE "\[U:1:[1-9][0-9]+\]" <(tail -3 "$CL" 2>/dev/null) && break; sleep 3; done
echo "Steam logged in. Waiting 40s for license sync..."; sleep 40
echo "Launching Cities: Skylines II..."
rm -f "$PLOG"
"$WINE" explorer /desktop=CS2,1600x1000 "$GDIR/Cities2.exe"
