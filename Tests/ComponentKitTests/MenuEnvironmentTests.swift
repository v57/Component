import SwiftUI
import Testing

@testable import ComponentKit

// A menu's rows and a tooltip's detail draw in their own window (a panel on the Mac, a window above the scene on
// iPhone and iPad), so they don't inherit the presenting view's environment: the kit carries it over. Before it did,
// an app's model injected with `.environment(model)` was missing in the menu, and `@Environment(Model.self)` trapped
// (Vault's New menu, the Hub app's hub menu, on iPhone and iPad).

@MainActor @Observable
private final class MenuProbeModel {
  var name = "probe"
}

/// What the menu's row found in its environment.
@MainActor
private final class MenuProbeLog {
  var model: MenuProbeModel?
  var value: Int?
  var hint: String??
  var isEnabled: Bool?
  var built = false
}

extension EnvironmentValues {
  /// A value only the app sets (the kit doesn't carry it over by name).
  @Entry fileprivate var menuProbeValue = 0
}

private struct MenuProbeRow: View {
  let log: MenuProbeLog
  // Optional, so a missing model is nil here rather than a trap.
  @Environment(MenuProbeModel.self) private var model: MenuProbeModel?
  @Environment(\.menuProbeValue) private var value
  @Environment(\.kitMenuHint) private var hint
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    let _ = record()
    Button("Row") {}
  }

  private func record() {
    log.model = model
    log.value = value
    log.hint = hint
    log.isEnabled = isEnabled
    log.built = true
  }
}

#if canImport(AppKit)
  import AppKit

  @MainActor @Test func menuContentGetsThePresentersEnvironment() async throws {
    _ = NSApplication.shared
    let model = MenuProbeModel()
    let log = MenuProbeLog()
    let root = Text("Trigger")
      // A row's hint on the trigger itself is the trigger's, not every row's.
      .kitMenuHint("⌘N")
      .kitMenu(isPresented: .constant(true)) { MenuProbeRow(log: log) }
      .disabled(true)
      .environment(model)
      .environment(\.menuProbeValue, 7)
      .frame(width: 200, height: 100)
    let window = NSWindow(
      contentRect: CGRect(x: 100, y: 100, width: 200, height: 100), styleMask: [.titled], backing: .buffered,
      defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: root)
    window.orderFront(nil)
    defer {
      // The anchor goes, and the menu's panel with it.
      window.contentView = nil
      window.orderOut(nil)
    }
    for _ in 0..<100 where !log.built { try await Task.sleep(for: .milliseconds(20)) }
    #expect(log.built)
    #expect(log.model === model)
    #expect(log.value == 7)
    // What belongs to where the anchor is stays there: a row's hint, and a disabled anchor (behind an overlay).
    #expect(log.hint == .some(nil))
    #expect(log.isEnabled == true)
  }
#endif
