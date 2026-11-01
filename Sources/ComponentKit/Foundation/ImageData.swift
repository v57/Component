import SwiftUI

#if canImport(ImageIO)
  import ImageIO
#endif

// MARK: - A picture from bytes

/// PNG or JPEG bytes (a vault project's icon, a stored thumbnail) drawn once they have decoded off the main thread,
/// cut to `maxPixelSize` on their long side, with `placeholder` until then and when they aren't a picture. Bytes
/// already decoded at that size draw at once. The image is resizable: size it as an `Image`.
///
/// ```swift
/// KitImageData(data: attachment.data, maxPixelSize: 600).scaledToFit()
/// KitImageData(data: project.icon) { Avatar(name: project.name, kind: .thing) }
/// ```
///
/// For an icon in a badge, a tile or a welcome row, pass the bytes to the component instead
/// (`Avatar(name:imageData:)`, `KitAppIcon(data:)`, `RecentItem(_:imageData:)`): it decodes them the same way.
public struct KitImageData<Placeholder: View>: View {
  var data: Data?
  var maxPixelSize: Int?
  var placeholder: Placeholder

  /// The picture in `data`, `maxPixelSize` pixels at most on its long side (nil: its own size).
  public init(data: Data?, maxPixelSize: Int? = nil, @ViewBuilder placeholder: () -> Placeholder) {
    self.data = data
    self.maxPixelSize = maxPixelSize
    self.placeholder = placeholder()
  }

  public var body: some View {
    KitDecodedImage(data.map(KitImages.Source.data), maxPixelSize: maxPixelSize) { phase in
      if case .image(let image) = phase { image.resizable().interpolation(.high) } else { placeholder }
    }
  }
}

extension KitImageData where Placeholder == KitImageFilePlaceholder {
  /// The picture in `data` on the soft fill until it has decoded.
  public init(data: Data?, maxPixelSize: Int? = nil) {
    self.init(data: data, maxPixelSize: maxPixelSize) { KitImageFilePlaceholder() }
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
  var url: URL?
  var maxPixelSize: Int?
  var placeholder: Placeholder

  /// The picture at `url`, `maxPixelSize` pixels at most on its long side (nil: its own size).
  public init(url: URL?, maxPixelSize: Int? = nil, @ViewBuilder placeholder: () -> Placeholder) {
    self.url = url
    self.maxPixelSize = maxPixelSize
    self.placeholder = placeholder()
  }

  public var body: some View {
    KitDecodedImage(url.map(KitImages.Source.file), maxPixelSize: maxPixelSize) { phase in
      if case .image(let image) = phase { image.resizable().interpolation(.high) } else { placeholder }
    }
  }
}

extension KitImageFile where Placeholder == KitImageFilePlaceholder {
  /// The picture at `url` on the soft fill until it has loaded.
  public init(url: URL?, maxPixelSize: Int? = nil) {
    self.init(url: url, maxPixelSize: maxPixelSize) { KitImageFilePlaceholder() }
  }
}

/// `KitImageFile`'s and `KitImageData`'s placeholder: the soft fill where the picture will be.
public struct KitImageFilePlaceholder: View {
  public init() {}
  public var body: some View { Rectangle().fill(.kitFillSoft) }
}

// MARK: - Decoding

/// Where a decoded picture stands: still decoding, drawn, or not a picture (no source, or bytes that aren't one).
enum KitImagePhase {
  case loading
  case image(Image)
  case failed
}

/// The kit's one way to turn bytes or a file into an image: decoded off the main thread, the phase handed to
/// `content`. A picture already decoded (at that size) is drawn in the first frame, so rows that come back on
/// screen don't flash their placeholder.
struct KitDecodedImage<Content: View>: View {
  var source: KitImages.Source?
  var maxPixelSize: Int?
  @ViewBuilder var content: (KitImagePhase) -> Content
  @State private var loaded: (key: KitImages.Key, phase: KitImagePhase)?

  init(
    _ source: KitImages.Source?, maxPixelSize: Int? = nil, @ViewBuilder content: @escaping (KitImagePhase) -> Content
  ) {
    self.source = source
    self.maxPixelSize = maxPixelSize
    self.content = content
  }

  private var key: KitImages.Key? { source.map { KitImages.Key($0, maxPixelSize: maxPixelSize) } }

  private var phase: KitImagePhase {
    guard let key else { return .failed }
    if let loaded, loaded.key == key { return loaded.phase }
    return KitImages.cached(key).map(KitImagePhase.image) ?? .loading
  }

  var body: some View {
    content(phase)
      .task(id: key) {
        guard let key else { return }
        if let loaded, loaded.key == key { return }
        let image = await KitImages.load(key)
        guard !Task.isCancelled else { return }
        loaded = (key, image.map(KitImagePhase.image) ?? .failed)
      }
  }
}

/// Decodes pictures off the main thread and keeps them by source and size (dropped under memory pressure). On the
/// Apple platforms ImageIO decodes the pixels there too (`kCGImageSourceShouldCacheImmediately`), so nothing is left
/// for the first draw.
@MainActor
enum KitImages {
  enum Source: Hashable, Sendable {
    case data(Data)
    case file(URL)
  }

  /// A source at a size, as a cache key: bytes compare by contents (`NSData`'s hash reads only their start).
  final class Key: NSObject, @unchecked Sendable {
    let source: Source
    let maxPixelSize: Int?

    init(_ source: Source, maxPixelSize: Int?) {
      self.source = source
      self.maxPixelSize = maxPixelSize
    }

    override var hash: Int {
      switch source {
      case .data(let data): (data as NSData).hash &+ (maxPixelSize ?? 0)
      case .file(let url): url.hashValue &+ (maxPixelSize ?? 0)
      }
    }

    override func isEqual(_ object: Any?) -> Bool {
      guard let other = object as? Key else { return false }
      return other === self || (other.maxPixelSize == maxPixelSize && other.source == source)
    }
  }

  private final class Box: @unchecked Sendable {
    let image: Image
    init(_ image: Image) { self.image = image }
  }

  private static let cache = NSCache<Key, Box>()
  /// Decodes under way, so rows showing the same bytes wait for one decode.
  private static var pending: [Key: Task<Image?, Never>] = [:]

  static func cached(_ key: Key) -> Image? { cache.object(forKey: key)?.image }

  static func load(_ key: Key) async -> Image? {
    if let image = cached(key) { return image }
    if let task = pending[key] { return await task.value }
    let task = Task { await decode(key) }
    pending[key] = task
    let image = await task.value
    pending[key] = nil
    if let image { cache.setObject(Box(image), forKey: key) }
    return image
  }

  #if canImport(ImageIO)
    private struct Picture: @unchecked Sendable {
      let cgImage: CGImage?
    }

    private static func decode(_ key: Key) async -> Image? {
      let source = key.source, maxPixelSize = key.maxPixelSize
      let picture = await Task.detached(priority: .userInitiated) {
        Picture(cgImage: decodedImage(source, maxPixelSize: maxPixelSize))
      }.value
      return picture.cgImage.map { Image(decorative: $0, scale: 1) }
    }

    /// The picture's pixels, turned upright and cut to `maxPixelSize` (never enlarged).
    nonisolated private static func decodedImage(_ source: Source, maxPixelSize: Int?) -> CGImage? {
      let imageSource =
        switch source {
        case .data(let data): CGImageSourceCreateWithData(data as CFData, nil)
        case .file(let url): CGImageSourceCreateWithURL(url as CFURL, nil)
        }
      guard let imageSource, CGImageSourceGetCount(imageSource) > 0 else { return nil }
      let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
      let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
      let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
      let ownSize = max(width, height)
      let size = maxPixelSize.map { ownSize > 0 ? min($0, ownSize) : $0 } ?? ownSize
      guard size > 0 else {
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        return CGImageSourceCreateImageAtIndex(imageSource, 0, options)
      }
      let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceThumbnailMaxPixelSize: size,
      ]
      return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }
  #else
    /// v57/SwiftUI's backends (GdkPixbuf, WinUI, Android) decode on the main thread: only the read goes off it.
    private static func decode(_ key: Key) async -> Image? {
      let data: Data?
      switch key.source {
      case .data(let bytes): data = bytes
      case .file(let url): data = await Task.detached(priority: .userInitiated) { try? Data(contentsOf: url) }.value
      }
      return data.flatMap { Image(_platformData: $0) }
    }
  #endif
}
