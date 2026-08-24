# wine 11.16: fixes the alt-tab freeze. Upstream is clean — one *build* breaks file IO

> **Read the conclusion first (settled 2026-08-23, amended 2026-08-24):** stock wine 11.16,
> compiled from source, is clean *for file IO*. The file-IO regression documented below belongs to
> **WineForge's build**, not to Wine. A DXMT engine on a clean 11.16+ base is better than wine 11.0
> **for the game** — but it is not strictly better: on 2026-08-24 a controlled A/B showed stock
> 11.16 **breaks every embedded-Chromium UI** (Steam's client, the Paradox Launcher), which renders
> fine on 11.0. See §"Second regression" at the foot of this file.

The investigation below is kept in the order it happened, because the intermediate steps are the
evidence for the conclusion.

**Measured 2026-08-23** against WineForge 0.6.0.3 (`wine-11.16 (WineForge 0.6.0.3)` + DXMT v0.80),
using the same probe that produced [`measurement-wine11.0.txt`](measurement-wine11.0.txt): CS2's own
Unity Mono runtime (`scripts/monohost.exe`) running `scripts/filetest_net.exe`, with the game's
shipped `mscorlib` (patched with `fshandle` only — the six errno-tolerance patches deliberately
absent, which is what makes this test meaningful).

## The trade-off

| | wine 11.0 (Porting Kit) | wine 11.16 (WineForge) |
|---|---|---|
| Alt-tab presentation freeze ([dxmt#206](https://github.com/3Shain/dxmt/issues/206)) | **present** | **fixed** |
| File-IO probe | 44 OK / 7 expected-fail | **39 OK / 12 fail** |
| In-game Paradox Mods downloads | work | **would break** (see §11 below) |
| Patches needed | 10 | 16 (the 6 errno-tolerance ones return) |
| Embedded-Chromium UIs (Steam client, Paradox Launcher) | **render** | **black / blank** — see §"Second regression" (measured on *stock* 11.16, 2026-08-24) |

## What regressed

Every new failure carries the same signature — a garbage error code surfacing through Mono's
P/Invoke last-error capture, exactly the R1 defect wine 11.0 had fixed:

```
IOException: "Unknown error (0x100193b0) : '\\?\C:\probe1116\.downloading\74417_17\.metadata'"
```

Operations that pass on 11.0 and fail on 11.16:

- `Directory.Delete(recursive)` — §5, §6, §12
- `Directory.Move` on a directory containing `.metadata` — §9
- `File.Delete(nonexistent)` — §9
- `GetDirectories` / `GetFiles` / `Delete` on a nonexistent directory — §13
- `File.Delete` on an open file — §13 (11.0 raised the *correct* sharing-violation error; 11.16
  raises garbage)

**§11 is the one that matters in practice.** That section replicates
`ClearFolderAndKeepPatchFile` — the real `PrepareFolderForPatching` path in the mod downloader —
and its recursive delete fails. That is precisely the failure that made in-game Paradox Mods
downloads impossible before, and the reason the six errno-tolerance patches exist.

## What did *not* regress

- **Handle-0 still never reproduces**: 120 directory-handle opens, `handle0=0 invalid=0 ok=120`,
  matching 11.0. The rationale for keeping `patch_fshandle` is unchanged.
- Creating nested directories, writing files, enumerating existing directories, and the
  `FileShare.Write`/`FileShare.Read` PdxSdk pattern all still pass.

## ✅ ATTRIBUTION SETTLED (2026-08-23, same day): upstream 11.16 is CLEAN — it is the build

Final measurement: **stock wine 11.16, compiled from the winehq.org source tarball on this
machine** (x86_64, minimal configure, no external patches), same probe, same `mscorlib`:

| build | file-IO probe | garbage-errno lines |
|---|---|---|
| wine 11.0 (Porting Kit) | 44 OK / 7 | 0 |
| stock wine 11.15 (Gcenx) | 44 OK / 7 | 0 |
| **stock wine 11.16 (built from source)** | **44 OK / 7** | **0** |
| WineForge 11.16 | 39 OK / 12 | 15 |

**Upstream Wine never had the regression.** The defect is introduced by WineForge's patch stack
(CrossOver patches / WFDXCompat — which of its patches specifically is their bug to find). Nothing
to file at WineHQ.

**Consequently the ideal upgrade is fully de-risked:** a clean wine-11.16 build carries BOTH the
swapchain fix (retiring the alt-tab freeze, dxmt#206) AND clean file IO (mod downloads keep
working, 10 patches stay 10). As soon as a DXMT-enabled engine appears on a clean 11.16+ base
(Porting Kit's next engine, or a self-build of stock 11.16 + the ~450-line winemac enablement
patch), it is strictly better than wine 11.0. Run the probe once on any new engine to confirm its
base is clean before switching.

## The earlier attribution reasoning (kept for the record — now superseded)
### Attribution: narrowed to the build, not upstream Wine

Follow-up measurements the same day, same probe, same machine, same (patched-only-with-`fshandle`)
`mscorlib`:

| build | file-IO probe | garbage-errno lines | raw Win32 `GetLastError` |
|---|---|---|---|
| wine 11.0 (Porting Kit) | 44 OK / 7 | 0 | — |
| **stock wine 11.15 (Gcenx `wine-devel`)** | **44 OK / 7** | **0** | **9/9 correct** |
| **WineForge 11.16** | **39 OK / 12** | **15** | **9/9 correct** |

Three things this establishes:

1. **Stock upstream Wine is clean at 11.15** — byte-for-byte the same verdicts as 11.0. The defect
   is not something that crept into Wine across fifteen dev releases.
2. **It is not WineForge's sync layer.** The probe was run under their build with
   `WINEESYNC`/`WINEMSYNC` in all four on/off combinations plus their default: 39 OK / 12 fail and
   15 garbage-errno lines every time, identical.
3. **The corruption is in Mono's P/Invoke last-error capture, not in Win32.** `errtest.exe` reports
   `9/9 correct, 0 WRONG` on *both* builds — so the Win32 layer hands back the right error, and
   something about WineForge's build breaks Mono's capture of it. That is the same layer as the
   original R1 defect, which is why WineHQ bug 60220 was correctly closed INVALID against
   `kernel32`.

**What remains unproven:** whether upstream Wine 11.16 itself regressed, or whether WineForge's
patch stack (CrossOver patch IDs, WFDXCompat) is responsible. Settling it needs a *stock* 11.16
build, which does not exist publicly yet — Gcenx's newest is 11.15, and Wine 11.16 was only tagged
2026-08-21. Re-run this probe when one appears.

Given stock 11.15 is clean and a single dev release separates it from 11.16, the build's own patches
are the more likely culprit.

## Practical conclusion

**Do not adopt WineForge's build for this game.** It fixes the freeze but breaks in-game mod
downloads, and the freeze is already fully avoidable by using Fullscreen Window.

The wine-11.16 upgrade path is still worth pursuing — just with a different build. When a stock or
Porting Kit 11.16+ engine with DXMT appears, re-run this probe first. If it comes back 44 OK / 7,
that engine retires the alt-tab freeze at no cost; if it shows the garbage errno, the six
errno-tolerance patches are still in this repo (retired, not deleted) and `repatch.sh` already has
that target.

Until someone validates a full game session on 11.16, **wine 11.0 + Fullscreen Window remains the
recommendation**: the freeze is fully avoidable in borderless, whereas broken mod downloads are not.


---

# Second regression (2026-08-24): stock 11.16 breaks embedded Chromium

The file-IO regression above was WineForge's. **This one is stock Wine's**, and it was found by
A/B-ing the two wrappers that are still installed side by side.

## The controlled comparison

Same Mac, same session, ~10 minutes apart. Everything except the Wine engine held constant and
*verified* constant, not assumed:

| | `CS2dxmt11` (self-built stock **11.16**) | `CS2dxmt11-pk110` (Porting Kit **11.0**) |
|---|---|---|
| DXMT `d3d11.dll` / `dxgi.dll` | 5304320 / 1753088 bytes | **identical** |
| `libMoltenVK.dylib` | 8096560 bytes | **identical** |
| Steam client `-buildid` | 1785799196 | **identical** |
| `steam.exe` / `steamui.dll` mtime | Aug 3 16:46:16 2026 | **identical** |
| `cef_log.txt`: `exit_code=-1073740791` (0xC0000409) | many, every boot | **0** |
| `cef_log.txt`: `minimum Vulkan instance` | present | **0** |
| Steam window, captured per-HWND | 22980 B, **uniform black** | 1405591 B, **full store page, images, everything** |
| Interactive, not just painted | n/a | **yes** — account dropdown opened and navigated by James, same session |

Only the engine differs. **Steam's UI renders on 11.0 and is black on 11.16.**

## What this kills

- **"Steam broke with the ~Aug-2026 CEF update."** Wrong attribution — the CEF/client build is
  byte-identical in both prefixes. It broke when this project promoted the 11.16 engine.
- **"A newer MoltenVK dylib is the fix."** Disproven twice over: the *same* MoltenVK renders Steam
  fine on 11.0, and on 11.16 `-cef-disable-gpu` removes Vulkan from the path entirely without
  changing the symptom. Do not spend a build on it.
- **"CEF presents into its HWND and the surface is lost"** (the winemac/DXMT-presentation theory,
  by analogy with the alt-tab freeze). Also wrong: window surfaces composite fine on 11.16 — the
  Paradox Launcher's window comes through **white** and the game's own window captures 3.4 MB of
  real content. The surface path works; Chromium's GPU process is what dies.

## What it actually is

Chromium's GPU process **fastfails `0xC0000409`** on stock 11.16, three times per browser start,
before ANGLE logs anything. The Vulkan-version failure previously recorded as the root cause is
only what the *4th, fallback* attempt hits.

It is **not Steam-specific**. The Paradox Launcher — a separate Electron app, different Chromium
version, no SDL, no Steam involvement — crashes the same way in the same prefix:

```
GPU process exited unexpectedly: exit_code=-1073740791
error [main]: GPU process crash detected. Skipping quit, hoping that electron will restart itself.
```

So it is an engine-wide Chromium-on-Wine-11.16 defect, not an app bug.

## Next step

**Bisect the engine, don't theorise.** `scripts/build-engine-1116.sh` already builds a sha-pinned
stock engine in ~1 hr; 11.0 → 11.16 is 16 releases, so a binary search is ~4 builds. Reuse the
per-HWND capture (`scripts/winlist.swift` + `screencapture -x -o -l <id>`) as the pass/fail gate,
and count `exit_code=-1073740791` in `cef_log.txt` as the cheap machine-readable signal — no
eyeballing required.

## Practical consequence right now

**Keep `CS2dxmt11-pk110.app`. Do not delete it.** It is currently the only way to use Steam's UI
(purchases, library, settings) on this machine. Play on `CS2dxmt11` (11.16 — faster, no alt-tab
freeze); shop on `CS2dxmt11-pk110` (11.0). Both can hold a Steam resident at once — scope any
process check on the parent (`pgrep -f "<App>.app.*steam.exe"`), never on `steamwebhelper.exe`.
