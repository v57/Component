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
  state.update(index: 0)
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

/// Applies a group move to `rows` and checks the dragged rows end up where `groupMove` says.
private func groupMoved(_ rows: [String], dragging: IndexSet, anchor: Int, to: Int) -> [String]? {
  guard let step = ContReorder.groupMove(indices: dragging, anchor: anchor, to: to) else { return nil }
  let dragged = dragging.map { rows[$0] }
  var rows = rows
  rows.move(fromOffsets: dragging, toOffset: step.destination)
  #expect(step.indices.map { rows[$0] } == dragged)
  #expect(rows[step.anchor] == dragged[dragging.count(in: 0..<anchor)])
  return rows
}

@Test func groupMoveGathersRowsAfterTheTargetGoingDown() {
  let rows = ["a", "b", "c", "d", "e", "f"]
  #expect(groupMoved(rows, dragging: [1, 3], anchor: 3, to: 5) == ["a", "c", "e", "f", "b", "d"])
  #expect(groupMoved(rows, dragging: [1, 3], anchor: 1, to: 2) == ["a", "c", "b", "d", "e", "f"])
}

@Test func groupMoveGathersRowsBeforeTheTargetGoingUp() {
  let rows = ["a", "b", "c", "d", "e", "f"]
  #expect(groupMoved(rows, dragging: [2, 4], anchor: 2, to: 0) == ["c", "e", "a", "b", "d", "f"])
  #expect(groupMoved(rows, dragging: [1, 3], anchor: 3, to: 2) == ["a", "b", "d", "c", "e", "f"])
}

@Test func groupMoveIgnoresTheDraggedRows() {
  #expect(ContReorder.groupMove(indices: [1, 3], anchor: 1, to: 3) == nil)
  #expect(ContReorder.groupMove(indices: [], anchor: 0, to: 1) == nil)
}

@Test func groupMoveOfOneRowMatchesTheSingleRowMove() {
  for (from, to) in [(1, 3), (3, 0), (0, 4)] {
    let step = ContReorder.groupMove(indices: [from], anchor: from, to: to)
    #expect(step?.destination == ContReorder.destination(from: from, to: to))
    #expect(step?.anchor == to)
  }
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
