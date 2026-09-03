#!/usr/bin/env python3
"""band-counts.py — count frames whose outer 10% band is >= 20% true black, per edge.

Reads darkboxes.swift output (one line per frame, flat key=value) and counts by BAND. The probes'
own one-line summary ORs all four bands together, which is what hid the growing-edge strip for a
day: a 280 px black column on the right diluted to nothing against three clean edges (C35). Parses
by LABEL, never by position -- positional awk on that line has published two wrong counts.
(macgameport, 2026-09-03)
"""
import re, sys

cnt = {'L': 0, 'R': 0, 'T': 0, 'B': 0}
worst = dict.fromkeys(cnt, 0.0)
n = 0
for line in open(sys.argv[1]):
    d = dict(re.findall(r'\b([A-Za-z]+)=\s*([0-9.]+)', line))
    if 'R' not in d:
        continue
    n += 1
    for b in cnt:
        v = float(d[b])
        worst[b] = max(worst[b], v)
        if v >= 20:
            cnt[b] += 1
if not n:
    print('no frames scored'); sys.exit(1)
print('bands >=20%% true black over %d frames:  ' % n +
      '  '.join('%s %d/%d (worst %.0f%%)' % (b, cnt[b], n, worst[b]) for b in ('L', 'R', 'T', 'B')))
