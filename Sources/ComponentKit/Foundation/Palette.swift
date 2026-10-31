import SwiftUI

/// A colour from the kit's palette: one value for light and one for dark, picked from the environment where it's
/// drawn, so it needs no platform colour type. Use the named styles (`.kitCard`, `.kitSecondary`, `Hue.blue.fill`…)
/// rather than building one.
public struct KitColor: ShapeStyle, Hashable, Sendable {
  let light: RGBA
  let dark: RGBA
  /// Increase Contrast values; `nil` keeps the standard ones.
  var lightMore: RGBA?
  var darkMore: RGBA?

  init(_ light: RGBA, _ dark: RGBA, more lightMore: RGBA? = nil, _ darkMore: RGBA? = nil) {
    self.light = light
    self.dark = dark
    self.lightMore = lightMore
    self.darkMore = darkMore
  }

  public func resolve(in environment: EnvironmentValues) -> Color {
    rgba(in: environment).color
  }

  func rgba(in environment: EnvironmentValues) -> RGBA {
    rgba(dark: environment.colorScheme == .dark, moreContrast: environment.kitMoreContrast)
  }

  func rgba(dark isDark: Bool, moreContrast more: Bool) -> RGBA {
    if isDark { return more ? darkMore ?? dark : dark }
    return more ? lightMore ?? light : light
  }

  /// The colour as drawn where `scheme` and `moreContrast` (the environment's `kitMoreContrast`) hold, for a view
  /// that needs a `Color` (a gradient's stops, a shadow).
  func color(_ scheme: ColorScheme, moreContrast: Bool) -> Color {
    rgba(dark: scheme == .dark, moreContrast: moreContrast).color
  }

  /// The colour for one appearance, outside a view (canvas drawing, previews).
  public func color(dark: Bool) -> Color { (dark ? self.dark : light).color }
}

/// sRGB components, so tokens can be written as the design's hex and alpha values and mixed without a platform type.
struct RGBA: Hashable, Sendable {
  var r: Double, g: Double, b: Double, a: Double

  init(_ hex: UInt32, _ a: Double = 1) {
    r = Double((hex >> 16) & 0xff) / 255
    g = Double((hex >> 8) & 0xff) / 255
    b = Double(hex & 0xff) / 255
    self.a = a
  }

  init(r: Double, g: Double, b: Double, a: Double) {
    self.r = r
    self.g = g
    self.b = b
    self.a = a
  }

  static func black(_ a: Double) -> RGBA { RGBA(0x000000, a) }
  static func white(_ a: Double) -> RGBA { RGBA(0xffffff, a) }

  var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

  /// `amount` of `self` over `other`, as CSS `color-mix(in srgb, self amount, other)`.
  func mixed(with other: RGBA, _ amount: Double) -> RGBA {
    RGBA(
      r: r * amount + other.r * (1 - amount), g: g * amount + other.g * (1 - amount),
      b: b * amount + other.b * (1 - amount), a: a * amount + other.a * (1 - amount))
  }

  func opacity(_ factor: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: a * factor) }

  /// `self` drawn over `ground` (source-over), as one colour.
  func over(_ ground: RGBA) -> RGBA {
    let alpha = a + ground.a * (1 - a)
    guard alpha > 0 else { return RGBA(r: 0, g: 0, b: 0, a: 0) }
    func channel(_ top: Double, _ bottom: Double) -> Double { (top * a + bottom * ground.a * (1 - a)) / alpha }
    return RGBA(r: channel(r, ground.r), g: channel(g, ground.g), b: channel(b, ground.b), a: alpha)
  }
}

/// A translucent token as it looks over `ground`, as one opaque colour where the ground is: what a bar's controls
/// draw, so content scrolling under the bar doesn't show through them.
struct ContOver: ShapeStyle {
  let top: KitColor
  let ground: KitColor

  func resolve(in environment: EnvironmentValues) -> Color {
    top.rgba(in: environment).over(ground.rgba(in: environment)).color
  }
}

extension KitColor {
  /// This colour over the bar ground in the environment (`contBarGround`), or itself outside a bar.
  func overBarGround(_ ground: KitColor?) -> AnyShapeStyle {
    ground.map { AnyShapeStyle(ContOver(top: self, ground: $0)) } ?? AnyShapeStyle(self)
  }
}

extension Color.Resolved {
  var rgba: RGBA { RGBA(r: Double(red), g: Double(green), b: Double(blue), a: Double(opacity)) }
}

// MARK: - Grounds, text, lines

extension KitColor {
  // Grounds (dark: "steps of light", darkest first)
  static let window = KitColor(RGBA(0xffffff), RGBA(0x1c1c1e))
  static let sidebar = KitColor(RGBA(0xebebed), RGBA(0x161618))
  static let panel = KitColor(RGBA(0xf6f6f7), RGBA(0x18181a))
  static let card = KitColor(RGBA(0xffffff).opacity(0.7), RGBA(0x262628))
  static let control = KitColor(RGBA(0xffffff), RGBA(0x262628))
  static let raised = KitColor(RGBA(0xffffff), RGBA(0x3c3c3f))
  static let elevated = KitColor(RGBA(0xffffff), RGBA(0x2e2e30))

  // Text
  static let label = KitColor(.black(0.85), .white(0.88))
  static let secondary = KitColor(.black(0.55), .white(0.62), more: .black(0.7), .white(0.78))
  static let tertiary = KitColor(.black(0.3), .white(0.28), more: .black(0.5), .white(0.55))
  static let quiet = KitColor(.black(0.5), .white(0.5), more: .black(0.7), .white(0.72))
  static let sectionHeader = KitColor(.black(0.5), .white(0.55), more: .black(0.7), .white(0.72))
  static let link = KitColor(RGBA(0x0068da), RGBA(0x419cff))

  // Lines and fills (dark fields and tracks are wells, 30% black)
  static let separator = KitColor(.black(0.1), .white(0.1), more: .black(0.25), .white(0.28))
  static let border = KitColor(.black(0.16), .white(0.16), more: .black(0.45), .white(0.45))
  static let fill = KitColor(.black(0.08), .black(0.3), more: .black(0.14), .black(0.45))
  static let fillSoft = KitColor(.black(0.035), .white(0.045))
  static let field = KitColor(.black(0.045), .black(0.3), more: .black(0.09), .black(0.4))
  static let hover = KitColor(.black(0.04), .white(0.05))
  static let press = KitColor(.black(0.1), .white(0.1))
  static let rowHover = KitColor(.black(0.03), .white(0.05))
  static let rowUnfocused = KitColor(.black(0.09), .white(0.14))
  static let scrim = KitColor(.black(0.18), .black(0.4))
  static let highlight = KitColor(.white(0), .white(0.08))
}

extension ShapeStyle where Self == KitColor {
  /// Content panes, editors, tables.
  public static var kitWindow: KitColor { .window }
  /// The sidebar's ground.
  public static var kitSidebar: KitColor { .sidebar }
  /// Secondary panes: inspectors, sheets, settings, welcome recents.
  public static var kitPanel: KitColor { .panel }
  /// A card resting on a ground (70% white in light, opaque in dark).
  public static var kitCard: KitColor { .card }
  /// What is on, sitting on a field track: the selected segment, an on chip, a selected row in dark.
  public static var kitRaised: KitColor { .raised }
  /// Sheets, menus, popovers, toasts.
  public static var kitElevated: KitColor { .elevated }
  public static var kitLabel: KitColor { .label }
  public static var kitSecondary: KitColor { .secondary }
  public static var kitTertiary: KitColor { .tertiary }
  /// Quiet text that is still read (menu hints, NULL, line numbers).
  public static var kitQuiet: KitColor { .quiet }
  public static var kitLink: KitColor { .link }
  public static var kitSeparator: KitColor { .separator }
  public static var kitBorder: KitColor { .border }
  /// Neutral pills, segmented and chip tracks, wells.
  public static var kitFill: KitColor { .fill }
  public static var kitFillSoft: KitColor { .fillSoft }
  /// Text fields and field tracks.
  public static var kitField: KitColor { .field }
  public static var kitHover: KitColor { .hover }
  public static var kitPress: KitColor { .press }
  /// The dim under a modal palette or a sheet: black at 18% (40% in dark).
  public static var kitScrim: KitColor { .scrim }
}

// MARK: - Hues

/// The system hues, by meaning. `fill` draws dots, icons and tinted grounds; `text` is the same hue dark (or light)
/// enough for 11–13pt text on the window, a card or a field (4.5:1). `.accent` follows the app's accent.
public enum Hue: String, CaseIterable, Hashable, Sendable {
  case accent, blue, green, orange, red, yellow, teal, indigo, purple, pink, brown, gray

  /// The hue for fills, dots and icons.
  public var fill: HueStyle { HueStyle(hue: self, role: .fill) }
  /// The hue as text.
  public var text: HueStyle { HueStyle(hue: self, role: .text) }
  /// A soft tinted ground (tiles, chips, banners): the hue at 15% (16% for chips).
  public func soft(_ amount: Double = 0.15) -> HueStyle { HueStyle(hue: self, role: .soft(amount)) }

  var light: RGBA {
    switch self {
    case .accent, .blue: RGBA(0x007aff)
    case .green: RGBA(0x28cd41)
    case .orange: RGBA(0xff9500)
    case .red: RGBA(0xff3b30)
    case .yellow: RGBA(0xffcc00)
    case .teal: RGBA(0x59adc4)
    case .indigo: RGBA(0x5856d6)
    case .purple: RGBA(0xaf52de)
    case .pink: RGBA(0xff2d55)
    case .brown: RGBA(0xa2845e)
    case .gray: RGBA(0x8e8e93)
    }
  }

  var dark: RGBA {
    switch self {
    case .accent, .blue: RGBA(0x0a84ff)
    case .green: RGBA(0x32d74b)
    case .orange: RGBA(0xff9f0a)
    case .red: RGBA(0xff453a)
    case .yellow: RGBA(0xffd60a)
    case .teal: RGBA(0x6ac4dc)
    case .indigo: RGBA(0x5e5ce6)
    case .purple: RGBA(0xbf5af2)
    case .pink: RGBA(0xff375f)
    case .brown: RGBA(0xac8e68)
    case .gray: RGBA(0x98989d)
    }
  }

  var lightText: RGBA {
    switch self {
    case .accent, .blue: RGBA(0x0a5cc2)
    case .green: RGBA(0x146c2e)
    case .orange: RGBA(0xa34f00)
    case .red: RGBA(0xc00012)
    case .yellow: RGBA(0x8a6d00)
    case .teal: RGBA(0x1d6f84)
    case .indigo: RGBA(0x3c3ab5)
    case .purple: RGBA(0x8a35b5)
    case .pink: RGBA(0xc4123f)
    case .brown: RGBA(0x7a5a2e)
    case .gray: RGBA(0x5f5f64)
    }
  }

  var darkText: RGBA {
    switch self {
    case .accent, .blue: RGBA(0x5eaaff)
    case .green: RGBA(0x4cd964)
    case .orange: RGBA(0xffb340)
    case .red: RGBA(0xff6961)
    case .yellow: RGBA(0xffd60a)
    case .teal: RGBA(0x7fd3ea)
    case .indigo: RGBA(0x9a98ff)
    case .purple: RGBA(0xd08bf5)
    case .pink: RGBA(0xff8aa5)
    case .brown: RGBA(0xd2b48c)
    case .gray: RGBA(0xa1a1a6)
    }
  }
}

/// A hue resolved for where it's drawn; `.accent` reads the app's accent from the environment.
public struct HueStyle: ShapeStyle, Hashable, Sendable {
  enum Role: Hashable, Sendable { case fill, text, soft(Double) }
  let hue: Hue
  let role: Role

  public func resolve(in environment: EnvironmentValues) -> Color {
    rgba(in: environment).color
  }

  func rgba(in environment: EnvironmentValues) -> RGBA {
    let dark = environment.colorScheme == .dark
    let base: RGBA
    if hue == .accent {
      base = environment.kitAccent.resolve(in: environment).rgba
    } else {
      base = dark ? hue.dark : hue.light
    }
    switch role {
    case .fill:
      return base
    case .soft(let amount):
      return base.opacity(amount)
    case .text:
      if hue == .accent {
        // The accent dark enough for text: 62% with black in light, 55% with white in dark.
        return dark ? base.mixed(with: .white(1), 0.55) : base.mixed(with: .black(1), 0.62)
      }
      return dark ? hue.darkText : hue.lightText
    }
  }
}

extension ShapeStyle where Self == HueStyle {
  /// The app's accent as a fill (set once with `.componentKit(accent:)`).
  public static var kitAccent: HueStyle { Hue.accent.fill }
  /// The app's accent dark enough for text.
  public static var kitAccentText: HueStyle { Hue.accent.text }
}

/// The colour for a name that stays the same across launches (unlike `hashValue`): avatars, repository tiles.
public enum StableHue {
  static let palette: [Hue] = [.blue, .purple, .teal, .orange, .pink, .indigo, .green, .brown]

  public static func pick(_ key: String) -> Hue {
    let hash = key.unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
    return palette[Int(hash % UInt32(palette.count))]
  }
}

// MARK: - Colours from hex

extension Color {
  /// A colour from its sRGB hex value, `0xRRGGBB`: a syntax theme's colours, a colour stored as a number. Components
  /// take tokens (`KitColor`, `Hue`); this is for data that names its own colours.
  ///
  /// ```swift
  /// Text(token).foregroundStyle(Color(rgb: 0xc678dd))
  /// ```
  public init(rgb: UInt32) {
    self = RGBA(rgb).color
  }

  /// A colour from its sRGB hex value, `0xRRGGBB`, at an opacity (0…1).
  ///
  /// ```swift
  /// RoundedRectangle(cornerRadius: 4).fill(Color(rgb: 0x61afef, opacity: 0.2))
  /// ```
  public init(rgb: UInt32, opacity: Double) {
    self = RGBA(rgb, opacity).color
  }

  /// A colour from CSS-style hex text: `#RGB`, `#RRGGBB` or `#RRGGBBAA`, the `#` and surrounding spaces optional;
  /// nil for anything else.
  ///
  /// ```swift
  /// let background = Color(hex: frame.background) ?? .black
  /// ```
  public init?(hex: String) {
    guard let rgba = RGBA(hex: hex) else { return nil }
    self = rgba.color
  }

  /// The red the Hub family's apps (Get, Player) take as their accent: sRGB #FF3B30.
  ///
  /// ```swift
  /// WindowGroup { ContentView().componentKit(accent: .kitHubRed) }
  /// ```
  public static var kitHubRed: Color { RGBA(0xff3b30).color }
}

extension RGBA {
  /// `#RGB`, `#RRGGBB` or `#RRGGBBAA`; nil for anything else.
  init?(hex: String) {
    var digits = Substring(hex.trimmingCharacters(in: .whitespaces))
    if digits.hasPrefix("#") { digits = digits.dropFirst() }
    guard [3, 6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16)
    else { return nil }
    switch digits.count {
    case 3:
      let r = (value >> 8) & 0xf, g = (value >> 4) & 0xf, b = value & 0xf
      self.init((r * 0x11) << 16 | (g * 0x11) << 8 | b * 0x11)
    case 6:
      self.init(value)
    default:
      self.init(value >> 8, Double(value & 0xff) / 255)
    }
  }
}
