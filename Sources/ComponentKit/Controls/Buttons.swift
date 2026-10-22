import SwiftUI

/// The kit's buttons, drawn by the kit so they look the same on every platform. Size follows `.controlSize`
/// (small 28, regular 30, large 34); `Button(role: .destructive)` turns the label red.
///
/// ```swift
/// Button("Cancel") { … }.buttonStyle(.kit)
/// Button("Clone") { … }.buttonStyle(.kitPrimary)
/// Button("Discard", role: .destructive) { … }.buttonStyle(.kit)
/// ```
///
/// On Apple TV a focused button grows 16%, tilts and lights as `kitHoverEffect` does, and a primary's tint fills 20%
/// more: no ring.
public struct KitButtonStyle: ButtonStyle {
  public enum Kind: Hashable, Sendable {
    /// A raised button: white in light, one step of light in dark.
    case secondary
    /// The accent, white label: the one action a view leads with.
    case primary
    /// Text in the accent, a fill on hover (links, Undo, Show All).
    case plain
    /// A square icon button for headers and rows (24pt, 28 on touch).
    case icon
  }

  var kind: Kind

  public init(_ kind: Kind = .secondary) { self.kind = kind }

  public func makeBody(configuration: Configuration) -> some View {
    KitButton(configuration: configuration, kind: kind)
  }
}

extension ButtonStyle where Self == KitButtonStyle {
  public static var kit: KitButtonStyle { KitButtonStyle(.secondary) }
  public static var kitPrimary: KitButtonStyle { KitButtonStyle(.primary) }
  public static var kitPlain: KitButtonStyle { KitButtonStyle(.plain) }
  public static var kitIcon: KitButtonStyle { KitButtonStyle(.icon) }
}

struct KitButton: View {
  let configuration: ButtonStyleConfiguration
  let kind: KitButtonStyle.Kind
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.controlSize) private var controlSize
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.colorScheme) private var scheme
  @State private var isHovered = false
  #if os(tvOS)
    @Environment(\.isFocused) private var isFocused
  #else
    private let isFocused = false
  #endif

  private var isDestructive: Bool { configuration.role == .destructive }
  /// Hovered on the Mac and iPad, focused on Apple TV.
  private var isLit: Bool { (isHovered || isFocused) && isEnabled }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    configuration.label
      .kitFont(kind == .primary ? .headline : .body)
      .fontWeight(kind == .primary ? .semibold : .medium)
      .labelStyle(KitButtonLabelStyle(iconOnly: kind == .icon, spacing: 6 * idiom.scale))
      .lineLimit(1)
      .foregroundStyle(foreground)
      .padding(.horizontal, kind == .icon ? 0 : horizontalPadding)
      .frame(minWidth: kind == .icon ? height : nil, minHeight: height)
      .frame(width: kind == .icon ? height : nil)
      .background { background(shape) }
      .overlay {
        shape.fill(Color.primary.opacity(configuration.isPressed ? 0.1 : isLit ? 0.04 : 0))
      }
      .opacity(isEnabled || kind == .primary ? 1 : 0.45)
      .contentShape(shape)
      .kitHover { isHovered = $0 }
      #if os(tvOS)
      .overlay {
        // The tint fills 20% more while focused.
        if isFocused && kind == .primary && isEnabled { shape.fill(Color.white.opacity(0.2)).allowsHitTesting(false) }
      }
      .kitFocusedButton(in: shape, isPressed: configuration.isPressed)
      #endif
      .animation(.kitFast, value: isHovered)
      .animation(.kitFast, value: configuration.isPressed)
  }

  private var height: CGFloat {
    if kind == .icon { return idiom.size(24, touch: 32) }
    let base: CGFloat =
      switch controlSize {
      case .mini, .small: KitMetrics.controlSmall
      case .large, .extraLarge: KitMetrics.controlLarge
      default: KitMetrics.controlRegular
      }
    return idiom.isTouch ? base + 8 : base
  }

  private var radius: CGFloat {
    if kind == .icon { return 6 * idiom.scale }
    let height = height / idiom.scale
    return (height <= 28 ? 7 : height <= 30 ? 8 : 9) * idiom.scale
  }

  private var horizontalPadding: CGFloat { (kind == .plain ? 8 : 12) * idiom.scale }

  private var foreground: AnyShapeStyle {
    if isDestructive {
      // A disabled destructive primary sits on the raised ground like any disabled primary: white would vanish.
      if kind == .primary { return isEnabled ? AnyShapeStyle(Color.white) : AnyShapeStyle(.kitSecondary) }
      return AnyShapeStyle(Hue.red.text)
    }
    switch kind {
    case .primary: return isEnabled ? AnyShapeStyle(Color.white) : AnyShapeStyle(.kitSecondary)
    case .plain: return AnyShapeStyle(Hue.accent.text)
    case .icon: return AnyShapeStyle(.kitSecondary)
    case .secondary: return AnyShapeStyle(.kitLabel)
    }
  }

  @ViewBuilder
  private func background(_ shape: RoundedRectangle) -> some View {
    switch kind {
    case .primary:
      if isEnabled {
        // Destructive primaries take red; white text needs the hue darkened to 85% for 4.5:1.
        shape.fill(isDestructive ? Hue.red.fill : Hue.accent.fill)
          .overlay(shape.fill(Color.black.opacity(0.08)))
      } else {
        shape.fill(.kitRaised).opacity(scheme == .dark ? 0.55 : 1)
      }
    case .secondary:
      SurfaceShape(surface: .raised, cornerRadius: radius)
    case .plain, .icon:
      shape.fill(isLit ? AnyShapeStyle(.kitHover) : AnyShapeStyle(Color.clear))
    }
  }
}

/// Icon and title 6pt apart; an icon-only button shows just the icon (the title stays for accessibility).
struct KitButtonLabelStyle: LabelStyle {
  var iconOnly: Bool
  var spacing: CGFloat = 6

  func makeBody(configuration: Configuration) -> some View {
    if iconOnly {
      configuration.icon
    } else {
      HStack(spacing: spacing) {
        configuration.icon.imageScale(.small)
        configuration.title
      }
    }
  }
}

#if os(tvOS)
  extension View {
    /// A kit button's focus on Apple TV: the hover effect, driven by the button's focus, growing 16% (the canvas's
    /// focused buttons), its press sinking it back.
    func kitFocusedButton<S: InsettableShape>(in shape: S, isPressed: Bool) -> some View {
      kitHoverEffect(in: shape)
        .environment(\.kitFocusGrowth, 0.16)
        .environment(\.kitHoverPressed, isPressed)
    }
  }
#endif

// MARK: - Round

/// A round button on its own, on the card ground of the toolbar's tool groups (32pt, 44 on touch, the same height):
/// Trash in a player's toolbar, a close button, a share button. Shows the icon alone (the title stays for
/// accessibility and the tooltip); `role: .destructive` turns it red. `.controlSize(.small)` is 28pt.
///
/// ```swift
/// Button("Move to Trash", systemImage: "trash", role: .destructive) { … }.buttonStyle(.kitRound)
/// ```
public struct KitRoundButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    KitRoundButton(configuration: configuration)
  }
}

extension ButtonStyle where Self == KitRoundButtonStyle {
  public static var kitRound: KitRoundButtonStyle { KitRoundButtonStyle() }
}

struct KitRoundButton: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.controlSize) private var controlSize
  @Environment(\.kitIdiom) private var idiom
  @State private var isHovered = false

  var body: some View {
    let size = KitRoundButton.size(idiom: idiom, small: controlSize == .small || controlSize == .mini)
    configuration.label
      .labelStyle(.iconOnly)
      .font(.system(size: size * 0.42, weight: .medium))
      .foregroundStyle(
        configuration.role == .destructive ? AnyShapeStyle(Hue.red.text)
          : isEnabled ? AnyShapeStyle(.kitLabel) : AnyShapeStyle(.kitTertiary))
      .frame(width: size, height: size)
      .background { SurfaceShape(surface: .card, cornerRadius: size / 2) }
      .overlay {
        Circle().fill(Color.primary.opacity(configuration.isPressed ? 0.1 : isHovered && isEnabled ? 0.04 : 0))
      }
      .contentShape(Circle())
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .kitHover { isHovered = $0 }
      #if os(tvOS)
      .kitFocusedButton(in: Circle(), isPressed: configuration.isPressed)
      #endif
      .animation(.kitFast, value: isHovered)
      .animation(.kitFast, value: configuration.isPressed)
  }

  /// 32pt (28 small) on the Mac, 44 (36 small) on touch, 64 (56 small) on Apple TV.
  static func size(idiom: KitIdiom, small: Bool) -> CGFloat {
    idiom.size(small ? 28 : 32, touch: small ? 36 : 44)
  }
}

#Preview("Round") {
  HStack(spacing: 12) {
    Button("Move to Trash", systemImage: "trash", role: .destructive) {}.buttonStyle(.kitRound)
    Button("Share", systemImage: "square.and.arrow.up") {}.buttonStyle(.kitRound)
    Button("Close", systemImage: "xmark") {}.buttonStyle(.kitRound).controlSize(.small)
    Button("Add", systemImage: "plus") {}.buttonStyle(.kitRound).disabled(true)
  }
  .padding(20)
  .background(.kitWindow)
  .componentKit()
}
