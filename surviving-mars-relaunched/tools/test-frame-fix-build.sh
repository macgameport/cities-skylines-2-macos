#!/bin/bash
# test-frame-fix-build.sh -- the committed tools/frame-fix.exe is the program its source builds
# (docs/plans/surviving-mars-install.md, 2.6, MT7). Everywhere: frame-fix.c and frame-fix.exe have the sha256
# values recorded in tools/frame-fix.build, the record's build line is the one in the source's header, and
# the program holds no path of the Mac that built it. Where the installed mingw-w64 is the recorded one, the
# header's build line is run in a scratch folder and must give the same bytes; elsewhere that part prints
# SKIP with the reason and is not called a pass.
#   bash tools/test-frame-fix-build.sh            exit 0 = every case that could run passed
#   MUTANT=1 ...   one byte of the program changed; must exit 1
#   MUTANT=2 ...   one byte of frame-fix.c changed; must exit 1
#   MUTANT=3 ...   -s dropped from the build line, the record following it; must exit 1 where the rebuild
#                  runs (elsewhere exit 0 with the SKIP line: nothing but the rebuild can see it)
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d /tmp/frame-fix-test.XXXX)"
trap 'rm -rf "$T"' EXIT
M="${MUTANT:-0}"
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
sha() { shasum -a 256 "$1" | awk '{ print $1 }'; }
rec() { sed -n "s/^$1: //p" "$R"; }
mkdir -p "$T/tools"
C="$T/tools/frame-fix.c"; X="$T/tools/frame-fix.exe"; R="$T/tools/frame-fix.build"
cp "$HERE/tools/frame-fix.c" "$C"; cp "$HERE/tools/frame-fix.exe" "$X"; cp "$HERE/tools/frame-fix.build" "$R"
case "$M" in
  0) ;;
  1) printf 'X' | dd of="$X" bs=1 seek=100 conv=notrunc 2> /dev/null ;;
  2) sed -i '' '1s/frame-fix.exe/frame-fix.EXE/' "$C" ;;
  3) sed -i '' 's/ -O2 -Wall -s -Wl,--no-insert-timestamp / -O2 -Wall -Wl,--no-insert-timestamp /' "$C" "$R"
     sed -i '' "s/^sha256 frame-fix.c: .*/sha256 frame-fix.c: $(sha "$C")/" "$R" ;;
  *) echo "REFUSED: no mutant $M"; exit 2 ;;
esac
if [ "$M" != 0 ]; then
  cmp -s "$HERE/tools/frame-fix.c" "$C" && cmp -s "$HERE/tools/frame-fix.exe" "$X" && { echo "REFUSED: mutant $M did not apply"; exit 2; }
fi

BL="$(sed -n 's/^ \* Build:  //p' "$C")"
check "frame-fix.c has the recorded sha256" "$(sha "$C")" "$(rec 'sha256 frame-fix.c')"
check "frame-fix.exe has the recorded sha256" "$(sha "$X")" "$(rec 'sha256 frame-fix.exe')"
check "  ...and the recorded size" "$(stat -f %z "$X")" "$(rec 'bytes frame-fix.exe')"
check "the record's build line is the one in the source's header" "$(rec build)" "$BL"
check "  ...and it is one line that builds tools/frame-fix.exe from tools/frame-fix.c" "$(printf '%s\n' "$BL" | grep -c '^x86_64-w64-mingw32-gcc .* -o tools/frame-fix.exe tools/frame-fix.c$')" 1
check "the program holds no path of the Mac that built it" "$(LC_ALL=C grep -a -c -E '/Users/|/private/tmp|/opt/homebrew' "$X")" 0
check "the runtime's licence text is beside it" "$(grep -c 'Zope Public License (ZPL) Version 2.1' "$HERE/tools/LICENSE-mingw-w64")" 1

HAVE="$(brew list --versions mingw-w64 2> /dev/null)"
if [ -n "$HAVE" ] && [ "$HAVE" = "$(rec package)" ] && command -v x86_64-w64-mingw32-gcc > /dev/null 2>&1; then
  mkdir -p "$T/rebuild/tools"; cp "$C" "$T/rebuild/tools/"
  (cd "$T/rebuild" && eval "$BL") > "$T/build.out" 2>&1; rc=$?
  check "the header's build line runs" "$rc" 0
  check "  ...and gives the committed program byte for byte" "$(cmp -s "$T/rebuild/tools/frame-fix.exe" "$X" && echo same || echo differs)" same
else
  echo "SKIP  the rebuild: this Mac has '${HAVE:-no mingw-w64}', the record names '$(rec package)'; only the sha256 values were checked"
fi

echo "$fails failure(s)"
[ "$fails" = 0 ]
