#!/bin/bash
# test-install-words.sh -- a source gate, and only that: it greps (docs/plans/surviving-mars-install.md, 2.7,
# MT8). The launcher and make-app.sh run from an install as well as from a checkout, so the lines a player
# reads must not send them to a file that only a checkout has, or to "the header". Each old wording must be
# gone, and each line that replaced it must say to open the installer again.
#   bash tools/test-install-words.sh            exit 0 = every line is as it should be
#   MUTANT=1 ...   one old line put back in the launcher; must exit 1
#   MUTANT=2 ...   one old line put back in make-app.sh; must exit 1
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d /tmp/sm-words-test.XXXX)"
trap 'rm -rf "$T"' EXIT
M="${MUTANT:-0}"
L="$T/launch-relaunched.sh"; A="$T/make-app.sh"
cp "$HERE/launch-relaunched.sh" "$L"; cp "$HERE/make-app.sh" "$A"
case "$M" in
  0) ;;
  1) sed -i '' 's|Open the installer again: it opens Steam in this wrapper and waits while you install the game\.|Reinstall it with this wrapper'"'"'s Steam (steam://install/3215050; see the header).|' "$L"
     cmp -s "$HERE/launch-relaunched.sh" "$L" && { echo "REFUSED: mutant 1 did not apply"; exit 2; } ;;
  2) sed -i '' 's|message "The launcher is missing\. Open the installer again\. (From a checkout: bash surviving-mars-relaunched/scripts/setup.sh)"|message "Launcher script is missing. Re-run surviving-mars-relaunched/make-app.sh."|' "$A"
     cmp -s "$HERE/make-app.sh" "$A" && { echo "REFUSED: mutant 2 did not apply"; exit 2; } ;;
  *) echo "REFUSED: no mutant $M"; exit 2 ;;
esac
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
gone() {   # <file> <old wording, a fixed string>
  check "$(basename "$1") no longer says: $2" "$(grep -c -F -- "$2" "$1")" 0
}
gone "$L" 'see the header'
gone "$L" 'see its header'
gone "$L" 'the top of launch-relaunched.sh'
gone "$L" '$HERE/tools/split-wrapper.sh'
gone "$L" '$HERE/tools/make-engine.sh'
gone "$L" 'is not built'
gone "$L" 'On another Mac: clone this repo'
gone "$A" 'Re-run surviving-mars-relaunched/make-app.sh'
gone "$A" 'is missing from this checkout'
gone "$A" "run from the repository's top folder"
gone "$A" 'runs the launcher in this checkout as it is'
# the launcher's die and note lines that tell a player what to do: each names the installer
check "the launcher's four lines for a missing wrapper, engine, game, helper say to open the installer again" \
  "$(grep -E '^\[ -d "\$WINEPREFIX" \] \|\| die |^  \*\) die "This Wine has D3DMetal|^\[ -f "\$GAME/Mars.exe" \] \|\| die |^  note "The click helper' "$L" | grep -c 'pen the installer again')" 4
check "its two Steam Cloud conflict lines point at the guide" "$(grep -c 'A Steam Cloud conflict\\" in the guide, https://github.com/macgameport/1launcher/blob/main/surviving-mars-relaunched/INSTALL.md' "$L")" 2
check "make-app.sh's alert for a missing launcher says to open the installer again" "$(grep -c 'display alert .*The launcher is missing\. Open the installer again\.' "$A")" 1
echo "$fails failure(s)"
[ "$fails" = 0 ]
