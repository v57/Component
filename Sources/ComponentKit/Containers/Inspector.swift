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
    let inset: CGFloat = idiom == .phone ? 16 : idiom == .pad ? 12 : 10
    ContEdgeScroll {
      VStack(alignment: .leading, spacing: idiom == .phone ? 16 : idiom == .pad ? 12 : 10) { content }
        .padding(.top, idiom.isTouch ? 16 : 14)
        .padding(.horizontal, inset)
        .padding(.bottom, inset)
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
      LiveIcon(systemImage: systemImage, hue: hue, status: status, size: idiom == .phone ? 40 : idiom == .pad ? 36 : 30)
        .padding(.top, 1)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .kitFont(idiom.isTouch ? .title2 : .title3)
          .fixedSize(horizontal: false, vertical: true)
        if !meta.isEmpty {
          MetaLine(meta).kitFont(.caption).lineLimit(2)
        }
        if Tags.self != EmptyView.self {
          ContFlowLayout(spacing: 6, lineSpacing: 6) { tags }
            .padding(.top, 4)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 6)
    .padding(.bottom, 4)
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
public struct InspectorRow<Value: View>: View {
  var key: String
  var copyText: String?
  @ViewBuilder var value: Value
  @State private var isHovered = false
  @Environment(\.kitIdiom) private var idiom

  /// A row with any value view; `copyText` is what Copy puts on the pasteboard (none: no Copy).
  public init(_ key: String, copyText: String? = nil, @ViewBuilder value: () -> Value) {
    self.key = key
    self.copyText = copyText
    self.value = value()
  }

  public var body: some View {
    HStack(spacing: 8) {
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
    .padding(.horizontal, idiom.isTouch ? 10 : 6)
    .padding(.vertical, idiom.isTouch ? 6 : 4)
    .frame(minHeight: idiom == .phone ? 44 : idiom == .pad ? 40 : 30)
    .background {
      if isHovered, !idiom.isTouch {
        RoundedRectangle(cornerRadius: ContMetrics.rowRadius(idiom), style: .continuous).fill(.kitHover)
      }
    }
    .contentShape(Rectangle())
    .onHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
    .contextMenu {
      if let copyText {
        Button("Copy", systemImage: "doc.on.doc") { ContPlatform.copy(copyText) }
      }
    }
    .accessibilityElement(children: .combine)
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
  @ViewBuilder var content: Content

  public init(@ViewBuilder content: () -> Content) { self.content = content() }

  public var body: some View {
    ContBarCard(labeled: true) {
      ContFlowLayout(spacing: 2, lineSpacing: 2) { content }
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
