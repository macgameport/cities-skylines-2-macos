#!/usr/bin/env python3
"""layer-gap.py — time the layer-swap cycle from a run's wine trace, in milliseconds.

⚠ **This does NOT measure how long issue #12's S3 gap is visible, and it was written believing it
did.** Read the negative result below before using it for anything.

The interval it reports, per child window, is

    retire_superseded_layers(child C, ctx O -> N)  ..  next macdrv_client_surface_present(C)

which looked like the exposure window: at the retire the layer that had been carrying content is
gone, and the host adds the replacement's host view in the same message handler (window.c, the
WM_MACDRV_CREATE_REMOTE_LAYER case -- create the view, then retire the predecessors), so between the
two the hosted layer has no drawable.

**Measured over the ten stage-1 diag runs of 2026-09-06: 2331 such intervals, median 127 ms, and
they total 35.9 s of a 35.4 s drag.** They TILE the drag. That is not a description of anything
visible -- the window renders the store page throughout -- and 127 ms is simply the 120 ms step
period. The child re-creates its swapchain once per resize step, so the time from one retire to the
next present is one step, always. Two things follow:

  * The number is a CADENCE, not an exposure. Do not quote it as a gap duration.
  * "The replacement layer has no drawable yet" is the CONTINUOUS state of this system during a
    drag, not a rare event -- and blue (that layer's background on the diag build) appears on 1
    captured frame in ~3,900. So something covers it essentially always, and the open question for
    issue #13 is what that is and why it occasionally does not, NOT how to shorten the gap.

What the file is still good for, and what it does measure honestly:

    retire_superseded_layers(C, O -> N)  ..  update_remote_layer_frame_for(C, context N)

how long the host waits before installing the replacement's frame -- a median 100 ms, which is the
host-side half of the lag issue #7 is about. `scripts/host-frame-stalls.py` is the one that measures
that lag in pixels-of-window rather than in milliseconds, and it is the one with a claim resting on
it (C57).

⚠ Sort by TIMESTAMP, never by line order. The trace is written by several threads (the child's
0104 and the host's 02e8 both appear in one cycle) and their lines interleave without being
globally ordered -- retire lines routinely sit above presents that preceded them.

Usage:  layer-gap.py <run-dir-or-stdout.txt> [...]      one line of stats per run, plus a pooled total
        layer-gap.py --dump <run>                       every interval, for eyeballing
(macgameport, 2026-09-06)
"""
import os, re, sys, statistics

TS = r'^(\d+\.\d+):([0-9a-f]+):trace:macdrv:'
RETIRE = re.compile(TS + r'retire_superseded_layers retiring superseded layer ctx (\d+) '
                         r'for child (0x[0-9a-f]+) \(replaced by (\d+)\)')
PRESENT = re.compile(TS + r'macdrv_client_surface_present (0x[0-9a-f]+)/')
INSTALL = re.compile(TS + r'update_remote_layer_frame_for child (0x[0-9a-f]+) context (\d+) ')


def events(path):
    """(time, kind, child, ctx) for every event we time, sorted by time."""
    out = []
    for line in open(path, errors='replace'):
        m = RETIRE.match(line)
        if m:
            out.append((float(m.group(1)), 'retire', m.group(4), m.group(5)))
            continue
        m = PRESENT.match(line)
        if m:
            out.append((float(m.group(1)), 'present', m.group(3), None))
            continue
        m = INSTALL.match(line)
        if m:
            out.append((float(m.group(1)), 'install', m.group(3), m.group(4)))
    out.sort(key=lambda e: e[0])
    return out


def gaps(path):
    """Per retire: (child, ms to next present, ms to the replacement's frame install or None)."""
    ev = events(path)
    by_child = {}
    for i, (t, kind, child, ctx) in enumerate(ev):
        by_child.setdefault(child, []).append((i, t, kind, ctx))
    out = []
    for child, seq in by_child.items():
        for j, (i, t, kind, ctx) in enumerate(seq):
            if kind != 'retire':
                continue
            to_present = to_install = None
            for (_, t2, k2, c2) in seq[j + 1:]:
                if to_present is None and k2 == 'present':
                    to_present = (t2 - t) * 1000.0
                if to_install is None and k2 == 'install' and c2 == ctx:
                    to_install = (t2 - t) * 1000.0
                if to_present is not None and to_install is not None:
                    break
            if to_present is not None:
                out.append((child, to_present, to_install))
    return out


def resolve(arg):
    return arg if os.path.isfile(arg) else os.path.join(arg, 'stdout.txt')


def stats(v):
    v = sorted(v)
    p = lambda q: v[min(len(v) - 1, int(q * len(v)))]
    return dict(n=len(v), med=statistics.median(v), p90=p(0.90), mx=v[-1],
                over16=sum(1 for x in v if x > 16.7), over100=sum(1 for x in v if x > 100))


def line(label, v):
    s = stats(v)
    return ('%-34s n=%-4d median %6.1f ms   p90 %6.1f ms   max %7.1f ms   '
            '>1 frame(16.7ms) %3d/%-3d (%2.0f%%)   >100ms %d'
            % (label, s['n'], s['med'], s['p90'], s['mx'],
               s['over16'], s['n'], 100.0 * s['over16'] / s['n'], s['over100']))


if __name__ == '__main__':
    args = sys.argv[1:]
    dump = '--dump' in args
    args = [a for a in args if a != '--dump']
    pooled, pooled_i = [], []
    for a in args:
        p = resolve(a)
        if not os.path.exists(p):
            print('%-34s NO TRACE' % os.path.basename(a.rstrip('/')));  continue
        g = gaps(p)
        if not g:
            print('%-34s no retire/present pairs' % os.path.basename(a.rstrip('/')));  continue
        pres = [x[1] for x in g]
        inst = [x[2] for x in g if x[2] is not None]
        pooled += pres
        pooled_i += inst
        print(line(os.path.basename(a.rstrip('/')), pres))
        if dump:
            for child, tp, ti in g:
                print('    %s  retire -> present %7.1f ms   -> frame install %s'
                      % (child, tp, ('%7.1f ms' % ti) if ti is not None else '      --'))
    if len(args) > 1 and pooled:
        print('-' * 118)
        print(line('POOLED retire -> present', pooled))
    if pooled_i:
        print(line('       retire -> frame install', pooled_i))
