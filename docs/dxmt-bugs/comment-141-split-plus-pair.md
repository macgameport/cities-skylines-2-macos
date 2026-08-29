# dxmt#141 — fourth evidence comment (2026-08-29)

Draft reply to mikey92's "one cell is still missing" comment. Prior comments on the thread:
5400445243 (stock-vs-vendor sweep) · 5403561498 (`--in-process-gpu`: renders but textless) ·
5458926046 (vanilla-wined3d split, out-of-process: black — **retracted below**).

Status: **not yet posted.**

---

@mikey92 — you were right that a cell was missing, and chasing it turned up something more useful
than an answer to it: **my previous comment on this thread was wrong, and I need to retract it.**
My split was broken, so
[#5458926046](https://github.com/3Shain/dxmt/issues/141#issuecomment-5458926046) compared DXMT
against a D3D11 that never worked. Here's the corrected picture, plus a small ask that would tell
us why your setup works and mine doesn't.

**1. The retraction.** I wired the split with soju's technique — strip the `"Wine builtin DLL\0"`
marker at file offset `0x40` so a `native` override loads a wine-built PE — and verified it with
`+loaddll`, which duly showed `d3d11.dll … native` inside Steam's processes. That proved the PE
**loaded**. It did not prove it **worked**, and it didn't. A 50-line probe that creates a device
never reaches its first `printf` on that wiring:

```
wine: Call from ... to unimplemented function dxgi.dll.DXGID3D10CreateDevice, aborting
```

— with either dxgi underneath it. So "the split landed and Steam is still black, byte-identical on
wined3d's GL and Vulkan renderers" was measuring a d3d11 that aborts at device creation. It carried
no information about DXMT, and the conclusion I drew from it — that the client's black window was
never DXMT's missing cross-process swapchain — is **not supported**. **A module load is not a
working implementation.** That one's on me.

⚠ **It also invalidates every Steam-side cell I've run against the split, on both dates** — they
were all on that wiring. So I can't tell you what your pair does on a *working* vanilla-wined3d
client; nobody has measured that here. The marker-strip trick can't be fixed into one, either: the
wiring that does work is engine-global, which would take DXMT away from the game too. A valid test
needs a separate wrapper, which I haven't built yet.

**2. What a correctly-wired vanilla wined3d actually does.** Installing the same vanilla PEs as
*true builtins* (marker intact) in a cloned wine tree, driven from a scratch prefix — self-built
stock wine 11.16, M3 Max, macOS 26.6.2:

| configuration | adapter reported | `CheckInterfaceSupport(IDXGIDevice)` | max feature level |
|---|---|---|---|
| **DXMT v0.80** | **Apple M3 Max** | **`S_OK`** | **`0xB100` = 11_1** |
| vanilla wined3d, GL renderer | "NVIDIA GeForce 6800" (0x10DE/0x0041 — the fallback card) | `0x887A0004` `DXGI_ERROR_UNSUPPORTED` | `0x9300` = **9_3** |
| vanilla wined3d, `renderer=vulkan` | **Apple M3 Max** (correct) | `0x887A0004` `DXGI_ERROR_UNSUPPORTED` | `0x9300` = **9_3** |

Two measured deltas, and I asked for the feature level **both ways** — `pFeatureLevels=NULL` and an
explicit `{11_1, 11_0, 10_1, 10_0, 9_3}` array — because a single-form reading is exactly how you
publish a wrong number. Same answer both times.

- **`0x887A0004` is `Renderer11.cpp:1108`.** ANGLE's `Error querying driver version from DXGI
  Adapter` is literally wined3d's dxgi returning `DXGI_ERROR_UNSUPPORTED` from
  `CheckInterfaceSupport`, where DXMT returns `S_OK`. That's an API delta now, not an inference
  from a CEF log.
- **wined3d gives me feature level 9_3; DXMT gives 11_1** — even with the Vulkan renderer correctly
  identifying the M3 Max, so it isn't the fallback-adapter bug.

I'll stop short of the obvious next sentence: I *can't* yet say FL 9_3 is what breaks CEF. The
`Requested GLES version (3.0) is greater than max supported (2, 0)` line in my `cef_log.txt` is
consistent with an ANGLE D3D11 display on a sub-10_0 device, but it was logged on the broken wiring
where ANGLE may never have reached a D3D11 device at all. Correlation, not chain.

**3. `--use-gl=swiftshader` is a dead switch on this CEF.** Chromium moved software selection to
`--use-angle=swiftshader`, which I'd measured on 08-24 — renders art, no glyphs, like every
in-process route. The `--use-gl` spelling turns a *working* `--in-process-gpu` cell into a
`gl_factory_win.cc(63)` NOTREACHED loop. Good Battle.net data point; it doesn't transfer here.

**4. A reproduction trap, if your wrapper renames the webhelper.** Wine keys `AppDefaults` on the
executable's **file name**. My shim takes the name `steamwebhelper.exe` and the real CEF binary
becomes `steamwebhelper_real.exe` — so my first run of your cell missed the only process that loads
d3d11 and silently fell through to the global override. It ran clean and looked completely valid.

**5. `-noverifyfiles` — thanks, that's the better half of the trick.** My shim is zero-padded to the
original's byte count, which passes because Steam's bootstrap says "Verifying file sizes only", but
padding is the fragile part and yours isn't.

**The ask, and it's small.** Would you run the probe on your setup? ~50 lines, no dependencies:
[`scripts/dxgiprobe.c`](https://github.com/macgameport/cities-skylines-2-macos/blob/main/scripts/dxgiprobe.c),
built with `x86_64-w64-mingw32-gcc dxgiprobe.c -o dxgiprobe.exe -ld3d11 -ldxgi -ldxguid -luuid`,
run inside your prefix with the split active. If you get a real adapter at **feature level 11_x**,
then wined3d is genuinely serving D3D11 on your stack, the variable between us is wine 11.0 vs
11.16 or macOS 26.5 vs 26.6.2, and your split is legitimately viable where mine is capped — a far
more useful conclusion than the presentation-layer one I posted. If you get **9_3** and
`0x887A0004` like me, then something other than D3D11 is carrying your client, and that's worth
knowing too.

*(Analysis and testing done with AI assistance, per the project's policy.)*
