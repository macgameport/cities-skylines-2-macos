#!/bin/bash
# test-setup.sh -- scripts/setup.sh end to end with HOME at a scratch folder: a fake wrapper (a stub wine64,
# empty steam.exe and Cities2.exe), a scratch copy of scripts/, launchers/ and repatch.sh beside stub
# patchers, a stub xcrun so the app builder compiles nothing, and stubs for sw_vers, sysctl and arch so that
# any Mac can be played (and so that no Intel program is started). No game, no Wine, no network, no real
# patcher; nothing outside the scratch folder is read as an install or written.
#   bash scripts/test-setup.sh            exit 0 = every case passed
#   MUTANT=1 bash scripts/test-setup.sh   the badge patch is kept wherever a copy exists; must exit 1
#   MUTANT=2 bash scripts/test-setup.sh   --show-mod-badges leaves the marker behind; must exit 1
#   MUTANT=3 bash scripts/test-setup.sh   "setup complete" whatever failed; must exit 1
#   MUTANT=4 bash scripts/test-setup.sh   --dest takes no care of a missing value (it loops); must exit 1
#   MUTANT=5 bash scripts/test-setup.sh   macOS 15 counts as tested; must exit 1
#   MUTANT=6 bash scripts/test-setup.sh   the window builder (14unch3r) is never run; must exit 1
#   MUTANT=7 bash scripts/test-setup.sh   a failed window build counts as a setup problem; must exit 1
#   MUTANT=8 bash scripts/test-setup.sh   the window builder runs when the game's app was not built; must exit 1
# The window builder is a recording stub beside the scratch repo, at $T/common, where setup.sh looks for it.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d /tmp/setup-test.XXXX)"
trap 'rm -rf "$T"' EXIT
R="$T/repo"; mkdir -p "$R/patches" "$T/bin"
cp -R "$REPO/scripts" "$REPO/launchers" "$REPO/repatch.sh" "$R/"
S="$R/scripts/setup.sh"
mutate() {  # <sed expression> <grep that proves it applied>
  sed -i '' "$1" "$S"; grep -q "$2" "$S" || { echo "REFUSED: mutant did not apply"; exit 2; }
}
case "${MUTANT:-0}" in
  1) mutate 's#^    elif \[ -f "\$BADGE_DST" \] \&\& badge_has_run; then .*#    elif [ -f "$BADGE_DST" ]; then#' '^    elif \[ -f "\$BADGE_DST" \]; then$' ;;
  2) mutate 's#^    rm -f "\$BADGE_DST" "\$BADGE_MARK"$#    rm -f "$BADGE_DST"#' '^    rm -f "\$BADGE_DST"$' ;;
  3) mutate 's#^if \[ "\$problems" -gt 0 \]; then$#if false; then#' '^if false; then$' ;;
  4) mutate 's#^    --dest) .*#    --dest)    DEST="${2:-}"; shift 2 ;;#' '^    --dest)    DEST="${2:-}"; shift 2 ;;$' ;;
  5) mutate 's#^  26|27) say #  15|26|27) say #' '^  15|26|27) say ' ;;
  6) mutate 's#^  elif bash "\$WINDOW_BUILDER"; then$#  elif true; then#' '^  elif true; then$' ;;
  7) mutate 's#^    echo "  window: not built (see the line above)"$#    problems=$((problems+1)); echo "  window: not built (see the line above)"#' '^    problems=\$((problems+1)); echo "  window: not built' ;;
  8) perl -0pi -e 's/\nelse\n  # 14unch3r/\nfi\nif true; then\n  # 14unch3r/' "$S"; grep -q '^if true; then$' "$S" || { echo "REFUSED: mutant did not apply"; exit 2; } ;;
esac
for f in "$REPO"/patches/patch_*.py; do
  echo 'import os, sys; sys.exit(1 if os.environ.get("STUB_FAIL") == os.path.basename(sys.argv[0]) else 0)' > "$R/patches/$(basename "$f")"
done
NPATCH=$(ls "$R/patches" | wc -l | tr -d ' ')
mkdir -p "$R/patches/_vendor/lib"; echo vendored > "$R/patches/_vendor/lib/file.py"
printf '#!/bin/bash\nexit 1\n' > "$T/bin/xcrun"      # no swiftc: make-shortcut.sh skips the progress panel
# this Mac, as the case wants it: STUB_OSV (default 27.2), STUB_ARM64 (default 1), STUB_ROSETTA (exit code, default 0)
printf '#!/bin/bash\n[ "$1" = -productVersion ] && echo "${STUB_OSV-27.2}"\n' > "$T/bin/sw_vers"
printf '#!/bin/bash\n[ "$*" = "-n hw.optional.arm64" ] && { echo "${STUB_ARM64:-1}"; exit 0; }\nexec /usr/sbin/sysctl "$@"\n' > "$T/bin/sysctl"
printf '#!/bin/bash\n[ "$1" = -x86_64 ] && exit "${STUB_ROSETTA:-0}"\nexec /usr/bin/arch "$@"\n' > "$T/bin/arch"
chmod +x "$T/bin"/*
mkdir -p "$T/badpy"; printf '#!/bin/bash\nexit 1\n' > "$T/badpy/python3"; chmod +x "$T/badpy/python3"
# the window builder: a stub that records each call, and whether the game's app was there when it ran
export WINDOW_CALLS="$T/window.calls"; : > "$WINDOW_CALLS"
mkdir -p "$T/common"
cat > "$T/common/make-launcher-app.sh" << 'STUB'
#!/bin/bash
printf 'CALL args=%s app=%s\n' "$#" "$([ -f "$HOME/Applications/Cities Skylines II.app/Contents/MacOS/launch" ] && echo there || echo missing)" >> "$WINDOW_CALLS"
echo "stub: window builder"
exit "${STUB_WINDOW_RC:-0}"
STUB
cp -R "$R" "$T/repo2"; printf '#!/bin/bash\necho "stub: no app"; exit 1\n' > "$T/repo2/scripts/make-shortcut.sh"
BADGE="cs2-patch/patch-modconflict-badge.py"
MARK="cs2-patch/patches/.mod-badges-on"
GAME="Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"

home() {   # <dir> [wrapper name]: a HOME holding a fake wrapper with Steam and the game in it
  local p="$1/Applications/${2:-CS2dxmt11.app}/Contents/SharedSupport"
  mkdir -p "$p/wine/bin" "$1/Applications/${2:-CS2dxmt11.app}/$GAME/Cities2_Data/Managed"
  printf '#!/bin/bash\necho wine-11.0\n' > "$p/wine/bin/wine64"; chmod +x "$p/wine/bin/wine64"
  : > "$p/prefix/drive_c/Program Files (x86)/Steam/steam.exe"
  : > "$1/Applications/${2:-CS2dxmt11.app}/$GAME/Cities2.exe"
}
ran_here() { : > "$1/Applications/CS2dxmt11.app/$GAME/Cities2_Data/Managed/Game.dll.bak-modconflict-20260827-164900"; }
run() {    # <home> [setup.sh arguments]: output in <home>.out; echoes the exit code, or "timeout" after 20 s
  local h="$1" p i=0; shift
  env -u CS2_PATCH_DIR -u CS2_WRAPPER -u CS2_GAME_DIR -u CS2_ERRNO_PATCHES HOME="$h" PATH="${EXTRA_PATH:+$EXTRA_PATH:}$T/bin:$PATH" \
    bash "${SETUP_REPO:-$R}/scripts/setup.sh" "$@" > "$h.out" 2>&1 < /dev/null & p=$!
  while kill -0 $p 2>/dev/null; do
    i=$((i + 1)); [ $i -gt 200 ] && { kill -9 $p 2>/dev/null; wait $p 2>/dev/null; echo timeout; return; }
    sleep 0.1
  done
  wait $p; echo $?
}
snap() { (cd "$1" && find . | sort | shasum | cut -c1-12); }
said() { grep -c -- "$2" "$1.out"; }
has()  { if [ -e "$1" ]; then echo yes; else echo no; fi; }
lines() { wc -l < "$1" | tr -d ' '; }
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

# --- the clean run
H="$T/h1"; home "$H"
check "clean run exits 0" "$(run "$H")" 0
check "  ...says setup complete, and that all ten patch scripts finished" "$(said "$H" '^=== setup complete ===$'):$(said "$H" '^10 of 10 patch scripts finished without error$')" "1:1"
check "  ...on a tested Mac: no caution, and the three lines about the Mac" "$(said "$H" 'CAUTION\|caution'):$(said "$H" 'Apple Silicon  *OK$'):$(said "$H" 'Rosetta 2  *OK$'):$(said "$H" 'macOS 27.2  *OK (tested)$')" "0:1:1:1"
check "  ...the libraries the patch scripts use are installed with them" "$(cat "$H/cs2-patch/patches/_vendor/lib/file.py" 2>/dev/null)" vendored
check "  ...launcher, repatch.sh and every patch script are in the install folder" "$(has "$H/cs2-patch/launch-cs2-dxmt11.sh"):$(has "$H/cs2-patch/repatch.sh"):$(ls "$H/cs2-patch/patches"/*.py | wc -l | tr -d ' ')" "yes:yes:$NPATCH"
check "  ...the app is in Applications and starts the installed launcher" "$(grep -c "^SCRIPT=\"$H/cs2-patch/launch-cs2-dxmt11.sh\"$" "$H/Applications/Cities Skylines II.app/Contents/MacOS/launch" 2>/dev/null)" 1
check "  ...no badge file, no marker, and nothing said about the badge patch" "$(has "$H/$BADGE"):$(has "$H/$MARK"):$(said "$H" 'mod badge patch')" "no:no:0"

# --- the badge patch is opt-in
check "--hide-mod-badges exits 0" "$(run "$H" --hide-mod-badges)" 0
check "  ...installs the badge file and the marker, and says when it takes effect" "$(has "$H/$BADGE"):$(has "$H/$MARK"):$(said "$H" 'mod badge patch: on. It takes effect at the next launch')" "yes:yes:1"
echo stale > "$H/$BADGE"
check "a plain run before any launch exits 0" "$(run "$H")" 0
check "  ...keeps the badge file and refreshes it (it was asked for)" "$(cmp -s "$R/scripts/patch-modconflict-badge.py" "$H/$BADGE" && echo same || echo differs)" same
check "--show-mod-badges exits 0" "$(run "$H" --show-mod-badges)" 0
check "  ...removes the file and the marker and says how to put Game.dll back" "$(has "$H/$BADGE"):$(has "$H/$MARK"):$(said "$H" 'Verify integrity of game files'):$(said "$H" 'Game.dll.bak-modconflict-')" "no:no:1:1"
ran_here "$H"
check "after --show-mod-badges a plain run exits 0, even where the patch once ran" "$(run "$H")" 0
check "  ...and it stays off" "$(has "$H/$BADGE"):$(has "$H/$MARK")" "no:no"
check "both badge flags at once: exit 2" "$(run "$H" --hide-mod-badges --show-mod-badges):$(said "$H" 'cannot both be given')" "2:1"

# --- installs made before the patch became opt-in: every one of them holds a copy
H="$T/h2"; home "$H"; mkdir -p "$H/cs2-patch"; echo old > "$H/$BADGE"
check "an old copy that never ran: exit 0" "$(run "$H")" 0
check "  ...it is removed, and setup says so" "$(has "$H/$BADGE"):$(has "$H/$MARK"):$(said "$H" 'mod badge patch: off (it has never run here); --hide-mod-badges turns it on')" "no:no:1"
H="$T/h3"; home "$H"; mkdir -p "$H/cs2-patch"; echo old > "$H/$BADGE"; ran_here "$H"
check "an old copy where the patch has run: exit 0" "$(run "$H")" 0
check "  ...it is kept, refreshed, and the choice recorded" "$(cmp -s "$R/scripts/patch-modconflict-badge.py" "$H/$BADGE" && echo same || echo differs):$(has "$H/$MARK"):$(said "$H" 'mod badge patch: on, as before')" "same:yes:1"
rm "$H/Applications/CS2dxmt11.app/$GAME/Cities2_Data/Managed"/Game.dll.bak-modconflict-*
check "  ...and a later run keeps it after the backups are deleted" "$(run "$H"):$(has "$H/$BADGE")" "0:yes"

# --- a wrapper the badge patch does not know
H="$T/h4"; home "$H" CS2.app
check "--hide-mod-badges with another wrapper: exit 0, with a warning" "$(run "$H" --hide-mod-badges):$(said "$H" 'the badge patch only knows ~/Applications/CS2dxmt11.app')" "0:1"

# --- --check writes nothing, whatever else is asked
H="$T/h5"; home "$H"; before=$(snap "$H")
check "--check --hide-mod-badges exits 0" "$(run "$H" --check --hide-mod-badges)" 0
check "  ...and wrote nothing" "x$(snap "$H")" "x$before"

# --- a stale file in the installed library folder does not survive a run
H="$T/h6"; home "$H"; mkdir -p "$H/cs2-patch/patches/_vendor"; echo old > "$H/cs2-patch/patches/_vendor/stale.py"
check "a run replaces the installed library folder" "$(run "$H"):$(has "$H/cs2-patch/patches/_vendor/stale.py"):$(has "$H/cs2-patch/patches/_vendor/lib/file.py")" "0:no:yes"

# --- a Mac outside what has been tested: a caution, and setup goes on
H="$T/h7"; home "$H"
check "macOS 15: exit 0, setup complete" "$(STUB_OSV=15.5 run "$H"):$(said "$H" '^=== setup complete ===$')" "0:1"
check "  ...one CAUTION line with its reason, the paragraph, and no question (nobody is at a terminal)" "$(said "$H" 'macOS 15.5  *CAUTION$'):$(said "$H" 'older than anything this has been run on'):$(said "$H" '^1 caution(s): this Mac is outside'):$(said "$H" 'Press Return')" "1:1:1:0"
check "  ...a caution is not counted as a check" "$(said "$H" '^All 7 checks passed\.$')" 1
H="$T/h8"; home "$H"
check "macOS 28: a caution about Rosetta's end" "$(STUB_OSV=28.0 run "$H"):$(said "$H" 'macOS 28.0  *CAUTION$'):$(said "$H" 'last release with general Rosetta support')" "0:1:1"
check "macOS 13: a caution about the graphics layer's minimum" "$(STUB_OSV=13.6.1 run "$H"):$(said "$H" 'below the minimum of DXMT')" "0:1"
check "a version that cannot be read: a caution" "$(STUB_OSV= run "$H"):$(said "$H" 'macOS version  *CAUTION$')" "0:1"
check "an Intel Mac: a caution, and no Rosetta line" "$(STUB_ARM64=0 run "$H"):$(said "$H" 'Apple Silicon  *CAUTION$'):$(said "$H" 'Rosetta 2')" "0:1:0"
H="$T/h9"; home "$H"; before=$(snap "$H")
check "--check on macOS 15: the caution, exit 0" "$(STUB_OSV=15.5 run "$H" --check):$(said "$H" 'CAUTION$'):$(said "$H" '^(--check: stopping before making changes)$')" "0:1:1"
check "  ...and wrote nothing" "x$(snap "$H")" "x$before"

# --- what cannot work stops setup before anything is copied
check "no Rosetta: exit 1, the command to install it" "$(STUB_ROSETTA=1 run "$H"):$(said "$H" 'Rosetta 2  *MISSING$'):$(said "$H" 'softwareupdate --install-rosetta --agree-to-license')" "1:1:1"
check "  ...and wrote nothing" "x$(snap "$H")" "x$before"
check "a python3 that does not run: exit 1, the command to install it" "$(EXTRA_PATH="$T/badpy" run "$H"):$(said "$H" 'python3, version 3.8 or newer  *MISSING$'):$(said "$H" 'xcode-select --install')" "1:1:1"
check "  ...and wrote nothing" "x$(snap "$H")" "x$before"

# --- at a terminal, a caution asks before going on, and --yes answers it
pty() {   # <home> [setup.sh arguments]: setup with a terminal for stdin and one Return typed; output in <home>.out
  local h="$1"; shift
  printf '\n' | env -u CS2_PATCH_DIR -u CS2_WRAPPER -u CS2_GAME_DIR -u CS2_ERRNO_PATCHES HOME="$h" PATH="$T/bin:$PATH" STUB_OSV=15.5 \
    script -q /dev/null bash "$S" "$@" > "$h.out" 2>&1; echo $?
}
H="$T/h10"; home "$H"
check "macOS 15 at a terminal: the question is asked, and Return goes on" "$(pty "$H"):$(said "$H" 'Press Return to continue, or Control-C to stop'):$(said "$H" '=== setup complete ===')" "0:1:1"
check "  ...with --yes it is not asked" "$(pty "$H" --yes):$(said "$H" 'Press Return'):$(said "$H" '=== setup complete ===')" "0:0:1"

# --- failures are counted, said, and never end in "setup complete"
H="$T/h11"; home "$H"
check "a failing patch script: exit 1" "$(STUB_FAIL=patch_mkparent.py run "$H")" 1
check "  ...1 problem, no setup complete, the patch named" "$(said "$H" '^=== setup finished with 1 problem(s): see the lines marked !! above ===$'):$(said "$H" 'setup complete'):$(said "$H" '^FAILED: patch_mkparent.py$')" "1:0:1"
check "  ...and no closing instructions to play" "$(said "$H" '^Play:')" 0
H="$T/h12"; home "$H"
check "a failing app builder: exit 1" "$(SETUP_REPO="$T/repo2" run "$H")" 1
check "  ...1 problem, no setup complete" "$(said "$H" '^=== setup finished with 1 problem(s)'):$(said "$H" 'setup complete')" "1:0"
check "a failing patch script and a failing app builder: 2 problems" "$(SETUP_REPO="$T/repo2" STUB_FAIL=patch_cohtml.py run "$H"):$(said "$H" '^=== setup finished with 2 problem(s)')" "1:1"

# --- options
H="$T/h13"; home "$H"; before=$(snap "$H")
check "--dest with no value: exit 2 at once" "$(run "$H" --dest):$(said "$H" '^--dest needs a value$')" "2:1"
check "--dest with an empty value: exit 2 at once" "$(run "$H" --dest ''):$(said "$H" '^--dest needs a value$')" "2:1"
check "--stack with no value: exit 2 at once" "$(run "$H" --stack):$(said "$H" '^--stack needs a value$')" "2:1"
check "  ...none of those wrote anything" "x$(snap "$H")" "x$before"
check "--stack d3dmetal: exit 2 and the retirement sentence, nothing written" "$(run "$H" --stack d3dmetal):$(said "$H" '^The Wine 10 + D3DMetal stack was retired on 2026-11-09\. Its last version is commit [0-9a-f]\{7,40\}\.$'):x$(snap "$H")" "2:1:x$before"
check "--stack wine10: the same" "$(run "$H" --stack wine10):$(said "$H" 'stack was retired on 2026-11-09')" "2:1"
check "--stack with an unknown name: exit 2" "$(run "$H" --stack vulkan):$(said "$H" "unknown --stack")" "2:1"
check "--stack dxmt11 is still accepted" "$(run "$H" --stack dxmt11):$(said "$H" '^=== setup complete ===$')" "0:1"
check "--help prints the usage and stops before the code" "$(run "$H" --help):$(said "$H" 'bash scripts/setup.sh --check'):$(said "$H" '^set -u$')" "0:1:0"

# --- 14unch3r, the window's builder (docs/plans/launcher-window.md, 2.3; W10)
H="$T/hw"; home "$H"; : > "$WINDOW_CALLS"
check "14unch3r: setup runs the window builder once, with no arguments, after the game's app" "$(run "$H"):$(cat "$WINDOW_CALLS")" "0:CALL args=0 app=there"
check "  ...setup completes, and its closing lines name the window" "$(said "$H" '^=== setup complete ===$'):$(said "$H" 'or open 14unch3r')" "1:1"
for rc in 1 3; do
  : > "$WINDOW_CALLS"
  check "the window builder exits $rc: setup exits 0, says so once, counts no problem, marks nothing !!" \
    "$(STUB_WINDOW_RC=$rc run "$H"):$(said "$H" '^  window: not built (see the line above)$'):$(said "$H" '^=== setup complete ===$'):$(said "$H" 'setup finished with'):$(said "$H" '!!.*window'):$(said "$H" 'or open 14unch3r')" "0:1:1:0:0:0"
done
mkdir -p "$T/nocommon"; cp -R "$R" "$T/nocommon/repo"; : > "$WINDOW_CALLS"
check "no common/ beside the checkout: setup exits 0 and says the builder is not in this checkout" \
  "$(SETUP_REPO="$T/nocommon/repo" run "$H"):$(said "$H" '^  window: not built (common/make-launcher-app.sh is not in this checkout)$'):$(said "$H" '^=== setup complete ===$'):$(lines "$WINDOW_CALLS")" "0:1:1:0"
: > "$WINDOW_CALLS"
check "the game's app was not built: the window builder is not run" "$(SETUP_REPO="$T/repo2" run "$H"):$(lines "$WINDOW_CALLS")" "1:0"

echo "$fails failure(s)"
[ "$fails" = 0 ]
