import SwiftUI

// MARK: - Columns

/// What happened to a row that isn't saved yet. The grid marks it in its gutter (a pencil, trash or plus tile) and
/// tints deleted and new rows; `ChangesCard` lists the same edits.
public enum KitGridRowState: Hashable, Sendable {
  case edited, deleted, inserted

  var hue: Hue {
    switch self {
    case .edited: .orange
    case .deleted: .red
    case .inserted: .green
    }
  }

  var systemImage: String {
    switch self {
    case .edited: "pencil"
    case .deleted: "trash"
    case .inserted: "plus"
    }
  }

  var title: String {
    switch self {
    case .edited: "Edited"
    case .deleted: "Deleted"
    case .inserted: "New"
    }
  }
}

/// The column a grid is sorted by. The grid only shows it and flips it from the header; the app sorts its rows.
public struct KitGridSort: Hashable, Sendable {
  public var column: String
  public var ascending: Bool

  public init(_ column: String, ascending: Bool = true) {
    self.column = column
    self.ascending = ascending
  }
}

/// One column of a `KitGrid`: its header (title, an optional type chip and glyph), width and alignment, and how a
/// row's cell reads. A text column (`value:` or a key path) draws `nil` as a NULL chip and an empty string as
/// "empty", and can be edited in place; a custom column draws any view.
///
/// ```swift
/// KitGridColumn<Order>("id", width: 80, alignment: .trailing, systemImage: "key") { "\($0.id)" }
/// KitGridColumn<Order>("note", \.note) { order, text in store.set(\.note, text, of: order) }
/// KitGridColumn<Order>("status", width: 100) { order in StatusChip(order.status) }
/// ```
public struct KitGridColumn<Row>: Identifiable {
  public enum Alignment: Hashable, Sendable {
    case leading, trailing
  }

  public let id: String
  public var title: String
  /// A type or kind shown as a small chip after the title ("jsonb").
  public var detail: String?
  /// A glyph before the title (a key for the primary key).
  public var systemImage: String?
  public var width: CGFloat
  public var alignment: Alignment
  public var isMono: Bool
  let value: ((Row) -> String?)?
  let cell: ((Row) -> AnyView)?
  let edit: ((Row, String) -> Void)?

  /// A text column; `edit` makes it editable in place (Return or a double click on the focused cell).
  public init(
    _ title: String, id: String? = nil, detail: String? = nil, systemImage: String? = nil, width: CGFloat = 120,
    alignment: Alignment = .leading, mono: Bool = false, value: @escaping (Row) -> String?,
    edit: ((Row, String) -> Void)? = nil
  ) {
    self.id = id ?? title
    self.title = title
    self.detail = detail
    self.systemImage = systemImage
    self.width = width
    self.alignment = alignment
    self.isMono = mono
    self.value = value
    self.cell = nil
    self.edit = edit
  }

  /// A text column read from a key path (`nil` draws the NULL chip).
  public init(
    _ title: String, _ keyPath: KeyPath<Row, String?>, id: String? = nil, detail: String? = nil,
    systemImage: String? = nil, width: CGFloat = 120, alignment: Alignment = .leading, mono: Bool = false,
    edit: ((Row, String) -> Void)? = nil
  ) {
    self.init(
      title, id: id, detail: detail, systemImage: systemImage, width: width, alignment: alignment, mono: mono,
      value: { $0[keyPath: keyPath] }, edit: edit)
  }

  /// A text column read from a key path.
  public init(
    _ title: String, _ keyPath: KeyPath<Row, String>, id: String? = nil, detail: String? = nil,
    systemImage: String? = nil, width: CGFloat = 120, alignment: Alignment = .leading, mono: Bool = false,
    edit: ((Row, String) -> Void)? = nil
  ) {
    self.init(
      title, id: id, detail: detail, systemImage: systemImage, width: width, alignment: alignment, mono: mono,
      value: { $0[keyPath: keyPath] }, edit: edit)
  }

  /// A column that draws any view per row and still edits as text: `value` is the text the field starts from,
  /// `edit` gets what was typed (Return or a double click on the focused cell, as a text column).
  ///
  /// ```swift
  /// KitGridColumn<Order>("status", width: 110, value: { $0.status }, edit: { store.set(\.status, $1, of: $0) }) { order in
  ///   Chip(status: order.status)
  /// }
  /// ```
  public init<Content: View>(
    _ title: String, id: String? = nil, detail: String? = nil, systemImage: String? = nil, width: CGFloat = 120,
    alignment: Alignment = .leading, mono: Bool = false, value: @escaping (Row) -> String?,
    edit: @escaping (Row, String) -> Void, @ViewBuilder content: @escaping (Row) -> Content
  ) {
    self.id = id ?? title
    self.title = title
    self.detail = detail
    self.systemImage = systemImage
    self.width = width
    self.alignment = alignment
    self.isMono = mono
    self.value = value
    self.cell = { AnyView(content($0)) }
    self.edit = edit
  }

  /// A column that draws any view per row (chips, links, a JSON preview).
  public init<Content: View>(
    _ title: String, id: String? = nil, detail: String? = nil, systemImage: String? = nil, width: CGFloat = 120,
    alignment: Alignment = .leading, @ViewBuilder content: @escaping (Row) -> Content
  ) {
    self.id = id ?? title
    self.title = title
    self.detail = detail
    self.systemImage = systemImage
    self.width = width
    self.alignment = alignment
    self.isMono = false
    self.value = nil
    self.cell = { AnyView(content($0)) }
    self.edit = nil
  }

  var frameAlignment: SwiftUI.Alignment { alignment == .trailing ? .trailing : .leading }
}

/// How tall a grid's rows are.
public enum KitGridRowHeight: Hashable, Sendable {
  /// One line: 34pt (44 on touch).
  case standard
  /// At least one line, growing with the cells (multi-line comments, plural forms): text cells wrap.
  case automatic
}

// MARK: - Layout and navigation (pure, tested)

enum KitGridLayout {
  /// The rows an outline shows, in order, with their depth: each row, then (while it's open) its children.
  static func flatten<Row, ID: Hashable>(
    _ rows: [Row], id: (Row) -> ID, children: ((Row) -> [Row]?)?, isOpen: (ID) -> Bool, depth: Int = 0
  ) -> [(row: Row, depth: Int, hasChildren: Bool)] {
    var out: [(row: Row, depth: Int, hasChildren: Bool)] = []
    for row in rows {
      let kids = children?(row)
      out.append((row, depth, kids != nil))
      if let kids, isOpen(id(row)) {
        out += flatten(kids, id: id, children: children, isOpen: isOpen, depth: depth + 1)
      }
    }
    return out
  }

  /// Column widths: each column's own (or resized) width; the last one also takes what's left of `available`.
  static func widths(_ base: [CGFloat], available: CGFloat) -> [CGFloat] {
    guard var last = base.last else { return [] }
    let others = base.dropLast().reduce(0, +)
    last = max(last, available - others)
    return base.dropLast() + [last]
  }

  /// The column `offset` steps from `current`, clamped.
  static func column(_ current: Int?, by offset: Int, count: Int) -> Int? {
    guard count > 0 else { return nil }
    guard let current else { return offset >= 0 ? 0 : count - 1 }
    return min(max(current + offset, 0), count - 1)
  }

  /// The selection after moving to `target` from `anchor`: just the target, or with shift the run between them.
  static func selection<ID: Hashable>(_ ids: [ID], anchor: ID?, target: ID, extending: Bool) -> Set<ID> {
    guard extending, let anchor, let a = ids.firstIndex(of: anchor), let b = ids.firstIndex(of: target) else {
      return [target]
    }
    return Set(ids[min(a, b)...max(a, b)])
  }
}

// MARK: - Grid

/// The kit's data grid (Database's tables, Dev's strings): a field-filled track in the window, 34pt rows (44 on
/// iPad) 2pt apart and striped, the selected row raised as a card (consecutive ones merge), the focused cell a 28pt
/// field that fills its row, NULL as a chip, and a header that sorts and resizes. Unsaved rows carry a tile in a
/// gutter; deleted and new rows are tinted. Keyboard: ↑↓ move (⇧ extends), ←→ and Tab move the cell, Return edits,
/// Escape cancels.
///
/// ```swift
/// KitGrid(orders, columns: columns, selection: $selection, sort: $sort, rowState: { pending[$0.id] })
/// ```
public struct KitGrid<Row: Identifiable, Footer: View>: View {
  var rows: [Row]
  var columns: [KitGridColumn<Row>]
  @Binding var selection: Set<Row.ID>
  @Binding var sort: KitGridSort?
  var rowState: ((Row) -> KitGridRowState?)?
  var footer: Footer
  var children: KeyPath<Row, [Row]?>?
  var expandedBinding: Binding<Set<Row.ID>>?
  var heightMode: KitGridRowHeight
  var primaryAction: ((Set<Row.ID>) -> Void)?
  var menu: ((Set<Row.ID>) -> AnyView)?

  @State private var ownExpanded: Set<Row.ID> = []
  @State private var resized: [String: CGFloat] = [:]
  @State private var available: CGFloat = 0
  @State private var focusRow: Row.ID?
  @State private var focusColumn: Int?
  @State private var anchor: Row.ID?
  @State private var editing = false
  @State private var draft = ""
  @State private var hovered: Row.ID?
  @FocusState private var isFocused: Bool
  @FocusState private var isFieldFocused: Bool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitWindowIsActive) private var isActive

  /// A grid of `rows`.
  ///
  /// - Parameters:
  ///   - children: makes it an outline (Redis key groups, JSON): a row with children (`[]` counts) leads its first
  ///     cell with a disclosure chevron and shows them one step in while open; ← → close and open it.
  ///   - expanded: the ids of the open rows, to keep them; without it the grid keeps its own.
  ///   - rowHeight: `.automatic` lets rows grow with their cells (text wraps).
  ///   - primaryAction: what a double click on a cell that doesn't edit, or Return there, does with the selection
  ///     (open the row, drill into a key).
  public init(
    _ rows: [Row], columns: [KitGridColumn<Row>], selection: Binding<Set<Row.ID>>,
    sort: Binding<KitGridSort?> = .constant(nil), rowState: ((Row) -> KitGridRowState?)? = nil,
    children: KeyPath<Row, [Row]?>? = nil, expanded: Binding<Set<Row.ID>>? = nil,
    rowHeight: KitGridRowHeight = .standard, primaryAction: ((Set<Row.ID>) -> Void)? = nil,
    @ViewBuilder footer: () -> Footer
  ) {
    self.rows = rows
    self.columns = columns
    self._selection = selection
    self._sort = sort
    self.rowState = rowState
    self.children = children
    self.expandedBinding = expanded
    self.heightMode = rowHeight
    self.primaryAction = primaryAction
    self.footer = footer()
  }

  /// A context menu for the rows: it gets the selection when the clicked row is in it, else just that row.
  ///
  /// ```swift
  /// KitGrid(orders, columns: columns, selection: $selection).rowContextMenu { ids in
  ///   Button("Copy as JSON") { copy(ids) }
  ///   Button("Delete", role: .destructive) { delete(ids) }
  /// }
  /// ```
  public func rowContextMenu<Menu: View>(@ViewBuilder _ menu: @escaping (Set<Row.ID>) -> Menu) -> Self {
    var grid = self
    grid.menu = { AnyView(menu($0)) }
    return grid
  }

  private var expanded: Binding<Set<Row.ID>> { expandedBinding ?? $ownExpanded }

  /// The rows shown, in order, with their depth in an outline.
  private var visible: [(row: Row, depth: Int, hasChildren: Bool)] {
    guard let children else { return rows.map { ($0, 0, false) } }
    let open = expanded.wrappedValue
    return KitGridLayout.flatten(rows, id: \.id, children: { $0[keyPath: children] }, isOpen: { open.contains($0) })
  }

  private var rowHeight: CGFloat { KitMetrics.tableRow(idiom) }
  private var gutter: CGFloat { rowState == nil ? 0 : 30 }
  private var inset: CGFloat { idiom.size(4, touch: 6) }

  private var widths: [CGFloat] {
    KitGridLayout.widths(
      columns.map { resized[$0.id] ?? $0.width }, available: available - gutter - inset * 2)
  }

  public var body: some View {
    let widths = widths
    let visible = visible
    DataScroll(axes: [.horizontal, .vertical]) {
      LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
        Section {
          ForEach(Array(visible.enumerated()), id: \.element.row.id) { index, item in
            rowView(item.row, index: index, widths: widths, visible: visible)
          }
          footer
            .padding(.leading, 8)
            .frame(minHeight: rowHeight, alignment: .leading)
        } header: {
          header(widths: widths)
        }
      }
      .padding(.horizontal, inset)
      .padding(.bottom, inset)
    }
    .background(.kitField, in: RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous))
    .clipShape(RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous))
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { available = $0 }
    .focusable(!editing)
    .focused($isFocused)
    .focusEffectDisabled()
    .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow, .return, .escape, .tab]) { press in
      handle(press, visible: visible)
    }
    .accessibilityElement(children: .contain)
  }

  // MARK: Header

  private func header(widths: [CGFloat]) -> some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: gutter)
      ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
        headerCell(column, width: widths[index], resizable: index < columns.count - 1)
      }
    }
    .frame(height: 28)
    .background {
      // Rows scroll under the pinned header: it takes the track's colour over the window.
      Rectangle().fill(.kitWindow).overlay(Rectangle().fill(.kitField)).padding(.horizontal, -inset)
    }
  }

  private func headerCell(_ column: KitGridColumn<Row>, width: CGFloat, resizable: Bool) -> some View {
    let sorted = sort?.column == column.id
    return Button {
      withKitAnimation {
        sort = KitGridSort(column.id, ascending: sorted ? !(sort?.ascending ?? true) : true)
      }
    } label: {
      HStack(spacing: 4) {
        if let image = column.systemImage {
          Image(systemName: image).font(.system(size: 9, weight: .semibold))
        }
        Text(column.title).lineLimit(1)
        if let detail = column.detail { Chip(detail, style: .quiet) }
        if sorted {
          Image(systemName: "chevron.down")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(Hue.accent.text)
            .rotationEffect(.degrees(sort?.ascending == true ? 180 : 0))
        }
      }
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(sorted ? AnyShapeStyle(.kitLabel) : AnyShapeStyle(.kitSecondary))
      .padding(.horizontal, 8)
      .frame(width: width, height: 28, alignment: column.frameAlignment)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(column.title)
    .accessibilityHint(sorted ? (sort?.ascending == false ? "Sorted descending" : "Sorted ascending") : "Sort")
    .overlay(alignment: .trailing) {
      if resizable { ResizeHandle(width: width) { resized[column.id] = max(40, $0) } reset: { resized[column.id] = nil } }
    }
  }

  // MARK: Rows

  private func rowView(
    _ row: Row, index: Int, widths: [CGFloat], visible: [(row: Row, depth: Int, hasChildren: Bool)]
  ) -> some View {
    let state = rowState?(row)
    let selected = selection.contains(row.id)
    let previousSelected = index > 0 && selection.contains(visible[index - 1].row.id)
    let nextSelected = index + 1 < visible.count && selection.contains(visible[index + 1].row.id)
    let outline = children == nil ? nil : (depth: visible[index].depth, hasChildren: visible[index].hasChildren)
    return HStack(spacing: 0) {
      if rowState != nil {
        ZStack {
          if let state { Tile(systemImage: state.systemImage, hue: state.hue, size: 18) }
        }
        .frame(width: gutter)
      }
      ForEach(Array(columns.enumerated()), id: \.element.id) { column, item in
        cell(row, column: item, index: column, width: widths[column], state: state, outline: column == 0 ? outline : nil)
      }
    }
    .frame(minHeight: rowHeight, maxHeight: heightMode == .automatic ? nil : rowHeight)
    .fixedSize(horizontal: false, vertical: heightMode == .automatic)
    .background {
      RowGround(
        selected: selected, striped: index % 2 == 1, hovered: hovered == row.id, state: state,
        mergeTop: selected && previousSelected, mergeBottom: selected && nextSelected, active: isActive)
    }
    .kitHover { hovered = $0 ? row.id : (hovered == row.id ? nil : hovered) }
    .modifier(GridRowMenu(ids: selected ? selection : [row.id], menu: menu))
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityValue(state?.title ?? "")
  }

  private func cell(
    _ row: Row, column: KitGridColumn<Row>, index: Int, width: CGFloat, state: KitGridRowState?,
    outline: (depth: Int, hasChildren: Bool)?
  ) -> some View {
    let focused = focusRow == row.id && focusColumn == index
    return ZStack(alignment: column.frameAlignment) {
      if focused {
        RoundedRectangle(cornerRadius: KitMetrics.radiusSmall, style: .continuous)
          .fill(.kitRaised)
          .overlay {
            RoundedRectangle(cornerRadius: KitMetrics.radiusSmall, style: .continuous)
              .strokeBorder(Hue.accent.fill, lineWidth: 1.5)
          }
          .frame(height: KitMetrics.controlSmall + (idiom.size(0, touch: 8)))
          .padding(.horizontal, 2)
      }
      if focused, editing {
        TextField(column.title, text: $draft)
          .textFieldStyle(.plain)
          .font(cellFont(column))
          .multilineTextAlignment(column.alignment == .trailing ? .trailing : .leading)
          .focused($isFieldFocused)
          .onSubmit { commit(row, column) }
          .onKeyPress(.escape) {
            cancelEditing()
            return .handled
          }
          .padding(.horizontal, 8)
      } else {
        HStack(spacing: 4) {
          if let outline {
            disclosure(row, hasChildren: outline.hasChildren)
              .padding(.leading, CGFloat(outline.depth) * (idiom.size(14, touch: 20)))
          }
          cellContent(row, column: column, state: state)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, heightMode == .automatic ? 6 : 0)
      }
    }
    .frame(width: width, alignment: column.frameAlignment)
    .frame(maxHeight: .infinity)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) {
      focus(row, column: index, extending: false)
      if column.edit != nil {
        beginEditing(row, column)
      } else {
        primaryAction?(selection)
      }
    }
    .simultaneousGesture(TapGesture().onEnded { focus(row, column: index, extending: false) })
  }

  @ViewBuilder
  private func cellContent(_ row: Row, column: KitGridColumn<Row>, state: KitGridRowState?) -> some View {
    let deleted = state == .deleted
    Group {
      if let cell = column.cell {
        cell(row)
      } else if let value = column.value {
        switch value(row) {
        case .none:
          DataNullChip()
        case .some(let text) where text.isEmpty:
          Text("empty").italic().foregroundStyle(.kitQuiet)
        case .some(let text):
          Text(text)
            .font(cellFont(column))
            .monospacedDigit()
            .foregroundStyle(deleted ? AnyShapeStyle(Hue.red.text) : AnyShapeStyle(.kitLabel))
        }
      }
    }
    .strikethrough(deleted)
    .lineLimit(heightMode == .automatic ? nil : 1)
    .truncationMode(.tail)
  }

  /// An outline row's chevron (or the empty slot of a leaf), which opens and closes it.
  @ViewBuilder
  private func disclosure(_ row: Row, hasChildren: Bool) -> some View {
    let size: CGFloat = idiom.size(12, touch: 14)
    if hasChildren {
      let isOpen = expanded.wrappedValue.contains(row.id)
      Button {
        withKitAnimation { toggle(row.id) }
      } label: {
        Image(systemName: "chevron.right")
          .font(.system(size: size * 0.75, weight: .semibold))
          .foregroundStyle(.kitSecondary)
          .rotationEffect(.degrees(isOpen ? 90 : 0))
          .frame(width: size, height: size)
          .contentShape(Rectangle().inset(by: -4))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isOpen ? "Collapse" : "Expand")
    } else {
      Color.clear.frame(width: size, height: size)
    }
  }

  private func toggle(_ id: Row.ID) {
    if expanded.wrappedValue.contains(id) { expanded.wrappedValue.remove(id) } else { expanded.wrappedValue.insert(id) }
  }

  private func cellFont(_ column: KitGridColumn<Row>) -> Font {
    let touch: CGFloat = idiom.size(0, touch: 4)
    return column.isMono
      ? .system(size: 12 + touch, design: .monospaced) : .system(size: 13 + touch)
  }

  // MARK: Focus, selection, editing

  private func focus(_ row: Row, column: Int, extending: Bool) {
    if editing { cancelEditing() }
    isFocused = true
    focusRow = row.id
    focusColumn = column
    selection = KitGridLayout.selection(rows.map(\.id), anchor: anchor, target: row.id, extending: extending)
    if !extending { anchor = row.id }
  }

  private func handle(_ press: KeyPress, visible: [(row: Row, depth: Int, hasChildren: Bool)]) -> KeyPress.Result {
    let shown = visible.map(\.row)
    let ids = shown.map(\.id)
    switch press.key {
    case .upArrow, .downArrow:
      let offset = press.key == .upArrow ? -1 : 1
      let current = focusRow.flatMap { ids.firstIndex(of: $0) }
      let next = current.map { min(max($0 + offset, 0), ids.count - 1) } ?? (offset > 0 ? 0 : ids.count - 1)
      guard ids.indices.contains(next) else { return .ignored }
      focus(shown[next], column: focusColumn ?? 0, extending: press.modifiers.contains(.shift))
      return .handled
    case .leftArrow where children != nil && (focusColumn ?? 0) == 0,
      .rightArrow where children != nil && (focusColumn ?? 0) == 0:
      // In an outline, ← → on the first column close and open the focused row (or go to its parent).
      guard let id = focusRow, let index = ids.firstIndex(of: id) else { return .ignored }
      let isOpen = expanded.wrappedValue.contains(id)
      if press.key == .rightArrow {
        guard visible[index].hasChildren, !isOpen else { return moveColumn(press, ids: ids) }
        withKitAnimation { toggle(id) }
      } else if visible[index].hasChildren && isOpen {
        withKitAnimation { toggle(id) }
      } else if let parent = visible[..<index].last(where: { $0.depth < visible[index].depth }) {
        focus(parent.row, column: 0, extending: false)
      } else {
        return .ignored
      }
      return .handled
    case .leftArrow, .rightArrow, .tab:
      let back = press.key == .leftArrow || (press.key == .tab && press.modifiers.contains(.shift))
      focusColumn = KitGridLayout.column(focusColumn, by: back ? -1 : 1, count: columns.count)
      if focusRow == nil { focusRow = ids.first }
      return .handled
    case .return:
      guard let id = focusRow, let row = shown.first(where: { $0.id == id }) else { return .ignored }
      guard let index = focusColumn, columns[index].edit != nil else {
        guard let primaryAction else { return .ignored }
        primaryAction(selection)
        return .handled
      }
      beginEditing(row, columns[index])
      return .handled
    case .escape:
      if focusColumn != nil {
        focusColumn = nil
        return .handled
      }
      return .ignored
    default:
      return .ignored
    }
  }

  private func moveColumn(_ press: KeyPress, ids: [Row.ID]) -> KeyPress.Result {
    focusColumn = KitGridLayout.column(focusColumn, by: press.key == .leftArrow ? -1 : 1, count: columns.count)
    if focusRow == nil { focusRow = ids.first }
    return .handled
  }

  private func beginEditing(_ row: Row, _ column: KitGridColumn<Row>) {
    guard column.edit != nil, let value = column.value else { return }
    draft = value(row) ?? ""
    editing = true
    isFieldFocused = true
  }

  private func commit(_ row: Row, _ column: KitGridColumn<Row>) {
    column.edit?(row, draft)
    cancelEditing()
  }

  private func cancelEditing() {
    editing = false
    isFieldFocused = false
    isFocused = true
  }
}

extension KitGrid where Footer == EmptyView {
  /// A grid without a footer row.
  public init(
    _ rows: [Row], columns: [KitGridColumn<Row>], selection: Binding<Set<Row.ID>>,
    sort: Binding<KitGridSort?> = .constant(nil), rowState: ((Row) -> KitGridRowState?)? = nil,
    children: KeyPath<Row, [Row]?>? = nil, expanded: Binding<Set<Row.ID>>? = nil,
    rowHeight: KitGridRowHeight = .standard, primaryAction: ((Set<Row.ID>) -> Void)? = nil
  ) {
    self.init(
      rows, columns: columns, selection: selection, sort: sort, rowState: rowState, children: children,
      expanded: expanded, rowHeight: rowHeight, primaryAction: primaryAction
    ) { EmptyView() }
  }
}

/// A row's context menu, when the grid has one.
private struct GridRowMenu<ID: Hashable>: ViewModifier {
  let ids: Set<ID>
  let menu: ((Set<ID>) -> AnyView)?

  func body(content: Content) -> some View {
    if let menu {
      content.kitContextMenu { menu(ids) }
    } else {
      content
    }
  }
}

/// A row's ground: raised when selected (a run of selected rows merges into one shape), tinted when deleted or new,
/// striped every other row, a wash under the pointer.
private struct RowGround: View {
  let selected: Bool
  let striped: Bool
  let hovered: Bool
  let state: KitGridRowState?
  let mergeTop: Bool
  let mergeBottom: Bool
  let active: Bool
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let shape = DataRunShape(radius: KitMetrics.radiusSmall, squareTop: mergeTop, squareBottom: mergeBottom)
    if selected {
      // The 2pt gap between merged rows is filled from the upper row down.
      shape.fill(.kitRaised)
        .padding(.bottom, mergeBottom ? -2 : 0)
        .shadow(color: .black.opacity(scheme == .dark || !active ? 0 : 0.1), radius: 1, y: 0.5)
        .opacity(active ? 1 : 0.6)
    } else if let state, state != .edited {
      shape.fill(state.hue.soft(hovered ? 0.18 : 0.12))
    } else if hovered {
      shape.fill(KitColor.rowHover)
    } else if striped {
      shape.fill(.kitFillSoft)
    }
  }
}

/// The 9pt grab area on a header's trailing edge: drag to resize the column, double-click to reset it.
private struct ResizeHandle: View {
  let width: CGFloat
  let resize: (CGFloat) -> Void
  let reset: () -> Void
  @State private var start: CGFloat?
  @State private var isHovered = false

  var body: some View {
    Rectangle()
      .fill(Color.clear)
      .frame(width: 9)
      .overlay {
        Rectangle()
          .fill(start != nil ? AnyShapeStyle(Hue.accent.fill) : AnyShapeStyle(.kitSeparator))
          .frame(width: start != nil ? 2 : 1, height: 16)
          .opacity(start != nil || isHovered ? 1 : 0)
      }
      .contentShape(Rectangle())
      .offset(x: 4.5)
      .kitHover { isHovered = $0 }
      #if !os(tvOS)
      .gesture(
        DragGesture(minimumDistance: 1)
          .onChanged { value in
            if start == nil { start = width }
            resize((start ?? width) + value.translation.width)
          }
          .onEnded { _ in start = nil }
      )
      #endif
      .onTapGesture(count: 2, perform: reset)
      .accessibilityHidden(true)
  }
}

private struct PreviewOrder: Identifiable {
  var id: Int
  var status: String
  var total: String
  var note: String?
}

#Preview("Grid") {
  @Previewable @State var selection: Set<Int> = [10234]
  @Previewable @State var sort: KitGridSort? = KitGridSort("id", ascending: false)
  let orders = [
    PreviewOrder(id: 10237, status: "refunded", total: "443.00", note: "Call before delivery"),
    PreviewOrder(id: 10236, status: "refunded", total: "662.00", note: nil),
    PreviewOrder(id: 10235, status: "cancelled", total: "39.00", note: nil),
    PreviewOrder(id: 10234, status: "pending", total: "136.00", note: ""),
    PreviewOrder(id: 10233, status: "shipped", total: "177.00", note: "Leave at the door"),
  ]
  let columns: [KitGridColumn<PreviewOrder>] = [
    KitGridColumn("id", systemImage: "key", width: 80, alignment: .trailing) { "\($0.id)" },
    KitGridColumn("status", width: 110) { Chip(status: $0.status) },
    KitGridColumn("total", width: 90, alignment: .trailing) { $0.total },
    KitGridColumn("note", \.note) { _, _ in },
  ]
  KitGrid(orders, columns: columns, selection: $selection, sort: $sort) { order in
    order.id == 10236 ? .edited : order.id == 10235 ? .deleted : nil
  }
  .frame(width: 600, height: 260)
  .padding(KitMetrics.gutter)
  .componentKit()
}
