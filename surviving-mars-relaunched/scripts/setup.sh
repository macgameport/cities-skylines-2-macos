#!/bin/bash
# setup.sh -- the last step of an install of Surviving Mars: Relaunched, and the way to update one
# (docs/plans/surviving-mars-install.md, 2.5). It puts the launcher and the click helper where the game's
# app keeps them, builds the app, and builds 14unch3r, the window that lists every game.
#
#   bash scripts/setup.sh              # copy the launcher and the helper, build the app and 14unch3r
#   bash scripts/setup.sh --check      # say what it would do, change nothing
#   bash scripts/setup.sh --yes        # do not stop to ask when this Mac is outside what has been tested
#   bash scripts/setup.sh --mac-only   # check this Mac only (Apple Silicon, macOS, Rosetta), then stop
#
#   exit 0 = done (or, with --mac-only, this Mac is ready); 1 = something failed or is missing, said which
#   (with --mac-only: only Rosetta 2 is missing); 2 = a wrong option; 3 = it will not go on: an Intel Mac, a
#   macOS below 14, the game running, or a launch or an install using the wrapper.
#
# The app runs a copy. The launcher and tools/frame-fix.exe are copied into the game's state folder,
# ~/Library/Application Support/1launcher/surviving-mars-relaunched/ (where runs/ and backup/ already are,
# and which setup never touches), and the app is built to run that copy. So an app made by the installer
# does not need the folder it was installed from, and every Mac runs the game the same way. After
# `git pull`, a maintainer runs setup again. A copy is never written over a file in place: it is written
# beside it and renamed over it, because a launcher goes on reading its own file after the game exits.
#
# Read from the environment: SM_VIA_INSTALLER=1, set by scripts/install.sh, which holds the wrapper's lock
# while it runs setup and has already asked the question about this Mac; SM_STATE, SM_APP and SM_WRAPPER,
# which name another state folder, app and wrapper (tests). With SM_APP set, 14unch3r is built in that
# app's folder.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME_ROOT="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$GAME_ROOT/.." && pwd)"
TESTED=27   # the macOS this has been run on (README.md, "What it assumes")

MAC_ONLY=0; YES=0; CHECK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --mac-only) MAC_ONLY=1; shift ;;
    --yes) YES=1; shift ;;
    --check) CHECK=1; shift ;;
    -h|--help) sed -n '2,/^set -u$/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)"; exit 2 ;;
  esac
done
[ "$(id -u)" = 0 ] && { echo "  !! Do not run setup as root (with sudo): it would leave files only root can change in your home folder."; exit 1; }

say() { printf "  %-28s %s\n" "$1" "$2"; }
# a path as printed: the home folder as ~, so that output pasted into an issue does not carry the user's name
tilde() { case "$1" in "$HOME") printf '~' ;; "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }

# --- this Mac
[ "$(uname -s)" = Darwin ] || { echo "  !! This only runs on macOS."; exit 3; }
cautions=0
# sysctl, not uname -m: in a shell that itself runs under Rosetta, uname says x86_64 on Apple Silicon
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" != 1 ]; then
  echo "  !! This Mac has an Intel processor. Wine for this game, and Apple's D3DMetal, need an Apple Silicon Mac (M1 or later)."
  exit 3
fi
say "Apple Silicon" "OK"
OSV="$(sw_vers -productVersion 2>/dev/null)"; OSMAJ="${OSV%%.*}"
case "$OSMAJ" in
  ''|*[!0-9]*) say "macOS version" "CAUTION"; echo "      -> it could not be read, so this Mac cannot be compared with what has been tested."; cautions=1 ;;
  *) if [ "$OSMAJ" -lt 14 ]; then
       echo "  !! macOS $OSV: Apple's D3DMetal 3.0 does not load below macOS 14. Update macOS, then try again."
       exit 3
     elif [ "$OSMAJ" = "$TESTED" ]; then say "macOS $OSV" "OK (tested)"
     elif [ "$OSMAJ" -gt "$TESTED" ]; then
       say "macOS $OSV" "CAUTION"; cautions=1
       echo "      -> newer than anything this has been run on. Apple has said macOS $TESTED is the last release with general Rosetta support."
     else
       say "macOS $OSV" "CAUTION"; cautions=1
       echo "      -> older than anything this has been run on (macOS $TESTED). It may work: D3DMetal's own minimum is macOS 14."
     fi ;;
esac
ROSETTA=1; arch -x86_64 /usr/bin/true 2>/dev/null || ROSETTA=0
if [ "$ROSETTA" = 1 ]; then say "Rosetta 2" "OK"; else say "Rosetta 2" "MISSING"; fi
if [ "$cautions" -gt 0 ]; then
  echo "  This Mac is outside what this project has been tested on. Setup can go on; the game may still not start."
  if [ "$YES" = 0 ] && [ "$CHECK" = 0 ] && [ "${SM_VIA_INSTALLER:-0}" != 1 ] && [ -t 0 ]; then
    printf '  Press Return to continue, or Control-C to stop. (--yes skips this question.) '
    read -r _ || true
  fi
fi
if [ "$MAC_ONLY" = 1 ]; then   # scripts/install.sh, step 1: this Mac alone
  [ "$ROSETTA" = 1 ] || exit 1
  exit 0
fi
[ "$ROSETTA" = 1 ] || { echo "      -> the game cannot run without it. Install it:  softwareupdate --install-rosetta --agree-to-license"; exit 1; }

# --- what must not be happening: the game running, or a launch or an install using the wrapper
WRAPPER="${SM_WRAPPER:-$HOME/Applications/SurvivingMars.app}"
GAME="$WRAPPER/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Project Spark"
# --- the launcher's own function (launch-relaunched.sh); scripts/test-setup.sh holds it identical
game_running() {
  for _p in $(pgrep -f 'Mars\.exe' 2>/dev/null); do
    case "$(ps -o command= -p "$_p" 2>/dev/null)" in
      "$GAME/Mars.exe"*|'C:\'*'\Project Spark\Mars.exe'*) return 0 ;;
    esac
  done
  return 1
}
if game_running; then echo "  !! The game is running. Quit it, then run setup again."; exit 3; fi
h="$(readlink "$WRAPPER/Contents/SharedSupport/prefix/.launcher.lock" 2>/dev/null)"
if [ -n "$h" ] && kill -0 "$h" 2>/dev/null; then
  # the installer holds the lock while it runs setup: its lock, and no other, is passed
  if [ "${SM_VIA_INSTALLER:-0}" != 1 ] || [ "$h" != "$PPID" ]; then
    echo "  !! A launch or an install is using the game's wrapper (process $h). Wait for it to finish, then run setup again."
    exit 3
  fi
fi

# --- the state folder: the user's own, and nobody else may write to it
STATE="${SM_STATE:-$HOME/Library/Application Support/1launcher/surviving-mars-relaunched}"
APP="${SM_APP:-$HOME/Applications/Surviving Mars Relaunched.app}"
own_folder() {   # <folder>: 0 when it is a real folder of this user's that group and others cannot write to
  [ -d "$1" ] && [ ! -L "$1" ] || return 1
  [ "$(stat -f %u "$1")" = "$(id -u)" ] || return 1
  case "$(stat -f %Lp "$1")" in *[2367]?|*[2367]) return 1 ;; esac
  return 0
}
for d in "$STATE" "$STATE/tools"; do
  if [ -e "$d" ] || [ -L "$d" ]; then
    own_folder "$d" || { echo "  !! $(tilde "$d") is not a folder of your own that only you can write to; setup will not put the launcher there."; exit 1; }
  fi
done
for f in "$GAME_ROOT/launch-relaunched.sh" "$GAME_ROOT/tools/frame-fix.exe" "$GAME_ROOT/make-app.sh" "$REPO/common/make-launcher-app.sh"; do
  [ -f "$f" ] || { echo "  !! setup's own files are missing ($(tilde "$f")). Open the installer again, or run setup from a whole checkout."; exit 1; }
done
if [ "$CHECK" = 1 ]; then
  echo "  would copy the launcher and the click helper into $(tilde "$STATE")"
  echo "  would build $(tilde "$APP") and 14unch3r beside it"
  echo "(--check: stopping before making changes)"
  exit 0
fi

# --- the copies: each written beside the old one and renamed over it, never written in place
for d in "$STATE" "$STATE/tools"; do
  [ -d "$d" ] || { mkdir -p "$d" && chmod go-w "$d"; } || { echo "  !! $(tilde "$d") could not be made."; exit 1; }
done
put() {   # <from> <to>
  local tmp="$2.new.$$"
  if cp "$1" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$2"; then return 0; fi
  rm -f "$tmp"; echo "  !! $(tilde "$2") could not be written."; exit 1
}
put "$GAME_ROOT/launch-relaunched.sh" "$STATE/launch-relaunched.sh"
put "$GAME_ROOT/tools/frame-fix.exe" "$STATE/tools/frame-fix.exe"
say "the launcher and its helper" "in $(tilde "$STATE")"

# --- the game's app, built to run that copy
echo
OUT="$(mktemp /tmp/sm-setup.XXXXXX)" || { echo "  !! no temporary file could be made."; exit 1; }
if ! SM_SCRIPT="$STATE/launch-relaunched.sh" bash "$GAME_ROOT/make-app.sh" > "$OUT" 2>&1; then
  sed 's/^/  /' "$OUT"; rm -f "$OUT"
  echo "  !! The game's app was not built. The lines above say why."
  exit 1
fi
grep -v '^14unch3r: ' "$OUT" | sed "s#$HOME#~#g; s/^/  /"

# --- 14unch3r, beside the game's app. Not building it is not a problem: the game's own app does not need it
if [ -n "${SM_APP:-}" ]; then bash "$REPO/common/make-launcher-app.sh" --dest "$(dirname "$APP")" > "$OUT" 2>&1; rc=$?
else bash "$REPO/common/make-launcher-app.sh" > "$OUT" 2>&1; rc=$?; fi
case "$rc" in
  0) say "14unch3r" "built: one window that lists every game" ;;
  *) say "14unch3r" "not built (the game's own app does not need it):"; sed "s#$HOME#~#g; s/^/      /" "$OUT" ;;
esac
rm -f "$OUT"

if [ "${SM_VIA_INSTALLER:-0}" = 1 ]; then UPDATE="open the installer again."
else UPDATE="after  git pull , run  bash surviving-mars-relaunched/scripts/setup.sh  again."; fi
cat << DONE

=== setup complete ===
The game:   $(tilde "$APP"), also in Spotlight and Launchpad
To update:  $UPDATE
DONE
