# Archived: D3DMetal 3.0 on Wine 11 (stopped 2026-11-07)

An attempt to run Surviving Mars on the cs2 project's Wine 11.16 engine with CrossOver 26.2's
D3DMetal 3.0, so both games could share one prefix. Stopped; full record in cs2 `EXPERIMENTS.md` C83.

- D3DMetal's four DLLs import `ntdll.__wine_unix_call`, which Wine 11 dropped. `d3dmu.c`/`.def` build a
  side DLL that supplies it (and forwards `NtQueryVirtualMemory`); `pe_patch.py` renames the DLLs'
  import from `ntdll.dll` to `d3dmu.dll` (4 bytes each) and stamps Wine's 32-byte builtin signature.
  That part worked: the DLLs loaded, once a controlled `wineboot -u` wrote the system32 placeholder.
- With D3DMetal running inside Steam's processes, Steam crashed at start; with Steam on the DXMT engine
  it signed in, but the game died on a NULL read in macOS code. Likely cause, not debugger-proven:
  D3DMetal reads winemac's per-window record with CrossOver's layout.

`tools/make-engine.sh` refuses a Wine 11 source. To retry this route, put these files beside it and
re-add the compat branch (`ENGINE_COMPAT=1`) to `make-engine.sh`: build the side DLL, run `pe_patch.py`
over the four D3DMetal DLLs, as outlined above. That branch last existed in commit `6089bb5` of the
private pre-publication history (README, History), not in this repository.
