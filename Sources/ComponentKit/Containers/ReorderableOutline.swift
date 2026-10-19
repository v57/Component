import SwiftUI

// A tree whose rows drag: `KitOutline`'s rows on `ReorderableSection`'s reordering. The tree is drawn as one flat list
// of the rows on screen (an open folder's rows follow it), so a drag slides the rows as in any list. A dragged folder
// takes its open rows along, counted as one row; dropped beside a row it joins that row's folder, and over the middle
// of a folder row it goes into it.

/// A tree of rows, like `KitOutline`, that reorders by dragging: a row dropped between two others joins their folder,
/// one dropped onto the middle of a folder row goes into that folder (at its end), and a folder carries its rows
/// along. `move` gets the dragged item, its new parent (`nil`: the top level) and its place among that parent's
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
  @Environment(\.contRowIndent) private var baseIndent
  @Environment(\.contReorderState) private var shared

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
            list: list, index: entry.index, move: { rows.move($0, to: $1, move) }, state: state,
            group: entry.end > entry.index + 1 ? IndexSet(integersIn: entry.index..<entry.end) : nil,
            count: rows.entries.count, collapses: true, nests: { rows.entries[$0].isFolder },
            nest: { rows.nest($0, into: $1, move) }))
    }
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
        rows.entries.append(
          Entry(element: item, index: index, end: index + 1, depth: depth, parent: parent, place: place, childCount: kids?.count))
        if let kids, expanded.contains(item.id) {
          add(kids, depth: depth + 1, parent: item.id)
          rows.entries[index].end = rows.entries.count
        }
      }
    }
    add(items, depth: 0, parent: nil)
    return rows
  }

  /// The drop of the rows `dragged` (a row and its open rows) before the row at `destination` (`.onMove`'s
  /// arguments for the flat list): it joins the folder of the row after it, or becomes the first child of the open
  /// folder just before it; at the end it goes to the top level's end.
  func destination(of dragged: IndexSet, before destination: Int) -> (parent: Element.ID?, index: Int) {
    let before = (0..<destination).last { !dragged.contains($0) }.map { entries[$0] }
    guard destination < entries.count else { return (nil, rootCount) }
    let after = entries[destination]
    if let before, after.parent == before.id { return (before.id, 0) }
    return (after.parent, after.place)
  }

  func move(_ dragged: IndexSet, to destination: Int, _ move: (Element.ID, Element.ID?, Int) -> Void) {
    guard let first = dragged.first else { return }
    let (parent, index) = self.destination(of: dragged, before: destination)
    move(entries[first].id, parent, index)
  }

  func nest(_ dragged: IndexSet, into folder: Int, _ move: (Element.ID, Element.ID?, Int) -> Void) {
    guard let first = dragged.first, entries.indices.contains(folder) else { return }
    move(entries[first].id, entries[folder].id, entries[folder].childCount ?? 0)
  }
}
