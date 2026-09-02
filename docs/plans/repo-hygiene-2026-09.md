# Repo hygiene — identity section, archive, prune, headers, ledger wording

**Status: check-it'd 2026-09-02 — build-ready-with-fixes (pass 2; corrections folded, cross-plan consistency re-checked).** Umbrella:
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
`CLAUDE.local.md` to `.gitignore` (matching the file's existing comment style), leave a one-line
pointer in `CLAUDE.md`: *"identity detail lives in the untracked `CLAUDE.local.md`; the `gh`
invocation rule is `docs/agent-brief.md` § If you run gh"* — the brief keeps the
`GH_CONFIG_DIR="$HOME/.config/gh-cs2"` line (a path, not an account) and is what subagents are
handed. Reword `CLAUDE.md:103`, which cites "the `GH_CONFIG_DIR` requirement" as if it still lived
in this file. **Residual public mentions, left deliberately:** the earlier account's name stays in
`docs/dxmt-bugs/comment-141-fifth-retraction.md:5,14-15,215-216` and
`comment-141-sixth-shimmer.md:5-6` — they document a public thread whose authorship is visible on
GitHub anyway. **Premise correction for `docs/agent-brief.md:3-4`:** a subagent spawned from a
session *does* receive the project `CLAUDE.md` and the memory index in its system prompt (the
check lens observed its own); what it lacks is the conversation and the memory bodies. The
"agent without the local file" case is therefore a clone on another machine, not a subagent —
say that in the brief. **Platform fact, verified 2026-09-02 by the Claude Code guide lens against
https://code.claude.com/docs/en/memory.md ("Local instructions"):** `CLAUDE.local.md` is the
documented mechanism for personal, gitignored project instructions; it loads *after* the project
`CLAUDE.md` in the same directory (managed policy → `~/.claude/CLAUDE.md` → project `CLAUDE.md` →
`CLAUDE.local.md`), and the docs themselves say to add it to `.gitignore`. History is **not** rewritten (recorded decision: the text is
already public, a rewrite of a public branch with a triager's links into it costs more than it
buys).

## H2 — `docs/steam-ui-investigation.md` (1652 lines, 32 sections the checker counts; 33 `## ` lines)

It is the raw chronology; `docs/steam-ui-findings.md` is the readable story. **Constraint:** the
file is one of the two banner corpora `scripts/check-experiments.py` scans (`BANNER_DOCS` at
`:27`, the name hard-coded five times incl. a regex at `:238`), and it has **42 inbound
references** (34 in `GOTCHAS.md`, 5 in the checker, `EXPERIMENTS.md:778`, `PLAN.md:59`,
`docs/steam-ui-findings.md:9`), so moving it means editing the checker and every link.

**Design: do not move it.** Extend the existing blockquote at lines 3–8 (which already says
"read the index first" but never names `steam-ui-findings.md`) with an ARCHIVE line: "the raw
chronology; read `steam-ui-findings.md` first; kept in place because the ledger checker scans its
status banners". Leave the checker alone. Cheaper and no link churn; the "archive" is a label.

## H3 — `PLAN.md` (571 lines)

| section (lines) | disposition |
|---|---|
| `✅ SOLVED: the alt-tab freeze` (12–62) | delete; pointer line to `GOTCHAS.md:464` § alt-tab, `docs/dxmt-bugs/DRAFT-focus-loss-freeze.md` and `docs/plans/build-wine1116-dxmt-engine.md`. **The open decision at `:41-44`** (a game-level confirmation on dxmt#183, "James's call") gets an explicit disposition: memory records it as closed-not-owed (#206 was closed as a dup of #183); write that, or open an issue |
| `✅ ADOPTED: retina` (239–260) | delete; pointer to `docs/plans/retina-swapchain-experiment.md` (as-built) **and** `docs/plans/launcher-display-profiles.md`; the `:256-260` ship note still says "T10 open" — T10 closed 2026-08-27, say so |
| `✅ Retired: fix it upstream in Wine` (261–274) | delete; pointer text "retired for R1–R3; later filings (60262, 60263) are tracked in `docs/wine-bugs/README.md`" — `:272-273` "nothing is left to file against Wine" is false since 2026-08-31 |
| `Known-unresolved, low severity` (284–564, 281 lines) | **triage, do not bulk-move.** Measured: **9 top-level items + 18 nested bullets, all nested under item 5** (Steam's visible UI, `:322–546`, ~225 lines, superseded by `docs/steam-ui-findings.md` + the ledger). The other eight: home-profile 1080p assumption · `scripts/README.md` 25-of-40 coverage · Metal HUD off · ~~Game.dll.bak~~ (already struck) · fullscreen-toggle cursor desync (untested on 11.16) · graphics-in-game rule (already in CLAUDE.md) · D3DMetal API notices (Wine 10 only) · Rosetta horizon. Each gets one line: still real → GitHub issue; superseded / fixed → deleted with a pointer |
| `Queued: mod keybinding alerts`, `Performance: RUNNING`, `Report upstream to Paradox`, `Not worth doing` | keep; refresh status lines |

## H4 — `docs/patch-inventory.md` header

Describes only the Wine 10 stack. Add the default `dxmt11` target (10 patches, no licence bypass)
above it, add `dxmt11` to the `Applied by:` line, keep the Wine 10 block as the fallback, bump
`Last verified` — and fix `:11` in the same edit: "retires 7 of the 17" contradicts the measured
16 total / 10 on `dxmt11` / 6 errno (`CLAUDE.md`: "the old 17 counted the cohtml warning").

## H5 — ledger C2 wording

C2 (`PARTIAL`) describes the geometry-less child patch of 2026-08-29. Keep the row and status (a
measurement is never deleted) **and keep its `**void-ok:**` marker** — `check-experiments.py:181-188`
exempts a claim resting on VOID cells only if the row text contains it; dropping it turns T4 red.
Reword the notes to "superseded for the current build by C12–C29; the 2,588,759 B composite
measurement stands as the first proof the route composites".

---

## Test plan

| # | test | method | pass |
|---|---|---|---|
| T1 | H1 loads | put a **nonce sentinel** (a random word) in `CLAUDE.local.md`; in a fresh `claude` session in the repo ask for the nonce; then rename the file and ask again (negative control). Asking about `GH_CONFIG_DIR` would prove nothing — `docs/agent-brief.md:52`, two `docs/dxmt-bugs/` files and auto-memory all carry it | nonce returned with the file present, unknown with it renamed; `git check-ignore -v CLAUDE.local.md` prints the rule and `git ls-files CLAUDE.local.md` is empty (an ignored file is *invisible* in `git status`) |
| T2 | H1 pointer present and the brief unchanged | `grep -c 'CLAUDE.local.md' CLAUDE.md` = 1 and `git grep -n GH_CONFIG_DIR -- ':!CLAUDE.local.md'` lists only `docs/agent-brief.md` and the two `docs/dxmt-bugs/` files | counts as stated |
| T3 | H2/H3/H4 leave no broken links | `git grep -n 'PLAN\.md\|steam-ui-investigation\|steam-ui-findings\|patch-inventory'` and open each hit — `PLAN.md#` has **0** hits today; every inbound reference is `§`-prose, and H3 breaks three: `docs/plans/retina-swapchain-experiment.md:22,24`, `scripts/steam-render-cell.sh:5`; `REFERENCES.md:39` ("P4 in PLAN.md") is already stale | every reference resolves or is rewritten |
| T4 | ledger gate | `python3 scripts/check-experiments.py` — **pre-registered:** the H2 banner is a blockquote line, not a `## ` heading, so the checker's section count stays 32 | exit 0 and "32 section(s)" unchanged |
| T5 | H3 triage is complete | every item in the old 284–564 span appears exactly once: as an issue number, or as a deletion with a pointer | 9 top-level + 18 nested = 27 dispositions |
| T6 | H1 headline | `git grep -c jvspearman -- CLAUDE.md` | 0; the accepted residual is exactly the dxmt-bugs hits listed in H1 |
| T7 | H3 issues are filed as the right account | `GH_CONFIG_DIR="$HOME/.config/gh-cs2" gh auth status` **before** the first `gh issue create`, and each created issue's `author.login` | `iosoceans` throughout — the dxmt#141 failure mode, gated this time |
| T8 | H4's counts are measured, not copied | count the `patch_*.py` invocations in `~/cs2-patch/repatch.sh` and those inside `ERRNO_PATCHES`/`COHTML_LICENSE` guards | 16 total, 6 errno-guarded, 10 on `dxmt11` (re-run, do not trust `CLAUDE.md`'s number) |

## Exit criteria
1. `CLAUDE.local.md` exists, is ignored, and is auto-loaded (T1); the public `CLAUDE.md` no
   longer names the personal account (T6); the residual mentions are listed, not discovered later.
2. H2 banner present; checker untouched; T3, T4 green.
3. `PLAN.md` under 250 lines with the H3 triage table applied; each still-real item has an issue.
4. H4, H5 done.

## Sequencing
Independent of the other four plans; any time.

## Rollback
Plain git revert of one commit; `CLAUDE.local.md` is untracked and stays.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-02 | 1 | correctness (repo facts, link census, checker constants) + Claude Code guide (the `CLAUDE.local.md` platform fact) | 2 agents, 12 tool calls | claude-fable-5-1 | `c94d9e9` | build-ready-with-fixes — no design change; two test measurements were wrong (T1, T3), H1 needed its residual-mentions decision and the brief's premise corrected, H3 three specifics and the counts, H4/H5 one line each. Folded. |
| 2026-09-02 | 1b | cross-plan test-plan audit | 1 agent, 10 tool calls | claude-fable-5-1 | `310e631c` | inadequate as written → fixed: T1 now a nonce sentinel with a negative control, T7 gates issue creation on the `gh` identity, T8 re-measures the patch counts. Folded. |
| 2026-09-02 | 2 (fitted re-check of the fold) | one agent over the rewritten sections, cites re-verified against the code and the trace | 1 agent, 11 tool calls | claude-fable-5-1 | `276f43d5` | build-ready-with-fixes — only cross-plan items re-checked (sequencing, status line); content stands on pass 1. **Cleared for build, any time.** |

**Key paths:** `CLAUDE.md` · `.gitignore` · `PLAN.md` · `docs/steam-ui-investigation.md` ·
`docs/patch-inventory.md` · `EXPERIMENTS.md` · `scripts/check-experiments.py`
