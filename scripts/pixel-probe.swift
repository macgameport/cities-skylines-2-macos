// pixel-probe.swift -- measure the EDGES of a captured window instead of eyeballing a screenshot.
//
// The resize artifact under investigation is a 1-device-pixel strip at the right/bottom edge of a
// hosted CALayer. That is invisible in a scaled-down screenshot and impossible to argue about from
// a description, so measure it: print the mean RGB of the outermost N columns and rows, next to a
// reference column from the interior. A bright edge against a dark interior IS the artifact.
//
// Build: swiftc -O scripts/pixel-probe.swift -o /tmp/pixel-probe
// Usage: /tmp/pixel-probe <png> [edge-depth, default 4]
// (macgameport, 2026-08-31)

import Foundation
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
guard args.count >= 2,
      let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write("usage: pixel-probe <png> [depth]\n".data(using: .utf8)!)
    exit(2)
}
let depth = args.count >= 3 ? (Int(args[2]) ?? 4) : 4
let w = img.width, h = img.height
var buf = [UInt8](repeating: 0, count: w * h * 4)
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: w * 4, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(3) }
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

// mean of a column (x fixed) / row (y fixed), skipping a margin at each end so rounded corners
// and window shadow do not dominate the average
func col(_ x: Int) -> (Int, Int, Int) {
    var r = 0, g = 0, b = 0, n = 0
    let m = max(8, h / 12)
    for y in m..<(h - m) { let i = (y * w + x) * 4; r += Int(buf[i]); g += Int(buf[i+1]); b += Int(buf[i+2]); n += 1 }
    return (r / n, g / n, b / n)
}
func row(_ y: Int) -> (Int, Int, Int) {
    var r = 0, g = 0, b = 0, n = 0
    let m = max(8, w / 12)
    for x in m..<(w - m) { let i = (y * w + x) * 4; r += Int(buf[i]); g += Int(buf[i+1]); b += Int(buf[i+2]); n += 1 }
    return (r / n, g / n, b / n)
}
func fmt(_ t: (Int, Int, Int)) -> String { String(format: "%3d,%3d,%3d", t.0, t.1, t.2) }
func lum(_ t: (Int, Int, Int)) -> Int { (t.0 * 299 + t.1 * 587 + t.2 * 114) / 1000 }

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
