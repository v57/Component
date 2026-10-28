import SwiftUI

/// The running app's own icon at a size, as the welcome draws it: on the Mac its artwork (not Apple's grid
/// margin around it) fills `size`; iOS masks it to the rounded square. Without an icon (a test host, Windows) it is
/// the app name's first letter on an accent tile. For an app's own welcome in a pane, an About box or an empty
/// window.
///
/// ```swift
/// VStack(spacing: 10) {
///   KitAppIcon(size: 72)
///   Text("Database").kitFont(.largeTitle)
/// }
/// ```
public struct KitAppIcon: View {
  var size: CGFloat

  public init(size: CGFloat = 64) {
    self.size = size
  }

  public var body: some View {
    Group {
      if let icon = DataPlatform.appIcon {
        let drawn = DataPlatform.appIconArtwork < 1 ? size / DataPlatform.appIconArtwork : size
        #if os(macOS)
          icon.resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            .frame(width: drawn, height: drawn)
        #else
          icon.resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            .frame(width: drawn, height: drawn)
            .clipShape(RoundedRectangle(cornerRadius: drawn * 0.225, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
        #endif
      } else {
        Tile(letters: String(DataPlatform.appName.prefix(1)), hue: .accent, size: size, style: .solid)
          .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}
