#if os(tvOS)
  import GameController
  import SwiftUI

  /// Where the thumb rests on the Siri Remote's touch surface, for the focus effect's tilt (`kitHoverEffect`). It
  /// listens only once a view is focused, and asks the remote for absolute positions: an app that reads the remote as
  /// a game controller itself sees them absolute too.
  @MainActor @Observable
  final class KitRemoteTouch {
    static let shared = KitRemoteTouch()

    /// From -0.5 to 0.5 across the surface (y down), or nil while the thumb is off it.
    private(set) var point: CGPoint?

    @ObservationIgnored private var started = false

    func start() {
      guard !started else { return }
      started = true
      NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { _ in
        MainActor.assumeIsolated { KitRemoteTouch.shared.listenToRemotes() }
      }
      listenToRemotes()
    }

    private func listenToRemotes() {
      for controller in GCController.controllers() { listen(to: controller) }
    }

    private func listen(to controller: GCController) {
      guard let pad = controller.microGamepad else { return }
      pad.reportsAbsoluteDpadValues = true
      pad.dpad.valueChangedHandler = { _, x, y in
        MainActor.assumeIsolated { KitRemoteTouch.shared.move(x: x, y: y) }
      }
    }

    private func move(x: Float, y: Float) {
      // The surface reads 0, 0 with no thumb on it (and at its very center, which reads as resting too).
      let point = x == 0 && y == 0 ? nil : KitRemoteTouch.point(x: x, y: y)
      if point != self.point { self.point = point }
    }

    /// The dpad's -1…1 (y up) as the effect's -0.5…0.5 (y down).
    nonisolated static func point(x: Float, y: Float) -> CGPoint {
      CGPoint(x: CGFloat(max(min(x, 1), -1)) / 2, y: CGFloat(-max(min(y, 1), -1)) / 2)
    }
  }
#endif
