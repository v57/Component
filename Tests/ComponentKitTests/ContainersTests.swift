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
