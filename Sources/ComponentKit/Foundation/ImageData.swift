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
  public init?(data: Data) {
    #if canImport(AppKit)
      guard let image = NSImage(data: data) else { return nil }
      self.init(nsImage: image)
    #elseif canImport(UIKit)
      guard let image = UIImage(data: data) else { return nil }
      self.init(uiImage: image)
    #else
      return nil
    #endif
  }
}
