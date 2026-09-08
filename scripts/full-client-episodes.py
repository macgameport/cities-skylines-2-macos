#!/usr/bin/env python3
"""full-client-episodes.py -- count FULL-CLIENT diagnostic episodes in a video battery's runs.

    python3 scripts/full-client-episodes.py <rundir|batterydir> ...
    python3 scripts/full-client-episodes.py --min 0 --baseline 0.333 <batterydir>   # S3's gate

WHY THIS EXISTS, and it is the third instance of one bug. The battery's own tally counts an episode
at `fraction > 0` for every colour but black (`video-gap-battery.sh`). That is sound for a colour
the page cannot contain and unsound the moment it can -- and C64 read 542 cyan episodes against 543
across two builds that differ exactly in the surface under test, called the page contaminated, and
voided the run. Re-scored here, C64's own recordings say something different: the median cyan frame
among those 542 carries **one pixel**, at (30,479), in nearly every frame of every run. The episodes
were a stray pixel. Nothing about the page was ever measured.

So the discriminator is SIZE, not presence -- and the size that matters is the one the defect has:
S3 exposes the WHOLE CLIENT (C56 measured Tblue=100 % of the top band; C58's episodes covered
13-53 % of the recorded frame). Two other phenomena live in the same recordings and neither is
full-client:

  * the C61 growing-edge column -- 1 to 4 drag steps wide, full window height. Measured here at
    16,171 px = 2.2 % of the window, with 26 distinct columns of a 1005 px bounding box, so a
    BOUNDING BOX test would pass it and a pixel-count test does not. This is why the gate counts
    PIXELS and not the bbox.
  * the C57/C60 stall -- the host failing to track a growing window. Sustained (28-36 consecutive
    frames), growing monotonically, and it plateaus at 51-60 % of the window.

THE GATE, declared before the run it decides (S3): a frame is FULL-CLIENT for colour X when X
covers at least BAR x the window's INITIAL area (`video-rect.txt`'s `window=WxH`, which is the
pre-drag size and therefore a size the client never falls below). Default BAR = 0.80.

BAR is not tuned. Swept over C64's two arms (24 runs, ~24,000 frames) the counts are FLAT from 0.65
to 0.92 -- arm A cyan 2 / blue 0 / black 0, arm B cyan 0 / blue 4 / black 0 at every bar in that
range. Below 0.65 the C57 stall bleeds in; at 1.00 the bar exceeds the initial area and starts
dropping flashes that happened early in a drag, before the window grew. 0.80 is the middle of the
plateau. Re-run `--sweep` on any new battery before trusting a number from it.

⚠ Isolation is REPORTED, never REQUIRED. Every episode measured so far is one frame (C58, and all
six here), so an isolated-spike filter would reproduce today's counts exactly -- and would silently
miss a multi-frame episode, which is the one result a CLOSURE test must not miss. Consecutive
full-client frames are grouped into one episode and the frame count is printed.

Exit code: 0, or 1 if `--min N` is given and any colour's episode count exceeds N.
(macgameport, 2026-09-08)
"""
import sys, os, re, glob, math

BAR = 0.80
COLOURS = ('blue', 'green', 'magenta', 'cyan', 'black')


def runs_under(p):
    """A run dir (has frames/video-frames.txt), or a battery dir of them."""
    if os.path.exists(os.path.join(p, 'frames', 'video-frames.txt')):
        return [p]
    return sorted(glob.glob(os.path.join(p, '*', 'frames', 'video-frames.txt')) and
                  [os.path.dirname(os.path.dirname(f))
                   for f in glob.glob(os.path.join(p, '*', 'frames', 'video-frames.txt'))])


def read_run(d, bar):
    """-> (label, window_area, {colour: [(first_frame, nframes, ms, peak_frac)]}) or (label, None, why)."""
    label = os.path.basename(d)
    fp = os.path.join(d, 'frames', 'video-frames.txt')
    rp = os.path.join(d, 'frames', 'video-rect.txt')
    sp = os.path.join(d, 'frames', 'capture-state.txt')
    if not os.path.exists(fp):
        return label, None, 'no video-frames.txt'
    if not os.path.exists(rp):
        return label, None, 'no video-rect.txt -- window size unknown, so no full-client bar exists'
    m = re.search(r'window=(\d+)x(\d+)', open(rp).read())
    if not m:
        return label, None, 'video-rect.txt carries no window=WxH'
    area = int(m.group(1)) * int(m.group(2))
    # Same guard the battery uses: a window in front of Steam lands in the recording.
    if os.path.exists(sp):
        o = re.search(r'overlaps=(\S+)', open(sp).read())
        if o and o.group(1) != '0/0':
            return label, None, 'overlaps=%s' % o.group(1)
    frames = []
    for ln in open(fp):
        fm = re.match(r'f(\d+) t=([0-9.]+) ', ln)
        if not fm:
            continue
        px = {c: int(k.group(1)) for c in COLOURS
              for k in [re.search(r'\b%spx=(\d+)' % c, ln)] if k}
        frames.append((int(fm.group(1)), float(fm.group(2)), px))
    if len(frames) < 2:
        return label, None, 'fewer than 2 scored frames'
    eps = {}
    for c in COLOURS:
        hits = [i for i, (_, _, px) in enumerate(frames) if px.get(c, 0) >= bar * area]
        if not hits:
            continue
        groups, cur = [], [hits[0]]
        for i in hits[1:]:
            if i == cur[-1] + 1:
                cur.append(i)
            else:
                groups.append(cur)
                cur = [i]
        groups.append(cur)
        for g in groups:
            end = frames[g[-1] + 1][1] if g[-1] + 1 < len(frames) else frames[g[-1]][1]
            peak = max(frames[i][2].get(c, 0) for i in g) / area
            eps.setdefault(c, []).append((frames[g[0]][0], len(g), (end - frames[g[0]][1]) * 1000, peak))
    return label, area, eps


def poisson_p0(rate, n):
    """P(observing 0 events in n runs | Poisson rate per run) -- the plan's exact closure bar."""
    return math.exp(-rate * n)


def main():
    a = sys.argv[1:]
    bar, minimum, baseline, sweep = BAR, None, None, False
    paths = []
    i = 0
    while i < len(a):
        if a[i] == '--bar':
            bar = float(a[i + 1]); i += 2
        elif a[i] == '--min':
            minimum = int(a[i + 1]); i += 2
        elif a[i] == '--baseline':
            baseline = float(a[i + 1]); i += 2
        elif a[i] == '--sweep':
            sweep = True; i += 1
        elif a[i].startswith('--'):
            sys.exit('unknown option %s' % a[i])
        else:
            paths.append(a[i]); i += 1
    if not paths:
        sys.exit(__doc__.strip().splitlines()[0])

    dirs = []
    for p in paths:
        dirs += runs_under(p)
    if not dirs:
        sys.exit('REFUSED: no run directories with frames/video-frames.txt under %s' % ', '.join(paths))

    if sweep:
        print('  bar x initial window area | ' + ' '.join('%8s' % c for c in COLOURS))
        for bf in (0.50, 0.65, 0.75, 0.80, 0.85, 0.90, 1.00):
            tot = {}
            for d in dirs:
                _, area, eps = read_run(d, bf)
                if area is None:
                    continue
                for c, v in eps.items():
                    tot[c] = tot.get(c, 0) + len(v)
            print('           %.2f             | ' % bf + ' '.join('%8d' % tot.get(c, 0) for c in COLOURS))
        print('  -> a number is only worth reading off a bar that sits on a FLAT stretch of this table.')

    print('  full-client bar: a colour covering >= %.2f x the window\'s initial area '
          '(episodes = consecutive such frames)' % bar)
    tot, hitruns, valid, void = {}, {}, 0, []
    for d in sorted(dirs):
        label, area, eps = read_run(d, bar)
        if area is None:
            void.append('%s (%s)' % (label, eps)); continue
        valid += 1
        if eps:
            for c, v in sorted(eps.items()):
                tot[c] = tot.get(c, 0) + len(v)
                hitruns.setdefault(c, set()).add(label)
                print('   %-44s %-8s %s' % (label, c, '  '.join(
                    'f%d x%d frames %.0f ms peak %.0f%% of window'
                    % (e[0], e[1], e[2], 100 * e[3]) for e in v)))
    print('  %d valid runs%s' % (valid, (', %d VOID: %s' % (len(void), '; '.join(void))) if void else ''))
    # A battery whose rows ALL voided has zero episodes of every colour, and a `--min 0` gate on it
    # would report GREEN off no evidence at all -- the same shape as the lock-screen recording that
    # scored as a flawless run (video-gap-battery.sh's refusal). Refuse instead of passing.
    if valid == 0:
        print('  REFUSED: no valid run survived the guards, so there is nothing to score.')
        return 2
    for c in COLOURS:
        if tot.get(c):
            print('  %-8s %d full-client episodes in %d of %d runs (%.2f per run)'
                  % (c, tot[c], len(hitruns[c]), valid, tot[c] / valid))
        else:
            print('  %-8s no full-client episodes in %d runs' % (c, valid))
    if baseline is not None:
        n = tot.get('cyan', 0) + tot.get('blue', 0) + tot.get('black', 0)
        p = poisson_p0(baseline, valid)
        print('  closure test vs a baseline of %.3f episodes/run over %d runs: expected %.1f, '
              'observed %d (cyan+blue+black); exact Poisson P(0) = %.4f'
              % (baseline, valid, baseline * valid, n, p))
        if n == 0:
            print('  -> 0 observed, p = %.4f %s the plan\'s 0.007 bar'
                  % (p, 'MEETS' if p <= 0.007 else 'DOES NOT MEET'))
    if minimum is not None:
        over = {c: v for c, v in tot.items() if v > minimum}
        if over:
            print('  GATE RED: %s exceed --min %d' % (', '.join('%s=%d' % kv for kv in sorted(over.items())), minimum))
            return 1
        print('  GATE GREEN: no colour exceeds --min %d' % minimum)
    return 0


sys.exit(main())
