import SwiftUI

/// How a `KitSection` draws: a raised card with the rich header (the default: sidebars, inspectors, list groups), or
/// plain on its ground with a small header (compact sidebars like Code's navigator).
public enum KitSectionStyle: Hashable, Sendable {
  /// A raised card whose header names what it holds: an icon tile, the name, one line of counts or status.
  case card
  /// No card: a quiet 11pt header with the chevron in front, and compact rows (plain icons, 24pt on the Mac).
  case plain
}

extension EnvironmentValues {
  /// How the `KitSection`s below draw (`.kitSectionStyle(_:)`).
  @Entry public var kitSectionStyle: KitSectionStyle = .card
  /// The sections are rows of a `KitList`.
  @Entry var contInList = false
}

extension View {
  /// Sets how the sections below draw: `.card` (the default) or `.plain` for a compact sidebar.
  ///
  /// ```swift
  /// KitSidebar(selection: $file) { KitSection("Atlas", systemImage: "folder") { … } }
  ///   .kitSectionStyle(.plain)
  /// ```
  public func kitSectionStyle(_ style: KitSectionStyle) -> some View {
    environment(\.kitSectionStyle, style)
  }
}

/// A group of rows under the kit's rich header: the icon tile (a live icon while work runs), the name, one meta line
/// that sums the group up, and trailing actions. As a card it's the sidebar's section, the inspector's section and a
/// list's group; it collapses from its header, and a closed section still shows its meta.
///
/// ```swift
/// KitSection("Repositories", meta: ["5 repositories", "2 with changes"], systemImage: "folder", hue: .blue) {
///   SidebarRow(value: repo.id, repo.name, systemImage: "shippingbox")
/// } accessory: {
///   Button("Add Repository", systemImage: "plus") { … }
/// }
/// ```
///
/// Pass `isExpanded` to own the open state (to remember it); without it the section keeps its own.
public struct KitSection<Icon: View, Meta: View, Content: View, Accessory: View>: View {
  var title: Text
  var isExpanded: Binding<Bool>?
  @ViewBuilder var icon: Icon
  @ViewBuilder var meta: Meta
  @ViewBuilder var content: Content
  @ViewBuilder var accessory: Accessory
  var titleAccessory: AnyView?
  @State private var ownExpanded = true
  @State private var isHovered = false
  @Environment(\.kitSectionStyle) private var style
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.contInList) private var inList
  /// The sticky item this section is in, as its title last saw it (`.kitSticky`).
  @State private var sticky = ContStickyBox()

  /// A section with any icon, meta and accessory views.
  public init(
    _ title: Text, isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content,
    @ViewBuilder icon: () -> Icon, @ViewBuilder meta: () -> Meta, @ViewBuilder accessory: () -> Accessory
  ) {
    self.title = title
    self.isExpanded = isExpanded
    self.content = content()
    self.icon = icon()
    self.meta = meta()
    self.accessory = accessory()
  }

  private var expanded: Bool { isExpanded?.wrappedValue ?? ownExpanded }

  /// Sets a small view right after the section's title: a chip ("Production"), a dot, a count.
  ///
  /// ```swift
  /// KitSection("Shop", meta: "PostgreSQL 16", systemImage: "cylinder") { … }.titleAccessory { Chip.production }
  /// ```
  public func titleAccessory<V: View>(@ViewBuilder _ content: () -> V) -> Self {
    var section = self
    section.titleAccessory = AnyView(content())
    return section
  }

  private func toggle() {
    // A stuck title (`.kitSticky`) scrolls to its section instead.
    if let context = sticky.context, context.state?.part == .title, let scroll = context.scroll {
      withKitAnimation { scroll.action(context.id) }
      return
    }
    withKitAnimation {
      if let isExpanded { isExpanded.wrappedValue.toggle() } else { ownExpanded.toggle() }
    }
  }

  public var body: some View {
    switch style {
    case .card:
      if inList, #available(macOS 15.0, iOS 18.0, *) {
        listCard
      } else {
        card
      }
    case .plain: plain
    }
  }

  // MARK: Card in a list

  /// In a `KitList` the card is spread over the list's rows: the header and each row are rows of their own, each
  /// drawing its slice of the card, so a row's `.swipeActions` and `.contextMenu` belong to that row alone.
  @available(macOS 15.0, iOS 18.0, *)
  private var listCard: some View {
    Group(subviews: content) { rows in
      let count = expanded ? rows.count : 0
      let radius = ContMetrics.cardRadius(idiom)
      // The list puts 1pt above and below each row: the slices run over it, and the cards keep the sidebar's gap.
      let gap = (ContMetrics.sectionSpacing(idiom) - 2) / 2
      header
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
        .modifier(SectionHeaderAccessibility(title: title, expanded: expanded, toggle: toggle))
        .padding(.bottom, count > 0 ? 4 : 0)
        .modifier(CardSliceModifier(slice: KitCardSlice(0, of: count + 1), cornerRadius: radius, bleed: 1))
        .kitHover { isHovered = $0 }
        .padding(.top, gap)
        .padding(.bottom, count > 0 ? 0 : gap)
      if expanded {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
          row
            .environment(\.contInList, false)
            // Each slice spans the card: a row narrower than the list (a fixed-width view, a short label) would
            // draw a narrower slice, a notch in the card.
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(CardSliceModifier(slice: KitCardSlice(index + 1, of: count + 1), cornerRadius: radius, bleed: 1))
            .padding(.bottom, index == count - 1 ? gap : 0)
        }
      }
    }
  }

  // MARK: Card

  private var card: some View {
    let radius = ContMetrics.cardRadius(idiom)
    return VStack(alignment: .leading, spacing: 0) {
      header
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
        .padding([.horizontal, .top], KitMetrics.cardPadding)
        .padding(.bottom, expanded ? 0 : KitMetrics.cardPadding)
        .modifier(SectionHeaderAccessibility(title: title, expanded: expanded, toggle: toggle))
        // Sticky (`.kitSticky`): the title alone stays in view, on a card of its own.
        .modifier(
          ContStickyTitleModifier(
            box: sticky, extra: expanded ? KitMetrics.cardPadding : 0, cornerRadius: radius, plain: false))
      ContRevealLayout(progress: expanded ? 1 : 0) {
        if expanded {
          // Lazy: in a long sidebar the rows come a few at a time as the card nears the screen.
          KitLazyStack(alignment: .leading, spacing: 2) { content }
            .environment(\.contStickyContext, nil)
            .padding(.top, 2)
            .padding([.horizontal, .bottom], KitMetrics.cardPadding)
            .transition(.opacity)
        }
      }
      .clipped()
    }
    // Stuck whole (`.kitSticky`), the card floats: opaque, with the float shadow.
    .background { ContStickyCardGround(cornerRadius: radius) }
    .kitHover { isHovered = $0 }
  }

  private var header: RichHeader<Icon, Meta, some View> {
    var header = RichHeader(title, icon: { icon }, meta: { meta }, accessory: { cardAccessory })
    header.titleAccessory = titleAccessory
    return header
  }

  private var cardAccessory: some View {
    HStack(spacing: 2) {
      if isHovered || !expanded || idiom.isTouch {
        Image(systemName: "chevron.down")
          .font(.system(size: idiom.isTouch ? 12 : 10, weight: .semibold))
          .foregroundStyle(.kitTertiary)
          .rotationEffect(.degrees(expanded ? 0 : -90))
          .frame(width: idiom.isTouch ? 24 : 16)
          .transition(.opacity)
          .accessibilityHidden(true)
      }
      accessory
    }
    .animation(.kitFast, value: isHovered)
  }

  // MARK: Plain

  private var plain: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        Image(systemName: "chevron.down")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.kitTertiary)
          .rotationEffect(.degrees(expanded ? 0 : -90))
          .frame(width: 12)
          .accessibilityHidden(true)
        HStack(spacing: 6) {
          title
            .kitFont(idiom.isTouch ? .headline : .sectionHeader)
            .foregroundStyle(KitColor.sectionHeader)
            .lineLimit(1)
          if let titleAccessory {
            titleAccessory.kitFont(.caption).fixedSize()
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        accessory
          .buttonStyle(.kitIcon)
          .controlSize(.small)
          .opacity(isHovered || idiom.isTouch ? 1 : 0)
      }
      .padding(.leading, 4)
      .padding(.trailing, 2)
      .frame(minHeight: idiom.isTouch ? 34 : 22)
      .contentShape(Rectangle())
      .onTapGesture(perform: toggle)
      .kitHover { isHovered = $0 }
      .modifier(SectionHeaderAccessibility(title: title, expanded: expanded, toggle: toggle))
      .modifier(ContStickyTitleModifier(box: sticky, extra: 0, cornerRadius: 0, plain: true))
      ContRevealLayout(progress: expanded ? 1 : 0) {
        if expanded {
          KitLazyStack(alignment: .leading, spacing: 0) { content }
            .padding(.top, 1)
            .environment(\.contStickyContext, nil)
            .transition(.opacity)
        }
      }
      .clipped()
      if !expanded {
        // What a closed section holds, in one line.
        meta
          .kitFont(.caption)
          .lineLimit(1)
          .padding(.leading, 20)
          .padding(.bottom, 4)
          .transition(.opacity)
      }
    }
  }
}

/// The header reads as a heading that opens and closes its section.
private struct SectionHeaderAccessibility: ViewModifier {
  let title: Text
  let expanded: Bool
  let toggle: () -> Void

  func body(content: Content) -> some View {
    content
      .accessibilityElement(children: .contain)
      .accessibilityAddTraits(.isHeader)
      .accessibilityAction(named: expanded ? "Collapse" : "Expand", toggle)
  }
}

// MARK: - Convenience

extension KitSection where Icon == LiveIcon<Image>, Meta == MetaLine {
  /// A section with an SF Symbol tile (carrying `status`), a meta line of parts and trailing actions.
  public init(
    _ title: some StringProtocol, meta: [String] = [], systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.init(
      Text(title), isExpanded: isExpanded, content: content,
      icon: { LiveIcon(systemImage: systemImage, hue: hue, status: status, size: 24) }, meta: { MetaLine(meta) },
      accessory: accessory)
  }

  /// A section with a one-part meta line and trailing actions.
  public init(
    _ title: some StringProtocol, meta: String, systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.init(
      title, meta: [meta], systemImage: systemImage, hue: hue, status: status, isExpanded: isExpanded,
      content: content, accessory: accessory)
  }
}

extension KitSection where Icon == LiveIcon<Image>, Meta == MetaLine, Accessory == EmptyView {
  /// A section with an SF Symbol tile and a meta line of parts.
  ///
  /// ```swift
  /// KitSection("Remotes", meta: ["origin", "fetched 2 hr ago"], systemImage: "cloud") { … }
  /// ```
  public init(
    _ title: some StringProtocol, meta: [String] = [], systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content
  ) {
    self.init(
      title, meta: meta, systemImage: systemImage, hue: hue, status: status, isExpanded: isExpanded,
      content: content, accessory: { EmptyView() })
  }

  /// A section with an SF Symbol tile and a one-part meta line.
  public init(
    _ title: some StringProtocol, meta: String, systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content
  ) {
    self.init(
      title, meta: [meta], systemImage: systemImage, hue: hue, status: status, isExpanded: isExpanded,
      content: content, accessory: { EmptyView() })
  }
}

extension KitSection where Icon == SizedLiveIcon {
  /// A section with an SF Symbol tile sized for the idiom (carrying `status`), any meta view (a live status line,
  /// counts in colour, a progress line) and trailing actions.
  ///
  /// ```swift
  /// KitSection("Sessions", systemImage: "terminal", status: sync) {
  ///   ForEach(sessions) { SidebarRow(value: $0.id, $0.name, systemImage: "terminal") }
  /// } meta: {
  ///   Text("3 running") + Text("  ·  1 failed").foregroundStyle(Hue.red.text)
  /// } accessory: {
  ///   Button("New Session", systemImage: "plus") { … }
  /// }
  /// ```
  public init(
    _ title: some StringProtocol, systemImage: String, hue: Hue = .accent, status: WorkStatus = .idle,
    isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content, @ViewBuilder meta: () -> Meta,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.init(
      Text(title), isExpanded: isExpanded, content: content,
      icon: { SizedLiveIcon(systemImage: systemImage, hue: hue, status: status, size: .section) }, meta: meta,
      accessory: accessory)
  }
}

extension KitSection where Icon == SizedLiveIcon, Accessory == EmptyView {
  /// A section with an SF Symbol tile sized for the idiom and any meta view.
  ///
  /// ```swift
  /// KitSection("Agents", systemImage: "person.2", status: connection) { … } meta: { ConnectionLine(state) }
  /// ```
  public init(
    _ title: some StringProtocol, systemImage: String, hue: Hue = .accent, status: WorkStatus = .idle,
    isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content, @ViewBuilder meta: () -> Meta
  ) {
    self.init(
      title, systemImage: systemImage, hue: hue, status: status, isExpanded: isExpanded, content: content,
      meta: meta, accessory: { EmptyView() })
  }
}

extension KitSection where Icon == SizedLiveIcon, Meta == MetaLine {
  /// A section whose tile holds any glyph (a drawn `BranchGlyph`, an image) instead of an SF Symbol, with a meta line
  /// of parts and trailing actions.
  ///
  /// ```swift
  /// KitSection("Branches", meta: ["3 local", "1 merged"], hue: .orange, glyph: { BranchGlyph() }) {
  ///   ForEach(branches) { SidebarRow(value: $0.id, $0.name, glyph: { BranchGlyph() }) }
  /// } accessory: {
  ///   Button("New Branch", systemImage: "plus") { … }
  /// }
  /// ```
  public init<Glyph: View>(
    _ title: some StringProtocol, meta: [String] = [], hue: Hue = .accent, status: WorkStatus = .idle,
    isExpanded: Binding<Bool>? = nil, @ViewBuilder glyph: () -> Glyph, @ViewBuilder content: () -> Content,
    @ViewBuilder accessory: () -> Accessory
  ) {
    let icon = SizedLiveIcon(hue: hue, status: status, size: .section, glyph: glyph)
    self.init(
      Text(title), isExpanded: isExpanded, content: content, icon: { icon }, meta: { MetaLine(meta) },
      accessory: accessory)
  }
}

extension KitSection where Icon == SizedLiveIcon, Meta == MetaLine, Accessory == EmptyView {
  /// A section whose tile holds any glyph, with a meta line of parts.
  ///
  /// ```swift
  /// KitSection("Branches", meta: ["3 local"], glyph: { BranchGlyph() }) { … }
  /// ```
  public init<Glyph: View>(
    _ title: some StringProtocol, meta: [String] = [], hue: Hue = .accent, status: WorkStatus = .idle,
    isExpanded: Binding<Bool>? = nil, @ViewBuilder glyph: () -> Glyph, @ViewBuilder content: () -> Content
  ) {
    self.init(
      title, meta: meta, hue: hue, status: status, isExpanded: isExpanded, glyph: glyph, content: content,
      accessory: { EmptyView() })
  }
}

extension KitSection where Icon == SizedLiveIcon {
  /// A section whose tile holds any glyph, with any meta view and trailing actions.
  ///
  /// ```swift
  /// KitSection("Remotes", hue: .blue, glyph: { BranchGlyph() }) { … } meta: { FetchLine(state) } accessory: { … }
  /// ```
  public init<Glyph: View>(
    _ title: some StringProtocol, hue: Hue = .accent, status: WorkStatus = .idle, isExpanded: Binding<Bool>? = nil,
    @ViewBuilder glyph: () -> Glyph, @ViewBuilder content: () -> Content, @ViewBuilder meta: () -> Meta,
    @ViewBuilder accessory: () -> Accessory
  ) {
    let icon = SizedLiveIcon(hue: hue, status: status, size: .section, glyph: glyph)
    self.init(Text(title), isExpanded: isExpanded, content: content, icon: { icon }, meta: meta, accessory: accessory)
  }
}

extension KitSection where Icon == SizedLiveIcon, Accessory == EmptyView {
  /// A section whose tile holds any glyph, with any meta view.
  public init<Glyph: View>(
    _ title: some StringProtocol, hue: Hue = .accent, status: WorkStatus = .idle, isExpanded: Binding<Bool>? = nil,
    @ViewBuilder glyph: () -> Glyph, @ViewBuilder content: () -> Content, @ViewBuilder meta: () -> Meta
  ) {
    self.init(
      title, hue: hue, status: status, isExpanded: isExpanded, glyph: glyph, content: content, meta: meta,
      accessory: { EmptyView() })
  }
}

// MARK: - Reveal

/// A slot as tall as its content times `progress`, the content pinned to the top and revealed downward, so opening
/// or closing a section slides the views below instead of jumping (from Shell's `SidebarRowLine`). The cache keeps
/// the content's last height for the frames of a collapse after it left the tree.
struct ContRevealLayout: Layout {
  var progress: Double

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func makeCache(subviews: Subviews) -> CGFloat { 0 }
  func updateCache(_ cache: inout CGFloat, subviews: Subviews) {}

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CGFloat) -> CGSize {
    var width: CGFloat = 0
    var height: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
      width = max(width, size.width)
      height = max(height, size.height)
    }
    if !subviews.isEmpty { cache = height }
    // Opening: the content is there and grows in; closing: it may already be gone, so the cached height shrinks.
    return CGSize(width: proposal.width ?? width, height: cache * progress)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CGFloat) {
    for subview in subviews {
      subview.place(
        at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
        proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
  }
}

#Preview("Sections") {
  @Previewable @State var open = true
  VStack(spacing: 10) {
    KitSection("Repositories", meta: ["5 repositories", "2 with changes"], systemImage: "folder", hue: .indigo) {
      Text("atlas").padding(.horizontal, 12).frame(height: 32)
      Text("beacon").padding(.horizontal, 12).frame(height: 32)
    } accessory: {
      Button("Add", systemImage: "plus") {}
    }
    KitSection("Branches", meta: "3 local · 1 merged", systemImage: "arrow.triangle.branch", hue: .orange, isExpanded: $open) {
      Text("main").padding(.horizontal, 12).frame(height: 32)
    }
    KitSection("Downloads", meta: ["2 downloading", "27.7 MB/s"], systemImage: "arrow.down", hue: .red, status: .working(progress: 0.4)) {
      Text("ubuntu.iso").padding(.horizontal, 12).frame(height: 32)
    }
    VStack(alignment: .leading, spacing: 8) {
      KitSection("Sources", meta: "4 files", systemImage: "folder") {
        Text("Trip.swift").frame(height: 24)
      }
    }
    .kitSectionStyle(.plain)
  }
  .padding(10)
  .frame(width: 260)
  .background(.kitSidebar)
  .componentKit()
}
