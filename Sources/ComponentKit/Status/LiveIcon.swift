import SwiftUI

/// The kit's icon tile: a glyph on a soft rounded square in its hue (15%), or solid for apps.
/// A `LiveIcon` is the same tile wearing a ring that carries work: progress, an indeterminate arc, done or failed.
public struct Tile<Content: View>: View {
  public enum Style: Hashable, Sendable {
    /// The hue at 15% under the hue: things, sections, rows.
    case soft
    /// Filled with the hue, white glyph: apps.
    case solid
    /// No ground, just the glyph in the hue (compact sidebars).
    case plain
  }

  var hue: Hue
  var size: CGFloat
  var style: Style
  var shape: KitShape
  @ViewBuilder var content: Content

  public init(
    hue: Hue = .accent, size: CGFloat = 24, style: Style = .soft, shape: KitShape = .rounded,
    @ViewBuilder content: () -> Content
  ) {
    self.hue = hue
    self.size = size
    self.style = style
    self.shape = shape
    self.content = content()
  }

  public var body: some View {
    content
      .font(.system(size: size * 0.58, weight: .semibold))
      .imageScale(.small)
      .foregroundStyle(style == .solid ? AnyShapeStyle(Color.white) : AnyShapeStyle(hue.fill))
      .frame(width: size, height: size)
      .background {
        switch style {
        case .soft: shape.shape(size: size).fill(hue.soft())
        case .solid: shape.shape(size: size).fill(hue.fill)
        case .plain: EmptyView()
        }
      }
      .accessibilityHidden(true)
  }
}

extension Tile where Content == Image {
  /// A tile with an SF Symbol.
  public init(systemImage: String, hue: Hue = .accent, size: CGFloat = 24, style: Style = .soft) {
    self.init(hue: hue, size: size, style: style) { Image(systemName: systemImage) }
  }
}

extension Tile where Content == Text {
  /// A tile with one or two letters ("Pg", "A").
  public init(letters: String, hue: Hue = .accent, size: CGFloat = 24, style: Style = .soft, shape: KitShape = .rounded) {
    self.init(hue: hue, size: size, style: style, shape: shape) {
      Text(letters.prefix(2)).font(.system(size: size * (letters.count > 1 ? 0.42 : 0.5), weight: .bold))
    }
  }
}

/// Shape says kind: people are circles, agents and things rounded squares.
public enum KitShape: Hashable, Sendable {
  case rounded, circle

  /// The tile's corner: 7pt at 24, scaling with the size.
  func shape(size: CGFloat) -> AnyShape {
    switch self {
    case .circle: AnyShape(Circle())
    case .rounded: AnyShape(RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
    }
  }
}

/// A tile that carries work: the ring shows progress (or turns while indeterminate), settles green with a check when
/// done and red when it failed. Put a `WorkStatus` on it and the kit does the rest.
///
/// ```swift
/// LiveIcon(systemImage: "arrow.up", status: .working(progress: 0.4))
/// ```
public struct LiveIcon<Content: View>: View {
  var hue: Hue
  var status: WorkStatus
  var size: CGFloat
  var shape: KitShape
  @ViewBuilder var content: Content

  public init(
    hue: Hue = .accent, status: WorkStatus, size: CGFloat = 24, shape: KitShape = .rounded,
    @ViewBuilder content: () -> Content
  ) {
    self.hue = hue
    self.status = status
    self.size = size
    self.shape = shape
    self.content = content()
  }

  public var body: some View {
    let tint = status.hue ?? hue
    Tile(hue: tint, size: size, shape: shape) {
      ZStack {
        switch status {
        case .done:
          Image(systemName: "checkmark").fontWeight(.bold).transition(.scale.combined(with: .opacity))
        case .failed:
          Image(systemName: "exclamationmark").fontWeight(.bold).transition(.scale.combined(with: .opacity))
        default:
          content.transition(.opacity)
        }
      }
    }
    .overlay {
      if status != .idle {
        StatusRing(status: status, hue: tint, size: size, shape: shape)
      }
    }
    .animation(.kit, value: status)
    .accessibilityElement()
    .accessibilityLabel(Self.label(status))
  }

  static func label(_ status: WorkStatus) -> String {
    switch status {
    case .idle: ""
    case .working(let p): p.map { "\(Int($0 * 100)) percent" } ?? "Working"
    case .paused: "Paused"
    case .done: "Done"
    case .failed(let message): message ?? "Failed"
    }
  }
}

extension LiveIcon where Content == Image {
  public init(systemImage: String, hue: Hue = .accent, status: WorkStatus, size: CGFloat = 24, shape: KitShape = .rounded) {
    self.init(hue: hue, status: status, size: size, shape: shape) { Image(systemName: systemImage) }
  }
}

/// The ring 3.5pt outside the tile: a 2pt track at 22% of the hue with the progress in the hue, or a turning arc.
struct StatusRing: View {
  let status: WorkStatus
  let hue: Hue
  let size: CGFloat
  let shape: KitShape
  @Environment(\.kitWindowIsActive) private var isActive
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let outset: CGFloat = 3.5
    let ringShape = ringPath(outset: outset)
    ZStack {
      ringShape.stroke(hue.soft(0.22), lineWidth: 2)
      if let progress = status.progress {
        ringShape.trim(from: 0, to: progress).stroke(hue.fill, style: StrokeStyle(lineWidth: 2, lineCap: .round))
      } else if status.isWorking {
        TimelineView(.animation(paused: !isActive || reduceMotion)) { context in
          let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
          ringShape.trim(from: 0, to: 0.3)
            .stroke(hue.fill, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(turn * 360))
        }
      }
    }
    .frame(width: size + outset * 2, height: size + outset * 2)
    .allowsHitTesting(false)
  }

  /// The ring follows the tile's shape, starting at the top centre and going clockwise.
  private func ringPath(outset: CGFloat) -> AnyShape {
    switch shape {
    case .circle: AnyShape(Circle().rotation(.degrees(-90)))
    case .rounded: AnyShape(TopStartRoundedRect(cornerRadius: size * 0.29 + outset))
    }
  }
}

/// A rounded rectangle path that starts at the top centre, so `trim` fills it clockwise like a progress ring.
struct TopStartRoundedRect: Shape {
  var cornerRadius: CGFloat

  func path(in rect: CGRect) -> Path {
    let r = min(cornerRadius, rect.width / 2, rect.height / 2)
    var p = Path()
    p.move(to: CGPoint(x: rect.midX, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
    p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r)
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
    p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY), radius: r)
    p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
    p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - r), radius: r)
    p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
    p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + r, y: rect.minY), radius: r)
    p.closeSubpath()
    return p
  }
}
