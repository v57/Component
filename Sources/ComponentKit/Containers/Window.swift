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
}

// MARK: - Status bar

/// A pane's status bar as a small card bar, 8pt in from the pane's edges (like the sidebar's bottom bar): a live icon
/// leads, the status line follows in the caption style, and what sits at the end (counts, the cursor position) trails
/// after a `Spacer`.
///
/// ```swift
/// StatusBar(systemImage: "checkmark", status: .done) {
///   Text("Saved")
///   Spacer()
///   Text("101 words · 1 min read")
/// }
/// ```
public struct StatusBar<Content: View>: View {
  var systemImage: String?
  var hue: Hue
  var status: WorkStatus
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom

  /// A status bar; `systemImage` adds the live icon that carries `status`.
  public init(
    systemImage: String? = nil, hue: Hue = .accent, status: WorkStatus = .idle, @ViewBuilder content: () -> Content
  ) {
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
    self.content = content()
  }

  public var body: some View {
    HStack(spacing: 8) {
      if let systemImage {
        LiveIcon(systemImage: systemImage, hue: hue, status: status, size: idiom.isTouch ? 26 : 22)
      }
      content
    }
    .kitFont(idiom.isTouch ? .callout : .caption)
    .lineLimit(1)
    .padding(.leading, systemImage == nil ? 10 : 4)
    .padding(.trailing, 10)
    .frame(height: idiom.isTouch ? 38 : 30)
    .frame(maxWidth: .infinity, alignment: .leading)
    .kitSurface(.card)
    .padding([.horizontal, .bottom], KitMetrics.gutter)
    .accessibilityElement(children: .combine)
  }
}

extension View {
  /// Adds a status bar card at the bottom of this pane (its content stays above it).
  ///
  /// ```swift
  /// Editor().kitStatusBar(systemImage: "hammer", status: buildStatus) { Text("Test failed"); Spacer(); Text("Line 17") }
  /// ```
  public func kitStatusBar<Content: View>(
    systemImage: String? = nil, hue: Hue = .accent, status: WorkStatus = .idle,
    @ViewBuilder content: () -> Content
  ) -> some View {
    safeAreaInset(edge: .bottom, spacing: 0) {
      StatusBar(systemImage: systemImage, hue: hue, status: status, content: content)
    }
  }
}

// MARK: - Split

/// The main content and a pane beside it, split by a divider that drags the pane's width (from Git's
/// `ResizableSplit`). The width is remembered under `autosaveName`; double-clicking the divider restores the default.
/// When the window is too narrow for both, the main content gives way down to `mainMinWidth`, then the pane down to
/// its minimum.
///
/// The divider keeps a 9pt grab area. At rest it shows nothing (the change of ground is the edge) or a hairline when
/// both sides share a ground (`showsLine`); under the pointer a half-accent line marks it, and while dragging the line
/// is the accent and a small card reads the width.
///
/// ```swift
/// ResizableSplit("inspectorWidth", pane: .trailing, width: 320, range: 260...480, mainMinWidth: 360) {
///   Diff().kitPane(.content)
/// } pane: {
///   KitInspector { … }
/// }
/// ```
public struct ResizableSplit<Main: View, Pane: View>: View {
  let edge: HorizontalEdge
  let defaultWidth: CGFloat
  let range: ClosedRange<CGFloat>
  let mainMinWidth: CGFloat
  let showsLine: Bool
  @ViewBuilder let main: Main
  @ViewBuilder let pane: Pane
  @AppStorage private var width: Double
  /// The pane's laid-out width, which drags start from (it can be less than `width`).
  @State private var shownWidth: CGFloat = 0
  @State private var dragStart: CGFloat?
  @State private var isHovered = false

  public init(
    _ autosaveName: String, pane edge: HorizontalEdge, width defaultWidth: CGFloat,
    range: ClosedRange<CGFloat>, mainMinWidth: CGFloat = 0, showsLine: Bool = false,
    @ViewBuilder main: () -> Main, @ViewBuilder pane: () -> Pane
  ) {
    self.edge = edge
    self.defaultWidth = defaultWidth
    self.range = range
    self.mainMinWidth = mainMinWidth
    self.showsLine = showsLine
    self.main = main()
    self.pane = pane()
    _width = AppStorage(wrappedValue: Double(defaultWidth), autosaveName)
  }

  public var body: some View {
    HStack(spacing: 0) {
      if edge == .leading {
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

  private var sizedMain: some View {
    main.frame(minWidth: mainMinWidth, maxWidth: .infinity)
  }

  private var sizedPane: some View {
    pane
      .frame(minWidth: range.lowerBound, maxWidth: ContSplit.clamp(width, to: range))
      .modifier(ContWidthReader(width: $shownWidth))
      .layoutPriority(1)
  }

  private var divider: some View {
    let isDragging = dragStart != nil
    return Color.clear
      .frame(width: 0)
      .overlay {
        ZStack {
          if isDragging || isHovered {
            Rectangle()
              .fill(isDragging ? Hue.accent.fill : Hue.accent.soft(0.5))
              .frame(width: 2)
              .transition(.opacity)
          } else if showsLine {
            Rectangle().fill(.kitSeparator).frame(width: 1)
          }
          Color.clear
            .frame(width: 9)
            .contentShape(Rectangle())
            .contResizeCursor()
            .onHover { isHovered = $0 }
            .gesture(
              DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { drag in
                  let start = dragStart ?? shownWidth
                  dragStart = start
                  width = ContSplit.width(start: start, translation: drag.translation.width, edge: edge, range: range)
                }
                .onEnded { _ in dragStart = nil }
            )
            .onTapGesture(count: 2) { withKitAnimation { width = defaultWidth } }
        }
        .animation(.kitFast, value: isHovered)
        .animation(.kitFast, value: isDragging)
      }
      .overlay(alignment: .top) {
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
            .padding(.top, 10)
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
        let step: CGFloat = edge == .leading ? 20 : -20
        let start = shownWidth
        switch direction {
        case .increment: width = ContSplit.width(start: start, translation: step, edge: edge, range: range)
        case .decrement: width = ContSplit.width(start: start, translation: -step, edge: edge, range: range)
        @unknown default: break
        }
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
    let offset = edge == .leading ? translation : -translation
    return Double(clamp(Double(start + offset), to: range))
  }
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
        Spacer()
        Text("101 words · 1 min read")
      }
    } pane: {
      Color.clear.kitPane(.secondary)
    }
  }
  .frame(width: 720, height: 360)
  .componentKit()
}
