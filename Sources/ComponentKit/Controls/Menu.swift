import SwiftUI

#if canImport(AppKit)
  import AppKit
#elseif canImport(UIKit)
  import UIKit
#endif

// Menus: the kit draws its own (the canvas's menu, from Shell's drop menu): a floating card with a hairline and a
// soft shadow, 26pt rows (44 on touch) with a 16pt icon column, the title and a trailing hint; the highlighted row is
// the accent with white text. `.kitMenu(isPresented:)` opens one under any view; `KitPicker` and `KitMenuButton` use
// it. Inside, SwiftUI's own `Button`, `Toggle` and `Divider` become menu rows; `KitMenuOptions` picks one of several
// values, `KitSubmenu` opens a menu beside its row, `KitMenuFooter` says what the menu acts on.
//
// It floats above the window like a system menu: on the Mac in a borderless panel over the screen (so it works in
// sheets and can run past the window's edge), on iPad and iPhone in a window above the scene. A click outside closes
// it (and is swallowed, as a menu's is), as do Esc, picking a row, and the app or window going away. ↑/↓ move the
// highlight, Return picks.

extension View {
  /// Opens the kit's menu under this view while `isPresented` is true; picking a row, Esc or a click outside closes
  /// it. The content is the menu's rows: `Button`, `Toggle`, `Divider`, `KitMenuOptions`, `KitSubmenu`.
  ///
  /// ```swift
  /// Button("More", systemImage: "ellipsis") { showsMenu = true }
  ///   .kitMenu(isPresented: $showsMenu) {
  ///     Button("Rename…", systemImage: "pencil") { rename() }.kitMenuHint("↩")
  ///     Divider()
  ///     Button("Delete", systemImage: "trash", role: .destructive) { delete() }
  ///   }
  /// ```
  ///
  /// `matchesWidth` makes the menu at least as wide as this view (a pop-up's options under it).
  public func kitMenu<MenuContent: View>(
    isPresented: Binding<Bool>, matchesWidth: Bool = false, @ViewBuilder content: @escaping () -> MenuContent
  ) -> some View {
    modifier(KitMenuPresenter(isPresented: isPresented, matchesWidth: matchesWidth, menu: content))
  }

  /// The hint at the end of a menu row: a shortcut (`"⌘N"`), a number key, or `"↩"`.
  public func kitMenuHint(_ hint: String?) -> some View {
    environment(\.kitMenuHint, hint)
  }

  /// Draws a menu row highlighted, as under the pointer (mockups and previews of a `KitMenu`).
  public func kitMenuHighlighted(_ isHighlighted: Bool = true) -> some View {
    environment(\.kitMenuForcedHighlight, isHighlighted)
  }
}

extension EnvironmentValues {
  @Entry var kitMenuHint: String? = nil
  @Entry var kitMenuForcedHighlight: Bool = false
  @Entry var kitMenuModel: KitMenuModel? = nil
}

// MARK: - The card

/// The menu as drawn: the floating card with its rows. `.kitMenu(isPresented:)` presents one; draw it on its own for
/// a mockup or a preview (its rows still hover and run their actions).
///
/// ```swift
/// KitMenu {
///   Button("New Tab", systemImage: "plus.square") {}.kitMenuHint("⌘T").kitMenuHighlighted()
///   Button("Close", systemImage: "xmark") {}.kitMenuHint("⌘W")
/// }
/// ```
public struct KitMenu<Content: View>: View {
  var minWidth: CGFloat?
  var content: Content
  @State private var model = KitMenuModel()

  public init(minWidth: CGFloat? = nil, @ViewBuilder content: () -> Content) {
    self.minWidth = minWidth
    self.content = content()
  }

  public var body: some View {
    KitMenuCard(model: model, minWidth: minWidth) { content }
  }
}

/// The card around a model's rows.
struct KitMenuCard<Content: View>: View {
  let model: KitMenuModel
  var minWidth: CGFloat?
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    let metrics = KitMenuMetrics(idiom)
    VStack(alignment: .leading, spacing: metrics.rowGap) { content }
      .padding(metrics.cardPadding)
      .frame(minWidth: max(minWidth ?? 0, metrics.minWidth), alignment: .leading)
      .fixedSize()
      .coordinateSpace(name: KitMenuModel.space)
      .kitSurface(.floating, cornerRadius: metrics.cardRadius)
      .environment(\.kitMenuModel, model)
      .buttonStyle(KitMenuItemStyle())
      .toggleStyle(KitMenuToggleStyle())
      .labelStyle(KitMenuLabelStyle())
      .accessibilityElement(children: .contain)
      .accessibilityAddTraits(.isModal)
  }
}

struct KitMenuMetrics {
  var rowHeight: CGFloat
  var rowRadius: CGFloat
  var rowGap: CGFloat
  var rowPadding: CGFloat
  var cardPadding: CGFloat
  var cardRadius: CGFloat
  var font: CGFloat
  var hintFont: CGFloat
  var icon: CGFloat
  var iconGap: CGFloat
  var minWidth: CGFloat

  init(_ idiom: KitIdiom) {
    switch idiom {
    case .mac:
      (rowHeight, rowRadius, rowGap, rowPadding, cardPadding, cardRadius) = (26, 6, 1, 8, 5, KitMetrics.radiusLarge)
      (font, hintFont, icon, iconGap, minWidth) = (13, 12, 16, 8, 160)
    case .pad, .phone:
      (rowHeight, rowRadius, rowGap, rowPadding, cardPadding, cardRadius) = (44, 14, 2, 12, 6, KitMetrics.radiusOverlay)
      (font, hintFont, icon, iconGap, minWidth) = (idiom == .pad ? 15 : 17, 13, 20, 12, 250)
    }
  }
}

// MARK: - Model

/// One open menu: its rows (registered by the rows themselves, with where they sit and what they do), the
/// highlighted one, the open submenu, and how to close.
@MainActor @Observable
final class KitMenuModel {
  static let space = "kit.menu"

  struct Row {
    var y: CGFloat = 0
    var isEnabled = true
    var hasIcon = false
    var isSubmenu = false
    var trigger: () -> Void = {}
  }

  var highlighted: UUID?
  var openSubmenu: UUID?
  private(set) var rows: [UUID: Row] = [:]
  /// Some row has an icon, so every row keeps the icon column and the titles line up.
  var hasIconColumn: Bool { rows.values.contains { $0.hasIcon } }
  /// Closes the whole menu (a submenu's model closes its parent's).
  @ObservationIgnored var dismiss: () -> Void = {}

  func update(_ id: UUID, _ change: (inout Row) -> Void) {
    var row = rows[id] ?? Row()
    change(&row)
    rows[id] = row
  }

  func remove(_ id: UUID) {
    rows[id] = nil
    if highlighted == id { highlighted = nil }
  }

  /// Runs a row's action, then closes the menu, as a menu does.
  func perform(_ action: () -> Void) {
    action()
    dismiss()
  }

  /// ↑/↓: the next enabled row, top to bottom, wrapping.
  func move(by step: Int) {
    let order = rows.filter(\.value.isEnabled).sorted { $0.value.y < $1.value.y }.map(\.key)
    guard !order.isEmpty else { return }
    if let highlighted, let index = order.firstIndex(of: highlighted) {
      self.highlighted = order[(index + step + order.count) % order.count]
    } else {
      highlighted = step > 0 ? order.first : order.last
    }
  }

  /// Return: picks the highlighted row.
  func activate() {
    guard let highlighted, let row = rows[highlighted], row.isEnabled else { return }
    row.trigger()
  }

  /// → opens the highlighted submenu, ← closes it.
  func openHighlightedSubmenu(_ open: Bool) {
    if open, let highlighted, rows[highlighted]?.isSubmenu == true { openSubmenu = highlighted }
    if !open { openSubmenu = nil }
  }
}

// MARK: - Rows

/// A menu row: the icon column, the title, the hint (or a submenu's chevron), highlighted under the pointer.
struct KitMenuRow<Label: View>: View {
  var checked: Bool? = nil
  var role: ButtonRole? = nil
  var isSubmenu = false
  /// The row's id in its menu (a submenu passes its own, to know when it is open).
  var rowID: UUID? = nil
  var trigger: () -> Void
  @ViewBuilder var label: Label

  @Environment(\.kitMenuModel) private var model
  @Environment(\.kitMenuHint) private var hint
  @Environment(\.kitMenuForcedHighlight) private var forced
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitIdiom) private var idiom
  @State private var ownID = UUID()
  @State private var hasIcon = false

  private var id: UUID { rowID ?? ownID }
  private var isHighlighted: Bool { isEnabled && (forced || model?.highlighted == id) }

  var body: some View {
    let metrics = KitMenuMetrics(idiom)
    HStack(spacing: metrics.iconGap) {
      if let checked {
        Image(systemName: "checkmark")
          .font(.system(size: metrics.font * 0.85, weight: .semibold))
          .opacity(checked ? 1 : 0)
          .frame(width: metrics.icon)
          .accessibilityHidden(!checked)
      }
      if !hasIcon && model?.hasIconColumn == true && checked == nil {
        Color.clear.frame(width: metrics.icon, height: 1)
      }
      label
        .lineLimit(1)
        .onPreferenceChange(KitMenuHasIcon.self) { value in hasIcon = value }
      Spacer(minLength: 8)
      if let hint, !isSubmenu {
        Text(hint)
          .font(.system(size: metrics.hintFont))
          .foregroundStyle(isHighlighted ? AnyShapeStyle(Color.white.opacity(0.8)) : AnyShapeStyle(.kitTertiary))
      }
      if isSubmenu {
        Image(systemName: "chevron.right")
          .font(.system(size: metrics.font * 0.75, weight: .semibold))
          .foregroundStyle(isHighlighted ? AnyShapeStyle(Color.white.opacity(0.8)) : AnyShapeStyle(.kitSecondary))
      }
    }
    .font(.system(size: metrics.font))
    .foregroundStyle(titleStyle)
    .environment(\.kitMenuRowHighlighted, isHighlighted)
    .padding(.horizontal, metrics.rowPadding)
    .frame(height: metrics.rowHeight)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: metrics.rowRadius, style: .continuous)
        .fill(isHighlighted ? AnyShapeStyle(role == .destructive ? Hue.red.fill : Hue.accent.fill) : AnyShapeStyle(.clear))
    }
    .contentShape(Rectangle())
    .onHover { inside in hover(inside) }
    .onTapGesture { if isEnabled { trigger() } }
    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(KitMenuModel.space)).minY } action: { y in
      model?.update(id) { $0.y = y }
    }
    .onChange(of: isEnabled, initial: true) { register() }
    .onChange(of: hasIcon) { register() }
    .onDisappear { model?.remove(id) }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(checked == true ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction { if isEnabled { trigger() } }
    .zIndex(model?.openSubmenu == id ? 1 : 0)
  }

  private var titleStyle: AnyShapeStyle {
    if !isEnabled { return AnyShapeStyle(.kitTertiary) }
    if isHighlighted { return AnyShapeStyle(Color.white) }
    if role == .destructive { return AnyShapeStyle(Hue.red.text) }
    return AnyShapeStyle(.kitLabel)
  }

  private func register() {
    let trigger = trigger
    let isSubmenu = isSubmenu
    model?.update(id) { row in
      row.isEnabled = isEnabled
      row.hasIcon = hasIcon
      row.isSubmenu = isSubmenu
      row.trigger = trigger
    }
  }

  private func hover(_ inside: Bool) {
    guard let model, isEnabled else { return }
    if inside {
      model.highlighted = id
      // Another row of this menu closes its open submenu; this one opens its own.
      if isSubmenu { model.openSubmenu = id } else { model.openSubmenu = nil }
    } else if model.highlighted == id, model.openSubmenu != id {
      model.highlighted = nil
    }
  }
}

extension EnvironmentValues {
  @Entry var kitMenuRowHighlighted: Bool = false
}

struct KitMenuHasIcon: PreferenceKey {
  static let defaultValue = false
  static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

/// `Button` in a kit menu: a row that runs its action and closes the menu.
struct KitMenuItemStyle: PrimitiveButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    KitMenuItem(configuration: configuration)
  }
}

private struct KitMenuItem: View {
  let configuration: PrimitiveButtonStyleConfiguration
  @Environment(\.kitMenuModel) private var model

  var body: some View {
    KitMenuRow(role: configuration.role, trigger: { perform() }) { configuration.label }
  }

  private func perform() {
    if let model { model.perform { configuration.trigger() } } else { configuration.trigger() }
  }
}

/// `Toggle` in a kit menu: a row with a check, closing the menu as it flips.
struct KitMenuToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    KitMenuToggle(configuration: configuration)
  }
}

private struct KitMenuToggle: View {
  let configuration: ToggleStyleConfiguration
  @Environment(\.kitMenuModel) private var model

  var body: some View {
    KitMenuRow(checked: configuration.isOn, trigger: { flip() }) { configuration.label }
  }

  private func flip() {
    if let model { model.perform { configuration.isOn.toggle() } } else { configuration.isOn.toggle() }
  }
}

/// A `Label` in a menu row: the icon in the 16pt column (secondary, white on the highlight), then the title.
struct KitMenuLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    KitMenuLabel(configuration: configuration)
  }
}

private struct KitMenuLabel: View {
  let configuration: LabelStyleConfiguration
  @Environment(\.kitMenuRowHighlighted) private var isHighlighted
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    let metrics = KitMenuMetrics(idiom)
    HStack(spacing: metrics.iconGap) {
      configuration.icon
        .foregroundStyle(
          !isEnabled ? AnyShapeStyle(.kitTertiary) : isHighlighted ? AnyShapeStyle(Color.white) : AnyShapeStyle(.kitSecondary)
        )
        .frame(width: metrics.icon)
      configuration.title
    }
    .preference(key: KitMenuHasIcon.self, value: true)
  }
}

// MARK: - Options, submenus, footers

/// Rows that pick one value: the picked one checked; picking closes the menu. A pop-up's menu, or a group in a
/// bigger one.
///
/// ```swift
/// KitMenuButton("Sort", systemImage: "arrow.up.arrow.down") {
///   KitMenuOptions(selection: $sort, options: [("Name", .name), ("Date", .date)])
///   Divider()
///   Toggle("Folders First", isOn: $foldersFirst)
/// }
/// ```
public struct KitMenuOptions<Value: Hashable>: View {
  @Binding var selection: Value
  var segments: [KitSegment<Value>]
  @Environment(\.kitMenuModel) private var model

  /// Options with titles, values, optional glyphs; disabled ones can't be picked.
  public init(selection: Binding<Value>, segments: [KitSegment<Value>]) {
    _selection = selection
    self.segments = segments
  }

  /// Options as titled values.
  public init(selection: Binding<Value>, options: [(String, Value)]) {
    self.init(selection: selection, segments: options.map { KitSegment($0.0, value: $0.1) })
  }

  public var body: some View {
    ForEach(segments) { segment in
      KitMenuRow(checked: segment.value == selection, trigger: { pick(segment.value) }) {
        if let systemImage = segment.systemImage {
          Label(segment.title, systemImage: systemImage)
        } else {
          Text(segment.title)
        }
      }
      .disabled(!segment.isEnabled)
    }
  }

  private func pick(_ value: Value) {
    if let model { model.perform { selection = value } } else { selection = value }
  }
}

extension KitMenuOptions where Value: KitOption {
  /// Options titled (and given glyphs) by the options themselves.
  public init(selection: Binding<Value>, options: [Value]) {
    self.init(
      selection: selection, segments: options.map { KitSegment($0.title, value: $0, systemImage: $0.systemImage) })
  }
}

/// A row that opens a menu beside it (on hover, a click, or →): "Sort by ▸", "Open With ▸".
///
/// ```swift
/// KitSubmenu("Sort by", systemImage: "arrow.up.arrow.down") {
///   Button("Name") { sort(.name) }
///   Button("Date") { sort(.date) }
/// }
/// ```
public struct KitSubmenu<Content: View>: View {
  var title: String
  var systemImage: String?
  var content: Content
  @Environment(\.kitMenuModel) private var model
  @Environment(\.kitIdiom) private var idiom
  @State private var rowID = UUID()
  @State private var child = KitMenuModel()

  public init(_ title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  public var body: some View {
    let metrics = KitMenuMetrics(idiom)
    KitMenuRow(isSubmenu: true, rowID: rowID, trigger: { model?.openSubmenu = rowID }) {
      if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
    }
    .overlay(alignment: .topTrailing) {
      if model?.openSubmenu == rowID {
        KitMenuCard(model: child) { content }
          .alignmentGuide(.trailing) { $0[.leading] - metrics.cardPadding - 2 }
          .alignmentGuide(.top) { $0[.top] + metrics.cardPadding }
          .transition(.opacity)
          .onAppear { child.dismiss = { model?.dismiss() } }
      }
    }
  }
}

/// What the menu acts on, under a divider at its end: an icon tile, a title and a line.
///
/// ```swift
/// Divider()
/// KitMenuFooter("harbor.png", subtitle: "Dropped on prod-db", systemImage: "doc")
/// ```
public struct KitMenuFooter: View {
  var title: String
  var subtitle: String?
  var systemImage: String

  public init(_ title: String, subtitle: String? = nil, systemImage: String) {
    self.title = title
    self.subtitle = subtitle
    self.systemImage = systemImage
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: systemImage)
        .font(.system(size: 12))
        .foregroundStyle(.kitSecondary)
        .frame(width: 26, height: 26)
        .background(.kitFill, in: RoundedRectangle(cornerRadius: KitMetrics.radiusSmall, style: .continuous))
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1).truncationMode(.middle)
        if let subtitle {
          Text(subtitle).font(.system(size: 11)).foregroundStyle(.kitSecondary).lineLimit(1).truncationMode(.middle)
        }
      }
    }
    .padding(.horizontal, 8)
    .padding(.top, 8)
    .padding(.bottom, 6)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Presenting

struct KitMenuPresenter<MenuContent: View>: ViewModifier {
  @Binding var isPresented: Bool
  var matchesWidth: Bool
  var menu: () -> MenuContent
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.kitAccent) private var accent
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitIncreaseContrast) private var increaseContrast
  @Environment(\.layoutDirection) private var layoutDirection
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.locale) private var locale

  func body(content: Content) -> some View {
    #if canImport(AppKit) || canImport(UIKit)
      content.background {
        KitMenuAnchor(isPresented: $isPresented, menu: { model, anchor in AnyView(overlay(model, anchor)) })
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    #else
      content.popover(isPresented: $isPresented) {
        let model = KitMenuModel()
        KitMenuCard(model: model) { menu() }
          .onAppear { model.dismiss = { isPresented = false } }
      }
    #endif
  }

  /// The menu's floating root: the anchor's environment carried over, since it lives in its own window.
  private func overlay(_ model: KitMenuModel, _ anchor: CGRect) -> some View {
    KitMenuOverlay(model: model, anchor: anchor, matchesWidth: matchesWidth) { menu() }
      .environment(\.colorScheme, colorScheme)
      .environment(\.kitAccent, accent)
      .environment(\.kitIdiom, idiom)
      .environment(\.kitIncreaseContrast, increaseContrast)
      .environment(\.layoutDirection, layoutDirection)
      .environment(\.dynamicTypeSize, dynamicTypeSize)
      .environment(\.locale, locale)
      .font(KitFont.body.font)
      .foregroundStyle(.kitLabel)
  }
}

/// The menu window's whole content: a catcher that closes the menu on a click outside, and the card under the
/// anchor (above it when there's no room below), kept inside with an 8pt margin.
struct KitMenuOverlay<Content: View>: View {
  let model: KitMenuModel
  let anchor: CGRect
  var matchesWidth: Bool
  @ViewBuilder var content: Content
  @State private var size: CGSize?
  @State private var shown = false
  @FocusState private var isFocused: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let gap: CGFloat = 4
  private let margin: CGFloat = 8

  var body: some View {
    GeometryReader { proxy in
      let place = placement(in: proxy.size)
      ZStack(alignment: .topLeading) {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { model.dismiss() }
          .accessibilityHidden(true)
        KitMenuCard(model: model, minWidth: matchesWidth ? anchor.width : nil) { content }
          .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
          .scaleEffect(shown || reduceMotion ? 1 : 0.96, anchor: place.above ? .bottomLeading : .topLeading)
          .opacity(shown && size != nil ? 1 : 0)
          .offset(x: place.origin.x, y: place.origin.y)
      }
    }
    .ignoresSafeArea()
    .focusable()
    .focused($isFocused)
    .focusEffectDisabled()
    .onKeyPress(.escape) { model.dismiss(); return .handled }
    .onKeyPress(.upArrow) { model.move(by: -1); return .handled }
    .onKeyPress(.downArrow) { model.move(by: 1); return .handled }
    .onKeyPress(.rightArrow) { model.openHighlightedSubmenu(true); return .handled }
    .onKeyPress(.leftArrow) { model.openHighlightedSubmenu(false); return .handled }
    .onKeyPress(.return) { model.activate(); return .handled }
    .onAppear {
      isFocused = true
      withAnimation(.smooth(duration: 0.18)) { shown = true }
    }
  }

  private func placement(in bounds: CGSize) -> (origin: CGPoint, above: Bool) {
    let size = size ?? .zero
    let x = min(max(anchor.minX, margin), max(margin, bounds.width - size.width - margin))
    let below = anchor.maxY + gap
    if below + size.height + margin <= bounds.height || anchor.minY - gap - size.height < margin {
      return (CGPoint(x: x, y: min(below, max(margin, bounds.height - size.height - margin))), false)
    }
    return (CGPoint(x: x, y: anchor.minY - gap - size.height), true)
  }
}

// MARK: - Platform windows

#if canImport(AppKit)
  /// Sits behind the anchored view: finds its window and frame, and opens or closes the menu panel as
  /// `isPresented` changes (and refreshes it while open).
  struct KitMenuAnchor: NSViewRepresentable {
    @Binding var isPresented: Bool
    var menu: (KitMenuModel, CGRect) -> AnyView

    func makeCoordinator() -> KitMenuPanelController { KitMenuPanelController() }
    func makeNSView(context: Context) -> KitMenuAnchorView { KitMenuAnchorView() }

    func updateNSView(_ view: KitMenuAnchorView, context: Context) {
      let controller = context.coordinator
      controller.close = { isPresented = false }
      controller.menu = menu
      // A menu that starts open waits for the view to land in its window.
      view.movedToWindow = { [weak view] in if isPresented, let view { controller.show(from: view) } }
      if isPresented { controller.show(from: view) } else { controller.hide() }
    }

    static func dismantleNSView(_ view: KitMenuAnchorView, coordinator: KitMenuPanelController) {
      coordinator.hide()
    }
  }

  /// The menu's borderless panel, over the whole screen the anchor is on: it never becomes key (the window keeps
  /// its focus and look), takes the keys through a local monitor while open, and closes when the app goes inactive
  /// or the anchor's window moves, resizes or closes.
  @MainActor
  final class KitMenuPanelController {
    var close: () -> Void = {}
    var menu: (KitMenuModel, CGRect) -> AnyView = { _, _ in AnyView(EmptyView()) }
    private var panel: KitMenuPanel?
    private var host: NSHostingView<AnyView>?
    private var model: KitMenuModel?
    private weak var anchorView: NSView?
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []

    func show(from view: NSView) {
      anchorView = view
      guard let window = view.window, let screen = window.screen ?? NSScreen.main else { return }
      let model = self.model ?? KitMenuModel()
      model.dismiss = { [weak self] in self?.dismiss() }
      self.model = model
      let screenFrame = screen.frame
      let rect = window.convertToScreen(view.convert(view.bounds, to: nil))
      // The anchor in the panel's top-left coordinates.
      let anchor = CGRect(
        x: rect.minX - screenFrame.minX, y: screenFrame.maxY - rect.maxY, width: rect.width, height: rect.height)
      let root = menu(model, anchor)
      if let host {
        host.rootView = root
        return
      }
      let panel = KitMenuPanel(
        contentRect: screenFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hasShadow = false
      panel.level = .popUpMenu
      panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary, .moveToActiveSpace]
      panel.isReleasedWhenClosed = false
      panel.appearance = window.effectiveAppearance
      let host = NSHostingView(rootView: root)
      host.sizingOptions = []
      host.frame = CGRect(origin: .zero, size: screenFrame.size)
      host.autoresizingMask = [.width, .height]
      panel.contentView = host
      panel.setFrame(screenFrame, display: false)
      panel.orderFront(nil)
      self.panel = panel
      self.host = host
      watch(window)
    }

    func hide() {
      monitors.forEach(NSEvent.removeMonitor)
      monitors = []
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
      panel?.orderOut(nil)
      panel = nil
      host = nil
      model = nil
    }

    private func dismiss() {
      hide()
      close()
    }

    private func watch(_ window: NSWindow) {
      if let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
        let keyCode = event.keyCode
        let command = event.modifierFlags.contains(.command)
        let handled = MainActor.assumeIsolated { self?.handle(keyCode: keyCode, command: command) ?? false }
        return handled ? nil : event
      }) {
        monitors.append(keys)
      }
      let center = NotificationCenter.default
      let names: [(Notification.Name, AnyObject?)] = [
        (NSApplication.didResignActiveNotification, nil), (NSWindow.didMoveNotification, window),
        (NSWindow.didResizeNotification, window), (NSWindow.willCloseNotification, window),
      ]
      for (name, object) in names {
        observers.append(
          center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
          })
      }
    }

    /// The menu's keys; ⌘ shortcuts close it and go on to the app, as with a menu.
    private func handle(keyCode: UInt16, command: Bool) -> Bool {
      guard let model else { return false }
      if command {
        dismiss()
        return false
      }
      switch keyCode {
      case 126: model.move(by: -1)
      case 125: model.move(by: 1)
      case 124: model.openHighlightedSubmenu(true)
      case 123: model.openHighlightedSubmenu(false)
      case 36, 76, 49: model.activate()
      case 53: dismiss()
      default: break
      }
      return true
    }
  }

  final class KitMenuAnchorView: NSView {
    var movedToWindow: () -> Void = {}
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window != nil { DispatchQueue.main.async { [weak self] in self?.movedToWindow() } }
    }
  }

  final class KitMenuPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
  }

#elseif canImport(UIKit)
  /// Sits behind the anchored view: finds its window and frame, and opens or closes the menu window as
  /// `isPresented` changes (and refreshes it while open).
  struct KitMenuAnchor: UIViewRepresentable {
    @Binding var isPresented: Bool
    var menu: (KitMenuModel, CGRect) -> AnyView

    func makeCoordinator() -> KitMenuWindowController { KitMenuWindowController() }
    func makeUIView(context: Context) -> KitMenuAnchorView {
      let view = KitMenuAnchorView()
      view.isUserInteractionEnabled = false
      return view
    }

    func updateUIView(_ view: KitMenuAnchorView, context: Context) {
      let controller = context.coordinator
      controller.close = { isPresented = false }
      controller.menu = menu
      // A menu that starts open waits for the view to land in its window.
      view.movedToWindow = { [weak view] in if isPresented, let view { controller.show(from: view) } }
      if isPresented { controller.show(from: view) } else { controller.hide() }
    }

    static func dismantleUIView(_ view: KitMenuAnchorView, coordinator: KitMenuWindowController) {
      coordinator.hide()
    }
  }

  final class KitMenuAnchorView: UIView {
    var movedToWindow: () -> Void = {}
    override func didMoveToWindow() {
      super.didMoveToWindow()
      if window != nil { DispatchQueue.main.async { [weak self] in self?.movedToWindow() } }
    }
  }

  /// The menu's window above the scene: it takes the keys while open (↑/↓, Return, Esc on a hardware keyboard).
  @MainActor
  final class KitMenuWindowController {
    var close: () -> Void = {}
    var menu: (KitMenuModel, CGRect) -> AnyView = { _, _ in AnyView(EmptyView()) }
    private var window: UIWindow?
    private var host: UIHostingController<AnyView>?
    private var model: KitMenuModel?

    func show(from view: UIView) {
      guard let scene = view.window?.windowScene else { return }
      let model = self.model ?? KitMenuModel()
      model.dismiss = { [weak self] in self?.dismiss() }
      self.model = model
      let window = self.window ?? UIWindow(windowScene: scene)
      let anchor = view.convert(view.bounds, to: window)
      let root = menu(model, anchor)
      if let host {
        host.rootView = root
        return
      }
      let host = UIHostingController(rootView: root)
      host.view.backgroundColor = .clear
      window.windowLevel = .alert + 1
      window.backgroundColor = .clear
      window.rootViewController = host
      window.isHidden = false
      window.makeKey()
      self.window = window
      self.host = host
    }

    func hide() {
      window?.isHidden = true
      window = nil
      host = nil
      model = nil
    }

    private func dismiss() {
      hide()
      close()
    }
  }
#endif
