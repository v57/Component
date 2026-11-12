import SwiftUI

#if canImport(UIKit) && !os(macOS)
  import UIKit
#endif
#if os(iOS) && canImport(GameController)
  import GameController
#endif

/// The kind of device the app runs on, for labels and symbols: "On My Mac", "On My iPad", "On This PC".
///
/// ```swift
/// Label("On My \(KitDevice.name)", systemImage: KitDevice.systemImage)
/// ```
public enum KitDevice {
  /// "Mac", "iPad", "iPhone", "Apple TV", or "PC" (Windows) / "Computer" (Linux).
  @MainActor public static var name: String {
    #if os(macOS)
      "Mac"
    #elseif os(tvOS)
      "Apple TV"
    #elseif canImport(UIKit)
      UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    #elseif os(Windows)
      "PC"
    #else
      "Computer"
    #endif
  }

  /// The name inside a sentence ("on this \(KitDevice.nameInSentence)"): the brand names keep their capitals, the
  /// generic "computer" (Linux) doesn't.
  @MainActor public static var nameInSentence: String {
    name == "Computer" ? "computer" : name
  }

  /// The SF Symbol for the device.
  @MainActor public static var systemImage: String {
    #if os(macOS)
      "laptopcomputer"
    #elseif os(tvOS)
      "appletv"
    #elseif canImport(UIKit)
      UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
    #else
      "desktopcomputer"
    #endif
  }

  /// Whether there's a keyboard to press shortcuts on: always on a computer, on iPad while a hardware keyboard is
  /// connected, never on iPhone or Apple TV. Mention a shortcut ("⌃⌘1…⌃⌘9 switch") only where it's true.
  ///
  /// ```swift
  /// Text(KitDevice.hasKeyboard ? "Each window shows one account; ⌃⌘1…⌃⌘9 switch." : "Each window shows one account.")
  /// ```
  @MainActor public static var hasKeyboard: Bool {
    #if os(macOS) || os(Windows) || os(Linux)
      true
    #elseif os(iOS) && canImport(GameController)
      UIDevice.current.userInterfaceIdiom == .pad && GCKeyboard.coalesced != nil
    #else
      false
    #endif
  }
}
