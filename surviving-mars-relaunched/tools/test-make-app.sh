#!/bin/bash
# test-make-app.sh -- make-app.sh builds the double-click app, and the app runs the launcher it was given,
# once. A fake launcher that prints its version, HOME in a temp dir so the shim's log lands there; no game,
# no Steam, no osascript (the fake launcher always exits 0). The app pulls nothing at launch (unification
# plan, O3).
#   bash tools/test-make-app.sh            exit 0 = every case passed
#   MUTANT=1 bash tools/test-make-app.sh   the built shim never runs its launcher; must exit 1
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MAKE="$HERE/make-app.sh"
T="$(mktemp -d /tmp/make-app-test.XXXX)"
trap 'rm -rf "$T"' EXIT
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

printf '#!/bin/bash\necho "LAUNCHED v1"\n' > "$T/launch-relaunched.sh"
mkdir -p "$T/Library/Logs"
SM_APP="$T/App.app" SM_SCRIPT="$T/launch-relaunched.sh" bash "$MAKE" > "$T/make.out" 2>&1
check "make-app.sh builds the app" "$?:$([ -x "$T/App.app/Contents/MacOS/launch" ] && echo shim)" "0:shim"
SHIM="$T/App.app/Contents/MacOS/launch"
if [ "${MUTANT:-0}" = 1 ]; then
  sed -i '' 's|^SM_QUIET=1 bash "$SCRIPT"|SM_QUIET=1 true "$SCRIPT"|' "$SHIM"
  grep -q '^SM_QUIET=1 true "$SCRIPT"' "$SHIM" || { echo "REFUSED: mutant did not apply"; exit 2; }
fi
log="$T/Library/Logs/sm-relaunched-launcher.log"; : > "$log"
HOME="$T" "$SHIM" >/dev/null 2>&1; rc=$?
check "the app runs the launcher it was given, once, and exits 0" "$rc:$(grep -c '^LAUNCHED v1$' "$log")" "0:1"

echo "$fails failure(s)"
[ "$fails" = 0 ]
