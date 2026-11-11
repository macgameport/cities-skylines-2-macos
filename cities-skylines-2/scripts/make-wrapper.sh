#!/bin/bash
# make-wrapper.sh -- make the Wine 11 + DXMT wrapper from two public files of Porting Kit's releases, with
# no Porting Kit app (docs/plans/simple-install.md, 2.2): the Wineskin template and the engine, each
# checked against a fixed sha256, then the prefix made by the template's own launcher, as Wineskin Winery
# makes it. Measured on the Studio, 2026-11-10: about 40 s once the two files are here.
#
#   bash scripts/make-wrapper.sh                       # ~/Applications/CS2dxmt11.app, or $CS2_WRAPPER
#   bash scripts/make-wrapper.sh --wrapper <path.app>  # another place (an absolute path)
#   bash scripts/make-wrapper.sh --check               # say what it would do; write nothing
#
#   exit 0 = made (or, with --check, could be made); 1 = refused or failed, said why, nothing left;
#   2 = a wrong option; 3 = another install is making a wrapper in that folder.
# It never replaces anything: the target must not exist. It builds in a hidden folder beside the target,
# .l1-wrapper.XXXXXX, removed when it exits, and moves the finished wrapper in last.
# L1_DOWNLOADS=<folder> names a folder of the two files already downloaded: a copy of one is used only if
# its size and sha256 match.
set -u
ENGINE_URL="https://github.com/vitor251093/porting-kit-engines/releases/download/wineskin/WS12Wine11.0_DXMT-v0.80.tar.7z"
ENGINE_BYTES=180784324
ENGINE_SHA=afdaab97e84ec7064b8fddf47192c95b18b8bbb9cc3aa4d81060a57d7b4dced0
TEMPLATE_URL="https://github.com/vitor251093/porting-kit-wrappers/releases/download/Wineskin-3.0.6-2/Wineskin.app.tar.7z"
TEMPLATE_BYTES=53110672
TEMPLATE_SHA=fbe276bba96d5582b99c511117abb1e035a988b8c1aeefe27c32df266a07907a
NEED_KB=$((6 * 1024 * 1024))

tilde() { case "$1" in "$HOME") printf '~' ;; "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }
say() { echo "  $*"; }
die() { echo "  !! $*"; exit 1; }

CHECK=0
TARGET="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --wrapper) if [ $# -lt 2 ] || [ -z "$2" ]; then echo "--wrapper needs a value"; exit 2; fi
               TARGET="$2"; shift 2 ;;
    -h|--help) sed -n '2,/^set -u$/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)"; exit 2 ;;
  esac
done
[ "$(id -u)" = 0 ] && die "do not run this as root (with sudo): it would leave files only root can change in your home folder"

# 1. the target
case "$TARGET" in /*) ;; *) die "the wrapper's path must be absolute: $TARGET" ;; esac
TARGET="${TARGET%/}"
NAME="$(basename "$TARGET")"
printf '%s' "$NAME" | grep -Eq '^[A-Za-z0-9._ -]+\.app$' \
  || die "the wrapper's name must be letters, digits, spaces, dots, hyphens or underscores, ending .app: $NAME"
{ [ -e "$TARGET" ] || [ -L "$TARGET" ]; } && die "$(tilde "$TARGET") already exists; this script never replaces anything"

# 2. its folder: made if it is ~/Applications, on a volume that ignores case, with room
DIR="$(dirname "$TARGET")"
if [ ! -d "$DIR" ]; then
  if [ "$DIR" = "$HOME/Applications" ] && [ "$CHECK" = 0 ]; then mkdir -p "$DIR" || die "$(tilde "$DIR") could not be made"
  elif [ "$DIR" != "$HOME/Applications" ]; then die "the folder $(tilde "$DIR") does not exist"
  fi
fi
HAVE="$DIR"; while [ ! -d "$HAVE" ]; do HAVE="$(dirname "$HAVE")"; done
[ -d "$(printf '%s' "$HAVE" | tr '[:lower:]' '[:upper:]')" ] \
  || die "$(tilde "$HAVE") is on a volume that tells capitals from small letters; Steam and the game need one that does not"
FREE_KB="$(df -k "$HAVE" 2>/dev/null | awk 'NR == 2 { print $4 }')"
case "$FREE_KB" in ''|*[!0-9]*) die "the free space of $(tilde "$HAVE") could not be read" ;; esac
[ "$FREE_KB" -ge "$NEED_KB" ] || die "the wrapper needs 6 GB free; $(tilde "$HAVE") has $((FREE_KB / 1024 / 1024)) GB"
if [ "$CHECK" = 1 ]; then
  say "would make $(tilde "$TARGET"), downloading two files of Porting Kit's:"
  say "  $TEMPLATE_URL ($((TEMPLATE_BYTES / 1000000)) MB)"
  say "  $ENGINE_URL ($((ENGINE_BYTES / 1000000)) MB)"
  exit 0
fi

# 3. older build folders, then this one
for old in "$DIR"/.l1-wrapper.*; do
  [ -d "$old" ] || continue
  p="$(cat "$old/pid" 2>/dev/null)"
  case "$p" in ''|*[!0-9]*) ;; *) if kill -0 "$p" 2>/dev/null; then
    echo "  !! another install is making a wrapper in $(tilde "$DIR") (process $p). Wait for it, or quit it, then try again."
    exit 3
  fi ;; esac
  rm -rf "$old" && say "removed a build folder left by an install that stopped: $(tilde "$old")"
done
B="$(mktemp -d "$DIR/.l1-wrapper.XXXXXX")" || die "a build folder could not be made in $(tilde "$DIR")"
echo $$ > "$B/pid"
APP="$B/$NAME"
SS="$APP/Contents/SharedSupport"
cleanup() {
  if [ -x "$SS/wine/bin/wineserver" ] && [ -d "$SS/prefix" ]; then   # without the library path it exits 134
    WINEPREFIX="$SS/prefix" DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib" \
      "$SS/wine/bin/wineserver" -k >/dev/null 2>&1
  fi
  rm -rf "$B"
}
trap cleanup EXIT
fail_log() {   # <log> <message>: the last twenty lines of a step's output, then die
  echo "  -- the last lines of its output:"
  tail -n 20 "$1" 2>/dev/null | sed "s#$HOME#~#g" | sed 's/^/     /'
  die "$2"
}

# 4. the two files
sha() { shasum -a 256 "$1" | awk '{ print $1 }'; }
fetch() {   # <url> <bytes> <sha256> <file>
  local url="$1" bytes="$2" want="$3" out="$4" name size got rc bar=-sS
  name="$(basename "$url")"
  if [ -n "${L1_DOWNLOADS:-}" ] && [ -f "$L1_DOWNLOADS/$name" ]; then
    cp "$L1_DOWNLOADS/$name" "$out"
    if [ "$(stat -f %z "$out")" = "$bytes" ] && [ "$(sha "$out")" = "$want" ]; then say "$name: the copy in $(tilde "$L1_DOWNLOADS")"; return 0; fi
    rm -f "$out"; say "$name in $(tilde "$L1_DOWNLOADS") is not the file this was tested with: downloading it instead"
  fi
  say "downloading $name ($((bytes / 1000000)) MB)"
  [ -t 1 ] && bar=-#
  curl --proto '=https' --tlsv1.2 -fL --retry 2 $bar -o "$out" "$url"; rc=$?
  if [ "$rc" = 22 ]; then die "$name is no longer published at $url. Please open an issue: https://github.com/macgameport/1launcher/issues"
  elif [ "$rc" != 0 ]; then die "the download of $name failed (curl exit $rc). Check the network, then try again."
  fi
  size="$(stat -f %z "$out")"; got="$(sha "$out")"
  if [ "$size" != "$bytes" ] || [ "$got" != "$want" ]; then
    rm -f "$out"
    die "$name is not the file this was tested with: $size bytes, sha256 $got, where $bytes bytes, sha256 $want was expected. Please open an issue: https://github.com/macgameport/1launcher/issues"
  fi
}
fetch "$TEMPLATE_URL" "$TEMPLATE_BYTES" "$TEMPLATE_SHA" "$B/template.tar.7z"
fetch "$ENGINE_URL" "$ENGINE_BYTES" "$ENGINE_SHA" "$B/engine.tar.7z"

# 5. the template: a 7-Zip file holding one tar, whose files carry a quarantine attribute (measured)
mkdir "$B/t1" "$B/t" "$B/e"
/usr/bin/tar -xf "$B/template.tar.7z" -C "$B/t1" > "$B/tar.log" 2>&1 || fail_log "$B/tar.log" "the template could not be unpacked"
INNER="$(ls -A "$B/t1")"
if [ "$(printf '%s\n' "$INNER" | grep -c .)" = 1 ] && [ -f "$B/t1/$INNER" ] && [ "${INNER%.tar}" != "$INNER" ]; then
  /usr/bin/tar --no-mac-metadata -xf "$B/t1/$INNER" -C "$B/t" > "$B/tar.log" 2>&1 || fail_log "$B/tar.log" "the template's inner archive could not be unpacked"
  TOP="$B/t"
else
  TOP="$B/t1"
fi
xattr -dr com.apple.quarantine "$TOP" 2>/dev/null
n=0; for a in "$TOP"/*.app; do [ -d "$a" ] && [ ! -L "$a" ] && { n=$((n + 1)); APP0="$a"; }; done
[ "$n" = 1 ] || die "the template holds $n apps at its top, not one"
[ -x "$APP0/Contents/MacOS/wineskinlauncher" ] || die "the template has no Contents/MacOS/wineskinlauncher"
for l in libfreetype libgnutls libinotify; do
  ls "$APP0/Contents/Frameworks/$l"* > /dev/null 2>&1 || die "the template has no $l under Contents/Frameworks"
done
mv "$APP0" "$APP" || die "the template could not be renamed"   # its launcher writes this name into Info.plist

# 6. the engine: XZ data under a .7z name (measured)
/usr/bin/tar --no-mac-metadata -xf "$B/engine.tar.7z" -C "$B/e" > "$B/tar.log" 2>&1 || fail_log "$B/tar.log" "the engine could not be unpacked"
[ -x "$B/e/wswine.bundle/bin/wine64" ] && [ -x "$B/e/wswine.bundle/bin/wineserver" ] \
  || die "the engine has no wswine.bundle/bin/wine64 and wineserver"
mkdir -p "$SS" && mv "$B/e/wswine.bundle" "$SS/wine" || die "the engine could not be moved into the wrapper"

# 7. the prefix, made by the template's own launcher
say "making the Wine prefix (about 30 s)"
"$APP/Contents/MacOS/wineskinlauncher" WSS-wineprefixcreate > "$B/prefix.log" 2>&1; rc=$?
[ "$rc" = 0 ] || fail_log "$B/prefix.log" "the prefix was not made (the template's launcher exited $rc)"
for f in system.reg drive_c/windows drive_c/users/Wineskin; do
  [ -e "$SS/prefix/$f" ] || fail_log "$B/prefix.log" "the prefix was not made: it has no $f"
done

# 8. Wine itself, with the library path exported as the launcher exports it
export WINEPREFIX="$SS/prefix"
export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"
"$SS/wine/bin/wineserver" -w > /dev/null 2>&1 &
w=$!; i=0; while kill -0 "$w" 2>/dev/null && [ "$i" -lt 30 ]; do sleep 1; i=$((i + 1)); done
kill -0 "$w" 2>/dev/null && "$SS/wine/bin/wineserver" -k > /dev/null 2>&1
V="$("$SS/wine/bin/wine64" --version 2>/dev/null | head -n 1)"
case "$V" in wine-*) ;; *) die "wine64 --version did not answer" ;; esac

# 9. into place, last
{ [ -e "$TARGET" ] || [ -L "$TARGET" ]; } && die "$(tilde "$TARGET") appeared while the wrapper was being made; nothing was replaced"
mv "$APP" "$TARGET" || die "the wrapper could not be moved to $(tilde "$TARGET")"
if [ ! -x "$TARGET/Contents/MacOS/wineskinlauncher" ]; then
  [ -d "$TARGET/$NAME" ] && mv "$TARGET/$NAME" "$APP"   # mv onto a folder that appeared nests the bundle: take it back
  die "$(tilde "$TARGET") appeared while the wrapper was being moved in; nothing of it was replaced"
fi

# 10.
say "made $(tilde "$TARGET") ($(du -sh "$TARGET" | awk '{ print $1 }'), $V)"
say "Wine and the wrapper are Porting Kit's, used as published: https://www.portingkit.com"
exit 0
