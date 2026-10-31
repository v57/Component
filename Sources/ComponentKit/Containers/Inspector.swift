import SwiftUI

// The inspector (the Inspectors board, pick B): the sidebar mirrored. It stands on the panel ground; its header is the
// rich title; each section is a card with the rich header; rows are flat key–value lines; the actions sit in one card
// bar at the end.

/// The trailing detail pane: the panel ground, 320pt wide (340 on iPad), its sections as cards 10pt in from its edges,
/// scrolling with its bottom edge faded while content runs on under it.
///
/// ```swift
/// KitInspector {
///   InspectorHeader("Order 10234", meta: ["Row in orders", "7 fields"], systemImage: "tablecells", hue: .blue)
///   KitSection("Fields", meta: "7 fields", systemImage: "list.bullet") {
///     InspectorRow("id", value: "10234")
///     InspectorRow("status", value: "shipped")
///   }
///   ActionBar {
///     Button("Copy as JSON", systemImage: "doc.on.doc") { … }
///     Button("Delete Row…", systemImage: "trash", role: .destructive) { … }
///   }
/// }
/// ```
public struct KitInspector<Content: View>: View {
  var width: CGFloat?
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom

  /// An inspector `width` wide; pass `nil` to fill what its container gives (inside a `ResizableSplit`).
  public init(width: CGFloat? = KitMetrics.inspectorWidth, @ViewBuilder content: () -> Content) {
    self.width = width
    self.content = content()
  }

  public var body: some View {
    let inset: CGFloat = idiom.size(10, pad: 12, phone: 16)
    ContEdgeScroll {
      VStack(alignment: .leading, spacing: idiom.size(10, pad: 12, phone: 16)) { content }
        .padding(EdgeInsets(top: idiom.size(14, touch: 16), leading: inset, bottom: inset, trailing: inset))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(width: width.map { idiom == .pad && $0 == KitMetrics.inspectorWidth ? 340 : $0 })
    .kitPane(.secondary)
  }
}

/// The inspector's header: the rich title at its size (a 30pt tile, a 15pt name that wraps), one meta line with
/// status, then tags (chips) wrapped under it.
///
/// ```swift
/// InspectorHeader("Sharing: Shared a trip as a file", meta: ["330c484", "1 file changed"], systemImage: "circle.dashed") {
///   Chip("v1.1.0", systemImage: "tag")
/// }
/// ```
public struct InspectorHeader<Tags: View>: View {
  var title: String
  var meta: [String]
  var systemImage: String
  var hue: Hue
  var status: WorkStatus
  @ViewBuilder var tags: Tags
  @Environment(\.kitIdiom) private var idiom

  public init(
    _ title: some StringProtocol, meta: [String] = [], systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, @ViewBuilder tags: () -> Tags
  ) {
    self.title = String(title)
    self.meta = meta
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
    self.tags = tags()
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 10) {
      LiveIcon(systemImage: systemImage, hue: hue, status: status, size: idiom.size(30, pad: 36, phone: 40))
        .padding(.top, 1)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .kitFont(idiom.isTouch ? .title2 : .title3)
          .fixedSize(horizontal: false, vertical: true)
        if !meta.isEmpty {
          MetaLine(meta).kitFont(.caption).lineLimit(2)
        }
        if Tags.self != EmptyView.self {
          KitFlowLayout(spacing: 6, lineSpacing: 6) { tags }
            .padding(.top, 4)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(EdgeInsets(top: 0, leading: 6, bottom: 4, trailing: 6))
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }
}

extension InspectorHeader where Tags == EmptyView {
  /// A header with no tags.
  public init(
    _ title: some StringProtocol, meta: [String] = [], systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle
  ) {
    self.init(title, meta: meta, systemImage: systemImage, hue: hue, status: status) { EmptyView() }
  }
}

/// A key–value line inside an inspector section: the key in the secondary colour, the value at the end. Hovering
/// washes the line and shows a Copy button; the context menu copies too.
///
/// ```swift
/// InspectorRow("created_at", value: "2026-10-08 19:26")
/// InspectorRow("total") { Text("$128.00").kitFont(.mono) }
/// ```
///
/// `.wraps()` lets a long value run over several lines instead of one cut line (a message, a nested object): the key
/// stays at the top, at most 40% of the row, and the row is as tall as the value draws, at any width.
///
/// ```swift
/// InspectorRow("summary", value: payload.summary).wraps()
/// InspectorRow("result") { Text(describe(result)).kitFont(.monoSmall) }.wraps(alignment: .leading)
/// ```
public struct InspectorRow<Value: View>: View {
  var key: String
  var copyText: String?
  var wrapAlignment: HorizontalAlignment?
  @ViewBuilder var value: Value
  @State private var isHovered = false
  @Environment(\.kitIdiom) private var idiom

  /// A row with any value view; `copyText` is what Copy puts on the pasteboard (none: no Copy).
  public init(_ key: String, copyText: String? = nil, @ViewBuilder value: () -> Value) {
    self.key = key
    self.copyText = copyText
    self.value = value()
  }

  /// Lets the value wrap over as many lines as it needs, `alignment` within its column (`.trailing`, as a one-line
  /// value sits, or `.leading` for a block of text).
  public func wraps(alignment: HorizontalAlignment = .trailing) -> Self {
    var row = self
    row.wrapAlignment = alignment
    return row
  }

  public var body: some View {
    HStack(alignment: wrapAlignment == nil ? .center : .top, spacing: 8) {
      if let wrapAlignment {
        ContKeyValueLayout(spacing: 12) {
          Text(key)
            .kitFont(.body)
            .foregroundStyle(.kitSecondary)
            .fixedSize(horizontal: false, vertical: true)
          value
            .kitFont(.body)
            .multilineTextAlignment(wrapAlignment == .leading ? .leading : wrapAlignment == .center ? .center : .trailing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: wrapAlignment, vertical: .top))
        }
      } else {
        Text(key)
          .kitFont(.body)
          .foregroundStyle(.kitSecondary)
          .lineLimit(1)
          .layoutPriority(1)
        Spacer(minLength: 8)
        value
          .kitFont(.body)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      if let copyText, isHovered, !idiom.isTouch {
        Button {
          ContPlatform.copy(copyText)
        } label: {
          Image(systemName: "doc.on.doc")
            .font(.system(size: 10, weight: .medium))
            .frame(width: 20, height: 20)
            .background { RoundedRectangle(cornerRadius: KitMetrics.radiusXS, style: .continuous).fill(.kitFill) }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.kitLabel)
        .accessibilityLabel("Copy \(key)")
        .transition(.opacity)
        .padding(.trailing, -2)
      }
    }
    .padding(EdgeInsets(horizontal: idiom.size(6, touch: 10), vertical: idiom.size(4, touch: 6)))
    .frame(minHeight: idiom.size(30, pad: 40, phone: 44))
    .background {
      if isHovered, !idiom.isTouch {
        RoundedRectangle(cornerRadius: ContMetrics.rowRadius(idiom), style: .continuous).fill(.kitHover)
      }
    }
    .contentShape(Rectangle())
    .kitHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
    .modifier(InspectorCopyMenu(text: copyText))
    .accessibilityElement(children: .combine)
  }
}

/// A key and its value side by side: the key as wide as it is (at most 40% of the width), the value wrapping in the
/// rest. Each is measured at the width it is placed at, so the height asked for is the height drawn (a `Grid`
/// reported less on a phone's width).
struct ContKeyValueLayout: Layout {
  var spacing: CGFloat

  private func widths(_ width: CGFloat?, _ subviews: Subviews) -> (key: CGFloat, value: CGFloat) {
    guard subviews.count == 2 else { return (0, width ?? 0) }
    let ideal = subviews[0].sizeThatFits(.unspecified).width
    guard let width else { return (ideal, subviews[1].sizeThatFits(.unspecified).width) }
    let key = min(ideal, width * 0.4)
    return (key, max(0, width - key - spacing))
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard subviews.count == 2 else { return .zero }
    let (key, value) = widths(proposal.width, subviews)
    let height = max(
      subviews[0].sizeThatFits(ProposedViewSize(width: key, height: nil)).height,
      subviews[1].sizeThatFits(ProposedViewSize(width: value, height: nil)).height)
    return CGSize(width: proposal.width ?? key + spacing + value, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard subviews.count == 2 else { return }
    let (key, value) = widths(bounds.width, subviews)
    subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: key, height: nil))
    subviews[1].place(
      at: CGPoint(x: bounds.minX + key + spacing, y: bounds.minY), proposal: ProposedViewSize(width: value, height: nil))
  }
}

/// A copyable row's context menu.
private struct InspectorCopyMenu: ViewModifier {
  let text: String?

  func body(content: Content) -> some View {
    if let text {
      content.kitContextMenu { Button("Copy", systemImage: "doc.on.doc") { ContPlatform.copy(text) } }
    } else {
      content
    }
  }
}

extension InspectorRow where Value == Text {
  /// A row with a text value, copyable by default.
  public init(_ key: String, value: String, copyable: Bool = true) {
    self.init(key, copyText: copyable ? value : nil) { Text(value) }
  }
}

/// One card bar of labelled buttons at the end of a pane (the inspector's actions), like the sidebar's bottom bar:
/// buttons fill on hover, destructive ones are red, and the bar wraps when they don't fit.
///
/// ```swift
/// ActionBar {
///   Button("Check Out") { … }
///   Button("Revert…") { … }
///   Button("Delete", role: .destructive) { … }
/// }
/// ```
public struct ActionBar<Content: View>: View {
  var iconOnly: Bool
  @ViewBuilder var content: Content

  /// An action bar; `iconOnly` shows the buttons' icons alone (their titles stay for accessibility). A single
  /// button's own `.labelStyle(.iconOnly)` is honoured too.
  public init(iconOnly: Bool = false, @ViewBuilder content: () -> Content) {
    self.iconOnly = iconOnly
    self.content = content()
  }

  public var body: some View {
    ContBarCard(labeled: true) {
      KitFlowLayout(spacing: 2, lineSpacing: 2) {
        if iconOnly {
          content.labelStyle(.iconOnly)
        } else {
          content
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

#Preview("Inspector") {
  KitInspector {
    InspectorHeader("Sharing: Shared a trip as a file", meta: ["330c484", "1 file changed"], systemImage: "circle.dashed") {
      Text("v1.1.0").kitFont(.caption)
    }
    KitSection("Maya Okafor", meta: "Oct 8, 7:26 PM", systemImage: "person.fill", hue: .brown) {
      InspectorRow("commit", value: "330c484")
      InspectorRow("parent") { Text("0baea71").kitFont(.mono) }
    }
    ActionBar {
      Button("Check Out") {}
      Button("Revert…") {}
      Button("Cherry-Pick") {}
    }
  }
  .frame(height: 420)
  .componentKit()
}
