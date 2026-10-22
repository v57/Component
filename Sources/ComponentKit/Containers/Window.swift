import SwiftUI

// Window structure (the Window structure board, pick B "One sheet, cards for groups"): the content stays one sheet on
// the window ground, secondary panes take the panel ground so the change of ground is the edge, and only groups are
// cards (the inspector's sections, the status bar). Panes are not rounded, so they meet the window and each other edge
// to edge; two panes on the same ground side by side get their hairline back.

/// The ground a pane stands on.
public enum PaneGround: Hashable, Sendable {
  /// The window's white sheet: editors, tables, the main content.
  case content
  /// The panel ground: lists beside the content, inspectors, consoles, tab strips.
  case secondary
}

extension View {
  /// Puts a pane on its ground. Inside a `KitWindowLayout`, two panes on the same ground that meet get a hairline.
  ///
  /// ```swift
  /// NoteList().kitPane(.secondary)
  /// ```
  public func kitPane(_ ground: PaneGround = .content) -> some View {
    background {
      Rectangle().fill(ground == .content ? KitColor.window : KitColor.panel).ignoresSafeArea()
    }
    .anchorPreference(key: ContPaneKey.self, value: .bounds) { [ContPane(ground: ground, bounds: $0)] }
  }
}

struct ContPane {
  var ground: PaneGround
  var bounds: Anchor<CGRect>
}

struct ContPaneKey: PreferenceKey {
  static var defaultValue: [ContPane] { [] }
  static func reduce(value: inout [ContPane], nextValue: () -> [ContPane]) { value += nextValue() }
}

/// Panes side by side on one sheet, edge to edge, with no hairlines except where two panes on the same ground meet
/// (`.kitPane(_:)`). Splits (`ResizableSplit`) nest inside it.
///
/// ```swift
/// KitWindowLayout {
///   NoteList().frame(width: 240).kitPane(.secondary)
///   NoteEditor().kitPane(.content)
///     .kitStatusBar(systemImage: "checkmark", status: .done) { Text("Saved") }
/// }
/// ```
public struct KitWindowLayout<Content: View>: View {
  @ViewBuilder var content: Content

  public init(@ViewBuilder content: () -> Content) { self.content = content() }

  public var body: some View {
    HStack(spacing: 0) { content }
      .overlayPreferenceValue(ContPaneKey.self) { panes in
        GeometryReader { proxy in
          let frames = panes.map { (proxy[$0.bounds], $0.ground) }
          ForEach(Array(ContPaneEdges.lines(frames).enumerated()), id: \.offset) { _, line in
            Rectangle()
              .fill(.kitSeparator)
              .frame(width: line.width, height: line.height)
              .position(x: line.midX, y: line.midY)
          }
        }
        .allowsHitTesting(false)
      }
  }
}

/// Where a window's panes need a hairline, apart from views.
enum ContPaneEdges {
  /// A 1pt line where two panes on the same ground meet side by side, over the height they share.
  static func lines(_ panes: [(CGRect, PaneGround)]) -> [CGRect] {
    var lines: [CGRect] = []
    for (i, a) in panes.enumerated() {
      for b in panes[(i + 1)...] where a.1 == b.1 {
        let (left, right) = a.0.minX <= b.0.minX ? (a.0, b.0) : (b.0, a.0)
        guard abs(left.maxX - right.minX) < 1 else { continue }
        let top = max(left.minY, right.minY)
        let bottom = min(left.maxY, right.maxY)
        guard bottom - top > 1 else { continue }
        lines.append(CGRect(x: right.minX - 0.5, y: top, width: 1, height: bottom - top))
      }
    }
    return lines
  }

  struct Span: Equatable {
    var minX: CGFloat
    var width: CGFloat
    var ground: PaneGround
    var midX: CGFloat { minX + width / 2 }
  }

  /// The grounds along the top of a view `width` wide: the panes that reach its top (their frames in its space), the
  /// rest the window's sheet. The first pane listed wins where panes overlap.
  static func topSpans(_ panes: [(CGRect, PaneGround)], width: CGFloat) -> [Span] {
    var spans: [Span] = []
    var covered: [ClosedRange<CGFloat>] = []
    for (frame, ground) in panes where frame.minY <= 1 {
      var start = max(frame.minX, 0)
      var end = min(frame.maxX, width)
      for range in covered.sorted(by: { $0.lowerBound < $1.lowerBound }) {
        if range.contains(start) { start = range.upperBound }
        if range.lowerBound > start { end = min(end, range.lowerBound) }
      }
      guard end - start > 0.5 else { continue }
      spans.append(Span(minX: start, width: end - start, ground: ground))
      covered.append(start...end)
    }
    var x: CGFloat = 0
    for range in covered.sorted(by: { $0.lowerBound < $1.lowerBound }) {
      if range.lowerBound - x > 0.5 { spans.append(Span(minX: x, width: range.lowerBound - x, ground: .content)) }
      x = max(x, range.upperBound)
    }
    if width - x > 0.5 { spans.append(Span(minX: x, width: width - x, ground: .content)) }
    return spans
  }
}

// MARK: - Status bar

/// A pane's status bar as a small card, as wide as what it shows, at the pane's trailing side (or `alignment`'s), 8pt
/// in from its edges and opaque over content that runs on under it: a live icon leads, then the status line and what
/// goes with it (counts, the cursor position) in the caption style, 8pt apart.
///
/// ```swift
/// StatusBar(systemImage: "checkmark", status: .done) {
///   Text("Saved")
///   Text("101 words · 1 min read").foregroundStyle(.kitSecondary)
/// }
/// ```
public struct StatusBar<Content: View>: View {
  var systemImage: String?
  var hue: Hue
  var status: WorkStatus
  var alignment: HorizontalAlignment
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom

  /// A status bar; `systemImage` adds the live icon that carries `status`, `alignment` is the pane's side it sits at.
  public init(
    systemImage: String? = nil, hue: Hue = .accent, status: WorkStatus = .idle,
    alignment: HorizontalAlignment = .trailing, @ViewBuilder content: () -> Content
  ) {
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
    self.alignment = alignment
    self.content = content()
  }

  public var body: some View {
    HStack(spacing: 8) {
      if let systemImage {
        LiveIcon(systemImage: systemImage, hue: hue, status: status, size: idiom.size(22, touch: 26))
      }
      content
    }
    .kitFont(idiom.isTouch ? .callout : .caption)
    .lineLimit(1)
    .padding(.leading, systemImage == nil ? 10 : 4)
    .padding(.trailing, 10)
    .frame(height: idiom.size(30, touch: 38))
    .kitSurface(.card)
    // Opaque: content may run on under it.
    .kitBar()
    .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    .padding([.horizontal, .bottom], KitMetrics.gutter)
    .accessibilityElement(children: .combine)
  }
}

extension View {
  /// Adds a status bar card at the bottom of this pane (its content stays above it).
  ///
  /// ```swift
  /// Editor().kitStatusBar(systemImage: "hammer", status: buildStatus) { Text("Test failed"); Text("Line 17") }
  /// ```
  public func kitStatusBar<Content: View>(
    systemImage: String? = nil, hue: Hue = .accent, status: WorkStatus = .idle,
    alignment: HorizontalAlignment = .trailing, @ViewBuilder content: () -> Content
  ) -> some View {
    safeAreaInset(edge: .bottom, spacing: 0) {
      StatusBar(systemImage: systemImage, hue: hue, status: status, alignment: alignment, content: content)
    }
  }
}

// MARK: - Split

/// The main content and a pane beside it (or under it), split by a divider that drags the pane's size (from Git's
/// `ResizableSplit`). The size is remembered under `autosaveName`; double-clicking the divider restores the default.
/// When the window is too small for both, the main content gives way down to its minimum, then the pane down to its
/// own.
///
/// The divider keeps a 9pt grab area. At rest it shows nothing (the change of ground is the edge) or a hairline when
/// both sides share a ground (`showsLine`); under the pointer a half-accent line marks it, and while dragging the line
/// is the accent and a small card reads the size.
///
/// ```swift
/// ResizableSplit("inspectorWidth", pane: .trailing, width: 320, range: 260...480, mainMinWidth: 360) {
///   Diff().kitPane(.content)
/// } pane: {
///   KitInspector { … }
/// }
/// ResizableSplit("consoleHeight", pane: .bottom, height: 200, range: 120...480, mainMinHeight: 200) {
///   Editor().kitPane(.content)
/// } pane: {
///   Console().kitPane(.secondary)
/// }
/// ```
public struct ResizableSplit<Main: View, Pane: View>: View {
  let edge: Edge
  let defaultWidth: CGFloat
  let range: ClosedRange<CGFloat>
  let mainMinWidth: CGFloat
  let showsLine: Bool
  @ViewBuilder let main: Main
  @ViewBuilder let pane: Pane
  @AppStorage private var width: Double
  /// The pane's laid-out size along the split, which drags start from (it can be less than `width`).
  @State private var shownWidth: CGFloat = 0
  @State private var dragStart: CGFloat?
  @State private var isHovered = false

  /// A pane at the leading or trailing edge, `width` wide by default.
  public init(
    _ autosaveName: String, pane edge: HorizontalEdge, width defaultWidth: CGFloat,
    range: ClosedRange<CGFloat>, mainMinWidth: CGFloat = 0, showsLine: Bool = false,
    @ViewBuilder main: () -> Main, @ViewBuilder pane: () -> Pane
  ) {
    self.edge = edge == .leading ? .leading : .trailing
    self.defaultWidth = defaultWidth
    self.range = range
    self.mainMinWidth = mainMinWidth
    self.showsLine = showsLine
    self.main = main()
    self.pane = pane()
    _width = AppStorage(wrappedValue: Double(defaultWidth), autosaveName)
  }

  /// A pane at the top or bottom edge (a console, a preview), `height` tall by default.
  public init(
    _ autosaveName: String, pane edge: VerticalEdge, height defaultHeight: CGFloat,
    range: ClosedRange<CGFloat>, mainMinHeight: CGFloat = 0, showsLine: Bool = false,
    @ViewBuilder main: () -> Main, @ViewBuilder pane: () -> Pane
  ) {
    self.edge = edge == .top ? .top : .bottom
    self.defaultWidth = defaultHeight
    self.range = range
    self.mainMinWidth = mainMinHeight
    self.showsLine = showsLine
    self.main = main()
    self.pane = pane()
    _width = AppStorage(wrappedValue: Double(defaultHeight), autosaveName)
  }

  private var isVertical: Bool { edge == .top || edge == .bottom }
  private var paneLeads: Bool { edge == .leading || edge == .top }

  public var body: some View {
    let layout = isVertical ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
    layout {
      if paneLeads {
        sizedPane
        divider
        sizedMain
      } else {
        sizedMain
        divider
        sizedPane
      }
    }
  }

  @ViewBuilder
  private var sizedMain: some View {
    if isVertical {
      main.frame(minHeight: mainMinWidth, maxHeight: .infinity)
    } else {
      main.frame(minWidth: mainMinWidth, maxWidth: .infinity)
    }
  }

  @ViewBuilder
  private var sizedPane: some View {
    if isVertical {
      pane
        .frame(minHeight: range.lowerBound, maxHeight: ContSplit.clamp(width, to: range))
        .modifier(ContSizeReader(axis: .vertical, size: $shownWidth))
        .layoutPriority(1)
    } else {
      pane
        .frame(minWidth: range.lowerBound, maxWidth: ContSplit.clamp(width, to: range))
        .modifier(ContSizeReader(axis: .horizontal, size: $shownWidth))
        .layoutPriority(1)
    }
  }

  private var divider: some View {
    let isDragging = dragStart != nil
    let vertical = isVertical
    return Color.clear
      .frame(width: vertical ? nil : 0, height: vertical ? 0 : nil)
      .overlay {
        ZStack {
          if isDragging || isHovered {
            Rectangle()
              .fill(isDragging ? Hue.accent.fill : Hue.accent.soft(0.5))
              .frame(width: vertical ? nil : 2, height: vertical ? 2 : nil)
              .transition(.opacity)
          } else if showsLine {
            Rectangle().fill(.kitSeparator).frame(width: vertical ? nil : 1, height: vertical ? 1 : nil)
          }
          Color.clear
            .frame(width: vertical ? nil : 9, height: vertical ? 9 : nil)
            .contentShape(Rectangle())
            .contResizeCursor(vertical: vertical)
            .kitHover { isHovered = $0 }
            #if !os(tvOS)
            .gesture(
              DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { drag in
                  let start = dragStart ?? shownWidth
                  dragStart = start
                  width = ContSplit.size(
                    start: start, translation: vertical ? drag.translation.height : drag.translation.width,
                    paneLeads: paneLeads, range: range)
                }
                .onEnded { _ in dragStart = nil }
            )
            #endif
            .onTapGesture(count: 2) { withKitAnimation { width = defaultWidth } }
        }
        .animation(.kitFast, value: isHovered)
        .animation(.kitFast, value: isDragging)
      }
      .overlay(alignment: vertical ? .leading : .top) {
        if isDragging {
          Text("\(Int(shownWidth.rounded())) pt")
            .kitFont(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.kitLabel)
            .monospacedDigit()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background { SurfaceShape(surface: .floating, cornerRadius: KitMetrics.radiusXS) }
            .fixedSize()
            .padding(vertical ? .leading : .top, 10)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
      }
      // Above the views beside it, so the whole grab area takes the drag.
      .zIndex(1)
      .accessibilityElement()
      .accessibilityLabel("Divider")
      .accessibilityValue("\(Int(shownWidth.rounded())) points")
      .accessibilityAdjustableAction { direction in
        let step: CGFloat = paneLeads ? 20 : -20
        let start = shownWidth
        switch direction {
        case .increment: width = ContSplit.size(start: start, translation: step, paneLeads: paneLeads, range: range)
        case .decrement: width = ContSplit.size(start: start, translation: -step, paneLeads: paneLeads, range: range)
        @unknown default: break
        }
      }
  }
}

/// Reports a view's width or height.
struct ContSizeReader: ViewModifier {
  let axis: Axis
  @Binding var size: CGFloat

  func body(content: Content) -> some View {
    let axis = axis
    return content.onGeometryChange(for: CGFloat.self) { axis == .vertical ? $0.size.height : $0.size.width } action: {
      size = $0
    }
  }
}

struct ContWidthReader: ViewModifier {
  @Binding var width: CGFloat

  func body(content: Content) -> some View {
    content.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
  }
}

/// The split's width math, apart from views.
enum ContSplit {
  static func clamp(_ width: Double, to range: ClosedRange<CGFloat>) -> CGFloat {
    min(max(CGFloat(width), range.lowerBound), range.upperBound)
  }

  /// The pane's width after dragging the divider by `translation` from a pane `start` wide: a leading pane grows as
  /// the divider moves right, a trailing one as it moves left.
  static func width(start: CGFloat, translation: CGFloat, edge: HorizontalEdge, range: ClosedRange<CGFloat>) -> Double {
    size(start: start, translation: translation, paneLeads: edge == .leading, range: range)
  }

  /// The pane's size after dragging the divider by `translation` along the split: a pane that leads (leading, top)
  /// grows as the divider moves forward (right, down), one that trails as it moves back.
  static func size(start: CGFloat, translation: CGFloat, paneLeads: Bool, range: ClosedRange<CGFloat>) -> Double {
    let offset = paneLeads ? translation : -translation
    return Double(clamp(Double(start + offset), to: range))
  }
}

#Preview("Vertical split") {
  ResizableSplit("preview.console", pane: .bottom, height: 140, range: 80...260, showsLine: true) {
    Text("Editor").frame(maxWidth: .infinity, maxHeight: .infinity).kitPane(.content)
  } pane: {
    Text("Console").frame(maxWidth: .infinity, maxHeight: .infinity).kitPane(.secondary)
  }
  .frame(width: 480, height: 360)
  .componentKit()
}

#Preview("Window B") {
  KitWindowLayout {
    VStack(alignment: .leading) {
      Text("All Notes").kitFont(.headline).padding(12)
      Spacer()
    }
    .frame(width: 200)
    .kitPane(.secondary)
    ResizableSplit("preview.inspector", pane: .trailing, width: 220, range: 160...320) {
      VStack {
        Text("Trip to Lisbon").kitFont(.title2)
        Spacer()
      }
      .padding()
      .frame(maxWidth: .infinity)
      .kitPane(.content)
      .kitStatusBar(systemImage: "checkmark", status: .done) {
        Text("Saved")
        Text("101 words · 1 min read").foregroundStyle(.kitSecondary)
      }
    } pane: {
      Color.clear.kitPane(.secondary)
    }
  }
  .frame(width: 720, height: 360)
  .componentKit()
}
