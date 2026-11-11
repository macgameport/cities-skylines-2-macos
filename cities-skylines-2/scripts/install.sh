#!/bin/bash
# install.sh -- Cities: Skylines II from nothing to playable, in six steps, each skipped when it is already
# done (docs/plans/simple-install.md, 2.3): this Mac, Apple's Command Line Tools, Wine (make-wrapper.sh),
# Steam for Windows, the game (the player signs in and presses Install; this waits for the download),
# and setup.sh. Open it again after any stop and it carries on from there; on a finished install it is the
# way to update (setup runs every time).
#
#   bash scripts/install.sh              # the whole install
#   bash scripts/install.sh --check      # say what each step would do; start, download and change nothing
#   bash scripts/install.sh --yes        # install Rosetta without asking, and pass --yes to setup
#   bash scripts/install.sh --desktop    # pass --desktop to setup: a 14unch3r shortcut on the Desktop
#   bash scripts/install.sh --no-setup   # stop before step 6
#
#   exit 0 = done; 1 = a step failed, said why; 2 = a wrong option; 3 = stopped at a question (answered no,
#   or nobody to ask) or because the game or another install is running; 4 = it cannot go on by itself:
#   open the installer again to carry on. --check exits 0 after its report, or 1 or 3 for the refusals
#   that come before it.
# CS2_WRAPPER=<absolute path> names the wrapper, made in step 3 if absent. L1_TRACE=<file> gets one line per
# poll while Steam starts and downloads (the live check of the plan's NL1).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME_ROOT="$(cd "$HERE/.." && pwd)"
SETUP="$HERE/setup.sh"
MAKE_WRAPPER="$HERE/make-wrapper.sh"
STEAM_URLS="https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
STEAM_TESTED_SHA=7d3654531c32d941b8cae81c4137fc542172bfa9635f169cb392f245a0a12bcb
POLL=5            # seconds between looks at Steam and the download
TOOLS_POLLS=720   # 60 minutes for Apple's Command Line Tools
STUCK_POLLS=12    # a Steam with no client for 60 s is stuck at its box
GONE_POLLS=3      # Steam gone for this many polls in a row is gone (its updater replaces itself)
START_POLLS=120   # ten minutes for one start of Steam to bring its client up
MAX_STARTS=5
NEED_GB=110
FATAL='Error: (Failed to determine download location|Steam needs to be online)'
KILL_CMD="${L1_KILL:-kill}"   # the tests record the stray sweep's kill instead of sending it

CHECK=0; YES=0; DESKTOP=0; NO_SETUP=0; END=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --yes) YES=1; shift ;;
    --desktop) DESKTOP=1; shift ;;
    --no-setup) NO_SETUP=1; shift ;;
    -h|--help) sed -n '2,/^set -u$/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)"; exit 2 ;;
  esac
done

RHOME="$(cd "$HOME" 2>/dev/null && pwd -P)"   # the home folder as a resolved path is printed as ~ too
tilde() {
  case "$1" in
    "$HOME"|"$RHOME") printf '~' ;;
    "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
    "$RHOME"/*) printf '~%s' "${1#"$RHOME"}" ;;
    *) printf '%s' "$1" ;;
  esac
}
stage() { echo; echo "Step $1 of 6: $2"; }
say() { echo "  $*"; }
step() { :; }                           # acquire_lock's progress line: this script says its own
die() { echo "  !! $1"; exit 3; }       # acquire_lock's: the game started meanwhile
on_exit() {
  local rc=$?
  [ -n "${LOCK:-}" ] && release_lock
  case "$END" in
    quiet) ;;
    *) echo
       case "$rc" in
         0) echo "Done. Start the game from Applications: Cities Skylines II, or 14unch3r." ;;
         4) echo "Open the installer again: it carries on from here." ;;
         *) echo "The install stopped. The lines above say why. Open the installer again to carry on from that step." ;;
       esac ;;
  esac
}
trap on_exit EXIT
[ "$CHECK" = 1 ] && END=quiet
[ "$(id -u)" = 0 ] && { echo "Do not run the installer as root (with sudo): it would leave files only root can change in your home folder."; exit 1; }

# --- copies of the launcher's own functions (cities-skylines-2/launchers/launch-cs2-dxmt11.sh); test-install.sh
# --- holds them identical to it, and common/test-launch-lock.sh holds the lock code identical
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
_owns() { lsof -p "$1" 2>/dev/null | grep -q "$WINEPREFIX"; }
webhelper_up() {   # any CEF helper of THIS prefix up? (readiness signal after a fresh start)
  for _p in $(pgrep -f "steamwebhelper.exe" 2>/dev/null); do _owns "$_p" && return 0; done
  return 1
}
steam_family() {   # every steam-ish pid THIS prefix still owns (shutdown sweep)
  for _p in $(pgrep -f "steam" 2>/dev/null); do _owns "$_p" && echo "$_p"; done
}
game_running() { local p; for p in $(pgrep -f 'Cities2\.exe' 2>/dev/null); do lsof -p "$p" 2>/dev/null | grep -q "$WINEPREFIX" && return 0; done; return 1; }
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
acf_field() {   # first top-level "<key>" "<value>" pair; the three keys used here occur once
  sed -n "s/^[[:space:]]*\"$1\"[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$MANIFEST" 2>/dev/null | head -1
}

# --- this script's own
prefix_known() { [ -n "${WINEPREFIX:-}" ]; }   # an empty pattern would make _owns match every process
steam_proc_up() {   # steam.exe proper, either case (Valve's installer writes Steam.exe), holding this prefix
  local p
  for p in $(pgrep -f '[Ss]team\.exe' 2>/dev/null); do
    case "$(ps -o command= -p "$p" 2>/dev/null)" in *steamwebhelper*) continue ;; esac
    _owns "$p" && return 0
  done
  return 1
}
wsrv() { WINEPREFIX="${WINEPREFIX:?}" "$SS/wine/bin/wineserver" "$@"; }
trace() { [ -n "${L1_TRACE:-}" ] && echo "$(date '+%H:%M:%S') steam=$(steam_family | wc -l | tr -d ' ') client=$1" >> "$L1_TRACE"; return 0; }
use_wrapper() {   # <path>: the wrapper, and the launcher's exports for it
  APP="$1"
  SS="$APP/Contents/SharedSupport"
  export WINE="$SS/wine/bin/wine64"
  export WINEPREFIX="$SS/prefix"
  export PATH="$SS/wine/bin:$PATH"
  export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"
  export WINEDEBUG="${WINEDEBUG:--all}"
  export WINEDLLOVERRIDES="winemenubuilder.exe=d"
  STEAMDIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
  BOOTLOG="$STEAMDIR/logs/bootstrap_log.txt"
  GDIR="$STEAMDIR/steamapps/common/Cities Skylines II"
  MANIFEST="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/appmanifest_949230.acf"
  export CS2_WRAPPER="$APP"
}
steam_exe() { if [ -f "$STEAMDIR/steam.exe" ]; then echo "$STEAMDIR/steam.exe"; else echo "$STEAMDIR/Steam.exe"; fi; }
start_steam() {   # its own process group, hang-up ignored: Control-C or a closed window does not reach it
  set -m
  ( trap '' HUP; exec "$WINE" "$(steam_exe)" -no-cef-sandbox ) < /dev/null > /dev/null 2>&1 & disown
  set +m
}
end_steam() {   # wineserver -k for this prefix, then up to 10 s until nothing holds it
  local i=0
  wsrv -k > /dev/null 2>&1
  while [ "$i" -lt 10 ] && [ -n "$(steam_family)" ]; do sleep 1; i=$((i + 1)); done
}
game_state() {   # installed | update | absent | partial
  local f
  [ -f "$GDIR/Cities2.exe" ] || { echo absent; return; }
  [ -f "$MANIFEST" ] || { echo partial; return; }
  f="$(acf_field StateFlags)"
  case "$f" in ''|*[!0-9]*) echo partial; return ;; esac
  if [ "$f" = 4 ]; then echo installed
  elif [ $((f & 4)) -ne 0 ]; then echo update
  else echo partial; fi
}

start_until_up() {   # 0 = the client is up; 1 = five starts and no client
  local starts=0 i gone before
  while [ "$starts" -lt "$MAX_STARTS" ]; do
    starts=$((starts + 1))
    rm -f "$STEAMDIR/.crash"
    before=0; [ -f "$BOOTLOG" ] && before="$(wc -l < "$BOOTLOG" | tr -d ' ')"   # no log before Steam's first start
    start_steam
    i=0; gone=0
    while [ "$i" -lt "$START_POLLS" ]; do
      sleep "$POLL"; i=$((i + 1))
      if webhelper_up; then trace up; return 0; fi
      trace no
      if tail -n +"$((before + 1))" "$BOOTLOG" 2>/dev/null | grep -Eq "$FATAL"; then end_steam; continue 2; fi
      if steam_proc_up; then gone=0
      else gone=$((gone + 1)); [ "$gone" -ge "$GONE_POLLS" ] && continue 2
      fi
    done
    end_steam
  done
  return 1
}

# --- which wrapper (2.3)
echo "Cities: Skylines II for Apple Silicon Macs: the installer"
echo "You need a Steam account that owns the game, about 105 GB free, and time for a download of about 100 GB."
echo "You can open the installer again at any point: it carries on from where it stopped."
if [ -n "${CS2_WRAPPER:-}" ]; then
  case "$CS2_WRAPPER" in /*) ;; *) END=quiet; echo "CS2_WRAPPER must be an absolute path: $CS2_WRAPPER"; exit 2 ;; esac
fi
unset WINEPREFIX LOCK
W="$(find_wrapper)"
HOLDS="Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II/Cities2.exe"
if [ -n "${CS2_WRAPPER:-}" ]; then W="${CS2_WRAPPER%/}"
elif [ "$W" = "$HOME/Applications/CS2dxmt11.app" ]; then :
elif [ -n "$W" ] && [ -f "$W/$HOLDS" ]; then say "Using $(tilde "$W"), which holds the game."
else W="$HOME/Applications/CS2dxmt11.app"
fi
if [ -d "$W" ]; then
  W="$(cd "$W" && pwd -P)"
  if [ ! -x "$W/Contents/SharedSupport/wine/bin/wine64" ] || [ ! -x "$W/Contents/SharedSupport/wine/bin/wineserver" ] \
     || [ ! -d "$W/Contents/SharedSupport/prefix" ]; then
    say "!! $(tilde "$W") looks incomplete: it has no Wine or no prefix. Move it to the Trash, then open the installer again."
    exit 1
  fi
  use_wrapper "$W"
  LOCK="$WINEPREFIX/.launcher.lock"
  h="$(lock_holder)"
  if [ -n "$h" ] && [ "$h" != "$$" ] && kill -0 "$h" 2>/dev/null; then
    say "!! Another launch or install is using this wrapper (process $h). Wait for it to finish, then try again."
    exit 3
  fi
  unset LOCK
fi
if prefix_known && game_running; then say "!! The game is running. Quit it, then open the installer again."; exit 3; fi
[ "$CHECK" = 0 ] && { caffeinate -i -w $$ > /dev/null 2>&1 & }
[ "$CHECK" = 0 ] && say "The Mac is kept awake while this runs."

# --- step 1: this Mac
stage 1 "This Mac"
args="--mac-only"; [ "$YES" = 1 ] && args="$args --yes"; [ "$CHECK" = 1 ] && args="$args --check"
bash "$SETUP" $args; rc=$?
if [ "$rc" = 1 ]; then
  echo
  say "Rosetta 2 is Apple's translator for Intel programs. The game cannot run without it, and this Mac does not have it."
  say "Installing it accepts Apple's licence for it."
  if [ "$CHECK" = 1 ]; then say "The installer would offer to install it."
  else
    ans=n
    if [ "$YES" = 1 ]; then ans=y
    elif [ -t 0 ]; then printf '  To install it now, type y and press Return. Anything else stops here. '; read -r ans || ans=n
    fi
    case "$ans" in
      y|Y) softwareupdate --install-rosetta --agree-to-license || { say "!! Rosetta could not be installed."; exit 1; }
           bash "$SETUP" --mac-only --yes > /dev/null 2>&1 || { say "!! Rosetta is still missing."; exit 1; }
           say "Rosetta 2: OK" ;;
      *) say "To install it later, run this in Terminal:  softwareupdate --install-rosetta --agree-to-license"; exit 3 ;;
    esac
  fi
elif [ "$rc" != 0 ]; then say "!! the check of this Mac failed (exit $rc)"; exit 1
fi

# --- step 2: Apple's Command Line Tools (python3 for the patches)
stage 2 "Apple's Command Line Tools"
py_ok() {
if python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 8))' >/dev/null 2>&1; then
  return 0
fi
return 1
}
if xcode-select -p > /dev/null 2>&1; then   # first: without the tools, running python3 opens Apple's window itself
  py_ok || { say "!! Apple's Command Line Tools are installed, but their python3 does not run. Reinstall them, then open the installer again."; exit 1; }
  say "OK"
elif [ "$CHECK" = 1 ]; then say "missing: the installer would ask Apple for them"
else
  xcode-select --install > /dev/null 2>&1
  say "A box from Apple has opened; it may be behind this window. Press Install, then Agree."
  say "The download comes from Apple and can take 10 minutes or more. This window goes on by itself when it is done."
  i=0
  until xcode-select -p > /dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -gt "$TOOLS_POLLS" ] && { say "Apple's Command Line Tools are not installed yet."; exit 4; }
    sleep "$POLL"
  done
  py_ok || { say "!! Apple's Command Line Tools are installed, but their python3 does not run. Reinstall them, then open the installer again."; exit 1; }
  say "OK"
fi

FREE_KB="$(df -k "$HOME" 2>/dev/null | awk 'NR == 2 { print $4 }')"
case "$FREE_KB" in ''|*[!0-9]*) ;; *)
  if [ "$((FREE_KB / 1024 / 1024))" -lt "$NEED_GB" ]; then
    echo; say "CAUTION: $((FREE_KB / 1024 / 1024)) GB free. The game with its DLC takes about 100 GB, and Wine and Steam about 5 GB more."
  fi ;;
esac

# --- step 3: Wine
stage 3 "Wine, which runs Windows programs (about 235 MB)"
if [ -d "$W" ]; then say "OK: $(tilde "$W")"
elif [ "$CHECK" = 1 ]; then bash "$MAKE_WRAPPER" --wrapper "$W" --check; rc=$?; [ "$rc" = 3 ] && exit 3
else
  bash "$MAKE_WRAPPER" --wrapper "$W"; rc=$?
  [ "$rc" = 3 ] && exit 3
  [ "$rc" = 0 ] || exit 1
  W="$(cd "$W" && pwd -P)"
  use_wrapper "$W"
fi

if [ "$CHECK" = 1 ] && [ ! -d "$W" ]; then
  stage 4 "Steam for Windows"; say "would be downloaded from Valve and installed in the new wrapper"
  stage 5 "The game"; say "would wait for you to sign in to Steam and press Install"
  stage 6 "The Mac fixes and the game's app"; say "would run setup.sh"
  exit 0
fi
if [ "$CHECK" = 0 ]; then
LOCK="$WINEPREFIX/.launcher.lock"
  acquire_lock 1 || { say "!! Another launch or install is using this wrapper (process $(lock_holder)). Wait for it to finish, then try again."; exit 3; }
fi

# --- step 4: Steam for Windows
stage 4 "Steam for Windows"
if [ -f "$STEAMDIR/steam.exe" ] || [ -f "$STEAMDIR/Steam.exe" ]; then say "OK"
elif [ "$CHECK" = 1 ]; then say "would be downloaded from Valve and installed in the wrapper"
else
  D="$(mktemp -d "${TMPDIR:-/tmp}/1launcher-steam.XXXXXX")" || { say "!! a temporary folder could not be made"; exit 1; }
  got=0
  for u in $STEAM_URLS; do
    curl --proto '=https' --tlsv1.2 -fsSL --retry 2 -o "$D/SteamSetup.exe" "$u" && { got=1; break; }
  done
  if [ "$got" = 0 ]; then rm -rf "$D"; say "!! Steam's installer could not be downloaded from Valve. Check the network, then open the installer again."; exit 1; fi
  sz="$(stat -f %z "$D/SteamSetup.exe")"
  if [ "$sz" -le 1048576 ] || [ "$(head -c 2 "$D/SteamSetup.exe")" != MZ ] || ! grep -q -a 'Valve Corp' "$D/SteamSetup.exe"; then
    rm -rf "$D"; say "!! the file downloaded from Valve is not Steam's installer (a cut download, or an error page)"; exit 1
  fi
  s="$(shasum -a 256 "$D/SteamSetup.exe" | awk '{ print $1 }')"
  say "Steam's installer: $sz bytes, sha256 $s"
  [ "$s" = "$STEAM_TESTED_SHA" ] || say "CAUTION: this is a newer installer from Valve than the one this was tested with."
  "$WINE" "$D/SteamSetup.exe" /S > /dev/null 2>&1; rc=$?
  wsrv -w > /dev/null 2>&1
  rm -rf "$D"
  [ "$rc" = 0 ] || { say "!! Steam's installer exited $rc"; exit 1; }
  if [ -f "$STEAMDIR/steam.exe" ] || [ -f "$STEAMDIR/Steam.exe" ]; then say "OK"
  else say "!! Steam's installer left no steam.exe"; exit 1; fi
fi

# --- step 5: the game
stage 5 "The game"
STATE="$(game_state)"
case "$STATE" in
  installed) say "OK" ;;
  update) say "Steam has a game update waiting. The game's app offers it at the next start." ;;
  *)
    if [ "$CHECK" = 1 ]; then say "not installed: would start Steam and wait for you to sign in and press Install"; else
    say "Steam for Windows is starting. A small box headed \"Steam - Fatal Error\" can appear once or twice"
    say "and close again. That is expected: Steam is updating itself. Click nothing in it."
    up=0
    if webhelper_up; then up=1
    elif steam_proc_up; then   # a Steam already there: up, or stuck at its box
      i=0
      while [ "$i" -lt "$STUCK_POLLS" ]; do
        sleep "$POLL"; i=$((i + 1))
        webhelper_up && { up=1; break; }
      done
      [ "$up" = 1 ] || end_steam
    fi
    if [ "$up" = 0 ]; then
      start_until_up || {
        end_steam
        say "!! Steam did not start after $MAX_STARTS tries. The last lines of its log:"
        tail -n 20 "$BOOTLOG" 2>/dev/null | sed 's/^/     /'
        exit 1
      }
    fi
    cat << 'WORDS'
  When Steam's sign-in window appears:
    1. Sign in with the Steam account that owns Cities: Skylines II. Tick "Remember me".
       Steam may ask for a code from your email or the Steam app on your phone.
    2. Click Library, then Cities: Skylines II, then the blue Install button, then Install.
       The download is about 100 GB and takes hours.
    3. When it finishes Steam shows a green Play button. Do not press it: it does not work from
       inside Steam. This window sees the download finish, closes Steam, and goes on to step 6.
  Leave this window open. The Mac is kept awake while it runs.
WORDS
    gone=0; last=""; said_wait=""; said_ready=""
    while :; do
      [ "$(game_state)" = installed ] && break
      if [ ! -f "$MANIFEST" ]; then
        [ -n "$said_wait" ] || { say "Waiting for you to choose Install in Steam"; said_wait=1; }
      else
        to="$(acf_field BytesToDownload)"; done_b="$(acf_field BytesDownloaded)"
        case "$to" in ''|*[!0-9]*) to=0 ;; esac
        case "$done_b" in ''|*[!0-9]*) done_b=0 ;; esac
        if [ "$to" = 0 ]; then
          [ -n "$said_ready" ] || { say "Steam is getting the download ready"; said_ready=1; }
        else
          pct="$(awk -v d="$done_b" -v t="$to" 'BEGIN { printf "%d", d * 100 / t }')"
          if [ "$pct" != "$last" ]; then
            say "$(awk -v d="$done_b" -v t="$to" 'BEGIN { printf "%.1f of %.1f GB (%d%%)", d / 1e9, t / 1e9, d * 100 / t }')"
            last="$pct"
          fi
        fi
      fi
      if steam_proc_up || webhelper_up; then gone=0
      else
        gone=$((gone + 1))
        [ "$gone" -ge "$GONE_POLLS" ] && { say "Steam closed before the game finished downloading."; exit 4; }
      fi
      sleep "$POLL"
      trace download
    done
    say "The game is installed. Closing Steam."
    "$WINE" "$(steam_exe)" -shutdown > /dev/null 2>&1
    i=0; while [ "$i" -lt 20 ] && steam_proc_up; do sleep 1; i=$((i + 1)); done
    if steam_proc_up; then
      wsrv -k > /dev/null 2>&1
      i=0; while [ "$i" -lt 10 ] && steam_proc_up; do sleep 1; i=$((i + 1)); done
    fi
    strays="$(steam_family)"
    if [ -n "$strays" ]; then
      wsrv -k > /dev/null 2>&1
      sleep 2
      strays="$(steam_family)"
      [ -n "$strays" ] && $KILL_CMD $strays 2>/dev/null   # plain TERM, never -9: a 0-byte .crash stops the next start
    fi
    wsrv -w > /dev/null 2>&1 &
    w=$!; i=0; while kill -0 "$w" 2>/dev/null && [ "$i" -lt 15 ]; do sleep 1; i=$((i + 1)); done
    say "OK"
    fi ;;
esac

# --- step 6: setup
stage 6 "The Mac fixes and the game's app"
if [ "$CHECK" = 1 ]; then say "would run setup.sh"; exit 0; fi
if [ "$NO_SETUP" = 1 ]; then END=quiet; say "Stopped before step 6, as asked."; exit 0; fi
if prefix_known && game_running; then say "!! The game is running. Quit it, then open the installer again."; exit 3; fi
for f in "$SETUP" "$GAME_ROOT/repatch.sh" "$GAME_ROOT/patches" "$GAME_ROOT/../common/make-launcher-app.sh"; do
  [ -e "$f" ] || { say "The installer's own files are gone (macOS clears old temporary files)."; exit 4; }
done
set --
[ "$YES" = 1 ] && set -- "$@" --yes
[ "$DESKTOP" = 1 ] && set -- "$@" --desktop
CS2_VIA_INSTALLER=1 bash "$SETUP" "$@"
exit $?
