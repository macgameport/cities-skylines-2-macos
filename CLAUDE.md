# Claude Instructions — cs2 (macOS CS2 port notes)

Personal-tier project: **no phases, no SPEC.md** — but **GitHub Issues are enabled** (corrected
2026-09-02; this line used to say "no issue tracker"). Use them for umbrella/multi-item work and
anything a future session must not lose; single mechanical fixes still go straight to a commit.
Durable record = this repo + its issues + `~/cs2-patch/change-ledger.txt`.

## Where things live

| What | Path |
|---|---|
| Patch scripts + ledger | `~/cs2-patch/` (**outside this repo**, deliberately) |
| Canonical launcher (**default**) | `~/cs2-patch/launch-cs2-dxmt11.sh` — Wine 11 + DXMT. Repo copies are thin wrappers (macOS TCC blocks app bundles from executing scripts in `~/Documents`) |
| Canonical launcher (fallback) | `~/cs2-patch/launch-cs2.sh` — Wine 10 + D3DMetal |
| Display-profile helper | `~/cs2-patch/cs2-display-profile.sh` — the dxmt11 launcher runs it pre-boot: retina + DRS per *main* display (mobile = retina on + DRS 0.5 CAS · home/external = retina off, native 1:1). `CS2_PROFILE=off\|home\|mobile`, `DRY=1` preview. Repo original: `scripts/`; design: `docs/plans/launcher-display-profiles.md` |
| Apply all patches | `bash ~/cs2-patch/repatch.sh dxmt11` (**10** patches) · `… free` (**16**, Wine 10 — and that target only *warns* about the unpublished cohtml licence bypass, it cannot apply it, so it reaches no main menu) · no arg = the dead CrossOver bottle. Counted 2026-08-30: 16 `.py` invocations total, 6 of them behind `ERRNO_PATCHES` which `dxmt11` sets to 0. The old "17" counted the cohtml warning as a patch. |
| Badge patch (**`Game.dll`, outside repatch.sh**) | `~/cs2-patch/patch-modconflict-badge.py` — kills the per-boot mod keybind ⚠ badges; the dxmt11 launcher re-ensures it pre-boot (step 0b, fail-open), so a game update self-heals. Run via `~/cs2-patch/revenv/bin/python3`; no args = verify, `apply` = patch (refuses unless the game is down). Repo original: `scripts/`; mechanism + the IL rules it earned: `GOTCHAS.md` |
| Shortcut | `~/Applications/Cities Skylines II.app` → runs the **dxmt11** launcher with `CS2_QUIET=1`. Revert = one `SCRIPT=` line in `Contents/MacOS/launch` |
| Store shortcut | `~/Applications/CS2 Steam Store.app` → opens Steam **visibly** in the storefront wrapper (`CS2dxmt11-pk110.app`, wine 11.0 — the 11.16 engine black-screens Steam's UI). Built by `scripts/make-steam-shortcut.sh` (also creates the wrapper by APFS clone if absent) |
| Webhelper shim (**in the daily prefix**) | `<prefix>/drive_c/Program Files (x86)/Steam/bin/cef/`**`cef.win64`**`/steamwebhelper.exe`, original kept beside it as `steamwebhelper_real.exe`. Compiled default is **empty** — installed is NOT armed; a cell asks for switches via `SHIM_ARGS`. A Steam client update restores the original and silently un-shims it. Install/revert: `scripts/install-webhelper-shim.sh [--revert]` |
| Game prefix (default) | `~/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix` |
| Game prefix (fallback) | `~/Applications/S734M.app/Contents/SharedSupport/prefix` |
| Game logs | `<prefix>/drive_c/users/Wineskin/AppData/LocalLow/Colossal Order/Cities Skylines II/` (the other user dirs in the prefix are symlinks to `Wineskin`) |
| Agent brief | `docs/agent-brief.md` — hand to every subagent; they inherit no auto-loaded memory |
| Experiment ledger | `EXPERIMENTS.md` — conclusions register + run index. Read the register at `wake up`; `python3 scripts/check-experiments.py` at `button up` |
| Evidence store | `~/cs2-patch/evidence/<cell>/` (**outside this repo** — window PNGs carry the persona name). `/tmp/steam-cell-*` is volatile; `scripts/salvage-cells.sh` moves + sanitises |
| Boot-verify (**the** way to prove the game boots) | `scripts/boot-verify.sh` — launcher → dwell → `WM_CLOSE` → judge `Logs/SceneFlow.log` (written live; only `GameManager destroyed` is exit-only). Prints `GRACEFUL: yes\|no` and one `VERDICT: PASS\|FAIL\|VOID` line; the exit code follows (2 = refused, the prefix is busy). **Run it detached with a log** — a tool timeout kills the process group and Steam with it. `--selftest` = every judge branch, no launch. Run dirs: `~/cs2-patch/boot-verify/` (outside the evidence store on purpose: the ledger checker treats every store dir as a cell) |
| Resize instruments | `scripts/win-resize-driver.c` (exact `SetWindowPos` sizes, **per-monitor DPI aware** so odd raw sizes are reachable; `tree`, a signal-free `close`, and `move <hwnd> <dx,dy>` — a **delta in the parent's client space**, cross-process; output is LF since 2026-09-03 but callers keep `tr -d '\r'` because the gitignored `.exe` can be older than the source) + `scripts/pixel-probe.swift` (edge-vs-interior RGB — a 1-device-pixel seam does not survive a screenshot; `strip <x> <w>` = mean RGB of a column band; refuses images under 24 px). Build lines are in each file's header; deploy the driver to `~/cs2-patch/win-resize-driver.exe` |
| RE toolchain | `~/cs2-patch/revenv` (dnfile + capstone + pefile) |
| Disassemble | `~/cs2-patch/revenv/bin/python3 ~/cs2-patch/dis_pdx.py <dll> <Type> <Method>` |

## Rules specific to this project

- **Never edit a `launch-cs2*.sh` (or `cs2-display-profile.sh`) while the game is running.** Bash
  reads scripts incrementally; a mid-run edit shifts byte offsets and corrupts the parse
  (produces a bogus syntax error).
- **Several wrappers legitimately run Steam at once** (dxmt11 + store wrapper + S734M). Never
  attribute a Steam process by COMMAND LINE: webhelper children always carry Windows-style argv,
  and a steam.exe restarted by its own updater does too — a `pgrep -f "<App>.app.*steam.exe"`
  sweep missed a live logged-in Steam (2026-08-24). Attribute by open files against the PREFIX:
  `lsof -p <pid> | grep -q "<prefix>"`; the launchers' `steam_exe_up`/`steam_family` helpers are
  the reference (prefix, not wine dir — an engine can serve a foreign prefix).
- **Same-account Steams swap ONE online session** ("Session Replaced"); the running game survives
  the swap and takes the session back on its next launch (GOTCHAS 2026-08-24). A store wrapper
  showing NO CONNECTION mid-game is correct behavior, not a bug.
- **Never `kill -9` Steam.** It leaves a 0-byte `.crash` marker that makes the next launch exit 1.
  Use `steam.exe -shutdown`; fall back to `WINEPREFIX=<prefix> wineserver -k`. The launcher clears
  a stale `.crash` on startup.
- **Don't hand-edit `Settings.coc` for graphics.** Flipping `enabled` without the accompanying
  parameters yields an "on but zeroed" profile the game reports as `Custom` and won't restore
  across a display-mode change. Set graphics in-game.
- **Judge runs by timestamp.** Only read a run whose `SceneFlow.log` first line postdates the change.
- **Check disk, not the UI**, for anything mod-related.
- Boot-verify after touching `mscorlib` — it's on the boot path.

## GitHub identity

Identity detail lives in the untracked `CLAUDE.local.md` — if that file is absent you are on a
clone or a git worktree: do not push or post until identity is set up; the `gh` invocation rule is
`docs/agent-brief.md` § If you run `gh`.

## Experiments — read the ledger before designing a test (2026-08-30)

**`EXPERIMENTS.md` is the standing record of what we have tested and how much to trust it.**
`GOTCHAS.md` holds *patterns*; the ledger holds *runs, their config, and the claims resting on
them*. They are different jobs — do not merge them.

- **`wake up`** — read the ledger's **Conclusions register** (the `C<n>` table). Not the whole
  file, and never `GOTCHAS.md` whole. It is the index of what is already settled, `PARTIAL`,
  `UNREVIEWED`, or `RETRACTED`, so a session does not re-run a finished experiment or build on a
  withdrawn one.
- **`button up`** — run `python3 scripts/check-experiments.py`. It exits non-zero on drift and is
  the freshness gate: unrecorded cells, evaporated evidence, stale counts, any `SUPPORTED`/`PARTIAL`
  claim resting on a run the evidence marks VOID, dangling `exp_` references, and any GOTCHAS status
  banner that disagrees with the register. **Conventions are enforced there, not by memory** — see
  `EXPERIMENTS.md` § Conventions before inventing a format.
- **Spawning a subagent?** Point it at **`docs/agent-brief.md`** first — one screen carrying the
  evidence rules, the process-attribution and `kill -9` traps, the exit-code trap and the privacy
  rules. A subagent gets this file and the memory index but not the conversation, the memory
  bodies or the shortcuts — hand it the brief anyway, or it re-raises settled findings.
- **Every render cell runs `scripts/cell-fingerprint.sh --strict` first.** It records the config
  beside the result and refuses the run on a precondition that would void it. A cell without a
  `config.json` is `UNREVIEWED`, not a result.
- **Three columns, never fused: Config · Measured · Inferred.** When a premise falls, retract the
  *inference* and keep the *measurement*. Fusing them into prose is what cost a week.

**Why (the incident):** on 2026-08-30 an audit found **41 of 43** render cells had run with no font
library — wine could not resolve `libfreetype.dylib`, printed one line, and continued with no font
backend, which renders art and no glyphs. A week had gone into eliminating fonts, rasterisation,
texture formats, occlusion and compositing. Two more confounds sat in the same runs: the shim was
installed in a `cef` dir Steam does not use (so `--shim-args` silently never applied), and the
harness's `ps`/window capture were not prefix-filtered, so another wrapper's Steam could supply a
**false PASS**. None were detectable afterwards, because nothing recorded the config a result was
measured under.

## ⛔ DXMT does not accept AI-authored contributions (2026-08-31)

`CONTRIBUTING.md` in 3Shain/dxmt: *"We cannot accept contributions made or co-authored by AI/LLM…
You are still free to use AI to do your own research and share your findings with others (including
the developers, but **please don't create a PR**)."*

**So: never open a PR against dxmt from this project** — but a **comment is explicitly permitted**,
and is the right channel. Read the policy precisely: the only prohibition is the PR; *"share your
findings with others (including the developers)"* is in the same sentence, allowed. The diagnosis is
the valuable part and a maintainer can write the code from it.

**Disclosure is what makes this legitimate.** Say plainly, up front, that the research was
AI-assisted, so the maintainer can apply their own policy with full information instead of guessing.
Concealing it would be the actual violation. And describe the change with exact locations rather than
pasting a diff and asking them to apply it — that is a PR wearing a comment's clothes. Applies to the cross-process fix, the geometry fix, the
leak fix and the #25 style work alike. Detail: `docs/dxmt-bugs/issue-25-housekeeping-outline.md`.

Related, [#152](https://github.com/3Shain/dxmt/issues/152): new changes are LGPL-2.1-or-later, a CLA
is planned but does not exist, and a maintainer has asked that code changes pause until relicensing
completes. Wine is a **separate** project with its own process — this rule does not speak for it.

## Personal info

Repo is intended to be publishable. Keep Steam IDs, `[U:1:<n>]` account ids, real usernames and
absolute `/Users/<name>` paths **out of committed files** — use `$HOME`, `$WINEUSER`, `<REDACTED>`.

**Test artifacts (audited 2026-08-30 — full table in `EXPERIMENTS.md` § Privacy):**

- `stdout.txt` / `windows.txt` — verified clean (only `C:\` / `Z:\` wine-internal paths). Quotable.
- `win-*.png` — Steam client windows carry the **persona name twice** (top-right, and as a nav
  item) plus the avatar. Evidence store only, **never committed unmasked**.
- `known-good.png` — a capture of whatever browser/terminal window was frontmost. **Not retained**;
  only its byte size is. It is the largest accidental-disclosure surface in the harness and its
  only datum is "the capture worked". `scripts/salvage-cells.sh` drops it automatically.
- Evidence lives in **`~/cs2-patch/evidence/`**, outside the repo, same reasoning as
  `change-ledger.txt`. `/tmp` is volatile — salvage before a reboot eats the week's evidence.
- ⚠ **Committed images are gated by [`docs/images/AUDIT.md`](docs/images/AUDIT.md)** — a row per
  image saying what is visible, plus its sha256 prefix, enforced by `check-experiments.py`. A new
  image with no row, or one replaced since its audit, fails `button up`. All **four** were audited
  2026-08-30 and are clean.
  The two Steam captures among them are clean only because the glyph bug was active — Steam rendered
  no text, so there was no persona name to leak — and that would have expired the moment glyphs work.
- ✅ **Handled at source 2026-08-30: the Steam persona is now a generic placeholder.** The name is a
  *label*, freely editable, so this cost nothing; and it is **account-level**, so it lands in the
  native macOS Steam app and all three wine wrappers alike, protecting captures **whether or not text
  renders**. Verify it in the **native macOS app** — no wine, so the check can't be confounded by our
  own rendering bugs (and a rendered-text shot from there says nothing about wine's glyph handling).
  Don't rename back while capture work continues, and don't re-propose this — it is done.
  Not retroactive: pre-rename captures in `~/cs2-patch/evidence/` still carry the real name, which is
  precisely why that store sits outside the repo. Captures stay there unless deliberately promoted.
  Never mask: a mask you got wrong is worse than no mask.
- **Cheapest durable fix:** the Steam persona name is a *label*, freely editable. Set it to
  something generic while doing capture work and new captures are clean at source. A mask you got
  wrong is worse than no mask, because it looks safe.

## Escalate the model tier by SURFACE, not by task (2026-09-03, provisional)

**Where a gate can decide it, the tier barely matters. Where prose is the deliverable and no gate
can check it, use the most capable model.**

Measured on 2026-09-03, one session, both directions:

- **Execution found the behavioural defects, at any tier.** Three hunks carrying vendor context
  rather than the predicted two, `assert()` baking `__LINE__` into the object so a comment-only
  edit is not byte-identical, a probe leaking a running churn on its abort path, the exact anchor
  a relocated hunk needs. Every one surfaced from a build, a mutant or a byte-compare. The gate was
  the reviewer.
- **The top tier found the latent inconsistencies, which no gate can reach.** A plan asserting a
  131-entry unixlib table that is really 132 — its own test gate would have failed red for the
  wrong reason; an install step whose `codesign` contradicted the same plan's `cmp` outcome test; a
  test stating a pass condition absent from the tool's vocabulary; cites off by one after a table
  grew; five nested items missed in a census. All are cross-referencing work: hold a lot of material
  in mind, check it against the code and against itself.

**So:** `check it` lenses, and any audit of prose a human will act on that no test verifies, get the
top tier. Execution-gated work gets whatever is cheapest — the mutant is the reviewer, not the model.

**The label:** GitHub label `needs-high-tier-review` marks the judgment surface; `blocker` marks
what it holds up. First use: [#6](https://github.com/macgameport/cities-skylines-2-macos/issues/6),
comment accuracy in the published winemac reference, where `strip-comments.py`, the object
comparison and the whole C29 battery all pass while saying nothing about whether the surviving
comments are TRUE.

**Second instance, same repo (2026-09-03).** The `check it` on `exposed-edge-live-resize.md` ran six lenses at Fable 5.1, then one fitted Opus 5 agent over the *fold*. The fitted pass found a blocker no gate could reach: a test's pass condition named the wrong band and the wrong black-threshold for a signature measured two sections earlier, so **its mutant could never be observed red** while the exit criteria demanded it red. Pure cross-referencing — the plan against itself. Consistent with the rule; one repo *at that point*, so still provisional.

**First sibling adoption (homeOne, 2026-09-03) — repo 2.** homeOne took the rule and the `needs-high-tier-review` label for its Metal↔LLM upstream-contribution umbrella ([jvspearman/homeOne#66](https://github.com/jvspearman/homeOne/issues/66)). It is a useful second data point because the split there is unusually clean and runs *both* ways: the benchmark sweep (#68) is gated hard by Lily's 64-token-digest contract — no model talks past a digest mismatch — while the baseRT track (#69) has **no gate anywhere**, being prose argued on a third party's tracker. The label went on the surfaces, not the tickets, which is the part that most needs restating: two of the three issues carry both halves at once. Not yet evidence *for* the rule (nothing has been reviewed under it there yet) — evidence that it transfers to a repo with no build, no tests and no compiler.

**Second sibling adoption (isnotus, 2026-09-03) — repo 3.** Fitted, not copy-pasted: its sharpest
ungated surface is **Metis/Notus prompt and tool-description text** — a test proves a prompt does
not crash and a tool is reachable, nothing proves the wording steers the agent correctly over real
family data — plus anything the kids read, the news feed having been live since 2026-08-10. It
also drew the line this rule most needs drawn twice: privacy *policy* reasoning is judgment
surface, while the `visible_to_metis` filter that enforces it is gated.

⚠ **Three adoptions, zero confirmations — NOT promoted, and the distinction is the point.**
The count that the cross-repo sweep rule gates on is repos where a convention *fits*, and on that
reading the bar is met. But this rule's own text asks for evidence it **held**, and nothing has
been reviewed under it in either sibling yet. So the honest state is: the rule has proven it
**transfers** — to a repo with no build, no tests and no compiler (homeOne), and to one whose
riskiest output is prose aimed at an LLM and at children (isnotus) — and has proven nothing about
whether it **works** outside this repo. Promotion to `~/.claude/rules/` is James's call; the
mechanical bar is met and the evidentiary one is not. **Do not let a third copy be mistaken for a
third data point.**

## Deliberate deviations from sibling-repo practice

- **`.claude/rules/` in `.prettierignore`** (from meritmap, declined 2026-08-26) — Python / C / shell (20 py, 17 sh, 16 c); no package.json anywhere, so prettier can never run here. The guard exists because a repo `.prettierrc` whose `printWidth` differs from the global source's default 80 makes format-on-commit fight the session-start sync forever (diagnosed in meritmap, where it had run since 2026-08-14). Adopted in bespoke-tr, isnotus and homeOne, which have a JS toolchain that could grow a `.prettierrc`. Here it would configure a tool that will never exist. **Revisit if this repo ever gains a `package.json`.**
