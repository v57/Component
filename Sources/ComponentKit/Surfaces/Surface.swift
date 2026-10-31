import SwiftUI

/// The kit's grounds for a shape. In light, cards are 70% white with a hairline and a soft shadow; in dark the kit
/// uses opaque steps of light with no resting shadow (a 0.5pt top highlight), and fields and tracks are wells.
public enum Surface: Hashable, Sendable {
  /// A group: sidebar sections, inspector sections, list groups, toolbar groups.
  case card
  /// What is on, on a field track: the selected segment, an on chip, a selected row.
  case raised
  /// Things that float: sheets, popovers, menus, toasts.
  case floating
  /// Text fields, tracks, wells.
  case field
  /// A flat neutral fill (pills, counts).
  case fill
}

extension View {
  /// Draws `surface` behind the view in a rounded rectangle (and casts its shadow); `KitMetrics.radiusCapsule` makes
  /// it a capsule (a floating bar).
  ///
  /// ```swift
  /// VStack { … }.padding(6).kitSurface(.card)
  /// HStack { tools }.padding(.horizontal, 12).frame(height: 52).kitSurface(.floating, cornerRadius: KitMetrics.radiusCapsule)
  /// ```
  public func kitSurface(_ surface: Surface, cornerRadius: CGFloat? = nil) -> some View {
    background { SurfaceShape(surface: surface, cornerRadius: cornerRadius ?? surface.defaultRadius) }
  }

  /// A card: the content padded 6pt on the card ground with 12pt corners. Rounded views never touch, so give
  /// neighbouring cards an 8pt gap (`VStack(spacing: KitMetrics.gutter)`).
  public func kitCard(padding: CGFloat = KitMetrics.cardPadding) -> some View {
    self.padding(padding).kitSurface(.card)
  }
}

extension Surface {
  var defaultRadius: CGFloat {
    switch self {
    case .card: KitMetrics.radiusCard
    case .raised, .field: KitMetrics.radius
    case .floating: KitMetrics.radiusOverlay
    case .fill: KitMetrics.radiusSmall
    }
  }
}

struct SurfaceShape: View {
  let surface: Surface
  let cornerRadius: CGFloat
  @Environment(\.colorScheme) private var scheme
  @Environment(\.kitMoreContrast) private var moreContrast
  @Environment(\.contBarGround) private var barGround

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    let dark = scheme == .dark
    let more = moreContrast
    switch surface {
    case .card:
      // In a bar, opaque over the bar's ground (the card token is translucent in light mode).
      shape.fill(KitColor.card.overBarGround(barGround))
        .overlay {
          if dark {
            TopHighlight(shape: shape, opacity: 0.08)
          } else {
            shape.strokeBorder(Color.black.opacity(more ? 0.32 : 0.1), lineWidth: more ? 1 : 0.5)
          }
        }
        .shadow(color: .black.opacity(dark ? 0 : 0.06), radius: 1.5, y: 1)
    case .raised:
      shape.fill(.kitRaised)
        .overlay {
          if dark {
            TopHighlight(shape: shape, opacity: 0.08)
          } else if more {
            shape.strokeBorder(Color.black.opacity(0.32), lineWidth: 1)
          }
        }
        .shadow(color: .black.opacity(dark ? 0 : 0.14), radius: 1, y: 1)
    case .floating:
      shape.fill(.kitElevated)
        .overlay {
          shape.strokeBorder(dark ? Color.white.opacity(0.1) : Color.black.opacity(0.14), lineWidth: 0.5)
        }
        .overlay { if dark { TopHighlight(shape: shape, opacity: 0.12) } }
        .kitFloatShadow(scheme)
    case .field:
      shape.fill(KitColor.field.overBarGround(barGround))
        .overlay { if more { shape.strokeBorder(.kitBorder, lineWidth: 1) } }
    case .fill:
      shape.fill(.kitFill)
    }
  }
}

extension View {
  /// The floating surface's shadow (menus, popovers, overlay cards).
  func kitFloatShadow(_ scheme: ColorScheme) -> some View {
    let dark = scheme == .dark
    return shadow(color: .black.opacity(dark ? 0.5 : 0.16), radius: dark ? 20 : 16, y: dark ? 16 : 12)
  }
}

/// Dark mode's resting edge: a 0.5pt highlight along the top of a shape instead of a shadow.
struct TopHighlight<S: InsettableShape>: View {
  let shape: S
  let opacity: Double

  var body: some View {
    shape.strokeBorder(Self.gradient(opacity), lineWidth: 0.5)
  }

  static func gradient(_ opacity: Double) -> LinearGradient {
    LinearGradient(
      colors: [.white.opacity(opacity), .white.opacity(0)], startPoint: .top, endPoint: .init(x: 0.5, y: 0.12))
  }
}

/// The card ground in any shape (a footer bar concentric with the iPhone's sheet card): `.card`'s fill, hairline
/// (top highlight in dark) and shadow, the edges drawn inside the shape.
struct SurfaceCardShape: View {
  let shape: AnyShape
  @Environment(\.colorScheme) private var scheme
  @Environment(\.kitMoreContrast) private var moreContrast
  @Environment(\.contBarGround) private var barGround

  var body: some View {
    let dark = scheme == .dark
    shape.fill(KitColor.card.overBarGround(barGround))
      .overlay {
        if dark {
          shape.stroke(TopHighlight<Rectangle>.gradient(0.08), lineWidth: 1).clipShape(shape)
        } else {
          shape.stroke(Color.black.opacity(moreContrast ? 0.32 : 0.1), lineWidth: moreContrast ? 2 : 1).clipShape(shape)
        }
      }
      .shadow(color: .black.opacity(dark ? 0 : 0.06), radius: 1.5, y: 1)
  }
}
