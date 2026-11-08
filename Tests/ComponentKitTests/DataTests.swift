import SwiftUI
import Testing

@testable import ComponentKit

// MARK: - Diffs

@Test func splitRowsPairsRemovedWithAdded() {
  let lines = [
    DiffLine(.context, old: 1, new: 1, text: "a"),
    DiffLine(.removed, old: 2, text: "b"),
    DiffLine(.removed, old: 3, text: "c"),
    DiffLine(.added, new: 2, text: "B"),
    DiffLine(.context, old: 4, new: 3, text: "d"),
    DiffLine(.added, new: 4, text: "e"),
  ]
  let rows = DiffLine.splitRows(lines)
  #expect(rows.count == 5)
  #expect(rows[0].old?.text == "a" && rows[0].new?.text == "a")
  #expect(rows[1].old?.oldNumber == 2 && rows[1].new?.newNumber == 2)
  #expect(rows[2].old?.oldNumber == 3 && rows[2].new == nil)
  #expect(rows[4].old == nil && rows[4].new?.newNumber == 4)
}

@Test func splitRowsKeepsAddedBeforeRemovedApart() {
  let lines = [DiffLine(.added, new: 1, text: "x"), DiffLine(.removed, old: 1, text: "y")]
  let rows = DiffLine.splitRows(lines)
  #expect(rows.count == 2)
  #expect(rows[0].old == nil && rows[0].new?.text == "x")
  #expect(rows[1].old?.text == "y" && rows[1].new == nil)
}

@Test func diffLineIDsAreUniqueInAHunk() {
  let ids = [
    DiffLine(.context, old: 5, new: 6, text: "").id, DiffLine(.removed, old: 6, text: "").id,
    DiffLine(.added, new: 6, text: "").id,
  ]
  #expect(Set(ids).count == 3)
}

@Test func markedWordsGetABackground() {
  let line = DiffLine(.added, new: 1, text: "load() throws {", highlights: [7..<13, 40..<50])
  let marked = line.marked(.green)
  let runs = marked.runs.filter { $0.backgroundColor != nil }
  #expect(runs.count == 1)
  #expect(String(marked[runs.first!.range].characters) == "throws")
}

// MARK: - Run output

@Test func runOutputMarksCompilerErrorsAndWarnings() {
  let output = "Building...\nTrip.swift:42: error: bad\nwarning: unused\nno error: here"
  let marks = RunOutput.marks(in: output)
  #expect(marks.count == 2)
  let text = Array(output)
  #expect(String(text[marks[0].range]) == "error:" && marks[0].isError)
  #expect(String(text[marks[1].range]) == "warning:" && !marks[1].isError)
}

// MARK: - Meters

@Test func meterWidthsArePartsOfTheTrack() {
  let widths = MeterLayout.widths([50, 25], total: 100, width: 104, gap: 2, minWidth: 4)
  // 104 - 2 gaps (two parts and the free rest) = 100 usable.
  #expect(widths == [50, 25])
}

@Test func meterWidthsKeepSmallPartsVisible() {
  let widths = MeterLayout.widths([1000, 1], total: nil, width: 102, gap: 2, minWidth: 4)
  #expect(widths[1] == 4)
  #expect(abs(widths.reduce(0, +) - 100) < 0.6)
}

@Test func meterWidthsOfNothing() {
  #expect(MeterLayout.widths([0, 0], total: 10, width: 100, gap: 2, minWidth: 4) == [0, 0])
  #expect(MeterLayout.widths([], total: nil, width: 100, gap: 2, minWidth: 4).isEmpty)
}

@Test func laneHuesWrap() {
  #expect(Hue.lane(0) == .accent && Hue.lane(8) == .accent && Hue.lane(-1) == .brown)
}

// MARK: - Grid and navigation

@Test func lastGridColumnTakesTheRest() {
  #expect(KitGridLayout.widths([80, 120], available: 400) == [80, 320])
  #expect(KitGridLayout.widths([80, 120], available: 100) == [80, 120])
  #expect(KitGridLayout.widths([], available: 100).isEmpty)
}

@Test func gridClickFindsItsColumn() {
  let widths: [CGFloat] = [60, 100, 80]
  #expect(KitGridLayout.column(at: 0, widths: widths) == 0)
  #expect(KitGridLayout.column(at: 59, widths: widths) == 0)
  #expect(KitGridLayout.column(at: 60, widths: widths) == 1)
  #expect(KitGridLayout.column(at: 200, widths: widths) == 2)
  #expect(KitGridLayout.column(at: 500, widths: widths) == 2)
  // The state gutter belongs to the first column.
  #expect(KitGridLayout.column(at: 10, widths: widths, leading: 30) == 0)
  #expect(KitGridLayout.column(at: 95, widths: widths, leading: 30) == 1)
  #expect(KitGridLayout.column(at: 10, widths: []) == 0)
}

@Test func gridColumnMovesClamp() {
  #expect(KitGridLayout.column(nil, by: 1, count: 3) == 0)
  #expect(KitGridLayout.column(nil, by: -1, count: 3) == 2)
  #expect(KitGridLayout.column(2, by: 1, count: 3) == 2)
  #expect(KitGridLayout.column(0, by: 1, count: 0) == nil)
}

@Test func shiftExtendsGridSelection() {
  let ids = [1, 2, 3, 4, 5]
  #expect(KitGridLayout.selection(ids, anchor: 2, target: 4, extending: true) == [2, 3, 4])
  #expect(KitGridLayout.selection(ids, anchor: 4, target: 1, extending: true) == [1, 2, 3, 4])
  #expect(KitGridLayout.selection(ids, anchor: 2, target: 4, extending: false) == [4])
}

@Test func navigationClampsAndStarts() {
  let ids = ["a", "b", "c"]
  #expect(DataNav.moved(nil, by: 1, in: ids) == "a")
  #expect(DataNav.moved(nil, by: -1, in: ids) == "c")
  #expect(DataNav.moved("c", by: 1, in: ids) == "c")
  #expect(DataNav.moved("b", by: -1, in: ids) == "a")
  #expect(DataNav.moved("gone", by: 1, in: ids) == "a")
  #expect(DataNav.moved("a", by: 1, in: []) == nil)
}

@MainActor @Test func navModelActivatesTheSelection() {
  let nav = DataNavModel()
  nav.update(ids: ["a", "b"])
  #expect(nav.selected == "a")
  nav.move(by: 1)
  nav.activate()
  #expect(nav.activated == "b" && nav.activation == 1)
  nav.update(ids: ["c"])
  #expect(nav.selected == "c")
}

/// A welcome item without an `id:` used to take its subtitle as its id, so projects on the same devices ("studio-mac")
/// shared one and every row opened the first (Code C-007).
@MainActor @Test func recentItemsWithTheSameSubtitleHaveTheirOwnIDs() {
  let first = RecentItem.defaultID(title: "Alpha", subtitle: "studio-mac")
  let second = RecentItem.defaultID(title: "Bravo", subtitle: "studio-mac")
  #expect(first != second)
  #expect(RecentItem.defaultID(title: "Alpha", subtitle: nil) == "Alpha")
  #expect(RecentItem.defaultID(title: "Alpha", subtitle: "b") != RecentItem.defaultID(title: "Alpha b", subtitle: nil))
}

@Test func paletteMarksTheMatch() {
  let marked = PaletteMatch.marked("TripStore.swift", query: "store")
  let strong = marked.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }
  #expect(strong.count == 1)
  #expect(String(marked[strong.first!.range].characters) == "Store")
  #expect(PaletteMatch.marked("Build", query: " ").runs.count == 1)
}

// MARK: - Palette match offsets

@Test func paletteMarksFuzzyOffsets() {
  let text = PaletteMatch.marked("TripStore.swift", offsets: [0, 4, 4, 99, -1])
  let bold = text.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }.map { String(text[$0.range].characters) }
  #expect(bold == ["T", "S"])
  // Offsets count UTF-16 units: "é" is one, the emoji two.
  let accented = PaletteMatch.marked("é🙂x", offsets: [3])
  let marked = accented.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }.map { String(accented[$0.range].characters) }
  #expect(marked == ["x"])
}

// MARK: - Grid outline

private struct Key { var name: String; var children: [Key]? }

@Test func gridFlattensOpenRows() {
  let keys = [
    Key(name: "user", children: [Key(name: "user:1"), Key(name: "user:2", children: [Key(name: "user:2:cart")])]),
    Key(name: "session", children: []),
    Key(name: "config"),
  ]
  let closed = KitGridLayout.flatten(keys, id: \.name, children: \.children, isOpen: { _ in false })
  #expect(closed.map(\.row.name) == ["user", "session", "config"])
  #expect(closed.map(\.hasChildren) == [true, true, false])
  let open = KitGridLayout.flatten(keys, id: \.name, children: \.children, isOpen: { $0 == "user" || $0 == "user:2" })
  #expect(open.map(\.row.name) == ["user", "user:1", "user:2", "user:2:cart", "session", "config"])
  #expect(open.map(\.depth) == [0, 1, 1, 2, 0, 0])
}

// MARK: - Diff line selection

@Test func diffSelectsRunsOfChangedLines() {
  let lines: [(id: String, isChange: Bool)] = [("a", false), ("b", true), ("c", true), ("d", false), ("e", true)]
  #expect(DiffSelect.run(lines, from: 0, to: 4) == ["b", "c", "e"])
  #expect(DiffSelect.run(lines, from: 4, to: 2) == ["c", "e"])
  #expect(DiffSelect.run(lines, from: 3, to: 3) == [])
  #expect(DiffSelect.index(atY: 45, count: 5) == 2)
  #expect(DiffSelect.index(atY: -10, count: 5) == 0)
  #expect(DiffSelect.index(atY: 900, count: 5) == 4)
}

// MARK: - Inline welcome

@Test func welcomeGoesTwoColumnsInAWidePane() {
  #expect(WelcomeLayout.isWide(width: 900, idiom: .mac))
  #expect(WelcomeLayout.isWide(width: 1000, idiom: .pad))
  #expect(!WelcomeLayout.isWide(width: 640, idiom: .mac))
  #expect(!WelcomeLayout.isWide(width: 1000, idiom: .phone))
}

@Test func welcomeListTakesThePaneWithinLimits() {
  #expect(WelcomeLayout.wideListHeight(available: 900) == 560)
  #expect(WelcomeLayout.wideListHeight(available: 400) == 400)
  #expect(WelcomeLayout.wideListHeight(available: 100) == WelcomeLayout.minListHeight)
  #expect(WelcomeLayout.columnListHeight(available: 1000, identity: 320, fills: false) == 440)
  #expect(WelcomeLayout.columnListHeight(available: 650, identity: 320, fills: false) == 330)
  // A short pane keeps the list readable and scrolls.
  #expect(WelcomeLayout.columnListHeight(available: 500, identity: 320, fills: false) == WelcomeLayout.minListHeight)
  // On iPhone it fills the screen under the identity.
  #expect(WelcomeLayout.columnListHeight(available: 1000, identity: 320, fills: true) == 680)
}

// MARK: - Decoded images

#if canImport(ImageIO)
  import ImageIO
  import UniformTypeIdentifiers

  /// A `side`-pixel square PNG of one grey.
  private func greyPNG(side: Int) throws -> Data {
    let context = try #require(
      CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
    context.setFillColor(gray: 0.5, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    let image = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
  }

  @MainActor @Test func decodedImagesLoadOnceAndKeepThePicture() async throws {
    let png = try greyPNG(side: 64)
    let key = KitImages.Key(.data(png), maxPixelSize: 36)
    #expect(KitImages.cached(key) == nil)
    #expect(await KitImages.load(key) != nil)
    // The same bytes in another buffer, at the same size, come from the cache.
    #expect(KitImages.cached(KitImages.Key(.data(Data(png)), maxPixelSize: 36)) != nil)
    // Another size is another picture.
    #expect(KitImages.cached(KitImages.Key(.data(png), maxPixelSize: 64)) == nil)
  }

  @MainActor @Test func decodedImagesRefuseBytesThatAreNoPicture() async {
    #expect(await KitImages.load(KitImages.Key(.data(Data("not a picture".utf8)), maxPixelSize: nil)) == nil)
    #expect(await KitImages.load(KitImages.Key(.file(URL(fileURLWithPath: "/nonexistent.png")), maxPixelSize: 10)) == nil)
  }
#endif

#if os(macOS)
  /// A MongoDB edit's ObjectId kept Review's change row, and with it the sheet, wider than an iPhone: the statement
  /// and the Undo were cut at both edges (Database D-009).
  @MainActor @Test func changeRowFitsANarrowWidthWithALongKey() {
    let key = "ObjectId(\"65f1c0ffee0123456789abcd\")"
    let row = ChangeRow(.edited, title: key, field: "body", old: "Sturdy", new: "Sturdy and bright") {}
      .componentKit()
    let host = NSHostingController(rootView: row)
    #expect(host.sizeThatFits(in: CGSize(width: 300, height: 1000)).width <= 300)
    // Where there is room the key stays whole, on one line with the change.
    #expect(host.sizeThatFits(in: CGSize(width: 900, height: 1000)).width > 300)
  }
#endif
