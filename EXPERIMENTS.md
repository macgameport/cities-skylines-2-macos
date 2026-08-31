# Experiment ledger

> **Read the "Conclusions register" below before designing any new test.** It exists so a later
> session can tell what we already know, how much to trust it, and what would overturn it — without
> re-deriving it from 2,500 lines of `GOTCHAS.md` prose. Checked by `scripts/check-experiments.py`,
> which `button up` runs.

## ✅ RESOLVED 2026-08-30 — the whole "renders art, no text" thread was one word: `nohup`

**Steam's visible UI works on the self-built wine 11.16 + DXMT engine.** Proof:
[`docs/images/steam-renders-with-text.png`](docs/images/steam-renders-with-text.png) (`exp_d7dd0d`)
— storefront, menus, nav, store copy and review counts, all legible.

The chain, every link measured (C10, C11, C4):

1. `scripts/steam-render-cell.sh` launched Steam via **`nohup`**.
2. macOS **purges `DYLD_*` when exec'ing a SIP-protected system binary**, and `/usr/bin/nohup` is
   one. (So are `env` and `/bin/bash`.)
3. This engine's `win32u.so` carries only an `@loader_path/` rpath, so without
   `DYLD_FALLBACK_LIBRARY_PATH` it **cannot find its own `wine/lib/libfreetype.dylib`**.
   PK 11.0's carries `@loader_path/../../` as well, which is why PK always looked immune.
4. No FreeType → DirectWrite enumerates **204 families** but rasterises **zero** coverage → Chromium
   draws art and not one glyph.
5. Remove the word `nohup`: FreeType failures **63 → 0**, glyphs rasterise in-tree, and the client
   renders **with text** under the exact `--in-process-gpu` config previously blamed for killing it.

**Nothing about Steam, CEF, DXMT, MoltenVK, ANGLE, rasterisation, glyph atlases, occlusion,
compositing or macOS was ever wrong.** A week of eliminations chased an artifact of the measuring
apparatus. The daily launcher was never affected — it execs wine directly — which is exactly why the
*game* had fonts the whole time and only *cells* did not.

**✅ Durable fix APPLIED 2026-08-30 — and it needed no rebuild.** `install_name_tool -add_rpath
"@loader_path/../../"` on the four modules that dlopen a bare soname (`win32u`, `dwrite`, `crypt32`,
`secur32`), then `codesign -f -s -` because add_rpath invalidates the ad-hoc signature. The engine
now resolves its own libraries the way PK's does.

| test | before | after |
|---|---|---|
| `wine notepad`, **no DYLD var at all** | 7 FreeType failures | **0** |
| Steam via **`nohup` AND no DYLD** — the exact broken combination | 63 failures, no glyph coverage | **0 failures, `GLYPHS RASTERISE` in-tree** |
| game boot | — | `MainMenu reached`, log timestamp postdating the change |

**Two premises checked rather than assumed, because both could have sunk this:**
- **PK really is immune** — measured directly this time (`wine notepad`, PK, no DYLD → **0**
  failures). The earlier claim was inferred from the rpath difference alone and had never been run.
- **A bare-soname `dlopen` really does consult `LC_RPATH`.** dyld only uses rpath for `@rpath/…`
  load commands, so this was genuinely in doubt. Verified with a purpose-built x86_64 probe
  carrying a baked-in rpath: it resolves `libfreetype.dylib` with every DYLD var unset.

Made durable in `scripts/build-engine-1116.sh` (step 8) so a rebuild does not silently lose it.
⚠ That step was appended using `$ENGINE`, which **does not exist** in that script — it would have
skipped every module in silence. Corrected to `$E` and dry-run against the real tree.

### ❓ OPEN HYPOTHESIS: is the GPU crash the VPN's `utun` interface? (2026-08-30)

**Raised by James, and it names a bias worth stating plainly:** *"when the VPN fails you think
whatever you are working on is failing due to timeouts."* That is exactly what happened earlier the
same day — a `steam.exe -shutdown` that blocked past three minutes was attributed to wine being slow
to spawn a helper, and only reattributed to the tunnel when he raised it. **A timeout is ambiguous
evidence and this project has been resolving the ambiguity toward "the thing under test is broken".**

**The specific version, which is testable.** The GPU process's own log is full of wine network
failures — `GetAdaptersAddresses failed: 2` (ERROR_FILE_NOT_FOUND), `Failed to read DnsConfig`,
WPAD/DHCP failures — and the traced crash is a **null read at offset `0x18` inside a wine syscall**,
in a process whose module list includes `nsi.dll`, `IPHLPAPI.DLL` and `nsiproxy.sys`. A `utun`
interface wine's IPHLPAPI cannot describe is a plausible source of a null return that nothing checks.

| | |
|---|---|
| baseline, **VPN UP** (`utun4`), network up | **6 crashes**, black window, fonts healthy (`exp_` = `vpn-up-baseline`) |
| **VPN DOWN** | **NOT YET RUN** — needs the tunnel dropped for ~3 minutes |

⚠ **Evidence AGAINST, stated so this is not adopted on plausibility alone:** the crash count has
been **exactly 6** in every cell today — default backend, software rendering, forced D3D11, builtin
CRT, patched DXMT. If it were driven by a flapping tunnel we would expect variation across a day in
which the tunnel was admittedly unreliable. That is a real argument that the cause is deterministic
and internal, not environmental. The A/B settles it either way and costs one cell.

**Only 6 of 16 fingerprinted cells record network state at all** — the ones after that field was
added. Every earlier cell in this investigation is silent on it, which is precisely the gap this
ledger exists to close, reopened one level up.

### 🔬 The fastfail, traced: a NULL read at +0x18 inside a wine syscall (2026-08-30)

`WINEDEBUG=+seh` on the out-of-process client gives the whole sequence on one thread, and it is
**deterministic** — same address every crash, every launch:

```
handle_syscall_fault code=c0000005 flags=0 addr=0x2179833df
  info[0]=0  info[1]=0x18                 <- READ (info[0]=0) from address 0x18
handle_syscall_fault returning to user mode ip=0x6fffe4f62a37 ret=c0000005
err:seh:NtRaiseException Unhandled exception code c0000409 addr 0x6ffffecd98fe
```

**Read it in order:** a **null-pointer read at offset 0x18** faults *inside a wine syscall*
(`handle_syscall_fault`, not an ordinary user-mode fault). Wine converts it to `c0000005` and
returns it to Windows-side code, which does not handle it and calls **`abort()`**.

The `c0000409` end of it is fully identified — disassembled from the module actually loaded:

| fact | value |
|---|---|
| faulting instruction | `int 0x29` — `__fastfail` |
| code in `ecx` | **7** = `FAST_FAIL_FATAL_APP_EXIT` |
| lead-in | `mov ecx,0x16` (`raise(SIGABRT)`), abort-behaviour check, then the fastfail — the UCRT's **`abort()`** |
| module | `C:\windows\system32\ucrtbase.dll`, loaded **`native`** (a real Microsoft CRT is installed in this prefix, overriding wine's builtin) |

**So it is not memory corruption, not a stack-cookie/GS violation, not an invalid CRT parameter.**
It is an unhandled access violation that becomes a deliberate abort. Combined with the
backend-independence result above, the GPU process dies from a **null dereference in wine's syscall
path that has nothing to do with graphics**.

⚠ **Tested and negative:** forcing wine's builtin CRT (`WINEDLLOVERRIDES=…;ucrtbase=b`) leaves the
crash count unchanged at 6. The native CRT is where the abort *surfaces*, not its cause. (The
override was not independently confirmed to have applied — worth verifying before relying on it.)

⚠ **Two dead ends, recorded so they are not retried.** `--enable-logging=stderr --v=1` injected via
the shim reaches the real webhelper's command line but yields **no** GPU-process log output — the
fault precedes Chromium's logging. And mapping the fault address to a module across the whole log is
**unsound**: bases differ per process, and doing so named the wrong DLL and produced a garbage
disassembly. Scope the module list to the **crashing thread id**, which the wine log prefixes.

**Next:** `ip=0x2179833df` is a *unix-side* address, so the null deref is in a wine `.so` or a
native dylib, not in Chromium's PE code. Identifying that mapping is where a next round starts.

### 🎯 The GPU-process crash is BACKEND-INDEPENDENT — it is not a graphics fault (2026-08-30)

Ran the out-of-process client on the default backend and on **pure software rendering**
(`--use-angle=swiftshader`, which touches no Metal, no DXMT and no GPU driver at all), fonts healthy
in both:

| cell | backend | GPU crashes (this launch) | window |
|---|---|---|---|
| `default-oop-control` | default | **6** | black, **40,903 B** |
| `swiftshader-oop` | software only | **6** | black, **40,903 B — byte-identical** |

**Same crash count, byte-identical capture, with the entire graphics stack swapped out.** So the
`0xC0000409` fastfail is not a Metal, DXMT, ANGLE-backend or presentation fault — it is something
generic about running Chromium's GPU process under wine on this stack.

**This is the strongest elimination in the whole Steam-UI thread**, because it does not depend on
reading anyone's source: swapping the renderer for a software one changes nothing at all. Everything
downstream — cross-process swapchains, the CHILD-window FIXME, the four-refusal chain — is not
merely unreachable (previous section) but **the wrong tree entirely**. `0xC0000409` is Chromium's
`__fastfail`, i.e. a deliberate `CHECK`/`NOTREACHED` abort, so the GPU process is *choosing* to die
on a failed invariant. Finding which one is the next question, and it is a Chromium/wine question,
not a graphics one.

⚠ **Instrument defect found and fixed in the same session — earlier crash counts are VOID.** The
harness reported "gpu-process crashes this launch" using `grep -c` over the whole of
`cef_log.txt`, **which accumulates across every launch ever**. That is where the 107 / 113 / 119
figures in earlier entries and commit messages came from; they are cumulative totals, not
per-launch, and must not be compared against anything. The harness now writes a marker into the log
before starting Steam and counts only lines after it. Every number above is post-fix.

### ⛔ The cross-process chain is UNREACHABLE — the GPU process fastfails before it can ask (2026-08-30)

Built DXMT **v0.80** from upstream source with `dxmt-force-crossprocess.patch`, installed it
alongside the CHILD-patched `winemac.so`, and ran with `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1`
(`exp_ae1338` default backend, `exp_003f82` with `--use-angle=d3d11`). Fonts healthy in both
(`GLYPHS RASTERISE`). Result in both:

| signal | count |
|---|---|
| `swapchain FORCED` (refusal 1 falling through) | **0** |
| `cross-process CHILD hwnd → root` (refusal 4) | **0** |
| GPU-process crashes per launch | **107 / 113** |
| distinct crash code | **`exit_code=-1073740791`** = `0xC0000409` `STATUS_STACK_BUFFER_OVERRUN` |

**The GPU process fastfails at init and never reaches `CreateSwapChain`**, so the guard the patch
removes is never evaluated and none of the four refusals fire. Verified the patch *is* compiled in
(the built `d3d11.dll` carries both the `swapchain FORCED` string and the env-var name) — this is
not a build problem.

**What this reframes.** The four-refusal chain was mapped by reading source, and every refusal in it
is real — but it sits **downstream of a blocker nobody has addressed**. Out-of-process, Chromium's
GPU process dies ~110 times a launch before any of that machinery is consulted. So:

- Patching winemac and DXMT for cross-process presentation cannot help until the GPU process
  survives init. **That, not the CHILD FIXME, is the top of the stack.**
- `--in-process-gpu` "works" precisely because it deletes the problem rather than solving it: the
  GPU moves into the browser process, so there is no separate process to crash and no cross-process
  swapchain to acquire.
- `0xC0000409` is a **security-check / `__fastfail`**, not an ordinary access violation. That is a
  different class of bug from anything this thread has chased, and it is where a next investigation
  should start.

⚠ **Version caveat:** built from tag `v0.80`; the shipped DLL is `v0.80-17-g79f6279`, and commit
`79f6279` is **not in the public repo** — the installed build carries 17 commits from elsewhere. The
crash count is the same order either way, so the delta does not explain the result, but it is not a
byte-for-byte comparison.

Everything was restored afterwards (shipped `d3d11`/`dxgi`/`winemetal`/`winemac`) and the game
boot-verified to `MainMenu`. The `@loader_path/../../` rpath fix lives on
`win32u`/`dwrite`/`crypt32`/`secur32`, which this swap never touched, so it survived intact.

### ⛔ BLOCKED: winemac's CHILD patch alone does nothing — the chain starts in DXMT (2026-08-30)

Tested whether the cross-process CHILD patch renders Steam **without** the shim now that fonts work
(`exp_9edcc6` plain, `exp_e75c1e` with `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1`). Both **black**,
both with fonts confirmed healthy in-tree (`GLYPHS RASTERISE`). The patched `winemac.so` was
installed and verified loaded — and its `cross-process CHILD hwnd` counter fired **zero** times.

**Why: the four-refusal chain starts in DXMT, not winemac.** Refusal #1 is
`d3d11_swapchain.cpp` returning `E_FAIL` before attempting anything, and it is removed by
`scripts/dxmt-force-crossprocess.patch` — which is **not** in the installed DXMT. The 2026-08-28
ledger entry says so plainly (*"ALL REVERTED: 4 DXMT dlls restored to system32/syswow64"*).
So winemac never gets asked, and a winemac-only install can never test this. **Do not retry it.**

⚠ **An inference error worth recording, because it nearly became a finding.** The installed
`d3d11.dll` was checked for the refusal string, found to have **zero** hits, and read as "already
patched". It is not — it contains *none* of the three markers (`cross-process swapchain not
supported`, `swapchain FORCED`, `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN`), because it is stock DXMT
whose strings differ entirely. **Absence of a string is not evidence of a patch**; check for the
marker the patch ADDS, not only the one it removes. One `strings` call settled it.

**To actually run this test** you need DXMT rebuilt with `dxmt-force-crossprocess.patch` and the
`macdrv_functions_t` ABI (80 → 88) matching the patched winemac, both trees in lockstep. That is a
build, not a swap. Stock `winemac.so` was restored and the game boot-verified to `MainMenu`
afterwards.

## Why this exists

On **2026-08-30** an audit of the Steam-UI thread found that **41 of 43 render cells had been
measured with no font library** — wine could not resolve `libfreetype.dylib`, so `win32u` printed
one message and continued with no font backend. Those runs render art and no glyphs, which is
indistinguishable from a GPU/compositing failure. A week of work had been spent eliminating fonts,
rasterisation, texture formats, occlusion, DirectComposition and presentation architecture — while
the actual cause of "no text" sat unrecorded in every log.

Two further confounds surfaced in the same audit: the webhelper shim was installed in a `cef` dir
Steam does not use (so `--shim-args` silently never applied), and the harness's `ps` and window
capture were not prefix-filtered (so another wrapper's Steam supplied a **false PASS**).

None of the three were detectable after the fact, because **no artifact recorded the configuration
a result was measured under.** That is what this ledger fixes.

## ⚠ The git log is NOT a source of truth for this thread

`git log` is immutable, and the commit subjects written between 2026-08-24 and 2026-08-30 assert
conclusions this ledger has since withdrawn — *"eliminate text RASTERISATION"*, *"the glyph story
resolves"*, *"no wine-version bisect is warranted"*, *"macOS is not the variable"*. They were
honest when written and they are wrong now, and nothing in a commit message can be edited to say so.

**Rule: for anything in the Steam-UI thread, the register below outranks any commit subject, README
line, or a heading in `GOTCHAS.md` / `docs/steam-ui-investigation.md`.** Several headings still read "ELIMINATED" or "SOLVED" with a
`Ledger:` banner directly beneath them retracting exactly that word — the banner wins. Headings were
deliberately left alone so the history stays greppable and the retraction stays visible next to the
claim it retracts.

## Network is part of the config (added 2026-08-30)

**A Steam that cannot reach the network renders an empty/offline client, and in a window capture
that is indistinguishable from the presentation failure this harness exists to measure.** VPN flaps
are a recurring event on this machine, so `cell-fingerprint.sh` now records `network` and
`vpn_interfaces` in every `config.json`, and **refuses the cell outright** if the network is down.

It also explains a hang misdiagnosed the same day: a `steam.exe -shutdown` that blocked past three
minutes was blamed on wine being slow to spawn the helper process. Steam's shutdown does network
work — logging off, flushing state — so a flapping tunnel stalls it. The instrument now records the
thing that would have told us.

⚠ Today's load-bearing cells are **not** affected: `exp_d7dd0d` rendered the live storefront with
real content (game titles, review counts), which an offline client cannot produce. That was luck
rather than instrumentation, which is the whole reason for this entry.

## The rule: three columns, never fused

| column | what it is | when it changes |
|---|---|---|
| **Config** | the state the run happened in | captured automatically, never typed |
| **Measured** | the raw observation, no interpretation | never — a measurement is permanent |
| **Inferred** | what we concluded from it | freely, as premises fall |

Fusing *Measured* and *Inferred* into prose is what cost the week. When a premise collapses you must
be able to retract the **inference** and keep the **measurement** — otherwise the only safe move is
to re-run everything, which is exactly the circle this file exists to break.

## Status vocabulary

| status | meaning |
|---|---|
| `SUPPORTED` | measured under a recorded, sound config; still believed |
| `PARTIAL` | some claims survive, others don't — the entry says which |
| `UNREVIEWED` | never audited against the config rules; treat as unknown, not as true |
| `VOID` | the run could not have measured what it claimed (failed precondition) |
| `RETRACTED` | the inference was drawn and later disproved |

`VOID` is about the **run**; `RETRACTED` is about the **claim**. A VOID run can still hold a valid
measurement of something *else* — say so rather than deleting it.

---

## Conclusions register

Each row: what we believe, what it rests on, and what would overturn it. **Audited 2026-08-30.**

| # | Claim | Status | Rests on | Notes / what would overturn it |
|---|---|---|---|---|
| C1 | Wine 11.16 retires the alt-tab / exclusive-fullscreen freeze (dxmt#206) | `SUPPORTED` | in-game confirmation; upstream closed as dup of #183 | Font/graphics-lib independent. Unaffected by the 08-30 audit. |
| C2 | The cross-process **child-window** patch makes Steam's client composite on stock winemac + DXMT | `PARTIAL` | `exp_6bd192` `exp_06760c` `exp_3d7586` `exp_015b85` — **void-ok:** whether a layer composites is font-independent, so the byte-size jump stands | **Rendering supported** — window went 108,343 B → 2,588,759 B, and whether a layer composites does not depend on FreeType. **The "still no text" half is VOID** — every one of those cells ran with no font backend. |
| C3 | `macdrv_get_cocoa_window` returns NULL for a foreign HWND — the cross-process root cause | `SUPPORTED` | source read + direct measurement | Derived from reading wine's source and a targeted probe, not from a render cell. |
| C4 | The glyph loss is in-process GPU itself, not the `--in-process-gpu` flag | `DISPROVEN` | `exp_d7dd0d` — in-process GPU **with fonts working** renders Steam's storefront complete with text | The premise was never true. With `nohup` removed (C10) the *same* config — shim injecting `--in-process-gpu`, confirmed on the real webhelper's command line — renders the full client: menus, nav, store copy, review counts, all legible. **In-process GPU never had anything to do with glyphs.** Proof: `docs/images/steam-renders-with-text.png`. |
| C5 | Text **rasterisation** eliminated — `dwritetest` byte-identical across engines | `RETRACTED` | `scripts/dwritetest.c` | The measurement stands (ALIASED 545/1633 sum 138975; CLEARTYPE 315/4899 sum 80325, identical on both). The **elimination** does not: `dwritetest` runs as a standalone PE, and standalone PEs were measured 2026-08-30 to resolve FreeType fine on *both* engines. It never exercised the failing condition. |
| C6 | Glyph-atlas texture path eliminated — `scripts/r8test.c` | `RETRACTED` | same class as C5 | Same defect: a standalone PE probe cannot eliminate a fault that only appears under Steam. Measurement kept, elimination withdrawn. |
| C7 | CPU raster renders Steam **with text** on an 11.0-lineage engine | `PARTIAL` | `exp_8d065a`, `exp_fb79d9` | `winestable-cpuraster` is genuine — shim installed, libs resolve, text visible. **`pk-cpuraster` is mislabeled**: that prefix has no shim, so `--shim-args` never applied and it was an ordinary launch, not CPU raster. |
| C8 | macOS is not the variable; wine-stable 11.0 renders where our 11.16 does not | `RETRACTED` | `exp_fb79d9` vs `exp_53a8e6` | Not a controlled comparison: one side had the shim and a working font backend, the other had neither. Retracted 2026-08-30, same day it was committed. |
| C9 | DXMT beats vanilla wined3d at every cell (wined3d gets FL 9_3 only) | `UNREVIEWED` | `scripts/dxgiprobe.c`, the `vanilla-*` cells | The feature-level measurement comes from a standalone probe and is font-independent, so it plausibly survives — but it has **not** been re-audited against the config rules. Do not cite as settled. |
| C10 | **SOLVED — our own harness caused it.** `nohup` strips `DYLD_*`, and this engine's `win32u.so` cannot find its own libfreetype without it | `SUPPORTED` | `exp_0a43b3` (0 FreeType failures, glyphs rasterise in-tree) vs `exp_4b9824` (63, no coverage) — same script, one line changed | macOS **purges `DYLD_*` when exec'ing a SIP-protected system binary**. Measured: a bare `dlopen("libfreetype.dylib")` succeeds directly and **FAILS** via `nohup`, via `env`, and via `/bin/bash -c`. The harness launched Steam with `nohup`. Removing that one word took FreeType failures **63 → 0** and made DirectWrite rasterise **inside Steam's tree** for the first time. |
| C11 | Without FreeType, DirectWrite **enumerates 204 families but rasterises nothing** — so the font failure IS sufficient to explain zero glyphs, and the family count is a decoy | `SUPPORTED` | `exp_4b9824`, `exp_95fb82` (in Steam's tree, via the shim) + shell A/B on the same engine — **void-ok:** the library failure is the condition under measurement, not a defect in it | **In-tree: DWrite 204 families, `hr=S_OK`, glyph run `ABC@32` → bounds `0x0`, nonzero `0`, sum `0`.** Shell control, same engine, same probe: with `DYLD_FALLBACK` set → `71x23`, nonzero `545`, sum `138975`; without → `0x0`, `0`, `0`. Only rasterisation moves; the family count is **204 either way**. The 545/138975 figures reproduce `dwritetest.c`'s recorded ALIASED numbers exactly, which independently validates the port. Overturned by: a cell where in-tree rasterisation is non-zero and text is still missing. |

### ✅ C10 CLOSED (2026-08-30) — it was `nohup`, in our own harness

**The engine was never the variable, and neither was Steam.** The chain, each link measured:

1. Our `win32u.so` carries **only** an `@loader_path/` rpath, so it cannot reach its own
   `wine/lib/libfreetype.dylib`. It depends entirely on `DYLD_FALLBACK_LIBRARY_PATH`.
   PK 11.0's `win32u.so` also carries **`@loader_path/../../`** — which *is* `wine/lib` — so PK
   needs no environment variable at all. **That asymmetry is the whole "PK is different" story.**
2. macOS **purges `DYLD_*` when exec'ing a SIP-protected system binary.** Measured with the x86_64
   `dlprobe`: a bare `dlopen("libfreetype.dylib")` resolves on direct invocation and **FAILS**
   through `nohup`, through `env`, and through `/bin/bash -c`.
3. `scripts/steam-render-cell.sh` launched Steam as `... nohup "$WINE" steam.exe ...`.
4. So every cell ran with the variable stripped → no font backend → DirectWrite enumerates 204
   families but rasterises **nothing** → **Steam draws art and no glyphs.**

Deleting the word `nohup` took FreeType failures **63 → 0** (`exp_4b9824` → `exp_0a43b3`) and
produced the first in-tree `GLYPHS RASTERISE` this project has ever recorded.

> **The instrument caused the defect it was measuring, for a week.** The daily launcher was never
> affected — `launch-cs2-dxmt11.sh` execs wine directly — which is exactly why the game had fonts
> the whole time and only *cells* did not. Nothing about Steam, DXMT, CEF or macOS was ever wrong
> here.

**The durable fix is the engine, not the harness.** Build with
`-Wl,-rpath,@loader_path/../../` on the unix `.so` set so `win32u` resolves its own libraries the
way PK's does, and no launch path can ever strip it again. Until that lands, **any** wrapper script
that reaches wine through `nohup`/`env`/`bash -c`/`setsid` silently disables fonts. `docs/plans/build-wine1116-dxmt-engine.md` is where that change belongs.

### Superseded: the original open lead — why does our engine lose FreeType *only* under Steam?

Our engine's `config.h` has `SONAME_LIBFREETYPE "libfreetype.dylib"` (unversioned, from Homebrew);
PK's `win32u.so` asks for `libfreetype.6.dylib`. Both names exist in every wrapper's `Frameworks/`
(the unversioned one as a symlink, present on the canonical wrapper since 2026-08-23).

**Sharpened 2026-08-30 (second pass).** A bare `dlopen("libfreetype.dylib")` with **no** DYLD
variable set FAILS — dyld's built-in fallback is `/usr/lib` only, and macOS ships no
`/usr/lib/libfreetype.dylib`. It SUCCEEDS the moment the engine's own `wine/lib` is on
`DYLD_FALLBACK_LIBRARY_PATH`, on **both** engines. Our launcher and the cell harness both export
exactly that (`launch-cs2-dxmt11.sh:63`, `steam-render-cell.sh:65`), and `cell-fingerprint.sh`
confirms it resolves — yet the same cell logs 61 FreeType failures once Steam is running.

So the variable is neither the engine nor the library.

**Tested and FALSIFIED 2026-08-30: it is not variable priority.** The obvious next move was
`DYLD_LIBRARY_PATH` — searched *first*, and not the variable a runtime would overwrite. Two cells
ran with it set alongside the fallback (`exp_54cc10` 61 FreeType failures, `exp_a96ecc` 59). No
improvement, so "Steam overwrites the fallback path and the fix is a higher-priority variable" is
dead. Do not re-run it.

Both cells are the first ever recorded with a full `config.json`, and both confirm the shim now
works: `steamwebhelper.exe` spawns `steamwebhelper_real.exe` children in `cef.win64`. So a
CPU-raster cell is finally possible — that is the next real experiment, not another env tweak.

### ✅ The audit's mechanism, finally MEASURED rather than inferred (2026-08-30, second pass)

This file opens by saying 41 of 43 cells "render art and no glyphs" because they had no font backend.
That was a **correlation** — the two clean cells were the two that showed text — and it has now been
measured directly, inside the failing process tree, by a probe in the webhelper shim (`exp_4b9824`):

| | GDI families | DWrite families | DWrite rasterises `ABC@32` |
|---|---|---|---|
| **inside Steam's tree** | 0 | **204**, `S_OK` | **`0x0`, nonzero 0, sum 0 — nothing** |
| shell, same engine, DYLD set | 924 | 204 | `71x23`, nonzero **545**, sum **138975** |
| shell, same engine, DYLD unset | 0 | 204 | `0x0`, **0**, **0** |

**Chromium draws text through DirectWrite, and DirectWrite in that state cannot produce a single
pixel of glyph coverage.** The mechanism is real and the blanket `VOID` is correct on its own terms.

⚠ **This corrects a claim made earlier in this same session, and the error is instructive.** An hour
before, only *enumeration* had been measured — 204 families, `S_OK` — and C11 was written to say the
font failure "does not explain Chromium's missing glyphs." **That was wrong, from exactly the trap
this thread already documents: a load is not an implementation.** 204 families with a dead rasteriser
and 204 that actually draw are indistinguishable from a count. The rasterisation probe reverses the
conclusion. **Never conclude from an enumeration what only a rasterisation can tell you.**

**Still open.** What remains is to catch the failure in the act. The remaining hypothesis
worth testing is that macOS strips `DYLD_*` across the exec into wine's preloader for Steam's
children specifically — which would have to be measured *inside* the process, e.g. by extending
the webhelper shim (our own code, already running there) to log the environment it actually sees.

> ⚠ **RETRACTED 2026-08-30 (same day): "`wine notepad` is a blind font probe" was WRONG, and the
> way it was wrong is the more useful finding.** That A/B was run as
> `timeout 25 wine notepad 2>&1 | grep -c ...`. **macOS ships no `timeout`.** Every run exited 127
> without launching anything, and `grep -c` on the resulting error text returns **0** — identical to
> "ran, found nothing". Re-run properly, `wine notepad` is a **good** probe: **0** FreeType failures
> with `DYLD_FALLBACK_LIBRARY_PATH` set, **7** without, on the canonical engine. It discriminates.
>
> **Two traps worth more than the probe:**
> - **`timeout` does not exist on this machine** (no coreutils). `timeout <cmd> 2>&1 | grep -c` is a
>   silent zero-generator. Assert the command produced *expected* output — not just that grep
>   returned a number. A `ran=yes/NO` line on every probe is the cheap fix.
> - **`bash -c` strips `DYLD_*`.** macOS purges `DYLD_*` when exec'ing a SIP-protected binary, and
>   `/bin/bash` is one. Wrapping a probe in `bash -c "wine ..."` silently removes the very variable
>   under test — measured here: 7 failures *both* with and without DYLD via `bash -c`, but 0 vs 7 on
>   direct invocation. **Invoke wine directly.** This is also the leading candidate mechanism for the
>   whole of C10.

> ⚠ **`ps eww` cannot read another process's environment on this macOS — it returns nothing even
> for a process you own with the variable definitely set** (validated 2026-08-30 against a
> `DYLD_LIBRARY_PATH=... sleep` sentinel; both `ps eww -p` and `ps eww -o command=` came back
> empty). A harness that reads env this way will report "the variable did not survive" for every
> process on the machine. `wine cmd /c set` is no substitute: it shows the *Windows* environment
> block, which does not carry `DYLD_*` either.

> ⚠ **`cell-fingerprint.sh`'s library check has a blind spot, by construction.** It probes with the
> env *the harness exports*, so it answers "can this library be resolved from here?" — not "will the
> process that matters resolve it?". It would have passed every one of the 41 contaminated cells.
> It is a precondition, not a verdict; the FreeType count in the cell's own `stdout.txt` is the verdict.

**Already eliminated — do not re-test these.** Each was measured on 2026-08-30; re-running them is
the circle this ledger exists to break.

| hypothesis | how it was eliminated |
|---|---|
| the wrapper is missing the libs | canonical has all three in `Frameworks/` **and** `wine/lib/`; `wineboot -u` there resolves all three (292-line log, prefix built, MoltenVK initialised) |
| the unversioned symlink is broken | `dlopen("libfreetype.dylib")` succeeds from a plain x86_64 process under the cell's exact env |
| architecture mismatch | `lipo -archs`: engine `wine64`, and every `Frameworks/` dylib, are all `x86_64` on both wrappers |
| the real Steam prefix is different | the GDI font probe resolves fine **in the real Steam prefix**, script-style env, both bitnesses |
| 32-bit processes can't reach the libs | 32- and 64-bit GDI probes return **identical** metrics on both engines (Arial, height 16, extent 29×16) |
| old-style vs new-WoW64 | all three engines are new-WoW64 — `lib/wine/` has no `i386-unix` in any of them |
| the engine itself can't resolve the soname | **both** engines resolve a bare `dlopen("libfreetype.dylib")` when their own `wine/lib` is on `DYLD_FALLBACK_LIBRARY_PATH` (2026-08-30, `~/cs2-patch/dlprobe`, x86_64). The engine is not the variable |
| Homebrew's copy is the one being found | `/opt/homebrew/lib/libfreetype.dylib` is **arm64** — an x86_64 wine could never load it, whatever the path says. Every engine ships its own `x86_64` copy in `wine/lib` |
| a stale `wineserver` pins a bad environment | started `wineserver` with and without the DYLD var, then launched a wine GUI process each way — no difference (but see the ⚠ below: that probe turned out to be blind) |
| `$HOME/lib` shadowing / fallback | `$HOME/lib` is **not** a dyld fallback on this macOS; the only default is `/usr/lib`, and none of the three libs is in any default fallback dir |
| the shim sanitises the environment | the failure reproduces on plain no-shim launches (`exp_7b9920`) |

**What remains untested:** whether `DYLD_FALLBACK_LIBRARY_PATH` actually reaches Steam's child
processes (`ps eww` will not show another process's environment on macOS, so the direct read is
unavailable), and whether `DYLD_LIBRARY_PATH` — searched *first*, a different dyld code path —
survives where the fallback does not. That A/B was started 2026-08-30 and **abandoned mid-run**:
its own inter-run shutdown failed, leaving two `steam.exe` racing in one prefix, so phase A's
number (60 FreeType) is not clean and phase B never ran. Re-run it with the fingerprint attached.

---

## Experiment index

Auto-derived from the evidence store by `scripts/check-experiments.py --regen`.
Artifacts: `~/cs2-patch/evidence/<cell>/` (outside the repo — see § Privacy).

`VOID-LIBS` = ran with at least one unresolved graphics/font library. `capture` is **unreliable for
pre-2026-08-30 cells**: the harness did not prefix-filter its window list, so a "rendered" reading
may belong to a different wrapper's Steam.

| id | ran | cell | FT | gnutls | MVK | capture | status |
|---|---|---|---:|---:|---:|---|---|
| exp_a886cb | 2026-08-29 16:56 | `split-pair` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_7ae4c7 | 2026-08-29 16:59 | `split-pair-v2` | 14 | 7 | 4 | — | VOID-LIBS |
| exp_cc3bb9 | 2026-08-29 17:01 | `split-ipgpu-swiftshader` | 24 | 0 | 0 | — | VOID-LIBS |
| exp_0dbb6c | 2026-08-29 17:04 | `split-single` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_154886 | 2026-08-29 17:15 | `dxmt-single-control` | 17 | 0 | 0 | rendered | VOID-LIBS |
| exp_43d01c | 2026-08-29 18:17 | `vanilla-real-control` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_17e351 | 2026-08-29 18:19 | `vanilla-real-pair` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_e8594e | 2026-08-29 18:21 | `vanilla-real-single` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_bb8f7e | 2026-08-29 18:24 | `vanilla-real-ipgpu` | 24 | 0 | 0 | — | VOID-LIBS |
| exp_20ad29 | 2026-08-29 18:26 | `vanilla-vk-control` | 24 | 0 | 0 | — | VOID-LIBS |
| exp_fc38ad | 2026-08-29 18:27 | `vanilla-vk-control2` | 56 | 0 | 0 | black | VOID-LIBS |
| exp_d2c54c | 2026-08-29 19:27 | `cef-force-gpu` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_cad7d4 | 2026-08-29 19:29 | `angle-d3d9` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_34c48b | 2026-08-29 19:46 | `vis-control` | 60 | 0 | 0 | — | VOID-LIBS |
| exp_509ae4 | 2026-08-29 19:54 | `vis-control2` | 54 | 0 | 0 | black | VOID-LIBS |
| exp_454e00 | 2026-08-29 21:05 | `fork-control` | 22 | 0 | 0 | — | VOID-LIBS |
| exp_56dbae | 2026-08-29 21:09 | `fork-pair` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_3206bc | 2026-08-29 21:12 | `fork-pair2` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_8cf39c | 2026-08-29 21:30 | `forced-xproc` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_272e5a | 2026-08-29 21:33 | `forced-xproc-dbg` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_d7a882 | 2026-08-29 21:53 | `foreign-hwnd` | 14 | 0 | 0 | — | VOID-LIBS |
| exp_26b733 | 2026-08-29 21:57 | `foreign-hwnd2` | 32 | 22 | 5 | black | VOID-LIBS |
| exp_457ad8 | 2026-08-29 22:14 | `vk-remote-layer` | 59 | 49 | 13 | black | VOID-LIBS |
| exp_c52a07 | 2026-08-29 22:20 | `remote-layer` | 58 | 48 | 13 | — | VOID-LIBS |
| exp_98ce17 | 2026-08-29 22:27 | `remote-layer2` | 54 | 48 | 12 | black | VOID-LIBS |
| exp_71db7a | 2026-08-29 22:31 | `remote-layer3` | 59 | 49 | 13 | black | VOID-LIBS |
| exp_7c608c | 2026-08-29 22:39 | `child-warm` | 31 | 0 | 0 | — | VOID-LIBS |
| exp_6bd192 | 2026-08-29 22:42 | `child-real` | 28 | 24 | 8 | — | VOID-LIBS |
| exp_3c7dd2 | 2026-08-29 23:12 | `glyph-nodcomp` | 28 | 22 | 5 | rendered | VOID-LIBS |
| exp_098eee | 2026-08-29 23:17 | `glyph-nodcomp2` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_200289 | 2026-08-29 23:23 | `glyph-onelayer` | 73 | 57 | 13 | black | VOID-LIBS |
| exp_fe859a | 2026-08-29 23:29 | `z-bottom` | 33 | 23 | 6 | black | VOID-LIBS |
| exp_3d7586 | 2026-08-30 00:23 | `geom-mapped` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_490c1b | 2026-08-30 01:39 | `mvk-in-winelib` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_fb1293 | 2026-08-30 01:44 | `angle-d3d11-live` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_4a9a98 | 2026-08-30 01:56 | `mikey92-exact` | 14 | 7 | 4 | — | VOID-LIBS |
| exp_53a8e6 | 2026-08-30 02:02 | `cpuraster` | 14 | 7 | 4 | — | VOID-LIBS |
| exp_8d065a | 2026-08-30 02:29 | `pk-cpuraster` | 0 | 0 | 0 | rendered | candidate |
| exp_311758 | 2026-08-30 02:49 | `sw-vulkan` | 14 | 7 | 4 | — | VOID-LIBS |
| exp_06760c | 2026-08-30 03:41 | `clean-patch-verify` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_015b85 | 2026-08-30 04:28 | `geom-reposition` | 33 | 23 | 6 | rendered | VOID-LIBS |
| exp_fb79d9 | 2026-08-30 05:27 | `winestable-cpuraster` | 0 | 0 | 0 | rendered | candidate |
| exp_7b9920 | 2026-08-30 11:55 | `cpuraster-canonical` | 61 | 52 | 14 | rendered | VOID-LIBS |
| exp_54cc10 | 2026-08-30 13:24 | `dyldpath-first` | 61 | 0 | 0 | black | VOID-LIBS |
| exp_a96ecc | 2026-08-30 13:27 | `dyld-env-probe` | 59 | 0 | 0 | black | VOID-LIBS |
| exp_95fb82 | 2026-08-30 14:23 | `fontprobe-intree` | 63 | 0 | 0 | black | VOID-LIBS |
| exp_4b9824 | 2026-08-30 14:28 | `raster-intree` | 63 | 0 | 0 | black | VOID-LIBS |
| exp_0a43b3 | 2026-08-30 14:32 | `nohup-removed` | 0 | 0 | 0 | black | candidate |
| exp_d7dd0d | 2026-08-30 14:35 | `ipgpu-fonts-fixed` | 0 | 0 | 0 | rendered | candidate |
| exp_9edcc6 | 2026-08-30 15:28 | `childpatch-noshim` | 0 | 0 | 0 | black | candidate |
| exp_e75c1e | 2026-08-30 15:31 | `childpatch-forced` | 0 | 0 | 0 | black | candidate |
| exp_ae1338 | 2026-08-30 17:32 | `xproc-v080` | 0 | 0 | 0 | black | candidate |
| exp_003f82 | 2026-08-30 17:34 | `xproc-angle-d3d11` | 0 | 0 | 0 | black | candidate |
| exp_fd9012 | 2026-08-30 17:47 | `gpu-fastfail-verbose` | 0 | 0 | 0 | black | candidate |
| exp_55fc05 | 2026-08-30 17:49 | `swiftshader-oop` | 0 | 0 | 0 | black | candidate |
| exp_b292d6 | 2026-08-30 17:51 | `default-oop-control` | 0 | 0 | 0 | black | candidate |
| exp_9f3199 | 2026-08-30 18:02 | `seh-fastfail` | 0 | 0 | 0 | black | candidate |
| exp_86ebce | 2026-08-30 18:04 | `seh-module` | 0 | 0 | 0 | black | candidate |
| exp_e99644 | 2026-08-30 18:08 | `ucrtbase-builtin` | 0 | 0 | 0 | black | candidate |
| exp_226724 | 2026-08-30 21:24 | `vpn-up-baseline` | 0 | 0 | 0 | black | candidate |

60 cells · 45 VOID-LIBS · 15 candidate
---

## Running a cell (the procedure this ledger assumes)

```bash
bash scripts/cell-fingerprint.sh --out /tmp/steam-cell-<label> \
     --shim-args " --disable-gpu --single-process" --strict   # refuses on a fatal precondition
bash scripts/steam-render-cell.sh --label <label> --shim-args " --disable-gpu --single-process"
```

`cell-fingerprint.sh` writes `config.json` beside the result and **exits non-zero** when a
precondition that would void the cell is unmet. It checks:

1. **every graphics/font soname the engine references actually resolves** under the cell's env,
   probed x86_64 (an arm64 probe would resolve dylibs the engine can never load)
2. **the shim is in every `cef` dir present** when `--shim-args` is passed — not just one
3. **no foreign wrapper's Steam is running** (`--strict` refuses; otherwise warns)

⚠ **Read the real exit code.** `bash scripts/cell-fingerprint.sh … | tail` reports *tail's* status,
so a VOID cell announces itself as exit 0. This bit the script's own first test on 2026-08-30.

A cell whose fingerprint says `VOID` is **not evidence** and must not get a ledger row beyond the
fact that it was voided.

## Privacy — what may leave this machine

The repo is intended to be publishable. Audited **2026-08-30**:

| artifact | contains | disposition |
|---|---|---|
| `stdout.txt`, `windows.txt` | only `C:\` / `Z:\` wine-internal paths — **no** `/Users/<name>`, no Steam ID, no persona name (verified by grep) | safe to quote in the repo |
| `config.json` | wrapper + prefix paths under `/Users/<name>` | evidence store only; redact `$HOME` if quoting |
| `win-*.png` | Steam client window — **persona name twice** (top-right, and as a nav item) plus the avatar | evidence store only, **never committed unmasked**; mask the two regions before publishing |
| `known-good.png` | an arbitrary browser/terminal window — whatever was frontmost | **not retained.** Only its byte size is kept (`known-good.size.txt`). This is the largest accidental-disclosure surface in the harness and it has no evidentiary value beyond "the capture worked". |

`scripts/salvage-cells.sh` applies all of this when moving cells out of `/tmp`.

**Cheapest durable fix for the screenshots:** the Steam persona name is a *label*, freely editable —
set it to something generic while doing capture work and new captures are clean at source, with no
post-processing to get wrong. A mask you got wrong is worse than no mask, because it looks safe.

## Maintenance

- **`wake up`** — read the **Conclusions register** (not the whole file, not `GOTCHAS.md` whole).
  It is the index of what we already know and how much to trust it.
- **`button up`** — run `python3 scripts/check-experiments.py`. It fails on drift: a claim citing a
  VOID run, a ledger row whose evidence is missing, a cell in the store with no row, or a
  dangling `exp_` reference, or a `GOTCHAS.md` status banner that disagrees with the register.
- **On every new conclusion** — add a `C<n>` row here *and* a status banner in the GOTCHAS
  section, so invalidating a run is a grep rather than an audit.

### Conventions (enforced by the checker, not by memory)

| convention | form | enforced? |
|---|---|---|
| experiment id | `exp_` + 6 hex, **minted, never derived from the cell name** | format + uniqueness |
| GOTCHAS status banner | `> **Ledger: ` + `` `STATUS` `` + ` (C<n>).** <why>` on the line directly under the `##` heading | vocabulary; must match the register's status for that claim; cited ids must exist |
| citing a VOID run | add `void-ok: <what the void run still measures>` in the claim row | a `SUPPORTED`/`PARTIAL` claim citing a VOID run fails without it |
| status words | `SUPPORTED` · `PARTIAL` · `UNREVIEWED` · `VOID` · `RETRACTED` — nothing else | rejected if not in vocabulary |

**Why ids are minted, not sequential.** `E043` silently asserts "the 43rd, and later than E042" —
so backfilling an older run makes the ordering lie, and holding the numbering stable across a regen
needs bookkeeping a minted key does not. Per the project's standing key/label rule: an identity key
that other rows point at carries no readable meaning. The cell *name* is the label; it may be
reused or renamed, which is exactly why nothing durable derives from it.

**Where each piece goes.** The register row is the claim. The GOTCHAS banner is the warning at the
point of use. The index row is the run. A conclusion missing any of the three is not recorded — it
is remembered, and this file exists because remembering failed.
- **When a premise falls** — flip the *inference* to `RETRACTED`/`VOID` and say what survives.
  Never delete a measurement.
