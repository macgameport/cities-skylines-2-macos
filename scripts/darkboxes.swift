// darkboxes.swift — per-edge true-black scoring for window captures.
//
// Build:  swiftc -O scripts/darkboxes.swift -o /tmp/darkboxes
// Use:    /tmp/darkboxes <lum-threshold> <png>...
//
// For each frame prints the fraction of pixels below the luminance threshold overall and in each
// outer 10% band (L/R/T/B), plus the largest dark block found by row projection. Use threshold 6
// for true black (Steam's own dark chrome sits near lum 20-40) and 15 to match pixel-probe's "gap".
//
// WHY THIS EXISTS (2026-09-03): livedrag-probe scored min(mean edge, interior) and reported 76
// for a run in which the right 10% of the window was 93% pure black -- the hosted child had not
// caught up with the drag and the exposed strip showed the host layer's black background. A
// mean over all four edges diluted a 280 px black column to nothing. Score bands, never a mean
// of the perimeter, and keep the frames: C28's were not kept and there is no baseline for them.
import Foundation
import CoreGraphics
import ImageIO
// Per-frame: fraction of near-black pixels in each outer 10% band, plus the bounding box of the
// largest dark blob found by row projection. The bitmap's row 0 is the image's TOP row (checked
// against a frame whose top chrome row was black, 2026-09-03 -- the first version had T/B swapped).
func load(_ p: String) -> CGImage? {
  guard let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil) else { return nil }
  return CGImageSourceCreateImageAtIndex(s, 0, nil)
}
let thr = Int(CommandLine.arguments[1]) ?? 15
for path in CommandLine.arguments.dropFirst(2) {
  guard let img = load(path) else { print("\(path): load failed"); continue }
  let w = img.width, h = img.height
  var buf = [UInt8](repeating: 0, count: w*h*4)
  guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
  ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
  var dark = [Bool](repeating: false, count: w*h); var total = 0
  for i in 0..<(w*h) { let j = i*4; let lum = (Int(buf[j])*299 + Int(buf[j+1])*587 + Int(buf[j+2])*114)/1000; if lum < thr { dark[i] = true; total += 1 } }
  func frac(_ x0: Int, _ x1: Int, _ y0: Int, _ y1: Int) -> Double { var d = 0; for y in y0..<y1 { for x in x0..<x1 where dark[y*w+x] { d += 1 } }; return 100*Double(d)/Double((x1-x0)*(y1-y0)) }
  let bw = w/10, bh = h/10
  let L = frac(0,bw,0,h), R = frac(w-bw,w,0,h), Top = frac(0,w,0,bh), Bot = frac(0,w,h-bh,h)
  // largest dark rectangle by projection: rows with >=200 dark px that are contiguous, then column extent
  var best = (0,0,0,0,0)  // area, x0,y0(top-origin),x1,y1
  var y = 0
  while y < h {
    var cnt = 0; for x in 0..<w where dark[y*w+x] { cnt += 1 }
    if cnt >= 200 {
      var y2 = y; while y2+1 < h { var c2 = 0; for x in 0..<w where dark[(y2+1)*w+x] { c2 += 1 }; if c2 < 200 { break }; y2 += 1 }
      var x0 = w, x1 = 0; for yy in y...y2 { for x in 0..<w where dark[yy*w+x] { if x < x0 { x0 = x }; if x > x1 { x1 = x } } }
      let area = (x1-x0+1)*(y2-y+1); if area > best.0 { best = (area, x0, y, x1, y2) }
      y = y2 + 1
    } else { y += 1 }
  }
  let name = (path as NSString).lastPathComponent
  print(String(format: "%@ %dx%d dark=%.2f%% L=%.1f R=%.1f T=%.1f B=%.1f  biggest-dark-block=%dx%d at x=%d y=%d (top-origin)",
        name, w, h, 100*Double(total)/Double(w*h), L, R, Top, Bot, best.3-best.1+1, best.4-best.2+1, best.1, best.2))
}
