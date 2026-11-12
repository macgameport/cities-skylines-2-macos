#!/bin/bash
# test-launch-lock.sh [<launcher> ...] -- fixtures for the one-launcher-per-Wine-prefix lock
# (LOCK, lock_holder, acquire_lock, release_lock). The functions are copied out of each launcher and
# run in throwaway bash processes against a temporary lock path: no game, no Steam. Then every copy of
# them must be identical: one implementation in two launchers, Cities: Skylines II's and Surviving Mars's
# (a third, for a Wine 10 stack that shared a prefix with Surviving Mars, was retired on 2026-11-09), and
# in Cities: Skylines II's installer, which holds the lock while it starts and closes that prefix's Steam
# (docs/plans/simple-install.md, 2.3).
# The functions move into shared code in Phase 5 of docs/plans/1launcher-unification.md.
#   bash common/test-launch-lock.sh            exit 0 = every case passed; exit 2 = a launcher is missing
#   MUTANT=1 bash common/test-launch-lock.sh   acquire_lock always succeeds (no lock); must exit 1
# Files given as arguments replace the three it finds by itself; the exit-2 rule is for those three.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHERS=()
if [ $# -gt 0 ]; then
  LAUNCHERS=("$@")
else
  for f in surviving-mars-relaunched/launch-relaunched.sh cities-skylines-2/launchers/launch-cs2-dxmt11.sh \
           common/install-core.sh; do
    [ -f "$HERE/$f" ] || { echo "REFUSED: $f not found under $HERE"; exit 2; }
    LAUNCHERS+=("$HERE/$f")
  done
fi
T="$(mktemp -d /tmp/launch-lock-test.XXXX)"
trap 'rm -rf "$T"' EXIT

# one function from a launcher: a one-liner `f() { ...; }` alone, else through its closing `}` (a plain
# sed range would run past a one-liner into the launcher code that takes the lock)
fn() {
  awk -v f="$1" 'index($0, f "() {") == 1 { print; if ($0 ~ /; }[[:space:]]*$/) exit; p = 1; next }
                 p { print; if ($0 ~ /^}/) exit }' "$2"
}
lock_code() { grep '^LOCK=' "$1"; for f in lock_holder acquire_lock release_lock; do fn "$f" "$1"; done; }

# a fake launcher: <functions file> <lock path> <tries> <seconds to hold>; prints GOT or BUSY
cat > "$T/launcher.sh" <<'EOF'
. "$1" "$2"
acquire_lock "$3" || { echo BUSY; exit 1; }
trap release_lock EXIT
echo GOT; sleep "$4"
EOF

fails=0
check() {  # <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fails=$((fails + 1)); fi
}

n=0
for L in "${LAUNCHERS[@]}"; do
  n=$((n + 1)); D="$T/$n"; mkdir -p "$D"; FN="$D/fns.sh"; LK="$D/.launcher.lock"; tag="${L##*/}:"
  {
    echo 'LOCK="$1"'
    echo 'note() { :; }; step() { :; }; die() { echo "DIE $1"; exit 1; }; game_running() { return 1; }'
    for f in lock_holder acquire_lock release_lock; do
      fn "$f" "$L" | grep -q . || { echo "REFUSED: $f not found in $L" >&2; exit 2; }
      fn "$f" "$L"
    done
    if [ "${MUTANT:-0}" = 1 ]; then echo 'acquire_lock() { return 0; }'; fi
  } > "$FN" || exit 2

  check "$tag free lock is taken" "$(bash "$T/launcher.sh" "$FN" "$LK" 1 0)" GOT
  check "$tag exit releases the lock" "$([ -L "$LK" ] && echo held || echo free)" free

  bash -c 'exit 0' & dead=$!; wait $dead
  ln -s "$dead" "$LK"
  check "$tag stale lock (dead pid) is cleared and taken" "$(bash "$T/launcher.sh" "$FN" "$LK" 1 0)" GOT

  bash "$T/launcher.sh" "$FN" "$LK" 1 6 > "$D/a.out" & a=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -L "$LK" ] && break; sleep 0.3; done
  check "$tag second launch is refused while the first holds the lock" "$(bash "$T/launcher.sh" "$FN" "$LK" 1 0)" BUSY
  check "$tag the lock still names the first launcher" "$(readlink "$LK")" "$a"
  check "$tag second launch waits, then gets the lock" "$(bash "$T/launcher.sh" "$FN" "$LK" 8 0)" GOT
  wait "$a"
  check "$tag first launcher had the lock" "$(cat "$D/a.out")" GOT
done

# parity: every copy of the lock code is identical
ALL=("${LAUNCHERS[@]}")
ref="$(lock_code "${ALL[0]}")"
for f in "${ALL[@]}"; do
  [ "$(lock_code "$f")" = "$ref" ] && check "parity: lock code in $f" same same || check "parity: lock code in $f" differs "same as ${ALL[0]}"
done

echo "$fails failure(s)"
[ "$fails" = 0 ]
