import SwiftUI

// Sticky sections: a section of a scrolling stack (a sidebar's cards) that stays in view when it scrolls out of the
// visible area, above or below it. `.kitSticky(top:bottom:)` marks the section as a container value, so the
// `KitLazyStack` around it knows before it builds anything: it keeps a section that may show at an edge built while
// far off. The stack's item reports where the section sits in the stack (a frame that doesn't move as the stack
// scrolls), the section reports its title, and the host (the sidebar) puts them in one table in the environment.
// Each frame, every sticky view works out from the table and its own place in the scroll view where it shows, in a
// `visualEffect`: scrolling changes no state. Only whether a view is stuck is state (its z-order and its stuck card),
// and that changes as it sticks or comes free. While the user scrolls or drags a row, and for half a second after,
// nothing sticks at the top: the sections scroll in place (and the views skip the work), and the stuck ones come back
// once the list holds still. Sections below the visible area never move: a compact copy of each waits in a dock over
// the bottom bar, outside the scroll view (the sections send their copies up as a preference), until the section
// scrolls up to it. Before macOS 15 and iOS 18 the stack is a `LazyVStack` and nothing sticks.

/// What a sticky section keeps in view once it has scrolled up past the visible area (`.kitSticky(top:bottom:)`).
public enum KitStickyTop: Hashable, Sendable {
  /// The whole section stays at the top while the rest scrolls past: for short sections, a few rows.
  case content
  /// Its title stays at the top, as a card of its own; clicking it scrolls back to the section.
  case title
  /// Its title stays until the section's last row leaves; the next title pushes it up.
  case titleWhileVisible
  /// The section scrolls away with the rest.
  case none
}

/// What a sticky section keeps in view while it is still below the visible area (`.kitSticky(top:bottom:)`): a
/// compact copy, one line in the dock over the sidebar's bottom bar; clicking it scrolls to the section.
public enum KitStickyBottom: Hashable, Sendable {
  /// Its line also holds its rows, as small buttons (a `SidebarRow` shows its icon and trailing views).
  case content
  /// Its line shows its icon, title and meta.
  case title
  /// Nothing waits; the list ends at the edge.
  case none
}

extension View {
  /// Keeps this section in view when it scrolls out of the visible area of a `KitSidebar`: at the top once it has
  /// scrolled up past it, and while it is still below it as a compact line in the dock over the bottom bar. Stuck
  /// sections stack in their own order under the sidebar's top bar as opaque cards, and a stuck title or a docked
  /// line scrolls to its section when clicked. The dock takes at most 40% of the sidebar. Sections without it never
  /// stick.
  ///
  /// ```swift
  /// KitSection("Repositories", meta: ["72 repositories"], systemImage: "folder") { rows }
  ///   .kitSticky()                                  // the title while the list is in view
  /// KitSection("atlas", meta: ["main", "4 changed"], systemImage: "arrow.triangle.branch") { pages }
  ///   .kitSticky(bottom: .content)                  // the open repository and its pages wait in the dock
  /// KitSection("Branches", meta: ["3 local"], glyph: { BranchGlyph() }) { branches }
  ///   .kitSticky(bottom: .title)
  /// ```
  ///
  /// Use it on the sections directly in the sidebar (through `ForEach`, `Group` and your own views). It needs macOS
  /// 15 or iOS 18; before them the sections scroll as usual.
  public func kitSticky(top: KitStickyTop = .titleWhileVisible, bottom: KitStickyBottom = .none) -> some View {
    modifier(ContStickyMark(sticky: ContSticky(top: top, bottom: bottom)))
  }
}

/// A view's sticky options.
struct ContSticky: Hashable, Sendable {
  var top: KitStickyTop
  var bottom: KitStickyBottom

  /// It may show at an edge from anywhere in the stack, so the stack keeps it built while far off. A title kept
  /// while visible is only stuck while its section is on screen.
  var isPinned: Bool { top == .content || top == .title || bottom != .none }
}

@available(macOS 15.0, iOS 18.0, *)
extension ContainerValues {
  @Entry var contSticky: ContSticky? = nil
}

private struct ContStickyMark: ViewModifier {
  let sticky: ContSticky

  func body(content: Content) -> some View {
    if #available(macOS 15.0, iOS 18.0, *) {
      content.containerValue(\.contSticky, sticky)
    } else {
      content
    }
  }
}

// MARK: - Layout

/// The part of a sticky view that shows when it's stuck.
enum ContStickyPart: Hashable, Sendable {
  case title, content
}

enum ContStickyEdge: Hashable, Sendable {
  case top, bottom
}

/// Where a stuck view shows: its edge, its part, and the part's top in the stack's space.
struct ContStickyPlacement: Equatable, Sendable {
  var edge: ContStickyEdge
  var part: ContStickyPart
  var y: CGFloat
}

/// A stuck view's state, without the per-frame position: what draws it differently while stuck.
struct ContStickyState: Hashable, Sendable {
  var edge: ContStickyEdge
  var part: ContStickyPart
  /// Its place among the sticky views.
  var order = 0
  /// The last stuck view on its edge, the farthest from it: the fade past the stack runs from it.
  var isLast = false

  /// Stuck views draw over the rest; in the top stack the first over the next (whose card scrolls on under it), in
  /// the bottom stack the last; the bottom stack over the top one, whose rows scroll on under it.
  var zIndex: Double { edge == .top ? Double(1000 - order) : Double(1001 + order) }
}

/// A sticky view's place in the stack's space, which doesn't move as the stack scrolls.
struct ContStickyItem: Equatable, @unchecked Sendable {
  var id: AnyHashable
  var sticky: ContSticky
  var minY: CGFloat
  var maxY: CGFloat
  /// Its title's top, and the title's height as a card of its own. A view without a title (not a `KitSection`)
  /// shows whole either way.
  var titleTop: CGFloat? = nil
  var titleHeight: CGFloat? = nil
  /// The height of its copy in the bottom dock, once the dock has drawn it.
  var copyHeight: CGFloat? = nil

  /// The top and height of `part`.
  func block(_ part: ContStickyPart) -> (top: CGFloat, height: CGFloat) {
    if part == .title, let titleTop, let titleHeight { return (titleTop, titleHeight) }
    return (minY, maxY - minY)
  }
}

/// Every sticky view of a stack, in the stack's order, with the bars it sticks under. Pure: the views work out
/// their places from it each frame, and the tests check it.
struct ContStickyTable: Equatable, @unchecked Sendable {
  var items: [ContStickyItem] = []
  /// The part of the scroll view clear of its bars (the Mac's title bar over a sidebar, the sidebar's bottom bar), in
  /// its own space: its whole frame, as its content insets reach beyond it.
  var clearTop: CGFloat = 0
  var clearBottom: CGFloat = 0
  /// The gap between stuck views.
  var spacing: CGFloat = 8
  /// The gaps from the clear area's ends: the stack's own padding there.
  var topGap: CGFloat = 2
  var bottomGap: CGFloat = 0
  /// The user is scrolling or dragging (or was half a second ago): every item stays in place.
  var isPaused = false

  /// The share of the visible height the bottom dock may take; past it, the farthest copies let go.
  static let bottomShare: CGFloat = 0.4
  /// A copy's height in the dock until the dock has drawn it.
  static let copyEstimate: CGFloat = 30
  /// The dock's padding around its copies.
  var dockPadding: CGFloat = 4
  /// The stack's coordinate space, where the frames are.
  static let space = "kit.sticky"
  /// The scroll view's own space, where the clear area is.
  static let hostSpace = "kit.sticky.host"
  /// A sticky item's own space, where its title measures itself.
  static let itemSpace = "kit.sticky.item"

  /// Where each item shows, in the items' order: `nil` in place.
  ///
  /// - Top: an item sticks once its part has scrolled above the line under the top bar (and the items stuck before
  ///   it). `.titleWhileVisible` stays only while the section reaches below the title, which its end pushes up.
  ///   Nothing sticks there while the table is paused.
  /// - Bottom: the item stays where it is, and a compact copy of it shows in the dock over the bottom bar while its
  ///   title is below the copy's place there (`y`, the copy's top); an item in view stops the dock, as the items
  ///   before it are in view too. Past its share of the sidebar, the farthest copies let go one by one.
  func placements(visibleTop: CGFloat, visibleBottom: CGFloat) -> [ContStickyPlacement?] {
    var result = [ContStickyPlacement?](repeating: nil, count: items.count)
    let top = visibleTop + topGap
    let bottom = visibleBottom - bottomGap
    if !isPaused {
      var cursor = top
      for (index, item) in items.enumerated() where item.sticky.top != .none {
        let part: ContStickyPart = item.sticky.top == .content ? .content : .title
        let block = item.block(part)
        guard block.top < cursor else { continue }
        var y = cursor
        if item.sticky.top == .titleWhileVisible {
          guard item.maxY > cursor else { continue }
          y = min(cursor, item.maxY - block.height)
        }
        result[index] = ContStickyPlacement(edge: .top, part: part, y: y)
        cursor = max(cursor, y + block.height + spacing)
      }
    }
    let cap = (bottom - top) * Self.bottomShare
    var dropped: Set<Int> = []
    var dock = dockStack(above: bottom - dockPadding, skipping: result, dropping: dropped)
    while dock.height + 2 * dockPadding > cap, let farthest = dock.placements.map(\.0).max() {
      dropped.insert(farthest)
      dock = dockStack(above: bottom - dockPadding, skipping: result, dropping: dropped)
    }
    for (index, placement) in dock.placements { result[index] = placement }
    return result
  }

  /// The copies in the dock, from the bottom up, and their height.
  private func dockStack(
    above bottom: CGFloat, skipping top: [ContStickyPlacement?], dropping dropped: Set<Int>
  ) -> (placements: [(Int, ContStickyPlacement)], height: CGFloat) {
    var cursor = bottom
    var placements: [(Int, ContStickyPlacement)] = []
    for index in items.indices.reversed() where items[index].sticky.bottom != .none && !dropped.contains(index) {
      // Stuck at the top, it and the items before it are above.
      guard top[index] == nil else { break }
      let item = items[index]
      let slot = cursor - (item.copyHeight ?? Self.copyEstimate)
      // Its title came up to its copy's place: it's in view, and so is everything before it.
      guard item.block(.title).top > slot else { break }
      let part: ContStickyPart = item.sticky.bottom == .content ? .content : .title
      placements.append((index, ContStickyPlacement(edge: .bottom, part: part, y: slot)))
      cursor = slot
    }
    return (placements, bottom - cursor)
  }

  /// Where the item `id` shows, with the visible area in the stack's space.
  func placement(of id: AnyHashable, visibleTop: CGFloat, visibleBottom: CGFloat) -> ContStickyPlacement? {
    guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
    return placements(visibleTop: visibleTop, visibleBottom: visibleBottom)[index]
  }

  /// The table with the item `id` where it is now: its `part` at `liveTop` in the stack's space. The table's places
  /// come through preferences and can lag the layout (as a screen first settles); a view always lays out its own
  /// item from where it really is, and the others from the table.
  func live(_ id: AnyHashable, part: ContStickyPart, at liveTop: CGFloat) -> (table: ContStickyTable, index: Int)? {
    guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
    var table = self
    let shift = liveTop - items[index].block(part).top
    if shift != 0 {
      table.items[index].minY += shift
      table.items[index].maxY += shift
      if let titleTop = table.items[index].titleTop { table.items[index].titleTop = titleTop + shift }
    }
    return (table, index)
  }

  /// How far `part` of the item `id` moves from its place this frame. `naturalTop` is the top of the view the proxy
  /// measures, in the stack's space: the visible area follows from it.
  func offset(of id: AnyHashable, part: ContStickyPart, naturalTop: CGFloat, proxy: GeometryProxy) -> CGFloat {
    guard !isPaused, let (table, index) = live(id, part: part, at: naturalTop), clearBottom > clearTop else { return 0 }
    let visible = visibleArea(naturalTop: naturalTop, hostTop: proxy.frame(in: .named(Self.hostSpace)).minY)
    // A view docked at the bottom stays where it is: its copy shows there.
    guard let placement = table.placements(visibleTop: visible.top, visibleBottom: visible.bottom)[index],
      placement.edge == .top, placement.part == part
    else { return 0 }
    return placement.y - naturalTop
  }

  /// The clear area in the stack's space, for a view whose top is `naturalTop` there and `hostTop` in the scroll
  /// view's.
  func visibleArea(naturalTop: CGFloat, hostTop: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
    (naturalTop + clearTop - hostTop, naturalTop + clearBottom - hostTop)
  }

  func item(_ id: AnyHashable) -> ContStickyItem? { items.first { $0.id == id } }
}

/// What a sticky item tells the section inside it.
struct ContStickyContext: Equatable, @unchecked Sendable {
  var id: AnyHashable
  var state: ContStickyState?
  var scroll: ContStickyScroll?
  /// What its copy in the bottom dock shows.
  var bottom: KitStickyBottom = .none
}

/// Scrolls the host to a sticky item (a click on its stuck title).
struct ContStickyScroll: Equatable {
  let action: @MainActor (AnyHashable) -> Void
  static func == (lhs: Self, rhs: Self) -> Bool { true }
}

/// The id a sticky item scrolls to.
struct ContStickyScrollID: Hashable {
  let value: AnyHashable
}

extension EnvironmentValues {
  /// The sticky views of the host above (a sidebar), `nil` where nothing sticks.
  @Entry var contStickyTable: ContStickyTable? = nil
  @Entry var contStickyScroll: ContStickyScroll? = nil
  @Entry var contStickyRegistry: ContStickyRegistry? = nil
  /// The sticky item this view is in, for the `KitSection` inside it.
  @Entry var contStickyContext: ContStickyContext? = nil
  /// The view is drawn in a copy in the bottom dock: rows draw as small buttons.
  @Entry var contStickyCopy = false
}

// MARK: - Registry

/// A section's title: its top in its item and its height as a card of its own.
struct ContStickyTitle: Equatable, @unchecked Sendable {
  var id: AnyHashable
  var top: CGFloat
  var height: CGFloat
}

/// Where a host's sticky views are, written by the views themselves. Not preferences: in Shell's iPhone sidebar, past
/// the first value, the sections' preference changes never reached the host, which kept their first places.
@MainActor
final class ContStickyRegistry {
  private(set) var items: [AnyHashable: ContStickyItem] = [:]
  private(set) var titles: [AnyHashable: ContStickyTitle] = [:]
  /// The items whose copies show in the bottom dock.
  private(set) var docked: Set<AnyHashable> = []
  private(set) var copyHeights: [AnyHashable: CGFloat] = [:]
  /// The host draws again (once for any number of changes in one update).
  var onChange: (@MainActor () -> Void)?
  private var isPending = false

  func set(_ item: ContStickyItem) {
    guard items[item.id] != item else { return }
    items[item.id] = item
    changed()
  }

  func set(_ title: ContStickyTitle) {
    guard titles[title.id] != title else { return }
    titles[title.id] = title
    changed()
  }

  func setDocked(_ id: AnyHashable, _ isDocked: Bool) {
    guard docked.contains(id) != isDocked else { return }
    if isDocked { docked.insert(id) } else { docked.remove(id) }
    changed()
  }

  func setCopyHeight(_ id: AnyHashable, _ height: CGFloat) {
    guard copyHeights[id] != height else { return }
    copyHeights[id] = height
    changed()
  }

  func remove(_ id: AnyHashable) {
    guard items[id] != nil || titles[id] != nil || docked.contains(id) else { return }
    items[id] = nil
    titles[id] = nil
    docked.remove(id)
    changed()
  }

  /// After this update: a state change made while a screen's first frame is built can be dropped.
  private func changed() {
    guard !isPending else { return }
    isPending = true
    Task { @MainActor [weak self] in
      self?.isPending = false
      self?.onChange?()
    }
  }
}

// MARK: - Host

extension View {
  /// Makes this scroll view a host of sticky sections: put it on the `ScrollView` and give its stack the
  /// `ContStickyTable.space` coordinate space (`contStickyStack()`). `spacing` is the gap between stuck views,
  /// `topGap` and `bottomGap` their gaps from the visible area's ends, `sideInset` the bottom dock's from its sides.
  func contStickyHost(
    spacing: CGFloat, topGap: CGFloat, bottomGap: CGFloat, sideInset: CGFloat,
    scroll: @escaping @MainActor (AnyHashable) -> Void
  ) -> some View {
    modifier(
      ContStickyHost(spacing: spacing, topGap: topGap, bottomGap: bottomGap, sideInset: sideInset, scroll: scroll))
  }

  /// The stack of a sticky host's scroll view: the frames the sticky views report are in its space.
  func contStickyStack() -> some View {
    coordinateSpace(.named(ContStickyTable.space))
  }
}

private struct ContStickyHost: ViewModifier {
  let spacing: CGFloat
  let topGap: CGFloat
  let bottomGap: CGFloat
  let sideInset: CGFloat
  let scroll: @MainActor (AnyHashable) -> Void
  @State private var registry = ContStickyRegistry()
  @State private var clear = ContStickyClear()
  @State private var revision = 0
  @State private var pause = ContStickyPause()

  func body(content: Content) -> some View {
    let _ = revision
    if #available(macOS 15.0, iOS 18.0, *) {
      let table = table
      let scroll = ContStickyScroll { [pause] id in
        pause.scrollsItself()
        self.scroll(id)
      }
      content
        .environment(\.contStickyTable, table)
        .environment(\.contStickyScroll, scroll)
        .environment(\.contStickyRegistry, registry)
        // The sections below the visible area stay in place; their copies wait in the dock over the bottom bar,
        // outside the scroll view, so nothing in it moves for them.
        .overlayPreferenceValue(ContStickyCopyKey.self, alignment: .bottom) { copies in
          let docked = table.items.compactMap { item in
            registry.docked.contains(item.id) ? copies.last { $0.id == item.id } : nil
          }
          Color.clear
            .overlay(alignment: .bottom) {
              if !docked.isEmpty {
                ContStickyDock(copies: docked, registry: registry)
                  .environment(\.contStickyScroll, scroll)
                  .padding(EdgeInsets(top: 0, leading: sideInset, bottom: bottomGap, trailing: sideInset))
              }
            }
            // The fade behind the dock reaches past it: the sidebar ends it.
            .clipped()
        }
        .onAppear {
          registry.onChange = { revision &+= 1 }
          revision &+= 1
        }
        // The scroll view's own space is its frame clear of its bars (the title bar, the bottom bar), which it scrolls
        // on under: its content insets reach beyond it. (Its visible bounds take them in on the Mac and not on iOS.)
        .onScrollGeometryChange(for: ContStickyClear.self) { geometry in
          ContStickyClear(top: 0, bottom: geometry.containerSize.height)
        } action: { _, new in
          clear = new
        }
        // The user's scroll or a row drag lets go of the stuck sections until half a second after it ends. A
        // programmatic scroll (a click on a stuck title) keeps them.
        .onScrollPhaseChange { _, phase in
          pause.scrolled(phase)
        }
        .onChange(of: ContDragActivity.shared.isDragging, initial: true) { _, dragging in
          pause.dragged(dragging)
        }
        #if os(macOS)
          // A mouse wheel scrolls without a phase: the content moving while idle is one.
          .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, _ in
            pause.moved()
          }
        #endif
        .coordinateSpace(.named(ContStickyTable.hostSpace))
    } else {
      content
    }
  }

  private var table: ContStickyTable {
    var sorted = registry.items.values.sorted { $0.minY < $1.minY }
    for index in sorted.indices {
      if let title = registry.titles[sorted[index].id] {
        sorted[index].titleTop = sorted[index].minY + title.top
        sorted[index].titleHeight = title.height
      }
      sorted[index].copyHeight = registry.copyHeights[sorted[index].id]
    }
    return ContStickyTable(
      items: sorted, clearTop: clear.top, clearBottom: clear.bottom, spacing: spacing, topGap: topGap,
      bottomGap: bottomGap, isPaused: pause.isPaused)
  }
}

/// Whether the stuck sections are let go: from the start of a scroll or a row drag until `delay` after its end.
@MainActor @Observable
final class ContStickyPause {
  static let delay: Duration = .milliseconds(500)

  private(set) var isPaused = false
  @ObservationIgnored private var isScrolling = false
  @ObservationIgnored private var isDragging = false
  /// The kit scrolls the host itself (a click on a stuck title): its move isn't the user's.
  @ObservationIgnored private var isScrollingItself = false
  /// The end of the last scroll or drag, or the last wheel step.
  @ObservationIgnored private var lastActivity = ContinuousClock.now
  @ObservationIgnored private var resume: Task<Void, Never>?

  @available(macOS 15.0, iOS 18.0, *)
  func scrolled(_ phase: ScrollPhase) {
    isScrolling = phase == .interacting || phase == .decelerating
    update()
  }

  func dragged(_ dragging: Bool) {
    isDragging = dragging
    update()
  }

  /// The content moved. Only a move outside a scroll phase counts (a mouse wheel's step on the Mac).
  func moved() {
    guard !isScrolling, !isScrollingItself else { return }
    update(moved: true)
  }

  func scrollsItself() {
    isScrollingItself = true
    Task { @MainActor [weak self] in
      await kitSleep(for: .milliseconds(200))
      self?.isScrollingItself = false
    }
  }

  private func update(moved: Bool = false) {
    let isActive = isScrolling || isDragging
    if (isActive || moved) && !isPaused { withAnimation(.kit) { isPaused = true } }
    if isActive {
      resume?.cancel()
      resume = nil
      return
    }
    guard isPaused else { return }
    lastActivity = .now
    guard resume == nil else { return }
    // One wait for any number of wheel steps: each moves its end on.
    resume = Task { @MainActor [weak self] in
      while let due = self.map({ $0.lastActivity + Self.delay }), ContinuousClock.now < due {
        await kitSleep(until: due)
        if Task.isCancelled { return }
      }
      guard let self else { return }
      resume = nil
      withAnimation(.kit) { isPaused = false }
    }
  }
}

/// The scroll view's area clear of its bars, in its own space.
private struct ContStickyClear: Equatable {
  var top: CGFloat = 0
  var bottom: CGFloat = 0
}

// MARK: - Item

/// A lazy stack's item with sticky options: it reports its frame, keeps whether it's stuck (its z-order: a stuck
/// view draws over the rest), moves while stuck, and tells the section inside.
@available(macOS 15.0, iOS 18.0, *)
struct ContStickyItemModifier: ViewModifier {
  let id: AnyHashable
  let sticky: ContSticky
  @State private var state: ContStickyState?
  /// Bumped to draw again after a change SwiftUI may have dropped (see `ContStickyHost.redrawSoon`).
  @State private var revision = 0
  /// The item's frame and top in the scroll view as of the last frame: not state, which a screen's first frame can
  /// drop (an iPad sidebar opening on an empty detail kept a bottom section stuck over its own rows).
  @State private var visible = ContStickyVisible()
  @Environment(\.contStickyTable) private var table
  @Environment(\.contStickyScroll) private var scroll
  @Environment(\.contStickyRegistry) private var registry

  func body(content: Content) -> some View {
    let _ = revision
    if let table {
      let keyed = ContStickyKeyed(table: table, id: id)
      // What reads geometry sits outside the offset: inside it, frames move with it, and the offset would follow.
      content
        .environment(\.contStickyContext, ContStickyContext(id: id, state: state, scroll: scroll, bottom: sticky.bottom))
        // The section's title measures itself from here, so the offset of the whole doesn't move it.
        .coordinateSpace(.named(ContStickyTable.itemSpace))
        .visualEffect { effect, proxy in
          effect.offset(y: keyed.offset(.content, proxy))
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(ContStickyTable.space)) } action: {
          visible.frame = $0
          report()
          update()
          redrawSoon()
        }
        // The same places read in layout: `onGeometryChange` can stop reporting while a screen settles (an iPad
        // sidebar opening on an empty detail kept a section one screen taller than it drew, and the section under
        // it stuck over its own rows). A reader runs with every layout; what it finds is handled after it.
        .background {
          GeometryReader { proxy in
            let _ = observe(
              frame: proxy.frame(in: .named(ContStickyTable.space)),
              hostTop: proxy.frame(in: .named(ContStickyTable.hostSpace)).minY)
            Color.clear
          }
        }
        .onChange(of: sticky) { report() }
        .onAppear {
          visible.isPresent = true
          report()
        }
        // A report already on its way (a layout's, after the update) mustn't bring a view that's gone back: a section
        // that never draws again would stay in the table and push the stack beside it out of place.
        .onDisappear {
          visible.isPresent = false
          registry?.remove(id)
        }
        // Whether it's stuck follows the scroll and the table (another section moved, a title came).
        // (A geometry action keeps the closure it was first given: it reads the table from the box.)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(ContStickyTable.hostSpace)).minY } action: { top in
          visible.hostTop = top
          update()
        }
        .onChange(of: table, initial: true) { _, table in
          visible.table = table
          update()
        }
        // Again after each redraw: a stuck state set while the screen settled may have been dropped, and nothing
        // else checks it once the layout holds still.
        .onChange(of: revision) { update() }
        .zIndex(state?.zIndex ?? 0)
    } else {
      content
    }
  }
}

@available(macOS 15.0, iOS 18.0, *)
extension ContStickyItemModifier {
  private func update() {
    var new: ContStickyState?
    var isDocked = false
    // The dock follows the scroll while the table is paused too: it's outside the scroll view.
    if let hostTop = visible.hostTop, let frame = visible.frame, let table = visible.table,
      table.clearBottom > table.clearTop
    {
      let area = table.visibleArea(naturalTop: frame.minY, hostTop: hostTop)
      if let (live, order) = table.live(id, part: .content, at: frame.minY) {
        let placements = live.placements(visibleTop: area.top, visibleBottom: area.bottom)
        if let placement = placements[order] {
          if placement.edge == .top {
            new = ContStickyState(
              edge: .top, part: placement.part, order: order,
              isLast: !placements[(order + 1)...].contains { $0?.edge == .top })
          } else {
            isDocked = true
          }
        }
      }
    }
    if visible.isPresent { registry?.setDocked(id, isDocked) }
    if new != state {
      state = new
      redrawSoon()
    }
  }

  private func redrawSoon() {
    Task { @MainActor in revision &+= 1 }
  }

  /// The item's places as a layout found them: when they differ from the last report, it reports and checks its
  /// state after this update (a redraw only if the state changed: the top changes with every scrolled frame).
  private func observe(frame: CGRect, hostTop: CGFloat) {
    guard frame != visible.frame || hostTop != visible.hostTop else { return }
    let moved = frame != visible.frame
    visible.frame = frame
    visible.hostTop = hostTop
    // Paused, nothing sticks at the top: a scrolled frame has nothing to check, unless the item may be docked.
    if !moved, state == nil, sticky.bottom == .none, visible.table?.isPaused == true { return }
    Task { @MainActor in
      if moved { report() }
      update()
    }
  }

  /// Tells the host where the item is.
  private func report() {
    guard visible.isPresent, let frame = visible.frame else { return }
    registry?.set(ContStickyItem(id: id, sticky: sticky, minY: frame.minY, maxY: frame.maxY))
  }
}

final class ContStickyVisible {
  /// Between its appearance and its disappearance: reports only then.
  var isPresent = false
  var frame: CGRect?
  var hostTop: CGFloat?
  var table: ContStickyTable?
}

/// A table with the item and the top of the view that reads it, to send into a geometry closure.
struct ContStickyKeyed: @unchecked Sendable {
  let table: ContStickyTable
  let id: AnyHashable

  /// The view's own top in the stack's space, read with its place in the scroll view in the same frame: a top
  /// from the table may lag the layout (as a navigation bar's large title settles) and set the view off.
  private func naturalTop(_ proxy: GeometryProxy) -> CGFloat {
    proxy.frame(in: .named(ContStickyTable.space)).minY
  }

  func offset(_ part: ContStickyPart, _ proxy: GeometryProxy) -> CGFloat {
    table.offset(of: id, part: part, naturalTop: naturalTop(proxy), proxy: proxy)
  }
}

// MARK: - Dock

/// A section's copy in the bottom dock.
struct ContStickyCopy: Identifiable {
  let id: AnyHashable
  /// A plain section's: the dock draws on the sidebar's ground instead of a card.
  let plain: Bool
  let view: AnyView
}

/// The copies of the sections that may wait at the bottom, from the sections themselves.
struct ContStickyCopyKey: PreferenceKey {
  static var defaultValue: [ContStickyCopy] { [] }
  static func reduce(value: inout [ContStickyCopy], nextValue: () -> [ContStickyCopy]) {
    value.append(contentsOf: nextValue())
  }
}

/// The bottom dock: the copies of the sections below the visible area, one compact line each on one stuck card,
/// in the sections' order. It measures its copies for the table, and goes while the user drags a row (to drop it on
/// a row under it).
struct ContStickyDock: View {
  let copies: [ContStickyCopy]
  let registry: ContStickyRegistry
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    let plain = copies.allSatisfy(\.plain)
    let isDragging = ContDragActivity.shared.isDragging
    VStack(spacing: 0) {
      ForEach(copies) { copy in
        copy.view
          .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { registry.setCopyHeight(copy.id, $0) }
      }
    }
    .padding(ContStickyTable().dockPadding)
    .background {
      ContStuckGround(
        cornerRadius: plain ? 0 : ContMetrics.cardRadius(idiom), plain: plain,
        state: ContStickyState(edge: .bottom, part: .content, isLast: true))
    }
    .opacity(isDragging ? 0 : 1)
    .allowsHitTesting(!isDragging)
    .animation(.kit, value: isDragging)
  }
}

/// A section's line in the bottom dock: a small icon, the title and the meta, and for a section that waits whole
/// its rows as small buttons. A click on the line scrolls to the section.
struct ContStickyCopyLine<Icon: View, Meta: View, Rows: View>: View {
  let id: AnyHashable
  let title: Text
  let plain: Bool
  /// It shows the section's rows: they may not fit beside the title.
  let hasRows: Bool
  @ViewBuilder var icon: Icon
  @ViewBuilder var meta: Meta
  @ViewBuilder var rows: Rows
  @State private var isHovered = false
  @Environment(\.contStickyScroll) private var scroll
  @Environment(\.kitIdiom) private var idiom

  /// The icon, the title and the meta. On the last line it may cut the meta, never the title.
  private func heading(meta showsMeta: Bool) -> some View {
    HStack(spacing: 6) {
      if !plain {
        icon.environment(\.contTileSize, idiom.size(18, touch: 24))
      }
      title
        .kitFont(plain ? .sectionHeader : .body)
        .fontWeight(.semibold)
        .foregroundStyle(plain ? AnyShapeStyle(KitColor.sectionHeader) : AnyShapeStyle(.kitLabel))
        .lineLimit(1)
        .layoutPriority(1)
      if showsMeta {
        meta
          .kitFont(.caption)
          .lineLimit(1)
      }
    }
  }

  private var buttons: some View {
    HStack(spacing: 1) { rows }
      .environment(\.contStickyCopy, true)
      .fixedSize()
  }

  var body: some View {
    Group {
      if hasRows {
        // All on one line if it fits; then without the meta; then the rows on a line of their own.
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 6) {
            heading(meta: true)
            Spacer(minLength: 4)
            buttons
          }
          HStack(spacing: 6) {
            heading(meta: false)
            Spacer(minLength: 4)
            buttons
          }
          VStack(alignment: .leading, spacing: 2) {
            heading(meta: true)
            buttons
          }
          .padding(.vertical, 3)
        }
      } else {
        heading(meta: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
    .frame(minHeight: idiom.size(28, touch: 40))
    .background {
      if isHovered, !idiom.isTouch {
        RoundedRectangle(cornerRadius: ContMetrics.rowRadius(idiom, compact: true), style: .continuous)
          .fill(KitColor.rowHover)
      }
    }
    .contentShape(Rectangle())
    .kitHover { isHovered = $0 }
    .onTapGesture { withKitAnimation { scroll?.action(id) } }
    .accessibilityElement(children: .contain)
    .accessibilityAction(named: Text("Show Section")) { scroll?.action(id) }
  }
}

// MARK: - Section title

/// The sticky item a section is in, for its header's tap (a stuck title scrolls to its section). The section's own
/// body runs where its stack resolves it, outside the item, so its title, inside, keeps this up to date.
@MainActor
final class ContStickyBox {
  var context: ContStickyContext?
}

/// A section's title in a sticky item: it reports its place, moves while stuck alone, and floats on a card of its
/// own then.
struct ContStickyTitleModifier: ViewModifier {
  let box: ContStickyBox
  /// The title's card reaches this far below it (the card's padding under an open section's title).
  let extra: CGFloat
  let cornerRadius: CGFloat
  let plain: Bool
  /// The section's copy in the bottom dock, with its rows or without.
  var copy: ((_ id: AnyHashable, _ rows: Bool) -> AnyView)? = nil
  @State private var frame: CGRect?
  @Environment(\.contStickyTable) private var table
  @Environment(\.contStickyContext) private var context
  @Environment(\.contStickyRegistry) private var registry

  func body(content: Content) -> some View {
    let _ = box.context = context
    if let context, let table {
      let keyed = ContStickyKeyed(table: table, id: context.id)
      content
        .background(alignment: .top) {
          ContStuckGround(
            cornerRadius: cornerRadius, plain: plain, state: context.state?.part == .title ? context.state : nil
          )
          .padding(.bottom, -extra)
        }
        .visualEffect { effect, proxy in
          effect.offset(y: keyed.offset(.title, proxy))
        }
        // Outside the offset, in the item's space: the item may be moving too.
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(ContStickyTable.itemSpace)) } action: {
          frame = $0
          report(context.id)
        }
        .onChange(of: extra) { report(context.id) }
        .preference(
          key: ContStickyCopyKey.self,
          value: context.bottom == .none
            ? [] : copy.map { [ContStickyCopy(id: context.id, plain: plain, view: $0(context.id, context.bottom == .content))] } ?? [])
        .zIndex(1)
        // What a click on the stuck title scrolls to (an id outside the stack's subview is never found).
        .id(ContStickyScrollID(value: context.id))
    } else {
      content
    }
  }
}

extension ContStickyTitleModifier {
  /// Tells the host where the title is in its item.
  private func report(_ id: AnyHashable) {
    guard let frame else { return }
    registry?.set(ContStickyTitle(id: id, top: frame.minY, height: frame.height + extra))
  }
}

/// A section card's ground: the card, or while it is stuck whole, the stuck card.
struct ContStickyCardGround: View {
  var cornerRadius: CGFloat
  @Environment(\.contStickyContext) private var context

  var body: some View {
    if let context {
      SurfaceShape(surface: .card, cornerRadius: cornerRadius)
        .overlay {
          ContStuckGround(cornerRadius: cornerRadius, state: context.state?.part == .content ? context.state : nil)
        }
    } else {
      SurfaceShape(surface: .card, cornerRadius: cornerRadius)
    }
  }
}

/// A stuck card's ground: the card, opaque over the sidebar, with light mode's card shadow in dark mode too (a card's
/// resting edge there is a top highlight, and a stuck card over cards of the same step didn't stand out). Behind the
/// stack the sidebar's ground fades the rows scrolling under it (`ContStuckFade`). A plain section's title gets the
/// sidebar's ground alone.
///
/// It stays in place while the view is in a sticky item, `state` `nil` while the view isn't stuck: the ground comes
/// and goes at once (the view sticks and comes free where it is, on its own card) and the shadow and the fade fade.
struct ContStuckGround: View {
  var cornerRadius: CGFloat
  var plain = false
  var state: ContStickyState?
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let isStuck = state != nil
    Group {
      if plain {
        Rectangle().fill(.kitSidebar)
          .opacity(isStuck ? 1 : 0)
      } else {
        SurfaceShape(surface: .card, cornerRadius: cornerRadius)
          .shadow(color: .black.opacity(scheme == .dark ? 0.06 : 0), radius: 1.5, y: 1)
          .opacity(isStuck ? 1 : 0)
          .animation(.kit, value: isStuck)
          .environment(\.contBarGround, KitColor.sidebar)
      }
    }
    .background {
      ZStack {
        if let state, state.isLast { ContStuckFade(edge: state.edge).transition(.opacity) }
      }
      .animation(.kit, value: state)
    }
  }
}

/// Behind the last stuck view on an edge, the sidebar's ground over the rows scrolling under the stack: from the edge
/// to the view, across the sidebar, then fading out past it, as under the bars. The stuck views then stand on the
/// sidebar's ground more than on the rows. It reaches past the sidebar's scroll view, which clips it, and runs on
/// under the views nearer the edge, which draw over it: one fade for the stack (each view's own doubled it up).
struct ContStuckFade: View {
  var edge: ContStickyEdge
  @Environment(\.kitIdiom) private var idiom
  private let opacity = 0.6

  var body: some View {
    let reach: CGFloat = 1000
    let tail = idiom.size(24, touch: 32)
    let top = edge == .top
    VStack(spacing: 0) {
      if !top { Rectangle().fill(ContGroundFade(ground: .kitSidebar, edge: .bottom, opacity: opacity)).frame(height: tail) }
      Rectangle().fill(.kitSidebar).opacity(opacity)
      if top { Rectangle().fill(ContGroundFade(ground: .kitSidebar, edge: .top, opacity: opacity)).frame(height: tail) }
    }
    .padding(EdgeInsets(top: -(top ? reach : tail), leading: -reach, bottom: -(top ? tail : reach), trailing: -reach))
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
