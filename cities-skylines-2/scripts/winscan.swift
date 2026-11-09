// winscan.swift -- sample ONE window's diagnostic-colour fractions as fast as the window server
// will hand them over, for a fixed span. A DURATION instrument.
//
// ⛔ THIS DOES NOT RUN, and is kept only so the next person does not spend an hour rediscovering
// why. It was written to get high-cadence capture that survives a LOCKED session, which
// `screencapture -v` cannot. Two walls, in order:
//   1. `CGWindowListCreateImage` -- the obvious API, and what `screencapture -l` is built on -- is
//      UNAVAILABLE as of macOS 26. Not deprecated: the compiler refuses it outright.
//      "'CGWindowListCreateImage' is unavailable in macOS: Please use ScreenCaptureKit instead."
//   2. Rewritten on ScreenCaptureKit (below, and it compiles), every capture fails with
//      SCStreamErrorDomain Code=-3811, "Failed to start stream due to audio/video capture
//      failure" -- TCC refusing an unsigned ad-hoc binary. `screencapture` succeeds where this
//      fails because it is Apple-signed and carries the entitlement; a /tmp binary does not
//      inherit that from the terminal that spawned it. Granting it would be a security-settings
//      change, which is the user's to make and not worth it for one measurement.
// So high-cadence capture needs an UNLOCKED session and `screencapture -v` (scripts/video-blue.swift
// scores it). Measured 2026-09-06.
//
// Why not `screencapture`: spawning it costs ~113 ms a frame, which is the resolution limit that
// left issue #12's S3 gap bounded only to "under about 226 ms" (C56, 2 blue frames in 3,900). Its
// video mode (`-v`) does reach 60 fps -- but `-v` and `-R` composite the DISPLAY, so on a LOCKED
// session they record the lock screen, measured 2026-09-06: a 36 s recording came back 60 fps of
// animated wallpaper with no diagnostic colour in any frame, which reads exactly like a clean run.
// `CGWindowListCreateImage` reads the window's own backing store instead, so it keeps working with
// the session locked -- the same reason the frame probe's default mode does.
//
// Nothing is written to disk: each capture is scored in memory and only the counts are printed.
// That is deliberate given what a Steam window carries (EXPERIMENTS.md ~ Privacy).
//
// Thresholds are darkboxes.swift's, unchanged, so the fractions mean the same thing:
//   green  = a host placed larger than its content (S1)
//   blue   = the child's own layer before its first drawable (S3)
//   magenta= the deferred create path (S2)
//   black  = true black, lum < 6 -- with no colour on a diag build, that is S4, nothing hosting it
// R* are the same quantities over the right tenth, where issue #7's strip lives.
//
//   swiftc -O -o /tmp/winscan scripts/winscan.swift
//   /tmp/winscan <window-id> <seconds> > samples.txt
// (macgameport, 2026-09-06)

import AppKit
import CoreGraphics
import ScreenCaptureKit
import Foundation

// A plain command-line tool has no window-server connection, and ScreenCaptureKit trips
// `CGS_REQUIRE_INIT` on the first capture without one. Touching NSApplication establishes it.
_ = NSApplication.shared

// ⚠ CGWindowListCreateImage is UNAVAILABLE (a hard error, not a deprecation) as of macOS 26, so
// this is ScreenCaptureKit throughout. SCScreenshotManager.captureImage keeps reading a window's
// own content the way `screencapture -l` does, which is what survives a locked session.

let a = CommandLine.arguments
guard a.count > 2, let wid = UInt32(a[1]), let secs = Double(a[2]) else {
    FileHandle.standardError.write("usage: winscan <window-id> <seconds>\n".data(using: .utf8)!); exit(2)
}

func score(_ img: CGImage, _ t: Double, _ n: Int) {
    let w = img.width, h = img.height
    guard w > 24, h > 24, let data = img.dataProvider?.data, let base = CFDataGetBytePtr(data) else { return }
    let stride = img.bytesPerRow
    let bpp = img.bitsPerPixel / 8
    guard bpp >= 3 else { return }
    let bandX = w - w / 10          // the right tenth: issue #7's strip
    var black = 0, green = 0, blue = 0, magenta = 0
    var rBlack = 0, rGreen = 0, rBlue = 0, rMagenta = 0
    for y in 0..<h {
        let row = base + y * stride
        for x in 0..<w {
            let p = row + x * bpp
            let b = Int(p[0]), g = Int(p[1]), r = Int(p[2])       // BGRA
            if (r * 299 + g * 587 + b * 114) / 1000 < 6 { black += 1; if x >= bandX { rBlack += 1 } }
            if g >= 200 && r <= 60 && b <= 60 { green += 1; if x >= bandX { rGreen += 1 } }
            if b >= 200 && r <= 60 && g <= 60 { blue += 1; if x >= bandX { rBlue += 1 } }
            if r >= 200 && b >= 200 && g <= 60 { magenta += 1; if x >= bandX { rMagenta += 1 } }
        }
    }
    let all = Double(w * h) / 100.0
    let band = Double((w - bandX) * h) / 100.0
    print(String(format: "s%d t=%.4f %dx%d black=%.3f green=%.3f blue=%.3f magenta=%.3f Rblack=%.2f Rgreen=%.2f Rblue=%.2f Rmagenta=%.2f",
                 n, t, w, h, Double(black)/all, Double(green)/all, Double(blue)/all, Double(magenta)/all,
                 Double(rBlack)/band, Double(rGreen)/band, Double(rBlue)/band, Double(rMagenta)/band))
}

let sem = DispatchSemaphore(value: 0)
Task {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let win = content.windows.first(where: { $0.windowID == wid }) else {
            FileHandle.standardError.write("window \(wid) not in shareable content\n".data(using: .utf8)!)
            exit(3)
        }
        let filter = SCContentFilter(desktopIndependentWindow: win)
        let cfg = SCStreamConfiguration()
        cfg.width = Int(win.frame.width); cfg.height = Int(win.frame.height)
        cfg.showsCursor = false
        cfg.captureResolution = .nominal
        let t0 = Date()
        var n = 0, failed = 0
        while Date().timeIntervalSince(t0) < secs {
            do {
                let img = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
                score(img, Date().timeIntervalSince(t0), n); n += 1
            } catch {
                failed += 1
                if failed == 1 { FileHandle.standardError.write("first capture error: \(error)\n".data(using: .utf8)!) }
            }
        }
        FileHandle.standardError.write("sampled \(n) frames in \(String(format: "%.1f", Date().timeIntervalSince(t0)))s, \(failed) failed\n".data(using: .utf8)!)
    } catch {
        FileHandle.standardError.write("SCK error: \(error.localizedDescription)\n".data(using: .utf8)!)
        exit(4)
    }
    sem.signal()
}
sem.wait()
