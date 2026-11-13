#!/bin/bash
# install.sh -- Surviving Mars: Relaunched from nothing to playable, in seven steps, each skipped when it is
# already done (docs/plans/surviving-mars-install.md, 2.4): this Mac, Apple's Command Line Tools, Wine
# (common/make-wrapper.sh), Apple's D3DMetal 3.0 (tools/fetch-d3dmetal.sh and tools/make-engine.sh), Steam
# for Windows, the game (the player signs in and presses Install; this waits for the download), and
# setup.sh. Open it again after any stop and it carries on from there; on a finished install it is the way
# to update (setup runs every time). No CrossOver and no other game's wrapper is needed.
#
#   bash scripts/install.sh              # the whole install
#   bash scripts/install.sh --check      # say what each step would do; start, download and change nothing
#   bash scripts/install.sh --yes        # install Rosetta and fetch Apple's D3DMetal without asking, and
#                                        # pass --yes to setup
#   bash scripts/install.sh --no-setup   # stop before step 7
#
#   exit 0 = done; 1 = a step failed, said why; 2 = a wrong option; 3 = stopped at a question (answered no,
#   or nobody to ask) or because the game, another install, this wrapper's Steam or another wrapper's Steam
#   is running; 4 = it cannot go on by itself: open the installer again to carry on. --check exits 0 after
#   its report, or 1 or 3 for the refusals that come before it.
# SM_WRAPPER=<absolute path> names another wrapper, made in step 3 if absent. That is a test: the game's
# app starts the default wrapper, so the installer then stops before step 7 and makes no app.
# L1_TRACE=<file> gets one line per poll while Steam starts and downloads.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME_ROOT="$(cd "$HERE/.." && pwd)"
SETUP="$HERE/setup.sh"
FETCH="$GAME_ROOT/tools/fetch-d3dmetal.sh"
MAKE_ENGINE="$GAME_ROOT/tools/make-engine.sh"
# --- this game's settings (docs/plans/shared-installer.md, 2.1)
GAME_TITLE="Surviving Mars: Relaunched"
GAME_APPID=3215050
GAME_DIR="Project Spark"
GAME_EXE="Mars.exe"
WRAPPER_VAR=SM_WRAPPER
STEPS=7
NEED_GB=20
ENGINE_URL="https://github.com/vitor251093/porting-kit-engines/releases/download/wineskin/WS12WineSikarugir10.0_2_D3DMetal-v2.1.tar.7z"
ENGINE_BYTES=183963888
ENGINE_SHA=a2f9322f3e6160453d9b31891e91d17a7c1f0b752c1804416880792c37d125d2
WORDS_NEED="about 20 GB free, and time for a download of about 10 GB"
WORDS_SPACE="The game takes about 11 GB, and Wine and Steam about 3 GB more."   # measured at the plan's ML2
WORDS_WINE="about 237 MB"
WORDS_DOWNLOAD="The download is about 10 GB."
WORDS_DONE="Surviving Mars Relaunched, or 14unch3r"
TOOLS_PART=nm               # what this game needs of Apple's Command Line Tools: nm, for the engine swap
STEAM_ARGS="-no-cef-sandbox"
GPTK_PAGE="https://github.com/Gcenx/game-porting-toolkit/releases/tag/Game-Porting-Toolkit-3.0-3"
# The core exports SM_WRAPPER itself once it has chosen a wrapper (install-core.sh, use_wrapper), so what
# the caller gave is read here, before the core is: whether one was given decides the stop before step 7,
# and the path as the launcher would spell it is what the launcher's game_running looks for.
GIVEN_WRAPPER="${SM_WRAPPER:-}"
SPELLED="${SM_WRAPPER:-$HOME/Applications/SurvivingMars.app}"; SPELLED="${SPELLED%/}"
SM_TMP=""

# --- copies of the launcher's own lines (launch-relaunched.sh); scripts/test-install.sh holds them identical
game_running() {
  for _p in $(pgrep -f 'Mars\.exe' 2>/dev/null); do
    case "$(ps -o command= -p "$_p" 2>/dev/null)" in
      "$GAME/Mars.exe"*|'C:\'*'\Project Spark\Mars.exe'*) return 0 ;;
    esac
  done
  return 1
}
game_env() {   # the launcher's exports for the wrapper at $APP: its ENGINE, always the wrapper's own Wine here
  ENGINE="$SS/wine"
  GAME="$SPELLED/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Project Spark"
export WINEPREFIX="$SS/prefix"
export PATH="$ENGINE/bin:$PATH"
export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$ENGINE/lib:/usr/lib:/usr/local/lib"
# Every wine client must match the wineserver's sync mode: a client started without
# WINEMSYNC/WINEESYNC against an msync wineserver dies with SIGFPE in ntdll.so (2026-11-01).
export WINEESYNC=1 WINEMSYNC=1 D3DMETAL=1 D3DMETAL_FORCE=1 WINEDEBUG=fixme-all
export WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d;winemenubuilder.exe=d"
export SteamAppId=3215050 SteamGameId=3215050 SteamOverlayGameId=3215050
WINE="$ENGINE/bin/wine64"
}
d3dm_ver() {   # <wine folder>: the launcher's own expression, which reads $ENGINE
local ENGINE="$1"
D3DM_VER=$(plutil -extract CFBundleShortVersionString raw "$ENGINE/lib/external/D3DMetal.framework/Versions/A/Resources/Info.plist" 2>/dev/null \
  || plutil -extract CFBundleShortVersionString raw "$ENGINE/lib/external/D3DMetal.framework/Resources/Info.plist" 2>/dev/null || echo none)
}
d3dm_ok() {   # <wine folder>: 0 when its D3DMetal is 3 or later, by the launcher's own pattern
d3dm_ver "$1"
case "$D3DM_VER" in
  [3-9].*) ;;
  *) return 1 ;;
esac
}

# --- this script's own
tools_ok() { nm -gU /usr/lib/dyld > /dev/null 2>&1; }
words_play() {   # <the step after the game's>
cat << WORDS
    3. When it finishes Steam shows a green Play button. Do not press it: this window sees the
       download finish, closes Steam, and goes on to step $1. The game starts from its own app.
WORDS
}
game_cleanup() { [ -n "${SM_TMP:-}" ] && rm -rf "$SM_TMP"; return 0; }   # the core calls it at every exit
wine_whole() { [ -x "$1/Contents/SharedSupport/wine/bin/wine64" ] && [ -x "$1/Contents/SharedSupport/wine/bin/wineserver" ]; }   # the core's test
swap_waiting() { [ -d "$1/Contents/SharedSupport/wine.new" ] && [ -e "$1/Contents/SharedSupport/wine.d3dm21-BAK" ]; }
game_wrapper() {   # sets W. An engine swap stopped part way is finished here, before the core judges the wrapper
W="$SPELLED"
swap_waiting "$W" || return 0
# LOCK and WINEPREFIX are not set yet: the link is read as it is
_h="$(readlink "$W/Contents/SharedSupport/prefix/.launcher.lock" 2>/dev/null)"
if [ -n "$_h" ] && [ "$_h" != "$$" ] && kill -0 "$_h" 2>/dev/null; then
  say "!! Another launch or install is using this wrapper (process $_h). Wait for it to finish, then try again."
  exit 3
fi
if [ "$CHECK" = 1 ]; then
  say "$(tilde "$W"): an engine swap was stopped part way. The installer would finish it."
  wine_whole "$W" || exit 0   # the core would call the wrapper incomplete
  return 0
fi
if _out="$(bash "$MAKE_ENGINE" --install "$W" 2>&1)"; then
  say "Finished the engine swap that was stopped part way."
else
  printf '%s\n' "$_out" | sed "s#$HOME#~#g; s/^/  /"
  say "!! The engine swap that was stopped part way could not be finished. Quit whatever uses this wrapper, then open the installer again."
  exit 3
fi
}

. "$GAME_ROOT/../common/install-core.sh"

core_begin
core_mac 1
core_tools 2
core_space

# --- before anything of Apple's is fetched, the installer asks: once, and not when steps 3 and 4 are done
if [ ! -d "$W" ] || ! d3dm_ok "$W/Contents/SharedSupport/wine"; then
  echo
  say "Wine for this game comes with Apple's D3DMetal, a part of Apple's Game Porting Toolkit. Version 2.1 comes"
  say "inside Porting Kit's Wine, and version 3.0 from Gcenx's release page; neither comes from Apple directly."
  say "Apple's licence for it is linked from that page:"
  say "  $GPTK_PAGE"
  say "It allows using the toolkit to develop, test or evaluate games on a Mac. By using it you agree to it;"
  say "if you do not agree, do not fetch it."
  if [ "$CHECK" = 1 ]; then say "The installer would ask before fetching it."
  else
    ans=n
    if [ "$YES" = 1 ]; then ans=y
    elif [ -t 0 ]; then printf '  To fetch it, type y and press Return. Anything else stops here. '; read -r ans || ans=n
    fi
    case "$ans" in
      y|Y) ;;
      *) say "Nothing of Apple's was fetched. To go on later, open the installer again."; exit 3 ;;
    esac
  fi
fi

core_wine 3
if [ "$CHECK" = 1 ] && [ ! -d "$W" ]; then
  stage 4 "Apple's D3DMetal 3.0"; say "would be fetched from Gcenx's release page and put into the new wrapper's Wine"
  stage 5 "Steam for Windows"; say "would be downloaded from Valve and installed in the new wrapper"
  stage 6 "The game"; say "would wait for you to sign in to Steam and press Install"
  stage 7 "The game's app"; say "would run setup.sh"
  exit 0
fi
core_lock

# --- step 4: Apple's D3DMetal 3.0, with the lock held
stage 4 "Apple's D3DMetal 3.0"
if d3dm_ok "$SS/wine"; then say "OK: D3DMetal $D3DM_VER"
elif [ "$CHECK" = 1 ]; then say "D3DMetal $D3DM_VER: version 3.0 would be fetched from Gcenx's release page and put into the wrapper's Wine"
else
  # nothing of Wine may hold the wrapper: make-engine.sh's own test, waited for up to 10 s
  i=0
  while :; do
    held=""
    for p in $(pgrep -f -i 'wine|steam|\.exe' 2>/dev/null); do
      lsof -p "$p" 2>/dev/null | grep -qF "$SS/" && { held="$p"; break; }
    done
    [ -z "$held" ] && break
    if steam_proc_up || webhelper_up; then say "!! Steam is open in this wrapper. Quit it, then open the installer again."; exit 3; fi
    i=$((i + 1))
    [ "$i" -gt 10 ] && { say "!! Something of Wine is still using this wrapper (process $held). Quit it, then open the installer again."; exit 3; }
    sleep 1
  done
  _t="${TMPDIR:-/tmp}"   # macOS's ends with a slash
  SM_TMP="$(mktemp -d "${_t%/}/1launcher-d3dmetal.XXXXXX")" || { say "!! A temporary folder could not be made."; exit 1; }
  bash "$FETCH" --into "$SM_TMP/pieces" || exit 1
  [ -d "$SM_TMP/pieces/lib/external/D3DMetal.framework" ] || { say "!! The fetched pieces are not where they should be."; exit 1; }
  set -- --install "$W"
  [ -e "$SS/wine.d3dm21-BAK" ] && set -- "$@" --rebuild
  CX_GPTK="$SM_TMP/pieces/lib" bash "$MAKE_ENGINE" "$@" > "$SM_TMP/make-engine.out" 2>&1; rc=$?
  grep -E '^(source Wine |D3DMetal    ): ' "$SM_TMP/make-engine.out" | sed "s#$HOME#~#g; s/^/  /"
  if [ "$rc" != 0 ]; then
    say "!! Apple's D3DMetal 3.0 could not be put into the wrapper's Wine (exit $rc). The last lines of that step:"
    tail -n 20 "$SM_TMP/make-engine.out" | sed "s#$HOME#~#g; s/^/     /"
    exit 1
  fi
  d3dm_ok "$SS/wine" || { say "!! The wrapper's D3DMetal still reads $D3DM_VER."; exit 1; }
  for f in external/libd3dshared.dylib wine/x86_64-windows/atidxx64.dll wine/x86_64-windows/d3d11.dll \
           wine/x86_64-windows/d3d12.dll wine/x86_64-windows/dxgi.dll; do
    cmp -s "$SM_TMP/pieces/lib/$f" "$SS/wine/lib/$f" || { say "!! $f in the wrapper is not the fetched file."; exit 1; }
  done
  say "OK: D3DMetal $D3DM_VER"
fi

core_steam 5
core_game 6

# --- step 7: setup
stage 7 "The game's app"
if [ "$CHECK" = 1 ]; then say "would run setup.sh"; exit 0; fi
if [ "$NO_SETUP" = 1 ]; then END=quiet; say "Stopped before step 7, as asked."; exit 0; fi
if [ -n "$GIVEN_WRAPPER" ]; then
  END=quiet
  say "Stopped before step 7: SM_WRAPPER names another wrapper, and the game's app starts the default one."
  say "So an install into $(tilde "$W") is a test, and gets no app."
  exit 0
fi
if prefix_known && game_running; then say "!! The game is running. Quit it, then open the installer again."; exit 3; fi
for f in "$SETUP" "$GAME_ROOT/launch-relaunched.sh" "$GAME_ROOT/make-app.sh" "$GAME_ROOT/tools/frame-fix.exe" \
         "$MAKE_ENGINE" "$FETCH" "$GAME_ROOT/../common/make-launcher-app.sh"; do
  [ -e "$f" ] || { say "The installer's own files are gone (macOS clears old temporary files)."; exit 4; }
done
set --
[ "$YES" = 1 ] && set -- "$@" --yes
SM_VIA_INSTALLER=1 bash "$SETUP" "$@"
exit $?
