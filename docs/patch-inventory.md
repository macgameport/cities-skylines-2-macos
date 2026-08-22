# CS2 macOS patch inventory

**Game:** Cities: Skylines II `1.6.0f1 (419.d6c6)`
**Stack:** Kegworks/WineskinNavy wrapper (`~/Applications/S734M.app`) — Wine 10.0 Sikarugir + D3DMetal v2.1
**Applied by:** `~/cs2-patch/repatch.sh [free]` — idempotent, pattern-matched, each writes a `.bak`
**Last verified:** 2026-08-22

> **These are not bugs in this project's code.** Every entry is a workaround for a defect in
> something else — overwhelmingly **Wine**. If the three Wine bugs in §1 were fixed upstream,
> **12 of the 17 patches below would become unnecessary.**

## The three upstream root causes

| # | Root cause | Owner | Patches it forces |
|---|---|---|---|
| **R1** | `GetLastError` / `Marshal.GetLastWin32Error()` returns **garbage** after file APIs — including on *success* and on the *non-success* return of failing calls. Callers can't distinguish "not found" from a real failure. | **Wine** (macOS) | 2, 6, 7, 8, 9, 10, 11, 15 |
| **R2** | `CreateFile` returns **handle value 0 for a valid open file**. .NET's `SafeFileHandle` derives from `SafeHandleZeroOrMinusOneIsInvalid`, so a usable handle is judged invalid. | **Wine** (macOS) | 3, 12 |
| **R3** | `BCryptVerifySignature` (Windows CNG) **fails on valid ECDSA signatures**. | **Wine** (macOS) | 5 |

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
| 12 | `patch_fshandle` | `mscorlib.dll` → `FileStream.Init` | every-boot `ArgumentException: Invalid handle` → "Failed to read settings file with GUID …"; settings fall back to defaults; mod conflict alerts. **Second site** — `patch_longfile` fixes Colossal's throw, mscorlib then validates the handle *again*. |

## 3. Wine, other — Colossal Order binaries

| # | Patch | Target | Symptom |
|---|---|---|---|
| 1 | `patch_cohtml` | `cohtml_unity3dplugin.dll` | crash during UI init (`je`→`jne` in `IAllocator` init). Community fix, credit **manolz1/cities2-gptk-fix** |
| 2 | `patch_colossal_io` | `Colossal.IO.dll` → `EnumerateFileSystemIterator[Recursive]` | startup crash — Win32 error check after `FindNextFile` reads garbage (R1) |
| 4 | `patch_asset_database` | `Colossal.IO.AssetDatabase.dll` → `PopulateFromDirectory` | `File.Exists` wrong under Wine → bogus `.priority` read |

## 4. Wine crypto (R3) — ⚠ see licensing note

| # | Patch | Target | Symptom |
|---|---|---|---|
| 5 | `patch_cohtml_license` | `cohtml.WindowsDesktop.dll` | Coherent Gameface rejects its own **valid embedded** licence because Wine's `BCryptVerifySignature` fails → native crash before the main menu |

> **⚠ Do not publish this patch.** The licence is legitimate and present; only Wine's crypto is
> broken. But a ready-to-run licence-check bypass for commercial middleware reads as circumvention
> regardless of intent. **Fixing R3 in Wine removes the need for it entirely** — that is the correct
> route. Describe the finding; don't ship the tool.

## 5. Paradox `PDX.SDK.dll` — mod downloads

| # | Patch | Target | Symptom / cause |
|---|---|---|---|
| 13 | `patch_mkparent` | `DiskIODefaultWindows.CreateFileStream` | nested download dirs don't exist → `DirectoryNotFoundException`. Prepends `Directory.CreateDirectory(dirname)` |
| 14 | `patch_lockbypass` | `AcquireLockResult.GetError` | lock reports "UNKNOWN" failure under Wine threading; force `null` so the caller proceeds |
| 15 | `patch_longdelete` | `DeleteLongPathFile` / `DeleteLongPathDirectory` | PdxSdk's **own second IO layer** for long paths, same R1 garbage-errno throws |
| 16 | `patch_createfile` | `LongPathFileExists` / `LongPathDirectoryExists` | under concurrency both metadata queries false-positive on a missing file → integrity check reads a not-yet-downloaded `.zip` → abort **before** download. Rewritten to test existence by *opening*. |
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
3. **File a Wine bug for R3** — `BCryptVerifySignature` on valid ECDSA. Retires 1, and removes the
   only patch with a licensing problem.
4. **Report #17 to Paradox** — the leaked lock is a real cross-platform defect with a clean fix
   (dispose the lock in the catch handler, or add a `finally`).

## Method notes

- Every patch is **pattern-matched**: it refuses to write if the IL moved (game update), rather than
  corrupting the binary. `.bak` = pristine original.
- **Prefer in-place edits** (same byte count) over relocation — no branch-target, offset or
  exception-handler-clause shifts. Relocating a `.ctor` specifically breaks early-init resolution.
- **Verify stack balance on both branch paths** before applying; an unbalanced edit yields
  "Invalid IL at IL_xxxx" at runtime, not at patch time.
- **Boot-verify after any `mscorlib` change** — it is on the boot path.
- Re-derive offsets after a game update with
  `~/cs2-patch/revenv/bin/python3 ~/cs2-patch/dis_pdx.py <dll> <Type> <Method>`.
