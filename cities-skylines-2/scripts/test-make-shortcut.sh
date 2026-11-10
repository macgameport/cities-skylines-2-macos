#!/bin/bash
# test-make-shortcut.sh -- make-shortcut.sh builds the double-click app with the shared progress panel, and the
# app's shim starts that panel once, after the ===== line, tells the launcher whether a window is up, stops
# only its own panel and only while it is alive, and shows one alert for one failure. Apps are built into a
# scratch folder around fake launchers that sleep one second. HOME is a scratch folder, so the shim's log
# lands there; a stub pgrep and a recording osascript come first on PATH, so the real game is never looked
# for or brought forward and no alert is shown. The compiled panel is only asked to --parse, then REPLACED
# by a recording stub before any shim runs: the real one would open a window, and a shim is refused here
# while its app holds anything but a stub. No game, no Steam, no Wine.
#   bash scripts/test-make-shortcut.sh            exit 0 = every case passed
#   MUTANT=1 ...   the shim says a window is up whether or not its process is alive; must exit 1
#   MUTANT=2 ...   the panel is stopped by a plain kill of its PID (a stranger's, hours later); must exit 1
#   MUTANT=3 ...   the panel is stopped by pkill -f (the other game's window goes too); must exit 1
#   MUTANT=4 ...   the panel is started before the ===== line (it reads the last session); must exit 1
#   MUTANT=5 ...   the title is passed to the panel as an argument; must exit 1
#   MUTANT=6 ...   the builder drops ${HUD_ENV} from the shim (--hud does nothing); must exit 1
#   MUTANT=7 ...   the shim alerts on every failure (two alerts for one die); must exit 1
#   MUTANT=8 ...   the shim looks for ERROR: in the whole log (an old failure silences a new one); must exit 1
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
case "$M" in 0|1|2|3|4|5|6|7|8) ;; *) echo "REFUSED: no mutant $M"; exit 2 ;; esac
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
if [ "$M" = 6 ]; then
  scratch_builder "$T/mut"; MAKE="$T/mut/cities-skylines-2/scripts/make-shortcut.sh"
  sed -i '' 's/\${HUD_ENV} bash / bash /' "$MAKE"; grep -q 'HUD_ENV} bash ' "$MAKE" && mutated
fi

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

echo "$fails failure(s)"
[ "$fails" = 0 ]
