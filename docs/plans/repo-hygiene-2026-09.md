# Repo hygiene — identity section, archive, prune, headers, ledger wording

**Status: check-it'd 2026-09-03 — build-ready-with-fixes (pass 3, fitted re-check after the instruments build at `cc62ff8`; three test expectations, two H1 clauses and the `CLAUDE.md` cites corrected, no design change). Pass 2: check-it'd 2026-09-02 — build-ready-with-fixes (corrections folded, cross-plan consistency re-checked).** Umbrella:
[issue #1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: commit
`c94d9e9`. All items are mechanical; the plan exists so the two that carry a decision (H1, H2) are
decided once and the rest are done in one commit.

> **🔧 As-built (2026-09-03): BUILT — H1–H5 all applied.** Commit: `4874ef1` (built in the working
> tree; the session that commits should fill the SHA here). Deviations from the plan, all recorded
> in the same pass:
> 1. **`PLAN.md` "Queued: mod keybinding alerts" was compressed, not kept verbatim** (148 → 19
>    lines). H3's table says "keep; refresh status lines", but keeping 148 lines of a closed
>    chronology makes exit criterion 3 (`PLAN.md` < 250 lines) arithmetically impossible — the
>    faithful-verbatim build measured ~260. Every superseded entry is superseded *by a later entry
>    in the same section*; the durable content (mechanism, the two-patch IL set, the remaining
>    visual check, the deliberately-open Anarchy binding) is kept, and the detail is pointed at
>    GOTCHAS § "IL opcode surgery", GOTCHAS § "Mod keybinding defaults are extractable offline",
>    `CLAUDE.md` § Where things live and the change ledger. Result: **179 lines**.
> 2. **The `CLAUDE.md` pointer sits under a `## GitHub identity` heading**, not as a bare line — an
>    orphan line after the "Rules specific to this project" bullets reads as one of those bullets.
>    The heading carries no account name, so T2 (=1) and T6 (=0) are unaffected.
> 3. **T3 fixed two more inbound references than it named as broken:**
>    `docs/plans/retina-swapchain-experiment.md:22-25` (it cited a `§ "Retina / native-swapchain
>    experiment"` that never existed) and `REFERENCES.md:39` ("P4 in PLAN.md"). A third,
>    `scripts/steam-render-cell.sh:5`, cited `PLAN.md § "Steam's visible UI"` and was repointed at
>    `docs/steam-ui-findings.md` once the concurrent build released `scripts/`. `docs/plans/perf-pass.md:14`
>    was checked and still resolves — `PLAN.md:58` keeps that heading.
> 4. **H3's `scripts/README.md` count was re-measured and is worse than the plan's**: 25 of **63**
>    tracked source files documented, **38** unmentioned (the plan carried 25-of-40 / 15
>    unmentioned, measured 2026-08-28 before the instruments landed).
> 5. **`docs/patch-inventory.md`'s `Last verified` bump is qualified**, not a blanket re-date: the
>    targets and counts were re-measured 2026-09-03, the in-game verification behind §1 is still
>    2026-08-22, and the header now says both.
> 6. **The four still-real items are filed as [#2](https://github.com/macgameport/cities-skylines-2-macos/issues/2)
>    (home-hidpi profile), [#3](https://github.com/macgameport/cities-skylines-2-macos/issues/3)
>    (`scripts/README.md` drift), [#4](https://github.com/macgameport/cities-skylines-2-macos/issues/4)
>    (fullscreen-toggle cursor desync) and [#5](https://github.com/macgameport/cities-skylines-2-macos/issues/5)
>    (Rosetta horizon)**, linked from `PLAN.md` § Known-unresolved. The build session drafted them
>    without GitHub write scope; the session that filed them ran T7 first and each issue's
>    `author.login` is **`iosoceans`**.
>
> **Verify against:** `CLAUDE.md:56-60` · `CLAUDE.local.md` (untracked) · `.gitignore:5-9` ·
> `docs/agent-brief.md:62-65` · `docs/steam-ui-investigation.md:13-19` · `PLAN.md` (179 lines) ·
> `docs/patch-inventory.md:1-30` · `README.md:157,196` · `EXPERIMENTS.md:833`.

---

## H1 — the GitHub-identity section is in a public file

`CLAUDE.md` lines 56–86 (`## GitHub identity — this project is deliberately separated`; `## Experiments`
follows at :87 — the table above it grew a line in `cc62ff8`, so re-measure before cutting) name both
accounts and state that nothing publicly links them, in a public repo. The link is already
inferable from dxmt#141 (comments 5 and 6 continue the earlier account's thread), so this is a
consistency fix, not a leak response.

**Design.** Move the section verbatim to `CLAUDE.local.md` at the repo root, add
`CLAUDE.local.md` to `.gitignore` (matching the file's existing comment style), leave a one-line
pointer in `CLAUDE.md`: *"identity detail lives in the untracked `CLAUDE.local.md` — if that file
is absent you are on a clone or a git worktree: do not push or post until identity is set up; the
`gh` invocation rule is `docs/agent-brief.md` § If you run gh"* — the brief keeps the
`GH_CONFIG_DIR="$HOME/.config/gh-cs2"` line (a path, not an account) and is what subagents are
handed. Reword `CLAUDE.md:104-105`: drop the `GH_CONFIG_DIR` clause (it cites "the `GH_CONFIG_DIR`
requirement" as if it still lived in this file) **and** replace "A subagent inherits none of this
file" with "gets this file and the memory index but not the conversation, the memory bodies or the
shortcuts — hand it the brief anyway, or it re-raises settled findings", so `CLAUDE.md` stops
contradicting `docs/agent-brief.md:3-5`. **Residual public mentions, left deliberately:** the earlier account's name stays in
`docs/dxmt-bugs/comment-141-fifth-retraction.md:5,14-15,215-216` and
`comment-141-sixth-shimmer.md:5-6` — they document a public thread whose authorship is visible on
GitHub anyway — and this plan's own T6/T7 rows (`docs/plans/repo-hygiene-2026-09.md`), which must
name the literals to be executable. **Premise correction for `docs/agent-brief.md:3-5` — done in `a94903c`** (the brief now says
a subagent receives the project `CLAUDE.md` and the memory index, not the conversation or the
memory bodies). Still to write, one clause in the brief: a reader without `CLAUDE.local.md` is a
fresh clone or a **git worktree** — the gitignored file exists only in the worktree that created
it, and this harness offers worktree-isolated subagents — not a same-session subagent; the `gh`
rule in the brief covers the mechanics either way. **Platform fact, verified 2026-09-02 by the Claude Code guide lens against
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

**Design: do not move it.** Extend the opening blockquote (`:3` ff.; "read the index first" at `:8`) (which already says
"read the index first" but never names `steam-ui-findings.md`) with an ARCHIVE line: "the raw
chronology; read `steam-ui-findings.md` first; kept in place because the ledger checker scans its
status banners". Leave the checker alone. Cheaper and no link churn; the "archive" is a label.

## H3 — `PLAN.md` (571 lines)

| section (lines) | disposition |
|---|---|
| `✅ SOLVED: the alt-tab freeze` (12–62) | delete; pointer line to `GOTCHAS.md:464` § alt-tab, `docs/dxmt-bugs/DRAFT-focus-loss-freeze.md` and `docs/plans/build-wine1116-dxmt-engine.md`. **The open decision at `:41-44`** (a game-level confirmation on dxmt#183, "James's call") gets an explicit disposition: memory records it as closed-not-owed (#206 was closed as a dup of #183); write that, or open an issue |
| `✅ ADOPTED: retina` (239–260) | delete; pointer to `docs/plans/retina-swapchain-experiment.md` (as-built) **and** `docs/plans/launcher-display-profiles.md`; the `:256-260` ship note still says "T10 open" — T10 closed 2026-08-27, say so |
| `✅ Retired: fix it upstream in Wine` (261–274) | delete; pointer text "retired for R1–R3; later filings (60262, 60263) are tracked in `docs/wine-bugs/README.md`" — `:272-273` "nothing is left to file against Wine" is false since 2026-08-31 |
| `Known-unresolved, low severity` (284–564, 281 lines) | **triage, do not bulk-move.** Measured: **9 top-level items + 18 nested bullets + 5 nested numbered re-check triggers (`:508–:543`), all under item 5** (Steam's visible UI, `:322–546`, ~225 lines, superseded by `docs/steam-ui-findings.md` + the ledger). The other eight: home-profile 1080p assumption · `scripts/README.md` 25-of-40 coverage · Metal HUD off · ~~Game.dll.bak~~ (already struck) · fullscreen-toggle cursor desync (untested on 11.16) · graphics-in-game rule (already in CLAUDE.md) · D3DMetal API notices (Wine 10 only) · Rosetta horizon. Each gets one line: still real → GitHub issue; superseded / fixed → deleted with a pointer |
| `Queued: mod keybinding alerts`, `Performance: RUNNING`, `Report upstream to Paradox`, `Not worth doing` | keep; refresh status lines |

## H4 — `docs/patch-inventory.md` header

Describes only the Wine 10 stack. Add the default `dxmt11` target (10 patches, no licence bypass)
above it, add `dxmt11` to the `Applied by:` line, keep the Wine 10 block as the fallback, bump
`Last verified` — and fix `:11` in the same edit: "retires 7 of the 17" contradicts the measured
16 total / 10 on `dxmt11` / 6 errno (`CLAUDE.md`: "the old 17 counted the cohtml warning").

**Also (pass 3):** `README.md:157` ("All 17 binary patches") and `:196` ("7 of the 17 patches")
repeat the count H4 corrects, and T3's grep surfaces `:157` — fix both in the H4 edit.
`docs/wine-bugs/README.md:9` and `FINDING-wine11-fixes-it.md:46,158,247` also say 17: dated
findings, keep the historical count (decided here, not rediscovered).

## H5 — ledger C2 wording

C2 (`PARTIAL`) describes the geometry-less child patch of 2026-08-29. Keep the row and status (a
measurement is never deleted) **and keep its `**void-ok:**` marker** — `check-experiments.py:181-188`
exempts a claim resting on VOID cells only if the row text contains it; dropping it turns T4 red.
Reword the notes to "superseded for the current build by C12–C30; the 2,588,759 B composite
measurement stands as the first proof the route composites".

---

## Test plan

| # | test | method | pass |
|---|---|---|---|
| T1 | H1 loads | in a fresh `claude` session run `/context` first — it lists the loaded files under **Memory files** (cheap positive control) — then put a **nonce sentinel** (a random word) in `CLAUDE.local.md`; in a fresh `claude` session in the repo ask for the nonce; then rename the file and ask again (negative control). Asking about `GH_CONFIG_DIR` would prove nothing — `docs/agent-brief.md:58`, two `docs/dxmt-bugs/` files and auto-memory all carry it | nonce returned with the file present, unknown with it renamed; `git check-ignore -v CLAUDE.local.md` prints the rule and `git ls-files CLAUDE.local.md` is empty (an ignored file is *invisible* in `git status`) |
| T2 | H1 pointer present and the brief unchanged | `grep -c 'CLAUDE.local.md' CLAUDE.md` = 1 and `git grep -n GH_CONFIG_DIR -- ':!CLAUDE.local.md'` lists only `docs/agent-brief.md`, the two `docs/dxmt-bugs/` files and this plan (its H1/T7 rows); `CLAUDE.md` drops out once `:104` is reworded | counts as stated |
| T3 | H2/H3/H4 leave no broken links | `git grep -n 'PLAN\.md\|steam-ui-investigation\|steam-ui-findings\|patch-inventory'` and open each hit — `PLAN.md#` has **0** hits outside this plan today (a literal re-run returns this row); every inbound reference is `§`-prose, and H3 breaks three: `docs/plans/retina-swapchain-experiment.md:22,24`, `scripts/steam-render-cell.sh:5`; `REFERENCES.md:39` ("P4 in PLAN.md") is already stale | every reference resolves or is rewritten |
| T4 | ledger gate | `python3 scripts/check-experiments.py` — **pre-registered:** the H2 banner is a blockquote line, not a `## ` heading, so the checker's note line stays at its pre-build value — `GOTCHAS.md + steam-ui-investigation.md: 82 section(s), 37 carry a … banner` at `cc62ff8` (49 + 33; the 32 is only interpolated into the *failure* message); re-baseline if another plan's GOTCHAS edit lands first | exit 0 and the note line identical to the pre-build run |
| T5 | H3 triage is complete | every item in the old 284–564 span appears exactly once: as an issue number, or as a deletion with a pointer | 9 top-level + 18 nested bullets + 5 nested numbered triggers = 32 dispositions (28 if the five-trigger list is dispositioned as one unit — say which) |
| T6 | H1 headline | `git grep -c jvspearman -- CLAUDE.md` | 0; the accepted residual is exactly the dxmt-bugs hits and this plan's T6/T7 rows, as listed in H1 |
| T7 | H3 issues are filed as the right account | `GH_CONFIG_DIR="$HOME/.config/gh-cs2" gh auth status` **before** the first `gh issue create`, and each created issue's `author.login` | `iosoceans` throughout — the dxmt#141 failure mode, gated this time |
| T9 | no retracted SceneFlow claim in the two files H1 edits | `git grep -n -i flush -- CLAUDE.md docs/agent-brief.md` (both carried "flushed on graceful exit" until 2026-09-03; SceneFlow.log is written live — GOTCHAS 2026-09-03) | 0 hits |
| T8 | H4's counts are measured, not copied | count the `^python3` invocations of `patch_*.py` in `~/cs2-patch/repatch.sh` (a loose `patch.*\.py` grep returns 17 because `:138` is a comment about `patch_pdxsdk_io.py` being deliberately not run) and those inside the `ERRNO_PATCHES` guard (`:81–:102`; the `COHTML_LICENSE` block at `:75-78` holds only the warning, no `.py`) | 16 total, 6 errno-guarded, 10 on `dxmt11` (re-run, do not trust `CLAUDE.md`'s number) |

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

## Review corrections (triple-check 2026-09-03, pass 3 — fitted re-check after the instruments build)

Trigger: `cc62ff8` edited files this plan cites (`CLAUDE.md` table +1 line, `GOTCHAS.md` +2 sections,
`docs/agent-brief.md` +1 bullet). One agent re-measured every cite and count at HEAD, re-fetched
the `CLAUDE.local.md` platform doc, executed T4 and re-counted T8. No design change. Folded: the
`CLAUDE.md` section is `:56–86` and the reword target `:104-105` (which also carries the "inherits
none of this file" premise the brief already corrected in `a94903c`); the H1 premise paragraph now
records that fix and the worktree case; the pointer text covers the file-absent case; the residual
list includes this plan's own T6/T7 literals; T2's expected list includes this plan; T4 names the
note line the green run actually prints (82 / 37), not the 32 that only appears on failure; T5 and
the H3 row count the five nested numbered triggers (`PLAN.md:508–543`); T3 says "outside this plan";
T8 counts `^python3` lines and puts all six guarded patches under `ERRNO_PATCHES`; H2's blockquote
cite, H5's `C12–C30`, T1's `agent-brief.md:58` and a `/context` positive control; H4 gains the two
`README.md` lines; T9 gates the retracted SceneFlow claim out of the two files H1 edits.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-09-02 | 1 | correctness (repo facts, link census, checker constants) + Claude Code guide (the `CLAUDE.local.md` platform fact) | 2 agents, 12 tool calls | claude-fable-5-1 | `c94d9e9` | build-ready-with-fixes — no design change; two test measurements were wrong (T1, T3), H1 needed its residual-mentions decision and the brief's premise corrected, H3 three specifics and the counts, H4/H5 one line each. Folded. |
| 2026-09-02 | 1b | cross-plan test-plan audit | 1 agent, 10 tool calls | claude-fable-5-1 | `310e631c` | inadequate as written → fixed: T1 now a nonce sentinel with a negative control, T7 gates issue creation on the `gh` identity, T8 re-measures the patch counts. Folded. |
| 2026-09-02 | 2 (fitted re-check of the fold) | one agent over the rewritten sections, cites re-verified against the code and the trace | 1 agent, 11 tool calls | claude-fable-5-1 | `276f43d5` | build-ready-with-fixes — only cross-plan items re-checked (sequencing, status line); content stands on pass 1. **Cleared for build, any time.** |
| 2026-09-03 | 3 (fitted re-check after the instruments build) | correctness (every cite re-measured at HEAD; T4 executed, T8 re-counted) + platform-fact (`CLAUDE.local.md` doc re-fetched) + test-plan executability | 1 agent, 14 tool calls | claude-fable-5-1 | `cc62ff8` | build-ready-with-fixes — no design change; three expected values were wrong (T2 omitted this plan's own hits, T4 named a count the green run never prints, T5 missed 5 nested numbered items), two H1 clauses stale (premise fix already shipped in `a94903c`; "not a subagent" is false for worktrees), `CLAUDE.md` cites +1, and both files H1 edits carried the retracted "flushed on exit" claim (fixed the same day; T9 gates it). Folded above. |

**Key paths:** `CLAUDE.md` · `.gitignore` · `PLAN.md` · `docs/steam-ui-investigation.md` ·
`docs/patch-inventory.md` · `EXPERIMENTS.md` · `scripts/check-experiments.py` · `docs/agent-brief.md` · `README.md`
