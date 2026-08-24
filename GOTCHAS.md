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

## Alt-tab still freezes the game — presentation, NOT refresh rate (2026-08-22)

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
    assistance disclosed; no PR per their policy). Watch the issue for maintainer follow-ups.
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
- Exclusive Fullscreen remains freeze-on-alt-tab until dxmt#206 is fixed upstream.

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
