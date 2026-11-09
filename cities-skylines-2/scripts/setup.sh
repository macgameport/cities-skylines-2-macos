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
#   bash scripts/setup.sh --hide-mod-badges   # opt in to the mod badge patch (INSTALL.md)
#   bash scripts/setup.sh --show-mod-badges   # opt out again
#   bash scripts/setup.sh --yes        # do not stop to ask when this Mac is outside what has been tested
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
ASSUME_YES=0
BADGES=""
DEST="${CS2_PATCH_DIR:-$HOME/cs2-patch}"

need_value() {   # <option> [<value> ...]: an option that takes a value must be given a non-empty one
  if [ $# -lt 2 ] || [ -z "$2" ]; then echo "$1 needs a value"; exit 2; fi
}
while [ $# -gt 0 ]; do
  case "$1" in
    --check)   CHECK_ONLY=1; shift ;;
    --yes)     ASSUME_YES=1; shift ;;
    --stack)   need_value "$@"; STACK="$2"; shift 2 ;;
    --dest)    need_value "$@"; DEST="$2"; shift 2 ;;
    --hide-mod-badges|--show-mod-badges)
      _b="${1#--}"; _b="${_b%-mod-badges}"
      [ -z "$BADGES" ] || [ "$BADGES" = "$_b" ] || { echo "--hide-mod-badges and --show-mod-badges cannot both be given"; exit 2; }
      BADGES="$_b"; shift ;;
    -h|--help) sed -n '2,/^set -u$/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)"; exit 2 ;;
  esac
done

case "$STACK" in
  dxmt11|wine11)   LAUNCHER_SRC="$REPO/launchers/launch-cs2-dxmt11.sh"; WRAPPERS="CS2dxmt11.app CS2.app" ;;
  d3dmetal|wine10) LAUNCHER_SRC="$REPO/launchers/launch-cs2.sh";        WRAPPERS="S734M.app CS2.app" ;;
  *) echo "unknown --stack '$STACK' (use dxmt11 or d3dmetal)"; exit 2 ;;
esac

ok=0; bad=0; cautions=0; problems=0
say()  { printf "  %-52s %s\n" "$1" "$2"; }
good() { say "$1" "OK";   ok=$((ok+1)); }
fail() { say "$1" "MISSING"; echo "      -> $2"; bad=$((bad+1)); }
# a CAUTION is not a failure: this Mac is outside what has been tested, and the player may go on
caution() { say "$1" "CAUTION"; echo "      -> $2"; cautions=$((cautions+1)); }

echo "=== Cities: Skylines II on macOS — setup ($STACK) ==="
echo "repo: $REPO"
echo
echo "Preflight:"

# --- this Mac, against what has been tested (the root README.md, "Compatibility")
[ "$(uname -s)" = "Darwin" ] || { echo "  This only runs on macOS."; exit 1; }
# sysctl, not uname -m: in a shell that itself runs under Rosetta, uname says x86_64 on Apple Silicon
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; then
  good "Apple Silicon"
  if arch -x86_64 /usr/bin/true 2>/dev/null; then good "Rosetta 2"
  else fail "Rosetta 2" "nothing here runs without it. Install it:  softwareupdate --install-rosetta --agree-to-license"; fi
else
  caution "Apple Silicon" "an Intel Mac. Not supported: nothing here has been run on one."
fi
OSV="$(sw_vers -productVersion 2>/dev/null)"; OSMAJ="${OSV%%.*}"
case "$OSMAJ" in
  26|27) say "macOS $OSV" "OK (tested)"; ok=$((ok+1)) ;;
  ''|*[!0-9]*) caution "macOS version" "it could not be read, so this Mac cannot be compared with what has been tested." ;;
  *) if [ "$OSMAJ" -ge 28 ]; then
       caution "macOS $OSV" "newer than anything this has been run on. Apple has said macOS 27 is the last release with general Rosetta support."
     elif [ "$OSMAJ" -ge 14 ]; then
       caution "macOS $OSV" "older than anything this has been run on. The engine's graphics library is built for macOS 26 and may not load."
     else
       caution "macOS $OSV" "below the minimum of DXMT, the graphics layer (macOS 14)."
     fi ;;
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
else fail "Wine wrapper" "INSTALL.md step 1 — install the Porting Kit Wine 11 + DXMT wrapper, or set CS2_WRAPPER=/path/to/Wrapper.app"; fi

PREFIX="${WRAPPER:-}/Contents/SharedSupport/prefix"
GDIR="$PREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"

# --- wine binary
if [ -n "$WRAPPER" ] && [ -x "$WRAPPER/Contents/SharedSupport/wine/bin/wine64" ]; then
  good "wine64 in the wrapper ($("$WRAPPER/Contents/SharedSupport/wine/bin/wine64" --version 2>/dev/null))"
else fail "wine64 in the wrapper" "the wrapper looks incomplete — reinstall the engine"; fi

# --- steam + game
if [ -n "$WRAPPER" ] && [ -f "$PREFIX/drive_c/Program Files (x86)/Steam/steam.exe" ]; then good "Steam inside the wrapper"
else fail "Steam inside the wrapper" "INSTALL.md step 2 — install Steam into the wrapper's prefix"; fi
if [ -n "$WRAPPER" ] && [ -f "$GDIR/Cities2.exe" ]; then good "Cities: Skylines II installed"
else fail "Cities: Skylines II installed" "INSTALL.md step 3 — install the game via Steam inside the wrapper"; fi

# --- python3 that really runs (Apple's stub answers to the name before the Command Line Tools are installed)
if python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 8))' >/dev/null 2>&1; then
  good "python3 (patches + icon extraction)"
else fail "python3, version 3.8 or newer" "install Apple's Command Line Tools:  xcode-select --install"; fi

echo
if [ "$bad" -gt 0 ]; then
  echo "$bad prerequisite(s) missing — fix the ones marked above, then re-run."
  echo "Full walkthrough: $REPO/INSTALL.md"
  exit 1
fi
echo "All $ok checks passed."
if [ "$cautions" -gt 0 ]; then
  echo
  echo "$cautions caution(s): this Mac is outside what this project has been tested on (README.md, \"Compatibility\")."
  echo "Setup can go on from here. It changes only what INSTALL.md names, and INSTALL.md's Uninstall section undoes it."
  echo "The game may still not start on this Mac. Either way, a note in the project's Discussions helps the next person."
fi
[ "$CHECK_ONLY" = 1 ] && { echo "(--check: stopping before making changes)"; exit 0; }
if [ "$cautions" -gt 0 ] && [ "$ASSUME_YES" = 0 ] && [ -t 0 ]; then
  printf 'Press Return to continue, or Control-C to stop. (--yes skips this question.) '
  read -r _ || true
fi

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
cp "$REPO/scripts/cs2-display-profile.sh" "$DEST/" 2>/dev/null && echo "  cs2-display-profile.sh (home/mobile display profiles)"
mkdir -p "$DEST/patches" && cp "$REPO"/patches/*.py "$DEST/patches/" 2>/dev/null && \
  echo "  patches:   $(ls "$DEST/patches"/*.py 2>/dev/null | wc -l | tr -d ' ') scripts"
# the two Python libraries the patch scripts use ship with them (patches/_vendor/README.md). Remove, then copy:
# cp -R onto an existing folder merges, and would keep a file a newer version no longer has.
rm -rf "$DEST/patches/_vendor" && cp -R "$REPO/patches/_vendor" "$DEST/patches/_vendor" \
  && echo "  patches/_vendor (dnfile and pefile, which the patch scripts use)"

# --- the mod badge patch is opt-in. It edits the game's Game.dll to hide a keybinding badge, which is a
#     preference and not a compatibility fix (INSTALL.md, "Mod keybinding badges"). The launcher applies it
#     wherever the installed copy exists, so the installed copy is the switch; the marker records that the
#     player asked, and sits inside patches/ so that it travels with that folder.
BADGE_SRC="$REPO/scripts/patch-modconflict-badge.py"
BADGE_DST="$DEST/patch-modconflict-badge.py"
BADGE_MARK="$DEST/patches/.mod-badges-on"
# the script edits this wrapper's Game.dll and no other, whatever CS2_WRAPPER says
BADGE_DLL_DIR="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II/Cities2_Data/Managed"
badge_has_run() { ls "$BADGE_DLL_DIR"/Game.dll.bak-modconflict-* >/dev/null 2>&1; }
badge_install() { cp "$BADGE_SRC" "$BADGE_DST" && : > "$BADGE_MARK"; }
case "$BADGES" in
  hide)
    badge_install && echo "  mod badge patch: on. It takes effect at the next launch; --show-mod-badges turns it off"
    [ "$WRAPPER" = "$HOME/Applications/CS2dxmt11.app" ] \
      || echo "  !! the badge patch only knows ~/Applications/CS2dxmt11.app. Your wrapper is $WRAPPER, so it will not find your game."
    ;;
  show)
    rm -f "$BADGE_DST" "$BADGE_MARK"
    echo "  mod badge patch: off. If it has already edited Game.dll, put the file back with Steam: right-click the"
    echo "     game, Properties, Installed Files, Verify integrity of game files. A Game.dll.bak-modconflict-* file"
    echo "     beside Game.dll is the right one only if it was made on the game build that is installed now."
    ;;
  *)
    if [ -f "$BADGE_MARK" ]; then
      badge_install && echo "  mod badge patch: on (--show-mod-badges turns it off)"
    elif [ -f "$BADGE_DST" ] && badge_has_run; then      # it ran here before the patch became opt-in
      badge_install && echo "  mod badge patch: on, as before (--show-mod-badges turns it off)"
    elif [ -f "$BADGE_DST" ]; then                        # copied by an older setup, never ran
      rm -f "$BADGE_DST"
      echo "  mod badge patch: off (it has never run here); --hide-mod-badges turns it on"
    fi
    ;;
esac
chmod +x "$DEST"/*.sh 2>/dev/null

echo
echo "Applying binary patches (idempotent — safe to re-run after every game update):"
if CS2_GAME_DIR="$GDIR" bash "$DEST/repatch.sh" "$STACK"; then
  echo "  every patch script finished without error."
else
  problems=$((problems+1))
  echo "  !! not every patch is in place: the FAILED line above names the ones that are not. They refuse to write"
  echo "     rather than corrupt a file. If the game has just updated, a pattern may have moved: update this"
  echo "     checkout (git pull), run setup again, and see INSTALL.md, 'After a game update'."
fi

echo
echo "Building the double-clickable app:"
if ! bash "$REPO/scripts/make-shortcut.sh" --stack "$STACK" --launcher "$DEST/$(basename "$LAUNCHER_SRC")" \
  --game "$GDIR/Cities2.exe"; then
  problems=$((problems+1))
  echo "  !! the app was not built: the lines above say why."
fi

if [ "$problems" -gt 0 ]; then
  echo
  echo "=== setup finished with $problems problem(s): see the lines marked !! above ==="
  exit 1
fi

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
