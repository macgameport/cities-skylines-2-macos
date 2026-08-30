# dxmt#141 — fourth evidence comment (2026-08-29)

Draft reply to mikey92's "one cell is still missing" comment. Prior comments on the thread:
5400445243 (stock-vs-vendor sweep) · 5403561498 (`--in-process-gpu`: renders but textless) ·
5458926046 (vanilla-wined3d split — **its argument is retracted below; its conclusion survives on
different evidence**).

Status: **not yet posted.**

---

@mikey92 — you were right that a cell was missing, and chasing it broke my previous comment open.
Short version: **my split was wired wrong, so
[#5458926046](https://github.com/3Shain/dxmt/issues/141#issuecomment-5458926046) argued from a
D3D11 that never worked.** I've since built the test properly and run your config on it. Full
results below, plus a one-command ask that would explain the difference between our machines.

**1. The retraction.** I wired the split with soju's marker-strip technique — flip a byte in
`"Wine builtin DLL\0"` at offset `0x40` so a `native` override loads a wine-built PE — and verified
it with `+loaddll`, which duly showed `d3d11.dll … native` inside Steam's processes. That proved
the PE **loaded**. It did not prove it **worked**. A device-creation probe never reaches its first
`printf` on that wiring:

```
wine: Call from ... to unimplemented function dxgi.dll.DXGID3D10CreateDevice, aborting
```

So every Steam cell I ran against the split, on both dates, was measuring a client whose `d3d11`
aborts at `CreateDevice`. **A module load is not a working implementation** — that one's on me.

**2. So I built the test properly.** The wiring that *does* work — vanilla `d3d11`+`dxgi` as true
builtins in `lib/wine/*/`, marker intact — is engine-global, so it can't live in the wrapper that
also runs the game. It needs its own bundle. On APFS that's free: `cp -Rc` clones the 103 GB
wrapper in seconds, then swap the two builtins. Probe in that clone's own Steam prefix, self-built
stock wine 11.16, M3 Max, macOS 26.6.2:

| | adapter | `CheckInterfaceSupport(IDXGIDevice)` | max feature level |
|---|---|---|---|
| **DXMT v0.80** | Apple M3 Max | **`S_OK`** | **`0xB100` = 11_1** |
| vanilla wined3d (GL) | "NVIDIA GeForce 6800" — the fallback card | `0x887A0004` `DXGI_ERROR_UNSUPPORTED` | `0x9300` = **9_3** |
| vanilla wined3d (`renderer=vulkan`) | Apple M3 Max (correct) | `0x887A0004` | `0x9300` = **9_3** |

Feature level asked both ways — `pFeatureLevels=NULL` and an explicit `{11_1…9_3}` array — same
answer. `0x887A0004` is literally what ANGLE reports as `Renderer11.cpp:1108 Error querying driver
version from DXGI Adapter`, now measured as a plain API return rather than inferred from a log.

**3. Your config, on a genuinely working vanilla-wined3d client.** Every cell capture-judged, with
the instrument validated each time:

| client | switches | gpu children | crashes | window |
|---|---|---|---|---|
| **vanilla wined3d** | none (out-of-process) | **1** | **0** | black, 30,482 B |
| **vanilla wined3d** | none, `renderer=vulkan` | **1** | **0** | black, 30,482 B — byte-identical |
| **vanilla wined3d** | `--in-process-gpu` | 0 | 0 | **none** |
| **vanilla wined3d** | `--single-process` | 0 | 0 | **none** |
| **vanilla wined3d** | `--disable-gpu --single-process` (yours) | 0 | 0 | **none**, 174 % spin |
| DXMT | none (out-of-process) | — | **×3** | black, ~40 KB |
| DXMT | `--in-process-gpu` | 0 | 0 | renders, zero glyphs |
| DXMT | `--single-process` | 0 | 0 | **renders, 1,810,329 B**, zero glyphs |
| DXMT | `--disable-gpu --single-process` | 0 | 0 | none |

**On this machine DXMT is strictly better than vanilla wined3d at every cell** — the split isn't a
missed opportunity here, it's a downgrade. And the CEF log from a *working* vanilla client finally
makes the chain attributable end to end:

```
Renderer11.cpp (populateRenderer11DeviceCaps): Error querying driver version from DXGI Adapter.
eglCreateContext: Requested GLES version (3.0) is greater than max supported (2, 0).
eglInitialize SwANGLE failed with error EGL_NOT_INITIALIZED
Initialization of all EGL display types failed.  ->  gl_factory_win.cc(63) NOTREACHED (×1,127,264)
```

FL 9_3 lets ANGLE offer **GLES 2.0 only**; CEF asks for **3.0**; every display type then fails —
which is why the in-process modes that at least render on DXMT produce no window at all here.

**4. One row is worth more than the rest, and it partly rescues the comment I'm retracting.**
Out-of-process on vanilla wined3d, the **GPU process is healthy — one child, zero crashes** (on
DXMT it crashes 3× per launch) — and the window is **still black, byte-identical across wined3d's
GL and Vulkan renderers**. A healthy cross-process GPU that still can't present is a
presentation-layer wall independent of D3D. So my earlier conclusion appears to be right; the
argument I gave for it just wasn't.

**5. Smaller things.** Also eliminated today, both previously untried: `-cef-force-gpu` and
`--use-angle=d3d9` — each black at 108,343 B, though notably the GPU process survives under both.
`--use-gl=swiftshader` is a dead switch on this CEF — Chromium moved software
selection to `--use-angle=swiftshader`, which I measured on 08-24 (renders art, no glyphs); the
`--use-gl` spelling turns a *working* `--in-process-gpu` cell into the NOTREACHED loop above. Good
Battle.net data point, doesn't transfer. And a trap if your wrapper renames the webhelper: wine keys
`AppDefaults` on the executable's **file name**, so with a shim occupying `steamwebhelper.exe` the
real binary becomes `steamwebhelper_real.exe` and a per-app override that doesn't name it silently
misses the only process that loads d3d11. That's what made my first run of your cell look valid.
Also: thanks for `-noverifyfiles` — my shim is zero-padded to the original's byte count, which
passes "Verifying file sizes only", but padding is the fragile half and yours isn't.

**6. The thing I should have checked first — and it may mean your split isn't what's carrying your
client.** I went and read [notpop/steam-on-m1-wine](https://github.com/notpop/steam-on-m1-wine),
which is where the wrapper originates. Per its own README the enabler isn't the vanilla-wined3d
split; it's two things I don't have:

- **`winemac.so` rebuilt with `-fvisibility=default`** (`scripts/08-patch-wine-visibility.sh`) —
  *"to make macdrv's public API callable by third-party Metal layers"*. One module:
  `CFLAGS='-fvisibility=default -O2 -Wno-error'`, then `make dlls/winemac.drv/winemac.so`. Their own
  success gate is `nm -g` showing **≥100 public text symbols**.
- **A DXMT fork** — `notpop/dxmt@debug/present-path-tracing`, ~150 lines over upstream, which
  *"rewrites `_CreateMetalViewFromHWND`"* around two Wine 11 bugs (`macdrv_win_data` not exposing a
  usable NSView at swap-chain creation; `OnMainThread` re-entrance deadlock).

I measured the visibility half here straight away:

| engine | global syms in `winemac.so` | public TEXT (`T`) | renders Steam? |
|---|---|---|---|
| my self-built stock 11.16 + DXMT | 550 | **0** | no |
| the CrossOver-lineage build I use as a workaround | 535 | **0** | **yes** |
| notpop's patched build | — | **≥100** (their gate) | yes |

Which says something I think is genuinely useful to this issue: **there are at least three
independent mechanisms here, and symbol visibility is not the one the vendor build uses** — it
renders Steam while exporting exactly as little as mine does. The helpers themselves are present
in my `winemac.so` by name (`macdrv_view_create_metal_view`, `macdrv_view_get_metal_layer`,
`macdrv_view_release_metal_view`) and `winemetal.dll` carries `CreateMetalViewFromHWND`; they're
just not *exported*, which is the gap that flag closes.

So — genuine question rather than a correction, since I can't see your install: **are you running
notpop's patched `winemac.so` and the DXMT fork, or stock Homebrew `wine-stable` 11.0 with only the
split?**

**7. I went and built as much of that route as this machine allows.** Both halves, and the results
are worth having on this thread:

- **The visibility rebuild works and is inert on its own.** Rebuilding only
  `dlls/winemac.drv/winemac.so` with `-fvisibility=default` takes my engine from **0 public text
  symbols to 213** (183 of them `macdrv_*`), including exactly the ones the fork needs —
  `macdrv_view_create_metal_view`, `_get_metal_layer`, `_release_metal_view`,
  `macdrv_client_surface_acquire_metal_swapchain`, and the `get_win_data`/`release_win_data`
  accessors. Installed on its own it is ABI-clean and changes nothing: DXMT still at FL 11_1, Steam
  still black. Which is the expected result — the flag is an enabler for the fork, not a fix.
- **Two notes for anyone else reproducing.** You do **not** need to build LLVM from source: the
  fork's meson default `native_llvm_path` is already `/usr/local/opt/llvm@15`, i.e. the *Intel*
  Homebrew prefix, because airconv links LLVM as a macOS **x86_64** static library — so
  `arch -x86_64 /usr/local/bin/brew install llvm@15 zstd` gives you exactly what it wants in
  minutes rather than an hour. And the fork has a small portability bug:
  `src/util/com/com_guid.cpp` uses `std::setfill`/`std::setw` without `#include <iomanip>`, which
  older GCC pulled in transitively and current mingw-w64 doesn't. One line; happy to send it over.
- **Then I built the fork and ran it.** (For anyone following: `xcrun -f metal` *resolving* isn't
  enough on macOS 26 — the shader compiler is a separate asset, `xcodebuild -downloadComponent
  MetalToolchain`, 688 MB.) Both arches build clean. Installed into a wrapper carrying **both**
  ingredients — forked DXMT plus the `-fvisibility=default` `winemac.so` — the engine is healthy:
  Apple M3 Max, `CheckInterfaceSupport` `S_OK`, FL 11_1.

**8. And that produced the actual answer, in DXMT's own words.** With the full stack in place,
Steam is still black — but the log now says exactly why:

```
err:   CreateSwapChain: cross-process swapchain not supported yet
```

`src/d3d11/d3d11_swapchain.cpp:1102`. **The fork still refuses cross-process swapchains** — string
count: 1 in the forked `d3d11.dll`, 0 in the stock v0.80 I ship (v0.80 just crashed the GPU process
instead of naming the refusal). Which fits its own evidence exactly: the rewrite fixes the
**same-process** Metal-view path, so a *game* presenting to its own window works, while CEF creating
a swapchain for an HWND owned by **another process** takes a path the fork doesn't touch.

It does move the failure though, and that's worth having on record: on stock v0.80 out-of-process
the GPU process crashes ×3 per launch; with the fork ANGLE gets *further* — reaching
`SwapChain11::reset` ("Could not create additional swap chains or offscreen surfaces") and
`eglCreateWindowSurface: Bad allocation` — before the same black window. A crash became a named
refusal.

**9. And since I had a working build, I forced the guard — which turns out to be the useful part.**
The refusal is a precondition check that returns before attempting anything, so what actually
breaks has never been observed:

```c
GetWindowThreadProcessId(hWnd, &window_process_id);
if (GetProcessId(GetCurrentProcess()) != window_process_id) {
  ERR("CreateSwapChain: cross-process swapchain not supported yet");
  return E_FAIL;
}
```

I made that env-gated and let it fall through. It fires with genuine cross-process ids
(`hwnd_pid=300 self_pid=472`, 6× per launch), and with `DXMT_DEBUG_METAL_VIEW=1` the next step says
this:

```
CreateMetalViewFromHWND: hwnd=0x10102 macdrv_functions=0x213810560
    get_cocoa_window=0x2137e3d20 create_metal_view=0x2137e3df0 get_metal_layer=0x2137e3e40
CreateMetalViewFromHWND: cocoa_window=0x0
CreateMetalViewFromHWND: macdrv_get_cocoa_window returned NULL for hwnd=0x10102
```

Three things fall out of that, and I think all three are worth having:

- **Every macdrv symbol resolved.** So the error DXMT prints on this path —
  *"Failed to create metal view, it seems like your Wine has no exported symbols needed by DXMT"*
  (`d3d11_swapchain.cpp:137`, then `abort()`) — is a guess, and it's the wrong diagnosis whenever
  the symbols are actually present. It makes this look like a build problem when it isn't. Might be
  worth softening that message regardless of anything else here.
- **`macdrv_get_cocoa_window(hwnd, FALSE)` returns NULL for the foreign HWND**, because winemac's
  window data is per-process — a window created by another process simply isn't in this process's
  table.
- So **"cross-process swapchain not supported yet" isn't swapchain bookkeeping**: a Metal view
  can't be built for a foreign HWND at all, because there's no cross-process route from HWND to
  NSWindow. Whatever fixes this has to solve *that*, which looks like a winemac/wineserver-level
  problem rather than a DXMT-only one. It lines up with something I measured earlier on this
  thread: a cross-process GDI `FillRect` into a foreign window is lost on stock winemac too.

(Forcing the guard is not a workaround, to be clear — it just converts a clean `E_FAIL` into an
`abort()` in the GPU process. Same black window. I kept the patch purely as a diagnostic.)

**10. So I kept going, and I think this is the useful part for you.** `macdrv_get_cocoa_window` is
`get_win_data(hwnd)`, and `get_win_data` is a lookup in `win_datas` — a **process-local
`CFDictionary`**. So that route can't ever work cross-process. But wine's macdrv has a *second*
path, and it already handles the foreign case. In `macdrv_client_surface_acquire_metal_swapchain`:

```c
if ((data = get_win_data(hwnd))) { ... macdrv_create_view_swapchain(surface->cocoa_view); }
else {
    if (NtUserGetAncestor(hwnd, GA_ROOT) != hwnd) {
        FIXME("Cross-process child window Metal swapchains are not implemented\n");
        return FALSE;
    }
    surface->metal_swapchain = macdrv_create_offscreen_swapchain(hwnd, ...);
}
```

For a foreign **root** window wine builds an **offscreen** swapchain; only foreign **child** windows
are unimplemented. On my engine the thing that stops us reaching it is a refusal one level up — the
DXMT-support patch's `my_get_win_data` returns NULL whenever `get_win_data` does. I gated that on an
env var and rebuilt `winemac.so`, then ran it against **stock DXMT v0.80** (which, unlike the newer
tree, has no cross-process guard at all). Result:

- the foreign path fires **46×** in one launch,
- **no** `Cross-process child window` FIXME — these are root windows, so the offscreen branch ran,
- **zero** `Failed to create metal view` — DXMT genuinely gets a Metal view for a foreign HWND,
- and the window is **still black**.

**Which I think locates the problem precisely: it isn't view creation and it isn't swapchain
bookkeeping — both can be made to succeed.** It's that the cross-process route yields an
*offscreen* swapchain whose contents are never composited into the on-screen window owned by the
other process. Closing this would need cross-process *compositing* — an `IOSurface`/`CAContext`-style
shared layer — which is a winemac/wineserver-level change rather than anything DXMT can do alone.
That would also explain why the CrossOver-lineage build is the only thing I've seen render this
client: its plumbing spans exactly those layers.

Caveats, so you can weigh it: that cell ran with `WINEDEBUG=err+all` (the harness normally uses
`-all`, which suppresses wine's own `ERR()` — my first attempt looked like "nothing fired" purely
because of that), the patch leaks the client surface since there's no `win_data` to own it, and the
same run logs some MoltenVK/gnutls load failures I have **not** controlled for and am not
attributing to the patch.

**11. And wiring that up found the bottom.** I added
`dxmt_acquire_remote_layer(HWND, macdrv_view*)` to `macdrv_functions_t` (sizeof 80 → 88, both trees
rebuilt in lockstep) and had `_CreateMetalViewFromHWND` call it whenever `macdrv_get_cocoa_window`
returns NULL. The route goes live — guard forced 6×, remote path taken 6× in one launch — and then
wine answers, precisely:

```
fixme:macdrv:macdrv_client_surface_acquire_metal_swapchain
    Cross-process child window Metal swapchains are not implemented
```

Six occurrences, matching the six attempts. The branch is
`if (NtUserGetAncestor(hwnd, GA_ROOT) != hwnd) return FALSE;` — **wine's cross-process CAContext
route is implemented only for root windows, and Steam's CEF presents into a child HWND.**

So the whole thing reduces to one sentence: *Steam's CEF renders to a cross-process **child**
window, and winemac implements cross-process Metal swapchains only for **root** windows.* Which
also explains, without hand-waving, everything else in this comment — games work because they're
same-process; notpop's fork fixes the same-process view path, hence a game as its evidence; the
vanilla-wined3d split sidesteps DXMT entirely.

**Which means, respectfully, that #141 may not be actionable on the DXMT side at all.** The
unimplemented case is in winemac's `macdrv_client_surface_acquire_metal_swapchain`. The root-window
path there already builds a `CAContextSwapChain` and posts `WM_MACDRV_CREATE_REMOTE_LAYER` to the
owning process, which hosts it via `CALayerHost`; a child window additionally needs its rect mapped
into the owner's coordinate space and the hosted layer positioned and clipped there. That's a wine
patch. I'm happy to attempt it and report back if that's useful.

(One trap for anyone reproducing: that FIXME is invisible under `WINEDEBUG=-all` *and* under
`err+all` — FIXME is its own class. Two of my earlier cells read "0 occurrences" purely for that
reason. You need `+macdrv`.)

**12. I implemented that, and Steam's client renders.**

The change is small. In `macdrv_client_surface_acquire_metal_swapchain`, instead of the FIXME:
resolve `root = NtUserGetAncestor(hwnd, GA_ROOT)` and build the offscreen `CAContextSwapChain`
**against the root** rather than the child. That indirection is the whole thing —
`macdrv_create_offscreen_swapchain(hwnd, …)` posts `WM_MACDRV_CREATE_REMOTE_LAYER` to whatever HWND
it's given, and the handler needs `data->cocoa_window`, which a child HWND doesn't have. The root
both owns an `NSWindow` and lives in the owning process.

| | before | after |
|---|---|---|
| window capture | **108,343 B** (uniform black) | **2,346,395 B — renders** |
| `REMOTE path` layer / view | `0x0 / 0x0` | **non-NULL** |
| `acquire_metal_swapchain FAILED` | 6 | **0** |
| `Cross-process child window…` FIXME | 6 | **0** |

**Configuration, verified rather than assumed:** no webhelper shim, **no injected switches at all**,
**out-of-process GPU** (1 `--type=gpu-process` child). That is exactly the stock setup that measured
108,343 B black on every previous run in this thread. So it isn't a flag, isn't the shim, and isn't
the wined3d split — it's the winemac patch.

**What's fixed:** artwork, capsules, thumbnails, gradients, nav chrome, the search field — the store
lays out and composites correctly.

**What isn't:** glyphs. Still six bare dropdown carets for the nav bar, no titles or prices, only
text baked into promo art. And I'd flag that as genuinely odd rather than assume it's the known bug:
the glyph loss was previously tied to *in-process GPU*, but this run is **out-of-process**. So the
text defect is either broader than that path or shares a cause with it — I don't yet know which.

Geometry is also unfinished: the hosted `CALayerHost` fills the root's content view rather than
being positioned and clipped to the child's rect, which shows as a black band at the bottom. That's
the obvious next piece, and cosmetic next to the black window going away.

So the honest summary: **cross-process presentation for Steam's CEF is fixable, and the fix is a
handful of lines in winemac, not in DXMT.** I'm happy to clean this up into a proper wine patch
(geometry mapped, no leaked client surface, the ABI addition done sensibly) and send it to
wine-devel — and to hand you the DXMT-side counterpart if you'd rather carry that half. Whichever
is more useful.

*(One caveat on my setup: DXMT's own `CreateSwapChain` cross-process guard has to be lifted for any
of this to be reached, which I did behind an env var. On a stock DXMT v0.80 there is no such guard,
so the winemac patch alone is what matters there.)* The vanilla-wined3d split
is capped at FL 9_3 here; notpop's visibility + fork route fixes games, not the client; and the only
thing left standing between Steam's CEF and a rendered window on DXMT is cross-process swapchain
support — which is what #141 has said from the start. I'd rather report that than another
workaround, because it puts the fix back where you'd already put it.

**And on your setup specifically** — none of the above contradicts your result; it explains it.
If your wined3d serves D3D11 at a usable feature level on Wine 11.0 / macOS 26.5, then your split
takes DXMT out of the CEF path entirely and the client renders on wined3d, which is precisely what
mine cannot do at FL 9_3. That's why the probe matters. Reading the fork's commit message, its
verification is *"the 32-bit Unity 6000 game 幻獣大農場 (Steam AppID 3659410): Present1 returns
hr=0x0 every frame"* — **a game, not the Steam client**. The two root causes it names are precise
and look right to me — (1) Wine 11 renamed `macdrv_win_data`'s NSView field to `client_view` and
only populates it in the GDI present path (`dlls/winemac.drv/window.c:1131-1135`), so at
`IDXGISwapChain` creation it is always NULL; (2) the macdrv Metal helpers already dispatch through
`OnMainThread` (`cocoa_window.m:3941/3954/3966`), so the unixlib's extra `OnMainThread` is nested
dispatch and the outer wait deadlocks (`cocoa_event.m:489`) — and if that's right it's a much more
actionable fix for this issue than anything I've posted. But it's evidenced for *game* presentation,
so whether it also carries the **CEF client** is the open question, and your setup is the one data
point that would answer it.

**The ask.** Alongside that, would you run the probe on your stack? ~50 lines, no dependencies:
[`scripts/dxgiprobe.c`](https://github.com/macgameport/cities-skylines-2-macos/blob/main/scripts/dxgiprobe.c),
built with `x86_64-w64-mingw32-gcc dxgiprobe.c -o dxgiprobe.exe -ld3d11 -ldxgi -ldxguid -luuid`,
run in your prefix with the split active. If you get a real adapter at **feature level 11_x**, then
wined3d is serving D3D11 properly on wine 11.0 / macOS 26.5 where mine caps at 9_3 on 11.16 /
26.6.2 — your split is viable and mine is blocked by a feature-level cap, which is a far more
actionable finding than anything else on this thread. If you get **9_3** and `0x887A0004` like me,
then something other than D3D11 is carrying your client and that's worth knowing too.

*(Analysis and testing done with AI assistance, per the project's policy.)*
