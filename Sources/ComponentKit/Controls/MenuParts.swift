import SwiftUI

// The menu's newer parts (the canvas's Preview design and its long lists): the preview panel that says what the
// highlighted row will do, the filter field a long list starts with, a grid of tiles for picking one of many things of
// one kind (devices), and the Open With row. They go in a kit menu's content beside `Button`, `KitSubmenu` and
// `KitMenuSection`.

// MARK: - Preview panel

/// What the menu is about, in its preview panel while no row with a sentence is highlighted (rows say what they do
/// with `kitMenuPreview`). Put it anywhere in the menu's content; it draws nothing in the rows.
///
/// ```swift
/// .kitContextMenu {
///   KitMenuPreview("TripStore.swift, staged: 12 lines added, 3 removed.")
///   Button("Unstage", systemImage: "minus.circle") { unstage() }.kitMenuPreview("Takes it out of the next commit.")
/// }
/// ```
public struct KitMenuPreview: View {
  var text: String
  @Environment(\.kitMenuModel) private var model

  public init(_ text: String) {
    self.text = text
  }

  public var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .accessibilityHidden(true)
      .onAppear { model?.summary = KitMenuPreviewItem(text: text) }
      .onChange(of: text) { model?.summary = KitMenuPreviewItem(text: text) }
  }
}

/// The rows, then the views under them (the preview panel) at the rows' width: the panel's sentences wrap rather
/// than widen the menu.
struct KitMenuPanelLayout: Layout {
  var minWidth: CGFloat
  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard let rows = subviews.first else { return .zero }
    let size = rows.sizeThatFits(.unspecified)
    let width = max(size.width, minWidth, proposal.width ?? 0)
    var height = rows.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
    for view in subviews.dropFirst() {
      height += spacing + view.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
    }
    return CGSize(width: width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for (index, view) in subviews.enumerated() {
      let size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
      view.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: size.height))
      y += size.height + (index == 0 ? spacing : spacing)
    }
  }
}

/// The panel at a menu's end: the highlighted row's sentence (red for a destructive row), else the menu's summary.
/// It keeps the tallest sentence's height, so the rows above it never move.
struct KitMenuPreviewPanel: View {
  let model: KitMenuModel
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    let active = model.activePreview
    ZStack(alignment: .topLeading) {
      ForEach(Array(model.previews.enumerated()), id: \.offset) { _, item in
        sentence(item).hidden()
      }
      if let active {
        sentence(active)
      }
    }
    .padding(EdgeInsets(top: 8, leading: 10, bottom: 9, trailing: 10) * idiom.scale)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(
      active == nil ? AnyShapeStyle(.clear) : AnyShapeStyle(.kitFillSoft),
      in: RoundedRectangle(cornerRadius: KitMetrics.radiusSmall + 1, style: .continuous)
    )
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.updatesFrequently)
  }

  private func sentence(_ item: KitMenuPreviewItem) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      if let picture = item.picture { picture }
      Text(item.text)
        .font(.system(size: 12 * idiom.scale))
        .lineSpacing(2)
        .foregroundStyle(item.isDanger ? AnyShapeStyle(Hue.red.text) : AnyShapeStyle(.kitLabel))
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension EdgeInsets {
  fileprivate static func * (insets: EdgeInsets, scale: CGFloat) -> EdgeInsets {
    EdgeInsets(
      top: insets.top * scale, leading: insets.leading * scale, bottom: insets.bottom * scale,
      trailing: insets.trailing * scale)
  }
}

// MARK: - Filter

/// The field a long list starts with (over 10 choices): typing while the menu is open goes into it, rows whose words
/// (`kitMenuFilter`) don't contain the text hide, folds (`KitSubmenu`) show their rows in place, section headers hide
/// and each match says its kind at its end. Delete takes a character off, Esc clears it (then closes the menu),
/// Return picks the first match. Commands (rows without words: Refresh) stay. On touch it is a text field that takes
/// the keyboard only when tapped.
///
/// ```swift
/// KitMenuFilter("Filter \(schemes.count) schemes", total: schemes.count)
/// KitMenuSection("Apps") { ForEach(apps) { Button($0.name) { … }.kitMenuFilter($0.name, kind: "App") } }
/// KitSubmenu("Libraries", value: "\(libraries.count)") { ForEach(libraries) { … } }
/// ```
public struct KitMenuFilter: View {
  var prompt: String
  var total: Int?
  var empty: ((String) -> String)?
  @Environment(\.kitMenuModel) private var model
  @Environment(\.kitIdiom) private var idiom

  /// `total`: how many rows it filters, for "2 of 22" while typing. `empty` says that nothing matches what's typed
  /// ("No scheme has “docker” in its name.").
  public init(_ prompt: String, total: Int? = nil, empty: ((String) -> String)? = nil) {
    self.prompt = prompt
    self.total = total
    self.empty = empty
  }

  public var body: some View {
    let metrics = KitMenuMetrics(idiom)
    let query = model?.query ?? ""
    VStack(alignment: .leading, spacing: metrics.rowGap) {
      HStack(spacing: idiom.size(6, touch: 8)) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: idiom.size(12, touch: 15)))
        field(query)
        Spacer(minLength: 4)
        if !query.isEmpty, let total, let model {
          Text("\(model.matchCount) of \(total)")
            .font(.system(size: metrics.hintFont))
            .monospacedDigit()
            .fixedSize()
        }
      }
      .foregroundStyle(.kitSecondary)
      .font(.system(size: metrics.font))
      .padding(.horizontal, idiom.size(8, touch: 12))
      .frame(height: idiom.size(28, touch: 44))
      .background(.kitFill, in: RoundedRectangle(cornerRadius: metrics.rowRadius, style: .continuous))
      .padding(.bottom, idiom.size(3, touch: 4))
      if !query.isEmpty, model?.matchCount == 0 {
        Text(empty?(query) ?? "Nothing has “\(query)” in its name.")
          .font(.system(size: metrics.headerFont, weight: .semibold))
          .foregroundStyle(.kitSecondary)
          .padding(EdgeInsets(top: 4, leading: metrics.rowPadding, bottom: 3, trailing: metrics.rowPadding))
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .onAppear { model?.hasFilter = true }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(query.isEmpty ? prompt : "Filter: \(query)")
    .accessibilityAddTraits(.isSearchField)
  }

  @ViewBuilder
  private func field(_ query: String) -> some View {
    if idiom.isTouch, let model {
      TextField(prompt, text: Binding(get: { model.query }, set: { model.query = $0 }))
        .textFieldStyle(.plain)
        .autocorrectionDisabled()
        .foregroundStyle(.kitLabel)
    } else if query.isEmpty {
      Text(prompt).lineLimit(1)
    } else {
      // Drawn rather than a field: the menu's panel never takes focus from the window, so the keys come to it.
      HStack(spacing: 1) {
        Text(query).foregroundStyle(.kitLabel).lineLimit(1)
        Rectangle().fill(.kitAccent).frame(width: 1, height: 15)
      }
    }
  }
}

// MARK: - Tiles

/// Tiles for picking one of many things of one kind (devices, simulators): `columns` across, each a picture, a name
/// and a quiet word. Only for pickers: actions stay rows. Head each family with a `KitMenuSection` so a tile drops
/// what the family already says ("17 Pro", not "iPhone 17 Pro"). ↑ ↓ ← → move between tiles.
///
/// ```swift
/// KitMenuSection("iPhone Simulators", value: "iOS 27.2") {
///   KitMenuGrid {
///     ForEach(iPhones) { phone in
///       KitMenuTile(phone.shortName, systemImage: "iphone", detail: phone.isBooted ? "Booted" : nil,
///                   isOn: phone == destination) { destination = phone }
///         .kitMenuFilter(phone.name)
///     }
///   }
/// }
/// ```
public struct KitMenuGrid<Content: View>: View {
  var columns: Int
  var content: Content
  @Environment(\.kitIdiom) private var idiom

  public init(columns: Int = 3, @ViewBuilder content: () -> Content) {
    self.columns = columns
    self.content = content()
  }

  public var body: some View {
    let metrics = KitMenuMetrics(idiom)
    let gap = idiom.size(2, touch: 4)
    LazyVGrid(
      columns: Array(repeating: GridItem(.fixed(metrics.tileWidth), spacing: gap, alignment: .top), count: columns),
      alignment: .leading, spacing: gap
    ) {
      content
    }
    .fixedSize()
  }
}

/// One tile in a `KitMenuGrid`: a picture, a name, a quiet word under it; the picked one tinted with a check in its
/// corner. Picking it closes the menu. Its name is also its filter words unless `kitMenuFilter` says otherwise.
public struct KitMenuTile: View {
  var title: String
  var systemImage: String
  var detail: String?
  var isOn: Bool
  var action: () -> Void
  @Environment(\.kitMenuModel) private var model
  @Environment(\.kitMenuFilter) private var filter
  @Environment(\.kitMenuPreview) private var preview
  @Environment(\.kitMenuForcedHighlight) private var forced
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitIdiom) private var idiom
  @State private var id = UUID()

  public init(
    _ title: String, systemImage: String, detail: String? = nil, isOn: Bool = false, action: @escaping () -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.detail = detail
    self.isOn = isOn
    self.action = action
  }

  private var words: KitMenuFilterText { filter ?? KitMenuFilterText(text: title) }
  private var isHighlighted: Bool { isEnabled && (forced || model?.highlighted == id) }

  public var body: some View {
    if let model, model.isFiltering, !words.text.localizedStandardContains(model.rootQuery) {
      EmptyView()
    } else {
      tile
    }
  }

  private var tile: some View {
    let metrics = KitMenuMetrics(idiom)
    return VStack(spacing: 3 * idiom.scale) {
      Image(systemName: systemImage)
        .font(.system(size: 20 * idiom.scale))
        .frame(height: 24 * idiom.scale)
        .foregroundStyle(!isEnabled ? AnyShapeStyle(.kitTertiary) : isOn ? AnyShapeStyle(.kitAccent) : AnyShapeStyle(.kitSecondary))
      Text(title)
        .font(.system(size: idiom.size(12, touch: 14)))
        .foregroundStyle(isEnabled ? AnyShapeStyle(.kitLabel) : AnyShapeStyle(.kitTertiary))
        .lineLimit(1)
        .truncationMode(.middle)
      if let detail {
        Text(detail)
          .font(.system(size: metrics.detailFont))
          .foregroundStyle(.kitSecondary)
          .lineLimit(1)
      }
    }
    .padding(EdgeInsets(top: 8, leading: 4, bottom: 7, trailing: 4) * idiom.scale)
    .frame(width: metrics.tileWidth)
    .frame(maxHeight: .infinity, alignment: .top)
    .background {
      RoundedRectangle(cornerRadius: metrics.rowRadius, style: .continuous)
        .fill(isOn || isHighlighted ? AnyShapeStyle(Hue.accent.soft(isOn && isHighlighted ? 0.22 : 0.14)) : AnyShapeStyle(.clear))
    }
    .overlay(alignment: .topTrailing) {
      if isOn {
        Image(systemName: "checkmark")
          .font(.system(size: 9 * idiom.scale, weight: .bold))
          .foregroundStyle(.kitAccent)
          .padding(5 * idiom.scale)
      }
    }
    .contentShape(Rectangle())
    .kitHover { inside in
      guard let model, isEnabled else { return }
      if inside { model.highlight(id) } else if model.highlighted == id { model.highlighted = nil }
    }
    .onTapGesture { if isEnabled { pick() } }
    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(KitMenuModel.space)) } action: { frame in
      model?.setFrame(id, frame)
    }
    .onChange(of: isEnabled, initial: true) {
      register()
      if forced, isEnabled { model?.highlighted = id }
    }
    .onChange(of: words) { register() }
    .onDisappear { model?.remove(id) }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction { if isEnabled { pick() } }
  }

  private func pick() {
    if let model { model.perform(action) } else { action() }
  }

  private func register() {
    let pick = pick
    let words = words
    let preview = preview
    model?.update(id) { row in
      row.isEnabled = isEnabled
      row.trigger = pick
      row.filter = words
      row.preview = preview
      // ← → walk the tiles in reading order, as ↑ ↓ do.
      row.step = { [weak model] delta in model?.move(by: delta) }
    }
  }
}

// MARK: - Open With

/// An app a file or folder can open in, for `KitOpenWithRow`: its name, icon, the row's words for it ("Open in
/// Xcode", "Show in Finder") and what it opens.
public struct KitOpenApp: Identifiable {
  public var id: String
  public var name: String
  public var icon: Image?
  public var words: String
  public var preview: String?
  public var action: @MainActor () -> Void

  public init(
    _ name: String, icon: Image?, words: String? = nil, preview: String? = nil, id: String? = nil,
    action: @escaping @MainActor () -> Void
  ) {
    self.id = id ?? name
    self.name = name
    self.icon = icon
    self.words = words ?? "Open in \(name)"
    self.preview = preview
    self.action = action
  }

  /// An installed app by its bundle identifier, opening `urls` (a project's folder, then a file in it); nil when it
  /// isn't installed (and off the Mac).
  ///
  /// ```swift
  /// KitOpenApp.app("com.apple.dt.Xcode", name: "Xcode", opening: [project], preview: "Opens Trips in Xcode.")
  /// ```
  @MainActor public static func app(
    _ bundleIdentifier: String, name: String, opening urls: [URL], preview: String? = nil
  ) -> KitOpenApp? {
    guard KitDesktop.isAppInstalled(bundleIdentifier) else { return nil }
    return KitOpenApp(name, icon: KitDesktop.appIcon(bundleIdentifier), preview: preview, id: bundleIdentifier) {
      KitDesktop.open(urls, withApp: bundleIdentifier)
    }
  }

  /// The file manager (Finder, Explorer, Files), selecting `urls` in their folder: "Show in Finder".
  @MainActor public static func fileManager(revealing urls: [URL], preview: String? = nil) -> KitOpenApp {
    let name = KitDesktop.fileManagerName
    return KitOpenApp(name, icon: KitDesktop.fileManagerIcon, words: "Show in \(name)", preview: preview, id: "kit.files") {
      KitDesktop.reveal(urls)
    }
  }

  /// A terminal in `folder` (Terminal on the Mac); nil where there is none to open (iPhone, iPad).
  @MainActor public static func terminal(at folder: URL, preview: String? = nil) -> KitOpenApp? {
    #if os(iOS) || os(tvOS) || os(visionOS)
      return nil
    #else
      #if os(macOS)
        let icon = KitDesktop.appIcon("com.apple.Terminal")
      #else
        let icon: Image? = nil
      #endif
      return KitOpenApp("Terminal", icon: icon, preview: preview, id: "kit.terminal") {
        KitDesktop.openTerminal(at: folder)
      }
    #endif
  }
}

/// Open With as one row: the first app in words with its icon, the other apps as icons at the row's end. Pointing at
/// an icon turns the words and the first icon into that app's ("Show in Finder"), so the row always says what a click
/// does; clicking the words opens the first app, an icon its own. ← → move between the apps, Return opens. On iPhone
/// and iPad (no pointer to follow) each app is its own row. Apps that are nil (not installed) are left out, and with
/// none the row draws nothing.
///
/// ```swift
/// .kitContextMenu {
///   Button("Stop", systemImage: "stop.fill") { stop() }
///   Divider()
///   KitOpenWithRow([
///     .app("com.apple.dt.Xcode", name: "Xcode", opening: [project.url]),
///     .fileManager(revealing: [project.url]),
///     .terminal(at: project.url),
///   ])
/// }
/// ```
public struct KitOpenWithRow: View {
  var apps: [KitOpenApp]
  @Environment(\.kitMenuModel) private var model
  @Environment(\.kitIdiom) private var idiom
  @State private var rowID = UUID()
  /// The app under the pointer (or picked with ← →); nil: the first.
  @State private var active: Int?

  public init(_ apps: [KitOpenApp?]) {
    self.apps = apps.compactMap { $0 }
  }

  public var body: some View {
    if apps.isEmpty {
      EmptyView()
    } else if idiom.isTouch {
      ForEach(apps) { app in
        KitMenuRow(trigger: { open(app) }) {
          Label { Text(app.words) } icon: { icon(app, size: KitMenuMetrics(idiom).icon + 4) }
        }
        .kitMenuPreview(app.preview)
      }
    } else {
      row
    }
  }

  private var row: some View {
    let metrics = KitMenuMetrics(idiom)
    let shown = model?.highlighted == rowID ? (active ?? 0) : 0
    let app = apps[min(shown, apps.count - 1)]
    let others = Array(apps.indices.dropFirst())
    let count = apps.count
    let activeBinding = $active
    return KitMenuRow(
      rowID: rowID, height: metrics.appIcon + idiom.size(8, touch: 12),
      trailing: others.isEmpty ? nil : AnyView(buttons(others, shown: shown)),
      step: { delta in
        let next = ((activeBinding.wrappedValue ?? 0) + delta + count) % count
        activeBinding.wrappedValue = next
      },
      trigger: { open(app) }
    ) {
      Label { Text(app.words) } icon: { icon(app, size: metrics.appIcon) }
    }
    .kitMenuPreview(app.preview)
    .onChange(of: model?.highlighted == rowID) { _, highlighted in if !highlighted { active = nil } }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Open With")
  }

  private func buttons(_ indices: [Int], shown: Int) -> some View {
    let metrics = KitMenuMetrics(idiom)
    let side = metrics.appIcon + 2 * idiom.scale
    return HStack(spacing: 2 * idiom.scale) {
      ForEach(indices, id: \.self) { index in
        let app = apps[index]
        icon(app, size: metrics.appIcon)
          .frame(width: side, height: side)
          .background {
            RoundedRectangle(cornerRadius: 6 * idiom.scale, style: .continuous)
              .fill(index == shown ? AnyShapeStyle(Hue.accent.soft(0.22)) : AnyShapeStyle(.clear))
          }
          .contentShape(Rectangle())
          .kitHover { inside in
            if inside {
              model?.highlight(rowID)
              active = index
            } else if active == index {
              active = nil
            }
          }
          .onTapGesture { open(app) }
          .help(app.words)
          .accessibilityElement()
          .accessibilityLabel(app.words)
          .accessibilityAddTraits(.isButton)
          .accessibilityAction { open(app) }
      }
    }
    .padding(.leading, 8)
  }

  @ViewBuilder
  private func icon(_ app: KitOpenApp, size: CGFloat) -> some View {
    if let image = app.icon {
      image.resizable().interpolation(.high).aspectRatio(contentMode: .fit).frame(width: size, height: size)
    } else {
      Image(systemName: "app.dashed").font(.system(size: size * 0.7)).frame(width: size, height: size)
    }
  }

  private func open(_ app: KitOpenApp) {
    if let model { model.perform { app.action() } } else { app.action() }
  }
}
