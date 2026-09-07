// video-blue.swift -- per-frame diagnostic-colour fractions from a screen RECORDING, with timestamps.
//
// The frame probe captures every ~113 ms, which is coarser than the thing issue #12 is about: a
// blue (S3) region turned up on 2 frames out of 3,900 across 13 diag runs, and a single hit at that
// cadence bounds the event's duration only to "somewhere under ~226 ms". Duration is the whole
// question for #13 -- a 3 ms gap is a non-issue and a 100 ms gap is six frames of hole -- so this
// scores a `screencapture -v` recording instead, at display refresh (~16.7 ms), and prints each
// frame's presentation timestamp so consecutive-blue RUN LENGTHS give the duration directly.
//
// Whole-recording fractions, deliberately: the window grows and moves during a drag, so a rect that
// tracks it crops the edge under test (C53). The recorded rect is a fixed superset of the window's
// whole travel, and pure blue/green/magenta appear nowhere on a desktop but the diag build's own
// backgrounds -- so "any blue in this frame" needs no geometry to be meaningful.
//
// STRICT uses darkboxes.swift's thresholds unchanged (b>=200, r<=60, g<=60) so the numbers are
// comparable to bands.txt. LOOSE (b>=140, r<=100, g<=100) is reported beside it because H.264
// chroma subsampling drags a 1-pixel-wide blue sliver toward grey -- if the two ever disagree by
// much, the strict count is undercounting thin features and the loose one is what to read.
//
//   swiftc -O -o /tmp/video-blue scripts/video-blue.swift -framework AVFoundation
//   /tmp/video-blue rec.mov > frames.txt
// (macgameport, 2026-09-06)

import AVFoundation
import CoreVideo
import Foundation

let args = CommandLine.arguments
guard args.count > 1 else { FileHandle.standardError.write("usage: video-blue <file.mov>\n".data(using: .utf8)!); exit(2) }

// optional: `--where green|blue|magenta` switches from counting to locating
var whereColour: String? = nil
if let i = args.firstIndex(of: "--where"), i + 1 < args.count { whereColour = args[i + 1] }

let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
guard let track = asset.tracks(withMediaType: .video).first else {
    FileHandle.standardError.write("no video track\n".data(using: .utf8)!); exit(2)
}
guard let reader = try? AVAssetReader(asset: asset) else {
    FileHandle.standardError.write("cannot open reader\n".data(using: .utf8)!); exit(2)
}
let out = AVAssetReaderTrackOutput(track: track,
    outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
out.alwaysCopiesSampleData = false
reader.add(out)
reader.startReading()

var n = 0
while let sb = out.copyNextSampleBuffer() {
    guard let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
    let t = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb))
    CVPixelBufferLockBaseAddress(pb, .readOnly)
    let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
    let stride = CVPixelBufferGetBytesPerRow(pb)
    let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
    var blue = 0, blueLoose = 0, green = 0, magenta = 0
    for y in 0..<h {
        let row = base + y * stride
        for x in 0..<w {
            let p = row + x * 4                       // BGRA
            let b = Int(p[0]), g = Int(p[1]), r = Int(p[2])
            if b >= 200 && r <= 60 && g <= 60 { blue += 1 }
            if b >= 140 && r <= 100 && g <= 100 { blueLoose += 1 }
            if g >= 200 && r <= 60 && b <= 60 { green += 1 }
            if r >= 200 && b >= 200 && g <= 60 { magenta += 1 }
        }
    }
    CVPixelBufferUnlockBaseAddress(pb, .readOnly)
    // `--where <colour>` locates rather than counts: the bounding box and column extent of the
    // named colour on the frames that carry it. Added 2026-09-06 because magenta turned up on
    // hundreds of video frames while the WINDOW capture of the same build scored 0 of 300, and
    // "how many" cannot tell those two instruments apart -- "where" can.
    if let want = whereColour {
        var minx = w, maxx = -1, miny = h, maxy = -1, cnt = 0, cols = 0
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        var seen = [Bool](repeating: false, count: w)
        for y in 0..<h {
            let row = base + y * stride
            for x in 0..<w {
                let p = row + x * 4
                let b = Int(p[0]), g = Int(p[1]), r = Int(p[2])
                let hit: Bool
                switch want {
                case "green":   hit = g >= 200 && r <= 60 && b <= 60
                case "blue":    hit = b >= 200 && r <= 60 && g <= 60
                default:        hit = r >= 200 && b >= 200 && g <= 60
                }
                if hit {
                    cnt += 1
                    if !seen[x] { seen[x] = true; cols += 1 }
                    if x < minx { minx = x }
                    if x > maxx { maxx = x }
                    if y < miny { miny = y }
                    if y > maxy { maxy = y }
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pb, .readOnly)
        if cnt > 0 {
            print(String(format: "f%d t=%.4f %dx%d %@=%d px  x %d..%d (w %d, %d distinct cols)  y %d..%d (h %d)",
                         n, t, w, h, want, cnt, minx, maxx, maxx - minx + 1, cols, miny, maxy, maxy - miny + 1))
        }
        n += 1
        continue
    }
    let tot = Double(w * h) / 100.0
    print(String(format: "f%d t=%.4f %dx%d blue=%.4f blueloose=%.4f green=%.4f magenta=%.4f bluepx=%d greenpx=%d",
                 n, t, w, h, Double(blue)/tot, Double(blueLoose)/tot, Double(green)/tot, Double(magenta)/tot,
                 blue, green))
    n += 1
}
if reader.status == .failed {
    FileHandle.standardError.write("reader failed: \(reader.error?.localizedDescription ?? "?")\n".data(using: .utf8)!)
    exit(1)
}
FileHandle.standardError.write("scored \(n) frames\n".data(using: .utf8)!)
