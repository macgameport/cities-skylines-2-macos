#!/bin/bash
# salvage-cells.sh — move render-cell evidence out of volatile /tmp into the durable evidence store,
# applying the project's privacy rule on the way.
#
# WHY: every conclusion in the Steam-UI thread rests on cells written to /tmp/steam-cell-*, which a
# reboot clears. On 2026-08-30 an audit had to re-read a week of cells to find that most were void;
# had /tmp been cleared first, none of that would have been recoverable and the same wrong
# conclusions would have been re-derived from prose.
#
# PRIVACY (repo is publishable — see CLAUDE.md § Personal info):
#   * known-good.png is a capture of whatever browser/terminal window happened to be frontmost. It
#     is instrument validation only: the sole datum is "did the capture succeed and how big". We
#     keep the SIZE and drop the IMAGE — it is the single largest accidental-disclosure surface here.
#   * win-*.png are Steam client windows and carry the persona name + avatar. They stay in the
#     evidence store (OUTSIDE the repo) and are never committed; mask before publishing one.
#   * stdout.txt / windows.txt were audited 2026-08-30: no /Users/<name>, no Steam IDs, no persona.
#     Only C:\ and Z:\ wine-internal paths. Safe to quote in the repo.
#
# Usage:  bash scripts/salvage-cells.sh [--dest DIR] [--dry-run]
set -u
DEST="$HOME/cs2-patch/evidence"; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) shift; DEST="$1" ;;
    --dry-run) DRY=1 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac; shift
done
mkdir -p "$DEST"
n=0; kept=0; dropped=0
for d in /tmp/steam-cell-*/; do
  [ -d "$d" ] || continue
  cell=$(basename "$d" | sed 's/^steam-cell-//')
  out="$DEST/$cell"
  n=$((n+1))
  [ "$DRY" = 1 ] || mkdir -p "$out"
  # shim.log carries the SHIM_FONTPROBE in-tree measurement (GDI/DWrite family counts and whether
  # DirectWrite actually rasterises). That is the only record of the single most decisive probe in
  # this project, and it was NOT retained until 2026-08-30 — it lived only in volatile /tmp and in
  # C:\shim.log, which every run overwrites.
  # ⚠ NOT clean: the relaunch command line it records carries Steam's own switches,
  # including a SteamID64 (-steamid=7656119...) and a C:\users\<name> cachedir.
  # Evidence-store ONLY, exactly like win-*.png -- never commit one, never paste one
  # into an issue. Checked 2026-08-30 after a first pass wrongly called it clean; the
  # sweep that missed it omitted the SteamID64 pattern.
  for f in stdout.txt windows.txt config.json shim.log drag-sizes.txt; do
    [ -f "$d$f" ] && { [ "$DRY" = 1 ] || cp -p "$d$f" "$out/"; }
  done
  # Steam-window captures a cell made for itself: the resize work names them rsz-/b-/churn*, and
  # the first salvage after that run silently dropped ALL of them -- the primary evidence for the
  # measurement -- because only win-*.png was whitelisted. Same privacy class as win-*.png:
  # evidence store only, never committed. (2026-08-31)
  for p in "$d"win-*.png "$d"rsz-*.png "$d"b-*.png "$d"churn*.png "$d"drag-*.png; do
    [ -e "$p" ] || continue
    [ "$DRY" = 1 ] || cp -p "$p" "$out/"
    kept=$((kept+1))
  done
  if [ -f "${d}known-good.png" ]; then
    sz=$(stat -f%z "${d}known-good.png")
    [ "$DRY" = 1 ] || printf 'known-good.png was %s bytes (instrument validation only; image intentionally NOT retained — it captures an arbitrary browser/terminal window)\n' "$sz" > "$out/known-good.size.txt"
    dropped=$((dropped+1))
  fi
  # record the source mtime so the ledger can date the run
  [ "$DRY" = 1 ] || stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S' "$d" > "$out/ran-at.txt"
done
echo "cells:            $n"
echo "win-*.png kept:   $kept   (Steam windows — persona name visible, never commit unmasked)"
echo "known-good dropped: $dropped (size recorded instead)"
echo "dest:             $DEST"
[ "$DRY" = 1 ] && echo "(dry run — nothing written)"
exit 0
