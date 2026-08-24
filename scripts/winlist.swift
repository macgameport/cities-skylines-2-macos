// winlist.swift — enumerate on-screen windows so a headless session can inspect a Wine window
// without fronting it and without granting Accessibility permission.
//
//   swiftc -O scripts/winlist.swift -o /tmp/winlist
//   /tmp/winlist | grep owner=wine
//   screencapture -x -o -l <id> shot.png      # captures that window even when occluded
//
// Why this exists: `osascript`/System Events needs Accessibility (and prompts for it), and the
// older capture scripts hardcode `-R x,y,w,h` regions that break the moment a window moves.
// Used 2026-08-24 to measure Steam's black CEF windows — see GOTCHAS.md
// "Steam black UI is NOT the Vulkan failure".
//
// ⚠ Validate the instrument before trusting an all-black reading: capture a KNOWN-GOOD occluded
// window too. If that one also comes back black, the capture is the problem, not the app.

import CoreGraphics
import Foundation

let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
    FileHandle.standardError.write("winlist: CGWindowListCopyWindowInfo returned nothing (screen recording permission?)\n".data(using: .utf8)!)
    exit(1)
}

for w in info {
    let owner = w[kCGWindowOwnerName as String] as? String ?? "?"
    let name  = w[kCGWindowName  as String] as? String ?? ""
    let num   = w[kCGWindowNumber as String] as? Int ?? -1
    let layer = w[kCGWindowLayer  as String] as? Int ?? -1
    var wd = 0, ht = 0, x = 0, y = 0
    if let b = w[kCGWindowBounds as String] as? [String: Any] {
        wd = (b["Width"]  as? NSNumber)?.intValue ?? 0
        ht = (b["Height"] as? NSNumber)?.intValue ?? 0
        x  = (b["X"]      as? NSNumber)?.intValue ?? 0
        y  = (b["Y"]      as? NSNumber)?.intValue ?? 0
    }
    print("id=\(num) layer=\(layer) owner=\(owner) size=\(wd)x\(ht) at=\(x),\(y) title=\(name)")
}
