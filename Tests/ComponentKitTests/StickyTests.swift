import SwiftUI
import Testing

@testable import ComponentKit

// MARK: - Sticky sections

/// A sidebar like Git's: a long list, the open repository's card, two sections that wait at the bottom by title.
private func gitTable(atlasRows: CGFloat = 100) -> ContStickyTable {
  ContStickyTable(
    items: [
      ContStickyItem(
        id: "repositories", sticky: ContSticky(top: .titleWhileVisible, bottom: .none), minY: 0, maxY: 2000,
        titleTop: 0, titleHeight: 50),
      ContStickyItem(
        id: "atlas", sticky: ContSticky(top: .titleWhileVisible, bottom: .content), minY: 2010,
        maxY: 2010 + 50 + atlasRows, titleTop: 2010, titleHeight: 50),
      ContStickyItem(
        id: "branches", sticky: ContSticky(top: .titleWhileVisible, bottom: .title), minY: 2300, maxY: 2500,
        titleTop: 2300, titleHeight: 50),
      ContStickyItem(
        id: "remotes", sticky: ContSticky(top: .titleWhileVisible, bottom: .title), minY: 2510, maxY: 2600,
        titleTop: 2510, titleHeight: 50),
    ],
    spacing: 10, topGap: 0)
}

@Test func stickyBottomStackKeepsItsOrder() {
  // At the top of the list: atlas whole, then the Branches and Remotes titles, ending at the bottom edge.
  let placements = gitTable().placements(visibleTop: 0, visibleBottom: 1000)
  #expect(placements[0] == nil)
  #expect(placements[3] == ContStickyPlacement(edge: .bottom, part: .title, y: 950))
  #expect(placements[2] == ContStickyPlacement(edge: .bottom, part: .title, y: 890))
  #expect(placements[1] == ContStickyPlacement(edge: .bottom, part: .content, y: 730))
}

@Test func stickyBottomStackFallsBackToTitlesPastItsShare() {
  // atlas with 300pt of rows: 350 + 50 + 50 + 20 is more than 40% of 1000, so it shows its title too.
  let placements = gitTable(atlasRows: 300).placements(visibleTop: 0, visibleBottom: 1000)
  #expect(placements[1] == ContStickyPlacement(edge: .bottom, part: .title, y: 830))
  #expect(placements[2]?.part == .title)
  #expect(placements[3]?.part == .title)
}

@Test func stickyBottomItemInPlaceStopsTheStack() {
  // Scrolled so atlas is in view: it and Branches are in place, Remotes still waits.
  let table = gitTable()
  let placements = table.placements(visibleTop: 1500, visibleBottom: 2500)
  #expect(placements[1] == nil)
  #expect(placements[2] == nil)
  #expect(placements[3] == ContStickyPlacement(edge: .bottom, part: .title, y: 2450))
}

@Test func stickyTitleWhileVisibleStaysThenIsPushedUp() {
  let table = gitTable()
  // In the middle of the list: the Repositories title stays at the top.
  #expect(table.placements(visibleTop: 800, visibleBottom: 1800)[0] == ContStickyPlacement(edge: .top, part: .title, y: 800))
  // Near its end: its last row pushes it up.
  #expect(table.placements(visibleTop: 1980, visibleBottom: 2980)[0] == ContStickyPlacement(edge: .top, part: .title, y: 1950))
  // Past its end: gone.
  #expect(table.placements(visibleTop: 2005, visibleBottom: 3005)[0] == nil)
}

@Test func stickyTopStackKeepsItsOrder() {
  let table = ContStickyTable(
    items: [
      ContStickyItem(id: "a", sticky: ContSticky(top: .content, bottom: .none), minY: 0, maxY: 100),
      ContStickyItem(
        id: "b", sticky: ContSticky(top: .title, bottom: .none), minY: 110, maxY: 500, titleTop: 110, titleHeight: 40),
      ContStickyItem(id: "c", sticky: ContSticky(top: .none, bottom: .none), minY: 510, maxY: 900),
    ],
    clearTop: 52, clearBottom: 652, spacing: 8, topGap: 2)
  // Scrolled far down (the stack's top 1052pt above the window's): a whole under the title bar, then b's title under
  // it; c scrolls under them.
  let area = table.visibleArea(naturalTop: 0, hostTop: -1000)
  #expect(area.top == 1052 && area.bottom == 1652)
  let placements = table.placements(visibleTop: area.top, visibleBottom: area.bottom)
  #expect(placements[0] == ContStickyPlacement(edge: .top, part: .content, y: 1054))
  #expect(placements[1] == ContStickyPlacement(edge: .top, part: .title, y: 1162))
  #expect(placements[2] == nil)
  // At the top nothing sticks (the stack starts 2pt below the title bar).
  let top = table.visibleArea(naturalTop: 0, hostTop: 54)
  #expect(table.placements(visibleTop: top.top, visibleBottom: top.bottom).allSatisfy { $0 == nil })
}

@Test func stickyNoneNeverSticks() {
  let table = ContStickyTable(items: [
    ContStickyItem(id: "a", sticky: ContSticky(top: .none, bottom: .none), minY: 2000, maxY: 2100)
  ])
  #expect(table.placements(visibleTop: 0, visibleBottom: 500) == [nil])
  #expect(table.placements(visibleTop: 3000, visibleBottom: 3500) == [nil])
}

@Test func stickyWithoutTitleShowsWhole() {
  // A sticky view that isn't a section (no title reported): `.title` shows all of it.
  let item = ContStickyItem(id: "a", sticky: ContSticky(top: .title, bottom: .title), minY: 100, maxY: 160)
  #expect(item.block(.title) == item.block(.content))
}

@Test func stickyPinsWhatMayShowFromAnywhere() {
  #expect(!ContSticky(top: .titleWhileVisible, bottom: .none).isPinned)
  #expect(!ContSticky(top: .none, bottom: .none).isPinned)
  #expect(ContSticky(top: .title, bottom: .none).isPinned)
  #expect(ContSticky(top: .content, bottom: .none).isPinned)
  #expect(ContSticky(top: .titleWhileVisible, bottom: .title).isPinned)
  #expect(ContStickyState(edge: .top, part: .title, order: 0).zIndex > ContStickyState(edge: .top, part: .title, order: 1).zIndex)
  #expect(ContStickyState(edge: .bottom, part: .title, order: 1).zIndex > ContStickyState(edge: .bottom, part: .title, order: 0).zIndex)
}

@Test func stickyBottomTitlesPastTheShareLetTheFarthestGo() {
  // Six titles of 60pt under a 600pt sidebar: 40% holds three, the nearest; the rest scroll as usual, and no
  // section in view is pushed up.
  let items = (0..<6).map { index in
    ContStickyItem(
      id: AnyHashable(index), sticky: ContSticky(top: .none, bottom: .title), minY: 1000 + CGFloat(index) * 300,
      maxY: 1250 + CGFloat(index) * 300, titleTop: 1000 + CGFloat(index) * 300, titleHeight: 60)
  }
  let table = ContStickyTable(items: items, spacing: 10, topGap: 0)
  let placements = table.placements(visibleTop: 0, visibleBottom: 600)
  #expect(placements.compactMap { $0 }.count == 3)
  #expect(placements[0] == ContStickyPlacement(edge: .bottom, part: .title, y: 400))
  #expect(placements[2] == ContStickyPlacement(edge: .bottom, part: .title, y: 540))
  #expect(placements[3] == nil && placements[5] == nil)
}

@Test func stickyLaysOutItsOwnItemFromWhereItIs() {
  // The table still has Databases far below (its place from a frame before the screen settled); Databases' own
  // view, at 306 in a 608pt sidebar, is in place, not stuck at the bottom.
  let stale = ContStickyTable(
    items: [
      ContStickyItem(
        id: "remote", sticky: ContSticky(top: .titleWhileVisible, bottom: .title), minY: 0, maxY: 290, titleTop: 0,
        titleHeight: 60),
      ContStickyItem(
        id: "databases", sticky: ContSticky(top: .titleWhileVisible, bottom: .title), minY: 1306, maxY: 1510,
        titleTop: 1306, titleHeight: 60),
    ],
    spacing: 16, topGap: 2)
  #expect(stale.placements(visibleTop: -2, visibleBottom: 606)[1] != nil)
  let live = stale.live("databases", part: .title, at: 306)
  #expect(live?.index == 1)
  #expect(live?.table.items[1].minY == 306 && live?.table.items[1].maxY == 510)
  #expect(live?.table.placements(visibleTop: -2, visibleBottom: 606)[1] == nil)
}
