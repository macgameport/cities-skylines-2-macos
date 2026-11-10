#!/bin/bash
# test-update-check.sh — exercises the launcher's pending-game-update check (step 2b, #17) without
# Steam, wine or the game. It sources the launcher's own code between the `>>> update-check` and
# `<<< update-check` markers, stubs what that code calls (note, step, die, steam_exe_up, ensure_patches),
# and writes minimal appmanifest_949230.acf fixtures. The apply path runs against a fake `wine`
# that records its arguments and then rewrites the fixture the way Steam does when an update lands.
#
#   bash scripts/test-update-check.sh [path/to/launch-cs2-dxmt11.sh]
#
# Exit 0 = every case passed. If the real pre-update manifest from 2026-10-10 is still in
# ~/cs2-patch/rollback-build23700737/, it is checked as well (local only; it is never committed,
# because it carries a SteamID).
#   MUTANT=1 ...   "Updating the game" is a pop-up again (note) and no step; must exit 1
#   MUTANT=2 ...   "Still updating" is a pop-up again and no step; must exit 1
#   MUTANT=3 ...   "Game updated" is a pop-up again and no step; must exit 1
#   MUTANT=4 ...   a total of 0 bytes is shown to the player as a size; must exit 1
#   MUTANT=5 ...   the dialog's answer is tested inside `[` again (lost to bash 3.2's brace expansion); must exit 1
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHER="${1:-$REPO/launchers/launch-cs2-dxmt11.sh}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

BLOCK="$T/block.sh"
sed -n '/^# >>> update-check/,/^# <<< update-check/p' "$LAUNCHER" > "$BLOCK"
[ -s "$BLOCK" ] || { echo "FAIL: no update-check block in $LAUNCHER"; exit 1; }
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
case "${MUTANT:-0}" in
  0) ;;
  1) sed -i '' -e 's/^  echo "Updating the game through Steam /  note "Updating the game through Steam /' -e '/^  step 4 "Updating the game\. This /d' "$BLOCK"
     grep -q '^  note "Updating the game through Steam ' "$BLOCK" && ! grep -q 'step 4 "Updating the game\. This ' "$BLOCK" || mutated ;;
  2) sed -i '' -e 's/^      echo "Still updating the game /      note "Still updating the game /' -e '/^      step 4 "Updating the game: /d' "$BLOCK"
     grep -q '^      note "Still updating the game ' "$BLOCK" && ! grep -q 'step 4 "Updating the game: ' "$BLOCK" || mutated ;;
  3) sed -i '' 's/then echo "Game updated to build \$UPD_FROM\."; step 4 "The game is updated…"; return 0; fi$/then note "Game updated to build $UPD_FROM."; return 0; fi/' "$BLOCK"
     grep -q 'then note "Game updated to build \$UPD_FROM\."; return 0; fi$' "$BLOCK" || mutated ;;
  4) sed -i '' '/^  \[ "\$((10#\$2))" = 0 \] && return 0 /d' "$BLOCK"; grep -q '= 0 \] && return 0' "$BLOCK" && mutated ;;
  5) python3 - "$BLOCK" <<'PY' || mutated
import io, sys
p = sys.argv[1]; s = io.open(p, encoding='utf-8').read()
a = s.index('        btn=$(osascript '); b = s.index('\n', a); c = s.index('\n', b + 1)
cmd = s[a + len('        btn='):b]
s = s[:a] + '        [ "' + cmd + '" = "Update first" ] && ans=update' + s[c:]
io.open(p, 'w', encoding='utf-8').write(s)
PY
     grep -q '^        \[ "\$(osascript ' "$BLOCK" || mutated ;;
  *) echo "REFUSED: no mutant ${MUTANT}"; exit 2 ;;
esac

mk_manifest() {   # flags buildid target [file]; BYTES_TODO and BYTES_DONE replace the two byte counts
  local f="${4:-$T/appmanifest_949230.acf}"
  cat > "$f" <<EOF
"AppState"
{
	"appid"		"949230"
	"StateFlags"		"$1"
	"buildid"		"$2"
	"BytesToDownload"		"${BYTES_TODO:-5108493840}"
	"BytesDownloaded"		"${BYTES_DONE:-0}"
	"TargetBuildID"		"$3"
	"InstalledDepots"
	{
		"949231"
		{
			"manifest"		"759759680630981357"
			"size"		"82891646983"
		}
	}
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
  env CS2_UPDATE_TIMEOUT=15 "$@" FAKE_ARGLOG="$T/$name.args" FAKE_MANIFEST="$T/appmanifest_949230.acf" \
    bash -c '
      set -u
      QUIET="${QUIET:-0}"; WINE="'"$FAKEWINE"'"; STEAM="steam.exe"
      MANIFEST="${MANIFEST_OVERRIDE:-'"$T"'/appmanifest_949230.acf}"
      note() { echo "NOTE: $1"; }
      step() { echo "STEP $1: $2"; }
      die()  { echo "DIE: $1"; exit 1; }
      steam_exe_up() { [ "${FAKE_STEAM_GONE:-0}" = 1 ] && return 1; return 0; }
      ensure_patches() { echo "ENSURE_PATCHES"; }
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
mk_manifest 4 25127643 25127643; run_case current $NUL
expect current has 'is current'; expect current lacks 'WARNING|steam://'

# 2. TargetBuildID 0 is "no target", not a pending build
mk_manifest 4 25127643 0; run_case target0 $NUL
expect target0 has 'is current'

# 3. the real 2026-10-10 state: StateFlags 6, build ids differ -> flagged; headless -> warn, launch
mk_manifest 6 23700737 25127643; run_case headless $NUL
expect headless has 'WARNING: game update waiting \(build 23700737 -> 25127643\)'
expect headless lacks 'steam://|ENSURE_PATCHES'; expect headless has 'RC:0'

# 4. StateFlags 4 but a different target build is still pending
mk_manifest 4 23700737 25127643; run_case flags4mismatch $NUL CS2_UPDATE=skip
expect flags4mismatch has 'WARNING: game update waiting'

# 5. StateFlags not 4 with no target recorded still counts
mk_manifest 6 23700737 ""; run_case flagsonly $NUL CS2_UPDATE=skip
expect flagsonly has 'WARNING: game update waiting \(build 23700737 -> \?\)'

# 6. unreadable manifest -> skipped, never fatal
run_case nomanifest $NUL MANIFEST_OVERRIDE="$T/does-not-exist.acf"
expect nomanifest has 'update check skipped'; expect nomanifest has 'RC:0'

# 7. apply: Steam finishes after 2 s -> validate forwarded, success noted, patches re-ensured
mk_manifest 6 23700737 25127643
run_case apply $NUL CS2_UPDATE=apply CS2_UPDATE_POLL=1 CS2_UPDATE_TICK=1 FAKE_DELAY=2 FAKE_NEWBUILD=25127643
expect apply has 'steam.exe steam://validate/949230'
expect apply has 'Game updated to build 25127643'
expect apply has 'ENSURE_PATCHES'; expect apply lacks 'DIE'
# 7b. each of the three progress messages is a line of detail in the log and a step 4 for the player's
#     window, never a pop-up. UPDATE_TICK is 1 s here so that "so far" is reached; it is 60 in a launch.
expect apply has '^Updating the game through Steam \(build 23700737 -> 25127643\)…$'
expect apply has '^STEP 4: Updating the game\. This can take several minutes…$'
expect apply has '^Still updating the game — 0 min so far \(StateFlags 6, 0 of 5108493840 bytes\)\.$'
expect apply has '^STEP 4: Updating the game: 0 min so far, 0\.0 of 5\.1 GB…$'
expect apply has '^Game updated to build 25127643\.$'
expect apply has '^STEP 4: The game is updated…$'
expect apply lacks '^NOTE: (Updating the game|Still updating|Game updated)'

# 8. apply, Steam never finishes -> dies at the timeout and does not repatch
mk_manifest 6 23700737 25127643
run_case timeout $NUL CS2_UPDATE=apply CS2_UPDATE_POLL=1 CS2_UPDATE_TIMEOUT=3
expect timeout has 'DIE: The game update did not finish'; expect timeout lacks 'ENSURE_PATCHES'

# 9. apply, Steam exits mid-update -> dies with that reason
mk_manifest 6 23700737 25127643
run_case steamgone $NUL CS2_UPDATE=apply CS2_UPDATE_POLL=1 FAKE_STEAM_GONE=1
expect steamgone has 'DIE: Steam exited while updating'

# 9b. the size in the player's line: shown when Steam gives one, left out when the total is 0 bytes
#     (Steam gives none) or the two numbers are equal (what an idle manifest keeps from the last update)
BYTES_DONE=3400000000 mk_manifest 6 23700737 25127643
run_case size $NUL CS2_UPDATE=apply CS2_UPDATE_POLL=1 CS2_UPDATE_TICK=1 CS2_UPDATE_TIMEOUT=2
expect size has '^STEP 4: Updating the game: 0 min so far, 3\.4 of 5\.1 GB…$'
BYTES_DONE=3400000000 BYTES_TODO=0 mk_manifest 6 23700737 25127643
run_case zerototal $NUL CS2_UPDATE=apply CS2_UPDATE_POLL=1 CS2_UPDATE_TICK=1 CS2_UPDATE_TIMEOUT=2
expect zerototal has '^STEP 4: Updating the game: 0 min so far…$'
expect zerototal has '^Still updating the game — 0 min so far \(StateFlags 6, 3400000000 of 0 bytes\)\.$'
expect zerototal lacks ' GB|syntax error|division by|integer expression|unbound variable|command not found'
BYTES_DONE=5108493840 mk_manifest 6 23700737 25127643
run_case equal $NUL CS2_UPDATE=apply CS2_UPDATE_POLL=1 CS2_UPDATE_TICK=1 CS2_UPDATE_TIMEOUT=2
expect equal has '^STEP 4: Updating the game: 0 min so far…$'; expect equal lacks ' GB'

# 9c. the app's dialog (QUIET=1), under /bin/bash 3.2, the shell the app runs: a fake `osascript` answers.
#     The answer was once tested inside `[`, where bash 3.2 brace-expands the dialog's {…, …}; `[` then got
#     too many arguments and "Update first" was lost (2026-11-10, a real click on the MacBook).
FAKEBIN="$T/fakebin"; mkdir -p "$FAKEBIN"
printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$@" >> "$FAKE_OSALOG"' '[ -n "${FAKE_BUTTON:-}" ] && echo "$FAKE_BUTTON"' 'exit 0' > "$FAKEBIN/osascript"
chmod +x "$FAKEBIN/osascript"
dialog_case() {   # dialog_case <name> <button or empty> <env...>
  local name="$1" button="$2"; shift 2
  : > "$T/$name.args"; : > "$T/$name.osa"
  mk_manifest 6 23700737 25127643
  env PATH="$FAKEBIN:$PATH" FAKE_BUTTON="$button" FAKE_OSALOG="$T/$name.osa" CS2_UPDATE_TIMEOUT=15 "$@" \
    FAKE_ARGLOG="$T/$name.args" FAKE_MANIFEST="$T/appmanifest_949230.acf" \
    /bin/bash -c '
      set -u
      QUIET=1; WINE="'"$FAKEWINE"'"; STEAM="steam.exe"; MANIFEST="'"$T"'/appmanifest_949230.acf"
      note() { echo "NOTE: $1"; }; step() { echo "STEP $1: $2"; }; die() { echo "DIE: $1"; exit 1; }
      steam_exe_up() { return 0; }; ensure_patches() { echo "ENSURE_PATCHES"; }
      . "'"$BLOCK"'"
      check_game_update; echo "RC:$?"
    ' < "$NUL" > "$T/$name.out" 2>&1
}
dialog_case dlgupdate "Update first" CS2_UPDATE_POLL=1 FAKE_DELAY=1 FAKE_NEWBUILD=25127643
expect dlgupdate has 'steam://validate/949230'; expect dlgupdate has 'ENSURE_PATCHES'
expect dlgupdate lacks 'too many arguments|WARNING: game update waiting'
if grep -q 'buttons {"Play anyway", "Update first"}' "$T/dlgupdate.osa"; then PASS=$((PASS + 1))
else FAIL=$((FAIL + 1)); echo "FAIL dlgupdate: osascript did not get the dialog's buttons whole"; fi
dialog_case dlgplay "Play anyway"
expect dlgplay has 'WARNING: game update waiting'; expect dlgplay lacks 'steam://|too many arguments'
dialog_case dlgnone ""
expect dlgnone has 'WARNING: game update waiting'; expect dlgnone lacks 'steam://|too many arguments'

# 10-12. interactive terminal (`script` supplies a tty): "n" plays, Enter updates, silence plays.
#        Input is held back 1 s: typed before the prompt, `script` loses it and sends EOF, which
#        also means "play" — so an undelayed "n" case passes vacuously (it did, 2026-10-10).
tty_case() {   # tty_case <name> <input> <env...>
  local name="$1" input="$2"; shift 2
  : > "$T/$name.args"
  printf '%s' "$input" > "$T/$name.in"
  mk_manifest 6 23700737 25127643
  # shellcheck disable=SC2016
  env CS2_UPDATE_TIMEOUT=15 "$@" FAKE_ARGLOG="$T/$name.args" FAKE_MANIFEST="$T/appmanifest_949230.acf" \
    script -q "$T/$name.out" bash -c '
      set -u
      QUIET=0; WINE="'"$FAKEWINE"'"; STEAM="steam.exe"; MANIFEST="'"$T"'/appmanifest_949230.acf"
      note() { echo "NOTE: $1"; }; step() { echo "STEP $1: $2"; }; die() { echo "DIE: $1"; exit 1; }
      steam_exe_up() { return 0; }; ensure_patches() { echo "ENSURE_PATCHES"; }
      . "'"$BLOCK"'"
      check_game_update; echo "RC:$?"
    ' < <(sleep 1; cat "$T/$name.in"; sleep 20) > /dev/null 2>&1
}
tty_case ttyno $'n\n'
expect ttyno has 'Update first\? \[Y/n\]'; expect ttyno has 'WARNING: game update waiting'
expect ttyno lacks 'steam://'
tty_case ttyyes $'\n' CS2_UPDATE_POLL=1 FAKE_DELAY=1 FAKE_NEWBUILD=25127643
expect ttyyes has 'steam://validate/949230'; expect ttyyes has 'ENSURE_PATCHES'
tty_case ttysilent '' CS2_UPDATE_ASK_SECS=1
expect ttysilent has 'WARNING: game update waiting'; expect ttysilent lacks 'steam://'

# 13. the real manifests, when present on this machine
REAL_OLD="$HOME/cs2-patch/rollback-build23700737/appmanifest_949230.acf"
REAL_NOW="$HOME/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/appmanifest_949230.acf"
if [ -f "$REAL_OLD" ]; then
  run_case realold $NUL MANIFEST_OVERRIDE="$REAL_OLD" CS2_UPDATE=skip
  expect realold has 'WARNING: game update waiting \(build 23700737 -> 25127643\)'
else echo "skip: no $REAL_OLD"; fi
if [ -f "$REAL_NOW" ]; then
  run_case realnow $NUL MANIFEST_OVERRIDE="$REAL_NOW"
  echo "live manifest: $(grep -m1 -E 'is current|WARNING' "$T/realnow.out")"
fi

echo "update-check: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
