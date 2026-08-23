#!/bin/bash
# CS2 launcher — Kegworks/WineskinNavy "Steambuild Metal" wrapper
#   Engine: Wine 10.0 Sikarugir + D3DMetal v2.1 (the free CrossOver-equivalent D3DMetal path)
# Recipe: patches -> Steam login -> licence sync -> Cities2.exe DIRECTLY -> graceful shutdown.
# Steam's "Play" button routes via the Paradox Launcher / -applaunch and does NOT work; this does.
#
# CS2_QUIET=1  -> no terminal output expected (the .app sets this): milestones become macOS
#                 notifications, failures become alert dialogs, nothing blocks on a keypress.
#
# Overrides: CS2_WRAPPER=/path/to/Wrapper.app, CS2_PATCH_DIR=~/cs2-patch, CS2_QUIET=1
set -u

find_wrapper() {
  [ -n "${CS2_WRAPPER:-}" ] && { echo "$CS2_WRAPPER"; return; }
  for cand in "$HOME/Applications/S734M.app" "$HOME/Applications/CS2.app"; do
    [ -d "$cand/Contents/SharedSupport/prefix" ] && { echo "$cand"; return; }
  done
  for cand in "$HOME/Applications"/*.app; do
    [ -f "$cand/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II/Cities2.exe" ] \
      && { echo "$cand"; return; }
  done
  echo ""
}
APP="$(find_wrapper)"
if [ -z "$APP" ]; then
  echo "ERROR: no Wine wrapper found. Install the Wine 10 + D3DMetal wrapper (see INSTALL.md) or set CS2_WRAPPER=/path/to/Wrapper.app"
  [ "${CS2_QUIET:-0}" = "1" ] && osascript -e 'display alert "Cities: Skylines II" message "No Wine wrapper found — see INSTALL.md" as critical' >/dev/null 2>&1
  exit 1
fi
APPTAG="$(basename "$APP")"
SS="$APP/Contents/SharedSupport"
export WINE="$SS/wine/bin/wine64"
export WINEPREFIX="$SS/prefix"
export PATH="$SS/wine/bin:$PATH"
export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"
export WINEESYNC=1 WINEMSYNC=1 D3DMETAL=1 D3DMETAL_FORCE=1 WINEDEBUG=-all
export SteamAppId=949230 SteamGameId=949230 SteamOverlayGameId=949230
export WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d;winemenubuilder.exe=d"

STEAM="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
GDIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"
CL="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs/connection_log.txt"
QUIET="${CS2_QUIET:-0}"

note() {  # milestone: notification when quiet, plain echo otherwise
  echo "$1"
  [ "$QUIET" = "1" ] && osascript -e "display notification \"$1\" with title \"Cities: Skylines II\"" >/dev/null 2>&1
  return 0
}
die() {   # fatal: alert dialog when quiet, pause-on-keypress otherwise
  echo "ERROR: $1"
  if [ "$QUIET" = "1" ]; then
    osascript -e "display alert \"Cities: Skylines II\" message \"$1\" as critical" >/dev/null 2>&1
  else
    echo "(press any key to close)"; read -n1 -r
  fi
  exit 1
}

echo "949230" > "$GDIR/steam_appid.txt"

# 0) Ensure all binary patches are applied (a game update reverts them; all idempotent).
#    repatch.sh now takes a target: "free" = this wrapper. 16 patches incl. the cohtml licence
#    bypass (REQUIRED on Sikarugir — its bcrypt fails Gameface's signature check) and lockleak.
if [ -x "${CS2_PATCH_DIR:-$HOME/cs2-patch}/repatch.sh" ]; then
  bash "${CS2_PATCH_DIR:-$HOME/cs2-patch}/repatch.sh" free >/dev/null 2>&1 && echo "Patches ensured (16)." \
    || echo "WARNING: repatch reported an issue — continuing (patches are idempotent)."
fi

# 1) Steam up + FRESHLY logged in.
#    A stale [U:1:...] line in connection_log matches a PREVIOUS session -> game launches before
#    Steam really connected -> SteamAPI.Init() fails -> GameManager NRE flood. So when WE start
#    Steam we record the log position first and require a NEW LogOnResponse 'OK'.
fresh_login() { tail -n +$((BEFORE+1)) "$CL" 2>/dev/null | grep -qE "LogOnResponse.*'OK'|\[Logged On.*\[U:1:[1-9]"; }
BEFORE=$(wc -l < "$CL" 2>/dev/null || echo 0)
STARTED_STEAM=0
# Scoped to THIS wrapper: since 2026-08-22 the dxmt11 wrapper can also have a Steam resident, and
# webhelper children carry Windows-style command lines that don't identify their wrapper. The
# parent steam.exe carries the unix path, so detect on that.
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
    if fresh_login && pgrep -f "$APPTAG.*steam.exe" >/dev/null 2>&1; then ok=1; break; fi
    sleep 3
  done
  [ "$ok" = 1 ] || die "Steam did not auto-login (token expired, or it crashed). Open Steam in the wrapper, sign in until the library loads, then relaunch. If Steam won't start at all, reboot — kill -9 can wedge it."
fi

# 2) Licence sync — ONLY needed when we just started Steam. Launching Cities2.exe too soon after a
#    fresh login means SteamAPI can't verify ownership -> platform-service failure -> NRE flood.
#    If Steam was already up, its licences are long since synced, so skip the wait entirely.
if [ "$STARTED_STEAM" = 1 ]; then
  # Progress feedback: the wait is ~45s of nothing, which looks like a hang. Report at intervals.
  # NOTE: Steam's appinfo job reports "UpdatesJob: finished OK" ~1s after login, so 45s is very
  # conservative — but it is the empirically proven margin for SteamAPI ownership verification
  # (too short -> SteamAPI.Init fails -> GameManager NRE flood -> no menu). Don't shorten blind.
  note "Signed in — verifying licence (about 45 seconds)…"
  for _s in 30 15; do
    sleep 15
    note "Almost ready — ${_s}s…"
  done
  sleep 15
else
  echo "Steam already warm — skipping the 45s licence wait."
fi

# 3) Launch the game DIRECTLY — NOT via `explorer /desktop`.
#    The saved displayMode=Fullscreen gives native exclusive fullscreen, which routes BOTH mouse and
#    keyboard. The old virtual-desktop wrapper fixed menu-mouse but ate WSAD (keyboard went to the
#    desktop container). If keyboard ever dies: check Options > Graphics > Display Mode = Fullscreen.
note "Launching Cities: Skylines II…"
"$WINE" "$GDIR/Cities2.exe"
GAME_RC=$?

# 4) Graceful shutdown. Quitting the game otherwise leaves Steam + ~9 steamwebhelper procs +
#    wineserver resident (~560 MB). Use steam.exe -shutdown, NEVER kill -9: hard-killing Steam
#    leaves a 0-byte .crash marker that makes the NEXT launch exit 1.
echo "Game exited (rc=$GAME_RC). Shutting down Steam cleanly…"
# Primary: ask Steam to close itself. NEVER kill -9 — that leaves a 0-byte .crash marker
# which makes the NEXT launch exit 1. Observed 2026-08-22: this can itself die with a floating
# point exception, so it is not sufficient on its own.
"$WINE" "$STEAM" -shutdown >/dev/null 2>&1 || echo "  (steam -shutdown failed; falling back)"
for i in $(seq 1 20); do
  pgrep -f "$APPTAG.*steam.exe" >/dev/null 2>&1 || break
  sleep 1
done
# Fallback: if Steam is still resident, end the wine session for THIS prefix. WINEPREFIX must be
# exported or wineserver targets the default prefix and silently does nothing (caught 2026-08-22).
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
# Report what, if anything, is still holding memory.
_rss=$(ps aux | grep -iE "[s]team\.exe|[s]teamwebhelper|[w]ineserver" | awk "{s+=\$6} END {printf \"%.0f\", s/1024+0}")
echo "  Residual after shutdown: ${_rss:-0} MB"
note "Cities: Skylines II closed."
exit 0
