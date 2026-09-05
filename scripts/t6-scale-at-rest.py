#!/usr/bin/env python3
"""t6-scale-at-rest.py — issue #7 T6: no hosted layer is left scaled once the resize is over.

    python3 scripts/t6-scale-at-rest.py <cell stdout.txt> [--window 3.0]

Reads the `+macdrv` trace and reports, per SURVIVING context id, the scale its last placement left
it at. Exits non-zero if any survivor is off identity.

⚠ "Surviving" is the whole test, and the naive version is badly wrong. A churn on the Steam store
retires hundreds of contexts -- every tooltip, thumbnail and video surface is its own remote layer
-- and a retired host's last trace is frequently NOT identity, because being scaled is exactly what
stage 1 does to a stale host in the moment before its replacement arrives. Measured 2026-09-03 on
one 40-frame churn: 490 distinct contexts, 434 of them last seen off identity, and every one of
those had been retired. Reading that as 434 failures would have condemned a mechanism that was
working; the log shows the opposite -- e.g. ctx 3548379062, creation 1920x1050, placed at
1.250,1.429 when the window grew to 2400x1500, retired 45 lines later for its replacement, then
released. That is the fix doing its job.

A context is retired by either of two traces, and both must be honoured: `retire_superseded_layers`
(the owner drops it when a replacement lands) and `WM_MACDRV_RELEASE_REMOTE_LAYER` (the child says
it is gone).

⚠ The cut is the last placement trace, and a supersede AFTER it still counts (2026-09-05). The
resize's last step -- and on stage 2 the end-of-loop re-derive -- places every full-client host
from the child's rect while the swapchain behind it is still the previous size, so the last
placement line reads a small scale (1.003 to 1.035 measured). CEF then re-creates the swapchain at
the final size and the owner retires the scaled host for the replacement, whose own placement is
identity by construction: the CREATE handler stores frame.size as the content size and traces
`layer frame in root`, never a placement line. Those retires land 21-65 lines AFTER the last
placement, so a cut at the last placement discarded exactly the event T6 waits for. Measured
2026-09-05 across every T6 FAIL to date -- S-A and S-B of `stage2-tests/20260904-191349`,
`drag/t0-20260904-172306` (C45) and `drag/t2b-20260904-172841` (C46): all four were this artifact,
and each "survivor" had its replacement created three lines before its retire. So a
retire-by-supersede counts whenever it occurs (it needs a live child creating a new layer, which
teardown never does); a RELEASE still counts only up to the cut, because shutting Steam down
releases everything and that must not pardon a stuck host. With `+timestamp` in the trace a late
supersede must also land within --window seconds of the last placement (T6's "3 s after the last
size change"), and the delay is printed; without timestamps it is counted and reported as untimed.
"""
import re, sys

if len(sys.argv) < 2:
    sys.exit(__doc__)

WINDOW = 3.0
args = sys.argv[1:]
if '--window' in args:
    i = args.index('--window')
    WINDOW = float(args[i + 1])
    del args[i:i + 2]

TS = re.compile(r'^\s*(\d+)\.(\d{3}):')
PLACE = re.compile(r'context (\d+) frame (\S+) zpos \S+ creation (\d+)x(\d+) scale ([\d.]+),([\d.]+)')
RETIRE = re.compile(r'retiring superseded layer ctx (\d+) for child \S+ \(replaced by (\d+)\)')
RELEASE = re.compile(r'WM_MACDRV_RELEASE_REMOTE_LAYER context_id (\d+)')

lines = open(args[0], errors='ignore').readlines()


def ts(line):
    m = TS.match(line)
    return int(m.group(1)) + int(m.group(2)) / 1000.0 if m else None


# Deaths by RELEASE count only up to the LAST placement trace. Everything after the last size change
# is teardown: shutting Steam down releases every remote layer, so counting those would let a
# genuinely stuck scaled host escape the check by dying at exit -- the one failure T6 exists to catch.
cut = max((i for i, l in enumerate(lines) if PLACE.search(l)), default=-1)
t_cut = ts(lines[cut]) if cut >= 0 else None
timed = t_cut is not None

last, dead, n = {}, set(), 0
late, too_late = {}, {}     # supersedes after the cut: ctx -> (line, delay-or-None)
for i, line in enumerate(lines):
    m = PLACE.search(line)
    if m:
        n += 1
        last[m.group(1)] = (m.group(3) + 'x' + m.group(4), m.group(5), m.group(6))
        continue
    m = RETIRE.search(line)
    if m:
        if i <= cut:
            dead.add(m.group(1))
            continue
        delay = None
        if timed:
            t = ts(line)
            delay = (t - t_cut) if t is not None else None
        if delay is not None and delay > WINDOW:
            too_late[m.group(1)] = (i, delay)
        else:
            dead.add(m.group(1))
            late[m.group(1)] = (i, delay)
        continue
    if i <= cut:
        m = RELEASE.search(line)
        if m:
            dead.add(m.group(1))

# A build without the stage-1 scale TRACE (`717d431`) -- the pre-stage-1 baseline, say -- emits no
# placement line at all, and "no survivors" must not read as PASS there (K2/K4, 2026-09-05).
if not last:
    print("T6 N/A: no placement traces in this run -- a pre-stage-1 module, or a trace without +macdrv")
    sys.exit(2)
alive = {c: v for c, v in last.items() if c not in dead}
off = {c: v for c, v in alive.items() if (v[1], v[2]) != ('1.000', '1.000')}
print("placements %d · contexts %d · retired/released %d · surviving %d · last placement at line %d%s"
      % (n, len(last), len(last) - len(alive), len(alive), cut + 1, (" t=%.3f" % t_cut) if timed else ""))
for c, v in sorted(alive.items(), key=lambda kv: -int(kv[1][0].split('x')[0]))[:6]:
    print("  ctx %-11s creation %-11s scale %s,%s" % (c, v[0], v[1], v[2]))
if late:
    ds = [d for _, d in late.values() if d is not None]
    when = (", landing %.0f-%.0f ms after it" % (min(ds) * 1000, max(ds) * 1000)) if ds \
        else ", untimed -- no +timestamp in the trace"
    print("superseded after the last placement: %d (CEF's final re-create; counted as retired%s)"
          % (len(late), when))
for c, (i, d) in too_late.items():
    print("  ctx %-11s superseded only %.1f s after the last placement (line %d), outside the %.0f s window: still a survivor"
          % (c, d, i + 1, WINDOW))
if off:
    for c, v in off.items():
        print("  ctx %-11s creation %-11s scale %s,%s" % (c, v[0], v[1], v[2]))
    print("T6 FAIL: %d surviving context(s) left off identity" % len(off))
    sys.exit(1)
print("T6 PASS: every surviving context's last placement is scale 1.000,1.000")
