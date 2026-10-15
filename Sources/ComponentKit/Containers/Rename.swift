import SwiftUI

/// What `.kitRename` hands the row below it.
struct ContRename {
  var isRenaming: Binding<Bool>
  var text: Binding<String>?
  var commit: @MainActor (String) -> Void
}

extension EnvironmentValues {
  @Entry var contRename: ContRename? = nil
}

extension View {
  /// Renames a `SidebarRow` in place: while `isRenaming` is on, its title becomes a field at the same position, weight
  /// and size (the window ground with a thin accent outline). Return or leaving the field commits, Escape cancels;
  /// either way `isRenaming` turns off.
  ///
  /// ```swift
  /// SidebarRow(value: host.id, host.name, systemImage: "server.rack")
  ///   .kitRename(isRenaming: $renaming, text: $host.name) { save() }
  /// ```
  public func kitRename(
    isRenaming: Binding<Bool>, text: Binding<String>, onCommit: @escaping @MainActor () -> Void = {}
  ) -> some View {
    environment(
      \.contRename,
      ContRename(isRenaming: isRenaming, text: text) { newValue in
        text.wrappedValue = newValue
        onCommit()
      })
  }

  /// Renames a `SidebarRow` in place, starting from its title; `onCommit` gets the new name (never empty).
  ///
  /// ```swift
  /// SidebarRow(value: note.id, note.title, systemImage: "doc.text")
  ///   .kitRename(isRenaming: $renaming) { model.rename(note, to: $0) }
  /// ```
  public func kitRename(isRenaming: Binding<Bool>, onCommit: @escaping @MainActor (String) -> Void) -> some View {
    environment(\.contRename, ContRename(isRenaming: isRenaming, text: nil, commit: onCommit))
  }
}

/// The title as a field: the text keeps its place, so it reads as the row being edited, not a box on top.
struct ContRenameField: View {
  let title: String
  let rename: ContRename
  @State private var draft = ""
  @State private var didFinish = false
  @FocusState private var focused: Bool

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
    TextField("Name", text: $draft)
      .textFieldStyle(.plain)
      .kitFont(.body)
      .fontWeight(.medium)
      .focused($focused)
      .onSubmit { finish(commit: true) }
      .onKeyPress(.escape) {
        finish(commit: false)
        return .handled
      }
      .onChange(of: focused) { _, isFocused in
        if !isFocused { finish(commit: true) }
      }
      .padding(.horizontal, 5)
      .frame(height: 24)
      .background { shape.fill(.kitWindow) }
      .overlay { shape.strokeBorder(Hue.accent.soft(0.7), lineWidth: 1) }
      .overlay {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .strokeBorder(Hue.accent.soft(0.16), lineWidth: 3)
          .padding(-3)
          .allowsHitTesting(false)
      }
      .padding(.horizontal, -5)
      .onAppear {
        draft = rename.text?.wrappedValue ?? title
        didFinish = false
        Task { @MainActor in focused = true }
      }
  }

  private func finish(commit: Bool) {
    guard !didFinish else { return }
    didFinish = true
    let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    if commit, !name.isEmpty, name != (rename.text?.wrappedValue ?? title) { rename.commit(name) }
    rename.isRenaming.wrappedValue = false
  }
}
