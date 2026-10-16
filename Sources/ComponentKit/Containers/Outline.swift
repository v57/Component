import SwiftUI

// Tree rows: the disclosure chevron a `SidebarRow` leads with, `KitOutline` (a tree of rows from data, indented and
// expandable), and the keyboard navigation `KitSidebar` and `KitList` share (↑↓ move, ← closes or goes to the parent,
// → opens or goes to the first child, Return).

/// A row's disclosure: its open state, or a leaf's empty slot (so icons in a tree line up).
struct ContRowDisclosure {
  /// `nil`: a leaf in a tree, which keeps the chevron's slot.
  var isExpanded: Binding<Bool>?
}

extension EnvironmentValues {
  /// Set by `KitOutline` on each of its rows.
  @Entry var contRowDisclosure: ContRowDisclosure? = nil
}

/// The chevron: right when closed, down when open; 12pt (14 on touch). A tap opens or closes it.
struct ContDisclosureButton: View {
  let disclosure: ContRowDisclosure
  let title: String
  @Environment(\.kitIdiom) private var idiom
  @State private var isHovered = false

  var body: some View {
    let size: CGFloat = idiom.isTouch ? 14 : 12
    if let isExpanded = disclosure.isExpanded {
      Button {
        withKitAnimation { isExpanded.wrappedValue.toggle() }
      } label: {
        Image(systemName: "chevron.right")
          .font(.system(size: size * 0.75, weight: .semibold))
          .foregroundStyle(isHovered ? .kitLabel : .kitSecondary)
          .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
          .frame(width: size, height: size)
          .padding(.horizontal, -1)
          .contentShape(Rectangle().inset(by: -4))
      }
      .buttonStyle(.plain)
      .onHover { isHovered = $0 }
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
/// children (`nil` children: a leaf, which keeps the chevron's slot so the icons line up). Put `SidebarRow`s in it,
/// inside a `KitSidebar`, `KitList` or `KitSection`; ← → open and close the selected row from the keyboard.
///
/// The open folders live in the outline unless you pass `expanded` (the ids of the open items) to keep them.
///
/// ```swift
/// KitOutline(files, children: \.children) { file in
///   SidebarRow(value: file.id, file.name, systemImage: file.isFolder ? "folder" : "doc")
/// }
/// KitOutline(groups, children: \.children, expanded: $openGroups) { group in … }
/// ```
public struct KitOutline<Element: Identifiable, RowContent: View>: View {
  let items: [Element]
  let children: KeyPath<Element, [Element]?>
  let expanded: Binding<Set<Element.ID>>?
  let row: (Element) -> RowContent
  @State private var ownExpanded: Set<Element.ID> = []
  @Environment(\.contRowIndent) private var baseIndent

  /// An outline of `items`; `children` is `nil` for a leaf.
  public init(
    _ items: some RandomAccessCollection<Element>, children: KeyPath<Element, [Element]?>,
    expanded: Binding<Set<Element.ID>>? = nil, @ViewBuilder row: @escaping (Element) -> RowContent
  ) {
    self.items = Array(items)
    self.children = children
    self.expanded = expanded
    self.row = row
  }

  public var body: some View {
    let open = expanded ?? $ownExpanded
    ForEach(items) { item in
      ContOutlineNode(item: item, children: children, expanded: open, level: baseIndent, row: row)
    }
  }
}

/// One item of an outline and, while it's open, its children one level in.
private struct ContOutlineNode<Element: Identifiable, RowContent: View>: View {
  let item: Element
  let children: KeyPath<Element, [Element]?>
  @Binding var expanded: Set<Element.ID>
  let level: Int
  let row: (Element) -> RowContent

  var body: some View {
    let kids = item[keyPath: children]
    let id = item.id
    let isOpen = Binding(
      get: { expanded.contains(id) },
      set: { open in
        if open { expanded.insert(id) } else { expanded.remove(id) }
      })
    row(item)
      .environment(\.contRowIndent, level)
      .environment(\.contRowDisclosure, ContRowDisclosure(isExpanded: kids == nil ? nil : isOpen))
    if let kids, expanded.contains(id) {
      ForEach(kids) { child in
        ContOutlineNode(item: child, children: children, expanded: $expanded, level: level + 1, row: row)
      }
      .transition(.opacity)
    }
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

/// Arrow keys and Return over the rows of a `KitSidebar` or `KitList`.
struct ContRowKeyboard: ViewModifier {
  let current: AnyHashable?
  let select: @MainActor (AnyHashable) -> Void
  let onReturn: (@MainActor () -> Void)?
  var onPrimary: (@MainActor (AnyHashable) -> Void)? = nil
  @State private var rows: [ContRowNavItem] = []

  func body(content: Content) -> some View {
    content
      .onPreferenceChange(ContRowNavKey.self) { rows in
        MainActor.assumeIsolated { self.rows = rows }
      }
      .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow, .return]) { press in
        handle(press.key)
      }
  }

  private func handle(_ key: KeyEquivalent) -> KeyPress.Result {
    let plain = rows.map { (value: $0.value, indent: $0.indent, isOpen: $0.isOpen) }
    let step: ContRowNav.Step
    switch key {
    case .upArrow: step = ContRowNav.move(current, by: -1, in: plain)
    case .downArrow: step = ContRowNav.move(current, by: 1, in: plain)
    case .leftArrow: step = ContRowNav.left(current, in: plain)
    case .rightArrow: step = ContRowNav.right(current, in: plain)
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
    case .select(let value): select(value)
    case .expand(let value), .collapse(let value):
      guard let isExpanded = rows.first(where: { $0.value == value })?.disclosure?.isExpanded else { return .ignored }
      withKitAnimation { isExpanded.wrappedValue = step == .expand(value) }
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
