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
