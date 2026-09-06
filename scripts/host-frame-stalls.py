#!/usr/bin/env python3
"""host-frame-stalls.py — find drag segments the host layer never tracked, from a run's wine trace.

Issue #7's strip is normally a LAG of one or two 25 px steps: the host installs a frame for every
step, each slightly behind the window, and the uncovered sliver is a few per cent of the right band.
This finds the severe tail of the same defect -- a segment in which `update_remote_layer_frame_for`
does not run at all while the window grows, so the host stays at its pre-drag width for seconds and
the whole grown area is uncovered.

A stall is a single install-to-install width jump on ONE CHILD, in time order, that

  * grows by more than `thresh` px (a tracked segment steps 25-75 px at the calibrated cadence),
  * starts from a width of at least `min_prev` -- a host's FIRST install goes 0 -> full size by
    definition, which is the create path and not a segment anyone failed to track, and
  * takes at least `min_seconds`. Those creates complete in 0.1-0.2 s; a real stall spans a whole
    drag segment. A jump is only evidence if the host sat at the old width long enough to be seen.

⚠ Group by CHILD in time order -- not by child+context, and not across children. Each resize step
creates a new context, so the width progression lives ACROSS contexts and grouping by context
destroys the signal entirely (it scored 0 of 42 on runs whose pixels show a stall outright).
Pooling all children instead manufactures jumps, because one window's children legitimately differ
in size. Both errors were made here before this comment existed.

⚠ The summary line for a clean run is computed by the SAME function as the detection, so the two
cannot disagree. An earlier version summarised with different filters and printed "widest step
650 px" on runs it had just declared tracked.

Cross-checked against the pixels on the two runs that show it: solving dark% = (W - x)/W per frame
gives a CONSTANT frozen content width (1006, 1006, 1007 px) across each episode, matching the
trace's stalled install width to within a pixel.

Usage:  host-frame-stalls.py <run-dir> [...]
(macgameport, 2026-09-06)
"""
import os, re, sys

INSTALL = re.compile(r'^(\d+\.\d+):[0-9a-f]+:trace:macdrv:update_remote_layer_frame_for '
                     r'child (0x[0-9a-f]+) context (\d+) frame \(0,0\)-\((\d+),(\d+)\)')
THRESH, MIN_PREV, MIN_SECONDS = 300, 200, 1.0


def installs(path):
    out = []
    for line in open(path, errors='replace'):
        m = INSTALL.match(line)
        if m:
            out.append((float(m.group(1)), m.group(2), int(m.group(4))))
    return out


def steps(path):
    """Every install-to-install grow on one child, in time order, past the create filter."""
    by = {}
    for t, child, w in installs(path):
        by.setdefault(child, []).append((t, w))
    out = []
    for child, seq in by.items():
        for i in range(1, len(seq)):
            (t0, w0), (t1, w1) = seq[i - 1], seq[i]
            if w1 > w0 and w0 >= MIN_PREV:
                out.append((t0, t1 - t0, child, w0, w1))
    return sorted(out)


if __name__ == '__main__':
    nrun = nstall = 0
    for a in sys.argv[1:]:
        p = a if os.path.isfile(a) else os.path.join(a, 'stdout.txt')
        if not os.path.exists(p):
            continue
        name = os.path.basename(a.rstrip('/'))
        ins = installs(p)
        if not ins:
            print('%-46s no installs traced' % name)
            continue
        nrun += 1
        st = steps(p)
        bad = [s for s in st if s[4] - s[3] > THRESH and s[1] >= MIN_SECONDS]
        if bad:
            nstall += 1
            for t, dt, child, w0, w1 in bad:
                print('%-46s STALL %4.1f s  child %s  host %d -> %d px in one step '
                      '(%d px never tracked)' % (name, dt, child, w0, w1, w1 - w0))
        else:
            print('%-46s tracked · %d installs · widest grow step %d px'
                  % (name, len(ins), max((s[4] - s[3] for s in st), default=0)))
    if nrun:
        print('\n%d of %d runs contain a stalled grow segment (%.0f%%)'
              % (nstall, nrun, 100.0 * nstall / nrun))
