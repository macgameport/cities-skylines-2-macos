#!/bin/bash
# Direct-launch CS2 on the CrossOver "Steam" bottle, bypassing the Paradox Launcher PLAY button
# (which exits the game immediately — "exit code null", gotcha #10/#15). Steam must already be
# running + logged in (license long-synced). D3DMetal is CrossOver's builtin renderer — no DXVK/MVK env.
set -u
CX="$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"
export CX_ROOT="$CX" CX_BOTTLE="Steam" WINEDEBUG=-all
export SteamAppId=949230 SteamGameId=949230 SteamOverlayGameId=949230
export WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d;winemenubuilder.exe=d"
GDIR="$HOME/Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"
LL="$HOME/Library/Application Support/CrossOver/Bottles/Steam/drive_c/users/crossover/AppData/LocalLow/Colossal Order/Cities Skylines II"
echo 949230 > "$GDIR/steam_appid.txt"
rm -f "$LL/Player.log"
if ! pgrep -f 'steam.exe -silent' >/dev/null 2>&1; then
  echo "⚠️  Steam isn't running in the bottle — start it + log in first (license needs ~40s sync)."; exit 1
fi
cd "$GDIR"
echo "Launching Cities2.exe directly (native Fullscreen)…"
"$CX/bin/wine" "$GDIR/Cities2.exe"
