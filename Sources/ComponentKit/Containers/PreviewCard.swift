import SwiftUI

// The floating preview (the canvas's Code page, "Preview" boards, second pass of 2026-11-16): a running app as a
// card over a corner of what makes it, so the content under it keeps its width. The card minimizes to a capsule in
// the same corner, opens in a window of its own, moves between corners by its bar and resizes by its free borders.

/// The corner of its container a floating preview sits in.
public enum KitPreviewCorner: String, CaseIterable, Sendable {
  case bottomTrailing, bottomLeading, topTrailing, topLeading

  public var alignment: Alignment {
    switch self {
    case .bottomTrailing: .bottomTrailing
    case .bottomLeading: .bottomLeading
    case .topTrailing: .topTrailing
    case .topLeading: .topLeading
    }
  }

  var isTrailing: Bool { self == .bottomTrailing || self == .topTrailing }
  var isBottom: Bool { self == .bottomTrailing || self == .bottomLeading }

  /// The corner a card ends in after its bar was dragged by `translation`: past 80pt along an axis it changes side.
  func moved(by translation: CGSize, isRightToLeft: Bool = false) -> KitPreviewCorner {
    let dx = isRightToLeft ? -translation.width : translation.width
    let trailing = isTrailing ? dx > -80 : dx > 80
    let bottom = isBottom ? translation.height > -80 : translation.height > 80
    switch (bottom, trailing) {
    case (true, true): return .bottomTrailing
    case (true, false): return .bottomLeading
    case (false, true): return .topTrailing
    case (false, false): return .topLeading
    }
  }
}

/// What a card's bar tells the float it sits in while it is dragged.
struct ContPreviewMove {
  var changed: (CGSize) -> Void
  var ended: (CGSize) -> Void
}

extension EnvironmentValues {
  @Entry var contPreviewMove: ContPreviewMove?
  @Entry var contPreviewCorner: KitPreviewCorner = .bottomTrailing
}

/// Places a floating preview (a `KitPreviewCard` or a `KitPreviewPill`) in a corner of the room it is given, `inset`
/// from the edges. Dragging the card's bar moves it; let go and it settles in the nearest corner, kept in `corner`.
/// Put it in an `.overlay` of the content it floats over.
///
/// ```swift
/// editor.overlay {
///   KitPreviewFloat(corner: $corner, insets: EdgeInsets(top: 8, leading: 8, bottom: 46, trailing: 8)) {
///     KitPreviewCard("iPhone 17", meta: "Trips", systemImage: "iphone", scale: "55%") { … } content: { screen }
///   }
/// }
/// ```
public struct KitPreviewFloat<Content: View>: View {
  @Binding var corner: KitPreviewCorner
  var insets: EdgeInsets
  @ViewBuilder var content: Content
  @State private var drag = CGSize.zero
  @Environment(\.layoutDirection) private var layoutDirection

  public init(
    corner: Binding<KitPreviewCorner>, insets: EdgeInsets = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8),
    @ViewBuilder content: () -> Content
  ) {
    _corner = corner
    self.insets = insets
    self.content = content()
  }

  public var body: some View {
    content
      .environment(
        \.contPreviewMove,
        ContPreviewMove(
          changed: { drag = $0 },
          ended: { translation in
            withKitAnimation {
              corner = corner.moved(by: translation, isRightToLeft: layoutDirection == .rightToLeft)
              drag = .zero
            }
          })
      )
      .environment(\.contPreviewCorner, corner)
      .offset(drag)
      .padding(insets)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner.alignment)
  }
}

/// A running app as a floating card: its bar (a live icon, the name, a short meta, then the scale as a button,
/// Minimize, Open in Its Own Window and `tools`, usually one More menu), and the picture under it. In a
/// `KitPreviewFloat` the bar drags the card to another corner. `isDetached` is the same bar for a window of its own:
/// no Minimize, and the window button puts it back.
///
/// ```swift
/// KitPreviewCard(
///   "iPhone 17", meta: "Trips", systemImage: "iphone", scale: "55%", onScale: { toggleRealSize() },
///   onMinimize: { isMinimized = true }, onDetach: { openWindow() }
/// ) {
///   KitMenuButton("More", systemImage: "ellipsis") { … }
/// } content: {
///   KitPreviewScreen(aspect: size) { screen }.frame(width: width, height: height)
/// }
/// ```
public struct KitPreviewCard<Tools: View, Content: View>: View {
  var title: KitString
  var meta: String?
  var systemImage: String
  var hue: Hue
  var status: WorkStatus
  var scale: String?
  var isRealSize: Bool
  var isDetached: Bool
  var onScale: (() -> Void)?
  var onMinimize: (() -> Void)?
  var onDetach: (() -> Void)?
  @ViewBuilder var tools: Tools
  @ViewBuilder var content: Content
  @Environment(\.contPreviewMove) private var move

  /// A card titled by a key (a literal), looked up in the app's strings; `meta` and `scale` are shown as they are.
  /// A nil action leaves its button out.
  public init(
    _ title: LocalizedStringKey, meta: String? = nil, systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, scale: String? = nil, isRealSize: Bool = false, isDetached: Bool = false,
    onScale: (() -> Void)? = nil, onMinimize: (() -> Void)? = nil, onDetach: (() -> Void)? = nil,
    @ViewBuilder tools: () -> Tools, @ViewBuilder content: () -> Content
  ) {
    self.init(
      title: KitString(title), meta: meta, systemImage: systemImage, hue: hue, status: status, scale: scale,
      isRealSize: isRealSize, isDetached: isDetached, onScale: onScale, onMinimize: onMinimize, onDetach: onDetach,
      tools: tools, content: content)
  }

  /// The same with the title a string shown as it is (a device's or a window's name).
  @_disfavoredOverload
  public init(
    _ title: some StringProtocol, meta: String? = nil, systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, scale: String? = nil, isRealSize: Bool = false, isDetached: Bool = false,
    onScale: (() -> Void)? = nil, onMinimize: (() -> Void)? = nil, onDetach: (() -> Void)? = nil,
    @ViewBuilder tools: () -> Tools, @ViewBuilder content: () -> Content
  ) {
    self.init(
      title: KitString(verbatim: String(title)), meta: meta, systemImage: systemImage, hue: hue, status: status,
      scale: scale, isRealSize: isRealSize, isDetached: isDetached, onScale: onScale, onMinimize: onMinimize,
      onDetach: onDetach, tools: tools, content: content)
  }

  init(
    title: KitString, meta: String?, systemImage: String, hue: Hue, status: WorkStatus, scale: String?,
    isRealSize: Bool, isDetached: Bool, onScale: (() -> Void)?, onMinimize: (() -> Void)?, onDetach: (() -> Void)?,
    @ViewBuilder tools: () -> Tools, @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.meta = meta
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
    self.scale = scale
    self.isRealSize = isRealSize
    self.isDetached = isDetached
    self.onScale = onScale
    self.onMinimize = onMinimize
    self.onDetach = onDetach
    self.tools = tools()
    self.content = content()
  }

  public var body: some View {
    VStack(spacing: 0) {
      bar
      content.padding(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
    }
    .modifier(ContPreviewCardGround(isDetached: isDetached))
  }

  private var bar: some View {
    HStack(spacing: 6) {
      HStack(spacing: 6) {
        LiveIcon(systemImage: systemImage, hue: hue, status: status, size: 20)
        Text(title).kitFont(.callout).fontWeight(.semibold).lineLimit(1)
        if let meta { Text(verbatim: meta).kitFont(.caption).foregroundStyle(.kitSecondary).lineLimit(1) }
        Spacer(minLength: 4)
      }
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      #if !os(tvOS)
        .gesture(moveGesture, isEnabled: move != nil)
      #endif
      if let scale, let onScale {
        Button(action: onScale) {
          Text(verbatim: scale)
            .kitFont(.caption)
            .fontWeight(.medium)
            .monospacedDigit()
            .foregroundStyle(isRealSize ? AnyShapeStyle(Hue.accent.text) : AnyShapeStyle(.kitSecondary))
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(
              isRealSize ? AnyShapeStyle(Hue.accent.soft(0.16)) : AnyShapeStyle(.kitFill),
              in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .kitHelp(isRealSize ? "Back to the Size Before" : "Real Size", shortcut: "⌘1")
        .accessibilityLabel(Text(isRealSize ? "Back to the Size Before" : "Real Size"))
        .accessibilityValue(Text(verbatim: scale))
      }
      HStack(spacing: 0) {
        if let onMinimize, !isDetached {
          Button("Minimize", systemImage: "minus", action: onMinimize).kitHelp("Minimize")
        }
        if let onDetach {
          Button(
            isDetached ? "Put Back in the Window" : "Open in Its Own Window",
            systemImage: isDetached ? "arrow.down.backward.square" : "arrow.up.forward.square", action: onDetach
          )
          .kitHelp(isDetached ? "Put Back in the Window" : "Open in Its Own Window")
        }
        tools
      }
      .buttonStyle(.kitIcon)
      .controlSize(.small)
    }
    .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 4))
    .frame(height: 34)
  }

  #if !os(tvOS)
    private var moveGesture: some Gesture {
      DragGesture(minimumDistance: 4, coordinateSpace: .global)
        .onChanged { move?.changed($0.translation) }
        .onEnded { move?.ended($0.translation) }
    }
  #endif
}

/// The card's ground: the overlays' card while it floats, the pane's ground in its own window.
private struct ContPreviewCardGround: ViewModifier {
  let isDetached: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if isDetached {
      content.frame(maxWidth: .infinity, maxHeight: .infinity).kitPane(.secondary)
    } else {
      // Floating, the card is as large as its picture.
      content.fixedSize().kitOverlayCard()
    }
  }
}

/// A floating preview folded away: a capsule with a small picture (or the live icon while there is none), the name
/// and its state. A click opens the preview again.
///
/// ```swift
/// KitPreviewPill("iPhone 17", status: "Trips · running", systemImage: "iphone") { isMinimized = false } thumbnail: { screen }
/// KitPreviewPill("iPhone 17", status: "Installing Trips…", systemImage: "iphone", work: .working(progress: 0.6)) { … }
/// ```
public struct KitPreviewPill<Thumbnail: View>: View {
  var title: String
  var statusText: String?
  var systemImage: String
  var hue: Hue
  var work: WorkStatus
  var action: () -> Void
  @ViewBuilder var thumbnail: Thumbnail
  @Environment(\.contPreviewMove) private var move

  /// The texts name a device and its state, so they are shown as they are. An empty `thumbnail` shows the live icon.
  public init(
    _ title: String, status: String? = nil, systemImage: String, hue: Hue = .accent, work: WorkStatus = .idle,
    action: @escaping () -> Void, @ViewBuilder thumbnail: () -> Thumbnail
  ) {
    self.title = title
    statusText = status
    self.systemImage = systemImage
    self.hue = hue
    self.work = work
    self.action = action
    self.thumbnail = thumbnail()
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if Thumbnail.self == EmptyView.self {
          LiveIcon(systemImage: systemImage, hue: hue, status: work, size: 28, shape: .circle)
        } else {
          thumbnail
            .frame(maxHeight: 30)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.kitBorder, lineWidth: 0.5))
            .allowsHitTesting(false)
        }
        VStack(alignment: .leading, spacing: 0) {
          Text(verbatim: title).kitFont(.callout).fontWeight(.semibold).lineLimit(1)
          if let statusText {
            Text(verbatim: statusText).kitFont(.caption).foregroundStyle(.kitSecondary).lineLimit(1)
          }
        }
      }
      .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 12))
      .frame(height: 40)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .background { SurfaceShape(surface: .floating, cornerRadius: 20) }
    .kitHelp("Show Preview", shortcut: "⌥⌘P")
    .accessibilityLabel(Text(verbatim: [title, statusText].compactMap { $0 }.joined(separator: ", ")))
    #if !os(tvOS)
      .simultaneousGesture(
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
          .onChanged { move?.changed($0.translation) }
          .onEnded { move?.ended($0.translation) },
        isEnabled: move != nil)
    #endif
  }
}

extension KitPreviewPill where Thumbnail == EmptyView {
  /// A capsule with the live icon in place of a picture: nothing to show yet, or work in progress.
  public init(
    _ title: String, status: String? = nil, systemImage: String, hue: Hue = .accent, work: WorkStatus = .idle,
    action: @escaping () -> Void
  ) {
    self.init(title, status: status, systemImage: systemImage, hue: hue, work: work, action: action) { EmptyView() }
  }
}

extension View {
  /// Lets a floating preview be resized by its free borders: the two away from the corner it sits in (read from its
  /// `KitPreviewFloat`), and the corner between them. `onChange` gets how much larger the card should be than when
  /// the drag began (width and height, either may be negative); the app turns that into its size. While dragging,
  /// the card is outlined in the accent and `readout` shows at its free corner (`isSnapped` colours it: the size
  /// caught on a mark, such as real size).
  ///
  /// ```swift
  /// card.kitPreviewResize(readout: "64% · 257 × 559", isSnapped: scale == 1) { growth in
  ///   width = clamp(startWidth + max(growth.width, growth.height * aspect))
  /// } onEnded: { startWidth = width }
  /// ```
  public func kitPreviewResize(
    readout: String?, isSnapped: Bool = false, onChange: @escaping (CGSize) -> Void,
    onEnded: @escaping () -> Void = {}
  ) -> some View {
    modifier(ContPreviewResize(readout: readout, isSnapped: isSnapped, onChange: onChange, onEnded: onEnded))
  }
}

struct ContPreviewResize: ViewModifier {
  let readout: String?
  let isSnapped: Bool
  let onChange: (CGSize) -> Void
  let onEnded: () -> Void
  @State private var isDragging = false
  @Environment(\.contPreviewCorner) private var corner
  @Environment(\.layoutDirection) private var layoutDirection

  private static let grab: CGFloat = 12
  private static let cornerGrab: CGFloat = 20

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusOverlay, style: .continuous)
    content
      .overlay {
        if isDragging { shape.strokeBorder(Hue.accent.fill, lineWidth: 2).allowsHitTesting(false) }
      }
      // The free borders: the ones away from the anchored corner. Each grab area straddles its border.
      .overlay(alignment: corner.isTrailing ? .leading : .trailing) {
        handle(corner.isTrailing ? .leading : .trailing)
      }
      .overlay(alignment: corner.isBottom ? .top : .bottom) { handle(corner.isBottom ? .top : .bottom) }
      .overlay(alignment: freeCorner) { handle(freeEdge) }
      .overlay(alignment: freeCorner) {
        if isDragging, let readout {
          Text(verbatim: readout)
            .kitFont(.caption)
            .fontWeight(.medium)
            .monospacedDigit()
            .foregroundStyle(isSnapped ? AnyShapeStyle(Hue.accent.text) : AnyShapeStyle(.kitLabel))
            .padding(EdgeInsets(top: 4, leading: 9, bottom: 4, trailing: 9))
            .background { SurfaceShape(surface: .floating, cornerRadius: KitMetrics.radius) }
            .fixedSize()
            .alignmentGuide(corner.isBottom ? .top : .bottom) { $0[corner.isBottom ? .bottom : .top] + (corner.isBottom ? 8 : -8) }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
      }
      .animation(.kitFast, value: isDragging)
  }

  private var freeCorner: Alignment {
    switch corner {
    case .bottomTrailing: .topLeading
    case .bottomLeading: .topTrailing
    case .topTrailing: .bottomLeading
    case .topLeading: .bottomTrailing
    }
  }

  /// The corner between the free borders.
  private var freeEdge: ContFrameEdge {
    switch corner {
    case .bottomTrailing: .topLeading
    case .bottomLeading: .topTrailing
    case .topTrailing: .bottomLeading
    case .topLeading: .bottomTrailing
    }
  }

  /// A border's grab area: 12pt across it, half inside the card and half outside, along the border between the
  /// corners; a corner's is 20pt square over the card's rounded corner. The pointer says which way it resizes
  /// anywhere in the area.
  private func handle(_ edge: ContFrameEdge) -> some View {
    let horizontal = edge != .top && edge != .bottom
    let vertical = edge != .leading && edge != .trailing
    let outward = Self.grab / 2
    return Color.clear
      .frame(
        width: edge.isCorner ? Self.cornerGrab : (horizontal ? Self.grab : nil),
        height: edge.isCorner ? Self.cornerGrab : (vertical ? Self.grab : nil)
      )
      .padding(horizontal && !vertical ? .vertical : [], Self.cornerGrab - outward)
      .padding(vertical && !horizontal ? .horizontal : [], Self.cornerGrab - outward)
      .contentShape(Rectangle())
      .contFrameResizeCursor(edge)
      #if !os(tvOS)
        .gesture(
          DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { drag in
              isDragging = true
              onChange(growth(drag.translation, horizontal: horizontal, vertical: vertical))
            }
            .onEnded { _ in
              isDragging = false
              onEnded()
            }
        )
      #endif
      // Half of the area lies outside the card.
      .offset(
        x: horizontal ? (edge.isOnTrailingSide(corner) ? outward : -outward) : 0,
        y: vertical ? (edge.isOnBottomSide ? outward : -outward) : 0)
  }

  /// A drag's translation as growth: moving a free border away from the anchored corner makes the card larger.
  private func growth(_ translation: CGSize, horizontal: Bool, vertical: Bool) -> CGSize {
    let dx = layoutDirection == .rightToLeft ? -translation.width : translation.width
    return CGSize(
      width: horizontal ? (corner.isTrailing ? -dx : dx) : 0,
      height: vertical ? (corner.isBottom ? -translation.height : translation.height) : 0)
  }
}

extension ContFrameEdge {
  fileprivate var isOnBottomSide: Bool { self == .bottom || self == .bottomLeading || self == .bottomTrailing }

  /// Whether the area sits at the card's trailing border (in a layout direction's own terms).
  fileprivate func isOnTrailingSide(_ corner: KitPreviewCorner) -> Bool {
    self == .trailing || self == .topTrailing || self == .bottomTrailing
  }
}
