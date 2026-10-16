import SwiftUI

/// The system pasteboard, without the platform's types: copy text on the Mac, iPad and iPhone alike.
///
/// ```swift
/// Button("Copy Hash", systemImage: "doc.on.doc") { KitPasteboard.copy(commit.hash) }
/// ```
public enum KitPasteboard {
  /// Puts `string` on the general pasteboard, replacing what was there.
  @MainActor public static func copy(_ string: String) {
    ContPlatform.copy(string)
  }
}
