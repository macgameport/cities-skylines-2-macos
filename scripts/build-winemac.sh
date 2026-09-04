#!/bin/bash
# build-winemac.sh — build a winemac.so for a Steam test, with the branch and glue asserted.
#
#   bash scripts/build-winemac.sh <out.so>                        # clean main
#   bash scripts/build-winemac.sh <out.so> /tmp/diag-patch.py     # main + a throwaway patch
#   bash scripts/build-winemac.sh <out.so> /tmp/diag-patch.py --e1
#
# ⚠ WHY THIS EXISTS. The nested winemac repo carries `core` (the stock-applicable subset, what goes
# upstream) and `main` (= aquadran + core + the DXMT glue commit, what actually runs here). A module
# built from `core` INSTALLS AND LOADS FINE. Steam then comes up, its GPU process dies with
# c0000409 six times, no remote layer is ever posted, and the window renders pure black -- at which
# point every band scores 100% and every diagnostic colour scores 0, which reads as a clean pass.
# Two full sessions were spent on 2026-09-03 attributing that to the diagnostic colours before the
# hashes were compared: `core` builds 502560 B, `main` builds 508544 B.
#
# Three assertions, because the failure is silent at every other layer:
#   1. the nested repo is on `main` and clean before the patch;
#   2. the patcher's own exit status is read DIRECTLY -- never through a pipe, which reports the
#      pipe's last command (the same trap as `<cmd> | tail` announcing a failed suite as exit 0;
#      a `python3 patch.py | sed` on this very script's first draft hid a "FAIL: 0 matches");
#   3. the built module carries `dxmt_client_surface` (5 hits on main/aquadran, 0 on core), so a
#      module missing the vendor layer is refused rather than measured.
# (macgameport, 2026-09-03)
set -u
OUT="${1:?usage: build-winemac.sh <out.so> [patcher [args...]]}"; shift || true
NR="$HOME/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv"
BLD="$HOME/cs2-patch/build-1116/wine-1116-vis-build"
SRC="$NR/cocoa_window.m"
SO="$BLD/dlls/winemac.drv/winemac.so"

br=$(git -C "$NR" rev-parse --abbrev-ref HEAD)
[ "$br" = main ] || { echo "REFUSED: nested repo is on '$br', not main -- a core build has no DXMT glue"; exit 2; }
[ -z "$(git -C "$NR" status --porcelain)" ] || { echo "REFUSED: nested tree is dirty before patching"; exit 2; }

restore() { git -C "$NR" checkout -- cocoa_window.m 2>/dev/null; }
trap restore EXIT

if [ $# -gt 0 ]; then
  patcher="$1"; shift
  python3 "$patcher" "$SRC" "$@" || { echo "REFUSED: patcher exited non-zero"; exit 3; }
fi

( cd "$BLD" && gmake dlls/winemac.drv/winemac.so ) > /tmp/build-winemac.out 2>&1 || {
  grep -E ' error' /tmp/build-winemac.out | head -5; echo "REFUSED: build failed"; exit 4; }
grep -qE ' error:' /tmp/build-winemac.out && { grep -E ' error:' /tmp/build-winemac.out | head -5
                                               echo "REFUSED: compiler errors"; exit 4; }

n=$(strings "$SO" | grep -c dxmt_client_surface)
[ "$n" -gt 0 ] || { echo "REFUSED: built module has no dxmt_client_surface -- this is a core build"; exit 5; }

cp "$SO" "$OUT" || exit 6
echo "built $(basename "$OUT")  $(shasum -a 256 "$OUT" | cut -c1-16)  ($(stat -f %z "$OUT") B)  glue-markers=$n"
