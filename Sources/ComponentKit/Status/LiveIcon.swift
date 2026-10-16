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
      .environment(\.kitGlyphSize, size * 0.62)
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

extension EnvironmentValues {
  /// The size a drawn glyph takes where it sits: set by `Tile`, `LiveIcon` and `RowTile` for the glyph inside them
  /// (an SF Symbol follows the font instead). A custom glyph view reads it to fit any tile; `BranchGlyph` does.
  ///
  /// ```swift
  /// struct PlugGlyph: View {
  ///   @Environment(\.kitGlyphSize) private var size
  ///   var body: some View { PlugShape().stroke(.foreground).frame(width: size ?? 16, height: size ?? 16) }
  /// }
  /// RowTile { PlugGlyph() }
  /// ```
  @Entry public var kitGlyphSize: CGFloat? = nil
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

/// How a `LiveIcon` shows work whose amount is unknown. Every style follows the tile's shape (circle or rounded square).
public enum KitWorkIndicator: String, Hashable, Sendable, CaseIterable {
  /// An arc that runs around the ring, along the shape (the default).
  case trace
  /// The running arc with a tail that fades behind it.
  case comet
  /// The whole ring breathes between its track and the hue.
  case pulse
  /// No ring: the tile's ground breathes in its hue.
  case breathe
  /// Short dashes march around the ring.
  case march
  /// A ring that leaves the tile and fades, again and again.
  case ripple
}

extension EnvironmentValues {
  /// How the `LiveIcon`s below show indeterminate work (`.kitWorkIndicator(_:)`).
  @Entry public var kitWorkIndicator: KitWorkIndicator = .trace
}

extension View {
  /// Sets how the live icons below show work of unknown length: `.trace` (the default), `.comet`, `.pulse`,
  /// `.breathe`, `.march` or `.ripple`.
  ///
  /// ```swift
  /// LiveIcon(systemImage: "sparkles", status: .working).kitWorkIndicator(.pulse)
  /// ```
  public func kitWorkIndicator(_ indicator: KitWorkIndicator) -> some View {
    environment(\.kitWorkIndicator, indicator)
  }
}

/// The ring 3.5pt outside the tile: a 2pt track at 22% of the hue with the progress in the hue, or the work indicator.
struct StatusRing: View {
  let status: WorkStatus
  let hue: Hue
  let size: CGFloat
  let shape: KitShape
  @Environment(\.kitWindowIsActive) private var isActive
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.kitWorkIndicator) private var indicator

  private let outset: CGFloat = 3.5
  private let line: CGFloat = 2

  var body: some View {
    let ringShape = ringPath(outset: outset)
    ZStack {
      if let progress = status.progress {
        ringShape.stroke(hue.soft(0.22), lineWidth: line)
        ringShape.trim(from: 0, to: progress).stroke(hue.fill, style: StrokeStyle(lineWidth: line, lineCap: .round))
      } else if status.isWorking {
        TimelineView(.animation(paused: !isActive || reduceMotion)) { context in
          indeterminate(ringShape, time: context.date.timeIntervalSinceReferenceDate)
        }
      } else {
        ringShape.stroke(hue.soft(0.22), lineWidth: line)
      }
    }
    .frame(width: size + outset * 2, height: size + outset * 2)
    .allowsHitTesting(false)
  }

  @ViewBuilder
  private func indeterminate(_ ring: AnyShape, time: TimeInterval) -> some View {
    switch indicator {
    case .trace:
      ring.stroke(hue.soft(0.22), lineWidth: line)
      arc(ring, head: phase(time, period: 1.2), length: 0.28)
    case .comet:
      ring.stroke(hue.soft(0.22), lineWidth: line)
      let head = phase(time, period: 1.1)
      // The tail: short pieces behind the head, each fainter than the last.
      ForEach(0..<8, id: \.self) { i in
        let step = 0.045
        arc(ring, head: head - Double(i) * step, length: step + 0.004, cap: i == 0 ? .round : .butt)
          .opacity(1 - Double(i) / 8)
      }
    case .pulse:
      let wave = (1 - cos(phase(time, period: 1.4) * 2 * .pi)) / 2
      ring.stroke(hue.soft(0.22), lineWidth: line)
      ring.stroke(hue.fill, lineWidth: line).opacity(0.15 + wave * 0.85)
    case .breathe:
      let wave = (1 - cos(phase(time, period: 1.6) * 2 * .pi)) / 2
      shape.shape(size: size)
        .fill(hue.soft(0.3))
        .frame(width: size, height: size)
        .opacity(wave)
    case .march:
      let perimeter = ringPerimeter()
      let dash = perimeter / 12
      ring.stroke(hue.soft(0.22), lineWidth: line)
      ring.stroke(
        hue.fill,
        style: StrokeStyle(
          lineWidth: line, lineCap: .round, dash: [dash * 0.45, dash * 0.55],
          dashPhase: -phase(time, period: 1.5) * dash * 3)
      )
    case .ripple:
      ring.stroke(hue.soft(0.22), lineWidth: line)
      ForEach(0..<2, id: \.self) { i in
        let t = phase(time + Double(i) * 0.8, period: 1.6)
        ring.stroke(hue.fill, lineWidth: line * (1 - t * 0.5))
          .scaleEffect(1 + t * 0.35)
          .opacity((1 - t) * 0.9)
      }
    }
  }

  /// An arc of `length` (0…1 of the ring) ending at `head`, split in two where it crosses the ring's start.
  @ViewBuilder
  private func arc(_ ring: AnyShape, head: Double, length: Double, cap: CGLineCap = .round) -> some View {
    let style = StrokeStyle(lineWidth: line, lineCap: cap)
    let end = head - floor(head)
    let start = end - length
    if start >= 0 {
      ring.trim(from: start, to: end).stroke(hue.fill, style: style)
    } else {
      ring.trim(from: 0, to: end).stroke(hue.fill, style: style)
      ring.trim(from: 1 + start, to: 1).stroke(hue.fill, style: style)
    }
  }

  private func phase(_ time: TimeInterval, period: Double) -> Double {
    time.truncatingRemainder(dividingBy: period) / period
  }

  private func ringPerimeter() -> CGFloat {
    let side = size + outset * 2
    switch shape {
    case .circle: return .pi * side
    case .rounded:
      let r = min(size * 0.29 + outset, side / 2)
      return 4 * (side - 2 * r) + 2 * .pi * r
    }
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
