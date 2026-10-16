import SwiftUI

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
  /// A soft halo of the hue around the tile breathes in and out.
  case glow
  /// A filled ripple: a band of the hue grows out of the tile's edge and fades.
  case bloom
  /// The band around the tile beats twice, then rests.
  case heartbeat
  /// Inside the tile, a fill grows from the centre to the edges and fades.
  case sonar
}

extension EnvironmentValues {
  /// How the `LiveIcon`s below show indeterminate work (`.kitWorkIndicator(_:)`).
  @Entry public var kitWorkIndicator: KitWorkIndicator = .trace
}

extension View {
  /// Sets how the live icons below show work of unknown length: `.trace` (the default), `.comet`, `.pulse`,
  /// `.breathe`, `.march`, `.ripple`, `.glow`, `.bloom`, `.heartbeat` or `.sonar`.
  ///
  /// ```swift
  /// LiveIcon(systemImage: "sparkles", status: .working).kitWorkIndicator(.pulse)
  /// ```
  public func kitWorkIndicator(_ indicator: KitWorkIndicator) -> some View {
    environment(\.kitWorkIndicator, indicator)
  }
}

/// The ring 3.5pt outside the tile: a 2pt track at 22% of the hue with the progress in the hue, or the work indicator.
/// It is always there and animates between states: it grows in from idle, the running arc morphs into the progress
/// arc (and back), and a finished ring closes before it turns green or red.
struct StatusRing: View {
  let status: WorkStatus
  let hue: Hue
  let size: CGFloat
  let shape: KitShape
  @Environment(\.kitWindowIsActive) private var isActive
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.kitWorkIndicator) private var indicator
  @State private var clock = RingClock()

  var body: some View {
    let outset: CGFloat = 3.5
    let running = status.isWorking && status.progress == nil
    TimelineView(.animation(paused: !running || !isActive || reduceMotion)) { context in
      RingDrawing(
        presence: status == .idle ? 0 : 1,
        determinate: status.progress == nil ? 0 : 1,
        progress: status.progress ?? 0,
        elapsed: clock.elapsed(
          at: context.date.timeIntervalSinceReferenceDate, running: running,
          indeterminate: status.progress == nil && status != .idle),
        indicator: indicator, hue: hue, size: size, shape: shape, outset: outset
      )
    }
    .frame(width: size + outset * 2, height: size + outset * 2)
    .allowsHitTesting(false)
  }
}

/// The running indicator's clock. It holds still when the work stops (so a morph starts from where the arc stopped),
/// resumes from there after a pause, and starts again at zero when the work was determinate in between (so the arc
/// leaves from the top, where the progress arc starts). Not observed: it's written while drawing.
final class RingClock {
  private var start: TimeInterval?
  private var held: TimeInterval = 0
  private var restart = true

  /// `running`: the indicator turns. `indeterminate`: the amount is unknown (running or paused).
  func elapsed(at now: TimeInterval, running: Bool, indeterminate: Bool) -> TimeInterval {
    if running {
      if start == nil { start = now - (restart ? 0 : held) }
      restart = false
      held = now - start!
    } else {
      start = nil
      if !indeterminate { restart = true }
    }
    return held
  }
}

/// One drawing for every state, so the state changes interpolate: `presence` (idle 0), `determinate` (the share of
/// the progress arc over the running indicator) and `progress`.
struct RingDrawing: View, Animatable {
  var presence: Double
  var determinate: Double
  var progress: Double
  let elapsed: TimeInterval
  let indicator: KitWorkIndicator
  let hue: Hue
  let size: CGFloat
  let shape: KitShape
  let outset: CGFloat

  private let line: CGFloat = 2

  nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
    get { AnimatablePair(presence, AnimatablePair(determinate, progress)) }
    set {
      presence = newValue.first
      determinate = newValue.second.first
      progress = newValue.second.second
    }
  }

  var body: some View {
    let ring = ringPath()
    let running = 1 - determinate
    ZStack {
      ring.stroke(hue.soft(0.22), lineWidth: line)
        .opacity(indicator.drawsTrack ? 1 : determinate)
      switch indicator {
      case .trace:
        morphingArc(ring, period: 1.2, length: 0.28)
      case .comet:
        let head = phase(period: 1.1)
        // The tail: faint arcs that all end at the head, longer and longer, so they add up to a fade with no seams.
        // It fades out as the arc settles into progress.
        ForEach(1..<9, id: \.self) { i in
          arc(ring, from: head - Double(i) * 0.04, to: head, cap: .butt)
            .opacity(0.22 * running)
        }
        morphingArc(ring, period: 1.1, length: 0.045)
      case .pulse:
        let wave = (1 - cos(phase(period: 1.4) * 2 * .pi)) / 2
        ring.stroke(hue.fill, lineWidth: line).opacity((0.15 + wave * 0.85) * running)
        progressArc(ring)
      case .breathe:
        let wave = (1 - cos(phase(period: 1.6) * 2 * .pi)) / 2
        shape.shape(size: size)
          .fill(hue.soft(0.3))
          .frame(width: size, height: size)
          .opacity(wave * running)
        progressArc(ring)
      case .march:
        let dash = ringPerimeter() / 12
        ring.stroke(
          hue.fill,
          style: StrokeStyle(
            lineWidth: line, lineCap: .round, dash: [dash * 0.45, dash * 0.55],
            dashPhase: -phase(period: 1.5) * dash * 3)
        )
        .opacity(running)
        progressArc(ring)
      case .ripple:
        ForEach(0..<2, id: \.self) { i in
          let t = phase(period: 1.6, offset: Double(i) * 0.8)
          ring.stroke(hue.fill, lineWidth: line * (1 - t * 0.5))
            .scaleEffect(1 + t * 0.35)
            .opacity((1 - t) * 0.9 * running)
        }
        progressArc(ring)
      case .glow:
        let wave = (1 - cos(phase(period: 1.6) * 2 * .pi)) / 2
        band(outset: 3 + wave * 2.5)
          .fill(hue.fill, style: FillStyle(eoFill: true))
          .blur(radius: 3)
          .mask { band(outset: 24).fill(style: FillStyle(eoFill: true)) }
          .opacity((0.25 + wave * 0.55) * running)
        progressArc(ring)
      case .bloom:
        ForEach(0..<2, id: \.self) { i in
          let t = phase(period: 1.6, offset: Double(i) * 0.8)
          band(outset: 1 + t * 8)
            .fill(hue.fill, style: FillStyle(eoFill: true))
            .opacity((1 - t) * (1 - t) * 0.75 * running)
        }
        progressArc(ring)
      case .heartbeat:
        let t = phase(period: 1.3)
        // Lub-dub: two quick beats, the second softer, then a rest.
        let beat = max(Self.beat(t, at: 0.08, width: 0.06), Self.beat(t, at: 0.3, width: 0.06) * 0.7)
        band(outset: outset + line / 2 - 0.5 + beat * 1.5)
          .fill(hue.fill, style: FillStyle(eoFill: true))
          .opacity((0.12 + beat * 0.6) * running)
        progressArc(ring)
      case .sonar:
        ForEach(0..<2, id: \.self) { i in
          let t = phase(period: 1.6, offset: Double(i) * 0.8)
          Circle()
            .fill(hue.fill)
            .frame(width: size * 1.5 * t, height: size * 1.5 * t)
            .opacity((1 - t) * 0.35 * running)
        }
        .frame(width: size, height: size)
        .clipShape(shape.shape(size: size))
        ring.stroke(hue.soft(0.22), lineWidth: line).opacity(running)
        progressArc(ring)
      }
    }
    .opacity(presence)
    .scaleEffect(0.82 + 0.18 * presence)
  }

  /// The running arc (ending at the head, `length` long) blended into the progress arc (0…progress). The progress
  /// arc is taken a whole turn on when the running arc is in the ring's second half, so the blend takes the short way.
  private func morphingArc(_ ring: AnyShape, period: Double, length: Double) -> some View {
    let start = phase(period: period)
    let end = start + length
    let turn: Double = start > 0.5 ? 1 : 0
    let from = start + (turn - start) * determinate
    let to = end + (turn + progress - end) * determinate
    let shown = from + (to - from) * presence
    return arc(ring, from: from, to: shown).opacity(fade(from, shown))
  }

  /// The progress arc growing out of the top as the work becomes determinate.
  private func progressArc(_ ring: AnyShape) -> some View {
    arc(ring, from: 0, to: progress * determinate * presence).opacity(fade(0, progress * determinate * presence))
  }

  /// An arc between two positions on the ring (in turns, any range), split in two where it crosses the ring's start.
  @ViewBuilder
  private func arc(_ ring: AnyShape, from: Double, to: Double, cap: CGLineCap = .round) -> some View {
    let style = StrokeStyle(lineWidth: line, lineCap: cap)
    let start = from - floor(from)
    let end = start + max(0, to - from)
    // A round cap would leave a dot where the arc is about to vanish: draw nothing, and fade the last bit in.
    if end - start < 0.002 {
      EmptyView()
    } else if end - start >= 1 {
      ring.stroke(hue.fill, style: style)
    } else if end <= 1 {
      ring.trim(from: start, to: end).stroke(hue.fill, style: style)
    } else {
      ring.trim(from: start, to: 1).stroke(hue.fill, style: style)
      ring.trim(from: 0, to: end - 1).stroke(hue.fill, style: style)
    }
  }

  /// `arc` fading in over its first 6% of the ring.
  private func fade(_ from: Double, _ to: Double) -> Double { min(1, max(0, to - from) / 0.06) }

  /// The area around the tile out to `outset`, with the tile cut out (fill it even-odd).
  private func band(outset: CGFloat) -> TileBand {
    TileBand(tile: size, shape: shape, outset: outset)
  }

  /// A smooth bump at `at` (0…1 of the period), `width` wide.
  private static func beat(_ t: Double, at: Double, width: Double) -> Double {
    let x = (t - at) / width
    return exp(-x * x)
  }

  private func phase(period: Double, offset: Double = 0) -> Double {
    (elapsed + offset).truncatingRemainder(dividingBy: period) / period
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
  private func ringPath() -> AnyShape {
    switch shape {
    case .circle: AnyShape(Circle().rotation(.degrees(-90)))
    case .rounded: AnyShape(TopStartRoundedRect(cornerRadius: size * 0.29 + outset))
    }
  }
}

extension KitWorkIndicator {
  /// The ring's track shows while it runs (the fill styles do without it).
  var drawsTrack: Bool {
    switch self {
    case .breathe, .glow, .bloom, .heartbeat, .sonar: false
    default: true
    }
  }
}

/// The area around a tile out to `outset`, both following the tile's shape. Filled even-odd it leaves the tile clear,
/// so a halo never covers the glyph.
struct TileBand: Shape {
  var tile: CGFloat
  var shape: KitShape
  var outset: CGFloat

  func path(in rect: CGRect) -> Path {
    let inner = CGRect(x: rect.midX - tile / 2, y: rect.midY - tile / 2, width: tile, height: tile)
    let outer = inner.insetBy(dx: -outset, dy: -outset)
    var p = Path()
    switch shape {
    case .circle:
      p.addEllipse(in: outer)
      p.addEllipse(in: inner)
    case .rounded:
      let r = tile * 0.29
      p.addRoundedRect(in: outer, cornerSize: CGSize(width: r + outset, height: r + outset), style: .continuous)
      p.addRoundedRect(in: inner, cornerSize: CGSize(width: r, height: r), style: .continuous)
    }
    return p
  }
}
