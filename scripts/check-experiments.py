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
import os, re, sys, glob, argparse, secrets

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEDGER = os.path.join(REPO, "EXPERIMENTS.md")
GOTCHAS = os.path.join(REPO, "GOTCHAS.md")
# The Steam-UI thread was split out 2026-08-30 (65% of GOTCHAS, one open investigation). ALL 24
# status banners went with it, so a checker reading only GOTCHAS.md would validate an empty set
# and report OK forever. Both files are scanned as one corpus.
BANNER_DOCS = [GOTCHAS, os.path.join(REPO, "docs", "steam-ui-investigation.md")]
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


ROW = re.compile(r"^\|\s*(exp_[0-9a-f]{6})\s*\|\s*(\S[^|]*?)\s*\|\s*`([^`]+)`\s*\|\s*(\d+)\s*\|")
CLAIM = re.compile(r"^\|\s*(C\d+)\s*\|(.*)$")


def parse_ledger(text):
    index, claims = {}, []
    for line in text.splitlines():
        m = ROW.match(line)
        if m:
            index[m.group(3)] = {"eid": m.group(1), "ran": m.group(2),
                                 "ft": int(m.group(4)), "line": line}
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
                           "cites": re.findall(r"`([a-z0-9][a-z0-9._*-]+)`", c.group(2))
                                    + re.findall(r"\b(exp_[0-9a-f]{6})\b", c.group(2))})
    return index, claims


def render_index(cells, existing):
    """Experiment ids are MINTED OPAQUE SURROGATES (`exp_` + 6 hex), per the project's standing
    key/label rule: an identity key that other rows point at must carry no readable meaning.

    Sequential ids failed that twice over — `E043` silently asserts "the 43rd, and later than
    E042", so a backfilled older run would make the ordering lie, and keeping the numbering stable
    across a regen needed bookkeeping (read prior ids, max+1) that a minted key does not.
    Minted, not derived from the cell name: a label must never be the source of a durable key."""
    used = {n: existing[n]["eid"] for n in existing}
    taken = set(used.values())
    for name in sorted(cells, key=lambda n: (cells[n]["ran"], n)):
        if name not in used:
            while True:
                cand = "exp_" + secrets.token_hex(3)
                if cand not in taken:
                    break
            used[name] = cand
            taken.add(cand)
    out = ["| id | ran | cell | FT | gnutls | MVK | capture | status |",
           "|---|---|---|---:|---:|---:|---|---|"]
    for name in sorted(cells, key=lambda n: (cells[n]["ran"], n)):
        c = cells[name]
        out.append("| %s | %s | `%s` | %d | %d | %d | %s | %s |"
                   % (used[name], c["ran"], name, c["ft"], c["gnutls"], c["mvk"],
                      c["render"], c["status"]))
    v = sum(1 for c in cells.values() if c["status"] == "VOID-LIBS")
    k = sum(1 for c in cells.values() if c["status"] == "candidate")
    out += ["", "%d cells · %d VOID-LIBS · %d candidate" % (len(cells), v, k)]
    return "\n".join(out)


def regen(text, cells, existing):
    start = text.find("| id | ran | cell | FT |")
    if start < 0:
        print("  ! no index table found to regenerate"); return text
    end = text.find("\n---", start)
    tail = text[end:] if end > 0 else "\n"
    return text[:start] + render_index(cells, existing) + "\n" + tail.lstrip("\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--regen", action="store_true")
    args = ap.parse_args()

    if not os.path.exists(LEDGER):
        print("FAIL: EXPERIMENTS.md missing"); return 1
    text = open(LEDGER, encoding="utf-8").read()
    cells = scan_store()

    if args.regen:
        prior, _ = parse_ledger(text)
        new = regen(text, cells, prior)
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
    present = [d for d in BANNER_DOCS if os.path.exists(d)]
    if present:
        parts = {os.path.basename(d): open(d, encoding="utf-8").read() for d in present}
        g = "\n".join(parts.values())
        banners = len(re.findall(r"^> \*\*Ledger:", g, re.M))
        notes.append("%s: %d section(s), %d carry a `> **Ledger:` status banner"
                     % (" + ".join(parts), sum(t.count("\n## ") for t in parts.values()), banners))
        # The split is only safe while the index still lists every section it moved out. A section
        # added to the detail doc without an index row is invisible to `wake up`, which reads the
        # index — that is exactly the "trap nobody knows exists" this file guards against.
        det = parts.get("steam-ui-investigation.md")
        if det is not None:
            gt = parts.get("GOTCHAS.md", "")
            linked = len(re.findall(r"\]\(docs/steam-ui-investigation\.md#", gt))
            # the L779/L780 pair is one logical section written as two `## ` lines
            sections = det.count("\n## ") - det.count("\n## disproven by")
            if linked != sections:
                problems.append("steam-ui-investigation.md has %d section(s) but GOTCHAS.md's index "
                                "links %d — every moved section needs an index row" % (sections, linked))
        # dangling-reference check: a GOTCHAS banner citing an id no longer in the index is the
        # exact failure this whole system exists to prevent — a conclusion pointing at evidence
        # that is gone, which reads as "backed by a run" to anyone who does not go looking.
        by_id = {v["eid"]: n for n, v in index.items() if "eid" in v}
        for cited in sorted(set(re.findall(r"\b(exp_[0-9a-f]{6})\b", g))):
            if cited not in by_id:
                problems.append("GOTCHAS.md cites %s, which is not in the ledger index" % cited)

        # Convention enforcement. The banner format and the register are two statements of the same
        # fact in two files; nothing but a check keeps them equal, and a banner that says SUPPORTED
        # over a claim the register RETRACTED is worse than no banner at all.
        VOCAB = {"SUPPORTED", "PARTIAL", "UNREVIEWED", "VOID", "RETRACTED"}
        by_claim = {c["id"]: c["status"] for c in claims}
        for line in re.findall(r"^> \*\*Ledger:[^\n]*", g, re.M):
            st = re.search(r"Ledger:\s*`([A-Z-]+)`", line)
            cid = re.search(r"\((C\d+)\)", line)
            if st and st.group(1) not in VOCAB:
                problems.append("GOTCHAS banner uses status `%s`, not in the vocabulary (%s)"
                                % (st.group(1), ", ".join(sorted(VOCAB))))
            if st and cid:
                want = by_claim.get(cid.group(1))
                if want and want != st.group(1):
                    problems.append("GOTCHAS banner says %s is `%s`, register says `%s`"
                                    % (cid.group(1), st.group(1), want))
            if cid and cid.group(1) not in by_claim:
                problems.append("GOTCHAS banner cites %s, which is not in the register" % cid.group(1))

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
