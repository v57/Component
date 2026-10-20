import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppKit)
  import AppKit
#elseif canImport(UIKit)
  import UIKit
#elseif os(Windows)
  import WinSDK
#endif

/// Hands files and links to the system, without the platform's types: opens them in their default app and shows
/// them in the file manager (Finder, Explorer).
///
/// ```swift
/// Button("Show in \(KitDesktop.fileManagerName)", systemImage: "folder") { KitDesktop.reveal([download.url]) }
/// ```
public enum KitDesktop {
  /// Opens a file in its default app, or a link in the browser.
  @MainActor public static func open(_ url: URL) {
    #if canImport(AppKit)
      NSWorkspace.shared.open(url)
    #elseif canImport(UIKit)
      UIApplication.shared.open(url)
    #elseif os(Windows)
      let target = url.isFileURL ? url.path : url.absoluteString
      _ = target.withCString(encodedAs: UTF16.self) { file in
        "open".withCString(encodedAs: UTF16.self) { verb in ShellExecuteW(nil, verb, file, nil, nil, SW_SHOWNORMAL) }
      }
    #else
      run("/usr/bin/xdg-open", [url.isFileURL ? url.path : url.absoluteString])
    #endif
  }

  /// Shows files in the file manager, selected in their folder.
  @MainActor public static func reveal(_ urls: [URL]) {
    #if canImport(AppKit)
      NSWorkspace.shared.activateFileViewerSelecting(urls)
    #elseif os(Windows)
      for url in urls.prefix(1) {
        run(#"C:\Windows\explorer.exe"#, ["/select,\(url.path.replacingOccurrences(of: "/", with: "\\"))"])
      }
    #elseif canImport(UIKit)
      // iOS has no file manager to point at a file: the Files app opens on the folder.
      if let folder = urls.first?.deletingLastPathComponent(),
        let files = URL(string: "shareddocuments://" + folder.path)
      {
        UIApplication.shared.open(files)
      }
    #else
      if let folder = urls.first?.deletingLastPathComponent() { open(folder) }
    #endif
  }

  /// What the file manager is called on this platform, for labels ("Show in Finder").
  public static var fileManagerName: String {
    #if os(macOS)
      "Finder"
    #elseif os(Windows)
      "Explorer"
    #elseif canImport(UIKit)
      "Files"
    #else
      "Files"
    #endif
  }

  #if !canImport(AppKit) && !canImport(UIKit)
    static func run(_ tool: String, _ arguments: [String]) {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: tool)
      process.arguments = arguments
      try? process.run()
    }
  #endif
}

extension KitDesktop {
  /// Opens a terminal in a folder: Terminal on the Mac, Windows Terminal (else PowerShell) on Windows.
  @MainActor public static func openTerminal(at folder: URL) {
    #if canImport(AppKit)
      guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
      NSWorkspace.shared.open([folder], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    #elseif os(Windows)
      let path = folder.path.replacingOccurrences(of: "/", with: "\\")
      let local = ProcessInfo.processInfo.environment["LOCALAPPDATA"] ?? ""
      let windowsTerminal = local + "\\Microsoft\\WindowsApps\\wt.exe"
      if FileManager.default.fileExists(atPath: windowsTerminal) {
        run(windowsTerminal, ["-d", path])
      } else {
        run(#"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"#, ["-NoExit", "-Command", "Set-Location -LiteralPath '\(path)'"])
      }
    #elseif !canImport(UIKit)
      run("/usr/bin/x-terminal-emulator", ["--working-directory=\(folder.path)"])
    #endif
  }

  /// Asks for folders with the system's open panel; empty when cancelled (and on iOS, which has none).
  @MainActor public static func chooseFolders(
    prompt: String = "Choose", message: String? = nil, directory: URL? = nil, allowsMultipleSelection: Bool = false,
    canCreateDirectories: Bool = false
  ) async -> [URL] {
    #if canImport(AppKit)
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = allowsMultipleSelection
      panel.canCreateDirectories = canCreateDirectories
      panel.prompt = prompt
      if let message { panel.message = message }
      if let directory { panel.directoryURL = directory }
      return panel.runModal() == .OK ? panel.urls : []
    #elseif canImport(UIKit)
      return []
    #else
      var request = FileDialogRequest(
        kind: .open, contentTypes: [UTType.folder.identifier], allowsMultipleSelection: allowsMultipleSelection,
        canChooseDirectories: true)
      request.options.confirmationLabel = prompt
      request.options.message = message
      request.options.defaultDirectory = directory
      return await FileDialogs.present(request) ?? []
    #endif
  }

  /// Asks where to save with the system's save panel; nil when cancelled (and on iOS).
  @MainActor public static func chooseSaveLocation(
    title: String? = nil, prompt: String = "Save", name: String = "", directory: URL? = nil
  ) async -> URL? {
    #if canImport(AppKit)
      let panel = NSSavePanel()
      if let title { panel.title = title }
      panel.prompt = prompt
      panel.nameFieldStringValue = name
      panel.canCreateDirectories = true
      if let directory { panel.directoryURL = directory }
      return panel.runModal() == .OK ? panel.url : nil
    #elseif canImport(UIKit)
      return nil
    #else
      var request = FileDialogRequest(kind: .save, contentTypes: [], defaultFilename: name)
      request.options.confirmationLabel = prompt
      request.options.message = title
      request.options.defaultDirectory = directory
      return await FileDialogs.present(request)?.first
    #endif
  }

  /// The modifier keys held now, for clicks that select more (⌘-click, ⇧-click). On Windows and Linux Ctrl
  /// counts as ⌘, as in their menus' shortcuts.
  @MainActor public static var modifierKeys: EventModifiers {
    #if canImport(AppKit)
      let flags = NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags
      var keys: EventModifiers = []
      if flags.contains(.command) { keys.insert(.command) }
      if flags.contains(.shift) { keys.insert(.shift) }
      if flags.contains(.option) { keys.insert(.option) }
      if flags.contains(.control) { keys.insert(.control) }
      return keys
    #elseif os(Windows)
      func down(_ key: Int32) -> Bool { GetKeyState(key) < 0 }
      var keys: EventModifiers = []
      if down(VK_CONTROL) { keys.insert(.command) }
      if down(VK_SHIFT) { keys.insert(.shift) }
      if down(VK_MENU) { keys.insert(.option) }
      return keys
    #else
      return []
    #endif
  }
}
