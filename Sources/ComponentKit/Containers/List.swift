import SwiftUI

/// A selectable list of kit rows without the sidebar's bottom bar: a note list, search results, a file list beside
/// the content. Rows are `SidebarRow`s (or card `KitSection`s of them) and look as in a `KitSidebar`: the selection is
/// the raised card, the accent tile while the list has keyboard focus. It's a `List` underneath, so rows take
/// SwiftUI's own `.swipeActions` (iOS and the Mac's trackpad), `.contextMenu` and `.onMove`; arrow keys move the
/// selection and open tree rows, as in the sidebar.
///
/// It draws no ground of its own: put it on a pane (`.kitPane(.secondary)`) or the sidebar colour.
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
  @FocusState private var focused: Bool
  @Namespace private var namespace
  @Environment(\.kitIdiom) private var idiom

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

  public var body: some View {
    let selection = getSelection()
    let inset = ContMetrics.sidebarInset(idiom)
    List {
      Group { content }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 1, leading: inset, bottom: 1, trailing: inset))
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .contentMargins(.vertical, inset / 2, for: .scrollContent)
    .environment(\.defaultMinListRowHeight, 1)
    .focusable()
    .focusEffectDisabled()
    .focused($focused)
    .modifier(ContRowKeyboard(current: selection, select: setSelection, onReturn: returnAction))
    .simultaneousGesture(TapGesture().onEnded { focused = true })
    .environment(
      \.contSidebarSelection,
      ContSidebarSelection(
        value: selection, select: setSelection, isFocused: focused || idiom.isTouch, namespace: namespace)
    )
    .animation(.kit, value: selection)
    .animation(.kit, value: focused)
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
