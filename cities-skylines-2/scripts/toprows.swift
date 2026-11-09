// toprows.swift -- scan a window capture down its centre column and report the first near-white
// row: that count is the macOS chrome (title bar) sitting above a client area the app painted white
// (COLOR_WINDOW). The instrument for wine 60262: stock 11.16 reads 64 device px, the fixed driver 0.
//   swiftc -O scripts/toprows.swift -o /tmp/toprows
//   /tmp/toprows capture.png
// (macgameport, 2026-10-10)
import Foundation
import CoreGraphics
import ImageIO
let path = CommandLine.arguments[1]
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let w = img.width, h = img.height
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
let x = w/2
var first = -1
for y in 0..<h { let i = (y*w + x)*4
  if p[i] > 245 && p[i+1] > 245 && p[i+2] > 245 { first = y; break } }
print("image \(w)x\(h) px; first near-white row at centre column = \(first) (rows of chrome above client)")
for y in [0, 10, 30, 50, 60, 70, 100] where y < h { let i=(y*w+x)*4; print("  row \(y): rgb \(p[i]),\(p[i+1]),\(p[i+2])") }
