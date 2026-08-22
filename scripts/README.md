# Reproducers and helpers

Compiled binaries are **not committed** (see `.gitignore`) — build them from source.
They exist to demonstrate the Wine bugs in `../docs/patch-inventory.md` **without launching
the game**, which makes them suitable to attach to a Wine bug report.

| Source | Purpose |
|---|---|
| `monohost.c` | Minimal host that runs a .NET assembly under **CS2's exact Unity Mono runtime** — so results reflect the game's runtime, not the system one |
| `filetest_net.cs` | The R1/R2 probe. Sections `[5][6][7]` cover recursive delete; `[10]`–`[13]` add Move/Delete/open-handle and nonexistent-path edges |
| `filetest.c` | Native Win32 equivalent (isolates Wine from Mono) |
| `dxtest.c` | Minimal DX11 clear-to-magenta — proves whether a graphics path can present at all. Invaluable for testing a renderer without a 78 GB game install |
| `whwrapper.c` | steamwebhelper wrapper used while chasing the CEF black screen (historical) |
| `capture-hang.sh`, `watch-mods.sh` | Diagnostics: sample a hung process; watch the mod-download tree live |
| `disasm.py` | IL walker used to derive patch offsets |

## Building

`dxtest.exe`, `filetest.exe`, `monohost.exe` — mingw-w64 cross-compiler:

```sh
brew install mingw-w64
x86_64-w64-mingw32-gcc dxtest.c    -o dxtest.exe    -ld3d11 -ldxgi
x86_64-w64-mingw32-gcc filetest.c  -o filetest.exe
x86_64-w64-mingw32-gcc monohost.c  -o monohost.exe
```

`filetest_net.exe` — build with the **prefix's own** C# compiler so it targets the same framework:

```sh
WINEPREFIX=<prefix> wine \
  "<prefix>/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe" \
  /out:filetest_net.exe filetest_net.cs
```

## Running the probe

```sh
WINEPREFIX=<prefix> wine 'Z:\path\to\monohost.exe' 'Z:\path\to\filetest_net.exe' 'C:\probe'
```

Reports per-section pass/fail. On Windows every section passes; under Wine on macOS the
garbage-errno and handle-0 sections fail deterministically — that contrast is the bug report.
