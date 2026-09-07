#!/usr/bin/env python3
"""live-hosts.py -- replay the owner's hosted-layer dictionary from a run's trace.

Answers one question, the one the S3 plan's S7 rests on: **how many hosted layers is the owner
holding for a single child at once, and for how long?** Candidate D deliberately holds a child's
previous generation past the point today's code discards it, so "max live hosts per child <= 2
throughout" is D's bound and a leak is what happens when an exit is missed. That bound is not
readable from the code -- it is a run-time property of four exits interacting -- so it gets an
instrument rather than an argument.

WHAT IT REPLAYS. `data->remote_layer_children` is a CAContextID -> child HWND dictionary
(`window.c:1758`). Exactly three sites change it, and all three TRACE:

    :1717  WM_MACDRV_CREATE_REMOTE_LAYER child %p context_id %u    -> add ctx, mapped to child
    :964   retiring superseded layer ctx %u for child %p (...)     -> remove ctx
    :1770  WM_MACDRV_RELEASE_REMOTE_LAYER context_id %u           -> remove ctx IF STILL TRACKED

⚠ **RELEASE is not a decrement.** The handler skips an untracked id on purpose ("an untracked id is
one retire_superseded_layers() already took"), and in practice that is nearly all of them: §2.5
measured RELEASE arriving after its own retire in 271 of 271 generations. A script that subtracted
one per RELEASE line would run the count deeply negative and report a healthy system. So this
replays the dictionary -- add, remove-if-present -- rather than counting events.

⚠ **MAX ALONE CANNOT SEPARATE D FROM THE BASELINE, and that is why duration is reported.** Today's
code already reaches 2 momentarily: the CREATE handler adds the replacement and only then retires
its predecessor, so between those two lines the child has two hosts. On the baseline that lasts
microseconds; under D it lasts until an exit fires. The pass criterion therefore has to be read off
the DWELL columns -- "time spent at >= 2" -- not off the max, which is 2 on a clean baseline and 2
on a correct D. The max column is still what catches a missed exit (the --norelease mutant grows it
monotonically).

⚠ **Sort by TIMESTAMP, never by line order** (the trap `layer-gap.py` documents): the trace is
written by several threads and their lines interleave without being globally ordered. Needs
WINEDEBUG=+timestamp; without it the script says so and falls back to line order, which is right
only while all three sites stay on one thread (measured: 856 of 856 on thread 0130, 2026-09-06).

Usage:  live-hosts.py <run-dir-or-stdout.txt> [...]   one block per run, plus a pooled verdict
        live-hosts.py --dump <run>                    every transition, for eyeballing
        live-hosts.py --max 2 <run> [...]             exit 1 if any child ever exceeds N
(macgameport, 2026-09-07)
"""
import os, re, sys

TS = r'^(?:(\d+\.\d+):)?([0-9a-f]+):trace:macdrv:'
CREATE = re.compile(TS + r'macdrv_WindowMessage WM_MACDRV_CREATE_REMOTE_LAYER '
                         r'child (0x[0-9a-f]+|\(nil\)) context_id (\d+)')
RETIRE = re.compile(TS + r'retire_superseded_layers retiring superseded layer ctx (\d+) '
                         r'for child (0x[0-9a-f]+) \(replaced by (\d+)\)')
RELEASE = re.compile(TS + r'macdrv_WindowMessage WM_MACDRV_RELEASE_REMOTE_LAYER context_id (\d+)')


def events(path):
    """(time_or_None, kind, ctx, child) in trace order, then stably sorted by time."""
    out, untimed = [], 0
    for line in open(path, errors='replace'):
        for rx, kind in ((CREATE, 'create'), (RETIRE, 'retire'), (RELEASE, 'release')):
            m = rx.match(line)
            if not m:
                continue
            t = float(m.group(1)) if m.group(1) else None
            if t is None:
                untimed += 1
            if kind == 'create':
                out.append((t, kind, m.group(4), m.group(3)))
            elif kind == 'retire':
                out.append((t, kind, m.group(3), m.group(4)))
            else:
                out.append((t, kind, m.group(3), None))
            break
    # stable sort keeps same-millisecond events in the order the trace wrote them, which within one
    # thread is the order they happened -- exactly what the CREATE-then-retire pair needs.
    if untimed == 0 and out:
        out.sort(key=lambda e: e[0])
    return out, untimed


def replay(path):
    """Replay the dictionary. Returns per-child stats and the transition log."""
    ev, untimed = events(path)
    tracked = {}                      # ctx -> child, the owner's dictionary
    stats, log = {}, []
    released = set()
    retired = set()

    def st(child):
        return stats.setdefault(child, dict(create=0, retire=0, release=0, live=0, mx=0,
                                            mx_t=None, dwell={}, last_t=None))

    def bump(child, t):
        """Accrue the time the child spent at its CURRENT count, then move on."""
        s = st(child)
        if s['last_t'] is not None and t is not None:
            s['dwell'][s['live']] = s['dwell'].get(s['live'], 0.0) + (t - s['last_t'])
        s['last_t'] = t

    for t, kind, ctx, child in ev:
        if kind == 'create':
            bump(child, t)
            s = st(child)
            s['create'] += 1
            if ctx not in tracked:
                tracked[ctx] = child
                s['live'] += 1
                if s['live'] > s['mx']:
                    s['mx'], s['mx_t'] = s['live'], t
        elif kind == 'retire':
            retired.add(ctx)
            if ctx in tracked:
                owner = tracked.pop(ctx)
                bump(owner, t)
                st(owner)['live'] -= 1
            st(child)['retire'] += 1
        else:                                       # release
            released.add(ctx)
            if ctx in tracked:                      # the handler's own guard
                owner = tracked.pop(ctx)
                bump(owner, t)
                st(owner)['live'] -= 1
                st(owner)['release'] += 1
            child = None
        log.append((t, kind, ctx, child, len(tracked)))
    return stats, log, untimed, retired, released, tracked


def resolve(a):
    return a if os.path.isfile(a) else os.path.join(a, 'stdout.txt')


if __name__ == '__main__':
    args = sys.argv[1:]
    dump = '--dump' in args
    args = [a for a in args if a != '--dump']
    cap = None
    if '--max' in args:
        i = args.index('--max')
        cap = int(args[i + 1]); del args[i:i + 2]
    worst, bad = 0, []
    for a in args:
        p = resolve(a)
        name = os.path.basename(a.rstrip('/'))
        if not os.path.exists(p):
            print('%-34s NO TRACE' % name); continue
        stats, log, untimed, retired, released, left = replay(p)
        if not stats:
            print('%-34s no remote-layer events' % name); continue
        print('%s%s' % (name, '   ⚠ NO TIMESTAMPS (+timestamp absent) -- line order, dwell omitted'
                              if untimed else ''))
        for child, s in sorted(stats.items(), key=lambda kv: -kv[1]['mx']):
            over = sum(v for k, v in s['dwell'].items() if k >= 2)
            tot = sum(s['dwell'].values())
            print('  child %-10s creates %4d  retires %4d  releases-that-freed %4d   '
                  'MAX LIVE %2d   at rest %d   dwell>=2 %6.2f s of %6.2f s (%4.1f%%)'
                  % (child, s['create'], s['retire'], s['release'], s['mx'], s['live'],
                     over, tot, 100.0 * over / tot if tot else 0.0))
            worst = max(worst, s['mx'])
            if cap is not None and s['mx'] > cap:
                bad.append('%s child %s max %d' % (name, child, s['mx']))
        # §2.5's leak column: a predecessor the child retired but never released.
        print('  retired %d · released %d · retired-but-never-released %d · still tracked at end %d'
              % (len(retired), len(released), len(retired - released), len(left)))
        if dump:
            for t, kind, ctx, child, n in log:
                print('    %s %-7s ctx %-11s %-10s tracked=%d'
                      % ('%.3f' % t if t is not None else '  --  ', kind, ctx, child or '', n))
    if cap is not None:
        if bad:
            print('FAIL: max live hosts per child exceeded %d -- %s' % (cap, '; '.join(bad)))
            sys.exit(1)
        print('PASS: no child exceeded %d live hosts (worst seen %d)' % (cap, worst))
