# dxmt#141 — fourth evidence comment (2026-08-29)

Draft reply to mikey92's "one cell is still missing" comment. Prior comments on the thread:
5400445243 (stock-vs-vendor sweep) · 5403561498 (`--in-process-gpu`: renders but textless) ·
5458926046 (vanilla-wined3d split, out-of-process: black — **partially retracted below**).

Status: **not yet posted.**

---

@mikey92 — you were right that a cell was missing, and running it turned up something better than
an answer to that question: **a correction to my previous comment on this thread.** Short version —
my split was broken, so [#5458926046](https://github.com/3Shain/dxmt/issues/141#issuecomment-5458926046)
compared DXMT against a D3D11 that never worked. The route is still dead on my machine, but for a
completely different and much more specific reason, and it gives you a 10-second check that would
tell us why your setup works and mine doesn't.

**1. The retraction.** I wired the split with soju's technique — strip the `"Wine builtin DLL\0"`
marker at file offset `0x40` so a `native` override loads a wine-built PE — and verified it with
`+loaddll`, which duly showed `d3d11.dll … native` inside Steam's processes. That proved the PE
**loaded**. It did not prove it **worked**, and it didn't. I wrote a 50-line probe that calls the
exact query ANGLE fails on and then creates a device, and on the marker-stripped `native` d3d11 it
never reaches its first `printf`:

```
wine: Call from ... to unimplemented function dxgi.dll.DXGID3D10CreateDevice, aborting
```

— with either dxgi underneath it. So "the split landed and Steam is still black, byte-identical on
wined3d's GL and Vulkan renderers" was measuring a d3d11 that aborts at device creation. That
comparison carried no information about DXMT and I shouldn't have drawn the conclusion I did from
it. **A module load is not a working implementation** — that's on me.

**2. Wired properly, vanilla wined3d does work — and is still disqualified, measurably.** Installing
the same vanilla PEs as *true builtins* (marker intact) in a cloned wine tree, driven from a scratch
prefix:

| configuration | adapter reported | `CheckInterfaceSupport(IDXGIDevice)` | `D3D11CreateDevice` |
|---|---|---|---|
| **DXMT v0.80** | **Apple M3 Max** (0x106B / 0x1A0603F1) | **`S_OK`** | **FL `0xB000` = 11_0** |
| vanilla wined3d, GL renderer | "NVIDIA GeForce 6800" (0x10DE/0x0041 — the fallback card) | `0x887A0004` `DXGI_ERROR_UNSUPPORTED` | FL `0x9300` = **9_3** |
| vanilla wined3d, `renderer=vulkan` | **Apple M3 Max** (correct) | `0x887A0004` `DXGI_ERROR_UNSUPPORTED` | FL `0x9300` = **9_3** |

Two things there are worth more than the whole earlier investigation:

- **`0x887A0004` is `Renderer11.cpp:1108`.** ANGLE's `Error querying driver version from DXGI
  Adapter` is literally wined3d's dxgi returning `DXGI_ERROR_UNSUPPORTED` from
  `CheckInterfaceSupport`, where DXMT returns `S_OK`. That's a measured API delta now, not an
  inference from a CEF log.
- **wined3d gives me feature level 9_3; DXMT gives 11_0.** That holds even with the Vulkan renderer
  correctly identifying the M3 Max, so it isn't the fallback-adapter bug. A 9_3 device can't serve
  Chromium's D3D11 backend — which is why, on *this* machine, the split can't work no matter how
  it's wired.

**3. The combined cells you asked for**, for completeness — split plus injected switches, capture-
judged, with a control:

| client d3d11 | switches | window | CPU |
|---|---|---|---|
| vanilla wined3d | `--disable-gpu --single-process` (your pair) | none | 174 % |
| vanilla wined3d | `--single-process` | none | 173 % |
| vanilla wined3d | `--in-process-gpu --use-gl=swiftshader` | none | 172 % |
| **DXMT** (control) | `--single-process` | **yes** | 9 % — 1,810,329 B, zero glyphs |

⚠ **A reproduction trap worth flagging if your wrapper renames the webhelper:** wine keys
`AppDefaults` on the executable's **file name**, and my shim takes the name `steamwebhelper.exe`
while the real CEF binary becomes `steamwebhelper_real.exe`. My first run of your cell therefore
missed the only process that loads d3d11 and fell through to the global `builtin` (= DXMT). It ran
clean and looked completely valid.

**4. `--use-gl=swiftshader` is a dead switch on this CEF.** Chromium moved software selection to
`--use-angle=swiftshader`, which I'd measured back on 08-24 — renders art, no glyphs, like every
in-process route. The `--use-gl` spelling turns a *working* `--in-process-gpu` cell into the
`gl_factory_win.cc(63)` NOTREACHED loop. Good Battle.net data point, but it doesn't transfer here.

**5. `-noverifyfiles` — thanks, that's the better half of the trick.** My shim is zero-padded to the
original's byte count, which passes because Steam's bootstrap says "Verifying file sizes only", but
padding is the fragile part and yours isn't.

**The ask, and it's small.** Would you run the probe on your setup? It's ~50 lines, no dependencies:
[`scripts/dxgiprobe.c`](https://github.com/macgameport/cities-skylines-2-macos/blob/main/scripts/dxgiprobe.c),
built with
`x86_64-w64-mingw32-gcc dxgiprobe.c -o dxgiprobe.exe -ld3d11 -ldxgi -ldxguid -luuid`, run inside
your prefix with the split active. If it prints a real adapter with feature level **11_0**, then
wined3d is genuinely serving D3D11 properly on your stack and the variable between us is wine 11.0
vs 11.16 or macOS 26.5 vs 26.6.2 — which would make your split legitimately viable and mine
blocked by a feature-level cap, a far more useful conclusion than "it's the presentation layer".
If you get 9_3 and `0x887A0004` like me, then something other than D3D11 is carrying your client
and that's worth knowing too.

*(Analysis and testing done with AI assistance, per the project's policy.)*
