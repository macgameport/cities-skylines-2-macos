#!/bin/bash
# test-make-launcher-app.sh -- common/make-launcher-app.sh builds 14unch3r.app (docs/plans/launcher-window.md,
# 2.3 and 2.6; W6). Every build goes into a scratch folder, from a scratch copy of common/ that a mutant may
# edit, with HOME at a scratch folder. The built program is only asked for --folders, --list and --icon: the
# window itself is never opened. No game, no Steam, no Wine.
#   bash common/test-make-launcher-app.sh            exit 0 = every case passed; exit 2 = swiftc is missing,
#                                                    which is not a pass: nothing was tested
#   MUTANT=1 ...   the app is built straight into the target, not in a build folder; must exit 1
#   MUTANT=2 ...   the new app is moved onto the old one (mv nests it); must exit 1
#   MUTANT=3 ...   a skipped build exits 0; must exit 1
#   MUTANT=4 ...   the own-app test is dropped (a wrapper at the target is replaced); must exit 1
#   MUTANT=5 ...   the window's own folder is not among the folders it reads; must exit 1
#   MUTANT=6 ...   the name check is dropped (a name starting with - builds); must exit 1
#   MUTANT=7 ...   CFBundleIconFile is written when the icon failed; must exit 1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
for f in make-launcher-app.sh launcher-window.swift games.tsv; do
  [ -f "$HERE/$f" ] || { echo "REFUSED: common/$f not found"; exit 2; }
done
xcrun -f swiftc >/dev/null 2>&1 || { echo "REFUSED: swiftc is missing (install the Xcode Command Line Tools); nothing was tested"; exit 2; }
T="$(mktemp -d /tmp/make-launcher-app-test.XXXX)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/repo/common" "$T/home/Applications"
cp "$HERE/make-launcher-app.sh" "$HERE/launcher-window.swift" "$HERE/games.tsv" "$T/repo/common/"
BUILDER="$T/repo/common/make-launcher-app.sh"; SRC="$T/repo/common/launcher-window.swift"

mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
drop() {   # <file> <fixed text>: delete the one line that holds it
  [ "$(grep -cF -- "$2" "$1")" = 1 ] || mutated
  grep -vF -- "$2" "$1" > "$1.new" && mv "$1.new" "$1"
}
case "${MUTANT:-0}" in
  0) ;;
  1) sed -i '' 's|^NEW="\$B/\$NAME.app"$|NEW="$APP"|' "$BUILDER"; grep -q '^NEW="\$APP"$' "$BUILDER" || mutated ;;
  2) sed -i '' 's|^if \[ -e "\$APP" \]; then$|if false; then|' "$BUILDER"; grep -q '^if false; then$' "$BUILDER" || mutated ;;
  3) sed -i '' 's|; exit 3; }$|; exit 0; }|' "$BUILDER"; grep -q '^skip() { .*; exit 0; }$' "$BUILDER" || mutated ;;
  4) sed -i '' 's|^if ! own_app "\$APP"; then$|if false; then|' "$BUILDER"; grep -q '^if false; then$' "$BUILDER" || mutated ;;
  5) sed -i '' 's|^    if let b = ownBundle() {|    if false, let b = ownBundle() {|' "$SRC"; grep -q '^    if false, let b = ownBundle() {' "$SRC" || mutated ;;
  6) drop "$BUILDER" 'echo "--name must not be empty' ;;
  7) sed -i '' 's|^if \[ "\$ICON_OK" = 1 \]; then plutil -replace CFBundleIconFile|if true; then plutil -replace CFBundleIconFile|' "$BUILDER"
     grep -q '^if true; then plutil -replace CFBundleIconFile' "$BUILDER" || mutated ;;
  *) echo "REFUSED: no mutant ${MUTANT}"; exit 2 ;;
esac

fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
mk() {   # <dest> [builder arguments]: output in $T/out; echoes the exit code. XPATH goes first on PATH
  local d="$1"; shift
  HOME="$T/home" PATH="${XPATH:+$XPATH:}$PATH" /bin/bash "$BUILDER" --dest "$d" "$@" > "$T/out" 2>&1
  echo $?
}
said() { grep -c -- "$1" "$T/out"; }
px() { plutil -extract "$1" raw "$2/Contents/Info.plist" 2>/dev/null; }
snap() { (cd "$1" && { find . -type f -exec shasum {} + | sort; find . | sort; }) | shasum | cut -c1-12; }
leftover() { ls -a "$1" | grep -c '^\.14unch3r-build\.'; }
fake() {   # <bundle> <identifier> [wrapper]: an app of someone else's shape at the target
  mkdir -p "$1/Contents/MacOS"
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>%s</string></dict></plist>\n' "$2" > "$1/Contents/Info.plist"
  echo keep > "$1/Contents/MacOS/keep"
  [ "${3:-}" = wrapper ] && mkdir -p "$1/Contents/SharedSupport/prefix"
  return 0
}

# --- built from nothing
D="$T/apps"; mkdir -p "$D"; A="$D/14unch3r.app"
rc=$(mk "$D")
check "the app is built" "$rc:$([ -x "$A/Contents/MacOS/launcher-window" ] && echo program)" "0:program"
check "  ...its identifier, program, name and display name" "$(px CFBundleIdentifier "$A"):$(px CFBundleExecutable "$A"):$(px CFBundleName "$A"):$(px CFBundleDisplayName "$A")" \
  "local.1launcher.window:launcher-window:14unch3r:14unch3r"
check "  ...its three other names for Spotlight, and no fourth" "$(px CFBundleAlternateNames.0 "$A")|$(px CFBundleAlternateNames.1 "$A")|$(px CFBundleAlternateNames.2 "$A")|$(px CFBundleAlternateNames.3 "$A")" \
  "1launcher|launcher|game launcher|"
check "  ...its plist lints, and its table of games is the repo's" "$(plutil -lint "$A/Contents/Info.plist" >/dev/null 2>&1 && echo lint):$(cmp -s "$A/Contents/Resources/games.tsv" "$T/repo/common/games.tsv" && echo same)" "lint:same"
check "  ...and no build folder is left beside it" "$(leftover "$D")" 0

# --- the program inside the app: where it looks, and what it finds there
check "--folders from inside the app: that HOME's Applications, then the app's own folder" \
  "$(HOME="$T/home" "$A/Contents/MacOS/launcher-window" --folders | tr '\n' '|')" "$T/home/Applications|$(cd "$D" && pwd -P)|"
mkdir -p "$T/home2/Applications"; rc=$(HOME="$T/home2" mk "$T/home2/Applications")
check "--folders when the app is in that HOME's Applications: one line" \
  "$rc:$(HOME="$T/home2" "$T/home2/Applications/14unch3r.app/Contents/MacOS/launcher-window" --folders | tr '\n' '|')" "0:$T/home2/Applications|"
mkdir -p "$D/Fixture.app/Contents"
printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>L1Role</key><string>game</string><key>L1SteamAppID</key><integer>3215050</integer><key>CFBundleDisplayName</key><string>Fixture Game</string></dict></plist>\n' > "$D/Fixture.app/Contents/Info.plist"
check "--list given the app's folder: the fixture game beside it, and not the app itself" \
  "$("$A/Contents/MacOS/launcher-window" --list "$D" | tr '\t' '|')" "game|3215050|unknown|Fixture Game|$D/Fixture.app"

# --- built again over its own older app
echo old > "$A/Contents/Resources/old-file"
rc=$(mk "$D")
check "built again over its own app: exit 0, the old app's extra file gone" "$rc:$([ -e "$A/Contents/Resources/old-file" ] && echo old)" "0:"
check "  ...no app inside the app, and no build folder left" "$([ -e "$A/14unch3r.app" ] && echo nested):$(leftover "$D")" ":0"

# --- skipped: nothing is changed and nothing is left, exit 3
before=$(snap "$D")
mkdir -p "$T/noswift"; printf '#!/bin/bash\nexit 1\n' > "$T/noswift/xcrun"; chmod +x "$T/noswift/xcrun"
check "no swiftc: exit 3, the reason said, the older app and its folder as they were" \
  "$(XPATH="$T/noswift" mk "$D"):$(said 'window: skipped (swiftc is missing'):$(snap "$D")" "3:1:$before"
check "no source: the same" "$(L1_WINDOW_SRC="$T/absent.swift" mk "$D"):$(said 'window: skipped (common/launcher-window.swift is missing'):$(snap "$D")" "3:1:$before"
echo 'this is not Swift' > "$T/bad.swift"
check "a source that does not compile: the same" "$(L1_WINDOW_SRC="$T/bad.swift" mk "$D"):$(said 'window: skipped (the compile failed'):$(snap "$D")" "3:1:$before"

# --- refused: exit 1, both lines said, the bundle untouched
refused() {   # <case> <dest>
  local b="$2/14unch3r.app" s rc
  s=$(snap "$b"); rc=$(mk "$2")
  check "$1: refused with exit 1, both lines said, untouched" \
    "$rc:$(said "^ERROR: $b exists and was not built by this script; nothing removed$")$(said '^If it is a leftover of this script, move it to the Trash and run this again.$'):$(snap "$b")" "1:11:$s"
}
fake "$T/r1/14unch3r.app" local.1launcher.window wrapper; refused "a wrapper-shaped bundle with this app's identifier" "$T/r1"
fake "$T/r2/14unch3r.app" local.someone.else;            refused "a bundle with another identifier" "$T/r2"
mkdir -p "$T/r3"; ln -s "$A" "$T/r3/14unch3r.app";       refused "a symlink to an app of this builder's" "$T/r3"
check "  ...it is still a symlink" "$([ -L "$T/r3/14unch3r.app" ] && echo link)" link

# --- names, checked before anything is touched: exit 2, nothing written
mkdir -p "$T/names"
for n in 'a/b' '-x' '.x'; do
  check "--name '$n': exit 2, nothing written" "$(mk "$T/names" --name "$n"):$(ls -A "$T/names" | wc -l | tr -d ' ')" "2:0"
done
check "--name with no value: exit 2" "$(mk "$T/names" --name ''):$(said '^--name needs a value$')" "2:1"

# --- no table of games in the checkout: built, and said
mkdir -p "$T/nogames/common"; cp "$BUILDER" "$SRC" "$T/nogames/common/"
rc=$(HOME="$T/home" /bin/bash "$T/nogames/common/make-launcher-app.sh" --dest "$T/ng" > "$T/out" 2>&1; echo $?)
check "no common/games.tsv: built, said, and the app holds no table" "$rc:$(said 'common/games.tsv is missing'):$([ -e "$T/ng/14unch3r.app/Contents/Resources/games.tsv" ] && echo table)" "0:1:"

# --- the icon (B6)
check "the icon is in the app, and its plist names it" "$([ -s "$A/Contents/Resources/14unch3r.icns" ] && echo icns):$(px CFBundleIconFile "$A")" "icns:14unch3r.icns"
"$A/Contents/MacOS/launcher-window" --icon "$T/icon.png"
check "  ...drawn at exactly 1024 by 1024 pixels" "$(sips -g pixelWidth -g pixelHeight "$T/icon.png" 2>/dev/null | awk '/pixel/ { printf "%s ", $2 }')" "1024 1024 "
mkdir -p "$T/noicon"; printf '#!/bin/bash\nexit 1\n' > "$T/noicon/iconutil"; chmod +x "$T/noicon/iconutil"
rc=$(XPATH="$T/noicon" mk "$T/ni")
check "iconutil fails: the app is built, its plist names no icon, and it says so" "$rc:$(px CFBundleIconFile "$T/ni/14unch3r.app"):$(said '^    icon:     skipped')" "0::1"

echo "$fails failure(s)"
[ "$fails" = 0 ]
