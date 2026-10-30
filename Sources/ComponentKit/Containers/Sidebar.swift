import SwiftUI

// The kit's sidebar: Shell's `ScrollView` + `LazyVStack` sidebar (SidebarView2), made generic, on a `KitLazyStack`.
// A stack does none of what a `List` does for its rows, so the container publishes the selection, its focus and a
// namespace, and every row selects itself on tap, draws the selection card (which glides between rows) and reorders
// by dragging.

/// What a sidebar publishes to its rows.
struct ContSidebarSelection {
  var value: AnyHashable?
  var select: @MainActor (AnyHashable) -> Void
  /// The sidebar holds keyboard focus (or is on a touch idiom, where there is no other focus).
  var isFocused: Bool
  var namespace: Namespace.ID
  /// The container's double-click (and Return) action on a row's value.
  var primaryAction: (@MainActor (AnyHashable) -> Void)? = nil
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
/// reorder, and the bottom bar: a square search button that opens into the search line, then the actions and (on
/// iPad and iPhone) the sidebar toggle in one card. On the Mac the toggle sits at the sidebar's top right, in the
/// title bar. Rows read the selection from the environment.
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
  private let isSearching: Binding<Bool>?
  private let columnVisibility: Binding<NavigationSplitViewVisibility>?
  private let content: Content
  private let bottomBar: BottomBar
  private var statusView: AnyView?
  private var returnAction: (@MainActor () -> Void)?
  private var primary: (@MainActor (AnyHashable) -> Void)?
  @FocusState private var focused: Bool
  @Namespace private var namespace
  @State private var reorder = ContReorderState()
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitAppearsActive) private var appearsActive
  @Environment(\.kitSectionStyle) private var style
  @Environment(\.contThreeColumns) private var threeColumns
  #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
  #endif

  /// A sidebar whose rows select an optional value.
  ///
  /// - Parameters:
  ///   - searchText: shows the search button in the bottom bar; it opens into the search line bound to this text.
  ///   - isSearching: whether the search line is open, to open it from code (⌘F) or know when it closes.
  ///   - columnVisibility: the split view's visibility, for the bar's sidebar toggle. On the Mac the toggle works
  ///     without it (through the window's split view); on iPad and iPhone it shows only when this is given.
  public init<Selection: Hashable & Sendable>(
    selection: Binding<Selection?>, searchText: Binding<String>? = nil, searchPrompt: String = "Search",
    isSearching: Binding<Bool>? = nil, columnVisibility: Binding<NavigationSplitViewVisibility>? = nil,
    @ViewBuilder content: () -> Content, @ViewBuilder bottomBar: () -> BottomBar
  ) {
    getSelection = { selection.wrappedValue.map(AnyHashable.init) }
    setSelection = { value in
      if let value = value.base as? Selection { selection.wrappedValue = value }
    }
    self.searchText = searchText
    self.searchPrompt = searchPrompt
    self.isSearching = isSearching
    self.columnVisibility = columnVisibility
    self.content = content()
    self.bottomBar = bottomBar()
  }

  /// A sidebar whose rows select a value that is always set.
  @_disfavoredOverload
  public init<Selection: Hashable & Sendable>(
    selection: Binding<Selection>, searchText: Binding<String>? = nil, searchPrompt: String = "Search",
    isSearching: Binding<Bool>? = nil, columnVisibility: Binding<NavigationSplitViewVisibility>? = nil,
    @ViewBuilder content: () -> Content, @ViewBuilder bottomBar: () -> BottomBar
  ) {
    getSelection = { AnyHashable(selection.wrappedValue) }
    setSelection = { value in
      if let value = value.base as? Selection { selection.wrappedValue = value }
    }
    self.searchText = searchText
    self.searchPrompt = searchPrompt
    self.isSearching = isSearching
    self.columnVisibility = columnVisibility
    self.content = content()
    self.bottomBar = bottomBar()
  }

  public var body: some View {
    ScrollViewReader { proxy in sidebar(proxy) }
  }

  private func sidebar(_ proxy: ScrollViewProxy) -> some View {
    let selection = getSelection()
    let inset = ContMetrics.sidebarInset(idiom)
    let spacing = style == .plain ? 8 : ContMetrics.sectionSpacing(idiom)
    // The rows run on under the title bar and the bottom bar (both safe area), so the system's scroll edge
    // blurs them there; the bar's cards carry their own shadows over the rows, and a fade of the sidebar's ground
    // softens both edges.
    return ScrollView {
      // The sections' rows are lazy stacks of their own, so a card nearing the screen comes a few rows at a time.
      KitLazyStack(alignment: .leading, spacing: spacing) {
        content
      }
      // Sticky sections (`.kitSticky`) report their places in the stack's space.
      .contStickyStack()
      .padding(.horizontal, inset)
      // The ends' gaps are padding, not safe area, so the bars' fades end at the bars.
      .padding(EdgeInsets(top: 2, leading: 0, bottom: inset, trailing: 0))
    }
    // Stuck sections stack under the title bar and over the bottom bar; a stuck title scrolls to its section.
    // The bottom bar keeps its own gap above its cards.
    .contStickyHost(spacing: spacing, topGap: 2, bottomGap: showsBar ? 0 : inset) { id in
      proxy.scrollTo(ContStickyScrollID(value: id), anchor: .top)
    }
    .focusable()
    .focusEffectDisabled()
    .focused($focused)
    .modifier(
      ContRowKeyboard(
        current: selection, select: setSelection, onReturn: returnAction, onPrimary: primary,
        scroll: { value, anchor in proxy.scrollTo(ContRowScrollID(value: value), anchor: anchor) }))
    // A click on a row focuses the sidebar, like a click into a `List`.
    .simultaneousGesture(TapGesture().onEnded { focused = true })
    // No system scroll edge under the title bar; the bottom bar as an inset.
    .contEdgeEffectHidden(.top)
    .contEdgeBar(.bottom) {
      if showsBar {
        ContSidebarBar(
          searchText: searchText, prompt: searchPrompt, isSearching: isSearching, toggle: barToggle,
          status: statusView, actions: { bottomBar })
          .environment(\.contBarGround, KitColor.sidebar)
          .background { ContEdgeFade(edge: .bottom, ground: .kitSidebar) }
      }
    }
    // Under the title bar (the traffic lights) or the status bar. The inset is read where it's drawn: an
    // `onGeometryChange` into state missed the last of a quick 52 → 0 → 52 at launch in Shell's window and kept 0,
    // which dropped the fade and put the hide button under the title bar.
    .overlay(alignment: .top) {
      GeometryReader { geometry in
        let top = geometry.safeAreaInsets.top
        // The reader starts under the inset, so the fade sits above it, the inset's height. `ContEdgeFade` here,
        // `top` high, also reached into the inset: it ran from the window's top to twice the inset, over the rows.
        Rectangle()
          .fill(ContGroundFade(ground: .kitSidebar, edge: .top))
          .frame(height: top)
          .offset(y: -top)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
        #if os(macOS)
          // The Mac's hide button sits at the sidebar's top right, centered on the traffic lights, as the system's
          // does. A sidebar with no title bar over it (one shown inside a page) has nowhere to put it: drawn
          // there, it sat half above the sidebar's top edge.
          if let toggle, top >= ContMetrics.toolbarHeight(.mac) / 2 {
            ToolGroup(iconOnly: true) {
              Button("Hide Sidebar", systemImage: "sidebar.left") { toggle() }
            }
            .help("Hide Sidebar")
            .environment(\.contBarGround, KitColor.sidebar)
            .frame(height: top)
            .padding(.trailing, inset)
            .frame(width: geometry.size.width, alignment: .trailing)
            .offset(y: -top)
          }
        #endif
      }
    }
    .background { Rectangle().fill(.kitSidebar).ignoresSafeArea() }
    #if os(macOS)
      // With its background, the system toolbar (an app's own items over the page) took every click in its row over
      // the sidebar: the hide button answered only below it, under the icon.
      .modifier(ContToolbarBackgroundHidden())
    #endif
    // iPadOS 26 would float the column as a glass card inside the screen's edges.
    .contFlushSidebarColumn()
    // Its own floor on the Mac: a split view's column minimum gives way under a full toolbar. Not on iPad, where
    // the split view fixes the column's width (about 200pt in a three-column portrait, an app's own 220pt):
    // held wider than the column, the cards ran past both of its edges, with no gutter at the screen's edge.
    .frame(minWidth: idiom.isTouch ? nil : KitMetrics.sidebarMinWidth(idiom))
    .environment(
      \.contSidebarSelection,
      ContSidebarSelection(
        value: selection, select: setSelection, isFocused: focused || idiom.isTouch || appearsActive, namespace: namespace,
        primaryAction: primary)
    )
    .environment(\.contReorderState, reorder)
    // The selection card glides to the newly selected row, and settles or goes flat as focus comes and goes.
    .animation(.kit, value: selection)
    .animation(.kit, value: focused)
  }

  private var showsBar: Bool {
    searchText != nil || BottomBar.self != EmptyView.self || barToggle != nil || statusView != nil
  }

  /// The bottom bar's sidebar toggle: on iPad and iPhone; the Mac's sits at the top right. A compact split (an
  /// iPhone, a narrow iPad window) stacks its columns, so there is no sidebar beside the page to hide.
  private var barToggle: (@MainActor () -> Void)? {
    #if os(macOS)
      nil
    #else
      sizeClass == .compact ? nil : toggle
    #endif
  }

  /// Puts a status at the start of the bottom bar, after the search button: where the items live ("On This Mac",
  /// "iCloud"), a sync's live icon, a count. It gives way to the search line while searching.
  ///
  /// ```swift
  /// KitSidebar(selection: $note, searchText: $search) { … }
  ///   .status { Label("On This Mac", systemImage: "laptopcomputer") }
  /// ```
  public func status<Status: View>(@ViewBuilder _ content: () -> Status) -> Self {
    var sidebar = self
    sidebar.statusView = AnyView(content())
    return sidebar
  }

  /// What Return does on the selected row while the sidebar has keyboard focus (open it, start renaming). Without it
  /// Return opens or closes a tree row. Arrow keys always move the selection: ↑↓ through the rows, ← closes a row or
  /// goes to its parent, → opens it or goes to its first child. A row with `.action` runs it on Return.
  ///
  /// ```swift
  /// KitSidebar(selection: $file) { … }.onReturn { open(file) }
  /// ```
  public func onReturn(_ action: @escaping @MainActor () -> Void) -> Self {
    var sidebar = self
    sidebar.returnAction = action
    return sidebar
  }

  /// What a double click on a row does with its value (open a file, connect to a host); Return runs it too on the
  /// selected row while the sidebar has keyboard focus, unless `onReturn` is set. Rows with their own `.action` or
  /// `.onDoubleClick` keep theirs. A single click still selects at once.
  ///
  /// ```swift
  /// KitSidebar(selection: $file) { … }.primaryAction { (url: URL) in open(url) }
  /// ```
  public func primaryAction<Value: Hashable>(_ action: @escaping @MainActor (Value) -> Void) -> Self {
    var sidebar = self
    sidebar.primary = { value in
      if let value = value.base as? Value { action(value) }
    }
    return sidebar
  }

  private var toggle: (@MainActor () -> Void)? {
    if let columnVisibility {
      let threeColumns = threeColumns
      return {
        withAnimation(.kitSlow) {
          columnVisibility.wrappedValue = ContSplitVisibility.toggled(
            columnVisibility.wrappedValue, threeColumns: threeColumns)
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
    isSearching: Binding<Bool>? = nil, columnVisibility: Binding<NavigationSplitViewVisibility>? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      selection: selection, searchText: searchText, searchPrompt: searchPrompt, isSearching: isSearching,
      columnVisibility: columnVisibility, content: content, bottomBar: { EmptyView() })
  }

  @_disfavoredOverload
  public init<Selection: Hashable & Sendable>(
    selection: Binding<Selection>, searchText: Binding<String>? = nil, searchPrompt: String = "Search",
    isSearching: Binding<Bool>? = nil, columnVisibility: Binding<NavigationSplitViewVisibility>? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      selection: selection, searchText: searchText, searchPrompt: searchPrompt, isSearching: isSearching,
      columnVisibility: columnVisibility, content: content, bottomBar: { EmptyView() })
  }
}

// MARK: - Showing a hidden sidebar

extension EnvironmentValues {
  @Entry var contThreeColumns = false
}

extension View {
  /// Brings back a sidebar the kit's toggle hid: while the sidebar is hidden, a "Show Sidebar" button leads the
  /// toolbar (the kit's own bar under a `kitToolbar`, the system toolbar otherwise; the kit draws the button in both). Put it on the detail column (the content column in a three-column split), with the same visibility
  /// binding the `KitSidebar` got (on iPad and iPhone the bar's toggle hides it, and the split view's own toggle may
  /// be removed). On iPad it also shows at `.automatic` while the split keeps the sidebar out of the way (portrait,
  /// or always in a three-column split).
  ///
  /// ```swift
  /// NavigationSplitView(columnVisibility: $columns) {
  ///   KitSidebar(selection: $page, columnVisibility: $columns) { … }
  ///     .toolbar(removing: .sidebarToggle)
  /// } detail: {
  ///   Detail().kitSidebarToggle(columnVisibility: $columns)
  /// }
  /// ```
  public func kitSidebarToggle(columnVisibility: Binding<NavigationSplitViewVisibility>) -> some View {
    modifier(ContShowSidebar(columnVisibility: columnVisibility))
  }

  /// Says the split view below has three columns (sidebar, content, detail): the kit's sidebar toggle then hides the
  /// sidebar alone (`.doubleColumn`) instead of the content column with it (`.detailOnly`), and `kitSidebarToggle`
  /// shows its button whenever the sidebar is out. Put it on the `NavigationSplitView`.
  ///
  /// ```swift
  /// NavigationSplitView(columnVisibility: $columns) {
  ///   KitSidebar(selection: $folder, columnVisibility: $columns) { … }
  /// } content: {
  ///   NoteList().kitSidebarToggle(columnVisibility: $columns)
  /// } detail: {
  ///   Editor()
  /// }
  /// .kitThreeColumnSplit()
  /// ```
  public func kitThreeColumnSplit(_ isOn: Bool = true) -> some View {
    environment(\.contThreeColumns, isOn)
  }
}

/// What the sidebar toggles do with a split view's visibility, apart from views.
enum ContSplitVisibility {
  /// Whether the sidebar is out of sight at `visibility`. `.automatic` hides it in a three-column split and, on
  /// touch, in portrait.
  static func sidebarIsHidden(
    _ visibility: NavigationSplitViewVisibility, threeColumns: Bool, isTouch: Bool, isPortrait: Bool
  ) -> Bool {
    if isAutomatic(visibility) { return isTouch && (threeColumns || isPortrait) }
    switch visibility {
    case .detailOnly: return true
    case .doubleColumn: return threeColumns
    default: return false
    }
  }

  /// Whether `visibility` is `.automatic`. It compares equal to the visibility it stands for (`.automatic ==
  /// .doubleColumn`), so its own flag is read.
  static func isAutomatic(_ visibility: NavigationSplitViewVisibility) -> Bool {
    Mirror(reflecting: visibility).children.first { $0.label == "isAutomatic" }?.value as? Bool ?? false
  }

  /// Shows the hidden sidebar. On the Mac through the window's split view, as the sidebar's own hide button does:
  /// once AppKit has collapsed the sidebar, setting the binding back to `.all` doesn't bring it back.
  @MainActor
  static func showSidebar(_ columnVisibility: Binding<NavigationSplitViewVisibility>) {
    if ContPlatform.canToggleSidebar {
      ContPlatform.toggleSidebar()
    } else {
      withAnimation(.kitSlow) { columnVisibility.wrappedValue = .all }
    }
  }

  /// The bar's toggle: hide the sidebar (the sidebar alone in a three-column split), or show every column.
  static func toggled(_ visibility: NavigationSplitViewVisibility, threeColumns: Bool) -> NavigationSplitViewVisibility {
    let automatic = isAutomatic(visibility)
    if threeColumns {
      return !automatic && (visibility == .detailOnly || visibility == .doubleColumn) ? .all : .doubleColumn
    }
    return !automatic && visibility == .detailOnly ? .all : .detailOnly
  }
}

private struct ContShowSidebar: ViewModifier {
  @Binding var columnVisibility: NavigationSplitViewVisibility
  @State private var isPortrait = false
  @State private var hasKitToolbar = false
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.contThreeColumns) private var threeColumns
  #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
  #endif

  func body(content: Content) -> some View {
    // A compact split stacks its columns: the back button leads to the sidebar there.
    #if os(macOS)
      let isStacked = false
    #else
      let isStacked = sizeClass == .compact
    #endif
    let isHidden = !isStacked && ContSplitVisibility.sidebarIsHidden(
      columnVisibility, threeColumns: threeColumns, isTouch: idiom.isTouch, isPortrait: isPortrait)
    content
      // A kit toolbar below takes the button into its own bar.
      .environment(\.contShowSidebar, isHidden ? ContShowSidebarAction(action: showSidebar) : nil)
      // On iPhone and iPad the kit toolbar hides the navigation bar, so the system item never shows there.
      #if os(macOS)
        .onPreferenceChange(ContKitToolbarKey.self) { hasKitToolbar = $0 }
      #endif
      .background {
        if idiom.isTouch {
          // The column's own shape stands in for the orientation: full height and narrower than tall in portrait.
          GeometryReader { proxy in
            Color.clear
              .onAppear { isPortrait = proxy.size.height > proxy.size.width }
              .onChange(of: proxy.size) { _, size in isPortrait = size.height > size.width }
          }
        }
      }
      .toolbar {
        ContShowSidebarItem(columnVisibility: $columnVisibility, isHidden: isHidden && !hasKitToolbar)
      }
  }

  private func showSidebar() {
    ContSplitVisibility.showSidebar($columnVisibility)
  }
}

private struct ContShowSidebarItem: ToolbarContent {
  @Binding var columnVisibility: NavigationSplitViewVisibility
  let isHidden: Bool

  // The kit's own button, without the system's glass: a plain `ToolbarItem` button was the glass circle on iPad.
  var body: some ToolbarContent {
    KitToolbarItem(placement: .navigation) {
      if isHidden {
        ContShowSidebarButton(action: ContShowSidebarAction { ContSplitVisibility.showSidebar($columnVisibility) })
      }
    }
  }
}

// MARK: - Bottom bar

/// The sidebar's bar, a bottom safe-area inset the rows scroll on under: the square search button leads; the actions and the sidebar toggle share
/// one card at the end. While searching, the search line (the controls' `SidebarSearchButton`) takes the whole bar.
struct ContSidebarBar<Actions: View>: View {
  let searchText: Binding<String>?
  let prompt: String
  var isSearching: Binding<Bool>? = nil
  let toggle: (@MainActor () -> Void)?
  var status: AnyView? = nil
  /// Buttons show their titles (a pushed screen's bar: "Copy Password"); a button's own `.labelStyle(.iconOnly)` wins.
  var labeled = false
  @ViewBuilder let actions: Actions
  @State private var ownSearching = false
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    let searching = isSearching ?? $ownSearching
    HStack(spacing: idiom.size(8, touch: 10)) {
      if let searchText {
        SidebarSearchButton(text: searchText, isSearching: searching, prompt: prompt)
      }
      if !searching.wrappedValue {
        if let status {
          // A card of its own, as the search and the actions have: rows scrolling on under the bar would otherwise
          // read through the text.
          status
            .kitFont(.caption)
            .lineLimit(1)
            .padding(.horizontal, idiom.size(9, touch: 12))
            .frame(minHeight: ContMetrics.barHeight(idiom))
            .kitSurface(.card, cornerRadius: ContMetrics.barRadius(idiom))
            .layoutPriority(-1)
            .transition(.opacity)
        }
        Spacer(minLength: 0)
        if Actions.self != EmptyView.self || toggle != nil {
          ContBarCard(labeled: labeled) {
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
    // On the Mac the card sits 10pt from the bar's top and the window's bottom, as from the sidebar's edge (52pt, the
    // title bar's height).
    .padding(
      EdgeInsets(
        top: idiom.size(10, pad: 8, phone: 10),
        leading: idiom.size(10, pad: 12, phone: 20),
        bottom: idiom.size(10, pad: 14, phone: 10),
        trailing: idiom.size(10, pad: 12, phone: 20)))
  }
}

// MARK: - Rows

/// A sidebar row: the icon tile, the title (and a subtitle), a trailing accessory. Inside a `KitSidebar` or `KitList`
/// it selects itself on tap and wears the selection card while its value is the selection; rows are 32pt on the Mac
/// and 44 on iPad and iPhone (24 in a plain sidebar).
///
/// ```swift
/// SidebarRow(value: repo.id, repo.name, subtitle: repo.branch, systemImage: "shippingbox") {
///   Count(repo.changes, .attention)
/// }
/// ```
///
/// More, as initializer parameters or chained on the row:
/// - `progress:` (and `secondaryProgress:`) draws a `KitProgressBar` under the title (a download, a sync); a row
///   with a `status:` draws it in the state's hue (gray while paused), as `.progress(_:secondary:status:)` does.
/// - `isExpanded:` leads with a disclosure chevron for a tree row (`KitOutline` sets it, and the indent, for you);
///   `.disclosureSlot()` keeps its empty slot on a leaf beside such rows.
/// - `.title(_:)` swaps the title for any `Text` (an attributed match, coloured runs); renaming still edits the string.
/// - `.subtitle { … }` puts any view in the subtitle's place (a styled terminal line, a date and a preview).
/// - `.titleAccessory { … }` sets a chip or a dot right after the title.
///
/// ```swift
/// SidebarRow(value: file.id, file.name, systemImage: "doc", progress: file.progress) { ProgressRow(value: file.progress) }
/// SidebarRow(value: folder.id, folder.name, systemImage: "folder", isExpanded: $open)
/// SidebarRow(value: note.id, note.title, systemImage: "doc.text")
///   .title(Text(match.attributed))
///   .subtitle { Text(note.date, style: .date) + Text("  ") + Text(note.preview).foregroundStyle(.kitTertiary) }
///   .titleAccessory { Chip("Draft", hue: .orange) }
/// ```
///
/// Renaming in place: `.kitRename(isRenaming:text:onCommit:)` turns the title into a field.
public struct SidebarRow<Icon: View, Trailing: View>: View {
  let value: AnyHashable?
  let title: String
  let subtitle: String?
  let icon: Icon
  let trailing: Trailing
  var titleText: Text?
  var subtitleView: AnyView?
  var accessoryView: AnyView?
  var progress: Double?
  var secondaryProgress: Double?
  /// The work the bar shows: its hue is the state's (gray paused, green done, red failed).
  var progressStatus = WorkStatus.idle
  var isExpanded: Binding<Bool>?
  var reservesDisclosure = false
  var isCurrent = false
  var action: (@MainActor () -> Void)?
  var doubleClick: (@MainActor () -> Void)?
  @Environment(\.contSidebarSelection) private var selection
  @Environment(\.contRowTag) private var tag
  @Environment(\.contRowIndent) private var indent
  @Environment(\.contRowDisclosure) private var outlineDisclosure
  @Environment(\.contRename) private var rename
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitWindowIsActive) private var isActive
  @Environment(\.kitSectionStyle) private var style
  @Environment(\.kitRowDensity) private var density
  @State private var isHovered = false

  init(
    value: AnyHashable?, title: String, subtitle: String?, progress: Double? = nil, secondaryProgress: Double? = nil,
    isExpanded: Binding<Bool>? = nil, @ViewBuilder icon: () -> Icon, @ViewBuilder trailing: () -> Trailing
  ) {
    self.value = value
    self.title = title
    self.subtitle = subtitle
    self.progress = progress
    self.secondaryProgress = secondaryProgress
    self.isExpanded = isExpanded
    self.icon = icon()
    self.trailing = trailing()
  }

  /// A row that selects `value`, with any icon and trailing views.
  public init<Value: Hashable>(
    value: Value, _ title: String, subtitle: String? = nil, progress: Double? = nil,
    secondaryProgress: Double? = nil, isExpanded: Binding<Bool>? = nil, @ViewBuilder icon: () -> Icon,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.init(
      value: AnyHashable(value), title: title, subtitle: subtitle, progress: progress,
      secondaryProgress: secondaryProgress, isExpanded: isExpanded, icon: icon, trailing: trailing)
  }

  /// A row with any icon and trailing views; it selects the value given by `.kitTag(_:)`.
  public init(
    _ title: String, subtitle: String? = nil, progress: Double? = nil, secondaryProgress: Double? = nil,
    isExpanded: Binding<Bool>? = nil, @ViewBuilder icon: () -> Icon, @ViewBuilder trailing: () -> Trailing
  ) {
    self.init(
      value: nil, title: title, subtitle: subtitle, progress: progress, secondaryProgress: secondaryProgress,
      isExpanded: isExpanded, icon: icon, trailing: trailing)
  }

  // MARK: Chained options

  /// Draws `text` as the title instead of the plain string: an attributed match, coloured runs, a monospaced name.
  /// The row keeps its weight and colour unless the text sets its own; renaming still edits the plain title.
  ///
  /// ```swift
  /// SidebarRow(value: file.id, file.name, systemImage: "doc").title(Text(file.highlightedName))
  /// ```
  public func title(_ text: Text) -> Self {
    var row = self
    row.titleText = text
    return row
  }

  /// Puts any view where the subtitle goes, under the title. It starts in the caption style (quiet, one line); give
  /// its texts their own colours (a terminal line, a date beside a preview).
  ///
  /// ```swift
  /// SidebarRow(value: session.id, session.name, systemImage: "terminal")
  ///   .subtitle { Text("✓ ").foregroundStyle(Hue.green.text) + Text(session.lastLine).monospaced() }
  /// ```
  public func subtitle<Subtitle: View>(@ViewBuilder _ content: () -> Subtitle) -> Self {
    var row = self
    row.subtitleView = AnyView(content())
    return row
  }

  /// Sets a small view right after the title: a chip ("Draft", "Production"), a dot, a lock.
  ///
  /// ```swift
  /// SidebarRow(value: db.id, db.name, systemImage: "cylinder").titleAccessory { Chip.production }
  /// ```
  public func titleAccessory<Accessory: View>(@ViewBuilder _ content: () -> Accessory) -> Self {
    var row = self
    row.accessoryView = AnyView(content())
    return row
  }

  /// Draws a progress bar under the title (`nil` removes it); `secondary` sits softly behind it. `status` gives the
  /// bar the state's hue: gray while paused, green done, red failed.
  ///
  /// ```swift
  /// SidebarRow(value: torrent.id, torrent.name, systemImage: "arrow.down").progress(torrent.done, secondary: torrent.available)
  /// SidebarRow(value: item.id, item.title).progress(item.progress, status: item.isPaused ? .paused() : .working)
  /// ```
  public func progress(_ value: Double?, secondary: Double? = nil, status: WorkStatus? = nil) -> Self {
    var row = self
    row.progress = value
    row.secondaryProgress = secondary
    if let status { row.progressStatus = status }
    return row
  }

  /// Leads the row with a disclosure chevron bound to `isExpanded` (a folder in a tree).
  public func disclosure(isExpanded: Binding<Bool>?) -> Self {
    var row = self
    row.isExpanded = isExpanded
    return row
  }

  /// Keeps the disclosure chevron's slot empty on a leaf row, so it lines up with the rows beside it that open (a
  /// table under a schema next to a view that doesn't). `KitOutline` does it for its own leaves.
  ///
  /// ```swift
  /// SidebarRow(value: table.id, table.name, systemImage: "tablecells").disclosureSlot()
  /// ```
  public func disclosureSlot(_ reserves: Bool = true) -> Self {
    var row = self
    row.reservesDisclosure = reserves
    return row
  }

  /// Marks the row as the current one: a second, weaker mark than the selection (a flat card), for a sidebar that
  /// holds two (the open repository while a screen of it is selected).
  ///
  /// ```swift
  /// SidebarRow(value: repo.id, repo.name, systemImage: "shippingbox").isCurrent(repo.id == openRepository)
  /// ```
  public func isCurrent(_ isCurrent: Bool = true) -> Self {
    var row = self
    row.isCurrent = isCurrent
    return row
  }

  /// Runs `action` on a tap (or Return) instead of selecting the row: "Add Repository…", "Show All".
  ///
  /// ```swift
  /// SidebarRow("Add Connection…", systemImage: "plus").action { showsNewConnection = true }
  /// ```
  public func action(_ action: @escaping @MainActor () -> Void) -> Self {
    var row = self
    row.action = action
    return row
  }

  /// Runs `action` on a double click (a double tap on touch), after the first click selected the row: open the
  /// file, connect, rename. It wins over the container's `primaryAction`.
  ///
  /// ```swift
  /// SidebarRow(value: file.id, file.name, systemImage: "doc").onDoubleClick { open(file) }
  /// ```
  public func onDoubleClick(_ action: @escaping @MainActor () -> Void) -> Self {
    var row = self
    row.doubleClick = action
    return row
  }

  /// The double click's action: the row's own, or the container's primary action on the row's value.
  private var doubleClickAction: (@MainActor () -> Void)? {
    if let doubleClick { return doubleClick }
    guard action == nil, let rowValue, let primary = selection?.primaryAction else { return nil }
    return { primary(rowValue) }
  }

  private var rowValue: AnyHashable? { value ?? tag }
  private var compact: Bool { (style == .plain || density == .compact) && !idiom.isTouch }
  /// The row's own disclosure, or the one its `KitOutline` node gives it.
  private var disclosure: ContRowDisclosure? {
    if let isExpanded { return ContRowDisclosure(isExpanded: isExpanded) }
    if reservesDisclosure { return ContRowDisclosure(isExpanded: nil) }
    return outlineDisclosure
  }

  public var body: some View {
    // A row is not left selected on iPhone (it pushes its screen).
    let isSelected = rowValue != nil && selection?.value == rowValue && idiom != .phone
    let isEmphasized = isSelected && (selection?.isFocused ?? false) && isActive
    let isRenaming = rename?.isRenaming.wrappedValue ?? false
    let disclosure = disclosure
    HStack(spacing: compact ? 6 : idiom.size(8, touch: 12)) {
      if let disclosure {
        ContDisclosureButton(disclosure: disclosure, title: title)
      }
      icon
      VStack(alignment: .leading, spacing: compact ? 0 : 1) {
        if isRenaming, let rename {
          ContRenameField(title: title, rename: rename)
        } else {
          HStack(spacing: 6) {
            (titleText ?? Text(title))
              .kitFont(.body)
              .fontWeight(isSelected ? .medium : .regular)
              .foregroundStyle(!isActive && !isSelected ? AnyShapeStyle(.kitSecondary) : AnyShapeStyle(.kitLabel))
              .lineLimit(1)
              // As the selection glides, the old and new rows' titles cross-fade between weights: interpolated, they
              // were drawn on the CPU every frame of the glide (a dropped frame or two after each selection).
              .contentTransition(.opacity)
            if let accessoryView {
              accessoryView
                .kitFont(.caption)
                .fixedSize()
            }
          }
        }
        if let subtitleView {
          subtitleView
            .kitFont(.caption)
            .font(compact ? .system(size: 10) : nil)
            .lineLimit(1)
        } else if let subtitle {
          Text(subtitle)
            .kitFont(.caption)
            .font(compact ? .system(size: 10) : nil)
            .lineLimit(1)
        }
        if let progress {
          KitProgressBar(value: progress, secondary: secondaryProgress, hue: progressStatus.hue ?? .accent)
            .padding(EdgeInsets(top: compact ? 2 : 4, leading: 0, bottom: compact ? 1 : 2, trailing: 0))
            .transition(.opacity)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      trailing
        .kitFont(.caption)
        .monospacedDigit()
    }
    .environment(\.contRowState, ContRowState(isSelected: isSelected, isEmphasized: isEmphasized))
    .padding(
      EdgeInsets(
        top: compact ? 1 : idiom == .phone ? 6 : 4,
        leading: idiom.size(6, touch: 10) + CGFloat(indent) * ContMetrics.rowIndent(idiom)
          - (disclosure != nil ? 4 : 0),
        bottom: compact ? 1 : idiom == .phone ? 6 : 4,
        trailing: idiom.size(6, touch: 10)))
    .frame(minHeight: compact ? 24 : KitMetrics.row(idiom))
    .background { background(isSelected: isSelected, isEmphasized: isEmphasized, isRenaming: isRenaming) }
    .contentShape(Rectangle())
    .kitHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
    .animation(.kit, value: progress == nil)
    .onTapGesture {
      guard !isRenaming else { return }
      if let action {
        action()
      } else if let rowValue {
        selection?.select(rowValue)
      }
    }
    // Alongside the single tap, so selecting doesn't wait for a second click.
    .simultaneousGesture(
      TapGesture(count: 2).onEnded {
        guard !isRenaming else { return }
        doubleClickAction?()
      }, including: doubleClickAction == nil ? .subviews : .all
    )
    .preference(
      key: ContRowNavKey.self,
      value: rowValue.map { [ContRowNavItem(value: $0, indent: indent, disclosure: disclosure, action: action)] } ?? [])
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction {
      if let action {
        action()
      } else if let rowValue {
        selection?.select(rowValue)
      }
    }
    .modifier(ContDisclosureAccessibility(disclosure: disclosure))
    // What the arrow keys scroll to as they move the selection.
    .id(ContRowScrollID(value: rowValue))
  }

  @ViewBuilder
  private func background(isSelected: Bool, isEmphasized: Bool, isRenaming: Bool) -> some View {
    let radius = ContMetrics.rowRadius(idiom, compact: compact)
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    ZStack {
      if isRenaming {
        shape.fill(Hue.accent.soft())
      } else if isCurrent, !isSelected {
        SurfaceShape(surface: .raised, cornerRadius: radius).opacity(isActive ? 1 : 0.6)
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
    status: WorkStatus = .idle, progress: Double? = nil, secondaryProgress: Double? = nil,
    isExpanded: Binding<Bool>? = nil, @ViewBuilder trailing: () -> Trailing
  ) {
    self.init(
      value: value, title, subtitle: subtitle, progress: progress, secondaryProgress: secondaryProgress,
      isExpanded: isExpanded, icon: { RowTile(systemImage: systemImage, hue: hue, status: status) },
      trailing: trailing)
    progressStatus = status
  }

  /// A row with an SF Symbol tile; it selects the value given by `.kitTag(_:)`.
  public init(
    _ title: String, subtitle: String? = nil, systemImage: String, hue: Hue? = nil, status: WorkStatus = .idle,
    progress: Double? = nil, secondaryProgress: Double? = nil, isExpanded: Binding<Bool>? = nil,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.init(
      title, subtitle: subtitle, progress: progress, secondaryProgress: secondaryProgress, isExpanded: isExpanded,
      icon: { RowTile(systemImage: systemImage, hue: hue, status: status) }, trailing: trailing)
    progressStatus = status
  }
}

extension SidebarRow where Icon == RowTile, Trailing == EmptyView {
  /// A row that selects `value`, with an SF Symbol tile.
  ///
  /// ```swift
  /// SidebarRow(value: Page.history, "History", systemImage: "clock")
  /// ```
  public init<Value: Hashable>(
    value: Value, _ title: String, subtitle: String? = nil, systemImage: String, hue: Hue? = nil,
    status: WorkStatus = .idle, progress: Double? = nil, secondaryProgress: Double? = nil,
    isExpanded: Binding<Bool>? = nil
  ) {
    self.init(
      value: value, title, subtitle: subtitle, systemImage: systemImage, hue: hue, status: status,
      progress: progress, secondaryProgress: secondaryProgress, isExpanded: isExpanded
    ) { EmptyView() }
  }

  /// A row with an SF Symbol tile; it selects the value given by `.kitTag(_:)`.
  public init(
    _ title: String, subtitle: String? = nil, systemImage: String, hue: Hue? = nil, status: WorkStatus = .idle,
    progress: Double? = nil, secondaryProgress: Double? = nil, isExpanded: Binding<Bool>? = nil
  ) {
    self.init(
      title, subtitle: subtitle, systemImage: systemImage, hue: hue, status: status, progress: progress,
      secondaryProgress: secondaryProgress, isExpanded: isExpanded
    ) { EmptyView() }
  }
}

extension SidebarRow where Icon == RowTile {
  /// A row that selects `value`, with a tile around any glyph (a drawn `BranchGlyph`, an image) and trailing views.
  ///
  /// ```swift
  /// SidebarRow(value: branch.id, branch.name, hue: .green, glyph: { BranchGlyph() }) { Count(branch.ahead) }
  /// ```
  @_disfavoredOverload
  public init<Value: Hashable, Glyph: View>(
    value: Value, _ title: String, subtitle: String? = nil, hue: Hue? = nil, status: WorkStatus = .idle,
    progress: Double? = nil, secondaryProgress: Double? = nil, isExpanded: Binding<Bool>? = nil,
    @ViewBuilder glyph: () -> Glyph, @ViewBuilder trailing: () -> Trailing
  ) {
    let tile = RowTile(hue: hue, status: status, glyph: glyph)
    self.init(
      value: value, title, subtitle: subtitle, progress: progress, secondaryProgress: secondaryProgress,
      isExpanded: isExpanded, icon: { tile }, trailing: trailing)
    progressStatus = status
  }

  /// A row with a tile around any glyph and trailing views; it selects the value given by `.kitTag(_:)`.
  @_disfavoredOverload
  public init<Glyph: View>(
    _ title: String, subtitle: String? = nil, hue: Hue? = nil, status: WorkStatus = .idle, progress: Double? = nil,
    secondaryProgress: Double? = nil, isExpanded: Binding<Bool>? = nil, @ViewBuilder glyph: () -> Glyph,
    @ViewBuilder trailing: () -> Trailing
  ) {
    let tile = RowTile(hue: hue, status: status, glyph: glyph)
    self.init(
      title, subtitle: subtitle, progress: progress, secondaryProgress: secondaryProgress, isExpanded: isExpanded,
      icon: { tile }, trailing: trailing)
    progressStatus = status
  }
}

extension SidebarRow where Icon == RowTile, Trailing == EmptyView {
  /// A row that selects `value`, with a tile around any glyph.
  ///
  /// ```swift
  /// SidebarRow(value: branch.id, branch.name, glyph: { BranchGlyph() })
  /// ```
  @_disfavoredOverload
  public init<Value: Hashable, Glyph: View>(
    value: Value, _ title: String, subtitle: String? = nil, hue: Hue? = nil, status: WorkStatus = .idle,
    progress: Double? = nil, secondaryProgress: Double? = nil, isExpanded: Binding<Bool>? = nil,
    @ViewBuilder glyph: () -> Glyph
  ) {
    self.init(
      value: value, title, subtitle: subtitle, hue: hue, status: status, progress: progress,
      secondaryProgress: secondaryProgress, isExpanded: isExpanded, glyph: glyph
    ) { EmptyView() }
  }

  /// A row with a tile around any glyph; it selects the value given by `.kitTag(_:)`.
  @_disfavoredOverload
  public init<Glyph: View>(
    _ title: String, subtitle: String? = nil, hue: Hue? = nil, status: WorkStatus = .idle, progress: Double? = nil,
    secondaryProgress: Double? = nil, isExpanded: Binding<Bool>? = nil, @ViewBuilder glyph: () -> Glyph
  ) {
    self.init(
      title, subtitle: subtitle, hue: hue, status: status, progress: progress, secondaryProgress: secondaryProgress,
      isExpanded: isExpanded, glyph: glyph
    ) { EmptyView() }
  }
}

extension SidebarRow where Trailing == EmptyView {
  /// A row that selects `value`, with any icon (`Tile(letters:)`, an avatar…).
  public init<Value: Hashable>(
    value: Value, _ title: String, subtitle: String? = nil, progress: Double? = nil,
    secondaryProgress: Double? = nil, isExpanded: Binding<Bool>? = nil, @ViewBuilder icon: () -> Icon
  ) {
    self.init(
      value: value, title, subtitle: subtitle, progress: progress, secondaryProgress: secondaryProgress,
      isExpanded: isExpanded, icon: icon
    ) { EmptyView() }
  }

  /// A row with any icon; it selects the value given by `.kitTag(_:)`.
  public init(
    _ title: String, subtitle: String? = nil, progress: Double? = nil, secondaryProgress: Double? = nil,
    isExpanded: Binding<Bool>? = nil, @ViewBuilder icon: () -> Icon
  ) {
    self.init(
      title, subtitle: subtitle, progress: progress, secondaryProgress: secondaryProgress, isExpanded: isExpanded,
      icon: icon
    ) { EmptyView() }
  }
}

// MARK: - Row tile

/// A row's icon on a rounded tile, like a repository's: gray, the accent on the selected row while the sidebar has
/// focus, or its own hue; a white glyph on a soft top light. 18pt on the Mac, 28 on iPad, 30 on iPhone
/// (`KitMetrics.rowTile(_:)`). In a plain sidebar it is the bare glyph. With a `status` other than idle it is the live
/// icon at the same size, carrying the work.
///
/// ```swift
/// SidebarRow(value: id, "atlas", icon: { RowTile(systemImage: "shippingbox", hue: .blue) })
/// SidebarRow(value: id, "Sync", icon: { RowTile(systemImage: "arrow.triangle.2.circlepath", status: .working) })
/// SidebarRow(value: branch.id, branch.name, icon: { RowTile { BranchGlyph() } })
/// ```
public struct RowTile: View {
  var systemImage: String
  var glyph: AnyView?
  var hue: Hue?
  var status: WorkStatus
  @Environment(\.contRowState) private var row
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitSectionStyle) private var style
  @Environment(\.kitRowDensity) private var density

  public init(systemImage: String, hue: Hue? = nil, status: WorkStatus = .idle) {
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
  }

  /// A tile with any glyph instead of an SF Symbol: a drawn one (`BranchGlyph`), an image. The glyph is drawn in the
  /// tile's foreground style (white on the tile, the hue when bare) and can size itself from `kitGlyphSize`.
  ///
  /// ```swift
  /// RowTile(hue: .green) { BranchGlyph() }
  /// RowTile { Image("postgres").resizable().scaledToFit() }
  /// ```
  public init<Glyph: View>(hue: Hue? = nil, status: WorkStatus = .idle, @ViewBuilder glyph: () -> Glyph) {
    self.systemImage = ""
    self.glyph = AnyView(glyph())
    self.hue = hue
    self.status = status
  }

  private var tint: Hue { hue ?? (row.isEmphasized ? .accent : .gray) }
  private var compact: Bool { (style == .plain || density == .compact) && !idiom.isTouch }

  @ViewBuilder
  private var symbol: some View {
    if let glyph {
      glyph
    } else {
      Image(systemName: systemImage)
    }
  }

  public var body: some View {
    if status != .idle {
      LiveIcon(hue: hue ?? .accent, status: status, size: compact ? 16 : KitMetrics.rowTile(idiom)) { symbol }
    } else if compact {
      symbol
        .font(.system(size: 13))
        .foregroundStyle(hue == nil && !row.isEmphasized ? AnyShapeStyle(.kitSecondary) : AnyShapeStyle(tint.fill))
        .environment(\.kitGlyphSize, 14)
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    } else {
      let size = KitMetrics.rowTile(idiom)
      let shape = RoundedRectangle(cornerRadius: size * (idiom == .mac ? 0.28 : 0.27), style: .continuous)
      symbol
        .font(.system(size: ContMetrics.rowGlyph(idiom), weight: .medium))
        .imageScale(.small)
        .foregroundStyle(Color.white)
        .environment(\.kitGlyphSize, (size * 0.72).rounded())
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
