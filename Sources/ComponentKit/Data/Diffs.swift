import SwiftUI

// MARK: - Lines

/// One line of a diff: context, added or removed, its old and new line numbers, the text (plain or already coloured by
/// a highlighter) and the changed words as character ranges, which the hunk draws in a stronger tint.
///
/// ```swift
/// DiffLine(.added, new: 32, text: "private func load() throws {", highlights: [19..<26])
/// ```
///
/// Plain text stays a `String` until a line is drawn, so a diff of a million lines costs little more than its text.
public struct DiffLine: Identifiable, Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    case context, added, removed
  }

  private enum Content: Hashable, Sendable {
    case plain(String)
    case attributed(AttributedString)
  }

  public var kind: Kind
  public var oldNumber: Int?
  public var newNumber: Int?
  private var content: Content
  /// Changed words, as character offsets into `text`.
  public var highlights: [Range<Int>]
  /// Unique within a hunk, or across every hunk sharing a selection: the app's own id for the line, else one made
  /// from its old and new numbers (`DiffLine.id(old:new:)`).
  public var id: Int

  public var isChange: Bool { kind != .context }

  public var text: AttributedString {
    get {
      switch content {
      case .plain(let string): AttributedString(string)
      case .attributed(let text): text
      }
    }
    set { content = .attributed(newValue) }
  }

  /// The text when it has no attributes.
  var plain: String? {
    if case .plain(let string) = content { string } else { nil }
  }

  /// The text without its attributes.
  public var string: String {
    switch content {
    case .plain(let string): string
    case .attributed(let text): String(text.characters)
    }
  }

  public init(
    _ kind: Kind, old: Int? = nil, new: Int? = nil, text: AttributedString, highlights: [Range<Int>] = [],
    id: Int? = nil
  ) {
    self.kind = kind
    self.oldNumber = old
    self.newNumber = new
    self.content = .attributed(text)
    self.highlights = highlights
    self.id = id ?? Self.id(old: old, new: new)
  }

  public init(
    _ kind: Kind, old: Int? = nil, new: Int? = nil, text: String, highlights: [Range<Int>] = [], id: Int? = nil
  ) {
    self.kind = kind
    self.oldNumber = old
    self.newNumber = new
    self.content = .plain(text)
    self.highlights = highlights
    self.id = id ?? Self.id(old: old, new: new)
  }

  /// The id a line with these numbers gets when the app gives none: unique within a hunk.
  public static func id(old: Int?, new: Int?) -> Int {
    ((old ?? -1) + 1) << 32 | ((new ?? -1) + 1)
  }

  /// Pairs the lines for side by side: context on both sides, a run of removed lines beside the added run that
  /// follows it, `nil` where a side has no line.
  public static func splitRows(_ lines: [DiffLine]) -> [(old: DiffLine?, new: DiffLine?)] {
    var rows: [(old: DiffLine?, new: DiffLine?)] = []
    var removed: [DiffLine] = []
    var added: [DiffLine] = []
    func flush() {
      for i in 0..<max(removed.count, added.count) {
        rows.append((i < removed.count ? removed[i] : nil, i < added.count ? added[i] : nil))
      }
      removed = []
      added = []
    }
    for line in lines {
      switch line.kind {
      case .context:
        flush()
        rows.append((line, line))
      case .removed:
        if !added.isEmpty { flush() }
        removed.append(line)
      case .added:
        added.append(line)
      }
    }
    flush()
    return rows
  }

  /// The text with the changed words given a background.
  func marked(_ color: Color) -> AttributedString {
    var text = text
    let count = text.characters.count
    for range in highlights where range.lowerBound < count && !range.isEmpty {
      let start = text.characters.index(text.startIndex, offsetBy: range.lowerBound)
      let end = text.characters.index(text.startIndex, offsetBy: min(range.upperBound, count))
      text[start..<end].backgroundColor = color
    }
    return text
  }
}

/// How a hunk lays its lines out: one column, or old and new side by side.
public enum DiffLayout: Hashable, Sendable {
  case unified, split
}

/// What a hunk does with a line longer than the card: cut it at the end, or scroll the lines sideways together.
public enum DiffOverflow: Hashable, Sendable {
  case truncate, scroll
}

// MARK: - Hunk card

/// A hunk as a card, headed by the function it's in and its range. Gutters have no fill: the whole line carries the
/// added or removed tint, changed words a stronger one. Hovering a changed line shows a + that stages it; clicking
/// selects it (the accent bar) and the header offers Stage N Lines. A staged hunk folds to its header and a summary
/// line, with Unstage. Put the cards for a file in a `VStack(spacing: 10)` on the panel ground.
///
/// Selecting lines: a click toggles one, ⇧-click selects the run from the last one clicked, and a drag down the lines
/// selects the run it passes over. Right-click (or ⌘C on the Mac) copies the selected lines, or the one under the
/// pointer. Lines draw lazily inside a scroll view, so a huge hunk stays cheap; `overflow: .scroll` scrolls long
/// lines sideways together instead of cutting them. A staged hunk with `unstageLines` unstages lines the same way.
///
/// ```swift
/// HunkCard(header: "public final class TripStore", range: "@@ -23,8 +24,13 @@", lines: hunk.lines,
///          selection: $selectedLines, stage: { lines in repo.stage(lines) })
/// HunkCard(header: "TripStore", range: "@@ -14,6 +14,7 @@", lines: staged.lines, isStaged: true,
///          summary: "1 line added in add(_:)", unstage: { repo.unstage(staged) })
/// HunkCard(header: "TripStore", range: "@@ -14,6 +14,7 @@", lines: staged.lines, isStaged: true,
///          selection: $selectedLines, unstage: { … }, unstageLines: { repo.unstage($0) }, overflow: .scroll)
/// ```
public struct HunkCard: View {
  var header: String
  var range: String
  var lines: [DiffLine]
  var layout: DiffLayout
  var isStaged: Bool
  var summary: String?
  var selection: Binding<Set<DiffLine.ID>>?
  var stage: (([DiffLine]) -> Void)?
  var unstage: (() -> Void)?
  var unstageLines: (([DiffLine]) -> Void)?
  var overflow: DiffOverflow
  @State private var expanded: Bool?
  @State private var hovered: DiffLine.ID?
  @State private var anchor: DiffLine.ID?
  @State private var dragStart: Int?
  @State private var width: CGFloat = 0
  /// The widest line's text, for `overflow: .scroll` (every row stretches to the widest one).
  @State private var textWidth: CGFloat = 0
  /// How far the lines are scrolled sideways, for `overflow: .scroll`: every block of lines follows it.
  @State private var scrollX: CGFloat = 0
  @Environment(\.kitIdiom) private var idiom

  public init(
    header: String, range: String, lines: [DiffLine], layout: DiffLayout = .unified, isStaged: Bool = false,
    summary: String? = nil, selection: Binding<Set<DiffLine.ID>>? = nil, stage: (([DiffLine]) -> Void)? = nil,
    unstage: (() -> Void)? = nil, unstageLines: (([DiffLine]) -> Void)? = nil, overflow: DiffOverflow = .truncate
  ) {
    self.header = header
    self.range = range
    self.lines = lines
    self.layout = layout
    self.isStaged = isStaged
    self.summary = summary
    self.selection = selection
    self.stage = stage
    self.unstage = unstage
    self.unstageLines = unstageLines
    self.overflow = overflow
  }

  /// What a line's own action does: stage it, or (staged) unstage it.
  private var lineAction: (([DiffLine]) -> Void)? { isStaged ? unstageLines : stage }

  private var isExpanded: Bool { expanded ?? !isStaged }
  private var selected: Set<DiffLine.ID> { selection?.wrappedValue ?? [] }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      headerRow
      if isExpanded {
        Group {
          switch layout {
          case .unified:
            unifiedLines
          case .split:
            splitLines
          }
        }
        .transition(.opacity)
      } else if let summary {
        Text(summary)
          .kitFont(.caption)
          .padding(EdgeInsets(top: -6, leading: 30, bottom: 0, trailing: 12))
          .padding(.bottom, 4)
      }
    }
    .padding(.bottom, 6)
    .kitSurface(.card)
    .clipShape(RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous))
    .onChange(of: isStaged) { expanded = nil }
    .animation(.kit, value: isExpanded)
    .modifier(DiffCopyCommand(text: { copiedText(for: nil) }))
  }

  /// The title and range with the actions after them; where the card is narrow (an iPhone) the actions go on a line of
  /// their own rather than squeezing the title.
  private var headerRow: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 8) {
        headerTitle
        Spacer(minLength: 8)
        headerActions
      }
      .frame(height: idiom.size(38, touch: 46))
      VStack(alignment: .trailing, spacing: 4) {
        HStack(spacing: 8) { headerTitle }
          .frame(maxWidth: .infinity, minHeight: idiom.size(32, touch: 40), alignment: .leading)
        HStack(spacing: 8) { headerActions }
      }
      .padding(.bottom, 6)
    }
    .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 6))
  }

  @ViewBuilder private var headerTitle: some View {
    Button {
      withKitAnimation { expanded = !isExpanded }
    } label: {
      Image(systemName: "chevron.down")
        .font(.system(size: 10, weight: .semibold))
        .rotationEffect(.degrees(isExpanded ? 0 : -90))
        .frame(width: 16, height: 16)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(.kitSecondary)
    .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
    Text(header)
      .font(.system(size: 12, weight: .semibold))
      .lineLimit(1)
      .frame(minWidth: 100, alignment: .leading)
      .layoutPriority(-1)
    Text(range)
      .font(.system(size: 11, design: .monospaced))
      .foregroundStyle(.kitSecondary)
      .lineLimit(1)
      .fixedSize()
  }

  @ViewBuilder private var headerActions: some View {
    if isStaged {
      Label("Staged", systemImage: "checkmark")
        .labelStyle(KitButtonLabelStyle(iconOnly: false))
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Hue.green.text)
      if let unstageLines {
        let chosen = chosenLines
        if !chosen.isEmpty {
          Button(chosen.count == 1 ? "Unstage 1 Line" : "Unstage \(chosen.count) Lines") {
            unstageLines(chosen)
            selection?.wrappedValue = []
          }
          .buttonStyle(.dataSoft)
          .transition(.opacity)
        }
      }
      if let unstage { Button("Unstage", action: unstage).buttonStyle(.dataSoft) }
    } else if let stage {
      let chosen = chosenLines
      if !chosen.isEmpty {
        Button(chosen.count == 1 ? "Stage 1 Line" : "Stage \(chosen.count) Lines") {
          stage(chosen)
          selection?.wrappedValue = []
        }
        .buttonStyle(.kitPrimary)
        .controlSize(.small)
        .transition(.opacity)
      }
      Button("Stage Hunk") { stage(lines.filter(\.isChange)) }.buttonStyle(.dataSoft)
    }
  }

  /// The selected changed lines (none to look through while nothing is selected, as in a huge hunk).
  private var chosenLines: [DiffLine] {
    selected.isEmpty ? [] : lines.filter { selected.contains($0.id) && $0.isChange }
  }

  // MARK: Unified

  /// Lines per horizontal scroll view with `overflow: .scroll`. A scroll view builds all of its content, even a lazy
  /// stack's, so a long hunk scrolls sideways in blocks that the lazy stack builds as they come into view.
  static let scrollBlock = 50

  /// The lines, lazily (a scroll view around the card keeps a huge hunk cheap), scrolling sideways together when
  /// `overflow` is `.scroll`; a drag down them selects the run it passes over.
  @ViewBuilder
  private var unifiedLines: some View {
    let stack = LazyVStack(alignment: .leading, spacing: 0) {
      switch overflow {
      case .truncate:
        ForEach(lines) { line in unifiedLine(line) }
      case .scroll:
        ForEach(Array(stride(from: 0, to: lines.count, by: Self.scrollBlock)), id: \.self) { start in
          let end = min(start + Self.scrollBlock, lines.count)
          // The scroller shows under the last block only, not every 50 lines.
          DiffScrollBlock(offset: $scrollX, showsIndicator: end == lines.count) {
            VStack(alignment: .leading, spacing: 0) {
              ForEach(lines[start..<end]) { line in
                unifiedLine(line).frame(width: max(width, textWidth + DiffSelect.gutterWidth))
              }
            }
            .frame(minWidth: width, alignment: .leading)
          }
        }
      }
    }
    .coordinateSpace(name: DiffSpace.lines)
    #if !os(tvOS)
    .simultaneousGesture(dragSelect, including: selection == nil ? .subviews : .all)
    #endif
    if overflow == .scroll {
      stack.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    } else {
      stack
    }
  }

  private enum DiffSpace: Hashable { case lines }

  #if !os(tvOS)
  /// A drag down the lines selects them: rows are at least 20pt, so the index under the pointer is its height over 20.
  private var dragSelect: some Gesture {
    DragGesture(minimumDistance: 6, coordinateSpace: .named(DiffSpace.lines))
      .onChanged { drag in
        guard selection != nil, !lines.isEmpty else { return }
        let start = dragStart ?? DiffSelect.index(atY: drag.startLocation.y, count: lines.count)
        dragStart = start
        let end = DiffSelect.index(atY: drag.location.y, count: lines.count)
        selectRun(from: start, to: end)
      }
      .onEnded { _ in dragStart = nil }
  }
  #endif

  private func selectRun(from start: Int, to end: Int) {
    guard let selection, canSelect else { return }
    let ids = DiffSelect.run(lines.map { ($0.id, $0.isChange) }, from: start, to: end)
    selection.wrappedValue = Set(ids)
  }

  private var canSelect: Bool { !isStaged || unstageLines != nil }

  private func unifiedLine(_ line: DiffLine) -> some View {
    let isSelected = selected.contains(line.id)
    let isHovered = hovered == line.id
    return HStack(spacing: 0) {
      number(line.oldNumber, line: line, selected: isSelected).frame(width: 38, alignment: .trailing)
      number(line.newNumber, line: line, selected: isSelected).frame(width: 38, alignment: .trailing)
      Text(sign(line))
        .foregroundStyle(signStyle(line))
        .frame(width: 18)
      code(line)
        .padding(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .font(.system(size: 12, design: .monospaced))
    .frame(minHeight: 20)
    .background { LineGround(line: line, selected: isSelected, hovered: isHovered) }
    .overlay(alignment: .leading) {
      if line.isChange, isHovered, let lineAction {
        StageLineButton(unstages: isStaged) { lineAction([line]) }.padding(.leading, 5)
      }
    }
    .contentShape(Rectangle())
    .kitHover { inside in
      if inside { hovered = line.id } else if hovered == line.id { hovered = nil }
    }
    .onTapGesture { toggle(line) }
    .kitContextMenu { copyMenu(line) }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func toggle(_ line: DiffLine) {
    guard line.isChange, let selection, canSelect else { return }
    withKitAnimation(.kitFast) {
      if ContPlatform.isShiftDown, let anchor, let from = lines.firstIndex(where: { $0.id == anchor }),
        let to = lines.firstIndex(where: { $0.id == line.id })
      {
        selection.wrappedValue.formUnion(DiffSelect.run(lines.map { ($0.id, $0.isChange) }, from: from, to: to))
      } else if selection.wrappedValue.contains(line.id) {
        selection.wrappedValue.remove(line.id)
      } else {
        selection.wrappedValue.insert(line.id)
      }
    }
    anchor = line.id
  }

  @ViewBuilder
  private func copyMenu(_ line: DiffLine) -> some View {
    let count = selected.contains(line.id) ? lines.filter { selected.contains($0.id) }.count : 1
    Button(count == 1 ? "Copy Line" : "Copy \(count) Lines", systemImage: "doc.on.doc") {
      KitPasteboard.copy(copiedText(for: line))
    }
  }

  /// The selected lines' text (the line under the pointer, or `line`, when it isn't among them), one per line.
  private func copiedText(for line: DiffLine?) -> String {
    let chosen: [DiffLine]
    if let line, !selected.contains(line.id) {
      chosen = [line]
    } else if !selected.isEmpty {
      chosen = lines.filter { selected.contains($0.id) }
    } else if let hovered, let line = lines.first(where: { $0.id == hovered }) {
      chosen = [line]
    } else {
      chosen = []
    }
    return chosen.map(\.string).joined(separator: "\n")
  }

  private func number(_ value: Int?, line: DiffLine, selected: Bool) -> some View {
    Text(value.map(String.init) ?? "")
      .font(.system(size: 11, design: .monospaced))
      .monospacedDigit()
      .foregroundStyle(selected ? AnyShapeStyle(Hue.accent.text) : numberStyle(line))
      .padding(.trailing, 6)
  }

  private func numberStyle(_ line: DiffLine) -> AnyShapeStyle {
    switch line.kind {
    case .added: AnyShapeStyle(Hue.green.text)
    case .removed: AnyShapeStyle(Hue.red.text)
    case .context: AnyShapeStyle(.kitQuiet)
    }
  }

  private func sign(_ line: DiffLine) -> String {
    switch line.kind {
    case .added: "+"
    case .removed: "−"
    case .context: ""
    }
  }

  private func signStyle(_ line: DiffLine) -> AnyShapeStyle {
    line.kind == .context ? AnyShapeStyle(.kitQuiet) : numberStyle(line)
  }

  @ViewBuilder
  private func code(_ line: DiffLine) -> some View {
    if overflow == .scroll && layout == .unified {
      WordMarkedText(line: line).lineLimit(1).fixedSize(horizontal: true, vertical: false)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = max(textWidth, $0) }
    } else {
      WordMarkedText(line: line).lineLimit(1).truncationMode(.tail)
    }
  }

  // MARK: Split

  private var splitLines: some View {
    LazyVStack(spacing: 0) {
      ForEach(Array(DiffLine.splitRows(lines).enumerated()), id: \.offset) { _, row in
        HStack(spacing: 0) {
          splitHalf(row.old, number: row.old?.oldNumber, side: .removed)
          Rectangle().fill(.kitSeparator).frame(width: 1)
          splitHalf(row.new, number: row.new?.newNumber, side: .added)
        }
        .fixedSize(horizontal: false, vertical: true)
      }
    }
    .font(.system(size: 12, design: .monospaced))
  }

  @ViewBuilder
  private func splitHalf(_ line: DiffLine?, number: Int?, side: DiffLine.Kind) -> some View {
    if let line {
      let isSelected = selected.contains(line.id)
      HStack(spacing: 0) {
        self.number(number, line: line, selected: isSelected).frame(width: 34, alignment: .trailing)
        code(line)
          .padding(.trailing, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxWidth: .infinity, minHeight: 20)
      .background { LineGround(line: line, selected: isSelected, hovered: hovered == line.id) }
      .contentShape(Rectangle())
      .kitHover { inside in
        if inside { hovered = line.id } else if hovered == line.id { hovered = nil }
      }
      .onTapGesture { toggle(line) }
      .kitContextMenu { copyMenu(line) }
    } else {
      EmptySideStripes().frame(maxWidth: .infinity, minHeight: 20)
    }
  }
}

/// Selecting runs of diff lines, apart from views.
enum DiffSelect {
  /// What a unified line holds besides its text: two number columns, the sign, the text's padding.
  static let gutterWidth: CGFloat = 38 + 38 + 18 + 4 + 10

  /// The line under `y` in a column of 20pt rows, clamped to the lines.
  static func index(atY y: CGFloat, count: Int) -> Int {
    min(max(Int(y / 20), 0), max(count - 1, 0))
  }

  /// The changed lines between `from` and `to` (either order, both included).
  static func run<ID>(_ lines: [(id: ID, isChange: Bool)], from: Int, to: Int) -> [ID] {
    guard !lines.isEmpty else { return [] }
    let low = max(min(from, to), 0)
    let high = min(max(from, to), lines.count - 1)
    guard low <= high else { return [] }
    return lines[low...high].filter(\.isChange).map(\.id)
  }
}

/// ⌘C copies the hunk's selected lines (the Mac's Copy command; touch idioms copy from the context menu).
private struct DiffCopyCommand: ViewModifier {
  let text: () -> String

  func body(content: Content) -> some View {
    #if os(macOS)
      content.onCopyCommand {
        let string = text()
        return string.isEmpty ? [] : [NSItemProvider(object: string as NSString)]
      }
    #else
      content
    #endif
  }
}

/// A block of a hunk's lines in a horizontal scroll view that keeps to the hunk's shared offset: scrolling one block
/// scrolls the others, and a block coming into view starts where they are. Before macOS 15 and iOS 18 each block
/// scrolls on its own.
private struct DiffScrollBlock<Content: View>: View {
  @Binding var offset: CGFloat
  var showsIndicator: Bool
  @ViewBuilder var content: Content

  var body: some View {
    let scroll = ScrollView(.horizontal) { content }
      .scrollIndicators(showsIndicator ? .automatic : .hidden)
    if #available(macOS 15, iOS 18, *) {
      scroll.modifier(DiffScrollSync(offset: $offset))
    } else {
      scroll
    }
  }
}

@available(macOS 15, iOS 18, *)
private struct DiffScrollSync: ViewModifier {
  @Binding var offset: CGFloat
  @State private var position = ScrollPosition(edge: .leading)
  /// This block's own offset, so it isn't moved to where it already is (that would stop a fling).
  @State private var current: CGFloat = 0

  func body(content: Content) -> some View {
    content
      .scrollPosition($position)
      .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in
        current = x
        if abs(x - offset) > 0.5 { offset = x }
      }
      .onChange(of: offset) { _, x in follow(x) }
      .onAppear { follow(offset) }
  }

  private func follow(_ x: CGFloat) {
    guard abs(x - current) > 0.5 else { return }
    position.scrollTo(x: x)
  }
}

/// A line's text with its changed words on a stronger tint of the line's hue.
private struct WordMarkedText: View {
  let line: DiffLine
  @Environment(\.self) private var environment

  var body: some View {
    if line.highlights.isEmpty, let plain = line.plain {
      Text(verbatim: plain)
    } else {
      marked
    }
  }

  private var marked: Text {
    switch line.kind {
    case .added: Text(line.marked(Hue.green.fill.resolve(in: environment).opacity(0.32)))
    case .removed: Text(line.marked(Hue.red.fill.resolve(in: environment).opacity(0.3)))
    case .context: Text(line.text)
    }
  }
}

/// A line's tint: added green, removed red (deeper under the pointer), the accent with a 3pt bar when selected.
private struct LineGround: View {
  let line: DiffLine
  let selected: Bool
  let hovered: Bool

  var body: some View {
    if selected {
      Rectangle().fill(Hue.accent.soft(0.18))
        .overlay(alignment: .leading) { Rectangle().fill(Hue.accent.fill).frame(width: 3) }
    } else {
      switch line.kind {
      case .added: Rectangle().fill(Hue.green.soft(hovered ? 0.2 : 0.13))
      case .removed: Rectangle().fill(Hue.red.soft(hovered ? 0.2 : 0.13))
      case .context: Color.clear
      }
    }
  }
}

/// The + in the gutter of a hovered changed line: stages that line (a − unstages it in a staged hunk).
private struct StageLineButton: View {
  var unstages = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: unstages ? "minus" : "plus")
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 16, height: 16)
        .background(Hue.accent.fill, in: Circle())
        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(unstages ? "Unstage this line" : "Stage this line")
    .transition(.opacity)
  }
}

/// Where one side of a split diff has no line: soft diagonal stripes.
private struct EmptySideStripes: View {
  var body: some View {
    Canvas { context, size in
      var path = Path()
      var x: CGFloat = -size.height
      while x < size.width {
        path.move(to: CGPoint(x: x, y: size.height))
        path.addLine(to: CGPoint(x: x + size.height, y: 0))
        x += 8
      }
      context.stroke(path, with: .style(.kitFillSoft), lineWidth: 4)
    }
    .clipped()
    .accessibilityHidden(true)
  }
}

// MARK: - Conflict card

/// Which side of a conflict to keep.
public enum ConflictChoice: Hashable, Sendable {
  case current, incoming, both

  var title: String {
    switch self {
    case .current: "Current"
    case .incoming: "Incoming"
    case .both: "Both"
    }
  }
}

/// Which side a conflict shows first (and puts first when keeping both).
public enum ConflictOrder: Hashable, Sendable {
  /// Current, then Incoming (a merge).
  case currentFirst
  /// Incoming, then Current (a rebase, where "current" is the branch being replayed onto).
  case incomingFirst
}

/// One side of a conflict: its name ("Current", "Incoming"), the branch it comes from and its lines.
public struct ConflictSide: Hashable, Sendable {
  public var label: String
  public var ref: String?
  public var lines: [AttributedString]

  public init(_ label: String, ref: String? = nil, lines: [AttributedString]) {
    self.label = label
    self.ref = ref
    self.lines = lines
  }

  /// A side from plain text, split into lines.
  public init(_ label: String, ref: String? = nil, code: String) {
    self.init(label, ref: ref, lines: code.split(separator: "\n", omittingEmptySubsequences: false).map {
      AttributedString(String($0))
    })
  }
}

/// A conflict as a card: a rich header (the live icon, "Conflict 1 of 2", lines and function) with a Current /
/// Incoming / Both choice, then the two sides; Current is the accent and Incoming purple, so neither reads as
/// removed. After a choice the card keeps only the result, tinted with the side it came from, and offers Undo
/// (which sets the choice back to `nil`).
///
/// ```swift
/// ConflictCard(title: "Conflict 1 of 1", meta: ["Lines 32–36", "save()"],
///              current: ConflictSide("Current", ref: "main", code: ours),
///              incoming: ConflictSide("Incoming", ref: "feature/offline-maps", code: theirs),
///              choice: $choice, edit: { openEditor() })
/// ```
///
/// `order: .incomingFirst` shows Incoming, then Current (a rebase); `ancestor` adds the common ancestor ("Base"),
/// shown on demand from the header, in gray.
///
/// ```swift
/// ConflictCard(title: "Conflict 1 of 3", current: ours, incoming: theirs, ancestor: base, order: .incomingFirst,
///              choice: $choice)
/// ```
public struct ConflictCard: View {
  var title: String
  var resolvedTitle: String
  var meta: [String]
  var current: ConflictSide
  var incoming: ConflictSide
  var ancestor: ConflictSide?
  var order: ConflictOrder
  @Binding var choice: ConflictChoice?
  var edit: (() -> Void)?
  @State private var showsAncestor = false
  @Environment(\.kitIdiom) private var idiom

  public init(
    title: String, resolvedTitle: String = "Conflict resolved", meta: [String] = [], current: ConflictSide,
    incoming: ConflictSide, ancestor: ConflictSide? = nil, order: ConflictOrder = .currentFirst,
    choice: Binding<ConflictChoice?>, edit: (() -> Void)? = nil
  ) {
    self.title = title
    self.resolvedTitle = resolvedTitle
    self.meta = meta
    self.current = current
    self.incoming = incoming
    self.ancestor = ancestor
    self.order = order
    self._choice = choice
    self.edit = edit
  }

  /// The two sides in the order shown, with their hues.
  private var sides: [(side: ConflictSide, hue: Hue, choice: ConflictChoice)] {
    let currentSide = (current, Hue.accent, ConflictChoice.current)
    let incomingSide = (incoming, Hue.purple, ConflictChoice.incoming)
    return order == .currentFirst ? [currentSide, incomingSide] : [incomingSide, currentSide]
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Group {
        if let choice {
          VStack(spacing: 2) {
            ForEach(sides, id: \.choice) { item in
              if choice == item.choice || choice == .both { resultBlock(item.side, hue: item.hue) }
            }
          }
          .padding([.horizontal, .bottom], 8)
        } else {
          VStack(spacing: 8) {
            if let ancestor, showsAncestor {
              sidePanel(ancestor, hue: .gray).transition(.opacity)
            }
            // Side by side where both have room, else one over the other (an iPhone).
            ViewThatFits(in: .horizontal) {
              HStack(alignment: .top, spacing: 8) {
                ForEach(sides, id: \.choice) { item in sidePanel(item.side, hue: item.hue) }
              }
              .frame(minWidth: 440)
              VStack(spacing: 8) {
                ForEach(sides, id: \.choice) { item in sidePanel(item.side, hue: item.hue) }
              }
            }
          }
          .padding([.horizontal, .bottom], 8)
        }
      }
      .transition(.opacity)
    }
    .kitSurface(.card)
    .animation(.kit, value: choice)
    .animation(.kit, value: showsAncestor)
  }

  /// The title with the picker beside it, or the picker under it where the card is narrow.
  private var header: some View {
    ViewThatFits(in: .horizontal) {
      titleRow { actions }
      VStack(alignment: .trailing, spacing: 4) {
        titleRow { EmptyView() }
        actions.padding(.horizontal, 6).padding(.bottom, 4)
      }
    }
  }

  private func titleRow<Accessory: View>(@ViewBuilder accessory: () -> Accessory) -> some View {
    RichHeader(
      Text(choice == nil ? title : resolvedTitle),
      icon: {
        LiveIcon(
          systemImage: "exclamationmark.triangle", hue: .orange, status: choice == nil ? .idle : .done, size: 24)
      },
      meta: { MetaLine(choice.map { resolvedMeta($0) } ?? meta) },
      accessory: accessory)
    .padding(EdgeInsets(horizontal: 6, vertical: 2))
  }

  private var actions: some View {
    let options: [(String, ConflictChoice?)] = (sides.map(\.choice) + [.both]).map { ($0.title, $0) }
    return HStack(spacing: 6) {
      if choice == nil {
        if ancestor != nil {
          Button("Base") { showsAncestor.toggle() }
            .buttonStyle(.dataSoft)
            .fixedSize()
            .help(showsAncestor ? "Hide the common ancestor" : "Show the common ancestor both sides changed")
            .accessibilityValue(showsAncestor ? "Shown" : "Hidden")
        }
        KitSegmented(selection: $choice, options: options)
        if let edit { Button("Edit…", action: edit).buttonStyle(.dataSoft) }
      } else {
        Button("Undo", systemImage: "arrow.uturn.backward") { withKitAnimation { choice = nil } }
          .buttonStyle(.kit)
          .controlSize(.small)
      }
    }
  }

  private func resolvedMeta(_ choice: ConflictChoice) -> [String] {
    switch choice {
    case .current: ["Used Current", current.ref ?? ""]
    case .incoming: ["Used Incoming", incoming.ref ?? ""]
    case .both: ["Used Both", sides.compactMap(\.side.ref).joined(separator: ", then ")]
    }
  }

  private func sidePanel(_ side: ConflictSide, hue: Hue) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 7) {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(hue.fill).frame(width: 8, height: 8)
        Text(side.label).font(.system(size: 12, weight: .semibold))
        if let ref = side.ref {
          Text(ref).font(.system(size: 12)).foregroundStyle(.kitSecondary).lineLimit(1)
        }
      }
      .padding(.leading, 10)
      .frame(height: 30)
      codeLines(side)
        .padding(EdgeInsets(top: 2, leading: 10, bottom: 8, trailing: 10))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(hue.soft(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
  }

  private func resultBlock(_ side: ConflictSide, hue: Hue) -> some View {
    codeLines(side)
      .padding(EdgeInsets(top: 4, leading: 10, bottom: 6, trailing: 10))
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(hue.soft(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
  }

  private func codeLines(_ side: ConflictSide) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(side.lines.enumerated()), id: \.offset) { _, line in
        Text(line)
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(minHeight: 20)
      }
    }
    .font(.system(size: 12, design: .monospaced))
  }
}

// MARK: - Previews

#Preview("Hunk cards") {
  @Previewable @State var selection: Set<DiffLine.ID> = [DiffLine.id(old: nil, new: 27), DiffLine.id(old: nil, new: 28)]
  let lines: [DiffLine] = [
    DiffLine(.context, old: 23, new: 24, text: "    save()"),
    DiffLine(.context, old: 24, new: 25, text: "  }"),
    DiffLine(.added, new: 27, text: "  /// Trips that haven't ended, soonest first."),
    DiffLine(.added, new: 28, text: "  public var upcoming: [Trip] {"),
    DiffLine(.removed, old: 26, text: "  private func load() {"),
    DiffLine(.removed, old: 27, text: "    guard let data = try? Data(contentsOf: url) else { return }", highlights: [4..<9]),
    DiffLine(.added, new: 32, text: "  private func load() throws {", highlights: [21..<28]),
    DiffLine(.context, old: 28, new: 34, text: "    trips = (try? JSONDecoder().decode([Trip].self, from: data)) ?? []"),
  ]
  VStack(spacing: 10) {
    HunkCard(
      header: "public final class TripStore", range: "@@ -14,6 +14,7 @@", lines: [], isStaged: true,
      summary: "1 line added in add(_:)", unstage: {})
    HunkCard(
      header: "public final class TripStore", range: "@@ -23,8 +24,13 @@", lines: lines, selection: $selection,
      stage: { _ in })
    HunkCard(header: "public final class TripStore", range: "@@ -23,8 +24,13 @@", lines: lines, layout: .split, stage: { _ in })
  }
  .padding(14)
  .frame(width: 680)
  .background(.kitPanel)
  .componentKit()
}

#Preview("Conflict") {
  @Previewable @State var choice: ConflictChoice?
  ConflictCard(
    title: "Conflict 1 of 1", meta: ["Lines 32–36", "save()"],
    current: ConflictSide("Current", ref: "main", code: "do {\n  try JSONEncoder().encode(trips).write(to: url)\n} catch {\n  lastError = error\n}"),
    incoming: ConflictSide(
      "Incoming", ref: "feature/offline-maps",
      code: "let data = try? JSONEncoder().encode(trips)\ntry? data?.write(to: url, options: .atomic)\nOfflineMaps.shared.prefetch(trips)"),
    choice: $choice, edit: {}
  )
  .padding(14)
  .frame(width: 680)
  .background(.kitPanel)
  .componentKit()
}
