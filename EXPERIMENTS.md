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

### ❌ FALSIFIED: the GPU crash is not the VPN (2026-08-30)

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

**Run 2026-08-30 evening**, James switching off the flaky Proton tunnel and staying on a home VPN
that has never misbehaved:

| arm | tunnel | GPU crashes | window |
|---|---|---|---|
| baseline | Proton, `utun4 10.2.0.2` | **6** | black, **108,343 B** |
| comparison | home VPN, `utun4 10.10.99.3` | **6** | black, **108,343 B — byte-identical** |

**Identical.** Two different tunnels, same crash count, same capture to the byte. The flaky VPN is
**not** what crashes the GPU process, and by extension is not what produced the black window this
week. The evidence-against recorded when this was raised — exactly 6 crashes in every configuration
all day — held up.

⚠ **What this does NOT close, stated precisely:** *both* arms still had a `utun` interface present.
So "Proton specifically" is eliminated; "wine's IPHLPAPI chokes on **any** tunnel interface" is
**not**. Closing that needs an arm with every VPN disconnected, which has not been run. The
`GetAdaptersAddresses failed: 2` and `Failed to read DnsConfig` errors are still there in both.

**The bias the hypothesis came from stands regardless, and is the durable part:** a timeout is
ambiguous evidence, and this project had been resolving it toward "the thing under test is broken."
Network state is now recorded in every cell's `config.json` and a down network is a fatal
precondition, so the next time it matters the answer will be in the artifact rather than in
somebody's memory of what the tunnel was doing.

⚠ **Evidence AGAINST, stated so this is not adopted on plausibility alone:** the crash count has
been **exactly 6** in every cell today — default backend, software rendering, forced D3D11, builtin
CRT, patched DXMT. If it were driven by a flapping tunnel we would expect variation across a day in
which the tunnel was admittedly unreliable. That is a real argument that the cause is deterministic
and internal, not environmental. The A/B settles it either way and costs one cell.

**Only 6 of 16 fingerprinted cells record network state at all** — the ones after that field was
added. Every earlier cell in this investigation is silent on it, which is precisely the gap this
ledger exists to close, reopened one level up.

### ⚠ RESIZE IS NOT FIXED — two distinct defects, one diagnosed (2026-08-31)

James re-tested the bounds-tracking build. **Resize is still broken**, and his screenshots separate
two different faults that had been read as one.

**The mechanism itself works.** 2,074 geometry updates fired during the session with real changing
sizes (`2948x1113`, `2952x929`, `3036x935` …), so the update hook tracks the child correctly now.
302 acquires / 288 releases / 287 drains under heavy resizing.

**Defect 1 — hairline light line at an edge. DIAGNOSED, arithmetic:**

| window (Win32 px) | → points | |
|---|---|---|
| 1010×600 | 505.0 × 300.0 | exact |
| **1441×669** | **720.5 × 334.5** | **fractional** |
| **2019×1199** | **1009.5 × 599.5** | **fractional** |

`cgrect_mac_from_win` halves for retina, so **any odd pixel dimension lands on a half-point** and the
layer falls a half-point short of its frame — a hairline of whatever is behind it. Candidate fix:
`CGRectIntegral`, or round the size up rather than truncating. Not yet applied or tested.

**Defect 2 — content still goes fully black on some resizes. NOT diagnosed.** Defer-by-one is not
enough at 302 acquires: CEF destroys and recreates swapchains faster than a one-deep hold covers, so
there are still moments with nothing hosted. A deeper fix would hold the retired surface until the
*replacement* is confirmed hosted, rather than until the next release arrives — that is a different
and more invasive design than what is in place.

**Status: resize is an open defect, not a solved one.** The steady state is correct — a window that
is not being resized renders completely and correctly. Say exactly that anywhere this is described.

### 🔧 LEAK FIXED, then RESIZE regression found and mitigated (2026-08-31)

**The leak.** `my_dxmt_acquire_remote_layer` kept every client surface forever, because retiring the
previous one on acquire destroyed the layer DXMT was still rendering into. Root cause of the design:
the table was keyed by **HWND**, and DXMT re-acquires the same HWND repeatedly — measured **16
distinct windows, 4 acquires each**, so an hwnd-keyed table can only ever hold the newest.

**Fix:** key by the **view** instead, and add an exported `dxmt_release_remote_layer(view)` that
returns TRUE if the view was one of ours. DXMT calls it first in `_ReleaseMetalView` and falls
through to the ordinary metal-view release otherwise — **no tagging or bookkeeping on the DXMT
side**, and on an unpatched winemac the symbol is simply absent. Measured: **157 acquires, 142
release HITs, 0 MISSes**, still rendering, 0 crashes.

⚠ **This introduced a regression, found by James in live use, not by the harness:** *"flickers on
resize and with some resize I was able to black out the child windows."* The cause is structural:
`ResizeBuffers` never touches the view — CEF resizes by **destroying a swapchain and creating a new
one**, so a prompt release un-hosts the old layer before the new one exists. The old leak had been
accidentally masking this by never releasing at all.

**Mitigation: deferred by one.** Hold exactly one retired surface until the next release arrives,
then drain it. Something stays hosted across the destroy/create gap, and the cost is bounded at a
single surface rather than one per acquire. Measured: **130 acquires, 115 deferred releases, 114
drained**, still rendering, 0 crashes.

⚠ **NOT YET CONFIRMED against the actual symptom.** Resize is interactive and the harness cannot
drive it; the numbers above only show the mechanism behaves. Whether the flicker and the blackout are
gone needs a human resizing the window. **Do not record this as fixed until that happens.**

### ❓ Can the wine patch be avoided? No — and here is exactly why (2026-08-31)

Measured against the **stock shipped** `winemac.so`, not reasoned about:

| function | present in stock? | exported? |
|---|---|---|
| `macdrv_CreateClientSurface` | yes | **no** |
| `macdrv_client_surface_acquire_metal_swapchain` | yes | **no** |
| `macdrv_swapchain_get_layer` | yes | **no** |
| `macdrv_create_offscreen_swapchain` | yes | **no** |

**Stock winemac exports ZERO text symbols** (`nm -g … | grep -c ' T '` = **0**; the
`-fvisibility=default` build has **215**). The only thing DXMT can reach is `macdrv_functions`, a
`DECLSPEC_EXPORT`ed *data* symbol — ten function pointers, **none of them a cross-process route**.

**Two independent blockers, and visibility only removes the first:**

1. **Visibility.** Everything needed is compiled in but hidden. `dlsym` finds nothing.
2. **The FIXME.** Even fully exported, `macdrv_client_surface_acquire_metal_swapchain` **returns
   FALSE for a child window** — stock carries the string *"Cross-process child window Metal
   swapchains are not implemented"* and none of our CHILD branch. CEF's HWND **is** a child, so a
   visibility-only rebuild still fails.

**Could DXMT pass the ROOT instead, to take the non-child path?** Possibly — that path is genuinely
cross-process (it is what `vulkan.c` uses). But the hosted layer would then cover the whole root with
no child geometry, so sibling widgets would occlude one another — the exact failure
`addCALayerHostViewWithContextId:` documents (*"only the topmost was ever visible … measured: black"*).
Degraded, not a substitute.

**And the part that is unavoidable in principle:** the hosting happens in the **owner** process, via
`WM_MACDRV_CREATE_REMOTE_LAYER` and `CALayerHost`. Only wine has that cross-process plumbing. DXMT
cannot replicate it from outside its own process, whatever is exported.

**So the honest framing is not "avoid the wine patch" but "upstream it".** That is more tractable
than it sounds:

- The child case is **wine's own acknowledged gap** — it ships the FIXME describing it.
- The pixels→points bug is a **plain unit error** in wine's code, independent of DXMT.
- The visibility change is a **build flag**, already what notpop does.

**Meanwhile there is a working path today with no wine patch at all:** the webhelper shim with
`--in-process-gpu`. Full client, with text, since the font fix. Its only known cost is store-tab
flicker. So users are not blocked while the wine side goes upstream.

### 🏁 GEOMETRY CLOSED — Steam renders COMPLETELY out-of-process (2026-08-31)

**The black band is gone.** Steam's client renders correctly and completely on stock out-of-process
CEF: chrome, nav, URL bar, search, Featured & Recommended, review counts, price, bottom bar. No
shim, no injected switches, **0 GPU crashes**. Proof:
[`docs/images/steam-crossprocess-complete.png`](docs/images/steam-crossprocess-complete.png).

**Two fixes, and the second was the one that mattered:**

1. **Root-relative creation geometry** (`window.c`). The CHILD branch passed
   `NtUserGetClientRect(hwnd)` = `(0,0,w,h)`, so every hosted layer landed at the root's origin.
   Now computed as `NtUserGetWindowRect(child)` offset by the root — matching what the *update*
   path already did, so creation and later moves agree. **This alone did not fix the band**, because
   the children genuinely sit at the root origin: the logged frames were `(0,0)-(w,h)` either way.
2. **Win32 pixels → Cocoa points** (`cocoa_window.m`). `CALayer.frame` is in **points**; the frames
   arriving were **raw Win32 pixels**. Measured: window **1010×600 points**, frame **2020×1200** —
   exactly 2× on this retina display. Every hosted layer was double size with its content pushed
   down and right, which *is* the black band. Wrapped both Cocoa entry points in the driver's own
   `cgrect_mac_from_win()`.

**How it was found, and it is the method rather than the insight:** log what the mechanism actually
sets, not what it ought to set. The line

```
dxmt-geom: ctx N child 0x10140 frame (1,184) 2018x915  root 2020x1200
```

against a window the harness independently reported as `size=1010x600` made the 2× immediate. No
amount of reading `addCALayerHostViewWithContextId:` would have shown it, because the code is
correct — it is the units of its input that were wrong.

**Patches:** `scripts/winemac-crossprocess-remote-layer.patch` (wine, three files) +
`scripts/dxmt-remote-layer-fallback.patch` (DXMT). Neither half works alone.

~~⚠ **Still open:** `my_dxmt_acquire_remote_layer` deliberately leaks the previous client surface.~~
**Closed 2026-08-31** — view-keyed table + `dxmt_release_remote_layer`, lifetime driven by DXMT's
own release — and **hardened 2026-09-02**: a destroyed child's held surface is drained instead of
parked forever, dead children are pruned owner-side, root-keyed layers are tracked so the release
guard cannot skip them, and a child that dies between post and handler is not hosted. The 2026-09-02
audit also found the *published* patch files had never carried the release mechanism; both were
regenerated from the working trees (the prose version is preserved at
`docs/winemac-crossprocess-remote-layer-history.md`).

### 🏆 IT RENDERS OUT-OF-PROCESS, NO SHIM — the cross-process path works (2026-08-31)

**Steam's client renders on stock out-of-process CEF, with text, with no shim and no injected
switches.** `exp` = `remote-confirmed`: **2,136,894 B**, **0 GPU crashes** (was 6, every launch, for
the whole investigation). Proof: [`docs/images/steam-renders-crossprocess.png`](docs/images/steam-renders-crossprocess.png).

**Fully attributed, with both markers firing 56 times each:**

```
err:macdrv:my_dxmt_acquire_remote_layer  remote layer acquired for hwnd 0x10104 (swapchain ...)
err:macdrv:...                           cross-process CHILD hwnd -> hosting remote layer on root
```

**The mechanism, end to end:**

1. DXMT's `get_win_data()` returns NULL for CEF's child window (process-local `win_datas`).
2. **New:** DXMT falls back to `dxmt_acquire_remote_layer()` instead of dereferencing NULL.
3. That calls `macdrv_client_surface_acquire_metal_swapchain()`, which takes the **CHILD** branch and
   builds `macdrv_create_offscreen_swapchain(root, hwnd, rect)`.
4. A `CAContext` layer is hosted in the **owning** process via `CALayerHost`.
5. DXMT presents to that layer through its existing `Presenter` — unchanged.

**Isolation, run rather than assumed:** stock DXMT + patched winemac → **6 crashes, black**. So the
DXMT-side change is required; the wine side alone is not enough. Both halves are needed.

**Design note worth keeping:** the entry is reached by **`dlsym("dxmt_acquire_remote_layer")`**, not
by a new `macdrv_functions_t` member. That struct is `C_ASSERT`-ed at a fixed size, so extending it
is a breaking ABI change — a DXMT built against an 11-member struct would read past the end of a
10-member one and call whatever followed it. A standalone symbol resolves to NULL on any unpatched
winemac and the code falls through unchanged. This is what makes the DXMT half safe to offer
upstream on its own.

⚠ **Not finished:** a **black band across the upper content area** — the unmapped-geometry gap the
CHILD patch documents. The hosted `CALayerHost` fills the root's content view rather than tracking
the child's rect; `macdrv_window_update_ca_layer_host_frame` exists for the general case and is not
wired. Also unaddressed: the deliberate surface leak in `my_dxmt_acquire_remote_layer` (releasing the
previous surface kills the live layer — see its comment).

⚠ **Instrument artifact that nearly buried this.** The first run of this exact configuration
reported **0 firings** for both markers while rendering perfectly. Cause: the harness set
`WINEDEBUG=-all`, which suppresses the **`err`** channel — where all of wine's own diagnostics live.
The path had fired all along. Harness default changed to `+err`. **A counter reading zero is not
evidence when the channel it counts is switched off.**

**Patches:** `scripts/dxmt-remote-layer-fallback.patch` (DXMT) and the exported wrapper in
wine's `macdrv_main.c`.

### ✅ RE-SCOPED (source read): it is ~50 lines, NOT a subsystem (2026-08-31)

Read the wine and DXMT sources instead of estimating. **The hard part does not exist — both halves
are already implemented and simply not connected.**

**1. Wine already produces a layer from the remote path.** `macdrv_cocoa.h`:

```c
macdrv_metal_swapchain macdrv_create_offscreen_swapchain(void* hwnd, void* child, CGRect bounds);
macdrv_metal_layer     macdrv_swapchain_get_layer(macdrv_metal_swapchain swapchain);
void                   macdrv_destroy_swapchain(macdrv_metal_swapchain swapchain);
```

`macdrv_create_offscreen_swapchain` is `[[CAContextSwapChain alloc] initWithHwnd:child:bounds:]` —
it **already takes a `child` argument**, and `window.c:1195` already calls it as
`(root, hwnd, rect)`. `macdrv_swapchain_get_layer` returns a **`macdrv_metal_layer`** — the exact
type DXMT consumes.

**2. DXMT only needs a layer.** `native_view_` appears in exactly three places in
`d3d11_swapchain.cpp`: assigned (134), null-checked → `abort()` (136), released (209). **It is never
used for rendering.** Everything real goes through `layer_weak_`:

```
145   Presenter(pDevice->GetMTLDevice(), layer_weak_, ...)
1052  MetalLayer_getEDRValue(layer_weak_, ...)
```

So the view is a *lifetime handle*, nothing more — and the remote path can supply an equivalent one
(the swapchain object itself).

**The whole change, measured:**

| where | work | size |
|---|---|---|
| wine `macdrv_functions_t` | 3 new entries: `create_offscreen_swapchain`, `swapchain_get_layer`, `destroy_swapchain`. Implementations **already exist** | ~10 lines |
| DXMT `_CreateMetalViewFromHWND` | on NULL `win_data`: create offscreen swapchain against the root, take its layer, return both | ~20 lines |
| DXMT release path | route `ReleaseMetalView` to `destroy_swapchain` for that case (tagged handle or flag) | ~10 lines |

**≈40–50 lines across two repos, and no new mechanism.** The earlier "largest single piece of work
the project has faced" estimate was wrong, and wrong in the expensive direction — it was made from
the ABI surface alone, without reading either implementation. **Estimate from the source, not from
the interface.**

⚠ Known gap to carry into the build: **geometry is not mapped.** The hosted `CALayerHost` fills the
root's content view, which is approximately right only while the child covers the client area (CEF's
main widget does). `macdrv_window_update_ca_layer_host_frame` exists for the general case.

### 📐 SCOPED: wiring DXMT to the remote-layer path is new engineering, not a call (2026-08-31)

Asked whether DXMT can simply call wine's cross-process route. **It cannot — the entry point is not
in the ABI.** `struct macdrv_functions_t` is `C_ASSERT`-ed at **size 80**, ten pointers, and this is
everything DXMT can reach:

```
macdrv_init_display_devices  get_win_data                 release_win_data
macdrv_get_cocoa_window      macdrv_create_metal_device    macdrv_release_metal_device
macdrv_view_create_metal_view  macdrv_view_get_metal_layer macdrv_view_release_metal_view
on_main_thread
```

`macdrv_client_surface_acquire_metal_swapchain` is **not** in it. It is wine's internal
client-surface API, driven by winemac itself; the `client_surface` is created inside
`my_get_win_data` and owned by `data->dxmt_client_surfaces`. DXMT never sees one.

⚠ **Correcting yesterday's reasoning.** I wrote that mapping child → root "cannot work because the
root has no `win_data` either". That is a **Route A** fact (`get_win_data` → `macdrv_view_create_metal_view`,
which needs a local `win_data`) applied to a **Route B** mechanism
(`macdrv_client_surface_acquire_metal_swapchain`, which posts `WM_MACDRV_CREATE_REMOTE_LAYER` to the
window's *owning process* and needs no local `win_data` at all). The child→root idea is **not** dead
on that evidence. What is true is narrower: **DXMT never calls Route B**, so our CHILD patch is
unreachable from DXMT — which is exactly why its counter fired zero times.

**No newer DXMT to upgrade to:** upstream `main` (`19e24ee`) still calls `CreateMetalViewFromHWND`
and contains **zero** client-surface code; `v0.80` is the newest tag.

**What building it actually requires — three pieces, in order:**

| # | where | work |
|---|---|---|
| 1 | wine | add an entry to `macdrv_functions_t` (the 80 → 88 change) exposing a remote-layer acquisition |
| 2 | wine | implement it over the existing `macdrv_create_offscreen_swapchain` + `WM_MACDRV_CREATE_REMOTE_LAYER` + `CALayerHost` machinery — the CHILD patch already does part of this |
| 3 | DXMT | call it when `get_win_data` returns NULL, and make `Presenter` accept what it returns |

**Piece 3 is the risk and it is worth measuring before starting.** DXMT's `Presenter` is built around
`layer_weak_`, a `macdrv_metal_layer`. Wine's cross-process branch produces a **swapchain object**,
not a layer. If the remote path can be made to yield a `CAMetalLayer`, `Presenter` may need almost
no change; if it cannot, this becomes a second presentation backend inside DXMT. **That question —
"can the remote path yield a CAMetalLayer?" — is the cheapest next thing to answer, and it is a
source read, not a run.**

This is the largest single piece of work the project has faced, and it is upstream-shaped: it is
what DXMT would have to do to support cross-process presentation at all.

### 🧩 DIAGNOSED: it is a CHILD window whose ROOT is also unknown to winemac (2026-08-31)

Instrumented the NULL branch to ask what the window actually is. Six firings, two distinct windows,
identical shape:

```
dxmt-diag: get_win_data(0x10104) NULL  parent=0x200f0  root=0x500e6  root_win_data=null
dxmt-diag: get_win_data(0x500f0) NULL  parent=0x400e8  root=0x70110  root_win_data=null
```

Three facts, and the third kills a plan:

1. **It is a child window** — it has a parent, and a root distinct from itself.
2. **The d3d11 cross-process guard did not fire**, so `GetWindowThreadProcessId()` says the *child*
   belongs to this process. It is not foreign by the Win32 test.
3. **The ROOT has no `win_data` either.** So **mapping child → root cannot work** — which is exactly
   what our `winemac-crossprocess-child.patch` does. That approach is dead on this evidence.

**The coherent reading:** the child is owned by the GPU process, its *root* lives in the browser
process, and winemac cannot realize a child whose parent chain leaves the process — so neither the
child nor the root ever gets a `win_data`. That is precisely the case winemac names in its own
`FIXME`: *"Cross-process child window Metal swapchains are not implemented"*. The Win32 process
check and the winemac realization check disagree, and DXMT trusts the first.

**Why every fix so far stopped here:**

| attempt | why it could not work |
|---|---|
| null-check `get_win_data` | the caller `abort()`s on a null view **by design** (`d3d11_swapchain.cpp`, *"your Wine has no exported symbols needed by DXMT"* — a misleading message; the symbols are fine) |
| notpop's fork | rewrites the same function; still needs a `win_data` that does not exist |
| map child → root (our CHILD patch) | **the root has no `win_data` either** |
| force the cross-process guard open | the guard was never the thing stopping it — it does not fire for this window |

**The next test follows from this and nothing else:** stop trying to obtain a `macdrv_view` for a
window this process does not own, and use wine's **existing remote-layer path** instead —
`macdrv_client_surface_acquire_metal_swapchain` / the `WM_MACDRV_CREATE_REMOTE_LAYER` +
`CAContext` machinery already present in our patched winemac (`my_dxmt_acquire_remote_layer`).
That mechanism exists precisely for compositing another process's surface, and DXMT simply never
calls it. Wiring it is a DXMT-side change, and the winemac half is already built.

### ✅ WALL 1 DOWN: null-checking `get_win_data` moves the crash (2026-08-31)

Patched `_CreateMetalViewFromHWND` in DXMT **v0.80** (the shipped lineage) to check what
`get_win_data()` returns before dereferencing it — `scripts/dxmt-nullcheck-win-data.patch`, six
lines. Built against the shipped engine, installed, **winemac left stock** so the only variable is
the null check.

```
a339   callq *%r15            ; get_win_data(hwnd)
a33c   testq %rax, %rax       ; <== THE FIX
a344   movq 0x18(%rax), %rdi  ; only reached when non-NULL
```

| | before | after |
|---|---|---|
| AV address | `0x2179833df` = `winemetal.so` `_CreateMetalViewFromHWND +0xbf` | **`0x2086a91f9`** = `ntdll.so +0x301f9` |
| enclosing | the unchecked deref | **`__wine_unix_call_dispatcher +0xc9`** |
| GPU crashes | 6 | 6 |
| window | black | black |

**The first wall is genuinely down** — that specific dereference no longer happens — and the crash
**moved to the next one**. No user-visible change yet.

**The convergence is the real result.** `__wine_unix_call_dispatcher +0xc9` is *exactly* where
notpop's fork crashed too. Two independent fixes to the same bug — their rewrite and our six-line
null check — land on the identical next failure. So:

- **That dispatcher crash is not a fork artifact and not a build mismatch.** It is simply *the next
  wall*, reached by anyone who stops crashing in `_CreateMetalViewFromHWND`. My ABI-mismatch theory
  for it is now doubly dead: the ABI-matched rebuild did not move it, and an unrelated fix reproduces
  it exactly.
- **It also retro-explains the fork result.** "notpop's fork does not fix the Steam client" is true,
  but the reason is now specific: the fork fixes wall 1 and stops at wall 2, the same as we do.

**Next:** identify what unix call is being dispatched with a null handle at
`__wine_unix_call_dispatcher +0xc9`. Reproducible from two directions now, which makes it a much
better target than it was an hour ago.

### 🔗 CLOSED LOOP: the GPU crash IS the cross-process problem, as a null deref (2026-08-31)

The four function pointers the crash depends on are resolved **by name**, and the strings are in the
binary:

| loaded into | symbol |
|---|---|
| — | `macdrv_functions` (struct lookup, tried first) |
| `%r15` | **`get_win_data`** |
| `%r14` | `release_win_data` |
| `%r13` | `macdrv_view_create_metal_view` |
| `%r12` | `macdrv_view_get_metal_layer` |

```
a3b3..a3d4   testq %r15/%r14/%r13/%r12  -> all four POINTERS null-checked, ANDed
a3d6         movq (%rbx), %rdi          ; the HWND
a3d9         callq *%r15                ; get_win_data(hwnd)
a3dc         movq %rax, %r15            ; keep the win_data
a3df         movq 0x18(%rax), %rdi      ; <== deref win_data->+0x18, UNCHECKED
```

**`get_win_data(hwnd)` returns NULL for a foreign HWND — that is exactly C3**, which we derived from
wine's source: `win_datas` is a process-local `CFDictionary`, so another process's window is invisible
by construction. DXMT carefully null-checks all four *function pointers* and then does not check the
*return value* of the first call.

**So the chain is closed end to end:**

1. Steam's CEF **GPU process** asks DXMT for a Metal view for the **browser process's** HWND.
2. DXMT calls `get_win_data(hwnd)`.
3. It returns NULL — foreign HWND, process-local table (C3).
4. DXMT dereferences at `+0x18` with no check → AV → `abort()` → `__fastfail(7)`.
5. Chromium restarts the GPU process, it dies the same way, 6× → gives up → **black window**.

**This unifies the whole investigation.** The GPU crash is not a separate mystery upstream of the
cross-process work — **it IS the cross-process problem**, surfacing as a null dereference instead of
the graceful `E_FAIL` we kept looking for. The `cross-process swapchain not supported` guard in
`d3d11_swapchain.cpp` is a *later* checkpoint that is never reached, because this earlier path
crashes first. That is also why forcing that guard open changed nothing.

**The next test is now cheap:** add a null check on `get_win_data`'s return in DXMT and rebuild.
If the GPU process survives instead of aborting, we find out what the *next* wall is — and we get a
one-line upstream patch either way. Everything needed is already in place: the source tree, a working
build against the shipped engine, and a harness that measures it.

### ❌ notpop's fork does NOT fix the Steam client — re-tested properly (2026-08-31)

Rebuilt the fork **against the shipped engine** (`-Dwine_install_path=…/CS2dxmt11.app/…/wine`,
153/153, exit 0), installed it with the `-fvisibility=default` `winemac.so`, fonts working.
**Unchanged: 6 GPU crashes, black window.**

| | stock | fork (ABI-matched) |
|---|---|---|
| GPU crashes / launch | 6 | **6** |
| window | black | **black** |
| `movq 0x18(%rax)` in the rewritten function | present — the crash | **absent** |

So the fork removes the specific unchecked deref at `_CreateMetalViewFromHWND +0xbf` and the client
still does not render. **The original `PARTIAL` conclusion ("the fork does not fix the Steam client")
is now upheld on sound evidence** — fonts working, ABI matched, crash count unchanged.

⚠ **My ABI-mismatch explanation for the previous run was WRONG, and the rebuild is what proved it.**
The reasoning was that the fork's artifacts were built against `engine-1116` and the null in
`__wine_unix_call_dispatcher` was a registration failure. Rebuilding against the shipped engine
changed the **PE side only** — `winemetal.so` came out **byte-identical** (`cmp`), because
`wine_install_path` selects `winecrt0`, which is linked into the DLLs and not into the unix `.so`.
The outcome did not move. So the dispatcher AV is **not** a build mismatch and remains unexplained;
`winemetal.so` loads fine standalone and `winemetal.dll` is present in the process.

**What this restores:** the earlier "cross-process path is unreachable" result (`xproc-v080`) was
flagged as suspect on the same wrong ABI reasoning. That flag is withdrawn — the mechanism it
invoked does not exist. The result stands on its own terms again, though it has not been
independently re-run.

### ⚠ Superseded: the ABI-mismatch reading of the first fork re-test (2026-08-30)

Re-ran notpop's fork with fonts working, to retest the `PARTIAL` "the fork does not fix the Steam
client" conclusion. **The run is void and must not be cited either way.**

Installed the fork's `d3d11`/`dxgi`/`winemetal.dll`/`winemetal.so` plus the `-fvisibility=default`
`winemac.so`. Result: still 6 crashes, still black — but the fault **moved**, from
`winemetal.so +0xa3df` to `ntdll.so +0x301f9`, which `nm` places in
**`__wine_unix_call_dispatcher +0xc9`**, dereferencing address **0** with `rbx=0`.

**That is a NULL unix-call table, i.e. a `.so` that failed to register — not a crash in fork logic.**
The cause is mine: `build-dxmt-fork.sh` builds against
`~/cs2-patch/build-1116/engine-1116` (2026-08-28), and I installed the output into the *shipped*
engine (2026-08-23). Their `ntdll.so` are different builds (`cmp` says so), so the PE↔unix ABI does
not match and registration fails.

**To run it properly:** either install the fork into a wrapper actually running `engine-1116`, or
rebuild the fork with `-Dwine_install_path` pointing at the shipped engine. A hand-copied
`winemetal.so` must always match the engine it lands in — *the same lesson as the DXMT v0.80 build
earlier today*, which was also built against `engine-1116`, so **that result deserves the same
suspicion and should be re-examined before being relied on.**

**What survives, because it is static analysis and needs no run:**

| | stock winemetal | notpop's fork |
|---|---|---|
| `_CreateMetalViewFromHWND` at | `0xa320` | `0xa280` (rewritten, plus a `_block_invoke`) |
| `callq *%r15` → `movq 0x18(%rax)` with no null test between | **present** — the crash | **absent entirely** |
| null-tests the *other* call's result 15 bytes later (`a3ee`) | yes | n/a |

Stock checks one call's return and not the other's, 21 bytes apart. That asymmetry is what makes it
an oversight rather than a design assumption, and the fork's rewrite does not contain the faulting
instruction at all. **Whether that fixes Steam is still untested.**

### 🎯 NAMED: the GPU process dies on an unchecked NULL in `_CreateMetalViewFromHWND` (2026-08-30)

Caught a live `--type=gpu-process` child mid-flight and took its `vmmap`, which resolves the
unix-side fault address the `+seh` trace reported:

```
0x2179833df  ->  winemetal.so  __TEXT 0x217979000-0x2194dc000  +0xa3df
```

`nm` puts that inside **`_CreateMetalViewFromHWND`** (starts `0xa320`), at **+0xbf**. The
disassembly is unambiguous:

```
a3d6   movq (%rbx), %rdi         ; set up the argument
a3d9   callq *%r15               ; call
a3dc   movq %rax, %r15           ; keep the return value
a3df   movq 0x18(%rax), %rdi     ; <== FAULT: dereference [rax+0x18]
```

**The call returns NULL and the very next instruction dereferences it at offset `0x18`** — which is
exactly the `info[1]=0x18` the SEH trace reported. A missing null check, nothing subtler.

**Base verified stable across two independent runs** (`217979000-2194dc000` both times, no ASLR on
these modules) — checked deliberately, because the same class of cross-process base-mismatch error
was made twice earlier in the day and produced a garbage disassembly both times.

**The convergence that matters.** `_CreateMetalViewFromHWND` is *precisely* the function
[notpop/dxmt@debug/present-path-tracing](https://github.com/notpop/dxmt) rewrites, and its commit
message names the reason as **"`macdrv_win_data` not exposing a usable NSView at swap-chain
creation"** — i.e. a NULL where an NSView was expected. They found this independently, from the
other end.

⚠ **So the standing "notpop's fork does not fix the Steam client" result needs re-testing.** That
was measured on cells with **no font library** and is `PARTIAL` for exactly that reason. The fork
targets the function we have now proven is the crash site. **This is the next experiment.**

⚠ **One thing this does not yet reconcile:** the crash is backend-independent — `--use-angle=swiftshader`
produced an identical count and a byte-identical window — which requires `winemetal.so` to be
loaded and reach this path even under software rendering. Grepping the swiftshader cell's stdout for
`winemetal` returns **0**, but that is log text, not a load record, so it settles nothing. Confirm by
`vmmap`-ing a gpu-process under swiftshader before treating the two results as consistent.

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
| C2 | The cross-process **child-window** patch makes Steam's client composite on stock winemac + DXMT | `PARTIAL` | `exp_6bd192` `exp_06760c` `exp_3d7586` `exp_015b85` — **void-ok:** whether a layer composites is font-independent, so the byte-size jump stands | **Superseded for the current build by C12–C30** — Steam now renders completely, out-of-process, with no shim. The **2,588,759 B** composite measurement stands as the first proof the route composites, and that is font-independent; the "still no text" half was always VOID — every one of those cells ran with no font backend. |
| C3 | `macdrv_get_cocoa_window` returns NULL for a foreign HWND — the cross-process root cause | `SUPPORTED` | source read + direct measurement | Derived from reading wine's source and a targeted probe, not from a render cell. |
| C4 | The glyph loss is in-process GPU itself, not the `--in-process-gpu` flag | `DISPROVEN` | `exp_d7dd0d` — in-process GPU **with fonts working** renders Steam's storefront complete with text | The premise was never true. With `nohup` removed (C10) the *same* config — shim injecting `--in-process-gpu`, confirmed on the real webhelper's command line — renders the full client: menus, nav, store copy, review counts, all legible. **In-process GPU never had anything to do with glyphs.** Proof: `docs/images/steam-renders-with-text.png`. |
| C5 | Text **rasterisation** eliminated — `dwritetest` byte-identical across engines | `RETRACTED` | `scripts/dwritetest.c` | The measurement stands (ALIASED 545/1633 sum 138975; CLEARTYPE 315/4899 sum 80325, identical on both). The **elimination** does not: `dwritetest` runs as a standalone PE, and standalone PEs were measured 2026-08-30 to resolve FreeType fine on *both* engines. It never exercised the failing condition. |
| C6 | Glyph-atlas texture path eliminated — `scripts/r8test.c` | `RETRACTED` | same class as C5 | Same defect: a standalone PE probe cannot eliminate a fault that only appears under Steam. Measurement kept, elimination withdrawn. |
| C7 | CPU raster renders Steam **with text** on an 11.0-lineage engine | `PARTIAL` | `exp_8d065a`, `exp_fb79d9` | `winestable-cpuraster` is genuine — shim installed, libs resolve, text visible. **`pk-cpuraster` is mislabeled**: that prefix has no shim, so `--shim-args` never applied and it was an ordinary launch, not CPU raster. |
| C8 | macOS is not the variable; wine-stable 11.0 renders where our 11.16 does not | `RETRACTED` | `exp_fb79d9` vs `exp_53a8e6` | Not a controlled comparison: one side had the shim and a working font backend, the other had neither. Retracted 2026-08-30, same day it was committed. |
| C9 | DXMT beats vanilla wined3d at every cell (wined3d gets FL 9_3 only) | `UNREVIEWED` | `scripts/dxgiprobe.c`, the `vanilla-*` cells | The feature-level measurement comes from a standalone probe and is font-independent, so it plausibly survives — but it has **not** been re-audited against the config rules. Do not cite as settled. |
| C10 | **SOLVED — our own harness caused it.** `nohup` strips `DYLD_*`, and this engine's `win32u.so` cannot find its own libfreetype without it | `SUPPORTED` | `exp_0a43b3` (0 FreeType failures, glyphs rasterise in-tree) vs `exp_4b9824` (63, no coverage) — same script, one line changed | macOS **purges `DYLD_*` when exec'ing a SIP-protected system binary**. Measured: a bare `dlopen("libfreetype.dylib")` succeeds directly and **FAILS** via `nohup`, via `env`, and via `/bin/bash -c`. The harness launched Steam with `nohup`. Removing that one word took FreeType failures **63 → 0** and made DirectWrite rasterise **inside Steam's tree** for the first time. |
| C11 | Without FreeType, DirectWrite **enumerates 204 families but rasterises nothing** — so the font failure IS sufficient to explain zero glyphs, and the family count is a decoy | `SUPPORTED` | `exp_4b9824`, `exp_95fb82` (in Steam's tree, via the shim) + shell A/B on the same engine — **void-ok:** the library failure is the condition under measurement, not a defect in it | **In-tree: DWrite 204 families, `hr=S_OK`, glyph run `ABC@32` → bounds `0x0`, nonzero `0`, sum `0`.** Shell control, same engine, same probe: with `DYLD_FALLBACK` set → `71x23`, nonzero `545`, sum `138975`; without → `0x0`, `0`, `0`. Only rasterisation moves; the family count is **204 either way**. The 545/138975 figures reproduce `dwritetest.c`'s recorded ALIASED numbers exactly, which independently validates the port. Overturned by: a cell where in-tree rasterisation is non-zero and text is still missing. |
| C12 | The white hairline at the right/bottom of Steam's client is a **half-point retina rounding** artifact, not a race | `SUPPORTED` | `resize-diag` vs `resize-ship` (`resize-measurements.txt` in each) | Win32 gives RAW PIXELS, Cocoa takes POINTS. An ODD pixel dimension halves to a `.5` point, and the content view is sized in WHOLE points, so the hosted layer lands exactly **one device pixel** short of the view. Measured: root 2401x1500 px → host frame 1200.5x750.0 pt in a 1201.0x750.0 pt view → capture column x=2401 reads `255,255,255` against an interior of `15,25,36`. **The axis that is odd is the axis that shows it** — 2401x1500 right only, 2400x1501 bottom only, 2400x1500 neither. Fixed by extending a hosted frame to the view's edge when it already reaches it. **3 bright-edge findings before, 0 across 20 captures after.** Overturned by: a bright edge on any even-sized capture (would mean the parity story is wrong). |
| C13 | The resize **blackout** is hosted-layer z-order, not a lifetime or surface bug | `SUPPORTED` | `resize-diag` (repro) vs `resize-fix`/`resize-ship` (fix), plus the `tree` dump | Steam's client is **two SIBLING `CefBrowserWindow` trees** on one root (`0x1013E` above `0x6012A`), not a parent and a child as their rectangles suggest. Hosted `CALayerHost`s were stacked in **creation order**, and CEF recreates a swapchain on every resize — so any resize that recreated the LOWER browser put its full-window layer on top of the content and the client went black **and stayed black**. `2400x1500 → 2399x1499 → 2400x1500` reproduced it every time (interior luminance 82 → 1 → 0); after ordering by Win32 paint order it measures 63 → 63 → 113, and 60 alternations at 60 ms end rendering. Observed live: `0x2011E → z2`, `0x10140 → z5`, independent of creation order. Overturned by: a blackout with the z-order trace showing the layers correctly ordered. |
| C14 | The **navigation** blackout is an empty (0×0) child rect being treated as "no rect supplied" and stretched over the view | `SUPPORTED` | Library-navigation trace (`-DDXMT_RSZ_DEBUG`) + a six-navigation sweep | **Found by James in ordinary use, minutes after the scripted resize suite passed clean** — the suite drove geometry and never drove content, so it could not have found this. CEF keeps an inactive browser in the z-order at **0×0**; `CGRectIsEmpty` cannot distinguish that from the root-window "no child rect" case, so the layer was stretched to the whole view, on top, with nothing drawn in it. Measured: `0x1013E/0x10140` = `0x0` exactly while black, `2598x1275` once the store view returned. **A resize does not clear it** (the update path skipped empty frames) — that is the tell separating it from C13. Trace: `HOST create ctx=2870122112 frame=0.0,0.0 0.0x0.0 (view 1300.0x780.0)` at `z5`. Fixed by testing `CGRectIsNull` before `CGRectIsEmpty` and hiding a zero-area layer. Verified: six navigations, none black, 0 GPU crashes. Overturned by: a blackout whose trace shows no empty frame. |
| C15 | Gating the **un-hide** on the frame having changed black-holed Steam's Friends List | `SUPPORTED` | Friends List trace + capture 20,420 B lum 0 → 274,680 B lum 38 | **My own regression, live ~1 hour, found by James in ordinary use.** The window briefly reports 0×0, the layer is hidden, then the frame returns to *the value it already held* — so a `!CGRectEqualToRect` guard on the whole branch skipped the un-hide permanently. Visibility and geometry are independent state; each needs its own test. Overturned by: a black popup whose trace shows `hidden = NO` already set. |
| C16 | `macdrv_swapchain_set_bounds()` is **dead code** — the claim it fixed stale strips is WITHDRAWN | `SUPPORTED` | `SURF-UPD`=0 and `CONTENT`=0 across five instrumented sessions vs 67/120/184/101 `HOST create` | Its only caller is `macdrv_client_surface_update()`'s remote-layer branch, which never fires: CEF resizes by destroying and recreating the swapchain, so the in-place path is never taken. It shipped beside two changes that DID work, the symptom improved, and the improvement was credited to all three. Kept and annotated, not credited. Overturned by: any session where that branch logs. |
| C17 | The resize **shimmer** is not our layers being stretched — and the positive cause is now measured | `SUPPORTED` | instrumented SCALE check: 0 stretch events; and the only path that could stretch is C16, which never runs | **Both halves are now measured (T1, 2026-08-31).** Churn produces visible gaps: a 240-step churn gave 35 distinct frames of 40 with 2 showing a **black content area while Steam's chrome rendered perfectly**; a 40-capture static control on the same window gave 1 distinct frame and 0 black. That is the content browser's layer un-hosted with no replacement up. Fix built (retire-on-create) and **verified 2026-08-31: the gap rate falls from 2/40 (5.0%) to 2/160 (1.25%), a ~4x reduction — but it is NOT eliminated.** The first post-fix trial showed 0/40 and would have been reported as fixed; trials 2 and 3 each showed 1. Residual frames carry the same signature (chrome perfect, content black), so it is the same class of gap in a sub-case the fix misses — leading hypothesis is a content child recreated under a NEW HWND, which `retire_superseded_layers()` cannot match. Untested. Original note follows: What the trace does show is churn — 24 scripted resize steps produced **101** `HOST create` and **83** `HOST remove` across the two browsers, so layers are constantly un-hosted and re-hosted and the window shows whatever is behind during each gap. That would explain a shimmer, and it is **untested**. Do not write it up as the cause. |
| C18 | The menu **black-box lag** is `backgroundColor` painting a hosted layer before its first frame | `SUPPORTED` | parity re-measure with the background removed, then deferred | Added the same morning to cover a 1-device-pixel seam. A `CALayerHost` is visible as soon as it is added, so the background paints the whole layer black until the remote context presents — and each Steam menu is its own popup window, so mousing across the menu bar hosts a fresh layer per menu. **Removing it is not the fix:** re-measured, the seam returns exactly on the odd axis (2400×1500 → 0 bright edges, 2401×1500 → 1, 2400×1501 → 1, 2401×1501 → 2), so it is load-bearing. Deferred by 120 ms instead: transparent while empty, black once content has arrived. Verified 0 bright edges on all four parities, popups unaffected. Overturned by: a black flash whose trace shows the background already deferred. |
| C19 | Paradox launcher hit-testing is offset vertically from the visible cursor | `PARTIAL` | James's report + `win-resize-driver rects` on the launcher window | Renders fine and the game boots from it to `MainMenu`, but you must aim above a button to hit it. Measured: the launcher's top-level `Chrome_WidgetWin_1` has a Win32 client offset of **dx=5, dy=0**, so "off by the title bar in Win32" is ruled out — yet macOS draws one. If the Cocoa content view starts lower on screen than Win32's client origin, CEF receives a client *y* that is too large and highlights a control below the cursor, which matches the reported direction. **Mechanism now measured 2026-08-31:** the content view is **642 pt** tall (from the hosted-layer trace) inside a 674 pt window — a **32 pt** macOS title bar — while Win32's client rect is 1339 px = **669.5 pt**. Widths match exactly; Win32 believes the client is **~27.5 pt taller** than the view that displays it, so a cursor maps ~28 pt too low. Magnitude matches the report. **Ownership still untested** and **ownership untested** — our edits touch layer frames/z-order/visibility only (`grep -c macgameport` over the event path = 0), and the A/B against the stock `winemac.so.bak-*` has not been run. Overturned by: the same offset on stock winemac (⇒ pre-existing, not ours). |
| C20 | The Paradox "crashed / exit code null" dialog and the `assert_*.dmp` are both benign | `SUPPORTED` | six dumps, one per run, incl. two boot-verifies that reached `MainMenu`; `SceneFlow.log` 05:39:03 → `MainMenu reached` 05:40:07 | Steam's handler writes an `assert_cities2.exe_*.dmp` on **every** launch (Mono `gpath.c:115 assertion 'filename != NULL'`), including known-good ones, so its presence proves nothing. The launcher's `exit code null` is it failing to *read* an exit code from a wine process after a run that reached `MainMenu` and shut down normally. **Every game start on 2026-08-31 reached `MainMenu`; there is no failed run in the logs.** Overturned by: a run with no `MainMenu reached` line. |
| C21 | The launcher's PLAY never starts the game — `spawn Cities2.exe ENOENT`, not a crash | `SUPPORTED` | `launcher-2026-08-31.log` (4 occurrences) + `launcher-settings.json` | `exePath` is `../Cities2.exe` and Steam passes `--gameDir ...\Cities Skylines II\Launcher`, but `Cities2.exe` is in the game **root** and what reaches `spawn` is the bare name. The "crashed / exit code null" dialog and all of its advice (verify files, disable mods, install VC++/.NET) are wrong — nothing was launched. Unrelated to the rendering patches. Workaround: the shortcut runs `Cities2.exe` directly. Overturned by: a PLAY that starts the game with the same log line present. |
| C22 | "A launcher update has failed — check your internet connection" is loopback, not internet | `SUPPORTED` | same log: `EADDRNOTAVAIL 127.0.0.1:11000` ×2, `cpatch took too long to connect` ×11; `api.paradoxplaza` 200 and Steam 200 measured host-side | The launcher talks to a helper (`cpatch.exe`) over **localhost TCP 11000** and cannot connect under wine. Cosmetic — the launcher works un-updated. Overturned by: the update succeeding while the EADDRNOTAVAIL lines are still present. |
| C23 | winemac decorates frameless windows because it reads style bits, not the client rect | `PARTIAL` | style/region/rect probe on Steam vs the launcher; before/after capture | Both windows have `WS_CAPTION`, neither is shaped or layered — so the style test cannot separate them. What does: Steam's client fills its window exactly (`dx=0 dy=0`, escapes via the existing `EqualRect(window, visible)` guard) while the launcher reserves 5px left/right/bottom and **zero on top** (`dx=5 dy=0`) — a resize border with no caption, the `WM_NCCALCSIZE` frameless pattern. Suppressing `title_bar` when `rects.client.top == rects.window.top` removes the doubled chrome, **verified visually**. ⚠ **It does NOT fix the cursor offset**: content-view vs Win32-client stays 27.5 pt apart before and after (642.0/669.5 → 643.0/670.5) — the Cocoa window shrank by the caption height instead of the content growing into it. **The change was REVERTED** — see C24: it leaves `macdrv_GetWindowStyleMasks` still reserving caption space, so the NSWindow merely moves down by it. Overturned by: a frameless window that still gets a title bar with the client-top test in place. |
| C24 | The cursor offset is window-relative, and caused by **two** functions answering "has a title bar" differently | `SUPPORTED` | bracketed `GetCursorPos` vs `CGEvent`; before/after window origins | Global mapping is **exact** (dx −0.4, dy −0.4 px — truncation), so it is not a pointer bug. `ScreenToClient` subtracts a window origin 56 px (28 pt) above where the NSWindow actually is. Cause: `macdrv_GetWindowStyleMasks` → `get_window_features_for_style()` (style bits only) tells win32u how much non-client space the window rect reserves, while `get_cocoa_window_features()` (style bits **+ `data->rects`**) decides the real Cocoa decoration. Patching only the latter left win32u still reserving caption space and merely moved the NSWindow down by it — 27.5 pt error before **and** after, so the change was reverted. A fix must make both answers share one source of truth. Overturned by: an offset that persists with the two functions provably in agreement. |
| C25 | The launcher's `spawn Cities2.exe ENOENT` is **not** a path problem | `SUPPORTED` | two PLAY attempts, the second with an absolute `exePath` | Setting `exePath` to a full absolute path **did take effect** — the launcher logged `Starting game: C:\...\Cities2.exe` — and the spawn failed identically. Node formats ENOENT with the *basename*, which is what makes it look like a bare-name lookup. The file exists, the path resolves, and plain wine launches that same exe to `MainMenu` (the shortcut does exactly that). So the fault is the launcher's own Electron/libuv spawn under wine. **The edit was reverted** — it changed no outcome and Steam would revert it on validation. Overturned by: a PLAY that succeeds after a path-only change. |
| C26 | The resize **shimmer is closed** — retire-on-create plus a per-child deferred release | `SUPPORTED` | T1 across three builds, 520 sampled frames, static controls throughout | Gap rate **5.00% (2/40) → 1.25% (2/160) → 0.00% (0/320)**, interior-luminance minimum **0 → 0 → 28**. p≈0.018 for zero in 320 against the 1.25% rate. Dark frames were diagnostic: chrome perfect, content area black. Two changes — (1) retire superseded layers on CREATE so the child is never unhosted, (2) hold the deferred `client_surface` release **per child HWND** rather than in one global slot, since that is the only lever that keeps the remote `CAContext` alive across a recreate. ⚠ A third design ("keep the orphaned host until a successor lands") was **killed by reading before building**: `dealloc` releases the context, so the host has no content source to preserve. **First post-fix trial showed 0/40 and would have been reported as fixed** — trials 2 and 3 each showed 1; repeating is what turned "fixed" into "4× better". Overturned by: a near-black content frame on the per-child build with the instrument validated live. |
| C27 | The winemac frameless-decoration bug reproduces on **stock** wine 11.16, in 60 lines | `SUPPORTED` | `scripts/frameless-window-repro.c` on `engine-1116` in a throwaway prefix; `~/cs2-patch/evidence/repro-stock.png` | A window whose `WM_NCCALCSIZE` reserves a 5px border and **zero** caption (`dx=5 dy=0`) gets a macOS title bar with traffic lights. Stock `winemac.so`, zero project symbols. **The trigger is a border without a caption:** reclaiming the whole rect gives `dx=0 dy=0`, fires wine's own `EqualRect(window, visible)` guard and is undecorated — which is Steam's window and why Steam is unaffected, and why the naive reproducer would have "proved" there is no bug. `SWP_FRAMECHANGED` after creation is mandatory or `WM_NCCALCSIZE` never takes effect (`dy=30`) and the run means nothing. Overturned by: a stock run with `dx=5 dy=0` and no title bar. |
| C28 | Live-drag flicker: **no gap-class events** during a real mouse drag | `PARTIAL` | `scripts/livedrag-probe.sh`, 80 frames over 14.2 s of a genuine drag (25 distinct window sizes) | **Now measured**, which `shimmer-probe.sh` could not do — it drives `SetWindowPos`, while a human dragging an edge goes through macOS live-resize. `livedrag-probe.sh` waits for the window to settle, arms, detects the drag starting, then samples hard: **0 near-black frames in 80**, interior lum min 23 / median 77. The drag was genuine — 25 distinct window sizes while sampling — and the probe reports VOID rather than a pass if no drag happens. **`PARTIAL`, not `SUPPORTED`, and the limit is arithmetic:** sampling ran at 5.6/s (one frame per **178 ms**), so this rules out a gap rate near the pre-fix 5% (P=0.017 of seeing zero) but **cannot see a single-frame 16 ms flash**, which would usually fall between samples. James's independent assessment by eye was "minimal". Overturned by: a gap caught at higher sampling density. |
| C29 | The 2026-09-02 lifetime hardening (dead-child drain + per-release sweep, owner-side pruning, root-keyed tracking, no hosting of a child that died in flight, frame update after the Cocoa frame is current) keeps every prior result | `SUPPORTED` | `exp_9b5030` `exp_2e93af` `exp_a879f0` (fingerprinted, FT 0) + game boot: `Logs/SceneFlow.log` 16:24:23 → `MainMenu reached` 16:25:25, graceful `GameManager destroyed`, 0 `InvalidProgramException`, 7 mod logs | Installed module `310f13d03e27732d`. 0 GPU crashes across three sessions; six navigations render; blackout sequence 83/84/112 with 0 bright edges on the odd size; two 40-sample churns + a static control at 0 gap frames; popup open/close with 5 dead-child prunes and 5 drained slots seen in `dxmt-life` traces. **What would overturn it:** a gap frame or crash on the same battery, or held-surface growth over a long popup session — only the drain *firing* was measured, not the steady-state count. |
| C30 | In the current stack **every cross-process child is created and owned by the browser's UI thread** (the thread that owns its root and runs the hosting handler); the GPU process is foreign to the whole tree and only acquires layers | `SUPPORTED` | `exp_9b5030` (`WINEDEBUG=+macdrv`): for children `0x2011c`, `0x20138` (main root `0x40122`) and `0x10198` (popup root `0x10194`), `macdrv_create_win_data` and every `WindowPosChanging`/`Changed` hook (20/20, 21/21 and 25/25 respectively) ran on tid `0130`, which also runs every `WM_MACDRV_CREATE_REMOTE_LAYER` handler line (20 children); `my_get_win_data` → NULL and the cross-process branch ran on tid `01dc` (5×, 6×, 7×), which also emits every `dxmt-life` line and **no** `WindowPos*` hook for any window | Corrects the 2026-08-31 reading in `docs/steam-ui-findings.md` § Diagnosed ("the child is owned by the GPU process", measured on `0x10104` under the fork build). Consequence: the owner already sees every child move through its own driver hook and discards it at the no-cocoa-window exit — the design premise of `docs/plans/hosting-layer-design-gaps.md` D1. **What would overturn it:** a hosted child whose hook tid differs from the CREATE-handler tid (T0 in that plan). |
| C31 | The winemac reference **splits cleanly into a stock-applicable core and a DXMT glue layer**, and the split module keeps every C29 result | `SUPPORTED` | `exp_519eef` `exp_1da98c` `exp_37f651` `exp_4679e5` (fingerprinted, FT 0) + boot-verify run `20260902-214032` + the stock build in `build-1116/wine-1116-stock-build` | Core is 656 lines and applies with **zero fuzz to pristine 11.16 AND to 11.16+aquadran**, compiles on pristine (exit 0, driver warning set identical to the 56-warning stock baseline, the `Cross-process child window Metal swapchains are not implemented` FIXME string 1 -> 0 in the binary), and links — so it implements the FIXME for `vulkan.c` too, whose two entry-point signatures are byte-identical to stock. Glue is 186 lines. stock+aquadran+combined reproduces all five files byte-for-byte, and core-then-glue reaches the same place. On the rebuilt module `53c9443db3145f58`: six navigations all RENDERED (interior luminance 37-121), blackout sequence 83/84/85 with **0 bright edges on the odd size**, popup open/close then main still RENDERED, **0 GPU crashes across three cells**, 2 dead-child prunes, 1 slot drained, 0 acquire failures, 0 ERR lines; churn x2 + a static control **0 gap frames** (interior-luminance minima 42 / 19 / 79); game boots to MainMenu with a graceful exit and 0 `InvalidProgramException`. **What would overturn it:** a base wine version where the three relocated insertion points collide again, or a gap frame on this module with the churn probe validated live. ⚠ The first churn attempt was VOID, not failed — the probe leaked a running churn on its abort path and the control measured during it (GOTCHAS 2026-09-03); numbers above are the re-run. ⚠ **Addendum 2026-09-03:** the split's invariant broke silently when D1/D2 (C32) landed on `main` only — the committed core patch lacked them and the generator's `main~1..main` glue range yielded the wrong commit. Caught by `--check` ~14 h later while preparing the bug-60263 attachment. Fixed by rebuilding `main` as aquadran → core(+D1/D2) → glue (tree byte-identical; old tips tagged `pre-restructure-*`; bundle `winemac-drv-history-20260903-restructured.bundle`), pinning glue by subject, and wiring `--check` into `check-experiments.py`. **Re-measured with D1/D2 on pristine 11.16:** applies with `git apply`/`patch -F0`, exit 0, warning set identical (55/55, message text compared with file:line stripped), FIXME string 1 → 0 in the built module; four files, +513/−27. ⚠ **Addendum 2026-09-04:** the comment pass after issue #6 (nested `core` `63a0cec`, `main` `52789ff`) is measured behaviour-neutral: `cocoa_window.o`, `window.o` and `winemac.so` byte-identical to the previous build (`00ac32aa3115b455`, the installed module), `strip-comments.py` CODE IDENTICAL on both files, `--check` green; the core patch is 1082 lines. |
| C32 | The design-gap changes are correct **only with D1 scoped to the child that moved**; the first form was an O(n) regression that every individual test passed | `SUPPORTED` | store-page churn A/B across three modules, 1,200 sampled frames; suite run `20260903-012103`; boot-verify `20260903-012453` | **D1** (refresh hosted layers on a child's own `WindowPosChanged`) and **D2** (single-pass growable paint order, no breadth cap) both verified: T0 premise holds on this build (CREATE tid `0130` vs acquiring tid `01dc`, disjoint), T1 content shifts by exactly the delta and vacates the old column, T2 restacks by 103/channel and restores, blackout 87/92/113 with 0 bright edges, churn and static 0 gaps, 0 `paint order incomplete` across ~250 layer creations, 0 acquire failures, 0 GPU crashes, game boots to `MainMenu` with a graceful exit. **The regression and its fix are the finding:** D1 first called the full `update_remote_layer_frames`, repositioning every layer on the root, but a child's own move moves one child — during a resize the root moves, all n children move with it, and n full passes ran where one would do. Measured on Steam's store page: **0 gaps / 320 frames** before D1/D2, **9 / 400** with the full pass (p < 0.001), **0 / 160** with that branch disabled and D2 left active (which pinned it to D1, not D2), and **1 / 480** once D1 updates only the moved child (p = 1.0 vs baseline). ⚠ **Every individual test passed on the regressing build** — it was visible only by A/B against the previous module at a sample size able to resolve a sub-1% rate. **What would overturn it:** a gap rate above baseline on the targeted build at ≥ 480 frames, or a client that moves a child without re-creating its swapchain behaving differently (see the T1-mutant note below). ⚠ This build did not regenerate the published patches; see the C31 addendum. |
| C33 | The DXMT half is recorded, generated from git and re-verified; its three review nits are closed and every mutant is red | `SUPPORTED` | suite run `20260903-062937`, boot-verify `20260903-063316`, mutant cells `dxm-green` / `dxm-t3` / `dxm-t3b` / `dxm-t4b` | Rebuilt `winemetal.so` `81b94bbf1e6fe598` installed byte-identical to the build artifact (27,924,120 B, unsigned like the file it replaced, dated backup beside it). Pre-build gate: `ninja -n -d explain` shows only the `.o` + link, **0** `metal` invocations. Unixlib table re-measured at **132 entries**, `nm` delta `0x420` — the plan's original 131/`0x418` would have failed its own gate; export set identical to the previously installed `.so`. Patch regenerated from branch `cs2/remote-layer` (two commits: the mingw `<iomanip>` fix separately) and **reproduces the working tree byte for byte** from a pristine `v0.80`. Battery on the rebuilt `.so`: T0 disjoint, T1 green, T2 restacks 86/channel and restores, blackout 85/84/85 with 0 bright edges, churn and static 0 gaps, 0 acquire failures, 0 GPU crashes, boot `VERDICT: PASS`. **Mutants, all red and restored:** ignoring the release hook's TRUE → blank client (40,903 B against a 2,594,598 B baseline, instrument healthy); disabling the acquire hook → **6 GPU crashes**, black window; the wine side handing back a NULL view → **6 crashes, and the new defensive line fires 6 times**, which is the only way to reach a branch that is dead by construction. **What would overturn it:** a table length other than 132 after any DXMT-side rebuild, since the PE pairs by bare index with no diagnostic. |
| C34 | Live drag on the hardened module (D1-scoped `cd79fc463795939f`): **the interior never blacks out during a genuine 15 s edge drag** — the growing edge does (C35) | `PARTIAL` | cell `livedrag-setup3` (fingerprinted, 0 fatal 0 warn; frames `drag-01..60.png` + `drag-sizes.txt`), probe run 2026-09-03 16:34–16:36 | James dragged the Steam window edge by hand. The probe armed on 1245x800, detected 1232x849, and sampled **60 frames in which the window had 60 distinct sizes** — motion was continuous through the whole sample; interior luminance min **76** / median 90 / max 113, **0 gaps** (<15). Same resolution limit as C28: one capture per ~178 ms cannot see a single-frame flash, so this rules out gap-class blackouts at the probe's resolution, not sub-frame flicker. Two earlier attempts the same afternoon voided (nobody dragged inside a 240 s window — the probe now documents `WAIT=1800` for agent-run sessions) and a human-terminal run's output was never captured; only this run counts. **What would overturn it:** a gap frame during a live drag on this module, or a higher-rate capture (screen recording) showing a flash the probe cannot resolve. ⚠ **Re-scoped the same evening.** James saw black boxes on the open edge while dragging; re-scoring these same 60 frames per band shows the right band ≥20% true black in **19 of 60** (up to 92.6%) and the chrome row fully black when the top edge was dragged. The probe's score — min(perimeter mean, interior) — was blind to a 280 px black strip. The measurement stands (interior never <15); the inference *clean drag* is withdrawn. See C35 and issue #7. |
| C35 | **Live resize exposes a black strip at the growing edge** — the hosted child lags the drag and the host layer's black background shows through the uncovered part of its frame | `SUPPORTED` | cell `livedrag-setup3`, frames `drag-*.png` re-scored with `scripts/darkboxes.swift` (lum<6, outer 10% bands); issue #7 | Recomputed after a field-mapping bug in the first summary (below): the **right band** is ≥20% true black in **19 of 60** frames, up to **92.6%** (frames 32, 09, 41, 50); the **top chrome row** is fully black in the two frames where the top edge was dragged (**100%** in 49, 97.6% in 46); the bottom band is not counted, because the store page's own black artwork crosses the threshold there. Frame 09: chrome and bottom bar already at the new width, page at the old width, ~280 px of solid black between. Mechanism read from `cocoa_window.m` on `main`: the host frame is set to the new rect at once (`snap_host_frame_to_view_edges`, `update_remote_layer_frame_for`) while the remote content stays at the last presented size; the uncovered area is `host.backgroundColor`, black since the hardening's sliver fix (deferred 120 ms, `:770-781`). Shrinking clips instead, hence open edge only; a top-edge drag moves the host frame under stale content and blacks the chrome row. James: the native macOS client shows none of this, or only very briefly. **Not a regression — architectural.** Churn A/B with frames kept (cells `edge-post` on `cd79fc46`, `edge-pre` on `53c9443d`, the pre-D1/D2 module): the same maxima on both, right band 86.2% and bottom band 100%, so the strip predates D1/D2. The frame counts (17/40 vs 8/40) are not comparable — the runs started from different window sizes (1040x909 vs 1920x1050) and grew by different amounts. **What would overturn it:** a module on which the same churn shows no band black. ⚠ The first publication of this row (295f806) said 56 of 60 and mislabelled an edge: the summary awk read the block-width field as a band, so any frame with a dark block ≥20 px wide counted, and the analyser had T/B swapped. Fixed and recomputed the same evening — the images were right, the count was not.  **Stage 1 addressed the S1 half and was measured 2026-09-03: see [[C38]] (interleaved A/B, right band -33 %) and [[C39]] (T2a, S1 -> 0 at threshold, residual entirely S4).** |
| C36 | **The growing-edge strip has two sources and neither is the child's layer**: an existing host reframed larger than its content (S1), and the window growing before the app has resized its children so no host covers the strip (S4) | `SUPPORTED` | cells `m0-colour` (host create-path background red, reframe-grow green) and `m0b-colour` (plus the child's offscreen layer blue), 40 churn frames each, scored by `scripts/darkboxes.swift` + `darkboxes-attrib.py`; `classbg` (class brushes) | Right band ≥20 %: **green 9 and 10 / 40** at 78–86 % — the reframed old host's own background (S1); **black with no diagnostic colour 6 and 8 / 40** at 77–86 % — beneath every host (S4); **blue 0 / 40** — the child's black layer (`cocoa_window.m:4232`) never shows before its first drawable (S3 ruled out). Red is unusable: the store banner is red. M0 frame 15 shows stale content pinned **top-left** with the exposed L at right and bottom; frame 14 shows a *shrink* displacing content (top ≈138 px cut off; the band at the bottom is dark grey, **not** true black — `B = 0.0 %` at lum<6 — and which layer moved is unattributed; the plan's T7 measures it). Class brushes (`win-resize-driver.exe classbg`): root `SDL_app` NULL, `CefBrowserWindow` NULL, `Chrome_WidgetWin_1` solid **000000**, `Chrome_RenderWidgetHostHWND` `COLOR_0+1` (index 0, `GetSysColor` → `FFFFFF`; the row first read `COLOR_WINDOW+1` — wrong index name, same printed colour — corrected 2026-09-03 from `classbg/classbg.txt`, which is what the driver printed). ⚠ **Corrected the same evening (check-it, correctness lens):** the first version of this row inferred "Windows erases the resized widget black" from that table; Chromium's `HWNDMessageHandler::OnEraseBkgnd` returns 1 and never uses the brush (read from source), so **Windows erases nothing there and what it shows is not established** — what stands is that no Windows path paints the strip, so a fix is a beyond-Windows nicety. **Inferred, not yet measured:** S4's timing (root resized, children not yet) — the plan's T0 checks it from the `+macdrv` trace. **What would overturn it:** a magenta create-path run showing S2 (a new host past 120 ms with no frame) as a major share, or the T0 trace showing child rects already updated in the S4 frames.  **[[C39]] re-ran this attribution on the stage-1 module with the same colours: S1 collapses from 78-86 % of the right band to a max 0.80 %, S2 and S3 stay 0, and the residual is S4 alone.** |
| C37 | **A hosted, out-of-process CALayer tree honours the hosting layer's `transform`** — so scaling a stale host over its new frame (issue #7 stage 1, option B) is possible at all | `SUPPORTED` | T1 spike: throwaway branch `t1-spike` off nested `main`, fixed `CATransform3DMakeScale(1.5, 1.5, 1)` with `anchorPoint (0,0)` applied at CREATE in `addCALayerHostViewWithContextId` so it holds at rest; module `66f8bec678bb620c` vs baseline `cd79fc463795939f`; Steam **Library** page (never the store — its autoplaying video changes the capture between shots); display profile **home**, retina off, native 1:1; `scripts/t1-spike.sh` both phases + the analysis; captures in `~/cs2-patch/t1-spike/`, cells `t1-before` / `t1-after` | The library's strongest column edge moved **296 px → 448 px, ratio 1.514** (independent edge-detection over the column-mean profile, 8 px step, so 1.5 within resolution); the plan's own three-part criterion was decisive at X=560 (`control 37, moved-to-1.5X 3, left-X 15`); the RED gate (both strips unchanged ≤ 2 at every X) did **not** fire; capture size fell 1.72 MB → 1.09 MB, consistent with magnified content and right/bottom clipping. The spike also printed **`geometryFlipped=YES viewIsFlipped=YES retina_on=NO`** — which is what makes `anchorPoint (0,0)` the visual **top-left** here rather than an assumption. ⚠ The per-column strip test was decisive at only 1 of 12 candidate X, because `pixel-probe strip` averages a column over the whole image height and a 1.5× **vertical** stretch changes that mean too; the edge-ratio is the strong measurement and the criterion is the weak one. **Inferred, not measured:** that the right/bottom third is clipped — the library page's right third is flat, so a column mean cannot separate clipped from flat. **What would overturn it:** a decisive-at-zero-X re-run on a page with horizontal structure across the full width. |
| C38 | **Stage 1 measurably reduces the growing-edge strip under churn, but does not remove it** — consistent with the residual being S4 (no host covers the strip), which stage 1 does not address | `PARTIAL` | Interleaved A/B, same session, same store page, 4 Steam sessions × 2 churns × 40 frames = 160 frames per arm, order baseline · stage1 · baseline · stage1: modules `cd79fc463795939f` (baseline) and `2a251a4b2510fb84` (stage 1 + scale TRACE + the 8 px degenerate floor); `scripts/stage1-tests.sh` with `MODULE=`, frames scored per EDGE by `scripts/darkboxes.swift` + `scripts/band-counts.py` at lum < 6; runs in `~/cs2-patch/stage1-ab2/` | **Right band ≥ 20 % true black:** baseline 12 · 17 · 12 · 13 = **54/160** (mean 13.5/40) → stage 1 9 · 7 · 12 · 8 = **36/160** (mean 9.0/40), **−33 %**. **Bottom band:** baseline 17 · 23 · 15 · 20 = **75/160** → stage 1 9 · 10 · 11 · 9 = **39/160**, **−48 %**, and the per-run ranges do not overlap (15–23 vs 9–11). Worst band unchanged at 86–94 % in both arms — when a frame is bad it is still fully black, which is the S4 signature, not S1's. Static control 0/40 in every session. The scale TRACE shows stage 1 **engaging**, not merely installed: 238 placements at `scale 1.091,1.103` and 235 at `1.091,1.115` in one session (= 2400/2200 and 1500/1360, the churn's own ratios), plus the shrink direction at `0.917,0.907`. ⚠ **This is NOT the plan's T2a**, which requires the **diag-fix** module (green = reframe-grow host background, magenta = create path, blue = child layer) to separate S1 from S4; on a colourless module the residual 9/40 cannot be attributed. **T2a was run later the same evening — see [[C39]]**, which confirms this row's inference by measurement: `Rgreen` 0/120, and the residual is entirely S4. **What would overturn it:** a diag-fix churn showing green still present, which would mean the scaling is applied and still leaves background exposed — **run 2026-09-03, green 0/120, condition not met ([[C39]])**. |
| C39 | **The growing-edge strip that survives stage 1 is entirely S4 — no host covers it at all.** Stage 1 removes the S1 source (an existing host reframed larger than its content); S2 and S3 contribute nothing to the edge bands | `SUPPORTED` | T2a as specified: **diag-fix** module `50fdfe79898dac36` (stage 1 + magenta on the create path's deferred background at `main-old:781`, green on a placement larger than its stored content, blue on the child's offscreen layer), built from nested **`main`** through `scripts/build-winemac.sh`; Steam **store** page; `scripts/stage1-tests.sh DIAG=1 CHURNS=3` = 3 x 40 churn frames, scored per band AND per colour by `darkboxes.swift` + `darkboxes-attrib.py` at lum < 6; run `~/cs2-patch/stage1-tests/t2a-20260903-201503`, cell `stage1-t2a-20260903-201503` = **exp_51334e**. Mutant E1 (`f7b2ad5d54455689`, the content-size read-back removed) run identically at `e1-mutant-20260903-201954` (**exp_f0d8a4**) | **T2a passes every clause.** `Rgreen >= 20 %` **0 / 120** (C36 pre-stage-1: 9 and 10 / 40 at 78-86 % of the band); magenta 0 / 120 in every band; blue 0 / 120; black-with-no-colour **8 / 9 / 12 per 40**, inside the 3-13 positive-control range; static control **0 / 40** gaps in the same session. **The instrument is proven to register, not merely silent:** green paints in 19 / 120 frames and magenta in 24 / 120 at whole-frame fractions of 0.08 % and 0.01 % -- so `Rgreen 0` is a magnitude collapse (right-band green 78-86 % -> **max 0.80 %**, ~100x), not an unpainted diagnostic. The residual green is localised: `churn-1/f1.png` shows it as a **2-device-pixel column** of `0,249,1` at x=2398-2399. **E1 observed RED in all three runs** -- green **8 / 8 / 9 per 40**, back on C36's pre-fix rate -- and corroborated independently by the trace, which under E1 reads `3021 scale 1.000,1.000` and nothing else: every placement at identity, the mechanism disabled. Module restored, nested tree clean. **Also measured in the same sessions:** T4 0 BRIGHT edges at 2399x1499 at rest (interior lum 88 > 40); T6 PASS on two independent sessions via `scripts/t6-scale-at-rest.py` -- 3 surviving contexts, all at `1.000,1.000`. **Inferred, not measured:** that stage 2 (B') will remove the S4 residual; this run only establishes that S4 is what is left. **What would overturn it:** a live drag (T2b/T3) showing green in the strip, which churn cannot rule out -- a churn is not a live resize. |
| C40 | **Stage 1's grow behaviour is clean on both axes, and two of the plan's own stage-1 test criteria do not bind** — T7's shrink clause cannot discriminate anything, and E2's mutant has no pixel-level signal on this build | `PARTIAL` | One chained session per row, `scripts/stage1-tests.sh`, Steam store page, run dirs under `~/cs2-patch/stage1-tests/`: **T7** on diag-fix `50fdfe79898dac36` (`T7=1 DIAG=1`, width churn 2200x1500<->2400x1500 and height churn 2400x1360<->2400x1500, 40 frames each); **E5** `f309e74dfd74c77b` (anchorPoint 1,1) same shape; **E2** `e84ef3b09b066b6e` (the snap removed from the REFRAME path — the plan's `:816`, resolved on `main-old`) `CHURNS=1`; **E3** `9b6993e62ca091b4` (half the creation size stored) `CHURNS=1`. Mutants built through `scripts/build-winemac.sh`; the prod module was reinstalled at the end of the chain. Cells: T7 **exp_796397** · E5 **exp_0b256d** · E2 **exp_9f018e** · E3 **exp_ad5977** | **T7 grow: PASS on both axes** — width churn `Rgreen >= 20 %` **0/40**, height churn `Bgreen` max **0.10 %**, **0/40**; the black that remains is S4 alone (width 8/40 in R, height 8/40 in B, right band 0). **T7 shrink: NOT EVALUABLE.** Its criterion (bottom band >= 20 % at lum < 40 -> 0) is satisfied by a window that is not being resized: the **static control scores B >= 20 % in 40 of 40 frames at lum < 40, worst 79.4 %**, and at that threshold every band of every grow, shrink and static frame is >= 20 %. The lum < 40 restatement came from the fitted re-check, which correctly fixed a criterion that could never go RED and produced one that could never go GREEN; the control was never scored at the new threshold. `scripts/churn-grow-shrink.py` now prints the baseline beside any such count. **E5 RED** — every band 100 % black in 40/40, with **2050 placement traces** in the same session, i.e. the layers were placed off-screen (anchor at the far corner), not absent; the plan predicted L- or T-band >= 20 % in >= 5 frames and got a strict superset. **E3 RED** — the trace reads `1.999,2.000` / `1.833,1.813` where the fixed module reads `1.000,1.000`, and the page renders doubled. **E2 engaged but is NOT OBSERVABLE at the pixel level**: 172 placements at `scale 0.999,1.000` prove the unsnapped rect reaches the host, yet the odd-size capture shows **0 BRIGHT** edges, because the seam the snap covers is *also* covered by the create path's deferred background — visible directly on the diag module, where the outermost two columns at 2399x1499 read `255,65,255` (magenta, the S2 marker) against `0,0,0` on prod. Two mechanisms cover one seam, so removing either leaves no white. **Inferred, not measured:** that the sub-pixel `0.999` placement E2 produces is harmless — the magnification filter is nearest, but no sharpness measurement was taken. **What would overturn it:** a displacement-based instrument (not a band threshold) showing the frame-14 shrink signature is stage-1-introduced rather than pre-existing — C36 measured it before stage 1 existed. |
| C41 | **The hosting-layer battery is green on the stage-1 module, and its M1 mutant cannot discriminate what it claims to** — removing the D1 per-child refresh does not stop a moved child's layer following, because the root's full pass still covers it | `PARTIAL` | `scripts/hosting-layer-tests.sh --mutants` on module `2a251a4b2510fb84`, Steam store page, run `~/cs2-patch/hosting-layer-tests/t5b-20260903-210339`. **This is the second run of the evening**: the first (`t5-20260903-205113`) is superseded — its M1 row measured an unmutated module (stale anchor, ungated `mutate`), its GPU-crash count anchored on the first marker in an accumulating log, and its T2 restore delta was page-content noise. All three fixed in `0a8a731`/`d1ee300` | **Battery green:** T0 PASS (disjoint), T1 GREEN, T2 restacked and restored (**delta 8**, at the `<= 8` bound — the first run's 28 was the store page's own moving content between two captures, which is why T1 uses the Library), T3/T4 **0 bright edges at all three sizes** with interiors lit (125/63, 126/89, 100/47), churn **0 gaps**, static **0 gaps and 0/40 exposed edges**, `paint order incomplete` **0**, `acquire_metal_swapchain FAILED` **0**, **GPU crashes 0**, tree modified 0. The churn's 14/40 exposed-edge frames are issue #7's own residual, not a battery failure. **Mutants: M2 green (`06f7e7dbb9ce`), M3 red (`d0f26ff18c70`, 1 `paint order incomplete`), M1 APPLIED AND STILL GREEN (`ee653585b893`).** M1 is the finding: with the D1 call removed, `update_remote_layer_frame_for` fires **0** times and `update_remote_layer_frames` — the root's full pass — still fires **126**, placing the moved child at its new origin (`frame (120,0)-(2040,1050)`). **Inferred:** D1 is an optimisation that avoids an O(n) full pass, not the only path by which a moved child's layer follows, so "remove D1 → the layer must stop following" is not a property D1 has. That matches how D1 was justified in the first place — C32 established it by gap-rate A/B (9/400 → 1/480), never by a mutant. **Not measured:** whether any mutant can isolate D1 at all; the gap-rate A/B may be the only instrument that can. **What would overturn it:** a build where the root's full pass does not fire on a child-only move, in which case M1 would bind. **Superseded 2026-09-04 by [[C44]]** — M1 was rewritten to revert D1 rather than delete it, and now binds: clean `for=1 frames=0`, mutant `for=0 frames=2`. This row's measurement stands; its conclusion that no mutant can isolate D1 was wrong. |
| C42 | **The S4 strip is the content view's own layer in only ~1 frame in 5; the dominant source is neither a host nor that layer** — so giving the content view a background would close a minority of the defect, and stage 2's full-client stretch is not made redundant by it | `PARTIAL` | T0(b): module `38b52d6b3971d78b` (built from nested `main` via `scripts/build-winemac.sh`) with the content view's GDI surface blit suppressed and its own layer painted **cyan** at `initWithFrame:` — a fourth diagnostic colour the store page cannot contain, classified by `scripts/darkboxes.swift` as `g>=200, b>=200, r<=60`. `stage1-tests.sh DIAG=1 CHURNS=3`, Steam store page, 120 churn frames; run `~/cs2-patch/stage1-tests/t0b3-20260903-212616`. ⚠ **A first attempt is VOID and not counted**: it set the colour only inside `updateLayer`, which runs when the window's GDI surface is redrawn — and a window whose content is entirely hosted CALayers may never redraw one. It returned 0.00 % cyan in every band, where "the strip is not this layer" and "the colour was never applied" are the same reading | **15 exposed frames of 120** (an outer band >= 20 % at lum < 6, or >= 20 % cyan): **3 are the content view's layer, 12 are not.** When it is that layer it is unambiguous — `Bcyan` **100.0 %** and **93.9 %**, `Rcyan` up to **84.9 %**, with near-zero black in the same band. The other 12 are true black with **0.0 % cyan**, and their values recur exactly (R 76.9 / B 63.4, R 77.7 / B 66.7), i.e. a repeating geometry rather than page content. Static control 0/40 in the same session; green/magenta/blue all 0, as C39. **Inferred, not measured:** the 12 are the window's own backing showing in a region the content view's layer has not yet grown into — which is what "the window grew and nothing has caught up" would look like, and is consistent with S4's definition, but no measurement here separates that from any other opaque black surface below the hosts. **Consequence for stage 2:** §9's cheap alternative — give the content view's layer a sensible background instead of stretching full-client hosts — would address **3 of 15** exposed frames on this fixture. Worth doing, not sufficient. **What would overturn it:** a run where the 12 take a colour applied to the window's backing or to the layer tree beneath the content view, which would name the real source. |
| C43 | **Stage 2 is built and contained: the live-resize stretch cannot fire on a programmatic resize** — its only measurement is a live drag, which is why the three drags cannot be automated away | `PARTIAL` | Nested `core` +2 (`55f0805` the stretch · `c96547f` the decline trace), `main` rebuilt as aquadran → core → glue (`a5e0d03`); all three generator invariants green, reference patches regenerated; compiles with 0 errors and no new `window.c` warnings. Modules built via `scripts/build-winemac.sh` from `main`: **prod `ef82ef17f4ef5516`** (T3) · **diag-fix `86efd83b755de109`** (T2b) · diag-pre = stage 1 + colours `50fdfe79898dac36` (T0). T10 guard run as `stage1-tests.sh CHURNS=3` on the prod module, store page, 120 churn frames; run `~/cs2-patch/stage1-tests/s2-smoke-20260903-223739` | **T10 GREEN.** Across 120 churn frames and **3021 placement traces**: `stretched … (live resize)` **0**, and the new decline trace `not full-client` **0** as well — so `in_live_resize` is never set by a `SetWindowPos` resize and the substitution branch is not merely declining, it is never entered. Churn is statistically unchanged from stage 1 (right band 14 · 9 · 9 per 40 against stage 1's 8 · 9 · 12; bottom 12 · 9 · 9), static control **0/40**, `t6-scale-at-rest.py` **PASS**, `placement-invariants.py` **PASS** (0 sub-pixel placements, 0 hosts moved). Boot `VERDICT: PASS` — MainMenu reached, graceful exit, 0 `InvalidProgramException`, 16 mod logs, no crash marker. **Not measured — and not measurable this way:** whether the stretch closes the S4 strip. A churn is not a live resize, so every number here is stage 1's; stage 2's effect exists only under a real mouse drag (T2b/T3). **A risk closed before the drags:** the substitution compares a child rect from `MDT_RAW_DPI` window queries against `data->rects`, documented as monitor DPI (`macdrv.h:185`), and retina is profile-conditional here — if the spaces differ, `EqualRect` never matches and stage 2 does nothing *silently*, which after a drag would read as the fix not helping. The decline trace makes that case legible; the first build lacked it and was rebuilt. **What would overturn it:** a churn showing a stretch trace, which would mean the live-resize guard leaks into programmatic resizes. |
| C44 | **D1's benefit is a call SHAPE, and it is now measurable: a child's own move costs one targeted reposition, not a full pass over every layer on the root** — the pixel test that used to stand for this could never fail | `SUPPORTED` | `scripts/hosting-layer-tests.sh --mutants`, module `ef82ef17f4ef5516` (nested `main`, stage 2), Steam **Library** page; run `~/cs2-patch/hosting-layer-tests/m1fix2-20260904-164813`. M1 rewritten (`d5bb4fb`) to **revert** D1 — the child path calls `update_remote_layer_frames(data, NULL)` again, which is literally what D1's commit `eddf167` replaced — rather than delete the call. New helper `d1_call_shape` moves one hosted child by +120 px and counts the traces emitted after a log high-water mark | **Both sides measured in one session and they flip.** Clean: **`for=1 frames=0`** — one `update_remote_layer_frame_for`, zero full passes. Under M1: **`for=0 frames=2`** — no targeted call and one full pass per hosted child, which is the O(n) cost D1 exists to remove. M2 green, M3 red (1 `paint order incomplete`), T0 disjoint, T1 GREEN, 0 GPU crashes, tree modified 0. **Inferred, not measured:** that the 2 full passes would scale with child count — the store page has two hosted children and this ran on the library; the shape is what was measured, not a curve. **Why the old M1 could not bind ([[C41]], #10):** it deleted the call and asserted the layer would stop following, which the root's own `WindowPosChanged` full pass makes false — measured at `_for` 0 / `_frames` 126 with T1 still GREEN. A pixel test cannot separate the two mechanisms because both put the layer in the right place. **What would overturn it:** a clean build showing `frames>0` after a child-only move, which would mean something else is still running the full pass on that path. |
| C45 | **Stage 1 leaves hosted layers scaled after a live drag ends, and no churn can show it** — plus stage 2's z-order premise verified: the full-client browser sits BELOW the page | `PARTIAL` | First live drag of issue #7, `scripts/drag-session.sh t0`, diag-pre module `50fdfe79898dac36` (stage 1 + colours), Steam store page, window 1853x994; run `~/cs2-patch/drag/t0-20260904-172306`. 60 frames sampled across **49 distinct window sizes** (30 grow steps, 26 shrink), width-only — the height never left 994, so the drag script's top-edge segment did not happen | **T6 FAIL, and it is a real defect stage 1 has.** Two surviving full-width hosts left at `scale 1.000,1.003` (ctx 1787525808, creation 1782x991) and `1.000,1.004` (ctx 1636755610, creation 1782x848) after the drag ended, never returning to identity. The cause is read from the code, not inferred: on stage 1 `macdrv_window_resize_ended` is `TRACE` + `send_message(hwnd, WM_EXITSIZEMOVE, 0, 0)` and nothing else — **nothing re-derives the hosts when a drag ends**, and the last two placements come from D1's per-child path (`update_remote_layer_frame_for`), which leaves the fractional scale in place. **Every churn run passed T6** (C39, C41, C43) because a programmatic resize ends with the root's full pass at identity; only a live drag ends on D1. This is exactly the gap stage 2's `macdrv_window_resize_ended` re-derive closes, so **t2b carries a falsifiable prediction: T6 should PASS on stage 2 where it FAILED here.** **Z-order, which gates stage 2's design (§4.2b):** the full-client host `0x2012a` (creation 1782x991, frame (0,0)-(1782,991)) is at **zpos 2**; the inset page `0x1013e` (creation 1782x848, frame (1,92)-(1781,940)) is at **zpos 5**. The browser is BELOW the page, which is the condition the plan requires — stretching it cannot smear over the page. **Attribution is thin and not a result:** 1 exposed-edge frame of 60 (right band 29 %, S4, GREEN/MAGENTA/BLUE all 0), against C35's 19/60 baseline — but that baseline was a different window size and a sustained outward pull, where this drag oscillated between 1561 and 1852 px wide and ended near where it started. **No claim is made here that stage 1 reduced the strip on a live drag**; that needs a grow-dominant drag. **What would overturn the T6 half:** a live drag on stage 1 whose surviving hosts all end at identity, which would mean something else re-derives them. **Amended 2026-09-05 — the T6 half is RETRACTED as a scorer artifact ([[C49]]):** the overturning observation was in this run's own trace. Both "survivors" were superseded by CEF's final re-create after the loop ended — 1787525808 retired for 2821022660 at trace line 185958, 1636755610 for 470972771 at 185978 — 42 and 62 lines after the last placement, which is where `t6-scale-at-rest.py` stopped counting deaths; re-scored, **T6 PASS**. Kept: the hosts ARE at 1.003/1.004 when the loop ends, because stage 1 has no end-of-drag re-derive (the code fact stands), and the z-order half. Withdrawn: "never returning to identity", and t2b's prediction, which was testing an artifact. |
| C46 | **Stage 2 cannot work on this stack: the AppKit live-resize signal both of its halves depend on is never set.** `in_resize` has never been 1 in any session ever captured | `SUPPORTED` | T2b, `scripts/drag-session.sh t2b`, diag-fix module `86efd83b755de109` (stage 2 + colours), Steam store page, real mouse drag; run `~/cs2-patch/drag/t2b-20260904-172841`. 60 frames across **34 distinct window sizes**, so the drag unquestionably resized the window. Counts taken over every `stdout.txt` under `~/cs2-patch/drag/` and `~/cs2-patch/stage1-tests/` | **`in_resize 1`: 0. `in_resize 0`: 8838.** Never set, in any churn or either live drag. Consequently `stage-2 stretches fired: 0` during a genuine drag, and the decline trace I added for the DPI-mismatch risk reads **0** as well — the substitution branch was never even reached, so this is upstream of every risk that was guarded. **`WINDOW_RESIZE_ENDED` has also never fired (0, ever)**, which independently kills stage 2's other half: T6 still FAILS on the stage-2 module (hosts left at `1.000,1.005` and `1.000,1.004`) for the same reason it failed on stage 1 ([[C45]]) — the end-of-drag re-derive hangs off `windowDidEndLiveResize:`, which never runs. Both halves of stage 2 are dead code here. **The plan's premise (§4.2b, first sentence) is wrong in the way that matters:** *"the live-resize signal already exists in stock and needs no new observation"* is true of the CODE — `windowDidResize:` really does pass `resizing:[self inLiveResize]` (`cocoa_window.m:3352`) and `macdrv_cocoa.h:400` really does carry the field — and false of the RUNTIME. It was verified by reading the declaration, never by measuring the value. **Inferred, not measured:** that Steam, an `SDL_app`, resizes itself through Win32 in response to its own mouse handling, so wine calls `setFrame:` programmatically and AppKit's live-resize loop never engages — which would make `[self inLiveResize]` legitimately false. The mechanism is untested; only the absence of the flag is measured. **What would overturn it:** any session where `in_resize 1` appears, which would mean the signal exists and something about these drags failed to trigger it. **→ [[C47]]** measures the mechanism inferred here: the drags run win32u's own size loop, and that loop's capture flag is the signal stage 2 was rebuilt on. **Amended 2026-09-05:** the "T6 still FAILS" sentence was the same scorer artifact as C45's ([[C49]]) — 1859420888 and 1578949999 were superseded 42 and 63 lines after the last placement by CEF's re-create; re-scored **T6 PASS**. The claim does not rest on it: `WINDOW_RESIZE_ENDED` **0** stands on its own count, and the re-derive that hung off it still never ran. |
| C47 | **The resize signal that exists here is win32u's own size loop, and it is measured: `GUI_INMOVESIZE` on every poll of a synthetic drag, the driver handed both ends** — so stage 2 can be armed on it, and a drag no longer needs a hand | `SUPPORTED` | `win-resize-driver.exe sizedrag` (new verb, driver `668361dfc8d2f029`): presses 2 px inside the window's own resize border, moves the cursor with `SetCursorPos` (wineserver queues a `WM_MOUSEMOVE` per placement, `server/queue.c:561`), releases, and between steps polls `GetGUIThreadInfo` on the window's thread — the shared input state win32u publishes (`message.c:2292-2316`). `DRAG=synth scripts/drag-session.sh s1`, the stage-1 daily driver `2a251a4b2510fb84` (no stage-2 code), `+err,+macdrv,+cursor`, store page; runs `~/cs2-patch/drag/s1-20260904-184917` (2 px / 60 ms, pre-sized 1400x900) and `s1-20260904-185442` (1 px / 16 ms, pre-sized 1400x700 and moved down 150 px). Read against the code path in `win32u/defwnd.c:676-903` (`sys_command_size_move`) | **Measured.** Right-edge drag: `GUI_INMOVESIZE` set on **150 of 150** and **300 of 300** polls, `hwndMoveSize` = the Steam root `0x30122`, flags **0x0** after release; window 1400→1700 and 1400→1697. Trace, in order: `macdrv_SysCommand 0x30122, f002` → `macdrv_SetCapture hwnd 0x30122 flags 0x00000002 previous 0x0` … `macdrv_SetCapture hwnd 0x0 flags 0x00000002 previous 0x30122`; the top segment the same with `f003`. That is `defwnd.c:781` and `:896` reaching `mouse.c:686` through `input.c:2003`, each end once per segment. `in_resize 1`: **0** again, in 125 frame-changed events. **The top edge:** the first run's top segment ran its loop (**100 of 100** polls) and **the size did not change** — the window sits flush under the menu bar and the loop clamps the cursor to the work area (`defwnd.c:830-841`), which is also why neither human drag ever changed the height (C45, C46); with the window moved down 150 px first the top drag grows 700→850 (150 of 150). **Not reproduced: the strip.** On stage 1 both cadences score **R 0/60** (worst 4 %), against 1/60 by hand (C45) and 19/60 before stage 1 (C35) — so at these cadences the synthetic drag instruments the *mechanism* (is the pass armed, do stretches fire, does the end re-derive run) and not yet the strip; a coarser cadence is untested. **Inferred, not measured:** that a hand's burstier event stream is what exposes S4 on stage 1. **What would overturn it:** a run in which `GUI_INMOVESIZE` reads 0 while the window is being resized by a drag — a path other than `sys_command_size_move` resizing it. **Amended 2026-09-05:** the coarser cadence is now tested — [[C50]]: from 8 px / 16 ms upward the synthetic drag reproduces the strip on the pre-stage-1 baseline, so the zero on stage 1 at 1 px / 16 ms was the cadence, not the module. |
| C48 | **Both of stage 2's controls now bind: silencing the size loop kills the stretch, dropping the guard makes a churn stretch** — the fix is armed by the signal and contained by the guard, each shown by a mutant observed red | `SUPPORTED` | `scripts/stage2-tests.sh`, five rows, all on the GATED modules (prod `s2b` `00ac32aa3115b455` · diag `s2b-diag` `7bdfcd9c1746f483` · E4′ `s2b-sigoff` `0ee4dd26d4e1f0c3` · E4 `s2b-sigon` `d5cbe3121f9654c6`), Steam store page; run `~/cs2-patch/stage2-tests/20260904-191349`. Synthetic drags via `sizedrag` (1 px / 16 ms, 300 px right then 150 px up); churns via `stage1-tests.sh CHURNS=1`. ⚠ A FIRST battery (`20260904-185755`) is **not counted**: its modules were rebuilt underneath it mid-run and one row died on an edit-during-read, so no row can say which build it measured | **E4′ (S-C) RED as designed:** with `in_size_move_loop` returning FALSE, `loop=1` on **0** passes, `loop=0` on **2082**, and **0 stretches** across a drag of 47 distinct sizes — silence the signal and stage 2 does nothing, which is what makes S-A/S-B's stretches attributable to the loop. **E4 (S-E) RED as designed:** with the arming guard dropped, a `SetWindowPos` churn — which never enters the loop (`loop=1` 0, `loop=0` 331, `SysCommand SC_SIZE` **0**) — stretches **291** times and declines 286. **T10 (S-D) GREEN:** the same churn on unmutated prod stretches **0**. So the guard is what contains it, not the fixture. **The hwndMoveSize pairing works and narrows correctly:** prod's drag now fires **12** stretches and diag's **66**, against **2148** on the pre-pairing build where 12 of Steam's popup roots each took a full armed pass per step (`07cd84d`). **Not concluded — two rows need a re-run.** S-A sampled a drag of only **4** distinct sizes (the probe armed late), so its 2/60 exposed frames and its **T6 FAIL** (1 surviving context off identity, `size_move_ended` 1 where 2 segments ran) are not interpretable as stage-2 results; S-B's drag was healthier (24 sizes, 1/60 exposed, all right-band colours 0). **Inferred, not measured:** that the T6 FAIL is the late-arming drag rather than a defect in the end-of-loop re-derive. **What would overturn it:** a clean-drag re-run of S-A showing the same T6 FAIL, which would mean `macdrv_size_move_ended` does not re-derive every host. **Amended 2026-09-05 — both open rows are closed, and S-A's cause was misread.** The probe armed on time; the **right-edge press never took**: 66 of 300 polls flagged, then 0, size 1400x700 throughout, and the root received **no size step at all** in that segment (one `181f` no-op sync, against 11 steps in the top segment that worked). The only event inside it is `macdrv_app_activated` ~300 trace lines in, followed by the app's own `SetCapture(hwnd)` with no flags and `ReleaseCapture` (`+cursor`: `flags 0x00000000 previous 0x1011e`, then `hwnd 0x0`), which is what clears `GUI_INMOVESIZE`; the loop's own release then carried `previous 0x0`, so the pairing correctly declined the re-derive — 1 of 2 was right. The human t2b drag's first press has the same signature (`app_activated` on the next line, no size step, re-grabbed 148 lines later; traced without `+cursor`, so the capture pair is unobservable there). **Inferred, not measured:** what activated the app mid-drag; the harness now re-presses once on `DID NOT TAKE`, as a hand re-grabs. **Re-run 2026-09-05, prod `s2b`, `~/cs2-patch/stage2-tests/20260905-001933` (`+timestamp`):** both presses took first time (1400→1698, 700→849; 300/300 and 150/150 polls), `app_activated` 0; the probe sampled **49 distinct sizes**; **EXPOSED 0/60, worst band 5 %**, GAPS 0, L/R/T/B 0/60 each; root passes read the loop **1956 / 87**; **163 stretches, 163 declines, re-derives 2 of 2**; **T6 PASS**, the two scaled hosts superseded **6–9 ms** after the last placement. The first battery's S-A/S-B T6 FAILs were the scorer artifact ([[C49]]); S-B's own drag (24 sizes, 1/60 exposed, colours 0) stands. ⚠ 0/60 at this cadence is the mechanism running clean, not exposure measured — a synthetic 1 px / 16 ms drag shows no strip on any module ([[C47]]); T3's human verdict remains the acceptance test. |
| C49 | **T6 never failed: every "residual scale at rest" was the scorer stopping one settle short** — at the loop's end the full-client hosts sit scaled (1.003–1.035) until CEF's final re-create lands, and it lands within tens of milliseconds | `SUPPORTED` | `scripts/t6-scale-at-rest.py` re-read against the four failing traces — `exp_f17638` (t0, C45), `exp_73ca27` (t2b, C46), `exp_7bff13` / `exp_dcec62` (S-A / S-B of `stage2-tests/20260904-191349`, C48) — and the timed re-run `exp_94ec40` (prod `s2b` `00ac32aa3115b455`, synthetic 1 px / 16 ms, `+timestamp`; run `~/cs2-patch/stage2-tests/20260905-000838`, captures VOID by the screen lock, trace intact) | **Measured.** In all four FAILs the "survivor" was superseded by CEF's re-create **after** the scorer's cut: the cut was the last placement trace, the CREATE handler traces `layer frame in root` and never a placement, and the retire landed **21–65 lines** later with its replacement created three lines before it (t0: 1787525808 → 2821022660, 1636755610 → 470972771 · t2b: 1859420888 → 1391563343, 1578949999 → 912507821 · S-A: 4156318113 → 3515853278 · S-B: 751766390 → 1942061674, 889203799 → 2187145352). Re-scored with the supersede rule — a retire-by-supersede counts whenever it occurs, a RELEASE only up to the cut, so teardown cannot pardon a stuck host — **PASS ×4**; the two runs that already passed are unchanged. Timed on the re-run: loop end `63612.555`, the end-of-loop re-derive places three hosts at 1.006–1.016, CEF's replacements land at `63612.606`–`.643`, **51–88 ms after the loop end**, and every survivor is identity by the next root pass at `63614.268`; T6 PASS with no supersede needed past the cut. Both presses took first time, `macdrv_app_activated` 0, re-derives 2 of 2. **Inferred, not measured:** that 51–88 ms is typical — one timed drag; the scorer now prints the delay on every run and a supersede later than 3 s counts as a survivor. **What survives of C45/C46:** the measurement (hosts ARE scaled at the loop's end; stage 1 has no end-of-drag re-derive, stage 2 runs one) and the z-order half; withdrawn is "never returning to identity" and the prediction that t2b would flip it. **What would overturn it:** a timed trace with a scaled host and no supersede within 3 s of its last placement. |
| C50 | **A synthetic drag reproduces the growing-edge strip once its steps outrun the child's re-create, and on that instrument stage 1 reduces the strip at every cadence** — 8 px / 16 ms, 25 px / 120 ms and 50 px / 200 ms all show it on the pre-stage-1 baseline; 1 px / 16 ms never did on anything | `SUPPORTED` | `drag-session.sh DRAG=synth` with `SYNTH_PX` / `SYNTH_MS`, `SYNTH_REPEAT=3`, `SYNTH_PAUSE=3`, `PRESIZE=1000x650`, right edge +650 px ×3 then top −350; Steam store page; `band-counts.py` (its growing-frame line was added the same night). Cells: baseline `cd79fc463795939f` — `exp_5e29fc` (8/16), `exp_1f0a17` (25/120), `exp_e99836` (50/200) · stage 1 `2a251a4b2510fb84` — `exp_d5fd29` (8/16), `exp_405b45` + `exp_706825` (25/120), `exp_9cc85a` (50/200) · stage 2 `00ac32aa3115b455` — `exp_e5a2a7` + `exp_11a2a3` (25/120), `exp_1fa790` (S-A, 1/16) · stage 2 diag `7bdfcd9c1746f483` — `exp_4b7464` (25/120). Run dirs `~/cs2-patch/drag/k1…k10-*`, frames kept | **Measured — right band ≥ 20 % true black, of 60:** baseline **2 · 4 · 3** at 8/16 · 25/120 · 50/200; stage 1 **0 · 0 (×2) · 0**; stage 2 **1 (×2)** at 25/120, and both of those are the black full-client frame of [[C51]], not a strip. **The finer metric — right band mean / max over GROWING frames (n growing):** baseline 16.5 / 27.4 (6) · 11.6 / 47.8 (13) · 8.3 / 30.1 (8); stage 1 6.6 / 15.9 (6) · 5.4 / 18.2 (15) and 1.4 / 1.7 (15) · 1.4 / 1.7 (8); stage 2 5.2 / 22.9 (13) and 2.8 / 23.0 (16); stage 2 diag 4.3 / 26.6 (12), its one ≥ 20 % frame **black with no colour** (S4 — nothing hosting the area; green, magenta and blue all 0); S-A at 1/16 on stage 2: 1.8 / 2.9 (31). Frames looked at: on the baseline at 25/120 the chrome, page and footer all stop ~75 px short of the window's edge with black beyond; on stage 1 the same strip ~27 px wide. Every press took first time (0 re-presses in 10 runs) once the window stayed under ~1700 px and presses were 3 s apart; the first K1 (`exp_7855af`, captures VOID by the lock) had a shrink take 8 px and two grows not take at all from 1868 px on a 1920 px display. **The probe's 60 captures span 8–9 s** (0.13–0.15 s each), so at these cadences they cover the first grow segment and part of the first shrink; the ×3 repeats fall outside the window. **Inferred, not measured:** that stage 2 adds nothing over stage 1 on this instrument — 5.2 / 2.8 against 5.4 / 1.4 at n = 2 sits inside the run-to-run spread, so the two are *not separable here*, which is not the same as equal; and that stage 1's residual at 25/120 (one step plus lag) is the S4 the churn A/B measured ([[C38]]). **Not a substitute for T3:** the hand's 19/60 on the baseline ([[C35]]) is still four times this instrument's best, and only a hand has seen the strip on stage 1. **What would overturn it:** a baseline run at a coarse cadence with no growing-frame exposure, or a stage-1 run scoring above the baseline at the same cadence. |
| C51 | **Stage 2 shows a one-capture black full-client host mid-drag on the coarse synthetic drag — 2 of 3 stage-2 runs, 0 of 7 stage-1 and baseline runs** — chrome, footer and margins black while the inset page is complete at the new width | `SUPPORTED` | prod `s2b` `00ac32aa3115b455`, 25 px / 120 ms, cells `exp_e5a2a7` (frame f18, 1660x650 — the last step of the first grow) and `exp_11a2a3` (f14, 1560x650 — mid-grow); the diag build `exp_4b7464` and every stage-1 / baseline run of [[C50]] had none (top band worst ≤ 5 %). Traces `+timestamp`; frames kept in the run dirs | **Measured:** in each, one frame with the top band **100 %** true black, bottom 78–79 %, left 22 %, right 23 %, interior lit (GAPS 0): the full-client child's host draws nothing while the page host (a separate child, zpos 5) is intact and already at the new width. Looked at: `k5 f18`, `k9 f14`. Aligned to the trace by the driver's wall stamp against the first `SysCommand f002` (±150 ms): in the ~100 ms before each capture the root pass **stretched** the full-client child (`stretched (0,0)-(1610,650) -> (0,0)-(1635,650)`) and ~22 ms later CEF **re-created** it (`RELEASE` of the generation before, `CREATE` of the next, `retire_superseded_layers` of the current). T6 PASS in both runs; `macdrv_size_move_ended` 6 of 6 segments. **Inferred, not measured — two candidate mechanisms:** (a) a display gap: the stretched host is retired at its replacement's CREATE and the replacement has not presented yet, so the content view's black shows for a frame — but that retire-on-create sequence runs on stage 1 too, which never showed it, so the stretch (a transform on the host) would have to lengthen or expose the gap; (b) a capture artifact: `screencapture -l` missing a remote layer that carries a non-identity transform at the instant of the window server's commit, invisible to a user. Nothing here separates them; **T3's eyes do** (a black flash of the chrome during a hand drag = display), or a full-screen capture at the same instant. **Consequence:** the stage-2 module stays out of the daily driver until this is understood, and T2b / T3 read the **top** band too — a right-band-only reading would have filed this as a 23 % strip. **What would overturn it:** three further prod runs at 25 / 120 with none (chance at 2 of 3), or the same frame on stage 1. |

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
| exp_eb78a3 | 2026-08-30 23:11 | `proton-off` | 0 | 0 | 0 | black | candidate |
| exp_8d675d | 2026-08-30 23:50 | `notpop-fork-fonts-fixed` | 0 | 0 | 0 | black | candidate |
| exp_090ec5 | 2026-08-30 23:52 | `fork-seh` | 0 | 0 | 0 | black | candidate |
| exp_2ded9b | 2026-08-31 00:25 | `fork-abi-matched` | 0 | 0 | 0 | black | candidate |
| exp_71d767 | 2026-08-31 00:53 | `nullcheck-getwindata` | 0 | 0 | 0 | black | candidate |
| exp_5481ff | 2026-08-31 00:55 | `nullcheck-seh` | 0 | 0 | 0 | black | candidate |
| exp_b8d3a1 | 2026-08-31 01:13 | `winddata-diag` | 0 | 0 | 0 | black | candidate |
| exp_b2fdea | 2026-08-31 02:08 | `remote-layer-wired` | 0 | 0 | 0 | rendered | candidate |
| exp_d5ea1a | 2026-08-31 02:11 | `isolate-stockdxmt` | 0 | 0 | 0 | black | candidate |
| exp_e43611 | 2026-08-31 02:13 | `remote-confirmed` | 0 | 0 | 0 | rendered | candidate |
| exp_1ee1a5 | 2026-08-31 02:28 | `geometry-mapped` | 0 | 0 | 0 | rendered | candidate |
| exp_b72adf | 2026-08-31 02:31 | `geom-diag` | 0 | 0 | 0 | rendered | candidate |
| exp_6d89af | 2026-08-31 02:34 | `geom-points` | 0 | 0 | 0 | rendered | candidate |
| exp_fc9497 | 2026-08-31 02:57 | `leak-fixed` | 0 | 0 | 0 | rendered | candidate |
| exp_5e2e93 | 2026-08-31 02:59 | `leak-measured` | 0 | 0 | 0 | rendered | candidate |
| exp_3a34f1 | 2026-08-31 03:02 | `deferred-release` | 0 | 0 | 0 | rendered | candidate |
| exp_8002c1 | 2026-08-31 03:42 | `resize-diag` | 0 | 0 | 0 | rendered | candidate |
| exp_f9c0fb | 2026-08-31 03:49 | `resize-fix` | 0 | 0 | 0 | rendered | candidate |
| exp_cd86e0 | 2026-08-31 03:52 | `resize-final` | 0 | 0 | 0 | rendered | candidate |
| exp_c40e9c | 2026-08-31 03:55 | `resize-ship` | 0 | 0 | 0 | rendered | candidate |
| exp_9b5030 | 2026-09-02 15:57 | `audit-fix` | 0 | 0 | 0 | rendered | candidate |
| exp_2e93af | 2026-09-02 16:02 | `audit-fix2` | 0 | 0 | 0 | rendered | candidate |
| exp_a879f0 | 2026-09-02 16:05 | `audit-fix3` | 0 | 0 | 0 | rendered | candidate |
| exp_519eef | 2026-09-02 21:55 | `core-nav` | 0 | 0 | 0 | rendered | candidate |
| exp_1da98c | 2026-09-02 21:57 | `core-geom` | 0 | 0 | 0 | rendered | candidate |
| exp_37f651 | 2026-09-02 22:00 | `core-churn` | 0 | 0 | 0 | rendered | candidate |
| exp_4679e5 | 2026-09-02 22:03 | `core-churn2` | 0 | 0 | 0 | rendered | candidate |
| exp_c9e172 | 2026-09-03 00:39 | `ab-pre` | 0 | 0 | 0 | rendered | candidate |
| exp_3b68a9 | 2026-09-03 00:44 | `ab-post` | 0 | 0 | 0 | rendered | candidate |
| exp_22687c | 2026-09-03 00:50 | `ab2-pre` | 0 | 0 | 0 | rendered | candidate |
| exp_842787 | 2026-09-03 00:56 | `ab2-post` | 0 | 0 | 0 | rendered | candidate |
| exp_b9f791 | 2026-09-03 01:03 | `iso-d1off` | 0 | 0 | 0 | rendered | candidate |
| exp_a09b6a | 2026-09-03 01:16 | `ab3-post` | 0 | 0 | 0 | rendered | candidate |
| exp_5807b7 | 2026-09-03 06:39 | `dxm-green` | 0 | 0 | 0 | rendered | candidate |
| exp_eee158 | 2026-09-03 06:41 | `dxm-t3` | 0 | 0 | 0 | black | candidate |
| exp_6b0c84 | 2026-09-03 06:42 | `dxm-t3b` | 0 | 0 | 0 | black | candidate |
| exp_78c961 | 2026-09-03 06:44 | `dxm-t4` | 0 | 0 | 0 | rendered | candidate |
| exp_4deb41 | 2026-09-03 06:46 | `dxm-t4b` | 0 | 0 | 0 | black | candidate |
| exp_9e8d92 | 2026-09-03 08:12 | `livedrag-setup` | 0 | 0 | 0 | rendered | candidate |
| exp_44fe1c | 2026-09-03 15:01 | `livedrag` | 0 | 0 | 0 | rendered | candidate |
| exp_f94279 | 2026-09-03 16:27 | `livedrag-setup2` | 0 | 0 | 0 | rendered | candidate |
| exp_3a9834 | 2026-09-03 16:38 | `livedrag-setup3` | 0 | 0 | 0 | rendered | candidate |
| exp_5c988e | 2026-09-03 16:51 | `edge-post` | 0 | 0 | 0 | rendered | candidate |
| exp_88f348 | 2026-09-03 16:53 | `edge-pre` | 0 | 0 | 0 | rendered | candidate |
| exp_8e5043 | 2026-09-03 17:09 | `m0-colour` | 0 | 0 | 0 | rendered | candidate |
| exp_974d1b | 2026-09-03 17:14 | `m0b-colour` | 0 | 0 | 0 | rendered | candidate |
| exp_374ae7 | 2026-09-03 17:45 | `classbg` | 0 | 0 | 0 | rendered | candidate |
| exp_5c1a70 | 2026-09-03 18:36 | `t1-before` | 0 | 0 | 0 | rendered | candidate |
| exp_e42b19 | 2026-09-03 18:38 | `t1-after` | 0 | 0 | 0 | rendered | candidate |
| exp_7d0f4c | 2026-09-03 20:00 | `stage1` | 0 | 0 | 0 | rendered | candidate |
| exp_4f5478 | 2026-09-03 20:06 | `stage1-ctrl-prod-20260903-200515` | 0 | 0 | 0 | rendered | candidate |
| exp_aa3654 | 2026-09-03 20:10 | `stage1-t2a-diagfix2-20260903-200851` | 0 | 0 | 0 | black | candidate |
| exp_51334e | 2026-09-03 20:16 | `stage1-t2a-20260903-201503` | 0 | 0 | 0 | rendered | candidate |
| exp_f0d8a4 | 2026-09-03 20:21 | `stage1-e1-mutant-20260903-201954` | 0 | 0 | 0 | rendered | candidate |
| exp_796397 | 2026-09-03 20:25 | `stage1-t7-20260903-202411` | 0 | 0 | 0 | rendered | candidate |
| exp_0b256d | 2026-09-03 20:28 | `stage1-e5-mutant-20260903-202411` | 0 | 0 | 0 | black | candidate |
| exp_9f018e | 2026-09-03 20:31 | `stage1-e2-mutant-20260903-202411` | 0 | 0 | 0 | rendered | candidate |
| exp_ad5977 | 2026-09-03 20:34 | `stage1-e3-mutant-20260903-202411` | 0 | 0 | 0 | rendered | candidate |
| exp_263429 | 2026-09-04 16:49 | `main` | 0 | 0 | 0 | rendered | candidate |
| exp_f3f3e6 | 2026-09-04 16:53 | `m1` | 0 | 0 | 0 | rendered | candidate |
| exp_75d3fb | 2026-09-04 16:55 | `m2` | 0 | 0 | 0 | rendered | candidate |
| exp_9c51be | 2026-09-04 16:57 | `m3` | 0 | 0 | 0 | rendered | candidate |
| exp_bd2870 | 2026-09-04 16:59 | `green` | 0 | 0 | 0 | rendered | candidate |
| exp_f17638 | 2026-09-04 17:24 | `drag-t0-t0-20260904-172306` | 0 | 0 | 0 | rendered | candidate |
| exp_73ca27 | 2026-09-04 17:30 | `drag-t2b-t2b-20260904-172841` | 0 | 0 | 0 | rendered | candidate |
| exp_ec6ec8 | 2026-09-04 18:50 | `drag-s1-s1-20260904-184917` | 0 | 0 | 0 | rendered | candidate |
| exp_4473d4 | 2026-09-04 18:56 | `drag-s1-s1-20260904-185442` | 0 | 0 | 0 | rendered | candidate |
| exp_3dfdb9 | 2026-09-04 18:59 | `drag-t3-S-A-20260904-185755` | 0 | 0 | 0 | rendered | candidate |
| exp_247867 | 2026-09-04 19:01 | `drag-t2b-S-B-20260904-185755` | 0 | 0 | 0 | rendered | candidate |
| exp_6f2fc1 | 2026-09-04 19:04 | `drag-t3-S-C-20260904-185755` | 0 | 0 | 0 | rendered | candidate |
| exp_7dbaad | 2026-09-04 19:06 | `stage1-S-D-20260904-185755` | 0 | 0 | 0 | rendered | candidate |
| exp_aacd71 | 2026-09-04 19:09 | `stage1-S-E-20260904-185755` | 0 | 0 | 0 | rendered | candidate |
| exp_7bff13 | 2026-09-04 19:15 | `drag-t3-S-A-20260904-191349` | 0 | 0 | 0 | rendered | candidate |
| exp_dcec62 | 2026-09-04 19:18 | `drag-t2b-S-B-20260904-191349` | 0 | 0 | 0 | rendered | candidate |
| exp_759055 | 2026-09-04 19:21 | `drag-t3-S-C-20260904-191349` | 0 | 0 | 0 | rendered | candidate |
| exp_d85b36 | 2026-09-04 19:23 | `stage1-S-D-20260904-191349` | 0 | 0 | 0 | rendered | candidate |
| exp_c032cb | 2026-09-04 19:26 | `stage1-S-E-20260904-191349` | 0 | 0 | 0 | rendered | candidate |
| exp_94ec40 | 2026-09-05 00:10 | `drag-t3-S-A-20260905-000838` | 0 | 0 | 0 | rendered | candidate |
| exp_7855af | 2026-09-05 00:12 | `drag-s1-k1-s1-8px16ms-20260905-000838` | 0 | 0 | 0 | rendered | candidate |
| exp_1fa790 | 2026-09-05 00:21 | `drag-t3-S-A-20260905-001933` | 0 | 0 | 0 | rendered | candidate |
| exp_d5fd29 | 2026-09-05 00:23 | `drag-s1-k1-s1-8px16ms-20260905-001933` | 0 | 0 | 0 | rendered | candidate |
| exp_5e29fc | 2026-09-05 00:26 | `drag-s1-k2-base-8px16ms-20260905-001933` | 0 | 0 | 0 | rendered | candidate |
| exp_405b45 | 2026-09-05 00:28 | `drag-s1-k3-s1-25px120ms-20260905-001933` | 0 | 0 | 0 | rendered | candidate |
| exp_1f0a17 | 2026-09-05 00:31 | `drag-s1-k4-base-25px120ms-20260905-001933` | 0 | 0 | 0 | rendered | candidate |
| exp_e5a2a7 | 2026-09-05 00:35 | `drag-t3-k5-s2b-25px120ms-20260905-003408` | 0 | 0 | 0 | rendered | candidate |
| exp_e99836 | 2026-09-05 00:38 | `drag-s1-k6-base-50px200ms-20260905-003408` | 0 | 0 | 0 | rendered | candidate |
| exp_9cc85a | 2026-09-05 00:41 | `drag-s1-k7-s1-50px200ms-20260905-003408` | 0 | 0 | 0 | rendered | candidate |
| exp_4b7464 | 2026-09-05 00:45 | `drag-t2b-k8-s2bdiag-25px120ms-20260905-004403` | 0 | 0 | 0 | rendered | candidate |
| exp_11a2a3 | 2026-09-05 00:48 | `drag-t3-k9-s2b-25px120ms-20260905-004403` | 0 | 0 | 0 | rendered | candidate |
| exp_706825 | 2026-09-05 00:51 | `drag-s1-k10-s1-25px120ms-20260905-004403` | 0 | 0 | 0 | rendered | candidate |

150 cells · 45 VOID-LIBS · 105 candidate
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
| `shim.log` | the webhelper shim's relaunch command line + the `SHIM_FONTPROBE` counters. **Carries a SteamID64** (`-steamid=7656119…`) and a `C:\users\<name>` cachedir, because it logs Steam's own switches verbatim | **evidence store only — never commit, never paste into an issue.** Quote the `[fontprobe]` counter line alone; that part is clean |
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
