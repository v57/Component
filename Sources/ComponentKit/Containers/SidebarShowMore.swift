import SwiftUI

// MARK: - Show more

/// The row after a sidebar list for what its filters leave out: "Show 8 More · unused" with a down chevron in the
/// accent, and once they show, "Show Fewer" with an up one. A click (or Return) flips `isShowing`, animated. `reason`
/// trails the row while the extra items are hidden; `help` and `hideHelp` are the tooltips in either state.
///
/// ```swift
/// if more > 0 || showsMore {
///   SidebarShowMoreRow(count: more, isShowing: $showsMore, reason: "unused",
///                      help: "Show \(more) connections unused for a week",
///                      hideHelp: "Hide the connections the filters leave out")
/// }
/// ```
public struct SidebarShowMoreRow: View {
  var count: Int
  @Binding var isShowing: Bool
  var reason: KitString?
  var help: KitString?
  var hideHelp: KitString?
  @Environment(\.kitIdiom) private var idiom

  /// The row with its reason and tooltips as keys (literals), looked up in the app's strings.
  public init(
    count: Int, isShowing: Binding<Bool>, reason: LocalizedStringKey? = nil, help: LocalizedStringKey? = nil,
    hideHelp: LocalizedStringKey? = nil
  ) {
    self.init(
      count: count, isShowing: isShowing, reason: KitString(reason), help: KitString(help),
      hideHelp: KitString(hideHelp))
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(
    count: Int, isShowing: Binding<Bool>, reason: String? = nil, help: String? = nil, hideHelp: String? = nil
  ) {
    self.init(
      count: count, isShowing: isShowing, reason: KitString(verbatim: reason), help: KitString(verbatim: help),
      hideHelp: KitString(verbatim: hideHelp))
  }

  init(count: Int, isShowing: Binding<Bool>, reason: KitString?, help: KitString?, hideHelp: KitString?) {
    self.count = count
    self._isShowing = isShowing
    self.reason = reason
    self.help = help
    self.hideHelp = hideHelp
  }

  public var body: some View {
    let title = isShowing ? KitString("Show Fewer") : KitString("Show \(count) More")
    SidebarRow(value: nil, title: title, subtitle: nil) {
      Image(systemName: isShowing ? "chevron.up" : "chevron.down")
        .font(.system(size: idiom.size(11, touch: 13), weight: .semibold))
        .foregroundStyle(.kitAccent)
        .frame(width: KitMetrics.rowTile(idiom))
    } trailing: {
      if !isShowing, let reason { Text(reason).lineLimit(1) }
    }
    .title(Text(title).foregroundStyle(.kitAccent))
    .action { withKitAnimation { isShowing.toggle() } }
    .help((isShowing ? hideHelp : help) ?? title)
  }
}

#Preview("Show more") {
  @Previewable @State var showsMore = false
  KitSidebar(selection: .constant(String?.none)) {
    KitSection("Databases", systemImage: "cylinder.split.1x2") {
      SidebarRow("atlas", systemImage: "cylinder")
      SidebarShowMoreRow(count: 8, isShowing: $showsMore, reason: "unused")
    }
  }
  .frame(width: 260, height: 240)
  .componentKit()
}
