#!/bin/bash
# licence-wait-probe.sh <seconds> [runs]   plan C2/T9: does a shorter licence wait still reach the menu?
# licence-wait-probe.sh --judge <game log> judge one of the game's own logs, no launch
#
# Launches the game <runs> (default 5) times through launch-relaunched.sh with SM_LICENCE_WAIT=<seconds>,
# judges each run from the game's own log, quits the game at the main menu and lets the launcher close
# Steam. Every launch starts Steam fresh (the launcher shuts it down at exit), so each run pays the wait;
# a run whose launcher log lacks "Waiting <seconds> s" did not exercise it and is VOID.
#
# PASS = the game logged `Steam initialized`, both DLCs loaded (`DLC norman`, `DLC thomas`) and
# `[Braze] Initialized` -- the last line all 23 full start-ups on record share, ~11 s in, with the menu
# up -- with no other error/fail line (every start logs `Failed activating D3D12 Dred`; the Fix Pack's
# counters and PdxSDK's autologin are not Steam), the Fix Pack's `Available DLCs:` line, when it logs
# one, naming both; the game still up 10 s after that; and the launcher exiting 0. The licence race cs2
# measured shows as SteamAPI failing to verify ownership, which here would be a missing `Steam
# initialized`, no DLC lines or a short DLC list. One failed run is the result: keep the default (plan C2).
# `--judge` over the 24 logs on record (2026-11-08): 23 PASS, 1 FAIL (a 28-line start-up crash).
#
# Measured 2026-11-08 (Studio): 5/5 PASS at 30 s, then 5/5 PASS at 15 s; menu at sign-in + 54 s and
# + 39 s, against + 57 s with the old 45 s default. The default went to 15 on this. All ten runs sat a
# fixed 13.5 s between `Build branch` and `Account storage loaded`; so did 7 of the 23 earlier 45 s
# runs (the other 16: 2.1-9.7 s). Cause not identified -- Steam's logs and Wine's output do not differ
# between stalled and quick runs -- and it is not a wait for a moment after sign-in: that reading came
# from the 30 s runs alone, where the stall happens to end at sign-in + 48 s.
#
# The game is fullscreen on this Mac's screen for ~30 s per run. Refuses while the game, a Steam of this
# wrapper or a launcher lock exists. The quit is Wine's taskkill without /F (WM_CLOSE; the game logs
# `WM_QUIT` and exits by itself), SIGTERM to the game's pids after 20 s if not -- never steam.exe.
# Output: $SM_STATE/runs/licence-<seconds>/ (SM_STATE as in launch-relaunched.sh), run-N.launcher.log + run-N.game.log, one summary line per run;
# exit 0 = every run passed.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SM_STATE="${SM_STATE:-$HOME/Library/Application Support/1launcher/surviving-mars-relaunched}"
L="$HERE/launch-relaunched.sh"

# The game buffers its log and flushes it on exit, and its timestamp writer can land mid-line (run 2,
# 2026-11-08: `Available DLCs: <tab>Lua 0:00:18:046` with the list on the next line). Judge the flushed
# log with the timestamps stripped and a list-less `Available DLCs:` joined to its next line.
cleaned() { awk '{ gsub(/\t+(Lua|Render) [0-9:]*/, "") } /^Available DLCs: *$/ { printf "%s", $0; next } { print }' "$1"; }   # BSD sed has no \t
lua_at() {  # <game log> <text> -> the Lua/Render timestamp preceding the first line holding <text>
  awk -v pat="$2" '/^\t+(Lua|Render) /{ ts = $0; gsub(/\t|Lua |Render /, "", ts); next } index($0, pat) { print ts; exit }' "$1"
}
judge() {   # <game log> -> "PASS|FAIL <why>" from the game's log alone
  local g="$1" why="" c e
  c=$(cleaned "$g")
  [ "$(echo "$c" | grep -c 'Steam initialized')" = 1 ] || why="$why no-steam-init"
  [ "$(echo "$c" | grep -c '^DLC [a-z]* loaded')" = 2 ] || why="$why dlc=$(echo "$c" | grep -c '^DLC [a-z]* loaded')"
  # the Fix Pack logs the DLCs Steam says are owned (its logs since 2026-11-03); when present, both must be there
  if echo "$c" | grep -q '^Available DLCs:'; then echo "$c" | grep -q '^Available DLCs: *norman(.*thomas(' || why="$why dlc-list: $(echo "$c" | grep -m1 '^Available DLCs:' | cut -c17-60)"; fi
  echo "$c" | grep -q '\[Braze\] Initialized' || why="$why no-menu"
  e=$(echo "$c" | grep -i 'error\|fail' | grep -v 'D3D12 Dred\|^\[mod\]\|^\[PdxSDK' | head -3 | tr '\n' ';')
  [ -z "$e" ] || why="$why errors: $e"
  [ -n "$why" ] && echo "FAIL$why" || echo PASS
}
if [ "${1:-}" = --judge ]; then judge "${2:?usage: --judge <game log>}"; exit; fi

SECS="${1:?usage: licence-wait-probe.sh <seconds> [runs] | --judge <game log>}"; RUNS="${2:-5}"
eval "$(grep -E '^(APP|SS|GAME|ENGINE)=' "$L")"
export WINEPREFIX="$SS/prefix" WINEESYNC=1 WINEMSYNC=1 WINEDEBUG=-all
export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$ENGINE/lib:/usr/lib:/usr/local/lib"
WINE="$ENGINE/bin/wine64"
eval "$(grep '^_owns() {' "$L")"
eval "$(sed -n '/^steam_exe_up() {/,/^}/p' "$L")"
eval "$(sed -n '/^game_running() {/,/^}/p' "$L")"
for f in _owns steam_exe_up game_running; do [ "$(type -t $f)" = function ] || { echo "REFUSED: $f not found in the launcher"; exit 2; }; done
GLOGS=$(ls -d "$WINEPREFIX"/drive_c/users/*/AppData/Roaming/"Surviving Mars Relaunched"/logs 2>/dev/null | head -1)
[ -d "$GLOGS" ] || { echo "REFUSED: no game log dir under $WINEPREFIX"; exit 2; }
game_running && { echo "REFUSED: the game is running"; exit 2; }
steam_exe_up && { echo "REFUSED: this wrapper's Steam is running"; exit 2; }
[ -L "$WINEPREFIX/.launcher.lock" ] && { echo "REFUSED: a launcher lock exists ($(readlink "$WINEPREFIX/.launcher.lock"))"; exit 2; }
OUT="$SM_STATE/runs/licence-$SECS"; mkdir -p "$OUT"
game_pids() { for _p in $(pgrep -f 'Mars\.exe' 2>/dev/null); do case "$(ps -o command= -p "$_p" 2>/dev/null)" in "$GAME/Mars.exe"*) echo "$_p" ;; esac; done; }
ts() { date +%H:%M:%S; }

fails=0
echo "licence wait $SECS s, $RUNS run(s), $(date '+%Y-%m-%d %H:%M'), host $(scutil --get LocalHostName), output $OUT"
for r in $(seq 1 "$RUNS"); do
  LL="$OUT/run-$r.launcher.log"
  prev=$(ls -t "$GLOGS"/Mars.exe-*.log 2>/dev/null | head -1)
  t0=$(date +%s)
  SM_LICENCE_WAIT="$SECS" bash "$L" > "$LL" 2>&1 &
  LP=$!
  glog=""
  for _ in $(seq 1 150); do          # sign-in (<= 120 s) + the wait + the cloud sync + the game's start
    g=$(ls -t "$GLOGS"/Mars.exe-*.log 2>/dev/null | head -1)
    [ -n "$g" ] && [ "$g" != "$prev" ] && { glog="$g"; break; }
    kill -0 "$LP" 2>/dev/null || break
    sleep 2
  done
  tg=$(date +%s)
  if [ -n "$glog" ]; then   # the log is buffered until exit: give the menu 40 s (slowest on record: 22 s), then quit
    for _ in $(seq 1 20); do game_running || break; sleep 2; done
  fi
  alive=no; game_running && alive=yes
  if game_running; then
    "$WINE" taskkill /IM Mars.exe >/dev/null 2>&1
    for _ in $(seq 1 20); do game_running || break; sleep 1; done
    game_running && { echo "  run $r: taskkill did not close the game; SIGTERM to $(game_pids | tr '\n' ' ')"; kill $(game_pids) 2>/dev/null; }
  fi
  wait "$LP"; lrc=$?
  [ -n "$glog" ] && cp "$glog" "$OUT/run-$r.game.log"
  waited=$(grep -c "Waiting $SECS s" "$LL")
  v=VOID
  if [ "$waited" != 1 ]; then v="VOID (licence wait not run: $(grep -m1 'ERROR\|already running' "$LL" | cut -c1-80))"
  elif [ -z "$glog" ]; then v="FAIL no game log within $((tg - t0)) s: $(grep -m1 'ERROR' "$LL" | cut -c1-80)"
  else
    v=$(judge "$glog")
    [ "$alive" = yes ] || v="FAIL game gone before the dwell ended ($v)"
    [ "$lrc" = 0 ] || v="FAIL launcher rc $lrc ($v)"
  fi
  case "$v" in PASS) ;; *) fails=$((fails + 1)) ;; esac
  echo "  run $r: $v | game +$((tg - t0)) s, account storage at $(lua_at "${glog:-/dev/null}" 'Account storage'), menu at $(lua_at "${glog:-/dev/null}" '[Braze] Initialized'), $(grep -c 'WM_QUIT' "${glog:-/dev/null}") WM_QUIT | launcher: $(grep -m1 'Steam Cloud:' "$LL" | cut -c1-40), rc $lrc"
  for _ in $(seq 1 30); do steam_exe_up || break; sleep 1; done
  steam_exe_up && { echo "  Steam still up after run $r; stopping here"; fails=$((fails + 1)); break; }
  [ "$r" -lt "$RUNS" ] && sleep 5
done
echo "$fails failure(s) of $RUNS at SM_LICENCE_WAIT=$SECS"
[ "$fails" = 0 ]
