# R2 — `CreateFile` returns handle value `0` for a valid, usable file

**Component:** kernel32 (file)
**Severity:** normal · **Platform:** macOS (Apple Silicon, Rosetta 2)

## Summary

`CreateFile` sometimes returns a handle whose numeric value is **`0`** for a file it opened
successfully. The handle is usable — reads and writes on it work — but `0` is conventionally
treated as invalid on Windows, so callers reject it.

This breaks .NET/Mono badly: `SafeFileHandle` derives from `SafeHandleZeroOrMinusOneIsInvalid`,
whose `IsInvalid` returns true for both `0` and `-1`. A valid handle is therefore judged invalid,
and `FileStream`'s constructor throws `ArgumentException: Invalid handle. Parameter name: handle`.

## Observed in

Cities: Skylines II, on every launch, reading its own settings files:

```
[FileSystem] [ERROR] Failed to read settings file with GUID '<guid>': Invalid handle.
Parameter name: handle
  at System.IO.FileStream.Init (Microsoft.Win32.SafeHandles.SafeFileHandle safeHandle, ...)
  at System.IO.LongFile+FileStreamWithDisposeCallback..ctor (SafeFileHandle handle, System.Guid guid, ...)
```

Settings then fall back to defaults and are written back on exit, so user configuration silently
fails to persist across sessions.

Note the accompanying `GetLastError()` is `0` ("Success"), consistent with a successful open — so
the API *reports* success while returning a handle the platform's own conventions call invalid.

## Reproducer

`scripts/filetest_net.cs` (see `scripts/README.md`) opens a known-good file and reports the raw
handle value alongside `SafeFileHandle.IsInvalid`.

## Expected vs actual

| | Windows | Wine/macOS |
|---|---|---|
| `CreateFile` on an existing readable file | handle ≠ 0 and ≠ −1 | occasionally **0** |
| `new FileStream(safeHandle, …)` on that handle | constructs | `ArgumentException: Invalid handle` |

## Suggested fix

Avoid handing out `0` as a file handle value — Win32 treats it as reserved/invalid by convention,
and at least one major managed runtime encodes that assumption in its type hierarchy.

## Impact

Two binary patches exist to work around this (one in the application's IO layer, one in
`mscorlib`'s `FileStream.Init`, because the handle is validated twice on the path).

## ⚠ A THIRD validation site, still throwing (observed 2026-08-31)

`patch_fshandle` works — its target site is silent. Measured on a clean boot to `MainMenu`:

```
ArgumentException / "Parameter name: handle"   0   <- the documented symptom, FIXED
IOException: Invalid handle to path "[Unknown]" 8   <- and yet
```

Same method, one site further in:

```
[FileSystem] [ERROR] Failed to read settings file with GUID '<guid>':
    Invalid handle to path "[Unknown]" System.IO.IOException: ...
  at System.IO.FileStream.Init (... SafeFileHandle safeHandle, ...) [0x0006a]
  at System.IO.LongFile+FileStreamWithDisposeCallback..ctor (...)
  at System.IO.LongFile.OpenRead (System.String path)
```

So the handle is validated **three** times on this path, not twice: Colossal's `LongFile`
(`patch_longfile`), `FileStream.Init`'s first check (`patch_fshandle`, at `0x1668c4` — verified
applied), and a **second check inside `FileStream.Init` at `[0x0006a]`** that throws a *different*
exception type with a *different* message. Grepping for the documented `ArgumentException` string
reports success while the bug is still firing — which is exactly how it stayed unnoticed.

**Impact is unchanged from the original:** 8 settings files fall back to defaults and are written
back on exit, so user configuration silently fails to persist.

**How old is it?** Unknown, and do not guess. The only adjacent log (`Player-prev.log`) is an
86-line aborted boot that never reached the settings read, so it cannot serve as a before. Most
likely long-standing and simply never re-checked after `patch_fshandle` landed — the patch does fix
what it was written for.

**Not related to the winemac/DXMT work.** It surfaced during the resize boot-verify only because
that pass counted `exception|error` broadly instead of the single `InvalidProgramException` string
boot-verify normally checks. Fixing it means IL surgery on `mscorlib`, which is on the boot path —
see GOTCHAS § "IL opcode surgery" before touching it.
