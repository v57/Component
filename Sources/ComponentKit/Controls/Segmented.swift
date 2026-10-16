import SwiftUI

/// A value a kit picker can show: a title, and optionally an SF Symbol and a count. Conform an app's enum and the
/// segmented control and the search scope list its cases.
///
/// ```swift
/// enum Mode: String, KitOption, CaseIterable {
///   case unified, split
///   var title: String { rawValue.capitalized }
/// }
/// KitSegmented(selection: $mode)
/// ```
public protocol KitOption: Hashable {
  var title: String { get }
  var systemImage: String? { get }
  /// A count shown after the title as a plain number ("Changes 3"); `nil` shows none.
  var count: Int? { get }
}

extension KitOption {
  public var systemImage: String? { nil }
  public var count: Int? { nil }
}

/// One segment of a `KitSegmented`: the title, the value it picks, and optionally an icon, a count, or disabled.
///
/// ```swift
/// KitSegmented(selection: $tab, segments: [
///   KitSegment("Results", value: .results),
///   KitSegment("Messages", value: .messages, count: 2),
///   KitSegment("Plan", value: .plan, isEnabled: false),
/// ])
/// ```
public struct KitSegment<Value: Hashable>: Identifiable {
  public var title: String
  public var value: Value
  public var systemImage: String?
  public var count: Int?
  public var isEnabled: Bool
  public var id: Value { value }

  public init(_ title: String, value: Value, systemImage: String? = nil, count: Int? = nil, isEnabled: Bool = true) {
    self.title = title
    self.value = value
    self.systemImage = systemImage
    self.count = count
    self.isEnabled = isEnabled
  }
}

/// How a segmented control sits on its field track: sized to its segments, or `.wide` sharing the width. Set it with
/// `.kitSegmentedStyle(_:)`.
public enum KitSegmentedStyle: Hashable, Sendable {
  /// A field track sized to its segments.
  case automatic
  /// A field track whose segments share the available width.
  case wide
}

extension EnvironmentValues {
  @Entry var kitSegmentedStyle: KitSegmentedStyle = .automatic
}

extension View {
  /// Sets how the segmented controls inside sit: `.automatic` or `.wide`.
  ///
  /// ```swift
  /// KitSegmented(selection: $refs, options: …).kitSegmentedStyle(.wide)
  /// ```
  public func kitSegmentedStyle(_ style: KitSegmentedStyle) -> some View {
    environment(\.kitSegmentedStyle, style)
  }
}

/// The kit's segmented control: segments on a field track, the selected one a raised card that glides to the new
/// pick. Counts are plain numbers. Keyboard: Tab focuses a segment (the track takes the field ring and the focused
/// segment rises half-way), ← → move, Space picks. VoiceOver reads each segment as a button, the picked one selected.
///
/// ```swift
/// KitSegmented(selection: $mode)                                     // a KitOption & CaseIterable enum
/// KitSegmented(selection: $mode, options: [("Unified", .unified), ("Split", .split)])
/// ```
public struct KitSegmented<Value: Hashable>: View {
  @Binding var selection: Value
  var segments: [KitSegment<Value>]
  @Environment(\.kitSegmentedStyle) private var style
  @Environment(\.kitIdiom) private var idiom
  @FocusState private var focus: Value?
  @Namespace private var namespace

  /// A segmented control over `segments`.
  public init(selection: Binding<Value>, segments: [KitSegment<Value>]) {
    _selection = selection
    self.segments = segments
  }

  /// A segmented control over titled values.
  public init(selection: Binding<Value>, options: [(String, Value)]) {
    self.init(selection: selection, segments: options.map { KitSegment($0.0, value: $0.1) })
  }

  public var body: some View {
    let metrics = CtlSegmentMetrics(style: style, idiom: idiom)
    HStack(spacing: 0) {
      ForEach(segments) { segment in
        Button {
          withKitAnimation { selection = segment.value }
        } label: {
          CtlSegmentLabel(
            segment: segment, isSelected: segment.value == selection, isFocused: focus == segment.value,
            metrics: metrics, namespace: namespace)
        }
        .buttonStyle(CtlPressStyle())
        .disabled(!segment.isEnabled)
        .focused($focus, equals: segment.value)
        .accessibilityAddTraits(segment.value == selection ? .isSelected : [])
      }
    }
    .padding(metrics.trackPadding)
    .background { track(metrics) }
    .ctlFieldRing(focus != nil, cornerRadius: metrics.trackRadius)
    .fixedSize(horizontal: style != .wide, vertical: true)
    .focusEffectDisabled()
    .onKeyPress(.leftArrow) { moveFocus(-1) }
    .onKeyPress(.rightArrow) { moveFocus(1) }
    .animation(.kit, value: selection)
    .accessibilityElement(children: .contain)
  }

  private func track(_ metrics: CtlSegmentMetrics) -> some View {
    CtlTrack(cornerRadius: metrics.trackRadius)
  }

  /// Moves keyboard focus to the next enabled segment in `direction`, wrapping at the ends.
  private func moveFocus(_ direction: Int) -> KeyPress.Result {
    guard let current = focus, let index = segments.firstIndex(where: { $0.value == current }) else { return .ignored }
    guard let next = CtlSegmentNavigation.next(from: index, by: direction, enabled: segments.map(\.isEnabled)) else {
      return .ignored
    }
    focus = segments[next].value
    return .handled
  }
}

extension KitSegmented where Value: KitOption {
  /// A segmented control over the given options, titled (and counted) by the options themselves.
  public init(selection: Binding<Value>, options: [Value]) {
    self.init(
      selection: selection,
      segments: options.map { KitSegment($0.title, value: $0, systemImage: $0.systemImage, count: $0.count) })
  }
}

extension KitSegmented where Value: KitOption & CaseIterable {
  /// A segmented control over every case of a `KitOption` enum.
  public init(selection: Binding<Value>) {
    self.init(selection: selection, options: Array(Value.allCases))
  }
}

/// Keyboard movement across segments (and any row of items), skipping disabled ones.
enum CtlSegmentNavigation {
  /// The index after `index` in `direction` (±1) whose item is enabled, wrapping around; nil when none is.
  static func next(from index: Int, by direction: Int, enabled: [Bool]) -> Int? {
    let count = enabled.count
    guard count > 0 else { return nil }
    var candidate = index
    for _ in 0..<count {
      candidate = (candidate + direction + count) % count
      if enabled[candidate] { return candidate == index ? nil : candidate }
    }
    return nil
  }
}

struct CtlSegmentMetrics {
  var trackPadding: CGFloat
  var trackRadius: CGFloat
  var height: CGFloat
  var horizontalPadding: CGFloat
  var radius: CGFloat
  var font: KitFont
  var style: KitSegmentedStyle

  init(style: KitSegmentedStyle, idiom: KitIdiom) {
    self.style = style
    switch (style, idiom) {
    case (_, .mac):
      (trackPadding, trackRadius, height, horizontalPadding, radius, font) = (2, 9, 26, 11, 7, .callout)
    case (_, .pad):
      (trackPadding, trackRadius, height, horizontalPadding, radius, font) = (3, 12, 32, 14, 9, .callout)
    case (_, .phone):
      (trackPadding, trackRadius, height, horizontalPadding, radius, font) = (3, 12, 34, style == .wide ? 8 : 14, 9, .callout)
    }
  }
}

/// A segment: the title (and icon, count) on its card. Selected is the raised card (it glides between segments);
/// hovered, focused or pressed is the half-strength card (Hover A, focus C); pressing settles it.
struct CtlSegmentLabel<Value: Hashable>: View {
  let segment: KitSegment<Value>
  let isSelected: Bool
  let isFocused: Bool
  let metrics: CtlSegmentMetrics
  let namespace: Namespace.ID
  @Environment(\.ctlIsPressed) private var isPressed
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitToolbarIconOnly) private var toolbarIconOnly
  @State private var isHovered = false

  var body: some View {
    let isLit = isEnabled && (isHovered || isFocused || isPressed)
    // In a compacted toolbar a segment with an icon shows the icon alone (the title stays for accessibility).
    let iconOnly = toolbarIconOnly && segment.systemImage != nil
    HStack(spacing: 5) {
      if let systemImage = segment.systemImage {
        Image(systemName: systemImage).imageScale(.small)
      }
      if !iconOnly {
        CtlStableWeightText(segment.title, bold: isSelected)
      }
      if let count = segment.count {
        Text(count, format: .number)
          .monospacedDigit()
          .fontWeight(.regular)
          .opacity(0.8)
      }
    }
    .kitFont(metrics.font)
    .lineLimit(1)
    .foregroundStyle(foreground(isLit: isLit))
    .padding(.horizontal, metrics.horizontalPadding)
    .frame(maxWidth: metrics.style == .wide ? .infinity : nil)
    .frame(height: metrics.height)
    .background {
      let shape = RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)
      if isSelected {
        selectedCard
          .matchedGeometryEffect(id: "selection", in: namespace)
      } else if isLit {
        shape.fill(KitColor.ctlGhost)
      }
    }
    .scaleEffect(isPressed && isEnabled ? 0.98 : 1)
    .contentShape(Rectangle())
    .help(iconOnly ? segment.title : "")
    .accessibilityLabel(segment.title)
    .onHover { isHovered = $0 }
    .animation(.kitFast, value: isLit)
    .animation(.kitFast, value: isPressed)
  }

  private var selectedCard: some View {
    CtlRaisedCard(cornerRadius: metrics.radius, flat: isPressed)
  }

  private func foreground(isLit: Bool) -> KitColor {
    if !isEnabled { return .tertiary }
    return isSelected || isLit ? .label : .secondary
  }
}

/// Text that keeps the width of its semibold form, so a segment doesn't change width when it becomes selected.
struct CtlStableWeightText: View {
  var text: String
  var bold: Bool

  init(_ text: String, bold: Bool) {
    self.text = text
    self.bold = bold
  }

  var body: some View {
    ZStack {
      Text(text).fontWeight(.semibold).hidden()
      Text(text).fontWeight(bold ? .semibold : .regular)
    }
  }
}

private enum PreviewMode: String, KitOption, CaseIterable {
  case all, changes, staged
  var title: String { rawValue.capitalized }
  var count: Int? {
    switch self {
    case .all: nil
    case .changes: 3
    case .staged: 12
    }
  }
}

#Preview("Segmented") {
  @Previewable @State var mode = PreviewMode.changes
  @Previewable @State var view = "Unified"
  @Previewable @State var page = 0
  VStack(alignment: .leading, spacing: 16) {
    KitSegmented(selection: $mode)
    KitSegmented(selection: $view, options: [("Unified", "Unified"), ("Split", "Split")])
    KitSegmented(selection: $view, options: [("Local", "Local"), ("Remote", "Remote"), ("Tags", "Tags")])
      .kitSegmentedStyle(.wide)
    KitSegmented(selection: $page, segments: [
      KitSegment("History", value: 0), KitSegment("Changes", value: 1), KitSegment("Stashes", value: 2, isEnabled: false),
    ])
  }
  .padding(20)
  .frame(width: 360)
  .componentKit()
}
