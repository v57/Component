import SwiftUI

/// The kit's type scale (13pt body on the Mac, 17pt on iPad and iPhone), each style with its weight, tracking and
/// default colour. Apply it with `.kitFont(_:)`; on touch idioms it follows Dynamic Type.
public enum KitFont: Hashable, Sendable {
  /// 26/32 bold: a window's or board's title.
  case largeTitle
  /// 22/26 bold.
  case title1
  /// 17/22 semibold: an inspector's or sheet's title.
  case title2
  /// 15/20 semibold.
  case title3
  /// 13/16 semibold: row titles that lead, section names.
  case headline
  /// 13/16: the body of every label.
  case body
  /// 12/15.
  case callout
  /// 11/14 secondary: meta lines, captions, counts.
  case caption
  /// 11/14 semibold: section headers on plain grounds.
  case sectionHeader
  /// 12/16 monospaced: values, ids, hashes, code.
  case mono
  /// 11/14 monospaced: small values and line numbers.
  case monoSmall

  /// Mac size; iPad adds 2 (13 → 15), iPhone 4 (13 → 17).
  var size: CGFloat {
    switch self {
    case .largeTitle: 26
    case .title1: 22
    case .title2: 17
    case .title3: 15
    case .headline, .body: 13
    case .callout, .mono: 12
    case .caption, .sectionHeader, .monoSmall: 11
    }
  }

  var weight: Font.Weight {
    switch self {
    case .largeTitle, .title1: .bold
    case .title2, .title3, .headline, .sectionHeader: .semibold
    default: .regular
    }
  }

  var isMono: Bool { self == .mono || self == .monoSmall }

  /// -0.01em on text (Git's designTracking), -0.02em on the big titles, none on monospaced text.
  var trackingEm: CGFloat {
    switch self {
    case .largeTitle, .title1: -0.02
    case .mono, .monoSmall: 0
    default: -0.01
    }
  }

  var tracking: CGFloat { trackingEm * size }

  /// The style's default colour, when the caller hasn't set one.
  var defaultStyle: KitColor? {
    switch self {
    case .caption: .secondary
    case .sectionHeader: .sectionHeader
    default: nil
    }
  }

  /// The font at the Mac size.
  public var font: Font { font(scale: 1) }

  func font(scale: CGFloat, idiom: KitIdiom = .mac) -> Font {
    let grow: CGFloat = self.size >= 20 ? 0 : idiom == .phone ? 4 : idiom == .pad ? 2 : 0
    let size = (self.size + grow) * scale
    return .system(size: size, weight: weight, design: isMono ? .monospaced : .default)
  }
}

extension View {
  /// Sets the kit's type style: size, weight, tracking and (for captions and section headers) the quiet colour.
  public func kitFont(_ style: KitFont) -> some View {
    modifier(KitFontModifier(style: style))
  }
}

struct KitFontModifier: ViewModifier {
  let style: KitFont
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.dynamicTypeSize) private var typeSize

  func body(content: Content) -> some View {
    let font = style.font(scale: scale, idiom: idiom)
    if let color = style.defaultStyle {
      content.font(font).tracking(style.tracking).foregroundStyle(color)
    } else {
      content.font(font).tracking(style.tracking)
    }
  }

  /// Dynamic Type on touch idioms; the Mac keeps its sizes.
  private var scale: CGFloat {
    guard idiom.isTouch else { return 1 }
    switch typeSize {
    case .xSmall: return 0.82
    case .small: return 0.88
    case .medium: return 0.94
    case .large: return 1
    case .xLarge: return 1.12
    case .xxLarge: return 1.24
    case .xxxLarge: return 1.35
    case .accessibility1: return 1.65
    case .accessibility2: return 1.95
    case .accessibility3: return 2.35
    case .accessibility4: return 2.75
    case .accessibility5: return 3.1
    @unknown default: return 1
    }
  }
}
