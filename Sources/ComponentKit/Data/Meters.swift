import SwiftUI

// MARK: - Meter

/// One part of a meter: what it is, how much, its hue and glyph, and the value as text ("214.2 GB").
public struct MeterSegment: Identifiable, Hashable, Sendable {
  public var label: String
  public var value: Double
  public var hue: Hue
  public var systemImage: String?
  public var valueText: String?
  public var id: String { label }

  public init(_ label: String, value: Double, hue: Hue, systemImage: String? = nil, valueText: String? = nil) {
    self.label = label
    self.value = value
    self.hue = hue
    self.systemImage = systemImage
    self.valueText = valueText
  }
}

enum MeterLayout {
  /// Segment widths in `width`, `gap` apart: each in proportion to its value out of `total` (the sum when `nil`),
  /// at least `minWidth` so a small part still shows; the rest of the track is what's free.
  static func widths(_ values: [Double], total: Double?, width: CGFloat, gap: CGFloat, minWidth: CGFloat) -> [CGFloat] {
    let shown = values.filter { $0 > 0 }
    let sum = values.reduce(0) { $0 + max($1, 0) }
    let total = max(total ?? sum, sum)
    guard total > 0, !shown.isEmpty else { return values.map { _ in 0 } }
    let free = total > sum ? 1 : 0
    let usable = max(width - gap * CGFloat(shown.count - 1 + free), 0)
    var widths = values.map { $0 > 0 ? max(minWidth, usable * CGFloat($0 / total)) : 0 }
    // Minimum widths may overflow the track: take the excess from the widest parts.
    var excess = widths.reduce(0, +) - usable
    while excess > 0.5, let widest = widths.indices.max(by: { widths[$0] < widths[$1] }), widths[widest] > minWidth {
      let cut = min(excess, widths[widest] - minWidth)
      widths[widest] -= cut
      excess -= cut
    }
    return widths
  }
}

/// A stacked meter (Dev's storage scan, iCloud): the parts as tile-shaped pieces 2pt apart, in their hues, on a
/// field track whose rest is what's free. Pair it with `MeterLegend` in a card with a rich header.
///
/// ```swift
/// MeterBar(segments: [MeterSegment("Development", value: 214.2, hue: .blue), …], total: 994.7)
/// ```
public struct MeterBar: View {
  var segments: [MeterSegment]
  var total: Double?
  var height: CGFloat

  public init(segments: [MeterSegment], total: Double? = nil, height: CGFloat = 10) {
    self.segments = segments
    self.total = total
    self.height = height
  }

  public var body: some View {
    GeometryReader { proxy in
      let widths = MeterLayout.widths(
        segments.map(\.value), total: total, width: proxy.size.width, gap: 2, minWidth: 4)
      HStack(spacing: 2) {
        ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
          if widths[index] > 0 {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
              .fill(segment.hue.fill)
              .frame(width: widths[index])
          }
        }
        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(.kitField)
      }
      .animation(.kit, value: segments)
    }
    .frame(height: height)
    .accessibilityElement()
    .accessibilityLabel(segments.map { "\($0.label) \($0.valueText ?? String(format: "%g", $0.value))" }.joined(separator: ", "))
  }
}

/// A meter's legend: a row per part with its soft tile, name and value, a quiet row for what's free.
///
/// ```swift
/// MeterLegend(segments: parts, free: MeterSegment("Free", value: 382.3, hue: .gray, systemImage: "circle.dashed",
///                                                valueText: "382.3 GB"))
/// ```
public struct MeterLegend: View {
  var segments: [MeterSegment]
  var free: MeterSegment?
  @Environment(\.kitIdiom) private var idiom

  public init(segments: [MeterSegment], free: MeterSegment? = nil) {
    self.segments = segments
    self.free = free
  }

  public var body: some View {
    VStack(spacing: 2) {
      ForEach(segments) { row($0, quiet: false) }
      if let free { row(free, quiet: true) }
    }
  }

  private func row(_ segment: MeterSegment, quiet: Bool) -> some View {
    HStack(spacing: 10) {
      Tile(systemImage: segment.systemImage ?? "circle.fill", hue: segment.hue, size: 22)
      Text(segment.label)
        .foregroundStyle(quiet ? AnyShapeStyle(.kitSecondary) : AnyShapeStyle(.kitLabel))
        .lineLimit(1)
      Spacer(minLength: 8)
      Text(segment.valueText ?? String(format: "%g", segment.value))
        .monospacedDigit()
        .foregroundStyle(.kitSecondary)
    }
    .frame(minHeight: idiom.size(26, touch: 36))
    .accessibilityElement(children: .combine)
  }
}

/// A usage figure as a live icon: the ring carries the amount (or the work indicator while it's unknown), the value and its name
/// beside it (Shell's CPU and GPU, a board's progress, a scan).
///
/// ```swift
/// MeterTile("CPU", value: "32%", systemImage: "cpu", hue: .blue, progress: 0.32)
/// MeterTile("Scanning", value: "1,204", systemImage: "magnifyingglass", progress: nil)
/// ```
public struct MeterTile: View {
  var label: String
  var value: String
  var systemImage: String
  var hue: Hue
  var status: WorkStatus

  /// `progress` 0…1 fills the ring, `nil` turns the arc.
  public init(_ label: String, value: String, systemImage: String, hue: Hue = .accent, progress: Double?) {
    self.init(label, value: value, systemImage: systemImage, hue: hue, status: .working(progress: progress))
  }

  public init(_ label: String, value: String, systemImage: String, hue: Hue = .accent, status: WorkStatus) {
    self.label = label
    self.value = value
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
  }

  public var body: some View {
    HStack(spacing: 10) {
      LiveIcon(systemImage: systemImage, hue: hue, status: status, size: 28)
      VStack(alignment: .leading, spacing: 0) {
        Text(value).kitFont(.title3).monospacedDigit().contentTransition(.numericText())
        Text(label).kitFont(.caption)
      }
    }
    .padding(4)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Lanes

extension Hue {
  /// Lane colours, picked by index (Git's graph lanes, board columns, workflow runs): the accent, orange, purple,
  /// teal, pink, indigo, green, brown, then round again.
  public static func lane(_ index: Int) -> Hue {
    let lanes: [Hue] = [.accent, .orange, .purple, .teal, .pink, .indigo, .green, .brown]
    return lanes[((index % lanes.count) + lanes.count) % lanes.count]
  }
}

/// A board column (Agentus' tasks, Dev's workflows) as a card, like a sidebar's section: a rich header (the live icon,
/// the name with a bare count, a status line) over its items as rows, 2pt apart. Put lanes in a `LaneBoard`, which
/// lays them 12pt apart.
///
/// ```swift
/// Lane("Running", count: 2, meta: ["2 agents", "1 failing"], systemImage: "bolt", status: .working) {
///   LaneItem("#5 Damage-state sprites", subtitle: "artist · 3 of 8 sprites", isSelected: true) { Avatar(…) }
/// }
/// ```
public struct Lane<Accessory: View, Items: View>: View {
  var title: String
  var count: Int?
  var meta: [String]
  var systemImage: String
  var hue: Hue
  var status: WorkStatus
  var accessory: Accessory
  var items: Items

  public init(
    _ title: String, count: Int? = nil, meta: [String] = [], systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, @ViewBuilder accessory: () -> Accessory, @ViewBuilder items: () -> Items
  ) {
    self.title = title
    self.count = count
    self.meta = meta
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
    self.accessory = accessory()
    self.items = items()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      RichHeader(
        Text(title) + Text(count.map { "  \($0)" } ?? "").foregroundStyle(.kitSecondary),
        icon: { LiveIcon(systemImage: systemImage, hue: hue, status: status, size: 24) },
        meta: { MetaLine(meta) },
        accessory: { accessory })
      VStack(spacing: 2) { items }
    }
    .kitCard()
  }
}

/// A board: lanes side by side, 12pt apart and 16pt in, on the pane's own ground. Scrolls sideways lane by lane where
/// they don't all fit.
///
/// ```swift
/// LaneBoard {
///   Lane("Ready", count: 2, systemImage: "tray") { … }
///   Lane("Running", count: 1, systemImage: "bolt", status: .working) { … }
/// }
/// ```
public struct LaneBoard<Content: View>: View {
  var content: Content

  public init(@ViewBuilder content: () -> Content) { self.content = content() }

  public var body: some View {
    ScrollView(.horizontal) {
      HStack(alignment: .top, spacing: 12) { content }
        .padding(KitMetrics.gutter * 2)
        .scrollTargetLayout()
    }
    .scrollTargetBehavior(.viewAligned)
    .scrollBounceBehavior(.basedOnSize)
  }
}

extension Lane where Accessory == EmptyView {
  public init(
    _ title: String, count: Int? = nil, meta: [String] = [], systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, @ViewBuilder items: () -> Items
  ) {
    self.init(
      title, count: count, meta: meta, systemImage: systemImage, hue: hue, status: status,
      accessory: { EmptyView() }, items: items)
  }
}

/// A task in a lane: a leading view (an agent's square, a person's circle, a check), a title and a line under it (red
/// when it failed). It is a row like a sidebar's: the hover fill, and the selected task raised (at 60% while the window
/// isn't focused).
///
/// ```swift
/// LaneItem("#3 Stone walls", subtitle: "tester: Test failed", subtitleHue: .red) { AgentTile("C1", status: .failed) }
/// ```
public struct LaneItem<Leading: View>: View {
  var title: String
  var subtitle: String?
  var subtitleHue: Hue?
  var isSelected: Bool
  var leading: Leading
  @Environment(\.kitWindowIsActive) private var isActive
  @State private var isHovered = false

  public init(
    _ title: String, subtitle: String? = nil, subtitleHue: Hue? = nil, isSelected: Bool = false,
    @ViewBuilder leading: () -> Leading
  ) {
    self.title = title
    self.subtitle = subtitle
    self.subtitleHue = subtitleHue
    self.isSelected = isSelected
    self.leading = leading()
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 8) {
      leading
      VStack(alignment: .leading, spacing: 1) {
        Text(title).kitFont(.headline).lineLimit(1)
        if let subtitle {
          Text(subtitle)
            .foregroundStyle(subtitleHue.map { AnyShapeStyle($0.text) } ?? AnyShapeStyle(.kitSecondary))
            .kitFont(.caption)
            .lineLimit(2)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 6)
    .background {
      if isSelected, isActive {
        SurfaceShape(surface: .raised, cornerRadius: KitMetrics.radius)
      } else if isSelected {
        RoundedRectangle(cornerRadius: KitMetrics.radius, style: .continuous).fill(KitColor.raised).opacity(0.6)
      } else if isHovered {
        RoundedRectangle(cornerRadius: KitMetrics.radius, style: .continuous).fill(KitColor.rowHover)
      }
    }
    .kitHover { isHovered = $0 }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

extension LaneItem where Leading == EmptyView {
  public init(_ title: String, subtitle: String? = nil, subtitleHue: Hue? = nil, isSelected: Bool = false) {
    self.init(title, subtitle: subtitle, subtitleHue: subtitleHue, isSelected: isSelected) { EmptyView() }
  }
}

#Preview("Meters") {
  let parts = [
    MeterSegment("Development", value: 214.2, hue: .blue, systemImage: "hammer", valueText: "214.2 GB"),
    MeterSegment("AI", value: 96.5, hue: .purple, systemImage: "brain", valueText: "96.5 GB"),
    MeterSegment("Applications", value: 158, hue: .orange, systemImage: "shippingbox", valueText: "158.0 GB"),
    MeterSegment("CI", value: 22.3, hue: .indigo, systemImage: "server.rack", valueText: "22.3 GB"),
  ]
  VStack(alignment: .leading, spacing: 10) {
    RichHeader("Storage", meta: ["Macintosh HD", "scanning, 1,204 files"], systemImage: "internaldrive", status: .working)
    MeterBar(segments: parts, total: 994.7)
    MeterLegend(segments: parts, free: MeterSegment("Free", value: 382.3, hue: .gray, systemImage: "circle.dashed", valueText: "382.3 GB"))
    HStack {
      MeterTile("CPU", value: "32%", systemImage: "cpu", progress: 0.32)
      MeterTile("GPU", value: "36%", systemImage: "gauge.medium", hue: .purple, progress: 0.36)
    }
  }
  .kitCard(padding: 10)
  .frame(width: 360)
  .padding()
  .componentKit()
}

#Preview("Lanes") {
  HStack(alignment: .top, spacing: 12) {
    Lane("Running", count: 2, meta: ["2 agents", "1 failing"], systemImage: "bolt", status: .working) {
      LaneItem("#5 Damage-state sprites", subtitle: "artist · 3 of 8 sprites", isSelected: true) {
        Tile(letters: "A", hue: .pink, size: 24)
      }
      LaneItem("#3 Stone walls", subtitle: "tester: Test failed, crashed on launch", subtitleHue: .red) {
        Tile(letters: "C1", hue: .red, size: 24)
      }
    }
    Lane("Done", count: 3, meta: ["3 today"], systemImage: "checkmark", hue: .green, status: .done) {
      LaneItem("#1 Wall defs")
      LaneItem("#9 Mod settings page")
    }
  }
  .frame(width: 520)
  .padding()
  .componentKit()
}
