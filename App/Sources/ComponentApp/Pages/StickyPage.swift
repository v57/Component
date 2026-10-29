import ComponentKit
import SwiftUI

/// Sticky sections: Git's sidebar with 72 repositories (boards D1 and D2), and a sidebar to try every option on.
struct StickyPage: View {
  @State private var selection: String? = "History"
  @State private var tried: String? = "row-0"
  @State private var top = KitStickyTop.titleWhileVisible
  @State private var bottom = KitStickyBottom.content
  @MainActor private static let repos: [LongRepo] = (0..<72).map { LongRepo($0) }

  var body: some View {
    CatalogPage(page: .stickySections, maxWidth: 1100) {
      SpecimenSection(
        "Git's sidebar",
        note: "72 repositories. The open repository's card waits at the bottom with the Branches and Remotes titles; scroll down and the Repositories title stays at the top. Click a stuck title to scroll to its section."
      ) {
        Columns {
          WindowFrame(height: 640) {
            KitSidebar(selection: $selection, searchText: .constant("")) {
              KitSection("Repositories", meta: ["\(Self.repos.count) repositories", "Name"], systemImage: "folder", hue: .indigo) {
                ForEach(Self.repos) { repo in
                  SidebarRow(value: repo.name, repo.name, subtitle: repo.branches[0].name) {
                    Tile(letters: String(repo.name.prefix(1)).uppercased(), hue: repo.hue, size: 18)
                  } trailing: {
                    SyncCounts(changes: repo.branches[0].changes, ahead: repo.branches[0].ahead, behind: 0)
                  }
                }
              } accessory: {
                Button("Add Repository", systemImage: "plus") {}
              }
              .kitSticky(top: .titleWhileVisible)
              KitSection("atlas", meta: ["main", "4 changed", "↑2 ↓1"], systemImage: "arrow.triangle.branch", hue: .red) {
                SidebarRow(value: "Changes", "Changes", systemImage: "pencil") { Count(4, .attention) }
                SidebarRow(value: "History", "History", systemImage: "clock")
                SidebarRow(value: "Stashes", "Stashes", systemImage: "tray") { Count(1) }
              }
              .kitSticky(top: .titleWhileVisible, bottom: .content)
              KitSection("Branches", meta: ["3 local", "1 merged"], hue: .orange, glyph: { BranchGlyph() }) {
                SidebarRow(value: "main", "main", glyph: { BranchGlyph() })
                SidebarRow(value: "feature/offline-maps", "feature/offline-maps", glyph: { BranchGlyph() })
                SidebarRow(value: "fix/date-parsing", "fix/date-parsing", glyph: { BranchGlyph() })
              }
              .kitSticky(top: .titleWhileVisible, bottom: .title)
              KitSection("Remotes", meta: ["origin", "fetched 1 min ago"], systemImage: "cloud", hue: .blue) {
                SidebarRow(value: "origin", "origin", systemImage: "cloud")
              }
              .kitSticky(top: .titleWhileVisible, bottom: .title)
              KitSection("Tags", meta: ["v1.1.0"], systemImage: "tag", hue: .gray) {
                SidebarRow(value: "v1.1.0", "v1.1.0", systemImage: "tag")
                SidebarRow(value: "v1.0.0", "v1.0.0", systemImage: "tag")
              }
              .kitSticky()
            } bottomBar: {
              Button("Add Repository", systemImage: "plus") {}
            }
          }
          .frame(width: 290)
          VStack(alignment: .leading, spacing: 12) {
            Text("Selected: \(selection ?? "none")").kitFont(.headline)
            CodeSnippet(
              """
              KitSidebar(selection: $page) {
                KitSection("Repositories", meta: …, systemImage: "folder") { rows }
                  .kitSticky()                          // top: .titleWhileVisible
                KitSection("atlas", meta: …, systemImage: "arrow.triangle.branch") { pages }
                  .kitSticky(bottom: .content)          // waits at the bottom
                KitSection("Branches", meta: …, glyph: { BranchGlyph() }) { branches }
                  .kitSticky(bottom: .title)
                KitSection("Remotes", meta: …, systemImage: "cloud") { remotes }
                  .kitSticky(bottom: .title)
                KitSection("Tags", meta: …, systemImage: "tag") { tags }
                  .kitSticky()
              }
              """)
            Text(
              "Top: .content .title .titleWhileVisible (default) .none\nBottom: .content .title .none (default)\nThe bottom stack takes at most 40% of the sidebar; past that, .content shows the title. Sections without .kitSticky never stick."
            )
            .kitFont(.caption)
          }
        }
      }
      SpecimenSection(
        "Every option",
        note: "Pick the options of the \"Tried\" section, then scroll it out of view above and below. The others show one option each."
      ) {
        Columns {
          WindowFrame(height: 560) {
            KitSidebar(selection: $tried) {
              filler("Before", count: 12, hue: .gray)
              option("Top: content", top: .content, bottom: .none, rows: 2, hue: .teal)
              option("Top: title", top: .title, bottom: .none, rows: 6, hue: .indigo)
              filler("Middle", count: 14, hue: .gray)
              option("Tried", top: top, bottom: bottom, rows: 3, hue: .red)
              filler("After", count: 16, hue: .gray)
              option("Bottom: content", top: .none, bottom: .content, rows: 2, hue: .orange)
              option("Bottom: title", top: .none, bottom: .title, rows: 5, hue: .blue)
              option("None", top: .none, bottom: .none, rows: 3, hue: .green)
            }
          }
          .frame(width: 290)
          VStack(alignment: .leading, spacing: 12) {
            Labeled("Top") {
              KitSegmented(
                selection: $top,
                options: [("Content", .content), ("Title", .title), ("While Visible", .titleWhileVisible), ("None", .none)])
            }
            Labeled("Bottom") {
              KitSegmented(selection: $bottom, options: [("Content", .content), ("Title", .title), ("None", .none)])
            }
            CodeSnippet("KitSection(\"Tried\", …) { rows }\n  .kitSticky(top: .\(top), bottom: .\(bottom))")
          }
        }
      }
    }
  }

  private func option(_ name: String, top: KitStickyTop, bottom: KitStickyBottom, rows: Int, hue: Hue) -> some View {
    KitSection(name, meta: ["\(rows) rows"], systemImage: "pin", hue: hue) {
      ForEach(0..<rows, id: \.self) { index in
        SidebarRow(value: "\(name)-\(index)", "\(name) \(index + 1)", systemImage: "doc")
      }
    }
    .kitSticky(top: top, bottom: bottom)
  }

  private func filler(_ name: String, count: Int, hue: Hue) -> some View {
    KitSection(name, meta: ["\(count) rows", "not sticky"], systemImage: "list.bullet", hue: hue) {
      ForEach(0..<count, id: \.self) { index in
        SidebarRow(value: "\(name)-\(index)", "\(name) \(index + 1)", systemImage: "doc")
      }
    }
  }
}
