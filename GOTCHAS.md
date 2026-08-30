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

### 3. ⚠ CORRECTED 2026-08-28 — wined3d's Vulkan renderer no longer crashes; it just doesn't help
**Original claim (DXVK era, kept for history):** setting `HKCU\Software\Wine\Direct3D\renderer =
vulkan` makes wined3d use Vulkan… and it crashes (`dxtest` exits, apps die). DXVK is the only
working accelerated path.
**Re-measured on the self-built stock 11.16 engine:** it initialises cleanly — `err:winediag:
wined3d_dll_init Using the Vulkan renderer`, MoltenVK 1.2.10 creates its VkInstances, and **zero**
`GL_INVALID_FRAMEBUFFER_OPERATION` (the GL renderer throws that from `glClear` on the very same
binary, see §2). So "it crashes" is stale. What is still true is that it **buys nothing here**:
Steam's CEF is byte-identically black on the GL and Vulkan renderers alike (108,343 B both times),
because the wall is presentation, not rasterization — see § "Taking DXMT out of Steam's path".

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

### 6b. "Everything is too dark to see" has TWO unrelated causes — check gameplay first
Both were hit on this stack within two days, and only one is a port defect:
1. **Night, because the day/night cycle is on** — a *gameplay* setting, not rendering.
   **Options → Gameplay → day/night visual → off** (writes `"dayNightVisual": false` under the
   `Gameplay Settings` block of `Settings.coc`). Fixed it instantly on 2026-08-22. The key is
   **absent** from the file until the toggle is first used, so its absence is the default-on state.
2. **A washed-out, permanently dim scene at any hour** — `SSGIQualitySettings enabled: false`, a
   leftover MoltenVK GI-off mitigation that no longer applies (fixed 2026-08-21).
**Tell them apart before debugging:** is it dark *at a particular time of day* (cause 1) or dark
*always* (cause 2)? Neither is a renderer bug — don't go near DXMT/D3DMetal for either. Confirmed
non-defect on 2026-08-22: lighting keys byte-identical to the known-good stack, zero shader errors,
zero exceptions in `Player.log`.

---

## Steam client

### 7. Steam's CEF UI renders BLACK — ✅ STALE: it RENDERS on the D3DMetal stack (2026-08-22)
**Superseded.** Launched visibly (`steam.exe -no-cef-sandbox`, no `-silent`) on the current stack
(Wine 10 Sikarugir + D3DMetal, Steam build 1785799196): the full client UI — library, store shelves,
account menu — renders correctly. Screenshot-verified. Two facts that reframe the old diagnosis:
- **steam.exe picks the webview render path itself, per wrapper — and both paths work.** On the
  D3DMetal wrapper every webhelper launch back to 2026-07-05 (`logs/webhelper.txt`) carries
  `--no-sandbox --in-process-gpu --disable-gpu` (renderers on swiftshader ANGLE = software CEF); no
  config file, registry key, or wrapper sets those — steam.exe adds them. On the **Wine 11 + DXMT**
  wrapper it adds NO such flags: CEF runs a real `gpu-process`, and the UI renders anyway (verified
  2026-08-22, store page + promo popup), so `whwrapper_ipgpu.c` stays unused.
  ⚠️ **Correction (2026-08-22):** earlier notes — including a commit made the same day — cited
  [3Shain/dxmt#141](https://github.com/3Shain/dxmt/issues/141) as "DXMT lacks cross-process
  swapchains." **It is not that issue.** #141 is *"ANGLE `SwapChain11` fails with `EGL_BAD_ALLOC`
  (Steam CEF black window)"* — i.e. it tracks **this very black-window symptom**, on DXMT v0.74 +
  wine 11.5, and it is still open. The string `cross-process swapchain` appears **nowhere** in this
  project's logs; it survived only in prose. Since Steam's UI renders fine here on **v0.80 +
  wine-11.0**, we hold a genuinely useful upstream data point: #141 does not reproduce on v0.80.
  Worth posting there.
- **The July black screen happened with these SAME flags** — so the flags were never the fix or the
  culprit. It stopped reproducing somewhere across the engine swap (→ Sikarugir/D3DMetal) and the
  Steam client updates since; the exact cause was not isolated.
Interactivity confirmed 2026-08-22: store browsed, an expansion purchased, and its download started
from inside the client (Cloud Status: Up to date). Same-day check on the Wine 11 + DXMT wrapper:
renders there too (cached login OK in ~20 s, store fully drawn). Launching the game from Steam's Play button remains WRONG regardless — see #10, and
the shortcut's launcher is what re-applies the patches after exactly this kind of update.
The original record (DXVK 1.10.3 era, 2026-07), kept for history: compositor blamed on a missing
shared-texture interface *[2026-08-22: that GUID `f8fb5c27` is `ID3D11Texture1D` — benign
type-discovery]*; tried and failed then: `-cef-disable-gpu[-compositing]`, `WINEDLLOVERRIDES=dcomp=`,
virtual desktop, Big Picture (`-gamepadui`), per-app builtin d3d11, a mingw steamwebhelper.exe
wrapper. **All black at the time.**
- **CDP login** (`cdp.py` + `CS2 Steam Login.command`) is hereby demoted from required workaround to
  fallback — the normal Steam window should now handle fresh logins. Keep the scripts.

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
Cost me real time this session — I twice concluded a patch "failed" (and once reverted a good one) from a **stale**
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

## Second display gets blacked out by the game → REFRESH-RATE mismatch (2026-08-22)

**Symptom:** launching the game in exclusive fullscreen blanks the *other* monitor too, so you
cannot use anything else while it runs.

**Cause:** the display and the game disagreed about refresh rate, so Wine performed a display
**mode change** to take the screen:

    main display (DELL U2424H) : 1920x1080 @ 120.00 Hz
    game was asking for        : 1920x1080 @  60 Hz

A mode change on a captured display disturbs the whole display arrangement, which is what blanks the
second monitor.

**Fix — set the game's refresh rate to match the display**, so no mode change is needed:
Options → Graphics → **Screen Resolution → `1920 x 1080 x 120Hz`**. Confirmed: with 120 Hz selected,
**the black overlay on the second screen is gone.**

⚠ **Confound, stated honestly:** `CaptureDisplaysForFullscreen="N"` was written to
`HKCU\Software\Wine\Mac Driver` in the same session, so the two were not isolated. The timing
points at the refresh rate (the overlay stopped when 120 Hz was selected in-game, after launch), but
either or both may be contributing. Keep both.

**Set it in-game, not by editing `Settings.coc`.** Editing `refreshRate.numerator` 60000→120000 in
the file did **not** take effect — the game still applied 60 Hz on the next launch. Only the
in-game Screen Resolution control actually changed it. Another instance of the rule that this
project keeps re-learning the hard way.

## "Failed to read settings … Invalid handle" ⚠ markers are ABSENT FILES, not broken settings (2026-08-22)

**One error per settings file that does not exist yet — on both stacks, with `patch_fshandle`
applied.** Wine 11 + DXMT logged 4 (5 mods, 2 with `.coc` files → 3 mods + keybinds absent);
Wine 10 + D3DMetal logged 3 (4 mods → 2 + keybinds). None of the reported GUIDs exists on disk.

Wine's handle-0 defect makes a *not-found* open indistinguishable from an *invalid handle*, so the
first read of an absent settings file surfaces as an IO error rather than "no file, use defaults".

**Cosmetic.** The visible symptom is an exception dialog on exit. Don't debug it as a patch failure:
verify `fshandle` is applied (4 differing bytes vs `mscorlib.dll.bak`), then count mods lacking a
`.coc`; if the numbers match, it is this. `fshandle` remains necessary — it fixes reads of files
that *do* exist, which is why keybinds persist at all.

⚠️ **Two corrections to earlier versions of this entry, both measured 2026-08-22:**

1. **"Open the mod's settings once and the error clears" is FALSE.** Viewing a panel writes nothing;
   the `.coc` appears only when a setting is actually *changed*. A whole session spent in those
   panels produced no new files.
2. **The ⚠ badges are NOT this bug.** They are **keybinding conflicts**, and they have nothing to do
   with Wine, DXMT or the port — the same mods do this on Windows. The disproof is on disk:

   | mod | has `.coc`? | ⚠ badge? |
   |---|---|---|
   | Traffic | **yes** | **yes** |
   | Move It | yes | no |
   | Anarchy | no | **yes** |
   | Easy Zoning · Unified Icon Library | no | no |

   Missing-file and badge don't correlate at all. What *does* explain it is the binding state:
   `Traffic.coc` holds three actions (`RemoveIntersectionConnections`, `RemoveUTurnConnections`,
   `RemoveUnsafeConnections`) all with an **empty `m_Path`** — unbound. `MoveIt.coc` holds exactly
   one key, `"HasShownMConflictPanel": true` — its M-key conflict was acknowledged, so no badge. And
   `Settings.coc` → `Keybinding Settings` holds three **vanilla** shortcuts, also unbound: Map Tile
   Purchase Panel, Relocate Selected Object, Toggle Selected Object Active.

   **Fix it in Options → KEYBINDS by assigning keys** (or accepting the mod's conflict panel). This
   is game configuration, not a port defect — don't chase it through Wine.

**2026-08-25 update — the dialog can also fire MID-SESSION, at mod-options open.** First boot after
adding 5 mods: 8 GUID errors in Player.log (the new mods' settings + keybind stores, none on disk —
the count scales with mod additions, still cosmetic), and opening Find It's options page raised the
same IOException as a mid-session dialog (CONTINUE / SAVE & QUIT / QUIT). **CONTINUE is safe** — the
mod runs on defaults. Each mod's error stops once its settings file exists, i.e. after any of its
settings is actually changed (viewing alone writes nothing, per correction 1 above).

## Mod keybinding defaults are extractable offline — and the conflicts were fixed on disk (2026-08-25)

Mod default chords live in `SettingsUIKeyboardBinding` attribute blobs, not strings —
`scripts/dump-binding-attrs.py` (dnfile, run via `~/cs2-patch/revenv`) parses them, using
Game.dll for the BindingKeyboard enum map. **Calibration:** the ctor bools are positional —
b1=alt, b2=ctrl, b3=shift (anchored on Move It Ctrl+Z undo + Find It Ctrl+F search). Vanilla
declares nothing via attributes (Game.dll yields zero rows) — vanilla chords come from docs/UI.

Measured collisions in the 10-mod set (game 1.6.0f1): Find It Random **Ctrl+R** ⟷ Traffic lane
connector **Ctrl+R** · Traffic priorities-display **Ctrl+S** ⟷ vanilla quicksave · Traffic's
remove-connection trio ships **unbound** because its Ctrl+1/2/3 defaults collide with Traffic's
own priorities quick-set · **PageUp/PageDown** triple-booked (vanilla surface/underground ·
Move It raise/lower · Anarchy elevation). BB / Line Tool / Plop / InfoLoom / AIL declare zero
keybindings.

**Disk fix protocol (applied 2026-08-25, backups `*.bak-keybinds-20260825-120139`):** edit only
files the game itself wrote — `.coc` format is `Header\r\n` + 4-space JSON with `\n` bodies and
a `\r\n` after the final `}`; mod entries are keyed by settings **property name** (from the
dump); rebind = complete binding object (`m_Path` + `m_Modifiers`), modifier entries
`{"m_Name": "modifier", "m_Path": "<Keyboard>/ctrl|alt|shift"}`. Applied: Settings.coc three
emptied vanilla actions → Ctrl+Shift+M/R/A · Traffic trio → Ctrl+Alt+1/2/3 + display toggle →
Ctrl+Alt+S · FindIt Random → +alt (Ctrl+Alt+R). **Never create a `.coc` a mod hasn't written
yet** (header name is unverifiable — a wrong guess risks its settings load): Anarchy has none,
so its PageUp/Down badge stays until someone rebinds once in-game to mint the file.

## Apple/⌘ binds as Ctrl in-game — rebinding chords from the Mac keyboard (2026-08-25)

`user.reg` → `[Software\\Wine\\Mac Driver]` carries `"LeftCommandIsCtrl"="Y"` +
`"RightCommandIsCtrl"="Y"` (and both Option keys are Alt). So in any keybinding capture the game
receives **⌘ as Ctrl**: pressing ⌘⇧F stores Ctrl+Shift+F, and the chord then works from the Mac
keyboard as Apple+Shift+F. First use: Find It's search default (plain Ctrl+F, shipped with a
conflict ⚠) was rebound to ⌘⇧F — `FindIt.coc` `SearchKeyBinding` now carries `shift`+`ctrl`
modifiers over the default `f`, which is exactly that chord as the game spells it.

## ✅ SOLVED by wine 11.16 — alt-tab freeze is presentation, NOT refresh rate (2026-08-22; kept for the mechanism)

**Separate problem from the one above, and NOT fixed by matching refresh rate.** After switching away
and back, the game accepts input (one action registers) but **the screen never redraws**.

**Measured:** matching the refresh rate did *not* reduce mode-change churn — it went from 9 to **25**
(`Setting display mode` in wine stderr, 12@120 + 13@60) while the game sat correctly at 120 Hz. So
the churn is not driven by the mismatch, and an earlier version of this entry claiming otherwise was
wrong.

**The two startup warnings are NOT the cause.** `unsupported swap effect 3` is cosmetic — the same
`MTLD3D11SwapChain` is built regardless (source read, `d3d11_swapchain.cpp:1111`). Swap effect 3 is
**`DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL`** — *not* `FLIP_DISCARD`, which is 4. (Verified against
mingw's `dxgi.h`: `DISCARD=0, SEQUENTIAL=1, FLIP_SEQUENTIAL=3, FLIP_DISCARD=4`. An earlier version
of this entry said `FLIP_DISCARD`; that was the same guess-the-constant error as the `f8fb5c27`
misidentification. Check the header.) `MakeWindowAssociation: Ignoring flags 3` = the game asking
DXGI not to manage window transitions; DXMT ignores everyone's flags there, so it distinguishes
nothing.

**Source-level state (2026-08-22, late session — v0.80 ≡ master `d31278d` in all cited files):**

- **The swapchain IS exclusive fullscreen (`Windowed == FALSE`).** The boot line
  `Setting display mode: 1920x1080@120` is printed only by `wsi::setWindowMode`
  (`wsi_window_win32.cpp:42`), and every path to it requires exclusive-fullscreen state. Closes the
  draft report's open question. Corollary: `SetFullscreenState` logs NOTHING on success, so
  "no SetFullscreenState lines" was never evidence — don't re-make that inference.
- **`dxgi.handleAltTab` is structurally inert for CS2**: both reaction sites
  (`d3d11_swapchain.cpp:743-744` and `:441-442`) require `!window_minimized`, and CS2 minimizes
  itself on focus loss. Explains the measured null result. Worth telling upstream.
- **MEASURED 2026-08-23 (diag run + held freeze + 5s `sample`): the mechanism is pinned.**
  - **Only the screen freezes.** Frozen process sustains ~250% CPU; sim autosaves; blind save/quit
    works. The sample shows the COMPLETE present pipeline running: encoder encoding real draws, GPU
    submits/completes, `presentAfterMinimumDuration` firing, drawables recycling sub-millisecond.
    **Zero `nextDrawable` waits in 65k sample lines → the wedged-drawable-pool theory is dead.**
  - **One visible refresh per minimize/restore cycle** (user-verified, repeatable): the WindowServer
    samples the layer's current surface once during each window-order transaction, otherwise
    ignores every present. This is what makes blind save/quit possible — one frame per alt-tab.
  - **Trigger, traced to the millisecond:** at the FIRST focus loss the game (Unity standard
    behavior) sets WS_MINIMIZE + `ShowWindow(SW_MINIMIZE)` within 5ms — then **600ms later creates
    a SECOND swapchain while the window is miniaturized with client rect (0,0)-(0,0)** (second
    `CreateSwapChain: unsupported swap effect 3` in the trace); its metal view/layer attaches in
    that state and never enters live compositing. Both swapchains stay alive to process exit; the
    win32/Cocoa window and both metal views are never recreated. Six windowing-flawless restore
    cycles (one *inside* the proven-static window) changed nothing — the restores were never the
    problem; the layer's compositing link was never established at birth.
  - Explains dxmt#48's folk remedy (fullscreen toggle = fresh attach while visible = normal
    compositing) and the windowed launcher's immunity (no minimize → no swapchain recreation).
  - **REPRODUCED STANDALONE same day (`scripts/minrepro3.c` + `run-minrepro3.sh`), and stripped
    further than expected: no fullscreen, no minimize, no focus change needed.** The minimal
    recipe: two swapchains on one HWND; presents to the OLDER one complete at full fps/S_OK but
    never reach the screen (screenshots byte-identical across 6s of 120fps red presents); presents
    to the newest chain show instantly. So the defect is: **only the most-recently-created
    swapchain's layer on an HWND is composited** — each swapchain gets its own client view and the
    newest view hides the previous one forever. CS2 freezes because Unity creates a recovery
    swapchain on alt-tab but keeps rendering into the ORIGINAL. ⚠ v1's lesson: present to the OLD
    chain when testing this — presenting to the new one shows nothing wrong (that false-negative
    cost one iteration).
  - **✅ FIXED IN WINE 11.16 (measured 2026-08-23).** The reproducer passes under WineForge 0.6.0.3
    (wine-11.16 + DXMT v0.80): the old swapchain's presents composite and animate. Since that DXMT
    is OLDER than ours, the fix is Wine's — `2293b0e` (client-surface reuse), which is in 11.16 but
    NOT 11.15. Upgrading the engine would retire this defect; the 10-patch stack would need
    re-validating on 11.16 first.
  - **Filed upstream 2026-08-23 as [dxmt#206](https://github.com/3Shain/dxmt/issues/206)** (AI
    assistance disclosed; no PR per their policy). **CLOSED 2026-08-24 by 3Shain as
    "duplication of [#183](https://github.com/3Shain/dxmt/issues/183)"** — that one line was the
    only maintainer response. #183 is still open, so anything further on this defect goes there.
  - Diagnostic kit that produced this: `scripts/diag-launch-dxmt11.sh` (WINEDEBUG trace) +
    `scripts/capture-freeze.sh` run while frozen. ⚠ The canonical launcher hard-set
    `WINEDEBUG=-all` and silently ate the first diag run's trace — it now respects a caller's
    `WINEDEBUG` (fixed 2026-08-23).

**Prior art upstream:** [#48](https://github.com/3Shain/dxmt/issues/48) (closed) is the same class —
"doesn't update screen contents unless switching fullscreen on/off" — but a different trigger, and
its `SetFullscreenState: stub` / `outstanding buffer hold` signatures do **not** appear in our v0.80
logs. No open issue covers focus-loss freeze (searched 2026-08-22). Draft report:
`docs/dxmt-bugs/DRAFT-focus-loss-freeze.md`.

**Both stacks misbehave on alt-tab** (D3DMetal/Wine 10 gave cursor desync and darkening; DXMT/Wine 11
gives this freeze), so it is not renderer-specific.

**RESOLVED FOR DAILY PLAY (2026-08-23, Option-2 test):**
- **Fullscreen Window mode is IMMUNE.** Tested in-city: alt-tab back and forth freely, input
  routes correctly, no freeze. This is now the recommended display mode. (The old "windowed
  thrashes display modes" gotcha #6a was the DXVK-era stack — does not apply to DXMT.)
- **Frozen in exclusive Fullscreen? Recover in-game, no force-kill:** blind-navigate (one
  alt-tab refresh per step) Options → Graphics → Display Mode → Fullscreen Window → Apply.
  The screen comes back LIVE. Trace shows NO new swapchain at the toggle — the game simply
  switches to presenting its windowed chain, which is the visible one. Mechanism confirmed
  from a second angle.
- Exclusive Fullscreen remains freeze-on-alt-tab **on the wine 11.0 wrappers** (`CS2dxmt11-pk110`,
  `S734M`). On the daily 11.16 engine it is fixed — see the ✅ line above. The fix came from Wine,
  not from dxmt#206, which the maintainer closed as a duplicate.

**Old practical rule (superseded): don't alt-tab out of exclusive fullscreen.** Use the windowed launcher
(`explorer /desktop=`) for sessions where you must switch between the game and a terminal; use
fullscreen for playing.

## Building a Wine engine from source for this stack (2026-08-23)

Five traps, each hit live while building the stock-11.16 + DXMT engine. All are encoded in
`scripts/build-engine-1116.sh`; this is why each line is there.

1. **brew's freetype/gnutls are arm64-only — an x86_64 Wine cannot link them.** Configure does a
   real link test: freetype failure is a *hard abort*, gnutls failure is a **silent** downgrade to
   "no schannel support" (= Steam TLS broken, discovered much later). Installing `pkgconf` does
   not help. Fix: pass `FREETYPE_LIBS`/`GNUTLS_LIBS` pointing at an existing wrapper's x86_64
   dylibs, with brew's (arch-neutral) headers.
2. **Pathless install names poison the recorded soname.** Those donor dylibs have install names
   like `libfreetype.dylib` with no path, so configure's soname extraction captures the *entire*
   `otool -L` line — tab, version parenthetical and all — into `SONAME_LIBFREETYPE`. Wine then
   `dlopen()`s that garbage at runtime and silently loses fonts + TLS. Fix:
   `ac_cv_lib_soname_freetype=libfreetype.dylib ac_cv_lib_soname_gnutls=libgnutls.dylib`.
   **Gate on `include/config.h` after configure — never trust "configure exited 0".**
3. **The build itself needs `DYLD_FALLBACK_LIBRARY_PATH`.** Build-time tools (`sfnt2fon`) link the
   same pathless name and die with `dyld: Library not loaded` partway through `fonts/`. Set it on
   the `gmake` line, not just at runtime.
4. **Run the one-time prefix update controlled, before the first launcher run.** A fresh 11.16
   prefix fires the wine-mono updater dialog; under a `-silent` Steam boot it has nowhere to
   present, everything queues behind it, and the *launcher* reports a bogus "Steam did not
   auto-login (token expired)". Tell: an idle `rundll32 …InstallHinfSection… wine.inf` at 0% CPU.
   Fix: `WINEDLLOVERRIDES="mscoree=;mshtml=" wine64 wineboot -u` first (~15 s).
5. **`gmake install` needs `--prefix`**, or it targets `/usr/local`. And a hand-copied engine is
   not bootable: it also needs `programs/*/*-windows/*` (wineboot, services, explorer) and all of
   `share/wine/` (wine.inf, nls, fonts) — `install` handles both; a naive `dlls/` copy does not.

## Two self-inflicted measurement bugs found by review, not by failure (2026-08-23)

Both had been silently wrong for a while; both were caught by adversarial review of a plan, then
fixed and *demonstrated* wrong the same session.

- **`run-minrepro3.sh` could fabricate a verdict.** `waitfor()` ended in `echo` on timeout, so it
  returned **success** — every `waitfor X && snap` fired regardless, sampling stale desktop
  pixels from a run that had already died. The printed `VERDICT:` line was a hardcoded string, not
  a computed result. Fixed: timeouts return 1 and abort, a failed/empty `screencapture` aborts,
  and the verdict is computed from the sampled RGB (`STALE`/`LIVE`/`INCONCLUSIVE`). Minutes after
  the fix a locked display made it abort cleanly — the old version would have printed
  "BUG REPRODUCED" over nothing. **Any harness that prints a conclusion it didn't compute is a
  liability.**
- **The launcher re-patched the wrong wrapper.** `launch-cs2-dxmt11.sh` called `repatch.sh`
  *without* `CS2_GAME_DIR`, so with `CS2_WRAPPER=` pointing anywhere else it patched the default
  wrapper while reporting success for the one it launched. Harmless-looking (patches are
  idempotent) until you run two wrappers — then a game update silently leaves the running one
  unpatched. The correct idiom already existed in `setup.sh`; only the launcher omitted it.

## AppleScript applet `progress` renders NO window on macOS 26 — use an AppKit panel (2026-08-23)

Building the dock-launch progress window, both canonical applet patterns produced a running
process with **zero windows** (System Events `windows` = empty, confirmed on two builds):

- stay-open applet (`osacompile -s`) setting `progress total steps` from `on run` and updating in
  `on idle` — no window, ever;
- plain applet with the whole poll loop inside `on run` (`repeat`/`delay`, the classic pattern
  that historically kept the panel alive) — still no window.

The `progress` properties execute without error; the panel simply never materializes. Fix that
shipped: a ~80-line Swift AppKit floating panel compiled by `make-shortcut.sh` at bundle-build
time (`xcrun swiftc`, CLT ships it), `.accessory` activation policy so it never takes focus or a
dock icon, `orderFrontRegardless()` + `.floating` + `.canJoinAllSpaces` for visibility. Verified
end to end the same night: renders, live milestone tracking from the launcher log, self-dismisses
2 s after the game process appears.

## `pgrep -f` self-match: your own watcher becomes "the game is running" (2026-08-23)

The shim's `pgrep -f 'Cities2.exe'` matched a *monitoring script* whose command line contained
the string (a background watcher polling for game exit) — so a dock click concluded "already
running", refused to launch, and showed nothing. The same trap the steamwebhelper rule documents,
now measured from the other side: **any** wrapper/watcher/editor whose argv mentions the pattern
is a false positive.

Scope on structure the real process must have and casual mentions won't: the game's argv is a
unix path, so match `'/Cities2.exe'` **with the leading slash** (watchers say `Cities2.exe`
bare). Applied in the shim's already-running check, its `GPID` capture, and the Swift panel's
game-up probe. Corollary: a test harness that greps for a process by name must never put that
name in its own command line unescaped (`pkill` excludes itself; `pgrep -f` does not).

## Resolution scaling on this stack: what works and what structurally cannot (2026-08-24)

Adjudicated live in one session (HUD + Settings.coc reads + relaunches). The traps:

- **The in-game Screen Resolution dropdown is INERT in Fullscreen Windowed.** Unity borderless
  always uses desktop resolution; the choice saves to `Settings.coc` but the swapchain never
  follows (verified across a relaunch: saved 1280×720, HUD input stayed 1920×1080). Resolution
  choices only bite in exclusive Fullscreen (mode-change/blanking class — see the refresh-rate
  section) or plain Windowed.
- **Consequently `DXMT_METALFX_SPATIAL_SWAPCHAIN` cannot downscale-render in borderless** — input
  is pinned at desktop res, so any factor >1 is supersampling (measured: softer AND slower — three
  resample passes for world text). MetalFX itself works (HUD `Scaling: Spatial` lines) — it's the
  display mode that kills the use case, not DXMT.
- **CS2 street names are painted onto roads in the 3D world, not drawn as UI** — any internal-
  resolution scaling (DRS included) softens them. "DRS keeps UI sharp" is true for menus/panels
  and useless for road text.
- **DRS Constant defaults to 50% scale** (`minScale: 0.5`, `EdgeAdaptiveScaling`) — brutal at
  1080p. The scale slider is double-gated: DRS must be *Constant* AND "SHOW ADVANCED" toggled.
- **Anti-aliasing was the actual jaggedness fix**: Low→High SMAA at native, cost ~1-2 FPS.
  Settings.coc also carries `outlinesMSAA: MSAA8x`.
- Reading `Settings.coc`: it is a title line + MULTIPLE concatenated JSON objects — `json.loads`
  fails with "Extra data"; use `JSONDecoder.raw_decode` in a loop. (Reading is fine; the standing
  rule against hand-EDITING it is unchanged.)

## Settings.coc: complete value edits ARE honored — the trap is PARTIAL flips (2026-08-24)

Refines the standing "never hand-edit Settings.coc" rule after a controlled experiment (game
closed, backup taken, one surgical value swap, functional verification):

- Edited `minScale` 0.75→0.5 in the DRS block. The game booted clean, **rendered at the edited
  scale** (benchmark gpuMs 40.5→33.7 avg, −17%, far beyond the ~11% run spread — functional
  proof, not just file survival), preserved the value through its exit rewrite, menu uncorrupted.
- The original 2026-08-22 trap stands for its actual mechanism: flipping an `enabled` flag whose
  companion parameters are absent/zeroed produces the "on but zeroed" Custom profile. **Complete,
  self-consistent value edits with the game closed are safe.** Always: backup first, edit with
  unique-anchor regexes asserting exactly one match, verify persistence after the next run.
- This unlocks autonomous settings A/B: `~/cs2-patch/perf-runs/settings-series.py` (edit → bench
  → verify → restore per cell). Menu label ↔ file value mappings are enums/floats, e.g. the menu's
  "AMD FidelityFX Super Resolution 1.0" saves as `upscaleFilter: "EdgeAdaptiveScaling"` (Unity's
  EASU name); other filter enums: CatmullRom, ContrastAdaptiveSharpen, TAAU.

## Steam Play button / Paradox Launcher — re-tested 2026-08-24: runs now, still doesn't deliver a game

The historical claim ("routes via the Paradox Launcher and exits before Unity initialises") is
stale in mechanism: on the 11.16 stack, `steam.exe -applaunch 949230` (the Play-button path) now
boots the full launcher — bootstrapper → `Paradox Launcher.exe` v2.2026.6 → Chromium UI window +
settings + update checks. It then dies on its own IPC: `cpatch took too long to connect`,
`set-auth-token command timed out`, `Socket server is not connected` (launcher-v2 logs under
`AppData/Local/Paradox Interactive/launcher-v2/logs/`). Unattended outcome unchanged: no game.
Community reports (M4, presumably CrossOver/Whisky-lineage Wine) of Play "just working" are
plausible — different Wine, different localhost-socket behavior — and do not replicate on stock
Wine 11.16. Direct `Cities2.exe` launch remains this stack's reliable path. Open question: does
the launcher's window render + does its own Play work when clicked (needs an attended try).

## Visible Steam UI black-windows on 11.16 — intermittent, dxmt#141-class; silent flow unaffected (2026-08-24)

Starting Steam WITHOUT `-silent` to click the Play button produced fully black CEF windows —
process healthy and logged in underneath, repaint (minimize/restore, resize) did NOT fix it, and
`-cef-disable-gpu-compositing` did NOT fix it either. This revises the V1 "dxmt#141 does not
reproduce" note: the library rendered fine on 2026-08-23, black on 2026-08-24 — the CEF
black-window class is **intermittent** here, not absent. The daily stack never hits it because
the launcher runs Steam `-silent` (tray only) and launches `Cities2.exe` directly. Consequences:
(a) any attended test needing the visible Steam UI (e.g. clicking Play to drive the Paradox
Launcher) is unreliable — parked; (b) any future dxmt#141 upstream comment must say
"intermittent", not "does not reproduce". Teardown from a black-window state: plain
`steam.exe -shutdown` works — the UI being black doesn't wedge the process.

## Steam's visible UI is BROKEN since the ~Aug-2026 CEF update — mechanism pinned, fix queued (2026-08-24)

Follow-up to the "intermittent dxmt#141-class" entry above — no longer intermittent, and the
mechanism is now measured. Steam's updated CEF initializes its GPU process on **Vulkan**:
`ANGLE Requires a minimum Vulkan instance` → `Internal Vulkan error (-9): The requested version
of Vulkan is not supported` → SwANGLE fallback fails the same probe → `Exiting GPU process` →
every Steam window is black (`logs/cef_log.txt` in the Steam dir). Our winevulkan → PK-era
x86_64 MoltenVK dylib reports too old an instance version. Full fix-ladder tried and dead:
repaint/resize · `-cef-disable-gpu-compositing` · client unpin + current build ·
htmlcache clear + `-cef-disable-gpu` · `--use-angle=d3d11` (flag DOES forward; Vulkan errors
vanish but the GPU process then crashes 0xC0000409 on the ANGLE→D3D11→DXMT path).

- **The game is unaffected** — the daily flow runs Steam `-silent` (tray only) and never renders
  this UI. Purchases/library management need another device or the queued fix.
- **Queued fix (own mini-project + plan): drop a newer x86_64 MoltenVK dylib into the engine** so
  winevulkan reports a modern Vulkan instance — likely also what differentiates the CrossOver/
  Whisky users who report Steam rendering fine (newer MoltenVK lineage).
- Secondary upstream lead: the 0xC0000409 ANGLE-on-D3D11 crash is DXMT-relevant evidence for
  dxmt#141 (stronger than anything currently on the thread).
- `steam.cfg` update pin (`BootStrapperInhibitAll`, a dead experiment's leftover) removed
  permanently — parked as `steam.cfg.disabled-20260824`. Re-pinning now would freeze a broken
  state; unpinned is the healthy default.

## Steam black UI is NOT the Vulkan failure — reboot retest disproves the queued MoltenVK fix (2026-08-24 PM)

Supersedes the mechanism in the section above on two points. James rebooted the Mac and asked for
a retest; four launch configurations were measured, each with its own `cef_log.txt` (kept in the
prefix as `logs/cef_log.E{0..3}-*.txt`). Window state judged per-window, not by eye — see the
capture method below.

**1. The reboot changes nothing.** E0 (stock `steam.exe -no-cef-sandbox`) reproduces the
pre-reboot log line for line. Not stale GPU state, not intermittent: deterministic.

**2. The failure ORDER was recorded backwards.** The GPU process does not "initialize on Vulkan"
first. It hard-crashes `exit_code=-1073740791` (0xC0000409) **three times before ANGLE logs
anything at all**; only the 4th, fallback attempt reaches ANGLE, fails the
`minimum Vulkan instance version of 1.1` probe, fails SwANGLE the same way, and prints
`Exiting GPU process`. So 0xC0000409 is the PRIMARY failure and Vulkan is what the fallback
hits — the reverse of what the previous section says, and it is why forcing `--use-angle=d3d11`
"made the Vulkan errors vanish but crashed 0xC0000409": that flag just deletes the fallback.

**3. New rung — Wine's builtin `vulkan-1` shadows Chromium's own loader.** The tell: SwANGLE
failed with the *same* "minimum Vulkan instance 1.1" message, which is impossible if it had
actually reached SwiftShader (that ICD is Vulkan 1.3, and `vk_swiftshader.dll` +
`vk_swiftshader_icd.json` ARE present in `bin/cef/cef.win64/`). Wine implements `vulkan-1`, so
builtin wins over the app-local native DLL and every ANGLE backend gets routed at
winevulkan → MoltenVK. Fix that with `WINEDLLOVERRIDES=…;vulkan-1=n,b` (native first, builtin
fallback) plus `--use-angle=swiftshader` — **E1 measured: every Vulkan error gone, GPU process
survives init and stops crashing. Window still black.**

**4. The decisive one — E3 removes the GPU stack entirely and the window is STILL black.**
`-cef-disable-gpu` + the `vulkan-1=n,b` override → `cef_log.txt` has **zero** GPU-process crashes
and **zero** Vulkan errors, a clean boot, browser process alive and working. Window black.

⚠ **Consequence: the queued "drop in a newer MoltenVK dylib" fix cannot be the fix.** E3 takes
Vulkan out of the picture completely and does not change the symptom. The black window has a
cause independent of the Vulkan/GPU-process stack — most likely in how CEF's browser process
presents into its HWND under this engine, which is the same surface the alt-tab freeze lived in.
Re-scope the mini-project before spending a build on it. A newer MoltenVK is still worth having
(it removes rungs 2-3 above), it is just not sufficient and probably not the cause.

**Flag-forwarding facts, so nobody re-tests these:** `--use-angle=<backend>` passed straight on
the `steam.exe` command line DOES forward to the webhelper (confirmed in
`logs/webhelper.txt` child-process lines). Chromium-style `--disable-gpu` /
`--disable-gpu-compositing` do **NOT** — Steam filters them, a gpu-process still spawns. Use
Steam's own `-cef-disable-gpu`, which forwards as `--disable-gpu-sandbox --use-gl=disabled`.

**Capture method — verify Steam's render state without fronting it or granting Accessibility.**
`osascript`/System Events needs Accessibility permission (and prompts for it — decline; it is not
needed). Instead enumerate with `scripts/winlist.swift` (CGWindowListCopyWindowInfo → `id`, owner,
size, title) and grab one window by id: `screencapture -x -o -l <id> out.png`. This works on
occluded windows, so it beats the hardcoded `-R x,y,w,h` regions the older capture scripts use.
**Validate the instrument before trusting a black reading** — capture a known-good occluded window
too (a partly-covered Messages window returned 252 KB of real content while the 1280x800 Steam
window returned a byte-identical 22980 across three separate runs = uniform black).

## ⚠ SUPERSEDED same day (see next section): the "11.0 → 11.16 regression" attribution below was
## disproven by a three-version stock sweep — stock 11.0 is ALSO blank. Kept for the measurements.

## Steam's black UI is a wine 11.0 → 11.16 REGRESSION, not a CEF/MoltenVK problem (2026-08-24 PM)

Settled by a controlled A/B against the parked `CS2dxmt11-pk110.app`. **Supersedes the two
sections above on the cause; their measurements stand, their attribution does not.**

**The comparison.** Same Mac, ~10 minutes apart, every variable except the engine verified
identical (not assumed): DXMT `d3d11.dll` 5304320 B and `dxgi.dll` 1753088 B in both ·
`libMoltenVK.dylib` 8096560 B in both · Steam client `-buildid=1785799196` and `steam.exe` /
`steamui.dll` mtime `Aug 3 16:46:16 2026` in both.

| | stock **11.16** (`CS2dxmt11`) | Porting Kit **11.0** (`CS2dxmt11-pk110`) |
|---|---|---|
| `exit_code=-1073740791` in `cef_log.txt` | many, every boot | **0** |
| `minimum Vulkan instance` | present | **0** |
| Steam window (per-HWND capture) | 22980 B **uniform black** | 1405591 B **full store page** |
| Interactive? | n/a | **yes** — James drove the account dropdown live on 2026-08-24, menus open and navigate |

**Three things this kills — don't re-derive them:**
1. **"The ~Aug-2026 CEF update broke it."** No: the client build is byte-identical in both
   prefixes. It broke when the 11.16 engine was promoted (2026-08-23).
2. **"Update MoltenVK."** No: the *same* dylib renders Steam fine on 11.0, and on 11.16
   `-cef-disable-gpu` takes Vulkan out of the path entirely with no change in symptom.
3. **"CEF's HWND presentation is being lost"** (by analogy with the alt-tab freeze). No: surfaces
   composite fine on 11.16 — the Paradox Launcher window comes through **white**, and the game's
   own window captures 3.4 MB of real content. The surface path works.

**What it actually is:** Chromium's GPU process **fastfails `0xC0000409`** on stock 11.16, ×3 per
browser start, before ANGLE logs anything. **Not Steam-specific** — the Paradox Launcher (separate
Electron app, different Chromium, no SDL) crashes identically in the same prefix
(`GPU process crash detected. Skipping quit…`). Engine-wide Chromium-on-11.16 defect.

⚠ **The instrument trap that nearly produced a wrong answer here.** A Win32 probe doing
`GetWindowDC` + `BitBlt`/`PrintWindow` on another process's window returns **nothing** under Wine —
`scripts/wingrab.c` primes its DIB with magenta and got 100% untouched magenta from Steam. That
looks like damning evidence until you run the same probe on `wine notepad`, which renders fine and
returns **the identical 100% untouched magenta**. Cross-process GDI readback does not work here;
the probe is only good for the window-tree dump. **Use the macOS side** (`scripts/winlist.swift` +
`screencapture -x -o -l <id>`) for pixels, and validate it against a known-good window each time.

**Practical, today:** keep `CS2dxmt11-pk110.app` — **do not delete it**. Play on `CS2dxmt11`
(11.16: faster, no alt-tab freeze); do Steam purchases/library on `CS2dxmt11-pk110` (11.0). Both
can hold a Steam resident simultaneously.

**Next step is a bisect, not more theory:** `scripts/build-engine-1116.sh` builds a sha-pinned
stock engine in ~1 hr and 11.0 → 11.16 is 16 releases, so binary search is ~4 builds. Gate each
build on `grep -c 'exit_code=-1073740791' cef_log.txt` — machine-readable, no eyeballing.

## Embedded Chromium NEVER rendered on stock Wine here — the PK vendor patchset is the enabler (2026-08-24 PM-2)

The afternoon's controlled program (three stock builds + env probes + patch test + module
transplants; driver `~/cs2-patch/bisect/`, results ledger `/tmp/bisect/results.log` while it
lives) settles the causal chain and **supersedes the version-regression attribution above**:

| cell | result |
|---|---|
| stock 11.0 / 11.15 / 11.16, identical configure, fresh-prefix launcher gate | **all BLANK, byte-identical captures** |
| PK 11.0 (vendor), same gate | RENDERED, repeatedly |
| PK + `WINE_SIMULATE_WRITECOPY=0` / `WINEMSYNC=0` | still RENDERED — neither is the enabler |
| stock 11.16 + Proton writecopy patch, env-armed, verified in binary | still BLANK |
| stock 11.0 + PK's win32u/winemac/user32/gdi32 transplanted | still BLANK |
| stock 11.0 + PK core (ntdll+wineserver) or + DXMT payload transplants | unstable/crashes — vendor modules interlock |
| `--in-process-gpu`: Electron (any engine) | breaks startup, no window — Electron dropped the flag |
| `--in-process-gpu`: Steam on the daily engine | **filtered, not forwarded** (webhelper children unchanged, same crash ladder) |

**Facts that anchor the diagnosis:**
- The PK engine is a **Gcenx vendor build from a private tree** (`wine-private` paths in its
  binaries), carrying at least: Proton-lineage `WINE_SIMULATE_WRITECOPY` (env/Battle.net-keyed —
  measured NOT active for our apps), the mach-semaphore msync patchset, and CrossOver-lineage
  `CX_LIBVULKAN` code in win32u. Its winemac.drv carries NO DXMT patch (PK wires DXMT another way).
- Config omission ruled out: fresh same-flag configures of 11.0/11.16 have config.h parity; all
  86 dylibs + DXMT binaries md5-identical between engines; module manifest deltas reconciled to
  upstream restructuring or non-graphics `--without` flags.

**Mechanism (supported, final visual proof pending):** Chromium's viz/software compositor paints
the browser's HWND **cross-process**; on winemac, GDI window surfaces are per-process, so a
foreign process's blit lands in its own shadow surface and never reaches the screen — on X11 the
drawable is server-side, which is why Linux never sees this. Same wall as dxmt#141's
"cross-process swapchain unsupported (upstream Wine limitation)" on the GPU path.
`scripts/crossblit.c` measures the naked primitive (green in-process paint vs red cross-process
paint, judged from the macOS side) — **its screen judge is queued on the next unlock**, along
with reruns of the two in-process-gpu pixel cells voided by the display lock (below).

**Consequences:** the fix is porting the relevant CrossOver/vendor support into the 11.16 engine
(own mini-project — start from public winecx source, find the shared-window-surface machinery),
or living with the two-wrapper split (play on `CS2dxmt11`, Steam UI on `CS2dxmt11-pk110` —
which remains **do-not-delete**). No amount of Steam/CEF flags can bridge it: Steam filters the
relevant Chromium switches (`--disable-gpu`, `--in-process-gpu`); `--use-angle` it forwards.

## screencapture goes silently blind when the display sleeps/locks (2026-08-24)

Mid-experiment the display slept and later showed the lock screen: `screencapture -l <id>` fails
("could not create image from window"), region captures write nothing, and a full-screen capture
returns an all-black frame — while **CGWindowList keeps working** (winlist still enumerates
windows correctly). Any pixel-based cell that ran in that state is VOID, not negative: two
`--in-process-gpu` pixel cells were discarded this way (their "no window" verdicts survived only
because winlist is display-independent). Before trusting any capture-based verdict, capture the
full screen once and eyeball it — the all-black/lock-screen frame is unmistakable. `caffeinate
-u -t 3` wakes the display, but a locked session stays locked (never enter credentials — park
visual work until the user unlocks).

## Mechanism CONFIRMED by elimination (2026-08-24 evening): cross-process PRESENTATION is the wall; PK wins only via its GPU path

Final round of measured cells (post-unlock), which corrects the "mechanism model" line in the
previous section — the model said PK carries generic cross-process surface support; it does not:

| cell | result |
|---|---|
| `crossblit.c` judge: cross-process GDI FillRect into a foreign window | **lost on BOTH engines** — stock AND PK stay pure green (in-process control paints fine). Cross-process `GetPixel` readback returns CLR_INVALID everywhere |
| child-process census during white-window state (stock) | identical healthy 5-process tree as PK's rendered state, zero churn — nothing is crashing; frames are produced and never presented |
| launcher `--disable-gpu` on stock 11.16 | white (18369 B) |
| launcher `--disable-gpu` on **PK** | **white, byte-identical 18369 B** — PK's software path is exactly as dead as stock's |

**The collapsed story, every 2026-08-24 measurement consistent:**
1. Chromium's software presentation (viz-composited frames → browser HWND) is broken on **all**
   winemac engines. That is the floor everyone stands on.
2. **PK renders CEF solely because its GPU path works**: ANGLE → D3D11 → DXMT presents
   cross-process through vendor plumbing (spanning winemac/win32u/wineserver — which is why
   module transplants into stock blanked or crashed; the machinery does not travel in pieces).
3. Stock engines fail the GPU path (wined3d/dead-GL without DXMT; `0xC0000409` fastfail with
   DXMT — dxmt#141's "cross-process swapchain not supported yet… upstream Wine limitation"),
   fall back to software, and hit floor (1): white/black window over healthy processes.
4. One defect family across dxmt#141 (Steam CEF black), dxmt#183 (ANGLE white window — whose
   author traced winemac's unrefcounted per-window Metal-view lifetime; dxmt#206, our alt-tab
   freeze, is now closed as its duplicate), and every white Electron/CEF window measured here.

**Consequences, final:** no flag can fix Steam on stock-lineage engines (software mode hits the
same wall; Steam filters the useful flags anyway). The only real fix for a single-engine setup
is cross-process presentation support in the engine (CX-lineage port or upstream work) — the
queued mini-project. Until then the two-wrapper split stands. Upstream: this evidence set
(vendor-vs-stock sweep, software-path parity of failure, transplant interlock) is precisely what
dxmt#141 lacks; comment pending James's go-ahead.

## ⚠ PARTIAL — see the correction section below: the shim fixes RENDERING but NOT TEXT.
## Steam's visible UI CAN render on stock Wine + DXMT — the webhelper shim (2026-08-24 evening)

Reverses the "no way to get Steam working on 11.16" conclusion. **Measured working in a
sandbox prefix: the Steam login window rendered fully** (logo, fields, QR) on the self-built
11.16 + DXMT engine — the same 700x440 window that captured 9,659 B of pure black that morning
came back at **80,714 B of real UI**, with every machine-readable signal flipping together:
gpu-process children 10 → **0**, `0xC0000409` crashes 6+ → **0**, metal-layer errors 12 → 1.

**The mechanism, in one line:** `--in-process-gpu` moves Chromium's GPU into the browser
process, so the swapchain is same-process — the path DXMT already serves for the game — instead
of the cross-process one it cannot (dxmt#141).

**Two traps that make this look impossible, and both must be solved:**

1. **steam.exe FILTERS the flag.** `--in-process-gpu` and `--disable-gpu` never reach
   steamwebhelper (verified against `logs/webhelper.txt` child cmdlines; gpu-process children
   spawn regardless). `--use-angle=<backend>` *does* forward. Steam's own switch set has no
   in-process option (`-cef-disable-gpu`, `-cef-disable-gpu-sandbox`, `-cef-disable-sandbox`,
   `-cef-disable-seccomp-sandbox`, `-cef-force-accessibility`, `-cef-force-gpu` — from
   `strings steam.exe`). So the flag must be injected AT the webhelper: rename the real binary
   to `steamwebhelper_real.exe` and drop a shim in its place that re-launches it with the flag
   appended (`scripts/steamwebhelper-shim.c`, installer `scripts/install-webhelper-shim.sh`).
2. **⭐ Steam restores the shim — unless it is SIZE-MATCHED.** A plain shim gets silently
   replaced and Steam exits **42**; that is what makes the whole approach read as dead. The
   tell is in `logs/bootstrap_log.txt`: **`Verifying installation... Verifying file sizes
   only`**. Zero-pad the shim to the original's exact byte count (7,489,176 for the Aug-2026
   client) and it passes verification untouched. A trailing-zero-padded PE runs normally.
   ⚠ This depends on Valve verifying sizes only — a hash check upstream kills it.

**Shim implementation notes that matter** (all in the .c file): forward `lpCmdLine` VERBATIM
with `bInheritHandles=TRUE` — Chromium passes live IPC/crashpad handle values on the child
command line and inherited handles keep their values; use `lstrcatW` into a 32K buffer, never
`wsprintf` (1K limit) since Chromium cmdlines are huge; Chromium spawns its own subprocesses
via the *running* image path (`steamwebhelper_real.exe`), so they bypass the shim and only the
top-level launch is wrapped. IFEO `Debugger` is NOT an alternative — Wine implements only
`AeDebug` (crash-time), not launch interception (`dlls/kernelbase/debug.c:555`).

**Re-apply after every Steam client update** (the update restores the original webhelper).
`bash scripts/install-webhelper-shim.sh` installs, `--revert` undoes; the original is preserved
in-tree as `steamwebhelper_real.exe` and offsite at `~/cs2-patch/shim/steamwebhelper.orig.exe`.

**Status:** sandbox-proven (login window). Store/library rendering under a real signed-in
session is the remaining confirmation. In-process GPU is an unsupported Chromium mode — watch
for long-session stability before calling it the project default.

## The webhelper shim renders everything EXCEPT text — `--in-process-gpu` is what kills glyphs (2026-08-24 late)

Correction to the section above, which called the shim a fix on the strength of a login window
that had rendered *images and layout*. It had **no text either** — the blank blue button should
have been the tell. With the shim, Steam draws artwork, thumbnails, gradients, icons and chrome
perfectly and **not one glyph**: no menu labels, no game titles, no prices, no search
placeholder. Only text baked into promo images appears.

**Isolated to the flag, not our engine:** the PK 11.0 wrapper renders Steam text fine normally,
and **loses text the same way the moment the shim is added**. ⚠ **CORRECTED 2026-08-30 — true only
for `--in-process-gpu`, the shim's compiled default. With the shim injecting `--disable-gpu
--single-process` instead, PK keeps ALL its text; the shim is not the text killer, in-process GPU
is. See § "CPU raster renders Steam WITH TEXT on an 11.0-lineage engine".** So `--in-process-gpu` breaks glyph
rendering in Chromium 126 CEF under Wine, independent of engine and graphics backend.

**Measured dead ends (all with the shim + `--in-process-gpu`, judged by per-window capture):**
`--disable-gpu-rasterization --disable-oop-rasterization` · `--disable-lcd-text
--disable-font-subpixel-positioning` · `--use-angle=swiftshader` **+ `vulkan-1=n,b`** (pure
software — proves it is NOT DXMT's glyph-atlas texture support) · `--disable-gpu-compositing` ·
`--disable-direct-write --disable-partial-raster` (GDI fonts instead of DirectWrite).
Also measured: **`--disable-gpu-compositing` WITHOUT `--in-process-gpu` = 22,980 B uniform black**,
i.e. the in-process flag is what buys rendering at all.

**Fonts are NOT the cause — don't re-chase this.** `scripts/fonttest.c` enumerates what Chromium
actually sees, and the daily 11.16 engine and PK 11.0 are *identical*: **924 GDI families, 204
DirectWrite families**, same names. ⚠ And an earlier claim in this session that our build lacked
DirectWrite FreeType support was **wrong**: our `dwrite.so` carries all 56 `pFT_*` pointers;
PK's shows none only because PK's binaries are **stripped** (its FT_ evidence is dlsym name
*strings*). Compare with `nm`, not `strings`, and never infer capability from file size.

**Net:** the shim converts "black window" into "usable-looking but textless window" — still not
practical for a public audience, so it is **not installed by default** and was reverted from the
daily wrapper. `scripts/install-webhelper-shim.sh` remains for anyone continuing this; the shim
takes `SHIM_ARGS` to swap injected switches without rebuilding + re-padding. The two-wrapper
split (play on `CS2dxmt11`, Steam UI on `CS2dxmt11-pk110`) stands as the practical answer.

**Still worth knowing (unchanged and independently useful):** steam.exe *filters*
`--in-process-gpu` / `--disable-gpu` but forwards `--use-angle`; and Steam's integrity pass is
**"Verifying file sizes only"**, so a size-padded replacement survives where an unpadded one is
restored with exit 42.

## Taking DXMT out of Steam's path entirely does NOT fix it — the vanilla-wined3d split, measured (2026-08-28)

The last untried route from [mikey92's dxmt#141
comment](https://github.com/3Shain/dxmt/issues/141#issuecomment-5448572368) and
[BCD1210/soju](https://github.com/BCD1210/soju/blob/main/docs/STEAM-GAMES.md): stop trying to make
DXMT serve Steam, and instead run the *client* on vanilla wined3d while the *game* keeps DXMT.
**Built, installed, measured, reverted. It does not work here.**

**Getting a vanilla PE cost a build.** Every `d3d11.dll`/`dxgi.dll` on this machine was DXMT's —
both arch trees and every `.bak`. A `build-engine-1116.sh` run stopped after step 3 yields stock
wine 11.16 (`gmake install`) *before* step 4 overlays DXMT; the vanilla PEs exist only in between.
Harvested: x86_64 `d3d11.dll` 4,584,886 B, i386 3,817,450 B, both version-matched to the engine.

⚠ **Do NOT identify a build by grepping for `dxmt`.** The harvested *vanilla* PEs carry **90**
"dxmt" hits — all of them build paths in debug info, because the source tree is named
`wine-11.16-dxmt`. That count would have failed the vanilla check and sent the whole trial down a
wrong path. The real discriminator is the API surface, and it is unambiguous:

| PE | Metal/winemetal refs | `wined3d_` refs |
|---|---|---|
| DXMT's `d3d11.dll` | **197** | 0 |
| vanilla `d3d11.dll` | 0 | **1,237** |

**The mechanism works exactly as soju documents it** — verified, not assumed. Wine marks its
builtins with the 17-byte signature `"Wine builtin DLL\0"` at file offset **0x40**; `build_module`
(`dlls/ntdll/loader.c`) computes `signature = base + sizeof(IMAGE_DOS_HEADER)` and `memcmp`s it, so
a `native` override aimed at a wine-built PE is redirected straight back to the builtin. Flip one
of those 17 bytes and it loads as true native. With that plus global `d3d11/dxgi=builtin` and
per-app `native` for `steam.exe`/`steamwebhelper.exe`/`steamservice.exe`, `+loaddll` confirms the
split landed:

```
Loaded L"C:\windows\system32\d3d11.dll" ...: native     <- vanilla, in Steam's processes
Loaded L"C:\windows\system32\wined3d.dll" ...: builtin
(no winemetal anywhere in Steam's tree)                    <- DXMT fully out of the path
```

**Result: still a uniformly black window, 108,343 B.** And the same 108,343 B with wined3d's
*Vulkan* renderer — byte-identical, which is the tell: **the D3D implementation is not the
variable — OUT-OF-PROCESS.** (⚠ Scoped 2026-08-29: *in-process* it is decisive and the sign flips —
DXMT renders, vanilla wined3d produces no window at all. See § "The vanilla-wined3d split is
strictly WORSE than DXMT for Steam's CEF".) Swapping out the entire D3D stack changed nothing, so
the failure is not DXMT's missing cross-process swapchain for the *client*; it is the
winemac/cross-process presentation layer, exactly as § "Embedded Chromium NEVER rendered on stock Wine" concluded. The PK vendor
patchset remains the only thing that has ever made this render.

**A second reason the route was never going to work as written:** wined3d's **GL** backend is
broken on macOS 26 at the most basic level — `err:d3d:wined3d_check_gl_call
GL_INVALID_FRAMEBUFFER_OPERATION (0x506) from glClear`. It cannot clear a buffer. (Its Vulkan
renderer is healthy, which is the correction in § Rendering 3.)

**Cost/benefit if anyone reconsiders:** ~1 h build + ~20 min to wire and measure. The two-wrapper
split (play on `CS2dxmt11`, Steam UI on `CS2dxmt11-pk110`) remains the practical answer.
`scripts/steam-vanilla-d3d-split.sh` keeps the whole apparatus — install / verify / revert, with
backups — so re-testing after an upstream winemac change is minutes, not another hour.
**Everything was reverted**; the game path re-verified as `d3d11: builtin` + `winemetal: builtin`.

## The glyph loss is IN-PROCESS GPU itself, not `--in-process-gpu` — `--single-process` fails identically (2026-08-28)

Prompted by [mikey92's dxmt#141 comment](https://github.com/3Shain/dxmt/issues/141#issuecomment-5448572368),
which reports a stable Steam client on an M4 Pro / macOS 26.5 / Homebrew `wine-stable` 11 by
running the *client* processes on vanilla wined3d and giving only games the DXMT builtins, with
notpop's wrapper forcing `--disable-gpu --single-process`. `--single-process` had **never been
tested here** (zero hits repo-wide before this date) — the whole earlier investigation used
`--in-process-gpu`. It was a one-env-var test because the shim already reads `SHIM_ARGS`.

**Result: `--single-process` renders exactly as much as `--in-process-gpu`, and loses text exactly
the same way.** Five measured cells on the daily self-built 11.16 + DXMT engine, judged by
per-window `screencapture` (black ≈ 15–41 KB, rendered ≈ 0.7–2.0 MB on the same windows):

| cell | GPU location | gpu-process children (this prefix) | window | capture |
|---|---|---|---|---|
| `--disable-gpu --single-process` (mikey92's pair) | in-process | 0 | **none** | — hot spin, 174 % CPU |
| **`--single-process`** | in-process | 0 | yes | **2,018,352 B — renders, ZERO glyphs** |
| control, no shim, no flags | out-of-process | crashes ×3 | yes | 40,903 B (black) |
| `--use-angle=gl` | out-of-process | crashes ×3 | yes | (see capture-blind note) |
| `--use-angle=vulkan` | out-of-process | crashes ×3 | yes | (see capture-blind note) |

**What this changes.** The open lead was *"why does `--in-process-gpu` kill glyphs?"* — that framing
is now wrong. **Any route that puts Chromium's GPU in the browser process renders art and drops
every glyph**, so the cause sits in the in-process-GPU path itself, not in one switch. Same
signature both times: artwork, thumbnails, gradients, icons and chrome perfect; nav bar reduced to
bare dropdown carets, empty search field, no titles or prices; the only readable text is baked into
promo images.

**And `--disable-gpu --single-process` is worse than either.** With no GPU *and* one process,
Chromium cannot make a GL context at all — `gl_factory_win.cc(63) NOTREACHED`, `Failed to create
GLES3 context, fallback to GLES2`, `ContextResult::kFatalFailure: Failed to create shared context
for virtualization`, looping at ~174 % CPU with **no window ever appearing**. mikey92's pair works
for them because their Steam client is on vanilla wined3d; on DXMT builtins it is a dead end,
which matches their own report of a 10 s webhelper restart loop.

**The cross-process wall is backend-independent.** Out-of-process, the GPU process crashes 3× in a
launch regardless of ANGLE backend — default (D3D11), `gl`, and `vulkan` all identical. So this is
not "DXMT lacks a D3D11 path"; nothing presents cross-process here.

⚠ **Instrument note — validate before trusting an all-black reading.** Two cells ran while the
display auto-locked; `screencapture` then produces **no file at all**, and the tell is
`owner=loginwindow` at layer ≥1999 in `/tmp/winlist`. Per `winlist.swift`'s own header, capture a
**known-good** window in the same pass — when the Firefox/Claude control also fails, the
instrument is blind and the cell is void, not black. Hold the display awake (`caffeinate -d -i -u`)
for any unattended cell.

**Adopted from soju's writeup and worth keeping:** a stale Chromium `SingletonLock` in `htmlcache`
silently turns the next Steam launch into `--silent` — i.e. **no window**, which reads exactly like
a render failure. `scripts/steam-render-cell.sh` purges it per cell.

⚠ **SUPERSEDED — this route was built and measured the same day, and again on 2026-08-29 in
combination with the shim. It does not work; it is strictly worse.** See § "Taking DXMT out of
Steam's path entirely does NOT fix it" and § "The vanilla-wined3d split is strictly WORSE than
DXMT for Steam's CEF". The paragraph below is kept for the harvesting recipe only.

**Was untested at the time of writing:** Steam's processes on **vanilla wined3d** while the
game keeps DXMT. It cannot be tried here today — every `d3d11.dll`/`dxgi.dll` on this machine is
DXMT's, in **both** arch trees and in every `.bak` (all 5,304,320 B / 7,780 dxmt strings), so there
is no vanilla PE to point a per-app override at. Harvesting one means a fresh
`scripts/build-engine-1116.sh` run (~1 h): step 3's `gmake install` lays down vanilla wine, and
step 4 is what overlays DXMT — the vanilla `d3d11.dll` + `dxgi.dll` exist in between.
⚠ Version-couple it: wine's `d3d11.dll` talks to `wined3d.dll` over an internal, per-release ABI,
so a vanilla PE must come from the **same 11.16 build**, not from the PK 11.0 tree.

⚠ Note also that our i386 tree is DXMT (`lib/wine/i386-windows/d3d11.dll`, 5,369,856 B) where
soju's rule 5 keeps i386 vanilla for the 32-bit steam.exe composer — **but that rule is not a
necessary condition**: `CS2dxmt11-pk110` carries the same DXMT i386 build (7,785 dxmt strings) and
renders Steam's text fine. Do not treat i386-vanilla as the explanation.

## The vanilla-wined3d split is strictly WORSE than DXMT for Steam's CEF — and the trap that nearly voided the test (2026-08-29)

[mikey92 on dxmt#141](https://github.com/3Shain/dxmt/issues/141) pointed out a real hole in the
2026-08-28 matrix: the split had only ever been run with **default out-of-process CEF**, and the
`--disable-gpu --single-process` pair had only ever been run on a **DXMT** client. The cell they
actually use daily — *both together* — had never been run here. They were right, it hadn't. It has
now, and it makes things worse rather than better.

⚠ **The trap, first — it silently invalidates any "split + shim" cell.** Wine keys
`HKCU\Software\Wine\AppDefaults\<exe>\DllOverrides` on the executable's **file name**, and
`install-webhelper-shim.sh` renames the real CEF binary to **`steamwebhelper_real.exe`** (the shim
takes the original name). So a split whose per-app list is `steam.exe steamwebhelper.exe
steamservice.exe` does **not** cover the process that actually loads d3d11 — it falls through to
the *global* override, which this split deliberately pins to `builtin` **= DXMT**. The first
combined cell ran clean, produced a plausible result, and was testing the DXMT client. The two
mechanisms only compose if **both** names are in the list; `steam-vanilla-d3d-split.sh` now carries
`steamwebhelper_real.exe` with that reasoning inline. Proof the fix landed, from `+loaddll` inside
the webhelper's own process tree: `dxgi.dll … native`, `wined3d.dll … builtin`, **no winemetal
anywhere**, alongside `steamwebhelper_real.exe`, `libcef.dll` and ANGLE's `libglesv2.dll`.

**Four cells, one variable at a time, judged by per-window capture:**

| cell | client d3d11 | shim args | window | CPU | result |
|---|---|---|---|---|---|
| `split-pair-v2` | vanilla wined3d | `--disable-gpu --single-process` | **none** | 174 % | mikey92's exact pair — hot spin |
| `split-ipgpu-swiftshader` | vanilla wined3d | `--in-process-gpu --use-gl=swiftshader` | **none** | 172 % | hot spin |
| `split-single` | vanilla wined3d | `--single-process` | **none** | 173 % | hot spin |
| **control** — `dxmt-single-control` | **DXMT** | `--single-process` | **yes** | **9.0 %** | **1,810,329 B rendered, ZERO glyphs** |

The control is the load-bearing row: it reproduces the 2026-08-28 reading (2,018,352 B then,
1,810,329 B now) on the same harness in the same session, so the three "no window" results are
measurements, not a broken rig. Store artwork, thumbnails, gradients and chrome are perfect; the
nav bar is six bare dropdown carets, the search field is empty, and no capsule has a title or
price. The only readable text is baked into promo images.

**Why the split fails — ANGLE names it, so this is not inference.** On vanilla wined3d *every* EGL
display type fails, in this order:

```
Renderer11.cpp:1108 (rx::Renderer11::populateRenderer11DeviceCaps):
    Error querying driver version from DXGI Adapter.              <- D3D11 path
eglCreateContext: Requested GLES version (3.0) is greater than max supported (2, 0).   <- GL path
eglInitialize SwANGLE failed with error EGL_NOT_INITIALIZED
    Internal Vulkan error (-9): The requested version of Vulkan is not supported ...   <- SwANGLE
Initialization of all EGL display types failed.
GLDisplayEGL::Initialize failed.
gl_factory_win.cc(63)] NOTREACHED hit.        <- then loops ~1,043,304 times in one 95 s cell
```

So the conclusion inverts the intuition the split was built on: **DXMT is the only D3D11 on this
stack that gives Chromium a working ANGLE display.** Its DXGI answers
`populateRenderer11DeviceCaps`; vanilla wined3d's does not, and neither fallback is available
(wined3d's GL backend caps at GLES 2.0 here — consistent with its `GL_INVALID_FRAMEBUFFER_OPERATION
from glClear` on macOS 26 — and SwANGLE's Vulkan is rejected outright). Taking DXMT out of the
client's path removes the one path that works.

**`--use-gl=swiftshader` is a dead switch on this CEF, not a missing idea.** Modern Chromium moved
software selection to `--use-angle=swiftshader`, which was **already measured here on 2026-08-24**
(with `--in-process-gpu` + `vulkan-1=n,b`) and renders art with no glyphs like every other
in-process route. The `--use-gl` spelling is worse than useless: it converts a *working*
`--in-process-gpu` cell into the same NOTREACHED loop. Don't re-chase it from the Battle.net
data point.

**Worth keeping from mikey92 regardless:** starting steam.exe with **`-noverifyfiles`** stops the
integrity pass from restoring a replaced `steamwebhelper.exe`, which is a cleaner alternative to
size-padding the shim (§ "Verifying file sizes only"). Our padded shim passes either way, so this
was not adopted — but it is the fix if Valve ever switches from sizes to hashes.

**Fixed in passing — `--verify` could never return.** `dxtest.exe` renders forever (its message
loop exits only on `WM_QUIT`), and piping it to `head` does **not** kill it because grep
block-buffers, so the SIGPIPE never arrives. Two `--verify` runs this session were written off as
"timed out" when the probe was doing exactly what it was written to do. macOS has no coreutils
`timeout`; the branch now launches, polls the log for up to 25 s, and kills. A verification step
that hangs is worse than none — the script's own output tells you to run it.

**Everything reverted and re-verified**: DXMT builtins restored (`metal=197 wined3d=0`, builtin
marker back), all per-app overrides deleted, shim reverted to the original 7,489,176 B webhelper,
and the game path re-checked with the now-working `--verify` — `winemetal.dll builtin`,
`DXGI.DLL builtin`, `d3d11.dll builtin`.

## ⚠ The split never gave Steam a WORKING D3D11 — a load is not an implementation (2026-08-29)

**This corrects the 2026-08-28 conclusion two sections up, and the comment posted from it.** Asked
whether anything else was worth testing before replying to mikey92, the answer turned out to be
yes, and it inverted the result.

`scripts/dxgiprobe.c` (new) calls the *exact* query ANGLE's D3D11 renderer fails on —
`IDXGIAdapter::CheckInterfaceSupport(__uuidof(IDXGIDevice), &umdVersion)`, which is what
`Renderer11::populateRenderer11DeviceCaps` uses for the driver version — and then tries
`D3D11CreateDevice`. Build:
`x86_64-w64-mingw32-gcc dxgiprobe.c -o dxgiprobe.exe -ld3d11 -ldxgi -ldxguid -luuid`.

| configuration | `CheckInterfaceSupport` | `D3D11CreateDevice` |
|---|---|---|
| **DXMT** (`d3d11=b,dxgi=b`) | **`0x00000000` S_OK** | **`0x00000000`, FL `0xB000`** |
| vanilla d3d11 + vanilla dxgi (`n,n`) | — never reached — | **abort** |
| vanilla d3d11 + DXMT dxgi (`n,b`) | — never reached — | **abort** |
| DXMT d3d11 + vanilla dxgi (`b,n`) | `0x00000000` S_OK | `0x00000000`, FL `0xB000` |

Both vanilla-`d3d11` rows die before the probe's first `printf`:

```
wine: Call from 00006FFFFFC16AEA to unimplemented function dxgi.dll.DXGID3D10CreateDevice, aborting
```

with **either** dxgi underneath it. (String counts: the harvested vanilla `dxgi.dll` carries
`DXGID3D10CreateDevice` **7** times; DXMT's carries it **0** — so DXMT's dxgi does not export it
at all, and the vanilla one exports it as a winebuild stub.)

**What this overturns.** The 08-28 finding read: *the split provably landed, Steam is still black,
byte-identical on wined3d's GL and Vulkan renderers — therefore the D3D implementation is not the
variable and the client's black window was never DXMT's missing cross-process swapchain.* That
comparison was against a **non-functional** alternative. `+loaddll` proved the vanilla PE **loaded**;
it never proved the PE **worked**, and a d3d11 that aborts at device creation cannot render
anything by any route. "Black either way" was therefore never evidence about DXMT. The
byte-identical GL-vs-Vulkan reading has the same hole — both runs were black for the same trivial
reason.

⚠ **The transferable rule, and the one this whole thread kept missing: a module load is not a
working implementation.** Verify any swapped graphics DLL with a **device-creation probe**
(`scripts/dxgiprobe.exe`), never with `+loaddll` alone. Three separate sessions took a `native`
line in a loaddll trace as proof the swap had taken effect.

**RESOLVED the same session — wired properly, vanilla wined3d works, and it is still disqualified,
for a reason nothing had measured before.** The discriminator: vanilla `d3d11.dll` + `dxgi.dll`
installed as **true builtins** (marker intact) into an APFS-cloned wine tree
(`cp -Rc`, instant and free), driven from a scratch prefix.

| configuration | adapter reported | `CheckInterfaceSupport` | `D3D11CreateDevice` |
|---|---|---|---|
| **DXMT** | **Apple M3 Max** (0x106B / 0x1A0603F1) | **S_OK** | **FL `0xB100` = 11_1** (explicit list; `0xB000` = 11_0 via NULL list) |
| vanilla wined3d, GL renderer | *"NVIDIA GeForce 6800"* (0x10DE/0x0041 — wined3d's fallback card) | `0x887A0004` **DXGI_ERROR_UNSUPPORTED** | FL `0x9300` = **9_3** (both forms) |
| vanilla wined3d, `renderer=vulkan` | **Apple M3 Max** (correct) | `0x887A0004` **DXGI_ERROR_UNSUPPORTED** | FL `0x9300` = **9_3** (both forms) |

Three things fall out, and the middle one is the answer:

1. **The marker-strip/`native` trick is what aborts, not wined3d.** As true builtins the same PEs
   create a device fine. So the split *as wired here* was broken; soju's technique needs different
   wiring on this stack.
2. **`0x887A0004` is `Renderer11.cpp:1108` — reproduced outside Chromium.** ANGLE's "Error querying
   driver version from DXGI Adapter" is literally wined3d's dxgi returning `DXGI_ERROR_UNSUPPORTED`
   from `CheckInterfaceSupport`. DXMT returns `S_OK`. This is now a measured API delta rather than
   an inference from a CEF log.
3. **Vanilla wined3d tops out at feature level 9_3 here — DXMT reaches 11_1.** That holds even with
   the Vulkan renderer correctly identifying the M3 Max, so it is not the fallback-adapter bug.
   ⚠ **Asked BOTH ways before publishing**, because the first pass used only `pFeatureLevels=NULL`
   (the runtime's default list) and a single-form measurement is how this project has produced a
   wrong headline number before: with an **explicit** `{11_1, 11_0, 10_1, 10_0, 9_3}` array,
   vanilla wined3d still returns **9_3** and DXMT returns **11_1**. The probe now prints both.

⚠ **RESOLVED — the valid test was built and run the same day; see the next section.** The finding
below stands as the reason it was needed: **every Steam cell run against the split before that point
— 08-28 and 08-29 alike — used the broken marker-strip wiring.** Those cells were not measuring a
vanilla-wined3d client; they were measuring a client whose `d3d11.dll` aborts at device creation.
The "no window, ~174 % spin" rows say nothing about wined3d. **A valid Steam-side test of the split
has still never been run here**, and it cannot be run with the marker-strip trick at all — the
true-builtin wiring is engine-global, so it would take the game's DXMT away too. It needs a
separate wrapper (clone the tree, install vanilla builtins, point it at a Steam-bearing prefix).
Not yet done; do not describe the split's Steam behaviour as measured until it is.

**Was NOT established at this point:** that FL 9_3 is what breaks CEF — the `Requested GLES version
(3.0) is greater than max supported (2, 0)` line was logged in a cell whose d3d11 aborts, so ANGLE
may never have reached a D3D11 device. ✅ **Settled by the valid run in the next section**, where the
same line appears on a working FL 9_3 device.

⚠ Two traps found setting the scratch prefix up, both of which cost ~15 min of apparent hang:
wine **refuses a `WINEPREFIX` under `/tmp`** ("is not owned by you"), and a fresh-prefix `wineboot`
**blocks on the Wine Mono installer dialog** with no console output at all — it looks exactly like
a hang. Always create scratch prefixes with `WINEDLLOVERRIDES="mscoree=d;mshtml=d"`.
⚠ And the orphaned `wineboot.exe` processes could **not** be killed with `pkill -f wine-vanilla-test`
— wine processes carry Windows-style argv, the same attribution trap this repo already documents
for steam.exe. Kill by PID after checking `lsof` against the prefix.

## The valid Steam-side test at last: DXMT beats vanilla wined3d at EVERY cell (2026-08-29)

The section above closed with "a valid Steam-side test of the split has never been run here." It has
now. `scripts/make-vanilla-wrapper.sh` builds the thing that makes it possible: an APFS clone of the
daily wrapper (`cp -Rc`, ~0 disk on a 103 GB bundle) whose **wine tree** carries the vanilla
`d3d11.dll`/`dxgi.dll` as **true builtins, marker intact**. That wiring is engine-global — which is
exactly why it cannot be done in the daily wrapper, and why a separate bundle was the only route.

Probe first, in the clone's own Steam-bearing prefix: **FL `0x9300` (9_3) both ways, adapter
"NVIDIA GeForce 6800" (wined3d's fallback card), `CheckInterfaceSupport` = `0x887A0004`.** Same
numbers as the scratch prefix, so the wrapper is a faithful vehicle.

**Client on REAL vanilla wined3d** (all capture-judged, instrument validated every cell):

| switches | gpu-process children | crashes | window |
|---|---|---|---|
| none — out-of-process, GL renderer | **1** | **0** | black, **30,482 B** |
| none — out-of-process, `renderer=vulkan` | **1** | **0** | black, **30,482 B — byte-identical** |
| `--in-process-gpu` | 0 | 0 | **none** |
| `--single-process` | 0 | 0 | **none** |
| `--disable-gpu --single-process` (mikey92's pair) | 0 | 0 | **none**, 174 % spin |

**Same cells on DXMT**, for the comparison that was never valid before:

| switches | gpu-process children | crashes | window |
|---|---|---|---|
| none — out-of-process | crashes | **×3** | black, ~40 KB |
| `--in-process-gpu` | 0 | 0 | **renders**, zero glyphs |
| `--single-process` | 0 | 0 | **renders, 1,810,329 B**, zero glyphs |
| `--disable-gpu --single-process` | 0 | 0 | none |

**Conclusion, now properly evidenced: on this machine DXMT is strictly better than vanilla wined3d
at every cell.** The split isn't a missed opportunity; it's a downgrade. The in-process modes that
buy a rendered (if textless) window on DXMT produce **no window at all** on wined3d, and the CEF log
from a *working* vanilla client finally makes the chain attributable end to end:

```
Renderer11.cpp (populateRenderer11DeviceCaps): Error querying driver version from DXGI Adapter.
eglCreateContext: Requested GLES version (3.0) is greater than max supported (2, 0).
eglInitialize SwANGLE failed with error EGL_NOT_INITIALIZED
Initialization of all EGL display types failed. -> gl_factory_win.cc(63) NOTREACHED (×1,127,264)
```

A FL 9_3 D3D11 device lets ANGLE offer **GLES 2.0 only**; CEF asks for **3.0**; every EGL display
type then fails. On 08-29 this was explicitly flagged as correlation-not-chain because the log came
from the broken wiring — this run had a genuinely working D3D11 device, so the attribution holds.

⚠ **And the 08-28 conclusion turns out to be right for reasons it never had.** Its *reasoning* was
invalid (it compared against a d3d11 that aborts). But the out-of-process rows above are the
evidence it lacked: on vanilla wined3d the **GPU process is healthy — 1 child, zero crashes** — and
the window is **still black, byte-identical across wined3d's GL and Vulkan renderers**. A healthy
cross-process GPU that still cannot present is a presentation-layer wall, independent of D3D. So
keep the conclusion, discard the old argument for it, and cite these rows instead.

⚠ **Harness trap found here: with the shim installed, an empty `--shim-args` is NOT "no flags."**
`steamwebhelper-shim.c` falls back to its compiled `APPEND` default of `--in-process-gpu` when
`SHIM_ARGS` is unset, so a "control" cell run with the shim in place silently tests in-process GPU.
One cell was thrown away to this. **For a true out-of-process control, revert the shim** — don't
just omit `--shim-args`.

**Tooling kept:** `scripts/make-vanilla-wrapper.sh` (`--build` / `--verify` / `--remove`) and
`scripts/dxgiprobe.c`. The wrapper itself was **removed** after the run — a Steam-bearing,
DXMT-less bundle sitting in `~/Applications` next to the real ones is a footgun, and `--build`
recreates it in about a minute.

## There is a THIRD mechanism for Steam's CEF, and we had never read its source (2026-08-29)

Asked "are there other sources of workarounds to check before posting?", the answer was yes, and it
reframes the whole thread. mikey92's wrapper comes from **[notpop/steam-on-m1-wine](https://github.com/notpop/steam-on-m1-wine)**
— a source `REFERENCES.md` never listed and this project had never opened (zero hits repo-wide
before today). Its README says the enabler is **not** the vanilla-wined3d split at all. It is two
things we do not have:

1. **`winemac.so` rebuilt with `-fvisibility=default`** (`scripts/08-patch-wine-visibility.sh`),
   *"to make macdrv's public API callable by third-party Metal layers"* — one module, not the whole
   tree: `configure --enable-win64 --disable-tests CFLAGS='-fvisibility=default -O2 -Wno-error'`
   then `make dlls/winemac.drv/winemac.so`. Their own success check is `nm -g` showing **≥100
   public text symbols**.
2. **A DXMT fork** — `notpop/dxmt@debug/present-path-tracing`
   (`924a607e3eee06fad5be6f176d8510bb08bc418d`), ~150 lines over upstream, which *"rewrites
   `_CreateMetalViewFromHWND` around two Wine 11 bugs"*: `macdrv_win_data` no longer exposing a
   usable NSView at swap-chain creation, and wrapping macdrv's Metal helpers in Wine's
   `OnMainThread` deadlocking on re-entrance.

**Measured here immediately, and the numbers matter:**

| engine | global syms in `winemac.so` | **public TEXT (`T`)** | renders Steam? |
|---|---|---|---|
| our self-built stock 11.16 + DXMT | 550 | **0** (2 `S` + 1 `D _macdrv_functions`; the rest `U`) | no |
| **PK 11.0 vendor build** | 535 | **0** (2 `S`) | **YES** |
| notpop's patched build | — | **≥100** (their gate) | yes |

**So there are at least THREE independent mechanisms, and symbol visibility is not the one PK
uses.** PK renders Steam while exporting exactly as little as we do — which *confirms* the
2026-08-24 PM-2 conclusion (PK wins via its vendor patchset) rather than replacing it, and shows
notpop's route is a genuinely separate third path that our engine has never had.

Supporting detail: our `winemac.so` does contain the helpers by name —
`macdrv_view_create_metal_view`, `macdrv_view_get_metal_layer`, `macdrv_view_release_metal_view`
(plus `my_`-prefixed variants) — and `winemetal.dll` in **both** wrappers carries
`CreateMetalViewFromHWND`. The functions are all present; they are simply not *exported*, which is
exactly the gap `-fvisibility=default` closes.

⚠ **What this means for the reply to mikey92:** they attribute their working client to the
vanilla-wined3d split, but per notpop's own README their stack also carries the visibility rebuild
**and** the forked DXMT. The split may not be what is carrying it. That is worth raising — carefully,
since we cannot see their specific install — and it makes the "which EGL display initializes"
question much less interesting than "are you on notpop's patched `winemac.so` and DXMT fork?"

**HALF 1 TRIALLED THE SAME DAY — built, gated, measured, and it changes nothing on its own.**
`scripts/build-winemac-visibility.sh` rebuilds **only** `dlls/winemac.drv/winemac.so` from the same
DXMT-patched 11.16 source the engine uses (`wineandaqua-dxmt.patch`), with the engine's exact
configure line plus `CFLAGS/CXXFLAGS='-fvisibility=default -O2 -Wno-error'`. Result:

| | public TEXT symbols | `macdrv_*` public |
|---|---|---|
| installed engine | **0** | 0 |
| rebuilt module | **213** ✅ (notpop's gate is ≥100) | **183** |

and the exports are exactly the ones the fork needs — `macdrv_view_create_metal_view`,
`macdrv_view_get_metal_layer`, `macdrv_view_release_metal_view`,
`macdrv_client_surface_acquire_metal_swapchain`, plus `get_win_data`/`release_win_data` (the
`macdrv_win_data` accessors named in notpop's bug description).

**Installed into a clone wrapper it is ABI-clean but inert**: wine 11.16 starts, no driver errors,
DXMT still reports Apple M3 Max at **FL 11_1** — and Steam is **still black (108,343 B**, GPU
process healthy, 1 child, 0 crashes**)**. That is the expected result: per notpop's own README the
flag exists to make macdrv's API *callable by* the forked DXMT, so it is an enabler, not a fix.
**Half 1 is necessary-not-sufficient; the fork is the active ingredient.**

⚠ **The first run of that cell reported "no window" and was WRONG** — Steam was still verifying its
install at the 95 s mark. Re-run at `--wait 165` it produced the window. **A no-window reading on a
freshly-cloned wrapper means "not finished starting" until a longer wait says otherwise.**
⚠ Also ruled out while diagnosing that: `Wine cannot find the FreeType font library` appears in
**every** Steam cell including the one that renders (17 occurrences in the successful
`--single-process` run, 59 in others). It is pre-existing noise, not a symptom — do not chase it.

**HALF 2 ATTEMPTED — it gets all the way to the Metal shader compiler and stops there.**
`scripts/build-dxmt-fork.sh` captures the whole verified recipe. What was learned:

- ⚠ **Do NOT build LLVM from source.** notpop's own script compiles `llvmorg-15.0.7` (~1 h). It is
  unnecessary: the fork's meson default `native_llvm_path` is already **`/usr/local/opt/llvm@15`**,
  i.e. the **Intel**-Homebrew prefix, because airconv links LLVM as a macOS **x86_64** static lib to
  match our x86_64 wine. An Intel Homebrew already exists on this machine, so
  `arch -x86_64 /usr/local/bin/brew install llvm@15 zstd` drops a bottle at exactly that path with
  `libLLVMCore.a` present — **minutes instead of an hour**. (The arm64 `/opt/homebrew` `llvm@15` is
  the wrong arch and will not do.)
- **meson configures cleanly against our own engine**: `-Dwine_install_path=…/engine-1116` resolves
  `winecrt0`, `ntdll`, `dbghelp` and `bin/winebuild`. 16 targets, no complaints.
- **A real portability bug in the fork, found and fixed here:** `src/util/com/com_guid.cpp` uses
  `std::setfill`/`std::setw` without `#include <iomanip>`. Older GCC pulled it in transitively; our
  mingw-w64 does not. One line — kept as `scripts/dxmt-fork-iomanip.patch`, and worth sending to
  notpop. With it applied the **entire C++ side builds clean**.
- 🚧 **The remaining blocker is FULL XCODE, and only that.** The build compiles Metal shaders with
  `xcrun -sdk macosx metal`, which ships with Xcode.app and is **not** in the Command Line Tools
  (this machine has CLT only: `xcode-select -p` → `/Library/Developer/CommandLineTools`). Measured:
  of 7 remaining `FAILED` lines, **7 are `unable to find utility "metal"` and 0 are anything else**.
  Fix is the user's: install Xcode from the App Store, then
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (and
  `xcodebuild -downloadComponent MetalToolchain` if `xcrun -f metal` still fails). Neither is
  runnable unattended.

⚠ **`meson compile … | tail` reported the failing build as exit 0** and it was briefly read as a
success. Same class as the `<cmd> | tail` trap in the engineering rules — **capture to a log and
read the real `$?`**. `build-dxmt-fork.sh` does that.

**What the fork's commit message says — the best statement of this bug that exists anywhere**, and
it is worth quoting to dxmt#141 whether or not we ever build it. Two stacked root causes, both with
file:line:
1. `struct macdrv_win_data` is the wrong place to read the NSView: **Wine 11 renamed the field to
   `client_view` and only populates it in the GDI present path**
   (`dlls/winemac.drv/window.c:1131-1135`, `macdrv_client_surface_present()`). At `IDXGISwapChain`
   creation time it is **always NULL**, so the old code handed `macdrv_view_create_metal_view` a
   NULL view and returned silently empty.
2. `macdrv_view_create_metal_view` / `_get_metal_layer` / `_release_metal_view`
   (`cocoa_window.m:3941/3954/3966`) **already dispatch through `OnMainThread(^{…})`**. Wrapping
   them in another `OnMainThread` in the unixlib is nested main-thread dispatch — and `OnMainThread`
   (`cocoa_event.m:489`) is `OnMainThreadAsync` + wait, so **the outer wait deadlocks against the
   inner block**.

The rewrite reaches the NSView via the stable public `macdrv_get_cocoa_window(HWND, BOOL)` plus
`[NSWindow contentView]`, dispatches only the contentView lookup, and calls the Metal helpers
directly from the NtUser caller thread so their internal main-thread hops are not re-entered.

⚠ **Read their verification claim precisely: it is a GAME, not the Steam client.** *"Verified on
Apple Silicon M1 + macOS Tahoe 26.4 + Wine 11.0 rebuilt with `-fvisibility=default`, running the
32-bit Unity 6000 game 幻獣大農場 (Steam AppID 3659410): Present1 returns hr=0x0 every frame."*
So the fork is evidenced for **game** presentation. Whether it also fixes the **CEF client** is not
claimed there — which is exactly the question to put to mikey92, since their Steam UI may be riding
on the `--disable-gpu --single-process` wrapper rather than on this patch.

 Measured 2026-08-29: **`meson`, `ninja`, `llvm-config` and `cmake` are all
missing** on this machine (only Apple clang + git). notpop's `07-build-dxmt-fork.sh` needs meson
with `-Dnative_llvm_path` and two cross-files, built twice (64- and 32-bit). **`notpop/dxmt` also
publishes NO releases**, so there is no prebuilt fork to drop in — it must be compiled. Every DXMT
binary in this project was *reused* from the Wine 11.0 + DXMT base engine, never compiled. Standing
up that toolchain is ~2-3 GB of brew installs and its own mini-project.

**Also eliminated today, both never previously run** (daily wrapper, capture-judged):
`-cef-force-gpu` → black **108,343 B**, GPU process survives (1 child, no crashes) ·
`--use-angle=d3d9` → black **108,343 B**, same. So ANGLE's D3D9 backend and Steam's own
force-GPU switch join `d3d11`/`gl`/`vulkan`/`swiftshader` on the eliminated list.

## ✅ notpop's fork BUILT and TESTED — it does not fix the Steam client, and that restores dxmt#141 (2026-08-29)

Both halves of the third mechanism were built and run end to end. The result is decisive and it
points back at the issue itself.

**Getting there.** `xcrun -f metal` resolving is **not** a sufficient gate — with Xcode installed
the binary exists but on macOS 26 the shader compiler is a separate asset, and every `.air` target
still died with *"cannot execute tool 'metal' due to missing Metal Toolchain"*.
`xcodebuild -downloadComponent MetalToolchain` (687.9 MB, "Metal Toolchain 17F109") fixed it.
`build-dxmt-fork.sh` now gates by **compiling a one-line kernel**, not by `xcrun -f`.
Then both arches built clean — 64-bit `[123/123]` — producing `d3d11.dll` (22,952,314 B),
`dxgi.dll`, `d3d10core.dll`, `winemetal.dll` and `winemetal.so` (27,924,584 B), plus the 32-bit set.

**Installed into a clone carrying BOTH ingredients** (forked DXMT + the `-fvisibility=default`
`winemac.so`, 213 public text symbols), the engine is healthy: Apple M3 Max, `CheckInterfaceSupport`
`S_OK`, **FL 11_1**.

**And Steam is still black — but now it says why, in DXMT's own words:**

```
err:   CreateSwapChain: cross-process swapchain not supported yet
```

`src/d3d11/d3d11_swapchain.cpp:1102`. **The fork still refuses cross-process swapchains.** Verified
by string count: the built forked `d3d11.dll` carries that message **1** time; our stock DXMT v0.80
carries it **0** times (it is newer upstream code — v0.80 merely crashed the GPU process instead of
naming the refusal).

**What that settles.** notpop's fork rewrites `_CreateMetalViewFromHWND` for the **same-process**
path — which is why their evidence is a *game* (`Present1 returns hr=0x0 every frame`) and why it
works there. Steam's CEF creates its swapchain for an HWND owned by **another process**, and that is
a different code path which the fork does not touch. So:

- the vanilla-wined3d split is dead here (wined3d caps at FL 9_3),
- notpop's visibility + fork route fixes games, not the client,
- and therefore **dxmt#141 itself — cross-process swapchain support — really is the blocker for the
  Steam client.** Every workaround is now eliminated *by measurement*, which is a better outcome
  than another dead end: it puts the fix back where the issue already says it belongs.

⚠ **The fork does change the failure mode, which is worth reporting.** Out-of-process on stock DXMT
v0.80 the GPU process crashes ×3 per launch; with the fork ANGLE gets **further** — it reaches
`SwapChain11::reset` (*"Could not create additional swap chains or offscreen surfaces"*) and
`eglCreateWindowSurface: Bad allocation` — before the same black window. A crash became a named
refusal. That is a diagnosability win even though the outcome is unchanged.

**And it explains mikey92 without contradicting them.** Their client renders because *their* wined3d
serves D3D11 at a usable feature level (Wine 11.0 / macOS 26.5), taking DXMT out of the CEF path
entirely — the split IS load-bearing for them. Ours caps at 9_3, so the same split cannot work.
The feature-level probe is exactly the discriminator, which is why the reply asks for it.

**Cleanup:** shim reverted in the clone; daily wrapper verified pristine (`d3d11` 5,304,320 B = stock
v0.80, `winemac.so` 0 public T, game path `d3d11 -> builtin`). `CS2vis-test.app` retains the full
notpop stack and is the artefact to keep if this is revisited — **never run the game in it.**

## The cross-process root cause, MEASURED: `macdrv_get_cocoa_window` returns NULL for a foreign HWND (2026-08-29)

The refusal in DXMT is a **precondition check that returns before attempting anything**
(`src/d3d11/d3d11_swapchain.cpp`, `CreateSwapChain`):

```c
GetWindowThreadProcessId(hWnd, &window_process_id);
if (GetProcessId(GetCurrentProcess()) != window_process_id) {
  ERR("CreateSwapChain: cross-process swapchain not supported yet");
  return E_FAIL;
}
```

So **nobody had ever observed what actually breaks.** Upstream `3Shain/dxmt` has four branches
(`main`, `ci/arm64x`, `feat/d3d12-5`, `feat/d3d12-6`) — no work in progress on this. We had a
working build, so we forced it: the guard was made env-gated
(`DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1`, kept as `scripts/dxmt-force-crossprocess.patch`) and the
Steam cell re-run.

**It fires, with genuine cross-process IDs** — 6 times in one launch:

```
err: CreateSwapChain: cross-process swapchain FORCED (experimental) hwnd_pid=300 self_pid=472
```

**And then the real failure, with `DXMT_DEBUG_METAL_VIEW=1`:**

```
CreateMetalViewFromHWND: hwnd=0x10102 macdrv_functions=0x213810560
    get_cocoa_window=0x2137e3d20 create_metal_view=0x2137e3df0 get_metal_layer=0x2137e3e40
CreateMetalViewFromHWND: cocoa_window=0x0
CreateMetalViewFromHWND: macdrv_get_cocoa_window returned NULL for hwnd=0x10102.
```

Three things follow, and each kills a wrong explanation:

1. **Every macdrv symbol resolved** (all pointers non-NULL). So DXMT's own error —
   *"Failed to create metal view, it seems like your Wine has no exported symbols needed by DXMT"*
   (`d3d11_swapchain.cpp:137`, followed by `abort()`) — is the author's **guess**, and it is the
   wrong diagnosis whenever the symbols are in fact present. It is what makes this failure look
   like a build problem when it is not.
2. **`macdrv_get_cocoa_window(hwnd, FALSE)` returns NULL for the foreign HWND.** Winemac's window
   data is **per-process**; a window created by another process is not in this process's table.
   That is the actual wall.
3. **The fork's own fallback comment is also wrong here** — it reads *"the window is probably still
   in the middle of being created; the caller will retry"*. It is not mid-creation; it belongs to
   another process and will never appear. Meanwhile the D3D11 side `abort()`s on the NULL, which is
   the `GPU process exited unexpectedly` in `cef_log.txt`.

**So "cross-process swapchain not supported yet" is not swapchain bookkeeping.** A Metal view cannot
be built for a foreign HWND at all, because there is no cross-process route from HWND to NSWindow.
Any fix has to solve *that* — which is a winemac/wineserver-level problem, not a DXMT-only one, and
it lines up exactly with the 2026-08-24 findings (a cross-process GDI `FillRect` into a foreign
window is lost on stock winemac too; the PK vendor plumbing that does work spans
winemac/win32u/wineserver).

**Forcing the guard is therefore not a workaround** — it converts a clean `E_FAIL` refusal into an
`abort()` in the GPU process. Window still black (108,343 B). Kept for diagnosis only.

## Cross-process, all the way down: wine's own branch is OFFSCREEN, and that is the real wall (2026-08-29)

Pulling the thread past the DXMT guard produced the complete chain. Four refusals stack, and
removing them one at a time gets a *Metal view* for a foreign HWND — but never a *pixel* in the
foreign window.

**1. `macdrv_get_cocoa_window` can't work cross-process, by construction.** It is
`get_win_data(hwnd)` (`window.c:223`), and `get_win_data` is a lookup in `win_datas`, a
**process-local `CFDictionary`** guarded by `win_data_mutex` (`window.c`). Another process's window
is simply not in this process's table. `release_win_data(NULL)` is a safe no-op, so the NULL path
is clean — it just never yields a window.

**2. But our engine has a second, better path that notpop's fork deliberately abandoned.** The
aquadran DXMT patch adds `my_get_win_data` (`macdrv_main.c:684`), which calls
**`macdrv_CreateClientSurface(hwnd, 0)` *first*** and hands DXMT a `client_cocoa_view`. notpop's
rewrite avoids `macdrv_win_data` because on **stock** Wine 11 `client_view` is only populated from
the GDI present path — true there, but our patched winemac creates the surface on demand. Two
different engines, two different correct answers.

**3. Wine already has a cross-process branch — and it names its own limit.** In
`macdrv_client_surface_acquire_metal_swapchain` (`window.c:1165`):

```c
if ((data = get_win_data(hwnd)))  { ... macdrv_create_view_swapchain(surface->cocoa_view); }
else {
    if (NtUserGetAncestor(hwnd, GA_ROOT) != hwnd) {
        FIXME("Cross-process child window Metal swapchains are not implemented\n");
        return FALSE;
    }
    surface->metal_swapchain = macdrv_create_offscreen_swapchain(hwnd, cgrect_from_rect(rect));
}
```

So for a foreign **root** window wine builds an **offscreen** swapchain
(`cocoa_window.m:4175`); only foreign **child** windows are unimplemented.

**4. The refusal that actually bites is in our own wrapper, and it is removable.**
`my_get_win_data` returns NULL whenever `get_win_data` does — before wine's offscreen branch can
ever run. Gated that on `DXMT_ALLOW_FOREIGN_HWND=1` (kept as
`scripts/winemac-foreign-hwnd.patch`) and rebuilt `winemac.so`. Measured with **stock DXMT v0.80**
(which has *no* cross-process guard at all — 0 occurrences of the string, unlike the newer fork):

- the foreign path fires **46 times** in one launch (`FOREIGN HWND 0x30164 …`),
- **no `Cross-process child window` FIXME** — so these are root windows and the offscreen branch ran,
- **zero `Failed to create metal view`** — DXMT genuinely obtains a Metal view for a foreign HWND,
- and the window is **still black, 108,343 B**.

**That is the answer — but see the NEXT section, which corrects the last step.** The wall is not
view creation and not swapchain bookkeeping; both can be made to succeed. It is that DXMT never
reaches wine's CAContext/CALayerHost route at all, so its offscreen content is never composited
into the window owned by the other process. ⚠ The compositing itself **does** exist and is used by
wine's Vulkan path — the gap is an ABI entry, not a missing implementation. Fixing
dxmt#141 therefore needs cross-process *compositing* (an `IOSurface`/`CAContext`-style shared
layer), which is exactly the shape of the vendor plumbing noted on 2026-08-24 as spanning
winemac / win32u / wineserver — and it is why no DXMT-only change can close it.

⚠ **Caveats on this cell, stated rather than buried.** It ran with `WINEDEBUG=err+all` (the cell
harness normally sets `-all`, which **suppresses wine's own `ERR()`** — the first attempt looked
like "nothing fired" purely because of that). The same run also logs
`err:vulkan:vulkan_init_once Failed to load libMoltenVK.dylib` ×5 and gnutls/kerberos load
failures; those are visible only because err logging was on and are **not** known to be caused by
the patch — do not attribute them without a matched control. The patch also **leaks** the client
surface when there is no `win_data` to own it. Diagnostic build only.

## The cross-process compositing already EXISTS — DXMT just can't reach it (2026-08-29)

The previous section concluded the wall was "no cross-process compositing." **That was wrong, and
the correction is the most actionable thing in this whole thread.** The machinery is written,
shipping, and in use — DXMT is simply not given access to it.

**What exists in our patched winemac, fully wired:**

| piece | location | what it does |
|---|---|---|
| `CAContextSwapChain` | `cocoa_window.m` | offscreen `CAMetalLayer`, exported via `CAContext contextWithCGSConnection:` → `contextId` |
| `macdrv_create_offscreen_swapchain` | `cocoa_window.m:4175` | returns that CAContext swapchain |
| `macdrv_create_remote_layer(hwnd, id)` | `window.c:1583` | `NtUserPostMessage(hwnd, WM_MACDRV_CREATE_REMOTE_LAYER, 0, id)` — **crosses the process boundary** |
| `WM_MACDRV_CREATE_REMOTE_LAYER` handler | `window.c:1564` | owner calls `macdrv_window_create_ca_layer_host_view(cocoa_window, id)` |
| `CALayerHost` + `_caLayerHosts` | `cocoa_window.m:62, 397` | owner hosts the remote layer in its own `WineContentView` |

The source comment states the design outright: *"Export the CAMetalLayer from the rendering
process, then have the target HWND's owner host it using CALayerHost."* That is textbook macOS
cross-process compositing, and `macdrv_create_remote_layer` is called at the end of
`CAContextSwapChain initWithHwnd:bounds:` — the loop is closed.

**So why is Steam still black? Because the only caller is Vulkan.**

```
vulkan.c:50:  if (!macdrv_client_surface_acquire_metal_swapchain(surface)) return VK_ERROR_INCOMPATIBLE_DRIVER;
```

That is the **sole** call site. And the DXMT-facing ABI cannot reach it —
`struct macdrv_functions_t` (`macdrv_main.c:644`, `C_ASSERT(sizeof == 80)`, ten pointers) exports
`get_win_data` · `release_win_data` · `macdrv_get_cocoa_window` · `create_metal_device` ·
`release_metal_device` · `view_create_metal_view` · `view_get_metal_layer` ·
`view_release_metal_view` · `on_main_thread` — and **not**
`macdrv_client_surface_acquire_metal_swapchain`, nor `macdrv_swapchain_get_layer`.

So DXMT's only route is `macdrv_view_create_metal_view` on the client surface's **local, hidden**
view (`macdrv_CreateClientSurface` does `macdrv_set_view_hidden(..., TRUE)`). It renders correctly
into a layer that is never hosted anywhere. **That is exactly what we measured**: a Metal view
obtained for a foreign HWND, no errors, and a black window.

**The missing last mile is therefore an ABI entry, not an implementation.** A fix candidate:

1. add `macdrv_client_surface_acquire_metal_swapchain` and `macdrv_swapchain_get_layer` to
   `macdrv_functions_t` (⚠ this breaks the `C_ASSERT(sizeof == 80)` contract — every DXMT binary
   compiled against the old layout must be rebuilt; we now have both source trees and working
   builds for exactly that),
2. in DXMT's `CreateSwapChain`, when `GetWindowThreadProcessId(hWnd) != GetCurrentProcessId()`, take
   that path instead of `view_create_metal_view`,
3. present into the returned `CAMetalLayer`.

Wine's Vulkan path is the existence proof that the route works. ⚠ **Untested prediction, stated as
such:** a Vulkan app should already be able to present into a foreign HWND on this engine. Worth
measuring before relying on any of the above.

## 🎯 FINAL: the blocker is cross-process CHILD windows, and it is a one-line FIXME in wine (2026-08-29)

Wiring DXMT to wine's existing CAContext route located the bottom of the whole thread. Four
refusals, each removed in turn, each handing off to the next:

| # | refusal | where | removed by |
|---|---|---|---|
| 1 | `cross-process swapchain not supported yet` (returns before trying) | DXMT `d3d11_swapchain.cpp:1102` | `scripts/dxmt-force-crossprocess.patch` |
| 2 | `macdrv_get_cocoa_window` NULL — `win_datas` is process-local | winemac `window.c:223` | new ABI entry (below) |
| 3 | `my_get_win_data` refuses a foreign HWND | winemac `macdrv_main.c` | `scripts/winemac-foreign-hwnd.patch` |
| 4 | **`Cross-process child window Metal swapchains are not implemented`** | winemac `window.c:1176` | **nothing — this is the wall** |

**The new ABI entry works.** `macdrv_functions_t` gained
`dxmt_acquire_remote_layer(HWND, macdrv_view*)` (sizeof 80 → **88**; both trees rebuilt in lockstep),
DXMT's `_CreateMetalViewFromHWND` calls it when `macdrv_get_cocoa_window` returns NULL, and the
measurement shows the route is live: **guard forced 6×, REMOTE path taken 6×** in one launch.

**And then wine says no, precisely:**

```
fixme:macdrv:macdrv_client_surface_acquire_metal_swapchain
    Cross-process child window Metal swapchains are not implemented
```

**6 occurrences, matching the 6 attempts.** The branch is
`if (NtUserGetAncestor(hwnd, GA_ROOT) != hwnd) return FALSE;` — wine's cross-process CAContext route
is implemented **only for root windows**, and Steam's CEF presents into a **child** HWND.

**So the entire investigation reduces to one sentence:** *Steam's CEF renders to a cross-process
**child** window, and winemac implements cross-process Metal swapchains only for **root** windows.*

Everything else now follows without hand-waving — games work (same-process); notpop's fork fixes the
same-process view path (its evidence is a game); the vanilla-wined3d split sidesteps DXMT entirely
(and is FL-9_3-capped here); and no DXMT-side change can help, because the unimplemented case is in
wine's macdrv.

⚠ **Note the FIXME is invisible under the harness's usual logging.** `WINEDEBUG=-all` hides it, and
even `err+all` hides it — FIXME is its own class. It needs `+macdrv`. Two earlier cells reported
"no Cross-process child FIXME: 0" purely for that reason and were **wrong**; the correct reading
required `WINEDEBUG=err+all,+macdrv`. Do not conclude "branch not taken" from a channel you have
not enabled.

**Fix shape, for anyone picking this up:** implement the child-window case in
`macdrv_client_surface_acquire_metal_swapchain` — the root-window path already builds a
`CAContextSwapChain` and posts `WM_MACDRV_CREATE_REMOTE_LAYER` to the owner, which hosts it via
`CALayerHost`. A child window additionally needs its rect mapped into the owner's coordinate space
and the hosted layer positioned/clipped there. **That is a wine patch, not a DXMT patch.**

## Cross-process CHILD windows: implemented, builds, TEST BLOCKED ON A STEAM LOGIN (2026-08-29)

The child-window case named by the FIXME is now **implemented and building**, but it has **not yet
been validated** — say so plainly rather than implying otherwise.

**The implementation** (`macdrv_client_surface_acquire_metal_swapchain`, `window.c`): replace the
`FIXME`/`return FALSE` with — resolve `root = NtUserGetAncestor(hwnd, GA_ROOT)`, take the child's
client rect, and build the offscreen `CAContextSwapChain` **against the root** rather than the
child. That matters because `macdrv_create_offscreen_swapchain(hwnd, …)` internally posts
`WM_MACDRV_CREATE_REMOTE_LAYER` to `hwnd`, and the handler needs `data->cocoa_window` — which a
**child HWND does not have**. The root is the window that both owns an `NSWindow` and lives in the
other process. Geometry is deliberately not mapped yet: the hosted `CALayerHost` fills the root's
content view, which is approximately right when the child covers the client area (CEF's main widget
does). Builds clean alongside the `dxmt_acquire_remote_layer` ABI entry.

**Why it is unvalidated: the test clone came up at `Sign in to Steam` (700×440).** With no logged-in
client there is no store/library, so no cross-process child HWNDs are created — `cross-process
swapchain FORCED` counted **0**, versus 6 in the earlier valid run. The cell measured a login window
and nothing else. **Entering Steam credentials is the user's action, not something to automate.**

⚠ **Self-inflicted, and worth knowing before repeating this:** several test clones were launched in
sequence against the same Steam account, and per § "Same-account Steam sessions SWAP" that shuffles
the single online session. The daily wrapper was re-verified afterwards and is **fine** —
`winemac.so` 0 public text symbols, `d3d11.dll` 5,304,320 B (stock v0.80), `loginusers.vdf` intact —
but a *clone* can land on a login prompt. **Warm a clone to a logged-in client before treating any
Steam-UI cell on it as valid**, and prefer reusing one clone over creating several.

⚠ **Timing, again:** a fresh clone's Steam can take **>200 s** to produce any stdout. Two cells here
reported "0 markers" purely because the capture window closed first; a later read of the same file
showed 1,342 lines. `--wait 260` was sufficient in the run that worked. **Never read a marker count
from a cell whose `stdout.txt` is empty.**

**Resume:** `CS2child-test.app` is kept, with the full stack installed (patched `winemac.so` +
forked DXMT + `dxmt_acquire_remote_layer` + child path). Log into Steam in it once, then re-run
`WINEDEBUG=err+all,+macdrv DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN=1 … --wait 260` and check for
`cross-process CHILD hwnd … -> hosting remote layer on root`.

## ✅ IT RENDERS — the cross-process CHILD patch fixes Steam's black client (2026-08-29)

**The wine patch works.** Steam's storefront composites into the window for the first time in this
investigation, in the *stock* configuration that has been uniformly black throughout.

| | before | with the patch |
|---|---|---|
| window capture | **108,343 B** (uniform black) | **2,346,395 B — renders** |
| `cross-process CHILD hwnd → root` | n/a | **44** firings |
| `REMOTE path` layer / view | `layer=0x0 view=0x0` | **`layer=0x7f8008f09f10 view=0x7f8009609aa0`** |
| `acquire_metal_swapchain FAILED` | 6 | **0** |
| `Cross-process child window Metal…` FIXME | 6 | **0** |
| `Failed to create metal view` | 6 | **0** |

⚠ **Configuration, verified rather than assumed — this is the load-bearing detail.** No webhelper
shim (`steamwebhelper_real.exe` absent), **no injected switches at all** (empty cmdline grep), and
**out-of-process GPU** (1 `--type=gpu-process` child in this prefix). That is precisely the stock
setup which measured 108,343 B black on every previous run. So the fix is not a flag, not the shim,
and not the vanilla-wined3d split — it is the winemac child-window patch.

Screenshot: `docs/images/steam-crossprocess-child-renders.png`.

**What is fixed:** artwork, capsules, thumbnails, gradients, nav chrome, the search field — the
store lays out and composites correctly.

**What is NOT fixed: glyphs.** The nav bar is still six bare dropdown carets, capsules have no
titles or prices, and the only readable text is baked into promo art — the same signature documented
since 2026-08-24. ⚠ **And that is a genuinely new wrinkle worth flagging rather than glossing:** the
glyph loss was previously attributed to *in-process GPU*, but this run is **out-of-process**. So
either the glyph defect is broader than the in-process path, or the two have a common cause. Do not
restate the old "in-process GPU kills glyphs" framing as if it still fully explains this.

**Also not yet done: geometry.** The hosted `CALayerHost` fills the root's content view rather than
being positioned and clipped to the child's rect, exactly as the patch header says. Visible as a
black band at the bottom of the capture and a slight offset. That is the next piece of work, and it
is cosmetic relative to what just changed.

⚠ **Not claimed:** the `cef_log.txt` crash counter reads 12, but that file accumulates across the
several launches this clone has had — it is **not** a per-launch figure and no claim is made that
the patch eliminates GPU-process crashes.

**The three patches that together produce this** (all diagnostic-grade, all kept):
`scripts/dxmt-force-crossprocess.patch` (DXMT's up-front refusal) ·
`scripts/winemac-crossprocess-child.patch` (the actual fix — build the CAContext swapchain against
the ROOT for a foreign child) · plus the `dxmt_acquire_remote_layer` ABI entry in
`macdrv_functions_t` (sizeof 80 → 88). `scripts/winemac-foreign-hwnd.patch` is superseded by the
ABI route and is not needed for this result.

## Glyph chase on the new rendering baseline — three hypotheses tested, cause narrowed (2026-08-29)

With the client finally rendering, the glyph defect was re-attacked on a baseline that actually
shows pixels. **Not fixed** — but the cause is now narrowed to something structural rather than
mysterious, and two plausible explanations are dead.

**1. DirectComposition — ELIMINATED.** Chromium calls `DCompositionCreateDevice3`, which wine stubs
(`fixme:dcomp:`), so "text goes into a DComp visual that never composites" was a good hypothesis.
`--disable-direct-composition` injected via the shim (confirmed on the real webhelper cmdline):
window still **renders, still zero glyphs**. Capture went 2,429,957 → 2,569,047 B — ⚠ and that
increase was **just a busier promo image**, not text. **Capture size is not a glyph proxy; open the
image.** Note this flag had only ever been used here bundled with three others in
`scripts/whwrapper.c`, never isolated.

**2. Stale stacked layers — DISPROVED, and the leak turns out to be load-bearing.** The main Steam
window acquires **7** remote layers in a session (16 distinct child HWNDs → 15 roots overall, so
~1 per window, but the main one retries). Retiring the previous surface per HWND on each acquire —
one hosted `CALayerHost` per window, which also fixes the deliberate leak — sent the window
**straight back to black (108,343 B)**, with 7 retirements logged. **DXMT keeps rendering into the
layer handed to it by an earlier acquire**, so releasing on the next acquire destroys the live one.
Lifetime has to be driven by DXMT releasing its swapchain, not by the next acquire. Reverted, with
the reason recorded in the source.

**3. Z-order — the informative one. Only the TOPMOST hosted layer is ever visible.**
`addCALayerHostViewWithContextId:` does `host.frame = self.layer.bounds` with
`kCALayerWidthSizable|kCALayerHeightSizable` and `[self.layer addSublayer:host]` — so **every host
is stretched over the entire content view**, and newest wins. Probe (`DXMT_HOST_LAYER_BOTTOM=1`,
`insertSublayer:atIndex:0`): **black, 108,343 B**, versus ~2.4 MB rendered with the default. So
whichever layer is on top is the only one you see, and everything under it is hidden.

**Where that leaves the glyphs — ⚠ SUPERSEDED by the next section, which implements the geometry
mapping and finds text still absent.** The leading explanation *at this point* was **occlusion, not
rasterisation**:
several full-bounds layers stacked on one window, only the top one visible, and any content drawn
into the others — plausibly including text-bearing widgets — buried. It fits the earlier
observation that PK renders Steam text *until* the shim is added, and it fits art-without-text.
⚠ **It is not proven.** The alternative — that glyphs are genuinely never rasterised, which is what
the 2026-08-24 in-process work concluded — is not excluded by anything measured here.

**Next step, and it is the piece the child patch already flagged as missing: map the geometry.**
Each child's hosted layer must be positioned and clipped to that child's rect in the root's
coordinate space instead of filling the content view, so the layers stop occluding one another.
That needs the child's rect carried to the owning process (the current
`WM_MACDRV_CREATE_REMOTE_LAYER` only carries a `contextId` in `lParam`; the child HWND could go in
`wParam` and let the receiver compute the rect). Until that exists, "no glyphs" and "layers occlude
each other" cannot be told apart.

## An unbounded `until` waiter outlived its target by 6.5 hours (2026-08-29)

`until grep -q <pattern> <file>; do sleep 10; done` was used to wait on a backgrounded probe. The
probe was killed ~15 minutes later; the loop kept polling a file that would never change again and
was still running **6 h 37 m** later, found only because the user noticed it in the task list.

Two lessons, and the second is the one that actually bit:

1. **Bound the wait on the TARGET, not just the condition.** A waiter whose condition can become
   permanently unreachable needs a second exit: check the producer is still alive and break if it
   is not — `until <cond>; do pgrep -f <producer> >/dev/null || break; sleep 10; done` — or cap the
   iterations. Later probes in the same session did this; the first did not.
2. **"Is anything still running?" must include your OWN waiters.** The check run here grepped for
   `steam.exe|wine64|gmake|meson|caffeinate` — the things deliberately *started* — and reported
   "nothing running" while a monitoring loop from the same session was still going. **A waiter is
   exactly as running as the thing it waits for.** Sweep for `until|sleep` loops and background
   task IDs too, and prefer `TaskStop` on the task id over hunting the process.

Cost was negligible (a sleeping shell, no interference with any measurement) — recorded because it
is the same family as the auto-armed background task that blocked a macOS update, per the global
`CLAUDE.md` note, not because this instance did harm.

## Geometry mapping lands — and it ELIMINATES occlusion as the glyph cause (2026-08-29)

The missing piece of the child patch is implemented: each cross-process child's hosted layer is now
positioned and clipped to its own rect in the root's coordinate space instead of being stretched
over the whole content view.

**Wiring:** `WM_MACDRV_CREATE_REMOTE_LAYER` now carries the **child HWND in `wParam`** (0 for a root)
alongside the `contextId` in `lParam`; the owning process computes
`NtUserGetWindowRect(child) − NtUserGetWindowRect(root)` and passes a `CGRect` down to
`addCALayerHostViewWithContextId:frame:`, which sets `host.frame` + `masksToBounds` instead of
`bounds` + autoresizing. `WineContentView` is `isFlipped = YES`, so Windows' top-left origin maps
straight through with no Y flip. Env-gated on `DXMT_MAP_CHILD_GEOMETRY=1`.

**Result: visibly better composition.** Steam's window chrome now appears — broadcast /
notifications / avatar, minimize / maximize / close, back / forward, refresh and lock icons — all
of which are **separate child widgets that were previously buried** under the full-bounds main
layer. The black band along the bottom is gone. Capture 2,447,073 B.
Screenshot: `docs/images/steam-crossprocess-geometry-mapped.png`.

**So the occlusion hypothesis was REAL — and it is NOT the glyph cause.** Several widgets that were
invisible now render correctly, which is exactly what the hypothesis predicted. And **every one of
them shows icons and artwork with no text at all.** Compositing many more layers correctly did not
bring back a single glyph.

**That flips the conclusion of the previous section.** The leading explanation is no longer
occlusion; it is that **glyphs are genuinely never rasterised into the content**, which is what the
2026-08-24 in-process investigation concluded before any of this. The text defect is therefore
**independent of the presentation path** — it survives in-process GPU, out-of-process GPU, the
CAContext remote-layer route, and now correct per-child geometry. Three presentation architectures,
same missing text.

**Frames observed** (`child → root = x,y w×h`): the main window maps `0,0 1512x949`; smaller widgets
`0,0 36x235`, `0,0 2x1`. ⚠ **Every offset measured was `0,0`**, and many rects are `0x0` at
swapchain-creation time (the widget is not laid out yet) — those fall back to full bounds, so the
mapping is not yet exercised for them. A proper implementation should re-position the host on
`WM_MACDRV_WINDOWPOSCHANGED` rather than only at creation; without that, a widget that moves or
resizes after its layer is hosted keeps a stale frame.

## Glyph-atlas texture path ELIMINATED — `scripts/r8test.c` (2026-08-29)

Skia uploads glyph masks as single-channel textures and samples them; if that silently yielded
zero, text would vanish while artwork drew. **It does not.** `scripts/r8test.c` is a headless
D3D11 probe — no window, no Steam, no compositor — that uploads a known-white texture, samples it
in a pixel shader, copies the render target to a staging texture and **reads the pixel values back
as numbers**. On the daily DXMT v0.80 engine, feature level 11_0:

| path | R8G8B8A8 (control) | R8_UNORM | A8_UNORM |
|---|---|---|---|
| immutable initial data | **255** | **255** | **255** |
| `UpdateSubresource`, strip at a time (how an atlas grows) | — | **255** | **255** |
| `Map(WRITE_DISCARD)` on a DYNAMIC texture | — | **255** | — |

⚠ **The first run reported `A8_UNORM` BLACK, and that was MY BUG, not DXMT's.** The shader read
`.r`, but `A8_UNORM` legitimately samples as `(0,0,0,A)` — reading `.r` returns 0 on correct
hardware too. Caught before it was written up as a finding; the shader now takes `max(t.r, t.a)`.
**A single-channel format test that reads the wrong channel manufactures the exact bug it is looking
for.**

**So the glyph defect is not the texture path.** Creation, both single-channel formats, both
incremental upload routes, and sampling all behave correctly.

**What is now eliminated, cumulatively:** font enumeration (924 GDI / 204 DirectWrite families,
identical to the PK build that renders text — 2026-08-24) · texture format, upload and sampling
(this section) · presentation architecture (in-process GPU, out-of-process, CAContext remote layer)
· occlusion (per-child geometry mapped; more widgets appeared, still no text) · DirectComposition ·
`--use-angle=swiftshader`, `--disable-lcd-text`, `--disable-direct-write`, `--disable-gpu-*` (2026-08-24).

**The next probe, and it is a small one:** does **DirectWrite actually rasterise** on this stack?
Fonts *enumerate*, and `dwrite.so` carries all 56 `pFT_*` pointers — but nothing here has ever
checked that a glyph run produces non-empty coverage. `IDWriteFactory` →
`IDWriteGlyphRunAnalysis` → `CreateAlphaTexture` and sum the bytes: non-zero means rasterisation
works and the fault is further up in Skia; all-zero means the text never exists as pixels in the
first place, which would explain every observation in this whole thread at once.

## Text RASTERISATION eliminated — byte-identical to the build that renders text (2026-08-29)

`scripts/dwritetest.c` asks DirectWrite for the alpha texture of a real glyph run ("ABC", Arial,
32 px) and sums the bytes. Run on **both** engines on the same machine:

| | families | ALIASED_1x1 | CLEARTYPE_3x1 (natural) | CLEARTYPE_3x1 (gdi) |
|---|---|---|---|---|
| our stock 11.16 + DXMT (**no** Steam text) | 204 | 71×23, nonzero 545/1633, max 255, **sum 138975** | 315/4899, **sum 80325** | 315/4899, **sum 80325** |
| PK 11.0 vendor build (**renders** Steam text) | 204 | 71×23, nonzero 545/1633, max 255, **sum 138975** | 315/4899, **sum 80325** | 315/4899, **sum 80325** |

**Byte-identical.** Same bounds, same coverage, same sums, same font family count.

Two things fall out:

1. **Glyph rasterisation is not the defect.** DirectWrite produces real coverage on our engine —
   545 nonzero bytes at max 255 for three glyphs. The text exists as pixels before anything
   graphical happens to it.
2. ⚠ **The ClearType sparsity is normal, not a symptom.** 315/4899 nonzero looked suspiciously
   thin next to the aliased 545/1633 and was briefly a lead — until the *working* engine produced
   exactly the same number. **A ratio that looks wrong is not evidence without a reference.** The
   PK build is the reference this project has for "text works", and it should be run against any
   future text hypothesis before that hypothesis is believed.

**This is the strongest control available on this machine:** same hardware, same fonts, same
DirectWrite output down to the byte — and one engine shows Steam's text while the other does not.
So the difference lives entirely in what Chromium does with those glyphs afterwards, not in
producing them.

**Cumulative eliminations for the missing text — the list is now long and the survivors are few:**
font enumeration · **glyph rasterisation (this section)** · single-channel texture format, upload
(immutable, `UpdateSubresource`, `Map`/DISCARD) and sampling · presentation architecture
(in-process GPU, out-of-process, CAContext remote layer) · occlusion (per-child geometry) ·
DirectComposition · the 2026-08-24 flag matrix (`--use-angle=swiftshader`, `--disable-lcd-text`,
`--disable-direct-write`, `--disable-gpu-rasterization`, `--disable-gpu-compositing`, …).

**What survives:** something in how Chromium/Skia *uploads or composites* the glyph coverage it
already has — a path the PK vendor plumbing satisfies and ours does not. That is now a
Chromium/ANGLE-level question rather than a DXMT one, and the next probe should look at what ANGLE
does differently between the two engines rather than at anything font-shaped.

## The glyph defect localised: Chromium has NO working GL at all on this engine (2026-08-29)

Comparing `cef_log.txt` between our engine and the PK build that renders text gives the cleanest
signal in the whole text investigation.

| | our stock 11.16 + DXMT (**no text**) | PK 11.0 vendor build (**text works**) |
|---|---|---|
| `Initialization of all EGL display types failed` | **12** | **0** |
| `GLDisplayEGL::Initialize failed` | **12** | **0** |
| `eglInitialize SwANGLE failed` | **12** | **0** |
| GL/ANGLE errors of any kind | many | **none** (only network / ffmpeg / bad_message) |

**On our engine ANGLE never initialises at all.** The sequence is unambiguous:

```
WARNING: ANGLE Requires a minimum Vulkan instance version of 1.1
ERROR:   Internal Vulkan error (-9): The requested version of Vulkan is not supported by the driver
ERROR:   eglInitialize SwANGLE failed with error EGL_NOT_INITIALIZED
ERROR:   Initialization of all EGL display types failed.
ERROR:   GLDisplayEGL::Initialize failed.
```

⚠ **And it only ever tries Vulkan.** Display-type mentions in the log: `Vulkan` 84, `SwANGLE` 12,
**`D3D11` zero**. On this CEF build ANGLE's path is SwANGLE (software ANGLE over Vulkan), and it
needs a Vulkan **1.1** instance it cannot get — the same processes log
`err:vulkan:vulkan_init_once Failed to load libMoltenVK.dylib` **6×** per run.

**So Chromium is running with no GL whatsoever, on its software path** — which evidently blits
artwork fine and produces no text. ⚠ **SUPERSEDED 2026-08-30:** mikey92 has no GL either (CPU
raster, zero GPU process) and *does* get text, so "no GL" does not by itself explain the glyphs.
See § "mikey92's CPU-raster config does NOT reproduce here". That is the most economical explanation of every text
observation in this thread, and it predicts the fix: **get ANGLE initialised and the glyphs should
follow.**

**Two things tried against it, both no change:**
- **MoltenVK placement.** PK carries `libMoltenVK.dylib` in `wine/lib/` where ours only had it in
  `Contents/Frameworks/`, and `winevulkan` dlopens it by name. Copied it into `wine/lib/`
  (identical binary — both 8,096,560 B, `lipo -archs` = `x86_64`, so not an arch mismatch):
  **still 6 load failures**, still 12 EGL failures. Placement is not the problem.
- **`--use-angle=d3d11`** on the rendering baseline: renders (2,310,029 B), **still zero glyphs**.
  Forcing the backend does not help when the display never initialises.

**Next thread, and it is now specific rather than font-shaped:** why does
`libMoltenVK.dylib` fail to load *inside Steam's spawned child processes* when it loads fine for a
directly-launched wine program (the `dxgiprobe` runs print full MoltenVK banners)? That smells like
`DYLD_FALLBACK_LIBRARY_PATH` not surviving the steam.exe → webhelper spawn, and PK's wrapper doing
something different about it. Fix that, and ANGLE should come up.

⚠ **Do not read the cef_log counters as per-run** — that file accumulates across launches on a
prefix. The 12s above are consistent across runs but were not isolated per launch; the MoltenVK
count (6) is from the run's own stdout and is per-run.

## mikey92's CPU-raster config does NOT reproduce here — and the flag attribution is disproved (2026-08-30)

mikey92 measured their own stack ([#141](https://github.com/3Shain/dxmt/issues/141)) and the result
is important: **their Steam client is carried by CPU raster, not D3D11.** Their `dxgiprobe` matches
ours exactly — vanilla PE gives `"NVIDIA GeForce 6800"`, `0x887A0004`, **FL 9_3**; the DXMT fork
gives `"Apple M4 Pro"`, `S_OK`, **FL 11_1** — and a `+loaddll` session shows **`d3d11.dll` loaded
zero times** across steam.exe and both webhelpers. With `--disable-gpu` Chromium skips the GPU
process and rasterises through Skia on the CPU; the split's only job there is to keep DXMT's guard
away from the steam processes, which otherwise restart-loop.

**They attributed our "no window, 174 % spin" row to a missing `-cef-single-process` on steam.exe**
(without it the browser forks a utility child for the network service → `net_error -100/-107`
cascade). **Tested. That is not what happens here.**

Ran their exact line — `steam.exe -no-cef-sandbox -cef-single-process -noverifyfiles`, shim
prepending `--disable-gpu --single-process` — on **stock DXMT v0.80** (verified guard-free:
0 occurrences of the `cross-process swapchain` string, so no restart loop) with a **stock**
`winemac.so` (0 public text symbols) and none of our patches active:

| | ours | mikey92 |
|---|---|---|
| flags on the real webhelper | `--disable-gpu --single-process` ✅ | same |
| `net_error` cascade | **0** | (their predicted cause) |
| `single process` notices | 6 | 58 |
| **`gpu_process_host` lines** | **36** | **0** |
| `gl_factory_win.cc` errors | **6,834,935** | — |
| window | **none**, after 10+ min | renders, with text |

**So the missing flag was not our cause.** With it supplied and verified, there is no net_error
cascade — and Chromium here *still* spins up gpu-process-host activity (36 lines vs their 0), never
reaches single-process cleanly (6 notices vs 58), and falls into the `gl_factory_win.cc(63)`
NOTREACHED loop at ~6.8 M occurrences with `wineserver` burning 53 % CPU.

**What that leaves as the real difference:** wine **11.0 vs 11.16**, macOS **26.5 vs 26.6.2**,
M4 Pro vs M3 Max. Not flag plumbing, and not the D3D path — both of us agree D3D11 is never used.

⚠ **And it kills the theory from the previous section.** "No GL → software path → no text" is
**wrong**: mikey92 has no GL either (CPU raster, zero GPU process) and gets **text**. So an absent
ANGLE does not by itself explain missing glyphs. The glyph question is reopened, and CPU raster is
now a *working* reference configuration that this machine cannot yet enter.

⚠ **Unverified claim, flagged rather than repeated:** that the CALayerHost route is 11.11+ only
(commit `1a63b0d7`, 2026-05-20, after the 11.10 tag). Our attempt to confirm it by `strings` on the
PK 11.0 `winemac.so` was **void** — the sanity control failed, `macdrv` itself counts 0 because
**PK's binaries are stripped** (already documented in § "The webhelper shim renders everything
EXCEPT text"). It is plausible and matters for the thread, but check it against wine git, not
against a stripped binary.

## ✅ CPU raster renders Steam WITH TEXT on an 11.0-lineage engine — the glyph story resolves (2026-08-30)

mikey92's configuration was run on a **clone of the PK 11.0 wrapper** (`cp -Rc`; the real store
wrapper untouched): `steam.exe -no-cef-sandbox -cef-single-process -noverifyfiles`, shim prepending
`--disable-gpu --single-process`.

**Result: a complete, fully-textual Steam client.** 1,897,587 B capture with the `Steam / View /
Friends / Games / Help` menu bar, `STORE / LIBRARY / COMMUNITY` nav, the full `Browse /
Recommendations / Categories / Hardware / Ways to Play / Special Sections` row, `Search the store`,
`Wishlist 7`, `Featured & Recommended`, game titles, `Overwhelmingly Positive (19,089 Reviews)`,
`Top Seller`, `$19.99`, `Discounts & Events`, `Add a Game`, `Manage Downloads`, `Friends & Chat`.
⚠ **Screenshot deliberately NOT committed** — the account name is visible and this repo is meant to
be publishable (see CLAUDE.md § Personal info). Described here instead.

**⚠ This CORRECTS a standing claim in § "The webhelper shim renders everything EXCEPT text".** That
section says PK *"loses text the same way the moment the shim is added"*. That is true **only for
`--in-process-gpu`**, which is the shim's compiled default. With the shim installed and
`--disable-gpu --single-process` injected instead, **PK keeps all its text.** The shim is not the
text killer; **in-process GPU is.**

**So the whole glyph picture finally resolves into three consistent rows:**

| GPU mode | art | text | notes |
|---|---|---|---|
| in-process GPU (`--in-process-gpu` / `--single-process` alone) | renders | **none** | both engines — the long-standing glyph bug |
| **no GPU at all** (`--disable-gpu --single-process`, CPU raster) | renders | **YES** | PK 11.0-lineage — *this run* |
| out-of-process GPU | black (11.16) / fine (PK) | — | the cross-process swapchain thread |

**And it relocates our remaining defect precisely.** CPU raster is a *known-good, text-complete*
configuration. Our 11.16 engine cannot enter it — the identical flag set there produces **no window
at all**, with `gl_factory_win.cc(63)` NOTREACHED at ~6.8 M occurrences, 36 `gpu_process_host` lines
where mikey92 gets 0, and 6 `single process` notices where they get 58. So the target is no longer
"why are glyphs missing" but **"why can wine 11.16 not run Chromium's GPU-less single-process
path when 11.0 can"** — a regression between the two, on the GL-probe path Chromium takes before
deciding it needs no GPU.

**Verified while checking mikey92's other claim** (against wine git, not a stripped binary):
`macdrv_client_surface_acquire_metal_swapchain` / `WM_MACDRV_CREATE_REMOTE_LAYER` are **absent in
`wine-11.0` and `wine-11.10`, present in `wine-11.11`** (1 and 3 occurrences). Their "11.11+ only"
statement is **correct**, which means the cross-process CHILD patch cannot apply to the many
black-window reports on `wine-stable` 11.0 without moving engines.

## No wine-version bisect is warranted — and mikey92's setup relocates the variable to macOS (2026-08-30)

Asked "was it 11.4 or 11.11?", the honest answer is **neither: there is no version boundary between
11.0 and 11.16 on this machine.** A controlled sweep on 2026-08-24 already measured it —
§ "Embedded Chromium NEVER rendered on stock Wine here":

| cell | result |
|---|---|
| **stock 11.0 / 11.15 / 11.16**, identical configure, fresh-prefix gate | **all BLANK, byte-identical captures** |
| PK 11.0 (vendor), same gate | RENDERED, repeatedly |

**Stock 11.0 fails here exactly as stock 11.16 does.** So bisecting 11.0 → 11.16 would land on no
commit; the axis was never the version, it is **stock vs the PK vendor patchset** (a Gcenx build
from a private tree carrying CrossOver-lineage `CX_LIBVULKAN` code in win32u, the msync patchset,
and Proton-lineage writecopy). ⚠ Individual module transplants were already tried and failed —
stock 11.0 + PK's `win32u`/`winemac`/`user32`/`gdi32` was still blank, and PK core transplants
crash, because the vendor modules interlock.

**What mikey92's report changes, and it is the useful part.** They run **stock Homebrew
`wine-stable` 11.0** — not a vendor build — and Steam renders *with text* under CPU raster. Ours is
a stock build too, and fails. Same engine lineage, opposite outcome. **So the remaining variable is
not wine at all: it is macOS 26.5 (theirs) vs 26.6.2 (ours)**, or M4 Pro vs M3 Max.
⚠ **WRONG — SUPERSEDED 2026-08-30.** wine-stable 11.0 was installed and runs their config on THIS
machine, macOS 26.6.2, rendering Steam with full text. The OS is exonerated; the variable is the
engine. See § "CORRECTION: macOS is NOT the variable".

That also fits the one error we cannot shake: `ANGLE Requires a minimum Vulkan instance version of
1.1` → `Internal Vulkan error (-9)`. Per the 08-24 A/B that warning is **present on stock 11.16 and
absent on PK 11.0** — it tracks the Vulkan stack, and PK's differentiator is precisely
CrossOver-lineage Vulkan code.

⚠ **Also eliminated today:** forcing Chromium's own bundled software Vulkan with
`WINEDLLOVERRIDES="vulkan-1=n,b"` (its `vk_swiftshader.dll` 5,307,032 B + `vk_swiftshader_icd.json`
are both present in the CEF directory) under the CPU-raster flags — **no change**: 10 EGL
all-failed, 10 "minimum Vulkan instance" warnings, 6,222,856 `gl_factory_win` errors, no window.
The override does not divert ANGLE off wine's Vulkan.

**The one cheap experiment that would settle it:** install Homebrew `wine-stable` — mikey92's exact
engine — on this machine and run the CPU-raster config. Stock-vs-stock, same client, same flags,
only the OS and hardware differing. If it fails here, macOS 26.6.2 is confirmed as the variable and
wine is fully exonerated; if it works, our own 11.16 build configuration is implicated rather than
the version.

## ⚠ CORRECTION: macOS is NOT the variable — wine-stable 11.0 renders Steam WITH TEXT here (2026-08-30)

The previous section concluded *"the remaining variable is not wine at all: it is macOS 26.5 vs
26.6.2"*. **That is wrong, and this supersedes it.** Homebrew `wine-stable` (**wine-11.0**, the exact
engine mikey92 runs) was installed and given their exact configuration on **this** machine —
macOS 26.6.2, M3 Max:

```
steam.exe -no-cef-sandbox -cef-single-process -noverifyfiles
shim injecting --disable-gpu --single-process
```

**Result: a complete, fully-textual Steam client. 665,949 B.** Menu bar (`Steam / View / Friends /
Games / Help`), `STORE / LIBRARY / COMMUNITY`, the `Browse / Recommendations / Categories / More`
row, `Search the store`, `Wishlist 7`, `Featured & Recommended`, game title, `Overwhelmingly
Positive (200,124 Reviews)`, `Recommended because you played games tagged with`, the tag chips,
`$19.99`, `Add a Game`, `Manage Downloads`, `Friends & Chat`.
⚠ **Screenshot NOT committed** — the account name is visible (CLAUDE.md § Personal info).

**Same machine, same OS, same Steam install, same flags — the ONLY difference is the engine:**

| engine | result |
|---|---|
| our self-built stock **11.16** + DXMT | **no window at all**; `gl_factory_win.cc` NOTREACHED ~6.8 M, 36 `gpu_process_host` lines, 6 single-process notices |
| Homebrew **wine-stable 11.0** | **renders, with full text** |

**So the OS is exonerated and a bisect IS warranted after all** — for *this specific configuration*.
That does not contradict the 2026-08-24 three-version sweep, which is why the earlier reasoning went
wrong: that sweep found stock 11.0 / 11.15 / 11.16 all blank **under DEFAULT flags** (out-of-process
CEF). It says nothing about the CPU-raster path, which nobody had run on 11.0 here until now.
**Two different configurations, two different answers — do not generalise one sweep across both.**

**Two candidates, both testable:** (a) a wine regression between 11.0 and 11.16 on the GL-probe path
Chromium takes before deciding it needs no GPU; or (b) our own build configuration differing from
WineHQ's stable build (we configure with a specific `--without-*` set). (b) is the cheaper to check
first — build 11.0 from source with our flags and see which side it lands on.

**Practical consequence, and it is a real one:** there is now a WORKING Steam client path on this
machine that needs no two-wrapper split — `wine-stable` 11.0 + the padded webhelper shim +
`--disable-gpu --single-process`. It is CPU raster, so it will be slower than a GPU-composited
client, but it renders text, which the daily 11.16 engine has never done.

**Method note worth keeping:** wine-stable ships only `wine` (no separate `wine64`), and the
Gatekeeper approval is **per path** — copying the wine tree to a new location re-quarantines it and
`syspolicyd` blocks with no visible prompt (this cost ~7 min of apparent hang). Run the approved
binary IN PLACE and build a wrapper-shaped shell of symlinks around it, with a `wine64 -> wine`
alias for harnesses that expect the old name.

## `du` lies about disk on APFS: the two wrappers' 91 GB game installs were CLONES (2026-08-24)

Both wrappers reported a 91 GB `Cities Skylines II` install, so deleting the redundant one in
`CS2dxmt11-pk110.app` looked like a ~91 GB reclaim. **It freed 0 GB** — measured, `df -g` read
222 before and 222 after.

**Why:** APFS `clonefile` copies (Finder duplicate, `cp -c`, `cp -Rc`) get **distinct inodes but
share physical extents**. `du`/`ls` report each clone's *logical* size, so N clones of a 91 GB
tree look like N×91 GB while occupying ~91 GB plus divergence. Checking inodes is **not** enough
to prove two trees are independent — that check passed here and was still wrong.

**How to actually tell before deleting anything large:** trust only the container, not `du` —
`df -g /` (or `diskutil info / | grep "Container Free Space"`) before and after; on a clone the
number does not move. There is no cheap per-file "is this cloned" query, so measure the delta.

**The useful consequence:** restoring a clone is instant and free — `cp -Rc <src> <dst>` re-shares
the extents rather than copying 91 GB. So the pk110 wrapper can be given the game back in seconds
from the daily wrapper's copy if it is ever wanted as a play wrapper again; it does **not** need
a 91 GB Steam re-download. (Deleting `steamapps/common/<game>` **and** its
`appmanifest_<appid>.acf` together is what stops Steam re-downloading — removing the tree while
leaving the manifest makes Steam see "installed, files missing" and fetch the lot again.)

## Same-account Steam sessions SWAP, they don't stack — and the running game doesn't care (2026-08-24)

Context: the two-wrapper split (play on 11.16, shop on 11.0) puts two logged-in Steam clients on
one machine. The question the `CS2 Steam Store.app` shortcut forces: does opening the store kill
a running game?

**Measured mechanics.** Both clients RUN logged-in happily, but the account holds ONE online CM
session. Whichever client connects last takes it; the other logs
`ConnectionDisconnected() not auto reconnecting due to Session Replaced` and drops to its
cached/offline UI (footer shows NO CONNECTION; the library stays browsable). It does NOT
auto-reconnect, so the clients never fight — each swap is one clean handover, triggered only by
a fresh connect (client start, or a manual Go Online).

**The running game survives the steal — measured at the menu AND in live gameplay** (2026-08-24
22:13: session stolen mid-play with James at the controls; 2.5-min soak, game at 250% CPU, the
only new Player.log lines were routine Unity asset GC). Menu-state detail: with CS2 at the menu,
starting the store wrapper's Steam took the session at 21:42:59 — the game-side Steam delivered
`SteamServersDisconnected_t` and the game kept rendering (117% CPU) with ZERO new Player.log
lines over an 8-minute soak. CS2 needs SteamAPI at BOOT (the licence check behind the launcher's
45 s wait); a mid-session CM disconnect is a non-event. The reverse steal is symmetric: the next
game launch logs in and kicks the store back to cached mode (21:48:39, same session).

**Untested edge:** a Paradox Mods download in flight at the moment of a steal (different
auth/CDN — expected unaffected, not measured).

## Command lines cannot attribute a wine process to its wrapper — use lsof (2026-08-24)

The old rule (scope Steam checks with `pgrep -f "<App>.app.*steam.exe"`) has TWO blind spots,
both hit live in one evening:

1. **A steam.exe re-exec'd by its own updater/watchdog carries a Windows-style argv**
   (`C:\Program Files (x86)\Steam\steam.exe`) — no unix path anywhere, so every .app-path pgrep
   misses it. Found as a *hidden* logged-in Steam that a pgrep sweep called "no steam running";
   left alone it kept re-stealing the account session and respawning webhelpers that looked like
   orphans. An "already running" check that misses it starts a SECOND steam into the same
   prefix; a shutdown loop that misses it declares victory while Steam lives.
2. **steamwebhelper children always carry Windows-style argv AND reparent to launchd** when
   their steam.exe dies mid-cleanup — six of them survived a "Residual: 0" shutdown, invisible
   to `pgrep -f "$APPTAG"`.

**The truthful test is open files:** `lsof -p <pid> 2>/dev/null | grep -q "$WINEPREFIX"`
(~30 ms/pid). Attribute by PREFIX, not by the wine directory — an engine can serve a foreign
prefix (a /tmp/bisect scratch prefix ran the daily wrapper's wine binaries, so wine-dir matching
blamed its webhelpers on the daily wrapper). Both launchers now ship `_owns()` /
`steam_exe_up()` / `webhelper_up()` / `steam_family()` plus a shutdown sweep built on this, and
the `build-engine-1116.sh` / `install-webhelper-shim.sh` preflights use the same loop.

**Bonus trap:** bench/bisect scratch prefixes under /tmp keep their own logged-in steam.exe
alive for hours after the test ends — and steal the account session while at it (see the
session-swap entry above). End them: `WINEPREFIX=/tmp/<scratch> wineserver -k`.

## Retina mode: native 3024×1964 costs ~13% stress-scene GPU — but the game's saved resolution is a ratchet (2026-08-26)

Full campaign: `docs/plans/retina-swapchain-experiment.md` (triple-checked, then executed same
session; rt- rows in the perf results doc). The standing facts:

- **`RetinaMode=y` (+ LogPixels 192) works as designed on the self-built 11.16 engine**: Wine's
  desktop becomes the panel-native 3024×1964, the borderless swapchain follows automatically
  (Unity `Player.log` "Window resolution: 3024x1964", Metal HUD agrees), the compositor ×2
  upscale — the laptop-panel blur — disappears, painted street names go razor sharp, and the
  game UI scales proportionally (normal size). DPI is read from `HKCU\Control Panel\Desktop\
  LogPixels` (primary); per-app `AppDefaults` scoping is deliberately unsupported for RetinaMode
  (upstream comment: DPI/monitor geometry must be prefix-wide) — do not "fix" it into AppDefaults.
- **Measured cost (stress bench, ×3 medians): gpuMs.average 32.31 → 36.42 = +12.7%** for 4× the
  pixels — the scene is CPU/sim-bound, so GPU time responds sub-linearly. On the GPU-bound daily
  city expect the *absolute* delta (~+4 ms GPU) to matter more: ~25 → ~30 ms class, i.e. 40 FPS →
  mid-30s. Accidental middle point: 1920×1200 renders at 33.52 gpuMs (+3.7%).
- **TRAP 1 — `Benchmark.coc` `screenResolution` (→ results.jsonl `resolution`) is NOT the
  swapchain.** It is Unity's `Screen.currentResolution` = the *display-mode* view. Under retina,
  winemac's mode list doubles, the game's saved resolution can suddenly match a mode, and winemac
  *emulates* the mode change for borderless windows — so the field reports the saved value
  (1920×1200 here) while the game demonstrably renders 3024×1964. Arbiter for what actually
  rendered = `Player.log` "Window resolution" + the HUD, never this field.
- **TRAP 2 — the saved resolution cannot be cleared from disk; the game re-derives and re-persists
  it every run.** With a stale external-era 1920×1200 saved: run 1 under retina boots native, but
  the game re-applies 1920×1200 (validation of the on-disk value against its mode list evidently
  rejects 3024×1964), then at exit writes 1920×1200 into BOTH `Settings.coc` (`resolution` key —
  which it also transiently drops and re-adds) AND Unity's Screenmanager registry values, flipping
  `Resolution Use Native` 1 → 0. Consequence: the NEXT boot creates the window at 1920×1200 (soft
  upscale blit). Setting both layers to 3024×1964 with the game closed survives exactly one boot
  (that boot renders native) and is overwritten again on exit — measured across four launches.
  **Stable retina daily use therefore needs a pre-boot assert (`Screenmanager Resolution Use
  Native…=1`) in the launcher, or the in-game dropdown setting the game's own runtime value to
  3024×1964 (untested — the dropdown may not offer it if the mode list filters it).**
- Outcome 2026-08-26: **full revert, nothing adopted** (decision matrix row 4 — stable adoption
  requires a launcher change outside the checked plan's blast radius). Machine byte-verified back
  to the measured baseline state. The revert recipe lives in the plan §1.

**Addendum (same night — ADOPTED via the in-game dropdown; trap 2 refined).** Under retina the
in-game Screen Resolution dropdown lists the full doubled mode set (3024×1964 at 120/60/59/50/48/
47 Hz, 3024×1890, 2704×…, …). James selected 3024×1964×120 live; on exit the game persisted the
**complete tuple — width + height + `refreshRate` object — into `Settings.coc`** and wrote
Screenmanager 3024×1964 with `Use Native=1`. That refines trap 2: the file-edit rejection was
almost certainly the **missing `refreshRate`** (the stale external-era object carried only
width/height; a hand edit of those two fields alone fails the game's validation and falls back) —
not a mode-list filter. Consequences: (a) the ratchet ratchets *whichever way the last in-game
selection points* — after a UI selection of native it is self-maintaining and **no launcher assert
is needed** *(superseded 2026-08-27: the display-profile helper now asserts `Use Native=1` every boot regardless — docs/plans/launcher-display-profiles.md)*; (b) a future from-disk resolution change must write the full tuple including
`refreshRate`, or use the dropdown. Live-city cost of native-at-100% measured far above the
sim-bound bench's +13%: GPU 25.4 → 45.9 ms (40 → 22 FPS) — the bench extrapolation understated a
GPU-bound scene, as flagged. Final adopted config: retina native swapchain + DRS Constant 0.5 +
ContrastAdaptiveSharpen (= morning's render cost, native presentation).

**Second addendum (2026-08-27 — display profiles shipped; DRS disk-enable proven live).** The
launcher now runs `cs2-display-profile.sh` pre-boot (main-display-keyed: mobile = native + DRS
0.5 CAS · home/external = DRS off, native 1:1; `CS2_PROFILE=off|home|mobile`, `DRY=1`;
fail-open). Measured while shipping: (a) disk-flipping the DRS `enabled` flag **to true** does
take effect — a minScale-0.25 discriminator probe moved gpuMs.average 36.5→32.64 and 1%-low
22.5→32.6, far beyond repeat noise (the settings series had only proven the disable direction);
(b) ⚠ DRS-0.5's saving is **invisible on the sim-bound bench scene** at native swapchain (36.5 vs
native median 36.42 — pixels are cheap there); judge DRS by a scale-extreme probe or on the
GPU-bound live city, never by a single 0.5-vs-native bench pair; (c) the Metal HUD resolution
line shows the **drawable**, never DRS's internal render target — it is not a DRS arbiter.

**Third addendum (2026-08-27 — T10 first dock: RetinaMode is GLOBAL, so it joined the profile).**
winemac's RetinaMode doubles the coordinate space of EVERY display in the prefix, not just
retina-backed ones — measured: with a 1× DELL U2424H (1920×1080 logical = pixels) as main, the
game's window came up **3840×2160**, supersampled down by the compositor (75.35 gpuMs / 14.5 FPS
stress-scene — rt-home-1; pretty, unplayable). The display-profile helper (v2) therefore aligns
retina per context: **mobile = RetinaMode y + LogPixels 192/192 · home = RetinaMode deleted, CPD
LogPixels deleted, Fonts 96** — the option is read per-process at init, so a pre-boot flip is
exact, and skip-if-already keeps steady-state boots at zero wine calls. Proven live in the home
direction (rt-home-2: window 1920×1080 true 1:1, 36.49 gpuMs, registry state held through the
game's exit rewrite); the mobile direction is the same code path, DRY-verified, live-confirmed on
the next laptop boot. Reporting subtlety worth keeping: the settings-already-set early exit
initially swallowed the retina-ops report — the helper now flushes the DRY would-do list from
`out()` and marks "retina realigned" on that path.

## Mod keybind ⚠ badges arm at boot from FACTORY defaults — rebinds can't clear them (2026-08-27)

The Options mod-row/tab ⚠ is stale cached state, not live config: during boot, each mod's
`AddActions` triggers `InputManager.CheckConflicts` (via the defer-wrapper →
`ProcessActionsUpdate`) **before the per-user .coc overrides settle**, so the mods'
factory-default chords (which collide: FindIt/Traffic Ctrl+R, Traffic/quicksave Ctrl+S,
trio/quick-set, Anarchy/vanilla PgUp/Dn) get flagged into `ProxyBinding`'s cached conflict
state. Two separate surfaces read that cache — patching only the first (2026-08-27 v2) did
NOT clear the badges James sees; screenshots falsified that attribution:
- `SetModConflictNotification` → a per-mod "KeyBindingConflict" notification (menu toasts).
- **`InputBindingField.get_warning`** → per-keybind-row widget warning
  (`(binding.hasConflicts & mask) != 0`); the KEYBINDS-tab ⚠ and mod-row ⚠ aggregate from
  these rows (the mods declare no `SettingsUI*Warning` attributes — rows are the only
  source). This is the badge.
Opening a badged section re-runs `CheckConflicts` against the settled bindings → cache goes
clean → badge clears on mere viewing, re-arms next boot. That's why the 2026-08-25 disk
rebinds fixed real collisions but never the badge. **Lessons: an indicator that clears on
view without input is an acknowledgment/stale-cache pattern — don't debug it as a mirror of
current config; and after neutering one consumer of shared state, re-check WHICH consumer
renders the artifact you're chasing (xref all readers — here `get_hasConflicts` had four).**

Conflict predicate (for future binding work, disassembled 1.6.0f1):
`ProxyBinding.ConflictsWith` = both set + same device + `PathEquals` (+ usage overlap), where
PathEquals includes modifiers UNLESS either action has `modifierOptions==0` (then base-key-only
— `Alt+R` vs `Ctrl+Alt+R` would collide); `CanConflict` exempts whitelisted/linked pairs
(how Anarchy's mimic-vanilla PgUp/Dn shares keys without flagging).

Fix = two tiny IL patches, `patch-modconflict-badge.py` (~/cs2-patch original, repo scripts/
copy): **P1** `SetModConflictNotification` `ldarg.2`→`ldc.i4.0` (0x04→0x16, always the
pop/clear path — kills the notification) and **P2** `InputBindingField.get_warning` prologue
→ `ldc.i4.0; ret` (0x16 0x2A — constant-false widget warning, kills the badges). The cut is
at the WIDGET, not `ProxyBinding.get_hasConflicts`, because the interactive rebind
"key already taken" dialog (`InputRebindingUISystem` → `NeedAskUser`) reads `hasConflicts`
too and must stay live. Methods re-resolved by name via dnfile each run (refuses on
unexpected bytes), lsof game-down guard (run BEFORE dnfile opens the DLL — dnPE's own mmap
otherwise trips it), idempotent, backs up Game.dll. **The dxmt11 launcher auto-ensures both
at every start (step 0b)** — covers game updates; repatch.sh does NOT cover Game.dll.

## IL opcode surgery: branch opcodes have STACK effects — brfalse pops, br doesn't (2026-08-27)

The v1 badge patch flipped `brfalse`→`br` (0x39→0x38): one byte, same length, looks
equivalent — but `brfalse` POPS the condition its `ldarg.2` pushed and `br` does not, so the
method leaves an orphaned stack slot and Mono rejects the whole method at JIT:
`InvalidProgramException: Invalid IL code in ... SetModConflictNotification ... IL_015a`,
thrown on the BOOT path (CheckConflicts → InitializeUI) and again from every mod's
`AddActions` (MoveIt init died). Boot-verify caught it; backup restore was byte-verified by
the patcher's own sig check reading PATCHABLE again. **Rules: (1) when neutering a
conditional, replace the VALUE (`ldarg.X`→`ldc.i4.0/1`) and keep the branch, rather than
changing the branch opcode — it preserves stack shape by construction; (2) emulate stack
effects over every path before writing any opcode change; (3) an IL patch without a
boot-verify is not applied, it is armed.**

Second and third failures, same day (boot-verify rounds 4 + 5): **truncating a method is
the wrong primitive entirely — Mono linearly decodes the ENTIRE body, and dead code is not
exempt from any of it.** Round 4: `ldc.i4.0; ret` over the first two bytes left the old
third byte (a field-token fragment, 0x33) decoding as `bne.un.s` with an out-of-method
target → `InvalidProgramException: IL_0002`, in unreachable code. Round 5's "fix" (nop-pad
the whole tail) failed the SAME linear pass differently: **a `nop` tail falls off the end
of the method** — the decoder needs the last instruction to be a terminator, kept reading,
and hit the next method's tiny header (`IL_0021: beq.s IL_0095` = the neighbor's `2E 72`).
**Rule (4), as finally measured: don't truncate. The safe primitive is VALUE SUBSTITUTION
inside unchanged control flow — replace a load/call sequence with `ldc` + nops of identical
length, leaving every branch, stack shape and the original terminator intact** (v2c: the
11-byte `hasConflicts` load → `ldc.i4.0` + 10 nops; method computes `(0 & mask) != 0` =
false). Boot-verify caught all three same-day failures; none reached a play session.
