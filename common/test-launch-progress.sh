#!/bin/bash
# test-launch-progress.sh -- compiles common/launch-progress.swift and asks it two things about fixture logs:
# `--parse`, what the progress window would show for a launcher log, and `--decide`, whether the window
# would stay up. Both modes return before any window object is made, and the window itself is never started
# here: the panel is only ever run with one of the two. No game, no Steam, no launcher.
#   bash common/test-launch-progress.sh            exit 0 = every case passed; exit 2 = swiftc is missing,
#                                                  which is not a pass: nothing was tested
#   MUTANT=1 ...    the first step line of the session wins, not the last; must exit 1
#   MUTANT=2 ...    the whole file is read, not the last session; must exit 1
#   MUTANT=3 ...    a line starting ERROR: is ignored; must exit 1
#   MUTANT=4 ...    a step numbered above its total is accepted; must exit 1
#   MUTANT=5 ...    the final step does not latch (the game's own output is read as the launcher's); must exit 1
#   MUTANT=6 ...    the window never closes after the final step; must exit 1
#   MUTANT=7 ...    the window stays up on ERROR:; must exit 1
#   MUTANT=8 ...    no limit on a log that stopped growing; must exit 1
#   MUTANT=9 ...    no limit on the time since start; must exit 1
#   MUTANT=10 ...   the window outlives the shim that started it; must exit 1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/launch-progress.swift"
[ -f "$SRC" ] || { echo "REFUSED: $SRC not found"; exit 2; }
xcrun -f swiftc >/dev/null 2>&1 || { echo "REFUSED: swiftc is missing (install the Xcode Command Line Tools); nothing was tested"; exit 2; }
T="$(mktemp -d /tmp/launch-progress-test.XXXX)"
trap 'rm -rf "$T"' EXIT
cp "$SRC" "$T/p.swift"
mutated() { echo "REFUSED: mutant did not apply"; exit 2; }
drop() {   # <fixed text>: delete the one source line that holds it
  [ "$(grep -cF -- "$1" "$T/p.swift")" = 1 ] || mutated
  grep -vF -- "$1" "$T/p.swift" > "$T/p.new" && mv "$T/p.new" "$T/p.swift"
}
case "${MUTANT:-0}" in
  0) ;;
  1) sed -i '' 's/^        last = \.step(n, of, text)$/        return .step(n, of, text)/' "$T/p.swift"
     grep -q '^        return \.step(n, of, text)$' "$T/p.swift" || mutated ;;
  2) drop 'options: .backwards) { from = r.lowerBound + 1 }' ;;
  3) drop 'if line.hasPrefix("ERROR:") { return .error }' ;;
  4) sed -i '' 's/^    guard of >= 1, n <= of else { return nil }$/    guard of >= 1 else { return nil }/' "$T/p.swift"
     grep -q '^    guard of >= 1 else { return nil }$' "$T/p.swift" || mutated ;;
  5) drop 'if n == of { break }' ;;
  6) drop 'if sinceFinal >= 5 { return false }' ;;
  7) drop 'if case .error = r { return false }' ;;
  8) drop 'if sinceGrew >= 900 { return false }' ;;
  9) drop 'if sinceStart >= 5400 { return false }' ;;
  10) drop 'if !parentIsStarter { return false }' ;;
  *) echo "REFUSED: no mutant ${MUTANT}"; exit 2 ;;
esac
P="$T/launch-progress"
if ! xcrun swiftc -O -o "$P" "$T/p.swift" > "$T/swiftc.out" 2>&1; then
  [ "${MUTANT:-0}" = 0 ] || { echo "REFUSED: mutant ${MUTANT} does not compile"; sed 's/^/    /' "$T/swiftc.out"; exit 2; }
  echo "FAIL  the panel does not compile:"; sed 's/^/    /' "$T/swiftc.out"; exit 1
fi
fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}
parse() { printf '%b' "$1" > "$T/log"; "$P" --parse "$T/log" 2>&1; }
decide() { local log="$1"; shift; printf '%b' "$log" > "$T/log"; "$P" --decide "$T/log" "$@" 2>&1; }
H1='===== 2026-11-10 09:00:00 =====\n'; H2='\n===== 2026-11-10 21:00:00 =====\n'

# --- what the window shows
check "no log file: 0 0" "$("$P" --parse "$T/absent" 2>&1)" "0 0"
check "an empty log: 0 0" "$(parse '')" "0 0"
check "a session with no step: 0 0" "$(parse "${H1}Wrapper: CS2dxmt11.app\nEngine: wine-11.16\n")" "0 0"
check "one step" "$(parse "${H1}[1/5] Checking the Mac fixes for the game…\n")" "1 5 Checking the Mac fixes for the game…"
check "the last step wins" "$(parse "${H1}[1/5] one\nPatches ensured.\n[2/5] two\nsome other line\n")" "2 5 two"
check "a step line with no newline yet" "$(parse "${H1}[1/5] one\n[3/5] three")" "3 5 three"
check "step 0 is a step: [0/5] x is accepted" "$(parse "${H1}[0/5] Waiting for the last session to finish closing…\n")" "0 5 Waiting for the last session to finish closing…"
check "a number above its total is no step: [6/5] x is ignored" "$(parse "${H1}[2/5] two\n[6/5] x\n")" "2 5 two"
check "a total of 0 is no step: [0/0] x is ignored" "$(parse "${H1}[2/5] two\n[0/0] x\n")" "2 5 two"
check "three digits are no step" "$(parse "${H1}[2/5] two\n[100/100] x\n")" "2 5 two"
check "an indented step line is no step" "$(parse "${H1}[1/5] one\n  [2/5] quoted by something else\n")" "1 5 one"
check "brackets in the text survive" "$(parse "${H1}[4/5] Updating the game: 3 min so far [x] (y)…\n")" "4 5 Updating the game: 3 min so far [x] (y)…"
check "only the last session counts: its own step" "$(parse "${H1}[5/5] Starting the game…\n${H2}[1/5] one\n")" "1 5 one"
check "an earlier session holding a step and ERROR:, and an empty last session: 0 0" "$(parse "${H1}[2/5] two\nERROR: Steam did not sign in.\n${H2}")" "0 0"
check "ERROR: before a later step in one session: error" "$(parse "${H1}[1/5] one\nERROR: Steam did not sign in.\n[2/5] two\n")" "error"
check "ERROR: before any step: error" "$(parse "${H1}ERROR: No Wine wrapper found.\n")" "error"
check "ERROR: in mid-line has no effect" "$(parse "${H1}[2/5] two\nWARNING: the log said ERROR: once\n")" "2 5 two"
check "===== in mid-line starts no session" "$(parse "${H1}[2/5] two\na line with ===== in it =====\n")" "2 5 two"
check "the game's own lines after the final step change nothing" "$(parse "${H1}[4/5] Checking for a game update…\n[5/5] Starting the game…\n[UnityMemory] Configuration Parameters\nERROR: Shader compiler: one of the game's own lines\n[2/5] not the launcher's\n")" "5 5 Starting the game…"
check "no ===== line: the whole log is the session" "$(parse "[2/5] two\n[3/5] three\n")" "3 5 three"
check "a bad byte in an earlier session: the last still parses" "$(parse "${H1}[1/5] one \xff\xfe\n${H2}[2/5] two\n")" "2 5 two"
check "a bad byte in this session: the step after it still parses" "$(parse "${H1}\xff\xfe a line that is not UTF-8\n[2/5] two\n")" "2 5 two"

# --- whether the window stays up: <since the log grew> <since the final step, or -1> <since start> <parent>
MID="${H1}[2/5] Starting Steam and signing in…\n"; END="${H1}[5/5] Starting the game…\n"
check "a step in progress: show" "$(decide "$MID" 10 -1 20 1)" show
check "no step yet: show" "$(decide "$H1" 1 -1 1 1)" show
check "4 s after the final step: show" "$(decide "$END" 0 4 60 1)" show
check "5 s after the final step: close" "$(decide "$END" 0 5 60 1)" close
check "ERROR: close at once" "$(decide "${MID}ERROR: Steam did not sign in.\n" 0 -1 20 1)" close
check "899 s of silence: show" "$(decide "$MID" 899 -1 1000 1)" show
check "900 s of silence: close" "$(decide "$MID" 900 -1 1000 1)" close
check "5399 s since start: show" "$(decide "$MID" 10 -1 5399 1)" show
check "5400 s since start: close" "$(decide "$MID" 10 -1 5400 1)" close
check "the parent is no longer the starter: close" "$(decide "$MID" 10 -1 20 0)" close

# --- anything else is a usage error, before any window
"$P" --parse > "$T/usage.out" 2>&1; check "--parse with no log: exit 2" "$?" 2
"$P" --decide "$T/log" 1 x 1 1 > "$T/usage.out" 2>&1; check "--decide with a value that is no number: exit 2" "$?" 2
"$P" --bogus "$T/log" > "$T/usage.out" 2>&1; check "an unknown argument: exit 2" "$?" 2

echo "$fails failure(s)"
[ "$fails" = 0 ]
