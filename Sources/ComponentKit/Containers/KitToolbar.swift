import SwiftUI

#if os(iOS)
  import UIKit
#endif

// The kit's own toolbar: drawn by the kit in the window's title bar area instead of the system toolbar, so it keeps the
// kit's look and compacts by the kit's rule (labelled → icon-only → folded by priority into "…") rather than the
// system's overflow chevron, which hides every item at once. The system toolbar stays only for the title bar's height
// (the traffic lights sit centered on the bar), with nothing of its own showing.

// MARK: - Slots

/// One item of a `KitToolbar`: any view (a `ToolGroup`, a `KitSegmented`, a primary button), its priority (lower folds
/// first) and its form inside the trailing "…" menu once it folds. A slot without a menu never folds. The "…" is the
/// kit's menu, so a slot's menu is kit menu rows: `Button`, `Toggle`, `Divider`, `KitMenuOptions` where a picker was,
/// `KitSubmenu`, `KitMenuSection`.
///
/// ```swift
/// ToolbarSlot(priority: 1) {
///   KitSegmented(selection: $mode, segments: modes)
/// } menu: {
///   KitSubmenu("Mode", systemImage: "rectangle.split.2x1") { KitMenuOptions(selection: $mode, segments: modes) }
/// }
/// ```
public struct ToolbarSlot {
  var priority: Int?
  var content: () -> AnyView
  var menu: (() -> AnyView)?

  /// A slot that never folds (the primary action, a search field that must stay).
  public init<Content: View>(@ViewBuilder _ content: @escaping () -> Content) {
    self.content = { AnyView(content()) }
  }

  /// A slot that folds into the "…" menu as `menu` when the toolbar runs out of room, lowest priority first.
  public init<Content: View, Menu: View>(
    priority: Int = 0, @ViewBuilder _ content: @escaping () -> Content, @ViewBuilder menu: @escaping () -> Menu
  ) {
    self.priority = priority
    self.content = { AnyView(content()) }
    self.menu = { AnyView(menu()) }
  }
}

/// Builds a `KitToolbar`'s tools: `ToolbarSlot`s, and plain views as slots that never fold.
@resultBuilder
public enum ToolbarSlotBuilder {
  public static func buildExpression(_ slot: ToolbarSlot) -> [ToolbarSlot] { [slot] }
  public static func buildExpression(_ slots: [ToolbarSlot]) -> [ToolbarSlot] { slots }
  public static func buildExpression<Content: View>(_ view: Content) -> [ToolbarSlot] { [ToolbarSlot { view }] }
  public static func buildBlock(_ parts: [ToolbarSlot]...) -> [ToolbarSlot] { parts.flatMap { $0 } }
  public static func buildOptional(_ part: [ToolbarSlot]?) -> [ToolbarSlot] { part ?? [] }
  public static func buildEither(first: [ToolbarSlot]) -> [ToolbarSlot] { first }
  public static func buildEither(second: [ToolbarSlot]) -> [ToolbarSlot] { second }
  public static func buildArray(_ parts: [[ToolbarSlot]]) -> [ToolbarSlot] { parts.flatMap { $0 } }
  public static func buildLimitedAvailability(_ part: [ToolbarSlot]) -> [ToolbarSlot] { part }
}

extension EnvironmentValues {
  /// Whether the toolbar around this view has compacted to icons: `ToolGroup`s, `.kitTool` buttons and
  /// `KitSegmented` drop their titles (they stay for accessibility and the tooltip). Read it in a view of your own
  /// that should compact the same way.
  @Entry public var kitToolbarIconOnly = false
}

// MARK: - The bar

/// The kit's toolbar: what leads (the Show Sidebar button while the sidebar is hidden, Back on iPhone), the title, and
/// the tools at the trailing edge. As room runs out the tools go icon-only all at once, then fold into the trailing
/// "…" menu by priority, lowest first; slots without a menu never fold, and the title truncates last. 52pt on the Mac,
/// 60 on iPad, 56 on iPhone. `.kitToolbar(…)` puts it at the top of a view, in the window's title bar.
///
/// ```swift
/// KitToolbar("History", meta: ["main", "2 to push"], systemImage: "clock") {
///   ToolbarSlot(priority: 1) { ToolGroup { Button("Fetch", systemImage: "arrow.down.circle") { … } } } menu: {
///     Button("Fetch", systemImage: "arrow.down.circle") { … }
///   }
///   Button("Commit", systemImage: "checkmark") { … }.buttonStyle(.kitPrimary)
/// }
/// ```
public struct KitToolbar<Title: View>: View {
  let title: Title
  let slots: [ToolbarSlot]
  /// How far from the window's leading edge the bar starts.
  @State private var windowMinX = CGFloat.infinity
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.contShowSidebar) private var showSidebar
  @Environment(\.contShowsSidebarButton) private var showsSidebarButton
  @Environment(\.contHasSidebarToggle) private var hasSidebarToggle
  @Environment(\.contFullScreen) private var isFullScreen
  #if os(Windows) || os(Linux)
    /// The title bar row the bar sits in (v57/SwiftUI): its height, the menu bar before it, the caption buttons after.
    @Environment(\.windowTitleBarArea) private var titleBarArea
    /// The app's menus, which the bar draws at its leading end (`ContMenuBar`).
    @Environment(\.windowMenuBar) private var menus
  #endif
  #if os(iOS)
    @Environment(\.isPresented) private var isPresented
    @Environment(\.dismiss) private var dismiss
  #endif

  /// A toolbar with any title view (a `KitTitle`, a `RichHeader(…, size: .title)` with an avatar, plain text).
  public init(@ViewBuilder title: () -> Title, @ToolbarSlotBuilder tools: () -> [ToolbarSlot]) {
    self.title = title()
    self.slots = tools()
  }

  public var body: some View {
    let height = barHeight
    ContToolbarLayout(spacing: idiom.size(8, touch: 10)) {
      HStack(spacing: idiom.size(8, touch: 10)) {
        #if os(iOS)
          if isPresented {
            ToolGroup(iconOnly: true) {
              Button("Back", systemImage: "chevron.left") { dismiss() }
            }
            .transition(.opacity)
          }
        #endif
        #if os(Windows) || os(Linux)
          // The window's menus, drawn by the kit at the start of the bar (the row's own menu bar steps aside).
          if let menus, !menus.isEmpty {
            ContMenuBar(menus: menus)
          }
        #endif
        // On the Mac the system toolbar's item carries the button (`ContSystemToolbarAway`): the item sits there
        // and would take its clicks. In full screen the toolbar is hidden.
        if let showSidebar, showsSidebarButton, drawsShowSidebar {
          ContShowSidebarButton(action: showSidebar, isVisible: true)
            .transition(.opacity)
        }
      }
      title
        .lineLimit(1)
        .modifier(ContGroundGlow())
      ContToolbarTools(slots: slots)
    }
    .padding(EdgeInsets(top: 0, leading: leadingInset, bottom: 0, trailing: trailingInset))
    .frame(height: height)
    .frame(maxWidth: .infinity)
    .background { ContWindowDragArea() }
    #if os(macOS)
      .background { ContWindowLeadingProbe(minX: $windowMinX, limit: leadingRoom).accessibilityHidden(true) }
    #endif
    .environment(\.contBarGround, KitColor.window)
    .animation(.kit, value: showSidebar != nil)
  }

  private var drawsShowSidebar: Bool {
    #if os(macOS)
      isFullScreen
    #else
      true
    #endif
  }

  /// 16pt in from the bar's edge, and on the Mac clear of the traffic lights (where the system toolbar puts its first
  /// item), and of the Show Sidebar button in a column whose sidebar `kitSidebarToggle` hides, measured from where the
  /// bar is in the window. So as the sidebar slides away the title rides with its column until it reaches that room,
  /// and as the sidebar comes back the title waits there until the column takes it along (it jumped aside at once,
  /// then slid back with the column).
  #if os(macOS)
    /// The traffic lights' room, and the Show Sidebar button's beside a sidebar `kitSidebarToggle` hides.
    private var leadingRoom: CGFloat {
      ContMetrics.windowControlsWidth + (hasSidebarToggle ? ContMetrics.showSidebarItemWidth + 8 : 12)
    }
  #endif

  private var leadingInset: CGFloat {
    #if os(macOS)
      if isFullScreen { return 16 }
      return max(16, leadingRoom - windowMinX)
    #elseif os(Windows) || os(Linux)
      // After the menu bar in the title bar row.
      max(16, (titleBarArea?.leading ?? 0) + 8)
    #else
      16
    #endif
  }

  /// 10pt on the Mac (16 on touch); on Windows clear of the caption buttons (and the system toolbar) at the row's end.
  private var trailingInset: CGFloat {
    #if os(Windows) || os(Linux)
      (titleBarArea?.trailing ?? 0) + 10
    #else
      idiom == .mac ? 10 : 16
    #endif
  }

  /// The title bar's height on the Mac (52), the row's on Windows (its caption buttons' height), 60 on iPad, 56 on iPhone.
  private var barHeight: CGFloat {
    #if os(Windows) || os(Linux)
      titleBarArea?.height ?? ContMetrics.toolbarHeight(idiom)
    #else
      ContMetrics.toolbarHeight(idiom)
    #endif
  }
}

extension KitToolbar where Title == KitTitle {
  /// A toolbar named by the kit's rich title (icon tile, name, status line).
  public init(
    _ title: String, meta: [String] = [], systemImage: String, hue: Hue = .accent, status: WorkStatus = .idle,
    @ToolbarSlotBuilder tools: () -> [ToolbarSlot]
  ) {
    self.init(title: { KitTitle(title, meta: meta, systemImage: systemImage, hue: hue, status: status) }, tools: tools)
  }
}

extension View {
  /// Puts the kit's toolbar at the top of this view, in the window's title bar (under the status bar on iPhone and
  /// iPad), in place of the system toolbar: the title, then the tools at the trailing edge, compacting by the kit's
  /// rule. The view's content scrolls on under it. `windowTitle` stays the window's (Window menu, Mission Control).
  /// Put it on the detail column, and `kitSidebarToggle` outside it to get the Show Sidebar button in the bar. In a
  /// window without a sidebar put it on the window's root view: the title then starts after the traffic lights.
  ///
  /// ```swift
  /// HistoryView()
  ///   .kitToolbar("History", title: { KitTitle("History", meta: ["main"], systemImage: "clock") }) {
  ///     ToolbarSlot(priority: 1) { ToolGroup { … } } menu: { … }
  ///     Button("Commit", systemImage: "checkmark") { … }.buttonStyle(.kitPrimary)
  ///   }
  ///   .kitSidebarToggle(columnVisibility: $columns)
  /// ```
  public func kitToolbar<Title: View>(
    _ windowTitle: String, @ViewBuilder title: () -> Title, @ToolbarSlotBuilder tools: () -> [ToolbarSlot]
  ) -> some View {
    modifier(ContKitToolbar(windowTitle: windowTitle, bar: KitToolbar(title: title, tools: tools)))
  }

  /// The kit's toolbar named by the rich title (icon tile, name, status line).
  ///
  /// ```swift
  /// HistoryView()
  ///   .kitToolbar("History", meta: ["main", "2 to push"], systemImage: "clock", status: fetch) { … }
  /// ```
  public func kitToolbar(
    _ title: String, meta: [String] = [], systemImage: String, hue: Hue = .accent, status: WorkStatus = .idle,
    @ToolbarSlotBuilder tools: () -> [ToolbarSlot]
  ) -> some View {
    kitToolbar(title, title: { KitTitle(title, meta: meta, systemImage: systemImage, hue: hue, status: status) }, tools: tools)
  }

  /// The kit's toolbar only while `isPresented`: a column whose pages bring their own toolbar for some content (a
  /// database page) and take this one otherwise. Off, the view is left as it is, so a `kitToolbar` inside it is the
  /// window's. Switching rebuilds the content (as an `if` around the modifier does): tie it to what changes the page.
  ///
  /// ```swift
  /// Detail()
  ///   .kitToolbar(page.title, isPresented: !showsDatabase, title: { page.titleView }) { pageTools }
  /// ```
  public func kitToolbar<Title: View>(
    _ windowTitle: String, isPresented: Bool, @ViewBuilder title: () -> Title,
    @ToolbarSlotBuilder tools: () -> [ToolbarSlot]
  ) -> some View {
    modifier(
      ContOptionalKitToolbar(
        isPresented: isPresented, windowTitle: windowTitle, bar: KitToolbar(title: title, tools: tools)))
  }

  /// The kit's toolbar named by the rich title, only while `isPresented`.
  ///
  /// ```swift
  /// Detail().kitToolbar("History", isPresented: !isEmbedded, systemImage: "clock") { … }
  /// ```
  public func kitToolbar(
    _ title: String, isPresented: Bool, meta: [String] = [], systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, @ToolbarSlotBuilder tools: () -> [ToolbarSlot]
  ) -> some View {
    kitToolbar(
      title, isPresented: isPresented,
      title: { KitTitle(title, meta: meta, systemImage: systemImage, hue: hue, status: status) }, tools: tools)
  }
}

/// `kitToolbar(isPresented:)`: the bar while on, nothing of it while off.
private struct ContOptionalKitToolbar<Title: View>: ViewModifier {
  let isPresented: Bool
  let windowTitle: String
  let bar: KitToolbar<Title>

  func body(content: Content) -> some View {
    if isPresented {
      content.modifier(ContKitToolbar(windowTitle: windowTitle, bar: bar))
    } else {
      content
    }
  }
}

/// Places the bar: a top bar the content scrolls under, over the title bar on the Mac and in place
/// of the navigation bar on iPhone and iPad.
private struct ContKitToolbar<Title: View>: ViewModifier {
  let windowTitle: String
  let bar: KitToolbar<Title>

  func body(content: Content) -> some View {
    content
      .modifier(ContTopBar { bar })
      .preference(key: ContKitToolbarKey.self, value: true)
      .navigationTitle(windowTitle)
      .modifier(ContSystemToolbarAway())
  }
}

/// The bar as a top safe-area inset the content scrolls under, with a fade of the ground under it. On the Mac the view
/// runs up into the title bar, so the bar takes its place.
private struct ContTopBar<Bar: View>: ViewModifier {
  @ViewBuilder var bar: Bar

  func body(content: Content) -> some View {
    content
      .overlayPreferenceValue(ContPaneKey.self) { panes in ContTopBarFade(panes: panes) }
      .contEdgeBar(.top) { bar }
    #if os(macOS)
      .ignoresSafeArea(.container, edges: .top)
    #endif
  }
}

/// The bar's fade, over the content and under the bar: each pane that reaches the bar (`kitPane`) fades its own ground,
/// so the bar over a panel-ground pane stays the panel; the rest fades the window's. A single fade of the window's
/// white read as a lighter band (#fafafb) over a panel pane.
private struct ContTopBarFade: View {
  let panes: [ContPane]

  var body: some View {
    GeometryReader { proxy in
      let top = proxy.safeAreaInsets.top
      let spans = ContPaneEdges.topSpans(panes.map { (proxy[$0.bounds], $0.ground) }, width: proxy.size.width)
      ForEach(Array(spans.enumerated()), id: \.offset) { _, span in
        Rectangle()
          .fill(ContGroundFade(ground: span.ground == .content ? .kitWindow : .kitPanel, edge: .top))
          .frame(width: span.width, height: top)
          .position(x: span.midX, y: -top / 2)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

/// A soft glow of the window's ground around the title, so it stays readable over content passing under the bar.
private struct ContGroundGlow: ViewModifier {
  @Environment(\.colorScheme) private var scheme
  @Environment(\.kitMoreContrast) private var moreContrast

  func body(content: Content) -> some View {
    content.shadow(color: KitColor.window.color(scheme, moreContrast: moreContrast), radius: 4)
  }
}

/// Clears the system toolbar out of the kit's way. On the Mac one item keeps the toolbar (so the title bar keeps its
/// 52pt and the traffic lights sit centered on the kit's bar) while the title and the background go; clicks then reach
/// the kit's bar. The item is invisible, except while the sidebar is hidden: it then sits just after the traffic
/// lights, where it would take the clicks of a button the kit drew there, so it is the Show Sidebar button itself.
/// In full screen the toolbar hides: AppKit moves it to a window of its own over the top of the screen, which hid the
/// kit's bar. On iPhone and iPad the navigation bar hides.
private struct ContSystemToolbarAway: ViewModifier {
  @Environment(\.contShowSidebar) private var showSidebar
  @Environment(\.contShowsSidebarButton) private var showsSidebarButton
  @State private var isFullScreen = false

  func body(content: Content) -> some View {
    #if os(macOS)
      content
        .environment(\.contFullScreen, isFullScreen)
        .toolbar(isFullScreen ? .hidden : .automatic, for: .windowToolbar)
        .toolbar {
          KitToolbarItem(placement: .navigation) {
            Group {
              if let showSidebar, !isFullScreen {
                ContShowSidebarButton(action: showSidebar, isVisible: showsSidebarButton)
                  .transition(.identity)
              } else {
                Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
              }
            }
            .background { ContToolbarItemClicks(takesClicks: showSidebar != nil && !isFullScreen && showsSidebarButton) }
          }
        }
        .kitHidesSystemTitle()
        .modifier(ContToolbarBackgroundHidden())
        .background {
          ContTitlebarClear(isFullScreen: $isFullScreen).frame(width: 0, height: 0).accessibilityHidden(true)
        }
    #elseif os(Windows) || os(Linux)
      // As on the Mac: the content runs up into the title bar row (no toolbar background), which shows no title or
      // menu bar of its own; the bar takes the row up to the caption buttons and draws the menus (`ContMenuBar`).
      content
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .windowMenuBarVisibility(.hidden)
        .kitHidesSystemTitle()
    #else
      content.toolbar(.hidden, for: .navigationBar)
    #endif
  }
}

#if os(macOS)
  /// In a window an app hosts itself (an `NSHostingController`'s: a capture or debug window) hiding the toolbar's
  /// background doesn't reach the title bar, even when the controller bridges its toolbar (`sceneBridgingOptions`),
  /// and the title bar's own background drew over the kit's bar (a blank or faded bar). There, with the content under
  /// the title bar, the title bar goes transparent. It also says whether the window is in full screen: from the
  /// moment it starts going in to the moment it starts coming out, so the toolbar is back for the windowed title bar
  /// (and again once either is done).
  private struct ContTitlebarClear: NSViewRepresentable {
    @Binding var isFullScreen: Bool

    func makeNSView(context: Context) -> ContTitlebarClearView {
      let view = ContTitlebarClearView()
      view.onFullScreen = { isFullScreen = $0 }
      return view
    }

    func updateNSView(_ view: ContTitlebarClearView, context: Context) {
      view.onFullScreen = { isFullScreen = $0 }
    }
  }

  final class ContTitlebarClearView: NSView {
    var onFullScreen: (Bool) -> Void = { _ in }
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
      guard let window else { return }
      // A window restored in full screen; after the update that put the view there.
      if window.styleMask.contains(.fullScreen) {
        DispatchQueue.main.async { [weak self] in self?.onFullScreen(true) }
      }
      for (name, isFullScreen) in [
        (NSWindow.willEnterFullScreenNotification, true), (NSWindow.willExitFullScreenNotification, false),
        (NSWindow.didEnterFullScreenNotification, true), (NSWindow.didExitFullScreenNotification, false),
      ] {
        observers.append(
          NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onFullScreen(isFullScreen) }
          })
      }
      guard Self.clearsTitlebar(of: window) else { return }
      window.titlebarAppearsTransparent = true
    }

    /// A titled window the app made itself, whose content runs under its title bar. SwiftUI's scene windows are of its
    /// own class (`SwiftUI.AppKitWindow`), where the kit hides the toolbar's background instead.
    static func clearsTitlebar(of window: NSWindow) -> Bool {
      let isScene = NSStringFromClass(type(of: window)).hasPrefix("SwiftUI.")
      return !isScene && window.styleMask.contains(.titled) && window.styleMask.contains(.fullSizeContentView)
        && !window.titlebarAppearsTransparent
    }
  }

  /// Reports how far from the window's leading edge the view starts, up to `limit`: past it the reader doesn't care,
  /// so a sidebar resized wider than that updates nothing. AppKit's frames are read: a split view moves its columns
  /// without SwiftUI seeing a new frame, so the views it lays out (the columns the view is in) are watched too, and
  /// every step of a sidebar's slide is seen.
  struct ContWindowLeadingProbe: NSViewRepresentable {
    @Binding var minX: CGFloat
    let limit: CGFloat

    func makeNSView(context: Context) -> ContWindowLeadingView {
      let view = ContWindowLeadingView()
      view.limit = limit
      view.onChange = { minX = $0 }
      return view
    }

    func updateNSView(_ view: ContWindowLeadingView, context: Context) {
      view.limit = limit
      view.onChange = { minX = $0 }
      view.check()
    }
  }

  final class ContWindowLeadingView: NSView {
    var limit = CGFloat.infinity
    var onChange: (CGFloat) -> Void = { _ in }
    private var reported: CGFloat?
    private var observers: [NSObjectProtocol] = []

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
      if window != nil {
        var view = superview
        while let next = view {
          if next.superview is NSSplitView {
            observers.append(
              NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification, object: next, queue: nil
              ) { [weak self] _ in
                MainActor.assumeIsolated { self?.check(now: true) }
              })
          }
          view = next.superview
        }
      }
      check()
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
      super.setFrameOrigin(newOrigin)
      check(now: true)
    }

    override func setFrameSize(_ newSize: NSSize) {
      super.setFrameSize(newSize)
      check(now: true)
    }

    /// At once (`now`) when a frame changes, as a split view slides its column: a run loop later the bar was a step
    /// behind the column and the title overshot its room. A new window or SwiftUI's update reports after the update.
    func check(now: Bool = false) {
      guard window != nil else { return }
      let minX = min(convert(bounds, to: nil).minX.rounded(), limit)
      guard minX != reported else { return }
      reported = minX
      if now {
        onChange(minX)
      } else {
        // Not during the update that moved the view.
        DispatchQueue.main.async { [weak self] in self?.onChange(minX) }
      }
    }
  }

  /// Lets the clicks through the system toolbar's item while it shows nothing. AppKit's viewer around the item is
  /// 36pt wide however small the item is, and takes every click over it: it lay over what the kit's bar draws at the
  /// start of a column (Code's Run button got no clicks, and its right click was the toolbar's own menu). A hidden
  /// viewer keeps the toolbar, so the title bar keeps its 52pt.
  struct ContToolbarItemClicks: NSViewRepresentable {
    let takesClicks: Bool

    func makeNSView(context: Context) -> ContToolbarItemClicksView { ContToolbarItemClicksView() }

    func updateNSView(_ view: ContToolbarItemClicksView, context: Context) {
      view.takesClicks = takesClicks
      view.apply()
    }
  }

  final class ContToolbarItemClicksView: NSView {
    var takesClicks = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      apply()
    }

    func apply() {
      var ancestor = superview
      while let view = ancestor {
        if NSStringFromClass(type(of: view)).contains("NSToolbarItemViewer") {
          if view.isHidden == takesClicks { view.isHidden = !takesClicks }
          return
        }
        ancestor = view.superview
      }
    }
  }

  /// Hides the system toolbar's background, so the window's toolbar row takes clicks only on its items and the kit's
  /// views drawn in that row get the rest (`.kitToolbar`, `KitSidebar`'s hide button).
  struct ContToolbarBackgroundHidden: ViewModifier {
    func body(content: Content) -> some View {
      if #available(macOS 15.0, *) {
        content.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
      } else {
        content.toolbarBackground(.hidden, for: .windowToolbar)
      }
    }
  }
#endif

extension View {
  /// Hides the window toolbar's background on the Mac, so the view's own ground shows up through the title bar (a
  /// welcome that names the app itself, a pane drawn to the window's top). `kitToolbar`, `KitSidebar` and
  /// `KitSettings` do it themselves; does nothing elsewhere.
  ///
  /// ```swift
  /// WelcomeView().kitPane().kitHidesSystemTitle().kitHidesToolbarBackground()
  /// ```
  public func kitHidesToolbarBackground(_ hides: Bool = true) -> some View {
    #if os(macOS)
      modifier(ContToolbarBackgroundHiddenIf(hides: hides))
    #else
      self
    #endif
  }
}

#if os(macOS)
  private struct ContToolbarBackgroundHiddenIf: ViewModifier {
    let hides: Bool

    func body(content: Content) -> some View {
      if hides { content.modifier(ContToolbarBackgroundHidden()) } else { content }
    }
  }
#endif

/// The kit's Show Sidebar button: in its bar, and as the system toolbar's item (without the glass) elsewhere.
/// As the system toolbar's item it comes invisible as the sidebar starts to hide, so the toolbar lays it out (and moves
/// it along) while it can't be seen, and fades in where it is once the sidebar is gone: drawn as it came, it grew in
/// from the title bar's top.
struct ContShowSidebarButton: View {
  let action: ContShowSidebarAction
  var isVisible: Bool
  @State private var isShown = false

  var body: some View {
    ToolGroup(iconOnly: true) {
      Button("Show Sidebar", systemImage: "sidebar.left") { action() }
    }
    .help("Show Sidebar")
    .opacity(isShown ? 1 : 0)
    // Comes out from behind the traffic lights, where the sidebar's own button went. It leaves at once as the
    // sidebar comes back (an identity transition where it is the toolbar's item): sliding back, it crossed the
    // traffic lights beside the sidebar's returning button.
    .offset(x: isShown ? 0 : -ContMetrics.showSidebarItemWidth)
    .allowsHitTesting(isVisible)
    .accessibilityHidden(!isVisible)
    .onChange(of: isVisible, initial: true) { _, visible in
      withAnimation(.kit) { isShown = visible }
    }
  }
}

/// Set by `.kitToolbar`, so `kitSidebarToggle` puts its button in the kit's bar instead of the system toolbar.
struct ContKitToolbarKey: PreferenceKey {
  static let defaultValue = false
  static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

/// Shows the hidden sidebar; `kitSidebarToggle` sets it while the sidebar is hidden, for the kit's bar. Only whether
/// it is set matters to views, so any two compare equal.
struct ContShowSidebarAction: Equatable {
  let action: @MainActor () -> Void

  @MainActor func callAsFunction() { action() }

  static func == (lhs: Self, rhs: Self) -> Bool { true }
}

extension EnvironmentValues {
  @Entry var contShowSidebar: ContShowSidebarAction? = nil
  /// Whether the Show Sidebar button can be seen: once the sidebar has slid away.
  @Entry var contShowsSidebarButton = false
  /// Whether `kitSidebarToggle` can hide the sidebar beside this column: on the Mac the kit's bar keeps room for the
  /// Show Sidebar button where the column meets the traffic lights.
  @Entry var contHasSidebarToggle = false
  /// Whether the Mac window is in full screen, where the system toolbar is hidden and the traffic lights are away.
  @Entry var contFullScreen = false
  /// A hidden copy of views laid out only to be measured (the kit toolbar's forms): overlays and menus bound to the
  /// same state don't present from it, so the visible copy presents once.
  @Entry var contMeasuringCopy = false
}

// MARK: - Layout

/// The bar's three parts: what leads at its ideal width, the title, and the tools at the trailing edge. The tools
/// get the room the title leaves, down to their smallest form (everything folded); only then does the title give way.
struct ContToolbarLayout: Layout {
  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let frames = frames(width: proposal.width, subviews: subviews)
    return CGSize(width: proposal.width ?? frames.reduce(0) { max($0, $1.maxX) }, height: frames.map(\.height).max() ?? 0)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for (subview, frame) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.midY), anchor: .leading,
        proposal: ProposedViewSize(width: frame.width, height: bounds.height))
    }
  }

  private func frames(width: CGFloat?, subviews: Subviews) -> [CGRect] {
    guard subviews.count == 3 else { return subviews.map { _ in .zero } }
    let leading = subviews[0].sizeThatFits(.unspecified)
    let title = subviews[1].sizeThatFits(.unspecified)
    let toolsIdeal = subviews[2].sizeThatFits(.unspecified)
    let toolsMin = subviews[2].sizeThatFits(ProposedViewSize(width: 0, height: nil))
    let widths = ContToolbarLayoutMath.widths(
      available: width, leading: leading.width, title: title.width, toolsIdeal: toolsIdeal.width,
      toolsMin: toolsMin.width, spacing: spacing)
    let tools = subviews[2].sizeThatFits(ProposedViewSize(width: widths.tools, height: nil))
    let total = width ?? (widths.leading + widths.title + tools.width + spacing * 2)
    let titleX = widths.leading > 0 ? widths.leading + spacing : 0
    return [
      CGRect(x: 0, y: 0, width: widths.leading, height: leading.height),
      CGRect(x: titleX, y: 0, width: widths.title, height: title.height),
      CGRect(x: total - tools.width, y: 0, width: tools.width, height: tools.height),
    ]
  }
}

/// The bar's widths, apart from views.
enum ContToolbarLayoutMath {
  struct Widths: Equatable {
    var leading: CGFloat
    var title: CGFloat
    var tools: CGFloat
  }

  /// The title keeps its ideal width while the tools can still compact into what's left; past that it shrinks so the
  /// tools keep their smallest form. With no limit everything takes its ideal width.
  static func widths(
    available: CGFloat?, leading: CGFloat, title: CGFloat, toolsIdeal: CGFloat, toolsMin: CGFloat, spacing: CGFloat
  ) -> Widths {
    let leadingSpace = leading > 0 ? leading + spacing : 0
    guard let available else { return Widths(leading: leading, title: title, tools: toolsIdeal) }
    let room = max(0, available - leadingSpace - spacing)
    let titleWidth = min(title, max(0, room - toolsMin))
    return Widths(leading: leading, title: titleWidth, tools: max(0, room - titleWidth))
  }
}

// MARK: - Tools

/// The tools in the first form that fits: all labelled, all icon-only, then icon-only with the slots folded one by
/// one, lowest priority first, into the trailing "…" menu. Every form is measured hidden (with a stand-in for the
/// menu) and only the chosen one is drawn, so the real menu is built once (`ViewThatFits` builds every form's menu on
/// each pass, which never settles on iOS). The view's minimum is the smallest form, its ideal the widest.
private struct ContToolbarTools: View {
  let slots: [ToolbarSlot]
  @State private var widths: [Int: CGFloat] = [:]
  @State private var available: CGFloat = 0

  var body: some View {
    let steps = ContToolbarPlan.steps(priorities: slots.map(\.priority))
    let chosen = ContToolbarPlan.firstFit(widths: steps.indices.map { widths[$0] }, available: available)
    ContToolbarStep(slots: slots, step: steps[chosen], measuring: false)
      .frame(
        minWidth: widths[steps.count - 1], idealWidth: widths[0], maxWidth: .infinity, alignment: .trailing)
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { available = $0 }
      .background(alignment: .trailing) {
        ZStack {
          ForEach(steps.indices, id: \.self) { index in
            ContToolbarStep(slots: slots, step: steps[index], measuring: true)
              .fixedSize()
              .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { widths[index] = $0 }
          }
        }
        .hidden()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        // A tool's popover, sheet or menu presents from the visible tools only, not from every hidden copy.
        .environment(\.contMeasuringCopy, true)
      }
  }
}

/// One form of the tools: the slots that are out, then "…" with the folded ones' menus (a stand-in of the same size
/// while measuring).
private struct ContToolbarStep: View {
  let slots: [ToolbarSlot]
  let step: ContToolbarPlan.Step
  let measuring: Bool

  var body: some View {
    HStack(spacing: KitMetrics.gutter) {
      ForEach(slots.indices.filter { !step.folded.contains($0) }, id: \.self) { index in
        slots[index].content()
      }
      if !step.folded.isEmpty {
        if measuring {
          ToolGroup(iconOnly: true) { Button("More", systemImage: "ellipsis") {} }
        } else {
          ToolbarOverflow {
            ForEach(step.folded.sorted(), id: \.self) { index in
              slots[index].menu?()
            }
          }
        }
      }
    }
    .environment(\.kitToolbarIconOnly, !step.labelled)
    .fixedSize()
  }
}

// MARK: - Window dragging

/// The bar's empty space moves the window, and a double click zooms it (or minimizes it, per System Settings), as the
/// title bar it stands in for. Mac only; macOS 15 on.
private struct ContWindowDragArea: View {
  var body: some View {
    #if os(macOS)
      if #available(macOS 15.0, *) {
        Color.clear
          .contentShape(Rectangle())
          .gesture(WindowDragGesture())
          .onTapGesture(count: 2) { ContPlatform.titleBarDoubleClick() }
          .allowsWindowActivationEvents(true)
      }
    #endif
  }
}

#if os(iOS)
  /// A pushed view's bar draws the kit's Back (apps hide the system one with `.navigationBarBackButtonHidden`), which
  /// also turns off the swipe from the edge (and from anywhere on iOS 26) that pops it. Every navigation controller
  /// takes the pop gestures' delegate back, so a swipe pops whenever there is something to pop.
  extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
      super.viewDidLoad()
      interactivePopGestureRecognizer?.delegate = self
      if #available(iOS 26.0, *) {
        interactiveContentPopGestureRecognizer?.delegate = self
      }
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
      viewControllers.count > 1
    }
  }
#endif

#Preview("Kit toolbar") {
  VStack(spacing: 16) {
    ForEach([720.0, 420, 260], id: \.self) { width in
      KitToolbar("History", meta: ["main", "2 to push"], systemImage: "clock") {
        ToolbarSlot(priority: 1) {
          ToolGroup {
            Button("Fetch", systemImage: "arrow.down.circle") {}
            Button("Push", systemImage: "arrow.up") {}
          }
        } menu: {
          Button("Fetch", systemImage: "arrow.down.circle") {}
          Button("Push", systemImage: "arrow.up") {}
        }
        Button("Commit", systemImage: "checkmark") {}.buttonStyle(.kitPrimary)
      }
      .frame(width: width)
      .background(.kitWindow)
    }
  }
  .padding()
  .componentKit()
}
