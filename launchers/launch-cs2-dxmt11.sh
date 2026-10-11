#!/bin/bash
# CS2 launcher — Wine 11 + DXMT wrapper. The recipe, in order:
#   patches -> Steam up + logged in -> licence sync -> update check -> Cities2.exe DIRECTLY -> shutdown.
#
# Steam's "Play" button does NOT deliver a game on this stack: the Paradox Launcher now boots
# fully (re-tested 2026-08-24) but its cpatch/socket IPC times out under stock Wine — see
# GOTCHAS § Steam Play button. Launching the exe directly is still the whole trick.
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
#   CS2_ARGS="..."                     extra Cities2.exe arguments (e.g. -benchmark for the
#                                      perf-pass measurement cells; unquoted expansion, so
#                                      multiple space-separated args work)
#   CS2_UPDATE=ask|apply|skip          what to do when Steam has a game update waiting (step 2b).
#                                      ask (default) offers it; with no one to answer — no
#                                      terminal, or no reply within 2 minutes — the installed
#                                      build launches with a warning. apply takes it unasked.
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
# (WINEESYNC/WINEMSYNC removed 2026-08-23: stock winehq wine has never shipped esync/msync —
#  whole-source-tree grep, zero hits. They were Porting-Kit habit and did nothing here.)
export WINEDEBUG="${WINEDEBUG:--all}"
PATCH_DIR="${CS2_PATCH_DIR:-$HOME/cs2-patch}"

# >>> rosetta-preflight
# Rosetta preflight (2026-10-11, docs/plans/arm64-migration.md P0). This engine is x86_64, and a
# macOS update can remove Rosetta silently: 27.0.1 did (C69), and every launch then died with
# "Bad CPU type" where nobody saw it. Ask the engine itself first, so a future arm64 build passes
# untouched; only when it cannot run, tell a missing Rosetta apart from any other failure.
if ! wine_out="$("$WINE" --version 2>&1)"; then
  arch -x86_64 /usr/bin/true 2>/dev/null \
    || die "Rosetta 2 is not installed (a macOS update can remove it). In Terminal run: softwareupdate --install-rosetta --agree-to-license, then launch again."
  die "Wine cannot start ($WINE): ${wine_out:-no output}"
fi
# <<< rosetta-preflight

# Display profile (home/external vs mobile/built-in) — docs/plans/launcher-display-profiles.md
# CS2_PROFILE=home|mobile|off overrides auto-detect. Never blocks a launch: missing/failing
# helper = one warning line, boot continues untouched.
if [ -f "$PATCH_DIR/cs2-display-profile.sh" ]; then
  bash "$PATCH_DIR/cs2-display-profile.sh" || echo "WARNING: display-profile step failed — continuing with saved settings"
else
  echo "NOTE: no cs2-display-profile.sh in $PATCH_DIR — display profiles inactive."
fi

# CS2_HUD=1 — Metal's performance HUD (FPS, frame time, GPU time), plus DXMT's own stat lines
# (commit/sync/encode/render breakdown), since DXMT publishes into the same _CADeveloperHUDProperties
# overlay. This is the way to get a comparable frame-rate number on this stack; the game has no
# usable built-in counter.
[ "${CS2_HUD:-0}" = "1" ] && export MTL_HUD_ENABLED=1 && echo "Metal HUD: on"
# CS2_METALFX=1 — EXPERIMENTAL. Renders through a MetalFX spatially-upscaled swapchain; the factor
# comes from d3d11.metalSpatialUpscaleFactor (default 2). It does NOT lower the render resolution:
# it upscales the game's output toward the panel's native size. Measured on an M4 Pro (cs2 #15):
# a net LOSS at the game's own 2560x1440 (14.72 -> 14.31 FPS; 2560x1440 -> 5120x2880 upscale),
# and only worth it combined with a lowered in-game resolution (1080p: no measurable cost, cleaner
# than letting the panel stretch). Expect softer output; turn it off if anything looks wrong.
if [ "${CS2_METALFX:-0}" = "1" ]; then
  export DXMT_METALFX_SPATIAL_SWAPCHAIN=1
  echo "MetalFX spatial upscaling: on (experimental)"
fi
export SteamAppId=949230 SteamGameId=949230 SteamOverlayGameId=949230
export WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d;winemenubuilder.exe=d"

STEAM="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
GDIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"
CL="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs/connection_log.txt"

# ---- process attribution (2026-08-24): a steam.exe re-exec'd by its own updater carries a
# Windows-style argv (C:\...\steam.exe) that no .app-path pgrep can match, and webhelper
# children always do — command lines cannot attribute a wine process to its wrapper. Open
# files can: lsof against THIS prefix is the truthful test (~30 ms per pid).
_owns() { lsof -p "$1" 2>/dev/null | grep -q "$WINEPREFIX"; }
steam_exe_up() {   # steam.exe proper (any argv style) alive in THIS prefix?
  for _p in $(pgrep -f "steam.exe" 2>/dev/null); do
    case "$(ps -o command= -p "$_p" 2>/dev/null)" in *steamwebhelper*) continue ;; esac
    _owns "$_p" && return 0
  done
  return 1
}
webhelper_up() {   # any CEF helper of THIS prefix up? (readiness signal after a fresh start)
  for _p in $(pgrep -f "steamwebhelper.exe" 2>/dev/null); do _owns "$_p" && return 0; done
  return 1
}
steam_family() {   # every steam-ish pid THIS prefix still owns (shutdown sweep)
  for _p in $(pgrep -f "steam" 2>/dev/null); do _owns "$_p" && echo "$_p"; done
}

[ -x "$WINE" ]            || die "Wine not found inside $APPTAG (expected $WINE). Is this the DXMT wrapper?"
[ -f "$STEAM" ]           || die "Steam is not installed inside $APPTAG. See INSTALL.md step 2."
[ -f "$GDIR/Cities2.exe" ] || die "Cities: Skylines II is not installed inside $APPTAG. Install it via Steam in the wrapper (INSTALL.md step 3)."

echo "Wrapper: $APPTAG"
echo "949230" > "$GDIR/steam_appid.txt"
echo "Engine: $("$WINE" --version 2>/dev/null)"

# 0) Ensure the binary patches are applied — a game update reverts them. All are idempotent and
#    refuse to write if the pattern moved, so re-running is always safe. Step 2b calls this again
#    after it updates the game. Returns non-zero when repatch.sh reported a problem.
ensure_patches() {
  local rc=0
  if [ -x "$PATCH_DIR/repatch.sh" ]; then
    if CS2_GAME_DIR="$GDIR" bash "$PATCH_DIR/repatch.sh" dxmt11 >/dev/null 2>&1; then
      echo "Patches ensured (10, dxmt11 target)."
    else
      echo "WARNING: repatch reported an issue — continuing (patches are idempotent)."; rc=1
    fi
  else
    echo "NOTE: no repatch.sh in $PATCH_DIR — skipping the patch check. Run scripts/setup.sh to install it."
  fi
  # 0b) Badge patch (Game.dll): re-ensure after game updates — Steam replaces Game.dll and
  #     repatch.sh does not cover it (see patch-modconflict-badge.py; fail-open by design).
  if [ -x "$PATCH_DIR/revenv/bin/python3" ] && [ -f "$PATCH_DIR/patch-modconflict-badge.py" ]; then
    BP_OUT=$("$PATCH_DIR/revenv/bin/python3" "$PATCH_DIR/patch-modconflict-badge.py" apply 2>&1) \
      && echo "Badge patch: $(printf '%s' "$BP_OUT" | tail -1)" \
      || echo "WARNING: badge-patch check failed — continuing (cosmetic). $(printf '%s' "$BP_OUT" | head -1)"
  fi
  return $rc
}
ensure_patches

# 1) Steam up + FRESHLY logged in — scoped to THIS wrapper. Two wrappers can each have a Steam
#    resident, and `pgrep steamwebhelper` cannot tell them apart: webhelper children carry
#    Windows-style command lines. The PARENT steam.exe carries the unix path of its wrapper, so
#    scope on that. The fresh-login check reads THIS prefix's connection log.
fresh_login() { tail -n +$((BEFORE+1)) "$CL" 2>/dev/null | grep -qE "LogOnResponse.*'OK'|\[Logged On.*\[U:1:[1-9]"; }
BEFORE=$(wc -l < "$CL" 2>/dev/null || echo 0)
STARTED_STEAM=0
if steam_exe_up; then
  note "Steam already running — reusing session."
  tail -20 "$CL" 2>/dev/null | grep -qE "\[Logged On.*\[U:1:[1-9]|LogOnResponse.*'OK'" \
    || die "Steam is running but not logged in. Sign in in the Steam window, then relaunch."
else
  note "Starting Steam…"
  # a stale 0-byte .crash marker makes steam.exe exit 1 and never start — clear it first
  rm -f "$WINEPREFIX/drive_c/Program Files (x86)/Steam/.crash" 2>/dev/null
  # ⚠ NEVER `nohup` here (nor `env`, `setsid`, `bash -c`). macOS PURGES DYLD_* when exec'ing a
  # SIP-protected system binary, and this engine's win32u.so has only an `@loader_path/` rpath,
  # so stripping DYLD_FALLBACK_LIBRARY_PATH leaves wine unable to load its own
  # libfreetype.dylib and Steam renders with NO TEXT. Measured 2026-08-30 — it is why Steam had
  # no glyphs for a week while the game (launched directly) was fine.
  # `disown` is a shell builtin: no exec, nothing to strip.
  "$WINE" "$STEAM" -silent -no-cef-sandbox >/dev/null 2>&1 & disown
  STARTED_STEAM=1
  ok=0
  for i in $(seq 1 40); do
    if fresh_login && webhelper_up; then ok=1; break; fi
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

# 2b) Is a game update waiting? (#17) This launcher runs Steam -silent and shuts it down the moment
#     the game exits, so Steam's scheduled auto-update window never arrives: the game sat on the
#     2026-07-05 build for three months while Paradox Mods updated mods to the current one, until a
#     mod needed a type the old Game.dll lacked (GOTCHAS 2026-10-10, ledger C70). Checked after the
#     licence wait so a freshly started Steam has had time to refresh the app's manifest.
MANIFEST="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/appmanifest_949230.acf"
# >>> update-check — scripts/test-update-check.sh sources everything between these markers
UPDATE_POLL="${CS2_UPDATE_POLL:-10}"          # seconds between manifest reads while updating
UPDATE_TIMEOUT="${CS2_UPDATE_TIMEOUT:-3600}"  # give up waiting for Steam after this long
UPDATE_ASK_SECS="${CS2_UPDATE_ASK_SECS:-120}" # unanswered question -> launch the installed build
acf_field() {   # first top-level "<key>" "<value>" pair; the three keys used here occur once
  sed -n "s/^[[:space:]]*\"$1\"[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$MANIFEST" 2>/dev/null | head -1
}
update_pending() {   # 0 = update waiting, 1 = current, 2 = manifest unreadable. Sets UPD_FROM/UPD_TO.
  local flags target
  flags=$(acf_field StateFlags); UPD_FROM=$(acf_field buildid); target=$(acf_field TargetBuildID)
  UPD_TO="${target:-?}"
  [ -n "$flags" ] || return 2
  [ "$flags" != 4 ] && return 0                     # 4 = fully installed, nothing scheduled
  [ -n "$target" ] && [ "$target" != 0 ] && [ "$target" != "$UPD_FROM" ] && return 0
  return 1
}
apply_game_update() {
  local waited=0 last=0 rc
  note "Updating the game through Steam (build $UPD_FROM -> $UPD_TO)…"
  # Forwarded to the running Steam. It validates the installed build first — our patched DLLs
  # count as mismatches, which is expected — then runs the real update. 1.6.0f1 -> 1.6.2f1 was
  # 5.1 GB and ~6.5 min (ledger 2026-10-10). No `timeout` wrapper: macOS has none, and
  # `timeout … wine` exits 127 having done nothing.
  "$WINE" "$STEAM" "steam://validate/949230" >/dev/null 2>&1 & disown
  while [ "$waited" -lt "$UPDATE_TIMEOUT" ]; do
    sleep "$UPDATE_POLL"; waited=$((waited + UPDATE_POLL))
    update_pending; rc=$?
    if [ "$rc" = 1 ]; then note "Game updated to build $UPD_FROM."; return 0; fi
    steam_exe_up || die "Steam exited while updating the game. Open Steam inside the wrapper, let the update finish, then relaunch."
    if [ $((waited - last)) -ge 60 ]; then
      last=$waited
      note "Still updating the game — $((waited / 60)) min so far (StateFlags $(acf_field StateFlags), $(acf_field BytesDownloaded) of $(acf_field BytesToDownload) bytes)."
    fi
  done
  die "The game update did not finish within $((UPDATE_TIMEOUT / 60)) minutes. Steam is still running in the wrapper: let it finish, then relaunch."
}
check_game_update() {
  local rc ans=play msg
  update_pending; rc=$?
  if [ "$rc" = 2 ]; then echo "NOTE: cannot read the game's Steam manifest — update check skipped."; return 0; fi
  if [ "$rc" = 1 ]; then echo "Game build $UPD_FROM is current."; return 0; fi
  msg="Steam has a game update waiting (build $UPD_FROM -> $UPD_TO). Mods follow the newest game version, so the installed build can break them."
  case "${CS2_UPDATE:-ask}" in
    apply) ans=update ;;
    skip)  ;;
    *)
      if [ "$QUIET" = "1" ]; then
        [ "$(osascript -e "button returned of (display dialog \"$msg Updating takes several minutes.\" buttons {\"Play anyway\", \"Update first\"} default button \"Update first\" with title \"Cities: Skylines II\" giving up after $UPDATE_ASK_SECS)" 2>/dev/null)" = "Update first" ] && ans=update
      elif [ -t 0 ]; then
        printf '%s\nUpdate first? [Y/n] (no answer in %ss = play the installed build) ' "$msg" "$UPDATE_ASK_SECS"
        if read -r -t "$UPDATE_ASK_SECS" ans; then
          case "$ans" in [nN]*) ans=play ;; *) ans=update ;; esac
        else
          echo; ans=play
        fi
      fi
      ;;
  esac
  if [ "$ans" != update ]; then
    note "WARNING: game update waiting (build $UPD_FROM -> $UPD_TO) — launching the installed build. CS2_UPDATE=apply takes it."
    return 0
  fi
  apply_game_update
  ensure_patches || note "WARNING: some fixes did not apply to the new game build — see INSTALL.md 'After a game update'."
}
# <<< update-check
check_game_update

# 3) Launch the game DIRECTLY — NOT via `explorer /desktop` (that eats WSAD: the keyboard goes to
#    the virtual-desktop container).
#    ⚠ In the game's Options, set Display Mode = FULLSCREEN WINDOW. It is immune to the alt-tab
#    presentation freeze (dxmt#206); exclusive Fullscreen presents into a hidden swapchain after
#    you switch away, and the screen then only updates once per alt-tab.
note "Launching Cities: Skylines II (Wine 11 + DXMT)…"
"$WINE" "$GDIR/Cities2.exe" ${CS2_ARGS:-}
GAME_RC=$?

# 4) Graceful shutdown, scoped to THIS wrapper. NEVER kill -9 — that leaves a 0-byte .crash marker
#    which makes the NEXT launch exit 1. `steam -shutdown` can itself die with a floating point
#    exception, so it is not sufficient on its own.
echo "Game exited (rc=$GAME_RC). Shutting down Steam cleanly…"
"$WINE" "$STEAM" -shutdown >/dev/null 2>&1 || echo "  (steam -shutdown failed; falling back)"
for i in $(seq 1 20); do
  steam_exe_up || break
  sleep 1
done
# Fallback: end the wine session for THIS prefix only. WINEPREFIX must be exported or wineserver
# targets the default prefix and silently does nothing.
if steam_exe_up; then
  echo "  Steam still resident — ending the wine session for this prefix."
  WINEPREFIX="$WINEPREFIX" "$SS/wine/bin/wineserver" -k >/dev/null 2>&1
  for i in $(seq 1 10); do
    steam_exe_up || break
    sleep 1
  done
fi
# Webhelpers can outlive steam.exe: they reparent to launchd and their Windows-style argv hides
# them from every cmdline check (6 of them survived a shutdown unseen, 2026-08-24). Sweep the
# whole family by prefix attribution.
_strays="$(steam_family)"
if [ -n "$_strays" ]; then
  WINEPREFIX="$WINEPREFIX" "$SS/wine/bin/wineserver" -k >/dev/null 2>&1
  sleep 2
  _strays="$(steam_family)"
  [ -n "$_strays" ] && kill $_strays 2>/dev/null   # plain TERM — NEVER kill -9 steam
fi
# wineserver exits on its own once its clients are gone; nudge it only if it lingers
if pgrep -f "$APPTAG.*wineserver" >/dev/null 2>&1; then
  sleep 2
  WINEPREFIX="$WINEPREFIX" "$SS/wine/bin/wineserver" -k >/dev/null 2>&1
fi
_left=$(steam_family | wc -l | tr -d ' ')
echo "  Residual Steam-family processes in this prefix: ${_left:-0}"
note "Cities: Skylines II closed."
exit 0
