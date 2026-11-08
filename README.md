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

## Libraries

| Library | Purpose | Platforms | Import |
|---|---|---|---|
| [ComponentKit](docs/ComponentKit.md) | The shared design: tokens, surfaces, controls, menus, sidebar, sections, toolbar, forms, sheets, badges, live status, motion, data views and platform helpers (`KitDesktop`, `KitPasteboard`). Split by area into [Foundation](docs/ComponentKit-Foundation.md), [Controls](docs/ComponentKit-Controls.md), [Containers](docs/ComponentKit-Containers.md), [Status](docs/ComponentKit-Status.md) and [Data](docs/ComponentKit-Data.md). | macOS 14, iOS/iPadOS 17, tvOS 18, visionOS 2; Windows and Linux on v57/SwiftUI | `import ComponentKit` |

ComponentKit depends on v57/Platform's `PlatformLanguages` (downloadable languages); apps don't import it for the
kit. The catalog's `ComponentApp` library (in `App/`) is the catalog app itself, not for apps.
