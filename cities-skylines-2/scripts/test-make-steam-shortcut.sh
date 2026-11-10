#!/bin/bash
# test-make-steam-shortcut.sh -- make-steam-shortcut.sh builds the Steam app, S734M.app (docs/plans/launcher-window.md,
# 2.4, W4). Every build is given a fixture --wrapper in a scratch folder (a stub wine64 that prints a version and
# records each call, an empty steam.exe, nothing else) and a --from that does not exist, so the builder can never
# clone a real wrapper; HOME is a scratch folder too. A built shim is run only after the fixture's steam.exe is
# deleted, so it stops at its first check, before either wine64 line, with a recording osascript first on PATH.
# Keys are read with plutil, never by grepping the plist. No game, no Steam, no Wine.
#   bash scripts/test-make-steam-shortcut.sh      exit 0 = every case passed
#   MUTANT=1 ...   the own-bundle test is dropped (a wrapper named S734M.app is deleted); must exit 1
#   MUTANT=2 ...   the old CS2 Steam Store.app is removed without the own-bundle test; must exit 1
#   MUTANT=3 ...   the -ef test is dropped (an app built as "cs2 steam store" removes itself); must exit 1
#   MUTANT=4 ...   the title is written into the shim as raw text, as an unquoted heredoc would; must exit 1
#   MUTANT=5 ...   the title is put into the AppleScript source of the alert; must exit 1
#   MUTANT=6 ...   nohup is added to a start line (macOS strips DYLD_*, Steam draws no text); must exit 1
#   MUTANT=7 ...   the builder drops L1Role; must exit 1
#   MUTANT=8 ...   the name is checked after the target was removed; must exit 1
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MAKE="$REPO/scripts/make-steam-shortcut.sh"
T="$(mktemp -d /tmp/make-steam-shortcut-test.XXXX)"
trap 'rm -rf "$T"' EXIT
M="${MUTANT:-0}"
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
case "$M" in 0|1|2|3|4|5|6|7|8) ;; *) echo "REFUSED: no mutant $M"; exit 2 ;; esac
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

# a scratch copy of the builder for the mutants, laid out as in the repo so that it finds pe-icon.py
if [ "$M" != 0 ]; then
  mkdir -p "$T/mut/scripts"; cp "$MAKE" "$REPO/scripts/pe-icon.py" "$T/mut/scripts/"; MAKE="$T/mut/scripts/make-steam-shortcut.sh"
fi
case "$M" in
  1) sed -i '' 's/^  \[ -e "\$t" \] || \[ -L "\$t" \] || return 0$/  return 0/' "$MAKE"; grep -q '|| return 0$' "$MAKE" && mutated ;;
  2) sed -i '' 's/^  elif own_bundle "\$OLD" "\$MARK" "\$BUNDLE_ID"; then$/  elif true; then/' "$MAKE"; grep -q '^  elif true; then$' "$MAKE" || mutated ;;
  3) sed -i '' 's/^  if \[ "\$OLD" -ef "\$APP" \]; then :$/  if false; then :/' "$MAKE"; grep -q '^  if false; then :$' "$MAKE" || mutated ;;
  4) sed -i '' "s/^printf 'TITLE=%q\\\\n' \"\\\$APPNAME\"/printf 'TITLE=\"%s\"\\\\n' \"\$APPNAME\"/" "$MAKE"; grep -q "^printf 'TITLE=\"%s\"" "$MAKE" || mutated ;;
  5) sed -i '' 's/^  osascript -e .on run a. -e .display alert (item 2 of a) message (item 1 of a) as critical. -e .end run. -- \(".*"\) "\$TITLE" >/  osascript -e "display alert \\"$TITLE\\" message \\"x\\" as critical" -- \1 >/' "$MAKE"
     grep -q '^  osascript -e "display alert \\"\$TITLE\\"' "$MAKE" || mutated ;;
  6) sed -i '' 's/^  "\$SS\/wine\/bin\/wine64" "\$STEAM" -no-cef-sandbox /  nohup "$SS\/wine\/bin\/wine64" "$STEAM" -no-cef-sandbox /' "$MAKE"; grep -q '^  nohup ' "$MAKE" || mutated ;;
  7) sed -i '' '/<key>L1Role<\/key>/d' "$MAKE"; grep -q '<key>L1Role</key>' "$MAKE" && mutated ;;
  8) awk '/^check_name "\$APPNAME"$/ { next } { print } /^rm -rf "\$APP"$/ { print "check_name \"$APPNAME\"" }' "$MAKE" > "$MAKE.new" && cat "$MAKE.new" > "$MAKE"
     [ "$(grep -n '^check_name "\$APPNAME"$' "$MAKE" | cut -d: -f1)" -gt "$(grep -n '^rm -rf "\$APP"$' "$MAKE" | cut -d: -f1)" ] 2>/dev/null || mutated ;;
esac
[ "$M" = 0 ] || /bin/bash -n "$MAKE" || { echo "REFUSED: mutant $M does not parse"; exit 2; }

# the fixture store wrapper: its wine64 records each call and prints a version; steam.exe is an empty file
W="$T/fixture/Store.app"; WS="$W/Contents/SharedSupport"; STEAM_EXE="$WS/prefix/drive_c/Program Files (x86)/Steam/steam.exe"
mkdir -p "$WS/wine/bin" "${STEAM_EXE%/*}" "$T/bin" "$T/cwd" "$T/home" "$T/badplutil"
printf '#!/bin/bash\necho "$*" >> "%s/wine.calls"\necho wine-11.0\n' "$T" > "$WS/wine/bin/wine64"
: > "$STEAM_EXE"; : > "$T/wine.calls"
# the recording osascript: one line per call, whether it shows an alert, and its last argument, the title
cat > "$T/bin/osascript" <<EOF
#!/bin/bash
echo call >> "$T/osa.calls"
case "\$*" in *"display alert"*) echo alert >> "$T/osa.kinds" ;; *) echo other >> "$T/osa.kinds" ;; esac
for a; do last="\$a"; done
printf '%s' "\$last" > "$T/osa.title"
EOF
printf '#!/bin/bash\nexit 1\n' > "$T/bin/pgrep"
printf '#!/bin/bash\nexit 1\n' > "$T/badplutil/plutil"   # every plutil call fails
chmod +x "$WS/wine/bin/wine64" "$T/bin"/* "$T/badplutil/plutil"

mk() {   # <dest> [options]: the builder with the fixture wrapper and a donor that does not exist; output in $T/mk.out; prints its exit code
  local d="$1"; shift
  ( cd "$T/cwd" && HOME="$T/home" PATH="${PRE:+$PRE:}$T/bin:$PATH" bash "$MAKE" --wrapper "$W" --from "$T/no-such-donor.app" --dest "$d" "$@" ) > "$T/mk.out" 2>&1
  echo $?
}
key() { plutil -extract "$2" raw "$1/Contents/Info.plist" 2>/dev/null || echo "(none)"; }
alts() {   # <app>: how many alternate names, then each, joined by |
  local pl="$1/Contents/Info.plist" n i out
  n=$(plutil -extract CFBundleAlternateNames raw -expect array "$pl" 2>/dev/null) || { echo "(none)"; return; }
  out="$n"; i=0
  while [ "$i" -lt "$n" ]; do out="$out|$(plutil -extract "CFBundleAlternateNames.$i" raw "$pl" 2>/dev/null)"; i=$((i + 1)); done
  echo "$out"
}
lints() { plutil -lint "$1/Contents/Info.plist" >/dev/null 2>&1 && echo lints; }
said() { grep -c -F -x -e "$1" "$T/mk.out"; }
complete() { [ -x "$1/Contents/MacOS/launch" ] && [ -s "$1/Contents/Info.plist" ] && echo complete; }
snap() {   # <bundle>: names, file contents and link targets under it, as one short hash; "gone" when it is not there
  [ -d "$1" ] || { echo gone; return; }
  ( cd "$1" && { find . | LC_ALL=C sort; find . -type f -exec shasum {} + | LC_ALL=C sort; find . -type l -exec readlink {} +; } ) | shasum | cut -c1-12
}

# --- the default build
rc=$(mk "$T/d1"); A="$T/d1/S734M.app"
check "built as S734M.app by default" "$rc:$(complete "$A")" "0:complete"
check "  ...its plist lints, and keeps the bundle identifier" "$(lints "$A"):$(key "$A" CFBundleIdentifier)" "lints:local.cs2.steamstore"
check "  ...L1Role is steam" "$(key "$A" L1Role)" steam
check "  ...L1Prefix is the store wrapper's prefix" "$(key "$A" L1Prefix)" "$WS/prefix"
check "  ...its three alternate names" "$(alts "$A")" "3|Windows Steam|Steam Store|CS2 Steam Store"
check "  ...its name and display name are S734M" "$(key "$A" CFBundleName):$(key "$A" CFBundleDisplayName)" "S734M:S734M"
check "  ...its shim passes bash -n" "$(/bin/bash -n "$A/Contents/MacOS/launch" 2>&1 && echo parses)" parses
# The two start lines must stay exactly as they are: nohup, env or bash -c in front of wine64 makes macOS strip
# DYLD_* and Steam draws no text (the builder's own comment beside them). These are those lines as of 5791286.
WANT='  "$SS/wine/bin/wine64" "$STEAM" "steam://open/main" >/dev/null 2>&1 & disown
  "$SS/wine/bin/wine64" "$STEAM" -no-cef-sandbox >/dev/null 2>&1 & disown'
check "  ...its two wine64 lines are byte for byte the builder's" "$(grep -F '/wine/bin/wine64" "$STEAM"' "$A/Contents/MacOS/launch")" "$WANT"
rc=$(mk "$T/d1" --name Other)
check "built under --name" "$rc:$(complete "$T/d1/Other.app"):$(key "$T/d1/Other.app" CFBundleName)" "0:complete:Other"

# --- a name full of shell, AppleScript and plist characters; then its shim, with steam.exe gone
NAME="It's \"q\" \$(touch x) & more"
rc=$(mk "$T/d2" --name "$NAME"); A="$T/d2/$NAME.app"
check "a name holding ', \", \$(touch x) and &: built, written by plutil exactly, and the plist lints" "$rc:$(key "$A" CFBundleName):$(key "$A" CFBundleDisplayName):$(lints "$A")" "0:$NAME:$NAME:lints"
before=$(wc -l < "$T/wine.calls" | tr -d ' ')
rm "$STEAM_EXE"
[ ! -e "$STEAM_EXE" ] || { echo "REFUSED: the fixture's steam.exe is still there: the shim would go on to start wine64"; exit 2; }
( cd "$T/cwd" && HOME="$T/home" PATH="$T/bin:$PATH" "$A/Contents/MacOS/launch" ) > /dev/null 2>&1; rc=$?
check "its shim, with steam.exe gone: exit 1, and no wine64 call" "$rc:$(wc -l < "$T/wine.calls" | tr -d ' ')" "1:$before"
check "  ...one osascript call, an alert" "$(cat "$T/osa.calls" 2>/dev/null | wc -l | tr -d ' '):$(cat "$T/osa.kinds" 2>/dev/null)" "1:alert"
check "  ...whose title argument is exactly the name" "$(cat "$T/osa.title" 2>/dev/null)" "$NAME"
check "  ...and no file x appears" "$(find "$T" -name x | wc -l | tr -d ' ')" 0
: > "$STEAM_EXE"

# --- what is at the target, and the old app
ERR1() { echo "ERROR: $1 exists and was not built by this script; nothing removed"; }
ERR2='If it is a leftover of this script, move it to the Trash and run this again.'
ERR3='A Wine wrapper of that name is in this folder. Move or remove it (see surviving-mars-relaunched/README.md), or build under another name with --name.'
mkdir -p "$T/d3/S734M.app/Contents/MacOS" "$T/d3/S734M.app/Contents/SharedSupport/prefix/drive_c" "$T/d3/S734M.app/Contents/SharedSupport/wine/bin"
printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.example.wineskin</string></dict></plist>\n' > "$T/d3/S734M.app/Contents/Info.plist"
echo wrapper > "$T/d3/S734M.app/Contents/MacOS/wineskinlauncher"; echo reg > "$T/d3/S734M.app/Contents/SharedSupport/prefix/system.reg"
before=$(snap "$T/d3/S734M.app")
rc=$(mk "$T/d3")
check "a wrapper-shaped S734M.app at the target: exit 1, all three lines said, byte for byte as it was" "$rc:$(said "$(ERR1 "$T/d3/S734M.app")")$(said "$ERR2")$(said "$ERR3"):$(snap "$T/d3/S734M.app")" "1:111:$before"

mk "$T/proto" --name Proto > /dev/null; PROTO="$T/proto/Proto.app"   # an app of this builder's, copied wherever one is needed
check "(the prototype app was built)" "$(complete "$PROTO")" complete
own_copy() { mkdir -p "$(dirname "$1")"; cp -R "$PROTO" "$1"; : > "$1/Contents/Resources/keep"; }
studio_old() {   # <bundle>: the old app as the Studio has it, three hand-written lines above the marker on line 5
  own_copy "$1"
  { echo '#!/bin/bash'; echo '# 2026-08-30: a note added by hand'; echo '# a second note'; echo '# a third note'
    sed -n '2,$p' "$PROTO/Contents/MacOS/launch"; } > "$1/Contents/MacOS/launch"
}
studio_old "$T/d4/CS2 Steam Store.app"
check "(that old app's marker is on line 5)" "$(grep -n '^# Generated by scripts/make-steam-shortcut.sh' "$T/d4/CS2 Steam Store.app/Contents/MacOS/launch" | cut -d: -f1)" 5
rc=$(mk "$T/d4")
check "an old CS2 Steam Store.app of this builder's, marker on line 5: removed, and said with the Dock" "$rc:$([ -e "$T/d4/CS2 Steam Store.app" ] && echo left):$(said "    old app: removed $T/d4/CS2 Steam Store.app, which this app replaces. A Dock entry for it has to be dragged out by hand."):$(complete "$T/d4/S734M.app")" "0::1:complete"
oldkept() {   # <case> <dest>: the old app there is left as it was, and said
  local o="$2/CS2 Steam Store.app" b
  b=$(snap "$o"); rc=$(mk "$2")
  check "$1: left as it was, and said" "$rc:$(snap "$o"):$(said "    old app: left $o: it was not built by this script")" "0:$b:1"
}
own_copy "$T/d5/CS2 Steam Store.app"; plutil -replace CFBundleIdentifier -string local.someone.else "$T/d5/CS2 Steam Store.app/Contents/Info.plist"
oldkept "an old CS2 Steam Store.app with another identifier" "$T/d5"
own_copy "$T/d6/CS2 Steam Store.app"; sed -i '' '/^# Generated by /d' "$T/d6/CS2 Steam Store.app/Contents/MacOS/launch"
oldkept "an old CS2 Steam Store.app with no marker" "$T/d6"

rc=$(mk "$T/d7" --name "CS2 Steam Store")
check "built as --name \"CS2 Steam Store\": the app just built is still there" "$rc:$(complete "$T/d7/CS2 Steam Store.app")" "0:complete"
rc=$(mk "$T/d8" --name "cs2 steam store")
check "built as --name \"cs2 steam store\": the app just built is still there" "$rc:$(complete "$T/d8/cs2 steam store.app")" "0:complete"
: > "$T/d8/CaseProbe"
[ -e "$T/d8/caseprobe" ] || echo "NOTE  this volume tells letter case apart, so the case above did not reach the -ef test; the one before it did"

# --- names refused before anything is removed: the app each points at and an old app beside them stay
badname() {   # <case> <name> <line said>
  local t="$T/d9/$2.app" b bo
  own_copy "$t"; b=$(snap "$t"); bo=$(snap "$T/d9/CS2 Steam Store.app")
  rc=$(mk "$T/d9" --name "$2")
  check "--name $1: exit 2, said, nothing removed" "$rc:$(said "$3"):$(snap "$t"):$(snap "$T/d9/CS2 Steam Store.app")" "2:1:$b:$bo"
}
own_copy "$T/d9/CS2 Steam Store.app"
NAMEMSG="--name must not be empty, hold / or a control character, or start with . or -"
badname "empty" "" "--name needs a value"
badname "holding /" "sub/X" "$NAMEMSG"
badname "starting with -" "-x" "$NAMEMSG"
check "--name as the last word: exit 2, said, and no hang" "$( ( cd "$T/cwd" && HOME="$T/home" PATH="$T/bin:$PATH" bash "$MAKE" --wrapper "$W" --from "$T/no-such-donor.app" --name ) > "$T/mk.out" 2>&1; echo $?):$(said '--name needs a value')" "2:1"

# --- a plutil that fails
rc=$(PRE="$T/badplutil" mk "$T/d10")
check "every plutil call fails: the error line, no bundle left, exit 1" "$rc:$(said "ERROR: $T/d10/S734M.app/Contents/Info.plist is not a valid property list; the app was not built"):$([ -e "$T/d10/S734M.app" ] && echo left)" "1:1:"

echo "$fails failure(s)"
[ "$fails" = 0 ]
