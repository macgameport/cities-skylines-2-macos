# CS2 macOS patch inventory

**Game:** Cities: Skylines II `1.6.4f1` (Steam build 26404411, since 2026-11-10; `patch_cohtml` re-derived 2026-11-12). Before that `1.6.2f1` (build 25127643; re-derived 2026-10-10), and 1.6.0f1 `419.d6c6`
**Stack:** self-built stock Wine 11.16 + DXMT (`~/Applications/CS2dxmt11.app`): needs **10** of these patch
scripts. The other six are for an engine with the errno defect (`CS2_ERRNO_PATCHES=1`). An older Wine 10 +
D3DMetal stack was retired from this repository on 2026-11-09.
**Applied by:** `~/cs2-patch/repatch.sh dxmt11` — idempotent, self-verifying (byte pattern, or by-name method lookup for the PDX.SDK five), each writes a `.bak`
**Last verified:** 2026-11-12 — 1.6.4f1: `setup.sh` reported 10 of 10 patch scripts finished without error after the `patch_cohtml` re-derivation, and boot-verify PASS (`20261112-155937`, the main menu); the other nine were not re-read against the new build. Before that 2026-10-10 — 1.6.2f1 re-derivation: all 10 dxmt11 patches + badge applied, boot-verify PASS ×3 and a forced mod re-download (C73); before that 2026-09-03, when targets and patch counts were re-measured against `repatch.sh`; the
in-game verification behind §1 is 2026-08-22

> **These are not bugs in this project's code.** Every entry is a workaround for a defect in
> something else. ⚠️ **The §1 root-cause analysis below was partly disproven on 2026-08-22** — see
> [`wine-bugs/FINDING-wine11-fixes-it.md`](wine-bugs/FINDING-wine11-fixes-it.md). Measured result:
> **moving to Wine 11 drops the applied set from 16 to 10** — the six errno-tolerance patches go —
> and Wine 11 also fixed the bcrypt defect (R3, §4), so the game's UI middleware verifies its own licence
> there. Both verified in-game: a fresh mod download, and the main menu reached with zero licence errors.
> `patch_fshandle` is still needed there; R1 and R2 as originally stated are false.
>
> ⚠ **The numbers.** Entries keep the numbers 1 to 17 they have always had here, and there is no number 5:
> it described a Wine 10 workaround for R3 that was never in this repository (§4). **16** patch scripts
> exist. Measured 2026-09-03 against `repatch.sh`: 16 patch invocations, 6 of them behind `ERRNO_PATCHES`,
> which is off by default: hence **10**.

## The three upstream root causes

| # | Root cause | Owner | Patches it forces |
|---|---|---|---|
| **R1** | `GetLastError` / `Marshal.GetLastWin32Error()` returns **garbage** after file APIs — including on *success* and on the *non-success* return of failing calls. Callers can't distinguish "not found" from a real failure. | **Wine** (macOS) | 2, 6, 7, 8, 9, 10, 11, 15 |
| **R2** | `CreateFile` returns **handle value 0 for a valid open file**. .NET's `SafeFileHandle` derives from `SafeHandleZeroOrMinusOneIsInvalid`, so a usable handle is judged invalid. | **Wine** (macOS) | 3, 12 |
| **R3** | `BCryptVerifySignature` (Windows CNG) **fails on valid ECDSA signatures**. | **Wine** (macOS) | none in this repository; fixed in Wine 11 |

A fourth, narrower one: under **concurrent** IO, metadata-query APIs (`GetFileAttributesW`,
`FindFirstFile`) return a false "exists" for a missing file, while *opening* the file
(`CreateFile`) reports correctly every time. Forces patch 16.

## 1. Wine file-API error reporting (R1) — `mscorlib.dll`

| # | Patch | Target method | Symptom |
|---|---|---|---|
| 6 | `patch_dirdel` | `FileSystem.RemoveDirectoryRecursive` @IL 0x163 | `Directory.Delete(recursive:true)` throws instead of removing the dir |
| 7 | `patch_dirhandle` | `FileSystemEnumerator.CreateDirectoryHandle` | enumerating a not-yet-created dir throws `IOException: Success` instead of returning empty |
| 8 | `patch_delfile` | `FileSystem.DeleteFile` | `File.Delete` throws on a garbage errno |
| 9 | `patch_delrec` | `FileSystem.RemoveDirectoryInternal` | final/non-recursive removal throws "I/O error occurred" |
| 10 | `patch_dirrec_nx` | `FileSystem.RemoveDirectoryRecursive` | recursive delete of a **nonexistent** dir throws instead of no-op |
| 11 | `patch_delchild` | `FileSystem.RemoveDirectoryRecursive` | a child file/subdir failure is rethrown, aborting the whole delete |

## 2. Wine handle-0 (R2)

| # | Patch | Target | Symptom |
|---|---|---|---|
| 3 | `patch_longfile` | `Colossal.IO.dll` → `LongFile.GetFileHandle` | `IOException … <settings>.coc: Success.` dialog on settings read/write |
| 12 | `patch_fshandle` | `mscorlib.dll` → `FileStream.Init` | every-boot `ArgumentException: Invalid handle` → "Failed to read settings file with GUID …"; settings fall back to defaults; mod conflict alerts. **Second site** — `patch_longfile` fixes Colossal's throw, mscorlib then validates the handle *again*. ⚠ **A THIRD site exists and still throws** (2026-08-31): `FileStream.Init` `[0x0006a]` raises `IOException: Invalid handle to path "[Unknown]"` — different type, different message, so a grep for the documented `ArgumentException` reports success while 8 settings files still fall back to defaults. See `docs/wine-bugs/R2-createfile-handle-zero.md`. |

## 3. Wine, other — Colossal Order binaries

| # | Patch | Target | Symptom |
|---|---|---|---|
| 1 | `patch_cohtml` | `cohtml_unity3dplugin.dll` | crash during UI init on the GPTK/D3DMetal path. One `je`→`jne` at the top of the plugin's D3D11 state-restore release function. **What it really does (disassembled 2026-10-10):** the plugin saves Unity's pipeline state with ~33 `ID3D11DeviceContext` Get calls, restores it, then `Release()`s every captured COM reference; the flip makes that function return early whenever state was captured, so the references are deliberately **leaked**. That only avoids a crash if the translation layer under-counts references in its Get methods. Not an `IAllocator` fix (no such string in the binary). Re-derived for 1.6.2f1: same 1,604-byte function, moved; the patcher now also anchors on the function's own bytes. Re-derived again for 1.6.4f1 (2026-11-12): the same function with the object kept in `rbx` where it was in `rsi` (1,611 bytes, the same 45 `Release()` call sites), which the patcher matches as `fn-rbx`. Kept applied on DXMT because it is the long-proven configuration; whether DXMT needs it is untested (the unpatched 1.6.2f1 build reached the menu once). Community fix, credit **manolz1/cities2-gptk-fix** |
| 2 | `patch_colossal_io` | `Colossal.IO.dll` → `EnumerateFileSystemIterator[Recursive]` | startup crash — Win32 error check after `FindNextFile` reads garbage (R1) |
| 4 | `patch_asset_database` | `Colossal.IO.AssetDatabase.dll` → `PopulateFromDirectory` | `File.Exists` wrong under Wine → bogus `.priority` read |

## 4. Wine crypto (R3)

Wine 10's `BCryptVerifySignature` failed on a valid ECDSA signature, so Coherent Gameface, the game's UI
middleware, rejected its own valid embedded licence and the game stopped before the main menu. Wine 11
fixed it (measured 2026-08-22), and that is the fix. No patch for it is in this repository or ever was:
[`../patches/README.md`](../patches/README.md), "Which patches the game needs".

## 5. Paradox `PDX.SDK.dll` — mod downloads

| # | Patch | Target | Symptom / cause |
|---|---|---|---|
| 13 | `patch_mkparent` | `DiskIODefaultWindows.CreateFileStream` | nested download dirs don't exist → `DirectoryNotFoundException`. Prepends `Directory.CreateDirectory(dirname)`. The body is relocated into `.text`'s file padding and, since 2026-10-10, `.text` VirtualSize is raised to SizeOfRawData so any loader maps it (suggested in #15) |
| 14 | `patch_lockbypass` | `AcquireLockResult.GetError` | lock reports "UNKNOWN" failure under Wine threading; force `null` so the caller proceeds |
| 15 | `patch_longdelete` | `DeleteLongPathFile` / `DeleteLongPathDirectory` | PdxSdk's **own second IO layer** for long paths, same R1 garbage-errno throws |
| 16 | `patch_createfile` | `LongPathFileExists` / `LongPathDirectoryExists` | under concurrency both metadata queries false-positive on a missing file → integrity check reads a not-yet-downloaded `.zip` → abort **before** download. Rewritten to test existence by *opening*. Since 1.6.2f1 the bodies are rewritten **in place**; the 1.6.0f1 version relocated them to RVAs that mapped to no section and was never runnable (C71) |
| 17 | `patch_lockleak` | `<CreateFileStream>d__25.MoveNext` | **A genuine Paradox bug, not a Wine one.** The method has two `catch` clauses and **no `finally`**; the catch handler never disposes the lock acquired at IL 0x78/0x82 (the FileNotFound path at 0x120 does). Any throw leaks the per-path lock forever; the next waiter dies on `GetLockToken`'s timeout. Would bite on Windows too, given the right timing. |

**Superseded — do NOT re-apply.** `patch_pdxsdk_io` (`ResultFactory.CreateIoResultFromException` →
force Success) *masks* failures rather than fixing them: the delete never happens, downloads wait
forever, and boot NREs on empty mod state. `patch_dirdel` is the correct layer.

**Also rejected**, each after a live test — all four chased a "reader→writer upgrade deadlock" that
**does not exist** (IL 0x6c–0x87 of `<CreateFileStream>d__25` is an `if/else` on `FileAccess`, so
exactly one lock is taken per call): `patch_locksem` (breaks SDK init — the lock needs `(1,1)` mutex
semantics) · `patch_writenowait` (breaks fetch ordering) · `patch_readerinit` (relocating the `.ctor`
breaks early-init resolution) · `patch_readerskip` (valid IL, clean init, but crashes boot — the lock
is load-bearing for `Colossal.IO.AssetDatabase` concurrent caching).

## What to do upstream

Ranked by how many patches it retires:

1. **File a Wine bug for R1** — `GetLastError` on file-API failure/success paths. Retires 8 patches.
   Deterministic reproducer already built: `scripts/monohost.c` + `scripts/filetest_net.cs` (build per `scripts/README.md`)
   (sections `[5][6][7][10]`–`[13]`), runs under CS2's exact Unity Mono with no game launch.
2. **File a Wine bug for R2** — `CreateFile` returning handle 0 for a valid file. Retires 2.
3. ~~File a Wine bug for R3~~ — `BCryptVerifySignature` on valid ECDSA is fixed in Wine 11 (measured
   2026-08-22). Nothing to file.
4. **Report #17 to Paradox** — the leaked lock is a real cross-platform defect with a clean fix
   (dispose the lock in the catch handler, or add a `finally`).

## Method notes

- Every patch **verifies before it writes** (byte pattern, or by-name lookup + full original IL for
  the PDX.SDK five): it refuses if the code moved or changed (game update), rather than corrupting
  the binary. `.bak` = pristine original — a refresh-on-update rule varies by script, so check that
  a `.bak` predating an update is not left holding the OLD build (2026-10-10: two were).
- **Prefer in-place edits** (same byte count) over relocation — no branch-target, offset or
  exception-handler-clause shifts. Relocating a `.ctor` specifically breaks early-init resolution.
- **Verify stack balance on both branch paths** before applying; an unbalanced edit yields
  "Invalid IL at IL_xxxx" at runtime, not at patch time.
- **Boot-verify after any `mscorlib` change** — it is on the boot path.
- Re-derive offsets after a game update with
  `python3 patches/dis_pdx.py <dll> <Type> <Method>`.
