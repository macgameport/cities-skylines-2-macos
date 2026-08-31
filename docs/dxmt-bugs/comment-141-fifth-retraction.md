# dxmt#141 — fifth comment: retraction + the actual root cause

Prior comments: 5400445243 · 5403561498 · 5458926046 · **5466938536** (partly retracted below).

**Status: DRAFTED, NOT POSTED.**

## Before posting

**Identity: `iosoceans`. Settled 2026-08-31 — not a decision, an instruction.** The four existing
comments are `jvspearman` and this one splitting the thread's authorship is accepted and intended.
Verify before posting, because the Bash tool does not get the zsh `gh` wrapper:
`GH_CONFIG_DIR="$HOME/.config/gh-cs2" gh auth status`

Two things that are still constraints, not choices:

1. **The AI disclosure paragraph stays.** `CONTRIBUTING.md` forbids AI-authored *PRs* and explicitly
   permits sharing findings with developers. A comment is the right channel; concealing how the work
   was done would not be.
2. **Resize was re-tested 2026-08-31 and both defects are FIXED** — the draft below now says so,
   with the measurements. What is still open is *flicker during a live mouse drag*, which the
   post-settle captures cannot see either way. Do not upgrade that one to "fixed".

⚠ **No diff in the comment.** Describe the change and name the locations; offer the patches if they
want them. Pasting a diff and asking for it to be applied is a PR wearing a comment's clothes.

---

@3Shain @mikey92 — two things: a retraction I owe you, and what I think is the actual root cause of
the black Steam client.

**Disclosure first, because your CONTRIBUTING.md asks about it:** this investigation was done with
heavy AI assistance. Per your policy I am not opening a PR and there is no AI-authored patch here —
this is a findings report, which the policy explicitly permits. Do with it whatever you think best.

### 1. Retraction

Every "renders but zero glyphs" measurement I posted to this thread was my own bug, not DXMT's.

My launcher and test harness started Steam through `nohup`. macOS purges `DYLD_*` across an exec into
a SIP-protected binary, my self-built wine's `win32u.so` carries only an `@loader_path/` rpath, and
so it silently could not find its own bundled `libfreetype.dylib`. Wine prints one line and continues
**with no font backend**.

What made it hide for a week: DirectWrite still reports **204 font families and `S_OK`**. Only
*rasterisation* is dead. Measured from inside Steam's own process tree:

| | GDI families | DWrite families | rasterises `ABC@32` |
|---|---|---|---|
| broken | 0 | 204, `S_OK` | empty bounds, **0 coverage** |
| fixed | 924 | 204 | `71x23`, 545 non-zero px |

A CEF client in that state draws artwork, gradients and chrome perfectly and not one glyph — which
is indistinguishable in a screenshot from a compositing bug. **So `--in-process-gpu` does not kill
text.** If anyone has been avoiding it on my say-so, they can stop. Anyone can check their own
client in one line:

```
grep -c "cannot find the FreeType font library" <steam stdout/log>
```

### 2. The actual root cause of the black window

`_CreateMetalViewFromHWND` in `winemetal_unix.c` validates all four function pointers it resolves,
then calls the first one and **does not check what it returns**:

```
callq *%r15            ; get_win_data(hwnd)
movq  %rax, %r15
movq  0x18(%rax), %rdi ; <-- win_data->client_cocoa_view, and win_data is NULL
```

`get_win_data()` returns NULL **by construction** here: `win_datas` is a process-local
`CFDictionary`, and CEF's GPU process asks for a Metal view on a **child window whose root lives in
the browser process**. The result is an access violation at `+0x18`, an unhandled exception,
`abort()`, `__fastfail`, and `exit_code=-1073740791`. Chromium restarts the GPU process, it dies
identically, and after ~6 attempts it gives up — black window.

Two things worth flagging about how this hides:

- The `CreateSwapChain` cross-process guard **never fires** for this window, because
  `GetWindowThreadProcessId()` says the *child* is ours. The Win32 process check and winemac's
  realization check disagree, and this path trusts the first.
- The crash is **backend-independent**: `--use-angle=swiftshader` — no Metal, no DXMT, no GPU driver
  — produces the same crash count and a byte-identical black capture. That is what finally pointed
  away from graphics entirely.

### 3. Wine already implements the answer, and DXMT never calls it

`macdrv_client_surface_acquire_metal_swapchain()` builds a `CAContext`-backed offscreen swapchain and
posts `WM_MACDRV_CREATE_REMOTE_LAYER` to the window's **owning** process, which hosts it via
`CALayerHost`. That is exactly the cross-process case. Today only `vulkan.c` reaches it; DXMT has no
client-surface path at all (`main` included).

Wired up — DXMT falling back to that route when `get_win_data()` returns NULL — **Steam's client
renders completely, out-of-process, with text, no shim, no injected switches, 0 GPU crashes.**

That needed a small wine-side change too (the entry has to be reachable, and wine's own
`Cross-process child window Metal swapchains are not implemented` FIXME has to be filled in). One
detail worth passing on if you take this up: I reached it via a **standalone exported symbol rather
than a new `macdrv_functions_t` member**, because that struct is `C_ASSERT`-ed at a fixed size — a
DXMT built against a larger struct would read past the end of an older winemac's and call whatever
followed. A separate symbol just resolves to NULL on an unpatched wine and the code falls through.

### 4. Resize — two more bugs, both in the hosting layer, both now measured

An earlier draft of this called resize "rough" and blamed the destroy/recreate cycle. That was wrong
twice over. There are **two** defects, they are **independent**, and **neither is a race** — both are
steady state and both reproduce on demand.

**(a) A one-device-pixel white seam at the right/bottom edge.** Win32 gives raw pixels, `CALayer`
takes points, and `retina_on` makes that a factor of two — so an **odd** pixel dimension becomes a
`.5` point. The content view is sized in whole points, so the hosted layer lands exactly one device
pixel short of it and the window surface beneath shows through:

```
root 2401x1500 px  ->  hosted layer 1200.5 x 750.0 pt   inside a   1201.0 x 750.0 pt view
capture column x=2401 = 255,255,255                     interior  = 15,25,36
```

The falsification test is cheap, and it passes: **the odd axis is the axis that shows it.**
`2401x1500` → right edge only; `2400x1501` → bottom edge only; `2400x1500` → neither.

**(b) The blackout is z-order.** Hosted layers stack in the order they were **added**, which is
whenever the other process happened to create a swapchain. Steam's client is **two sibling
`CefBrowserWindow` trees** on one root — not a parent and a child, which is what their rectangles
suggest — so any resize that recreated the *lower* browser put its full-window layer on top of the
content layer. Black, and it stayed black because the next resize did it again.
`2400x1500 → 2399x1499 → 2400x1500` reproduced it every time: interior luminance **82 → 1 → 0**.

Both are fixed in `winemac.drv` — (a) by extending a hosted frame to the view's edge only where it
already reaches it, (b) by deriving `zPosition` from Win32 paint order. After: **0 seams across 20
captures**, the blackout sequence measures **63 → 63 → 113**, and 60 alternations at 60 ms end
rendering with 0 GPU crashes.

**Still open:** flicker during a live mouse drag. Every capture after a settle is correct, but a
sub-frame flash while the mouse is down would not show up in a post-settle capture — so that is
untested, not fine.

Happy to send the wine and DXMT patches, the `+seh` traces, the resize measurements, or the harness
if any of it is useful — just say which. The two instruments the resize work needed are small and
generic: a per-monitor-DPI-aware `SetWindowPos` driver (a DPI-unaware process cannot even *request*
the odd sizes that fail) and an edge-vs-interior pixel probe, because a one-device-pixel seam does
not survive a screenshot. And sorry for the noise in the earlier comments: the measurements were real, the
attribution was not.
