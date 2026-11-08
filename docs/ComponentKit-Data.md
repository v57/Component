# ComponentKit: Data views

Larger views for data and whole screens: grids, diffs, run output, the command palette, the welcome screen, the
Settings window, secrets and codes, documents and meters. Part of [ComponentKit](ComponentKit.md).

## Grids

`KitGrid` is the data grid (database tables, string catalogs): striped rows on a field track, a raised selected row,
editable cells, sorting from the header, and outlines.

```swift
let columns: [KitGridColumn<Order>] = [
  KitGridColumn("Customer", value: { $0.customer }),
  KitGridColumn("Total", width: 90, alignment: .trailing, mono: true, value: { $0.total }),
]

KitGrid(orders, columns: columns, selection: $selected, sort: $sort)
  .rowContextMenu { ids in Button("Delete \(ids.count) Rows", role: .destructive) { delete(ids) } }
```

| API | What it is |
|---|---|
| `KitGrid(_:columns:selection:sort:rowState:children:expanded:rowHeight:primaryAction:)` | The grid. `children` makes it an outline; a `footer:` form adds a footer row. |
| `KitGridColumn` | A column: title, optional type chip and glyph, width, alignment, mono, and how a row's cell reads (`value:`, a key path, or any view per cell). `edit:` makes it editable in place. |
| `KitGridSort`, `KitGridRowState`, `KitGridRowHeight`, `KitGridInteraction` | The sorted column (the app sorts); a row's unsaved change (edited, deleted, new); row height; `.rows` for a file-browser style list. |
| `.rowContextMenu(_:)`, `.interaction(_:)`, `.rowDrag(_:)`, `.rowDropDestination(…)` | Menus, click behaviour, dragging rows out, dropping onto rows. |
| `ChangesCard`, `ChangeRow`, `ChangeValues` | Edits that wait for review, under the grid, each with Undo. |

## Diffs and conflicts

| API | What it is |
|---|---|
| `DiffLine`, `DiffLine.splitRows(_:)` | One line of a diff: kind, old and new numbers, text (plain or already highlighted), changed-word ranges. |
| `HunkCard(header:range:lines:layout:isStaged:summary:selection:stage:unstage:unstageLines:overflow:)` | A hunk as a card, unified or side by side (`DiffLayout`), with staging of lines. `DiffOverflow`: cut or scroll long lines. |
| `ConflictCard`, `ConflictSide`, `ConflictChoice`, `ConflictOrder` | A merge conflict with a Current / Incoming / Both choice. |
| `TextConflict(mine:theirs:mineHue:theirsHue:)` | Two copies of a text file that changed in two places, side by side. |

Syntax colours come from the app (Code's `CodeHighlighting` in the v57 apps); the kit draws what it's given.

## Output and code

| API | What it is |
|---|---|
| `RunBlocks(selection:content:)`, `RunBlock(_:command:id:systemImage:hue:status:progress:duration:warnings:output:stop:)` | Output nobody types into (actions, build, test and run consoles) as run blocks on a track, each headed by its command and live icon. |
| `KitCodeBlock(_:wraps:maxHeight:followsEnd:font:placeholder:)` | Read-only monospaced text on a well: a command, a fingerprint, a file. A `lines:` form shows a log lazily, one view per line. |
| `kitFollowsEnd(_:)` | Keeps a scroll view on its end as content arrives, the way a log reads. |
| `KitLineEditor`, `KitLineIssue` | Editable monospaced text with line numbers and a message under any line (filter rules, a hosts list). |
| `KitFileCell(_:isFolder:systemImage:)` | A file's or folder's name with a glyph for its kind, cut in the middle. |
| `KitFilePreview(name:data:)` | A file shown in place from bytes the app already has: pictures, PDFs, text. |

## Command palette

| API | What it is |
|---|---|
| `KitPalette(query:prompt:status:hints:maxHeight:dismiss:focusesOnAppear:content:)` | The command palette and quick open. A `scope:` form adds a scope pop-up. |
| `kitPaletteOverlay(isPresented:width:palette:)` | Shows a palette over the window, at the top. |
| `PaletteGroup`, `PaletteItem`, `PaletteHint`, `PaletteMenu` | A group of results as a card; one result (the match in bold); a key hint in the footer (`PaletteHint.standard`); the pop-ups. |

## Welcome screen

The welcome is the main screen's empty state: it fills the detail pane while nothing is selected (on iPhone, the
root's first screen). It isn't a separate window.

```swift
KitWelcome(appName: "Notes") {
  WelcomeAction("New Note", detail: "Start writing", systemImage: "square.and.pencil") { newNote() }
} recents: {
  ForEach(recents) { item in
    RecentItem(item.name, subtitle: item.path, date: item.opened.kitFormatted(.ago)) { open(item) }
  }
}
```

| API | What it is |
|---|---|
| `KitWelcome(appName:version:icon:emptyTitle:emptyMessage:searchText:searchPrompt:onDrop:actions:recents:)` | The welcome with one list. A form with `source:` and `projects:` shows Recent and Projects (`WelcomeSource`). |
| `.options(_:)`, `.listTitle(_:)`, `.emptyState(systemImage:status:)` | More options under the list; a name for the list; a live icon while the list waits on work. |
| `WelcomeAction(_:detail:systemImage:action:)` | One of the welcome's actions. |
| `RecentItem(_:subtitle:date:status:statusHue:systemImage:image:imageData:id:action:)` | A recent item or shared project. Pass `id:` when titles can repeat. |
| `KitAppIcon(size:)`, `KitAppIcon(image:size:isShaped:)`, `KitAppIcon(data:size:isShaped:)` | The running app's icon, or any app's from a picture. |

## Settings

```swift
Settings {
  KitSettings(selection: $pane, window: .hiddenTitleBar) {
    SettingsPane("General", systemImage: "gearshape") {
      FormCard { FormRow("Open at Login", systemImage: "power") { Toggle("Open at Login", isOn: $opensAtLogin) } }
    }
    SettingsPane("Languages", systemImage: "globe", section: "v57") { KitLanguagesSettings() }
  }
  .frame(width: 640, height: 520)
  .componentKit()
}
.windowStyle(.hiddenTitleBar)
```

| API | What it is |
|---|---|
| `KitSettings(selection:window:content:footer:)` | The Settings window: a kit sidebar of panes and the selected pane. `selection` is a pane's id (its title as written unless `id:` is given). |
| `KitSettingsWindow` | The Mac window it sits in: `.framed`, `.hiddenTitleBar` (the standard Settings window), `.titled`. iPad and iPhone ignore it. |
| `SettingsPane(_:systemImage:hue:section:value:id:content:)` | One pane: its sidebar row (title, glyph, section, a value on iPhone) and its content. |
| `KitLanguagesSettings()` | The Languages pane every app adds: the app's language and the languages it can download. |
| `KitNeverContacts`, `KitPrivacyParties`, `KitPrivacyParty` | The Privacy pane: the promise that the app sends nothing to its makers, advertisers or trackers (only where true), then every party it talks to and why. |
| `KitSecurityComparison`, `KitComparisonRow` | The Security pane's comparison with other apps of its kind. Each sentence about another app should be a fact from that app's own documentation. |

## Secrets and codes

| API | What it is |
|---|---|
| `KitSecretValue(_:label:isRevealed:copies:)`, `KitSecretValue(label:isRevealed:copies:value:)` | A secret in a row: dots until revealed, with Show and Copy. The closure form reads it on demand (from the keychain). Copying uses `KitPasteboard.copySecret`. |
| `kitSecretAccess(_:)` | Asks a closure (an app lock: Touch ID, Face ID) before any secret inside is shown or copied. |
| `KitOneTimeCode(period:showsSeconds:code:)` | A TOTP code with its countdown ring. |
| `KitSafetyCode(_:alphabet:groupSize:columns:)` | A safety code two people compare, in groups. |
| `KitWordGrid(_:columns:)` | Numbered words (a recovery phrase) on a well. |
| `KitQRCode(_:size:correction:)` | A QR code on a white plate, from the kit's own encoder. |
| `KitQRScanner(onScan:)` | A camera view that reads QR codes (iOS and macOS). The app declares `NSCameraUsageDescription`, and on the Mac the hardened runtime's camera entitlement. |
| `KitQRReader.codes(inImageData:)`, `KitQRReader.codesOnScreen()`, `canScanScreen` | QR codes from a picture; from the screen on the Mac (asks for screen recording the first time). |

## Documents and pages

| API | What it is |
|---|---|
| `KitPagePreview(data:aspectRatio:pages:maxPixelSize:)` | A scanned page drawn as paper. |
| `KitDocumentCard`, `KitDocumentGrid(minimumWidth:content:)` | Documents in a grid with a corner badge and a line under the title. |
| `KitPageStrip`, `KitPage` | A document's pages in a row, with Add Page. |
| `KitPageViewer`, `KitMarkedPage`, `KitPageHighlight`, `KitWatermark` | A page large with highlights, hidden parts as black boxes, and a watermark for a shared copy. |
| `KitPageCrop(imageData:aspectRatio:corners:)`, `KitPageCorners` | Corrects a page's corners on a photo. |

## Meters, stats and boards

| API | What it is |
|---|---|
| `MeterBar(segments:total:height:)`, `MeterLegend(segments:free:)`, `MeterSegment` | A stacked meter (storage) and its legend. |
| `MeterTile` | A usage figure as a live icon (CPU, GPU). |
| `KitStatCard(_:value:systemImage:hue:delta:deltaHue:detail:sparkline:action:)` | A number that sums something up, with a delta and an optional sparkline. |
| `KitSparkline` | A line through recent values. |
| `LaneBoard(content:)`, `Lane`, `LaneItem` | A board of lanes (tasks, workflows) side by side. |
