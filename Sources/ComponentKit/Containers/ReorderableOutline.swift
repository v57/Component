import SwiftUI
import UniformTypeIdentifiers

// A tree whose rows drag: `KitOutline`'s rows on `ReorderableSection`'s reordering. The tree is drawn as one flat list
// of the rows on screen (an open folder's rows follow it), so a drag slides the rows as in any list. A dragged folder
// takes its open rows along, counted as one row; dropped beside a row it joins that row's folder, and over the middle
// of a folder row it goes into it. Held over a closed folder, the folder opens, and closes again if the drag moves
// back above it. Where a place sits between levels (after a folder's last row), moving the drag across picks one,
// and the slot moves in to show it.

/// A tree of rows, like `KitOutline`, that reorders by dragging: a row dropped between two others joins their folder,
/// one dropped onto the middle of a closed folder row goes into that folder (at its end), and a folder carries its
/// rows along. A closed folder held under the drag opens (and closes again when the drag moves back above it); after a
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
  private var title: ((Element) -> String)?
  private var rootTitle: String?
  private let listName: AnyHashable?
  private var receive: ((Element.ID, AnyHashable, Element.ID?, Int) -> Void)?
  private var exportURL: ((Element) -> URL?)?
  private var together: Set<Element.ID> = []
  private var moveTogether: (([Element.ID], Element.ID?, Int) -> Void)?
  private var dropTypes: [UTType] = []
  private var drop: (([NSItemProvider], Element.ID?, Int) -> Bool)?
  @State private var ownExpanded: Set<Element.ID> = []
  @State private var ownList = UUID()
  /// The folders the drag opened, which close again when it moves back above them, and where the drag image's
  /// middle was as the drag's place went above each.
  @State private var springOpened: [Element.ID] = []
  @State private var passedAbove: [Element.ID: CGFloat] = [:]
  @Environment(\.contRowIndent) private var baseIndent
  @Environment(\.contReorderState) private var shared
  @Environment(\.kitIdiom) private var idiom

  /// An outline of `items` (`children` is `nil` for a leaf); `expanded` keeps the ids of the open folders, else the
  /// outline keeps them. `list` names the outline when another takes its items (`receivesItems`).
  public init(
    _ items: some RandomAccessCollection<Element>, children: KeyPath<Element, [Element]?>,
    expanded: Binding<Set<Element.ID>>? = nil, list: AnyHashable? = nil,
    move: @escaping (_ item: Element.ID, _ parent: Element.ID?, _ index: Int) -> Void,
    @ViewBuilder row: @escaping (Element) -> RowContent
  ) {
    self.items = Array(items)
    self.children = children
    self.expanded = expanded
    self.listName = list
    self.move = move
    self.row = row
  }

  public var body: some View {
    let open = expanded ?? $ownExpanded
    let rows = ContOutlineRows.flatten(items, children: children, expanded: open.wrappedValue)
    let state = shared ?? .app
    let list = self.list
    let levels = ContReorderLevels(
      range: { rows.levels(for: $0, at: $1) }, home: { $0.first.map { rows.entries[$0].depth } ?? 0 },
      receiver: { rows.receiver(of: $0, at: $1, level: $2) },
      moved: { springClose(above: $0, in: open, state: state) },
      title: title.map { title in { receiver in receiver.map { title(rows.entries[$0].element) } ?? rootTitle } },
      isOrigin: { dragged, receiver in
        guard let first = dragged.first else { return false }
        return rows.entries[first].parent == receiver.map { rows.entries[$0].id }
      },
      step: ContMetrics.rowIndent(idiom))
    // From another outline, the dragged item comes in before the row it entered, at that row's level.
    let receiving = receive.map { receive in
      { (fromList: AnyHashable, _: Int, index: Int) in
        guard let id = state.item?.base as? Element.ID else { return }
        let (parent, place) = rows.destination(of: [], before: index)
        // Closed: it moves on here as one row, its rows inside it.
        open.wrappedValue.remove(id)
        receive(id, fromList, parent, place)
      }
    }
    if rows.entries.isEmpty, let receiving {
      // Empty, a row's room still takes items from other outlines.
      ContOutlineEmptyDrop(list: list, state: state, receive: receiving)
    }
    // The selection's rows, when several items of it are on screen to drag together.
    let selected = moveTogether == nil ? IndexSet() : rows.together(together)
    let dragsSelection = rows.tops(of: selected).count > 1
    ForEach(rows.entries) { entry in
      let id = entry.id
      let isTogether = dragsSelection && selected.contains(entry.index)
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
            list: list, index: entry.index,
            move: { rows.move($0, to: $1, level: state.level, move, together: moveTogether) }, state: state,
            accepts: drop == nil ? [] : dropTypes, perform: drop.map { dropped(entry, drop: $0) }, receive: receiving,
            group: isTogether
              ? selected : entry.end > entry.index + 1 ? IndexSet(integersIn: entry.index..<entry.end) : nil,
            exportURL: exportURL.map { url in { url(entry.element) } }, count: rows.entries.count,
            // Rows dragged together keep their own heights, as a list's do; a folder counts as its first row.
            collapses: !isTogether,
            // Into closed folders only: an open one's rows show where the drop goes, as its slot.
            nests: { rows.entries[$0].isFolder && !rows.entries[$0].isOpen },
            nest: { rows.nest($0, into: $1, move, together: moveTogether) }, levels: levels,
            item: AnyHashable(entry.id)))
        // Held over, a closed folder opens.
        .task(id: entry.isFolder && !entry.isOpen && state.isInto(list, at: entry.index)) {
          guard entry.isFolder, !entry.isOpen, state.isInto(list, at: entry.index) else { return }
          await kitSleep(for: .milliseconds(600))
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

  /// Names where a drag will drop above the drag image, so the folder shows even when it's out of sight: `title` gives
  /// a folder's name, `root` the top level's (`nil`: nothing over the top level). It shows at a folder's last place,
  /// where dragging across picks the level, once the drop has left the folder the row came from.
  ///
  /// ```swift
  /// ReorderableOutline(files, children: \.children, move: move) { … }
  ///   .dropTitle(root: "Atlas") { $0.name }
  /// ```
  public func dropTitle(root: String? = nil, _ title: @escaping (Element) -> String) -> Self {
    var outline = self
    outline.title = title
    outline.rootTitle = root
    return outline
  }

  /// Lets a row be dragged out of the app as `url` (`nil` for none): a file URL drops into Finder, Mail or Terminal
  /// as the file itself, a web URL as the link. Reordering inside the app goes on as before; a drag of several rows
  /// (`dragsTogether`) carries the URL of the row under the pointer.
  ///
  /// ```swift
  /// ReorderableOutline(projects, children: \.children, move: move) { … }
  ///   .exportsURL { $0.folder }
  /// ```
  public func exportsURL(_ url: @escaping (Element) -> URL?) -> Self {
    var outline = self
    outline.exportURL = url
    return outline
  }

  /// Drags the rows of `selection` together: dragging one of them picks up all those on screen (a folder with its
  /// open rows; the lifted card shows how many), they gather where it passes, and `move` gets them all, top to
  /// bottom, with their new parent and their place among its children as they are before the move (`.onMove`'s
  /// `toOffset`). A row outside the selection still drags alone, through the outline's own `move`. Rows dragged
  /// together stay in their own outline.
  ///
  /// ```swift
  /// ReorderableOutline(files, children: \.children, move: move) { … }
  ///   .dragsTogether(selectedFiles) { ids, parent, index in tree.move(ids, into: parent, at: index) }
  /// ```
  public func dragsTogether(
    _ selection: Set<Element.ID>,
    move: @escaping (_ items: [Element.ID], _ parent: Element.ID?, _ index: Int) -> Void
  ) -> Self {
    var outline = self
    outline.together = selection
    outline.moveTogether = move
    return outline
  }

  /// Takes drops of `types` from outside the outline (files from Finder, links) on its rows: one dropped on a folder
  /// row goes into that folder, at its end; one on any other row goes in beside it, after it. `perform` gets the
  /// drag's providers (one per item), the parent (`nil`: the top level) and the place among its children, as `move`
  /// counts it. The row under the drag wears the drop target. Rows still reorder as before.
  ///
  /// ```swift
  /// ReorderableOutline(projects, children: \.children, move: move) { … }
  ///   .acceptsDrops(of: [.fileURL]) { providers, parent, index in add(providers, into: parent, at: index) }
  /// ```
  public func acceptsDrops(
    of types: [UTType],
    perform: @escaping (_ providers: [NSItemProvider], _ parent: Element.ID?, _ index: Int) -> Bool
  ) -> Self {
    var outline = self
    outline.dropTypes = types
    outline.drop = perform
    return outline
  }

  /// A drop on `entry`'s row: into it when it is a folder, else after it.
  private func dropped(
    _ entry: ContOutlineRows<Element>.Entry, drop: @escaping ([NSItemProvider], Element.ID?, Int) -> Bool
  ) -> ([NSItemProvider]) -> Bool {
    { providers in
      entry.isFolder
        ? drop(providers, entry.id, entry.childCount ?? 0) : drop(providers, entry.parent, entry.place + 1)
    }
  }

  /// The outline's list: its name, or its own.
  private var list: AnyHashable { listName ?? AnyHashable(ownList) }

  /// Takes items dragged in from other outlines (given `list` names): as one passes over a row here,
  /// `receive(item, fromList, parent, index)` asks you to move it (and its children) from the other outline into
  /// `parent` here (`nil`: the top level) at `index`, counted among that parent's children before the move; it then
  /// reorders here as usual.
  ///
  /// ```swift
  /// ReorderableOutline(docs, children: \.children, list: "docs", move: move) { … }
  ///   .receivesItems { id, from, parent, index in docs.insert(atlas.remove(id), into: parent, at: index) }
  /// ```
  public func receivesItems(
    _ receive: @escaping (_ item: Element.ID, _ fromList: AnyHashable, _ parent: Element.ID?, _ index: Int) -> Void
  ) -> Self {
    var outline = self
    outline.receive = receive
    return outline
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

/// An empty outline's drop target: a row's room, which takes items dragged in from other outlines.
private struct ContOutlineEmptyDrop: View {
  let list: AnyHashable
  let state: ContReorderState
  let receive: (AnyHashable, Int, Int) -> Void
  @State private var geometry = ContRowGeometry()
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.contOuterDrop) private var outerDrop

  var body: some View {
    Color.clear
      .frame(maxWidth: .infinity, minHeight: KitMetrics.row(idiom))
      .contentShape(Rectangle())
      .onDrop(
        of: [ContReorderState.contentType] + (outerDrop?.types ?? []),
        delegate: ContReorderDropDelegate(
          list: list, index: 0, count: 0, move: { _, _ in }, state: state, receive: receive, geometry: geometry,
          outerDrop: outerDrop))
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { [geometry] in geometry.frame = $0 }
      .accessibilityHidden(true)
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

  /// The rows (indices) of the `selection`'s items on screen, each with its open rows.
  func together(_ selection: Set<Element.ID>) -> IndexSet {
    guard !selection.isEmpty else { return [] }
    var rows = IndexSet()
    for entry in entries where selection.contains(entry.id) { rows.insert(integersIn: entry.index..<entry.end) }
    return rows
  }

  /// The dragged rows' items that move, top to bottom: those not inside another dragged row (it carries them).
  func tops(of dragged: IndexSet) -> [Entry] {
    var tops: [Entry] = []
    for index in dragged where !tops.contains(where: { index < $0.end }) { tops.append(entries[index]) }
    return tops
  }

  func move(
    _ dragged: IndexSet, to destination: Int, level: Int? = nil, _ move: (Element.ID, Element.ID?, Int) -> Void,
    together: (([Element.ID], Element.ID?, Int) -> Void)? = nil
  ) {
    guard let first = dragged.first else { return }
    let (parent, index) = self.destination(of: dragged, before: destination, level: level)
    let tops = tops(of: dragged)
    if tops.count > 1, let together {
      // Already together there, in order: nothing moves.
      let places = tops.map(\.place)
      let inPlace =
        tops.allSatisfy { $0.parent == parent } && places == Array(places[0]..<places[0] + tops.count)
        && (places[0]...(places[0] + tops.count)).contains(index)
      if !inPlace { together(tops.map(\.id), parent, index) }
      return
    }
    // In place at its own level: nothing moves.
    if parent == entries[first].parent, index == entries[first].place || index == entries[first].place + 1 { return }
    move(entries[first].id, parent, index)
  }

  func nest(
    _ dragged: IndexSet, into folder: Int, _ move: (Element.ID, Element.ID?, Int) -> Void,
    together: (([Element.ID], Element.ID?, Int) -> Void)? = nil
  ) {
    guard let first = dragged.first, entries.indices.contains(folder) else { return }
    let tops = tops(of: dragged)
    if tops.count > 1, let together {
      together(tops.map(\.id), entries[folder].id, entries[folder].childCount ?? 0)
      return
    }
    move(entries[first].id, entries[folder].id, entries[folder].childCount ?? 0)
  }
}
