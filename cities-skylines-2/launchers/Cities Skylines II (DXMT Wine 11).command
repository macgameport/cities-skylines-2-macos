#!/bin/bash
# Thin wrapper for the DEFAULT stack (Wine 11 + DXMT). The real launcher lives at
# ~/cs2-patch/launch-cs2-dxmt11.sh because macOS TCC blocks app-bundle execution of scripts inside
# ~/Documents ("Operation not permitted") — the .app shortcut could not run it from here.
# Edit ~/cs2-patch/launch-cs2-dxmt11.sh, not this file.
# (A Wine 10 + D3DMetal sibling existed until 2026-11-09.)
exec bash "$HOME/cs2-patch/launch-cs2-dxmt11.sh" "$@"
