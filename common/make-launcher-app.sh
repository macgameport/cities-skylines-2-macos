#!/bin/bash
# make-launcher-app.sh -- build 14unch3r.app, one window that lists every game set up on this Mac and starts
# the one chosen (docs/plans/launcher-window.md, 2.3). It compiles common/launcher-window.swift into the app,
# copies common/games.tsv beside it, draws the app's icon with the program it just built, and writes the
# Info.plist. Cities: Skylines II's setup.sh runs it after building that game's app.
#
#   bash common/make-launcher-app.sh                    # ~/Applications/14unch3r.app
#   bash common/make-launcher-app.sh --dest <folder>    # build somewhere else (testing)
#   bash common/make-launcher-app.sh --name <name>      # another file and display name
#
#   exit 0 = built; 1 = refused or not built, and said; 2 = a wrong option; 3 = skipped, and said: swiftc or
#   the source is missing, or the compile failed. setup.sh counts none of these as a problem: the games' own
#   apps do not need the window.
#
# It replaces only its own app. The target must be absent, or a folder that is not a symlink, has no
# Contents/SharedSupport (every Wine wrapper has one) and carries this app's identifier. It builds in a
# hidden folder inside --dest, removed when it exits, and swaps the finished app in, so a build that fails
# leaves an older app as it was. A bundle is never moved onto a bundle: mv then puts it inside (X.app/X.app)
# and exits 0. L1_WINDOW_SRC names another source file, for common/test-make-launcher-app.sh.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${L1_WINDOW_SRC:-$HERE/launcher-window.swift}"
GAMES="$HERE/games.tsv"
DEST="$HOME/Applications"
NAME="14unch3r"
ID="local.1launcher.window"

need_value() {   # <option> [<value> ...]: an option that takes a value must be given a non-empty one
  if [ $# -lt 2 ] || [ -z "$2" ]; then echo "$1 needs a value"; exit 2; fi
}
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) need_value "$@"; DEST="$2"; shift 2 ;;
    --name) need_value "$@"; NAME="$2"; shift 2 ;;
    -h|--help) sed -n '2,/^set -u$/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)"; exit 2 ;;
  esac
done
case "$NAME" in   # it becomes a file name in --dest and the app's name, so it is checked before anything is removed
  ''|*/*|.*|-*|*[[:cntrl:]]*) echo "--name must not be empty, hold / or a control character, or start with . or -"; exit 2 ;;
esac
DEST="${DEST%/}"
APP="$DEST/$NAME.app"

own_app() {   # <target>: 0 when it is absent or this builder's own app
  local t="$1" id
  [ -e "$t" ] || [ -L "$t" ] || return 0
  { [ -d "$t" ] && [ ! -L "$t" ]; } || return 1
  { [ ! -e "$t/Contents/SharedSupport" ] && [ ! -L "$t/Contents/SharedSupport" ]; } || return 1
  id=$(plutil -extract CFBundleIdentifier raw "$t/Contents/Info.plist" 2>/dev/null) || return 1
  [ "$id" = "$ID" ]
}

echo "=== building $APP ==="
if ! own_app "$APP"; then
  echo "ERROR: $APP exists and was not built by this script; nothing removed"
  echo "If it is a leftover of this script, move it to the Trash and run this again."
  exit 1
fi
skip() { echo "    window: skipped ($1); nothing was changed"; exit 3; }
xcrun -f swiftc >/dev/null 2>&1 || skip "swiftc is missing: install the Xcode Command Line Tools"
[ -f "$SRC" ] || skip "common/launcher-window.swift is missing from this checkout"

mkdir -p "$DEST" || { echo "ERROR: cannot make $DEST"; exit 1; }
B="$(mktemp -d "$DEST/.14unch3r-build.XXXXXX")" || { echo "ERROR: cannot make a build folder in $DEST"; exit 1; }
trap 'rm -rf "$B"' EXIT
NEW="$B/$NAME.app"
mkdir -p "$NEW/Contents/MacOS" "$NEW/Contents/Resources"
EXE="$NEW/Contents/MacOS/launcher-window"
if ! xcrun swiftc -O -o "$EXE" "$SRC" > "$B/compile.log" 2>&1; then
  skip "the compile failed: $(grep -m1 'error:' "$B/compile.log" | sed 's/^.*error: //')"
fi
echo "    program:  compiled"

if [ -f "$GAMES" ]; then
  cp "$GAMES" "$NEW/Contents/Resources/games.tsv"
  echo "    games:    the table of ported games copied in"
else
  echo "    games:    common/games.tsv is missing, so the window will offer no games to set up"
fi

# The icon: the program draws it (launcher-window --icon, docs/plans/launcher-window.md, 2.6), sips scales it
# and iconutil packs it, as the game builders do with a game's own icon. No image file is in the repository.
ICON_OK=0
if "$EXE" --icon "$B/icon.png" > /dev/null 2>&1 && [ -f "$B/icon.png" ]; then
  ISET="$B/14unch3r.iconset"; mkdir -p "$ISET"
  for sz in 16 32 128 256 512; do
    sips -z $sz $sz "$B/icon.png" --out "$ISET/icon_${sz}x${sz}.png" > /dev/null 2>&1
    sips -z $((sz * 2)) $((sz * 2)) "$B/icon.png" --out "$ISET/icon_${sz}x${sz}@2x.png" > /dev/null 2>&1
  done
  iconutil -c icns "$ISET" -o "$NEW/Contents/Resources/14unch3r.icns" > /dev/null 2>&1 && ICON_OK=1
fi
if [ "$ICON_OK" = 1 ]; then echo "    icon:     drawn"; else echo "    icon:     skipped (drawing or packing it failed); the app keeps the generic icon"; fi

# The heredoc holds constants only; the name comes from --name, so plutil writes it and escapes it.
PL="$NEW/Contents/Info.plist"
not_built() { echo "ERROR: $PL is not a valid property list; the app was not built"; exit 1; }
cat > "$PL" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>      <string>local.1launcher.window</string>
    <key>CFBundleExecutable</key>      <string>launcher-window</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleVersion</key>         <string>1.0</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>CFBundleAlternateNames</key>
    <array>
        <string>1launcher</string>
        <string>launcher</string>
        <string>game launcher</string>
    </array>
</dict>
</plist>
PLIST
plutil -replace CFBundleName -string "$NAME" "$PL" > /dev/null 2>&1 || not_built
plutil -replace CFBundleDisplayName -string "$NAME" "$PL" > /dev/null 2>&1 || not_built
if [ "$ICON_OK" = 1 ]; then plutil -replace CFBundleIconFile -string 14unch3r.icns "$PL" > /dev/null 2>&1 || not_built; fi
plutil -lint "$PL" > /dev/null 2>&1 || not_built

# The swap: the old app into the build folder, the new one into its place, the old one back if that fails.
if [ -e "$APP" ]; then
  mv "$APP" "$B/old.app" || { echo "ERROR: could not move the old app aside; nothing was changed"; exit 1; }
  if ! mv "$NEW" "$APP"; then
    mv "$B/old.app" "$APP"
    echo "ERROR: could not move the new app into place; the old one is back"
    exit 1
  fi
else
  mv "$NEW" "$APP" || { echo "ERROR: could not move the new app into place"; exit 1; }
fi
touch "$APP"
echo "=== done ==="
echo "Open: $APP"
