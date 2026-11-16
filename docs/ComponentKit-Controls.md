# ComponentKit: Controls

Buttons, toggles, fields, pickers, menus and the other controls. Part of [ComponentKit](ComponentKit.md).

<!-- platforms: macos ios linux=partial windows=partial android=planned -->

The kit draws its controls itself, so they look the same on every platform. Most are styles on SwiftUI's own views
(`Button`, `Toggle`, `TextField`), so VoiceOver, keyboard focus and `keyboardShortcut` work as usual. What is on sits
raised on a field track, the same way everywhere: the selected segment, an on chip, a stepper's value, a switch's knob.

```swift
enum Sort: String, KitOption, CaseIterable {
  case name, date
  var title: String { rawValue.capitalized }
}

struct ConnectForm: View {
  @State private var sort = Sort.name
  @State private var wraps = true
  @State private var port = ""

  var body: some View {
    VStack(alignment: .leading, spacing: KitMetrics.gutter) {
      KitSegmented(selection: $sort)
      Toggle("Wrap Lines", isOn: $wraps).toggleStyle(.kitSwitch)
      TextField("Port", text: $port).kitField(status: port.isEmpty ? .none : .valid, content: .number)
      HStack {
        Button("Cancel") {}.buttonStyle(.kit)
        Button("Connect") {}.buttonStyle(.kitPrimary).keyboardShortcut(.defaultAction)
      }
    }
  }
}
```
<!-- preview: connect-form -->

## Buttons

Pick a style; the kit draws the rest. Size follows `.controlSize` (small 28, regular 30, large 34pt), and
`role: .destructive` turns the label red. The primary is the one action a view leads with.

```swift
HStack {
  Button("Cancel") { close() }.buttonStyle(.kit)
  Button("Discard", role: .destructive) { discard() }.buttonStyle(.kit)
  Button("Clone") { clone() }.buttonStyle(.kitPrimary)
}
HStack {
  Button("Show All") { showAll() }.buttonStyle(.kitPlain)
  Button("Add", systemImage: "plus") { add() }.buttonStyle(.kitIcon)
  KitCopyButton("Copy Code", value: code).buttonStyle(.kit)
}
```
<!-- preview: buttons -->

| API | What it is |
|---|---|
| `.buttonStyle(.kit)` | A raised secondary button: white in light, one step of light in dark. |
| `.buttonStyle(.kitPrimary)` | The accent with a white label. Disabled, it turns into a raised button with quiet text rather than a faded accent. |
| `.buttonStyle(.kitPlain)` | Text in the accent, a fill on hover (links, Undo, Show All). |
| `.buttonStyle(.kitIcon)` | A square icon button for headers and rows (24pt, 32 on touch). Give it a title: VoiceOver reads it. |
| `.buttonStyle(.kitRound)`, `.kitRoundPrimary` | A round button on the toolbar's card ground; the accent-filled one (Send). `KitRoundButtonStyle(prominent:size:)` is the type. |
| `.buttonStyle(.kitTool)`, `.kitToolIcon` | A toolbar tool on its own, as inside a `ToolGroup`. |
| `.buttonStyle(.kitRow)` | A whole custom row as a button or `NavigationLink`, with the kit's press wash. |
| `KitButtonStyle(_:)`, `KitButtonStyle.Kind` | The style type: `.secondary`, `.primary`, `.plain`, `.icon`. |
| `.labelStyle(.kitTrailingIcon)` | Title, then the icon: a button that leaves the app ("Continue on GitHub ↗"). |
| `KitCopyButton(_:systemImage:value:isSecret:)` | Copies text and says "Copied" for a moment. `isSecret: true` copies through `KitPasteboard.copySecret`; `copiedWhen:` resets it when the value changes. |
| `KitSplitButton(_:systemImage:action:menu:)` | A main action with a chevron that opens the kit's menu of the others. |

## Toggles

A `Toggle` takes the kit's look from its style. A `ChipTrack` turns the toggles inside it into chips on one track.

```swift
@State private var remote = true
@State private var english = true
@State private var german = false
@State private var tag = Hue.orange

VStack(alignment: .leading, spacing: KitMetrics.gutter) {
  Toggle("Show Remote Branches", isOn: $remote).toggleStyle(.kitCheckbox)
  ChipTrack {
    Toggle("English", isOn: $english)
    Toggle("German", isOn: $german)
  }
  KitHuePicker(selection: $tag)
}
```
<!-- preview: toggles -->

| API | What it is |
|---|---|
| `.toggleStyle(.kitSwitch)` | A switch; the label leads. |
| `.toggleStyle(.kitCheckbox)` | A checkbox; the label follows. `kitMixed(_:)` draws the checkboxes inside as mixed (a group that is partly on). |
| `.toggleStyle(.kitChip)` | A chip. `ChipTrack(lazy:content:)` puts chips on one field track and wraps them; `lazy: true` keeps them on one line, built as they scroll in. |
| `kitLabelsHidden()` | Hides the labels of the kit's controls and the system's inside (`.labelsHidden()` alone doesn't reach the kit's). |
| `ChoiceCard(isOn:content:)`, `ChoiceCardLabel` | A selectable card (engines, templates). `Binding.picks(_:)` makes a row of cards pick one value. `kitChoiceCardStyle(.tall)` for visual choices. |
| `kitSelectedRing(_:hue:cornerRadius:)` | The ring a picked card wears, for a card of your own. |
| `KitHuePicker(selection:hues:)` | A row of colour swatches (`KitHuePicker.tagHues` by default); a `Hue?` binding adds a "no colour" swatch. |

## Fields

`kitField` puts a `TextField` on the field well: a filled, borderless field that takes the 2pt ring at half the
accent while focused. Its status says what the kit knows about the value, at the field's end.

```swift
TextField("https://", text: $url)
  .kitField(status: isChecking ? .checking : isValid ? .valid : .none, mono: true, content: .url)
TextField("Branch", text: $name)
  .kitField(status: exists ? .error : .none)
  .kitFieldError(exists ? "A branch with this name exists" : nil)
TextField("Port", text: $port).kitField(content: .number) { Text("TCP").kitFont(.caption) }
```

| API | What it is |
|---|---|
| `kitField(status:mono:content:)` | The field well with the focus ring. `FieldStatus`: `.none`, `.error` (the ring in red), `.live(WorkStatus, systemImage:)`, `.checking`, `.valid`. |
| `kitField(status:mono:content:trailing:)` | The same with a view at the field's end (a unit, a clear button). |
| `kitFieldError(_:)` | Says what is wrong in red under the field; pair it with `status: .error`. `nil` shows nothing. |
| `KitFieldContent` | What a field holds, for the keyboard, autocorrection, capitals and AutoFill: `.text`, `.verbatim`, `.url`, `.email`, `.number`, `.secret`, `.secretNumber` and more. `kitTextContent(_:)` applies it to a view that isn't a `kitField`. |
| `KitMultilineField(_:text:lines:)` | Text with paragraphs; grows between `lines` (3…14 by default), then scrolls. |
| `KitSearchField(text:prompt:status:count:)` | A search inside content; with `scope:` (a `KitOption` enum) it leads with a scope pop-up. |
| `SidebarSearchButton(text:isSearching:prompt:)` | The sidebar's search button that opens into a search line. `KitSidebar` shows it when given `searchText`. |

## Pickers, sliders and steppers

Conform an enum to `KitOption` and the pickers list its cases. `KitSegmented` shows every option on a track (the
selected one glides); `KitPicker` is a pop-up that opens the kit's menu.

```swift
enum Theme: String, KitOption, CaseIterable {
  case system, light, dark
  var title: String { rawValue.capitalized }
}

@State private var theme = Theme.system
@State private var volume = 0.6
@State private var fontSize = 13

FormCard {
  FormRow("Appearance", systemImage: "circle.lefthalf.filled") { KitPicker("Appearance", selection: $theme) }
  FormRow("Volume", systemImage: "speaker.wave.2") { KitSlider("Volume", value: $volume) }
  FormRow("Font Size", systemImage: "textformat.size") { KitStepper("Font Size", value: $fontSize, in: 9...24, unit: "pt") }
}
```
<!-- preview: pickers -->

| API | What it is |
|---|---|
| `KitOption` | A protocol for an app's enum: `title`, optional `systemImage` and `count`. |
| `KitSegment(_:value:systemImage:count:isEnabled:preview:)` | One option with a title, its value and an optional glyph or count, for pickers that take `segments:`. |
| `KitSegmented(selection:)`, `(selection:options:)`, `(selection:segments:)` | Segments on a field track; the selected one glides. A count is a plain number after the title. `kitSegmentedStyle(.wide)` shares the width. |
| `KitPicker(_:selection:)`, `(_:selection:options:)`, `(_:selection:segments:)`, `(_:selection:sections:)` | The pop-up picker on the field well. `kitPickerMaxWidth(_:)` caps its width. |
| `KitSlider(_:value:in:step:valueBubble:format:onEditingChanged:)` | A slider with a value bubble while dragging (`valueBubble: .visible` keeps it). `kitSliderStyle(.overlay)` over a video. |
| `KitStepper(_:value:in:step:unit:)` | − and + on one track with the value between them; they go quiet at the ends of the range. A `format:` variant writes the value itself. |

## Menus

Menus are drawn by the kit: a floating panel on the Mac, a window above the scene on iPad and iPhone. Their rows are
`Button`, `Toggle`, `Divider`, `KitMenuOptions`, `KitSubmenu` and the parts below. Don't use SwiftUI's `Menu` or
`.contextMenu` in kit views.

```swift
@State private var sort = "name"
@State private var foldersFirst = true

KitMenuButton("Sort", systemImage: "arrow.up.arrow.down") {
  KitMenuOptions(selection: $sort, options: [("Name", "name"), ("Date", "date"), ("Size", "size")])
  Divider()
  Toggle("Folders First", isOn: $foldersFirst)
}

FileRow(file)
  .kitContextMenu {
    Button("Open", systemImage: "arrow.up.right.square") { open(file) }
    Button("Rename…", systemImage: "pencil") { rename(file) }.kitMenuHint("↩")
    Divider()
    Button("Move to Trash", systemImage: "trash", role: .destructive) { trash(file) }
  }
```
<!-- preview: menus -->

| API | What it is |
|---|---|
| `kitMenu(isPresented:matchesWidth:content:)` | Opens a menu under the view while the binding is true. |
| `kitMenu(matchesWidth:content:)` | Makes the view a pop-up trigger: press to open, release over a row to pick. |
| `kitMenu(isPresented:at:content:)` | Opens a menu at a point in the view (a drop menu at the drop point). |
| `kitContextMenu(content:)` | The view's context menu: secondary click on the Mac, touch and hold on touch. |
| `KitMenuButton(_:systemImage:style:content:)` | A pop-up button: `.pill` (a raised card with a chevron) or `.button` (takes the button style around it). |
| `KitMenuOptions(selection:options:)` | Rows that pick one value; the picked one is checked. Takes `(title, value)` pairs, `KitSegment`s or `KitOption` values. |
| `KitSubmenu(_:value:systemImage:content:)` | A row that opens a menu beside it ("Sort by ▸"), with its current value at the end. |
| `KitMenuSection(_:value:content:)` | A group of rows under a small header. |
| `KitMenuFooter(_:subtitle:message:systemImage:)` | What the menu acts on, under a divider at its end. |
| `KitMenuShare` | A row that opens the system share sheet once the menu has closed. |
| `kitMenuHint(_:)`, `kitMenuDetail(_:)` | A shortcut or count at a row's end; a second line under its title. |
| `kitMenuPreview(_:isDanger:)`, `KitMenuPreview` | What picking a row does, in a panel at the menu's end (the Mac). |
| `KitMenuFilter(_:total:empty:)`, `kitMenuFilter(_:kind:)` | A filter field for a long list and the words a row matches by. |
| `KitMenuGrid(columns:content:)`, `KitMenuTile` | Tiles for picking one of many things of one kind (devices, simulators). |
| `KitOpenWithRow(_:)`, `KitOpenApp` | Open With as one row: the first app in words, the others as icons. `KitOpenApp.app(…)`, `.defaultApp(opening:)`, `.fileManager(revealing:)`, `.terminal(at:)` make the entries. |
| `KitMenu(minWidth:content:)` | The menu as drawn, for a mockup or preview. |

In a system toolbar (`.toolbar`, iOS 26 and later) SwiftUI turns a bare `Button` into a native bar button and drops
the modifiers that anchor a kit menu. Put the trigger in a kit view (`ToolGroup`, `KitMenuButton`), ideally in a
`KitToolbarItem`, or use the kit's own toolbar (`.kitToolbar`).

## Tabs, paths and keys

```swift
KitTabStrip(tabs: documents.map { KitTab(id: $0.id, title: $0.name, isEdited: $0.isDirty) },
            selection: $current, onClose: { close($0) }, onAdd: { newQuery() })
KitPathBar(["v57", "Git", "Shared", "Components.swift"])
KeyHints([("⌘↩", "runs"), ("Tab", "completes"), ("esc", "closes")])
```

| API | What it is |
|---|---|
| `KitTabStrip(tabs:selection:onClose:onAdd:onMove:)`, `KitTab` | Editor or query tabs on a card as wide as its tabs; edited dots, preview tabs in italics, reordering. A single tab isn't shown. `tabContextMenu(_:)`, `onTabDoubleClick(_:)`. |
| `KitPathBar(components:)`, `KitPathBar(_:)`, `KitPathItem` | Breadcrumbs; the last crumb is the current one. |
| `Keycap(_:)`, `Keycaps(_:)` | A key, or a shortcut drawn as keys. `Keycaps.label(_:)` writes a shortcut as text the platform's way: `⌘↩` on the Mac, `Ctrl+Enter` on Windows and Linux. |
| `KeyHints(_:)` | A wrapping line of "keys + what they do" hints. |

See [Containers](ComponentKit-Containers.md#toolbar) for the toolbar's `ToolGroup`, `KitToolbar` and `kitToolOn(_:)`.

## Related

- [Containers](ComponentKit-Containers.md): forms (`FormCard`, `FormRow`) that hold these controls, and the toolbar.
- [Status and badges](ComponentKit-Status.md): `WorkStatus`, which a field's `.live` status and a picker's rows carry.
