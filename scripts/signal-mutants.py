#!/usr/bin/env python3
"""The two controls for stage 2's resize signal (window.c, `main` branch).

    PATCH_FILE=window.c bash scripts/build-winemac.sh <out.so> scripts/signal-mutants.py --off
    PATCH_FILE=window.c bash scripts/build-winemac.sh <out.so> scripts/signal-mutants.py --on

--off  (E4′)  in_size_move_loop() never reports the loop. A real drag (sizedrag / a hand) must
              then fire 0 stretches, every root pass reading `size/move loop 0`. This is the row
              that proves the loop is what ARMS the stretch: silence the signal, the fix dies.

--on   (E4)   Drop the arming guard: old_rects is passed to every child on every root pass,
              whatever the signal says. A SetWindowPos CHURN -- which never enters the loop --
              must then stretch its full-client child (T10 RED). This is the row that proves the
              guard is what CONTAINS the stretch to a real resize.

Why --on drops the guard rather than forcing the flag TRUE: `07cd84d` pairs the flag with
hwndMoveSize (only the sized root's pass is armed), so a forced flag with no matching move-size
window is correctly refused -- measured 2026-09-04, a `return TRUE` helper left the churn at
0 stretches. Dropping the guard is the plan's own E4 ("force in_live_resize true OR drop the
guard", §5 T10) and is the mutant that actually reddens the churn.

Exact-string replacement, so a zero-match is loud.
"""
import sys, io
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()

def sub(old, new, label):
    n = s.count(old)
    if n != 1:
        sys.exit("FAIL %s: %d matches (want 1)" % (label, n))
    return s.replace(old, new)

if '--off' in sys.argv:
    s = sub("    return (info.flags & GUI_INMOVESIZE) != 0;\n}",
            "    return FALSE;   /* MUTANT E4-prime: the loop is never seen */\n}",
            "sig-off helper")
    print("  ok mutant E4' (sig-off): the size loop is never seen")
elif '--on' in sys.argv:
    s = sub("        if (!loop && !data->in_live_resize) old_rects = NULL;\n",
            "        /* MUTANT E4: guard dropped -- old_rects armed regardless of the signal */\n",
            "sig-on guard")
    print("  ok mutant E4 (sig-on): the arming guard is dropped")
else:
    sys.exit("FAIL: say --off or --on")
io.open(p, 'w', encoding='utf-8').write(s)
print("  written")
