#!/usr/bin/env python3
"""Apply the issue-#7 diagnostic colours to cocoa_window.m ON THE `main` BRANCH.

    bash scripts/build-winemac.sh <out.so> scripts/diag-colours-patch.py [--e1] [--noblue]
    (or directly: python3 scripts/diag-colours-patch.py <cocoa_window.m> [--e1] [--noblue])

⚠ `main` only. The nested winemac repo keeps `core` (the stock-applicable subset) and `main`
(= aquadran + core + the DXMT glue commit). A module built from `core` installs and loads fine and
then Steam's GPU process dies with c0000409 and posts no remote layer at all, so the window renders
black and every band scores 100% -- which looks like a measurement. Measured 2026-09-03: `core`
builds 502560 B, `main` builds 508544 B, and the two void runs cost a session each.

Exact-string replacement, so a zero-match is loud. This lived in /tmp as a "throwaway" until
2026-09-04, when it was found gone while the ledger still cited four modules built from it (C39-C43,
C45, C46) -- recovered from the session transcript and committed, because a build input that
produced evidence is not throwaway.
"""
import sys, io
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()

def sub(old, new, label):
    global s
    n = s.count(old)
    if n != 1:
        sys.exit("FAIL %s: %d matches (want 1)" % (label, n))
    s = s.replace(old, new)
    print("  ok %s" % label)

# --- magenta (S2): the create path's DEFERRED background. `main` already paints a host black 120 ms
# after creation to cover the snap's sliver, and "a new host past its deferred black with no frame"
# is exactly the plan's S2. So recolour that, rather than adding a second background.
sub("""                if ([_caLayerHosts objectForKey:@(cid)] == deferred)
                    deferred.backgroundColor = CGColorGetConstantColor(kCGColorBlack);""",
    """                /* DIAG (issue #7): magenta = S2, a host still showing its create-path
                 * background. Magenta and green, not red: Steam's store banner is red (C36).
                 * The !backgroundColor guard matters -- a host created and then reframed-grown
                 * inside the 120 ms window has already been painted green by placeCALayerHost:,
                 * and without the guard this would repaint it magenta and score S1 as S2. */
                static CGColorRef diag_magenta;
                if (!diag_magenta) diag_magenta = CGColorCreateGenericRGB(1.0, 0.0, 1.0, 1.0);
                if ([_caLayerHosts objectForKey:@(cid)] == deferred && !deferred.backgroundColor)
                    deferred.backgroundColor = diag_magenta;""",
    "magenta / deferred create background")

# --- green (S1): a placement whose target frame exceeds the size the remote content was created at
sub("""        host.bounds = (CGRect){ CGPointZero, content };
        host.position = frame.origin;""",
    """        /* DIAG (issue #7): green = an existing host placed larger than its content, the S1
         * source. Stage 1's transform is supposed to cover it; green visible in the strip means
         * the scale did not engage. Read from `stored`, not `content`, which the floor and the
         * one-pixel tolerance above may already have substituted. */
        {
            static CGColorRef diag_green;
            if (!diag_green) diag_green = CGColorCreateGenericRGB(0.0, 1.0, 0.0, 1.0);
            CGSize created = stored ? stored.sizeValue : frame.size;
            if (frame.size.width > created.width || frame.size.height > created.height)
                host.backgroundColor = diag_green;
        }
        host.bounds = (CGRect){ CGPointZero, content };
        host.position = frame.origin;""",
    "green / reframe-grow")

# --- blue (S3): the child's own offscreen layer. Runs in the GPU process.
if '--noblue' not in sys.argv:
    sub("    offscreen_layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);",
        """{   /* DIAG (issue #7): blue = the child's own layer before its first drawable (S3). */
        static CGColorRef diag_blue;
        if (!diag_blue) diag_blue = CGColorCreateGenericRGB(0.0, 0.0, 1.0, 1.0);
        offscreen_layer.backgroundColor = diag_blue;
    }""",
        "blue / child offscreen layer")

if '--e1' in sys.argv:
    sub("""        NSValue* stored = [_caLayerHostContentSizes objectForKey:@(contextId)];
        CGSize content = stored ? stored.sizeValue : frame.size;""",
        """        NSValue* stored = [_caLayerHostContentSizes objectForKey:@(contextId)];
        CGSize content = frame.size;   /* MUTANT E1: the content size is never read back */""",
        "E1 mutant")

io.open(p, 'w', encoding='utf-8').write(s)
print("  written")
