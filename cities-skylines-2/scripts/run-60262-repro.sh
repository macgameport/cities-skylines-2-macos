#!/bin/bash
# run-60262-repro.sh <engine-dir> <tag> -- run the wine 60262 reproducer (frameless-window-repro.c) on
# one stock-layout wine engine, capture the window, and count the rows of macOS chrome above the
# client area. Used 2026-10-10 to measure Julliard's 6cfa941 against stock 11.16 (R4 doc § "Upstream
# fix, measured"). Expects /tmp/winlist (swiftc -O winlist.swift -o /tmp/winlist) and /tmp/toprows
# (swiftc -O toprows.swift -o /tmp/toprows); frameless-repro.exe built per frameless-window-repro.c.
#
# Do NOT set DYLD_FALLBACK_LIBRARY_PATH into a wrapper bundle here -- Gatekeeper then verifies the
# whole 90 GB bundle and wineboot hangs behind the sheet (GOTCHAS 2026-10-10). The FreeType warning
# the engine prints without it is harmless for geometry. Window capture uses -R (region) because
# `screencapture -l` fails for wine windows on macOS 27. (macgameport, 2026-10-10)
E=$1; TAG=$2; OUT=/Users/js/cs2-patch/evidence/60262-6cfa941
export WINEPREFIX=/Users/js/cs2-patch/stock-prefix WINEDLLOVERRIDES="mscoree,mshtml=d" WINEDEBUG=-all
unset DYLD_FALLBACK_LIBRARY_PATH
echo "=== $TAG  ($E)  win32u.so $(shasum -a 256 $E/lib/wine/x86_64-unix/win32u.so | cut -c1-16)"
$E/bin/wine /Users/js/cs2-patch/frameless-repro.exe > $OUT/$TAG-stdout.txt 2>&1 &
ID=""; for i in $(seq 1 60); do sleep 0.5; L=$(/tmp/winlist | grep -i 'title=frameless repro'); [ -n "$L" ] && { ID=$(echo "$L" | head -1 | sed -E 's/.*id=([0-9]+).*/\1/'); break; }; done
[ -z "$ID" ] && { echo "window NOT FOUND"; sleep 12; $E/bin/wineserver -k; exit 1; }
sleep 2; /tmp/winlist | grep -i 'title=frameless repro' | tee $OUT/$TAG-winlist.txt
ok=0; for i in $(seq 1 12); do screencapture -x -o -l "$ID" $OUT/$TAG.png 2>/dev/null && [ -s $OUT/$TAG.png ] && { ok=1; break; }; sleep 0.5; done
[ $ok = 1 ] && /tmp/toprows $OUT/$TAG.png | tee $OUT/$TAG-toprows.txt || echo "capture FAILED"
# region fallback (screen coordinates from winlist, points)
R=$(/tmp/winlist | grep -i 'title=frameless repro' | head -1 | sed -E 's/.*size=([0-9]+)x([0-9]+) at=(-?[0-9]+),(-?[0-9]+).*/\3,\4,\1,\2/')
screencapture -x -R "$R" $OUT/$TAG-region.png 2>/dev/null && echo "region $R captured"
wait; echo "--- stdout"; grep -E 'style|rect|client|NON-CLIENT|dy !=' $OUT/$TAG-stdout.txt
$E/bin/wineserver -k; sleep 2
