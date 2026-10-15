import SwiftUI

// Shared pieces of the badges: the chip's tint and ink, the one solid label's red, and the chip sizes. Internal;
// candidates for Foundation if other areas need them.

/// A badge's tinted ground: the hue at 16% in light and 20% in dark (refs: 16% / 22%).
struct BadgeTint: ShapeStyle {
  var hue: Hue
  var light: Double = 0.16
  var dark: Double = 0.20

  func resolve(in environment: EnvironmentValues) -> Color {
    let amount = environment.colorScheme == .dark ? dark : light
    return Hue.fill(hue, in: environment).opacity(amount).color
  }
}

/// A badge's text on its tint: the hue's text tone, a touch darker in light (88% with black) so it keeps 4.5:1 on a
/// selected row too. Yellow reads in orange's text tone.
struct BadgeInk: ShapeStyle {
  var hue: Hue

  func resolve(in environment: EnvironmentValues) -> Color {
    let text = HueStyle(hue: hue == .yellow ? .orange : hue, role: .text).rgba(in: environment)
    if environment.colorScheme == .dark { return text.color }
    return text.mixed(with: .black(1), 0.88).color
  }
}

/// The identity grounds (rv-identity C): a thing's or agent's soft tile is the hue at 14% (20% in dark); its letters
/// are the hue's text tone mixed with black (82%) in light, with white (65%) in dark.
struct IdentityTint: ShapeStyle {
  var hue: Hue

  func resolve(in environment: EnvironmentValues) -> Color {
    Hue.fill(hue, in: environment).opacity(environment.colorScheme == .dark ? 0.2 : 0.14).color
  }
}

struct IdentityInk: ShapeStyle {
  var hue: Hue

  func resolve(in environment: EnvironmentValues) -> Color {
    let text = HueStyle(hue: hue == .yellow ? .orange : hue, role: .text).rgba(in: environment)
    if environment.colorScheme == .dark { return text.mixed(with: .white(1), 0.65).color }
    return text.mixed(with: .black(1), 0.82).color
  }
}

/// A person's circle: the hue's deep shade (one value in both appearances), so white initials reach 4.5:1 on every
/// hue; a soft top-down gradient from 92% of it with white.
struct PersonFill: ShapeStyle {
  var hue: Hue

  func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
    let deep = Self.deep(hue, in: environment)
    return LinearGradient(
      colors: [deep.mixed(with: .white(1), 0.92).color, deep.color], startPoint: .top, endPoint: .bottom)
  }

  static func deep(_ hue: Hue, in environment: EnvironmentValues) -> RGBA {
    switch hue {
    case .accent: environment.kitAccent.resolve(in: environment).rgba.mixed(with: .black(1), 0.62)
    case .yellow: RGBA(0x765a00)
    default: hue.lightText
    }
  }
}

extension Hue {
  /// The hue's fill for `environment`, the accent read from it.
  static func fill(_ hue: Hue, in environment: EnvironmentValues) -> RGBA {
    HueStyle(hue: hue, role: .fill).rgba(in: environment)
  }
}

extension KitColor {
  /// The one solid label (Production): white on it is 6.5:1 in light, 5.4:1 in dark.
  static let dangerSolid = KitColor(RGBA(0xc00012), RGBA(0xd70015))
}

/// A chip's metrics from `.controlSize` and the idiom: 18pt (22 iPad, 24 iPhone), small 15pt everywhere.
struct ChipMetrics {
  var height: CGFloat
  var fontSize: CGFloat
  var padding: CGFloat
  var radius: CGFloat
  var gap: CGFloat
  var glyph: CGFloat

  init(controlSize: ControlSize, idiom: KitIdiom) {
    if controlSize == .small || controlSize == .mini {
      self.init(height: 15, fontSize: 10, padding: 5, radius: 4, gap: 3, glyph: 9)
    } else {
      switch idiom {
      case .mac: self.init(height: 18, fontSize: 11, padding: 6, radius: 5, gap: 4, glyph: 10)
      case .pad: self.init(height: 22, fontSize: 12, padding: 8, radius: 6, gap: 5, glyph: 12)
      case .phone: self.init(height: 24, fontSize: 13, padding: 8, radius: 6, gap: 5, glyph: 12)
      }
    }
  }

  init(height: CGFloat, fontSize: CGFloat, padding: CGFloat, radius: CGFloat, gap: CGFloat, glyph: CGFloat) {
    self.height = height
    self.fontSize = fontSize
    self.padding = padding
    self.radius = radius
    self.gap = gap
    self.glyph = glyph
  }

  var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }
}

/// Bare figures (counts, sync, line counts): 11pt on the Mac, 13 on iPad, 15 on iPhone.
func badgeFigureSize(_ idiom: KitIdiom) -> CGFloat {
  switch idiom {
  case .mac: 11
  case .pad: 13
  case .phone: 15
  }
}
