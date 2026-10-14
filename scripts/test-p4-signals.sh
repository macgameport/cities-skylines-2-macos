#!/bin/bash
# test-p4-signals.sh — exercises scripts/p4-signals.py (perf-pass P4's load-signal gate) on synthetic
# Player.logs shaped like the real graceful-exit allocator report, then (if present) on the real
# perf-run logs in ~/cs2-patch/perf-runs. No game, no Wine. Runs in about a second.
#
#   bash scripts/test-p4-signals.sh [path/to/p4-signals.py]
#
# The optional argument lets a mutant copy be tested: each mutant below must turn a case red.
#   M1 unanchored worker regex (match 'Job.Worker N' anywhere)  -> case 3 reads 15, not 11
#   M2 sum Failed count over all four [ALLOC_BUCKET] copies     -> case 6 reads 4x
#   M3 drop the truncation check                                 -> case 5 exits 0/3, not 2
# Exit 0 = every case passed.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
X="${1:-$REPO/scripts/p4-signals.py}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

/usr/bin/python3 - "$T" <<'PY'
import sys, os
d = sys.argv[1]
def bucket(used, fails):
    rows = ''.join('        %dB: 1 Subsections = 1 buckets. Failed count: %d\n' % (16 * (i + 1), f)
                   for i, f in enumerate(fails))
    return ('    [ALLOC_BUCKET]\n      Large Block size 4.0 MB\n      Used Block count %d\n'
            '      Peak Allocated bytes 4.0 MB\n      Failed Allocations. Bucket layout:\n%s' % (used, rows))
def log(workers=17, used=1, fails=(100, 200, 300, 400, 500, 600, 700, 800), copies=4,
        report=True, with_bucket=True):
    s = 'Game terminated successfully\n'
    if not report:
        return s.replace('Game terminated successfully\n', 'Received signal SIGTERM\n')
    s += 'Memory Statistics:\n[ALLOC_TEMP_TLS] TLS Allocator\n  StackAllocators : \n'
    s += ('    [ALLOC_TEMP_MAIN]\n      Peak usage frame count: [8.0 KB-16.0 KB]: 700 frames, '
          '[32.0 KB-64.0 KB]: 5490 frames, [4.0 MB-8.0 MB]: 10 frames\n'
          '      Initial Block Size 4.0 MB\n      Current Block Size 8.0 MB\n'
          '      Peak Allocated Bytes 7.8 MB\n      Overflow Count 9036\n')
    for i in range(workers):
        s += '    [ALLOC_TEMP_Job.Worker %d]\n      Initial Block Size 256.0 KB\n      Overflow Count 0\n' % i
    for i in range(16):
        s += '    [ALLOC_TEMP_Background Job.Worker %d]\n      Initial Block Size 32.0 KB\n' % i
    if with_bucket:
        s += bucket(used, fails) * copies
    s += '[ALLOC_TEMP_JOB_ASYNC (Background)]\n  Initial Block Size 1.0 MB\n  Used Block Count 2\n'
    return s
cases = {'default': log(), 'bucket4': log(used=4), 'workers12': log(workers=12),
         'sigterm': log(report=False), 'truncated': log(with_bucket=False)}
for k, v in cases.items():
    open(os.path.join(d, k + '.log'), 'w').write(v)
PY

FAILS=0
run() { /usr/bin/python3 "$X" "$T/$1.log" ${2:+--expect "$2"}; }
case_rc() {   # name log expect want-rc
  out=$(run "$2" "$3" 2>&1); rc=$?
  if [ "$rc" = "$4" ]; then echo "pass $1 (rc $rc)"; else echo "FAIL $1: rc $rc, want $4 — $out"; FAILS=$((FAILS + 1)); fi
}
case_field() {   # name log jq-ish-python-expr want
  got=$(run "$2" | /usr/bin/python3 -c "import json,sys; r=json.loads(sys.stdin.read()); print($3)" 2>&1)
  if [ "$got" = "$4" ]; then echo "pass $1 ($got)"; else echo "FAIL $1: got [$got], want [$4]"; FAILS=$((FAILS + 1)); fi
}

case_rc    "1 default reads as control"            default   control    0
case_rc    "1 default is not a bucket KEEP"        default   bucket     3
case_rc    "1 default is not workers=12"           default   workers=12 3
case_rc    "2 bucket key applied"                  bucket4   bucket     0
case_rc    "2 bucket key leaks into a control"     bucket4   control    3
case_rc    "3 workers=12 applied"                  workers12 workers=12 0
case_field "3 anchored worker max (not Background 15)" workers12 "r['job_worker_max']" 11
case_rc    "3 workers key leaks into a control"    workers12 control    3
case_rc    "4 SIGTERM log is VOID"                 sigterm   control    2
case_rc    "5 truncated report is VOID"            truncated control    2
case_field "6 bucket = FIRST section only"         default   "r['bucket']['failed_sum']" 3600
case_field "6 per frame uses ALLOC_TEMP_MAIN frames" default "r['failed_per_frame']" 0.6
case_field "6 four identical bucket copies seen"   default   "r['bucket']['sections'], r['bucket']['identical']" "4 True"

# Live: every real perf-run log, read with --expect control.
L="$HOME/cs2-patch/perf-runs"
if ls "$L"/*-Player.log >/dev/null 2>&1; then
  n=0; bad=0
  for f in "$L"/*-Player.log; do
    /usr/bin/python3 "$X" "$f" --expect control >/dev/null; rc=$?
    # No boot.config key has ever been set, so a log WITH a report must read as control (0) and one
    # without (SIGTERM'd, incl. the teardown mutant and pre-2026-10-10 cycles) as VOID (2).
    if grep -q 'Memory Statistics:' "$f"; then want=0; else want=2; fi
    [ "$rc" = "$want" ] || { echo "FAIL live: $(basename "$f") rc $rc, want $want"; bad=$((bad + 1)); }
    n=$((n + 1))
  done
  [ "$bad" = 0 ] && echo "pass live: $n real logs" || FAILS=$((FAILS + bad))
else
  echo "skip live: no perf-run logs"
fi

[ "$FAILS" -eq 0 ] && { echo "ALL PASS"; exit 0; }
echo "$FAILS FAILED"; exit 1
