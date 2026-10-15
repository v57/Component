import SwiftUI

// MARK: - Lines

/// One line of a diff: context, added or removed, its old and new line numbers, the text (plain or already coloured by
/// a highlighter) and the changed words as character ranges, which the hunk draws in a stronger tint.
///
/// ```swift
/// DiffLine(.added, new: 32, text: "private func load() throws {", highlights: [19..<26])
/// ```
public struct DiffLine: Identifiable, Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    case context, added, removed
  }

  public var kind: Kind
  public var oldNumber: Int?
  public var newNumber: Int?
  public var text: AttributedString
  /// Changed words, as character offsets into `text`.
  public var highlights: [Range<Int>]

  /// Unique within a hunk: a line's old and new numbers.
  public var id: String { "\(oldNumber ?? -1):\(newNumber ?? -1)" }
  public var isChange: Bool { kind != .context }

  public init(_ kind: Kind, old: Int? = nil, new: Int? = nil, text: AttributedString, highlights: [Range<Int>] = []) {
    self.kind = kind
    self.oldNumber = old
    self.newNumber = new
    self.text = text
    self.highlights = highlights
  }

  public init(_ kind: Kind, old: Int? = nil, new: Int? = nil, text: String, highlights: [Range<Int>] = []) {
    self.init(kind, old: old, new: new, text: AttributedString(text), highlights: highlights)
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

// MARK: - Hunk card

/// A hunk as a card, headed by the function it's in and its range. Gutters have no fill: the whole line carries the
/// added or removed tint, changed words a stronger one. Hovering a changed line shows a + that stages it; clicking
/// selects it (the accent bar) and the header offers Stage N Lines. A staged hunk folds to its header and a summary
/// line, with Unstage. Put the cards for a file in a `VStack(spacing: 10)` on the panel ground.
///
/// ```swift
/// HunkCard(header: "public final class TripStore", range: "@@ -23,8 +24,13 @@", lines: hunk.lines,
///          selection: $selectedLines, stage: { lines in repo.stage(lines) })
/// HunkCard(header: "TripStore", range: "@@ -14,6 +14,7 @@", lines: staged.lines, isStaged: true,
///          summary: "1 line added in add(_:)", unstage: { repo.unstage(staged) })
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
  @State private var expanded: Bool?
  @State private var hovered: DiffLine.ID?
  @Environment(\.kitIdiom) private var idiom

  public init(
    header: String, range: String, lines: [DiffLine], layout: DiffLayout = .unified, isStaged: Bool = false,
    summary: String? = nil, selection: Binding<Set<DiffLine.ID>>? = nil, stage: (([DiffLine]) -> Void)? = nil,
    unstage: (() -> Void)? = nil
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
  }

  private var isExpanded: Bool { expanded ?? !isStaged }
  private var selected: Set<DiffLine.ID> { selection?.wrappedValue ?? [] }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      headerRow
      if isExpanded {
        Group {
          switch layout {
          case .unified:
            VStack(spacing: 0) { ForEach(lines) { unifiedLine($0) } }
          case .split:
            splitLines
          }
        }
        .transition(.opacity)
      } else if let summary {
        Text(summary)
          .kitFont(.caption)
          .padding(.leading, 30)
          .padding(.trailing, 12)
          .padding(.top, -6)
          .padding(.bottom, 4)
      }
    }
    .padding(.bottom, 6)
    .kitSurface(.card)
    .clipShape(RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous))
    .onChange(of: isStaged) { expanded = nil }
    .animation(.kit, value: isExpanded)
  }

  private var headerRow: some View {
    HStack(spacing: 8) {
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
        .layoutPriority(-1)
      Text(range)
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.kitSecondary)
        .lineLimit(1)
        .fixedSize()
      Spacer(minLength: 8)
      if isStaged {
        Label("Staged", systemImage: "checkmark")
          .labelStyle(KitButtonLabelStyle(iconOnly: false))
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Hue.green.text)
        if let unstage { Button("Unstage", action: unstage).buttonStyle(.dataSoft) }
      } else if let stage {
        let chosen = lines.filter { selected.contains($0.id) && $0.isChange }
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
    .padding(.leading, 10)
    .padding(.trailing, 6)
    .frame(height: idiom.isTouch ? 46 : 38)
  }

  // MARK: Unified

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
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .font(.system(size: 12, design: .monospaced))
    .frame(minHeight: 20)
    .background { LineGround(line: line, selected: isSelected, hovered: isHovered) }
    .overlay(alignment: .leading) {
      if line.isChange, isHovered, !isStaged, let stage {
        StageLineButton { stage([line]) }.padding(.leading, 5)
      }
    }
    .contentShape(Rectangle())
    .onHover { inside in
      if inside { hovered = line.id } else if hovered == line.id { hovered = nil }
    }
    .onTapGesture { toggle(line) }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func toggle(_ line: DiffLine) {
    guard line.isChange, let selection, !isStaged else { return }
    withKitAnimation(.kitFast) {
      if selection.wrappedValue.contains(line.id) {
        selection.wrappedValue.remove(line.id)
      } else {
        selection.wrappedValue.insert(line.id)
      }
    }
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

  private func code(_ line: DiffLine) -> some View {
    WordMarkedText(line: line)
      .lineLimit(1)
      .truncationMode(.tail)
  }

  // MARK: Split

  private var splitLines: some View {
    VStack(spacing: 0) {
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
      .onHover { inside in
        if inside { hovered = line.id } else if hovered == line.id { hovered = nil }
      }
      .onTapGesture { toggle(line) }
    } else {
      EmptySideStripes().frame(maxWidth: .infinity, minHeight: 20)
    }
  }
}

/// A line's text with its changed words on a stronger tint of the line's hue.
private struct WordMarkedText: View {
  let line: DiffLine
  @Environment(\.self) private var environment

  var body: some View {
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

/// The + in the gutter of a hovered changed line: stages that line.
private struct StageLineButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "plus")
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 16, height: 16)
        .background(Hue.accent.fill, in: Circle())
        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Stage this line")
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
public struct ConflictCard: View {
  var title: String
  var resolvedTitle: String
  var meta: [String]
  var current: ConflictSide
  var incoming: ConflictSide
  @Binding var choice: ConflictChoice?
  var edit: (() -> Void)?
  @Environment(\.kitIdiom) private var idiom

  public init(
    title: String, resolvedTitle: String = "Conflict resolved", meta: [String] = [], current: ConflictSide,
    incoming: ConflictSide, choice: Binding<ConflictChoice?>, edit: (() -> Void)? = nil
  ) {
    self.title = title
    self.resolvedTitle = resolvedTitle
    self.meta = meta
    self.current = current
    self.incoming = incoming
    self._choice = choice
    self.edit = edit
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Group {
        if let choice {
          VStack(spacing: 2) {
            if choice != .incoming { resultBlock(current, hue: .accent) }
            if choice != .current { resultBlock(incoming, hue: .purple) }
          }
          .padding([.horizontal, .bottom], 8)
        } else {
          HStack(alignment: .top, spacing: 8) {
            sidePanel(current, hue: .accent)
            sidePanel(incoming, hue: .purple)
          }
          .padding([.horizontal, .bottom], 8)
        }
      }
      .transition(.opacity)
    }
    .kitSurface(.card)
    .animation(.kit, value: choice)
  }

  private var header: some View {
    let options: [(String, ConflictChoice?)] = [ConflictChoice.current, .incoming, .both].map { ($0.title, $0) }
    return RichHeader(
      Text(choice == nil ? title : resolvedTitle),
      icon: {
        LiveIcon(
          systemImage: "exclamationmark.triangle", hue: .orange, status: choice == nil ? .idle : .done, size: 24)
      },
      meta: { MetaLine(choice.map { resolvedMeta($0) } ?? meta) },
      accessory: {
        HStack(spacing: 6) {
          if choice == nil {
            KitSegmented(selection: $choice, options: options)
            if let edit { Button("Edit…", action: edit).buttonStyle(.dataSoft) }
          } else {
            Button("Undo", systemImage: "arrow.uturn.backward") { withKitAnimation { choice = nil } }
              .buttonStyle(.kit)
              .controlSize(.small)
          }
        }
      })
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
  }

  private func resolvedMeta(_ choice: ConflictChoice) -> [String] {
    switch choice {
    case .current: ["Used Current", current.ref ?? ""]
    case .incoming: ["Used Incoming", incoming.ref ?? ""]
    case .both: ["Used Both", [current.ref, incoming.ref].compactMap { $0 }.joined(separator: ", then ")]
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
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(hue.soft(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
  }

  private func resultBlock(_ side: ConflictSide, hue: Hue) -> some View {
    codeLines(side)
      .padding(.horizontal, 10)
      .padding(.top, 4)
      .padding(.bottom, 6)
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
  @Previewable @State var selection: Set<DiffLine.ID> = ["-1:27", "-1:28"]
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
