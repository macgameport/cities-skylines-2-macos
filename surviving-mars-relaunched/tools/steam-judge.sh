#!/bin/bash
# steam-judge.sh <label> [dwell-seconds]
# Launch the Steam install via steam://run/464920 (the LaunchServices path that crashed 8/8 on
# 2026-10-30), judge: CRASH (new .ips) | ALIVE (process up after dwell) | NO-LAUNCH, then quit an
# ALIVE game (AppleEvent, then TERM, then KILL -- it is the game, not Steam). ALIVE means "past the
# launch-time window trap", which fires in under a second; it does NOT mean the menu rendered.
# Output: ~/sm-patch/runs/<label>/ (no screenshots: they capture whatever app is in front).
set -u
LABEL=$1; DWELL=${2:-10}
BIN="$HOME/Library/Application Support/Steam/steamapps/common/Surviving Mars/MarsSteam.app/Contents/MacOS/MarsSteam"
OUT="$HOME/sm-patch/runs/$LABEL"; mkdir -p "$OUT"
REP="$HOME/Library/Logs/DiagnosticReports"
arch -x86_64 /usr/bin/true 2>/dev/null || { echo "REFUSED: Rosetta missing (softwareupdate --install-rosetta --agree-to-license)"; exit 2; }
echo "label=$LABEL sha=$(shasum -a 256 "$BIN" | cut -c1-16)"
pgrep -f "$BIN" >/dev/null && { echo "REFUSED: game already running"; exit 2; }
touch "$OUT/marker"
open "steam://run/464920"
PID=""
for ((i = 0; i < 60; i++)); do  # up to 30 s for Steam to start it
  PID=$(pgrep -f "$BIN" | head -1)
  [ -n "$PID" ] && break
  [ -n "$(find "$REP" -name 'MarsSteam-*.ips' -newer "$OUT/marker" | head -1)" ] && break
  perl -e 'select(undef,undef,undef,0.5)'
done
echo "pid=${PID:-none}"
if [ -n "$PID" ]; then
  for ((i = 0; i < DWELL * 2; i++)); do
    kill -0 "$PID" 2>/dev/null || break
    perl -e 'select(undef,undef,undef,0.5)'
  done
fi
[ -n "$PID" ] && kill -0 "$PID" 2>/dev/null || perl -e 'select(undef,undef,undef,4)'  # ReportCrash writes after exit
NEW=$(find "$REP" -name 'MarsSteam-*.ips' -newer "$OUT/marker" | head -1)
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
  VERDICT=ALIVE
  osascript -e 'tell application id "com.haemimontgames.survivingmars.steam" to quit' >/dev/null 2>&1
  for ((i = 0; i < 20; i++)); do kill -0 "$PID" 2>/dev/null || break; perl -e 'select(undef,undef,undef,0.5)'; done
  kill -0 "$PID" 2>/dev/null && { kill -TERM "$PID"; perl -e 'select(undef,undef,undef,3)'; }
  kill -0 "$PID" 2>/dev/null && kill -KILL "$PID"
  kill -0 "$PID" 2>/dev/null && echo "WARN: game still running after KILL" || echo "closed"
elif [ -n "$NEW" ]; then
  VERDICT=CRASH
  /usr/bin/python3 - "$NEW" <<'EOF'
import json,sys
s=open(sys.argv[1]).read().split('\n',1)[1]; b,_=json.JSONDecoder().raw_decode(s)
imgs=b.get('usedImages',[]); th=b['threads'][b.get('faultingThread',0)]
caller=next((fr.get('symbol') for fr in th['frames'] if (imgs[fr['imageIndex']].get('name') if fr.get('imageIndex') is not None else '')=='MarsSteam'),None)
print(' ', sys.argv[1].rsplit('/',1)[1], b.get('exception',{}).get('signal'), list((b.get('asi') or {}).values()), caller)
EOF
else
  VERDICT=NO-LAUNCH
fi
echo "VERDICT: $VERDICT" | tee "$OUT/verdict.txt"
