# Claude Instructions — cs2 (macOS CS2 port notes)

Personal-tier project: **no phases, no SPEC.md** — but **GitHub Issues are enabled** (corrected
2026-09-02; this line used to say "no issue tracker"). Use them for umbrella/multi-item work and
anything a future session must not lose; single mechanical fixes still go straight to a commit.
Durable record = this repo + its issues + `~/cs2-patch/change-ledger.txt`.

## Where things live

| What | Path |
|---|---|
| Patch scripts + ledger | `~/cs2-patch/` (**outside this repo**, deliberately). ⚠ `repatch.sh` runs `~/cs2-patch/patches/*.py` (= this repo's `patches/`); the old top-level `patch_*.py` were moved to `~/cs2-patch/old-patchers/` 2026-10-10 (its README says which are stale, duplicate, or the only copy) |
| Canonical launcher (**default**) | `~/cs2-patch/launch-cs2-dxmt11.sh` — Wine 11 + DXMT. Repo copies are thin wrappers (macOS TCC blocks app bundles from executing scripts in `~/Documents`) |
| Display-profile helper | `~/cs2-patch/cs2-display-profile.sh` — the dxmt11 launcher runs it pre-boot: retina + DRS per *main* display (mobile = retina on + DRS 0.5 CAS · home/external = retina off, native 1:1). `CS2_PROFILE=off\|home\|mobile`, `DRY=1` preview. Repo original: `scripts/`; design: `docs/plans/launcher-display-profiles.md` |
| Apply all patches | `bash ~/cs2-patch/repatch.sh` (**10** patch scripts; `dxmt11` is the same) · `CS2_ERRNO_PATCHES=1 bash ~/cs2-patch/repatch.sh` (**16**, for an engine with the errno defect) · a game folder as the argument. It prints `<n> of <expected> patch scripts finished without error` and names any that failed |
| Badge patch (**`Game.dll`, outside repatch.sh**) | `~/cs2-patch/patch-modconflict-badge.py` — hides the per-boot mod keybind ⚠ badges. **Opt-in since 2026-11-09** (`setup.sh --hide-mod-badges` / `--show-mod-badges`; marker `patches/.mod-badges-on`); where it is installed the dxmt11 launcher re-ensures it pre-boot (step 0b, fail-open), so a game update self-heals. Run with `python3`; no args = verify, `apply` = patch (refuses unless the game is down). Repo original: `scripts/`; mechanism + the IL rules it earned: `GOTCHAS.md` |
| Shortcut | `~/Applications/Cities Skylines II.app` → runs the **dxmt11** launcher with `CS2_QUIET=1`. Revert = one `SCRIPT=` line in `Contents/MacOS/launch` |
| Store shortcut | `~/Applications/S734M.app`, the Windows Steam (called `CS2 Steam Store.app` until 2026-11-10; the S734M wrapper that had the name goes to the Trash first, in the plan's live step 2) → opens Steam **visibly** in the storefront wrapper (`CS2dxmt11-pk110.app`, wine 11.0 — the 11.16 engine black-screens Steam's UI). Built by `scripts/make-steam-shortcut.sh` (also creates the wrapper by APFS clone if absent), which replaces only a bundle it generated itself |
| Window of every game | `~/Applications/14unch3r.app`, built by `common/make-launcher-app.sh`, which `scripts/setup.sh` runs. It lists the apps that carry `L1Role` in their `Info.plist` and opens the chosen one; plan `docs/plans/launcher-window.md` |
| Webhelper shim (**in the daily prefix**) | `<prefix>/drive_c/Program Files (x86)/Steam/bin/cef/`**`cef.win64`**`/steamwebhelper.exe`, original kept beside it as `steamwebhelper_real.exe`. Compiled default is **empty** — installed is NOT armed; a cell asks for switches via `SHIM_ARGS`. A Steam client update restores the original and silently un-shims it. Install/revert: `scripts/install-webhelper-shim.sh [--revert]` |
| Game prefix (default) | `~/Applications/CS2dxmt11.app/Contents/SharedSupport/prefix` |
| Other tenant of these wrappers (2026-10-31; own wrapper since 2026-11-07) | **Surviving Mars: Relaunched** has its own wrapper, `~/Applications/SurvivingMars.app`, built by `surviving-mars-relaunched/tools/split-wrapper.sh`: an APFS clone of S734M with CS2 stripped, the game moved in from the storefront's Steam library, D3DMetal 3.0 in its `wine/` (2.1 blacked out landscaping). It is run by `surviving-mars-relaunched/launch-relaunched.sh` in this repo (since 2026-11-09; the separate repo it came from is private, and its earlier history is kept privately). Buying still goes through the storefront Steam (licences are account-level). **One Steam on the account at a time across all wrappers**: since the split, no lock serialises S734M's Steam against the game's wrapper's |
| Game logs | `<prefix>/drive_c/users/Wineskin/AppData/LocalLow/Colossal Order/Cities Skylines II/` (the other user dirs in the prefix are symlinks to `Wineskin`) |
| Agent brief | `docs/agent-brief.md` — hand to every subagent; they inherit no auto-loaded memory |
| Experiment ledger | `EXPERIMENTS.md` — conclusions register + run index. Read the register at `wake up`; `python3 scripts/check-experiments.py` at `button up` |
| Evidence store | `~/cs2-patch/evidence/<cell>/` (**outside this repo** — window PNGs carry the persona name). `/tmp/steam-cell-*` is volatile; `scripts/salvage-cells.sh` moves + sanitises |
| Boot-verify (**the** way to prove the game boots) | `scripts/boot-verify.sh` — launcher → dwell → `WM_CLOSE` → judge `Logs/SceneFlow.log` (written live; only `GameManager destroyed` is exit-only). Prints `GRACEFUL: yes\|no` and one `VERDICT: PASS\|FAIL\|VOID` line; the exit code follows (2 = refused, the prefix is busy). **Run it detached with a log** — a tool timeout kills the process group and Steam with it. `--selftest` = every judge branch, no launch. Run dirs: `~/cs2-patch/boot-verify/` (outside the evidence store on purpose: the ledger checker treats every store dir as a cell) |
| Resize instruments | `scripts/win-resize-driver.c` (exact `SetWindowPos` sizes, **per-monitor DPI aware** so odd raw sizes are reachable; `tree`, a signal-free `close`, and `move <hwnd> <dx,dy>` — a **delta in the parent's client space**, cross-process; output is LF since 2026-09-03 but callers keep `tr -d '\r'` because the gitignored `.exe` can be older than the source) + `scripts/pixel-probe.swift` (edge-vs-interior RGB — a 1-device-pixel seam does not survive a screenshot; `strip <x> <w>` = mean RGB of a column band; refuses images under 24 px). Build lines are in each file's header; deploy the driver to `~/cs2-patch/win-resize-driver.exe` |
| RE toolchain | `patches/_vendor/` (dnfile + pefile, shipped in the repo since 2026-11-09 and installed beside the patch scripts by `setup.sh`). `~/cs2-patch/revenv` is the environment used before that; nothing tracked needs it now |
| Disassemble | `python3 patches/dis_pdx.py <dll> <Type> <Method>` from the game folder |

## Rules specific to this project

- **Never edit a `launch-cs2*.sh` (or `cs2-display-profile.sh`) while the game is running.** Bash
  reads scripts incrementally; a mid-run edit shifts byte offsets and corrupts the parse
  (produces a bogus syntax error).
- **Several wrappers legitimately run Steam at once** (dxmt11 + store wrapper + the Surviving Mars wrapper). Never
  attribute a Steam process by COMMAND LINE: webhelper children always carry Windows-style argv,
  and a steam.exe restarted by its own updater does too — a `pgrep -f "<App>.app.*steam.exe"`
  sweep missed a live logged-in Steam (2026-08-24). Attribute by open files against the PREFIX:
  `lsof -p <pid> | grep -q "<prefix>"`; the launchers' `steam_exe_up`/`steam_family` helpers are
  the reference (prefix, not wine dir — an engine can serve a foreign prefix).
- **Same-account Steams swap ONE online session** ("Session Replaced"); the running game survives
  the swap and takes the session back on its next launch (GOTCHAS 2026-08-24). A store wrapper
  showing NO CONNECTION mid-game is correct behavior, not a bug. The other order costs something:
  a store opened AFTER the game starts replaces the game's Steam, which then skips the game's
  Steam Cloud upload at exit (GOTCHAS 2026-11-01).
- **Never `kill -9` Steam.** It leaves a 0-byte `.crash` marker that makes the next launch exit 1.
  Use `steam.exe -shutdown`; fall back to `WINEPREFIX=<prefix> wineserver -k`. The launcher clears
  a stale `.crash` on startup.
- **Don't hand-edit `Settings.coc` for graphics.** Flipping `enabled` without the accompanying
  parameters yields an "on but zeroed" profile the game reports as `Custom` and won't restore
  across a display-mode change. Set graphics in-game.
- **Judge runs by timestamp.** Only read a run whose `SceneFlow.log` first line postdates the change.
- **Check disk, not the UI**, for anything mod-related.
- Boot-verify after touching `mscorlib` — it's on the boot path.

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
