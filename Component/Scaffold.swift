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

  var body: some View {
    ScrollViewReader { proxy in
      scroll.onAppear {
        // `--section <title>` (DEBUG) opens the page scrolled to that section, for window captures.
        if let section = model?.section { proxy.scrollTo(section, anchor: .top) }
      }
    }
  }

  private var scroll: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 32) {
        HStack(spacing: 14) {
          Tile(systemImage: page.systemImage, hue: page.area.hue, size: 44)
          VStack(alignment: .leading, spacing: 2) {
            Text(page.title).kitFont(.largeTitle)
            MetaLine(page.area.title, page.summary).kitFont(.callout).foregroundStyle(.kitSecondary)
          }
        }
        content
      }
      .padding(idiom == .phone ? 16 : 28)
      .frame(maxWidth: maxWidth, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(.kitWindow)
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
    VStack(alignment: .leading, spacing: 16) {
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

  var body: some View {
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

/// Small specimens side by side, wrapping to fit.
struct SpecimenGrid<Content: View>: View {
  var minWidth: CGFloat = 300
  @ViewBuilder var content: Content

  var body: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: minWidth), spacing: 20, alignment: .topLeading)], alignment: .leading,
      spacing: 24
    ) {
      content
    }
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

/// A frame like a window's, for containers and scenarios: rounded, a hairline, clipped.
struct WindowFrame<Content: View>: View {
  var height: CGFloat
  @ViewBuilder var content: Content

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusWindow, style: .continuous)
    content
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
