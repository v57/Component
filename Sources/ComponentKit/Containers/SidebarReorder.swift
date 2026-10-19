import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppKit)
  import AppKit
#endif

// Drag to reorder, from Shell's SidebarReorder: a `LazyVStack` has no reordering of its own, so the rows do it. A
// reorderable row is a drag source (publishing which list it is in and where) and a drop target. While a drag passes
// over its list, the rows only slide (offsets) to show where it would land, worked out from where the rows sit, which
// the sliding never changes: rows of different heights can't push the pointer onto another row and back. The list's
// data moves once, on the drop. Which list a row belongs to is what refuses a drop between lists.

/// The row drag in progress, shared by every reorderable row (a `KitSidebar` publishes one; rows outside one share
/// the app's, `app`: a section or row of its own would never hear of a drag from its neighbours).
@MainActor @Observable
final class ContReorderState {
  /// The drag of the rows outside a `KitSidebar`. One drag at a time, so one for the app.
  static let app = ContReorderState()

  /// The type a row drag declares and accepts. Its payload is never read (this object describes the drag), but a drag
  /// and its targets have to agree on a type to be matched at all. Its own type, so a row never takes a file drop and a
  /// file never reorders a row. A dynamic type (from a MIME type), as no app declares one: on macOS a drag of an
  /// undeclared exported type never reaches a drop target, and one conforming to `public.data` drags as a file promise
  /// (a row dropped on Finder would make a file).
  nonisolated static let contentType = UTType(mimeType: "application/x-dev.v57.componentkit.row", conformingTo: .item)!

  /// The list the dragged row is in, and its index there.
  private(set) var list: AnyHashable?
  private(set) var index: Int?
  /// Every dragged row's index: the row alone, or the rows dragged with it (a multi-row drag).
  private(set) var indices = IndexSet()
  /// Where the dragged rows would land: their place among the list's other rows (`nil` while the pointer is away).
  private(set) var target: Int?
  /// How far each row of the dragged list slides to show the drop (by index), along `axis`.
  private(set) var offsets: [Int: CGFloat] = [:]
  /// The row the dragged rows would go into (a folder of a `ReorderableOutline`), rather than beside.
  private(set) var into: Int?
  /// The level of a tree the dragged rows would land at (`ContReorderLevels`), and how far apart levels are drawn.
  private(set) var level: Int?
  /// The tree's folder row the drop goes into, worn as a drop target so the level shows while the drag image covers
  /// its slot (`nil`: the top level, or a list).
  private(set) var receiver: Int?
  /// The name of where the drop goes (`ContReorderLevels.title`), shown above the drag image, and the pointer (global
  /// coordinates) with how far below the image's top it holds it.
  private(set) var hint: String?
  private(set) var pointer: CGPoint = .zero
  private(set) var hintLift: CGFloat = 0
  private(set) var levelStep: CGFloat = 0
  /// The direction the list runs (a tab strip's tabs run across).
  private(set) var axis: Axis = .vertical

  /// Starts a drag of the row at `index`; `group` holds the indices of the rows dragged with it (itself included).
  func begin(_ list: AnyHashable, at index: Int, with group: IndexSet? = nil) {
    self.list = list
    self.index = index
    if let group, group.contains(index) { indices = group } else { indices = [index] }
    target = nil
    offsets = [:]
    into = nil
    level = nil
    receiver = nil
    hint = nil
    grab = nil
    grabAcross = nil
    hintArmed = false
    hasLanded = false
  }

  /// After the drop: where the dragged rows are now, which of them is the one under the pointer, and how far the rows
  /// still slide (by their new indices) to stay where they are drawn until the drag image has landed: a collapsed
  /// group's rows open its room as it sits back in.
  func update(indices: IndexSet, anchor: Int, offsets: [Int: CGFloat] = [:]) {
    self.indices = indices
    index = anchor
    target = nil
    self.offsets = offsets
    into = nil
    level = nil
    receiver = nil
    hint = nil
    hasLanded = true
  }

  /// The drop happened: a late update of the pointer (one arrives as the drag image lands) places nothing.
  @ObservationIgnored private var hasLanded = false

  /// How many rows the drag carries.
  var count: Int { indices.count }

  func isDragging(_ list: AnyHashable, at index: Int) -> Bool {
    self.list == list && indices.contains(index)
  }

  /// How far the row at `index` of `list` slides while the drag shows where it lands.
  func offset(_ list: AnyHashable, at index: Int) -> CGFloat {
    self.list == list ? offsets[index] ?? 0 : 0
  }

  /// Whether the row at `index` of `list` draws the drag's slot (collapsed rows dragged together draw one, the
  /// first's).
  func isSlot(_ list: AnyHashable, at index: Int, collapses: Bool) -> Bool {
    isMoving && isDragging(list, at: index) && (!collapses || indices.first == index)
  }

  /// Whether the dragged rows would go into the row at `index` of `list`.
  func isInto(_ list: AnyHashable, at index: Int) -> Bool { into == index && self.list == list }

  /// Whether the drop goes into the row at `index` of `list`: held over it, or beside its rows at their level.
  func receives(_ list: AnyHashable, at index: Int) -> Bool { (receiver ?? into) == index && self.list == list }

  func end() {
    list = nil
    index = nil
    indices = []
    target = nil
    offsets = [:]
    into = nil
    level = nil
    receiver = nil
    hint = nil
    isMoving = false
  }

  /// The drag's session is under way, so the dragged row is drawn as its slot. On touch a long press calls the drag
  /// source as the row lifts, before any drag: a press let go there (or one that opened a context menu instead) has
  /// no session to end, and its row stayed an empty slot. There it waits for the session to move; on the Mac the
  /// source is called as the drag starts.
  private(set) var isMoving = false

  /// The session moved (`ContDragSessionEnd`).
  func sessionMoved() {
    if list != nil, !isMoving { isMoving = true }
  }

  /// Counts the drags, so a late `endAfterLanding` leaves a newer drag alone.
  private var drags = 0

  /// Starts a drag from its source (see `begin`); `collapsedLength`: the dragged row is a group that counts as its
  /// first row, this long.
  func start(
    _ list: AnyHashable, at index: Int, with group: IndexSet? = nil, axis: Axis, collapsedLength: CGFloat? = nil
  ) {
    drags += 1
    self.axis = axis
    self.collapsedLength = collapsedLength
    // At once: the drag image takes the row's place as the drag starts.
    isMoving = !KitIdiom.current.isTouch
    begin(list, at: index, with: group)
  }

  /// After a drop: the row stays the slot while the drag image lands on it, and sits back in as the session ends
  /// (`ContDragSessionEnd`). This ends it in case no end arrives: before macOS 26 and iOS 27, or when the source row
  /// left the screen (moved into another list).
  func endAfterLanding() {
    let drag = drags
    Task { @MainActor [weak self] in
      if #available(macOS 26.0, iOS 27.0, visionOS 27.0, *) { try? await Task.sleep(for: .milliseconds(600)) }
      guard let self, self.drags == drag, self.list != nil else { return }
      withAnimation(.kit) { self.end() }
    }
  }

  // MARK: Where the rows sit

  /// Every reorderable row's geometry, by list and index: a drop target reads its whole list's to place the drag.
  /// Not observed: it changes as rows lay out, and only a drag reads it.
  @ObservationIgnored private var rows: [AnyHashable: [Int: ContRowGeometry]] = [:]

  func register(_ geometry: ContRowGeometry, in list: AnyHashable, at index: Int) {
    if let old = geometry.place, old != (list, index), rows[old.list]?[old.index] === geometry {
      rows[old.list]?[old.index] = nil
    }
    geometry.place = (list, index)
    rows[list, default: [:]][index] = geometry
  }

  /// A row left the screen (a lazy stack dropped it) or the list.
  func unregister(_ geometry: ContRowGeometry) {
    guard let place = geometry.place, rows[place.list]?[place.index] === geometry else { return }
    rows[place.list]?[place.index] = nil
    if rows[place.list]?.isEmpty == true { rows[place.list] = nil }
  }

  /// Where the rows of `list` sit along the drag's axis (rows off screen are missing).
  private func spans(of list: AnyHashable, count: Int) -> [Int: ContReorder.Span] {
    var spans: [Int: ContReorder.Span] = [:]
    for (index, geometry) in rows[list] ?? [:] where index < count && geometry.frame != .zero {
      let frame = geometry.frame
      spans[index] = axis == .vertical
        ? .init(start: frame.minY, length: frame.height) : .init(start: frame.minX, length: frame.width)
    }
    return spans
  }

  /// The pointer is at `pointer` (global coordinates) over `list`, which has `count` rows: the dragged rows' place
  /// follows it, and the other rows slide out of their way. `throughSubRow`: read by a row inside one of the list's
  /// rows (a group's sub-row), which is skipped while the rows slide: `DropInfo` places the pointer where such a row
  /// is drawn, part way through its group's slide, and its frame is where the slide ends, so the pair puts the
  /// pointer up to a group's height away and the place would swing back and forth.
  func retarget(
    _ list: AnyHashable, count: Int, pointer: CGPoint, throughSubRow: Bool = false, nests: ((Int) -> Bool)? = nil,
    levels: ContReorderLevels? = nil
  ) {
    guard self.list == list, !hasLanded else { return }
    hover += 1
    if throughSubRow, let slid, Date.now.timeIntervalSince(slid) < 0.3 { return }
    // Rows just came or went (a folder opened under the drag) and are still moving into place.
    if let settling, Date.now.timeIntervalSince(settling) < 0.3 { return }
    guard let index else { return }
    let spans = spans(of: list, count: count)
    // The drag image's middle places the drop, not the pointer: a row held by its bottom edge and moved up shows
    // above a row before the pointer gets there. Where the pointer holds the row is read from its first move.
    let along = axis == .vertical ? pointer.y : pointer.x
    let length = collapsedLength ?? spans[index]?.length ?? 0
    if grab == nil, let span = spans[index] { grab = min(max(along - span.start, 0), length) }
    let middle = along - (grab ?? length / 2) + length / 2
    rowCount = count
    // A tree may close a folder it opened under the drag: the rows have changed, and the next update places the drag.
    if let moved = levels?.moved, moved(middle) { return }
    let (target, into) = ContReorder.place(
      from: self.target ?? ContReorder.home(dragged: indices, anchor: index),
      pointer: middle, spans: spans, dragged: indices, count: count, draggedLength: collapsedLength, nests: nests)
    if into != self.into { withAnimation(.kitFast) { self.into = into } }
    // A tree's level, from how far across the drag image has moved since it was picked up, within those the place
    // allows.
    if let levels {
      let across = axis == .vertical ? pointer.x : pointer.y
      if grabAcross == nil { grabAcross = across }
      let home = levels.home(indices)
      let moved = Int(((across - (grabAcross ?? across)) / max(levels.step, 1)).rounded())
      let range = levels.range(indices, target)
      let level = into == nil ? min(max(home + moved, range.lowerBound), range.upperBound) : nil
      levelHome = home
      levelStep = levels.step
      if level != self.level { withAnimation(.kitFast) { self.level = level } }
      let receiver = into ?? level.flatMap { levels.receiver(indices, target, $0) }
      if receiver != self.receiver { withAnimation(.kitFast) { self.receiver = receiver } }
      // Named at a list's last place only (after a folder's last row), where moving across picks between levels:
      // elsewhere the slot shows where the drop goes. Not at first while that's still the folder the rows came from.
      if levels.isOrigin(indices, receiver) == false { hintArmed = true }
      if let title = levels.title {
        let hint = hintArmed && into == nil && range.count > 1 ? title(receiver) : nil
        if hint != self.hint { withAnimation(.kitFast) { self.hint = hint } }
        if self.pointer != pointer { self.pointer = pointer }
        hintLift = grab ?? 0
      }
    }
    let stale = isStale
    if isStale, spans.count >= count { isStale = false }
    guard target != self.target || stale else { return }
    let offsets = ContReorder.offsets(
      spans: spans, count: count, dragged: indices, target: target, draggedLength: collapsedLength)
    slid = .now
    withAnimation(.kit) {
      self.target = target
      self.offsets = offsets
    }
  }

  /// The pointer left `list`'s rows: unless it comes back to one of them right away (it crossed the gap between two),
  /// the rows slide back.
  func leave(_ list: AnyHashable, at pointer: CGPoint? = nil) {
    // Between two rows (the gap no row covers) the pointer is still over the list.
    if let pointer, let bounds = rows[list]?.values.map(\.frame).filter({ $0 != .zero }).reduce(nil, { (union: CGRect?, frame) in
      union?.union(frame) ?? frame
    }), bounds.insetBy(dx: -1, dy: -4).contains(pointer) {
      return
    }
    hover += 1
    let hover = hover
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(120))
      guard let self, self.hover == hover, self.list == list, self.target != nil else { return }
      self.slid = .now
      withAnimation(.kit) {
        self.target = nil
        self.offsets = [:]
        self.into = nil
        self.hint = nil
      }
    }
  }

  /// Counts the pointer's moves over rows, so a late `leave` doesn't undo a newer place.
  @ObservationIgnored private var hover = 0
  /// When the rows last started to slide.
  @ObservationIgnored private var slid: Date?
  /// How far into the dragged row the pointer holds it, along the axis (`retarget`), and where across it first was.
  @ObservationIgnored private var grab: CGFloat?
  @ObservationIgnored private var grabAcross: CGFloat?
  /// The drop's place has left the folder the rows came from, so its name shows (`ContReorderLevels.title`).
  @ObservationIgnored private var hintArmed = false
  /// The dragged rows' own level (`ContReorderLevels.home`).
  @ObservationIgnored private var levelHome: Int?
  /// Rows came or went under the drag: the slides are worked out again as the rows settle (`insertRows`).
  @ObservationIgnored private var isStale = false
  @ObservationIgnored private var settling: Date?

  /// Sets the drag's place directly (tests).
  func retargetForTesting(target: Int?) { self.target = target }

  /// `count` rows were added to `list` at `position` during the drag (a folder opened under it): the drag's indices
  /// move past them, and the dragged rows keep their place among the others unless it was after them. The rows slide
  /// at once to where they go once the new rows are laid out (worked out from the rows on screen), so call it in the
  /// animation that shows the rows.
  func insertRows(_ list: AnyHashable, at position: Int, count: Int) {
    guard self.list == list, count > 0 else { return }
    let spans = ContReorder.inserting(count, at: position, into: spans(of: list, count: rowCount))
    let before = target.map { place in (0..<position).filter { !indices.contains($0) }.count < place } ?? false
    shift(from: position, by: count)
    if before, let target { self.target = target + count }
    rowCount += count
    reslide(spans)
  }

  /// The rows `range` of `list` went during the drag (a folder closed under it); like `insertRows`, the rows slide at
  /// once to where they go.
  func removeRows(_ list: AnyHashable, _ range: Range<Int>) {
    guard self.list == list, !range.isEmpty, !indices.contains(where: range.contains) else { return }
    let spans = ContReorder.removing(range, from: spans(of: list, count: rowCount))
    if let target {
      let othersBefore = (0..<range.upperBound).filter { !indices.contains($0) }.count
      if target >= othersBefore { self.target = target - range.count }
      else if target > othersBefore - range.count { self.target = othersBefore - range.count }
    }
    if let into, range.contains(into) { self.into = nil }
    shift(from: range.upperBound, by: -range.count)
    rowCount -= range.count
    reslide(spans)
  }

  /// How long the dragged rows' slot is, along the axis.
  var slotLength: CGFloat {
    if let collapsedLength { return collapsedLength }
    guard let list, let index, let frame = rows[list]?[index]?.frame else { return 0 }
    return axis == .vertical ? frame.height : frame.width
  }

  /// The list's row count, as the last update of the pointer gave it.
  @ObservationIgnored private var rowCount = 0

  private func reslide(_ spans: [Int: ContReorder.Span]) {
    guard let target else { return }
    offsets = ContReorder.offsets(
      spans: spans, count: rowCount, dragged: indices, target: target, draggedLength: collapsedLength)
  }

  private func shift(from position: Int, by count: Int) {
    func moved(_ index: Int) -> Int { index >= position ? index + count : index }
    indices = IndexSet(indices.map(moved))
    index = index.map(moved)
    into = into.map(moved)
    offsets = Dictionary(uniqueKeysWithValues: offsets.compactMap { key, value in
      count < 0 && key >= position + count && key < position ? nil : (moved(key), value)
    })
    isStale = true
    settling = .now
  }
  /// How long the dragged rows count as, when a group collapses to its first row (`ContReorderRow.collapses`).
  @ObservationIgnored private var collapsedLength: CGFloat?

  /// The drop onto `list` of `count` rows: `move` gets `.onMove`'s arguments when the rows change places, and the
  /// rows stay where they are drawn until the drag image has landed (`update`).
  func land(
    in list: AnyHashable, count: Int, move: (IndexSet, Int) -> Void, nest: ((IndexSet, Int) -> Void)? = nil
  ) {
    guard self.list == list, let index else { return }
    if let into, let nest {
      // Into a folder: the rows leave their places (or join the folder's, open), and slide shut.
      let moving = indices
      withAnimation(.kit) {
        nest(moving, into)
        update(indices: [], anchor: index)
      }
      return
    }
    guard let target else {
      hasLanded = true
      return
    }
    let spans = spans(of: list, count: count)
    let drawn = ContReorder.layout(
      spans: spans, count: count, dragged: indices, target: target, draggedLength: collapsedLength)
    let laidOut = ContReorder.layout(spans: spans, count: count, dragged: indices, target: target)
    var held: [Int: CGFloat] = [:]
    for (place, row) in ContReorder.order(count: count, dragged: indices, target: target).enumerated() {
      if let drawn = drawn[row], let laidOut = laidOut[row], abs(drawn - laidOut) > 0.5 { held[place] = drawn - laidOut }
    }
    // A new level alone (a folder's last row taken out to its parent's level) is a move too, in place.
    let others = (0..<count).filter { !indices.contains($0) }
    let inPlace = level != nil && level != levelHome
      ? (destination: target < others.count ? others[target] : count, indices: indices, anchor: index) : nil
    guard let step = ContReorder.landing(count: count, dragged: indices, anchor: index, target: target) ?? inPlace
    else {
      update(indices: indices, anchor: index, offsets: held)
      return
    }
    // The rows move and take their new slides in one transaction, so they stay where they are drawn.
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
      move(indices, step.destination)
      update(indices: step.indices, anchor: step.anchor, offsets: held)
    }
  }
}

extension EnvironmentValues {
  @Entry var contReorderState: ContReorderState? = nil
}

/// A tree's levels, for a list that is a tree drawn flat (`ReorderableOutline`): the drop's level is picked by moving
/// the drag image across, within the levels its place allows.
struct ContReorderLevels {
  /// The levels the `dragged` rows may take at `target`, their place among the other rows.
  var range: (_ dragged: IndexSet, _ target: Int) -> ClosedRange<Int>
  /// The dragged rows' own level.
  var home: (_ dragged: IndexSet) -> Int
  /// The row the drop goes into at `target` and `level` (`nil`: the top level).
  var receiver: (_ dragged: IndexSet, _ target: Int, _ level: Int) -> Int?
  /// Called as the drag image's middle moves (along the axis), before the drag is placed; `true`: the rows changed
  /// (a folder closed), so the update places nothing.
  var moved: ((_ middle: CGFloat) -> Bool)? = nil
  /// The name of the folder row the drop goes into (`nil`: the top level), shown above the drag image; `nil` for none.
  var title: ((_ receiver: Int?) -> String?)? = nil
  /// Whether the folder row `receiver` (`nil`: the top level) is the one the `dragged` rows came from.
  var isOrigin: (_ dragged: IndexSet, _ receiver: Int?) -> Bool = { _, _ in false }
  /// How far apart levels are drawn.
  var step: CGFloat
}

/// The reorder math, apart from views.
enum ContReorder {
  /// `.onMove`'s destination for a row dragged from `from` onto the row at `to`: a row dragged down lands after the
  /// row it was dropped on, one dragged up before it; either way it ends up at `to`.
  static func destination(from: Int, to: Int) -> Int { from < to ? to + 1 : to }

  /// Whether a row dragged from `source` may land in `list`: its own list always, another only when the list
  /// receives rows.
  static func accepts(from source: AnyHashable?, into list: AnyHashable, receives: Bool) -> Bool {
    guard let source else { return false }
    return source == list || receives
  }

  /// Where a row sits along its list: its top (or leading edge) and its height (or width).
  struct Span: Equatable {
    var start: CGFloat
    var length: CGFloat
    var middle: CGFloat { start + length / 2 }
  }

  /// The dragged rows' own place among the other rows: where a drag starts (`anchor` is the pointer's row).
  static func home(dragged: IndexSet, anchor: Int) -> Int { anchor - dragged.count(in: 0..<anchor) }

  /// Where the `dragged` rows land with the pointer at `pointer`, from their place `target`: one place on for each
  /// row drawn after them whose middle the pointer passes, one place back for each row drawn before them. Rows are
  /// taken where they are drawn (slid to show `target`), so the dragged rows' own size is the margin before the
  /// place turns back: a move puts the row it passed on the pointer's other side, and the place can't swing back and
  /// forth. A row off screen (no span) stops it.
  static func target(
    from target: Int, pointer: CGFloat, spans: [Int: Span], dragged: IndexSet, count: Int,
    draggedLength: CGFloat? = nil
  ) -> Int {
    place(from: target, pointer: pointer, spans: spans, dragged: dragged, count: count, draggedLength: draggedLength)
      .target
  }

  /// `target`, where rows that `nests` (folders) take the dragged rows into them too: such a row is passed at three
  /// quarters rather than half way, and the half between its quarters is `into` it.
  static func place(
    from target: Int, pointer: CGFloat, spans: [Int: Span], dragged: IndexSet, count: Int,
    draggedLength: CGFloat? = nil, nests: ((Int) -> Bool)? = nil
  ) -> (target: Int, into: Int?) {
    let others = (0..<count).filter { !dragged.contains($0) }
    var target = min(max(target, 0), others.count)
    for _ in 0...count {
      let drawn = layout(spans: spans, count: count, dragged: dragged, target: target, draggedLength: draggedLength)
      func span(_ row: Int) -> Span? { drawn[row].flatMap { start in spans[row].map { Span(start: start, length: $0.length) } } }
      if target < others.count, let next = span(others[target]) {
        let nestable = nests?(others[target]) ?? false
        if pointer > next.start + next.length * (nestable ? 0.75 : 0.5) {
          target += 1
          continue
        }
        if nestable, pointer > next.start + next.length / 4 { return (target, others[target]) }
      }
      if target > 0, let previous = span(others[target - 1]) {
        let nestable = nests?(others[target - 1]) ?? false
        if pointer < previous.start + previous.length * (nestable ? 0.25 : 0.5) {
          target -= 1
          continue
        }
        if nestable, pointer < previous.start + previous.length * 0.75 { return (target, others[target - 1]) }
      }
      break
    }
    return (target, nil)
  }

  /// Where the rows will sit once `count` rows of the same size as the row before them come in at `position`.
  static func inserting(_ count: Int, at position: Int, into spans: [Int: Span]) -> [Int: Span] {
    let gap = gap(in: spans)
    let length = spans[position - 1]?.length ?? spans.values.first?.length ?? 0
    let start = spans[position - 1].map { $0.start + $0.length + gap } ?? spans[position]?.start ?? 0
    let moved = CGFloat(count) * (length + gap)
    var result: [Int: Span] = [:]
    for (index, span) in spans {
      result[index < position ? index : index + count] =
        index < position ? span : Span(start: span.start + moved, length: span.length)
    }
    for row in 0..<count { result[position + row] = Span(start: start + CGFloat(row) * (length + gap), length: length) }
    return result
  }

  /// Where the rows will sit once the rows `range` have gone.
  static func removing(_ range: Range<Int>, from spans: [Int: Span]) -> [Int: Span] {
    let gap = gap(in: spans)
    let removed: CGFloat
    if let first = spans[range.lowerBound], let next = spans[range.upperBound] {
      removed = next.start - first.start
    } else {
      removed = range.map { (spans[$0]?.length ?? spans.values.first?.length ?? 0) + gap }.reduce(0, +)
    }
    var result: [Int: Span] = [:]
    for (index, span) in spans where !range.contains(index) {
      result[index < range.lowerBound ? index : index - range.count] =
        index < range.lowerBound ? span : Span(start: span.start - removed, length: span.length)
    }
    return result
  }

  /// The gap between neighbouring rows (2pt when no two neighbours are known).
  private static func gap(in spans: [Int: Span]) -> CGFloat {
    for (index, span) in spans.sorted(by: { $0.key < $1.key }) {
      if let next = spans[index + 1] { return next.start - span.start - span.length }
    }
    return 2
  }

  /// The rows' order with the dragged ones moved to `target` (their place among the others): old indices, new order.
  static func order(count: Int, dragged: IndexSet, target: Int) -> [Int] {
    var others = (0..<count).filter { !dragged.contains($0) }
    others.insert(contentsOf: dragged.filter { $0 < count }, at: min(target, others.count))
    return others
  }

  /// How far each row slides (by index) to show the dragged rows at `target`: the rows keep their sizes and the gaps
  /// between places stay. A row off screen is taken as tall as the rows around it.
  static func offsets(
    spans: [Int: Span], count: Int, dragged: IndexSet, target: Int, draggedLength: CGFloat? = nil
  ) -> [Int: CGFloat] {
    var offsets: [Int: CGFloat] = [:]
    for (row, start) in layout(
      spans: spans, count: count, dragged: dragged, target: target, draggedLength: draggedLength)
    {
      if let span = spans[row], abs(start - span.start) > 0.5 { offsets[row] = start - span.start }
    }
    return offsets
  }

  /// Where each row on screen starts (by index) with the dragged rows at `target`; `draggedLength`: how long the
  /// dragged rows count as (a group collapsed to its first row), when not their own length.
  static func layout(
    spans: [Int: Span], count: Int, dragged: IndexSet, target: Int, draggedLength: CGFloat? = nil
  ) -> [Int: CGFloat] {
    let known = spans.filter { $0.key < count }
    guard let first = known.keys.min() else { return [:] }
    let typical = known.values.map(\.length).reduce(0, +) / CGFloat(known.count)
    func length(_ row: Int) -> CGFloat {
      if let draggedLength, dragged.contains(row) { return draggedLength }
      return spans[row]?.length ?? typical
    }
    // The gap after each place, from the rows on screen (2pt where two neighbours aren't both known).
    func gap(_ place: Int) -> CGFloat {
      guard let a = spans[place], let b = spans[place + 1] else { return 2 }
      return b.start - a.start - a.length
    }
    // Where place 0 starts: the first known row's start, less the rows above it.
    var start = known[first]!.start
    for place in stride(from: first - 1, through: 0, by: -1) { start -= length(place) + gap(place) }
    var starts: [Int: CGFloat] = [:]
    // Collapsed, the dragged rows count as one (a folder with its open rows): the rest sit hidden at its start.
    var block: CGFloat?
    for (place, row) in order(count: count, dragged: dragged, target: target).enumerated() {
      if draggedLength != nil, dragged.contains(row) {
        if let block {
          if spans[row] != nil { starts[row] = block }
          continue
        }
        block = start
      }
      if spans[row] != nil { starts[row] = start }
      start += length(row) + gap(place)
    }
    return starts
  }

  /// The drop of the `dragged` rows (the pointer's row `anchor` among them) at `target`: `.onMove`'s destination,
  /// where the rows sit afterwards, and where the anchor is. `nil` when they are already there.
  static func landing(count: Int, dragged: IndexSet, anchor: Int, target: Int)
    -> (destination: Int, indices: IndexSet, anchor: Int)?
  {
    let dragged = dragged.filteredIndexSet { $0 < count }
    guard !dragged.isEmpty, order(count: count, dragged: dragged, target: target) != Array(0..<count) else {
      return nil
    }
    let others = (0..<count).filter { !dragged.contains($0) }
    let target = min(target, others.count)
    let destination = target < others.count ? others[target] : count
    let moved = IndexSet(integersIn: target..<(target + dragged.count))
    return (destination, moved, target + dragged.count(in: 0..<anchor))
  }
}

/// What a row drag carries out of the app when its row has a URL: the file first (Finder and the like take the first
/// data type, and only a file representation makes them copy the file), the link for a web URL, then the kit's own
/// row type for its reorder targets.
struct ContRowDrag: Transferable {
  let url: URL?

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .data) { drag in
      // The original file: the destination copies or links it, and an in-app drop costs nothing.
      SentTransferredFile(drag.url ?? URL(fileURLWithPath: "/"), allowAccessingOriginalFile: true)
    }
    .suggestedFileName { $0.url?.lastPathComponent }
    .exportingCondition { $0.url?.isFileURL == true }
    ProxyRepresentation(exporting: { (drag: ContRowDrag) in drag.url ?? URL(fileURLWithPath: "/") })
      .exportingCondition { drag in drag.url.map { !$0.isFileURL } ?? false }
    DataRepresentation(exportedContentType: ContReorderState.contentType) { _ in Data() }
      .visibility(.ownProcess)
  }
}

/// A list of rows that reorder by dragging, live: the dragged row lifts as a raised card, a field slot opens where it
/// will land, the rows under the pointer make room, and a drop into another list is refused. `move` takes `.onMove`'s
/// arguments, so `array.move(fromOffsets:toOffset:)` fits it.
///
/// ```swift
/// ReorderableSection(hosts, move: { hosts.move(fromOffsets: $0, toOffset: $1) }) { host in
///   SidebarRow(value: host.id, host.name, systemImage: "server.rack")
/// }
/// ```
public struct ReorderableSection<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
  private let items: [ContIndexed<Data.Element, ID>]
  private let list: AnyHashable?
  private let move: (IndexSet, Int) -> Void
  private let content: (Data.Element) -> RowContent
  private var accepts: [UTType] = []
  private var perform: ((Data.Element, [NSItemProvider]) -> Bool)?
  private var receive: ((AnyHashable, Int, Int) -> Void)?
  private var exportURL: ((Data.Element) -> URL?)?
  private var together: Set<ID> = []
  private var groups = false
  @State private var ownList = UUID()
  @Environment(\.contReorderState) private var shared
  @Environment(\.kitSectionStyle) private var style

  /// Rows for `data`, identified by `id`. `list` names the list when two sections must accept each other's rows
  /// (by default each section is its own list).
  public init(
    _ data: Data, id: KeyPath<Data.Element, ID>, list: AnyHashable? = nil,
    move: @escaping (IndexSet, Int) -> Void, @ViewBuilder content: @escaping (Data.Element) -> RowContent
  ) {
    items = data.enumerated().map { ContIndexed(id: $0.element[keyPath: id], index: $0.offset, element: $0.element) }
    self.list = list
    self.move = move
    self.content = content
  }

  public var body: some View {
    let list = list ?? AnyHashable(ownList)
    let state = shared ?? .app
    let selected = together.isEmpty ? IndexSet() : IndexSet(items.filter { together.contains($0.id) }.map(\.index))
    ForEach(items) { item in
      row(item)
        .modifier(
          ContReorderRow(
            list: list, index: item.index, move: move, state: state, accepts: accepts,
            perform: perform.map { perform in { providers in perform(item.element, providers) } },
            receive: receive,
            group: selected.count > 1 && selected.contains(item.index) ? selected : nil,
            exportURL: exportURL.map { url in { url(item.element) } }, count: items.count, collapses: groups))
    }
  }

  @ViewBuilder
  private func row(_ item: ContIndexed<Data.Element, ID>) -> some View {
    if groups {
      // The element's rows as one view: one drag source, one target, one lifted card and one slot.
      VStack(alignment: .leading, spacing: style == .plain ? 0 : 2) { content(item.element) }
    } else {
      content(item.element)
    }
  }

  /// Lets a row be dragged out of the app as `url` (`nil` for none): a file URL drops into Finder, Mail or Terminal
  /// as the file itself, a web URL as the link. Reordering inside the app goes on as before.
  ///
  /// ```swift
  /// ReorderableSection(projects, move: { projects.move(fromOffsets: $0, toOffset: $1) }) { project in
  ///   SidebarRow(value: project.id, project.name, systemImage: "folder")
  /// }
  /// .exportsURL { $0.folder }
  /// ```
  ///
  /// A multi-row drag (`dragsTogether`) carries the URL of the row under the pointer.
  public func exportsURL(_ url: @escaping (Data.Element) -> URL?) -> Self {
    var section = self
    section.exportURL = url
    return section
  }

  /// Drags the rows of `selection` together: dragging one of them picks them all up (the lifted card shows how
  /// many), they gather where it passes, and `move` gets all their offsets at once. A row outside the selection still
  /// drags alone. Rows dragged together stay in their own list (`receivesRows` takes single rows).
  ///
  /// ```swift
  /// ReorderableSection(files, move: { files.move(fromOffsets: $0, toOffset: $1) }) { file in … }
  ///   .dragsTogether(selectedFiles)
  /// ```
  public func dragsTogether(_ selection: Set<ID>) -> Self {
    var section = self
    section.together = selection
    return section
  }

  /// Drags each element's rows as one group: when `content` draws a row followed by its sub-rows (an SSH host and
  /// its sessions), the whole group lifts, leaves one slot and reorders among the other groups. Sub-rows can be a
  /// `ReorderableSection` of their own: a group dragged over them still moves the groups.
  ///
  /// ```swift
  /// ReorderableSection(hosts, move: { hosts.move(fromOffsets: $0, toOffset: $1) }) { host in
  ///   SidebarRow(value: host.id, host.name, systemImage: "server.rack")
  ///   ReorderableSection(host.sessions, move: { move(host, $0, $1) }) { session in
  ///     SidebarRow(value: session.id, session.name, systemImage: "terminal").kitRowIndent(1)
  ///   }
  /// }
  /// .dragsAsGroup()
  /// ```
  public func dragsAsGroup(_ isOn: Bool = true) -> Self {
    var section = self
    section.groups = isOn
    return section
  }

  /// Lets the rows take other drops too (files, URLs, text): a row under such a drag wears the drop target, and
  /// `perform` gets the row's element and the drag's providers, one per dragged item. Reordering goes on as before.
  /// Drags from this app count too: on macOS, where SwiftUI describes them with no types or the wrong ones, the kit
  /// reads the drag pasteboard for `types` (a file list's rows dropped on a sidebar row).
  ///
  /// ```swift
  /// ReorderableSection(hosts, move: { hosts.move(fromOffsets: $0, toOffset: $1) }) { host in
  ///   SidebarRow(value: host.id, host.name, systemImage: "server.rack")
  /// }
  /// .alsoAccepts([.fileURL]) { host, providers in upload(providers, to: host) }
  /// ```
  public func alsoAccepts(
    _ types: [UTType], perform: @escaping (Data.Element, [NSItemProvider]) -> Bool
  ) -> Self {
    var section = self
    section.accepts = types
    section.perform = perform
    return section
  }

  /// Takes rows dragged in from other lists (sections given a `list` name): as one passes over a row here,
  /// `receive(fromList, fromIndex, toIndex)` asks you to move that element from the other list to `toIndex` in this
  /// one; it then reorders here as usual. Without it a drop from another list is refused.
  ///
  /// ```swift
  /// ReorderableSection(pinned, list: "pinned", move: { pinned.move(fromOffsets: $0, toOffset: $1) }) { … }
  ///   .receivesRows { from, index, to in
  ///     if from == AnyHashable("recent") { pinned.insert(recent.remove(at: index), at: to) }
  ///   }
  /// ```
  public func receivesRows(_ receive: @escaping (_ fromList: AnyHashable, _ fromIndex: Int, _ toIndex: Int) -> Void)
    -> Self
  {
    var section = self
    section.receive = receive
    return section
  }
}

extension ReorderableSection where Data.Element: Identifiable, ID == Data.Element.ID {
  /// Rows for identifiable `data`.
  public init(
    _ data: Data, list: AnyHashable? = nil, move: @escaping (IndexSet, Int) -> Void,
    @ViewBuilder content: @escaping (Data.Element) -> RowContent
  ) {
    self.init(data, id: \.id, list: list, move: move, content: content)
  }
}

struct ContIndexed<Element, ID: Hashable>: Identifiable {
  let id: ID
  let index: Int
  let element: Element
}

extension View {
  /// Makes one row of a hand-built list reorderable by dragging (`ReorderableSection` does this for a whole list).
  /// Rows with the same `list` reorder among themselves; a drop from another list is refused.
  ///
  /// ```swift
  /// ForEach(hosts) { host in
  ///   HostRow(host).kitReorderable(host, in: hosts, list: "hosts") { hosts.move(fromOffsets: $0, toOffset: $1) }
  /// }
  /// ```
  public func kitReorderable<Item: Identifiable>(
    _ item: Item, in items: [Item], list: some Hashable, move: @escaping (IndexSet, Int) -> Void
  ) -> some View {
    modifier(
      ContReorderableModifier(
        list: AnyHashable(list), index: items.firstIndex { $0.id == item.id } ?? 0, count: items.count, move: move))
  }

  /// Makes one row of a hand-built list reorderable by dragging, and lets it take other drops too (files, URLs,
  /// text): under such a drag it wears the drop target and `perform` gets the drag's providers, one per item. Drags
  /// from this app count (see `ReorderableSection.alsoAccepts`). SwiftUI gives a drop to the innermost target only,
  /// so a reorderable row that takes files needs this rather than an `onDrop` of its own.
  ///
  /// ```swift
  /// ForEach(hosts) { host in
  ///   HostRow(host)
  ///     .kitReorderable(host, in: hosts, list: "hosts", alsoAccepts: [.fileURL], perform: { upload($0, to: host) }) {
  ///       hosts.move(fromOffsets: $0, toOffset: $1)
  ///     }
  ///   ForEach(host.sessions) { SessionRow($0).kitRowIndent(1) }
  /// }
  /// ```
  public func kitReorderable<Item: Identifiable>(
    _ item: Item, in items: [Item], list: some Hashable, alsoAccepts types: [UTType],
    perform: @escaping ([NSItemProvider]) -> Bool, move: @escaping (IndexSet, Int) -> Void
  ) -> some View {
    modifier(
      ContReorderableModifier(
        list: AnyHashable(list), index: items.firstIndex { $0.id == item.id } ?? 0, count: items.count, move: move,
        accepts: types, perform: perform))
  }
}

private struct ContReorderableModifier: ViewModifier {
  let list: AnyHashable
  let index: Int
  let count: Int
  let move: (IndexSet, Int) -> Void
  var accepts: [UTType] = []
  var perform: (([NSItemProvider]) -> Bool)? = nil
  @Environment(\.contReorderState) private var shared

  func body(content: Content) -> some View {
    content.modifier(
      ContReorderRow(
        list: list, index: index, move: move, state: shared ?? .app, accepts: accepts, perform: perform, count: count))
  }
}

/// Makes a row a drag source and a drop target of its list.
struct ContReorderRow: ViewModifier {
  let list: AnyHashable
  let index: Int
  let move: (IndexSet, Int) -> Void
  let state: ContReorderState
  var accepts: [UTType] = []
  var perform: (([NSItemProvider]) -> Bool)? = nil
  var receive: ((AnyHashable, Int, Int) -> Void)? = nil
  /// The rows dragged with this one (itself included), when it is part of a multi-row drag.
  var group: IndexSet? = nil
  /// The URL the drag carries out of the app.
  var exportURL: (() -> URL?)? = nil
  /// How many rows the list has (`nil`: as many as have been seen).
  var count: Int? = nil
  /// The direction the list runs.
  var axis: Axis = .vertical
  /// The row is a group (`dragsAsGroup`): dragged, it collapses to its first row, slot and lifted card, so it moves
  /// past its neighbours as far as a row does; its sub-rows come back on the drop.
  var collapses = false
  /// Which rows of the list take dragged rows into them (by index), and what does it (`ReorderableOutline`).
  var nests: ((Int) -> Bool)? = nil
  var nest: ((IndexSet, Int) -> Void)? = nil
  /// The list is a tree drawn flat: the drop's level.
  var levels: ContReorderLevels? = nil
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.contOuterReorder) private var outer
  @State private var isTargeted = false
  /// The row's frame in global coordinates, where it is laid out (its slide while a drag passes doesn't move it): the
  /// drop targets place a drag from their list's frames. In a box rather than in state: it changes on every frame of
  /// a scroll and only a drag reads it, while in state every row would draw again (and hand its rows a new
  /// environment) each frame.
  @State private var geometry = ContRowGeometry()
  /// The row's width, which makes the drag image the row, so it lands on its slot.
  @State private var width: CGFloat?
  /// Counts the row's drags (`ContRowDragSource.generation`).
  @State private var drags = 0

  func body(content: Content) -> some View {
    let delegate = ContReorderDropDelegate(
      list: list, index: index, count: count, move: move, state: state, accepts: accepts, perform: perform,
      receive: receive, isTargeted: $isTargeted, outer: outer, geometry: geometry, nests: nests, nest: nest,
      levels: levels, axis: axis)
    content
      // Reorderable rows inside this one (a group's sub-rows) share its drag and pass its rows' drags to it.
      .environment(\.contReorderState, state)
      .environment(\.contOuterReorder, ContOuterReorder(delegate))
      .kitDropTarget(isTargeted, cornerRadius: ContMetrics.rowRadius(idiom))
      .modifier(
        ContDraggedRowSlot(
          list: list, index: index, axis: axis, collapses: collapses, state: state, geometry: geometry))
      .modifier(ContRowDragSource(begin: begin, exportURL: exportURL, generation: drags, preview: preview(content)))
      .modifier(ContDragSessionEnd(state: state, ended: { drags += 1 }))
      // Outside the slide: the target stays where the row is laid out, so the rows under the drag cover the list, and
      // reaches over the gaps between rows (a drag resting in one got no updates: moving across there changed
      // nothing); the layout is padded back.
      .padding(axis == .vertical ? .vertical : .horizontal, ContReorderDropDelegate.reach)
      .onDrop(of: [ContReorderState.contentType] + accepts, delegate: delegate)
      .padding(axis == .vertical ? .vertical : .horizontal, -ContReorderDropDelegate.reach)
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { [geometry] in geometry.frame = $0 }
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
      .onAppear { state.register(geometry, in: list, at: index) }
      .onChange(of: index) { state.register(geometry, in: list, at: index) }
      .onChange(of: list) { state.register(geometry, in: list, at: index) }
      .onDisappear { state.unregister(geometry) }
      // Above the rows after it: the slot draws where the drop goes on top of them.
      .zIndex(state.isSlot(list, at: index, collapses: collapses) ? 1 : 0)
  }

  /// Called as the drag starts (on the main thread, though the drag source's closures aren't isolated).
  private func begin() {
    let (state, list, index, group, axis, collapses, idiom) = (state, list, index, group, axis, collapses, idiom)
    let length = collapses ? KitMetrics.row(idiom) : nil
    MainActor.assumeIsolated { state.start(list, at: index, with: group, axis: axis, collapsedLength: length) }
  }

  private func preview(_ content: Content) -> some View {
    content
      .frame(height: collapses ? KitMetrics.row(idiom) : nil, alignment: .top)
      .clipped()
      .kitLifted(true, cornerRadius: ContMetrics.rowRadius(idiom))
      .overlay(alignment: .topTrailing) {
        if !collapses, let group, group.count > 1 {
          Count(group.count, .attention).offset(x: 6, y: -6)
        }
      }
      .frame(width: width ?? 220)
      .padding(8)
  }
}

/// The drag half: the kit's own row type only, or, with a URL, the file or link first (see `ContRowDrag`).
private struct ContRowDragSource<Preview: View>: ViewModifier {
  let begin: () -> Void
  let exportURL: (() -> URL?)?
  /// Counts the row's drags: SwiftUI on macOS keeps the item a drag source gave until the source changes, so a
  /// drag that left the rows as they were (dropped back on its slot) made the next one start without calling it, and
  /// without the kit hearing of it. A new count makes the next drag ask again.
  let generation: Int
  let preview: Preview

  func body(content: Content) -> some View {
    if let exportURL {
      // `draggable` asks for its payload only as the drag starts.
      content.draggable(drag(exportURL)) { preview }
    } else {
      content.onDrag {
        begin()
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
          forTypeIdentifier: ContReorderState.contentType.identifier, visibility: .ownProcess
        ) { completion in
          completion(Data(), nil)
          return nil
        }
        return provider
      } preview: {
        preview
      }
    }
  }

  private func drag(_ url: () -> URL?) -> ContRowDrag {
    begin()
    return ContRowDrag(url: url())
  }
}

/// A reorderable row's frame in global coordinates, which the drop targets read as a drag passes, and where it is
/// registered (`ContReorderState.register`).
@MainActor final class ContRowGeometry {
  var frame: CGRect = .zero
  var place: (list: AnyHashable, index: Int)?
}

/// The reorder target of the row around this one (a group around its sub-rows), boxed: a target holds its outer one.
final class ContOuterReorder {
  let delegate: ContReorderDropDelegate
  init(_ delegate: ContReorderDropDelegate) { self.delegate = delegate }
}

extension EnvironmentValues {
  @Entry var contOuterReorder: ContOuterReorder? = nil
}

/// While a drag passes over its list, the row slides to show where the drag would land. While its row is dragged (the
/// drag image is the lifted card), the row is the field slot it will sit back into, at the place it would land
/// (`ContDragSessionEnd` clears it as the session ends). Before macOS 26 and iOS 27 nothing reports a drag that ends
/// away from any row, so there the row stays drawn.
private struct ContDraggedRowSlot: ViewModifier {
  let list: AnyHashable
  let index: Int
  let axis: Axis
  let collapses: Bool
  let state: ContReorderState
  let geometry: ContRowGeometry
  @Environment(\.kitIdiom) private var idiom

  func body(content: Content) -> some View {
    let offset = state.offset(list, at: index)
    let isSlot = state.isSlot(list, at: index, collapses: collapses)
    slot(content)
      .offset(x: axis == .horizontal ? offset : 0, y: axis == .vertical ? offset : 0)
      // Where the drop goes, above the drag image: the folder it names may be out of sight.
      .overlay(alignment: .topLeading) {
        if isSlot, let hint = state.hint {
          // Every frame from the pointer itself where the platform gives it (the Mac): the drop's updates stop
          // wherever no row is under the pointer.
          TimelineView(.animation) { _ in
            let pointer = ContPlatform.pointerInWindow ?? state.pointer
            ContDropHint(title: hint)
              .position(
                x: pointer.x - geometry.frame.minX, y: pointer.y - state.hintLift - geometry.frame.minY - 20)
          }
          .allowsHitTesting(false)
          .transition(.opacity)
        }
      }
  }

  @ViewBuilder
  private func slot(_ content: Content) -> some View {
    if #available(macOS 26.0, iOS 27.0, visionOS 27.0, *) {
      let isDragging = state.isMoving && state.isDragging(list, at: index)
      // Collapsed rows dragged together (a folder and its open rows) show one slot, the first's.
      let isSlot = isDragging && (!collapses || state.indices.first == index)
      content
        .kitDropTarget(state.receives(list, at: index), cornerRadius: ContMetrics.rowRadius(idiom))
        .opacity(isDragging ? 0 : 1)
        // A group's slot is its first row: its rows count as that one while dragged (`ContReorderState.start`), and
        // the layout keeps their room (shrinking it would move a scrolled list under the pointer).
        .background(alignment: .top) {
          if isSlot {
            RoundedRectangle(cornerRadius: ContMetrics.rowRadius(idiom), style: .continuous).fill(.kitField)
              .frame(height: collapses ? KitMetrics.row(idiom) : nil)
              // In a tree, the slot moves in to the level the rows would land at.
              .padding(.leading, CGFloat(state.level ?? 0) * state.levelStep)
          }
        }
    } else {
      content
    }
  }
}

/// The name of where a drop goes, floating above the drag image: a keycap, opaque over the rows under it.
private struct ContDropHint: View {
  let title: String

  var body: some View { Keycap(title) }
}

/// Ends the drag with its session: a drag can end away from any row (cancelled, or dropped outside the app), and then
/// the rows slide back. Outside the drag source, where the session's updates arrive.
private struct ContDragSessionEnd: ViewModifier {
  let state: ContReorderState
  /// The session ended (see `ContRowDragSource.generation`).
  var ended: () -> Void = {}

  func body(content: Content) -> some View {
    if #available(macOS 26.0, iOS 27.0, visionOS 27.0, *) {
      content
        .dragConfiguration(DragConfiguration(allowMove: true))
        .onDragSessionUpdated { session in
          switch session.phase {
          case .ended:
            ended()
            if state.list != nil { withAnimation(.kit) { state.end() } }
          case .active: state.sessionMoved()
          default: break
          }
        }
    } else {
      content
    }
  }
}

/// The drop half: while the drag passes over a row of its list, the rows show where it would land, and the drop moves
/// it there. Only a row of the same list is a target, so a drag across lists is refused rather than mis-moving a row;
/// a drag of the list around this row (a group dragged over a group's sub-rows) goes to that list's target.
struct ContReorderDropDelegate: DropDelegate {
  let list: AnyHashable
  let index: Int
  /// How many rows the list has (`nil`: as many as have been seen).
  var count: Int? = nil
  let move: (IndexSet, Int) -> Void
  let state: ContReorderState
  var accepts: [UTType] = []
  var perform: (([NSItemProvider]) -> Bool)? = nil
  var receive: ((AnyHashable, Int, Int) -> Void)? = nil
  var isTargeted: Binding<Bool>? = nil
  /// The target of the row around this one, for drags of its list.
  var outer: ContOuterReorder? = nil
  /// Where the row is, in global coordinates.
  var geometry: ContRowGeometry? = nil
  /// Which rows take dragged rows into them, and what does it (`ContReorderRow.nests`).
  var nests: ((Int) -> Bool)? = nil
  var nest: ((IndexSet, Int) -> Void)? = nil
  var levels: ContReorderLevels? = nil
  /// The direction the list runs: the target reaches `reach` past the row's ends that way.
  var axis: Axis = .vertical

  /// How far a row's drop target reaches past it along the list, over half the gap to its neighbour and a little more.
  static let reach: CGFloat = 1.5

  /// The row's frame in global coordinates (`.zero` before its first layout).
  var frame: CGRect { geometry?.frame ?? .zero }

  /// The pointer in global coordinates: `DropInfo` gives it in this row's, and a forwarded drag needs it in the outer
  /// row's.
  private func pointer(_ info: DropInfo) -> CGPoint {
    CGPoint(
      x: frame.minX + info.location.x - (axis == .horizontal ? Self.reach : 0),
      y: frame.minY + info.location.y - (axis == .vertical ? Self.reach : 0))
  }

  /// The list's row count: given, or past the furthest row seen.
  @MainActor private var rows: Int { count ?? max(index + 1, (state.indices.max() ?? 0) + 1) }

  /// Whether the drag is a kit row. Read from the drag pasteboard on macOS: `DropInfo` describes a drag SwiftUI started
  /// in this process with no types.
  private func isRow(_ info: DropInfo) -> Bool {
    #if canImport(AppKit)
      NSPasteboard(name: .drag).types?.contains(NSPasteboard.PasteboardType(ContReorderState.contentType.identifier))
        ?? false
    #else
      info.hasItemsConforming(to: [ContReorderState.contentType])
    #endif
  }

  /// A drop of one of the other accepted types (a file, a URL) rather than a row. On macOS the drag pasteboard is read
  /// too: a drag started in this app (a file list's row, a chip) reaches `DropInfo` with no types or the wrong ones.
  private func isOther(_ info: DropInfo) -> Bool {
    perform != nil && !isRow(info) && (info.hasItemsConforming(to: accepts) || ContDragPasteboard.has(accepts))
  }

  /// The outer target, when the dragged row belongs to its list rather than this one.
  private func forwarded(_ info: DropInfo) -> ContReorderDropDelegate? {
    guard let source = state.list, source != list, isRow(info) else { return nil }
    var target = outer?.delegate
    while let candidate = target {
      if candidate.list == source { return candidate }
      target = candidate.outer?.delegate
    }
    return nil
  }

  func validateDrop(info: DropInfo) -> Bool {
    if let outer = forwarded(info) { return outer.validateDrop(info: info) }
    if isOther(info) { return true }
    // Rows dragged together stay in their list.
    let single = state.count <= 1 || state.list == list
    return isRow(info) && single && ContReorder.accepts(from: state.list, into: list, receives: receive != nil)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? { updated(info, at: pointer(info)) }

  func dropEntered(info: DropInfo) { entered(info, at: pointer(info)) }

  private func updated(_ info: DropInfo, at pointer: CGPoint, throughSubRow: Bool = false) -> DropProposal? {
    if let outer = forwarded(info) { return outer.updated(info, at: pointer, throughSubRow: true) }
    if isOther(info) { return DropProposal(operation: .copy) }
    let isValid = validateDrop(info: info)
    if isValid {
      state.retarget(list, count: rows, pointer: pointer, throughSubRow: throughSubRow, nests: nests, levels: levels)
    }
    return DropProposal(operation: isValid ? .move : .forbidden)
  }

  private func entered(_ info: DropInfo, at pointer: CGPoint, throughSubRow: Bool = false) {
    if let outer = forwarded(info) { return outer.entered(info, at: pointer, throughSubRow: true) }
    if isOther(info) {
      withAnimation(.kitFast) { isTargeted?.wrappedValue = true }
      return
    }
    guard isRow(info), let from = state.index, let fromList = state.list else { return }
    if fromList != list {
      // A row from another list: the app moves it here, then it reorders here.
      guard let receive, state.count <= 1 else { return }
      withAnimation(.kit) {
        receive(fromList, from, index)
        state.begin(list, at: index)
      }
      return
    }
    state.retarget(list, count: rows, pointer: pointer, throughSubRow: throughSubRow, nests: nests, levels: levels)
  }

  func dropExited(info: DropInfo) {
    if let outer = forwarded(info) { return outer.dropExited(info: info) }
    if isTargeted?.wrappedValue == true { withAnimation(.kitFast) { isTargeted?.wrappedValue = false } }
    if state.list == list { state.leave(list, at: pointer(info)) }
  }

  func performDrop(info: DropInfo) -> Bool {
    if let outer = forwarded(info) { return outer.performDrop(info: info) }
    if isOther(info), let perform {
      isTargeted?.wrappedValue = false
      // One provider per dragged item, read from the drag pasteboard where it has them (macOS); else SwiftUI's.
      let pasted = ContDragPasteboard.providers(for: accepts)
      return perform(pasted.isEmpty ? info.itemProviders(for: accepts) : pasted)
    }
    guard isRow(info) else { return false }
    state.land(in: list, count: rows, move: move, nest: nest)
    state.endAfterLanding()
    return true
  }
}

// MARK: - The drag pasteboard

/// What the drag pasteboard holds, for the drops SwiftUI describes badly: on macOS `DropInfo` gives a drag started in
/// this process no types or the wrong ones, and one opaque provider for a multi-file drag, while
/// `NSPasteboard(name: .drag)` has the real items, one per file. Nothing on other platforms.
@MainActor
enum ContDragPasteboard {
  /// The pasteboard types (identifiers, in order) that conform to one of `accepts`.
  nonisolated static func matching(_ types: [String], accepts: [UTType]) -> [String] {
    types.filter { identifier in
      guard let type = UTType(identifier) else { return false }
      return accepts.contains { type.conforms(to: $0) }
    }
  }

  /// Whether the drag in progress carries an item of one of `accepts`.
  static func has(_ accepts: [UTType]) -> Bool {
    #if canImport(AppKit)
      guard !accepts.isEmpty, let types = NSPasteboard(name: .drag).types else { return false }
      return !matching(types.map(\.rawValue), accepts: accepts).isEmpty
    #else
      false
    #endif
  }

  /// One provider per item of the drag that carries one of `accepts`, holding that item's data for those types (read
  /// now, while the drag pasteboard still has it). Empty when none does (a file promise), or off macOS.
  static func providers(for accepts: [UTType]) -> [NSItemProvider] {
    #if canImport(AppKit)
      guard !accepts.isEmpty else { return [] }
      return (NSPasteboard(name: .drag).pasteboardItems ?? []).compactMap { item in
        let types = matching(item.types.map(\.rawValue), accepts: accepts)
        let data = types.compactMap { type in item.data(forType: .init(type)).map { (type, $0) } }
        guard !data.isEmpty else { return nil }
        let provider = NSItemProvider()
        for (type, bytes) in data {
          provider.registerDataRepresentation(forTypeIdentifier: type, visibility: .all) { completion in
            completion(bytes, nil)
            return nil
          }
        }
        return provider
      }
    #else
      []
    #endif
  }
}
