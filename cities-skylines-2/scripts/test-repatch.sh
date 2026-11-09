#!/bin/bash
# test-repatch.sh -- repatch.sh as a scratch copy beside a patches/ folder of stub patchers that record how
# they were run (name, target). No game, no Wine, no real patcher; HOME is a scratch folder too, so a default
# target can never be a real game folder.
#   bash scripts/test-repatch.sh            exit 0 = every case passed
#   MUTANT=1 bash scripts/test-repatch.sh   run() ignores a patch script's exit status; must exit 1
#   MUTANT=2 bash scripts/test-repatch.sh   one patch script is no longer run; must exit 1
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d /tmp/repatch-test.XXXX)"
trap 'rm -rf "$T"' EXIT
I="$T/inst"; mkdir -p "$I/patches" "$T/home"
cp "$REPO/repatch.sh" "$I/repatch.sh"
case "${MUTANT:-0}" in
  1) sed -i '' 's#^  if python3 "\$HERE/\$p" "\$@"; then #  if python3 "$HERE/$p" "$@" || true; then #' "$I/repatch.sh"
     grep -q '"\$@" || true; then ' "$I/repatch.sh" || { echo "REFUSED: mutant did not apply"; exit 2; } ;;
  2) sed -i '' '/^run patch_longdelete\.py /d' "$I/repatch.sh"
     grep -q '^run patch_longdelete\.py ' "$I/repatch.sh" && { echo "REFUSED: mutant did not apply"; exit 2; } ;;
esac

# a stub patcher: one line per run in $STUB_LOG (name, target); fails when STUB_FAIL lists it
STUB='import os, sys
name = os.path.basename(sys.argv[0])
with open(os.environ["STUB_LOG"], "a") as f:
    f.write("%s\t%s\n" % (name, sys.argv[1]))
sys.exit(1 if name in os.environ.get("STUB_FAIL", "").split() else 0)'
for f in "$REPO"/patches/patch_*.py; do echo "$STUB" > "$I/patches/$(basename "$f")"; done
ST="Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"
G="$T/A.app/$ST"; G2="$T/B.app/$ST"; mkdir -p "$G" "$G2"; : > "$G/Cities2.exe"; : > "$G2/Cities2.exe"
SENTENCE='^The Wine 10 + D3DMetal stack was retired on 2026-11-09\. Its last version is commit [0-9a-f]\{7,40\}\.$'
TEN="cohtml colossal_io longfile asset_database fshandle mkparent lockbypass longdelete createfile lockleak "
SIXTEEN="cohtml colossal_io longfile asset_database dirdel dirhandle delfile delrec dirrec_nx delchild fshandle mkparent lockbypass longdelete createfile lockleak "

fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
run() {    # [VAR=value ...] bash <repatch.sh> [args]: fresh log, output in $T/out; echoes the exit code
  : > "$T/log"
  ( cd "$T" && env -u CS2_GAME_DIR -u CS2_ERRNO_PATCHES -u STUB_FAIL HOME="$T/home" STUB_LOG="$T/log" "$@" > "$T/out" 2>&1 ); echo $?
}
names() { cut -f1 "$T/log" | sed 's/^patch_//; s/\.py$//' | tr '\n' ' '; }
said()  { grep -c -- "$1" "$T/out"; }

# --- the default set: ten, in order
check "all succeed: exit 0" "$(run CS2_GAME_DIR="$G" bash "$I/repatch.sh" dxmt11)" 0
check "  ...ten, in the order that keeps Colossal.IO.dll's backup pristine" "$(names)" "$TEN"
check "  ...it says 10 of 10" "$(said '^10 of 10 patch scripts finished without error$')" 1
check "  ...and names no failure" "$(said '^FAILED')" 0
check "  ...targets: the game folder x4, mscorlib.dll, PDX.SDK.dll x5" "$(cut -f2 "$T/log" | sed 's|.*/||' | uniq -c | awk '{printf "%s:%s ", $1, $NF}')" "4:II 1:mscorlib.dll 5:PDX.SDK.dll "
check "CS2_ERRNO_PATCHES=1: exit 0" "$(run CS2_GAME_DIR="$G" CS2_ERRNO_PATCHES=1 bash "$I/repatch.sh" dxmt11)" 0
check "  ...sixteen, the six errno ones after the first four" "$(names)" "$SIXTEEN"
check "  ...it says 16 of 16" "$(said '^16 of 16 patch scripts finished without error$')" 1

# --- a failure is named, and does not stop the others
check "patch_mkparent fails: exit 1" "$(run CS2_GAME_DIR="$G" STUB_FAIL=patch_mkparent.py bash "$I/repatch.sh" dxmt11)" 1
check "  ...the other nine still ran, in order" "$(names)" "$TEN"
check "  ...it says 9 of 10 and names the one" "$(said '^9 of 10 patch scripts finished without error$'):$(said '^FAILED: patch_mkparent.py$')" "1:1"
check "two fail: exit 1" "$(run CS2_GAME_DIR="$G" STUB_FAIL="patch_cohtml.py patch_lockleak.py" bash "$I/repatch.sh" dxmt11)" 1
check "  ...8 of 10, both named, in the order they ran" "$(said '^8 of 10 patch scripts finished without error$'):$(said '^FAILED: patch_cohtml.py patch_lockleak.py$')" "1:1"

# --- no game there: nothing is run
check "no Cities2.exe under the target: exit 1" "$(run CS2_GAME_DIR="$T/nowhere" bash "$I/repatch.sh" dxmt11)" 1
check "  ...it says so, and no patch script ran" "$(said '^ERROR: no Cities2.exe under: '):$(wc -l < "$T/log" | tr -d ' ')" "1:0"

# --- targets: one stack. The retired names say so and run nothing; a folder is that folder, with the ten
for w in free FREE d3dmetal wine10; do
  check "$w: exit 2, the retirement sentence, no patch script run" "$(run CS2_GAME_DIR="$G" bash "$I/repatch.sh" $w):$(said "$SENTENCE"):$(wc -l < "$T/log" | tr -d ' ')" "2:1:0"
done
check "a folder as the argument: exit 0" "$(run bash "$I/repatch.sh" "$G2")" 0
check "  ...ten, all in that folder, and a line about the errno six" "$(names)/$(cut -f2 "$T/log" | grep -c "^$T/B.app/")/$(said 'needs CS2_ERRNO_PATCHES=1')" "$TEN/10/1"
check "  ...and CS2_ERRNO_PATCHES=1 makes it sixteen there" "$(run CS2_ERRNO_PATCHES=1 bash "$I/repatch.sh" "$G2"):$(names)" "0:$SIXTEEN"
check "no argument, CS2_GAME_DIR set: ten, in that folder" "$(run CS2_GAME_DIR="$G" bash "$I/repatch.sh"):$(names)/$(cut -f2 "$T/log" | grep -c "^$T/A.app/")" "0:$TEN/10"
check "no argument and no wrapper: exit 1, naming the default wrapper's game folder" "$(run bash "$I/repatch.sh"):$(said "^ERROR: no Cities2.exe under: $T/home/Applications/CS2dxmt11.app/"):$(wc -l < "$T/log" | tr -d ' ')" "1:1:0"

echo "$fails failure(s)"
[ "$fails" = 0 ]
