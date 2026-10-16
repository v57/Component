import SwiftUI

/// The kit's buttons, drawn by the kit so they look the same on every platform. Size follows `.controlSize`
/// (small 28, regular 30, large 34); `Button(role: .destructive)` turns the label red.
///
/// ```swift
/// Button("Cancel") { … }.buttonStyle(.kit)
/// Button("Clone") { … }.buttonStyle(.kitPrimary)
/// Button("Discard", role: .destructive) { … }.buttonStyle(.kit)
/// ```
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

  private var isDestructive: Bool { configuration.role == .destructive }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    configuration.label
      .kitFont(kind == .primary ? .headline : .body)
      .fontWeight(kind == .primary ? .semibold : .medium)
      .labelStyle(KitButtonLabelStyle(iconOnly: kind == .icon))
      .lineLimit(1)
      .foregroundStyle(foreground)
      .padding(.horizontal, kind == .icon ? 0 : horizontalPadding)
      .frame(minWidth: kind == .icon ? height : nil, minHeight: height)
      .frame(width: kind == .icon ? height : nil)
      .background { background(shape) }
      .overlay {
        shape.fill(Color.primary.opacity(configuration.isPressed ? 0.1 : isHovered && isEnabled ? 0.04 : 0))
      }
      .opacity(isEnabled || kind == .primary ? 1 : 0.45)
      .contentShape(shape)
      .onHover { isHovered = $0 }
      .animation(.kitFast, value: isHovered)
      .animation(.kitFast, value: configuration.isPressed)
  }

  private var height: CGFloat {
    if kind == .icon { return idiom.isTouch ? 32 : 24 }
    let base: CGFloat =
      switch controlSize {
      case .mini, .small: KitMetrics.controlSmall
      case .large, .extraLarge: KitMetrics.controlLarge
      default: KitMetrics.controlRegular
      }
    return idiom.isTouch ? base + 8 : base
  }

  private var radius: CGFloat {
    if kind == .icon { return 6 }
    return height <= 28 ? 7 : height <= 30 ? 8 : 9
  }

  private var horizontalPadding: CGFloat { kind == .plain ? 8 : 12 }

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
      shape.fill(isHovered && isEnabled ? AnyShapeStyle(.kitHover) : AnyShapeStyle(Color.clear))
    }
  }
}

/// Icon and title 6pt apart; an icon-only button shows just the icon (the title stays for accessibility).
struct KitButtonLabelStyle: LabelStyle {
  var iconOnly: Bool

  func makeBody(configuration: Configuration) -> some View {
    if iconOnly {
      configuration.icon
    } else {
      HStack(spacing: 6) {
        configuration.icon.imageScale(.small)
        configuration.title
      }
    }
  }
}
