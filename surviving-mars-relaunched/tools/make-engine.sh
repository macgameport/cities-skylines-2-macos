#!/bin/bash
# make-engine.sh --install <wrapper.app> [--rebuild]   put D3DMetal 3.0 into the wrapper's own Wine
# make-engine.sh [<out-dir>]                            build a standalone engine (default $SM_WORK/engine/wine-d3dm30)
#
# Builds the Wine engine the game runs on: a copy of a Wine 10 Sikarugir engine with D3DMetal 3.0 (taken
# from CrossOver 26) in place of its D3DMetal 2.1. --install builds from the wrapper's own wine/, moves that
# aside as wine.d3dm21-BAK and puts the result in its place (cs2 build-engine-1116.sh's swap). It refuses a
# wrapper holding Cities: Skylines II (that game does not run on this engine), one with a Wine process
# running, and one already installed unless --rebuild, which rebuilds wine/ from the BAK (never from the
# installed 3.0 engine) and keeps the BAK. Standalone mode builds an engine to try elsewhere (cs2 C82).
#
# CX_GPTK=<dir>, when set, is the only place D3DMetal is looked for: a folder shaped like CrossOver's
# apple_gptk (external/D3DMetal.framework, external/libd3dshared.dylib, wine/x86_64-windows/*.dll), or a
# CrossOver.app. One that holds no framework, or an empty value, stops the script. Not set, a CrossOver in
# ~/Applications or /Applications is used.
#
# A swap stopped part way (docs/plans/surviving-mars-install.md, 2.4). The new Wine is built as
# wine.new.tmp.<pid> and gets the name wine.new only when it is whole; then wine/ is moved aside (or, on a
# rebuild, removed) and wine.new moved in. So a wine.new beside the BAK is a whole engine whose last move
# did not happen: --install first removes what is left of wine/ and moves it in, prints "finished", and
# without --rebuild exits 0. Left-over wine.new.tmp.* folders are removed. While it changes a wrapper the
# script holds Contents/SharedSupport/.engine-swap, a link to its process number: a second run stops at
# it, and one left by a process that is gone is replaced. It refuses to run as root.
#
# Why (Studio, M5 Max, macOS 27.2, 2026-11-07): under D3DMetal 2.1 a landscaping project (RC Dozer:
# Flatten, Ramp, ...) turns the whole map black with a few bright pixels flickering, and a save that holds
# one comes back black on every load, while saves without one render normally. The same save ("Archibald",
# a pending Ramp) renders correctly on this engine, and a new landscaping area placed with the Ramp tool
# on it also rendered normally. Ruled out under 2.1 first: D3DM_SAMPLE_NAN_TO_ZERO=1 +
# D3DM_FLUSH_POS_INF_TO_NAN=1 (no change), and Options > Video > Antialiasing = SMAA (no change; whether
# that also took FSR 2 out of use was not verified).
#
# Standalone mode builds from the S734M wrapper's Wine while that wrapper is in ~/Applications, and from
# the copy of it SurvivingMars.app keeps as wine.d3dm21-BAK once it is gone: the wrapper goes to the
# Trash, and its name to the Steam app (docs/plans/launcher-window.md, D11). Either is only read.
# The four D3DMetal DLLs and their Mac-side libraries change layout between the versions: 2.1 has a
# separate d3d12.so/dxgi.so/... per DLL, 3.0 links all of them to one libd3dshared.dylib.
# Rebuild after the source Wine or CrossOver is updated: it replaces <out-dir>.
set -eu
[ "$(id -u)" = 0 ] && { echo "ERROR: do not run make-engine.sh as root (with sudo): it would leave files only root can change"; exit 1; }
SM_WORK="${SM_WORK:-$HOME/Library/Developer/1launcher/surviving-mars-relaunched}"
# ENGINE_SRC=<wine dir> clones another engine instead (the unified-stack probe used the daily CS2
# wrapper's Wine 11.16, which exports the same macdrv_functions table D3DMetal reaches Wine through).
INSTALL=""
if [ "${1:-}" = --install ]; then
  INSTALL="${2:-}"
  [ -n "$INSTALL" ] || { echo "usage: make-engine.sh --install <wrapper.app> [--rebuild]"; exit 64; }
  T="${INSTALL%/}/Contents/SharedSupport"
  BAK="$T/wine.d3dm21-BAK"
  OUT="$T/wine.new"
  # a wrapper whose wine/ is gone is still one when a finished wine.new waits beside the BAK
  { [ -d "$T/wine" ] || { [ -d "$OUT" ] && [ -e "$BAK" ]; }; } && [ -d "$T/prefix" ] \
    || { echo "ERROR: $INSTALL is not a wrapper (no Contents/SharedSupport/wine + prefix)"; exit 1; }
  [ -z "$(find "$T/prefix/drive_c/Program Files (x86)/Steam/steamapps/common" -maxdepth 2 -name Cities2.exe 2>/dev/null)" ] \
    || { echo "ERROR: $INSTALL holds Cities: Skylines II, so it is a cs2 wrapper; refusing to change its engine"; exit 1; }
  for p in $(pgrep -f -i 'wine|steam|\.exe' 2>/dev/null); do
    lsof -p "$p" 2>/dev/null | grep -qF "$T/" && { echo "ERROR: a Wine process (pid $p) is using $INSTALL; quit it first"; exit 1; }
  done
  GUARD="$T/.engine-swap"
  h="$(readlink "$GUARD" 2>/dev/null || true)"
  if [ -n "$h" ] && kill -0 "$h" 2>/dev/null; then
    echo "ERROR: another make-engine.sh (process $h) is changing $INSTALL; wait for it to finish"; exit 1
  fi
  [ -n "$h" ] && [ "$(readlink "$GUARD" 2>/dev/null || true)" = "$h" ] && rm -f "$GUARD"   # left by a run that died
  ln -s "$$" "$GUARD" 2>/dev/null || { echo "ERROR: another make-engine.sh is changing $INSTALL; wait for it to finish"; exit 1; }
  trap '[ "$(readlink "$GUARD" 2>/dev/null)" = "$$" ] && rm -f "$GUARD"' EXIT
  rm -rf "$T"/wine.new.tmp.*
  if [ -d "$OUT" ] && [ -e "$BAK" ]; then
    rm -rf "$T/wine"; mv "$OUT" "$T/wine"
    echo "finished    : $T/wine (an engine swap that was stopped part way)"
    [ "${3:-}" = --rebuild ] || exit 0
  fi
  if [ -e "$BAK" ]; then
    [ "${3:-}" = --rebuild ] || { echo "ERROR: $BAK exists, so D3DMetal 3.0 is already installed; --rebuild rebuilds wine/ from the BAK"; exit 1; }
    SRC="$BAK"
  else
    SRC="$T/wine"
  fi
else
  # A Steam app named S734M.app has no SharedSupport, so it is passed over like an absent wrapper
  SRC="$HOME/Applications/S734M.app/Contents/SharedSupport/wine"
  [ -d "$SRC" ] || SRC="$HOME/Applications/SurvivingMars.app/Contents/SharedSupport/wine.d3dm21-BAK"
  SRC="${ENGINE_SRC:-$SRC}"
  OUT="${1:-$SM_WORK/engine/wine-d3dm30}"
fi
GPTK=""
if [ -n "${CX_GPTK+set}" ]; then
  c="$CX_GPTK"
  [ -n "$c" ] && [ -d "$c/Contents/SharedSupport/CrossOver/lib64/apple_gptk" ] && c="$c/Contents/SharedSupport/CrossOver/lib64/apple_gptk"
  [ -n "$c" ] && [ -d "$c/external/D3DMetal.framework" ] \
    || { echo "ERROR: CX_GPTK is set to '$CX_GPTK', which holds no external/D3DMetal.framework; nothing else is looked in"; exit 1; }
  GPTK="$c"
else
  for c in "$HOME/Applications/CrossOver.app" "/Applications/CrossOver.app"; do
    [ -d "$c/Contents/SharedSupport/CrossOver/lib64/apple_gptk" ] && c="$c/Contents/SharedSupport/CrossOver/lib64/apple_gptk"
    [ -d "$c/external/D3DMetal.framework" ] && { GPTK="$c"; break; }
  done
fi
[ -x "$SRC/bin/wine64" ] || { echo "ERROR: no Wine engine at $SRC"; exit 1; }
nm -gU "$SRC/lib/wine/x86_64-unix/winemac.so" 2>/dev/null | grep -q " _macdrv_functions$" \
  || { echo "ERROR: $SRC's winemac.so does not export macdrv_functions, which D3DMetal needs"; exit 1; }
# D3DMetal's DLLs call ntdll's __wine_unix_call export. Wine 10 has it; Wine 11 (Porting Kit's 11.0, the
# cs2 11.16 build) exports only __wine_unix_call_dispatcher, and the game aborts at start with "unimplemented
# function ntdll.dll.__wine_unix_call" (unified-stack probe, 2026-11-07).
# Re-adding the export to an 11.16 ntdll is no fix: Steam then crashes at start (A/B, same date). A side DLL
# supplying it got D3DMetal loaded, but the game still crashed; that route is archived in
# tools/archive/wine11/ (cs2 EXPERIMENTS C83). So a Wine 11 source is refused.
HERE="$(cd "$(dirname "$0")" && pwd)"
LC_ALL=C tr '\0' '\n' < "$SRC/lib/wine/x86_64-windows/ntdll.dll" | grep -qx '__wine_unix_call' \
  || { echo "ERROR: $SRC's ntdll.dll does not export __wine_unix_call, which D3DMetal's DLLs call (Wine 11; see tools/archive/wine11/)"; exit 1; }
[ -n "$GPTK" ] || { echo "ERROR: no CrossOver D3DMetal found (install CrossOver 26, or set CX_GPTK=<.../apple_gptk>)"; exit 1; }
ver() { plutil -extract CFBundleShortVersionString raw "$1/Versions/A/Resources/Info.plist" 2>/dev/null \
          || plutil -extract CFBundleShortVersionString raw "$1/Resources/Info.plist"; }
echo "source Wine : $SRC ($("$SRC/bin/wine64" --version), D3DMetal $(ver "$SRC/lib/external/D3DMetal.framework" 2>/dev/null || echo none))"
echo "D3DMetal    : $GPTK ($(ver "$GPTK/external/D3DMetal.framework"))"

TMP="$OUT.tmp.$$"
rm -rf "$TMP"; mkdir -p "$(dirname "$OUT")"
cp -c -R "$SRC" "$TMP"                      # APFS clone: near-instant, shares blocks with the source
L="$TMP/lib"
mkdir -p "$L/external"
rm -rf "$L/external/D3DMetal.framework" "$L/external/libd3dshared.dylib"
cp -c -R "$GPTK/external/D3DMetal.framework" "$L/external/"
cp -c "$GPTK/external/libd3dshared.dylib" "$L/external/"
for d in atidxx64 d3d11 d3d12 dxgi; do
  cp -c "$GPTK/wine/x86_64-windows/$d.dll" "$L/wine/x86_64-windows/$d.dll"
  rm -f "$L/wine/x86_64-unix/$d.so"
  ln -s ../../external/libd3dshared.dylib "$L/wine/x86_64-unix/$d.so"
done
for d in atidxx64 d3d11 d3d12 dxgi; do
  cmp -s "$GPTK/wine/x86_64-windows/$d.dll" "$L/wine/x86_64-windows/$d.dll" || { echo "ERROR: $d.dll did not copy"; exit 1; }
  [ "$(readlink "$L/wine/x86_64-unix/$d.so")" = ../../external/libd3dshared.dylib ] || { echo "ERROR: $d.so link"; exit 1; }
done
rm -rf "$OUT"; mv "$TMP" "$OUT"
if [ -n "$INSTALL" ]; then
  if [ "$SRC" = "$BAK" ]; then rm -rf "$T/wine"; else mv "$T/wine" "$BAK"; fi
  mv "$OUT" "$T/wine"
  OUT="$T/wine"
  [ "$(ver "$OUT/lib/external/D3DMetal.framework")" = 3.0 ] || { echo "ERROR: installed D3DMetal is not 3.0"; exit 1; }
  echo "installed   : $OUT (2.1 original kept as $(basename "$BAK"))"
fi
echo "built       : $OUT (D3DMetal $(ver "$OUT/lib/external/D3DMetal.framework"), $("$OUT/bin/wine64" --version))"
