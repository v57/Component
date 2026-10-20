import SwiftUI

#if canImport(UIKit) && !os(macOS)
  import UIKit
#endif

/// The kind of device the app runs on, for labels and symbols: "On My Mac", "On My iPad", "On This PC".
///
/// ```swift
/// Label("On My \(KitDevice.name)", systemImage: KitDevice.systemImage)
/// ```
public enum KitDevice {
  /// "Mac", "iPad", "iPhone", or "PC" (Windows) / "Computer" (Linux).
  @MainActor public static var name: String {
    #if os(macOS)
      "Mac"
    #elseif canImport(UIKit)
      UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    #elseif os(Windows)
      "PC"
    #else
      "Computer"
    #endif
  }

  /// The SF Symbol for the device.
  @MainActor public static var systemImage: String {
    #if os(macOS)
      "laptopcomputer"
    #elseif canImport(UIKit)
      UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
    #else
      "desktopcomputer"
    #endif
  }
}
