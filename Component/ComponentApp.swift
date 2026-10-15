import ComponentKit
import SwiftUI

/// The ComponentKit catalog: every component in every state, light and dark.
@main
struct ComponentApp: App {
  var body: some Scene {
    WindowGroup("Component") {
      CatalogView()
        .componentKit(accent: .blue)
    }
  }
}

struct CatalogView: View {
  var body: some View {
    VStack(spacing: KitMetrics.gutter) {
      RichHeader("Repositories", meta: ["5 repositories", "2 with changes"], systemImage: "folder", hue: .blue)
        .kitCard()
      HStack {
        Button("Cancel") {}.buttonStyle(.kit)
        Button("Clone") {}.buttonStyle(.kitPrimary)
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.kitPanel)
  }
}
