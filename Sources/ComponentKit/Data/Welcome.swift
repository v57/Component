import SwiftUI

/// Which list the welcome shows.
public enum WelcomeSource: String, Hashable, Sendable, CaseIterable {
  case recent = "Recent"
  case projects = "Projects"
}

/// The welcome every app shows as its main screen's empty state: drawn as the detail pane's content while nothing
/// is selected (on iPhone, the root's first screen while there is nothing to list). The app's icon, name and
/// version, its actions, then the recent items on a card (or Recent | Projects when the app passes projects), filling
/// the pane and centred: one column, or two side by side in a wide pane. A folder dropped anywhere on it goes to
/// `onDrop`. ↑↓ move through the items once the list has focus and Return opens the selected one; on the Mac a click
/// selects and a double click opens, on iPad and iPhone a tap opens. Name, version and icon default to the app
/// bundle's.
///
/// ```swift
/// NavigationSplitView {
///   Sidebar(selection: $selection)
/// } detail: {
///   if let selection {
///     ProjectView(selection)
///   } else {
///     KitWelcome(onDrop: { library.open($0) }) {
///       WelcomeAction("Clone Repository…", detail: "From GitHub, GitLab or any URL", systemImage: "arrow.down") { … }
///       WelcomeAction("Open Local Repository…", detail: "Any folder with a .git directory", systemImage: "folder") { … }
///     } recents: {
///       ForEach(recent) { repo in
///         RecentItem(repo.name, subtitle: repo.path, date: "Today", status: "1 change", statusHue: .orange) { open(repo) }
///       }
///     }
///   }
/// }
/// ```
public struct KitWelcome<Actions: View, Recents: View, Projects: View>: View {
  var appName: String
  var version: String
  var icon: Image?
  var emptyTitle: String
  var emptyMessage: String
  var onDrop: (([URL]) -> Bool)?
  var actions: Actions
  var recents: Recents
  var projects: Projects
  var sourceBinding: Binding<WelcomeSource>?
  var searchText: Binding<String>?
  var searchPrompt: String
  var optionsView: AnyView?
  var listTitle = "Recent"
  var emptyIcon: (systemImage: String, status: WorkStatus)?
  @State private var identityHeight: CGFloat = 320
  @State private var ownSource = WelcomeSource.recent
  @State private var nav = DataNavModel()
  @State private var isDropTargeted = false
  @FocusState private var isListFocused: Bool
  @Environment(\.dataRendersFlat) private var flat
  @Environment(\.kitIdiom) private var idiom

  /// The welcome with Recent | Projects, as the main screen's empty state.
  ///
  /// - Parameters:
  ///   - source: which list shows, to remember it (`@AppStorage`); without it the welcome keeps its own.
  ///   - searchText: shows a search field over the lists, bound to this text (filter `recents` and `projects`
  ///     with it).
  public init(
    appName: String? = nil, version: String? = nil, icon: Image? = nil,
    emptyTitle: String = "No Recent Items", emptyMessage: String = "What you open appears here.",
    source: Binding<WelcomeSource>? = nil, searchText: Binding<String>? = nil, searchPrompt: String = "Search",
    onDrop: (([URL]) -> Bool)? = nil, @ViewBuilder actions: () -> Actions,
    @ViewBuilder recents: () -> Recents, @ViewBuilder projects: () -> Projects
  ) {
    self.sourceBinding = source
    self.searchText = searchText
    self.searchPrompt = searchPrompt
    self.appName = appName ?? DataPlatform.appName
    self.version = version ?? "Version \(DataPlatform.version)"
    self.icon = icon
    self.emptyTitle = emptyTitle
    self.emptyMessage = emptyMessage
    self.onDrop = onDrop
    self.actions = actions()
    self.recents = recents()
    self.projects = projects()
  }

  private var hasProjects: Bool { Projects.self != EmptyView.self }
  private var source: WelcomeSource { sourceBinding?.wrappedValue ?? ownSource }
  private var sourceSelection: Binding<WelcomeSource> { sourceBinding ?? $ownSource }

  /// Puts more options under the list: checkboxes, a pop-up ("Open at launch: …").
  ///
  /// ```swift
  /// KitWelcome { … } recents: { … }
  ///   .options { Toggle("Reopen last project", isOn: $reopen).toggleStyle(.kitCheckbox) }
  /// ```
  public func options<Options: View>(@ViewBuilder _ content: () -> Options) -> Self {
    var welcome = self
    welcome.optionsView = AnyView(content())
    return welcome
  }

  /// Names the list when it isn't recent items ("Already in your vault": what other apps saved).
  ///
  /// ```swift
  /// KitWelcome { … } recents: { … }.listTitle("Already in your vault")
  /// ```
  public func listTitle(_ title: String) -> Self {
    var welcome = self
    welcome.listTitle = title
    return welcome
  }

  /// Puts a live icon over the empty list's title, for a list that waits on work ("Waiting for Your Keys" while
  /// a new device's keys arrive).
  ///
  /// ```swift
  /// KitWelcome(emptyTitle: "Waiting for Your Keys", …) { … } recents: { … }
  ///   .emptyState(systemImage: "key", status: .working)
  /// ```
  public func emptyState(systemImage: String, status: WorkStatus) -> Self {
    var welcome = self
    welcome.emptyIcon = (systemImage, status)
    return welcome
  }

  public var body: some View {
    inline
    .overlay { if isDropTargeted { DropRing(title: "Open in \(appName)") } }
    .modifier(WelcomeDrop(onDrop: onDrop, isTargeted: $isDropTargeted))
    .environment(nav)
    .onPreferenceChange(DataNavItemsKey.self) { ids in
      // Nothing is selected until the list takes focus.
      MainActor.assumeIsolated { nav.update(ids: ids, selectsFirst: false) }
    }
    .animation(.kit, value: isDropTargeted)
  }

  /// The main screen's empty state: on the pane's own ground, the identity and actions over the list's card in one
  /// column (520pt at most), or beside it when the pane is wide; centred, the list as tall as the pane allows (at
  /// least 260pt: a shorter pane scrolls).
  private var inline: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let isWide = WelcomeLayout.isWide(width: size.width, idiom: idiom)
      let margin: CGFloat = idiom == .phone ? KitMetrics.gutter : 24
      let available = size.height - margin * 2
      ScrollView {
        Group {
          if isWide {
            HStack(alignment: .center, spacing: 32) {
              identity.frame(width: 340)
              listCard
                .frame(maxWidth: 500)
                .frame(height: WelcomeLayout.wideListHeight(available: available))
            }
            .frame(maxWidth: 880)
          } else {
            VStack(spacing: 0) {
              identity.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { identityHeight = $0 }
              listCard.frame(
                height: WelcomeLayout.columnListHeight(
                  available: available, identity: identityHeight, fills: idiom == .phone))
            }
            .frame(maxWidth: idiom == .phone ? .infinity : 520)
          }
        }
        .padding(margin)
        .frame(width: size.width)
        .frame(minHeight: size.height)
      }
      .scrollBounceBehavior(.basedOnSize)
      .scrollIndicators(.automatic)
    }
  }

  private var identity: some View {
    VStack(spacing: 0) {
      Group {
        if let icon {
          icon.resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
        } else if let icon = DataPlatform.appIcon {
          // The Mac's app icon keeps Apple's grid margin (its artwork is 824 of 1024 points, with the system's own
          // shadow around it): drawn larger, so the artwork is the 64pt the window wants.
          let size = DataPlatform.appIconArtwork < 1 ? 64 / DataPlatform.appIconArtwork : 64
          #if os(macOS)
            icon.resizable().interpolation(.high).aspectRatio(contentMode: .fit)
              .frame(width: size, height: size)
          #else
            // iOS keeps its icons square; the system masks them, so the welcome does too.
            icon.resizable().interpolation(.high).aspectRatio(contentMode: .fit)
              .frame(width: size, height: size)
              .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
              .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
          #endif
        } else {
          Tile(letters: String(appName.prefix(1)), hue: .accent, size: 64, style: .solid)
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
        }
      }
      .frame(width: 64, height: 64)
      .accessibilityHidden(true)
      Text(appName)
        .kitFont(.largeTitle)
        .padding(.top, 12)
      Text(version)
        .kitFont(.callout)
        .foregroundStyle(.kitSecondary)
        .padding(.top, 2)
      VStack(spacing: 2) { actions }
        .padding(.top, 18)
    }
    .padding(EdgeInsets(top: idiom == .phone ? 16 : 0, leading: 0, bottom: 18, trailing: 0))
    .frame(maxWidth: .infinity)
  }

  /// The pane's list: a card on the pane's ground.
  private var listCard: some View {
    listContent
      .padding(EdgeInsets(top: 10, leading: KitMetrics.gutter, bottom: 12, trailing: KitMetrics.gutter))
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .kitSurface(.card, cornerRadius: idiom.isTouch ? KitMetrics.radiusXL : KitMetrics.radiusOverlay)
  }

  private var listContent: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: KitMetrics.gutter) {
        if hasProjects {
          KitSegmented(selection: sourceSelection, options: WelcomeSource.allCases.map { ($0.rawValue, $0) })
            .fixedSize()
        } else {
          Text(listTitle).kitFont(.headline).padding(.leading, 6)
        }
        if let searchText {
          Spacer(minLength: 0)
          KitSearchField(text: searchText, prompt: searchPrompt)
            .frame(maxWidth: 200)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
      .padding(.horizontal, 8)
      items
      if let optionsView {
        VStack(alignment: .leading, spacing: 6) { optionsView }
          .toggleStyle(.kitCheckbox)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(EdgeInsets(top: 4, leading: 8, bottom: 0, trailing: 8))
      }
    }
  }

  private var items: some View {
    let rows = VStack(spacing: 2) {
      switch source {
      case .recent: recents
      case .projects: projects
      }
    }
    return Group {
      if flat {
        rows
      } else {
        ScrollViewReader { proxy in
          // The rows fade out at the bottom while more run on under the options (`.ck-scroll-edge`).
          ContEdgeScroll { rows }
            .scrollIndicators(.never)
            .onChange(of: nav.selected) { _, id in if let id { proxy.scrollTo(id) } }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .overlay {
      if nav.ids.isEmpty {
        VStack(spacing: 4) {
          if let emptyIcon {
            LiveIcon(systemImage: emptyIcon.systemImage, status: emptyIcon.status, size: 56).padding(.bottom, 8)
          }
          Text(emptyTitle).kitFont(.headline)
          Text(onDrop == nil ? emptyMessage : "\(emptyMessage) Or drop a folder here.")
            .kitFont(.callout)
            .foregroundStyle(.kitSecondary)
            .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 120)
      }
    }
    .focusable()
    .focused($isListFocused)
    .focusEffectDisabled()
    .onKeyPress(keys: [.upArrow, .downArrow, .return]) { press in
      if press.key == .return { nav.activate() } else { nav.move(by: press.key == .upArrow ? -1 : 1) }
      return .handled
    }
    .onChange(of: source) { nav.selected = nil }
  }
}

extension KitWelcome where Projects == EmptyView {
  /// The welcome with one list, the recent items, as the main screen's empty state; `searchText` adds a search
  /// field over it.
  public init(
    appName: String? = nil, version: String? = nil, icon: Image? = nil,
    emptyTitle: String = "No Recent Items", emptyMessage: String = "What you open appears here.",
    searchText: Binding<String>? = nil, searchPrompt: String = "Search",
    onDrop: (([URL]) -> Bool)? = nil, @ViewBuilder actions: () -> Actions, @ViewBuilder recents: () -> Recents
  ) {
    self.init(
      appName: appName, version: version, icon: icon, emptyTitle: emptyTitle, emptyMessage: emptyMessage,
      searchText: searchText, searchPrompt: searchPrompt, onDrop: onDrop, actions: actions, recents: recents,
      projects: { EmptyView() })
  }
}

/// The inline welcome's layout: two columns from 800pt (not on iPhone); the list as tall as the pane allows, from
/// 260pt (a shorter pane scrolls) to 560pt beside the identity or 440pt under it (no limit on iPhone, where it fills
/// the screen).
enum WelcomeLayout {
  static let twoColumnWidth: CGFloat = 800
  static let minListHeight: CGFloat = 260

  static func isWide(width: CGFloat, idiom: KitIdiom) -> Bool {
    idiom != .phone && width >= twoColumnWidth
  }

  static func wideListHeight(available: CGFloat) -> CGFloat {
    min(max(available, minListHeight), 560)
  }

  static func columnListHeight(available: CGFloat, identity: CGFloat, fills: Bool) -> CGFloat {
    let room = max(available - identity, minListHeight)
    return fills ? room : min(room, 440)
  }
}

/// Folders dropped on the welcome.
private struct WelcomeDrop: ViewModifier {
  let onDrop: (([URL]) -> Bool)?
  @Binding var isTargeted: Bool

  func body(content: Content) -> some View {
    if let onDrop {
      content.dropDestination(for: URL.self) { urls, _ in
        onDrop(urls.filter(\.isFileURL))
      } isTargeted: { isTargeted = $0 }
    } else {
      content
    }
  }
}

/// A window that takes a drop: its content ringed 8pt in from the edges, with a card naming what happens.
private struct DropRing: View {
  let title: String

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)
        .fill(Hue.accent.soft(0.06))
        .strokeBorder(Hue.accent.fill, lineWidth: 2)
        .padding(KitMetrics.gutter)
      Label(title, systemImage: "arrow.down.to.line")
        .labelStyle(KitButtonLabelStyle(iconOnly: false))
        .kitFont(.headline)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background { SurfaceShape(surface: .floating, cornerRadius: KitMetrics.radiusCard) }
    }
    .allowsHitTesting(false)
    .transition(.opacity)
  }
}

// MARK: - Actions and items

/// One of the welcome's actions: an accent glyph on a soft tile, the title and a line of help.
///
/// ```swift
/// WelcomeAction("New Note", detail: "Start writing", systemImage: "square.and.pencil") { newNote() }
///   .keyboardShortcut("n")
/// ```
public struct WelcomeAction: View {
  var title: String
  var detail: String?
  var systemImage: String
  var action: () -> Void
  @State private var isHovered = false

  public init(_ title: String, detail: String? = nil, systemImage: String, action: @escaping () -> Void) {
    self.title = title
    self.detail = detail
    self.systemImage = systemImage
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: systemImage)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(Hue.accent.fill)
          .frame(width: 32, height: 32)
          .background {
            RoundedRectangle(cornerRadius: KitMetrics.radius, style: .continuous)
              .fill(.kitFillSoft)
              .strokeBorder(.kitSeparator, lineWidth: 0.5)
          }
        VStack(alignment: .leading, spacing: 1) {
          Text(title).kitFont(.headline)
          if let detail { Text(detail).kitFont(.callout).foregroundStyle(.kitSecondary) }
        }
        .lineLimit(1)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .frame(minHeight: 52)
      .background {
        RoundedRectangle(cornerRadius: KitMetrics.radiusLarge, style: .continuous)
          .fill(isHovered ? AnyShapeStyle(.kitHover) : AnyShapeStyle(Color.clear))
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .kitHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
  }
}

/// On the Mac a click selects a recent item and a double click opens it; a tap opens it on iPad and iPhone.
private struct RecentItemTaps: ViewModifier {
  let isTouch: Bool
  let open: () -> Void
  let select: () -> Void

  func body(content: Content) -> some View {
    if isTouch {
      content.onTapGesture { open() }
    } else {
      content
        .onTapGesture(count: 2) { open() }
        .simultaneousGesture(TapGesture().onEnded { select() })
    }
  }
}

/// A recent item (or a shared project) in the welcome: a letter tile in the name's stable colour (or a
/// glyph), the name and its path (cut in the middle), a status chip and when it was last opened. The selected item
/// is a raised card; Return or a double click opens it (a tap on iPad and iPhone).
///
/// ```swift
/// RecentItem("harbor", subtitle: "~/Developer/harbor", date: "Today", status: "1 change", statusHue: .orange) { … }
/// RecentItem("Shell", subtitle: "~/Developer/Shell", image: shellIcon) { … }   // a project's icon in the tile's place
/// ```
///
/// A group of items (a folder of projects): `.disclosure(isExpanded:)` trails it with a chevron that opens and closes
/// it, and in a `KitOutline` it gets the chevron and its indent (20pt a level) from the outline. Its `action` (Return,
/// a double click) is still yours: usually the same toggle.
///
/// ```swift
/// KitOutline(tree.roots, children: { $0.group == nil ? nil : $0.children }, collapsed: $collapsed.ids) { node in
///   if let group = node.group {
///     RecentItem(group.name, subtitle: "3 projects", systemImage: "folder", id: "group:\(group.id)") {
///       collapsed.toggle(group.id)
///     }
///   } else { … }
/// }
/// RecentItem(group.name, systemImage: "folder") { toggle() }.disclosure(isExpanded: $isOpen)
/// ```
public struct RecentItem: View {
  var title: String
  var subtitle: String?
  var date: String?
  var status: String?
  var statusHue: Hue
  var systemImage: String?
  var image: Image?
  var id: String
  var action: () -> Void
  var isExpanded: Binding<Bool>?
  @Environment(DataNavModel.self) private var nav: DataNavModel?
  @Environment(\.contRowDisclosure) private var outlineDisclosure
  @Environment(\.contRowIndent) private var indent
  @Environment(\.colorScheme) private var scheme
  @Environment(\.kitIdiom) private var idiom
  @State private var isHovered = false

  public init(
    _ title: String, subtitle: String? = nil, date: String? = nil, status: String? = nil, statusHue: Hue = .gray,
    systemImage: String? = nil, image: Image? = nil, id: String? = nil, action: @escaping () -> Void
  ) {
    self.title = title
    self.subtitle = subtitle
    self.date = date
    self.status = status
    self.statusHue = statusHue
    self.systemImage = systemImage
    self.image = image
    self.id = id ?? subtitle ?? title
    self.action = action
  }

  private var isSelected: Bool { nav?.selected == id }

  /// Trails the item with a chevron bound to `isExpanded` (a group of projects); `nil` removes it.
  ///
  /// ```swift
  /// RecentItem(group.name, systemImage: "folder") { isOpen.toggle() }.disclosure(isExpanded: $isOpen)
  /// ```
  public func disclosure(isExpanded: Binding<Bool>?) -> Self {
    var item = self
    item.isExpanded = isExpanded
    return item
  }

  /// The item's own open state, or the one its `KitOutline` gives it.
  private var expansion: Binding<Bool>? { isExpanded ?? outlineDisclosure?.isExpanded }

  public var body: some View {
    HStack(spacing: 12) {
      Group {
        if let image {
          Avatar(name: title, image: image, kind: .thing, size: 36)
        } else if let systemImage {
          Tile(systemImage: systemImage, hue: StableHue.pick(title), size: 36)
        } else {
          Tile(letters: String(title.prefix(1)).uppercased(), hue: StableHue.pick(title), size: 36)
        }
      }
      VStack(alignment: .leading, spacing: 1) {
        Text(title).kitFont(.headline).lineLimit(1)
        if let subtitle {
          Text(subtitle)
            .kitFont(.caption)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 3) {
        if let status { Chip(status, hue: statusHue) }
        if let date { Text(date).kitFont(.caption) }
      }
      if let expansion {
        RecentItemChevron(isExpanded: expansion, title: title)
      }
    }
    .padding(.leading, 10)
    .padding(.trailing, expansion == nil ? 10 : 2)
    .frame(minHeight: 56)
    .background {
      if isSelected {
        SurfaceShape(surface: .raised, cornerRadius: KitMetrics.radiusLarge)
      } else if isHovered {
        RoundedRectangle(cornerRadius: KitMetrics.radiusLarge, style: .continuous).fill(.kitHover)
      }
    }
    .contentShape(Rectangle())
    .kitHover { isHovered = $0 }
    .modifier(RecentItemTaps(isTouch: idiom.isTouch, open: { nav?.activate(id) ?? action() }, select: {
      withKitAnimation(.kitFast) { nav?.selected = id }
    }))
    .dataNavItem(id, model: nav, action: action)
    .id(id)
    .help(subtitle ?? title)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction { action() }
    .modifier(ContDisclosureAccessibility(disclosure: expansion.map { ContRowDisclosure(isExpanded: $0) }))
    .padding(.leading, CGFloat(indent) * 20)
  }
}

/// A group's chevron at the item's end: right when closed, down when open.
private struct RecentItemChevron: View {
  @Binding var isExpanded: Bool
  let title: String
  @Environment(\.kitIdiom) private var idiom
  @State private var isHovered = false

  var body: some View {
    Button {
      withKitAnimation { isExpanded.toggle() }
    } label: {
      Image(systemName: "chevron.right")
        .font(.system(size: idiom.size(11, touch: 13), weight: .semibold))
        .foregroundStyle(isHovered ? .kitLabel : .kitSecondary)
        .rotationEffect(.degrees(isExpanded ? 90 : 0))
        .frame(width: idiom.size(28, touch: 36), height: idiom.size(28, touch: 36))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .kitHover { isHovered = $0 }
    .accessibilityLabel(isExpanded ? "Collapse \(title)" : "Expand \(title)")
  }
}

#Preview("Welcome") {
  KitWelcome(appName: "Git", version: "Version 1.0", onDrop: { _ in true }) {
    WelcomeAction("Clone Repository…", detail: "From GitHub, GitLab or any URL", systemImage: "arrow.down") {}
    WelcomeAction("Open Local Repository…", detail: "Any folder with a .git directory", systemImage: "folder") {}
    WelcomeAction("New Repository…", detail: "Start tracking a folder", systemImage: "plus") {}
  } recents: {
    RecentItem("pebble", subtitle: "~/Developer/Projects/pebble", date: "Today", status: "Up to date", statusHue: .green) {}
    RecentItem("harbor", subtitle: "~/Developer/Projects/harbor", date: "Today", status: "1 change", statusHue: .orange) {}
    RecentItem("atlas", subtitle: "~/Developer/Projects/atlas", date: "Today", status: "4 changes", statusHue: .orange) {}
  }
  .frame(width: 900, height: 660)
  .componentKit()
}

#Preview("Welcome, empty") {
  KitWelcome(
    appName: "Markdown", version: "Notes in plain Markdown files", emptyTitle: "No Recent Notes",
    emptyMessage: "Notes you open appear here."
  ) {
    WelcomeAction("New Note", detail: "Start writing", systemImage: "square.and.pencil") {}
  } recents: {
    EmptyView()
  } projects: {
    RecentItem("Notes", subtitle: "~/Notes", systemImage: "folder") {}
  }
  .frame(width: 600, height: 700)
  .componentKit()
}
