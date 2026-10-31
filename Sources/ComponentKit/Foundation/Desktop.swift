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
  /// Whether the app with a bundle identifier (`dev.v57.code`) is installed, for items such as Open in Code that
  /// show only then. Only the Mac looks apps up this way: false elsewhere.
  @MainActor public static func isAppInstalled(_ bundleIdentifier: String) -> Bool {
    #if canImport(AppKit)
      NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    #else
      false
    #endif
  }

  /// Opens files and folders in the app with a bundle identifier, handed over in order (a project's folder, then a
  /// file in it). Does nothing when the app isn't installed, and off the Mac.
  ///
  /// ```swift
  /// if KitDesktop.isAppInstalled("dev.v57.code") {
  ///   Button("Open in Code", systemImage: "chevron.left.forwardslash.chevron.right") {
  ///     KitDesktop.open([project, file], withApp: "dev.v57.code")
  ///   }
  /// }
  /// ```
  @MainActor public static func open(_ urls: [URL], withApp bundleIdentifier: String) {
    #if canImport(AppKit)
      guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
      NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    #endif
  }

  /// Opens a terminal in a folder: Terminal on the Mac, Windows Terminal (else PowerShell) on Windows.
  @MainActor public static func openTerminal(at folder: URL) {
    #if canImport(AppKit)
      open([folder], withApp: "com.apple.Terminal")
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

  /// Asks for folders with the system's open panel; empty when cancelled (and on iOS, which has none). `name` picks an
  /// item in `directory` to start on (the folder the user is asked to grant again).
  ///
  /// ```swift
  /// let folder = await KitDesktop.chooseFolders(prompt: "Allow Editing", directory: root.deletingLastPathComponent(),
  ///                                             name: root.lastPathComponent).first
  /// ```
  @MainActor public static func chooseFolders(
    prompt: String = "Choose", message: String? = nil, directory: URL? = nil, allowsMultipleSelection: Bool = false,
    canCreateDirectories: Bool = false, name: String? = nil
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
      if let name { panel.nameFieldStringValue = name }
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

  /// Asks for files with the system's open panel: of `contentTypes` (any file when empty), and folders too with
  /// `canChooseFolders`; empty when cancelled (and on iOS, which has none: use SwiftUI's `fileImporter` there). Windows
  /// and Linux show their own file dialogs.
  ///
  /// ```swift
  /// let urls = await KitDesktop.chooseFiles(prompt: "Open", contentTypes: [.movie], allowsMultipleSelection: true)
  /// for url in await KitDesktop.chooseFiles(message: "Choose a folder to open as a project.", canChooseFolders: true) { open(url) }
  /// ```
  @MainActor public static func chooseFiles(
    title: String? = nil, prompt: String = "Open", message: String? = nil, contentTypes: [UTType] = [],
    directory: URL? = nil, canChooseFolders: Bool = false, allowsMultipleSelection: Bool = false
  ) async -> [URL] {
    #if canImport(AppKit)
      let panel = NSOpenPanel()
      if let title { panel.title = title }
      if let message { panel.message = message }
      panel.prompt = prompt
      panel.canChooseFiles = true
      panel.canChooseDirectories = canChooseFolders
      panel.allowsMultipleSelection = allowsMultipleSelection
      if !contentTypes.isEmpty { panel.allowedContentTypes = contentTypes }
      if let directory { panel.directoryURL = directory }
      return panel.runModal() == .OK ? panel.urls : []
    #elseif canImport(UIKit)
      return []
    #else
      var request = FileDialogRequest(
        kind: .open, contentTypes: contentTypes.map(\.identifier), allowsMultipleSelection: allowsMultipleSelection,
        canChooseDirectories: canChooseFolders)
      request.options.confirmationLabel = prompt
      request.options.message = message ?? title
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

  /// The icon the file manager shows for a file, folder or app (Finder's on the Mac, already in its shape: draw it with
  /// `KitAppIcon(image:isShaped: true)` or as it is); nil where the system has none to give.
  ///
  /// ```swift
  /// if let icon = KitDesktop.icon(forFile: app.path) { icon.resizable().frame(width: 18, height: 18) }
  /// ```
  @MainActor public static func icon(forFile path: String) -> Image? {
    #if canImport(AppKit)
      Image(nsImage: NSWorkspace.shared.icon(forFile: path))
    #else
      nil
    #endif
  }

  /// Whether an app with this bundle identifier is running (the Mac's apps; false elsewhere).
  public static func isAppRunning(_ bundleIdentifier: String) -> Bool {
    #if canImport(AppKit)
      !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    #else
      false
    #endif
  }

  /// Calls `handler` each time the app becomes the active one (the user comes back to it: refresh what may have
  /// changed meanwhile), until the returned observation is released. The Mac, iPhone and iPad say so; never called
  /// where the system doesn't (Windows, Linux).
  ///
  /// ```swift
  /// @State private var activation: AnyObject?
  /// .onAppear { activation = KitDesktop.onActivation { model.refresh() } }
  /// ```
  @MainActor public static func onActivation(_ handler: @escaping @MainActor () -> Void) -> AnyObject? {
    #if canImport(AppKit)
      KitObservation(NSApplication.didBecomeActiveNotification, handler)
    #elseif canImport(UIKit)
      KitObservation(UIApplication.didBecomeActiveNotification, handler)
    #else
      nil
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

#if canImport(AppKit) || canImport(UIKit)
  /// A notification observer that stops observing when released.
  private final class KitObservation {
    let token: NSObjectProtocol

    @MainActor init(_ name: Notification.Name, _ handler: @escaping @MainActor () -> Void) {
      token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
        MainActor.assumeIsolated { handler() }
      }
    }

    deinit { NotificationCenter.default.removeObserver(token) }
  }
#endif
