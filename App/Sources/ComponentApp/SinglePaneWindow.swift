import ComponentKit
import SwiftUI

#if os(macOS)
  /// A window of one pane under the kit's toolbar (no sidebar): the bar's title starts after the traffic lights.
  /// DEBUG: `--open-single-pane` opens it at launch (Window › Single Pane otherwise).
  struct SinglePaneWindow: View {
    @State private var showsFilter = false
    @State private var isStreaming = true

    var body: some View {
      EmptyState(
        systemImage: "display", title: "Studio Display", message: "A window with no sidebar: the kit's bar is its toolbar.")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.kitWindow)
        .kitToolbar("Studio Display", meta: ["build-mac"], systemImage: "display", status: isStreaming ? .idle : .working) {
          ToolGroup(iconOnly: true) {
            Button("Windows", systemImage: "macwindow.on.rectangle") { showsFilter = true }
              .kitToolOn(showsFilter)
            Button("Stream", systemImage: "play") { isStreaming.toggle() }
          }
          .kitPopover(isPresented: $showsFilter) {
            Text("The host's windows").kitFont(.headline).padding(14).frame(width: 220, alignment: .leading)
          }
        }
    }
  }

  /// `--open-single-pane` (DEBUG): opens the single-pane window once the catalog's window is up.
  struct OpenSinglePaneAtLaunch: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
      content.task {
        guard ProcessInfo.processInfo.arguments.contains("--open-single-pane") else { return }
        try? await Task.sleep(for: .milliseconds(300))
        openWindow(id: "single-pane")
      }
    }
  }
#endif
