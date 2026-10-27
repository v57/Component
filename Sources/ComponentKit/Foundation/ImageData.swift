import SwiftUI

#if canImport(AppKit)
  import AppKit
#elseif canImport(UIKit)
  import UIKit
#endif

extension Image {
  /// An image from PNG or JPEG bytes, such as a stored thumbnail (a vault project's icon); nil when they aren't one.
  ///
  /// ```swift
  /// if let icon = project.icon.flatMap(Image.init(data:)) { Avatar(name: project.name, image: icon, kind: .thing) }
  /// ```
  ///
  /// The same bytes give the same image: each is decoded once, and a view drawn again (a row in an animation) keeps
  /// its picture instead of cross-fading to a fresh copy.
  public init?(data: Data) {
    #if canImport(AppKit)
      guard let image = DecodedImages.image(for: data, decode: NSImage.init(data:)) else { return nil }
      self.init(nsImage: image)
    #elseif canImport(UIKit)
      guard let image = DecodedImages.image(for: data, decode: UIImage.init(data:)) else { return nil }
      self.init(uiImage: image)
    #else
      // Decoded by v57/SwiftUI's backend (GdkPixbuf on Linux), on the main thread where views are built.
      guard Thread.isMainThread,
        let box = DecodedImages.image(
          for: data, decode: { data in MainActor.assumeIsolated { Image(_platformData: data).map(ImageBox.init) } })
      else { return nil }
      self = box.image
    #endif
  }
}

#if !canImport(AppKit) && !canImport(UIKit)
  /// A decoded image as a cache entry.
  private final class ImageBox: @unchecked Sendable {
    let image: Image
    init(_ image: Image) { self.image = image }
  }
#endif

/// Decoded pictures by their bytes (`NSData` compares contents); the cache drops them under memory pressure.
private enum DecodedImages {
  nonisolated(unsafe) private static let cache = NSCache<NSData, AnyObject>()

  static func image<Picture: AnyObject>(for data: Data, decode: (Data) -> Picture?) -> Picture? {
    let key = data as NSData
    if let image = cache.object(forKey: key) as? Picture { return image }
    guard let image = decode(data) else { return nil }
    cache.setObject(image, forKey: key)
    return image
  }
}
