import Combine
import SwiftUI

// A lazy stack for scroll views of a few heavy views (a page of specimens, a sidebar of section cards), where a
// `LazyVStack` builds each view in the frame it scrolls in and drops frames there. Here a view is built:
// - at once while it is on screen (what shows must be there);
// - ahead of the screen (a screen's height) and, while scrolling rests, a little further (a screen and a quarter),
//   a few views a frame across every stack in the app (the nearest, with its stack's others within a third of a
//   screen: each change lays the page out again, so small views go together), so building never piles up in one
//   frame;
// - and let go past two screens, keeping its measured height, so the page never jumps when it comes back (built
//   views far off still lay out and track the scroll, which a long page feels).
// Stacks nest: a section's rows in a stack of their own come a few at a time rather than with their card, and a stack
// inside an item (in a scroll view of its own) is no nearer the screen than its item. Each item observes only its own
// state, so building one redraws that one. Outside a scroll view everything is built. Before macOS 15 and iOS 18 (no
// `Group(subviews:)`) it is a `LazyVStack`.

extension EnvironmentValues {
  /// Builds every view of the `KitLazyStack`s below at once (`.kitLazyLoading(false)`).
  @Entry var contLazyEager = false
  /// The lazy stack item this view is in, so a stack inside it (in a scroll view of its own, say) is no nearer the
  /// screen than its item.
  @Entry var contLazyParent: ContLazyParent? = nil
}

extension View {
  /// Turns lazy building off for the `KitLazyStack`s below (a capture that scrolls to a section, a print): every view
  /// is built at once, as in a `VStack`.
  ///
  /// ```swift
  /// Page().kitLazyLoading(!isCapturing)
  /// ```
  public func kitLazyLoading(_ isLazy: Bool) -> some View {
    environment(\.contLazyEager, !isLazy)
  }
}

/// A vertical stack in a scroll view that builds its views near the screen only, steadier than a `LazyVStack` for
/// a few heavy views: it builds ahead of the scroll, a few views a frame, lets far views go but keeps their heights,
/// and nests (a card's rows in a stack of their own come a few at a time). For thousands of light rows (a log, a
/// diff) use a `LazyVStack`, which never lays out the views it hasn't built; past a thousand views (a section of
/// search results) the stack is one.
///
/// ```swift
/// ScrollView {
///   KitLazyStack(alignment: .leading, spacing: 32) {
///     ForEach(sections) { section in
///       SectionView(section)
///     }
///   }
/// }
/// ```
public struct KitLazyStack<Content: View>: View {
  let alignment: HorizontalAlignment
  let spacing: CGFloat
  let content: Content
  /// Shown in place of the stack while its content has no views (macOS 15 and iOS 18 on): a section's empty line.
  var empty: AnyView?
  @Environment(\.contLazyEager) private var eager

  public init(alignment: HorizontalAlignment = .center, spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
    self.alignment = alignment
    self.spacing = spacing
    self.content = content()
  }

  init(alignment: HorizontalAlignment, spacing: CGFloat, empty: AnyView?, @ViewBuilder content: () -> Content) {
    self.init(alignment: alignment, spacing: spacing, content: content)
    self.empty = empty
  }

  public var body: some View {
    if eager {
      if #available(macOS 15, iOS 18, *) {
        // Sticky views (`.kitSticky`) stick here too.
        Group(subviews: content) { subviews in
          if subviews.isEmpty, let empty {
            empty
          } else {
            VStack(alignment: alignment, spacing: spacing) {
              ForEach(subviews) { subview in
                if let sticky = subview.containerValues.contSticky {
                  subview.modifier(ContStickyItemModifier(id: AnyHashable(subview.id), sticky: sticky))
                } else {
                  subview
                }
              }
            }
          }
        }
      } else {
        VStack(alignment: alignment, spacing: spacing) { content }
      }
    } else if #available(macOS 15, iOS 18, *) {
      ContLazyStack(alignment: alignment, spacing: spacing, content: content, empty: empty)
    } else {
      LazyVStack(alignment: alignment, spacing: spacing) { content }
    }
  }
}

// MARK: - Stack


@available(macOS 15, iOS 18, *)
private struct ContLazyStack<Content: View>: View {
  let alignment: HorizontalAlignment
  let spacing: CGFloat
  let content: Content
  let empty: AnyView?
  @State private var model = ContLazyModel()
  @Environment(\.contLazyParent) private var parent

  var body: some View {
    Group(subviews: content) { subviews in
      if subviews.isEmpty, let empty {
        empty
      } else if subviews.count > ContLazyModel.rowLimit {
        // Thousands of views (a search's matches in one section): each item would cost on every plan and every
        // layout, so they go in a `LazyVStack`, which lays out only what it built.
        LazyVStack(alignment: alignment, spacing: spacing) {
          ForEach(subviews) { $0 }
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
        .onAppear { model.cancel() }
      } else {
        stack(subviews)
      }
    }
  }

  private func stack(_ subviews: SubviewsCollection) -> some View {
    let ids = subviews.map { AnyHashable($0.id) }
    // Sticky views (`.kitSticky`) that may show at an edge from anywhere stay built, with their rows.
    let pinned = Set(subviews.filter { $0.containerValues.contSticky?.isPinned == true }.map { AnyHashable($0.id) })
    return Group {
      VStack(alignment: alignment, spacing: spacing) {
        ForEach(subviews) { subview in
          let id = AnyHashable(subview.id)
          let item = ContLazyItem(subview: subview, id: id, flag: model.flag(id), model: model, alignment: alignment)
          if let sticky = subview.containerValues.contSticky {
            item.modifier(ContStickyItemModifier(id: id, sticky: sticky))
          } else {
            item
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
      .onAppear { model.setItems(ids, pinned: pinned, spacing: spacing, parent: parent) }
      // Views that come with an animated change (a group opening) are built under its animation, so the views below
      // slide down as they come in instead of jumping.
      .transaction(value: ids) { model.insertionAnimation = $0.disablesAnimations ? nil : $0.animation }
      .onChange(of: ids) { model.setItems(ids, pinned: pinned, spacing: spacing, parent: parent) }
      .onChange(of: pinned) { model.setItems(ids, pinned: pinned, spacing: spacing, parent: parent) }
    }
    // Where the scroll view's visible bounds fall in the stack, rounded out to 64pt so it plans every 64pt at most
    // (a long page nests many stacks, and each plans when it moves) and still covers all that shows.
    .onGeometryChange(for: ContLazyWindow?.self) { proxy in
      guard let visible = proxy.bounds(of: .scrollView) else { return nil }
      return ContLazyWindow(
        top: (visible.minY / 64).rounded(.down) * 64, bottom: (visible.maxY / 64).rounded(.up) * 64,
        height: (visible.height / 64).rounded() * 64)
    } action: { window in
      model.update(window)
    }
    .onDisappear { model.cancel() }
  }
}

/// One view of the stack: itself once built, else a clear space of its last height (or the stack's best guess).
@available(macOS 15, iOS 18, *)
private struct ContLazyItem: View {
  let subview: Subview
  let id: AnyHashable
  @ObservedObject var flag: ContLazyFlag
  let model: ContLazyModel
  let alignment: HorizontalAlignment
  @Environment(\.contStickyContext) private var sticky

  var body: some View {
    // One container either way, the built view inside it: the item keeps its identity as it is built and let go.
    // Switching between the view and a placeholder made SwiftUI set the scroll view's offset again, to where it was
    // before the last scroll step, so the page jumped back as views went far off and were let go.
    let alignment = Alignment(horizontal: alignment, vertical: .top)
    ZStack(alignment: alignment) {
      if flag.isBuilt {
        subview
          .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.measured(id, $0) }
          .environment(\.contLazyParent, ContLazyParent(model: model, item: id))
          // The section's own body ran as the stack resolved its subviews, so the sticky item around this one tells
          // the views inside it.
          .environment(\.contStickyContext, sticky)
      }
    }
    .frame(maxWidth: .infinity, minHeight: flag.isBuilt ? nil : flag.height, alignment: alignment)
  }
}

/// An item's own state, observed by it alone, so building one view redraws that view and not the stack. An
/// `ObservableObject` the item subscribes to as it is made, not an `@Observable` read in its body: a change SwiftUI
/// drops (see `build`) can be said again; an item whose body first ran as a page opened sometimes had no observation
/// left to hear it. Its publisher is stored: the synthesized one is looked up in Combine's global table on every send,
/// which grows with every flag, so a stack of thousands of rows spent most of its time there.
@MainActor
final class ContLazyFlag: ObservableObject {
  nonisolated(unsafe) let objectWillChange = ObservableObjectPublisher()
  var isBuilt = false {
    willSet { if newValue != isBuilt { objectWillChange.send() } }
  }
  /// The placeholder's height.
  var height: CGFloat {
    willSet { if newValue != height { objectWillChange.send() } }
  }

  init(height: CGFloat) { self.height = height }

  /// Draws the item again (its state unchanged): for a change SwiftUI dropped.
  func redraw() { objectWillChange.send() }
}

/// The scroll view's visible bounds in the stack's space; `nil` outside a scroll view.
struct ContLazyWindow: Equatable {
  var top: CGFloat
  var bottom: CGFloat
  var height: CGFloat
}

/// A stack's item, for the stacks inside it.
struct ContLazyParent: Equatable {
  weak var model: ContLazyModel?
  var item: AnyHashable

  static func == (lhs: Self, rhs: Self) -> Bool { lhs.model === rhs.model && lhs.item == rhs.item }
}

// MARK: - Model

/// One item's bookkeeping, kept in the stack's order so planning walks an array instead of hashing ids.
@MainActor
final class ContLazySlot {
  let id: AnyHashable
  let flag: ContLazyFlag
  var measured: CGFloat?
  /// The height it gave the app's average (`ContLazyScheduler.averageHeight`), if it gave one.
  var counted: CGFloat?
  var isBuilt = false
  /// The built view has drawn (it measured itself since it was built).
  var hasDrawn = false
  var isQueued = false
  /// A sticky view that may show at an edge from anywhere: built at once, never let go, and the stacks inside it
  /// build everything (its height must be right wherever it is, and it may show whole at an edge).
  var isPinned = false
  /// How far it is from the screen, as of the last plan; the stacks inside it read it.
  var distance: CGFloat?
  var children: [ContLazyWeak] = []

  init(id: AnyHashable, height: CGFloat) {
    self.id = id
    flag = ContLazyFlag(height: height)
  }
}

/// Which views of a stack are built, and their heights.
@MainActor @Observable
final class ContLazyModel {
  @ObservationIgnored private var slots: [ContLazySlot] = []
  @ObservationIgnored private var byID: [AnyHashable: ContLazySlot] = [:]
  @ObservationIgnored private var spacing: CGFloat = 8
  @ObservationIgnored private var window: ContLazyWindow?
  @ObservationIgnored private var hasWindow = false
  @ObservationIgnored private var isReplanning = false
  @ObservationIgnored private var parent: ContLazyParent?
  /// This stack is inside a pinned sticky view: it builds every view.
  @ObservationIgnored private var buildsAll = false
  /// The sum and count of the measured heights, for the estimate.
  @ObservationIgnored private var measuredSum: CGFloat = 0
  @ObservationIgnored private var measuredCount = 0
  /// The estimate the far placeholders last took: they follow it only when it moves a quarter from there.
  @ObservationIgnored private var placedEstimate: CGFloat?
  /// The animation of the change that last set the items, for the views it added (`setItems`).
  @ObservationIgnored var insertionAnimation: Animation?
  /// Views the last `setItems` added under `insertionAnimation`: built under it rather than without animation.
  @ObservationIgnored private var inserted: Set<AnyHashable> = []

  /// Past this many views a stack is a `LazyVStack`: planning and laying out every item cost each frame of a scroll.
  static let rowLimit = 1000

  /// How far ahead views are built while scrolling, and while the scroll rests, in screens; past `release` they go.
  static let ahead: CGFloat = 1
  static let restingAhead: CGFloat = 1.25
  static let release: CGFloat = 2

  /// The item's slot, made with its flag the first time the stack draws it.
  func flag(_ id: AnyHashable) -> ContLazyFlag { slot(id).flag }

  private func slot(_ id: AnyHashable) -> ContLazySlot {
    if let slot = byID[id] { return slot }
    let slot = ContLazySlot(id: id, height: estimate)
    byID[id] = slot
    return slot
  }

  /// The average of the heights measured so far; before any, a third of the screen, so the first frame builds a few
  /// views and the next ones follow once their sizes are known (a guess too small would build the whole stack).
  private var estimate: CGFloat {
    if measuredCount > 0 { return measuredSum / CGFloat(measuredCount) }
    return ContLazyScheduler.shared.averageHeight ?? max((window?.height ?? 0) / 3, 44)
  }

  func setItems(_ ids: [AnyHashable], pinned: Set<AnyHashable> = [], spacing: CGFloat, parent: ContLazyParent?) {
    if insertionAnimation != nil, !slots.isEmpty {
      // The stack made slots for the new views as it drew them: new is what the last items didn't have.
      let previous = Set(slots.map(\.id))
      inserted = Set(ids.filter { !previous.contains($0) })
    }
    defer {
      inserted = []
      insertionAnimation = nil
    }
    slots = ids.map(slot)
    for slot in slots { slot.isPinned = pinned.contains(slot.id) }
    self.spacing = spacing
    if self.parent != parent {
      self.parent = parent
      parent?.model?.adopt(self, in: parent!.item)
    }
    if byID.count > slots.count {
      let current = Set(ids)
      for (id, slot) in byID where !current.contains(id) {
        if let height = slot.measured { measuredSum -= height; measuredCount -= 1 }
        forgetCounted(slot)
        if slot.isQueued { ContLazyScheduler.shared.dequeue(self, id) }
        byID[id] = nil
      }
    }
    ContLazyScheduler.shared.register(self)
    plan()
  }

  func measured(_ id: AnyHashable, _ height: CGFloat) {
    guard let slot = byID[id] else { return }
    let old = slot.measured
    if let old { measuredSum -= old } else { measuredCount += 1 }
    measuredSum += height
    slot.measured = height
    if slot.isBuilt { slot.hasDrawn = true }
    // Only views without stacks inside feed the app's average: a card whose rows are still placeholders (sized from
    // that average) grew with it, and the average with the card, without end.
    if !slot.isPinned, slot.children.isEmpty {
      ContLazyScheduler.shared.measured(height, replacing: slot.counted)
      slot.counted = height
    } else {
      forgetCounted(slot)
    }
    // The views below moved: plan again once this frame's sizes are in.
    guard old.map({ abs($0 - height) >= 1 }) ?? true else { return }
    replanSoon()
  }

  func update(_ window: ContLazyWindow?) {
    self.window = window
    hasWindow = true
    ContLazyScheduler.shared.scrolled()
    plan()
  }

  func cancel() {
    for slot in slots { slot.isQueued = false }
    ContLazyScheduler.shared.remove(self)
  }

  /// A stack inside `item`: it plans again whenever the item's distance to the screen changes.
  fileprivate func adopt(_ child: ContLazyModel, in item: AnyHashable) {
    let slot = slot(item)
    forgetCounted(slot)
    slot.children.removeAll { $0.model == nil || $0.model === child }
    slot.children.append(ContLazyWeak(model: child))
  }

  /// Takes the slot's height out of the app's average.
  private func forgetCounted(_ slot: ContLazySlot) {
    guard let counted = slot.counted else { return }
    ContLazyScheduler.shared.forget(counted)
    slot.counted = nil
  }

  private func distance(of item: AnyHashable) -> CGFloat { byID[item]?.distance ?? 0 }

  /// Whether the stacks inside `item` build everything: it is pinned, or this stack does.
  private func buildsAll(in item: AnyHashable) -> Bool { buildsAll || byID[item]?.isPinned == true }

  private func step(_ distance: CGFloat, _ screen: CGFloat) -> Int {
    distance == 0 ? 0 : 1 + Int(distance / (screen / 4))
  }

  private func replanSoon() {
    guard !isReplanning else { return }
    isReplanning = true
    Task { [weak self] in
      guard let self else { return }
      self.isReplanning = false
      self.plan()
    }
  }

  /// Builds what is on screen now, queues what is near, lets go of what is far. An item is as far from the screen
  /// as it is in this stack's scroll view, and no nearer than the parent stack's item it sits in.
  func plan() {
    guard hasWindow else { return }
    let scheduler = ContLazyScheduler.shared
    let outer = parent.flatMap { parent in parent.model?.distance(of: parent.item) } ?? 0
    buildsAll = parent.flatMap { parent in parent.model?.buildsAll(in: parent.item) } ?? false
    let screen = max(window?.height ?? 0, outer > 0 ? 400 : 100)
    let ahead = screen * (scheduler.isResting ? Self.restingAhead : Self.ahead)
    let farDistance = screen * Self.release
    var now: [ContLazySlot] = []
    var changed: [ContLazySlot] = []
    var y: CGFloat = 0
    let estimate = self.estimate
    // Far placeholders follow the estimate only when it moved a quarter since they last did: with thousands of rows,
    // rewriting them on every plan (each change draws the placeholder again) held the main thread for seconds.
    let refreshesFar = placedEstimate.map { abs($0 - estimate) > estimate / 4 } ?? true
    if refreshesFar { placedEstimate = estimate }
    for slot in slots {
      // The height the layout has for it: a placeholder's own until it takes a new one.
      let height = slot.isBuilt ? slot.measured ?? estimate : slot.flag.height
      let top = y
      let bottom = y + height
      y = bottom + spacing
      var distance = outer
      if let window {
        let own = bottom < window.top ? window.top - bottom : top > window.bottom ? top - window.bottom : 0
        distance = max(own, outer)
      }
      if buildsAll { distance = 0 }
      // The stacks inside follow when the item comes on screen, leaves it, or moves a quarter screen nearer or
      // farther; scroll views of their own don't see the outer scroll, and every 64pt would be too often.
      if let old = slot.distance, !slot.children.isEmpty, step(old, screen) != step(distance, screen) {
        changed.append(slot)
      }
      slot.distance = distance
      if !slot.isBuilt {
        // A placeholder still at an old guess takes the new one (the scroll height follows); a near one at once, past
        // a quarter off (each change draws it again), a far one when the estimate moved.
        let target = slot.measured ?? estimate
        if abs(height - target) > target / 4, distance <= farDistance || refreshesFar || slot.measured != nil {
          slot.flag.height = target
        }
      }
      if distance == 0 || slot.isPinned {
        if !slot.isBuilt { now.append(slot) }
        unqueue(slot)
      } else if distance <= ahead, !slot.isBuilt {
        queue(slot, priority: distance, release: false)
      } else if distance > farDistance, slot.isBuilt {
        queue(slot, priority: .greatestFiniteMagnitude, release: true)
      } else {
        unqueue(slot)
      }
    }
    if !now.isEmpty { build(now) }
    // The stacks inside items that moved nearer or farther (in scroll views of their own) follow.
    for slot in changed {
      for child in slot.children { child.model?.plan() }
    }
  }

  private func queue(_ slot: ContLazySlot, priority: CGFloat, release: Bool) {
    slot.isQueued = true
    ContLazyScheduler.shared.enqueue(self, slot.id, priority: priority, release: release)
  }

  private func unqueue(_ slot: ContLazySlot) {
    guard slot.isQueued else { return }
    slot.isQueued = false
    ContLazyScheduler.shared.dequeue(self, slot.id)
  }

  /// The scheduler's turn for a queued item.
  func perform(_ id: AnyHashable, release: Bool) {
    guard let slot = byID[id] else { return }
    slot.isQueued = false
    if release { self.release(slot) } else { build([slot]) }
  }

  private func build(_ slots: [ContLazySlot]) {
    let missing = slots.filter { !$0.isBuilt }
    guard !missing.isEmpty else { return }
    var transaction = Transaction()
    transaction.disablesAnimations = true
    for slot in missing {
      slot.isBuilt = true
      slot.hasDrawn = false
    }
    withTransaction(transaction) {
      for slot in missing where !inserted.contains(slot.id) || insertionAnimation == nil { slot.flag.isBuilt = true }
    }
    if let insertionAnimation {
      withAnimation(insertionAnimation) {
        for slot in missing where inserted.contains(slot.id) { slot.flag.isBuilt = true }
      }
    }
    // Said again once this update is over: SwiftUI sometimes drops a change made while it builds the page's first
    // frame (in an `onAppear` or `onGeometryChange` action), and the item stays a blank placeholder.
    // Only for views that haven't drawn: setting it again draws the view again.
    Task {
      withTransaction(transaction) {
        for slot in missing where slot.isBuilt && !slot.hasDrawn { slot.flag.redraw() }
      }
    }
  }

  private func release(_ slot: ContLazySlot) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    slot.isBuilt = false
    withTransaction(transaction) {
      slot.flag.height = slot.measured ?? estimate
      slot.flag.isBuilt = false
    }
  }
}

struct ContLazyWeak {
  weak var model: ContLazyModel?
}

// MARK: - Scheduler

/// Whether a lazy stack's scroll view is moving (until it rests 150 ms), for what draws differently meanwhile.
@MainActor @Observable
final class ContLazyScrolling {
  static let shared = ContLazyScrolling()
  var isScrolling = false
}

/// Builds the queued views of every lazy stack a few a frame, nearest to its screen first, and tells the stacks when
/// scrolling rests so they build further ahead.
@MainActor
final class ContLazyScheduler {
  static let shared = ContLazyScheduler()

  private struct Key: Hashable {
    let model: ObjectIdentifier
    let item: AnyHashable
  }

  private struct Job {
    var priority: CGFloat
    weak var model: ContLazyModel?
    var item: AnyHashable
    var release: Bool
  }

  private var jobs: [Key: Job] = [:]
  private var loop: Task<Void, Never>?
  private static let batchSpan: CGFloat = 300
  private var models: [ObjectIdentifier: ContLazyWeak] = [:]
  private var restTask: Task<Void, Never>?
  /// No scroll view has moved for a moment.
  private(set) var isResting = false
  private var heightSum: CGFloat = 0
  private var heightCount = 0

  /// The average height of every view without stacks inside measured in any stack: a new stack's first guess, nearer than a fraction of the
  /// screen (a guess far off changes heights on screen as the views come, which moves the scroll).
  var averageHeight: CGFloat? { heightCount > 0 ? heightSum / CGFloat(heightCount) : nil }

  func measured(_ height: CGFloat, replacing old: CGFloat?) {
    if let old { heightSum -= old } else { heightCount += 1 }
    heightSum += height
  }

  func forget(_ height: CGFloat) {
    heightSum -= height
    heightCount -= 1
  }

  func register(_ model: ContLazyModel) {
    models[ObjectIdentifier(model)] = ContLazyWeak(model: model)
  }

  func remove(_ model: ContLazyModel) {
    let id = ObjectIdentifier(model)
    models[id] = nil
    jobs = jobs.filter { $0.key.model != id }
  }

  /// A scroll view moved: build only a screen ahead until it rests 150 ms, then a quarter more.
  func scrolled() {
    isResting = false
    if !ContLazyScrolling.shared.isScrolling { ContLazyScrolling.shared.isScrolling = true }
    restTask?.cancel()
    restTask = Task { [weak self] in
      await kitSleep(for: .milliseconds(150))
      guard !Task.isCancelled, let self else { return }
      self.isResting = true
      ContLazyScrolling.shared.isScrolling = false
      self.models = self.models.filter { $0.value.model != nil }
      for model in self.models.values { model.model?.plan() }
    }
  }

  func enqueue(_ model: ContLazyModel, _ item: AnyHashable, priority: CGFloat, release: Bool) {
    let key = Key(model: ObjectIdentifier(model), item: item)
    if jobs[key] != nil {
      jobs[key]?.priority = priority
      jobs[key]?.release = release
    } else {
      jobs[key] = Job(priority: priority, model: model, item: item, release: release)
    }
    start()
  }

  func dequeue(_ model: ContLazyModel, _ item: AnyHashable) {
    jobs[Key(model: ObjectIdentifier(model), item: item)] = nil
  }

  private func start() {
    guard loop == nil else { return }
    loop = Task { [weak self] in
      var span = Self.batchSpan
      let clock = ContinuousClock()
      while let self, let start = self.buildBatch(span: span, clock: clock) {
        // A batch a frame: the next waits for this one's frame to go out.
        await kitSleep(for: .milliseconds(17))
        // What the frame took past the wait is what the batch cost. A heavy one (a frame missed) makes the next a
        // single view and rests as long as it took, so building never holds the main thread more than half the
        // time while a page scrolls; light ones let the batch grow back.
        let cost = (clock.now - start) - .milliseconds(17)
        if cost > .milliseconds(8) {
          span = 0
          await kitSleep(for: min(cost, .milliseconds(100)))
        } else {
          span = min(span + 100, Self.batchSpan)
        }
      }
      self?.loop = nil
    }
  }

  /// Builds the most wanted job and, with it, the same stack's views within `span` of it: each change lays the page
  /// out again, so a few small views at once cost less than one at a time. Returns when the building started, or nil
  /// with no job left. Out of line, so the loop's waits don't each get a copy of it.
  @inline(never)
  private func buildBatch(span: CGFloat, clock: ContinuousClock) -> ContinuousClock.Instant? {
    guard let next = jobs.min(by: { $0.value.priority < $1.value.priority }) else { return nil }
    let batch = jobs.filter {
      $0.key.model == next.key.model && $0.value.priority <= next.value.priority + span
    }
    let start = clock.now
    for (key, job) in batch {
      jobs[key] = nil
      job.model?.perform(job.item, release: job.release)
    }
    return start
  }
}
