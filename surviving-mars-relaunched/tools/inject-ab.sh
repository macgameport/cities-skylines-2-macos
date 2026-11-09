#!/bin/bash
# inject-ab.sh [inf|nan]  -- the mechanism A/B for patch-window-origin.py, no Steam launch, no window.
# Builds two scratch copies of the game binary (stock, patched) beside symlinks to the game data and
# a steam_appid.txt (so SteamAPI_RestartAppIfNecessary does not hand the launch to Steam), injects
# the value into the uninitialised origin.y slot under lldb, and expects:
#   stock   -> TRAPPED  in _NSViewValidateGeometry <- NSViewValidateRect (the 2026-10-30 crash chain)
#   patched -> ACCEPTED (initWithContentRect: returns)
# Full logs: ~/sm-patch/runs/inject-<arm>-<val>.log
set -u
VAL=${1:-inf}
G="$HOME/Library/Application Support/Steam/steamapps/common/Surviving Mars"
S="$HOME/sm-patch/scratch"; R="$HOME/sm-patch/runs"; T="$HOME/sm-patch/tools"
PY=/Applications/Xcode.app/Contents/Developer/usr/bin/python3
arch -x86_64 /usr/bin/true 2>/dev/null || { echo "REFUSED: Rosetta missing (softwareupdate --install-rosetta --agree-to-license)"; exit 2; }
pgrep -f 'MarsSteam.app/Contents/MacOS/MarsSteam' >/dev/null && { echo "REFUSED: a MarsSteam is running"; exit 2; }
mkdir -p "$R"
for arm in stock patched; do
  d="$S/$arm"; rm -rf "$d"; mkdir -p "$d"
  cp -R "$G/MarsSteam.app" "$d/"
  for e in DLC Licenses Local Movies Packs; do ln -s "$G/$e" "$d/$e"; done
  echo 464920 > "$d/steam_appid.txt"
done
python3 "$HOME/sm-patch/patch-window-origin.py" "$S/stock/MarsSteam.app/Contents/MacOS/MarsSteam" | tail -1
python3 "$HOME/sm-patch/patch-window-origin.py" apply "$S/patched/MarsSteam.app/Contents/MacOS/MarsSteam" | tail -1
rc=0
for arm in stock patched; do
  log="$R/inject-$arm-$VAL.log"
  (cd / && PYTHONPATH="$(lldb -P)" perl -e 'alarm 90; exec @ARGV' "$PY" "$T/inject.py" \
     "$S/$arm/MarsSteam.app/Contents/MacOS/MarsSteam" "$S/$arm" "$VAL") >"$log" 2>&1
  # an alarm-killed lldb orphans the debuggee + Rosetta's debugserver (hung the game 2026-10-30)
  for p in $(pgrep -f "$S/$arm/MarsSteam.app"); do kill -KILL "$p" 2>/dev/null; done
  for p in $(pgrep -f 'oah/debugserver'); do kill -TERM "$p" 2>/dev/null; done
  v=$(grep '^VERDICT:' "$log" | tail -1)
  want=$([ "$arm" = stock ] && echo TRAPPED || echo ACCEPTED)
  echo "$arm: ${v:-VERDICT: none (see $log)}  (want $want)"
  grep -E '^entry|^injected|^stop|^   ' "$log" | sed 's/^/    /'
  [ "${v#VERDICT: }" = "$want" ] || rc=1
done
pgrep -lf 'MarsSteam|oah/debugserver' && { echo "WARN: leftovers above"; rc=1; }
echo "AB: $([ $rc = 0 ] && echo PASS || echo FAIL)"
exit $rc
