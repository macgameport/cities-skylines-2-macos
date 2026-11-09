#!/bin/bash
export WINE="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin/wine"
export WINEPREFIX="$HOME/cs2-mac/prefix"
export PATH="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin:$PATH"
export WINEDEBUG=-all WINEESYNC=1 MVK_CONFIG_LOG_LEVEL=0
export WINEDLLOVERRIDES="winemenubuilder.exe=d"
STEAMEXE="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
echo "Steam login — CEF via wined3d-on-Vulkan (builtin d3d11). Login should render."
n=0; while [ $n -lt 3 ]; do "$WINE" "$STEAMEXE" -no-cef-sandbox; [ $? -eq 42 ] || break; n=$((n+1)); sleep 2; done
