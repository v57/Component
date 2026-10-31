import SwiftUI

/// A short status floating over content, on the floating surface: a live icon carrying the work and a line ("Waiting
/// for the download" over a player, "Reconnecting…" over a remote screen). The `@ViewBuilder` forms take any content
/// (a column of stream figures), with or without an icon. Place it with an overlay and the 8pt gutter; over a video
/// set `.environment(\.colorScheme, .dark)` on it.
///
/// ```swift
/// .overlay(alignment: .topLeading) {
///   if isWaiting {
///     KitStatusPill("Waiting for the download", systemImage: "arrow.down", hue: .orange, status: .working)
///       .padding(KitMetrics.gutter * 2)
///   }
/// }
/// KitStatusPill { VStack(alignment: .trailing) { Text("60 fps"); Text("12.4 Mbps") }.monospacedDigit() }
/// ```
public struct KitStatusPill<Icon: View, Content: View>: View {
  var icon: Icon
  var content: Content
  @Environment(\.kitIdiom) private var idiom

  public init(@ViewBuilder icon: () -> Icon, @ViewBuilder content: () -> Content) {
    self.icon = icon()
    self.content = content()
  }

  public var body: some View {
    let hasIcon = Icon.self != EmptyView.self
    HStack(spacing: idiom.size(8, touch: 10)) {
      icon
      content
    }
    .kitFont(.callout)
    .padding(
      EdgeInsets(
        top: idiom.size(6, touch: 8), leading: idiom.size(hasIcon ? 6 : 10, touch: hasIcon ? 8 : 12),
        bottom: idiom.size(6, touch: 8), trailing: idiom.size(12, touch: 14)))
    .kitSurface(.floating, cornerRadius: KitMetrics.radiusCard)
    .accessibilityElement(children: .combine)
  }
}

extension KitStatusPill where Icon == LiveIcon<Image>, Content == Text {
  /// A 20pt live icon and a line.
  public init(_ title: String, systemImage: String, hue: Hue = .accent, status: WorkStatus = .idle) {
    self.init(icon: { LiveIcon(systemImage: systemImage, hue: hue, status: status, size: 20) }, content: { Text(title) })
  }
}

extension KitStatusPill where Icon == EmptyView {
  /// Any content on the pill, without an icon.
  public init(@ViewBuilder content: () -> Content) {
    self.init(icon: { EmptyView() }, content: content)
  }
}
