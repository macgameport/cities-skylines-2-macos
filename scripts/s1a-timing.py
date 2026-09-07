#!/usr/bin/env python3
"""s1a-timing.py -- the S3 plan's S1a, computed from a stamp build's trace.

    s1a-timing.py <run-dir-or-stdout.txt> [...]        pooled, one line per run plus the verdict
    s1a-timing.py --dump <run>                         every generation, for eyeballing

⚠ Run `align-trace-video.py --check-clock` on the same runs FIRST. Every number here is a
subtraction across two processes, and it is only meaningful if the child's self-printed ticks sit
on wine's clock. That gate is not optional and this script refuses without it having been possible:
it re-checks the range itself and says so.

────────────────────────────────────────────────────────────────────────────────────────────────
WHAT IT MEASURES, and the two halves decide different things.

A "generation" is one CAContextSwapChain -- one context id -- for one child. Per generation:

  owner commit  window.c:1717  WM_MACDRV_CREATE_REMOTE_LAYER child C context_id N   (wine tick)
  child create  stamp create   ctx=N                                                (wine tick)
  first acquire stamp acquire  ctx=N       the first nextDrawable of that generation
  present       stamp presented ctx=N pres=P   P is on the MACH clock, so it is converted with
                the (tick, media) pair printed in the SAME statement: pres_tick = tick+(P-media)*1000
  release post  stamp relpost  ctx=N       the child asks the owner to drop it
  detach        stamp detach   ctx=N       the child's async teardown actually runs (§ 2.5 (a))

**(i) the null: does a new generation present about when the owner hosts it?**
  presented(N) - commit(N), and acquire(N) - commit(N) beside it.
  PASS (null upheld) = >= 90 % of generations present within one refresh (8.3 ms) of the commit.
  The fraction beyond 120 ms is reported because 120 ms is D's own cap (§ 2.4).
  ⚠ A generation that NEVER presents cannot be inside 8.3 ms of anything. Those are counted in the
  denominator and reported separately -- treating them as missing data would quietly convert the
  commonest failure into a pass.

**(ii) the decision: does the child hold the OLD context past the NEW one's first present?**
  For each succession O -> N (from `retiring superseded layer ctx O ... (replaced by N)`):
  detach(O) - presented(N), and RELEASE(O) - presented(N) beside it as the owner-side upper bound.
  D CLOSES  = detach(O) follows presented(N) in >= 95 % of successions.
  D NARROWS = below that, and the covered fraction is what D can reach.
  § 7.2, fixed before the run: **if detach precedes presented(N) in more than 5 % of successions,
  D cannot reach the tail -- return to § 2.** This script prints that verdict; it does not soften it.

⚠ Sort by TIMESTAMP, never line order (the trap layer-gap.py documents) -- several threads write
this trace and their lines interleave.
(macgameport, 2026-09-07)
"""
import os, re, sys, statistics

TS = r'^(\d+)\.(\d{3}):[0-9a-f]+:'
COMMIT = re.compile(TS + r'trace:macdrv:macdrv_WindowMessage WM_MACDRV_CREATE_REMOTE_LAYER '
                         r'child (0x[0-9a-f]+|\(nil\)) context_id (\d+)')
RETIRE = re.compile(TS + r'trace:macdrv:retire_superseded_layers retiring superseded layer '
                         r'ctx (\d+) for child (0x[0-9a-f]+) \(replaced by (\d+)\)')
RELEASE = re.compile(TS + r'trace:macdrv:macdrv_WindowMessage WM_MACDRV_RELEASE_REMOTE_LAYER '
                          r'context_id (\d+)')
# ⚠ `^err:\S*:` does NOT work here, and it fails SILENTLY -- as "no stamp lines, not a stamp
# build", which reads like a wrong module rather than a wrong regex. ERR() prefixes the message
# with `__func__`, and for an Objective-C method that is `-[WineStampMetalLayer nextDrawable]`,
# which contains a SPACE. Measured on the first live row, 2026-09-07:
#   err:-[WineStampMetalLayer nextDrawable]_block_invoke:stamp presented ctx=... tick=... pres=...
# So match up to `stamp ` non-greedily instead of assuming the prefix is one token.
STAMP = re.compile(r'^err:.*?:stamp (\w+) ctx=(\d+) tick=(\d+) media=([0-9.]+)(?: pres=([0-9.]+))?')
ANYTS = re.compile(TS)


def parse(path):
    """gens[ctx] = {commit, create, acquire, presented, relpost, detach, release, child}, all in
    wine-tick milliseconds; plus the O -> N succession list and the trace's own tick range."""
    gens, succ, lo, hi = {}, [], None, None

    def g(ctx):
        return gens.setdefault(ctx, {})

    for ln in open(path, errors='replace'):
        m = ANYTS.match(ln)
        if m:
            t = int(m.group(1)) * 1000 + int(m.group(2))
            lo = t if lo is None else min(lo, t)
            hi = t if hi is None else max(hi, t)
        m = COMMIT.match(ln)
        if m:
            e = g(m.group(4))
            e['commit'] = int(m.group(1)) * 1000 + int(m.group(2))
            e['child'] = m.group(3)
            continue
        m = RETIRE.match(ln)
        if m:
            succ.append((m.group(3), m.group(5), m.group(4)))     # (old, new, child)
            continue
        m = RELEASE.match(ln)
        if m:
            g(m.group(3))['release'] = int(m.group(1)) * 1000 + int(m.group(2))
            continue
        m = STAMP.match(ln)
        if m:
            kind, ctx, tick, media = m.group(1), m.group(2), int(m.group(3)), float(m.group(4))
            e = g(ctx)
            e[kind] = tick
            if kind == 'presented' and m.group(5):
                # both clocks sampled in one statement, so this conversion is exact per line
                e['pres_tick'] = tick + (float(m.group(5)) - media) * 1000.0
    return gens, succ, lo, hi


def pct(v, q):
    v = sorted(v)
    return v[min(len(v) - 1, int(q * len(v)))]


def describe(label, v, unit='ms'):
    if not v:
        return '  %-38s (none)' % label
    return ('  %-38s n=%-5d median %8.1f   p10 %8.1f   p90 %8.1f   min %8.1f   max %9.1f %s'
            % (label, len(v), statistics.median(v), pct(v, .10), pct(v, .90), min(v), max(v), unit))


def resolve(a):
    return a if os.path.isfile(a) else os.path.join(a, 'stdout.txt')


if __name__ == '__main__':
    args = sys.argv[1:]
    dump = '--dump' in args
    args = [a for a in args if not a.startswith('--')]
    if not args:
        sys.exit(__doc__.split('\n\n')[0])

    P_ACQ, P_PRES, P_REL, P_DET = [], [], [], []
    n_gen = n_nopres = n_nocommit = 0
    close_hits = narrow = 0
    clockbad = []

    for a in args:
        p = resolve(a)
        name = os.path.basename(a.rstrip('/'))
        if not os.path.exists(p):
            print('%-34s NO TRACE' % name); continue
        gens, succ, lo, hi = parse(p)
        stamped = [e for e in gens.values() if 'create' in e]
        if not stamped:
            print('%-34s no stamp lines -- not a stamp build' % name); continue
        out = [e['create'] for e in stamped if not (lo <= e['create'] <= hi)]
        if out:
            clockbad.append(name)
            print('%-34s ⚠ CLOCK: %d stamp ticks outside the trace range -- SKIPPED' % (name, len(out)))
            continue

        acq, pres, rel, det = [], [], [], []
        for ctx, e in gens.items():
            if 'create' not in e:
                continue
            n_gen += 1
            if 'commit' not in e:
                n_nocommit += 1
                continue
            if 'acquire' in e:
                acq.append(e['acquire'] - e['commit'])
            if 'pres_tick' in e:
                pres.append(e['pres_tick'] - e['commit'])
            else:
                n_nopres += 1
        # (ii) the succession half
        for old, new, child in succ:
            o, n = gens.get(old, {}), gens.get(new, {})
            if 'pres_tick' not in n:
                continue                      # nothing to be early or late relative to
            if 'detach' in o:
                d = o['detach'] - n['pres_tick']
                det.append(d)
                if d >= 0:
                    close_hits += 1
                else:
                    narrow += 1
            if 'release' in o:
                rel.append(o['release'] - n['pres_tick'])

        print('%s   %d generations, %d successions' % (name, len(stamped), len(succ)))
        print(describe('(i) acquire - owner commit', acq))
        print(describe('(i) PRESENT - owner commit', pres))
        print(describe('(ii) detach(old) - present(new)', det))
        print(describe('(ii) RELEASE(old) - present(new)', rel))
        P_ACQ += acq; P_PRES += pres; P_REL += rel; P_DET += det
        if dump:
            for old, new, child in succ[:40]:
                o, n = gens.get(old, {}), gens.get(new, {})
                print('    %s %s->%s  present(new) %s  detach(old) %s  release(old) %s'
                      % (child, old, new,
                         '%.1f' % n['pres_tick'] if 'pres_tick' in n else '   --   ',
                         o.get('detach', '--'), o.get('release', '--')))

    print('\n' + '=' * 110)
    if not P_PRES and not P_DET:
        sys.exit('S1a: NOTHING TO REPORT -- no stamped generation had both a commit and a present.')

    # (i)
    tot_i = len(P_PRES) + n_nopres
    within = sum(1 for x in P_PRES if abs(x) <= 8.3)
    beyond = sum(1 for x in P_PRES if abs(x) > 120)
    print(describe('POOLED (i) PRESENT - owner commit', P_PRES))
    print(describe('POOLED (i) acquire - owner commit', P_ACQ))
    print('  (i) %d of %d generations present within one refresh (8.3 ms) of the commit = %.1f %%'
          % (within, tot_i, 100.0 * within / tot_i if tot_i else 0))
    print('      %d never presented at all (%.1f %% of the denominator, counted against the null)'
          % (n_nopres, 100.0 * n_nopres / tot_i if tot_i else 0))
    print('      %d beyond 120 ms, D\'s own cap (%.1f %% of those that did present)'
          % (beyond, 100.0 * beyond / len(P_PRES) if P_PRES else 0))
    ok_i = tot_i and 100.0 * within / tot_i >= 90.0
    print('  (i) VERDICT: null %s' % ('UPHELD (>= 90 %)' if ok_i else 'NOT upheld (< 90 %)'))

    # (ii) -- the § 7.2 decision rule, stated before the run and not softened here
    print()
    print(describe('POOLED (ii) detach(old) - present(new)', P_DET))
    print(describe('POOLED (ii) RELEASE(old) - present(new)', P_REL))
    tot_ii = close_hits + narrow
    if not tot_ii:
        print('  (ii) no succession had both a detach and a present -- UNDECIDED')
        sys.exit(2)
    follows = 100.0 * close_hits / tot_ii
    print('  (ii) detach FOLLOWS present(new) in %d of %d successions = %.1f %%'
          % (close_hits, tot_ii, follows))
    print('       detach PRECEDES it in %d = %.1f %%   (§ 7.2 stops D above 5 %%)'
          % (narrow, 100.0 - follows))
    if follows >= 95.0:
        print('  (ii) VERDICT: **D CLOSES** -- the child holds the old context past the new one\'s')
        print('       first present in >= 95 % of successions. § 7.2 says: build D.')
    elif 100.0 - follows > 5.0:
        print('  (ii) VERDICT: **§ 7.2 STOP** -- detach precedes present in more than 5 % of')
        print('       successions, so D cannot reach the tail. Return to § 2; do not build D.')
    else:
        print('  (ii) VERDICT: **D NARROWS** -- covered fraction %.1f %%. Decide on the' % follows)
        print('       per-generation metric with n ~ 60/arm, per the S3 row.')
    if clockbad:
        print('\n  ⚠ %d run(s) skipped on the clock check: %s' % (len(clockbad), ', '.join(clockbad)))
