#!/usr/bin/env python3
"""candidate-a-patch.py -- candidate A of the S3 plan: the child's layer gets no black background.

    bash scripts/build-winemac.sh <out.so> scripts/candidate-a-patch.py --drop --colours --noblue --cyan
    (or directly: python3 scripts/candidate-a-patch.py <cocoa_window.m> --drop [--colours [...]])

⚠ `main` only, cocoa_window.m only -- same constraints as `diag-colours-patch.py`, read its header.

⚠ **This is CANDIDATE code, not an instrument.** A build carrying it changes what the user sees and
must not be installed as a daily driver until S3/S6/S7 say so (§ 8: the rollback is reinstalling
stage 1 `2a251a4b2510fb84`).

WHAT A IS. `CAContextSwapChain` sets its offscreen layer's background to opaque black at
construction (`cocoa_window.m:4339`), before any drawable exists -- and § 2.1 measured that line as
pristine winehq, not a project addition. On a production build that black IS what a user sees in
the S3 gap. A removes it.

⚠ **The premise A rests on is UNMEASURED, which is exactly what S0 is for.** Whether an
`opaque = YES` CAMetalLayer with no background and no drawable composites as *nothing* through a
`CALayerHost` is undocumented; every cell to date ran that layer either black or blue, so nobody
has seen it with no background at all. If it composites as an opaque fill, **A-drop is inert** and
S3's mutant could never go red -- which is why S0 decides A's FORM before anything is built on it.

  --drop     remove the background entirely (the principled form, and what S0 tests)
  --defer    NOT IMPLEMENTED. S0's fallback if --drop is inert: `opaque = NO` deferred on the
             § 2.4 timer pattern. Deliberately absent -- it is only worth writing if S0 says so,
             and writing it first would invite building on the branch S0 might close.
  --colours  also apply diag-colours-patch.py, passing everything after it through. ⚠ With --drop
             you MUST pass --noblue: the blue patch rewrites the very line --drop removes, so
             without it one of the two patchers finds no match and the build refuses (loudly, which
             is the intent).
(macgameport, 2026-09-07)
"""
import os, subprocess, sys, io

p = sys.argv[1]

if '--defer' in sys.argv:
    sys.exit("--defer is not implemented: S0 decides whether it is needed. See this file's header.")
if '--drop' not in sys.argv:
    sys.exit("nothing to do: pass --drop (the only implemented form of A)")

if '--colours' in sys.argv:
    i = sys.argv.index('--colours')
    rc = subprocess.run([sys.executable,
                         os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                      'diag-colours-patch.py'), p] + sys.argv[i + 1:]).returncode
    if rc != 0:
        sys.exit("FAIL: diag-colours-patch.py exited %d" % rc)

s = io.open(p, encoding='utf-8').read()


def sub(old, new, label):
    global s
    n = s.count(old)
    if n != 1:
        sys.exit("FAIL %s: %d matches (want 1)" % (label, n))
    s = s.replace(old, new)
    print("  ok %s" % label)


# A-drop. The line is REPLACED BY A COMMENT rather than deleted, so a reader of the patched source
# sees that the absence is deliberate -- and so this patcher's own anchor stays greppable.
sub("    offscreen_layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);",
    """    /* CANDIDATE A (issue #13, --drop): no background. On an opaque layer whose contents are
     * only presented drawables, a background is visible ONLY before the first drawable -- which
     * is the S3 gap itself, and on a production build this line is the black the user sees there.
     * Whether the layer then composites as nothing through a CALayerHost is what S0 measures. */""",
    "A-drop / remove the child layer's black background")

io.open(p, 'w', encoding='utf-8').write(s)
print("  written")
