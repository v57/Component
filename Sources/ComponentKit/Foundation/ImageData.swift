import SwiftUI

#if canImport(ImageIO)
  import ImageIO
#endif
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

// MARK: - A picture from a file

/// A picture file (PNG, JPEG, HEIC…) drawn once it has loaded off the main thread, cut to `maxPixelSize` on its long
/// side (a thumbnail), with `placeholder` until then and when the file isn't a picture. It loads again when `url`
/// changes; pictures already loaded at that size come back at once. The image is resizable: size it as an `Image`.
///
/// ```swift
/// KitImageFile(url: screenshot.url, maxPixelSize: 900)
///   .scaledToFit()
///   .clipShape(RoundedRectangle(cornerRadius: KitMetrics.radius, style: .continuous))
/// KitImageFile(url: picture.url) { ProgressView() }
/// ```
public struct KitImageFile<Placeholder: View>: View {
  var url: URL
  var maxPixelSize: Int?
  var placeholder: Placeholder
  @State private var loaded: (url: URL, image: Image)?

  /// The picture at `url`, `maxPixelSize` pixels at most on its long side (nil: its own size).
  public init(url: URL, maxPixelSize: Int? = nil, @ViewBuilder placeholder: () -> Placeholder) {
    self.url = url
    self.maxPixelSize = maxPixelSize
    self.placeholder = placeholder()
  }

  public var body: some View {
    Group {
      if let image = loaded?.url == url ? loaded?.image : KitImageFiles.cached(url, maxPixelSize: maxPixelSize) {
        image.resizable().interpolation(.high)
      } else {
        placeholder
      }
    }
    .task(id: url) {
      if let image = await KitImageFiles.load(url, maxPixelSize: maxPixelSize) { loaded = (url, image) }
    }
  }
}

extension KitImageFile where Placeholder == KitImageFilePlaceholder {
  /// The picture at `url` on the soft fill until it has loaded.
  public init(url: URL, maxPixelSize: Int? = nil) {
    self.init(url: url, maxPixelSize: maxPixelSize) { KitImageFilePlaceholder() }
  }
}

/// `KitImageFile`'s placeholder: the soft fill where the picture will be.
public struct KitImageFilePlaceholder: View {
  public init() {}
  public var body: some View { Rectangle().fill(.kitFillSoft) }
}

/// Loads picture files off the main thread and keeps them by file and size (dropped under memory pressure).
@MainActor
enum KitImageFiles {
  private final class Box: @unchecked Sendable {
    let image: Image
    init(_ image: Image) { self.image = image }
  }

  private static let cache = NSCache<NSString, Box>()

  private static func key(_ url: URL, _ maxPixelSize: Int?) -> NSString {
    "\(url.absoluteString)|\(maxPixelSize ?? 0)" as NSString
  }

  static func cached(_ url: URL, maxPixelSize: Int?) -> Image? {
    cache.object(forKey: key(url, maxPixelSize))?.image
  }

  static func load(_ url: URL, maxPixelSize: Int?) async -> Image? {
    if let image = cached(url, maxPixelSize: maxPixelSize) { return image }
    #if canImport(ImageIO)
      let picture = await Task.detached(priority: .utility) { Picture(decode(url, maxPixelSize: maxPixelSize)) }.value
      guard let cgImage = picture.cgImage else { return nil }
      let image = Image(decorative: cgImage, scale: 1)
    #else
      // v57/SwiftUI's backends decode on the main thread: only the read goes off it.
      let data = await Task.detached(priority: .utility) { try? Data(contentsOf: url) }.value
      guard let data, let image = Image(data: data) else { return nil }
    #endif
    cache.setObject(Box(image), forKey: key(url, maxPixelSize))
    return image
  }

  #if canImport(ImageIO)
    private struct Picture: @unchecked Sendable {
      let cgImage: CGImage?
      init(_ cgImage: CGImage?) { self.cgImage = cgImage }
    }

    /// The picture, as a thumbnail when `maxPixelSize` is set (turned upright).
    nonisolated private static func decode(_ url: URL, maxPixelSize: Int?) -> CGImage? {
      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
      guard let maxPixelSize else { return CGImageSourceCreateImageAtIndex(source, 0, nil) }
      let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      ]
      return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
  #endif
}
