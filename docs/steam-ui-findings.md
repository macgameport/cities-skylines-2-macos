# Steam's UI on wine 11.16 + DXMT — what we actually know

> **Read this first.** The investigation is recorded elsewhere in reverse chronological order with
> retractions layered on top, which is faithful but nearly unreadable. This is the same material as
> one causal story, current as of **2026-08-31**.
>
> Companions: [`test-matrix.md`](test-matrix.md) = what works today, cell by cell ·
> [`../EXPERIMENTS.md`](../EXPERIMENTS.md) = the register and per-run evidence (authoritative on
> trust) · [`steam-ui-investigation.md`](steam-ui-investigation.md) = the raw chronology.

## The short version

There were **two separate bugs**, and for a week they were mistaken for one.

1. **No font backend.** Our own launcher and harness started Steam through `nohup`. macOS strips
   `DYLD_*` across a SIP-protected exec, our engine could not then find its own `libfreetype.dylib`,
   and DirectWrite rasterised nothing — so Steam drew **art with no text**. *Ours. Fixed.*
2. **A NULL dereference in DXMT.** Chromium's GPU process asks DXMT for a Metal view for a window
   owned by *another process*; `get_win_data()` returns NULL for a foreign HWND; DXMT dereferences
   it without checking, aborts, and after six retries Chromium gives up — so Steam's window stays
   **black**. *Upstream. Open.*

Bug 1 masked bug 2 and vice versa: a black window and a textless window look equally "broken", and
almost every measurement taken before 2026-08-30 was contaminated by bug 1.

## Bug 1 — the font backend (SOLVED)

```
launcher/harness uses nohup
   -> macOS purges DYLD_* on exec of a SIP-protected binary (nohup, env, /bin/bash all qualify)
      -> win32u.so has only an @loader_path/ rpath, cannot find its own wine/lib/libfreetype.dylib
         -> wine prints ONE line and continues with NO font backend
            -> DirectWrite still reports 204 families and S_OK, but rasterises ZERO coverage
               -> Chromium draws artwork, gradients, thumbnails, chrome -- and not one glyph
```

**Why it hid for a week:** every check said fonts were fine. `EnumFontFamilies` returned 204.
`DWriteCreateFactory` returned `S_OK`. Only *rasterisation* was broken, and nothing measured that
until a probe was compiled into the webhelper shim and run **inside Steam's own process tree**:

| | GDI families | DWrite families | rasterises `ABC@32` |
|---|---|---|---|
| broken | 0 | **204**, `S_OK` | **empty bounds, 0 coverage** |
| fixed | 924 | 204 | `71x23`, 545 non-zero px |

**The fix, applied:** `install_name_tool -add_rpath "@loader_path/../../"` on the four modules that
`dlopen` a bare soname — `win32u`, `dwrite`, `crypt32`, `secur32` — then `codesign -f -s -`. Porting
Kit's engine already carries that rpath, which is the entire reason PK builds never showed this.
Verified: launching through `nohup` with every `DYLD_*` unset now resolves fonts cleanly, **63
FreeType failures → 0**. Made durable as step 8 of `build-engine-1116.sh`.

**Consequence:** `--in-process-gpu` renders the Steam client **completely, with text**
([screenshot](images/steam-renders-with-text.png)). The long-standing claim that in-process GPU
"kills all text" was our own bug, and is now `DISPROVEN`.

## Bug 2 — the NULL dereference (OPEN)

`winemetal_unix.c`, `_CreateMetalViewFromHWND`:

```c
if (pfn_get_win_data && pfn_release_win_data && pfn_macdrv_view_create_metal_view &&
    pfn_macdrv_view_get_metal_layer) {                       /* all four POINTERS checked */
  struct macdrv_win_data *win_data = pfn_get_win_data((HWND)params->hwnd);
  macdrv_metal_view view =
      pfn_macdrv_view_create_metal_view(win_data->client_cocoa_view, ...);   /* <== NULL deref */
```

`client_cocoa_view` sits at **+0x18**, which is exactly the faulting address the trace reported.
The code validates all four *function pointers* and then never checks what the first call *returns*.

**And `get_win_data()` returns NULL by construction for a foreign HWND** — winemac keeps `win_datas`
in a **process-local `CFDictionary`**, so another process's window is invisible. That is C3, derived
from wine's source independently and days earlier.

```
CEF GPU process wants a Metal view for the BROWSER process's HWND
  -> get_win_data(foreign hwnd) -> NULL          (process-local table)
     -> win_data->client_cocoa_view              -> AV reading 0x18
        -> unhandled -> abort() -> __fastfail(7) -> ucrtbase int 0x29 -> 0xC0000409
           -> Chromium restarts the GPU process; identical death; 6x; gives up
              -> black window
```

**This unifies the investigation.** The GPU crash was never a separate blocker sitting *upstream* of
the cross-process work — **it is the cross-process problem**, surfacing as a null dereference rather
than the graceful `E_FAIL` we spent days looking for. The `cross-process swapchain not supported`
guard in `d3d11_swapchain.cpp` is a *later* checkpoint that is never reached, which is also why
forcing it open changed nothing.

**Why `--in-process-gpu` works:** it deletes the problem rather than solving it. The GPU moves into
the browser process, so the HWND is no longer foreign, `get_win_data` succeeds, and nothing
dereferences NULL. Its only known cost is **flicker on the store tab's autoplaying video**; the
library renders cleanly.

## What has been eliminated

Each of these changed **nothing** — same 6 crashes, same black window, several byte-identical:

| eliminated | how |
|---|---|
| the rendering backend | `--use-angle=swiftshader` (pure software, no Metal/DXMT/GPU driver) — byte-identical |
| ANGLE's D3D11 path | `--use-angle=d3d11` |
| the C runtime | forcing wine's builtin `ucrtbase` |
| the VPN / network | Proton vs a home tunnel — byte-identical |
| notpop's fork | rebuilt ABI-matched against the shipped engine; removes the faulting instruction, still black |
| a missing library | only 5 unix modules `dlopen` a bare soname; `win32u` covers MoltenVK **and** FreeType and already has the fix |

## Instruments, and the ones that lied

Four probes returned clean, confident, **wrong** answers. Each is now documented where it will be
hit again:

- **`timeout` does not exist on macOS.** `timeout <cmd> | grep -c` is a silent zero-generator; it
  made `wine notepad` look like a blind font probe when it had simply never run.
- **`bash -c`, `env` and `nohup` strip `DYLD_*`.** Wrapping a probe in one removes the variable
  under test — and is also the whole of bug 1.
- **`ps eww` cannot read another process's environment** on macOS 26; it returns empty for a
  sentinel you own, so it reports "the variable was lost" for everything.
- **`cell-fingerprint.sh`'s library check validates the *harness's* env**, not the target's. It
  would have passed all 41 contaminated cells.

Plus two of my own analysis errors worth the same treatment: mapping a fault address to a module
using bases from **another process** (twice — it named the wrong DLL and decoded a jump displacement
as an instruction), and concluding from **enumeration** what only **rasterisation** could tell you.

## Wall 1 is down (2026-08-31)

`scripts/dxmt-nullcheck-win-data.patch` — six lines — checks `get_win_data()`'s return before
dereferencing it. Built against the shipped engine, installed with **winemac left stock** so the
null check is the only variable.

**The crash moved:** `winemetal.so _CreateMetalViewFromHWND +0xbf` → `ntdll.so +0x301f9`, which is
`__wine_unix_call_dispatcher +0xc9`. Still 6 crashes, still black — no user-visible change — but
that specific dereference is gone.

**And that is the same address notpop's fork crashed at.** Two independent fixes to bug 2 — their
rewrite and our six-line check — land on an identical next failure. So the dispatcher crash is not a
fork artifact and not a build mismatch: it is simply **wall 2**, reached by anyone who gets past wall
1. It also makes the fork result precise — "does not fix the Steam client" is true because it fixes
wall 1 and stops where we now stop.

## Diagnosed (2026-08-31) — and it rules out three fixes

Instrumenting the NULL branch answered it. Six firings, two windows, identical shape:

```
get_win_data(0x10104) NULL  parent=0x200f0  root=0x500e6  root_win_data=null
```

- **It is a child window** (has a parent, and a root distinct from itself).
- **The Win32 guard did not fire** — `GetWindowThreadProcessId()` says the *child* is ours.
- **The root has no `win_data` either.**

The child is owned by the GPU process; its root lives in the browser process; winemac cannot realize
a child whose parent chain leaves the process, so neither gets a `win_data`. That is exactly the case
winemac's own `FIXME` names — *"Cross-process child window Metal swapchains are not implemented"*.
The Win32 process check and the winemac realization check disagree, and DXMT trusts the first.

**This explains every failed fix at once:**

| attempt | why it could not work |
|---|---|
| null-check `get_win_data` | the caller `abort()`s on a null view **by design** |
| notpop's fork | rewrites the same function; still needs a `win_data` that does not exist |
| map child → root (our CHILD patch) | **the root has no `win_data` either** |
| force the cross-process guard open | the guard never fires for this window |

## ✅ SOLVED 2026-08-31 — Steam renders completely, out-of-process, no shim

Two patches, neither of which works alone:

- **wine** (`scripts/winemac-crossprocess-remote-layer.patch`) — export
  `dxmt_acquire_remote_layer` as a standalone symbol; pass the child rect in the ROOT's space at
  creation; and **convert Win32 pixels to Cocoa points** at the two Cocoa entry points. That last
  one removed the black band: `CALayer.frame` is in points, the frames arriving were raw pixels,
  and on retina that is exactly 2×.
- **DXMT** (`scripts/dxmt-remote-layer-fallback.patch`) — when `get_win_data()` returns NULL,
  call `dxmt_acquire_remote_layer()` via `dlsym` instead of dereferencing NULL.

Result: **0 GPU crashes** (was 6 every launch), full client with text
([screenshot](images/steam-crossprocess-complete.png)). The game still boots to `MainMenu` on the
same configuration, which matters because winemac is on the boot path.

⚠ **Blocker to upstreaming:** `my_dxmt_acquire_remote_layer` deliberately leaks the previous
client surface — releasing it on the next acquire destroys the layer DXMT is still rendering
into. Lifetime should be driven by DXMT releasing its swapchain.

## Open

1. **Wire DXMT to wine's remote-layer path.** Stop asking for a `macdrv_view` on a window this
   process does not own; use `macdrv_client_surface_acquire_metal_swapchain` /
   `WM_MACDRV_CREATE_REMOTE_LAYER` + `CAContext`, which exist for exactly this and which our patched
   winemac already exposes. DXMT simply never calls them. The winemac half is built; the DXMT half
   is not.
3. **Backend-independence is not fully closed** — software rendering gave a byte-identical result,
   which requires `winemetal.so` to be reached under swiftshader too. Not confirmed by `vmmap`.
4. **43 of 64 cells can never be interpreted.** No config was recorded; permanently `VOID-LIBS`.
