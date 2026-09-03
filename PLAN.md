# Open threads

Current stack: **self-built stock Wine 11.16 + DXMT**, promoted 2026-08-23 — 10 patches. Built by
`scripts/build-engine-1116.sh` from the official winehq source (the DXMT binaries and x86_64
dylibs are reused from a Porting Kit Wine11+DXMT wrapper, which remains the prerequisite install).
**Porting Kit Wine 11.0 + DXMT** is the storefront wrapper + parked fallback
(`CS2dxmt11-pk110.app` — `CS2 Steam Store.app` opens Steam there); **Wine 10
Sikarugir + D3DMetal** (`S734M.app`) is the older proven one. See `README.md` for how it works,
`INSTALL.md` §6 for the engine build, and `docs/patch-inventory.md` for the patch-by-patch
breakdown.

> **Pruned 2026-09-03** per `docs/plans/repo-hygiene-2026-09.md` § H3. Three closed sections and the
> 281-line "Known-unresolved" list collapsed to one disposition line each. **Nothing was discarded
> without naming where it now lives**: a closed thread points at the doc that holds it, a still-real
> one points at its GitHub issue. This file is a router now, not an archive.

## Closed — kept as pointers only

- **✅ SOLVED: the alt-tab freeze** (the headline defect since July). Fixed by the promoted Wine
  11.16 engine 2026-08-23 and confirmed in-game. Mechanism, the three eliminated hypotheses and the
  standalone reproducer: `GOTCHAS.md:464` § alt-tab · `docs/dxmt-bugs/DRAFT-focus-loss-freeze.md`;
  engine build + measured payoff (44.86 vs 42.7 FPS, presentation Direct):
  `docs/plans/build-wine1116-dxmt-engine.md`. **The one open decision is closed, not owed** —
  dxmt#206 was closed by the maintainer as a duplicate of
  [#183](https://github.com/3Shain/dxmt/issues/183), so the stock-source 11.16 game-level
  confirmation has no upstream home and nobody is waiting on it. Do not re-open it as a task.
- **✅ ADOPTED: retina / native swapchain** (2026-08-26, option 2 — no launcher change). As-built:
  `docs/plans/retina-swapchain-experiment.md`; the per-display profile that ships it (mobile =
  native + DRS 0.5 CAS · home = DRS off, native 1:1): `docs/plans/launcher-display-profiles.md`.
  **T10, the first real dock, was executed 2026-08-27** — the "one open item, fail-open until then"
  status this section used to carry is stale.
- **✅ Retired: "fix it upstream in Wine"** — retired for R1–R3 (R1 and R3 fixed upstream in Wine
  11.0, R2 disproven; table in `docs/wine-bugs/README.md`). Its closing line, *"nothing is left to
  file against Wine"*, has been **false since 2026-08-31**: the later filings
  [60262](https://bugs.winehq.org/show_bug.cgi?id=60262) (frameless-window decoration) and
  [60263](https://bugs.winehq.org/show_bug.cgi?id=60263) (cross-process child-window Metal
  swapchains) are tracked in `docs/wine-bugs/README.md`.

## Queued: mod keybinding alerts (James, 2026-08-24) — CLOSED pending one visual check

The ⚠ badges on mod rows in Options are a **boot-time notice armed from the mods' factory
defaults**, evaluated before the per-user `.coc` overrides apply — so the 2026-08-25 rebinds fixed
the real conflicts but could never clear the badge. Killed by a two-patch IL set on `Game.dll`
(P1 `SetModConflictNotification`, P2 `InputBindingField.get_warning`), applied and boot-verified
clean 2026-08-27; the launcher re-ensures it pre-boot (step 0b, fail-open), so a game update
self-heals.

**Remaining — the only reason this is still open:** James eyeballs Options → mod rows and confirms
no ⚠ anywhere, including Anarchy.

Detail, all of it recorded elsewhere: the offline collision table and the `.coc` edit protocol in
GOTCHAS § "Mod keybinding defaults are extractable offline" · the four invalid-IL rounds and the
rules they earned in GOTCHAS § "IL opcode surgery" · the patcher, its invocation and the launcher
hook in `CLAUDE.md` § Where things live · backups and timings in `~/cs2-patch/change-ledger.txt`.
**Left open by choice:** Anarchy's PageUp/Down triple-booking — no `Anarchy.coc` exists and minting
one from scratch is format-risk; one in-game rebind creates it properly.

## Performance: the deep optimization pass (RUNNING — P0–P2 measured 2026-08-24)

James, 2026-08-23: *"take a deep hard look at optimizing efficiency"* — serious token budget
approved. Plan + ethos: `docs/plans/perf-pass.md` (check-it'd; its as-built header is the authority
on what has shipped). Measured table: `docs/perf-pass-results.md`. Method + traps: GOTCHAS
(benchmark instrument, Settings.coc edit rule, resolution/upscaling closures).

**Done:** instrument discovered (the game's own `-benchmark` writes structured per-frame results;
`scripts/perf-bench.sh` runs autonomous cycles) · noise floor 1.03 FPS · resolution/upscaling
family closed by live adjudication · settings matrix measured autonomously via Settings.coc edits ·
**composed daily driver measured +11.6% avg / +55% 1%-low** (native + High SMAA + LOD 0.25 +
mipbias 0) — **applied, and ACCEPTED as the daily driver** (James, 2026-08-24, mid-play: *"things
look good … pretty solid"*). If looks ever outrank frames, LOD 0.25→0.5 buys it back for ~4.7 FPS.

**Remaining, unchanged since 2026-08-24:** P3 pacing cells (`preferredMaxFrameRate`, vsync
decision) · P4 late-game CPU cells (M0-L baseline + boot.config levers) · P5 ship (README numbers +
wiki draft — unblocked by the verdict, not yet done). Out of scope unchanged (DXMT rebuild,
alternative layers, Rosetta experiments); the MoltenVK dylib update is **cancelled** (2026-08-24,
disproven outright by the A/B against pk110).

## Report upstream to Paradox

`patch_lockleak` works around a genuine PdxSdk defect, not a Wine one:
`FileIO::CreateFileStream`'s state machine has two `catch` clauses and **no `finally`**, and the
catch handler never disposes the lock acquired at IL `0x78`/`0x82` — though the FileNotFound path at
`0x120` does. Any IO exception leaks that path's lock permanently; the next waiter dies on
`GetLockToken`'s timeout. Windows just rarely throws there, so it hides. Clean fix upstream: dispose
in the handler, or wrap in `finally`. Still unreported as of 2026-09-03; the write-up that would go
upstream is `docs/patch-inventory.md` §5 (patch 17).

## Known-unresolved, low severity — triaged 2026-09-03

Every item of the old 281-line list is below exactly once. **Issue** = still real, filed on the
tracker (📋 = filed, with its number). **Closed** = fixed or
superseded, with the pointer to where the surviving content lives.

### Still real

- 📋 **`home` profile assumes a ~1080p main panel.** [#2](https://github.com/macgameport/cities-skylines-2-macos/issues/2). The desk already carries a DELL
  U2720Q (27" 4K, 163 ppi) as the *portrait secondary*; making it `spdisplays_main` is a
  one-setting change that would put `home` at native 4K (~4× the tuned working point). Wants a new
  `home-hidpi` row giving 4K the *mobile* treatment (DRS 0.5 + CAS), re-benched not assumed.
- 📋 **`scripts/README.md` coverage drift.** [#3](https://github.com/macgameport/cities-skylines-2-macos/issues/3). Re-measured 2026-09-03: **25 of 63
  tracked source files documented, 38 unmentioned** (was 15 unmentioned on 2026-08-28 — it is
  getting worse, not better, as instruments land).
- 📋 **Fullscreen-toggle cursor desync.** [#4](https://github.com/macgameport/cities-skylines-2-macos/issues/4). Observed on wine 11.0, **never re-tested on
  the promoted 11.16 engine**; the whole defect class lived in the client-surface machinery 11.16
  reworked, so it may already be gone. Re-check before repeating the old "set Fullscreen and don't
  toggle" advice.
- 📋 **Rosetta horizon.** [#5](https://github.com/macgameport/cities-skylines-2-macos/issues/5). The stack is entirely x86-64 under Rosetta 2 and macOS 26
  surfaces a deprecation notice ([Apple 102527](https://support.apple.com/en-us/102527)). Apple's
  stated plan: full Rosetta through macOS 27, a reduced "older games" subset in 28+, no word on
  whether Wine-style use qualifies. Nothing to do today; plan-B territory around late 2027.

### Closed — where each one went

- **Metal HUD off in the double-clickable shortcut** (James, 2026-08-27, "for now"). Not a defect, a
  setting: per-run `CS2_HUD=1` is documented in `INSTALL.md` § the HUD and in `README.md`; baking it
  into the `.app` is `HUD=1 bash scripts/make-shortcut.sh` (the generator's `HUD_ENV` line).
- **~~Five `Game.dll.bak-modconflict-*` backups (~58 MB)~~** — pruned 2026-08-27, 58 MB → 12 MB. The
  one keeper is `Game.dll.bak-modconflict-20260827-164920`, byte-probed pristine at both patch
  sites; restoring it puts the DLL back to stock, and the launcher would re-apply on next boot, so
  move the patcher aside if you want stock to *stay*. Recorded in `~/cs2-patch/change-ledger.txt`.
- **Steam's visible UI** (the ~225-line sub-thread). **Superseded in full by
  [`docs/steam-ui-findings.md`](docs/steam-ui-findings.md)** — the same material as one causal
  story, with `EXPERIMENTS.md`'s register (C1–C30) as the authority on trust and
  `docs/steam-ui-investigation.md` as the raw chronology. Two bugs, not one: the font backend
  (ours, fixed) and a NULL dereference in DXMT (upstream, open). Upstream work is tracked by
  [issue #1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Its 23 sub-items:
  - **The 2026-08-30 VOID audit** (41 of 43 render cells ran with no font library) → `EXPERIMENTS.md`
    § index (`VOID-LIBS`) and the `void-ok:` convention; `docs/agent-brief.md` carries the rule.
  - **"Our 11.16 loses FreeType/gnutls/MoltenVK only under Steam"** → root cause found: `nohup` +
    macOS stripping `DYLD_*` across a SIP-protected exec. Findings § Bug 1; ledger C10.
  - **"Ruled out as the cause" list** (glyph atlas, GPU/OOP raster, subpixel, DirectWrite, fonts) →
    withdrawn by the same audit; the surviving eliminations are findings § "What has been eliminated".
  - **The DirectWrite-FreeType correction** (`nm`, never `strings` or file size) → moot once the
    font backend was fixed; the `nm` rule survives in GOTCHAS.
  - **The webhelper shim moved to `cef.win64`, compiled default empty** → live config fact, now in
    `CLAUDE.md` § Where things live (installed ≠ armed; a Steam update silently un-shims it).
  - **Productized two-wrapper split (`CS2 Steam Store.app`)** → `CLAUDE.md` § Where things live;
    the same-account session-swap behaviour is a GOTCHAS entry and a CLAUDE.md rule.
  - **Disk note: the pk110 game copy reclaimed 0 GB** → GOTCHAS § "`du` lies about disk on APFS".
  - **"It is in-process GPU by any route, not the flag"** → **DISPROVEN**, ledger C4: with fonts
    working, the same in-process config renders the storefront complete with text.
  - **Vanilla-wined3d split "TESTED AND DEAD" (08-28)** → the wiring was broken; retracted below.
  - **Split + `--disable-gpu --single-process` "CLOSED HARDER" (08-29)** → same retraction.
  - **The `dxgiprobe.c` partial retraction** → `scripts/dxgiprobe.c` kept; the measured numbers
    (wined3d `DXGI_ERROR_UNSUPPORTED`, FL 9_3 vs DXMT 11_0/11_1) are in findings + the register.
  - **"THE VALID TEST — DXMT beats vanilla wined3d at every cell"** → findings § "What has been
    eliminated"; the split is a downgrade, `scripts/make-vanilla-wrapper.sh` kept for a re-test.
  - **notpop's two ingredients (`-fvisibility=default` + a DXMT fork)** → overtaken: the winemac
    cross-process patch itself landed and renders. Findings § "Wall 1 is down"; wine 60263.
  - **The 4th dxmt#141 comment** → posted. Drafts and posted state for all **six** of this
    project's comments on that thread live in `docs/dxmt-bugs/` (each file records its own status).
  - **The "hold, do not post" note on `comment-141-split-plus-pair.md`** → **stale**: that file now
    records itself as POSTED, and the retraction and shimmer comments followed 2026-08-31.
  - **"Remaining untried: an older-CEF client pin"** → moot; both bugs are diagnosed and one is
    fixed, so pinning an older client answers nothing.
  - **Eliminated: `-cef-force-gpu`, `--use-angle=d3d9`** → findings § "What has been eliminated".
  - **The evidence/harness pointer** (`scripts/steam-render-cell.sh`, GOTCHAS §§) → superseded by
    the instruments list in `CLAUDE.md` § Where things live and findings § "Instruments, and the
    ones that lied".
  - **Revisit trigger 1 — a Steam client update** → moot for rendering (no shim needed; Steam
    renders out-of-process). The update caveat that survives is in `CLAUDE.md`'s webhelper-shim row.
  - **Revisit trigger 2 — dxmt#141 activity** → the thread is live and this project is on it;
    tracked by issue #1 and `docs/dxmt-bugs/`, not by a periodic check here.
  - **Revisit trigger 3 — a DXMT release** → tracked by issue #1's upstream plan set.
  - **Revisit trigger 4 — Wine 11.17+** → superseded by the actual filing, wine 60263.
  - **Revisit trigger 5 — an older-CEF pin** → same as the untried-route bullet above: moot.
- **Graphics settings must be set in-game.** Promoted to a standing rule — `CLAUDE.md` § Rules
  specific to this project ("Don't hand-edit `Settings.coc` for graphics") and GOTCHAS.
- **D3DMetal unsupported-API notices** (`NumClassInstances > 0`, `GetSharedHandle`, timestamp
  queries) at startup. One-time init messages, no observed impact, and **Wine 10 + D3DMetal only** —
  the default stack is DXMT and never prints them. Nothing to carry forward.

## Not worth doing

- **Reviving the DXVK/MoltenVK stack.** Archived in `archive/`. D3DMetal is stable where it was not.
- **CrossOver.** Licence expired 2026-08-21. The free stack matched it and then exceeded it.
- **`patch_pdxsdk_io`.** Masks failures instead of fixing them; breaks boot on empty mod state.
- **The four rejected lock patches.** All chased a deadlock that does not exist. See
  `docs/patch-inventory.md` §5.
