#!/usr/bin/env python3
"""Stop native-macOS Surviving Mars crashing at launch on macOS 27 (SIGILL, NaN view geometry).

Mechanism (disassembled 2026-10-30, Steam app 464920, buildid 8705308, Mac build
05-09-2022, x86_64 under Rosetta): -[AppDelegate applicationDidFinishLaunching:]
builds the content rect for -[HGWindow initWithContentRect:styleMask:backing:defer:]
from two 16-byte halves:

  0x1005dee1d  movaps 0x1cfb4c(%rip),%xmm0   ; size  = {1024.0, 768.0} (constant)
  0x1005dee24  movups %xmm0,-0x38(%rbp)
  0x1005dee2f  movups -0x48(%rbp),%xmm0      ; origin = NEVER WRITTEN -> stack garbage
  0x1005dee33  movups -0x38(%rbp),%xmm1

Whatever is left on the stack becomes the window origin. macOS 27's AppKit traps
it in NSViewValidateRect ("Invalid view geometry: height is NaN") and the game
dies with EXC_BAD_INSTRUCTION before a frame is drawn.

Measured 2026-10-30 (MacBook, M3 Max):
  - Natural crash: 8 of 8 launches 20:50-20:55 on macOS 27.0.1, all Steam/LaunchServices
    launches (_handleAEOpenEvent in every stack), all this exact trap. From 20:56 it stopped
    reproducing: 3 stock Steam launches survived, including with LocalStorage.lua removed and
    with the app-support dir reset to its pre-crash contents. Trigger state unknown.
  - Mechanism, on demand (tools/inject-ab.sh, macOS 27.2): +inf or NaN written into the
    origin.y slot under lldb -> stock TRAPPED in _NSViewValidateGeometry <- NSViewValidateRect
    <- NSThemeFrame (the crash-report chain); patched -> initWithContentRect: returns.
  - Patched Steam install launched via steam://run on 27.2: alive at 10 s, log reached Steam
    init and texture load, 0 crash reports (tools/steam-judge.sh). Not yet play-tested.

Patch (4 bytes, file offset 0x5dee2f, same length, no control flow touched):
  0f 10 45 b8   movups -0x48(%rbp),%xmm0
  0f 57 c0 90   xorps  %xmm0,%xmm0 ; nop     -> origin = {0, 0}

The binary is unsigned ("code object is not signed at all"), so nothing needs
re-signing. A Steam "verify integrity" or a game update restores the stock
bytes: re-run `apply`.

Usage:
  python3 patch-window-origin.py            # verify only (safe while the game runs)
  python3 patch-window-origin.py apply      # backup + patch (game must be down)
  python3 patch-window-origin.py revert     # restore stock bytes (game must be down)
  ... [path/to/MarsSteam]                   # optional last arg; default = Steam install
"""
import hashlib
import os
import shutil
import subprocess
import sys

DEFAULT = os.path.expanduser(
    "~/Library/Application Support/Steam/steamapps/common/Surviving Mars/"
    "MarsSteam.app/Contents/MacOS/MarsSteam")
BACKUP_DIR = os.path.join(os.environ.get("SM_STATE") or os.path.expanduser(
    "~/Library/Application Support/1launcher/surviving-mars-relaunched"), "backup")

OFF = 0x5dee2f
BEFORE = bytes.fromhex("488b3541642200")  # movq selector(initWithContentRect:...),%rsi
STOCK = bytes.fromhex("0f1045b8")
PATCHED = bytes.fromhex("0f57c090")
AFTER = bytes.fromhex("0f104dc8")         # movups -0x38(%rbp),%xmm1


def state(data: bytes) -> str:
    lo = OFF - len(BEFORE)
    if data[lo:OFF] != BEFORE or data[OFF + 4:OFF + 4 + len(AFTER)] != AFTER:
        return "unknown"
    return {STOCK: "stock", PATCHED: "patched"}.get(data[OFF:OFF + 4], "unknown")


def game_running(path: str) -> bool:
    return subprocess.run(["pgrep", "-f", path], capture_output=True).returncode == 0


def main() -> int:
    args = sys.argv[1:]
    mode = args.pop(0) if args and args[0] in ("apply", "revert") else "verify"
    path = args[0] if args else DEFAULT
    data = open(path, "rb").read()
    st = state(data)
    print(f"target: {path}")
    print(f"sha256: {hashlib.sha256(data).hexdigest()[:16]}  state: {st}")
    if st == "unknown":
        print("REFUSED: context bytes do not match the 2022 Mac build; re-disassemble first")
        return 1
    if mode == "verify":
        return 0
    want = "patched" if mode == "apply" else "stock"
    if st == want:
        print(f"already {want}, nothing to do")
        return 0
    if game_running(path):
        print("REFUSED: the game is running; quit it first")
        return 2
    if mode == "apply":
        os.makedirs(BACKUP_DIR, exist_ok=True)
        bak = os.path.join(BACKUP_DIR, f"MarsSteam.{hashlib.sha256(data).hexdigest()[:16]}.orig")
        if not os.path.exists(bak):
            shutil.copy2(path, bak)
            print(f"backup: {bak}")
    with open(path, "r+b") as f:
        f.seek(OFF)
        f.write(PATCHED if mode == "apply" else STOCK)
    after = open(path, "rb").read()
    print(f"sha256: {hashlib.sha256(after).hexdigest()[:16]}  state: {state(after)}")
    return 0 if state(after) == want else 1


if __name__ == "__main__":
    sys.exit(main())
