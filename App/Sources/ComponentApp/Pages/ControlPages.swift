import ComponentKit
import SwiftUI

// MARK: - Buttons

struct ButtonsPage: View {
  @State private var pushed = 0

  var body: some View {
    CatalogPage(page: .buttons) {
      SpecimenSection(
        "Kinds", note: "Drawn by the kit. Hover and press them: hover adds a 4% wash, pressing 10%."
      ) {
        Specimen(
          "Secondary, primary, plain, icon",
          code: """
            Button("Cancel") { … }.buttonStyle(.kit)
            Button("Clone") { … }.buttonStyle(.kitPrimary)
            Button("Show All") { … }.buttonStyle(.kitPlain)
            Button("Add", systemImage: "plus") { … }.buttonStyle(.kitIcon)
            """
        ) {
          statesGrid { disabled in
            Button("Cancel") {}.buttonStyle(.kit).disabled(disabled)
            Button("Clone") {}.buttonStyle(.kitPrimary).disabled(disabled)
            Button("Show All") {}.buttonStyle(.kitPlain).disabled(disabled)
            Button("Add Repository", systemImage: "plus") {}.buttonStyle(.kitIcon).disabled(disabled)
          }
        }
        Specimen(
          "With icons",
          code: "Button(\"Fetch\", systemImage: \"arrow.down.circle\") { … }.buttonStyle(.kit)"
        ) {
          Flow(spacing: 10) {
            Button("Fetch", systemImage: "arrow.down.circle") {}.buttonStyle(.kit)
            Button("Commit", systemImage: "checkmark") {}.buttonStyle(.kitPrimary)
            Button("Undo", systemImage: "arrow.uturn.backward") {}.buttonStyle(.kitPlain)
            Button("Settings", systemImage: "gearshape") {}.buttonStyle(.kitIcon)
            Button("More", systemImage: "ellipsis") {}.buttonStyle(.kitIcon)
          }
        }
        Specimen(
          "Destructive",
          code: "Button(\"Discard\", role: .destructive) { … }.buttonStyle(.kit)"
        ) {
          statesGrid { disabled in
            Button("Discard Changes", role: .destructive) {}.buttonStyle(.kit).disabled(disabled)
            Button("Delete", role: .destructive) {}.buttonStyle(.kitPrimary).disabled(disabled)
            Button("Remove", role: .destructive) {}.buttonStyle(.kitPlain).disabled(disabled)
            Button("Delete", systemImage: "trash", role: .destructive) {}.buttonStyle(.kitIcon).disabled(disabled)
          }
        }
      }
      SpecimenSection("Sizes", note: "From .controlSize: small 28, regular 30, large 34 (8 more on touch).") {
        Specimen("Control sizes", code: "Button(\"Clone\") { … }.buttonStyle(.kitPrimary).controlSize(.large)") {
          VStack(alignment: .leading, spacing: 12) {
            ForEach([ControlSize.small, .regular, .large], id: \.self) { size in
              HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(String(describing: size)).kitFont(.monoSmall).foregroundStyle(.kitSecondary).frame(width: 70, alignment: .leading)
                Flow(spacing: 10) {
                  Button("Cancel") {}.buttonStyle(.kit)
                  Button("Clone Repository") {}.buttonStyle(.kitPrimary)
                  Button("Show All") {}.buttonStyle(.kitPlain)
                }
              }
              .controlSize(size)
            }
          }
        }
      }
      SpecimenSection("Round", note: "A button on its own in a toolbar, on the tool groups' card ground and height.") {
        Specimen(
          "kitRound",
          code: "Button(\"Move to Trash\", systemImage: \"trash\", role: .destructive) { … }.buttonStyle(.kitRound)\nButton(\"Close\", systemImage: \"xmark\") { … }.buttonStyle(.kitRound).controlSize(.small)"
        ) {
          Flow(spacing: 12) {
            Button("Move to Trash", systemImage: "trash", role: .destructive) {}.buttonStyle(.kitRound)
            Button("Share", systemImage: "square.and.arrow.up") {}.buttonStyle(.kitRound)
            Button("Close", systemImage: "xmark") {}.buttonStyle(.kitRound).controlSize(.small)
            Button("Add", systemImage: "plus") {}.buttonStyle(.kitRound).disabled(true)
            ToolGroup {
              Button("Play", systemImage: "play.fill") {}
              Button("Next", systemImage: "forward.fill") {}
            }
          }
        }
      }
      SpecimenSection("Grounds and long text") {
        SpecimenGrid(minWidth: 300) {
          ForEach([StageGround.window, .panel, .sidebar], id: \.self) { ground in
            Specimen("On \(ground.name)", ground: ground) {
              HStack {
                Button("Cancel") {}.buttonStyle(.kit)
                Button("Save") {}.buttonStyle(.kitPrimary)
              }
            }
          }
          Specimen("A long title stays on one line", code: "// labels keep one line; give the button a width to cut it") {
            Button("Open the Repository in a New Window and Fetch") {}.buttonStyle(.kit).frame(maxWidth: 240)
          }
          Specimen("With an effect", code: "Button(\"Push\") { pushed += 1 }.effect(.success, on: pushed)") {
            Button("Push", systemImage: "arrow.up") { pushed += 1 }
              .buttonStyle(.kitPrimary)
              .effect(.success, on: pushed)
          }
        }
      }
      CopyAndRoundPrimarySpecimens()
    }
  }

  private func statesGrid<Content: View>(@ViewBuilder _ row: @escaping (Bool) -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Labeled("Rest") { Flow(spacing: 10) { row(false) } }
      Labeled("Disabled") { Flow(spacing: 10) { row(true) } }
    }
  }
}

// MARK: - Toggles

struct TogglesPage: View {
  @State private var sync = true
  @State private var off = false
  @State private var remote = true
  @State private var languages: Set<String> = ["English", "German"]
  @State private var failedOnly = true

  var body: some View {
    CatalogPage(page: .toggles) {
      SpecimenSection("Switch", note: "Tab to a switch for its focus ring; Space flips it.") {
        Specimen(
          "kitSwitch",
          code: "Toggle(\"Sync with iCloud\", isOn: $sync).toggleStyle(.kitSwitch)\nToggle(\"Sync\", isOn: $sync).kitLabelsHidden()   // .labelsHidden() too, from macOS 15 / iOS 18"
        ) {
          Flow(spacing: 28, lineSpacing: 14, alignment: .top) {
            Labeled("On") { Toggle("Sync", isOn: $sync) }
            Labeled("Off") { Toggle("Sync", isOn: $off) }
            Labeled("Disabled on") { Toggle("Sync", isOn: .constant(true)).disabled(true) }
            Labeled("Disabled off") { Toggle("Sync", isOn: .constant(false)).disabled(true) }
            Labeled("Label hidden") { Toggle("Sync", isOn: $sync).labelsHidden() }
            Labeled("kitLabelsHidden") { Toggle("Sync", isOn: $sync).kitLabelsHidden() }
          }
          .toggleStyle(.kitSwitch)
        }
      }
      SpecimenSection("Checkbox") {
        Specimen("kitCheckbox", code: "Toggle(\"Show remote branches\", isOn: $remote).toggleStyle(.kitCheckbox)") {
          VStack(alignment: .leading, spacing: 8) {
            Toggle("Show remote branches", isOn: $remote)
            Toggle("Show tags", isOn: $off)
            Toggle("Disabled, on", isOn: .constant(true)).disabled(true)
            Toggle("Disabled, off", isOn: .constant(false)).disabled(true)
            Toggle("A long label that wraps when the column is narrow, as a checkbox's label can", isOn: $remote)
              .frame(maxWidth: 300, alignment: .leading)
          }
          .toggleStyle(.kitCheckbox)
        }
      }
      SpecimenSection("Chips", note: "On their own a chip sits on the field fill; on a track it is clear until on.") {
        Specimen(
          "ChipTrack",
          code: """
            ChipTrack {
              Toggle("English", isOn: $english)
              Toggle("German", isOn: $german)
            }
            """
        ) {
          VStack(alignment: .leading, spacing: 12) {
            ChipTrack {
              ForEach(["English", "German", "Japanese", "French", "Spanish"], id: \.self) { language in
                Toggle(language, isOn: binding(language))
              }
              Toggle("Korean", isOn: .constant(false)).disabled(true)
            }
            Labeled("Wraps when narrow") {
              ChipTrack {
                ForEach(["English", "German", "Japanese", "French", "Spanish"], id: \.self) { language in
                  Toggle(language, isOn: binding(language))
                }
              }
              .frame(width: 240, alignment: .leading)
            }
          }
        }
        Specimen("kitChip on its own", code: "Toggle(\"Failed only\", isOn: $failedOnly).toggleStyle(.kitChip)") {
          HStack(spacing: 8) {
            Toggle("Failed only", isOn: $failedOnly)
            Toggle("Video", isOn: $off)
            Toggle("Disabled", isOn: .constant(false)).disabled(true)
          }
          .toggleStyle(.kitChip)
        }
      }
      MixedCheckboxSpecimens()
    }
  }

  private func binding(_ language: String) -> Binding<Bool> {
    Binding(
      get: { languages.contains(language) },
      set: { on in if on { languages.insert(language) } else { languages.remove(language) } })
  }
}

// MARK: - Segmented

enum DiffMode: String, KitOption, CaseIterable {
  case all, changes, staged
  var title: String { rawValue.capitalized }
  var count: Int? {
    switch self {
    case .all: nil
    case .changes: 3
    case .staged: 12
    }
  }
}

struct SegmentedPage: View {
  @State private var mode = DiffMode.changes
  @State private var layout = "Unified"
  @State private var refs = "Local"
  @State private var tab = "Results"

  var body: some View {
    CatalogPage(page: .segmented) {
      SpecimenSection(
        "On a field track", note: "The selected segment is a raised card that glides. Tab focuses a segment; ← → move."
      ) {
        Specimen(
          "A KitOption enum, with counts",
          code: """
            enum Mode: String, KitOption, CaseIterable {
              case all, changes, staged
              var title: String { rawValue.capitalized }
            }
            KitSegmented(selection: $mode)
            """
        ) {
          KitSegmented(selection: $mode)
        }
        Specimen("Titled values", code: "KitSegmented(selection: $layout, options: [(\"Unified\", \"Unified\"), (\"Split\", \"Split\")])") {
          KitSegmented(selection: $layout, options: [("Unified", "Unified"), ("Split", "Split")])
        }
        Specimen(
          "Icons, counts and a disabled segment",
          code: """
            KitSegmented(selection: $tab, segments: [
              KitSegment("Results", value: "Results", systemImage: "tablecells"),
              KitSegment("Messages", value: "Messages", count: 2),
              KitSegment("Plan", value: "Plan", isEnabled: false),
            ])
            """
        ) {
          KitSegmented(
            selection: $tab,
            segments: [
              KitSegment("Results", value: "Results", systemImage: "tablecells"),
              KitSegment("Messages", value: "Messages", systemImage: "text.bubble", count: 2),
              KitSegment("Plan", value: "Plan", systemImage: "list.bullet.indent", isEnabled: false),
            ])
        }
        Specimen("Wide", code: "KitSegmented(selection: $refs, options: …).kitSegmentedStyle(.wide)") {
          KitSegmented(selection: $refs, options: [("Local", "Local"), ("Remote", "Remote"), ("Tags", "Tags")])
            .kitSegmentedStyle(.wide)
            .frame(maxWidth: 360)
        }
        Specimen("Disabled", code: "KitSegmented(selection: $mode).disabled(true)") {
          KitSegmented(selection: $mode).disabled(true)
        }
      }
    }
  }
}

// MARK: - Menus

struct MenusPage: View {
  @State private var mode = DiffMode.changes
  @State private var indent = 4
  @State private var matchCase = true
  @State private var wholeWords = false
  @State private var sort = "Name"
  @State private var foldersFirst = true
  @State private var showsMore = ProcessInfo.processInfo.arguments.contains("--open-menu")
  @State private var picked = "Nothing yet"
  @State private var provider = "anthropic"
  @State private var branch = "feature/branch-1"

  var body: some View {
    CatalogPage(page: .menus) {
      SpecimenSection(
        "Menu",
        note: "The kit draws its menus: a floating card, 26pt rows (44 on touch) with an icon column, the title and a "
          + "hint; the highlighted row is the accent. Inside, Button, Toggle and Divider become rows."
      ) {
        SpecimenGrid(minWidth: 280) {
          Specimen(
            "Actions", note: "Icons, hints, a destructive row",
            code: "Button(\"Rename…\", systemImage: \"pencil\") { … }.kitMenuHint(\"↩\")\nDivider()\nButton(\"Delete\", systemImage: \"trash\", role: .destructive) { … }"
          ) {
            KitMenu {
              Button("New Tab", systemImage: "plus.square.on.square") {}.kitMenuHint("⌘T")
              Button("Rename…", systemImage: "pencil") {}.kitMenuHint("↩").kitMenuHighlighted()
              Button("Duplicate", systemImage: "plus.square.on.square") {}.kitMenuHint("⌘D")
              Button("Paste", systemImage: "doc.on.clipboard") {}.kitMenuHint("⌘V").disabled(true)
              Divider()
              Button("Delete", systemImage: "trash", role: .destructive) {}.kitMenuHint("⌫")
            }
          }
          Specimen(
            "Checks", note: "Toggles and one-of-many options",
            code: "KitMenuOptions(selection: $sort, options: [(\"Name\", \"Name\"), …])\nDivider()\nToggle(\"Folders First\", isOn: $foldersFirst)"
          ) {
            KitMenu {
              KitMenuOptions(selection: $sort, options: [("Name", "Name"), ("Date Modified", "Date"), ("Size", "Size")])
              Divider()
              Toggle("Folders First", isOn: $foldersFirst)
              Toggle("Match Case", isOn: $matchCase).kitMenuHighlighted()
            }
          }
          Specimen(
            "Submenu", note: "Opens beside its row (the side with room) on hover, a click or →",
            code: "KitSubmenu(\"Open With\", systemImage: \"arrow.up.forward.app\") {\n  Button(\"Code\") { … }\n}"
          ) {
            KitMenu {
              Button("Open", systemImage: "arrow.up.right.square") {}.kitMenuHint("⌘O")
              KitSubmenu("Open With", systemImage: "arrow.up.forward.app") {
                Button("Code", systemImage: "chevron.left.forwardslash.chevron.right") {}
                Button("Markdown", systemImage: "doc.richtext") {}
                Button("Shell", systemImage: "terminal") {}
              }
              .kitMenuHighlighted()
              KitSubmenu("Sort by", systemImage: "arrow.up.arrow.down") {
                KitMenuOptions(selection: $sort, options: [("Name", "Name"), ("Date Modified", "Date"), ("Size", "Size")])
              }
              Divider()
              Button("Show in Finder", systemImage: "folder") {}
            }
          }
          Specimen(
            "Footer", note: "What the menu acts on (Shell's drop menu)",
            code: "Divider()\nKitMenuFooter(\"harbor.png\", subtitle: \"Dropped on prod-db\", systemImage: \"doc\")"
          ) {
            KitMenu(minWidth: 244) {
              Button("Copy Here", systemImage: "doc.on.doc") {}.kitMenuHint("↩").kitMenuHighlighted()
              Button("Upload", systemImage: "arrow.up.doc") {}.kitMenuHint("2")
              Button("Insert Path", systemImage: "character.cursor.ibeam") {}.kitMenuHint("3")
              Divider()
              KitMenuFooter("harbor.png", subtitle: "Dropped on prod-db", systemImage: "doc")
            }
          }
        }
      }
      SpecimenSection(
        "Pop-ups",
        note: "When the options don't fit on a track: the select on the field well, and a raised menu button. Both "
          + "open the kit's menu under them."
      ) {
        SpecimenGrid(minWidth: 320) {
          Specimen(
            "KitPicker", note: "The menu is at least as wide as the field",
            code: "KitPicker(\"Mode\", selection: $mode)   // a KitOption & CaseIterable enum\nKitPicker(\"Indent\", selection: $indent, options: [(\"2 spaces\", 2), (\"4 spaces\", 4), (\"Tabs\", 0)])\nFormRow(\"Indent\") { KitPicker(…) }"
          ) {
            VStack(alignment: .leading, spacing: 12) {
              Flow(spacing: 10) {
                KitPicker("Mode", selection: $mode)
                KitPicker("Indent", selection: $indent, options: [("2 spaces", 2), ("4 spaces", 4), ("Tabs", 0)])
                KitPicker("Disabled", selection: $indent, options: [("4 spaces", 4)]).disabled(true)
              }
              FormCard {
                FormRow("Indent", systemImage: "increase.indent", hue: .blue) {
                  KitPicker("Indent", selection: $indent, options: [("2 spaces", 2), ("4 spaces", 4), ("Tabs", 0)])
                }
              }
            }
          }
          Specimen(
            "KitMenuButton", note: "Any rows: toggles, options, submenus",
            code: "KitMenuButton(\"Options\", systemImage: \"slider.horizontal.3\") {\n  Toggle(\"Match Case\", isOn: $matchCase)\n}\nKitMenuButton(\"Sort\") { KitMenuOptions(selection: $sort, options: …) }.controlSize(.small)"
          ) {
            Flow(spacing: 10) {
              KitMenuButton("Options", systemImage: "slider.horizontal.3") {
                Toggle("Match Case", isOn: $matchCase)
                Toggle("Whole Words", isOn: $wholeWords)
              }
              KitMenuButton("Atlas", systemImage: "hammer") {
                Button("Atlas", systemImage: "app") {}
                Button("AtlasKit", systemImage: "shippingbox") {}
                Divider()
                KitSubmenu("Destination", systemImage: "desktopcomputer") {
                  Button("My Mac") {}
                  Button("iPhone 17") {}
                }
              }
              KitMenuButton(sort, systemImage: "arrow.up.arrow.down") {
                KitMenuOptions(selection: $sort, options: [("Name", "Name"), ("Date Modified", "Date"), ("Size", "Size")])
                Divider()
                Toggle("Folders First", isOn: $foldersFirst)
              }
              .controlSize(.small)
            }
          }
        }
      }
      SpecimenSection(
        "Context menus",
        note: "Right-click or Control-click on the Mac, a long press on touch. The kit's (left) beside the system's "
          + "(right), with the same rows: hold on and let go over a row to pick it."
      ) {
        SpecimenGrid(minWidth: 320) {
          Specimen(
            ".kitContextMenu", note: "Drawn by the kit",
            code: "row.kitContextMenu {\n  Button(\"Open\", systemImage: \"arrow.up.right.square\") { … }\n}"
          ) {
            contextTarget("Kit menu").kitContextMenu { contextRows("Kit") }
          }
          Specimen(".contextMenu", note: "The system's, to compare", code: "row.contextMenu { … }") {
            contextTarget("System menu").contextMenu { contextRows("System") }
          }
        }
        Text("Last picked: \(picked)").kitFont(.caption).foregroundStyle(.kitSecondary)
      }
      SpecimenSection(
        "Anywhere",
        note: ".kitMenu { } makes any view a trigger (press opens, release picks, a click leaves it open); "
          + ".kitMenu(isPresented:) opens it from code."
      ) {
        SpecimenGrid(minWidth: 320) {
          Specimen(
            "On a button",
            code: "Button(\"More\", systemImage: \"ellipsis\") { showsMenu = true }\n  .kitMenu(isPresented: $showsMenu) { … }"
          ) {
            Button("More", systemImage: "ellipsis") { showsMore = true }
              .buttonStyle(.kitIcon)
              .kitMenu(isPresented: $showsMore) {
                Button("Share…", systemImage: "square.and.arrow.up") {}
                Button("Copy Link", systemImage: "link") {}.kitMenuHint("⌥⌘C")
                Divider()
                Button("Move to Trash", systemImage: "trash", role: .destructive) {}
              }
          }
          Specimen(
            "As a trigger", note: "Press opens, release over a row picks it",
            code: "row.kitMenu(matchesWidth: true) {\n  Button(\"Open\") { … }\n}"
          ) {
            HStack {
              Label("TripStore.swift", systemImage: "swift")
              Spacer()
              Image(systemName: "chevron.down").foregroundStyle(.kitSecondary)
            }
            .padding(.horizontal, 12)
            .frame(width: 240, height: 34)
            .kitSurface(.card)
            .kitMenu(matchesWidth: true) {
              Button("Open", systemImage: "arrow.up.right.square") {}
              Button("Reveal in Sidebar", systemImage: "sidebar.left") {}
              Button("Copy Path", systemImage: "doc.on.doc") {}
            }
          }
        }
      }
      SpecimenSection(
        "Sections, long menus, split buttons",
        note: "Section headers group rows (and a picker's options); a menu taller than its window scrolls; a split "
          + "button is an action with a menu beside it; any button style can open a menu."
      ) {
        SpecimenGrid(minWidth: 280) {
          Specimen(
            "Sections", note: "A small header over each group",
            code: "KitMenuSection(\"Local\") { … }\nDivider()\nKitMenuSection(\"Remote Branches\") { … }"
          ) {
            KitMenu {
              KitMenuSection("Merge into main") {
                Button("feature/maps", systemImage: "arrow.triangle.branch") {}
                Button("fix/crash-12", systemImage: "arrow.triangle.branch") {}.kitMenuHighlighted()
              }
              Divider()
              KitMenuSection("Remote Branches") {
                Button("origin/release/1.2", systemImage: "cloud") {}
                Button("origin/main", systemImage: "cloud") {}
              }
            }
          }
          Specimen(
            "Grouped options", note: "KitPicker's options in sections",
            code: "KitPicker(\"Provider\", selection: $provider, sections: [\n  (\"Local\", [KitSegment(\"Ollama\", value: \"ollama\")]),\n  (\"Cloud\", […]),\n])"
          ) {
            KitPicker(
              "Provider", selection: $provider,
              sections: [
                ("Local", [KitSegment("Ollama", value: "ollama"), KitSegment("LM Studio", value: "lmstudio")]),
                ("Cloud", [KitSegment("Anthropic", value: "anthropic"), KitSegment("OpenAI", value: "openai"), KitSegment("Mistral", value: "mistral")]),
                ("Custom", [KitSegment("OpenAI-compatible", value: "custom")]),
              ])
          }
          Specimen(
            "A long menu", note: "Taller than the screen: beside its button, scrolling",
            code: "KitMenuButton(\"Branch\") { ForEach(branches) { Button($0.name) { … } } }"
          ) {
            KitMenuButton(branch, systemImage: "arrow.triangle.branch") {
              KitMenuOptions(selection: $branch, options: (1...80).map { ("feature/branch-\($0)", "feature/branch-\($0)") })
            }
          }
          Specimen(
            "Split button", note: "The action, and a menu of the others",
            code: "KitSplitButton(\"Translate\", systemImage: \"character.bubble\") { translate() } menu: {\n  Button(\"Missing Only\") { … }\n}"
          ) {
            VStack(alignment: .leading, spacing: 10) {
              KitSplitButton("Translate", systemImage: "character.bubble") { picked = "Translate" } menu: {
                Button("Translate Missing Only", systemImage: "text.badge.plus") { picked = "Missing only" }
                Divider()
                KitMenuSection("Engine") {
                  KitMenuOptions(selection: $sort, options: [("On Device", "Name"), ("Claude", "Date")])
                }
              }
              ToolGroup {
                Button("Run", systemImage: "play.fill") {}
                KitSplitButton("Test", systemImage: "checkmark.diamond") {} menu: {
                  Button("Test Again") {}
                  Button("Test Failed Only") {}
                }
              }
            }
          }
          Specimen(
            "Any button opens one", note: "KitMenuButton(style: .button) takes the style around it",
            code: "ToolGroup {\n  KitMenuButton(\"Distribute\", systemImage: \"square.and.arrow.up\", style: .button) { … }\n}"
          ) {
            HStack(spacing: 10) {
              ToolGroup {
                Button("Build", systemImage: "hammer") {}
                KitMenuButton("Distribute", systemImage: "square.and.arrow.up", style: .button) {
                  Button("TestFlight", systemImage: "airplane") {}
                  Button("Developer ID", systemImage: "checkmark.seal") {}
                }
              }
              KitMenuButton("New", systemImage: "plus", style: .button) {
                Button("New Session", systemImage: "terminal") {}
                Button("New Host", systemImage: "server.rack") {}
              }
              .buttonStyle(.kitIcon)
            }
          }
          Specimen(
            "Share", note: "Shares once the menu has closed, from where it opened; prepare makes the items when picked",
            code: "KitMenuShare(items: [note.url])\nKitMenuShare(\"Share a Copy…\") { [exportCopy()] }"
          ) {
            contextTarget("Share a note").kitContextMenu {
              Button("Open", systemImage: "arrow.up.right.square") {}
              KitMenuShare(items: [URL(string: "https://github.com/v57")!])
              KitMenuShare("Share a Copy…", systemImage: "doc.on.doc") { ["A copy made when picked"] }
            }
          }
          Specimen(
            "Nested", note: "The innermost view's context menu wins",
            code: "Card { Row().kitContextMenu { … } }.kitContextMenu { … }"
          ) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Folder (its own menu)").kitFont(.caption).foregroundStyle(.kitSecondary)
              contextTarget("A file inside").kitContextMenu {
                Button("Open File", systemImage: "doc") { picked = "Open File" }
              }
            }
            .padding(10)
            .kitSurface(.card)
            .kitContextMenu {
              Button("New File in Folder", systemImage: "doc.badge.plus") { picked = "New File in Folder" }
            }
          }
        }
      }
      MenuAdditionSections()
    }
  }
}

extension MenusPage {
  fileprivate func contextTarget(_ title: String) -> some View {
    VStack(spacing: 6) {
      Image(systemName: "cursorarrow.click.2").font(.system(size: 22)).foregroundStyle(.kitSecondary)
      Text(title).kitFont(.headline)
      Text("Right-click or long press").kitFont(.caption).foregroundStyle(.kitSecondary)
    }
    .frame(maxWidth: .infinity, minHeight: 120)
    .kitSurface(.card)
    .contentShape(Rectangle())
  }

  @ViewBuilder fileprivate func contextRows(_ menu: String) -> some View {
    Button("Open", systemImage: "arrow.up.right.square") { picked = "\(menu): Open" }
    Button("Rename…", systemImage: "pencil") { picked = "\(menu): Rename" }
    Button("Copy Path", systemImage: "doc.on.doc") { picked = "\(menu): Copy Path" }
    if menu == "Kit" {
      KitSubmenu("Share", systemImage: "square.and.arrow.up") { shareRows(menu) }
    } else {
      Menu("Share", systemImage: "square.and.arrow.up") { shareRows(menu) }
    }
    Divider()
    Button("Move to Trash", systemImage: "trash", role: .destructive) { picked = "\(menu): Move to Trash" }
  }
}

extension MenusPage {
  @ViewBuilder fileprivate func shareRows(_ menu: String) -> some View {
    Button("Mail", systemImage: "envelope") { picked = "\(menu): Share › Mail" }
    Button("Messages", systemImage: "message") { picked = "\(menu): Share › Messages" }
  }
}

// MARK: - Tabs and path bar

struct TabsPage: View {
  private func keep(_ id: Int) {
    if let index = files.firstIndex(where: { $0.id == id }) { files[index].preview = false }
  }

  @State private var tabs: [KitTab<Int>] = [
    KitTab(id: 1, title: "TripStore.swift", systemImage: "swift", hue: .orange),
    KitTab(id: 2, title: "Trip.swift", systemImage: "swift", hue: .orange, isEdited: true),
    KitTab(id: 3, title: "Package.swift", systemImage: "shippingbox", hue: .brown),
    KitTab(id: 4, title: "README.md", systemImage: "doc.text", hue: .blue, isEdited: true),
  ]
  @State private var selection = 1
  @State private var queries = 1
  @State private var crumbs = "TripStore.swift"
  @State private var files: [(id: Int, name: String, letter: String, hue: Hue, preview: Bool)] = [
    (1, "TripStore.swift", "S", .orange, false), (2, "Trip.swift", "S", .orange, true), (3, "README.md", "M", .blue, false),
    (4, "Package.resolved", "J", .teal, false),
  ]
  @State private var file = 2

  var body: some View {
    CatalogPage(page: .tabs) {
      SpecimenSection(
        "Tab strip", note: "Close shows on the selected and hovered tab; a dot marks unsaved edits. Tab focuses, ← → move."
      ) {
        Specimen(
          "Editor tabs", ground: .window, padding: 0,
          code: """
            KitTabStrip(tabs: files.map { KitTab(id: $0.id, title: $0.name, isEdited: $0.isDirty) },
                        selection: $current, onClose: { close($0) }, onAdd: { newFile() })
            """
        ) {
          KitTabStrip(
            tabs: tabs, selection: $selection, onClose: { id in withKitAnimation { tabs.removeAll { $0.id == id } } },
            onAdd: {
              let id = (tabs.map(\.id).max() ?? 0) + 1
              withKitAnimation {
                tabs.append(KitTab(id: id, title: "Untitled \(id).swift", systemImage: "swift", hue: .orange))
                selection = id
              }
            })
        }
        Specimen(
          "Preview, icons, reorder, menu",
          note: "Drag tabs to reorder; right-click for the menu; double-click the italic preview to keep it.",
          ground: .window, padding: 0,
          code: """
            KitTabStrip(tabs: files.map { file in
                          KitTab(id: file.id, title: file.name, isPreview: file.isPreview) { FileIcon(file) }
                        },
                        selection: $current, onClose: { close($0) },
                        onMove: { files.move(fromOffsets: $0, toOffset: $1) })
              .tabContextMenu { id in Button("Close Other Tabs") { closeOthers(id) } }
              .onTabDoubleClick { keep($0) }
            """
        ) {
          KitTabStrip(
            tabs: files.map { item in
              KitTab(id: item.id, title: item.name, isPreview: item.preview) { FileLetterIcon(letter: item.letter, hue: item.hue, size: 14) }
            },
            selection: $file, onClose: { id in withKitAnimation { files.removeAll { $0.id == id } } },
            onMove: { files.move(fromOffsets: $0, toOffset: $1) }
          )
          .tabContextMenu { id in
            Button("Keep Open") { keep(id) }
            Button("Close Other Tabs") { withKitAnimation { files.removeAll { $0.id != id } } }
          }
          .onTabDoubleClick { keep($0) }
        }
        Specimen("Many tabs scroll sideways", ground: .window, padding: 0, code: "// the strip scrolls when the tabs don't fit") {
          KitTabStrip(
            tabs: (1...12).map { KitTab(id: $0, title: "Query \($0)", systemImage: "terminal", hue: .teal, isEdited: $0 % 4 == 0) },
            selection: $queries, onClose: { _ in })
            .frame(maxWidth: 520)
        }
        Specimen("Without close or add", ground: .window, padding: 0, code: "KitTabStrip(tabs: tabs, selection: $tab)") {
          KitTabStrip(
            tabs: [KitTab(id: "a", title: "Results"), KitTab(id: "b", title: "Messages"), KitTab(id: "c", title: "A very long tab title that gets cut at its end")],
            selection: .constant("a"))
        }
      }
      SpecimenSection("Path bar", note: "The last crumb is current; others are quiet and take the field fill on hover.") {
        Specimen(
          "Crumbs with icons",
          code: """
            KitPathBar(components: [
              KitPathItem("Atlas", systemImage: "folder", hue: .red) { reveal(atlas) },
              KitPathItem("TripStore.swift", systemImage: "swift", hue: .orange),
            ])
            """
        ) {
          KitPathBar(components: [
            KitPathItem("Atlas", systemImage: "folder", hue: .red) { crumbs = "Atlas" },
            KitPathItem("Sources", systemImage: "folder", hue: .blue) { crumbs = "Sources" },
            KitPathItem("AtlasCore", systemImage: "folder", hue: .blue) { crumbs = "AtlasCore" },
            KitPathItem("TripStore.swift", systemImage: "swift", hue: .orange),
          ])
        }
        Specimen("Icon views", code: "KitPathItem(\"TripStore.swift\", icon: { FileIcon(file) }) { reveal(file) }") {
          KitPathBar(components: [
            KitPathItem("Atlas", systemImage: "folder", hue: .red) {},
            KitPathItem("README.md", icon: { FileLetterIcon(letter: "M", hue: .blue, size: 14) }) {},
            KitPathItem("TripStore.swift", icon: { FileLetterIcon(letter: "S", hue: .orange, size: 14) }),
          ])
        }
        Specimen("Plain titles", code: "KitPathBar([\"v57\", \"Git\", \"Shared\", \"Components.swift\"])") {
          KitPathBar(["v57", "Git", "Shared", "Components.swift"])
        }
        Specimen("Narrow: the last crumb keeps its width", code: "KitPathBar(path).frame(width: 260)") {
          KitPathBar(["Developer", "v57", "Component", "Sources", "ComponentKit", "Containers", "SidebarReorder.swift"])
            .frame(width: 300, alignment: .leading)
        }
      }
    }
  }
}

// MARK: - Fields

struct FieldsPage: View {
  @State private var empty = ""
  @State private var url = "https://github.com/v57/Component.git"
  @State private var wrong = "github.com/v57"
  @State private var port = "5432"
  @State private var long = "~/Developer/v57/Component/Sources/ComponentKit/Containers/SidebarReorder.swift"
  @State private var checking = false

  var body: some View {
    CatalogPage(page: .fields) {
      SpecimenSection(
        "States", note: "Click a field to focus it: it takes the control ground and the half-accent ring."
      ) {
        SpecimenGrid(minWidth: 380) {
          Specimen("Empty", code: "TextField(\"https://\", text: $url).kitField()") {
            TextField("https://", text: $empty).kitField()
          }
          Specimen("Filled, mono", code: "TextField(\"URL\", text: $url).kitField(mono: true)") {
            TextField("URL", text: $url).kitField(mono: true)
          }
          Specimen("Checking", code: "TextField(\"URL\", text: $url).kitField(status: .checking)") {
            TextField("URL", text: $url).kitField(status: .checking, mono: true)
          }
          Specimen("Valid", code: "TextField(\"URL\", text: $url).kitField(status: .valid)") {
            TextField("URL", text: $url).kitField(status: .valid, mono: true)
          }
          Specimen("Failed check", code: "TextField(\"URL\", text: $url).kitField(status: .live(.failed, systemImage: \"link\"))") {
            TextField("URL", text: $url).kitField(status: .live(.failed, systemImage: "link"), mono: true)
          }
          Specimen("Error with a message", code: "TextField(\"Host\", text: $host)\n  .kitField(status: .error)\n  .kitFieldError(\"Not a Git URL\")") {
            TextField("Host", text: $wrong).kitField(status: .error).kitFieldError("Not a Git URL")
          }
          Specimen("Trailing view", code: "TextField(\"Port\", text: $port).kitField { Text(\"TCP\").kitFont(.caption) }") {
            TextField("Port", text: $port).kitField(mono: true) { Text("TCP").kitFont(.caption) }
          }
          Specimen("Disabled", code: "TextField(\"Location\", text: $path).kitField().disabled(true)") {
            TextField("Location", text: $empty).kitField().disabled(true)
          }
          Specimen("Long value", code: "// one line, scrolls while editing") {
            TextField("Path", text: $long).kitField(mono: true)
          }
        }
      }
      SpecimenSection("Live check", note: "Type a URL: the field checks it as you type.") {
        Specimen(
          "Validating",
          code: """
            TextField("URL", text: $url).kitField(status: isChecking ? .checking : isValid ? .valid : .error)
            Button("Paste") { url = KitPasteboard.string() ?? url }   // reads the pasteboard's text
            """
        ) {
          HStack(spacing: 8) {
            TextField("Repository URL", text: $wrong)
              .kitField(status: fieldStatus, mono: true)
              .kitFieldError(checking || isValid ? nil : "Starts with https:// or git@")
              .task(id: wrong) {
                checking = true
                try? await Task.sleep(for: .milliseconds(700))
                checking = false
              }
            Button("Paste", systemImage: "doc.on.clipboard") { wrong = KitPasteboard.string() ?? wrong }
              .buttonStyle(.kit)
          }
        }
      }
    }
  }

  private var isValid: Bool { wrong.hasPrefix("https://") || wrong.hasPrefix("git@") }
  private var fieldStatus: FieldStatus { checking ? .checking : isValid ? .valid : .error }
}

// MARK: - Search

enum SearchScope: String, KitOption, CaseIterable {
  case anyColumn = "Any column", id = "id", status = "status", note = "note"
  var title: String { rawValue }
}

struct SearchPage: View {
  @State private var empty = ""
  @State private var query = "Lisbon"
  @State private var scope = SearchScope.anyColumn
  @State private var searching = false
  @State private var sidebarText = ""
  @State private var live = ""
  @State private var liveStatus: WorkStatus = .idle

  let cities = ["Lisbon", "Porto", "London", "Lyon", "Berlin", "Bern", "Tokyo", "Toronto"]

  var body: some View {
    CatalogPage(page: .search) {
      SpecimenSection("Search field", note: "Esc clears the text; the clear button shows while there is text and no search runs.") {
        SpecimenGrid(minWidth: 380) {
          Specimen("Empty", code: "KitSearchField(text: $filter, prompt: \"Filter branches\")") {
            KitSearchField(text: $empty, prompt: "Filter branches")
          }
          Specimen("With a scope", code: "KitSearchField(text: $query, prompt: \"Search orders\", scope: $column)") {
            KitSearchField(text: $empty, prompt: "Search orders", scope: $scope)
          }
          Specimen("Searching", code: "KitSearchField(text: $query, scope: $column, status: .working, count: \"13 in 3 files\")") {
            KitSearchField(text: $query, scope: $scope, status: .working, count: "13 in 3 files")
          }
          Specimen("Done, with a count", code: "KitSearchField(text: $query, scope: $column, status: .done, count: \"4 rows\")") {
            KitSearchField(text: $query, scope: $scope, status: .done, count: "4 rows")
          }
          Specimen("Nothing matched", code: "KitSearchField(text: $query, status: .failed)") {
            KitSearchField(text: $query, scope: $scope, status: .failed)
          }
          Specimen("Text, idle", code: "KitSearchField(text: $query)") {
            KitSearchField(text: $query)
          }
        }
      }
      SpecimenSection("Live", note: "Type a city.") {
        Specimen("Search as you type", code: "KitSearchField(text: $q, status: status, count: \"\\(matches.count) cities\")") {
          VStack(alignment: .leading, spacing: 10) {
            KitSearchField(text: $live, prompt: "Search cities", status: liveStatus, count: liveCount)
            Text(matches.joined(separator: " · ")).kitFont(.caption)
          }
          .task(id: live) {
            guard !live.isEmpty else {
              liveStatus = .idle
              return
            }
            liveStatus = .working
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            liveStatus = matches.isEmpty ? .failed : .done
          }
        }
      }
      SpecimenSection("Sidebar search", note: "A square card button that opens into the full-width search line.") {
        Specimen(
          "SidebarSearchButton", ground: .sidebar,
          code: """
            HStack(spacing: KitMetrics.gutter) {
              SidebarSearchButton(text: $filter, isSearching: $isSearching)
              if !isSearching { Spacer(); actions }
            }
            """
        ) {
          HStack(spacing: KitMetrics.gutter) {
            SidebarSearchButton(text: $sidebarText, isSearching: $searching)
            if !searching {
              Spacer()
              Text("Click the magnifier").kitFont(.caption)
            }
          }
          .frame(width: 260)
        }
      }
    }
  }

  private var matches: [String] {
    live.isEmpty ? [] : cities.filter { $0.localizedCaseInsensitiveContains(live) }
  }

  private var liveCount: String? {
    liveStatus == .done ? (matches.count == 1 ? "1 city" : "\(matches.count) cities") : nil
  }
}

// MARK: - Stepper and slider

struct StepperPage: View {
  @State private var size = 13
  @State private var zoom = 1.0
  @State private var retries = 0
  @State private var scale = 1.4
  @State private var volume = 0.3
  @State private var opacity = 0.75

  var body: some View {
    CatalogPage(page: .stepper) {
      SpecimenSection("Stepper", note: "− and + go quiet at the ends of the range. Tab focuses, ↑ ↓ step.") {
        SpecimenGrid(minWidth: 280) {
          Specimen("With a unit", code: "KitStepper(\"Font size\", value: $size, in: 9...24, unit: \"pt\")") {
            KitStepper("Font size", value: $size, in: 9...24, unit: "pt")
          }
          Specimen("Formatted", code: "KitStepper(\"Zoom\", value: $zoom, in: 0.5...2, step: 0.25) { \"\\(Int($0 * 100))%\" }") {
            KitStepper("Zoom", value: $zoom, in: 0.5...2, step: 0.25) { "\(Int($0 * 100))%" }
          }
          Specimen("At its lower end", code: "KitStepper(value: $retries, in: 0...10)") {
            KitStepper(value: $retries, in: 0...10)
          }
          Specimen("Disabled", code: "KitStepper(value: $size, in: 9...24).disabled(true)") {
            KitStepper(value: $size, in: 9...24).disabled(true)
          }
        }
      }
      SpecimenSection("Slider", note: "Hover rings the knob; dragging shows the value. Tab focuses, ← → move.") {
        SpecimenGrid(minWidth: 300) {
          Specimen("Default", code: "KitSlider(\"Volume\", value: $volume)") {
            KitSlider("Volume", value: $volume)
          }
          Specimen("Stepped, value always shown", code: "KitSlider(\"Scale\", value: $scale, in: 0.5...2, step: 0.1,\n          valueBubble: .visible) { \"\\(Int($0 * 100))%\" }") {
            KitSlider("Scale", value: $scale, in: 0.5...2, step: 0.1, valueBubble: .visible) { "\(Int($0 * 100))%" }
              .padding(.top, 20)
          }
          Specimen("Disabled", code: "KitSlider(\"Opacity\", value: $opacity).disabled(true)") {
            KitSlider("Opacity", value: $opacity).disabled(true)
          }
          Specimen("In a row", code: "HStack { Image(systemName: \"speaker\"); KitSlider(value: $volume); Image(…) }") {
            HStack(spacing: 10) {
              Image(systemName: "speaker.fill").foregroundStyle(.kitSecondary)
              KitSlider("Volume", value: $volume)
              Image(systemName: "speaker.wave.3.fill").foregroundStyle(.kitSecondary)
            }
          }
          Specimen(
            "Over a video", note: "White track at 50%, one soft shadow per part, no outline.", padding: 0,
            code: "KitSlider(\"Position\", value: $time, in: 0...duration).kitSliderStyle(.overlay)"
          ) {
            HStack(spacing: 10) {
              Text("0:42").font(.system(size: 12, weight: .medium)).monospacedDigit()
              KitSlider("Position", value: $volume).kitSliderStyle(.overlay)
              Text("3:10").font(.system(size: 12, weight: .medium)).monospacedDigit()
            }
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 14)
            .background(
              LinearGradient(colors: [Color(white: 0.95), .orange, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
          }
        }
      }
    }
  }
}

// MARK: - Keycaps

struct KeycapsPage: View {
  var body: some View {
    CatalogPage(page: .keycaps) {
      SpecimenSection("Keys") {
        Specimen("Keycap and Keycaps", code: "Keycap(\"⌘\")\nKeycap(\"⇧⌘P\")   // one cap\nKeycaps(\"⇧⌘F\")   // ⇧ ⌘ F") {
          Flow(spacing: 18, lineSpacing: 14, alignment: .top) {
            Labeled("Keycap") { HStack { Keycap("⌘"); Keycap("esc"); Keycap("↩"); Keycap("Tab") } }
            Labeled("One cap") { Keycap("⇧⌘P") }
            Labeled("Keycaps") { HStack(spacing: 14) { Keycaps("⇧⌘F"); Keycaps("⌘↩"); Keycaps("⌥⌘←") } }
          }
        }
        Specimen(
          "Key hints", note: "They wrap when the line runs out",
          code: "KeyHints([(\"⌘↩\", \"runs\"), (\"Tab\", \"completes\"), (\"esc\", \"closes\")])"
        ) {
          VStack(alignment: .leading, spacing: 16) {
            KeyHints([("⌘↩", "runs"), ("Tab", "completes"), ("⇧⌘F", "find in project"), ("esc", "closes")])
            KeyHints([("⌘↩", "runs"), ("Tab", "completes"), ("⇧⌘F", "find in project"), ("esc", "closes")])
              .frame(width: 260, alignment: .leading)
          }
        }
      }
    }
  }
}

// MARK: - Choice cards

enum Engine: String, Hashable, Sendable {
  case postgres, mysql, sqlite, duckdb, custom
}

struct ChoiceCardsPage: View {
  @State private var look = "Light"
  @State private var engine = Engine.postgres
  @State private var download: WorkStatus = .working(progress: 0.45)

  var body: some View {
    CatalogPage(page: .choiceCards) {
      SpecimenSection("Pick one", note: "Picked lifts to a raised card with the half-accent ring; hover rises half-way.") {
        Specimen(
          "Choice cards",
          code: """
            HStack(spacing: KitMetrics.gutter) {
              ChoiceCard("PostgreSQL", subtitle: "Port 5432", letters: "PG", hue: .blue,
                         isOn: $engine.picks(.postgres))
              ChoiceCard("SQLite", subtitle: "A file", systemImage: "doc", isOn: $engine.picks(.sqlite))
            }
            """
        ) {
          // Three a row on the Mac, one on an iPhone.
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 240), spacing: KitMetrics.gutter)], spacing: KitMetrics.gutter
          ) {
            ChoiceCard("PostgreSQL", subtitle: "Port 5432", letters: "PG", hue: .blue, isOn: $engine.picks(.postgres))
            ChoiceCard("MySQL", subtitle: "Port 3306", letters: "My", hue: .teal, isOn: $engine.picks(.mysql))
            ChoiceCard("SQLite", subtitle: "A file on this Mac", systemImage: "doc", hue: .indigo, isOn: $engine.picks(.sqlite))
            ChoiceCard(isOn: $engine.picks(.duckdb)) {
              ChoiceCardLabel("DuckDB", subtitle: "Downloading · 45%") {
                LiveIcon(systemImage: "arrow.down", hue: .orange, status: download, size: 26)
              }
            }
            ChoiceCard("Custom…", subtitle: "Any driver", systemImage: "puzzlepiece", hue: .gray, isOn: $engine.picks(.custom))
            ChoiceCard("Oracle", subtitle: "Not available", letters: "Or", hue: .red, isOn: .constant(false))
              .disabled(true)
          }
        }
      }
      SpecimenSection("Tall cards", note: "Something to look at: the content stacked and centred (an app icon's appearances, themes).") {
        Specimen(
          "kitChoiceCardStyle(.tall)",
          code: "HStack { ForEach(looks) { look in ChoiceCard(isOn: $look.picks(look)) { Preview(look); Text(look.title) } } }\n  .kitChoiceCardStyle(.tall)"
        ) {
          HStack(spacing: KitMetrics.gutter) {
            ForEach(["Light", "Dark", "Tinted"], id: \.self) { name in
              ChoiceCard(isOn: $look.picks(name)) {
                Avatar(name: name, kind: .app, systemImage: "arrow.triangle.branch", hue: name == "Tinted" ? .teal : name == "Dark" ? .indigo : .orange, size: 72)
                  .padding(.top, 4)
                Text(name).kitFont(.callout)
              }
            }
          }
          .kitChoiceCardStyle(.tall)
          .frame(maxWidth: 420)
        }
      }
    }
  }
}
