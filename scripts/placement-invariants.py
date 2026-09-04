#!/usr/bin/env python3
"""placement-invariants.py — what the issue-#7 placement trace says about the hosting layer.

    python3 scripts/placement-invariants.py <cell stdout.txt> [more...]

Two invariants, both read from `+macdrv` placement traces. Neither is visible in pixels, which is
the point: each replaces a pixel criterion that could not discriminate on this build.

**1. No host is placed at a SUB-PIXEL scale** (a factor in (0.990, 1.000)).
`snap_host_frame_to_view_edges` aligns a host rect to the view edge, so a full-client host lands
exactly on it and its scale is 1.000 or an honest churn ratio. Drop the snap and the rect arrives a
fraction of a point short, which shows up here and nowhere else. This is mutant **E2**'s signal.
The plan originally asked for a BRIGHT edge at 2399x1499 instead, and that cannot work on this
build: the seam the snap covers is *also* covered by the create path's deferred background, so
removing either mechanism still leaves no white. Measured 2026-09-03 — fixed module **0** sub-pixel
placements over 4133 (two independent sessions), E2 **230** of 1104 (`0.999,1.000` x172,
`0.999,0.960` x57, `0.999,0.999` x1).

**2. A host's frame ORIGIN never changes.** Every placement of a given context id keeps its origin
and varies only in size and scale. This is what T7's shrink clause needs: the plan allows the
frame-14 displacement to be attributed by the trace rather than by a band count ("*or, if it
persists, the trace says which layer moved*"), and the answer is that **none of them move** — shrink
placements are pure scale about a fixed top-left corner (`anchorPoint (0,0)` with
`geometryFlipped=YES`, C37). Measured on the T7 height churn: **0 of 906** hosts with creation width
>= 1000 changed origin, across 1930 placements. So the displacement is not a host-position effect,
and mutant E6 (clamp the scale to >= 1) is not applicable.
"""
import re, sys, collections

if len(sys.argv) < 2:
    sys.exit(__doc__)

PAT = re.compile(r'child (0x[0-9a-f]+) context (\d+) frame '
                 r'\((-?\d+),(-?\d+)\)-\((-?\d+),(-?\d+)\).*'
                 r'creation (\d+)x(\d+) scale ([\d.]+),([\d.]+)')
MIN_W = 1000     # only hosts big enough to be a full-client or page layer

fail = 0
for path in sys.argv[1:]:
    byctx = collections.OrderedDict()
    total = subpx = 0
    vals = collections.Counter()
    for line in open(path, errors='ignore'):
        m = PAT.search(line)
        if not m:
            continue
        g = m.groups()
        total += 1
        sx, sy = float(g[8]), float(g[9])
        if any(0.990 < v < 1.000 for v in (sx, sy)):
            subpx += 1
            vals["%s,%s" % (g[8], g[9])] += 1
        byctx.setdefault(g[1], []).append(g)

    big = [(c, v) for c, v in byctx.items() if int(v[0][6]) >= MIN_W]
    moved = [c for c, v in big if len({(p[2], p[3]) for p in v}) > 1]
    npl = sum(len(v) for _, v in big)

    print("%s" % path)
    print("  placements %d · contexts %d · large hosts %d (%d placements)"
          % (total, len(byctx), len(big), npl))
    print("  sub-pixel placements : %d%s" % (subpx, "   " + ", ".join(
          "%s x%d" % (k, n) for k, n in vals.most_common(4)) if subpx else ""))
    print("  large hosts that MOVED: %d" % len(moved))
    for c in moved[:5]:
        v = byctx[c]
        print("      ctx %-11s origins %s" % (c, sorted({(p[2], p[3]) for p in v})[:4]))
    bad = []
    if subpx:
        bad.append("%d sub-pixel placement(s) — the snap did not run" % subpx)
    if moved:
        bad.append("%d host(s) changed origin" % len(moved))
    print("  -> %s" % ("FAIL: " + "; ".join(bad) if bad else "PASS: no sub-pixel placement, no host moved"))
    fail += bool(bad)
sys.exit(1 if fail else 0)
