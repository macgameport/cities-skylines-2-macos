# Repo hygiene — identity section, archive, prune, headers, ledger wording

**Status: Not yet triple-checked — run `check it` before build.** Umbrella:
[issue #1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: commit
`c94d9e9`. All items are mechanical; the plan exists so the two that carry a decision (H1, H2) are
decided once and the rest are done in one commit.

---

## H1 — the GitHub-identity section is in a public file

`CLAUDE.md` lines 55–85 (`## GitHub identity — this project is deliberately separated`) name both
accounts and state that nothing publicly links them, in a public repo. The link is already
inferable from dxmt#141 (comments 5 and 6 continue the earlier account's thread), so this is a
consistency fix, not a leak response.

**Design.** Move the section verbatim to `CLAUDE.local.md` at the repo root, add
`CLAUDE.local.md` to `.gitignore`, leave a one-line pointer in `CLAUDE.md` ("agent identity and
`gh` config: see the untracked `CLAUDE.local.md`; agents without it must not run `gh` for this
project"). **Platform fact, verified 2026-09-02 by the Claude Code guide lens against
https://code.claude.com/docs/en/memory.md ("Local instructions"):** `CLAUDE.local.md` is the
documented mechanism for personal, gitignored project instructions; it loads *after* the project
`CLAUDE.md` in the same directory (managed policy → `~/.claude/CLAUDE.md` → project `CLAUDE.md` →
`CLAUDE.local.md`), and the docs themselves say to add it to `.gitignore`. History is **not** rewritten (recorded decision: the text is
already public, a rewrite of a public branch with a triager's links into it costs more than it
buys).

## H2 — `docs/steam-ui-investigation.md` (1652 lines, 33 sections)

It is the raw chronology; `docs/steam-ui-findings.md` is the readable story. **Constraint:** the
file is one of the two banner corpora `scripts/check-experiments.py` scans (`BANNER_DOCS`,
5 references), so moving it means editing the checker and every link (`git grep` the name).

**Design: do not move it.** Add a two-line banner at the top ("ARCHIVE — the raw chronology;
read `steam-ui-findings.md` first; kept in place because the ledger checker scans its status
banners") and leave the checker alone. Cheaper and no link churn; the "archive" is a label.

## H3 — `PLAN.md` (571 lines)

| section (lines) | disposition |
|---|---|
| `✅ SOLVED: the alt-tab freeze` (12–62) | delete; pointer line to `GOTCHAS.md` § alt-tab and `docs/dxmt-bugs/` |
| `✅ ADOPTED: retina` (239–260) | delete; pointer to `docs/plans/retina-swapchain-experiment.md` (as-built) |
| `✅ Retired: fix it upstream in Wine` (261–274) | delete; pointer to `docs/wine-bugs/README.md` |
| `Known-unresolved, low severity` (284–564, 280 lines) | **triage, do not bulk-move**: list every item with a one-line "still real / superseded / fixed silently" — still-real items become GitHub issues (the tracker is on), the rest are deleted with a pointer to where they were resolved |
| `Queued: mod keybinding alerts`, `Performance: RUNNING`, `Report upstream to Paradox`, `Not worth doing` | keep; refresh status lines |

## H4 — `docs/patch-inventory.md` header

Describes only the Wine 10 stack. Add the default `dxmt11` target (10 patches, no licence bypass)
above it and keep the Wine 10 block as the fallback; bump `Last verified`.

## H5 — ledger C2 wording

C2 (`PARTIAL`) describes the geometry-less child patch of 2026-08-29. Keep the row and status (a
measurement is never deleted); reword the notes to "superseded for the current build by C12–C29;
the 2,588,759 B composite measurement stands as the first proof the route composites".

---

## Test plan

| # | test | method | pass |
|---|---|---|---|
| T1 | H1 loads | in a fresh `claude` session in the repo, ask what `GH_CONFIG_DIR` the project uses; the answer must come from `CLAUDE.local.md` | correct answer; `git status` shows the file untracked |
| T2 | H1 pointer is enough for an agent without the local file | the pointer text tells it not to run `gh` | reviewed by reading |
| T3 | H2/H3/H4 leave no broken links | `git grep -n "steam-ui-investigation\|PLAN.md#\|patch-inventory"` and open each hit | every link resolves |
| T4 | ledger gate | `python3 scripts/check-experiments.py` | exit 0 |
| T5 | H3 triage is complete | every item in the old 284–564 span appears exactly once: as an issue number, or as a deletion with a pointer | count matches |

## Exit criteria
1. `CLAUDE.local.md` exists, is untracked, and is auto-loaded (T1); the public `CLAUDE.md` no
   longer names the personal account.
2. H2 banner present; checker untouched; T3, T4 green.
3. `PLAN.md` under 250 lines with the H3 triage table applied; each still-real item has an issue.
4. H4, H5 done.

## Rollback
Plain git revert of one commit; `CLAUDE.local.md` is untracked and stays.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| — | not yet checked | — | — | — | — | — |

**Key paths:** `CLAUDE.md` · `.gitignore` · `PLAN.md` · `docs/steam-ui-investigation.md` ·
`docs/patch-inventory.md` · `EXPERIMENTS.md` · `scripts/check-experiments.py`
