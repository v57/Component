import SwiftUI

#if canImport(AppKit)
  import AppKit
#endif

extension View {
  /// The kit's tooltip: half a second after the pointer stops on the view, a small card with a rich header shows 6pt
  /// under it: the item's icon on a tinted tile (wearing `status`'s ring while it runs), its name, one line of status,
  /// then the shortcut as keycaps. Any move of the pointer hides it at once, and it comes back once the pointer rests
  /// again (on this item or the next one). On iPhone, with no pointer, it falls back to `.help`; everywhere the words
  /// also go to accessibility as a hint.
  ///
  /// ```swift
  /// Button("Pull", systemImage: "arrow.down") { … }
  ///   .kitHelp("Pull", shortcut: "⇧⌘P", meta: "1 behind origin/main", systemImage: "arrow.down")
  /// ```
  ///
  /// On the Mac it draws in a small window of its own over the app's window, so no column or scroll view clips it: it
  /// stays inside the window, and goes above the view when there's no room under it; `edge` picks the side instead.
  /// On iPad it draws in the view's overlay, so put it on views whose container doesn't clip (a scroll view clips); in
  /// a `KitSidebar` the sidebar draws it, over every card and stuck title, kept inside the sidebar.
  ///
  /// ```swift
  /// Text("Ln 12, Col 4").kitHelp("Go to Line", shortcut: "⌘L", edge: .top)
  /// ```
  public func kitHelp(
    _ title: String, shortcut: String? = nil, meta: String? = nil, systemImage: String? = nil,
    hue: Hue = .accent, status: WorkStatus = .idle, edge: VerticalEdge? = nil
  ) -> some View {
    modifier(
      ContHelpModifier(
        title: title, shortcut: shortcut, meta: meta, systemImage: systemImage, hue: hue, status: status, edge: edge))
  }

  /// The kit's tooltip with more under its header, past a hairline: a list of what a group holds, a few facts in
  /// rows. Keep it short and lined up (a `Grid`); it draws in `callout` type.
  ///
  /// ```swift
  /// GroupHeader(group)
  ///   .kitHelp(group.name, meta: "~/Developer · 12 repositories", systemImage: "folder") {
  ///     Grid(alignment: .leading) {
  ///       ForEach(changed) { repo in GridRow { Text(repo.name); SyncCounts(changes: repo.changes) } }
  ///     }
  ///   }
  /// ```
  public func kitHelp<Detail: View>(
    _ title: String, shortcut: String? = nil, meta: String? = nil, systemImage: String? = nil,
    hue: Hue = .accent, status: WorkStatus = .idle, edge: VerticalEdge? = nil,
    @ViewBuilder detail: () -> Detail
  ) -> some View {
    modifier(
      ContHelpModifier(
        title: title, shortcut: shortcut, meta: meta, systemImage: systemImage, hue: hue, status: status, edge: edge,
        detail: AnyView(detail())))
  }
}

/// How long the pointer rests on a view before its tooltip shows.
enum ContTooltipClock {
  static let delay: Duration = .milliseconds(500)
}

/// The pointer's rest timer: each move pushes its deadline back without redrawing the view.
@MainActor
private final class ContTooltipRest {
  var task: Task<Void, Never>?
  var deadline = ContinuousClock.now
}

private struct ContHelpModifier: ViewModifier {
  let title: String
  let shortcut: String?
  let meta: String?
  let systemImage: String?
  let hue: Hue
  let status: WorkStatus
  let edge: VerticalEdge?
  var detail: AnyView? = nil
  @State private var isShown = false
  @State private var rest = ContTooltipRest()
  @State private var id = UUID()
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.contTooltipHost) private var hasHost
  #if canImport(AppKit)
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.kitAccent) private var accent
    @Environment(\.kitIncreaseContrast) private var increaseContrast
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.contMeasuringCopy) private var isMeasuringCopy
  #endif

  func body(content: Content) -> some View {
    #if canImport(AppKit)
      content
        .kitHover { if !$0 { hide() } }
        .onContinuousHover(perform: pointer)
        .simultaneousGesture(TapGesture().onEnded { hide() })
        .background {
          // A kit toolbar's hidden copy of its tools shows none.
          if isShown, !isMeasuringCopy {
            ContTooltipPanelAnchor(
              card: AnyView(
                ContTooltipPanelContent(card: card)
                  .environment(\.colorScheme, colorScheme)
                  .environment(\.kitAccent, accent)
                  .environment(\.kitIdiom, idiom)
                  .environment(\.kitIncreaseContrast, increaseContrast)
                  .environment(\.layoutDirection, layoutDirection)
                  .environment(\.dynamicTypeSize, dynamicTypeSize)
                  .environment(\.locale, locale)
                  .font(KitFont.body.font)
                  .foregroundStyle(.kitLabel)),
              edge: edge
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
          }
        }
        .accessibilityHint([meta, shortcut].compactMap { $0 }.joined(separator: ", "))
        .onAppear {
          // For captures: once the window's columns have settled, as they have under a pointer.
          guard KitLaunchOptions.shownTooltip == title else { return }
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isShown = true }
        }
        .onDisappear { hide() }
    #else
    if idiom == .phone {
      content.help(title)
    } else if hasHost {
      content
        .kitHover { if !$0 { hide() } }
        .onContinuousHover(perform: pointer)
        .simultaneousGesture(TapGesture().onEnded { hide() })
        // Drawn by the container (`ContTooltipHost`), over every card and title.
        .anchorPreference(key: ContTooltipKey.self, value: .bounds) { [isShown, card, id] bounds in
          isShown ? [ContTooltip(id: id, card: card, anchor: bounds, edge: edge)] : []
        }
        .accessibilityHint([meta, shortcut].compactMap { $0 }.joined(separator: ", "))
        .onAppear { if KitLaunchOptions.shownTooltip == title { isShown = true } }
        .onDisappear { hide() }
    } else {
      content
        .kitHover { if !$0 { hide() } }
        .onContinuousHover(perform: pointer)
        .simultaneousGesture(TapGesture().onEnded { hide() })
        .overlay(alignment: isAbove ? .top : .bottom) {
          if isShown {
            card
              .fixedSize()
              // Under the view (its top a gap below the view's bottom) or over it (its bottom a gap above the top):
              // a frame of no height on that edge, the card reaching out of it.
              .padding(isAbove ? .bottom : .top, ContTooltipHost.gap)
              .frame(height: 0, alignment: isAbove ? .bottom : .top)
              .allowsHitTesting(false)
              .transition(.opacity)
          }
        }
        .zIndex(isShown ? 100 : 0)
        .accessibilityHint([meta, shortcut].compactMap { $0 }.joined(separator: ", "))
        .onAppear { if KitLaunchOptions.shownTooltip == title { isShown = true } }
        .onDisappear { hide() }
    }
    #endif
  }

  private var isAbove: Bool { edge == .top }

  private var card: ContTooltipCard {
    ContTooltipCard(
      title: title, shortcut: shortcut, meta: meta, systemImage: systemImage, hue: isEnabled ? hue : .gray,
      status: status, detail: detail)
  }

  /// Every move hides the tooltip and restarts the wait; it shows once the pointer has rested for `delay`.
  private func pointer(_ phase: HoverPhase) {
    guard case .active = phase, !ContDragActivity.shared.isDragging else { return hide() }
    if isShown { isShown = false }
    let rest = rest
    rest.deadline = .now + ContTooltipClock.delay
    guard rest.task == nil else { return }
    rest.task = Task { @MainActor in
      while ContinuousClock.now < rest.deadline {
        await kitSleep(until: rest.deadline)
        if Task.isCancelled { return }
      }
      rest.task = nil
      withAnimation(.kitFast) { isShown = true }
    }
  }

  private func hide() {
    rest.task?.cancel()
    rest.task = nil
    if isShown { isShown = false }
  }
}

/// A shown tooltip on its way to its container: its card and the view it explains.
struct ContTooltip: Identifiable {
  let id: UUID
  let card: ContTooltipCard
  let anchor: Anchor<CGRect>
  var edge: VerticalEdge? = nil
}

struct ContTooltipKey: PreferenceKey {
  static let defaultValue: [ContTooltip] = []
  static func reduce(value: inout [ContTooltip], nextValue: () -> [ContTooltip]) { value += nextValue() }
}

extension EnvironmentValues {
  /// Inside a container that draws its tooltips over itself (`ContTooltipHost`).
  @Entry var contTooltipHost = false
}

/// A container's tooltips (`kitHelp`), drawn over everything in it: each under the view it explains, centred on it and
/// kept 8pt inside the container's edges (no wider than it), or above the view when there's no room under it. Only where the views stay
/// in one hosting view: a system toolbar item's preferences never reach the window's root, so the root draws none.
struct ContTooltipHost: ViewModifier {
  static let gap: CGFloat = 6

  func body(content: Content) -> some View {
    content
      .environment(\.contTooltipHost, true)
      .overlayPreferenceValue(ContTooltipKey.self, alignment: .topLeading) { tooltips in
        GeometryReader { proxy in
          ForEach(tooltips) { tooltip in
            ContTooltipPlacement(anchor: proxy[tooltip.anchor], edge: tooltip.edge) { tooltip.card }
              .allowsHitTesting(false)
              .transition(.opacity)
          }
        }
      }
      .transformPreference(ContTooltipKey.self) { $0 = [] }
  }
}

/// Lays a tooltip's card out at its own size under (or over) the view it explains, inside the proposed bounds.
private struct ContTooltipPlacement: Layout {
  let anchor: CGRect
  var edge: VerticalEdge? = nil

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    proposal.replacingUnspecifiedDimensions()
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard let card = subviews.first else { return }
    let gutter = KitMetrics.gutter
    // At its own width while that fits, else as wide as the container allows (its lines wrap): the container may
    // clip what reaches past it (a split view's sidebar column does).
    let ideal = card.sizeThatFits(.unspecified)
    let room = max(0, bounds.width - 2 * gutter)
    let size = ideal.width <= room ? ideal : card.sizeThatFits(ProposedViewSize(width: room, height: nil))
    let origin = ContTooltipGeometry.origin(anchor: anchor, size: size, in: bounds.size, edge: edge)
    card.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: ProposedViewSize(size))
  }
}

/// Where a tooltip's card goes in its container, whose top-left is the origin: centred under (or over) the view it
/// explains, 8pt inside the container's edges.
enum ContTooltipGeometry {
  static func origin(anchor: CGRect, size: CGSize, in bounds: CGSize, edge: VerticalEdge?) -> CGPoint {
    let gutter = KitMetrics.gutter
    let x = min(max(anchor.midX - size.width / 2, gutter), max(gutter, bounds.width - gutter - size.width))
    let below = anchor.maxY + ContTooltipHost.gap
    let above = anchor.minY - ContTooltipHost.gap - size.height
    let fitsBelow = below + size.height <= bounds.height - gutter
    let fitsAbove = above >= gutter
    let y =
      switch edge {
      case .top: fitsAbove || !fitsBelow ? above : below
      case .bottom: below
      case nil: fitsBelow || !fitsAbove ? below : above
      }
    return CGPoint(x: x, y: y)
  }
}

#if canImport(AppKit)
  /// The card in its window: room around it for the floating surface's shadow, and the kit's fade in.
  private struct ContTooltipPanelContent: View {
    let card: ContTooltipCard
    @State private var isShown = false

    var body: some View {
      card
        .fixedSize()
        .opacity(isShown ? 1 : 0)
        .padding(ContTooltipPanelView.shadowRoom)
        .onAppear { withAnimation(.kitFast) { isShown = true } }
    }
  }

  /// Behind the view while its tooltip shows: finds the window and the frame, and keeps the tooltip's window open.
  private struct ContTooltipPanelAnchor: NSViewRepresentable {
    let card: AnyView
    let edge: VerticalEdge?

    func makeNSView(context: Context) -> ContTooltipPanelView { ContTooltipPanelView() }

    func updateNSView(_ view: ContTooltipPanelView, context: Context) {
      view.card = card
      view.edge = edge
      view.show()
    }

    static func dismantleNSView(_ view: ContTooltipPanelView, coordinator: ()) { view.close() }
  }

  /// The tooltip's window: a borderless child of the view's window, so it stays over that window and moves with it,
  /// and nothing in the window (a split view's column, a scroll view) clips it. It takes no clicks and no focus.
  final class ContTooltipPanelView: NSView {
    /// Past the card on every side, for the floating surface's shadow (radius 20, 16 down).
    static let shadowRoom: CGFloat = 36

    var card = AnyView(EmptyView())
    var edge: VerticalEdge?
    private var panel: NSPanel?
    private var host: NSHostingView<AnyView>?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window != nil { show() } else { close() }
    }

    // SwiftUI gives the view its frame after updating it, so the first `show` sees a stale place.
    override func setFrameOrigin(_ newOrigin: NSPoint) {
      super.setFrameOrigin(newOrigin)
      if panel != nil { show() }
    }

    override func setFrameSize(_ newSize: NSSize) {
      super.setFrameSize(newSize)
      if panel != nil { show() }
    }

    func show() {
      guard let window else { return }
      let host = host ?? NSHostingView(rootView: card)
      host.rootView = card
      host.sizingOptions = [.intrinsicContentSize]
      let panel = panel ?? makePanel(in: window, host: host)
      panel.appearance = window.effectiveAppearance
      self.host = host
      self.panel = panel
      place()
      // A column the view is in may have moved without the view's own frame changing.
      DispatchQueue.main.async { [weak self] in self?.place() }
    }

    private func place() {
      guard let window, let panel, let host else { return }
      let room = Self.shadowRoom
      host.layoutSubtreeIfNeeded()
      let fitting = host.intrinsicContentSize
      guard fitting.width > 2 * room, fitting.height > 2 * room else { return }
      let frame = Self.panelFrame(
        view: window.convertToScreen(convert(bounds, to: nil)), window: window.frame,
        screen: (window.screen ?? NSScreen.main)?.visibleFrame,
        card: CGSize(width: fitting.width - 2 * room, height: fitting.height - 2 * room), edge: edge)
      if panel.frame != frame { panel.setFrame(frame, display: true) }
    }

    func close() {
      guard let panel else { return }
      panel.parent?.removeChildWindow(panel)
      panel.orderOut(nil)
      self.panel = nil
      host = nil
    }

    /// The tooltip window's frame on the screen (AppKit's coordinates, from the bottom): the card placed inside the
    /// app's window, and inside the screen when it's wider than the window; plus the room for its shadow.
    static func panelFrame(
      view: CGRect, window: CGRect, screen: CGRect?, card: CGSize, edge: VerticalEdge?
    ) -> CGRect {
      let anchor = CGRect(x: view.minX - window.minX, y: window.maxY - view.maxY, width: view.width, height: view.height)
      let origin = ContTooltipGeometry.origin(anchor: anchor, size: card, in: window.size, edge: edge)
      var x = window.minX + origin.x
      var y = window.maxY - origin.y - card.height
      if let screen {
        x = max(screen.minX, min(x, screen.maxX - card.width))
        y = max(screen.minY, min(y, screen.maxY - card.height))
      }
      let room = shadowRoom
      return CGRect(x: x - room, y: y - room, width: card.width + 2 * room, height: card.height + 2 * room)
    }

    private func makePanel(in window: NSWindow, host: NSHostingView<AnyView>) -> NSPanel {
      let panel = NSPanel(
        contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hasShadow = false
      panel.ignoresMouseEvents = true
      panel.hidesOnDeactivate = false
      panel.isReleasedWhenClosed = false
      panel.animationBehavior = .none
      panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
      host.autoresizingMask = [.width, .height]
      panel.contentView = host
      window.addChildWindow(panel, ordered: .above)
      return panel
    }
  }
#endif

/// The tooltip's card: a rich header at its smallest, the shortcut as keys, and any detail under a hairline.
struct ContTooltipCard: View {
  let title: String
  let shortcut: String?
  let meta: String?
  let systemImage: String?
  let hue: Hue
  let status: WorkStatus
  var detail: AnyView? = nil
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    if let detail {
      VStack(alignment: .leading, spacing: 0) {
        header
        Rectangle().fill(.kitSeparator).frame(height: 0.5)
        detail
          .kitFont(.callout)
          .padding(EdgeInsets(top: 8, leading: 10, bottom: 9, trailing: 10))
      }
      .background { SurfaceShape(surface: .floating, cornerRadius: cornerRadius) }
    } else {
      header
        .background { SurfaceShape(surface: .floating, cornerRadius: cornerRadius) }
    }
  }

  private var cornerRadius: CGFloat { idiom.isTouch ? KitMetrics.radiusXL : KitMetrics.radiusCard }

  private var header: some View {
    HStack(spacing: 9) {
      if let systemImage {
        LiveIcon(systemImage: systemImage, hue: hue, status: status, size: idiom.size(26, touch: 30))
      }
      VStack(alignment: .leading, spacing: 1) {
        Text(title).kitFont(.headline)
        if let meta { Text(meta).kitFont(.caption) }
      }
      .padding(.trailing, shortcut == nil ? 4 : 6)
      if let shortcut { ContKeycaps(shortcut: shortcut) }
    }
    .padding(EdgeInsets(top: 7, leading: systemImage == nil ? 10 : 7, bottom: 7, trailing: 8))
    .frame(minHeight: idiom.size(42, touch: 48))
    .frame(maxWidth: detail == nil ? nil : .infinity, alignment: .leading)
  }
}

#Preview("Tooltip") {
  VStack(alignment: .leading, spacing: 12) {
    ContTooltipCard(title: "Pull", shortcut: "⇧⌘P", meta: "1 behind origin/main", systemImage: "arrow.down", hue: .accent, status: .idle)
    ContTooltipCard(title: "Fetch", shortcut: nil, meta: "Fetching origin…", systemImage: "arrow.clockwise", hue: .accent, status: .working)
    ContTooltipCard(title: "Push", shortcut: "⌘P", meta: "Nothing to push", systemImage: "arrow.up", hue: .gray, status: .idle)
    ContTooltipCard(
      title: "v57", shortcut: nil, meta: "~/Developer/v57 · 12 repositories", systemImage: "folder", hue: .orange,
      status: .idle,
      detail: AnyView(
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 3) {
          GridRow { Text("Code"); SyncCounts(changes: 1).gridColumnAlignment(.trailing) }
          GridRow { Text("Shell"); SyncCounts(ahead: 3) }
          GridRow { Text("Git"); SyncCounts(changes: 2, ahead: 2) }
        }))
    Button("Hover me", systemImage: "arrow.down") {}
      .buttonStyle(.kit)
      .kitHelp("Pull", shortcut: "⇧⌘P", meta: "1 behind origin/main", systemImage: "arrow.down")
  }
  .padding(40)
  .componentKit()
}
