import SwiftUI

/// A short effect the kit plays on a view when something happened. Apps report the event; the kit decides the look.
public enum KitEffect: Hashable, Sendable {
  // Feedback

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

  // Flourishes: pieces that leave the view or land on it

  /// Worth celebrating (published, all tests passed, inbox zero): confetti bursts from the view and falls away.
  case burst
  /// Earned (a streak, an achievement, points): the symbol sprays up from the view's top edge in an arc and falls
  /// back. `.fountain("star.fill", .yellow)`.
  case fountain(_ systemImage: String = "star.fill", _ hue: Hue = .yellow)
  /// Kept or counted (liked, starred, +1): the symbol rises from the view's top edge and fades, two smaller ones
  /// after it. `.float("heart.fill", .pink)`.
  case float(_ systemImage: String = "plus", _ hue: Hue = .accent)
  /// Sent off (sent, pushed, uploaded, shared): the symbol leaves the view's trailing edge and flies away up and to
  /// the right while the view recoils. `.send("paperplane.fill")`.
  case send(_ systemImage: String = "paperplane.fill", _ hue: Hue = .accent)
  /// Came in (received, downloaded, saved here): the symbol drops onto the view's top edge, lands and sinks in while
  /// the view dips. `.receive("arrow.down.circle.fill")`.
  case receive(_ systemImage: String = "arrow.down.circle.fill", _ hue: Hue = .accent)
  /// Gone (cleared, emptied, deleted a draft): grey puffs blow out from the view and thin away.
  case poof
  /// New or generated (a summary, a suggestion, a fresh result): small stars twinkle around the view.
  case sparkle
  /// Approved (verified, merged, signed): the symbol stamps down on the view's top-trailing corner, like a seal,
  /// with a ring and a wash.
  /// `.stamp("checkmark.seal.fill", .green)`.
  case stamp(_ systemImage: String = "checkmark.seal.fill", _ hue: Hue = .green)

  // Light: drawn on or around the view's edge

  /// Refreshed or up to date: a band of accent light sweeps across.
  case shimmer
  /// Ready (connected, unlocked, your turn): a soft accent halo blooms around the view and fades.
  case glow
  /// Reached (pinged, broadcast, shared nearby): three rings ripple out from the view's edge.
  case ripple
  /// Came full circle (synced, backed up, a loop closed): a light runs once around the view's edge.
  case trace

  // Moves: the view itself moves

  /// Not now (locked, nothing to do, finish something else first): a short tilt back and forth, softer than
  /// `.failure`.
  case wiggle
  /// Here it is (a new item, a fresh notification): the view hops, lands with a squash and hops once more.
  case bounce
  /// Picked or snapped in (chosen, dropped into place): the view wobbles wider and taller and settles.
  case jelly
  /// Still alive (connected, live, listening): two quick beats.
  case heartbeat
  /// This way (more to see, swipe, next): the view nudges toward its trailing side twice.
  case nudge
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
      let move = t.map { reduceMotion ? EffectMove() : EffectMove(effect, at: $0) } ?? EffectMove()
      content
        .scaleEffect(x: move.scaleX, y: move.scaleY, anchor: move.anchor)
        .rotationEffect(.degrees(move.angle))
        .offset(x: move.x, y: move.y)
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
      await kitSleep(for: .seconds(duration))
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
    case .wiggle, .jelly, .nudge: return 0.6
    case .bounce: return 0.65
    case .poof: return 0.7
    case .send: return 0.75
    case .shimmer, .receive, .heartbeat: return 0.8
    case .burst, .float, .glow, .trace: return 0.9
    case .stamp: return 1
    case .sparkle, .ripple: return 1.1
    case .fountain: return 1.2
    }
  }

  private func progress(at date: Date) -> Double? {
    guard let start else { return nil }
    return min(1, max(0, date.timeIntervalSince(start) / duration))
  }
}

/// How an effect moves the view itself at progress `t`: scale, tilt and offset.
private struct EffectMove {
  var scaleX: CGFloat = 1
  var scaleY: CGFloat = 1
  var anchor: UnitPoint = .center
  var angle: Double = 0
  var x: CGFloat = 0
  var y: CGFloat = 0

  init() {}

  init(_ effect: KitEffect, at t: Double) {
    switch effect {
    case .success, .pop: scale(1 + 0.06 * sin(easeOut(t) * .pi))
    case .burst: scale(1 + 0.05 * sin(min(1, t * 2.2) * .pi))
    case .float, .fountain: scale(1 + 0.04 * sin(min(1, t * 3) * .pi))
    case .send: scale(1 - 0.04 * sin(min(1, t * 3) * .pi))
    case .poof: scale(1 - 0.04 * sin(min(1, t * 2.5) * .pi))
    case .receive: scale(1 - 0.05 * sin(window(t, 0.4, 0.7) * .pi))
    case .stamp: scale(1 - 0.035 * sin(window(t, 0.18, 0.43) * .pi))
    case .heartbeat: scale(1 + 0.07 * beat(t, at: 0.18) + 0.05 * beat(t, at: 0.45))
    case .failure:
      let e = easeOut(t)
      x = 4 * sin(e * .pi * 6) * (1 - e)
    case .wiggle:
      angle = 2.5 * sin(t * .pi * 4) * (1 - t)
    case .nudge:
      x = 6 * abs(sin(t * .pi * 2)) * (1 - t)
    case .jelly:
      let wobble = 0.07 * sin(t * .pi * 3.5) * (1 - t)
      scaleX = 1 + wobble
      scaleY = 1 - wobble
    case .bounce:
      // A hop, a squash on landing (anchored at the bottom), then a small second hop.
      anchor = .bottom
      if t < 0.55 { y = -10 * sin(t / 0.55 * .pi) }
      if t > 0.65 { y = -3 * sin((t - 0.65) / 0.35 * .pi) }
      let squash = sin(window(t, 0.5, 0.7) * .pi)
      scaleX = 1 + 0.05 * squash
      scaleY = 1 - 0.07 * squash
    default: break
    }
  }

  private mutating func scale(_ value: CGFloat) {
    scaleX = value
    scaleY = value
  }

  /// A short bump around `center`, 1 at its top.
  private func beat(_ t: Double, at center: Double) -> Double {
    exp(-pow((t - center) / 0.08, 2))
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
        case .fountain(let symbol, let hue):
          Fountain(systemImage: symbol, hue: hue, t: t, seed: seed)
        case .float(let symbol, let hue):
          FloatingSymbols(systemImage: symbol, hue: hue, t: t)
        case .send(let symbol, let hue):
          SentSymbol(systemImage: symbol, hue: hue, t: t)
        case .receive(let symbol, let hue):
          ReceivedSymbol(systemImage: symbol, hue: hue, t: t)
        case .poof:
          Poof(t: t, seed: seed)
        case .sparkle:
          Sparkles(t: t, seed: seed)
        case .stamp(let symbol, let hue):
          Stamp(systemImage: symbol, hue: hue, t: t)
        case .shimmer:
          Shimmer(t: t).clipShape(shape)
        case .glow:
          Glow(cornerRadius: cornerRadius, t: t)
        case .ripple:
          Ripple(shape: shape, t: t)
        case .trace:
          Trace(shape: shape, t: t)
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
    case .stamp(_, let hue): return hue
    case .pop, .pulse: return nil
    case .float(_, let hue), .send(_, let hue), .receive(_, let hue), .fountain(_, let hue):
      return reduceMotion ? hue : nil
    case .burst, .sparkle, .shimmer, .glow, .ripple, .trace, .bounce, .jelly, .heartbeat, .nudge:
      return reduceMotion ? .accent : nil
    case .wiggle, .poof: return reduceMotion ? .gray : nil
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
        // Every star takes its jitter, shown or not, so a star that ends doesn't move the others.
        let jitter = CGPoint(x: random.next(in: -4...4), y: random.next(in: -3...3))
        let delay = Double(i) * 0.09
        let local = (t - delay) / 0.5
        guard local > 0, local < 1 else { continue }
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

/// The symbol sprays up from the view's top edge, each copy on its own arc, and falls back as it fades.
private struct Fountain: View {
  let systemImage: String
  let hue: Hue
  let t: Double
  let seed: Int

  var body: some View {
    var random = SeededRandom(seed: seed)
    let drops = (0..<10).map { i in
      (delay: Double(i) * 0.035, vx: random.next(in: -64...64), vy: random.next(in: -125...(-95)),
       size: random.next(in: 9...14), spin: random.next(in: -40...40))
    }
    ZStack {
      ForEach(drops.indices, id: \.self) { i in
        let drop = drops[i]
        let local = max(0, t - drop.delay) / (1 - drop.delay)
        // Seconds since launch, under a constant pull back down.
        let time = local * 1.2
        Image(systemName: systemImage)
          .font(.system(size: drop.size, weight: .semibold))
          .foregroundStyle(hue.fill)
          .rotationEffect(.degrees(drop.spin * time))
          .scaleEffect(min(1, local / 0.08))
          .offset(x: drop.vx * time, y: drop.vy * time + 80 * time * time)
          .opacity(local == 0 ? 0 : local < 0.6 ? 1 : 1 - (local - 0.6) / 0.4)
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }
}

/// The symbol falls onto the view's top edge, lands with a squash, then shrinks into the view.
private struct ReceivedSymbol: View {
  let systemImage: String
  let hue: Hue
  let t: Double

  var body: some View {
    let fall = min(1, t / 0.42)
    let sink = window(t, 0.5, 1)
    let squash = sin(window(t, 0.4, 0.55) * .pi)
    Image(systemName: systemImage)
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(hue.fill)
      .scaleEffect(x: 1 + 0.18 * squash, y: 1 - 0.22 * squash, anchor: .bottom)
      .scaleEffect(1 - 0.6 * easeOut(sink))
      .offset(y: -40 * (1 - fall * fall) - 8 + 14 * easeOut(sink))
      .opacity(min(1, t / 0.1) * (1 - sink))
      .frame(maxHeight: .infinity, alignment: .top)
  }
}

/// Grey puffs: soft circles blow out from inside the view, swell and thin away.
private struct Poof: View {
  let t: Double
  let seed: Int

  private let spread: CGFloat = 36

  var body: some View {
    Canvas { context, size in
      let rect = CGRect(origin: .zero, size: size).insetBy(dx: spread, dy: spread)
      let center = CGPoint(x: rect.midX, y: rect.midY)
      var random = SeededRandom(seed: seed)
      let e = easeOut(t)
      let count = 10
      for i in 0..<count {
        let angle = Double(i) / Double(count) * 2 * .pi + random.next(in: -0.25...0.25)
        let travel = random.next(in: 12...26)
        let radius = random.next(in: 3...6)
        let start = CGPoint(
          x: center.x + cos(angle) * rect.width * 0.32, y: center.y + sin(angle) * rect.height * 0.32)
        let point = CGPoint(x: start.x + cos(angle) * travel * e, y: start.y + sin(angle) * travel * e - 6 * e)
        let r = radius + 6 * e
        var puff = context
        puff.opacity = 0.5 * pow(1 - t, 1.3) * min(1, t / 0.06)
        puff.fill(
          Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
          with: .style(Hue.gray.fill))
      }
    }
    .padding(-spread)
  }
}

/// The symbol comes down from large onto the view's top-trailing corner (clear of its title); on impact a ring
/// spreads from it.
private struct Stamp: View {
  let systemImage: String
  let hue: Hue
  let t: Double

  var body: some View {
    GeometryReader { proxy in
      let size = min(max(proxy.size.height * 0.5, 16), 22)
      let down = min(1, t / 0.2)
      let ring = window(t, 0.2, 0.7)
      let fade = t < 0.6 ? 1 : 1 - (t - 0.6) / 0.4
      ZStack {
        Circle()
          .stroke(hue.fill, lineWidth: 1.5)
          .frame(width: size * (1.1 + ring), height: size * (1.1 + ring))
          .opacity(ring == 0 || ring == 1 ? 0 : 0.7 * (1 - ring))
        Image(systemName: systemImage)
          .font(.system(size: size, weight: .bold))
          .foregroundStyle(hue.fill)
          .scaleEffect(1 + 0.9 * (1 - down) * (1 - down))
          .rotationEffect(.degrees(-8 * (1 - down)))
          .opacity(down * fade)
      }
      .position(x: proxy.size.width - size * 0.25, y: size * 0.25)
    }
  }
}

/// A soft accent halo around the view that swells and fades; it is cut out of the view, so it never covers it.
private struct Glow: View {
  let cornerRadius: CGFloat
  let t: Double

  var body: some View {
    let strength = pow(sin(t * .pi), 0.8)
    HaloBand(cornerRadius: cornerRadius, outset: 3 + 6 * easeOut(t))
      .fill(Hue.accent.fill, style: FillStyle(eoFill: true))
      .blur(radius: 6)
      .mask { HaloBand(cornerRadius: cornerRadius, outset: 40).fill(style: FillStyle(eoFill: true)) }
      .opacity(0.75 * strength)
  }
}

/// Three rings that spread out from the view's edge one after another.
private struct Ripple: View {
  let shape: RoundedRectangle
  let t: Double

  var body: some View {
    ZStack {
      ForEach(0..<3, id: \.self) { i in
        let local = window(t, Double(i) * 0.18, Double(i) * 0.18 + 0.64)
        shape.inset(by: -26 * easeOut(local))
          .stroke(Hue.accent.fill, lineWidth: 1.5)
          .opacity(local == 0 || local == 1 ? 0 : 0.7 * (1 - local))
      }
    }
  }
}

/// A short bright arc runs once around the view's edge, then the whole edge flashes as the loop closes.
private struct Trace: View {
  let shape: RoundedRectangle
  let t: Double

  var body: some View {
    let run = easeInOut(min(1, t / 0.75))
    let close = window(t, 0.7, 1)
    ZStack {
      shape.trim(from: max(0, run - 0.2), to: run)
        .stroke(Hue.accent.fill, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .opacity(t < 0.75 ? 1 : 1 - close)
      shape.stroke(Hue.accent.fill, lineWidth: 1.5)
        .opacity(0.6 * sin(close * .pi))
    }
  }
}

/// A band around a rounded rectangle: its outline grown by `outset`, minus the rectangle (fill it even-odd).
private struct HaloBand: Shape {
  let cornerRadius: CGFloat
  let outset: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path(
      roundedRect: rect.insetBy(dx: -outset, dy: -outset), cornerRadius: cornerRadius + outset, style: .continuous)
    path.addPath(Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous))
    return path
  }
}

// MARK: - Support

private func easeOut(_ t: Double) -> Double { 1 - (1 - t) * (1 - t) }
private func easeInOut(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }
/// `t` mapped so `from…to` runs 0…1, clamped.
private func window(_ t: Double, _ from: Double, _ to: Double) -> Double { min(1, max(0, (t - from) / (to - from))) }

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
