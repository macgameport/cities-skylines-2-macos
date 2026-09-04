#!/usr/bin/env python3
"""churn-grow-shrink.py — score a churn's GROW and SHRINK frames per band, against a static control.

    python3 scripts/churn-grow-shrink.py <lum-threshold> <churn-dir> [static-dir]

Frames are classified grow/shrink by pixel count against the previous frame (issue #7 T7's own
rule), then each outer 10 % band is counted at the given luminance threshold. If a static directory
is given its frames are scored the same way and printed as the BASELINE.

⚠ **Never state a band criterion without its baseline at the same threshold.** T7's shrink clause
was written as "bottom band >= 20 % at lum < 40 -> 0" after a review correctly found that the
frame-14 signature is dark grey, not true black (`B` 0.0 % at lum < 6, 67.6 % at lum < 40), and
restated the threshold so the mutant could be observed red. Nobody scored the control at the new
threshold. Measured 2026-09-03: the STATIC window — never resized — scores `B >= 20 %` in **40 of
40** frames at lum < 40, worst 79.4 %, and `T` in 40 of 40 at worst 91.4 %, because the Steam store
page is full of dark artwork. The criterion is satisfied by a window that is not being resized, so
it can never go green. Fixing a criterion that could never go RED produced one that could never go
GREEN, and only the control shows it.
"""
import re, sys, glob, subprocess

if len(sys.argv) < 3:
    sys.exit(__doc__)
thr, churn = sys.argv[1], sys.argv[2]
static = sys.argv[3] if len(sys.argv) > 3 else None
BANDS = ('L', 'R', 'T', 'B')

def rows(d):
    files = sorted(glob.glob(d.rstrip('/') + '/f*.png'),
                   key=lambda x: int(re.search(r'f(\d+)', x).group(1)))
    if not files:
        return []
    out = subprocess.run(['/tmp/darkboxes', thr] + files, capture_output=True, text=True).stdout
    r = []
    for line in out.splitlines():
        m = re.match(r'(\S+) (\d+)x(\d+) ', line)
        if not m:
            continue
        d2 = dict(re.findall(r'\b([A-Za-z]+)=\s*([0-9.]+)', line))
        r.append((m.group(1), int(m.group(2)) * int(m.group(3)),
                  {b: float(d2[b]) for b in BANDS}))
    return r

def report(label, rs):
    if not rs:
        print("  %-22s no frames" % label); return
    print("  %-22s %d frames" % (label, len(rs)))
    for b in BANDS:
        n = sum(1 for r in rs if r[2][b] >= 20)
        w = max(r[2][b] for r in rs)
        print("      %s  >=20%%: %2d/%-3d  worst %5.1f%%" % (b, n, len(rs), w))

r = rows(churn)
grow = [x for i, x in enumerate(r) if i and x[1] > r[i-1][1]]
shrink = [x for i, x in enumerate(r) if i and x[1] < r[i-1][1]]
print("lum<%s  %s" % (thr, churn))
report("GROW", grow)
report("SHRINK", shrink)
if static:
    print("BASELINE (static, never resized) — any criterion must beat this:")
    report("STATIC", rows(static))
