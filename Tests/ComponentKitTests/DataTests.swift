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
