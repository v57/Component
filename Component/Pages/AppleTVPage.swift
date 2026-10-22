import ComponentKit
import SwiftUI

/// Apple TV (the canvas's kit-tvos board): the Mac's layout at twice its size, lit by focus instead of a pointer.
/// On a Mac or iPad the pointer lights the same views; `--idiom tv` draws the type at the TV's sizes. `--focus <name>`
/// (DEBUG) focuses a specimen first: `studio`, `lab`, `requests`, `update`, `review`, `share`, `devices-row`…
struct AppleTVPage: View {
  @Environment(CatalogModel.self) private var model
  @FocusState private var focus: String?

  var body: some View {
    CatalogPage(page: .appleTV, maxWidth: 1600) {
      SpecimenSection(
        "Focus",
        note: "No ring: the focused view grows, tilts toward the thumb on the remote (the top right while it rests), lights there and casts the only shadow on screen. Its parent lifts a little and glows faintly."
      ) {
        SpecimenGrid(minWidth: 380) {
          Specimen("Card", code: ".kitHoverEffect(in: shape)  // in a Button with .buttonStyle(.kitHoverEffect)") {
            VStack(spacing: KitMetrics.gutter * 2) {
              TVHubCard(name: "Studio", services: 70).focused($focus, equals: "studio")
              TVHubCard(name: "Lab", services: 64).focused($focus, equals: "lab")
            }
          }
          Specimen("Inside a card", code: ".labelStyle(.kitHoverTile).buttonStyle(.kitHoverEffect)") {
            TVTileCard(focus: $focus)
          }
          Specimen("Buttons", code: "Button(\"Review\") { … }.buttonStyle(.kitPrimary)  // tint +20%, grows") {
            HStack(spacing: KitMetrics.gutter * 2) {
              Button("Update") {}.buttonStyle(.kit).focused($focus, equals: "update")
              Button("Review") {}.buttonStyle(.kitPrimary).focused($focus, equals: "review")
              Button("Share", systemImage: "square.and.arrow.up") {}.buttonStyle(.kitRound).focused($focus, equals: "share")
            }
          }
          Specimen("Tabs", code: "KitSegmented(selection: $page, options: …)  // the segment fills 30% and grows") {
            TVTabs().focused($focus, equals: "tabs")
          }
          Specimen("Rows", code: "row.kitHoverEffect(in: shape), card.kitHoverEffect(in: cardShape)") {
            TVRowsCard(focus: $focus)
          }
        }
      }
      SpecimenSection("Type and metrics", note: "Points, the Mac's and Apple TV's: KitIdiom.tv doubles the Mac's.") {
        TVTypeTable()
      }
    }
    .defaultFocus($focus, model.focus)
    .task {
      // After the page's first layout, so the focus engine knows the specimen.
      try? await Task.sleep(for: .seconds(1.5))
      if let name = model.focus { focus = name }
    }
  }
}

/// A hub's card that opens its page: the whole card takes the focus.
private struct TVHubCard: View {
  var name: String
  var services: Int

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)
    Button {
    } label: {
      RichHeader(name, meta: ["\(services) services"], systemImage: "server.rack", hue: .indigo)
        .padding(KitMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.kitCard, in: shape)
        .kitHoverEffect(in: shape)
    }
    .buttonStyle(.kitHoverEffect)
  }
}

/// A hub's card with its apps: a tile takes the focus, its card lifts.
private struct TVTileCard: View {
  var focus: FocusState<String?>.Binding

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)
    VStack(alignment: .leading, spacing: KitMetrics.gutter) {
      RichHeader("Studio", meta: ["70 services"], systemImage: "server.rack", hue: .indigo)
      HStack(spacing: KitMetrics.gutter * 2) {
        Button("Requests", systemImage: "clock") {}.focused(focus, equals: "requests")
        Button("Devices", systemImage: "laptopcomputer") {}.focused(focus, equals: "devices")
        Button("Tasks", systemImage: "checklist") {}.focused(focus, equals: "tasks")
      }
      .labelStyle(.kitHoverTile)
      .buttonStyle(.kitHoverEffect)
    }
    .padding(KitMetrics.cardPadding * 2)
    .background(.kitCard, in: shape)
    .kitHoverEffect(in: shape)
  }
}

/// Rows in a card: the focused row tilts in it, the card lifts; the selection stays as on the Mac.
private struct TVRowsCard: View {
  var focus: FocusState<String?>.Binding
  @State private var selection = "Requests"
  @Environment(\.kitIdiom) private var idiom
  private let rows: [(String, String, Int)] = [
    ("Devices", "laptopcomputer", 0), ("Requests", "clock", 2), ("Connections", "wifi", 0),
  ]

  var body: some View {
    let card = RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)
    let row = RoundedRectangle(cornerRadius: KitMetrics.radius, style: .continuous)
    VStack(spacing: 0) {
      ForEach(rows, id: \.0) { title, image, count in
        Button {
          selection = title
        } label: {
          HStack(spacing: KitMetrics.gutter) {
            Tile(systemImage: image, hue: .gray, size: KitMetrics.rowTile(idiom))
            Text(title)
            Spacer()
            if count > 0 { Count(count, .attention) }
          }
          .padding(.horizontal, KitMetrics.gutter)
          .frame(height: KitMetrics.row(idiom))
          .background(selection == title ? AnyShapeStyle(.kitRaised) : AnyShapeStyle(.clear), in: row)
          .kitHoverEffect(in: row)
        }
        .buttonStyle(.kitHoverEffect)
        .focused(focus, equals: title.lowercased() + "-row")
      }
    }
    .padding(KitMetrics.cardPadding)
    .background(.kitCard, in: card)
    .kitHoverEffect(in: card)
    .frame(maxWidth: 420 * idiom.scale)
  }
}

/// A hub's pages as a segmented control: the focused segment fills with the accent and grows.
private struct TVTabs: View {
  @State private var page = "Overview"

  var body: some View {
    KitSegmented(selection: $page, options: ["Overview", "Services", "Apps", "Devices"].map { ($0, $0) })
  }
}

/// The board's table: each style drawn at the Mac's size and at Apple TV's.
private struct TVTypeTable: View {
  private let styles: [(String, KitFont)] = [
    ("Large title", .largeTitle), ("Title 2", .title2), ("Headline", .headline), ("Body", .body), ("Caption", .caption),
  ]

  var body: some View {
    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 32, verticalSpacing: 12) {
      GridRow {
        Text("Token").kitFont(.sectionHeader)
        Text("Mac").kitFont(.sectionHeader)
        Text("Apple TV").kitFont(.sectionHeader)
      }
      ForEach(styles, id: \.0) { name, style in
        GridRow {
          Text(name).kitFont(.callout).foregroundStyle(.kitSecondary)
          Text(name).kitFont(style).environment(\.kitIdiom, .mac)
          Text(name).kitFont(style).environment(\.kitIdiom, .tv)
        }
      }
      GridRow {
        Text("Row").kitFont(.callout).foregroundStyle(.kitSecondary)
        Text("\(Int(KitMetrics.row(.mac))) pt")
        Text("\(Int(KitMetrics.row(.tv))) pt")
      }
    }
    .padding(16)
    .kitSurface(.card)
  }
}
