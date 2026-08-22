# ★ Wine 11.15 fixes the bug. Wine 10.0 does not.

**Measured 2026-08-22.** Same probe, same Unity Mono runtime, same **pristine** `mscorlib`
(unpatched — the patched one would have masked the failure), two Wine versions.

## Result

| test | wine-10.0 Sikarugir | **wine-11.0 stable** | wine-11.15 devel |
|---|---|---|---|
| `Marshal.GetLastWin32Error` after P/Invoke | **1525694624 (garbage)** | **0** | **0** |
| `Directory.Delete(recursive)` | `IOException 0x5af040a0` | OK | OK |
| `Directory.Delete(tree w/ file, RECURSIVE)` | `IOException 0x5af040a0` | OK | OK |
| ManualDelete — empty dir | throws, **GONE=False** | no throw, GONE=True | no throw, GONE=True |
| ManualDelete — nested empty subdir | throws, **GONE=False** | no throw, GONE=True | no throw, GONE=True |
| ManualDelete — flat dir w/ file | throws, **GONE=False** | no throw, GONE=True | no throw, GONE=True |
| `File.Delete(nonexistent)` | `IOException 0x5af040a0` | OK | OK |
| `ClearFolderAndKeepPatchFile` replica (the `PrepareFolderForPatching` failure) | fails | **ALL OK** | ALL OK |

**The fix landed between 10.0 and 11.0** — it is in the *stable* branch, not buried in 11.x
development. That matters, because the only free Wine 11 Metal engine available is built on 11.0.

`0x5af040a0` is pointer-shaped — uninitialised memory, not an error code.

Raw logs: [`measurement-wine10.0.txt`](measurement-wine10.0.txt) ·
[`measurement-wine11.15.txt`](measurement-wine11.15.txt)

## The layer, finally pinned

This is where the earlier bug report went wrong. On **the same wine-10.0 build**:

- **Raw Win32 `GetLastError()` is correct** — `scripts/errtest.c` scores 9/9 across every failure
  path, including `FindNextFile`-exhausted → 18.
- **`Marshal.GetLastWin32Error()` returns garbage** — as measured above.

So the corruption happens in **Mono's P/Invoke last-error capture**, in the transition from the
native call back into managed code. Not in Wine's Win32 implementation. That is precisely why a
native probe could not reproduce it, and why bug
[60220](https://bugs.winehq.org/show_bug.cgi?id=60220) — which blamed `kernel32` — was correctly
closed INVALID.

The symptom described in that report was real. The attribution was not. And it is **already fixed
upstream**, so there is nothing left to file.

## What this means for the patches

Of the 17 patches, the **8 mscorlib/IO ones exist solely to tolerate this garbage errno**:
`patch_dirdel` · `patch_dirhandle` · `patch_delfile` · `patch_delrec` · `patch_dirrec_nx` ·
`patch_delchild` · plus `patch_longdelete` and `patch_createfile` in PdxSdk.

**On a Wine 11-based stack they are very likely unnecessary.**

### Engine survey (2026-08-22) — what actually exists

| source | newest | Metal? |
|---|---|---|
| **Sikarugir Engines** (Kegworks was renamed Sikarugir; this is what `S734M.app` uses) | `WS12WineSikarugir10.0_6` | D3DMetal, **Wine 10.0** — no Wine 11 build |
| Sikarugir, other lines | `WS12WineCX24.0.7_7`, `WS12WineGPTK1.1_3` | older |
| **Gcenx stock Wine** | 11.15 | **no Metal** — verified: DXMT fails `c0000135`, stock ships `winemac.so` without the exposed Metal symbols `winemetal.so` needs |
| **D3DMetal** | Apple's, welded to GPTK (wine-7.7); forward-ported to modern Wine only inside CrossOver | paid |

**There is no free Wine 11 + D3DMetal engine.** The one viable candidate is
**Porting Kit's `WS12Wine11.0_DXMT-v0.80`** — Wine 11.0 + DXMT, distributed through the Porting Kit
app rather than GitHub. This project already built `CS2dxmt.app` on it in July and reached a
**playable map**, so it is proven on this game — and per the table above, **Wine 11.0 has the errno
fix**.

### There is no D3DMetal for Wine 11 — and it cannot be transplanted

Porting Kit's own engine manifest (`~/Library/Application Support/portingkit/config.json`):

| engine | Wine | Metal layer |
|---|---|---|
| `WS12WineCX64Bit23.7.1-3_D3DMetal-v1.1` | CrossOver 23.7 (~Wine 8) | D3DMetal v1.1 |
| `WS12WineCX64Bit23.7.1-4_D3DMetalv2.1` | CrossOver 23.7 | D3DMetal v2.1 |
| **`WS12WineSikarugir10.0_2_D3DMetal-v2.1`** | **Wine 10.0** — newest D3DMetal | D3DMetal v2.1 |
| **`WS12Wine11.0_DXMT-v0.80`** | **Wine 11.0** — only Wine 11 engine | **DXMT** |

**Why it can't simply be copied across (tested 2026-08-22).** D3DMetal is not just a macOS
framework. It ships `lib/wine/x86_64-unix/d3d11.so` + `dxgi.so` — **unix-side** Mach-O libraries
linked against Wine's *internal* unixlib ABI, which is deliberately unstable between releases.
Transplanting the Wine-10 D3DMetal pieces into the Wine-11 engine and running a minimal DX11 test:

```
Loaded L"C:\windows\system32\d3d11.dll" ... builtin
err:module:loader_init "d3d11.dll" failed to initialize, aborting
status c0000142   (STATUS_DLL_INIT_FAILED)
```

The PE stub loads; its `DllMain` fails. The shim must be **recompiled** per Wine version — which
only Apple (for GPTK's frozen wine-7.7) and CodeWeavers (for CrossOver) do. That single
proprietary rebuild is what "D3DMetal for modern Wine" means, and it is not available free.

**So the choice is a genuine fork:**

| | D3DMetal + Wine 10.0 | DXMT + Wine 11.0 |
|---|---|---|
| renderer | D3DMetal v2.1 (proven stable here) | DXMT v0.80 |
| garbage-errno bug | **present** — needs 8 patches | **fixed** |
| status | current `S734M.app`, fully working | `CS2dxmt11.app`, IO verified, game not yet run |

### ✅ RESOLVED 2026-08-22: the Wine 11 route WORKS — 6 patches confirmed unnecessary

CS2 boots to the main menu on **PortingKit wine-11.0 + DXMT** with **`mscorlib` completely
unpatched (0 differing bytes)**, and all four mods load:

```
[15:02:01] MainMenu reached
[15:02:01] GameManager initialized! (60338ms)
Direct3D 11.0 [level 11.1]   Renderer: Apple M3 Max   VRAM: 14376 MB

======= Enabled Mods =======
 - Move It v0.5.15 · Unified Icon Library v1.0.14 · Anarchy v1.7.24 · Traffic v0.2.12.1
```

| counter | value |
|---|---|
| `Invalid handle` | **0** — `patch_fshandle` unnecessary |
| `IOException` | **0** |
| NullReferenceException | 0 |
| SteamAPI failures | 0 |
| mod load failures | 0 |
| PdxSdk errors | 0 |

**All 6 mscorlib patches dropped and nothing broke.** DXMT also reports the real GPU
(`Apple M3 Max`) where D3DMetal reports `AMD Compatibility Mode`.

✅ **Fresh mod DOWNLOAD confirmed 2026-08-22 15:33.** Subscribed to a new mod in-game (Easy Zoning,
`136261_15`) with the 5 errno patches OFF. It appeared on disk within ~2 minutes — 552K, real payload
(`EasyZoning.mjs` + `EasyZoning_win_x86_64.dll`) — with **0 PdxSdk errors and 0 IO failures**. So the
errno patches are unnecessary for downloading, not merely for loading.

### ⚠️ But `patch_fshandle` is STILL REQUIRED on Wine 11

Running with `mscorlib` fully unpatched produced **6 `Invalid handle` errors** on settings reads
(3 distinct GUIDs), which surface in-game as ⚠ markers on the KEYBINDS / ANARCHY / TRAFFIC panels,
keybindings that don't persist, and an `ArgumentException` dialog on exit. Applying `patch_fshandle`
alone took that **6 → 0**.

**Wine 11 fixes the garbage-errno defect. It does NOT fix the handle-0 defect.** Those are two
separate bugs and conflating them is an error — an earlier draft of this document claimed all 6
mscorlib patches were droppable, based on a log read before it had flushed.

**Correct tally: 5 patches retired, 1 still needed.**

| patch | Wine 10 | Wine 11 |
|---|---|---|
| `dirdel`, `dirhandle`, `delfile`, `delrec`, `dirrec_nx`, `delchild` | needed | **droppable** ✅ |
| `patch_fshandle` | needed | **still needed** ⚠️ |
| PDX.SDK ×5 (incl. `lockleak`) | needed | untested — left applied |

Verified end state of `CS2dxmt11.app`: `mscorlib` = **4 differing bytes** (`fshandle` only) instead
of 16; game boots, mods load, mods download, `Invalid handle` 0, NRE 0, SteamAPI failures 0.

#### The Steam blocker, and what it actually was

The first attempts failed at `[U:1:0]` and I wrongly blamed
`f8fb5c27-c6b3-4f75-a4c8-439af2ef564c`. **That GUID is `ID3D11Texture1D`** — ANGLE querying a
Texture2D for it is ordinary type-discovery, correctly answered with `E_NOINTERFACE`. The DXMT
warning is benign.

The real cause was mundane: **the engine swap left the wrapper's 86 `Contents/Frameworks/*.dylib`
behind**, so `wineserver` died on `@rpath/libinotify.0.dylib`. SIP strips `DYLD_*` from signed
binaries, so those dylibs must be **physically present in `SharedSupport/wine/lib/`** — a gotcha
this project already recorded in July and I re-learned the hard way. Copying them in fixed Steam
login immediately.

(DXMT genuinely does lack cross-process swapchains — `err: CreateSwapChain: cross-process swapchain
not supported yet`, tracked upstream as **[3Shain/dxmt#141](https://github.com/3Shain/dxmt/issues/141)**,
open since 2026-03-30. It did not block this run; a `--in-process-gpu` steamwebhelper wrapper is the
community workaround if it ever does.)

### Superseded analysis below (kept for the record)

> ⚠️ **Everything below was wrong and is retained only to show the reasoning.** The Wine 11 route
> works; Steam authenticates; mods download. Do not act on anything in this section.

The wrapper was built (`CS2dxmt11.app`, APFS clone of the working one with only the engine swapped)
and the IO layer verified clean with a **pristine** `mscorlib`. But the game could not be launched,
because **Steam will not authenticate on the DXMT engine**:

```
warn:  D3D11Resource(tex2d): Unknown interface query f8fb5c27-c6b3-4f75-a4c8-439af2ef564c
...
[Logged Off, 0, 0] [U:1:0] CCMInterface::SetSteamID( [U:1:0] )
```

~~`f8fb5c27-c6b3-4f75-a4c8-439af2ef564c` is the D3D11 shared-texture interface Steam's Chromium/CEF
uses to hand rendered frames across.~~ **WRONG — see the correction above. That GUID is
`ID3D11Texture1D`**; ANGLE querying a Texture2D for it is ordinary type-discovery, correctly answered
`E_NOINTERFACE`, and the DXMT warning is benign. The real Steam blocker turned out to be missing
`Contents/Frameworks/*.dylib` after the engine swap. Steam connects to the network fine (connectivity test OK) and the webhelper
starts, but login never completes — it sits at `[U:1:0]` and the client exits. Adding
`-cef-disable-gpu -cef-disable-gpu-compositing` got it as far as connecting, not to logging in.

Without a Steam login there is no licence, so `SteamAPI.Init` fails and CS2 will not start. **The
mods-unpatched test could not be run.**

This is also why the July DXMT stack needed a **CEF remote-debugging (CDP) login hack** rather than
ordinary auto-login — the same wall, worked around rather than solved.

### The trade-off, in final form

| | **S734M** (D3DMetal + Wine 10.0) | **CS2dxmt11** (DXMT + Wine 11.0) |
|---|---|---|
| garbage errno | **present** — needs 8 patches | **fixed** |
| `f8fb5c27` shared texture | **implemented** | **missing** |
| Steam login | works | **fails — `[U:1:0]`** |
| game launches | **yes, fully playable** | blocked, no licence |

**D3DMetal is required for Steam, and D3DMetal does not exist for Wine 11.** So the errno fix is
real and measured, but unreachable on a free stack today. `S734M.app` + the 17 patches remains the
only working configuration.

**What would unblock it**, in rough order of likelihood: DXMT implementing `f8fb5c27` (upstream
feature request — this is a small, well-defined interface) · a Wine 11 D3DMetal engine appearing
from Porting Kit or Sikarugir · reviving the CDP login hack from July to sidestep the Steam UI.

### Next step

Rebuild the wrapper on the Porting Kit Wine11.0-DXMT engine, then remove the 8 errno patches one at
a time and retest. Keep `patch_lockleak` regardless — it fixes a genuine Paradox managed-code defect
(a `catch` with no `finally`), which no Wine version will fix.

⚠️ **Not yet verified in the game.** This probe is single-process and single-threaded. It proves the
Mono/Wine defect is fixed in 11.15; it does not prove the game runs clean without patches. Test
before deleting anything.

## Method note

The measurement only worked because the **pristine** `mscorlib` was staged. Running it against the
patched one would have shown everything passing on both versions and produced the exact opposite
conclusion. When testing whether a workaround is still needed, remove the workaround first.
