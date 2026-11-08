# ComponentKit: Foundation

Tokens, surfaces, the idiom, small utilities and the platform helpers. Part of [ComponentKit](ComponentKit.md).

Components take tokens only: colours from `KitColor` and `Hue`, sizes from `KitMetrics`, type from `KitFont`, motion
from `Animation.kit*`. An app drawing its own views should do the same, so they match the kit's in light, dark,
Increase Contrast and on every idiom.

```swift
VStack(alignment: .leading, spacing: 4) {
  Text("Build").kitFont(.headline)
  Text("12 targets").kitFont(.caption)
}
.padding(KitMetrics.cardPadding)
.kitSurface(.card)
.foregroundStyle(.kitLabel)
```

## Colours

| API | What it is |
|---|---|
| `KitColor` | A palette colour with a light and a dark value, resolved where it's drawn. A `ShapeStyle`, so it goes in `.foregroundStyle` and `.fill`. `color(dark:)` gives one appearance's `Color` outside a view. |
| `.kitWindow`, `.kitSidebar`, `.kitPanel` | Grounds: content panes, the sidebar, secondary panes (inspectors, sheets, settings). |
| `.kitCard`, `.kitRaised`, `.kitElevated` | A card on a ground; what is "on" on a track (selected segment, on chip); floating things (menus, toasts). |
| `.kitLabel`, `.kitSecondary`, `.kitTertiary`, `.kitQuiet`, `.kitLink` | Text colours. |
| `.kitSeparator`, `.kitBorder`, `.kitFill`, `.kitFillSoft`, `.kitField`, `.kitHover`, `.kitPress`, `.kitScrim` | Lines, neutral fills, field wells, interaction washes and the dim under an overlay. |
| `Hue` | The system hues by meaning: `.accent`, `.blue`, `.green`, `.orange`, `.red`, `.yellow`, `.teal`, `.indigo`, `.purple`, `.pink`, `.brown`, `.gray`. `fill` for dots and icons, `text` for text on the kit's grounds, `soft(_:)` for tinted grounds. `color(in:)` and `textColor(in:)` resolve one to a `Color` for APIs that take only a `Color`. |
| `.kitAccent`, `.kitAccentText` | The app's accent (set with `componentKit(accent:)`) as a fill and as text. |
| `StableHue.pick(_:)` | A hue for a name that stays the same across launches (avatars, project tiles). |
| `Hue.forStatus(_:)`, `Hue.forTypeName(_:)`, `Hue.lane(_:)` | Hues for a status word, a value type's name, and the n-th lane of a graph or board. |
| `Color(rgb:)`, `Color(rgb:opacity:)`, `Color(hex:)`, `hex(in:)` | Colours from data (a theme file, a stored value) and back to CSS hex. Not for components. |
| `Color.kitHubRed` | The red the Hub family's apps take as their accent. |

Dark mode is "steps of light, tracks as wells": cards are opaque, what is on is raised, fields and tracks are dark
wells, and there are no resting shadows. `Surface` handles this.

## Surfaces and cards

| API | What it is |
|---|---|
| `Surface` | `.card`, `.raised`, `.floating`, `.field`, `.fill`. |
| `kitSurface(_:cornerRadius:)` | Draws a surface behind the view (with its shadow in light mode). `KitMetrics.radiusCapsule` makes a capsule. |
| `kitCard(padding:)` | Pads the content and puts it on a card with 12pt corners. |
| `kitCardSlice(_:of:cornerRadius:)`, `KitCardSlice` | Draws one row's slice of a card that spans many lazy rows. |
| `LazyCard(_:spacing:row:)` | A card over lazy rows; put it in your own `LazyVStack(spacing: 0)`. |
| `kitHoverEffect(in:)`, `kitFocusEffect(in:)`, `kitHoverTiltDisabled(_:)` | The tilt-and-light effect for a finger, a press and Apple TV focus; `kitFocusEffect` makes a non-button focusable on tvOS. |
| `.buttonStyle(.kitHoverEffect)`, `.labelStyle(.kitHoverTile)` | A plain button whose presses reach the hover effects in its label; an icon card with the title under it. |
| `kitBar()` | Marks a view as a bar that content scrolls under, so its cards and wells draw opaque. |

Rounded views never touch: keep an 8pt gutter (`KitMetrics.gutter`) between rounded shapes and from the window
edge, or merge them into one shape.

## Metrics

`KitMetrics` holds the kit's sizes. On Apple TV every size is twice the Mac's.

- Corner radii: `radiusXS` (5), `radiusSmall` (7), `radius` (8), `radiusLarge` (10), `radiusCard` (12), `radiusXL`
  (14), `radiusWindow` (16), `radiusOverlay` (20), `radiusCapsule`.
- Spacing: `gutter` (8), `cardPadding` (6).
- Controls: `controlSmall` (28), `controlRegular` (30), `controlLarge` (34).
- Rows, per idiom: `row(_:)`, `twoLineRow(_:)`, `tableRow(_:)`, `rowTile(_:)`.
- Columns: `sidebarWidth`, `sidebarMinWidth(_:)`, `sidebarMaxWidth(_:)`, `inspectorWidth`, `titlebarHeight`.

## Idiom

`KitIdiom` is where the kit lays out: `.mac` (dense desktop metrics; Windows and Linux use it too), `.pad` and
`.phone` (touch sizes, 44pt rows), `.tv` (the Mac's layout at twice its size, lit by focus). Read it with
`@Environment(\.kitIdiom)`. `isTouch` is true on iPad and iPhone; `scale` is 2 on Apple TV and 1 elsewhere, for an
app's own sizes.

## Type

`KitFont` is the kit's type scale (13pt body on the Mac, 17pt on iPad and iPhone): `.largeTitle`, `.title1`,
`.title2`, `.title3`, `.headline`, `.body`, `.callout`, `.caption`, `.sectionHeader`, `.mono`, `.monoSmall`, `.code`.
Apply a style with `.kitFont(_:)`, which sets size, weight, tracking and, for captions and section headers, the quiet
colour. `KitFont.font` is the Mac-size `Font`. `KitFont.monospacedFamilies()` lists installed fixed-pitch font
families (AppKit's font manager on the Mac, fontconfig on Linux), for an editor's font picker.

## Motion

| API | What it is |
|---|---|
| `Animation.kit` | The one animation for selection, pages, icons and text (smooth, 0.25 s). |
| `.kitFast`, `.kitSlow`, `.kitSpring` | Press and hover (0.15 s); windows, sheets and the sidebar (0.35 s); things that land with a bounce. |
| `AnyTransition.page`, `.detail`, `.row` | Screens and panels, a detail pane replacing another, a row arriving or leaving. |
| `withKitAnimation(_:_:)` | `withAnimation` with the kit's animation. |
| `kitAnimation(_:_:)` | Animates changes of a value with the kit's animation. |
| `kitAppearDelay(_:)` | Shows a view only after it has been on screen for a moment: a loading state that a quick load never shows. |

The root modifier stills animations in an inactive window and shortens them under Reduce Motion, so components just
animate.

## Utilities

| API | What it is |
|---|---|
| `KitStorage` | A `UserDefaults` value like `@AppStorage` that updates a view only when its own key changes (`Bool`, `Int`, `Double`, `String`, `Data`, and `RawRepresentable` with a `String` or `Int` raw value). |
| `KitIDSet` | A set of ids that `@AppStorage` or `KitStorage` can keep (one string): an outline's closed groups. |
| `Date.kitFormatted(_:relativeTo:)`, `KitDateStyle` | Dates written the same in every app: `.ago` ("3 min ago"), `.clock`, `.day`, `.dayAndTime`, `.elapsed`. |
| `KitDuration.format(_:seconds:)`, `KitDuration.timeLeft(_:)` | "42 s", "2 h 10 min"; "about 3 min left". |
| `KitFlowLayout(spacing:lineSpacing:alignment:)` | A `Layout` that wraps its views into lines: tags, chips, key hints. |
| `KitPackedGrid(unit:spacing:maxColumns:)`, `kitGridSpan(_:)` | Cards of any height packed into columns; a card can span several. |
| `KitImageData(data:maxPixelSize:)`, `KitImageFile(url:maxPixelSize:)` | Pictures decoded off the main thread with a placeholder until ready; `kitPreloadAvatars(_:size:)` decodes a list's avatar pictures ahead. |

```swift
@KitStorage("sidebar.showsExtensions") private var showsExtensions = false

Text(session.started.kitFormatted(.elapsed))     // "42 min"
Text(KitDuration.timeLeft(remaining))            // "about 3 min left"
```

## Platform helpers

These hide platform frameworks (AppKit, UIKit, Windows and Linux file dialogs) so app code needs none.

### KitDesktop

| Call | What it does |
|---|---|
| `open(_:)` | Opens a file in its default app, or a link in the browser. |
| `reveal(_:)` | Shows files selected in the file manager. `fileManagerName` ("Finder", "Explorer") and `fileManagerIcon` label it. |
| `open(_:withApp:)` | Opens files and folders in the app with a bundle identifier. |
| `openTerminal(at:)` | Opens a terminal in a folder: Terminal on the Mac, Windows Terminal (else PowerShell) on Windows. |
| `chooseFolders(prompt:message:directory:allowsMultipleSelection:canCreateDirectories:name:)` | The system's open panel for folders; empty when cancelled and on iOS. |
| `chooseFiles(title:prompt:message:contentTypes:directory:canChooseFolders:allowsMultipleSelection:)` | The open panel for files; empty when cancelled and on iOS (use `fileImporter` there). |
| `chooseSaveLocation(title:prompt:name:directory:)` | The save panel; `nil` when cancelled and on iOS. |
| `saveCopy(of:title:prompt:)` | Saves a copy of a file or folder where the user picks: the save panel on the desktop, the system exporter on iPhone and iPad. |
| `isAppInstalled(_:)`, `appURL(_:)`, `appIcon(_:)`, `defaultApp(for:)`, `apps(toOpen:prefix:)`, `icon(forFile:)` | App and file lookups for "Open in …" items. The Mac only; `nil` or empty elsewhere. |
| `isAppRunning(_:)` | Whether an app is running (the Mac; false elsewhere). |
| `onActivation(_:)` | Calls a handler each time the app becomes active, until the returned object is released. The Mac, iPhone and iPad; never called on Windows and Linux. |
| `modifierKeys` | The modifier keys held now. On Windows and Linux Ctrl counts as Command. |

```swift
Button("Show in \(KitDesktop.fileManagerName)", systemImage: "folder") { KitDesktop.reveal([file]) }

let urls = await KitDesktop.chooseFiles(prompt: "Open", contentTypes: [.movie], allowsMultipleSelection: true)
```

### KitPasteboard

- `copy(_:)` puts text on the general pasteboard.
- `copySecret(_:expiresAfter:)` puts a secret on it that stays on this device (no Universal Clipboard, marked
  concealed so clipboard managers skip it) and is cleared after 90 seconds by default, unless something else was
  copied since.
- `string()` reads text. Read it only when the person acts: on iOS reading may show the system's paste prompt.

Apple TV has no pasteboard: copying does nothing and `string()` is `nil`. Windows and Linux go through v57/SwiftUI's
pasteboard.

### KitDevice and keys

- `KitDevice.name` ("Mac", "iPad", "iPhone", "Apple TV", "PC" on Windows, "Computer" on Linux), `nameInSentence` and
  `systemImage`, for labels such as "On My Mac".
- `Keycaps.label(_:)` writes a shortcut the platform's way: `⌘↩` on the Mac, `Ctrl+Enter` on Windows and Linux.

### Launch options and appearance

- `KitLaunchOptions.appearsActive` (`-KitAppearsActive YES`) and `KitLaunchOptions.shownTooltip`
  (`-KitShowsTooltip <title>`) are for screenshots; see [Testing](ComponentKit.md#testing).
- `kitColorScheme(_:)` sets the window's appearance (see [Setting up a scene](ComponentKit.md#setting-up-a-scene)).

### Apple TV stand-ins

On tvOS the kit declares no-op versions of SwiftUI modifiers tvOS lacks (`keyboardShortcut`, `swipeActions`,
`dropDestination`, `draggable`, `listRowSeparator`, `scrollContentBackground`, `textSelection`, `onHover`), and
`popover` shows its content as a sheet, so code shared with the Mac builds unchanged. Types tvOS lacks
(`DragGesture`, `TextEditor`) still need an `#if !os(tvOS)` in the app.
