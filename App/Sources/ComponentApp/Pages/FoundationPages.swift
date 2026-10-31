import ComponentKit
import SwiftUI

// MARK: - Colours

struct ColoursPage: View {
  struct Token: Identifiable {
    var name: String
    var style: KitColor
    var use: String
    var id: String { name }
  }

  let grounds: [Token] = [
    Token(name: "kitWindow", style: .kitWindow, use: "Content panes, editors, tables"),
    Token(name: "kitSidebar", style: .kitSidebar, use: "The sidebar's ground"),
    Token(name: "kitPanel", style: .kitPanel, use: "Inspectors, sheets, settings"),
    Token(name: "kitCard", style: .kitCard, use: "A card on a ground"),
    Token(name: "kitRaised", style: .kitRaised, use: "What is on, on a track"),
    Token(name: "kitElevated", style: .kitElevated, use: "Sheets, menus, toasts"),
  ]
  let text: [Token] = [
    Token(name: "kitLabel", style: .kitLabel, use: "Every label"),
    Token(name: "kitSecondary", style: .kitSecondary, use: "Meta lines, keys"),
    Token(name: "kitTertiary", style: .kitTertiary, use: "Chevrons, hints"),
    Token(name: "kitQuiet", style: .kitQuiet, use: "NULL, line numbers"),
    Token(name: "kitLink", style: .kitLink, use: "Links"),
  ]
  let lines: [Token] = [
    Token(name: "kitSeparator", style: .kitSeparator, use: "Hairlines"),
    Token(name: "kitBorder", style: .kitBorder, use: "Borders, key edges"),
    Token(name: "kitFill", style: .kitFill, use: "Pills, tracks, wells"),
    Token(name: "kitFillSoft", style: .kitFillSoft, use: "Stripes, soft tiles"),
    Token(name: "kitField", style: .kitField, use: "Text fields, field tracks"),
    Token(name: "kitHover", style: .kitHover, use: "Hover"),
    Token(name: "kitPress", style: .kitPress, use: "Press"),
  ]

  var body: some View {
    CatalogPage(page: .colours) {
      SpecimenSection(
        "Grounds", note: "Dark mode is steps of light: each ground one step lighter, cards opaque, tracks as wells."
      ) {
        swatches(grounds, ground: .sidebar)
        CodeSnippet("Editor().background(.kitWindow)\nInspector().background(.kitPanel)")
      }
      SpecimenSection("Text") {
        SpecimenGrid(minWidth: 180) {
          ForEach(text) { token in
            VStack(alignment: .leading, spacing: 4) {
              Text("Aa Text").kitFont(.title2).foregroundStyle(token.style)
              Text(".\(token.name)").kitFont(.mono)
              Text(token.use).kitFont(.caption)
            }
          }
        }
        CodeSnippet("Text(meta).foregroundStyle(.kitSecondary)")
      }
      SpecimenSection("Lines and fills", note: "Fields and tracks are 30% black wells in dark.") {
        swatches(lines, ground: .panel)
        CodeSnippet("Divider().overlay(.kitSeparator)\nRoundedRectangle(cornerRadius: 8).fill(.kitField)")
      }
      SpecimenSection("Accent", note: "The only colour an app picks; set it once with .componentKit(accent:).") {
        Flow(spacing: 20, alignment: .top) {
          Labeled(".kitAccent") { RoundedRectangle(cornerRadius: 10).fill(.kitAccent).frame(width: 96, height: 44) }
          Labeled(".kitAccentText") { Text("Accent text").kitFont(.title3).foregroundStyle(.kitAccentText) }
          Labeled("Hue.accent.soft()") {
            RoundedRectangle(cornerRadius: 10).fill(Hue.accent.soft()).frame(width: 96, height: 44)
          }
        }
        CodeSnippet("WindowGroup { ContentView().componentKit(accent: .orange) }")
      }
      HexColourSpecimens()
    }
  }

  private func swatches(_ tokens: [Token], ground: StageGround) -> some View {
    SpecimenGrid(minWidth: 200) {
      ForEach(tokens) { token in
        HStack(spacing: 12) {
          RoundedRectangle(cornerRadius: KitMetrics.radiusLarge, style: .continuous)
            .fill(token.style)
            .overlay(RoundedRectangle(cornerRadius: KitMetrics.radiusLarge, style: .continuous).strokeBorder(.kitSeparator))
            .frame(width: 56, height: 44)
            .padding(6)
            .background(ground.style, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          VStack(alignment: .leading, spacing: 2) {
            Text(".\(token.name)").kitFont(.mono)
            Text(token.use).kitFont(.caption)
          }
        }
      }
    }
  }
}

// MARK: - Hues

struct HuesPage: View {
  var body: some View {
    CatalogPage(page: .hues) {
      SpecimenSection(
        "Hues by meaning",
        note: "fill draws dots, icons and grounds; text is dark (or light) enough for 11–13pt text; soft is a tinted ground."
      ) {
        SpecimenGrid(minWidth: 210) {
          ForEach(Hue.allCases, id: \.self) { hue in
            HStack(spacing: 10) {
              Circle().fill(hue.fill).frame(width: 26, height: 26)
              Tile(systemImage: "star.fill", hue: hue, size: 26)
              VStack(alignment: .leading, spacing: 1) {
                Text(hue.rawValue.capitalized).kitFont(.headline).foregroundStyle(hue.text)
                Text("Hue.\(hue.rawValue)").kitFont(.monoSmall).foregroundStyle(.kitSecondary)
              }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hue.soft(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
        }
        CodeSnippet("Circle().fill(Hue.green.fill)\nText(\"Failed\").foregroundStyle(Hue.red.text)\nRectangle().fill(Hue.orange.soft())")
      }
      SpecimenSection("Stable hues", note: "The same name always gets the same colour: avatars, repository tiles.") {
        Flow(spacing: 10) {
          ForEach(["atlas", "beacon", "harbor", "pebble", "Maya Okafor", "coder-1"], id: \.self) { name in
            VStack(spacing: 4) {
              Tile(letters: String(name.prefix(1)).uppercased(), hue: StableHue.pick(name), size: 32)
              Text(name).kitFont(.caption)
            }
          }
        }
        CodeSnippet("Tile(letters: \"A\", hue: StableHue.pick(repo.name))")
      }
      SpecimenSection("Lanes", note: "Lane colours by index: graph lanes, board columns.") {
        HStack(spacing: 6) {
          ForEach(0..<10, id: \.self) { index in
            Capsule().fill(Hue.lane(index).fill).frame(width: 6, height: 40)
          }
        }
        CodeSnippet("Path(lane).stroke(Hue.lane(index).fill, lineWidth: 2)")
      }
      SpecimenSection("Status words and types") {
        Flow(spacing: 6) {
          ForEach(["shipped", "pending", "failed", "archived", "syncing", "Lisbon"], id: \.self) { Chip(status: $0) }
        }
        Flow(spacing: 6) {
          ForEach(["TEXT", "INT64", "JSONB", "SET", "TIMESTAMP", "UUID", "BOOL", "BLOB"], id: \.self) { Chip(type: $0) }
        }
        CodeSnippet("Hue.forStatus(\"shipped\")   // .green\nHue.forTypeName(\"INT64\")   // .purple")
      }
      HuePickerSpecimens()
    }
  }
}

// MARK: - Type

struct TypePage: View {
  let styles: [(KitFont, String, String)] = [
    (.largeTitle, "largeTitle", "26 bold · a window's title"),
    (.title1, "title1", "22 bold"),
    (.title2, "title2", "17 semibold · an inspector's title"),
    (.title3, "title3", "15 semibold · a sheet's title"),
    (.headline, "headline", "13 semibold · row titles, section names"),
    (.body, "body", "13 · every label"),
    (.callout, "callout", "12"),
    (.caption, "caption", "11 secondary · meta lines"),
    (.sectionHeader, "sectionHeader", "11 semibold · headers on plain grounds"),
    (.mono, "mono", "12 monospaced · values, ids, code"),
    (.monoSmall, "monoSmall", "11 monospaced · line numbers"),
  ]

  var body: some View {
    CatalogPage(page: .type) {
      SpecimenSection(
        "The type scale", note: "Mac sizes; iPad adds 2pt and iPhone 4 (switch the idiom in the toolbar). Touch idioms follow Dynamic Type."
      ) {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(styles, id: \.1) { style, name, use in
            // On an iPhone's width the sample goes under its name and use.
            ViewThatFits(in: .horizontal) {
              HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(".\(name)").kitFont(.monoSmall).foregroundStyle(.kitSecondary).frame(width: 110, alignment: .leading)
                Text("Trip to Lisbon 1234").kitFont(style).fixedSize()
                Spacer(minLength: 8)
                Text(use).kitFont(.caption).fixedSize()
              }
              VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Text(".\(name)").kitFont(.monoSmall).foregroundStyle(.kitSecondary)
                  Spacer(minLength: 8)
                  Text(use).kitFont(.caption).multilineTextAlignment(.trailing)
                }
                Text("Trip to Lisbon 1234").kitFont(style)
              }
            }
            .padding(.vertical, 8)
            Divider().overlay(.kitSeparator)
          }
        }
        CodeSnippet("Text(title).kitFont(.headline)\nText(meta).kitFont(.caption)   // takes the secondary colour")
      }
      SpecimenSection("Meta lines", note: "Parts joined with a quiet dot; empty parts drop out.") {
        VStack(alignment: .leading, spacing: 6) {
          MetaLine("5 repositories", "2 with changes").kitFont(.caption)
          MetaLine(["main", "", "2 commits to push", "1 to pull"]).kitFont(.caption)
        }
        CodeSnippet("MetaLine(\"5 repositories\", \"2 with changes\").kitFont(.caption)")
      }
      DateAndMetaSpecimens()
    }
  }
}

// MARK: - Surfaces

struct SurfacesPage: View {
  let surfaces: [(Surface, String, String)] = [
    (.card, "card", "Groups: sections, toolbar groups"),
    (.raised, "raised", "What is on: a segment, a selected row"),
    (.floating, "floating", "Sheets, popovers, toasts"),
    (.field, "field", "Fields, tracks, wells"),
    (.fill, "fill", "Neutral pills"),
  ]

  var body: some View {
    CatalogPage(page: .surfaces) {
      ForEach([StageGround.sidebar, .panel, .window], id: \.self) { ground in
        Specimen("On \(ground.name)", ground: ground, padding: 20) {
          Flow(spacing: 20, alignment: .top) {
            ForEach(surfaces, id: \.1) { surface, name, use in
              VStack(spacing: 8) {
                Text(name).kitFont(.headline)
                  .frame(width: 112, height: 64)
                  .kitSurface(surface)
                Text(use).kitFont(.caption).multilineTextAlignment(.center).frame(width: 120)
              }
            }
          }
        }
      }
      SpecimenSection("Cards", note: "Rounded views never touch: an 8pt gutter between cards and from the window edge.") {
        Specimen("kitCard()", ground: .panel, code: "VStack(spacing: KitMetrics.gutter) {\n  Text(\"First\").kitCard()\n  Text(\"Second\").kitCard()\n}") {
          VStack(spacing: KitMetrics.gutter) {
            Text("First card").frame(maxWidth: .infinity, alignment: .leading).padding(6).kitCard()
            Text("Second card").frame(maxWidth: .infinity, alignment: .leading).padding(6).kitCard()
          }
          .frame(maxWidth: 280)
        }
      }
    }
  }
}

extension StageGround {
  var name: String {
    switch self {
    case .window: "the window"
    case .panel: "the panel"
    case .sidebar: "the sidebar"
    }
  }
}

// MARK: - Motion

struct MotionPage: View {
  @Environment(\.kitIdiom) private var idiom
  @State private var moved = false
  @State private var shown = true
  @State private var rows = ["Trip to Lisbon", "Packing list"]

  let animations: [(String, Animation, String)] = [
    ("kit", .kit, "0.25 s smooth · selection, pages, icons"),
    ("kitFast", .kitFast, "0.15 s · press, hover, labels"),
    ("kitSlow", .kitSlow, "0.35 s · windows, sheets, the sidebar"),
    ("kitSpring", .kitSpring, "A spring · things that land"),
  ]

  var body: some View {
    CatalogPage(page: .motion) {
      SpecimenSection(
        "Animations", note: "An inactive window doesn't animate; Reduce Motion keeps a short crossfade. Try the Inactive toggle."
      ) {
        Specimen("Move", code: "withKitAnimation { selection = item }\nview.kitAnimation(value)          // .animation(.kit, value:)") {
          VStack(alignment: .leading, spacing: 10) {
            ForEach(animations, id: \.0) { name, animation, use in
              // The use goes under the track on an iPhone's width.
              RowOrStack(spacing: 12, stackSpacing: 4) {
                HStack(spacing: 12) {
                  Text(".\(name)").kitFont(.mono).frame(width: idiom.isTouch ? 112 : 90, alignment: .leading)
                  ZStack(alignment: moved ? .trailing : .leading) {
                    Capsule().fill(.kitField).frame(height: 24)
                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.kitAccent).frame(width: 40, height: 20)
                      .padding(2)
                  }
                  .frame(minWidth: 140, maxWidth: 260)
                  .animation(animation, value: moved)
                }
                Text(use).kitFont(.caption).fixedSize()
              }
            }
            Button(moved ? "Move Back" : "Move") { moved.toggle() }.buttonStyle(.kitPrimary)
          }
        }
      }
      SpecimenSection("Transitions") {
        SpecimenGrid(minWidth: 280) {
          Specimen(".page", code: "Panel().transition(.page)") {
            VStack(alignment: .leading) {
              Button(shown ? "Hide" : "Show") { withKitAnimation { shown.toggle() } }.buttonStyle(.kit)
              ZStack {
                if shown {
                  Text("A pane").frame(maxWidth: .infinity, minHeight: 50).kitCard().transition(.page)
                }
              }
              .frame(height: 64)
            }
          }
          Specimen(".row", code: "ForEach(rows) { Row($0).transition(.row) }") {
            VStack(alignment: .leading, spacing: 2) {
              HStack {
                Button("Add Row") { withAnimation(.kitSpring) { rows.insert("Note \(rows.count + 1)", at: 0) } }
                Button("Remove") { withKitAnimation { if !rows.isEmpty { rows.removeFirst() } } }
              }
              .buttonStyle(.kit)
              .controlSize(.small)
              ForEach(rows, id: \.self) { row in
                SidebarRow(row, systemImage: "doc.text").transition(.row)
              }
            }
            .frame(minHeight: 140, alignment: .top)
          }
        }
      }
    }
  }
}

// MARK: - Metrics

struct MetricsPage: View {
  @Environment(\.kitIdiom) private var idiom

  let radii: [(String, CGFloat)] = [
    ("radiusXS", KitMetrics.radiusXS), ("radiusSmall", KitMetrics.radiusSmall), ("radius", KitMetrics.radius),
    ("radiusLarge", KitMetrics.radiusLarge), ("radiusCard", KitMetrics.radiusCard), ("radiusXL", KitMetrics.radiusXL),
    ("radiusWindow", KitMetrics.radiusWindow), ("radiusOverlay", KitMetrics.radiusOverlay),
  ]

  var body: some View {
    CatalogPage(page: .metrics) {
      SpecimenSection("Radii") {
        SpecimenGrid(minWidth: 110) {
          ForEach(radii, id: \.0) { name, radius in
            VStack(spacing: 6) {
              RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Hue.accent.soft(0.3)).frame(width: 72, height: 56)
              Text(name).kitFont(.monoSmall).lineLimit(1).minimumScaleFactor(0.75)
              Text("\(Int(radius)) pt").kitFont(.caption)
            }
          }
        }
        CodeSnippet("RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)")
      }
      SpecimenSection("Gutter", note: "8pt between rounded shapes and from the window edge; a card pads its content 6pt.") {
        HStack(spacing: KitMetrics.gutter) {
          ForEach(0..<3) { _ in
            RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous).fill(.kitCard)
              .overlay(RoundedRectangle(cornerRadius: KitMetrics.radiusCard).strokeBorder(.kitSeparator))
              .frame(width: 90, height: 56)
          }
        }
        .padding(KitMetrics.gutter)
        .background(.kitSidebar, in: RoundedRectangle(cornerRadius: KitMetrics.radiusCard + KitMetrics.gutter))
        CodeSnippet("HStack(spacing: KitMetrics.gutter) { … }.padding(KitMetrics.gutter)")
      }
      SpecimenSection("Heights", note: "Rows grow on touch idioms; switch the idiom in the toolbar.") {
        Flow(spacing: 20, lineSpacing: 16, alignment: .bottom) {
          bar("controlSmall", KitMetrics.controlSmall)
          bar("controlRegular", KitMetrics.controlRegular)
          bar("controlLarge", KitMetrics.controlLarge)
          bar("row", KitMetrics.row(idiom))
          bar("twoLineRow", KitMetrics.twoLineRow(idiom))
          bar("tableRow", KitMetrics.tableRow(idiom))
          bar("titlebarHeight", KitMetrics.titlebarHeight)
        }
        CodeSnippet("frame(minHeight: KitMetrics.row(idiom))   // 32 on the Mac, 44 on touch")
      }
      SpecimenSection("Widths") {
        VStack(alignment: .leading, spacing: 8) {
          widthBar("sidebarWidth", KitMetrics.sidebarWidth)
          widthBar("inspectorWidth", KitMetrics.inspectorWidth)
        }
      }
      FlowLayoutSpecimens()
    }
  }

  private func bar(_ name: String, _ height: CGFloat) -> some View {
    VStack(spacing: 6) {
      RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Hue.accent.soft(0.3)).frame(width: 64, height: height)
      Text(name).kitFont(.monoSmall)
      Text("\(Int(height)) pt").kitFont(.caption)
    }
  }

  private func widthBar(_ name: String, _ width: CGFloat) -> some View {
    Flow(spacing: 12, lineSpacing: 6) {
      RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Hue.accent.soft(0.3)).frame(width: width, height: 20)
      Text("\(name) · \(Int(width)) pt").kitFont(.monoSmall)
    }
  }
}
