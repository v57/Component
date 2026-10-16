import ComponentKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sections

struct SectionsPage: View {
  @State private var branchesOpen = false
  @State private var download = SimulatedWork()

  var body: some View {
    CatalogPage(page: .sections) {
      SpecimenSection(
        "Card sections", note: "Click a header to collapse it; a closed section still shows its meta. Hover for the chevron."
      ) {
        Specimen(
          "KitSection", ground: .sidebar,
          code: """
            KitSection("Repositories", meta: ["5 repositories", "2 with changes"], systemImage: "folder", hue: .indigo) {
              ForEach(repos) { SidebarRow(value: $0.id, $0.name, systemImage: "shippingbox") }
            } accessory: {
              Button("Add Repository", systemImage: "plus") { … }
            }
            """
        ) {
          HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 10) {
              KitSection("Repositories", meta: ["5 repositories", "2 with changes"], systemImage: "folder", hue: .indigo) {
                ForEach(sampleRepos.prefix(3)) { repo in
                  SidebarRow(repo.name, systemImage: "shippingbox") { SyncCounts(changes: repo.changes, ahead: repo.ahead) }
                }
              } accessory: {
                Button("Add Repository", systemImage: "plus") {}
              }
              KitSection(
                "Branches", meta: "3 local · 1 merged", systemImage: "arrow.triangle.branch", hue: .orange,
                isExpanded: $branchesOpen
              ) {
                SidebarRow("main", systemImage: "arrow.triangle.branch")
                SidebarRow("feature/offline-maps", systemImage: "arrow.triangle.branch")
              }
            }
            .frame(width: 280)
            VStack(spacing: 10) {
              KitSection(
                "Downloads", meta: ["2 downloading", download.label], systemImage: "arrow.down", hue: .red,
                status: download.status
              ) {
                SidebarRow("ubuntu-26.04.iso", systemImage: "opticaldisc") {
                  ProgressRow(value: download.status.progress ?? 0)
                }
              } accessory: {
                Button("Start", systemImage: "play.fill") { download.start(duration: 4) }
              }
              KitSection(
                "A section with a very long name that doesn't fit", meta: ["a meta line that is long as well", "and more"],
                systemImage: "text.alignleft", hue: .teal
              ) {
                SidebarRow("Row", systemImage: "doc")
              }
              KitSection("Empty", meta: "Nothing here yet", systemImage: "tray", hue: .gray) {
                Text("Drop files here").kitFont(.caption).padding(8)
              }
            }
            .frame(width: 280)
          }
        }
        Specimen(
          "Plain sections", note: "Compact sidebars like Code's navigator", ground: .sidebar,
          code: "KitSidebar(selection: $file) { KitSection(\"Sources\", meta: \"4 files\", systemImage: \"folder\") { … } }\n  .kitSectionStyle(.plain)"
        ) {
          VStack(alignment: .leading, spacing: 8) {
            KitSection("Sources", meta: "4 files", systemImage: "folder") {
              SidebarRow("TripStore.swift", systemImage: "swift", hue: .orange)
              SidebarRow("Trip.swift", systemImage: "swift", hue: .orange)
            } accessory: {
              Button("New File", systemImage: "plus") {}
            }
            KitSection("Tests", meta: ["2 files", "1 failing"], systemImage: "folder", isExpanded: .constant(false)) {
              SidebarRow("TripStoreTests.swift", systemImage: "swift")
            }
          }
          .kitSectionStyle(.plain)
          .frame(width: 260)
        }
      }
      SpecimenSection("Rich headers", note: "Sections, the toolbar title and sheets share one header.") {
        Specimen(
          "Sizes", code: "RichHeader(\"Repositories\", meta: \"5 repositories\", systemImage: \"folder\", hue: .blue) { actions }\nRichHeader(\"History\", meta: [\"main\"], size: .title, systemImage: \"clock\")"
        ) {
          VStack(alignment: .leading, spacing: 16) {
            Labeled(".section") {
              RichHeader("Repositories", meta: ["5 repositories", "2 with changes"], systemImage: "folder", hue: .blue) {
                Button("Add", systemImage: "plus") {}
                Button("More", systemImage: "ellipsis") {}
              }
              .frame(width: 320)
              .kitCard()
            }
            Labeled(".title") {
              RichHeader("History", meta: ["main", "2 commits to push"], size: .title, systemImage: "clock")
            }
            Labeled(".sheet") {
              RichHeader("Clone Repository", meta: "From GitHub, GitLab or any URL", size: .sheet, systemImage: "arrow.down.circle")
            }
            Labeled("Any icon") {
              RichHeader(Text("Maya Okafor"), icon: { Avatar(name: "Maya Okafor", presence: .online) }, meta: { Text("Online · 3 commits today") }, accessory: { EmptyView() })
                .frame(width: 320)
            }
          }
        }
      }
    }
  }
}

// MARK: - Sidebar

struct SidebarPage: View {
  @State private var selection: String? = "History"
  @State private var search = ""
  @State private var repos = sampleRepos
  @State private var renaming: String?
  @State private var file: String? = "TripStore.swift"
  @State private var hosts = ["atlas-web-1", "atlas-web-2", "atlas-db"]
  @State private var openFolders: Set<String> = ["Sources", "AtlasCore"]
  @State private var download = 0.42
  @State private var rowSelection: Int? = 2
  @State private var rowSearch = ""
  @State private var rowSearching = false
  @State private var note: Int? = 2
  @State private var notes = Array(1...6)

  var body: some View {
    CatalogPage(page: .sidebar, maxWidth: 1100) {
      SpecimenSection(
        "The kit sidebar",
        note: "Click a row: the selection glides and takes the accent tile while the sidebar has focus (click elsewhere for the flat gray). Drag repositories to reorder; double-click one to rename; search from the bottom bar."
      ) {
        HStack(alignment: .top, spacing: 20) {
          WindowFrame(height: 640) {
            KitSidebar(selection: $selection, searchText: $search, searchPrompt: "Filter") {
              KitSection("Repositories", meta: ["\(repos.count) repositories", "2 with changes"], systemImage: "folder", hue: .indigo) {
                ReorderableSection(filtered, move: { repos.move(fromOffsets: $0, toOffset: $1) }) { repo in
                  SidebarRow(value: repo.name, repo.name, subtitle: repo.branch) {
                    Tile(letters: String(repo.name.prefix(1)).uppercased(), hue: StableHue.pick(repo.name), size: 18)
                  }
                  .kitRename(
                    isRenaming: Binding(get: { renaming == repo.name }, set: { if !$0 { renaming = nil } }),
                    onCommit: { name in rename(repo, to: name) }
                  )
                  .simultaneousGesture(TapGesture(count: 2).onEnded { renaming = repo.name })
                }
              } accessory: {
                Button("Add Repository", systemImage: "plus") {
                  withKitAnimation { repos.append(Repo(name: "new-\(repos.count + 1)", branch: "main")) }
                }
              }
              KitSection("atlas", meta: ["main", "4 changed", "2 to push"], systemImage: "arrow.triangle.branch", hue: .red) {
                SidebarRow(value: "Changes", "Changes", systemImage: "pencil") { Count(4, .attention) }
                SidebarRow(value: "History", "History", systemImage: "clock") { Count(17) }
                SidebarRow(value: "Stashes", "Stashes", systemImage: "tray") { Count(2) }
                SidebarRow(value: "Checks", "Checks", systemImage: "checkmark.seal") { Count(1, .failed) }
              }
              KitSection("Remotes", meta: ["origin", "fetched 2 hr ago"], systemImage: "cloud", hue: .teal, isExpanded: .constant(false)) {
                SidebarRow(value: "origin", "origin", systemImage: "cloud")
              }
            } bottomBar: {
              Button("New Repository", systemImage: "plus") {}
              Button("Settings", systemImage: "gearshape") {}
            }
          }
          .frame(width: 290)
          VStack(alignment: .leading, spacing: 12) {
            Text("Selected: \(selection ?? "none")").kitFont(.headline)
            CodeSnippet(
              """
              KitSidebar(selection: $selection, searchText: $search) {
                KitSection("Repositories", meta: ["5 repositories"], systemImage: "folder") {
                  ReorderableSection(repos, move: { repos.move(fromOffsets: $0, toOffset: $1) }) { repo in
                    SidebarRow(value: repo.id, repo.name, subtitle: repo.branch, systemImage: "shippingbox")
                      .kitRename(isRenaming: $renaming) { rename(repo, to: $0) }
                  }
                } accessory: {
                  Button("Add Repository", systemImage: "plus") { … }
                }
                KitSection("atlas", meta: ["main", "4 changed"], systemImage: "arrow.triangle.branch") {
                  SidebarRow(value: Page.changes, "Changes", systemImage: "pencil") { Count(4, .attention) }
                  SidebarRow(value: Page.history, "History", systemImage: "clock")
                }
              } bottomBar: {
                Button("New Repository", systemImage: "plus") { … }
              }
              """)
            Specimen("Selection, focused and not", note: "Static rows outside a sidebar") {
              HStack(alignment: .top, spacing: 16) {
                Labeled("Not focused") { selectionSample.frame(width: 220) }
                Labeled("Inactive window") { selectionSample.frame(width: 220).environment(\.kitWindowIsActive, false) }
              }
            }
          }
        }
      }
      SpecimenSection("Compact sidebar", note: "Code's navigator: plain sections, 24pt rows, bare icons and indented trees.") {
        HStack(alignment: .top, spacing: 20) {
          WindowFrame(height: 420) {
            KitSidebar(selection: $file) {
              KitSection("Atlas", meta: "Swift package", systemImage: "shippingbox") {
                KitOutline(sampleTree, children: \.children, expanded: $openFolders) { node in
                  SidebarRow(
                    value: node.name, node.name, systemImage: node.children == nil ? "swift" : "folder",
                    hue: node.children == nil ? .orange : .blue)
                }
              }
              KitSection("Hosts", meta: "3 hosts", systemImage: "server.rack") {
                ReorderableSection(hosts, id: \.self, move: { hosts.move(fromOffsets: $0, toOffset: $1) }) { host in
                  SidebarRow(value: host, host, systemImage: "server.rack")
                }
              }
            }
            .kitSectionStyle(.plain)
          }
          .frame(width: 260)
          CodeSnippet(
            """
            KitSidebar(selection: $file) {
              KitSection("Atlas", meta: "Swift package", systemImage: "shippingbox") {
                KitOutline(files, children: \\.children, expanded: $openFolders) { file in
                  SidebarRow(value: file.id, file.name, systemImage: file.isFolder ? "folder" : "swift")
                }
                // or by hand: SidebarRow(…, isExpanded: $open) and .kitRowIndent(1) on the children
              }
            }
            .kitSectionStyle(.plain)        // or .kitRowDensity(.compact) with card sections
            // ↑↓ move, ← closes or goes to the parent, → opens or goes to the first child
            """)
        }
      }
      SpecimenSection(
        "A list without the bar",
        note: "KitList: the sidebar's rows and selection for a content list (notes, results). Swipe a row on iPad or with the trackpad; arrow keys move."
      ) {
        HStack(alignment: .top, spacing: 20) {
          WindowFrame(height: 360) {
            KitList(selection: $note) {
              ForEach(notes, id: \.self) { index in
                SidebarRow(value: index, sampleNotes[index % sampleNotes.count].0, systemImage: "doc.text")
                  .subtitle {
                    Text("Today").foregroundStyle(.kitLabel) + Text("  " + sampleNotes[index % sampleNotes.count].1)
                  }
                  .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                      withKitAnimation { notes.removeAll { $0 == index } }
                    }
                  }
              }
            }
            .kitPane(.secondary)
          }
          .frame(width: 300)
          CodeSnippet(
            """
            KitList(selection: $note) {
              ForEach(notes) { note in
                SidebarRow(value: note.id, note.title, systemImage: "doc.text")
                  .subtitle { Text(note.date) + Text("  " + note.preview) }
                  .swipeActions { Button("Delete", systemImage: "trash", role: .destructive) { … } }
              }
            }
            .onReturn { open(note) }
            .kitPane(.secondary)
            """)
        }
      }
      SpecimenSection(
        "Rows", note: "A progress line, any view as the subtitle, a styled title, a chip after it, a live tile, the current row and a row that acts."
      ) {
        HStack(alignment: .top, spacing: 20) {
          WindowFrame(height: 470) {
            KitSidebar(selection: $rowSelection, searchText: $rowSearch, isSearching: $rowSearching) {
              KitSection("Downloads", meta: ["2 downloading", "27.7 MB/s"], systemImage: "arrow.down", hue: .red) {
                SidebarRow(
                  value: 1, "ubuntu-26.04.iso", subtitle: "27.7 MB/s", systemImage: "opticaldisc", progress: download,
                  secondaryProgress: min(download + 0.25, 1)
                ) { ProgressRow(value: download) }
                SidebarRow(value: 2, "Lisbon trip", systemImage: "doc.text")
                  .subtitle { Text("Today").foregroundStyle(.kitLabel) + Text("  Packing list, the tram to Belém") }
                  .titleAccessory { Chip("Draft", hue: .orange) }
                SidebarRow(value: 3, "zsh — atlas", systemImage: "terminal", status: .working)
                  .subtitle { Text("✓ ").foregroundStyle(Hue.green.text) + Text("swift build").monospaced() }
                SidebarRow(value: 4, "TripStore.swift", systemImage: "swift", hue: .orange)
                  .title(Text("Trip").bold().foregroundStyle(Hue.accent.text) + Text("Store.swift"))
              }
              KitSection("Repositories", meta: "2 repositories", systemImage: "folder", hue: .indigo) {
                SidebarRow(value: 5, "atlas", systemImage: "shippingbox").isCurrent(rowSelection != 5)
                SidebarRow(value: 6, "pebble", systemImage: "shippingbox")
                SidebarRow("Add Repository…", systemImage: "plus").action {
                  withKitAnimation { download = download >= 1 ? 0 : min(download + 0.2, 1) }
                }
              }
            }
            .status { Label("On This Mac", systemImage: "laptopcomputer") }
          }
          .frame(width: 300)
          VStack(alignment: .leading, spacing: 12) {
            Button("Search", systemImage: "magnifyingglass") { withKitAnimation { rowSearching = true } }
              .buttonStyle(.kit)
              .keyboardShortcut("f")
            CodeSnippet(
              """
              KitSidebar(selection: $note, searchText: $search, isSearching: $isSearching) { … }
                .status { Label("On This Mac", systemImage: "laptopcomputer") }
                .onReturn { open(note) }   // ↑↓←→ move and open rows; Return runs this

              Button("Find") { isSearching = true }.keyboardShortcut("f")
              Detail().kitSidebarToggle(columnVisibility: $columns)   // iPad: brings a hidden sidebar back
              """)
          CodeSnippet(
            """
            SidebarRow(value: file.id, file.name, systemImage: "opticaldisc",
                       progress: file.done, secondaryProgress: file.available) { ProgressRow(value: file.done) }
            SidebarRow(value: note.id, note.title, systemImage: "doc.text")
              .subtitle { Text(note.date) + Text("  " + note.preview) }
              .titleAccessory { Chip("Draft", hue: .orange) }
            SidebarRow(value: session.id, session.name, systemImage: "terminal", status: session.status)
              .subtitle { Text("✓ ").foregroundStyle(Hue.green.text) + Text(line).monospaced() }
            SidebarRow(value: file.id, file.name, systemImage: "swift").title(Text(match.attributed))
            SidebarRow(value: repo.id, repo.name, systemImage: "shippingbox").isCurrent(repo.id == open)
            SidebarRow("Add Repository…", systemImage: "plus").action { showsClone = true }
            RowTile(systemImage: "terminal", status: .working)   // KitMetrics.rowTile(idiom) wide
            """)
          }
        }
      }
    }
  }

  private var filtered: [Repo] {
    search.isEmpty ? repos : repos.filter { $0.name.localizedCaseInsensitiveContains(search) }
  }

  private var selectionSample: some View {
    KitSidebar(selection: .constant(Optional("History"))) {
      KitSection("atlas", meta: "main", systemImage: "arrow.triangle.branch", hue: .red) {
        SidebarRow(value: "Changes", "Changes", systemImage: "pencil")
        SidebarRow(value: "History", "History", systemImage: "clock")
      }
    }
    .frame(height: 250)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func rename(_ repo: Repo, to name: String) {
    guard let index = repos.firstIndex(of: repo) else { return }
    repos[index].name = name
    if selection == repo.name { selection = name }
  }
}

/// Note titles and first lines for the list specimen.
let sampleNotes = [
  ("Lisbon trip", "The tram to Belém, then pastéis"), ("Packing list", "Adapter, the blue jacket, two books"),
  ("Reading", "Finish the essay on maps"), ("Groceries", "Lemons, rice, coffee beans"),
  ("Ideas", "A sidebar that remembers its width"), ("Meeting notes", "Ship the kit on Friday"),
]

/// A small file tree for the outline specimens.
struct SampleNode: Identifiable, Hashable {
  var id: String { name }
  var name: String
  var children: [SampleNode]?
}

let sampleTree = [
  SampleNode(name: "Package.swift"),
  SampleNode(name: "Sources", children: [
    SampleNode(name: "AtlasCore", children: [SampleNode(name: "TripStore.swift"), SampleNode(name: "Trip.swift")]),
    SampleNode(name: "AtlasApp", children: [SampleNode(name: "AtlasApp.swift")]),
  ]),
  SampleNode(name: "Tests", children: [SampleNode(name: "TripStoreTests.swift")]),
]

// MARK: - Toolbar

struct ToolbarPage: View {
  @State private var width: CGFloat = 640
  @State private var fetch = SimulatedWork()
  @State private var filterOn = true
  @State private var log: [String] = []

  var body: some View {
    CatalogPage(page: .toolbar) {
      SpecimenSection("The rich title", note: "The live icon carries the running operation.") {
        Specimen("KitTitle", ground: .window, code: "KitTitle(\"History\", meta: [\"main\", \"2 commits to push\"], systemImage: \"clock\", status: fetch)") {
          VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 30) {
              KitTitle("History", meta: ["main", "2 commits to push"], systemImage: "clock")
              KitTitle("Fetching", meta: ["origin", fetch.label], systemImage: "arrow.down.circle", status: fetch.status)
              Button("Fetch") { fetch.start() }.buttonStyle(.kit).controlSize(.small)
            }
            HStack(spacing: 30) {
              KitTitle("Pushed", meta: "2 commits", systemImage: "arrow.up", status: .done)
              KitTitle("Push failed", meta: "Rejected: fetch first", systemImage: "arrow.up", status: .failed)
              KitTitle("orders", meta: ["Shop", "10 rows"], systemImage: "tablecells", hue: .teal)
            }
          }
        }
      }
      SpecimenSection(
        "In a system toolbar",
        note: "Kit views draw their own cards, so on macOS 26 and iOS 26 the toolbar's glass stays out from behind them. This window's toolbar uses them."
      ) {
        Specimen(
          "KitToolbarItem, kitToolbarTitle, kitTool",
          code: """
            Detail()
              .kitToolbarTitle("History", meta: ["main", "2 to push"], systemImage: "clock", status: fetch)
              .toolbar {
                KitToolbarItem(placement: .primaryAction) {
                  ToolGroup {
                    Button("Fetch", systemImage: "arrow.down.circle") { … }
                    Button("Inspector", systemImage: "sidebar.right") { … }.kitToolOn(showsInspector)
                  }
                }
                ToolbarItemGroup { … }.kitToolbarItem()   // any item without the glass
              }
            Button("Filter", systemImage: "line.3.horizontal.decrease") { … }.buttonStyle(.kitToolIcon).kitToolOn(isFiltered)
            """
        ) {
          HStack(spacing: 12) {
            KitTitle("History", meta: ["main", "2 to push"], systemImage: "clock")
            Spacer()
            ToolGroup {
              Button("Fetch", systemImage: "arrow.down.circle") {}
              Button("Inspector", systemImage: "sidebar.right") { filterOn.toggle() }.kitToolOn(filterOn)
            }
            Button("Filter", systemImage: "line.3.horizontal.decrease") { filterOn.toggle() }
              .buttonStyle(.kitToolIcon)
              .kitToolOn(filterOn)
            Button("Move to Trash", systemImage: "trash", role: .destructive) {}.buttonStyle(.kitRound)
          }
        }
      }
      SpecimenSection("Tool groups") {
        Specimen(
          "ToolGroup and ToolbarOverflow", ground: .window,
          code: """
            ToolGroup {
              Button("Fetch", systemImage: "arrow.down.circle") { … }
              Button("Pull", systemImage: "arrow.down") { … }
            }
            ToolGroup(iconOnly: true) { … }
            ToolbarOverflow { Button("Stash", systemImage: "tray.and.arrow.down") { … } }
            """
        ) {
          VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: KitMetrics.gutter) {
              ToolGroup {
                Button("Fetch", systemImage: "arrow.down.circle") { log.append("Fetch") }
                Button("Pull", systemImage: "arrow.down") { log.append("Pull") }
                Button("Push", systemImage: "arrow.up") { log.append("Push") }
              }
              ToolGroup(iconOnly: true) {
                Button("Branch", systemImage: "arrow.triangle.branch") { log.append("Branch") }
                Button("Stash", systemImage: "tray.and.arrow.down") { log.append("Stash") }
                Button("Delete", systemImage: "trash", role: .destructive) { log.append("Delete") }
              }
              ToolGroup(iconOnly: true) {
                Button("Disabled", systemImage: "arrow.uturn.backward") {}.disabled(true)
              }
              ToolbarOverflow {
                Button("Stash", systemImage: "tray.and.arrow.down") { log.append("Stash") }
                Button("Cherry-Pick", systemImage: "arrow.right.doc.on.clipboard") { log.append("Cherry-Pick") }
              }
            }
            Text(log.isEmpty ? "Click a tool" : log.suffix(4).joined(separator: " · ")).kitFont(.caption)
          }
        }
      }
      SpecimenSection(
        "Compacting toolbar",
        note: "Labelled → icon-only (labels go all at once) → folded into … by priority. The primary action never folds. Drag the width."
      ) {
        Specimen(
          "CompactingToolbar", ground: .window,
          code: """
            CompactingToolbar {
              KitTool("Fetch", systemImage: "arrow.down.circle", priority: 1) { fetch() }
              KitTool("Pull", systemImage: "arrow.down", priority: 2) { pull() }
              KitTool("Push", systemImage: "arrow.up", count: 2, priority: 3) { push() }
              KitTool.gap
              KitTool("Stash", systemImage: "tray.and.arrow.down") { stash() }
              KitTool("Commit", systemImage: "checkmark", role: .primary) { commit() }
            }
            """
        ) {
          VStack(alignment: .leading, spacing: 14) {
            HStack {
              Text("Width").kitFont(.callout)
              KitSlider("Width", value: $width, in: 140...760, valueBubble: .automatic) { "\(Int($0)) pt" }
                .frame(width: 260)
              Text("\(Int(width)) pt").kitFont(.mono).foregroundStyle(.kitSecondary)
            }
            toolbar
              .frame(width: width, alignment: .trailing)
              .padding(6)
              .background(Hue.accent.soft(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            ForEach([560.0, 380, 260, 180], id: \.self) { fixed in
              Labeled("\(Int(fixed)) pt") {
                toolbar.frame(width: fixed, alignment: .trailing)
              }
            }
          }
        }
      }
    }
  }

  private var toolbar: some View {
    CompactingToolbar {
      KitTool("Fetch", systemImage: "arrow.clockwise", priority: 1) { log.append("Fetch") }
      KitTool("Pull", systemImage: "arrow.down", priority: 2) { log.append("Pull") }
      KitTool("Push", systemImage: "arrow.up", count: 2, priority: 3) { log.append("Push") }
      KitTool.gap
      KitTool("Filter", systemImage: "line.3.horizontal.decrease", priority: 0, isOn: filterOn) { filterOn.toggle() }
      KitTool("Branch", systemImage: "arrow.triangle.branch") { log.append("Branch") }
      KitTool("Stash", systemImage: "tray.and.arrow.down", isDisabled: true) {}
      KitTool("Commit", systemImage: "checkmark", role: .primary) { log.append("Commit") }
    }
  }
}

// MARK: - Window and split

struct WindowPage: View {
  @State private var saved: WorkStatus = .done

  var body: some View {
    CatalogPage(page: .window, maxWidth: 1100) {
      SpecimenSection(
        "Panes on their grounds",
        note: "Content on the window's sheet, secondary panes on the panel; no hairlines unless two panes share a ground. Drag the divider; double-click it to reset."
      ) {
        WindowFrame(height: 420) {
          KitWindowLayout {
            VStack(alignment: .leading, spacing: 2) {
              Text("All Notes").kitFont(.headline).padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 6)
              ForEach(["Trip to Lisbon", "Packing list", "Ideas"], id: \.self) { title in
                SidebarRow(title, subtitle: "Edited today", systemImage: "doc.text")
              }
              Spacer()
            }
            .padding(.horizontal, KitMetrics.gutter)
            .frame(width: 220)
            .kitPane(.secondary)
            ResizableSplit("catalog.window.inspector", pane: .trailing, width: 240, range: 180...360, mainMinWidth: 260) {
              VStack(alignment: .leading, spacing: 10) {
                Text("Trip to Lisbon").kitFont(.title1)
                Text("Three days in Lisbon in late October, then the train to Porto.").foregroundStyle(.kitSecondary)
                Spacer()
              }
              .padding(24)
              .frame(maxWidth: .infinity, alignment: .leading)
              .kitPane(.content)
              .kitStatusBar(systemImage: "checkmark", status: saved) {
                Text(saved == .done ? "Saved" : "Saving…")
                Spacer()
                Text("101 words · 1 min read")
              }
            } pane: {
              VStack(alignment: .leading, spacing: 10) {
                InspectorHeader("Trip to Lisbon", meta: ["Note", "Edited today"], systemImage: "doc.text")
                Button("Save", systemImage: "square.and.arrow.down") {
                  saved = .working
                  Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    saved = .done
                  }
                }
                .buttonStyle(.kit)
                Spacer()
              }
              .padding(12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .kitPane(.secondary)
            }
          }
        }
        CodeSnippet(
          """
          KitWindowLayout {
            NoteList().frame(width: 220).kitPane(.secondary)
            ResizableSplit("inspectorWidth", pane: .trailing, width: 240, range: 180...360, mainMinWidth: 260) {
              NoteEditor().kitPane(.content)
                .kitStatusBar(systemImage: "checkmark", status: saved) { Text("Saved"); Spacer(); Text("101 words") }
            } pane: {
              Inspector().kitPane(.secondary)
            }
          }
          """)
      }
      SpecimenSection("Two panes on one ground", note: "They get their hairline back.") {
        WindowFrame(height: 180) {
          KitWindowLayout {
            Text("List").frame(width: 200).frame(maxHeight: .infinity).kitPane(.secondary)
            Text("Preview").frame(width: 200).frame(maxHeight: .infinity).kitPane(.secondary)
            Text("Editor").frame(maxWidth: .infinity, maxHeight: .infinity).kitPane(.content)
          }
        }
      }
      SpecimenSection("Status bars") {
        Specimen("StatusBar", ground: .window, padding: 0, code: "StatusBar(systemImage: \"hammer\", status: .failed) { Text(\"Test failed\"); Spacer(); Text(\"Line 17\") }") {
          VStack(spacing: 0) {
            StatusBar(systemImage: "checkmark", status: .done) {
              Text("Saved")
              Spacer()
              Text("101 words · 1 min read")
            }
            StatusBar(systemImage: "hammer", status: .working(progress: 0.6)) {
              Text("Building Atlas · 31 of 48")
              Spacer()
              Text("12 s")
            }
            StatusBar(systemImage: "testtube.2", status: .failed) {
              Text("Test failed").foregroundStyle(Hue.red.text)
              Spacer()
              Text("Line 17, Column 9")
            }
            StatusBar {
              Text("No icon")
              Spacer()
              Text("UTF-8 · LF")
            }
          }
          .padding(.top, KitMetrics.gutter)
        }
      }
    }
  }
}

// MARK: - Inspector

struct InspectorPage: View {
  @State private var copied = 0

  var body: some View {
    CatalogPage(page: .inspector, maxWidth: 1100) {
      SpecimenSection(
        "The inspector", note: "Hover a row for its Copy button (the context menu copies too). The bottom edge fades while content runs on."
      ) {
        HStack(alignment: .top, spacing: 20) {
          WindowFrame(height: 620) {
            KitInspector(width: nil) {
              InspectorHeader("Sharing: Shared a trip as a file", meta: ["330c484", "6 files changed"], systemImage: "circle.dashed") {
                Chip("v1.12.0-beta.3", systemImage: "tag")
                Chip("Signed", systemImage: "checkmark.seal", hue: .green)
                RefChip(name: "main", isCurrent: true)
              }
              KitSection("Maya Okafor", meta: "Oct 8, 7:26 PM", systemImage: "person.fill", hue: .brown) {
                InspectorRow("commit", value: "330c484a1b2c3d4e5f")
                InspectorRow("parent") { Text("0baea71").kitFont(.mono) }
                InspectorRow("changes") { Diffstat(added: 148, removed: 22) }
                InspectorRow("status") { Chip(status: "merged") }
                InspectorRow("a very long key that runs out of room", value: "and a value that is long as well, cut in the middle")
              }
              KitSection("Files", meta: ["6 files", "+148 −22"], systemImage: "doc.on.doc", hue: .blue) {
                InspectorRow("TripStore.swift") { LineCounts(added: 54, removed: 12) }
                InspectorRow("Trip.swift") { LineCounts(added: 8, removed: 2) }
                InspectorRow("Share.swift") { LineCounts(added: 86, removed: 0) }
              }
              ActionBar {
                Button("Check Out", systemImage: "arrow.uturn.down") {}
                Button("Revert…", systemImage: "arrow.uturn.backward") {}
                Button("Cherry-Pick", systemImage: "arrow.right.doc.on.clipboard") {}
                Button("Delete Tag", systemImage: "trash", role: .destructive) {}
              }
              ActionBar(iconOnly: true) {
                Button("Copy", systemImage: "doc.on.doc") {}
                Button("Share", systemImage: "square.and.arrow.up") {}
                Button("Delete", systemImage: "trash", role: .destructive) {}
              }
            }
          }
          .frame(width: 340)
          CodeSnippet(
            """
            KitInspector {
              InspectorHeader("Order 10234", meta: ["Row in orders", "7 fields"],
                              systemImage: "tablecells", hue: .blue) {
                Chip("pending", hue: .orange)
              }
              KitSection("Fields", meta: "7 fields", systemImage: "list.bullet") {
                InspectorRow("id", value: "10234")
                InspectorRow("total") { Text("$128.00").kitFont(.mono) }
              }
              ActionBar {
                Button("Copy as JSON", systemImage: "doc.on.doc") { … }
                Button("Copy", systemImage: "doc.on.doc") { … }.labelStyle(.iconOnly)
                Button("Delete Row…", systemImage: "trash", role: .destructive) { … }
              }
              ActionBar(iconOnly: true) { … }   // every button as its icon
            }
            """)
        }
      }
      SpecimenSection("Headers") {
        Specimen("InspectorHeader", ground: .panel, code: "InspectorHeader(\"Order 10234\", meta: [\"orders\"], systemImage: \"tablecells\", hue: .blue, status: .working)") {
          VStack(alignment: .leading, spacing: 16) {
            InspectorHeader("Order 10234", meta: ["Row in orders", "7 fields"], systemImage: "tablecells", hue: .blue)
            InspectorHeader("Saving row…", meta: ["orders on Shop"], systemImage: "tablecells", hue: .blue, status: .working)
            InspectorHeader("A long title that wraps onto a second line because inspectors are narrow", meta: ["Wraps"], systemImage: "text.alignleft", hue: .teal)
          }
          .frame(width: 320)
        }
      }
    }
  }
}

// MARK: - Forms

struct FormsPage: View {
  @State private var url = "https://github.com/v57/Component.git"
  @State private var wrong = "github.com/v57"
  @State private var empty = ""
  @State private var sync = true
  @State private var open = false
  @State private var size = 13
  @State private var mode = "Unified"
  @State private var checking: WorkStatus = .idle

  var body: some View {
    CatalogPage(page: .forms) {
      SpecimenSection(
        "Form cards", note: "A card per group; rows with an icon tile, the label, a line of help and the control at the end."
      ) {
        Specimen(
          "Controls at the end", ground: .panel,
          code: """
            FormCard("Sync", footer: "Shared by Git, Shell, Database, Markdown, Code and Dev.") {
              FormRow("Sync with iCloud", help: "Projects, hosts and notes", systemImage: "icloud") {
                Toggle("Sync with iCloud", isOn: $sync).labelsHidden()
              }
              FormRow("Status", help: "Synced 2 min ago", systemImage: "checkmark.circle", hue: .green)
            }
            """
        ) {
          VStack(spacing: 20) {
            FormCard("Sync", footer: "Shared by Git, Shell, Database, Markdown, Code and Dev.") {
              FormRow("Sync with iCloud", help: "Projects, hosts and notes", systemImage: "icloud") {
                Toggle("Sync with iCloud", isOn: $sync).labelsHidden().toggleStyle(.kitSwitch)
              }
              FormRow("Status", help: "Synced 2 min ago", systemImage: "checkmark.circle", hue: .green)
              FormRow("Open when done", help: "In its default app", systemImage: "arrow.up.forward.app", hue: .indigo) {
                Toggle("Open when done", isOn: $open).labelsHidden().toggleStyle(.kitSwitch)
              }
              FormRow("Font size", help: "The editor's text", systemImage: "textformat.size", hue: .orange) {
                KitStepper("Font size", value: $size, in: 9...24, unit: "pt")
              }
              FormRow("Diffs", help: "How changes are laid out", systemImage: "rectangle.split.2x1", hue: .teal) {
                KitSegmented(selection: $mode, options: [("Unified", "Unified"), ("Split", "Split")])
              }
              FormRow("Location", help: "~/Developer/Component", systemImage: "folder", hue: .teal) {
                Button("Choose…") {}.buttonStyle(.kit)
              }
            }
            FormCard("Devices") {
              FormRow("This Mac", help: "Key in the Secure Enclave", systemImage: "laptopcomputer", hue: .gray)
              FormRow("iPad Pro", help: "Last seen yesterday", systemImage: "ipad", hue: .gray) {
                Button("Remove", role: .destructive) {}.buttonStyle(.kit)
              }
              FormRow("Old iPhone", help: "Removed", systemImage: "iphone", hue: .gray).disabled(true)
            }
          }
          .frame(maxWidth: 520)
        }
      }
      SpecimenSection("Fields under their rows", note: "A text field opens as a full-width filled line; a wrong one turns the tile and the help red.") {
        Specimen(
          "Field rows", ground: .panel,
          code: """
            FormRow("Repository URL", help: "GitHub, GitLab or any Git URL", systemImage: "link",
                    error: urlError, status: checking, field: TextField("https://", text: $url))
            """
        ) {
          FormCard {
            FormRow(
              "Repository URL", help: "GitHub, GitLab or any Git URL", systemImage: "link", status: checking,
              field: TextField("https://", text: $url))
            FormRow(
              "Mirror URL", help: "Optional", systemImage: "link", hue: .gray, field: TextField("https://", text: $empty))
            FormRow(
              "Upstream", systemImage: "link", hue: .orange,
              error: wrong.hasPrefix("https://") ? nil : "Not a Git URL: it starts with https:// or git@",
              field: TextField("https://", text: $wrong))
          }
          .frame(maxWidth: 520)
          .task(id: url) {
            checking = .working
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            checking = url.hasSuffix(".git") ? .done : .failed
          }
        }
      }
    }
  }
}

// MARK: - Sheets

struct SheetsPage: View {
  @State private var url = "https://github.com/v57/Component.git"
  @State private var cloning = false
  @State private var confirming = false
  @State private var deleted = 0
  @State private var panel = false
  @Environment(\.showToast) private var showToast

  var body: some View {
    CatalogPage(page: .sheets) {
      SpecimenSection("Present one", note: "Return confirms and Escape cancels.") {
        Specimen(
          "Sheet and confirmation",
          code: """
            .sheet(isPresented: $cloning) { CloneSheet() }
            .kitConfirmation("Delete harbor?", isPresented: $confirming,
                             message: "Its worktree and stashes go too.", systemImage: "trash",
                             confirm: "Delete") { delete(harbor) }
            """
        ) {
          HStack(spacing: 10) {
            Button("Clone Repository…", systemImage: "arrow.down.circle") { cloning = true }.buttonStyle(.kitPrimary)
            Button("Delete harbor…", systemImage: "trash", role: .destructive) { confirming = true }.buttonStyle(.kit)
            Button("Show Panel") { panel = true }.buttonStyle(.kit)
            if deleted > 0 { Text("Deleted \(deleted)×").kitFont(.caption) }
          }
          .sheet(isPresented: $cloning) { cloneSheet(dismiss: { cloning = false }) }
          .sheet(isPresented: $panel) {
            KitSheet(title: "Keyboard Shortcuts", meta: "Panels without Cancel get a close button.", systemImage: "keyboard", hue: .gray, onClose: { panel = false }) {
              FormCard {
                FormRow("Run", systemImage: "play.fill", hue: .green) { Keycaps("⌘R") }
                FormRow("Quick Actions", systemImage: "bolt", hue: .orange) { Keycaps("⇧⌘R") }
              }
            }
          }
          .kitConfirmation(
            "Delete harbor?", isPresented: $confirming,
            message: "Its worktree and 2 stashes are deleted too. This can't be undone.", systemImage: "trash",
            confirm: "Delete"
          ) {
            deleted += 1
            showToast(Toast("Deleted harbor", systemImage: "trash", undo: { deleted -= 1 }))
          }
        }
      }
      SpecimenSection("Inline", note: "The same sheets drawn in place, in their states.") {
        SpecimenGrid(minWidth: 470) {
          cloneSheet(status: .done, text: "Ready · 12 MB", dismiss: {})
            .clipShape(RoundedRectangle(cornerRadius: KitMetrics.radiusOverlay, style: .continuous))
          cloneSheet(status: .working, text: "Checking the URL…", dismiss: {})
            .clipShape(RoundedRectangle(cornerRadius: KitMetrics.radiusOverlay, style: .continuous))
          cloneSheet(status: .failed, text: "Not a Git URL", dismiss: {})
            .clipShape(RoundedRectangle(cornerRadius: KitMetrics.radiusOverlay, style: .continuous))
          KitSheet(title: "Pushing atlas", meta: "2 commits to origin/main", systemImage: "arrow.up", status: .working(progress: 0.6)) {
            EmptyView()
          } footer: {
            SheetStatus("2 of 3 objects", systemImage: "arrow.up", status: .working(progress: 0.6))
            Button("Stop", role: .destructive) {}
          }
          .clipShape(RoundedRectangle(cornerRadius: KitMetrics.radiusOverlay, style: .continuous))
        }
        CodeSnippet(
          """
          KitSheet(title: "Clone Repository", meta: "Copies a repository from GitHub, GitLab or any URL.",
                   systemImage: "arrow.down.circle") {
            FormCard { FormRow("Repository URL", systemImage: "link", field: TextField("https://", text: $url)) }
          } footer: {
            SheetStatus("Ready · 12 MB", systemImage: "arrow.down", status: .done)
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Button("Clone") { clone() }.buttonStyle(.kitPrimary).keyboardShortcut(.defaultAction)
          }
          """)
      }
    }
  }

  private func cloneSheet(status: WorkStatus = .done, text: String = "Ready · 12 MB", dismiss: @escaping () -> Void) -> some View {
    KitSheet(title: "Clone Repository", meta: "Copies a repository from GitHub, GitLab or any URL.", systemImage: "arrow.down.circle") {
      FormCard {
        FormRow(
          "Repository URL", help: "GitHub, GitLab or any Git URL", systemImage: "link",
          error: status == .failed ? "Not a Git URL" : nil, status: status == .failed ? .idle : status,
          field: TextField("https://", text: $url))
        FormRow("Location", help: "~/Developer/Component", systemImage: "folder", hue: .teal) {
          Button("Choose…") {}.buttonStyle(.kit)
        }
      }
    } footer: {
      SheetStatus(text, systemImage: "arrow.down", status: status)
      Button("Cancel", action: dismiss).keyboardShortcut(.cancelAction)
      Button("Clone", action: dismiss).buttonStyle(.kitPrimary).keyboardShortcut(.defaultAction)
        .disabled(status != .done)
    }
  }
}

// MARK: - Feedback

struct FeedbackPage: View {
  @Environment(\.showToast) private var showToast
  @State private var dismissed = false
  @State private var undone = 0

  var body: some View {
    CatalogPage(page: .feedback) {
      SpecimenSection("Banners", note: "An inset card at the top of a pane, faintly tinted with its colour.") {
        Specimen(
          "Banner", ground: .window,
          code: """
            Banner("This project has no release.env yet.", message: "release.sh steps need one.",
                   systemImage: "exclamationmark.triangle", hue: .orange) {
              Button("Set Up Release") { … }
            }
            """
        ) {
          VStack(spacing: KitMetrics.gutter) {
            Banner("This project has no release.env yet.", message: "release.sh steps need one.", systemImage: "exclamationmark.triangle", hue: .orange) {
              Button("Set Up Release") {}
            }
            if !dismissed {
              Banner("Couldn't reach origin.", message: "Check the network and try again.", systemImage: "wifi.slash", hue: .red, onDismiss: { withKitAnimation { dismissed = true } }) {
                Button("Retry") {}
              }
              .transition(.opacity)
            } else {
              Button("Show the dismissed banner") { withKitAnimation { dismissed = false } }.buttonStyle(.kitPlain)
            }
            Banner("A new version is available.", message: "Component 1.1 · 4 MB", systemImage: "arrow.down.circle", hue: .blue) {
              Button("Later") {}
              Button("Update") {}.buttonStyle(.kitPrimary)
            }
            Banner("Synced.", systemImage: "checkmark.icloud", hue: .green)
            Banner(
              "A banner with a long title that wraps onto a second line when the pane is narrow, like this one",
              message: "And a message that wraps too, up to two lines, then it is cut at its end so it stays short.",
              systemImage: "info.circle", hue: .purple)
          }
        }
      }
      SpecimenSection("Toasts", note: "One at a time at the bottom centre; resting the pointer on it keeps it.") {
        Specimen(
          "Toast", code: "@Environment(\\.showToast) private var showToast\nshowToast(Toast(\"Deleted harbor\", systemImage: \"trash\", undo: { restore(harbor) }))"
        ) {
          VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
              Button("Show a Toast") { showToast(Toast("Deleted harbor", systemImage: "trash", undo: { undone += 1 })) }
                .buttonStyle(.kitPrimary)
              Button("Just a Message") { showToast("Copied the commit hash", systemImage: "doc.on.doc") }.buttonStyle(.kit)
              if undone > 0 { Text("Undone \(undone)×").kitFont(.caption) }
            }
            ToastView(toast: Toast("Deleted harbor", systemImage: "trash", undo: {}), dismiss: {})
            ToastView(toast: Toast("Copied"), dismiss: {})
          }
        }
      }
      SpecimenSection("Empty states") {
        SpecimenGrid(minWidth: 320) {
          Specimen("With actions", ground: .window, code: "EmptyState(systemImage: \"tray\", title: \"No Stashes\", message: \"…\") {\n  Button(\"Stash Changes\") { … }.buttonStyle(.kitPrimary)\n}") {
            EmptyState(systemImage: "tray", title: "No Stashes", message: "Stash your changes to set them aside and come back later.") {
              Button("Stash Changes") {}.buttonStyle(.kitPrimary)
              Button("Learn More") {}.buttonStyle(.kit)
            }
            .frame(height: 240)
          }
          Specimen("Inactive window", ground: .window, code: "EmptyState(systemImage: \"magnifyingglass\", title: \"No Results\")") {
            EmptyState(systemImage: "magnifyingglass", title: "No Results", message: "Nothing matches “Lisbon”.")
              .frame(height: 240)
              .environment(\.kitWindowIsActive, false)
          }
        }
      }
    }
  }
}

// MARK: - Tooltips

struct TooltipsPage: View {
  @State private var fetch = SimulatedWork()

  var body: some View {
    CatalogPage(page: .tooltips) {
      SpecimenSection(
        "Rich tooltips",
        note: "Rest the pointer on a button for half a second; moving to the next swaps the tooltip at once. On iPhone it falls back to .help."
      ) {
        Specimen(
          "kitHelp", ground: .window,
          code: """
            Button("Pull", systemImage: "arrow.down") { … }
              .kitHelp("Pull", shortcut: "⇧⌘P", meta: "1 behind origin/main", systemImage: "arrow.down")
            """
        ) {
          VStack(alignment: .leading, spacing: 60) {
            ToolGroup(iconOnly: true) {
              Button("Fetch", systemImage: "arrow.clockwise") { fetch.start() }
                .kitHelp("Fetch", shortcut: "⌥⌘F", meta: fetch.status == .idle ? "Fetched 2 hr ago" : fetch.label, systemImage: "arrow.clockwise", status: fetch.status)
              Button("Pull", systemImage: "arrow.down") {}
                .kitHelp("Pull", shortcut: "⇧⌘P", meta: "1 behind origin/main", systemImage: "arrow.down")
              Button("Push", systemImage: "arrow.up") {}
                .kitHelp("Push", shortcut: "⌘P", meta: "Nothing to push", systemImage: "arrow.up").disabled(true)
              Button("Stash", systemImage: "tray.and.arrow.down") {}
                .kitHelp("Stash", meta: "Sets 4 changes aside", systemImage: "tray.and.arrow.down", hue: .purple)
            }
            HStack(spacing: 10) {
              Button("Title only") {}.buttonStyle(.kit).kitHelp("Just a title")
              Button("With a shortcut") {}.buttonStyle(.kit).kitHelp("Run", shortcut: "⌘R")
              Button("Failed", systemImage: "xmark") {}.buttonStyle(.kit)
                .kitHelp("Build failed", meta: "2 errors in TripStore.swift", systemImage: "hammer", status: .failed)
            }
          }
          .padding(.bottom, 50)
        }
      }
    }
  }
}

// MARK: - Drag and drop

struct DragDropPage: View {
  @State private var notes = ["Trip to Lisbon", "Packing list", "Ideas", "Recipes", "Books to read"]
  @State private var isTargeted = false
  @State private var dropped: [String] = []
  @State private var pinned = ["Lisbon", "Porto"]
  @State private var recent = ["Tokyo", "Kyoto", "Osaka"]
  @State private var cityNotes: [String: [String]] = [:]

  var body: some View {
    CatalogPage(page: .dragDrop) {
      SpecimenSection("The pieces", note: "Selection, drag and drop are one object: a raised card that leaves a field slot.") {
        Specimen(
          "Lifted, slot and target", ground: .sidebar,
          code: """
            MyRow(item).kitLifted(dragged == item.id)
            if dropIndex == index { DropSlot() }
            FolderRow(folder).kitDropTarget(isTargeted).onDrop(of: [.fileURL], isTargeted: $isTargeted) { … }
            """
        ) {
          VStack(alignment: .leading, spacing: 2) {
            SidebarRow("atlas", systemImage: "shippingbox")
            DropSlot()
            SidebarRow("beacon", systemImage: "shippingbox").kitLifted(true)
            SidebarRow("harbor", systemImage: "folder").kitDropTarget(true)
            SidebarRow("pebble", systemImage: "shippingbox")
          }
          .frame(width: 260)
        }
      }
      SpecimenSection("Live", note: "Drag the notes to reorder them; drag a chip onto the folder.") {
        HStack(alignment: .top, spacing: 20) {
          Specimen(
            "ReorderableSection", ground: .sidebar,
            code: "ReorderableSection(notes, id: \\.self, move: { notes.move(fromOffsets: $0, toOffset: $1) }) { note in\n  SidebarRow(note, systemImage: \"doc.text\")\n}"
          ) {
            VStack(alignment: .leading, spacing: 2) {
              ReorderableSection(notes, id: \.self, move: { notes.move(fromOffsets: $0, toOffset: $1) }) { note in
                SidebarRow(note, systemImage: "doc.text")
              }
            }
            .frame(width: 260)
          }
          Specimen(
            "A drop target", ground: .sidebar,
            code: "SidebarRow(\"Inbox\", systemImage: \"tray\")\n  .kitDropTarget(isTargeted)\n  .dropDestination(for: String.self) { … } isTargeted: { isTargeted = $0 }"
          ) {
            VStack(alignment: .leading, spacing: 14) {
              HStack(spacing: 6) {
                ForEach(["Lisbon", "Porto", "Tokyo"], id: \.self) { city in
                  Chip(city, systemImage: "mappin", hue: .blue).draggable(city)
                }
              }
              SidebarRow("Inbox", subtitle: dropped.isEmpty ? "Drop a city here" : dropped.joined(separator: ", "), systemImage: "tray") {
                Count(dropped.count)
              }
              .kitDropTarget(isTargeted)
              .dropDestination(for: String.self) { items, _ in
                withAnimation(.kitSpring) { dropped.append(contentsOf: items) }
                return true
              } isTargeted: { isTargeted = $0 }
            }
            .frame(width: 260)
          }
        }
      }
      SpecimenSection("Between lists, and other drops", note: "Drag a city from Recent into Pinned; drop text (a chip above) on a city.") {
        Specimen(
          "receivesRows and alsoAccepts", ground: .sidebar,
          code: """
            ReorderableSection(pinned, id: \\.self, list: "pinned", move: { pinned.move(fromOffsets: $0, toOffset: $1) }) { … }
              .receivesRows { from, index, to in pinned.insert(recent.remove(at: index), at: to) }
              .alsoAccepts([.plainText]) { city, providers in attach(providers, to: city) }
            """
        ) {
          HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Pinned").kitFont(.sectionHeader).padding(.leading, 6)
              ReorderableSection(pinned, id: \.self, list: "pinned", move: { pinned.move(fromOffsets: $0, toOffset: $1) }) { city in
                SidebarRow(city, subtitle: cityNotes[city]?.joined(separator: ", "), systemImage: "pin")
              }
              .receivesRows { from, index, to in
                guard from == AnyHashable("recent"), recent.indices.contains(index) else { return }
                pinned.insert(recent.remove(at: index), at: min(to, pinned.count))
              }
              .alsoAccepts([.plainText]) { city, providers in
                for provider in providers {
                  _ = provider.loadObject(ofClass: NSString.self) { text, _ in
                    guard let text = text as? String else { return }
                    Task { @MainActor in cityNotes[city, default: []].append(text) }
                  }
                }
                return true
              }
            }
            .frame(width: 220)
            VStack(alignment: .leading, spacing: 2) {
              Text("Recent").kitFont(.sectionHeader).padding(.leading, 6)
              ReorderableSection(recent, id: \.self, list: "recent", move: { recent.move(fromOffsets: $0, toOffset: $1) }) { city in
                SidebarRow(city, systemImage: "clock")
              }
              .receivesRows { from, index, to in
                guard from == AnyHashable("pinned"), pinned.indices.contains(index) else { return }
                recent.insert(pinned.remove(at: index), at: min(to, recent.count))
              }
            }
            .frame(width: 220)
          }
        }
      }
    }
  }
}
