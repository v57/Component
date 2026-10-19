import SwiftUI

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
    private static func run(_ tool: String, _ arguments: [String]) {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: tool)
      process.arguments = arguments
      try? process.run()
    }
  #endif
}
