# ★ Wine 11.15 fixes the bug. Wine 10.0 does not.

**Measured 2026-08-22.** Same probe, same Unity Mono runtime, same **pristine** `mscorlib`
(unpatched — the patched one would have masked the failure), two Wine versions.

## Result

| test | wine-10.0 Sikarugir | wine-11.15 |
|---|---|---|
| `Marshal.GetLastWin32Error` after P/Invoke | **1525694624 (garbage)** | **0 (correct)** |
| `Directory.Delete(recursive)` | `IOException 0x5af040a0` | OK |
| `Directory.Delete(tree w/ file, RECURSIVE)` | `IOException 0x5af040a0` | OK |
| ManualDelete — empty dir | throws, **GONE=False** | no throw, GONE=True |
| ManualDelete — nested empty subdir | throws, **GONE=False** | no throw, GONE=True |
| ManualDelete — flat dir w/ file | throws, **GONE=False** | no throw, GONE=True |
| `File.Delete(nonexistent)` | `IOException 0x5af040a0` | OK |
| `FindFirstFileW` err | **1525694624 (garbage)** | 127 |
| `ClearFolderAndKeepPatchFile` replica (the `PrepareFolderForPatching` failure) | fails | **ALL OK** |

`0x5af040a0` is pointer-shaped — uninitialised memory, not an error code.

Raw logs: [`measurement-wine10.0.txt`](measurement-wine10.0.txt) ·
[`measurement-wine11.15.txt`](measurement-wine11.15.txt)

## The layer, finally pinned

This is where the earlier bug report went wrong. On **the same wine-10.0 build**:

- **Raw Win32 `GetLastError()` is correct** — `scripts/errtest.c` scores 9/9 across every failure
  path, including `FindNextFile`-exhausted → 18.
- **`Marshal.GetLastWin32Error()` returns garbage** — as measured above.

So the corruption happens in **Mono's P/Invoke last-error capture**, in the transition from the
native call back into managed code. Not in Wine's Win32 implementation. That is precisely why a
native probe could not reproduce it, and why bug
[60220](https://bugs.winehq.org/show_bug.cgi?id=60220) — which blamed `kernel32` — was correctly
closed INVALID.

The symptom described in that report was real. The attribution was not. And it is **already fixed
upstream**, so there is nothing left to file.

## What this means for the patches

Of the 17 patches, the **8 mscorlib/IO ones exist solely to tolerate this garbage errno**:
`patch_dirdel` · `patch_dirhandle` · `patch_delfile` · `patch_delrec` · `patch_dirrec_nx` ·
`patch_delchild` · plus `patch_longdelete` and `patch_createfile` in PdxSdk.

**On a Wine 11-based stack they are very likely unnecessary.** That is now the single highest-value
thing to test: find a **Wine 11 + D3DMetal** engine (Kegworks / Porting Kit ship newer engines than
the Sikarugir 10.0 used here), rebuild the wrapper on it, and re-run with patches removed one at a
time.

⚠️ **Not yet verified in the game.** This probe is single-process and single-threaded. It proves the
Mono/Wine defect is fixed in 11.15; it does not prove the game runs clean without patches. Test
before deleting anything.

## Method note

The measurement only worked because the **pristine** `mscorlib` was staged. Running it against the
patched one would have shown everything passing on both versions and produced the exact opposite
conclusion. When testing whether a workaround is still needed, remove the workaround first.
