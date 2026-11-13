#!/bin/bash
# test-fetch-d3dmetal.sh -- tools/fetch-d3dmetal.sh on small archives this test makes
# (docs/plans/surviving-mars-install.md, MT4). A copy of the script and of common/fetch.sh run in a scratch
# tree with the copy's pins rewritten for each archive; curl and codesign are recording stubs, HOME is a
# scratch folder, and nothing is fetched. The archives are plain tar files with the pinned file's name
# (tar reads either), written with Python's tarfile so that one can hold an absolute name and one a name
# with a .. part, which macOS's tar will not write.
# Two parts run the real codesign: a look-alike framework this test builds and signs itself, with Apple's
# identifier and version 3.0, must be refused; and where Apple's own pieces are on this Mac (CX_GPTK, or an
# installed SurvivingMars.app that reads 3) the script must pass on an archive made from them. Where either
# cannot be run the test prints SKIP with the reason, and does not call it a pass.
#   bash tools/test-fetch-d3dmetal.sh            exit 0 = every case passed
#   MUTANT=<n> bash tools/test-fetch-d3dmetal.sh   each must exit 1; 2 = the mutant did not apply
#     1 the archive's sha256 test removed (common/fetch.sh)   2 the version test removed
#     3 -R dropped from the framework's codesign line          4 that check pointed at Versions/A
#     5 the fixed list removed                                 6 d3d12.dll's sha256 test removed
#     7 the test for an absolute name or a .. part removed     8 the whole archive unpacked
#     9 the cleanup armed before the folder is made
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
T="$(mktemp -d /tmp/fetch-d3dmetal-test.XXXX)"
trap 'rm -rf "$T"' EXIT
M="${MUTANT:-0}"
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

mkdir -p "$T/repo/common" "$T/repo/surviving-mars-relaunched/tools" "$T/home" "$T/bin" "$T/bin-real" "$T/a" "$T/dl"
S="$T/repo/surviving-mars-relaunched/tools/fetch-d3dmetal.sh"; FS="$T/repo/common/fetch.sh"
cp "$HERE/tools/fetch-d3dmetal.sh" "$S"; cp "$REPO/common/fetch.sh" "$FS"
case "$M" in
  0) ;;
  1) sed -i '' 's/ || \[ "\$got" != "\$want" \]; then$/; then/' "$FS" ;;
  2) sed -i '' '/^\[ "\$V" = 3\.0 \] || die /d' "$S" ;;
  3) sed -i '' "s/ -R '=identifier \"com.apple.D3DMetal\" and anchor apple'//" "$S" ;;
  4) sed -i '' 's|and anchor apple'"'"' "\$F" > /dev/null|and anchor apple'"'"' "$F/Versions/A" > /dev/null|' "$S" ;;
  5) sed -i '' '/^\[ "\$GOT" = /d' "$S" ;;
  6) sed -i '' '/"\$SHA_D3D12" \] || die /d' "$S" ;;
  7) sed -i '' '/^if grep -Eq .*absolute or has a \.\. part/d' "$S" ;;
  8) sed -i '' '/^  "\$TOP\/external" /d; s|^  "\$TOP/wine/x86_64-windows/d3d12.dll" "\$TOP/wine/x86_64-windows/dxgi.dll" > |  > |' "$S" ;;
  9) python3 - "$S" << 'PY'
import sys
p = sys.argv[1]; s = open(p).read()
t = """trap 'rm -rf "$INTO"' EXIT\n"""
assert s.count(t) == 1
s = s.replace(t, "")
k = 'case "$INTO" in /*) ;; *) die "the folder must be an absolute path'
assert s.count(k) == 1
open(p, "w").write(s.replace(k, t + k))
PY
     ;;
  *) echo "REFUSED: no mutant $M"; exit 2 ;;
esac
if [ "$M" != 0 ]; then
  cmp -s "$HERE/tools/fetch-d3dmetal.sh" "$S" && cmp -s "$REPO/common/fetch.sh" "$FS" && { echo "REFUSED: mutant $M did not apply"; exit 2; }
  bash -n "$S" && bash -n "$FS" || { echo "REFUSED: mutant $M does not parse"; exit 2; }
fi

NAME="game-porting-toolkit-3.0-3.tar.xz"
TOP="Game Porting Toolkit.app/Contents/Resources/wine/lib"
cat > "$T/mk.py" << 'PY'
# mk.py <out> <variant> <marker> [<real lib folder>]: one small archive in the shape of Gcenx's
import io, os, sys, tarfile
out, variant, marker = sys.argv[1:4]
APP = "Game Porting Toolkit.app"
TOP = APP + "/Contents/Resources/wine/lib"
FW = TOP + "/external/D3DMetal.framework"
def plist(v):
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>'
            '<key>CFBundleIdentifier</key><string>com.apple.D3DMetal</string>'
            '<key>CFBundleShortVersionString</key><string>%s</string></dict></plist>\n' % v).encode()
files = {
    APP + "/Contents/MacOS/run": b"#!/bin/sh\ntouch '%s'\n" % marker.encode(),
    TOP + "/wine/x86_64-windows/other.dll": b"not one of the four\n",
    FW + "/Versions/A/D3DMetal": b"framework binary\n",
    FW + "/Versions/A/Resources/Info.plist": plist("2.1" if variant == "v21" else "3.0"),
    FW + "/Versions/A/Resources/LICENSE": b"licence\n",
    FW + "/Versions/A/Resources/default.metallib": b"metallib\n",
    FW + "/Versions/A/Resources/libdxccontainer.dylib": b"1\n",
    FW + "/Versions/A/Resources/libdxcompiler.dylib": b"2\n",
    FW + "/Versions/A/Resources/libdxilconv.dylib": b"3\n",
    FW + "/Versions/A/Resources/libmetalirconverter.dylib": b"4\n",
    FW + "/Versions/A/Resources/version.plist": b"version\n",
    FW + "/Versions/A/_CodeSignature/CodeResources": b"seal\n",
    TOP + "/external/libd3dshared.dylib": b"shared library\n",
    TOP + "/wine/x86_64-windows/atidxx64.dll": b"dll atidxx64\n",
    TOP + "/wine/x86_64-windows/d3d11.dll": b"dll d3d11\n",
    TOP + "/wine/x86_64-windows/d3d12.dll": b"dll d3d12\n",
    TOP + "/wine/x86_64-windows/dxgi.dll": b"dll dxgi\n",
}
links = {
    FW + "/D3DMetal": "Versions/Current/D3DMetal",
    FW + "/Resources": "Versions/Current/Resources",
    FW + "/Versions/Current": "A",
    # a link with .. in its target, outside the pieces: the real archive has 29 of these, and it is accepted
    TOP + "/wine/x86_64-unix/d3d12.so": "../../external/libd3dshared.dylib",
}
if variant == "flipped": files[APP + "/Contents/MacOS/run"] = b"#!/bin/sh\ntouch '%s'\n" % marker.encode().replace(b"m", b"n", 1)
if variant == "nodll": del files[TOP + "/wine/x86_64-windows/d3d11.dll"]
if variant == "nofile": del files[FW + "/Versions/A/Resources/LICENSE"]
if variant == "extra": files[TOP + "/external/extra.txt"] = b"one file more\n"
if variant == "extrafw": files[FW + "/Versions/B/D3DMetal"] = b"a second version\n"
if variant == "badlink": links[FW + "/Versions/Current"] = "B"
if variant == "baddll": files[TOP + "/wine/x86_64-windows/d3d12.dll"] = b"dll d3d12, another build\n"
if variant == "absname": files["/tmp/fetch-d3dmetal-test-absolute"] = b"absolute\n"
if variant == "dotdot": files[APP + "/../fetch-d3dmetal-test-dotdot"] = b"climbs out\n"
with tarfile.open(out, "w") as tf:
    if variant == "real":   # Apple's own pieces from a folder on this Mac, under the archive's names
        lib = sys.argv[4]
        for f in ("wine/x86_64-windows/atidxx64.dll", "wine/x86_64-windows/d3d11.dll",
                  "wine/x86_64-windows/d3d12.dll", "wine/x86_64-windows/dxgi.dll", "external/libd3dshared.dylib"):
            tf.add(os.path.join(lib, f), TOP + "/" + f)
        tf.add(os.path.join(lib, "external/D3DMetal.framework"), FW)
    elif variant == "lookalike":   # a framework signed by this test, with Apple's identifier
        tf.add(sys.argv[4], FW)
        for n, d in files.items():
            if not n.startswith(FW):
                ti = tarfile.TarInfo(n); ti.size = len(d); ti.mode = 0o644; tf.addfile(ti, io.BytesIO(d))
    else:
        for n, d in files.items():
            ti = tarfile.TarInfo(n); ti.size = len(d); ti.mode = 0o755 if n.endswith("/run") else 0o644
            tf.addfile(ti, io.BytesIO(d))
        for n, t in links.items():
            ti = tarfile.TarInfo(n); ti.type = tarfile.SYMTYPE; ti.linkname = t; tf.addfile(ti)
PY
sha() { shasum -a 256 "$1" | awk '{ print $1 }'; }
pin() { sed -i '' "s#^$1=.*#$1=$2#" "$S"; }
mk() {   # <variant> [<folder for a real or look-alike archive>]: the archive at $T/a/<variant>/<the pinned name>
  mkdir -p "$T/a/$1"
  python3 -I "$T/mk.py" "$T/a/$1/$NAME" "$1" "$T/marker" ${2:+"$2"} || { echo "REFUSED: the archive '$1' could not be made"; exit 2; }
}
pins() {   # <variant>: the copy's archive pin becomes that archive's
  pin BYTES "$(stat -f %z "$T/a/$1/$NAME")"; pin SHA "$(sha "$T/a/$1/$NAME")"
}
printf '#!/bin/sh\necho "curl $*" >> "%s/calls"\nwhile [ $# -gt 0 ]; do [ "$1" = -o ] && out="$2"; shift; done\n[ -n "${CURL_FILE:-}" ] && cp "$CURL_FILE" "$out"\nexit "${CURL_RC:-0}"\n' "$T" > "$T/bin/curl"
printf '#!/bin/sh\necho "codesign $*" >> "%s/calls"\nexit "${CODESIGN_RC:-0}"\n' "$T" > "$T/bin/codesign"
chmod +x "$T/bin/curl" "$T/bin/codesign"; cp "$T/bin/curl" "$T/bin-real/curl"
run() {   # <stubs: bin|bin-real> <L1_DOWNLOADS or ""> <args...>: the script's exit code; its output in $T/out
  local b="$1" dl="$2"; shift 2
  : > "$T/calls"
  (cd "$T" && PATH="$T/$b:$PATH" HOME="$T/home" L1_DOWNLOADS="$dl" /bin/bash "$S" "$@") > "$T/out" 2>&1
  echo $?
}
calls() { grep -c "^$1 " "$T/calls"; }
gone() { [ -e "$1" ] || [ -L "$1" ] && echo left || echo gone; }

# --- the pins of the good archive, and of its four DLLs
mk good; pins good
pin SHA_ATIDXX64 "$(printf 'dll atidxx64\n' | shasum -a 256 | awk '{ print $1 }')"
pin SHA_D3D11 "$(printf 'dll d3d11\n' | shasum -a 256 | awk '{ print $1 }')"
pin SHA_D3D12 "$(printf 'dll d3d12\n' | shasum -a 256 | awk '{ print $1 }')"
pin SHA_DXGI "$(printf 'dll dxgi\n' | shasum -a 256 | awk '{ print $1 }')"

# --- the good archive, from a folder of downloads
I="$T/into"
rc=$(run bin "$T/a/good" --into "$I")
check "the good archive from L1_DOWNLOADS: exit 0, and the last line is the folder" "$rc:$(tail -n 1 "$T/out")" "0:$I/lib"
check "  ...the folder holds lib and nothing else" "$(ls -A "$I" 2>/dev/null | tr '\n' ' ')" "lib "
check "  ...15 files and 3 links" "$(cd "$I/lib" 2>/dev/null && find . -type f | wc -l | tr -d ' '):$(cd "$I/lib" 2>/dev/null && find . -type l | wc -l | tr -d ' ')" "15:3"
check "  ...the matching copy was used: curl was not called" "$(calls curl)" 0
check "  ...nothing from the archive was run, and what is not a piece never touched the disk" "$(gone "$T/marker"):$(find "$T/into" -name other.dll -o -name run -o -name d3d12.so | wc -l | tr -d ' ')" "gone:0"
check "  ...codesign was asked twice" "$(calls codesign)" 2
check "  ...the framework: --verify --strict, Apple's requirement, at the framework's root" "$(sed -n '1p' "$T/calls")" "codesign --verify --strict -R =identifier \"com.apple.D3DMetal\" and anchor apple $I/.work/x/$TOP/external/D3DMetal.framework"
check "  ...the library: the same, with its own identifier" "$(sed -n '2p' "$T/calls")" "codesign --verify --strict -R =identifier \"com.apple.libd3dshared\" and anchor apple $I/.work/x/$TOP/external/libd3dshared.dylib"
rm -rf "$I"

# --- each of these stops it with nothing left
bad() {   # <variant> <the words it must stop with> <name>
  mk "$1"; pins "$1"
  rc=$(run bin "$T/a/$1" --into "$I")
  check "$3: exit 1, its own words, nothing left" "$rc:$(grep -c -- "$2" "$T/out"):$(gone "$I")" "1:1:gone"
  rm -rf "$I"
}
bad nodll "could not be taken out of the archive" "a DLL missing"
bad nofile "is not the 15 files and 3 links" "a file of the framework missing"
bad extra "is not the 15 files and 3 links" "an extra file among the pieces"
bad extrafw "is not the 15 files and 3 links" "a second version added inside the framework"
bad badlink "is not the 15 files and 3 links" "a link among the pieces with another target"
bad v21 "reads version 2.1, not 3.0" "a framework that reads 2.1"
bad baddll "d3d12.dll is not the file this was tested with" "a DLL with another sha256"
bad absname "absolute or has a .. part" "an absolute name outside the pieces"
check "  ...and it was not written" "$(gone /tmp/fetch-d3dmetal-test-absolute)" gone
bad dotdot "absolute or has a .. part" "a name with a .. part outside the pieces"
pins good
rc=$(CODESIGN_RC=1 run bin "$T/a/good" --into "$I")
check "codesign saying no stops it" "$rc:$(grep -c 'is not signed by Apple as com.apple.D3DMetal' "$T/out"):$(gone "$I")" "1:1:gone"

# --- the download: a wrong sha256 at the right size, a wrong size, a copy that does not match, curl's 22
mk flipped
[ "$(stat -f %z "$T/a/flipped/$NAME")" = "$(stat -f %z "$T/a/good/$NAME")" ] || { echo "REFUSED: the flipped archive is not the good one's size"; exit 2; }
rc=$(CURL_FILE="$T/a/flipped/$NAME" run bin "" --into "$I")
check "a download with a wrong sha256 at the right size stops it" "$rc:$(grep -c "$NAME is not the file this was tested with" "$T/out"):$(calls curl):$(gone "$I")" "1:1:1:gone"
{ cat "$T/a/good/$NAME"; printf 'x'; } > "$T/longer"
rc=$(CURL_FILE="$T/longer" run bin "" --into "$I")
check "a download of a wrong size stops it" "$rc:$(grep -c "$NAME is not the file this was tested with" "$T/out"):$(gone "$I")" "1:1:gone"
rc=$(CURL_FILE="$T/a/good/$NAME" run bin "$T/a/flipped" --into "$I")
check "a copy in L1_DOWNLOADS that does not match is not used: it is downloaded instead" "$rc:$(grep -c 'downloading it instead' "$T/out"):$(calls curl)" "0:1:1"
rm -rf "$I"
rc=$(CURL_RC=22 run bin "" --into "$I")
check "curl's 22 gives the no-longer-published words" "$rc:$(grep -c "$NAME is no longer published at https://github.com/Gcenx/" "$T/out"):$(gone "$I")" "1:1:gone"
rc=$(CURL_RC=7 run bin "" --into "$I")
check "another curl failure says the download failed" "$rc:$(grep -c "the download of $NAME failed (curl exit 7)" "$T/out"):$(gone "$I")" "1:1:gone"

# --- the folder, and the exit codes
mkdir "$I"; touch "$I/keep"
rc=$(run bin "$T/a/good" --into "$I")
check "a folder that exists is refused and keeps its files" "$rc:$(grep -c 'is already there' "$T/out"):$(gone "$I/keep"):$(ls -A "$I" | tr '\n' ' ')" "1:1:left:keep "
rm -rf "$I"
check "a relative folder is refused with exit 1" "$(run bin "$T/a/good" --into relative/folder):$(gone "$T/relative")" "1:gone"
check "a folder whose parent is not there is refused with exit 1" "$(run bin "$T/a/good" --into "$T/absent/into"):$(gone "$T/absent")" "1:gone"
check "no option is exit 2" "$(run bin "")" 2
check "an unknown option is exit 2" "$(run bin "" --here "$I")" 2
check "--into with no folder is exit 2" "$(run bin "" --into)" 2
mkdir -p "$T/rootbin"; printf '#!/bin/sh\n[ "$1" = -u ] && { echo 0; exit 0; }\nexec /usr/bin/id "$@"\n' > "$T/rootbin/id"; chmod +x "$T/rootbin/id"
: > "$T/calls"; (cd "$T" && PATH="$T/rootbin:$T/bin:$PATH" HOME="$T/home" L1_DOWNLOADS="$T/a/good" /bin/bash "$S" --into "$I") > "$T/out" 2>&1; rc=$?
check "root is refused, and nothing is made" "$rc:$(grep -c 'as root' "$T/out"):$(gone "$I")" "1:1:gone"

# --- the real codesign, on a look-alike this test signs itself
LA="$T/lookalike/D3DMetal.framework"
mkdir -p "$LA/Versions/A/Resources"
cp /usr/bin/true "$LA/Versions/A/D3DMetal"
python3 -I - "$LA" << 'PY'
import os, sys
fw = sys.argv[1]; r = fw + "/Versions/A/Resources"
open(r + "/Info.plist", "w").write('<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>'
    '<key>CFBundleIdentifier</key><string>com.apple.D3DMetal</string><key>CFBundleExecutable</key><string>D3DMetal</string>'
    '<key>CFBundlePackageType</key><string>FMWK</string><key>CFBundleShortVersionString</key><string>3.0</string></dict></plist>\n')
for n in ("LICENSE", "default.metallib", "libdxccontainer.dylib", "libdxcompiler.dylib", "libdxilconv.dylib",
          "libmetalirconverter.dylib", "version.plist"):
    open(r + "/" + n, "w").write(n + "\n")
os.symlink("A", fw + "/Versions/Current")
os.symlink("Versions/Current/D3DMetal", fw + "/D3DMetal")
os.symlink("Versions/Current/Resources", fw + "/Resources")
PY
if /usr/bin/codesign --force -s - -i com.apple.D3DMetal "$LA" > "$T/sign.out" 2>&1 && /usr/bin/codesign --verify --strict "$LA" > /dev/null 2>&1 \
   && [ "$(cd "$LA" && find . -type f | wc -l | tr -d ' ')" = 10 ]; then
  mk lookalike "$LA"; pins lookalike
  rc=$(run bin-real "$T/a/lookalike" --into "$I")
  check "a look-alike with Apple's identifier and version 3.0, validly signed by someone else, is refused" "$rc:$(grep -c 'D3DMetal.framework is not signed by Apple as com.apple.D3DMetal' "$T/out"):$(gone "$I")" "1:1:gone"
else
  echo "SKIP  the look-alike could not be signed on this Mac ($(tail -n 1 "$T/sign.out" 2>/dev/null)); the refusal of a framework not signed by Apple was not tested"
fi

# --- the real codesign, on Apple's own pieces where this Mac has them
REAL="${CX_GPTK:-$HOME/Applications/SurvivingMars.app/Contents/SharedSupport/wine/lib}"
case "$(plutil -extract CFBundleShortVersionString raw "$REAL/external/D3DMetal.framework/Versions/A/Resources/Info.plist" 2>/dev/null)" in
  3.*)
    mk real "$REAL"; pins real
    for d in ATIDXX64:atidxx64 D3D11:d3d11 D3D12:d3d12 DXGI:dxgi; do pin "SHA_${d%%:*}" "$(sha "$REAL/wine/x86_64-windows/${d##*:}.dll")"; done
    rc=$(run bin-real "$T/a/real" --into "$I")
    check "Apple's own framework and library from this Mac pass the script's two signature checks" "$rc:$(tail -n 1 "$T/out")" "0:$I/lib"
    check "  ...and what is left equals the source, the signature included" "$(diff -rq "$REAL/external" "$I/lib/external" > /dev/null 2>&1; echo $?)" 0
    rm -rf "$I" ;;
  *) echo "SKIP  no D3DMetal 3 pieces on this Mac (CX_GPTK, or an installed SurvivingMars.app): the script's signature checks were not run on Apple's own files" ;;
esac

echo "$fails failure(s)"
[ "$fails" = 0 ]
