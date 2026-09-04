#!/bin/bash
# hosting-layer-tests.sh — the cross-process hosting-layer tests, in one command.
#
#   bash scripts/hosting-layer-tests.sh              # T0 T1 T2 + the regression rows
#   bash scripts/hosting-layer-tests.sh --mutants    # + rebuild/install each mutant, then restore
#   bash scripts/hosting-layer-tests.sh --list       # what it runs, no Steam
#
# Plan: docs/plans/hosting-layer-design-gaps.md (T0-T9). Run it DETACHED with a log; a tool timeout
# kills the process group and takes Steam with it.
#
# WHY THIS IS COMMITTED. On 2026-09-03 these tests were driven by throwaway scripts and SEVEN
# harness defects came out of them, every one producing a plausible wrong answer rather than an
# error. Each is encoded below so it cannot recur:
#
#   1. macOS ships bash 3.2 — no `mapfile`, no `${var,,}`. Both are fatal at the point of use, and
#      one hit before the shutdown line and left Steam running for the next run to trip over.
#   2. A `cd` inside a helper leaked into the caller, so `scripts/...` was no longer found and the
#      failure surfaced as "no steam". Every cd is in a subshell here.
#   3. Shutdown checked only steam.exe. Webhelpers outlive it, reparent to launchd and carry
#      Windows-style argv, so three were left holding the prefix. Sweep the family by prefix.
#   4. Diagnostics printed to stdout were swallowed by `x=$(...)`, so a failed step looked like a
#      step that never ran. Diagnostics go to stderr; stdout is the value.
#   5. `winlist` is on-screen-only, so a fullscreen app on another Space hides Steam's window while
#      Win32 still lists it. That read as "no Steam window (sign-in still up?)". Reported as
#      OCCLUDED now, by cross-checking the Win32 list.
#   6. `screencapture -l` returns NO FILE for a window with no imageable backing store, which is
#      indistinguishable from black in a size check. Raise the window first.
#   7. The cell harness's own refusal (`preconditions: N fatal -> VOID`) was ignored and reported as
#      "no steam". Its FATAL line is surfaced verbatim.
#
# And two test-design facts, each of which cost a run:
#   * Pick the child from the CREATE trace, NOT by size from the tree. A Chrome_RenderWidgetHostHWND
#     is large and never hosted, so moving it correctly changes nothing and proves nothing.
#   * Among hosted children, moving one whose layer sits BEHIND another is equally invisible, and
#     produces the same reading as a layer that failed to follow. So T1 does not trust one child:
#     it tries each in turn and accepts only a DECISIVE answer — content shifted by exactly the
#     delta (green), or the capture unchanged at both strips (red). Anything else is that child
#     being invisible, and it moves on. Reporting an ambiguous child as red is how a void run got
#     recorded as a failure and a red mutant as green.
#   * A hosted child parked at 0x0 is the inactive browser (ledger C14); skip it.
#   * T1 runs on the LIBRARY and T2 on the STORE, and the pages are not interchangeable. T2 needs
#     the store's two non-zero overlapping CefBrowserWindow siblings; T1 cannot use the store,
#     because its autoplaying video changes the capture between shots and every column then reads
#     "changed", which is indistinguishable from the layer having moved.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SS="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}/Contents/SharedSupport"
W="$SS/wine/bin/wine64"; S="$SS/prefix/drive_c/Program Files (x86)/Steam"
DRV="${CS2_DRIVER:-$HOME/cs2-patch/win-resize-driver.exe}"
SRC="${WINEMAC_SRC:-$HOME/cs2-patch/build-1116/wine-11.16-dxmt/dlls/winemac.drv}"
BD="${WINEMAC_BUILD:-$HOME/cs2-patch/build-1116/wine-1116-vis-build}"
INST="$SS/wine/lib/wine/x86_64-unix/winemac.so"
OUT="${OUT_DIR:-$HOME/cs2-patch/hosting-layer-tests/$(date +%Y%m%d-%H%M%S)}"
# Every build here comes from whatever branch $SRC happens to have checked out, and the nested repo
# keeps `core` (the stock-applicable subset) beside `main` (= aquadran + core + the DXMT glue). A
# core build installs and loads, then Steam's GPU process dies with c0000409 and nothing renders --
# and a battery of tests against a black window reports plausible numbers, not an error. Cost two
# sessions on 2026-09-03; GOTCHAS, "A module built off the wrong branch renders black".
_br=$(git -C "$SRC" rev-parse --abbrev-ref HEAD 2>/dev/null)
[ "$_br" = main ] || { echo "REFUSED: $SRC is on '$_br', not main -- a core build has no DXMT glue"
                       exit 2; }
MUTANTS=0
case "${1:-}" in
  --list) sed -n '/^# Plan:/,/^set -u/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --mutants) MUTANTS=1 ;;
  "") ;;
  *) echo "unknown arg: $1" >&2; exit 64 ;;
esac
mkdir -p "$OUT"
export WINEPREFIX="$SS/prefix"
export DYLD_FALLBACK_LIBRARY_PATH="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"

# the cell harness caffeinates only its own ~215 s window; these tests keep working after it, and
# a display that sleeps mid-run makes every capture silently empty
caffeinate -d -i -u -t 3600 & CAF=$!
_owns() { lsof -p "$1" 2>/dev/null | grep -q "$WINEPREFIX"; }
steam_up() { for p in $(pgrep -f "steam.exe" 2>/dev/null); do _owns "$p" && return 0; done; return 1; }
steam_family() { for p in $(pgrep -f "steam" 2>/dev/null); do _owns "$p" && echo "$p"; done; }
down() {
  steam_up && WINEDEBUG=-all "$W" "$S/steam.exe" -shutdown >/dev/null 2>&1
  for _ in $(seq 30); do steam_up || break; sleep 1; done
  steam_up && { "$SS/wine/bin/wineserver" -k >/dev/null 2>&1; sleep 3; }
  local left; left=$(steam_family | tr '\n' ' ')
  [ -n "$left" ] && { "$SS/wine/bin/wineserver" -k >/dev/null 2>&1; sleep 2
                      left=$(steam_family | tr '\n' ' '); [ -n "$left" ] && kill $left 2>/dev/null; }
  return 0
}
cleanup() { kill $CAF 2>/dev/null; down; (cd "$SRC" && git checkout -q -- . 2>/dev/null); }
trap cleanup EXIT
drv() { WINEDEBUG=-all "$W" "$DRV" "$@" 2>/dev/null | tr -d '\r'; }
dlist() { drv list | grep 'class='; }
shot() {   # stdout = path, stderr = why not
  local id; id=$(/tmp/winlist 2>/dev/null | grep 'title=Steam$' | head -1 | sed -E 's/^id=([0-9]+).*/\1/')
  if [ -z "$id" ]; then
    if dlist | grep -q 'title=Steam$'; then
      echo "    OCCLUDED: Win32 lists the Steam window but macOS does not — something fullscreen is covering it" >&2
    else echo "    no Steam window on screen" >&2; fi
    return 1
  fi
  local hw; hw=$(dlist | grep 'title=Steam$' | awk '{print $1}' | head -1)
  [ -n "$hw" ] && { drv front "$hw" >/dev/null; sleep 1; }
  screencapture -x -o -l "$id" "$OUT/$1.png" 2>/dev/null
  [ -s "$OUT/$1.png" ] || { echo "    capture produced no file (no imageable backing store?)" >&2; return 1; }
  echo "$OUT/$1.png"
}
strip_at() { /tmp/pixel-probe "$1" strip "$2" 10 2>/dev/null | grep -oE '[0-9]+, *[0-9]+, *[0-9]+' | tr -d ' '; }
dchan() { python3 -c "
import sys
a=[int(x) for x in sys.argv[1].split(',')]; b=[int(x) for x in sys.argv[2].split(',')]
print(max(abs(p-q) for p,q in zip(a,b)))" "$1" "$2" 2>/dev/null || echo 999; }
build_install() { (cd "$BD" && gmake dlls/winemac.drv/winemac.so >"$OUT/build.log" 2>&1 \
    && cp dlls/winemac.drv/winemac.so "$INST") \
  || { echo "    BUILD FAILED"; grep -m2 'error:' "$OUT/build.log"; return 1; }
  local h; h=$(shasum -a 256 "$INST" | cut -c1-12)
  # Only a MUTANT build must differ from the clean one. The restore-green step at the end rebuilds
  # the unmutated source and is SUPPOSED to come out byte-identical — refusing it there turned a
  # correct restore into a REFUSED row on this guard's first run.
  if [ "${EXPECT_DIFFERENT:-0}" = 1 ] && [ -n "${CLEAN_SHA:-}" ] && [ "$h" = "$CLEAN_SHA" ]; then
    echo "    module $h — REFUSED: byte-identical to the clean build, this mutant changed nothing"
    return 1
  fi
  echo "    module $h"; }
cell() {   # cell <label> ; brings Steam up and leaves it running, or reports the harness's refusal
  WINEDEBUG=+err,+macdrv bash "$REPO/scripts/steam-render-cell.sh" --label "$1" --keep-running >"$OUT/$1.txt" 2>&1
  if ! steam_up; then
    local why; why=$(grep -m1 'FATAL' "$OUT/$1.txt" | sed 's/^ *//' | cut -c1-110)
    echo "    VOID: ${why:-Steam did not come up and the harness reported no FATAL}"
    return 1
  fi
  return 0
}
# hosted_candidates <label> <root> — every hosted child that currently has area, per the CREATE trace
hosted_candidates() {
  local log=/tmp/steam-cell-$1/stdout.txt tree="$OUT/$1-tree.txt" h hx line
  drv tree "$2" > "$tree"
  for h in $(grep -oE 'cross-process child 0x[0-9a-f]+' "$log" 2>/dev/null | awk '{print $3}' | sort -u); do
    hx=$(printf '%016X' $((h)))
    line=$(grep -i "child $hx" "$tree" | head -1); [ -z "$line" ] && continue
    case "$(echo "$line" | awk '{print $4}')" in 0x0|"") continue;; esac
    echo "$hx"
  done
}
# T1: try each hosted child until one gives a DECISIVE answer. A child whose layer is behind
# another is invisible, and reads exactly like a layer that failed to follow — so ambiguity is
# reported as ambiguity, never as a result.
run_t1() {
  local H b a s40 s160 nc mi lo verdict=NONE C X x
  H=$(dlist | grep 'class=SDL_app' | grep 'title=Steam$' | awk '{print $1}' | head -1)
  # LIBRARY, not the store. The plan says so and it is right: the store's autoplaying video changes
  # the capture between the before and after shots, so every column reads "changed" and the test
  # cannot separate "the layer moved" from "the page moved". Measured 2026-09-03: on the store every
  # candidate came back ambiguous with both unchanged-checks at 16-65; on the library the same test
  # is a clean 0/60. T2 still needs the store, and navigates there itself.
  WINEDEBUG=-all "$W" "$S/steam.exe" steam://open/games >/dev/null 2>&1; sleep 12
  for C in $(hosted_candidates "$1" "$H"); do
    b=$(shot "$1-$C-before") || continue
    # Find a column pair 120 apart with real contrast instead of assuming x=40/160 has it. Steam's
    # pages are frequently flat at any one place, and a flat control voided the mutant runs twice.
    X=0; nc=0
    for x in 40 120 200 300 420 560 700 860 1020 1200 1400; do
      local c; c=$(dchan "$(strip_at "$b" $x)" "$(strip_at "$b" $((x+120)))")
      [ "$c" -gt "$nc" ] && { nc=$c; X=$x; }
      [ "$nc" -gt 25 ] && break
    done
    [ "$nc" -le 8 ] && { echo "    $C: skipped, best control $nc over 11 column pairs (content is flat)"; continue; }
    s40=$(strip_at "$b" $X); s160=$(strip_at "$b" $((X+120)))
    echo "    $C: measuring at x=$X vs x=$((X+120)), control $nc"
    drv move "$C" +120,+0 >/dev/null; sleep 1
    a=$(shot "$1-$C-after") || { drv move "$C" -120,+0 >/dev/null; continue; }
    mi=$(dchan "$(strip_at "$a" $((X+120)))" "$s40")      # did before@40 arrive at 160?
    lo=$(dchan "$(strip_at "$a" $X)" "$s40")       # did 40 stop showing it?
    local same40 same160
    same40=$(dchan "$(strip_at "$a" $X)" "$s40"); same160=$(dchan "$(strip_at "$a" $((X+120)))" "$s160")
    drv move "$C" -120,+0 >/dev/null; sleep 1
    if [ "$mi" -le 8 ] && [ "$lo" -gt 8 ]; then
      echo "    $C: GREEN — content shifted +120 (moved-in $mi, left-old $lo, control $nc)"; verdict=GREEN; break
    elif [ "$same40" -le 2 ] && [ "$same160" -le 2 ]; then
      echo "    $C: RED — capture unchanged at both strips, the layer did not follow (control $nc)"; verdict=RED; break
    else
      echo "    $C: ambiguous (moved-in $mi, left-old $lo, unchanged40 $same40, unchanged160 $same160) — layer likely behind another; next"
    fi
  done
  [ "$verdict" = NONE ] && echo "    VOID: no hosted child gave a decisive answer"
  echo "    T1 verdict: $verdict"
}
echo "########## hosting-layer tests $(date '+%F %T')  module $(shasum -a 256 "$INST" | cut -c1-16)"
echo "  run dir: $OUT"
if cell main; then
  LOG=/tmp/steam-cell-main/stdout.txt
  echo "=== T0 ownership premise"
  python3 - "$LOG" <<'PY'
import re, sys, collections
log = open(sys.argv[1], errors='replace').read()
c = collections.Counter(re.findall(r'^([0-9a-f]{4}):.*WM_MACDRV_CREATE_REMOTE_LAYER', log, re.M))
x = collections.Counter(re.findall(r'^([0-9a-f]{4}):.*cross-process child', log, re.M))
print("    CREATE tids %s   acquiring tids %s" % (dict(c) or 'none', dict(x) or 'none'))
print("    T0:", "PASS (disjoint)" if c and x and not (set(c) & set(x)) else "INCONCLUSIVE")
PY
  echo "=== T1 child-only move"; run_t1 main
  echo "=== T2 z restack (needs two non-zero CefBrowserWindow siblings; the store page has them)"
  H=$(dlist | grep 'class=SDL_app' | grep 'title=Steam$' | awk '{print $1}' | head -1)
  WINEDEBUG=-all "$W" "$S/steam.exe" steam://store >/dev/null 2>&1; sleep 12
  drv tree "$H" > "$OUT/t2-tree.txt"
  SIB=$(awk '$1=="child" && $NF ~ /CefBrowserWindow/ && $4 !~ /^0x0$/ {print $2}' "$OUT/t2-tree.txt" | tr '\n' ' ')
  set -- $SIB
  if [ $# -ge 2 ]; then
    b=$(shot t2-base) && { s=$(strip_at "$b" 400)
      drv front "$1" >/dev/null; sleep 2; m=$(shot t2-f0) && echo "    front $1 delta $(dchan "$(strip_at "$m" 400)" "$s")"
      drv front "$2" >/dev/null; sleep 2; m=$(shot t2-f1) && echo "    front $2 delta $(dchan "$(strip_at "$m" 400)" "$s")  (>8 = restacked)"
      # ⚠ restore the original order. Leaving the lower sibling on top puts a full-window layer over
      # the content and the client stays black (ledger C13) — every later row then measures 0.
      drv front "$1" >/dev/null; sleep 2
      r=$(shot t2-restored) && echo "    restored, delta vs base $(dchan "$(strip_at "$r" 400)" "$s")  (<=8 = back)"; }
  else echo "    VOID: only $# non-zero CefBrowserWindow sibling(s); the inactive browser is parked at 0x0 (C14)"; fi
  echo "=== T3/T4 regression rows"
  for sz in 2400x1500 2399x1499 2400x1500; do drv drive "$H" "$sz" >/dev/null; sleep 2
    f=$(shot "seq-$sz") && printf '    %-10s lum %s bright %s\n' "$sz" \
      "$(/tmp/pixel-probe "$f" 1 | grep -oE 'lum [0-9]+' | head -2 | awk '{print $2}' | tr '\n' '/')" "$(/tmp/pixel-probe "$f" 4 | grep -c BRIGHT)"; done
  SAMPLES=40 OUT_DIR="$OUT/churn" bash "$REPO/scripts/shimmer-probe.sh" churn 2>&1 | sed 's/^/    churn /'
  sleep 20
  SAMPLES=40 OUT_DIR="$OUT/static" bash "$REPO/scripts/shimmer-probe.sh" static 2>&1 | sed 's/^/    static /'
  echo "=== T8 traces"
  for k in 'paint order incomplete' 'acquire_metal_swapchain FAILED' 'gone -- releasing hosted layer'; do
    printf '    %-36s %s\n' "$k" "$(grep -c -- "$k" "$LOG" 2>/dev/null || echo 0)"; done
  # cef_log.txt accumulates across every launch the prefix has ever had, and this marker appears
  # once per battery run — so anchoring on the FIRST match counts every crash since the first run
  # this prefix ever did. Measured 2026-09-03: 7 markers, 274 crashes in the file, "24" reported,
  # and 0 actually in this session. Reset the count at each marker so the last one wins.
  echo "    GPU crashes: $(awk -v m='=== cell main' 'index($0,m){n=0} /GPU process has crashed/{n++} END{print n+0}' "$S/logs/cef_log.txt")"
  down
fi
if [ "$MUTANTS" = 1 ]; then
  # The clean module's hash, so every mutant row can prove it is measuring a DIFFERENT binary.
  # M1's false-negative row printed `module 2a251a4b2510` -- the baseline hash -- right above its
  # verdict, and nothing compared them. A mutation can also apply and change nothing; the exit
  # status cannot see that, the hash can.
  CLEAN_SHA=$(shasum -a 256 "$INST" | cut -c1-12)
  echo "########## mutants — each applied to real source, rebuilt, observed, restored"
  echo "  clean module $CLEAN_SHA — a mutant row showing this hash measured nothing"
  # ⚠ A mutant that fails to apply must ABORT its row. It used to print a traceback and return
  # non-zero, and the caller ignored that and ran `build_install && cell && run_t1` anyway — so the
  # row was measured against an UNMUTATED module and reported as a mutant result. M1's anchor had
  # been stale since this script was committed (cab54e6): the string it looks for exists on no
  # branch — not main, not main-old, not main-raw — because D1 was rewritten to reposition only the
  # moved child, and the mutant still names the full-pass version it replaced. Every run since has
  # produced an M1 row from an unmutated build. Nothing in the ledger rested on it; caught
  # 2026-09-03 only because the traceback happened to be read.
  mutate() {  # mutate <name> <python-edit> ; leaves the tree modified. Non-zero = do not proceed.
    if (cd "$SRC" && python3 -c "$2"); then echo "    $1: applied"; return 0
    else echo "    $1: SKIPPED — the mutant did not apply, so this row measures nothing"; return 1; fi
  }
  echo "=== M1 remove the D1 refresh — the layer must stop following"
  mutate M1 "
import io; p='window.c'; s=io.open(p,encoding='utf-8').read()
o='            update_remote_layer_frame_for(data, hwnd, remote_layer_context_for(data, hwnd));'
n='            /* MUTANT M1: the D1 refresh is removed */'
assert s.count(o)==1; io.open(p,'w',encoding='utf-8').write(s.replace(o,n))" \
    && EXPECT_DIFFERENT=1 build_install && cell m1 && run_t1 m1
  down; (cd "$SRC" && git checkout -q -- window.c)
  echo "=== M2 drop SWP_NOZORDER from the moved mask — T1 must stay green"
  mutate M2 "
import io; p='window.c'; s=io.open(p,encoding='utf-8').read()
o='        BOOL moved = (~swp_flags & (SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER)) ||'
n='        BOOL moved = (~swp_flags & (SWP_NOMOVE | SWP_NOSIZE)) ||   /* MUTANT */'
assert s.count(o)==1; io.open(p,'w',encoding='utf-8').write(s.replace(o,n))" \
    && EXPECT_DIFFERENT=1 build_install && cell m2 && run_t1 m2
  down; (cd "$SRC" && git checkout -q -- window.c)
  echo "=== M3 force the depth bound to 2 — the FIXME must fire"
  mutate M3 "
import io; p='window.c'; s=io.open(p,encoding='utf-8').read()
o='#define PAINT_ORDER_DEPTH 32'; n='#define PAINT_ORDER_DEPTH 2   /* MUTANT */'
assert s.count(o)==1; io.open(p,'w',encoding='utf-8').write(s.replace(o,n))" \
    && EXPECT_DIFFERENT=1 build_install && cell m3 && {
    WINEDEBUG=-all "$W" "$S/steam.exe" steam://store >/dev/null 2>&1; sleep 12
    echo "    'paint order incomplete': $(grep -c 'paint order incomplete' /tmp/steam-cell-m3/stdout.txt 2>/dev/null || echo 0)  (>=1 = red)"; }
  down; (cd "$SRC" && git checkout -q -- window.c)
  echo "=== restore green"; build_install && cell green && run_t1 green; down
fi
echo "########## done $(date '+%T')   tree modified: $( (cd "$SRC" && git status --porcelain | wc -l) | tr -d ' ')"
