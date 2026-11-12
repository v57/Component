#if os(macOS)
  import AppKit
  import SwiftUI
  import Testing

  @testable import ComponentKit

  /// `kitColorScheme(nil)` follows the app's appearance: its stream gives the scheme now, then each change.
  @MainActor @Test func colorSchemeFollowsTheAppsAppearance() async {
    let app = NSApplication.shared
    let original = app.appearance
    defer { app.appearance = original }

    app.appearance = NSAppearance(named: .aqua)
    var schemes = ContColorScheme.systemSchemes().makeAsyncIterator()
    #expect(await schemes.next() == .light)

    app.appearance = NSAppearance(named: .darkAqua)
    #expect(await schemes.next() == .dark)

    app.appearance = NSAppearance(named: .aqua)
    #expect(await schemes.next() == .light)
  }
#endif
