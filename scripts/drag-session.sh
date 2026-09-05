#!/bin/bash
# drag-session.sh — one live-drag measurement, set up end to end.
#
#   bash scripts/drag-session.sh t0      # diag-pre : stage 1 + colours   (issue #7 T0's live half)
#   bash scripts/drag-session.sh t2b     # diag-fix : stage 2 + colours   (T2b)
#   bash scripts/drag-session.sh t3      # prod     : stage 2, no colours (T3 — James's verdict)
#   bash scripts/drag-session.sh s1      # the stage-1 daily driver, no colours (a baseline)
#   DRAG=synth bash scripts/drag-session.sh <role>   # no hands: the driver runs the size loop itself
#   DRAG=synth SYNTH_PX=8 SYNTH_MS=16 SYNTH_REPEAT=3 ... <role>   # cadence and repeats, see below
#   CAPTURE=screen DRAG=synth ... <role>   # the #12 control: frames off the composited display
#
# A drag is the only measurement that reaches stage 2, and until 2026-09-04 that meant a human:
# shimmer-probe drives SetWindowPos, which never enters the resize path a drag takes. What a drag
# takes on this stack is NOT AppKit's live resize (in_resize was 0 in every event ever captured,
# ledger C46) but win32u's own SC_SIZE loop -- Steam's SDL window hit-tests its border, DefWindowProc
# turns the press into SC_SIZE, and sys_command_size_move issues one SetWindowPos per mouse move
# (SysCommand f002/f003 in both real drags). `win-resize-driver.exe sizedrag` presses in that border
# and moves, so DRAG=synth runs the same loop with nobody at the mouse; a human drag (the default)
# remains the acceptance test. Keep hands off the mouse during a synthetic run.
#
# It shuts Steam down, installs the right module, brings Steam up through the cell harness (so the
# run is fingerprinted and a run with no font library is refused), navigates to the store, then
# waits for you -- or drags. Then it scores. The daily driver is restored on the way out, always.
#
# THE DRAG, the same every time so runs compare:
#   1. grab the RIGHT edge, pull out ~300 px over about 5 seconds, hold a moment
#   2. grab the TOP edge, pull up ~150 px
#   3. let go
# Slow and steady beats fast: the defect is a lag, and a quick flick can outrun the sampler.
# (macgameport, 2026-09-03)
set -u
ROLE="${1:?usage: [DRAG=synth] drag-session.sh t0|t2b|t3|s1}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SS="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}/Contents/SharedSupport"
W="$SS/wine/bin/wine64"; S="$SS/prefix/drive_c/Program Files (x86)/Steam"
INST="$SS/wine/lib/wine/x86_64-unix/winemac.so"
DAILY="$HOME/cs2-patch/winemac.so.stage1"
# The first two runs never pre-sized: this variable was read but never set, and under `set -u` the
# command substitution that used it died silently, leaving DH empty and the step skipped.
DRV="${CS2_DRIVER:-$HOME/cs2-patch/win-resize-driver.exe}"
# +cursor shows macdrv_SetCapture at both ends of the size loop; +timestamp makes T6's "3 s after
# the last size change" a measurement (t6-scale-at-rest.py reads the stamps when they are there).
TRACE="${TRACE:-+err,+macdrv,+cursor,+timestamp}"
# Synthetic cadence. A hand moving ~60 px/s feeds the loop ~1 px per mouse event at 60-125 Hz; the
# first run (2 px every 60 ms, a quarter of that rate) gave the pipeline time to catch up per step
# and showed no strip at all on stage 1 (0/60), so a slow synthetic drag is not the defect's drag.
SYNTH_MS="${SYNTH_MS:-16}"; SYNTH_PX="${SYNTH_PX:-1}"
# Distances. A coarse cadence needs a longer pull to keep the probe sampling during motion, and
# a longer pull needs a narrower start (PRESIZE) so the screen has the room.
SYNTH_DX="${SYNTH_DX:-300}"; SYNTH_DY="${SYNTH_DY:-150}"
# Repeats. A coarse cadence finishes a pull in a second or two, before the probe has sampled much;
# SYNTH_REPEAT=n pulls the right edge out, back, out again -- n grow segments under the sampler,
# each its own press, the way a hand re-grabs.
SYNTH_REPEAT="${SYNTH_REPEAT:-1}"
# Pause between presses. At 8 px / 16 ms a press one second after a 770 px grow only half took
# (8 px, then nothing) and the next two did not take at all (K1, 2026-09-05); the fine cadence
# never needed more than a second. Coarse runs use 3. Keep the window clear of the screen edge
# too: a grow from 1868 px on a 1920 px display cannot take, the loop clamps the cursor.
SYNTH_PAUSE="${SYNTH_PAUSE:-1}"

case "$ROLE" in
  t0)  MOD="$HOME/cs2-patch/winemac.so.s1-diag"; WHAT="diag-pre — stage 1 + colours" ;;
  t2b) MOD="$HOME/cs2-patch/winemac.so.s2b-diag"; WHAT="diag-fix — stage 2 (win32u signal) + colours" ;;
  t3)  MOD="$HOME/cs2-patch/winemac.so.s2b";      WHAT="prod — stage 2 (win32u signal), no colours" ;;
  s1)  MOD="$DAILY";                             WHAT="stage 1 daily driver, no colours" ;;
  *)   echo "unknown role '$ROLE' (t0|t2b|t3|s1)"; exit 2 ;;
esac
# MODULE=<path> swaps the role's module for another build of the same shape -- a mutant, say --
# without inventing a role for it; the run dir and cell label still carry the role.
[ -n "${MODULE:-}" ] && { MOD="$MODULE"; WHAT="$WHAT — module override $(basename "$MODULE")"; }
[ -f "$MOD" ] || { echo "missing module $MOD — build it first"; exit 2; }

OUT="${DRAG_OUT:-$HOME/cs2-patch/drag/$ROLE-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"
export WINEPREFIX="$SS/prefix"
export DYLD_FALLBACK_LIBRARY_PATH="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"

_owns() { lsof -p "$1" 2>/dev/null | grep -q "$WINEPREFIX"; }
steam_up() { for p in $(pgrep -f "steam.exe" 2>/dev/null); do _owns "$p" && return 0; done; return 1; }
steam_family() { for p in $(pgrep -f "steam" 2>/dev/null); do _owns "$p" && echo "$p"; done; }
down() {   # never kill -9 steam.exe: a 0-byte .crash makes the next launch exit 1
  steam_up && WINEDEBUG=-all "$W" "$S/steam.exe" -shutdown >/dev/null 2>&1
  for _ in $(seq 30); do steam_up || break; sleep 1; done
  steam_up && { "$SS/wine/bin/wineserver" -k >/dev/null 2>&1; sleep 3; }
  local left; left=$(steam_family | tr '\n' ' ')
  [ -n "$left" ] && { "$SS/wine/bin/wineserver" -k >/dev/null 2>&1; sleep 2
                      left=$(steam_family | tr '\n' ' '); [ -n "$left" ] && kill $left 2>/dev/null; }
  return 0
}
CAF=""
restore() {                      # ALWAYS leave the machine on the daily driver
  [ -n "$CAF" ] && kill "$CAF" 2>/dev/null
  down
  cp "$DAILY" "$INST" 2>/dev/null &&
    echo "  daily driver restored: $(shasum -a 256 "$INST" | cut -c1-16)"
}
trap restore EXIT
caffeinate -d -i -u -t 5400 & CAF=$!

echo "########## drag session $ROLE — $WHAT"
echo "  run dir: $OUT"
down
cp "$MOD" "$INST" || exit 1
echo "  module:  $(shasum -a 256 "$INST" | cut -c1-16)"

WINEDEBUG="$TRACE" bash "$REPO/scripts/steam-render-cell.sh" \
    --label "drag-$ROLE-$(basename "$OUT")" --keep-running >"$OUT/cell.txt" 2>&1
steam_up || { echo "  VOID: $(grep -m1 FATAL "$OUT/cell.txt" | cut -c1-120)"; exit 1; }
WINEDEBUG=-all "$W" "$S/steam.exe" steam://store >/dev/null 2>&1; sleep 15

# Shrink the window first, so the drag has somewhere to GROW. The defect is on the growing edge, and
# the first run (2026-09-04, t0) opened at 1853x994 with little headroom: the drag oscillated
# between 1561 and 1852 and ended near where it started, producing 1 exposed frame in 60 against a
# 19/60 baseline. A drag that cannot grow measures the wrong half of the problem.
DH=$(WINEDEBUG=-all "$W" "$DRV" list 2>/dev/null | tr -d '\r' \
     | grep 'class=SDL_app' | grep 'title=Steam$' | awk '{print $1}' | head -1)
if [ -n "${DH:-}" ]; then
  WINEDEBUG=-all "$W" "$DRV" drive "$DH" "${PRESIZE:-1400x700}" >/dev/null 2>&1
  sleep 2
  # ... and DOWN. Steam opens flush under the menu bar (top edge at y=30), and a top-edge drag
  # cannot grow a window that is already at the work area's top: the size loop clamps the cursor
  # to rcWork, so the loop runs (GUI_INMOVESIZE set on 100 of 100 polls, 2026-09-04) and the
  # height never changes. Both human runs lost their top-edge segment that way (C45, C46).
  WINEDEBUG=-all "$W" "$DRV" move "$DH" "+0,${PREMOVE_DOWN:-150}" 2>/dev/null | tr -d '\r' | sed 's/^/  /'
  sleep 2
  echo "  pre-sized to ${PRESIZE:-1400x700} and moved down — room to pull right and up"
else
  echo "  WARNING: no SDL_app Steam window found by the driver — not pre-sized"
fi

if [ "${DRAG:-human}" = synth ]; then
  [ -n "${DH:-}" ] || { echo "  VOID: a synthetic drag needs the window handle"; exit 1; }
  echo "  synthetic drag: right edge +${SYNTH_DX} px (x${SYNTH_REPEAT}), then top edge -${SYNTH_DY} px, ${SYNTH_PX} px every ${SYNTH_MS} ms"
  ( OUT_DIR="$OUT/frames" WAIT=120 FRAMES=60 CAPTURE="${CAPTURE:-window}" bash "$REPO/scripts/livedrag-probe.sh" >"$OUT/probe.txt" 2>&1 ) &
  PROBE=$!
  # the probe arms after the window settles; drag only once it says so (or once it has given up)
  for _ in $(seq 120); do
    grep -q "DRAG A WINDOW EDGE NOW\|ABORT\|VOID" "$OUT/probe.txt" 2>/dev/null && break
    kill -0 "$PROBE" 2>/dev/null || break
    sleep 1
  done
  sleep 1
  # One press, re-pressed ONCE if the loop ended before it resized. An app activation mid-loop makes
  # SDL's focus handler call SetCapture(hwnd) then ReleaseCapture, which clears GUI_INMOVESIZE and
  # ends win32u's loop as if the button had come up: S-A of 2026-09-04 (flag set on 66 of 300
  # polls, size unchanged, `macdrv_app_activated` 300 trace lines into the loop), and the first
  # press of the human t2b drag went the same way. A hand re-grabs; so does this.
  press() {   # press <edge> <dx,dy> <steps> <file>
    local try
    for try in 1 2; do
      WINEDEBUG=-all "$W" "$DRV" sizedrag "$DH" "$1" "$2" "$3" "$SYNTH_MS" 2>&1 | tr -d '\r' | tee -a "$4"
      tail -1 "$4" | grep -q 'DID NOT TAKE' || return 0
      [ "$try" = 1 ] && { echo "  press did not take -- re-pressing once"; sleep 2; }
    done
    return 1
  }
  for r in $(seq "$SYNTH_REPEAT"); do
    press right "+${SYNTH_DX},+0" $((SYNTH_DX / SYNTH_PX)) "$OUT/sizedrag-right.txt"
    [ "$r" -lt "$SYNTH_REPEAT" ] && { sleep "$SYNTH_PAUSE"; press right "-${SYNTH_DX},+0" $((SYNTH_DX / SYNTH_PX)) "$OUT/sizedrag-right.txt"; }
    sleep "$SYNTH_PAUSE"
  done
  press top "+0,-${SYNTH_DY}" $((SYNTH_DY / SYNTH_PX)) "$OUT/sizedrag-top.txt"
  wait "$PROBE"
  cat "$OUT/probe.txt"
else
cat <<'MSG'

  ---------------------------------------------------------------
   Steam is up on the store page, sized down and moved down so both
   edges below have room to grow. When the probe says it is armed:

     1. grab the RIGHT edge, pull out ~300 px over about 5 seconds
     2. hold a moment
     3. grab the TOP edge, pull up ~150 px
     4. let go

   Slow and steady. It waits up to 30 minutes, so there is no rush.
  ---------------------------------------------------------------

MSG
OUT_DIR="$OUT/frames" WAIT=1800 FRAMES=60 CAPTURE="${CAPTURE:-window}" bash "$REPO/scripts/livedrag-probe.sh" 2>&1 | tee "$OUT/probe.txt"
fi

echo
echo "########## scoring"
[ -x /tmp/darkboxes ] || swiftc -O "$REPO/scripts/darkboxes.swift" -o /tmp/darkboxes
n=$(ls "$OUT/frames"/f*.png 2>/dev/null | wc -l | tr -d ' ')
if [ "$n" = 0 ]; then echo "  VOID: no frames captured"; else
  /tmp/darkboxes 6 "$OUT/frames"/f*.png > "$OUT/bands.txt" 2>/dev/null
  python3 "$REPO/scripts/band-counts.py" "$OUT/bands.txt" | sed 's/^/  /'
  [ "$ROLE" != t3 ] && python3 "$REPO/scripts/darkboxes-attrib.py" 6 "$OUT/frames"/f*.png \
      > "$OUT/attrib.txt" 2>&1 && tail -1 "$OUT/attrib.txt" | sed 's/^/  /'
  cp /tmp/steam-cell-drag-$ROLE-$(basename "$OUT")/stdout.txt "$OUT/stdout.txt" 2>/dev/null
  cnt() { grep -cE "$1" "$OUT/stdout.txt" 2>/dev/null || true; }   # grep -c prints 0 itself; no `|| echo 0`
  # Which resize path the drag took, from the trace. SC_SIZE + a WMSZ_* edge code in the low
  # nibble is DefWindowProc's size loop; SetCapture with GUI_INMOVESIZE (0x2) is that loop handing
  # the driver its start and end (+cursor only); `size/move loop 1` is the module reading the
  # signal on a root pass (stage 2 rebuilt on it, 2026-09-04).
  echo "  SC_SIZE via win32u's loop (SysCommand f001-f008): $(cnt 'macdrv_SysCommand .*, f00[1-8], ')"
  echo "  GUI_INMOVESIZE capture handed to the driver:     $(cnt 'macdrv_SetCapture.*flags 0x00000002')   (0 unless TRACE has +cursor)"
  echo "  root passes reading the loop as set / clear:     $(cnt 'size/move loop 1') / $(cnt 'size/move loop 0')"
  echo "  stage-2 stretches fired: $(cnt 'live resize')   declined: $(cnt 'not full-client')   end-of-loop re-derives: $(cnt 'macdrv_size_move_ended')"
  python3 "$REPO/scripts/t6-scale-at-rest.py" "$OUT/stdout.txt" 2>&1 | tail -3 | sed 's/^/  /'
fi
echo "########## done — $OUT"
