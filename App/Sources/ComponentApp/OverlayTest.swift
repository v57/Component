#if DEBUG && os(macOS)
  import AppKit
  import ComponentKit
  import SwiftUI

  /// `--overlay-test <report> --overlay-keys tab,shift-tab,esc` (DEBUG, Mac): once the window is up (open an overlay
  /// with `--open-sheet`), hands the keys to the top overlay as its key monitor would (events an app posts to itself
  /// never reach monitors), then to the app's event queue, so a background launch takes them without focus, and writes after each one which field has focus and which text fields are still on screen.
  @MainActor
  enum OverlayTest {
    private static var hasRun = false

    private static var hasSetAppearance = false

    /// `--app-appearance light|dark`: sets the app's appearance after launch, as Git, Database and Dev's screenshots
    /// force one on a Mac set to the other (`NSApp.appearance`), to check overlays under it.
    static func setAppearanceIfAsked() {
      let arguments = ProcessInfo.processInfo.arguments
      guard !hasSetAppearance, let index = arguments.firstIndex(of: "--app-appearance"), index + 1 < arguments.count
      else { return }
      hasSetAppearance = true
      let name: NSAppearance.Name = arguments[index + 1] == "dark" ? .darkAqua : .aqua
      Task { @MainActor in NSApp.appearance = NSAppearance(named: name) }
    }

    static func runIfAsked() {
      let arguments = ProcessInfo.processInfo.arguments
      guard !hasRun, let index = arguments.firstIndex(of: "--overlay-test"), index + 1 < arguments.count else { return }
      hasRun = true
      let path = arguments[index + 1]
      let keys = arguments.firstIndex(of: "--overlay-keys").map { arguments[$0 + 1].split(separator: ",").map(String.init) } ?? []
      Task { @MainActor in
        try? await Task.sleep(for: .seconds(2))
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.frame.height > 300 }) else { return }
        window.makeKey()
        var report = ["start: \(state(window))"]
        for key in keys {
          post(key, to: window)
          try? await Task.sleep(for: .seconds(0.8))
          report.append("\(key): \(state(window))")
        }
        try? report.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
      }
    }

    private static func post(_ key: String, to window: NSWindow) {
      let (code, characters, flags): (UInt16, String, NSEvent.ModifierFlags) =
        switch key {
        case "tab": (48, "\t", [])
        case "shift-tab": (48, "\u{19}", .shift)
        case "esc": (53, "\u{1b}", [])
        case "return": (36, "\r", [])
        default: (0, key, [])
        }
      for type in [NSEvent.EventType.keyDown, .keyUp] {
        guard
          let event = NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)
        else { continue }
        // As the kit's event monitor would see it; what it leaves goes on to the window.
        if type == .keyDown, _kitOverlayHandleKey(event) { continue }
        NSApp.postEvent(event, atStart: false)
      }
    }

    /// The focused field's text, and every editable field's text in the window.
    private static func state(_ window: NSWindow) -> String {
      var focused = "none"
      if let editor = window.firstResponder as? NSTextView, editor.isFieldEditor {
        focused = "field \"\((editor.delegate as? NSTextField)?.stringValue ?? editor.string)\""
      } else if let responder = window.firstResponder {
        focused = String(describing: type(of: responder))
      }
      var fields: [String] = []
      var overlays = 0
      func walk(_ view: NSView) {
        if String(describing: type(of: view)).contains("KitOverlayFocusView") { overlays += 1 }
        if let field = view as? NSTextField, field.isEditable, !field.isHidden {
          fields.append(field.stringValue.isEmpty ? "(\(field.placeholderString ?? ""))" : field.stringValue)
        }
        view.subviews.forEach(walk)
      }
      if let root = window.contentView { walk(root) }
      return "overlays \(overlays); focus \(focused); fields \(fields)"
    }
  }
#endif
