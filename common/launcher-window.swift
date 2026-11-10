// launcher-window.swift -- 14unch3r: one window that lists this project's games and starts the one chosen.
// common/make-launcher-app.sh compiles it into 14unch3r.app/Contents/MacOS/launcher-window. A row is an app
// whose Info.plist carries L1Role: each game's own app and the Steam app, as their builders write them. A
// start opens that app with /usr/bin/open, as a double-click does, and the window quits: the app keeps its
// own process tree, consent records and progress window. Plan: docs/plans/launcher-window.md, 2.2 and 2.5.
//
//   launcher-window [--games <tsv>] [<folder>...]           the window; with no folder, those of --folders
//   launcher-window --list [--games <tsv>] <folder>...      one line per row: role, app id or -, state,
//                                                           title, path; tab-separated, no headings
//   launcher-window --default <last app id or -> <folder>... the path of the row selected at open, or nothing
//   launcher-window --second <app path> <folder>...         go, or ask<TAB><title of the game in use>
//   launcher-window --start <app path> [new]                started, or failed<TAB><sentence>; exit 0 or 1
//   launcher-window --owned <app id> <packageinfo.vdf>...   (step B5)
//   launcher-window --folders                               the folders the window reads, one per line
//   launcher-window --icon <out.png>                        (step B6)
// Every mode but the window prints and returns before any window object is made, and the window calls the
// same functions. Any other use prints a usage line and exits 2. Tests: common/test-launcher-window.sh.
//
// The list is not a boundary of trust: whoever can put an app into ~/Applications can also edit the
// unsigned shims already there, and a start goes through LaunchServices as a double-click does.
import AppKit
import UniformTypeIdentifiers

enum Role: String { case game, steam, offer }
enum State: String { case busy, absent, ready, unknown, owned }

struct Row {
    let role: Role
    let appID: Int?       // a game's Steam app id: its key (D3). The title is a label
    var title: String     // as shown: with the file name too when two rows share a title
    let sortTitle: String
    let path: String      // the app as it was reached, or an offer's guide address
    let key: String       // the resolved path: one app reached twice is one row
    let prefix: String?
    var state: State
}

let fm = FileManager.default
let steamDir = "/drive_c/Program Files (x86)/Steam"

func realPath(_ p: String) -> String? {
    guard let r = realpath(p, nil) else { return nil }
    defer { free(r) }
    return String(cString: r)
}

// A folder or app path as given, made absolute, with no trailing slash. Not standardizingPath: that drops
// a leading /private, and one app reached through /tmp and /private/tmp must still be told apart by the
// resolved path, not by a cleaned-up spelling.
func absolute(_ p: String) -> String {
    var s = p
    while s.count > 1 && s.hasSuffix("/") { s.removeLast() }
    return s.hasPrefix("/") ? s : fm.currentDirectoryPath + "/" + s
}

// The bytes of a plain file, read from the opened file: nil for a symlink, a folder, a FIFO (O_NONBLOCK, so
// that one cannot hold the open), a file of more than `limit` bytes, or a failed read.
func readPlainFile(_ path: String, limit: Int) -> Data? {
    let fd = open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
    guard fd >= 0 else { return nil }
    defer { close(fd) }
    var st = stat()
    guard fstat(fd, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG else { return nil }
    var data = Data()
    var buf = [UInt8](repeating: 0, count: 65536)
    while data.count <= limit {
        let n = read(fd, &buf, min(buf.count, limit + 1 - data.count))
        if n < 0 && errno == EINTR { continue }
        if n < 0 { return nil }
        if n == 0 { return data }
        data.append(buf, count: n)
    }
    return nil
}

func lastID(_ s: String) -> Int? {   // a decimal app id from 1 to 2147483647, else none
    guard !s.isEmpty, s.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }), let n = Int(s), n >= 1, n <= 2147483647 else { return nil }
    return n
}

// A plist integer from 1 to 2147483647. Swift's `as? Int` would take <true/> as 1 and <real>5</real> as 5.
func appID(_ v: Any?) -> Int? {
    guard let n = v as? NSNumber else { return nil }
    if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
    if CFNumberIsFloatType(n) { return nil }
    let i = n.int64Value
    return i >= 1 && i <= 2147483647 ? Int(i) : nil
}

func text(_ v: Any?) -> String? {
    guard let s = v as? String, !s.isEmpty else { return nil }
    return s
}

// A tab or a line break becomes a space, so that a title is one field of one line.
func oneLine(_ s: String) -> String { String(s.map { $0 == "\t" || $0.isNewline ? " " : $0 }) }

func title(of d: [String: Any], file: String) -> String {
    let base = String(file.dropLast(4))
    let raw = text(d["CFBundleDisplayName"]) ?? text(d["CFBundleName"]) ?? base
    return oneLine(raw)
}

func hasControl(_ s: String) -> Bool {
    s.contains(where: { $0.isNewline }) || s.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
}

// A row: a direct child whose name ends .app in any case, a folder and not a symlink, whose
// Contents/Info.plist is a plain file of at most 1 MiB that parses and says L1Role game or steam; a game
// also needs L1SteamAppID as a whole number. A name holding a control character is passed over: no
// builder writes one (plan 2.1), and it would break the lines of --list.
func row(_ folder: String, _ name: String) -> Row? {
    guard name.lowercased().hasSuffix(".app"), !hasControl(name) else { return nil }
    let path = (folder == "/" ? "" : folder) + "/" + name
    var st = stat()
    guard lstat(path, &st) == 0, (st.st_mode & S_IFMT) == S_IFDIR else { return nil }
    guard let data = readPlainFile(path + "/Contents/Info.plist", limit: 1_048_576) else { return nil }
    guard let d = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return nil }
    let roleText = d["L1Role"] as? String
    guard roleText == "game" || roleText == "steam" else { return nil }
    let role: Role = roleText == "steam" ? .steam : .game
    var id: Int? = nil
    if role == .game {
        guard let n = appID(d["L1SteamAppID"]) else { return nil }
        id = n
    }
    var prefix: String? = nil
    if let p = d["L1Prefix"] as? String, p.hasPrefix("/"), p.hasSuffix("/Contents/SharedSupport/prefix") { prefix = p }
    let t = title(of: d, file: name)
    let key = realPath(path) ?? path
    return Row(role: role, appID: id, title: t, sortTitle: t, path: path, key: key, prefix: prefix, state: .unknown)
}

// A launcher holds <prefix>/.launcher.lock, a symlink whose target is its process number, from its start
// until it exits. Alive is the launchers' own rule: a kill that succeeds, so a number that now belongs to
// another user's process is not alive. 0 and 1 are never a launcher (kill(0, 0) asks about this process's
// own group), and a target that is not digits only is none (Int32("+7") is 7).
func lockHeldByLiveProcess(_ prefix: String) -> Bool {
    let lock = prefix + "/.launcher.lock"
    var st = stat()
    guard lstat(lock, &st) == 0, (st.st_mode & S_IFMT) == S_IFLNK else { return false }
    guard let t = try? fm.destinationOfSymbolicLink(atPath: lock) else { return false }
    guard !t.isEmpty, t.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) else { return false }
    guard let pid = Int32(t), pid >= 2, pid <= 99999 else { return false }
    return kill(pid, 0) == 0
}

// From files alone, with no process matching. A Steam app is never busy: nothing locks the store wrapper.
func state(of r: Row) -> State {
    guard let p = r.prefix else { return .unknown }
    let marker = r.role == .steam ? p + steamDir + "/steam.exe" : p + steamDir + "/steamapps/appmanifest_\(r.appID ?? 0).acf"
    if r.role == .game, lockHeldByLiveProcess(p) { return .busy }
    return fm.fileExists(atPath: marker) ? .ready : .absent
}

func secondLine(_ r: Row) -> String {
    switch (r.state, r.role) {
    case (_, .offer): return "Not set up on this Mac. Opens the set-up guide."
    case (.busy, _): return "In use: starting, running or closing"
    case (.absent, .steam): return "Windows Steam not found. Build this app again."
    case (.absent, _): return "Game files not found. See its set-up guide."
    case (.ready, .steam): return "Steam for Windows, run under Wine"
    default: return ""
    }
}

func rank(_ r: Role) -> Int { r == .game ? 0 : r == .steam ? 1 : 2 }

// Games, then Steam apps, then offers; each group by title without regard to case, then by path.
func ordered(_ rows: [Row]) -> [Row] {
    rows.sorted { a, b in
        if rank(a.role) != rank(b.role) { return rank(a.role) < rank(b.role) }
        let c = a.sortTitle.caseInsensitiveCompare(b.sortTitle)
        if c != .orderedSame { return c == .orderedAscending }
        return a.path < b.path
    }
}

// Rows with the same title, without regard to case, also show their file name.
func titled(_ rows: [Row]) -> [Row] {
    var count: [String: Int] = [:]
    for r in rows { count[r.sortTitle.lowercased(), default: 0] += 1 }
    return rows.map { r in
        guard count[r.sortTitle.lowercased(), default: 0] > 1 else { return r }
        var r = r
        r.title = "\(r.sortTitle) (\((r.path as NSString).lastPathComponent))"
        return r
    }
}

// Every row in the folders, states read now. A folder given twice, or the same folder by two spellings,
// adds nothing the second time: the first spelling of an app is the one kept.
func rows(in folders: [String]) -> [Row] {
    var seen = Set<String>(), found: [Row] = []
    for f in folders.map(absolute) {
        guard let names = try? fm.contentsOfDirectory(atPath: f) else { continue }
        for name in names.sorted() {
            guard var r = row(f, name), !seen.contains(r.key) else { continue }
            seen.insert(r.key)
            r.state = state(of: r)
            found.append(r)
        }
    }
    return ordered(titled(found))
}

// The row selected when the window opens: the game recorded last if it is listed (the first by path if two
// apps share it), else the first game, else the first row of any kind.
func defaultRow(_ rows: [Row], last: Int?) -> Row? {
    if let id = last, let r = rows.filter({ $0.role == .game && $0.appID == id }).min(by: { $0.path < $1.path }) { return r }
    return rows.first(where: { $0.role == .game }) ?? rows.first
}

func samePrefix(_ a: String?, _ b: String?) -> Bool {
    guard let a = a, let b = b else { return false }
    return a == b || (realPath(a) != nil && realPath(a) == realPath(b))
}

// One game at a time (D6): the game in use whose Steam a start of `chosen` would take offline, the first by
// the list's order, or nil to start without asking. A row with the busy row's own prefix shares its
// launcher, and an offer starts no Steam; a chosen row with no prefix could be any game, so it is asked.
func blocker(_ chosen: Row, _ rows: [Row]) -> Row? {
    guard chosen.role == .game || chosen.role == .steam else { return nil }
    let busy = rows.filter { $0.role == .game && $0.state == .busy && !samePrefix($0.prefix, chosen.prefix) }
    return busy.first
}

func openArguments(_ target: String, new: Bool) -> [String] { new ? ["-n", target] : [target] }

// /usr/bin/open, as a double-click does, the target one argument and no shell, waited for: it returns at
// once, and the app keeps starting after this program exits. -n for a row in use: a plain open of a script
// app that is still alive starts nothing. NSWorkspace.openApplication does not fit: for a script app its
// handler runs when the script ends. Nil when open exited 0, else its sentence.
func start(_ target: String, new: Bool) -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = openArguments(target, new: new)
    let err = Pipe()
    p.standardError = err
    p.standardOutput = FileHandle.nullDevice
    p.standardInput = FileHandle.nullDevice
    do { try p.run() } catch { return oneLine(error.localizedDescription) }
    let said = err.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    if p.terminationReason == .exit && p.terminationStatus == 0 { return nil }
    let s = oneLine(String(decoding: said, as: UTF8.self)).trimmingCharacters(in: .whitespaces)
    return s.isEmpty ? "open ended with status \(p.terminationStatus)." : s
}

// ~/Applications, with $HOME when it is set (NSHomeDirectory() ignores it), and the folder that holds this
// program's own app when it runs from inside one. Not /Applications: no builder writes there by default.
func ownBundle() -> String? {
    guard let exe = Bundle.main.executablePath.flatMap(realPath) else { return nil }
    let macos = (exe as NSString).deletingLastPathComponent
    let contents = (macos as NSString).deletingLastPathComponent
    let app = (contents as NSString).deletingLastPathComponent
    guard (macos as NSString).lastPathComponent == "MacOS", (contents as NSString).lastPathComponent == "Contents",
          app.lowercased().hasSuffix(".app") else { return nil }
    return app
}

func windowFolders() -> [String] {
    let env = ProcessInfo.processInfo.environment["HOME"] ?? ""
    let home = absolute(env.isEmpty ? NSHomeDirectory() : env)
    var all = [(home == "/" ? "" : home) + "/Applications"]
    if let b = ownBundle() { all.append((b as NSString).deletingLastPathComponent) }
    var out: [String] = [], seen = Set<String>()
    for f in all where seen.insert(realPath(f) ?? f).inserted { out.append(f) }
    return out
}

func usage() -> Never {
    FileHandle.standardError.write(Data("""
    usage: launcher-window [--games <tsv>] [<folder>...]          the window
           launcher-window --list [--games <tsv>] <folder>...
           launcher-window --default <last app id or -> <folder>...
           launcher-window --second <app path> <folder>...
           launcher-window --start <app path> [new]
           launcher-window --owned <app id> <packageinfo.vdf>...
           launcher-window --folders
           launcher-window --icon <out.png>

    """.utf8))
    exit(2)
}

func notBuilt(_ mode: String, _ step: String) -> Never {
    FileHandle.standardError.write(Data("launcher-window: \(mode) is not built yet (step \(step))\n".utf8))
    exit(2)
}

// -psn_ is what older systems added when Finder started an app.
let args = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-psn_") }

// `[--games <tsv>] rest`: the table of ported games, and what follows it
func gamesOption(_ a: [String]) -> (String?, [String]) {
    guard a.first == "--games" else { return (nil, a) }
    guard a.count >= 2 else { usage() }
    return (a[1], Array(a.dropFirst(2)))
}

if let mode = args.first, mode.hasPrefix("-"), mode != "--games" {
    let rest = Array(args.dropFirst())
    switch mode {
    case "--list":
        let (_, folders) = gamesOption(rest)   // offers: step B5
        guard !folders.isEmpty else { usage() }
        for r in rows(in: folders) {
            print([r.role.rawValue, r.appID.map(String.init) ?? "-", r.state.rawValue, r.title, r.path].joined(separator: "\t"))
        }
    case "--default":
        guard rest.count >= 2 else { usage() }
        if let r = defaultRow(rows(in: Array(rest.dropFirst())), last: lastID(rest[0])) { print(r.path) }
    case "--second":
        guard rest.count >= 2 else { usage() }
        let list = rows(in: Array(rest.dropFirst()))
        let k = realPath(absolute(rest[0])) ?? absolute(rest[0])
        if let c = list.first(where: { $0.key == k }), let b = blocker(c, list) { print("ask\t\(b.title)") } else { print("go") }
    case "--start":
        guard rest.count == 1 || (rest.count == 2 && rest[1] == "new"), !rest[0].isEmpty else { usage() }
        if let why = start(rest[0], new: rest.count == 2) { print("failed\t\(why)"); exit(1) }
        print("started")
    case "--folders":
        guard rest.isEmpty else { usage() }
        for f in windowFolders() { print(f) }
    case "--owned":
        notBuilt(mode, "B5")
    case "--icon":
        guard rest.count == 1 else { usage() }
        notBuilt(mode, "B6")
    default:
        usage()
    }
    exit(0)
}

// ---------------------------------------------------------------------------------------------- the window
let (gamesGiven, foldersGiven) = gamesOption(Array(args))
guard !foldersGiven.contains(where: { $0.hasPrefix("-") }) else { usage() }
let readFrom = foldersGiven.isEmpty ? windowFolders() : foldersGiven
let gamesTable = gamesGiven ?? ownBundle().map { $0 + "/Contents/Resources/games.tsv" }   // offers: step B5
let readmeAddress = "https://github.com/macgameport/1launcher/blob/main/README.md"
let windowWidth: CGFloat = 420, itemHeight: CGFloat = 52, headingHeight: CGFloat = 26, barHeight: CGFloat = 56

final class LauncherWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { NSApp.terminate(nil) }
}

// One row of the table: the app's icon at 32 points, its title at 13 points semibold, and the second line
// at 11 points in the label colour (the secondary one measured 3.95 to 1 in light mode). One element for
// VoiceOver: "<title>, <second line>".
final class ItemCell: NSTableCellView {
    init(_ r: Row) {
        super.init(frame: NSRect(x: 0, y: 0, width: windowWidth, height: itemHeight))
        let icon = NSImageView(frame: NSRect(x: 8, y: 10, width: 32, height: 32))
        let image = r.role == .offer ? NSWorkspace.shared.icon(for: .applicationBundle) : NSWorkspace.shared.icon(forFile: r.path)
        image.size = NSSize(width: 32, height: 32)
        icon.image = image
        icon.setAccessibilityElement(false)
        addSubview(icon)
        let second = secondLine(r)
        let name = NSTextField(labelWithString: r.title)
        name.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        name.textColor = .labelColor
        name.lineBreakMode = .byTruncatingTail
        name.frame = NSRect(x: 48, y: second.isEmpty ? 17 : 26, width: windowWidth - 72, height: 18)
        name.autoresizingMask = [.width]
        name.setAccessibilityElement(false)
        addSubview(name)
        if !second.isEmpty {
            let line = NSTextField(labelWithString: second)
            line.font = NSFont.systemFont(ofSize: 11)
            line.textColor = .labelColor
            line.lineBreakMode = .byTruncatingTail
            line.frame = NSRect(x: 48, y: 9, width: windowWidth - 72, height: 15)
            line.autoresizingMask = [.width]
            line.setAccessibilityElement(false)
            addSubview(line)
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.cell)
        setAccessibilityLabel(r.role == .offer ? "\(r.title), not set up on this Mac, opens the set-up guide in your browser"
                                              : second.isEmpty ? r.title : "\(r.title), \(second)")
    }
    required init?(coder: NSCoder) { fatalError() }
}

@MainActor
final class Launcher: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    enum Line { case heading(String), item(Row) }
    enum Sheet { case none, question(NSWindow), failure(NSWindow) }
    var lines: [Line] = []
    var appRows: [Row] = []
    var offers: [Row] = []
    var sheet = Sheet.none
    var starting = false
    var opened = false
    let window = LauncherWindow(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: 300),
                                styleMask: [.titled, .closable], backing: .buffered, defer: false)
    let table = NSTableView()
    let scroll = NSScrollView()
    let button = NSButton(title: "Play", target: nil, action: nil)
    let empty = NSView()
    let none = NSTextField(labelWithString: "No games are set up on this Mac yet.")
    let address = NSTextField(labelWithString: readmeAddress)

    func applicationDidFinishLaunching(_ n: Notification) {
        let menu = NSMenu(), item = NSMenuItem(), appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit 14unch3r", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu
        menu.addItem(item)
        NSApp.mainMenu = menu

        window.title = "14unch3r"
        window.setAccessibilityTitle("14unch3r game launcher")
        window.isReleasedWhenClosed = false
        window.delegate = self
        let content = window.contentView!

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("row"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        table.headerView = nil
        table.style = .inset
        table.allowsEmptySelection = false
        table.allowsMultipleSelection = false
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(startChosen(_:))
        table.setAccessibilityLabel("Games")
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autoresizingMask = [.width, .height]
        content.addSubview(scroll)

        none.font = NSFont.systemFont(ofSize: 13)
        none.textColor = .labelColor
        none.alignment = .center
        address.font = NSFont.systemFont(ofSize: 11)
        address.textColor = .labelColor
        address.alignment = .center
        address.isSelectable = true
        empty.addSubview(none)
        empty.addSubview(address)
        empty.autoresizingMask = [.width, .height]
        content.addSubview(empty)

        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.target = self
        button.action = #selector(startChosen(_:))
        button.frame = NSRect(x: windowWidth - 20 - 130, y: 14, width: 130, height: 28)
        button.autoresizingMask = [.minXMargin, .maxYMargin]
        content.addSubview(button)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [unowned self] e in
            guard e.keyCode == 53 else { return e }   // Escape
            switch self.sheet {
            case .none: NSApp.terminate(nil)
            case .question(let w), .failure(let w): self.window.endSheet(w, returnCode: .alertFirstButtonReturn)
            }
            return nil
        }

        reload()
        window.center()
        window.initialFirstResponder = table
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(table)
        if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        opened = true
    }

    func applicationDidBecomeActive(_ n: Notification) { if opened && !starting { reload() } }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        return false
    }

    var chosen: Row? {
        let i = table.selectedRow
        guard i >= 0, i < lines.count, case .item(let r) = lines[i] else { return nil }
        return r
    }

    // States are read when the window opens, each time it becomes the active app, and just before a start.
    // The selection stays on the same app when it is still listed.
    func reload() {
        let keep = chosen?.key
        appRows = rows(in: readFrom)
        let have = Set(appRows.compactMap { $0.role == .game ? $0.appID : nil })
        let all = appRows + offers.filter { !have.contains($0.appID ?? 0) }
        lines = []
        for (role, heading) in [(Role.game, "Games"), (.steam, "Steam"), (.offer, "You also own")] {
            let group = all.filter { $0.role == role }
            if group.isEmpty { continue }
            lines.append(.heading(heading))
            lines += group.map { .item($0) }
        }
        table.reloadData()
        var pick = lines.firstIndex { if case .item(let r) = $0 { return r.key == keep } else { return false } }
        if pick == nil, let d = defaultRow(appRows, last: appID(UserDefaults.standard.object(forKey: "lastAppID"))) {
            pick = lines.firstIndex { if case .item(let r) = $0 { return r.key == d.key } else { return false } }
        }
        if let i = pick {
            table.selectRowIndexes(IndexSet(integer: i), byExtendingSelection: false)
            table.scrollRowToVisible(i)
        }
        empty.isHidden = !lines.isEmpty
        scroll.isHidden = lines.isEmpty
        fit()
        updateButton()
    }

    // The window's height follows the list, up to a point; its top edge stays where it was.
    func fit() {
        let listHeight = lines.reduce(CGFloat(12)) { h, l in
            if case .heading = l { return h + headingHeight + 2 } else { return h + itemHeight + 2 }
        }
        let h = min(max(listHeight, 130), 470)
        let frame = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: windowWidth, height: h + barHeight))
        var f = window.frame
        f.origin.y += f.height - frame.height
        f.size = frame.size
        window.setFrame(f, display: true, animate: false)
        let content = window.contentView!.bounds
        scroll.frame = NSRect(x: 0, y: barHeight, width: content.width, height: content.height - barHeight)
        table.sizeLastColumnToFit()
        empty.frame = scroll.frame
        let middle = (scroll.frame.height / 2).rounded()
        none.frame = NSRect(x: 16, y: middle + 2, width: content.width - 32, height: 18)
        address.frame = NSRect(x: 16, y: middle - 20, width: content.width - 32, height: 16)
    }

    func updateButton() {
        let r = chosen
        button.title = r?.role == .steam ? "Open Steam" : r?.role == .offer ? "Open Guide" : "Play"
        button.isEnabled = r != nil && !starting
    }

    @objc func startChosen(_ sender: Any?) {
        guard !starting, case .none = sheet else { return }
        if (sender as? NSTableView) === table && table.clickedRow != table.selectedRow { return }
        guard let picked = chosen else { return }
        if picked.role == .offer { launch(picked, new: false); return }
        reload()
        guard let r = appRows.first(where: { $0.key == picked.key }) else { NSSound.beep(); return }
        if let b = blocker(r, appRows) { ask(about: b, starting: r) } else { launch(r, new: r.state == .busy) }
    }

    func ask(about b: Row, starting r: Row) {
        let a = NSAlert()
        a.alertStyle = .warning
        a.messageText = "\(b.title) is still in use."
        a.informativeText = "Starting \(r.title) now takes \(b.title)'s Steam offline. \(b.title) can keep running, but saves it has not uploaded yet stay on this Mac and do not reach Steam Cloud."
        a.addButton(withTitle: "Don't Start")   // the first button is the default: Return, and Escape too (the monitor)
        a.addButton(withTitle: "Start Anyway")
        sheet = .question(a.window)
        a.beginSheetModal(for: window) { answer in
            self.sheet = .none
            guard answer == .alertSecondButtonReturn else { return }
            self.reload()
            let now = self.appRows.first(where: { $0.key == r.key }) ?? r
            self.launch(now, new: now.state == .busy)
        }
    }

    func launch(_ r: Row, new: Bool) {
        starting = true
        updateButton()
        DispatchQueue.global(qos: .userInitiated).async {
            let why = start(r.path, new: new)
            DispatchQueue.main.async {
                self.starting = false
                if let why = why { self.failed(r, why); self.updateButton(); return }
                if r.role == .offer { self.updateButton(); return }   // the guide is in the browser; the list stays
                if r.role == .game, let id = r.appID {
                    UserDefaults.standard.set(id, forKey: "lastAppID")
                    UserDefaults.standard.synchronize()
                }
                NSApp.terminate(nil)
            }
        }
    }

    func failed(_ r: Row, _ why: String) {
        let a = NSAlert()
        a.alertStyle = .warning
        a.messageText = r.role == .offer ? "The set-up guide of \(r.title) did not open." : "\(r.title) did not start."
        a.informativeText = why
        a.addButton(withTitle: "OK")
        sheet = .failure(a.window)
        a.beginSheetModal(for: window) { _ in self.sheet = .none }
    }

    func numberOfRows(in t: NSTableView) -> Int { lines.count }

    func tableView(_ t: NSTableView, isGroupRow i: Int) -> Bool {
        if case .heading = lines[i] { return true } else { return false }
    }

    func tableView(_ t: NSTableView, heightOfRow i: Int) -> CGFloat {
        if case .heading = lines[i] { return headingHeight } else { return itemHeight }
    }

    func tableView(_ t: NSTableView, viewFor c: NSTableColumn?, row i: Int) -> NSView? {
        switch lines[i] {
        case .heading(let s):
            let cell = NSTableCellView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: headingHeight))
            let f = NSTextField(labelWithString: s)
            f.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            f.textColor = .labelColor
            f.frame = NSRect(x: 8, y: 4, width: windowWidth - 32, height: 15)
            f.autoresizingMask = [.width]
            cell.addSubview(f)
            cell.textField = f
            return cell
        case .item(let r):
            return ItemCell(r)
        }
    }

    // Headings cannot be selected. An arrow key that lands on one goes on to the next row in its direction;
    // a click on one changes nothing.
    func tableView(_ t: NSTableView, selectionIndexesForProposedSelection p: IndexSet) -> IndexSet {
        guard let i = p.first, case .heading = lines[i] else { return p }
        let current = t.selectedRow >= 0 ? IndexSet(integer: t.selectedRow) : IndexSet()
        guard NSApp.currentEvent?.type == .keyDown else { return current }
        let step = i > t.selectedRow ? 1 : -1
        var j = i
        while j >= 0 && j < lines.count {
            if case .item = lines[j] { return IndexSet(integer: j) }
            j += step
        }
        return current
    }

    func tableViewSelectionDidChange(_ n: Notification) { updateButton() }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let launcher = Launcher()
    app.delegate = launcher
    app.run()
}
