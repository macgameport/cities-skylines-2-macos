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
split?** If it's the former, then the split may be incidental and the real fix for this issue is
upstreaming that `_CreateMetalViewFromHWND` rewrite plus whatever visibility change it needs — which
is a much more actionable outcome for #141 than anything I've posted. I haven't tried that route
yet: the wine half is ~20 minutes, but I've never built DXMT from source, so it's its own project.

**The ask.** Alongside that, would you run the probe on your stack? ~50 lines, no dependencies:
[`scripts/dxgiprobe.c`](https://github.com/macgameport/cities-skylines-2-macos/blob/main/scripts/dxgiprobe.c),
built with `x86_64-w64-mingw32-gcc dxgiprobe.c -o dxgiprobe.exe -ld3d11 -ldxgi -ldxguid -luuid`,
run in your prefix with the split active. If you get a real adapter at **feature level 11_x**, then
wined3d is serving D3D11 properly on wine 11.0 / macOS 26.5 where mine caps at 9_3 on 11.16 /
26.6.2 — your split is viable and mine is blocked by a feature-level cap, which is a far more
actionable finding than anything else on this thread. If you get **9_3** and `0x887A0004` like me,
then something other than D3D11 is carrying your client and that's worth knowing too.

*(Analysis and testing done with AI assistance, per the project's policy.)*
