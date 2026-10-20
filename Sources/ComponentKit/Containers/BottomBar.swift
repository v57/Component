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
  public func kitBottomBar<Actions: View>(
    searchText: Binding<String>? = nil, prompt: String = "Search", ground: PaneGround = .content,
    @ViewBuilder actions: () -> Actions
  ) -> some View {
    let color: KitColor = ground == .content ? .window : .panel
    let bar = ContSidebarBar(
      searchText: searchText, prompt: prompt, toggle: nil, labeled: true, actions: actions)
    return contEdgeBar(.bottom) {
      bar
        .environment(\.contBarGround, color)
        .background { ContEdgeFade(edge: .bottom, ground: color) }
    }
  }

  /// A pushed iPhone screen's bar with only the search button and a status line (no actions).
  public func kitBottomBar(
    searchText: Binding<String>?, prompt: String = "Search", ground: PaneGround = .content
  ) -> some View {
    kitBottomBar(searchText: searchText, prompt: prompt, ground: ground) { EmptyView() }
  }
}
