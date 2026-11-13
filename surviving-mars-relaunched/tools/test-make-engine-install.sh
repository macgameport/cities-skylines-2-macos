#!/bin/bash
# test-make-engine-install.sh -- make-engine.sh --install on throwaway wrappers whose wine/ is an APFS clone
# of S734M's Wine (no game, no Steam): the S734M wrapper's own while it is in ~/Applications, else the copy
# SurvivingMars.app keeps as wine.d3dm21-BAK (docs/plans/launcher-window.md, D11). Refusals: no path; a
# wrapper holding Cities2.exe; a Wine process using the wrapper; an existing wine.d3dm21-BAK without
# --rebuild. Then a real install (3.0 in, 2.1 kept as the BAK) and a --rebuild that builds from the BAK,
# never from the installed 3.0 engine. Then a swap stopped part way (docs/plans/surviving-mars-install.md,
# 2.4, MT8): a finished wine.new beside the BAK is moved in, with wine/ gone, half removed or whole; a
# wrapper in use keeps it; the script's own guard stops a second run and passes one left by a dead process;
# left-over clone folders go; a wine.new with no BAK is replaced; root is refused.
# It starts the Intel wine64 of a clone; tools/test-engine-source.sh checks only which Wine and which
# D3DMetal are chosen, and starts nothing.
# The D3DMetal 3.0 pieces come from CX_GPTK when it is given, and otherwise from the wine/lib of the
# installed SurvivingMars.app when its framework reads 3.0 (that folder has the shape CX_GPTK takes). No
# CrossOver is needed. What is installed is compared with that folder, never with a published checksum.
#   bash tools/test-make-engine-install.sh            exit 0 = every case passed; 2 = refused (no Wine, no pieces)
#   MUTANT=<n> bash tools/test-make-engine-install.sh   each must exit 1; 2 = the mutant did not apply
#     1 the Cities2.exe guard removed            2 the finishing move removed
#     3 the finishing move before the test for a Wine process
#     4 a finished swap falls through to the "already installed" refusal
#     5 the guard removed                        6 a dead process's guard obeyed
#     7 left-over clone folders kept             8 the root refusal removed
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ME="$HERE/tools/make-engine.sh"
SRCW="$HOME/Applications/S734M.app/Contents/SharedSupport/wine"
[ -d "$SRCW" ] || SRCW="$HOME/Applications/SurvivingMars.app/Contents/SharedSupport/wine.d3dm21-BAK"
[ -x "$SRCW/bin/wine64" ] || { echo "REFUSED: no Wine to clone at $SRCW"; exit 2; }
fwver() { plutil -extract CFBundleShortVersionString raw "$1/Versions/A/Resources/Info.plist" 2>/dev/null; }
GP="${CX_GPTK:-}"
if [ -z "$GP" ]; then
  GP="$HOME/Applications/SurvivingMars.app/Contents/SharedSupport/wine/lib"
  case "$(fwver "$GP/external/D3DMetal.framework")" in 3.*) ;; *) GP="" ;; esac
fi
[ -n "$GP" ] && [ -d "$GP/external/D3DMetal.framework" ] \
  || { echo "REFUSED: no D3DMetal 3.0 pieces: set CX_GPTK, or install the game's wrapper with D3DMetal 3.0"; exit 2; }
export CX_GPTK="$GP"
mkdir -p "$HERE/scratch"
T="$(mktemp -d "$HERE/scratch/install-test.XXXX")"   # same volume as the source, so cp -c clones
FIX=""
cleanup() { [ -n "$FIX" ] && kill "$FIX" 2>/dev/null; wait 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
M="${MUTANT:-0}"
if [ "$M" != 0 ]; then
  cp "$ME" "$T/make-engine.sh"
  case "$M" in
    1) sed -i '' '/holds Cities: Skylines II/d; /-name Cities2.exe/d' "$T/make-engine.sh" ;;
    2) sed -i '' 's|^    rm -rf "\$T/wine"; mv "\$OUT" "\$T/wine"$|    :|' "$T/make-engine.sh" ;;
    3) python3 - "$T/make-engine.sh" << 'PY'
import sys
p = sys.argv[1]; s = open(p).read()
a = s.index('  if [ -d "$OUT" ] && [ -e "$BAK" ]; then\n    rm -rf "$T/wine"'); b = s.index('  fi\n', a) + 5
block = s[a:b]; s = s[:a] + s[b:]
i = s.index("  for p in $(pgrep -f -i 'wine|steam|\\.exe'")
open(p, 'w').write(s[:i] + block + s[i:])
PY
       ;;
    4) sed -i '' '/^    \[ "\${3:-}" = --rebuild \] || exit 0$/d' "$T/make-engine.sh" ;;
    5) sed -i '' '/^  if \[ -n "\$h" \] && kill -0 "\$h" 2>\/dev\/null; then$/,/^  fi$/d; s|^  ln -s "\$\$" "\$GUARD" 2>/dev/null \|\| .*$|  ln -sf "$$" "$GUARD"|' "$T/make-engine.sh" ;;
    6) sed -i '' 's|^  if \[ -n "\$h" \] && kill -0 "\$h" 2>/dev/null; then$|  if [ -n "$h" ]; then|' "$T/make-engine.sh" ;;
    7) sed -i '' '/^  rm -rf "\$T"\/wine\.new\.tmp\.\*$/d' "$T/make-engine.sh" ;;
    8) sed -i '' '/^\[ "\$(id -u)" = 0 \] && /d' "$T/make-engine.sh" ;;
    *) echo "REFUSED: no mutant $M"; exit 2 ;;
  esac
  cmp -s "$ME" "$T/make-engine.sh" && { echo "REFUSED: mutant $M did not apply"; exit 2; }
  bash -n "$T/make-engine.sh" || { echo "REFUSED: mutant $M does not parse"; exit 2; }
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
same=yes
for f in external/libd3dshared.dylib wine/x86_64-windows/atidxx64.dll wine/x86_64-windows/d3d11.dll \
         wine/x86_64-windows/d3d12.dll wine/x86_64-windows/dxgi.dll external/D3DMetal.framework/Versions/A/D3DMetal; do
  cmp -s "$GP/$f" "$S/wine/lib/$f" || same="$f differs"
done
check "  ...the installed pieces equal the source folder's" "$same" yes
check "  ...the guard is gone" "$([ -e "$S/.engine-swap" ] || [ -L "$S/.engine-swap" ] && echo left || echo none)" none

rc=$(run --install "$W")
check "a second install without --rebuild is refused" "$rc:$(grep -c 'already installed' "$T/out")" "1:1"
rc=$(run --install "$W" --rebuild)
check "--rebuild succeeds" "$rc" 0
check "  ...it built from the BAK" "$(grep -c 'source Wine : .*wine.d3dm21-BAK' "$T/out")" 1
check "  ...the BAK is still 2.1" "$(plutil -extract CFBundleShortVersionString raw "$S/wine.d3dm21-BAK/lib/external/D3DMetal.framework/Versions/A/Resources/Info.plist" 2>/dev/null)" 2.1
check "  ...wine/ is still 3.0" "$(plutil -extract CFBundleShortVersionString raw "$S/wine/lib/external/D3DMetal.framework/Versions/A/Resources/Info.plist" 2>/dev/null)" 3.0

# --- a swap stopped part way: a finished wine.new beside the BAK ($W is installed: wine/ 3.0 and the BAK)
v() { fwver "$S/$1/lib/external/D3DMetal.framework"; }
mv "$S/wine" "$S/wine.new"; touch "$S/wine.new/NEW"
rc=$(run --install "$W")
check "wine/ gone beside a finished wine.new: finished, exit 0" "$rc:$(grep -c '^finished    : ' "$T/out"):$(grep -c 'source Wine' "$T/out")" "0:1:0"
check "  ...wine.new is now wine/, 3.0, and the BAK is 2.1" "$([ -e "$S/wine/NEW" ] && echo in):$(v wine):$(v wine.d3dm21-BAK):$([ -e "$S/wine.new" ] && echo left || echo none)" "in:3.0:2.1:none"
rm -f "$S/wine/NEW"
cp -c -R "$S/wine" "$S/wine.new"; touch "$S/wine.new/NEW"; rm -rf "$S/wine/bin"
rc=$(run --install "$W")
check "wine/ half removed: finished" "$rc:$([ -e "$S/wine/NEW" ] && echo in):$([ -x "$S/wine/bin/wine64" ] && echo whole)" "0:in:whole"
rm -f "$S/wine/NEW"
cp -c -R "$S/wine" "$S/wine.new"; touch "$S/wine.new/NEW"; mkdir "$S/wine.new.tmp.4242"
rc=$(run --install "$W")
check "wine/ whole: finished" "$rc:$([ -e "$S/wine/NEW" ] && echo in):$([ -e "$S/wine.new" ] && echo left || echo none)" "0:in:none"
check "  ...a left-over clone folder is removed" "$([ -e "$S/wine.new.tmp.4242" ] && echo left || echo none)" none
rm -f "$S/wine/NEW"
mv "$S/wine" "$S/wine.new"; touch "$S/wine.new/NEW"
rc=$(run --install "$W" --rebuild)
check "with --rebuild: finished, then rebuilt from the BAK" "$rc:$(grep -c '^finished    : ' "$T/out"):$(grep -c 'source Wine : .*wine.d3dm21-BAK' "$T/out"):$([ -e "$S/wine/NEW" ] && echo in || echo rebuilt):$(v wine)" "0:1:1:rebuilt:3.0"

cp -c -R "$S/wine" "$S/wine.new"; touch "$S/wine.new/NEW"
touch "$S/prefix/system.reg"
( exec -a wine-fixture-hold tail -f "$S/prefix/system.reg" ) >/dev/null 2>&1 & FIX=$!
sleep 1; before=$(snap "$W"); rc=$(run --install "$W")
check "a wrapper in use is refused before the finish" "$rc:$(grep -c 'is using' "$T/out"):$([ -e "$S/wine.new/NEW" ] && echo kept):$([ -e "$S/wine/NEW" ] && echo in || echo not)" "1:1:kept:not"
check "  ...and nothing in it changed" "$(snap "$W")" "$before"
kill "$FIX" 2>/dev/null; wait "$FIX" 2>/dev/null; FIX=""

ln -s "$$" "$S/.engine-swap"; before=$(snap "$W"); rc=$(run --install "$W")
check "a guard held by a live process stops a second run" "$rc:$(grep -c 'another make-engine.sh' "$T/out"):$([ -e "$S/wine.new/NEW" ] && echo kept)" "1:1:kept"
check "  ...and nothing in it changed, the guard included" "$(snap "$W"):$(readlink "$S/.engine-swap")" "$before:$$"
rm -f "$S/.engine-swap"
( : ) & dead=$!; wait "$dead" 2>/dev/null
ln -s "$dead" "$S/.engine-swap"; rc=$(run --install "$W")
check "a guard left by a process that is gone is replaced" "$rc:$([ -e "$S/wine/NEW" ] && echo in):$([ -L "$S/.engine-swap" ] && echo left || echo none)" "0:in:none"

W=$(wrapper nobak); S="$W/Contents/SharedSupport"
mkdir "$S/wine.new"; touch "$S/wine.new/JUNK"
rc=$(run --install "$W")
check "a wine.new with no BAK is not a finished swap: a clean install replaces it" "$rc:$(grep -c '^finished' "$T/out"):$(v wine):$(v wine.d3dm21-BAK):$([ -e "$S/wine/JUNK" ] && echo junk || echo clean)" "0:0:3.0:2.1:clean"

W=$(wrapper asroot); mkdir -p "$T/rootbin"; printf '#!/bin/sh\n[ "$1" = -u ] && { echo 0; exit 0; }\nexec /usr/bin/id "$@"\n' > "$T/rootbin/id"; chmod +x "$T/rootbin/id"
before=$(snap "$W"); rc=$(PATH="$T/rootbin:$PATH" run --install "$W")
check "root is refused" "$rc:$(grep -c 'as root' "$T/out")" "1:1"
check "  ...and nothing in it changed" "$(snap "$W")" "$before"

echo "$fails failure(s)"
[ "$fails" = 0 ]
