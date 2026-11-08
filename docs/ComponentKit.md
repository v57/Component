# ComponentKit

ComponentKit is the one design every v57 app shares: the sidebar, toolbar, buttons, fields, menus, forms, sheets,
badges, live status and motion. The kit draws its controls itself instead of using system controls, so an app looks
the same on macOS, iPadOS, iOS and Apple TV, and (through v57/SwiftUI) on Windows and Linux.

It is a SwiftUI library. An app passes in data and closures; the kit decides how things look and move. It has no app
models and no persistence of its own beyond a few view settings (`KitStorage`, `KitIDSet`). It is not a general
widget toolkit with themes: an app picks only its accent colour, and everything else comes from the kit's tokens.

The `Component` app in this repository is the catalog: every component in every state, light and dark, on the Mac,
iPad, iPhone and Apple TV. Use it to see a component before reading its source.

Pages by area:

| Page | What it covers |
|---|---|
| [Foundation](ComponentKit-Foundation.md) | Tokens (colours, hues, metrics, type, motion), surfaces, idiom, storage, dates, layouts, platform helpers (`KitDesktop`, `KitPasteboard`, `KitDevice`) |
| [Controls](ComponentKit-Controls.md) | Button and toggle styles, fields, pickers, segmented controls, sliders, steppers, menus, search, tabs, keycaps |
| [Containers](ComponentKit-Containers.md) | Sidebar, sections, toolbar, panes and splits, inspector, forms, sheets and other overlays, banners, toasts, empty states, tooltips, drag and drop |
| [Status and badges](ComponentKit-Status.md) | `WorkStatus`, live icons, effects, status pills, counts, chips, progress bars, refs, avatars |
| [Data views](ComponentKit-Data.md) | Grids, diffs and conflicts, run blocks, code blocks, the command palette, the welcome screen, Settings, secrets, QR codes, documents, meters |

## Getting started

Add the package and the product:

```swift
// Package.swift
dependencies: [
  .package(url: "https://github.com/v57/Component.git", branch: "main"),
],
targets: [
  .target(name: "MyApp", dependencies: [.product(name: "ComponentKit", package: "Component")]),
]
```

In an Xcode project, add the same URL as a package dependency (branch `main`) and link `ComponentKit`.

ComponentKit depends on v57/Platform (its `PlatformLanguages` library, for downloadable languages). With
`V57_LOCAL=1` in the environment the package takes `../Platform` (and `../SwiftUI` on Windows and Linux) from the
checkouts next to this one instead of GitHub; an `<App>-Local.xcworkspace` lists the local checkouts for Xcode.

A minimal app: one window with a sidebar of notes and a detail pane.

```swift
import ComponentKit
import SwiftUI

@main struct NotesApp: App {
  var body: some Scene {
    WindowGroup { ContentView().kitToasts().componentKit(accent: .orange) }
  }
}

struct ContentView: View {
  @State private var selection: String?
  @State private var columns = NavigationSplitViewVisibility.all
  let notes = ["Groceries", "Ideas", "Trip"]

  var body: some View {
    KitSidebarSplit(selection: $selection, columnVisibility: $columns) {
      KitSidebar(selection: $selection, columnVisibility: $columns) {
        KitSection("Notes", meta: ["\(notes.count) notes"], systemImage: "note.text") {
          ForEach(notes, id: \.self) { SidebarRow(value: $0, $0, systemImage: "doc.text") }
        }
      }
    } detail: { name in
      Text(name).kitFont(.title1)
    } empty: {
      EmptyState(systemImage: "note.text", title: "No Note Selected", message: "Pick a note in the sidebar.")
    }
  }
}
```

`KitSidebarSplit` is a split view on the Mac and iPad and one navigation stack on iPhone, where the selection is
pushed onto the sidebar list.

## Setting up a scene

Put `.componentKit(accent:)` once on each scene's root view. It sets the accent (the only colour an app picks), the
kit's type and ground, and the window rules: an inactive window goes still (no animation, gray selections) and
Reduce Motion keeps fades but drops movement. It also installs the overlay host that kit sheets, dialogs, menus and the
palette present on. Without it, those overlays have nowhere to show.

```swift
WindowGroup {
  ContentView()
    .kitLanguages()                       // rebuild when a language pack changes (optional)
    .kitToasts()                          // host for `showToast` (optional)
    .kitColorScheme(appearance)           // the app's Light / Dark / System setting (optional)
    .componentKit(accent: .orange)
}
```

| Call | What it does |
|---|---|
| `componentKit(accent:)` | Puts the view tree on the kit. `accent` is any `Color`; `nil` keeps the default blue. `Color.kitHubRed` is the red the Hub family's apps use. |
| `kitColorScheme(_:)` | The window's appearance: `.light`, `.dark` or `nil` for the system's. Use it in place of `preferredColorScheme`. |
| `kitToasts()` | Hosts toasts for the views below; show one with `@Environment(\.showToast)`. |
| `kitLanguages()` | Rebuilds the scene when the app's strings change (a language downloaded or removed). Goes inside `componentKit`. |
| `KitLanguages.start(sources:)` | Names the app's string sources for downloadable languages. Call it first in the `App`'s `init`. |

Environment values the kit sets and components read: `kitAccent`, `kitWindowIsActive`, `kitIdiom`,
`kitIncreaseContrast`, `kitAppearsActive`. Apps read them when they draw something of their own; they don't pass
them down.

## How the API is shaped

- **Styles and modifiers on SwiftUI's own views first**: `.buttonStyle(.kit)`, `.toggleStyle(.kitSwitch)`,
  `.kitField()`, `.kitSurface(.card)`, `.effect(.success, on:)`, `.status(_:)`, `.kitFont(.caption)`.
- **Environment for what is set once**: the accent, the window's active state, the idiom, toasts, the dismiss
  action of an overlay (`@Environment(\.kitDismiss)`).
- **`@ViewBuilder` containers for structure**: `KitSection(…) { rows }`, `RichHeader(…) { actions }`,
  `FormCard { FormRow(…) { control } }`, `KitSheet(…) { body } footer: { buttons }`.
- **Convenience initializers** cover the common case (an SF Symbol name, a `[String]` meta line, a `Hue`); a generic
  `@ViewBuilder` initializer covers the rest.
- **Overlays, never system sheets.** `.kitSheet(isPresented:)` and `.kitSheet(item:)` take the same bindings as
  `.sheet`. Close an overlay from inside with `@Environment(\.kitDismiss)`: SwiftUI's `dismiss` doesn't reach it.
- **Menus are the kit's**: `.kitMenu`, `.kitContextMenu`, `KitMenuButton`, `KitPicker`. No system `Menu` inside
  kit components.
- **Work state lives in the live icon** (`LiveIcon`, `WorkStatus`), not in a spinner or a bare progress bar.
- **Long lists are lazy**: `KitLazyStack` for a few heavy views (a page's sections), `LazyVStack` for thousands of
  light rows.

### Text and localization

Every title, subtitle, message, help line, prompt and button label comes in two overloads, as SwiftUI's `Text` does:

- a `LocalizedStringKey` (a string literal), looked up in the main bundle, where the app's strings, its kits' strings
  and a downloaded language pack meet;
- `some StringProtocol` (a `String` value), shown as it is.

All texts of one call take the same kind. If you mix a literal with a `String` value, Swift picks the verbatim
overload and the literal is no longer translated. Interpolate the value to keep the literal a key:

```swift
.kitNotice("Couldn't Save", isPresented: $failed, message: "\(error.localizedDescription)")
```

Data (names, paths, `meta` lines, values, code) is always `String` and never looked up.

## Platform notes

| Platform | State |
|---|---|
| macOS 14+ | Primary platform. Overlays and menus float in panels of their own; tooltips, hover, keyboard focus and Tab cycling in sheets work as on the Mac. |
| iPadOS 17+ / iOS 17+ | Supported. Touch sizes (44pt rows), menus and overlays in a window above the scene, an opaque top bar once content scrolls under it on iPhone, `KitSidebarSplit` as one stack on iPhone. |
| tvOS 18+ | Supported (`KitIdiom.tv`): the Mac's layout at twice its size, lit by focus instead of a pointer (`kitHoverEffect`, `kitFocusEffect(in:)`). SwiftUI modifiers tvOS lacks (`keyboardShortcut`, `onHover`, `draggable`, `popover`…) have no-op stand-ins in the kit so shared code builds. |
| visionOS 2+ | Builds. No scroll edge effect, shared toolbar background or impact haptics there. |
| Windows | Builds on v57/SwiftUI (the WinUI backend) with the Mac's desktop idiom. The kit's toolbar sits in the title bar row with the window's menus as tools at its start; shortcuts read the Windows way (`Ctrl+Shift+O`). File panels, the pasteboard and opening files go through v57/SwiftUI. The catalog builds as `ComponentWinUI`. |
| Linux | Builds on v57/SwiftUI (the GTK backend) with the Mac's desktop idiom; the catalog runs as the `Component` executable. File dialogs, the pasteboard and `KitFont.monospacedFamilies()` (fontconfig) have Linux backends. |
| Android | Not yet. |

Apple-only features say so in their docs: the QR camera scanner (`KitQRScanner`) runs on iOS and macOS, screen
scanning (`KitQRReader.codesOnScreen()`) on the Mac only, PDF previews where PDFKit exists, and app lookups
(`KitDesktop.appURL`, `appIcon`, `apps(toOpen:)`) only on the Mac.

There is no `AppKit` or `UIKit` type in the public API. When a platform call is needed, the kit hides it behind its own
API (see [Platform helpers](ComponentKit-Foundation.md#platform-helpers)).

## Testing

Run the kit's tests (Swift Testing) from the repository root:

```bash
swift test
swift test --filter MenuTests        # one suite
```

SwiftUI builds no accessibility tree in a test process, so the tests check layout and state, not what VoiceOver
reads. Check that in the running catalog.

Builds for the other Apple platforms:

```bash
swift build --triple arm64-apple-ios17.0-simulator --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
swift build --triple arm64-apple-tvos18.0-simulator --sdk "$(xcrun --sdk appletvsimulator --show-sdk-path)" --scratch-path .build-tvos
```

The catalog (`Component.xcodeproj`, scheme `Component`) is the visual test bench. Its DEBUG launch arguments open any
page in any state: `--page <id>`, `--section <title>`, `--dark` / `--light`, `--idiom mac|pad|phone|tv`,
`--accent <name>`, `--contrast`, `--inactive`, `--open-sheet <name>` and more; see the repository's `CLAUDE.md`.
`Scripts/hitch-test.sh` scrolls every page and reports animation hitches.

For an app's own screenshots and UI tests, the kit reads two launch arguments (`KitLaunchOptions`):

- `-KitAppearsActive YES` draws every window as the focused one, so selections keep the accent in captures.
- `-KitShowsTooltip <title>` shows the `kitHelp` tooltip with that title as its view appears.

The kit offers no test fakes; components take plain data and closures, so an app tests its own models directly.
