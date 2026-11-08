import SwiftUI

#if os(iOS) || os(visionOS)
  import UIKit
#endif

extension View {
  /// Covers the whole window with `cover` while `isPresented`, above everything the window shows: on iPhone and iPad
  /// a window of its own above the scene's, so the window's sheets, full-screen covers, alerts and the kit's menus
  /// stay under it; on the Mac the window's content with the kit's sheets. For an app lock, and for what the app
  /// switcher's snapshot shows (present it while the scene isn't active).
  ///
  /// `cover` gets this view's environment, and takes the touches and the keys while it shows.
  ///
  /// ```swift
  /// ContentView()
  ///   .kitCover(isPresented: lock.isLocked || scenePhase != .active) { LockScreen() }
  /// ```
  public func kitCover<Cover: View>(isPresented: Bool, @ViewBuilder cover: () -> Cover) -> some View {
    modifier(ContCover(isPresented: isPresented, cover: cover()))
  }
}

struct ContCover<Cover: View>: ViewModifier {
  let isPresented: Bool
  let cover: Cover

  func body(content: Content) -> some View {
    #if os(iOS) || os(visionOS)
      content.background {
        ContCoverAnchor(isPresented: isPresented, cover: cover)
          .frame(width: 0, height: 0)
          .accessibilityHidden(true)
      }
    #else
      content.overlay {
        if isPresented { cover }
      }
    #endif
  }
}

#if os(iOS) || os(visionOS)
  /// Finds the scene of the view it sits behind, and shows or hides the cover's window as `isPresented` changes.
  struct ContCoverAnchor<Cover: View>: UIViewRepresentable {
    let isPresented: Bool
    let cover: Cover

    func makeCoordinator() -> ContCoverWindow { ContCoverWindow() }

    func makeUIView(context: Context) -> ContCoverAnchorView {
      let view = ContCoverAnchorView()
      view.isUserInteractionEnabled = false
      view.coordinator = context.coordinator
      return view
    }

    func updateUIView(_ view: ContCoverAnchorView, context: Context) {
      let coordinator = context.coordinator
      coordinator.isPresented = isPresented
      coordinator.root = isPresented ? AnyView(cover.environment(\.self, context.environment)) : nil
      coordinator.update(scene: view.window?.windowScene)
    }

    static func dismantleUIView(_ view: ContCoverAnchorView, coordinator: ContCoverWindow) {
      coordinator.hide()
    }
  }

  /// The anchor: shows the cover once it's in a window (the first update may come before).
  final class ContCoverAnchorView: UIView {
    weak var coordinator: ContCoverWindow?

    override func didMoveToWindow() {
      super.didMoveToWindow()
      coordinator?.update(scene: window?.windowScene)
    }
  }

  /// The cover's window: above the scene's windows and the kit's menu window (`.alert + 1`).
  @MainActor
  final class ContCoverWindow {
    var isPresented = false
    var root: AnyView?
    private var window: UIWindow?
    private var host: UIHostingController<AnyView>?

    func update(scene: UIWindowScene?) {
      guard isPresented, let root, let scene else {
        if !isPresented { hide() }
        return
      }
      if let host, window?.windowScene === scene {
        host.rootView = root
        return
      }
      hide()
      let window = UIWindow(windowScene: scene)
      let host = UIHostingController(rootView: root)
      host.view.backgroundColor = .clear
      window.windowLevel = .alert + 2
      window.backgroundColor = .clear
      window.rootViewController = host
      window.isHidden = false
      window.makeKey()
      self.window = window
      self.host = host
    }

    func hide() {
      guard let window else { return }
      window.isHidden = true
      self.window = nil
      host = nil
      // The scene's own window takes the keys again.
      window.windowScene?.windows.first { $0.windowLevel == .normal && !$0.isHidden }?.makeKey()
    }
  }
#endif
