import SwiftUI
import Testing

@testable import ComponentKit

@MainActor @Test func menuFilterTakesTextAndDeleteButNotKeys() {
  let model = KitMenuModel()
  // Without a filter field nothing is typed into it (a number key picks its row instead).
  #expect(!model.type("1", isDelete: false))
  model.hasFilter = true
  #expect(model.type("l", isDelete: false))
  #expect(model.type("sp", isDelete: false))
  #expect(model.query == "lsp")
  #expect(model.type("", isDelete: true))
  #expect(model.query == "ls")
  // Arrows arrive as private-use characters, Return and Tab as control characters: they stay the menu's.
  #expect(!model.type("\u{F700}", isDelete: false))
  #expect(!model.type("\r", isDelete: false))
  #expect(!model.type("\t", isDelete: false))
  #expect(model.query == "ls")
  #expect(model.isFiltering)
  model.query = ""
  #expect(!model.isFiltering)
  #expect(model.type("", isDelete: true))
}

@MainActor @Test func submenuFiltersWithItsParentsText() {
  let parent = KitMenuModel()
  let child = KitMenuModel()
  child.parent = parent
  parent.hasFilter = true
  parent.query = "lib"
  #expect(child.isFiltering)
  #expect(child.rootQuery == "lib")
}

@MainActor @Test func previewPanelShowsTheHighlightedRowsSentenceElseTheSummary() {
  let model = KitMenuModel()
  #expect(!model.hasPreviews)
  let pull = UUID()
  let fetch = UUID()
  model.update(pull) { $0.preview = KitMenuPreviewItem(text: "Brings 3 commits.") }
  model.update(fetch) { _ in }
  #expect(model.hasPreviews)
  #expect(model.activePreview == nil)
  model.summary = KitMenuPreviewItem(text: "Trips, on main.")
  #expect(model.activePreview?.text == "Trips, on main.")
  model.highlight(pull)
  #expect(model.activePreview?.text == "Brings 3 commits.")
  // A row without a sentence shows the summary.
  model.highlight(fetch)
  #expect(model.activePreview?.text == "Trips, on main.")
  #expect(model.previews.count == 2)
}

@MainActor @Test func menuMovesThroughTilesInReadingOrder() {
  let model = KitMenuModel()
  let ids = (0..<4).map { _ in UUID() }
  // Two lines of two tiles, registered out of order.
  let frames = [CGRect(x: 100, y: 0, width: 90, height: 60), CGRect(x: 0, y: 62, width: 90, height: 60),
    CGRect(x: 0, y: 0, width: 90, height: 60), CGRect(x: 100, y: 62, width: 90, height: 60)]
  for (id, frame) in zip(ids, frames) {
    model.update(id) { _ in }
    model.setFrame(id, frame)
  }
  model.move(by: 1)
  #expect(model.highlighted == ids[2])
  model.move(by: 1)
  #expect(model.highlighted == ids[0])
  model.move(by: 1)
  #expect(model.highlighted == ids[1])
  model.move(by: 1)
  #expect(model.highlighted == ids[3])
}
