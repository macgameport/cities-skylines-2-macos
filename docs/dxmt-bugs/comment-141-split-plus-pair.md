# dxmt#141 — fourth evidence comment (2026-08-29)

Draft reply to mikey92's "one cell is still missing" comment. Prior comments on the thread:
5400445243 (stock-vs-vendor sweep) · 5403561498 (`--in-process-gpu`: renders but textless) ·
5458926046 (vanilla-wined3d split, out-of-process: black, byte-identical on wined3d GL vs Vulkan).

Status: **not yet posted.**

---

@mikey92 — you were right, that cell was missing, and thanks for naming it precisely enough to be
testable. I've now run split + `--disable-gpu --single-process` together. It does not work here, but
the failure is specific enough to be useful, and there's a reproduction trap in it that I think is
worth flagging to anyone else trying to combine the two mechanisms.

**First, the trap — my initial run of your cell was invalid and looked fine.**

Wine keys `HKCU\Software\Wine\AppDefaults\<exe>\DllOverrides` on the executable's **file name**. My
wrapper injects switches with a shim that takes the name `steamwebhelper.exe` and renames the real
CEF binary to `steamwebhelper_real.exe`. So my per-app `native` list —
`steam.exe`, `steamwebhelper.exe`, `steamservice.exe` — did not cover the process that actually
loads d3d11, and it fell through to the *global* override, which this split deliberately pins to
`builtin` (= DXMT) so the game keeps it. The cell ran clean and produced a plausible result while
testing the DXMT client. Adding `steamwebhelper_real.exe` to the list fixed it; `+loaddll` inside
the webhelper's own tree then shows `dxgi.dll native`, `wined3d.dll builtin`, no `winemetal`
anywhere, next to `steamwebhelper_real.exe`, `libcef.dll` and ANGLE's `libglesv2.dll`. If your
wrapper renames the binary too, it's worth checking which name your override is keyed on.

**The four cells, one variable at a time**, all judged by per-window `screencapture` on a self-built
stock wine 11.16 + DXMT v0.80 engine (M3 Max, macOS 26.6.2, Aug-2026 client, CEF 126):

| client d3d11 | injected switches | window | CPU | result |
|---|---|---|---|---|
| vanilla wined3d | `--disable-gpu --single-process` (your pair) | **none** | 174 % | hot spin |
| vanilla wined3d | `--in-process-gpu --use-gl=swiftshader` | **none** | 172 % | hot spin |
| vanilla wined3d | `--single-process` | **none** | 173 % | hot spin |
| **DXMT** (control) | `--single-process` | **yes** | **9 %** | **1,810,329 B — renders, zero glyphs** |

The control is there because three consecutive "no window" readings should not be trusted on their
own — it reproduces my 2026-08-28 result on the same harness in the same session, so the rig was
working.

**Why the split fails here — ANGLE names it, so this isn't inference.** On vanilla wined3d, *every*
EGL display type fails in turn:

```
Renderer11.cpp:1108 (rx::Renderer11::populateRenderer11DeviceCaps):
    Error querying driver version from DXGI Adapter.                        <- D3D11
eglCreateContext: Requested GLES version (3.0) is greater than max supported (2, 0).   <- GL
eglInitialize SwANGLE failed with error EGL_NOT_INITIALIZED
    Internal Vulkan error (-9): The requested version of Vulkan is not supported ...   <- SwANGLE
Initialization of all EGL display types failed.
GLDisplayEGL::Initialize failed.
gl_factory_win.cc(63)] NOTREACHED hit.     <- then ~1,043,304 times in one 95 s cell
```

That inverts the intuition the split is built on. On this stack **DXMT is the only D3D11 that gives
Chromium a working ANGLE display** — its DXGI answers `populateRenderer11DeviceCaps`, vanilla
wined3d's doesn't, and neither fallback is available (wined3d's GL backend caps at GLES 2.0 here,
consistent with the `GL_INVALID_FRAMEBUFFER_OPERATION from glClear` I reported earlier on macOS 26;
SwANGLE's Vulkan is rejected outright). Taking DXMT out of the client's path removes the one path
that initializes. That's also why your pair is worse than either flag alone for me: with no
hardware GPU path *and* one process, there is nothing left for ANGLE to pick.

**On the Battle.net data point:** `--use-gl=swiftshader` is a dead switch on this CEF — modern
Chromium moved software selection to `--use-angle=swiftshader`. I'd measured that one back on
2026-08-24 (with `--in-process-gpu`, plus `vulkan-1=n,b` to force pure software) and it renders art
with no glyphs like every other in-process route, which is what ruled out DXMT's glyph-atlas
support as the cause. The `--use-gl` spelling is actively worse: it turns a *working*
`--in-process-gpu` cell into the same NOTREACHED loop above.

**`-noverifyfiles` — noted and useful, thank you.** My shim is zero-padded to the original's exact
byte count, which passes because Steam's bootstrap log says "Verifying file sizes only", so I
didn't need it. But padding is the fragile half of that trick and `-noverifyfiles` isn't, so it's
the better answer if Valve ever moves from sizes to hashes.

**The question your result raises, and the one thing that would settle it:** your config works, so
on your machine ANGLE must be successfully initializing *some* EGL display type where all three of
mine fail. Could you grep your `logs/cef_log.txt` for `eglInitialize`, `Renderer11`,
`gl_display.cc` and `Initialization of all EGL display types`? If yours initializes D3D11 on
wined3d, the variable is the wined3d version (your 11.0 vs my 11.16) rather than the split itself.
If yours comes up on the GL path, then the variable is likely GLES 3.0 availability — which would
point at macOS 26.5 vs 26.6.2 and would be a much more interesting finding than either of us
expected.

Happy to run anything else on this setup.

*(Analysis and testing done with AI assistance, per the project's policy.)*
