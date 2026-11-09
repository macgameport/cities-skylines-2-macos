#!/usr/bin/env python3
"""p4-signals.py — read perf-pass P4's load signals out of one graceful-exit Player.log.

    python3 scripts/p4-signals.py <Player.log> [--expect control|bucket|workers=N] [--default-workers 17]

Prints one JSON line and exits 0 (report complete, expectation met), 2 (report missing or truncated —
the cycle is VOID: a SIGTERM'd game writes no allocator report), or 3 (report complete, expectation
NOT met — on a lever cycle the key was not applied; on a control cycle a key leaked in).

Every signal is read SECTION-SCOPED (perf-pass §3D, pass 3). The field names are exact but not unique:
`Overflow Count` / `Initial Block Size` appear in every temp-allocator section, `Used Block Count` (capital
C) also appears under the job allocators, the shared bucket allocator is printed in four identical
`[ALLOC_BUCKET]` sections, and `[ALLOC_TEMP_Background Job.Worker N]` sits beside `[ALLOC_TEMP_Job.Worker N]`.
So: workers = the highest header matching exactly `[ALLOC_TEMP_Job.Worker N]`; bucket = the FIRST
`[ALLOC_BUCKET]` section only; per frame = that section's Failed-count sum / the total of
`[ALLOC_TEMP_MAIN]`'s `Peak usage frame count` histogram (process frames, not results.jsonl
framesRendered). Measured defaults on the Mac Studio, 29 graceful logs: workers 0..16, bucket Used
Block count 1, temp main Initial 4.0 MB / Overflow 9036 (EXPERIMENTS C79).
"""
import json
import re
import sys

HEADER = re.compile(r'^\s*\[(ALLOC_[^\]]+)\]\s*$')
WORKER = re.compile(r'^ALLOC_TEMP_Job\.Worker (\d+)$')


def sections(text):
    """[(name, body_lines)] for every allocator section after 'Memory Statistics:'."""
    start = text.find('Memory Statistics:')
    if start < 0:
        return None
    out, name, body = [], None, []
    for line in text[start:].splitlines()[1:]:
        m = HEADER.match(line)
        if m:
            if name is not None:
                out.append((name, body))
            name, body = m.group(1), []
        elif name is not None:
            body.append(line)
    if name is not None:
        out.append((name, body))
    return out


def field(body, label):
    for line in body:
        s = line.strip()
        if s.startswith(label + ' '):
            return s[len(label) + 1:]
    return None


def read(path):
    text = open(path, encoding='utf-8', errors='replace').read()
    r = {'log': path.rsplit('/', 1)[-1], 'graceful': 'Game terminated successfully' in text
         and 'Memory Statistics:' in text}
    secs = sections(text)
    if not secs:
        r['report'] = 'MISSING'
        return r
    workers = [int(m.group(1)) for n, _ in secs for m in [WORKER.match(n)] if m]
    main = next((b for n, b in secs if n == 'ALLOC_TEMP_MAIN'), None)
    buckets = [b for n, b in secs if n == 'ALLOC_BUCKET']
    missing = [k for k, v in (('Job.Worker', workers), ('ALLOC_TEMP_MAIN', main),
                              ('ALLOC_BUCKET', buckets)) if not v]
    if missing:
        r['report'] = 'TRUNCATED: no ' + ', '.join(missing)
        return r
    r['report'] = 'complete'
    r['job_worker_max'] = max(workers)
    r['job_workers'] = len(set(workers))
    hist = field(main, 'Peak usage frame count:') or ''
    frames = sum(int(x) for x in re.findall(r'(\d+) frames', hist))
    ovf = field(main, 'Overflow Count')
    r['temp_main'] = {'initial': field(main, 'Initial Block Size'),
                      'current': field(main, 'Current Block Size'),
                      'overflow': int(ovf) if ovf and ovf.isdigit() else None}
    first = buckets[0]
    ub = field(first, 'Used Block count')
    failed = sum(int(x) for x in re.findall(r'Failed count: (\d+)', '\n'.join(first)))
    r['bucket'] = {'sections': len(buckets), 'identical': all(b == first for b in buckets),
                   'used_blocks': int(ub) if ub and ub.isdigit() else None,
                   'block_size': field(first, 'Large Block size'), 'failed_sum': failed}
    r['process_frames'] = frames
    r['failed_per_frame'] = round(failed / frames, 1) if frames else None
    return r


def check(r, expect, default_workers):
    """None if the expectation holds, else the reason it does not."""
    dflt_max = default_workers - 1
    if expect == 'control':
        bad = []
        if r['job_worker_max'] != dflt_max:
            bad.append('job_worker_max %s != default %d' % (r['job_worker_max'], dflt_max))
        if r['bucket']['used_blocks'] != 1:
            bad.append('bucket used_blocks %s != default 1' % r['bucket']['used_blocks'])
        return '; '.join(bad) or None
    if expect == 'bucket':
        u = r['bucket']['used_blocks']
        return None if u is not None and u > 1 else 'bucket used_blocks %s — key not applied' % u
    m = re.fullmatch(r'workers=(\d+)', expect)
    if m:
        want = int(m.group(1)) - 1
        got = r['job_worker_max']
        return None if got == want else 'job_worker_max %s != %d — key not applied' % (got, want)
    raise SystemExit('unknown --expect %r' % expect)


def main(argv):
    args, expect, default_workers = [], None, 17
    it = iter(argv)
    for a in it:
        if a == '--expect':
            expect = next(it)
        elif a == '--default-workers':
            default_workers = int(next(it))
        else:
            args.append(a)
    if len(args) != 1:
        raise SystemExit(__doc__)
    r = read(args[0])
    if r.get('report') != 'complete':
        print(json.dumps(r))
        return 2
    if expect:
        why = check(r, expect, default_workers)
        r['expect'] = expect
        r['expect_ok'] = why is None
        if why:
            r['expect_fail'] = why
    print(json.dumps(r))
    return 3 if expect and not r['expect_ok'] else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
