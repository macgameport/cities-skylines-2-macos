#!/bin/bash
# build-winemac-visibility.sh — rebuild ONLY dlls/winemac.drv/winemac.so with
# -fvisibility=default, so macdrv's Metal helpers become callable by a third-party Metal layer.
#
# WHY (2026-08-29): notpop/steam-on-m1-wine renders Steam's CEF on a near-stock Wine 11, and per
# its README the enabler is NOT the vanilla-wined3d split (built + measured dead here) but two
# things: this visibility rebuild, and a DXMT fork that rewrites _CreateMetalViewFromHWND.
# Measured here: our winemac.so exports ZERO public text symbols — but so does the CrossOver-lineage
# build that DOES render Steam, so visibility is not that build's mechanism. This is a third,
# independent path we have never had. notpop's own success gate is `nm -g` >= 100 public T symbols.
#
# ⚠ This builds from the SAME DXMT-patched source as the engine (scripts/wineandaqua-dxmt.patch,
# which adds dlls/winemac.drv/dxmt_objc.m) and reuses the engine's exact configure line. A
# differently-configured winemac.so is not ABI-compatible with the installed engine.
#
# ⚠ It NEVER touches the daily wrapper. Output goes to a file; install it into a CLONE
# (scripts/make-vanilla-wrapper.sh shows the pattern) and test there.
#
# Usage:  bash scripts/build-winemac-visibility.sh
#         CS2_BUILD_DIR=~/cs2-patch/build-1116 bash scripts/build-winemac-visibility.sh
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${CS2_BUILD_DIR:-$HOME/cs2-patch/build-1116}"
WINE_VER=11.16
TARBALL_SHA=c66e2090343dcd727f7f7fd2f87ee0bfb0b118790c1d745ab7b8a4c3a4197f2f
APP="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
PKLIB="$APP/Contents/SharedSupport/wine/lib"
SRC="$WORK/wine-$WINE_VER"; PATCHED="$WORK/wine-$WINE_VER-dxmt"; B="$WORK/wine-1116-vis-build"
OUT="$WORK/winemac-visibility/winemac.so"
die(){ echo "ERROR: $1"; exit 1; }
step(){ echo; echo "== $1"; }

[ -d "$PKLIB" ] || die "no donor wrapper libs at $PKLIB"
command -v gmake >/dev/null || die "gmake missing (brew install make)"
[ -x /opt/homebrew/opt/bison/bin/bison ] || die "brew bison keg missing"

step "source + DXMT winemac patch"
if [ ! -f "$PATCHED/dlls/winemac.drv/dxmt_objc.m" ]; then
  if [ ! -d "$SRC" ]; then
    TB="$WORK/wine-$WINE_VER.tar.xz"
    [ -f "$TB" ] || curl -fL -o "$TB" "https://dl.winehq.org/wine/source/11.x/wine-$WINE_VER.tar.xz" || die "download failed"
    echo "$TARBALL_SHA  $TB" | shasum -a 256 -c - || die "tarball sha256 MISMATCH"
    tar -xJf "$TB" -C "$WORK" || die "unpack failed"
  fi
  cp -Rc "$SRC" "$PATCHED" 2>/dev/null || cp -R "$SRC" "$PATCHED"
  ( cd "$PATCHED" && patch -p1 < "$REPO/scripts/wineandaqua-dxmt.patch" ) || die "DXMT winemac patch did not apply"
fi
echo "  $PATCHED"

step "configure (engine's exact line + -fvisibility=default)"
mkdir -p "$B" && cd "$B"
if [ ! -f "$B/Makefile" ]; then
  PATH="/opt/homebrew/opt/bison/bin:$PATH" \
  "$PATCHED/configure" \
    --prefix="$WORK/vis-throwaway" \
    --host=x86_64-apple-darwin --enable-archs=i386,x86_64 \
    --without-x --without-gstreamer --without-sdl --without-cups --without-dbus \
    --without-inotify --without-krb5 --without-netapi --without-opencl --without-pcap \
    --without-pcsclite --without-usb --without-v4l2 \
    CC="clang -arch x86_64" CXX="clang++ -arch x86_64" \
    CFLAGS="-fvisibility=default -O2 -Wno-error" \
    CXXFLAGS="-fvisibility=default -O2 -Wno-error" \
    LDFLAGS="-L$PKLIB" \
    FREETYPE_CFLAGS="-I/opt/homebrew/opt/freetype/include/freetype2" \
    FREETYPE_LIBS="-L$PKLIB -lfreetype" \
    GNUTLS_CFLAGS="-I/opt/homebrew/opt/gnutls/include" \
    GNUTLS_LIBS="-L$PKLIB -lgnutls" \
    ac_cv_lib_soname_freetype=libfreetype.dylib \
    ac_cv_lib_soname_gnutls=libgnutls.dylib > "$WORK/vis-configure.log" 2>&1 \
    || die "configure failed — see $WORK/vis-configure.log"
fi
grep -q "winemac" "$B/Makefile" || die "winemac.drv is not in this build — configure dropped the mac driver"
echo "  configured"

step "build dlls/winemac.drv/winemac.so only"
PATH="/opt/homebrew/opt/bison/bin:$PATH" DYLD_FALLBACK_LIBRARY_PATH="$PKLIB" \
  gmake -j"$(sysctl -n hw.ncpu)" dlls/winemac.drv/winemac.so 2>&1 | tail -5
BUILT="$B/dlls/winemac.drv/winemac.so"
[ -f "$BUILT" ] || die "winemac.so was not produced"

step "gate: notpop's check is nm -g >= 100 public TEXT symbols"
T=$(nm -g "$BUILT" 2>/dev/null | grep -c " T ")
TOT=$(nm -g "$BUILT" 2>/dev/null | wc -l | tr -d ' ')
STOCK="$APP/Contents/SharedSupport/wine/lib/wine/x86_64-unix/winemac.so"
TS=$(nm -g "$STOCK" 2>/dev/null | grep -c " T ")
echo "  built  : public T=$T   (total globals $TOT)"
echo "  installed engine: public T=$TS"
mkdir -p "$(dirname "$OUT")"; cp "$BUILT" "$OUT"
echo "  -> $OUT"
[ "$T" -ge 100 ] && echo "  ✅ GATE PASSED (>=100)" || echo "  ⚠ GATE FAILED — only $T public text symbols"
