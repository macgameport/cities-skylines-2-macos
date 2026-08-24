#!/bin/bash
# CS2 launcher — Wine 11 + DXMT wrapper. The recipe, in order:
#   patches -> Steam up + logged in -> licence sync -> Cities2.exe DIRECTLY -> graceful shutdown.
#
# Steam's "Play" button does NOT work: it routes via the Paradox Launcher and exits before Unity
# initialises. Launching the exe directly is the whole trick.
#
# Install it with `bash scripts/setup.sh` (copies this, repatch.sh and patches/ into ~/cs2-patch/,
# because macOS TCC blocks .app bundles from executing scripts inside ~/Documents).
#
# Overrides, all optional:
#   CS2_WRAPPER=/path/to/Wrapper.app   the Wineskin/Porting Kit bundle (auto-detected otherwise)
#   CS2_PATCH_DIR=~/cs2-patch          where repatch.sh + patches/ live
#   CS2_QUIET=1                        no terminal expected: milestones become macOS
#                                      notifications, failures become alert dialogs
#   WINEDEBUG=...                      respected if set (scripts/diag-launch-dxmt11.sh uses it)
set -u

# ---------------------------------------------------------------- locate the wrapper
find_wrapper() {
  [ -n "${CS2_WRAPPER:-}" ] && { echo "$CS2_WRAPPER"; return; }
  for cand in "$HOME/Applications/CS2dxmt11.app" "$HOME/Applications/CS2.app" \
              "/Applications/CS2dxmt11.app"; do
    [ -d "$cand/Contents/SharedSupport/prefix" ] && { echo "$cand"; return; }
  done
  # last resort: any wrapper in ~/Applications that has the game installed inside it
  for cand in "$HOME/Applications"/*.app; do
    [ -f "$cand/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II/Cities2.exe" ] \
      && { echo "$cand"; return; }
  done
  echo ""
}

APP="$(find_wrapper)"
QUIET="${CS2_QUIET:-0}"

die() {   # fatal: alert dialog when quiet, pause-on-keypress otherwise
  echo "ERROR: $1"
  if [ "$QUIET" = "1" ]; then
    osascript -e "display alert \"Cities: Skylines II\" message \"$1\" as critical" >/dev/null 2>&1
  else
    echo "(press any key to close)"; read -n1 -r
  fi
  exit 1
}
note() {  # milestone: notification when quiet, plain echo otherwise
  echo "$1"
  [ "$QUIET" = "1" ] && osascript -e "display notification \"$1\" with title \"Cities: Skylines II\"" >/dev/null 2>&1
  return 0
}

[ -n "$APP" ] || die "No Wine wrapper found. Install the Porting Kit Wine 11 + DXMT wrapper (see INSTALL.md), or set CS2_WRAPPER=/path/to/Wrapper.app"

SS="$APP/Contents/SharedSupport"
APPTAG="$(basename "$APP")"          # e.g. CS2dxmt11.app — used to scope pgrep to THIS wrapper
export WINE="$SS/wine/bin/wine64"
export WINEPREFIX="$SS/prefix"
export PATH="$SS/wine/bin:$PATH"
export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"
export WINEESYNC=1 WINEMSYNC=1 WINEDEBUG="${WINEDEBUG:--all}"

# CS2_HUD=1 — Metal's performance HUD (FPS, frame time, GPU time), plus DXMT's own stat lines
# (commit/sync/encode/render breakdown), since DXMT publishes into the same _CADeveloperHUDProperties
# overlay. This is the way to get a comparable frame-rate number on this stack; the game has no
# usable built-in counter.
[ "${CS2_HUD:-0}" = "1" ] && export MTL_HUD_ENABLED=1 && echo "Metal HUD: on"
# CS2_METALFX=1 — EXPERIMENTAL. Renders through a MetalFX spatially-upscaled swapchain; the factor
# comes from d3d11.metalSpatialUpscaleFactor (default 2). Untested here — try it for performance,
# expect softer output, and turn it off if anything looks wrong.
if [ "${CS2_METALFX:-0}" = "1" ]; then
  export DXMT_METALFX_SPATIAL_SWAPCHAIN=1
  echo "MetalFX spatial upscaling: on (experimental)"
fi
export SteamAppId=949230 SteamGameId=949230 SteamOverlayGameId=949230
export WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d;winemenubuilder.exe=d"

STEAM="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
GDIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"
CL="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs/connection_log.txt"
PATCH_DIR="${CS2_PATCH_DIR:-$HOME/cs2-patch}"

[ -x "$WINE" ]            || die "Wine not found inside $APPTAG (expected $WINE). Is this the DXMT wrapper?"
[ -f "$STEAM" ]           || die "Steam is not installed inside $APPTAG. See INSTALL.md step 3."
[ -f "$GDIR/Cities2.exe" ] || die "Cities: Skylines II is not installed inside $APPTAG. Install it via Steam in the wrapper (INSTALL.md step 4)."

echo "Wrapper: $APPTAG"
echo "949230" > "$GDIR/steam_appid.txt"
echo "Engine: $("$WINE" --version 2>/dev/null)"

# 0) Ensure the binary patches are applied — a game update reverts them. All are idempotent and
#    refuse to write if the pattern moved, so re-running is always safe.
if [ -x "$PATCH_DIR/repatch.sh" ]; then
  CS2_GAME_DIR="$GDIR" bash "$PATCH_DIR/repatch.sh" dxmt11 >/dev/null 2>&1 && echo "Patches ensured (10, dxmt11 target)." \
    || echo "WARNING: repatch reported an issue — continuing (patches are idempotent)."
else
  echo "NOTE: no repatch.sh in $PATCH_DIR — skipping the patch check. Run scripts/setup.sh to install it."
fi

# 1) Steam up + FRESHLY logged in — scoped to THIS wrapper. Two wrappers can each have a Steam
#    resident, and `pgrep steamwebhelper` cannot tell them apart: webhelper children carry
#    Windows-style command lines. The PARENT steam.exe carries the unix path of its wrapper, so
#    scope on that. The fresh-login check reads THIS prefix's connection log.
fresh_login() { tail -n +$((BEFORE+1)) "$CL" 2>/dev/null | grep -qE "LogOnResponse.*'OK'|\[Logged On.*\[U:1:[1-9]"; }
BEFORE=$(wc -l < "$CL" 2>/dev/null || echo 0)
STARTED_STEAM=0
if pgrep -f "$APPTAG.*steam.exe" >/dev/null 2>&1; then
  note "Steam already running — reusing session."
  tail -20 "$CL" 2>/dev/null | grep -qE "\[Logged On.*\[U:1:[1-9]|LogOnResponse.*'OK'" \
    || die "Steam is running but not logged in. Sign in in the Steam window, then relaunch."
else
  note "Starting Steam…"
  # a stale 0-byte .crash marker makes steam.exe exit 1 and never start — clear it first
  rm -f "$WINEPREFIX/drive_c/Program Files (x86)/Steam/.crash" 2>/dev/null
  nohup "$WINE" "$STEAM" -silent -no-cef-sandbox >/dev/null 2>&1 &
  STARTED_STEAM=1
  ok=0
  for i in $(seq 1 40); do
    if fresh_login && pgrep -f "steamwebhelper.exe" >/dev/null 2>&1; then ok=1; break; fi
    sleep 3
  done
  [ "$ok" = 1 ] || die "Steam did not auto-login (token expired, or it crashed). Open Steam inside the wrapper, sign in until the library loads, then relaunch. If Steam won't start at all, reboot — a kill -9 can wedge it."
fi

# 2) Licence sync — ONLY needed when we just started Steam. Launching Cities2.exe too soon after a
#    fresh login means SteamAPI cannot verify ownership -> platform-service failure -> NRE flood
#    -> no main menu. If Steam was already up, licences are long since synced, so skip the wait.
if [ "$STARTED_STEAM" = 1 ]; then
  # 45s is conservative but it is the empirically proven margin.
  note "Signed in — verifying licence (about 45 seconds)…"
  for _s in 30 15; do
    sleep 15
    note "Almost ready — ${_s}s…"
  done
  sleep 15
else
  echo "Steam already warm — skipping the 45s licence wait."
fi

# 3) Launch the game DIRECTLY — NOT via `explorer /desktop` (that eats WSAD: the keyboard goes to
#    the virtual-desktop container).
#    ⚠ In the game's Options, set Display Mode = FULLSCREEN WINDOW. It is immune to the alt-tab
#    presentation freeze (dxmt#206); exclusive Fullscreen presents into a hidden swapchain after
#    you switch away, and the screen then only updates once per alt-tab.
note "Launching Cities: Skylines II (Wine 11 + DXMT)…"
"$WINE" "$GDIR/Cities2.exe"
GAME_RC=$?

# 4) Graceful shutdown, scoped to THIS wrapper. NEVER kill -9 — that leaves a 0-byte .crash marker
#    which makes the NEXT launch exit 1. `steam -shutdown` can itself die with a floating point
#    exception, so it is not sufficient on its own.
echo "Game exited (rc=$GAME_RC). Shutting down Steam cleanly…"
"$WINE" "$STEAM" -shutdown >/dev/null 2>&1 || echo "  (steam -shutdown failed; falling back)"
for i in $(seq 1 20); do
  pgrep -f "$APPTAG.*steam.exe" >/dev/null 2>&1 || break
  sleep 1
done
# Fallback: end the wine session for THIS prefix only. WINEPREFIX must be exported or wineserver
# targets the default prefix and silently does nothing.
if pgrep -f "$APPTAG.*steam.exe" >/dev/null 2>&1; then
  echo "  Steam still resident — ending the wine session for this prefix."
  WINEPREFIX="$WINEPREFIX" "$SS/wine/bin/wineserver" -k >/dev/null 2>&1
  for i in $(seq 1 10); do
    pgrep -f "$APPTAG.*steam.exe" >/dev/null 2>&1 || break
    sleep 1
  done
fi
# wineserver exits on its own once its clients are gone; nudge it only if it lingers
if pgrep -f "$APPTAG.*wineserver" >/dev/null 2>&1; then
  sleep 2
  WINEPREFIX="$WINEPREFIX" "$SS/wine/bin/wineserver" -k >/dev/null 2>&1
fi
_left=$(pgrep -f "$APPTAG" | wc -l | tr -d ' ')
echo "  Residual $APPTAG processes after shutdown: ${_left:-0}"
note "Cities: Skylines II closed."
exit 0
