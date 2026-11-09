#!/bin/bash
# steam-vanilla-d3d-split.sh — run the Steam CLIENT on vanilla wined3d while the GAME keeps DXMT.
#
# WHY: Steam's CEF UI is black on this stack because Chromium's GPU process creates its swapchain
# for an HWND owned by another process, and nothing here presents cross-process (3Shain/dxmt#141;
# measured 2026-08-28: the GPU process crashes x3 per launch on EVERY ANGLE backend — default
# D3D11, gl and vulkan alike, so it is not "DXMT lacks a D3D11 path"). The in-process-GPU dodges
# (`--in-process-gpu`, `--single-process`) render art but draw ZERO glyphs, so they are not
# shippable. This is the remaining route, from mikey92 on dxmt#141 + BCD1210/soju's writeup:
# don't make DXMT serve Steam — take DXMT out of Steam's path and leave it for the game.
#
# HOW IT WORKS — three facts, each of which breaks the naive version:
#   1. DXMT is installed here as the wine BUILTINS (lib/wine/{x86_64,i386}-windows/d3d11.dll is
#      DXMT, 5,304,320 B, 197 Metal/winemetal refs and ZERO wined3d — NOT a fake-dll stub). So "builtin" means
#      DXMT and there is nothing vanilla to fall back to.
#   2. A per-app `native` override pointed at a wine-built PE does NOT load that PE: wine marks
#      its own builtins with the 17-byte signature "Wine builtin DLL\0" at file offset 0x40
#      (= base + sizeof(IMAGE_DOS_HEADER)) and `build_module` in dlls/ntdll/loader.c does
#      `memcmp(base + 0x40, "Wine builtin DLL", 17)`; a match means "this is a builtin" and the
#      load is redirected. Flipping ONE of those 17 bytes makes the copy load as true native.
#   3. Therefore the global override must pin d3d11/dxgi to `builtin` — otherwise the GAME would
#      pick up the marker-stripped vanilla copies now sitting in system32 and silently lose DXMT.
#      That global line is load-bearing: verify it, don't assume it (`--verify`).
#
# Vanilla PEs must be VERSION-MATCHED: wine's d3d11.dll talks to wined3d.dll over an internal,
# per-release ABI, so they must come from the same 11.16 build as the engine. Harvest them with a
# build-engine-1116.sh run stopped after step 3 (`gmake install` lays down stock wine; step 4 is
# what overlays DXMT) — the vanilla d3d11.dll + dxgi.dll exist only in between.
#
# Usage:
#   bash scripts/steam-vanilla-d3d-split.sh --status
#   bash scripts/steam-vanilla-d3d-split.sh --install     # backs up everything it replaces
#   bash scripts/steam-vanilla-d3d-split.sh --verify      # which d3d11 does a D3D11 app get?
#   bash scripts/steam-vanilla-d3d-split.sh --revert
#
# CS2_VANILLA_DIR overrides where the harvested PEs live (expects x86_64/ and i386/ subdirs).
set -u

APP="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
VAN="${CS2_VANILLA_DIR:-$HOME/cs2-patch/build-1116/vanilla-1116}"
MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --install|--revert|--status|--verify) MODE="${1#--}" ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
  shift
done
[ -n "$MODE" ] || { echo "usage: $0 --status|--install|--verify|--revert"; exit 2; }

SS="$APP/Contents/SharedSupport"
export WINEPREFIX="$SS/prefix"
export WINE="$SS/wine/bin/wine64"
export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$SS/wine/lib:/usr/lib:/usr/local/lib"
export WINEDEBUG="${WINEDEBUG:--all}"
SYS32="$WINEPREFIX/drive_c/windows/system32"
SYSWOW="$WINEPREFIX/drive_c/windows/syswow64"
BAK="$WINEPREFIX/drive_c/windows/.dxmt-d3d-backup"
# ⚠ steamwebhelper_real.exe is LOAD-BEARING, not a nicety. Wine keys AppDefaults on the
# executable's FILE NAME, and install-webhelper-shim.sh renames the real CEF binary to
# steamwebhelper_real.exe (the shim takes the original name). So the process that actually
# loads d3d11 is steamwebhelper_real.exe — without this entry it falls through to the GLOBAL
# override (= builtin = DXMT) and a "split + shim" cell silently tests the DXMT client instead
# of the vanilla one. Measured 2026-08-29: cell `split-pair` looked like a valid combined test
# and was not. Combining the two mechanisms REQUIRES both names.
STEAM_EXES="steam.exe steamwebhelper.exe steamwebhelper_real.exe steamservice.exe"
die(){ echo "ERROR: $1"; exit 1; }
[ -x "$WINE" ] || die "no wine at $WINE"

# never operate on a live prefix — attribute by open files, not cmdline (Windows-argv steam.exe)
steam_running(){
  for p in $(pgrep -f "steam" 2>/dev/null); do
    lsof -p "$p" 2>/dev/null | grep -q "$WINEPREFIX" && return 0
  done
  return 1
}

# is this PE one of wine's builtins? (the exact test build_module does)
marker(){ python3 - "$1" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
print("yes" if d[0x40:0x40+17]==b"Wine builtin DLL\0" else "no")
PY
}
# ⚠ Do NOT identify a build by grepping for "dxmt" — a vanilla PE built from the DXMT-patched
# source tree carries 90 hits that are just BUILD PATHS in debug info (the tree is named
# wine-11.16-dxmt). The real discriminator is the API surface: DXMT imports winemetal/Metal and
# has zero wined3d refs; vanilla is the exact mirror (measured 2026-08-28).
metal_refs(){ strings -a "$1" | grep -cE '^WMT|winemetal\.dll|MTLDevice'; }
wined3d_refs(){ strings -a "$1" | grep -c 'wined3d_'; }
ident(){ printf '%9s B  metal=%-5s wined3d=%-5s builtin-marker=%s' \
  "$(stat -f%z "$1")" "$(metal_refs "$1")" "$(wined3d_refs "$1")" "$(marker "$1")"; }

case "$MODE" in
status)
  echo "prefix: $WINEPREFIX"
  for f in "$SYS32/d3d11.dll" "$SYS32/dxgi.dll" "$SYSWOW/d3d11.dll" "$SYSWOW/dxgi.dll"; do
    [ -f "$f" ] && { printf '  %-22s ' "${f#$WINEPREFIX/drive_c/windows/}"; ident "$f"; echo; }
  done
  echo "  backup dir: $([ -d "$BAK" ] && echo "$BAK ($(ls "$BAK" | wc -l | tr -d ' ') files)" || echo none)"
  echo "--- registry ---"
  "$WINE" reg query 'HKCU\Software\Wine\DllOverrides' /v d3d11 2>/dev/null | grep -i d3d11 || echo "  global d3d11: (unset)"
  "$WINE" reg query 'HKCU\Software\Wine\DllOverrides' /v dxgi  2>/dev/null | grep -i dxgi  || echo "  global dxgi:  (unset)"
  for e in $STEAM_EXES; do
    v=$("$WINE" reg query "HKCU\\Software\\Wine\\AppDefaults\\$e\\DllOverrides" /v d3d11 2>/dev/null | grep -i d3d11)
    echo "  $e d3d11: ${v:-(unset)}"
  done
  ;;

install)
  steam_running && die "Steam is running in this wrapper — quit it first (steam.exe -shutdown; never kill -9)"
  for a in x86_64 i386; do for d in d3d11 dxgi; do
    [ -f "$VAN/$a/$d.dll" ] || die "missing $VAN/$a/$d.dll — harvest the vanilla PEs first (see header)"
  done; done

  echo "== validating the harvested PEs are actually vanilla"
  for a in x86_64 i386; do for d in d3d11 dxgi; do
    f="$VAN/$a/$d.dll"
    printf '  %-16s ' "$a/$d.dll"; ident "$f"; echo
    [ "$(metal_refs "$f")" = "0" ] || die "$f imports winemetal/Metal — that is a DXMT build, not vanilla"
    [ "$(wined3d_refs "$f")" -gt 100 ] || die "$f has almost no wined3d references — not a wined3d-backed PE"
    [ "$(marker "$f")" = "yes" ] || die "$f has no builtin marker — unexpected for a wine-built PE; refusing"
  done; done

  echo "== backing up the current (DXMT) copies"
  mkdir -p "$BAK"
  for pair in "$SYS32 x86_64" "$SYSWOW i386"; do
    set -- $pair; dir="$1"; arch="$2"
    for d in d3d11 dxgi; do
      [ -f "$dir/$d.dll" ] || continue
      [ -f "$BAK/$arch-$d.dll" ] || cp "$dir/$d.dll" "$BAK/$arch-$d.dll"
    done
  done
  echo "  backup: $BAK ($(ls "$BAK" | wc -l | tr -d ' ') files)"

  echo "== installing vanilla copies with the builtin marker stripped"
  for pair in "$SYS32 x86_64" "$SYSWOW i386"; do
    set -- $pair; dir="$1"; arch="$2"
    for d in d3d11 dxgi; do
      cp "$VAN/$arch/$d.dll" "$dir/$d.dll"
      python3 - "$dir/$d.dll" <<'PY'
import sys
p=sys.argv[1]; b=bytearray(open(p,'rb').read())
assert b[0x40:0x40+17]==b"Wine builtin DLL\0", "marker not at 0x40 — refusing to patch blind"
b[0x40]=ord('w')            # 1-byte flip: memcmp in build_module now fails -> loads as native
open(p,'wb').write(b)
PY
      printf '  %-22s ' "$arch/$d.dll"; ident "$dir/$d.dll"; echo
    done
  done

  echo "== registry: global builtin (game keeps DXMT), per-app native (Steam gets wined3d)"
  for d in d3d11 dxgi; do
    "$WINE" reg add 'HKCU\Software\Wine\DllOverrides' /v "$d" /d builtin /f >/dev/null 2>&1 \
      || die "failed to set global $d=builtin — WITHOUT THIS THE GAME LOSES DXMT"
  done
  for e in $STEAM_EXES; do for d in d3d11 dxgi; do
    "$WINE" reg add "HKCU\\Software\\Wine\\AppDefaults\\$e\\DllOverrides" /v "$d" /d native /f >/dev/null 2>&1 \
      || die "failed to set $e $d=native"
  done; done
  "$WINEPREFIX/../wine/bin/wineserver" -w 2>/dev/null
  echo "  done. Run --verify next (the global builtin line is load-bearing), then a Steam cell."
  ;;

verify)
  # Does a plain D3D11 app still get DXMT? +loaddll prints the origin of every module load.
  T="$(cd "$(dirname "$0")" && pwd)/dxtest.exe"
  [ -f "$T" ] || die "no dxtest.exe next to this script"
  echo "== loading a D3D11 app (dxtest.exe) with +loaddll — expect BUILTIN d3d11 = DXMT"
  # ⚠ dxtest.exe renders FOREVER (its message loop has no exit but WM_QUIT), so this must be
  # time-boxed or --verify never returns. Piping to `head` does NOT save you: grep block-buffers,
  # so the SIGPIPE that would kill it never arrives. Measured 2026-08-29 — two --verify runs were
  # reported as "timed out" when in fact the probe was working exactly as written.
  # macOS has no coreutils `timeout`; launch, sample, kill.
  LOG=$(mktemp -t dxsplit-verify)
  WINEDEBUG=+loaddll DXMT_LOG_LEVEL=info "$WINE" "$T" >"$LOG" 2>&1 &
  VPID=$!
  for _ in $(seq 25); do grep -qi "d3d11\.dll" "$LOG" 2>/dev/null && break; sleep 1; done
  kill "$VPID" 2>/dev/null; pkill -f "dxtest.exe" 2>/dev/null
  out=$(grep -iE "d3d11\.dll|dxgi\.dll|winemetal" "$LOG" | head -8)
  rm -f "$LOG"
  [ -n "$out" ] || echo "  ⚠ no module-load lines captured — probe did not reach D3D11 (check wine/prefix)"
  echo "$out" | sed 's/^/  /'
  echo "$out" | grep -qi "d3d11.dll.*builtin" \
    && echo "  VERDICT: game path still resolves d3d11 -> builtin (DXMT). Good." \
    || echo "  ⚠ VERDICT: d3d11 did NOT resolve builtin — the game would lose DXMT. Revert before playing."
  ;;

revert)
  steam_running && die "Steam is running in this wrapper — quit it first"
  [ -d "$BAK" ] || die "no backup at $BAK — nothing to revert"
  for pair in "$SYS32 x86_64" "$SYSWOW i386"; do
    set -- $pair; dir="$1"; arch="$2"
    for d in d3d11 dxgi; do
      [ -f "$BAK/$arch-$d.dll" ] && { cp "$BAK/$arch-$d.dll" "$dir/$d.dll"; printf '  restored %-16s ' "$arch/$d.dll"; ident "$dir/$d.dll"; echo; }
    done
  done
  for d in d3d11 dxgi; do
    "$WINE" reg delete 'HKCU\Software\Wine\DllOverrides' /v "$d" /f >/dev/null 2>&1
  done
  for e in $STEAM_EXES; do
    "$WINE" reg delete "HKCU\\Software\\Wine\\AppDefaults\\$e\\DllOverrides" /f >/dev/null 2>&1
  done
  echo "  reverted (backups left in $BAK — delete by hand once you are happy)"
  ;;
esac
