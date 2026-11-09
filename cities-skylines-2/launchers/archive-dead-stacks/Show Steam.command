#!/bin/bash
# Screenshot Steam's (black) UI via its CEF debug channel and open it — so you can SEE Steam
# (library, downloads, dialogs) even though the window renders black.
CDP="$HOME/cs2-mac/cdpenv/bin/python $HOME/cs2-mac/cdp.py"
OUT="$HOME/cs2-mac/steam-view.png"
if ! curl -s --max-time 2 http://localhost:8080/json >/dev/null 2>&1; then
  echo "Steam's debug channel isn't up. Launch the game (or Steam) first, then re-run."
  echo "Press any key."; read -n1; exit 0
fi
$CDP screenshot "$OUT" 2>/dev/null && open "$OUT" && echo "Opened a snapshot of Steam's current screen: $OUT"
echo "(Re-run to refresh. To click something in there, tell Claude what you see and it can drive it via CDP.)"
echo "Press any key."; read -n1
