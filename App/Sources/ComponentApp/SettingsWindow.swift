import ComponentKit
import SwiftUI

#if os(macOS)
  /// The catalog's own Settings window (⌘,): the sample panes in the setup every Mac app's Settings uses, a
  /// `Settings` scene with `.windowStyle(.hiddenTitleBar)` and `KitSettings(window: .hiddenTitleBar)`. DEBUG launch
  /// arguments: `--open-settings` opens it at launch; `--settings-window titled|framed|hidden` lays the panes out
  /// for another window, to compare.
  struct CatalogSettingsWindow: View {
    @State private var pane = "General"

    var body: some View {
      SampleSettings(selection: $pane, window: Self.window)
        .frame(width: 640, height: 480)
    }

    static var window: KitSettingsWindow {
      let arguments = ProcessInfo.processInfo.arguments
      guard let index = arguments.firstIndex(of: "--settings-window"), index + 1 < arguments.count else {
        return .hiddenTitleBar
      }
      switch arguments[index + 1] {
      case "titled": return .titled
      case "framed": return .framed
      default: return .hiddenTitleBar
      }
    }
  }

  /// `--open-settings` (DEBUG): opens the Settings window once the catalog's window is up.
  struct OpenSettingsAtLaunch: ViewModifier {
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
      content.task {
        guard ProcessInfo.processInfo.arguments.contains("--open-settings") else { return }
        try? await Task.sleep(for: .milliseconds(300))
        openSettings()
      }
    }
  }
#endif
