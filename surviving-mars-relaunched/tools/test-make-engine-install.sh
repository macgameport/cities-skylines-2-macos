#!/bin/bash
# test-make-engine-install.sh -- make-engine.sh --install on throwaway wrappers whose wine/ is an APFS clone
# of S734M's (no game, no Steam). Refusals: no path; a wrapper holding Cities2.exe; a Wine process using the
# wrapper; an existing wine.d3dm21-BAK without --rebuild. Then a real install (3.0 in, 2.1 kept as the BAK)
# and a --rebuild that builds from the BAK, never from the installed 3.0 engine.
#   bash tools/test-make-engine-install.sh            exit 0 = every case passed
#   MUTANT=1 bash tools/test-make-engine-install.sh   the Cities2.exe guard removed; must exit 1
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ME="$HERE/tools/make-engine.sh"
SRCW="$HOME/Applications/S734M.app/Contents/SharedSupport/wine"
[ -x "$SRCW/bin/wine64" ] || { echo "REFUSED: no S734M Wine to clone at $SRCW"; exit 2; }
mkdir -p "$HERE/scratch"
T="$(mktemp -d "$HERE/scratch/install-test.XXXX")"   # same volume as the source, so cp -c clones
FIX=""
cleanup() { [ -n "$FIX" ] && kill "$FIX" 2>/dev/null; wait 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
if [ "${MUTANT:-0}" = 1 ]; then
  sed '/holds Cities: Skylines II/d; /-name Cities2.exe/d' "$ME" > "$T/make-engine.sh"
  ME="$T/make-engine.sh"
fi
wrapper() {   # <name> -> a minimal wrapper with a cloned wine/ and an empty prefix
  local w="$T/$1.app/Contents/SharedSupport"
  mkdir -p "$w/prefix/drive_c/Program Files (x86)/Steam/steamapps/common"
  cp -c -R "$SRCW" "$w/wine"
  echo "$T/$1.app"
}
snap() { (cd "$1" && find . -maxdepth 4 | sort | shasum | cut -c1-12); }
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
run() { bash "$ME" "$@" > "$T/out" 2>&1; echo $?; }

check "no wrapper path is refused" "$(run --install)" 64

W=$(wrapper cs2like); mkdir -p "$W/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"
touch "$W/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II/Cities2.exe"
before=$(snap "$W"); rc=$(run --install "$W")
check "a wrapper holding Cities2.exe is refused" "$rc:$(grep -c 'holds Cities' "$T/out")" "1:1"
check "  ...and nothing in it changed" "$(snap "$W")" "$before"

W=$(wrapper busy); touch "$W/Contents/SharedSupport/prefix/system.reg"
( exec -a wine-fixture-hold tail -f "$W/Contents/SharedSupport/prefix/system.reg" ) >/dev/null 2>&1 & FIX=$!
sleep 1; before=$(snap "$W"); rc=$(run --install "$W")
check "a wrapper with a Wine process using it is refused" "$rc:$(grep -c 'is using' "$T/out")" "1:1"
check "  ...and nothing in it changed" "$(snap "$W")" "$before"
kill "$FIX" 2>/dev/null; wait "$FIX" 2>/dev/null; FIX=""

W=$(wrapper game); S="$W/Contents/SharedSupport"
rc=$(run --install "$W")
check "a clean wrapper installs" "$rc" 0
check "  ...wine/ is D3DMetal 3.0" "$(plutil -extract CFBundleShortVersionString raw "$S/wine/lib/external/D3DMetal.framework/Versions/A/Resources/Info.plist" 2>/dev/null)" 3.0
check "  ...the 2.1 original is the BAK" "$(plutil -extract CFBundleShortVersionString raw "$S/wine.d3dm21-BAK/lib/external/D3DMetal.framework/Versions/A/Resources/Info.plist" 2>/dev/null)" 2.1
check "  ...no wine.new left behind" "$([ -e "$S/wine.new" ] && echo left || echo none)" none

rc=$(run --install "$W")
check "a second install without --rebuild is refused" "$rc:$(grep -c 'already installed' "$T/out")" "1:1"
rc=$(run --install "$W" --rebuild)
check "--rebuild succeeds" "$rc" 0
check "  ...it built from the BAK" "$(grep -c 'source Wine : .*wine.d3dm21-BAK' "$T/out")" 1
check "  ...the BAK is still 2.1" "$(plutil -extract CFBundleShortVersionString raw "$S/wine.d3dm21-BAK/lib/external/D3DMetal.framework/Versions/A/Resources/Info.plist" 2>/dev/null)" 2.1
check "  ...wine/ is still 3.0" "$(plutil -extract CFBundleShortVersionString raw "$S/wine/lib/external/D3DMetal.framework/Versions/A/Resources/Info.plist" 2>/dev/null)" 3.0

echo "$fails failure(s)"
[ "$fails" = 0 ]
