// launch-progress.swift -- the start-up progress window of both games' double-click apps.
// cities-skylines-2/scripts/make-shortcut.sh and surviving-mars-relaunched/make-app.sh compile it into
// <app>/Contents/Resources/launch-progress, and the app's shim starts it beside the launcher. It follows
// the log the shim writes and shows the newest step line the launcher printed there, `[n/N] text`
// (`step` in each launcher's launch-feedback block).
//
//   LP_TITLE="<game>" LP_LOG=<launcher log> launch-progress     the window
//   launch-progress --parse <log>      prints "<n> <N> <text>", "error" or "0 0"
//   launch-progress --decide <log> <seconds since the log grew> <seconds since the final step, or -1>
//                   <seconds since start> <1 if the parent is still the starter, else 0>
//                                      prints "show" or "close"
// Both test modes return before any window object is made, and the window's timer calls the same two
// functions. Tests: common/test-launch-progress.sh.
//
// Until 2026-11-10 this was a heredoc in make-shortcut.sh, for Cities: Skylines II only. It found its
// step by matching the launcher's message text, which no test named, and it quit after 8 minutes
// whatever was happening, while a game update is allowed 60.
//
// The title and the log come from the environment, never from the arguments: a game's name on a
// helper's command line is how a watcher came to be taken for the game (make-shortcut.sh, the shim's
// note of 2026-08-23).
import AppKit

enum Reading { case none, error, step(Int, Int, String) }

// The current session's lines: the text after the last line that starts with "===== " (the shim writes
// one before each launch), or the whole log if there is none. Only that part is decoded, and leniently,
// so that one bad byte anywhere does not blank the window.
func sessionLines(ofLog path: String) -> [Substring] {
    guard let data = FileManager.default.contents(atPath: path) else { return [] }
    var from = data.startIndex
    if let r = data.range(of: Data("\n===== ".utf8), options: .backwards) { from = r.lowerBound + 1 }
    var lines = String(decoding: data[from...], as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false)
    if let first = lines.first, first.hasPrefix("===== ") { lines.removeFirst() }
    return lines
}

let stepLine = try! NSRegularExpression(pattern: "^\\[([0-9]{1,2})/([0-9]{1,2})\\] (.*)$")

func step(in line: Substring) -> (Int, Int, String)? {
    let s = String(line) as NSString
    guard let m = stepLine.firstMatch(in: s as String, range: NSRange(location: 0, length: s.length)),
          let n = Int(s.substring(with: m.range(at: 1))),
          let of = Int(s.substring(with: m.range(at: 2))) else { return nil }
    guard of >= 1, n <= of else { return nil }
    return (n, of, s.substring(with: m.range(at: 3)))
}

// What the log says now. A line that starts "ERROR:" is the launcher's `die`. Otherwise the last step
// line counts, and nothing after a step whose n equals its N: the game's own output follows that line
// in the same log, and it may hold anything.
func reading(ofLog path: String) -> Reading {
    var last = Reading.none
    for line in sessionLines(ofLog: path) {
        if line.hasPrefix("ERROR:") { return .error }
        guard let (n, of, text) = step(in: line) else { continue }
        last = .step(n, of, text)
        if n == of { break }
    }
    return last
}

// Whether the window stays up. It ends by what the log says, with no process matching. The limits:
// `die` has shown its own alert; 5 s after the final step the game's window is on its way; the longest
// designed silence is the Surviving Mars cloud sync, 5 minutes, so 15 without a line means the launcher
// is stuck or gone; a game update is allowed 60 minutes and can run a little past that, so 90 in all;
// and a window whose shim has gone has nothing left to report.
func staysUp(_ r: Reading, sinceGrew: Double, sinceFinal: Double, sinceStart: Double, parentIsStarter: Bool) -> Bool {
    if case .error = r { return false }
    if sinceFinal >= 5 { return false }
    if sinceGrew >= 900 { return false }
    if sinceStart >= 5400 { return false }
    if !parentIsStarter { return false }
    return true
}

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: launch-progress --parse <log> | --decide <log> <since grew> <since final, or -1> <since start> <parent 1|0>\n       the window: LP_TITLE and LP_LOG in the environment, no arguments\n".utf8))
    exit(2)
}

let args = CommandLine.arguments
if args.count > 1 {
    if args.count == 3, args[1] == "--parse" {
        switch reading(ofLog: args[2]) {
        case .none: print("0 0")
        case .error: print("error")
        case .step(let n, let of, let text): print("\(n) \(of) \(text)")
        }
        exit(0)
    }
    if args.count == 7, args[1] == "--decide",
       let grew = Double(args[3]), let final = Double(args[4]), let start = Double(args[5]),
       args[6] == "1" || args[6] == "0" {
        let up = staysUp(reading(ofLog: args[2]), sinceGrew: grew, sinceFinal: final, sinceStart: start,
                         parentIsStarter: args[6] == "1")
        print(up ? "show" : "close")
        exit(0)
    }
    usage()
}

let env = ProcessInfo.processInfo.environment
guard let gameTitle = env["LP_TITLE"], !gameTitle.isEmpty, let logPath = env["LP_LOG"], !logPath.isEmpty else { usage() }

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon, no focus theft

let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 96),
                   styleMask: [.titled, .closable], backing: .buffered, defer: false)
win.title = gameTitle
win.level = .floating
win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
win.isReleasedWhenClosed = false
if let screen = NSScreen.main {
    let f = screen.visibleFrame
    win.setFrameOrigin(NSPoint(x: f.maxX - 424, y: f.maxY - 120))
}
let heading = NSTextField(labelWithString: "\(gameTitle) is starting")
heading.font = NSFont.boldSystemFont(ofSize: 13)
heading.lineBreakMode = .byTruncatingTail
heading.frame = NSRect(x: 16, y: 66, width: 368, height: 18)
let status = NSTextField(labelWithString: "Getting ready…")
status.font = NSFont.systemFont(ofSize: 12)
status.textColor = .secondaryLabelColor
status.lineBreakMode = .byTruncatingTail
status.frame = NSRect(x: 16, y: 44, width: 368, height: 17)
let bar = NSProgressIndicator(frame: NSRect(x: 16, y: 16, width: 368, height: 16))
bar.isIndeterminate = false
bar.minValue = 0
bar.maxValue = 5
win.contentView!.addSubview(heading)
win.contentView!.addSubview(status)
win.contentView!.addSubview(bar)
win.orderFrontRegardless()

func logSize() -> UInt64 {
    ((try? FileManager.default.attributesOfItem(atPath: logPath))?[.size] as? NSNumber)?.uint64Value ?? 0
}
let starter = getppid()   // the shim; once it is gone this process belongs to launchd
let started = Date()
var lastSize = logSize()
var lastGrew = started
var finalAt: Date? = nil
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    let now = Date()
    let size = logSize()
    if size != lastSize { lastSize = size; lastGrew = now }
    let r = reading(ofLog: logPath)
    if case .step(let n, let of, let text) = r {
        // "step 4 of 5", not a bar at 80 per cent alone: step 4 can be a game update of many minutes
        heading.stringValue = n >= 1 ? "\(gameTitle) is starting: step \(n) of \(of)" : "\(gameTitle) is starting"
        bar.maxValue = Double(of)
        bar.doubleValue = Double(n)
        if status.stringValue != text {
            status.stringValue = text
            NSAccessibility.post(element: win, notification: .announcementRequested,
                                 userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
        if n == of && finalAt == nil { finalAt = now }
    }
    let up = staysUp(r, sinceGrew: now.timeIntervalSince(lastGrew),
                     sinceFinal: finalAt.map { now.timeIntervalSince($0) } ?? -1,
                     sinceStart: now.timeIntervalSince(started), parentIsStarter: getppid() == starter)
    if !up || !win.isVisible { app.terminate(nil) }   // not visible: the player closed it by its button
}
app.run()
