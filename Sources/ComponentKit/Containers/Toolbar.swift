import SwiftUI

// The toolbar (the Toolbars and Toolbar compacting boards): the rich title on the leading side, tools in card groups,
// and a toolbar that compacts in steps as the window narrows: labelled → icon-only → folded by priority into "…".
// The window's own toolbar is `kitToolbar` (KitToolbar.swift); the pieces here also serve a system toolbar.

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
    ToolbarItem(placement: placement) { content() }.kitToolbarItem()
  }
}

extension ToolbarContent {
  /// Hides the toolbar's shared glass behind this content on macOS 26 and iOS 26 (kit views draw their own cards);
  /// nothing before. For a `ToolbarItem` or `ToolbarItemGroup` you build yourself; `KitToolbarItem` does it for you.
  ///
  /// ```swift
  /// ToolbarItemGroup(placement: .primaryAction) { … }.kitToolbarItem()
  /// ```
  @ToolbarContentBuilder
  public func kitToolbarItem() -> some ToolbarContent {
    if #available(macOS 26.0, iOS 26.0, *) {
      sharedBackgroundVisibility(.hidden)
    } else {
      self
    }
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
    if #available(macOS 15.0, iOS 18.0, *) {
      toolbar(removing: hides ? .title : nil)
    } else {
      background { ContWindowTitleHidden(hides: hides) }
    }
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
      .padding(.horizontal, idiom.isTouch ? 4 : 3)
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

/// The trailing "…" of a compacted toolbar: a menu of what didn't fit, each item with its icon and label.
///
/// ```swift
/// ToolbarOverflow {
///   Button("Stash", systemImage: "tray.and.arrow.down") { … }
/// }
/// ```
public struct ToolbarOverflow<Content: View>: View {
  @ViewBuilder var content: Content

  public init(@ViewBuilder content: () -> Content) { self.content = content() }

  public var body: some View {
    ToolGroup(iconOnly: true) {
      Menu {
        content
          .labelStyle(.titleAndIcon)
      } label: {
        Label("More", systemImage: "ellipsis")
      }
      .accessibilityLabel("More")
    }
  }
}

// MARK: - Compacting

/// One item of a `CompactingToolbar`: its title and symbol (the three forms are labelled, icon-only, and a row of the
/// "…" menu), an optional count (Push 2), its priority (lower folds first) and its role. `KitTool.gap` starts a new
/// card.
public struct KitTool: Identifiable {
  public enum Role: Hashable, Sendable {
    /// An ordinary tool in a card.
    case tool
    /// The view's one leading action: filled with the accent, it keeps its label and never folds.
    case primary
    /// A tool whose label is red.
    case destructive
  }

  public var id: String { isGap ? "gap.\(gapIndex)" : title }
  public var title: String
  public var systemImage: String
  public var count: Int?
  public var priority: Int
  public var role: Role
  public var isOn: Bool
  public var isDisabled: Bool
  var action: @MainActor () -> Void
  var isGap = false
  var gapIndex = 0

  public init(
    _ title: String, systemImage: String, count: Int? = nil, priority: Int = 0, role: Role = .tool,
    isOn: Bool = false, isDisabled: Bool = false, action: @escaping @MainActor () -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.count = count
    self.priority = priority
    self.role = role
    self.isOn = isOn
    self.isDisabled = isDisabled
    self.action = action
  }

  /// Ends the current card; the tools after it start a new one.
  public static var gap: KitTool {
    var tool = KitTool("", systemImage: "", action: {})
    tool.isGap = true
    return tool
  }
}

/// Builds a `CompactingToolbar`'s tools.
@resultBuilder
public enum KitToolBuilder {
  public static func buildExpression(_ tool: KitTool) -> [KitTool] { [tool] }
  public static func buildExpression(_ tools: [KitTool]) -> [KitTool] { tools }
  public static func buildBlock(_ parts: [KitTool]...) -> [KitTool] { parts.flatMap { $0 } }
  public static func buildOptional(_ part: [KitTool]?) -> [KitTool] { part ?? [] }
  public static func buildEither(first: [KitTool]) -> [KitTool] { first }
  public static func buildEither(second: [KitTool]) -> [KitTool] { second }
  public static func buildArray(_ parts: [[KitTool]]) -> [KitTool] { parts.flatMap { $0 } }
}

/// A toolbar that compacts in steps as its room narrows: every tool labelled → every tool icon-only (labels go all at
/// once; the title shows on hover) → tools fold into the trailing "…" menu by priority, lowest first. The primary
/// action never folds and keeps its label. The same rule on the Mac, iPad and iPhone.
///
/// ```swift
/// CompactingToolbar {
///   KitTool("Fetch", systemImage: "arrow.down.circle", priority: 1) { fetch() }
///   KitTool("Pull", systemImage: "arrow.down", priority: 2) { pull() }
///   KitTool("Push", systemImage: "arrow.up", count: 2, priority: 3) { push() }
///   KitTool.gap
///   KitTool("Stash", systemImage: "tray.and.arrow.down") { stash() }
///   KitTool("Commit", systemImage: "checkmark", role: .primary) { commit() }
/// }
/// ```
///
/// Put it in a pane's own title bar or a bar under the toolbar; a system toolbar sizes its items to their ideal width
/// and overflows on its own.
public struct CompactingToolbar: View {
  let tools: [KitTool]

  public init(@KitToolBuilder tools: () -> [KitTool]) {
    var index = 0
    self.tools = tools().map { tool in
      guard tool.isGap else { return tool }
      var gap = tool
      gap.gapIndex = index
      index += 1
      return gap
    }
  }

  public var body: some View {
    let steps = ContToolbarPlan.steps(priorities: tools.map { $0.isGap || $0.role == .primary ? nil : $0.priority })
    ViewThatFits(in: .horizontal) {
      ForEach(steps, id: \.self) { step in
        ContToolbarRow(tools: tools, step: step)
      }
    }
  }
}

/// One form of a compacting toolbar: labelled or not, with some tools folded into "…".
private struct ContToolbarRow: View {
  let tools: [KitTool]
  let step: ContToolbarPlan.Step

  var body: some View {
    let groups = ContToolbarPlan.groups(isGap: tools.map(\.isGap), isPrimary: tools.map { $0.role == .primary }, folded: step.folded)
    HStack(spacing: KitMetrics.gutter) {
      ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
        if group.count == 1, tools[group[0]].role == .primary {
          ContPrimaryTool(tool: tools[group[0]])
        } else {
          ToolGroup(iconOnly: !step.labelled) {
            ForEach(group, id: \.self) { index in
              ContKitToolButton(tool: tools[index], labelled: step.labelled)
            }
          }
        }
      }
      if !step.folded.isEmpty {
        ToolbarOverflow {
          ForEach(step.folded.sorted(), id: \.self) { index in
            let tool = tools[index]
            Button(role: tool.role == .destructive ? .destructive : nil, action: tool.action) {
              Label(tool.count.map { "\(tool.title) (\($0))" } ?? tool.title, systemImage: tool.systemImage)
            }
            .disabled(tool.isDisabled)
          }
        }
      }
    }
    .fixedSize()
  }
}

private struct ContKitToolButton: View {
  let tool: KitTool
  let labelled: Bool

  var body: some View {
    Button(role: tool.role == .destructive ? .destructive : nil, action: tool.action) {
      HStack(spacing: labelled ? 6 : 4) {
        Image(systemName: tool.systemImage)
        if labelled { Text(tool.title) }
        if let count = tool.count {
          // A count rides inside the tool, a bare semibold number in orange (it waits on you).
          Text("\(count)")
            .kitFont(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(Hue.orange.text)
            .monospacedDigit()
        }
      }
      .padding(.horizontal, !labelled && tool.count != nil ? 6 : 0)
    }
    .buttonStyle(ContToolButtonStyle(iconOnly: !labelled && tool.count == nil))
    .environment(\.contToolIsOn, tool.isOn)
    .disabled(tool.isDisabled)
    .accessibilityLabel(tool.title)
    .modifier(ContIconOnlyHelp(title: tool.title, systemImage: tool.systemImage, isOn: !labelled))
  }
}

/// An icon-only tool shows its label in the kit's tooltip.
private struct ContIconOnlyHelp: ViewModifier {
  let title: String
  let systemImage: String
  let isOn: Bool

  func body(content: Content) -> some View {
    if isOn {
      content.kitHelp(title, systemImage: systemImage)
    } else {
      content
    }
  }
}

/// The primary action in a toolbar: the accent card, its label always shown.
private struct ContPrimaryTool: View {
  let tool: KitTool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    Button(action: tool.action) {
      Label(tool.title, systemImage: tool.systemImage)
        .labelStyle(ContToolLabelStyle(iconOnly: false))
    }
    .buttonStyle(.kitPrimary)
    .controlSize(.regular)
    .disabled(tool.isDisabled)
    .clipShape(RoundedRectangle(cornerRadius: ContMetrics.toolGroupRadius(idiom), style: .continuous))
    .frame(height: ContMetrics.toolGroupHeight(idiom))
    .fixedSize()
  }
}

/// The compacting rule, apart from views.
enum ContToolbarPlan {
  struct Step: Hashable {
    var labelled: Bool
    var folded: Set<Int>
  }

  /// Every form the toolbar steps through, widest first: labelled; icon-only; then icon-only with one more tool folded
  /// each step, lowest priority first (the later tool first on a tie). `nil` never folds (the primary action, gaps).
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

  /// The cards a step draws: runs of tools between gaps, minus the folded ones, with each primary action split out as
  /// its own card. Empty runs disappear.
  static func groups(isGap: [Bool], isPrimary: [Bool], folded: Set<Int>) -> [[Int]] {
    var groups: [[Int]] = []
    var current: [Int] = []
    func close() {
      if !current.isEmpty { groups.append(current) }
      current = []
    }
    for index in isGap.indices {
      if isGap[index] {
        close()
      } else if isPrimary[index] {
        close()
        groups.append([index])
      } else if !folded.contains(index) {
        current.append(index)
      }
    }
    close()
    return groups
  }
}

#Preview("Toolbar") {
  VStack(alignment: .leading, spacing: 16) {
    KitTitle("History", meta: ["main", "2 commits to push", "1 to pull"], systemImage: "clock", status: .working(progress: 0.4))
    ToolGroup {
      Button("Fetch", systemImage: "arrow.down.circle") {}
      Button("Pull", systemImage: "arrow.down") {}
    }
    ForEach([560.0, 380, 200], id: \.self) { width in
      CompactingToolbar {
        KitTool("Fetch", systemImage: "arrow.clockwise", priority: 1) {}
        KitTool("Pull", systemImage: "arrow.down", priority: 2) {}
        KitTool("Push", systemImage: "arrow.up", count: 2, priority: 3) {}
        KitTool.gap
        KitTool("Branch", systemImage: "arrow.triangle.branch") {}
        KitTool("Stash", systemImage: "tray.and.arrow.down") {}
        KitTool("Commit", systemImage: "checkmark", role: .primary) {}
      }
      .frame(width: width, alignment: .trailing)
    }
  }
  .padding()
  .componentKit()
}
