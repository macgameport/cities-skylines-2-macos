# Move the stack off Rosetta: arm64 Wine + FEX + ARM64EC DXMT

> **Status: planned; P0 (watch) is the only current phase.** Triple-checked 2026-10-11 — build-ready-with-fixes
> for P0, corrections folded (four lenses; § Review corrections). P1–P4 were `needs-rework` as
> written and are corrected in this fold, but they are planning-only and **must be re-checked
> before P1 starts** — the external facts below move weekly.
> Tracking: [#16](https://github.com/macgameport/cities-skylines-2-macos/issues/16). Written
> 2026-10-10. Every external fact below carries the date it was checked; most of them will move
> before this is built, so the watch list in §5 is part of the plan, not an appendix.

## 1. Why, and the deadline

Every executable piece of this stack is x86_64 and runs under Rosetta 2. Measured 2026-10-10/11 on
the live wrapper (`file` on each): `wine`, `wine64` (a symlink to `wine`, made by
`build-engine-1116.sh:134`), `wineserver`, `ntdll.so`, `winemac.so`, `win32u.so`, `winevulkan.so`,
DXMT's `winemetal.so`, the wrapper's `wineskinlauncher`, and every Mach-O in the wrapper but one
(944 scanned; `ObjectiveC_Extension.framework` is universal x86_64+arm64).

The PE side splits in two:
- **The game path is x86_64.** `Cities2.exe`, `UnityPlayer.dll`, `mono-2.0-bdwgc.dll`,
  `cohtml_Unity3DPlugin.dll` and `steam_api64.dll` are PE32+ x86-64. The game dir's only native
  i386 PEs are an installer and `vswhere.exe`; its other "PE32" files are AnyCPU .NET.
- **Windows Steam also runs i386 code.** `steam.exe` is PE32+, but the Steam dir holds 31 native
  i386 PEs within depth 3 — `steamclient.dll`, `bin/steamservice.exe` (which runs, and crashes
  harmlessly: GOTCHAS § "Don't zero-out steamservice.exe"), `GameOverlayRenderer.dll`,
  `bin/x86launcher.exe`. So any route that keeps Windows Steam needs i386 emulation as well.

Apple, 2026-09-01 ([developer news](https://developer.apple.com/news/?id=w5ngl9k2), re-read
2026-10-11): macOS 27 is the final release to support Rosetta; afterwards Rosetta continues only
for "older, unmaintained gaming titles that rely on Intel-based frameworks". Apple's page names no
version for that subset — "macOS 28" is CodeWeavers' framing. A self-built x86_64 Wine host does not
fit the description, and CS2 is neither older nor unmaintained. macOS 28 betas: expected ≈ June
2027. 27.0.1 already removed Rosetta once on this machine (C69, GOTCHAS 2026-10-10).

**The arm64 route depends on Apple too.** FEX on macOS needs the kernel's cross-architecture
features (`os_cross_arch_is_supported`, `os/arch/arm64.h:160-185`, "the set of cross-architecture
features required by a user-space compatibility layer"). If macOS 28 withdraws those along with
Rosetta, the arm64 route fails with it. W8 watches for this.

**The decision this plan forces before anything else:** do not move the Studio to macOS 28 until
§4 phase P4 has promoted an arm64 stack (D4). Until then, a macOS 28 upgrade is an upgrade with no
rollback for the game.

## 2. What is verified (checked 2026-10-10, re-checked 2026-10-11)

| fact | source | confidence |
|---|---|---|
| CodeWeavers has native ARM64 Wine on macOS, with FEX emulating i386/x86_64 through ARM64EC; shipped in CrossOver Preview. Shanks: "I'll be sending MRs upstream soon" (2026-08-07) — none by 2026-10-11 | [wine-devel, B. Shanks, 2026-08-07](https://list.winehq.org/hyperkitty/list/wine-devel@list.winehq.org/thread/CKG5CEN2BE5VRXZ7O7NX4YUSBH3247WH/) | primary |
| The **core** macOS-ARM64 changes (x18 custom ABI, 4K-page spawn, TSO, PAGEZERO layout) are **not upstream** from CodeWeavers. Merged preparatory pieces: !11267, !11402, !11668 (bshanks), !11736 (**natbro**). !12257 (bshanks) opened 2026-10-06, **closed unmerged 2026-10-09**. Other open MRs on the same ground: **!11638** (trcrsired, "Support Apple silicon mac for running native windows on arm softwares", x18 + 4K page) and **!11737** (natbro, segv trap numbers). Wine tags 11.17 / 11.18 / 11.19 (09-04 / 09-18 / 10-02); no 11.20 yet. Upstream winemac itself has moved since 11.16 (!12230 WineMetalSwapChain, !12214, !12215, !9503) | gitlab.winehq.org API | primary, absence-of-evidence for CodeWeavers' core |
| The OS APIs exist in the local macOS 27.0 SDK: `os_set_custom_x18_abi_enabled` (`os/arch/arm64.h:122-124`, 26.4), `posix_spawnattr_set_4k_page_size_np` (`spawn.h:165`, 26.0), `os_cross_arch_is_supported` (`arm64.h:183-185`, 26.6), `thread_set_x86_64_compat` (`mach/mach_traps.h:304`, **no** availability annotation). The wine-devel post requires **26.5** for x18, 4K spawn **and per-thread TSO**, and **26.4 + `-Wl,-x86_64_layout_emulation`** for the PAGEZERO layout; its x18 stopgap is `-Wl,-platform_version,macos,11.0,11.0`. **TSO is per-thread and new threads do not inherit it** (post) — see T10 | `xcrun --show-sdk-path` headers; wine-devel post | primary |
| Entitlement: `com.apple.developer.cross-architecture-support` (paid account) or `…-unmanaged` (free account), via an App ID + registered UDID + provisioning profile in a `.app` beside the loader. Disabling SIP is the alternative the post "can't recommend" — **not an option here** (§7 D2). No public report that the free-account route works | wine-devel post | primary for the names; **Apple documents neither** (absent from the whole 27.0 SDK) |
| DXMT: latest release still **v0.80** (2026-04-23), which predates the ARM64 work. CI builds ARM64EC/arm64x PE DLLs (#202 merged 2026-08-04, #209 2026-09-17). The `package` job (`ci.yml:644`) ships gcc x86_64, gcc x86 and **clang arm64ec**. `src/winemetal/meson.build:60-61` builds the unix side whenever `cpu_family` is `aarch64`, so the arm64 `winemetal.so` most likely comes **from the arm64ec job, which is in `package`** — not from `build-clang-release-arm64-macos`, which passes no `wine_install_path`. The arm64ec job links against `3Shain/wine` release `wine-11.2`, whose notes say it only exists for linking DXMT | `3Shain/dxmt` source + `gh release list` | primary for the source; artifact contents **unopened** |
| FEX: upstream publishes no macOS module, but FEX releases ship **no assets as a rule** (FEX-2610, 2026-10-07: none), so that is weak evidence. Community port [`dbc-hbin/FEX-darwin`](https://github.com/dbc-hbin/FEX-darwin): created 2026-10-07, v0.1.0, 0 stars, MIT, based on FEX-2609.1, **not a GitHub fork** (no upstream diff link), commits unsigned, **active** (commits 10-08…10-10). It builds `xtajit64.dll` (x64) + `xtajit.dll` (WoW64 x86) and requires Wine to provide shared-data, JIT write-protection, native JIT allocation and WoW64 guest-window hooks (README:36), so it is not a drop-in for any upstream Wine. Its release zip is named `…-wine-arm64.zip` (contents unopened) | GitHub API | primary for existence; fitness untested |
| **neutron** — [`lixsldotnet/neutron`](https://github.com/lixsldotnet/neutron): created 2026-10-09, v0.1.0 pre-release, LGPL-2.1, 1 star. arm64 Wine + ARM64EC DLLs + FEX + DXMT, plus Proton's `lsteamclient` bridged to **Mac Steam** (Windows Steam is not used). Built from source by `build.sh`; README says most of the code was written by AI; **"32-bit games dont work and will not"**; `install.sh` **re-signs `/Applications/Steam.app` ad hoc**; claims "macOS 15 or newer (tested only on macOS 27)" and does not mention entitlements, x18 or SIP — how it runs without them is unverified. Fork [`codeWonderland/neutron`](https://github.com/codeWonderland/neutron) carries `winemac-remote-metal.patch` and `cross-process-swapchain.patch`, which overlap this repo's winemac work ([dxmt#141](https://github.com/3Shain/dxmt/issues/141) reply, 2026-10-10) | GitHub API + README | primary for the claims; nothing run |
| Another public arm64 Wine + FEX + DXMT tree: `willfaust/Madeira` (iOS) with an LGPL `willfaust/wine` fork (branches `ios-build`, `madeira-lgpl`); its README asks that changes not be sent upstream. FEX-darwin's guest-window patch derives from `willfaust/FEX` PR #2 | GitHub | primary for existence |
| CrossOver Preview's ARM64 path: the blog post exists ("CrossOver Preview: The right to bear ARM64 on Mac", 2026-07-31; body blocked to every fetch). Its claims — bundles ARM64 DXMT, **no D3DMetal**, macOS 26.5+, cannot convert existing bottles — and CrossOver 27 (Apple-silicon only, drops 32-bit bottles, expected early 2027) come from **search summaries only**. CodeWeavers' [source page](https://www.codeweavers.com/crossover/source) offers only `crossover-sources-26.3.0.tar.gz` (2026-07-21): **no Preview source**. Installed here: `~/Applications/CrossOver.app` 26.2 — the expired licence (2026-08-21, `change-ledger.txt:481`), not the Preview | CodeWeavers blog index, source page | **second-hand** for the ARM64 claims — open the post in a browser before relying on them |
| **No public report of CS2** on any ARM64 path. One self-reported Unity D3D11 title (Gamble With Your Friends, ~100 FPS at 3440×1440, M5 Max, macOS 27) on neutron's README; unvetted DX11 FEX-vs-Rosetta parity figures (FFXIV tie, Dota 2 faster) at blendlogic.com, Aug 2026, no named author | neutron README; blendlogic.com | self-reported / unvetted |

## 3. What has to become arm64, and what does not

| component today | target | owner | carries over? |
|---|---|---|---|
| Wine 11.16 unix side (`wine`, `wineserver`, `*.so`) x86_64 | arm64 Wine with the macOS-ARM64 work | CodeWeavers → upstream, or a community tree (neutron, `willfaust/wine`) | **rebuild**; blocked on a buildable public tree (§5 W1/W6/W7) |
| Wine PE side (x86_64-windows, i386-windows) + Wine Mono 10.4.1 + Gecko 2.47.4 (x86/x86_64 only, in `share/wine`; Gecko installed in the prefix) | `aarch64-windows` + ARM64EC/arm64x; the arm64 tree's own addon versions | Wine | rebuild |
| Base winemac DXMT hook: `scripts/wineandaqua-dxmt.patch` (453 lines, applied first by `build-engine-1116.sh:91`) | the arm64 tree's own DXMT hooks | CodeWeavers / tree owner | **not portable as written** — the whole `WineMetalLayer` interface and implementation sits inside `#if defined(__x86_64__)` (patch lines 112, 147), while `cocoa_window.m` uses it unconditionally. CrossOver's ARM64 path ships DXMT, so its tree very likely has an arm64 equivalent (inferred) — expect to replace this patch, not port it |
| Our winemac cross-process work (`scripts/winemac-crossprocess-{child-core,child,dxmt-glue,remote-layer}.patch` — four files, `ls` 2026-10-11. There is no 60262 workaround patch: that fix is upstream 6cfa941, and 60262 was closed as a duplicate of 42877 on 2026-10-11) | rebased onto the arm64 tree's DXMT hooks | **this repo** | rebase. These four contain no arch ifdefs, inline asm or wow64 thunks (grep), so expect API drift — but onto **someone else's** DXMT hook (above) and a winemac that has moved since 11.16 (§2 row 2). codeWonderland's patches are the nearest public precedent |
| DXMT PE DLLs (`d3d11`, `dxgi`, `winemetal`) — today Porting Kit's `v0.80-17-g79f6279`, a commit **not in** 3Shain/dxmt (INSTALL.md:131) | arm64x from DXMT CI or a release | 3Shain | swap — but upstream arm64x is a **second variable** on top of the architecture change |
| DXMT `winemetal.so` x86_64 — **built here** from `v0.80` + `scripts/dxmt-remote-layer-fallback.patch` (INSTALL.md:132), which the out-of-process Steam UI needs (C12–C30) | arm64, **rebuilt from source** with `scripts/dxmt-*.patch` (4 patches) against our own arm64 winemac | this repo | **rebuild**. The current recipe needs an x86_64 `llvm@15` from Intel Homebrew under Rosetta (`build-dxmt-fork.sh:18-22,41`) — P2 needs an arm64 LLVM. A CI artifact (arm64ec job, linked to 3Shain `wine-11.2`) is only a P1/smoke stand-in (§6 T1) |
| — (Rosetta does it today) | x86_64 emulation: FEX `xtajit64.dll` for the game; **`xtajit.dll` (WoW64 x86) too on any route that keeps Windows Steam** (31 native i386 PEs, `steamservice.exe` runs — §1). On a Mac-Steam-bridge route (neutron) Windows Steam drops out, and with it the i386 need **and** our out-of-process Steam UI work | FEX / CrossOver / FEX-darwin / neutron | **new dependency** — admitted only through P1's binary-admission gate |
| Wrapper dylibs (freetype, gnutls, MoltenVK, SDL2, GStreamer…) x86_64, dlopened by soname | arm64 builds (Homebrew's are arm64) | Homebrew | rebuild/relink, with the same soname/schannel gates as `build-engine-1116.sh:100-122`; MoltenVK only if anything still uses it |
| `Contents/Wineskin.app`, `wineskinlauncher` (x86_64) | — | — | **out of scope**: the launcher calls `wine64` directly (`launch-cs2-dxmt11.sh:64`) |
| x86_64 helper binaries (e.g. `~/cs2-patch/dlprobe`) and the x86_64 wine build tools | arm64 rebuilds where still needed | this repo | rebuild or retire |
| The game, mods (x86_64 PE) | unchanged — run under FEX | — | yes |
| `repatch.sh` IL patches (PDX.SDK, Colossal.IO, mscorlib, Game.dll badge) | unchanged | this repo | **should** apply untouched — they edit .NET IL, which Mono JITs to x86_64 and FEX then emulates. Whether each is still **needed** is a separate question: several fix Wine bugs that may differ on the arm64 tree (§6 T6, T6b) |
| `patch_cohtml` (a byte flip in x86_64 machine code) | unchanged | this repo | should hold: FEX emulates the patched bytes. Presence-only today — unpatched 1.6.2f1 on DXMT reached the menu once (C72) |
| Launcher and scripts | arch-aware paths, entitlement-bearing loader `.app` | this repo | **edit — 27 files** under `scripts/`, `launchers/` and `~/cs2-patch/*.sh` reference `x86_64-unix`, `*-windows` or `wine64`, and 25 hardcode `CS2dxmt11.app` (`grep -lE`, 9ef4111), including the evidence gate `cell-fingerprint.sh:44-45`. Keep the `wine64` symlink or change its ~19 call sites |

**Performance is the unknown that decides whether this is a port or a downgrade.** Today the
game's x86_64 code runs under Rosetta's AOT+JIT; afterwards it runs under FEX's JIT, and Unity
Mono's own JIT output is itself x86_64. The benchmark scene is CPU/sim-bound
(`gpuBoundPercent` 18–20 % at 2560×1440 on the M5 Max, `studio-home-1440-*`), so emulator speed
lands almost directly on frame rate.

## 4. Phases

Only P0 is current. P1–P4 are planning-only until their entry gate is met.

### P0 — Watch and fence (now → until P4 promotes)
- After every macOS update (major, point or Rapid Security Response): `arch -x86_64 /bin/ls /`. If
  it fails, James runs `softwareupdate --install-rosetta --agree-to-license` (a human step); then
  `bash scripts/boot-verify.sh` must PASS before any "the stack is broken" claim; one line in
  `~/cs2-patch/change-ledger.txt`.
- **Launcher preflight — ✅ BUILT 2026-10-11.** The `>>> rosetta-preflight` block in
  `launchers/launch-cs2-dxmt11.sh` runs the engine's own `wine64 --version` first, so a future
  arm64 engine passes untouched. If that fails, it checks `arch -x86_64 /usr/bin/true` to decide
  between "Rosetta 2 is not installed" (with the reinstall command) and "Wine cannot start" (with
  wine's output). C69 had failed silently. Test: `scripts/test-rosetta-preflight.sh`, 6 cases
  including a live run against the real engine; three mutants were observed red.
- **D4 enforcement** (deferred 2026-10-11 — revisit with D5): James turns off automatic macOS major
  upgrades before the macOS 28 release (a human step).
- `.gitignore` covers `*.mobileprovision`, `*.p12`, `*.cer` (added with this check, ahead of D2).
- Run the §5 watch list monthly (fold into `clean up`); record each run as a dated comment on #16.
- P0 never "exits"; it runs until P4 promotes. P1 starts on D1, independent of W-triggers.

### P1 — Prototype on someone else's build (no engine build of ours)
Entry: **D1 resolved** — resolved 2026-10-11 as *wait*, so P1 is parked until D1 is revisited (§7).
When it starts, do it early: P1 is the measurement that decides whether P2 is worth doing.
- **Binary admission (before any third-party binary runs — FEX-darwin, neutron, a DXMT CI
  artifact, CrossOver Preview):**
  (a) every download needs James's explicit OK;
  (b) pin a commit SHA and prefer building from source at it; a prebuilt binary is checked against
  the author's SHA256SUMS **and** a local build, both hashes recorded in the EXPERIMENTS row;
  (c) read the diff against its upstream (FEX tag, DXMT tag, the Wine tree) for anything touching
  network, filesystem or credentials — FEX-darwin is not a GitHub fork, so find its base first;
  (d) CrossOver Preview: `codesign -dv --verbose=4` and `spctl -a -vv` show the CodeWeavers
  Developer ID;
  (e) first boot with Steam offline. Anything that modifies the daily install (neutron's
  `install.sh` re-signs `/Applications/Steam.app`) needs its own explicit OK.
- **Fence the daily stack:** APFS-clone the 1.6.2f1 game dir into the bottle rather than
  downloading; block Steam updates for it (GOTCHAS § "The launcher never lets Steam update the
  game"); run `repatch.sh` **only with an explicit game dir** — its default target is a CrossOver
  bottle named `Steam` (`repatch.sh:11,14`), which is exactly what a P1 CrossOver bottle may be
  called; copy the daily `Settings.coc`; make no Paradox Mods subscription changes from the bottle
  (the playset is account-level); log out of Steam and delete the bottle when P1 ends. Record the
  bottle's Wine base version and DXMT version.
- **Instruments first:** `boot-verify.sh`, `perf-bench.sh` and `cell-fingerprint.sh` assume the
  wrapper layout (`Contents/SharedSupport/{wine,prefix}`, `drive_c/users/Wineskin`); a CrossOver
  bottle is `~/Library/Application Support/CrossOver/Bottles/<name>`, `users/crossover`. Extend
  them to a bottle layout before measuring, or every P1 row is `UNREVIEWED` (no `config.json`).
- Measure: T1, T3, T4, T5, T9, T10 and T11 (§6) on the borrowed build — no game patches first,
  then `repatch.sh` with the bottle's game dir.
- **Gate (decision rule, fixed now):** P1 passes if it reaches the menu with mods **and**
  `averageFps` is **≥ 70 %** of the reference, where:
  - **primary reference** — on a runtime that offers both (CrossOver): an x86_64 bottle under
    Rosetta on the same build, same day. This isolates FEX vs Rosetta from every other difference;
  - **secondary reference** — the daily x86_64 stack, same day: median of 3 clean runs per stack,
    warm-up discarded. Clean = vsync off, display awake, session unlocked, no Screen Sharing viewer
    (`docs/perf-pass-results.md` § Studio M0). The `studio-home-1440` rows (47.8 FPS) ran with
    vsync **on** and are **not** a baseline (`perf-pass-results.md:197-199`);
  - `simulationTicks` (recorded by `perf-bench.sh:133`) must not fall by more than the FPS margin —
    an emulated sim can hold frame rate by simulating less;
  - the difference must exceed the measured repeat spread; Studio M0 supplies the noise floor.
  Below 70 % the port is a downgrade: stay on Rosetta for as long as macOS 27 lasts and re-test each
  FEX release. (70 % is a judgment, not a measurement — James to confirm, §7 D3.) Confounds to name
  in the verdict: Wine base (an older one may predate 11.16's alt-tab fix, GOTCHAS:464), DXMT
  vintage, none of our winemac patches, no display-profile step.
- Exit: an `EXPERIMENTS.md` conclusion row (C-id + the `exp_` ids from `config.json`), with versions
  and hashes.

### P2 — Build our own arm64 Wine
Entry: P1 passed **and** either W1 (CodeWeavers' code public) or D5 chose P2-alt (a public
community tree — neutron, `willfaust/wine` — plus FEX-darwin).
- Mirror `scripts/build-engine-1116.sh` as `build-engine-arm64.sh`: source tarball or pinned commit
  + checksum, configure for `aarch64` unix + `aarch64,arm64ec,i386` PE, donor-free (Homebrew arm64
  freetype + gnutls; no Porting Kit dylibs — the x86_64 donor model in today's script does not carry
  over). Link flags per the wine-devel post (§2 row 3). Keep the `wine64` symlink.
- Self-check: today's only checks for the `macdrv_functions` export (`build-engine-1116.sh:144`),
  which is not arch-gated. Add a check that the DXMT layer class is present in the built
  `winemac.so`.
- DXMT: build from source with our 4 `scripts/dxmt-*.patch` against our arm64 winemac, on an arm64
  LLVM.
- Entitlement wrapper per §7 D2.
- Smoke ladder: `build-engine-1116.sh`'s self-check (`--version` at `:142`, the shim export at
  `:144`) and `wineboot -u` (`:188`), then G1–G4 from `docs/plans/build-wine1116-dxmt-engine.md` §6,
  then `scripts/dxtest.exe` (DX11 clear; it renders until killed — `steam-vanilla-d3d-split.sh:167-179`
  shows the harness) through DXMT before any game file is touched.

### P3 — Port this repo's work onto it
Entry: P2 smoke ladder green.
- Replace `wineandaqua-dxmt.patch` with the tree's own DXMT hooks; rebase the winemac cross-process
  patches onto them; rebuild; re-run `scripts/hosting-layer-tests.sh`.
- Drop in our arm64 DXMT build (P2) — the CI artifact lacks `dxmt-remote-layer-fallback.patch`.
- **New files, never edits to the daily launcher until P4:** `launch-cs2-arm64.sh` (wrapper path
  from a variable). The script set to make arch-aware is the 27/25-file `grep -lE
  'x86_64-unix|wine64|CS2dxmt11.app'` list (§3), including `cell-fingerprint.sh`. After any edit to
  a shared script, re-run boot-verify on the x86_64 wrapper. `scripts/test-update-check.sh` must
  stay green.
- A **second wrapper**, never the daily one: clone the game dir (APFS clone — same Data volume as
  `~/Applications`, measured with `df`; use `df`, not `du`, to judge space).

### P4 — Validate and promote
Entry: P3 complete. The x86_64 wrapper stays installed and launchable throughout.
- Full test plan §6 green, then James plays a session (admin walkthrough).
- Promote by swapping the default launcher target; keep the x86_64 wrapper until the Studio
  actually runs macOS 28.

## 5. Watch list (the P0 triggers)

| id | trigger | how to check |
|---|---|---|
| W1 | CodeWeavers' macOS-ARM64 core lands on gitlab.winehq.org, or CrossOver publishes source containing it | MR search, authors `bshanks` and `natbro`, terms "arm64 macOS", "x18", "PAGEZERO", "TSO"; status of open !11638 / !11737; [CrossOver source page](https://www.codeweavers.com/crossover/source) (26.3.0 only as of 2026-10-11 — the realistic route is CrossOver 27's LGPL source drop, early 2027) |
| W2 | A DXMT release after v0.80, with arm64x DLLs and an aarch64 unix side | `gh release list -R 3Shain/dxmt` |
| W3 | A FEX ARM64EC module for macOS works with a **public Wine tree we can build** (neutron's, `willfaust/wine`, CrossOver source) | `FEX-Emu/FEX` releases; `dbc-hbin/FEX-darwin` activity and the Wine hooks it names |
| W4 | Apple defines the post-27 games subset of Rosetta | developer.apple.com news |
| W5 | Wine 6cfa941 (60262) reaches a release — one fewer patch to rebase | wine release notes |
| W6 | neutron matures: a release that documents its entitlement route, or reports a Unity DX11 title at scale | `lixsldotnet/neutron`, `codeWonderland/neutron` releases |
| W7 | `willfaust/wine` gains a macOS (not iOS) branch | its branch list |
| W8 | The first macOS 28 beta: are the cross-arch kernel features still there? | Apple's beta release notes and the beta SDK's `os/arch/arm64.h` (the SDK comes with Xcode beta and needs no OS upgrade); reports of `os_cross_arch_is_supported(OS_CROSS_ARCH_X86_64)` and `arch -x86_64` on the beta. **Never by upgrading the Studio** (D4) |

## 6. Test plan (outcome-based)

**When:** T1, T3, T4, T5, T9, T10 and T11 also run at the end of **P1** on the borrowed build; the
full table runs at the end of **P4**.

| id | test | passes when | mutant / control |
|---|---|---|---|
| T1 | DXMT arm64 artifact is what it claims | `file` on the unix `.so` says arm64; `llvm-readobj --coff-load-config` on each PE DLL shows non-null CHPE metadata (that, not the machine field, is what makes ARM64X); `strings winemetal.so \| grep dxmt_acquire_remote_layer` hits (our fallback patch is in) | control: today's `winemetal.so` reports x86_64. **Mutant:** the stock CI artifact, which lacks `dxmt-remote-layer-fallback.patch`, must fail the `strings` check (guards GOTCHAS 2032's "built off the wrong branch renders black") |
| T2 | Engine is native | `file wine wineserver ntdll.so winemac.so winemetal.so` all arm64; **every pid attributed to the prefix** (`lsof -p <pid> \| grep <prefix>` — never by argv) reads `P_TRANSLATED` (0x20000) clear in `kinfo_proc.p_flag` via `sysctl kern.proc.pid.<pid>` (a short ctypes script) | **positive control:** the same script against the running x86_64 wrapper reads translated. Optional: a fresh macOS VM, which has no Rosetta, runs the P2 smoke ladder (needs James's OK) |
| T3 | Boot | `boot-verify.sh` PASS, GRACEFUL yes, 0 InvalidProgramException | control: the x86_64 wrapper's PASS the same day |
| T4 | Mods | force one mod to re-download (move `Plop the Growables` aside, as `change-ledger.txt:1963,1975`): files byte-identical, 0 IL load errors | — |
| T5 | Speed | `perf-bench.sh` ×3 on the arm64 stack vs ×3 x86_64 the same day, same display mode, clean conditions (P1 gate), warm-up discarded; report averageFps, gpuMs, cpuGameMs, 1 %-low, simulationTicks; P1's rule applied | noise floor: Studio M0 (owed — perf pass) |
| T6 | Patches still bite | **mutant: `patch_fshandle`** — in the cloned arm64 game dir only, restore pristine `mscorlib.dll` from `.bak` and boot: ≥ 1 "Invalid handle" / "Failed to read settings file" in Player.log (the every-boot defect, `repatch.sh:103-110`, "6 errors -> 0"); re-apply → 0. **Patcher self-test** on a scratch copy: pristine → patches; second run → "already patched"; one anchor byte flipped → "ERROR … refusing", non-zero exit (`patch_fshandle.py:111`). cohtml: flip present at its anchor | if the fshandle mutant stays green on the arm64 tree, record **"not needed there"** — never count it as a pass. ⚠ Not `patch_lockleak`: it only fires on Wine's garbage-errno throw, which Wine 11 fixed (`repatch.sh:15-17`), so removing it changes nothing on demand |
| T6b | Patches still **needed** | each Wine-bug patch (R1/R2, `docs/patch-inventory.md:34-36`) removed one at a time on the clone: does its documented failure still occur? | the mutant is the removal; record needed / not needed per patch |
| T7 | Steam UI | store renders with text, 0 GPU crashes in the webhelper log, game still reaches MainMenu on the same build (`docs/steam-ui-findings.md:177-194`) | control: x86_64 storefront wrapper. **n/a** on a Mac-Steam-bridge route — record that, not a pass |
| T8 | Launcher paths | `scripts/test-update-check.sh` green; `cs2-display-profile.sh` classifies the Studio Display `home` (`:51-90`); `CS2_UPDATE` dialog shows | — |
| T9 | Alt-tab / exclusive fullscreen | alt-tab ×10 with no freeze — the defect 11.16 fixed (GOTCHAS:464); audio plays; controller detected | control: x86_64 wrapper |
| T10 | Soak | 2 h of play plus 10 back-to-back benchmarks, 0 crashes; record FEX's TSO mode. Diagnostic, not a gate: rerun with TSO forced off — if crashes appear, TSO coverage is load-bearing (TSO is per-thread and not inherited, §2 row 3; CS2's job system is heavily multithreaded, so a missed thread corrupts intermittently rather than failing cleanly) | control: x86_64 wrapper, same session length |
| T11 | Saves and runtime-patching mods | a save made on x86_64 loads on arm64 and an arm64 save loads back on x86_64; a Harmony mod (patches at runtime, emitting x86_64) loads and its effect is visible | — |

## 7. Open decisions (James)

- **D1** — P1's borrowed build. Options: (a) re-licence CrossOver (expired 2026-08-21) for the
  Preview, which allows the clean x86_64-vs-ARM64 same-build A/B; (b) **neutron** — free, LGPL,
  built from source, but mostly AI-written, 1 day old at the check, its entitlement route unknown,
  and its installer re-signs `/Applications/Steam.app` ad hoc; it drops Windows Steam, so it cannot
  test our Steam UI work; (c) wait for our own build after W1.
  **DECIDED 2026-10-11 (James): (c) wait.** No borrowed build now. Revisit at the monthly watch run if
  W6 trips (neutron documents its entitlement route / matures) or CrossOver 27 ships.
- **D2** — Entitlement route for P2: the free Apple account + `…-unmanaged` profile. **Disabling SIP
  is recorded as upstream context only and is not an option** (machine rule: no changes to system
  security settings). The free route is not footprint-free: an Apple ID in Xcode, a development
  certificate and key in the login keychain, a per-user profile under
  `~/Library/MobileDevice/Provisioning Profiles`, and the Studio's UDID registered with Apple. Free
  development profiles generally expire after 7 days — **unverified for `…-unmanaged`**; if it
  applies, the launcher must check profile expiry before launch and fail with a clear message. The
  UDID, Team ID, App ID, profile, certificate and any `codesign -d --entitlements` output stay
  outside the repo (`~/cs2-patch/`); the repo carries only a generic entitlements template.
- **D3** — Is 70 % of today's frame rate (against the references in P1's gate) the right bar for
  "port, not downgrade"? **DECIDED 2026-10-11 (James): 70 % stands.**
- **D4** — Hold the Studio on macOS 27 until P4 promotes (recommended, §1), with automatic major
  upgrades turned off. **DEFERRED 2026-10-11 (James):** macOS 27 has just shipped and 28 is ~a year
  out, so nothing to fence yet — revisit with D5. The near-term risk is a 27.x point update removing
  Rosetta again (C69), which P0's post-update check and launcher preflight cover, not D4.
- **D5 — decide by 2027-05-01** (before the macOS 28 betas): if W1 has not tripped, choose one of
  (a) CrossOver ARM64 as the daily runtime, without our patches (losing the out-of-process Steam UI);
  (b) P2-alt on a public community tree + FEX-darwin; (c) an indefinite hold on macOS 27 (D4).

Outcomes of D1–D5 and each monthly watch-list run go on #16 as dated comments, not into this plan.

## 8. Rollback

Until macOS 28: launch the x86_64 wrapper. Its engine, prefix and game dir are never written by
P1–P4. Shared state that **is** touched is fenced: `~/cs2-patch` scripts (P3 writes new files only
and re-runs boot-verify on the x86_64 wrapper after any shared edit), `repatch.sh` (explicit game dir
only), the Paradox Mods playset (no subscription changes from a test bottle), the Steam session
(same-account sessions swap; harmless). Once Rosetta is gone the x86_64 wrapper is **frozen**: it
cannot be relinked or rebuilt (the x86_64 wine build tools die — C69 — and the DXMT build needs
Intel-Homebrew `llvm@15`). After macOS 28 there is no rollback for an x86_64 stack, which is why D4
exists.

## 9. Risks

- CodeWeavers' macOS-ARM64 Wine work may stay CrossOver-only for a long time; P2 then depends on a
  community tree (D5).
- FEX on macOS is days old in public; FEX-darwin needs Wine hooks that may not match whatever Wine
  tree becomes available.
- Apple may withdraw the cross-arch kernel features with Rosetta (§1, W8) — which would end the
  arm64 route as well.
- Our cross-process winemac work has never been built for arm64. The cross-process patches are
  arch-neutral C/ObjC, but the base DXMT hook they sit on is x86_64-gated (§3) and upstream winemac
  has moved; the risk is the rebase onto a foreign DXMT hook, not the instruction set.
- Performance under FEX for a sim-bound Unity title is unmeasured anywhere public, and TSO
  coverage gaps would show as intermittent corruption rather than a clean failure (T10).
- Third-party JIT code runs inside a process holding the Steam login (P1 binary admission).

## Review corrections (triple-check 2026-10-11)

Four lenses, each an independent agent against HEAD `9ef4111`: platform-facts (Opus),
architecture + rollback (Opus), correctness of local claims (Sonnet), security + test plan (Opus).
Every BLOCKER below was spot-checked inline before folding. Verdicts as written: P0
build-ready-with-fixes (all four); P1–P4 needs-rework (architecture, security) / plan-sound with
fixes (platform-facts, correctness).

**Blockers (all folded):**
1. **The DXMT unix side cannot be "swapped from CI".** The live `winemetal.so` is built here with
   `dxmt-remote-layer-fallback.patch` (INSTALL.md:132), which the Steam UI needs; the build needs
   x86_64 Intel-brew `llvm@15` (`build-dxmt-fork.sh:41`). §3 row, P2, P3, T1 mutant.
2. **The winemac base patch is x86_64-gated.** `wineandaqua-dxmt.patch:112,147` wraps
   `WineMetalLayer` in `#if defined(__x86_64__)`. "API drift, not arch" was true only of the five
   cross-process patches. §3, P2 self-check, P3, §9.
3. **The P1 baseline was a disqualified series.** `studio-home-1440` ran with vsync on
   (`perf-pass-results.md:197-199`). P1 gate, T5.
4. **T6's mutant could not go red.** `patch_lockleak` needs Wine's garbage-errno throw, fixed in
   Wine 11 (`repatch.sh:15-17`); replaced by the deterministic `patch_fshandle` mutant plus a
   patcher self-test. T6, T6b.

**Should-fix (all folded):** Windows Steam runs i386 code (31 native i386 PEs; §1, §3);
`xtajit.dll` is therefore needed on any Windows-Steam route · the P2 smoke ladder cited a § 6
that holds G1–G4, not `--version`/`wineboot`/`dxtest` · P1 needs instruments for a bottle layout
or its rows are `UNREVIEWED` · P1 entry was coupled to W-triggers it does not need · no decision
date (D5) · rollback leaked through shared scripts, `repatch.sh`'s default and the account-level
playset · no supply-chain gate (P1 binary admission) · D2 "touches nothing system-wide" was false,
SIP listed as an option, 7-day expiry unaddressed, nothing kept identifiers out of the repo · T2's
control could not be run on purpose (now `P_TRANSLATED` per pid with a positive control) · T7's
criteria did not exist as named · missing tests: alt-tab, soak/TSO, saves both ways, Harmony ·
W3 could never trip ("upstream Wine" lacks W1's core) · §2 row 2 overstated the absence (!11638,
!11737); !12257 closed 10-09 not 10-06; !11736 is natbro's · §2 "no Unity DX11 report" is now
false (neutron, self-reported) · "neutron — unverified" is identified · the arm64 `winemetal.so`
comes from the arm64ec job, which **is** packaged · CrossOver offers no Preview source.

**Corrected in synthesis (lens claims not adopted as stated):** the architecture lens said
`repatch.sh` defaults to the daily game dir; its default is a CrossOver bottle named `Steam`
(`repatch.sh:11,14`) — a different hazard, and the one P1 now fences. The security lens quoted the
patchers' refusal as "UNEXPECTED … refusing"; `patch_fshandle.py:111` prints "ERROR: … refusing".

**Owed (not runnable inside a review):** the contents of the DXMT arm64ec artifact, the FEX-darwin
zip and neutron's tree (each needs a download — James's OK); the CrossOver Preview blog post body
(open in a browser); whether free `…-unmanaged` profiles expire after 7 days; whether
`src/winemetal/unix/meson.build:13` really refuses without `wine_install_path` (lens claim, not
re-read here).

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| 2026-10-11 | full check (1) | platform-facts · architecture + rollback · correctness · security + test plan | 4 agents (≤4 concurrent) + inline spot-check of every BLOCKER | Opus 5.5 ×3, Sonnet ×1; synthesis Opus 5.5 | `9ef4111` | build-ready-with-fixes (P0); P1–P4 corrected, re-check before P1 |

Key paths: `scripts/build-engine-1116.sh`, `scripts/build-dxmt-fork.sh`,
`scripts/wineandaqua-dxmt.patch`, `scripts/winemac-crossprocess-*.patch`, `scripts/dxmt-*.patch`,
`launchers/launch-cs2-dxmt11.sh`, `repatch.sh`, `patches/`, `scripts/boot-verify.sh`,
`scripts/perf-bench.sh`, `scripts/cell-fingerprint.sh`, `docs/perf-pass-results.md`.
