# CS2 Paradox Mods on Wine — download testing plan

> **✅ RESOLVED 2026-08-21.** This documents the investigation into why in-game Paradox Mods
> downloads failed — much of it on the CrossOver bottle, before that licence expired. **It is now
> fixed** and all four test mods download and load on the free stack.
> The decisive finding was that the long-standing "reader→writer lock upgrade deadlock" diagnosis in
> this file was **wrong**: `<CreateFileStream>d__25` takes reader *XOR* writer via an `if/else`, so
> no upgrade occurs. The real defect was a **leaked lock** — a catch handler with no `finally` that
> never released it. Read [`docs/patch-inventory.md`](docs/patch-inventory.md) §5 for the correction
> before trusting any conclusion below.


**Goal:** get subscribed Paradox mods (Traffic, Unified Icon Library, Anarchy, Move It) to actually
download + load. Vanilla plays perfectly; this is the one remaining gap.

## ★ Reproducer findings (2026-07-06 night) — the "handle-0" is UNITY-MONO-specific, not Wine
Built two standalone reproducers (in repo `scripts/`, runnable deterministically over Bash — no 20-min game
boot) to isolate WHERE the handle-0 actually comes from. Both run under CrossOver's own wine in the Steam bottle
(`CX_BOTTLE=Steam`, `~/Applications/CrossOver.app/.../bin/wine`):
- **`filetest.c` → filetest.exe** (pure Win32, mingw): CreateDirectory (incl. 2-level nested `.downloading/74324_36`),
  CreateFile write+read. **ALL SUCCEED, handles nonzero (0x3c), nested create ret=1.** Wine's kernel32 is NOT broken.
- **`filetest_net.cs` → filetest_net.exe** (managed C#, compiled+run in-bottle with the real MS .NET Framework
  `csc.exe` at `C:\windows\Microsoft.NET\Framework64\v4.0.30319`): P/Invoke CreateFile + **`SafeFileHandle.IsInvalid`**
  + managed `FileStream` write+read. **ALL SUCCEED — handle 0xc4, IsInvalid=False, FileStream OK.** (Real MS .NET is
  installed so Wine ran the actual Microsoft CLR, not a Mono fallback — a true MS-.NET data point.)

**Truth table (all deterministic, zero game runs):**

| Layer under test | Wine build | handle-0 / failure? |
|---|---|---|
| Wine kernel32 raw Win32 (C, `filetest.exe`) | CrossOver 26.2 | ❌ no — handles 0x3c, nested dirs create fine |
| same, cross-Wine check | Sikarugir Wine 10 | ❌ no — identical (0x34). **No Win32 variance across Wine builds** |
| stdin closed / /dev/null / fully detached (fd-0 theory) | CrossOver 26.2 | ❌ no effect — std handles stay 0x8, all ops succeed |
| MS .NET Framework `FileStream`+`SafeFileHandle` (real MS CLR, `filetest_net.exe`) | CrossOver 26.2 | ❌ no — handle 0xc4, IsInvalid=False, works |
| **standard Mono 6.12** `FileStream`+`SafeFileHandle` (`mono.exe filetest_net.exe`) | Sikarugir Wine 10 | ❌ no — handle 0xb8, IsInvalid=False, works (clean `C:\` path) |
| **Unity's embedded Mono** (`MonoBleedingEdge/mono-2.0-bdwgc.dll`, via `scripts/monohost.exe`) | CrossOver 26.2 | ❌ **NO handle-0 either** — ran `filetest_net.exe` under the game's EXACT runtime, plain FileStream to `.downloading/74324_36/content.bin`: handle 0xc4, IsInvalid=False, write+read OK |

**★ PIVOT (2026-07-06 night) — the simple "handle-0 on the mod-download FileStream" theory is DISPROVEN.**
FIVE runtime/Wine combos all handle files correctly, INCLUDING the game's exact runtime: raw Win32 (CO + Sikarugir),
MS .NET CLR, standard Mono 6.12, AND — via `scripts/monohost.exe` (LoadLibrary the game's `mono-2.0-bdwgc.dll` →
`mono_set_assemblies_path`=Cities2_Data\Managed → `mono_set_dirs` etc → `mono_jit_init_version("v4.0.30319")` →
`mono_jit_exec`) — **Unity's own MonoBleedingEdge**: a plain `FileStream` create/write + open/read to the exact nested
`.downloading/74324_36/content.bin` path returns handle 0xc4, IsInvalid=False, no error. So under Wine, on the identical
runtime the game uses, ordinary file I/O to the mod path is FINE. The download blocker is therefore **not** a generic
handle-0 on a normal FileStream — it must be one of:
- **PdxSdk's specific I/O pattern** — ❌ RULED OUT 2026-07-06. Disassembled the real write path
  (`PDX.SDK.Internal.Util.IO.FileIO`): `CreateWriteStream` → `CreateFileStream(FileMode.Create, FileAccess.Write,
  FileShare.Write)` → a lambda doing **`new FileStream(string, FileMode, FileAccess, FileShare)`** — the plain **4-arg
  SYNCHRONOUS** ctor (sig `2004010e118101118105118109`, no bufferSize, **no FileOptions.Asynchronous**; the async is
  just await-wrapping around a sync open). Replicated that EXACT call (Create/Write/**FileShare.Write**, read-back
  Open/Read/FileShare.Read) in `filetest_net` and ran it under **Unity's own mono via monohost.exe → WORKS ("OK — 15
  bytes")**. So the mod-write FileStream open is NOT the blocker. **The handle-0-on-download theory is DEAD.**

  ★★ **REAL ROOT CAUSE FOUND 2026-07-07 (unpatched game, unmasked PdxSdk.log): errno-0 / FindNextFile DIRECTORY bug —
  NOT a file-handle bug at all.** Booted the game UNPATCHED (patch_pdxsdk_io reverted — it was breaking boot), opened
  Paradox Mods → Library. The real download errors:
  - `[FileDownloader][CreateFileStream] System.IO.DirectoryNotFoundException: …\.downloading\74417_17\.metadata\thumbnail.png`
    — the nested `.metadata\` subdir never gets created, so the content write DirectoryNotFounds.
  - `[ModsPatching.PrepareFolderForPatching] System.IO.IOException: Success : …\.downloading\<id>` + `[…DeleteDirectory]
    IOERR_101: IOError - I/O error` — Wine returns ERROR_SUCCESS(0) from a `Directory` op, .NET/Mono misreads 0 as an
    error → `IOException("Success")` → download aborts, retries ~2×, gives up. (UI "installed" = account state only;
    `Modding.log` Enabled Mods = empty, disk = 0B — mods never actually land.)
  **This is DIRECTORY enumeration/creation, not file handles** — which is why every file reproducer (CreateFile/FileStream,
  incl. Unity's own mono) passed clean: wrong operation. Same class as the original `patch_colossal_io` FindNextFile fix,
  but PdxSdk uses raw unpatched `System.IO.Directory`. **Next:** (1) reproduce with `Directory.EnumerateFiles/GetFiles/
  CreateDirectory(nested)` in `filetest_net` under `monohost.exe` (should throw "IOException: Success"); (2) fix at the
  RIGHT layer — pre-create the full `.downloading/<id>/.metadata/` tree, OR patch the FindNextFile/errno-0 false-positive
  in Mono's `Directory` (mscorlib) like `patch_colossal_io` did for the game's `LongDirectory`. `patch_pdxsdk_io` masked
  this at the WRONG layer (→ "Preparing 2%" hang + boot NRE) — leave it OFF.
- **The settings-read handle-0 that `patch_longfile` fixes is real + separately evidenced** (`Colossal.IO.LongFile.
  GetFileHandle`) — but since our reproducers never hit handle-0, that method uses a *different* open than a normal
  CreateFile/FileStream. Disassembling GetFileHandle shows which open yields 0 — the one concrete handle-0 lead, and the
  pattern the download-write may share.
- **Or "Preparing 2%" isn't file I/O at all** (network / verify / the xdelta subprocess) — re-check with
  `WINEDEBUG=+relay,+file` on a REAL in-game download rather than assuming the write.

**Consequences:** (1) **CodeWeavers filing is OFF the table** — a minimal repro does NOT reproduce, so there's nothing
clean to file until the specific failing op is identified. (2) **PK (Idea 1) is even weaker** — we can't name what a
different Wine would need to fix. (3) **Idea 4 (VM → copy `pdx_mods` folders) stays the reliable path** to actually get
mods. Tooling kept in `scripts/`: `filetest.{c,exe}` (Win32), `filetest_net.{cs,exe}` (managed), `monohost.{c,exe}`
(runs any assembly under the game's Unity mono — reusable for the flag/async follow-ups). Standard Mono 6.12 in
throwaway prefix `~/monotest` (~500MB, deletable).

## What's confirmed (as of 2026-07-06)
- **Playset activation WORKS** via `~/cs2-patch/patch_pdxsdk_io.py` (PDX.SDK.dll
  `CreateIoResultFromException` → `set_Success`). Mods queue + reach "Preparing… 2.0%".
- **Downloads then hang / fail.** Root suspect: **Wine's `CreateFile` returns handle value 0** for
  valid files; .NET `FileStream`/`SafeFileHandle.IsInvalid` reject handle-0 → the mod-content file
  write (and settings reads) fail. Same class the original `patch_longfile` addressed for the main
  read path, but the mod/settings path uses .NET `FileStream` which re-validates.
- **In-game download is the GAME's PdxSdk** (logs to LocalLow `Logs/PdxSdk.log`), NOT the launcher.
  Launcher `cpatch.log` is only the launcher self-updater. The masking patch turns fail-fast into a
  silent "Preparing 2%" hang (pipeline waits for a fake-success completion).
- **Sideload is BLOCKED:** mod file manifest needs an **AWS SigV4-signed** request to
  `api.paradox-interactive.com` (403 without it); CDN content blobs are public but their paths live
  only in that manifest; `github.com/yenyang/CS2-MoveIt` is source-only (no release DLL, can't build
  here). Mod content GUIDs: Move It=74324_36 `a3b6b122-48f5-44e4-a15f-cc51839c3ff8` (dep: UIL 74417),
  UIL=74417_17, Anarchy=74604_39, Traffic=80095_28.

## Ideas to test (keep until one works)

### ☒ Idea 0 — let the PARADOX LAUNCHER download the mods (don't bypass it) — REJECTED 2026-07-06 (22:00–22:17)
**TESTED on CrossOver, Steam DOWN and UP → the launcher does NOT and CANNOT download CS2 mods. Conclusively dead.**
Rig built + kept: `launchers/Paradox Launcher (CrossOver).command` (opens the launcher standalone in the CO Steam
bottle via `cxstart` → `bootstrapper-v2.exe`; renders perfectly via D3DMetal) + `scripts/watch-mods.sh` (polls
`pdx_mods` bytes + streams DownloadManager/CPatch log lines). Three independent proofs:
1. **The launcher never manages CS2 mods.** Every launcher run logs `ModsRegistryMigration: SKIPPING … Reason: Mods
   are not enabled for this game` + `Mods are disabled for game cities_skylines_2`. CS2 uses the *in-game* Paradox
   Mods system, not the launcher's ModsRegistry/playset manager. `launcher-settings.json` only carries a
   `--disableCodeModding` launch flag and `browserModUrl: https://mods.paradoxplaza.com/games/` — the launcher's
   entire "mods" role for CS2 is a **web deep-link** to browse/subscribe, no in-launcher downloader.
2. **CPatch is 100% self-updater.** Its whole `cpatch.log` history (517KB) patches only `launcher-v2-bootstrapper`
   and `launcher-v2_1` under `C:\Program Files\Paradox Interactive\launcher\…`. **Zero** references to `pdx_mods`,
   the 4 mod IDs, or any mod-content op anywhere in the launcher logs. The "DownloadManager pausing pending patch
   operations" I saw was the launcher pausing its **own bootstrapper self-update** (`bootstrapper-update-operation`),
   not a mod patch. The Go-daemon-dodges-handle-0 premise is moot: CPatch never handles mod content.
3. **Steam running changes ownership display but NOT mods.** Started Steam in the CO bottle (auto-login OK,
   `[U:1:<REDACTED>]` Logged On 22:16:29) and restarted the launcher AFTER. With Steam up the CS2 page flipped to
   owned+playable (**RESUME / PLAY** buttons, v1.6.0f1) — so ownership recognition works — but the CS2 sidebar STILL
   showed only Home + Game settings, **no Mods entry**, and the log still said `Mods are disabled for game
   cities_skylines_2` + `Steam API is not initialized`. So it's not an ownership gate: game shows fully owned/playable,
   mods still absent, because the launcher just doesn't manage CS2 mods. (The ▼ by PLAY = `--disableCodeModding` "play
   without code mods", not a downloader.) CS2 mod download routes through the in-game PdxSdk regardless.

**Takeaway = same as Idea 2/3:** the CS2 mod download *must* go through the in-game PdxSdk (the handle-0 wall), and
nothing on the CrossOver stack routes around it. The fix has to be a **Wine that returns proper file handles (Idea 1)**
or **obtain the files elsewhere (Idea 4)**. Rig kept for re-use if we ever test launcher-mod behavior on another stack.

<details><summary>original Idea 0 note</summary>
**Insight (2026-07-06):** the launcher "seems to serve a purpose" — it does. The launcher's
`DownloadManager` was seen **"Pausing all pending patch operations"** the instant the game launched, and its
download engine is **CPatch, a Go daemon**. Go/Node file I/O uses raw syscalls, **NOT .NET `FileStream`** — so it
almost certainly **does NOT hit the handle-0 wall** that kills the in-game PdxSdk downloader. Our entire approach
("bypass the launcher, launch `Cities2.exe` directly") may be exactly what prevents mod downloads.
- **Test:** open the full **Paradox Launcher** in the CrossOver bottle, log in, go to its **Mods** section, and let it
  **download the 4 mods there (game NOT running)**. Watch `.cache/Mods/pdx_mods/<id>_<ver>/` for real bytes and
  `launcher-v2/logs/*` (DownloadManager/CPatch) for progress. If it downloads → then launch the game with mods present.
- Caveat only lightly checked: `cpatch.log` so far showed only launcher *self-update* ops — but the launcher log's
  "pending patch operations" strongly implies it also runs mod patches. Confirm by actually driving the launcher UI.
- **Related setup goal:** get a bottle config where **Steam UI shows up / login works cleanly AND the Paradox
  Launcher appears** (currently we launch semi-headless / direct-exe). A normal launcher-visible flow is the natural
  way to exercise this idea. CrossOver renders CEF via D3DMetal, so Steam+launcher UI *should* be displayable here.
</details>

### ☐ Idea 1 — different Wine (the proven pattern) ⭐ NOW THE TOP LIVE PATH (Idea 0 dead)
The handle-0 behavior is a **Wine bug and may be CrossOver-Wine-specific**. Every "impossible" wall on
this project fell by swapping the Wine (GPTK → free Wine 11 → DXMT/Porting Kit), not by patching the
game. The **Porting Kit `WS12Wine11.0_DXMT-v0.80`** stack (`~/Applications/CS2dxmt.app`, if rebuilt)
reached a playable map and had Paradox login working — but **mod download was never tested there.**
Its Wine is a different build; it may return proper handles.
- **Test:** on the DXMT stack, log into Paradox, open Paradox Mods → Library, see if downloads
  complete (bytes land in `.cache/Mods/pdx_mods/<id>_<ver>/`). If yes → play there, or copy the
  `pdx_mods` folders back to the CrossOver bottle.
- Also worth: Kegworks/Sikarugir Wine 10 (`S734M.app`), and a **newer CrossOver** build.

### ☒ Idea 2 — NOP all handle-0 throws in FileStream.Init (file-scoped) — REJECTED 2026-07-06
**TESTED (run 04:52:27) → BREAKS BOOT.** NREs in PdxSdk / Modding / SceneFlow (FATAL) → "unable to
start". Conclusive: when FileStream accepts Wine's handle-0 and READS, it gets garbage/null → NRE. So
Wine's handle-0 file streams genuinely don't work; the throws are *correct*, load-bearing behavior.
**This rules out the entire "patch the runtime to accept handle-0" family.** mscorlib reverted to stock;
patch_filestream removed from repatch.sh. Kept in `~/cs2-patch/` only as a documented dead end.
The takeaway: **the fix must be a Wine that doesn't return handle-0 (Idea 1), not a game/runtime patch.**

<details><summary>original Idea 2 note</summary>
`patch_filestream.py` (mscorlib) now NOPs all three handle-0 throws in `System.IO.FileStream.Init`:
(A) `IsInvalid` pre-check, (B) the `GetException(hr)` throw, (C) the `fileType==0` backstop. Premise:
`patch_longfile` says handle-0 IS usable via raw ReadFile, so if FileStream stops rejecting it, reads
may work → settings popup gone + mod writes succeed.
- **File-scoped** (only FileStream — won't break kernel/wait handles like the global SafeHandle patch,
  which broke boot with NULL_REFERENCE). Instantly revertible: `cp mscorlib.dll.bak mscorlib.dll`.
- **Risk:** if handle-0 file streams genuinely return garbage, expect corruption / TextureStreaming
  NRE. Watch SceneFlow.log for NRE, and whether `.downloading/` gets real bytes.
- **Verdict:** ___ (untested as of 2026-07-06 04:43)

</details>

### ☒ Idea 3 (partial) — global SafeHandle.IsInvalid patch — REJECTED
`patch_safehandle.py` made `SafeHandleZeroOrMinusOneIsInvalid.IsInvalid` treat only -1 as invalid.
**Breaks boot** (NULL_REFERENCE): kernel handles (events/mutexes) use 0/NULL for *failure*, so making
0 "valid" globally makes failed kernel handles look valid. Do NOT use. Kept in `~/cs2-patch/` only as
a documented dead end.

### ☐ Idea 4 — get pdx_mods from real Windows (VM works — no GPU needed) ⭐ reliable fallback
Guaranteed to work; the mods just need to be downloaded on real (non-Wine) Windows, then copy
`…/Cities Skylines II/.cache/Mods/pdx_mods/<id>_<ver>/` into this bottle.
- **VM is enough:** you do NOT need CS2 to run/render. Install the **standalone Paradox Launcher**
  in a Windows VM (UTM/QEMU or Parallels on Apple Silicon — ARM Windows is fine; the launcher is an Electron app,
  no GPU/game needed), log into the Paradox account, download the 4 mods, then copy the `pdx_mods` folders to the Mac
  bottle. Low-risk, deterministic. Also handy as a **"real Windows session to test theories"** against (compare
  behavior vs Wine — e.g. confirm handle values, download flow).
- If a full native Windows PC is available, same thing via CS2 directly.

## Test protocol (avoid stale-log mistakes)
Each patch change is stamped in `~/cs2-patch/change-ledger.txt`. Only interpret a game run whose
`Logs/SceneFlow.log` first-line timestamp is **after** the change being tested. Watch for real bytes
in `.cache/Mods/pdx_mods/.downloading/` (the pre-created folders persist under Wine).
