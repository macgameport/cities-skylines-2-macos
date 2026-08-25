#!/bin/bash
# build-engine-1116.sh — build a stock wine 11.16 + DXMT engine and install it into your
# Porting Kit wrapper. This retires the alt-tab/exclusive-fullscreen freeze (dxmt#206):
# wine 11.16 fixed it upstream, but no prebuilt clean-base 11.16 DXMT engine exists yet.
#
# What it does (fully local, redistributes nothing):
#   1. checks toolchain + your existing Wine 11 + DXMT wrapper
#   2. downloads the official wine-11.16 source from winehq.org (sha256-verified)
#   3. applies the winemac DXMT-support patch (aquadran's, in this repo)
#   4. builds wine (x86_64 + i386 PE, new-WoW64) — roughly 45-60 min on an M3 Max
#   5. assembles the engine, reusing the DXMT binaries and x86_64 dylibs FROM YOUR OWN wrapper
#   6. swaps it into the wrapper (old engine kept as wine.pk11.0-BAK — rollback is one `mv`)
#   7. runs the one-time prefix update in a controlled way (no hidden dialogs)
#
# Usage:  bash scripts/build-engine-1116.sh            # build + install
#         CS2_WRAPPER=/path/to/Wrapper.app bash scripts/build-engine-1116.sh
#
# Every non-obvious flag below was earned by a live failure on 2026-08-23 — see
# docs/plans/build-wine1116-dxmt-engine.md for the full story.
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${CS2_BUILD_DIR:-/tmp}"
WINE_VER=11.16
TARBALL_SHA=c66e2090343dcd727f7f7fd2f87ee0bfb0b118790c1d745ab7b8a4c3a4197f2f
E="$WORK/engine-1116"
die(){ echo "ERROR: $1"; exit 1; }
step(){ echo; echo "== $1"; }

# ---------------------------------------------------------------- 0. preflight
step "Preflight"
APP="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
[ -d "$APP/Contents/SharedSupport/prefix" ] || die "no wrapper at $APP — install the base stack first (INSTALL.md steps 1-4), or set CS2_WRAPPER"
PK="$APP/Contents/SharedSupport/wine"
PKLIB="$PK/lib"
for f in "$PK/lib/wine/x86_64-unix/winemetal.so" \
         "$PK/lib/wine/x86_64-windows/d3d11.dll" "$PK/lib/wine/i386-windows/d3d11.dll" \
         "$PKLIB/libfreetype.dylib" "$PKLIB/libgnutls.dylib"; do
  [ -e "$f" ] || die "wrapper is missing $f — this script needs the Porting Kit Wine11+DXMT engine as its donor"
done
command -v brew >/dev/null || die "Homebrew required (brew.sh)"
echo "  installing/confirming brew deps (mingw-w64 bison make pkgconf freetype gnutls)…"
brew install mingw-w64 bison make pkgconf freetype gnutls >/dev/null 2>&1 || true
for t in x86_64-w64-mingw32-gcc i686-w64-mingw32-gcc gmake; do
  command -v "$t" >/dev/null || die "$t not found after brew install"
done
[ -x /opt/homebrew/opt/bison/bin/bison ] || die "brew bison (keg) not found — Apple's 2.3 is too old"
avail_gb=$(df -g "$WORK" | awk 'NR==2{print $4}')
[ "$avail_gb" -ge 15 ] || die "need ~15 GB free in $WORK (have ${avail_gb}G)"
# attribute by open files, not cmdline — a self-restarted steam.exe carries a Windows-style argv
for _p in $(pgrep -f "steam" 2>/dev/null); do
  lsof -p "$_p" 2>/dev/null | grep -q "$APP/Contents/SharedSupport/prefix" && \
    die "Steam (or a webhelper) is running in the wrapper — quit it first (steam.exe -shutdown; never kill -9)"
done
echo "  wrapper: $APP"
echo "  donor engine: $("$PK/bin/wine64" --version 2>/dev/null || cat "$PK/version" 2>/dev/null)"

# ---------------------------------------------------------------- 1. source + patch
step "wine $WINE_VER source"
SRC="$WORK/wine-$WINE_VER"
PATCHED="$WORK/wine-$WINE_VER-dxmt"
if [ ! -f "$PATCHED/dlls/winemac.drv/dxmt_objc.m" ]; then
  if [ ! -d "$SRC" ]; then
    TB="$WORK/wine-$WINE_VER.tar.xz"
    if [ ! -f "$TB" ]; then
      echo "  downloading from dl.winehq.org (~45 MB)…"
      curl -fL -o "$TB" "https://dl.winehq.org/wine/source/11.x/wine-$WINE_VER.tar.xz" || die "download failed"
    fi
    echo "$TARBALL_SHA  $TB" | shasum -a 256 -c - || die "tarball sha256 MISMATCH — refusing to build from it"
    tar -xJf "$TB" -C "$WORK" || die "unpack failed"
  fi
  cp -Rc "$SRC" "$PATCHED" 2>/dev/null || cp -R "$SRC" "$PATCHED"
  ( cd "$PATCHED" && patch -p1 < "$REPO/scripts/wineandaqua-dxmt.patch" ) || die "DXMT winemac patch did not apply — wine $WINE_VER expected"
fi
echo "  patched tree: $PATCHED"

# ---------------------------------------------------------------- 2. configure (gate G0)
step "configure (x86_64 + i386 PE)"
B="$WORK/wine-1116-build"
mkdir -p "$B" && cd "$B"
# Non-obvious, all measured 2026-08-23:
#  - FREETYPE_*/GNUTLS_* vars: brew's dylibs are arm64-only; link your wrapper's x86_64 ones
#  - ac_cv_lib_soname_*: the wrapper's dylibs have pathless install names; without these,
#    configure records garbage sonames and wine silently loses fonts + Steam TLS at runtime
#  - LDFLAGS -L: lets the MoltenVK soname check find the wrapper's x86_64 copy
PATH="/opt/homebrew/opt/bison/bin:$PATH" \
"$PATCHED/configure" \
  --prefix="$E" \
  --host=x86_64-apple-darwin --enable-archs=i386,x86_64 \
  --without-x --without-gstreamer --without-sdl --without-cups --without-dbus \
  --without-inotify --without-krb5 --without-netapi --without-opencl --without-pcap \
  --without-pcsclite --without-usb --without-v4l2 \
  CC="clang -arch x86_64" CXX="clang++ -arch x86_64" \
  LDFLAGS="-L$PKLIB" \
  FREETYPE_CFLAGS="-I/opt/homebrew/opt/freetype/include/freetype2" \
  FREETYPE_LIBS="-L$PKLIB -lfreetype" \
  GNUTLS_CFLAGS="-I/opt/homebrew/opt/gnutls/include" \
  GNUTLS_LIBS="-L$PKLIB -lgnutls" \
  ac_cv_lib_soname_freetype=libfreetype.dylib \
  ac_cv_lib_soname_gnutls=libgnutls.dylib > "$WORK/engine-configure.log" 2>&1 \
  || die "configure failed — see $WORK/engine-configure.log"
grep -q '#define SONAME_LIBFREETYPE "libfreetype.dylib"' include/config.h || die "G0: freetype soname wrong"
grep -q '#define SONAME_LIBGNUTLS "libgnutls.dylib"'     include/config.h || die "G0: gnutls soname wrong"
grep -qi "no schannel support" "$WORK/engine-configure.log" && die "G0: gnutls was silently skipped (broken Steam TLS)"
echo "  G0 clean: freetype + gnutls + winemac in the build"

# ---------------------------------------------------------------- 3. build + install
step "build (~45-60 min; get coffee)"
# DYLD var: the build-time font tool dlopens the pathless freetype name (measured failure without)
PATH="/opt/homebrew/opt/bison/bin:$PATH" DYLD_FALLBACK_LIBRARY_PATH="$PKLIB" \
  gmake -j"$(sysctl -n hw.ncpu)" install > "$WORK/engine-build.log" 2>&1 \
  || die "build failed — tail $WORK/engine-build.log"

# ---------------------------------------------------------------- 4. assemble + self-check
step "assemble the engine (DXMT + dylibs from your own wrapper)"
ln -sf wine "$E/bin/wine64"
cp "$PK/lib/wine/x86_64-unix/winemetal.so" "$E/lib/wine/x86_64-unix/"
for a in x86_64 i386; do for d in d3d11 dxgi winemetal; do
  cp "$PK/lib/wine/$a-windows/$d.dll" "$E/lib/wine/$a-windows/"
done; done
cp -R "$PKLIB"/*.dylib "$E/lib/"
cp -R "$PK/share/wine/gecko" "$PK/share/wine/mono" "$E/share/wine/" 2>/dev/null || true
printf 'wine stock %s + DXMT (self-built %s)\n' "$WINE_VER" "$(date +%F)" > "$E/version"
v="$("$E/bin/wine64" --version 2>/dev/null)"
[ "$v" = "wine-$WINE_VER" ] || die "self-check: engine reports '$v', expected wine-$WINE_VER"
dyld_info -exports "$E/lib/wine/x86_64-unix/winemac.so" 2>/dev/null | grep -q macdrv_functions \
  || die "self-check: DXMT shim not exported from winemac.so"
echo "  engine OK: $v, DXMT shim present"

# ---------------------------------------------------------------- 5. swap into the wrapper
step "install into the wrapper"
SS="$APP/Contents/SharedSupport"
if [ -d "$SS/wine.pk11.0-BAK" ]; then
  echo "  wine.pk11.0-BAK already exists — replacing the current engine, keeping that backup."
  rm -rf "$SS/wine.new-tmp"; mv "$SS/wine" "$SS/wine.new-tmp"
else
  mv "$SS/wine" "$SS/wine.pk11.0-BAK"
fi
cp -R "$E" "$SS/wine" || die "engine copy into the wrapper failed"
rm -rf "$SS/wine.new-tmp" 2>/dev/null

# ---------------------------------------------------------------- 6. controlled prefix update
step "one-time prefix update (dialogs disabled — this is the step that hangs if run implicitly)"
WINEPREFIX="$SS/prefix" DYLD_FALLBACK_LIBRARY_PATH="$SS/wine/lib" \
  WINEDLLOVERRIDES="mscoree=;mshtml=" WINEDEBUG=-all \
  "$SS/wine/bin/wine64" wineboot -u >/dev/null 2>&1
WINEPREFIX="$SS/prefix" "$SS/wine/bin/wineserver" -w

# ------------------------------------------- 7. storefront wrapper + Steam shortcut
# The 11.16 engine renders the game but Steam's visible storefront is BLACK on it (GOTCHAS,
# dxmt#141-class). make-steam-shortcut.sh keeps the storefront usable: it APFS-clones this
# wrapper, restores the 11.0 engine inside the clone from wine.pk11.0-BAK (instant, ~no disk,
# game install stripped from the clone), and builds a "CS2 Steam Store.app" that opens Steam
# there. Licences are account-level, so purchases cross over. Failure here is non-fatal —
# the game side is already complete.
step "storefront wrapper + Steam shortcut (play in 11.16, shop in 11.0)"
bash "$REPO/scripts/make-steam-shortcut.sh" --from "$APP" \
  || echo "  (storefront shortcut failed — run: bash scripts/make-steam-shortcut.sh)"

cat << DONE

=== done ===
Engine: $(cat "$SS/wine/version")
Play as usual (double-click the app, or the launcher). Exclusive Fullscreen is now safe —
the alt-tab freeze is fixed in this engine.

Steam's visible storefront is black on this engine (upstream, dxmt#141) — for buying DLC or
browsing, double-click "CS2 Steam Store.app" instead: it opens Steam in the preserved wine 11.0
wrapper. Licences are account-level, so purchases apply to both wrappers immediately. Opening
the store while the game runs steals the account's online session from the game's Steam — the
game keeps running (measured); the game's Steam simply reconnects on its next launch.

Optional verification (a 30-second windowed test, expect "VERDICT: LIVE"):
  bash "$REPO/scripts/run-minrepro3.sh"

Rollback (engine only, one command — your game/saves are untouched):
  mv "$SS/wine" "$SS/wine.1116" && mv "$SS/wine.pk11.0-BAK" "$SS/wine"
  (the prefix has then seen a newer wine once; in practice it keeps working, worst case
   delete + recreate the prefix = reinstall Steam inside the wrapper)
DONE
