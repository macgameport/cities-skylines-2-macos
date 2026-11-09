#!/bin/bash
# test-setup.sh -- scripts/setup.sh end to end with HOME at a scratch folder: a fake wrapper (a stub wine64,
# empty steam.exe and Cities2.exe), a scratch copy of scripts/, launchers/ and repatch.sh beside stub
# patchers, and a stub xcrun so the app builder compiles nothing. No game, no Wine, no network, no real
# patcher; nothing outside the scratch folder is read as an install or written.
#   bash scripts/test-setup.sh            exit 0 = every case passed
#   MUTANT=1 bash scripts/test-setup.sh   the badge patch is kept wherever a copy exists; must exit 1
#   MUTANT=2 bash scripts/test-setup.sh   --show-mod-badges leaves the marker behind; must exit 1
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
esac
for f in "$REPO"/patches/patch_*.py; do
  echo 'import os, sys; sys.exit(1 if os.environ.get("STUB_FAIL") == os.path.basename(sys.argv[0]) else 0)' > "$R/patches/$(basename "$f")"
done
NPATCH=$(ls "$R/patches" | wc -l | tr -d ' ')
printf '#!/bin/bash\nexit 1\n' > "$T/bin/xcrun"      # no swiftc: make-shortcut.sh skips the progress panel
chmod +x "$T/bin"/*
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
  env -u CS2_PATCH_DIR -u CS2_WRAPPER -u CS2_GAME_DIR -u CS2_ERRNO_PATCHES HOME="$h" PATH="$T/bin:$PATH" \
    bash "$S" "$@" > "$h.out" 2>&1 & p=$!
  while kill -0 $p 2>/dev/null; do
    i=$((i + 1)); [ $i -gt 200 ] && { kill -9 $p 2>/dev/null; wait $p 2>/dev/null; echo timeout; return; }
    sleep 0.1
  done
  wait $p; echo $?
}
snap() { (cd "$1" && find . | sort | shasum | cut -c1-12); }
said() { grep -c -- "$2" "$1.out"; }
has()  { if [ -e "$1" ]; then echo yes; else echo no; fi; }
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

# --- the clean run
H="$T/h1"; home "$H"
check "clean run exits 0" "$(run "$H")" 0
check "  ...says setup complete" "$(said "$H" '^=== setup complete ===$')" 1
check "  ...launcher, repatch.sh and every patch script are in the install folder" "$(has "$H/cs2-patch/launch-cs2-dxmt11.sh"):$(has "$H/cs2-patch/repatch.sh"):$(ls "$H/cs2-patch/patches" | wc -l | tr -d ' ')" "yes:yes:$NPATCH"
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

echo "$fails failure(s)"
[ "$fails" = 0 ]
