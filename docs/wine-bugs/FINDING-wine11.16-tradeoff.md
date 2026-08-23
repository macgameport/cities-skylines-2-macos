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

## Attribution is undetermined — read this before acting

Two things differ between the runs, not one: the **Wine version** (11.0 → 11.16) *and* the
**builder** (Porting Kit → WineForge, which carries CrossOver patches). So this measurement
establishes that *this* 11.16 build has the defect; it does **not** establish that upstream Wine
11.16 does. Testing a stock 11.16 build would settle it, and is the obvious next experiment.

## Practical conclusion

A wine-11.16 stack is **viable but not free**: it retires the alt-tab freeze and re-enables
exclusive Fullscreen, at the cost of re-applying the six errno-tolerance patches — all of which are
still in this repo, since they were retired rather than deleted. `repatch.sh` already has that
target: it is the `free` (17-patch) path minus the licence bypass.

Until someone validates a full game session on 11.16, **wine 11.0 + Fullscreen Window remains the
recommendation**: the freeze is fully avoidable in borderless, whereas broken mod downloads are not.
