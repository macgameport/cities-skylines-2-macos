#!/usr/bin/env python3
"""check-links.py -- every relative link in every tracked .md file must resolve to a file or folder.

  python3 common/check-links.py            exit 0 = none unresolved; prints the counts
  python3 common/check-links.py --list     also print each unresolved link as file:line -> target

A link is `](target)` outside fenced code blocks and inline code. URLs (anything with a scheme),
`mailto:` and bare `#anchor` links are skipped; an anchor or a quoted title after the path is ignored.
The target is resolved against the folder of the file that holds the link.
"""
import os, re, subprocess, sys

ROOT = subprocess.run(["git", "-C", os.path.dirname(os.path.abspath(__file__)), "rev-parse", "--show-toplevel"],
                      capture_output=True, text=True, check=True).stdout.strip()
files = subprocess.run(["git", "-C", ROOT, "ls-files", "-z", "*.md"],
                       capture_output=True, text=True, check=True).stdout.split("\0")
LINK = re.compile(r"\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
total, bad = 0, []
for rel in filter(None, files):
    path = os.path.join(ROOT, rel)
    if not os.path.isfile(path):
        continue
    fenced = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for n, line in enumerate(fh, 1):
            if line.lstrip().startswith(("```", "~~~")):
                fenced = not fenced
                continue
            if fenced:
                continue
            for target in LINK.findall(re.sub(r"`[^`]*`", "", line)):
                if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target) or target.startswith("#"):
                    continue
                total += 1
                dest = os.path.normpath(os.path.join(os.path.dirname(path), target.split("#", 1)[0]))
                if not os.path.exists(dest):
                    bad.append("%s:%d -> %s" % (rel, n, target))
print("%d markdown files, %d relative links, %d unresolved" % (len([f for f in files if f]), total, len(bad)))
if "--list" in sys.argv or bad:
    for b in bad:
        print("  " + b)
sys.exit(1 if bad else 0)
