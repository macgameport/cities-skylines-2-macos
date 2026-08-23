#!/bin/bash
# setup.sh — install the launcher, apply the patches, and build the double-clickable app.
#
# Run this AFTER you have: the Wine 11 + DXMT wrapper installed, Steam installed inside it, and
# Cities: Skylines II downloaded inside that Steam. See INSTALL.md for those steps — they need a
# GUI and cannot be scripted.
#
#   bash scripts/setup.sh              # check, install, patch, build shortcut
#   bash scripts/setup.sh --check      # preflight only, change nothing
#   bash scripts/setup.sh --stack d3dmetal
#
# What it does:
#   1. verifies the wrapper, Steam and the game are where they should be
#   2. copies the launcher + repatch.sh + patches/ into ~/cs2-patch/   (macOS TCC blocks .app
#      bundles from executing scripts inside ~/Documents, so they cannot live in the repo)
#   3. applies the binary patches (idempotent; each refuses to write if the pattern moved)
#   4. builds "Cities Skylines II.app" in ~/Applications with the game's own icon
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
STACK="dxmt11"
CHECK_ONLY=0
DEST="${CS2_PATCH_DIR:-$HOME/cs2-patch}"

while [ $# -gt 0 ]; do
  case "$1" in
    --check)   CHECK_ONLY=1; shift ;;
    --stack)   STACK="${2:-}"; shift 2 ;;
    --dest)    DEST="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (try --help)"; exit 2 ;;
  esac
done

case "$STACK" in
  dxmt11|wine11)   LAUNCHER_SRC="$REPO/launchers/launch-cs2-dxmt11.sh"; WRAPPERS="CS2dxmt11.app CS2.app" ;;
  d3dmetal|wine10) LAUNCHER_SRC="$REPO/launchers/launch-cs2.sh";        WRAPPERS="S734M.app CS2.app" ;;
  *) echo "unknown --stack '$STACK' (use dxmt11 or d3dmetal)"; exit 2 ;;
esac

ok=0; bad=0
say()  { printf "  %-52s %s\n" "$1" "$2"; }
good() { say "$1" "OK";   ok=$((ok+1)); }
fail() { say "$1" "MISSING"; echo "      -> $2"; bad=$((bad+1)); }

echo "=== Cities: Skylines II on macOS — setup ($STACK) ==="
echo "repo: $REPO"
echo
echo "Preflight:"

# --- machine
[ "$(uname -s)" = "Darwin" ] || { echo "  This only runs on macOS."; exit 1; }
case "$(uname -m)" in
  arm64) good "Apple Silicon" ;;
  *)     say  "Apple Silicon" "NO — Intel is untested, continuing anyway" ;;
esac

# --- the wrapper
WRAPPER=""
if [ -n "${CS2_WRAPPER:-}" ]; then
  [ -d "$CS2_WRAPPER/Contents/SharedSupport/prefix" ] && WRAPPER="$CS2_WRAPPER"
else
  for w in $WRAPPERS; do
    [ -d "$HOME/Applications/$w/Contents/SharedSupport/prefix" ] && { WRAPPER="$HOME/Applications/$w"; break; }
  done
fi
if [ -n "$WRAPPER" ]; then good "Wine wrapper ($(basename "$WRAPPER"))"
else fail "Wine wrapper" "INSTALL.md step 2 — install the Porting Kit Wine 11 + DXMT wrapper, or set CS2_WRAPPER=/path/to/Wrapper.app"; fi

PREFIX="${WRAPPER:-}/Contents/SharedSupport/prefix"
GDIR="$PREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"

# --- wine binary
if [ -n "$WRAPPER" ] && [ -x "$WRAPPER/Contents/SharedSupport/wine/bin/wine64" ]; then
  good "wine64 in the wrapper ($("$WRAPPER/Contents/SharedSupport/wine/bin/wine64" --version 2>/dev/null))"
else fail "wine64 in the wrapper" "the wrapper looks incomplete — reinstall the engine"; fi

# --- steam + game
if [ -n "$WRAPPER" ] && [ -f "$PREFIX/drive_c/Program Files (x86)/Steam/steam.exe" ]; then good "Steam inside the wrapper"
else fail "Steam inside the wrapper" "INSTALL.md step 3 — install Steam into the wrapper's prefix"; fi
if [ -n "$WRAPPER" ] && [ -f "$GDIR/Cities2.exe" ]; then good "Cities: Skylines II installed"
else fail "Cities: Skylines II installed" "INSTALL.md step 4 — install the game via Steam inside the wrapper"; fi

# --- optional niceties
command -v python3 >/dev/null 2>&1 && good "python3 (patches + icon extraction)" \
  || fail "python3" "install Xcode Command Line Tools:  xcode-select --install"

echo
if [ "$bad" -gt 0 ]; then
  echo "$bad prerequisite(s) missing — fix the ones marked above, then re-run."
  echo "Full walkthrough: $REPO/INSTALL.md"
  exit 1
fi
echo "All $ok checks passed."
[ "$CHECK_ONLY" = 1 ] && { echo "(--check: stopping before making changes)"; exit 0; }

# ---------------------------------------------------------------- install
echo
echo "Installing launcher + patches into $DEST"
mkdir -p "$DEST"
_lname="$(basename "$LAUNCHER_SRC")"
if [ -f "$DEST/$_lname" ] && ! cmp -s "$LAUNCHER_SRC" "$DEST/$_lname"; then
  cp "$DEST/$_lname" "$DEST/$_lname.bak" && echo "  backed up existing launcher -> $_lname.bak"
fi
cp "$LAUNCHER_SRC" "$DEST/" && echo "  launcher:  $_lname"
cp "$REPO/repatch.sh" "$DEST/" && echo "  repatch.sh"
mkdir -p "$DEST/patches" && cp "$REPO"/patches/*.py "$DEST/patches/" 2>/dev/null && \
  echo "  patches:   $(ls "$DEST/patches"/*.py 2>/dev/null | wc -l | tr -d ' ') scripts"
chmod +x "$DEST"/*.sh 2>/dev/null

echo
echo "Applying binary patches (idempotent — safe to re-run after every game update):"
if CS2_GAME_DIR="$GDIR" bash "$DEST/repatch.sh" "$STACK"; then
  echo "  patches applied."
else
  echo "  !! repatch reported a problem. If the game updated recently a pattern may have moved —"
  echo "     see docs/patch-inventory.md. The patches refuse to write rather than corrupt a file."
fi

echo
echo "Building the double-clickable app:"
bash "$REPO/scripts/make-shortcut.sh" --stack "$STACK" --launcher "$DEST/$(basename "$LAUNCHER_SRC")" \
  --game "$GDIR/Cities2.exe"

cat << DONE

=== setup complete ===

Play:      double-click  ~/Applications/Cities Skylines II.app
Log:       ~/Library/Logs/cs2-launcher.log

First run: Steam signs in inside the wrapper, waits ~45s for the licence to sync, then the game
           starts. That wait only happens when Steam was not already running.

In-game:   Options -> Graphics -> Display Mode -> FULLSCREEN WINDOW.
           Exclusive Fullscreen has an alt-tab presentation bug on this stack (dxmt#206) —
           borderless looks identical and is immune.

After a game update: re-run  bash scripts/setup.sh  (updates reset the patched DLLs).
Troubleshooting: INSTALL.md, then GOTCHAS.md.
DONE
