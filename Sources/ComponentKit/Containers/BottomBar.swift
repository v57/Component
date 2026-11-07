import SwiftUI

extension View {
  /// The bar at the bottom of a pushed iPhone screen, as the root list's sidebar has it: the square search button
  /// leads (it opens into the search line), then the screen's actions on one card at the end. The content scrolls
  /// on under it, faded. Titles show (a pushed screen has room for "Copy Password"); give a button
  /// `.labelStyle(.iconOnly)` to show only its glyph. Works on every idiom; apps use it where a screen has no
  /// toolbar of tools (iPhone).
  ///
  /// ```swift
  /// LoginDetail(login)
  ///   .kitBottomBar(searchText: $search, prompt: "Search logins") {
  ///     Button("Copy Password", systemImage: "doc.on.doc") { … }
  ///     Button("Share", systemImage: "square.and.arrow.up") { … }.labelStyle(.iconOnly)
  ///   }
  /// ```
  ///
  /// The prompt is a key (a literal), looked up in the app's strings.
  public func kitBottomBar<Actions: View>(
    searchText: Binding<String>? = nil, prompt: LocalizedStringKey = "Search", ground: PaneGround = .content,
    @ViewBuilder actions: () -> Actions
  ) -> some View {
    kitBottomBar(searchText: searchText, prompt: KitString(prompt), ground: ground, actions: actions)
  }

  /// The same with the prompt a string shown as it is (`nil`: the kit's "Search").
  @_disfavoredOverload
  public func kitBottomBar<Actions: View>(
    searchText: Binding<String>? = nil, prompt: String? = nil, ground: PaneGround = .content,
    @ViewBuilder actions: () -> Actions
  ) -> some View {
    kitBottomBar(
      searchText: searchText, prompt: KitString(verbatim: prompt) ?? KitString("Search"), ground: ground,
      actions: actions)
  }

  func kitBottomBar<Actions: View>(
    searchText: Binding<String>?, prompt: KitString, ground: PaneGround, @ViewBuilder actions: () -> Actions
  ) -> some View {
    let color: KitColor = ground == .content ? .window : .panel
    let bar = ContSidebarBar(
      searchText: searchText, prompt: prompt, toggle: nil, labeled: true, actions: actions)
    // Filling the pane, the content isn't asked for its smallest size (a scroll view answers by laying out every row).
    return contFillsProposal().contEdgeBar(.bottom) {
      bar
        .environment(\.contBarGround, color)
        .background { ContEdgeFade(edge: .bottom, ground: color) }
    }
  }

  /// A pushed iPhone screen's bar with only the search button and a status line (no actions); the prompt is a key
  /// (a literal), looked up in the app's strings.
  public func kitBottomBar(
    searchText: Binding<String>?, prompt: LocalizedStringKey = "Search", ground: PaneGround = .content
  ) -> some View {
    kitBottomBar(searchText: searchText, prompt: KitString(prompt), ground: ground) { EmptyView() }
  }

  /// The same with the prompt a string shown as it is (`nil`: the kit's "Search").
  @_disfavoredOverload
  public func kitBottomBar(
    searchText: Binding<String>?, prompt: String? = nil, ground: PaneGround = .content
  ) -> some View {
    kitBottomBar(
      searchText: searchText, prompt: KitString(verbatim: prompt) ?? KitString("Search"), ground: ground
    ) { EmptyView() }
  }
}
