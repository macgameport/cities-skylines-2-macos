#!/bin/bash
# test-make-shortcut.sh -- make-shortcut.sh builds the double-click app with the shared progress panel, and the
# app's shim starts that panel once, after the ===== line, tells the launcher whether a window is up, stops
# only its own panel and only while it is alive, and shows one alert for one failure. Apps are built into a
# scratch folder around fake launchers that sleep one second. HOME is a scratch folder, so the shim's log
# lands there; a stub pgrep and a recording osascript come first on PATH, so the real game is never looked
# for or brought forward and no alert is shown. The compiled panel is only asked to --parse, then REPLACED
# by a recording stub before any shim runs: the real one would open a window, and a shim is refused here
# while its app holds anything but a stub. No game, no Steam, no Wine.
# Then what the 14unch3r window reads (docs/plans/launcher-window.md, 2.1, W5), every key read with plutil:
# the role, the app id, the alternate names, the prefix of a fixture wrapper; a --name full of shell and
# plist characters; the names refused before anything is removed; a failing plutil; and the own-bundle test,
# which refuses anything at the target this builder did not make. Every target is in the scratch folder.
#   bash scripts/test-make-shortcut.sh            exit 0 = every case passed
#   MUTANT=1 ...   the shim says a window is up whether or not its process is alive; must exit 1
#   MUTANT=2 ...   the panel is stopped by a plain kill of its PID (a stranger's, hours later); must exit 1
#   MUTANT=3 ...   the panel is stopped by pkill -f (the other game's window goes too); must exit 1
#   MUTANT=4 ...   the panel is started before the ===== line (it reads the last session); must exit 1
#   MUTANT=5 ...   the title is passed to the panel as an argument; must exit 1
#   MUTANT=6 ...   the builder drops ${HUD_ENV} from the shim (--hud does nothing); must exit 1
#   MUTANT=7 ...   the shim alerts on every failure (two alerts for one die); must exit 1
#   MUTANT=8 ...   the shim looks for ERROR: in the whole log (an old failure silences a new one); must exit 1
#   MUTANT=9 ...   the builder writes the other game's app id; must exit 1
#   MUTANT=10 ...  the name is written into the plist heredoc, not by plutil; must exit 1
#   MUTANT=11 ...  the builder drops L1Role; must exit 1
#   MUTANT=12 ...  the own-bundle test is dropped (whatever is at the target is removed); must exit 1
#   MUTANT=13 ...  the name is checked after the old app was removed; must exit 1
#   MUTANT=14 ...  a failed plutil is ignored; must exit 1
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TOP="$(cd "$REPO/.." && pwd)"
MAKE="$REPO/scripts/make-shortcut.sh"
T="$(mktemp -d /tmp/make-shortcut-test.XXXX)"
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
case "$M" in 0|1|2|3|4|5|6|7|8|9|10|11|12|13|14) ;; *) echo "REFUSED: no mutant $M"; exit 2 ;; esac
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

mkdir -p "$T/bin" "$T/noswift" "$T/badswift" "$T/home"
printf '#!/bin/bash\nexit 1\n' > "$T/bin/pgrep"
printf '#!/bin/bash\necho "$*" >> "%s"\n' "$OSA" > "$T/bin/osascript"
printf '#!/bin/bash\nexit 1\n' > "$T/noswift/xcrun"                                    # no swiftc on this Mac
printf '#!/bin/bash\n[ "$1" = -f ] && { echo /stub/swiftc; exit 0; }\nexit 1\n' > "$T/badswift/xcrun"   # swiftc is there, the compile fails
chmod +x "$T/bin"/* "$T/noswift/xcrun" "$T/badswift/xcrun"
: > "$OSA"; : > "$KILLS"; : > "$CALLS"

# fake launchers: what the shim told them, one second of "work", then FAKE_ERROR as a die and FAKE_RC as the exit
launcher() {   # <file> [noblock]: with the line the builder looks for, or as an older launcher without it
  { echo '#!/bin/bash'
    [ "${2:-}" = noblock ] || echo '# >>> launch-feedback (a fake launcher: the builder looks for this line)'
    echo 'echo "LAUNCHED quiet=${CS2_QUIET:-unset} panel=${CS2_PANEL:-unset} hud=${CS2_HUD:-unset}"'
    echo 'sleep 1'
    echo '[ -n "${FAKE_ERROR:-}" ] && echo "ERROR: $FAKE_ERROR"'
    echo 'exit "${FAKE_RC:-0}"'
  } > "$1"
}
launcher "$T/launcher.sh"; launcher "$T/old-launcher.sh" noblock

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
mutate_shim() {   # <shim>: the shim-level mutants, applied to the file the builder wrote
  local s="$1"
  case "$M" in
    1) sed -i '' 's/then PANEL=1; else PANEL_PID=""; fi$/then PANEL=1; else PANEL=1; PANEL_PID=""; fi/' "$s"; grep -q 'else PANEL=1; PANEL_PID=""; fi$' "$s" || mutated ;;
    2) sed -i '' 's/^stop_panel() { .*/stop_panel() { [ -n "$PANEL_PID" ] \&\& kill "$PANEL_PID" 2>\/dev\/null; return 0; }/' "$s"; grep -q '^stop_panel() { \[ -n "\$PANEL_PID" \] && kill "\$PANEL_PID" 2>/dev/null; return 0; }$' "$s" || mutated ;;
    3) sed -i '' "s/^stop_panel() { .*/stop_panel() { pkill -f 'Resources\/launch-progress' 2>\/dev\/null; return 0; }/" "$s"; grep -q "^stop_panel() { pkill -f 'Resources/launch-progress'" "$s" || mutated ;;
    4) awk '/^\{ echo; echo "===== / { h = $0; next } /^CS2_QUIET=1 / { print h } { print }' "$s" > "$s.new" && cat "$s.new" > "$s" && rm "$s.new"
       [ "$(grep -n '^{ echo; echo "===== ' "$s" | cut -d: -f1)" -gt "$(grep -n '^PANEL=0; PANEL_PID=""$' "$s" | cut -d: -f1)" ] || mutated ;;
    5) sed -i '' 's/^  LP_TITLE="Cities: Skylines II" LP_LOG="\$LOG" "\$PROGRESS" >/  LP_LOG="$LOG" "$PROGRESS" "Cities: Skylines II" >/' "$s"; grep -q '^  LP_LOG="\$LOG" "\$PROGRESS" "Cities: Skylines II" >' "$s" || mutated ;;
    7) sed -i '' 's/^if \[ \$rc -ne 0 \] && ! awk .*; then$/if [ $rc -ne 0 ]; then/' "$s"; grep -q '^if \[ \$rc -ne 0 \]; then$' "$s" || mutated ;;
    8) sed -i '' "s/^if \[ \\\$rc -ne 0 \] && ! awk .*; then\$/if [ \$rc -ne 0 ] \&\& ! grep -q '^ERROR:' \"\$LOG\"; then/" "$s"; grep -q "^if \[ \$rc -ne 0 \] && ! grep -q '^ERROR:' \"\$LOG\"; then\$" "$s" || mutated ;;
  esac
}
build() {   # <name> <launcher> [PATH prefix] [make-shortcut.sh options]: the app $T/dest/<name>.app; output in $T/<name>.make
  local name="$1" l="$2" pre="${3:-}"; shift; shift; [ $# -gt 0 ] && shift
  PATH="${pre:+$pre:}$T/bin:$PATH" bash "$MAKE" --dest "$T/dest" --name "$name" --launcher "$l" --game "$T/absent.exe" "$@" > "$T/$name.make" 2>&1
}
run() {   # <app> [NAME=value ...]: its shim with a scratch HOME, the stubs first on PATH and every kill it sends recorded
  local app="$1" p; shift
  p="$app/Contents/Resources/launch-progress"
  [ ! -e "$p" ] || grep -q '^# stub panel' "$p" || { echo "REFUSED: $p is not a stub: the real panel would open a window"; exit 2; }
  : > "$CALLS"; : > "$KILLS"; : > "$OSA"
  env "$@" HOME="$T/home" PATH="$T/bin:$PATH" REC="$KILLS" SHIM="$app/Contents/MacOS/launch" \
    /bin/bash -c 'kill() { echo "KILL $*" >> "$REC"; builtin kill "$@"; }; export -f kill; exec "$SHIM"' > "$T/shim.out" 2>&1
}
alive() { local p; for p in $(cat "$1" 2>/dev/null); do kill -0 "$p" 2>/dev/null && return 0; done; return 1; }
log="$T/home/Library/Logs/cs2-launcher.log"
told() { grep '^LAUNCHED ' "$log" | tail -1; }
lines() { wc -l < "$1" | tr -d ' '; }
complete() { [ -x "$1/Contents/MacOS/launch" ] && [ -s "$1/Contents/Info.plist" ] && echo complete; }

# a scratch copy of the builder, laid out as in the repo so that it finds common/ (or, with `nocommon`, does not)
scratch_builder() {   # <dir> [nocommon]
  mkdir -p "$1/cities-skylines-2/scripts"; cp "$REPO/scripts/make-shortcut.sh" "$1/cities-skylines-2/scripts/"
  [ "${2:-}" = nocommon ] || { mkdir -p "$1/common"; cp "$TOP/common/launch-progress.swift" "$1/common/"; }
}
case "$M" in 6|9|10|11|12|13|14) scratch_builder "$T/mut"; MAKE="$T/mut/cities-skylines-2/scripts/make-shortcut.sh" ;; esac
case "$M" in
  6) sed -i '' 's/\${HUD_ENV} bash / bash /' "$MAKE"; grep -q 'HUD_ENV} bash ' "$MAKE" && mutated ;;
  9) sed -i '' 's|<integer>949230</integer>|<integer>3215050</integer>|' "$MAKE"; grep -q '<integer>3215050</integer>' "$MAKE" || mutated ;;
  10) awk '/^plutil -replace CFBundleName / { next } { print } /<key>CFBundleDisplayName<\/key>/ { print "    <key>CFBundleName</key>            <string>$APPNAME</string>" }' "$MAKE" > "$MAKE.new" && cat "$MAKE.new" > "$MAKE"
      { grep -q '<string>\$APPNAME</string>' "$MAKE" && ! grep -q '^plutil -replace CFBundleName ' "$MAKE"; } || mutated ;;
  11) sed -i '' '/<key>L1Role<\/key>/d' "$MAKE"; grep -q '<key>L1Role</key>' "$MAKE" && mutated ;;
  12) sed -i '' 's/^  \[ -e "\$t" \] || \[ -L "\$t" \] || return 0$/  return 0/' "$MAKE"; grep -q '|| return 0$' "$MAKE" && mutated ;;
  13) awk '/^check_name "\$APPNAME"$/ { next } { print } /^rm -rf "\$APP"$/ { print "check_name \"$APPNAME\"" }' "$MAKE" > "$MAKE.new" && cat "$MAKE.new" > "$MAKE"
      [ "$(grep -n '^check_name "\$APPNAME"$' "$MAKE" | cut -d: -f1)" -gt "$(grep -n '^rm -rf "\$APP"$' "$MAKE" | cut -d: -f1)" ] 2>/dev/null || mutated ;;
  14) sed -i '' 's/^not_built() { .*/not_built() { return 0; }/' "$MAKE"; grep -q '^not_built() { return 0; }$' "$MAKE" || mutated ;;
esac

# --- the builder
build App "$T/launcher.sh"; rc=$?
APP="$T/dest/App.app"; PANEL="$APP/Contents/Resources/launch-progress"
check "make-shortcut.sh builds the app" "$rc:$(complete "$APP")" "0:complete"
if xcrun -f swiftc >/dev/null 2>&1; then
  check "the builder compiled the shared panel into the app, and says so" "$([ -x "$PANEL" ] && echo yes):$(grep -c 'progress: Swift panel built' "$T/App.make")" "yes:1"
  printf '===== x =====\n[2/5] two\n' > "$T/fixture.log"
  check "  ...and it is the shared one (--parse answers)" "$("$PANEL" --parse "$T/fixture.log" 2>&1)" "2 5 two"
else
  check "no swiftc on this Mac: the builder says the panel was skipped" "$([ -e "$PANEL" ] && echo built):$(grep -c 'progress: skipped (swiftc is missing' "$T/App.make")" ":1"
fi
check "nothing is left of the old panel's name" "$(grep -c 'cs2-progress' "$APP/Contents/MacOS/launch"):$([ -e "$APP/Contents/Resources/cs2-progress" ] && echo file)" "0:"
mutate_shim "$APP/Contents/MacOS/launch"

skipped() {   # <case> <app name> <reason wanted>: the builder exits 0, the app is complete, no panel, the reason is printed
  check "$1: the builder exits 0, the app is complete, there is no panel, and the reason is printed" \
    "$rc:$(complete "$T/dest/$2.app"):$([ -e "$T/dest/$2.app/Contents/Resources/launch-progress" ] && echo panel):$(grep -c "progress: skipped ($3" "$T/$2.make")" "0:complete::1"
}
build NoSwift "$T/launcher.sh" "$T/noswift"; rc=$?
skipped "no swiftc" NoSwift "swiftc is missing"
build BadSwift "$T/launcher.sh" "$T/badswift"; rc=$?
skipped "the compile fails" BadSwift "the compile failed"
build Old "$T/old-launcher.sh"; rc=$?
skipped "a launcher with no launch-feedback block" Old "the launcher prints no step lines"
scratch_builder "$T/nocommon" nocommon
PATH="$T/bin:$PATH" bash "$T/nocommon/cities-skylines-2/scripts/make-shortcut.sh" --dest "$T/dest" --name NoSource --launcher "$T/launcher.sh" --game "$T/absent.exe" > "$T/NoSource.make" 2>&1; rc=$?
skipped "the source is missing" NoSource "common/launch-progress.swift is missing"

# --- the shim and a panel that stays up. Another app's panel runs beside it, as the other game's would.
mkdir -p "$T/other/Other.app/Contents/Resources"; stub "$T/other/Other.app" stays
"$T/other/Other.app/Contents/Resources/launch-progress" & disown
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$PIDS" ] && break; sleep 0.1; done
cp "$PIDS" "$T/other.pids"; : > "$PIDS"
check "(the other game's stub panel is running)" "$(alive "$T/other.pids" && echo running)" running
stub "$APP" stays
mkdir -p "${log%/*}"; : > "$log"
run "$APP"; rc=$?
check "the app runs the launcher once and exits 0" "$rc:$(grep -c '^LAUNCHED ' "$log")" "0:1"
check "the panel is started once, after the ===== line, title and log in its environment, no arguments" "$(cat "$CALLS")" "PANEL args=0 title=Cities: Skylines II log=$log headers=1"
check "the launcher is told the window is up, and --hud was not asked for" "$(told)" "LAUNCHED quiet=1 panel=1 hud=unset"
sleep 0.5
check "the panel was alive when the launcher returned: it is stopped (at least one kill), and gone" "$([ "$(lines "$KILLS")" -ge 1 ] && echo killed):$(alive "$PIDS" && echo running || echo gone)" "killed:gone"
check "the other game's panel is still running when this shim returns" "$(alive "$T/other.pids" && echo running || echo gone)" running
check "no alert, no notification" "$(lines "$OSA")" 0

# --- a panel that is gone at once, one that ends before the launcher returns, and none
: > "$PIDS"; stub "$APP" quits
run "$APP"
check "a panel that exits at once: the launcher is told there is no window, and nothing is killed" "$(told):$(lines "$CALLS"):$(lines "$KILLS")" "LAUNCHED quiet=1 panel=0 hud=unset:1:0"
stub "$APP" brief
run "$APP"
check "a panel that ended before the launcher returned: it was up, and nothing is killed" "$(told):$(lines "$KILLS")" "LAUNCHED quiet=1 panel=1 hud=unset:0"
rm -f "$PANEL"
run "$APP"
check "no panel file: the launcher is told there is no window and nothing is started" "$(told):$(lines "$CALLS"):$(lines "$KILLS")" "LAUNCHED quiet=1 panel=0 hud=unset:0:0"

# --- one alert for one failure
: > "$log"
run "$APP" FAKE_ERROR=x FAKE_RC=1; rc=$?
check "a launcher that dies with ERROR: its exit code, and no alert from the shim" "$rc:$(grep -c 'Launch failed' "$OSA")" "1:0"
run "$APP" FAKE_RC=1; rc=$?
check "a launcher that exits 1 in silence, after a session that held ERROR:: one alert" "$rc:$(grep -c 'Launch failed (exit 1)' "$OSA")" "1:1"
: > "$log"
run "$APP" FAKE_RC=3; rc=$?
check "the same in a fresh log: its exit code, one alert" "$rc:$(grep -c 'Launch failed (exit 3)' "$OSA")" "3:1"

# --- --hud reaches the launcher
build Hud "$T/launcher.sh" "$T/noswift" --hud
mutate_shim "$T/dest/Hud.app/Contents/MacOS/launch"; stub "$T/dest/Hud.app" stays; : > "$PIDS"
run "$T/dest/Hud.app"
check "built with --hud: the launcher sees CS2_HUD=1 beside the window setting" "$(told)" "LAUNCHED quiet=1 panel=1 hud=1"

# --- what the 14unch3r window reads (docs/plans/launcher-window.md, 2.1; W5). Built without swiftc, from a
# scratch working folder, so that a file a name might create lands where it is looked for. Keys are read by
# plutil, never by grepping the plist, which plutil rewrites whole.
mkdir -p "$T/cwd" "$T/badplutil"
printf '#!/bin/bash\nexit 1\n' > "$T/badplutil/plutil"; chmod +x "$T/badplutil/plutil"   # every plutil call fails
mk() {   # <dest> <name> [options]: the builder as a person runs it, output in $T/mk.out; prints its exit code
  local d="$1" n="$2"; shift 2
  ( cd "$T/cwd" && PATH="${PRE:+$PRE:}$T/noswift:$T/bin:$PATH" bash "$MAKE" --dest "$d" --name "$n" --launcher "$T/launcher.sh" --game "$T/absent.exe" "$@" ) > "$T/mk.out" 2>&1
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
GP="drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II/Cities2.exe"
mkdir -p "$T/fx/W.app/Contents/SharedSupport/prefix" "$T/fx/A&B.app/Contents/SharedSupport/prefix" \
         "$T/fx/Old.app/Contents/SharedSupport/prefix-old" "$T/cwd/rel.app/Contents/SharedSupport/prefix"

rc=$(mk "$T/k" Keys --game "$T/fx/W.app/Contents/SharedSupport/prefix/$GP"); A="$T/k/Keys.app"
check "built with a fixture wrapper's game path: exit 0, and the plist lints" "$rc:$(lints "$A")" "0:lints"
check "  ...L1Role is game" "$(key "$A" L1Role)" game
check "  ...L1SteamAppID is this game's, stored as an integer" "$(appid "$A")" 949230
check "  ...its three alternate names" "$(alts "$A")" "3|CS2|Cities Skylines 2|Cities: Skylines II"
check "  ...L1Prefix is the fixture wrapper's prefix" "$(key "$A" L1Prefix)" "$T/fx/W.app/Contents/SharedSupport/prefix"
rc=$(mk "$T/k" Amp --game "$T/fx/A&B.app/Contents/SharedSupport/prefix/$GP")
check "a prefix holding & survives, and the plist lints" "$rc:$(key "$T/k/Amp.app" L1Prefix):$(lints "$T/k/Amp.app")" "0:$T/fx/A&B.app/Contents/SharedSupport/prefix:lints"
noprefix() {   # <case> <game path>: built, and no L1Prefix
  rc=$(mk "$T/k" NoPrefix --game "$2")
  check "$1: built, and no L1Prefix" "$rc:$(key "$T/k/NoPrefix.app" L1Prefix)" "0:(none)"
}
noprefix "the prefix folder is missing" "$T/fx/Gone.app/Contents/SharedSupport/prefix/$GP"
noprefix "the game path has no prefix segment" "$T/absent.exe"
noprefix "the game path runs through .../prefix-old/..." "$T/fx/Old.app/Contents/SharedSupport/prefix-old/$GP"
noprefix "the game path is relative, its folder there" "rel.app/Contents/SharedSupport/prefix/$GP"

NAME="N \"q\" & \$(touch x) \`touch x\`"
rc=$(mk "$T/k" "$NAME")
check "--name holding \", &, \$(touch x) and a backtick: exit 0, the plist holds that exact name, and lints" "$rc:$(key "$T/k/$NAME.app" CFBundleName):$(lints "$T/k/$NAME.app")" "0:$NAME:lints"
check "  ...and no file x appears" "$(ls -A "$T/cwd" "$T/k" | grep -c -x x)" 0

mk "$T/proto" Proto > /dev/null; PROTO="$T/proto/Proto.app"   # an app of this builder's, copied wherever one is needed
own_copy() { mkdir -p "$(dirname "$1")"; cp -R "$PROTO" "$1"; : > "$1/Contents/Resources/keep"; }
NAMEMSG="--name must not be empty, hold / or a control character, or start with . or -"
badname() {   # <case> <name> <line said>: exit 2, said, and the app of this builder's that the name points at untouched
  local t="$T/bad/$2.app" before
  own_copy "$t"; before=$(snap "$t")
  rc=$(mk "$T/bad" "$2")
  check "--name $1: exit 2, said, and the app it names untouched" "$rc:$(said "$3"):$(snap "$t")" "2:1:$before"
}
badname "empty" "" "--name needs a value"
badname "holding /" "sub/X" "$NAMEMSG"
badname "starting with -" "-x" "$NAMEMSG"
badname "starting with ." ".x" "$NAMEMSG"
badname "holding a tab" "$(printf 'a\tb')" "$NAMEMSG"

rc=$(PRE="$T/badplutil" mk "$T/pl" Fails)
check "every plutil call fails: the error line, no bundle left, exit 1" "$rc:$(said "ERROR: $T/pl/Fails.app/Contents/Info.plist is not a valid property list; the app was not built"):$([ -e "$T/pl/Fails.app" ] && echo left)" "1:1:"
# A trailing slash cannot reach this builder's target: it is always <dest>/<name>.app, and a name holding /
# is refused above. tools/test-make-app.sh tests one on SM_APP.

fake() {   # <bundle> <marker line> <identifier> [wrapper|shimlink]: shaped like this builder's app, or nearly
  local b="$1" i=2
  mkdir -p "$b/Contents/MacOS" "$b/Contents/Resources"
  { echo '#!/bin/bash'; while [ "$i" -lt "$2" ]; do echo "# line $i"; i=$((i + 1)); done
    echo '# Generated by scripts/make-shortcut.sh — re-run that instead of editing this file.'; } > "$b/Contents/MacOS/launch"
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>%s</string></dict></plist>\n' "$3" > "$b/Contents/Info.plist"
  : > "$b/Contents/Resources/keep"
  case "${4:-}" in
    wrapper) mkdir -p "$b/Contents/SharedSupport/prefix" ;;
    shimlink) mv "$b/Contents/MacOS/launch" "$b/Contents/MacOS/launch.real"; ln -s launch.real "$b/Contents/MacOS/launch" ;;
  esac
}
refused() {   # <case> <name>: in $T/own, exit 1, both lines said, the target untouched
  local t="$T/own/$2.app" before
  before=$(snap "$t")
  rc=$(mk "$T/own" "$2")
  check "$1: refused with exit 1, both lines said, untouched" "$rc:$(said "ERROR: $t exists and was not built by this script; nothing removed")$(said 'If it is a leftover of this script, move it to the Trash and run this again.'):$(snap "$t")" "1:11:$before"
}
ID=local.cs2.dxmt11.launcher
fake "$T/own/Wrapper.app" 2 "$ID" wrapper;      refused "a wrapper-shaped bundle (Contents/SharedSupport)" Wrapper
fake "$T/own/OtherID.app" 2 local.someone.else; refused "a bundle with another identifier" OtherID
fake "$T/own/Line11.app" 11 "$ID";              refused "a bundle whose marker is on line 11" Line11
fake "$T/own/ShimLink.app" 2 "$ID" shimlink;    refused "a bundle whose shim is a symlink" ShimLink
own_copy "$T/elsewhere/Real.app"; ln -s "$T/elsewhere/Real.app" "$T/own/Link.app"
refused "a symlink to a bundle of this builder's" Link
check "  ...it is still a symlink" "$([ -L "$T/own/Link.app" ] && echo link)" link
replaced() {   # <case> <name>: in $T/own, exit 0, a complete app, and the old one's extra file gone
  rc=$(mk "$T/own" "$2")
  check "$1 is replaced" "$rc:$(complete "$T/own/$2.app"):$([ -e "$T/own/$2.app/Contents/Resources/keep" ] && echo old)" "0:complete:"
}
own_copy "$T/own/Again.app";       replaced "a bundle this builder made" Again
fake "$T/own/Line10.app" 10 "$ID"; replaced "a bundle of this builder's shape with its marker on line 10" Line10

echo "$fails failure(s)"
[ "$fails" = 0 ]
