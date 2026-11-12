import ComponentKit
import SwiftUI

/// Scanned pages and documents: the paper preview, cards in a grid, a document's page strip, the page viewer with
/// what was read on it, the crop handles and a shared copy's watermark and hidden parts.
struct DocumentPagesPage: View {
  @State private var selected = "home"
  @State private var page: String? = "data"
  @State private var corners = KitPageCorners([
    .init(x: 0.22, y: 0.14), .init(x: 0.8, y: 0.1), .init(x: 0.84, y: 0.88), .init(x: 0.18, y: 0.9),
  ])
  @State private var zoom: CGFloat = 1
  @State private var rotation = 0
  @State private var showsFullScreen = false

  private static let pages = [
    KitPage(id: "data", label: "Data page", imageData: nil, aspectRatio: 1.42),
    KitPage(id: "cover", label: "Cover", imageData: nil, aspectRatio: 0.7),
  ]

  private static let mrz = KitPageHighlight(
    rect: CGRect(x: 0.04, y: 0.77, width: 0.92, height: 0.17), label: "Machine-readable zone · check digits match",
    systemImage: "checkmark.shield")

  var body: some View {
    CatalogPage(page: .pages) {
      SpecimenSection(
        "Paper", note: "A page is content: light in both appearances, dimmed a little in dark. More than one page stacks the next sheets behind it."
      ) {
        SpecimenGrid(minWidth: 300) {
          Specimen("Shapes", code: "KitPagePreview(data: thumbnail, aspectRatio: 1.42, pages: 2)") {
            HStack(alignment: .bottom, spacing: 20) {
              KitPagePreview(data: nil, aspectRatio: 0.707).frame(height: 96)
              KitPagePreview(data: nil, aspectRatio: 0.707, pages: 4).frame(height: 96)
              KitPagePreview(data: nil, aspectRatio: 1.42, pages: 2).frame(width: 110)
              KitPagePreview(data: nil, aspectRatio: 1.586).frame(width: 90)
            }
          }
        }
      }
      SpecimenSection(
        "Document cards", note: "The first page on a well, a badge for what's coming up, the title and one line. A tap selects, a double click opens."
      ) {
        Specimen(
          "A collection", ground: .window,
          code: "KitDocumentGrid { KitDocumentCard(\"Car\", subtitle: \"Autoschutz · Kenji\", imageData: doc.thumbnail, pages: 3, badge: \"23 days\") { select(doc) } }"
        ) {
          KitDocumentGrid {
            card("health", "Health", "Nordhealth · Aiko", pages: 2)
            card("home", "Home Contents", "Haus&Hof · both", pages: 3)
            card("car", "Car", "Autoschutz · Kenji", pages: 3, badge: "23 days")
            KitDocumentCard(
              "Passport", imageData: nil, aspectRatio: 1.42, pages: 2, isSelected: selected == "passport",
              badge: "74 days", badgeHue: .orange
            ) {
              Avatar(name: "Kenji Tanaka", size: 14)
              Text("Kenji · until Jan 2027")
            } action: {
              selected = "passport"
            }
          }
        }
      }
      SpecimenSection(
        "Pages and the viewer", note: "The page fitted on a well, with what was read on it marked; the strip under it picks the page and adds one. Full Screen shows the pages alone on black: pinch or double-tap to zoom, ‹ › or ← → between pages, Close or Escape."
      ) {
        Specimen(
          "Passport", ground: .window,
          code: "KitPageViewer(imageData: page.data, aspectRatio: 1.42, highlights: [mrz]) { …buttons }\n  .kitFullScreenPages(isPresented: $fullScreen, pages: pages, selection: $page)\nKitPageStrip(pages: pages, selection: $page) { scan() }"
        ) {
          VStack(spacing: 12) {
            KitPageViewer(
              imageData: nil, aspectRatio: page == "cover" ? 0.7 : 1.42, zoom: zoom, rotation: rotation,
              highlights: page == "data" ? [Self.mrz] : []
            ) {
              Button(zoom > 1 ? "Fit" : "Zoom", systemImage: "plus.magnifyingglass") {
                withAnimation(.kit) { zoom = zoom > 1 ? 1 : 2 }
              }
              .buttonStyle(.kit)
              Spacer()
              Button("Rotate", systemImage: "rotate.right") { withAnimation(.kit) { rotation += 1 } }
                .buttonStyle(.kitRound)
              Button("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right") { showsFullScreen = true }
                .buttonStyle(.kitRound)
            }
            .frame(height: 380)
            .kitFullScreenPages(isPresented: $showsFullScreen, pages: Self.pages, selection: $page)
            KitPageStrip(pages: Self.pages, selection: $page) {}
          }
        }
      }
      SpecimenSection(
        "Cropping and copies", note: "Drag a corner to where the page's corner is. A shared copy shows its watermark and the parts left out, as the PDF will."
      ) {
        SpecimenGrid(minWidth: 300) {
          Specimen("Edges found", code: "KitPageCrop(imageData: photo, aspectRatio: 4.0 / 3.0, corners: $corners)") {
            KitPageCrop(imageData: nil, aspectRatio: 4.0 / 3.0, corners: $corners)
              .background(.kitFill)
              .frame(maxWidth: 360)
          }
          Specimen(
            "A copy to give out",
            code: "KitMarkedPage(imageData: page, aspectRatio: 1.42, hidden: [number, mrz], watermark: \"For Wohnbau GmbH only · 7 Nov 2026\")"
          ) {
            KitMarkedPage(
              imageData: nil, aspectRatio: 1.42,
              hidden: [CGRect(x: 0.6, y: 0.2, width: 0.3, height: 0.07), CGRect(x: 0.04, y: 0.77, width: 0.92, height: 0.17)],
              watermark: "For Wohnbau GmbH only · 7 Nov 2026"
            )
            .frame(width: 300)
          }
        }
      }
    }
  }

  private func card(_ id: String, _ title: String, _ subtitle: String, pages: Int, badge: String? = nil) -> some View {
    KitDocumentCard(
      title, subtitle: subtitle, imageData: nil, pages: pages, isSelected: selected == id, badge: badge
    ) {
      selected = id
    }
  }
}
