#!/usr/bin/env python3
"""strip-comments.py — compare two revisions of a C/ObjC file for CODE equality, ignoring
comments and whitespace.

    python3 scripts/strip-comments.py <before> <after>

Exit 0 and "CODE IDENTICAL" when the two differ only in comments and whitespace; exit 1 with a
unified diff of the stripped text otherwise.

WHY BOTH GATES. The upstream-form plan plans its comment passes to be behaviour-neutral and
verifies that by rebuilding. Rebuilding alone is not enough in either direction:

  - a byte-identical object proves no CODEGEN changed, but a deleted no-op statement can also be
    byte-identical, so it does not prove the code text is untouched -- this script does;
  - and byte-identity is not even available for every file. macOS `assert()` expands to
    `__assert_rtn(__func__, __FILE__, __LINE__, ...)`, so removing a comment line above an assert
    shifts a line-number immediate in the object (measured 2026-09-03 on window.c: five bytes,
    0x30 -> 0x10). There, this script is the primary gate and the object comparison needs
    -DNDEBUG. See GOTCHAS.md and docs/plans/winemac-reference-upstream-form.md § 2.
"""
import sys, re

def strip(src: str) -> str:
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == '"' or c == "'":                      # string / char literal: copy verbatim
            q = c; out.append(c); i += 1
            while i < n:
                if src[i] == '\\': out.append(src[i:i+2]); i += 2; continue
                out.append(src[i]); i += 1
                if src[i-1] == q: break
            continue
        if src.startswith('/*', i):                   # block comment
            j = src.find('*/', i + 2); i = n if j < 0 else j + 2; out.append(' '); continue
        if src.startswith('//', i):                   # line comment
            j = src.find('\n', i); i = n if j < 0 else j; out.append(' '); continue
        out.append(c); i += 1
    text = ''.join(out)
    lines = [re.sub(r'[ \t]+', ' ', ln).strip() for ln in text.split('\n')]
    return '\n'.join(ln for ln in lines if ln)

if __name__ == '__main__':
    a, b = (strip(open(p, encoding='utf-8', errors='replace').read()) for p in sys.argv[1:3])
    if a == b:
        print('CODE IDENTICAL (comments and whitespace ignored)')
    else:
        import difflib
        d = list(difflib.unified_diff(a.split('\n'), b.split('\n'), 'before', 'after', lineterm='', n=1))
        print('CODE DIFFERS — %d diff lines' % len(d))
        print('\n'.join(d[:40]))
        sys.exit(1)
