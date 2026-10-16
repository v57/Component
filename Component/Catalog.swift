import ComponentKit
import SwiftUI

// MARK: - Pages

/// A group of pages in the sidebar.
enum Area: String, CaseIterable, Identifiable {
  case foundations, status, controls, badges, containers, data, scenarios

  var id: String { rawValue }

  var title: String {
    switch self {
    case .foundations: "Foundations"
    case .status: "Status"
    case .controls: "Controls"
    case .badges: "Badges & identity"
    case .containers: "Containers"
    case .data: "Data"
    case .scenarios: "Scenarios"
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
  case colours, hues, type, surfaces, motion, metrics
  case liveIcon = "live-icon", workStatus = "work-status", effects
  case buttons, toggles, segmented, menus, tabs, fields, search, stepper, keycaps, choiceCards = "choice-cards"
  case counts, chips, refs, lineCounts = "line-counts", avatars
  case sections, sidebar, toolbar, window, inspector, forms, sheets, feedback, tooltips, dragDrop = "drag-drop"
  case grid, changes, diffs, runBlocks = "run-blocks", palette, welcome, settings, meters
  case gitApp = "git", databaseApp = "database", shellApp = "shell", markdownApp = "markdown"
  case settingsApp = "settings-app", welcomeApp = "welcome-app"

  var id: String { rawValue }

  var area: Area {
    switch self {
    case .colours, .hues, .type, .surfaces, .motion, .metrics: .foundations
    case .liveIcon, .workStatus, .effects: .status
    case .buttons, .toggles, .segmented, .menus, .tabs, .fields, .search, .stepper, .keycaps, .choiceCards: .controls
    case .counts, .chips, .refs, .lineCounts, .avatars: .badges
    case .sections, .sidebar, .toolbar, .window, .inspector, .forms, .sheets, .feedback, .tooltips, .dragDrop:
      .containers
    case .grid, .changes, .diffs, .runBlocks, .palette, .welcome, .settings, .meters: .data
    case .gitApp, .databaseApp, .shellApp, .markdownApp, .settingsApp, .welcomeApp: .scenarios
    }
  }

  var title: String {
    switch self {
    case .colours: "Colours"
    case .hues: "Hues"
    case .type: "Type"
    case .surfaces: "Surfaces"
    case .motion: "Motion"
    case .metrics: "Metrics"
    case .liveIcon: "Live Icon"
    case .workStatus: "Work Status"
    case .effects: "Effects"
    case .buttons: "Buttons"
    case .toggles: "Toggles & Chips"
    case .segmented: "Segmented"
    case .menus: "Menus & Pop-ups"
    case .tabs: "Tabs & Path Bar"
    case .fields: "Text Fields"
    case .search: "Search"
    case .stepper: "Stepper & Slider"
    case .keycaps: "Keycaps"
    case .choiceCards: "Choice Cards"
    case .counts: "Counts & Dots"
    case .chips: "Labels"
    case .refs: "Refs"
    case .lineCounts: "Line Counts & Progress"
    case .avatars: "Avatars"
    case .sections: "Sections & Headers"
    case .sidebar: "Sidebar"
    case .toolbar: "Toolbar & Compacting"
    case .window: "Window & Split"
    case .inspector: "Inspector"
    case .forms: "Forms"
    case .sheets: "Sheets"
    case .feedback: "Feedback"
    case .tooltips: "Tooltips"
    case .dragDrop: "Drag & Drop"
    case .grid: "Data Grid"
    case .changes: "Changes Card"
    case .diffs: "Diffs & Conflicts"
    case .runBlocks: "Run Blocks"
    case .palette: "Command Palette"
    case .welcome: "Welcome"
    case .settings: "Settings"
    case .meters: "Meters & Lanes"
    case .gitApp: "Git"
    case .databaseApp: "Database"
    case .shellApp: "Shell"
    case .markdownApp: "Markdown"
    case .settingsApp: "Settings Window"
    case .welcomeApp: "Welcome Window"
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
    case .gitApp: "arrow.triangle.branch"
    case .databaseApp: "cylinder.split.1x2"
    case .shellApp: "apple.terminal"
    case .markdownApp: "text.alignleft"
    case .settingsApp: "gearshape.2"
    case .welcomeApp: "macwindow.badge.plus"
    }
  }

  /// One line under the page's title.
  var summary: String {
    switch self {
    case .colours: "Grounds, text and lines: one value for light, one for dark"
    case .hues: "The system hues by meaning, as fills, text and soft grounds"
    case .type: "The kit's type scale, 13pt body on the Mac"
    case .surfaces: "Cards, raised, floating, fields and fills"
    case .motion: "One animation for everything, and the transitions"
    case .metrics: "Radii, the gutter, control and row heights"
    case .liveIcon: "The tile that carries work: progress, done, failed"
    case .workStatus: "A piece of work through its states, in every component"
    case .effects: "Feedback, flourishes, light and moves"
    case .buttons: "Secondary, primary, plain, icon; sizes, roles, disabled"
    case .toggles: "Switch, checkbox, chip and the chip track"
    case .segmented: "Field track and wide"
    case .menus: "The kit's menu, pickers and menu buttons"
    case .tabs: "Editor tabs and breadcrumbs"
    case .fields: "Filled fields with a ring, an error and a live icon"
    case .search: "Search with a scope, a count and its live icon"
    case .stepper: "Values on a track, and the slider"
    case .keycaps: "Keys, shortcuts and key hints"
    case .choiceCards: "Selectable cards that pick one value"
    case .counts: "Bare numbers whose colour says what they mean"
    case .chips: "Status, safety, type and language labels"
    case .refs: "Branches, remotes and tags, with overflow"
    case .lineCounts: "+14 −2, diffstats, micro bars and row progress"
    case .avatars: "People, agents, things and apps"
    case .sections: "Card sections and the rich header"
    case .sidebar: "Card sections, gliding selection, reorder, rename, search"
    case .toolbar: "The rich title, tool groups and the compacting toolbar"
    case .window: "Panes on their grounds, the split and the status bar"
    case .inspector: "The sidebar mirrored: header, sections, rows, actions"
    case .forms: "Rich rows in cards, with fields under them"
    case .sheets: "Sheets, footer status and confirmations"
    case .feedback: "Banners, toasts and empty states"
    case .tooltips: "Rich tooltips with status and shortcut"
    case .dragDrop: "Lifted rows, drop slots and drop targets"
    case .grid: "Sorting, selection, editing, NULL and unsaved rows"
    case .changes: "The edits that wait for review"
    case .diffs: "Hunk cards, staging lines and the conflict card"
    case .runBlocks: "Builds, tests and runs on a track"
    case .palette: "Quick open and quick actions"
    case .welcome: "The one welcome window"
    case .settings: "The settings window with shared panes"
    case .meters: "Stacked meters, meter tiles and board lanes"
    case .gitApp: "Sidebar sections, history and an inspector"
    case .databaseApp: "Browse a table, edit it, review the changes"
    case .shellApp: "Quick actions over a project's runs"
    case .markdownApp: "Notes with Edit and Read"
    case .settingsApp: "An app's settings, from kit pieces only"
    case .welcomeApp: "An app's welcome window"
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
        .navigationSplitViewColumnWidth(min: 250, ideal: 270, max: 340)
        .defaultScrollAnchor(model.sidebarMiddle ? .center : nil)
    } detail: {
      PageContent(page: model.page)
        .id(model.page)
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
            area.title, meta: pages.count == 1 ? "1 page" : "\(pages.count) pages", systemImage: area.systemImage,
            hue: area.hue
          ) {
            ForEach(pages) { page in
              SidebarRow(value: page, page.title, systemImage: page.systemImage)
            }
          }
        }
      }
    }
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
      Picker("Appearance", selection: $model.appearance) {
        ForEach(Appearance.allCases, id: \.self) { Label($0.title, systemImage: $0.systemImage).tag($0) }
      }
    }
    ToolbarSlot(priority: 1) {
      AccentPicker(selection: $model.accent)
    } menu: {
      Picker("Accent", selection: $model.accent) {
        ForEach(Accent.allCases) { Text($0.title).tag($0) }
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
      Picker("Idiom", selection: $model.idiom) {
        Text("Platform").tag(KitIdiom?.none)
        Text("Mac").tag(KitIdiom?.some(.mac))
        Text("iPad").tag(KitIdiom?.some(.pad))
        Text("iPhone").tag(KitIdiom?.some(.phone))
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
