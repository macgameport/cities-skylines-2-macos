# 14unch3r: desktop icons over a dark background, and the mark

> **Status:** Triple-checked 2026-11-10 — build-ready-with-fixes, corrections folded. Pass 1 was three
> lenses; pass 1b was a fourth agent checking the fold, and its findings are folded too. Eight decisions
> James made the same day are in section 9. Written 2026-11-10.
> **🔧 As-built (2026-11-10):** PARTIAL: B8 to B12 built on branch `launcher-look` (`17dd03a` and `7ac2482`) and
> merged as `64c06f1`. L1 done the same day on James's word: no launcher, Wine or Steam ran and no launcher lock
> was held; `make-launcher-app.sh` exit 0; `--grid - ~/Applications` gave two games and one Steam tile at 444 by
> 172, the pill `#0059D1` at 6.27, the lowest title, second-line and outline ratios 9.62, 9.79 and 5.06 (3.58 on
> the plate); the packed icon holds the small form at 16 and 32 pixels. L2 done the same day, on stand-in apps
> (a busy game, a ready one, one with no program, a game and a Windows Steam not installed, an offer): in the
> captures the names measured 10.20 to 1 at worst, the status lines 8.34 and the pill 6.21; with the system in
> light mode the window and the question were the same dark window (no pixel off by more than 24 of 255);
> "Don't Start" wrote nothing, a failed start kept the window, "Start Anyway" started the stand-in and quit;
> the empty window and the 16-pixel icon as designed. James did the rest and said "everything checked out":
> the pointer, the keys, the yellow accent, VoiceOver, Finder and the Dock. He kept the outline, the hover
> plate and the pointing hand (D16, D25). Captures in `~/cs2-patch/evidence/`. L3 done the same day: James ran
> `setup.sh` twice in Terminal, answered `y`, and macOS asked nothing about the Desktop folder; one alias of 904
> bytes, which `--alias` reads as `have`, was made at the first run and not rewritten by the second, which did not
> ask; no name ending " 2" a few minutes later. The two game aliases left the Desktop 37 seconds after, through a
> Finder Move to Trash by James himself ("i moved the shortcuts"), not through setup, which never calls Finder. Put back, they
> were byte-identical to their fingerprints from before setup, and all three aliases read Kind "Alias", type `fapa`,
> and grouped together. L4 and L5 are still to come. Tests:
> `test-launcher-window.sh` 166 cases, its 40 new mutants (31 to 70) each seen red and restored;
> `test-make-launcher-app.sh` 27, mutant 8 new; `test-setup.sh` 77, mutants 9 to 16 new; every other suite of
> the parent's section 6 and `test-launcher-builders.sh` (W19) unchanged and green; `check-identifiers.sh`
> and `check-links.py` exit 0; the source compiles with warnings as errors. The window was not opened for a
> look because a game was running on the Studio: an offscreen render of the real views, from the same code,
> showed the grid, the selection with its outline, a hovered tile and the grey tiles. Deviations: (1) that
> render found grey icons drawn at half size, since a bitmap's own context counts in pixels; fixed, and
> recorded in `cities-skylines-2/GOTCHAS.md`, since `--grid` reports `dim` but no pixel of it. (2) With the
> offers block centred, Up from a lone offer goes to the tile nearest above it in x, which is no longer the
> first game; W15's case says so. (3) Setup's Desktop step is a function, `desktop_step`, called after the
> problems exit, so that W18's mutant "run before the problems exit" is one line; `scrollOffset` never
> returns less than 0, and `fit()` scrolls the clip view to the grid's offset again after a resize. Verify
> against: `common/launcher-window.swift`, `common/make-launcher-app.sh`, `cities-skylines-2/scripts/setup.sh`,
> their three tests, `docs/images/14unch3r.svg`.
> Tracking: issue #22. A follow-on to `docs/plans/launcher-window.md` ("the parent"), whose step numbers,
> test numbers and decisions this plan continues: B8 to B12, W13 to W19, D12 to D25. File and line
> references are as of `f1afa88`. A path is relative to the repository root. Every number marked
> "measured" was measured on the Studio on 2026-11-10 (macOS 27.2) with throwaway programs under `/tmp`
> that drew offscreen and exited; none of them is in the repository.

## 0. What James asked for (2026-11-10)

| # | His words | What this plan does with it |
|---|---|---|
| K1 | "Can we change the orientation and font sizes to make them look more like desktop icons in the popup window. maybe add a cool background with the 14 logo" | The table becomes a grid of tiles: a 64-point icon with the name centred under it (2.1 to 2.4) |
| K2 | "Like maybe a one and a backwards for that creates an upward arrow inside a circle", with a pen sketch | The mark of 2.5 |
| K3 | Of three mockups: "very cool, third iteration looks awesome" | The third is the look: the mark large, faint, white and centred behind the tiles |
| K4 | The app icon becomes the mark, white on the graphite rounded square | 2.6; it replaces the drawn "14" (parent 2.6, D8) |
| K5 | "let's go ahead and place that on the deskop with the install script (we can ask if the user wants a desktop shortcut during isntall)" | `setup.sh` offers one alias on the Desktop (2.9) |
| K6 | "can we also add the logo to the github page" | The root `README.md` shows the mark, from one generated SVG (2.8) |
| K7 | "if a game is owned but not installed on steam can the icon be grayed out noting need to install?" | A tile that cannot start is drawn grey and says why in a few words: a game not installed, a missing Windows Steam, an offer (2.4) |
| K8 | "we can also include the icon when we post on reddit" | `--icon` writes the PNG (2.8). Posting is James's |

Already built in `f1afa88` and kept: one click starts a row, Return and Enter start the selection, no
button (parent as-built deviation 8).

## 1. What is true today (read or measured)

- The window is an `NSTableView` in a scroll view: `ItemCell` (`common/launcher-window.swift:572-606`),
  `Launcher` (`:609-866`), `reload()` (`:725-749`), `fit()` (`:754-769`), 420 points wide (`:563`).
- `startChosen` (`:771-779`) refuses while `starting` or while a sheet is up (`:772`), and takes a click
  only when `clickedRow == selectedRow` (`:773`). The key monitor (`:671-683`) maps Return, Enter and
  Escape. `ask` (`:781-796`), `launch` (`:798-813`) and `failed` (`:815-823`) are attached alerts.
- `secondLine()` (`:157-166`) gives a row's state in words; `defaultRow` (`:210-213`) picks the row
  selected at open; `drawIcon` (`:489-508`) draws "14" into a bitmap of exactly 1024 by 1024 pixels.
- Every text mode returns before any window object is made (`:520-555`), and the tests run only those
  (`common/test-launcher-window.sh:1-11`). `common/test-make-launcher-app.sh:127-133` checks the icon's
  1024 pixels and the builder's fallback.
- **A view tree works with no window, no `NSApplication` and no run loop** (measured). A command-line
  program built `NSView` subclasses, read their frames, read `accessibilityRole()` (`AXButton`),
  `accessibilityLabel()` and `accessibilityChildren()` (3 of 3), got `true` and the side effect from
  `accessibilityPerformPress()`, made a key event with `NSEvent.keyEvent(with:...)` and passed it to
  `keyDown(with:)` (selection moved twice), drew with `cacheDisplay(in:to:)`, and exited with `NSApp`
  still nil. `NSView.hitTest` on a flipped view with no superview gave the wrong answer, so hit testing
  here is the grid's own function over the tile frames (2.7). `acceptsFirstMouse(for:)` is false by default.
- **The title bar is 32 points** on macOS 27 (measured from `NSWindow.frameRect(forContentRect:styleMask:)`,
  with no window made). It was 28 on older systems, so no test names a height that includes it.
- **Text at 112 points wide** (measured, system font). 12 points semibold: "Cities: Skylines II" 1 line,
  "Surviving Mars: Relaunched" 2 lines of 15, a title with its file name appended 3 or 4 lines. 10.5 points regular, 13
  per line: "In use: starting, running or closing" 2, "Game files not found. See its set-up guide." 2,
  "Steam for Windows, run under Wine" 2, "Windows Steam not found. Build this app again." 3, "Not set up
  on this Mac. Opens the set-up guide." 3, "Windows Steam not found" 2, "Not set up. Opens its guide." 2,
  "Not installed in Steam" 1, "Not installed in Steam. See its set-up guide." 3. One line of 12 points
  semibold cut to fit: at its tail, "Surviving Mars Relaunched.app" and "Surviving Mars Relaunched
  copy.app" both become "Surviving Mars R…"; in the middle they become "Survivin…hed.app" and
  "Survivin…opy.app".
- **Contrast** (measured, WCAG ratio, white text). On `controlAccentColor` in dark mode: 4.02 for blue,
  and 3.18, 2.57, 1.58, 2.43, 3.20 for red, orange, yellow, green and pink. On
  `selectedContentBackgroundColor`: 6.27 for blue (`#0059D1`), but 4.07, 2.44 and 3.86 for orange, yellow
  and green. So neither system colour holds 4.5 for every accent a user can pick. On the background of
  2.3, sampled at every pixel of windows 444 by 188 up to 580 by 600: without the mark, white 8.20 and
  white at alpha 0.88 6.83 at worst; with the mark behind, white 6.80, white at alpha 0.88 5.72, white at
  alpha 0.75 4.68 at worst. The pill `#0059D1` against that background is 1.03 to 1.24: it differs by
  hue, not by lightness. White at alpha 0.75 against the selection plate's own fill is 3.37. A reviewer
  measured the same numbers again at every pixel from 444 by 188 to 580 by 632; `--grid` prints them for
  the sizes the window really takes (section 4).
- **A bookmark alias** (measured in `/tmp`): `URL.bookmarkData(options: .suitableForBookmarkFile)` and
  `URL.writeBookmarkData(_:to:)` wrote an 880-byte file that `file` calls "MacOS Alias file", whose
  `isAliasFile` is true and `isSymbolicLink` false, and that `URL(resolvingAliasFileAt:)` resolved to the
  app. After the app was moved to another folder it resolved to the new place. After the app was deleted
  the resolve threw. A plain file resolves to itself, a symlink reads `isAliasFile` true and
  `isSymbolicLink` true, and a target that does not exist cannot be bookmarked. No AppleEvent is sent.
  `writeBookmarkData` overwrites a file that is already there, so the never-replace rule of 2.9 rests on
  the mode's own test of the path.
- No script in the repository writes to `~/Desktop` (`git grep -i desktop` finds Wine's virtual desktop,
  and `common/mac-inventory.sh:109`, which tests whether the folder can be listed). `setup.sh` asks one question, at a terminal only (`[ -t 0 ]`,
  `cities-skylines-2/scripts/setup.sh:136-138`); `--check` stops at `:135`; the window is built at
  `:217-225`, a run with problems exits 1 at `:227-231`, and the closing lines are at `:233-237`. Its
  options are parsed at `:35-36` and listed in the header that `--help` prints (`:8-12`, `:48`).
- The repository holds no image outside `cities-skylines-2/docs/images/`, whose audit
  (`cities-skylines-2/scripts/check-experiments.py:28-29`) covers that folder only. The root `docs/` holds `plans/` only.
- **The mark as SVG** (measured): the path of 2.8, written by hand from `markPath`'s numbers, passed
  `xmllint --noout`, and drawn through `NSImage` had ink and body at the same eleven points as the bitmap.
- **The mark at 16 and 32 pixels** (measured, `sips` from 1024). The full form at 16: brightest ink 186 of
  255, no pixel at 200 or more, stems and ring a grey blur. With the stroke at 0.085 of a box inset by 60:
  245, and 31 pixels at 200 or more, an arrow in a ring. At 32: 244 and 31 against 255 and 149. Heavier
  strokes (0.10, 0.12) filled the arrowhead.
- **`.fullSizeContentView`** (measured by the builder lens): `frameRect(forContentRect:)` adds nothing
  for that mask (172 stays 172; the plain mask gives 204).
- **A `toolTip` becomes the view's `accessibilityHelp()`** (measured by the design lens), so VoiceOver
  would read it after the label.
- **`script` and a typed answer** (measured): `printf 'y\n' | script -q /dev/null bash -c 'read a'` gives
  the read an end of file and an empty answer; `{ sleep 1; printf 'y\n'; sleep 2; } | script ...`, which
  holds the pipe open, gives it `y`. The existing helper's typed Return
  (`cities-skylines-2/scripts/test-setup.sh:157-161`) is that end of file.
- **B8 to B11 were built once on a scratch tree by the builder lens**: 153 and 73 cases passed and the 30
  mutants then listed went red. That tree is not the build. It showed what this plan had left unsaid,
  which sections 2 and 4 now say.

## 2. Design

### 2.1 The grid

Tiles replace rows. The rows, their order, their states and their titles are the parent's, unchanged.

| Constant | Points |
|---|---|
| Tile | 120 wide, 146 high |
| Icon | 64 by 64, its top 6 below the tile's top, centred |
| Title | starts 9 below the icon; at most 112 wide and 2 lines (30) |
| Second line | starts 4 below the title; at most 112 wide and 2 lines (26) |
| Side margin 24, gap between tiles in a row 8, gap between rows 8 |  |
| Group gap, before the first Steam tile when a game is to its left in the same row | 28 |
| Above the first row 4, below the last row 22 |  |
| Narrowest grid | 444 |

- **Order and wrap.** Games, then Steam apps, laid left to right, 4 to a row. The first Steam tile is set
  apart by the group gap. When it starts a row there is nothing to its left and no gap is added: its second
  line says what it is.
- **Offers** (parent 2.5) start a row of their own below the others, 4 to a row, under a label "You also
  own": 11 points semibold, white at alpha 0.88, 16 high, 8 below the row above it and 4 above its tiles.
  The label stays because a tile with a generic icon and no app behind it needs its reason said. An offer
  is a grey tile (2.4).
- **Two blocks.** The games and Steam tiles are one block and the offers another. Within a block the rows
  share one left edge; each block is centred; the label starts at the offers block's left edge. So when
  the offers arrive late and the window widens about its middle (2.2), no game moves on the screen.
- **Width** is the widest row of either block plus both margins, and at least 444. A row is its tiles,
  the gaps between them, and 20 more when it holds the group gap.
- **Height** is 4, the rows and the gaps between them, the offers block when there is one (8 + 16 + 4 and
  its rows), and 22.
- **Past 600.** When the grid is taller than 600 the window shows 600 of it and the grid scrolls inside a
  scroll view that draws no background; the background and the mark do not move. After every change of
  selection the offset becomes `scrollOffset(for:from:)`: the offset nearest the one before at which the
  selected tile's frame, grown by 4 above and 22 below, is inside the 600. The grid keeps it, the scroll
  view follows it, and `--act` prints it.

| Tiles | Grid size | Tile origins, x from the left and y from the top of the grid |
|---|---|---|
| none | 444 by 172 | the two lines of the empty state, centred |
| 1 game | 444 by 172 | 162, 4 |
| 2 games and Steam | 444 by 172 | 24, 152 and 300; all 4. This is the mockup |
| 3 games and Steam | 572 by 172 | 24, 152, 280 and 428 |
| 4 games and Steam | 552 by 326 | row 2: Steam at 24, 158 |
| 5 games and Steam | 552 by 326 | row 2: 24 and 172, at 158 |
| 8 tiles | 552 by 326 | two full rows, or 572 wide when a row holds the group gap |
| 2 games, Steam, 1 offer | 444 by 346 | label at 162, 158; the offer at 162, 178 |
| 17 games | 552 by 788, shown 600 high | five rows; the last tile at 24, 620 |

### 2.2 Window chrome

`styleMask` is `[.titled, .closable, .fullSizeContentView]`, with `titlebarAppearsTransparent = true` and
`titleVisibility = .hidden`. The background runs under the title bar; the grid starts below it, so no tile
is under the close button and the bar still drags the window. `window.title` stays "14unch3r" and the
accessibility title stays "14unch3r game launcher". `fit()` keeps the top edge and the horizontal middle
when the size changes, as when the offers arrive.

The content's height is the grid's shown height plus the bar's, and the bar's is what
`NSWindow.frameRect(forContentRect:styleMask:)` adds for the plain mask `[.titled, .closable]` (32,
measured). With `.fullSizeContentView` it adds nothing (section 1), so a `fit()` kept from `:757` would
put the first row under the bar.

### 2.3 Appearance and background

The window is dark whatever the system is set to: `NSApp.appearance = NSAppearance(named: .darkAqua)`, set
once before `Launcher()` at `:871`, whose `window` is a stored property (`:618`), so the alerts and the
menu follow. This replaces the parent's sentence
"Every colour is a system colour, so light and dark follow the system": the colours below are fixed, and
only the alerts' own colours are the system's.

One background view fills the content, title bar included, and draws in this order:

1. a vertical gradient, `NSColor(white: 0.24)` at the top to `NSColor(white: 0.09)` at the bottom;
2. a radial glow, `NSColor(calibratedRed: 0.35, green: 0.45, blue: 0.75, alpha: 0.22)` fading to clear,
   centred at 0.15 of the width on the top edge, radius 0.7 of the width;
3. the mark of 2.5, stroked in white at alpha 0.075.

Every colour, alpha and size of 2.1 to 2.5 is a named constant in one `enum Look`, which the drawing and
`--grid`'s `paint` lines both read. `readmeAddress` and the sizes sit after the mode switch today
(`:562-563`); they move above it, so that a text mode can build the grid.

### 2.4 Text, selection, hover and grey tiles

- **Title:** 12 points semibold, white, centred, word-wrapped, at most 2 lines, the second cut at its tail
  with an ellipsis. Under it a shadow: black at alpha 0.75, blur 3, offset 1 down. No shadow on the
  selected tile.
- **Two apps with one title.** `titled()` (`:181-190`) appends the file name, which ran to 3 or 4 lines
  and, cut to 2, left both tiles reading the same. Such a tile shows the title on line 1, cut at its tail,
  and the file name on line 2, cut in its middle so that its end stays, where copies differ. The cuts are
  `CTLineCreateTruncatedLine`'s, which gave section 1's strings. `--list` and VoiceOver keep `titled()`'s
  form.
- **Second line:** 10.5 points regular, white at alpha 0.88, the same shadow, at most 2 lines, starting 4
  below the title's last line. It is `secondLine()`, except that the tile shortens three sentences:

| State | `secondLine()`: VoiceOver's label and the tooltip | On the tile |
|---|---|---|
| a game that is `absent` | "Not installed in Steam. See its set-up guide." It was "Game files not found. See its set-up guide." (`:162`) | "Not installed in Steam" |
| a Steam app that is `absent` | "Windows Steam not found. Build this app again." | "Windows Steam not found" |
| an offer | "Not set up on this Mac. Opens the set-up guide." | "Not set up. Opens its guide." |

- **Grey tiles (K7).** Those three kinds are grey: the icon is drawn with its colours replaced by their
  luminance, at alpha 0.5. An offer's icon is the generic application icon, since a game's own icon comes
  out of its own files when its app is built. The texts stay at full strength, so the ratios below hold.
  A grey tile is chosen and started like any other: an `absent` game's launcher stops at once with its own
  alert naming the fix (`cities-skylines-2/launchers/launch-cs2-dxmt11.sh:183`,
  `surviving-mars-relaunched/launch-relaunched.sh:145`), and an offer opens its guide.
- **Tooltip:** the full title and, on a new line, the full sentence when there is one. The tile answers
  `accessibilityHelp()` with nothing, or VoiceOver would read the tooltip after the label (section 1).
- **Selection:** a plate behind the icon, the icon's rectangle grown by 7 at the sides and 6 above and
  below, corner radius 10, filled white at alpha 0.16 and outlined 1.5 points in white at alpha 0.75; and
  a pill behind the title, as wide as the title's widest line, the title's rectangle grown by 5 and 1,
  radius 4, filled `#0059D1` in sRGB. The pill is a fixed colour, not the accent (section 1, D15). The
  outline is not in the mockup (D16): it is what shows the selection by lightness, 4.68 to 1 at worst
  against the background and 3.37 against the plate's own fill, where the pill alone is 1.03 to 1.24.
- **Hover:** the same plate, filled white at alpha 0.08 with no outline, and the pointing-hand cursor over
  a tile. It is an extra cue: a click starts a game, so the tile under the pointer says it is live. Its
  tracking area is `.activeInKeyWindow`, so a window that a first click would only activate promises
  nothing. Neither is in the mockup (D25).
- **Ratios the build must keep:** title on the pill 6.27; title on the background 6.80 at worst with the
  mark behind and 8.20 without; second line and label 5.72 and 6.83. All are above 4.5. `--grid` prints
  them from the real views (section 4). The system's Increase Contrast setting changes nothing here:
  these are the floor at every setting.
- The empty state keeps its two strings (`:623-624`), "No games are set up on this Mac yet." at 13 points
  in white and the README address at 11 points in white at alpha 0.88, still selectable, centred in a
  grid of 444 by 172 with the mark behind. The address measured 350 points wide.
- Nothing animates.

### 2.5 The mark

Its numbers live in one `enum Mark`, read by `markPath(in:stroke:)` and by `--svg`. The path cannot be the
single source: an `NSBezierPath` arc cannot be read back as an SVG arc. In a square box, x to the right
and y up, both from 0 to 1:

| Part | Geometry |
|---|---|
| Ring | an arc centred 0.5, 0.5, radius 0.42, counter-clockwise from -58 to 238 degrees: open at the bottom |
| The 1 | 0.30, 0.605 to 0.455, 0.76 to 0.455, 0.08 |
| The mirrored 4 | 0.545, 0.08 to 0.545, 0.76 to 0.715, 0.585 to 0.545, 0.545 |
| Stroke | 0.05 of the box, round caps, round joins, no fill |
| Small form | the same path with the stroke at 0.085 of the box (2.6) |

**In the window** the box is a square whose side is 0.75 of the content's width, rounded. Its left edge is
at (width - side) / 2, not rounded, and its bottom edge is 0.08 of its side, rounded, below the window's
bottom edge, so the two stems run out of the window as in the mockup: 333, 55.5 and 27 at 444 wide; 414,
69 and 33 at 552. It grows with the width and is cropped by the height: a
one-row window shows its middle band, a taller one more of the ring.

### 2.6 The app icon

`drawIcon` keeps its contract: a bitmap of exactly 1024 by 1024 pixels, the rounded square 824 wide,
centred, corner radius 185, the gradient from `NSColor(white: 0.32)` to `NSColor(white: 0.13)`. The "14" and its
font go. In their place `markPath` is stroked in opaque white in the square inset by 92 on every side: a
box of 640 at 192, 192, stroke 32.

**A small form for 16 and 32 pixels (D24).** `--icon <out.png> small` draws the small form of 2.5 in the
square inset by 60: a box of 704 at 160, 160, stroke 59.84. The builder draws both and scales the three
files of 16 and 32 pixels (`icon_16x16`, `icon_16x16@2x`, `icon_32x32`) from the small one and the other
seven from the full one (`common/make-launcher-app.sh:85-91`). If the small one cannot be drawn, all ten
come from the full one.

The drawing moves into `iconBitmap(small:)`, which `--icon` writes and `--icon-at` samples: a pixel is
`clear` when its alpha is under 0.5, `ink` when its red is over 0.9, and `body` otherwise.

### 2.7 Interaction and VoiceOver

A `GridView` holds one `TileView` per row and is the window's only key view and first responder. It is
made in one function, `makeGrid`, and filled by one, `show(rows:offers:last:)`, which the window, `--grid`
and `--act` all call. It reports through two closures, `onStart` and `onQuit`, and asks a third, `blocked`.
`perform(_:)` on the grid applies `start` (through `blocked`, to `onStart`) and `quit` (to `onQuit`); the
monitor and `--act` call it with `keyAction`'s answer.

- **Click.** `mouseDown` and `mouseUp` only convert the point and call `press(at:)` and
  `release(at:clicks:)`. A press on a tile selects it and arms it, by its row's key. A release on the armed
  tile with a click count of 1 starts it. A release anywhere else, or with a higher count, starts nothing,
  so a double-click opens an offer's guide once. A reload disarms. A press between tiles, in a margin or on
  the label does nothing. A tile's hit area is its 120 by 146 frame, found by the grid's own function over
  the tile frames. `GridView` overrides `acceptsFirstMouse(for:)` to return false, so the first click into
  an inactive window only activates it. Whether a start comes on the release is one constant, so that its
  mutant is one line.
- **Keys.** One function, `keyAction(_:sheetUp:)`, answers `start`, `quit`, `endSheet` or `pass`, and the
  monitor of `:671-683` only calls it. With no sheet: Return, Enter and Space start the selection and
  Escape quits. With a sheet up: Escape ends it as "Don't Start", as today (`:677-681`), and every other
  key passes, Space included, so an alert's buttons keep their keys. The arrows are the grid's `keyDown`.
  Left and Right move one tile through the whole order, across rows, and stop at both ends. Up and Down
  move to the tile in the next row in that direction whose centre is nearest in x, the left one on a tie,
  the offers rows included, and stay put when there is no such row.
- **Blocked.** Before a press, a release, an arrow, a start or a press action does anything, the grid
  asks `blocked`. The window answers true while `starting` or while a sheet is up, which is `:772`'s test.
- **A start** goes from the grid through `onStart` to `startChosen`, which keeps `:772`, the reload, the
  question of `ask` for a busy target and `launch`. Its test of `clickedRow` (`:773`) goes: the armed-tile
  rule replaces it. `chosen` reads the grid's selection. `--act` gives the grid closures that print.
- **The selection at open** is `defaultRow`'s choice, and a reload keeps it on the same app by its key, as
  `:726` and `:738-745` do today.
- **VoiceOver.** Each tile is one element with the button role and today's label: the title, or "<title>,
  <second line>" with `secondLine()`'s full sentence, or for an offer "<title>, not set up on this Mac,
  opens the set-up guide in your browser" (`:602-603`). Its press action starts it. The selected tile
  answers `isAccessibilityFocused()` with true, `setAccessibilityFocused(true)` selects a tile, and every
  change of selection posts `.focusedUIElementChanged` for the tile: a move with the arrows is spoken, and
  Return starts the tile just read. Icons and texts are drawn, so they are not elements. The grid is a
  group labelled "Games", with the help "Click a game, or press Return, to start it." The label "You also
  own" is not an element: an offer's label says it.
- **Full keyboard access.** The grid is the only stop, so Tab has nowhere to go and the arrows do the
  moving. Nothing is added for it beyond Space.

### 2.8 The mark on the repository's page

- `launcher-window --svg <out.svg>` writes the icon form: exactly these five lines, each ended by one line
  break, 596 bytes. The path's numbers come from `Mark` (x = 192 + 640 x, y = 832 - 640 y, two decimals);
  the rest is literal. No text, no image, no script, no link.

```
<svg xmlns="http://www.w3.org/2000/svg" viewBox="100 100 824 824" role="img" aria-label="14unch3r">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#525252"/><stop offset="1" stop-color="#212121"/></linearGradient></defs>
<rect x="100" y="100" width="824" height="824" rx="185" fill="url(#g)"/>
<path d="M654.44 739.96A268.80 268.80 0 1 0 369.56 739.96M384.00 444.80L483.20 345.60L483.20 780.80M540.80 780.80L540.80 345.60L649.60 457.60L540.80 483.20" fill="none" stroke="#FFFFFF" stroke-width="32.00" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

- The output is committed as `docs/images/14unch3r.svg`, a new folder beside `docs/plans/`. W16 compares
  it byte for byte with fresh output, so the file cannot drift from the icon.
- `README.md` gains, above its first heading:
  `<p align="center"><img src="docs/images/14unch3r.svg" width="128" height="128" alt="14unch3r: a 1 and a mirrored 4 that form an upward arrow in a circle"></p>`
- One file, not `<picture>` with two: the white mark sits on its own graphite square (white on its
  lightest grey is 7.8 to 1 by the same formula), so it reads on GitHub's light and dark pages alike, and
  there is one file to keep equal to the program.
- Outside this plan, by James in GitHub's settings if he wants them: the organisation's avatar and the
  repository's social preview. `--icon` gives a PNG to upload there, or to put with a post elsewhere (K8).

### 2.9 A shortcut on the Desktop

- **Kind:** an alias file, written by the window program. Not a symlink: it breaks when the app
  moves, where the alias followed it (section 1). Not Finder through `osascript`:
  that brings an Automation question for whatever runs setup.
- **Mode:** `launcher-window --alias <app> <alias path> [make]`. It tests the path with `lstat` first and
  prints one word, exit 0: `have` when the path is an alias file, not a symlink, that resolves (no
  interface, no mounting) to the same resolved path as the app; `other` when anything else is at the path,
  a dangling symlink included; `none` when nothing is. With `make` and `none` it writes the alias and
  prints `made`; with `make` and `have` or `other` it writes nothing and prints that word. A write that
  fails prints `failed`, a tab and the system's sentence, and exits 1.
- **Never replaced.** An existing path is never written, removed or renamed: `writeBookmarkData` would
  overwrite (section 1), so it is called only after `lstat` found nothing. On James's Macs the Desktop is
  in iCloud, where a quick delete and rewrite leaves a stale " 2" copy, and where an alias made on one Mac
  appears on the other: there it reads `have` when it resolves to that Mac's app, and `other` when it does
  not, and either way setup adds nothing. No other file on the Desktop is read or touched.
- **Name:** `~/Desktop/14unch3r`, with `$HOME` as setup has it.
- **In `setup.sh`,** after the problems exit (`:227-231`) and before the closing lines, so a setup that
  ends with problems never reaches it. The step runs only when the window was built (`WINDOW_BUILT=1`,
  `:221`), the program `$HOME/Applications/14unch3r.app/Contents/MacOS/launcher-window` is there, and
  `$HOME/Desktop` is a folder. When any of those is not so there is no call, no question and no line.

| State | At a terminal, no flag | With `--desktop`, at a terminal or not | `--yes` alone, or not at a terminal |
|---|---|---|---|
| `none` | asks `Put a 14unch3r shortcut on the Desktop? [y/N] `; `y` or `Y` makes it, anything else does not | makes it, no question | the Desktop is not looked at |
| `have` | no question | no question | the Desktop is not looked at |
| `other` | no question | nothing made | the Desktop is not looked at |

- `--yes` does not answer this question with a yes: it means "do not stop", not "write to my Desktop".
  `--desktop` is the yes. Without it, a run with `--yes` or with no terminal makes no call at all: a look
  could bring a privacy question from macOS to a run nobody is watching. `--check` exits at `:135`, before
  any of this, with or without `--desktop`. `--desktop` is parsed with the other options (`:35-36`) and
  listed in the header that `--help` prints (`:8-12`).
- Nothing is remembered. A later run that finds `none` asks again.
- **One closing line** under `Play:`, by outcome: `Desktop:   14unch3r shortcut added`; `Desktop:   the
  14unch3r shortcut is already there`; `Desktop:   something else named 14unch3r is there; it was left as
  it is`; `Desktop:   no shortcut made. To add one:  bash scripts/setup.sh --desktop`, for a no and for a
  Desktop not looked at; or, on `failed`, `Desktop:   the shortcut could not be made: <the sentence>`. Any
  other answer from the program gives no line. None counts as a problem.
- Not measured, and owed to live step L3: whether macOS asks the terminal for access to the Desktop
  folder when the mode first looks there, and whether that comes before the question above.

## 3. Phases

Built in this order on a branch in a scratch worktree, as the parent was. A step is done when its tests
exit 0, every mutant of those rows has been seen red and restored, and every suite that passed before
still passes.

| Step | What | Files |
|---|---|---|
| B8 | `Mark`, `markPath`, `iconBitmap(small:)`, the icon carrying the mark, its small form and the builder's use of it, `--icon-at` | `common/launcher-window.swift`, `common/test-launcher-window.sh`, `common/make-launcher-app.sh`, `common/test-make-launcher-app.sh` |
| B9 | The grid: `Look`, `makeGrid`, `GridView`, `TileView`, the two blocks, grey tiles and `secondLine()`'s new sentence, the background, the chrome, dark appearance, `keyAction`, clicks, `blocked`, the scroll, VoiceOver, `--grid` and `--act`; `ItemCell` and the table go | `common/launcher-window.swift`, `common/test-launcher-window.sh` |
| B10 | `--svg`, the committed SVG, the README line | those two, `docs/images/14unch3r.svg`, `README.md` |
| B11 | `--alias`; `setup.sh`'s `--desktop` (option, header), question and closing line | those two, `cities-skylines-2/scripts/setup.sh`, `cities-skylines-2/scripts/test-setup.sh` |
| B12 | Documents: the pointer lines of section 8; the mode list in the source header (`:7-18`) and `usage()` (`:468-481`); `CLAUDE.md` (the Desktop alias as a place outside the repo, with its reason; `docs/images/`); `cities-skylines-2/INSTALL.md` (the question, `--desktop`, and the alias under Uninstall); the as-built header here | those |

## 4. Test plan

The parent's conventions hold: fixtures in a scratch folder, no game, no Steam, no Wine, the window never
started, an exit 2 is not a pass, each mutant one changed line in a copy of the source. The new modes
build the real `GridView` and `TileView` through `makeGrid`, with no window, and read their answers from
those views. No test names a path outside its scratch folder.

**`--grid [--games <tsv>] <last app id or -> <folder>...`** prints lines of tab-separated fields.
Coordinates are in points from the grid's top left, y down.

| Line | Fields |
|---|---|
| `size` | the grid's width and height |
| `window` | the width and height shown, the bar not counted: the height is at most 600 |
| `mark` | side, left edge, how far its bottom is below the content's bottom (2.5) |
| `group` | the grid's accessibility role, label and help |
| `label` | x, y and the text, when there are offers |
| `tile`, one per tile | row and column from 1; x; y; `game`, `steam` or `offer`; `selected` or `-`; `dim` or `-`; the accessibility role; the label; the help or `-`; the number of title lines; the title as shown, its lines joined by ` \| `; the second line as shown or `-` |
| `empty` | both strings, when there is no tile |
| `first-click` | `activates` or `starts`: what `acceptsFirstMouse` answers |
| `paint pill` | the pill's colour as `#RRGGBB`, and the ratio of the title's colour on it |
| `paint title`, `paint second`, `paint label` | the lowest ratio of that text's colour, composited at its alpha, over every pixel under any rectangle of that kind in a `cacheDisplay` of the real background at the window's size, bar included |
| `paint outline` | the lowest ratio of the outline over the background under the plate, and its ratio over the plate's fill; `-` when no outline is drawn |

**`--act <step,...> [--games <tsv>] <last app id or -> <folder>...`** applies steps, separated by commas,
to the same views and goes on after a start or a quit. Per step it prints the step; then `selected` and
the title, or `start` and the path, or `quit`, `pass`, `end-sheet` or `nothing`; then `focus` and the
number of the tile that answers focused, or `-` when none does; then `offset` and the grid's offset: one
tab-separated line per step. `block`, `unblock`, `reload` and `axfocus` print `selected` and the title.
A start prints and starts nothing.

| Step | What it does |
|---|---|
| `left` `right` `up` `down` | a key event to the grid's `keyDown` |
| `return` `enter` `space` `escape` | through `keyAction` with no sheet |
| `sheet:<key>` | the same key through `keyAction` with a sheet up |
| `press:x:y` `release:x:y` | `press(at:)`, and `release(at:clicks:)` with a count of 1 |
| `release2:x:y` | a release with a count of 2 |
| `axpress:n` `axfocus:n` | the press action of tile n, from 1, and `setAccessibilityFocused(true)` on it |
| `block` `unblock` | what `blocked` answers from then on |
| `reload` | `show(rows:offers:last:)` again, as the window's reload |

**`--icon-at [small] <x,y>...`** prints `ink`, `body` or `clear` per pixel of `iconBitmap(small:)`, x and
y from the top left (2.6).

| # | Step | Test | Cases | Mutants, each seen red |
|---|---|---|---|---|
| W13 | B8 | `common/test-launcher-window.sh`: `--icon-at`; `common/test-make-launcher-app.sh`: the packing | `ink` at 512,242 (ring top), 243,511 and 780,511 (ring sides), 483,575 and 540,575 (the stems), 433,395 (the 1's flag), 650,458 (the 4's flag); `body` at 512,780 (the ring's opening), 512,575 (between the stems), 672,575; `clear` at 64,959. The "14" icon measured `body` at five of those ink points and `ink` at 512,575 and 672,575, so the case tells the two apart. With `small`: `ink` at 512,192, which is `body` in the full form. `test-make-launcher-app.sh:127-133` still passes: 1024 by 1024. Added there, with a recording `sips` first on the path: the three files of 16 and 32 pixels are scaled from the small drawing and the other seven from the full one; with a program that fails on `small`, all ten come from the full one and the icon is still packed | the mark not stroked in the icon; the arc ended at 302 degrees, not 238; the small form's stroke at 0.05; the small drawing used for no size |
| W14 | B9 | `common/test-launcher-window.sh`: `--grid` | Each row of 2.1's table by `size`, `window` and origins, with fixture apps; 17 games give `size 552 788` and `window 552 600`. `mark` is 333, 55.5, 27 at 444 and 414, 69, 33 at 552. Every tile has `AXButton`, the label of 2.7 and no help; the group is `AXGroup`, "Games", with its help. An offer is on its own row under the label, both at the offers block's left edge; its label ends "opens the set-up guide in your browser"; it shows "Not set up. Opens its guide." and is `dim`. An `absent` Steam app shows "Windows Steam not found", is `dim`, and its label holds the full sentence. An `absent` game shows "Not installed in Steam" and is `dim`; a `ready` one is not. Two apps with one title, whose file names differ only at their ends: 2 title lines each, line 1 the title, and the two shown titles differ. A game whose title wraps to three lines shows 2, the second ending in an ellipsis. The selected tile is the last game when listed, else the first game. An empty folder: `size 444 172`, both strings, no tile. `first-click activates`. `paint`: the pill is `#0059D1` at 6.27; title, second line and label are at least 4.5; the outline is at least 4.5 on the background and 3 on the plate | 5 to a row; the group gap dropped; the least width dropped; the button role dropped; an offer's label without the guide words; offers not starting a row; the offers block given the games' left edge; the first tile selected whatever the last id; the title allowed 3 lines; the file name cut at its tail; an `absent` game not dim; the tile's help left as the tooltip; `acceptsFirstMouse` true; the pill the accent colour; the outline dropped; the second line at alpha 0.5; the mark at alpha 0.4 |
| W15 | B9 | same file: `--act` | `right` moves on, stays at the last tile; `left` stays at the first; `right` goes from the end of row 1 to the start of row 2. `down` goes to the nearest tile of the next row (with 5 games and Steam, from the fourth tile to Steam, not to the fifth game), into the offers row too, and stays on the last row; `up` the reverse. `return`, `enter` and `space` print `start` and the selected path; on an offer, its address. `escape` prints `quit`. `sheet:escape` prints `end-sheet`; `sheet:space` and `sheet:return` print `pass`. `press` and `release` on one tile: `start`, and the tile is selected after the press. `press` on one tile and `release` on another, or in a gap: `nothing`. `press`, `release2` on one tile: `nothing`. `press`, `reload`, `release` on one tile: `nothing`. `press` and `release` at 146:40, between two tiles, and at 10:10: `nothing`. After `block`: `press` and `release`, `return`, `right` and `axpress:1` each print `nothing`; after `unblock` they act. `axpress:2` starts tile 2. `axfocus:3` selects tile 3, and after every move `focus` names the selected tile. `right`, `reload`: still tile 2. With 17 games: `offset 188` after four `down`, `offset 0` after four `up` | a start on the press; the release not compared with the armed tile; a second click counted; a reload not disarming; `down` moving one tile on; `right` wrapping to the first; Escape dropped; Space dropped; Space taken under a sheet; the press action starting nothing; `blocked` not asked; focus never answered; a reload selecting the default; the selection not scrolled into view |
| W16 | B10 | same file: `--svg` | The output equals `docs/images/14unch3r.svg` by `cmp`, is the five lines of 2.8 and 596 bytes, passes `xmllint --noout`, and holds none of `<text`, `<image`, `<script`, `href`. `README.md` names that file once, and the file is there | the 1's top at 0.70, not 0.76; a second line break written at the end |
| W17 | B11 | same file: `--alias`, in a scratch folder with a fixture app | `none` for an empty path; `make` prints `made`, and the file is an alias by `file`, then reads `have`; `make` again prints `have` and the file's bytes and inode are unchanged. `other`, and untouched under `make`: a plain file, a folder, a symlink to the app, a dangling symlink, an alias to another fixture app. After the app is moved within the scratch folder the alias still reads `have` for the new path. A target that does not exist: `failed`, exit 1, nothing written. A folder that does not exist: `failed`, exit 1 | an existing path overwritten; a symlink to the app read as `have`; an alias to another app read as `have`; exit 0 on a failed write |
| W18 | B11 | `cities-skylines-2/scripts/test-setup.sh`: the builder stub (`:52-57`) also writes a recording `launcher-window` into the scratch `HOME`'s `14unch3r.app`, before it exits 1 when told to fail; the program answers `--alias` with `$STUB_ALIAS` (default `none`), records each call, and prints `made` under `make`. Every scratch home that should reach the step has a `Desktop` folder. A second form of the pty helper (`:157-161`) types a given answer through a pipe held open, `{ sleep 1; printf '%s\n' "$answer"; sleep 6; } \| script ...`, with `STUB_OSV` unset so that the caution question is not asked first | Typing `y`: the question is asked once, one call without `make` and one with, the `added` line. Typing an empty line, and typing `n`: asked, no `make`, the `no shortcut made` line. `--yes` at a terminal: not asked, no call at all, the `no shortcut made` line. `--desktop` with no terminal: not asked, `make` once. No terminal and no flag: no call at all, the `no shortcut made` line. `STUB_ALIAS=have`: not asked, no `make`, the `already there` line, at a terminal and with `--desktop` at none. `STUB_ALIAS=other`: the same, with the `left as it is` line. `STUB_ALIAS` set to `failed`, a tab and a sentence, with `--desktop`: the `could not be made:` line with that sentence. `--check --desktop`: no call and nothing written. The window stub exiting 1: no call, no `Desktop:` line. A home with no `Desktop` folder: no call, no line. A failing patch (`STUB_FAIL`, `:174`) with `--desktop`: exit 1 as before, not asked, no call. `--help` names `--desktop`. Every case but the failing patch, `--check` and `--help` exits 0 with `=== setup complete ===` | Return counted as yes; `--yes` counted as yes; the Desktop looked at without a terminal; `make` passed when the state is `other`; asked when the state is `have`; the alias step run when the window was not built; the step run before the problems exit; the Desktop folder not tested |
| W19 | B9 | `common/test-launcher-builders.sh`, unchanged | The builders' apps still come out of `--list` as before: the grid changed no row | none new |

Only a person sees: the look itself, the grey of a grey tile, the hover plate and cursor, the alerts in
dark, `mouseDown` and `mouseUp` reaching `press` and `release` in the real window, a first click
activating it, the scroll of a long grid, the Dock icon, the alias's arrow and icon in Finder, and the
page on GitHub.

## 5. Live steps, each on James's word

Records carry counts and verdict words only. Captures go to the evidence store, not the repository.

- **L1. Merge and build, on the Studio, with no launcher running** (the parent's live step 1 check), then
  `bash common/make-launcher-app.sh`. `--grid - ~/Applications` gives two games and one Steam tile at
  444 by 172.
- **L2. The rehearsal. This replaces parent live step 4**, on the same fixtures: the window opened on a
  scratch folder holding a busy app, one whose shim writes a file, one with no executable, an `absent`
  game, an `absent` Steam app, and a table that makes an offer. Captured once, the window's own region, with the system in light
  and again in dark: both must show the same dark window. Captures: the grid with every second line, the
  selected tile, a hovered tile, the three grey tiles, the question, the failed-start alert, the empty window.
  On each, the text measures at least 4.5 to 1 against what is behind it, the mark included, and the
  selection outline at least 3 to 1. "Don't Start" writes no file; "Start Anyway" writes it and the window
  quits; a failed start keeps the window. A press dragged off a tile starts nothing. The first click into
  the window from another app starts nothing. A double-click on the offer opens one guide. James moves
  through it with the arrows, Return, Space and Escape, and once with the accent set to yellow. Once with
  VoiceOver on: each move with the arrows is spoken, a tile's sentence is read once, and Return starts
  the tile just read. The icon reads as an arrow in a ring at 16 pixels in Finder's list view and in the
  Dock, where the parent asked that of "14". James may strike the outline (D16), the hover plate or the
  pointing hand (D25).
- **L3. The Desktop.** `bash scripts/setup.sh` at a terminal: the question, `y`, and one `14unch3r` alias
  with the app's icon and arrow, which opens the window. Written down: whether macOS asked for access to
  the Desktop folder, and when. A second run does not ask. James's two game aliases are byte-identical
  before and after, and no name ending " 2" has appeared on the Desktop a minute later.
- **L4. The page.** After the push, the README on github.com shows the mark in the light and the dark
  theme. W16 has checked that the file it names is there: `common/check-links.py` does not read `<img>`.
- **L5. The MacBook.** `git pull`, the build, and `setup.sh`: the alias that iCloud brought reads `have`
  or `other`, which is written down, and no second one is made. Parent live steps 5 to 8 then go on from
  this window; their wording "row" means a tile.

## 6. Exit criteria

- W13 to W18 exit 0 with every mutant seen red and restored; W19 and every suite the parent's section 6
  names still exit 0, as do `test-make-launcher-app.sh` and the parent's W1 to W12.
- `launcher-window.swift` holds no `NSTableView`, no `ItemCell` and no "14" drawn as text, and constructs
  `GridView(` at one place.
- L1 to L4 pass on the Studio and L5 on the MacBook.
- The design gate: W14's `paint` lines and L2's captures at the measured ratios; every state is words,
  grey or not; the keyboard reaches every tile; VoiceOver speaks each move, reads each tile's title and
  state once, and can start it.
- The as-built header here is written, and the parent has the pointer lines of section 8.

## 7. Rollback

`git revert` of this plan's merge, then `bash common/make-launcher-app.sh` on each Mac: the window is the
table of `f1afa88` again, with the "14" icon. By hand: `~/Desktop/14unch3r` to the Trash, once, on one
Mac, since iCloud removes it from the other. The revert takes `docs/images/14unch3r.svg` and the README
line with it. No launcher code, game file, save or preference is touched by this plan: `lastAppID` is
read and written as before.

## 8. Pointer lines the builder adds to the parent

- In `docs/plans/launcher-window.md` 2.2, under "What it looks like": "Superseded 2026-11-10 by
  `docs/plans/launcher-window-look.md`, sections 2.1 to 2.4 and 2.7: tiles, a dark window, fixed colours."
- In 2.6: "Superseded 2026-11-10 by `docs/plans/launcher-window-look.md`, 2.5 and 2.6: the icon carries the
  mark, and one SVG of it is in `docs/images/`."
- In 2.2's table of states, at `absent`: "A game now reads 'Not installed in Steam. See its set-up
  guide.' (`docs/plans/launcher-window-look.md`, 2.4)."
- In section 5, live step 4: "Replaced by live step L2 of `docs/plans/launcher-window-look.md`."
- In section 9, at D8: "See D12 and D19 of `docs/plans/launcher-window-look.md`."

## 9. Decisions (James)

| # | Question | Recommendation, or what was decided |
|---|---|---|
| D12 | The icon | **Decided 2026-11-10:** the mark, white on the graphite square. It ends the parent's D8 "until James supplies art" |
| D13 | The look | **Decided 2026-11-10** from the third mockup: tiles, the dark background, the mark centred and faint |
| D14 | Light mode | The window is always dark, alerts included. The parent's "light and dark follow the system" ends |
| D15 | The selection's colour | **Decided 2026-11-10 ("Fixed blue + outline").** A fixed blue, `#0059D1`, not the system accent: white on the accent measured 1.58 to 4.02. On a Mac set to another accent the pill stays blue |
| D16 | An outline on the selected icon's plate, which the mockup does not have | **Decided 2026-11-10** with D15: added. Without it the selection is told by hue alone. **Kept after L2 (2026-11-10, "keep all three")** |
| D17 | Second lines shortened on the tile | **Decided 2026-11-10 ("Shorten").** "Windows Steam not found", "Not set up. Opens its guide." and, with K7, "Not installed in Steam", so no tile needs a third line. The full sentences stay for VoiceOver and the tooltip |
| D18 | The label "You also own" | Kept, small, above a row of its own |
| D19 | An image file in the repository, which the parent's D8 ruled out | **Decided 2026-11-10** by K6: one SVG, written by the program and compared with it by a test |
| D20 | The Desktop shortcut | **Decided 2026-11-10 ("Ask, default No").** Asked at a terminal, default no; `--desktop` says yes; `--yes` does not, and without `--desktop` an unwatched run does not look at the Desktop; never replaced; nothing remembered |
| D21 | A new place outside the repo, which `CLAUDE.md` asks James's word for | `~/Desktop/14unch3r`, one alias, made only on a yes. K5 is that word; B12 writes it into `CLAUDE.md` |
| D22 | The repository's name, which James asked to alias to `14unch3r` | **Decided 2026-11-10 ("Keep 1launcher").** GitHub has no aliases; a rename, whose old links redirect, was offered and not taken. The app, the icon and the page's image say 14unch3r; the repository, its folders and its links stay `1launcher` (parent D4) |
| D23 | A tile that cannot start (K7) | Grey icon and a few words saying why. It is still chosen and started: for a game not installed, its launcher's own alert names the fix. The window cannot open a game's own Steam to install it; that gap is in `docs/plans/1launcher-unification.md` |
| D24 | The icon at 16 and 32 pixels | A small form with a heavier stroke, measured (section 1): the full form is a grey blur at 16 |
| D25 | The hover plate and the pointing hand, which the mockup does not have | Added, since one click starts a game. **Kept after L2 (2026-11-10, "keep all three, everything checked out")** |

## Review corrections (triple-check 2026-11-10)

Pass 1 was three lenses. All three said build-ready-with-fixes; the two blockers were both in the test
plan, and both were measured again before folding. The corrections are in the sections named.

| # | Finding | Lens | Where it landed |
|---|---|---|---|
| R1 | **Blocker.** W18's helper cannot type an answer: `script` gives the read an end of file | builder, correctness | 1, W18 |
| R2 | **Blocker.** `--act` steps are split at commas and `press:x,y` holds one | builder | 4: `press:x:y` |
| R3 | `--act` could not reach the keys or the start guard, which sat in a closure and in `Launcher` | all three | 2.7 `keyAction`, `blocked`, `makeGrid`; 4; W15; 6 |
| R4 | VoiceOver: arrow moves silent, the cursor and the selection apart, the tooltip read twice | design | 2.4, 2.7, W14, W15, L2 |
| R5 | Two apps with one title showed the same two lines | design, correctness | 1, 2.4, W14 |
| R6 | Space taken while a sheet is up | design | 2.7, W15 |
| R7 | The mark is a blur at 16 pixels | design | 1, 2.5, 2.6, W13, B8, L2, D24 |
| R8 | No test guarded a colour | design | 2.3 `Look`, 4 `paint`, W14 |
| R9 | The Desktop step: before the problems exit; a missing folder said two things; an unwatched run looked | correctness, builder | 2.9, W18, D20 |
| R10 | Late offers moved a game under the pointer | correctness | 2.1 two blocks, W14; a reload disarms, 2.7, W15 |
| R11 | The scroll past 600 was not specified or tested | correctness, design | 2.1, 4, W14, W15 |
| R12 | The title bar: `.fullSizeContentView` adds nothing | builder | 1, 2.2 |
| R13 | The SVG's bytes were not given, and the path could not be the numbers' one home | builder, design | 2.5 `Mark`, 2.8 |
| R14 | `--grid`'s fields, frames and bases; `--icon-at`'s thresholds; smaller things a builder had to invent | builder | 2.3, 2.4, 2.6, 2.7, 4 |
| R15 | A double-click on an offer opened two guides; hover promised a start an inactive window does not give | design | 2.4, 2.7, W15, L2 |
| R16 | Two cites; a mutant under the wrong test; `check-links.py` does not read `<img>`; `--desktop` missing from `--help` | correctness, builder | 1, W14, L4, 2.9, W18 |

Not taken: the accent colour where it reaches 4.5 (it never does on the numbers of section 1, and James
chose the fixed blue); a second `<picture>` image for the page.

Added in the same fold, from James (2026-11-10): K7 and D23, grey tiles; D15, D16, D17 and D20 decided;
D22, the name stays.

### Fold check (pass 1b, 2026-11-10)

One agent read the fold alone, against the code and a copy of the builder's scratch tree. It confirmed R1
to R16 in every place they belong, every new number and every new cite, and measured the small form's
points, the `paint` ratios and the grey icon offscreen. Its nine findings are folded:

| # | Finding | Where it landed |
|---|---|---|
| F1 | **Blocker.** W18's mutant "the step run before the problems exit" survived: with no terminal the Desktop is not looked at either way (measured) | W18: the failing patch runs with `--desktop` |
| F2 | **Blocker.** W14's mutant "the title allowed 3 lines" had no red case once a shared title became two one-line cuts | W14: a title that wraps to three lines |
| F3 | W18's `have`, `other` and `failed` cases predated R9 and would not reach the program | W18 |
| F4 | The least scroll depends on the offset before, so it is not a function of the frames alone | 2.1 `scrollOffset(for:from:)` |
| F5, F6 | Two more cases that do not end in "setup complete"; one mutant that was the same line as another | W18 |
| F7 | `--act`'s line for the steps that are not keys or clicks | 4 |
| F8 | Nothing called `onQuit` | 2.7 `perform(_:)` |
| F9 | Which truncation gives the middle cut | 2.4 |

## Review log

| Date | Pass | Lenses | Method | Model | Verified against | Verdict |
|---|---|---|---|---|---|---|
| 2026-11-10 | 1 | correctness, architecture and blast radius; builder simulation; design, accessibility and test plan | three agents; the builder built B8 to B11 on a scratch tree, ran the four suites and saw 30 mutants red; blockers measured again inline | Fable 5.2 | `5bbab65` | build-ready-with-fixes |
| 2026-11-10 | 1b | the fold alone | one agent; offscreen probes and a copy of the scratch tree | Fable 5.2 | `fee81b0` | build-ready-with-fixes |

Key paths: `common/launcher-window.swift`, `common/make-launcher-app.sh`, `common/test-launcher-window.sh`,
`common/test-make-launcher-app.sh`, `common/test-launcher-builders.sh`, `cities-skylines-2/scripts/setup.sh`,
`cities-skylines-2/scripts/test-setup.sh`, `README.md`, `docs/plans/launcher-window.md`.
