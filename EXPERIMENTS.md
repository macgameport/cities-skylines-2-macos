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

⚠ **Still open:** `my_dxmt_acquire_remote_layer` deliberately leaks the previous client surface —
releasing it on the next acquire destroys the layer DXMT is still rendering into. Lifetime should be
driven by DXMT releasing its swapchain. That is the remaining blocker to offering this upstream.

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
| C12 | The white hairline at the right/bottom of Steam's client is a **half-point retina rounding** artifact, not a race | `SUPPORTED` | `resize-diag` vs `resize-ship` (`resize-measurements.txt` in each) | Win32 gives RAW PIXELS, Cocoa takes POINTS. An ODD pixel dimension halves to a `.5` point, and the content view is sized in WHOLE points, so the hosted layer lands exactly **one device pixel** short of the view. Measured: root 2401x1500 px → host frame 1200.5x750.0 pt in a 1201.0x750.0 pt view → capture column x=2401 reads `255,255,255` against an interior of `15,25,36`. **The axis that is odd is the axis that shows it** — 2401x1500 right only, 2400x1501 bottom only, 2400x1500 neither. Fixed by extending a hosted frame to the view's edge when it already reaches it. **3 bright-edge findings before, 0 across 20 captures after.** Overturned by: a bright edge on any even-sized capture (would mean the parity story is wrong). |
| C13 | The resize **blackout** is hosted-layer z-order, not a lifetime or surface bug | `SUPPORTED` | `resize-diag` (repro) vs `resize-fix`/`resize-ship` (fix), plus the `tree` dump | Steam's client is **two SIBLING `CefBrowserWindow` trees** on one root (`0x1013E` above `0x6012A`), not a parent and a child as their rectangles suggest. Hosted `CALayerHost`s were stacked in **creation order**, and CEF recreates a swapchain on every resize — so any resize that recreated the LOWER browser put its full-window layer on top of the content and the client went black **and stayed black**. `2400x1500 → 2399x1499 → 2400x1500` reproduced it every time (interior luminance 82 → 1 → 0); after ordering by Win32 paint order it measures 63 → 63 → 113, and 60 alternations at 60 ms end rendering. Observed live: `0x2011E → z2`, `0x10140 → z5`, independent of creation order. Overturned by: a blackout with the z-order trace showing the layers correctly ordered. |
| C14 | The **navigation** blackout is an empty (0×0) child rect being treated as "no rect supplied" and stretched over the view | `SUPPORTED` | Library-navigation trace (`-DDXMT_RSZ_DEBUG`) + a six-navigation sweep | **Found by James in ordinary use, minutes after the scripted resize suite passed clean** — the suite drove geometry and never drove content, so it could not have found this. CEF keeps an inactive browser in the z-order at **0×0**; `CGRectIsEmpty` cannot distinguish that from the root-window "no child rect" case, so the layer was stretched to the whole view, on top, with nothing drawn in it. Measured: `0x1013E/0x10140` = `0x0` exactly while black, `2598x1275` once the store view returned. **A resize does not clear it** (the update path skipped empty frames) — that is the tell separating it from C13. Trace: `HOST create ctx=2870122112 frame=0.0,0.0 0.0x0.0 (view 1300.0x780.0)` at `z5`. Fixed by testing `CGRectIsNull` before `CGRectIsEmpty` and hiding a zero-area layer. Verified: six navigations, none black, 0 GPU crashes. Overturned by: a blackout whose trace shows no empty frame. |
| C15 | Gating the **un-hide** on the frame having changed black-holed Steam's Friends List | `SUPPORTED` | Friends List trace + capture 20,420 B lum 0 → 274,680 B lum 38 | **My own regression, live ~1 hour, found by James in ordinary use.** The window briefly reports 0×0, the layer is hidden, then the frame returns to *the value it already held* — so a `!CGRectEqualToRect` guard on the whole branch skipped the un-hide permanently. Visibility and geometry are independent state; each needs its own test. Overturned by: a black popup whose trace shows `hidden = NO` already set. |
| C16 | `macdrv_swapchain_set_bounds()` is **dead code** — the claim it fixed stale strips is WITHDRAWN | `SUPPORTED` | `SURF-UPD`=0 and `CONTENT`=0 across five instrumented sessions vs 67/120/184/101 `HOST create` | Its only caller is `macdrv_client_surface_update()`'s remote-layer branch, which never fires: CEF resizes by destroying and recreating the swapchain, so the in-place path is never taken. It shipped beside two changes that DID work, the symptom improved, and the improvement was credited to all three. Kept and annotated, not credited. Overturned by: any session where that branch logs. |
| C17 | The resize **shimmer** is not our layers being stretched | `PARTIAL` | instrumented SCALE check: 0 stretch events; and the only path that could stretch is C16, which never runs | **The negative half is measured; the positive half is a hypothesis.** What the trace does show is churn — 24 scripted resize steps produced **101** `HOST create` and **83** `HOST remove` across the two browsers, so layers are constantly un-hosted and re-hosted and the window shows whatever is behind during each gap. That would explain a shimmer, and it is **untested**. Do not write it up as the cause. |
| C18 | The menu **black-box lag** is `backgroundColor` painting a hosted layer before its first frame | `SUPPORTED` | parity re-measure with the background removed, then deferred | Added the same morning to cover a 1-device-pixel seam. A `CALayerHost` is visible as soon as it is added, so the background paints the whole layer black until the remote context presents — and each Steam menu is its own popup window, so mousing across the menu bar hosts a fresh layer per menu. **Removing it is not the fix:** re-measured, the seam returns exactly on the odd axis (2400×1500 → 0 bright edges, 2401×1500 → 1, 2400×1501 → 1, 2401×1501 → 2), so it is load-bearing. Deferred by 120 ms instead: transparent while empty, black once content has arrived. Verified 0 bright edges on all four parities, popups unaffected. Overturned by: a black flash whose trace shows the background already deferred. |
| C19 | Paradox launcher hit-testing is offset vertically from the visible cursor | `PARTIAL` | James's report + `win-resize-driver rects` on the launcher window | Renders fine and the game boots from it to `MainMenu`, but you must aim above a button to hit it. Measured: the launcher's top-level `Chrome_WidgetWin_1` has a Win32 client offset of **dx=5, dy=0**, so "off by the title bar in Win32" is ruled out — yet macOS draws one. If the Cocoa content view starts lower on screen than Win32's client origin, CEF receives a client *y* that is too large and highlights a control below the cursor, which matches the reported direction. **Mechanism now measured 2026-08-31:** the content view is **642 pt** tall (from the hosted-layer trace) inside a 674 pt window — a **32 pt** macOS title bar — while Win32's client rect is 1339 px = **669.5 pt**. Widths match exactly; Win32 believes the client is **~27.5 pt taller** than the view that displays it, so a cursor maps ~28 pt too low. Magnitude matches the report. **Ownership still untested** and **ownership untested** — our edits touch layer frames/z-order/visibility only (`grep -c macgameport` over the event path = 0), and the A/B against the stock `winemac.so.bak-*` has not been run. Overturned by: the same offset on stock winemac (⇒ pre-existing, not ours). |
| C20 | The Paradox "crashed / exit code null" dialog and the `assert_*.dmp` are both benign | `SUPPORTED` | six dumps, one per run, incl. two boot-verifies that reached `MainMenu`; `SceneFlow.log` 05:39:03 → `MainMenu reached` 05:40:07 | Steam's handler writes an `assert_cities2.exe_*.dmp` on **every** launch (Mono `gpath.c:115 assertion 'filename != NULL'`), including known-good ones, so its presence proves nothing. The launcher's `exit code null` is it failing to *read* an exit code from a wine process after a run that reached `MainMenu` and shut down normally. **Every game start on 2026-08-31 reached `MainMenu`; there is no failed run in the logs.** Overturned by: a run with no `MainMenu reached` line. |
| C21 | The launcher's PLAY never starts the game — `spawn Cities2.exe ENOENT`, not a crash | `SUPPORTED` | `launcher-2026-08-31.log` (4 occurrences) + `launcher-settings.json` | `exePath` is `../Cities2.exe` and Steam passes `--gameDir ...\Cities Skylines II\Launcher`, but `Cities2.exe` is in the game **root** and what reaches `spawn` is the bare name. The "crashed / exit code null" dialog and all of its advice (verify files, disable mods, install VC++/.NET) are wrong — nothing was launched. Unrelated to the rendering patches. Workaround: the shortcut runs `Cities2.exe` directly. Overturned by: a PLAY that starts the game with the same log line present. |
| C22 | "A launcher update has failed — check your internet connection" is loopback, not internet | `SUPPORTED` | same log: `EADDRNOTAVAIL 127.0.0.1:11000` ×2, `cpatch took too long to connect` ×11; `api.paradoxplaza` 200 and Steam 200 measured host-side | The launcher talks to a helper (`cpatch.exe`) over **localhost TCP 11000** and cannot connect under wine. Cosmetic — the launcher works un-updated. Overturned by: the update succeeding while the EADDRNOTAVAIL lines are still present. |
| C23 | winemac decorates frameless windows because it reads style bits, not the client rect | `PARTIAL` | style/region/rect probe on Steam vs the launcher; before/after capture | Both windows have `WS_CAPTION`, neither is shaped or layered — so the style test cannot separate them. What does: Steam's client fills its window exactly (`dx=0 dy=0`, escapes via the existing `EqualRect(window, visible)` guard) while the launcher reserves 5px left/right/bottom and **zero on top** (`dx=5 dy=0`) — a resize border with no caption, the `WM_NCCALCSIZE` frameless pattern. Suppressing `title_bar` when `rects.client.top == rects.window.top` removes the doubled chrome, **verified visually**. ⚠ **It does NOT fix the cursor offset**: content-view vs Win32-client stays 27.5 pt apart before and after (642.0/669.5 → 643.0/670.5) — the Cocoa window shrank by the caption height instead of the content growing into it. **The change was REVERTED** — see C24: it leaves `macdrv_GetWindowStyleMasks` still reserving caption space, so the NSWindow merely moves down by it. Overturned by: a frameless window that still gets a title bar with the client-top test in place. |
| C24 | The cursor offset is window-relative, and caused by **two** functions answering "has a title bar" differently | `SUPPORTED` | bracketed `GetCursorPos` vs `CGEvent`; before/after window origins | Global mapping is **exact** (dx −0.4, dy −0.4 px — truncation), so it is not a pointer bug. `ScreenToClient` subtracts a window origin 56 px (28 pt) above where the NSWindow actually is. Cause: `macdrv_GetWindowStyleMasks` → `get_window_features_for_style()` (style bits only) tells win32u how much non-client space the window rect reserves, while `get_cocoa_window_features()` (style bits **+ `data->rects`**) decides the real Cocoa decoration. Patching only the latter left win32u still reserving caption space and merely moved the NSWindow down by it — 27.5 pt error before **and** after, so the change was reverted. A fix must make both answers share one source of truth. Overturned by: an offset that persists with the two functions provably in agreement. |
| C25 | The launcher's `spawn Cities2.exe ENOENT` is **not** a path problem | `SUPPORTED` | two PLAY attempts, the second with an absolute `exePath` | Setting `exePath` to a full absolute path **did take effect** — the launcher logged `Starting game: C:\...\Cities2.exe` — and the spawn failed identically. Node formats ENOENT with the *basename*, which is what makes it look like a bare-name lookup. The file exists, the path resolves, and plain wine launches that same exe to `MainMenu` (the shortcut does exactly that). So the fault is the launcher's own Electron/libuv spawn under wine. **The edit was reverted** — it changed no outcome and Steam would revert it on validation. Overturned by: a PLAY that succeeds after a path-only change. |

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

80 cells · 45 VOID-LIBS · 35 candidate
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
