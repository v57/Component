import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppKit)
  import AppKit
#endif

// Drag to reorder, from Shell's SidebarReorder: a `LazyVStack` has no reordering of its own, so the rows do it. A
// reorderable row is a drag source (publishing which list it is in and where) and a drop target, and the target moves
// the dragged row to its own index as the drag passes over it: the live reordering a `List` shows. Which list a row
// belongs to is what refuses a drop between lists.

/// The row drag in progress, shared by every reorderable row (a `KitSidebar` publishes one; a `ReorderableSection`
/// outside it keeps its own).
@MainActor @Observable
final class ContReorderState {
  /// The type a row drag declares and accepts. Its payload is never read (this object describes the drag), but a drag
  /// and its targets have to agree on a type to be matched at all. Its own type, so a row never takes a file drop and a
  /// file never reorders a row.
  static let contentType = UTType(exportedAs: "dev.v57.componentkit.row")

  /// The list the dragged row is in, and its index there (kept up to date as it moves under the pointer).
  private(set) var list: AnyHashable?
  private(set) var index: Int?

  func begin(_ list: AnyHashable, at index: Int) {
    self.list = list
    self.index = index
  }

  func update(index: Int) { self.index = index }

  func isDragging(_ list: AnyHashable, at index: Int) -> Bool {
    self.list == list && self.index == index
  }

  func end() {
    list = nil
    index = nil
  }
}

extension EnvironmentValues {
  @Entry var contReorderState: ContReorderState? = nil
}

/// The reorder math, apart from views.
enum ContReorder {
  /// `.onMove`'s destination for a row dragged from `from` onto the row at `to`: a row dragged down lands after the
  /// row it was dropped on, one dragged up before it; either way it ends up at `to`.
  static func destination(from: Int, to: Int) -> Int { from < to ? to + 1 : to }

  /// Whether a row dragged from `source` may land in `list`: its own list always, another only when the list
  /// receives rows.
  static func accepts(from source: AnyHashable?, into list: AnyHashable, receives: Bool) -> Bool {
    guard let source else { return false }
    return source == list || receives
  }
}

/// A list of rows that reorder by dragging, live: the dragged row lifts as a raised card, a field slot opens where it
/// will land, the rows under the pointer make room, and a drop into another list is refused. `move` takes `.onMove`'s
/// arguments, so `array.move(fromOffsets:toOffset:)` fits it.
///
/// ```swift
/// ReorderableSection(hosts, move: { hosts.move(fromOffsets: $0, toOffset: $1) }) { host in
///   SidebarRow(value: host.id, host.name, systemImage: "server.rack")
/// }
/// ```
public struct ReorderableSection<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
  private let items: [ContIndexed<Data.Element, ID>]
  private let list: AnyHashable?
  private let move: (IndexSet, Int) -> Void
  private let content: (Data.Element) -> RowContent
  private var accepts: [UTType] = []
  private var perform: ((Data.Element, [NSItemProvider]) -> Bool)?
  private var receive: ((AnyHashable, Int, Int) -> Void)?
  @State private var ownList = UUID()
  @State private var ownState = ContReorderState()
  @Environment(\.contReorderState) private var shared

  /// Rows for `data`, identified by `id`. `list` names the list when two sections must accept each other's rows
  /// (by default each section is its own list).
  public init(
    _ data: Data, id: KeyPath<Data.Element, ID>, list: AnyHashable? = nil,
    move: @escaping (IndexSet, Int) -> Void, @ViewBuilder content: @escaping (Data.Element) -> RowContent
  ) {
    items = data.enumerated().map { ContIndexed(id: $0.element[keyPath: id], index: $0.offset, element: $0.element) }
    self.list = list
    self.move = move
    self.content = content
  }

  public var body: some View {
    let list = list ?? AnyHashable(ownList)
    let state = shared ?? ownState
    ForEach(items) { item in
      content(item.element)
        .modifier(
          ContReorderRow(
            list: list, index: item.index, move: move, state: state, accepts: accepts,
            perform: perform.map { perform in { providers in perform(item.element, providers) } },
            receive: receive))
    }
  }

  /// Lets the rows take other drops too (files, URLs, text): a row under such a drag wears the drop target, and
  /// `perform` gets the row's element and the drag's providers. Reordering goes on as before.
  ///
  /// ```swift
  /// ReorderableSection(hosts, move: { hosts.move(fromOffsets: $0, toOffset: $1) }) { host in
  ///   SidebarRow(value: host.id, host.name, systemImage: "server.rack")
  /// }
  /// .alsoAccepts([.fileURL]) { host, providers in upload(providers, to: host) }
  /// ```
  public func alsoAccepts(
    _ types: [UTType], perform: @escaping (Data.Element, [NSItemProvider]) -> Bool
  ) -> Self {
    var section = self
    section.accepts = types
    section.perform = perform
    return section
  }

  /// Takes rows dragged in from other lists (sections given a `list` name): as one passes over a row here,
  /// `receive(fromList, fromIndex, toIndex)` asks you to move that element from the other list to `toIndex` in this
  /// one; it then reorders here as usual. Without it a drop from another list is refused.
  ///
  /// ```swift
  /// ReorderableSection(pinned, list: "pinned", move: { pinned.move(fromOffsets: $0, toOffset: $1) }) { … }
  ///   .receivesRows { from, index, to in
  ///     if from == AnyHashable("recent") { pinned.insert(recent.remove(at: index), at: to) }
  ///   }
  /// ```
  public func receivesRows(_ receive: @escaping (_ fromList: AnyHashable, _ fromIndex: Int, _ toIndex: Int) -> Void)
    -> Self
  {
    var section = self
    section.receive = receive
    return section
  }
}

extension ReorderableSection where Data.Element: Identifiable, ID == Data.Element.ID {
  /// Rows for identifiable `data`.
  public init(
    _ data: Data, list: AnyHashable? = nil, move: @escaping (IndexSet, Int) -> Void,
    @ViewBuilder content: @escaping (Data.Element) -> RowContent
  ) {
    self.init(data, id: \.id, list: list, move: move, content: content)
  }
}

struct ContIndexed<Element, ID: Hashable>: Identifiable {
  let id: ID
  let index: Int
  let element: Element
}

extension View {
  /// Makes one row of a hand-built list reorderable by dragging (`ReorderableSection` does this for a whole list).
  /// Rows with the same `list` reorder among themselves; a drop from another list is refused.
  ///
  /// ```swift
  /// ForEach(hosts) { host in
  ///   HostRow(host).kitReorderable(host, in: hosts, list: "hosts") { hosts.move(fromOffsets: $0, toOffset: $1) }
  /// }
  /// ```
  public func kitReorderable<Item: Identifiable>(
    _ item: Item, in items: [Item], list: some Hashable, move: @escaping (IndexSet, Int) -> Void
  ) -> some View {
    modifier(
      ContReorderableModifier(
        list: AnyHashable(list), index: items.firstIndex { $0.id == item.id } ?? 0, move: move))
  }
}

private struct ContReorderableModifier: ViewModifier {
  let list: AnyHashable
  let index: Int
  let move: (IndexSet, Int) -> Void
  @Environment(\.contReorderState) private var shared
  @State private var ownState = ContReorderState()

  func body(content: Content) -> some View {
    content.modifier(ContReorderRow(list: list, index: index, move: move, state: shared ?? ownState))
  }
}

/// Makes a row a drag source and a drop target of its list.
struct ContReorderRow: ViewModifier {
  let list: AnyHashable
  let index: Int
  let move: (IndexSet, Int) -> Void
  let state: ContReorderState
  var accepts: [UTType] = []
  var perform: (([NSItemProvider]) -> Bool)? = nil
  var receive: ((AnyHashable, Int, Int) -> Void)? = nil
  @Environment(\.kitIdiom) private var idiom
  @State private var isTargeted = false

  func body(content: Content) -> some View {
    let list = list
    let index = index
    let state = state
    content
      .kitDropTarget(isTargeted, cornerRadius: ContMetrics.rowRadius(idiom))
      .modifier(ContDraggedRowSlot(list: list, index: index, state: state))
      .onDrag {
        // A drag always starts on the main thread, but `onDrag`'s closure isn't main-actor isolated.
        MainActor.assumeIsolated { state.begin(list, at: index) }
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
          forTypeIdentifier: ContReorderState.contentType.identifier, visibility: .ownProcess
        ) { completion in
          completion(Data(), nil)
          return nil
        }
        return provider
      } preview: {
        content
          .kitLifted(true, cornerRadius: ContMetrics.rowRadius(idiom))
          .frame(width: 220)
      }
      .onDrop(
        of: [ContReorderState.contentType] + accepts,
        delegate: ContReorderDropDelegate(
          list: list, index: index, move: move, state: state, accepts: accepts, perform: perform, receive: receive,
          isTargeted: $isTargeted))
  }
}

/// While its row is dragged (the drag image is the lifted card), the row keeps its place as the field slot it will
/// sit back into. A drag can end away from any row, so the session's end clears the drag too; before macOS 26 and
/// iOS 27 nothing reports that end, so there the row stays drawn.
private struct ContDraggedRowSlot: ViewModifier {
  let list: AnyHashable
  let index: Int
  let state: ContReorderState
  @Environment(\.kitIdiom) private var idiom

  func body(content: Content) -> some View {
    if #available(macOS 26.0, iOS 27.0, *) {
      let isDragging = state.isDragging(list, at: index)
      content
        .opacity(isDragging ? 0 : 1)
        .background {
          if isDragging {
            RoundedRectangle(cornerRadius: ContMetrics.rowRadius(idiom), style: .continuous).fill(.kitField)
          }
        }
        .onDragSessionUpdated { session in
          if case .ended = session.phase { state.end() }
        }
    } else {
      content
    }
  }
}

/// The drop half: while the drag passes over a sibling, the sibling moves the dragged row to its own index. Only a row
/// of the same list is a target, so a drag across lists is refused rather than mis-moving a row.
struct ContReorderDropDelegate: DropDelegate {
  let list: AnyHashable
  let index: Int
  let move: (IndexSet, Int) -> Void
  let state: ContReorderState
  var accepts: [UTType] = []
  var perform: (([NSItemProvider]) -> Bool)? = nil
  var receive: ((AnyHashable, Int, Int) -> Void)? = nil
  var isTargeted: Binding<Bool>? = nil

  /// Whether the drag is a kit row. Read from the drag pasteboard on macOS: `DropInfo` describes a drag SwiftUI started
  /// in this process with no types.
  private func isRow(_ info: DropInfo) -> Bool {
    #if canImport(AppKit)
      NSPasteboard(name: .drag).types?.contains(NSPasteboard.PasteboardType(ContReorderState.contentType.identifier))
        ?? false
    #else
      info.hasItemsConforming(to: [ContReorderState.contentType])
    #endif
  }

  /// A drop of one of the other accepted types (a file, a URL) rather than a row.
  private func isOther(_ info: DropInfo) -> Bool {
    perform != nil && !isRow(info) && info.hasItemsConforming(to: accepts)
  }

  func validateDrop(info: DropInfo) -> Bool {
    if isOther(info) { return true }
    return isRow(info) && ContReorder.accepts(from: state.list, into: list, receives: receive != nil)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    if isOther(info) { return DropProposal(operation: .copy) }
    return DropProposal(operation: validateDrop(info: info) ? .move : .forbidden)
  }

  func dropEntered(info: DropInfo) {
    if isOther(info) {
      withAnimation(.kitFast) { isTargeted?.wrappedValue = true }
      return
    }
    guard isRow(info), let from = state.index, let fromList = state.list else { return }
    if fromList != list {
      // A row from another list: the app moves it here, then it reorders here.
      guard let receive else { return }
      withAnimation(.kitSpring) { receive(fromList, from, index) }
      state.begin(list, at: index)
      return
    }
    guard from != index else { return }
    withAnimation(.kitSpring) {
      move(IndexSet(integer: from), ContReorder.destination(from: from, to: index))
    }
    state.update(index: index)
  }

  func dropExited(info: DropInfo) {
    if isTargeted?.wrappedValue == true { withAnimation(.kitFast) { isTargeted?.wrappedValue = false } }
  }

  func performDrop(info: DropInfo) -> Bool {
    if isOther(info), let perform {
      isTargeted?.wrappedValue = false
      return perform(info.itemProviders(for: accepts))
    }
    guard isRow(info) else { return false }
    state.end()
    return true
  }
}
