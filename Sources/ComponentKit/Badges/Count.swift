import SwiftUI

/// A count as a bare semibold number whose colour says what it means: gray informs (History 17), orange waits on you
/// (unread, changes, to push), red failed. The same in rows, segments, toolbar buttons and section headers. A changing
/// number rolls to its new value.
///
/// ```swift
/// Count(17)
/// Count(4, .attention)
/// Count(1, .failed)
/// Count("31 of 48")
/// ```
public struct Count: View {
  /// What a count tells the reader.
  public enum Meaning: Hashable, Sendable {
    /// Gray: just information.
    case info
    /// Orange: something waits on you.
    case attention
    /// Red: something failed.
    case failed

    var hue: Hue? {
      switch self {
      case .info: nil
      case .attention: .orange
      case .failed: .red
      }
    }
  }

  var text: String
  var value: Double?
  var meaning: Meaning
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled

  /// A number.
  public init(_ value: Int, _ meaning: Meaning = .info) {
    text = "\(value)"
    self.value = Double(value)
    self.meaning = meaning
  }

  /// A figure that isn't a plain number ("31 of 48", "4.2 s", "1 warning").
  public init(_ text: some StringProtocol, _ meaning: Meaning = .info) {
    self.text = String(text)
    value = nil
    self.meaning = meaning
  }

  public var body: some View {
    Text(text)
      .font(.system(size: badgeFigureSize(idiom), weight: .semibold).monospacedDigit())
      .foregroundStyle(meaning.hue.map { AnyShapeStyle($0.text) } ?? AnyShapeStyle(.kitSecondary))
      .lineLimit(1)
      .fixedSize()
      .contentTransition(value.map { .numericText(value: $0) } ?? .opacity)
      .animation(.kit, value: text)
      .opacity(isEnabled ? 1 : 0.45)
  }
}

/// A repository's sync as bare figures: local changes (an orange dot and the number), commits to push (↑, orange:
/// they wait on you) and to pull (↓, gray). Zeros are left out, so an up-to-date repository shows nothing.
///
/// ```swift
/// SyncCounts(changes: 5, ahead: 2, behind: 1)   // • 5  ↑2  ↓1
/// ```
public struct SyncCounts: View {
  var changes: Int
  var ahead: Int
  var behind: Int
  @Environment(\.kitIdiom) private var idiom

  public init(changes: Int = 0, ahead: Int = 0, behind: Int = 0) {
    self.changes = changes
    self.ahead = ahead
    self.behind = behind
  }

  public var body: some View {
    let size = badgeFigureSize(idiom)
    HStack(spacing: 6) {
      if changes > 0 {
        HStack(spacing: 4) {
          Circle().fill(Hue.orange.fill).frame(width: size * 0.64, height: size * 0.64)
          Text("\(changes)").contentTransition(.numericText(value: Double(changes)))
        }
        .foregroundStyle(Hue.orange.text)
      }
      if ahead > 0 {
        Text("↑\(ahead)").foregroundStyle(Hue.orange.text)
          .contentTransition(.numericText(value: Double(ahead)))
      }
      if behind > 0 {
        Text("↓\(behind)").fontWeight(.medium).foregroundStyle(.kitSecondary)
          .contentTransition(.numericText(value: Double(behind)))
      }
    }
    .font(.system(size: size, weight: .semibold).monospacedDigit())
    .lineLimit(1)
    .fixedSize()
    .animation(.kit, value: [changes, ahead, behind])
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.label(changes: changes, ahead: ahead, behind: behind))
  }

  nonisolated static func label(changes: Int, ahead: Int, behind: Int) -> String {
    var parts: [String] = []
    if changes > 0 { parts.append("\(changes) changed") }
    if ahead > 0 { parts.append("\(ahead) to push") }
    if behind > 0 { parts.append("\(behind) to pull") }
    return parts.isEmpty ? "Up to date" : parts.joined(separator: ", ")
  }
}

/// A step's number in the tile shape, for pipeline stages and numbered walkthroughs; the current step takes the
/// accent's tint.
///
/// ```swift
/// HStack { StepNumber(1); StepNumber(2); StepNumber(3, isCurrent: true) }
/// ```
public struct StepNumber: View {
  var number: Int
  var isCurrent: Bool
  @Environment(\.kitIdiom) private var idiom

  public init(_ number: Int, isCurrent: Bool = false) {
    self.number = number
    self.isCurrent = isCurrent
  }

  public var body: some View {
    let side: CGFloat = idiom.size(18, pad: 22, phone: 24)
    let shape = RoundedRectangle(cornerRadius: idiom == .mac ? KitMetrics.radiusXS : 6, style: .continuous)
    Text("\(number)")
      .font(.system(size: badgeFigureSize(idiom), weight: .semibold).monospacedDigit())
      .foregroundStyle(isCurrent ? AnyShapeStyle(BadgeInk(hue: .accent)) : AnyShapeStyle(.kitSecondary))
      .padding(.horizontal, 4)
      .frame(minWidth: side, minHeight: side)
      .background(isCurrent ? AnyShapeStyle(BadgeTint(hue: .accent)) : AnyShapeStyle(.kitFill), in: shape)
      .fixedSize()
      .animation(.kit, value: isCurrent)
      .accessibilityLabel("Step \(number)")
      .accessibilityAddTraits(isCurrent ? .isSelected : [])
  }
}

/// A status dot: 7pt in its hue, or a hollow ring for "not yet" (offline, not pushed).
///
/// ```swift
/// StatusDot(hue: .green)
/// StatusDot(hue: .gray, isHollow: true)
/// ```
public struct StatusDot: View {
  var hue: Hue
  var isHollow: Bool
  var size: CGFloat

  public init(hue: Hue, isHollow: Bool = false, size: CGFloat = 7) {
    self.hue = hue
    self.isHollow = isHollow
    self.size = size
  }

  public var body: some View {
    ZStack {
      if isHollow {
        Circle().strokeBorder(hue.fill, lineWidth: 1.5)
      } else {
        Circle().fill(hue.fill)
      }
    }
    .frame(width: size, height: size)
    .animation(.kit, value: hue)
    .accessibilityHidden(true)
  }
}

#Preview("Counts") {
  VStack(alignment: .leading, spacing: 12) {
    HStack(spacing: 8) {
      Count(12)
      Count(3, .attention)
      Count(1, .failed)
      Count("31 of 48")
    }
    SyncCounts(changes: 3, ahead: 2, behind: 1)
    HStack(spacing: 6) {
      StepNumber(1)
      StepNumber(2)
      StepNumber(3, isCurrent: true)
      StepNumber(4)
    }
    HStack(spacing: 8) {
      StatusDot(hue: .green)
      StatusDot(hue: .orange)
      StatusDot(hue: .red)
      StatusDot(hue: .gray, isHollow: true)
    }
  }
  .padding()
  .componentKit()
}
