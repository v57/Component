import SwiftUI

/// A progress bar that stretches to its width: a 4pt capsule on the fill (6 with `.controlSize(.large)`), the value
/// in the hue, and an optional second value behind it at a third of the hue's strength (what's buffered, downloaded or
/// available, ahead of what's played or verified). For a row's progress, under its title, or a download's line.
///
/// Prefer the live icon for work in progress (`LiveIcon`, `WorkStatus`); use a bar where the amount itself is the
/// information (a file's download, a video's buffer).
///
/// ```swift
/// KitProgressBar(value: 0.4)
/// KitProgressBar(value: played, secondary: buffered, hue: .red)
/// KitProgressBar(status: .paused(progress: 0.6))   // gray; green when done, red when failed
/// KitProgressBar(status: file.isPaused ? .paused(progress: done) : .working(progress: done), secondary: verified)
/// ```
public struct KitProgressBar: View {
  var value: Double
  var secondary: Double?
  var hue: Hue
  @Environment(\.controlSize) private var controlSize
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitWindowIsActive) private var isActive

  /// A bar filled to `value` (0…1), with `secondary` (0…1) drawn softly behind it.
  public init(value: Double, secondary: Double? = nil, hue: Hue = .accent) {
    self.value = value
    self.secondary = secondary
    self.hue = hue
  }

  /// A bar for a piece of work: its progress, in the state's hue (green done, red failed, gray paused), with
  /// `secondary` (0…1) drawn softly behind it in the same hue.
  public init(status: WorkStatus, secondary: Double? = nil, hue: Hue = .accent) {
    self.init(value: status.progress ?? 0, secondary: secondary, hue: status.hue ?? hue)
  }

  public var body: some View {
    let height = KitProgressBar.height(large: controlSize == .large || controlSize == .extraLarge, idiom: idiom)
    let tint = isActive || hue != .accent ? hue : .gray
    GeometryReader { geometry in
      let width = geometry.size.width
      ZStack(alignment: .leading) {
        Capsule().fill(.kitFill)
        if let secondary {
          Capsule()
            .fill(tint.soft(0.35))
            .frame(width: KitProgressBar.fillWidth(secondary, in: width, height: height))
        }
        Capsule()
          .fill(tint.fill)
          .frame(width: KitProgressBar.fillWidth(value, in: width, height: height))
      }
    }
    .frame(height: height)
    .frame(minWidth: 20)
    .clipShape(Capsule())
    .animation(.kit, value: value)
    .animation(.kit, value: secondary)
    .accessibilityElement()
    .accessibilityLabel("Progress")
    .accessibilityValue("\(Int((MicroBar.clamped(value) * 100).rounded())) percent")
  }

  /// 4pt (5 on touch), 6pt large (7 on touch).
  static func height(large: Bool, idiom: KitIdiom) -> CGFloat {
    (large ? 6 : 4) * idiom.scale + (idiom.isTouch ? 1 : 0)
  }

  /// The filled width for `value` on a bar `width` wide: 0 stays empty, any other value shows at least a dot (the
  /// bar's own height), and it never passes the end.
  nonisolated static func fillWidth(_ value: Double, in width: CGFloat, height: CGFloat) -> CGFloat {
    let clamped = MicroBar.clamped(value)
    guard clamped > 0, width > 0 else { return 0 }
    return min(max(width * clamped, height), width)
  }
}

#Preview("Progress bar") {
  VStack(spacing: 14) {
    KitProgressBar(value: 0.4)
    KitProgressBar(value: 0.3, secondary: 0.7, hue: .red)
    KitProgressBar(status: .paused(progress: 0.6))
    KitProgressBar(status: .done)
    KitProgressBar(value: 0.55).controlSize(.large)
  }
  .padding(20)
  .frame(width: 280)
  .componentKit()
}
