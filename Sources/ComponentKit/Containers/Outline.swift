import SwiftUI

// Tree rows: the disclosure chevron a `SidebarRow` leads with, `KitOutline` (a tree of rows from data, indented and
// expandable), and the keyboard navigation `KitSidebar` and `KitList` share (↑↓ move, ← closes or goes to the parent,
// → opens or goes to the first child, Return).

/// A row's disclosure: its open state, or a leaf's empty slot (so icons in a tree line up).
struct ContRowDisclosure: Equatable {
  /// `nil`: a leaf in a tree, which keeps the chevron's slot.
  var isExpanded: Binding<Bool>?
  /// Opens or closes the row with everything inside it (an ⌥-click on the chevron); `nil` where the row's children
  /// aren't known (then ⌥-click opens or closes the row alone).
  var setRecursively: ((Bool) -> Void)? = nil
  /// The `KitOutline` item it opens: two disclosures of one item in the same state are equal, so an outline built
  /// again leaves its rows alone (its bindings and closures are new each time, the state they reach the same).
  var id: AnyHashable? = nil

  static func == (a: Self, b: Self) -> Bool {
    guard let id = a.id, id == b.id else { return false }
    return a.isExpanded?.wrappedValue == b.isExpanded?.wrappedValue && (a.isExpanded == nil) == (b.isExpanded == nil)
      && (a.setRecursively == nil) == (b.setRecursively == nil)
  }

  /// Opens or closes the row; with ⌥ held, everything inside it too, as in Finder and Xcode.
  @MainActor func toggle() {
    guard let isExpanded else { return }
    let open = !isExpanded.wrappedValue
    withKitAnimation {
      if let setRecursively, KitDesktop.modifierKeys.contains(.option) {
        setRecursively(open)
      } else {
        isExpanded.wrappedValue = open
      }
    }
  }
}

extension EnvironmentValues {
  /// Set by `KitOutline` on each of its rows.
  @Entry var contRowDisclosure: ContRowDisclosure? = nil
}

/// The chevron: right when closed, down when open; 12pt (14 on touch). A tap opens or closes it, an ⌥-click everything
/// inside it too (in a `KitOutline`).
struct ContDisclosureButton: View {
  let disclosure: ContRowDisclosure
  let title: String
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    let size: CGFloat = idiom.size(12, touch: 14)
    if let isExpanded = disclosure.isExpanded {
      Button {
        disclosure.toggle()
      } label: {
        Image(systemName: "chevron.right")
          .font(.system(size: size * 0.75, weight: .semibold))
          .foregroundStyle(.kitSecondary)
          .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
          .frame(width: size, height: size)
          .padding(.horizontal, -1)
          .contentShape(Rectangle().inset(by: -4))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isExpanded.wrappedValue ? "Collapse \(title)" : "Expand \(title)")
    } else {
      Color.clear.frame(width: size - 2, height: size).accessibilityHidden(true)
    }
  }
}

/// VoiceOver: an expandable row says so and offers Expand or Collapse.
struct ContDisclosureAccessibility: ViewModifier {
  let disclosure: ContRowDisclosure?

  func body(content: Content) -> some View {
    if let isExpanded = disclosure?.isExpanded {
      content
        .accessibilityValue(isExpanded.wrappedValue ? "Expanded" : "Collapsed")
        .accessibilityAction(named: isExpanded.wrappedValue ? "Collapse" : "Expand") {
          withKitAnimation { isExpanded.wrappedValue.toggle() }
        }
    } else {
      content
    }
  }
}

// MARK: - KitOutline

/// A tree of rows from data: each item's row, indented one step a level, with a disclosure chevron when it has
/// children (`nil` children: a leaf, which keeps the chevron's slot so the icons line up). An outline whose items
/// have no children at all (a project list before any group is made) is a plain list: its leaves keep no slot, so
/// the same `KitOutline` serves with and without groups. Rows nested inside an item's own row content (indented with
/// `.kitRowIndent(_:)`) take neither its chevron nor its slot. Put `SidebarRow`s in it,
/// inside a `KitSidebar`, `KitList` or `KitSection`; ← → open and close the selected row from the keyboard. A
/// `SidebarRow` that selects nothing and has no action (a group) opens and closes on a click; `RecentItem`s take
/// the indent and the chevron too, so a welcome screen's project groups are an outline as well.
///
/// The open folders live in the outline unless you pass `expanded` (the ids of the open items) to keep them, or
/// `collapsed` (the ids of the closed ones: everything starts open, as groups do), e.g. a `KitIDSet` in
/// `@AppStorage`. `children` is a key path or a closure.
///
/// ```swift
/// KitOutline(files, children: \.children) { file in
///   SidebarRow(value: file.id, file.name, systemImage: file.isFolder ? "folder" : "doc")
/// }
/// KitOutline(groups, children: \.children, expanded: $openGroups) { group in … }
///
/// @AppStorage("collapsedGroups") private var collapsed = KitIDSet()
/// KitOutline(tree.roots, children: { $0.group == nil ? nil : $0.children }, collapsed: $collapsed.ids) { node in
///   switch node {
///   case .group(let group, _): SidebarRow(group.name, systemImage: "folder")
///   case .project(let project): SidebarRow(value: project.id, project.name, systemImage: "shippingbox")
///   }
/// }
/// ```
public struct KitOutline<Element: Identifiable, RowContent: View>: View {
  let items: [Element]
  let children: (Element) -> [Element]?
  let expansion: ContOutlineExpansion<Element.ID>?
  let row: (Element) -> RowContent
  @State private var ownExpanded: Set<Element.ID> = []
  @Environment(\.contRowIndent) private var baseIndent

  /// An outline of `items`; `children` is `nil` for a leaf.
  public init(
    _ items: some RandomAccessCollection<Element>, children: KeyPath<Element, [Element]?>,
    expanded: Binding<Set<Element.ID>>? = nil, @ViewBuilder row: @escaping (Element) -> RowContent
  ) {
    self.init(items, children: { $0[keyPath: children] }, expanded: expanded, row: row)
  }

  /// An outline whose children come from a closure (`nil` for a leaf): an enum's cases, a group's members.
  public init(
    _ items: some RandomAccessCollection<Element>, children: @escaping (Element) -> [Element]?,
    expanded: Binding<Set<Element.ID>>? = nil, @ViewBuilder row: @escaping (Element) -> RowContent
  ) {
    self.items = Array(items)
    self.children = children
    self.expansion = expanded.map { .expanded($0) }
    self.row = row
  }

  /// An outline that keeps the ids of its closed items: everything else is open.
  public init(
    _ items: some RandomAccessCollection<Element>, children: KeyPath<Element, [Element]?>,
    collapsed: Binding<Set<Element.ID>>, @ViewBuilder row: @escaping (Element) -> RowContent
  ) {
    self.init(items, children: { $0[keyPath: children] }, collapsed: collapsed, row: row)
  }

  /// An outline with children from a closure that keeps the ids of its closed items.
  public init(
    _ items: some RandomAccessCollection<Element>, children: @escaping (Element) -> [Element]?,
    collapsed: Binding<Set<Element.ID>>, @ViewBuilder row: @escaping (Element) -> RowContent
  ) {
    self.items = Array(items)
    self.children = children
    self.expansion = .collapsed(collapsed)
    self.row = row
  }

  public var body: some View {
    let open = expansion ?? .expanded($ownExpanded)
    // Nothing opens: no chevrons, so no slots to line up with.
    let isFlat = !items.contains { children($0) != nil }
    ForEach(items) { item in
      ContOutlineNode(
        item: item, children: children, expansion: open, level: baseIndent, reservesLeafSlot: !isFlat, row: row)
    }
  }
}

/// Which items of an outline are open: the ids of the open ones, or of the closed ones.
enum ContOutlineExpansion<ID: Hashable> {
  case expanded(Binding<Set<ID>>)
  case collapsed(Binding<Set<ID>>)

  func isOpen(_ id: ID) -> Bool {
    switch self {
    case .expanded(let ids): ids.wrappedValue.contains(id)
    case .collapsed(let ids): !ids.wrappedValue.contains(id)
    }
  }

  func set(_ id: ID, open: Bool) {
    set([id], open: open)
  }

  /// Opens or closes several in one write.
  func set(_ some: some Sequence<ID>, open: Bool) {
    switch self {
    case .expanded(let ids):
      var new = ids.wrappedValue
      if open { new.formUnion(some) } else { new.subtract(some) }
      if new != ids.wrappedValue { ids.wrappedValue = new }
    case .collapsed(let ids):
      var new = ids.wrappedValue
      if open { new.subtract(some) } else { new.formUnion(some) }
      if new != ids.wrappedValue { ids.wrappedValue = new }
    }
  }

  /// Opens or closes `item` and everything inside it. Opening goes a level at a time, asking for each level's
  /// children after the one above opened, so an app that reads a folder when it opens (a file tree) has them.
  @MainActor func setRecursively<Element: Identifiable>(
    _ item: Element, open: Bool, children: (Element) -> [Element]?
  ) where Element.ID == ID {
    // Far more than anyone opens by hand: a node_modules stays in reach.
    var budget = 5_000
    var level = [item]
    while !level.isEmpty, budget > 0 {
      let ids = level.prefix(budget).map(\.id)
      budget -= ids.count
      if open { set(ids, open: true) }
      // Closing reaches inside closed folders too, so opening one later doesn't bring back its old open folders.
      level = level.flatMap { children($0) ?? [] }.filter { children($0) != nil }
      if !open { set(ids, open: false) }
    }
  }
}

/// One item of an outline and, while it's open, its children one level in.
private struct ContOutlineNode<Element: Identifiable, RowContent: View>: View {
  let item: Element
  let children: (Element) -> [Element]?
  let expansion: ContOutlineExpansion<Element.ID>
  let level: Int
  /// A leaf keeps the chevron's empty slot (some item in the outline opens).
  let reservesLeafSlot: Bool
  let row: (Element) -> RowContent

  var body: some View {
    let kids = children(item)
    let id = item.id
    let expansion = expansion
    let isOpen = Binding(get: { expansion.isOpen(id) }, set: { expansion.set(id, open: $0) })
    let children = children
    let disclosure =
      kids == nil
      ? ContRowDisclosure(isExpanded: nil, id: AnyHashable(id))
      : ContRowDisclosure(
        isExpanded: isOpen, setRecursively: { open in expansion.setRecursively(item, open: open, children: children) },
        id: AnyHashable(id))
    row(item)
      .environment(\.contRowIndent, level)
      .environment(\.contRowDisclosure, kids == nil && !reservesLeafSlot ? nil : disclosure)
    if let kids, expansion.isOpen(id) {
      ForEach(kids) { child in
        ContOutlineNode(
          item: child, children: children, expansion: expansion, level: level + 1, reservesLeafSlot: true, row: row)
      }
      .transition(.opacity)
    }
  }
}

// MARK: - Stored ids

/// A set of ids that `@AppStorage` keeps (one string, the ids a line each): the closed groups of an outline, the
/// items removed from a list. Bind an outline to its `ids`.
///
/// ```swift
/// @AppStorage("welcome.collapsedGroups") private var collapsedGroups = KitIDSet()
/// KitOutline(tree.roots, children: { $0.group == nil ? nil : $0.children }, collapsed: $collapsedGroups.ids) { … }
/// collapsedGroups.toggle(group.id)
/// ```
///
/// The stored string is the same as the apps' own `CollapsedGroups` wrote (sorted ids joined by newlines), so a
/// switch to it keeps what users had closed.
public struct KitIDSet: RawRepresentable, Hashable, Sendable, ExpressibleByArrayLiteral {
  public var ids: Set<String>

  public init() { ids = [] }

  public init(_ ids: some Sequence<String>) { self.ids = Set(ids) }

  public init(arrayLiteral elements: String...) { ids = Set(elements) }

  public init(rawValue: String) {
    ids = Set(rawValue.split(separator: "\n").map(String.init))
  }

  public var rawValue: String { ids.sorted().joined(separator: "\n") }

  public func contains(_ id: String) -> Bool { ids.contains(id) }

  /// Adds `id` if it's missing, removes it if it's there.
  public mutating func toggle(_ id: String) {
    if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
  }
}

// MARK: - Keyboard navigation

/// A row as the keyboard sees it: what it selects, how deep it sits, its disclosure and its action.
struct ContRowNavItem: Equatable {
  var value: AnyHashable
  var indent: Int
  var disclosure: ContRowDisclosure?
  var action: (@MainActor () -> Void)?

  var isOpen: Bool? { disclosure?.isExpanded?.wrappedValue }

  static func == (a: Self, b: Self) -> Bool {
    a.value == b.value && a.indent == b.indent && a.isOpen == b.isOpen && (a.action == nil) == (b.action == nil)
  }
}

/// The rows of a sidebar or list in the order they're drawn.
struct ContRowNavKey: PreferenceKey {
  static var defaultValue: [ContRowNavItem] { [] }
  static func reduce(value: inout [ContRowNavItem], nextValue: () -> [ContRowNavItem]) {
    value.append(contentsOf: nextValue())
  }
}

/// What a key does to a list of rows, apart from views.
enum ContRowNav {
  enum Step: Equatable {
    case select(AnyHashable)
    case expand(AnyHashable)
    case collapse(AnyHashable)
    case none
  }

  /// ↑ (-1) or ↓ (+1) from `current`: the row before or after it, or the first (last) one when nothing is selected.
  static func move(_ current: AnyHashable?, by offset: Int, in rows: [(value: AnyHashable, indent: Int, isOpen: Bool?)])
    -> Step
  {
    guard !rows.isEmpty else { return .none }
    guard let current, let index = rows.firstIndex(where: { $0.value == current }) else {
      return .select(offset >= 0 ? rows[0].value : rows[rows.count - 1].value)
    }
    let next = min(max(index + offset, 0), rows.count - 1)
    return next == index ? .none : .select(rows[next].value)
  }

  /// ←: an open row closes; otherwise the selection goes to its parent (the nearest row above with less indent).
  static func left(_ current: AnyHashable?, in rows: [(value: AnyHashable, indent: Int, isOpen: Bool?)]) -> Step {
    guard let current, let index = rows.firstIndex(where: { $0.value == current }) else { return .none }
    if rows[index].isOpen == true { return .collapse(current) }
    let indent = rows[index].indent
    for parent in rows[..<index].reversed() where parent.indent < indent { return .select(parent.value) }
    return .none
  }

  /// →: a closed row opens; an open one moves the selection to its first child.
  static func right(_ current: AnyHashable?, in rows: [(value: AnyHashable, indent: Int, isOpen: Bool?)]) -> Step {
    guard let current, let index = rows.firstIndex(where: { $0.value == current }) else { return .none }
    switch rows[index].isOpen {
    case false?: return .expand(current)
    case true?:
      let next = index + 1
      return next < rows.count && rows[next].indent > rows[index].indent ? .select(rows[next].value) : .none
    case nil: return .none
    }
  }
}

/// A row's scroll id, so the arrow keys can scroll the selection into view without touching the app's own ids.
struct ContRowScrollID: Hashable {
  var value: AnyHashable?
}

/// Arrow keys and Return over the rows of a `KitSidebar` or `KitList`. The selection scrolls into view as it moves;
/// at the last row built so far (the rows past it are lazy), the list scrolls on to build them and the move goes on.
/// What `ContRowKeyboard` acts with: the selected row and what selecting, Return and scrolling do.
@MainActor final class ContRowKeyboardInputs {
  var current: AnyHashable?
  var select: @MainActor (AnyHashable) -> Void = { _ in }
  var onReturn: (@MainActor () -> Void)?
  var onPrimary: (@MainActor (AnyHashable) -> Void)?
  /// Scrolls the row with this value into view: to `anchor`, or as little as it takes (`nil`).
  var scroll: (@MainActor (AnyHashable, UnitPoint?) -> Void)?
  /// A selection of several rows: it learns the rows' order here, for ⇧-click ranges.
  var clicks: ContRowClicks?
  /// ⇧↑↓ in a selection of several: the range grows to the row.
  var extend: (@MainActor (AnyHashable) -> Void)?

  /// Takes the container's current values (from its body) and returns itself.
  func configured(
    current: AnyHashable?, select: @escaping @MainActor (AnyHashable) -> Void, onReturn: (@MainActor () -> Void)?,
    onPrimary: (@MainActor (AnyHashable) -> Void)?, scroll: (@MainActor (AnyHashable, UnitPoint?) -> Void)?,
    clicks: ContRowClicks?, extend: (@MainActor (AnyHashable) -> Void)?
  ) -> Self {
    self.current = current
    self.select = select
    self.onReturn = onReturn
    self.onPrimary = onPrimary
    self.scroll = scroll
    self.clicks = clicks
    self.extend = extend
    return self
  }
}

struct ContRowKeyboard: ViewModifier {
  /// What the keys act with, in a box the container fills as it updates: the modifier stays the same value as the
  /// selection changes, and so do its key handlers. New handlers changed the environment of everything inside, and
  /// every lazy stack in a sidebar resolved its rows again on each new selection.
  let inputs: ContRowKeyboardInputs
  @State private var rows: [ContRowNavItem] = []

  private var current: AnyHashable? { inputs.current }
  private var select: @MainActor (AnyHashable) -> Void { inputs.select }
  private var onReturn: (@MainActor () -> Void)? { inputs.onReturn }
  private var onPrimary: (@MainActor (AnyHashable) -> Void)? { inputs.onPrimary }
  private var scroll: (@MainActor (AnyHashable, UnitPoint?) -> Void)? { inputs.scroll }
  private var clicks: ContRowClicks? { inputs.clicks }
  private var extend: (@MainActor (AnyHashable) -> Void)? { inputs.extend }

  func body(content: Content) -> some View {
    content
      .onPreferenceChange(ContRowNavKey.self) { rows in
        MainActor.assumeIsolated {
          self.rows = rows
          clicks?.order = rows.map(\.value)
        }
      }
      .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow, .return]) { press in
        handle(press.key, extending: press.modifiers.contains(.shift), recursive: press.modifiers.contains(.option))
      }
  }

  private var plainRows: [(value: AnyHashable, indent: Int, isOpen: Bool?)] {
    rows.map { (value: $0.value, indent: $0.indent, isOpen: $0.isOpen) }
  }

  /// ↑/↓ past the last row built: the list scrolls the selected row to its far edge, the rows past it build, and
  /// the move goes on once they're in.
  private func moveOn(by offset: Int) -> KeyPress.Result {
    guard let current, let scroll else { return .ignored }
    scroll(current, offset > 0 ? .top : .bottom)
    let rows = $rows
    let select = select
    Task { @MainActor in
      for _ in 0..<6 {
        await kitSleep(for: .milliseconds(34))
        let plain = rows.wrappedValue.map { (value: $0.value, indent: $0.indent, isOpen: $0.isOpen) }
        if case .select(let value) = ContRowNav.move(current, by: offset, in: plain) {
          select(value)
          scroll(value, nil)
          return
        }
      }
    }
    return .handled
  }

  /// `recursive`: ⌥→ and ⌥← open or close everything inside the row too.
  private func handle(_ key: KeyEquivalent, extending: Bool = false, recursive: Bool = false) -> KeyPress.Result {
    let plain = plainRows
    let step: ContRowNav.Step
    switch key {
    case .upArrow, .downArrow:
      let offset = key == .upArrow ? -1 : 1
      step = ContRowNav.move(current, by: offset, in: plain)
      if step == .none { return moveOn(by: offset) }
    case .leftArrow: step = ContRowNav.left(current, in: plain)
    case .rightArrow:
      // ⌥→ on an open row opens what's inside it rather than moving in.
      let row = rows.first { $0.value == current }
      if recursive, let current, row?.disclosure?.setRecursively != nil {
        step = .expand(current)
      } else {
        step = ContRowNav.right(current, in: plain)
      }
    case .return:
      let row = rows.first { $0.value == current }
      if let action = row?.action {
        action()
      } else if let onReturn {
        onReturn()
      } else if let onPrimary, let current {
        onPrimary(current)
      } else if let isExpanded = row?.disclosure?.isExpanded {
        withKitAnimation { isExpanded.wrappedValue.toggle() }
      } else {
        return .ignored
      }
      return .handled
    default: return .ignored
    }
    switch step {
    case .select(let value):
      if extending, let extend { extend(value) } else { select(value) }
      scroll?(value, nil)
    case .expand(let value), .collapse(let value):
      guard let disclosure = rows.first(where: { $0.value == value })?.disclosure,
        let isExpanded = disclosure.isExpanded
      else { return .ignored }
      let open = step == .expand(value)
      withKitAnimation {
        if recursive, let setRecursively = disclosure.setRecursively {
          setRecursively(open)
        } else {
          isExpanded.wrappedValue = open
        }
      }
    case .none: return .ignored
    }
    return .handled
  }
}

private struct PreviewNode: Identifiable {
  var id: String { name }
  var name: String
  var children: [PreviewNode]?
}

#Preview("Outline") {
  @Previewable @State var selection: String? = "Trip.swift"
  @Previewable @State var open: Set<String> = ["Sources", "Models"]
  let tree = [
    PreviewNode(name: "Sources", children: [
      PreviewNode(name: "Models", children: [PreviewNode(name: "Trip.swift"), PreviewNode(name: "Stop.swift")]),
      PreviewNode(name: "App.swift"),
    ]),
    PreviewNode(name: "Tests", children: []),
    PreviewNode(name: "Package.swift"),
  ]
  KitSidebar(selection: $selection) {
    KitSection("Atlas", meta: "Swift package", systemImage: "folder") {
      KitOutline(tree, children: \.children, expanded: $open) { node in
        SidebarRow(value: node.name, node.name, systemImage: node.children == nil ? "swift" : "folder")
      }
    }
  }
  .kitSectionStyle(.plain)
  .frame(width: 260, height: 320)
  .componentKit()
}
