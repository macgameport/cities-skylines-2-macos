#!/bin/bash
# cell-fingerprint.sh — record the CONFIG A RESULT WAS MEASURED UNDER, and refuse the run when a
# precondition that would silently void it is not met.
#
# WHY THIS EXISTS (2026-08-30). The render-cell harness already guards three traps that make a bad
# run look like a bad *result* (stale SingletonLock, a blind screencapture, cmdline attribution).
# A matrix audit that day found three MORE, and all three had been corrupting cells for a week:
#
#   4. LIBRARY RESOLUTION. wine dlopens its optional deps by bare soname. When one does not
#      resolve, win32u prints a single WINE_MESSAGE and continues with NO font backend — the cell
#      then renders art and no glyphs, indistinguishable from a GPU/compositing failure. 39 of 41
#      cells had been measured with no FreeType, and the entire "glyph loss" investigation was
#      built on them.
#   5. SHIM PLACEMENT. install-webhelper-shim.sh targets ONE cef dir. Steam picks its own. If they
#      disagree, --shim-args is accepted, logged, and silently never reaches CEF — so a cell that
#      reads as "CPU raster fails here" may never have run CPU raster at all.
#   6. FOREIGN STEAM. Several wrappers legitimately run Steam at once. The harness's `ps | head -1`
#      and its window list are not prefix-filtered, so another wrapper's client can supply both the
#      "flags survived" line and a RENDERED window. That is a false PASS, the worst kind.
#
# A result without its config is not a measurement, it is an anecdote. This writes the config next
# to the result so a later session can tell which cells are still worth believing.
#
# Usage:  bash scripts/cell-fingerprint.sh --out DIR [--steam-args S] [--shim-args S] [--strict]
#         CS2_WRAPPER=/path/to/Wrapper.app bash scripts/cell-fingerprint.sh --out /tmp/x
# Exit :  0 = every fatal precondition passed;  1 = at least one failed (do not trust the cell)
set -u

OUTDIR=""; STEAM_ARGS=""; SHIM_ARGS=""; STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --out) shift; OUTDIR="$1" ;;
    --steam-args) shift; STEAM_ARGS="$1" ;;
    --shim-args)  shift; SHIM_ARGS="$1" ;;
    --strict) STRICT=1 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$OUTDIR" ] || { echo "ERROR: --out DIR required" >&2; exit 2; }
mkdir -p "$OUTDIR"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
SS="$APP/Contents/SharedSupport"; E="$SS/wine"; PFX="$SS/prefix"
S="$PFX/drive_c/Program Files (x86)/Steam"
FATAL=0; WARN=0
note(){ printf '  %-6s %s\n' "$1" "$2"; }
fatal(){ note FATAL "$1"; FATAL=$((FATAL+1)); }
warn(){  note warn  "$1"; WARN=$((WARN+1)); }
ok(){    note ok    "$1"; }

json_esc(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'; }

echo "=== fingerprint: $(basename "$APP") ==="

# ---------------------------------------------------------------- identity
WINEVER="$("$E/bin/wine64" --version 2>/dev/null || "$E/bin/wine" --version 2>/dev/null || echo unknown)"
REPO_HEAD="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo none)"
REPO_DIRTY="$(git -C "$REPO" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
ENGINE_STAMP="$(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S' "$E/bin/wine64" 2>/dev/null || echo unknown)"
ok "engine $WINEVER  built/installed $ENGINE_STAMP"
ok "repo $REPO_HEAD ($REPO_DIRTY uncommitted file(s))"

# ---------------------------------------------------------------- P4: library resolution
# Probe under the SAME env the cell will use, with an x86_64 probe (an arm64 one would resolve
# arm64 dylibs the x86_64 engine can never load).
DYLD_FB="$APP/Contents/Frameworks:$E/lib:/usr/lib:/usr/local/lib"
PROBE=/tmp/dlprobe
if [ ! -x "$PROBE" ] || [ "$REPO/scripts/dlprobe.c" -nt "$PROBE" ]; then
  clang -arch x86_64 -o "$PROBE" "$REPO/scripts/dlprobe.c" 2>/dev/null || { warn "could not build dlprobe — skipping library check"; PROBE=""; }
fi
LIBS_JSON=""; LIB_STATUS="unchecked"
if [ -n "$PROBE" ]; then
  # the sonames the engine actually references, not a hardcoded list — adapts if the build changes
  # scan EVERY unix .so: freetype is dlopened by win32u AND (separately) by dwrite; gnutls by
  # bcrypt/secur32; MoltenVK by winemac+winevulkan. Scanning only win32u missed gnutls entirely.
  CRIT=$(strings "$E"/lib/wine/x86_64-unix/*.so 2>/dev/null \
         | grep -E '^lib[A-Za-z0-9._+-]+\.dylib$' \
         | grep -iE 'freetype|gnutls|moltenvk|vulkan|fontconfig' | sort -u)
  [ -n "$CRIT" ] || warn "no critical sonames found in the unix .so set — check the engine layout"
  RES=$(DYLD_FALLBACK_LIBRARY_PATH="$DYLD_FB" $PROBE $CRIT 2>&1)
  LIB_STATUS="pass"
  while IFS=$'\t' read -r st name; do
    case "$st" in
      OK)   ok "resolves  $name" ;;
      FAIL) fatal "DOES NOT RESOLVE  $name  — this cell would run with that subsystem missing"; LIB_STATUS="fail" ;;
    esac
    [ -n "${name:-}" ] && LIBS_JSON="$LIBS_JSON    \"$(json_esc "$name")\": \"$st\",
"
  done <<< "$(printf '%s\n' "$RES" | grep -E '^(OK|FAIL)	')"
fi

# ---------------------------------------------------------------- P5: shim placement
CEF_JSON=""; SHIM_SUMMARY="none"
if [ -d "$S/bin/cef" ]; then
  shimmed=0; total=0
  while IFS= read -r -d '' d; do
    total=$((total+1))
    wh="$d/steamwebhelper.exe"; rl="$d/steamwebhelper_real.exe"
    sz=$(stat -f%z "$wh" 2>/dev/null || echo 0)
    if [ -f "$rl" ] && [ "$sz" -lt 1000000 ]; then st="SHIM"; shimmed=$((shimmed+1)); else st="stock"; fi
    ok "cef $(basename "$d"): $st (webhelper ${sz} B)"
    CEF_JSON="$CEF_JSON    \"$(json_esc "$(basename "$d")")\": \"$st\",
"
  done < <(find "$S/bin/cef" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  SHIM_SUMMARY="$shimmed/$total shimmed"
  if [ -n "$SHIM_ARGS" ]; then
    if [ "$shimmed" = "0" ]; then
      fatal "--shim-args given but NO cef dir is shimmed — the flags will never reach CEF"
    elif [ "$shimmed" != "$total" ]; then
      fatal "--shim-args given but only $shimmed of $total cef dirs are shimmed — Steam may pick an unshimmed one"
    else ok "--shim-args will apply (all $total cef dir(s) shimmed)"; fi
  fi
fi

# ---------------------------------------------------------------- P6: foreign Steam
# Attribute by open files against the PREFIX, never by cmdline (a self-restarted steam.exe and every
# webhelper child carry Windows-style argv).
FOREIGN=0; FOREIGN_LIST=""
for p in $(pgrep -f 'steam\.exe|steamwebhelper' 2>/dev/null); do
  files=$(lsof -p "$p" 2>/dev/null)
  printf '%s' "$files" | grep -q "$PFX" && continue          # ours: fine, harness shuts it down
  other=$(printf '%s' "$files" | grep -oE '/[^ ]*\.app/Contents/SharedSupport/prefix' | head -1)
  [ -n "$other" ] && { FOREIGN=$((FOREIGN+1)); FOREIGN_LIST="$FOREIGN_LIST$other "; }
done
if [ "$FOREIGN" -gt 0 ]; then
  u=$(printf '%s\n' $FOREIGN_LIST | sort -u | tr '\n' ' ')
  if [ "$STRICT" = 1 ]; then fatal "$FOREIGN foreign Steam process(es) running: $u — window capture and ps WILL cross-contaminate"
  else warn "$FOREIGN foreign Steam process(es) running: $u — capture may cross-contaminate (use --strict to refuse)"; fi
else ok "no foreign Steam running"; fi

# ---------------------------------------------------------------- misc state
[ -f "$S/.crash" ] && warn ".crash marker present ($(stat -f%z "$S/.crash") B) — next launch exits 1 unless cleared"
DXMT="absent"; [ -f "$E/lib/wine/x86_64-windows/winemetal.dll" ] || [ -f "$E/lib/wine/x86_64-unix/winemetal.so" ] && DXMT="present"
ok "DXMT: $DXMT"

# ---------------------------------------------------------------- emit
cat > "$OUTDIR/config.json" <<JSON
{
  "utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "wrapper": "$(json_esc "$APP")",
  "prefix": "$(json_esc "$PFX")",
  "engine_version": "$(json_esc "$WINEVER")",
  "engine_installed": "$ENGINE_STAMP",
  "dxmt": "$DXMT",
  "repo_head": "$REPO_HEAD",
  "repo_uncommitted_files": $REPO_DIRTY,
  "steam_args": "$(json_esc "$STEAM_ARGS")",
  "shim_args": "$(json_esc "$SHIM_ARGS")",
  "shim_summary": "$(json_esc "$SHIM_SUMMARY")",
  "library_resolution": "$LIB_STATUS",
  "libraries": {
$(printf '%s' "$LIBS_JSON" | sed '$ s/,$//')
  },
  "cef_dirs": {
$(printf '%s' "$CEF_JSON" | sed '$ s/,$//')
  },
  "foreign_steam_processes": $FOREIGN,
  "os": "$(sw_vers -productVersion 2>/dev/null)",
  "hw": "$(sysctl -n machdep.cpu.brand_string 2>/dev/null)",
  "dyld_fallback": "$(json_esc "$DYLD_FB")",
  "preconditions": { "fatal": $FATAL, "warn": $WARN },
  "verdict": "$([ "$FATAL" = 0 ] && echo TRUSTWORTHY || echo VOID)"
}
JSON

echo "--- preconditions: $FATAL fatal, $WARN warn -> $([ "$FATAL" = 0 ] && echo TRUSTWORTHY || echo 'VOID (do not record this cell as evidence)') ---"
echo "--- config written: $OUTDIR/config.json ---"
[ "$FATAL" = 0 ]
