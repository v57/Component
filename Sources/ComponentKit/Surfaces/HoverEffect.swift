import SwiftUI

#if os(iOS)
import UIKit
#endif

// Hub's 3D hover: the view tilts toward the pointer, a soft light follows it and a rim catches the light. A view
// inside another one (a tile in a card) tilts less and lights its parent faintly, so the parent reads as focused too.
//
// The light and the rim are only in the tree while the view is lit (hovered, touched, pressed, or a child is): an
// idle view draws its content and nothing else, however many there are on screen.

extension View {
  /// Tilts the view toward the pointer and lights it where the pointer is; touches do the same on iOS. Inside
  /// another hover effect it tilts less and lights the outer view faintly. Put it on the thing that's pressed (the
  /// tile, the card), not around its caption: text under the light washes out. In a button, give the button
  /// `.buttonStyle(.kitHoverEffect)` so presses deepen the effect.
  ///
  ///     Button { open() } label: {
  ///       Image(systemName: "clock").frame(width: 56, height: 56)
  ///         .background(.kitCard, in: .rect(cornerRadius: KitMetrics.radiusCard))
  ///         .kitHoverEffect(in: .rect(cornerRadius: KitMetrics.radiusCard))
  ///     }
  ///     .buttonStyle(.kitHoverEffect)
  public func kitHoverEffect<S: InsettableShape>(in shape: S) -> some View {
    modifier(KitHoverEffect(shape: shape))
  }

  /// Keeps the hover effects around this view flat: they still light, but don't tilt (a view that holds a text
  /// field, or one too wide to tilt well).
  public func kitHoverTiltDisabled(_ disabled: Bool = true) -> some View {
    preference(key: HoverTiltDisabled.self, value: disabled)
  }
}

extension ButtonStyle where Self == KitHoverEffectButtonStyle {
  /// A plain button whose presses reach the `kitHoverEffect`s in its label.
  public static var kitHoverEffect: KitHoverEffectButtonStyle { KitHoverEffectButtonStyle() }
}

/// A plain button whose presses reach the `kitHoverEffect`s in its label. Use `.kitHoverEffect`.
public struct KitHoverEffectButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .environment(\.kitHoverPressed, configuration.isPressed)
      .animation(.kit, value: configuration.isPressed)
  }
}

extension LabelStyle where Self == KitHoverTileLabelStyle {
  /// The icon on a card that tilts and lights, the title under it outside the effect (Hub's home buttons). Pair
  /// with `.buttonStyle(.kitHoverEffect)`.
  public static var kitHoverTile: KitHoverTileLabelStyle { KitHoverTileLabelStyle() }
}

/// The icon on a card that tilts and lights, the title under it outside the effect. Use `.kitHoverTile`.
public struct KitHoverTileLabelStyle: LabelStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusOverlay, style: .continuous)
    VStack(spacing: 6) {
      configuration.icon
        .font(.system(size: 26, weight: .medium))
        .frame(width: 64, height: 64)
        .background { shape.fill(.kitCard).strokeBorder(.kitBorder) }
        .kitHoverEffect(in: shape)
      configuration.title
        .font(.callout)
        .foregroundStyle(.kitLabel)
        .lineLimit(1)
    }
    .contentShape(.rect)
  }
}

extension EnvironmentValues {
  /// The enclosing `.kitHoverEffect` button is pressed.
  @Entry var kitHoverPressed = false
  /// Inside another hover effect: tilt less, so the inner view doesn't leave its parent.
  @Entry fileprivate var kitHoverInner = false
}

/// Whether a hover effect inside is lit (any of them), so its parent dims its own light.
private struct HoverInnerLit: PreferenceKey {
  static let defaultValue = false
  static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

private struct HoverTiltDisabled: PreferenceKey {
  static let defaultValue = false
  static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

private struct KitHoverEffect<S: InsettableShape>: ViewModifier {
  let shape: S

  @Environment(\.colorScheme) private var scheme
  @Environment(\.kitHoverPressed) private var isPressed
  @Environment(\.kitHoverInner) private var isInner
  @Environment(\.displayScale) private var displayScale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var hovering = false
  @State private var touching = false
  /// Where the pointer is, from -0.5 to 0.5 across the view.
  @State private var offset = CGPoint.zero
  @State private var size = CGSize(width: 1, height: 1)
  @State private var innerLit = false
  @State private var tiltDisabled = false
  /// Whether the light is in the tree: set as soon as the view lights, cleared once it has faded out.
  @State private var lightOn = false

  private var isActive: Bool { hovering || touching }
  private var wantsLight: Bool { isActive || isPressed || innerLit }
  private var isDark: Bool { scheme == .dark }
  /// Tilting blurs edges on a low-resolution screen, and moves the view under Reduce Motion.
  private var tilts: Bool { displayScale >= 1.5 && !reduceMotion && !tiltDisabled }

  func body(content: Content) -> some View {
    content
      .environment(\.kitHoverInner, true)
      .onPreferenceChange(HoverInnerLit.self) { lit in
        withAnimation(.spring(response: 0.25, dampingFraction: 1)) { innerLit = lit }
      }
      .onPreferenceChange(HoverTiltDisabled.self) { tiltDisabled = $0 }
      .overlay {
        if lightOn {
          shape.fill(light).strokeBorder(rim, lineWidth: 1).allowsHitTesting(false)
        }
      }
      .rotation3DEffect(tilts ? .degrees(-offset.y * 8) : .zero, axis: (1, 0, 0), anchorZ: depth)
      .rotation3DEffect(tilts ? .degrees(offset.x * 8) : .zero, axis: (0, 1, 0), anchorZ: depth)
      .offset(x: tilts ? offset.x * shift : 0, y: tilts ? offset.y * shift : 0)
      .background {
        GeometryReader { proxy in
          Color.clear.onAppear { size = proxy.size }.onChange(of: proxy.size) { _, new in size = new }
        }
      }
      .preference(key: HoverInnerLit.self, value: isActive)
      .modifier(HoverInput(hovering: $hovering, touching: $touching, offset: $offset, size: size))
      .task(id: wantsLight) {
        if wantsLight {
          lightOn = true
        } else {
          // Long enough for the light to spread and fade (the 0.5 s spring of a hover ending).
          try? await Task.sleep(for: .seconds(0.7))
          if !Task.isCancelled { lightOn = false }
        }
      }
  }

  private var shift: Double { isInner ? 2 : 8 }

  private var depth: Double {
    guard tilts else { return 0 }
    if isPressed { return isInner ? -5 : -10 }
    if isActive { return isInner ? -4 : -8 }
    return 0
  }

  private var center: UnitPoint { UnitPoint(x: offset.x * 0.9 + 0.5, y: offset.y * 0.9 + 0.5) }

  private var light: RadialGradient {
    let start: Double, end: Double, radius: Double
    if innerLit {
      (start, end, radius) = (0.05, 0.01, 32)
    } else if isDark {
      (start, end) = (isPressed ? 0.2 : isActive ? 0.1 : 0, isActive ? 0.02 : 0)
      radius = isPressed || !isActive ? 200 : 64
    } else {
      (start, end) = (isPressed ? 0.5 : isActive ? 1 : 0, 0)
      radius = isPressed || !isActive ? 200 : 32
    }
    return RadialGradient(
      colors: [.white.opacity(start), .white.opacity(end)], center: center, startRadius: 0, endRadius: radius)
  }

  private var rim: RadialGradient {
    let color = KitColor.label.color(scheme, moreContrast: false)
    return RadialGradient(
      colors: [color.opacity(isActive ? 1 : 0), color.opacity(0)], center: center, startRadius: 0,
      endRadius: isPressed ? 64 : isActive ? 32 : 200)
  }
}

/// Pointer hover everywhere, touch drags on iOS 18, the system's gaze highlight on visionOS.
private struct HoverInput: ViewModifier {
  @Binding var hovering: Bool
  @Binding var touching: Bool
  @Binding var offset: CGPoint
  let size: CGSize

  func body(content: Content) -> some View {
    #if os(visionOS)
    content.hoverEffect { view, isActive, _ in
      view.scaleEffect(isActive ? (max(size.width, size.height) + 8) / max(size.width, size.height, 1) : 1)
    }
    #elseif os(iOS)
    if #available(iOS 18, *) {
      content.onContinuousHover(perform: hover).gesture(TouchTracking(began: touchBegan, moved: touchMoved, ended: touchEnded))
    } else {
      content.onContinuousHover(perform: hover)
    }
    #else
    content.onContinuousHover(perform: hover)
    #endif
  }

  private func hover(_ phase: HoverPhase) {
    switch phase {
    case .active(let point) where !ContDragActivity.shared.isDragging:
      withAnimation(.spring(response: 0.25, dampingFraction: 1)) {
        move(to: point)
        hovering = true
      }
    default:
      guard hovering else { return }
      withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
        offset = .zero
        hovering = false
      }
    }
  }

  private func touchBegan() {
    withAnimation(.spring(response: 0.25, dampingFraction: 1)) { touching = true }
  }

  private func touchMoved(_ point: CGPoint) {
    guard !hovering else { return }
    withAnimation(.spring(response: 0.25, dampingFraction: 1)) { move(to: point) }
  }

  private func touchEnded() {
    withAnimation(.spring(response: 0.25, dampingFraction: 1)) {
      touching = false
      if !hovering { offset = .zero }
    }
  }

  private func move(to point: CGPoint) {
    let x = point.x / max(size.width, 1) - 0.5
    let y = point.y / max(size.height, 1) - 0.5
    offset = CGPoint(x: min(max(x, -0.5), 0.5), y: min(max(y, -0.5), 0.5))
  }
}

#if os(iOS)
/// Follows a finger from touch down without taking it from the scroll view or the button under it.
@available(iOS 18, *)
private struct TouchTracking: UIGestureRecognizerRepresentable {
  let began: () -> Void
  let moved: (CGPoint) -> Void
  let ended: () -> Void

  func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
    let gesture = UILongPressGestureRecognizer()
    gesture.minimumPressDuration = 0
    gesture.allowableMovement = .greatestFiniteMagnitude
    gesture.cancelsTouchesInView = false
    gesture.delegate = context.coordinator
    return gesture
  }

  func handleUIGestureRecognizerAction(_ gesture: UILongPressGestureRecognizer, context: Context) {
    switch gesture.state {
    case .began:
      began()
      moved(context.converter.localLocation)
    case .changed: moved(context.converter.localLocation)
    case .ended, .cancelled, .failed: ended()
    default: break
    }
  }

  func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(
      _ gesture: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
  }
}
#endif
