// video-blue.swift -- per-frame diagnostic-colour fractions from a screen RECORDING, with timestamps.
//
// The frame probe captures every ~113 ms, which is coarser than the thing issue #12 is about: a
// blue (S3) region turned up on 2 frames out of 3,900 across 13 diag runs, and a single hit at that
// cadence bounds the event's duration only to "somewhere under ~226 ms". Duration is the whole
// question for #13 -- a 3 ms gap is a non-issue and a 100 ms gap is six frames of hole -- so this
// scores a `screencapture -v` recording instead, at display refresh (~16.7 ms), and prints each
// frame's presentation timestamp so consecutive-blue RUN LENGTHS give the duration directly.
//
// Whole-recording fractions by default, deliberately: the window grows and moves during a drag, so
// a rect that TRACKS it crops the edge under test (C53). The recorded rect is a fixed superset of
// the window's whole travel, and pure blue/green/magenta appear nowhere on a desktop but the diag
// build's own backgrounds -- so "any blue in this frame" needs no geometry to be meaningful.
//
// `--rect x,y,w,h` is the exception the S3 plan's S1b needs, and it is NOT the thing C53 ruled out.
// C53's mistake was a rect that FOLLOWED the window, which subtracts the newly-grown ground that is
// the whole signal. This one is FIXED for the life of the recording, supplied by the caller (the
// aligner, from a known episode), and its only job is to stop the rest of the screen contributing
// to a fraction. A fixed rect cannot crop a growing edge it does not move with -- but it can crop a
// window that grows out of it, so size it as a superset of the travel, exactly as the recording is.
// Fractions are then RECT-relative, and every line says `rect=` so a rect run cannot be read as a
// whole-frame one.
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

// optional: `--rect x,y,w,h` scores only that sub-rectangle, in the recording's own pixels.
var rectArg: (x: Int, y: Int, w: Int, h: Int)? = nil
if let i = args.firstIndex(of: "--rect"), i + 1 < args.count {
    let p = args[i + 1].split(separator: ",").map { Int($0.trimmingCharacters(in: .whitespaces)) }
    guard p.count == 4, !p.contains(where: { $0 == nil }), p[2]! > 0, p[3]! > 0 else {
        FileHandle.standardError.write("--rect wants x,y,w,h with w,h > 0\n".data(using: .utf8)!); exit(2)
    }
    rectArg = (p[0]!, p[1]!, p[2]!, p[3]!)
}

// Clamp to the frame ONCE per frame and report what was actually scored. A rect partly off the
// frame is a caller error worth seeing rather than silently shrinking: `rect=` prints the clamped
// values, so a run whose rect fell outside the recording reads as a zero-area refusal, not as a
// clean sheet of zero episodes.
func clamped(_ w: Int, _ h: Int) -> (x0: Int, y0: Int, x1: Int, y1: Int) {
    guard let r = rectArg else { return (0, 0, w, h) }
    let x0 = max(0, min(r.x, w)), y0 = max(0, min(r.y, h))
    return (x0, y0, max(x0, min(r.x + r.w, w)), max(y0, min(r.y + r.h, h)))
}

func rectLabel(_ r: (x0: Int, y0: Int, x1: Int, y1: Int)) -> String {
    guard rectArg != nil else { return "" }
    return String(format: "  rect=%d,%d,%d,%d", r.x0, r.y0, r.x1 - r.x0, r.y1 - r.y0)
}

// ⚠ Refuse an argument this build does not know, rather than ignoring it. `livedrag-probe.sh:247`
// CACHES the compiled binary at /tmp/video-blue and only rebuilds it when absent, so a caller can
// easily be talking to a binary older than the source. Silently ignoring `--rect` there would
// return WHOLE-FRAME fractions to a caller that asked for a sub-rectangle -- the same numbers, the
// same shape, quietly answering a different question. Exit loudly instead.
let known = ["--where", "--rect"]
for (i, a) in args.enumerated() where i > 1 && a.hasPrefix("--") {
    if !known.contains(a) {
        FileHandle.standardError.write(("unknown option \(a) -- this build knows only "
            + known.joined(separator: ", ")
            + ".\nIf you expected it to: rm /tmp/video-blue and let the caller rebuild.\n")
            .data(using: .utf8)!)
        exit(2)
    }
}

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
    var blue = 0, blueLoose = 0, green = 0, magenta = 0, cyan = 0, black = 0
    let R = clamped(w, h)
    for y in R.y0..<R.y1 {
        let row = base + y * stride
        for x in R.x0..<R.x1 {
            let p = row + x * 4                       // BGRA
            let b = Int(p[0]), g = Int(p[1]), r = Int(p[2])
            if b >= 200 && r <= 60 && g <= 60 { blue += 1 }
            if b >= 140 && r <= 100 && g <= 100 { blueLoose += 1 }
            if g >= 200 && r <= 60 && b <= 60 { green += 1 }
            if r >= 200 && b >= 200 && g <= 60 { magenta += 1 }
            if g >= 200 && b >= 200 && r <= 60 { cyan += 1 }   // C42's content-view layer
            // true black at darkboxes' threshold, so a strip that carries NO diagnostic colour is
            // counted alongside the ones that do -- the whole question on a build that colours one
            // surface is "is the exposure this colour, or is it still black?"
            if (r * 299 + g * 587 + b * 114) / 1000 < 6 { black += 1 }
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
        for y in R.y0..<R.y1 {
            let row = base + y * stride
            for x in R.x0..<R.x1 {
                let p = row + x * 4
                let b = Int(p[0]), g = Int(p[1]), r = Int(p[2])
                let hit: Bool
                switch want {
                case "green":   hit = g >= 200 && r <= 60 && b <= 60
                case "blue":    hit = b >= 200 && r <= 60 && g <= 60
                case "cyan":    hit = g >= 200 && b >= 200 && r <= 60
                case "black":   hit = (r * 299 + g * 587 + b * 114) / 1000 < 6
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
            print(String(format: "f%d t=%.4f %dx%d %@=%d px  x %d..%d (w %d, %d distinct cols)  y %d..%d (h %d)%@",
                         n, t, w, h, want, cnt, minx, maxx, maxx - minx + 1, cols, miny, maxy, maxy - miny + 1,
                         rectLabel(R)))
        }
        n += 1
        continue
    }
    // Rect-relative: the denominator is the area actually scanned, so a fraction means the same
    // thing ("this share of what I looked at") whether or not a rect was supplied.
    let tot = Double(max(1, (R.x1 - R.x0) * (R.y1 - R.y0))) / 100.0
    print(String(format: "f%d t=%.4f %dx%d blue=%.4f blueloose=%.4f green=%.4f magenta=%.4f cyan=%.4f black=%.4f bluepx=%d greenpx=%d cyanpx=%d blackpx=%d%@",
                 n, t, w, h, Double(blue)/tot, Double(blueLoose)/tot, Double(green)/tot, Double(magenta)/tot,
                 Double(cyan)/tot, Double(black)/tot, blue, green, cyan, black, rectLabel(R)))
    n += 1
}
if reader.status == .failed {
    FileHandle.standardError.write("reader failed: \(reader.error?.localizedDescription ?? "?")\n".data(using: .utf8)!)
    exit(1)
}
FileHandle.standardError.write("scored \(n) frames\n".data(using: .utf8)!)
