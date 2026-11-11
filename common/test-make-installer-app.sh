#!/bin/bash
# test-make-installer-app.sh -- common/make-installer-app.sh, the app it builds and the .command that app
# writes (docs/plans/simple-install.md, NT5), and the one address every document and the app must agree on
# (NT7). The app's program is run with a stub open, and the .command with a stub curl whose answer is a
# one-line script that records how it was called. HOME and TMPDIR are scratch folders. No network, no
# Terminal window, nothing opened.
#   bash common/test-make-installer-app.sh            exit 0 = every case passed
#   MUTANT=1 ...  the .command copied from the bundle (its quarantine attribute travels); must exit 1
#   MUTANT=2 ...  open given a file inside the bundle; must exit 1
#   MUTANT=3 ...  a foreign bundle replaced; must exit 1
#   MUTANT=4 ...  the ref not checked; must exit 1
#   MUTANT=5 ...  the recursive delete put back; must exit 1
#   MUTANT=6 ...  the $0 word given as install.sh; must exit 1
#   MUTANT=7 ...  the root README's pasted line changed alone; must exit 1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
T="$(mktemp -d /tmp/installer-app-test.XXXX)"
# One case makes the app's program fall back to /tmp; a mutant can leave that folder behind. What was not
# there before this run is removed after it: the one file the program writes, then its folder.
STRAYS_BEFORE=" $(ls -d /tmp/1launcher-install.* 2>/dev/null | tr '\n' ' ')"
cleanup() {
  local d
  for d in /tmp/1launcher-install.*; do
    [ -d "$d" ] || continue
    case "$STRAYS_BEFORE" in *" $d "*) continue ;; esac
    rm -f "$d"/*.command; rmdir "$d" 2>/dev/null
  done
  rm -rf "$T"
}
trap cleanup EXIT
mkdir -p "$T/common" "$T/docs/cities-skylines-2"
S="$T/common/make-installer-app.sh"; cp "$HERE/make-installer-app.sh" "$S"; cp "$HERE/games.tsv" "$T/common/"
cp "$REPO/README.md" "$T/docs/README.md"
cp "$REPO/cities-skylines-2/README.md" "$REPO/cities-skylines-2/INSTALL.md" "$T/docs/cities-skylines-2/"
mutate() {  # <sed expression> <grep that proves it applied> [<file>]
  sed -i '' "$1" "${3:-$S}"; grep -q -- "$2" "${3:-$S}" || { echo "REFUSED: mutant did not apply"; exit 2; }
}
case "${MUTANT:-0}" in
  1) mutate "s#^cat > \"\\\$C\" <<'EOS'\$#cp \"\$0\" \"\$C\"; cat >> \"\$C\" <<'EOS'#" '^cp "\$0" "\$C"; cat >> "\$C"' ;;
  2) mutate 's#^open -a Terminal "\$C"$#open -a Terminal "$0"#' '^open -a Terminal "\$0"$' ;;
  3) mutate 's#^if ! own_app "\$APP"; then$#if false; then#' '^if false; then$' ;;
  4) mutate 's#^case "\$REF" in .*#: unchecked#' '^: unchecked$'
     mutate 's#^printf .%s. "\$REF" | grep -Eq .*#: unchecked2#' '^: unchecked2$' ;;
  5) mutate "s#^trap 'rm -f \"\\\$0\"; rmdir \"\\\$(dirname \"\\\$0\")\" 2>/dev/null' EXIT\$#trap 'rm -rf \"\$(dirname \"\$0\")\"' EXIT#" "^trap 'rm -rf " ;;
  6) mutate 's#/bin/bash -c "\$S" 1launcher-install @GAME@#/bin/bash -c "$S" install.sh @GAME@#' '"\$S" install.sh @GAME@' ;;
  7) mutate 's#1launcher/release/install.sh#1launcher/main/install.sh#' '1launcher/main/install.sh' "$T/docs/README.md" ;;
esac

fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
mkdir -p "$T/bin" "$T/home" "$T/tmp"
printf '#!/bin/bash\necho "OPEN $*" >> "$CALLS"\n' > "$T/bin/open"
cat > "$T/bin/curl" << 'C'
#!/bin/bash
echo "CURL $*" >> "$CALLS"
[ -n "${STUB_CURL_EXIT:-}" ] && exit "$STUB_CURL_EXIT"
echo 'echo "BOOT $0 $1 $2 words=$#" >> "$CALLS"'
C
printf '#!/bin/bash\nexit 0\n' > "$T/bin/clear"
printf '#!/bin/bash\necho "OSASCRIPT $*" >> "$CALLS"\n' > "$T/bin/osascript"
chmod +x "$T/bin"/*
export CALLS="$T/calls"; : > "$CALLS"
printf 'icns' > "$T/mark.icns"
build() {   # <dest> [more options]: output in $T/build.out; echoes the exit code
  local d="$1"; shift
  env HOME="$T/home" TMPDIR="$T/tmp" bash "$S" --dest "$d" --game cities-skylines-2 "$@" > "$T/build.out" 2>&1; echo $?
}
NAME="Install Cities Skylines II"
ADDR="https://raw.githubusercontent.com/macgameport/1launcher/release/install.sh"

# --- built
D="$T/d1"
check "built with an icon: exit 0" "$(build "$D" --icns "$T/mark.icns")" 0
A="$D/$NAME.app"; P="$A/Contents/MacOS/install"
check "  ...the app's three files, and nothing else in it" "$(cd "$A" && find . -type f | sort | tr '\n' ' ')" "./Contents/Info.plist ./Contents/MacOS/install ./Contents/Resources/installer.icns "
check "  ...its identifier, name, program and icon" \
  "$(plutil -extract CFBundleIdentifier raw "$A/Contents/Info.plist"):$(plutil -extract CFBundleName raw "$A/Contents/Info.plist"):$(plutil -extract CFBundleExecutable raw "$A/Contents/Info.plist"):$(plutil -extract CFBundleIconFile raw "$A/Contents/Info.plist")" \
  "local.1launcher.installer:$NAME:install:installer.icns"
check "  ...arm64 named as its architecture" "$(plutil -extract LSArchitecturePriority.0 raw "$A/Contents/Info.plist")" arm64
check "  ...the program executable, its marker in line 2, no placeholder left" \
  "$([ -x "$P" ] && echo x):$(sed -n 2p "$P" | grep -c '^# Generated by common/make-installer-app.sh'):$(grep -c '@[A-Z]*@' "$P")" "x:1:0"
check "  ...the game, the ref and the title in every place" \
  "$(grep -c '1launcher-install cities-skylines-2 "release"' "$P"):$(grep -cF "\"$ADDR\"" "$P"):$(grep -c 'blob/main/cities-skylines-2/INSTALL.md' "$P"):$(grep -c 'C="$D/Install Cities Skylines II.command"' "$P")" "1:1:1:1"
check "  ...the alert's title passed to osascript as an argument" "$(grep -c -- "-e 'end run' -- \"Cities Skylines II\"\$" "$P")" 1
check "  ...the ZIP named from the games table, its size and sha256 printed" \
  "$([ -f "$D/Install-Cities-Skylines-II.zip" ] && echo zip):$(grep -cE '^      [0-9]+ bytes, sha256 [0-9a-f]{64}$' "$T/build.out")" "zip:1"
mkdir -p "$T/unz" && ditto -x -k "$D/Install-Cities-Skylines-II.zip" "$T/unz"
check "  ...unpacked, the program is still executable" "$([ -x "$T/unz/$NAME.app/Contents/MacOS/install" ] && echo x)" x
check "  ...no build folder left" "$(ls -A "$D" | grep -c '^\.installer-build')" 0
check "built again over its own app: exit 0" "$(build "$D" --icns "$T/mark.icns")" 0
check "--ref another branch: written in both places" "$(build "$T/d2" --no-icon --ref simple-install):$(grep -c 'macgameport/1launcher/simple-install/install.sh' "$T/d2/$NAME.app/Contents/MacOS/install"):$(grep -c 'cities-skylines-2 "simple-install"' "$T/d2/$NAME.app/Contents/MacOS/install")" "0:1:1"
check "--no-icon: built, says so, no icon key" "$(grep -c 'none, as asked' "$T/build.out"):$(plutil -extract CFBundleIconFile raw "$T/d2/$NAME.app/Contents/Info.plist" > /dev/null 2>&1; echo $?)" "1:1"

# --- refused
check "neither --icns nor --no-icon: exit 2" "$(build "$T/d3")" 2
check "both: exit 2" "$(build "$T/d3" --icns "$T/mark.icns" --no-icon)" 2
check "an icon file that is not there: exit 2" "$(build "$T/d3" --icns "$T/nope.icns")" 2
for r in 'a..b' '/abs' 'a//b' 'a b' 'a;b' '-x'; do check "a ref that fails the rule ($r): exit 2, nothing built" "$(build "$T/d3" --no-icon --ref "$r"):$([ -e "$T/d3" ] && echo made || echo none)" "2:none"; done
check "no --dest: exit 2" "$(env HOME="$T/home" bash "$S" --game cities-skylines-2 --no-icon > /dev/null 2>&1; echo $?)" 2
check "no --game: exit 2" "$(env HOME="$T/home" bash "$S" --dest "$T/d3" --no-icon > /dev/null 2>&1; echo $?)" 2
check "a game with no row in the table: exit 2" "$(env HOME="$T/home" bash "$S" --dest "$T/d3" --game no-such-game --no-icon > /dev/null 2>&1; echo $?)" 2
mkdir -p "$T/d4/$NAME.app"; echo mine > "$T/d4/$NAME.app/keep"
check "a folder of that name that is not this builder's: exit 1, left as it was" "$(build "$T/d4" --no-icon):$(cat "$T/d4/$NAME.app/keep")" "1:mine"
mkdir -p "$T/d5"; cp -R "$A" "$T/d5/"; sed -i '' '2s/.*/# something else/' "$T/d5/$NAME.app/Contents/MacOS/install"; echo mine > "$T/d5/$NAME.app/keep"
check "its identifier without its marker line: exit 1, left as it was" "$(build "$T/d5" --no-icon):$(cat "$T/d5/$NAME.app/keep")" "1:mine"

# --- the app's program, run: a fresh .command, opened in Terminal
xattr -w com.apple.quarantine "0083;00000000;Safari;" "$P"
runshim() { env HOME="$T/home" TMPDIR="${1:-$T/tmp}" PATH="$T/bin:$PATH" bash "$P" > "$T/shim.out" 2>&1; echo $?; }
# (functions, not a case inside $( ): bash 3.2 ends a command substitution at a case pattern's parenthesis)
where() {   # <path of the .command>: fresh = in a new folder under the scratch TMPDIR; tmp = under /tmp; else the path
  case "$1" in
    "$T/tmp/1launcher-install."*"/Install Cities Skylines II.command") echo fresh ;;
    /tmp/1launcher-install.*"/Install Cities Skylines II.command") echo tmp ;;
    *) echo "$1" ;;
  esac
}
: > "$CALLS"; rc="$(runshim)"
C="$(sed -n 's/^OPEN -a Terminal //p' "$CALLS")"
check "the program: exit 0, open called with -a Terminal and a .command in a new temporary folder" \
  "$rc:$(grep -c '^OPEN -a Terminal ' "$CALLS"):$(where "$C")" "0:1:fresh"
check "  ...the .command is executable and carries no quarantine attribute, though the program does" \
  "$([ -x "$C" ] && echo x):$(xattr "$C" 2>/dev/null | grep -c quarantine):$(xattr "$P" | grep -c quarantine)" "x:0:1"
: > "$CALLS"; rc="$(runshim "$T/no-such-folder")"
C2="$(sed -n 's/^OPEN -a Terminal //p' "$CALLS")"
check "TMPDIR names no folder: /tmp is used, and no alert" "$rc:$(where "$C2"):$(grep -c OSASCRIPT "$CALLS")" "0:tmp:0"
case "$C2" in /tmp/1launcher-install.*/*) rm -f "$C2"; rmdir "$(dirname "$C2")" ;; esac

# --- the .command, run
runcmd() { env HOME="$T/home" PATH="$T/bin:$PATH" "$@" bash "$C" > "$T/cmd.out" 2>&1; echo $?; }
: > "$CALLS"; cp "$C" "$T/saved.command"; rc="$(runcmd)"
check "the .command: fetches the one address over https, and runs it as 1launcher-install with the game and the ref" \
  "$(grep -cF "CURL --proto =https --tlsv1.2 -fsSL $ADDR" "$CALLS"):$(grep -c '^BOOT 1launcher-install cities-skylines-2 release words=2$' "$CALLS")" "1:1"
check "  ...then removes itself and its folder" "$([ -e "$C" ] && echo file):$([ -e "$(dirname "$C")" ] && echo folder)" ":"
runsaved() {   # <folder to run a copy in> [VAR=value]: the saved .command copied there and run
  local d="$1"; shift; mkdir -p "$d"; cp "$T/saved.command" "$d/x.command"
  env HOME="$T/home" PATH="$T/bin:$PATH" "$@" bash "$d/x.command" > "$T/cmd.out" 2>&1; echo $?
}
: > "$CALLS"; runsaved "$T/c22" STUB_CURL_EXIT=22 > /dev/null
check "GitHub answers not found: the withdrawn lines, with the guide's address, and nothing run" \
  "$(grep -c 'has been withdrawn or has moved' "$T/cmd.out"):$(grep -c 'blob/main/cities-skylines-2/INSTALL.md' "$T/cmd.out"):$(grep -c BOOT "$CALLS")" "1:1:0"
: > "$CALLS"; runsaved "$T/c6" STUB_CURL_EXIT=6 > /dev/null
check "GitHub cannot be reached: the network line" "$(grep -c 'GitHub could not be reached' "$T/cmd.out"):$(grep -c BOOT "$CALLS")" "1:0"
mkdir -p "$T/desk"; echo precious > "$T/desk/other.txt"; runsaved "$T/desk" > /dev/null
check "copied beside another file and run: only itself is removed" "$(cat "$T/desk/other.txt" 2>/dev/null):$([ -e "$T/desk/x.command" ] && echo left || echo gone)" "precious:gone"

# --- NT7: one address, in the documents and in the app
DOCS="$T/docs/README.md $T/docs/cities-skylines-2/README.md $T/docs/cities-skylines-2/INSTALL.md"
for f in $DOCS; do
  n="$(grep -o 'raw\.githubusercontent\.com/macgameport/1launcher/[^ )"`]*' "$f" | wc -l | tr -d ' ')"
  same="$(grep -o 'raw\.githubusercontent\.com/macgameport/1launcher/[^ )"`]*' "$f" | grep -cx 'raw.githubusercontent.com/macgameport/1launcher/release/install.sh')"
  check "the pasted line in ${f#"$T/docs/"}: there, and every one the same address" "$([ "$n" -ge 1 ] && echo some):$((n - same))" "some:0"
  rel="$(grep -o 'releases/download/installer-[^ )"`]*' "$f" | grep -cvx 'releases/download/installer-1/Install-Cities-Skylines-II.zip')"
  check "  ...any link to the installer's release names installer-1 and the ZIP" "$rel" 0
done
check "the app built with the default ref fetches that address" "$(grep -cF "\"$ADDR\"" "$P")" 1

echo "$fails failure(s)"
[ "$fails" = 0 ]
