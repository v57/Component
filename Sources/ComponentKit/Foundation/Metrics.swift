import SwiftUI

/// The kit's sizes, so components agree on them. Touch idioms use the larger value.
public enum KitMetrics {
  /// Corner radii.
  public static let radiusXS: CGFloat = 5
  public static let radiusSmall: CGFloat = 7
  public static let radius: CGFloat = 8
  public static let radiusLarge: CGFloat = 10
  /// Cards and card sections.
  public static let radiusCard: CGFloat = 12
  public static let radiusXL: CGFloat = 14
  public static let radiusWindow: CGFloat = 16
  /// Sheets, popovers, palettes: concentric with a card 8pt inside (12 + 8).
  public static let radiusOverlay: CGFloat = 20

  /// The gutter between rounded shapes, and between them and the window edge: rounded views never touch.
  public static let gutter: CGFloat = 8
  /// A card's inner padding.
  public static let cardPadding: CGFloat = 6

  /// Control heights: in cards and rows, in headers and banners, the big actions.
  public static let controlSmall: CGFloat = 28
  public static let controlRegular: CGFloat = 30
  public static let controlLarge: CGFloat = 34

  /// Rows: one line, with a subtitle, a table row.
  public static func row(_ idiom: KitIdiom) -> CGFloat { idiom.isTouch ? 44 : 32 }
  public static func twoLineRow(_ idiom: KitIdiom) -> CGFloat { idiom.isTouch ? 56 : 44 }
  public static func tableRow(_ idiom: KitIdiom) -> CGFloat { idiom.isTouch ? 44 : 34 }

  /// A sidebar row's icon tile (and a live icon in its place): 18pt on the Mac, 28 on iPad, 30 on iPhone.
  ///
  /// ```swift
  /// LiveIcon(systemImage: "terminal", status: session.status, size: KitMetrics.rowTile(idiom))
  /// ```
  public static func rowTile(_ idiom: KitIdiom) -> CGFloat { idiom == .phone ? 30 : idiom == .pad ? 28 : 18 }

  public static let sidebarWidth: CGFloat = 240
  public static let inspectorWidth: CGFloat = 320
  public static let titlebarHeight: CGFloat = 52
}
