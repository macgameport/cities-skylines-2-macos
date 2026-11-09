"""inject.py <exe> <workdir> <inf|nan|none>  (run with Xcode's python3 and PYTHONPATH="$(lldb -P)")

Launch MarsSteam under lldb, stop at -[AppDelegate applicationDidFinishLaunching:] entry,
write the injected value into the never-initialised origin.y slot (rbp-0x40 == entry rsp-0x48;
origin.x = rbp-0x48 == entry rsp-0x50 is set to 0.0), then continue to either:
  ACCEPTED - initWithContentRect: returned (stop at entry+0x63, the instruction after the call)
  TRAPPED  - an exception stop (prints the top frames)
  EXITED   - the process ended before the entry breakpoint (prints the exit status; a 0 here is
             usually SteamAPI_RestartAppIfNecessary handing the launch to Steam: no steam_appid.txt
             in <workdir>)
The process is always killed before exit.
"""
import struct
import sys

import lldb

exe, workdir, inject = sys.argv[1:4]
VAL = {"inf": float("inf"), "nan": float("nan")}
dbg = lldb.SBDebugger.Create()
dbg.SetAsync(False)
dbg.HandleCommand("settings set target.skip-prologue false")
t = dbg.CreateTarget(exe)
bp1 = t.BreakpointCreateByName("-[AppDelegate applicationDidFinishLaunching:]")
li = t.GetLaunchInfo()
li.SetWorkingDirectory(workdir)
err = lldb.SBError()
p = t.Launch(li, err)
print("launch:", err.GetCString() or "ok", "| bp1 locations:", bp1.GetNumLocations())
bp2 = None
verdict = "NO-STOP"
try:
    for _ in range(30):
        if not p.IsValid():
            verdict = "INVALID-PROCESS"
            break
        if p.GetState() == lldb.eStateExited:
            verdict = f"EXITED status={p.GetExitStatus()} desc={p.GetExitDescription()}"
            break
        if p.GetState() != lldb.eStateStopped:
            verdict = f"STATE-{p.GetState()}"
            break
        th = p.GetSelectedThread()
        fr = th.GetFrameAtIndex(0)
        reason = th.GetStopReason()
        if reason == lldb.eStopReasonBreakpoint:
            bid = th.GetStopReasonDataAtIndex(0)
            if bid == bp1.GetID():
                entry, sp = fr.GetPC(), fr.GetSP()
                print(f"entry pc={entry:#x} sym={fr.GetSymbol().GetName()}")
                if inject in VAL:
                    p.WriteMemory(sp - 0x50, struct.pack("<d", 0.0), err)
                    p.WriteMemory(sp - 0x48, struct.pack("<d", VAL[inject]), err)
                    back = struct.unpack("<2d", p.ReadMemory(sp - 0x50, 16, err))
                    print(f"injected origin = {back}")
                bp2 = t.BreakpointCreateByAddress(entry + 0x63)
            elif bp2 is not None and bid == bp2.GetID():
                verdict = "ACCEPTED"
                break
        elif reason in (lldb.eStopReasonException, lldb.eStopReasonSignal):
            print("stop:", th.GetStopDescription(200))
            for i in range(min(6, th.GetNumFrames())):
                f = th.GetFrameAtIndex(i)
                print("  ", f.GetModule().GetFileSpec().GetFilename(), f.GetFunctionName() or f.GetSymbol().GetName())
            sig = th.GetStopReasonDataAtIndex(0) if reason == lldb.eStopReasonSignal else None
            if reason == lldb.eStopReasonException or sig in (4, 6, 10, 11):
                verdict = "TRAPPED"
                break
        else:
            print("stop (other):", reason, th.GetStopDescription(200))
        p.Continue()
finally:
    if p.IsValid() and p.GetState() not in (lldb.eStateExited, lldb.eStateDetached):
        p.Kill()
    print("VERDICT:", verdict)
