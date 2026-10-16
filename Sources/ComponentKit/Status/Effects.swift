import SwiftUI

/// A short effect the kit plays on a view when something happened. Apps report the event; the kit decides the look.
public enum KitEffect: Hashable, Sendable {
  /// It worked: a green wash and a small pop.
  case success
  /// It didn't: a red wash and a shake.
  case failure
  /// Something arrived or changed: a quick scale.
  case pop
  /// Something landed here: an accent wash that fades.
  case wash
  /// Look here: a ring that grows and fades.
  case pulse
  /// Worth celebrating (published, all tests passed, inbox zero): confetti bursts from the view and falls away.
  case burst
  /// Kept or counted (liked, starred, +1): the symbol rises from the view's top edge and fades, two smaller ones
  /// after it. `.float("heart.fill", .pink)`.
  case float(_ systemImage: String = "plus", _ hue: Hue = .accent)
  /// Sent off (sent, pushed, uploaded, shared): the symbol leaves the view's trailing edge and flies away up and to the
  /// right while the view recoils. `.send("paperplane.fill")`.
  case send(_ systemImage: String = "paperplane.fill", _ hue: Hue = .accent)
  /// New or generated (a summary, a suggestion, a fresh result): small stars twinkle around the view.
  case sparkle
  /// Refreshed or up to date: a band of accent light sweeps across.
  case shimmer
  /// Not now (locked, nothing to do, finish something else first): a short tilt back and forth, softer than
  /// `.failure`.
  case wiggle
}

extension View {
  /// Plays `effect` once each time `value` changes. It draws in an overlay (layout never moves), quick repeats
  /// restart it, nothing plays in a window that isn't focused, and Reduce Motion keeps only the colour.
  ///
  /// ```swift
  /// Button("Push") { … }.effect(.success, on: pushedCount)
  /// Button("Like", systemImage: "heart") { … }.effect(.float("heart.fill", .pink), on: likes)
  /// ```
  public func effect<V: Equatable>(_ effect: KitEffect, on value: V, cornerRadius: CGFloat = KitMetrics.radius)
    -> some View
  {
    modifier(EffectModifier(effect: effect, trigger: value, cornerRadius: cornerRadius))
  }

  /// Ties a view to a piece of work: when `status` finishes it plays `.success` or `.failure`.
  public func status(_ status: WorkStatus, cornerRadius: CGFloat = KitMetrics.radius) -> some View {
    modifier(StatusEffectModifier(status: status, cornerRadius: cornerRadius))
  }
}

/// Plays an effect on a clock: each play stamps a start, and every frame draws the effect at its progress `t`
/// (0…1), so a repeat simply restarts and the view keeps its identity between plays.
struct EffectModifier<V: Equatable>: ViewModifier {
  let effect: KitEffect
  let trigger: V
  let cornerRadius: CGFloat
  @State private var start: Date?
  @State private var plays = 0
  @Environment(\.kitWindowIsActive) private var isActive
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    TimelineView(.animation(paused: start == nil)) { timeline in
      let t = progress(at: timeline.date)
      content
        .scaleEffect(scale(t))
        .rotationEffect(.degrees(tilt(t)))
        .offset(x: shake(t))
        .overlay {
          if let t {
            EffectDrawing(
              effect: effect, t: t, seed: plays, cornerRadius: cornerRadius, reduceMotion: reduceMotion)
          }
        }
    }
    .onChange(of: trigger) { play() }
    .task(id: start) {
      guard start != nil else { return }
      try? await Task.sleep(for: .seconds(duration))
      if !Task.isCancelled { start = nil }
    }
  }

  private func play() {
    guard isActive else { return }
    plays += 1
    start = .now
  }

  private var duration: Double {
    if reduceMotion { return 0.3 }
    switch effect {
    case .success, .failure, .pop, .wash, .pulse: return 0.55
    case .wiggle: return 0.5
    case .send: return 0.75
    case .shimmer: return 0.8
    case .burst, .float: return 0.9
    case .sparkle: return 1.1
    }
  }

  private func progress(at date: Date) -> Double? {
    guard let start else { return nil }
    return min(1, max(0, date.timeIntervalSince(start) / duration))
  }

  private func scale(_ t: Double?) -> CGFloat {
    guard let t, !reduceMotion else { return 1 }
    switch effect {
    case .success, .pop: return 1 + 0.06 * sin(easeOut(t) * .pi)
    case .burst: return 1 + 0.05 * sin(min(1, t * 2.2) * .pi)
    case .float: return 1 + 0.04 * sin(min(1, t * 3) * .pi)
    case .send: return 1 - 0.04 * sin(min(1, t * 3) * .pi)
    default: return 1
    }
  }

  private func tilt(_ t: Double?) -> Double {
    guard let t, !reduceMotion, effect == .wiggle else { return 0 }
    return 2.5 * sin(t * .pi * 4) * (1 - t)
  }

  private func shake(_ t: Double?) -> CGFloat {
    guard let t, !reduceMotion, effect == .failure else { return 0 }
    let e = easeOut(t)
    return 4 * sin(e * .pi * 6) * (1 - e)
  }
}

/// What an effect draws over its view at progress `t`.
private struct EffectDrawing: View {
  let effect: KitEffect
  let t: Double
  let seed: Int
  let cornerRadius: CGFloat
  let reduceMotion: Bool

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    ZStack {
      if let wash = washHue {
        shape.fill(wash.fill).opacity((1 - easeOut(t)) * 0.22)
      }
      if !reduceMotion {
        switch effect {
        case .pulse:
          shape.stroke(Hue.accent.fill, lineWidth: 2)
            .scaleEffect(1 + easeOut(t) * 0.25)
            .opacity(1 - easeOut(t))
        case .burst:
          Confetti(t: t, seed: seed)
        case .float(let symbol, let hue):
          FloatingSymbols(systemImage: symbol, hue: hue, t: t)
        case .send(let symbol, let hue):
          SentSymbol(systemImage: symbol, hue: hue, t: t)
        case .sparkle:
          Sparkles(t: t, seed: seed)
        case .shimmer:
          Shimmer(t: t).clipShape(shape)
        default:
          EmptyView()
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  /// The colour the effect leaves; under Reduce Motion every effect keeps its colour as a wash.
  private var washHue: Hue? {
    switch effect {
    case .success: return .green
    case .failure: return .red
    case .wash: return .accent
    case .pop, .pulse: return nil
    case .float(_, let hue), .send(_, let hue): return reduceMotion ? hue : nil
    case .burst, .sparkle, .shimmer: return reduceMotion ? .accent : nil
    case .wiggle: return reduceMotion ? .gray : nil
    }
  }
}

// MARK: - Flourishes

/// Confetti: bits leave the view's edge in every direction, spin, drop a little and fade.
private struct Confetti: View {
  let t: Double
  let seed: Int

  private static let hues: [Hue] = [.accent, .yellow, .pink, .green, .purple, .orange]
  private let spread: CGFloat = 56

  var body: some View {
    Canvas { context, size in
      let rect = CGRect(origin: .zero, size: size).insetBy(dx: spread, dy: spread)
      let center = CGPoint(x: rect.midX, y: rect.midY)
      var random = SeededRandom(seed: seed)
      let count = 22
      let travel = easeOut(t)
      for i in 0..<count {
        let angle = Double(i) / Double(count) * 2 * .pi + random.next(in: -0.16...0.16)
        let distance = random.next(in: 22...52)
        let size = random.next(in: 3...6)
        let spin = random.next(in: -3...3) * .pi
        let round = i % 3 == 0
        let start = CGPoint(x: center.x + cos(angle) * rect.width / 2, y: center.y + sin(angle) * rect.height / 2)
        let point = CGPoint(
          x: start.x + cos(angle) * distance * travel,
          y: start.y + sin(angle) * distance * travel + 20 * t * t)
        let grow = min(1, t / 0.08)
        let opacity = t < 0.55 ? 1 : 1 - (t - 0.55) / 0.45
        var piece = context
        piece.opacity = opacity
        piece.translateBy(x: point.x, y: point.y)
        piece.rotate(by: .radians(spin * t))
        piece.scaleBy(x: grow, y: grow)
        let bounds =
          round
          ? CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
          : CGRect(x: -size / 2, y: -size * 0.3, width: size, height: size * 0.6)
        let path = round ? Path(ellipseIn: bounds) : Path(roundedRect: bounds, cornerRadius: 1)
        piece.fill(path, with: .style(Self.hues[i % Self.hues.count].fill))
      }
    }
    .padding(-spread)
  }
}

/// The symbol rises from the view's top edge with a small sway, two smaller ones after it.
private struct FloatingSymbols: View {
  let systemImage: String
  let hue: Hue
  let t: Double

  private let copies: [(delay: Double, x: CGFloat, rise: CGFloat, size: CGFloat)] = [
    (0, 0, 36, 1), (0.14, -18, 26, 0.7), (0.24, 17, 22, 0.6),
  ]

  var body: some View {
    ZStack {
      ForEach(copies.indices, id: \.self) { i in
        let copy = copies[i]
        let local = min(1, max(0, (t - copy.delay) / (1 - copy.delay)))
        let rise = easeOut(local)
        Image(systemName: systemImage)
          .font(.system(size: 15 * copy.size, weight: .semibold))
          .foregroundStyle(hue.fill)
          .scaleEffect(local == 0 ? 0.01 : 0.5 + 0.5 * min(1, local / 0.2) + 0.12 * sin(min(1, local / 0.4) * .pi))
          .offset(x: copy.x * rise + 3 * sin(local * .pi * 2), y: -copy.rise * rise)
          .opacity(local == 0 ? 0 : local < 0.5 ? 1 : 1 - (local - 0.5) / 0.5)
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }
}

/// The symbol pops up at the view's trailing edge and flies away up and to the right, faster and faster, with a
/// short trail.
private struct SentSymbol: View {
  let systemImage: String
  let hue: Hue
  let t: Double

  var body: some View {
    ZStack {
      ForEach(0..<4, id: \.self) { ghost in
        let u = max(0, t - Double(ghost) * 0.05)
        let point = position(pow(u, 1.7))
        Image(systemName: systemImage)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(hue.fill)
          .scaleEffect((0.4 + 0.6 * min(1, u / 0.15)) * (1 - 0.3 * u))
          .rotationEffect(.degrees(-12 * u))
          .offset(x: point.x, y: point.y)
          .opacity((ghost == 0 ? 1 : 0.3 / Double(ghost)) * (u < 0.55 ? 1 : 1 - (u - 0.55) / 0.45))
          .opacity(ghost > 0 && u < 0.05 ? 0 : 1)
      }
    }
    .alignmentGuide(.trailing) { $0[.leading] - 2 }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
  }

  /// A quadratic curve: out to the right first, then up.
  private func position(_ u: Double) -> CGPoint {
    let p1 = CGPoint(x: 36, y: 4)
    let p2 = CGPoint(x: 76, y: -52)
    return CGPoint(
      x: 2 * (1 - u) * u * p1.x + u * u * p2.x,
      y: 2 * (1 - u) * u * p1.y + u * u * p2.y)
  }
}

/// Four-point stars just outside the view's edge, one after another: each grows, turns and shrinks.
private struct Sparkles: View {
  let t: Double
  let seed: Int

  private let spread: CGFloat = 24
  /// Where the stars sit, as fractions of the view (outside 0…1 is beyond its edge).
  private static let spots: [(x: Double, y: Double, size: Double)] = [
    (0.06, -0.32, 13), (0.86, -0.42, 16), (1.09, 0.55, 11), (0.62, 1.36, 13), (-0.07, 0.95, 10), (0.4, -0.6, 9),
  ]

  var body: some View {
    Canvas { context, size in
      let rect = CGRect(origin: .zero, size: size).insetBy(dx: spread, dy: spread)
      var random = SeededRandom(seed: seed)
      for (i, spot) in Self.spots.enumerated() {
        let delay = Double(i) * 0.09
        let local = (t - delay) / 0.5
        guard local > 0, local < 1 else { continue }
        let jitter = CGPoint(x: random.next(in: -4...4), y: random.next(in: -3...3))
        let center = CGPoint(
          x: rect.minX + rect.width * spot.x + jitter.x, y: rect.minY + rect.height * spot.y + jitter.y)
        let scale = sin(local * .pi)
        var star = context
        star.translateBy(x: center.x, y: center.y)
        star.rotate(by: .degrees(90 * local))
        star.scaleBy(x: scale, y: scale)
        let hue: Hue = i.isMultiple(of: 2) ? .yellow : .accent
        star.fill(Self.star(radius: spot.size / 2), with: .style(hue.fill))
      }
    }
    .padding(-spread)
  }

  /// A four-point star with concave sides, centred on the origin.
  private static func star(radius r: CGFloat) -> Path {
    var path = Path()
    let points = [CGPoint(x: 0, y: -r), CGPoint(x: r, y: 0), CGPoint(x: 0, y: r), CGPoint(x: -r, y: 0)]
    let pinch = r * 0.28
    path.move(to: points[0])
    for i in 0..<4 {
      let next = points[(i + 1) % 4]
      let corner = CGPoint(x: (points[i].x + next.x) * 0.5, y: (points[i].y + next.y) * 0.5)
      path.addQuadCurve(to: next, control: CGPoint(x: corner.x * pinch / r, y: corner.y * pinch / r))
    }
    path.closeSubpath()
    return path
  }
}

/// A slanted band of accent light that crosses the view from left to right.
private struct Shimmer: View {
  let t: Double

  var body: some View {
    GeometryReader { proxy in
      let band = max(36, proxy.size.width * 0.3)
      let e = easeInOut(t)
      Rectangle()
        .fill(Hue.accent.soft(0.32))
        .mask(LinearGradient(colors: [.clear, .black, .clear], startPoint: .leading, endPoint: .trailing))
        .frame(width: band, height: proxy.size.height * 3)
        .rotationEffect(.degrees(18))
        .position(
          x: -band + (proxy.size.width + band * 2) * e,
          y: proxy.size.height / 2)
    }
  }
}

// MARK: - Support

private func easeOut(_ t: Double) -> Double { 1 - (1 - t) * (1 - t) }
private func easeInOut(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }

/// A tiny deterministic generator, so a play draws the same pieces every frame and the next play draws new ones.
private struct SeededRandom {
  private var state: UInt64

  init(seed: Int) { state = UInt64(truncatingIfNeeded: seed) &* 0x9E37_79B9_7F4A_7C15 | 1 }

  mutating func next(in range: ClosedRange<Double>) -> Double {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return range.lowerBound + Double(state % 10_000) / 10_000 * (range.upperBound - range.lowerBound)
  }
}

struct StatusEffectModifier: ViewModifier {
  let status: WorkStatus
  let cornerRadius: CGFloat
  @State private var finished = 0
  @State private var failed = 0

  func body(content: Content) -> some View {
    content
      .effect(.success, on: finished, cornerRadius: cornerRadius)
      .effect(.failure, on: failed, cornerRadius: cornerRadius)
      .onChange(of: status) { old, new in
        guard !old.isFinished else { return }
        if new == .done { finished += 1 }
        if case .failed = new { failed += 1 }
      }
  }
}
