#!/bin/bash
# test-make-app.sh -- the app make-app.sh builds pulls `hub main` before each launch and never lets the pull
# stop a launch. Throwaway repo + bare hub, a fake launcher that prints its version, HOME in a temp dir so
# the shim's log lands there; no game, no Steam, no osascript (the fake launcher always exits 0). The ssh
# ConnectTimeout is not exercised here (the unreachable hub is a missing local path).
#   bash tools/test-make-app.sh            exit 0 = every case passed
#   MUTANT=1 bash tools/test-make-app.sh   the shim fetches instead of pulling (nothing updates); must exit 1
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MAKE="$HERE/make-app.sh"
T="$(mktemp -d /tmp/make-app-test.XXXX)"
trap 'rm -rf "$T"' EXIT
if [ "${MUTANT:-0}" = 1 ]; then
  sed 's|pull --ff-only --quiet hub main|fetch --quiet hub main|' "$MAKE" > "$T/make-app.sh"
  grep -q 'fetch --quiet hub main' "$T/make-app.sh" || { echo "REFUSED: mutant did not apply"; exit 2; }
  cp "$HERE/launch-relaunched.sh" "$T/"   # make-app.sh wants its default launcher beside it
  MAKE="$T/make-app.sh"
fi
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
publish() {  # <version>: commit a fake launcher printing it in the dev clone and push to the hub
  printf '#!/bin/bash\necho "LAUNCHED %s"\n' "$1" > "$T/dev/launch-relaunched.sh"
  git -C "$T/dev" add -A && git -C "$T/dev" commit -qm "$1" && git -C "$T/dev" push -q hub main
}
launch() {  # run the app once; echo "<rc>|<scripts: verdict>|<launcher output, lines joined by +>"
  local log="$T/Library/Logs/sm-relaunched-launcher.log"; : > "$log"
  HOME="$T" "$T/App.app/Contents/MacOS/launch" >/dev/null 2>&1; local rc=$?
  echo "$rc|$(grep -o 'scripts: \(current\|updated\|pull failed\)' "$log" | head -1)|$(grep -E '^(LAUNCHED|LOCAL EDIT)' "$log" | paste -sd+ -)"
}

git init -q --bare -b main "$T/hub.git"
git init -q -b main "$T/dev" && git -C "$T/dev" remote add hub "$T/hub.git"
publish v1
git clone -q -o hub "$T/hub.git" "$T/repo"       # the Mac's checkout; its remote is named hub
mkdir -p "$T/Library/Logs"
SM_APP="$T/App.app" SM_SCRIPT="$T/repo/launch-relaunched.sh" bash "$MAKE" > "$T/make.out" 2>&1
check "make-app.sh builds the app" "$?:$([ -x "$T/App.app/Contents/MacOS/launch" ] && echo shim)" "0:shim"
check "the shim pulls hub main" "$(grep -c 'hub main' "$T/App.app/Contents/MacOS/launch")" 1

check "current: launches, reports current" "$(launch)" "0|scripts: current|LAUNCHED v1"
publish v2
check "behind: pulls, then launches the new version" "$(launch)" "0|scripts: updated|LAUNCHED v2"
check "  ...the checkout is at the hub's head" "$(git -C "$T/repo" rev-parse HEAD)" "$(git -C "$T/dev" rev-parse HEAD)"

publish v3
git -C "$T/repo" remote set-url hub "$T/nonexistent.git"
check "hub unreachable: launches the installed version, exit 0" "$(launch)" "0|scripts: pull failed|LAUNCHED v2"
git -C "$T/repo" remote set-url hub "$T/hub.git"

echo 'echo "LOCAL EDIT"' >> "$T/repo/launch-relaunched.sh"
check "local edit the pull would overwrite: kept, launches, exit 0" "$(launch)" "0|scripts: pull failed|LAUNCHED v2+LOCAL EDIT"
check "  ...the edit survived" "$(git -C "$T/repo" status --porcelain)" " M launch-relaunched.sh"
git -C "$T/repo" checkout -q -- launch-relaunched.sh
check "edit reverted: pulls v3" "$(launch)" "0|scripts: updated|LAUNCHED v3"

echo "$fails failure(s)"
[ "$fails" = 0 ]
