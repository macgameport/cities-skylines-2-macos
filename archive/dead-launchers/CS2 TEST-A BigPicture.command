#!/bin/bash
export WINE="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin/wine"
export WINEPREFIX="$HOME/cs2-mac/prefix"
export PATH="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin:$PATH"
export WINEDEBUG=-all WINEESYNC=1 ROSETTA_ADVERTISE_AVX=1 MVK_CONFIG_LOG_LEVEL=0
export WINEDLLOVERRIDES="winemenubuilder.exe=d"
STEAMEXE="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
echo "TEST A: Steam Big Picture mode. Watch for a fullscreen Steam UI to log in."
while :; do "$WINE" "$STEAMEXE" -no-cef-sandbox -gamepadui -fulldesktopres; [ $? -eq 42 ] || break; sleep 2; done
