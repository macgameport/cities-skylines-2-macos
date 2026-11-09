#!/usr/bin/env python3
"""Apply the issue-#7 diagnostic colours to cocoa_window.m ON THE `main` BRANCH.

    bash scripts/build-winemac.sh <out.so> scripts/diag-colours-patch.py [--e1] [--noblue] \
                                                 [--cyan] [--norelease]
    (or directly: python3 scripts/diag-colours-patch.py <cocoa_window.m> [flags])

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


def sub_any(variants, label):
    """Exactly one of several EXACT anchors must match exactly once; the rest must not match.

    Branch `d` (candidate D) moved the deferred create background out of
    -addCALayerHostViewWithContextId: into -armCALayerHostBackground:, which re-indented the two
    lines the magenta anchor matches by four columns. A regex over whitespace would paper over
    that, and would also stop this patcher failing loudly on a file it does not understand -- the
    property that catches a `core` build. So each branch gets its own exact anchor and the patcher
    says which one it used; two matching, or none, is still a refusal.
    """
    global s
    hits = [(o, n, c) for o, n, c in ((o, n, s.count(o)) for o, n in variants) if c]
    if len(hits) != 1 or hits[0][2] != 1:
        sys.exit("FAIL %s: %s (want exactly one anchor matching exactly once)"
                 % (label, ", ".join("anchor %d: %d matches" % (i + 1, s.count(o))
                                     for i, (o, _) in enumerate(variants))))
    s = s.replace(hits[0][0], hits[0][1])
    print("  ok %s (anchor %d of %d)" % (label, variants.index((hits[0][0], hits[0][1])) + 1, len(variants)))

# --- magenta (S2): the create path's DEFERRED background. `main` already paints a host black 120 ms
# after creation to cover the snap's sliver, and "a new host past its deferred black with no frame"
# is exactly the plan's S2. So recolour that, rather than adding a second background.
MAGENTA_BODY = """/* DIAG (issue #7): magenta = S2, a host still showing its create-path
%(i)s * background. Magenta and green, not red: Steam's store banner is red (C36).
%(i)s * The !backgroundColor guard matters -- a host created and then reframed-grown
%(i)s * inside the 120 ms window has already been painted green by placeCALayerHost:,
%(i)s * and without the guard this would repaint it magenta and score S1 as S2. */
%(i)sstatic CGColorRef diag_magenta;
%(i)sif (!diag_magenta) diag_magenta = CGColorCreateGenericRGB(1.0, 0.0, 1.0, 1.0);
%(i)sif ([_caLayerHosts objectForKey:@(cid)] == deferred && !deferred.backgroundColor)
%(i)s    deferred.backgroundColor = diag_magenta;"""

# ⚠ Two anchors, because branch `d` re-indented these lines by four columns when it moved the
# deferred background into -armCALayerHostBackground:. Exact strings both ways -- see sub_any.
_MAG = [(i + "if ([_caLayerHosts objectForKey:@(cid)] == deferred)\n"
         + i + "    deferred.backgroundColor = CGColorGetConstantColor(kCGColorBlack);",
         i + MAGENTA_BODY % {"i": i})
        for i in (" " * 16, " " * 12)]
sub_any(_MAG, "magenta / deferred create background")

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
#
# ⚠ Two anchors again, and on branch `d` this is a MUTANT rather than a recolour. On `main` the
# line being recoloured is the opaque black candidate A removes (`:4339`), so painting it blue only
# changes the colour of a background that is there either way. Candidate D's branch has already
# dropped that line, so blue there RESTORES a background the candidate removed -- which is exactly
# the S3 plan's mutant (a): "restore :4339 on the D-diag source, build without --noblue -> blue
# returns". A D build carrying it is not candidate D and must never be installed or compared as one.
BLUE_BODY = """{   /* DIAG (issue #7): blue = the child's own layer before its first drawable (S3). */
        static CGColorRef diag_blue;
        if (!diag_blue) diag_blue = CGColorCreateGenericRGB(0.0, 0.0, 1.0, 1.0);
        offscreen_layer.backgroundColor = diag_blue;
    }"""
if '--noblue' not in sys.argv:
    # ⚠ anchor 1's replacement carries NO leading indent, because the string it replaces includes
    # its own -- reproducing exactly what every module built from `main` to date was patched with.
    # Verified byte-identical against the pre-two-anchor patcher over all five main recipes.
    sub_any([("    offscreen_layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);",
              BLUE_BODY),
             ("    offscreen_layer.magnificationFilter = kCAFilterNearest;\n"
              "    offscreen_layer.contentsScale = retina_on ? 2.0 : 1.0;",
              "    offscreen_layer.magnificationFilter = kCAFilterNearest;\n"
              "    " + BLUE_BODY + "\n"
              "    offscreen_layer.contentsScale = retina_on ? 2.0 : 1.0;")],
            "blue / child offscreen layer")

# --- cyan (S4): the CONTENT VIEW's own layer, the surface below every host.
#
# C42's build `38b52d6b3971d78b` produced C42 and C61 and had NO committed build input -- the S3
# plan lists folding it in as instrument (4) for exactly that reason, and the ledger's own rule is
# that a build input which produced evidence is not throwaway.
#
# ⚠ This is a RECONSTRUCTION from C42's prose description and the source it names -- NOT a
# reproduction, and it cannot be made into one. Measured 2026-09-07: this patch on `main` builds
# `e700ac8fdfef0e80` (508936 B) against C42's `38b52d6b3971d78b` (508656 B). The difference is not
# evidence the reconstruction is wrong, and equally is no evidence it is right, because a
# byte-compare is unavailable here on two counts: (a) FIVE behavioural commits landed on `main`
# after C42's module was built at 21:22 on 2026-09-03 (`eecbe79` .. `5dd318c`, the stage-1 scale
# and stage-2 stretch), so the code around the patch is not the code C42 measured; (b) `main` is
# the glue commit rebased over the core series, so the tip C42 built from is not a commit that
# still exists to check out. Do not spend a session trying.
#
# What follows from that, and it is a constraint on how a --cyan arm may be read: a new --cyan run
# measures WHICH SURFACE is exposed on TODAY's module. C42's 3-of-15 split and C61's 25 px column
# were measured on a different module and are NOT a baseline this build continues. Treat a --cyan
# arm as its own fixture with its own controls; the S3 plan's S0 does exactly that, and its
# `--noblue` mutant (blue returns) is the check that the colour was applied at all -- the failure
# C42's void first attempt shows is the one that matters, not a digest mismatch.
#
# TWO halves, and the first attempt failed by having only one. C42's void first try set the colour
# inside `updateLayer`, which runs when the window's GDI surface is redrawn -- and a window whose
# content is entirely hosted CALayers may never redraw one, so it returned 0.00 % cyan everywhere
# and "the strip is not this layer" was indistinguishable from "the colour was never applied".
# Setting it at `initWithFrame:` applies it unconditionally at construction.
#
# ⚠ The blit suppression CHANGES THE FIXTURE: the content view stops showing the window's GDI
# surface for the life of the run. That is deliberate (the background is invisible under an opaque
# blit) and it is why a --cyan build measures WHICH SURFACE is exposed, never how often a normal
# window is. Do not compare a --cyan arm's absolute rates with a plain diag arm's.
#
# ⚠ Cyan is only safe on a page that cannot contain it. C61 lost 2 runs of 10 to a 489x305 Steam
# store banner scoring 1850 cyan frames against the others' 30-41. Pair this with drag-session.sh's
# STEAM_PAGE knob or with a shape gate.
if '--cyan' in sys.argv:
    sub("""            [self setWantsLayer:YES];""",
        """            [self setWantsLayer:YES];
            {   /* DIAG (issue #7 S4 / #13 S0): cyan = the content view's OWN layer, the surface
                 * that shows when neither a host nor the child's layer covers the area. Set here,
                 * at construction, NOT in updateLayer -- a fully-hosted window may never redraw a
                 * GDI surface, and C42's first attempt scored 0.00 % everywhere because of it. */
                static CGColorRef diag_cyan;
                if (!diag_cyan) diag_cyan = CGColorCreateGenericRGB(0.0, 1.0, 1.0, 1.0);
                self.layer.backgroundColor = diag_cyan;
            }""",
        "cyan / content view layer")
    sub("""            layer.position = surfaceRect.origin;
            layer.contents = (id)image;""",
        """            layer.position = surfaceRect.origin;
            /* DIAG: the GDI blit is SUPPRESSED so the cyan background above is visible. An opaque
             * contents image covers it completely, which is what made C42's first attempt
             * unreadable. The window stops showing its GDI surface for the run -- deliberate. */
            if (0) layer.contents = (id)image;""",
        "cyan / suppress the GDI blit")

# --- --norelease: the S7 mutant. The child stops telling the owner its context is gone.
#
# S7 bounds D's hold: "max live hosts per child <= 2 throughout". This mutant removes the exit that
# keeps it there, so a hold with no other bound grows without limit and `scripts/live-hosts.py`
# reports it. It is a MUTANT, not a candidate -- a build carrying it leaks a host per swapchain by
# construction, which is the 2026-08-31 leak class (C29) reintroduced on purpose.
if '--norelease' in sys.argv:
    sub("    if (context_id) macdrv_release_remote_layer(hwnd, context_id);",
        """    /* MUTANT --norelease (S7): the child never posts RELEASE, so the owner's only remaining
     * exits are the next CREATE, the dead-child drain and root destroy. Expected RED: max live
     * hosts per child grows monotonically past 2. Restore this line to go green. */
    if (0 && context_id) macdrv_release_remote_layer(hwnd, context_id);""",
        "--norelease mutant")

if '--e1' in sys.argv:
    sub("""        NSValue* stored = [_caLayerHostContentSizes objectForKey:@(contextId)];
        CGSize content = stored ? stored.sizeValue : frame.size;""",
        """        NSValue* stored = [_caLayerHostContentSizes objectForKey:@(contextId)];
        CGSize content = frame.size;   /* MUTANT E1: the content size is never read back */""",
        "E1 mutant")

io.open(p, 'w', encoding='utf-8').write(s)
print("  written")
