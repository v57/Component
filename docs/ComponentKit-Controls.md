# ComponentKit: Controls

Buttons, toggles, fields, pickers, menus and the other controls. Part of [ComponentKit](ComponentKit.md).

The kit draws its controls itself, so they look the same on every platform. Most are styles on SwiftUI's own views
(`Button`, `Toggle`, `TextField`), so VoiceOver, keyboard focus and `keyboardShortcut` work as usual.

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

## Buttons

| API | What it is |
|---|---|
| `.buttonStyle(.kit)` | A raised secondary button. Size follows `.controlSize` (small 28, regular 30, large 34); `role: .destructive` turns it red. |
| `.buttonStyle(.kitPrimary)` | The accent with a white label: the one action a view leads with. |
| `.buttonStyle(.kitPlain)` | Text in the accent, a fill on hover (links, Undo, Show All). |
| `.buttonStyle(.kitIcon)` | A square icon button for headers and rows. |
| `.buttonStyle(.kitRound)`, `.kitRoundPrimary` | A round button on the toolbar's card ground; the accent-filled one (Send). |
| `.buttonStyle(.kitTool)`, `.kitToolIcon` | A toolbar tool on its own, as inside a `ToolGroup`. |
| `.buttonStyle(.kitRow)` | A whole custom row as a button or `NavigationLink`, with the kit's press wash. |
| `KitButtonStyle(_:)`, `KitButtonStyle.Kind` | The style type: `.secondary`, `.primary`, `.plain`, `.icon`. |
| `.labelStyle(.kitTrailingIcon)` | Title, then the icon: a button that leaves the app ("Continue on GitHub ↗"). |
| `KitCopyButton(_:systemImage:copiedTitle:value:isSecret:copiedWhen:)` | Copies text and shows "Copied" for a moment. |
| `KitSplitButton(_:systemImage:action:menu:)` | A main action with a chevron that opens the kit's menu of the others. |

## Toggles

| API | What it is |
|---|---|
| `.toggleStyle(.kitSwitch)` | A switch; the label leads. |
| `.toggleStyle(.kitCheckbox)` | A checkbox; the label follows. `kitMixed(_:)` draws the checkboxes inside as mixed. |
| `.toggleStyle(.kitChip)` | A chip; put several on a `ChipTrack { … }`. |
| `kitLabelsHidden()` | Hides the labels of the kit's controls and the system's inside (`.labelsHidden()` alone doesn't reach the kit's). |
| `ChoiceCard(isOn:content:)`, `ChoiceCardLabel` | A selectable card (engines, templates). `Binding.picks(_:)` makes a row of cards pick one value. `kitChoiceCardStyle(.tall)` for visual choices. |
| `kitSelectedRing(_:hue:cornerRadius:)` | The ring a picked card wears, for a card of your own. |
| `KitHuePicker(selection:hues:)` | A row of colour swatches; a `Hue?` binding adds a "no colour" swatch. |

## Fields

| API | What it is |
|---|---|
| `kitField(status:mono:content:)` | Puts a `TextField` on the kit's field well with the focus ring. `FieldStatus`: `.none`, `.error`, `.live(WorkStatus, systemImage:)`, `.checking`, `.valid`. |
| `kitField(status:mono:content:trailing:)` | The same with a view at the field's end (a unit, a clear button). |
| `kitFieldError(_:)` | Says what is wrong in red under the field; pair it with `status: .error`. |
| `KitFieldContent` | What a field holds, for the keyboard, autocorrection, capitals and AutoFill: `.text`, `.verbatim`, `.url`, `.email`, `.number`, `.secret`, `.secretNumber` and more. `kitTextContent(_:)` applies it to a view that isn't a `kitField`. |
| `KitMultilineField(_:text:lines:)` | Text with paragraphs; grows between `lines`, then scrolls. |
| `KitSearchField(text:prompt:status:count:)` | A search inside content; with `scope:` and `scopes:` (a `KitOption` enum) it leads with a scope pop-up. |
| `SidebarSearchButton(text:isSearching:prompt:)` | The sidebar's search button that opens into a search line. `KitSidebar` shows it when given `searchText`. |

## Pickers and value controls

| API | What it is |
|---|---|
| `KitOption` | A protocol for an app's enum: `title`, optional `systemImage` and `count`. The pickers list its cases. |
| `KitSegment(_:value:systemImage:count:isEnabled:preview:)` | One option with a title, its value and optional glyph or count, for pickers that take `segments:`. |
| `KitSegmented(selection:)`, `(selection:options:)`, `(selection:segments:)` | Segments on a field track; the selected one glides. `kitSegmentedStyle(.wide)` shares the width. |
| `KitPicker(_:selection:)`, `(_:selection:options:)`, `(_:selection:segments:)` | The pop-up picker (a select) that opens the kit's menu. `kitPickerMaxWidth(_:)` caps its width. |
| `KitSlider(_:value:in:step:valueBubble:format:onEditingChanged:)` | A slider with a value bubble while dragging. `kitSliderStyle(.overlay)` over a video. |
| `KitStepper(_:value:in:step:unit:)` | − and + on one track with the value between them; a `format:` variant writes the value itself. |

## Menus

Menus are drawn by the kit: a floating panel on the Mac, a window above the scene on iPad and iPhone. Their rows are
`Button`, `Toggle`, `Divider`, `KitMenuOptions`, `KitSubmenu` and the parts below.

```swift
KitMenuButton("Sort", systemImage: "arrow.up.arrow.down") {
  KitMenuOptions(selection: $sort, options: Sort.allCases)
}

FileRow(file)
  .kitContextMenu {
    Button("Open", systemImage: "arrow.up.right.square") { open(file) }
    Divider()
    Button("Move to Trash", systemImage: "trash", role: .destructive) { trash(file) }
  }
```

| API | What it is |
|---|---|
| `kitMenu(isPresented:matchesWidth:content:)` | Opens a menu under the view while the binding is true. |
| `kitMenu(matchesWidth:content:)` | Makes the view a pop-up trigger: press to open, release over a row to pick. |
| `kitMenu(isPresented:at:content:)` | Opens a menu at a point in the view (as a context menu opens at the click). |
| `kitContextMenu(content:)` | The view's context menu: secondary click on the Mac, touch and hold on touch. |
| `KitMenuButton(_:systemImage:style:content:)` | A pop-up button (`.pill` or `.button` style). |
| `KitMenuOptions(selection:options:)` | Rows that pick one value; the picked one is checked. |
| `KitSubmenu` | A row that opens a menu beside it ("Sort by ▸"), with its current value at the end. |
| `KitMenuSection(_:value:content:)` | A group of rows under a small header. |
| `KitMenuFooter` | What the menu acts on, under a divider at its end. |
| `KitMenuShare` | A row that opens the system share sheet once the menu has closed. |
| `kitMenuHint(_:)`, `kitMenuDetail(_:)` | A shortcut at a row's end; a second line under its title. |
| `kitMenuPreview(_:isDanger:)`, `KitMenuPreview` | What picking a row does, in a panel at the menu's end (the Mac). |
| `KitMenuFilter(_:total:empty:)`, `kitMenuFilter(_:kind:)` | A filter field for a long list (over 10 choices) and the words a row matches by. |
| `KitMenuGrid(columns:content:)`, `KitMenuTile` | Tiles for picking one of many things of one kind (devices, simulators). |
| `KitOpenWithRow(_:)`, `KitOpenApp` | Open With as one row: the first app in words, the others as icons. `KitOpenApp.app(…)`, `.defaultApp(opening:)`, `.fileManager(revealing:)`, `.terminal(at:)` make the entries. |
| `KitMenu(minWidth:content:)` | The menu as drawn, for a mockup or preview. |

In a system toolbar (`.toolbar`, iOS 26 on) SwiftUI turns a bare `Button` into a native bar button and drops the
modifiers that anchor a kit menu. Put the trigger in a kit view (`ToolGroup`, `KitMenuButton`), ideally in a
`KitToolbarItem`, or use the kit's own toolbar (`.kitToolbar`).

## Tabs, paths and keys

| API | What it is |
|---|---|
| `KitTabStrip(tabs:selection:onClose:onAdd:onMove:)`, `KitTab` | Editor or query tabs on a card; edited dots, preview tabs in italics, reordering. `tabContextMenu(_:)`, `onTabDoubleClick(_:)`. |
| `KitPathBar(components:)`, `KitPathBar(_:)`, `KitPathItem` | Breadcrumbs; the last crumb is the current one. |
| `Keycap(_:)`, `Keycaps(_:)` | A key or a shortcut drawn as keys. On Windows and Linux shortcuts read the platform's way. |
| `KeyHints(_:)` | A wrapping line of "keys + what they do" hints. |

See [Containers](ComponentKit-Containers.md) for the toolbar's `ToolGroup`, `KitToolbar` and `kitToolOn(_:)`.
