#!/bin/bash
# test-launcher-notes.sh -- what the launcher tells the player when patching fails, and when the Mac is outside
# the macOS releases this has been run on. Takes ensure_patches, the line that calls it, and the block between
# the `>>> compat-note` markers out of launchers/launch-cs2-dxmt11.sh and runs them against a stub repatch.sh,
# a stub sw_vers and a `note` that records. No Steam, no Wine, no game, no real install.
#   bash scripts/test-launcher-notes.sh            exit 0 = every case passed
#   MUTANT=1 ...   the call line no longer raises a notice when patching fails; must exit 1
#   MUTANT=2 ...   the compat note never writes its marker (it would repeat at every launch); must exit 1
#   MUTANT=3 ...   repatch.sh's output is thrown away again (the log cannot name the failed patch); must exit 1
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d /tmp/launcher-notes-test.XXXX)"
trap 'chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"' EXIT
L="$T/launcher.sh"; cp "$REPO/launchers/launch-cs2-dxmt11.sh" "$L"
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
case "${MUTANT:-0}" in
  1) sed -i '' 's/^ensure_patches || note .*/ensure_patches/' "$L"; grep -q '^ensure_patches$' "$L" || mutated ;;
  2) sed -i '' '/touch "\$PATCH_DIR\/patches\/\.compat-noted-/d' "$L"; grep -q 'touch "\$PATCH_DIR/patches/.compat-noted' "$L" && mutated ;;
  3) sed -i '' 's#if RP_OUT=\$(CS2_GAME_DIR="\$GDIR" bash "\$PATCH_DIR/repatch.sh" dxmt11 2>&1); then#if CS2_GAME_DIR="$GDIR" bash "$PATCH_DIR/repatch.sh" dxmt11 >/dev/null 2>\&1; then RP_OUT=""; else RP_OUT=""; false; fi; if [ $? = 0 ]; then#' "$L"
     grep -q 'RP_OUT=""; false' "$L" || mutated ;;
esac
# the pieces under test, as the launcher has them
{ sed -n '/^ensure_patches() {/,/^}/p' "$L"; } > "$T/fn.sh"
grep '^ensure_patches' "$L" | grep -v '() {' > "$T/call.sh"
sed -n '/^# >>> compat-note/,/^# <<< compat-note/p' "$L" > "$T/compat.sh"
[ -s "$T/fn.sh" ] && [ "$(wc -l < "$T/call.sh" | tr -d ' ')" = 1 ] && [ -s "$T/compat.sh" ] || { echo "REFUSED: could not find the three pieces in the launcher"; exit 2; }

mkdir -p "$T/bin"
printf '#!/bin/bash\n[ "$1" = -productVersion ] && echo "${STUB_OSV-27.2}"\n' > "$T/bin/sw_vers"; chmod +x "$T/bin/sw_vers"
inst() {   # <dir> <repatch exit code> [badge]: an install folder with a stub repatch.sh, and optionally the badge file
  mkdir -p "$1/patches"
  printf '#!/bin/bash\necho "Target game dir: x"\n[ %s = 0 ] || echo "FAILED: patch_mkparent.py"\nexit %s\n' "$2" "$2" > "$1/repatch.sh"; chmod +x "$1/repatch.sh"
  [ "${3:-}" = badge ] && echo 'print("all patches present — nothing to do")' > "$1/patch-modconflict-badge.py"
  return 0
}
harness() {   # <install dir> <piece ...>: run pieces in a fresh shell; notes go to <install dir>.notes
  local d="$1"; shift
  : > "$d.notes"
  ( export PATH="$T/bin:$PATH"; set -u
    PATCH_DIR="$d"; GDIR="$T/game"; NOTES="$d.notes"
    note() { echo "$1" >> "$NOTES"; return 0; }
    for piece in "$@"; do . "$piece"; done ) > "$d.out" 2> "$d.err"
}
notes() { wc -l < "$1.notes" | tr -d ' '; }
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

# --- patching
D="$T/ok"; inst "$D" 0
harness "$D" "$T/fn.sh" "$T/call.sh"
check "patches in place: no notice, and the log says ensured" "$(notes "$D"):$(grep -c '^Patches ensured (10, dxmt11 target)\.$' "$D.out")" "0:1"
D="$T/bad"; inst "$D" 1
harness "$D" "$T/fn.sh" "$T/call.sh"
check "a patch failed: exactly one notice, telling the player what to do" "$(notes "$D"):$(grep -c 'Some patches could not be applied. Update and run setup' "$D.notes")" "1:1"
check "  ...and the log names the patch that failed" "$(grep -c 'WARNING: repatch reported an issue.*FAILED: patch_mkparent.py' "$D.out")" 1
check "  ...and the launch goes on (nothing on stderr)" "$(wc -c < "$D.err" | tr -d ' ')" 0

# --- the badge step runs where the file is installed, with no environment needed
D="$T/badge"; inst "$D" 0 badge
harness "$D" "$T/fn.sh" "$T/call.sh"
check "badge file installed: the step runs under plain python3" "$(grep -c '^Badge patch: all patches present' "$D.out")" 1
D="$T/nobadge"; inst "$D" 0
harness "$D" "$T/fn.sh" "$T/call.sh"
check "no badge file: the step does not run" "$(grep -c 'Badge patch\|badge-patch' "$D.out")" 0

# --- outside the tested macOS releases: one note per release, never fatal
D="$T/c27"; inst "$D" 0
STUB_OSV=27.2 harness "$D" "$T/compat.sh"
check "macOS 27: no note, no marker" "$(notes "$D"):$(ls -A "$D/patches" | wc -l | tr -d ' ')" "0:0"
D="$T/c15"; inst "$D" 0
STUB_OSV=15.5 harness "$D" "$T/compat.sh"
check "macOS 15: one note naming the version, and a marker" "$(notes "$D"):$(grep -c 'macOS 15.5, which this has not been tested on' "$D.notes"):$(ls -A "$D/patches")" "1:1:.compat-noted-15"
STUB_OSV=15.6 harness "$D" "$T/compat.sh"
check "  ...the next launch on that release: no note" "$(notes "$D")" 0
STUB_OSV=28.0 harness "$D" "$T/compat.sh"
check "  ...a different release: one note again" "$(notes "$D")" 1
D="$T/cro"; inst "$D" 0; chmod a-w "$D/patches"
STUB_OSV=15.5 harness "$D" "$T/compat.sh"
check "an install folder that cannot be written: the note, and no error text" "$(notes "$D"):$(wc -c < "$D.err" | tr -d ' ')" "1:0"
D="$T/cnone"; inst "$D" 0
STUB_OSV= harness "$D" "$T/compat.sh"
check "a version that cannot be read: no note" "$(notes "$D")" 0

echo "$fails failure(s)"
[ "$fails" = 0 ]
