import SwiftUI

#if canImport(AppKit)
  import AppKit
#elseif canImport(UIKit)
  import UIKit
#endif

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

  /// Puts a secret on the pasteboard (a password, a one-time code): it stays on this device (no Universal
  /// Clipboard, marked concealed so clipboard managers skip it) and is cleared after `expiry` seconds unless
  /// something else was copied since. `KitSecretValue` and `KitOneTimeCode` copy this way.
  ///
  /// ```swift
  /// Button("Copy Password") { KitPasteboard.copySecret(login.password) }
  /// ```
  @MainActor public static func copySecret(_ string: String, expiresAfter expiry: TimeInterval = 90) {
    #if canImport(AppKit)
      let board = NSPasteboard.general
      board.clearContents()
      // The nspasteboard.org markers: clipboard managers and Universal Clipboard leave it alone.
      let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
      let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
      board.declareTypes([.string, concealed, transient], owner: nil)
      board.setString(string, forType: .string)
      board.setString("", forType: concealed)
      board.setString("", forType: transient)
      let count = board.changeCount
      Task { @MainActor in
        try? await Task.sleep(for: .seconds(expiry))
        if board.changeCount == count { board.clearContents() }
      }
    #elseif canImport(UIKit)
      UIPasteboard.general.setItems(
        [["public.utf8-plain-text": string]],
        options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(expiry)])
    #else
      ContPlatform.copy(string)
    #endif
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
