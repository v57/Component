import SwiftUI

/// One tab of a `KitTabStrip`: its id, title, an optional SF Symbol in a hue (or any icon view), whether it has
/// unsaved edits, and whether it's a preview (a file shown until another replaces it: the title in italics).
///
/// ```swift
/// KitTab(id: file.id, title: "TripStore.swift", systemImage: "swift", hue: .orange, isEdited: true)
/// KitTab(id: file.id, title: file.name, isPreview: true) { FileIcon(file) }
/// ```
public struct KitTab<ID: Hashable>: Identifiable {
  public var id: ID
  public var title: String
  public var systemImage: String?
  /// The icon's hue; `nil` draws it in the tab's text colour.
  public var hue: Hue?
  /// Unsaved edits: a dot where the close button sits (the close button shows on hover).
  public var isEdited: Bool
  /// A preview tab: its title in italics, until the app keeps it (an edit, a double click).
  public var isPreview: Bool
  /// An icon view in place of the SF Symbol (a file's icon drawn as letters), about 14pt.
  public var icon: AnyView?
  /// What the icon view shows (a file's URL), so the strip can tell an unchanged tab from a changed one: without it a
  /// tab with an icon view is redrawn whenever the strip is.
  public var iconID: AnyHashable?

  public init(
    id: ID, title: String, systemImage: String? = nil, hue: Hue? = nil, isEdited: Bool = false,
    isPreview: Bool = false
  ) {
    self.id = id
    self.title = title
    self.systemImage = systemImage
    self.hue = hue
    self.isEdited = isEdited
    self.isPreview = isPreview
  }

  /// A tab with any icon view; `iconID` names what it shows (a file's URL), so switching tabs doesn't redraw the
  /// others.
  public init<Icon: View>(
    id: ID, title: String, isEdited: Bool = false, isPreview: Bool = false, iconID: AnyHashable? = nil,
    @ViewBuilder icon: () -> Icon
  ) {
    self.init(id: id, title: title, isEdited: isEdited, isPreview: isPreview)
    self.icon = AnyView(icon())
    self.iconID = iconID
  }

  /// Whether the tab draws the same as `other` (an icon view without an `iconID` never does).
  func drawsSame(as other: Self) -> Bool {
    id == other.id && title == other.title && systemImage == other.systemImage && hue == other.hue
      && isEdited == other.isEdited && isPreview == other.isPreview && (icon == nil) == (other.icon == nil)
      && (icon == nil || (iconID != nil && iconID == other.iconID))
  }
}

/// The kit's tab strip (editor tabs, query tabs): the tabs on a card as wide as they are, like a toolbar's tool
/// group, opaque over content that runs on under it, 8pt in from the sides and above what follows; the selected tab a
/// raised card that glides to the new pick, a close button on the selected and the hovered tab, a dot on an edited
/// one, and an optional + at the end. It scrolls sideways inside the card when the tabs don't fit. A single tab isn't
/// shown (the content says what is open): the card then holds the + alone, and without one the strip takes no room.
/// Keyboard: Tab focuses a tab (a solid ring), ← → move, Space selects. VoiceOver: each tab is a selectable button
/// with a Close action.
///
/// ```swift
/// KitTabStrip(tabs: documents.map { KitTab(id: $0.id, title: $0.name, isEdited: $0.isDirty) },
///             selection: $current, onClose: { close($0) }, onAdd: { newQuery() })
/// ```
public struct KitTabStrip<ID: Hashable>: View {
  var tabs: [KitTab<ID>]
  @Binding var selection: ID?
  var onClose: ((ID) -> Void)?
  var onAdd: (() -> Void)?
  var onMove: ((IndexSet, Int) -> Void)?
  var menu: ((ID) -> AnyView)?
  var onDoubleClick: ((ID) -> Void)?
  @Environment(\.kitIdiom) private var idiom
  @FocusState private var focus: ID?
  @Namespace private var namespace
  @State private var reorder = ContReorderState()
  @State private var list = UUID()
  @State private var keys = CtlTabKeys.Handler()
  @State private var actions = CtlTabActions<ID>()

  /// A tab strip; `onMove` lets the tabs reorder by dragging (it takes `.onMove`'s arguments, so
  /// `tabs.move(fromOffsets:toOffset:)` fits).
  public init(
    tabs: [KitTab<ID>], selection: Binding<ID?>, onClose: ((ID) -> Void)? = nil, onAdd: (() -> Void)? = nil,
    onMove: ((IndexSet, Int) -> Void)? = nil
  ) {
    self.tabs = tabs
    _selection = selection
    self.onClose = onClose
    self.onAdd = onAdd
    self.onMove = onMove
  }

  /// A tab strip that always has a selected tab.
  public init(
    tabs: [KitTab<ID>], selection: Binding<ID>, onClose: ((ID) -> Void)? = nil, onAdd: (() -> Void)? = nil,
    onMove: ((IndexSet, Int) -> Void)? = nil
  ) {
    self.init(
      tabs: tabs,
      selection: Binding<ID?>(get: { selection.wrappedValue }, set: { if let id = $0 { selection.wrappedValue = id } }),
      onClose: onClose, onAdd: onAdd, onMove: onMove)
  }

  /// A context menu for each tab (Close Others, Keep Open, Reveal in Finder), given the tab's id.
  ///
  /// ```swift
  /// KitTabStrip(tabs: tabs, selection: $current).tabContextMenu { id in
  ///   Button("Close Other Tabs") { closeOthers(than: id) }
  /// }
  /// ```
  public func tabContextMenu<Menu: View>(@ViewBuilder _ menu: @escaping (ID) -> Menu) -> Self {
    var strip = self
    strip.menu = { AnyView(menu($0)) }
    return strip
  }

  /// What a double click on a tab does (keep a preview tab open).
  public func onTabDoubleClick(_ action: @escaping (ID) -> Void) -> Self {
    var strip = self
    strip.onDoubleClick = action
    return strip
  }

  @ViewBuilder public var body: some View {
    if tabs.count > 1 || onAdd != nil { strip }
  }

  private var strip: some View {
    let radius = ContMetrics.toolGroupRadius(idiom)
    return ViewThatFits(in: .horizontal) {
      row
      ScrollView(.horizontal, showsIndicators: false) { row }
    }
    .frame(height: ContMetrics.toolGroupHeight(idiom))
    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    .kitSurface(.card, cornerRadius: radius)
    .kitBar()
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding([.horizontal, .bottom], KitMetrics.gutter)
    .focusEffectDisabled()
    .modifier(CtlTabKeys(handler: keys.configured { moveFocus($0) }))
    .animation(.kit, value: selection)
  }

  private var row: some View {
    let actions = actions.configured(
      select: { id in withKitAnimation { selection = id } }, close: onClose, menu: menu,
      doubleClick: onDoubleClick, move: onMove)
    return HStack(spacing: idiom.size(4, touch: 6)) {
      ForEach(Array((tabs.count > 1 ? tabs : []).enumerated()), id: \.element.id) { index, tab in
        CtlTabView(
          tab: tab, isSelected: tab.id == selection, isFocused: focus == tab.id, namespace: namespace,
          actions: actions, closes: onClose != nil
        )
        .equatable()
        .focused($focus, equals: tab.id)
        .modifier(
          CtlTabExtras(id: tab.id, actions: actions, hasMenu: menu != nil, hasDoubleClick: onDoubleClick != nil))
        .modifier(
          CtlTabReorder(list: list, index: index, count: tabs.count, actions: actions, moves: onMove != nil, state: reorder))
      }
      if let onAdd {
        Button("New Tab", systemImage: "plus", action: onAdd)
          .labelStyle(.iconOnly)
          .buttonStyle(.kitIcon)
          .help("New Tab")
      }
    }
    .padding(.horizontal, idiom.size(2, touch: 4))
    .fixedSize(horizontal: true, vertical: false)
    .frame(maxHeight: .infinity)
  }

  private func moveFocus(_ direction: Int) -> KeyPress.Result {
    guard let current = focus, let index = tabs.firstIndex(where: { $0.id == current }),
      let next = CtlSegmentNavigation.next(from: index, by: direction, enabled: tabs.map { _ in true })
    else { return .ignored }
    focus = tabs[next].id
    return .handled
  }
}

/// ← → move focus between the tabs. The handler is a box the strip fills as it updates, so the modifier (and the key
/// handler it puts in the environment) stays the same as the selection changes: a new handler changed the environment
/// of every tab, and each tab's buttons updated on every tab switch.
private struct CtlTabKeys: ViewModifier {
  @MainActor final class Handler {
    var move: @MainActor (Int) -> KeyPress.Result = { _ in .ignored }

    func configured(_ move: @escaping @MainActor (Int) -> KeyPress.Result) -> Self {
      self.move = move
      return self
    }
  }

  let handler: Handler

  func body(content: Content) -> some View {
    content.onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
      handler.move(press.key == .leftArrow ? -1 : 1)
    }
  }
}

/// What the strip's tabs do, in a box the strip fills as it updates: the tabs and their modifiers hold the box, not
/// the closures, so their inputs stay the same when the strip updates (new closures made every tab, its menu and its
/// buttons update on every tab switch).
@MainActor final class CtlTabActions<ID: Hashable> {
  var select: (ID) -> Void = { _ in }
  var close: ((ID) -> Void)?
  var menu: ((ID) -> AnyView)?
  var doubleClick: ((ID) -> Void)?
  var move: ((IndexSet, Int) -> Void)?

  func configured(
    select: @escaping (ID) -> Void, close: ((ID) -> Void)?, menu: ((ID) -> AnyView)?,
    doubleClick: ((ID) -> Void)?, move: ((IndexSet, Int) -> Void)?
  ) -> Self {
    self.select = select
    self.close = close
    self.menu = menu
    self.doubleClick = doubleClick
    self.move = move
    return self
  }
}

/// A tab's context menu and double click, when the strip has them.
private struct CtlTabExtras<ID: Hashable>: ViewModifier {
  let id: ID
  let actions: CtlTabActions<ID>
  let hasMenu: Bool
  let hasDoubleClick: Bool

  func body(content: Content) -> some View {
    Group {
      if hasMenu {
        content.kitContextMenu { actions.menu?(id) }
      } else {
        content
      }
    }
    .simultaneousGesture(
      TapGesture(count: 2).onEnded { actions.doubleClick?(id) }, including: hasDoubleClick ? .all : .subviews)
  }
}

/// Dragging tabs to reorder them, when the strip takes `onMove`.
private struct CtlTabReorder<ID: Hashable>: ViewModifier {
  let list: UUID
  let index: Int
  let count: Int
  let actions: CtlTabActions<ID>
  let moves: Bool
  let state: ContReorderState

  func body(content: Content) -> some View {
    if moves {
      content.modifier(
        ContReorderRow(
          list: AnyHashable(list), index: index, move: { [actions] in actions.move?($0, $1) }, state: state,
          count: count, axis: .horizontal))
    } else {
      content
    }
  }
}

/// A tab: the selected one is the raised card; the close button (or the edited dot) sits in an 18pt slot at the end
/// that is always there, so tabs never change width as the close button shows under the pointer.
/// Equatable by what it draws (its actions are the strip's box), so a tab switch redraws only the two tabs it changes.
struct CtlTabView<ID: Hashable>: View, Equatable {
  nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
    MainActor.assumeIsolated {
      lhs.isSelected == rhs.isSelected && lhs.isFocused == rhs.isFocused && lhs.namespace == rhs.namespace
        && lhs.actions === rhs.actions && lhs.closes == rhs.closes && lhs.tab.drawsSame(as: rhs.tab)
    }
  }

  let tab: KitTab<ID>
  let isSelected: Bool
  let isFocused: Bool
  let namespace: Namespace.ID
  let actions: CtlTabActions<ID>
  /// The strip closes tabs (`actions.close`).
  let closes: Bool
  private var close: (() -> Void)? {
    guard closes else { return nil }
    return { [actions, id = tab.id] in actions.close?(id) }
  }
  @Environment(\.kitIdiom) private var idiom
  @State private var isHovered = false

  var body: some View {
    let radius: CGFloat = idiom.size(8, touch: 10)
    HStack(spacing: 6) {
      Button { actions.select(tab.id) } label: {
        HStack(spacing: 6) {
          if let icon = tab.icon {
            icon.frame(width: idiom.size(14, touch: 18), height: idiom.size(14, touch: 18))
          } else if let systemImage = tab.systemImage {
            Image(systemName: systemImage)
              .imageScale(.small)
              .foregroundStyle(tab.hue.map { AnyShapeStyle($0.fill) } ?? AnyShapeStyle(.foreground))
          }
          ZStack {
            // As wide as the semibold title, so a tab doesn't change width as it's selected.
            // Italic goes first: a weight set before it drops it.
            Text(tab.title).italic(tab.isPreview).fontWeight(.semibold).hidden()
            Text(tab.title).italic(tab.isPreview).fontWeight(isSelected ? .semibold : .regular)
          }
          .truncationMode(.tail)
        }
        .frame(maxHeight: .infinity)
      }
      .buttonStyle(CtlPressStyle())
      .accessibilityAddTraits(isSelected ? .isSelected : [])
      .accessibilityAction(named: "Close") { close?() }
      if close != nil || tab.isEdited {
        trailing
      }
    }
    .kitFont(.callout)
    .fontWeight(.regular)
    .lineLimit(1)
    .foregroundStyle(isSelected ? .kitLabel : .kitSecondary)
    .padding(
      EdgeInsets(
        top: 0,
        leading: idiom.size(10, touch: 12),
        bottom: 0,
        trailing: close != nil || tab.isEdited ? (idiom.size(5, touch: 6)) : (idiom.size(10, touch: 12))))
    .frame(maxWidth: idiom.size(200, touch: 240))
    .frame(height: idiom.size(28, touch: 36))
    .background {
      if isSelected {
        CtlRaisedCard(cornerRadius: radius).matchedGeometryEffect(id: "tab", in: namespace)
      }
    }
    .ctlStandaloneRing(isFocused, cornerRadius: radius)
    .contentShape(Rectangle())
    .kitHover { isHovered = $0 }
  }

  @ViewBuilder
  private var trailing: some View {
    let size: CGFloat = idiom.size(18, touch: 24)
    ZStack {
      if let close, isSelected || isHovered || !tab.isEdited {
        CtlTabCloseButton(title: tab.title, size: size, action: close)
          .opacity(isSelected || isHovered ? 1 : 0)
          .accessibilityHidden(!(isSelected || isHovered))
      } else if tab.isEdited {
        Circle().fill(.kitSecondary).frame(width: 7, height: 7)
          .accessibilityLabel("Edited")
      }
    }
    .frame(width: size, height: size)
  }
}

struct CtlTabCloseButton: View {
  let title: String
  let size: CGFloat
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: size * 0.5, weight: .semibold))
        .frame(width: size, height: size)
    }
    .buttonStyle(CtlPressStyle())
    .accessibilityLabel("Close \(title)")
    .help("Close")
  }
}

// MARK: - Path bar

/// One crumb of a `KitPathBar`: a title, an optional SF Symbol in a hue, and what clicking it does.
///
/// ```swift
/// KitPathItem("Sources", systemImage: "folder", hue: .blue) { reveal(sources) }
/// ```
public struct KitPathItem {
  public var title: String
  public var systemImage: String?
  public var hue: Hue?
  public var action: (() -> Void)?
  /// An icon view in place of the SF Symbol (a file's icon drawn as letters), about 14pt.
  public var icon: AnyView?

  public init(_ title: String, systemImage: String? = nil, hue: Hue? = nil, action: (() -> Void)? = nil) {
    self.title = title
    self.systemImage = systemImage
    self.hue = hue
    self.action = action
  }

  /// A crumb with any icon view.
  ///
  /// ```swift
  /// KitPathItem("TripStore.swift", icon: { FileIcon(file) }) { reveal(file) }
  /// ```
  public init<Icon: View>(_ title: String, @ViewBuilder icon: () -> Icon, action: (() -> Void)? = nil) {
    self.init(title, action: action)
    self.icon = AnyView(icon())
  }
}

/// A path bar (breadcrumbs): crumbs separated by small chevrons; the current (last) crumb is the label in semibold,
/// the others are quiet and take the field fill on hover. The last crumb keeps its width when space runs out.
///
/// ```swift
/// KitPathBar(["v57", "Git", "Shared", "Components.swift"])
/// KitPathBar(components: [
///   KitPathItem("Sources", systemImage: "folder", hue: .blue) { open(sources) },
///   KitPathItem("TripStore", systemImage: "swift", hue: .orange),
/// ])
/// ```
public struct KitPathBar: View {
  var components: [KitPathItem]
  @Environment(\.kitIdiom) private var idiom

  public init(components: [KitPathItem]) {
    self.components = components
  }

  /// A path bar of plain titles.
  public init(_ titles: [String]) {
    self.init(components: titles.map { KitPathItem($0) })
  }

  public var body: some View {
    HStack(spacing: 1) {
      ForEach(components.indices, id: \.self) { index in
        let isLast = index == components.count - 1
        CtlCrumb(item: components[index], isCurrent: isLast)
          .layoutPriority(isLast ? 1 : 0)
        if !isLast {
          Image(systemName: "chevron.right")
            .font(.system(size: idiom.size(8, touch: 10), weight: .semibold))
            .foregroundStyle(.kitTertiary)
            .frame(width: idiom.size(10, touch: 12))
            .accessibilityHidden(true)
        }
      }
    }
    .kitFont(.callout)
    .fontWeight(.regular)
    .lineLimit(1)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Path")
  }
}

struct CtlCrumb: View {
  let item: KitPathItem
  let isCurrent: Bool
  @Environment(\.kitIdiom) private var idiom
  @FocusState private var isFocused: Bool

  var body: some View {
    let radius: CGFloat = idiom.size(7, touch: 9)
    Button {
      item.action?()
    } label: {
      HStack(spacing: 4) {
        if let icon = item.icon {
          icon.frame(width: idiom.size(14, touch: 18), height: idiom.size(14, touch: 18))
        } else if let systemImage = item.systemImage {
          Image(systemName: systemImage)
            .imageScale(.small)
            .foregroundStyle(item.hue.map { AnyShapeStyle($0.fill) } ?? AnyShapeStyle(.foreground))
        }
        Text(item.title)
          .fontWeight(isCurrent ? .semibold : .regular)
          .truncationMode(.middle)
      }
      .foregroundStyle(isCurrent ? .kitLabel : .kitSecondary)
      .padding(.horizontal, idiom.size(6, touch: 8))
      .frame(height: idiom.size(24, touch: 32))
    }
    .buttonStyle(CtlPressStyle())
    .disabled(item.action == nil && !isCurrent)
    .focused($isFocused)
    .ctlStandaloneRing(isFocused, cornerRadius: radius)
    .accessibilityAddTraits(isCurrent ? .isSelected : [])
  }
}

#Preview("Tabs and path bar") {
  @Previewable @State var tab = 1
  VStack(spacing: 0) {
    KitTabStrip(
      tabs: [
        KitTab(id: 1, title: "TripStore", systemImage: "swift", hue: .orange),
        KitTab(id: 2, title: "Trip", systemImage: "swift", hue: .orange),
        KitTab(id: 3, title: "Package", systemImage: "doc", hue: .orange, isEdited: true),
      ], selection: $tab, onClose: { _ in }, onAdd: {})
    KitPathBar(components: [
      KitPathItem("Atlas", systemImage: "folder", hue: .red) {},
      KitPathItem("Sources", systemImage: "folder", hue: .blue) {},
      KitPathItem("TripStore", systemImage: "swift", hue: .orange),
    ])
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
  .frame(width: 480)
  .componentKit()
}
