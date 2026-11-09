#!/bin/bash
export WINE="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin/wine"
export WINEPREFIX="$HOME/cs2-mac/prefix"
export PATH="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin:$PATH"
export WINEDEBUG=-all WINEESYNC=1 ROSETTA_ADVERTISE_AVX=1 MVK_CONFIG_LOG_LEVEL=0
export WINEDLLOVERRIDES="winemenubuilder.exe=d"
STEAMEXE="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
echo "TEST B: Steam in a desktop window, GPU compositing ON."
while :; do "$WINE" explorer /desktop=Steam,1600x900 "$STEAMEXE" -no-cef-sandbox; [ $? -eq 42 ] || break; sleep 2; done
