# Open threads

Current stack: **self-built stock Wine 11.16 + DXMT**, promoted 2026-08-23 — 10 patches. Built by
`scripts/build-engine-1116.sh` from the official winehq source (the DXMT binaries and x86_64
dylibs are reused from a Porting Kit Wine11+DXMT wrapper, which remains the prerequisite install).
**Porting Kit Wine 11.0 + DXMT** is the storefront wrapper + parked fallback
(`CS2dxmt11-pk110.app` — `CS2 Steam Store.app` opens Steam there); **Wine 10
Sikarugir + D3DMetal** (`S734M.app`) is the older proven one. See `README.md` for how it works,
`INSTALL.md` §6 for the engine build, and `docs/patch-inventory.md` for the patch-by-patch
breakdown.

## ✅ SOLVED: the alt-tab freeze (was this project's headline defect since July)

**Fixed in the daily stack as of 2026-08-23.** In exclusive Fullscreen, losing focus used to
freeze the render permanently — input and audio continued, the screen updated exactly once per
window-order change, and recovery meant a force-kill. It is gone: click-away → the game
self-minimizes (its own behaviour, unchanged) → **restore comes back live**, repeatedly,
confirmed in-game by James on the promoted engine.

**Root cause, pinned by measurement then reproduced standalone:** presents to an HWND's
*non-newest* swapchain are silently never composited. CS2 creates a second swapchain on focus
loss and keeps rendering into the original, so its output goes to a layer nothing shows.
`scripts/minrepro3.c` demonstrates it in ~150 lines with no fullscreen, minimize or focus change
required. Three earlier hypotheses were eliminated with evidence first (swap-effect warning,
`dxgi.handleAltTab`, the `DXGI_STATUS_OCCLUDED` gating) — full table in
`docs/dxmt-bugs/DRAFT-focus-loss-freeze.md`, mechanism detail in `GOTCHAS.md` § alt-tab.

**The fix is upstream in Wine 11.16, not in DXMT.** Two commits in the 11.15→11.16 window are
candidates — `1a1d1f3f3` *"winemac.drv: Hide client_view when flushing window surfaces"* and
[`2293b0e`](https://github.com/wine-mirror/wine/commit/2293b0e) *"win32u: Keep unused client
surfaces around and reuse them"* — and both ship in the stock tarball, so the built engine
carries the fix whichever it is. Verified end to end: the reproducer says `STALE` on wine 11.0
and `LIVE` on our 11.16 build (`scripts/run-minrepro3.sh` computes the verdict), and the game
confirms it.

**Filed as [3Shain/dxmt#206](https://github.com/3Shain/dxmt/issues/206)** (open, 7 comments, no
maintainer response yet) with the trace, the standalone reproducer, and the wine-version
finding. AI assistance disclosed per their policy; no PR, ever — any DXMT-side fix is theirs.
⚠ **Still to post:** the game-level confirmation from a *stock-source* 11.16 build, which is the
thing nobody else has reported.

**Delivered instead of waiting:** `scripts/build-engine-1116.sh` builds the engine from official
Wine source in ~1 hour, redistributing nothing. Full plan, gates and as-built record:
`docs/plans/build-wine1116-dxmt-engine.md`. Measured payoff (M3 Max, same city/settings):
freeze gone · **44.86 FPS vs 42.7** · GPU 23.1 ms vs 25.9–26.6 · presentation **Direct** where
11.0 composited · exclusive Fullscreen usable again · same 10 patches, mods still download.

**Measured negative:** macOS **Game Mode stays Off** even in exclusive fullscreen — the
hypothesis that regaining exclusive fullscreen would make the app eligible is closed. Likely a
Rosetta/Wine categorisation thing; nothing else depends on it.

**Second thing worth posting upstream:** [#141](https://github.com/3Shain/dxmt/issues/141) (Steam
CEF black window, ANGLE `EGL_BAD_ALLOC`, open) is **intermittent** here, not absent — library
rendered fine 2026-08-23 (purchases + DLC worked); fully black on 2026-08-24 in both GPU and
software compositing (GOTCHAS § visible Steam UI). The daily flow is immune (Steam runs
`-silent`). Any upstream comment should say "intermittent under stock wine 11.16", which is
still useful signal on the open issue.

## Queued: mod keybinding alerts (James, 2026-08-24, mid-play)

*"Can we do a thing about the keybinding alerts in the mods?"* — investigated from disk
2026-08-24 while the game ran (read-only). **Findings:** 5 mods installed (Move It, Traffic,
Anarchy, EasyZoning, Unified Icon Library); 4 register input actions; NO conflict/warning lines
in any log — the alert is UI-only. Move It ships a conflict panel (`MIT_BindingConflicts` →
`MIT_ShowRebindConfirm`, "Set {N} bindings to empty") and it already ran once: `MoveIt.coc`
`HasShownMConflictPanel: true`, and Settings.coc shows three vanilla actions emptied to make
room (Map Tile Purchase Panel · Relocate Selected Object · Toggle Selected Object Active).
Traffic's three optional remove-connection shortcuts are unbound in Traffic.coc (its default);
Traffic options has "Use Vanilla Tool bindings" + "Reset bindings"; Anarchy has "Reset Anarchy
Keybindings"; EasyZoning can log "Keybinding setup skipped:" (not firing now). Mod default keys
live in attribute metadata, not extractable as strings — collision table needs either James's
screenshot of the alert, or decompiling defaults via dis_pdx.py.
**Next:** James describes/screenshots the alert (which screen, what wording, when). Fix paths
ready: (a) resolve in-game via Options → Keybindings (badges mark the colliding pair), (b) rebind
the three emptied vanilla actions to fresh keys, (c) post-session Settings.coc complete-value
binding edits (honored per GOTCHAS — never partial).

**Update 2026-08-25 (screenshot received, thread mostly resolved):** the "alert" = the ⚠ badges
on mod entries in Options (post-batch-1: Find It · Anarchy · Traffic), plus — separately — the
known cosmetic settings-read IOException (GOTCHAS § absent files), which fired as a mid-session
dialog at Find It options-open on the first post-install boot. Find It's conflict was resolved
live: search rebound off plain Ctrl+F to ⌘⇧F (= Ctrl+Shift+F under `LeftCommandIsCtrl`, see
GOTCHAS § Apple/⌘ binds as Ctrl; landed in `FindIt.coc`). **Remaining:** Anarchy + Traffic
badges (unbound-action class) and optionally (b) — all benign, close out post-session via (a)
or (c).

**2026-08-25 PM — CLOSED via fix path (c), executed while the game was down.** Defaults
extracted offline with new `scripts/dump-binding-attrs.py` (attribute-blob parser; b1/b2/b3 =
alt/ctrl/shift, calibrated on Ctrl+Z/Ctrl+F); full collision table + the .coc edit protocol
now in GOTCHAS § "Mod keybinding defaults are extractable offline". Applied on disk (backups
`*.bak-keybinds-20260825-120139`): the three emptied vanilla actions → Ctrl+Shift+M/R/A ·
Traffic's unbound trio → Ctrl+Alt+1/2/3 · Traffic priorities-display off vanilla-quicksave
Ctrl+S → Ctrl+Alt+S · Find It Random off Traffic's Ctrl+R → Ctrl+Alt+R. **Left open by
choice:** Anarchy's PageUp/Down ⚠ (triple-booked with vanilla surface/underground + Move It;
no Anarchy.coc exists and minting one from scratch is format-risk — one in-game rebind creates
it properly if James wants that badge gone). Verify on next boot: Traffic + Find It badges
should be gone; then confirm the game preserved the .coc values after that session exits.

**2026-08-27 — REOPENED: verification split.** Disk half PASSED: all four rebind groups
survived the game's settings-rewrite cycle (live `.coc`s re-checked post-14:43 session; the
game canonicalizes to modifier-only deltas — `m_Path` omitted when the key matches the mod
default — confirmed against pre-edit FindIt backup; `HasShownMConflictPanel` intact; Player.log
has zero binding/conflict lines). Badge half FAILED, informatively: badges still appear **every
launch** on Find It · Anarchy · Traffic (screenshots), all rebinds visibly live in the UI, no
inline row warnings — and **opening a badged section clears its ⚠ with no input**. So the badge
is a boot-time notice with per-session acknowledgment, NOT a live conflict indicator — the
08-25 "fix conflicts ⇒ badges go" premise was wrong (conflicts were still worth fixing; chords
no longer fight). Two candidate mechanisms, both fitting the badge set {FindIt, Anarchy,
Traffic} and the non-badging {EasyZoning, MoveIt}: **(1) non-default/unregistrable-keybind
notice** (FindIt 2 + Traffic 4 rebinds carry ↻ reset arrows; Anarchy's mimic'd PgUp/Dn rows are
vanilla-owned; EZ is pure-default) · **(2) modifier-superset conflict detection** (Anarchy
Alt+R ⊂ FindIt Ctrl+Alt+R badges both; Traffic trio Ctrl+Alt+1/2/3 ⊃ own quick-set
Ctrl+1/2/3). **Decisive experiments (in-game, ~30 s each, read on next boot):** (E1) rebind
EasyZoning toggle to something unique (e.g. Ctrl+Alt+V) — if EZ starts badging → theory 1;
(E2) move FindIt Random Ctrl+Alt+R → Ctrl+Alt+F — if Anarchy stops badging → theory 2 (then
expect de-supersetting Traffic's trio to clear Traffic too). Fallback: RE the badge computation
in Game.dll (options UI) via dis_pdx.py. Until settled: badges are cosmetic, two clicks/boot.

**2026-08-27 PM — MECHANISM PINNED by disassembly (supersedes both theories; E1/E2 moot), fix
STAGED.** ⚠ **The badge ATTRIBUTION in this entry is wrong — falsified two entries below
(the notification is a menu toast, not the ⚠; the badge is `InputBindingField.get_warning`).
The stale-cache root cause and the boot-order finding below stand.** James asked for a fix;
ran the RE fallback (dnfile scan + dis_pdx on Game.dll
1.6.0f1). Chain: boot `InitializeUI` → `InputManager.CheckConflicts` → per-mod-map
`SetModConflictNotification` pushes a "KeyBindingConflict" notification = the options ⚠;
opening the section dirties conflicts → `ProcessActionsUpdate` re-runs `CheckConflicts` → clean
→ pops ("KeyBindingConflictResolved"). Same code, different verdicts ⇒ the **boot pass runs
before per-user .coc overrides apply and evaluates the mods' FACTORY defaults**, which do
collide exactly (FindIt Ctrl+R ⟷ Traffic Ctrl+R · Traffic Ctrl+S ⟷ quicksave · trio ⟷
quick-set · Anarchy PgUp/Dn ⟷ vanilla); EasyZoning's default collides with nothing = the one
mod that never badges. So the 08-25 rebinds fixed the real conflicts but could never kill the
badge — it's armed from state that predates them. (Conflict predicate detail for the record:
`ProxyBinding.ConflictsWith` respects modifiers unless either side's action has
`modifierOptions==0`, and `CanConflict` whitelists linked pairs — the superset theory wasn't
needed.) **Fix (v2 — v1 was invalid IL, see GOTCHAS § "IL opcode surgery"):** 1-byte IL patch
— `SetModConflictNotification`'s `ldarg.2`→`ldc.i4.0` (0x04→0x16 at file 0x22c1e5) makes the
active-check constant-false so every call takes the pop/clear path; badges can never arm; the
real conflict UI inside the rebind screens is separate code, untouched. Patcher:
`~/cs2-patch/patch-modconflict-badge.py` (repo copy `scripts/`) — dnfile-resolved,
sig-verified (exactly-one-hit or refuses), lsof game-down guard, idempotent, backup on apply;
verify-only run 2026-08-27 = PATCHABLE at the derived offset. **To finish: run
`~/cs2-patch/revenv/bin/python3 ~/cs2-patch/patch-modconflict-badge.py apply` with the game
down, then boot-verify (clean main menu + no badges). Re-run after any CS2 game update**
(Steam replaces Game.dll; script re-derives by signature). Ledger entry 2026-08-27 16:06.

**2026-08-27 ~17:00 — APPLIED + BOOT-VERIFIED (v2), thread CLOSED pending James's visual
check.** v1 (brfalse→br) was invalid IL — brfalse pops its condition, br doesn't →
`InvalidProgramException` at JIT in CheckConflicts/InitializeUI + broken mod init; caught by
boot-verify, backup restored byte-verified. Full lesson: GOTCHAS § "IL opcode surgery". v2
(`ldarg.2`→`ldc.i4.0`, stack-balanced) applied 16:58, boot-verify round 3 PASSED (fresh
Player.log: 0 InvalidProgram, 0 mod-init errors, game alive at main menu; backup
`Game.dll.bak-modconflict-20260827-165828`). Ops lessons from round 1: an
InvalidProgramException boot does NOT kill the process (limped at 98% CPU 10+ min — a stale
`ps comm` grep missed it and a second instance launched beside it); liveness check is
`pgrep -f '/Cities2.exe'` (the .app stub's own pattern). Machine left: game + Steam down.
**Remaining:** James eyeballs Options → mod rows next session (expected: no ⚠ anywhere,
including Anarchy); re-run the patcher after any CS2 game update.

**2026-08-27 ~17:2x — QUEUED (James's ask): launcher auto-ensures the badge patch.** Insert
after the repatch-ensure block (`launch-cs2-dxmt11.sh` ~line 131's `fi`), matching its
warn-and-continue style — fail-open, a bad state must never block a launch. The patcher is
idempotent (ALREADY PATCHED no-op · fresh apply after a game update · FAIL+warn on sig
anomaly/lsof), so `apply` is the right mode:

```bash
# Badge patch (Game.dll): re-ensure after game updates — Steam replaces Game.dll and
# repatch.sh does not cover it (see patch-modconflict-badge.py; fail-open by design).
if [ -x "$PATCH_DIR/revenv/bin/python3" ] && [ -f "$PATCH_DIR/patch-modconflict-badge.py" ]; then
  BP_OUT=$("$PATCH_DIR/revenv/bin/python3" "$PATCH_DIR/patch-modconflict-badge.py" apply 2>&1) \
    && echo "Badge patch: ${BP_OUT%%$'\n'*}" \
    || echo "WARNING: badge-patch check failed — continuing (cosmetic). ${BP_OUT%%$'\n'*}"
fi
```

**Blocked on:** game/Steam down (mid-run-edit rule — a launch was in flight when queued).
Post-edit gate: `bash -n` + standalone run of the inserted command; the echo integration
proves itself on the next natural launch (fail-open). Re-verify the ~line-131 anchor before
inserting.

**2026-08-27 ~17:1x — v2 attribution FALSIFIED by James's screenshots (badges unchanged on
the patched DLL); real badge source pinned and patched (P2); launcher auto-ensure SHIPPED.**
The notification v2 killed is a separate surface (menu toast). The badge chain, by xref:
per-row `InputBindingField.get_warning` = `(binding.hasConflicts & mask) != 0` reading
`ProxyBinding`'s conflict cache, which goes stale because every mod's `AddActions` re-runs
`CheckConflicts` mid-registration (round-1's crash stack was the map of this); tab/mod-row ⚠
aggregate from rows (mods declare no `SettingsUI*Warning` attributes). **P2** neuters the
widget getter (prologue → `ldc.i4.0; ret`); `get_hasConflicts` itself left alive because the
rebind-time NeedAskUser dialog reads it. Patcher rewritten as a two-patch set (P1+P2, per-
patch state machine, BROKEN-V1 detection); applied 17:18, backup
`Game.dll.bak-modconflict-20260827-171831`. Launcher gained step 0b (badge-patch
auto-ensure, fail-open, `bash -n` + standalone-run gated) — the game-update chore is now
automatic. Boot-verify round 4 = P2 IL validity + launcher line. **Badge-absence check:
James's next session.**

**2026-08-27 17:36 — P2 took three forms; v2c BOOT-VERIFIED CLEAN (round 6), thread closed
pending James's visual check.** v2a (prologue `ldc.i4.0; ret`, stale tail) and v2b (nop-pad
tail) were BOTH invalid IL — Mono linearly decodes the entire body: stale bytes must decode
(round 4, `IL_0002 bne.un.s` from a token fragment) and a nop tail falls off the method end
(round 5, `IL_0021 beq.s IL_0095` = the decoder reading the NEXT method's header `2E 72`,
confirmed by hexdump). v2c = value substitution: the 11-byte `hasConflicts` load →
`ldc.i4.0` + 10 nops, all original flow/terminator intact, body hand-decoded valid. Round 6:
game alive, 0 `Invalid IL`, 0 mod-init errors, launcher 0b line printed. Full lesson set in
GOTCHAS § "IL opcode surgery" (rules 1–4). Backups chain in Managed/; ledger 17:32. Machine
left: game + Steam down (launcher's own clean-shutdown hook confirmed 0 residual).
James's round-4 mid-verify quit was harmless (noted for the record: it proved the .app's
already-running guard + the launcher's post-exit Steam cleanup work as designed).

## Performance: the deep optimization pass (RUNNING — P0–P2 measured 2026-08-24)

James, 2026-08-23: *"take a deep hard look at optimizing efficiency"* — serious token budget
approved. Plan + ethos: `docs/plans/perf-pass.md` (check-it'd, as-built header current).
Measured table: `docs/perf-pass-results.md`. Method + traps: GOTCHAS (benchmark instrument,
Settings.coc edit rule, resolution/upscaling closures).

**Done:** instrument discovered (the game's own `-benchmark` writes structured per-frame results;
`scripts/perf-bench.sh` runs autonomous cycles) · noise floor 1.03 FPS · resolution/upscaling
family closed by live adjudication (borderless locks backbuffer res; MetalFX supersample-only
there; TAAU pathological; street names are world text) · settings matrix measured autonomously
via Settings.coc edits (LOD = GPU+CPU double lever; High SMAA costs ~5 gpuMs, kept for looks;
texture-up free) · **composed daily driver measured +11.6% avg / +55% 1%-low** (native + High
SMAA + LOD 0.25 + mipbias 0) — **applied, and VERDICT DELIVERED (James, 2026-08-24, mid-play):
"things look good, not as amazing as some youtubes i've seen but pretty solid" — ACCEPTED as the
daily driver.** (The YouTube gap is native-Windows/RTX rigs at high LOD + photo-mode footage; if
looks ever outrank frames, LOD 0.25→0.5 buys it back for ~4.7 FPS — one settings change.)

**Remaining:** P3 pacing cells (`preferredMaxFrameRate` on the daily scene, vsync decision) ·
P4 late-game CPU cells (M0-L baseline + job-worker-count/allocator boot.config levers) ·
P5 ship (README numbers + wiki draft — UNBLOCKED by the verdict, next session). Out of scope unchanged
(DXMT rebuild, alternative layers, Rosetta experiments) — and the MoltenVK
dylib update is **cancelled** (2026-08-24 PM: the A/B against pk110 disproved it outright; see
Known-unresolved: Steam UI). What replaces it is the **vendor-patch port
mini-project** (see Known-unresolved: Steam UI) — the bisect ran 2026-08-24 PM and found no
version regression to bisect; stock Wine never rendered embedded Chromium here.

## ✅ ADOPTED: retina / native swapchain (2026-08-26, option 2 — no launcher change)

Laptop-panel sharpness experiment — planned, triple-checked, executed, briefly reverted, then
**adopted the same night via James's attended test** (plan + as-built:
`docs/plans/retina-swapchain-experiment.md`; mechanism + traps: GOTCHAS § "Retina mode").
Final state: RetinaMode=y + LogPixels 192 · in-game Screen Resolution **3024×1964×120** (James's
dropdown selection — it persisted the full width/height/refreshRate tuple and re-latched the
ratchet the right way, `Use Native=1`; the launcher-assert fallback was never needed) · **DRS
Constant 0.5 + ContrastAdaptiveSharpen** set on disk at his request (native-at-100% measured
22–28 FPS on the live city — GPU-bound, unlike the sim-bound bench — vs ~40 at internal 1512).
Net: UI/HUD/menus retina-sharp, world at the accepted frame rate + battery cost. Tuning is the
in-game slider (DRS Constant + SHOW ADVANCED): 0.5 ≈ 40 FPS, 0.65 ≈ high-20s with sharper street
text. **Verified 2026-08-27** (T9 boot + 0.25 discriminator probe): the 3024×1964 selection holds
across relaunch at both stores, and disk-configured DRS is live (0.25 probe moved gpuMs 36.5→32.6,
1%-low 22.5→32.6 — far beyond repeat noise).

**2026-08-27: display-profile auto-detect SHIPPED** (docs/plans/launcher-display-profiles.md,
triple-checked then built same night): the launcher classifies by the *main* display pre-boot —
mobile = native + DRS 0.5 CAS, home/external = DRS off, native 1:1 — via a fail-open helper
(`cs2-display-profile.sh`; `CS2_PROFILE=off|home|mobile`, `DRY=1`). 36 build-night assertions +
5 red-checks green; one open item: **T10, first real dock** (fail-open until then).

## ✅ Retired: "fix it upstream in Wine"

**This was the top item for months. All three root causes are now resolved, none of them by us
filing anything.** Kept as a record of how it ended:

| ID | Defect | Outcome |
|---|---|---|
| **R1** | `GetLastError` garbage after file APIs | **Fixed upstream in Wine 11.0** — measured 2026-08-22. Retires 6 patches. The bug was never in `kernel32`; bug [60220](https://bugs.winehq.org/show_bug.cgi?id=60220) blamed the wrong layer and was correctly closed INVALID. It is Mono's P/Invoke last-error capture. |
| **R2** | `CreateFile` returns handle `0` for a valid file | **Disproven.** 3200 concurrent opens, short and long paths, both Wine versions — never once (`scripts/handletest.c`, `scripts/longpathw.c`). The handle-0 symptom is real but arises elsewhere; `patch_fshandle` is still needed. |
| **R3** | `BCryptVerifySignature` fails on valid ECDSA | **Fixed upstream in Wine 11.0** — measured 2026-08-22 by reverting the Coherent Gameface licence bypass entirely and reaching the main menu with zero licence errors. This retires the one patch that could not be published. |

Consequence: **every patch the default stack needs is published in this repo.** Nothing is left to
file against Wine.

## Report upstream to Paradox

`patch_lockleak` works around a genuine PdxSdk defect, not a Wine one:
`FileIO::CreateFileStream`'s state machine has two `catch` clauses and **no `finally`**, and the
catch handler never disposes the lock acquired at IL `0x78`/`0x82` — though the FileNotFound path at
`0x120` does. Any IO exception leaks that path's lock permanently; the next waiter dies on
`GetLockToken`'s timeout. Windows just rarely throws there, so it hides. Clean fix upstream: dispose
in the handler, or wrap in `finally`.

## Known-unresolved, low severity

- **The `home` profile assumes a ~1080p external panel — revisit before any high-DPI display
  (2026-08-27).** `cs2-display-profile.sh` classifies by whether the *main* display is internal
  (`mode = 'mobile' if internal(nd) else 'home'`, plus an "external present, no main flag" →
  home fallback), so a desktop Mac with no built-in panel correctly resolves to `home` — the
  logic ports as-is. **But `home` means retina off, DRS off, native 1:1**, which is only sane
  because the *main* panel is 1920×1080. On a 4K panel that's 4× the pixels of the tuned working
  point and on a 5K it's ~7× — at 23.1 ms GPU for 1080p High today, native would be unplayable.
  ⚠ **Not hypothetical, and not contingent on a purchase (measured 2026-08-28):** the desk already
  carries a **DELL U2720Q, 27" 3840×2160 (163 ppi, 60 Hz)** — today it is the *portrait secondary*
  and the **DELL U2424H (24" 1920×1080, 120 Hz) is `spdisplays_main`**, which is the only reason
  the profile is safe. **Making the U2720Q the main display is a one-setting change that would put
  `home` at native 4K.** The fix is already in the toolkit, not new code: a high-DPI `home` wants
  the *mobile* treatment (DRS Constant 0.5 + CAS), which lands 4K back on a ~1080p render. Treat
  the profile table as needing one new row — `home-hidpi` — and re-bench rather than assuming 0.5
  is the right factor. Also: set the refresh rate **in-game**, never in
  `Settings.coc` (measured not to take), or the mode change blanks the other display — GOTCHAS
  § "Second display gets blacked out".
- **`scripts/README.md` documents 25 of 40 source scripts — 15 have no mention at all (measured
  2026-08-28; 50 files in `scripts/`, 10 of them compiled `.exe` companions that need no row).** Pre-existing drift, not from any one session. Unmentioned and worth rows if
  anyone touches them: `minrepro{,2,3}.c` + their `run-minrepro*.sh` harnesses, `perf-bench.sh`,
  `perf-run.sh`, `capture-freeze.sh`, `diag-launch-dxmt11.sh`, `make-shortcut.sh`,
  `make-steam-shortcut.sh`, `pe-icon.py`, `whwrapper_ipgpu.c`, `wineandaqua-dxmt.patch`,
  `build-engine-1116.sh`. Check with: for each file, `grep -qF "$f" scripts/README.md`.
- **Metal HUD is OFF in the double-clickable shortcut (James, 2026-08-27, "for now").** The
  `.app` was previously generated with `HUD=1`; regenerated without it, so the perf overlay no
  longer appears in normal play. Restore whenever wanted:
  `HUD=1 bash scripts/make-shortcut.sh` (the generator parameterises it — `HUD_ENV` line;
  nothing else changes). Launching the script directly with `CS2_HUD=1` also works for one run.
- **~~Five `Game.dll.bak-modconflict-*` backups (~58 MB)~~ — PRUNED 2026-08-27 (James).** One
  kept: `Game.dll.bak-modconflict-20260827-164920`, the **pristine** rollback target — both
  patch sites verified unpatched by byte-probe (0x22c1e5 / 0x108d5a), sha `721e7e17bf74`,
  parses as a valid .NET PE. The other four were a byte-identical duplicate of it, two
  identical P1-only copies, and one holding the broken truncated-P2 state. 58 MB → 12 MB; live
  `Game.dll` untouched (both patches confirmed present after). Restoring the keeper puts the
  DLL back to stock; the launcher would then re-apply on next boot, so use `CS2_PROFILE`-style
  intent — i.e. move the patcher aside — if you ever want it to *stay* stock.
- **Steam's visible UI — PARTIAL, not shippable (2026-08-24 late).** The webhelper shim
  (`--in-process-gpu`, injected past steam.exe's filter, size-padded past Steam's
  "Verifying file sizes only" integrity pass) **converts the black window into a fully rendered
  one — except it draws no text at all.** Artwork, thumbnails, icons and chrome are perfect; no
  menu labels, titles, prices or search placeholder. Isolated to the flag: the PK wrapper renders
  Steam text normally and loses it identically once the shim is added.
  - **Ruled out as the cause:** DXMT glyph-atlas support (`--use-angle=swiftshader` + `vulkan-1=n,b`
    is pure software and still textless) · GPU/OOP rasterization · LCD/subpixel text · GPU
    compositing · DirectWrite (`--disable-direct-write`) · **fonts** (`scripts/fonttest.c`: daily
    and PK both see 924 GDI / 204 DirectWrite families, identical).
  - ⚠ **Correction:** an earlier claim this session that our build omitted DirectWrite FreeType was
    **wrong** — our `dwrite.so` has all 56 `pFT_*` pointers; PK's binaries are merely stripped.
    Compare with `nm`, never `strings` or file size.
  - **Reverted from the daily wrapper**; `scripts/install-webhelper-shim.sh` kept for future work
    (`SHIM_ARGS` swaps injected switches without rebuild+repad). Two-wrapper split still the
    practical answer: play on `CS2dxmt11`, Steam UI on `CS2dxmt11-pk110` (**do not delete**).
  - **✅ Productized (2026-08-24 late):** the split is now one double-click — `CS2 Steam
    Store.app` (`scripts/make-steam-shortcut.sh`; `build-engine-1116.sh` step 7 auto-preserves
    the 11.0 wrapper as an APFS clone + builds the app). Session behavior measured: same-account
    Steams SWAP one online session (Session Replaced), the running game survives the steal
    (8-min soak, 0 errors) and takes the session back on next launch. Launchers moved to
    lsof-vs-prefix process attribution (cmdline pgrep misses Windows-argv steam.exe + orphaned
    webhelpers). GOTCHAS has both writeups.
  - **Disk note (2026-08-24):** the pk110 wrapper's redundant 91 GB game copy was deleted (with
    its `appmanifest_949230.acf`, so Steam does not re-download) — but this reclaimed **0 GB**: the
    two installs were APFS clones sharing extents, and `du` was reporting logical size for each.
    Restoring it is instant and free via `cp -Rc` from the daily wrapper if ever wanted. See
    GOTCHAS § "`du` lies about disk on APFS".
  - ▶ **Open lead, RE-FRAMED 2026-08-28 — it is not the flag.** `--single-process` (never tested
    before that date) renders *and drops every glyph* exactly like `--in-process-gpu`: 2,018,352 B
    of real UI, zero text, bare dropdown carets, empty search field. So the cause is **in-process
    GPU by any route**, not one switch, and "why does `--in-process-gpu` kill glyphs" was the wrong
    question. The March-2026-client CEF-regression suspicion is unchanged and still untested
    (revisit trigger 5). Both durable findings (flag filtering, size-only verification) are worth a
    dxmt#141 follow-up regardless.
  - ✅ **TESTED AND DEAD 2026-08-28 — Steam's processes on vanilla wined3d, game keeps DXMT.** The
    route from [mikey92 on dxmt#141](https://github.com/3Shain/dxmt/issues/141#issuecomment-5448572368)
    + [BCD1210/soju](https://github.com/BCD1210/soju/blob/main/docs/STEAM-GAMES.md). Built it: a
    `build-engine-1116.sh` run stopped after step 3 yielded version-matched vanilla wine 11.16
    `d3d11.dll`/`dxgi.dll` (they exist only between step 3's `gmake install` and step 4's DXMT
    overlay). Wired it: builtin-marker strip at file offset 0x40 + global `builtin` / per-app
    `native`. **The split provably landed** — `+loaddll` shows Steam on `d3d11: native` +
    `wined3d: builtin` with no winemetal anywhere — and Steam is **still uniformly black
    (108,343 B)**. Byte-identical with wined3d's Vulkan renderer, which is the tell: the D3D
    implementation is not the variable, so the client's failure was never DXMT's missing
    cross-process swapchain. The wall is the winemac presentation layer; the PK vendor patchset
    stays the only thing that has ever rendered this. Also measured: wined3d's **GL** backend
    cannot even `glClear` on macOS 26 (`GL_INVALID_FRAMEBUFFER_OPERATION`), while its **Vulkan**
    renderer is healthy — correcting a stale GOTCHAS claim that it crashes. All reverted; game
    re-verified on DXMT. Apparatus kept as `scripts/steam-vanilla-d3d-split.sh` (install/verify/
    revert with backups), so a re-test after upstream winemac work is minutes, not an hour.
  - ▶ **Remaining untried:** an older-CEF client pin (trigger 5) — now the only route left that
    does not depend on someone else shipping engine-side cross-process presentation.
  - Evidence: GOTCHAS §§ "The webhelper shim renders everything EXCEPT text" and "The glyph loss is
    IN-PROCESS GPU itself". Harness: `scripts/steam-render-cell.sh` (one cell, capture-judged).

  **↻ Revisit triggers (checked periodically — James, 2026-08-24: "let's periodically look for a
  better solution").** Don't re-run the whole investigation; check these cheap signals, and only
  dig in if one moves:
  1. **A Steam client update.** The community shim was reported working on a *March-2026* client;
     ours is buildid `1785799196` (Aug-2026). Text may return on a different CEF. Cheap test:
     re-apply `scripts/install-webhelper-shim.sh`, launch, capture the window, look for glyphs;
     `--revert` after. (Also re-check whether Steam still verifies **file sizes only** — a switch
     to hashes kills the shim entirely.)
  2. **[dxmt#141](https://github.com/3Shain/dxmt/issues/141) activity** — any movement on
     cross-process swapchain support is the real fix. ✅ **FIRED 2026-08-28** — mikey92 posted an
     independent reproduction (M4 Pro / macOS 26.5 / Homebrew `wine-stable` 11) plus the
     vanilla-wined3d-for-the-client split. Acted on the same day: `--single-process` and
     `--disable-gpu --single-process` tested (textless / no window respectively), out-of-process
     `--use-angle=gl|vulkan` tested (GPU process crashes ×3, same as default — the wall is
     backend-independent). Still no maintainer reply. **Three evidence comments are on the thread**:
     the stock-vs-vendor sweep
     ([#5400445243](https://github.com/3Shain/dxmt/issues/141#issuecomment-5400445243)) and the
     `--in-process-gpu` results — renders but textless, with the steam.exe flag-filtering and
     file-size-only verification findings
     ([#5403561498](https://github.com/3Shain/dxmt/issues/141#issuecomment-5403561498)), and the
     2026-08-28 eliminations — `--single-process` textless, backend-independent out-of-process
     wall, and the vanilla-wined3d split landing yet still black
     ([#5458926046](https://github.com/3Shain/dxmt/issues/141#issuecomment-5458926046), drafted in
     `docs/dxmt-bugs/comment-141-vanilla-wined3d.md`). Watch for a maintainer reply; we offered to
     run further diagnostics on this setup.
  3. **A DXMT release** — `3Shain/dxmt` releases page; cross-process present is the thing to grep
     release notes for.
  4. **Wine 11.17+** — not because a version regression exists (there is none; stock 11.0 is
     equally affected), but because winemac cross-process surface work would show up there.
  5. **An older-CEF pin** — Steam keeps prior client builds; pinning one predating the regression
     is the most promising *untried* route, and the only one that doesn't depend on someone else
     shipping a fix.

- **Fullscreen-toggle cursor desync** — ⚠ *observed on wine 11.0; NOT re-tested on the promoted
  11.16 engine.* Toggling fullscreen ↔ windowed mid-session dropped the game out of exclusive
  fullscreen (a macOS title bar appeared); render resolution and window geometry stopped matching
  and cursor coordinates shifted. Since the whole defect class lived in the same client-surface
  machinery 11.16 reworked, this may already be gone — re-check before repeating the old
  "set Fullscreen and don't toggle" advice.
- **Graphics settings must be set in-game.** Hand-editing `Settings.coc` to flip an `enabled` flag
  without its accompanying parameters produces an "on but zeroed" profile (e.g. SSGI with
  `raySteps: 0`) that the game reports as `Custom` and does not restore across a display-mode
  change. Use Options → Graphics.
- **D3DMetal unsupported-API notices** at startup (`NumClassInstances > 0`, `GetSharedHandle`,
  timestamp queries). One-time init messages, not per-frame; no observed impact.
- **Rosetta horizon.** The entire stack is x86-64 under Rosetta 2, and macOS 26 now surfaces a
  deprecation notice ([Apple 102527](https://support.apple.com/en-us/102527)) — coming, not in
  effect. Apple's stated plan: full Rosetta through macOS 27, then a reduced subset "for older
  games" in macOS 28+, with no word on whether Wine-style use qualifies. Nothing to do today;
  plan-B territory (ARM-native Wine/FEX or whatever exists by then) around late 2027.

## Not worth doing

- **Reviving the DXVK/MoltenVK stack.** Archived in `archive/`. D3DMetal is stable where it was not.
- **CrossOver.** Licence expired 2026-08-21. The free stack matched it and then exceeded it.
- **`patch_pdxsdk_io`.** Masks failures instead of fixing them; breaks boot on empty mod state.
- **The four rejected lock patches.** All chased a deadlock that does not exist. See
  `docs/patch-inventory.md` §5.
