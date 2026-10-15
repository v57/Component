# Component

ComponentKit is the one design the v57 apps share: their sidebars, toolbars, buttons, forms, sheets, badges, live
status and motion. It's drawn by the kit rather than by system controls, so it looks the same on macOS and iPadOS
(and later on Android, Windows and Linux through the SwiftUI reimplementation).

The `Component` app is the catalog: every component in every state, light and dark.

```swift
import ComponentKit

@main struct MyApp: App {
  var body: some Scene {
    WindowGroup { ContentView().componentKit(accent: .orange) }
  }
}

KitSection("Repositories", meta: ["5 repositories", "2 with changes"], systemImage: "folder", hue: .blue) {
  ForEach(repositories) { SidebarRow($0.name, systemImage: "folder") }
}
Button("Clone") { … }.buttonStyle(.kitPrimary)
LiveIcon(systemImage: "arrow.up", status: .working(progress: 0.4))
```

Requires macOS 14 or iOS 17. MIT license.
