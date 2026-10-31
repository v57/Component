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

/// A progress bar with how it is going beside it: the time left while it works ("about 3 min left"), "Paused",
/// the failure. Pass the app's own estimate line, or when the work started and the kit estimates from its progress
/// (the time so far over the share done), refreshed every second while it works. "Estimating…" until there is one.
///
/// ```swift
/// KitProgressEstimate(status: run.status, startedAt: run.started)
/// KitProgressEstimate(status: .working(progress: estimate?.fraction), line: estimate.map { KitDuration.timeLeft($0.remaining) })
/// ```
public struct KitProgressEstimate: View {
  var status: WorkStatus
  var line: String?
  var startedAt: Date?
  var secondary: Double?
  var hue: Hue
  @Environment(\.kitIdiom) private var idiom

  /// The bar and `line`, the app's own estimate ("12 of 40 · about 3 min left").
  public init(status: WorkStatus, line: String?, secondary: Double? = nil, hue: Hue = .accent) {
    self.status = status
    self.line = line
    self.secondary = secondary
    self.hue = hue
  }

  /// The bar and the time left, estimated from `startedAt` and the progress.
  public init(status: WorkStatus, startedAt: Date, secondary: Double? = nil, hue: Hue = .accent) {
    self.init(status: status, line: nil, secondary: secondary, hue: hue)
    self.startedAt = startedAt
  }

  public var body: some View {
    HStack(spacing: idiom.size(12, touch: 14)) {
      KitProgressBar(status: status, secondary: secondary, hue: hue)
      if let startedAt, status.isWorking {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          label(Self.estimate(status: status, startedAt: startedAt, now: context.date))
        }
      } else {
        label(line ?? Self.fallback(status))
      }
    }
  }

  private func label(_ text: String) -> some View {
    Text(text)
      .kitFont(.caption)
      .monospacedDigit()
      .lineLimit(1)
      .fixedSize()
      .contentTransition(.numericText())
  }

  /// What the line says without an estimate.
  nonisolated static func fallback(_ status: WorkStatus) -> String {
    switch status {
    case .working: "Estimating…"
    case .paused: "Paused"
    case .failed(let message): message ?? "Failed"
    case .done, .idle: ""
    }
  }

  /// The time left: what the work took so far over the share done, less the time so far; "Estimating…" until 2% is
  /// done.
  nonisolated static func estimate(status: WorkStatus, startedAt: Date, now: Date) -> String {
    guard let progress = status.progress, progress >= 0.02, progress < 1 else { return fallback(status) }
    let elapsed = now.timeIntervalSince(startedAt)
    return KitDuration.timeLeft(elapsed / progress - elapsed)
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
