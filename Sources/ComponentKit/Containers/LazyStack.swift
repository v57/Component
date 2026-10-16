import SwiftUI

// A lazy stack for scroll views of a few heavy views (a page of specimens, a sidebar of section cards), where a
// `LazyVStack` builds each view in the frame it scrolls in and drops frames there. Here a view is built:
// - at once while it is on screen (what shows must be there);
// - ahead of the screen (a screen's height) and, while scrolling rests, further ahead (two screens), a few views a
//   frame across every stack in the app (the nearest, with its stack's others within a third of a screen: each
//   change lays the page out again, so small views go together), so building never piles up in one frame;
// - and let go past three screens, keeping its measured height, so the page never jumps when it comes back (built
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
/// diff) use a `LazyVStack`, which never lays out the views it hasn't built.
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
  @Environment(\.contLazyEager) private var eager

  public init(alignment: HorizontalAlignment = .center, spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
    self.alignment = alignment
    self.spacing = spacing
    self.content = content()
  }

  public var body: some View {
    if eager {
      VStack(alignment: alignment, spacing: spacing) { content }
    } else if #available(macOS 15, iOS 18, *) {
      ContLazyStack(alignment: alignment, spacing: spacing, content: content)
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
  @State private var model = ContLazyModel()
  @Environment(\.contLazyParent) private var parent

  var body: some View {
    Group(subviews: content) { subviews in
      let ids = subviews.map { AnyHashable($0.id) }
      VStack(alignment: alignment, spacing: spacing) {
        ForEach(subviews) { subview in
          let id = AnyHashable(subview.id)
          ContLazyItem(subview: subview, id: id, flag: model.flag(id), model: model)
        }
      }
      .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
      .onAppear { model.setItems(ids, spacing: spacing, parent: parent) }
      .onChange(of: ids) { model.setItems(ids, spacing: spacing, parent: parent) }
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
  let flag: ContLazyFlag
  let model: ContLazyModel

  var body: some View {
    if flag.isBuilt {
      subview
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.measured(id, $0) }
        .environment(\.contLazyParent, ContLazyParent(model: model, item: id))
    } else {
      Color.clear.frame(height: flag.height)
    }
  }
}

/// An item's own state, observed by it alone, so building one view redraws that view and not the stack.
@MainActor @Observable
final class ContLazyFlag {
  var isBuilt = false
  /// The placeholder's height.
  var height: CGFloat

  init(height: CGFloat) { self.height = height }
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

/// Which views of a stack are built, and their heights.
@MainActor @Observable
final class ContLazyModel {
  @ObservationIgnored private var built: Set<AnyHashable> = []
  @ObservationIgnored private var flags: [AnyHashable: ContLazyFlag] = [:]
  @ObservationIgnored private var items: [AnyHashable] = []
  @ObservationIgnored private var spacing: CGFloat = 8
  @ObservationIgnored private var heights: [AnyHashable: CGFloat] = [:]
  @ObservationIgnored private var window: ContLazyWindow?
  @ObservationIgnored private var hasWindow = false
  @ObservationIgnored private var isReplanning = false
  @ObservationIgnored private var parent: ContLazyParent?
  /// How far each item is from the screen, as of the last plan; the stacks inside an item read it.
  @ObservationIgnored private var distances: [AnyHashable: CGFloat] = [:]
  @ObservationIgnored private var children: [AnyHashable: [ContLazyWeak]] = [:]
  /// The items waiting in the scheduler, so planning touches it only for changes.
  @ObservationIgnored private var queued: Set<AnyHashable> = []

  /// How far ahead views are built while scrolling, and while the scroll rests, in screens; past `release` they go.
  static let ahead: CGFloat = 1
  static let restingAhead: CGFloat = 2
  static let release: CGFloat = 3

  func flag(_ id: AnyHashable) -> ContLazyFlag {
    if let flag = flags[id] { return flag }
    let flag = ContLazyFlag(height: height(of: id))
    flags[id] = flag
    return flag
  }

  func height(of id: AnyHashable) -> CGFloat { heights[id] ?? estimate }

  /// The average of the heights measured so far; before any, a third of the screen, so the first frame builds a few
  /// views and the next ones follow once their sizes are known (a guess too small would build the whole stack).
  private var estimate: CGFloat {
    guard !heights.isEmpty else { return max((window?.height ?? 0) / 3, 44) }
    return heights.values.reduce(0, +) / CGFloat(heights.count)
  }

  func setItems(_ ids: [AnyHashable], spacing: CGFloat, parent: ContLazyParent?) {
    items = ids
    self.spacing = spacing
    if self.parent != parent {
      self.parent = parent
      parent?.model?.adopt(self, in: parent!.item)
    }
    let current = Set(ids)
    if !built.isSubset(of: current) { built.formIntersection(current) }
    if flags.count > current.count { flags = flags.filter { current.contains($0.key) } }
    ContLazyScheduler.shared.register(self)
    plan()
  }

  func measured(_ id: AnyHashable, _ height: CGFloat) {
    let old = heights[id]
    heights[id] = height
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
    queued.removeAll()
    ContLazyScheduler.shared.remove(self)
  }

  /// A stack inside `item`: it plans again whenever the item's distance to the screen changes.
  fileprivate func adopt(_ child: ContLazyModel, in item: AnyHashable) {
    children[item, default: []].removeAll { $0.model == nil || $0.model === child }
    children[item, default: []].append(ContLazyWeak(model: child))
  }

  private func distance(of item: AnyHashable) -> CGFloat { distances[item] ?? 0 }

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
    let screen = max(window?.height ?? 0, outer > 0 ? 400 : 100)
    let ahead = screen * (scheduler.isResting ? Self.restingAhead : Self.ahead)
    var now: Set<AnyHashable> = []
    var changed: [AnyHashable] = []
    var y: CGFloat = 0
    let estimate = self.estimate
    for id in items {
      let height = heights[id] ?? estimate
      // A placeholder still at an old guess takes the new one (the scroll height follows).
      if let flag = flags[id], !flag.isBuilt, abs(flag.height - height) > height / 10 { flag.height = height }
      let top = y
      let bottom = y + height
      y = bottom + spacing
      var distance = outer
      if let window {
        let own = bottom < window.top ? window.top - bottom : top > window.bottom ? top - window.bottom : 0
        distance = max(own, outer)
      }
      // The stacks inside follow when the item comes on screen, leaves it, or moves a quarter screen nearer or
      // farther; scroll views of their own don't see the outer scroll, and every 16pt would be too often.
      if let old = distances[id], children[id] != nil, step(old, screen) != step(distance, screen) {
        changed.append(id)
      }
      distances[id] = distance
      if distance == 0 {
        if !built.contains(id) { now.insert(id) }
        unqueue(id)
      } else if distance <= ahead, !built.contains(id) {
        queue(id, priority: distance, release: false)
      } else if distance > screen * Self.release, built.contains(id) {
        queue(id, priority: .greatestFiniteMagnitude, release: true)
      } else {
        unqueue(id)
      }
    }
    if !now.isEmpty { build(now) }
    // The stacks inside items that moved nearer or farther (in scroll views of their own) follow.
    for id in changed {
      for child in children[id] ?? [] { child.model?.plan() }
    }
  }

  private func queue(_ id: AnyHashable, priority: CGFloat, release: Bool) {
    queued.insert(id)
    ContLazyScheduler.shared.enqueue(self, id, priority: priority, release: release)
  }

  private func unqueue(_ id: AnyHashable) {
    guard queued.remove(id) != nil else { return }
    ContLazyScheduler.shared.dequeue(self, id)
  }

  /// The scheduler's turn for a queued item.
  func perform(_ id: AnyHashable, release: Bool) {
    queued.remove(id)
    if release { self.release(id) } else { build([id]) }
  }

  private func build(_ ids: Set<AnyHashable>) {
    let missing = ids.subtracting(built)
    guard !missing.isEmpty else { return }
    var transaction = Transaction()
    transaction.disablesAnimations = true
    built.formUnion(missing)
    withTransaction(transaction) {
      for id in missing { flags[id]?.isBuilt = true }
    }
  }

  private func release(_ id: AnyHashable) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    built.remove(id)
    withTransaction(transaction) {
      flags[id]?.height = height(of: id)
      flags[id]?.isBuilt = false
    }
  }
}

struct ContLazyWeak {
  weak var model: ContLazyModel?
}

// MARK: - Scheduler

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

  func register(_ model: ContLazyModel) {
    models[ObjectIdentifier(model)] = ContLazyWeak(model: model)
  }

  func remove(_ model: ContLazyModel) {
    let id = ObjectIdentifier(model)
    models[id] = nil
    jobs = jobs.filter { $0.key.model != id }
  }

  /// A scroll view moved: build only a screen ahead until it rests 150 ms, then two.
  func scrolled() {
    isResting = false
    restTask?.cancel()
    restTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(150))
      guard !Task.isCancelled, let self else { return }
      self.isResting = true
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
      while let self, let next = self.jobs.min(by: { $0.value.priority < $1.value.priority }) {
        // With it, the same stack's views within `span` of it: each change lays the page out again, so a few small
        // views at once cost less than one at a time.
        let batch = self.jobs.filter {
          $0.key.model == next.key.model && $0.value.priority <= next.value.priority + span
        }
        let start = clock.now
        for (key, job) in batch {
          self.jobs[key] = nil
          job.model?.perform(job.item, release: job.release)
        }
        // A batch a frame: the next waits for this one's frame to go out.
        try? await Task.sleep(for: .milliseconds(17))
        // What the frame took past the wait is what the batch cost. A heavy one (a frame missed) makes the next a
        // single view and rests as long as it took, so building never holds the main thread more than half the
        // time while a page scrolls; light ones let the batch grow back.
        let cost = (clock.now - start) - .milliseconds(17)
        if cost > .milliseconds(8) {
          span = 0
          try? await Task.sleep(for: min(cost, .milliseconds(100)))
        } else {
          span = min(span + 100, Self.batchSpan)
        }
      }
      self?.loop = nil
    }
  }
}
