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

  /// The text on the general pasteboard, or `nil` when it holds none. Read it when the person acts (opening a sheet
  /// they asked for): on iOS reading it may ask them to allow pasting.
  ///
  /// ```swift
  /// .onAppear { if let text = KitPasteboard.string(), URL(string: text)?.scheme != nil { link = text } }
  /// ```
  @MainActor public static func string() -> String? {
    ContPlatform.pastedString()
  }
}
