import ComponentKit
import SwiftUI

// MARK: - Grid

/// The orders a grid edits, with its pending edits (nothing saved until reviewed).
@MainActor @Observable
final class OrdersModel {
  var orders = sampleOrders
  var pending: [Int: KitGridRowState] = [10236: .edited, 10235: .deleted]
  var edits: [Int: (field: String, old: String, new: String)] = [10236: ("status", "shipped", "refunded")]

  func sorted(by sort: KitGridSort?) -> [Order] {
    guard let sort else { return orders }
    let key: (Order) -> String =
      switch sort.column {
      case "id": { String(format: "%08d", $0.id) }
      case "customer": { $0.customer }
      case "status": { $0.status }
      case "total": { String(format: "%012.2f", Double($0.total) ?? 0) }
      case "city": { $0.city ?? "" }
      default: { $0.note ?? "" }
      }
    return orders.sorted { sort.ascending ? key($0) < key($1) : key($0) > key($1) }
  }

  func setNote(_ order: Order, _ text: String) { edit(order, field: "note", old: order.note ?? "NULL", new: text) { $0.note = text } }
  func setCity(_ order: Order, _ text: String) { edit(order, field: "city", old: order.city ?? "NULL", new: text) { $0.city = text } }

  private func edit(_ order: Order, field: String, old: String, new: String, change: (inout Order) -> Void) {
    guard let index = orders.firstIndex(of: order), old != new else { return }
    change(&orders[index])
    if pending[order.id] != .inserted { pending[order.id] = .edited }
    edits[order.id] = (field, edits[order.id]?.old ?? old, new)
  }

  func delete(_ ids: Set<Int>) {
    for id in ids { pending[id] = .deleted }
  }

  func insert() {
    let id = (orders.map(\.id).max() ?? 0) + 1
    orders.insert(Order(id: id, customer: "New customer", status: "pending", total: "0.00", city: nil, note: nil), at: 0)
    pending[id] = .inserted
  }

  func undo(_ id: Int) {
    if pending[id] == .inserted { orders.removeAll { $0.id == id } }
    if let edit = edits[id], let index = orders.firstIndex(where: { $0.id == id }) {
      let old = edit.old == "NULL" ? nil : edit.old
      if edit.field == "note" { orders[index].note = old }
      if edit.field == "city" { orders[index].city = old }
      if edit.field == "status" { orders[index].status = edit.old }
    }
    pending[id] = nil
    edits[id] = nil
  }

  func discardAll() {
    for id in Array(pending.keys) { undo(id) }
  }

  func save() {
    orders.removeAll { pending[$0.id] == .deleted }
    pending = [:]
    edits = [:]
  }

  var columns: [KitGridColumn<Order>] {
    [
      KitGridColumn("id", systemImage: "key", width: 80, alignment: .trailing, mono: true) { "\($0.id)" },
      KitGridColumn("customer", \.customer, detail: "text", width: 140),
      KitGridColumn("status", width: 110) { Chip(status: $0.status) },
      KitGridColumn("total", detail: "numeric", width: 120, alignment: .trailing, mono: true) { $0.total },
      KitGridColumn("city", \.city, width: 110) { [unowned self] order, text in self.setCity(order, text) },
      KitGridColumn("note", \.note, detail: "text") { [unowned self] order, text in self.setNote(order, text) },
    ]
  }

  @ViewBuilder var changeRows: some View {
    ForEach(orders.filter { pending[$0.id] != nil }) { order in
      let state = self.pending[order.id]!
      switch state {
      case .edited:
        let edit = self.edits[order.id]
        ChangeRow(.edited, title: "\(order.id)", field: edit?.field, old: edit?.old, new: edit?.new) { self.undo(order.id) }
      case .deleted:
        ChangeRow(.deleted, title: "\(order.id)", field: "row", old: "\(order.status), \(order.total), \(order.city ?? "NULL")") {
          self.undo(order.id)
        }
      case .inserted:
        ChangeRow(.inserted, title: "id \(order.id)", field: "row", new: "\(order.status), \(order.total)") { self.undo(order.id) }
      }
    }
  }
}

/// A Redis-like key for the outline grid specimen.
struct SampleKey: Identifiable, Hashable {
  var id: String { name }
  var name: String
  var type: String
  var value: String
  var children: [SampleKey]?
}

let sampleKeys = [
  SampleKey(name: "user", type: "group", value: "3 keys", children: [
    SampleKey(name: "user:1", type: "hash", value: "name, email, plan"),
    SampleKey(name: "user:2", type: "hash", value: "name, email"),
    SampleKey(name: "user:2:cart", type: "list", value: "4 items"),
  ]),
  SampleKey(name: "session", type: "group", value: "2 keys", children: [
    SampleKey(name: "session:a91f", type: "string", value: "{\"user\": 1}"),
    SampleKey(name: "session:b03c", type: "string", value: "{\"user\": 2}"),
  ]),
  SampleKey(name: "config", type: "string", value: "A comment long enough to wrap onto a second line when the rows grow with their cells"),
]

struct GridPage: View {
  @State private var model = OrdersModel()
  @State private var selection: Set<Int> = [10234]
  @State private var sort: KitGridSort? = KitGridSort("id", ascending: false)
  @State private var emptySelection: Set<Int> = []
  @State private var keySelection: Set<String> = ["user:1"]
  @State private var openKeys: Set<String> = ["user"]
  @State private var keys = sampleKeys
  @State private var opened = ""

  var body: some View {
    CatalogPage(page: .grid, maxWidth: 1100) {
      SpecimenSection(
        "KitGrid",
        note: "Click a header to sort; drag its edge to resize. Click a cell to focus it; ↑↓ move (⇧ extends), ←→ and Tab move the cell, Return or a double click edits city and note, Escape cancels."
      ) {
        VStack(alignment: .leading, spacing: KitMetrics.gutter) {
          // The summary goes under the buttons on an iPhone's width.
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
              gridButtons
              Spacer()
              gridSummary
            }
            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 8) { gridButtons }
              gridSummary
            }
          }
          KitGrid(model.sorted(by: sort), columns: model.columns, selection: $selection, sort: $sort, rowState: { model.pending[$0.id] }) {
            Text("\(model.orders.count) rows").kitFont(.caption)
          }
          .frame(height: 430)
        }
        .padding(KitMetrics.gutter)
        .background(.kitWindow, in: RoundedRectangle(cornerRadius: KitMetrics.radiusXL, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: KitMetrics.radiusXL, style: .continuous).strokeBorder(.kitSeparator))
        CodeSnippet(
          """
          let columns: [KitGridColumn<Order>] = [
            KitGridColumn("id", systemImage: "key", width: 80, alignment: .trailing, mono: true) { "\\($0.id)" },
            KitGridColumn("status", width: 110) { Chip(status: $0.status) },
            KitGridColumn("note", \\.note, detail: "text") { order, text in store.setNote(order, text) },
          ]
          KitGrid(orders, columns: columns, selection: $selection, sort: $sort, rowState: { pending[$0.id] }) {
            Text("\\(orders.count) rows").kitFont(.caption)
          }
          """)
      }
      SpecimenSection("Empty and inactive") {
        SpecimenGrid(minWidth: 420) {
          Specimen("No rows", ground: .window, padding: KitMetrics.gutter, code: "KitGrid([], columns: columns, selection: $selection)") {
            KitGrid([Order](), columns: Array(model.columns.prefix(4)), selection: $emptySelection) {
              Text("No rows match").kitFont(.caption)
            }
            .frame(height: 120)
          }
          Specimen("Inactive window", ground: .window, padding: KitMetrics.gutter, code: "// the selection goes flat in a window that isn't focused") {
            KitGrid(Array(sampleOrders.prefix(4)), columns: Array(model.columns.prefix(4)), selection: .constant([10239, 10238]))
              .frame(height: 180)
              .environment(\.kitWindowIsActive, false)
          }
        }
      }
      SpecimenSection(
        "Outline, menu and growing rows",
        note: "Keys in groups: ← → close and open the focused group; right-click for the menu; a double click or Return on a cell that doesn't edit opens the key. The type column draws a chip and still edits."
      ) {
        VStack(alignment: .leading, spacing: KitMetrics.gutter) {
          KitGrid(
            keys,
            columns: [
              KitGridColumn<SampleKey>("key", width: 200, mono: true) { $0.name },
              KitGridColumn<SampleKey>("type", width: 120, value: { $0.type }, edit: { key, text in rename(key, type: text) }) { key in
                Chip(key.type, hue: key.type == "group" ? .gray : .teal)
              },
              KitGridColumn<SampleKey>("value") { $0.value },
            ],
            selection: $keySelection, children: \.children, expanded: $openKeys, rowHeight: .automatic,
            primaryAction: { ids in opened = ids.sorted().joined(separator: ", ") }
          )
          .rowContextMenu { ids in
            Button("Copy Key Names") { KitPasteboard.copy(ids.sorted().joined(separator: "\n")) }
            Button("Delete", role: .destructive) {}
          }
          .frame(height: 330)
          Text(opened.isEmpty ? "Nothing opened" : "Opened \(opened)").kitFont(.caption)
          CodeSnippet(
            """
            KitGrid(keys, columns: columns, selection: $selection,
                    children: \\.children, expanded: $openGroups,     // an outline
                    rowHeight: .automatic,                           // rows grow, text wraps
                    primaryAction: { ids in open(ids) })             // double click, Return
              .rowContextMenu { ids in Button("Delete", role: .destructive) { delete(ids) } }

            KitGridColumn<Key>("type", width: 120, value: { $0.type }, edit: { setType($0, $1) }) { key in
              Chip(key.type)                                         // custom content that still edits
            }
            """)
        }
      }
    }
  }

  @ViewBuilder private var gridButtons: some View {
    Button("Add Row", systemImage: "plus") { withKitAnimation { model.insert() } }.buttonStyle(.kit)
    Button("Delete Selected", systemImage: "trash", role: .destructive) { withKitAnimation { model.delete(selection) } }
      .buttonStyle(.kit)
      .disabled(selection.isEmpty)
  }

  private var gridSummary: some View {
    Text("\(selection.count) selected · sorted by \(sort?.column ?? "nothing") \(sort?.ascending == false ? "↓" : "↑")")
      .kitFont(.caption)
  }

  private func rename(_ key: SampleKey, type: String) {
    func update(_ list: inout [SampleKey]) {
      for index in list.indices {
        if list[index].name == key.name { list[index].type = type }
        if list[index].children != nil { update(&list[index].children!) }
      }
    }
    update(&keys)
  }
}

// MARK: - Changes card

struct ChangesPage: View {
  @State private var model = OrdersModel()

  var body: some View {
    CatalogPage(page: .changes) {
      SpecimenSection("Changes card", note: "Nothing is saved until Review and Save. Undo a row or discard them all.") {
        Specimen(
          "ChangesCard", ground: .panel,
          code: """
            ChangesCard(count: pending.count, meta: ["orders on Shop", "nothing is saved until you review"],
                        discardAll: { pending.removeAll() }, review: { showReview = true }) {
              ChangeRow(.edited, title: "10236", field: "status", old: "shipped", new: "refunded") { undo(10236) }
              ChangeRow(.deleted, title: "10235", field: "row") { undo(10235) }
            }
            """
        ) {
          VStack(alignment: .leading, spacing: 10) {
            ChangesCard(
              count: model.pending.count, meta: ["orders on Shop", "nothing is saved until you review"],
              discardAll: { withKitAnimation { model.discardAll() } }, review: { withKitAnimation { model.save() } }
            ) {
              model.changeRows
            }
            Flow(spacing: 8) {
              Button("Add a Row") { withKitAnimation { model.insert() } }
              Button("Edit a Note") { withKitAnimation { model.setNote(model.orders[2], "Ring twice") } }
              Button("Delete 10239") { withKitAnimation { model.delete([10239]) } }
            }
            .buttonStyle(.kit)
            .controlSize(.small)
          }
        }
        Specimen("Nothing to review", ground: .panel, code: "ChangesCard(count: 0, meta: [\"orders on Shop\"], discardAll: …, review: …) {}") {
          ChangesCard(count: 0, meta: ["orders on Shop", "no changes"], discardAll: {}, review: {}) {}
        }
        Specimen("Custom change views", ground: .panel, code: "ChangeRow(.inserted, title: \"id 41\", field: \"row\") { Chip(\"pending\", hue: .orange); Text(\"59.00\") }") {
          ChangesCard("Staged", count: 2, meta: ["2 files"], systemImage: "tray.full", reviewTitle: "Commit", review: {}) {
            ChangeRow(.inserted, title: "Share.swift", field: "file", undo: {}) { LineCounts(added: 86, removed: 0) }
            ChangeRow(.edited, title: "TripStore.swift", field: "file", undo: {}) { Diffstat(added: 54, removed: 12) }
          }
        }
      }
    }
  }
}

// MARK: - Diffs

struct DiffsPage: View {
  @State private var selection: Set<DiffLine.ID> = [DiffLine.id(old: nil, new: 27), DiffLine.id(old: nil, new: 28)]
  @State private var unstaged = sampleDiffLines
  @State private var staged: [DiffLine] = []
  @State private var choice: ConflictChoice?
  @State private var rebaseChoice: ConflictChoice?
  @State private var layout = DiffLayout.unified
  @State private var overflow = DiffOverflow.truncate
  @State private var stagedSelection: Set<DiffLine.ID> = []

  var body: some View {
    CatalogPage(page: .diffs, maxWidth: 1100) {
      SpecimenSection(
        "Hunk cards",
        note: "Hover a changed line for its +; click lines (⇧-click for a run, or drag down them) and Stage N Lines; right-click or ⌘C copies. A staged hunk folds to a summary; open it to unstage lines."
      ) {
        Specimen(
          "Stage lines", ground: .panel,
          code: """
            HunkCard(header: "public final class TripStore", range: "@@ -23,8 +24,13 @@", lines: hunk.lines,
                     layout: layout, selection: $selected, stage: { repo.stage($0) })
            HunkCard(header: "TripStore", range: "@@ -14,6 +14,7 @@", lines: staged, isStaged: true,
                     summary: "1 line added in add(_:)", selection: $selectedStaged,
                     unstage: { repo.unstage(staged) }, unstageLines: { repo.unstage($0) })
            HunkCard(…, overflow: .scroll)   // long lines scroll sideways together
            """
        ) {
          VStack(alignment: .leading, spacing: 10) {
            Flow(spacing: 8) {
              KitSegmented(selection: $layout, options: [("Unified", .unified), ("Split", .split)])
              KitSegmented(selection: $overflow, options: [("Truncate", .truncate), ("Scroll", .scroll)])
            }
            if !staged.isEmpty {
              HunkCard(
                header: "public final class TripStore", range: "@@ -23,2 +24,\(staged.count) @@", lines: staged,
                isStaged: true, summary: "\(staged.count) lines staged in TripStore", selection: $stagedSelection,
                unstage: { withKitAnimation { unstaged = sampleDiffLines; staged = [] } },
                unstageLines: { lines in
                  withKitAnimation {
                    staged.removeAll { lines.contains($0) }
                    unstaged = sampleDiffLines.filter { !staged.contains($0) }
                  }
                })
            }
            HunkCard(
              header: "public final class TripStore", range: "@@ -23,8 +24,13 @@", lines: unstaged, layout: layout,
              selection: $selection,
              stage: { lines in
                withKitAnimation {
                  staged.append(contentsOf: lines)
                  unstaged.removeAll { line in lines.contains(line) }
                }
              }, overflow: overflow)
          }
        }
        Specimen("A staged hunk", ground: .panel, code: "HunkCard(…, lines: [], isStaged: true, summary: \"1 line added in add(_:)\", unstage: { … })") {
          HunkCard(
            header: "func add(_ trip: Trip)", range: "@@ -14,6 +14,7 @@", lines: [], isStaged: true,
            summary: "1 line added in add(_:)", unstage: {})
        }
      }
      SpecimenSection("Conflict card", note: "Current is the accent and Incoming purple; pick a side, then Undo.") {
        Specimen(
          "ConflictCard", ground: .panel,
          code: """
            ConflictCard(title: "Conflict 1 of 2", meta: ["Lines 32–36", "save()"],
                         current: ConflictSide("Current", ref: "main", code: ours),
                         incoming: ConflictSide("Incoming", ref: "feature/offline-maps", code: theirs),
                         choice: $choice, edit: { openEditor() })
            """
        ) {
          ConflictCard(
            title: "Conflict 1 of 2", meta: ["Lines 32–36", "save()"],
            current: ConflictSide("Current", ref: "main", code: "do {\n  try JSONEncoder().encode(trips).write(to: url)\n} catch {\n  lastError = error\n}"),
            incoming: ConflictSide(
              "Incoming", ref: "feature/offline-maps",
              code: "let data = try? JSONEncoder().encode(trips)\ntry? data?.write(to: url, options: .atomic)\nOfflineMaps.shared.prefetch(trips)"),
            choice: $choice, edit: {})
        }
        Specimen(
          "Incoming first, with the common ancestor", ground: .panel,
          code: """
            ConflictCard(title: "Conflict 1 of 1", current: ours, incoming: theirs,
                         ancestor: ConflictSide("Base", ref: mergeBase, code: base),
                         order: .incomingFirst, choice: $choice)   // a rebase; Base shows on demand
            """
        ) {
          ConflictCard(
            title: "Conflict 1 of 1", meta: ["Rebasing onto main", "Lines 12–13"],
            current: ConflictSide("Current", ref: "main", code: "let limit = 50\nlet timeout = 30"),
            incoming: ConflictSide("Incoming", ref: "feature/paging", code: "let limit = pageSize\nlet timeout = 30"),
            ancestor: ConflictSide("Base", ref: "a1b2c3d", code: "let limit = 20\nlet timeout = 30"),
            order: .incomingFirst, choice: $rebaseChoice)
        }
      }
    }
  }
}

// MARK: - Run blocks

struct RunBlocksPage: View {
  @State private var selection: String? = "test"
  @State private var build = SimulatedWork()

  var body: some View {
    CatalogPage(page: .runBlocks) {
      SpecimenSection(
        "Runs on a track",
        note: "Passed runs fold to their header; failed ones keep their output open. Click a header to fold or open it, and to select the run."
      ) {
        Specimen(
          "RunBlocks", ground: .window,
          code: """
            RunBlocks(selection: $selectedRun) {
              RunBlock("Build", command: "swift build", status: .done, duration: "21 s", warnings: "1 warning")
              RunBlock("Test", command: "swift test", status: .failed("exit 1"), duration: "4.2 s", output: log)
              RunBlock("Build", command: "swift build", id: "build-2", status: .working(progress: 0.64),
                       progress: "31 of 48", duration: "12 s", output: tail) { build.cancel() }
            }
            """
        ) {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Button("Run Build", systemImage: "play.fill") { build.start(duration: 5) }.buttonStyle(.kitPrimary)
              Toggle("Fail", isOn: $build.fails).toggleStyle(.kitCheckbox)
            }
            RunBlocks(selection: $selection) {
              RunBlock("Build", command: "swift build", systemImage: "hammer", status: .done, duration: "21 s", warnings: "1 warning", output: sampleBuildLog)
              RunBlock("Test", command: "swift test", id: "test", systemImage: "testtube.2", status: .failed("exit 1"), duration: "4.2 s", output: sampleTestLog)
              RunBlock(
                "Build", command: "swift build -c release", id: "live", systemImage: "hammer", status: build.status,
                progress: build.status.progress.map { "\(Int($0 * 48)) of 48" }, duration: build.label,
                output: build.status == .idle ? "" : "Building for production...\n[\(Int((build.status.progress ?? 0) * 48))/48] Compiling AtlasCore"
              ) { build.pause() }
              RunBlock("Index", command: "sourcekit-lsp index", id: "index", systemImage: "magnifyingglass", hue: .teal, status: .working, progress: "1,204 files")
              RunBlock(
                "Archive", command: "xcodebuild archive", id: "archive", systemImage: "archivebox", status: .working(progress: 0.64),
                progress: "31 of 48", duration: "12 s", output: "Building for production...\n[31/48] Compiling AtlasCore TripStore.swift", stop: {})
              RunBlock("Tail logs", command: "tail -f app.log", systemImage: "doc.text", status: .paused(), duration: "2 min")
              RunBlock(command: "git status --short", systemImage: "terminal", status: .idle)
            }
          }
        }
      }
      SpecimenSection(
        "A long run list",
        note: "A day of runs, each with its output: the blocks are built as they near the screen, a few a frame."
      ) {
        Specimen("RunBlocks { ForEach(runs) { … } }", ground: .window, code: "RunBlocks { ForEach(runs) { run in RunBlock(run.title, command: run.command, …) } }") {
          RunBlocks {
            ForEach(0..<60, id: \.self) { index in
              RunBlock(
                index % 3 == 0 ? "Test" : "Build", command: index % 3 == 0 ? "swift test" : "swift build",
                id: "day-\(index)", systemImage: index % 3 == 0 ? "testtube.2" : "hammer",
                status: index % 7 == 3 ? .failed("exit 1") : .done, duration: "\(4 + index % 20) s",
                output: index % 7 == 3 ? sampleTestLog : sampleBuildLog)
            }
          }
        }
      }
    }
  }
}

// MARK: - Palette

struct PaletteAction: Identifiable {
  var id: String { title + group }
  var title: String
  var group: String
  var systemImage: String
  var hue: Hue
  var detail: String?
  var note: String?
  var shortcut: String?
}

let paletteActions = [
  PaletteAction(title: "Run", group: "Atlas", systemImage: "play.fill", hue: .green, detail: "xcodebuild -scheme Atlas run", shortcut: "⌘R"),
  PaletteAction(title: "Build", group: "Atlas", systemImage: "hammer", hue: .orange, detail: "xcodebuild -scheme Atlas build", shortcut: "⌘B"),
  PaletteAction(title: "Test", group: "Atlas", systemImage: "testtube.2", hue: .purple, note: "Stops Build first", shortcut: "⌘U"),
  PaletteAction(title: "Clean Build Folder", group: "Atlas", systemImage: "trash", hue: .gray, shortcut: "⇧⌘K"),
  PaletteAction(title: "Deploy to Staging", group: "Release", systemImage: "paperplane", hue: .blue, detail: "release.sh staging"),
  PaletteAction(title: "Tag a Release", group: "Release", systemImage: "tag", hue: .teal, detail: "git tag v1.12.0"),
]

struct PalettePage: View {
  @Environment(\.kitIdiom) private var idiom
  @State private var query = "b"
  @State private var ran: String?
  @State private var scope = "atlas"
  @State private var quickOpen = "tst"
  @State private var showsOverlay = false

  var body: some View {
    CatalogPage(page: .palette) {
      SpecimenSection(
        "KitPalette",
        note: "Type to filter; ↑↓ move through every group's items, Return runs the selected one. The match is in bold."
      ) {
        Specimen(
          "Quick actions",
          code: """
            KitPalette(query: $query, prompt: "Run an action or search", status: .done, dismiss: { isOpen = false }) {
              PaletteMenu("atlas", systemImage: "folder") { Button("atlas") {}; Button("pebble") {} }
            } content: {
              PaletteGroup("Atlas", meta: ["Xcode", "Atlas.xcodeproj"], systemImage: "hammer") {
                PaletteItem("Build", systemImage: "hammer", hue: .orange, detail: "xcodebuild … build", shortcut: "⌘B") { build() }
                PaletteItem("Test", systemImage: "testtube.2", hue: .purple, note: "Stops Build first") { test() }
              }
            }
            """
        ) {
          VStack(alignment: .leading, spacing: 10) {
            palette(status: filtered.isEmpty ? .failed : .done)
              .frame(maxWidth: 600)
            Text(ran.map { "Ran \($0)" } ?? "Nothing run yet").kitFont(.caption)
          }
        }
      }
      SpecimenSection(
        "Quick open", note: "Two-line items with a fuzzy matcher's positions in bold and file icons of their own; the overlay dims the window."
      ) {
        Specimen(
          "Two lines, match offsets, any icon, the overlay",
          code: """
            Workspace()
              .kitPaletteOverlay(isPresented: $showsQuickOpen) {
                KitPalette(query: $query, prompt: "Open Quickly", dismiss: { showsQuickOpen = false }) {
                  PaletteGroup("Files in atlas", meta: ["3 matches"], systemImage: "doc.text.magnifyingglass") {
                    ForEach(results) { result in
                      PaletteItem(result.name, subtitle: result.folder, matches: result.positions,
                                  icon: { FileIcon(result.name) }) { open(result) }
                    }
                  }
                }
              }
            KitPalette(…, focusesOnAppear: false)   // embedded: leave the field unfocused
            """
        ) {
          VStack(alignment: .leading, spacing: 10) {
            quickOpenPalette(focuses: false).frame(maxWidth: 600)
            Button("Show as an Overlay", systemImage: "command") { showsOverlay = true }
              .buttonStyle(.kit)
          }
        }
      }
      SpecimenSection("States") {
        SpecimenGrid(minWidth: 460) {
          Specimen("Running", code: "PaletteItem(\"Build\", systemImage: \"hammer\", status: .working, returnLabel: \"Stop\") { stop() }") {
            KitPalette(query: .constant(""), prompt: "Search", status: .working, hints: [], focusesOnAppear: false) {
              PaletteGroup("Running in atlas", meta: ["Build · 0:42"], systemImage: "bolt", status: .working) {
                PaletteItem("Build", systemImage: "hammer", hue: .orange, detail: "Atlas · Building · 0:42", status: .working, returnLabel: "Stop") {}
                PaletteItem("Deploy", systemImage: "paperplane", hue: .blue, status: .working(progress: 0.3), returnLabel: "Stop") {}
              }
            }
          }
          Specimen("Disabled items, custom hints", code: "PaletteItem(\"Archive\", systemImage: \"archivebox\", isEnabled: false) { … }") {
            KitPalette(query: .constant(""), prompt: "Open Quickly", hints: [PaletteHint(["⌘", "↩"], "Beside"), PaletteHint(["esc"], "Close")], focusesOnAppear: false) {
              PaletteGroup("Files", meta: ["Atlas"], systemImage: "doc") {
                PaletteItem("TripStore.swift", systemImage: "swift", hue: .orange, detail: "Sources/AtlasCore") {}
                PaletteItem("Archive", systemImage: "archivebox", hue: .gray, note: "Needs a release build", isEnabled: false) {}
              }
            }
          }
        }
      }
    }
    .kitPaletteOverlay(isPresented: $showsOverlay) { quickOpenPalette(focuses: true) }
  }

  private func quickOpenPalette(focuses: Bool) -> some View {
    KitPalette(
      query: $quickOpen, prompt: "Open Quickly", status: .done, dismiss: { showsOverlay = false }, focusesOnAppear: focuses
    ) {
      PaletteGroup("Files in atlas", meta: ["3 matches"], systemImage: "doc.text.magnifyingglass", hue: .teal) {
        PaletteItem("TripStore.swift", subtitle: "Sources/AtlasCore", matches: [0, 4, 6], icon: { FileLetterIcon(letter: "S", hue: .orange) }) {
          ran = "TripStore.swift"
          showsOverlay = false
        }
        PaletteItem("TripStoreTests.swift", subtitle: "Tests/AtlasCoreTests", matches: [0, 4, 9], subtitleMatches: [0], icon: { FileLetterIcon(letter: "T", hue: .purple) }) {
          ran = "TripStoreTests.swift"
          showsOverlay = false
        }
        PaletteItem("Trip.swift", systemImage: "swift", hue: .orange, subtitle: "Sources/AtlasCore", matches: [0]) {
          ran = "Trip.swift"
          showsOverlay = false
        }
      }
    }
  }

  private var filtered: [PaletteAction] {
    let q = query.trimmingCharacters(in: .whitespaces)
    return q.isEmpty ? paletteActions : paletteActions.filter { $0.title.localizedCaseInsensitiveContains(q) }
  }

  private func palette(status: WorkStatus) -> some View {
    // On touch the keyboard would open with the page, so the embedded palette waits for a tap.
    KitPalette(
      query: $query, prompt: "Run an action or search", status: query.isEmpty ? .idle : status, dismiss: { query = "" },
      focusesOnAppear: !idiom.isTouch
    ) {
      PaletteMenu(scope, systemImage: "folder") {
        ForEach(["atlas", "beacon", "pebble"], id: \.self) { name in Button(name) { scope = name } }
      }
    } content: {
      let groups = Array(Set(filtered.map(\.group))).sorted()
      ForEach(groups, id: \.self) { group in
        PaletteGroup(group, meta: group == "Atlas" ? ["Xcode", "Atlas.xcodeproj"] : ["release.sh"], systemImage: group == "Atlas" ? "hammer" : "paperplane") {
          if group == "Atlas" {
            PaletteMenu("Atlas", systemImage: "hammer") { Button("Atlas") {}; Button("AtlasKit") {} }
          }
        } items: {
          ForEach(filtered.filter { $0.group == group }) { action in
            PaletteItem(action.title, systemImage: action.systemImage, hue: action.hue, detail: action.detail, note: action.note, shortcut: action.shortcut) {
              ran = action.title
            }
          }
        }
      }
      if filtered.isEmpty {
        Text("No actions match “\(query)”").kitFont(.callout).foregroundStyle(.kitSecondary).padding(20)
      }
    }
  }
}

// MARK: - Welcome

struct WelcomePage: View {
  private func matches(_ name: String) -> Bool { search.isEmpty || name.localizedCaseInsensitiveContains(search) }

  @State private var show = true
  @State private var opened: String?
  @State private var search = ""
  @State private var source = WelcomeSource.projects
  @State private var reopen = true

  var body: some View {
    CatalogPage(page: .welcome, maxWidth: 1100) {
      SpecimenSection(
        "The welcome window", note: "↑↓ move through the items, Return or a double click opens one. Drop a folder on the window."
      ) {
        Columns(minWidth: 980) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Recent").kitFont(.headline)
            WindowFrame(height: 640) {
              KitWelcome(
                appName: "Git", version: "Version 1.0", icon: AppIcon.image(systemImage: "arrow.triangle.branch", hue: .orange), showAtLaunch: $show,
                searchText: $search, searchPrompt: "Filter", close: {},
                onDrop: { urls in
                  opened = urls.first?.lastPathComponent
                  return true
                }
              ) {
                WelcomeAction("Clone Repository…", detail: "From GitHub, GitLab or any URL", systemImage: "arrow.down") {}
                WelcomeAction("Open Local Repository…", detail: "Any folder with a .git directory", systemImage: "folder") {}
                WelcomeAction("New Repository…", detail: "Start tracking a folder", systemImage: "plus") {}
              } recents: {
                if matches("pebble") { RecentItem("pebble", subtitle: "~/Developer/Projects/pebble", date: "Today", status: "Up to date", statusHue: .green) { opened = "pebble" } }
                if matches("harbor") { RecentItem("harbor", subtitle: "~/Developer/Projects/harbor", date: "Today", status: "1 change", statusHue: .orange) { opened = "harbor" } }
                if matches("atlas") { RecentItem("atlas", subtitle: "~/Developer/Projects/atlas", date: "Yesterday", status: "4 changes", statusHue: .orange) { opened = "atlas" } }
                if matches("lighthouse") { RecentItem("lighthouse", subtitle: "~/Developer/Archive/2025/lighthouse-for-the-harbor-project", date: "Oct 2") { opened = "lighthouse" } }
              }
              .options { Toggle("Reopen the last repository", isOn: $reopen) }
            }
            .frame(maxWidth: 480)
            Text("Opened: \(opened ?? "nothing")").kitFont(.caption)
          }
          VStack(alignment: .leading, spacing: 8) {
            Text("Empty, with projects").kitFont(.headline)
            WindowFrame(height: 560) {
              KitWelcome(
                appName: "Markdown", version: "Notes in plain Markdown files", icon: AppIcon.image(systemImage: "text.alignleft", hue: .red),
                showAtLaunch: $show,
                emptyTitle: "No Recent Notes", emptyMessage: "Notes you open appear here.", source: $source, close: {}
              ) {
                WelcomeAction("New Note", detail: "Start writing", systemImage: "square.and.pencil") {}
              } recents: {
                EmptyView()
              } projects: {
                RecentItem("Notes", subtitle: "~/Notes", systemImage: "folder") {}
                RecentItem("Journal", subtitle: "~/Documents/Journal", systemImage: "book") {}
              }
            }
            .frame(maxWidth: 480)
          }
          VStack(alignment: .leading, spacing: 8) {
            Text("Waiting, with its own list title").kitFont(.headline)
            WindowFrame(height: 560) {
              KitWelcome(
                appName: "Vault", version: "Passwords, encrypted folders and sync", icon: AppIcon.image(systemImage: "lock.rectangle.stack", hue: .blue),
                showAtLaunch: $show, emptyTitle: "Waiting for Your Keys",
                emptyMessage: "They arrive through iCloud Keychain from your other Apple devices.", close: {}
              ) {
                WelcomeAction("Recover with Key…", detail: "Type your 24 words or scan the kit’s QR code", systemImage: "key") {}
                WelcomeAction("Join from Another Device…", detail: "Scan an invite on a device that has your keys", systemImage: "qrcode") {}
              } recents: {
                EmptyView()
              }
              .listTitle("This Mac")
              .emptyState(systemImage: "key", status: .working)
            }
            .frame(maxWidth: 480)
          }
        }
        CodeSnippet(
          """
          KitWelcome(showAtLaunch: $showAtLaunch, searchText: $filter, close: { dismissWindow() }, onDrop: { library.open($0) }) {
            WelcomeAction("Clone Repository…", detail: "From GitHub, GitLab or any URL", systemImage: "arrow.down") { … }
          } recents: {
            ForEach(recent.filter(matching: filter)) { repo in
              RecentItem(repo.name, subtitle: repo.path, date: "Today", status: "1 change", statusHue: .orange) { open(repo) }
            }
          }
          .options { Toggle("Reopen the last repository", isOn: $reopen) }   // above "Show this window…"

          @AppStorage("welcome.source") var source = WelcomeSource.recent
          KitWelcome(…, source: $source, …) { … } recents: { … } projects: { … }   // Recent | Projects, remembered
          // With close:, the window's own buttons hide while the welcome fills its window; on iPhone it fills the width.
          KitWelcome(emptyTitle: "Waiting for Your Keys", …) { … } recents: { … }
            .listTitle("Already in your vault")                       // in place of "Recent"
            .emptyState(systemImage: "key", status: .working)         // a live icon over the empty list
          """)
      }
    }
  }
}

// MARK: - Settings

struct SettingsPage: View {
  @State private var pane = "General"
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    CatalogPage(page: .settings, maxWidth: 1100) {
      SpecimenSection("KitSettings", note: "The app's panes first, then the shared ones under their section. ↑↓ move through the panes. On iPhone the panes are rows with their value, and a row pushes its pane.") {
        WindowFrame(height: 520) {
          // On iPhone a pane pushes on the stack around the settings.
          if idiom == .phone {
            NavigationStack { SampleSettings(selection: $pane) }
          } else {
            SampleSettings(selection: $pane)
          }
        }
        CodeSnippet(
          """
          KitSettings(selection: $pane) {
            SettingsPane("General", systemImage: "gearshape") { FormCard { … } }
            SettingsPane("Updates", systemImage: "arrow.down.circle", hue: .blue, section: "v57", value: "Daily") { UpdatesSettings() }
            SettingsPane("About", systemImage: "info.circle", section: "v57") { AboutSettings() }
          }
          """)
      }
      SpecimenSection("In a Settings scene", note: "Say what the window looks like; the kit lays the sidebar and the title row out for it.") {
        VStack(alignment: .leading, spacing: 12) {
          VStack(alignment: .leading, spacing: 6) {
            Text("A standard titled window").kitFont(.headline)
            WindowFrame(height: 340) { SampleSettings(selection: $pane, window: .titled) }
              .frame(maxWidth: 680)
          }
          CodeSnippet(
            """
            Settings {
              KitSettings(selection: $pane, window: .titled) { … }.componentKit()
            }

            Settings {
              KitSettings(selection: $pane, window: .hiddenTitleBar) { … }.componentKit()
            }
            .windowStyle(.hiddenTitleBar)   // the sidebar runs up under the window's buttons
            """)
        }
      }
    }
  }
}

/// A file icon drawn as a letter on a hue, like Code's: what a custom icon view in a palette, tab or path looks like.
struct FileLetterIcon: View {
  var letter: String
  var hue: Hue
  var size: CGFloat = 20

  var body: some View {
    Text(letter)
      .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(hue.fill, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
  }
}

/// Settings made of kit pieces only, shared by the Settings page and scenario.
struct SampleSettings: View {
  @Binding var selection: String
  var window: KitSettingsWindow = .framed
  @State private var showWelcome = true
  @State private var wrap = true
  @State private var fontSize = 13
  @State private var theme = "Auto"
  @State private var autoUpdate = true
  @State private var sync = true
  @State private var check: WorkStatus = .idle

  var body: some View {
    KitSettings(selection: $selection, window: window) {
      SettingsPane("General", systemImage: "gearshape") {
        FormCard {
          FormRow("Show the welcome window", help: "When the app opens with nothing", systemImage: "macwindow", hue: .blue) {
            Toggle("Show the welcome window", isOn: $showWelcome).labelsHidden().toggleStyle(.kitSwitch)
          }
          FormRow("Appearance", systemImage: "circle.lefthalf.filled", hue: .indigo) {
            KitSegmented(selection: $theme, options: [("Auto", "Auto"), ("Light", "Light"), ("Dark", "Dark")])
          }
        }
      }
      SettingsPane("Editor", systemImage: "character.cursor.ibeam", hue: .orange) {
        FormCard("Text") {
          FormRow("Font size", systemImage: "textformat.size", hue: .orange) {
            KitStepper("Font size", value: $fontSize, in: 9...24, unit: "pt")
          }
          FormRow("Wrap lines", help: "At the window's edge", systemImage: "text.word.spacing", hue: .teal) {
            Toggle("Wrap lines", isOn: $wrap).labelsHidden().toggleStyle(.kitSwitch)
          }
        }
      }
      SettingsPane("Updates", systemImage: "arrow.down.circle", hue: .blue, section: "v57", value: autoUpdate ? "Daily" : "Off") {
        FormCard(footer: "Updates come from GitHub Releases. Nothing is checked unless you turn it on.") {
          FormRow("Check automatically", help: "Once a day", systemImage: "clock.arrow.circlepath", hue: .blue) {
            Toggle("Check automatically", isOn: $autoUpdate).labelsHidden().toggleStyle(.kitSwitch)
          }
          FormRow("Version 1.0", help: check == .done ? "Up to date" : "Last checked yesterday", systemImage: "info.circle", hue: .gray) {
            Button("Check Now") {
              check = .working
              Task {
                try? await Task.sleep(for: .seconds(1.5))
                check = .done
              }
            }
            .buttonStyle(.kit)
          }
        }
        if check != .idle {
          Banner(check == .done ? "Component is up to date." : "Checking for updates…", systemImage: "arrow.down.circle", hue: check == .done ? .green : .blue)
        }
      }
      SettingsPane("iCloud", systemImage: "icloud", hue: .teal, section: "v57", value: sync ? "On" : "Off") {
        FormCard("Devices", footer: "Shared by Git, Shell, Database, Markdown, Code and Dev.") {
          FormRow("Sync with iCloud", help: "Projects, hosts and notes", systemImage: "icloud", hue: .teal) {
            Toggle("Sync with iCloud", isOn: $sync).labelsHidden().toggleStyle(.kitSwitch)
          }
          FormRow("This Mac", help: "Key in the Secure Enclave", systemImage: "laptopcomputer", hue: .gray)
        }
      }
      SettingsPane("About", systemImage: "info", section: "v57") {
        HStack(spacing: 14) {
          Avatar(name: "Component", kind: .app, systemImage: "square.stack.3d.up", size: 56)
          VStack(alignment: .leading, spacing: 2) {
            Text("Component").kitFont(.title2)
            Text("Version 1.0 · MIT license").kitFont(.callout).foregroundStyle(.kitSecondary)
          }
        }
      }
    }
  }
}

// MARK: - Meters and lanes

struct MetersPage: View {
  @State private var cpu = 0.32
  @State private var selectedTask = "#5"

  let parts = [
    MeterSegment("Development", value: 214.2, hue: .blue, systemImage: "hammer", valueText: "214.2 GB"),
    MeterSegment("AI", value: 96.5, hue: .purple, systemImage: "brain", valueText: "96.5 GB"),
    MeterSegment("Applications", value: 158, hue: .orange, systemImage: "shippingbox", valueText: "158.0 GB"),
    MeterSegment("CI", value: 22.3, hue: .indigo, systemImage: "server.rack", valueText: "22.3 GB"),
    MeterSegment("Logs", value: 0.4, hue: .gray, systemImage: "doc.text", valueText: "0.4 GB"),
  ]

  var body: some View {
    CatalogPage(page: .meters) {
      SpecimenSection("Meters") {
        SpecimenGrid(minWidth: 380) {
          Specimen(
            "MeterBar and MeterLegend", ground: .panel,
            code: "MeterBar(segments: parts, total: 994.7)\nMeterLegend(segments: parts, free: MeterSegment(\"Free\", value: 382.3, hue: .gray))"
          ) {
            VStack(alignment: .leading, spacing: 10) {
              RichHeader("Storage", meta: ["Macintosh HD", "scanning, 1,204 files"], systemImage: "internaldrive", status: .working)
              MeterBar(segments: parts, total: 994.7)
              MeterLegend(segments: parts, free: MeterSegment("Free", value: 382.3, hue: .gray, systemImage: "circle.dashed", valueText: "382.3 GB"))
            }
            .kitCard(padding: 10)
          }
          Specimen("Meter tiles", ground: .panel, code: "MeterTile(\"CPU\", value: \"32%\", systemImage: \"cpu\", progress: 0.32)") {
            VStack(alignment: .leading, spacing: 12) {
              HStack(spacing: 16) {
                MeterTile("CPU", value: "\(Int(cpu * 100))%", systemImage: "cpu", progress: cpu)
                MeterTile("GPU", value: "36%", systemImage: "gauge.medium", hue: .purple, progress: 0.36)
              }
              HStack(spacing: 16) {
                MeterTile("Scanning", value: "1,204", systemImage: "magnifyingglass", progress: nil)
                MeterTile("Scan", value: "Done", systemImage: "magnifyingglass", hue: .green, status: .done)
              }
              KitSlider("CPU", value: $cpu).frame(maxWidth: 220)
            }
          }
        }
      }
      SpecimenSection("Lanes", note: "Board columns: cards like a sidebar's sections, their tasks as rows.") {
        Specimen(
          "Lane and LaneItem",
          code: """
            LaneBoard {
              Lane("Running", count: 2, meta: ["2 agents", "1 failing"], systemImage: "bolt", status: .working) {
                LaneItem("#5 Damage-state sprites", subtitle: "artist · 3 of 8", isSelected: true) { Avatar(…) }
              }
            }
            """
        ) {
          LaneBoard {
            Lane("Queued", count: 1, meta: ["waiting on #5"], systemImage: "tray", hue: .gray) {
              LaneItem("#7 Sound effects", subtitle: "Needs #5")
            }
            Lane("Running", count: 2, meta: ["2 agents", "1 failing"], systemImage: "bolt", status: .working) {
              Button("Add Task", systemImage: "plus") {}
            } items: {
              Button { selectedTask = "#5" } label: {
                LaneItem("#5 Damage-state sprites", subtitle: "artist · 3 of 8 sprites", isSelected: selectedTask == "#5") {
                  Avatar(name: "artist", kind: .agent, status: .working(progress: 0.38))
                }
              }
              .buttonStyle(.plain)
              Button { selectedTask = "#3" } label: {
                LaneItem("#3 Stone walls", subtitle: "tester: Test failed, crashed on launch", subtitleHue: .red, isSelected: selectedTask == "#3") {
                  Avatar(name: "coder-1", kind: .agent, status: .failed)
                }
              }
              .buttonStyle(.plain)
            }
            Lane("Done", count: 3, meta: ["3 today"], systemImage: "checkmark", hue: .green, status: .done) {
              LaneItem("#1 Wall defs") { Image(systemName: "checkmark.circle.fill").foregroundStyle(Hue.green.fill) }
              LaneItem("#9 Mod settings page") { Image(systemName: "checkmark.circle.fill").foregroundStyle(Hue.green.fill) }
              LaneItem("#2 Fog of war") { Image(systemName: "checkmark.circle.fill").foregroundStyle(Hue.green.fill) }
            }
          }
          .scrollIndicators(.never)
        }
      }
    }
  }
}

// MARK: - Secrets & Codes

struct SecretsPage: View {
  @State private var revealed = false
  @State private var scanning = false
  @State private var scanned: String?
  @State private var screenCodes: [String] = []
  @State private var mineChoice: String?
  @State private var selection: Set<String> = ["Estimated payments.numbers"]

  /// A stand-in for a TOTP: six digits that change every 30 seconds (the catalog has no secret to hash).
  private static func sampleCode(_ date: Date) -> String {
    let step = UInt64(date.timeIntervalSince1970 / 30)
    let mixed = (step &* 0x9E37_79B9_7F4A_7C15) >> 32
    return String(format: "%06d", Int(mixed % 1_000_000))
  }

  private static let words = [
    "orbit", "lantern", "maple", "fossil", "cradle", "velvet", "harbor", "ember", "quiet", "saddle", "tundra", "pixel",
    "anchor", "willow", "copper", "meadow", "falcon", "riddle", "summit", "pebble", "canyon", "violet", "thimble", "glacier",
  ]

  private struct SampleFile: Identifiable {
    var name: String
    var isFolder = false
    var size: String
    var modified: String
    var id: String { name }
  }

  private static let files = [
    SampleFile(name: "Receipts", isFolder: true, size: "64 items", modified: "Oct 18"),
    SampleFile(name: "2025 Return.pdf", size: "2.4 MB", modified: "Apr 11"),
    SampleFile(name: "Estimated payments.numbers", size: "412 KB", modified: "Today, 9:14 AM"),
    SampleFile(name: "Home office.heic", size: "3.8 MB", modified: "Sep 12"),
    SampleFile(name: "Accountant notes.md", size: "8 KB", modified: "Sep 9"),
    SampleFile(name: "IMG_2293.mov", size: "84 MB", modified: "Oct 19"),
  ]

  var body: some View {
    CatalogPage(page: .secrets) {
      SpecimenSection(
        "Secrets", note: "Dots until shown: always sixteen, so they don't tell the length. The value is read only when shown or copied, and Copy keeps it on this device for 90 seconds."
      ) {
        SpecimenGrid(minWidth: 340) {
          Specimen(
            "In an inspector", ground: .panel,
            code: "InspectorRow(\"Password\") { KitSecretValue { VaultSecrets.password(for: login.id) } }"
          ) {
            VStack(spacing: 0) {
              InspectorRow("Username", value: "aiko")
              InspectorRow("Password") { KitSecretValue("vT7q-Lm2x-9KpR-wd4Z") }
              InspectorRow("Token") { KitSecretValue("ghp_4f1c09e2b7a9", label: "Token", copies: false) }
            }
            .kitCard()
          }
          Specimen("Shown from outside", code: "KitSecretValue(isRevealed: $revealed) { password }") {
            VStack(alignment: .leading, spacing: 10) {
              KitSecretValue("vT7q-Lm2x-9KpR-wd4Z", isRevealed: $revealed)
              Toggle("Show passwords", isOn: $revealed).toggleStyle(.kitSwitch)
            }
          }
        }
      }
      SpecimenSection(
        "One-time codes", note: "The live icon's ring empties as the code runs out, orange in its last five seconds. The view ticks every second and asks the app for the code of that moment."
      ) {
        SpecimenGrid(minWidth: 340) {
          Specimen("With seconds", code: "KitOneTimeCode(period: 30) { totp.code(at: $0) }") {
            KitOneTimeCode { Self.sampleCode($0) }
          }
          Specimen("Narrow, and waiting for its secret", code: "KitOneTimeCode(showsSeconds: false) { _ in nil }") {
            VStack(alignment: .leading, spacing: 12) {
              KitOneTimeCode(showsSeconds: false) { Self.sampleCode($0) }
              KitOneTimeCode(showsSeconds: false) { _ in nil }
            }
          }
        }
      }
      SpecimenSection(
        "Safety codes and QR codes",
        note: "Two people compare the safety code to rule out a swapped key. The QR plate stays white in dark mode: scanners need the light ground."
      ) {
        SpecimenGrid(minWidth: 340) {
          Specimen("Safety code", code: "KitSafetyCode(code)\nKitSafetyCode(code).controlSize(.small)") {
            VStack(alignment: .leading, spacing: 12) {
              KitSafetyCode("482109375512067304187729105536641028931722740519834062518874")
              KitSafetyCode("603919375512067304187729128814641028931722740519834062518874").controlSize(.small)
            }
          }
          Specimen("QR code", code: "KitQRCode(invite.link)") {
            HStack(alignment: .top, spacing: 16) {
              KitQRCode("v57vault://invite?id=v57id:Q2hhbmdlIHRoaXMgaW52aXRlIGlmIHlvdSByZWFkIGl0&name=Rafael", size: 140)
              KitQRCode("otpauth://totp/Atlas:aiko?secret=JBSWY3DPEHPK3PXP", size: 80)
            }
          }
        }
        Specimen("Recovery words", code: "KitWordGrid(recoveryKey.words)") {
          KitWordGrid(Self.words)
        }
      }
      SpecimenSection(
        "Reading codes",
        note: "The camera, a picture, or (on the Mac) the screen. Each asks for its permission the first time it's used, and only then."
      ) {
        SpecimenGrid(minWidth: 340) {
          Specimen("Camera", code: "KitQRScanner { text in accept(text) }.frame(height: 240)") {
            VStack(alignment: .leading, spacing: 10) {
              if scanning {
                KitQRScanner { scanned = $0 }.frame(height: 220)
              }
              HStack {
                Button(scanning ? "Stop" : "Scan with Camera", systemImage: "qrcode.viewfinder") { scanning.toggle() }
                  .buttonStyle(.kit)
                Text(scanned ?? "Nothing scanned yet").kitFont(.caption).lineLimit(2)
              }
            }
          }
          Specimen("Screen and pictures", code: "try await KitQRReader.codesOnScreen()\nKitQRReader.codes(inImageData: data)") {
            VStack(alignment: .leading, spacing: 10) {
              Button("Scan Screen", systemImage: "rectangle.dashed") {
                Task { screenCodes = (try? await KitQRReader.codesOnScreen()) ?? ["Not allowed"] }
              }
              .buttonStyle(.kit)
              .disabled(!KitQRReader.canScanScreen)
              Text(screenCodes.isEmpty ? "Codes on screen appear here" : screenCodes.joined(separator: "\n")).kitFont(.caption)
            }
          }
        }
      }
      SpecimenSection("Previews", note: "A file shown from bytes the app already has (an encrypted folder's sealed chunks): nothing plain is written.") {
        SpecimenGrid(minWidth: 300) {
          Specimen("Text", code: "KitFilePreview(name: entry.name, data: try folder.read(entry.path))") {
            KitFilePreview(name: "Colors.json", data: Data(##"{ "accent": "#007AFF", "teal": "#59ADC4" }"##.utf8)).frame(height: 140)
          }
          Specimen("No preview", code: "KitFilePreview(name: \"Moodboard.fig\", data: data)") {
            KitFilePreview(name: "Moodboard.fig", data: Data(count: 18_200)).frame(height: 140)
          }
        }
      }
      SpecimenSection("Files", note: "A file's kind from its extension: folders teal, files quiet, the name shortened in the middle.") {
        Specimen(
          "In a grid", padding: 8,
          code: "KitGridColumn<FileItem>(\"Name\", width: 300) { KitFileCell($0.name, isFolder: $0.isFolder) }"
        ) {
          KitGrid(
            Self.files,
            columns: [
              KitGridColumn("Name", width: 280) { KitFileCell($0.name, isFolder: $0.isFolder) },
              KitGridColumn("Size", width: 90, alignment: .trailing) { $0.size },
              KitGridColumn("Modified", width: 140) { $0.modified },
            ],
            selection: $selection
          )
          .frame(height: 270)
        }
      }
      SpecimenSection(
        "Text conflicts",
        note: "Two copies of a text file side by side, the changed words in bold. The section's header carries the choice."
      ) {
        Specimen(
          "Mine and Remote", ground: .panel,
          code: "TextConflict(mine: ConflictSide(\"Mine\", ref: \"Studio Mac · 10:12 AM\", code: mine),\n             theirs: ConflictSide(\"Remote\", ref: \"Jonas · MacBook Air · 10:40 AM\", code: remote))"
        ) {
          KitSection(
            mineChoice ?? "Selects.txt",
            meta: ["changed here and on MacBook Air", "your edit is kept until you choose"],
            systemImage: "exclamationmark.triangle", hue: .purple
          ) {
            TextConflict(
              mine: ConflictSide("Mine", ref: "Studio Mac · 10:12 AM", code: "IMG_2201 cover\nIMG_2214 tram, cropped\nIMG_2230 night"),
              theirs: ConflictSide(
                "Remote", ref: "Jonas · MacBook Air · 10:40 AM", code: "IMG_2201 cover\nIMG_2214 tram\nIMG_2251 river")
            )
            .padding([.horizontal, .bottom], 6)
          } accessory: {
            HStack(spacing: 6) {
              Button("Keep Mine") { mineChoice = "Kept mine" }.buttonStyle(.kit).controlSize(.small)
              Button("Revert to Remote") { mineChoice = "Reverted to remote" }.buttonStyle(.kitPrimary).controlSize(.small)
            }
          }
        }
      }
    }
  }
}
