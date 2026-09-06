#!/usr/bin/env python3
"""layer-gap.py — time the S3 pre-drawable gap from a run's wine trace, in milliseconds.

C56 identified issue #12's mechanism as S3: the child's own remote layer exists and is being
hosted, but has not yet produced a drawable, so the region reads as a hole. That was established
from ONE captured frame painting `Tblue=100.0` -- which proves the gap is real but says nothing
about how long it lasts, and "how long" is the whole question for #13 (a 3 ms gap is a non-issue;
a 100 ms gap is six frames of hole at 60 Hz).

Frame captures cannot answer it. The probe samples every ~113 ms, so a gap shorter than that is
aliased to "present or absent" and one longer is bounded only to the nearest sample. The trace
carries the same events at 1 ms resolution, hundreds of times per drag, and is already on disk
beside every run -- so this measures the gap directly instead of inferring it from pixels.

The interval measured, per child window, is:

    retire_superseded_layers(child C, ctx O -> N)  ..  next macdrv_client_surface_present(C)

At the retire, the layer that had been carrying content is gone. The next present on that child is
the first moment new content exists. Everything between is the window in which nothing the child
drew is available. Reported alongside it, because it is the actionable half for a fix:

    retire_superseded_layers(C, O -> N)  ..  update_remote_layer_frame_for(C, context N)

which is how long the host waits before it even installs the replacement's frame.

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
