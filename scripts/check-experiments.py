#!/usr/bin/env python3
"""check-experiments.py — keep EXPERIMENTS.md honest against the evidence store.

Run by `button up`. Exits non-zero on drift, so a stale ledger is loud rather than quietly wrong.

The failure this guards against (2026-08-30): 41 of 43 render cells had been measured with no font
library, and several conclusions in GOTCHAS.md rested on them. Nothing surfaced that, because a
conclusion and the run it came from lived in different files with no link between them.

Checks
  1. every cell in the evidence store has a row in the index         (unrecorded evidence)
  2. every index row has a surviving evidence dir                     (evaporated evidence)
  3. no SUPPORTED/PARTIAL claim cites a cell the index marks VOID     (the anti-circling check)
  4. cells with no config.json are reported as unfingerprinted        (pre-procedure runs)
  5. GOTCHAS.md sections carrying an `Evidence:` line are counted     (adoption, informational)

  --regen  rewrite the index table from the evidence store, then re-check.
"""
import os, re, sys, glob, argparse

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEDGER = os.path.join(REPO, "EXPERIMENTS.md")
GOTCHAS = os.path.join(REPO, "GOTCHAS.md")
STORE = os.path.expanduser("~/cs2-patch/evidence")

FT_MARK = "cannot find the FreeType"


def scan_store():
    """Derive each cell's ground truth from its own artifacts, never from the ledger."""
    cells = {}
    if not os.path.isdir(STORE):
        return cells
    for d in sorted(os.listdir(STORE)):
        p = os.path.join(STORE, d)
        if not os.path.isdir(p):
            continue
        so = os.path.join(p, "stdout.txt")
        txt = ""
        if os.path.exists(so):
            with open(so, encoding="utf-8", errors="replace") as fh:
                txt = fh.read()
        pngs = glob.glob(os.path.join(p, "win-*.png"))
        ran = "?"
        rp = os.path.join(p, "ran-at.txt")
        if os.path.exists(rp):
            ran = open(rp).read().strip()[:16].replace("T", " ")
        ft = txt.count(FT_MARK)
        cells[d] = {
            "ran": ran,
            "ft": ft,
            "gnutls": txt.lower().count("load libgnutls"),
            "mvk": txt.count("Failed to load libMoltenVK"),
            "render": "rendered" if any(os.path.getsize(x) > 120000 for x in pngs)
                      else ("black" if pngs else "—"),
            "status": "VOID-LIBS" if ft > 0 else ("no-capture" if not pngs else "candidate"),
            "fingerprinted": os.path.exists(os.path.join(p, "config.json")),
        }
    return cells


ROW = re.compile(r"^\|\s*(\S[^|]*?)\s*\|\s*`([^`]+)`\s*\|\s*(\d+)\s*\|")
CLAIM = re.compile(r"^\|\s*(C\d+)\s*\|(.*)$")


def parse_ledger(text):
    index, claims = {}, []
    for line in text.splitlines():
        m = ROW.match(line)
        if m:
            index[m.group(2)] = {"ran": m.group(1), "ft": int(m.group(3)), "line": line}
            continue
        c = CLAIM.match(line)
        if c:
            cols = [x.strip() for x in c.group(2).split("|")]
            status = ""
            for col in cols:
                s = col.strip("` ")
                if s in ("SUPPORTED", "PARTIAL", "UNREVIEWED", "VOID", "RETRACTED"):
                    status = s
                    break
            claims.append({"id": c.group(1), "status": status, "raw": c.group(2),
                           "cites": re.findall(r"`([a-z0-9][a-z0-9._*-]+)`", c.group(2))})
    return index, claims


def render_index(cells):
    out = ["| ran | cell | FT | gnutls | MVK | capture | status |",
           "|---|---|---:|---:|---:|---|---|"]
    for name in sorted(cells, key=lambda n: (cells[n]["ran"], n)):
        c = cells[name]
        out.append("| %s | `%s` | %d | %d | %d | %s | %s |"
                   % (c["ran"], name, c["ft"], c["gnutls"], c["mvk"], c["render"], c["status"]))
    v = sum(1 for c in cells.values() if c["status"] == "VOID-LIBS")
    k = sum(1 for c in cells.values() if c["status"] == "candidate")
    out += ["", "%d cells · %d VOID-LIBS · %d candidate" % (len(cells), v, k)]
    return "\n".join(out)


def regen(text, cells):
    start = text.find("| ran | cell | FT |")
    if start < 0:
        print("  ! no index table found to regenerate"); return text
    end = text.find("\n---", start)
    tail = text[end:] if end > 0 else "\n"
    return text[:start] + render_index(cells) + "\n" + tail.lstrip("\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--regen", action="store_true")
    args = ap.parse_args()

    if not os.path.exists(LEDGER):
        print("FAIL: EXPERIMENTS.md missing"); return 1
    text = open(LEDGER, encoding="utf-8").read()
    cells = scan_store()

    if args.regen:
        new = regen(text, cells)
        if new != text:
            open(LEDGER, "w", encoding="utf-8").write(new)
            print("  regenerated index (%d cells)" % len(cells))
            text = new
        else:
            print("  index already current")

    index, claims = parse_ledger(text)
    problems, notes = [], []

    for name in cells:
        if name not in index:
            problems.append("cell in evidence store with no ledger row: %s" % name)
    for name in index:
        if name not in cells:
            problems.append("ledger row whose evidence is gone: %s" % name)
    for name, c in sorted(cells.items()):
        if name in index and index[name]["ft"] != c["ft"]:
            problems.append("ledger FT count stale for %s (says %d, artifacts say %d)"
                            % (name, index[name]["ft"], c["ft"]))

    # the anti-circling check
    for cl in claims:
        if cl["status"] not in ("SUPPORTED", "PARTIAL"):
            continue
        # A VOID run may still hold a valid measurement of something else. Citing one is allowed
        # ONLY with an explicit `void-ok:` marker naming what survives — so the exemption is a
        # deliberate written claim, not an oversight that silently passes.
        for cited in cl["cites"]:
            if cited in cells and cells[cited]["status"] == "VOID-LIBS":
                if "void-ok" in cl["raw"].lower():
                    continue
                problems.append("%s is %s but cites VOID run `%s` — restate what survives, or mark "
                                "`void-ok: <what the void run still measures>`"
                                % (cl["id"], cl["status"], cited))

    unfp = [n for n, c in cells.items() if not c["fingerprinted"]]
    if unfp:
        notes.append("%d cell(s) predate cell-fingerprint.sh — config unrecorded, treat as UNREVIEWED"
                     % len(unfp))
    if os.path.exists(GOTCHAS):
        g = open(GOTCHAS, encoding="utf-8").read()
        notes.append("GOTCHAS.md: %d section(s), %d carry an `Evidence:` line"
                     % (g.count("\n## "), len(re.findall(r"^\s*(?:\*\*)?Evidence:", g, re.M))))

    print("\n=== experiment ledger check ===")
    print("  evidence store : %s (%d cells)" % (STORE, len(cells)))
    print("  ledger rows    : %d index, %d claims" % (len(index), len(claims)))
    for n in notes:
        print("  note   %s" % n)
    for p in problems:
        print("  DRIFT  %s" % p)
    print("  -> %s" % ("OK" if not problems else "%d drift item(s)" % len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
