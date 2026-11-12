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
#   or nobody to ask) or because the game, another install, or another wrapper's Steam is running; 4 = it
#   cannot go on by itself: open the installer again to carry on. --check exits 0 after its report, or 1
#   or 3 for the refusals that come before it.
# CS2_WRAPPER=<absolute path> names the wrapper, made in step 3 if absent. L1_TRACE=<file> gets one line per
# poll while Steam starts and downloads (the live check of the plan's NL1).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME_ROOT="$(cd "$HERE/.." && pwd)"
SETUP="$HERE/setup.sh"
# --- this game's settings (docs/plans/shared-installer.md, 2.1)
GAME_TITLE="Cities: Skylines II"
GAME_APPID=949230
GAME_DIR="Cities Skylines II"
GAME_EXE="Cities2.exe"
WRAPPER_VAR=CS2_WRAPPER
STEPS=6
NEED_GB=110
ENGINE_URL="https://github.com/vitor251093/porting-kit-engines/releases/download/wineskin/WS12Wine11.0_DXMT-v0.80.tar.7z"
ENGINE_BYTES=180784324
ENGINE_SHA=afdaab97e84ec7064b8fddf47192c95b18b8bbb9cc3aa4d81060a57d7b4dced0
WORDS_NEED="about 105 GB free, and time for a download of about 100 GB"
WORDS_SPACE="The game with its DLC takes about 100 GB, and Wine and Steam about 5 GB more."
WORDS_WINE="about 235 MB"
WORDS_DOWNLOAD="The download is about 100 GB and takes hours."
WORDS_DONE="Cities Skylines II, or 14unch3r"
TOOLS_PART=python3          # what this game needs of Apple's Command Line Tools: python3, for the patches
STEAM_ARGS="-no-cef-sandbox"
TAKES_DESKTOP=1             # setup.sh takes --desktop

# --- copies of the launcher's own functions (cities-skylines-2/launchers/launch-cs2-dxmt11.sh); test-install.sh
# --- holds them identical to it
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
game_running() { local p; for p in $(pgrep -f 'Cities2\.exe' 2>/dev/null); do lsof -p "$p" 2>/dev/null | grep -q "$WINEPREFIX" && return 0; done; return 1; }
game_env() {   # the launcher's exports for the wrapper at $APP
  export WINE="$SS/wine/bin/wine64"
  export WINEPREFIX="$SS/prefix"
  export PATH="$SS/wine/bin:$PATH"
  export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"
  export WINEDEBUG="${WINEDEBUG:--all}"
  export WINEDLLOVERRIDES="winemenubuilder.exe=d"
}
py_ok() {
if python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 8))' >/dev/null 2>&1; then
  return 0
fi
return 1
}
tools_ok() { py_ok; }
words_play() {   # <the step after the game's>
cat << WORDS
    3. When it finishes Steam shows a green Play button. Do not press it: it does not work from
       inside Steam. This window sees the download finish, closes Steam, and goes on to step $1.
WORDS
}
game_wrapper() {   # sets W: the launcher's choice, else ~/Applications/CS2dxmt11.app
W="$(find_wrapper)"
HOLDS="Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II/Cities2.exe"
if [ -n "${CS2_WRAPPER:-}" ]; then W="${CS2_WRAPPER%/}"
elif [ "$W" = "$HOME/Applications/CS2dxmt11.app" ]; then :
elif [ -n "$W" ] && [ -f "$W/$HOLDS" ]; then say "Using $(tilde "$W"), which holds the game."
else W="$HOME/Applications/CS2dxmt11.app"
fi
}

. "$GAME_ROOT/../common/install-core.sh"

core_begin
core_mac 1
core_tools 2
core_space
core_wine 3
if [ "$CHECK" = 1 ] && [ ! -d "$W" ]; then
  stage 4 "Steam for Windows"; say "would be downloaded from Valve and installed in the new wrapper"
  stage 5 "The game"; say "would wait for you to sign in to Steam and press Install"
  stage 6 "The Mac fixes and the game's app"; say "would run setup.sh"
  exit 0
fi
core_lock
core_steam 4
core_game 5

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
