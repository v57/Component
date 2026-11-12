import ComponentKit
import SwiftUI

// MARK: - Pages

/// A group of pages in the sidebar.
enum Area: String, CaseIterable, Identifiable {
  case foundations, status, controls, badges, containers, data, scenarios

  var id: String { rawValue }

  var title: String {
    switch self {
    case .foundations: String(localized: "Foundations")
    case .status: String(localized: "Status")
    case .controls: String(localized: "Controls")
    case .badges: String(localized: "Badges & identity")
    case .containers: String(localized: "Containers")
    case .data: String(localized: "Data")
    case .scenarios: String(localized: "Scenarios")
    }
  }

  var systemImage: String {
    switch self {
    case .foundations: "paintpalette"
    case .status: "circle.dashed"
    case .controls: "switch.2"
    case .badges: "tag"
    case .containers: "rectangle.3.group"
    case .data: "tablecells"
    case .scenarios: "macwindow"
    }
  }

  var hue: Hue {
    switch self {
    case .foundations: .pink
    case .status: .green
    case .controls: .blue
    case .badges: .orange
    case .containers: .indigo
    case .data: .teal
    case .scenarios: .purple
    }
  }

  var pages: [Page] { Page.allCases.filter { $0.area == self } }
}

/// One page of the catalog. The raw value is the id `--page` takes.
enum Page: String, CaseIterable, Identifiable, Hashable, Sendable {
  case colours, hues, type, surfaces, motion, metrics, appleTV = "apple-tv"
  case liveIcon = "live-icon", workStatus = "work-status", effects
  case buttons, toggles, segmented, menus, tabs, fields, search, stepper, keycaps, choiceCards = "choice-cards"
  case counts, chips, refs, lineCounts = "line-counts", avatars
  case sections, sidebar, stickySections = "sticky-sections", toolbar, window, inspector, forms, sheets, feedback, tooltips, dragDrop = "drag-drop"
  case grid, changes, diffs, runBlocks = "run-blocks", palette, welcome, settings, meters, secrets, pages
  case gitApp = "git", databaseApp = "database", shellApp = "shell", markdownApp = "markdown"
  case settingsApp = "settings-app", welcomeApp = "welcome-app", longList = "long-list"
  case longSection = "long-section"
  case allComponents = "all"

  var id: String { rawValue }

  var area: Area {
    switch self {
    case .colours, .hues, .type, .surfaces, .motion, .metrics, .appleTV: .foundations
    case .liveIcon, .workStatus, .effects: .status
    case .buttons, .toggles, .segmented, .menus, .tabs, .fields, .search, .stepper, .keycaps, .choiceCards: .controls
    case .counts, .chips, .refs, .lineCounts, .avatars: .badges
    case .sections, .sidebar, .stickySections, .toolbar, .window, .inspector, .forms, .sheets, .feedback, .tooltips, .dragDrop:
      .containers
    case .grid, .changes, .diffs, .runBlocks, .palette, .welcome, .settings, .meters, .secrets, .pages: .data
    case .gitApp, .databaseApp, .shellApp, .markdownApp, .settingsApp, .welcomeApp, .longList, .longSection, .allComponents:
      .scenarios
    }
  }

  var title: String {
    switch self {
    case .colours: String(localized: "Colours")
    case .hues: String(localized: "Hues")
    case .type: String(localized: "Type")
    case .surfaces: String(localized: "Surfaces")
    case .motion: String(localized: "Motion")
    case .metrics: String(localized: "Metrics")
    case .appleTV: String(localized: "Apple TV")
    case .liveIcon: String(localized: "Live Icon")
    case .workStatus: String(localized: "Work Status")
    case .effects: String(localized: "Effects")
    case .buttons: String(localized: "Buttons")
    case .toggles: String(localized: "Toggles & Chips")
    case .segmented: String(localized: "Segmented")
    case .menus: String(localized: "Menus & Pop-ups")
    case .tabs: String(localized: "Tabs & Path Bar")
    case .fields: String(localized: "Text Fields")
    case .search: String(localized: "Search")
    case .stepper: String(localized: "Stepper & Slider")
    case .keycaps: String(localized: "Keycaps")
    case .choiceCards: String(localized: "Choice Cards")
    case .counts: String(localized: "Counts & Dots")
    case .chips: String(localized: "Labels")
    case .refs: String(localized: "Refs")
    case .lineCounts: String(localized: "Line Counts & Progress")
    case .avatars: String(localized: "Avatars")
    case .sections: String(localized: "Sections & Headers")
    case .sidebar: String(localized: "Sidebar")
    case .stickySections: String(localized: "Sticky Sections")
    case .toolbar: String(localized: "Toolbar & Compacting")
    case .window: String(localized: "Window & Split")
    case .inspector: String(localized: "Inspector")
    case .forms: String(localized: "Forms")
    case .sheets: String(localized: "Sheets")
    case .feedback: String(localized: "Feedback")
    case .tooltips: String(localized: "Tooltips")
    case .dragDrop: String(localized: "Drag & Drop")
    case .grid: String(localized: "Data Grid")
    case .changes: String(localized: "Changes Card")
    case .diffs: String(localized: "Diffs & Conflicts")
    case .runBlocks: String(localized: "Run Blocks")
    case .palette: String(localized: "Command Palette")
    case .welcome: String(localized: "Welcome")
    case .settings: String(localized: "Settings")
    case .meters: String(localized: "Meters & Lanes")
    case .secrets: String(localized: "Secrets & Codes")
    case .pages: String(localized: "Pages & Documents")
    case .gitApp: String(localized: "Git")
    case .databaseApp: String(localized: "Database")
    case .shellApp: String(localized: "Shell")
    case .markdownApp: String(localized: "Markdown")
    case .settingsApp: String(localized: "Settings Window")
    case .welcomeApp: String(localized: "Welcome Screen")
    case .longList: String(localized: "Long List")
    case .longSection: String(localized: "Long Section")
    case .allComponents: String(localized: "All Components")
    }
  }

  var systemImage: String {
    switch self {
    case .colours: "swatchpalette"
    case .hues: "paintpalette"
    case .type: "textformat"
    case .surfaces: "square.stack"
    case .motion: "wind"
    case .metrics: "ruler"
    case .appleTV: "appletv"
    case .liveIcon: "circle.dashed"
    case .workStatus: "arrow.triangle.2.circlepath"
    case .effects: "sparkles"
    case .buttons: "button.horizontal"
    case .toggles: "switch.2"
    case .segmented: "rectangle.split.3x1"
    case .menus: "filemenu.and.selection"
    case .tabs: "menubar.rectangle"
    case .fields: "character.cursor.ibeam"
    case .search: "magnifyingglass"
    case .stepper: "plusminus"
    case .keycaps: "command"
    case .choiceCards: "square.grid.2x2"
    case .counts: "number"
    case .chips: "tag"
    case .refs: "arrow.triangle.branch"
    case .lineCounts: "plus.forwardslash.minus"
    case .avatars: "person.crop.circle"
    case .sections: "rectangle.grid.1x2"
    case .sidebar: "sidebar.left"
    case .stickySections: "pin"
    case .toolbar: "menubar.dock.rectangle"
    case .window: "rectangle.split.3x1"
    case .inspector: "sidebar.right"
    case .forms: "list.bullet.rectangle"
    case .sheets: "rectangle.on.rectangle"
    case .feedback: "exclamationmark.bubble"
    case .tooltips: "text.bubble"
    case .dragDrop: "hand.draw"
    case .grid: "tablecells"
    case .changes: "pencil"
    case .diffs: "plus.forwardslash.minus"
    case .runBlocks: "terminal"
    case .palette: "command.square"
    case .welcome: "hand.wave"
    case .settings: "gearshape"
    case .meters: "chart.bar.xaxis"
    case .secrets: "key"
    case .pages: "doc.on.doc"
    case .gitApp: "arrow.triangle.branch"
    case .databaseApp: "cylinder.split.1x2"
    case .shellApp: "apple.terminal"
    case .markdownApp: "text.alignleft"
    case .settingsApp: "gearshape.2"
    case .welcomeApp: "macwindow.badge.plus"
    case .longList: "list.bullet.rectangle"
    case .longSection: "text.magnifyingglass"
    case .allComponents: "square.stack.3d.up"
    }
  }

  /// One line under the page's title.
  var summary: String {
    switch self {
    case .colours: String(localized: "Grounds, text and lines: one value for light, one for dark")
    case .hues: String(localized: "The system hues by meaning, as fills, text and soft grounds")
    case .type: String(localized: "The kit's type scale, 13pt body on the Mac")
    case .surfaces: String(localized: "Cards, raised, floating, fields and fills")
    case .motion: String(localized: "One animation for everything, and the transitions")
    case .metrics: String(localized: "Radii, the gutter, control and row heights")
    case .appleTV: String(localized: "Twice the Mac, lit by focus: cards, tiles, buttons and rows")
    case .liveIcon: String(localized: "The tile that carries work: progress, done, failed")
    case .workStatus: String(localized: "A piece of work through its states, in every component")
    case .effects: String(localized: "Feedback, flourishes, light and moves")
    case .buttons: String(localized: "Secondary, primary, plain, icon; sizes, roles, disabled")
    case .toggles: String(localized: "Switch, checkbox, chip and the chip track")
    case .segmented: String(localized: "Field track and wide")
    case .menus: String(localized: "The kit's menu, pickers and menu buttons")
    case .tabs: String(localized: "Editor tabs and breadcrumbs")
    case .fields: String(localized: "Filled fields with a ring, an error and a live icon")
    case .search: String(localized: "Search with a scope, a count and its live icon")
    case .stepper: String(localized: "Values on a track, and the slider")
    case .keycaps: String(localized: "Keys, shortcuts and key hints")
    case .choiceCards: String(localized: "Selectable cards that pick one value")
    case .counts: String(localized: "Bare numbers whose colour says what they mean")
    case .chips: String(localized: "Status, safety, type and language labels")
    case .refs: String(localized: "Branches, remotes and tags, with overflow")
    case .lineCounts: String(localized: "+14 −2, diffstats, micro bars and row progress")
    case .avatars: String(localized: "People, agents, things and apps")
    case .sections: String(localized: "Card sections and the rich header")
    case .sidebar: String(localized: "Card sections, gliding selection, reorder, rename, search")
    case .stickySections: String(localized: "Sections that stay in view above or below a long sidebar")
    case .toolbar: String(localized: "The rich title, tool groups and the kit's compacting toolbar")
    case .window: String(localized: "Panes on their grounds, the split and the status bar")
    case .inspector: String(localized: "The sidebar mirrored: header, sections, rows, actions")
    case .forms: String(localized: "Rich rows in cards, with fields under them")
    case .sheets: String(localized: "Sheets, footer status and confirmations")
    case .feedback: String(localized: "Banners, toasts and empty states")
    case .tooltips: String(localized: "Rich tooltips with status and shortcut")
    case .dragDrop: String(localized: "Lifted rows, drop slots and drop targets")
    case .grid: String(localized: "Sorting, selection, editing, NULL and unsaved rows")
    case .changes: String(localized: "The edits that wait for review")
    case .diffs: String(localized: "Hunk cards, staging lines and the conflict card")
    case .runBlocks: String(localized: "Builds, tests and runs on a track")
    case .palette: String(localized: "Quick open and quick actions")
    case .welcome: String(localized: "The main screen's empty state")
    case .settings: String(localized: "The settings window with shared panes")
    case .meters: String(localized: "Stacked meters, meter tiles and board lanes")
    case .secrets: String(localized: "Secrets, one-time codes, safety codes, QR codes, files and text conflicts")
    case .pages:
      String(localized: "Scanned pages as paper, document cards, page strips, the page viewer, cropping and shared copies")
    case .gitApp: String(localized: "Sidebar sections, history and an inspector")
    case .databaseApp: String(localized: "Browse a table, edit it, review the changes")
    case .shellApp: String(localized: "Quick actions over a project's runs")
    case .markdownApp: String(localized: "Notes with Edit and Read")
    case .settingsApp: String(localized: "An app's settings, from kit pieces only")
    case .welcomeApp: String(localized: "An app's main screen with nothing open")
    case .longList: String(localized: "500 repository cards from one ForEach")
    case .longSection: String(localized: "5,000 rows streamed into one section")
    case .allComponents: String(localized: "Every component page on one long page")
    }
  }
}

// MARK: - Window

/// The catalog window: the kit sidebar of pages, and the page with the catalog's controls in the toolbar.
struct CatalogView: View {
  @Environment(CatalogModel.self) private var model
  @Environment(\.kitIdiom) private var platformIdiom
  @State private var search = ""
  @State private var columns = NavigationSplitViewVisibility.all
  @State private var compactColumn = NavigationSplitViewColumn.sidebar

  var body: some View {
    @Bindable var model = model
    NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn) {
      CatalogSidebar(search: $search, columns: platformIdiom.isTouch ? $columns : nil)
        .toolbar(removing: .sidebarToggle)
        .kitSidebarColumn()
        .defaultScrollAnchor(model.sidebarAnchor.map { UnitPoint(x: 0.5, y: $0) })
    } detail: {
      // The page's identity stays inside the column: an `id` on the column's root would be the whole detail's, and
      // the split view would build the column again on every page, its toolbar too.
      // iOS: the detail's own stack, as an app's (a split view's detail has none): a list's rows push on iPhone.
      CatalogDetailStack {
        ZStack {
          PageContent(page: model.page).id(model.page)
        }
      }
      .environment(\.kitIdiom, model.idiom ?? platformIdiom)
      .modifier(InactiveOverride(isOn: model.inactiveWindow))
      .kitToolbar(model.page.title) {
        Text(model.page.title).kitFont(.title2)
      } tools: {
        CatalogToolbar.tools(model)
      }
      .kitSidebarToggle(columnVisibility: $columns)
    }
    .onChange(of: model.page) { compactColumn = .detail }
    .onAppear {
      if model.hidesSidebar { columns = .detailOnly }
      if model.opensOnPage { compactColumn = .detail }
    }
  }
}

/// The detail column in a `NavigationStack` on iOS, so views in a page push (the Sidebar page's list on iPhone).
private struct CatalogDetailStack<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    #if os(iOS)
      NavigationStack { content }
    #else
      content
    #endif
  }
}

/// Draws the page as in a window that isn't focused (without touching the real one's state when off).
private struct InactiveOverride: ViewModifier {
  var isOn: Bool

  func body(content: Content) -> some View {
    if isOn {
      content.environment(\.kitWindowIsActive, false)
    } else {
      content
    }
  }
}

/// The pages, grouped by area, filtered by the sidebar's search.
struct CatalogSidebar: View {
  @Binding var search: String
  var columns: Binding<NavigationSplitViewVisibility>?
  @Environment(CatalogModel.self) private var model

  var body: some View {
    @Bindable var model = model
    KitSidebar(selection: $model.page, searchText: $search, searchPrompt: "Find a component", columnVisibility: columns) {
      ForEach(Area.allCases) { area in
        let pages = area.pages.filter(matches)
        if !pages.isEmpty {
          KitSection(
            area.title, meta: String(localized: "\(pages.count) pages"),
            systemImage: area.systemImage,
            hue: area.hue
          ) {
            ForEach(pages) { page in
              SidebarRow(value: page, page.title, systemImage: page.systemImage)
            }
          }
          // The area's title stays in view while its pages scroll by, and waits at the bottom until they come.
          .kitSticky(bottom: .title)
        }
      }
    }
    #if os(iOS)
      // --large-title: the iPhone's root under a large title, as Shell's Terminals (sticky sections under it).
      .navigationTitle(ProcessInfo.processInfo.arguments.contains("--large-title") ? "Component" : "")
    #endif
  }

  private func matches(_ page: Page) -> Bool {
    let query = search.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return true }
    return page.title.localizedCaseInsensitiveContains(query) || page.area.title.localizedCaseInsensitiveContains(query)
      || page.summary.localizedCaseInsensitiveContains(query)
  }
}

// MARK: - Toolbar

/// The catalog's controls: appearance, accent, idiom, Increase Contrast and an inactive window. As the window narrows
/// they go icon-only, then fold into the "…" menu, the chips first and the appearance last.
enum CatalogToolbar {
  @MainActor @ToolbarSlotBuilder
  static func tools(_ model: CatalogModel) -> [ToolbarSlot] {
    @Bindable var model = model
    ToolbarSlot(priority: 3) {
      KitSegmented(
        selection: $model.appearance,
        segments: Appearance.allCases.map { KitSegment($0.title, value: $0, systemImage: $0.systemImage) }
      )
      .help("Appearance")
    } menu: {
      KitSubmenu("Appearance", systemImage: "circle.lefthalf.filled") {
        KitMenuOptions(
          selection: $model.appearance,
          segments: Appearance.allCases.map { KitSegment($0.title, value: $0, systemImage: $0.systemImage) })
      }
    }
    ToolbarSlot(priority: 1) {
      AccentPicker(selection: $model.accent)
    } menu: {
      KitSubmenu("Accent", systemImage: "paintpalette") {
        KitMenuOptions(selection: $model.accent, options: Accent.allCases.map { ($0.title, $0) })
      }
    }
    ToolbarSlot(priority: 2) {
      KitSegmented(
        selection: Binding(get: { model.idiom ?? KitIdiom.current }, set: { model.idiom = $0 }),
        segments: [
          KitSegment("Mac", value: KitIdiom.mac, systemImage: "laptopcomputer"),
          KitSegment("iPad", value: KitIdiom.pad, systemImage: "ipad"),
          KitSegment("iPhone", value: KitIdiom.phone, systemImage: "iphone"),
        ]
      )
      .help("Idiom")
    } menu: {
      KitSubmenu("Idiom", systemImage: "laptopcomputer.and.iphone") {
        KitMenuOptions(
          selection: $model.idiom,
          options: [("Platform", KitIdiom?.none), ("Mac", .mac), ("iPad", .pad), ("iPhone", .phone)])
      }
    }
    ToolbarSlot(priority: 0) {
      ChipTrack {
        Toggle("Contrast", isOn: $model.increaseContrast)
        Toggle("Inactive", isOn: $model.inactiveWindow)
      }
      .help("Increase Contrast and an inactive window")
    } menu: {
      Toggle("Increase Contrast", isOn: $model.increaseContrast)
      Toggle("Inactive Window", isOn: $model.inactiveWindow)
    }
  }
}

/// The apps' accents as dots in a tool group; the picked one wears a check.
struct AccentPicker: View {
  @Binding var selection: Accent

  var body: some View {
    ToolGroup(iconOnly: true) {
      ForEach(Accent.allCases) { accent in
        Button {
          withKitAnimation { selection = accent }
        } label: {
          Label(accent.title, systemImage: selection == accent ? "checkmark.circle.fill" : "circle.fill")
            .foregroundStyle(accent.color)
        }
        .help("\(accent.title) \(accent.hexString)")
      }
    }
  }
}
