import SwiftUI

// The toolbar's pieces (the Toolbars and Toolbar compacting boards): the rich title on the leading side, tools in card
// groups, the "…" of what didn't fit and the compacting rule (labelled → icon-only → folded by priority into "…"). The
// window's own toolbar is `kitToolbar` (KitToolbar.swift), which compacts by that rule; the pieces also serve a system
// toolbar.

// MARK: - Title

/// The toolbar's rich title: the live icon (the running operation's glyph and ring while work runs), the name and one
/// status line. Put it at the navigation placement, or at the start of a pane's own title bar.
///
/// ```swift
/// .toolbar {
///   ToolbarItem(placement: .navigation) {
///     KitTitle("History", meta: ["main", "2 commits to push"], systemImage: "clock", status: pushStatus)
///   }
/// }
/// ```
///
/// For another icon (an app tile, an avatar), use `RichHeader(…, size: .title)`.
public struct KitTitle: View {
  var title: String
  var meta: [String]
  var systemImage: String
  var hue: Hue
  var status: WorkStatus

  /// A title with a meta line of parts joined by " · ".
  public init(
    _ title: some StringProtocol, meta: [String] = [], systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle
  ) {
    self.title = String(title)
    self.meta = meta
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
  }

  /// A title with a one-part meta line.
  public init(
    _ title: some StringProtocol, meta: String, systemImage: String, hue: Hue = .accent, status: WorkStatus = .idle
  ) {
    self.init(title, meta: [meta], systemImage: systemImage, hue: hue, status: status)
  }

  public var body: some View {
    RichHeader(title, meta: meta, size: .title, systemImage: systemImage, hue: hue, status: status)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
  }
}

// MARK: - In a system toolbar

/// A toolbar item for kit views (`KitTitle`, `ToolGroup`, `KitSegmented`, a round button): they draw their own cards,
/// so on macOS 26 and iOS 26 the toolbar's shared glass stays out from behind them. Before, it's a plain
/// `ToolbarItem`. A kit menu opens from a kit view here (a `ToolGroup`'s button, a `KitMenuButton`), not from a bare
/// `Button`: SwiftUI makes that a native bar button and drops the menu's anchor (see `.kitMenu(isPresented:)`).
/// In an iOS bar the content takes its own width, up to 240pt on iPhone (420 on iPad), so a long `KitTitle`
/// truncates instead of shrinking to its tile.
///
/// ```swift
/// .toolbar {
///   KitToolbarItem(placement: .primaryAction) {
///     ToolGroup { Button("Fetch", systemImage: "arrow.down.circle") { … } }
///   }
/// }
/// ```
public struct KitToolbarItem<Content: View>: ToolbarContent {
  var placement: ToolbarItemPlacement
  var content: () -> Content

  public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: @escaping () -> Content) {
    self.placement = placement
    self.content = content
  }

  public var body: some ToolbarContent {
    ToolbarItem(placement: placement) { ContToolbarItemWidth(content: content()) }.kitToolbarItem()
  }
}

/// A kit view in an iOS bar at its own width, up to 240pt on iPhone (420 on iPad): the bar measures an item at zero
/// width, where a view whose text is flexible (a `KitTitle`) came back as its tile alone. The Mac's toolbar gives
/// the room itself.
struct ContToolbarItemWidth<Content: View>: View {
  var content: Content
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    #if os(iOS)
      ContIdealWidthLayout(max: idiom == .phone ? 240 : 420) { content }
    #else
      content
    #endif
  }
}

/// One view at its ideal width, capped, whatever width it is offered.
struct ContIdealWidthLayout: Layout {
  var max: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard let child = subviews.first else { return .zero }
    let width = Swift.min(child.sizeThatFits(.unspecified).width, max)
    return child.sizeThatFits(ProposedViewSize(width: width, height: proposal.height))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
  }
}

extension ToolbarContent {
  /// Hides the toolbar's shared glass behind this content on macOS 26 and iOS 26 (kit views draw their own cards);
  /// nothing before. For a `ToolbarItem` or `ToolbarItemGroup` you build yourself; `KitToolbarItem` does it for you.
  ///
  /// ```swift
  /// ToolbarItemGroup(placement: .primaryAction) { … }.kitToolbarItem()
  /// ```
  public func kitToolbarItem() -> some ToolbarContent {
    SharedBackgroundHidden(content: self)
  }
}

/// `kitToolbarItem()`'s content. Internal so an app's optimizer can't see through it to the `if #available`'s
/// type: that type's descriptor is private to this module, and apps targeting below macOS 26 failed to link in
/// Release.
struct SharedBackgroundHidden<Content: ToolbarContent>: ToolbarContent {
  var content: Content

  var body: some ToolbarContent {
    #if os(visionOS) || os(tvOS)
      content
    #else
      if #available(macOS 26.0, iOS 26.0, *) {
        content.sharedBackgroundVisibility(.hidden)
      } else {
        content
      }
    #endif
  }
}

extension View {
  /// Names the view in the toolbar with the kit's rich title (at the navigation placement, without the glass) and
  /// takes the system's own title out of the toolbar (macOS 15 and iOS 18 on; the window keeps its title for the
  /// Window menu and Mission Control).
  ///
  /// ```swift
  /// HistoryView()
  ///   .kitToolbarTitle("History", meta: ["main", "2 commits to push"], systemImage: "clock", status: fetch)
  /// ```
  public func kitToolbarTitle(
    _ title: String, meta: [String] = [], systemImage: String, hue: Hue = .accent, status: WorkStatus = .idle
  ) -> some View {
    kitToolbarTitle(title) {
      KitTitle(title, meta: meta, systemImage: systemImage, hue: hue, status: status)
    }
  }

  /// Puts any title view (a `KitTitle`, a `RichHeader(…, size: .title)` with an avatar) at the toolbar's navigation
  /// placement without the glass, and takes the system title out of the toolbar; `windowTitle` stays the window's.
  /// On macOS 26 a flexible space follows the title, so the view's tools sit at the trailing edge (without the
  /// system title, the toolbar would line them up right after it).
  ///
  /// ```swift
  /// Detail().kitToolbarTitle(host.name) { RichHeader(host.name, size: .title, icon: { Avatar(…) }, meta: { … }, accessory: {}) }
  /// ```
  public func kitToolbarTitle<Title: View>(_ windowTitle: String, @ViewBuilder content: @escaping () -> Title)
    -> some View
  {
    navigationTitle(windowTitle)
      .toolbar {
        KitToolbarItem(placement: .navigation, content: content)
        ContTitleSpace()
      }
      .kitHidesSystemTitle()
  }

  /// Takes the system's title out of the toolbar while `hides` is true, when a pane names itself with its own
  /// `KitTitle` (or a video fills the window). The window keeps its title for the Window menu and Mission Control.
  /// Turning it on and off keeps the view's identity and state. macOS 14 hides the window's title instead; iOS 17
  /// keeps it.
  ///
  /// ```swift
  /// Player().kitHidesSystemTitle(isPlaying)
  /// ```
  @ViewBuilder
  public func kitHidesSystemTitle(_ hides: Bool = true) -> some View {
    #if os(tvOS)
      self
    #else
    if #available(macOS 15.0, iOS 18.0, *) {
      toolbar(removing: hides ? .title : nil)
    } else {
      background { ContWindowTitleHidden(hides: hides) }
    }
    #endif
  }

  /// Draws a tool as on (a toggled tool: the inspector shown, a filter applied), in a `ToolGroup` or with the
  /// `.kitTool` button style.
  ///
  /// ```swift
  /// ToolGroup { Button("Inspector", systemImage: "sidebar.right") { showsInspector.toggle() }.kitToolOn(showsInspector) }
  /// ```
  public func kitToolOn(_ isOn: Bool) -> some View {
    environment(\.contToolIsOn, isOn)
  }
}

/// The flexible space after the kit's title on macOS 26, which keeps the tools at the trailing edge.
struct ContTitleSpace: ToolbarContent {
  var body: some ToolbarContent {
    #if os(macOS)
      if #available(macOS 26.0, *) {
        ToolbarSpacer(.flexible)
      }
    #endif
  }
}

/// A tool on its own, as inside a `ToolGroup`: 26pt (36 on touch), 9pt corners, a fill on hover, press and while on
/// (`.kitToolOn(_:)`). For a toolbar that lays out its own tools.
///
/// ```swift
/// Button("Inspector", systemImage: "sidebar.right") { … }.buttonStyle(.kitTool).kitToolOn(showsInspector)
/// Button("Filter", systemImage: "line.3.horizontal.decrease") { … }.buttonStyle(.kitToolIcon)
/// ```
public struct KitToolButtonStyle: ButtonStyle {
  var iconOnly: Bool

  public init(iconOnly: Bool = false) { self.iconOnly = iconOnly }

  public func makeBody(configuration: Configuration) -> some View {
    ContToolStyleButton(configuration: configuration, iconOnly: iconOnly)
  }
}

/// A `.kitTool` button, icon-only also while a `KitToolbar` has compacted.
private struct ContToolStyleButton: View {
  let configuration: ButtonStyleConfiguration
  let iconOnly: Bool
  @Environment(\.kitToolbarIconOnly) private var toolbarIconOnly

  var body: some View {
    let iconOnly = iconOnly || toolbarIconOnly
    ContToolButtonStyle(iconOnly: iconOnly).makeBody(configuration: configuration)
      .labelStyle(ContToolLabelStyle(iconOnly: iconOnly))
  }
}

extension ButtonStyle where Self == KitToolButtonStyle {
  /// A tool with its icon and title.
  public static var kitTool: KitToolButtonStyle { KitToolButtonStyle() }
  /// A tool showing its icon alone (the title stays for accessibility).
  public static var kitToolIcon: KitToolButtonStyle { KitToolButtonStyle(iconOnly: true) }
}

// MARK: - Groups

/// A card of tools: 32pt (44 on touch), 12pt corners, each tool a 26pt button that fills on hover. Buttons inside take
/// the tool look; `iconOnly` shows their icons alone (the title stays for accessibility and the tooltip), as does a
/// `KitToolbar` once it compacts.
///
/// ```swift
/// ToolGroup {
///   Button("Fetch", systemImage: "arrow.down.circle") { … }
///   Button("Pull", systemImage: "arrow.down") { … }
/// }
/// ```
public struct ToolGroup<Content: View>: View {
  var iconOnly: Bool
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitToolbarIconOnly) private var toolbarIconOnly

  public init(iconOnly: Bool = false, @ViewBuilder content: () -> Content) {
    self.iconOnly = iconOnly
    self.content = content()
  }

  public var body: some View {
    let iconOnly = iconOnly || toolbarIconOnly
    HStack(spacing: 2) { content }
      .environment(\.contInToolGroup, true)
      .buttonStyle(ContToolButtonStyle(iconOnly: iconOnly))
      .labelStyle(ContToolLabelStyle(iconOnly: iconOnly))
      .menuStyle(.button)
      .menuIndicator(.hidden)
      .padding(.horizontal, idiom.size(3, touch: 4))
      .frame(height: ContMetrics.toolGroupHeight(idiom))
      .kitSurface(.card, cornerRadius: ContMetrics.toolGroupRadius(idiom))
      .fixedSize()
  }
}

/// A tool's icon and title, 6pt apart; icon-only keeps just the icon.
struct ContToolLabelStyle: LabelStyle {
  var iconOnly: Bool

  func makeBody(configuration: Configuration) -> some View {
    if iconOnly {
      configuration.icon
    } else {
      HStack(spacing: 6) {
        configuration.icon
        configuration.title
      }
    }
  }
}

/// The trailing "…" of a compacted toolbar: the kit's menu of what didn't fit, each item with its icon and label.
/// Its rows are kit menu rows: `Button`, `Toggle`, `Divider`, `KitMenuOptions` (for a picker), `KitSubmenu`.
///
/// ```swift
/// ToolbarOverflow {
///   Button("Stash", systemImage: "tray.and.arrow.down") { … }
///   KitSubmenu("Appearance", systemImage: "circle.lefthalf.filled") { KitMenuOptions(selection: $appearance, options: …) }
/// }
/// ```
public struct ToolbarOverflow<Content: View>: View {
  var content: Content
  @State private var isOpen = false

  public init(@ViewBuilder content: () -> Content) { self.content = content() }

  public var body: some View {
    ToolGroup(iconOnly: true) {
      Button("More", systemImage: "ellipsis") { isOpen.toggle() }
        .kitToolOn(isOpen)
        .kitMenu(isPresented: $isOpen) { content }
        .accessibilityLabel("More")
    }
  }
}

/// The compacting rule, apart from views.
enum ContToolbarPlan {
  struct Step: Hashable {
    var labelled: Bool
    var folded: Set<Int>
  }

  /// Every form the toolbar steps through, widest first: labelled; icon-only; then icon-only with one more tool folded
  /// each step, lowest priority first (the later tool first on a tie). `nil` never folds (a slot without a menu).
  static func steps(priorities: [Int?]) -> [Step] {
    var steps = [Step(labelled: true, folded: []), Step(labelled: false, folded: [])]
    let order = priorities.enumerated()
      .compactMap { index, priority in priority.map { (index, $0) } }
      .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0 > $1.0 }
      .map(\.0)
    var folded = Set<Int>()
    for index in order {
      folded.insert(index)
      steps.append(Step(labelled: false, folded: folded))
    }
    return steps
  }

  /// The first form whose measured width fits `available`, or the last (the smallest) when none does or none is
  /// measured yet. A form not measured yet doesn't fit.
  static func firstFit(widths: [CGFloat?], available: CGFloat) -> Int {
    widths.firstIndex { width in width.map { $0 <= available + 0.5 } ?? false } ?? max(0, widths.count - 1)
  }
}

#Preview("Toolbar") {
  VStack(alignment: .leading, spacing: 16) {
    KitTitle("History", meta: ["main", "2 commits to push", "1 to pull"], systemImage: "clock", status: .working(progress: 0.4))
    ToolGroup {
      Button("Fetch", systemImage: "arrow.down.circle") {}
      Button("Pull", systemImage: "arrow.down") {}
    }
    ToolbarOverflow {
      Button("Stash", systemImage: "tray.and.arrow.down") {}
    }
  }
  .padding()
  .componentKit()
}
