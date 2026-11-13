#!/bin/bash
# test-setup.sh -- scripts/setup.sh (docs/plans/surviving-mars-install.md, 2.5, MT6). A copy of the game's
# folder runs in a scratch tree with HOME, the state folder and the app in a scratch folder. sysctl, sw_vers,
# arch, pgrep, ps, xcrun and osascript are stubs first on PATH, so this Mac's own processor, macOS and
# processes are not what is tested, no Swift is compiled and no game is looked for. make-app.sh is the real
# one (its progress window is skipped: the xcrun stub says there is no swiftc); common/make-launcher-app.sh
# is a stub that records how it was called. Nothing is written outside the scratch folder.
#   bash scripts/test-setup.sh            exit 0 = every case passed
#   MUTANT=<n> bash scripts/test-setup.sh   each must exit 1; 2 = the mutant did not apply
#     1 the app is pointed at the checkout's launcher     2 the helper is not copied
#     3 a copy is made only when none is there            4 a copy is written in place
#     5 a file in runs/ is removed                        6 the lock test is removed
#     7 the installer's own lock is refused               8 any live holder is passed
#     9 14unch3r is built in the real folder with SM_APP set
#    10 the test of who may write to the state folder is removed
#    11 the running-game test is removed                 12 --mac-only goes on to copy
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
T="$(mktemp -d /tmp/sm-setup-test.XXXX)"
OTHER=""
trap '[ -n "$OTHER" ] && kill "$OTHER" 2>/dev/null; rm -rf "$T"' EXIT
M="${MUTANT:-0}"
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

# --- the scratch tree: the game's folder as it is, and a recording stand-in for the 14unch3r builder
G="$T/repo/surviving-mars-relaunched"
mkdir -p "$G/scripts" "$G/tools" "$T/repo/common" "$T/bin" "$T/home/Applications"
cp "$HERE/scripts/setup.sh" "$G/scripts/"; cp "$HERE/launch-relaunched.sh" "$HERE/make-app.sh" "$G/"
cp "$HERE/tools/frame-fix.exe" "$G/tools/"
printf '#!/bin/bash\necho "make-launcher-app $*" >> "%s/calls"\nexit "${WINDOW_RC:-0}"\n' "$T" > "$T/repo/common/make-launcher-app.sh"
S="$G/scripts/setup.sh"
case "$M" in
  0) ;;
  1) sed -i '' 's|^if ! SM_SCRIPT="\$STATE/launch-relaunched.sh" bash |if ! SM_SCRIPT="$GAME_ROOT/launch-relaunched.sh" bash |' "$S" ;;
  2) sed -i '' '/^put "\$GAME_ROOT\/tools\/frame-fix.exe" /d' "$S" ;;
  3) sed -i '' 's|^  local tmp="\$2.new.\$\$"$|  local tmp="$2.new.$$"; [ -e "$2" ] \&\& return 0|' "$S" ;;
  4) sed -i '' 's|^  if cp "\$1" "\$tmp" \&\& chmod 755 "\$tmp" \&\& mv -f "\$tmp" "\$2"; then return 0; fi$|  if cp "$1" "$2" \&\& chmod 755 "$2"; then return 0; fi|' "$S" ;;
  5) sed -i '' 's|^put "\$GAME_ROOT/launch-relaunched.sh" |rm -f "$STATE/runs/kept.log"; put "$GAME_ROOT/launch-relaunched.sh" |' "$S" ;;
  6) sed -i '' 's|^if \[ -n "\$h" \] \&\& kill -0 "\$h" 2>/dev/null; then$|if false; then|' "$S" ;;
  7) sed -i '' 's/^  if \[ "\${SM_VIA_INSTALLER:-0}" != 1 \] || \[ "\$h" != "\$PPID" \]; then$/  if true; then/' "$S" ;;
  8) sed -i '' 's/^  if \[ "\${SM_VIA_INSTALLER:-0}" != 1 \] || \[ "\$h" != "\$PPID" \]; then$/  if [ "${SM_VIA_INSTALLER:-0}" != 1 ]; then/' "$S" ;;
  9) sed -i '' 's|^if \[ -n "\${SM_APP:-}" \]; then bash "\$REPO/common/make-launcher-app.sh" --dest "\$(dirname "\$APP")" |if [ -n "${SM_APP:-}" ]; then bash "$REPO/common/make-launcher-app.sh" |' "$S" ;;
  10) sed -i '' 's/^    own_folder "\$d" || /    true || /' "$S" ;;
  11) sed -i '' '/^if game_running; then /d' "$S" ;;
  12) sed -i '' '/^  \[ "\$ROSETTA" = 1 \] || exit 1$/{N;s/.*/  :/;}' "$S" ;;
  *) echo "REFUSED: no mutant $M"; exit 2 ;;
esac
if [ "$M" != 0 ]; then
  cmp -s "$HERE/scripts/setup.sh" "$S" && { echo "REFUSED: mutant $M did not apply"; exit 2; }
  bash -n "$S" || { echo "REFUSED: mutant $M does not parse"; exit 2; }
fi

# --- the stubs
stub() { printf '#!/bin/bash\n%s\n' "$2" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }
stub sysctl '[ "$*" = "-n hw.optional.arm64" ] && { echo "${STUB_ARM:-1}"; exit 0; }; exec /usr/sbin/sysctl "$@"'
stub sw_vers 'echo "${STUB_OS:-27.2.1}"'
stub arch 'exit "${STUB_ROSETTA_RC:-0}"'
stub pgrep 'case "$*" in "-f Mars\\.exe") [ "${STUB_GAME:-0}" = 1 ] && { echo 4242; exit 0; } ;; esac; exit 1'
stub ps 'case "$*" in *4242*) echo "${STUB_GAME_CMD:-}"; exit 0 ;; esac; exec /bin/ps "$@"'
stub xcrun 'exit 1'
stub osascript 'exit 0'

H="$T/home"; STATE="$T/state"; APP="$T/apps/Surviving Mars Relaunched.app"
W="$H/Applications/SurvivingMars.app"; PFX="$W/Contents/SharedSupport/prefix"
GAMEDIR="$PFX/drive_c/Program Files (x86)/Steam/steamapps/common/Project Spark"
mkdir -p "$GAMEDIR" "$T/apps"
run() {   # <args...>: setup's exit code; its output in $T/out. The caller sets STUB_* and SM_VIA_INSTALLER
  : > "$T/calls"
  (cd "$T" && PATH="$T/bin:$PATH" HOME="$H" SM_STATE="$STATE" SM_APP="$APP" SM_GAME_EXE="$GAMEDIR/Mars.exe" /bin/bash "$S" "$@") > "$T/out" 2>&1 < /dev/null
  echo $?
}
copies() { ls -A "$STATE" 2>/dev/null | grep -c -E '^launch-relaunched\.sh$|^tools$'; }
ino() { stat -f %i "$1" 2>/dev/null; }

# --- this Mac alone
check "--mac-only on a ready Mac: exit 0" "$(run --mac-only):$(grep -c 'OK (tested)' "$T/out")" "0:1"
check "  ...--yes and --check are taken" "$(run --mac-only --yes --check)" 0
check "  ...without Rosetta: exit 1" "$(STUB_ROSETTA_RC=1 run --mac-only):$(grep -c 'Rosetta 2  *MISSING' "$T/out")" "1:1"
check "  ...on an Intel Mac: exit 3, its own words" "$(STUB_ARM=0 run --mac-only):$(grep -c 'Intel processor' "$T/out")" "3:1"
check "  ...below macOS 14: exit 3, its own words" "$(STUB_OS=13.6.1 run --mac-only):$(grep -c 'does not load below macOS 14' "$T/out")" "3:1"
check "  ...on a macOS not tested: a caution, and exit 0" "$(STUB_OS=15.2 run --mac-only):$(grep -c 'CAUTION' "$T/out")" "0:1"
check "  ...and nothing was copied or built by any of them" "$(copies):$([ -e "$APP" ] && echo app || echo none):$(wc -l < "$T/calls" | tr -d ' ')" "0:none:0"
check "an unknown option is exit 2" "$(run --desktop)" 2
check "--check says what it would do and changes nothing" "$(run --check):$(grep -c 'would copy the launcher' "$T/out"):$(copies):$([ -e "$APP" ] && echo app || echo none)" "0:1:0:none"

# --- the whole of it
mkdir -p "$STATE/runs" "$STATE/backup"; echo "a run" > "$STATE/runs/kept.log"; echo "a save" > "$STATE/backup/kept.sav"
before="$(cd "$STATE" && find runs backup -type f -exec shasum {} + | shasum | cut -c1-12)"
rc=$(run)
check "setup on a ready Mac: exit 0" "$rc:$(grep -c '^=== setup complete ===$' "$T/out")" "0:1"
check "  ...the launcher is in the state folder, the same bytes" "$(cmp -s "$HERE/launch-relaunched.sh" "$STATE/launch-relaunched.sh" && echo same)" same
check "  ...and so is the helper, under tools/, where the launcher looks for it" "$(cmp -s "$HERE/tools/frame-fix.exe" "$STATE/tools/frame-fix.exe" && echo same):$(grep -c '^HELPER="\$HERE/tools/frame-fix.exe"$' "$STATE/launch-relaunched.sh")" "same:1"
check "  ...the app's program names that copy" "$(grep -c "^SCRIPT=\"$STATE/launch-relaunched.sh\"\$" "$APP/Contents/MacOS/launch" 2>/dev/null)" 1
check "  ...and no line of it names the folder setup ran from" "$(grep -c "$T/repo" "$APP/Contents/MacOS/launch" 2>/dev/null)" 0
check "  ...runs/ and backup/ are untouched, their files included" "$(cd "$STATE" && find runs backup -type f -exec shasum {} + | shasum | cut -c1-12)" "$before"
check "  ...the 14unch3r builder was called, to build beside the app" "$(cat "$T/calls")" "make-launcher-app --dest $T/apps"
check "  ...and nothing was built in the real place" "$(ls -A "$H/Applications" | tr '\n' ' ')" "SurvivingMars.app "
check "  ...no temporary copy is left in the state folder" "$(find "$STATE" -name '*.new.*' | wc -l | tr -d ' ')" 0
check "  ...the lines that say how to update speak of a checkout" "$(grep -c '^To update:  after  git pull , run  bash surviving-mars-relaunched/scripts/setup.sh  again\.$' "$T/out")" 1

# --- an older copy is replaced, by a rename and not in place
echo "an older launcher" > "$STATE/launch-relaunched.sh"; echo "an older helper" > "$STATE/tools/frame-fix.exe"
i1="$(ino "$STATE/launch-relaunched.sh")"; i2="$(ino "$STATE/tools/frame-fix.exe")"
rc=$(run)
check "an older copy of each is replaced" "$rc:$(cmp -s "$HERE/launch-relaunched.sh" "$STATE/launch-relaunched.sh" && echo same):$(cmp -s "$HERE/tools/frame-fix.exe" "$STATE/tools/frame-fix.exe" && echo same)" "0:same:same"
check "  ...by a rename: neither file is the one that was there" "$([ "$(ino "$STATE/launch-relaunched.sh")" != "$i1" ] && echo new):$([ "$(ino "$STATE/tools/frame-fix.exe")" != "$i2" ] && echo new)" "new:new"
check "14unch3r not built is not a problem" "$(WINDOW_RC=3 run):$(grep -c '14unch3r  *not built' "$T/out")" "0:1"

# --- what stops it, with nothing copied
refused() {   # <name> <want rc> <words>: after a run the caller made, the copies are still the older ones
  check "$1" "$rc:$(grep -c -- "$3" "$T/out"):$(cat "$STATE/launch-relaunched.sh")" "$2:1:an older launcher"
}
echo "an older launcher" > "$STATE/launch-relaunched.sh"
rc=$(STUB_GAME=1 STUB_GAME_CMD="$GAMEDIR/Mars.exe -x" run); refused "the game running stops it with exit 3" 3 "The game is running"
rc=$(STUB_GAME=1 STUB_GAME_CMD="/usr/bin/vim notes-about-Mars.exe" run)
check "  ...a process that only mentions Mars.exe does not" "$rc" 0
echo "an older launcher" > "$STATE/launch-relaunched.sh"
sleep 300 & OTHER=$!
ln -s "$OTHER" "$PFX/.launcher.lock"
rc=$(run); refused "a lock held by a live process stops it with exit 3" 3 "is using the game's wrapper (process $OTHER)"
rc=$(SM_VIA_INSTALLER=1 run); refused "  ...and so does that lock with SM_VIA_INSTALLER=1: it is not the parent's" 3 "is using the game's wrapper"
rm -f "$PFX/.launcher.lock"
# the installer's own lock: a parent process that holds the lock and runs setup as its child
parent() {   # <SM_VIA_INSTALLER value or "">: setup run by a shell whose own process number is in the lock
  : > "$T/calls"
  (cd "$T" && PATH="$T/bin:$PATH" HOME="$H" SM_STATE="$STATE" SM_APP="$APP" SM_GAME_EXE="$GAMEDIR/Mars.exe" VIA="$1" LOCKF="$PFX/.launcher.lock" S="$S" \
     /bin/bash -c 'ln -s "$$" "$LOCKF"; if [ -n "$VIA" ]; then SM_VIA_INSTALLER="$VIA" /bin/bash "$S"; else /bin/bash "$S"; fi; rc=$?; rm -f "$LOCKF"; exit $rc') > "$T/out" 2>&1 < /dev/null
  echo $?
}
rc=$(parent ""); refused "the parent's lock without SM_VIA_INSTALLER stops it with exit 3" 3 "is using the game's wrapper"
rc=$(parent 1)
check "run by the installer, its parent holding the lock: it goes on" "$rc:$(cmp -s "$HERE/launch-relaunched.sh" "$STATE/launch-relaunched.sh" && echo same)" "0:same"
check "  ...and the lines that say how to update speak of the installer" "$(grep -c '^To update:  open the installer again\.$' "$T/out")" 1
( : ) & dead=$!; wait "$dead" 2>/dev/null
ln -s "$dead" "$PFX/.launcher.lock"
check "a lock left by a process that is gone does not stop it" "$(run)" 0
rm -f "$PFX/.launcher.lock"; kill "$OTHER" 2>/dev/null; wait "$OTHER" 2>/dev/null; OTHER=""

echo "an older launcher" > "$STATE/launch-relaunched.sh"
chmod 777 "$STATE"
rc=$(run); refused "a state folder others can write to is refused" 1 "is not a folder of your own that only you can write to"
chmod 755 "$STATE"; chmod 775 "$STATE/tools"
rc=$(run); refused "  ...and so is a tools folder the group can write to" 1 "is not a folder of your own that only you can write to"
chmod 755 "$STATE/tools"
mkdir -p "$T/rootbin"; printf '#!/bin/sh\n[ "$1" = -u ] && { echo 0; exit 0; }\nexec /usr/bin/id "$@"\n' > "$T/rootbin/id"; chmod +x "$T/rootbin/id"
(cd "$T" && PATH="$T/rootbin:$T/bin:$PATH" HOME="$H" SM_STATE="$STATE" SM_APP="$APP" /bin/bash "$S") > "$T/out" 2>&1 < /dev/null; rc=$?
refused "root is refused" 1 "as root"
rm -f "$G/tools/frame-fix.exe"
rc=$(run); refused "with the helper gone from setup's own files it stops, and copies nothing" 1 "setup's own files are missing"
cp "$HERE/tools/frame-fix.exe" "$G/tools/"

# --- a state folder that is not there yet is made, for this user alone to write to
rm -rf "$STATE"
rc=$(run)
check "a state folder that is not there is made, and only its owner can write to it" "$rc:$(stat -f %Lp "$STATE"):$(stat -f %Lp "$STATE/tools")" "0:755:755"

# --- game_running is the launcher's own, word for word
fn() { awk '/^game_running\(\) \{$/ { p = 1 } p { print } p && /^\}$/ { exit }' "$1"; }
check "game_running equals the launcher's" "$(fn "$S" | shasum | cut -c1-12):$(fn "$S" | wc -l | tr -d ' ')" "$(fn "$HERE/launch-relaunched.sh" | shasum | cut -c1-12):8"

echo "$fails failure(s)"
[ "$fails" = 0 ]
