import SwiftUI

/// A Git ref as a chip that leads with a small glyph tile (branch, cloud, tag): the current branch (HEAD's) in the
/// accent's tint, other local branches orange, tags and remote branches gray. A remote's "origin/" is quieter, a
/// branch whose upstream sits on the same commit ends in a small cloud, and a long name is cut in the middle so its
/// namespace and its distinguishing end both stay (release/2026.10-h…payments). For a commit's refs in a row, use
/// `RefChips`.
///
/// ```swift
/// RefChip(name: "main", isCurrent: true)
/// RefChip(name: "origin/feature/offline-maps", kind: .remote)
/// RefChip(name: "v1.4.0", kind: .tag).controlSize(.small)
/// ```
public struct RefChip: View {
  public enum Kind: Hashable, Sendable {
    /// A local branch.
    case branch
    /// A remote-tracking branch ("origin/main").
    case remote
    case tag
    /// A detached HEAD.
    case head
  }

  /// A ref's data: what `RefChip` and `RefChips` draw.
  public struct Ref: Hashable, Identifiable, Sendable {
    public var name: String
    public var kind: Kind
    /// HEAD's branch (or a detached HEAD): the accent chip, first in a row.
    public var isCurrent: Bool
    /// The branch's upstream is on the same commit: one chip with a small cloud at its end.
    public var hasUpstream: Bool
    /// One line of what it is, for the refs card: "HEAD · 2 to push", "Tag · Oct 13", "fetched 2 hr ago".
    public var detail: String?

    public var id: String { "\(kind)/\(name)" }

    public init(name: String, kind: Kind = .branch, isCurrent: Bool = false, hasUpstream: Bool = false, detail: String? = nil) {
      self.name = name
      self.kind = kind
      self.isCurrent = isCurrent
      self.hasUpstream = hasUpstream
      self.detail = detail
    }

    /// A commit's refs in the kit's order, with each local branch and its upstream folded into one chip: HEAD's
    /// branch first, then local branches, tags (in the order given: newest first), then remote branches.
    public static func arranged(_ refs: [Ref]) -> [Ref] {
      var refs = refs
      let locals = Set(refs.filter { $0.kind == .branch }.map(\.name))
      var folded = Set<String>()
      refs.removeAll { ref in
        guard ref.kind == .remote, let slash = ref.name.firstIndex(of: "/") else { return false }
        let branch = String(ref.name[ref.name.index(after: slash)...])
        guard locals.contains(branch) else { return false }
        folded.insert(branch)
        return true
      }
      for index in refs.indices where refs[index].kind == .branch && folded.contains(refs[index].name) {
        refs[index].hasUpstream = true
      }
      return refs.enumerated().sorted { a, b in
        let (ra, rb) = (a.element.rank, b.element.rank)
        return ra != rb ? ra < rb : a.offset < b.offset
      }.map(\.element)
    }

    var rank: Int {
      if isCurrent { return 0 }
      switch kind {
      case .head: return 0
      case .branch: return 1
      case .tag: return 2
      case .remote: return 3
      }
    }

    var hue: Hue {
      if isCurrent { return .accent }
      return kind == .branch ? .orange : .gray
    }

    /// A remote's namespace ("origin/") and the rest of its name.
    var parts: (namespace: String, name: String) {
      guard kind == .remote, let slash = name.firstIndex(of: "/") else { return ("", name) }
      return (String(name[...slash]), String(name[name.index(after: slash)...]))
    }

    var accessibilityText: String {
      let kindName =
        switch kind {
        case .branch: isCurrent ? "current branch" : "branch"
        case .remote: "remote branch"
        case .tag: "tag"
        case .head: "HEAD"
        }
      return "\(name), \(kindName)\(hasUpstream ? ", same as upstream" : "")"
    }
  }

  var ref: Ref
  /// The widest the chip grows before its name is cut in the middle; `nil` shows it all.
  var maxWidth: CGFloat?
  @Environment(\.controlSize) private var controlSize
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitMoreContrast) private var moreContrast

  public init(
    name: String, kind: Kind = .branch, isCurrent: Bool = false, hasUpstream: Bool = false, detail: String? = nil,
    maxWidth: CGFloat? = 168
  ) {
    self.init(Ref(name: name, kind: kind, isCurrent: isCurrent, hasUpstream: hasUpstream, detail: detail), maxWidth: maxWidth)
  }

  public init(_ ref: Ref, maxWidth: CGFloat? = 168) {
    self.ref = ref
    self.maxWidth = maxWidth
  }

  public var body: some View {
    let m = ChipMetrics(controlSize: controlSize, idiom: idiom)
    let hue = ref.hue
    let ink = ref.isCurrent ? AnyShapeStyle(Hue.accent.text) : hue == .orange ? AnyShapeStyle(BadgeInk(hue: .orange)) : AnyShapeStyle(.kitLabel)
    let glyphSide = controlSize == .small || controlSize == .mini ? 15 : m.height
    HStack(spacing: 0) {
      glyph(size: m.glyph)
        .frame(width: glyphSide, height: glyphSide)
        .background(BadgeTint(hue: hue, light: 0.22, dark: 0.22), in: m.shape)
      nameText(ink)
        .lineLimit(1)
        .truncationMode(.middle)
        .padding(.leading, m.gap + 1)
        .padding(.trailing, ref.hasUpstream ? 0 : m.padding)
      if ref.hasUpstream {
        Image(systemName: "cloud")
          .font(.system(size: m.glyph, weight: .semibold))
          .imageScale(.small)
          .opacity(0.62)
          .padding(.leading, 4)
          .padding(.trailing, m.padding)
      }
    }
    .font(.system(size: m.fontSize, weight: .semibold))
    .foregroundStyle(ink)
    .frame(height: m.height)
    .modifier(CappedWidth(maxWidth: maxWidth))
    .background(BadgeTint(hue: hue, light: 0.16, dark: 0.22), in: m.shape)
    .overlay {
      if moreContrast { m.shape.strokeBorder(hue.fill.opacity(0.6), lineWidth: 1) }
    }
    .fixedSize(horizontal: false, vertical: true)
    .opacity(isEnabled ? 1 : 0.45)
    .help(ref.detail.map { "\(ref.name) · \($0)" } ?? ref.name)
    .accessibilityElement()
    .accessibilityLabel([ref.accessibilityText, ref.detail].compactMap { $0 }.joined(separator: ", "))
  }

  private func nameText(_ ink: AnyShapeStyle) -> Text {
    let parts = ref.parts
    if parts.namespace.isEmpty { return Text(parts.name) }
    return Text(parts.namespace).foregroundStyle(ink.opacity(0.62)) + Text(parts.name)
  }

  @ViewBuilder
  private func glyph(size: CGFloat) -> some View {
    switch ref.kind {
    case .branch: BranchGlyph(size: size + 2)
    case .remote: Image(systemName: "cloud").font(.system(size: size, weight: .semibold)).imageScale(.small)
    case .tag: Image(systemName: "tag").font(.system(size: size, weight: .semibold)).imageScale(.small)
    case .head: Image(systemName: "smallcircle.filled.circle").font(.system(size: size, weight: .semibold)).imageScale(.small)
    }
  }
}

/// A commit's refs in a row: up to `maxVisible` chips (two in a wide list, one when narrow: pass 1 when the row is
/// under 720pt or the inspector is open), each capped at 168pt (128 narrow) and cut in the middle; the rest fold into
/// a `+N` chip. When even that doesn't fit, fewer chips show. Hovering the chips for half a second, or clicking `+N`
/// (Space when focused, a tap on touch), opens a card that lists every ref at full length with one line on each.
/// Refs are put in the kit's order and a branch's upstream is folded into its chip (`RefChip.Ref.arranged`).
///
/// ```swift
/// RefChips(commit.refs, maxVisible: isNarrow ? 1 : 2, meta: ["0dd2b54", "Changelog: Started 1.12"])
/// ```
public struct RefChips: View {
  var refs: [RefChip.Ref]
  var maxVisible: Int
  var meta: [String]
  var onSelect: ((RefChip.Ref) -> Void)?
  @State private var isOpen = false
  @State private var openedByHover = false
  @State private var hoverChips = false
  @State private var hoverCard = false
  @State private var hoverTask: Task<Void, Never>?

  /// - Parameters:
  ///   - refs: the commit's refs; they're arranged in the kit's order.
  ///   - maxVisible: chips shown before `+N` (2 wide, 1 narrow).
  ///   - meta: the card header's meta line (the short hash, the message).
  ///   - onSelect: clicking a ref in the card (show it in the sidebar).
  public init(
    _ refs: [RefChip.Ref], maxVisible: Int = 2, meta: [String] = [], onSelect: ((RefChip.Ref) -> Void)? = nil
  ) {
    self.refs = RefChip.Ref.arranged(refs)
    self.maxVisible = max(maxVisible, 0)
    self.meta = meta
    self.onSelect = onSelect
  }

  public var body: some View {
    if !refs.isEmpty {
      ViewThatFits(in: .horizontal) {
        ForEach(Self.layouts(count: refs.count, maxVisible: maxVisible), id: \.self) { shown in
          row(shown: shown)
        }
      }
      .kitHover { hovering in
        hoverChips = hovering
        hoverChanged()
      }
      .popover(isPresented: $isOpen, arrowEdge: .bottom) {
        RefsCard(refs: refs, meta: meta, onSelect: select)
          .kitHover { hovering in
            hoverCard = hovering
            hoverChanged()
          }
          .presentationCompactAdaptation(.popover)
      }
      .onDisappear { hoverTask?.cancel() }
    }
  }

  /// The chip counts to try, most first: `maxVisible` (or all, when fewer) down to just `+N`.
  nonisolated static func layouts(count: Int, maxVisible: Int) -> [Int] {
    let most = min(count, maxVisible)
    return Array(stride(from: most, through: 0, by: -1))
  }

  /// The cap on a chip's width: 168pt in a wide list, 128 in a narrow one.
  nonisolated static func chipCap(maxVisible: Int) -> CGFloat { maxVisible <= 1 ? 128 : 168 }

  private func row(shown: Int) -> some View {
    HStack(spacing: 4) {
      ForEach(refs.prefix(shown)) { ref in
        RefChip(ref, maxWidth: Self.chipCap(maxVisible: maxVisible))
      }
      if shown < refs.count {
        let hidden = refs.dropFirst(shown)
        Button {
          openedByHover = false
          withKitAnimation(.kitFast) { isOpen.toggle() }
        } label: {
          Text("+\(hidden.count)")
        }
        .buttonStyle(MoreRefsStyle(isOpen: isOpen))
        .accessibilityLabel("\(hidden.count) more refs: \(hidden.map(\.name).joined(separator: ", "))")
      }
    }
    .fixedSize(horizontal: shown == 0, vertical: false)
  }

  private func hoverChanged() {
    hoverTask?.cancel()
    if hoverChips || hoverCard {
      guard !isOpen else { return }
      hoverTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled, hoverChips else { return }
        openedByHover = true
        isOpen = true
      }
    } else if isOpen, openedByHover {
      hoverTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled, !hoverChips, !hoverCard else { return }
        isOpen = false
      }
    }
  }

  private func select(_ ref: RefChip.Ref) {
    isOpen = false
    onSelect?(ref)
  }
}

/// The `+N` chip: the ref chip's shape and gray tint with a bare number; hover deepens it, raised while its card is
/// open, the field's ring when focused.
struct MoreRefsStyle: ButtonStyle {
  var isOpen: Bool

  func makeBody(configuration: Configuration) -> some View {
    MoreRefsLabel(configuration: configuration, isOpen: isOpen)
  }

  struct MoreRefsLabel: View {
    let configuration: Configuration
    let isOpen: Bool
    @State private var isHovered = false
    @Environment(\.kitIdiom) private var idiom
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      let touch = idiom.isTouch
      let shape = RoundedRectangle(cornerRadius: touch ? 6 : KitMetrics.radiusXS, style: .continuous)
      configuration.label
        .font(.system(size: touch ? 13 : 11, weight: .semibold).monospacedDigit())
        .foregroundStyle(.kitLabel)
        .padding(.horizontal, touch ? 6 : 5)
        .frame(minWidth: touch ? 26 : 22, minHeight: touch ? 22 : 18)
        .background {
          if isOpen {
            SurfaceShape(surface: .raised, cornerRadius: touch ? 6 : KitMetrics.radiusXS)
          } else {
            let extra = isHovered || configuration.isPressed ? 0.14 : 0
            shape.fill(BadgeTint(hue: .gray, light: 0.16 + extra, dark: 0.22 + extra))
          }
        }
        .overlay {
          if isFocused { shape.stroke(Hue.accent.fill.opacity(0.5), lineWidth: 2).padding(-1) }
        }
        .contentShape(shape)
        .fixedSize()
        .kitHover { isHovered = $0 }
        .animation(.kitFast, value: isHovered)
        .animation(.kitFast, value: isOpen)
    }
  }
}

/// Every ref of a commit at full length: a rich header ("4 refs", the hash and message) and a row per ref with one
/// line of what it is.
struct RefsCard: View {
  let refs: [RefChip.Ref]
  let meta: [String]
  let onSelect: (RefChip.Ref) -> Void
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      RichHeader(
        refs.count == 1 ? "1 ref" : "\(refs.count) refs", meta: meta, systemImage: "smallcircle.filled.circle",
        hue: .gray)
      ForEach(refs) { ref in
        RefsCardRow(ref: ref) { onSelect(ref) }
      }
    }
    .padding(idiom.isTouch ? 8 : KitMetrics.cardPadding)
    .frame(minWidth: 240, maxWidth: idiom.isTouch ? 460 : 360, alignment: .leading)
    .fixedSize(horizontal: false, vertical: true)
    .presentationBackground(.kitElevated)
  }
}

struct RefsCardRow: View {
  let ref: RefChip.Ref
  let action: () -> Void
  @State private var isHovered = false
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    let touch = idiom.isTouch
    Button(action: action) {
      HStack(spacing: 12) {
        RefChip(ref, maxWidth: nil)
        Spacer(minLength: 0)
        if let detail = ref.detail {
          Text(detail)
            .font(.system(size: badgeFigureSize(idiom) == 11 ? 11 : 13))
            .foregroundStyle(.kitSecondary)
            .lineLimit(1)
            .fixedSize()
        }
      }
      .padding(.leading, touch ? 8 : 5)
      .padding(.trailing, touch ? 10 : 6)
      .frame(height: touch ? 40 : 28)
      .background(
        isHovered ? AnyShapeStyle(.kitHover) : AnyShapeStyle(Color.clear),
        in: RoundedRectangle(cornerRadius: touch ? 10 : KitMetrics.radiusSmall, style: .continuous)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .kitHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
    .accessibilityLabel([ref.accessibilityText, ref.detail].compactMap { $0 }.joined(separator: ", "))
  }
}

/// Caps a view's width without stretching it: the child gets at most `maxWidth` and keeps its own size below it.
struct CappedWidth: ViewModifier {
  var maxWidth: CGFloat?

  func body(content: Content) -> some View {
    if let maxWidth { CappedWidthLayout(maxWidth: maxWidth) { content } } else { content }
  }
}

struct CappedWidthLayout: Layout {
  var maxWidth: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard let child = subviews.first else { return .zero }
    let width = min(proposal.width ?? .infinity, maxWidth)
    return child.sizeThatFits(ProposedViewSize(width: width, height: proposal.height))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    subviews.first?.place(
      at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
  }
}

/// The git branch glyph from Git's design: two commits on a line and a branch curving off, stroked in the
/// foreground style (SF Symbols' branch reads as a fork). A row's or a title's icon where the branch is the subject.
///
/// ```swift
/// Label { Text(branch.name) } icon: { BranchGlyph(size: 14) }
/// BranchGlyph().foregroundStyle(Hue.green.fill)
/// RowTile { BranchGlyph() }  // sized by the tile
/// ```
///
/// Without a `size` it takes the size of the tile it sits on (`kitGlyphSize`), or 16pt.
public struct BranchGlyph: View {
  var size: CGFloat?
  @Environment(\.kitGlyphSize) private var glyphSize

  public init(size: CGFloat? = nil) { self.size = size }

  public var body: some View {
    let size = size ?? glyphSize ?? 16
    // A shape rather than a `Canvas`: a canvas is a drawing layer (and a surface) of its own per glyph, slow to make
    // as a sidebar of branch rows scrolls in.
    BranchGlyphShape()
      .stroke(.foreground, style: StrokeStyle(lineWidth: 1.6 * size / 16, lineCap: .round, lineJoin: .round))
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}

/// The branch glyph's lines on a 16-unit grid scaled to the rect's width.
private struct BranchGlyphShape: Shape {
  func path(in rect: CGRect) -> Path {
    let s = rect.width / 16
    var path = Path()
    path.addEllipse(in: CGRect(x: 3.5 * s, y: 2 * s, width: 3 * s, height: 3 * s))
    path.addEllipse(in: CGRect(x: 3.5 * s, y: 11 * s, width: 3 * s, height: 3 * s))
    path.addEllipse(in: CGRect(x: 9.5 * s, y: 3.5 * s, width: 3 * s, height: 3 * s))
    path.move(to: CGPoint(x: 5 * s, y: 5 * s))
    path.addLine(to: CGPoint(x: 5 * s, y: 11 * s))
    path.move(to: CGPoint(x: 11 * s, y: 6.5 * s))
    path.addCurve(
      to: CGPoint(x: 5 * s, y: 11 * s), control1: CGPoint(x: 11 * s, y: 9.5 * s),
      control2: CGPoint(x: 5 * s, y: 9 * s))
    return path.offsetBy(dx: rect.minX, dy: rect.minY)
  }
}

#Preview("Refs") {
  let many: [RefChip.Ref] = [
    .init(name: "release/2026.10-hotfix-payments", detail: "Branch · not pushed"),
    .init(name: "main", isCurrent: true, detail: "HEAD · 2 to push"),
    .init(name: "v1.12.0-beta.3", kind: .tag, detail: "Tag · Oct 13"),
    .init(name: "testflight/1.12.0-beta.3-1842", kind: .tag, detail: "Tag · Oct 13"),
  ]
  VStack(alignment: .leading, spacing: 10) {
    HStack(spacing: 6) {
      RefChip(name: "main", isCurrent: true)
      RefChip(name: "feature/sidebar")
      RefChip(name: "origin/main", kind: .remote)
      RefChip(name: "v1.4.0", kind: .tag)
      RefChip(name: "fix/date-parsing", hasUpstream: true)
    }
    RefChip(name: "origin/feature/offline-maps-sync", kind: .remote)
    RefChips(many, meta: ["0dd2b54", "Changelog: Started 1.12"])
    RefChips(many, maxVisible: 1)
    RefChips([.init(name: "main"), .init(name: "origin/main", kind: .remote)])
    HStack(spacing: 6) {
      RefChip(name: "main", isCurrent: true)
      RefChip(name: "v1.4.0", kind: .tag)
    }
    .controlSize(.small)
  }
  .padding()
  .frame(width: 520, alignment: .leading)
  .componentKit()
}
