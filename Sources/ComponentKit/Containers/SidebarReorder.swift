import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppKit)
  import AppKit
#endif

// Drag to reorder, from Shell's SidebarReorder: a `LazyVStack` has no reordering of its own, so the rows do it. A
// reorderable row is a drag source (publishing which list it is in and where) and a drop target, and the target moves
// the dragged row to its own index as the drag passes over it: the live reordering a `List` shows. Which list a row
// belongs to is what refuses a drop between lists.

/// The row drag in progress, shared by every reorderable row (a `KitSidebar` publishes one; rows outside one share
/// the app's, `app`: a section or row of its own would never hear of a drag from its neighbours).
@MainActor @Observable
final class ContReorderState {
  /// The drag of the rows outside a `KitSidebar`. One drag at a time, so one for the app.
  static let app = ContReorderState()

  /// The type a row drag declares and accepts. Its payload is never read (this object describes the drag), but a drag
  /// and its targets have to agree on a type to be matched at all. Its own type, so a row never takes a file drop and a
  /// file never reorders a row. A dynamic type (from a MIME type), as no app declares one: on macOS a drag of an
  /// undeclared exported type never reaches a drop target, and one conforming to `public.data` drags as a file promise
  /// (a row dropped on Finder would make a file).
  nonisolated static let contentType = UTType(mimeType: "application/x-dev.v57.componentkit.row", conformingTo: .item)!

  /// The list the dragged row is in, and its index there (kept up to date as it moves under the pointer).
  private(set) var list: AnyHashable?
  private(set) var index: Int?
  /// Every dragged row's index: the row alone, or the rows dragged with it (a multi-row drag, together after the
  /// first move).
  private(set) var indices = IndexSet()

  /// Starts a drag of the row at `index`; `group` holds the indices of the rows dragged with it (itself included).
  func begin(_ list: AnyHashable, at index: Int, with group: IndexSet? = nil) {
    self.list = list
    self.index = index
    if let group, group.contains(index) { indices = group } else { indices = [index] }
  }

  func update(index: Int) {
    self.index = index
    indices = [index]
  }

  /// After a multi-row move: where the rows are now, and which of them is the one under the pointer.
  func update(indices: IndexSet, anchor: Int) {
    self.indices = indices
    index = anchor
  }

  /// How many rows the drag carries.
  var count: Int { indices.count }

  func isDragging(_ list: AnyHashable, at index: Int) -> Bool {
    self.list == list && indices.contains(index)
  }

  func end() {
    list = nil
    index = nil
    indices = []
  }

  /// Counts the drags, so a late `endAfterLanding` leaves a newer drag alone.
  private var drags = 0

  /// How tall the dragged row is (a group: all its rows), for `ContReorderDropDelegate.settles`.
  private(set) var height: CGFloat = 0

  /// Starts a drag from its source (see `begin`); `height` is the dragged row's.
  func start(_ list: AnyHashable, at index: Int, with group: IndexSet? = nil, height: CGFloat) {
    drags += 1
    self.height = height
    begin(list, at: index, with: group)
  }

  /// After a drop: the row stays the slot while the drag image lands on it, and sits back in as the session ends
  /// (`ContDragSessionEnd`). This ends it in case no end arrives: before macOS 26 and iOS 27, or when the source row
  /// left the screen (moved into another list).
  func endAfterLanding() {
    let drag = drags
    Task { @MainActor [weak self] in
      if #available(macOS 26.0, iOS 27.0, *) { try? await Task.sleep(for: .milliseconds(600)) }
      guard let self, self.drags == drag, self.list != nil else { return }
      withAnimation(.kitFast) { self.end() }
    }
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

  /// A multi-row drag passing over the row at `to`: the `.onMove` destination that brings the dragged rows
  /// (`indices`, the pointer's row `anchor` among them) together there, where they sit afterwards and where the
  /// anchor is. Like one row, they land after `to` when dragged down and before it when dragged up. `nil` over a
  /// dragged row.
  static func groupMove(indices: IndexSet, anchor: Int, to: Int) -> (destination: Int, indices: IndexSet, anchor: Int)? {
    guard !indices.contains(to), !indices.isEmpty else { return nil }
    let destination = to > anchor ? to + 1 : to
    let start = destination - indices.count(in: 0..<destination)
    let moved = IndexSet(integersIn: start..<(start + indices.count))
    return (destination, moved, start + indices.count(in: 0..<anchor))
  }
}

/// What a row drag carries out of the app when its row has a URL: the file first (Finder and the like take the first
/// data type, and only a file representation makes them copy the file), the link for a web URL, then the kit's own
/// row type for its reorder targets.
struct ContRowDrag: Transferable {
  let url: URL?

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .data) { drag in
      // The original file: the destination copies or links it, and an in-app drop costs nothing.
      SentTransferredFile(drag.url ?? URL(fileURLWithPath: "/"), allowAccessingOriginalFile: true)
    }
    .suggestedFileName { $0.url?.lastPathComponent }
    .exportingCondition { $0.url?.isFileURL == true }
    ProxyRepresentation(exporting: { (drag: ContRowDrag) in drag.url ?? URL(fileURLWithPath: "/") })
      .exportingCondition { drag in drag.url.map { !$0.isFileURL } ?? false }
    DataRepresentation(exportedContentType: ContReorderState.contentType) { _ in Data() }
      .visibility(.ownProcess)
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
  private var exportURL: ((Data.Element) -> URL?)?
  private var together: Set<ID> = []
  private var groups = false
  @State private var ownList = UUID()
  @Environment(\.contReorderState) private var shared
  @Environment(\.kitSectionStyle) private var style

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
    let state = shared ?? .app
    let selected = together.isEmpty ? IndexSet() : IndexSet(items.filter { together.contains($0.id) }.map(\.index))
    ForEach(items) { item in
      row(item)
        .modifier(
          ContReorderRow(
            list: list, index: item.index, move: move, state: state, accepts: accepts,
            perform: perform.map { perform in { providers in perform(item.element, providers) } },
            receive: receive,
            group: selected.count > 1 && selected.contains(item.index) ? selected : nil,
            exportURL: exportURL.map { url in { url(item.element) } }))
    }
  }

  @ViewBuilder
  private func row(_ item: ContIndexed<Data.Element, ID>) -> some View {
    if groups {
      // The element's rows as one view: one drag source, one target, one lifted card and one slot.
      VStack(alignment: .leading, spacing: style == .plain ? 0 : 2) { content(item.element) }
    } else {
      content(item.element)
    }
  }

  /// Lets a row be dragged out of the app as `url` (`nil` for none): a file URL drops into Finder, Mail or Terminal
  /// as the file itself, a web URL as the link. Reordering inside the app goes on as before.
  ///
  /// ```swift
  /// ReorderableSection(projects, move: { projects.move(fromOffsets: $0, toOffset: $1) }) { project in
  ///   SidebarRow(value: project.id, project.name, systemImage: "folder")
  /// }
  /// .exportsURL { $0.folder }
  /// ```
  ///
  /// A multi-row drag (`dragsTogether`) carries the URL of the row under the pointer.
  public func exportsURL(_ url: @escaping (Data.Element) -> URL?) -> Self {
    var section = self
    section.exportURL = url
    return section
  }

  /// Drags the rows of `selection` together: dragging one of them picks them all up (the lifted card shows how
  /// many), they gather where it passes, and `move` gets all their offsets at once. A row outside the selection still
  /// drags alone. Rows dragged together stay in their own list (`receivesRows` takes single rows).
  ///
  /// ```swift
  /// ReorderableSection(files, move: { files.move(fromOffsets: $0, toOffset: $1) }) { file in … }
  ///   .dragsTogether(selectedFiles)
  /// ```
  public func dragsTogether(_ selection: Set<ID>) -> Self {
    var section = self
    section.together = selection
    return section
  }

  /// Drags each element's rows as one group: when `content` draws a row followed by its sub-rows (an SSH host and
  /// its sessions), the whole group lifts, leaves one slot and reorders among the other groups. Sub-rows can be a
  /// `ReorderableSection` of their own: a group dragged over them still moves the groups.
  ///
  /// ```swift
  /// ReorderableSection(hosts, move: { hosts.move(fromOffsets: $0, toOffset: $1) }) { host in
  ///   SidebarRow(value: host.id, host.name, systemImage: "server.rack")
  ///   ReorderableSection(host.sessions, move: { move(host, $0, $1) }) { session in
  ///     SidebarRow(value: session.id, session.name, systemImage: "terminal").kitRowIndent(1)
  ///   }
  /// }
  /// .dragsAsGroup()
  /// ```
  public func dragsAsGroup(_ isOn: Bool = true) -> Self {
    var section = self
    section.groups = isOn
    return section
  }

  /// Lets the rows take other drops too (files, URLs, text): a row under such a drag wears the drop target, and
  /// `perform` gets the row's element and the drag's providers, one per dragged item. Reordering goes on as before.
  /// Drags from this app count too: on macOS, where SwiftUI describes them with no types or the wrong ones, the kit
  /// reads the drag pasteboard for `types` (a file list's rows dropped on a sidebar row).
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

  /// Makes one row of a hand-built list reorderable by dragging, and lets it take other drops too (files, URLs,
  /// text): under such a drag it wears the drop target and `perform` gets the drag's providers, one per item. Drags
  /// from this app count (see `ReorderableSection.alsoAccepts`). SwiftUI gives a drop to the innermost target only,
  /// so a reorderable row that takes files needs this rather than an `onDrop` of its own.
  ///
  /// ```swift
  /// ForEach(hosts) { host in
  ///   HostRow(host)
  ///     .kitReorderable(host, in: hosts, list: "hosts", alsoAccepts: [.fileURL], perform: { upload($0, to: host) }) {
  ///       hosts.move(fromOffsets: $0, toOffset: $1)
  ///     }
  ///   ForEach(host.sessions) { SessionRow($0).kitRowIndent(1) }
  /// }
  /// ```
  public func kitReorderable<Item: Identifiable>(
    _ item: Item, in items: [Item], list: some Hashable, alsoAccepts types: [UTType],
    perform: @escaping ([NSItemProvider]) -> Bool, move: @escaping (IndexSet, Int) -> Void
  ) -> some View {
    modifier(
      ContReorderableModifier(
        list: AnyHashable(list), index: items.firstIndex { $0.id == item.id } ?? 0, move: move, accepts: types,
        perform: perform))
  }
}

private struct ContReorderableModifier: ViewModifier {
  let list: AnyHashable
  let index: Int
  let move: (IndexSet, Int) -> Void
  var accepts: [UTType] = []
  var perform: (([NSItemProvider]) -> Bool)? = nil
  @Environment(\.contReorderState) private var shared

  func body(content: Content) -> some View {
    content.modifier(
      ContReorderRow(list: list, index: index, move: move, state: shared ?? .app, accepts: accepts, perform: perform))
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
  /// The rows dragged with this one (itself included), when it is part of a multi-row drag.
  var group: IndexSet? = nil
  /// The URL the drag carries out of the app.
  var exportURL: (() -> URL?)? = nil
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.contOuterReorder) private var outer
  @State private var isTargeted = false
  /// The row's frame in global coordinates: its width makes the drag image the row, so it lands on its slot; its
  /// height and place tell the drop target where the pointer is (`ContReorderDropDelegate.settles`).
  @State private var frame: CGRect?

  func body(content: Content) -> some View {
    let delegate = ContReorderDropDelegate(
      list: list, index: index, move: move, state: state, accepts: accepts, perform: perform, receive: receive,
      isTargeted: $isTargeted, outer: outer, frame: frame ?? .zero)
    content
      // Reorderable rows inside this one (a group's sub-rows) share its drag and pass its rows' drags to it.
      .environment(\.contReorderState, state)
      .environment(\.contOuterReorder, ContOuterReorder(delegate))
      .kitDropTarget(isTargeted, cornerRadius: ContMetrics.rowRadius(idiom))
      .modifier(ContDraggedRowSlot(list: list, index: index, state: state))
      .modifier(ContRowDragSource(begin: begin, exportURL: exportURL, preview: preview(content)))
      .modifier(ContDragSessionEnd(state: state))
      .onDrop(of: [ContReorderState.contentType] + accepts, delegate: delegate)
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
  }

  /// Called as the drag starts (on the main thread, though the drag source's closures aren't isolated).
  private func begin() {
    let (state, list, index, group, height) = (state, list, index, group, frame?.height ?? 0)
    MainActor.assumeIsolated { state.start(list, at: index, with: group, height: height) }
  }

  private func preview(_ content: Content) -> some View {
    content
      .kitLifted(true, cornerRadius: ContMetrics.rowRadius(idiom))
      .overlay(alignment: .topTrailing) {
        if let group, group.count > 1 {
          Count(group.count, .attention).offset(x: 6, y: -6)
        }
      }
      .frame(width: frame?.width ?? 220)
      .padding(8)
  }
}

/// The drag half: the kit's own row type only, or, with a URL, the file or link first (see `ContRowDrag`).
private struct ContRowDragSource<Preview: View>: ViewModifier {
  let begin: () -> Void
  let exportURL: (() -> URL?)?
  let preview: Preview

  func body(content: Content) -> some View {
    if let exportURL {
      // `draggable` asks for its payload only as the drag starts.
      content.draggable(drag(exportURL)) { preview }
    } else {
      content.onDrag {
        begin()
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
          forTypeIdentifier: ContReorderState.contentType.identifier, visibility: .ownProcess
        ) { completion in
          completion(Data(), nil)
          return nil
        }
        return provider
      } preview: {
        preview
      }
    }
  }

  private func drag(_ url: () -> URL?) -> ContRowDrag {
    begin()
    return ContRowDrag(url: url())
  }
}

/// The reorder target of the row around this one (a group around its sub-rows), boxed: a target holds its outer one.
final class ContOuterReorder {
  let delegate: ContReorderDropDelegate
  init(_ delegate: ContReorderDropDelegate) { self.delegate = delegate }
}

extension EnvironmentValues {
  @Entry var contOuterReorder: ContOuterReorder? = nil
}

/// While its row is dragged (the drag image is the lifted card), the row keeps its place as the field slot it will
/// sit back into (`ContDragSessionEnd` clears it as the session ends). Before macOS 26 and iOS 27 nothing reports a
/// drag that ends away from any row, so there the row stays drawn.
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
    } else {
      content
    }
  }
}

/// Ends the drag with its session: a drag can end away from any row (cancelled, or dropped outside the app). Outside the
/// drag source, where the session's updates arrive.
private struct ContDragSessionEnd: ViewModifier {
  let state: ContReorderState

  func body(content: Content) -> some View {
    if #available(macOS 26.0, iOS 27.0, *) {
      content
        .dragConfiguration(DragConfiguration(allowMove: true))
        .onDragSessionUpdated { session in
          if case .ended = session.phase, state.list != nil { withAnimation(.kitFast) { state.end() } }
        }
    } else {
      content
    }
  }
}

/// The drop half: while the drag passes over a sibling, the sibling moves the dragged row to its own index. Only a row
/// of the same list is a target, so a drag across lists is refused rather than mis-moving a row; a drag of the list
/// around this row (a group dragged over a group's sub-rows) goes to that list's target.
struct ContReorderDropDelegate: DropDelegate {
  let list: AnyHashable
  let index: Int
  let move: (IndexSet, Int) -> Void
  let state: ContReorderState
  var accepts: [UTType] = []
  var perform: (([NSItemProvider]) -> Bool)? = nil
  var receive: ((AnyHashable, Int, Int) -> Void)? = nil
  var isTargeted: Binding<Bool>? = nil
  /// The target of the row around this one, for drags of its list.
  var outer: ContOuterReorder? = nil
  /// The row's frame in global coordinates (`.zero` before its first layout).
  var frame: CGRect = .zero

  /// The pointer in global coordinates: `DropInfo` gives it in this row's, and a forwarded drag needs it in the outer
  /// row's.
  private func pointer(_ info: DropInfo) -> CGPoint {
    CGPoint(x: frame.minX + info.location.x, y: frame.minY + info.location.y)
  }

  /// Whether the pointer sits where the dragged rows will be once they move to this row, so the move is the last one:
  /// a tall row moved past a shorter one would otherwise land under the pointer again and move back, and back.
  private func settles(at pointer: CGPoint, from: Int) -> Bool {
    let dragged = state.height * CGFloat(max(state.count, 1))
    guard dragged > 0, frame.height > 0 else { return true }
    // Moving down, this row slides up by the dragged rows' height and they take its bottom; moving up, its top.
    return from < index ? pointer.y >= frame.maxY - dragged : pointer.y <= frame.minY + dragged
  }

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

  /// A drop of one of the other accepted types (a file, a URL) rather than a row. On macOS the drag pasteboard is read
  /// too: a drag started in this app (a file list's row, a chip) reaches `DropInfo` with no types or the wrong ones.
  private func isOther(_ info: DropInfo) -> Bool {
    perform != nil && !isRow(info) && (info.hasItemsConforming(to: accepts) || ContDragPasteboard.has(accepts))
  }

  /// The outer target, when the dragged row belongs to its list rather than this one.
  private func forwarded(_ info: DropInfo) -> ContReorderDropDelegate? {
    guard let source = state.list, source != list, isRow(info) else { return nil }
    var target = outer?.delegate
    while let candidate = target {
      if candidate.list == source { return candidate }
      target = candidate.outer?.delegate
    }
    return nil
  }

  func validateDrop(info: DropInfo) -> Bool {
    if let outer = forwarded(info) { return outer.validateDrop(info: info) }
    if isOther(info) { return true }
    // Rows dragged together stay in their list.
    let single = state.count <= 1 || state.list == list
    return isRow(info) && single && ContReorder.accepts(from: state.list, into: list, receives: receive != nil)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? { updated(info, at: pointer(info)) }

  func dropEntered(info: DropInfo) { entered(info, at: pointer(info)) }

  private func updated(_ info: DropInfo, at pointer: CGPoint) -> DropProposal? {
    if let outer = forwarded(info) { return outer.updated(info, at: pointer) }
    if isOther(info) { return DropProposal(operation: .copy) }
    let isValid = validateDrop(info: info)
    // A row that entered too far from where the dragged rows would settle moves them once the pointer gets there.
    if isValid, state.list == list { reorder(at: pointer) }
    return DropProposal(operation: isValid ? .move : .forbidden)
  }

  private func entered(_ info: DropInfo, at pointer: CGPoint) {
    if let outer = forwarded(info) { return outer.entered(info, at: pointer) }
    if isOther(info) {
      withAnimation(.kitFast) { isTargeted?.wrappedValue = true }
      return
    }
    guard isRow(info), let from = state.index, let fromList = state.list else { return }
    if fromList != list {
      // A row from another list: the app moves it here, then it reorders here.
      guard let receive, state.count <= 1 else { return }
      withAnimation(.kitSpring) {
        receive(fromList, from, index)
        state.begin(list, at: index)
      }
      return
    }
    reorder(at: pointer)
  }

  /// Moves the dragged rows of this list to this row, once the pointer is where they settle.
  private func reorder(at pointer: CGPoint) {
    guard let from = state.index, state.list == list, from != index, settles(at: pointer, from: from) else { return }
    if state.count > 1 {
      guard let step = ContReorder.groupMove(indices: state.indices, anchor: from, to: index) else { return }
      let moving = state.indices
      withAnimation(.kitSpring) {
        move(moving, step.destination)
        state.update(indices: step.indices, anchor: step.anchor)
      }
      return
    }
    // The drag's index moves with the rows, in one transaction: updated apart, the row sliding into the old place
    // would count as dragged for a frame and blink into the slot.
    withAnimation(.kitSpring) {
      move(IndexSet(integer: from), ContReorder.destination(from: from, to: index))
      state.update(index: index)
    }
  }

  func dropExited(info: DropInfo) {
    if let outer = forwarded(info) { return outer.dropExited(info: info) }
    if isTargeted?.wrappedValue == true { withAnimation(.kitFast) { isTargeted?.wrappedValue = false } }
  }

  func performDrop(info: DropInfo) -> Bool {
    if let outer = forwarded(info) { return outer.performDrop(info: info) }
    if isOther(info), let perform {
      isTargeted?.wrappedValue = false
      // One provider per dragged item, read from the drag pasteboard where it has them (macOS); else SwiftUI's.
      let pasted = ContDragPasteboard.providers(for: accepts)
      return perform(pasted.isEmpty ? info.itemProviders(for: accepts) : pasted)
    }
    guard isRow(info) else { return false }
    state.endAfterLanding()
    return true
  }
}

// MARK: - The drag pasteboard

/// What the drag pasteboard holds, for the drops SwiftUI describes badly: on macOS `DropInfo` gives a drag started in
/// this process no types or the wrong ones, and one opaque provider for a multi-file drag, while
/// `NSPasteboard(name: .drag)` has the real items, one per file. Nothing on other platforms.
@MainActor
enum ContDragPasteboard {
  /// The pasteboard types (identifiers, in order) that conform to one of `accepts`.
  nonisolated static func matching(_ types: [String], accepts: [UTType]) -> [String] {
    types.filter { identifier in
      guard let type = UTType(identifier) else { return false }
      return accepts.contains { type.conforms(to: $0) }
    }
  }

  /// Whether the drag in progress carries an item of one of `accepts`.
  static func has(_ accepts: [UTType]) -> Bool {
    #if canImport(AppKit)
      guard !accepts.isEmpty, let types = NSPasteboard(name: .drag).types else { return false }
      return !matching(types.map(\.rawValue), accepts: accepts).isEmpty
    #else
      false
    #endif
  }

  /// One provider per item of the drag that carries one of `accepts`, holding that item's data for those types (read
  /// now, while the drag pasteboard still has it). Empty when none does (a file promise), or off macOS.
  static func providers(for accepts: [UTType]) -> [NSItemProvider] {
    #if canImport(AppKit)
      guard !accepts.isEmpty else { return [] }
      return (NSPasteboard(name: .drag).pasteboardItems ?? []).compactMap { item in
        let types = matching(item.types.map(\.rawValue), accepts: accepts)
        let data = types.compactMap { type in item.data(forType: .init(type)).map { (type, $0) } }
        guard !data.isEmpty else { return nil }
        let provider = NSItemProvider()
        for (type, bytes) in data {
          provider.registerDataRepresentation(forTypeIdentifier: type, visibility: .all) { completion in
            completion(bytes, nil)
            return nil
          }
        }
        return provider
      }
    #else
      []
    #endif
  }
}
