#!/bin/bash
# build-dxmt-fork.sh — build notpop's DXMT fork (the _CreateMetalViewFromHWND rewrite).
#
# WHY: notpop/steam-on-m1-wine renders Steam's CEF on a near-stock Wine 11. Its two ingredients are
# (a) winemac.so rebuilt with -fvisibility=default — see scripts/build-winemac-visibility.sh, BUILT
# and measured INERT ALONE here 2026-08-29 — and (b) this fork, which is the active ingredient.
# The fork's own commit message is the best bug report on the subject that exists; see
# GOTCHAS § "There is a THIRD mechanism".
#
# ⚠ HARD PREREQUISITE — FULL XCODE. The build compiles Metal shaders with `xcrun -sdk macosx metal`,
# which ships with Xcode.app and is NOT in the Command Line Tools. Measured 2026-08-29 on CLT-only:
# the C++ side builds clean and **all 7 remaining failures are the missing `metal` utility**.
#   Install Xcode from the App Store, then:
#     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
#     xcodebuild -downloadComponent MetalToolchain      # only if `xcrun -f metal` still fails
# Neither is runnable unattended (App Store credentials / sudo).
#
# ⚠ DO NOT build LLVM from source. notpop's own script compiles llvmorg-15.0.7 (~1 h). Unnecessary:
# the fork's meson default `native_llvm_path` is ALREADY `/usr/local/opt/llvm@15`, which is the
# INTEL-Homebrew prefix — and airconv links LLVM as a macOS **x86_64** static lib, matching our
# x86_64 wine. Verified 2026-08-29: `arch -x86_64 /usr/local/bin/brew install llvm@15 zstd` drops a
# bottle at exactly that path with libLLVMCore.a present. Minutes, not an hour.
# (An arm64 /opt/homebrew llvm@15 is the WRONG ARCH for this.)
set -u
FORK="${DXMT_FORK_DIR:-$HOME/cs2-patch/dxmt-fork}"
WINE_INSTALL="${DXMT_WINE_INSTALL:-$HOME/cs2-patch/build-1116/engine-1116}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
die(){ echo "ERROR: $1"; exit 1; }
step(){ echo; echo "== $1"; }

step "gates"
xcrun -f metal >/dev/null 2>&1 || die "\`xcrun metal\` missing — install full Xcode (see header). CLT alone cannot build this."
[ -f /usr/local/opt/llvm@15/lib/libLLVMCore.a ] || die "x86_64 llvm@15 missing: arch -x86_64 /usr/local/bin/brew install llvm@15 zstd"
for t in meson ninja x86_64-w64-mingw32-gcc i686-w64-mingw32-gcc; do command -v "$t" >/dev/null || die "$t missing"; done
[ -f "$WINE_INSTALL/bin/winebuild" ] || die "no winebuild at $WINE_INSTALL — needs a wine 11.16 INSTALL (build-engine-1116.sh --prefix)"

step "source"
if [ ! -d "$FORK/.git" ]; then
  mkdir -p "$FORK"
  git clone --branch debug/present-path-tracing --depth 1 https://github.com/notpop/dxmt.git "$FORK" || die "clone failed"
  ( cd "$FORK" && git submodule update --init --recursive ) || die "submodules failed"
fi
# Portability fix found here 2026-08-29: com_guid.cpp uses std::setfill/std::setw without
# <iomanip>. Older GCC pulled it in transitively; our mingw-w64 does not. Worth reporting upstream.
if ! grep -q "include <iomanip>" "$FORK/src/util/com/com_guid.cpp"; then
  ( cd "$FORK" && patch -p1 < "$REPO/scripts/dxmt-fork-iomanip.patch" ) || die "iomanip patch failed"
  echo "  applied dxmt-fork-iomanip.patch"
fi
echo "  $FORK @ $(cd "$FORK" && git log --oneline -1)"

step "meson setup + compile (64-bit)"
cd "$FORK"
[ -d build ] || arch -arm64 meson setup --cross-file build-win64.txt \
  -Dnative_llvm_path=/usr/local/opt/llvm@15 -Dwine_install_path="$WINE_INSTALL" \
  build --buildtype release || die "meson setup (64) failed"
# ⚠ never pipe this to tail — meson/ninja failure then reports as exit 0 (cost us a wrong
# "build succeeded" reading on 2026-08-29). Capture, then read the real exit code.
arch -arm64 meson compile -C build > /tmp/dxmt-fork-build64.log 2>&1
rc=$?; grep -oE "^\[[0-9]+/[0-9]+\]" /tmp/dxmt-fork-build64.log | tail -1
[ $rc -eq 0 ] || { grep -E "^FAILED|error:" /tmp/dxmt-fork-build64.log | head -10; die "64-bit build failed (rc=$rc) — /tmp/dxmt-fork-build64.log"; }

step "meson setup + compile (32-bit)"
[ -d build32 ] || arch -arm64 meson setup --cross-file build-win32.txt \
  -Dwine_install_path="$WINE_INSTALL" build32 --buildtype release || die "meson setup (32) failed"
arch -arm64 meson compile -C build32 > /tmp/dxmt-fork-build32.log 2>&1
rc=$?; [ $rc -eq 0 ] || { grep -E "^FAILED|error:" /tmp/dxmt-fork-build32.log | head -10; die "32-bit build failed (rc=$rc)"; }

step "artifacts"
find "$FORK/build" "$FORK/build32" \( -name "d3d11.dll" -o -name "dxgi.dll" -o -name "d3d10core.dll" \
  -o -name "winemetal.dll" -o -name "winemetal.so" \) 2>/dev/null | while read -r f; do
  printf '  %-16s %9s B  %s\n' "$(basename "$f")" "$(stat -f%z "$f")" "$f"
done
echo
echo "  Install into a CLONE wrapper (never the daily one) that ALSO carries the"
echo "  -fvisibility=default winemac.so — the fork is useless without it."
