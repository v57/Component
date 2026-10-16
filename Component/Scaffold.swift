import ComponentKit
import SwiftUI

/// The page for `page`.
struct PageContent: View {
  let page: Page

  var body: some View {
    switch page {
    case .colours: ColoursPage()
    case .hues: HuesPage()
    case .type: TypePage()
    case .surfaces: SurfacesPage()
    case .motion: MotionPage()
    case .metrics: MetricsPage()
    case .liveIcon: LiveIconPage()
    case .workStatus: WorkStatusPage()
    case .effects: EffectsPage()
    case .buttons: ButtonsPage()
    case .toggles: TogglesPage()
    case .segmented: SegmentedPage()
    case .menus: MenusPage()
    case .tabs: TabsPage()
    case .fields: FieldsPage()
    case .search: SearchPage()
    case .stepper: StepperPage()
    case .keycaps: KeycapsPage()
    case .choiceCards: ChoiceCardsPage()
    case .counts: CountsPage()
    case .chips: ChipsPage()
    case .refs: RefsPage()
    case .lineCounts: LineCountsPage()
    case .avatars: AvatarsPage()
    case .sections: SectionsPage()
    case .sidebar: SidebarPage()
    case .toolbar: ToolbarPage()
    case .window: WindowPage()
    case .inspector: InspectorPage()
    case .forms: FormsPage()
    case .sheets: SheetsPage()
    case .feedback: FeedbackPage()
    case .tooltips: TooltipsPage()
    case .dragDrop: DragDropPage()
    case .grid: GridPage()
    case .changes: ChangesPage()
    case .diffs: DiffsPage()
    case .runBlocks: RunBlocksPage()
    case .palette: PalettePage()
    case .welcome: WelcomePage()
    case .settings: SettingsPage()
    case .meters: MetersPage()
    case .gitApp: GitScenarioPage()
    case .databaseApp: DatabaseScenarioPage()
    case .shellApp: ShellScenarioPage()
    case .markdownApp: MarkdownScenarioPage()
    case .settingsApp: SettingsScenarioPage()
    case .welcomeApp: WelcomeScenarioPage()
    case .allComponents: AllComponentsPage()
    }
  }
}

// MARK: - Page

/// A catalog page: its header (the area's tile, the title and one line), then its specimens, on the window ground.
struct CatalogPage<Content: View>: View {
  let page: Page
  var maxWidth: CGFloat = 980
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom
  @Environment(CatalogModel.self) private var model: CatalogModel?
  @Environment(\.catalogEmbedded) private var embedded

  var body: some View {
    if embedded {
      // On the All Components page: the page's stack alone, an item of that page's stack.
      stack
    } else {
      ScrollViewReader { proxy in
        scroll.onAppear {
          // `--section <title>` (DEBUG) opens the page scrolled to that section, for window captures.
          if let section = model?.section { proxy.scrollTo(section, anchor: .top) }
        }
      }
    }
  }

  private var stack: some View {
    // Lazy: a page's sections (and their specimens, and a grid's rows) are built as they near the screen.
    KitLazyStack(alignment: .leading, spacing: 32) {
      HStack(spacing: 14) {
        Tile(systemImage: page.systemImage, hue: page.area.hue, size: 44)
        VStack(alignment: .leading, spacing: 2) {
          Text(page.title).kitFont(.largeTitle)
          MetaLine(page.area.title, page.summary).kitFont(.callout).foregroundStyle(.kitSecondary)
        }
      }
      content
    }
  }

  private var scroll: some View {
    // A vertical scroll view takes its widest content's width, which would widen the whole column (the toolbar too);
    // the reader keeps the page at the width it is given.
    GeometryReader { proxy in
      scrollView(width: proxy.size.width)
    }
    .background(.kitWindow)
  }

  private func scrollView(width: CGFloat) -> some View {
    ScrollView {
      stack
        .padding(idiom == .phone ? 16 : 28)
        // `--offset <points>` (DEBUG) opens the page scrolled down, for iPhone captures.
        .padding(.top, -(model?.pageOffset ?? 0))
        .frame(maxWidth: maxWidth, alignment: .leading)
        // No wider than the window: a sample that doesn't fit runs off the right edge, not the whole page off both.
        .frame(width: width, alignment: .leading)
    }
    // A capture opened at a section or an offset needs the whole page built to find it.
    .kitLazyLoading(model?.section == nil && (model?.pageOffset ?? 0) == 0)
  }
}

/// A titled group of specimens on a page.
struct SpecimenSection<Content: View>: View {
  var title: String
  var note: String?
  @ViewBuilder var content: Content

  init(_ title: String, note: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.note = note
    self.content = content()
  }

  var body: some View {
    KitLazyStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title).kitFont(.title2)
        if let note {
          Text(note).kitFont(.callout).foregroundStyle(.kitSecondary).fixedSize(horizontal: false, vertical: true)
        }
      }
      content
    }
    .id(title)
  }
}

/// The ground a specimen stands on.
enum StageGround: Hashable {
  case window, panel, sidebar

  var style: KitColor {
    switch self {
    case .window: .kitWindow
    case .panel: .kitPanel
    case .sidebar: .kitSidebar
    }
  }
}

/// One sample: a title, the live view on its ground, and the minimal code to use it (selectable).
struct Specimen<Content: View>: View {
  var title: String
  var note: String?
  var ground: StageGround
  var padding: CGFloat
  var code: String?
  @ViewBuilder var content: Content

  init(
    _ title: String, note: String? = nil, ground: StageGround = .panel, padding: CGFloat = 16, code: String? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.note = note
    self.ground = ground
    self.padding = padding
    self.code = code
    self.content = content()
  }

  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    // An iPhone's width has no room for a wide stage margin.
    let padding = idiom == .phone ? min(padding, 16) : padding
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(title).kitFont(.headline)
        if let note {
          Text(note).kitFont(.caption).lineLimit(2)
        }
      }
      let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusXL, style: .continuous)
      Group {
        if padding == 0 {
          // Edge-to-edge samples (tab strips, status bars) take the stage's corners.
          content.frame(maxWidth: .infinity, alignment: .leading).background(ground.style).clipShape(shape)
        } else {
          content.frame(maxWidth: .infinity, alignment: .leading).padding(padding).background(ground.style, in: shape)
        }
      }
      .overlay(shape.strokeBorder(.kitSeparator, lineWidth: 1))
      if let code { CodeSnippet(code) }
    }
    // `--section <title>` also finds a specimen by its title.
    .id(title)
  }
}

/// Code under a sample: monospaced and selectable, on a field well.
struct CodeSnippet: View {
  var code: String

  init(_ code: String) { self.code = code }

  var body: some View {
    Text(code)
      .kitFont(.mono)
      .foregroundStyle(.kitLabel)
      .textSelection(.enabled)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .frame(maxWidth: .infinity, alignment: .leading)
      .kitSurface(.field, cornerRadius: KitMetrics.radiusLarge)
  }
}

/// Small specimens side by side, wrapping to fit; one column where even one is wider than the page (an iPhone). Its
/// rows are a `KitLazyStack`'s, so they are built as they near the screen, a few a frame.
struct SpecimenGrid<Content: View>: View {
  var minWidth: CGFloat = 300
  @ViewBuilder var content: Content
  @State private var width: CGFloat?

  var body: some View {
    let layout = SpecimenGridLayout(minWidth: minWidth)
    if #available(macOS 15, iOS 18, *) {
      Group(subviews: content) { subviews in
        let columns = layout.columns(width ?? minWidth)
        KitLazyStack(alignment: .leading, spacing: layout.rowSpacing) {
          ForEach(Array(stride(from: 0, to: subviews.count, by: columns)), id: \.self) { start in
            layout { ForEach(subviews[start..<min(start + columns, subviews.count)]) { $0 } }
          }
        }
      }
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    } else {
      layout { content }
    }
  }
}

/// As many columns of at least `minWidth` as fit, sharing the width, like an adaptive grid item.
struct SpecimenGridLayout: Layout {
  var minWidth: CGFloat = 300
  var spacing: CGFloat = 20
  var rowSpacing: CGFloat = 24

  /// The frames for the last width, until a specimen changes: a long page lays its grids out again on every change.
  struct Cache {
    var width: CGFloat?
    var frames: [CGRect] = []
  }

  func makeCache(subviews: Subviews) -> Cache { Cache() }

  func updateCache(_ cache: inout Cache, subviews: Subviews) { cache = Cache() }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
    let frames = frames(proposal.width, subviews, cache: &cache)
    return CGSize(width: proposal.width ?? frames.map(\.maxX).max() ?? 0, height: frames.map(\.maxY).max() ?? 0)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
    for (subview, frame) in zip(subviews, frames(bounds.width, subviews, cache: &cache)) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        proposal: ProposedViewSize(width: frame.width, height: nil))
    }
  }

  func columns(_ width: CGFloat) -> Int {
    max(1, Int((width + spacing) / (minWidth + spacing)))
  }

  private func frames(_ width: CGFloat?, _ subviews: Subviews, cache: inout Cache) -> [CGRect] {
    let width = width ?? minWidth
    if cache.width == width { return cache.frames }
    cache.frames = frames(width, subviews)
    cache.width = width
    return cache.frames
  }

  /// Each specimen in its cell, top leading; a row as tall as its tallest.
  private func frames(_ width: CGFloat, _ subviews: Subviews) -> [CGRect] {
    let count = columns(width)
    let column = max(0, (width - spacing * CGFloat(count - 1)) / CGFloat(count))
    var frames: [CGRect] = []
    var y: CGFloat = 0
    for start in stride(from: 0, to: subviews.count, by: count) {
      let row = subviews[start..<min(start + count, subviews.count)]
      let sizes = row.map { $0.sizeThatFits(ProposedViewSize(width: column, height: nil)) }
      for (index, size) in sizes.enumerated() {
        frames.append(CGRect(x: CGFloat(index) * (column + spacing), y: y, width: column, height: size.height))
      }
      y += (sizes.map(\.height).max() ?? 0) + rowSpacing
    }
    return frames
  }
}

/// Side by side when offered `minWidth`, else stacked: a live sample and its code, or samples a window wide. It
/// decides from the width it is offered, not its own size, which side by side could be wider than the page.
struct Columns: Layout {
  var minWidth: CGFloat = 640
  var spacing: CGFloat = 20

  /// The frames worked out for each width since the subviews last changed: measuring takes three passes over the
  /// subviews, and placing them would take three more (every time lazy content below them grows, while scrolling).
  struct Cache {
    var frames: [CGFloat?: [CGRect]] = [:]
  }

  func makeCache(subviews: Subviews) -> Cache { Cache() }

  func updateCache(_ cache: inout Cache, subviews: Subviews) { cache.frames = [:] }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
    let frames = frames(proposal.width, subviews, &cache)
    return CGSize(width: proposal.width ?? frames.map(\.maxX).max() ?? 0, height: frames.map(\.maxY).max() ?? 0)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
    for (subview, frame) in zip(subviews, frames(bounds.width, subviews, &cache)) {
      subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
    }
  }

  private func frames(_ width: CGFloat?, _ subviews: Subviews, _ cache: inout Cache) -> [CGRect] {
    if let frames = cache.frames[width] { return frames }
    let frames = frames(width, subviews)
    cache.frames[width] = frames
    return frames
  }

  /// Wide: the fixed views at their width and the flexible ones sharing the rest, tops aligned. Narrow: one under the
  /// other, each offered the whole width.
  private func frames(_ width: CGFloat?, _ subviews: Subviews) -> [CGRect] {
    guard let width, width >= minWidth else {
      var y: CGFloat = 0
      return subviews.map { subview in
        let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
        defer { y += size.height + spacing }
        return CGRect(x: 0, y: y, width: size.width, height: size.height)
      }
    }
    // A view as wide at half the width as at all of it is fixed. (Not probed at 0 and infinity: a code sample laid
    // out a character a line is slow, and this runs again whenever lazy content below settles.)
    let full = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).width }
    let half = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width / 2, height: nil)).width }
    let isFixed = zip(full, half).map { abs($0 - $1) < 1 }
    let fixedWidth = zip(isFixed, full).filter(\.0).map(\.1).reduce(0, +)
    let flexible = isFixed.filter { !$0 }.count
    let share = max(0, width - fixedWidth - spacing * CGFloat(subviews.count - 1)) / CGFloat(max(flexible, 1))
    var x: CGFloat = 0
    return subviews.indices.map { index in
      let proposed = isFixed[index] ? full[index] : share
      let size = subviews[index].sizeThatFits(ProposedViewSize(width: proposed, height: nil))
      defer { x += proposed + spacing }
      return CGRect(x: x, y: 0, width: proposed, height: size.height)
    }
  }
}

/// Scrolls sideways when the content is wider than the page (a toolbar at a fixed width on an iPhone).
struct SideScroll<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) { content }
      .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
  }
}

/// A row where it fits, else the same views stacked (on an iPhone's width).
struct RowOrStack<Content: View>: View {
  var spacing: CGFloat = 12
  var alignment: VerticalAlignment = .center
  var stackSpacing: CGFloat = 8
  @ViewBuilder var content: Content

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: alignment, spacing: spacing) { content }
      VStack(alignment: .leading, spacing: stackSpacing) { content }
    }
  }
}

/// Samples in a row that wraps onto more lines where the row doesn't fit (an iPhone's width).
struct Flow: Layout {
  var spacing: CGFloat = 12
  var lineSpacing: CGFloat?
  var alignment: VerticalAlignment = .center

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let frames = frames(subviews, maxWidth: proposal.width)
    // An item wider than the line runs past it without widening the page.
    let width = frames.map(\.maxX).max() ?? 0
    return CGSize(width: proposal.width.map { min(width, $0) } ?? width, height: frames.map(\.maxY).max() ?? 0)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for (subview, frame) in zip(subviews, frames(subviews, maxWidth: bounds.width)) {
      subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
    }
  }

  /// Each item at its ideal size (no wider than a line), wrapping before an item that would pass `maxWidth`.
  private func frames(_ subviews: Subviews, maxWidth: CGFloat?) -> [CGRect] {
    let limit = maxWidth ?? .infinity
    let sizes = subviews.map { subview in
      let ideal = subview.sizeThatFits(.unspecified)
      return ideal.width > limit ? subview.sizeThatFits(ProposedViewSize(width: limit, height: nil)) : ideal
    }
    var lines: [[Int]] = [[]]
    var x: CGFloat = 0
    for (index, size) in sizes.enumerated() {
      if !lines[lines.count - 1].isEmpty, x + spacing + size.width > limit + 0.5 {
        lines.append([])
        x = 0
      }
      x += (lines[lines.count - 1].isEmpty ? 0 : spacing) + size.width
      lines[lines.count - 1].append(index)
    }
    var frames = [CGRect](repeating: .zero, count: sizes.count)
    var y: CGFloat = 0
    for line in lines where !line.isEmpty {
      let height = line.map { sizes[$0].height }.max() ?? 0
      var x: CGFloat = 0
      for index in line {
        let size = sizes[index]
        let top: CGFloat =
          switch alignment {
          case .top: 0
          case .bottom: height - size.height
          default: (height - size.height) / 2
          }
        frames[index] = CGRect(x: x, y: y + top, width: size.width, height: size.height)
        x += size.width + spacing
      }
      y += height + (lineSpacing ?? spacing)
    }
    return frames
  }
}

/// A sample with a quiet caption under it, for rows of states ("Rest", "Disabled").
struct Labeled<Content: View>: View {
  var label: String
  @ViewBuilder var content: Content

  init(_ label: String, @ViewBuilder content: () -> Content) {
    self.label = label
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      content
      Text(label).kitFont(.caption)
    }
  }
}

/// A frame like a window's, for containers and scenarios: rounded, a hairline, clipped. Narrower than `minWidth` (an
/// iPhone), the window keeps that width and scrolls sideways.
struct WindowFrame<Content: View>: View {
  var height: CGFloat
  var minWidth: CGFloat = 0
  @ViewBuilder var content: Content
  @State private var width: CGFloat?

  var body: some View {
    Group {
      // Until measured it scrolls, which never widens the page.
      if (width ?? 0) < minWidth {
        SideScroll { window.frame(width: minWidth) }
      } else {
        window
      }
    }
    .frame(maxWidth: .infinity)
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
  }

  private var window: some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusWindow, style: .continuous)
    return content
      .frame(maxWidth: .infinity)
      .frame(height: height)
      .background(.kitWindow)
      .clipShape(shape)
      .overlay(shape.strokeBorder(.kitBorder, lineWidth: 1))
  }
}

/// An app icon drawn by the kit (an app avatar), as an image for views that take one (the welcome window).
enum AppIcon {
  static func image(systemImage: String, hue: Hue) -> Image {
    let renderer = ImageRenderer(content: Avatar(name: "App", kind: .app, systemImage: systemImage, hue: hue, size: 56).padding(4))
    renderer.scale = 3
    guard let cgImage = renderer.cgImage else { return Image(systemName: systemImage) }
    return Image(decorative: cgImage, scale: 3)
  }
}
