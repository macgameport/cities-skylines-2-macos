#!/bin/bash
# test-install.sh -- scripts/install.sh with HOME at a scratch folder (docs/plans/simple-install.md, NT3). The
# script runs from a scratch copy of the repository whose setup.sh and make-wrapper.sh are recording stubs.
# Every outside program it calls is a recording stub on PATH: curl, softwareupdate, xcode-select, python3,
# caffeinate, id, df, pgrep, ps, lsof and sleep. The fixture wrapper's wine64 and wineserver are stubs too.
# Processes are files in a state folder: wine64 makes them as each start of Steam's plan says (STUB_STARTS),
# wineserver -k and -shutdown remove them, and the stub sleep moves the world on one poll at a time (the
# download, a blip in Steam's process, Apple's tools arriving). No network, no Wine, no real process is
# signalled (the stray sweep's kill is recorded through L1_KILL).
#   bash scripts/test-install.sh            exit 0 = every case passed
#   MUTANT=1  ...  Rosetta installed on Return; must exit 1
#   MUTANT=2  ...  setup run when the game is absent; must exit 1
#   MUTANT=3  ...  the wrapper made when one exists; must exit 1
#   MUTANT=4  ...  Steam's installer run when Steam is present; must exit 1
#   MUTANT=5  ...  the fatal line not acted on; must exit 1
#   MUTANT=6  ...  a one-poll gap restarts Steam; must exit 1
#   MUTANT=7  ...  -shutdown left out; must exit 1
#   MUTANT=8  ...  exit 0 when Steam is gone; must exit 1
#   MUTANT=9  ...  --check starts Steam; must exit 1
#   MUTANT=10 ...  the MZ test left out; must exit 1
#   MUTANT=11 ...  the lock not taken; must exit 1
#   MUTANT=12 ...  the running-game test left out; must exit 1
#   MUTANT=13 ...  the update-waiting state treated as not installed; must exit 1
#   MUTANT=14 ...  BytesToDownload 0 divides; must exit 1
#   MUTANT=15 ...  CS2_VIA_INSTALLER not passed to setup; must exit 1
#   MUTANT=16 ...  winemenubuilder.exe=d dropped; must exit 1
#   MUTANT=17 ...  the .crash left; must exit 1
#   MUTANT=18 ...  the start limit raised to six; must exit 1
#   MUTANT=19 ...  a copied function changed in install.sh alone; must exit 1
#   MUTANT=20 ...  the update state matched on any value other than 4; must exit 1
#   MUTANT=21 ...  a client already up started again; must exit 1
#   MUTANT=22 ...  the ten-minute limit removed; must exit 1
#   MUTANT=23 ...  a copied function run with an empty WINEPREFIX; must exit 1
#   MUTANT=24 ...  a broken python3 sent to xcode-select --install; must exit 1
#   MUTANT=25 ...  a signal ends in the EXIT trap alone (which then says Done.); must exit 1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
LAUNCHER="$REPO/cities-skylines-2/launchers/launch-cs2-dxmt11.sh"
T="$(mktemp -d /tmp/install-test.XXXX)"
trap 'rm -rf "$T"' EXIT
R="$T/repo"; mkdir -p "$R/cities-skylines-2/scripts" "$R/cities-skylines-2/patches" "$R/common"
S="$R/cities-skylines-2/scripts/install.sh"; cp "$HERE/install.sh" "$S"
: > "$R/cities-skylines-2/repatch.sh"; : > "$R/common/make-launcher-app.sh"
mutate() {  # <sed expression> <grep that proves it applied>
  sed -i '' "$1" "$S"; grep -q -- "$2" "$S" || { echo "REFUSED: mutant did not apply"; exit 2; }
}
first() {   # <perl search> <replacement> <grep that proves it applied>: the first occurrence only
  perl -0pi -e "s/$1/$2/" "$S"; grep -q -- "$3" "$S" || { echo "REFUSED: mutant did not apply"; exit 2; }
}
case "${MUTANT:-0}" in
  1) mutate 's#^      y|Y) softwareupdate#      y|Y|"") softwareupdate#' 'y|Y|"") softwareupdate' ;;
  2) mutate 's#|| { echo absent; return; }#|| { echo installed; return; }#' 'echo installed; return; }$' ;;
  3) mutate 's#^if \[ -d "\$W" \]; then say "OK: #if false; then say "OK: #' '^if false; then say "OK: ' ;;
  4) first 'if \[ -f "\$STEAMDIR\/steam.exe" \] \|\| \[ -f "\$STEAMDIR\/Steam.exe" \]; then say "OK"' 'if false; then say "OK"' '^if false; then say "OK"' ;;
  5) mutate "s#^FATAL=.*#FATAL='no such line'#" "^FATAL='no such line'" ;;
  6) mutate 's#^GONE_POLLS=3 #GONE_POLLS=1 #' '^GONE_POLLS=1 ' ;;
  7) mutate 's#^    "\$WINE" "\$(steam_exe)" -shutdown.*#    :#' '^    :$' ;;
  8) mutate 's#{ say "Steam closed before the game finished downloading."; exit 4; }#{ say "Steam closed before the game finished downloading."; exit 0; }#' 'downloading."; exit 0; }' ;;
  9) mutate 's#if \[ "\$CHECK" = 1 \]; then say "not installed: would start#if false; then say "not installed: would start#' 'if false; then say "not installed' ;;
  10) mutate 's# || \[ "\$(head -c 2 "\$D/SteamSetup.exe")" != MZ \]##' 'le 1048576 \] || ! grep' ;;
  11) mutate 's#^  acquire_lock 1 ||#  true ||#' '^  true ||' ;;
  12) first 'if prefix_known && game_running; then say "!! The game is running.[^\n]*\n' '' 'x' ; grep -c 'prefix_known && game_running' "$S" | grep -qx 1 || { echo "REFUSED: mutant did not apply"; exit 2; } ;;
  13) mutate 's#^  elif \[ \$((f \& 4)) -ne 0 \]; then echo update$#  elif false; then echo update#' 'elif false; then echo update' ;;
  14) mutate 's#^        if \[ "\$to" = 0 \]; then$#        if false; then#' '^        if false; then$' ;;
  15) mutate 's#^CS2_VIA_INSTALLER=1 bash "\$SETUP" "\$@"#bash "$SETUP" "$@"#' '^bash "\$SETUP" "\$@"' ;;
  16) mutate 's#^  export WINEDLLOVERRIDES="winemenubuilder.exe=d"#  export WINEDLLOVERRIDES=""#' 'WINEDLLOVERRIDES=""' ;;
  17) mutate 's#^    rm -f "\$STEAMDIR/.crash"#    :#' '^    :$' ;;
  18) mutate 's#^MAX_STARTS=5#MAX_STARTS=6#' '^MAX_STARTS=6' ;;
  19) mutate 's#^_owns() { lsof -p "\$1" 2>/dev/null | grep -q "\$WINEPREFIX"; }#_owns() { lsof -p "$1" 2>/dev/null | grep -qF "$WINEPREFIX"; }#' 'grep -qF "\$WINEPREFIX"' ;;
  20) mutate 's#^  elif \[ \$((f \& 4)) -ne 0 \]; then echo update$#  elif true; then echo update#' 'elif true; then echo update' ;;
  21) mutate 's#^    if \[ "\$up" = 0 \]; then$#    if true; then#' '^    if true; then$' ;;
  22) mutate 's#^    while \[ "\$i" -lt "\$START_POLLS" \]; do$#    while :; do#' '^    while :; do$' ;;
  23) first 'if prefix_known && game_running' 'if game_running' '^if game_running' ;;
  25) mutate "s#^trap 'on_signal 143' TERM\$#: no trap#" '^: no trap$' ;;
  24) mutate 's#^if xcode-select -p > /dev/null 2>&1; then #if xcode-select -p > /dev/null 2>\&1 \&\& py_ok; then #' '2>&1 && py_ok; then' ;;
esac

fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

# --- the source: copies held identical to the launcher's, and what no line may hold
fn() {   # one function, as common/test-launch-lock.sh cuts it
  awk -v f="$1" 'index($0, f "() {") == 1 { print; if ($0 ~ /; }[[:space:]]*$/) exit; p = 1; next }
                 p { print; if ($0 ~ /^}/) exit }' "$2"
}
for f in find_wrapper _owns webhelper_up steam_family game_running acf_field; do
  check "the copy of $f equals the launcher's" "$( [ -n "$(fn "$f" "$S")" ] && [ "$(fn "$f" "$S")" = "$(fn "$f" "$LAUNCHER")" ] && echo same )" same
done
check "the python3 test equals setup.sh's" "$(grep -cxF "$(grep -m1 '^if python3 -c' "$HERE/setup.sh")" "$S")" 1
check "the library path is exported with the launcher's own line" "$(grep -cxF "  $(grep -m1 '^export DYLD_FALLBACK_LIBRARY_PATH=' "$LAUNCHER")" "$S")" 1
check "no nohup, env, setsid or kill -9 outside comments" \
  "$(grep -v '^[[:space:]]*#' "$S" | grep -cE '(^|[^-[:alnum:]_])(nohup|setsid)([^[:alnum:]_]|$)|(^|[^[:alnum:]_-])env |kill -9')" 0

# --- stubs
B="$T/bin"; mkdir -p "$B" "$T/fixbin"
export ST="$T/state" CALLS="$T/calls"
cat > "$R/cities-skylines-2/scripts/setup.sh" << 'X'
#!/bin/bash
echo "SETUP $* via=${CS2_VIA_INSTALLER:-} wrapper=${CS2_WRAPPER:-}" >> "$CALLS"
case " $* " in *" --mac-only "*)
  if [ -n "${STUB_NO_ROSETTA:-}" ] && [ ! -f "$ST/rosetta" ]; then echo "  Rosetta 2   MISSING"; exit 1; fi
  exit 0 ;;
esac
exit "${STUB_SETUP_EXIT:-0}"
X
cat > "$R/cities-skylines-2/scripts/make-wrapper.sh" << 'X'
#!/bin/bash
echo "MAKEWRAPPER $*" >> "$CALLS"
case " $* " in *" --check "*) exit 0 ;; esac
[ -n "${STUB_MW_EXIT:-}" ] && exit "$STUB_MW_EXIT"
bash "$MKW" "$2"
X
cat > "$T/mkw.sh" << 'X'
#!/bin/bash
# mkw.sh <wrapper> [steam] [game <StateFlags>|game-nomanifest]: a fixture wrapper
S="$1/Contents/SharedSupport"; P="$S/prefix/drive_c/Program Files (x86)/Steam"
mkdir -p "$S/wine/bin" "$P/logs"; cp "$FIXBIN/wine64" "$FIXBIN/wineserver" "$S/wine/bin/"
shift
while [ $# -gt 0 ]; do
  case "$1" in
    steam) : > "$P/Steam.exe" ;;
    game) mkdir -p "$P/steamapps/common/Cities Skylines II"; : > "$P/steamapps/common/Cities Skylines II/Cities2.exe"
          printf '"AppState"\n{\n\t"StateFlags"\t\t"%s"\n\t"BytesToDownload"\t\t"0"\n\t"BytesDownloaded"\t\t"0"\n}\n' "$2" > "$P/steamapps/appmanifest_949230.acf"; shift ;;
    game-nomanifest) mkdir -p "$P/steamapps/common/Cities Skylines II"; : > "$P/steamapps/common/Cities Skylines II/Cities2.exe" ;;
  esac
  shift
done
X
export MKW="$T/mkw.sh" FIXBIN="$T/fixbin"
cat > "$T/fixbin/wine64" << 'X'
#!/bin/bash
echo "WINE $* dll=${WINEDLLOVERRIDES:-}" >> "$CALLS"
P="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
case "$*" in
  *SteamSetup.exe*/S*) [ -n "${STUB_SETUP_NOEXE:-}" ] || { mkdir -p "$P/logs"; : > "$P/Steam.exe"; }; exit "${STUB_SETUP_RC:-0}" ;;
  *-shutdown*) [ -n "${STUB_SHUTDOWN_STUCK:-}" ] || rm -f "$ST/steam" "$ST/helper"; exit 0 ;;
  *-no-cef-sandbox*)
    n=$(( $(cat "$ST/starts" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$ST/starts"
    echo "start $n at tick $(wc -l < "$ST/ticks" | tr -d ' ') crash=$([ -e "$P/.crash" ] && echo yes || echo no)" >> "$ST/startlog"
    kind="$(echo "${STUB_STARTS:-ok}" | awk -v n="$n" '{ print $n }')"; kind="${kind:-ok}"
    BL="$P/logs/bootstrap_log.txt"; mkdir -p "$P/logs"
    case "$kind" in
      ok) : > "$ST/steam"; : > "$ST/helper-next" ;;
      fatal-u) : > "$ST/steam"; echo "[2026-11-10 20:40:49] Error: Failed to determine download location for universe 1" >> "$BL" ;;
      fatal-o) : > "$ST/steam"; echo "[2026-11-10 20:47:58] Error: Steam needs to be online to update. Please confirm your network connection and try again." >> "$BL" ;;
      blip) : > "$ST/steam"; echo 2 > "$ST/blip" ;;
      slow) : > "$ST/steam" ;;
      gone) ;;
    esac ;;
esac
exit 0
X
cat > "$T/fixbin/wineserver" << 'X'
#!/bin/bash
echo "WINESERVER $* prefix=${WINEPREFIX:-}" >> "$CALLS"
case "$1" in -k) if [ -n "${STUB_WS_STUCK:-}" ]; then rm -f "$ST/steam"; else rm -f "$ST/steam" "$ST/helper"; fi ;; esac
exit 0
X
cat > "$B/sleep" << 'X'
#!/bin/bash
/bin/sleep 0.15
echo "$1 lock=$([ -L "${WINEPREFIX:-/nowhere}/.launcher.lock" ] && echo yes || echo no)" >> "$ST/ticks"
[ "$(wc -l < "$ST/ticks")" -gt 400 ] && { echo "RUNAWAY" >> "$ST/../runaway"; kill -TERM "$PPID"; exit 0; }
[ -f "$ST/tools-pending" ] && [ -z "${STUB_TOOLS_NEVER:-}" ] && { rm "$ST/tools-pending"; : > "$ST/tools"; }
if [ -f "$ST/blip" ]; then
  if [ "$(cat "$ST/blip")" = 2 ]; then rm -f "$ST/steam"; echo 1 > "$ST/blip"; else : > "$ST/steam"; : > "$ST/helper"; rm "$ST/blip"; fi
  exit 0
fi
P="$WINEPREFIX/drive_c/Program Files (x86)/Steam"; M="$P/steamapps/appmanifest_949230.acf"
man() { mkdir -p "$P/steamapps"; printf '"AppState"\n{\n\t"StateFlags"\t\t"%s"\n\t"BytesToDownload"\t\t"%s"\n\t"BytesDownloaded"\t\t"%s"\n}\n' "$1" "$2" "$3" > "$M"; }
if [ -f "$ST/helper" ] && [ -s "$ST/dl" ]; then
  item="$(head -n 1 "$ST/dl")"; sed -i '' 1d "$ST/dl"
  case "$item" in
    41) man 1026 100000000000 41000000000 ;;
    zero) man 1026 0 0 ;;
    installed|installed+game) mkdir -p "$P/steamapps/common/Cities Skylines II"; : > "$P/steamapps/common/Cities Skylines II/Cities2.exe"; man 4 0 0
              [ "$item" = installed+game ] && : > "$ST/game" ;;
    quit) rm -f "$ST/steam" "$ST/helper" ;;
  esac
fi
[ -f "$ST/helper-next" ] && { rm "$ST/helper-next"; : > "$ST/helper"; }
exit 0
X
cat > "$B/pgrep" << 'X'
#!/bin/bash
case "$2" in
  *Cities2*) [ -f "$ST/game" ] && echo 99901 ;;
  steamwebhelper.exe) [ -f "$ST/helper" ] && echo 99903 ;;
  '[Ss]team\.exe') [ -f "$ST/steam" ] && echo 99902 ;;
  steam) [ -f "$ST/steam" ] && echo 99902; [ -f "$ST/helper" ] && echo 99903 ;;
esac
exit 0
X
cat > "$B/ps" << 'X'
#!/bin/bash
case "$*" in *99903*) echo 'C:\Program Files (x86)\Steam\bin\cef\cef.win7x64\steamwebhelper.exe' ;; *) echo 'C:\Program Files (x86)\Steam\steam.exe' ;; esac
X
cat > "$B/lsof" << 'X'
#!/bin/bash
case "$*" in *99901*) echo "wine64 ${STUB_GAME_OTHER:-${WINEPREFIX:-}}/drive_c/x" ;; *) echo "wine64 ${WINEPREFIX:-}/drive_c/x" ;; esac
X
cat > "$B/curl" << 'X'
#!/bin/bash
echo "CURL $*" >> "$CALLS"
out=""; url=""; while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; *) url="$1"; shift ;; esac; done
case "$url" in *fastly*) [ -n "${STUB_CURL_FIRST_FAIL:-}" ] && exit 6 ;; esac
[ -n "${STUB_CURL_FAIL:-}" ] && exit 6
cp "$FIXBIN/SteamSetup.${STUB_STEAMFILE:-good}" "$out"
X
cat > "$B/softwareupdate" << 'X'
#!/bin/bash
echo "SOFTWAREUPDATE $*" >> "$CALLS"; [ -n "${STUB_ROSETTA_STAYS_MISSING:-}" ] || : > "$ST/rosetta"
X
cat > "$B/xcode-select" << 'X'
#!/bin/bash
case "$1" in
  -p) if [ -n "${STUB_NO_TOOLS:-}" ] && [ ! -f "$ST/tools" ]; then echo "XS -p fail" >> "$CALLS"; exit 2; fi
      echo "XS -p ok" >> "$CALLS"; echo /Library/Developer/CommandLineTools ;;
  --install) echo "XS --install" >> "$CALLS"; : > "$ST/tools-pending" ;;
esac
X
printf '#!/bin/bash\necho "PY" >> "$CALLS"; exit "${STUB_PY_EXIT:-0}"\n' > "$B/python3"
printf '#!/bin/bash\necho "CAFF $*" >> "$CALLS"\n' > "$B/caffeinate"
printf '#!/bin/bash\necho "KILL $*" >> "$CALLS"; rm -f "$ST/steam" "$ST/helper"\n' > "$B/killrec"
printf '#!/bin/bash\nif [ "$1" = -u ] && [ -n "${STUB_ROOT:-}" ]; then echo 0; else exec /usr/bin/id "$@"; fi\n' > "$B/id"
printf '#!/bin/bash\necho "Filesystem 1024-blocks Used Available Capacity Mounted"\necho "/dev/x 999999999 1 ${STUB_DF_KB:-999999999} 1%% /"\n' > "$B/df"
chmod +x "$B"/* "$T/fixbin"/* "$R/cities-skylines-2/scripts"/*.sh
{ printf 'MZ'; head -c 2100000 /dev/zero; printf 'Valve Corp.'; } > "$T/fixbin/SteamSetup.good"
{ printf 'XX'; head -c 2100000 /dev/zero; printf 'Valve Corp.'; } > "$T/fixbin/SteamSetup.nomz"
{ printf 'MZ'; head -c 2100000 /dev/zero; } > "$T/fixbin/SteamSetup.novalve"
{ printf 'MZ'; head -c 1000 /dev/zero; printf 'Valve Corp.'; } > "$T/fixbin/SteamSetup.small"

# --- scenarios
n=0
newh() {   # a fresh HOME, state and call log
  n=$((n + 1)); H="$T/h$n"; mkdir -p "$H/Applications"; rm -rf "$ST"; mkdir -p "$ST"; : > "$ST/ticks"; : > "$CALLS"; : > "$ST/dl"
  WR="$H/Applications/CS2dxmt11.app"; PFX="$WR/Contents/SharedSupport/prefix"; SD="$PFX/drive_c/Program Files (x86)/Steam"
}
done_all() { bash "$MKW" "$WR" steam game 4; }     # every step done
dl() { printf '%s\n' "$@" > "$ST/dl"; }               # what the download does, one item per poll once Steam's client is up
run() {    # [install.sh arguments]: HOME=$H; output in $H.out; echoes the exit code, or "timeout"
  local p i=0
  env -u CS2_WRAPPER -u L1_TRACE -u CS2_VIA_INSTALLER HOME="$H" PATH="$B:$PATH" L1_KILL="$B/killrec" \
    bash "$S" "$@" > "$H.out" 2>&1 < /dev/null & p=$!
  while kill -0 "$p" 2>/dev/null; do i=$((i + 1)); [ "$i" -gt 900 ] && { kill "$p"; wait "$p" 2>/dev/null; echo timeout; return; }; /bin/sleep 0.1; done
  wait "$p"; echo $?
}
ptya() {   # <typed line> [install.sh arguments]: at a terminal, with <typed line> typed
  local typed="$1"; shift
  { /bin/sleep 1; printf '%s\n' "$typed"; /bin/sleep 5; } | env -u CS2_WRAPPER -u L1_TRACE -u CS2_VIA_INSTALLER HOME="$H" PATH="$B:$PATH" \
    L1_KILL="$B/killrec" script -q /dev/null bash "$S" "$@" > "$H.out" 2>&1; echo $?
}
said() { grep -c -- "$1" "$H.out"; }
calls() { grep -c -- "$1" "$CALLS"; }
starts() { cat "$ST/starts" 2>/dev/null || echo 0; }

# --- which wrapper: install.sh's choice equals the launcher's once the wrapper exists
chosen() {   # the wrapper install.sh used under --check, resolved
  local m; m="$(sed -n 's/^MAKEWRAPPER --wrapper \(.*\) --check$/\1/p' "$CALLS")"
  [ -n "$m" ] || m="$(sed -n 's/^  OK: \(.*\)$/\1/p' "$H.out" | sed "s#^~#$H#")"
  [ -d "$m" ] || bash "$MKW" "$m"
  (cd "$m" && pwd -P)
}
launchers_choice() { env -u CS2_WRAPPER HOME="$H" ${1:+CS2_WRAPPER="$1"} bash -c "$(fn find_wrapper "$LAUNCHER"); w=\"\$(find_wrapper)\"; cd \"\$w\" && pwd -P"; }
newh; run --check > /dev/null; check "wrapper rule: an empty home" "$(chosen)" "$(launchers_choice)"
newh; done_all; run --check > /dev/null; check "wrapper rule: CS2dxmt11.app" "$(chosen)" "$(launchers_choice)"
newh; bash "$MKW" "$H/Applications/CS2.app" steam game 4; run --check > /dev/null
check "wrapper rule: CS2.app with the game" "$(chosen)" "$(launchers_choice)"
check "  ...named, with ~" "$(said 'Using ~/Applications/CS2.app, which holds the game.')" 1
newh; bash "$MKW" "$H/Applications/CS2.app"; run --check > /dev/null
check "wrapper rule: CS2.app without the game: CS2dxmt11.app is made beside it" "$(chosen)" "$(launchers_choice)"
check "  ...which is CS2dxmt11.app" "$(chosen | sed 's#.*/##')" CS2dxmt11.app
newh; bash "$MKW" "$H/Applications/Other.app" steam game 4; run --check > /dev/null
check "wrapper rule: the game under another name" "$(chosen)" "$(launchers_choice)"
newh; bash "$MKW" "$H/Applications/A.app" steam game 4; bash "$MKW" "$H/Applications/B.app" steam game 4; run --check > /dev/null
check "wrapper rule: two holding the game" "$(chosen)" "$(launchers_choice)"
newh; mkdir -p "$T/my w$n"; rc="$(env -u L1_TRACE CS2_WRAPPER="$T/my w$n/X.app" HOME="$H" PATH="$B:$PATH" bash "$S" --check > "$H.out" 2>&1; echo $?)"
check "wrapper rule: CS2_WRAPPER with a space, to be made" "$rc:$(chosen)" "0:$(launchers_choice "$T/my w$n/X.app")"
newh; check "a relative CS2_WRAPPER: exit 2" "$(env CS2_WRAPPER=Applications/X.app HOME="$H" PATH="$B:$PATH" bash "$S" > "$H.out" 2>&1; echo $?)" 2
newh; bash "$MKW" "$WR"; rm "$WR/Contents/SharedSupport/wine/bin/wine64"
check "a wrapper without wine64: exit 1, nothing deleted" "$(run):$([ -d "$PFX" ] && echo kept)" "1:kept"
newh; bash "$MKW" "$WR"; rm -rf "$PFX"
check "a wrapper without a prefix folder: exit 1, nothing deleted" "$(run):$([ -d "$WR/Contents/SharedSupport/wine" ] && echo kept)" "1:kept"

# --- all done: only setup runs
newh; done_all
check "all done: exit 0" "$(run)" 0
check "  ...setup run once, with CS2_VIA_INSTALLER=1 and the wrapper" "$(grep -c "^SETUP  via=1 wrapper=$(cd "$WR" && pwd -P)\$" "$CALLS")" 1
check "  ...nothing else changed: no Steam start, no wrapper made, no download, no Rosetta, no Apple box" \
  "$(calls '^WINE '):$(calls MAKEWRAPPER):$(calls CURL):$(calls SOFTWAREUPDATE):$(calls 'XS --install')" "0:0:0:0:0"
check "  ...the Mac kept awake while it runs" "$(grep -cE '^CAFF -i -w [0-9]+$' "$CALLS")" 1
check "  ...the closing line for exit 0" "$(said '^Done. Start the game from Applications')" 1
check "  ...the lock released" "$([ -L "$PFX/.launcher.lock" ] && echo held || echo free)" free
check "  ...the home folder nowhere in the output" "$(grep -c "$H" "$H.out")" 0
newh; done_all; rc="$(STUB_SETUP_EXIT=1 run)"
check "setup fails: its exit code, and the stopped line" "$rc:$(said '^The install stopped.')" "1:1"
newh; done_all; run --yes --desktop > /dev/null
check "--yes and --desktop reach setup" "$(grep -c '^SETUP --yes --desktop via=1' "$CALLS")" 1
newh; done_all
check "--no-setup: exit 0, its own line, setup not run" "$(run --no-setup):$(said 'Stopped before step 6, as asked.'):$(grep -c '^SETUP  via' "$CALLS"):$(said '^Done.')" "0:1:0:0"

# --- guards
newh; done_all; : > "$ST/game"
check "the game running: exit 3, before step 1" "$(run):$(said 'Step 1'):$(calls '^SETUP')" "3:0:0"
newh; done_all; ln -s $$ "$PFX/.launcher.lock"
check "a live lock holder: exit 3, nothing done" "$(run):$(calls '^SETUP')" "3:0"
rm -f "$PFX/.launcher.lock"
newh; done_all
check "run as root: exit 1" "$(STUB_ROOT=1 run):$(calls '^SETUP')" "1:0"
check "a wrong option: exit 2" "$(env HOME="$H" PATH="$B:$PATH" bash "$S" --nope > /dev/null 2>&1; echo $?)" 2

# --- step 1: Rosetta
newh; done_all; rc="$(STUB_NO_ROSETTA=1 run)"
check "Rosetta missing, no terminal: exit 3, the command, softwareupdate not run" "$rc:$(said 'softwareupdate --install-rosetta --agree-to-license'):$(calls SOFTWAREUPDATE)" "3:1:0"
rc="$(STUB_NO_ROSETTA=1 ptya n)"; check "  ...n at a terminal: exit 3, not run" "$rc:$(calls SOFTWAREUPDATE)" "3:0"
: > "$CALLS"; rc="$(STUB_NO_ROSETTA=1 ptya '')"; check "  ...Return at a terminal: exit 3, not run" "$rc:$(calls SOFTWAREUPDATE)" "3:0"
: > "$CALLS"; rm -f "$ST/rosetta"; rc="$(STUB_NO_ROSETTA=1 ptya y)"
check "  ...y: softwareupdate with exactly the two options, then on to setup" "$rc:$(grep -cx 'SOFTWAREUPDATE --install-rosetta --agree-to-license' "$CALLS"):$(grep -c '^SETUP  via=1' "$CALLS")" "0:1:1"
: > "$CALLS"; rm -f "$ST/rosetta"; rc="$(STUB_NO_ROSETTA=1 run --yes)"
check "  ...--yes: installed without asking" "$rc:$(calls SOFTWAREUPDATE)" "0:1"
: > "$CALLS"; rm -f "$ST/rosetta"; rc="$(STUB_NO_ROSETTA=1 STUB_ROSETTA_STAYS_MISSING=1 run --yes)"
check "  ...still missing afterwards: exit 1" "$rc" 1

# --- step 2: Apple's Command Line Tools
newh; done_all; rc="$(STUB_NO_TOOLS=1 run)"
check "tools missing: Apple asked once, then on when they arrive" "$rc:$(calls 'XS --install'):$(grep -c '^SETUP  via=1' "$CALLS")" "0:1:1"
check "  ...python3 not run before xcode-select -p succeeds" "$(awk '/^XS -p ok/ { ok = 1 } /^PY$/ && !ok { bad = 1 } END { print bad ? "early" : "after" }' "$CALLS")" after
newh; done_all; sed -i '' 's/^TOOLS_POLLS=720 /TOOLS_POLLS=3 /' "$S"; rc="$(STUB_NO_TOOLS=1 STUB_TOOLS_NEVER=1 run)"
check "  ...they never arrive: exit 4" "$rc" 4
sed -i '' 's/^TOOLS_POLLS=3 /TOOLS_POLLS=720 /' "$S"
newh; done_all; rc="$(STUB_PY_EXIT=1 run)"
check "tools there, python3 broken: exit 1, Apple not asked" "$rc:$(calls 'XS --install')" "1:0"

# --- step 3: the wrapper
newh; done_all
check "low space: a CAUTION line, and on" "$(STUB_DF_KB=50000000 run):$(said 'CAUTION: 47 GB free')" "0:1"
newh; rc="$(STUB_MW_EXIT=1 run)"; check "make-wrapper fails: exit 1" "$rc" 1
newh; rc="$(STUB_MW_EXIT=3 run)"; check "make-wrapper finds another build at work: exit 3" "$rc" 3
newh; : > "$ST/game"; STUB_GAME_OTHER="$T/elsewhere"; export STUB_GAME_OTHER; dl installed
rc="$(run)"; unset STUB_GAME_OTHER
check "a wrapper to be made, with a game running in another wrapper: made, not taken for ours" "$rc:$(grep -c "^MAKEWRAPPER --wrapper $H/Applications/CS2dxmt11.app\$" "$CALLS")" "0:1"
# (with no prefix yet, set -u stops the copied function inside its own pipeline, so the game is not taken for
# ours either way; what the guard saves is the shell's error line in the player's Terminal)
check "  ...and no copied function was run before there was a prefix" "$(said 'unbound variable')" 0

# --- step 4: Steam
newh; bash "$MKW" "$WR"; dl installed; rc="$(run)"
check "no Steam: fetched over https from Valve, installed with /S, then on" "$rc:$(grep -c 'CURL --proto =https --tlsv1.2 -fsSL --retry 2 -o .* https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe$' "$CALLS"):$(grep -c '^WINE .*SteamSetup.exe /S dll=winemenubuilder.exe=d$' "$CALLS")" "0:1:1"
check "  ...an unknown sha256: a CAUTION line" "$(said 'CAUTION: this is a newer installer')" 1
check "  ...wineserver waited for in this prefix" "$(grep -c "^WINESERVER -w prefix=$(cd "$PFX" && pwd -P)\$" "$CALLS")" 2
newh; bash "$MKW" "$WR"; dl installed; rc="$(STUB_CURL_FIRST_FAIL=1 run)"
check "the first address fails: the second is tried" "$rc:$(grep -c 'cdn.akamai.steamstatic.com' "$CALLS")" "0:1"
for k in nomz novalve small; do
  newh; bash "$MKW" "$WR"; rc="$(STUB_STEAMFILE=$k run)"
  check "a downloaded file that fails one test ($k): exit 1, not run" "$rc:$(calls 'SteamSetup.exe /S')" "1:0"
done
newh; bash "$MKW" "$WR"; check "Steam's installer exits 1: exit 1" "$(STUB_SETUP_RC=1 run)" 1
newh; bash "$MKW" "$WR"; check "no steam.exe afterwards: exit 1" "$(STUB_SETUP_NOEXE=1 run)" 1
newh; bash "$MKW" "$WR" steam game 4; check "Steam.exe alone counts as Steam" "$(run):$(calls CURL)" "0:0"

# --- step 5: the game
newh; bash "$MKW" "$WR" steam game 6
check "an update waiting (6): its line, on to setup, Steam not started" "$(run):$(said 'Steam has a game update waiting'):$(starts):$(grep -c '^SETUP  via=1' "$CALLS")" "0:1:0:1"
newh; bash "$MKW" "$WR" steam game-nomanifest; dl installed
check "the game present with no manifest: Steam started" "$(run):$(starts)" "0:1"
newh; bash "$MKW" "$WR" steam game 1026; dl installed
check "the game present with 1026 (a download that stopped): Steam started" "$(run):$(starts)" "0:1"
newh; bash "$MKW" "$WR" steam; dl - installed; : > "$SD/.crash"
rc="$(run)"
check "a fresh start: the stale .crash gone before it, the words, -shutdown before setup" \
  "$rc:$(sed -n 1p "$ST/startlog" | sed 's/.*crash=//'):$(said 'Do not press it'):$(awk '/-shutdown/ { s = NR } /^SETUP  via=1/ { u = NR } END { print (s && u && s < u) ? "ordered" : "not" }' "$CALLS")" "0:no:1:ordered"
check "  ...no wineserver call without the prefix" "$(grep '^WINESERVER' "$CALLS" | grep -c 'prefix=$')" 0
check "  ...the lock held while it waited" "$(grep -c 'lock=yes' "$ST/ticks" | awk '{ print ($1 > 0) ? "held" : "never" }')" held
check "  ...the home folder nowhere in the output" "$(grep -c "$H" "$H.out")" 0
for k in fatal-u fatal-o; do
  newh; bash "$MKW" "$WR" steam; dl - installed
  rc="$(STUB_STARTS="$k ok" run)"
  check "a first start that ends in its fatal line ($k): ended in this prefix, started again at once" \
    "$rc:$(starts):$(grep -c "^WINESERVER -k prefix=$(cd "$PFX" && pwd -P)\$" "$CALLS" | awk '{ print ($1 > 0) }'):$(sed -n 2p "$ST/startlog" | awk '{ print ($5 <= 3) ? "soon" : "late" }')" "0:2:1:soon"
done
newh; bash "$MKW" "$WR" steam; dl - installed
check "a one-poll gap in Steam's process: not started again" "$(STUB_STARTS=blip run):$(starts)" "0:1"
newh; bash "$MKW" "$WR" steam; dl - installed
check "a three-poll gap: started again" "$(STUB_STARTS='gone ok' run):$(starts)" "0:2"
newh; bash "$MKW" "$WR" steam
rc="$(STUB_STARTS='fatal-u fatal-u fatal-u fatal-u fatal-u ok' run)"
check "five fatal starts: exit 1, five starts, Steam ended, its log shown, no setup" \
  "$rc:$(starts):$(said 'did not start after 5 tries'):$(said 'Failed to determine download location' | awk '{ print ($1 > 0) }'):$(grep -c '^SETUP  via' "$CALLS")" "1:5:1:1:0"
newh; bash "$MKW" "$WR" steam; : > "$ST/steam"; dl - installed; sed -i '' 's/^STUCK_POLLS=12 /STUCK_POLLS=2 /' "$S"
rc="$(run)"; sed -i '' 's/^STUCK_POLLS=2 /STUCK_POLLS=12 /' "$S"
check "a Steam already there with no client: ended, then started" "$rc:$(calls '^WINESERVER -k'):$(starts)" "0:1:1"
newh; bash "$MKW" "$WR" steam; dl - installed; sed -i '' 's/^START_POLLS=120 /START_POLLS=3 /' "$S"
rc="$(STUB_STARTS='slow ok' run)"; sed -i '' 's/^START_POLLS=3 /START_POLLS=120 /' "$S"
check "no client within the limit: ended and started again" "$rc:$(starts):$(calls '^WINESERVER -k' | awk '{ print ($1 > 0) }')" "0:2:1"
newh; bash "$MKW" "$WR" steam; : > "$ST/steam"; : > "$ST/helper"; dl installed
check "a client already up: not started again, straight to the words, and not said to be starting" "$(run):$(starts):$(said 'Do not press it'):$(said 'is starting'):$(said 'Steam for Windows is open.')" "0:0:1:0:1"
newh; bash "$MKW" "$WR" steam; dl - - - installed
check "no manifest yet: the choose-Install line once" "$(run):$(said '^  Waiting for you to choose Install in Steam$')" "0:1"
newh; bash "$MKW" "$WR" steam; dl - zero zero installed
check "BytesToDownload 0: the getting-ready line once, and it waits on" "$(run):$(said '^  Steam is getting the download ready$'):$(starts)" "0:1:1"
newh; bash "$MKW" "$WR" steam; dl - 41 41 installed
check "41 percent: one line for it" "$(run):$(said '41.0 of 100.0 GB (41%)')" "0:1"
newh; bash "$MKW" "$WR" steam; dl - quit
check "Steam closed during the download: exit 4, setup not run, the line for 4" "$(run):$(grep -c '^SETUP  via' "$CALLS"):$(said '^Open the installer again: it carries on from here.')" "4:0:1"
newh; bash "$MKW" "$WR" steam; dl - installed
check "-shutdown not enough: wineserver -k after it" "$(STUB_SHUTDOWN_STUCK=1 run):$(awk '/-shutdown/ { s = 1 } /^WINESERVER -k/ && s { k = 1 } END { print k ? "after" : "none" }' "$CALLS")" "0:after"
newh; bash "$MKW" "$WR" steam; dl - installed
check "a stray left after that: a plain kill, never -9" "$(STUB_SHUTDOWN_STUCK=1 STUB_WS_STUCK=1 run):$(grep -c '^KILL 99903$' "$CALLS"):$(grep -c 'KILL -9' "$CALLS")" "0:1:0"
newh; bash "$MKW" "$WR" steam; dl - installed
rc="$(env -u CS2_WRAPPER HOME="$H" PATH="$B:$PATH" L1_KILL="$B/killrec" L1_TRACE="$T/trace$n" bash "$S" > "$H.out" 2>&1 < /dev/null; echo $?)"
check "L1_TRACE: a line per poll" "$rc:$(grep -cE '^[0-9]{2}:[0-9]{2}:[0-9]{2} steam=[0-9]+ proc=(yes|no) client=' "$T/trace$n" | awk '{ print ($1 >= 2) ? "lines" : "few" }')" "0:lines"

# --- stopped by a signal while it waits (Control-C sends INT; a background job cannot be sent INT, so TERM and HUP)
for sig in TERM HUP; do
  newh; bash "$MKW" "$WR" steam; : > "$ST/steam"; : > "$ST/helper"
  env -u CS2_WRAPPER -u L1_TRACE HOME="$H" PATH="$B:$PATH" L1_KILL="$B/killrec" bash "$S" > "$H.out" 2>&1 < /dev/null & ip=$!
  i=0; until grep -q 'Waiting for you to choose Install' "$H.out" 2>/dev/null || [ "$i" -gt 100 ]; do /bin/sleep 0.1; i=$((i + 1)); done
  kill -"$sig" "$ip"; wait "$ip"; rc=$?
  check "stopped by $sig while it waits: its own line, not Done, the lock released, Steam left running" \
    "$(said '^Stopped. Open the installer again'):$(said '^Done.'):$([ -L "$PFX/.launcher.lock" ] && echo held || echo free):$([ -f "$ST/steam" ] && echo up):$(calls '^WINESERVER -k')" "1:0:free:up:0"
  check "  ...and a signal's exit code" "$rc" "$([ "$sig" = TERM ] && echo 143 || echo 129)"
done

# --- step 6
newh; bash "$MKW" "$WR" steam; dl - installed+game
check "the game started during the wait: exit 3 at step 6, setup not run" "$(run):$(grep -c '^SETUP  via' "$CALLS")" "3:0"
newh; done_all; mv "$R/cities-skylines-2/repatch.sh" "$T/repatch.away"
check "the checkout's files gone: exit 4, setup not run" "$(run):$(grep -c '^SETUP  via' "$CALLS")" "4:0"
mv "$T/repatch.away" "$R/cities-skylines-2/repatch.sh"

# --- --check
newh; done_all
check "--check: exit 0, no closing line, nothing changed" \
  "$(run --check):$(said '^Done.'):$(calls '^WINE'):$(calls '^WINESERVER'):$(calls CURL):$(calls SOFTWAREUPDATE):$(calls CAFF):$(calls 'XS --install')" "0:0:0:0:0:0:0:0"
check "  ...setup only as --mac-only --check" "$(calls '^SETUP'):$(calls '^SETUP --mac-only --check')" "1:1"
newh; bash "$MKW" "$WR" steam
check "--check with the game not installed: Steam not started" "$(run --check):$(calls '^WINE'):$(said 'would start Steam')" "0:0:1"
newh; done_all
check "--check with the tools missing: python3 not run" "$(STUB_NO_TOOLS=1 run --check):$(calls '^PY$'):$(said 'would ask Apple')" "0:0:1"
newh; done_all
check "--check with Rosetta missing: reported, exit 0" "$(STUB_NO_ROSETTA=1 run --check):$(said 'would offer to install it'):$(calls SOFTWAREUPDATE)" "0:1:0"
newh
check "--check on an empty home: make-wrapper asked only to check" "$(run --check):$(grep -c '^MAKEWRAPPER' "$CALLS"):$(grep -c '^MAKEWRAPPER --wrapper .* --check$' "$CALLS")" "0:1:1"
check "--help prints the usage" "$(bash "$S" --help | grep -c 'exit 0 = done')" 1

check "no run reached the runaway guard" "$(cat "$T/runaway" 2>/dev/null | wc -l | tr -d ' ')" 0
echo "$fails failure(s)"
[ "$fails" = 0 ]
