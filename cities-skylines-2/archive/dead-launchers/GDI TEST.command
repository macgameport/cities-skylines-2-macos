#!/bin/bash
# Does Wine 11 render a plain GDI window on macOS 26? White Notepad = yes, black = no.
export WINE="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin/wine"
export WINEPREFIX="$HOME/cs2-mac/prefix"
export PATH="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin:$PATH"
export WINEDEBUG=-all
echo "A Notepad window should open. WHITE with a menu bar = GDI works. Black = GDI broken."
"$WINE" notepad
