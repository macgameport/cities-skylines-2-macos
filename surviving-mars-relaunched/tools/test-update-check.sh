#!/bin/bash
# test-update-check.sh — exercises launch-relaunched.sh's pending-game-update check (step 2b) without
# Steam, wine or the game. It sources the launcher's own code between the `>>> update-check` and
# `<<< update-check` markers, stubs what that code calls (note, step, die, steam_exe_up), and writes minimal
# appmanifest_3215050.acf fixtures. The apply path runs against a fake `wine` that records its arguments
# and then rewrites the fixture the way Steam does when an update lands. Adapted from cs2's
# scripts/test-update-check.sh (the original, for cs2's launch-cs2-dxmt11.sh § 2b).
#
#   bash tools/test-update-check.sh [path/to/launch-relaunched.sh]   exit 0 = every case passed
#   MUTANT=1 bash tools/test-update-check.sh                          update_pending always "current"; must exit 1
#   MUTANT=2 ...   "Updating the game" is a pop-up again (note) and no step; must exit 1
#   MUTANT=3 ...   "Still updating" is a pop-up again and no step; must exit 1
#   MUTANT=4 ...   "Game updated" is a pop-up again and no step; must exit 1
#   MUTANT=5 ...   a total of 0 bytes is shown to the player as a size; must exit 1
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHER="${1:-$REPO/launch-relaunched.sh}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

BLOCK="$T/block.sh"
sed -n '/^# >>> update-check/,/^# <<< update-check/p' "$LAUNCHER" > "$BLOCK"
[ -s "$BLOCK" ] || { echo "FAIL: no update-check block in $LAUNCHER"; exit 1; }
[ "${MUTANT:-0}" = 1 ] && echo 'update_pending() { UPD_FROM=x; UPD_TO=x; return 1; }' >> "$BLOCK"
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
case "${MUTANT:-0}" in
  0|1) ;;
  2) sed -i '' -e 's/^  echo "Updating the game through Steam /  note "Updating the game through Steam /' -e '/^  step 4 "Updating the game\. This /d' "$BLOCK"
     grep -q '^  note "Updating the game through Steam ' "$BLOCK" && ! grep -q 'step 4 "Updating the game\. This ' "$BLOCK" || mutated ;;
  3) sed -i '' -e 's/^      echo "Still updating the game /      note "Still updating the game /' -e '/^      step 4 "Updating the game: /d' "$BLOCK"
     grep -q '^      note "Still updating the game ' "$BLOCK" && ! grep -q 'step 4 "Updating the game: ' "$BLOCK" || mutated ;;
  4) sed -i '' 's/then echo "Game updated to build \$UPD_FROM\."; step 4 "The game is updated…"; return 0; fi$/then note "Game updated to build $UPD_FROM."; return 0; fi/' "$BLOCK"
     grep -q 'then note "Game updated to build \$UPD_FROM\."; return 0; fi$' "$BLOCK" || mutated ;;
  5) sed -i '' '/^  \[ "\$((10#\$2))" = 0 \] && return 0 /d' "$BLOCK"; grep -q '= 0 \] && return 0' "$BLOCK" && mutated ;;
  *) echo "REFUSED: no mutant ${MUTANT}"; exit 2 ;;
esac

mk_manifest() {   # flags buildid target [file]; BYTES_TODO and BYTES_DONE replace the two byte counts
  local f="${4:-$T/appmanifest_3215050.acf}"
  cat > "$f" <<EOF
"AppState"
{
	"appid"		"3215050"
	"StateFlags"		"$1"
	"buildid"		"$2"
	"BytesToDownload"		"${BYTES_TODO:-1048576000}"
	"BytesDownloaded"		"${BYTES_DONE:-0}"
	"TargetBuildID"		"$3"
	"AutoUpdateBehavior"		"1"
}
EOF
}

# Fake wine: logs argv, and on a steam:// URL rewrites the manifest to the finished state after
# FAKE_DELAY seconds (unset FAKE_DELAY = Steam never finishes).
FAKEWINE="$T/wine64"
cat > "$FAKEWINE" <<'EOF'
#!/bin/bash
echo "$*" >> "$FAKE_ARGLOG"
case "$*" in *steam://*)
  [ -n "${FAKE_DELAY:-}" ] && ( sleep "$FAKE_DELAY"
    sed -e 's/"StateFlags"\t\t"[0-9]*"/"StateFlags"\t\t"4"/' \
        -e "s/\"buildid\"\t\t\"[0-9]*\"/\"buildid\"\t\t\"$FAKE_NEWBUILD\"/" \
        "$FAKE_MANIFEST" > "$FAKE_MANIFEST.new" && mv "$FAKE_MANIFEST.new" "$FAKE_MANIFEST" ) & ;;
esac
exit 0
EOF
chmod +x "$FAKEWINE"

# run_case <name> <stdin-file> <env...> — runs check_game_update in a clean subshell, output to $T/<name>.out.
# Every case caps the update wait at 15 s: a mutant that never finishes must fail, not hang for an hour.
run_case() {
  local name="$1" in="$2"; shift 2
  : > "$T/$name.args"
  env SM_UPDATE_TIMEOUT=15 "$@" FAKE_ARGLOG="$T/$name.args" FAKE_MANIFEST="$T/appmanifest_3215050.acf" \
    bash -c '
      set -u
      QUIET="${QUIET:-0}"; STEAM_WINE="'"$FAKEWINE"'"; STEAM="steam.exe"
      MANIFEST="${MANIFEST_OVERRIDE:-'"$T"'/appmanifest_3215050.acf}"
      note() { echo "NOTE: $1"; }
      step() { echo "STEP $1: $2"; }
      die()  { echo "DIE: $1"; exit 1; }
      steam_exe_up() { [ "${FAKE_STEAM_GONE:-0}" = 1 ] && return 1; return 0; }
      . "'"$BLOCK"'"
      check_game_update
      echo "RC:$?"
    ' < "$in" > "$T/$name.out" 2>&1
}

PASS=0; FAIL=0
expect() {   # expect <name> has|lacks <regex>
  local name="$1" mode="$2" re="$3" hit=0
  grep -qE -- "$re" "$T/$name.out" "$T/$name.args" 2>/dev/null && hit=1
  if { [ "$mode" = has ] && [ "$hit" = 1 ]; } || { [ "$mode" = lacks ] && [ "$hit" = 0 ]; }; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1)); echo "FAIL [$name] expected $mode /$re/ — output:"; sed 's/^/    /' "$T/$name.out"
    [ -s "$T/$name.args" ] && sed 's/^/    wine: /' "$T/$name.args"
  fi
}

NUL=/dev/null

# 1. clean manifest: StateFlags 4, buildid == TargetBuildID -> not flagged
mk_manifest 4 25579348 25579348; run_case current $NUL
expect current has 'is current'; expect current lacks 'WARNING|steam://'

# 2. TargetBuildID 0 is "no target", not a pending build
mk_manifest 4 25579348 0; run_case target0 $NUL
expect target0 has 'is current'

# 3. an update waiting: StateFlags 6, build ids differ -> flagged; headless -> warn, launch
mk_manifest 6 25579348 25600000; run_case headless $NUL
expect headless has 'WARNING: game update waiting \(build 25579348 -> 25600000\)'
expect headless lacks 'steam://'; expect headless has 'RC:0'

# 4. StateFlags 4 but a different target build is still pending
mk_manifest 4 25579348 25600000; run_case flags4mismatch $NUL SM_UPDATE=skip
expect flags4mismatch has 'WARNING: game update waiting'

# 5. StateFlags not 4 with no target recorded still counts
mk_manifest 6 25579348 ""; run_case flagsonly $NUL SM_UPDATE=skip
expect flagsonly has 'WARNING: game update waiting \(build 25579348 -> \?\)'

# 6. unreadable manifest -> skipped, never fatal
run_case nomanifest $NUL MANIFEST_OVERRIDE="$T/does-not-exist.acf"
expect nomanifest has 'update check skipped'; expect nomanifest has 'RC:0'

# 7. apply: Steam finishes after 2 s -> validate forwarded through STEAM_WINE, success noted
mk_manifest 6 25579348 25600000
run_case apply $NUL SM_UPDATE=apply SM_UPDATE_POLL=1 SM_UPDATE_TICK=1 FAKE_DELAY=2 FAKE_NEWBUILD=25600000
expect apply has 'steam.exe steam://validate/3215050'
expect apply has 'Game updated to build 25600000'; expect apply lacks 'DIE'
# 7b. each of the three progress messages is a line of detail in the log and a step 4 for the player's
#     window, never a pop-up. UPDATE_TICK is 1 s here so that "so far" is reached; it is 60 in a launch.
expect apply has '^Updating the game through Steam \(build 25579348 -> 25600000\)…$'
expect apply has '^STEP 4: Updating the game\. This can take several minutes…$'
expect apply has '^Still updating the game — 0 min so far \(StateFlags 6, 0 of 1048576000 bytes\)\.$'
expect apply has '^STEP 4: Updating the game: 0 min so far, 0\.0 of 1\.0 GB…$'
expect apply has '^Game updated to build 25600000\.$'
expect apply has '^STEP 4: The game is updated…$'
expect apply lacks '^NOTE: (Updating the game|Still updating|Game updated)'

# 8. apply, Steam never finishes -> dies at the timeout
mk_manifest 6 25579348 25600000
run_case timeout $NUL SM_UPDATE=apply SM_UPDATE_POLL=1 SM_UPDATE_TIMEOUT=3
expect timeout has 'DIE: The game update did not finish'

# 9. apply, Steam exits mid-update -> dies with that reason
mk_manifest 6 25579348 25600000
run_case steamgone $NUL SM_UPDATE=apply SM_UPDATE_POLL=1 FAKE_STEAM_GONE=1
expect steamgone has 'DIE: Steam exited while updating'

# 9b. the size in the player's line: shown when Steam gives one, left out when the total is 0 bytes
#     (Steam gives none) or the two numbers are equal (what an idle manifest keeps from the last update)
BYTES_DONE=340000000 mk_manifest 6 25579348 25600000
run_case size $NUL SM_UPDATE=apply SM_UPDATE_POLL=1 SM_UPDATE_TICK=1 SM_UPDATE_TIMEOUT=2
expect size has '^STEP 4: Updating the game: 0 min so far, 0\.3 of 1\.0 GB…$'
BYTES_DONE=340000000 BYTES_TODO=0 mk_manifest 6 25579348 25600000
run_case zerototal $NUL SM_UPDATE=apply SM_UPDATE_POLL=1 SM_UPDATE_TICK=1 SM_UPDATE_TIMEOUT=2
expect zerototal has '^STEP 4: Updating the game: 0 min so far…$'
expect zerototal has '^Still updating the game — 0 min so far \(StateFlags 6, 340000000 of 0 bytes\)\.$'
expect zerototal lacks ' GB|syntax error|division by|integer expression|unbound variable|command not found'
BYTES_DONE=1048576000 mk_manifest 6 25579348 25600000
run_case equal $NUL SM_UPDATE=apply SM_UPDATE_POLL=1 SM_UPDATE_TICK=1 SM_UPDATE_TIMEOUT=2
expect equal has '^STEP 4: Updating the game: 0 min so far…$'; expect equal lacks ' GB'

# 10-12. interactive terminal (`script` supplies a tty): "n" plays, Enter updates, silence plays.
#        Input is held back 1 s: typed before the prompt, `script` loses it and sends EOF, which
#        also means "play" — so an undelayed "n" case passes vacuously (cs2, 2026-10-10).
tty_case() {   # tty_case <name> <input> <env...>
  local name="$1" input="$2"; shift 2
  : > "$T/$name.args"
  printf '%s' "$input" > "$T/$name.in"
  mk_manifest 6 25579348 25600000
  # shellcheck disable=SC2016
  env SM_UPDATE_TIMEOUT=15 "$@" FAKE_ARGLOG="$T/$name.args" FAKE_MANIFEST="$T/appmanifest_3215050.acf" \
    script -q "$T/$name.out" bash -c '
      set -u
      QUIET=0; STEAM_WINE="'"$FAKEWINE"'"; STEAM="steam.exe"; MANIFEST="'"$T"'/appmanifest_3215050.acf"
      note() { echo "NOTE: $1"; }; step() { echo "STEP $1: $2"; }; die() { echo "DIE: $1"; exit 1; }
      steam_exe_up() { return 0; }
      . "'"$BLOCK"'"
      check_game_update; echo "RC:$?"
    ' < <(sleep 1; cat "$T/$name.in"; sleep 20) > /dev/null 2>&1
}
tty_case ttyno $'n\n'
expect ttyno has 'Update first\? \[Y/n\]'; expect ttyno has 'WARNING: game update waiting'
expect ttyno lacks 'steam://'
tty_case ttyyes $'\n' SM_UPDATE_POLL=1 FAKE_DELAY=1 FAKE_NEWBUILD=25600000
expect ttyyes has 'steam://validate/3215050'; expect ttyyes has 'Game updated to build 25600000'
tty_case ttysilent '' SM_UPDATE_ASK_SECS=1
expect ttysilent has 'WARNING: game update waiting'; expect ttysilent lacks 'steam://'

# 13. the real manifest, when present on this machine (print only: its state is whatever Steam says)
REAL_NOW="$HOME/Applications/SurvivingMars.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/appmanifest_3215050.acf"
if [ -f "$REAL_NOW" ]; then
  run_case realnow $NUL MANIFEST_OVERRIDE="$REAL_NOW" SM_UPDATE=skip
  echo "live manifest: $(grep -m1 -E 'is current|WARNING|skipped' "$T/realnow.out")"
fi

echo "update-check: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
