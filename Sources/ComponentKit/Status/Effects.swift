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
}

extension View {
  /// Plays `effect` once each time `value` changes. It draws in an overlay (layout never moves), quick repeats
  /// merge, nothing plays in a window that isn't focused, and Reduce Motion keeps only the colour.
  ///
  /// ```swift
  /// Button("Push") { … }.effect(.success, on: pushedCount)
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

struct EffectModifier<V: Equatable>: ViewModifier {
  let effect: KitEffect
  let trigger: V
  let cornerRadius: CGFloat
  @State private var phase: CGFloat = 0
  @State private var playing = false
  @Environment(\.kitWindowIsActive) private var isActive
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content
      .scaleEffect(scale)
      .offset(x: shake)
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(washStyle)
          .opacity(playing ? (1 - phase) * washOpacity : 0)
          .allowsHitTesting(false)
      }
      .overlay {
        if effect == .pulse {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Hue.accent.fill, lineWidth: 2)
            .scaleEffect(1 + phase * 0.25)
            .opacity(playing ? 1 - phase : 0)
            .allowsHitTesting(false)
        }
      }
      .onChange(of: trigger) { play() }
  }

  private func play() {
    guard isActive else { return }
    phase = 0
    playing = true
    withAnimation(.easeOut(duration: reduceMotion ? 0.3 : 0.55)) { phase = 1 } completion: { playing = false }
  }

  private var washStyle: HueStyle {
    switch effect {
    case .success: Hue.green.fill
    case .failure: Hue.red.fill
    default: Hue.accent.fill
    }
  }

  private var washOpacity: Double {
    switch effect {
    case .success, .failure, .wash: 0.22
    default: 0
    }
  }

  private var scale: CGFloat {
    guard playing, !reduceMotion else { return 1 }
    switch effect {
    case .success, .pop: return 1 + 0.06 * sin(phase * .pi)
    default: return 1
    }
  }

  private var shake: CGFloat {
    guard playing, !reduceMotion, effect == .failure else { return 0 }
    return 4 * sin(phase * .pi * 6) * (1 - phase)
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
