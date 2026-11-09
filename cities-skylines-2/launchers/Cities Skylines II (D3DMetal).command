#!/bin/bash
# Thin wrapper. The real launcher lives at ~/cs2-patch/launch-cs2.sh because macOS TCC blocks
# app-bundle execution of scripts inside ~/Documents ("Operation not permitted") — the .app
# shortcut could not run it from here. Edit ~/cs2-patch/launch-cs2.sh, not this file.
exec bash "$HOME/cs2-patch/launch-cs2.sh" "$@"
