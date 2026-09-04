#!/usr/bin/env python3
"""Mutants of the resize signal stage 2 is armed on (window.c, `main` branch).

    PATCH_FILE=window.c bash scripts/build-winemac.sh <out.so> scripts/signal-mutants.py --off
    PATCH_FILE=window.c bash scripts/build-winemac.sh <out.so> scripts/signal-mutants.py --on

--off  in_size_move_loop() never sees the loop: a synthetic drag must then read `size/move loop 0`
       on every root pass and fire 0 stretches -- the row that proves the signal is what arms it.
--on   in_size_move_loop() always reports the loop: a SetWindowPos churn must then stretch
       (T10 RED) -- the row that proves the churn guard is the signal and not an accident.

Exact-string replacement, so a zero-match is loud; the anchor is the helper's return line.
"""
import sys, io
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
old = "    return (info.flags & GUI_INMOVESIZE) != 0;\n}"
n = s.count(old)
if n != 1:
    sys.exit("FAIL signal helper: %d matches (want 1)" % n)
if '--off' in sys.argv:
    s = s.replace(old, "    return FALSE;   /* MUTANT sig-off: the loop is never seen */\n}")
    print("  ok mutant sig-off")
elif '--on' in sys.argv:
    s = s.replace(old, "    return TRUE;   /* MUTANT sig-on: always inside the loop */\n}")
    print("  ok mutant sig-on")
else:
    sys.exit("FAIL: say --off or --on")
io.open(p, 'w', encoding='utf-8').write(s)
print("  written")
