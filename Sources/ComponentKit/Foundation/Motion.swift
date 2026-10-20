import SwiftUI

extension Animation {
  /// The one animation every app uses: selection, pages, icons, text (`.smooth(duration: 0.25)`).
  public static let kit = Animation.smooth(duration: 0.25)
  /// Press, hover, labels.
  public static let kitFast = Animation.smooth(duration: 0.15)
  /// Windows, sheets, the sidebar.
  public static let kitSlow = Animation.smooth(duration: 0.35)
  /// Things that land with a bounce: an inserted row, a toast rising, the folder that takes a dropped row. The dropped
  /// row itself settles into its place with `.kit`.
  public static let kitSpring = Animation.spring(response: 0.35, dampingFraction: 0.68)
}

extension AnyTransition {
  /// Screens and panels fade in with a small rise and fade out.
  public static var page: AnyTransition { AnyTransition.asymmetric(
    insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity) }
  /// A detail pane replacing another: a crossfade with a small scale.
  public static var detail: AnyTransition { .opacity.combined(with: .scale(scale: 0.985)) }
  /// A row that arrives or leaves a list: it unfolds from its height.
  public static var row: AnyTransition { .opacity.combined(with: .move(edge: .top)) }
}

extension View {
  /// Animates changes of `value` with the kit's animation (the root modifier stills it in an inactive window).
  public func kitAnimation<V: Equatable>(_ value: V, _ animation: Animation = .kit) -> some View {
    self.animation(animation, value: value)
  }
}

/// Runs `body` with the kit's animation: `withKitAnimation { selection = item }`.
@MainActor
public func withKitAnimation<Result>(_ animation: Animation = .kit, _ body: () throws -> Result) rethrows -> Result {
  try withAnimation(animation, body)
}
