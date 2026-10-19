import SwiftUI

/// Which list the welcome window shows.
public enum WelcomeSource: String, Hashable, Sendable, CaseIterable {
  case recent = "Recent"
  case projects = "Projects"
}

/// The one welcome window every app shows, the compact one: a round close button, the app's icon, name and version,
/// its actions, then the recent items on the panel ground (or Recent | Projects when the app passes projects), and
/// "Show this window when … opens". A folder dropped anywhere on the window goes to `onDrop`. ↑↓ move through the
/// items, Return opens the selected one; a click selects, a double click opens. Name, version and icon default to
/// the app bundle's.
///
/// ```swift
/// KitWelcome(showAtLaunch: $showAtLaunch, close: { dismissWindow() }, onDrop: { library.open($0) }) {
///   WelcomeAction("Clone Repository…", detail: "From GitHub, GitLab or any URL", systemImage: "arrow.down") { … }
///   WelcomeAction("Open Local Repository…", detail: "Any folder with a .git directory", systemImage: "folder") { … }
/// } recents: {
///   ForEach(recent) { repo in
///     RecentItem(repo.name, subtitle: repo.path, date: "Today", status: "1 change", statusHue: .orange) { open(repo) }
///   }
/// }
/// ```
public struct KitWelcome<Actions: View, Recents: View, Projects: View>: View {
  var appName: String
  var version: String
  var icon: Image?
  var showAtLaunch: Binding<Bool>?
  var emptyTitle: String
  var emptyMessage: String
  var close: (() -> Void)?
  var onDrop: (([URL]) -> Bool)?
  var actions: Actions
  var recents: Recents
  var projects: Projects
  var sourceBinding: Binding<WelcomeSource>?
  var searchText: Binding<String>?
  var searchPrompt: String
  var optionsView: AnyView?
  @State private var ownSource = WelcomeSource.recent
  @State private var nav = DataNavModel()
  @State private var isDropTargeted = false
  @FocusState private var isListFocused: Bool
  @Environment(\.dataRendersFlat) private var flat
  @Environment(\.kitIdiom) private var idiom

  /// A welcome window with Recent | Projects.
  ///
  /// - Parameters:
  ///   - source: which list shows, to remember it (`@AppStorage`); without it the window keeps its own.
  ///   - searchText: shows a search field over the lists, bound to this text (filter `recents` and `projects`
  ///     with it).
  ///   - close: draws the round close button; on the Mac the window's own buttons are hidden then, so they don't
  ///     sit over it in a window without a title bar.
  public init(
    appName: String? = nil, version: String? = nil, icon: Image? = nil, showAtLaunch: Binding<Bool>? = nil,
    emptyTitle: String = "No Recent Items", emptyMessage: String = "What you open appears here.",
    source: Binding<WelcomeSource>? = nil, searchText: Binding<String>? = nil, searchPrompt: String = "Search",
    close: (() -> Void)? = nil, onDrop: (([URL]) -> Bool)? = nil, @ViewBuilder actions: () -> Actions,
    @ViewBuilder recents: () -> Recents, @ViewBuilder projects: () -> Projects
  ) {
    self.sourceBinding = source
    self.searchText = searchText
    self.searchPrompt = searchPrompt
    self.appName = appName ?? DataPlatform.appName
    self.version = version ?? "Version \(DataPlatform.version)"
    self.icon = icon
    self.showAtLaunch = showAtLaunch
    self.emptyTitle = emptyTitle
    self.emptyMessage = emptyMessage
    self.close = close
    self.onDrop = onDrop
    self.actions = actions()
    self.recents = recents()
    self.projects = projects()
  }

  private var hasProjects: Bool { Projects.self != EmptyView.self }
  private var source: WelcomeSource { sourceBinding?.wrappedValue ?? ownSource }
  private var sourceSelection: Binding<WelcomeSource> { sourceBinding ?? $ownSource }

  /// Puts more options above "Show this window when … opens": checkboxes, a pop-up ("Open at launch: …").
  ///
  /// ```swift
  /// KitWelcome(showAtLaunch: $show) { … } recents: { … }
  ///   .options { Toggle("Reopen last project", isOn: $reopen).toggleStyle(.kitCheckbox) }
  /// ```
  public func options<Options: View>(@ViewBuilder _ content: () -> Options) -> Self {
    var welcome = self
    welcome.optionsView = AnyView(content())
    return welcome
  }

  public var body: some View {
    VStack(spacing: 0) {
      identity
      list
    }
    .frame(width: idiom == .phone ? nil : 480)
    .frame(maxWidth: idiom == .phone ? .infinity : nil)
    .background(.kitWindow)
    .overlay(alignment: .topLeading) {
      if let close { CloseButton(action: close).padding(16) }
    }
    .background {
      // The round close button replaces the window's own buttons when the welcome fills its window.
      if close != nil { DataWindowButtonsHidden().ignoresSafeArea() }
    }
    .overlay { if isDropTargeted { DropRing(title: "Open in \(appName)") } }
    .modifier(WelcomeDrop(onDrop: onDrop, isTargeted: $isDropTargeted))
    .environment(nav)
    .onPreferenceChange(DataNavItemsKey.self) { ids in
      MainActor.assumeIsolated { nav.update(ids: ids) }
    }
    .animation(.kit, value: isDropTargeted)
  }

  private var identity: some View {
    VStack(spacing: 0) {
      Group {
        if let icon = icon ?? DataPlatform.appIcon {
          icon.resizable().interpolation(.high).aspectRatio(contentMode: .fit)
        } else {
          Tile(letters: String(appName.prefix(1)), hue: .accent, size: 64, style: .solid)
        }
      }
      .frame(width: 64, height: 64)
      .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
      .accessibilityHidden(true)
      Text(appName)
        .kitFont(.largeTitle)
        .padding(.top, 12)
      Text(version)
        .kitFont(.callout)
        .foregroundStyle(.kitSecondary)
        .padding(.top, 2)
      VStack(spacing: 2) { actions }
        .padding(.horizontal, idiom == .phone ? 16 : 40)
        .padding(.top, 18)
    }
    .padding(.top, 36)
    .padding(.bottom, 14)
    .frame(maxWidth: .infinity)
  }

  private var list: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: KitMetrics.gutter) {
        if hasProjects {
          KitSegmented(selection: sourceSelection, options: WelcomeSource.allCases.map { ($0.rawValue, $0) })
            .fixedSize()
        } else {
          Text("Recent").kitFont(.headline).padding(.leading, 6)
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
          .padding(.horizontal, 8)
          .padding(.top, 4)
      }
      if let showAtLaunch {
        Toggle("Show this window when \(appName) opens", isOn: showAtLaunch)
          .toggleStyle(.kitCheckbox)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 8)
          .padding(.top, 4)
      }
    }
    .padding(.horizontal, idiom == .phone ? 8 : 16)
    .padding(.top, 14)
    .padding(.bottom, 18)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.kitPanel)
    .overlay(alignment: .top) { Rectangle().fill(.kitSeparator).frame(height: 0.5) }
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
          ScrollView { rows }
            .scrollIndicators(.never)
            .onChange(of: nav.selected) { _, id in if let id { proxy.scrollTo(id) } }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .overlay {
      if nav.ids.isEmpty {
        VStack(spacing: 4) {
          Text(emptyTitle).kitFont(.headline)
          Text(onDrop == nil ? emptyMessage : "\(emptyMessage) Or drop a folder on this window.")
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
    .onKeyPress(.upArrow) {
      nav.move(by: -1)
      return .handled
    }
    .onKeyPress(.downArrow) {
      nav.move(by: 1)
      return .handled
    }
    .onKeyPress(.return) {
      nav.activate()
      return .handled
    }
    .onAppear { isListFocused = true }
    .onChange(of: source) { nav.selected = nil }
  }
}

extension KitWelcome where Projects == EmptyView {
  /// A welcome window with one list, the recent items; `searchText` adds a search field over it.
  public init(
    appName: String? = nil, version: String? = nil, icon: Image? = nil, showAtLaunch: Binding<Bool>? = nil,
    emptyTitle: String = "No Recent Items", emptyMessage: String = "What you open appears here.",
    searchText: Binding<String>? = nil, searchPrompt: String = "Search",
    close: (() -> Void)? = nil, onDrop: (([URL]) -> Bool)? = nil, @ViewBuilder actions: () -> Actions,
    @ViewBuilder recents: () -> Recents
  ) {
    self.init(
      appName: appName, version: version, icon: icon, showAtLaunch: showAtLaunch, emptyTitle: emptyTitle,
      emptyMessage: emptyMessage, searchText: searchText, searchPrompt: searchPrompt, close: close, onDrop: onDrop,
      actions: actions, recents: recents, projects: { EmptyView() })
  }
}

/// Folders dropped on the window.
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

/// The welcome window's close button: a raised circle with an ✕.
private struct CloseButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.kitLabel)
        .frame(width: 28, height: 28)
        .background { SurfaceShape(surface: .raised, cornerRadius: 14) }
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Close")
    .keyboardShortcut(.cancelAction)
  }
}

// MARK: - Actions and items

/// One of the welcome window's actions: an accent glyph on a soft tile, the title and a line of help.
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
    .onHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
  }
}

/// A recent item (or a shared project) in the welcome window: a letter tile in the name's stable colour (or a
/// glyph), the name and its path (cut in the middle), a status chip and when it was last opened. The selected item
/// is a raised card; Return or a double click opens it.
///
/// ```swift
/// RecentItem("harbor", subtitle: "~/Developer/harbor", date: "Today", status: "1 change", statusHue: .orange) { … }
/// RecentItem("Shell", subtitle: "~/Developer/Shell", image: shellIcon) { … }   // a project's icon in the tile's place
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
  @Environment(DataNavModel.self) private var nav: DataNavModel?
  @Environment(\.colorScheme) private var scheme
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
    }
    .padding(.horizontal, 10)
    .frame(minHeight: 56)
    .background {
      if isSelected {
        SurfaceShape(surface: .raised, cornerRadius: KitMetrics.radiusLarge)
      } else if isHovered {
        RoundedRectangle(cornerRadius: KitMetrics.radiusLarge, style: .continuous).fill(.kitHover)
      }
    }
    .contentShape(Rectangle())
    .onHover { isHovered = $0 }
    .onTapGesture(count: 2) { nav?.activate(id) ?? action() }
    .simultaneousGesture(TapGesture().onEnded { withKitAnimation(.kitFast) { nav?.selected = id } })
    .dataNavItem(id, model: nav, action: action)
    .id(id)
    .help(subtitle ?? title)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction { action() }
  }
}

#Preview("Welcome") {
  @Previewable @State var show = true
  KitWelcome(appName: "Git", version: "Version 1.0", showAtLaunch: $show, close: {}, onDrop: { _ in true }) {
    WelcomeAction("Clone Repository…", detail: "From GitHub, GitLab or any URL", systemImage: "arrow.down") {}
    WelcomeAction("Open Local Repository…", detail: "Any folder with a .git directory", systemImage: "folder") {}
    WelcomeAction("New Repository…", detail: "Start tracking a folder", systemImage: "plus") {}
  } recents: {
    RecentItem("pebble", subtitle: "~/Developer/Projects/pebble", date: "Today", status: "Up to date", statusHue: .green) {}
    RecentItem("harbor", subtitle: "~/Developer/Projects/harbor", date: "Today", status: "1 change", statusHue: .orange) {}
    RecentItem("atlas", subtitle: "~/Developer/Projects/atlas", date: "Today", status: "4 changes", statusHue: .orange) {}
  }
  .frame(height: 660)
  .componentKit()
}

#Preview("Welcome, empty") {
  @Previewable @State var show = true
  KitWelcome(
    appName: "Markdown", version: "Notes in plain Markdown files", showAtLaunch: $show, emptyTitle: "No Recent Notes",
    emptyMessage: "Notes you open appear here.", close: {}
  ) {
    WelcomeAction("New Note", detail: "Start writing", systemImage: "square.and.pencil") {}
  } recents: {
    EmptyView()
  } projects: {
    RecentItem("Notes", subtitle: "~/Notes", systemImage: "folder") {}
  }
  .frame(height: 560)
  .componentKit()
}
