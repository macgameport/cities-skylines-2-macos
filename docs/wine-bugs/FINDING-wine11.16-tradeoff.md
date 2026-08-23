# wine 11.16: fixes the alt-tab freeze, breaks file IO again

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

## Attribution: narrowed to the build, not upstream Wine

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
