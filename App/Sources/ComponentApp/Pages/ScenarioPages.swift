import ComponentKit
import SwiftUI

/// A scenario page: the mini app in a window frame, then the outline of its code. Narrower than `minWidth` (an
/// iPhone), an app with `panes` shows them one at a time, a page each, picked by swiping or with the segments above.
struct ScenarioPage<App: View, Panes: View>: View {
  let page: Page
  var height: CGFloat = 680
  var minWidth: CGFloat = 0
  var note: String
  var code: String
  var paneTitles: [String] = []
  @ViewBuilder var app: App
  @ViewBuilder var panes: Panes
  @State private var pane: String?

  var body: some View {
    CatalogPage(page: page, maxWidth: 1240) {
      SpecimenSection("The screen", note: note) {
        WidthSwitch(minWidth: paneTitles.isEmpty ? 0 : minWidth) {
          WindowFrame(height: height, minWidth: minWidth) { app }
        } narrow: {
          paged
        }
      }
      SpecimenSection("Its code", note: "Kit views and modifiers only: no colours, sizes or controls of the app's own.") {
        CodeSnippet(code)
      }
    }
  }

  private var paged: some View {
    VStack(alignment: .leading, spacing: 12) {
      KitSegmented(
        selection: Binding(get: { pane ?? paneTitles[0] }, set: { title in withKitAnimation { pane = title } }),
        options: paneTitles.map { ($0, $0) }
      )
      .kitSegmentedStyle(.wide)
      WindowFrame(height: height) {
        GeometryReader { proxy in
          ScrollView(.horizontal) {
            HStack(spacing: 0) { panes }.scrollTargetLayout()
          }
          .scrollTargetBehavior(.paging)
          .scrollPosition(id: $pane)
          .scrollIndicators(.never)
          .environment(\.scenarioPaneWidth, proxy.size.width)
        }
      }
    }
  }
}

extension ScenarioPage where Panes == EmptyView {
  init(page: Page, height: CGFloat = 680, note: String, code: String, @ViewBuilder app: () -> App) {
    self.init(page: page, height: height, note: note, code: code, app: app, panes: { EmptyView() })
  }
}

/// `wide` when it has `minWidth`, else `narrow`; until measured, the page's width decides, so a scenario's app isn't
/// built paged for the first frame and whole for the next.
private struct WidthSwitch<Wide: View, Narrow: View>: View {
  var minWidth: CGFloat
  // Closures: only the side that shows is made.
  var wide: () -> Wide
  var narrow: () -> Narrow
  @State private var width: CGFloat?
  @Environment(\.pageWidth) private var pageWidth

  init(minWidth: CGFloat, @ViewBuilder wide: @escaping () -> Wide, @ViewBuilder narrow: @escaping () -> Narrow) {
    self.minWidth = minWidth
    self.wide = wide
    self.narrow = narrow
  }

  var body: some View {
    Group {
      if (width ?? pageWidth ?? 0) < minWidth {
        narrow()
      } else {
        wide()
      }
    }
    .frame(maxWidth: .infinity)
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
  }
}

extension EnvironmentValues {
  @Entry var scenarioPaneWidth: CGFloat?
}

extension View {
  /// One page of a scenario on an iPhone: the window's width, found by its title.
  func scenarioPane(_ title: String) -> some View {
    modifier(ScenarioPane()).id(title)
  }
}

private struct ScenarioPane: ViewModifier {
  @Environment(\.scenarioPaneWidth) private var width

  func body(content: Content) -> some View {
    content.frame(width: width).clipped()
  }
}

// MARK: - Git

struct GitScenarioPage: View {
  nonisolated enum Selection: Hashable, Sendable {
    case repo(String), page(String)
  }

  @State private var selection = Selection.page("History")
  @State private var commit: String? = "330c484"
  @State private var search = ""
  @State private var fetch = SimulatedWork()
  @State private var repos = sampleRepos
  @Environment(\.showToast) private var showToast

  var body: some View {
    ScenarioPage(
      page: .gitApp, minWidth: 930,
      note: "Click commits, collapse sections, drag repositories, hover the refs, fetch from the toolbar.",
      code: """
        KitSidebar(selection: $selection, searchText: $filter) {
          KitSection("Repositories", meta: ["5 repositories", "2 with changes"], systemImage: "folder", hue: .indigo) {
            ReorderableSection(repos, move: move) { repo in
              SidebarRow(value: .repo(repo.id), repo.name, subtitle: repo.branch, icon: { Tile(letters: …) }) {
                SyncCounts(changes: repo.changes, ahead: repo.ahead, behind: repo.behind)
              }
            }
          }
          KitSection("atlas", meta: ["main", "4 changed"], systemImage: "arrow.triangle.branch", status: fetch) {
            SidebarRow(value: .changes, "Changes", systemImage: "pencil") { Count(4, .attention) }
            SidebarRow(value: .history, "History", systemImage: "clock") { Count(commits.count) }
          }
        } bottomBar: { Button("Add Repository", systemImage: "plus") { … } }

        ResizableSplit("inspector", pane: .trailing, width: 300, range: 260...420) {
          VStack(spacing: 0) {
            KitToolbar("History", meta: ["main", "2 to push"], systemImage: "clock", status: fetch) { ToolbarSlot(priority: 1) { … } menu: { … } }
            ScrollView { ForEach(commits) { CommitRow($0) } }       // Avatar, RefChips, Diffstat
          }
          .kitPane(.content)
          .kitStatusBar(systemImage: "arrow.down.circle", status: fetch) { Text("Fetched 2 hr ago") }
        } pane: {
          KitInspector(width: nil) {
            InspectorHeader(commit.message, meta: [commit.hash, "6 files changed"], systemImage: "circle.dashed") { … }
            KitSection(commit.author, meta: commit.date, systemImage: "person.fill") { InspectorRow("commit", value: …) }
            ActionBar { Button("Check Out") { … }; Button("Revert…") { … } }
          }
        }
        """,
      paneTitles: ["Sidebar", "History", "Inspector"]
    ) {
      HStack(spacing: 0) {
        sidebar.frame(width: 270)
        ResizableSplit("catalog.git.inspector", pane: .trailing, width: 300, range: 260...420, mainMinWidth: 360) {
          history
        } pane: {
          inspector
        }
      }
    } panes: {
      sidebar.scenarioPane("Sidebar")
      history.scenarioPane("History")
      inspector.scenarioPane("Inspector")
    }
  }

  private var sidebar: some View {
    KitSidebar(selection: $selection, searchText: $search, searchPrompt: "Filter") {
      KitSection("Repositories", meta: ["\(repos.count) repositories", "2 with changes"], systemImage: "folder", hue: .indigo) {
        ReorderableSection(repos, move: { repos.move(fromOffsets: $0, toOffset: $1) }) { repo in
          SidebarRow(value: Selection.repo(repo.id), repo.name, subtitle: repo.branch) {
            Tile(letters: String(repo.name.prefix(1)).uppercased(), hue: StableHue.pick(repo.name), size: 18)
          } trailing: {
            SyncCounts(changes: repo.changes, ahead: repo.ahead, behind: repo.behind)
          }
        }
      } accessory: {
        Button("Add Repository", systemImage: "plus") {}
      }
      KitSection("atlas", meta: ["main", "4 changed", "2 to push"], systemImage: "arrow.triangle.branch", hue: .red, status: fetch.status) {
        SidebarRow(value: Selection.page("Changes"), "Changes", systemImage: "pencil") { Count(4, .attention) }
        SidebarRow(value: Selection.page("History"), "History", systemImage: "clock") { Count(sampleCommits.count) }
        SidebarRow(value: Selection.page("Stashes"), "Stashes", systemImage: "tray") { Count(2) }
      }
      KitSection("Branches", meta: ["3 local", "1 merged"], systemImage: "arrow.triangle.branch", hue: .orange) {
        SidebarRow(value: Selection.page("main"), "main", systemImage: "arrow.triangle.branch") { SyncCounts(ahead: 2) }
        SidebarRow(value: Selection.page("offline"), "feature/offline-maps", systemImage: "arrow.triangle.branch") { SyncCounts(behind: 3) }
      }
    } bottomBar: {
      Button("Add Repository", systemImage: "plus") {}
    }
  }

  private var history: some View {
    VStack(spacing: 0) {
      // The kit's toolbar as the pane's title bar: the tools compact first; only then does the title give way (an
      // iPhone's width).
      KitToolbar(
        "History", meta: ["main", fetch.status == .idle ? "2 commits to push" : fetch.label], systemImage: "clock",
        status: fetch.status
      ) {
        ToolbarSlot(priority: 1) {
          ToolGroup {
            Button("Fetch", systemImage: "arrow.clockwise") { fetch.start(duration: 2) }
            Button("Pull", systemImage: "arrow.down") { showToast("Already up to date", systemImage: "checkmark") }
            Button("Push", systemImage: "arrow.up") { showToast("Pushed 2 commits", systemImage: "arrow.up") }
          }
        } menu: {
          Button("Fetch", systemImage: "arrow.clockwise") { fetch.start(duration: 2) }
          Button("Pull", systemImage: "arrow.down") { showToast("Already up to date", systemImage: "checkmark") }
          Button("Push", systemImage: "arrow.up") { showToast("Pushed 2 commits", systemImage: "arrow.up") }
        }
        Button("Commit", systemImage: "checkmark") {}.buttonStyle(.kitPrimary)
      }
      ScrollView {
        VStack(spacing: 2) {
          ForEach(sampleCommits) { item in
            CommitRow(commit: item, isSelected: commit == item.hash)
              .contentShape(Rectangle())
              .onTapGesture { withKitAnimation { commit = item.hash } }
          }
        }
        .padding(.horizontal, KitMetrics.gutter)
      }
    }
    .kitPane(.content)
    .kitStatusBar(systemImage: "arrow.down.circle", status: fetch.status) {
      Text(fetch.status == .done ? "Fetched just now" : fetch.status.isWorking ? "Fetching origin…" : "Fetched 2 hr ago")
      Text("\(sampleCommits.count) commits").foregroundStyle(.kitSecondary)
    }
  }

  @ViewBuilder
  private var inspector: some View {
    if let item = sampleCommits.first(where: { $0.hash == commit }) {
      KitInspector(width: nil) {
        InspectorHeader(item.message, meta: [item.hash, "\(item.files) files changed"], systemImage: "circle.dashed") {
          ForEach(item.refs) { RefChip($0) }
        }
        KitSection(item.author, meta: item.date, systemImage: "person.fill", hue: StableHue.pick(item.author)) {
          InspectorRow("commit", value: item.hash + "a1b2c3d4")
          InspectorRow("changes") { Diffstat(added: item.added, removed: item.removed) }
        }
        ActionBar {
          Button("Check Out", systemImage: "arrow.uturn.down") {}
          Button("Revert…", systemImage: "arrow.uturn.backward") {}
          Button("Cherry-Pick", systemImage: "arrow.right.doc.on.clipboard") {}
        }
      }
      .transition(.detail)
      .id(item.hash)
    } else {
      EmptyState(systemImage: "circle.dashed", title: "No Commit Selected").kitPane(.secondary)
    }
  }
}

/// A commit in the history list: the author, the message with its refs, the diffstat and the date.
struct CommitRow: View {
  let commit: Commit
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 10) {
      Avatar(name: commit.author)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(commit.message).kitFont(.body).fontWeight(isSelected ? .medium : .regular).lineLimit(1)
          RefChips(commit.refs, maxVisible: 2, meta: [commit.hash, commit.message])
        }
        MetaLine(commit.author, commit.hash, commit.date).kitFont(.caption)
      }
      Spacer(minLength: 8)
      Diffstat(added: commit.added, removed: commit.removed)
    }
    .padding(.horizontal, 8)
    .frame(minHeight: 44)
    .background {
      if isSelected { Color.clear.kitSurface(.raised, cornerRadius: KitMetrics.radius) }
    }
  }
}

// MARK: - Database

struct DatabaseScenarioPage: View {
  @State private var model = OrdersModel()
  @State private var table: String? = "orders"
  @State private var selection: Set<Int> = []
  @State private var sort: KitGridSort? = KitGridSort("id", ascending: false)
  @State private var query = ""
  @State private var scope = SearchScope.anyColumn
  @State private var saving: WorkStatus = .idle

  var body: some View {
    ScenarioPage(
      page: .databaseApp, height: 720, minWidth: 760,
      note: "Edit a city or note (double-click), delete or add rows, then review: the changes card lists every pending edit.",
      code: """
        KitSidebar(selection: $table) {
          KitSection("Shop", meta: ["PostgreSQL 17", "localhost"], systemImage: "cylinder.split.1x2", hue: .blue) {
            ForEach(tables) { SidebarRow(value: $0.name, $0.name, systemImage: "tablecells") { Count($0.rows) } }
          } accessory: { Chip.production.controlSize(.small) }
        }

        VStack(spacing: KitMetrics.gutter) {
          HStack {
            KitTitle("orders", meta: ["Shop", "\\(rows.count) rows"], systemImage: "tablecells", status: saving)
            KitSearchField(text: $query, prompt: "Filter rows", scope: $column, status: search, count: "4 rows")
            ToolGroup { Button("Add Row", systemImage: "plus") { … } }
          }
          KitGrid(rows, columns: columns, selection: $selection, sort: $sort, rowState: { pending[$0.id] })
          if !pending.isEmpty {
            ChangesCard(count: pending.count, meta: ["orders on Shop"], discardAll: discard, review: save) { changeRows }
          }
        }
        .kitStatusBar(systemImage: "bolt", status: saving) { Text("Connected"); Text("12 ms") }
        """,
      paneTitles: ["Tables", "orders"]
    ) {
      HStack(spacing: 0) {
        sidebar.frame(width: 250)
        tablePane
      }
    } panes: {
      sidebar.scenarioPane("Tables")
      tablePane.scenarioPane("orders")
    }
  }

  private var sidebar: some View {
    KitSidebar(selection: $table) {
      KitSection("Shop", meta: ["PostgreSQL 17", "localhost"], systemImage: "cylinder.split.1x2", hue: .blue) {
        SidebarRow(value: "orders", "orders", systemImage: "tablecells") { Count(model.orders.count) }
        SidebarRow(value: "customers", "customers", systemImage: "tablecells") { Count(1204) }
        SidebarRow(value: "products", "products", systemImage: "tablecells") { Count(86) }
        SidebarRow(value: "order_items", "order_items", systemImage: "tablecells") { Count(3410) }
      } accessory: {
        Chip("Staging", hue: .orange).controlSize(.small)
      }
      KitSection("Analytics", meta: ["DuckDB", "a file"], systemImage: "cylinder", hue: .orange, isExpanded: .constant(false)) {
        SidebarRow(value: "events", "events", systemImage: "tablecells")
      }
    }
  }

  private var tableTitle: some View {
    KitTitle("orders", meta: ["Shop", "\(rows.count) rows"], systemImage: "tablecells", hue: .teal, status: saving)
  }

  private var tableSearch: some View {
    KitSearchField(text: $query, prompt: "Filter rows", scope: $scope, count: query.isEmpty ? nil : "\(rows.count) rows")
  }

  private var tableTools: some View {
    ToolGroup(iconOnly: true) {
      Button("Add Row", systemImage: "plus") { withKitAnimation { model.insert() } }
      Button("Delete Rows", systemImage: "trash", role: .destructive) { withKitAnimation { model.delete(selection) } }
        .disabled(selection.isEmpty)
    }
  }

  private var tablePane: some View {
    VStack(spacing: KitMetrics.gutter) {
      // On an iPhone the search goes under the title.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 10) {
          tableTitle
          Spacer(minLength: 8)
          tableSearch.frame(width: 280)
          tableTools
        }
        .frame(height: KitMetrics.titlebarHeight - KitMetrics.gutter)
        VStack(spacing: KitMetrics.gutter) {
          HStack(spacing: 10) {
            tableTitle
            Spacer(minLength: 8)
            tableTools
          }
          .frame(height: KitMetrics.titlebarHeight - KitMetrics.gutter)
          tableSearch
        }
      }
      KitGrid(rows, columns: model.columns, selection: $selection, sort: $sort, rowState: { model.pending[$0.id] })
      if !model.pending.isEmpty {
        ChangesCard(
          count: model.pending.count, meta: ["orders on Shop", "nothing is saved until you review"],
          discardAll: { withKitAnimation { model.discardAll() } },
          review: {
            saving = .working
            Task {
              try? await Task.sleep(for: .seconds(1))
              withKitAnimation { model.save() }
              saving = .done
            }
          }
        ) {
          model.changeRows
        }
        .transition(.page)
      }
    }
    .padding([.horizontal, .top], KitMetrics.gutter)
    .kitPane(.content)
    .kitStatusBar(systemImage: "bolt", hue: .green, status: saving) {
      Text(saving == .done ? "Saved" : "Connected to localhost:5432")
      Text("12 ms").foregroundStyle(.kitSecondary)
    }
  }

  private var rows: [Order] {
    let all = model.sorted(by: sort)
    guard !query.isEmpty else { return all }
    return all.filter { order in
      switch scope {
      case .anyColumn: [String(order.id), order.customer, order.status, order.city ?? "", order.note ?? ""].contains { $0.localizedCaseInsensitiveContains(query) }
      case .id: String(order.id).contains(query)
      case .status: order.status.localizedCaseInsensitiveContains(query)
      case .note: (order.note ?? "").localizedCaseInsensitiveContains(query)
      }
    }
  }
}

// MARK: - Shell

struct ShellScenarioPage: View {
  @State private var query = ""
  @State private var isOpen = true
  @State private var build = SimulatedWork()
  @State private var test = SimulatedWork()
  @State private var selection: String?
  @State private var project = "atlas"
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    ScenarioPage(
      page: .shellApp, height: 640,
      note: "Pick an action: Return or a click runs it and the run lands in the project's runs. Esc closes the palette.",
      code: """
        RunBlocks(selection: $run) {
          ForEach(runs) { RunBlock($0.name, command: $0.command, status: $0.status, duration: $0.time, output: $0.log) }
        }
        .overlay {
          if isOpen {
            KitPalette(query: $query, prompt: "Run an action", status: .done, dismiss: { isOpen = false }) {
              PaletteMenu(project.name, systemImage: "folder") { ForEach(projects) { Button($0.name) { … } } }
            } content: {
              PaletteGroup("Atlas", meta: ["Swift package", "Package.swift"], systemImage: "shippingbox") {
                ForEach(actions) { PaletteItem($0.title, systemImage: $0.icon, hue: $0.hue, detail: $0.command) { run($0) } }
              }
            }
          }
        }
        """
    ) {
      ZStack(alignment: .top) {
        VStack(alignment: .leading, spacing: KitMetrics.gutter) {
          HStack {
            KitTitle(project, meta: ["~/Developer/\(project)", "Swift package"], systemImage: "apple.terminal", hue: .gray, status: build.status.isWorking ? build.status : test.status)
            Spacer()
            Button("Quick Actions", systemImage: "bolt") { isOpen = true }.buttonStyle(.kit).keyboardShortcut("r", modifiers: [.command, .shift])
          }
          .padding(.horizontal, 6)
          .frame(height: 44)
          RunBlocks(selection: $selection) {
            RunBlock("Build", command: "swift build", id: "build", systemImage: "hammer", hue: .orange, status: build.status, duration: build.label, output: build.status == .done ? sampleBuildLog : "") { build.pause() }
            RunBlock("Test", command: "swift test", id: "test", systemImage: "testtube.2", hue: .purple, status: test.status, duration: test.label, output: test.status.isFinished ? sampleTestLog : "") { test.pause() }
            RunBlock("Lint", command: "swift format lint -r .", id: "lint", systemImage: "checklist", status: .done, duration: "1.2 s")
          }
          Spacer()
        }
        .padding(KitMetrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .kitPane(.content)
        if isOpen {
          Rectangle().fill(Color.black.opacity(0.12)).ignoresSafeArea().onTapGesture { isOpen = false }
          // On touch the keyboard would open with the page (and the first text field to take focus sets up text input
          // for a second), so the palette open on the page waits for a tap.
          KitPalette(query: $query, prompt: "Run an action in \(project)", status: actions.isEmpty ? .failed : query.isEmpty ? .idle : .done, dismiss: { isOpen = false }, focusesOnAppear: !idiom.isTouch) {
            PaletteMenu(project, systemImage: "folder") {
              ForEach(["atlas", "beacon", "pebble"], id: \.self) { name in Button(name) { project = name } }
            }
          } content: {
            if build.status.isWorking || test.status.isWorking {
              PaletteGroup("Running in \(project)", meta: [build.status.isWorking ? "Build · \(build.label)" : "Test · \(test.label)"], systemImage: "bolt", status: .working) {
                if build.status.isWorking {
                  PaletteItem("Build", id: "stop-build", systemImage: "hammer", hue: .orange, status: build.status, returnLabel: "Stop") { build.pause() }
                }
                if test.status.isWorking {
                  PaletteItem("Test", id: "stop-test", systemImage: "testtube.2", hue: .purple, status: test.status, returnLabel: "Stop") { test.pause() }
                }
              }
            }
            PaletteGroup(project.capitalized, meta: ["Swift package", "Package.swift"], systemImage: "shippingbox", hue: .orange) {
              ForEach(actions, id: \.0) { title, image, hue, command in
                PaletteItem(title, systemImage: image, hue: hue, detail: command, note: title == "Test" && build.status.isWorking ? "Stops Build first" : nil) {
                  run(title)
                }
              }
            }
          }
          .frame(maxWidth: 560)
          .padding(.horizontal, KitMetrics.gutter)
          .padding(.top, 60)
          .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
      }
      .animation(.kitFast, value: isOpen)
    }
  }

  private var actions: [(String, String, Hue, String)] {
    let all: [(String, String, Hue, String)] = [
      ("Build", "hammer", .orange, "swift build"),
      ("Test", "testtube.2", .purple, "swift test"),
      ("Run", "play.fill", .green, "swift run atlas"),
      ("Resolve Packages", "arrow.triangle.2.circlepath", .blue, "swift package resolve"),
      ("Open in Xcode", "hammer.circle", .blue, "xed ."),
    ]
    return query.isEmpty ? all : all.filter { $0.0.localizedCaseInsensitiveContains(query) }
  }

  private func run(_ title: String) {
    isOpen = false
    query = ""
    switch title {
    case "Build":
      selection = "build"
      build.start(duration: 3)
    case "Test":
      selection = "test"
      test.fails = true
      build.pause()
      test.start(duration: 2)
    default:
      break
    }
  }
}

// MARK: - Markdown

struct MarkdownScenarioPage: View {
  enum Mode: String, KitOption, CaseIterable {
    case edit, read
    var title: String { rawValue.capitalized }
    var systemImage: String? { self == .edit ? "pencil" : "book" }
  }

  @State private var notes = [("Trip to Lisbon", sampleNote), ("Packing list", "# Packing list\n\n- Passport\n- Charger\n- Book"), ("Ideas", "# Ideas\n\nA catalog of every component.")]
  @State private var selected: String? = "Trip to Lisbon"
  @State private var mode = Mode.read
  @State private var search = ""

  var body: some View {
    ScenarioPage(
      page: .markdownApp, minWidth: 760,
      note: "Switch between Edit and Read; type in Edit and read it back.",
      code: """
        KitSidebar(selection: $note, searchText: $search) {
          KitSection("Notes", meta: "\\(notes.count) notes", systemImage: "doc.text", hue: .red) {
            ForEach(notes) { SidebarRow(value: $0.id, $0.title, subtitle: "Edited today", systemImage: "doc.text") }
          }
        } bottomBar: { Button("New Note", systemImage: "square.and.pencil") { … } }

        VStack(spacing: 0) {
          HStack { KitPathBar(["Notes", note.title]); Spacer(); KitSegmented(selection: $mode) }
          if mode == .edit { TextEditor(text: $note.text).kitFont(.mono) } else { MarkdownView(note.text) }
        }
        .kitPane(.content)
        .kitStatusBar(systemImage: "checkmark", status: .done) { Text("Saved"); Text("\\(words) words") }
        """,
      paneTitles: ["Notes", "Note"]
    ) {
      HStack(spacing: 0) {
        sidebar.frame(width: 250)
        editor
      }
    } panes: {
      sidebar.scenarioPane("Notes")
      editor.scenarioPane("Note")
    }
  }

  private var sidebar: some View {
    KitSidebar(selection: $selected, searchText: $search) {
      KitSection("Notes", meta: "\(notes.count) notes", systemImage: "doc.text", hue: .red) {
        ForEach(notes.filter { search.isEmpty || $0.0.localizedCaseInsensitiveContains(search) }, id: \.0) { note in
          SidebarRow(value: note.0, note.0, subtitle: "Edited today", systemImage: "doc.text")
        }
      } accessory: {
        Button("New Note", systemImage: "plus") {
          withKitAnimation {
            notes.append(("Untitled \(notes.count + 1)", "# Untitled\n\n"))
            selected = notes.last?.0
            mode = .edit
          }
        }
      }
    } bottomBar: {
      Button("New Note", systemImage: "square.and.pencil") {}
    }
  }

  private var index: Int? { notes.firstIndex { $0.0 == selected } }

  @ViewBuilder
  private var editor: some View {
    if let index {
      VStack(spacing: 0) {
        HStack {
          KitPathBar(components: [KitPathItem("Notes", systemImage: "folder", hue: .red) {}, KitPathItem(notes[index].0, systemImage: "doc.text")])
          Spacer()
          KitSegmented(selection: $mode)
        }
        .padding(.horizontal, 12)
        .frame(height: KitMetrics.titlebarHeight)
        Group {
          if mode == .edit {
            #if os(tvOS)
              // No multi-line editor on Apple TV.
              TextField("Note", text: $notes[index].1).kitFont(.mono).padding(.horizontal, 24)
            #else
              TextEditor(text: $notes[index].1)
                .kitFont(.mono)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 24)
            #endif
          } else {
            ScrollView {
              MarkdownText(source: notes[index].1)
                .padding(.horizontal, 32)
                .padding(.vertical, 8)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
      }
      .kitPane(.content)
      .kitStatusBar(systemImage: "checkmark", status: .done) {
        Text("Saved")
        Spacer()
        Text("\(notes[index].1.split { $0.isWhitespace }.count) words · \(mode.title) mode")
      }
    } else {
      EmptyState(systemImage: "doc.text", title: "No Note Selected", message: "Pick a note or make a new one.").kitPane(.content)
    }
  }
}

/// A small Markdown reader for the scenario: headings, lists, quotes and inline styles.
struct MarkdownText: View {
  let source: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(Array(source.split(separator: "\n", omittingEmptySubsequences: true).enumerated()), id: \.offset) { _, line in
        block(String(line))
      }
    }
    .textSelection(.enabled)
  }

  @ViewBuilder
  private func block(_ line: String) -> some View {
    if line.hasPrefix("# ") {
      Text(inline(line.dropFirst(2))).kitFont(.largeTitle).padding(.top, 6)
    } else if line.hasPrefix("## ") {
      Text(inline(line.dropFirst(3))).kitFont(.title3).padding(.top, 8)
    } else if line.hasPrefix("- ") {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Circle().fill(.kitTertiary).frame(width: 5, height: 5).offset(y: -3)
        Text(inline(line.dropFirst(2)))
      }
    } else if line.hasPrefix("> ") {
      Text(inline(line.dropFirst(2)))
        .foregroundStyle(.kitSecondary)
        .padding(.leading, 12)
        .overlay(alignment: .leading) { Capsule().fill(.kitAccent).frame(width: 3) }
    } else {
      Text(inline(Substring(line))).lineSpacing(3)
    }
  }

  private func inline(_ text: Substring) -> AttributedString {
    (try? AttributedString(markdown: String(text))) ?? AttributedString(String(text))
  }
}

// MARK: - Settings and welcome

struct SettingsScenarioPage: View {
  @State private var pane = "General"

  var body: some View {
    ScenarioPage(
      page: .settingsApp, height: 560,
      note: "Every pane is form cards; Updates, iCloud and About are the shared panes every v57 app lists under “v57”.",
      code: """
        Settings {
          KitSettings(selection: $pane) {
            SettingsPane("General", systemImage: "gearshape") {
              FormCard {
                FormRow("Show the welcome window", help: "When the app opens with nothing", systemImage: "macwindow") {
                  Toggle("Show the welcome window", isOn: $showWelcome).labelsHidden()
                }
              }
            }
            SettingsPane("Editor", systemImage: "character.cursor.ibeam", hue: .orange) {
              FormCard("Text") { FormRow("Font size", systemImage: "textformat.size") { KitStepper(value: $size, in: 9...24, unit: "pt") } }
            }
            SettingsPane("Updates", systemImage: "arrow.down.circle", hue: .blue, section: "v57") { UpdatesSettings() }
            SettingsPane("iCloud", systemImage: "icloud", hue: .teal, section: "v57") { VaultSettings() }
            SettingsPane("About", systemImage: "info", section: "v57") { AboutSettings() }
          }
          .componentKit(accent: .orange)
        }
        """
    ) {
      SampleSettings(selection: $pane)
    }
  }
}

struct WelcomeScenarioPage: View {
  @State private var selection: String?
  @State private var cloning = false
  @State private var url = ""
  @Environment(\.showToast) private var showToast

  var body: some View {
    ScenarioPage(
      page: .welcomeApp, height: 700, minWidth: 900,
      note: "No window of its own: the main window's detail is the welcome while no repository is selected. Pick one in "
        + "the sidebar, then Close Repository to come back. Clone opens a kit sheet over the whole window, from the "
        + "welcome or from the sidebar's bar.",
      code: """
        NavigationSplitView {
          KitSidebar(selection: $selection) {
            KitSection("Repositories", …) { ForEach(repos) { SidebarRow(value: $0.id, $0.name, …) } }
          } bottomBar: { Button("Clone Repository", systemImage: "plus") { cloning = true } }
        } detail: {
          if let selection {
            RepositoryView(selection)
          } else {
            KitWelcome(onDrop: { library.open($0) }) {
              WelcomeAction("Clone Repository…", detail: "From GitHub, GitLab or any URL", systemImage: "arrow.down") { cloning = true }
              WelcomeAction("Open Local Repository…", detail: "Any folder with a .git directory", systemImage: "folder") { open() }
            } recents: {
              ForEach(library.recent) { repo in
                RecentItem(repo.name, subtitle: repo.path, date: repo.opened, status: repo.summary, statusHue: repo.hue) { selection = repo.id }
              }
            }
          }
        }
        .kitSheet(isPresented: $cloning) { CloneSheet() }
        """,
      paneTitles: ["Sidebar", "Welcome"]
    ) {
      HStack(spacing: 0) {
        sidebar.frame(width: 250)
        detail
      }
      .kitSheet(isPresented: $cloning) { cloneSheet }
    } panes: {
      sidebar.scenarioPane("Sidebar")
      detail.scenarioPane("Welcome")
    }
  }

  private var sidebar: some View {
    KitSidebar(selection: $selection) {
      KitSection("Repositories", meta: ["\(sampleRepos.count) repositories"], systemImage: "folder", hue: .indigo) {
        ForEach(sampleRepos) { repo in
          SidebarRow(value: repo.id, repo.name, subtitle: repo.branch) {
            Tile(letters: String(repo.name.prefix(1)).uppercased(), hue: StableHue.pick(repo.name), size: 18)
          } trailing: {
            SyncCounts(changes: repo.changes, ahead: repo.ahead, behind: repo.behind)
          }
        }
      }
    } bottomBar: {
      Button("Clone Repository", systemImage: "plus") { cloning = true }
    }
  }

  @ViewBuilder
  private var detail: some View {
    if let repo = sampleRepos.first(where: { $0.id == selection }) {
      VStack(spacing: 12) {
        Tile(letters: String(repo.name.prefix(1)).uppercased(), hue: StableHue.pick(repo.name), size: 48)
        Text(repo.name).kitFont(.title2)
        Text(repo.branch).kitFont(.callout).foregroundStyle(.kitSecondary)
        Button("Close Repository") { selection = nil }.buttonStyle(.kit)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .kitPane(.content)
    } else {
      KitWelcome(
        appName: "Git", version: "Version 1.0", icon: AppIcon.image(systemImage: "arrow.triangle.branch", hue: .orange),
        onDrop: { urls in
          showToast("Opened \(urls.first?.lastPathComponent ?? "a folder")", systemImage: "folder")
          return true
        }
      ) {
        WelcomeAction("Clone Repository…", detail: "From GitHub, GitLab or any URL", systemImage: "arrow.down") { cloning = true }
        WelcomeAction("Open Local Repository…", detail: "Any folder with a .git directory", systemImage: "folder") { showToast("Open…", systemImage: "folder") }
      } recents: {
        ForEach(sampleRepos) { repo in
          RecentItem(
            repo.name, subtitle: "~/Developer/Projects/\(repo.name)", date: repo.name == "lighthouse" ? "Oct 2" : "Today",
            status: repo.changes > 0 ? "\(repo.changes) change\(repo.changes == 1 ? "" : "s")" : "Up to date",
            statusHue: repo.changes > 0 ? .orange : .green, id: repo.id
          ) {
            selection = repo.id
          }
        }
      }
      .kitPane(.content)
    }
  }

  private var cloneSheet: some View {
    KitSheet(title: "Clone Repository", meta: "Copies a repository from GitHub, GitLab or any URL.", systemImage: "arrow.down.circle") {
      FormCard { FormRow("Repository URL", systemImage: "link", field: TextField("https://", text: $url)) }
    } footer: {
      Button("Cancel") { cloning = false }.keyboardShortcut(.cancelAction)
      Button("Clone") {
        cloning = false
        showToast("Cloning \(url.isEmpty ? "the repository" : url)", systemImage: "arrow.down")
      }
      .buttonStyle(.kitPrimary)
      .keyboardShortcut(.defaultAction)
    }
  }
}
