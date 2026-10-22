import SwiftUI

/// The kit's sizes, so components agree on them. Touch idioms use the larger value; on Apple TV every size is twice
/// the Mac's.
public enum KitMetrics {
  /// The fixed sizes below are the Mac's, doubled on Apple TV (`KitIdiom.tv`).
  #if os(tvOS)
    private static let scale: CGFloat = 2
  #else
    private static let scale: CGFloat = 1
  #endif

  /// Corner radii.
  public static let radiusXS: CGFloat = 5 * scale
  public static let radiusSmall: CGFloat = 7 * scale
  public static let radius: CGFloat = 8 * scale
  public static let radiusLarge: CGFloat = 10 * scale
  /// Cards and card sections.
  public static let radiusCard: CGFloat = 12 * scale
  public static let radiusXL: CGFloat = 14 * scale
  public static let radiusWindow: CGFloat = 16 * scale
  /// Sheets, popovers, palettes: concentric with a card 8pt inside (12 + 8).
  public static let radiusOverlay: CGFloat = 20 * scale

  /// The gutter between rounded shapes, and between them and the window edge: rounded views never touch.
  public static let gutter: CGFloat = 8 * scale
  /// A card's inner padding.
  public static let cardPadding: CGFloat = 6 * scale

  /// Control heights: in cards and rows, in headers and banners, the big actions.
  public static let controlSmall: CGFloat = 28 * scale
  public static let controlRegular: CGFloat = 30 * scale
  public static let controlLarge: CGFloat = 34 * scale

  /// Rows: one line, with a subtitle, a table row.
  public static func row(_ idiom: KitIdiom) -> CGFloat { idiom.size(32, touch: 44) }
  public static func twoLineRow(_ idiom: KitIdiom) -> CGFloat { idiom.size(44, touch: 56) }
  public static func tableRow(_ idiom: KitIdiom) -> CGFloat { idiom.size(34, touch: 44) }

  /// A sidebar row's icon tile (and a live icon in its place): 18pt on the Mac, 28 on iPad, 30 on iPhone, 36 on
  /// Apple TV.
  ///
  /// ```swift
  /// LiveIcon(systemImage: "terminal", status: session.status, size: KitMetrics.rowTile(idiom))
  /// ```
  public static func rowTile(_ idiom: KitIdiom) -> CGFloat { idiom.size(18, pad: 28, phone: 30) }

  public static let sidebarWidth: CGFloat = 240 * scale
  /// The narrowest a `KitSidebar` gets (its bottom bar's search, status and actions still fit): 200pt on the Mac,
  /// 260 on iPad, 400 on Apple TV; iPhone fills the screen.
  public static func sidebarMinWidth(_ idiom: KitIdiom) -> CGFloat { idiom.size(200, pad: 260, phone: 0) }
  public static let inspectorWidth: CGFloat = 320 * scale
  public static let titlebarHeight: CGFloat = 52 * scale
}
