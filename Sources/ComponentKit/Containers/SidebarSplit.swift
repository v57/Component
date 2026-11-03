import SwiftUI

/// A sidebar and the screen of what it selects, the right way for each device: on iPhone one stack, with the list at
/// its root and the selection pushed onto it; on iPad and the Mac a split view with `empty` in the detail while nothing
/// is selected. Back on iPhone clears the selection, so tapping the row again opens it again. The detail can push
/// `NavigationLink(value:)`s of its own in both forms: add their `navigationDestination(for:)` in `detail`. Use it at a
/// window's root: inside another `NavigationStack` its pushes go to the outer one, or nowhere.
///
/// ```swift
/// @State private var project: Project.ID?
/// @State private var columns = NavigationSplitViewVisibility.all
///
/// KitSidebarSplit(selection: $project, columnVisibility: $columns) {
///   KitSidebar(selection: $project, columnVisibility: $columns) { … }
/// } detail: { id in
///   ProjectScreen(id: id)
/// } empty: {
///   KitWelcome(…)
/// }
/// ```
///
/// It isn't a collapsed `NavigationSplitView` on iPhone because that reports its sidebar column whenever the detail's
/// own stack pops, and value links don't push under a `navigationDestination(item:)`.
public struct KitSidebarSplit<Selection: Hashable, Sidebar: View, Detail: View, Empty: View>: View {
  @Binding private var selection: Selection?
  @Binding private var columnVisibility: NavigationSplitViewVisibility
  private let sidebar: Sidebar
  private let detail: (Selection) -> Detail
  private let empty: Empty
  @State private var path = NavigationPath()
  @Environment(\.kitIdiom) private var idiom

  public init(
    selection: Binding<Selection?>, columnVisibility: Binding<NavigationSplitViewVisibility>,
    @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: @escaping (Selection) -> Detail,
    @ViewBuilder empty: () -> Empty
  ) {
    _selection = selection
    _columnVisibility = columnVisibility
    self.sidebar = sidebar()
    self.detail = detail
    self.empty = empty()
  }

  public var body: some View {
    if idiom == .phone { stack } else { split }
  }

  /// The selection on the stack's path, under a type no app pushes itself.
  private struct Opened: Hashable {
    let selection: Selection
  }

  private var stack: some View {
    NavigationStack(path: $path) {
      sidebar
        .navigationDestination(for: Opened.self) { opened in
          detail(opened.selection).id(opened.selection)
        }
    }
    .onAppear { open(selection) }
    .onChange(of: selection) { _, selection in open(selection) }
    // Back on the root list: no row stays picked.
    .onChange(of: path.count) { _, count in
      if count == 0 { selection = nil }
    }
  }

  private func open(_ selection: Selection?) {
    guard let selection else { return }
    path = NavigationPath([Opened(selection: selection)])
  }

  private var split: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      sidebar
        .toolbar(removing: .sidebarToggle)
        .kitSidebarColumn()
    } detail: {
      NavigationStack {
        if let selection {
          detail(selection).id(selection)
        } else {
          empty
        }
      }
      .kitSidebarToggle(columnVisibility: $columnVisibility)
    }
  }
}
