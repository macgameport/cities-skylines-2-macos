#!/bin/bash
# fetch-d3dmetal.sh -- fetch the pinned archive that holds Apple's D3DMetal 3.0 from Gcenx's release page,
# take the six pieces make-engine.sh needs out of it, and check them (docs/plans/surviving-mars-install.md,
# 2.3). This project passes on nothing of Apple's: the file comes from its publisher to the player's Mac.
#
#   bash tools/fetch-d3dmetal.sh --into <folder>
#
# <folder> must be an absolute path that does not exist, in a folder that does. On success it holds lib/ and
# nothing else: lib/external/ (D3DMetal.framework, libd3dshared.dylib) and lib/wine/x86_64-windows/ (four
# DLLs). <folder>/lib is the value make-engine.sh takes as CX_GPTK, and the last line printed.
#   exit 0 = the pieces are there; 1 = refused or failed, said why, and <folder> is not left behind (one that
#   was already there is left as it was); 2 = a wrong option.
# Nothing from the archive is run, and only the pieces are taken out of it. L1_DOWNLOADS=<folder> names a
# folder of files already downloaded: a copy is used only if its size and sha256 match.
#
# What rests on what. The pin (size and sha256) fixes every byte of the archive. The signature shows more
# than the pin can: that the framework and the library are Apple's own builds, whoever published the
# archive. It does not cover the four DLLs, which are unsigned and rest on their sha256, and it does not
# notice an added file, which is what the fixed list is for.
set -u
URL="https://github.com/Gcenx/game-porting-toolkit/releases/download/Game-Porting-Toolkit-3.0-3/game-porting-toolkit-3.0-3.tar.xz"
BYTES=239200808
SHA=d377683937340f914823dbb2e1252b329cbf834ff58907d0293db8cebf0e392e
SHA_ATIDXX64=bd004dd9e41415b0e1395d51a2ded762a02c7731491e74ed6076f3648ae9ea7f
SHA_D3D11=05fa6f700fb5ee5561dc3a46d98f0aed845d4fa8ab274bff1dc604b0b3f6edd1
SHA_D3D12=27dcf69bedb20ed557a83953e356ab2477b688c2a2c631f880b7583f30ff0705
SHA_DXGI=249711d3d786a9b0bb7c3558f36e472ab07ee21b8dbf118e34c975046832f9a2
TOP="Game Porting Toolkit.app/Contents/Resources/wine/lib"
# what must come out, and nothing else: 15 files and 3 links
WANT="f external/D3DMetal.framework/Versions/A/D3DMetal
f external/D3DMetal.framework/Versions/A/Resources/Info.plist
f external/D3DMetal.framework/Versions/A/Resources/LICENSE
f external/D3DMetal.framework/Versions/A/Resources/default.metallib
f external/D3DMetal.framework/Versions/A/Resources/libdxccontainer.dylib
f external/D3DMetal.framework/Versions/A/Resources/libdxcompiler.dylib
f external/D3DMetal.framework/Versions/A/Resources/libdxilconv.dylib
f external/D3DMetal.framework/Versions/A/Resources/libmetalirconverter.dylib
f external/D3DMetal.framework/Versions/A/Resources/version.plist
f external/D3DMetal.framework/Versions/A/_CodeSignature/CodeResources
f external/libd3dshared.dylib
f wine/x86_64-windows/atidxx64.dll
f wine/x86_64-windows/d3d11.dll
f wine/x86_64-windows/d3d12.dll
f wine/x86_64-windows/dxgi.dll
l external/D3DMetal.framework/D3DMetal -> Versions/Current/D3DMetal
l external/D3DMetal.framework/Resources -> Versions/Current/Resources
l external/D3DMetal.framework/Versions/Current -> A"

tilde() { case "$1" in "$HOME") printf '~' ;; "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }
say() { echo "  $*"; }
die() { echo "  !! $*"; exit 1; }

INTO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --into) if [ $# -lt 2 ] || [ -z "$2" ]; then echo "--into needs a folder (try --help)"; exit 2; fi
            INTO="$2"; shift 2 ;;
    -h|--help) sed -n '2,/^set -u$/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)"; exit 2 ;;
  esac
done
[ -n "$INTO" ] || { echo "--into <folder> is needed (try --help)"; exit 2; }
[ "$(id -u)" = 0 ] && die "Do not run this as root (with sudo): it would leave files only root can change in your home folder."

# 1. the folder: absolute, absent, in a folder that exists. It is made here, and only then is the cleanup armed
case "$INTO" in /*) ;; *) die "the folder must be an absolute path: $INTO" ;; esac
INTO="${INTO%/}"
{ [ -e "$INTO" ] || [ -L "$INTO" ]; } && die "$(tilde "$INTO") is already there; this never writes into a folder that exists"
[ -d "$(dirname "$INTO")" ] || die "the folder $(tilde "$(dirname "$INTO")") does not exist"
mkdir "$INTO" || die "$(tilde "$INTO") could not be made"
trap 'rm -rf "$INTO"' EXIT
WORK="$INTO/.work"
mkdir "$WORK" "$WORK/x" || die "a work folder could not be made in $(tilde "$INTO")"

# 2. the archive, against its pin
. "$(cd "$(dirname "$0")/../../common" && pwd)/fetch.sh"
A="$WORK/$(basename "$URL")"
fetch "$URL" "$BYTES" "$SHA" "$A"

# 3. its listing, before anything is taken out: no absolute name, no name with a .. part
say "reading the archive's list"
tar -tf "$A" > "$WORK/list" 2> "$WORK/list.err" || die "the archive's list could not be read"
if grep -Eq '^/|(^|/)\.\.(/|$)' "$WORK/list"; then die "the archive holds a name that is absolute or has a .. part; nothing was taken out of it"; fi

# 4. only the pieces come out; nothing from the archive is run
say "taking Apple's D3DMetal 3.0 out of it"
tar -xf "$A" -C "$WORK/x" --no-mac-metadata --no-same-owner --no-same-permissions \
  "$TOP/external" "$TOP/wine/x86_64-windows/atidxx64.dll" "$TOP/wine/x86_64-windows/d3d11.dll" \
  "$TOP/wine/x86_64-windows/d3d12.dll" "$TOP/wine/x86_64-windows/dxgi.dll" > "$WORK/x.err" 2>&1 \
  || die "the pieces could not be taken out of the archive: $(tail -n 1 "$WORK/x.err")"
L="$WORK/x/$TOP"
[ -d "$L" ] || die "the archive does not hold $TOP"

# 5. exactly the 15 files and 3 links, the links with those targets, and nothing beside them
GOT="$(cd "$L" && { find . -type f | sed 's#^\./#f #'
                    find . -type l | while IFS= read -r l; do printf 'l %s -> %s\n' "${l#./}" "$(readlink "$l")"; done
                    find . ! -type f ! -type l ! -type d | sed 's#^\./#? #'; } | LC_ALL=C sort)"
[ "$GOT" = "$(printf '%s\n' "$WANT" | LC_ALL=C sort)" ] || die "what came out of the archive is not the 15 files and 3 links this was tested with"
[ "$(cd "$WORK/x" && find . -type f -o -type l | wc -l | tr -d ' ')" = 18 ] || die "the archive put a file outside the pieces"

# 6. the version, Apple's signature on the framework and on the library, the four DLLs' sha256
F="$L/external/D3DMetal.framework"
V="$(plutil -extract CFBundleShortVersionString raw "$F/Versions/A/Resources/Info.plist" 2>/dev/null)"
[ "$V" = 3.0 ] || die "the framework reads version ${V:-none}, not 3.0"
codesign --verify --strict -R '=identifier "com.apple.D3DMetal" and anchor apple' "$F" > /dev/null 2>&1 \
  || die "D3DMetal.framework is not signed by Apple as com.apple.D3DMetal"
codesign --verify --strict -R '=identifier "com.apple.libd3dshared" and anchor apple' "$L/external/libd3dshared.dylib" > /dev/null 2>&1 \
  || die "libd3dshared.dylib is not signed by Apple as com.apple.libd3dshared"
[ "$(sha "$L/wine/x86_64-windows/atidxx64.dll")" = "$SHA_ATIDXX64" ] || die "atidxx64.dll is not the file this was tested with"
[ "$(sha "$L/wine/x86_64-windows/d3d11.dll")" = "$SHA_D3D11" ] || die "d3d11.dll is not the file this was tested with"
[ "$(sha "$L/wine/x86_64-windows/d3d12.dll")" = "$SHA_D3D12" ] || die "d3d12.dll is not the file this was tested with"
[ "$(sha "$L/wine/x86_64-windows/dxgi.dll")" = "$SHA_DXGI" ] || die "dxgi.dll is not the file this was tested with"

# 7. lib into the folder; the work folder goes, the archive with it
mv "$L" "$INTO/lib" || die "the pieces could not be moved into $(tilde "$INTO")"
rm -rf "$WORK"
trap - EXIT
echo "$INTO/lib"
