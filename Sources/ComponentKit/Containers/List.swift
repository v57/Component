import SwiftUI

/// A selectable list of kit rows without the sidebar's bottom bar: a note list, search results, a file list beside
/// the content. Rows are `SidebarRow`s (or card `KitSection`s of them) and look as in a `KitSidebar`: the selection is
/// the raised card, the accent tile while the list has keyboard focus. It's a `List` underneath, so rows take
/// SwiftUI's own `.swipeActions` (iOS and the Mac's trackpad), `.contextMenu` and `.onMove`; arrow keys move the
/// selection and open tree rows, as in the sidebar.
///
/// Card `KitSection`s in it spread over the list's rows (macOS 15 and iOS 18 on): the header and each row are list
/// rows of their own drawing their slice of the card, so swipes and context menus belong to one row, not the card.
///
/// It draws no ground of its own: put it on a pane (`.kitPane(.secondary)`) or the sidebar colour.
///
/// On iPhone a row pushes its screen through SwiftUI's navigation: `.navigationDestination(item: $selection)` on the
/// list (it pops back to `nil`), or a `NavigationLink(value:)` around the row with `.buttonStyle(.kitRow)`; either
/// needs a `NavigationStack` around the list. A `NavigationSplitView`'s detail column has none of its own, so wrap the
/// detail in one there. `.pushes()` on the rows draws the chevron (the list hides the system's).
///
/// ```swift
/// KitList(selection: $record) {
///   ForEach(records) { SidebarRow(value: $0.id, $0.title, systemImage: "doc").pushes() }
/// }
/// .navigationDestination(item: $record) { RecordScreen(id: $0) }
/// ```
///
/// ```swift
/// KitList(selection: $note) {
///   ForEach(notes) { note in
///     SidebarRow(value: note.id, note.title, systemImage: "doc.text")
///       .subtitle { Text(note.date, style: .date) + Text("  " + note.preview) }
///       .swipeActions { Button("Delete", systemImage: "trash", role: .destructive) { delete(note) } }
///   }
/// }
/// .kitPane(.secondary)
/// ```
public struct KitList<Content: View>: View {
  private let getSelection: () -> AnyHashable?
  private let setSelection: @MainActor (AnyHashable) -> Void
  private let content: Content
  private var returnAction: (@MainActor () -> Void)?
  private var primary: (@MainActor (AnyHashable) -> Void)?
  @FocusState private var focused: Bool
  @Namespace private var namespace
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitAppearsActive) private var appearsActive

  /// A list whose rows select an optional value.
  public init<Selection: Hashable & Sendable>(
    selection: Binding<Selection?>, @ViewBuilder content: () -> Content
  ) {
    getSelection = { selection.wrappedValue.map(AnyHashable.init) }
    setSelection = { value in
      if let value = value.base as? Selection { selection.wrappedValue = value }
    }
    self.content = content()
  }

  /// A list whose rows select a value that is always set.
  @_disfavoredOverload
  public init<Selection: Hashable & Sendable>(selection: Binding<Selection>, @ViewBuilder content: () -> Content) {
    getSelection = { AnyHashable(selection.wrappedValue) }
    setSelection = { value in
      if let value = value.base as? Selection { selection.wrappedValue = value }
    }
    self.content = content()
  }

  /// What Return does on the selected row while the list has keyboard focus (open the note, start renaming).
  public func onReturn(_ action: @escaping @MainActor () -> Void) -> Self {
    var list = self
    list.returnAction = action
    return list
  }

  /// What a double click on a row does with its value (open the note in a window, play the file); Return runs it too
  /// on the selected row while the list has keyboard focus, unless `onReturn` is set.
  ///
  /// ```swift
  /// KitList(selection: $file) { … }.primaryAction { (id: File.ID) in open(id) }
  /// ```
  public func primaryAction<Value: Hashable>(_ action: @escaping @MainActor (Value) -> Void) -> Self {
    var list = self
    list.primary = { value in
      if let value = value.base as? Value { action(value) }
    }
    return list
  }

  public var body: some View {
    ScrollViewReader { proxy in list(proxy) }
  }

  private func list(_ proxy: ScrollViewProxy) -> some View {
    let selection = getSelection()
    let inset = ContMetrics.sidebarInset(idiom)
    return List {
      Group { content }
        .modifier(ContHiddenLinkIndicator())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 1, leading: inset, bottom: 1, trailing: inset))
    }
    .environment(\.contInList, true)
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .contentMargins(.vertical, inset / 2, for: .scrollContent)
    .environment(\.defaultMinListRowHeight, 1)
    .focusable()
    .focusEffectDisabled()
    .focused($focused)
    .modifier(
      ContRowKeyboard(
        current: selection, select: setSelection, onReturn: returnAction, onPrimary: primary,
        scroll: { value, anchor in proxy.scrollTo(ContRowScrollID(value: value), anchor: anchor) }))
    .modifier(ContListTapFocus(focused: $focused, selection: selection))
    .environment(
      \.contSidebarSelection,
      ContSidebarSelection(
        value: selection, select: setSelection, isFocused: focused || idiom.isTouch || appearsActive, namespace: namespace,
        primaryAction: primary)
    )
    .animation(.kit, value: selection)
    .animation(.kit, value: focused)
  }
}

/// A `NavigationLink` row draws the kit's chevron itself (`SidebarRow.pushes()`), not the list's (iOS draws one).
private struct ContHiddenLinkIndicator: ViewModifier {
  func body(content: Content) -> some View {
    #if os(iOS)
      content.navigationLinkIndicatorVisibility(.hidden)
    #else
      content
    #endif
  }
}

/// A click in the list gives it keyboard focus (the arrow keys move from there). On iOS a tap gesture on the list
/// keeps its `NavigationLink`s from firing, so there a row's selection takes focus instead.
private struct ContListTapFocus: ViewModifier {
  var focused: FocusState<Bool>.Binding
  let selection: AnyHashable?

  func body(content: Content) -> some View {
    #if os(macOS)
      content.simultaneousGesture(TapGesture().onEnded { focused.wrappedValue = true })
    #else
      content.onChange(of: selection) { _, value in
        if value != nil { focused.wrappedValue = true }
      }
    #endif
  }
}

#Preview("List") {
  @Previewable @State var selection: Int? = 2
  KitList(selection: $selection) {
    ForEach(1...6, id: \.self) { index in
      SidebarRow(value: index, "Note \(index)", systemImage: "doc.text")
        .subtitle { Text("Today").foregroundStyle(.kitLabel) + Text("  A line from the note") }
        .swipeActions { Button("Delete", systemImage: "trash", role: .destructive) {} }
    }
  }
  .frame(width: 280, height: 360)
  .background(.kitPanel)
  .componentKit()
}
