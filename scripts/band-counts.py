#!/usr/bin/env python3
"""band-counts.py — count frames whose outer 10% band is >= 20% true black, per edge.

Reads darkboxes.swift output (one line per frame, flat key=value) and counts by BAND. The probes'
own one-line summary ORs all four bands together, which is what hid the growing-edge strip for a
day: a 280 px black column on the right diluted to nothing against three clean edges (C35). Parses
by LABEL, never by position -- positional awk on that line has published two wrong counts.
(macgameport, 2026-09-03)
"""
import os, re, sys

cnt = {'L': 0, 'R': 0, 'T': 0, 'B': 0}
worst = dict.fromkeys(cnt, 0.0)
right = {}          # frame number -> right-band black %, joined by FILENAME below, never by line order
n = 0
for line in open(sys.argv[1]):
    d = dict(re.findall(r'\b([A-Za-z]+)=\s*([0-9.]+)', line))
    if 'R' not in d:
        continue
    n += 1
    m = re.match(r'f(\d+)\.png', line)
    if m:
        right[int(m.group(1))] = float(d['R'])
    for b in cnt:
        v = float(d[b])
        worst[b] = max(worst[b], v)
        if v >= 20:
            cnt[b] += 1
if not n:
    print('no frames scored'); sys.exit(1)
print('bands >=20%% true black over %d frames:  ' % n +
      '  '.join('%s %d/%d (worst %.0f%%)' % (b, cnt[b], n, worst[b]) for b in ('L', 'R', 'T', 'B')))

# The finer metric, when the probe's sizes.txt sits beside the frames: the right band's mean and max
# over GROWING frames only (width larger than the previous capture's). The >=20% count above is too
# coarse for an A/B -- on 2026-09-05 stage 1 scored 0/60 at every cadence while its growing frames
# still averaged 5-7% black against 12-17% on the baseline (C50). darkboxes lists frames in
# filename order (f1, f10, f11 ...) and sizes.txt in capture order, so the join is by frame NUMBER
# parsed from the filename; a positional paste of the two files misattributes every band.
sizes = os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), 'frames', 'sizes.txt')
if right and os.path.exists(sizes):
    widths = []
    for l in open(sizes):
        m = re.search(r'size=(\d+)x', l)
        widths.append(int(m.group(1)) if m else 0)
    grow = [i for i in range(2, len(widths) + 1) if widths[i - 1] > widths[i - 2] and i in right]
    if grow:
        vals = [right[i] for i in grow]
        print('right band over growing frames (%d of %d): mean %.1f%% · max %.1f%% · >=10%%: %d'
              % (len(grow), len(widths), sum(vals) / len(vals), max(vals), sum(v >= 10 for v in vals)))
    else:
        print('right band over growing frames: none grew while sampling')
