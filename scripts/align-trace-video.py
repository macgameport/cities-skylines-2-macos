#!/usr/bin/env python3
"""align-trace-video.py -- put a screen recording and a wine trace on one timeline.

Nothing aligns them today. `drag-session.sh` records a `rec.mov` and a `stdout.txt` in the same run
directory and names only wall-clock between them (`:87`); `win-resize-driver.exe` prints no
timestamps at all. So "the black frame at video t=12.4 s" and "the CREATE at tick 200226.121" have
never been comparable, and the S3 plan's S1b -- score video per VISIBLE episode, then read what the
trace was doing during it -- cannot be run without this.

    align-trace-video.py <run-dir> [--anchor-colour magenta] [--episodes blue] [--dump]
    align-trace-video.py --check-clock <run-dir> [...]     # the S1a stamp gate, trace only

────────────────────────────────────────────────────────────────────────────────────────────────
HOW THE ANCHOR WORKS, AND WHAT IT IS WORTH.

Two clocks, no shared origin: video PTS starts at 0 when `screencapture -v` began, wine ticks are
`NtGetTickCount()` milliseconds off a wineserver-mapped section. One event visible on both sides
fixes the offset, and this uses the one the S3 plan names -- **the first edge motion** of the drag:

  * video side: the first frame carrying the anchor colour. Default MAGENTA, C59's one-device-pixel
    seam at the window's right edge, which appears when that edge first moves.
  * trace side: the first `macdrv_SysCommand ..., f002,` -- win32u's size loop starting on the right
    edge (`defwnd.c:781`), i.e. the same instant, from the other side.

⚠ **This is a ONE-POINT anchor and it is worth about one video frame.** It assumes the two events
are simultaneous; they are not exactly -- the SysCommand precedes the first pixel moving by however
long the resize takes to reach the display. The residual is reported as `anchor uncertainty` and is
the number to quote beside any conclusion drawn through this mapping. It is fine for "which trace
events were in flight during this episode" (episodes last tens of ms and the trace is dense) and it
is NOT fine for sub-frame claims about ordering. If you need ordering, use the S1a stamps, which
put both sides on the wine clock directly and need no anchor at all.

⚠ **Drift is not corrected and is not measured.** The two clocks are independent; over a 35 s drag
a 0.1 % difference is 35 ms. `--anchor-late` re-anchors on the LAST f002 instead of the first, and
a large disagreement between the two offsets is drift showing itself -- the script prints both.

────────────────────────────────────────────────────────────────────────────────────────────────
--check-clock IS A GATE, NOT A REPORT, and it is the one the stamp build depends on.

`first-drawable-stamp-patch.py` prints its own tick, because the Cocoa side's ERR() bypasses wine's
`+timestamp` entirely (`cocoa_app.m:2402-2412`, a raw fprintf). That tick comes from a hand-written
`__attribute__((ms_abi))` declaration of NtGetTickCount, and a wrong ABI there would NOT fail the
build -- it would print a plausible-looking wrong number. So before any S1a number is read, this
checks that the stamps' ticks actually fall inside the range of the trace's own `+timestamp`
values. Exit 1 if they do not. A `tick=0`, or ticks nowhere near the trace's, is the declaration
going wrong and not the compositor.
(macgameport, 2026-09-07)
"""
import os, re, sys

TSLINE = re.compile(r'^(\d+)\.(\d{3}):[0-9a-f]+:')
STAMP = re.compile(r'^err:\S*:?stamp (\w+) ctx=(\d+) tick=(\d+) media=([0-9.]+)(?: pres=([0-9.]+))?')
F002 = re.compile(r'macdrv_SysCommand .*, f002, ')
FRAME = re.compile(r'^f(\d+) t=([0-9.]+) (\d+)x(\d+) (.*)$')
COLOUR = re.compile(r'(\w+)=([0-9.]+)')
# the trace events worth showing beside an episode: the hosted-layer lifecycle, nothing else
INTERESTING = re.compile(r'WM_MACDRV_CREATE_REMOTE_LAYER|WM_MACDRV_RELEASE_REMOTE_LAYER|'
                         r'retiring superseded layer|update_remote_layer_frame_for|stamp ')


def resolve(a):
    return a if os.path.isfile(a) else os.path.join(a, 'stdout.txt')


def trace_ticks(path):
    """Every timestamped line as (tick_ms, text), plus the stamp lines parsed out."""
    lines, stamps = [], []
    for ln in open(path, errors='replace'):
        m = TSLINE.match(ln)
        if m:
            lines.append((int(m.group(1)) * 1000 + int(m.group(2)), ln.rstrip('\n')))
        m = STAMP.match(ln)
        if m:
            stamps.append(dict(kind=m.group(1), ctx=m.group(2), tick=int(m.group(3)),
                               media=float(m.group(4)),
                               pres=float(m.group(5)) if m.group(5) else None))
    return lines, stamps


def frames(path):
    """(index, pts_seconds, {colour: percent}) per scored video frame."""
    out = []
    if not os.path.exists(path):
        return out
    for ln in open(path, errors='replace'):
        m = FRAME.match(ln)
        if m:
            out.append((int(m.group(1)), float(m.group(2)),
                        {k: float(v) for k, v in COLOUR.findall(m.group(5))}))
    return out


def check_clock(run):
    """The S1a gate. Returns True if the stamps' ticks sit inside the trace's own tick range."""
    p = resolve(run)
    name = os.path.basename(run.rstrip('/'))
    if not os.path.exists(p):
        print('%-34s NO TRACE' % name); return False
    lines, stamps = trace_ticks(p)
    if not lines:
        print('%-34s NO TIMESTAMPED TRACE LINES -- run with WINEDEBUG=+timestamp' % name)
        return False
    if not stamps:
        print('%-34s no stamp lines -- not a stamp build, nothing to check' % name)
        return True
    lo, hi = lines[0][0], lines[-1][0]
    ticks = [s['tick'] for s in stamps]
    out = [t for t in ticks if not (lo <= t <= hi)]
    print('%s\n  trace ticks %d..%d ms · %d stamps, ticks %d..%d ms'
          % (name, lo, hi, len(stamps), min(ticks), max(ticks)))
    if out:
        print('  FAIL: %d of %d stamp ticks fall OUTSIDE the trace\'s own range (e.g. %s).'
              % (len(out), len(ticks), ', '.join(str(x) for x in out[:5])))
        print('  That is the ms_abi NtGetTickCount declaration in first-drawable-stamp-patch.py,')
        print('  not the compositor. Do not read S1a numbers from this run.')
        return False
    kinds = {}
    for s in stamps:
        kinds[s['kind']] = kinds.get(s['kind'], 0) + 1
    print('  PASS: every stamp tick is inside the trace\'s range · %s'
          % ' · '.join('%s %d' % kv for kv in sorted(kinds.items())))
    return True


def anchor(run, colour, minpct, early_off=None):
    """(offset_ms, uncertainty_ms, note) mapping video PTS seconds -> wine tick ms.

    Pass `early_off` to RE-anchor on the last right-edge press instead of the first; the drift
    between the two offsets is the only estimate of clock drift this instrument can make.

    ⚠ The late anchor pairs like with like on purpose. The obvious version -- last f002 against the
    LAST frame carrying the colour -- compares two different events: the drag's final segment is a
    TOP-edge press (f003), so the last coloured frame sits after the last f002 by however long that
    segment lasts, and the "drift" it reports is really the top drag's duration. Instead the early
    offset is used to predict where the last f002 lands in video time, and the anchor is the first
    coloured frame at or after it -- the first visible motion of the LAST right-edge segment, which
    is the same kind of event as the early anchor's first visible motion of the first one.
    """
    lines, _ = trace_ticks(resolve(run))
    f002 = [t for t, ln in lines if F002.search(ln)]
    fr = frames(os.path.join(run, 'frames', 'video-frames.txt'))
    if not f002:
        return None, None, 'no `SysCommand ..., f002,` in the trace -- was +macdrv on?'
    if not fr:
        return None, None, 'no frames/video-frames.txt -- score the recording first'
    hits = [f for f in fr if f[2].get(colour, 0.0) > minpct]
    if not hits:
        return None, None, ('no video frame carries %s > %g%% -- pick another --anchor-colour, or '
                            'this is a prod build with no colour to anchor on' % (colour, minpct))
    # frame interval bounds how well one frame can locate an instant
    ivals = sorted((fr[i + 1][1] - fr[i][1]) for i in range(len(fr) - 1))
    unc = ivals[len(ivals) // 2] * 1000.0 if ivals else 0.0
    if early_off is None:
        first, tick = hits[0], f002[0]
    else:
        tick = f002[-1]
        want = (tick - early_off) / 1000.0
        after = [f for f in hits if f[1] >= want - unc / 1000.0]
        if not after:
            return None, unc, ('the last f002 (tick %d) predicts video t=%.3f s, past every %s '
                               'frame -- cannot re-anchor, so drift is unmeasured' % (tick, want, colour))
        first = after[0]
    return tick - first[1] * 1000.0, unc, 'f%d @ %.4f s  <->  tick %d' % (first[0], first[1], tick)


if __name__ == '__main__':
    args = sys.argv[1:]
    if '--check-clock' in args:
        runs = [a for a in args if a != '--check-clock']
        sys.exit(0 if all([check_clock(r) for r in runs]) else 1)

    def opt(name, default):
        if name in args:
            i = args.index(name); v = args[i + 1]; del args[i:i + 2]; return v
        return default

    colour = opt('--anchor-colour', 'magenta')
    episodes = opt('--episodes', 'blue')
    minpct = float(opt('--anchor-min', '0'))
    dump = '--dump' in args
    args = [a for a in args if not a.startswith('--')]
    if not args:
        sys.exit(__doc__.split('\n\n')[0])

    for run in args:
        run = run.rstrip('/')
        name = os.path.basename(run)
        off, unc, note = anchor(run, colour, minpct)
        if off is None:
            print('%-34s CANNOT ANCHOR: %s' % (name, note)); continue
        late, _, lnote = anchor(run, colour, minpct, early_off=off)
        print('%s\n  anchor (%s / first f002): %s' % (name, colour, note))
        print('  offset  tick = pts*1000 + %.1f ms   ·   anchor uncertainty +-%.1f ms (one frame)'
              % (off, unc))
        if late is None:
            print('  re-anchor on the last f002: %s' % lnote)
        else:
            print('  re-anchored on the last f002 (%s): drift %+.1f ms over the run%s'
                  % (lnote, late - off,
                     '   ⚠ larger than one frame -- treat every mapped time as +-%.0f ms'
                     % max(unc, abs(late - off)) if abs(late - off) > unc else ''))

        fr = frames(os.path.join(run, 'frames', 'video-frames.txt'))
        lines, _ = trace_ticks(resolve(run))
        hits = [i for i, f in enumerate(fr) if f[2].get(episodes, 0.0) > 0]
        if not hits:
            print('  no %s episodes to align' % episodes); continue
        runs_, cur = [], [hits[0]]
        for i in hits[1:]:
            if i == cur[-1] + 1:
                cur.append(i)
            else:
                runs_.append(cur)
                cur = [i]
        runs_.append(cur)
        print('  %d %s episode(s):' % (len(runs_), episodes))
        for g in runs_:
            t0, t1 = fr[g[0]][1], fr[g[-1]][1]
            k0, k1 = t0 * 1000 + off, t1 * 1000 + off
            print('    f%d..f%d  %.4f..%.4f s (%.0f ms)  ->  tick %.0f..%.0f  peak %s=%.2f%%'
                  % (fr[g[0]][0], fr[g[-1]][0], t0, t1, (t1 - t0) * 1000, k0, k1,
                     episodes, max(fr[i][2].get(episodes, 0.0) for i in g)))
            if dump:
                for t, ln in lines:
                    if k0 - unc <= t <= k1 + unc and INTERESTING.search(ln):
                        print('        %s' % ln[:150])
