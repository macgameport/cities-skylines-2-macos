# dxmt#141 — third evidence comment (2026-08-28)

Posted 2026-08-28 as [#5458926046](https://github.com/3Shain/dxmt/issues/141#issuecomment-5458926046),
in reply to mikey92's report.
Prior comments on the thread: 5400445243 (stock-vs-vendor sweep) · 5403561498 (`--in-process-gpu`:
renders but textless, plus the steam.exe flag-filtering and file-size-only verification findings).

---

@mikey92 — thanks, that pushed this somewhere useful. I tested both halves of your report on a
self-built **stock wine 11.16 + DXMT v0.80** engine (M3 Max, macOS 26.6.2, Aug-2026 Steam client,
CEF 126) and ended up eliminating three hypotheses, including the one this issue is named after.
All cells judged by per-window screen capture rather than logs; a black window here is ~15–41 KB
and a rendered one 0.7–2.0 MB on the same windows.

**1. `--single-process` fails exactly like `--in-process-gpu` — so the glyph loss is in-process
GPU itself, not one switch.**

I had only ever tested `--in-process-gpu` (renders art, draws zero glyphs). `--single-process`
gives a 2,018,352 B capture of a fully rendered store — artwork, thumbnails, gradients, icons,
chrome all perfect — and **not one glyph**: bare dropdown carets where the nav labels belong, empty
search field, no titles or prices. The only readable text is baked into promo images. Same failure,
different route in, which means the cause sits in the in-process-GPU path rather than in the flag I
originally blamed.

**2. Your `--disable-gpu --single-process` pair is worse than either flag alone on a DXMT engine.**

No window ever appears. Chromium cannot create a GL context at all —
`gl_factory_win.cc(63) NOTREACHED`, `Failed to create GLES3 context, fallback to GLES2`,
`ContextResult::kFatalFailure: Failed to create shared context for virtualization` — looping at
~174 % CPU. That matches your 10 s restart loop, and is consistent with the pair working for you
only because your client is on vanilla wined3d.

**3. Out-of-process, the wall is backend-independent.**

Default (D3D11), `--use-angle=gl` and `--use-angle=vulkan` all behave identically: the GPU process
crash-loops (Chromium reports 3 crashes, then gives up) and the window is black. So this is not
"ANGLE needs a D3D11 path that DXMT lacks" — nothing presents cross-process here regardless of
backend.

**4. The big one: taking DXMT out of the client's path entirely does not fix it.**

I built your split. Every `d3d11.dll`/`dxgi.dll` on this machine was DXMT's, so I built stock wine
11.16 from source and stopped before the DXMT overlay to harvest version-matched vanilla
`d3d11.dll` + `dxgi.dll` (x86_64 and i386). Wired exactly as your writeup describes: the
`"Wine builtin DLL\0"` marker stripped at file offset `0x40` (`build_module` in
`dlls/ntdll/loader.c` computes `signature = base + sizeof(IMAGE_DOS_HEADER)` and memcmps 17 bytes,
so a `native` override at a wine-built PE is otherwise redirected straight back to the builtin),
global `d3d11/dxgi=builtin` so the game keeps DXMT, per-app `native` for `steam.exe`,
`steamwebhelper.exe` and `steamservice.exe`.

The split provably landed — `+loaddll` inside Steam's processes:

```
Loaded L"C:\windows\system32\d3d11.dll"  ...: native      <- vanilla
Loaded L"C:\windows\system32\dxgi.dll"   ...: native      <- vanilla
Loaded L"C:\windows\system32\wined3d.dll"...: builtin
(no winemetal anywhere in Steam's process tree)
```

**Steam is still uniformly black: 108,343 B.** And with wined3d's *Vulkan* renderer instead of GL,
the capture is **byte-identical** — same 108,343 B.

That byte-identity is the useful part. Swapping the whole D3D implementation out for wined3d, and
then swapping wined3d's backend underneath it, changes nothing at all. **So the Steam client's
black window is not caused by DXMT's missing cross-process swapchain.** There is a second wall
underneath, in the winemac presentation layer, and DXMT is simply the first thing that hits it. It
lines up with what I measured earlier on this thread: a cross-process GDI `FillRect` into a foreign
window is lost on stock winemac too, and Chromium's software-composited path is blank on every
stock winemac engine I have tried — while a CrossOver-lineage build renders the same client fine.

Worth adding for anyone reproducing on macOS 26: wined3d's **GL** backend cannot clear a buffer
there — `err:d3d:wined3d_check_gl_call GL_INVALID_FRAMEBUFFER_OPERATION (0x506) from glClear`. Its
Vulkan renderer initialises cleanly (MoltenVK 1.2.10, no GL errors); it just doesn't change the
outcome above.

None of this argues against fixing cross-process swapchains in DXMT — it would still be the right
fix for the D3D11 half. It does say that on a stock-winemac engine it will not by itself make the
Steam client render, so anyone chasing that specific symptom should look at the presentation layer
first.

Offer stands to run further diagnostics or test a build on this setup.

*(Analysis and testing done with AI assistance, per the project's policy.)*
