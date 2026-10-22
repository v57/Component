import SwiftUI

/// The kit's stepper: − and + on one field track with the value as a raised card between them. The buttons go
/// quiet at the ends of the range. Keyboard: Tab focuses − or + (the track takes the field ring and the button rises
/// half-way), Space steps, ↑ → step up and ↓ ← step down. VoiceOver reads an adjustable value.
///
/// ```swift
/// KitStepper("Font size", value: $fontSize, in: 9...24, unit: "pt")
/// KitStepper(value: $retries, in: 0...10)
/// KitStepper("Zoom", value: $zoom, in: 0.5...2, step: 0.25) { "\(Int($0 * 100))%" }
/// ```
public struct KitStepper<V: Strideable>: View {
  var title: String
  @Binding var value: V
  var range: ClosedRange<V>
  var step: V.Stride
  var format: (V) -> String
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @FocusState private var focus: CtlStepperPart?

  /// A stepper whose value reads as a number, followed by `unit` when there is one ("13 pt").
  public init(
    _ title: String = "", value: Binding<V>, in range: ClosedRange<V>, step: V.Stride = 1, unit: String? = nil
  ) {
    self.init(title, value: value, in: range, step: step) { value in
      let number = CtlNumberText.string(value)
      return unit.map { "\(number) \($0)" } ?? number
    }
  }

  /// A stepper that shows its value as `format` returns it.
  public init(
    _ title: String = "", value: Binding<V>, in range: ClosedRange<V>, step: V.Stride = 1,
    format: @escaping (V) -> String
  ) {
    self.title = title
    _value = value
    self.range = range
    self.step = step
    self.format = format
  }

  public var body: some View {
    let metrics = CtlStepperMetrics(idiom)
    HStack(spacing: 2) {
      button(.decrement, systemImage: "minus", enabled: canDecrement, metrics: metrics)
      Text(format(value))
        .kitFont(.body)
        .fontWeight(.semibold)
        .monospacedDigit()
        .lineLimit(1)
        .padding(.horizontal, 6)
        .frame(minWidth: metrics.valueWidth, minHeight: metrics.button)
        .background { CtlRaisedCard(cornerRadius: metrics.radius) }
        .contentTransition(.numericText())
      button(.increment, systemImage: "plus", enabled: canIncrement, metrics: metrics)
    }
    .padding(2)
    .background { CtlTrack(cornerRadius: metrics.radius + 2) }
    .ctlFieldRing(focus != nil, cornerRadius: metrics.radius + 2)
    .opacity(isEnabled ? 1 : 0.45)
    .fixedSize()
    .focusEffectDisabled()
    .onKeyPress(keys: [.upArrow, .rightArrow]) { _ in stepped(up: true) }
    .onKeyPress(keys: [.downArrow, .leftArrow]) { _ in stepped(up: false) }
    .animation(.kitFast, value: CtlNumberText.string(value))
    #if os(tvOS)
    // No system stepper on Apple TV: the kit's takes VoiceOver's swipes itself.
    .accessibilityElement()
    .accessibilityLabel(Text(title))
    .accessibilityAdjustableAction { direction in step(up: direction == .increment) }
    #else
    .accessibilityRepresentation {
      Stepper(title, value: $value, in: range, step: step)
    }
    #endif
    .accessibilityValue(format(value))
  }

  private func button(_ part: CtlStepperPart, systemImage: String, enabled: Bool, metrics: CtlStepperMetrics)
    -> some View
  {
    Button {
      step(up: part == .increment)
    } label: {
      CtlStepperButtonLabel(systemImage: systemImage, isFocused: focus == part, metrics: metrics)
    }
    .buttonStyle(CtlPressStyle())
    .disabled(!enabled)
    .focused($focus, equals: part)
    .accessibilityLabel(part == .increment ? "Increment" : "Decrement")
  }

  private var canIncrement: Bool { value < range.upperBound }
  private var canDecrement: Bool { value > range.lowerBound }

  private func step(up: Bool) {
    value = CtlStepperMath.stepped(value, by: step, up: up, in: range)
  }

  private func stepped(up: Bool) -> KeyPress.Result {
    guard focus != nil else { return .ignored }
    step(up: up)
    return .handled
  }
}

enum CtlStepperPart: Hashable { case decrement, increment }

enum CtlStepperMath {
  /// `value` one `step` up or down, clamped to `range`.
  static func stepped<V: Strideable>(_ value: V, by step: V.Stride, up: Bool, in range: ClosedRange<V>) -> V {
    let next = value.advanced(by: up ? step : -step)
    return min(max(next, range.lowerBound), range.upperBound)
  }
}

/// Numbers as the kit shows them: integers as they are, fractions with up to two digits ("13", "0.25", "1.5").
enum CtlNumberText {
  static func string<V>(_ value: V, locale: Locale = .autoupdatingCurrent) -> String {
    if let value = value as? any BinaryFloatingPoint {
      return Double(value).formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale))
    }
    if let value = value as? any BinaryInteger {
      return Int(value).formatted(.number.grouping(.never).locale(locale))
    }
    return "\(value)"
  }
}

struct CtlStepperMetrics {
  var button: CGFloat
  var buttonWidth: CGFloat
  var radius: CGFloat
  var valueWidth: CGFloat

  init(_ idiom: KitIdiom) {
    switch idiom {
    case .mac: (button, buttonWidth, radius, valueWidth) = (24, 24, 7, 34)
    case .pad: (button, buttonWidth, radius, valueWidth) = (32, 32, 10, 44)
    case .phone: (button, buttonWidth, radius, valueWidth) = (36, 40, 11, 48)
    }
  }
}

struct CtlStepperButtonLabel: View {
  let systemImage: String
  let isFocused: Bool
  let metrics: CtlStepperMetrics
  @Environment(\.ctlIsPressed) private var isPressed
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)
    Image(systemName: systemImage)
      .font(.system(size: metrics.button * 0.42, weight: .semibold))
      .foregroundStyle(!isEnabled ? .kitTertiary : isHovered || isPressed || isFocused ? .kitLabel : .kitSecondary)
      .frame(width: metrics.buttonWidth, height: metrics.button)
      .background {
        if isEnabled && isPressed {
          shape.fill(.kitPress)
        } else if isEnabled && isFocused {
          shape.fill(KitColor.ctlGhost)
        } else if isEnabled && isHovered {
          shape.fill(.kitHover)
        }
      }
      .kitHover { isHovered = $0 }
      .animation(.kitFast, value: isHovered)
  }
}

#Preview("Stepper") {
  @Previewable @State var size = 13
  @Previewable @State var zoom = 1.0
  VStack(spacing: 12) {
    KitStepper("Font size", value: $size, in: 9...24, unit: "pt")
    KitStepper("Zoom", value: $zoom, in: 0.5...2, step: 0.25) { "\(Int($0 * 100))%" }
  }
  .padding(20)
  .componentKit()
}
