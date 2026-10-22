import SwiftUI

/// Where a slider sits: on the kit's grounds, or over a picture or video.
public enum KitSliderStyle: Hashable, Sendable {
  /// The field track and the accent fill (forms, inspectors).
  case standard
  /// Over a video or a photo (a player's scrubber, volume): the track is white at 50%; the track and the knob wear a
  /// hairline dark edge and a soft halo (the played part sits in the track's), so they hold on a white frame.
  case overlay
}

extension EnvironmentValues {
  @Entry var kitSliderStyle: KitSliderStyle = .standard
}

extension View {
  /// Sets how the `KitSlider`s inside draw: `.standard`, or `.overlay` over a video.
  ///
  /// ```swift
  /// KitSlider("Position", value: $time, in: 0...duration).kitSliderStyle(.overlay)
  /// ```
  public func kitSliderStyle(_ style: KitSliderStyle) -> some View {
    environment(\.kitSliderStyle, style)
  }
}

/// The kit's slider: a 6pt field track filled with the accent up to a white pill knob, the value in a bubble above
/// the knob while dragging. Hover rings the knob at half the accent; keyboard focus gives it the solid ring, and
/// ← → (↓ ↑) move it by `step` (or a twentieth of the range). VoiceOver reads an adjustable value.
///
/// ```swift
/// KitSlider("Volume", value: $volume)
/// KitSlider("Scale", value: $scale, in: 0.5...2, step: 0.1) { "\(Int($0 * 100))%" }
/// ```
public struct KitSlider<V: BinaryFloatingPoint>: View where V.Stride: BinaryFloatingPoint {
  var title: String
  @Binding var value: V
  var range: ClosedRange<V>
  var step: V.Stride?
  var bubble: Visibility
  var format: (V) -> String
  var onEditingChanged: (Bool) -> Void
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitSliderStyle) private var style
  @FocusState private var isFocused: Bool
  @State private var isDragging = false
  @State private var isHovered = false

  /// A slider over `range`. `valueBubble` `.automatic` shows the value while dragging, `.visible` always,
  /// `.hidden` never; `format` writes it (a number by default).
  public init(
    _ title: String = "", value: Binding<V>, in range: ClosedRange<V> = 0...1, step: V.Stride? = nil,
    valueBubble: Visibility = .automatic, format: ((V) -> String)? = nil,
    onEditingChanged: @escaping (Bool) -> Void = { _ in }
  ) {
    self.title = title
    _value = value
    self.range = range
    self.step = step
    self.bubble = valueBubble
    self.onEditingChanged = onEditingChanged
    self.format = format ?? { CtlNumberText.string($0) }
  }

  public var body: some View {
    let metrics = CtlSliderMetrics(idiom)
    GeometryReader { geometry in
      let width = geometry.size.width
      let fraction = CtlSliderMath.fraction(Double(value), in: Double(range.lowerBound)...Double(range.upperBound))
      let center = CtlSliderMath.knobCenter(fraction: fraction, width: width, knobWidth: metrics.knobWidth)
      let overlay = style == .overlay
      ZStack(alignment: .leading) {
        // Over a video the track's halo is the played part's too: the fill lies inside it and casts nothing.
        Capsule().fill(overlay ? AnyShapeStyle(KitColor.ctlOnMedia) : AnyShapeStyle(.kitFill))
          .overlay { if overlay { Capsule().stroke(Color.black.opacity(0.4), lineWidth: 0.5) } }
          .frame(height: metrics.track)
          .shadow(color: .black.opacity(overlay ? 0.4 : 0), radius: 1)
          .shadow(color: .black.opacity(overlay ? 0.3 : 0), radius: 3, y: 1)
        Capsule().fill(Hue.accent.fill)
          .frame(width: max(center, metrics.track), height: metrics.track)
        Capsule()
          .fill(KitColor.ctlKnob)
          .overlay {
            if overlay {
              Capsule().stroke(Color.black.opacity(0.4), lineWidth: 0.5)
            } else {
              Capsule().strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
            }
          }
          .shadow(color: .black.opacity(overlay ? 0.4 : 0.2), radius: 1.5, y: 1)
          .shadow(color: .black.opacity(overlay ? 0.3 : 0), radius: 4, y: 2)
          .frame(width: metrics.knobWidth, height: metrics.knobHeight)
          .ctlFieldRing((isHovered || isDragging) && !isFocused, cornerRadius: metrics.knobHeight / 2)
          .ctlStandaloneRing(isFocused, cornerRadius: nil)
          .offset(x: center - metrics.knobWidth / 2)
        if showsBubble {
          Text(format(value))
            .foregroundStyle(.kitLabel)
            .kitFont(.caption)
            .fontWeight(.semibold)
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
              CtlRaisedCard(cornerRadius: 6)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
            }
            .fixedSize()
            .position(x: center, y: -11)
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            .allowsHitTesting(false)
        }
      }
      .frame(height: geometry.size.height)
      .contentShape(Rectangle())
      #if !os(tvOS)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { drag in
            if !isDragging {
              isDragging = true
              onEditingChanged(true)
            }
            let fraction = CtlSliderMath.fraction(atX: drag.location.x, width: width, knobWidth: metrics.knobWidth)
            value = snapped(range.lowerBound + V(fraction) * (range.upperBound - range.lowerBound))
          }
          .onEnded { _ in
            isDragging = false
            onEditingChanged(false)
          },
        isEnabled: isEnabled)
      #endif
    }
    .frame(height: metrics.height)
    .frame(minWidth: 96)
    .opacity(isEnabled ? 1 : 0.45)
    .kitHover { isHovered = $0 }
    .focusable(isEnabled, interactions: .activate)
    .focused($isFocused)
    .focusEffectDisabled()
    .onKeyPress(keys: [.rightArrow, .upArrow]) { _ in nudge(1) }
    .onKeyPress(keys: [.leftArrow, .downArrow]) { _ in nudge(-1) }
    .animation(.kitFast, value: showsBubble)
    .animation(.kitFast, value: isHovered)
    #if os(tvOS)
    // No system slider on Apple TV: the kit's takes VoiceOver's swipes itself.
    .accessibilityElement()
    .accessibilityLabel(Text(title))
    .accessibilityAdjustableAction { direction in _ = nudge(direction == .increment ? 1 : -1) }
    #else
    .accessibilityRepresentation {
      Slider(value: $value, in: range) { Text(title) }
    }
    #endif
    .accessibilityValue(format(value))
  }

  private var showsBubble: Bool {
    switch bubble {
    case .visible: true
    case .hidden: false
    default: isDragging
    }
  }

  private func snapped(_ raw: V) -> V {
    V(CtlSliderMath.snap(Double(raw), step: step.map { Double($0) }, in: Double(range.lowerBound)...Double(range.upperBound)))
  }

  private func nudge(_ direction: Double) -> KeyPress.Result {
    guard isFocused else { return .ignored }
    let span = Double(range.upperBound - range.lowerBound)
    let amount = step.map { Double($0) } ?? span / 20
    value = snapped(V(Double(value) + direction * amount))
    return .handled
  }
}

/// The slider's math, apart from the view so it can be tested. The knob travels inside the track (its centre from
/// half a knob in to half a knob from the end), so it never overhangs.
enum CtlSliderMath {
  /// Where `value` sits in `range`, 0…1.
  static func fraction(_ value: Double, in range: ClosedRange<Double>) -> Double {
    let span = range.upperBound - range.lowerBound
    guard span > 0 else { return 0 }
    return min(max((value - range.lowerBound) / span, 0), 1)
  }

  /// The knob's centre for `fraction` on a track `width` wide.
  static func knobCenter(fraction: Double, width: CGFloat, knobWidth: CGFloat) -> CGFloat {
    let travel = max(width - knobWidth, 0)
    return knobWidth / 2 + travel * fraction
  }

  /// The fraction under a pointer at `x`.
  static func fraction(atX x: CGFloat, width: CGFloat, knobWidth: CGFloat) -> Double {
    let travel = width - knobWidth
    guard travel > 0 else { return 0 }
    return min(max(Double((x - knobWidth / 2) / travel), 0), 1)
  }

  /// `value` clamped to `range` and rounded to the nearest `step` from the range's start.
  static func snap(_ value: Double, step: Double?, in range: ClosedRange<Double>) -> Double {
    var value = min(max(value, range.lowerBound), range.upperBound)
    if let step, step > 0 {
      value = range.lowerBound + ((value - range.lowerBound) / step).rounded() * step
      value = min(max(value, range.lowerBound), range.upperBound)
    }
    return value
  }
}

struct CtlSliderMetrics {
  var height: CGFloat
  var track: CGFloat
  var knobWidth: CGFloat
  var knobHeight: CGFloat

  init(_ idiom: KitIdiom) {
    switch idiom {
    case .mac: (height, track, knobWidth, knobHeight) = (20, 6, 24, 16)
    case .pad: (height, track, knobWidth, knobHeight) = (28, 8, 32, 22)
    case .phone: (height, track, knobWidth, knobHeight) = (30, 8, 36, 24)
    case .tv: (height, track, knobWidth, knobHeight) = (40, 12, 48, 32)
    }
  }
}

#Preview("Slider") {
  @Previewable @State var scale = 1.4
  @Previewable @State var volume = 0.3
  VStack(spacing: 24) {
    KitSlider("Scale", value: $scale, in: 0.5...2, step: 0.1, valueBubble: .visible) { "\(Int($0 * 100))%" }
    KitSlider("Volume", value: $volume)
    KitSlider("Position", value: $volume).kitSliderStyle(.overlay)
      .padding(12)
      .background(LinearGradient(colors: [.orange, .white], startPoint: .leading, endPoint: .trailing))
  }
  .padding(30)
  .frame(width: 260)
  .componentKit()
}
