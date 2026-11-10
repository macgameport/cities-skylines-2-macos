#!/bin/bash
# launch-relaunched.sh -- Surviving Mars: Relaunched (Windows, Steam app 3215050) on macOS.
#
# The game is DirectX 12 only (Mars.exe loads d3d12.dll, exports D3D12SDKVersion 618, no D3D11 or
# Vulkan path), so it needs D3DMetal: DXMT is D3D11-only. It has its own wrapper,
# ~/Applications/SurvivingMars.app (docs/plans/one-wrapper-per-game.md, built 2026-11-07 by
# tools/split-wrapper.sh): an APFS clone of the Kegworks/Sikarugir "Steambuild Metal" wrapper S734M
# (Wine 10; first menu 2026-10-31) with Cities: Skylines II stripped out, the game in its own Steam
# library, and D3DMetal 3.0 from CrossOver 26 in its wine/ (tools/make-engine.sh --install; the 2.1
# original is wine.d3dm21-BAK). Under 2.1 any landscaping project (RC Dozer: Flatten, Ramp, ...) turned
# the whole map black, and a save holding one stayed black on every load; 3.0 renders it. The launcher
# refuses to start on 2.1. SM_WRAPPER=<.app> picks another wrapper; SM_ENGINE=<wine dir> another engine
# (default: the wrapper's own wine/); SM_STEAM_ENGINE=<wine dir> runs Steam on a different engine of the
# same Wine build. Buying and DLC browsing: the cs2 project's "CS2 Steam Store" app (licences are
# account-level). Never run two Steams on this account at once: the second replaces the first's
# session, and the replaced Steam skips the cloud upload at exit (MacBook, 2026-11-01). The lock below
# covers launches in this wrapper only.
#
# Recipe (from the Cities: Skylines II launcher): Steam up and freshly logged in IN THIS PREFIX -> licence wait ->
# cloud sign-in sync -> game-update check -> Mars.exe directly with steam_appid.txt, plus
# tools/frame-fix.exe watching its window -> on exit, wait for the cloud upload, steam.exe -shutdown.
# NEVER kill -9 Steam (0-byte .crash marker breaks the next start).
#
# Measured on the MacBook (M3 Max, macOS 27.2), 2026-11-01:
#   - DLC: Interplanetary Codex (thomas.fpk) and Feeding the Future (norman.fpk) load. Prime Mission is
#     the expansion pass, a licence with no depot of its own; its next pack (Machine Utopia) is unreleased.
#   - Mods: the in-game Mod Manager (Paradox Mods) works; installs land in this wrapper's prefix,
#     AppData/Roaming/Surviving Mars Relaunched/PdxMods. Steam Workshop subscriptions are untested here.
#   - Load: the game process uses 2.2-2.7 cores with no frame cap saved; set VSync or a frame limit in
#     Options > Video if the Mac runs hot (not yet re-measured with a cap).
# On another Mac: clone this repo, build tools/frame-fix.exe (line in its header), run
# tools/split-wrapper.sh (it needs that Mac's S734M and storefront wrappers with the game installed in
# the storefront one), re-run make-app.sh, and confirm Rosetta (`arch -x86_64 /usr/bin/true`). Mods are
# per prefix (re-install them in the Mod Manager); saves travel by Steam Cloud, below. With no copy of
# the game at all, forwarding steam://install/3215050 to this wrapper's Steam is the route (unmeasured).
#
# Steam Cloud, measured on the Studio 2026-11-02 from Steam's logs/cloud_log.txt:
#   - Steam's Auto-Cloud carries Saved Games/Surviving Mars Relaunched/<SteamID64>/* (saves plus
#     account.dat, the game's settings) and uploads it when the game exits. The Paradox account only
#     shows up handling mods.
#   - Steam asks "keep local or cloud?" only when IT launches the game. This launcher starts Mars.exe
#     itself, so a conflict blocks every upload without a word: on 2026-11-01 account.dat differed from
#     the MacBook's copy and six exits uploaded nothing. The launcher waits for the result and alerts.
#   - Pull before play. Steam syncs a game's cloud saves at sign-in only when the game is installed in
#     it (MacBook 2026-11-02: installed, a cloud save missing here arrived within 3 s of sign-in; not
#     installed, nothing in 2.5 min). The game is installed in this wrapper's Steam, so it pulls at
#     sign-in; the launcher waits for that sync and refuses on a conflict. Until 2026-11-07 the game
#     lived in the storefront wrapper and was registered here by a symlink plus a manifest copy.
#   - To clear a conflict, with the game and this wrapper's Steam closed: back up
#     Saved Games/Surviving Mars Relaunched/<SteamID64>/ and Steam's userdata/<id>/3215050/, delete the
#     files Steam named as conflicting and userdata/<id>/3215050/remotecache.vdf, then launch: Steam pulls
#     the cloud's copy at sign-in. Saves only on this Mac stay and upload at the next exit. Measured
#     2026-11-07 (Studio, one save deleted, the rest identical to the cloud's): without the cache Steam
#     counted this Mac as change 0 and downloaded all 10 cloud files in 22 s, no conflict, the deleted
#     save back byte-identical. What it does with a local file that DIFFERS from the cloud's, with no
#     cache, is unmeasured -- hence deleting the conflicting files as well.
#   - Steam's -shutdown cancels an exit upload still in flight ("Upload Timeout", "Job Canceled"): a
#     31.8 MB save lost its upload 24 s in (MacBook, 2026-11-01). Hence the wait below.
#
# SM_QUIET=1 -> notifications and alert dialogs instead of terminal output.
# SM_LICENCE_WAIT=<s> -> seconds to wait after sign-in (default 15; cs2's measured margin for SteamAPI is 45).
#   Measured 2026-11-08 (tools/licence-wait-probe.sh, 5 runs each at 30 s and 15 s): 10/10 clean, Steam
#   initialised and both DLCs owned every time, so the race cs2 hit does not show here. Menu at sign-in
#   + 39 s (15), + 54 s (30), + 57 or + 68 s (45). The game sometimes stalls a fixed 13.5 s before
#   "Account storage loaded" (10/10 of those runs, 7 of 23 at 45 s); cause not identified, README.
# SM_UPDATE=ask|apply|skip -> what to do when Steam has a game update waiting (default ask; see 2b).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SM_STATE="${SM_STATE:-$HOME/Library/Application Support/1launcher/surviving-mars-relaunched}"
APP="${SM_WRAPPER:-$HOME/Applications/SurvivingMars.app}"   # the wrapper whose prefix, Steam and game this is
SS="$APP/Contents/SharedSupport"
GAME="$SS/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Project Spark"
HELPER="$HERE/tools/frame-fix.exe"
RUNS="$SM_STATE/runs"
ENGINE="${SM_ENGINE:-$SS/wine}"
export WINEPREFIX="$SS/prefix"
export PATH="$ENGINE/bin:$PATH"
export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$ENGINE/lib:/usr/lib:/usr/local/lib"
# Every wine client must match the wineserver's sync mode: a client started without
# WINEMSYNC/WINEESYNC against an msync wineserver dies with SIGFPE in ntdll.so (2026-11-01).
export WINEESYNC=1 WINEMSYNC=1 D3DMETAL=1 D3DMETAL_FORCE=1 WINEDEBUG=fixme-all
export WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d;winemenubuilder.exe=d"
export SteamAppId=3215050 SteamGameId=3215050 SteamOverlayGameId=3215050
WINE="$ENGINE/bin/wine64"
# SM_STEAM_ENGINE=<wine dir> runs Steam on another engine of the same Wine build, sharing the prefix's
# wineserver with the game. Unified-stack probe, 2026-11-07: D3DMetal 3.0 loaded inside Steam's own
# processes on Wine 11.16 crashes steam.exe at start, so there Steam runs on the DXMT engine and only
# the game on the D3DMetal one. Default: the game's engine (Wine 10: Steam runs fine on D3DMetal 3.0).
STEAM_WINE="${SM_STEAM_ENGINE:-$ENGINE}/bin/wine64"
STEAM="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
CL="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs/connection_log.txt"
CLOUD="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs/cloud_log.txt"
SAPPS="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps"
MANIFEST="$SAPPS/appmanifest_3215050.acf"
QUIET="${SM_QUIET:-0}"
# >>> launch-feedback-config (this launcher's own values)
STEPS=5
TITLE="Surviving Mars: Relaunched"
PANEL="${SM_PANEL:-0}"
# <<< launch-feedback-config
# >>> launch-feedback (the same in both launchers: common/test-launcher-parity.sh compares the copies)
_notify() { osascript -e 'on run a' -e 'display notification (item 1 of a) with title (item 2 of a)' -e 'end run' -- "$1" "$TITLE" >/dev/null 2>&1; }
_alert() {   # <text> [warning]: the text travels as an argument, never as AppleScript source
  if [ "${2:-}" = warning ]; then osascript -e 'on run a' -e 'display alert (item 2 of a) message (item 1 of a) as warning' -e 'end run' -- "$1" "$TITLE" >/dev/null 2>&1
  else osascript -e 'on run a' -e 'display alert (item 2 of a) message (item 1 of a) as critical' -e 'end run' -- "$1" "$TITLE" >/dev/null 2>&1; fi
}
step() {   # <n> <text>: a start-up milestone. The progress window reads these lines from the log.
  echo "[$1/$STEPS] $2"
  [ "$QUIET" = 1 ] && [ "$PANEL" != 1 ] && _notify "$2"
  return 0
}
note() {   # something the player should see even while the progress window is up
  echo "$1"
  [ "$QUIET" = 1 ] && _notify "$1"
  return 0
}
licence_wait() {   # <step> <seconds as set, may be empty> <default>: the wait after a fresh sign-in
  local w
  case "$2" in ''|*[!0-9]*|????*) w=$3 ;; *) w=$((10#$2)) ;; esac
  echo "Licence wait: $w s"
  while [ "$w" -gt 0 ]; do
    step "$1" "Steam is confirming the game licence, about $w seconds left…"
    if [ "$w" -gt 15 ]; then sleep 15; w=$((w - 15)); else sleep "$w"; w=0; fi
  done
}
# <<< launch-feedback

die() {
  echo "ERROR: $1"
  [ "$QUIET" = 1 ] && _alert "$1"
  exit 1
}

arch -x86_64 /usr/bin/true 2>/dev/null || die "Rosetta is missing (a macOS update removes it). Run: softwareupdate --install-rosetta --agree-to-license"
[ -d "$WINEPREFIX" ] || die "The game's wrapper is missing: $APP. Build it: bash $HERE/tools/split-wrapper.sh"
[ -x "$WINE" ] || die "The game's Wine engine is missing: $ENGINE."
# D3DMetal 2.1 blacks out the map whenever a landscaping project exists (header). Refuse it out loud.
D3DM_VER=$(plutil -extract CFBundleShortVersionString raw "$ENGINE/lib/external/D3DMetal.framework/Versions/A/Resources/Info.plist" 2>/dev/null \
  || plutil -extract CFBundleShortVersionString raw "$ENGINE/lib/external/D3DMetal.framework/Resources/Info.plist" 2>/dev/null || echo none)
case "$D3DM_VER" in
  [3-9].*) ;;
  *) die "This Wine has D3DMetal $D3DM_VER, not 3.0, and landscaping turns the map black on it. Run: bash $HERE/tools/make-engine.sh --install \"$APP\"" ;;
esac
[ -f "$GAME/Mars.exe" ] || die "Mars.exe not found in $(basename "$APP" .app). Reinstall it with this wrapper's Steam (steam://install/3215050; see the header)."
# The game's command line STARTS with its own path (wine shows the unix path it was given, or a
# C:\ path if Steam started it). Match that start, never a substring: `pgrep -f` alone also matches
# any shell or editor whose command line merely mentions the file, and refused a launch (2026-11-01).
game_running() {
  for _p in $(pgrep -f 'Mars\.exe' 2>/dev/null); do
    case "$(ps -o command= -p "$_p" 2>/dev/null)" in
      "$GAME/Mars.exe"*|'C:\'*'\Project Spark\Mars.exe'*) return 0 ;;
    esac
  done
  return 1
}
game_running && die "The game is already running."

# One launcher per Wine prefix, for its whole run: every launcher that uses this prefix's Steam takes
# the same lock. Until 2026-11-07 S734M's prefix was shared by a Cities: Skylines II launcher and this one;
# now this wrapper is the game's own and the lock serialises launches in it. A launch while the
# previous launcher was still closing Steam found Steam "already running", reused it, and the game
# died as that shutdown finished: `CClientPipe::BWriteAndReadResult: BReadResult failed ... Fatal
# assert` (2026-11-07). The lock is a symlink whose target is the holder's PID: creating one is atomic,
# and a launcher that died leaves a link to a dead PID, which the next launch clears. The functions are
# identical in the Cities: Skylines II launcher and this one (original: this one); common/test-launch-lock.sh
# runs them and checks the copies still match.
LOCK="$WINEPREFIX/.launcher.lock"
lock_holder() { readlink "$LOCK" 2>/dev/null; }
acquire_lock() {   # <tries, 2 s apart> -- 0 = this launcher holds the lock; needs step, die, game_running
  local i h
  for i in $(seq 1 "$1"); do
    ln -s "$$" "$LOCK" 2>/dev/null && return 0
    h=$(lock_holder)
    if [ -n "$h" ] && ! kill -0 "$h" 2>/dev/null; then   # left by a launcher that died
      [ "$(lock_holder)" = "$h" ] && rm -f "$LOCK"
      ln -s "$$" "$LOCK" 2>/dev/null && return 0
    fi
    [ "$i" = 1 ] && step 0 "Waiting for the last session to finish closing…"
    game_running && die "The game is already running."
    sleep 2
  done
  return 1
}
release_lock() { [ "$(lock_holder)" = "$$" ] && rm -f "$LOCK"; return 0; }
acquire_lock 90 || die "Another launch in this wrapper is still running (pid $(lock_holder)). Wait for it to finish, then try again."
trap release_lock EXIT

# Attribute Steam by open files against THIS prefix, never by command line (cs2 GOTCHAS 2026-08-24).
_owns() { lsof -p "$1" 2>/dev/null | grep -q "$WINEPREFIX"; }
steam_exe_up() {
  for _p in $(pgrep -f "steam.exe" 2>/dev/null); do
    case "$(ps -o command= -p "$_p" 2>/dev/null)" in *steamwebhelper*) continue ;; esac
    _owns "$_p" && return 0
  done
  return 1
}
steam_family() { for _p in $(pgrep -f "steam" 2>/dev/null); do _owns "$_p" && echo "$_p"; done; }
# This game's Steam Cloud result in cloud_log lines on stdin; the last one wins:
# ok | conflict <files> | offline | failed | uploading | none. cloud_log.txt is CRLF.
cloud_outcome() {
  awk -v id="[AppID $SteamAppId]" '{ sub(/\r$/, "") } index($0, id) {
    if (/Upload complete, result OK/) r = "ok"
    else if (/Sync conflict for file /) { f = $0; sub(/.*\//, "", f); c = (c == "" ? f : c ", " f) }
    else if (/Upload failed/) { r = (c == "" ? "failed" : "conflict " c); c = "" }
    else if (/Sync Disabled/) r = "offline"
    else if (/Failed sync for |Upload Timeout|Job Canceled/) r = "failed"
    else if (/Upload batch initiated/) r = "uploading"
  } END { print (r == "" ? "none" : r) }'
}
# This game's sign-in cloud sync in cloud_log lines on stdin (header: pull before play):
# current | conflict [<files>] | failed | busy | none.
signin_outcome() {
  awk -v id="[AppID $SteamAppId]" '{ sub(/\r$/, "") } index($0, id) {
    if (/Sync conflict for file /) { f = $0; sub(/.*\//, "", f); c = (c == "" ? f : c ", " f); r = "conflict " c; next }
    if (/conflict/) { if (c == "") r = "conflict"; next }
    if (r ~ /^conflict/) next
    if (/Failed sync for |Upload Timeout|Job Canceled|Download failed|Upload failed/) r = "failed"
    else if (/Need to (download|upload) file|Starting sync \((down|up),|Upload batch initiated/) r = "busy"
    else if (/Successfully synced to ChangeNumber|Upload complete, result OK|Upload complete in build list/) r = "current"
    else if (/Eval complete/ && r == "") r = "current"
  } END { print (r == "" ? "none" : r) }'
}
stop_steam() {
  "$STEAM_WINE" "$STEAM" -shutdown >/dev/null 2>&1
  for _ in $(seq 1 20); do steam_exe_up || break; sleep 1; done
  steam_exe_up && "$ENGINE/bin/wineserver" -k >/dev/null 2>&1
  sleep 2
  _strays="$(steam_family)"
  [ -n "$_strays" ] && kill $_strays 2>/dev/null   # plain TERM, never -9
}

STARTED=0
if steam_exe_up; then
  step 1 "Steam is already running…"
else
  step 1 "Starting Steam and signing in…"
  STARTED=1
  BEFORE=$(wc -l < "$CL" 2>/dev/null || echo 0)
  rm -f "$WINEPREFIX/drive_c/Program Files (x86)/Steam/.crash" 2>/dev/null
  # never nohup/env/setsid here: macOS strips DYLD_* and wine loses its fonts (cs2, 2026-08-30)
  "$STEAM_WINE" "$STEAM" -silent -no-cef-sandbox >/dev/null 2>&1 & disown
  ok=0
  for _ in $(seq 1 40); do
    tail -n +$((BEFORE + 1)) "$CL" 2>/dev/null | grep -qE "LogOnResponse.*'OK'|\[Logged On" && steam_exe_up && { ok=1; break; }
    sleep 3
  done
  # A Steam left up after a failed sign-in would be "reused" by the next launch, skipping this check.
  [ "$ok" = 1 ] || { stop_steam; die "Steam did not sign in by itself. Open Steam in the $(basename "$APP" .app) wrapper, sign in, then launch again."; }
  licence_wait 2 "${SM_LICENCE_WAIT:-}" 15
fi

# Steam pulls this game's cloud saves right after sign-in (header: pull before play). Starting the game
# before that finishes would load stale saves; a conflict means saves made now could not upload. Read
# from this Steam's start (its last "Client version:" line), so a reused Steam is checked too and a
# rotated log does not hide the sync.
CSTART=$(grep -n 'Client version:' "$CLOUD" 2>/dev/null | tail -n 1 | cut -d: -f1)
step 3 "Checking saves with Steam Cloud…"
for _i in $(seq 1 150); do
  SIGNIN=$(tail -n +"${CSTART:-1}" "$CLOUD" 2>/dev/null | signin_outcome)
  [ "$SIGNIN" = busy ] || break
  [ "$_i" = 1 ] && step 3 "Syncing saves with Steam Cloud. This can take a few minutes…"
  sleep 2
done
_files="${SIGNIN#conflict}"
case "$SIGNIN" in
  current) echo "Steam Cloud: saves up to date." ;;
  conflict*) [ "$STARTED" = 1 ] && stop_steam
    die "Steam Cloud has a conflict${_files:+ on$_files}: this Mac's copy and the cloud's both changed, and saves made now could not upload. Clear it first: see the Steam Cloud notes at the top of launch-relaunched.sh." ;;
  busy) [ "$STARTED" = 1 ] && stop_steam
    die "Steam Cloud was still syncing saves after 5 minutes. Launch again in a few minutes." ;;
  failed) note "Steam Cloud could not sync at sign-in (Steam's logs/cloud_log.txt says why); playing with this Mac's saves." ;;
  *) note "Steam Cloud: no sign-in sync logged; playing with this Mac's saves." ;;
esac

# 2b) Is a game update waiting? Copied from cs2's launch-cs2-dxmt11.sh § 2b (its #17). This launcher runs
#     Steam -silent and shuts it down when the game exits, and the manifest reads AutoUpdateBehavior 1,
#     so Steam never updates the game on its own: this check is the only updater, and nothing downloads
#     while the game runs. Checked after the cloud sync so the saves' verdict comes first.
# >>> update-check — tools/test-update-check.sh sources everything between these markers
UPDATE_POLL="${SM_UPDATE_POLL:-10}"          # seconds between manifest reads while updating
UPDATE_TIMEOUT="${SM_UPDATE_TIMEOUT:-3600}"  # give up waiting for Steam after this long
UPDATE_ASK_SECS="${SM_UPDATE_ASK_SECS:-120}" # unanswered question -> launch the installed build
UPDATE_TICK="${SM_UPDATE_TICK:-60}"          # seconds between "so far" lines while updating
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
update_size() {   # <bytes downloaded> <bytes to download> -> ", 3.4 of 5.1 GB" for the player's line, or nothing
  case "$1" in ''|*[!0-9]*) return 0 ;; esac
  case "$2" in ''|*[!0-9]*) return 0 ;; esac
  [ "$((10#$2))" = 0 ] && return 0                # Steam gives no total
  [ "$((10#$1))" = "$((10#$2))" ] && return 0     # equal: what an idle manifest keeps from the last update
  echo ", $((10#$1 / 1000000000)).$((10#$1 / 100000000 % 10)) of $((10#$2 / 1000000000)).$((10#$2 / 100000000 % 10)) GB"
}
apply_game_update() {
  local waited=0 last=0 rc got total size
  # Each message is a line of detail for the log and a short step 4 for the player: an update is the
  # longest wait of a launch, and the progress window shows steps only.
  echo "Updating the game through Steam (build $UPD_FROM -> $UPD_TO)…"
  step 4 "Updating the game. This can take several minutes…"
  # Forwarded to the running Steam, which validates the installed build and then runs the update.
  # No `timeout` wrapper: macOS has none, and `timeout … wine` exits 127 having done nothing.
  "$STEAM_WINE" "$STEAM" "steam://validate/3215050" >/dev/null 2>&1 & disown
  while [ "$waited" -lt "$UPDATE_TIMEOUT" ]; do
    sleep "$UPDATE_POLL"; waited=$((waited + UPDATE_POLL))
    update_pending; rc=$?
    if [ "$rc" = 1 ]; then echo "Game updated to build $UPD_FROM."; step 4 "The game is updated…"; return 0; fi
    steam_exe_up || die "Steam exited while updating the game. Open Steam inside the wrapper, let the update finish, then relaunch."
    if [ $((waited - last)) -ge "$UPDATE_TICK" ]; then
      last=$waited
      got=$(acf_field BytesDownloaded); total=$(acf_field BytesToDownload); size=$(update_size "$got" "$total")
      echo "Still updating the game — $((waited / 60)) min so far (StateFlags $(acf_field StateFlags), $got of $total bytes)."
      step 4 "Updating the game: $((waited / 60)) min so far${size}…"
    fi
  done
  die "The game update did not finish within $((UPDATE_TIMEOUT / 60)) minutes. Steam is still running in the wrapper: let it finish, then relaunch."
}
check_game_update() {
  local rc ans=play msg
  update_pending; rc=$?
  if [ "$rc" = 2 ]; then echo "NOTE: cannot read the game's Steam manifest — update check skipped."; return 0; fi
  if [ "$rc" = 1 ]; then echo "Game build $UPD_FROM is current."; return 0; fi
  msg="Steam has a game update waiting (build $UPD_FROM -> $UPD_TO)."
  case "${SM_UPDATE:-ask}" in
    apply) ans=update ;;
    skip)  ;;
    *)
      if [ "$QUIET" = "1" ]; then
        [ "$(osascript -e "button returned of (display dialog \"$msg Updating can take several minutes.\" buttons {\"Play anyway\", \"Update first\"} default button \"Update first\" with title \"Surviving Mars: Relaunched\" giving up after $UPDATE_ASK_SECS)" 2>/dev/null)" = "Update first" ] && ans=update
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
    note "WARNING: game update waiting (build $UPD_FROM -> $UPD_TO) — launching the installed build. SM_UPDATE=apply takes it."
    return 0
  fi
  apply_game_update
}
# <<< update-check
step 4 "Checking for a game update…"
check_game_update

echo 3215050 > "$GAME/steam_appid.txt"
mkdir -p "$RUNS"; LOG="$RUNS/launch-$(date +%Y%m%d-%H%M%S).log"
step 5 "Starting Surviving Mars: Relaunched…"
cd "$GAME" || die "cannot enter the game directory"
CBEFORE=$(wc -l < "$CLOUD" 2>/dev/null || echo 0)
CLBEFORE=$(wc -l < "$CL" 2>/dev/null || echo 0)
"$WINE" "$GAME/Mars.exe" >"$LOG" 2>&1 &
GAME_PID=$!
# Clicks land sideways until the window's stale frame is recomputed (tools/frame-fix.c).
FIX_PID=""
if [ -f "$HELPER" ]; then
  "$WINE" "$HELPER" --watch >"$LOG.frame-fix" 2>&1 &
  FIX_PID=$!
else
  note "tools/frame-fix.exe is not built (see its header). If clicks miss, press Option+Return twice."
fi
wait "$GAME_PID"
echo "Game exited (rc=$?). Shutting down Steam…"
# The watcher exits by itself ~5 s after the window is gone (it waits that long for a recreated one).
if [ -n "$FIX_PID" ]; then
  for _ in $(seq 1 8); do kill -0 "$FIX_PID" 2>/dev/null || break; sleep 1; done
  kill "$FIX_PID" 2>/dev/null
fi

# Steam uploads the saves on exit. Wait for its answer before shutting it down: up to 30 s for one
# to appear, up to 5 min once an upload has started (three saves are ~95 MB).
CLOUD_MSG=""
for _i in $(seq 1 150); do
  res=$(tail -n +$((CBEFORE + 1)) "$CLOUD" 2>/dev/null | cloud_outcome)
  case "$res" in ok|conflict*|offline|failed) break ;; uploading) ;; *) [ "$_i" -ge 15 ] && break ;; esac
  sleep 2
done
case "$res" in
  ok)        echo "Steam Cloud: saves uploaded." ;;
  conflict*) CLOUD_MSG="Steam Cloud refused this session's saves: a conflict on${res#conflict}. They are safe on this Mac but not in the cloud. To clear it, see the Steam Cloud notes at the top of launch-relaunched.sh." ;;
  offline)
    if tail -n +$((CLBEFORE + 1)) "$CL" 2>/dev/null | grep -q "Session Replaced"; then
      CLOUD_MSG="Another Steam on this account signed in during play (Session Replaced), so Steam was offline when the game closed and did not upload this session's saves. They are safe on this Mac."
    else
      CLOUD_MSG="Steam was offline when the game closed, so it did not upload this session's saves. They are safe on this Mac."
    fi ;;
  failed)    CLOUD_MSG="Steam Cloud did not upload this session's saves (Steam's logs/cloud_log.txt says why). They are safe on this Mac." ;;
  uploading) CLOUD_MSG="Steam Cloud was still uploading after 5 minutes; Steam was shut down anyway. Launch once more to finish the upload." ;;
  *)         echo "Steam Cloud: nothing uploaded this session." ;;
esac

stop_steam
note "Surviving Mars: Relaunched closed."
if [ -n "$CLOUD_MSG" ]; then
  echo "WARNING: $CLOUD_MSG"
  [ "$QUIET" = 1 ] && _alert "$CLOUD_MSG" warning
fi
exit 0
