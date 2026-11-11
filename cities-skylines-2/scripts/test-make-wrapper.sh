#!/bin/bash
# test-make-wrapper.sh -- scripts/make-wrapper.sh with HOME at a scratch folder (docs/plans/simple-install.md,
# NT1). A stub curl copies fixture archives made here: the engine a tar under its .tar.7z name, the template a
# tar inside a tar whose files carry a quarantine attribute, as the real ones are (measured 2026-11-10). The
# pins are rewritten in a scratch copy. The template's launcher is a stub that records its call and makes a
# fake prefix; wine64 and wineserver are stubs. No network, no Wine, nothing written outside the scratch
# folder (the real ~/Applications is listed before and after).
#   bash scripts/test-make-wrapper.sh            exit 0 = every case passed
#   MUTANT=1  ...  the sha256 not compared; must exit 1
#   MUTANT=2  ...  step 1's existence test removed (an existing target replaced); must exit 1
#   MUTANT=3  ...  step 9's test before the move removed; must exit 1
#   MUTANT=4  ...  the build folder left behind on failure; must exit 1
#   MUTANT=5  ...  a failed prefix still moved to the target; must exit 1
#   MUTANT=6  ...  L1_DOWNLOADS used without the sha256; must exit 1
#   MUTANT=7  ...  the bundle not renamed before the prefix is made; must exit 1
#   MUTANT=8  ...  both quarantine guards removed; must exit 1
#   MUTANT=9  ...  a live build folder removed; must exit 1
#   MUTANT=10 ...  a pin changed in the script alone; must exit 1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REAL="$HERE/make-wrapper.sh"
LAUNCHER="$HERE/../launchers/launch-cs2-dxmt11.sh"
REALHOME="$HOME"
T="$(mktemp -d /tmp/make-wrapper-test.XXXX)"
trap 'hdiutil detach -quiet "$T/cs-mnt" 2>/dev/null; rm -rf "$T"' EXIT
S="$T/make-wrapper.sh"; cp "$REAL" "$S"
mutate() {  # <sed expression> <grep that proves it applied>
  sed -i '' "$1" "$S"; grep -q -- "$2" "$S" || { echo "REFUSED: mutant did not apply"; exit 2; }
}
case "${MUTANT:-0}" in
  1) mutate 's#|| \[ "\$got" != "\$want" \]; then$#; then#' 'bytes" \] ; then$' ;;
  2) mutate 's#^{ \[ -e "\$TARGET" \] || \[ -L "\$TARGET" \]; } \&\& die "\$(tilde "\$TARGET") already exists.*#: step1#' '^: step1$'
     mutate 's#^{ \[ -e "\$TARGET" \] || \[ -L "\$TARGET" \]; } \&\& die "\$(tilde "\$TARGET") appeared while.*#rm -rf "$TARGET"#' '^rm -rf "\$TARGET"$' ;;
  3) mutate 's#^{ \[ -e "\$TARGET" \] || \[ -L "\$TARGET" \]; } \&\& die "\$(tilde "\$TARGET") appeared while.*#: step9#' '^: step9$' ;;
  4) mutate 's#^  rm -rf "\$B"$#  :#' '^  :$' ;;
  5) mutate 's#^\[ "\$rc" = 0 \] || fail_log "\$B/prefix.log" "the prefix was not made.*#: prefix#' '^: prefix$' ;;
  6) mutate 's#if \[ "\$(stat -f %z "\$out")" = "\$bytes" \] \&\& \[ "\$(sha "\$out")" = "\$want" \]; then#if true; then#' 'if true; then' ;;
  7) mutate 's#^mv "\$APP0" "\$APP" || die .*#APP="$APP0"#' '^APP="\$APP0"$' ;;
  8) mutate 's#/usr/bin/tar --no-mac-metadata -xf "\$B/t1/#/usr/bin/tar -xf "$B/t1/#' '/usr/bin/tar -xf "\$B/t1/'
     mutate 's#^xattr -dr com.apple.quarantine "\$TOP".*#: guard#' '^: guard$' ;;
  9) mutate 's#if kill -0 "\$p" 2>/dev/null; then#if false; then#' 'if false; then' ;;
  10) mutate 's#^ENGINE_SHA=afdaab97.*#ENGINE_SHA=1111111111111111111111111111111111111111111111111111111111111111#' '^ENGINE_SHA=1111' ;;
esac

fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

# --- the pins, as published (docs/plans/simple-install.md, 1.3), before the copy's pins are rewritten
pinned() { sed -n "s/^$1=\"\{0,1\}\([^\"]*\)\"\{0,1\}$/\1/p" "$S"; }
check "pins: the engine's address, size and sha256" "$(pinned ENGINE_URL) $(pinned ENGINE_BYTES) $(pinned ENGINE_SHA)" \
  "https://github.com/vitor251093/porting-kit-engines/releases/download/wineskin/WS12Wine11.0_DXMT-v0.80.tar.7z 180784324 afdaab97e84ec7064b8fddf47192c95b18b8bbb9cc3aa4d81060a57d7b4dced0"
check "pins: the template's address, size and sha256" "$(pinned TEMPLATE_URL) $(pinned TEMPLATE_BYTES) $(pinned TEMPLATE_SHA)" \
  "https://github.com/vitor251093/porting-kit-wrappers/releases/download/Wineskin-3.0.6-2/Wineskin.app.tar.7z 53110672 fbe276bba96d5582b99c511117abb1e035a988b8c1aeefe27c32df266a07907a"
ENGINE_URL="$(pinned ENGINE_URL)"; TEMPLATE_URL="$(pinned TEMPLATE_URL)"
ENGINE="$(basename "$ENGINE_URL")"; TEMPLATE="$(basename "$TEMPLATE_URL")"

# --- the source
check "the library path is exported with the launcher's own line" \
  "$(grep -cxF "$(grep -m1 '^export DYLD_FALLBACK_LIBRARY_PATH=' "$LAUNCHER")" "$REAL")" 1
check "no nohup, env, setsid or kill -9 outside comments" \
  "$(grep -v '^[[:space:]]*#' "$REAL" | grep -cE '(^|[^-[:alnum:]_])(nohup|setsid)([^[:alnum:]_]|$)|(^|[^[:alnum:]_-])env |kill -9')" 0

# --- fixtures
F="$T/fix"; mkdir -p "$F/src" "$F/good" "$F/bad"
mk_template() {   # <out> [two-apps|no-launcher|no-freetype|no-gnutls|no-inotify]
  local d="$F/src/tpl" a; rm -rf "$d"; mkdir -p "$d/in" "$d/out"
  a="$d/in/Wineskin-3.0.6-2.app"; mkdir -p "$a/Contents/MacOS" "$a/Contents/Frameworks" "$a/Contents/SharedSupport/Logs"
  for l in libfreetype.6.dylib libgnutls.30.dylib libinotify.0.dylib libSDL2.dylib; do : > "$a/Contents/Frameworks/$l"; done
  case "${2:-}" in
    no-freetype) rm "$a/Contents/Frameworks/libfreetype.6.dylib" ;;
    no-gnutls) rm "$a/Contents/Frameworks/libgnutls.30.dylib" ;;
    no-inotify) rm "$a/Contents/Frameworks/libinotify.0.dylib" ;;
    two-apps) mkdir -p "$d/in/Other.app/Contents" ;;
  esac
  if [ "${2:-}" != no-launcher ]; then
    cat > "$a/Contents/MacOS/wineskinlauncher" << 'L'
#!/bin/bash
b="$(cd "$(dirname "$0")/../.." && pwd)"
echo "LAUNCHER $* bundle=$(basename "$b")" >> "$LAUNCHER_CALLS"
[ -n "${STUB_MAKE_TARGET:-}" ] && { mkdir -p "$STUB_MAKE_TARGET"; echo mine > "$STUB_MAKE_TARGET/mark"; }
p="$b/Contents/SharedSupport/prefix"
mkdir -p "$p/drive_c/windows" "$p/drive_c/users/Wineskin"
[ -n "${STUB_NO_SYSREG:-}" ] || : > "$p/system.reg"
[ -n "${STUB_NO_USERS:-}" ] && rm -rf "$p/drive_c/users/Wineskin"
echo "prefix made for $HOME/x"
[ -n "${STUB_LAUNCHER_FAIL:-}" ] && exit 1   # a whole prefix and a failure: only the exit code tells
exit 0
L
    chmod +x "$a/Contents/MacOS/wineskinlauncher"
  fi
  xattr -w com.apple.quarantine "0082;00000000;Test;" "$a/Contents/Frameworks/libSDL2.dylib"
  [ -f "$a/Contents/MacOS/wineskinlauncher" ] && xattr -w com.apple.quarantine "0082;00000000;Test;" "$a/Contents/MacOS/wineskinlauncher"
  (cd "$d/in" && /usr/bin/tar -cf "$d/out/Wineskin.app.tar" .)
  (cd "$d/out" && /usr/bin/tar -cf "$1" Wineskin.app.tar)
}
mk_engine() {   # <out> [no-wine64|silent]
  local d="$F/src/eng"; rm -rf "$d"; mkdir -p "$d/wswine.bundle/bin" "$d/wswine.bundle/lib"
  case "${2:-}" in
    no-wine64) ;;
    silent) printf '#!/bin/bash\n' > "$d/wswine.bundle/bin/wine64" ;;
    *) printf '#!/bin/bash\necho wine-11.0\n' > "$d/wswine.bundle/bin/wine64" ;;
  esac
  printf '#!/bin/bash\necho "WINESERVER $* prefix=$WINEPREFIX" >> "$WINESERVER_CALLS"\n' > "$d/wswine.bundle/bin/wineserver"
  chmod +x "$d/wswine.bundle/bin"/*
  (cd "$d" && /usr/bin/tar -cf "$1" wswine.bundle)
}
mk_template "$F/good/$TEMPLATE"; mk_engine "$F/good/$ENGINE"
pin() { sed -i '' "s#^$1=.*#$1=$2#" "$S"; }
sz() { stat -f %z "$1"; }
sh256() { shasum -a 256 "$1" | awk '{ print $1 }'; }
pin_to() {   # <folder>: the copy's pins made those of the fixtures in <folder>
  pin ENGINE_BYTES "$(sz "$1/$ENGINE")"; pin ENGINE_SHA "$(sh256 "$1/$ENGINE")"
  pin TEMPLATE_BYTES "$(sz "$1/$TEMPLATE")"; pin TEMPLATE_SHA "$(sh256 "$1/$TEMPLATE")"
}
pin_to "$F/good"; cp "$S" "$S.good"

# --- stubs
mkdir -p "$T/bin"
cat > "$T/bin/curl" << 'C'
#!/bin/bash
echo "CURL $*" >> "$CURL_CALLS"
[ -n "${STUB_CURL_EXIT:-}" ] && exit "$STUB_CURL_EXIT"
out=""; url=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) url="$1"; shift ;; esac; done
cp "$FIXDIR/$(basename "$url")" "$out"
C
printf '#!/bin/bash\necho "Filesystem 1024-blocks Used Available Capacity Mounted"\necho "/dev/x 999999999 1 ${STUB_DF_KB:-99999999} 1%% /"\n' > "$T/bin/df"
printf '#!/bin/bash\nif [ "$1" = -u ] && [ -n "${STUB_ROOT:-}" ]; then echo 0; else exec /usr/bin/id "$@"; fi\n' > "$T/bin/id"
chmod +x "$T/bin"/*
export LAUNCHER_CALLS="$T/launcher.calls" CURL_CALLS="$T/curl.calls" WINESERVER_CALLS="$T/wineserver.calls"
real_apps() { ls -A "$REALHOME/Applications" 2>/dev/null | shasum | cut -c1-12; }
REAL_BEFORE="$(real_apps)"

n=0
newh() { n=$((n + 1)); H="$T/h$n"; mkdir -p "$H/Applications"; : > "$LAUNCHER_CALLS"; : > "$CURL_CALLS"; : > "$WINESERVER_CALLS"; }
run() {   # the copy, HOME at $H (newh first, in the calling shell); output in $H.out; echoes the exit code
  env -u CS2_WRAPPER -u L1_DOWNLOADS HOME="$H" PATH="$T/bin:$PATH" FIXDIR="${FIXDIR:-$F/good}" \
    ${DL:+L1_DOWNLOADS="$DL"} bash "$S" "$@" > "$H.out" 2>&1 < /dev/null
  echo $?
}
W="Applications/CS2dxmt11.app"
left() { ls -A "$H/Applications" 2>/dev/null | grep -c '^\.l1-wrapper'; }
calls() { wc -l < "$1" | tr -d ' '; }
said() { grep -c -- "$1" "$H.out"; }

# --- made
newh; check "made: exit 0" "$(run)" 0
check "  ...wine64, prefix/system.reg, users/Wineskin and Frameworks at the target; no build folder left" \
  "$([ -x "$H/$W/Contents/SharedSupport/wine/bin/wine64" ] && echo y):$([ -f "$H/$W/Contents/SharedSupport/prefix/system.reg" ] && echo y):$([ -d "$H/$W/Contents/SharedSupport/prefix/drive_c/users/Wineskin" ] && echo y):$([ -f "$H/$W/Contents/Frameworks/libinotify.0.dylib" ] && echo y):$(left)" "y:y:y:y:0"
check "  ...no file of it carries the quarantine attribute" "$(xattr -lr "$H/$W" 2>/dev/null | grep -c quarantine)" 0
check "  ...the launcher called once, with WSS-wineprefixcreate, from a bundle named as the target" \
  "$(cat "$LAUNCHER_CALLS")" "LAUNCHER WSS-wineprefixcreate bundle=CS2dxmt11.app"
check "  ...curl called twice, with exactly the two published addresses" \
  "$(calls "$CURL_CALLS"):$(grep -c " $TEMPLATE_URL\$" "$CURL_CALLS"):$(grep -c " $ENGINE_URL\$" "$CURL_CALLS")" "2:1:1"
check "  ...curl given the https-only options" "$(grep -c -- '--proto =https --tlsv1.2 -fL --retry 2' "$CURL_CALLS")" 2
check "  ...wineserver waited for, in the new prefix" "$(grep -c "WINESERVER -w prefix=.*/CS2dxmt11.app/Contents/SharedSupport/prefix\$" "$WINESERVER_CALLS")" 1
check "  ...the wrapper's path printed with ~, and the home folder nowhere in the output" "$(said 'made ~/Applications/CS2dxmt11.app'):$(grep -c "$H" "$H.out")" "1:0"
newh; rm -rf "$H/Applications"; check "no ~/Applications yet: made, the folder made" "$(run):$([ -d "$H/$W/Contents/SharedSupport/prefix" ] && echo y)" "0:y"
newh; mkdir -p "$T/else$n"; check "--wrapper elsewhere: made there" "$(run --wrapper "$T/else$n/My Wrapper.app"):$([ -f "$T/else$n/My Wrapper.app/Contents/SharedSupport/prefix/system.reg" ] && echo y)" "0:y"
newh; mkdir -p "$T/cw$n"
rc="$(env -u L1_DOWNLOADS CS2_WRAPPER="$T/cw$n/W.app" HOME="$H" PATH="$T/bin:$PATH" FIXDIR="$F/good" bash "$S" > "$H.out" 2>&1; echo $?)"
check "CS2_WRAPPER names the target" "$rc:$([ -d "$T/cw$n/W.app/Contents/SharedSupport/prefix" ] && echo y)" "0:y"
newh; mkdir -p "$H/Applications/.l1-wrapper.dead1/x"; echo 999999 > "$H/Applications/.l1-wrapper.dead1/pid"
check "a build folder left by a dead install: removed, and the wrapper made" "$(run):$(left):$(said 'removed a build folder')" "0:0:1"

# --- refused before anything: nothing made, no build folder left, curl not called
refused() {   # <name> <exit> [<want exit>]
  check "$1: exit ${3:-1}, nothing at the target, no build folder, nothing downloaded" \
    "$2:$([ -e "$H/$W/Contents/SharedSupport" ] && echo made || echo none):$(left):$(calls "$CURL_CALLS")" "${3:-1}:none:0:0"
}
newh; mkdir -p "$H/$W"; echo keep > "$H/$W/mark"
check "target exists as a folder: exit 1, left as it was, nothing downloaded" "$(run):$(cat "$H/$W/mark"):$(calls "$CURL_CALLS"):$(left)" "1:keep:0:0"
newh; echo file > "$H/$W"
check "target exists as a file: exit 1, left as it was, nothing downloaded" "$(run):$(cat "$H/$W"):$(calls "$CURL_CALLS")" "1:file:0"
newh; ln -s "$T/nowhere" "$H/$W"
check "target is a dangling link: exit 1, left as it was, nothing downloaded" "$(run):$([ -L "$H/$W" ] && echo link):$(calls "$CURL_CALLS")" "1:link:0"
newh; refused "a relative path" "$(run --wrapper Applications/X.app)"
newh; refused "a name not ending .app" "$(run --wrapper "$H/Applications/CS2dxmt11")"
newh; refused "a name with a character the template launcher cannot take" "$(run --wrapper "$H/Applications/CS2;x.app")"
newh; refused "a folder that does not exist" "$(run --wrapper "$T/nofolder$n/X.app")"
newh; refused "too little space" "$(STUB_DF_KB=1000 run)"
newh; refused "run as root" "$(STUB_ROOT=1 run)"
newh; mkdir -p "$H/Applications/.l1-wrapper.live1"; echo $$ > "$H/Applications/.l1-wrapper.live1/pid"
check "another install's live build folder: exit 3, it is left, nothing downloaded" \
  "$(run):$([ -d "$H/Applications/.l1-wrapper.live1" ] && echo kept):$(calls "$CURL_CALLS")" "3:kept:0"
check "a wrong option: exit 2" "$(bash "$S" --nope > /dev/null 2>&1; echo $?)" 2
check "--wrapper with no value: exit 2" "$(bash "$S" --wrapper > /dev/null 2>&1; echo $?)" 2
CS=""
if hdiutil create -quiet -size 20m -fs 'Case-sensitive APFS' -volname l1cstest "$T/cs.dmg" 2>/dev/null \
   && mkdir -p "$T/cs-mnt" && hdiutil attach -quiet -nobrowse -mountpoint "$T/cs-mnt" "$T/cs.dmg" 2>/dev/null; then
  CS=1; mkdir -p "$T/cs-mnt/Apps"
  newh; refused "a folder on a case-sensitive volume" "$(run --wrapper "$T/cs-mnt/Apps/X.app")"
  check "  ...and it says why" "$(said 'tells capitals from small letters')" 1
  hdiutil detach -quiet "$T/cs-mnt"
fi
check "the case-sensitive disk image could be made and mounted" "${CS:-no}" 1

# --- failed after a download: nothing made, no build folder left
failed() {   # <name> <exit>
  check "$1: exit 1, nothing at the target, no build folder" "$2:$([ -e "$H/$W" ] && echo made || echo none):$(left)" "1:none:0"
}
newh; failed "curl fails with an HTTP error" "$(STUB_CURL_EXIT=22 run)"; check "  ...says it is no longer published" "$(said 'no longer published')" 1
newh; failed "curl fails otherwise" "$(STUB_CURL_EXIT=6 run)"; check "  ...says to check the network" "$(said 'Check the network')" 1
pin ENGINE_SHA 0000; newh; failed "a wrong sha256 of the engine" "$(run)"; check "  ...both checksums said" "$(grep -c 'sha256 [0-9a-f]\{64\}, where .* sha256 0000 was expected' "$H.out")" 1
cp "$S.good" "$S"; pin TEMPLATE_SHA 0000; newh; failed "a wrong sha256 of the template" "$(run)"
cp "$S.good" "$S"; pin ENGINE_BYTES 5; newh; failed "a wrong size" "$(run)"
bad() {   # <template kind> <engine kind>: fixtures in $F/bad, the copy pinned to them
  rm -f "$F/bad"/*; mk_template "$F/bad/$TEMPLATE" "$1"; mk_engine "$F/bad/$ENGINE" "$2"; cp "$S.good" "$S"; pin_to "$F/bad"
}
for k in two-apps no-launcher no-freetype no-gnutls no-inotify; do
  newh; bad "$k" ok; failed "a template: $k" "$(FIXDIR="$F/bad" run)"
done
newh; bad ok no-wine64; failed "an engine without wine64" "$(FIXDIR="$F/bad" run)"
newh; bad ok silent; failed "wine64 --version prints nothing" "$(FIXDIR="$F/bad" run)"
cp "$S.good" "$S"
newh; failed "the template's launcher exits 1 after making a whole prefix" "$(STUB_LAUNCHER_FAIL=1 run)"
check "  ...its last lines shown, with the home folder as ~" "$(said 'prefix made for ~/x'):$(grep -c "$H" "$H.out")" "1:0"
newh; failed "the prefix has no system.reg" "$(STUB_NO_SYSREG=1 run)"
check "  ...its last lines shown, with the home folder as ~" "$(said 'prefix made for ~/x'):$(grep -c "$H" "$H.out")" "1:0"
newh; failed "the prefix has no users/Wineskin" "$(STUB_NO_USERS=1 run)"
newh; T9="$H/$W"; rc="$(STUB_MAKE_TARGET="$T9" run)"
check "the target appears while the prefix is made: exit 1, its folder left as it was, nothing nested" \
  "$rc:$(cat "$T9/mark"):$(ls -A "$T9" | tr '\n' ' '):$(left)" "1:mine:mark :0"
check "  ...caught before the move" "$(said 'appeared while the wrapper was being made')" 1

# --- L1_DOWNLOADS
DL="$T/dl"; mkdir -p "$DL"; cp "$F/good/$ENGINE" "$DL/"
newh; check "L1_DOWNLOADS with a matching engine: made, curl called for the template only" \
  "$(run):$(calls "$CURL_CALLS"):$(grep -c "$ENGINE" "$CURL_CALLS")" "0:1:0"
echo tampered >> "$DL/$ENGINE"
newh; check "a non-matching one: dropped with a line, and downloaded" \
  "$(run):$(calls "$CURL_CALLS"):$(said 'not the file this was tested with: downloading it instead')" "0:2:1"
DL=""

# --- --check
newh; rm -rf "$H/Applications"
check "--check: exit 0, says what it would download, writes nothing, does not make ~/Applications" \
  "$(run --check):$(said 'would make ~/Applications/CS2dxmt11.app'):$(calls "$CURL_CALLS"):$([ -e "$H/Applications" ] && echo made || echo none)" "0:1:0:none"
newh; check "--check with too little space: exit 1" "$(STUB_DF_KB=1000 run --check)" 1
check "--help prints the usage" "$(bash "$S" --help | grep -c 'exit 0 = made')" 1

check "nothing written to the real ~/Applications" "$(real_apps)" "$REAL_BEFORE"
echo "$fails failure(s)"
[ "$fails" = 0 ]
