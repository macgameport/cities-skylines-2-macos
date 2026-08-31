# dxmt#141 — fifth comment: the glyph loss was mine, and the real blocker is upstream of DXMT

Prior comments: 5400445243 · 5403561498 · 5458926046 · **5466938536** (the one this corrects).

Status: **DRAFTED, NOT POSTED.** Posting is James's call — it is a public correction on someone
else's tracker. ⚠ The four existing comments went out as `jvspearman`; posting this one as
`iosoceans` would split the thread's authorship mid-conversation. Match the existing three unless
James decides otherwise. Verify first: `GH_CONFIG_DIR="$HOME/.config/gh-cs2" gh auth status`.

**Rewritten 2026-08-30 (evening).** The first draft was a straight retraction of the glyph claims.
Later the same day the actual cause was found and fixed, and the out-of-process failure was traced —
so this is now a diagnosis plus a fix plus a measurement, which is worth far more to the thread than
an apology. Keep it that way: lead with what someone else can use.

---

@mikey92 @3Shain — correcting [#5466938536](https://github.com/3Shain/dxmt/issues/141#issuecomment-5466938536),
and the correction turns out to be useful rather than just embarrassing.

**Every "zero glyphs" measurement I have posted to this thread was my own bug.** Not CEF's, not
DXMT's, not macOS's. If you have been avoiding `--in-process-gpu` because I reported it kills text,
**you can stop** — it does not.

**What actually happened.** My render harness — and my launcher — started Steam through `nohup`.
macOS **purges `DYLD_*` when exec'ing a SIP-protected system binary**, and `/usr/bin/nohup` is one
(so are `env` and `/bin/bash`). My self-built wine's `win32u.so` carries only an `@loader_path/`
rpath, so with `DYLD_FALLBACK_LIBRARY_PATH` stripped it could not find its own bundled
`libfreetype.dylib`. Wine prints one line about it and continues **with no font backend**:

```
Wine cannot find the FreeType font library.
```

DirectWrite then still reports **204 font families with `S_OK`** — which is why this hid for a week;
every check I ran said fonts were fine — but it **rasterises nothing**. Measured from inside Steam's
own process tree, via a probe compiled into my webhelper shim:

| | GDI families | DWrite families | DWrite rasterises `ABC@32` |
|---|---|---|---|
| broken (no `DYLD_*`) | 0 | **204**, `S_OK` | **empty bounds, 0 coverage** |
| fixed | 924 | 204 | `71x23`, 545 non-zero px |

A CEF client in that state draws artwork, thumbnails, gradients and chrome perfectly and **not one
glyph**. That is *identical in a screenshot* to a font/compositing bug, and I misattributed it four
times.

**The fix, if your engine has the same shape.** Porting Kit's `win32u.so` carries
`@loader_path/../../` as well as `@loader_path/`, which is why PK builds never showed this and mine
did. One command on a stock build, no rebuild required:

```sh
install_name_tool -add_rpath "@loader_path/../../" .../lib/wine/x86_64-unix/win32u.so
codesign -f -s - .../lib/wine/x86_64-unix/win32u.so    # add_rpath invalidates the ad-hoc signature
```

Same for `dwrite.so`, `crypt32.so`, `secur32.so` — the other modules that `dlopen` a bare soname.
After that, launching through `nohup` with every `DYLD_*` unset resolves fonts cleanly: **63
FreeType failures → 0**.

**Anyone can check their own client in one line:**

```sh
grep -c "cannot find the FreeType font library" <steam stdout/log>
```

Non-zero and your client has been rendering without a font backend, whatever else you were measuring.

**So, corrected results.** With fonts working, `--in-process-gpu` (injected at the webhelper, since
`steam.exe` filters it) renders the Steam client **completely, with text** on stock wine 11.16 +
DXMT v0.80 — menus, nav, store copy, review counts. Screenshot attached. The only cost I can find is
**flicker while the store tab autoplays video**; the library is clean.

**The part that matters for this issue.** I also went after the out-of-process case properly, and I
think it changes where the thread should be looking:

- Out-of-process, Chromium's **GPU process crashes ~6 times per launch and Chromium gives up**,
  every one `exit_code=-1073740791` (`0xC0000409`).
- That is **backend-independent**. `--use-angle=swiftshader` — pure software, no Metal, no DXMT, no
  GPU driver — produces the **same crash count and a byte-identical black window**.
- Traced with `WINEDEBUG=+seh`: a **null read at offset `0x18` inside a wine syscall**
  (`handle_syscall_fault code=c0000005 … info[1]=0x18`), which surfaces as an unhandled AV and
  becomes `abort()` → `__fastfail(7)` in the process's `ucrtbase`.
- Consequently the cross-process swapchain path is **never reached at all**. I built DXMT v0.80 with
  the `CreateSwapChain` cross-process guard removed and env-gated, ran it with a `winemac.so` patched
  for foreign HWNDs and child windows, and the forced path **logged zero times** — because the GPU
  process is already dead.

**So the cross-process-presentation limitation is real but it is not what blocks Steam here.**
Something kills the GPU process before it ever asks DXMT for a swapchain, and it is not graphics.
That looks like a wine bug rather than a DXMT one, and I would rather say so than keep filing
DXMT-shaped reports at it.

Happy to post the `+seh` traces, the shim source, or the fingerprint harness if any of that is
useful. Apologies for the noise in the earlier comments — the measurements were real, the
attribution was not.
