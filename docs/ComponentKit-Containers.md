# ComponentKit: Containers

The structure of a window: sidebar, sections, toolbar, panes, inspector, forms, sheets and other overlays, and the
feedback views. Part of [ComponentKit](ComponentKit.md).

## Sidebar

The sidebar is a scroll view of card sections on the sidebar ground. The selection is a raised card that glides
between rows; the bottom bar holds the search button, a status and the app's actions.

```swift
@State private var selection: Repository.ID?
@State private var columns = NavigationSplitViewVisibility.all
@State private var search = ""

KitSidebar(selection: $selection, searchText: $search, columnVisibility: $columns) {
  KitSection("Repositories", meta: ["\(repos.count) repositories"], systemImage: "folder", hue: .blue) {
    ForEach(repos) { repo in
      SidebarRow(value: repo.id, repo.name, subtitle: repo.branch, systemImage: "folder")
    }
  }
} bottomBar: {
  Button("Add", systemImage: "plus") { adding = true }
}
.status { Text("On This Mac") }
.primaryAction { (id: Repository.ID) in open(id) }
```

| API | What it is |
|---|---|
| `KitSidebar(selection:searchText:searchPrompt:isSearching:columnVisibility:content:bottomBar:)` | The sidebar. `selection` is an optional value, a value that is always set, or a `Set` for multiple selection (⌘-click, ⇧-click). `columnVisibility` adds the sidebar toggle on iPad and iPhone. |
| `.status(_:)`, `.selectionContextMenu(_:)`, `.onReturn(_:)`, `.primaryAction(_:)`, `.revealsSelection(_:)` | The bottom bar's status; a right-click menu for the selection; Return; double click; scroll the selection into view. |
| `SidebarRow(value:_:subtitle:systemImage:hue:status:progress:secondaryProgress:isExpanded:)` | A row with an SF Symbol tile. Other initializers take any icon view, a glyph on a tile, trailing views, or no `value` (then `.kitTag(_:)` gives it). |
| `.title(_:)`, `.subtitle(_:)`, `.titleAccessory(_:)`, `.progress(_:secondary:status:)`, `.disclosure(isExpanded:)`, `.disclosureSlot(_:)`, `.pushes(_:)`, `.isCurrent(_:)`, `.action(_:)`, `.onDoubleClick(_:)` | Row modifiers: styled title, any subtitle view, a chip after the title, a progress bar, a tree chevron, a push chevron, a second "current" mark, a tap action instead of selection. |
| `RowTile(systemImage:hue:status:)`, `KitPushChevron` | A row's icon tile; the push chevron for a row of your own. |
| `kitRowDensity(_:)`, `KitRowDensity`, `kitRowIndent(_:)` | Compact rows (file trees); indenting rows by level. |
| `kitRename(isRenaming:onCommit:)` | Renames a `SidebarRow` in place. |
| `KitList(selection:content:)` | A selectable list of kit rows without the sidebar's bottom bar (search results, a note list). |
| `KitOutline(_:children:expanded:row:)`, `KitIDSet` | A tree of rows from data; `KitIDSet` keeps the closed groups in `@AppStorage`. |
| `ReorderableSection(_:id:list:move:content:)`, `ReorderableOutline` | Rows (or a tree) that reorder by dragging, between lists too (`receivesRows`, `receivesItems`), out of the app (`exportsURL`), several at once (`dragsTogether`). `kitReorderable(…)` does it for one row of a hand-built list. |
| `SidebarShowMoreRow` | "Show 8 More" after a filtered list. |
| `kitSticky(top:bottom:)` | Keeps a section in view: at the top once scrolled past (`KitStickyTop`: `.content`, `.title`, `.titleWhileVisible`, `.none`), and as a one-line copy over the bottom bar while it is below (`KitStickyBottom`: `.content`, `.title`, `.none`). |
| `KitAccountPicker`, `KitAccount` | Picks the window's account, first in a sidebar or in a device chooser's header. |
| `kitBottomBar(…)` | The bottom bar for a pushed iPhone screen, as the root sidebar has. |

### Split views

| API | What it is |
|---|---|
| `KitSidebarSplit(selection:columnVisibility:sidebar:detail:empty:)` | A sidebar and the screen of what it selects: one stack on iPhone, a split view on the Mac and iPad with `empty` while nothing is selected. Use it at a window's root. |
| `kitSidebarColumn()` | A split view's sidebar column at the kit's widths, for a `NavigationSplitView` of your own. |
| `kitSidebarToggle(columnVisibility:isOn:)` | Puts a "Show Sidebar" button in the toolbar while the sidebar is hidden. |
| `kitThreeColumnSplit(_:)` | Says the split view has three columns, so the toggle hides the sidebar alone. |

Don't add a sidebar toggle of your own: remove the system one (`.toolbar(removing: .sidebarToggle)`); the kit's
bottom bar has one.

## Sections and headers

| API | What it is |
|---|---|
| `KitSection(_:meta:systemImage:hue:status:isExpanded:content:accessory:)` | A group of rows under the rich header: a tile (a live icon while work runs), the name, one meta line, trailing actions. Other initializers take a one-part meta, any meta view, or any glyph. |
| `.titleAccessory(_:)`, `.headerMenu(_:)`, `.emptyState(_:systemImage:)`, `.headerHelp(…)` | A chip after the title; a context menu on the header; a line while the section is empty (macOS 15 and iOS 18 on); a tooltip on the header. |
| `kitSectionStyle(_:)`, `KitSectionStyle` | `.card` (the default) or `.plain` for a compact sidebar. |
| `RichHeader`, `RichHeaderSize` | The same header on its own, at a section's, toolbar's or sheet's size. |
| `MetaLine(_:)` | Parts joined with a quiet " · ". |
| `SizedLiveIcon` | A header's live icon, sized for the idiom. |
| `KitLazyStack(alignment:spacing:content:)`, `kitLazyLoading(_:)` | A vertical stack that builds its views near the screen only, for a few heavy views (a page's sections). Use `LazyVStack` for thousands of light rows. |

## Toolbar

The kit's toolbar sits in the window's title bar (under the status bar on iPhone and iPad) in place of the system
toolbar. As room runs out, tools fold into a trailing "…" menu, lowest priority first.

```swift
HistoryView()
  .kitToolbar("History", meta: ["main", "2 to push"], systemImage: "clock", status: fetch) {
    ToolbarSlot(priority: 1) {
      ToolGroup {
        Button("Inspector", systemImage: "sidebar.right") { inspector.toggle() }.kitToolOn(inspector)
      }
    } menu: {
      Button("Inspector", systemImage: "sidebar.right") { inspector.toggle() }
    }
    Button("Commit", systemImage: "checkmark") { commit() }.buttonStyle(.kitPrimary)
  }
  .kitSidebarToggle(columnVisibility: $columns)
```

| API | What it is |
|---|---|
| `kitToolbar(_:meta:systemImage:hue:status:tools:)` | The toolbar named by the rich title. Other forms take any title view, `navigation:` before the title, or `isPresented:` to show it only sometimes. |
| `KitToolbar(title:tools:)` | The bar as a view. |
| `ToolbarSlot(_:)`, `ToolbarSlot(priority:_:menu:)` | A tool that never folds; one that folds into the "…" menu as `menu`. Plain views in the builder never fold. |
| `ToolGroup(iconOnly:content:)`, `ToolSeparator` | A card of tools; a chevron or hairline between tools. |
| `kitToolOn(_:)` | Draws a tool as on (the inspector shown). |
| `KitTitle(_:meta:systemImage:hue:status:)` | The rich title: live icon, name, status line. |
| `ToolbarOverflow` | The "…" menu, for a bar of your own. |
| `KitToolbarItem`, `kitToolbarItem()`, `kitToolbarTitle(…)`, `KitToolbarTitleSpace`, `kitHidesSystemTitle(_:)` | Kit views in a system `.toolbar`: hides the shared glass on macOS 26 and iOS 26. |
| `kitHidesToolbarBackground(_:)` | Lets the view's own ground show through the Mac's title bar. |
| `kitToolbarIconOnly` (environment) | Whether the bar has compacted to icons. |

## Panes, splits and the inspector

| API | What it is |
|---|---|
| `KitWindowLayout(content:)`, `kitPane(_:)`, `PaneGround` | Panes side by side on one sheet, with a hairline only where two panes on the same ground meet. |
| `ResizableSplit(_:pane:width:range:mainMinWidth:showsLine:main:pane:)` | Main content and a pane beside it (or under it, with `height:`), split by a draggable divider; the size is remembered under the name. |
| `StatusBar(systemImage:hue:status:alignment:content:)`, `kitStatusBar(…)` | A pane's status bar card; `kitStatusBar(isPresented:…)` shows it only while there is something to say. |
| `KitInspector(width:content:)` | The trailing detail pane: panel ground, sections as cards. |
| `InspectorHeader`, `InspectorRow(_:value:copyable:)`, `.wraps(alignment:)` | The inspector's header; a key–value line with a Copy button on hover. |
| `ActionBar(iconOnly:content:)` | A card bar of labelled buttons at the end of a pane. |
| `kitWindowMinimum(width:height:)` | A window's smallest content size without measuring the content. |

## Forms

```swift
FormCard("Connection", footer: "The key never leaves this device.") {
  FormRow("Host", systemImage: "network", field: TextField("hub.example.com", text: $host))
  FormRow("Use SSH Agent", help: "Sign in with the agent's keys", systemImage: "key") {
    Toggle("Use SSH Agent", isOn: $usesAgent).toggleStyle(.kitSwitch).kitLabelsHidden()
  }
}
```

| API | What it is |
|---|---|
| `FormCard(_:footer:content:)` | Form rows as one card, with an optional title and footnote. |
| `FormRow(_:help:systemImage:hue:error:status:control:)` | An icon tile, the label with a help line, the control at the end. Other forms: a field under the label (`field:`), a field and a control, a read-only row, a stacked row with `value:` for a wide control. |
| `.titleAccessory(_:)`, `.tile(_:)`, `.detail(_:)`, `.preview(height:_:)` | A chip after the title; any view in the tile's place; small controls under the row; a live preview of the setting. |
| `kitFormHelpWhileEditing(_:)` | Shows a field's help only while it is edited. |
| `FormHeading(_:)`, `FormPreview(height:content:)` | A heading over a group that isn't a `FormCard`; a preview row for a group of settings. |
| `GroupRow(_:help:action:)` | A plain row of a `FormCard`: title, help, the control or value at the end. |

## Sheets and other overlays

Kit overlays present on the host `componentKit()` installs: the window dims and the card floats in the middle, with
20pt corners on the Mac, iPad and iPhone. They stack. While one shows, the window behind is disabled, so only the top
card's Return and Escape buttons fire. On the Mac the first field takes focus and Tab cycles inside the card.

```swift
.kitSheet(isPresented: $cloning) {
  KitSheet(title: "Clone Repository", meta: "Copies a repository from any URL.", systemImage: "arrow.down.circle") {
    FormCard { FormRow("Repository URL", systemImage: "link", field: TextField("https://", text: $url)) }
  } footer: {
    SheetStatus("Ready", systemImage: "arrow.down", status: .done)
    Button("Cancel") { cloning = false }.keyboardShortcut(.cancelAction)
    Button("Clone") { clone() }.buttonStyle(.kitPrimary).keyboardShortcut(.defaultAction)
  }
}
.kitConfirmation("Delete harbor?", isPresented: $confirming, message: "Its worktree goes too.",
                 systemImage: "trash", confirm: "Delete") { delete(harbor) }
```

| API | What it is |
|---|---|
| `kitSheet(isPresented:onDismiss:content:)`, `kitSheet(item:…)` | The kit's sheet, with `.sheet`'s bindings. |
| `KitSheet(title:meta:systemImage:hue:status:width:onClose:content:footer:)` | A sheet's content: still header, body cards, footer bar. Put the primary button last; on iPhone the footer rearranges rather than cut a label. |
| `SheetStatus(_:systemImage:status:)` | The footer bar's lead: a live icon and one line of status. |
| `KitSheetFooterRow`, `kitSheetFooter()`, `kitSheetFooterBar()` | A footer row a sheet draws in its body (`kitSheetFooter()` pins it over the body on iPhone, above the keyboard); a footer bar over a body that scrolls on its own. |
| `kitConfirmation(_:isPresented:message:systemImage:confirm:role:action:)` | Asks before an action. A `buttons: [KitConfirmationButton]` form offers several ways to go. |
| `kitDialog(_:isPresented:message:systemImage:hue:confirm:role:content:action:)` | An alert-style card with content of its own (a safety code to compare). |
| `kitNotice(_:isPresented:message:systemImage:hue:buttons:)` | Says something that needs no decision, with OK. Forms that take `message: Binding<String?>` or an `item:` show while there is something to say. |
| `kitPrompt(_:isPresented:text:message:systemImage:hue:field:footnote:confirm:action:)`, `KitPromptField` | Asks for one line of text (a name, a password). `KitPromptField.secure(…)` hides it; `content: .verbatim` keeps a name exactly as typed. |
| `kitPopover(isPresented:edge:takesFocus:content:)` | Content on the overlay card beside the view, in place of `.popover`. |
| `kitCover(isPresented:cover:)` | Covers the whole window (a lock screen). |
| `@Environment(\.kitDismiss)` | Closes the overlay the view is in. SwiftUI's `dismiss` doesn't reach a kit overlay, and on the Mac would close the window. |
| `kitSheetDismissDisabled(_:)` | Keeps a sheet open on a click on the dim. |
| `kitOverlayCard()` | The overlays' card, for an overlay of your own. |

A view outside `componentKit()` has no overlay host; there the kit falls back to a system sheet.

## Feedback

| API | What it is |
|---|---|
| `Banner(_:message:systemImage:hue:onDismiss:actions:)` | A notice across a pane: an icon tile, a bold line, a quiet line, actions at the end. |
| `Toast`, `@Environment(\.showToast)`, `kitToasts()` | A short message about something that just happened, with an optional Undo or a follow-up action. |
| `EmptyState(systemImage:title:message:status:actions:)` | What a pane will show and how to get there; `status: .working` for a loading state. A `detail:` form shows a view under the message (a pairing code). |
| `kitHelp(_:shortcut:meta:systemImage:hue:status:edge:)` | The kit's tooltip: a small card with a rich header half a second after the pointer stops. A form with `detail:` adds rows under it. |

```swift
@Environment(\.showToast) private var showToast

showToast(Toast("Deleted harbor", systemImage: "trash", undo: { restore() }))
```

## Drag and drop

| API | What it is |
|---|---|
| `kitLifted(_:cornerRadius:)` | Draws a dragged row: raised, larger, with the floating shadow. |
| `kitDropTarget(_:cornerRadius:)` | Draws a drop target. `kitDropTarget(_:label:systemImage:)` covers a pane with a `KitDropLabel` ("Drop to Play"). |
| `DropSlot(height:)` | The slot a dragged row will land in. |
| `kitDropDestination(of:isTargeted:perform:)`, `kitFileDrop(isTargeted:perform:)`, `KitDroppedFiles.load(_:then:)` | Drops anywhere on a view, also over the kit's reorderable rows inside it; files arrive as URLs in the drag's order. |
