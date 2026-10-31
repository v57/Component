import ComponentKit
import SwiftUI

// Specimens for the gaps the apps reported while moving onto the kit (2026-10-31): each page shows them in a section
// of its own, after its other sections.

// MARK: - Forms: stacked rows, a line under a row, title chips, a field with a control, tile status, headings, rings

struct FormGapSpecimens: View {
  @State private var size = 24.0
  @State private var width = "Normal"
  @State private var formatOnSave = true
  @State private var needsConfig = true
  @State private var command = ""
  @State private var address = "ws://atlas.local:1997"
  @State private var engine = "PostgreSQL"
  @State private var step = 1

  var body: some View {
    SpecimenSection(
      "More rows",
      note: "A stacked row puts its control under the title, full width (the value at the end); .detail puts a line "
        + "of small controls under a row; .titleAccessory a chip after the title; a field row can keep a control at "
        + "its end; status: makes the tile the live icon."
    ) {
      SpecimenGrid(minWidth: 340) {
        Specimen(
          "Stacked",
          code: """
            FormCard {
              FormRow("Size", value: "\\(Int(size)) pt") { KitSlider("Size", value: $size, in: 12...48, step: 1) }
              FormRow("Width") { KitSegmented(selection: $width, options: widths).kitSegmentedStyle(.wide) }
            }
            """
        ) {
          FormCard {
            FormRow("Size", value: "\(Int(size)) pt") {
              KitSlider("Size", value: $size, in: 12...48, step: 1, format: { "\(Int($0)) pt" })
            }
            FormRow("Width") {
              KitSegmented(selection: $width, options: ["Narrow", "Normal", "Wide"].map { ($0, $0) })
                .kitSegmentedStyle(.wide)
            }
            FormRow("Speed", value: "1.5×", systemImage: "gauge.with.dots.needle.67percent", hue: .orange) {
              KitSlider("Speed", value: .constant(1.5), in: 0.5...3)
            }
          }
        }
        Specimen(
          "detail, titleAccessory, status",
          code: """
            FormRow("swift-format", help: "Swift", systemImage: "text.alignleft", hue: .orange) { Toggle(…) }
              .detail {
                Toggle("Only with a config file", isOn: $needsConfig).toggleStyle(.kitCheckbox).fixedSize()
                Spacer(minLength: 0)
                TextField("Custom command", text: $command).kitField(mono: true).frame(width: 160)
              }
            FormRow(machine.name, help: "macOS", systemImage: "laptopcomputer") { StatusLabel(…) }
              .titleAccessory { Chip("Primary", hue: .accent) }
            FormRow("ruff", help: "Installing…", systemImage: "text.alignleft", status: .working) { … }
            """
        ) {
          FormCard {
            FormRow("swift-format", help: "Swift · /usr/bin/swift-format", systemImage: "text.alignleft", hue: .orange) {
              Toggle("swift-format", isOn: $formatOnSave).toggleStyle(.kitSwitch).kitLabelsHidden()
            }
            .detail {
              Toggle("Only with a config file", isOn: $needsConfig).toggleStyle(.kitCheckbox).fixedSize()
              Spacer(minLength: 0)
              TextField("Custom command", text: $command).kitField(mono: true).frame(width: 140)
            }
            FormRow("Studio Mac", help: "macOS · 3 agents", systemImage: "laptopcomputer") {
              StatusLabel("Online", hue: .green)
            }
            .titleAccessory { Chip("Primary", hue: .accent) }
            FormRow("ruff", help: "Installing with pipx…", systemImage: "text.alignleft", hue: .orange, status: .working) {
              Toggle("ruff", isOn: .constant(true)).toggleStyle(.kitSwitch).kitLabelsHidden()
            }
          }
        }
        Specimen(
          "A field and a control",
          code: """
            FormRow("Address", help: "ws://host:port", systemImage: "network", hue: .green,
                    field: TextField("Address", text: $address)) {
              Button("Connect") { … }.buttonStyle(.kitPrimary)
            }
            """
        ) {
          FormCard {
            FormRow(
              "Address", help: "ws://host:port", systemImage: "network", hue: .green,
              field: TextField("Address", text: $address)
            ) {
              Button("Connect") {}.buttonStyle(.kitPrimary)
            }
          }
        }
      }
    }
    SpecimenSection(
      "Headings and selected cards",
      note: "FormHeading titles a group that isn't a FormCard (choice cards) as a FormCard's title sits; "
        + ".kitSelectedRing gives a card of your own the ring a picked choice card wears."
    ) {
      SpecimenGrid(minWidth: 340) {
        Specimen(
          "FormHeading",
          code: """
            VStack(alignment: .leading, spacing: 8) {
              FormHeading("Database")
              LazyVGrid(columns: columns, spacing: KitMetrics.gutter) { ChoiceCard(…) }
            }
            """
        ) {
          VStack(alignment: .leading, spacing: 8) {
            FormHeading("Database")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: KitMetrics.gutter)], spacing: KitMetrics.gutter) {
              ForEach([("PostgreSQL", "PG", Hue.blue), ("SQLite", "SQ", Hue.teal)], id: \.0) { name, letters, hue in
                ChoiceCard(
                  name, subtitle: "Port 5432", letters: letters, hue: hue,
                  isOn: Binding(get: { engine == name }, set: { if $0 { engine = name } }))
              }
            }
            FormCard("Connection") {
              FormRow("Host", help: "localhost", systemImage: "server.rack", hue: .gray)
            }
          }
        }
        Specimen(
          "kitSelectedRing",
          code: """
            StepCard(step)
              .kitSurface(.card)
              .kitSelectedRing(step.id == selection)
            """
        ) {
          VStack(spacing: KitMetrics.gutter) {
            ForEach(Array(["$match", "$project", "$group"].enumerated()), id: \.offset) { index, name in
              HStack {
                Text(name).kitFont(.mono)
                Spacer()
                Text("Step \(index + 1)").kitFont(.caption)
              }
              .padding(12)
              .kitSurface(.card)
              .kitSelectedRing(step == index)
              .onTapGesture { withKitAnimation { step = index } }
            }
          }
          .padding(4)
        }
      }
    }
  }
}

// MARK: - Sections: empty state, header help

struct SectionGapSpecimens: View {
  @State private var projects: [String] = []

  var body: some View {
    SpecimenSection(
      "Empty sections and header help",
      note: ".emptyState shows a quiet line (or any view) where the rows go while the section has none; .headerHelp "
        + "gives the header a tooltip of its own, so the rows keep theirs."
    ) {
      SpecimenGrid(minWidth: 280) {
        Specimen(
          "emptyState(_:)", ground: .sidebar,
          code: """
            KitSection("Projects", meta: "On your devices", systemImage: "folder") {
              ForEach(shown) { SidebarRow(value: $0.id, $0.name, systemImage: "folder") }
            }
            .emptyState("Nothing matches “atl”.", systemImage: "magnifyingglass")
            """
        ) {
          VStack(spacing: 8) {
            KitSection("Projects", meta: "On your devices", systemImage: "folder", hue: .orange) {
              ForEach(projects, id: \.self) { SidebarRow(value: $0, $0, systemImage: "folder") }
            }
            .emptyState("Nothing matches “atl”.", systemImage: "magnifyingglass")
            KitSection("Sources", meta: "Plain", systemImage: "folder") {
              ForEach(projects, id: \.self) { SidebarRow(value: $0, $0, systemImage: "doc") }
            }
            .emptyState("No files yet.")
            .kitSectionStyle(.plain)
          }
        }
        Specimen(
          "emptyState { }", ground: .sidebar,
          code: """
            KitSection("Remotes", systemImage: "cloud") { … }
              .emptyState {
                EmptyState(systemImage: "cloud", title: "No Remotes") { Button("Add Remote…") { … } }
              }
            """
        ) {
          KitSection("Remotes", meta: "None", systemImage: "cloud", hue: .blue) {
            ForEach(projects, id: \.self) { SidebarRow(value: $0, $0, systemImage: "cloud") }
          }
          .emptyState {
            EmptyState(systemImage: "cloud", title: "No Remotes", message: "Push to share this repository.") {
              Button("Add Remote…") {}.buttonStyle(.kit)
            }
            .frame(height: 180)
          }
        }
        Specimen(
          "headerHelp", note: "Hover the header", ground: .sidebar,
          code: """
            KitSection("Notes", meta: ["12 notes", "iCloud"], systemImage: "note.text") { … }
              .headerHelp("Notes", meta: "Files in iCloud Drive, encrypted.")
            """
        ) {
          KitSection("Notes", meta: ["12 notes", "iCloud"], systemImage: "note.text", hue: .yellow) {
            SidebarRow(value: "all", "All Notes", systemImage: "note.text") { Text("12") }
              .kitHelp("All Notes", meta: "Every note, newest first")
          }
          .headerHelp("Notes", meta: "Files in iCloud Drive, encrypted.", systemImage: "icloud")
        }
      }
    }
  }
}

// MARK: - Sidebar: push chevrons, nested rows in an outline, flat outlines, pushing from a list

struct SidebarGapSpecimens: View {
  struct Node: Identifiable {
    var id: String
    var children: [Node]?
  }

  @State private var selection: String?
  @State private var listSelection: Int?
  @State private var pushed: Int?
  @State private var opened = "None"
  private let grouped = [
    Node(id: "Apps", children: [Node(id: "Atlas", children: nil), Node(id: "Harbor", children: nil)]),
    Node(id: "Beacon", children: nil),
  ]
  private let flat = [Node(id: "Atlas", children: nil), Node(id: "Beacon", children: nil), Node(id: "Harbor", children: nil)]

  var body: some View {
    SpecimenSection(
      "Rows that push",
      note: ".pushes() trails a row with the push chevron (KitPushChevron): always for a row with an action, only on "
        + "iPhone for a row that selects (selecting pushes there). Switch the idiom to iPhone to see the second."
    ) {
      SpecimenGrid(minWidth: 280) {
        Specimen(
          "pushes()", note: "opened: \(opened)", ground: .sidebar,
          code: """
            SidebarRow("Sources", systemImage: "folder").pushes().action { pushed = folder }
            SidebarRow(value: project.id, project.name, systemImage: "shippingbox").pushes()   // iPhone only
            GroupRow("Appearance", action: { … }) { KitPushChevron() }
            """
        ) {
          VStack(spacing: 8) {
            KitSection("Atlas", meta: "On build-mac", systemImage: "folder", hue: .orange) {
              SidebarRow("Sources", systemImage: "folder").pushes().action { opened = "Sources" }
              SidebarRow("Package.swift", systemImage: "swift").pushes().action { opened = "Package.swift" }
              SidebarRow(value: "atlas", "Selects (iPhone: pushes)", systemImage: "shippingbox").pushes()
            }
            FormCard {
              GroupRow("Appearance", action: { opened = "Appearance" }) { KitPushChevron() }
            }
          }
        }
        Specimen(
          "Rows inside an outline item",
          note: "Before: the nested rows showed the item's empty chevron slot", ground: .sidebar,
          code: """
            KitOutline(projects, children: \\.children) { project in
              SidebarRow(project.name, systemImage: "folder")
              ForEach(project.notes) { SidebarRow($0.title, systemImage: "doc.text").kitRowIndent(1) }  // no slot
            }
            SidebarRow(note.title, systemImage: "doc.text").disclosureSlot(false)   // or per row
            """
        ) {
          KitSection("Projects", meta: "1 group", systemImage: "square.stack", hue: .indigo) {
            KitOutline(grouped, children: \.children) { node in
              SidebarRow(value: node.id, node.id, systemImage: node.children == nil ? "shippingbox" : "folder")
              if node.id == "Beacon" {
                SidebarRow(value: "Beacon/README", "README.md", systemImage: "doc.text").kitRowIndent(1)
                SidebarRow(value: "Beacon/Notes", "Notes", systemImage: "folder").kitRowIndent(1)
              }
            }
          }
        }
        Specimen(
          "A flat outline", note: "No item opens: no slots", ground: .sidebar,
          code: """
            KitOutline(tree.roots, children: { $0.group == nil ? nil : $0.children }, collapsed: $closed) { … }
            // with no groups the projects line up as a plain list's
            """
        ) {
          KitSection("Projects", meta: "No groups", systemImage: "square.stack", hue: .indigo) {
            KitOutline(flat, children: \.children) { node in
              SidebarRow(value: node.id, node.id, systemImage: "shippingbox")
            }
          }
        }
      }
    }
    SpecimenSection(
      "Pushing from a list",
      note: "A KitList in a split view's detail column on iPhone: rows push only with a NavigationStack around the "
        + "detail (a NavigationSplitView's detail has none of its own; the catalog's has one on iOS). A selected row "
        + "pushes through navigationDestination(item:); a NavigationLink around a row pushes too."
    ) {
      Specimen(
        "KitList + navigationDestination", ground: .window, padding: 0,
        code: """
          NavigationSplitView { … } detail: {
            NavigationStack { DetailView() }   // iPhone: the detail's own stack, for its pushes
          }

          KitList(selection: $record) {
            ForEach(records) { SidebarRow(value: $0.id, $0.title, systemImage: "doc").pushes() }
          }
          .navigationDestination(item: $record) { RecordScreen(id: $0) }   // pops back to nil

          NavigationLink { RecordScreen(id: id) } label: { SidebarRow(…).pushes() }.buttonStyle(.kitRow)
          """
      ) {
        KitList(selection: $listSelection) {
          ForEach(1...4, id: \.self) { index in
            SidebarRow(value: index, "Order 1023\(index)", subtitle: "Shipped · Oct \(index + 20)", systemImage: "shippingbox")
              .pushes()
          }
          NavigationLink {
            PushedScreen(index: 9)
          } label: {
            SidebarRow("A NavigationLink row", subtitle: "NavigationLink around a row", systemImage: "link")
              .pushes()
          }
          .buttonStyle(.kitRow)
        }
        .modifier(PushDestination(selection: $listSelection))
        .frame(height: 300)
        .kitPane(.secondary)
      }
    }
  }

  /// On iPhone the selection pushes its screen; elsewhere it stays selected.
  private struct PushDestination: ViewModifier {
    @Binding var selection: Int?
    @Environment(\.kitIdiom) private var idiom

    func body(content: Content) -> some View {
      if idiom == .phone {
        content
          .navigationDestination(item: $selection) { PushedScreen(index: $0) }
      } else {
        content
      }
    }
  }

  private struct PushedScreen: View {
    let index: Int

    var body: some View {
      EmptyState(systemImage: "shippingbox", title: "Order 1023\(index)", message: "Pushed from the list.")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kitPane(.content)
    }
  }
}

// MARK: - Toolbar: a separator in a tool group

struct ToolbarGapSpecimens: View {
  var body: some View {
    SpecimenSection("Separators in a group", note: "ToolSeparator between two tools of one group: a chevron for a path (Scheme › Destination), or a hairline.") {
      Specimen(
        "ToolSeparator", ground: .window,
        code: """
          ToolGroup {
            Button { … } label: { Label("Atlas", systemImage: "swift") }
            ToolSeparator()            // or ToolSeparator(.line)
            Button { … } label: { Label("iPhone 17", systemImage: "iphone") }
          }
          """
      ) {
        Flow(spacing: 12) {
          ToolGroup {
            Button {} label: { Label("Atlas", systemImage: "swift") }
            ToolSeparator()
            Button {} label: { Label("iPhone 17", systemImage: "iphone") }
          }
          ToolGroup {
            Button("Back", systemImage: "chevron.left") {}
            Button("Forward", systemImage: "chevron.right") {}
            ToolSeparator(.line)
            Button("Share", systemImage: "square.and.arrow.up") {}
          }
          .labelStyle(.iconOnly)
        }
      }
    }
  }
}

// MARK: - Inspector: values that wrap

struct InspectorGapSpecimens: View {
  var body: some View {
    SpecimenSection("Values that wrap", note: ".wraps() lets a value run over several lines; the key keeps the top, at most 40% of the row.") {
      Specimen(
        "wraps()", ground: .panel,
        code: """
          InspectorRow("summary", value: payload.summary).wraps()
          InspectorRow("result") { Text(describe(result)).kitFont(.monoSmall) }.wraps(alignment: .leading)
          """
      ) {
        KitSection("Payload", meta: "4 fields", systemImage: "curlybraces", hue: .purple) {
          InspectorRow("agent", value: "builder")
          InspectorRow("summary", value: "Moved the sidebar onto the kit's rows and fixed the sticky header on iPhone.")
            .wraps()
          InspectorRow("result") {
            Text("files: 4\nlines: +128 −64\ntests:\n  passed: 212\n  failed: 0").kitFont(.monoSmall)
          }
          .wraps(alignment: .leading)
          InspectorRow("ms", value: "48210")
        }
        .frame(maxWidth: 320)
      }
    }
  }
}

// MARK: - Menus: a footer's message

struct MenuGapSpecimens: View {
  var body: some View {
    SpecimenSection("A footer with a message", note: "KitMenuFooter's message: a note under the footer that wraps (why an action is missing).") {
      Specimen(
        "KitMenuFooter(message:)",
        code: """
          Divider()
          KitMenuFooter("3 files", subtitle: "Dropped on build-mac",
                        message: "Upload needs a folder open in the browser.", systemImage: "doc.on.doc")
          """
      ) {
        KitMenu {
          Button("Copy Here", systemImage: "doc.on.doc") {}.kitMenuHint("1")
          Button("Insert Paths", systemImage: "character.cursor.ibeam") {}.kitMenuHint("2")
          Divider()
          KitMenuFooter(
            "3 files", subtitle: "Dropped on build-mac", message: "Upload needs a folder open in the browser.",
            systemImage: "doc.on.doc")
        }
        .frame(width: 260)
      }
    }
  }
}
