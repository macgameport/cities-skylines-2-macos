#!/bin/bash
# test-vendor.sh -- the two Python libraries shipped in patches/_vendor (dnfile, pefile): the folder is what
# its manifest says, git stores every byte unchanged, every script that imports dnfile finds it there under
# Apple's python3 and whatever python3 is first on PATH, from any working directory, through a symlink and
# from an install-folder layout, and running them leaves no bytecode behind. Also the two patch scripts that
# can tell a missing pattern from an applied patch: they must fail on a file that has neither.
# No game, no Wine, no network. Nothing is written outside a scratch folder.
#   bash scripts/test-vendor.sh            exit 0 = every case passed
#   MUTANT=1 ...   one byte of one vendored file changed (in a scratch copy); must exit 1
#   MUTANT=2 ...   one patcher no longer sets sys.dont_write_bytecode; must exit 1
#   MUTANT=3 ...   one patcher finds _vendor with abspath instead of realpath; must exit 1
#   MUTANT=4 ...   patch_longfile.py returns instead of failing when its pattern is missing; must exit 1
#   MUTANT=5 ...   the .gitattributes line for _vendor is moved to the top; must exit 1
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TOP="$(cd "$REPO/.." && pwd)"
T="$(mktemp -d /tmp/vendor-test.XXXX)"
trap 'rm -rf "$T"' EXIT
M="${MUTANT:-0}"
# the scripts under test are always a scratch copy, so that a mutant never touches the checkout
C="$T/c"; mkdir -p "$C"; cp -R "$REPO/patches" "$C/patches"; mkdir -p "$C/scripts"
cp "$REPO/scripts/patch-modconflict-badge.py" "$REPO/scripts/disasm.py" "$REPO/scripts/dump-binding-attrs.py" "$C/scripts/"
cp "$TOP/.gitattributes" "$T/gitattributes"
V="$C/patches/_vendor"
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
case "$M" in
  1) printf 'x' | dd of="$V/pefile.py" bs=1 seek=100 conv=notrunc 2>/dev/null ;;
  2) sed -i '' '/^sys.dont_write_bytecode = True/d' "$C/patches/patch_mkparent.py"; grep -q '^sys.dont_write_bytecode' "$C/patches/patch_mkparent.py" && mutated ;;
  3) sed -i '' 's/os.path.realpath(__file__)/os.path.abspath(__file__)/' "$C/patches/patch_lockleak.py"; grep -q 'abspath(__file__)' "$C/patches/patch_lockleak.py" || mutated ;;
  4) sed -i '' 's/^        sys.exit(1)  # neither the original bytes.*/        return/' "$C/patches/patch_longfile.py"; grep -q 'neither the original bytes' "$C/patches/patch_longfile.py" && mutated ;;
  5) { grep 'patches/_vendor' "$T/gitattributes"; grep -v 'patches/_vendor' "$T/gitattributes"; } > "$T/ga" && mv "$T/ga" "$T/gitattributes"
     [ "$(head -1 "$T/gitattributes" | grep -c '_vendor')" = 1 ] || mutated ;;
esac
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
PYS="/usr/bin/python3"; P2="$(command -v python3)"; [ "$P2" != /usr/bin/python3 ] && PYS="$PYS $P2"

# --- the folder is what the manifest says
check "the manifest verifies" "$(cd "$V" && shasum -a 256 -c MANIFEST.sha256 >/dev/null 2>&1; echo $?)" 0
check "the manifest lists every file but itself, the README and the two licences" \
  "$(cd "$V" && find . -type f ! -name MANIFEST.sha256 ! -name README.md ! -name 'LICENSE-*' ! -path '*/__pycache__/*' | sed 's#^\./##' | LC_ALL=C sort | tr '\n' ' ')" \
  "$(cd "$V" && awk '{print $2}' MANIFEST.sha256 | LC_ALL=C sort | tr '\n' ' ')"
check "both licence files are there" "$(ls "$V" | grep -c '^LICENSE-')" 2

# --- git stores every byte as it came: the rule must be the last line of .gitattributes to win
G="$T/g"; mkdir -p "$G/cities-skylines-2/patches/_vendor/ordlookup"; cp "$T/gitattributes" "$G/.gitattributes"
cp "$REPO/patches/_vendor/ordlookup/wsock32.py" "$G/cities-skylines-2/patches/_vendor/ordlookup/"
( cd "$G" && git init -q . && git add -A 2>/dev/null )
check "a file with CRLF endings is stored with them, and marked -text" "$(cd "$G" && git ls-files --eol cities-skylines-2/patches/_vendor/ordlookup/wsock32.py | awk '{print $1, $2, $3}')" "i/crlf w/crlf attr/-text"

# --- every script that imports dnfile gets it from _vendor
for py in $PYS; do
  v="$("$py" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
  check "python $v imports dnfile 0.18.0 from _vendor" \
    "$("$py" -I -B -c "import sys; sys.path.insert(0, '$V'); import dnfile; print(dnfile.__version__, dnfile.__file__.startswith('$V'))" 2>&1)" "0.18.0 True"
  L="$T/layout-$v"; mkdir -p "$L/other" "$L/install/patches"                       # an install-folder layout
  cp -R "$C/patches/." "$L/install/patches/"; cp "$C/scripts/patch-modconflict-badge.py" "$L/install/"
  ln -s "$C/patches/patch_lockleak.py" "$L/link-to-lockleak.py"                    # run through a symlink
  past=0; total=0
  for s in "$C/patches/patch_mkparent.py" "$C/patches/patch_lockbypass.py" "$C/patches/patch_longdelete.py" \
           "$C/patches/patch_createfile.py" "$C/patches/patch_lockleak.py" "$C/patches/dis_pdx.py" \
           "$C/scripts/disasm.py" "$C/scripts/dump-binding-attrs.py" "$C/scripts/patch-modconflict-badge.py" \
           "$L/install/patches/patch_mkparent.py" "$L/install/patch-modconflict-badge.py" "$L/link-to-lockleak.py"; do
    total=$((total + 1))
    out="$(cd "$L/other" && HOME="$T/nohome" "$py" -I -X pycache_prefix="$T/pyc-$v" "$s" "$T/no-such-target" 2>&1)"
    case "$out" in *"No module named"*|*ModuleNotFoundError*|*ImportError*) echo "      import failed: ${s#$T/}" ;; *) past=$((past + 1)) ;; esac
  done
  check "python $v: all $total runs get past the import (another directory, a symlink, an install layout)" "$past" "$total"
  check "python $v: no bytecode for the vendored files, anywhere" \
    "$(find "$T/pyc-$v" "$V" "$L/install/patches/_vendor" -name '*.pyc' 2>/dev/null | grep -c '_vendor')" 0
done
check "no __pycache__ in the checkout's own _vendor" "$(find "$REPO/patches/_vendor" -name __pycache__ | wc -l | tr -d ' ')" 0

# --- a file that holds neither the original bytes nor the patched ones is a failure, not "no changes needed"
R="$T/root"; mkdir -p "$R/Cities2_Data/Plugins/x86_64" "$R/Cities2_Data/Managed"
head -c 8192 /dev/zero > "$R/Cities2_Data/Plugins/x86_64/cohtml_unity3dplugin.dll"
head -c 8192 /dev/zero > "$R/Cities2_Data/Managed/Colossal.IO.dll"
out="$(/usr/bin/python3 -I "$C/patches/patch_cohtml.py" "$R" 2>&1)"; rc=$?
check "patch_cohtml.py on a file with neither form: warns and exits 1" "$rc:$(echo "$out" | grep -c 'WARNING: Pattern not found')" "1:1"
out="$(/usr/bin/python3 -I "$C/patches/patch_longfile.py" "$R" 2>&1)"; rc=$?
check "patch_longfile.py on a file with neither form: warns and exits 1" "$rc:$(echo "$out" | grep -c 'WARNING: GetFileHandle throw pattern not found')" "1:1"

echo "$fails failure(s)"
[ "$fails" = 0 ]
