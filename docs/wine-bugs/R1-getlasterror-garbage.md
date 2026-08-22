# R1 — `GetLastError` returns garbage after file API calls

**Component:** kernel32 / ntdll (file APIs)
**Severity:** normal · **Platform:** macOS (Apple Silicon, Rosetta 2)

## Summary

After several file APIs, `GetLastError()` returns a garbage value rather than a meaningful Win32
error code — both after **successful** calls (where callers expect a stale-but-harmless value) and,
critically, on the **failure return** of failing calls, where the value is what distinguishes
"file not found" from a genuine I/O error.

Callers that branch on the error code therefore take the wrong path. Managed runtimes are hit hard
because .NET/Mono map the Win32 error to an exception *type*: with a garbage code, .NET throws a
generic `IOException` (often with the nonsensical message `"Success"`, i.e. `strerror(0)`) instead
of `DirectoryNotFoundException` / `FileNotFoundException`. Application code that catches the
specific type to handle a benign case instead sees a fatal error.

## Observed in

Cities: Skylines II. `Directory.Delete(path, recursive: true)` fails on a directory that is
successfully deleted on Windows: in CoreFX's `FileSystem.RemoveDirectoryRecursive`, the post-loop
error check after `FindNextFile` reads a garbage `GetLastError` (neither `0` nor
`ERROR_NO_MORE_FILES` 18) and throws *before* reaching the actual `RemoveDirectoryInternal` call.
The same class of failure appears in `File.Delete`, directory enumeration of a nonexistent path,
and deletion of a path with an open handle (which should report `ERROR_SHARING_VIOLATION`).

## Reproducer

Self-contained, no game required — runs a small .NET probe under the same Mono runtime:

- `scripts/monohost.c` — hosts a .NET assembly under a given Mono runtime
- `scripts/filetest_net.cs` — the probe; sections `[5] [6] [7]` and `[10]`–`[13]`

Build steps: `scripts/README.md`. Then:

```sh
WINEPREFIX=<prefix> wine 'Z:\path\monohost.exe' 'Z:\path\filetest_net.exe' 'C:\probe'
```

## Expected vs actual

| Operation | Windows | Wine/macOS |
|---|---|---|
| `Directory.Delete(dir, recursive:true)` on a populated dir | succeeds, dir gone | throws; dir remains |
| `Directory.GetDirectories(nonexistent)` | `DirectoryNotFoundException` | generic `IOException`, message `"Success"` |
| `File.Delete` / `Directory.Delete` with an open handle | `IOException` (sharing violation) | garbage error code |
| `File.Delete(nonexistent)` | silent no-op | throws, though the file is in fact absent |

## Impact

Eight separate binary patches to `mscorlib.dll` and the application's own IO layer exist solely to
make callers tolerate this. Any managed application doing routine filesystem work is affected.

## Notes

Linux/Proton does **not** reproduce this — it appears specific to the macOS backend.
