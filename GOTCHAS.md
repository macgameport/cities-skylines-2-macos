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
and **loses text the same way the moment the shim is added**. So `--in-process-gpu` breaks glyph
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

**HALF 2 status: NOT attempted — toolchain absent.** Measured 2026-08-29: **`meson`, `ninja`, `llvm-config` and `cmake` are all
missing** on this machine (only Apple clang + git). notpop's `07-build-dxmt-fork.sh` needs meson
with `-Dnative_llvm_path` and two cross-files, built twice (64- and 32-bit). **`notpop/dxmt` also
publishes NO releases**, so there is no prebuilt fork to drop in — it must be compiled. Every DXMT
binary in this project was *reused* from the Wine 11.0 + DXMT base engine, never compiled. Standing
up that toolchain is ~2-3 GB of brew installs and its own mini-project.

**Also eliminated today, both never previously run** (daily wrapper, capture-judged):
`-cef-force-gpu` → black **108,343 B**, GPU process survives (1 child, no crashes) ·
`--use-angle=d3d9` → black **108,343 B**, same. So ANGLE's D3D9 backend and Steam's own
force-GPU switch join `d3d11`/`gl`/`vulkan`/`swiftshader` on the eliminated list.

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
