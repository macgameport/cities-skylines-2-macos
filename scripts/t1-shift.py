#!/usr/bin/env python3
# t1-shift.py <before.png> <after.png> -- T1's decision: where did the changed content go?
#
# Finds the region that differs between two captures of Steam's window (top chrome and bottom bar
# excluded) and the horizontal offset, in capture px, that best explains it: after(x) ~ before(x-d).
# Prints one line: `changed=<px> best=<d> match=<frac at d> match0=<frac at d=0>`.
#
# WHY measure instead of compare two strips: until 2026-10-12 T1 compared fixed columns X and X+120,
# assuming a driver move of +120 lands as +120 capture px. On the Mac Studio it lands as 72 Win32 px
# (144 capture px at 2x, 72 at 1x: measured on both the daily module and with RetinaMode on), and the
# column chooser only checked contrast on one side of X -- so T1 read VOID on a layer that followed.
# Needs Apple's /usr/bin/python3 (PIL); run without -I, which hides its user site-packages.
# (macgameport, 2026-10-12)
import sys
from PIL import Image, ImageChops

b = Image.open(sys.argv[1]).convert('L')
a = Image.open(sys.argv[2]).convert('L')
W, H = b.size
y0, y1 = int(H * 0.15), int(H * 0.90)
B = b.crop((0, y0, W, y1)); A = a.crop((0, y0, W, y1))
mask = lambda im: im.point(lambda v: 255 if v > 12 else 0)
d0 = mask(ImageChops.difference(A, B))
changed = d0.histogram()[255]
if changed < 0.002 * W * (y1 - y0):
    print("changed=%d best=0 match=1.00 match0=1.00" % changed); sys.exit(0)
bx = d0.getbbox()

def match(d):
    x0, x1 = max(bx[0], d, 0), min(bx[2], W + min(d, 0))
    if x1 - x0 < 40: return 0.0
    diff = mask(ImageChops.difference(A.crop((x0, bx[1], x1, bx[3])),
                                      B.crop((x0 - d, bx[1], x1 - d, bx[3]))))
    return 1 - diff.histogram()[255] / ((x1 - x0) * (bx[3] - bx[1]))

best = max(((d, match(d)) for d in range(-40, 401, 4)), key=lambda t: t[1])
print("changed=%d best=%d match=%.2f match0=%.2f" % (changed, best[0], best[1], match(0)))
