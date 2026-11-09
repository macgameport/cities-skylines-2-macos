#!/bin/bash
# make-vanilla-wrapper.sh — build a THROWAWAY wrapper whose wine tree carries VANILLA wined3d
# builtins, so Steam's CEF can be measured on a real wined3d client.
#
# WHY THIS EXISTS (2026-08-29): every Steam-side test of the "vanilla-wined3d split" run in this
# project used soju's marker-strip + per-app `native` trick — and that wiring is BROKEN here. A
# device-creation probe (scripts/dxgiprobe.exe) aborts on it:
#     wine: Call from ... to unimplemented function dxgi.dll.DXGID3D10CreateDevice, aborting
# so those cells measured a client whose d3d11 dies at CreateDevice, NOT a wined3d client. The
# same PEs installed as TRUE BUILTINS (marker intact, in lib/wine/*/) do create a device. But that
# wiring is ENGINE-GLOBAL — it would take DXMT away from the game — so it cannot be done in the
# daily wrapper. Hence a separate bundle.
#
# WHAT IT IS NOT: a way to play. The game must never be run here; this wrapper has no DXMT.
#
# Cost: ~0 disk. `cp -Rc` is an APFS clone, so the 103 GB bundle shares extents with the original
# (GOTCHAS § "`du` lies about disk on APFS"). Deleting it reclaims only what diverged.
#
# Usage:
#   bash scripts/make-vanilla-wrapper.sh --build     # clone + install vanilla builtins
#   bash scripts/make-vanilla-wrapper.sh --verify    # what does each wrapper's d3d11 resolve to?
#   bash scripts/make-vanilla-wrapper.sh --remove    # delete the clone
#
# CS2_VANILLA_DIR overrides where the harvested PEs live (expects x86_64/ and i386/ subdirs).
set -u

SRC="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
DST="${CS2_VANILLA_WRAPPER:-$HOME/Applications/CS2vanilla-d3d.app}"
VAN="${CS2_VANILLA_DIR:-$HOME/cs2-patch/build-1116/vanilla-1116}"
MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --build|--verify|--remove) MODE="${1#--}" ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac; shift
done
[ -n "$MODE" ] || { echo "usage: $0 --build|--verify|--remove"; exit 2; }
die(){ echo "ERROR: $1"; exit 1; }

# never operate while either wrapper has a live wine process — attribute by OPEN FILES, because
# wine argv is Windows-style and no .app-path pgrep will match (GOTCHAS, learned twice).
busy(){
  local pfx="$1/Contents/SharedSupport/prefix"
  for p in $(pgrep -f "wine|steam" 2>/dev/null); do
    lsof -p "$p" 2>/dev/null | grep -q "$pfx" && return 0
  done
  return 1
}
metal_refs(){ strings -a "$1" 2>/dev/null | grep -ci "winemetal\|MTLDevice" || true; }
wined3d_refs(){ strings -a "$1" 2>/dev/null | grep -c "wined3d_" || true; }
marker(){ python3 - "$1" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
print("yes" if d[0x40:0x40+17]==b"Wine builtin DLL\0" else "no")
PY
}
ident(){ printf '%9s B  metal=%-5s wined3d=%-6s builtin-marker=%s' \
  "$(stat -f%z "$1" 2>/dev/null)" "$(metal_refs "$1")" "$(wined3d_refs "$1")" "$(marker "$1")"; }

case "$MODE" in
build)
  [ -d "$SRC" ] || die "no source wrapper at $SRC"
  [ -d "$DST" ] && die "$DST already exists — --remove first"
  busy "$SRC" && die "the source wrapper has live wine processes — quit them first"
  for a in x86_64 i386; do for d in d3d11 dxgi; do
    [ -f "$VAN/$a/$d.dll" ] || die "missing harvested PE: $VAN/$a/$d.dll"
  done; done

  echo "== validating the harvested PEs are vanilla AND still marked as builtins"
  for a in x86_64 i386; do for d in d3d11 dxgi; do
    f="$VAN/$a/$d.dll"; printf '  %-16s ' "$a/$d.dll"; ident "$f"; echo
    [ "$(metal_refs "$f")" = "0" ] || die "$f imports winemetal — that is DXMT, not vanilla"
    [ "$(wined3d_refs "$f")" -gt 100 ] || die "$f has almost no wined3d refs — not wined3d-backed"
    # ⚠ the marker must STAY: these go in as true builtins, which is the whole point.
    [ "$(marker "$f")" = "yes" ] || die "$f has no builtin marker — do not use a stripped copy here"
  done; done

  echo "== cloning $(basename "$SRC") -> $(basename "$DST")  (APFS clone, ~0 disk)"
  cp -Rc "$SRC" "$DST" || die "clone failed"

  echo "== installing VANILLA builtins into the clone's wine tree"
  for pair in "x86_64-windows x86_64" "i386-windows i386"; do
    set -- $pair; tree="$1"; arch="$2"
    for d in d3d11 dxgi; do
      t="$DST/Contents/SharedSupport/wine/lib/wine/$tree/$d.dll"
      [ -f "$t" ] || die "clone has no $tree/$d.dll — unexpected engine layout"
      cp "$VAN/$arch/$d.dll" "$t" || die "copy failed: $t"
      printf '  %-22s ' "$tree/$d.dll"; ident "$t"; echo
    done
  done

  echo "== confirming the SOURCE wrapper is untouched (it must still be DXMT)"
  for d in d3d11 dxgi; do
    printf '  src x86_64-windows/%-9s ' "$d.dll"
    ident "$SRC/Contents/SharedSupport/wine/lib/wine/x86_64-windows/$d.dll"; echo
  done
  echo
  echo "  Built. NEVER run the game in this wrapper — it has no DXMT."
  echo "  Next: CS2_WRAPPER=\"$DST\" bash scripts/steam-render-cell.sh --label vanilla-real"
  ;;

verify)
  for w in "$SRC" "$DST"; do
    [ -d "$w" ] || continue
    echo "$(basename "$w"):"
    for d in d3d11 dxgi; do
      f="$w/Contents/SharedSupport/wine/lib/wine/x86_64-windows/$d.dll"
      [ -f "$f" ] && { printf '  %-9s ' "$d.dll"; ident "$f"; echo; }
    done
  done
  ;;

remove)
  [ -d "$DST" ] || { echo "nothing to remove"; exit 0; }
  busy "$DST" && die "the clone has live wine processes — quit them first"
  case "$DST" in *"/CS2vanilla-d3d.app") ;; *) die "refusing to rm a path that is not the expected clone: $DST";; esac
  rm -rf "$DST" && echo "removed $DST"
  ;;
esac
