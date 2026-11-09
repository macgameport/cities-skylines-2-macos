#!/bin/bash
# test-rosetta-preflight.sh — exercises the launcher's Rosetta preflight (arm64 plan P0) without
# Steam or the game. It sources the launcher's own code between the `>>> rosetta-preflight` and
# `<<< rosetta-preflight` markers, stubs `die`, and runs it against fake `wine` / `arch` binaries
# placed first on PATH:
#   1. wine runs                         -> no die
#   2. wine fails, arch -x86_64 fails    -> die names Rosetta and the reinstall command
#   3. wine fails, arch -x86_64 works    -> die names Wine and carries its output, NOT Rosetta
#   4. live: the real wrapper's wine     -> no die (skipped if no wrapper is installed)
#
#   bash scripts/test-rosetta-preflight.sh [path/to/launch-cs2-dxmt11.sh]
#
# Exit 0 = every case passed. Runs in well under a second.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHER="${1:-$REPO/launchers/launch-cs2-dxmt11.sh}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

BLOCK="$T/block.sh"
sed -n '/^# >>> rosetta-preflight/,/^# <<< rosetta-preflight/p' "$LAUNCHER" > "$BLOCK"
[ -s "$BLOCK" ] || { echo "FAIL: no rosetta-preflight block in $LAUNCHER"; exit 1; }

mkbin() {   # name exit-code [stderr text]
  printf '#!/bin/bash\n[ -n "%s" ] && echo "%s" >&2\nexit %s\n' "${3:-}" "${3:-}" "$2" > "$T/bin/$1"
  chmod +x "$T/bin/$1"
}

# Run the block in a subshell; print "DIED: <msg>" if die was called, "OK" otherwise.
run_block() {   # wine-path
  ( die() { echo "DIED: $1"; exit 1; }
    WINE="$1"; PATH="$T/bin:$PATH"
    . "$BLOCK"
    echo OK )
}

FAILS=0
check() {   # name got want-substring [must-not-contain]
  if [[ "$2" != *"$3"* ]] || { [ -n "${4:-}" ] && [[ "$2" == *"$4"* ]]; }; then
    echo "FAIL $1: got [$2]"; FAILS=$((FAILS + 1))
  else
    echo "pass $1"
  fi
}

mkdir -p "$T/bin"

mkbin wine 0;  mkbin arch 0
check "1 wine runs" "$(run_block "$T/bin/wine")" "OK"

mkbin wine 126 "Bad CPU type in executable"; mkbin arch 1 "Bad CPU type in executable"
check "2 rosetta missing" "$(run_block "$T/bin/wine")" "DIED: Rosetta 2 is not installed"
check "2 reinstall command" "$(run_block "$T/bin/wine")" "softwareupdate --install-rosetta --agree-to-license"

mkbin wine 1 "dyld: Library not loaded: libfoo.dylib"; mkbin arch 0
check "3 other wine failure" "$(run_block "$T/bin/wine")" "DIED: Wine cannot start" "Rosetta"
check "3 carries wine output" "$(run_block "$T/bin/wine")" "Library not loaded"

# Live: the real wrapper's engine, with the launcher's own environment, must pass.
APP="${CS2_WRAPPER:-$HOME/Applications/CS2dxmt11.app}"
if [ -x "$APP/Contents/SharedSupport/wine/bin/wine64" ]; then
  rm -f "$T/bin/wine" "$T/bin/arch"
  got="$( export DYLD_FALLBACK_LIBRARY_PATH="$APP/Contents/Frameworks:$APP/Contents/SharedSupport/wine/lib:/usr/lib:/usr/local/lib"
          run_block "$APP/Contents/SharedSupport/wine/bin/wine64" )"
  check "4 live engine ($(basename "$APP"))" "$got" "OK"
else
  echo "skip 4 live engine: no wrapper at $APP"
fi

[ "$FAILS" -eq 0 ] && { echo "ALL PASS"; exit 0; }
echo "$FAILS FAILED"; exit 1
