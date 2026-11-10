#!/bin/bash
# test-make-app.sh -- make-app.sh builds the double-click app with the shared progress panel, and the app runs
# the launcher it was given, once. Its shim starts the panel once, after the ===== line, tells the launcher
# whether a window is up, stops only its own panel and only while it is alive, and shows one alert for one
# failure. Fake launchers that print their version and what they were told, then sleep one second; HOME in a
# temp dir so the shim's log lands there; a stub pgrep and a recording osascript first on PATH, so no game is
# looked for and no alert is shown. The compiled panel is only asked to --parse, then REPLACED by a recording
# stub before any shim runs: the real one would open a window, and a shim is refused here while its app holds
# anything but a stub. No game, no Steam. The app pulls nothing at launch (unification plan, O3).
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
case "$M" in 0|1|2|3|4|5|6|7|8|9) ;; *) echo "REFUSED: no mutant $M"; exit 2 ;; esac
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
build() {   # <app> <launcher> [PATH prefix]: output in <app>.make
  PATH="${3:+$3:}$T/bin:$PATH" SM_APP="$1" SM_SCRIPT="$2" bash "$MAKE" > "$1.make" 2>&1
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
if [ "$M" = 7 ]; then
  scratch_builder "$T/mut"; MAKE="$T/mut/surviving-mars-relaunched/make-app.sh"
  sed -i '' 's/^elif ! xcrun swiftc \(.*\); then PANEL_WHY="the compile failed".*$/else xcrun swiftc \1/' "$MAKE"
  grep -q '^else xcrun swiftc -O -o "\$PANEL_OUT" "\$PANEL_SRC" >/dev/null 2>&1$' "$MAKE" || mutated
fi

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

echo "$fails failure(s)"
[ "$fails" = 0 ]
