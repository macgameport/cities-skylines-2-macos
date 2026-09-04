#!/usr/bin/env python3
"""t6-scale-at-rest.py — issue #7 T6: no hosted layer is left scaled once the resize is over.

    python3 scripts/t6-scale-at-rest.py <cell stdout.txt>

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
"""
import re, sys

if len(sys.argv) < 2:
    sys.exit(__doc__)

PLACE = re.compile(r'context (\d+) frame (\S+) zpos \S+ creation (\d+)x(\d+) scale ([\d.]+),([\d.]+)')
RETIRE = re.compile(r'retiring superseded layer ctx (\d+)')
RELEASE = re.compile(r'WM_MACDRV_RELEASE_REMOTE_LAYER context_id (\d+)')

lines = open(sys.argv[1], errors='ignore').readlines()
# Deaths count only up to the LAST placement trace. Everything after the last size change is
# teardown: shutting Steam down releases every remote layer, so counting those retires would let a
# genuinely stuck scaled host escape the check by dying at exit -- which is the one failure T6
# exists to catch.
cut = max((i for i, l in enumerate(lines) if PLACE.search(l)), default=-1)

last, dead, n = {}, set(), 0
for i, line in enumerate(lines):
    m = PLACE.search(line)
    if m:
        n += 1
        last[m.group(1)] = (m.group(3) + 'x' + m.group(4), m.group(5), m.group(6))
        continue
    if i <= cut:
        m = RETIRE.search(line) or RELEASE.search(line)
        if m:
            dead.add(m.group(1))

alive = {c: v for c, v in last.items() if c not in dead}
off = {c: v for c, v in alive.items() if (v[1], v[2]) != ('1.000', '1.000')}
print("placements %d · contexts %d · retired/released %d · surviving %d"
      % (n, len(last), len(last) - len(alive), len(alive)))
for c, v in sorted(alive.items(), key=lambda kv: -int(kv[1][0].split('x')[0]))[:6]:
    print("  ctx %-11s creation %-11s scale %s,%s" % (c, v[0], v[1], v[2]))
if off:
    print("T6 FAIL: %d surviving context(s) left off identity" % len(off))
    for c, v in off.items():
        print("  ctx %-11s creation %-11s scale %s,%s" % (c, v[0], v[1], v[2]))
    sys.exit(1)
print("T6 PASS: every surviving context's last placement is scale 1.000,1.000")
