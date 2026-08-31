# dxmt#141 — fifth comment: retraction + the actual root cause

Prior comments: 5400445243 · 5403561498 · 5458926046 · **5466938536** (partly retracted below).

**Status: DRAFTED, NOT POSTED.**

## Before posting — three decisions

1. **Identity.** The four existing comments are `jvspearman`. James chose `iosoceans` for this
   project going forward; posting this one as `iosoceans` splits the thread's authorship mid-
   conversation. Verify either way:
   `GH_CONFIG_DIR="$HOME/.config/gh-cs2" gh auth status`
2. **The AI disclosure paragraph stays.** `CONTRIBUTING.md` forbids AI-authored *PRs* and explicitly
   permits sharing findings with developers. A comment is the right channel; concealing how the work
   was done would not be.
3. **Resize state is unsettled.** The draft says so. Do not soften it before James has re-tested.

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

### 4. What is not solved

Resize is rough: CEF resizes by destroying and recreating a swapchain, so the hosted layer is
un-hosted before its replacement exists — flicker, and sometimes a child that stays black.
`CAContextSwapChain` also fixes its layer bounds at init with no way to resize them, so the hosted
layer keeps its original size while the host frame moves on. I have partial mitigations for both and
would not call either finished.

Happy to send the wine and DXMT patches, the `+seh` traces, or the harness if any of it is useful —
just say which. And sorry for the noise in the earlier comments: the measurements were real, the
attribution was not.
