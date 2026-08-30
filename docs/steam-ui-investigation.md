# Steam's visible UI — the CEF investigation (2026-08-24 → 2026-08-30)

> **Split out of [`GOTCHAS.md`](../GOTCHAS.md) on 2026-08-30.** It was 65% of that file (1,641 of
> 2,580 lines) and it is not a set of standing traps — it is **one chronological investigation**,
> still open, most of it under retraction. `GOTCHAS.md` keeps the scannable index and the status of
> every section here; this file keeps the evidence. Nothing was reworded in the move.
>
> **Read the index first** — [`GOTCHAS.md` § "Steam's visible UI"](../GOTCHAS.md#steams-visible-ui--the-cef-investigation-2026-08-24--2026-08-30).
> It carries each section's `Ledger:` status in one table, which is the fastest way to see what is
> still believed. The authority on trust is [`../EXPERIMENTS.md`](../EXPERIMENTS.md); this is the
> narrative that register was derived from.
>
> ⚠ **Most headings below are wrong on their own terms.** They say "ELIMINATED", "SOLVED",
> "FINAL" — and many carry a `> **Ledger:`** banner immediately underneath retracting exactly that
> word. **The banner wins.** Headings were deliberately left as written so the history stays
> greppable and each retraction sits next to the claim it retracts. A section with no banner was
> audited and is unaffected; see `GOTCHAS.md`'s header for the rule and the three confounds.

---

## Visible Steam UI black-windows on 11.16 — intermittent, dxmt#141-class; silent flow unaffected (2026-08-24)

Starting Steam WITHOUT `-silent` to click the Play button produced fully black CEF windows —
process healthy and logged in underneath, repaint (minimize/restore, resize) did NOT fix it, and
`-cef-disable-gpu-compositing` did NOT fix it either. This revises the V1 "dxmt#141 does not
reproduce" note: the library rendered fine on 2026-08-23, black on 2026-08-24 — the CEF
black-window class is **intermittent** here, not absent. The daily stack never hits it because
the launcher runs Steam `-silent` (tray only) and launches `Cities2.exe` directly. Consequences:
(a) any attended test needing the visible Steam UI (e.g. clicking Play to drive the Paradox
Launcher) is unreliable — parked; (b) any future dxmt#141 upstream comment must say
"intermittent", not "does not reproduce". Teardown from a black-window state: plain
`steam.exe -shutdown` works — the UI being black doesn't wedge the process.

## Steam's visible UI is BROKEN since the ~Aug-2026 CEF update — mechanism pinned, fix queued (2026-08-24)

Follow-up to the "intermittent dxmt#141-class" entry above — no longer intermittent, and the
mechanism is now measured. Steam's updated CEF initializes its GPU process on **Vulkan**:
`ANGLE Requires a minimum Vulkan instance` → `Internal Vulkan error (-9): The requested version
of Vulkan is not supported` → SwANGLE fallback fails the same probe → `Exiting GPU process` →
every Steam window is black (`logs/cef_log.txt` in the Steam dir). Our winevulkan → PK-era
x86_64 MoltenVK dylib reports too old an instance version. Full fix-ladder tried and dead:
repaint/resize · `-cef-disable-gpu-compositing` · client unpin + current build ·
htmlcache clear + `-cef-disable-gpu` · `--use-angle=d3d11` (flag DOES forward; Vulkan errors
vanish but the GPU process then crashes 0xC0000409 on the ANGLE→D3D11→DXMT path).

- **The game is unaffected** — the daily flow runs Steam `-silent` (tray only) and never renders
  this UI. Purchases/library management need another device or the queued fix.
- **Queued fix (own mini-project + plan): drop a newer x86_64 MoltenVK dylib into the engine** so
  winevulkan reports a modern Vulkan instance — likely also what differentiates the CrossOver/
  Whisky users who report Steam rendering fine (newer MoltenVK lineage).
- Secondary upstream lead: the 0xC0000409 ANGLE-on-D3D11 crash is DXMT-relevant evidence for
  dxmt#141 (stronger than anything currently on the thread).
- `steam.cfg` update pin (`BootStrapperInhibitAll`, a dead experiment's leftover) removed
  permanently — parked as `steam.cfg.disabled-20260824`. Re-pinning now would freeze a broken
  state; unpinned is the healthy default.

## Steam black UI is NOT the Vulkan failure — reboot retest disproves the queued MoltenVK fix (2026-08-24 PM)

Supersedes the mechanism in the section above on two points. James rebooted the Mac and asked for
a retest; four launch configurations were measured, each with its own `cef_log.txt` (kept in the
prefix as `logs/cef_log.E{0..3}-*.txt`). Window state judged per-window, not by eye — see the
capture method below.

**1. The reboot changes nothing.** E0 (stock `steam.exe -no-cef-sandbox`) reproduces the
pre-reboot log line for line. Not stale GPU state, not intermittent: deterministic.

**2. The failure ORDER was recorded backwards.** The GPU process does not "initialize on Vulkan"
first. It hard-crashes `exit_code=-1073740791` (0xC0000409) **three times before ANGLE logs
anything at all**; only the 4th, fallback attempt reaches ANGLE, fails the
`minimum Vulkan instance version of 1.1` probe, fails SwANGLE the same way, and prints
`Exiting GPU process`. So 0xC0000409 is the PRIMARY failure and Vulkan is what the fallback
hits — the reverse of what the previous section says, and it is why forcing `--use-angle=d3d11`
"made the Vulkan errors vanish but crashed 0xC0000409": that flag just deletes the fallback.

**3. New rung — Wine's builtin `vulkan-1` shadows Chromium's own loader.** The tell: SwANGLE
failed with the *same* "minimum Vulkan instance 1.1" message, which is impossible if it had
actually reached SwiftShader (that ICD is Vulkan 1.3, and `vk_swiftshader.dll` +
`vk_swiftshader_icd.json` ARE present in `bin/cef/cef.win64/`). Wine implements `vulkan-1`, so
builtin wins over the app-local native DLL and every ANGLE backend gets routed at
winevulkan → MoltenVK. Fix that with `WINEDLLOVERRIDES=…;vulkan-1=n,b` (native first, builtin
fallback) plus `--use-angle=swiftshader` — **E1 measured: every Vulkan error gone, GPU process
survives init and stops crashing. Window still black.**

**4. The decisive one — E3 removes the GPU stack entirely and the window is STILL black.**
`-cef-disable-gpu` + the `vulkan-1=n,b` override → `cef_log.txt` has **zero** GPU-process crashes
and **zero** Vulkan errors, a clean boot, browser process alive and working. Window black.

⚠ **Consequence: the queued "drop in a newer MoltenVK dylib" fix cannot be the fix.** E3 takes
Vulkan out of the picture completely and does not change the symptom. The black window has a
cause independent of the Vulkan/GPU-process stack — most likely in how CEF's browser process
presents into its HWND under this engine, which is the same surface the alt-tab freeze lived in.
Re-scope the mini-project before spending a build on it. A newer MoltenVK is still worth having
(it removes rungs 2-3 above), it is just not sufficient and probably not the cause.

**Flag-forwarding facts, so nobody re-tests these:** `--use-angle=<backend>` passed straight on
the `steam.exe` command line DOES forward to the webhelper (confirmed in
`logs/webhelper.txt` child-process lines). Chromium-style `--disable-gpu` /
`--disable-gpu-compositing` do **NOT** — Steam filters them, a gpu-process still spawns. Use
Steam's own `-cef-disable-gpu`, which forwards as `--disable-gpu-sandbox --use-gl=disabled`.

**Capture method — verify Steam's render state without fronting it or granting Accessibility.**
`osascript`/System Events needs Accessibility permission (and prompts for it — decline; it is not
needed). Instead enumerate with `scripts/winlist.swift` (CGWindowListCopyWindowInfo → `id`, owner,
size, title) and grab one window by id: `screencapture -x -o -l <id> out.png`. This works on
occluded windows, so it beats the hardcoded `-R x,y,w,h` regions the older capture scripts use.
**Validate the instrument before trusting a black reading** — capture a known-good occluded window
too (a partly-covered Messages window returned 252 KB of real content while the 1280x800 Steam
window returned a byte-identical 22980 across three separate runs = uniform black).

## ⚠ SUPERSEDED same day (see next section): the "11.0 → 11.16 regression" attribution below was
## disproven by a three-version stock sweep — stock 11.0 is ALSO blank. Kept for the measurements.

## Steam's black UI is a wine 11.0 → 11.16 REGRESSION, not a CEF/MoltenVK problem (2026-08-24 PM)

Settled by a controlled A/B against the parked `CS2dxmt11-pk110.app`. **Supersedes the two
sections above on the cause; their measurements stand, their attribution does not.**

**The comparison.** Same Mac, ~10 minutes apart, every variable except the engine verified
identical (not assumed): DXMT `d3d11.dll` 5304320 B and `dxgi.dll` 1753088 B in both ·
`libMoltenVK.dylib` 8096560 B in both · Steam client `-buildid=1785799196` and `steam.exe` /
`steamui.dll` mtime `Aug 3 16:46:16 2026` in both.

| | stock **11.16** (`CS2dxmt11`) | Porting Kit **11.0** (`CS2dxmt11-pk110`) |
|---|---|---|
| `exit_code=-1073740791` in `cef_log.txt` | many, every boot | **0** |
| `minimum Vulkan instance` | present | **0** |
| Steam window (per-HWND capture) | 22980 B **uniform black** | 1405591 B **full store page** |
| Interactive? | n/a | **yes** — James drove the account dropdown live on 2026-08-24, menus open and navigate |

**Three things this kills — don't re-derive them:**
1. **"The ~Aug-2026 CEF update broke it."** No: the client build is byte-identical in both
   prefixes. It broke when the 11.16 engine was promoted (2026-08-23).
2. **"Update MoltenVK."** No: the *same* dylib renders Steam fine on 11.0, and on 11.16
   `-cef-disable-gpu` takes Vulkan out of the path entirely with no change in symptom.
3. **"CEF's HWND presentation is being lost"** (by analogy with the alt-tab freeze). No: surfaces
   composite fine on 11.16 — the Paradox Launcher window comes through **white**, and the game's
   own window captures 3.4 MB of real content. The surface path works.

**What it actually is:** Chromium's GPU process **fastfails `0xC0000409`** on stock 11.16, ×3 per
browser start, before ANGLE logs anything. **Not Steam-specific** — the Paradox Launcher (separate
Electron app, different Chromium, no SDL) crashes identically in the same prefix
(`GPU process crash detected. Skipping quit…`). Engine-wide Chromium-on-11.16 defect.

⚠ **The instrument trap that nearly produced a wrong answer here.** A Win32 probe doing
`GetWindowDC` + `BitBlt`/`PrintWindow` on another process's window returns **nothing** under Wine —
`scripts/wingrab.c` primes its DIB with magenta and got 100% untouched magenta from Steam. That
looks like damning evidence until you run the same probe on `wine notepad`, which renders fine and
returns **the identical 100% untouched magenta**. Cross-process GDI readback does not work here;
the probe is only good for the window-tree dump. **Use the macOS side** (`scripts/winlist.swift` +
`screencapture -x -o -l <id>`) for pixels, and validate it against a known-good window each time.

**Practical, today:** keep `CS2dxmt11-pk110.app` — **do not delete it**. Play on `CS2dxmt11`
(11.16: faster, no alt-tab freeze); do Steam purchases/library on `CS2dxmt11-pk110` (11.0). Both
can hold a Steam resident simultaneously.

**Next step is a bisect, not more theory:** `scripts/build-engine-1116.sh` builds a sha-pinned
stock engine in ~1 hr and 11.0 → 11.16 is 16 releases, so binary search is ~4 builds. Gate each
build on `grep -c 'exit_code=-1073740791' cef_log.txt` — machine-readable, no eyeballing.

## Embedded Chromium NEVER rendered on stock Wine here — the PK vendor patchset is the enabler (2026-08-24 PM-2)

> **Ledger: `PARTIAL`.** Evidence **not retained** (predates the store). The *measurements* — stock
> 11.0/11.15/11.16 blank, PK rendered, transplants blank — are blank-vs-rendered judgments and are
> font-independent, so they survive. The *attribution* does not: "the PK patchset is the enabler" was
> superseded by the cross-process CHILD-window root cause (C3), which explains the same results
> without any vendor-patchset magic. Keep the table, drop the conclusion.

The afternoon's controlled program (three stock builds + env probes + patch test + module
transplants; driver `~/cs2-patch/bisect/`, results ledger `/tmp/bisect/results.log` while it
lives) settles the causal chain and **supersedes the version-regression attribution above**:

| cell | result |
|---|---|
| stock 11.0 / 11.15 / 11.16, identical configure, fresh-prefix launcher gate | **all BLANK, byte-identical captures** |
| PK 11.0 (vendor), same gate | RENDERED, repeatedly |
| PK + `WINE_SIMULATE_WRITECOPY=0` / `WINEMSYNC=0` | still RENDERED — neither is the enabler |
| stock 11.16 + Proton writecopy patch, env-armed, verified in binary | still BLANK |
| stock 11.0 + PK's win32u/winemac/user32/gdi32 transplanted | still BLANK |
| stock 11.0 + PK core (ntdll+wineserver) or + DXMT payload transplants | unstable/crashes — vendor modules interlock |
| `--in-process-gpu`: Electron (any engine) | breaks startup, no window — Electron dropped the flag |
| `--in-process-gpu`: Steam on the daily engine | **filtered, not forwarded** (webhelper children unchanged, same crash ladder) |

**Facts that anchor the diagnosis:**
- The PK engine is a **Gcenx vendor build from a private tree** (`wine-private` paths in its
  binaries), carrying at least: Proton-lineage `WINE_SIMULATE_WRITECOPY` (env/Battle.net-keyed —
  measured NOT active for our apps), the mach-semaphore msync patchset, and CrossOver-lineage
  `CX_LIBVULKAN` code in win32u. Its winemac.drv carries NO DXMT patch (PK wires DXMT another way).
- Config omission ruled out: fresh same-flag configures of 11.0/11.16 have config.h parity; all
  86 dylibs + DXMT binaries md5-identical between engines; module manifest deltas reconciled to
  upstream restructuring or non-graphics `--without` flags.

**Mechanism (supported, final visual proof pending):** Chromium's viz/software compositor paints
the browser's HWND **cross-process**; on winemac, GDI window surfaces are per-process, so a
foreign process's blit lands in its own shadow surface and never reaches the screen — on X11 the
drawable is server-side, which is why Linux never sees this. Same wall as dxmt#141's
"cross-process swapchain unsupported (upstream Wine limitation)" on the GPU path.
`scripts/crossblit.c` measures the naked primitive (green in-process paint vs red cross-process
paint, judged from the macOS side) — **its screen judge is queued on the next unlock**, along
with reruns of the two in-process-gpu pixel cells voided by the display lock (below).

**Consequences:** the fix is porting the relevant CrossOver/vendor support into the 11.16 engine
(own mini-project — start from public winecx source, find the shared-window-surface machinery),
or living with the two-wrapper split (play on `CS2dxmt11`, Steam UI on `CS2dxmt11-pk110` —
which remains **do-not-delete**). No amount of Steam/CEF flags can bridge it: Steam filters the
relevant Chromium switches (`--disable-gpu`, `--in-process-gpu`); `--use-angle` it forwards.

## Mechanism CONFIRMED by elimination (2026-08-24 evening): cross-process PRESENTATION is the wall; PK wins only via its GPU path

> **Ledger: `PARTIAL`.** Evidence **not retained**. "Cross-process presentation is the wall" was
> right and is now pinned precisely — cross-process **CHILD** windows, C3 — but "CONFIRMED by
> elimination" overstates what these cells could show: they were black-vs-white captures with no
> prefix filtering. The direction held; treat the certainty as borrowed from C3, not earned here.

Final round of measured cells (post-unlock), which corrects the "mechanism model" line in the
previous section — the model said PK carries generic cross-process surface support; it does not:

| cell | result |
|---|---|
| `crossblit.c` judge: cross-process GDI FillRect into a foreign window | **lost on BOTH engines** — stock AND PK stay pure green (in-process control paints fine). Cross-process `GetPixel` readback returns CLR_INVALID everywhere |
| child-process census during white-window state (stock) | identical healthy 5-process tree as PK's rendered state, zero churn — nothing is crashing; frames are produced and never presented |
| launcher `--disable-gpu` on stock 11.16 | white (18369 B) |
| launcher `--disable-gpu` on **PK** | **white, byte-identical 18369 B** — PK's software path is exactly as dead as stock's |

**The collapsed story, every 2026-08-24 measurement consistent:**
1. Chromium's software presentation (viz-composited frames → browser HWND) is broken on **all**
   winemac engines. That is the floor everyone stands on.
2. **PK renders CEF solely because its GPU path works**: ANGLE → D3D11 → DXMT presents
   cross-process through vendor plumbing (spanning winemac/win32u/wineserver — which is why
   module transplants into stock blanked or crashed; the machinery does not travel in pieces).
3. Stock engines fail the GPU path (wined3d/dead-GL without DXMT; `0xC0000409` fastfail with
   DXMT — dxmt#141's "cross-process swapchain not supported yet… upstream Wine limitation"),
   fall back to software, and hit floor (1): white/black window over healthy processes.
4. One defect family across dxmt#141 (Steam CEF black), dxmt#183 (ANGLE white window — whose
   author traced winemac's unrefcounted per-window Metal-view lifetime; dxmt#206, our alt-tab
   freeze, is now closed as its duplicate), and every white Electron/CEF window measured here.

**Consequences, final:** no flag can fix Steam on stock-lineage engines (software mode hits the
same wall; Steam filters the useful flags anyway). The only real fix for a single-engine setup
is cross-process presentation support in the engine (CX-lineage port or upstream work) — the
queued mini-project. Until then the two-wrapper split stands. Upstream: this evidence set
(vendor-vs-stock sweep, software-path parity of failure, transplant interlock) is precisely what
dxmt#141 lacks; comment pending James's go-ahead.

## ⚠ PARTIAL — see the correction section below: the shim fixes RENDERING but NOT TEXT.
## Steam's visible UI CAN render on stock Wine + DXMT — the webhelper shim (2026-08-24 evening)

> **Ledger: `PARTIAL`.** The **rendering** half stands (a 9,659 B black window became 80,714 B of
> real UI — font-independent). The **"but not text"** half is void: this engine could not load
> `libfreetype.dylib` in any Steam cell, so no run of it could ever have shown a glyph. See C4.

Reverses the "no way to get Steam working on 11.16" conclusion. **Measured working in a
sandbox prefix: the Steam login window rendered fully** (logo, fields, QR) on the self-built
11.16 + DXMT engine — the same 700x440 window that captured 9,659 B of pure black that morning
came back at **80,714 B of real UI**, with every machine-readable signal flipping together:
gpu-process children 10 → **0**, `0xC0000409` crashes 6+ → **0**, metal-layer errors 12 → 1.

**The mechanism, in one line:** `--in-process-gpu` moves Chromium's GPU into the browser
process, so the swapchain is same-process — the path DXMT already serves for the game — instead
of the cross-process one it cannot (dxmt#141).

**Two traps that make this look impossible, and both must be solved:**

1. **steam.exe FILTERS the flag.** `--in-process-gpu` and `--disable-gpu` never reach
   steamwebhelper (verified against `logs/webhelper.txt` child cmdlines; gpu-process children
   spawn regardless). `--use-angle=<backend>` *does* forward. Steam's own switch set has no
   in-process option (`-cef-disable-gpu`, `-cef-disable-gpu-sandbox`, `-cef-disable-sandbox`,
   `-cef-disable-seccomp-sandbox`, `-cef-force-accessibility`, `-cef-force-gpu` — from
   `strings steam.exe`). So the flag must be injected AT the webhelper: rename the real binary
   to `steamwebhelper_real.exe` and drop a shim in its place that re-launches it with the flag
   appended (`scripts/steamwebhelper-shim.c`, installer `scripts/install-webhelper-shim.sh`).
2. **⭐ Steam restores the shim — unless it is SIZE-MATCHED.** A plain shim gets silently
   replaced and Steam exits **42**; that is what makes the whole approach read as dead. The
   tell is in `logs/bootstrap_log.txt`: **`Verifying installation... Verifying file sizes
   only`**. Zero-pad the shim to the original's exact byte count (7,489,176 for the Aug-2026
   client) and it passes verification untouched. A trailing-zero-padded PE runs normally.
   ⚠ This depends on Valve verifying sizes only — a hash check upstream kills it.

**Shim implementation notes that matter** (all in the .c file): forward `lpCmdLine` VERBATIM
with `bInheritHandles=TRUE` — Chromium passes live IPC/crashpad handle values on the child
command line and inherited handles keep their values; use `lstrcatW` into a 32K buffer, never
`wsprintf` (1K limit) since Chromium cmdlines are huge; Chromium spawns its own subprocesses
via the *running* image path (`steamwebhelper_real.exe`), so they bypass the shim and only the
top-level launch is wrapped. IFEO `Debugger` is NOT an alternative — Wine implements only
`AeDebug` (crash-time), not launch interception (`dlls/kernelbase/debug.c:555`).

**Re-apply after every Steam client update** (the update restores the original webhelper).
`bash scripts/install-webhelper-shim.sh` installs, `--revert` undoes; the original is preserved
in-tree as `steamwebhelper_real.exe` and offsite at `~/cs2-patch/shim/steamwebhelper.orig.exe`.

**Status:** sandbox-proven (login window). Store/library rendering under a real signed-in
session is the remaining confirmation. In-process GPU is an unsupported Chromium mode — watch
for long-session stability before calling it the project default.

## The webhelper shim renders everything EXCEPT text — `--in-process-gpu` is what kills glyphs (2026-08-24 late)

> **Ledger: `VOID` (C4).** Both halves fail, for different reasons. The self-built-engine half is
> explained without invoking any GPU mode: that engine resolved no font library under Steam, so
> "not one glyph" was guaranteed. The **PK** half looks like a clean control — PK resolves FreeType
> — but the 2026-08-24 PK-with-shim run **predates the evidence store and is not retained**, and the
> only indexed PK cell (`exp_8d065a`) had *no shim in that prefix*, so `--shim-args` never applied
> (C7). There is therefore no surviving measurement of PK **with** in-process GPU.
> ⚠ So "in-process GPU breaks glyphs" is currently supported by **nothing** measured under a
> recorded config — including the inline 2026-08-30 correction below, which rests on the same
> mislabeled cell. Re-run it before repeating it anywhere.

Correction to the section above, which called the shim a fix on the strength of a login window
that had rendered *images and layout*. It had **no text either** — the blank blue button should
have been the tell. With the shim, Steam draws artwork, thumbnails, gradients, icons and chrome
perfectly and **not one glyph**: no menu labels, no game titles, no prices, no search
placeholder. Only text baked into promo images appears.

**Isolated to the flag, not our engine:** the PK 11.0 wrapper renders Steam text fine normally,
and **loses text the same way the moment the shim is added**. ⚠ **CORRECTED 2026-08-30 — true only
for `--in-process-gpu`, the shim's compiled default. With the shim injecting `--disable-gpu
--single-process` instead, PK keeps ALL its text; the shim is not the text killer, in-process GPU
is. See § "CPU raster renders Steam WITH TEXT on an 11.0-lineage engine".** So `--in-process-gpu` breaks glyph
rendering in Chromium 126 CEF under Wine, independent of engine and graphics backend.

**Measured dead ends (all with the shim + `--in-process-gpu`, judged by per-window capture):**
`--disable-gpu-rasterization --disable-oop-rasterization` · `--disable-lcd-text
--disable-font-subpixel-positioning` · `--use-angle=swiftshader` **+ `vulkan-1=n,b`** (pure
software — proves it is NOT DXMT's glyph-atlas texture support) · `--disable-gpu-compositing` ·
`--disable-direct-write --disable-partial-raster` (GDI fonts instead of DirectWrite).
Also measured: **`--disable-gpu-compositing` WITHOUT `--in-process-gpu` = 22,980 B uniform black**,
i.e. the in-process flag is what buys rendering at all.

**Fonts are NOT the cause — don't re-chase this.** `scripts/fonttest.c` enumerates what Chromium
actually sees, and the daily 11.16 engine and PK 11.0 are *identical*: **924 GDI families, 204
DirectWrite families**, same names. ⚠ And an earlier claim in this session that our build lacked
DirectWrite FreeType support was **wrong**: our `dwrite.so` carries all 56 `pFT_*` pointers;
PK's shows none only because PK's binaries are **stripped** (its FT_ evidence is dlsym name
*strings*). Compare with `nm`, not `strings`, and never infer capability from file size.

**Net:** the shim converts "black window" into "usable-looking but textless window" — still not
practical for a public audience, so it is **not installed by default** and was reverted from the
daily wrapper. `scripts/install-webhelper-shim.sh` remains for anyone continuing this; the shim
takes `SHIM_ARGS` to swap injected switches without rebuilding + re-padding. The two-wrapper
split (play on `CS2dxmt11`, Steam UI on `CS2dxmt11-pk110`) stands as the practical answer.

**Still worth knowing (unchanged and independently useful):** steam.exe *filters*
`--in-process-gpu` / `--disable-gpu` but forwards `--use-angle`; and Steam's integrity pass is
**"Verifying file sizes only"**, so a size-padded replacement survives where an unpadded one is
restored with exit 42.

## Taking DXMT out of Steam's path entirely does NOT fix it — the vanilla-wined3d split, measured (2026-08-28)

> **Ledger: `RETRACTED`.** Evidence **not retained**. Superseded two sections down: the split never
> gave Steam a *working* D3D11 at all, so this cell measured a broken configuration and read the
> result as a property of the split. The build notes stay useful; the verdict does not.

The last untried route from [mikey92's dxmt#141
comment](https://github.com/3Shain/dxmt/issues/141#issuecomment-5448572368) and
[BCD1210/soju](https://github.com/BCD1210/soju/blob/main/docs/STEAM-GAMES.md): stop trying to make
DXMT serve Steam, and instead run the *client* on vanilla wined3d while the *game* keeps DXMT.
**Built, installed, measured, reverted. It does not work here.**

**Getting a vanilla PE cost a build.** Every `d3d11.dll`/`dxgi.dll` on this machine was DXMT's —
both arch trees and every `.bak`. A `build-engine-1116.sh` run stopped after step 3 yields stock
wine 11.16 (`gmake install`) *before* step 4 overlays DXMT; the vanilla PEs exist only in between.
Harvested: x86_64 `d3d11.dll` 4,584,886 B, i386 3,817,450 B, both version-matched to the engine.

⚠ **Do NOT identify a build by grepping for `dxmt`.** The harvested *vanilla* PEs carry **90**
"dxmt" hits — all of them build paths in debug info, because the source tree is named
`wine-11.16-dxmt`. That count would have failed the vanilla check and sent the whole trial down a
wrong path. The real discriminator is the API surface, and it is unambiguous:

| PE | Metal/winemetal refs | `wined3d_` refs |
|---|---|---|
| DXMT's `d3d11.dll` | **197** | 0 |
| vanilla `d3d11.dll` | 0 | **1,237** |

**The mechanism works exactly as soju documents it** — verified, not assumed. Wine marks its
builtins with the 17-byte signature `"Wine builtin DLL\0"` at file offset **0x40**; `build_module`
(`dlls/ntdll/loader.c`) computes `signature = base + sizeof(IMAGE_DOS_HEADER)` and `memcmp`s it, so
a `native` override aimed at a wine-built PE is redirected straight back to the builtin. Flip one
of those 17 bytes and it loads as true native. With that plus global `d3d11/dxgi=builtin` and
per-app `native` for `steam.exe`/`steamwebhelper.exe`/`steamservice.exe`, `+loaddll` confirms the
split landed:

```
Loaded L"C:\windows\system32\d3d11.dll" ...: native     <- vanilla, in Steam's processes
Loaded L"C:\windows\system32\wined3d.dll" ...: builtin
(no winemetal anywhere in Steam's tree)                    <- DXMT fully out of the path
```

**Result: still a uniformly black window, 108,343 B.** And the same 108,343 B with wined3d's
*Vulkan* renderer — byte-identical, which is the tell: **the D3D implementation is not the
variable — OUT-OF-PROCESS.** (⚠ Scoped 2026-08-29: *in-process* it is decisive and the sign flips —
DXMT renders, vanilla wined3d produces no window at all. See § "The vanilla-wined3d split is
strictly WORSE than DXMT for Steam's CEF".) Swapping out the entire D3D stack changed nothing, so
the failure is not DXMT's missing cross-process swapchain for the *client*; it is the
winemac/cross-process presentation layer, exactly as § "Embedded Chromium NEVER rendered on stock Wine" concluded. The PK vendor
patchset remains the only thing that has ever made this render.

**A second reason the route was never going to work as written:** wined3d's **GL** backend is
broken on macOS 26 at the most basic level — `err:d3d:wined3d_check_gl_call
GL_INVALID_FRAMEBUFFER_OPERATION (0x506) from glClear`. It cannot clear a buffer. (Its Vulkan
renderer is healthy, which is the correction in § Rendering 3.)

**Cost/benefit if anyone reconsiders:** ~1 h build + ~20 min to wire and measure. The two-wrapper
split (play on `CS2dxmt11`, Steam UI on `CS2dxmt11-pk110`) remains the practical answer.
`scripts/steam-vanilla-d3d-split.sh` keeps the whole apparatus — install / verify / revert, with
backups — so re-testing after an upstream winemac change is minutes, not another hour.
**Everything was reverted**; the game path re-verified as `d3d11: builtin` + `winemetal: builtin`.

## The glyph loss is IN-PROCESS GPU itself, not `--in-process-gpu` — `--single-process` fails identically (2026-08-28)

> **Ledger: `VOID` (C4).** Evidence **not retained** — these cells predate the evidence store (earliest kept run 2026-08-29 16:56). The premise "this engine renders art but not text" is explained by an unresolved font backend, not by GPU mode. Re-test before believing any part.

Prompted by [mikey92's dxmt#141 comment](https://github.com/3Shain/dxmt/issues/141#issuecomment-5448572368),
which reports a stable Steam client on an M4 Pro / macOS 26.5 / Homebrew `wine-stable` 11 by
running the *client* processes on vanilla wined3d and giving only games the DXMT builtins, with
notpop's wrapper forcing `--disable-gpu --single-process`. `--single-process` had **never been
tested here** (zero hits repo-wide before this date) — the whole earlier investigation used
`--in-process-gpu`. It was a one-env-var test because the shim already reads `SHIM_ARGS`.

**Result: `--single-process` renders exactly as much as `--in-process-gpu`, and loses text exactly
the same way.** Five measured cells on the daily self-built 11.16 + DXMT engine, judged by
per-window `screencapture` (black ≈ 15–41 KB, rendered ≈ 0.7–2.0 MB on the same windows):

| cell | GPU location | gpu-process children (this prefix) | window | capture |
|---|---|---|---|---|
| `--disable-gpu --single-process` (mikey92's pair) | in-process | 0 | **none** | — hot spin, 174 % CPU |
| **`--single-process`** | in-process | 0 | yes | **2,018,352 B — renders, ZERO glyphs** |
| control, no shim, no flags | out-of-process | crashes ×3 | yes | 40,903 B (black) |
| `--use-angle=gl` | out-of-process | crashes ×3 | yes | (see capture-blind note) |
| `--use-angle=vulkan` | out-of-process | crashes ×3 | yes | (see capture-blind note) |

**What this changes.** The open lead was *"why does `--in-process-gpu` kill glyphs?"* — that framing
is now wrong. **Any route that puts Chromium's GPU in the browser process renders art and drops
every glyph**, so the cause sits in the in-process-GPU path itself, not in one switch. Same
signature both times: artwork, thumbnails, gradients, icons and chrome perfect; nav bar reduced to
bare dropdown carets, empty search field, no titles or prices; the only readable text is baked into
promo images.

**And `--disable-gpu --single-process` is worse than either.** With no GPU *and* one process,
Chromium cannot make a GL context at all — `gl_factory_win.cc(63) NOTREACHED`, `Failed to create
GLES3 context, fallback to GLES2`, `ContextResult::kFatalFailure: Failed to create shared context
for virtualization`, looping at ~174 % CPU with **no window ever appearing**. mikey92's pair works
for them because their Steam client is on vanilla wined3d; on DXMT builtins it is a dead end,
which matches their own report of a 10 s webhelper restart loop.

**The cross-process wall is backend-independent.** Out-of-process, the GPU process crashes 3× in a
launch regardless of ANGLE backend — default (D3D11), `gl`, and `vulkan` all identical. So this is
not "DXMT lacks a D3D11 path"; nothing presents cross-process here.

⚠ **Instrument note — validate before trusting an all-black reading.** Two cells ran while the
display auto-locked; `screencapture` then produces **no file at all**, and the tell is
`owner=loginwindow` at layer ≥1999 in `/tmp/winlist`. Per `winlist.swift`'s own header, capture a
**known-good** window in the same pass — when the Firefox/Claude control also fails, the
instrument is blind and the cell is void, not black. Hold the display awake (`caffeinate -d -i -u`)
for any unattended cell.

**Adopted from soju's writeup and worth keeping:** a stale Chromium `SingletonLock` in `htmlcache`
silently turns the next Steam launch into `--silent` — i.e. **no window**, which reads exactly like
a render failure. `scripts/steam-render-cell.sh` purges it per cell.

⚠ **SUPERSEDED — this route was built and measured the same day, and again on 2026-08-29 in
combination with the shim. It does not work; it is strictly worse.** See § "Taking DXMT out of
Steam's path entirely does NOT fix it" and § "The vanilla-wined3d split is strictly WORSE than
DXMT for Steam's CEF". The paragraph below is kept for the harvesting recipe only.

**Was untested at the time of writing:** Steam's processes on **vanilla wined3d** while the
game keeps DXMT. It cannot be tried here today — every `d3d11.dll`/`dxgi.dll` on this machine is
DXMT's, in **both** arch trees and in every `.bak` (all 5,304,320 B / 7,780 dxmt strings), so there
is no vanilla PE to point a per-app override at. Harvesting one means a fresh
`scripts/build-engine-1116.sh` run (~1 h): step 3's `gmake install` lays down vanilla wine, and
step 4 is what overlays DXMT — the vanilla `d3d11.dll` + `dxgi.dll` exist in between.
⚠ Version-couple it: wine's `d3d11.dll` talks to `wined3d.dll` over an internal, per-release ABI,
so a vanilla PE must come from the **same 11.16 build**, not from the PK 11.0 tree.

⚠ Note also that our i386 tree is DXMT (`lib/wine/i386-windows/d3d11.dll`, 5,369,856 B) where
soju's rule 5 keeps i386 vanilla for the 32-bit steam.exe composer — **but that rule is not a
necessary condition**: `CS2dxmt11-pk110` carries the same DXMT i386 build (7,785 dxmt strings) and
renders Steam's text fine. Do not treat i386-vanilla as the explanation.

## The vanilla-wined3d split is strictly WORSE than DXMT for Steam's CEF — and the trap that nearly voided the test (2026-08-29)

> **Ledger: `VOID`.** Evidence: `exp_a886cb`, `exp_7ae4c7`, `exp_0dbb6c`, `exp_cc3bb9`, `exp_154886`
> — every cell ran with no font library, and the `--shim-args` cells were shimmed in `cef.win7x64`
> while Steam runs `cef.win64`, so the injected switches never reached CEF. Neither side of the
> comparison was the configuration it is labelled with. The **DllOverrides-keyed-on-exe-name trap**
> documented here is a real, re-verifiable mechanism and is worth keeping.

[mikey92 on dxmt#141](https://github.com/3Shain/dxmt/issues/141) pointed out a real hole in the
2026-08-28 matrix: the split had only ever been run with **default out-of-process CEF**, and the
`--disable-gpu --single-process` pair had only ever been run on a **DXMT** client. The cell they
actually use daily — *both together* — had never been run here. They were right, it hadn't. It has
now, and it makes things worse rather than better.

⚠ **The trap, first — it silently invalidates any "split + shim" cell.** Wine keys
`HKCU\Software\Wine\AppDefaults\<exe>\DllOverrides` on the executable's **file name**, and
`install-webhelper-shim.sh` renames the real CEF binary to **`steamwebhelper_real.exe`** (the shim
takes the original name). So a split whose per-app list is `steam.exe steamwebhelper.exe
steamservice.exe` does **not** cover the process that actually loads d3d11 — it falls through to
the *global* override, which this split deliberately pins to `builtin` **= DXMT**. The first
combined cell ran clean, produced a plausible result, and was testing the DXMT client. The two
mechanisms only compose if **both** names are in the list; `steam-vanilla-d3d-split.sh` now carries
`steamwebhelper_real.exe` with that reasoning inline. Proof the fix landed, from `+loaddll` inside
the webhelper's own process tree: `dxgi.dll … native`, `wined3d.dll … builtin`, **no winemetal
anywhere**, alongside `steamwebhelper_real.exe`, `libcef.dll` and ANGLE's `libglesv2.dll`.

**Four cells, one variable at a time, judged by per-window capture:**

| cell | client d3d11 | shim args | window | CPU | result |
|---|---|---|---|---|---|
| `split-pair-v2` | vanilla wined3d | `--disable-gpu --single-process` | **none** | 174 % | mikey92's exact pair — hot spin |
| `split-ipgpu-swiftshader` | vanilla wined3d | `--in-process-gpu --use-gl=swiftshader` | **none** | 172 % | hot spin |
| `split-single` | vanilla wined3d | `--single-process` | **none** | 173 % | hot spin |
| **control** — `dxmt-single-control` | **DXMT** | `--single-process` | **yes** | **9.0 %** | **1,810,329 B rendered, ZERO glyphs** |

The control is the load-bearing row: it reproduces the 2026-08-28 reading (2,018,352 B then,
1,810,329 B now) on the same harness in the same session, so the three "no window" results are
measurements, not a broken rig. Store artwork, thumbnails, gradients and chrome are perfect; the
nav bar is six bare dropdown carets, the search field is empty, and no capsule has a title or
price. The only readable text is baked into promo images.

**Why the split fails — ANGLE names it, so this is not inference.** On vanilla wined3d *every* EGL
display type fails, in this order:

```
Renderer11.cpp:1108 (rx::Renderer11::populateRenderer11DeviceCaps):
    Error querying driver version from DXGI Adapter.              <- D3D11 path
eglCreateContext: Requested GLES version (3.0) is greater than max supported (2, 0).   <- GL path
eglInitialize SwANGLE failed with error EGL_NOT_INITIALIZED
    Internal Vulkan error (-9): The requested version of Vulkan is not supported ...   <- SwANGLE
Initialization of all EGL display types failed.
GLDisplayEGL::Initialize failed.
gl_factory_win.cc(63)] NOTREACHED hit.        <- then loops ~1,043,304 times in one 95 s cell
```

So the conclusion inverts the intuition the split was built on: **DXMT is the only D3D11 on this
stack that gives Chromium a working ANGLE display.** Its DXGI answers
`populateRenderer11DeviceCaps`; vanilla wined3d's does not, and neither fallback is available
(wined3d's GL backend caps at GLES 2.0 here — consistent with its `GL_INVALID_FRAMEBUFFER_OPERATION
from glClear` on macOS 26 — and SwANGLE's Vulkan is rejected outright). Taking DXMT out of the
client's path removes the one path that works.

**`--use-gl=swiftshader` is a dead switch on this CEF, not a missing idea.** Modern Chromium moved
software selection to `--use-angle=swiftshader`, which was **already measured here on 2026-08-24**
(with `--in-process-gpu` + `vulkan-1=n,b`) and renders art with no glyphs like every other
in-process route. The `--use-gl` spelling is worse than useless: it converts a *working*
`--in-process-gpu` cell into the same NOTREACHED loop. Don't re-chase it from the Battle.net
data point.

**Worth keeping from mikey92 regardless:** starting steam.exe with **`-noverifyfiles`** stops the
integrity pass from restoring a replaced `steamwebhelper.exe`, which is a cleaner alternative to
size-padding the shim (§ "Verifying file sizes only"). Our padded shim passes either way, so this
was not adopted — but it is the fix if Valve ever switches from sizes to hashes.

**Fixed in passing — `--verify` could never return.** `dxtest.exe` renders forever (its message
loop exits only on `WM_QUIT`), and piping it to `head` does **not** kill it because grep
block-buffers, so the SIGPIPE never arrives. Two `--verify` runs this session were written off as
"timed out" when the probe was doing exactly what it was written to do. macOS has no coreutils
`timeout`; the branch now launches, polls the log for up to 25 s, and kills. A verification step
that hangs is worse than none — the script's own output tells you to run it.

**Everything reverted and re-verified**: DXMT builtins restored (`metal=197 wined3d=0`, builtin
marker back), all per-app overrides deleted, shim reverted to the original 7,489,176 B webhelper,
and the game path re-checked with the now-working `--verify` — `winemetal.dll builtin`,
`DXGI.DLL builtin`, `d3d11.dll builtin`.

## ⚠ The split never gave Steam a WORKING D3D11 — a load is not an implementation (2026-08-29)

> **Ledger: `SUPPORTED`.** Unaffected by the 2026-08-30 audit: this is a `dxgiprobe` result, and a
> standalone PE resolves its libraries normally (the same property that invalidated C5/C6 as
> *eliminations* makes it sound here — the question asked is about D3D11, not fonts).

**This corrects the 2026-08-28 conclusion two sections up, and the comment posted from it.** Asked
whether anything else was worth testing before replying to mikey92, the answer turned out to be
yes, and it inverted the result.

`scripts/dxgiprobe.c` (new) calls the *exact* query ANGLE's D3D11 renderer fails on —
`IDXGIAdapter::CheckInterfaceSupport(__uuidof(IDXGIDevice), &umdVersion)`, which is what
`Renderer11::populateRenderer11DeviceCaps` uses for the driver version — and then tries
`D3D11CreateDevice`. Build:
`x86_64-w64-mingw32-gcc dxgiprobe.c -o dxgiprobe.exe -ld3d11 -ldxgi -ldxguid -luuid`.

| configuration | `CheckInterfaceSupport` | `D3D11CreateDevice` |
|---|---|---|
| **DXMT** (`d3d11=b,dxgi=b`) | **`0x00000000` S_OK** | **`0x00000000`, FL `0xB000`** |
| vanilla d3d11 + vanilla dxgi (`n,n`) | — never reached — | **abort** |
| vanilla d3d11 + DXMT dxgi (`n,b`) | — never reached — | **abort** |
| DXMT d3d11 + vanilla dxgi (`b,n`) | `0x00000000` S_OK | `0x00000000`, FL `0xB000` |

Both vanilla-`d3d11` rows die before the probe's first `printf`:

```
wine: Call from 00006FFFFFC16AEA to unimplemented function dxgi.dll.DXGID3D10CreateDevice, aborting
```

with **either** dxgi underneath it. (String counts: the harvested vanilla `dxgi.dll` carries
`DXGID3D10CreateDevice` **7** times; DXMT's carries it **0** — so DXMT's dxgi does not export it
at all, and the vanilla one exports it as a winebuild stub.)

**What this overturns.** The 08-28 finding read: *the split provably landed, Steam is still black,
byte-identical on wined3d's GL and Vulkan renderers — therefore the D3D implementation is not the
variable and the client's black window was never DXMT's missing cross-process swapchain.* That
comparison was against a **non-functional** alternative. `+loaddll` proved the vanilla PE **loaded**;
it never proved the PE **worked**, and a d3d11 that aborts at device creation cannot render
anything by any route. "Black either way" was therefore never evidence about DXMT. The
byte-identical GL-vs-Vulkan reading has the same hole — both runs were black for the same trivial
reason.

⚠ **The transferable rule, and the one this whole thread kept missing: a module load is not a
working implementation.** Verify any swapped graphics DLL with a **device-creation probe**
(`scripts/dxgiprobe.exe`), never with `+loaddll` alone. Three separate sessions took a `native`
line in a loaddll trace as proof the swap had taken effect.

**RESOLVED the same session — wired properly, vanilla wined3d works, and it is still disqualified,
for a reason nothing had measured before.** The discriminator: vanilla `d3d11.dll` + `dxgi.dll`
installed as **true builtins** (marker intact) into an APFS-cloned wine tree
(`cp -Rc`, instant and free), driven from a scratch prefix.

| configuration | adapter reported | `CheckInterfaceSupport` | `D3D11CreateDevice` |
|---|---|---|---|
| **DXMT** | **Apple M3 Max** (0x106B / 0x1A0603F1) | **S_OK** | **FL `0xB100` = 11_1** (explicit list; `0xB000` = 11_0 via NULL list) |
| vanilla wined3d, GL renderer | *"NVIDIA GeForce 6800"* (0x10DE/0x0041 — wined3d's fallback card) | `0x887A0004` **DXGI_ERROR_UNSUPPORTED** | FL `0x9300` = **9_3** (both forms) |
| vanilla wined3d, `renderer=vulkan` | **Apple M3 Max** (correct) | `0x887A0004` **DXGI_ERROR_UNSUPPORTED** | FL `0x9300` = **9_3** (both forms) |

Three things fall out, and the middle one is the answer:

1. **The marker-strip/`native` trick is what aborts, not wined3d.** As true builtins the same PEs
   create a device fine. So the split *as wired here* was broken; soju's technique needs different
   wiring on this stack.
2. **`0x887A0004` is `Renderer11.cpp:1108` — reproduced outside Chromium.** ANGLE's "Error querying
   driver version from DXGI Adapter" is literally wined3d's dxgi returning `DXGI_ERROR_UNSUPPORTED`
   from `CheckInterfaceSupport`. DXMT returns `S_OK`. This is now a measured API delta rather than
   an inference from a CEF log.
3. **Vanilla wined3d tops out at feature level 9_3 here — DXMT reaches 11_1.** That holds even with
   the Vulkan renderer correctly identifying the M3 Max, so it is not the fallback-adapter bug.
   ⚠ **Asked BOTH ways before publishing**, because the first pass used only `pFeatureLevels=NULL`
   (the runtime's default list) and a single-form measurement is how this project has produced a
   wrong headline number before: with an **explicit** `{11_1, 11_0, 10_1, 10_0, 9_3}` array,
   vanilla wined3d still returns **9_3** and DXMT returns **11_1**. The probe now prints both.

⚠ **RESOLVED — the valid test was built and run the same day; see the next section.** The finding
below stands as the reason it was needed: **every Steam cell run against the split before that point
— 08-28 and 08-29 alike — used the broken marker-strip wiring.** Those cells were not measuring a
vanilla-wined3d client; they were measuring a client whose `d3d11.dll` aborts at device creation.
The "no window, ~174 % spin" rows say nothing about wined3d. **A valid Steam-side test of the split
has still never been run here**, and it cannot be run with the marker-strip trick at all — the
true-builtin wiring is engine-global, so it would take the game's DXMT away too. It needs a
separate wrapper (clone the tree, install vanilla builtins, point it at a Steam-bearing prefix).
Not yet done; do not describe the split's Steam behaviour as measured until it is.

**Was NOT established at this point:** that FL 9_3 is what breaks CEF — the `Requested GLES version
(3.0) is greater than max supported (2, 0)` line was logged in a cell whose d3d11 aborts, so ANGLE
may never have reached a D3D11 device. ✅ **Settled by the valid run in the next section**, where the
same line appears on a working FL 9_3 device.

⚠ Two traps found setting the scratch prefix up, both of which cost ~15 min of apparent hang:
wine **refuses a `WINEPREFIX` under `/tmp`** ("is not owned by you"), and a fresh-prefix `wineboot`
**blocks on the Wine Mono installer dialog** with no console output at all — it looks exactly like
a hang. Always create scratch prefixes with `WINEDLLOVERRIDES="mscoree=d;mshtml=d"`.
⚠ And the orphaned `wineboot.exe` processes could **not** be killed with `pkill -f wine-vanilla-test`
— wine processes carry Windows-style argv, the same attribution trap this repo already documents
for steam.exe. Kill by PID after checking `lsof` against the prefix.

## The valid Steam-side test at last: DXMT beats vanilla wined3d at EVERY cell (2026-08-29)

> **Ledger: `UNREVIEWED` (C9).** The feature-level numbers come from a standalone probe (`dxgiprobe`) and are font-independent, so they plausibly survive — but this has **not** been re-audited against the config rules. Do not cite as settled.

The section above closed with "a valid Steam-side test of the split has never been run here." It has
now. `scripts/make-vanilla-wrapper.sh` builds the thing that makes it possible: an APFS clone of the
daily wrapper (`cp -Rc`, ~0 disk on a 103 GB bundle) whose **wine tree** carries the vanilla
`d3d11.dll`/`dxgi.dll` as **true builtins, marker intact**. That wiring is engine-global — which is
exactly why it cannot be done in the daily wrapper, and why a separate bundle was the only route.

Probe first, in the clone's own Steam-bearing prefix: **FL `0x9300` (9_3) both ways, adapter
"NVIDIA GeForce 6800" (wined3d's fallback card), `CheckInterfaceSupport` = `0x887A0004`.** Same
numbers as the scratch prefix, so the wrapper is a faithful vehicle.

**Client on REAL vanilla wined3d** (all capture-judged, instrument validated every cell):

| switches | gpu-process children | crashes | window |
|---|---|---|---|
| none — out-of-process, GL renderer | **1** | **0** | black, **30,482 B** |
| none — out-of-process, `renderer=vulkan` | **1** | **0** | black, **30,482 B — byte-identical** |
| `--in-process-gpu` | 0 | 0 | **none** |
| `--single-process` | 0 | 0 | **none** |
| `--disable-gpu --single-process` (mikey92's pair) | 0 | 0 | **none**, 174 % spin |

**Same cells on DXMT**, for the comparison that was never valid before:

| switches | gpu-process children | crashes | window |
|---|---|---|---|
| none — out-of-process | crashes | **×3** | black, ~40 KB |
| `--in-process-gpu` | 0 | 0 | **renders**, zero glyphs |
| `--single-process` | 0 | 0 | **renders, 1,810,329 B**, zero glyphs |
| `--disable-gpu --single-process` | 0 | 0 | none |

**Conclusion, now properly evidenced: on this machine DXMT is strictly better than vanilla wined3d
at every cell.** The split isn't a missed opportunity; it's a downgrade. The in-process modes that
buy a rendered (if textless) window on DXMT produce **no window at all** on wined3d, and the CEF log
from a *working* vanilla client finally makes the chain attributable end to end:

```
Renderer11.cpp (populateRenderer11DeviceCaps): Error querying driver version from DXGI Adapter.
eglCreateContext: Requested GLES version (3.0) is greater than max supported (2, 0).
eglInitialize SwANGLE failed with error EGL_NOT_INITIALIZED
Initialization of all EGL display types failed. -> gl_factory_win.cc(63) NOTREACHED (×1,127,264)
```

A FL 9_3 D3D11 device lets ANGLE offer **GLES 2.0 only**; CEF asks for **3.0**; every EGL display
type then fails. On 08-29 this was explicitly flagged as correlation-not-chain because the log came
from the broken wiring — this run had a genuinely working D3D11 device, so the attribution holds.

⚠ **And the 08-28 conclusion turns out to be right for reasons it never had.** Its *reasoning* was
invalid (it compared against a d3d11 that aborts). But the out-of-process rows above are the
evidence it lacked: on vanilla wined3d the **GPU process is healthy — 1 child, zero crashes** — and
the window is **still black, byte-identical across wined3d's GL and Vulkan renderers**. A healthy
cross-process GPU that still cannot present is a presentation-layer wall, independent of D3D. So
keep the conclusion, discard the old argument for it, and cite these rows instead.

⚠ **Harness trap found here: with the shim installed, an empty `--shim-args` is NOT "no flags."**
`steamwebhelper-shim.c` falls back to its compiled `APPEND` default of `--in-process-gpu` when
`SHIM_ARGS` is unset, so a "control" cell run with the shim in place silently tests in-process GPU.
One cell was thrown away to this. **For a true out-of-process control, revert the shim** — don't
just omit `--shim-args`.

**Tooling kept:** `scripts/make-vanilla-wrapper.sh` (`--build` / `--verify` / `--remove`) and
`scripts/dxgiprobe.c`. The wrapper itself was **removed** after the run — a Steam-bearing,
DXMT-less bundle sitting in `~/Applications` next to the real ones is a footgun, and `--build`
recreates it in about a minute.

## There is a THIRD mechanism for Steam's CEF, and we had never read its source (2026-08-29)

Asked "are there other sources of workarounds to check before posting?", the answer was yes, and it
reframes the whole thread. mikey92's wrapper comes from **[notpop/steam-on-m1-wine](https://github.com/notpop/steam-on-m1-wine)**
— a source `REFERENCES.md` never listed and this project had never opened (zero hits repo-wide
before today). Its README says the enabler is **not** the vanilla-wined3d split at all. It is two
things we do not have:

1. **`winemac.so` rebuilt with `-fvisibility=default`** (`scripts/08-patch-wine-visibility.sh`),
   *"to make macdrv's public API callable by third-party Metal layers"* — one module, not the whole
   tree: `configure --enable-win64 --disable-tests CFLAGS='-fvisibility=default -O2 -Wno-error'`
   then `make dlls/winemac.drv/winemac.so`. Their own success check is `nm -g` showing **≥100
   public text symbols**.
2. **A DXMT fork** — `notpop/dxmt@debug/present-path-tracing`
   (`924a607e3eee06fad5be6f176d8510bb08bc418d`), ~150 lines over upstream, which *"rewrites
   `_CreateMetalViewFromHWND` around two Wine 11 bugs"*: `macdrv_win_data` no longer exposing a
   usable NSView at swap-chain creation, and wrapping macdrv's Metal helpers in Wine's
   `OnMainThread` deadlocking on re-entrance.

**Measured here immediately, and the numbers matter:**

| engine | global syms in `winemac.so` | **public TEXT (`T`)** | renders Steam? |
|---|---|---|---|
| our self-built stock 11.16 + DXMT | 550 | **0** (2 `S` + 1 `D _macdrv_functions`; the rest `U`) | no |
| **PK 11.0 vendor build** | 535 | **0** (2 `S`) | **YES** |
| notpop's patched build | — | **≥100** (their gate) | yes |

**So there are at least THREE independent mechanisms, and symbol visibility is not the one PK
uses.** PK renders Steam while exporting exactly as little as we do — which *confirms* the
2026-08-24 PM-2 conclusion (PK wins via its vendor patchset) rather than replacing it, and shows
notpop's route is a genuinely separate third path that our engine has never had.

Supporting detail: our `winemac.so` does contain the helpers by name —
`macdrv_view_create_metal_view`, `macdrv_view_get_metal_layer`, `macdrv_view_release_metal_view`
(plus `my_`-prefixed variants) — and `winemetal.dll` in **both** wrappers carries
`CreateMetalViewFromHWND`. The functions are all present; they are simply not *exported*, which is
exactly the gap `-fvisibility=default` closes.

⚠ **What this means for the reply to mikey92:** they attribute their working client to the
vanilla-wined3d split, but per notpop's own README their stack also carries the visibility rebuild
**and** the forked DXMT. The split may not be what is carrying it. That is worth raising — carefully,
since we cannot see their specific install — and it makes the "which EGL display initializes"
question much less interesting than "are you on notpop's patched `winemac.so` and DXMT fork?"

**HALF 1 TRIALLED THE SAME DAY — built, gated, measured, and it changes nothing on its own.**
`scripts/build-winemac-visibility.sh` rebuilds **only** `dlls/winemac.drv/winemac.so` from the same
DXMT-patched 11.16 source the engine uses (`wineandaqua-dxmt.patch`), with the engine's exact
configure line plus `CFLAGS/CXXFLAGS='-fvisibility=default -O2 -Wno-error'`. Result:

| | public TEXT symbols | `macdrv_*` public |
|---|---|---|
| installed engine | **0** | 0 |
| rebuilt module | **213** ✅ (notpop's gate is ≥100) | **183** |

and the exports are exactly the ones the fork needs — `macdrv_view_create_metal_view`,
`macdrv_view_get_metal_layer`, `macdrv_view_release_metal_view`,
`macdrv_client_surface_acquire_metal_swapchain`, plus `get_win_data`/`release_win_data` (the
`macdrv_win_data` accessors named in notpop's bug description).

**Installed into a clone wrapper it is ABI-clean but inert**: wine 11.16 starts, no driver errors,
DXMT still reports Apple M3 Max at **FL 11_1** — and Steam is **still black (108,343 B**, GPU
process healthy, 1 child, 0 crashes**)**. That is the expected result: per notpop's own README the
flag exists to make macdrv's API *callable by* the forked DXMT, so it is an enabler, not a fix.
**Half 1 is necessary-not-sufficient; the fork is the active ingredient.**

⚠ **The first run of that cell reported "no window" and was WRONG** — Steam was still verifying its
install at the 95 s mark. Re-run at `--wait 165` it produced the window. **A no-window reading on a
freshly-cloned wrapper means "not finished starting" until a longer wait says otherwise.**
⚠ Also ruled out while diagnosing that: `Wine cannot find the FreeType font library` appears in
**every** Steam cell including the one that renders (17 occurrences in the successful
`--single-process` run, 59 in others). It is pre-existing noise, not a symptom — do not chase it.

**HALF 2 ATTEMPTED — it gets all the way to the Metal shader compiler and stops there.**
`scripts/build-dxmt-fork.sh` captures the whole verified recipe. What was learned:

- ⚠ **Do NOT build LLVM from source.** notpop's own script compiles `llvmorg-15.0.7` (~1 h). It is
  unnecessary: the fork's meson default `native_llvm_path` is already **`/usr/local/opt/llvm@15`**,
  i.e. the **Intel**-Homebrew prefix, because airconv links LLVM as a macOS **x86_64** static lib to
  match our x86_64 wine. An Intel Homebrew already exists on this machine, so
  `arch -x86_64 /usr/local/bin/brew install llvm@15 zstd` drops a bottle at exactly that path with
  `libLLVMCore.a` present — **minutes instead of an hour**. (The arm64 `/opt/homebrew` `llvm@15` is
  the wrong arch and will not do.)
- **meson configures cleanly against our own engine**: `-Dwine_install_path=…/engine-1116` resolves
  `winecrt0`, `ntdll`, `dbghelp` and `bin/winebuild`. 16 targets, no complaints.
- **A real portability bug in the fork, found and fixed here:** `src/util/com/com_guid.cpp` uses
  `std::setfill`/`std::setw` without `#include <iomanip>`. Older GCC pulled it in transitively; our
  mingw-w64 does not. One line — kept as `scripts/dxmt-fork-iomanip.patch`, and worth sending to
  notpop. With it applied the **entire C++ side builds clean**.
- 🚧 **The remaining blocker is FULL XCODE, and only that.** The build compiles Metal shaders with
  `xcrun -sdk macosx metal`, which ships with Xcode.app and is **not** in the Command Line Tools
  (this machine has CLT only: `xcode-select -p` → `/Library/Developer/CommandLineTools`). Measured:
  of 7 remaining `FAILED` lines, **7 are `unable to find utility "metal"` and 0 are anything else**.
  Fix is the user's: install Xcode from the App Store, then
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (and
  `xcodebuild -downloadComponent MetalToolchain` if `xcrun -f metal` still fails). Neither is
  runnable unattended.

⚠ **`meson compile … | tail` reported the failing build as exit 0** and it was briefly read as a
success. Same class as the `<cmd> | tail` trap in the engineering rules — **capture to a log and
read the real `$?`**. `build-dxmt-fork.sh` does that.

**What the fork's commit message says — the best statement of this bug that exists anywhere**, and
it is worth quoting to dxmt#141 whether or not we ever build it. Two stacked root causes, both with
file:line:
1. `struct macdrv_win_data` is the wrong place to read the NSView: **Wine 11 renamed the field to
   `client_view` and only populates it in the GDI present path**
   (`dlls/winemac.drv/window.c:1131-1135`, `macdrv_client_surface_present()`). At `IDXGISwapChain`
   creation time it is **always NULL**, so the old code handed `macdrv_view_create_metal_view` a
   NULL view and returned silently empty.
2. `macdrv_view_create_metal_view` / `_get_metal_layer` / `_release_metal_view`
   (`cocoa_window.m:3941/3954/3966`) **already dispatch through `OnMainThread(^{…})`**. Wrapping
   them in another `OnMainThread` in the unixlib is nested main-thread dispatch — and `OnMainThread`
   (`cocoa_event.m:489`) is `OnMainThreadAsync` + wait, so **the outer wait deadlocks against the
   inner block**.

The rewrite reaches the NSView via the stable public `macdrv_get_cocoa_window(HWND, BOOL)` plus
`[NSWindow contentView]`, dispatches only the contentView lookup, and calls the Metal helpers
directly from the NtUser caller thread so their internal main-thread hops are not re-entered.

⚠ **Read their verification claim precisely: it is a GAME, not the Steam client.** *"Verified on
Apple Silicon M1 + macOS Tahoe 26.4 + Wine 11.0 rebuilt with `-fvisibility=default`, running the
32-bit Unity 6000 game 幻獣大農場 (Steam AppID 3659410): Present1 returns hr=0x0 every frame."*
So the fork is evidenced for **game** presentation. Whether it also fixes the **CEF client** is not
claimed there — which is exactly the question to put to mikey92, since their Steam UI may be riding
on the `--disable-gpu --single-process` wrapper rather than on this patch.

 Measured 2026-08-29: **`meson`, `ninja`, `llvm-config` and `cmake` are all
missing** on this machine (only Apple clang + git). notpop's `07-build-dxmt-fork.sh` needs meson
with `-Dnative_llvm_path` and two cross-files, built twice (64- and 32-bit). **`notpop/dxmt` also
publishes NO releases**, so there is no prebuilt fork to drop in — it must be compiled. Every DXMT
binary in this project was *reused* from the Wine 11.0 + DXMT base engine, never compiled. Standing
up that toolchain is ~2-3 GB of brew installs and its own mini-project.

**Also eliminated today, both never previously run** (daily wrapper, capture-judged):
`-cef-force-gpu` → black **108,343 B**, GPU process survives (1 child, no crashes) ·
`--use-angle=d3d9` → black **108,343 B**, same. So ANGLE's D3D9 backend and Steam's own
force-GPU switch join `d3d11`/`gl`/`vulkan`/`swiftshader` on the eliminated list.

## ✅ notpop's fork BUILT and TESTED — it does not fix the Steam client, and that restores dxmt#141 (2026-08-29)

> **Ledger: `PARTIAL`.** Evidence: `exp_454e00`, `exp_56dbae`, `exp_3206bc` — all ran with no font
> library. "Still black" is a font-independent judgment and survives; anything this section implies
> about **text** does not. The build recipe (Metal Toolchain gate) is unaffected.

Both halves of the third mechanism were built and run end to end. The result is decisive and it
points back at the issue itself.

**Getting there.** `xcrun -f metal` resolving is **not** a sufficient gate — with Xcode installed
the binary exists but on macOS 26 the shader compiler is a separate asset, and every `.air` target
still died with *"cannot execute tool 'metal' due to missing Metal Toolchain"*.
`xcodebuild -downloadComponent MetalToolchain` (687.9 MB, "Metal Toolchain 17F109") fixed it.
`build-dxmt-fork.sh` now gates by **compiling a one-line kernel**, not by `xcrun -f`.
Then both arches built clean — 64-bit `[123/123]` — producing `d3d11.dll` (22,952,314 B),
`dxgi.dll`, `d3d10core.dll`, `winemetal.dll` and `winemetal.so` (27,924,584 B), plus the 32-bit set.

**Installed into a clone carrying BOTH ingredients** (forked DXMT + the `-fvisibility=default`
`winemac.so`, 213 public text symbols), the engine is healthy: Apple M3 Max, `CheckInterfaceSupport`
`S_OK`, **FL 11_1**.

**And Steam is still black — but now it says why, in DXMT's own words:**

```
err:   CreateSwapChain: cross-process swapchain not supported yet
```

`src/d3d11/d3d11_swapchain.cpp:1102`. **The fork still refuses cross-process swapchains.** Verified
by string count: the built forked `d3d11.dll` carries that message **1** time; our stock DXMT v0.80
carries it **0** times (it is newer upstream code — v0.80 merely crashed the GPU process instead of
naming the refusal).

**What that settles.** notpop's fork rewrites `_CreateMetalViewFromHWND` for the **same-process**
path — which is why their evidence is a *game* (`Present1 returns hr=0x0 every frame`) and why it
works there. Steam's CEF creates its swapchain for an HWND owned by **another process**, and that is
a different code path which the fork does not touch. So:

- the vanilla-wined3d split is dead here (wined3d caps at FL 9_3),
- notpop's visibility + fork route fixes games, not the client,
- and therefore **dxmt#141 itself — cross-process swapchain support — really is the blocker for the
  Steam client.** Every workaround is now eliminated *by measurement*, which is a better outcome
  than another dead end: it puts the fix back where the issue already says it belongs.

⚠ **The fork does change the failure mode, which is worth reporting.** Out-of-process on stock DXMT
v0.80 the GPU process crashes ×3 per launch; with the fork ANGLE gets **further** — it reaches
`SwapChain11::reset` (*"Could not create additional swap chains or offscreen surfaces"*) and
`eglCreateWindowSurface: Bad allocation` — before the same black window. A crash became a named
refusal. That is a diagnosability win even though the outcome is unchanged.

**And it explains mikey92 without contradicting them.** Their client renders because *their* wined3d
serves D3D11 at a usable feature level (Wine 11.0 / macOS 26.5), taking DXMT out of the CEF path
entirely — the split IS load-bearing for them. Ours caps at 9_3, so the same split cannot work.
The feature-level probe is exactly the discriminator, which is why the reply asks for it.

**Cleanup:** shim reverted in the clone; daily wrapper verified pristine (`d3d11` 5,304,320 B = stock
v0.80, `winemac.so` 0 public T, game path `d3d11 -> builtin`). `CS2vis-test.app` retains the full
notpop stack and is the artefact to keep if this is revisited — **never run the game in it.**

## The cross-process root cause, MEASURED: `macdrv_get_cocoa_window` returns NULL for a foreign HWND (2026-08-29)

> **Ledger: `SUPPORTED` (C3).** Derived from reading wine's source plus a targeted probe, not from a render cell — unaffected by the 2026-08-30 library audit.

The refusal in DXMT is a **precondition check that returns before attempting anything**
(`src/d3d11/d3d11_swapchain.cpp`, `CreateSwapChain`):

```c
GetWindowThreadProcessId(hWnd, &window_process_id);
if (GetProcessId(GetCurrentProcess()) != window_process_id) {
  ERR("CreateSwapChain: cross-process swapchain not supported yet");
  return E_FAIL;
}
```

So **nobody had ever observed what actually breaks.** Upstream `3Shain/dxmt` has four branches
(`main`, `ci/arm64x`, `feat/d3d12-5`, `feat/d3d12-6`) — no work in progress on this. We had a
working build, so we forced it: the guard was made env-gated
(`DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1`, kept as `scripts/dxmt-force-crossprocess.patch`) and the
Steam cell re-run.

**It fires, with genuine cross-process IDs** — 6 times in one launch:

```
err: CreateSwapChain: cross-process swapchain FORCED (experimental) hwnd_pid=300 self_pid=472
```

**And then the real failure, with `DXMT_DEBUG_METAL_VIEW=1`:**

```
CreateMetalViewFromHWND: hwnd=0x10102 macdrv_functions=0x213810560
    get_cocoa_window=0x2137e3d20 create_metal_view=0x2137e3df0 get_metal_layer=0x2137e3e40
CreateMetalViewFromHWND: cocoa_window=0x0
CreateMetalViewFromHWND: macdrv_get_cocoa_window returned NULL for hwnd=0x10102.
```

Three things follow, and each kills a wrong explanation:

1. **Every macdrv symbol resolved** (all pointers non-NULL). So DXMT's own error —
   *"Failed to create metal view, it seems like your Wine has no exported symbols needed by DXMT"*
   (`d3d11_swapchain.cpp:137`, followed by `abort()`) — is the author's **guess**, and it is the
   wrong diagnosis whenever the symbols are in fact present. It is what makes this failure look
   like a build problem when it is not.
2. **`macdrv_get_cocoa_window(hwnd, FALSE)` returns NULL for the foreign HWND.** Winemac's window
   data is **per-process**; a window created by another process is not in this process's table.
   That is the actual wall.
3. **The fork's own fallback comment is also wrong here** — it reads *"the window is probably still
   in the middle of being created; the caller will retry"*. It is not mid-creation; it belongs to
   another process and will never appear. Meanwhile the D3D11 side `abort()`s on the NULL, which is
   the `GPU process exited unexpectedly` in `cef_log.txt`.

**So "cross-process swapchain not supported yet" is not swapchain bookkeeping.** A Metal view cannot
be built for a foreign HWND at all, because there is no cross-process route from HWND to NSWindow.
Any fix has to solve *that* — which is a winemac/wineserver-level problem, not a DXMT-only one, and
it lines up exactly with the 2026-08-24 findings (a cross-process GDI `FillRect` into a foreign
window is lost on stock winemac too; the PK vendor plumbing that does work spans
winemac/win32u/wineserver).

**Forcing the guard is therefore not a workaround** — it converts a clean `E_FAIL` refusal into an
`abort()` in the GPU process. Window still black (108,343 B). Kept for diagnosis only.

## Cross-process, all the way down: wine's own branch is OFFSCREEN, and that is the real wall (2026-08-29)

> **Ledger: `SUPPORTED` (C3).** Derived from reading wine's source, not from a render cell —
> unaffected by the library audit. Corrected in-thread by the next section, not by the audit.

Pulling the thread past the DXMT guard produced the complete chain. Four refusals stack, and
removing them one at a time gets a *Metal view* for a foreign HWND — but never a *pixel* in the
foreign window.

**1. `macdrv_get_cocoa_window` can't work cross-process, by construction.** It is
`get_win_data(hwnd)` (`window.c:223`), and `get_win_data` is a lookup in `win_datas`, a
**process-local `CFDictionary`** guarded by `win_data_mutex` (`window.c`). Another process's window
is simply not in this process's table. `release_win_data(NULL)` is a safe no-op, so the NULL path
is clean — it just never yields a window.

**2. But our engine has a second, better path that notpop's fork deliberately abandoned.** The
aquadran DXMT patch adds `my_get_win_data` (`macdrv_main.c:684`), which calls
**`macdrv_CreateClientSurface(hwnd, 0)` *first*** and hands DXMT a `client_cocoa_view`. notpop's
rewrite avoids `macdrv_win_data` because on **stock** Wine 11 `client_view` is only populated from
the GDI present path — true there, but our patched winemac creates the surface on demand. Two
different engines, two different correct answers.

**3. Wine already has a cross-process branch — and it names its own limit.** In
`macdrv_client_surface_acquire_metal_swapchain` (`window.c:1165`):

```c
if ((data = get_win_data(hwnd)))  { ... macdrv_create_view_swapchain(surface->cocoa_view); }
else {
    if (NtUserGetAncestor(hwnd, GA_ROOT) != hwnd) {
        FIXME("Cross-process child window Metal swapchains are not implemented\n");
        return FALSE;
    }
    surface->metal_swapchain = macdrv_create_offscreen_swapchain(hwnd, cgrect_from_rect(rect));
}
```

So for a foreign **root** window wine builds an **offscreen** swapchain
(`cocoa_window.m:4175`); only foreign **child** windows are unimplemented.

**4. The refusal that actually bites is in our own wrapper, and it is removable.**
`my_get_win_data` returns NULL whenever `get_win_data` does — before wine's offscreen branch can
ever run. Gated that on `DXMT_ALLOW_FOREIGN_HWND=1` (kept as
`scripts/winemac-foreign-hwnd.patch`) and rebuilt `winemac.so`. Measured with **stock DXMT v0.80**
(which has *no* cross-process guard at all — 0 occurrences of the string, unlike the newer fork):

- the foreign path fires **46 times** in one launch (`FOREIGN HWND 0x30164 …`),
- **no `Cross-process child window` FIXME** — so these are root windows and the offscreen branch ran,
- **zero `Failed to create metal view`** — DXMT genuinely obtains a Metal view for a foreign HWND,
- and the window is **still black, 108,343 B**.

**That is the answer — but see the NEXT section, which corrects the last step.** The wall is not
view creation and not swapchain bookkeeping; both can be made to succeed. It is that DXMT never
reaches wine's CAContext/CALayerHost route at all, so its offscreen content is never composited
into the window owned by the other process. ⚠ The compositing itself **does** exist and is used by
wine's Vulkan path — the gap is an ABI entry, not a missing implementation. Fixing
dxmt#141 therefore needs cross-process *compositing* (an `IOSurface`/`CAContext`-style shared
layer), which is exactly the shape of the vendor plumbing noted on 2026-08-24 as spanning
winemac / win32u / wineserver — and it is why no DXMT-only change can close it.

⚠ **Caveats on this cell, stated rather than buried.** It ran with `WINEDEBUG=err+all` (the cell
harness normally sets `-all`, which **suppresses wine's own `ERR()`** — the first attempt looked
like "nothing fired" purely because of that). The same run also logs
`err:vulkan:vulkan_init_once Failed to load libMoltenVK.dylib` ×5 and gnutls/kerberos load
failures; those are visible only because err logging was on and are **not** known to be caused by
the patch — do not attribute them without a matched control. The patch also **leaks** the client
surface when there is no `win_data` to own it. Diagnostic build only.

## The cross-process compositing already EXISTS — DXMT just can't reach it (2026-08-29)

> **Ledger: `SUPPORTED` (C3).** Source-derived (the CAContext route is read out of our own patched
> winemac), so no render cell is load-bearing here.

The previous section concluded the wall was "no cross-process compositing." **That was wrong, and
the correction is the most actionable thing in this whole thread.** The machinery is written,
shipping, and in use — DXMT is simply not given access to it.

**What exists in our patched winemac, fully wired:**

| piece | location | what it does |
|---|---|---|
| `CAContextSwapChain` | `cocoa_window.m` | offscreen `CAMetalLayer`, exported via `CAContext contextWithCGSConnection:` → `contextId` |
| `macdrv_create_offscreen_swapchain` | `cocoa_window.m:4175` | returns that CAContext swapchain |
| `macdrv_create_remote_layer(hwnd, id)` | `window.c:1583` | `NtUserPostMessage(hwnd, WM_MACDRV_CREATE_REMOTE_LAYER, 0, id)` — **crosses the process boundary** |
| `WM_MACDRV_CREATE_REMOTE_LAYER` handler | `window.c:1564` | owner calls `macdrv_window_create_ca_layer_host_view(cocoa_window, id)` |
| `CALayerHost` + `_caLayerHosts` | `cocoa_window.m:62, 397` | owner hosts the remote layer in its own `WineContentView` |

The source comment states the design outright: *"Export the CAMetalLayer from the rendering
process, then have the target HWND's owner host it using CALayerHost."* That is textbook macOS
cross-process compositing, and `macdrv_create_remote_layer` is called at the end of
`CAContextSwapChain initWithHwnd:bounds:` — the loop is closed.

**So why is Steam still black? Because the only caller is Vulkan.**

```
vulkan.c:50:  if (!macdrv_client_surface_acquire_metal_swapchain(surface)) return VK_ERROR_INCOMPATIBLE_DRIVER;
```

That is the **sole** call site. And the DXMT-facing ABI cannot reach it —
`struct macdrv_functions_t` (`macdrv_main.c:644`, `C_ASSERT(sizeof == 80)`, ten pointers) exports
`get_win_data` · `release_win_data` · `macdrv_get_cocoa_window` · `create_metal_device` ·
`release_metal_device` · `view_create_metal_view` · `view_get_metal_layer` ·
`view_release_metal_view` · `on_main_thread` — and **not**
`macdrv_client_surface_acquire_metal_swapchain`, nor `macdrv_swapchain_get_layer`.

So DXMT's only route is `macdrv_view_create_metal_view` on the client surface's **local, hidden**
view (`macdrv_CreateClientSurface` does `macdrv_set_view_hidden(..., TRUE)`). It renders correctly
into a layer that is never hosted anywhere. **That is exactly what we measured**: a Metal view
obtained for a foreign HWND, no errors, and a black window.

**The missing last mile is therefore an ABI entry, not an implementation.** A fix candidate:

1. add `macdrv_client_surface_acquire_metal_swapchain` and `macdrv_swapchain_get_layer` to
   `macdrv_functions_t` (⚠ this breaks the `C_ASSERT(sizeof == 80)` contract — every DXMT binary
   compiled against the old layout must be rebuilt; we now have both source trees and working
   builds for exactly that),
2. in DXMT's `CreateSwapChain`, when `GetWindowThreadProcessId(hWnd) != GetCurrentProcessId()`, take
   that path instead of `view_create_metal_view`,
3. present into the returned `CAMetalLayer`.

Wine's Vulkan path is the existence proof that the route works. ⚠ **Untested prediction, stated as
such:** a Vulkan app should already be able to present into a foreign HWND on this engine. Worth
measuring before relying on any of the above.

## 🎯 FINAL: the blocker is cross-process CHILD windows, and it is a one-line FIXME in wine (2026-08-29)

> **Ledger: `SUPPORTED` (C3).** The four-refusal chain is source-derived and each removal was
> observed in our own engine's logs — font-independent. Confirmed downstream by the patch that
> renders.

Wiring DXMT to wine's existing CAContext route located the bottom of the whole thread. Four
refusals, each removed in turn, each handing off to the next:

| # | refusal | where | removed by |
|---|---|---|---|
| 1 | `cross-process swapchain not supported yet` (returns before trying) | DXMT `d3d11_swapchain.cpp:1102` | `scripts/dxmt-force-crossprocess.patch` |
| 2 | `macdrv_get_cocoa_window` NULL — `win_datas` is process-local | winemac `window.c:223` | new ABI entry (below) |
| 3 | `my_get_win_data` refuses a foreign HWND | winemac `macdrv_main.c` | `scripts/winemac-foreign-hwnd.patch` |
| 4 | **`Cross-process child window Metal swapchains are not implemented`** | winemac `window.c:1176` | **nothing — this is the wall** |

**The new ABI entry works.** `macdrv_functions_t` gained
`dxmt_acquire_remote_layer(HWND, macdrv_view*)` (sizeof 80 → **88**; both trees rebuilt in lockstep),
DXMT's `_CreateMetalViewFromHWND` calls it when `macdrv_get_cocoa_window` returns NULL, and the
measurement shows the route is live: **guard forced 6×, REMOTE path taken 6×** in one launch.

**And then wine says no, precisely:**

```
fixme:macdrv:macdrv_client_surface_acquire_metal_swapchain
    Cross-process child window Metal swapchains are not implemented
```

**6 occurrences, matching the 6 attempts.** The branch is
`if (NtUserGetAncestor(hwnd, GA_ROOT) != hwnd) return FALSE;` — wine's cross-process CAContext route
is implemented **only for root windows**, and Steam's CEF presents into a **child** HWND.

**So the entire investigation reduces to one sentence:** *Steam's CEF renders to a cross-process
**child** window, and winemac implements cross-process Metal swapchains only for **root** windows.*

Everything else now follows without hand-waving — games work (same-process); notpop's fork fixes the
same-process view path (its evidence is a game); the vanilla-wined3d split sidesteps DXMT entirely
(and is FL-9_3-capped here); and no DXMT-side change can help, because the unimplemented case is in
wine's macdrv.

⚠ **Note the FIXME is invisible under the harness's usual logging.** `WINEDEBUG=-all` hides it, and
even `err+all` hides it — FIXME is its own class. It needs `+macdrv`. Two earlier cells reported
"no Cross-process child FIXME: 0" purely for that reason and were **wrong**; the correct reading
required `WINEDEBUG=err+all,+macdrv`. Do not conclude "branch not taken" from a channel you have
not enabled.

**Fix shape, for anyone picking this up:** implement the child-window case in
`macdrv_client_surface_acquire_metal_swapchain` — the root-window path already builds a
`CAContextSwapChain` and posts `WM_MACDRV_CREATE_REMOTE_LAYER` to the owner, which hosts it via
`CALayerHost`. A child window additionally needs its rect mapped into the owner's coordinate space
and the hosted layer positioned/clipped there. **That is a wine patch, not a DXMT patch.**

## Cross-process CHILD windows: implemented, builds, TEST BLOCKED ON A STEAM LOGIN (2026-08-29)

The child-window case named by the FIXME is now **implemented and building**, but it has **not yet
been validated** — say so plainly rather than implying otherwise.

**The implementation** (`macdrv_client_surface_acquire_metal_swapchain`, `window.c`): replace the
`FIXME`/`return FALSE` with — resolve `root = NtUserGetAncestor(hwnd, GA_ROOT)`, take the child's
client rect, and build the offscreen `CAContextSwapChain` **against the root** rather than the
child. That matters because `macdrv_create_offscreen_swapchain(hwnd, …)` internally posts
`WM_MACDRV_CREATE_REMOTE_LAYER` to `hwnd`, and the handler needs `data->cocoa_window` — which a
**child HWND does not have**. The root is the window that both owns an `NSWindow` and lives in the
other process. Geometry is deliberately not mapped yet: the hosted `CALayerHost` fills the root's
content view, which is approximately right when the child covers the client area (CEF's main widget
does). Builds clean alongside the `dxmt_acquire_remote_layer` ABI entry.

**Why it is unvalidated: the test clone came up at `Sign in to Steam` (700×440).** With no logged-in
client there is no store/library, so no cross-process child HWNDs are created — `cross-process
swapchain FORCED` counted **0**, versus 6 in the earlier valid run. The cell measured a login window
and nothing else. **Entering Steam credentials is the user's action, not something to automate.**

⚠ **Self-inflicted, and worth knowing before repeating this:** several test clones were launched in
sequence against the same Steam account, and per § "Same-account Steam sessions SWAP" that shuffles
the single online session. The daily wrapper was re-verified afterwards and is **fine** —
`winemac.so` 0 public text symbols, `d3d11.dll` 5,304,320 B (stock v0.80), `loginusers.vdf` intact —
but a *clone* can land on a login prompt. **Warm a clone to a logged-in client before treating any
Steam-UI cell on it as valid**, and prefer reusing one clone over creating several.

⚠ **Timing, again:** a fresh clone's Steam can take **>200 s** to produce any stdout. Two cells here
reported "0 markers" purely because the capture window closed first; a later read of the same file
showed 1,342 lines. `--wait 260` was sufficient in the run that worked. **Never read a marker count
from a cell whose `stdout.txt` is empty.**

**Resume:** `CS2child-test.app` is kept, with the full stack installed (patched `winemac.so` +
forked DXMT + `dxmt_acquire_remote_layer` + child path). Log into Steam in it once, then re-run
`WINEDEBUG=err+all,+macdrv DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1 … --wait 260` and check for
`cross-process CHILD hwnd … -> hosting remote layer on root`.

## ✅ IT RENDERS — the cross-process CHILD patch fixes Steam's black client (2026-08-29)

> **Ledger: `SUPPORTED` (C3).** The capture predates prefix-filtering, so the window PNG alone would
> be open to the foreign-Steam false PASS (trap 6) — but the **44 `cross-process CHILD hwnd → root`
> firings** come from a counter that exists only in our patched engine, which no other wrapper's
> Steam could produce. That is what makes this one safe. Rendering only: this cell says nothing
> about text.

**The wine patch works.** Steam's storefront composites into the window for the first time in this
investigation, in the *stock* configuration that has been uniformly black throughout.

| | before | with the patch |
|---|---|---|
| window capture | **108,343 B** (uniform black) | **2,346,395 B — renders** |
| `cross-process CHILD hwnd → root` | n/a | **44** firings |
| `REMOTE path` layer / view | `layer=0x0 view=0x0` | **`layer=0x7f8008f09f10 view=0x7f8009609aa0`** |
| `acquire_metal_swapchain FAILED` | 6 | **0** |
| `Cross-process child window Metal…` FIXME | 6 | **0** |
| `Failed to create metal view` | 6 | **0** |

⚠ **Configuration, verified rather than assumed — this is the load-bearing detail.** No webhelper
shim (`steamwebhelper_real.exe` absent), **no injected switches at all** (empty cmdline grep), and
**out-of-process GPU** (1 `--type=gpu-process` child in this prefix). That is precisely the stock
setup which measured 108,343 B black on every previous run. So the fix is not a flag, not the shim,
and not the vanilla-wined3d split — it is the winemac child-window patch.

Screenshot: `docs/images/steam-crossprocess-child-renders.png`.

**What is fixed:** artwork, capsules, thumbnails, gradients, nav chrome, the search field — the
store lays out and composites correctly.

**What is NOT fixed: glyphs.** The nav bar is still six bare dropdown carets, capsules have no
titles or prices, and the only readable text is baked into promo art — the same signature documented
since 2026-08-24. ⚠ **And that is a genuinely new wrinkle worth flagging rather than glossing:** the
glyph loss was previously attributed to *in-process GPU*, but this run is **out-of-process**. So
either the glyph defect is broader than the in-process path, or the two have a common cause. Do not
restate the old "in-process GPU kills glyphs" framing as if it still fully explains this.

**Also not yet done: geometry.** The hosted `CALayerHost` fills the root's content view rather than
being positioned and clipped to the child's rect, exactly as the patch header says. Visible as a
black band at the bottom of the capture and a slight offset. That is the next piece of work, and it
is cosmetic relative to what just changed.

⚠ **Not claimed:** the `cef_log.txt` crash counter reads 12, but that file accumulates across the
several launches this clone has had — it is **not** a per-launch figure and no claim is made that
the patch eliminates GPU-process crashes.

**The three patches that together produce this** (all diagnostic-grade, all kept):
`scripts/dxmt-force-crossprocess.patch` (DXMT's up-front refusal) ·
`scripts/winemac-crossprocess-child.patch` (the actual fix — build the CAContext swapchain against
the ROOT for a foreign child) · plus the `dxmt_acquire_remote_layer` ABI entry in
`macdrv_functions_t` (sizeof 80 → 88). `scripts/winemac-foreign-hwnd.patch` is superseded by the
ABI route and is not needed for this result.

## Glyph chase on the new rendering baseline — three hypotheses tested, cause narrowed (2026-08-29)

> **Ledger: `VOID`.** Evidence: `exp_3c7dd2`, `exp_6bd192` — every cell here ran with no font library (28-33 FreeType failures each). The hypotheses were tested against a broken baseline.

With the client finally rendering, the glyph defect was re-attacked on a baseline that actually
shows pixels. **Not fixed** — but the cause is now narrowed to something structural rather than
mysterious, and two plausible explanations are dead.

**1. DirectComposition — ELIMINATED.** Chromium calls `DCompositionCreateDevice3`, which wine stubs
(`fixme:dcomp:`), so "text goes into a DComp visual that never composites" was a good hypothesis.
`--disable-direct-composition` injected via the shim (confirmed on the real webhelper cmdline):
window still **renders, still zero glyphs**. Capture went 2,429,957 → 2,569,047 B — ⚠ and that
increase was **just a busier promo image**, not text. **Capture size is not a glyph proxy; open the
image.** Note this flag had only ever been used here bundled with three others in
`scripts/whwrapper.c`, never isolated.

**2. Stale stacked layers — DISPROVED, and the leak turns out to be load-bearing.** The main Steam
window acquires **7** remote layers in a session (16 distinct child HWNDs → 15 roots overall, so
~1 per window, but the main one retries). Retiring the previous surface per HWND on each acquire —
one hosted `CALayerHost` per window, which also fixes the deliberate leak — sent the window
**straight back to black (108,343 B)**, with 7 retirements logged. **DXMT keeps rendering into the
layer handed to it by an earlier acquire**, so releasing on the next acquire destroys the live one.
Lifetime has to be driven by DXMT releasing its swapchain, not by the next acquire. Reverted, with
the reason recorded in the source.

**3. Z-order — the informative one. Only the TOPMOST hosted layer is ever visible.**
`addCALayerHostViewWithContextId:` does `host.frame = self.layer.bounds` with
`kCALayerWidthSizable|kCALayerHeightSizable` and `[self.layer addSublayer:host]` — so **every host
is stretched over the entire content view**, and newest wins. Probe (`DXMT_HOST_LAYER_BOTTOM=1`,
`insertSublayer:atIndex:0`): **black, 108,343 B**, versus ~2.4 MB rendered with the default. So
whichever layer is on top is the only one you see, and everything under it is hidden.

**Where that leaves the glyphs — ⚠ SUPERSEDED by the next section, which implements the geometry
mapping and finds text still absent.** The leading explanation *at this point* was **occlusion, not
rasterisation**:
several full-bounds layers stacked on one window, only the top one visible, and any content drawn
into the others — plausibly including text-bearing widgets — buried. It fits the earlier
observation that PK renders Steam text *until* the shim is added, and it fits art-without-text.
⚠ **It is not proven.** The alternative — that glyphs are genuinely never rasterised, which is what
the 2026-08-24 in-process work concluded — is not excluded by anything measured here.

**Next step, and it is the piece the child patch already flagged as missing: map the geometry.**
Each child's hosted layer must be positioned and clipped to that child's rect in the root's
coordinate space instead of filling the content view, so the layers stop occluding one another.
That needs the child's rect carried to the owning process (the current
`WM_MACDRV_CREATE_REMOTE_LAYER` only carries a `contextId` in `lParam`; the child HWND could go in
`wParam` and let the receiver compute the rect). Until that exists, "no glyphs" and "layers occlude
each other" cannot be told apart.

## Geometry mapping lands — and it ELIMINATES occlusion as the glyph cause (2026-08-29)

> **Ledger: `PARTIAL`.** Evidence: `exp_3d7586`, `exp_015b85`. The **geometry mapping works** (font-independent). The **occlusion elimination does not** — both cells ran with no font backend, so "not occlusion" was concluded from a run that could not have shown text anyway.

The missing piece of the child patch is implemented: each cross-process child's hosted layer is now
positioned and clipped to its own rect in the root's coordinate space instead of being stretched
over the whole content view.

**Wiring:** `WM_MACDRV_CREATE_REMOTE_LAYER` now carries the **child HWND in `wParam`** (0 for a root)
alongside the `contextId` in `lParam`; the owning process computes
`NtUserGetWindowRect(child) − NtUserGetWindowRect(root)` and passes a `CGRect` down to
`addCALayerHostViewWithContextId:frame:`, which sets `host.frame` + `masksToBounds` instead of
`bounds` + autoresizing. `WineContentView` is `isFlipped = YES`, so Windows' top-left origin maps
straight through with no Y flip. Env-gated on `DXMT_MAP_CHILD_GEOMETRY=1`.

**Result: visibly better composition.** Steam's window chrome now appears — broadcast /
notifications / avatar, minimize / maximize / close, back / forward, refresh and lock icons — all
of which are **separate child widgets that were previously buried** under the full-bounds main
layer. The black band along the bottom is gone. Capture 2,447,073 B.
Screenshot: `docs/images/steam-crossprocess-geometry-mapped.png`.

**So the occlusion hypothesis was REAL — and it is NOT the glyph cause.** Several widgets that were
invisible now render correctly, which is exactly what the hypothesis predicted. And **every one of
them shows icons and artwork with no text at all.** Compositing many more layers correctly did not
bring back a single glyph.

**That flips the conclusion of the previous section.** The leading explanation is no longer
occlusion; it is that **glyphs are genuinely never rasterised into the content**, which is what the
2026-08-24 in-process investigation concluded before any of this. The text defect is therefore
**independent of the presentation path** — it survives in-process GPU, out-of-process GPU, the
CAContext remote-layer route, and now correct per-child geometry. Three presentation architectures,
same missing text.

**Frames observed** (`child → root = x,y w×h`): the main window maps `0,0 1512x949`; smaller widgets
`0,0 36x235`, `0,0 2x1`. ⚠ **Every offset measured was `0,0`**, and many rects are `0x0` at
swapchain-creation time (the widget is not laid out yet) — those fall back to full bounds, so the
mapping is not yet exercised for them. A proper implementation should re-position the host on
`WM_MACDRV_WINDOWPOSCHANGED` rather than only at creation; without that, a widget that moves or
resizes after its layer is hosted keeps a stale frame.

## Glyph-atlas texture path ELIMINATED — `scripts/r8test.c` (2026-08-29)

> **Ledger: `RETRACTED` (C6).** The r8test measurements stand; the *elimination* does not. r8test runs as a standalone PE, and standalone PEs were measured 2026-08-30 to resolve FreeType fine on **both** engines — so it never exercised the failing condition.

Skia uploads glyph masks as single-channel textures and samples them; if that silently yielded
zero, text would vanish while artwork drew. **It does not.** `scripts/r8test.c` is a headless
D3D11 probe — no window, no Steam, no compositor — that uploads a known-white texture, samples it
in a pixel shader, copies the render target to a staging texture and **reads the pixel values back
as numbers**. On the daily DXMT v0.80 engine, feature level 11_0:

| path | R8G8B8A8 (control) | R8_UNORM | A8_UNORM |
|---|---|---|---|
| immutable initial data | **255** | **255** | **255** |
| `UpdateSubresource`, strip at a time (how an atlas grows) | — | **255** | **255** |
| `Map(WRITE_DISCARD)` on a DYNAMIC texture | — | **255** | — |

⚠ **The first run reported `A8_UNORM` BLACK, and that was MY BUG, not DXMT's.** The shader read
`.r`, but `A8_UNORM` legitimately samples as `(0,0,0,A)` — reading `.r` returns 0 on correct
hardware too. Caught before it was written up as a finding; the shader now takes `max(t.r, t.a)`.
**A single-channel format test that reads the wrong channel manufactures the exact bug it is looking
for.**

**So the glyph defect is not the texture path.** Creation, both single-channel formats, both
incremental upload routes, and sampling all behave correctly.

**What is now eliminated, cumulatively:** font enumeration (924 GDI / 204 DirectWrite families,
identical to the PK build that renders text — 2026-08-24) · texture format, upload and sampling
(this section) · presentation architecture (in-process GPU, out-of-process, CAContext remote layer)
· occlusion (per-child geometry mapped; more widgets appeared, still no text) · DirectComposition ·
`--use-angle=swiftshader`, `--disable-lcd-text`, `--disable-direct-write`, `--disable-gpu-*` (2026-08-24).

**The next probe, and it is a small one:** does **DirectWrite actually rasterise** on this stack?
Fonts *enumerate*, and `dwrite.so` carries all 56 `pFT_*` pointers — but nothing here has ever
checked that a glyph run produces non-empty coverage. `IDWriteFactory` →
`IDWriteGlyphRunAnalysis` → `CreateAlphaTexture` and sum the bytes: non-zero means rasterisation
works and the fault is further up in Skia; all-zero means the text never exists as pixels in the
first place, which would explain every observation in this whole thread at once.

## Text RASTERISATION eliminated — byte-identical to the build that renders text (2026-08-29)

> **Ledger: `RETRACTED` (C5).** Same defect as C6: `dwritetest` is a standalone PE and the byte-identical result is real but irrelevant — it never ran under the condition that fails. Measurement kept, elimination withdrawn.

`scripts/dwritetest.c` asks DirectWrite for the alpha texture of a real glyph run ("ABC", Arial,
32 px) and sums the bytes. Run on **both** engines on the same machine:

| | families | ALIASED_1x1 | CLEARTYPE_3x1 (natural) | CLEARTYPE_3x1 (gdi) |
|---|---|---|---|---|
| our stock 11.16 + DXMT (**no** Steam text) | 204 | 71×23, nonzero 545/1633, max 255, **sum 138975** | 315/4899, **sum 80325** | 315/4899, **sum 80325** |
| PK 11.0 vendor build (**renders** Steam text) | 204 | 71×23, nonzero 545/1633, max 255, **sum 138975** | 315/4899, **sum 80325** | 315/4899, **sum 80325** |

**Byte-identical.** Same bounds, same coverage, same sums, same font family count.

Two things fall out:

1. **Glyph rasterisation is not the defect.** DirectWrite produces real coverage on our engine —
   545 nonzero bytes at max 255 for three glyphs. The text exists as pixels before anything
   graphical happens to it.
2. ⚠ **The ClearType sparsity is normal, not a symptom.** 315/4899 nonzero looked suspiciously
   thin next to the aliased 545/1633 and was briefly a lead — until the *working* engine produced
   exactly the same number. **A ratio that looks wrong is not evidence without a reference.** The
   PK build is the reference this project has for "text works", and it should be run against any
   future text hypothesis before that hypothesis is believed.

**This is the strongest control available on this machine:** same hardware, same fonts, same
DirectWrite output down to the byte — and one engine shows Steam's text while the other does not.
So the difference lives entirely in what Chromium does with those glyphs afterwards, not in
producing them.

**Cumulative eliminations for the missing text — the list is now long and the survivors are few:**
font enumeration · **glyph rasterisation (this section)** · single-channel texture format, upload
(immutable, `UpdateSubresource`, `Map`/DISCARD) and sampling · presentation architecture
(in-process GPU, out-of-process, CAContext remote layer) · occlusion (per-child geometry) ·
DirectComposition · the 2026-08-24 flag matrix (`--use-angle=swiftshader`, `--disable-lcd-text`,
`--disable-direct-write`, `--disable-gpu-rasterization`, `--disable-gpu-compositing`, …).

**What survives:** something in how Chromium/Skia *uploads or composites* the glyph coverage it
already has — a path the PK vendor plumbing satisfies and ours does not. That is now a
Chromium/ANGLE-level question rather than a DXMT one, and the next probe should look at what ANGLE
does differently between the two engines rather than at anything font-shaped.

## The glyph defect localised: Chromium has NO working GL at all on this engine (2026-08-29)

> **Ledger: superseded by C10.** The same cells that could not load `libfreetype.dylib` also failed `libMoltenVK.dylib` and `winevulkan`. "No working GL" is likely one instance of *this process cannot dlopen any graphics library*, not a GL-specific fault.

Comparing `cef_log.txt` between our engine and the PK build that renders text gives the cleanest
signal in the whole text investigation.

| | our stock 11.16 + DXMT (**no text**) | PK 11.0 vendor build (**text works**) |
|---|---|---|
| `Initialization of all EGL display types failed` | **12** | **0** |
| `GLDisplayEGL::Initialize failed` | **12** | **0** |
| `eglInitialize SwANGLE failed` | **12** | **0** |
| GL/ANGLE errors of any kind | many | **none** (only network / ffmpeg / bad_message) |

**On our engine ANGLE never initialises at all.** The sequence is unambiguous:

```
WARNING: ANGLE Requires a minimum Vulkan instance version of 1.1
ERROR:   Internal Vulkan error (-9): The requested version of Vulkan is not supported by the driver
ERROR:   eglInitialize SwANGLE failed with error EGL_NOT_INITIALIZED
ERROR:   Initialization of all EGL display types failed.
ERROR:   GLDisplayEGL::Initialize failed.
```

⚠ **And it only ever tries Vulkan.** Display-type mentions in the log: `Vulkan` 84, `SwANGLE` 12,
**`D3D11` zero**. On this CEF build ANGLE's path is SwANGLE (software ANGLE over Vulkan), and it
needs a Vulkan **1.1** instance it cannot get — the same processes log
`err:vulkan:vulkan_init_once Failed to load libMoltenVK.dylib` **6×** per run.

**So Chromium is running with no GL whatsoever, on its software path** — which evidently blits
artwork fine and produces no text. ⚠ **SUPERSEDED 2026-08-30:** mikey92 has no GL either (CPU
raster, zero GPU process) and *does* get text, so "no GL" does not by itself explain the glyphs.
See § "mikey92's CPU-raster config does NOT reproduce here". That is the most economical explanation of every text
observation in this thread, and it predicts the fix: **get ANGLE initialised and the glyphs should
follow.**

**Two things tried against it, both no change:**
- **MoltenVK placement.** PK carries `libMoltenVK.dylib` in `wine/lib/` where ours only had it in
  `Contents/Frameworks/`, and `winevulkan` dlopens it by name. Copied it into `wine/lib/`
  (identical binary — both 8,096,560 B, `lipo -archs` = `x86_64`, so not an arch mismatch):
  **still 6 load failures**, still 12 EGL failures. Placement is not the problem.
- **`--use-angle=d3d11`** on the rendering baseline: renders (2,310,029 B), **still zero glyphs**.
  Forcing the backend does not help when the display never initialises.

**Next thread, and it is now specific rather than font-shaped:** why does
`libMoltenVK.dylib` fail to load *inside Steam's spawned child processes* when it loads fine for a
directly-launched wine program (the `dxgiprobe` runs print full MoltenVK banners)? That smells like
`DYLD_FALLBACK_LIBRARY_PATH` not surviving the steam.exe → webhelper spawn, and PK's wrapper doing
something different about it. Fix that, and ANGLE should come up.

⚠ **Do not read the cef_log counters as per-run** — that file accumulates across launches on a
prefix. The 12s above are consistent across runs but were not isolated per launch; the MoltenVK
count (6) is from the run's own stdout and is per-run.

## mikey92's CPU-raster config does NOT reproduce here — and the flag attribution is disproved (2026-08-30)

> **Ledger: `VOID`.** Evidence: `exp_4a9a98` — 14 FreeType, 7 gnutls, 4 MoltenVK failures. A client with no fonts, no TLS and no Vulkan cannot test someone else's render config.

mikey92 measured their own stack ([#141](https://github.com/3Shain/dxmt/issues/141)) and the result
is important: **their Steam client is carried by CPU raster, not D3D11.** Their `dxgiprobe` matches
ours exactly — vanilla PE gives `"NVIDIA GeForce 6800"`, `0x887A0004`, **FL 9_3**; the DXMT fork
gives `"Apple M4 Pro"`, `S_OK`, **FL 11_1** — and a `+loaddll` session shows **`d3d11.dll` loaded
zero times** across steam.exe and both webhelpers. With `--disable-gpu` Chromium skips the GPU
process and rasterises through Skia on the CPU; the split's only job there is to keep DXMT's guard
away from the steam processes, which otherwise restart-loop.

**They attributed our "no window, 174 % spin" row to a missing `-cef-single-process` on steam.exe**
(without it the browser forks a utility child for the network service → `net_error -100/-107`
cascade). **Tested. That is not what happens here.**

Ran their exact line — `steam.exe -no-cef-sandbox -cef-single-process -noverifyfiles`, shim
prepending `--disable-gpu --single-process` — on **stock DXMT v0.80** (verified guard-free:
0 occurrences of the `cross-process swapchain` string, so no restart loop) with a **stock**
`winemac.so` (0 public text symbols) and none of our patches active:

| | ours | mikey92 |
|---|---|---|
| flags on the real webhelper | `--disable-gpu --single-process` ✅ | same |
| `net_error` cascade | **0** | (their predicted cause) |
| `single process` notices | 6 | 58 |
| **`gpu_process_host` lines** | **36** | **0** |
| `gl_factory_win.cc` errors | **6,834,935** | — |
| window | **none**, after 10+ min | renders, with text |

**So the missing flag was not our cause.** With it supplied and verified, there is no net_error
cascade — and Chromium here *still* spins up gpu-process-host activity (36 lines vs their 0), never
reaches single-process cleanly (6 notices vs 58), and falls into the `gl_factory_win.cc(63)`
NOTREACHED loop at ~6.8 M occurrences with `wineserver` burning 53 % CPU.

**What that leaves as the real difference:** wine **11.0 vs 11.16**, macOS **26.5 vs 26.6.2**,
M4 Pro vs M3 Max. Not flag plumbing, and not the D3D path — both of us agree D3D11 is never used.

⚠ **And it kills the theory from the previous section.** "No GL → software path → no text" is
**wrong**: mikey92 has no GL either (CPU raster, zero GPU process) and gets **text**. So an absent
ANGLE does not by itself explain missing glyphs. The glyph question is reopened, and CPU raster is
now a *working* reference configuration that this machine cannot yet enter.

⚠ **Unverified claim, flagged rather than repeated:** that the CALayerHost route is 11.11+ only
(commit `1a63b0d7`, 2026-05-20, after the 11.10 tag). Our attempt to confirm it by `strings` on the
PK 11.0 `winemac.so` was **void** — the sanity control failed, `macdrv` itself counts 0 because
**PK's binaries are stripped** (already documented in § "The webhelper shim renders everything
EXCEPT text"). It is plausible and matters for the thread, but check it against wine git, not
against a stripped binary.

## ✅ CPU raster renders Steam WITH TEXT on an 11.0-lineage engine — the glyph story resolves (2026-08-30)

> **Ledger: `PARTIAL` (C7).** Evidence: `exp_fb79d9` (wine-stable 11.0) is **genuine** — shim installed, libraries resolve, text visible. `exp_8d065a` (PK 11.0) is **mislabeled**: that prefix has no shim, so `--shim-args` never applied and it was an ordinary launch, not CPU raster.

mikey92's configuration was run on a **clone of the PK 11.0 wrapper** (`cp -Rc`; the real store
wrapper untouched): `steam.exe -no-cef-sandbox -cef-single-process -noverifyfiles`, shim prepending
`--disable-gpu --single-process`.

**Result: a complete, fully-textual Steam client.** 1,897,587 B capture with the `Steam / View /
Friends / Games / Help` menu bar, `STORE / LIBRARY / COMMUNITY` nav, the full `Browse /
Recommendations / Categories / Hardware / Ways to Play / Special Sections` row, `Search the store`,
`Wishlist 7`, `Featured & Recommended`, game titles, `Overwhelmingly Positive (19,089 Reviews)`,
`Top Seller`, `$19.99`, `Discounts & Events`, `Add a Game`, `Manage Downloads`, `Friends & Chat`.
⚠ **Screenshot deliberately NOT committed** — the account name is visible and this repo is meant to
be publishable (see CLAUDE.md § Personal info). Described here instead.

**⚠ This CORRECTS a standing claim in § "The webhelper shim renders everything EXCEPT text".** That
section says PK *"loses text the same way the moment the shim is added"*. That is true **only for
`--in-process-gpu`**, which is the shim's compiled default. With the shim installed and
`--disable-gpu --single-process` injected instead, **PK keeps all its text.** The shim is not the
text killer; **in-process GPU is.**

**So the whole glyph picture finally resolves into three consistent rows:**

| GPU mode | art | text | notes |
|---|---|---|---|
| in-process GPU (`--in-process-gpu` / `--single-process` alone) | renders | **none** | both engines — the long-standing glyph bug |
| **no GPU at all** (`--disable-gpu --single-process`, CPU raster) | renders | **YES** | PK 11.0-lineage — *this run* |
| out-of-process GPU | black (11.16) / fine (PK) | — | the cross-process swapchain thread |

**And it relocates our remaining defect precisely.** CPU raster is a *known-good, text-complete*
configuration. Our 11.16 engine cannot enter it — the identical flag set there produces **no window
at all**, with `gl_factory_win.cc(63)` NOTREACHED at ~6.8 M occurrences, 36 `gpu_process_host` lines
where mikey92 gets 0, and 6 `single process` notices where they get 58. So the target is no longer
"why are glyphs missing" but **"why can wine 11.16 not run Chromium's GPU-less single-process
path when 11.0 can"** — a regression between the two, on the GL-probe path Chromium takes before
deciding it needs no GPU.

**Verified while checking mikey92's other claim** (against wine git, not a stripped binary):
`macdrv_client_surface_acquire_metal_swapchain` / `WM_MACDRV_CREATE_REMOTE_LAYER` are **absent in
`wine-11.0` and `wine-11.10`, present in `wine-11.11`** (1 and 3 occurrences). Their "11.11+ only"
statement is **correct**, which means the cross-process CHILD patch cannot apply to the many
black-window reports on `wine-stable` 11.0 without moving engines.

## No wine-version bisect is warranted — and mikey92's setup relocates the variable to macOS (2026-08-30)

> **Ledger: `RETRACTED`.** Superseded twice — first by the wine-stable result, then by the 2026-08-30 audit which showed the comparison itself was confounded. Draw nothing from this.

Asked "was it 11.4 or 11.11?", the honest answer is **neither: there is no version boundary between
11.0 and 11.16 on this machine.** A controlled sweep on 2026-08-24 already measured it —
§ "Embedded Chromium NEVER rendered on stock Wine here":

| cell | result |
|---|---|
| **stock 11.0 / 11.15 / 11.16**, identical configure, fresh-prefix gate | **all BLANK, byte-identical captures** |
| PK 11.0 (vendor), same gate | RENDERED, repeatedly |

**Stock 11.0 fails here exactly as stock 11.16 does.** So bisecting 11.0 → 11.16 would land on no
commit; the axis was never the version, it is **stock vs the PK vendor patchset** (a Gcenx build
from a private tree carrying CrossOver-lineage `CX_LIBVULKAN` code in win32u, the msync patchset,
and Proton-lineage writecopy). ⚠ Individual module transplants were already tried and failed —
stock 11.0 + PK's `win32u`/`winemac`/`user32`/`gdi32` was still blank, and PK core transplants
crash, because the vendor modules interlock.

**What mikey92's report changes, and it is the useful part.** They run **stock Homebrew
`wine-stable` 11.0** — not a vendor build — and Steam renders *with text* under CPU raster. Ours is
a stock build too, and fails. Same engine lineage, opposite outcome. **So the remaining variable is
not wine at all: it is macOS 26.5 (theirs) vs 26.6.2 (ours)**, or M4 Pro vs M3 Max.
⚠ **WRONG — SUPERSEDED 2026-08-30.** wine-stable 11.0 was installed and runs their config on THIS
machine, macOS 26.6.2, rendering Steam with full text. The OS is exonerated; the variable is the
engine. See § "CORRECTION: macOS is NOT the variable".

That also fits the one error we cannot shake: `ANGLE Requires a minimum Vulkan instance version of
1.1` → `Internal Vulkan error (-9)`. Per the 08-24 A/B that warning is **present on stock 11.16 and
absent on PK 11.0** — it tracks the Vulkan stack, and PK's differentiator is precisely
CrossOver-lineage Vulkan code.

⚠ **Also eliminated today:** forcing Chromium's own bundled software Vulkan with
`WINEDLLOVERRIDES="vulkan-1=n,b"` (its `vk_swiftshader.dll` 5,307,032 B + `vk_swiftshader_icd.json`
are both present in the CEF directory) under the CPU-raster flags — **no change**: 10 EGL
all-failed, 10 "minimum Vulkan instance" warnings, 6,222,856 `gl_factory_win` errors, no window.
The override does not divert ANGLE off wine's Vulkan.

**The one cheap experiment that would settle it:** install Homebrew `wine-stable` — mikey92's exact
engine — on this machine and run the CPU-raster config. Stock-vs-stock, same client, same flags,
only the OS and hardware differing. If it fails here, macOS 26.6.2 is confirmed as the variable and
wine is fully exonerated; if it works, our own 11.16 build configuration is implicated rather than
the version.

## ⚠ CORRECTION: macOS is NOT the variable — wine-stable 11.0 renders Steam WITH TEXT here (2026-08-30)

> **Ledger: `RETRACTED` (C8).** Evidence: `exp_fb79d9` vs `exp_53a8e6`/`exp_7b9920`. Not a controlled comparison — one side had the shim and a working font backend, the other had neither. Retracted the same day it was written.

The previous section concluded *"the remaining variable is not wine at all: it is macOS 26.5 vs
26.6.2"*. **That is wrong, and this supersedes it.** Homebrew `wine-stable` (**wine-11.0**, the exact
engine mikey92 runs) was installed and given their exact configuration on **this** machine —
macOS 26.6.2, M3 Max:

```
steam.exe -no-cef-sandbox -cef-single-process -noverifyfiles
shim injecting --disable-gpu --single-process
```

**Result: a complete, fully-textual Steam client. 665,949 B.** Menu bar (`Steam / View / Friends /
Games / Help`), `STORE / LIBRARY / COMMUNITY`, the `Browse / Recommendations / Categories / More`
row, `Search the store`, `Wishlist 7`, `Featured & Recommended`, game title, `Overwhelmingly
Positive (200,124 Reviews)`, `Recommended because you played games tagged with`, the tag chips,
`$19.99`, `Add a Game`, `Manage Downloads`, `Friends & Chat`.
⚠ **Screenshot NOT committed** — the account name is visible (CLAUDE.md § Personal info).

**Same machine, same OS, same Steam install, same flags — the ONLY difference is the engine:**

| engine | result |
|---|---|
| our self-built stock **11.16** + DXMT | **no window at all**; `gl_factory_win.cc` NOTREACHED ~6.8 M, 36 `gpu_process_host` lines, 6 single-process notices |
| Homebrew **wine-stable 11.0** | **renders, with full text** |

**So the OS is exonerated and a bisect IS warranted after all** — for *this specific configuration*.
That does not contradict the 2026-08-24 three-version sweep, which is why the earlier reasoning went
wrong: that sweep found stock 11.0 / 11.15 / 11.16 all blank **under DEFAULT flags** (out-of-process
CEF). It says nothing about the CPU-raster path, which nobody had run on 11.0 here until now.
**Two different configurations, two different answers — do not generalise one sweep across both.**

**Two candidates, both testable:** (a) a wine regression between 11.0 and 11.16 on the GL-probe path
Chromium takes before deciding it needs no GPU; or (b) our own build configuration differing from
WineHQ's stable build (we configure with a specific `--without-*` set). (b) is the cheaper to check
first — build 11.0 from source with our flags and see which side it lands on.

**Practical consequence, and it is a real one:** there is now a WORKING Steam client path on this
machine that needs no two-wrapper split — `wine-stable` 11.0 + the padded webhelper shim +
`--disable-gpu --single-process`. It is CPU raster, so it will be slower than a GPU-composited
client, but it renders text, which the daily 11.16 engine has never done.

**Method note worth keeping:** wine-stable ships only `wine` (no separate `wine64`), and the
Gatekeeper approval is **per path** — copying the wine tree to a new location re-quarantines it and
`syspolicyd` blocks with no visible prompt (this cost ~7 min of apparent hang). Run the approved
binary IN PLACE and build a wrapper-shaped shell of symlinks around it, with a `wine64 -> wine`
alias for harnesses that expect the old name.
