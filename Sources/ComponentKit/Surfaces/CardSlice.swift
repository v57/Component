import SwiftUI

// One card drawn across many lazy rows: each row draws its slice of the card (the top corners on the first, the
// bottom ones on the last, the sides on all), so a `LazyVStack` of thousands of commits still reads as one card and
// only the rows on screen exist.

/// Where a row sits in a card spread over rows.
public enum KitCardSlice: Hashable, Sendable {
  case only, first, middle, last

  /// The slice for row `index` of `count`.
  public init(_ index: Int, of count: Int) {
    switch (index, count) {
    case (_, ...1): self = .only
    case (0, _): self = .first
    case (count - 1, _): self = .last
    default: self = .middle
    }
  }

  var hasTop: Bool { self == .only || self == .first }
  var hasBottom: Bool { self == .only || self == .last }
}

extension View {
  /// Draws this row's slice of a card that spans many rows (in a `LazyVStack` with no spacing): the card's ground and
  /// edge, with the corners only on the first and last rows and `KitMetrics.cardPadding` inside its ends.
  ///
  /// ```swift
  /// LazyVStack(spacing: 0) {
  ///   ForEach(Array(commits.enumerated()), id: \.element.id) { index, commit in
  ///     CommitRow(commit).kitCardSlice(index, of: commits.count)
  ///   }
  /// }
  /// ```
  public func kitCardSlice(_ index: Int, of count: Int, cornerRadius: CGFloat = KitMetrics.radiusCard) -> some View {
    modifier(CardSliceModifier(slice: KitCardSlice(index, of: count), cornerRadius: cornerRadius))
  }

  /// Draws this row's `slice` of a card that spans many rows.
  public func kitCardSlice(_ slice: KitCardSlice, cornerRadius: CGFloat = KitMetrics.radiusCard) -> some View {
    modifier(CardSliceModifier(slice: slice, cornerRadius: cornerRadius))
  }
}

struct CardSliceModifier: ViewModifier {
  let slice: KitCardSlice
  let cornerRadius: CGFloat
  /// How far the slice runs past the row's top and bottom where the card goes on: over a list's row insets.
  var bleed: CGFloat = 0

  func body(content: Content) -> some View {
    let pad = KitMetrics.cardPadding
    content
      .padding(.horizontal, pad)
      .padding(.top, slice.hasTop ? pad : 0)
      .padding(.bottom, slice.hasBottom ? pad : 0)
      .background {
        background
          .padding(.top, slice.hasTop ? 0 : -bleed)
          .padding(.bottom, slice.hasBottom ? 0 : -bleed)
      }
  }

  private var background: some View {
    Color.clear
      .background {
        // The whole card, run past the ends this row doesn't have and cut there, so its edge and shadow show only
        // where they belong.
        SurfaceShape(surface: .card, cornerRadius: cornerRadius)
          .padding(.top, slice.hasTop ? 0 : -(cornerRadius + 4))
          .padding(.bottom, slice.hasBottom ? 0 : -(cornerRadius + 4))
          .mask {
            Rectangle()
              .padding(.horizontal, -4)
              .padding(.top, slice.hasTop ? -4 : 0)
              .padding(.bottom, slice.hasBottom ? -4 : 0)
          }
      }
  }
}

/// A card over lazy rows: `ForEach` with each row's slice drawn for you, in a `LazyVStack(spacing: 0)` of your own
/// (the stack's spacing would open gaps in the card; `spacing` here sets the gap between rows inside it).
///
/// ```swift
/// ScrollView {
///   LazyVStack(spacing: 0) {
///     LazyCard(commits) { commit in CommitRow(commit) }
///   }
///   .padding(KitMetrics.gutter)
/// }
/// ```
public struct LazyCard<Data: RandomAccessCollection, ID: Hashable, Row: View>: View {
  let items: [ContIndexed<Data.Element, ID>]
  let spacing: CGFloat
  let row: (Data.Element) -> Row

  public init(
    _ data: Data, id: KeyPath<Data.Element, ID>, spacing: CGFloat = 2,
    @ViewBuilder row: @escaping (Data.Element) -> Row
  ) {
    items = data.enumerated().map { ContIndexed(id: $0.element[keyPath: id], index: $0.offset, element: $0.element) }
    self.spacing = spacing
    self.row = row
  }

  public var body: some View {
    let count = items.count
    ForEach(items) { item in
      row(item.element)
        .padding(.bottom, item.index < count - 1 ? spacing : 0)
        .kitCardSlice(item.index, of: count)
    }
  }
}

extension LazyCard where Data.Element: Identifiable, ID == Data.Element.ID {
  /// A card over identifiable rows.
  public init(_ data: Data, spacing: CGFloat = 2, @ViewBuilder row: @escaping (Data.Element) -> Row) {
    self.init(data, id: \.id, spacing: spacing, row: row)
  }
}

#Preview("Lazy card") {
  ScrollView {
    LazyVStack(spacing: 0) {
      LazyCard(Array(1...40), id: \.self) { number in
        Text("Commit \(number)").padding(.horizontal, 6).frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
      }
    }
    .padding(KitMetrics.gutter)
  }
  .frame(width: 320, height: 400)
  .background(.kitPanel)
  .componentKit()
}
