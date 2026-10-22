import SwiftUI

/// Cards of any height packed into columns of one unit width: each card goes where the columns are shortest, a card
/// may span several columns (`.kitGridSpan(2)`), and a wider container adds columns instead of blank space. For an
/// overview of places of different sizes (Hub's All Hubs: ten hubs on one screen, three columns beside the sidebar,
/// one on iPhone).
///
/// ```swift
/// ScrollView {
///   KitPackedGrid(unit: 320) {
///     ForEach(hubs) { hub in
///       HubCard(hub).kitGridSpan(hub.isBusy ? 2 : 1)
///     }
///   }
///   .padding(KitMetrics.gutter)
/// }
/// ```
///
/// Cards keep their order as far as the columns allow: a card never goes above one placed before it in the same
/// column.
public struct KitPackedGrid: Layout {
  /// The narrowest a column gets: the container fits as many as it can, then widens them to fill it.
  public var unit: CGFloat
  /// The gap between columns and between the cards in a column (12, the canvas's gap between packed cards).
  public var spacing: CGFloat
  /// The most columns, however wide the container.
  public var maxColumns: Int

  public init(unit: CGFloat = 320, spacing: CGFloat = 12, maxColumns: Int = 6) {
    self.unit = unit
    self.spacing = spacing
    self.maxColumns = max(1, maxColumns)
  }

  /// How many columns fit in `width`.
  public func columns(for width: CGFloat) -> Int {
    guard width.isFinite, width > 0 else { return 1 }
    return min(maxColumns, max(1, Int((width + spacing) / (unit + spacing))))
  }

  public struct Cache {
    var width: CGFloat = -1
    var frames: [CGRect] = []
    var height: CGFloat = 0
  }

  public func makeCache(subviews: Subviews) -> Cache { Cache() }

  public func updateCache(_ cache: inout Cache, subviews: Subviews) {
    cache = Cache()
  }

  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
    let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? unit
    pack(width: width, subviews: subviews, cache: &cache)
    return CGSize(width: width, height: cache.height)
  }

  public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
    pack(width: bounds.width, subviews: subviews, cache: &cache)
    for (index, subview) in subviews.enumerated() where index < cache.frames.count {
      let frame = cache.frames[index]
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
        proposal: ProposedViewSize(width: frame.width, height: frame.height))
    }
  }

  private func pack(width: CGFloat, subviews: Subviews, cache: inout Cache) {
    guard cache.width != width || cache.frames.count != subviews.count else { return }
    let count = columns(for: width)
    let column = (width - spacing * CGFloat(count - 1)) / CGFloat(count)
    var heights = [CGFloat](repeating: 0, count: count)
    var frames = [CGRect]()
    frames.reserveCapacity(subviews.count)
    for subview in subviews {
      let span = min(count, max(1, subview[KitGridSpanKey.self]))
      // The run of `span` columns whose tallest is shortest; the leftmost on a tie
      var start = 0
      var top = CGFloat.infinity
      for first in 0...(count - span) {
        let run = heights[first..<(first + span)].max() ?? 0
        if run < top - 0.5 {
          top = run
          start = first
        }
      }
      let cardWidth = column * CGFloat(span) + spacing * CGFloat(span - 1)
      let size = subview.sizeThatFits(ProposedViewSize(width: cardWidth, height: nil))
      let frame = CGRect(x: CGFloat(start) * (column + spacing), y: top, width: cardWidth, height: size.height)
      frames.append(frame)
      for index in start..<(start + span) {
        heights[index] = frame.maxY + spacing
      }
    }
    cache.width = width
    cache.frames = frames
    cache.height = max(0, (heights.max() ?? 0) - spacing)
  }
}

private struct KitGridSpanKey: LayoutValueKey {
  static let defaultValue = 1
}

extension View {
  /// How many columns of a `KitPackedGrid` this card spans (1 by default; fewer when the grid has fewer columns).
  ///
  /// ```swift
  /// HubCard(hub).kitGridSpan(2)
  /// ```
  public func kitGridSpan(_ columns: Int) -> some View {
    layoutValue(key: KitGridSpanKey.self, value: columns)
  }
}
