import SwiftUI

// The kit's sidebar: Shell's `ScrollView` + `LazyVStack` sidebar (SidebarView2), made generic. A `LazyVStack` does
// none of what a `List` does for its rows, so the container publishes the selection, its focus and a namespace, and
// every row selects itself on tap, draws the selection card (which glides between rows) and reorders by dragging.

/// What a sidebar publishes to its rows.
struct ContSidebarSelection {
  var value: AnyHashable?
  var select: @MainActor (AnyHashable) -> Void
  /// The sidebar holds keyboard focus (or is on a touch idiom, where there is no other focus).
  var isFocused: Bool
  var namespace: Namespace.ID
}

/// A row's own state, for what draws inside it (the icon tile turns to the accent on the emphasized selection).
struct ContRowState: Hashable {
  var isSelected = false
  var isEmphasized = false
}

extension EnvironmentValues {
  @Entry var contSidebarSelection: ContSidebarSelection? = nil
  @Entry var contRowState = ContRowState()
  @Entry var contRowTag: AnyHashable? = nil
  @Entry var contRowIndent: Int = 0
  /// How dense the sidebar's rows are (`.kitRowDensity(_:)`).
  @Entry public var kitRowDensity: KitRowDensity = .regular
}

/// How dense sidebar rows are: the regular rows (32pt on the Mac, icons on tiles), or compact ones (24pt, bare icons)
/// for file trees like Code's navigator. Touch idioms keep their 44pt rows either way.
public enum KitRowDensity: Hashable, Sendable {
  case regular, compact
}

extension View {
  /// The value a `SidebarRow` (or any row that reads it) selects, when the row didn't get one in its initializer.
  ///
  /// ```swift
  /// SidebarRow(note.title, systemImage: "doc.text").kitTag(note.id)
  /// ```
  public func kitTag<Value: Hashable>(_ value: Value) -> some View {
    environment(\.contRowTag, AnyHashable(value))
  }

  /// Sets how dense the sidebar rows below are; a `.plain` section style is compact already.
  ///
  /// ```swift
  /// KitSection("Atlas", meta: "Swift package", systemImage: "folder") { tree }.kitRowDensity(.compact)
  /// ```
  public func kitRowDensity(_ density: KitRowDensity) -> some View {
    environment(\.kitRowDensity, density)
  }

  /// Indents the rows below by `level` steps (a tree: 14pt a step on the Mac, 20 on touch).
  public func kitRowIndent(_ level: Int) -> some View {
    environment(\.contRowIndent, level)
  }
}

// MARK: - KitSidebar

/// The sidebar: card sections on the sidebar ground, the selection as a raised card that glides between rows (with
/// the accent tile while the sidebar has keyboard focus, flat and gray otherwise, still in an inactive window), drag to
/// reorder, and the bottom bar: a square search button that opens into the search line, then the actions and the
/// sidebar toggle in one card. Rows read the selection from the environment.
///
/// ```swift
/// KitSidebar(selection: $selection, searchText: $search) {
///   KitSection("Notes", meta: "8 notes", systemImage: "doc.text") {
///     ReorderableSection(notes, move: move) { note in
///       SidebarRow(value: note.id, note.title, systemImage: "doc.text") { Count(note.count) }
///     }
///   }
/// } bottomBar: {
///   Button("New Note", systemImage: "square.and.pencil") { … }
/// }
/// ```
public struct KitSidebar<Content: View, BottomBar: View>: View {
  private let getSelection: () -> AnyHashable?
  private let setSelection: @MainActor (AnyHashable) -> Void
  private let searchText: Binding<String>?
  private let searchPrompt: String
  private let columnVisibility: Binding<NavigationSplitViewVisibility>?
  private let content: Content
  private let bottomBar: BottomBar
  @FocusState private var focused: Bool
  @Namespace private var namespace
  @State private var reorder = ContReorderState()
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitSectionStyle) private var style

  /// A sidebar whose rows select an optional value.
  ///
  /// - Parameters:
  ///   - searchText: shows the search button in the bottom bar; it opens into the search line bound to this text.
  ///   - columnVisibility: the split view's visibility, for the bar's sidebar toggle. On the Mac the toggle works
  ///     without it (through the window's split view); on iPad and iPhone it shows only when this is given.
  public init<Selection: Hashable & Sendable>(
    selection: Binding<Selection?>, searchText: Binding<String>? = nil, searchPrompt: String = "Search",
    columnVisibility: Binding<NavigationSplitViewVisibility>? = nil, @ViewBuilder content: () -> Content,
    @ViewBuilder bottomBar: () -> BottomBar
  ) {
    getSelection = { selection.wrappedValue.map(AnyHashable.init) }
    setSelection = { value in
      if let value = value.base as? Selection { selection.wrappedValue = value }
    }
    self.searchText = searchText
    self.searchPrompt = searchPrompt
    self.columnVisibility = columnVisibility
    self.content = content()
    self.bottomBar = bottomBar()
  }

  /// A sidebar whose rows select a value that is always set.
  @_disfavoredOverload
  public init<Selection: Hashable & Sendable>(
    selection: Binding<Selection>, searchText: Binding<String>? = nil, searchPrompt: String = "Search",
    columnVisibility: Binding<NavigationSplitViewVisibility>? = nil, @ViewBuilder content: () -> Content,
    @ViewBuilder bottomBar: () -> BottomBar
  ) {
    getSelection = { AnyHashable(selection.wrappedValue) }
    setSelection = { value in
      if let value = value.base as? Selection { selection.wrappedValue = value }
    }
    self.searchText = searchText
    self.searchPrompt = searchPrompt
    self.columnVisibility = columnVisibility
    self.content = content()
    self.bottomBar = bottomBar()
  }

  public var body: some View {
    let selection = getSelection()
    let inset = ContMetrics.sidebarInset(idiom)
    VStack(spacing: 0) {
      ContEdgeScroll {
        LazyVStack(alignment: .leading, spacing: style == .plain ? 8 : ContMetrics.sectionSpacing(idiom)) {
          content
        }
        .padding(.horizontal, inset)
        .padding(.top, 2)
        .padding(.bottom, inset)
      }
      .focusable()
      .focusEffectDisabled()
      .focused($focused)
      // A click on a row focuses the sidebar, like a click into a `List`.
      .simultaneousGesture(TapGesture().onEnded { focused = true })
      if showsBar {
        ContSidebarBar(
          searchText: searchText, prompt: searchPrompt, toggle: toggle, actions: { bottomBar })
      }
    }
    .background { Rectangle().fill(.kitSidebar).ignoresSafeArea() }
    .environment(
      \.contSidebarSelection,
      ContSidebarSelection(
        value: selection, select: setSelection, isFocused: focused || idiom.isTouch, namespace: namespace)
    )
    .environment(\.contReorderState, reorder)
    // The selection card glides to the newly selected row, and settles or goes flat as focus comes and goes.
    .animation(.kit, value: selection)
    .animation(.kit, value: focused)
  }

  private var showsBar: Bool {
    searchText != nil || BottomBar.self != EmptyView.self || toggle != nil
  }

  private var toggle: (@MainActor () -> Void)? {
    if let columnVisibility {
      return {
        withAnimation(.kitSlow) {
          columnVisibility.wrappedValue = columnVisibility.wrappedValue == .detailOnly ? .all : .detailOnly
        }
      }
    }
    guard ContPlatform.canToggleSidebar else { return nil }
    return { @MainActor in ContPlatform.toggleSidebar() }
  }
}

extension KitSidebar where BottomBar == EmptyView {
  /// A sidebar with no actions of its own in the bottom bar (the search button and the toggle still show).
  public init<Selection: Hashable & Sendable>(
    selection: Binding<Selection?>, searchText: Binding<String>? = nil, searchPrompt: String = "Search",
    columnVisibility: Binding<NavigationSplitViewVisibility>? = nil, @ViewBuilder content: () -> Content
  ) {
    self.init(
      selection: selection, searchText: searchText, searchPrompt: searchPrompt, columnVisibility: columnVisibility,
      content: content, bottomBar: { EmptyView() })
  }

  @_disfavoredOverload
  public init<Selection: Hashable & Sendable>(
    selection: Binding<Selection>, searchText: Binding<String>? = nil, searchPrompt: String = "Search",
    columnVisibility: Binding<NavigationSplitViewVisibility>? = nil, @ViewBuilder content: () -> Content
  ) {
    self.init(
      selection: selection, searchText: searchText, searchPrompt: searchPrompt, columnVisibility: columnVisibility,
      content: content, bottomBar: { EmptyView() })
  }
}

// MARK: - Bottom bar

/// The sidebar's bar at the bottom safe area: the square search button leads; the actions and the sidebar toggle share
/// one card at the end. While searching, the search line (the controls' `SidebarSearchButton`) takes the whole bar.
struct ContSidebarBar<Actions: View>: View {
  let searchText: Binding<String>?
  let prompt: String
  let toggle: (@MainActor () -> Void)?
  @ViewBuilder let actions: Actions
  @State private var isSearching = false
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    HStack(spacing: idiom.isTouch ? 10 : 8) {
      if let searchText {
        SidebarSearchButton(text: searchText, isSearching: $isSearching, prompt: prompt)
      }
      if !isSearching {
        Spacer(minLength: 0)
        if Actions.self != EmptyView.self || toggle != nil {
          ContBarCard {
            HStack(spacing: 2) {
              actions
              if let toggle {
                Button("Toggle Sidebar", systemImage: "sidebar.left") { toggle() }
              }
            }
          }
          .transition(.opacity)
        }
      }
    }
    .padding(.top, idiom == .phone ? 10 : idiom == .pad ? 8 : 6)
    .padding(.horizontal, idiom == .phone ? 20 : idiom == .pad ? 12 : 10)
    .padding(.bottom, idiom == .phone ? 10 : idiom == .pad ? 14 : 10)
  }
}

// MARK: - Rows

/// A sidebar row: the icon tile, the title (and a subtitle), a trailing accessory. Inside a `KitSidebar` it selects
/// itself on tap and wears the selection card while its value is the sidebar's selection; rows are 32pt on the Mac and
/// 44 on iPad and iPhone (24 in a plain sidebar).
///
/// ```swift
/// SidebarRow(value: repo.id, repo.name, subtitle: repo.branch, systemImage: "shippingbox") {
///   Count(repo.changes, .attention)
/// }
/// ```
///
/// Renaming in place: `.kitRename(isRenaming:text:onCommit:)` turns the title into a field.
public struct SidebarRow<Icon: View, Trailing: View>: View {
  let value: AnyHashable?
  let title: String
  let subtitle: String?
  let icon: Icon
  let trailing: Trailing
  @Environment(\.contSidebarSelection) private var selection
  @Environment(\.contRowTag) private var tag
  @Environment(\.contRowIndent) private var indent
  @Environment(\.contRename) private var rename
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitWindowIsActive) private var isActive
  @Environment(\.kitSectionStyle) private var style
  @Environment(\.kitRowDensity) private var density
  @State private var isHovered = false

  init(
    value: AnyHashable?, title: String, subtitle: String?, @ViewBuilder icon: () -> Icon,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.value = value
    self.title = title
    self.subtitle = subtitle
    self.icon = icon()
    self.trailing = trailing()
  }

  /// A row that selects `value`, with any icon and trailing views.
  public init<Value: Hashable>(
    value: Value, _ title: String, subtitle: String? = nil, @ViewBuilder icon: () -> Icon,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.init(value: AnyHashable(value), title: title, subtitle: subtitle, icon: icon, trailing: trailing)
  }

  /// A row with any icon and trailing views; it selects the value given by `.kitTag(_:)`.
  public init(
    _ title: String, subtitle: String? = nil, @ViewBuilder icon: () -> Icon, @ViewBuilder trailing: () -> Trailing
  ) {
    self.init(value: nil, title: title, subtitle: subtitle, icon: icon, trailing: trailing)
  }

  private var rowValue: AnyHashable? { value ?? tag }
  private var compact: Bool { (style == .plain || density == .compact) && !idiom.isTouch }

  public var body: some View {
    // A row is not left selected on iPhone (it pushes its screen).
    let isSelected = rowValue != nil && selection?.value == rowValue && idiom != .phone
    let isEmphasized = isSelected && (selection?.isFocused ?? false) && isActive
    let isRenaming = rename?.isRenaming.wrappedValue ?? false
    HStack(spacing: compact ? 6 : idiom.isTouch ? 12 : 8) {
      icon
      VStack(alignment: .leading, spacing: compact ? 0 : 1) {
        if isRenaming, let rename {
          ContRenameField(title: title, rename: rename)
        } else {
          Text(title)
            .kitFont(.body)
            .fontWeight(isSelected ? .medium : .regular)
            .foregroundStyle(!isActive && !isSelected ? AnyShapeStyle(.kitSecondary) : AnyShapeStyle(.kitLabel))
            .lineLimit(1)
        }
        if let subtitle {
          Text(subtitle)
            .kitFont(.caption)
            .font(compact ? .system(size: 10) : nil)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      trailing
        .kitFont(.caption)
        .monospacedDigit()
    }
    .environment(\.contRowState, ContRowState(isSelected: isSelected, isEmphasized: isEmphasized))
    .padding(.vertical, compact ? 1 : idiom == .phone ? 6 : 4)
    .padding(.leading, (idiom.isTouch ? 10 : 6) + CGFloat(indent) * (idiom.isTouch ? 20 : 14))
    .padding(.trailing, idiom.isTouch ? 10 : 6)
    .frame(minHeight: compact ? 24 : KitMetrics.row(idiom))
    .background { background(isSelected: isSelected, isEmphasized: isEmphasized, isRenaming: isRenaming) }
    .contentShape(Rectangle())
    .onHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
    .onTapGesture {
      guard let rowValue, !isRenaming else { return }
      selection?.select(rowValue)
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction {
      if let rowValue { selection?.select(rowValue) }
    }
  }

  @ViewBuilder
  private func background(isSelected: Bool, isEmphasized: Bool, isRenaming: Bool) -> some View {
    let radius = ContMetrics.rowRadius(idiom, compact: compact)
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    ZStack {
      if isRenaming {
        shape.fill(Hue.accent.soft())
      } else if isHovered, !isSelected, !idiom.isTouch {
        shape.fill(KitColor.rowHover).transition(.opacity)
      }
      if isSelected {
        Group {
          if isEmphasized {
            SurfaceShape(surface: .raised, cornerRadius: radius)
          } else {
            shape.fill(KitColor.raised).opacity(0.6)
          }
        }
        .modifier(ContSelectionGlide(namespace: selection?.namespace))
      }
    }
  }
}

/// Ties the selection card to the sidebar's namespace, so the one card moves between rows instead of blinking.
private struct ContSelectionGlide: ViewModifier {
  let namespace: Namespace.ID?

  func body(content: Content) -> some View {
    if let namespace {
      content.matchedGeometryEffect(id: "kit.sidebar.selection", in: namespace)
    } else {
      content
    }
  }
}

extension SidebarRow where Icon == RowTile {
  /// A row that selects `value`, with an SF Symbol tile (gray, the accent on the selected row, or `hue`).
  public init<Value: Hashable>(
    value: Value, _ title: String, subtitle: String? = nil, systemImage: String, hue: Hue? = nil,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.init(value: value, title, subtitle: subtitle, icon: { RowTile(systemImage: systemImage, hue: hue) }, trailing: trailing)
  }

  /// A row with an SF Symbol tile; it selects the value given by `.kitTag(_:)`.
  public init(
    _ title: String, subtitle: String? = nil, systemImage: String, hue: Hue? = nil,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.init(title, subtitle: subtitle, icon: { RowTile(systemImage: systemImage, hue: hue) }, trailing: trailing)
  }
}

extension SidebarRow where Icon == RowTile, Trailing == EmptyView {
  /// A row that selects `value`, with an SF Symbol tile.
  ///
  /// ```swift
  /// SidebarRow(value: Page.history, "History", systemImage: "clock")
  /// ```
  public init<Value: Hashable>(
    value: Value, _ title: String, subtitle: String? = nil, systemImage: String, hue: Hue? = nil
  ) {
    self.init(value: value, title, subtitle: subtitle, systemImage: systemImage, hue: hue) { EmptyView() }
  }

  /// A row with an SF Symbol tile; it selects the value given by `.kitTag(_:)`.
  public init(_ title: String, subtitle: String? = nil, systemImage: String, hue: Hue? = nil) {
    self.init(title, subtitle: subtitle, systemImage: systemImage, hue: hue) { EmptyView() }
  }
}

extension SidebarRow where Trailing == EmptyView {
  /// A row that selects `value`, with any icon (`Tile(letters:)`, an avatar…).
  public init<Value: Hashable>(
    value: Value, _ title: String, subtitle: String? = nil, @ViewBuilder icon: () -> Icon
  ) {
    self.init(value: value, title, subtitle: subtitle, icon: icon) { EmptyView() }
  }

  /// A row with any icon; it selects the value given by `.kitTag(_:)`.
  public init(_ title: String, subtitle: String? = nil, @ViewBuilder icon: () -> Icon) {
    self.init(title, subtitle: subtitle, icon: icon) { EmptyView() }
  }
}

// MARK: - Row tile

/// A row's icon on a rounded tile, like a repository's: gray, the accent on the selected row while the sidebar has
/// focus, or its own hue; a white glyph on a soft top light. 18pt on the Mac, 28 on iPad, 30 on iPhone. In a plain
/// sidebar it is the bare glyph.
///
/// ```swift
/// SidebarRow(value: id, "atlas", icon: { RowTile(systemImage: "shippingbox", hue: .blue) })
/// ```
public struct RowTile: View {
  var systemImage: String
  var hue: Hue?
  @Environment(\.contRowState) private var row
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitSectionStyle) private var style
  @Environment(\.kitRowDensity) private var density

  public init(systemImage: String, hue: Hue? = nil) {
    self.systemImage = systemImage
    self.hue = hue
  }

  private var tint: Hue { hue ?? (row.isEmphasized ? .accent : .gray) }

  public var body: some View {
    if (style == .plain || density == .compact) && !idiom.isTouch {
      Image(systemName: systemImage)
        .font(.system(size: 13))
        .foregroundStyle(hue == nil && !row.isEmphasized ? AnyShapeStyle(.kitSecondary) : AnyShapeStyle(tint.fill))
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    } else {
      let size = ContMetrics.rowTile(idiom)
      let shape = RoundedRectangle(cornerRadius: size * (idiom == .mac ? 0.28 : 0.27), style: .continuous)
      Image(systemName: systemImage)
        .font(.system(size: ContMetrics.rowGlyph(idiom), weight: .medium))
        .imageScale(.small)
        .foregroundStyle(Color.white)
        .frame(width: size, height: size)
        .background {
          shape.fill(tint.fill)
            .overlay { shape.fill(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom)) }
        }
        .animation(.kit, value: row.isEmphasized)
        .accessibilityHidden(true)
    }
  }
}

#Preview("Sidebar") {
  @Previewable @State var selection: String? = "History"
  @Previewable @State var search = ""
  @Previewable @State var repos = ["atlas", "beacon", "harbor", "pebble"]
  KitSidebar(selection: $selection, searchText: $search) {
    KitSection("Repositories", meta: ["5 repositories", "2 with changes"], systemImage: "folder", hue: .indigo) {
      ReorderableSection(repos, id: \.self, move: { repos.move(fromOffsets: $0, toOffset: $1) }) { repo in
        SidebarRow(value: repo, repo, icon: { Tile(letters: repo.prefix(1).uppercased(), hue: StableHue.pick(repo), size: 18) })
      }
    } accessory: {
      Button("Add Repository", systemImage: "plus") {}
    }
    KitSection("atlas", meta: ["main", "4 changed"], systemImage: "arrow.triangle.branch", hue: .red) {
      SidebarRow(value: "Changes", "Changes", systemImage: "pencil") { Text("4") }
      SidebarRow(value: "History", "History", systemImage: "clock")
      SidebarRow(value: "Stashes", "Stashes", systemImage: "tray")
    }
  } bottomBar: {
    Button("Add", systemImage: "plus") {}
  }
  .frame(width: 260, height: 520)
  .componentKit()
}
