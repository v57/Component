import SwiftUI

/// The command palette and quick open (Code's Open Quickly, Markdown's commands, Shell's quick actions ⌘R): a card on
/// the panel ground with 20pt corners. The search line starts with an optional scope pop-up and ends with the live
/// icon (the work indicator while searching or indexing, a check when done, red when nothing matched); results are group cards
/// with rich headers; the selected row is raised and Return runs it; a card bar of key hints closes it.
/// ↑↓ move through every group's items, Return runs the selected one, Escape calls `dismiss`.
///
/// Summon it with `kitPaletteOverlay(isPresented:)`, which dims the whole window (from any view in it, as kit sheets
/// do, and over a sheet it is opened from), places it and closes it on a click outside;
/// a palette placed in the window by hand doesn't dim. Put it in a view directly only to embed it in a page
/// (`focusesOnAppear: false`).
///
/// ```swift
/// KitPalette(query: $query, prompt: "Run an action or search", status: .done, dismiss: { isOpen = false }) {
///   PaletteMenu("atlas", systemImage: "folder") { Button("atlas") {}; Button("pebble") {} }
/// } content: {
///   PaletteGroup("Atlas", meta: ["Xcode", "Atlas.xcodeproj"], systemImage: "hammer") {
///     PaletteMenu("Atlas", systemImage: "hammer") { Button("Atlas") {}; Button("AtlasKit") {} }
///   } items: {
///     PaletteItem("Build", systemImage: "hammer", hue: .orange, detail: "xcodebuild … build", shortcut: "⌘B") { build() }
///     PaletteItem("Test", systemImage: "testtube.2", hue: .purple, note: "Stops Build first") { test() }
///   }
/// }
/// ```
public struct KitPalette<Scope: View, Content: View>: View {
  @Binding var query: String
  var prompt: String
  var status: WorkStatus
  var hints: [PaletteHint]
  var maxHeight: CGFloat
  var dismiss: (() -> Void)?
  var focusesOnAppear: Bool
  var scope: Scope
  var content: Content
  @State private var nav = DataNavModel()
  @State private var contentHeight: CGFloat = 0
  @FocusState private var isFocused: Bool
  @Environment(\.dataRendersFlat) private var flat
  @Environment(\.kitIdiom) private var idiom

  /// A palette; `focusesOnAppear` false leaves the search field unfocused when it shows (a palette embedded in a
  /// page rather than summoned).
  public init(
    query: Binding<String>, prompt: String = "Search", status: WorkStatus = .idle,
    hints: [PaletteHint] = PaletteHint.standard, maxHeight: CGFloat = 440, dismiss: (() -> Void)? = nil,
    focusesOnAppear: Bool = true, @ViewBuilder scope: () -> Scope, @ViewBuilder content: () -> Content
  ) {
    self._query = query
    self.prompt = prompt
    self.status = status
    self.hints = hints
    self.maxHeight = maxHeight
    self.dismiss = dismiss
    self.focusesOnAppear = focusesOnAppear
    self.scope = scope()
    self.content = content()
  }

  public var body: some View {
    VStack(spacing: KitMetrics.gutter) {
      searchLine
      results
      if !hints.isEmpty { footer }
    }
    .padding(KitMetrics.gutter)
    .background { KitOverlayCardGround() }
    .environment(nav)
    .environment(\.dataPaletteQuery, query)
    .onPreferenceChange(DataNavItemsKey.self) { ids in
      MainActor.assumeIsolated { nav.update(ids: ids, isLazy: !flat) }
    }
    .onChange(of: query) { nav.selectFirst() }
    .onAppear { if focusesOnAppear { isFocused = true } }
  }

  private var searchLine: some View {
    HStack(spacing: 8) {
      scope
      TextField(prompt, text: $query)
        .textFieldStyle(.plain)
        .font(.system(size: idiom.size(17, touch: 20)))
        .focused($isFocused)
        .onSubmit { nav.activate() }
        .onKeyPress(.upArrow) {
          nav.move(by: -1)
          return .handled
        }
        .onKeyPress(.downArrow) {
          nav.move(by: 1)
          return .handled
        }
        .onKeyPress(.escape) {
          guard let dismiss else { return .ignored }
          dismiss()
          return .handled
        }
      LiveIcon(systemImage: "magnifyingglass", status: status, size: 20)
        .padding(.trailing, 4)
    }
    .padding(.leading, 8)
    .padding(.trailing, 6)
    .frame(height: idiom.size(44, touch: 52))
    .background {
      let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)
      SurfaceShape(surface: .raised, cornerRadius: KitMetrics.radiusCard)
        .overlay(shape.strokeBorder(Hue.accent.soft(0.5), lineWidth: isFocused ? 2 : 0))
    }
    .animation(.kitFast, value: isFocused)
  }

  /// Lazy in the scroll view: a palette with hundreds of results (Shell's ⌘R in a workspace of 47 schemes) built them
  /// all before its first frame. Keyboard navigation follows the built rows, and the next ones are built as the
  /// selection scrolls to them. Only the keyboard and a new query scroll it: as a scroll drops the selected row, the
  /// selection follows the first built one without pulling the scroll back.
  @ViewBuilder
  private var results: some View {
    if flat {
      VStack(spacing: KitMetrics.gutter) { content }
    } else {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: KitMetrics.gutter) { content }
            .id(Self.top)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollIndicators(.never)
        .frame(height: min(contentHeight, maxHeight))
        .onChange(of: nav.moves) {
          guard let id = nav.selected else { return }
          withKitAnimation(.kitFast) { proxy.scrollTo(id, anchor: nav.moveAnchor) }
        }
        .onChange(of: query) { proxy.scrollTo(Self.top, anchor: .top) }
      }
    }
  }

  private static var top: String { "kit.palette.top" }

  private var footer: some View {
    HStack(spacing: 14) {
      ForEach(hints) { hint in
        HStack(spacing: 6) {
          HStack(spacing: 2) { ForEach(hint.keys, id: \.self) { Keycaps($0) } }
          Text(hint.label)
        }
      }
      Spacer(minLength: 0)
    }
    .font(.system(size: 12))
    .foregroundStyle(.kitSecondary)
    .padding(.horizontal, 8)
    .frame(minHeight: 32)
    .kitSurface(.card)
  }
}

extension KitPalette where Scope == EmptyView {
  /// A palette without a scope pop-up.
  public init(
    query: Binding<String>, prompt: String = "Search", status: WorkStatus = .idle,
    hints: [PaletteHint] = PaletteHint.standard, maxHeight: CGFloat = 440, dismiss: (() -> Void)? = nil,
    focusesOnAppear: Bool = true, @ViewBuilder content: () -> Content
  ) {
    self.init(
      query: query, prompt: prompt, status: status, hints: hints, maxHeight: maxHeight, dismiss: dismiss,
      focusesOnAppear: focusesOnAppear, scope: { EmptyView() }, content: content)
  }
}

extension EnvironmentValues {
  @Entry var dataPaletteQuery: String = ""
}

/// A key hint in the palette's footer: keycaps and what they do.
///
/// ```swift
/// PaletteHint(["⌘", "↩"], "Beside")
/// ```
public struct PaletteHint: Identifiable, Hashable, Sendable {
  public var keys: [String]
  public var label: String
  public var id: String { label }

  public init(_ keys: [String], _ label: String) {
    self.keys = keys
    self.label = label
  }

  /// ↑↓ Move, ↩ Open, esc Close.
  public static let standard = [PaletteHint(["↑", "↓"], "Move"), PaletteHint(["↩"], "Open"), PaletteHint(["esc"], "Close")]
}

// MARK: - Groups

/// A group of palette results as a card: a rich header (tile or live icon, the name, a meta line, an optional
/// pop-up that covers the whole group, such as the scheme or host) over its items.
///
/// ```swift
/// PaletteGroup("Running in atlas", meta: ["Build · 0:42"], systemImage: "bolt", status: .working) {
///   PaletteItem("Build", systemImage: "hammer", status: .working, returnLabel: "Stop") { stop() }
/// }
/// ```
public struct PaletteGroup<Accessory: View, Items: View>: View {
  var title: String
  var meta: [String]
  var systemImage: String
  var hue: Hue
  var status: WorkStatus
  var accessory: Accessory
  var items: Items

  public init(
    _ title: String, meta: [String] = [], systemImage: String, hue: Hue = .accent, status: WorkStatus = .idle,
    @ViewBuilder accessory: () -> Accessory, @ViewBuilder items: () -> Items
  ) {
    self.title = title
    self.meta = meta
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
    self.accessory = accessory()
    self.items = items()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      RichHeader(title, meta: meta, systemImage: systemImage, hue: hue, status: status) { accessory }
      items
    }
    .kitCard()
  }
}

extension PaletteGroup where Accessory == EmptyView {
  public init(
    _ title: String, meta: [String] = [], systemImage: String, hue: Hue = .accent, status: WorkStatus = .idle,
    @ViewBuilder items: () -> Items
  ) {
    self.init(title, meta: meta, systemImage: systemImage, hue: hue, status: status, accessory: { EmptyView() },
      items: items)
  }
}

// MARK: - Items

/// One result in a palette: a solid tile (or a live icon while it runs, or any icon view), the title with the
/// query's match in bold, a mono detail (the command it runs, the folder), a note in orange ("Stops Build first"),
/// the shortcut; the selected row is raised and shows ↩ (with `returnLabel`, what Return does).
///
/// `subtitle` adds a second line (a file's folder, a symbol's location); `matches` bolds the given UTF-16 offsets of
/// the title (a fuzzy matcher's positions) instead of the query's first occurrence, `subtitleMatches` those of the
/// subtitle.
///
/// ```swift
/// PaletteItem("Build", systemImage: "hammer", hue: .orange, detail: "xcodebuild … build", shortcut: "⌘B") { build() }
/// PaletteItem(file.name, subtitle: file.folder, matches: match.positions, icon: { FileIcon(file) }) { open(file) }
/// ```
public struct PaletteItem: View {
  var title: String
  var id: String
  var systemImage: String
  var hue: Hue
  var subtitle: String?
  var matches: [Int]?
  var subtitleMatches: [Int]?
  var icon: AnyView?
  var detail: String?
  var note: String?
  var shortcut: String?
  var status: WorkStatus
  var returnLabel: String?
  var isEnabled: Bool
  var action: () -> Void
  @Environment(DataNavModel.self) private var nav: DataNavModel?
  @Environment(\.dataPaletteQuery) private var query
  @Environment(\.kitIdiom) private var idiom
  @State private var isHovered = false

  public init(
    _ title: String, id: String? = nil, systemImage: String, hue: Hue = .accent, subtitle: String? = nil,
    matches: [Int]? = nil, subtitleMatches: [Int]? = nil, detail: String? = nil,
    note: String? = nil, shortcut: String? = nil, status: WorkStatus = .idle, returnLabel: String? = nil,
    isEnabled: Bool = true, action: @escaping () -> Void
  ) {
    self.title = title
    self.id = id ?? title + (subtitle ?? "") + (detail ?? "")
    self.systemImage = systemImage
    self.hue = hue
    self.subtitle = subtitle
    self.matches = matches
    self.subtitleMatches = subtitleMatches
    self.detail = detail
    self.note = note
    self.shortcut = shortcut
    self.status = status
    self.returnLabel = returnLabel
    self.isEnabled = isEnabled
    self.action = action
  }

  /// A result with any icon view (a file's icon drawn as letters, an avatar), 20pt.
  public init<Icon: View>(
    _ title: String, id: String? = nil, subtitle: String? = nil, matches: [Int]? = nil,
    subtitleMatches: [Int]? = nil, detail: String? = nil, note: String? = nil, shortcut: String? = nil,
    returnLabel: String? = nil, isEnabled: Bool = true, @ViewBuilder icon: () -> Icon,
    action: @escaping () -> Void
  ) {
    self.init(
      title, id: id, systemImage: "", subtitle: subtitle, matches: matches, subtitleMatches: subtitleMatches,
      detail: detail, note: note, shortcut: shortcut, returnLabel: returnLabel, isEnabled: isEnabled, action: action)
    self.icon = AnyView(icon())
  }

  private var isSelected: Bool { nav?.selected == id }

  public var body: some View {
    HStack(spacing: 10) {
      Group {
        if let icon {
          icon.frame(width: 20, height: 20)
        } else if status == .idle {
          Tile(systemImage: systemImage, hue: hue, size: 20, style: .solid)
        } else {
          LiveIcon(systemImage: systemImage, hue: hue, status: status, size: 20)
        }
      }
      .opacity(isEnabled ? 1 : 0.45)
      VStack(alignment: .leading, spacing: 1) {
        Text(matches.map { PaletteMatch.marked(title, offsets: $0) } ?? PaletteMatch.marked(title, query: query))
          .foregroundStyle(isEnabled ? AnyShapeStyle(.kitLabel) : AnyShapeStyle(.kitTertiary))
          .lineLimit(1)
        if let subtitle {
          Text(subtitleMatches.map { PaletteMatch.marked(subtitle, offsets: $0) } ?? AttributedString(subtitle))
            .kitFont(.caption)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
      .layoutPriority(1)
      if let detail {
        Text(detail)
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(.kitSecondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      Spacer(minLength: 6)
      if let note {
        Text(note).font(.system(size: 11, weight: .medium)).foregroundStyle(Hue.orange.text).lineLimit(1).fixedSize()
      }
      if let shortcut, !isSelected {
        Text(shortcut).font(.system(size: 12)).foregroundStyle(.kitQuiet).fixedSize()
      }
      if isSelected {
        HStack(spacing: 5) {
          Keycap("↩")
          if let returnLabel { Text(returnLabel).font(.system(size: 11)).foregroundStyle(.kitSecondary) }
        }
        .transition(.opacity)
      } else if let returnLabel, status.isWorking {
        Text(returnLabel).font(.system(size: 11)).foregroundStyle(.kitSecondary)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, subtitle == nil ? 0 : 3)
    .frame(minHeight: subtitle == nil ? (idiom.size(36, touch: 44)) : KitMetrics.twoLineRow(idiom))
    .background {
      if isSelected {
        SurfaceShape(surface: .raised, cornerRadius: KitMetrics.radius)
      } else if isHovered {
        RoundedRectangle(cornerRadius: KitMetrics.radius, style: .continuous).fill(.kitHover)
      }
    }
    .contentShape(Rectangle())
    .kitHover { isHovered = $0 }
    .onTapGesture { if isEnabled { nav?.activate(id) ?? action() } }
    .dataNavItem(id, model: nav, action: isEnabled ? action : nil)
    .id(id)
    .animation(.kitFast, value: isSelected)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}

enum PaletteMatch {
  /// The title with the characters at `offsets` (UTF-16, as fuzzy matchers report them) in semibold; offsets past
  /// the end are ignored.
  static func marked(_ title: String, offsets: [Int]) -> AttributedString {
    var text = AttributedString(title)
    let utf16 = title.utf16
    for offset in Set(offsets).sorted() where offset >= 0 && offset < utf16.count {
      let start = utf16.index(utf16.startIndex, offsetBy: offset)
      guard let lower = start.samePosition(in: title) else { continue }
      let upper = title.index(after: lower)
      guard let range = Range(lower..<upper, in: text) else { continue }
      text[range].inlinePresentationIntent = .stronglyEmphasized
    }
    return text
  }

  /// The title with the first case-insensitive occurrence of `query` in semibold.
  static func marked(_ title: String, query: String) -> AttributedString {
    var text = AttributedString(title)
    let needle = query.trimmingCharacters(in: .whitespaces)
    guard !needle.isEmpty, let range = text.range(of: needle, options: .caseInsensitive) else { return text }
    text[range].inlinePresentationIntent = .stronglyEmphasized
    return text
  }
}

// MARK: - Overlay

extension View {
  /// Shows a palette over the window while `isPresented`, on the root's overlay host as kit sheets are (from any
  /// view in the window, stacking with sheets): the window dims (`kitScrim`), the palette sits at the top centre,
  /// 560pt wide at most (8pt from the edges on a narrow window), and a click on the dim closes it. Escape closes it
  /// through the palette's own `dismiss`. Without `componentKit()` above it, it covers this view only.
  ///
  /// ```swift
  /// Workspace()
  ///   .kitPaletteOverlay(isPresented: $showsQuickOpen) {
  ///     KitPalette(query: $query, prompt: "Open Quickly", dismiss: { showsQuickOpen = false }) { … }
  ///   }
  /// ```
  public func kitPaletteOverlay<Palette: View>(
    isPresented: Binding<Bool>, width: CGFloat = 560, @ViewBuilder palette: @escaping () -> Palette
  ) -> some View {
    modifier(DataPalettePresenter(isPresented: isPresented, width: width, palette: palette))
  }
}

private struct DataPalettePresenter<Palette: View>: ViewModifier {
  @Binding var isPresented: Bool
  let width: CGFloat
  let palette: () -> Palette
  @Environment(\.kitOverlayHost) private var host

  func body(content: Content) -> some View {
    if host == nil {
      content.overlay { DataPaletteOverlay(isPresented: $isPresented, width: width, palette: palette) }
    } else {
      content.modifier(
        KitOverlayPresenter(
          isPresented: $isPresented, style: .palette(width: width), onDismiss: nil,
          content: palette))
    }
  }
}

/// The palette over this view alone, without the root's host.
private struct DataPaletteOverlay<Palette: View>: View {
  @Binding var isPresented: Bool
  let width: CGFloat
  let palette: () -> Palette
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    ZStack(alignment: .top) {
      if isPresented {
        Rectangle()
          .fill(.kitScrim)
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture { withKitAnimation(.kitFast) { isPresented = false } }
          .accessibilityAddTraits(.isButton)
          .accessibilityLabel("Close")
          .transition(.opacity)
        palette()
          .frame(maxWidth: width)
          .padding(.horizontal, KitMetrics.gutter)
          .padding(.top, idiom.isTouch ? 16 : KitMetrics.gutter)
          .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
      }
    }
    .animation(.kitFast, value: isPresented)
  }
}

// MARK: - Pop-up

/// The palette's pop-ups: the scope at the start of the search line ("atlas"), and the scheme or host in a group's
/// header ("Atlas"). A raised pill with a glyph, the title and a chevron; its content is the menu.
///
/// ```swift
/// PaletteMenu("atlas-web-1", systemImage: "globe") { ForEach(hosts) { host in Button(host.name) { pick(host) } } }
/// ```
public struct PaletteMenu<Content: View>: View {
  var title: String
  var systemImage: String?
  var content: Content

  public init(_ title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  public var body: some View {
      HStack(spacing: 5) {
        if let systemImage { Image(systemName: systemImage).font(.system(size: 10, weight: .semibold)) }
        Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1)
        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(.kitSecondary)
      }
      .foregroundStyle(.kitLabel)
      .padding(.horizontal, 8)
      .frame(height: 26)
      .background { SurfaceShape(surface: .raised, cornerRadius: KitMetrics.radiusSmall) }
      .contentShape(Rectangle())
      .fixedSize()
      .kitMenu { content }
      .accessibilityLabel(title)
  }
}

#Preview("Palette") {
  @Previewable @State var query = "build"
  KitPalette(query: $query, prompt: "Run an action or search", status: .done) {
    PaletteMenu("atlas", systemImage: "folder") { Button("atlas") {} }
  } content: {
    PaletteGroup("Running in atlas", meta: ["Build · 0:42"], systemImage: "bolt", status: .working) {
      PaletteItem(
        "Build", systemImage: "hammer", hue: .orange, detail: "Atlas · Building … · 0:42", status: .working,
        returnLabel: "Stop") {}
    }
    PaletteGroup("Atlas", meta: ["Xcode", "Atlas.xcodeproj"], systemImage: "hammer") {
      PaletteMenu("Atlas", systemImage: "hammer") { Button("Atlas") {} }
    } items: {
      PaletteItem("Run", systemImage: "play.fill", hue: .green, detail: "xcodebuild -scheme Atlas build", shortcut: "⌘R") {}
      PaletteItem("Build", systemImage: "hammer", hue: .orange, detail: "xcodebuild -scheme Atlas build", shortcut: "⌘B") {}
      PaletteItem("Test", systemImage: "testtube.2", hue: .purple, note: "Stops Build first") {}
    }
  }
  .frame(width: 560)
  .padding(30)
  .componentKit()
}
