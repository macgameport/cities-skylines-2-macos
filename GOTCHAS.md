# CS2-on-macOS gotchas — all stacks (2026-07 → 2026-08)

> **Read the stack labels.** This is a cumulative log across **four** stacks tried between
> 2026-07-03 and 2026-08-22: CrossOver (licence now expired), GPTK/Apple D3DMetal, Wine 11 +
> DXVK/MoltenVK (abandoned — device-lost ~1 run in 8), and the current **Wine 10 Sikarugir +
> D3DMetal**. Many entries describe stacks that are no longer in use; they are kept because the
> underlying Wine behaviour usually still applies. Entries mentioning DXVK, MoltenVK or
> `VK_ERROR_DEVICE_LOST` are **historical** unless they also mention D3DMetal.
> Current setup: [`../README.md`](README.md) · Patch detail: [`docs/patch-inventory.md`](docs/patch-inventory.md)


Hard-won traps from getting Cities: Skylines II running for free on macOS 26 / M3 Max.
Context: the wider community says this is impossible (see REFERENCES.md) — so these are mostly undocumented.

---

## Rendering

### 1. The "black screen" is dead OpenGL, not a broken GPU
macOS 26 has degraded OpenGL to the point Wine's **default `d3d → wined3d → OpenGL`** path can't
render — `glClear` throws `GL_INVALID_FRAMEBUFFER_OPERATION`. **Everything renders black.**
- **Fix:** force **DXVK** (`d3d → DXVK → Vulkan → MoltenVK → Metal`). Bypasses GL entirely.
- Diagnostic: a 60-line DX11 "clear to magenta" test (`dxtest.c`) renders black on builtin d3d11,
  **magenta** with DXVK installed. That one test proves the whole approach.

### 2. GDI 2D windows DO render; only hardware GL is dead
`wine notepad` shows a normal white window. So plain Win32 dialogs render (that's why Steam's
"Steam Service Error" native dialog appears while its CEF UI is black). Only accelerated **GL** is broken.

### 3. wined3d's Vulkan renderer CRASHES on macOS 26 — don't use it
Setting `HKCU\Software\Wine\Direct3D\renderer = vulkan` makes wined3d use Vulkan… and it crashes
(`dxtest` exits, apps die). DXVK is the *only* working accelerated path. Don't waste time on wined3d-vulkan.

### 4. DXVK must be the macOS fork, and the FULL build
Use **Gcenx/DXVK-macOS v1.10.3** (last version supporting Vulkan 1.2 — MoltenVK doesn't expose the
extensions upstream DXVK 2.x needs). Install the **full** tarball (has `dxgi.dll`); the "-repack"/"-builtin"
variants **lack dxgi** → `D3D11CreateDevice` fails with **exit 53**. Copy `x64/{d3d11,dxgi,d3d10core,d3d9}.dll`
into `prefix/drive_c/windows/system32` and set those 4 `DllOverrides = native`.

### 5. VK_ERROR_DEVICE_LOST = GPU hang; MoltenVK crashes hard by default
CS2's heavy loading hangs the Metal GPU → `DxvkSubmissionQueue: VK_ERROR_DEVICE_LOST`, hard crash.
- **`export MVK_CONFIG_RESUME_LOST_DEVICE=1`** — documented workaround (Wine doesn't handle device-lost).
- Also try `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1`.
- **Keep `dxgi.maxDeviceMemory = 16384` + `dxgi.maxSharedMemory = 16384` in `dxvk.conf`.** It IS effective (shows
  in the DXVK "Effective configuration" dump). NOTE: it does NOT change what CS2's `Player.log` reports
  (`VRAM: 128 MB` regardless) — Unity reads the adapter differently — but keep it set; it's harmless and honest for
  a 36 GB unified M3 Max. (Earlier theory that the 128 MB report was the map-load killer was WRONG — see #5c. The
  map loads fine at "128 MB" once mods are off.)
- **Bundled MoltenVK is already the newest** — 1.4.1 (2025-11-30), the latest official release. Swapping in a
  "newer" MoltenVK is not an option; this is the tooling ceiling, not an outdated-layer problem. (The community
  DXVK-patched MoltenVK in REFERENCES.md is based on the *older* 1.1.9 → a downgrade, untried.)

### 5c. The map-load device-loss was MODS, not VRAM (SOLVED) ⭐
Turning **mods off** is what got past the loading screen. With subscribed mods present, CS2 runs **background
downloads + Virtual-Texturing "background processing of materials"** at the menu — GPU/CPU/disk churn. Starting a
map load *on top of* that stacked GPU work → `VK_ERROR_DEVICE_LOST`. Disable mods (see #5d) and let the menu go
quiet (notifications finished) before loading. Then the load completes: audio, ~206k objects, clean asset unload.

### 5d. Disable mods via files (menu hangs, so edit directly)
Mods live in `…/Cities Skylines II/.cache/Mods/`. To force-off without the (hang-prone) in-game menu:
- `playset_config.json` — set every `"isEnabled":true` → `"isEnabled":false` (game CLOSED; it rewrites on exit).
- Delete `pdx_mods/.downloading` to stop a pending download resuming mid-test.
- Check `Logs/Modding.log`: `Active Playset (none)` + `Enabled Mods (none)` = confirmed off. (An inactive playset
  already means mods don't LOAD even if listed enabled — but downloads still churn until disabled/finished.)

### 5e. Killing the "Wine window keeps reopening" + a device-lost/hung game
After a device-loss the game hangs (cursor still changes = OS-level alive, but GPU gone → black). Leftover
`explorer.exe /desktop` + Steam repaint = the window that keeps popping back. Kill the whole stack cleanly:
`WINEPREFIX=~/cs2-mac/prefix "…/Wine Staging.app/…/bin/wineserver" -k` then `pkill -9 -f cs2-mac; pkill -9 -f steamwebhelper`.

### 5f. Device-loss moved to the FIRST GAMEPLAY FRAME (current blocker)
With mods off + VRAM set, the load survives — but the **first full-city frame render** device-losts (audio plays,
screen black, `waitForIdle failed`). This is the single heaviest GPU moment (whole scene at once). `Player.log` is
clean; the `err:` only shows in the **terminal**. Levers (in `Settings.coc`, game closed): **shadows off**
(`ShadowsQualitySettings.enabled=false` — the biggest pass + a MoltenVK weak spot), **`maxLightCount` 4096→256**,
**`minScale` 0.5→0.3**. AND load the **smallest/flattest NEW map**, not a built save (10× lighter first frame).

### 5a. Mouse clicks not registering → virtual-desktop mode (SOLVED)
At the rendered menu, clicks didn't register (Wine input-routing quirk in exclusive-FS). **Fix: launch inside
a Wine virtual desktop** — `wine explorer /desktop=CS2,<W>x<H> Cities2.exe`. Input routes correctly there.

### 5b. Virtual-desktop resolution MUST match the game's render resolution (cursor offset)
With a virtual desktop sized differently from the game's internal resolution (e.g. desktop 1600x1000 vs game
1512x982), the cursor hit-test is **offset** — you can't click bottom-edge UI like **SELECT MODE**. Match the
`/desktop=CS2,WxH` to the game's actual render res (1512x982 here) and clicks land where the cursor is.

### 6. The game ignores `-screen-fullscreen 0` / `-screen-width` after first run
Once CS2 has a saved settings file it uses **its** resolution/window mode (`Exclusive FS: 1`, its saved res),
ignoring command-line graphics flags. To change graphics you must edit the saved settings (`Settings.coc` —
plain JSON), not the CLI.

### 6a. Keep `displayMode` = "Fullscreen" — "Windowed" THRASHES the display and device-losts
Editing `Settings.coc` `displayMode` to `"Windowed"` looked like the fix for input, but CS2 effectively
ignores it and **cycles display modes** on startup — each mode-set re-inits the swapchain and reliably
triggers `VK_ERROR_DEVICE_LOST` before the menu. `"Fullscreen"` does a single mode-set and reaches the
menu cleanly. Solve input with virtual-desktop mode (#5a below), NOT windowed mode.

---

## Steam client

### 7. Steam's CEF UI renders BLACK and cannot be fixed on this stack
Chromium's compositor needs a shared-texture interface DXVK 1.10.3 lacks
(`D3D11Texture2D::QueryInterface Unknown interface f8fb5c27-...`), and its dcomp/GL present paths are dead.
Tried and failed: `-cef-disable-gpu[-compositing]`, `WINEDLLOVERRIDES=dcomp=`, virtual desktop, Big Picture
(`-gamepadui`), per-app builtin d3d11, a mingw steamwebhelper.exe wrapper. **All black.**
- **Workaround that WORKS:** drive the login via **CEF remote debugging** (CDP). It renders the login in
  Chromium's own engine, off-screen. See `cdp.py` + `CS2 Steam Login.command`. Screenshot with
  `Page.captureScreenshot` to actually *see* it.

### 8. steamwebhelper hangs on OLD Wine — needs Wine 9+
GPTK's Wine 7.7 → "steamwebhelper is not responding," no login possible. Wine 11 fixes it. This is why
GPTK (Apple's toolkit) is a dead end for anything needing the modern Steam client.

### 9. Don't zero-out steamservice.exe to stop its crash
Steam's file verification catches a 0-byte `steamservice.exe`, re-downloads the whole client, and enters
an update loop. Instead: it's harmless (Proton disables it too) — click **Cancel** on the "requires
maintenance" dialog, or suppress via `HKCU\Software\Wine\WineDbg\ShowCrashDialog=0`.

---

## Launch / Steamworks

### 10. `steam -applaunch <id>` makes CS2 exit before Unity — launch the exe DIRECTLY
`-applaunch` kills the game early (no Player.log). Instead run `Cities2.exe` directly with
`steam_appid.txt`=949230 in the game dir + these env vars so SteamAPI connects to the running client:
`SteamAppId=SteamGameId=SteamOverlayGameId=949230`.

### 11. Launching the game too soon after Steam login = platform-init crash (the WORST red herring)
`[SceneFlow] platform service integration failed` → 100k+ NullReferenceException → `fatal://error`.
Looks like a game bug; it's a **Steam license-sync RACE**. SteamAPI can't verify ownership until Steam has
~40–60s of uptime after login. **Fix: sleep 40s after `[U:1:<nonzero>]` appears in connection_log, THEN launch.**
Add an auto-retry if `platform service integration failed` shows in the first ~12s.

### 12. Disable the Steam overlay — it crashes the game under Wine
`WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d"`.

### 13. CS2 bundles its own VC++ runtime — no vcredist/winetricks needed
`VCRUNTIME140/MSVCP140` load from `Cities2_Data/Plugins/x86_64/`. Don't waste time installing redists.

---

## Login automation (CDP)

### 14. Steam's login form is React — setting `.value` isn't enough
Use the native setter + dispatch `input`+`change` events, or React ignores it:
`Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set.call(el, val)` then dispatch.

### 15. Auto-login works after the first CDP login (cached token)
Once logged in once, Steam auto-connects headless on subsequent launches (no UI needed). The black CEF
UI stops mattering — the game launches via direct exe + the cached session.

### 16. Email vs mobile-app Steam Guard is an ACCOUNT setting, not a login-flow choice
If the mobile authenticator is enabled, Steam *requires* the app; "Enter a code instead" = the app's code,
not email. To go email-only: remove the authenticator from the account (→ email Steam Guard; ~15-day trade hold).

---

## Paradox Mods download (2026-07-06)

> Full testing plan + idea checklist in **MODS-TESTING.md**. These are the hard-won traps.

### 17. handle-0 is NOT a generic Wine bug, and it does NOT block a normal FileStream ⭐ (CORRECTED 2026-07-06)
**Earlier framing was wrong.** We assumed "Wine's `CreateFile` returns handle 0 for valid files → blocks mod downloads."
Deterministic reproducers (repo `scripts/`, runnable over Bash — no game boot) disproved it. On the identical Wine, a
plain CreateFile/FileStream create+write+open+read to the exact `.cache/Mods/pdx_mods/.downloading/74324_36/content.bin`
path **works with a proper nonzero handle** under EVERY runtime tested — raw Win32 (CrossOver 26.2 + Sikarugir Wine 10),
MS .NET CLR, standard Mono 6.12, **and CS2's own `MonoBleedingEdge/mono-2.0-bdwgc.dll`** (run via `scripts/monohost.exe`).
stdin state (closed / /dev/null / detached) is irrelevant too. So the mod-download blocker is **not** a generic handle-0.
- The **settings-read** handle-0 that `patch_longfile` addresses IS separately real (`Colossal.IO.LongFile.GetFileHandle`)
  — but that method must use a *different* open than a normal CreateFile, since our reproducers never surface handle-0.
- **Patching .NET to accept handle-0 still doesn't work** (kept as documented dead ends, NOT in `repatch.sh`):
  `patch_safehandle.py` (global `IsInvalid`) breaks boot (kernel handles use 0/NULL for FAILURE → null deref);
  `patch_filestream.py` (NOP FileStream.Init throws) breaks boot (accepting handle-0 → garbage reads → NRE).
- **★ REAL ROOT CAUSE (2026-07-07): the errno-0 / FindNextFile end-of-directory false-positive in `System.IO.Directory`
  ops — a DIRECTORY bug, not a file-handle bug.** Unmasked `PdxSdk.log` (unpatched game) shows the download failing on
  `PrepareFolderForPatching` → `IOException: "Success"` (Wine returns ERROR_SUCCESS(0), Mono misreads as error) + the
  nested `.metadata\` dir never created → `CreateFileStream` → `DirectoryNotFoundException`. Same class as
  `patch_colossal_io`'s FindNextFile fix, but PdxSdk uses raw unpatched `System.IO.Directory`. This is why file reproducers
  all passed — wrong op. Fix at the RIGHT layer (pre-create full nested dirs, or patch Mono Directory FindNextFile).
  `patch_pdxsdk_io` masked the WRONG layer (→ hang + boot NRE). Full detail in **MODS-TESTING.md**.
- **Reproducer cheatsheet:** CO wine = `CX_ROOT=<CrossOver> CX_BOTTLE=Steam WINEDEBUG=-all "$CX/bin/wine" <exe>`
  (use `CX_BOTTLE`, NOT `WINEPREFIX`); macOS has **no `timeout`**; Sikarugir wine needs `arch -x86_64` + the wrapper's
  `Frameworks/*.dylib` copied into `SharedSupport/wine/lib` (libinotify @rpath). `monohost.exe` runs ANY managed assembly
  under the game's exact Unity mono — reuse it for the flag/async follow-ups.

### 18. Playset activation IS patchable (and safe) — but masking turns fail-fast into a silent hang
`patch_pdxsdk_io.py` (PDX.SDK.dll `ResultFactory.CreateIoResultFromException` → `set_Success`) makes the playset
**activate** and mods **queue** (reach "Preparing… 2.0%"). BUT it masks the disk-op failure
as success, so the download pipeline **waits forever for a fake-success completion** → silent "Preparing 2%" hang, no log
(vs. the pre-patch fast-fail that logged `IOERR_101` and gave up after 2 rounds). It's a net cosmetic win, not a fix.

### 18b. ⚠️ `patch_pdxsdk_io` BREAKS BOOT when the mod-cache state is empty/minimal (regression, 2026-07-07)
Same masking bites at **startup**: with an empty `.cache/Mods` (no `playset_config.json`, empty `pdx_mods`),
`Colossal.PSI.PdxSdk.PdxSdkPlatform.Initialize()` does a disk op that legitimately fails → the patch fakes success with a
**null** payload → `Initialize` derefs it → `[PdxSdk][Create] Fatal error during SDK initialization: NullReferenceException`.
Cascade: PdxSdk init NRE → `[Modding]` NRE → `Colossal.IO.AssetDatabase.get_instance()` returns null → `[SceneFlow][FATAL]`
in `GameManager.UpdateModdingBacktraceAttributes()` → **main thread hard-blocks in `NtWaitForSingleObject`, never reaches
MainMenu**. On 2026-07-06 this DIDN'T happen because the mod state existed (the disk op succeeded, no mask triggered).
**Proven:** revert `PDX.SDK.dll` from `.bak` → game reaches MainMenu (58s) clean. **So there's a bind: WITH the patch =
boot NRE (empty mod state); WITHOUT = boots fine but playset won't activate (no queue → nothing to download).**
**Current shipped state (2026-07-07 03:0x): PDX.SDK.dll is UNPATCHED (reverted) so the game BOOTS + plays vanilla. Do NOT
blindly re-run `repatch.sh` / `patch_pdxsdk_io` — it re-breaks boot until the mod-cache state is restored.**
**Path to test downloads next session:** boot UNPATCHED → menu → Paradox Mods → subscribe the 4 mods (rebuilds a valid
`playset_config.json` + mod-cache so Initialize's disk op succeeds) → re-apply `patch_pdxsdk_io` → reboot (should boot now
that the state exists) → Paradox Mods → Library → trigger download → run `scripts/capture-hang.sh` for the async-stall test.

### 19. In-game mod downloads are the GAME's PdxSdk, NOT the launcher's CPatch
Download activity logs to LocalLow `Logs/PdxSdk.log`. The Paradox Launcher's `cpatch.log` is **only the launcher
self-updater** (xdelta on `launcher-v2` node_modules from `api.paradox-interactive.com`) — zero `pdx_mods` ops. Don't
chase cpatch. Also: the queue only actively processes while the **in-game Paradox Mods → Library screen is open**
(main-menu notifications are just persisted "queued" state).

### 20. Sideload is blocked — the mod API needs AWS SigV4 signing
Manual install seems attractive (bypass the broken downloader) but: the mod **file manifest** (`repository.json`) requires
an **AWS SigV4-signed** request to `api.paradox-interactive.com` — a bearer token 403s (`"Invalid key=value pair … hashed
with SHA-256 … Authorization header"`). CDN content blobs (`modscontent.paradox-interactive.com`) are public, but their
exact paths live only in that signed manifest. And GitHub (`yenyang/CS2-MoveIt`) is **source-only** — no release DLL, and
a CS2 code mod can't be built here. **Only real path to sideload: copy `pdx_mods/<id>_<ver>/` from a native Windows CS2.**
Mod map: Move It=74324_36 (dep: UIL), UIL=74417_17, Anarchy=74604_39, Traffic=80095_28.

### 21. Async testing: only interpret a run that POSTDATES the change
Cost James real time this session — I twice concluded a patch "failed" (and once reverted a good one) from a **stale**
game run that predated the patch. **Rule:** stamp each patch change in `~/cs2-patch/change-ledger.txt`; only interpret a
run whose `Logs/SceneFlow.log` first-line timestamp is **after** the change. A run that started before = stale, draw no
conclusion. (I can't see message send-times, so message order lies.)

### 22. ✅ ROOT CAUSE of the mod-download wall: Unity-Mono `Directory.Delete(recursive)` is broken on Wine
**Supersedes the #18/#18b whack-a-mole.** Isolated with `scripts/monohost.exe` (runs a managed assembly under CS2's
exact Unity Mono) + `scripts/filetest_net.cs` — no game launch, no GUI, no async-timing ambiguity.
- **Symptom in PdxSdk.log:** `IOERR_101: IOERROR - IOError - Success` on `.cache\Mods\pdx_mods\.downloading\<id>`.
  "Success" is `strerror(0)` — a **stale/garbage Win32 last-error**.
- **What actually breaks:** `Directory.Delete(path, recursive:true)` throws `IOException` **and does not delete the dir**
  (`GONE=False`), *even on an empty dir*. Non-recursive `Delete(x,false)`, `File.Delete`, `GetFiles`,
  `GetDirectories`, `CreateDirectory`, and **manual recursion** all work fine.
- **Mechanism (mscorlib `System.IO.FileSystem.RemoveDirectoryRecursive`, IL mapped):** after the `FindNextFile`
  end-of-dir, Wine leaves `GetLastError` garbage (not 0, not 18=`ERROR_NO_MORE_FILES`), so CoreFX's post-loop error
  check at IL `0x154`–`0x163` **throws before reaching `RemoveDirectoryInternal(topDir)`** at IL `0x170` (the real
  removal, which works standalone). That's why an empty dir throws with the dir still present.
- **THE FIX = `patch_dirdel.py`:** NOP the one spurious `throw` (mscorlib file offset `0x15461f`, `0x7a`→`0x00`).
  Execution then falls through to the real removal. **Proven:** post-patch the probe flips [5][6][7] to
  `no throw / GONE=True` across empty, nested, and file-bearing trees. Boot-safe (recursive delete isn't on the boot
  path; mscorlib byte patch only). Now wired into `~/cs2-patch/repatch.sh`.
- **Why #18b's `patch_pdxsdk_io` was the WRONG layer:** it forced `IOResult.Success=true`, masking a delete that never
  happened → downstream "waits forever" (#18) and boot NRE on empty mod-state (#18b). Removed from `repatch.sh`.
- **Every failing download op is a recursive delete** (`PrepareFolderForPatching` = clear folder,
  `CleanupTempFileStorage`, `CleanupAndLogResult`, `LocalStorage.Delete`); **none are Move/Copy** (`CopyRepoFiles`
  never errors). So `patch_dirdel` alone should unblock the whole pipeline.
- **`Directory.Move` is NOT broken** (corrects the prior "whack-a-mole" belief). Probe [10] MoveCheck: simple AND
  nested (`.metadata`) moves both complete (`MOVED=True`, no throw). The earlier "nested Move throws" ([9]) was a
  **flawed test** — it moved into a *nonexistent parent* (`baseDir\mm2\sub`, `mm2` never created), which throws
  `DirectoryNotFound` on real Windows too. So recursive `Directory.Delete` is the *only* Wine-garbage-errno op on the
  download path. Only residual: `File.Delete(nonexistent)` throws garbage but effectively succeeds (file's gone) —
  never seen in the download logs.
- **⚠️ LIVE TEST (04:19, postdates patch): patch_dirdel is NECESSARY-BUT-NOT-SUFFICIENT.** The download STILL fails —
  `PrepareFolderForPatching → IOException "Success"` on `.downloading\<id>`. It's a real fix for the success-path
  recursive delete, but that was never the download's blocker. **Kept** (boot-safe, harmless, fixes a genuine bug) but
  re-labeled: NOT the mod-download fix.

### 22b. THE ACTUAL download killer: Wine garbage-errno on file-op FAILURE/EDGE paths (not success paths)
Probe [13] cracked it: the ops that throw the "Success"/"Unknown error" `IOException` are the **failure/edge cases**, not
normal ops:
- `Directory.GetDirectories/GetFiles/Delete` on a **nonexistent** dir → garbage `IOException` (should be `DirectoryNotFound`)
- `Directory.Delete` / `File.Delete` on a dir/file with an **open handle** → garbage (should be `SharingViolation`)
- (`Directory.Exists(nonexistent)` correctly returns False; enumeration of the same path throws garbage.)

**Mechanism:** Wine leaves `GetLastError` uninitialized on the *non-success* return of file APIs, so Mono builds a garbage
`IOException` ("Success" = `strerror(0)`) instead of the correct **typed** exception. PdxSdk's download code distinguishes
benign "not found" from fatal errors — but every edge case is now an indistinguishable garbage `IOException`, so it aborts.
This is a **broad surface** (matches the 2026-07-07 03:4x "not 3 sites, the whole file-API failure path" read), NOT one
patchable op. Ruled out: thread context (main vs ThreadPool/Task identical), the specific path (real dot-parent + spaces
enumerates fine in isolation), wrong-mscorlib (only one; game loads the patched one).
- **No download-progress logging at all** in the failing run → content may not even be fetching (upstream signing/network,
  cf. #20 AWS SigV4) → `.downloading\<id>` left empty/absent → enumerate-nonexistent → garbage errno. Worth confirming.
- **Realistic fixes:** (a) central errno-sanitize at the Wine/Mono boundary — risky, may mask *real* failures; (b) the
  **sideload from a Windows CS2** (#20) remains the only reliable way to actually get the mod folders on disk.
- **Harness for the next attempt:** filetest_net.cs now has [10] Move/File.Delete, [11] ClearFolder replica, [12] thread
  context, [13] nonexistent/open-handle — rebuild w/ bottle `Framework64/v4.0.30319/csc.exe`, run via monohost.

## SOLVED since first draft (2026-07-04)
- **Mouse clicks** — virtual-desktop mode + matched resolution (#5a, #5b). Clicks register; SELECT MODE reachable.
- **Reaching the main menu reliably** — Fullscreen displayMode (#6a) + 40s license wait (#11) + Low preset (#5b).
- **MoltenVK version question** — already on latest (1.4.1); not a lever (#5).

## OPEN ITEMS (not yet solved as of 2026-07-04)
- **VK_ERROR_DEVICE_LOST is non-deterministic on map load** — the "final boss." Menu + mode-select reached
  reliably; loading an actual map still device-losts on some launches. Everything cheap has been tried
  (RESUME_LOST_DEVICE, arg buffers, Low graphics, no mem cap, matched res, latest MoltenVK). Remaining levers:
  drop adaptive `minScale` below 0.5, smaller virtual desktop, reboot for clean GPU state, or accept the ceiling.
- Current graphics preset (`Settings.coc`): volumetrics/clouds/fog/SSAO/SSR/DoF/motion-blur all off, shadows
  1024, terrainCastShadows off, adaptive DynamicResolutionScale (minScale 0.5), LOD 0.4, Fullscreen.
