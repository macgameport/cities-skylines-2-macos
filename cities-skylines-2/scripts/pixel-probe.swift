// pixel-probe.swift -- measure the EDGES of a captured window instead of eyeballing a screenshot.
//
// The resize artifact under investigation is a 1-device-pixel strip at the right/bottom edge of a
// hosted CALayer. That is invisible in a scaled-down screenshot and impossible to argue about from
// a description, so measure it: print the mean RGB of the outermost N columns and rows, next to a
// reference column from the interior. A bright edge against a dark interior IS the artifact.
//
// Build: swiftc -O scripts/pixel-probe.swift -o /tmp/pixel-probe
// Usage: /tmp/pixel-probe <png> [edge-depth, default 4]
//        /tmp/pixel-probe <png> strip <x> <w>    mean RGB of columns x..x+w-1 over the interior rows
// Exit:  2 usage · 3 no bitmap context · 4 image too small to probe (under 24 px on a side)
// (macgameport, 2026-08-31; strip mode and the size guard 2026-09-03)

import Foundation
import CoreGraphics
import ImageIO

func die(_ msg: String, _ code: Int32) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(code)
}

let args = CommandLine.arguments
guard args.count >= 2,
      let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    die("usage: pixel-probe <png> [depth] | pixel-probe <png> strip <x> <w>", 2)
}
let w = img.width, h = img.height
// Below this the margins meet in the middle. col() averages rows m..<(h-m) with m = max(8, h/12):
// at h = 10 that is the Range 8..<2, which traps before any division happens (measured
// 2026-09-03 -- the earlier "divide by zero" reading of the tiny-image crash was wrong). 24 keeps
// at least 8 interior rows and columns and makes the depth clamp below reachable.
if w < 24 || h < 24 { die("too small to probe (\(w)x\(h))", 4) }
var buf = [UInt8](repeating: 0, count: w * h * 4)
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: w * 4, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(3) }
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

// margins skipped at each end so rounded corners and window shadow do not dominate an average,
// clamped below half the dimension so the interior range can never be empty
let mh = min(max(8, h / 12), h / 2 - 1)   // rows skipped top and bottom when averaging a column
let mw = min(max(8, w / 12), w / 2 - 1)   // columns skipped left and right when averaging a row

func mean(x0: Int, x1: Int, y0: Int, y1: Int) -> (Int, Int, Int) {
    var r = 0, g = 0, b = 0, n = 0
    for y in y0..<y1 {
        for x in x0..<x1 { let i = (y * w + x) * 4; r += Int(buf[i]); g += Int(buf[i+1]); b += Int(buf[i+2]); n += 1 }
    }
    return n == 0 ? (0, 0, 0) : (r / n, g / n, b / n)
}
func col(_ x: Int) -> (Int, Int, Int) { mean(x0: x, x1: x + 1, y0: mh, y1: h - mh) }
func row(_ y: Int) -> (Int, Int, Int) { mean(x0: mw, x1: w - mw, y0: y, y1: y + 1) }
func fmt(_ t: (Int, Int, Int)) -> String { String(format: "%3d,%3d,%3d", t.0, t.1, t.2) }
func lum(_ t: (Int, Int, Int)) -> Int { (t.0 * 299 + t.1 * 587 + t.2 * 114) / 1000 }

if args.count >= 3 && args[2] == "strip" {
    // strip <x> <w>: the mean of an arbitrary column band over the interior rows. Two strips that
    // differ by more than 8 per channel are different content; a strip read before and after a
    // move is how a child-window relocation is measured (hosting-layer-design-gaps.md T1).
    guard args.count >= 5, let x = Int(args[3]), let sw = Int(args[4]) else { die("strip: want <x> <w>", 2) }
    guard x >= 0, sw >= 1, x + sw <= w else { die("strip: x=\(x) w=\(sw) is outside the image (width \(w))", 2) }
    let s = mean(x0: x, x1: x + sw, y0: mh, y1: h - mh)
    print("strip x=\(x) w=\(sw)  \(fmt(s))  lum \(lum(s))")
    exit(0)
}

var depth = args.count >= 3 ? (Int(args[2]) ?? 4) : 4
// x = w-1-k and y = h-1-k must stay inside the image; cap the walk at the interior band so an
// oversized depth degrades to "the whole edge band" instead of indexing before the image
depth = max(1, min(depth, min(w, h) - 2 * min(mh, mw)))

print("image \(w)x\(h) px   (\(w % 2 == 0 ? "even" : "ODD") width, \(h % 2 == 0 ? "even" : "ODD") height)")
let refC = col(w / 2), refR = row(h / 2)
print("interior reference   col x=\(w/2): \(fmt(refC)) lum \(lum(refC))    row y=\(h/2): \(fmt(refR)) lum \(lum(refR))")
print("RIGHT edge (outermost \(depth) columns, x = w-1 inward):")
for k in 0..<depth {
    let x = w - 1 - k, c = col(x)
    print("  x=\(x)  \(fmt(c))  lum \(lum(c))\(lum(c) > lum(refC) + 60 ? "   <== BRIGHT vs interior" : "")")
}
print("BOTTOM edge (outermost \(depth) rows, y = h-1 inward):")
for k in 0..<depth {
    let y = h - 1 - k, c = row(y)
    print("  y=\(y)  \(fmt(c))  lum \(lum(c))\(lum(c) > lum(refR) + 60 ? "   <== BRIGHT vs interior" : "")")
}
