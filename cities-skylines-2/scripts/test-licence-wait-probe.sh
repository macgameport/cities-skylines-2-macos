#!/bin/bash
# test-licence-wait-probe.sh -- scripts/licence-wait-probe.sh without a launch: its judge on fixture run
# folders, and its loop as a scratch copy beside a stub boot-verify.sh that plays a list of outcomes. HOME is
# a scratch folder, so the installed launcher, the wrapper and the run folders are all fakes under it; a stub
# pgrep, lsof and sleep come first on PATH, so nothing real is looked for and nothing waits. No game, no
# Steam, no Wine, no boot.
#   bash scripts/test-licence-wait-probe.sh            exit 0 = every case passed
#   MUTANT=1 ...   the wait line is matched loosely (a 45 s run counts for 15); must exit 1
#   MUTANT=2 ...   boot-verify exit 3 counts as FAIL; must exit 1
#   MUTANT=3 ...   boot-verify exit 1 counts as FAIL (any failed boot blamed on the licence); must exit 1
#   MUTANT=4 ...   rules 4 and 5 swapped (a real licence failure is filed as OTHER); must exit 1
#   MUTANT=5 ...   an exit code nobody documents counts as PASS; must exit 1
#   MUTANT=6 ...   the record before the boot is ignored (a missed update reads VOID, not FAIL); must exit 1
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d /tmp/licence-wait-probe-test.XXXX)"
trap 'rm -rf "$T"' EXIT
S="$T/scripts"; H="$T/home"; mkdir -p "$S" "$T/bin" "$T/runs" "$H/cs2-patch" "$H/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix"
P="$S/licence-wait-probe.sh"; cp "$REPO/scripts/licence-wait-probe.sh" "$P"
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
case "${MUTANT:-0}" in
  0) ;;
  1) sed -i '' 's/^wait_lines() { grep -c "^Licence wait: \$2 s\\\$" "\$1"; }/wait_lines() { grep -c "Licence wait: " "$1"; }/' "$P"
     grep -q '^wait_lines() { grep -c "Licence wait: " "\$1"; }' "$P" || mutated ;;
  2) sed -i '' 's/^  \[ "\$rc" = 3 \] && { echo "VOID /  [ "$rc" = 3 ] \&\& { echo "FAIL /' "$P"; grep -q '^  \[ "\$rc" = 3 \] && { echo "FAIL ' "$P" || mutated ;;
  3) sed -i '' 's/^  \[ "\$rc" = 1 \] && { echo "OTHER /  [ "$rc" = 1 ] \&\& { echo "FAIL /' "$P"; grep -q '^  \[ "\$rc" = 1 \] && { echo "FAIL ' "$P" || mutated ;;
  4) awk '/^  grep -qi .platform service integration failed. / { held = $0; next } { print } held != "" && /^  \[ "\$rc" = 1 \] && / { print held; held = "" }' "$P" > "$P.new" && mv "$P.new" "$P"
     [ "$(grep -n '^  \[ "\$rc" = 1 \] && ' "$P" | cut -d: -f1)" -lt "$(grep -n "^  grep -qi 'platform service integration failed' " "$P" | cut -d: -f1)" ] || mutated ;;
  5) sed -i '' 's/^  echo "VOID boot-verify exit \$rc is not one of its own"$/  echo "PASS"/' "$P"; grep -q '^  echo "PASS"$' "$P" || mutated ;;
  6) sed -i '' 's/^    if \[ "\$r" = current \] && grep /    if false \&\& grep /' "$P"; grep -q '^    if false && grep ' "$P" || mutated ;;
  *) echo "REFUSED: no mutant ${MUTANT}"; exit 2 ;;
esac
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

# ---------------------------------------------------------------- the judge, on fixture run folders
# One sign-in and Steam's app-information updates after it, as on 2026-11-09 (the account id replaced by
# Steam's logged-off one). Around them: an earlier session, a second "finished OK" before the last, and
# one after the 120 s window. The run starts at 21:01:08.
T0=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-11-09 21:01:08' +%s)
CONN="[2026-11-09 20:10:00] [Logging On, 4, 7] [U:1:0] RecvMsgClientLogOnResponse() : [U:1:0] 'OK'
[2026-11-09 21:01:34] Client version: 1792618285
[2026-11-09 21:01:43] [Logging On, 4, 7] [U:1:0] RecvMsgClientLogOnResponse() : [U:1:0] 'OK'
[2026-11-09 21:01:43] [Logged On, 4, 7] [U:1:0] RecvMsgClientLogOnResponse() : processing complete"
INFO="[2026-11-09 20:10:02] UpdatesJob: finished OK, apps updated 0 (0 KB), packages updated 0 (0 KB)
[2026-11-09 21:01:45] UpdatesJob: finished OK, apps updated 35 (533 KB), packages updated 0 (0 KB)
[2026-11-09 21:01:45] UpdatesJob: apps still needs updates, run again
[2026-11-09 21:01:46] UpdatesJob: finished OK, apps updated 0 (0 KB), packages updated 0 (0 KB)
[2026-11-09 21:09:00] UpdatesJob: finished OK, apps updated 0 (0 KB), packages updated 0 (0 KB)"
rundir() {   # <name>: a run folder as a clean boot at 15 s leaves it; echoes its path
  local d="$T/runs/$1"; mkdir -p "$d"
  printf '%s\n' 'Wrapper: CS2dxmt11.app' '[2/5] Starting Steam and signing in…' 'Licence wait: 15 s' \
    '[3/5] Steam is confirming the game licence, about 15 seconds left…' 'Game build 25127643 is current.' \
    '[5/5] Starting Cities: Skylines II. The menu takes about a minute…' 'Game exited (rc=0). Shutting down Steam cleanly…' > "$d/launcher.log"
  printf '%s\n' '[2026-11-09 21:02:40,008] [INFO]  Odin Serializer ArchitectureInfo initialization' \
    '[2026-11-09 21:03:34,182] [INFO]  MainMenu reached' '[2026-11-09 21:04:25,618] [INFO]  GameManager destroyed (4392.995ms)' > "$d/SceneFlow.log"
  echo 'Mono path[0] = C:/x' > "$d/Player.log"
  printf '%s\n' "t0                      : $T0 (2026-11-09 21:01:08)" 'reason                  : menu reached, graceful exit, 0 InvalidProgramException' 'VERDICT: PASS' > "$d/boot-verify.out"
  printf '%s\n' "$CONN" > "$d/connection_log.txt"; printf '%s\n' "$INFO" > "$d/appinfo_log.txt"
  echo "$d"
}
judge() { bash "$P" --judge "$@" 2>&1; }   # [--expect-update] <run dir> <seconds> <boot-verify exit>
word() { judge "$@" | cut -d' ' -f1; }
SIG='[2026-11-09 21:02:41,100] [ERROR]  [SceneFlow] platform service integration failed'

D=$(rundir clean)
check "a clean run, boot-verify 0: PASS, and the second job took 3 s" "$(judge "$D" 15 0)" "PASS | second job: 3 s"
D=$(rundir at45); sed -i '' 's/^Licence wait: 15 s$/Licence wait: 45 s/' "$D/launcher.log"
check "a log made with 45, judged at 15: VOID" "$(word "$D" 15 0)" VOID
check "  ...and judged at 45 it is a run" "$(word "$D" 45 0)" PASS
D=$(rundir nowait); printf '%s\n' 'Wrapper: CS2dxmt11.app' 'ERROR: Steam did not auto-login (token expired, or it crashed).' > "$D/launcher.log"
check "no wait line and an ERROR:: VOID, with the reason" "$(judge "$D" 15 3 | grep -c '^VOID .*ERROR: Steam did not auto-login')" 1
D=$(rundir twice); echo 'Licence wait: 15 s' >> "$D/launcher.log"
check "two wait lines: VOID" "$(word "$D" 15 0)" VOID
D=$(rundir warm); sed -i '' '/^Licence wait: /d' "$D/launcher.log"; echo "$SIG" >> "$D/SceneFlow.log"
check "no wait line, with the signature and boot-verify 1: VOID (the wait under test did not happen)" "$(word "$D" 15 1)" VOID
D=$(rundir sig0); echo "$SIG" >> "$D/SceneFlow.log"
check "the signature with boot-verify 0: FAIL" "$(word "$D" 15 0)" FAIL
D=$(rundir sig1); echo 'PLATFORM SERVICE INTEGRATION FAILED' >> "$D/Player.log"
check "the signature in Player.log, in other letter case, with boot-verify 1: FAIL" "$(word "$D" 15 1)" FAIL
D=$(rundir stale); echo "$SIG" >> "$D/SceneFlow.log"
check "boot-verify 3: VOID, even over a log that holds the signature (it is the last run's)" "$(word "$D" 15 3)" VOID
D=$(rundir other); sed -i '' "s/^reason .*/reason                  : no 'MainMenu reached'/" "$D/boot-verify.out"
check "boot-verify 1 with no signature: OTHER, with boot-verify's reason" "$(judge "$D" 15 1 | grep -c "^OTHER .*no 'MainMenu reached'")" 1
check "an exit nobody documents (143), with a wait line: VOID, with the code" "$(judge "$D" 15 143 | grep -c '^VOID .*143')" 1
judge "$D" 15 2 > "$T/stop.out"; rc=$?
check "boot-verify 2: STOP refused, and --judge exits 2" "$rc:$(grep -c '^STOP refused' "$T/stop.out")" "2:1"
judge "$D" 15 64 > "$T/stop.out"; rc=$?
check "boot-verify 64: STOP setup, and --judge exits 2" "$rc:$(grep -c '^STOP setup' "$T/stop.out")" "2:1"
D=$(rundir timeout); echo '[2026-11-09 21:02:13] UpdatesJob: finished Timeout' >> "$D/appinfo_log.txt"
check "the second job: \`finished Timeout\` after the sign-in is recorded as none" "$(judge "$D" 15 0)" "PASS | second job: none"
D=$(rundir noinfo); grep -v ' 21:01:4' "$T/runs/clean/appinfo_log.txt" > "$D/appinfo_log.txt"
check "the second job: no finished update in the 120 s after the sign-in is none" "$(judge "$D" 15 0)" "PASS | second job: none"
D=$(rundir nosignin); grep -v ' 21:01:43' "$T/runs/clean/connection_log.txt" > "$D/connection_log.txt"
check "the second job: no sign-in at or after the run's start is none" "$(judge "$D" 15 0)" "PASS | second job: none"
D=$(rundir update)
check "--expect-update, and no 'game update waiting' line: VOID" "$(word --expect-update "$D" 15 0)" VOID
echo 'WARNING: game update waiting (build 23700737 -> 25127643) — launching the installed build. CS2_UPDATE=apply takes it.' >> "$D/launcher.log"
check "--expect-update, with the line: PASS" "$(word --expect-update "$D" 15 0)" PASS
judge "$D" 015 0 > /dev/null; check "--judge with a leading zero in the seconds: usage, exit 64" "$?" 64
# The record before the boot (C74: it can read current between sessions, and Steam rewrites it after sign-in).
D=$(rundir missed); echo 'record before the boot: current (StateFlags 4, buildid 23700737, TargetBuildID 23700737)' > "$D/manifest-before.txt"
sed -i '' 's/^Game build 25127643 is current\.$/Game build 23700737 is current./' "$D/launcher.log"
check "--expect-update, the record current before the boot and the launcher saying current: FAIL, the second job" \
  "$(judge --expect-update "$D" 15 0 | grep -c "^FAIL the update check called the game current.*record before: current$")" 1
check "  ...the same run without --expect-update: PASS, with the record named" "$(judge "$D" 15 0)" "PASS | second job: 3 s | record before: current"
D=$(rundir seen); echo 'record before the boot: current (StateFlags 4, buildid 23700737, TargetBuildID 23700737)' > "$D/manifest-before.txt"
echo 'WARNING: game update waiting (build 23700737 -> 25127643) — launching the installed build. CS2_UPDATE=apply takes it.' >> "$D/launcher.log"
check "--expect-update, the record current before and the update shown: PASS, the second job tested" "$(judge --expect-update "$D" 15 0)" "PASS | second job: 3 s | record before: current"
D=$(rundir already); echo 'record before the boot: waiting (StateFlags 6, buildid 23700737, TargetBuildID 25127643)' > "$D/manifest-before.txt"
check "--expect-update, the record already waiting and no update line: VOID" "$(word --expect-update "$D" 15 0)" VOID
D=$(rundir norecord)
check "--expect-update, no record file and the launcher saying current: VOID, not FAIL" "$(word --expect-update "$D" 15 0)" VOID

# ---------------------------------------------------------------- the loop, against a stub boot-verify.sh
# The stub takes the next word of STUB_PLAN at each call and leaves what such a boot leaves in --out. Its
# launcher log says `Licence wait: N s` with the CS2_LICENCE_WAIT it was given, so a setting that does not
# reach the boot shows as VOID. The four functions the probe takes from boot-verify.sh are the real ones.
{ echo '#!/bin/bash'; grep -E '^(_owns|game_pids|game_up|steam_up)\(\) ' "$REPO/scripts/boot-verify.sh"; cat <<'EOF'
OUT=""; while [ $# -gt 0 ]; do [ "$1" = --out ] && { shift; OUT="$1"; }; shift; done
n=$(($(cat "$STUB_STATE/calls" 2>/dev/null || echo 0) + 1)); echo "$n" > "$STUB_STATE/calls"
what=$(echo $STUB_PLAN | cut -d' ' -f"$n")
echo "t0                      : $(date +%s)"
[ -n "${STUB_LEAVE_STEAM:-}" ] && : > "$STUB_STATE/steam-up"
case "$what" in refused) echo "REFUSED: something already runs"; exit 2 ;; setup) echo "ERROR: no driver"; exit 64 ;; esac
mkdir -p "$OUT"; : > "$OUT/Player.log"; echo '[INFO]  MainMenu reached' > "$OUT/SceneFlow.log"
printf '%s\n' "Licence wait: ${CS2_LICENCE_WAIT:-unset} s" 'Game exited (rc=0).' > "$OUT/launcher.log"
case "$what" in
  pass)  echo 'reason                  : menu reached'; exit 0 ;;
  current) echo 'Game build 23700737 is current.' >> "$OUT/launcher.log"; echo 'reason                  : menu reached'; exit 0 ;;
  update) echo 'WARNING: game update waiting (build 23700737 -> 25127643) — launching the installed build.' >> "$OUT/launcher.log"; echo 'reason                  : menu reached'; exit 0 ;;
  void)  echo 'ERROR: Steam did not auto-login' > "$OUT/launcher.log"; echo 'reason                  : launcher exited before the game started'; exit 3 ;;
  other) echo "reason                  : no 'GameManager destroyed'"; exit 1 ;;
  fail)  echo '[ERROR]  [SceneFlow] platform service integration failed' > "$OUT/SceneFlow.log"; echo "reason                  : no 'MainMenu reached'"; exit 1 ;;
  *)     echo "stub: the plan has no word $n"; exit 99 ;;
esac
EOF
} > "$S/boot-verify.sh"
[ "$(grep -cE '^(_owns|game_pids|game_up|steam_up)\(\) ' "$S/boot-verify.sh")" = 4 ] || { echo "REFUSED: boot-verify.sh no longer defines the four functions the probe takes from it"; exit 2; }
printf '#!/bin/bash\ncase "$*" in *steam.exe*) [ -n "${STUB_STEAM:-}" ] || [ -e "$STUB_STATE/steam-up" ] && echo 4242 ;; *Cities2*) [ -n "${STUB_GAME:-}" ] && echo 4243 ;; esac\nexit 0\n' > "$T/bin/pgrep"
printf '#!/bin/bash\necho "$STUB_PREFIX/drive_c/windows/system.reg"\n' > "$T/bin/lsof"
printf '#!/bin/bash\nexit 0\n' > "$T/bin/sleep"
chmod +x "$T/bin"/*
# the installed launcher, as far as the probe reads it: the block's marker, and the real update-check functions
installed() {
  { printf '#!/bin/bash\n%s\n' "$1"
    [ "${2:-}" = bare ] || for f in acf_field update_pending; do sed -n "/^$f() {/,/^}/p" "$REPO/launchers/launch-cs2-dxmt11.sh"; done
  } > "$H/cs2-patch/launch-cs2-dxmt11.sh"
}
installed '# >>> launch-feedback (a fake launcher)'
STEAMAPPS="$H/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/steamapps"; mkdir -p "$STEAMAPPS"
manifest() { printf '"AppState"\n{\n\t"appid"\t\t"949230"\n\t"StateFlags"\t\t"%s"\n\t"buildid"\t\t"%s"\n\t"TargetBuildID"\t\t"%s"\n}\n' "$1" "$2" "$3" > "$STEAMAPPS/appmanifest_949230.acf"; }
manifest 4 23700737 23700737
probe() {   # <name> <plan> [probe arguments]: output in $T/<name>.out; echoes the probe's exit code
  local name="$1" plan="$2"; shift 2
  rm -rf "$T/state" "$H/cs2-patch/boot-verify"; mkdir -p "$T/state"
  env -u CS2_WRAPPER -u CS2_LAUNCHER -u CS2_LICENCE_WAIT HOME="$H" PATH="$T/bin:$PATH" STUB_PLAN="$plan" STUB_STATE="$T/state" \
    STUB_PREFIX="$H/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix" bash "$P" "$@" > "$T/$name.out" 2>&1 < /dev/null
  echo $?
}
boots() { cat "$T/state/calls" 2>/dev/null || echo 0; }
dirs() { ls "$H/cs2-patch/boot-verify/licence-$1" 2>/dev/null | wc -l | tr -d ' '; }
said() { grep -c -- "$2" "$T/$1.out"; }

check "five clean boots: exit 0 after 5, and it says 5 of 5" "$(probe five 'pass pass pass pass pass pass' 15):$(boots):$(said five '^5 of 5 passed at CS2_LICENCE_WAIT=15')" "0:5:1"
check "  ...each in its own folder under ~/cs2-patch/boot-verify/licence-15, with boot-verify's output kept" "$(dirs 15):$(ls "$H"/cs2-patch/boot-verify/licence-15/*/boot-verify.out | wc -l | tr -d ' ')" "5:5"
check "a count of runs is taken: 2 runs at 30 s" "$(probe two 'pass pass pass' 30 2):$(boots):$(dirs 30)" "0:2:2"
check "a VOID and a first OTHER are repeated and not counted toward five: 7 boots" "$(probe repeat 'void pass other pass pass pass pass pass' 15):$(boots):$(said repeat '^5 of 5 passed')" "0:7:1"
check "three VOID in a row stop it: exit 3 after 3 boots" "$(probe voids 'void void void pass pass pass pass pass' 15):$(boots):$(said voids 'three VOID runs in a row')" "3:3:1"
check "two VOID, a pass, two VOID: not three in a row, it goes on" "$(probe voids2 'void void pass void void pass pass pass pass' 15):$(boots)" "0:9"
check "a second OTHER stops it: exit 3 after 3 boots" "$(probe others 'other pass other pass pass pass pass' 15):$(boots):$(said others 'a second boot failed for a reason that is not the licence')" "3:3:1"
check "a FAIL ends it: exit 1, the failing run named" "$(probe fail 'pass fail pass pass pass pass' 15):$(boots):$(said fail '^FAIL at CS2_LICENCE_WAIT=15, after 1 pass')" "1:2:1"
check "the control run, one boot at 0 s that fails: exit 1" "$(probe control 'fail' 0 1):$(boots):$(dirs 0)" "1:1:1"
check "boot-verify refuses (exit 2): the probe stops with exit 2" "$(probe refused 'pass refused pass' 15):$(boots):$(said refused '^stopped: not a run')" "2:2:1"
check "boot-verify cannot start (exit 64): the probe stops with exit 2" "$(probe setup 'setup pass' 15):$(boots)" "2:1"
check "Steam still up 30 s after a boot: the probe stops, exit 3 after 1 boot" "$(STUB_LEAVE_STEAM=1 probe steamleft 'pass pass' 15):$(boots):$(said steamleft "this wrapper's Steam is still up")" "3:1:1"
check "the game is running: refused, no boot" "$(STUB_GAME=1 probe game 'pass' 15):$(boots):$(said game '^REFUSED: the game is running')" "2:0:1"
check "this wrapper's Steam is running: refused, no boot" "$(STUB_STEAM=1 probe steam 'pass' 15):$(boots):$(said steam "^REFUSED: this wrapper's Steam is running")" "2:0:1"
installed 'echo "an older launcher"'
check "an installed launcher without the block: refused, no boot" "$(probe oldl 'pass' 15):$(boots):$(said oldl '^REFUSED: the installed launcher has no launch-feedback block')" "2:0:1"
installed '# >>> launch-feedback (a fake launcher)' bare
check "an installed launcher without the update-check functions: refused, no boot" "$(probe nofn 'pass' 15):$(boots):$(said nofn '^REFUSED: acf_field not found in the installed launcher')" "2:0:1"
installed '# >>> launch-feedback (a fake launcher)'
manifest 4 23700737 23700737
check "the record is read before each boot into manifest-before.txt: current, with its numbers" \
  "$(probe rec 'pass pass' 15 2):$(cat "$H"/cs2-patch/boot-verify/licence-15/*/manifest-before.txt | grep -c '^record before the boot: current (StateFlags 4, buildid 23700737, TargetBuildID 23700737)$')" "0:2"
check "--expect-update with a current record, and a launcher that says current: exit 1, FAIL on the first boot" \
  "$(probe missed2 'current pass' --expect-update 15):$(boots):$(said missed2 'attempt 1: FAIL the update check called the game current')" "1:1:1"
manifest 1026 23700737 25127643
check "--expect-update with a record already waiting, and the update shown: PASS, the record named waiting" \
  "$(probe seen2 'update' --expect-update 15 1):$(said seen2 'attempt 1: PASS .*record before: waiting')" "0:1"
manifest 4 23700737 23700737
for bad in 07 1000 abc -5 ''; do
  check "seconds '$bad': usage, exit 64, no boot" "$(probe bad 'pass' "$bad"):$(boots)" "64:0"
done
check "no arguments: usage, exit 64" "$(probe none 'pass'):$(boots)" "64:0"
check "runs '0': usage, exit 64" "$(probe runs0 'pass' 15 0):$(boots)" "64:0"

echo "$fails failure(s)"
[ "$fails" = 0 ]
