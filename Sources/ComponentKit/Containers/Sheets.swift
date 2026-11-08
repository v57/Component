import SwiftUI

// Sheets, dialogs and popovers (the Sheets and dialogs board, pick C): the panel ground with 20pt corners, so the cards
// inside read as raised; the header is the rich title, still; the fields' cards sit 8pt in from the edge; the footer is
// a raised card bar whose live icon and status line lead and whose filled buttons trail; with no status it is as wide
// as its buttons, at the trailing side, like a window's status bar.

/// A sheet's content: the still rich header (an icon tile, the title, one line of meta that wraps), the body's cards
/// 8pt in from the edges, and the footer as a card bar. Buttons in the footer are filled and borderless; give the
/// primary one `.buttonStyle(.kitPrimary)` and `.keyboardShortcut(.defaultAction)` (Return), Cancel
/// `.keyboardShortcut(.cancelAction)` (Escape). A sheet with a `KitMultilineField` takes Command-Return for its primary
/// button, as Return starts a new line there and `.defaultAction` would fire too. Lead the footer with a `SheetStatus` to show the sheet's own state
/// (the arc while input is checked, red when wrong, a check when ready); the bar then spans the sheet. Without one it
/// is as wide as its buttons, at the trailing side: no `Spacer()` before them, which would stretch it again. Put the
/// primary button last. On iPhone, when the row can't show every label whole, the status takes its own row (wrapping)
/// and the buttons go under it, the primary taking the rest of the row; narrower still, the other buttons share a row
/// over the primary, or every button spans the bar (`SheetFooterLayout`).
///
/// Present it with `.kitSheet(isPresented:)`: a card in the middle of the dimmed window, `width` wide on the Mac (80pt
/// wider on iPad, the screen's width less 16pt each side on iPhone), as tall as its content, its body scrolling
/// between the header and the footer when the window is too short for it.
///
/// ```swift
/// .kitSheet(isPresented: $cloning) {
///   KitSheet(title: "Clone Repository", meta: "Copies a repository from GitHub, GitLab or any URL.",
///            systemImage: "arrow.down.circle") {
///     FormCard { FormRow("Repository URL", systemImage: "link", field: TextField("https://", text: $url)) }
///   } footer: {
///     SheetStatus("Ready · 12 MB", systemImage: "arrow.down", status: .done)
///     Button("Cancel") { cloning = false }.keyboardShortcut(.cancelAction)
///     Button("Clone") { clone() }.buttonStyle(.kitPrimary).keyboardShortcut(.defaultAction)
///   }
/// }
/// ```
public struct KitSheet<Icon: View, Content: View, Footer: View>: View {
  var title: KitString
  var meta: KitString?
  var isMetaError: Bool
  var width: CGFloat?
  var topAligned: Bool
  var onClose: (() -> Void)?
  @ViewBuilder var icon: Icon
  @ViewBuilder var content: Content
  @ViewBuilder var footer: Footer
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitPresentation) private var presentation
  @Environment(\.kitOverlayRoom) private var room
  @State private var bodyHeight: CGFloat = 0
  /// The body runs on past the bottom of its scroll view, which then fades that edge (with no footer bar there).
  @State private var bodyRunsOn = false
  @State private var scrollSpace = UUID()
  @State private var viewport: CGFloat = 0
  /// The body put the footer over its own scroll view (`kitSheetFooterBar`), so the sheet draws no footer row.
  @State private var footerIsInBody = false
  /// The footer bar's height, while it sits over the sheet's scrolling body.
  @State private var footerHeight: CGFloat = 0
  /// The header's height, while it is a bar over the sheet's scrolling body.
  @State private var headerHeight: CGFloat = 0

  /// A sheet with any icon (a thing's own tile, an avatar). `width` applies on the Mac (and 80pt wider on iPad, over
  /// the window); `onClose` adds the round close button at the header's end (for panels without a Cancel button).
  /// The title and meta are keys (literals), looked up in the app's strings.
  public init(
    title: LocalizedStringKey, meta: LocalizedStringKey? = nil, width: CGFloat? = 460, onClose: (() -> Void)? = nil,
    @ViewBuilder icon: () -> Icon, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer
  ) {
    self.init(
      title: KitString(title), meta: KitString(meta), width: width, onClose: onClose, icon: icon, content: content,
      footer: footer)
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(
    title: some StringProtocol, meta: String? = nil, width: CGFloat? = 460, onClose: (() -> Void)? = nil,
    @ViewBuilder icon: () -> Icon, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer
  ) {
    self.init(
      title: KitString(verbatim: String(title)), meta: KitString(verbatim: meta), width: width, onClose: onClose,
      icon: icon, content: content, footer: footer)
  }

  init(
    title: KitString, meta: KitString?, width: CGFloat?, onClose: (() -> Void)? = nil,
    @ViewBuilder icon: () -> Icon, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer
  ) {
    self.title = title
    self.meta = meta
    self.isMetaError = false
    self.width = width
    self.topAligned = false
    self.onClose = onClose
    self.icon = icon()
    self.content = content()
    self.footer = footer()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if !headerOverBody { header }
      if Content.self != EmptyView.self {
        if presentation == .overlay {
          // Over the window the card is as tall as its content, and its body scrolls when the window is shorter,
          // running on under the header and the footer bar, which fade it out behind themselves (as a window's title
          // bar and status bar).
          let space = scrollSpace
          let viewport = viewport
          ScrollView {
            // A body that scrolls on its own (its footer over it) fits the card instead of running on in this one,
            // which would hide its footer below the card's edge (a short window, large text).
            SheetFitHeight(limit: footerIsInBody && room > 0 ? max(0, room - headerHeight) : nil) { sheetBody }
              .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bodyHeight = $0 }
              .onGeometryChange(for: Bool.self) { $0.frame(in: .named(space)).maxY > viewport + 0.5 } action: {
                bodyRunsOn = $0
              }
          }
          .coordinateSpace(.named(space))
          .scrollBounceBehavior(.basedOnSize)
          .scrollIndicators(.automatic)
          .modifier(FooterOverBody(footer: footerOverBody ? footerBar : nil, height: $footerHeight))
          .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { self.viewport = $0 }
          .contEdgeBar(.top) { headerBar }
          .frame(maxHeight: bodyHeight + headerHeight + (footerOverBody ? footerHeight : 0))
          .contScrollEdge(!footerOverBody && bodyRunsOn, length: idiom.size(24, touch: 32))
        } else if idiom == .phone {
          ScrollView {
            sheetBody
              .padding(.bottom, Footer.self == EmptyView.self ? 0 : 4)
          }
          .scrollBounceBehavior(.basedOnSize)
          .modifier(FooterOverBody(footer: footerOverBody ? footerBar : nil, height: $footerHeight))
          .contEdgeBar(.top) { headerBar }
          .frame(maxHeight: .infinity, alignment: .top)
        } else {
          sheetBody
        }
      }
      if footerIsInBody || footerOverBody {
        // The body's scroll view runs on to the sheet's bottom edge, under its footer bar.
      } else if Footer.self != EmptyView.self {
        footerBar
      } else {
        Spacer(minLength: KitMetrics.gutter).frame(height: KitMetrics.gutter)
      }
    }
    .frame(width: sheetWidth)
    .background {
      // Over the window the overlay's card is the ground.
      if presentation != .overlay { Rectangle().fill(.kitPanel).ignoresSafeArea() }
    }
  }

  /// Whether the header is a bar over the sheet's own scrolling body (over the window, and on iPhone) rather than a
  /// row over it.
  private var headerOverBody: Bool {
    Content.self != EmptyView.self && (presentation == .overlay || idiom == .phone)
  }

  /// The header as a bar the body scrolls under and fades out behind.
  private var headerBar: some View {
    header
      .background { ContEdgeFade(edge: .top, ground: .panel) }
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
  }

  /// Whether the footer is a bar over the sheet's own scrolling body (over the window, and on iPhone) rather than a
  /// row under it.
  private var footerOverBody: Bool {
    Footer.self != EmptyView.self && Content.self != EmptyView.self && !footerIsInBody
      && (presentation == .overlay || idiom == .phone)
  }

  private var sheetWidth: CGFloat? {
    guard let width else { return nil }
    switch idiom {
    case .mac, .tv: return width
    case .pad: return presentation == .overlay ? width + 80 : nil
    case .phone: return nil
    }
  }

  private var sheetBody: some View {
    VStack(alignment: .leading, spacing: KitMetrics.gutter) { content }
      .padding(.horizontal, KitMetrics.gutter)
      .environment(\.kitSheetFooter, Footer.self == EmptyView.self ? nil : KitSheetFooter(view: AnyView(footerBar)))
      .onPreferenceChange(KitSheetFooterInBody.self) { footerIsInBody = $0 }
  }

  private var header: some View {
    HStack(alignment: topAligned ? .top : .center, spacing: 12) {
      icon
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .kitFont(idiom.isTouch ? .title2 : .title3)
          .lineLimit(topAligned ? 2 : 1)
        if let meta {
          Text(meta)
            .kitFont(.callout)
            .foregroundStyle(isMetaError ? AnyShapeStyle(Hue.red.text) : AnyShapeStyle(.kitSecondary))
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      if let onClose {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: idiom.size(10, touch: 12), weight: .bold))
            .frame(width: idiom.size(24, touch: 30), height: idiom.size(24, touch: 30))
            .background { Circle().fill(.kitFill) }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.kitSecondary)
        .accessibilityLabel("Close")
      }
    }
    .padding(EdgeInsets(top: 16, leading: 16, bottom: 12, trailing: 16))
  }

  private var footerBar: some View {
    footerRow
      .buttonStyle(ContSheetButtonStyle())
      .controlSize(.small)
      .environment(\.kitInSheetFooter, true)
      .padding(4)
      .frame(minHeight: idiom.size(36, pad: 44, phone: 52))
      .background {
        SurfaceShape(surface: .card, cornerRadius: idiom == .pad ? KitMetrics.radiusXL : idiom == .phone ? 18 : KitMetrics.radiusCard)
      }
      // The card fits what it holds and trails; a SheetStatus fills the row and takes the card with it
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(KitMetrics.gutter)
  }

  /// One row on the Mac, iPad and Apple TV; on iPhone a row while everything fits whole, else the status above the
  /// buttons, then the buttons in rows (`SheetFooterLayout`), never a cut label.
  @ViewBuilder private var footerRow: some View {
    if idiom == .phone {
      SheetFooterLayout { footer }
        .environment(\.kitSheetFooterFills, true)
    } else {
      HStack(spacing: 6) { footer }
    }
  }
}

extension KitSheet where Icon == LiveIcon<Image> {
  /// A sheet with an SF Symbol tile; `status` puts the header's tile to work. The title and meta are keys
  /// (literals), looked up in the app's strings.
  public init(
    title: LocalizedStringKey, meta: LocalizedStringKey? = nil, systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, width: CGFloat? = 460, onClose: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer
  ) {
    self.init(
      title: KitString(title), meta: KitString(meta), systemImage: systemImage, hue: hue, status: status,
      width: width, onClose: onClose, content: content, footer: footer)
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(
    title: some StringProtocol, meta: String? = nil, systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, width: CGFloat? = 460, onClose: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer
  ) {
    self.init(
      title: KitString(verbatim: String(title)), meta: KitString(verbatim: meta), systemImage: systemImage, hue: hue,
      status: status, width: width, onClose: onClose, content: content, footer: footer)
  }

  init(
    title: KitString, meta: KitString?, systemImage: String, hue: Hue, status: WorkStatus = .idle,
    width: CGFloat? = 460, onClose: (() -> Void)? = nil, @ViewBuilder content: () -> Content,
    @ViewBuilder footer: () -> Footer
  ) {
    self.init(
      title: title, meta: meta, width: width, onClose: onClose,
      icon: { LiveIcon(systemImage: systemImage, hue: hue, status: status, size: 32) }, content: content,
      footer: footer)
  }
}

extension KitSheet where Icon == LiveIcon<Image>, Footer == EmptyView {
  /// A sheet (or panel) with no footer bar. The title and meta are keys (literals), looked up in the app's strings.
  public init(
    title: LocalizedStringKey, meta: LocalizedStringKey? = nil, systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, width: CGFloat? = 460, onClose: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      title: KitString(title), meta: KitString(meta), systemImage: systemImage, hue: hue, status: status,
      width: width, onClose: onClose, content: content, footer: { EmptyView() })
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(
    title: some StringProtocol, meta: String? = nil, systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, width: CGFloat? = 460, onClose: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      title: KitString(verbatim: String(title)), meta: KitString(verbatim: meta), systemImage: systemImage, hue: hue,
      status: status, width: width, onClose: onClose, content: content, footer: { EmptyView() })
  }
}

/// The footer bar's lead: a small live icon and one line of status ("Ready · 12 MB", "Checking…", "Not a Git URL").
///
/// ```swift
/// SheetStatus("Checking the URL…", systemImage: "link", status: .working)
/// ```
public struct SheetStatus: View {
  var text: KitString
  var systemImage: String
  var hue: Hue
  var status: WorkStatus
  @Environment(\.kitIdiom) private var idiom

  /// A status line that is a key (a literal), looked up in the app's strings.
  public init(
    _ text: LocalizedStringKey, systemImage: String = "checkmark", hue: Hue = .accent, status: WorkStatus = .idle
  ) {
    self.init(text: KitString(text), systemImage: systemImage, hue: hue, status: status)
  }

  /// The same with a string shown as it is.
  @_disfavoredOverload
  public init(
    _ text: some StringProtocol, systemImage: String = "checkmark", hue: Hue = .accent, status: WorkStatus = .idle
  ) {
    self.init(text: KitString(verbatim: String(text)), systemImage: systemImage, hue: hue, status: status)
  }

  init(text: KitString, systemImage: String, hue: Hue, status: WorkStatus) {
    self.text = text
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
  }

  private var isFailed: Bool { if case .failed = status { true } else { false } }

  public var body: some View {
    HStack(spacing: 8) {
      LiveIcon(systemImage: systemImage, hue: hue, status: status, size: idiom.size(22, touch: 26))
      Text(text)
        .kitFont(.callout)
        .foregroundStyle(isFailed ? AnyShapeStyle(Hue.red.text) : AnyShapeStyle(.kitSecondary))
        // On iPhone the footer gives a status that doesn't fit beside the buttons its own row, where it wraps
        .lineLimit(idiom == .phone ? 3 : 1)
        .truncationMode(.tail)
    }
    .padding(.leading, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .layoutValue(key: SheetFooterPartKey.self, value: .status)
  }
}

/// Its one view at its ideal height, but no taller than `limit`: a scroll view's content that should end at its edge.
struct SheetFitHeight: Layout {
  var limit: CGFloat?

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard let child = subviews.first else { return .zero }
    return child.sizeThatFits(childProposal(proposal, child))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
  }

  private func childProposal(_ proposal: ProposedViewSize, _ child: LayoutSubview) -> ProposedViewSize {
    guard let limit else { return proposal }
    let height = proposal.height ?? child.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)).height
    return ProposedViewSize(width: proposal.width, height: min(height, limit))
  }
}

/// What a view in a sheet's footer is, for the footer's layout on iPhone: the status leads, a `Spacer` only pushes,
/// anything else is an action, the last one the primary.
enum SheetFooterPart: Sendable {
  case action, status
}

struct SheetFooterPartKey: LayoutValueKey {
  static let defaultValue = SheetFooterPart.action
}

/// A footer row a sheet draws itself, in its body (the form's last line, on its own card): one row on the Mac, iPad
/// and Apple TV; on iPhone it rearranges as the footer bar does rather than cut a label (`SheetFooterLayout`): a
/// `SheetStatus`, or a note before the `Spacer`, gets its own row, the buttons go under it with the primary (the last)
/// taking the rest of the row, and so on.
///
/// ```swift
/// KitSheetFooterRow {
///   SheetStatus("Encrypted, synced to your 3 devices", systemImage: "checkmark.shield", hue: .green)
///   Spacer()
///   Button("Cancel") { dismiss() }.buttonStyle(.kit)
///   Button("Add Document", action: save).buttonStyle(.kitPrimary)
/// }
/// .padding(6)
/// .kitSurface(.card)
/// ```
public struct KitSheetFooterRow<Content: View>: View {
  var spacing: CGFloat
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom

  public init(spacing: CGFloat = 6, @ViewBuilder content: () -> Content) {
    self.spacing = spacing
    self.content = content()
  }

  public var body: some View {
    if idiom == .phone {
      SheetFooterLayout(spacing: spacing) { content }
        .environment(\.kitSheetFooterFills, true)
    } else {
      HStack(spacing: spacing) { content }
    }
  }
}

/// The footer's content on iPhone, in the first of these that fits whole (no label cut):
/// 1. one row, as on the Mac: the status leads and fills, the buttons trail;
/// 2. the status on its own row (wrapping), the buttons in a row under it, the primary (the last) taking the rest;
/// 3. the secondary buttons sharing a row, the primary under them across the bar;
/// 4. every button across the bar, one under another, the primary last.
/// A `Spacer` in the footer takes no room here: the status, or the primary, already fills the row. What comes before
/// the `Spacer` (a note, a status of the app's own) leads as a `SheetStatus` does: at its own width in the one row,
/// then on a row of its own across the bar, where it wraps.
struct SheetFooterLayout: Layout {
  var spacing: CGFloat = 6
  /// Above and below a status on its own row, so its line doesn't touch the bar's edge or the buttons.
  var statusInset: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    plan(width: proposal.width, subviews: subviews).size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let plan = plan(width: bounds.width, subviews: subviews)
    for (index, subview) in subviews.enumerated() {
      let frame = plan.frames[index]
      subview.place(
        at: CGPoint(x: bounds.minX + frame.midX, y: bounds.minY + frame.midY), anchor: .center,
        proposal: ProposedViewSize(width: frame.width, height: frame.height))
    }
  }

  struct Plan {
    var size: CGSize
    var frames: [CGRect]
  }

  /// `lead`: a view before the `Spacer` that isn't a `SheetStatus` (a note); it leads as the status does.
  enum Kind { case status, lead, spacer, action }

  /// The kinds with what comes before a `Spacer` as leads, when there are actions after it.
  static func resolved(_ kinds: [Kind]) -> [Kind] {
    guard let spacer = kinds.firstIndex(of: .spacer), kinds[spacer...].contains(.action) else { return kinds }
    return kinds.enumerated().map { index, kind in index < spacer && kind == .action ? .lead : kind }
  }

  private func kind(of subview: LayoutSubview) -> Kind {
    if subview[SheetFooterPartKey.self] == .status { return .status }
    // A Spacer is no bigger than its minimum length (8 by default, outside a stack) and takes any width it's offered;
    // nothing else in a footer does both (a filling button is as tall as a button).
    let least = subview.sizeThatFits(.zero)
    if max(least.width, least.height) <= 8.5, subview.sizeThatFits(.infinity).width > 10_000 { return .spacer }
    return .action
  }

  private func plan(width proposed: CGFloat?, subviews: Subviews) -> Plan {
    plan(
      width: proposed, kinds: subviews.map(kind(of:)), ideal: subviews.map { $0.sizeThatFits(.unspecified) },
      height: { subviews[$0].sizeThatFits(ProposedViewSize(width: $1, height: nil)).height })
  }

  /// Where each view goes, from what each is, its ideal size and its height at a width.
  func plan(width proposed: CGFloat?, kinds: [Kind], ideal: [CGSize], height: (Int, CGFloat) -> CGFloat) -> Plan {
    let kinds = Self.resolved(kinds)
    var frames = Array(repeating: CGRect.zero, count: kinds.count)
    // The status and the notes before the Spacer lead; only a status takes the room left in the one row.
    let statuses = kinds.indices.filter { kinds[$0] == .status || kinds[$0] == .lead }
    let actions = kinds.indices.filter { kinds[$0] == .action }
    let hasSpacer = kinds.contains(.spacer)

    func rowWidth(_ indices: [Int]) -> CGFloat {
      indices.isEmpty ? 0 : indices.reduce(0) { $0 + ideal[$1].width } + spacing * CGFloat(indices.count - 1)
    }
    let actionsWidth = rowWidth(actions)
    let statusesWidth = rowWidth(statuses)
    let oneRow = statusesWidth + actionsWidth + (statuses.isEmpty || actions.isEmpty ? 0 : spacing)
    let width = proposed.map { $0.isFinite ? $0 : oneRow } ?? oneRow

    /// Lays `indices` out left to right from `x` on a row at `y` with the given widths; returns the row's height.
    func placeRow(_ indices: [Int], widths: [CGFloat], x: CGFloat, y: CGFloat) -> CGFloat {
      let heights = zip(indices, widths).map { height($0, $1) }
      let rowHeight = heights.max() ?? 0
      var x = x
      for (offset, index) in indices.enumerated() {
        frames[index] = CGRect(
          x: x, y: y + (rowHeight - heights[offset]) / 2, width: widths[offset], height: heights[offset])
        x += widths[offset] + spacing
      }
      return rowHeight
    }

    // 1. One row, as on the Mac.
    if oneRow <= width + 0.5 {
      let fills = !statuses.isEmpty || hasSpacer
      let rowWidth = fills ? max(width, oneRow) : oneRow
      var widths = statuses.map { ideal[$0].width }
      // The status fills; notes keep their width and the buttons trail, the Spacer's room between them.
      if let first = statuses.firstIndex(where: { kinds[$0] == .status }) { widths[first] += rowWidth - oneRow }
      let order = statuses + actions
      let rowHeight = placeRow(
        order, widths: widths + actions.map { ideal[$0].width },
        x: statuses.isEmpty ? rowWidth - actionsWidth : 0, y: 0)
      let gap = rowWidth - oneRow
      if gap > 0.5, !statuses.contains(where: { kinds[$0] == .status }), !statuses.isEmpty {
        for index in actions { frames[index].origin.x += gap }
      }
      return Plan(size: CGSize(width: rowWidth, height: rowHeight), frames: frames)
    }

    // The status rows across the bar, then the buttons in the first arrangement that fits.
    var y: CGFloat = 0
    for index in statuses {
      let statusHeight = height(index, width)
      frames[index] = CGRect(x: 0, y: y + statusInset, width: width, height: statusHeight)
      y += statusHeight + statusInset * 2
    }
    guard let primary = actions.last else {
      return Plan(size: CGSize(width: width, height: max(0, y - statusInset)), frames: frames)
    }
    let secondaries = Array(actions.dropLast())

    if actionsWidth <= width + 0.5 {
      // 2. The buttons in one row, the primary taking the rest.
      let rest = width - rowWidth(secondaries) - (secondaries.isEmpty ? 0 : spacing)
      let widths = secondaries.map { ideal[$0].width } + [rest]
      y += placeRow(actions, widths: widths, x: 0, y: y)
    } else if !secondaries.isEmpty, rowWidth(secondaries) <= width + 0.5 {
      // 3. The secondaries sharing a row, the primary across the bar under them.
      let extra = (width - rowWidth(secondaries)) / CGFloat(secondaries.count)
      y += placeRow(secondaries, widths: secondaries.map { ideal[$0].width + extra }, x: 0, y: y) + spacing
      y += placeRow([primary], widths: [width], x: 0, y: y)
    } else {
      // 4. One under another.
      for (offset, index) in actions.enumerated() {
        y += placeRow([index], widths: [width], x: 0, y: y) + (offset == actions.count - 1 ? 0 : spacing)
      }
    }
    return Plan(size: CGSize(width: width, height: y), frames: frames)
  }
}

/// The overlays' buttons: filled and borderless (raised in dark), 28pt (36 on iPad, 44 on iPhone), red text for a
/// destructive role.
struct ContSheetButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    ContSheetButton(configuration: configuration)
  }
}

/// The footer bar's button size, shared with a `.kitPrimary` (or any kit button) placed in it, so Cancel and the
/// confirming button are one height, corner and type size.
enum SheetFooterButton {
  static func height(_ idiom: KitIdiom) -> CGFloat { idiom.size(28, pad: 36, phone: 44) }
  static func radius(_ idiom: KitIdiom) -> CGFloat {
    idiom == .phone ? 14 : idiom == .pad ? KitMetrics.radiusLarge : KitMetrics.radius
  }
  static func font(_ idiom: KitIdiom) -> KitFont { idiom.isTouch ? .body : .callout }
  static func padding(_ idiom: KitIdiom) -> CGFloat { idiom.size(12, touch: 16) }
  /// A footer button's ground, and a disabled primary's
  static func fill(_ scheme: ColorScheme) -> KitColor { scheme == .dark ? KitColor.raised : KitColor.fill }
}

extension EnvironmentValues {
  /// True inside a sheet's footer bar: kit buttons there take the footer's size.
  @Entry var kitInSheetFooter: Bool = false
  /// True in a sheet's footer on iPhone: its buttons take the width the footer gives them (the primary the rest of
  /// its row, a stacked button the bar's width) rather than hugging their label.
  @Entry var kitSheetFooterFills: Bool = false
  /// The sheet's footer bar, for a body that scrolls on its own to put over its scroll view (`kitSheetFooterBar`).
  @Entry var kitSheetFooter: KitSheetFooter? = nil
}

struct KitSheetFooter {
  var view: AnyView
}

/// Set by `kitSheetFooterBar`: the footer is in the body.
private struct KitSheetFooterInBody: PreferenceKey {
  static let defaultValue = false
  static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

extension View {
  /// Puts the sheet's footer over this scroll view as a bar its content scrolls under and fades out behind, as a
  /// window's status bar does, for a `KitSheet` body that scrolls on its own (one that keeps its height while its
  /// sections change). The sheet then draws no footer row, and the scroll view runs on to the sheet's bottom edge.
  /// Nothing outside a sheet with a footer.
  ///
  /// ```swift
  /// KitSheet(title: "New Connection", systemImage: "cylinder") {
  ///   ScrollView { fields }.frame(idealHeight: 620).kitSheetFooterBar()
  /// } footer: {
  ///   Button("Cancel") { … }
  ///   Button("Connect") { … }.buttonStyle(.kitPrimary)
  /// }
  /// ```
  public func kitSheetFooterBar() -> some View {
    modifier(SheetFooterBar())
  }
}

/// The sheet's footer as a bar over its scrolling body, with the fade behind it; `height` follows the bar's.
private struct FooterOverBody<Bar: View>: ViewModifier {
  let footer: Bar?
  @Binding var height: CGFloat

  func body(content: Content) -> some View {
    if let footer {
      content.contEdgeBar(.bottom) {
        footer
          // Opaque over the panel, as a bar's cards are: the body scrolls on under it
          .environment(\.contBarGround, KitColor.panel)
          .background { ContEdgeFade(edge: .bottom, ground: .panel) }
          .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
      }
    } else {
      content
    }
  }
}

private struct SheetFooterBar: ViewModifier {
  @Environment(\.kitSheetFooter) private var footer

  func body(content: Content) -> some View {
    if let footer {
      content
        .contEdgeBar(.bottom) {
          footer.view
            .environment(\.contBarGround, KitColor.panel)
            .background { ContEdgeFade(edge: .bottom, ground: .panel) }
        }
        .preference(key: KitSheetFooterInBody.self, value: true)
    } else {
      content
    }
  }
}

private struct ContSheetButton: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.colorScheme) private var scheme
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitSheetFooterFills) private var fills

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: SheetFooterButton.radius(idiom), style: .continuous)
    configuration.label
      .kitFont(SheetFooterButton.font(idiom))
      .fontWeight(.medium)
      .lineLimit(1)
      .foregroundStyle(configuration.role == .destructive ? AnyShapeStyle(Hue.red.text) : AnyShapeStyle(.kitLabel))
      .padding(.horizontal, SheetFooterButton.padding(idiom))
      .frame(maxWidth: fills ? .infinity : nil, minHeight: SheetFooterButton.height(idiom))
      .background { shape.fill(SheetFooterButton.fill(scheme)) }
      .overlay {
        shape.fill(configuration.isPressed ? AnyShapeStyle(.kitPress) : AnyShapeStyle(Color.clear))
      }
      .opacity(isEnabled ? 1 : 0.45)
      .contentShape(shape)
  }
}

// MARK: - Confirmation

extension View {
  /// Asks before an action, as a kit sheet (over the window, at the bottom on iPhone; it stacks over a sheet it is
  /// asked from): the still header (a red tile for a destructive action) with the message
  /// wrapping under the title, and a footer bar with Cancel and the confirming button (filled red when destructive).
  /// Return confirms and Escape cancels.
  ///
  /// ```swift
  /// .kitConfirmation("Delete harbor?", isPresented: $confirming, message: "Its worktree and stashes go too.",
  ///                  systemImage: "trash", confirm: "Delete") { delete(harbor) }
  /// ```
  ///
  /// The title, message and button are keys (literals), looked up in the app's strings.
  public func kitConfirmation(
    _ title: LocalizedStringKey, isPresented: Binding<Bool>, message: LocalizedStringKey? = nil,
    systemImage: String = "exclamationmark.triangle", confirm: LocalizedStringKey, role: ButtonRole? = .destructive,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    kitConfirmation(
      title: KitString(title), isPresented: isPresented, message: KitString(message), systemImage: systemImage,
      confirm: KitString(confirm), role: role, action: action)
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public func kitConfirmation(
    _ title: some StringProtocol, isPresented: Binding<Bool>, message: String? = nil,
    systemImage: String = "exclamationmark.triangle", confirm: some StringProtocol, role: ButtonRole? = .destructive,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    kitConfirmation(
      title: KitString(verbatim: String(title)), isPresented: isPresented, message: KitString(verbatim: message),
      systemImage: systemImage, confirm: KitString(verbatim: String(confirm)), role: role, action: action)
  }

  func kitConfirmation(
    title: KitString, isPresented: Binding<Bool>, message: KitString?, systemImage: String, confirm: KitString,
    role: ButtonRole?, action: @escaping @MainActor () -> Void
  ) -> some View {
    kitSheet(isPresented: isPresented) {
      ContConfirmation(
        title: title, message: message, systemImage: systemImage, confirm: confirm, role: role, action: action,
        dismiss: { isPresented.wrappedValue = false })
    }
  }
}

/// One button of a `kitConfirmation` with several choices.
///
/// ```swift
/// KitConfirmationButton("Force Delete", role: .destructive) { git.deleteBranch(name, force: true) }
/// ```
public struct KitConfirmationButton: Identifiable {
  public let id = UUID()
  var label: KitString
  public var role: ButtonRole?
  /// The one Return presses, drawn filled; by default the last button.
  public var isDefault: Bool
  var action: @MainActor () -> Void

  /// The title as a string: a key's localized text, or the string as it was given.
  public var title: String {
    get { label.string }
    set { label = KitString(verbatim: newValue) }
  }

  /// A button titled by a key (a literal), looked up in the app's strings.
  public init(
    _ title: LocalizedStringKey, role: ButtonRole? = nil, isDefault: Bool = false,
    action: @escaping @MainActor () -> Void
  ) {
    self.init(label: KitString(title), role: role, isDefault: isDefault, action: action)
  }

  /// The same with a string shown as it is.
  @_disfavoredOverload
  public init(
    _ title: some StringProtocol, role: ButtonRole? = nil, isDefault: Bool = false,
    action: @escaping @MainActor () -> Void
  ) {
    self.init(label: KitString(verbatim: String(title)), role: role, isDefault: isDefault, action: action)
  }

  init(label: KitString, role: ButtonRole?, isDefault: Bool, action: @escaping @MainActor () -> Void) {
    self.label = label
    self.role = role
    self.isDefault = isDefault
    self.action = action
  }
}

extension View {
  /// Asks before an action with several ways to go (Delete / Force Delete / Delete Local and Remote): the same sheet
  /// as the one-button confirmation, with Cancel and each button; the default one (marked, or the last) is filled
  /// and takes Return, the others are plain (red when destructive). Any button closes the sheet.
  ///
  /// ```swift
  /// .kitConfirmation("Delete feature/login?", isPresented: $confirming, message: "It isn't merged into main.",
  ///                  systemImage: "trash", buttons: [
  ///   KitConfirmationButton("Delete Local and Remote", role: .destructive) { deleteBoth() },
  ///   KitConfirmationButton("Force Delete", role: .destructive, isDefault: true) { forceDelete() },
  /// ])
  /// ```
  ///
  /// The title and message are keys (literals), looked up in the app's strings.
  public func kitConfirmation(
    _ title: LocalizedStringKey, isPresented: Binding<Bool>, message: LocalizedStringKey? = nil,
    systemImage: String = "exclamationmark.triangle", hue: Hue? = nil, buttons: [KitConfirmationButton]
  ) -> some View {
    kitConfirmation(
      title: KitString(title), isPresented: isPresented, message: KitString(message), systemImage: systemImage,
      hue: hue, buttons: buttons)
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public func kitConfirmation(
    _ title: some StringProtocol, isPresented: Binding<Bool>, message: String? = nil,
    systemImage: String = "exclamationmark.triangle", hue: Hue? = nil, buttons: [KitConfirmationButton]
  ) -> some View {
    kitConfirmation(
      title: KitString(verbatim: String(title)), isPresented: isPresented, message: KitString(verbatim: message),
      systemImage: systemImage, hue: hue, buttons: buttons)
  }

  func kitConfirmation(
    title: KitString, isPresented: Binding<Bool>, message: KitString?, systemImage: String, hue: Hue?,
    buttons: [KitConfirmationButton]
  ) -> some View {
    kitSheet(isPresented: isPresented) {
      ContMultiConfirmation(
        title: title, message: message, systemImage: systemImage, hue: hue, buttons: buttons,
        dismiss: { isPresented.wrappedValue = false })
    }
  }
}

struct ContMultiConfirmation: View {
  let title: KitString
  let message: KitString?
  let systemImage: String
  let hue: Hue?
  let buttons: [KitConfirmationButton]
  let dismiss: @MainActor () -> Void
  @Environment(\.kitDismiss) private var kitDismiss

  /// The binding false, and the card off the stack even when its presenter is gone (`kitDismiss`).
  private func close() {
    dismiss()
    kitDismiss()
  }

  var body: some View {
    let defaultID = (buttons.first { $0.isDefault } ?? buttons.last)?.id
    let tint = hue ?? (buttons.contains { $0.role == .destructive } ? .red : .accent)
    var sheet = KitSheet(
      title: title, meta: message, width: buttons.count > 2 ? 520 : 420,
      icon: { LiveIcon(systemImage: systemImage, hue: tint, status: .idle, size: 32) },
      content: { EmptyView() },
      footer: {
        Button("Cancel", role: .cancel) { close() }
          .keyboardShortcut(.cancelAction)
        ForEach(buttons) { button in
          if button.id == defaultID {
            Button(button.label, role: button.role) {
              button.action()
              close()
            }
            .buttonStyle(.kitPrimary)
            .keyboardShortcut(.defaultAction)
          } else {
            Button(button.label, role: button.role) {
              button.action()
              close()
            }
          }
        }
      })
    sheet.topAligned = true
    return sheet
  }
}

struct ContConfirmation: View {
  let title: KitString
  let message: KitString?
  let systemImage: String
  let confirm: KitString
  let role: ButtonRole?
  let action: @MainActor () -> Void
  let dismiss: @MainActor () -> Void
  @Environment(\.kitDismiss) private var kitDismiss

  /// The binding false, and the card off the stack even when its presenter is gone (`kitDismiss`).
  private func close() {
    dismiss()
    kitDismiss()
  }

  var body: some View {
    var sheet = KitSheet(
      title: title, meta: message, width: 380,
      icon: { LiveIcon(systemImage: systemImage, hue: role == .destructive ? .red : .accent, status: .idle, size: 32) },
      content: { EmptyView() },
      footer: {
        Button("Cancel", role: .cancel) { close() }
          .keyboardShortcut(.cancelAction)
        Button(confirm, role: role) {
          // Before closing: closing clears the binding, often the very value the action reads.
          action()
          close()
        }
        .buttonStyle(.kitPrimary)
        .keyboardShortcut(.defaultAction)
      })
    sheet.topAligned = true
    return sheet
  }
}

#Preview("Sheet") {
  @Previewable @State var url = "https://github.com/v57/Component.git"
  VStack(spacing: 24) {
    KitSheet(title: "Clone Repository", meta: "Copies a repository from GitHub, GitLab or any URL.", systemImage: "arrow.down.circle") {
      FormCard {
        FormRow("Repository URL", help: "GitHub, GitLab or any Git URL", systemImage: "link", status: .done, field: TextField("https://", text: $url))
        FormRow("Location", help: "~/Developer/Component", systemImage: "folder", hue: .teal) {
          Button("Choose…") {}.buttonStyle(.kit)
        }
      }
    } footer: {
      SheetStatus("Ready · 12 MB", systemImage: "arrow.down", status: .done)
      Button("Cancel") {}
      Button("Clone") {}.buttonStyle(.kitPrimary)
    }
    ContConfirmation(
      title: KitString("Delete harbor?"),
      message: KitString("Its worktree and 2 stashes are deleted too. This can't be undone."),
      systemImage: "trash", confirm: KitString("Delete"), role: .destructive, action: {}, dismiss: {})
    ContMultiConfirmation(
      title: KitString("Delete feature/login?"), message: KitString("It isn't merged into main."),
      systemImage: "trash", hue: nil,
      buttons: [
        KitConfirmationButton("Delete Local and Remote", role: .destructive) {},
        KitConfirmationButton("Force Delete", role: .destructive) {},
      ], dismiss: {})
  }
  .padding()
  .componentKit()
}
