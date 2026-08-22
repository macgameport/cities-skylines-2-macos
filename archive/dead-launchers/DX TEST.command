#!/bin/bash
# DX11-via-DXVK presentation test. A MAGENTA window = Wine 11 can render the game.
export WINE="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin/wine"
export WINEPREFIX="$HOME/cs2-mac/prefix"
export PATH="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin:$PATH"
export WINEDEBUG=-all WINEESYNC=1 MVK_CONFIG_LOG_LEVEL=0
echo "A window should open. MAGENTA = success. Black = presentation still broken."
echo "Close the window (or this terminal) when done."
"$WINE" "$HOME/cs2-mac/dxtest.exe"
