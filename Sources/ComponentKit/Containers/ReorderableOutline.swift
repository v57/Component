import SwiftUI

// A tree whose rows drag: `KitOutline`'s rows on `ReorderableSection`'s reordering. The tree is drawn as one flat list
// of the rows on screen (an open folder's rows follow it), so a drag slides the rows as in any list. A dragged folder
// takes its open rows along, counted as one row; dropped beside a row it joins that row's folder, and over the middle
// of a folder row it goes into it. Held over a closed folder, the folder opens, and closes again if the drag moves
// back above it. Where a place sits between levels (after a folder's last row), moving the drag across picks one,
// and the slot moves in to show it.

/// A tree of rows, like `KitOutline`, that reorders by dragging: a row dropped between two others joins their folder,
/// one dropped onto the middle of a folder row goes into that folder (at its end), and a folder carries its rows
/// along. A closed folder held under the drag opens (and closes again when the drag moves back above it); after a
/// folder's last row, dragging left or right picks whether the row lands inside the folder or beside it. `move` gets the dragged item, its new parent (`nil`: the top level) and its place among that parent's
/// children as they are before the move (`.onMove`'s `toOffset`).
///
/// ```swift
/// ReorderableOutline(files, children: \.children, move: { id, parent, index in tree.move(id, into: parent, at: index) }) { file in
///   SidebarRow(value: file.id, file.name, systemImage: file.children == nil ? "doc" : "folder")
/// }
/// ```
public struct ReorderableOutline<Element: Identifiable, RowContent: View>: View {
  let items: [Element]
  let children: KeyPath<Element, [Element]?>
  let expanded: Binding<Set<Element.ID>>?
  let move: (Element.ID, Element.ID?, Int) -> Void
  let row: (Element) -> RowContent
  @State private var ownExpanded: Set<Element.ID> = []
  @State private var list = UUID()
  /// The folders the drag opened, which close again when it moves back above them, and where the drag image's
  /// middle was as the drag's place went above each.
  @State private var springOpened: [Element.ID] = []
  @State private var passedAbove: [Element.ID: CGFloat] = [:]
  @Environment(\.contRowIndent) private var baseIndent
  @Environment(\.contReorderState) private var shared
  @Environment(\.kitIdiom) private var idiom

  /// An outline of `items` (`children` is `nil` for a leaf); `expanded` keeps the ids of the open folders, else the
  /// outline keeps them.
  public init(
    _ items: some RandomAccessCollection<Element>, children: KeyPath<Element, [Element]?>,
    expanded: Binding<Set<Element.ID>>? = nil,
    move: @escaping (_ item: Element.ID, _ parent: Element.ID?, _ index: Int) -> Void,
    @ViewBuilder row: @escaping (Element) -> RowContent
  ) {
    self.items = Array(items)
    self.children = children
    self.expanded = expanded
    self.move = move
    self.row = row
  }

  public var body: some View {
    let open = expanded ?? $ownExpanded
    let rows = ContOutlineRows.flatten(items, children: children, expanded: open.wrappedValue)
    let state = shared ?? .app
    let levels = ContReorderLevels(
      range: { rows.levels(for: $0, at: $1) }, home: { $0.first.map { rows.entries[$0].depth } ?? 0 },
      receiver: { rows.receiver(of: $0, at: $1, level: $2) },
      moved: { springClose(above: $0, in: open, state: state) }, step: ContMetrics.rowIndent(idiom))
    ForEach(rows.entries) { entry in
      let id = entry.id
      row(entry.element)
        .environment(\.contRowIndent, baseIndent + entry.depth)
        .environment(
          \.contRowDisclosure,
          ContRowDisclosure(
            isExpanded: entry.isFolder
              ? Binding(
                get: { open.wrappedValue.contains(id) },
                set: { isOpen in
                  if isOpen { open.wrappedValue.insert(id) } else { open.wrappedValue.remove(id) }
                })
              : nil)
        )
        .modifier(
          ContReorderRow(
            list: list, index: entry.index, move: { rows.move($0, to: $1, level: state.level, move) }, state: state,
            group: entry.end > entry.index + 1 ? IndexSet(integersIn: entry.index..<entry.end) : nil,
            count: rows.entries.count, collapses: true, nests: { rows.entries[$0].isFolder },
            nest: { rows.nest($0, into: $1, move) }, levels: levels))
        // Held over, a closed folder opens.
        .task(id: entry.isFolder && !entry.isOpen && state.isInto(list, at: entry.index)) {
          guard entry.isFolder, !entry.isOpen, state.isInto(list, at: entry.index) else { return }
          try? await Task.sleep(for: .milliseconds(600))
          guard !Task.isCancelled, state.isInto(list, at: entry.index) else { return }
          springOpen(entry.id, in: open, state: state)
        }
        // Once for the outline (a ForEach's modifiers go to each row).
        .onChange(of: entry.index == 0 && state.list == nil) { _, ended in
          if ended {
            springOpened = []
            passedAbove = [:]
          }
        }
    }
  }

  /// Opens a folder under the drag; the rows it shows move the drag's rows down.
  private func springOpen(_ id: Element.ID, in open: Binding<Set<Element.ID>>, state: ContReorderState) {
    let rows = ContOutlineRows.flatten(items, children: children, expanded: open.wrappedValue)
    guard let entry = rows.entries.first(where: { $0.id == id }) else { return }
    let after = ContOutlineRows.flatten(items, children: children, expanded: open.wrappedValue.union([id]))
    withAnimation(.kit) {
      open.wrappedValue.insert(id)
      springOpened.append(id)
      state.insertRows(list, at: entry.index + 1, count: after.entries.count - rows.entries.count)
    }
  }

  /// Closes the folders the drag opened once the drag's place is above them and the drag image has gone on up a slot's
  /// length (the last opened first, as they nest), so a folder doesn't close as the drag only grazes it. `true` when
  /// one closed.
  private func springClose(above middle: CGFloat, in open: Binding<Set<Element.ID>>, state: ContReorderState) -> Bool {
    var closed = false
    for id in springOpened.reversed() {
      let rows = ContOutlineRows.flatten(items, children: children, expanded: open.wrappedValue)
      guard let entry = rows.entries.first(where: { $0.id == id }) else {
        springOpened.removeAll { $0 == id }
        continue
      }
      let place = (0..<entry.index).filter { !state.indices.contains($0) }.count
      guard let target = state.target, target <= place else {
        if passedAbove[id] != nil { passedAbove[id] = nil }
        continue
      }
      guard let passed = passedAbove[id] else {
        passedAbove[id] = middle
        continue
      }
      guard middle < passed - state.slotLength else { continue }
      withAnimation(.kit) {
        open.wrappedValue.remove(id)
        springOpened.removeAll { $0 == id }
        passedAbove[id] = nil
        state.removeRows(list, (entry.index + 1)..<entry.end)
      }
      closed = true
    }
    return closed
  }
}

/// An outline's rows on screen, in order, and the tree moves their drops make.
struct ContOutlineRows<Element: Identifiable> {
  struct Entry: Identifiable {
    let element: Element
    /// Its place in the flat list, and past its open rows.
    let index: Int
    var end: Int
    let depth: Int
    let parent: Element.ID?
    /// Its place among its parent's children.
    let place: Int
    /// How many children it has (`nil`: a leaf).
    let childCount: Int?
    /// It's an open folder.
    let isOpen: Bool
    var id: Element.ID { element.id }
    var isFolder: Bool { childCount != nil }
  }

  var entries: [Entry] = []
  /// How many items the top level has.
  var rootCount = 0

  static func flatten(_ items: [Element], children: KeyPath<Element, [Element]?>, expanded: Set<Element.ID>) -> Self {
    var rows = Self(rootCount: items.count)
    func add(_ items: [Element], depth: Int, parent: Element.ID?) {
      for (place, item) in items.enumerated() {
        let kids = item[keyPath: children]
        let index = rows.entries.count
        let isOpen = kids != nil && expanded.contains(item.id)
        rows.entries.append(
          Entry(
            element: item, index: index, end: index + 1, depth: depth, parent: parent, place: place,
            childCount: kids?.count, isOpen: isOpen))
        if let kids, isOpen {
          add(kids, depth: depth + 1, parent: item.id)
          rows.entries[index].end = rows.entries.count
        }
      }
    }
    add(items, depth: 0, parent: nil)
    return rows
  }

  /// The rows beside the place `target` among the rows not `dragged`.
  private func neighbours(of dragged: IndexSet, at target: Int) -> (before: Entry?, after: Entry?) {
    let others = entries.indices.filter { !dragged.contains($0) }
    return (target > 0 ? entries[others[target - 1]] : nil, target < others.count ? entries[others[target]] : nil)
  }

  /// The levels the `dragged` rows may land at in the place `target`: the level of the row after it at least (they
  /// can't come between a row and its folder), and at most the row before's, or one in when that row is an open
  /// folder (its first row, or the only one of an empty folder).
  func levels(for dragged: IndexSet, at target: Int) -> ClosedRange<Int> {
    let (before, after) = neighbours(of: dragged, at: target)
    let lowest = after?.depth ?? 0
    let highest = before.map { $0.isOpen ? $0.depth + 1 : $0.depth } ?? 0
    return lowest...max(lowest, highest)
  }

  /// The folder row (its index) the `dragged` rows go into at the place `target` and `level`; `nil` for the top level.
  func receiver(of dragged: IndexSet, at target: Int, level: Int) -> Int? {
    let others = entries.indices.filter { !dragged.contains($0) }
    let destination = target < others.count ? others[target] : entries.count
    guard let parent = self.destination(of: dragged, before: destination, level: level).parent else { return nil }
    return entries.firstIndex { $0.id == parent }
  }

  /// The drop of the rows `dragged` (a row and its open rows) before the row at `destination` (`.onMove`'s
  /// arguments for the flat list), at `level`: beside the row after it when that row is at the level, else at the end
  /// of the folder before it that holds the level. Without a level, the row after it decides.
  func destination(of dragged: IndexSet, before destination: Int, level: Int? = nil) -> (parent: Element.ID?, index: Int) {
    let before = (0..<destination).last { !dragged.contains($0) }.map { entries[$0] }
    let after = destination < entries.count ? entries[destination] : nil
    let level = level ?? after?.depth ?? 0
    if let after, after.depth == level { return (after.parent, after.place) }
    guard let before else { return (nil, 0) }
    if level > before.depth { return (before.id, before.childCount ?? 0) }
    // The row before's folder at that level (or the row itself): the drop follows it.
    var holder = before.index
    while entries[holder].depth > level, holder > 0 { holder -= 1 }
    let sibling = entries[holder]
    return (sibling.parent, sibling.place + 1)
  }

  func move(_ dragged: IndexSet, to destination: Int, level: Int? = nil, _ move: (Element.ID, Element.ID?, Int) -> Void) {
    guard let first = dragged.first else { return }
    let (parent, index) = self.destination(of: dragged, before: destination, level: level)
    // In place at its own level: nothing moves.
    if parent == entries[first].parent, index == entries[first].place || index == entries[first].place + 1 { return }
    move(entries[first].id, parent, index)
  }

  func nest(_ dragged: IndexSet, into folder: Int, _ move: (Element.ID, Element.ID?, Int) -> Void) {
    guard let first = dragged.first, entries.indices.contains(folder) else { return }
    move(entries[first].id, entries[folder].id, entries[folder].childCount ?? 0)
  }
}
