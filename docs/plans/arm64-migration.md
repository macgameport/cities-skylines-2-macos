# Move the stack off Rosetta: arm64 Wine + FEX + ARM64EC DXMT

> **Status: planned, not started. Not yet triple-checked — run `check it` before any build step.**
> Tracking: [#16](https://github.com/macgameport/cities-skylines-2-macos/issues/16). Written
> 2026-10-10. Every external fact below carries the date it was checked; most of them will move
> before this is built, so the watch list in §5 is part of the plan, not an appendix.

## 1. Why, and the deadline

Every executable piece of this stack is x86_64 and runs under Rosetta 2. Measured 2026-10-10 on
the live wrapper (`file` on each): `wine`, `wineserver`, `ntdll.so`, `winemac.so`, DXMT's
`winemetal.so`, the wrapper's own launcher binary and every dylib in `Contents/Frameworks`
(`libMoltenVK`, `libfreetype`, `libgnutls`, …). `Cities2.exe` and `steam.exe` are both
PE32+ x86-64 (`file`, same day) — so the emulation that matters is x86_64, not i386.

Apple, 2026-09-01 ([developer news](https://developer.apple.com/news/?id=w5ngl9k2)): macOS 27 is
the last release with full Rosetta. macOS 28 keeps an **undefined** subset for "older,
unmaintained gaming titles". Assume a self-built x86_64 Wine host does not qualify. macOS 28
betas: expected ≈ June 2027. 27.0.1 already removed Rosetta once on this machine (C69, GOTCHAS
2026-10-10).

**The decision this plan forces before anything else:** do not move the Studio to macOS 28 until
§4 phase P4 has promoted an arm64 stack. Until then, a macOS 28 upgrade is an upgrade with no
rollback for the game.

## 2. What is verified (checked 2026-10-10)

| fact | source | confidence |
|---|---|---|
| CodeWeavers has native ARM64 Wine on macOS, with FEX emulating i386/x86_64 through ARM64EC; shipped in CrossOver Preview | [wine-devel, B. Shanks, 2026-08-07](https://list.winehq.org/hyperkitty/list/wine-devel@list.winehq.org/thread/CKG5CEN2BE5VRXZ7O7NX4YUSBH3247WH/) | primary |
| The **core** macOS-ARM64 changes (x18 custom ABI, 4K-page spawn, TSO, PAGEZERO layout) are **not upstream and not submitted as MRs** — only preparatory pieces merged (!11267, !11402, !11668, !11736); !12257 closed unmerged 2026-10-06; wine 11.17–11.19 release notes are silent | gitlab.winehq.org MR search | primary, absence-of-evidence |
| The OS APIs exist in the local macOS 27.0 SDK: `os_set_custom_x18_abi_enabled` (`os/arch/arm64.h`, 26.4), `posix_spawnattr_set_4k_page_size_np` (`spawn.h`, 26.0), `os_cross_arch_is_supported` (26.6), `thread_set_x86_64_compat` | `xcrun --show-sdk-path` headers | primary — ⚠ the wine-devel post says **26.5** for x18 + 4K spawn; the SDK annotations say 26.4 / 26.0 |
| Entitlement: `com.apple.developer.cross-architecture-support` (paid account) or `…-unmanaged` (free account), via an App ID + registered UDID + provisioning profile in a `.app` beside the loader; disabling SIP is the unrecommended alternative | wine-devel post | primary for the names; **Apple documents neither** (not in the entitlements reference, not in the SDK) |
| DXMT CI builds ARM64EC/arm64x PE DLLs (#202 merged 2026-08-04, #209 2026-09-17) **and** a native `build-clang-release-arm64-macos` job (the unix side) — but the `package` job ships only gcc x86_64, gcc x86 and clang ARM64EC, and the latest release (v0.80, 2026-04-23) predates all of it | `3Shain/dxmt` `ci.yml`, `gh release list` | primary; the arm64 artifact's contents are **unopened** |
| Upstream FEX publishes no macOS ARM64EC module (FEX-2610, 2026-10-07: no assets). A community port exists: [`dbc-hbin/FEX-darwin`](https://github.com/dbc-hbin/FEX-darwin) (created 2026-10-07, v0.1.0, 0 stars) builds `xtajit64.dll` (x64) + `xtajit.dll` (WoW64 x86) and **requires Wine-side hooks** (shared data, JIT write-protection, JIT allocation, WoW64 guest windows) — it is not a drop-in for upstream Wine | GitHub | primary for existence; its fitness is untested |
| CrossOver Preview's ARM64 path bundles ARM64 DXMT, has **no D3DMetal**, needs macOS 26.5+, cannot convert existing bottles; CrossOver 27 (Apple-silicon only) is expected early 2027 | CodeWeavers blog via search summaries only — the blog returned 403 to every fetch | **second-hand** — open it in a browser before relying on it |
| No public report of CS2 (or any Unity DX11 title) on the ARM64 path | CodeWeavers compat page, AppleGamingWiki | absence-of-evidence |

## 3. What has to become arm64, and what does not

| component today | target | owner | carries over? |
|---|---|---|---|
| Wine 11.16 unix side (`wine`, `wineserver`, `*.so`) x86_64 | arm64 Wine with the macOS-ARM64 work | CodeWeavers → upstream | **rebuild**; blocked on the code being public (§5 W1) |
| Wine PE side (x86_64-windows, i386-windows) | `aarch64-windows` + ARM64EC/arm64x | Wine | rebuild |
| Our winemac.drv work (`scripts/winemac-crossprocess-*.patch`, the 60262 workaround if 6cfa941 has not landed) | rebased onto the arm64 tree | **this repo** | rebase; winemac is unix-side C/ObjC, so expect API drift, not arch-specific code |
| DXMT PE DLLs (`d3d11`, `dxgi`, `winemetal`) | arm64x from DXMT CI | 3Shain | swap |
| DXMT `winemetal.so` x86_64 | arm64 from CI job `build-clang-release-arm64-macos` | 3Shain | swap — **contents unverified** (§6 T1) |
| — (Rosetta does it today) | x86_64 emulation: FEX `xtajit64.dll` (plus `xtajit.dll` only if any 32-bit PE is still loaded — inventory it in P1) | FEX / CrossOver / FEX-darwin | **new dependency** |
| Wrapper dylibs (freetype, gnutls, MoltenVK, SDL2, GStreamer…) x86_64 | arm64 builds (Homebrew's are arm64) | Homebrew | rebuild/relink; MoltenVK only if anything still uses it |
| The game, Steam, mods (x86_64 PE) | unchanged — run under FEX | — | yes |
| `repatch.sh` IL patches (PDX.SDK, Colossal.IO, mscorlib, Game.dll badge) | unchanged | this repo | **should** be untouched — they edit .NET IL, which Mono JITs to x86_64 and FEX then emulates. Verify, don't assume (§6 T6) |
| `patch_cohtml` (a byte flip in x86_64 machine code) | unchanged | this repo | should hold: FEX emulates the patched x86_64 bytes. Verify (§6 T6) |
| Launcher, boot-verify, perf-bench, display profile | arch-aware paths (`x86_64-unix` → `aarch64-unix`), entitlement-bearing loader `.app` | this repo | edit |

**Performance is the unknown that decides whether this is a port or a downgrade.** Today the
game's x86_64 code runs under Rosetta's AOT+JIT; afterwards it runs under FEX's JIT, and Unity
Mono's own JIT output is itself x86_64. The benchmark scene is CPU/sim-bound
(`gpuBoundPercent` ~20 % at 2560×1440 on the M5 Max, `studio-home-1440-*`), so emulator speed
lands almost directly on frame rate.

## 4. Phases

Only P0 is current. P1–P4 are planning-only until their entry gate is met.

### P0 — Watch (now → until a gate in §5 trips)
- After every macOS update: `arch -x86_64 /bin/ls /` before believing any "wine is broken" symptom.
- Run the §5 watch list monthly (fold into `clean up`).
- **Do not upgrade the Studio to macOS 28** (§1).
- Exit: any of W1/W2/W3 trips.

### P1 — Prototype on someone else's build (no build of ours)
Entry: CrossOver Preview (or CrossOver 27) ARM64 is obtainable, **or** a community ARM64EC Wine
(e.g. the `neutron` tool named in research — unverified) is. ⚠ CrossOver's licence here expired
2026-08-21; whether the Preview needs one is open (§7 D1).
- Install CS2 in a fresh ARM64 bottle on DXMT. No game patches first, then `repatch.sh` against
  that bottle's game dir.
- Measure the same three things the x86_64 stack is held to: boot to menu (SceneFlow `MainMenu
  reached`, graceful exit), a mod download through Paradox Mods, and `-benchmark`.
- **Gate (decision rule, fixed now):** P1 passes if it reaches the menu with mods and the
  benchmark `averageFps` is **≥ 70 %** of the x86_64 stack's `studio-home-1440` median on the same
  machine and display mode. Below 70 % the port is a downgrade: stay on Rosetta for as long as
  macOS 27 lasts and re-test each FEX release. (70 % is a judgment, not a measurement — James to
  confirm, §7 D3.)
- Exit: a recorded verdict row in `EXPERIMENTS.md`, with the bottle's versions.

### P2 — Build our own arm64 Wine
Entry: W1 (code public) **and** P1 passed.
- Mirror `scripts/build-engine-1116.sh` as `build-engine-arm64.sh`: source tarball + checksum,
  configure for `aarch64` unix + `aarch64,arm64ec,i386` PE, donor-free (Homebrew arm64 freetype +
  gnutls; no Porting Kit dylibs — the x86_64 donor model in today's script does not carry over).
- Entitlement wrapper per §7 D2.
- Smoke ladder as in `build-wine1116-dxmt-engine.md` §6: `wine64 --version`, `wineboot`, then
  `scripts/dxtest.exe` (DX11 clear) through DXMT before any game file is touched.

### P3 — Port this repo's work onto it
Entry: P2 smoke ladder green.
- Rebase the winemac cross-process patches; rebuild; re-run `scripts/hosting-layer-tests.sh`.
- Drop in DXMT arm64x + arm64 `winemetal.so` (or build DXMT from source if no release yet).
- Teach the launcher, `boot-verify.sh`, `perf-bench.sh`, `build-*.sh` and
  `cs2-display-profile.sh` the new paths; `scripts/test-update-check.sh` must stay green.
- A **second wrapper**, never the daily one: clone the game dir (APFS clone, as in 2026-08-23).

### P4 — Validate and promote
Entry: P3 complete. The x86_64 wrapper stays installed and launchable throughout.
- Full test plan §6 green, then James plays a session (admin walkthrough).
- Promote by swapping the default launcher target; keep the x86_64 wrapper until the Studio
  actually runs macOS 28.

## 5. Watch list (the P0 triggers)

| id | trigger | how to check |
|---|---|---|
| W1 | CodeWeavers' macOS-ARM64 MRs appear on gitlab.winehq.org, or a CrossOver Preview **source** tarball with them is published | MR search: author `bshanks`, terms "arm64 macOS", "x18", "PAGEZERO", "TSO"; CodeWeavers' CrossOver source download page (URL not yet checked) |
| W2 | A DXMT release ships arm64x DLLs **and** an arm64 unix side | `gh release list -R 3Shain/dxmt` |
| W3 | FEX (upstream or a maintained fork) publishes a macOS ARM64EC module that works with upstream Wine | `FEX-Emu/FEX` releases; `dbc-hbin/FEX-darwin` activity |
| W4 | Apple defines the macOS 28 games subset of Rosetta | developer.apple.com news |
| W5 | Wine 6cfa941 (60262) reaches a release — one fewer patch to rebase | wine release notes |

## 6. Test plan (executed at the end of P4; outcome-based)

| id | test | passes when | mutant / control |
|---|---|---|---|
| T1 | DXMT arm64 artifact is what it claims | `file` on its unix `.so` says arm64; PE DLLs show ARM64X machine type | control: today's `winemetal.so` reports x86_64 |
| T2 | Engine is native | `file wine wineserver ntdll.so winemac.so winemetal.so` all arm64; `arch -x86_64 /bin/ls /` failing (Rosetta absent) does not stop a launch | run T2 on a machine/VM user with Rosetta removed, or after `softwareupdate` removes it again |
| T3 | Boot | `boot-verify.sh` PASS, GRACEFUL yes, 0 InvalidProgramException | control: the x86_64 wrapper's PASS the same day |
| T4 | Mods | force one mod to re-download (move `Plop the Growables` aside, as 2026-10-10): files byte-identical, 0 IL load errors | — |
| T5 | Speed | `perf-bench.sh` ×3 on the arm64 wrapper vs ×3 x86_64 the same day, same display mode; report averageFps, gpuMs, cpuGameMs, 1 %-low; P1's 70 % rule applied | noise floor from the x86_64 triplet |
| T6 | Patches still bite | each `repatch.sh` patcher reports "already applied" after a fresh apply, and the cohtml flip is present at its anchor; remove one patch (PDX.SDK lockleak) → the documented failure returns | the mutant IS the removed patch |
| T7 | Steam UI | Steam store renders out-of-process (`docs/steam-ui-findings.md` criteria) | control: x86_64 storefront wrapper |
| T8 | Launcher paths | `scripts/test-update-check.sh` green; display profile classifies the Studio Display `home`; `CS2_UPDATE` dialog shows | — |

## 7. Open decisions (James)

- **D1** — CrossOver Preview for P1: re-licence CrossOver (expired 2026-08-21), or wait for a free
  route (a community ARM64EC Wine, or our own build after W1)?
- **D2** — Entitlement route for P2: a free Apple account + `…-unmanaged` profile (needs the
  Studio's UDID registered; touches nothing system-wide) vs disabling SIP (system-wide; not
  recommended upstream). Recommendation: the free-account profile.
- **D3** — Is 70 % of today's frame rate the right bar for "port, not downgrade"?
- **D4** — Hold the Studio on macOS 27 until P4 promotes (recommended, §1).

## 8. Rollback

Until the Studio runs macOS 28, rollback is "launch the x86_64 wrapper" — it is never modified by
P1–P4 (separate bottle/wrapper, cloned game dir). After macOS 28 there is no rollback for an
x86_64 stack, which is why D4 exists.

## 9. Risks

- The macOS-ARM64 Wine work may stay CrossOver-only for a long time; P2 then has no source.
- FEX on macOS is weeks old in public; FEX-darwin needs Wine hooks that may not match whatever
  Wine tree becomes available.
- Our cross-process winemac work has never been built for arm64. The macOS APIs it uses (CALayer
  hosting, IOSurface) are architecture-neutral, so the risk is Wine-tree drift between 11.16 and
  whatever arm64 tree exists, not the architecture itself.
- Performance under FEX for a sim-bound Unity title is unmeasured anywhere public.

## Review log

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| — | none yet | — | — | — | — | not checked |

Key paths: `scripts/build-engine-1116.sh`, `launchers/launch-cs2-dxmt11.sh`, `repatch.sh`,
`patches/`, `scripts/winemac-crossprocess-*.patch`, `scripts/boot-verify.sh`,
`scripts/perf-bench.sh`.
