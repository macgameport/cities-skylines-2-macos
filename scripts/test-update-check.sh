#!/bin/bash
# test-update-check.sh — exercises the launcher's pending-game-update check (step 2b, #17) without
# Steam, wine or the game. It sources the launcher's own code between the `>>> update-check` and
# `<<< update-check` markers, stubs what that code calls (note, die, steam_exe_up, ensure_patches),
# and writes minimal appmanifest_949230.acf fixtures. The apply path runs against a fake `wine`
# that records its arguments and then rewrites the fixture the way Steam does when an update lands.
#
#   bash scripts/test-update-check.sh [path/to/launch-cs2-dxmt11.sh]
#
# Exit 0 = every case passed. If the real pre-update manifest from 2026-10-10 is still in
# ~/cs2-patch/rollback-build23700737/, it is checked as well (local only; it is never committed,
# because it carries a SteamID).
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHER="${1:-$REPO/launchers/launch-cs2-dxmt11.sh}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

BLOCK="$T/block.sh"
sed -n '/^# >>> update-check/,/^# <<< update-check/p' "$LAUNCHER" > "$BLOCK"
[ -s "$BLOCK" ] || { echo "FAIL: no update-check block in $LAUNCHER"; exit 1; }

mk_manifest() {   # flags buildid target [file]
  local f="${4:-$T/appmanifest_949230.acf}"
  cat > "$f" <<EOF
"AppState"
{
	"appid"		"949230"
	"StateFlags"		"$1"
	"buildid"		"$2"
	"BytesToDownload"		"5108493840"
	"BytesDownloaded"		"0"
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
run_case apply $NUL CS2_UPDATE=apply CS2_UPDATE_POLL=1 FAKE_DELAY=2 FAKE_NEWBUILD=25127643
expect apply has 'steam.exe steam://validate/949230'
expect apply has 'Game updated to build 25127643'
expect apply has 'ENSURE_PATCHES'; expect apply lacks 'DIE'

# 8. apply, Steam never finishes -> dies at the timeout and does not repatch
mk_manifest 6 23700737 25127643
run_case timeout $NUL CS2_UPDATE=apply CS2_UPDATE_POLL=1 CS2_UPDATE_TIMEOUT=3
expect timeout has 'DIE: The game update did not finish'; expect timeout lacks 'ENSURE_PATCHES'

# 9. apply, Steam exits mid-update -> dies with that reason
mk_manifest 6 23700737 25127643
run_case steamgone $NUL CS2_UPDATE=apply CS2_UPDATE_POLL=1 FAKE_STEAM_GONE=1
expect steamgone has 'DIE: Steam exited while updating'

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
      note() { echo "NOTE: $1"; }; die() { echo "DIE: $1"; exit 1; }
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
