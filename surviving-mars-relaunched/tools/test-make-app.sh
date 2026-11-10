#!/bin/bash
# test-make-app.sh -- make-app.sh builds the double-click app with the shared progress panel, and the app runs
# the launcher it was given, once. Its shim starts the panel once, after the ===== line, tells the launcher
# whether a window is up, stops only its own panel and only while it is alive, and shows one alert for one
# failure. Fake launchers that print their version and what they were told, then sleep one second; HOME in a
# temp dir so the shim's log lands there; a stub pgrep and a recording osascript first on PATH, so no game is
# looked for and no alert is shown. The compiled panel is only asked to --parse, then REPLACED by a recording
# stub before any shim runs: the real one would open a window, and a shim is refused here while its app holds
# anything but a stub. No game, no Steam. The app pulls nothing at launch (unification plan, O3).
# Then what the 14unch3r window reads (docs/plans/launcher-window.md, 2.1, W5), every key read with plutil:
# the role, the app id, the alternate names, the prefix of a fixture wrapper; a failing plutil; a target given
# with a trailing slash; and the own-bundle test, which refuses anything at the target this builder did not
# make. Every build is given SM_GAME_EXE in the scratch folder, so no real game path is read or recorded.
#   bash tools/test-make-app.sh            exit 0 = every case passed
#   MUTANT=1 bash tools/test-make-app.sh   the built shim never runs its launcher; must exit 1
#   MUTANT=2 ...   the shim says a window is up whether or not its process is alive; must exit 1
#   MUTANT=3 ...   the panel is stopped by a plain kill of its PID (a stranger's, hours later); must exit 1
#   MUTANT=4 ...   the panel is stopped by pkill -f (the other game's window goes too); must exit 1
#   MUTANT=5 ...   the panel is started before the ===== line (it reads the last session); must exit 1
#   MUTANT=6 ...   the title is passed to the panel as an argument; must exit 1
#   MUTANT=7 ...   the builder compiles outside an `if` (under set -e a failed compile leaves half an app); must exit 1
#   MUTANT=8 ...   the shim alerts on every failure (two alerts for one die); must exit 1
#   MUTANT=9 ...   the shim looks for ERROR: in the whole log (an old failure silences a new one); must exit 1
#   MUTANT=10 ...  the builder writes the other game's app id; must exit 1
#   MUTANT=11 ...  the builder drops L1Role; must exit 1
#   MUTANT=12 ...  the own-bundle test is dropped (whatever is at the target is removed); must exit 1
#   MUTANT=13 ...  SM_GAME_EXE is ignored (the real game path is recorded); must exit 1
#   MUTANT=14 ...  a failed plutil is ignored; must exit 1
#   MUTANT=15 ...  a trailing slash is left on SM_APP (rm -rf of link.app/ empties the bundle it points at); must exit 1
#   MUTANT=16 ...  the hint to build 14unch3r is printed even when 14unch3r.app is beside the app; must exit 1
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
MAKE="$HERE/make-app.sh"
T="$(mktemp -d /tmp/make-app-test.XXXX)"
PIDS="$T/pids"; CALLS="$T/panel.calls"; KILLS="$T/kills"; OSA="$T/osascript.calls"
cleanup() {   # stop what the stub panels left, and only those: a recorded PID may be someone else's by now
  local p; for p in $(cat "$PIDS" "$T/other.pids" 2>/dev/null); do
    case "$(ps -o command= -p "$p" 2>/dev/null)" in *"$T"*) kill "$p" 2>/dev/null ;; esac
  done
  rm -rf "$T"
}
trap cleanup EXIT
M="${MUTANT:-0}"
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
case "$M" in 0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16) ;; *) echo "REFUSED: no mutant $M"; exit 2 ;; esac
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

mkdir -p "$T/bin" "$T/noswift" "$T/badswift" "$T/Library/Logs"
printf '#!/bin/bash\nexit 1\n' > "$T/bin/pgrep"
printf '#!/bin/bash\necho "$*" >> "%s"\n' "$OSA" > "$T/bin/osascript"
printf '#!/bin/bash\nexit 1\n' > "$T/noswift/xcrun"                                    # no swiftc on this Mac
printf '#!/bin/bash\n[ "$1" = -f ] && { echo /stub/swiftc; exit 0; }\nexit 1\n' > "$T/badswift/xcrun"   # swiftc is there, the compile fails
chmod +x "$T/bin"/* "$T/noswift/xcrun" "$T/badswift/xcrun"
: > "$OSA"; : > "$KILLS"; : > "$CALLS"

# fake launchers: their version, what the shim told them, one second of "work", then FAKE_ERROR as a die and
# FAKE_RC as the exit
launcher() {   # <file> [noblock]: with the line the builder looks for, or as an older launcher without it
  { echo '#!/bin/bash'
    [ "${2:-}" = noblock ] || echo '# >>> launch-feedback (a fake launcher: the builder looks for this line)'
    echo 'echo "LAUNCHED v1"'
    echo 'echo "TOLD quiet=${SM_QUIET:-unset} panel=${SM_PANEL:-unset}"'
    echo 'sleep 1'
    echo '[ -n "${FAKE_ERROR:-}" ] && echo "ERROR: $FAKE_ERROR"'
    echo 'exit "${FAKE_RC:-0}"'
  } > "$1"
}
launcher "$T/launch-relaunched.sh"; launcher "$T/old-launcher.sh" noblock

# stub panels, in place of the compiled one. Each records how it was started; `headers` is the number of
# ===== lines the log held at that moment: 1 in a fresh log when the shim wrote its line first, 0 when not.
stub() {   # <app> stays|quits|brief: up until stopped, gone at once, or alive at the shim's check and gone 0.6 s in
  local p="$1/Contents/Resources/launch-progress" tail
  case "$2" in stays) tail='while :; do sleep 0.2; done' ;; quits) tail='exit 0' ;; brief) tail='sleep 0.6; exit 0' ;; esac
  cat > "$p" <<EOF
#!/bin/bash
# stub panel ($2)
echo "\$\$" >> "$PIDS"
echo "PANEL args=\$# title=\${LP_TITLE:-unset} log=\${LP_LOG:-unset} headers=\$(grep -c '^===== ' "\${LP_LOG:-/dev/null}" 2>/dev/null)" >> "$CALLS"
$tail
EOF
  chmod +x "$p"
}
build() {   # <app> <launcher> [PATH prefix]: output in <app>.make. The game is looked for in the scratch folder
  PATH="${3:+$3:}$T/bin:$PATH" SM_APP="$1" SM_SCRIPT="$2" SM_GAME_EXE="$T/absent/Mars.exe" bash "$MAKE" > "$1.make" 2>&1
}
run() {   # <app> [NAME=value ...]: its shim with a scratch HOME, the stubs first on PATH and every kill it sends recorded
  local app="$1" p; shift
  p="$app/Contents/Resources/launch-progress"
  [ ! -e "$p" ] || grep -q '^# stub panel' "$p" || { echo "REFUSED: $p is not a stub: the real panel would open a window"; exit 2; }
  : > "$CALLS"; : > "$KILLS"; : > "$OSA"
  env "$@" HOME="$T" PATH="$T/bin:$PATH" REC="$KILLS" SHIM="$app/Contents/MacOS/launch" \
    /bin/bash -c 'kill() { echo "KILL $*" >> "$REC"; builtin kill "$@"; }; export -f kill; exec "$SHIM"' > "$T/shim.out" 2>&1
}
alive() { local p; for p in $(cat "$1" 2>/dev/null); do kill -0 "$p" 2>/dev/null && return 0; done; return 1; }
log="$T/Library/Logs/sm-relaunched-launcher.log"
told() { grep '^TOLD ' "$log" | tail -1; }
lines() { wc -l < "$1" | tr -d ' '; }
complete() { [ -x "$1/Contents/MacOS/launch" ] && [ -s "$1/Contents/Info.plist" ] && echo complete; }

# a scratch copy of the builder, laid out as in the repo so that it finds common/ (or, with `nocommon`, does not)
scratch_builder() {   # <dir> [nocommon]
  mkdir -p "$1/surviving-mars-relaunched"; cp "$HERE/make-app.sh" "$1/surviving-mars-relaunched/"
  [ "${2:-}" = nocommon ] || { mkdir -p "$1/common"; cp "$TOP/common/launch-progress.swift" "$1/common/"; }
}
case "$M" in 7|10|11|12|13|14|15|16) scratch_builder "$T/mut"; MAKE="$T/mut/surviving-mars-relaunched/make-app.sh" ;; esac
case "$M" in
  7) sed -i '' 's/^elif ! xcrun swiftc \(.*\); then PANEL_WHY="the compile failed".*$/else xcrun swiftc \1/' "$MAKE"
     grep -q '^else xcrun swiftc -O -o "\$PANEL_OUT" "\$PANEL_SRC" >/dev/null 2>&1$' "$MAKE" || mutated ;;
  10) sed -i '' 's|<integer>3215050</integer>|<integer>949230</integer>|' "$MAKE"; grep -q '<integer>949230</integer>' "$MAKE" || mutated ;;
  11) sed -i '' '/<key>L1Role<\/key>/d' "$MAKE"; grep -q '<key>L1Role</key>' "$MAKE" && mutated ;;
  12) sed -i '' 's/^  \[ -e "\$t" \] || \[ -L "\$t" \] || return 0$/  return 0/' "$MAKE"; grep -q '|| return 0$' "$MAKE" && mutated ;;
  13) sed -i '' 's|^GAME_EXE="\${SM_GAME_EXE:-\(.*\)}"$|GAME_EXE="\1"|' "$MAKE"; grep -q 'SM_GAME_EXE:-' "$MAKE" && mutated ;;
  14) sed -i '' 's/^not_built() { .*/not_built() { return 0; }/' "$MAKE"; grep -q '^not_built() { return 0; }$' "$MAKE" || mutated ;;
  15) sed -i '' '/# tested as the bundle it names$/d' "$MAKE"; grep -q 'APP="\${APP%/}"' "$MAKE" && mutated ;;
  16) sed -i '' 's|^if \[ ! -d "\$WHERE/14unch3r.app" \]; then$|if true; then|' "$MAKE"; grep -q '^if true; then$' "$MAKE" || mutated ;;
esac

# --- the builder
APP="$T/App.app"; SHIM="$APP/Contents/MacOS/launch"; PANEL="$APP/Contents/Resources/launch-progress"
build "$APP" "$T/launch-relaunched.sh"
check "make-app.sh builds the app" "$?:$([ -x "$SHIM" ] && echo shim)" "0:shim"
if xcrun -f swiftc >/dev/null 2>&1; then
  check "the builder compiled the shared panel into the app, and says so" "$([ -x "$PANEL" ] && echo yes):$(grep -c '^progress: Swift panel built' "$APP.make")" "yes:1"
  printf '===== x =====\n[2/5] two\n' > "$T/fixture.log"
  check "  ...and it is the shared one (--parse answers)" "$("$PANEL" --parse "$T/fixture.log" 2>&1)" "2 5 two"
else
  check "no swiftc on this Mac: the builder says the panel was skipped" "$([ -e "$PANEL" ] && echo built):$(grep -c '^progress: skipped (swiftc is missing' "$APP.make")" ":1"
fi
case "$M" in
  1) sed -i '' 's|^SM_QUIET=1 SM_PANEL=$PANEL bash "$SCRIPT"|SM_QUIET=1 SM_PANEL=$PANEL true "$SCRIPT"|' "$SHIM"
     grep -q '^SM_QUIET=1 SM_PANEL=$PANEL true "$SCRIPT"' "$SHIM" || mutated ;;
  2) sed -i '' 's/then PANEL=1; else PANEL_PID=""; fi$/then PANEL=1; else PANEL=1; PANEL_PID=""; fi/' "$SHIM"; grep -q 'else PANEL=1; PANEL_PID=""; fi$' "$SHIM" || mutated ;;
  3) sed -i '' 's/^stop_panel() { .*/stop_panel() { [ -n "$PANEL_PID" ] \&\& kill "$PANEL_PID" 2>\/dev\/null; return 0; }/' "$SHIM"; grep -q '^stop_panel() { \[ -n "\$PANEL_PID" \] && kill "\$PANEL_PID" 2>/dev/null; return 0; }$' "$SHIM" || mutated ;;
  4) sed -i '' "s/^stop_panel() { .*/stop_panel() { pkill -f 'Resources\/launch-progress' 2>\/dev\/null; return 0; }/" "$SHIM"; grep -q "^stop_panel() { pkill -f 'Resources/launch-progress'" "$SHIM" || mutated ;;
  5) awk '/^\{ echo; echo "===== / { h = $0; next } /^SM_QUIET=1 / { print h } { print }' "$SHIM" > "$SHIM.new" && cat "$SHIM.new" > "$SHIM" && rm "$SHIM.new"
     [ "$(grep -n '^{ echo; echo "===== ' "$SHIM" | cut -d: -f1)" -gt "$(grep -n '^PANEL=0; PANEL_PID=""$' "$SHIM" | cut -d: -f1)" ] || mutated ;;
  6) sed -i '' 's/^  LP_TITLE="Surviving Mars: Relaunched" LP_LOG="\$LOG" "\$PROGRESS" >/  LP_LOG="$LOG" "$PROGRESS" "Surviving Mars: Relaunched" >/' "$SHIM"; grep -q '^  LP_LOG="\$LOG" "\$PROGRESS" "Surviving Mars: Relaunched" >' "$SHIM" || mutated ;;
  8) sed -i '' 's/^if \[ \$rc -ne 0 \] && ! awk .*; then$/if [ $rc -ne 0 ]; then/' "$SHIM"; grep -q '^if \[ \$rc -ne 0 \]; then$' "$SHIM" || mutated ;;
  9) sed -i '' "s/^if \[ \\\$rc -ne 0 \] && ! awk .*; then\$/if [ \$rc -ne 0 ] \&\& ! grep -q '^ERROR:' \"\$LOG\"; then/" "$SHIM"; grep -q "^if \[ \$rc -ne 0 \] && ! grep -q '^ERROR:' \"\$LOG\"; then\$" "$SHIM" || mutated ;;
esac

skipped() {   # <case> <app> <exit code> <reason wanted>: the builder exits 0, the app is complete, no panel, the reason is printed
  check "$1: the builder exits 0, the app is complete, there is no panel, and the reason is printed" \
    "$3:$(complete "$2"):$([ -e "$2/Contents/Resources/launch-progress" ] && echo panel):$(grep -c "^progress: skipped ($4" "$2.make")" "0:complete::1"
}
build "$T/NoSwift.app" "$T/launch-relaunched.sh" "$T/noswift"
skipped "no swiftc" "$T/NoSwift.app" $? "swiftc is missing"
build "$T/BadSwift.app" "$T/launch-relaunched.sh" "$T/badswift"
skipped "the compile fails" "$T/BadSwift.app" $? "the compile failed"
build "$T/Old.app" "$T/old-launcher.sh"
skipped "a launcher with no launch-feedback block" "$T/Old.app" $? "the launcher prints no step lines"
scratch_builder "$T/nocommon" nocommon
PATH="$T/bin:$PATH" SM_APP="$T/NoSource.app" SM_SCRIPT="$T/launch-relaunched.sh" bash "$T/nocommon/surviving-mars-relaunched/make-app.sh" > "$T/NoSource.app.make" 2>&1
skipped "the source is missing" "$T/NoSource.app" $? "common/launch-progress.swift is missing"

# --- the shim and a panel that stays up. Another app's panel runs beside it, as the other game's would.
mkdir -p "$T/other/Other.app/Contents/Resources"; stub "$T/other/Other.app" stays
"$T/other/Other.app/Contents/Resources/launch-progress" & disown
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$PIDS" ] && break; sleep 0.1; done
cp "$PIDS" "$T/other.pids"; : > "$PIDS"
check "(the other game's stub panel is running)" "$(alive "$T/other.pids" && echo running)" running
stub "$APP" stays
: > "$log"
run "$APP"; rc=$?
check "the app runs the launcher it was given, once, and exits 0" "$rc:$(grep -c '^LAUNCHED v1$' "$log")" "0:1"
check "the panel is started once, after the ===== line, title and log in its environment, no arguments" "$(cat "$CALLS")" "PANEL args=0 title=Surviving Mars: Relaunched log=$log headers=1"
check "the launcher is told the window is up" "$(told)" "TOLD quiet=1 panel=1"
sleep 0.5
check "the panel was alive when the launcher returned: it is stopped (at least one kill), and gone" "$([ "$(lines "$KILLS")" -ge 1 ] && echo killed):$(alive "$PIDS" && echo running || echo gone)" "killed:gone"
check "the other game's panel is still running when this shim returns" "$(alive "$T/other.pids" && echo running || echo gone)" running
check "no alert, no notification" "$(lines "$OSA")" 0

# --- a panel that is gone at once, one that ends before the launcher returns, and none
: > "$PIDS"; stub "$APP" quits
run "$APP"
check "a panel that exits at once: the launcher is told there is no window, and nothing is killed" "$(told):$(lines "$CALLS"):$(lines "$KILLS")" "TOLD quiet=1 panel=0:1:0"
stub "$APP" brief
run "$APP"
check "a panel that ended before the launcher returned: it was up, and nothing is killed" "$(told):$(lines "$KILLS")" "TOLD quiet=1 panel=1:0"
rm -f "$PANEL"
run "$APP"
check "no panel file: the launcher is told there is no window and nothing is started" "$(told):$(lines "$CALLS"):$(lines "$KILLS")" "TOLD quiet=1 panel=0:0:0"

# --- one alert for one failure
: > "$log"
run "$APP" FAKE_ERROR=x FAKE_RC=1; rc=$?
check "a launcher that dies with ERROR: its exit code, and no alert from the shim" "$rc:$(grep -c 'Launch failed' "$OSA")" "1:0"
run "$APP" FAKE_RC=1; rc=$?
check "a launcher that exits 1 in silence, after a session that held ERROR:: one alert" "$rc:$(grep -c 'Launch failed (exit 1)' "$OSA")" "1:1"
: > "$log"
run "$APP" FAKE_RC=3; rc=$?
check "the same in a fresh log: its exit code, one alert" "$rc:$(grep -c 'Launch failed (exit 3)' "$OSA")" "3:1"

# --- what the 14unch3r window reads (docs/plans/launcher-window.md, 2.1; W5). Built without swiftc, from a
# scratch working folder. Keys are read by plutil, never by grepping the plist, which plutil rewrites whole.
mkdir -p "$T/cwd" "$T/badplutil"
printf '#!/bin/bash\nexit 1\n' > "$T/badplutil/plutil"; chmod +x "$T/badplutil/plutil"   # every plutil call fails
mk() {   # <SM_APP as given> [game exe]: the builder, output in $T/mk.out; prints its exit code
  ( cd "$T/cwd" && PATH="${PRE:+$PRE:}$T/noswift:$T/bin:$PATH" SM_APP="$1" SM_SCRIPT="$T/launch-relaunched.sh" \
      SM_GAME_EXE="${2:-$T/absent/Mars.exe}" bash "$MAKE" ) > "$T/mk.out" 2>&1
  echo $?
}
key() { plutil -extract "$2" raw "$1/Contents/Info.plist" 2>/dev/null || echo "(none)"; }
appid() { plutil -extract L1SteamAppID raw -expect integer "$1/Contents/Info.plist" 2>/dev/null || echo "(no integer)"; }
alts() {   # <app>: how many alternate names, then each, joined by |
  local pl="$1/Contents/Info.plist" n i out
  n=$(plutil -extract CFBundleAlternateNames raw -expect array "$pl" 2>/dev/null) || { echo "(none)"; return; }
  out="$n"; i=0
  while [ "$i" -lt "$n" ]; do out="$out|$(plutil -extract "CFBundleAlternateNames.$i" raw "$pl" 2>/dev/null)"; i=$((i + 1)); done
  echo "$out"
}
lints() { plutil -lint "$1/Contents/Info.plist" >/dev/null 2>&1 && echo lints; }
said() { grep -c -F -x -e "$1" "$T/mk.out"; }
snap() {   # <bundle>: names, file contents and link targets under it, as one short hash; "gone" when it is not there
  [ -d "$1" ] || { echo gone; return; }
  ( cd "$1" && { find . | LC_ALL=C sort; find . -type f -exec shasum {} + | LC_ALL=C sort; find . -type l -exec readlink {} +; } ) | shasum | cut -c1-12
}
GP="drive_c/Program Files (x86)/Steam/steamapps/common/Project Spark/Mars.exe"
mkdir -p "$T/fx/SM.app/Contents/SharedSupport/prefix" "$T/fx/A&B.app/Contents/SharedSupport/prefix" \
         "$T/fx/Old.app/Contents/SharedSupport/prefix-old" "$T/cwd/rel.app/Contents/SharedSupport/prefix"

G="$T/fx/SM.app/Contents/SharedSupport/prefix/$GP"
rc=$(mk "$T/k/Keys.app" "$G"); A="$T/k/Keys.app"
check "built with a fixture wrapper's game path: exit 0, and the plist lints" "$rc:$(lints "$A")" "0:lints"
check "  ...L1Role is game" "$(key "$A" L1Role)" game
check "  ...L1SteamAppID is this game's, stored as an integer" "$(appid "$A")" 3215050
check "  ...its three alternate names" "$(alts "$A")" "3|Surviving Mars|Surviving Mars: Relaunched|SMR"
check "  ...L1Prefix is the fixture wrapper's prefix" "$(key "$A" L1Prefix)" "$T/fx/SM.app/Contents/SharedSupport/prefix"
check "  ...the shim looks for the game SM_GAME_EXE named" "$(sed -n 's/^GAME_EXE="\(.*\)"$/\1/p' "$A/Contents/MacOS/launch")" "$G"
check "  ...and neither the plist nor the shim records a path in the real home folder" "$(cat "$A/Contents/Info.plist" "$A/Contents/MacOS/launch" | grep -c -F "$HOME/")" 0
rc=$(mk "$T/k/Amp.app" "$T/fx/A&B.app/Contents/SharedSupport/prefix/$GP")
check "a prefix holding & survives, and the plist lints" "$rc:$(key "$T/k/Amp.app" L1Prefix):$(lints "$T/k/Amp.app")" "0:$T/fx/A&B.app/Contents/SharedSupport/prefix:lints"
noprefix() {   # <case> <game path>: built, and no L1Prefix
  rc=$(mk "$T/k/NoPrefix.app" "$2")
  check "$1: built, and no L1Prefix" "$rc:$(key "$T/k/NoPrefix.app" L1Prefix)" "0:(none)"
}
noprefix "the prefix folder is missing" "$T/fx/Gone.app/Contents/SharedSupport/prefix/$GP"
noprefix "the game path has no prefix segment" "$T/absent/Mars.exe"
noprefix "the game path runs through .../prefix-old/..." "$T/fx/Old.app/Contents/SharedSupport/prefix-old/$GP"
noprefix "the game path is relative, its folder there" "rel.app/Contents/SharedSupport/prefix/$GP"

rc=$(PRE="$T/badplutil" mk "$T/pl/Fails.app")
check "every plutil call fails: the error line, no bundle left, exit 1" "$rc:$(said "ERROR: $T/pl/Fails.app/Contents/Info.plist is not a valid property list; the app was not built"):$([ -e "$T/pl/Fails.app" ] && echo left)" "1:1:"

mk "$T/proto/Proto.app" > /dev/null; PROTO="$T/proto/Proto.app"   # an app of this builder's, copied wherever one is needed
own_copy() { mkdir -p "$(dirname "$1")"; cp -R "$PROTO" "$1"; : > "$1/Contents/Resources/keep"; }
fake() {   # <bundle> <marker line> <identifier> [wrapper|shimlink]: shaped like this builder's app, or nearly
  local b="$1" i=2
  mkdir -p "$b/Contents/MacOS" "$b/Contents/Resources"
  { echo '#!/bin/bash'; while [ "$i" -lt "$2" ]; do echo "# line $i"; i=$((i + 1)); done
    echo '# Generated by surviving-mars-relaunched/make-app.sh -- re-run that instead of editing this file.'; } > "$b/Contents/MacOS/launch"
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>%s</string></dict></plist>\n' "$3" > "$b/Contents/Info.plist"
  : > "$b/Contents/Resources/keep"
  case "${4:-}" in
    wrapper) mkdir -p "$b/Contents/SharedSupport/prefix" ;;
    shimlink) mv "$b/Contents/MacOS/launch" "$b/Contents/MacOS/launch.real"; ln -s launch.real "$b/Contents/MacOS/launch" ;;
  esac
}
refused() {   # <case> <target as given> <the bundle it names>: exit 1, both lines said, the bundle untouched
  local before
  before=$(snap "$3")
  rc=$(mk "$2")
  check "$1: refused with exit 1, both lines said, untouched" "$rc:$(said "ERROR: $3 exists and was not built by this script; nothing removed")$(said 'If it is a leftover of this script, move it to the Trash and run this again.'):$(snap "$3")" "1:11:$before"
}
ID=local.sm-patch.relaunched.launcher
fake "$T/own/Wrapper.app" 2 "$ID" wrapper;      refused "a wrapper-shaped bundle (Contents/SharedSupport)" "$T/own/Wrapper.app" "$T/own/Wrapper.app"
fake "$T/own/OtherID.app" 2 local.someone.else; refused "a bundle with another identifier" "$T/own/OtherID.app" "$T/own/OtherID.app"
fake "$T/own/Line11.app" 11 "$ID";              refused "a bundle whose marker is on line 11" "$T/own/Line11.app" "$T/own/Line11.app"
fake "$T/own/ShimLink.app" 2 "$ID" shimlink;    refused "a bundle whose shim is a symlink" "$T/own/ShimLink.app" "$T/own/ShimLink.app"
own_copy "$T/elsewhere/Real.app"; ln -s "$T/elsewhere/Real.app" "$T/own/Link.app"
refused "a symlink to a bundle of this builder's" "$T/own/Link.app" "$T/own/Link.app"
check "  ...it is still a symlink" "$([ -L "$T/own/Link.app" ] && echo link)" link
refused "the same symlink given with a trailing slash" "$T/own/Link.app/" "$T/own/Link.app"
check "  ...it is still a symlink, and the bundle it points at is whole" "$([ -L "$T/own/Link.app" ] && echo link):$([ -e "$T/elsewhere/Real.app/Contents/Resources/keep" ] && echo whole)" link:whole
replaced() {   # <case> <target as given> <the bundle it names>: exit 0, a complete app, the old one's extra file gone
  rc=$(mk "$2")
  check "$1 is replaced" "$rc:$(complete "$3"):$([ -e "$3/Contents/Resources/keep" ] && echo old)" "0:complete:"
}
own_copy "$T/own/Again.app";       replaced "a bundle this builder made" "$T/own/Again.app" "$T/own/Again.app"
fake "$T/own/Line10.app" 10 "$ID"; replaced "a bundle of this builder's shape with its marker on line 10" "$T/own/Line10.app" "$T/own/Line10.app"
own_copy "$T/own/Slash.app";       replaced "a bundle of this builder's given with a trailing slash" "$T/own/Slash.app/" "$T/own/Slash.app"
check "  ...and it was built in place, not inside itself" "$([ -e "$T/own/Slash.app/Slash.app" ] && echo nested)" ""

# --- the hint to build 14unch3r (docs/plans/launcher-window.md, 2.3; W11)
mkdir -p "$T/w11"
build "$T/w11/Hint.app" "$T/launch-relaunched.sh"
check "no 14unch3r.app beside the app: the last line says how to build it, with --dest for this folder" \
  "$(tail -1 "$T/w11/Hint.app.make" | grep -c "^14unch3r: not in $T/w11\. .*bash common/make-launcher-app.sh --dest \"$T/w11\"$")" 1
mkdir -p "$T/w11/14unch3r.app"
build "$T/w11/Hint.app" "$T/launch-relaunched.sh"
check "14unch3r.app beside the app: no such line" "$(grep -c 'make-launcher-app' "$T/w11/Hint.app.make")" 0

echo "$fails failure(s)"
[ "$fails" = 0 ]
