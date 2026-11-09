#!/bin/bash
# t1-spike.sh — the T1 GATE for docs/plans/exposed-edge-live-resize.md.
#
#   bash scripts/t1-spike.sh before   # with the BASELINE module installed
#   bash scripts/t1-spike.sh after    # with the SPIKE module installed  (also analyses)
#   bash scripts/t1-spike.sh analyse  # re-run the analysis on the two captures already taken
#
# THE QUESTION. Stage 1 replaces `host.frame = frame` with bounds + position + transform, so that a
# host whose remote content is stale gets SCALED to its new frame instead of exposing background.
# `CALayerHost` and `CAContext` are private Apple API declared in wine's own source; whether a
# hosted (out-of-process) tree honours the hosting layer's `transform` at all is UNDOCUMENTED. If it
# does not, option B is dead and the plan falls back to C/D. So this runs FIRST and alone.
#
# THE SPIKE is a fixed CATransform3DMakeScale(1.5, 1.5, 1) applied at CREATE (so it holds at rest,
# with no churn to confound the capture) on a throwaway branch. The resulting module is NOT
# pointer-operable — the visuals no longer match the HWND rects wine still hit-tests against — so it
# is reverted before any interactive use.
#
# THE MEASUREMENT. Two captures of the same Steam LIBRARY page (never the store: its autoplaying
# video changes the capture between shots and every column then reads "changed" — the trap that
# voided the battery's T1 twice, hosting-layer-tests.sh). Content that sat at host-relative x = X
# before must sit at 1.5X after:
#
#   control  dchan(before@X, before@1.5X)  > 8    the two columns differ, so the test can resolve
#   moved    dchan(after@1.5X, before@X)  <= 8    what was at X is now at 1.5X
#   left     dchan(after@X,    before@X)   > 8    and is no longer at X
#
# X is measured FROM THE HOST'S OWN ORIGIN, which is why the full-window browser (@0,30) is the
# decisive child and an inset sibling is not: for an inset host, image-x 1.5X is not host-x 1.5X.
# The after-strip is sampled 1.5x wider so both means cover the same amount of PAGE.
#
# GATE (the reason this is not just a test): both strips unchanged (<= 2) across every candidate X
# means the host IGNORED the transform. That is RED, and it kills option B rather than failing a
# test — stop and re-plan.
#
# Corroboration, not a criterion: the column-mean profile's strongest horizontal edge (the library
# sidebar boundary) is located in both captures and its ratio printed. ~1.5 is the transform.
#
# Run it DETACHED with a log — a tool timeout kills the process group and takes Steam with it.
# (macgameport, 2026-09-03)
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SS="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}/Contents/SharedSupport"
W="$SS/wine/bin/wine64"; S="$SS/prefix/drive_c/Program Files (x86)/Steam"
DRV="${CS2_DRIVER:-$HOME/cs2-patch/win-resize-driver.exe}"
INST="$SS/wine/lib/wine/x86_64-unix/winemac.so"
OUT="${OUT_DIR:-$HOME/cs2-patch/t1-spike}"          # FIXED, not timestamped: `after` reads `before`
PHASE="${1:-}"
case "$PHASE" in before|after|analyse) ;; *) echo "usage: $0 before|after|analyse" >&2; exit 64 ;; esac
mkdir -p "$OUT"
export WINEPREFIX="$SS/prefix"
export DYLD_FALLBACK_LIBRARY_PATH="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"
[ -x /tmp/pixel-probe ] || swiftc -O "$REPO/scripts/pixel-probe.swift" -o /tmp/pixel-probe || exit 1
[ -x /tmp/winlist ]     || swiftc -O "$REPO/scripts/winlist.swift"     -o /tmp/winlist     || exit 1

_owns() { lsof -p "$1" 2>/dev/null | grep -q "$WINEPREFIX"; }
steam_up() { for p in $(pgrep -f "steam.exe" 2>/dev/null); do _owns "$p" && return 0; done; return 1; }
steam_family() { for p in $(pgrep -f "steam" 2>/dev/null); do _owns "$p" && echo "$p"; done; }
down() {   # never kill -9 steam.exe: it leaves a 0-byte .crash and the next launch exits 1
  steam_up && WINEDEBUG=-all "$W" "$S/steam.exe" -shutdown >/dev/null 2>&1
  for _ in $(seq 30); do steam_up || break; sleep 1; done
  steam_up && { "$SS/wine/bin/wineserver" -k >/dev/null 2>&1; sleep 3; }
  local left; left=$(steam_family | tr '\n' ' ')
  [ -n "$left" ] && { "$SS/wine/bin/wineserver" -k >/dev/null 2>&1; sleep 2
                      left=$(steam_family | tr '\n' ' '); [ -n "$left" ] && kill $left 2>/dev/null; }
  return 0
}
drv() { WINEDEBUG=-all "$W" "$DRV" "$@" 2>/dev/null | tr -d '\r'; }

CAF=""
cleanup() { [ -n "$CAF" ] && kill "$CAF" 2>/dev/null; down; }
trap cleanup EXIT

capture() {   # capture <phase>
  caffeinate -d -i -u -t 1800 & CAF=$!    # NOT `local`: the EXIT trap fires after this returns,
  echo "  module $(shasum -a 256 "$INST" | cut -c1-16)" | tee "$OUT/$1-module.txt"
  WINEDEBUG=+err,+macdrv bash "$REPO/scripts/steam-render-cell.sh" \
      --label "t1-$1" --keep-running >"$OUT/$1-cell.txt" 2>&1
  steam_up || { echo "  VOID: $(grep -m1 FATAL "$OUT/$1-cell.txt" | cut -c1-120)"; return 1; }
  WINEDEBUG=-all "$W" "$S/steam.exe" steam://open/games >/dev/null 2>&1; sleep 15
  local H id
  H=$(drv list | grep 'class=SDL_app' | grep 'title=Steam$' | awk '{print $1}' | head -1)
  [ -z "$H" ] && { echo "  VOID: no Steam SDL_app window"; return 1; }
  drv tree "$H" > "$OUT/$1-tree.txt"
  id=$(/tmp/winlist 2>/dev/null | grep 'title=Steam$' | head -1 | sed -E 's/^id=([0-9]+).*/\1/')
  [ -z "$id" ] && { echo "  VOID: OCCLUDED — Win32 lists the window, macOS does not"; return 1; }
  drv front "$H" >/dev/null; sleep 2
  screencapture -x -o -l "$id" "$OUT/$1.png" 2>/dev/null
  [ -s "$OUT/$1.png" ] || { echo "  VOID: capture produced no file"; return 1; }
  cp /tmp/steam-cell-t1-$1/stdout.txt "$OUT/$1-stdout.txt" 2>/dev/null
  grep -h "T1SPIKE" "$OUT/$1-stdout.txt" "$OUT/$1-cell.txt" 2>/dev/null | sort -u | tee "$OUT/$1-flip.txt"
  echo "  captured $OUT/$1.png ($(stat -f %z "$OUT/$1.png") bytes)"
  return 0
}

case "$PHASE" in
  before|after)
    echo "########## T1 spike — $PHASE — $(date '+%F %T')"
    echo "  display profile: $(CS2_PROFILE= DRY=1 bash "$HOME/cs2-patch/cs2-display-profile.sh" 2>&1 | tail -1)"
    down; capture "$PHASE" || exit 1; down
    [ "$PHASE" = before ] && exit 0
    ;;
esac

echo "########## T1 analysis"
python3 - "$OUT" <<'PY'
import subprocess, sys, os
out = sys.argv[1]
B, A = os.path.join(out, 'before.png'), os.path.join(out, 'after.png')
for f in (B, A):
    if not os.path.exists(f): sys.exit("missing %s — run both phases first" % f)

def strip(png, x, w=10):
    r = subprocess.run(['/tmp/pixel-probe', png, 'strip', str(int(x)), str(int(w))],
                       capture_output=True, text=True)
    import re
    m = re.search(r'(\d+),\s*(\d+),\s*(\d+)', r.stdout)
    return tuple(int(g) for g in m.groups()) if m else None

def d(p, q):
    return 999 if (p is None or q is None) else max(abs(a-b) for a, b in zip(p, q))

# host origin in IMAGE coords: the full-window CefBrowserWindow's offset inside the root. The tree
# prints root-relative rects; x0 is what makes 1.5X mean "1.5x from the HOST's origin" (plan T1).
x0 = 0
print("  host-origin x used: %d (full-window browser sits at the window's left edge)" % x0)

CAND = [40, 80, 120, 160, 200, 260, 320, 400, 480, 560, 640, 720]
rows, decisive, unchanged_all = [], [], True
for X in CAND:
    bx, b15 = strip(B, x0 + X), strip(B, x0 + 1.5 * X)
    ax, a15 = strip(A, x0 + X), strip(A, x0 + 1.5 * X, 15)
    ctl, moved, left = d(bx, b15), d(a15, bx), d(ax, bx)
    same_x, same_15 = d(ax, bx), d(a15, b15)
    if not (same_x <= 2 and same_15 <= 2): unchanged_all = False
    ok = ctl > 8 and moved <= 8 and left > 8
    if ok: decisive.append(X)
    rows.append((X, ctl, moved, left, same_x, same_15, 'DECISIVE' if ok else
                 ('flat control' if ctl <= 8 else '-')))
print("     X   control  moved-to-1.5X  left-X   same@X  same@1.5X")
for r in rows:
    print("  %4d  %7d  %13d  %6d  %7d  %9d   %s" % r)

# corroboration: strongest horizontal edge in the column-mean profile, before vs after
def edge(png, lo, hi, step=8):
    prof = [(x, strip(png, x, step)) for x in range(lo, hi, step)]
    prof = [(x, p) for x, p in prof if p]
    best, bx = -1, None
    for i in range(1, len(prof)):
        g = max(abs(a-b) for a, b in zip(prof[i][1], prof[i-1][1]))
        if g > best: best, bx = g, prof[i][0]
    return bx, best
eb, gb = edge(B, x0 + 24, x0 + 700)
ea, ga = edge(A, x0 + 24, x0 + 1000)
ratio = (ea - x0) / (eb - x0) if eb and ea and eb != x0 else 0
print("  strongest column edge: before x=%s (grad %s) · after x=%s (grad %s) · ratio %.3f"
      % (eb, gb, ea, ga, ratio))

if decisive:
    v = "GREEN — the hosted tree honours transform (decisive at X=%s)" % decisive
elif unchanged_all:
    v = "RED — both strips unchanged at every X: the host IGNORES transform. Option B is dead."
else:
    v = "AMBIGUOUS — no decisive X and not uniformly unchanged; read the frames before concluding"
print("  T1 verdict: %s" % v)
PY
