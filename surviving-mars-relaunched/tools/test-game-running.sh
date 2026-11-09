#!/bin/bash
# test-game-running.sh -- fixtures for the "already running" guard: game_running in
# launch-relaunched.sh, and the copy make-app.sh writes into the app shim. No game is started: fake
# processes carry the command lines (exec -a sets argv[0]).
#   bash tools/test-game-running.sh            exit 0 = every case passed
#   MUTANT=1 bash tools/test-game-running.sh   old substring test swapped in; must exit 1
# Refuses while the real game is running, since that would make every negative case true.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SHIM="$HOME/Applications/Surviving Mars Relaunched.app/Contents/MacOS/launch"
eval "$(grep -E '^(APP|SS|GAME)=' "$HERE/launch-relaunched.sh")"
eval "$(sed -n '/^game_running() {/,/^}/p' "$HERE/launch-relaunched.sh")"
[ "$(type -t game_running)" = function ] || { echo "REFUSED: game_running not found in the launcher"; exit 2; }
if [ -f "$SHIM" ]; then
  eval "$(grep '^GAME_EXE=' "$SHIM")"
  eval "shim_running() { $(sed -n '/^running=0$/,/^done$/p' "$SHIM")
  [ \"\$running\" = 1 ]; }"
else
  echo "NOTE: no app shim at $SHIM (run make-app.sh); testing the launcher only"
fi
if [ "${MUTANT:-0}" = 1 ]; then
  game_running() { pgrep -f 'Mars\.exe' >/dev/null; }
  shim_running() { pgrep -f '/Mars\.exe' >/dev/null; }
fi
game_running && { echo "REFUSED: the game (or a fixture) is running"; exit 2; }

fails=0
PIDS=()
stop_all() { for p in ${PIDS[@]+"${PIDS[@]}"}; do pkill -P "$p" 2>/dev/null; kill "$p" 2>/dev/null; done; wait 2>/dev/null; PIDS=(); }
trap stop_all EXIT
check() {   # <name> <expected 0|1> -- 1 = "running" expected
  local name=$1 want=$2 got
  sleep 0.5   # let the fixture exec before it is looked for
  for fn in game_running shim_running; do
    [ "$(type -t $fn)" = function ] || continue
    $fn && got=1 || got=0
    if [ "$got" = "$want" ]; then echo "PASS  $fn  $name"; else echo "FAIL  $fn  $name (got $got, want $want)"; fails=$((fails + 1)); fi
  done
  stop_all
}

bash -c 'sleep 30; : Mars.exe' 2>/dev/null & PIDS+=($!)
check "a shell that names the file" 0
bash -c "sleep 30; : '$GAME/Mars.exe'" 2>/dev/null & PIDS+=($!)
check "a shell that names the full path" 0
(exec -a "$GAME/Mars.exe" sleep 30) & PIDS+=($!)
check "the game, unix path (as the launcher starts it)" 1
(exec -a 'C:\Program Files (x86)\Steam\steamapps\common\Project Spark\Mars.exe' sleep 30) & PIDS+=($!)
check "the game, C:\\ path (as Steam starts it)" 1

echo "$fails failure(s)"
[ "$fails" = 0 ]
