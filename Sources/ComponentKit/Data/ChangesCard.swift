import SwiftUI

/// The edits that wait for review, as a card under the grid: a rich header (the pencil tile, "Changes" and the bare
/// count, what they apply to), Discard All and the primary Review and Save, then a row per edit with its Undo.
/// Nothing is saved until the app's `review` runs.
///
/// ```swift
/// ChangesCard(count: 3, meta: ["orders on Shop", "nothing is saved until you review"],
///             discardAll: { pending.removeAll() }, review: { showReview = true }) {
///   ChangeRow(.edited, title: "10236", field: "status", old: "shipped", new: "refunded") { undo(10236) }
///   ChangeRow(.deleted, title: "10235", field: "row") { undo(10235) }
/// }
/// ```
public struct ChangesCard<Meta: View, Rows: View>: View {
  var title: String
  var count: Int
  var systemImage: String
  var reviewTitle: String
  var discardAll: (() -> Void)?
  var review: (() -> Void)?
  var meta: Meta
  var rows: Rows

  public init(
    _ title: String = "Changes", count: Int, systemImage: String = "pencil", reviewTitle: String = "Review and Save",
    discardAll: (() -> Void)? = nil, review: (() -> Void)? = nil, @ViewBuilder meta: () -> Meta,
    @ViewBuilder rows: () -> Rows
  ) {
    self.title = title
    self.count = count
    self.systemImage = systemImage
    self.reviewTitle = reviewTitle
    self.discardAll = discardAll
    self.review = review
    self.meta = meta()
    self.rows = rows()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      // The buttons go under the title where the card is narrow (an iPhone).
      ViewThatFits(in: .horizontal) {
        header { buttons }
        VStack(alignment: .trailing, spacing: 4) {
          header { EmptyView() }
          buttons
        }
      }
      rows
    }
    .kitCard()
  }

  private func header<Accessory: View>(@ViewBuilder accessory: () -> Accessory) -> some View {
    RichHeader(
      Text(title) + Text(count > 0 ? "  \(count)" : "").foregroundStyle(Hue.orange.text),
      icon: { Tile(systemImage: systemImage, hue: .orange, size: 24) },
      meta: { meta },
      accessory: accessory)
  }

  private var buttons: some View {
    HStack(spacing: 4) {
      if let discardAll {
        Button("Discard All", action: discardAll).buttonStyle(.kitPlain)
      }
      if let review {
        Button(reviewTitle, action: review).buttonStyle(.kitPrimary)
      }
    }
    .controlSize(.small)
    .disabled(count == 0)
  }
}

extension ChangesCard where Meta == MetaLine {
  /// A changes card whose meta is a line of parts joined with " · ".
  public init(
    _ title: String = "Changes", count: Int, meta: [String], systemImage: String = "pencil",
    reviewTitle: String = "Review and Save", discardAll: (() -> Void)? = nil, review: (() -> Void)? = nil,
    @ViewBuilder rows: () -> Rows
  ) {
    self.init(
      title, count: count, systemImage: systemImage, reviewTitle: reviewTitle, discardAll: discardAll, review: review,
      meta: { MetaLine(meta) }, rows: rows)
  }
}

/// One pending edit in a `ChangesCard`: the kind's tile and name, which row and field, what changed, and Undo.
///
/// ```swift
/// ChangeRow(.edited, title: "10236", field: "status", old: "shipped", new: "refunded") { undo() }
/// ChangeRow(.inserted, title: "id 41", field: "row", undo: undo) { Text("59.00, created now()") }
/// ```
public struct ChangeRow<Change: View>: View {
  var kind: KitGridRowState
  var title: String
  var field: String?
  var undo: (() -> Void)?
  var change: Change
  @Environment(\.kitIdiom) private var idiom
  @State private var isHovered = false

  public init(
    _ kind: KitGridRowState, title: String, field: String? = nil, undo: (() -> Void)? = nil,
    @ViewBuilder change: () -> Change
  ) {
    self.kind = kind
    self.title = title
    self.field = field
    self.undo = undo
    self.change = change()
  }

  public var body: some View {
    // One line where it fits; else the change goes under the row's names (an iPhone).
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) {
        names
        changeView
        undoButton
      }
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 10) {
          names
          Spacer(minLength: 0)
          undoButton.fixedSize()
        }
        changeView.padding(.leading, 28)
      }
      .padding(.vertical, 4)
    }
    .padding(.leading, 8)
    .padding(.trailing, 2)
    .frame(minHeight: KitMetrics.tableRow(idiom))
    .background {
      RoundedRectangle(cornerRadius: KitMetrics.radius, style: .continuous)
        .fill(isHovered ? AnyShapeStyle(.kitHover) : AnyShapeStyle(Color.clear))
    }
    .onHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
    .accessibilityElement(children: .combine)
  }
}

extension ChangeRow {
  @ViewBuilder fileprivate var names: some View {
    Tile(systemImage: kind.systemImage, hue: kind.hue, size: 18)
    Text(kind.title)
      .kitFont(.headline)
      .lineLimit(1)
      .frame(width: idiom.isTouch ? 76 : 58, alignment: .leading)
    Text(title)
      .monospacedDigit()
      .lineLimit(1)
      .frame(minWidth: 48, alignment: .leading)
      .fixedSize()
    if let field {
      Text(field)
        .foregroundStyle(.kitSecondary)
        .lineLimit(1)
        .frame(minWidth: 40, alignment: .leading)
        .fixedSize()
    }
  }

  fileprivate var changeView: some View {
    HStack(spacing: 6) { change }
      .lineLimit(1)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder fileprivate var undoButton: some View {
    if let undo {
      Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
        .buttonStyle(.kitPlain)
        .controlSize(.small)
    }
  }
}

extension ChangeRow where Change == ChangeValues {
  /// An edit from `old` to `new` (either may be `nil`: a deleted row shows only what it was, a new one what it is).
  public init(
    _ kind: KitGridRowState, title: String, field: String? = nil, old: String? = nil, new: String? = nil,
    undo: (() -> Void)? = nil
  ) {
    self.init(kind, title: title, field: field, undo: undo) { ChangeValues(old: old, new: new) }
  }
}

/// What an edit changed: the old value struck through, an arrow, the new one in a chip.
public struct ChangeValues: View {
  var old: String?
  var new: String?

  public init(old: String?, new: String?) {
    self.old = old
    self.new = new
  }

  public var body: some View {
    HStack(spacing: 6) {
      if let old {
        Text(old)
          .strikethrough()
          .foregroundStyle(.kitSecondary)
      }
      if old != nil, new != nil {
        Image(systemName: "arrow.right")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.kitSecondary)
      }
      if let new { Chip(new) }
    }
    .kitFont(.callout)
  }
}

#Preview("Changes") {
  ChangesCard(count: 3, meta: ["orders on Shop", "nothing is saved until you review"], discardAll: {}, review: {}) {
    ChangeRow(.edited, title: "10236", field: "status", old: "shipped", new: "refunded") {}
    ChangeRow(.deleted, title: "10235", field: "row", old: "cancelled, 39.00, Lisbon") {}
    ChangeRow(.inserted, title: "id 41", field: "row", new: "pending, 59.00") {}
  }
  .frame(width: 640)
  .padding()
  .componentKit()
}
