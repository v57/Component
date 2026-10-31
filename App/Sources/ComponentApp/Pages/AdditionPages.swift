import ComponentKit
import SwiftUI

// Specimens for the components added from the consistency audit (2026-10-31): each page shows them in a section of
// its own, after its other sections.

// MARK: - Sheets: notice from a message, prompt, popover, overlay card

struct SheetAdditionSections: View {
  struct Failure: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var needsAccess = false
  }

  @State private var error: String?
  @State private var failure: Failure?
  @State private var renaming = catalogOpenSheet == "prompt"
  @State private var name = "Trip to Lisbon.md"
  @State private var renamed: String?
  @State private var unlocking = false
  @State private var password = ""
  @State private var addingFilter = catalogOpenSheet == "popover"
  @State private var filterField = ""
  @State private var filters: [String] = ["status = open"]
  @State private var showsBranches = false

  var body: some View {
    SpecimenSection(
      "Notice from a message",
      note: "Shown while a message (or an item) is set; OK, Escape or any button clears it. The message can be "
        + "selected, and a long one (a tool's output) goes in the body, which scrolls."
    ) {
      Specimen(
        "kitNotice(message:), kitNotice(item:)",
        code: """
          .kitNotice("Couldn't Complete the Action", message: $actions.error)
          .kitNotice(item: $session.failure, title: \\.title, message: \\.message) { failure in
            failure.needsAccess ? [KitConfirmationButton("Grant Access…", isDefault: true) { grant() }] : []
          }
          """
      ) {
        Flow(spacing: 10) {
          Button("Move…") { error = "“Trip to Lisbon.md” is open in another app." }
            .buttonStyle(.kit)
          Button("Push…") {
            failure = Failure(
              title: "Couldn't Push to origin",
              message: """
                remote: Permission to v57/atlas.git denied.
                refusing to allow an OAuth App to create or update workflow `.github/workflows/ci.yml` \
                without `workflow` scope
                error: failed to push some refs to 'github.com:v57/atlas.git'
                """,
              needsAccess: true)
          }
          .buttonStyle(.kit)
        }
        .kitNotice("Couldn't Move the Note", message: $error)
        .kitNotice(item: $failure, title: \.title, message: \.message) { failure in
          failure.needsAccess ? [KitConfirmationButton("Grant Access…", isDefault: true) {}] : []
        }
      }
    }
    SpecimenSection(
      "Prompt",
      note: "One line of text: the field takes focus, the action stays off while it is empty, Return confirms. "
        + "An action that throws keeps the sheet open with the error in its footer."
    ) {
      Specimen(
        "kitPrompt",
        code: """
          .kitPrompt("Rename", isPresented: $renaming, text: $name, message: "“\\(old)”", confirm: "Rename") { name in
            try rename(to: name)
          }
          .kitPrompt("Login Keychain", isPresented: $unlocking, text: $password, message: "build-mac",
                     systemImage: "key", hue: .indigo, field: .secure(placeholder: "Mac password"),
                     footnote: "Code unlocks it before each build.", confirm: "Save") { try save($0) }
          """
      ) {
        Flow(spacing: 10) {
          Button("Rename…", systemImage: "pencil") { renaming = true }.buttonStyle(.kit)
          Button("Unlock…", systemImage: "key") {
            password = ""
            unlocking = true
          }
          .buttonStyle(.kit)
          if let renamed { Text("Renamed to “\(renamed)”").kitFont(.caption) }
        }
        .kitPrompt(
          "Rename", isPresented: $renaming, text: $name, message: "“Trip to Lisbon.md” · type “error” to fail",
          confirm: "Rename"
        ) { newName in
          guard newName != "error" else { throw PromptSampleError() }
          renamed = newName
        }
        .kitPrompt(
          "Login Keychain", isPresented: $unlocking, text: $password, message: "build-mac", systemImage: "key",
          hue: .indigo, field: .secure(placeholder: "Mac password", help: "v57 on build-mac"),
          footnote: "An SSH session can't use the login keychain until it's unlocked.", confirm: "Save"
        ) { _ in }
      }
    }
    SpecimenSection(
      "Popover",
      note: "A kit card beside the view instead of a system popover: under it (above when there's no room), with "
        + "no dim. A click outside or Escape closes it; on iPhone it is a sheet in the middle."
    ) {
      Specimen(
        "kitPopover",
        code: """
          Button("Add Filter", systemImage: "plus") { adding = true }
            .buttonStyle(.kit)
            .kitPopover(isPresented: $adding) {
              AddFilterView { adding = false; add($0) }.frame(width: 300)
            }
          """
      ) {
        HStack(spacing: 8) {
          ForEach(filters, id: \.self) { filter in
            FilterToken(filter) { filters.removeAll { $0 == filter } }
          }
          Button("Add Filter", systemImage: "plus") { addingFilter = true }
            .buttonStyle(.kit)
            .kitPopover(isPresented: $addingFilter) { addFilter }
          Spacer()
          Button("Branch", systemImage: "arrow.triangle.branch") { showsBranches = true }
            .buttonStyle(.kit)
            .kitPopover(isPresented: $showsBranches, edge: .top) { branches }
        }
      }
      Specimen(
        "kitOverlayCard",
        note: "The overlays' card for a floating panel of your own.",
        ground: .window,
        code: """
          SubtitleStyleForm()
            .frame(width: 280)
            .kitOverlayCard()
          """
      ) {
        VStack(alignment: .leading, spacing: 10) {
          Text("Subtitles").kitFont(.headline)
          FormCard {
            FormRow("Size", systemImage: "textformat.size") { Text("24 pt").kitFont(.callout) }
            FormRow("Background", systemImage: "rectangle.fill", hue: .gray) { Text("Dim").kitFont(.callout) }
          }
        }
        .padding(KitMetrics.gutter)
        .frame(width: 280)
        .kitOverlayCard()
        .padding(KitMetrics.gutter)
      }
    }
  }

  private var addFilter: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Add Filter").kitFont(.headline)
      TextField("status = open", text: $filterField)
        .kitField()
        .onSubmit(add)
      HStack {
        Spacer()
        Button("Cancel") { addingFilter = false }.keyboardShortcut(.cancelAction)
        Button("Add") { add() }
          .buttonStyle(.kitPrimary)
          .keyboardShortcut(.defaultAction)
          .disabled(filterField.isEmpty)
      }
    }
    .padding(14)
    .frame(width: 300)
  }

  private var branches: some View {
    VStack(alignment: .leading, spacing: 2) {
      ForEach(["main", "feature/login", "fix/crash-on-launch"], id: \.self) { branch in
        SidebarRow(branch, systemImage: "arrow.triangle.branch").action { showsBranches = false }
      }
    }
    .padding(6)
    .frame(width: 240)
  }

  private func add() {
    guard !filterField.isEmpty else { return }
    filters.append(filterField)
    filterField = ""
    addingFilter = false
  }
}

private struct PromptSampleError: LocalizedError {
  var errorDescription: String? { "A note with that name already exists." }
}

// MARK: - Sidebar: show more, outline with closed groups

struct SidebarAdditionSections: View {
  struct Node: Identifiable {
    var id: String
    var name: String
    var children: [Node]?
  }

  @State private var showsMore = false
  @State private var selection: String?
  @State private var collapsed: KitIDSet = ["Archive"]

  private static let tree = [
    Node(id: "Apps", name: "Apps", children: [
      Node(id: "shell", name: "Shell"),
      Node(id: "Kits", name: "Kits", children: [Node(id: "component", name: "Component"), Node(id: "vault", name: "Vault")]),
    ]),
    Node(id: "Archive", name: "Archive", children: [Node(id: "hub", name: "Hub")]),
    Node(id: "dev", name: "Dev"),
  ]

  var body: some View {
    SpecimenSection(
      "Show more and grouped trees",
      note: "The row after a filtered list, and a tree whose closed groups are kept (KitIDSet in @AppStorage): a "
        + "group row that selects nothing opens and closes on a click."
    ) {
      Columns {
        Specimen(
          "SidebarShowMoreRow", ground: .sidebar,
          code: """
            SidebarShowMoreRow(count: more, isShowing: $showsMore, reason: "unused",
                               help: "Show \\(more) connections unused for a week",
                               hideHelp: "Hide the connections the filters leave out")
            """
        ) {
          KitSidebar(selection: $selection) {
            KitSection("Databases", meta: showsMore ? "11 connections" : "3 of 11", systemImage: "cylinder.split.1x2", hue: .indigo) {
              ForEach(showsMore ? ["atlas", "orders", "billing", "events", "metrics"] : ["atlas", "orders", "billing"], id: \.self) {
                name in
                SidebarRow(value: name, name, systemImage: "cylinder")
              }
              SidebarShowMoreRow(
                count: 8, isShowing: $showsMore, reason: "unused", help: "Show 8 connections unused for a week",
                hideHelp: "Hide the connections the filters leave out")
            }
          }
          .frame(height: 340)
        }
        Specimen(
          "KitOutline(collapsed:), KitIDSet", ground: .sidebar,
          code: """
            @AppStorage("collapsedGroups") private var collapsed = KitIDSet()
            KitOutline(tree.roots, children: { $0.group == nil ? nil : $0.children },
                       collapsed: $collapsed.ids) { node in
              if let group = node.group {
                SidebarRow(group.name, systemImage: "folder")   // opens and closes on a click
              } else {
                SidebarRow(value: node.id, node.name, systemImage: "shippingbox")
              }
            }
            """
        ) {
          KitSidebar(selection: $selection) {
            KitSection("Projects", meta: "\(collapsed.ids.count) closed", systemImage: "square.stack.3d.up", hue: .indigo) {
              KitOutline(Self.tree, children: \.children, collapsed: $collapsed.ids) { node in
                if node.children != nil {
                  SidebarRow(node.name, systemImage: collapsed.contains(node.id) ? "folder" : "folder.fill", hue: .gray)
                } else {
                  SidebarRow(value: node.id, node.name, systemImage: "shippingbox")
                }
              }
            }
          }
          .frame(height: 340)
        }
      }
    }
  }
}

// MARK: - Toolbar: a toolbar while on, the sidebar toggle's switch

struct ToolbarAdditionSections: View {
  @State private var isOn = true

  var body: some View {
    SpecimenSection(
      "Only while on",
      note: "A column whose page sometimes brings its own toolbar takes the kit's only while it doesn't; the Show "
        + "Sidebar button can be left out the same way (iPhone, where the back button does it)."
    ) {
      Specimen(
        "kitToolbar(isPresented:), kitSidebarToggle(isOn:)", ground: .window,
        code: """
          Detail()
            .kitToolbar(page.title, isPresented: !showsDatabase, title: { page.titleView }) { pageTools }
            .kitSidebarToggle(columnVisibility: $columns, isOn: idiom != .phone)
          """
      ) {
        VStack(alignment: .leading, spacing: 12) {
          Toggle("Toolbar", isOn: $isOn.animation(.kit)).toggleStyle(.kitSwitch)
          // Drawn in place here: the modifier puts the same bar in the window's title bar.
          if isOn {
            KitToolbar("Overview", meta: ["build-mac"], systemImage: "server.rack") {
              Button("Connect", systemImage: "bolt") {}.buttonStyle(.kitPrimary)
            }
            .background(Hue.accent.soft(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .transition(.opacity)
          } else {
            Text("The page's own toolbar shows instead.").kitFont(.callout).foregroundStyle(.kitSecondary)
          }
        }
      }
    }
  }
}

// MARK: - Window: a status bar that goes when it has nothing to say

struct WindowAdditionSections: View {
  @State private var indexing = false

  var body: some View {
    SpecimenSection(
      "A status bar while it has something to say",
      note: "Off, it fades out and gives its room back; the editor under it keeps its state."
    ) {
      Specimen(
        "kitStatusBar(isPresented:)", ground: .window, padding: 0,
        code: """
          Editor()
            .kitStatusBar(isPresented: message != nil || isIndexing, systemImage: "doc.text.magnifyingglass",
                          status: isIndexing ? .working : .idle) { Text("Indexing…") }
          """
      ) {
        VStack(alignment: .leading, spacing: 10) {
          Button(indexing ? "Stop Indexing" : "Index") { indexing.toggle() }.buttonStyle(.kit)
          Text("TripStore.swift").kitFont(.headline)
          Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 160)
        .kitStatusBar(
          isPresented: indexing, systemImage: "doc.text.magnifyingglass", status: indexing ? .working : .idle
        ) {
          Text("Indexing…")
        }
      }
    }
  }
}

// MARK: - Menus: a menu at a point

struct MenuAdditionSections: View {
  @State private var showsMenu = false
  @State private var point = CGPoint.zero
  @State private var picked: String?

  var body: some View {
    SpecimenSection(
      "At a point",
      note: "Opened from code where something happened (files dropped at the pointer): the first row is "
        + "highlighted for Return, and number hints pick their row from the keyboard."
    ) {
      Specimen(
        "kitMenu(isPresented:at:)",
        code: """
          Terminal()
            .kitMenu(isPresented: $showsDropMenu, at: dropLocation) {
              Button("Upload Here", systemImage: "arrow.up.doc") { upload() }.kitMenuHint("1")
              Button("Paste Paths", systemImage: "text.insert") { paste() }.kitMenuHint("2")
              Divider()
              KitMenuFooter("3 files", subtitle: "Dropped on build-mac", systemImage: "doc.on.doc")
            }
          """
      ) {
        ZStack {
          RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)
            .fill(.kitFill)
          Text(picked.map { "Picked \($0)" } ?? "Click anywhere here")
            .kitFont(.callout)
            .foregroundStyle(.kitSecondary)
        }
        .frame(height: 140)
        .contentShape(Rectangle())
        .onTapGesture { location in
          point = location
          showsMenu = true
        }
        .kitMenu(isPresented: $showsMenu, at: point) {
          Button("Upload Here", systemImage: "arrow.up.doc") { picked = "Upload Here" }.kitMenuHint("1")
          Button("Paste Paths", systemImage: "text.insert") { picked = "Paste Paths" }.kitMenuHint("2")
          Button("Open in New Tab", systemImage: "plus.square.on.square") { picked = "Open in New Tab" }.kitMenuHint("3")
          Divider()
          KitMenuFooter("3 files", subtitle: "Dropped on build-mac", systemImage: "doc.on.doc")
        }
      }
    }
  }
}

// MARK: - Welcome: groups of projects

struct WelcomeAdditionSections: View {
  struct Node: Identifiable {
    var id: String
    var name: String
    var path: String
    var children: [Node]?
  }

  @State private var collapsed = KitIDSet()

  private static let tree = [
    Node(id: "v57", name: "v57", path: "", children: [
      Node(id: "shell", name: "Shell", path: "~/Developer/v57/Shell"),
      Node(id: "kits", name: "Kits", path: "", children: [
        Node(id: "component", name: "Component", path: "~/Developer/v57/Component"),
      ]),
    ]),
    Node(id: "hub", name: "hub-app", path: "~/Developer/Hub/Apps/hub-app"),
  ]

  var body: some View {
    SpecimenSection(
      "Groups of projects",
      note: "In a KitOutline a RecentItem takes the indent and a chevron at its end; the item's own action is "
        + "usually the same toggle."
    ) {
      Specimen(
        "RecentItem in KitOutline", ground: .window,
        code: """
          KitOutline(tree.roots, children: { $0.group == nil ? nil : $0.children }, collapsed: $collapsed.ids) {
            node in
            if let group = node.group {
              RecentItem(group.name, subtitle: "2 projects", systemImage: "folder", id: "group:\\(group.id)") {
                withAnimation(.kit) { collapsed.toggle(group.id) }
              }
            } else {
              RecentItem(node.name, subtitle: node.path) { open(node) }
            }
          }
          """
      ) {
        VStack(spacing: 2) {
          KitOutline(Self.tree, children: \.children, collapsed: $collapsed.ids) { node in
            if let children = node.children {
              RecentItem(
                node.name, subtitle: children.count == 1 ? "1 item" : "\(children.count) items",
                systemImage: collapsed.contains(node.id) ? "folder" : "folder.fill", id: "group:\(node.id)"
              ) {
                withAnimation(.kit) { collapsed.toggle(node.id) }
              }
            } else {
              RecentItem(node.name, subtitle: node.path) {}
            }
          }
        }
        .frame(maxWidth: 460)
      }
    }
  }
}

// MARK: - Secrets: grouped codes

struct SecretAdditionSections: View {
  var body: some View {
    SpecimenSection("Short codes", note: "A pairing code in groups of three instead of five.") {
      Specimen("KitSafetyCode(groupSize:)", code: "KitSafetyCode(\"702115\", groupSize: 3, columns: 2)") {
        KitSafetyCode("702115", groupSize: 3, columns: 2)
          .frame(maxWidth: 200)
      }
    }
  }
}
