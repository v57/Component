import SwiftUI
import Testing

@testable import ComponentKit

// MARK: - Split

@Test func splitClampsToRange() {
  #expect(ContSplit.clamp(100, to: 200...400) == 200)
  #expect(ContSplit.clamp(500, to: 200...400) == 400)
  #expect(ContSplit.clamp(300, to: 200...400) == 300)
}

@Test func splitTrailingPaneGrowsWhenDividerMovesLeft() {
  #expect(ContSplit.width(start: 300, translation: -40, edge: .trailing, range: 200...400) == 340)
  #expect(ContSplit.width(start: 300, translation: 40, edge: .trailing, range: 200...400) == 260)
  #expect(ContSplit.width(start: 300, translation: -400, edge: .trailing, range: 200...400) == 400)
}

@Test func splitLeadingPaneGrowsWhenDividerMovesRight() {
  #expect(ContSplit.width(start: 250, translation: 30, edge: .leading, range: 200...400) == 280)
  #expect(ContSplit.width(start: 250, translation: -100, edge: .leading, range: 200...400) == 200)
}

// MARK: - Reorder

@Test func reorderDestinationMatchesOnMove() {
  // Dragged down onto row 3: lands after it, so `.onMove`'s destination is 4.
  #expect(ContReorder.destination(from: 1, to: 3) == 4)
  // Dragged up onto row 0: lands before it.
  #expect(ContReorder.destination(from: 2, to: 0) == 0)
  var rows = ["a", "b", "c", "d"]
  rows.move(fromOffsets: [1], toOffset: ContReorder.destination(from: 1, to: 3))
  #expect(rows == ["a", "c", "d", "b"])
  rows.move(fromOffsets: [3], toOffset: ContReorder.destination(from: 3, to: 0))
  #expect(rows == ["b", "a", "c", "d"])
}

@MainActor @Test func reorderStateTracksTheDraggedRow() {
  let state = ContReorderState()
  state.begin("hosts", at: 2)
  #expect(state.isDragging("hosts", at: 2))
  #expect(!state.isDragging("sessions", at: 2))
  state.update(indices: [0], anchor: 0)
  #expect(state.isDragging("hosts", at: 0))
  state.end()
  #expect(!state.isDragging("hosts", at: 0))
}

// MARK: - Toolbar compacting

@Test func toolbarStepsLabelsGoFirstThenFoldByPriority() {
  // Fetch 1, Pull 2, Push 3, a gap, Branch 0, Commit (primary, never folds).
  let steps = ContToolbarPlan.steps(priorities: [1, 2, 3, nil, 0, nil])
  #expect(steps.count == 2 + 4)
  #expect(steps[0] == .init(labelled: true, folded: []))
  #expect(steps[1] == .init(labelled: false, folded: []))
  #expect(steps[2].folded == [4])
  #expect(steps[3].folded == [4, 0])
  #expect(steps[4].folded == [4, 0, 1])
  #expect(steps[5].folded == [4, 0, 1, 2])
  #expect(steps.dropFirst().allSatisfy { !$0.labelled })
}

@Test func toolbarTiesFoldTheTrailingToolFirst() {
  let steps = ContToolbarPlan.steps(priorities: [0, 0, 0])
  #expect(steps[2].folded == [2])
  #expect(steps[3].folded == [2, 1])
}

@Test func toolbarGroupsSplitAtGapsAndPrimaries() {
  let groups = ContToolbarPlan.groups(
    isGap: [false, false, true, false, false, false],
    isPrimary: [false, false, false, false, false, true],
    folded: [])
  #expect(groups == [[0, 1], [3, 4], [5]])
  // Folding every tool of a card drops the card.
  let folded = ContToolbarPlan.groups(
    isGap: [false, false, true, false, false, false],
    isPrimary: [false, false, false, false, false, true],
    folded: [0, 1, 4])
  #expect(folded == [[3], [5]])
}

@Test func toolbarPicksTheFirstFormThatFits() {
  #expect(ContToolbarPlan.firstFit(widths: [500, 300, 200], available: 400) == 1)
  #expect(ContToolbarPlan.firstFit(widths: [500, 300, 200], available: 600) == 0)
  // Nothing fits, or nothing is measured yet: the smallest form.
  #expect(ContToolbarPlan.firstFit(widths: [500, 300, 200], available: 100) == 2)
  #expect(ContToolbarPlan.firstFit(widths: [nil, nil, nil], available: 1000) == 2)
}

@Test func kitToolbarTitleGivesWayOnlyAfterTheToolsCompact() {
  // Room for the title and the widest tools.
  let wide = ContToolbarLayoutMath.widths(
    available: 1000, leading: 0, title: 200, toolsIdeal: 500, toolsMin: 100, spacing: 8)
  #expect(wide == .init(leading: 0, title: 200, tools: 792))
  // The tools compact first: the title keeps its width while the smallest tools still fit.
  let narrow = ContToolbarLayoutMath.widths(
    available: 400, leading: 30, title: 200, toolsIdeal: 500, toolsMin: 100, spacing: 8)
  #expect(narrow == .init(leading: 30, title: 200, tools: 154))
  // Then the title shrinks so the smallest tools keep their room.
  let tight = ContToolbarLayoutMath.widths(
    available: 250, leading: 0, title: 200, toolsIdeal: 500, toolsMin: 100, spacing: 8)
  #expect(tight == .init(leading: 0, title: 142, tools: 100))
}

// MARK: - Window

@Test func paneHairlineOnlyBetweenSameGrounds() {
  let list = CGRect(x: 0, y: 0, width: 200, height: 400)
  let editor = CGRect(x: 200, y: 0, width: 400, height: 400)
  let inspector = CGRect(x: 600, y: 0, width: 300, height: 400)
  let second = CGRect(x: 900, y: 50, width: 100, height: 300)
  #expect(ContPaneEdges.lines([(list, .secondary), (editor, .content), (inspector, .secondary)]).isEmpty)
  let lines = ContPaneEdges.lines([(editor, .content), (inspector, .secondary), (second, .secondary)])
  #expect(lines == [CGRect(x: 899.5, y: 50, width: 1, height: 300)])
}

@Test func paneHairlineNeedsPanesToMeet() {
  let a = CGRect(x: 0, y: 0, width: 200, height: 400)
  let b = CGRect(x: 210, y: 0, width: 200, height: 400)
  #expect(ContPaneEdges.lines([(a, .content), (b, .content)]).isEmpty)
}

// MARK: - Flow and keycaps

@Test func flowWrapsWhenTheNextItemDoesNotFit() {
  let sizes = [CGSize(width: 60, height: 20), CGSize(width: 60, height: 24), CGSize(width: 60, height: 20)]
  let frames = ContFlow.frames(sizes, maxWidth: 130, spacing: 6, lineSpacing: 4)
  #expect(frames[0].origin == CGPoint(x: 0, y: 2))
  #expect(frames[1].origin == CGPoint(x: 66, y: 0))
  #expect(frames[2].origin == CGPoint(x: 0, y: 28))
  #expect(ContFlow.size(of: frames) == CGSize(width: 126, height: 48))
}

@Test func flowGivesAnOversizedItemItsOwnLine() {
  let frames = ContFlow.frames(
    [CGSize(width: 200, height: 10), CGSize(width: 20, height: 10)], maxWidth: 100, spacing: 4, lineSpacing: 4)
  #expect(frames[0].origin == .zero)
  #expect(frames[1].origin == CGPoint(x: 0, y: 14))
}

@Test func keycapsSplitModifiersFromTheKey() {
  #expect(ContKeycaps.keys("⌘⇧F") == ["⌘", "⇧", "F"])
  #expect(ContKeycaps.keys("⌥⌘Return") == ["⌥", "⌘", "Return"])
  #expect(ContKeycaps.keys("K") == ["K"])
}

// MARK: - Row keyboard navigation

private var navRows: [(value: AnyHashable, indent: Int, isOpen: Bool?)] { [
  ("Sources", 0, true), ("Models", 1, false), ("App.swift", 1, nil), ("Tests", 0, false), ("Package.swift", 0, nil),
] }

@Test func rowNavMovesUpAndDown() {
  #expect(ContRowNav.move(nil, by: 1, in: navRows) == .select("Sources"))
  #expect(ContRowNav.move(nil, by: -1, in: navRows) == .select("Package.swift"))
  #expect(ContRowNav.move("Models", by: 1, in: navRows) == .select("App.swift"))
  #expect(ContRowNav.move("Sources", by: -1, in: navRows) == .none)
  #expect(ContRowNav.move("x", by: 1, in: []) == .none)
}

@Test func rowNavLeftClosesThenGoesToTheParent() {
  #expect(ContRowNav.left("Sources", in: navRows) == .collapse("Sources"))
  #expect(ContRowNav.left("App.swift", in: navRows) == .select("Sources"))
  #expect(ContRowNav.left("Models", in: navRows) == .select("Sources"))
  #expect(ContRowNav.left("Package.swift", in: navRows) == .none)
}

@Test func rowNavRightOpensThenGoesToTheFirstChild() {
  #expect(ContRowNav.right("Tests", in: navRows) == .expand("Tests"))
  #expect(ContRowNav.right("Sources", in: navRows) == .select("Models"))
  #expect(ContRowNav.right("App.swift", in: navRows) == .none)
}

@Test func reorderAcceptsOtherListsOnlyWhenReceiving() {
  #expect(ContReorder.accepts(from: "a", into: "a", receives: false))
  #expect(!ContReorder.accepts(from: "b", into: "a", receives: false))
  #expect(ContReorder.accepts(from: "b", into: "a", receives: true))
  #expect(!ContReorder.accepts(from: nil, into: "a", receives: true))
}

@Test func splitBottomPaneGrowsWhenDividerMovesUp() {
  #expect(ContSplit.size(start: 200, translation: -50, paneLeads: false, range: 100...400) == 250)
  #expect(ContSplit.size(start: 200, translation: 50, paneLeads: false, range: 100...400) == 150)
  #expect(ContSplit.size(start: 200, translation: 500, paneLeads: true, range: 100...400) == 400)
}

@Test func cardSlicesByPosition() {
  #expect(KitCardSlice(0, of: 1) == .only)
  #expect(KitCardSlice(0, of: 3) == .first)
  #expect(KitCardSlice(1, of: 3) == .middle)
  #expect(KitCardSlice(2, of: 3) == .last)
  #expect(KitCardSlice(0, of: 0) == .only)
}

// MARK: - Multi-row reorder

/// Rows of the given heights, 2pt apart, from y 0.
private func spans(_ heights: [CGFloat]) -> [Int: ContReorder.Span] {
  var spans: [Int: ContReorder.Span] = [:]
  var y: CGFloat = 0
  for (index, height) in heights.enumerated() {
    spans[index] = .init(start: y, length: height)
    y += height + 2
  }
  return spans
}

/// Applies a drop to `rows` and checks the dragged rows end up where `landing` says.
private func landed(_ rows: [String], dragging: IndexSet, anchor: Int, target: Int) -> [String]? {
  guard let step = ContReorder.landing(count: rows.count, dragged: dragging, anchor: anchor, target: target) else {
    return nil
  }
  let dragged = dragging.map { rows[$0] }
  var rows = rows
  rows.move(fromOffsets: dragging, toOffset: step.destination)
  #expect(step.indices.map { rows[$0] } == dragged)
  #expect(rows[step.anchor] == dragged[dragging.count(in: 0..<anchor)])
  #expect(rows == ContReorder.order(count: rows.count, dragged: dragging, target: target).map { ["a", "b", "c", "d", "e", "f"][$0] })
  return rows
}

@Test func reorderTargetMovesPastTheMiddlesOfTheRowsDrawnBesideIt() {
  let rows = spans([20, 60, 20, 20])  // 0…20, 22…82, 84…104, 106…126
  // Row 0 dragged down: the tall row after it moves it on once the pointer passes that row's middle (52).
  #expect(ContReorder.target(from: 0, pointer: 30, spans: rows, dragged: [0], count: 4) == 0)
  #expect(ContReorder.target(from: 0, pointer: 53, spans: rows, dragged: [0], count: 4) == 1)
  // Past that, row 2 is drawn at 84…104: its middle (94) is next.
  #expect(ContReorder.target(from: 1, pointer: 90, spans: rows, dragged: [0], count: 4) == 1)
  #expect(ContReorder.target(from: 1, pointer: 120, spans: rows, dragged: [0], count: 4) == 3)
  // A jump across several rows at once lands in one go.
  #expect(ContReorder.target(from: 0, pointer: 120, spans: rows, dragged: [0], count: 4) == 3)
}

@Test func reorderTargetTurnsBackOnlyPastTheRowAsDrawn() {
  let rows = spans([20, 60, 20, 20])
  // The tall row 1 dragged up past row 0 (its middle at 10).
  #expect(ContReorder.target(from: 1, pointer: 15, spans: rows, dragged: [1], count: 4) == 1)
  #expect(ContReorder.target(from: 1, pointer: 9, spans: rows, dragged: [1], count: 4) == 0)
  // Row 0 is drawn below it now (62…82): back down only past 72, not past where row 0 was.
  #expect(ContReorder.target(from: 0, pointer: 15, spans: rows, dragged: [1], count: 4) == 0)
  #expect(ContReorder.target(from: 0, pointer: 71, spans: rows, dragged: [1], count: 4) == 0)
  #expect(ContReorder.target(from: 0, pointer: 73, spans: rows, dragged: [1], count: 4) == 1)
}

@Test func reorderCollapsedGroupCountsAsOneRow() {
  let rows = spans([20, 60, 20])  // 0…20, 22…82, 84…104
  // The tall group 1 dragged, counted as 20 tall: the row after it slides up into its room at once.
  #expect(ContReorder.offsets(spans: rows, count: 3, dragged: [1], target: 1, draggedLength: 20) == [2: -40])
  // And it passes that row (drawn at 44…64) at its middle, 54, not 94.
  #expect(ContReorder.target(from: 1, pointer: 55, spans: rows, dragged: [1], count: 3, draggedLength: 20) == 2)
  #expect(ContReorder.target(from: 1, pointer: 55, spans: rows, dragged: [1], count: 3) == 1)
}

@Test func reorderTargetStopsAtRowsOffScreen() {
  var rows = spans([20, 20, 20, 20, 20])
  rows[2] = nil
  #expect(ContReorder.target(from: 0, pointer: 100, spans: rows, dragged: [0], count: 5) == 1)
  #expect(ContReorder.home(dragged: [1, 3], anchor: 3) == 2)
}

@Test func reorderOffsetsSlideRowsOutOfTheWay() {
  let rows = spans([20, 60, 20])  // 0…20, 22…82, 84…104
  // The short row 0 dragged below the tall one: the tall one slides up by the short row and its gap, and row 0 takes
  // its place below it.
  let down = ContReorder.offsets(spans: rows, count: 3, dragged: [0], target: 1)
  #expect(down == [1: -22, 0: 62])
  // Where they started: nothing slides.
  #expect(ContReorder.offsets(spans: rows, count: 3, dragged: [0], target: 0).isEmpty)
  // The tall row dragged to the top.
  #expect(ContReorder.offsets(spans: rows, count: 3, dragged: [1], target: 0) == [1: -22, 0: 62])
}

@Test func reorderLandingGathersRowsDraggedTogether() {
  let rows = ["a", "b", "c", "d", "e", "f"]
  #expect(landed(rows, dragging: [1, 3], anchor: 3, target: 4) == ["a", "c", "e", "f", "b", "d"])
  #expect(landed(rows, dragging: [1, 3], anchor: 1, target: 2) == ["a", "c", "b", "d", "e", "f"])
  #expect(landed(rows, dragging: [2, 4], anchor: 2, target: 0) == ["c", "e", "a", "b", "d", "f"])
  #expect(landed(rows, dragging: [1, 3], anchor: 1, target: 1) == ["a", "b", "d", "c", "e", "f"])
}

@Test func reorderLandingOfOneRowMatchesTheSingleRowMove() {
  // Row 1 dropped after row 3 (its place among the others: 3).
  let step = ContReorder.landing(count: 5, dragged: [1], anchor: 1, target: 3)
  #expect(step?.destination == ContReorder.destination(from: 1, to: 3))
  #expect(step?.anchor == 3)
  #expect(ContReorder.landing(count: 5, dragged: [3], anchor: 3, target: 0)?.destination == 0)
}

@Test func reorderLandingWhereTheRowsAreIsNone() {
  #expect(ContReorder.landing(count: 4, dragged: [2], anchor: 2, target: 2) == nil)
  #expect(ContReorder.landing(count: 4, dragged: [1, 2], anchor: 2, target: 1) == nil)
  #expect(ContReorder.landing(count: 4, dragged: [], anchor: 0, target: 1) == nil)
}

@MainActor @Test func reorderStateTracksRowsDraggedTogether() {
  let state = ContReorderState()
  state.begin("files", at: 3, with: [1, 3])
  #expect(state.count == 2)
  #expect(state.isDragging("files", at: 1) && state.isDragging("files", at: 3))
  state.update(indices: [4, 5], anchor: 5)
  #expect(state.index == 5 && !state.isDragging("files", at: 1))
  // A group without the dragged row is not the drag: the row goes alone.
  state.begin("files", at: 2, with: [1, 3])
  #expect(state.count == 1 && state.isDragging("files", at: 2))
  state.end()
  #expect(state.count == 0)
}

@MainActor @Test func reorderStateSlidesRowsFromTheirFrames() {
  let state = ContReorderState()
  let frames = [CGRect(x: 0, y: 0, width: 100, height: 20), CGRect(x: 0, y: 22, width: 100, height: 60)]
  let rows = frames.map { frame in
    let geometry = ContRowGeometry()
    geometry.frame = frame
    return geometry
  }
  for (index, row) in rows.enumerated() { state.register(row, in: "hosts", at: index) }
  state.start("hosts", at: 0, axis: .vertical)
  // Held at its middle, then moved down 43: its middle is at 53, past the tall row's (52).
  state.retarget("hosts", count: 2, pointer: CGPoint(x: 10, y: 10))
  #expect(state.target == 0)
  state.retarget("hosts", count: 2, pointer: CGPoint(x: 10, y: 53))
  #expect(state.target == 1)
  #expect(state.offset("hosts", at: 1) == -22 && state.offset("hosts", at: 0) == 62)
  #expect(state.offset("other", at: 1) == 0)
  var moved: (IndexSet, Int)?
  state.land(in: "hosts", count: 2) { moved = ($0, $1) }
  #expect(moved?.0 == [0] && moved?.1 == 2)
  // Moved, row 0 is row 1 now, and nothing slides: the rows sit where they were drawn.
  #expect(state.isDragging("hosts", at: 1) && state.offsets.isEmpty)
  state.end()
  #expect(state.offset("hosts", at: 1) == 0)
}

@MainActor @Test func reorderPlacesTheDragByItsImagesMiddle() {
  let state = ContReorderState()
  for (index, y) in [0.0, 22, 44].enumerated() {
    let geometry = ContRowGeometry()
    geometry.frame = CGRect(x: 0, y: y, width: 100, height: 20)
    state.register(geometry, in: "rows", at: index)
  }
  // Row 2 (44…64) held near its bottom edge (63) and moved up to 40: the pointer is still in row 1's lower half, but
  // the row's middle (31) has passed row 1's (32).
  state.start("rows", at: 2, axis: .vertical)
  state.retarget("rows", count: 3, pointer: CGPoint(x: 10, y: 63))
  state.retarget("rows", count: 3, pointer: CGPoint(x: 10, y: 40))
  #expect(state.target == 1)
  state.end()
}

@MainActor @Test func reorderStateHoldsACollapsedGroupsRowsUntilTheDragEnds() {
  let state = ContReorderState()
  for (index, height) in [20.0, 60, 20].enumerated() {
    let geometry = ContRowGeometry()
    geometry.frame = CGRect(x: 0, y: [0.0, 22, 84][index], width: 100, height: height)
    state.register(geometry, in: "hosts", at: index)
  }
  // The tall group 1, collapsed to 20, dragged above row 0.
  state.start("hosts", at: 1, axis: .vertical, collapsedLength: 20)
  state.retarget("hosts", count: 3, pointer: CGPoint(x: 10, y: 32))
  state.retarget("hosts", count: 3, pointer: CGPoint(x: 10, y: 9))
  #expect(state.target == 0)
  state.land(in: "hosts", count: 3) { _, _ in }
  // Rows 0 and 2 (now 1 and 2) stay up under the collapsed group until it sits back in.
  #expect(state.offsets == [1: -40, 2: -40])
  state.end()
  #expect(state.offsets.isEmpty)
}

// MARK: - Drag pasteboard

@Test func dragPasteboardMatchesConformingTypes() {
  let types = ["public.file-url", "public.utf8-plain-text", "dev.v57.componentkit.row", "NSFilenamesPboardType"]
  #expect(ContDragPasteboard.matching(types, accepts: [.fileURL]) == ["public.file-url"])
  #expect(ContDragPasteboard.matching(types, accepts: [.plainText]) == ["public.utf8-plain-text"])
  #expect(ContDragPasteboard.matching(types, accepts: [.url]) == ["public.file-url"])
  #expect(ContDragPasteboard.matching(types, accepts: []).isEmpty)
}

// MARK: - Split visibility

@Test func twoColumnToggleHidesAndShowsTheSidebar() {
  #expect(ContSplitVisibility.toggled(.all, threeColumns: false) == .detailOnly)
  #expect(ContSplitVisibility.toggled(.automatic, threeColumns: false) == .detailOnly)
  #expect(ContSplitVisibility.toggled(.detailOnly, threeColumns: false) == .all)
}

@Test func threeColumnToggleKeepsTheContentColumn() {
  #expect(ContSplitVisibility.toggled(.all, threeColumns: true) == .doubleColumn)
  #expect(ContSplitVisibility.toggled(.automatic, threeColumns: true) == .doubleColumn)
  #expect(ContSplitVisibility.toggled(.doubleColumn, threeColumns: true) == .all)
  #expect(ContSplitVisibility.toggled(.detailOnly, threeColumns: true) == .all)
}

@Test func sidebarCountsAsHiddenWhereTheSplitKeepsItOut() {
  let hidden = ContSplitVisibility.sidebarIsHidden
  #expect(hidden(.detailOnly, false, false, false))
  #expect(!hidden(.doubleColumn, false, true, true))
  #expect(hidden(.doubleColumn, true, true, false))
  #expect(!hidden(.all, true, true, true))
  // `.automatic`: on iPad in portrait, or in a three-column split; never on the Mac.
  #expect(hidden(.automatic, false, true, true))
  #expect(!hidden(.automatic, false, true, false))
  #expect(hidden(.automatic, true, true, false))
  #expect(!hidden(.automatic, true, false, false))
}

@Test func automaticVisibilityIsToldApart() {
  #expect(ContSplitVisibility.isAutomatic(.automatic))
  #expect(!ContSplitVisibility.isAutomatic(.doubleColumn))
  #expect(!ContSplitVisibility.isAutomatic(.all))
}

#if canImport(AppKit)
  import AppKit

  /// The kit's toolbar clears the title bar of a window the app made itself (Database's capture window, an
  /// `NSHostingController` that bridges its toolbar, so it has one), when its content runs under the title bar.
  @MainActor @Test func kitToolbarClearsAppMadeWindowsTitlebar() {
    let window = NSWindow(
      contentRect: CGRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled, .fullSizeContentView],
      backing: .buffered, defer: true)
    window.toolbar = NSToolbar()
    #expect(ContTitlebarClearView.clearsTitlebar(of: window))
    window.titlebarAppearsTransparent = true
    #expect(!ContTitlebarClearView.clearsTitlebar(of: window))
    let below = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
    #expect(!ContTitlebarClearView.clearsTitlebar(of: below))
  }
#endif

// MARK: - Reorderable outline

private struct Node: Identifiable {
  let id: String
  var children: [Node]?
}

/// Sources/ (open: App.swift, Views/ (closed: List.swift)), README.md
private let tree = [
  Node(id: "Sources", children: [Node(id: "App.swift"), Node(id: "Views", children: [Node(id: "List.swift")])]),
  Node(id: "README.md"),
]

@Test func outlineRowsListTheOpenRows() {
  let rows = ContOutlineRows.flatten(tree, children: \.children, expanded: ["Sources"])
  #expect(rows.entries.map(\.id) == ["Sources", "App.swift", "Views", "README.md"])
  #expect(rows.entries.map(\.depth) == [0, 1, 1, 0])
  #expect(rows.entries[0].end == 3 && rows.entries[2].end == 3)
  #expect(rows.entries.map(\.isFolder) == [true, false, true, false])
}

@Test func outlineDropJoinsTheFolderOfTheRowAfterIt() {
  let rows = ContOutlineRows.flatten(tree, children: \.children, expanded: ["Sources"])
  // README dropped before Views: into Sources, at Views' place.
  #expect(rows.destination(of: [3], before: 2) == ("Sources", 1))
  // README dropped right after the open Sources: its first child.
  #expect(rows.destination(of: [3], before: 1) == ("Sources", 0))
  // App.swift dropped at the end: the top level's end.
  #expect(rows.destination(of: [1], before: 4) == (nil, 2))
  // Sources (with its open rows) dropped after README.
  #expect(rows.destination(of: [0, 1, 2], before: 4) == (nil, 2))
  #expect(rows.destination(of: [3], before: 0) == (nil, 0))
}

@Test func outlineDropIntoAFolderGoesToItsEnd() {
  let rows = ContOutlineRows.flatten(tree, children: \.children, expanded: ["Sources"])
  var moved: (String, String?, Int)?
  rows.nest([3], into: 2) { moved = ($0, $1, $2) }
  #expect(moved?.0 == "README.md" && moved?.1 == "Views" && moved?.2 == 1)
}

@Test func outlinePlaceGoesIntoTheMiddleOfAFolderRow() {
  let rows = spans([20, 20, 20])  // 0…20, 22…42, 44…64
  let folder: (Int) -> Bool = { $0 == 1 }
  // Row 0 dragged down over the folder (row 1): into it between its quarters (27…37), past it beyond 37.
  #expect(ContReorder.place(from: 0, pointer: 25, spans: rows, dragged: [0], count: 3, nests: folder) == (0, nil))
  #expect(ContReorder.place(from: 0, pointer: 32, spans: rows, dragged: [0], count: 3, nests: folder) == (0, 1))
  #expect(ContReorder.place(from: 0, pointer: 38, spans: rows, dragged: [0], count: 3, nests: folder) == (1, nil))
}

@Test func outlineLevelsBetweenAFoldersLastRowAndWhatFollows() {
  // Sources/ (open: App.swift, Views/ (closed)), README.md
  let rows = ContOutlineRows.flatten(tree, children: \.children, expanded: ["Sources"])
  // README dragged to its own place after Views: Sources' level or the top.
  #expect(rows.levels(for: [3], at: 3) == 0...1)
  // App.swift dragged to the end, after README: the top only.
  #expect(rows.levels(for: [1], at: 3) == 0...0)
  // Between the open Sources and its first row: inside only.
  #expect(rows.levels(for: [3], at: 1) == 1...1)
  // Views dragged out of Sources' end at the top level, in place: a move to after Sources.
  #expect(rows.destination(of: [2], before: 3, level: 0) == (nil, 1))
  // README taken into Sources at its end, in place.
  #expect(rows.destination(of: [3], before: 4, level: 1) == ("Sources", 2))
}

@Test func outlineDropIntoAnOpenEmptyFolder() {
  let tree = [Node(id: "Empty", children: []), Node(id: "a.txt")]
  let rows = ContOutlineRows.flatten(tree, children: \.children, expanded: ["Empty"])
  #expect(rows.levels(for: [1], at: 1) == 0...1)
  #expect(rows.destination(of: [1], before: 2, level: 1) == ("Empty", 0))
}

@MainActor @Test func reorderStateFollowsRowsComingAndGoing() {
  let state = ContReorderState()
  state.start("tree", at: 5, axis: .vertical)
  state.retargetForTesting(target: 4)
  // A folder at 1 opens 2 rows above the dragged row and its place: both move down.
  state.insertRows("tree", at: 2, count: 2)
  #expect(state.index == 7 && state.target == 6)
  state.removeRows("tree", 2..<4)
  #expect(state.index == 5 && state.target == 4)
  // Rows opening below the place leave it.
  state.insertRows("tree", at: 6, count: 3)
  #expect(state.index == 5 && state.target == 4)
  state.end()
}

@Test func outlineReceiverIsTheFolderAtTheLevel() {
  let rows = ContOutlineRows.flatten(tree, children: \.children, expanded: ["Sources"])
  // README in place after Views: Sources at level 1, the top at 0.
  #expect(rows.receiver(of: [3], at: 3, level: 1) == 0)
  #expect(rows.receiver(of: [3], at: 3, level: 0) == nil)
}

@Test func reorderPredictsRowsComingAndGoing() {
  let rows = spans([20, 20, 20])  // 0…20, 22…42, 44…64
  // Two rows open after row 0: they take its size, and rows 1 and 2 (now 3 and 4) move down by two rows.
  let opened = ContReorder.inserting(2, at: 1, into: rows)
  #expect(opened[1] == .init(start: 22, length: 20) && opened[2] == .init(start: 44, length: 20))
  #expect(opened[3] == .init(start: 66, length: 20) && opened[4] == .init(start: 88, length: 20))
  // And close again.
  #expect(ContReorder.removing(1..<3, from: opened) == rows)
}

@MainActor @Test func reorderStateSlidesAtOnceAsAFolderOpens() {
  let state = ContReorderState()
  for (index, y) in [0.0, 22, 44].enumerated() {
    let geometry = ContRowGeometry()
    geometry.frame = CGRect(x: 0, y: y, width: 100, height: 20)
    state.register(geometry, in: "tree", at: index)
  }
  // Row 2 dragged up to just after row 0 (a folder), which opens two rows.
  state.start("tree", at: 2, axis: .vertical, collapsedLength: 20)
  state.retarget("tree", count: 3, pointer: CGPoint(x: 10, y: 54))
  state.retarget("tree", count: 3, pointer: CGPoint(x: 10, y: 31))
  #expect(state.target == 1)
  state.insertRows("tree", at: 1, count: 2)
  // The slot stays under the folder: the two new rows and row 1 (now 3) slide down below it at once.
  #expect(state.index == 4 && state.target == 1)
  #expect(state.offsets[1] == 22 && state.offsets[2] == 22 && state.offsets[3] == 22 && state.offsets[4] == -66)
  state.end()
}

@MainActor @Test func reorderPointerBetweenRowsStaysOnTheList() async {
  let state = ContReorderState()
  for (index, y) in [0.0, 22, 44].enumerated() {
    let geometry = ContRowGeometry()
    geometry.frame = CGRect(x: 0, y: y, width: 100, height: 20)
    state.register(geometry, in: "rows", at: index)
  }
  state.start("rows", at: 0, axis: .vertical)
  state.retarget("rows", count: 3, pointer: CGPoint(x: 10, y: 10))
  state.retarget("rows", count: 3, pointer: CGPoint(x: 10, y: 33))
  #expect(state.target == 1)
  // The pointer rests in the gap between rows 1 and 2: still the list's.
  state.leave("rows", at: CGPoint(x: 10, y: 43))
  try? await Task.sleep(for: .milliseconds(200))
  #expect(state.target == 1)
  // Off the list: the rows slide back.
  state.leave("rows", at: CGPoint(x: 10, y: 120))
  try? await Task.sleep(for: .milliseconds(200))
  #expect(state.target == nil)
  state.end()
}

@MainActor @Test func reorderNamesTheDropOnlyAtALastPlaceOnceItLeavesHome() {
  let state = ContReorderState()
  for (index, y) in [0.0, 22, 44, 66].enumerated() {
    let geometry = ContRowGeometry()
    geometry.frame = CGRect(x: 0, y: y, width: 100, height: 20)
    state.register(geometry, in: "tree", at: index)
  }
  // Row 0 is a folder holding rows 1…3; row 3, its last, is dragged. Its own place is a last place (inside or out).
  let levels = ContReorderLevels(
    range: { _, target in target == 3 ? 0...1 : 1...1 }, home: { _ in 1 },
    receiver: { _, _, level in level == 1 ? 0 : nil },
    title: { $0 == nil ? "Top" : "Folder" }, isOrigin: { _, receiver in receiver == 0 }, step: 14)
  state.start("tree", at: 3, axis: .vertical)
  state.retarget("tree", count: 4, pointer: CGPoint(x: 50, y: 76), levels: levels)
  #expect(state.level == 1 && state.hint == nil)
  // Out to the top level: a new destination, named.
  state.retarget("tree", count: 4, pointer: CGPoint(x: 30, y: 76), levels: levels)
  #expect(state.level == 0 && state.hint == "Top")
  // Back in: named now too.
  state.retarget("tree", count: 4, pointer: CGPoint(x: 50, y: 76), levels: levels)
  #expect(state.hint == "Folder")
  // Up between rows 1 and 2: one level only, nothing to name.
  state.retarget("tree", count: 4, pointer: CGPoint(x: 50, y: 40), levels: levels)
  #expect(state.target == 2 && state.hint == nil)
  state.end()
}
