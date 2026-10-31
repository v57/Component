import SwiftUI

/// The running app's own icon at a size, as the welcome draws it: on the Mac its artwork (not Apple's grid
/// margin around it) fills `size`; iOS masks it to the rounded square. Without an icon (a test host, Windows) it is
/// the app name's first letter on an accent tile. For an app's own welcome in a pane, an About box or an empty
/// window. `KitAppIcon(image:)` and `KitAppIcon(data:)` draw any other app's (a project's) icon the same way.
///
/// ```swift
/// VStack(spacing: 10) {
///   KitAppIcon(size: 72)
///   Text("Database").kitFont(.largeTitle)
/// }
/// ```
public struct KitAppIcon: View {
  enum Source {
    case running
    case image(Image?, isShaped: Bool)
  }

  var size: CGFloat
  var source: Source = .running

  public init(size: CGFloat = 64) {
    self.size = size
  }

  /// Any app's icon from a picture: square artwork clipped to the app icon's squircle with its hairline and shadow
  /// (a project's icon render, a vault project's PNG). `isShaped` draws a picture that already has its shape and
  /// margin (a Mac app's icon file, `KitDesktop.icon(forFile:)`) as it is. Without a picture it is a quiet squircle
  /// with a dashed app glyph.
  ///
  /// ```swift
  /// KitAppIcon(image: project.iconImage, size: 28)
  /// KitAppIcon(image: KitDesktop.icon(forFile: app.path), size: 18, isShaped: true)
  /// ```
  public init(image: Image?, size: CGFloat = 64, isShaped: Bool = false) {
    self.size = size
    self.source = .image(image, isShaped: isShaped)
  }

  /// Any app's icon from PNG or JPEG bytes, as `init(image:size:isShaped:)` draws it (bytes that aren't a picture
  /// draw the quiet squircle).
  ///
  /// ```swift
  /// KitAppIcon(data: facts.icon.preview, size: 96)
  /// ```
  public init(data: Data?, size: CGFloat = 64, isShaped: Bool = false) {
    self.init(image: data.flatMap(Image.init(data:)), size: size, isShaped: isShaped)
  }

  public var body: some View {
    switch source {
    case .running: running
    case .image(let image, let isShaped): picture(image, isShaped: isShaped)
    }
  }

  @ViewBuilder
  private func picture(_ image: Image?, isShaped: Bool) -> some View {
    Group {
      if let image, isShaped {
        image.resizable().interpolation(.high).aspectRatio(contentMode: .fit)
      } else if let image {
        Avatar(name: "", image: image, kind: .app, size: size)
      } else {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        shape.fill(Hue.gray.soft())
          .overlay {
            Image(systemName: "app.dashed").font(.system(size: size * 0.45, weight: .medium)).foregroundStyle(Hue.gray.fill)
          }
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }

  private var running: some View {
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
