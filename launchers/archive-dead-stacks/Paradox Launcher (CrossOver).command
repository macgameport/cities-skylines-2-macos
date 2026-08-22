#!/bin/bash
# Idea 0 test rig: open the FULL Paradox Launcher standalone in the CrossOver "Steam" bottle,
# UI visible, GAME NOT running. Goal: let the launcher's CPatch (Go daemon, raw syscalls — NOT
# .NET FileStream) download the 4 subscribed CS2 mods, sidestepping the handle-0 wall that kills
# the in-game PdxSdk downloader. See MODS-TESTING.md Idea 0.
#
# After it opens: log into the Paradox account if prompted, go to the Mods section for
# Cities: Skylines II, and start the mod downloads. Watch bytes with:  scripts/watch-mods.sh
set -u

CXAPP="$HOME/Applications/CrossOver.app"
CXBIN="$CXAPP/Contents/SharedSupport/CrossOver/bin"
BOTTLE_NAME="Steam"
BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE_NAME"
BOOT="$BOTTLE/drive_c/Program Files/Paradox Interactive/launcher/bootstrapper-v2.exe"

# Safety: the launcher and a running game fight over the same mod files / Steam session.
if pgrep -fi "Cities2.exe" >/dev/null 2>&1; then
  echo "⚠️  Cities2.exe is running. Quit the game first (the launcher pauses mod patches while the game runs)."
  echo "    kill:  pkill -9 -f Cities2.exe"
  exit 1
fi
if pgrep -fi "Paradox Launcher.exe" >/dev/null 2>&1; then
  echo "⚠️  A Paradox Launcher is already running. Bring its window forward, or kill it first:"
  echo "    pkill -9 -f 'Paradox Launcher.exe'; pkill -9 -f bootstrapper-v2.exe"
  exit 1
fi

[ -f "$BOOT" ] || { echo "❌ bootstrapper not found: $BOOT"; exit 1; }

echo "Opening Paradox Launcher in CrossOver bottle '$BOTTLE_NAME' (game NOT running)…"
echo "→ Log in if asked, open Mods for Cities: Skylines II, start the 4 mod downloads."
echo "→ In another terminal, watch progress:  '$HOME/Documents/github/cs2/scripts/watch-mods.sh'"
echo

# cxstart sets up the full CrossOver/Wine env (CX_BOTTLE, DYLD, D3DMetal) and runs the exe.
exec "$CXBIN/cxstart" --bottle "$BOTTLE_NAME" "$BOOT"
