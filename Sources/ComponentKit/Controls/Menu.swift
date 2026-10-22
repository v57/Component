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
// sheets and can run past the window's edge), on iPad and iPhone in a window above the scene. `.kitMenu { }` makes a
// view its trigger, as a pop-up button: the menu opens on mouse or touch down, and releasing over a row picks it in
// the same gesture (a quick click leaves the menu open to pick with a second click). A click outside closes it (and
// is swallowed, as a menu's is), as do Esc, picking a row, the pointer moving away (on the Mac the menu shrinks and
// fades from 50pt away and closes at 100pt), and focus leaving the window or the app (on the Mac, as a system menu
// does; on iPad and iPhone only as the app goes to the background, as a popover stays over Control Center or an
// alert). ↑/↓ move the highlight, → opens a submenu, Return picks. A menu taller than its window scrolls; on iOS it
// leaves the keyboard with a text view that has it.

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
  ///
  /// In a system toolbar (`.toolbar`, iOS 26 on), SwiftUI turns a bare `Button` into a native bar button and drops
  /// the modifiers that anchor the menu, so nothing opens: give the item a kit view (`ToolGroup { … }`, a
  /// `KitMenuButton`), ideally in a `KitToolbarItem`. The kit's own toolbar (`.kitToolbar`) hosts its views as they are.
  public func kitMenu<MenuContent: View>(
    isPresented: Binding<Bool>, matchesWidth: Bool = false, @ViewBuilder content: @escaping () -> MenuContent
  ) -> some View {
    modifier(KitMenuPresenter(binding: isPresented, kind: .attached, matchesWidth: matchesWidth, menu: content))
  }

  /// The view's context menu, drawn by the kit, as `.contextMenu` opens the system's: a secondary click (right-click
  /// or Control-click) on the Mac opens it at the pointer, a long press on iPad and iPhone opens it at the finger
  /// (with a tap of haptics and a dim behind). Holding on, the pointer or finger highlights the row under it and
  /// letting go there picks it; letting go anywhere else on the view leaves the menu open to pick with a click or a
  /// tap. VoiceOver's actions include Show Menu.
  ///
  /// ```swift
  /// FileRow(file)
  ///   .kitContextMenu {
  ///     Button("Open", systemImage: "arrow.up.right.square") { open(file) }
  ///     Button("Copy Path", systemImage: "doc.on.doc") { copy(file.path) }
  ///     Divider()
  ///     Button("Move to Trash", systemImage: "trash", role: .destructive) { trash(file) }
  ///   }
  /// ```
  public func kitContextMenu<MenuContent: View>(@ViewBuilder content: @escaping () -> MenuContent) -> some View {
    modifier(KitMenuPresenter(binding: nil, kind: .context, matchesWidth: false, menu: content))
  }

  /// Makes this view a menu's trigger, as a pop-up button: pressing it opens the kit's menu under it, and releasing
  /// over a row picks that row in the same gesture; a quick click leaves the menu open, and pressing again closes
  /// it. Space, Return or ↓ open it from the keyboard when the view has focus.
  ///
  /// ```swift
  /// Label("TripStore.swift", systemImage: "swift")
  ///   .kitMenu {
  ///     Button("Open") { open() }
  ///     Button("Copy Path") { copyPath() }
  ///   }
  /// ```
  public func kitMenu<MenuContent: View>(
    matchesWidth: Bool = false, @ViewBuilder content: @escaping () -> MenuContent
  ) -> some View {
    modifier(KitMenuPresenter(binding: nil, kind: .trigger, matchesWidth: matchesWidth, menu: content))
  }

  /// A trigger whose open state the caller also reads (a pop-up drawn pressed while its menu is open).
  func kitMenuTrigger<MenuContent: View>(
    isPresented: Binding<Bool>, matchesWidth: Bool = false, @ViewBuilder content: @escaping () -> MenuContent
  ) -> some View {
    modifier(KitMenuPresenter(binding: isPresented, kind: .trigger, matchesWidth: matchesWidth, menu: content))
  }

  /// The hint at the end of a menu row: a shortcut (`"⌘N"`), a number key, or `"↩"`.
  public func kitMenuHint(_ hint: String?) -> some View {
    environment(\.kitMenuHint, hint)
  }

  /// Draws a menu row highlighted, as under the pointer (mockups and previews of a `KitMenu`); a highlighted
  /// `KitSubmenu` shows its menu.
  public func kitMenuHighlighted(_ isHighlighted: Bool = true) -> some View {
    environment(\.kitMenuForcedHighlight, isHighlighted)
  }
}

extension EnvironmentValues {
  @Entry var kitMenuHint: String? = nil
  @Entry var kitMenuForcedHighlight: Bool = false
  @Entry var kitMenuModel: KitMenuModel? = nil
  /// The size of the menu's window (submenus open on the side that has room).
  @Entry var kitMenuBounds: CGSize? = nil
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

/// A submenu row's frame in the menu's space, read when the submenu opens.
final class KitMenuRowGeometry {
  var frame: CGRect = .zero
}

/// The card around a model's rows.
struct KitMenuCard<Content: View>: View {
  let model: KitMenuModel
  var minWidth: CGFloat?
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitMenuBounds) private var bounds
  /// The rows' size, for the scroll view a menu taller than its window scrolls in.
  @State private var rowsSize: CGSize = .zero

  /// The margin a menu keeps from its window's edges.
  static var margin: CGFloat { 8 }

  var body: some View {
    let metrics = KitMenuMetrics(idiom)
    let rows = VStack(alignment: .leading, spacing: metrics.rowGap) { content }
      .padding(metrics.cardPadding)
      .frame(minWidth: max(minWidth ?? 0, metrics.minWidth), alignment: .leading)
      .fixedSize()
      .onGeometryChange(for: CGSize.self) { $0.size } action: { rowsSize = $0 }
    // Taller than its window (a long list of branches), it scrolls; the rows still measure themselves in the menu's
    // space, so the pointer and the keys find them where they scrolled to.
    let limit = bounds.map { $0.height - 2 * Self.margin } ?? .infinity
    Group {
      if rowsSize.height > limit {
        ScrollView(.vertical) { rows }
          .frame(width: rowsSize.width, height: limit)
          .scrollIndicators(.automatic)
          .clipShape(RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous))
      } else {
        rows
      }
    }
      .kitSurface(.floating, cornerRadius: metrics.cardRadius)
      // Open submenus lie over the card, outside its scroll view (which would clip them), each beside its row.
      .overlayPreferenceValue(KitSubmenuCards.self, alignment: .topLeading) { cards in
        GeometryReader { proxy in
          ForEach(cards) { card in
            let row = proxy[card.row]
            card.view.offset(x: row.minX + card.offset.width, y: row.minY + card.offset.height)
          }
        }
      }
      .transformPreference(KitSubmenuCards.self) { $0 = [] }
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(KitMenuModel.space)) } action: { frame in
        model.cardFrame = frame
      }
      .environment(\.kitMenuModel, model)
      .buttonStyle(KitMenuItemStyle())
      .toggleStyle(KitMenuToggleStyle())
      .labelStyle(KitMenuLabelStyle())
      .accessibilityElement(children: .contain)
      .accessibilityAddTraits(.isModal)
  }
}

/// The open submenus of a card's rows, drawn by the card over itself (see `KitMenuCard`).
struct KitSubmenuCards: PreferenceKey {
  struct Card: Identifiable {
    var id: UUID
    /// The submenu's row, which the card sits beside.
    var row: Anchor<CGRect>
    /// Where the card sits from the row's top-left corner.
    var offset: CGSize
    var view: AnyView
  }

  static var defaultValue: [Card] { [] }
  static func reduce(value: inout [Card], nextValue: () -> [Card]) { value += nextValue() }
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
/// highlighted one, the open submenu and its model, where the card and the anchor are, and how to close.
@MainActor @Observable
final class KitMenuModel {
  /// The menu window's coordinate space: rows, cards and the anchor are all measured in it.
  static let space = "kit.menu.root"

  struct Row {
    var isEnabled = true
    var hasIcon = false
    /// The row has the check column (a toggle, an option).
    var hasCheck = false
    var isSubmenu = false
    var trigger: () -> Void = {}
  }

  var highlighted: UUID?
  /// How far the pointer has strayed toward closing the menu: 0 near it, 1 at the edge of closing. The menu
  /// shrinks (to 80%) and fades (to 50%) with it.
  var fade: Double = 0
  /// The menu is on its way out (it strayed too far): it shrinks and fades away before its window goes.
  var isClosing = false
  var openSubmenu: UUID?
  private(set) var rows: [UUID: Row] = [:]
  /// Where each row sits, apart from `rows` and unobserved: a menu shown in a page (not in its window) measures its
  /// rows in the window's space, which moves on every frame of a scroll, and every row reads `rows`.
  @ObservationIgnored private var frames: [UUID: CGRect] = [:]
  /// Some row has an icon, so every row keeps the icon column and the titles line up.
  var hasIconColumn: Bool { rows.values.contains { $0.hasIcon } }
  /// Some row has a check column (section headers line up with the titles after it).
  var hasCheckColumn: Bool { rows.values.contains { $0.hasCheck } }
  /// The card, and the view the menu opened from, in the menu window's space.
  @ObservationIgnored var cardFrame: CGRect = .zero
  @ObservationIgnored var anchor: CGRect = .zero
  /// The view that opened the menu (for a pop-up, the same as the anchor; for a context menu, the anchor is the
  /// point that was clicked or pressed on it).
  @ObservationIgnored var trigger: CGRect = .zero
  /// A context menu: it opens at a point (and on touch, over a dim).
  @ObservationIgnored var isContext = false
  /// The open submenu's model (a submenu's parent is the menu it opens from).
  @ObservationIgnored var child: KitMenuModel?
  @ObservationIgnored weak var parent: KitMenuModel?
  /// Closes the whole menu (a submenu's model closes its parent's).
  @ObservationIgnored var dismiss: () -> Void = {}
  /// Closes the whole menu, then shares `items` from where it opened (`KitMenuShare`).
  @ObservationIgnored var share: (([Any]) -> Void)?
  /// The menu took the keys (its window is key): on iOS it doesn't while a text view has the keyboard.
  @ObservationIgnored var takesKeys = true

  func update(_ id: UUID, _ change: (inout Row) -> Void) {
    var row = rows[id] ?? Row()
    change(&row)
    rows[id] = row
  }

  func setFrame(_ id: UUID, _ frame: CGRect) {
    frames[id] = frame
  }

  func remove(_ id: UUID) {
    rows[id] = nil
    frames[id] = nil
    if highlighted == id { highlighted = nil }
  }

  /// Runs a row's action, then closes the menu, as a menu does.
  func perform(_ action: () -> Void) {
    action()
    dismiss()
  }

  /// Highlights a row (the pointer is over it): a submenu row opens its submenu, another row closes it.
  func highlight(_ id: UUID) {
    guard rows[id]?.isEnabled == true else { return }
    highlighted = id
    openSubmenu = rows[id]?.isSubmenu == true ? id : nil
  }

  /// The row under `point`, in this menu or its open submenu (which lies on top).
  func row(at point: CGPoint) -> (menu: KitMenuModel, id: UUID)? {
    if openSubmenu != nil, let child, let hit = child.row(at: point) { return hit }
    guard let id = rows.first(where: { frames[$0.key]?.contains(point) == true })?.key else { return nil }
    return (self, id)
  }

  /// The cards on screen: this one and its open submenus.
  var cardFrames: [CGRect] {
    [cardFrame] + (openSubmenu != nil ? child?.cardFrames ?? [] : [])
  }

  /// ↑/↓: the next enabled row, top to bottom, wrapping.
  func move(by step: Int) {
    let order = rows.filter(\.value.isEnabled).sorted { (frames[$0.key]?.minY ?? 0) < (frames[$1.key]?.minY ?? 0) }
      .map(\.key)
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
  /// An open touch submenu's first row: its title in bold with a down chevron; picking it folds the submenu.
  var isHeader = false
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
        .fontWeight(isHeader ? .semibold : nil)
        .onPreferenceChange(KitMenuHasIcon.self) { value in hasIcon = value }
      Spacer(minLength: 8)
      if let hint, !isSubmenu {
        Text(Self.textPresentation(hint))
          .font(.system(size: metrics.hintFont))
          .foregroundStyle(isHighlighted ? AnyShapeStyle(Color.white.opacity(0.8)) : AnyShapeStyle(.kitTertiary))
      }
      if isSubmenu || isHeader {
        Image(systemName: isHeader ? "chevron.down" : "chevron.right")
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
    .kitHover { inside in hover(inside) }
    .onTapGesture { if isEnabled { trigger() } }
    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(KitMenuModel.space)) } action: { frame in
      model?.setFrame(id, frame)
    }
    .onChange(of: isEnabled, initial: true) { register() }
    .onChange(of: hasIcon) { register() }
    .onDisappear { model?.remove(id) }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(checked == true ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction { if isEnabled { trigger() } }
    // On touch an open submenu covers its menu, whose other rows fade behind it.
    .opacity(idiom.isTouch && model?.openSubmenu != nil && model?.openSubmenu != id ? 0.3 : 1)
    .zIndex(model?.openSubmenu == id ? 1 : 0)
  }

  /// Symbols such as ↩ draw as emoji on iOS unless asked for their text form.
  static func textPresentation(_ hint: String) -> String {
    var scalars = String.UnicodeScalarView()
    for scalar in hint.unicodeScalars {
      scalars.append(scalar)
      if scalar.properties.isEmoji && !scalar.properties.isEmojiPresentation && !scalar.isASCII {
        scalars.append("\u{FE0E}")
      }
    }
    return String(scalars)
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
    let hasCheck = checked != nil
    model?.update(id) { row in
      row.isEnabled = isEnabled
      row.hasIcon = hasIcon
      row.hasCheck = hasCheck
      row.isSubmenu = isSubmenu
      row.trigger = trigger
    }
  }

  private func hover(_ inside: Bool) {
    guard let model, isEnabled else { return }
    if inside {
      model.highlight(id)
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
  @Environment(\.kitMenuBounds) private var bounds
  @Environment(\.kitMenuForcedHighlight) private var forced
  @Environment(\.kitIdiom) private var idiom
  @State private var rowID = UUID()
  @State private var child = KitMenuModel()
  /// The row's frame, in a box: kept out of state, it doesn't draw the row again on every frame of a scroll.
  @State private var rowGeometry = KitMenuRowGeometry()
  @State private var childSize: CGSize = .zero

  public init(_ title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  private var isOpen: Bool { forced || model?.openSubmenu == rowID }

  public var body: some View {
    let metrics = KitMenuMetrics(idiom)
    KitMenuRow(isSubmenu: true, rowID: rowID, trigger: { model?.openSubmenu = rowID }) {
      if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
    }
    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(KitMenuModel.space)) } action: { [rowGeometry] in
      rowGeometry.frame = $0
    }
    // Drawn by the card the row is in, over the card (a scrolling card would clip it).
    .anchorPreference(key: KitSubmenuCards.self, value: .bounds) { row in
      guard isOpen else { return [] }
      return [KitSubmenuCards.Card(id: rowID, row: row, offset: offset, view: AnyView(card(metrics)))]
    }
  }

  private func card(_ metrics: KitMenuMetrics) -> some View {
    KitMenuCard(model: child, minWidth: idiom.isTouch ? rowGeometry.frame.width + 2 * metrics.cardPadding + 8 : nil) {
      if idiom.isTouch {
        // As iOS: the submenu stacks over its menu from this row, headed by its title, which folds it.
        KitMenuRow(isHeader: true, trigger: { model?.openSubmenu = nil }) {
          if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
        }
        Divider()
      }
      content
    }
    .onGeometryChange(for: CGSize.self) { $0.size } action: { childSize = $0 }
    .environment(\.kitMenuForcedHighlight, false)
    .transition(.opacity)
    .onAppear {
      child.parent = model
      child.dismiss = { model?.dismiss() }
      child.share = { model?.share?($0) }
      model?.child = child
    }
  }

  /// Beside the row, its first row level with this one: on the trailing side, or the leading side when the
  /// trailing one has no room; on touch, over the menu from this row, a little wider. Lifted to stay on screen.
  private var offset: CGSize {
    let metrics = KitMenuMetrics(idiom)
    if idiom.isTouch {
      var x = -metrics.cardPadding - 4
      var y = -metrics.cardPadding - 4
      if let bounds {
        // Wider than its menu, it stays on screen (a menu at the window's edge, the toolbar's "…").
        let row = rowGeometry.frame
        x = min(x, bounds.width - 8 - childSize.width - row.minX)
        x = max(x, 8 - row.minX)
        if row.minY + y + childSize.height > bounds.height - 8 { y = bounds.height - 8 - childSize.height - row.minY }
      }
      return CGSize(width: x, height: y)
    }
    let gap = metrics.cardPadding + 2
    let trailing = rowGeometry.frame.width + gap
    var x = trailing
    if let bounds, rowGeometry.frame.maxX + gap + childSize.width > bounds.width - 8 {
      x = -childSize.width - gap
    }
    var y = -metrics.cardPadding
    if let bounds, rowGeometry.frame.minY + y + childSize.height > bounds.height - 8 {
      y = bounds.height - 8 - childSize.height - rowGeometry.frame.minY
    }
    return CGSize(width: x, height: y)
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

/// A group of rows under a small header, as a menu's sections ("Remote Branches", "Cloud"). Divide sections with a
/// `Divider()`.
///
/// ```swift
/// KitMenuSection("Local") { ForEach(local) { branch in Button(branch.name) { merge(branch) } } }
/// Divider()
/// KitMenuSection("Remote") { ForEach(remote) { branch in Button(branch.name) { merge(branch) } } }
/// ```
public struct KitMenuSection<Content: View>: View {
  var title: String
  var content: Content

  public init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  public var body: some View {
    KitMenuSectionHeader(title: title)
    content
  }
}

/// A section's header: its title in small semibold type, lined up with the rows' titles.
struct KitMenuSectionHeader: View {
  var title: String
  @Environment(\.kitMenuModel) private var model
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    let metrics = KitMenuMetrics(idiom)
    let columns = (model?.hasCheckColumn == true ? 1 : 0) + (model?.hasIconColumn == true ? 1 : 0)
    Text(title)
      .font(.system(size: metrics.hintFont, weight: .semibold))
      .foregroundStyle(.kitSecondary)
      .lineLimit(1)
      .padding(.leading, metrics.rowPadding + CGFloat(columns) * (metrics.icon + metrics.iconGap))
      .padding(.trailing, metrics.rowPadding)
      .padding(.top, idiom.isTouch ? 10 : 4)
      .padding(.bottom, idiom.isTouch ? 4 : 1)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityAddTraits(.isHeader)
  }
}

/// A row that shares `items` (URLs, text, images) with the system's share sheet, once the menu has closed (a
/// `ShareLink` in a menu goes with it): from the view the menu opened from, as a share button would. `prepare`
/// makes the items only when the row is picked (a temporary copy written just for sharing); empty, nothing opens.
///
/// ```swift
/// .kitContextMenu {
///   Button("Open", systemImage: "arrow.up.right.square") { open(note) }
///   KitMenuShare(items: [note.url])
/// }
/// KitMenuShare("Share a Copy…") { [try? exportCopy()].compactMap { $0 } }
/// ```
public struct KitMenuShare: View {
  var title: String
  var systemImage: String
  var items: () -> [Any]
  @Environment(\.kitMenuModel) private var model

  public init(_ title: String = "Share…", systemImage: String = "square.and.arrow.up", items: [Any]) {
    self.init(title, systemImage: systemImage) { items }
  }

  /// A row whose items `prepare` makes when it is picked.
  public init(_ title: String = "Share…", systemImage: String = "square.and.arrow.up", prepare: @escaping () -> [Any]) {
    self.title = title
    self.systemImage = systemImage
    self.items = prepare
  }

  public var body: some View {
    KitMenuRow(trigger: share) { Label(title, systemImage: systemImage) }
  }

  private func share() {
    let items = items()
    if let share = model?.share, !items.isEmpty { share(items) } else { model?.dismiss() }
  }
}

// MARK: - Presenting



enum KitMenuKind {
  /// Opened from code (`.kitMenu(isPresented:)`).
  case attached
  /// The view is a pop-up's trigger: press opens, release picks.
  case trigger
  /// The view's context menu: a secondary click or a long press opens it at that point.
  case context
}

/// A context menu gesture's phases, from the platform's events.
enum KitContextPhase {
  case began, changed, ended, cancelled
  /// The press became a drag (touch: the view is also a drag source): the menu closes and the drag goes on.
  case dragged
}

struct KitMenuPresenter<MenuContent: View>: ViewModifier {
  /// The open state, when the caller holds it (otherwise the presenter does).
  var binding: Binding<Bool>?
  var kind: KitMenuKind
  var matchesWidth: Bool
  var menu: () -> MenuContent
  @State private var ownIsOpen = false
  @State private var session = KitMenuSession()
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.kitAccent) private var accent
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitIncreaseContrast) private var increaseContrast
  @Environment(\.layoutDirection) private var layoutDirection
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.locale) private var locale
  @Environment(\.isEnabled) private var isEnabled

  private var isPresented: Binding<Bool> { binding ?? $ownIsOpen }

  func body(content: Content) -> some View {
    #if canImport(AppKit)
      if kind == .context {
        // On the Mac the anchor of a context menu is also the view over it that takes secondary clicks: one view
        // per row (a grid's, a diff's lines) rather than two.
        content
          .overlay { anchor(catchesClicks: true).accessibilityHidden(true) }
          .accessibilityAction(named: Text("Show Menu")) { session.showContext(isPresented: isPresented) }
      } else {
        Group {
          if kind == .trigger { trigger(content) } else { content }
        }
        .background { anchor(catchesClicks: false).allowsHitTesting(false).accessibilityHidden(true) }
      }
    #elseif canImport(UIKit) && !os(tvOS)
      Group {
        switch kind {
        case .attached: content
        case .trigger: trigger(content)
        case .context:
          content.accessibilityAction(named: Text("Show Menu")) { session.showContext(isPresented: isPresented) }
        }
      }
      .background { anchor().allowsHitTesting(false).accessibilityHidden(true) }
    #else
      Group {
        if kind == .attached { content } else { content.onTapGesture { isPresented.wrappedValue = true } }
      }
      .popover(isPresented: isPresented) {
        let model = KitMenuModel()
        KitMenuCard(model: model) { menu() }
          .onAppear { model.dismiss = { isPresented.wrappedValue = false } }
      }
    #endif
  }

  #if !os(tvOS)
  /// The trigger: one gesture from press to release. The press opens the menu (or closes it when it is open), the
  /// pointer highlights the row under it, and the release picks that row; a release on the trigger itself leaves
  /// the menu open.
  private func trigger(_ content: Content) -> some View {
    content
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            guard isEnabled else { return }
            if !session.isPressing {
              session.isPressing = true
              session.pressCloses = isPresented.wrappedValue
              session.contextPoint = nil
              isPresented.wrappedValue.toggle()
            } else if !session.pressCloses {
              session.track(value.location)
            }
          }
          .onEnded { value in
            session.isPressing = false
            if session.pressCloses {
              session.pressCloses = false
            } else if isEnabled {
              session.release(value.location, pressedAt: value.startLocation)
            }
          },
        including: isEnabled ? .all : .subviews
      )
      .onKeyPress(keys: [.space, .return, .downArrow]) { _ in
        guard isEnabled, !isPresented.wrappedValue else { return .ignored }
        isPresented.wrappedValue = true
        return .handled
      }
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { if isEnabled { isPresented.wrappedValue.toggle() } }
  }
  #endif

  #if canImport(AppKit)
    /// The view that finds the window and the frame the menu opens from; for a context menu it also takes the
    /// secondary clicks over the view (and nothing else).
    private func anchor(catchesClicks: Bool) -> KitMenuAnchor {
      let session = session
      let isPresented = isPresented
      let isEnabled = isEnabled
      return KitMenuAnchor(
        session: session, isPresented: isPresented, isContext: kind == .context,
        onContext: catchesClicks
          ? { phase, point in
            guard isEnabled else { return }
            session.context(phase, at: point, isPresented: isPresented)
          } : nil,
        menu: { model, anchor in AnyView(overlay(model, anchor)) })
    }
  #elseif canImport(UIKit) && !os(tvOS)
    /// The view that finds the window and the frame the menu opens from; on touch a context menu's long press is its.
    private func anchor() -> KitMenuAnchor {
      KitMenuAnchor(
        session: session, isPresented: isPresented, isContext: kind == .context,
        menu: { model, anchor in AnyView(overlay(model, anchor)) })
    }
  #endif

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

/// A trigger's press, and the menu it opened: where the pointer is during the press, mapped into the menu's
/// window (the trigger's origin plus the pointer's place on it).
@MainActor
final class KitMenuSession {
  #if canImport(UIKit) && !os(macOS) && !os(tvOS)
    static let isTouch = true
  #else
    static let isTouch = false
  #endif

  var isPressing = false
  /// This press began on an open menu, so it closes it and picks nothing.
  var pressCloses = false
  #if canImport(AppKit)
    let controller = KitMenuPanelController()
  #elseif canImport(UIKit) && !os(tvOS)
    let controller = KitMenuWindowController()
  #endif

  init() {
    #if canImport(AppKit) || (canImport(UIKit) && !os(tvOS))
      controller.isTracking = { [weak self] in self?.isPressing == true }
    #endif
  }

  private var model: KitMenuModel? {
    #if canImport(AppKit) || (canImport(UIKit) && !os(tvOS))
      controller.model
    #else
      nil
    #endif
  }

  /// Where a context menu opens on the view (its top-left coordinates); `nil` for a pop-up under it.
  var contextPoint: CGPoint?

  private func point(_ local: CGPoint) -> CGPoint? {
    guard let model else { return nil }
    return CGPoint(x: model.trigger.minX + local.x, y: model.trigger.minY + local.y)
  }

  /// A secondary click or a long press on a context menu's view, from press to release.
  func context(_ phase: KitContextPhase, at local: CGPoint, isPresented: Binding<Bool>) {
    switch phase {
    case .began:
      contextPoint = local
      isPressing = true
      pressCloses = false
      isPresented.wrappedValue = true
    case .changed:
      track(local)
    case .ended:
      isPressing = false
      release(local)
    case .cancelled:
      isPressing = false
    case .dragged:
      isPressing = false
      model?.dismiss()
    }
  }

  /// VoiceOver's Show Menu: the menu under the view, as a pop-up's.
  func showContext(isPresented: Binding<Bool>) {
    contextPoint = nil
    isPresented.wrappedValue = true
  }

  /// The pointer moved during the press: highlight the row under it.
  func track(_ local: CGPoint) {
    guard let model, let point = point(local) else { return }
    if let hit = model.row(at: point) { hit.menu.highlight(hit.id) }
  }

  /// The press ended: pick the row under the pointer, leave the menu open on the trigger, close it anywhere else.
  /// A trigger's click (released where it was pressed) only opens it, even when the menu lies over the trigger.
  func release(_ local: CGPoint, pressedAt start: CGPoint? = nil) {
    guard let model, let point = point(local) else { return }
    if let start, hypot(local.x - start.x, local.y - start.y) < 4, model.trigger.contains(point) { return }
    if let hit = model.row(at: point), let row = hit.menu.rows[hit.id], row.isEnabled {
      if !row.isSubmenu { row.trigger() }
    } else if model.isContext && Self.isTouch {
      // A finger lifted off a context menu leaves it open, as the system's does.
    } else if !model.trigger.contains(point), !model.cardFrames.contains(where: { $0.contains(point) }) {
      model.dismiss()
    }
  }
}

/// The ground behind a menu, with a hole over `cutout` (the view a touch context menu came from).
struct KitMenuDim: Shape {
  var cutout: CGRect?

  func path(in rect: CGRect) -> Path {
    var path = Path(rect)
    if let cutout {
      path.addPath(Path(roundedRect: cutout, cornerRadius: KitMetrics.radiusCard, style: .continuous))
    }
    return path
  }
}

/// The menu window's whole content: a catcher that closes the menu on a tap outside, and the card under the
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
  @Environment(\.kitIdiom) private var idiom

  private let gap: CGFloat = 4
  private let margin: CGFloat = 8

  var body: some View {
    GeometryReader { proxy in
      let place = placement(in: proxy.size)
      ZStack(alignment: .topLeading) {
        // On touch a context menu dims everything but its view, which stays bright as the system's lifts it.
        KitMenuDim(cutout: model.isContext && idiom.isTouch ? model.trigger : nil)
          .fill(model.isContext && idiom.isTouch ? AnyShapeStyle(.kitScrim) : AnyShapeStyle(.clear), style: FillStyle(eoFill: true))
          .opacity(shown && !model.isClosing ? 1 : 0)
          .contentShape(Rectangle())
          .onTapGesture { model.dismiss() }
          .accessibilityHidden(true)
        KitMenuCard(model: model, minWidth: matchesWidth ? anchor.width : nil) { content }
          .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
          .scaleEffect(scale)
          .opacity(model.isClosing ? 0 : (shown && size != nil ? 1 : 0) * (1 - 0.5 * model.fade))
          .offset(x: place.origin.x, y: place.origin.y)
      }
      .coordinateSpace(name: KitMenuModel.space)
      .environment(\.kitMenuBounds, proxy.size)
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
      model.anchor = anchor
      isFocused = model.takesKeys
      withAnimation(.smooth(duration: 0.18)) { shown = true }
    }
    .onChange(of: anchor) { model.anchor = anchor }
  }

  /// Opening grows it in from 96%; straying shrinks it toward 80%; closing takes it on down as it fades.
  private var scale: CGFloat {
    if reduceMotion { return 1 }
    if model.isClosing { return 0.7 }
    return (shown ? 1 : 0.96) * (1 - 0.2 * model.fade)
  }

  private func placement(in bounds: CGSize) -> (origin: CGPoint, above: Bool) {
    let size = size ?? .zero
    if model.isContext && idiom.isTouch {
      // On touch, as the system's: beside the pressed view, not over it (the finger and the view stay clear):
      // under it, starting at the finger, or above it when there's no room below.
      let trigger = model.trigger
      // iPhone centres it on the view; iPad starts it at the finger.
      let start = idiom == .phone ? trigger.midX - size.width / 2 : anchor.minX
      let x = min(max(start, margin), max(margin, bounds.width - size.width - margin))
      if trigger.maxY + margin + size.height <= bounds.height - margin {
        return (CGPoint(x: x, y: trigger.maxY + margin), false)
      }
      if trigger.minY - margin - size.height >= margin {
        return (CGPoint(x: x, y: trigger.minY - margin - size.height), true)
      }
    }
    if model.isContext {
      // At the point, its top-left corner just past it; flipped left or up when it would run off the edge.
      var x = anchor.minX + 1
      var y = anchor.minY + 1
      if x + size.width > bounds.width - margin { x = anchor.minX - size.width - 1 }
      if y + size.height > bounds.height - margin { y = anchor.minY - size.height - 1 }
      x = min(max(x, margin), max(margin, bounds.width - size.width - margin))
      y = min(max(y, margin), max(margin, bounds.height - size.height - margin))
      return (CGPoint(x: x, y: y), y < anchor.minY)
    }
    return Self.popUpPlacement(anchor: anchor, size: size, in: bounds, gap: gap, margin: margin)
  }

  /// A pop-up's place: under the anchor, above it when there's no room below, and beside it when there's room
  /// for neither (a long list of providers), so the press that opened it isn't over a row its release would pick:
  /// on the trailing side, or the leading one when the trailing has no room. Kept `margin` inside `bounds`.
  static func popUpPlacement(
    anchor: CGRect, size: CGSize, in bounds: CGSize, gap: CGFloat, margin: CGFloat
  ) -> (origin: CGPoint, above: Bool) {
    let x = min(max(anchor.minX, margin), max(margin, bounds.width - size.width - margin))
    let below = anchor.maxY + gap
    if below + size.height + margin <= bounds.height {
      return (CGPoint(x: x, y: below), false)
    }
    if anchor.minY - gap - size.height >= margin {
      return (CGPoint(x: x, y: anchor.minY - gap - size.height), true)
    }
    let y = min(max(anchor.minY, margin), max(margin, bounds.height - size.height - margin))
    if anchor.maxX + gap + size.width + margin <= bounds.width {
      return (CGPoint(x: anchor.maxX + gap, y: y), false)
    }
    if anchor.minX - gap - size.width >= margin {
      return (CGPoint(x: anchor.minX - gap - size.width, y: y), false)
    }
    return (CGPoint(x: x, y: min(below, max(margin, bounds.height - size.height - margin))), false)
  }
}

// MARK: - Platform windows

#if canImport(AppKit)
  /// Sits behind the anchored view: finds its window and frame, and opens or closes the menu panel as
  /// `isPresented` changes (and refreshes it while open).
  struct KitMenuAnchor: NSViewRepresentable {
    let session: KitMenuSession
    @Binding var isPresented: Bool
    var isContext = false
    /// A context menu's secondary clicks over the view, from press to release (`nil`: the view takes no clicks).
    var onContext: ((KitContextPhase, CGPoint) -> Void)? = nil
    var menu: (KitMenuModel, CGRect) -> AnyView

    func makeNSView(context: Context) -> KitMenuAnchorView { KitMenuAnchorView() }

    func updateNSView(_ view: KitMenuAnchorView, context: Context) {
      view.onEvent = onContext
      let controller = session.controller
      controller.close = { isPresented = false }
      controller.menu = menu
      // A menu that starts open waits for the view to land in its window.
      view.movedToWindow = { [weak view] in
        if isPresented, let view { controller.show(from: view, at: session.contextPoint) }
      }
      view.onDismantle = { controller.hide() }
      if isPresented { controller.show(from: view, at: session.contextPoint) } else { controller.hide() }
    }

    static func dismantleNSView(_ view: KitMenuAnchorView, coordinator: ()) {
      view.movedToWindow = {}
      view.dismantled()
    }
  }

  /// The menu's borderless panel, over the whole screen the anchor is on. It never becomes key (the window keeps
  /// its focus and look) and lets clicks through where it is clear, so event monitors close it: a click outside the
  /// menu (swallowed, as a menu's is), the pointer moving well away from it, ⌘ keys, the anchor's window losing
  /// focus, moving, resizing or closing, and the app going inactive.
  @MainActor
  final class KitMenuPanelController {
    var close: () -> Void = {}
    var menu: (KitMenuModel, CGRect) -> AnyView = { _, _ in AnyView(EmptyView()) }
    /// A trigger's press is in progress (the pointer may be anywhere until it ends).
    var isTracking: () -> Bool = { false }
    private(set) var model: KitMenuModel?
    private var panel: KitMenuPanel?
    private var host: NSHostingView<AnyView>?
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var awayTimer: Timer?
    /// The pointer has been near the menu since it opened (a menu opened from the keyboard or VoiceOver, with the
    /// pointer elsewhere, doesn't close until it has).
    private var pointerWasNear = false
    /// The trigger and cards as they were before the menu began to shrink (shrinking moves the cards' edges, which
    /// must not count as the pointer straying further).
    private var restFrames: [CGRect] = []

    /// How far the pointer may stray from the menu and its trigger before the menu closes, and where on the way
    /// it starts to shrink and fade.
    private let awayDistance: CGFloat = 100
    private let fadeDistance: CGFloat = 50

    func show(from view: NSView, at point: CGPoint? = nil) {
      guard let window = view.window, let screen = window.screen ?? NSScreen.main else { return }
      let model = self.model ?? KitMenuModel()
      model.dismiss = { [weak self] in self?.dismiss() }
      self.model = model
      let screenFrame = screen.frame
      let rect = window.convertToScreen(view.convert(view.bounds, to: nil))
      // The view in the panel's top-left coordinates; a context menu's anchor is the point on it.
      let trigger = CGRect(
        x: rect.minX - screenFrame.minX, y: screenFrame.maxY - rect.maxY, width: rect.width, height: rect.height)
      let anchor = point.map { CGRect(x: trigger.minX + $0.x, y: trigger.minY + $0.y, width: 0, height: 0) } ?? trigger
      model.trigger = trigger
      model.isContext = point != nil
      model.anchor = anchor
      model.share = { [weak self, weak view] items in
        self?.dismiss()
        guard let view else { return }
        // From the point a context menu opened at, or the whole view a pop-up opened from.
        let rect = point.map { CGRect(x: $0.x, y: view.isFlipped ? $0.y : view.bounds.height - $0.y, width: 1, height: 1) }
        DispatchQueue.main.async {
          NSSharingServicePicker(items: items).show(relativeTo: rect ?? view.bounds, of: view, preferredEdge: .minY)
        }
      }
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
      panel.acceptsMouseMovedEvents = true
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
      awayTimer?.invalidate()
      awayTimer = nil
      pointerWasNear = false
      restFrames = []
      panel?.orderOut(nil)
      panel = nil
      host = nil
      model = nil
    }

    private func dismiss() {
      guard panel != nil else { return }
      hide()
      close()
    }

    /// A screen point (the pointer's, by default) in the panel's top-left coordinates.
    private func pointer(_ screenPoint: CGPoint = NSEvent.mouseLocation) -> CGPoint? {
      guard let panel else { return nil }
      return CGPoint(x: screenPoint.x - panel.frame.minX, y: panel.frame.maxY - screenPoint.y)
    }

    private func watch(_ window: NSWindow) {
      let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        let keyCode = event.keyCode
        let command = event.modifierFlags.contains(.command)
        let handled = MainActor.assumeIsolated { self?.handle(keyCode: keyCode, command: command) ?? false }
        return handled ? nil : event
      }
      let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
      let localClicks = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
        // Where the click is, from the event itself (the pointer may have moved on since).
        let location = event.window.map { $0.convertPoint(toScreen: event.locationInWindow) } ?? NSEvent.mouseLocation
        let swallow = MainActor.assumeIsolated { self?.clickOutside(at: location) ?? false }
        return swallow ? nil : event
      }
      let otherApps = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
        MainActor.assumeIsolated { self?.dismiss() }
      }
      monitors = [keys, localClicks, otherApps].compactMap { $0 }
      awayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        MainActor.assumeIsolated { self?.checkAway() }
      }
      let center = NotificationCenter.default
      var names: [(Notification.Name, AnyObject?)] = [
        (NSWindow.didMoveNotification, window), (NSWindow.didResizeNotification, window),
        (NSWindow.willCloseNotification, window),
      ]
      // Focus leaving closes it, as a menu, when it had focus: a menu opened in an app or window in the background (a
      // capture, an automation) stays until a click or a key closes it.
      if NSApp.isActive { names.append((NSApplication.didResignActiveNotification, nil)) }
      if window.isKeyWindow { names.append((NSWindow.didResignKeyNotification, window)) }
      for (name, object) in names {
        observers.append(
          center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
          })
      }
    }

    /// A click in the app: on the menu it goes on; on the trigger it goes on (pressing it again closes the menu);
    /// anywhere else it closes the menu and is swallowed.
    private func clickOutside(at location: CGPoint) -> Bool {
      guard let model, let point = pointer(location) else { return false }
      if model.cardFrames.contains(where: { $0.contains(point) }) { return false }
      if model.anchor.contains(point) { return false }
      dismiss()
      return true
    }

    /// The pointer went well away from the menu, its submenus and its trigger (and no press is in progress).
    private func checkAway() {
      guard let model, let point = pointer() else { return }
      if model.fade < 0.005 || restFrames.isEmpty { restFrames = [model.anchor] + model.cardFrames }
      // How far the pointer is outside the trigger and every open card (0 inside one).
      let distance = restFrames.map { rect in
        hypot(max(rect.minX - point.x, 0, point.x - rect.maxX), max(rect.minY - point.y, 0, point.y - rect.maxY))
      }.min() ?? 0
      if distance <= fadeDistance { pointerWasNear = true }
      guard pointerWasNear, !isTracking() else { return setFade(0, of: model) }
      if distance > awayDistance { return closeAnimated(model) }
      setFade(max(0, (distance - fadeDistance) / (awayDistance - fadeDistance)), of: model)
    }

    /// Past the away distance: the menu finishes shrinking and fades out, then its panel goes.
    private func closeAnimated(_ model: KitMenuModel) {
      awayTimer?.invalidate()
      awayTimer = nil
      withAnimation(.smooth(duration: 0.18)) { model.isClosing = true }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self, weak model] in
        guard let self, let model, self.model === model else { return }
        self.dismiss()
      }
    }

    /// The timer samples every 0.1 s; animating each step over that time makes the change continuous.
    private func setFade(_ fade: Double, of model: KitMenuModel) {
      guard abs(model.fade - fade) > 0.005 else { return }
      withAnimation(.linear(duration: 0.12)) { model.fade = fade }
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

  /// Over a context menu's view (its menu's anchor): takes secondary clicks (right-click, Control-click) and the
  /// drags and release that follow, and lets every other event through to the view.
  class KitContextClickView: NSView {
    /// The secondary clicks' handler; without one the view takes no events.
    var onEvent: ((KitContextPhase, CGPoint) -> Void)? {
      didSet {
        guard (onEvent == nil) != (oldValue == nil) else { return }
        if onEvent != nil, window != nil { Self.all.add(self) } else { Self.all.remove(self) }
      }
    }
    /// The press is a Control-click (the left button), so its drags and release are the left button's.
    private var controlClick = false
    /// Every catcher in a window, to find the innermost under a click.
    private static let all = NSHashTable<KitContextClickView>.weakObjects()

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window != nil, onEvent != nil { Self.all.add(self) } else { Self.all.remove(self) }
    }

    /// A secondary click goes to the innermost context menu's catcher under it, as with `.contextMenu`: a view's
    /// catcher lies over the catchers of the views inside it (a modifier on a view of several rows lands on each,
    /// over the rows' own), so the one on top hands the click to the smallest, and on a tie the one under it.
    override func hitTest(_ point: NSPoint) -> NSView? {
      guard let event = NSApp.currentEvent else { return nil }
      let secondary =
        event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
      guard secondary, onEvent != nil, super.hitTest(point) != nil, window != nil else { return nil }
      return innermost(at: event.locationInWindow, among: Self.all.allObjects)
    }

    /// The catcher a secondary click at `location` (in the window) goes to: the smallest under it, this one or one
    /// of `catchers`, and on a tie the one drawn under.
    func innermost(at location: CGPoint, among catchers: [KitContextClickView]) -> KitContextClickView {
      var best: KitContextClickView = self
      for view in catchers where view !== self && view.window === window && !view.isHiddenOrHasHiddenAncestor {
        guard view.onEvent != nil, view.bounds.contains(view.convert(location, from: nil)) else { continue }
        let area = view.bounds.width * view.bounds.height
        let bestArea = best.bounds.width * best.bounds.height
        if area < bestArea - 0.5 || (abs(area - bestArea) <= 0.5 && view.isBelow(best)) { best = view }
      }
      return best
    }

    /// Drawn under `other` (earlier in their common superview's subviews).
    private func isBelow(_ other: NSView) -> Bool {
      guard let common = ancestorShared(with: other) else { return false }
      func branch(_ view: NSView) -> NSView? {
        var current: NSView? = view
        while let next = current, next.superview !== common { current = next.superview }
        return current
      }
      guard let mine = branch(self), let theirs = branch(other), mine !== theirs,
        let a = common.subviews.firstIndex(of: mine), let b = common.subviews.firstIndex(of: theirs)
      else { return false }
      return a < b
    }

    override func menu(for event: NSEvent) -> NSMenu? { nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func location(_ event: NSEvent) -> CGPoint { convert(event.locationInWindow, from: nil) }

    override func rightMouseDown(with event: NSEvent) { onEvent?(.began, location(event)) }
    override func rightMouseDragged(with event: NSEvent) { onEvent?(.changed, location(event)) }
    override func rightMouseUp(with event: NSEvent) { onEvent?(.ended, location(event)) }

    override func mouseDown(with event: NSEvent) {
      guard event.modifierFlags.contains(.control) else { return super.mouseDown(with: event) }
      controlClick = true
      onEvent?(.began, location(event))
    }
    override func mouseDragged(with event: NSEvent) {
      if controlClick { onEvent?(.changed, location(event)) } else { super.mouseDragged(with: event) }
    }
    override func mouseUp(with event: NSEvent) {
      guard controlClick else { return super.mouseUp(with: event) }
      controlClick = false
      onEvent?(.ended, location(event))
    }
  }

  final class KitMenuAnchorView: KitContextClickView {
    var movedToWindow: () -> Void = {}
    var onDismantle: () -> Void = {}
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window != nil { DispatchQueue.main.async { [weak self] in self?.movedToWindow() } }
    }
    func dismantled() { onDismantle() }
  }

  final class KitMenuPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
  }

#elseif canImport(UIKit) && !os(tvOS)
  /// Sits behind the anchored view: finds its window and frame, and opens or closes the menu window as
  /// `isPresented` changes (and refreshes it while open).
  struct KitMenuAnchor: UIViewRepresentable {
    let session: KitMenuSession
    @Binding var isPresented: Bool
    var isContext = false
    var menu: (KitMenuModel, CGRect) -> AnyView

    func makeUIView(context: Context) -> KitMenuAnchorView {
      let view = KitMenuAnchorView()
      view.isUserInteractionEnabled = false
      return view
    }

    func updateUIView(_ view: KitMenuAnchorView, context: Context) {
      let controller = session.controller
      let session = session
      let presented = $isPresented
      view.onLongPress = isContext ? { phase, point in session.context(phase, at: point, isPresented: presented) } : nil
      controller.close = { isPresented = false }
      controller.menu = menu
      // A menu that starts open waits for the view to land in its window.
      view.movedToWindow = { [weak view] in
        if isPresented, let view { controller.show(from: view, at: session.contextPoint) }
      }
      view.onDismantle = { controller.hide() }
      if isPresented { controller.show(from: view, at: session.contextPoint) } else { controller.hide() }
    }

    static func dismantleUIView(_ view: KitMenuAnchorView, coordinator: ()) {
      view.movedToWindow = {}
      view.dismantled()
    }
  }

  /// The first responder, found by an action sent to nil.
  @MainActor enum KitFirstResponder {
    static weak var found: UIResponder?
  }

  extension UIResponder {
    @objc func kitFindFirstResponder() { KitFirstResponder.found = self }
  }

  final class KitMenuAnchorView: UIView, UIGestureRecognizerDelegate {
    var movedToWindow: () -> Void = {}
    var onDismantle: () -> Void = {}
    /// A context menu's long press: set, the view's window gets a long-press recognizer for touches on this view.
    var onLongPress: ((KitContextPhase, CGPoint) -> Void)? {
      didSet { installLongPress() }
    }
    private var longPress: UILongPressGestureRecognizer?

    override func didMoveToWindow() {
      super.didMoveToWindow()
      installLongPress()
      if window != nil { DispatchQueue.main.async { [weak self] in self?.movedToWindow() } }
    }

    func dismantled() {
      onDismantle()
      onLongPress = nil
    }

    /// The press lives on the window (this view sits behind the content and takes no touches), and only begins for
    /// touches inside this view; once it's recognized, the touch is the menu's (the content's own gestures cancel).
    private func installLongPress() {
      let wanted = onLongPress != nil ? window : nil
      if longPress?.view === wanted, longPress != nil || wanted == nil { return }
      if let longPress { longPress.view?.removeGestureRecognizer(longPress) }
      longPress = nil
      guard let wanted else { return }
      let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
      // Ahead of a drag interaction's lift (about 0.45 s in a list), so this press decides that the two share the
      // touch (`shouldRecognizeSimultaneouslyWith`) rather than the lift's own delegate.
      recognizer.minimumPressDuration = 0.4
      recognizer.delegate = self
      wanted.addGestureRecognizer(recognizer)
      longPress = recognizer
    }

    @objc private func pressed(_ recognizer: UILongPressGestureRecognizer) {
      let point = recognizer.location(in: self)
      switch recognizer.state {
      case .began:
        #if !os(visionOS)
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        start = point
        onLongPress?(.began, point)
      case .changed:
        // Held and dragged on a view that lifted for a drag (a reorderable row, a `.draggable`): the drag goes on,
        // the menu goes, as the system's context menu does.
        if isLifted, hypot(point.x - start.x, point.y - start.y) > 10 {
          lifts.removeAll()
          onLongPress?(.dragged, point)
        } else {
          onLongPress?(.changed, point)
        }
      case .ended: onLongPress?(.ended, point)
      case .cancelled, .failed:
        // Cancelled as a drag began (the finger moved off with a lifted view): the menu goes. A list's drag
        // interaction also cancels the press as its lift settles, with the finger still: the menu stays.
        let moved = hypot(point.x - start.x, point.y - start.y) > 8
        onLongPress?(isLifted && moved ? .dragged : .cancelled, point)
      default: break
      }
      if recognizer.state == .ended || recognizer.state == .cancelled || recognizer.state == .failed {
        lifts.removeAll()
      }
    }

    /// Where the press began, in this view.
    private var start: CGPoint = .zero
    /// The drag interactions' recognizers that share this press: the view is a drag source too.
    private var lifts: [Weak] = []
    private struct Weak { weak var recognizer: UIGestureRecognizer? }

    /// A drag source under the press lifted its view.
    private var isLifted: Bool {
      lifts.contains { $0.recognizer.map { $0.state == .began || $0.state == .changed } ?? false }
    }

    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
      window != nil && !isHiddenInTree && bounds.contains(touch.location(in: self))
    }

    /// The press shares the touch with a drag interaction's own long press (the lift of a reorderable row or a
    /// `.draggable`): holding opens the menu, holding and dragging drags. Every other gesture yields to the menu.
    func gestureRecognizer(
      _ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
      guard Self.isDragLift(other) else { return false }
      if !lifts.contains(where: { $0.recognizer === other }) { lifts.append(Weak(recognizer: other)) }
      return true
    }

    /// A drag interaction's recognizer (UIKit names them so; SwiftUI's drag sources are drag interactions).
    static func isDragLift(_ recognizer: UIGestureRecognizer) -> Bool {
      let name = String(describing: type(of: recognizer))
      return name.contains("Drag") || name.contains("Lift")
    }

    private var isHiddenInTree: Bool {
      var view: UIView? = self
      while let current = view {
        if current.isHidden || current.alpha < 0.01 { return true }
        view = current.superview
      }
      return false
    }
  }

  /// The menu's window above the scene: a tap outside the menu closes it (the window's catcher), as does the app
  /// or scene going inactive; it takes the keys while open (↑/↓, Return, Esc on a hardware keyboard).
  @MainActor
  final class KitMenuWindowController {
    var close: () -> Void = {}
    var menu: (KitMenuModel, CGRect) -> AnyView = { _, _ in AnyView(EmptyView()) }
    var isTracking: () -> Bool = { false }
    private(set) var model: KitMenuModel?
    private var window: UIWindow?
    private var host: UIHostingController<AnyView>?
    private var observers: [NSObjectProtocol] = []

    func show(from view: UIView, at point: CGPoint? = nil) {
      guard let scene = view.window?.windowScene else { return }
      let model = self.model ?? KitMenuModel()
      model.dismiss = { [weak self] in self?.dismiss() }
      self.model = model
      let window = self.window ?? UIWindow(windowScene: scene)
      // The view in the menu window's coordinates; a context menu's anchor is the point on it.
      let trigger = view.convert(view.bounds, to: window)
      let anchor = point.map { CGRect(x: trigger.minX + $0.x, y: trigger.minY + $0.y, width: 0, height: 0) } ?? trigger
      model.trigger = trigger
      model.isContext = point != nil
      model.anchor = anchor
      model.share = { [weak self, weak view] items in
        self?.dismiss()
        // Once the menu's window has gone and the scene's window is key again.
        DispatchQueue.main.async {
          guard let view, let root = view.window?.rootViewController else { return }
          let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
          sheet.popoverPresentationController?.sourceView = view
          sheet.popoverPresentationController?.sourceRect = point.map { CGRect(origin: $0, size: .zero) } ?? view.bounds
          var top = root
          while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
          top.present(sheet, animated: true)
        }
      }
      let root = menu(model, anchor)
      if let host {
        host.rootView = root
        return
      }
      // A text view with the keyboard keeps it (an editor's keyboard bar, a composer): the menu's window takes the
      // keys only when nothing is typing.
      model.takesKeys = !KitMenuWindowController.isTyping(in: view.window)
      let host = UIHostingController(rootView: root)
      host.view.backgroundColor = .clear
      window.windowLevel = .alert + 1
      window.backgroundColor = .clear
      window.rootViewController = host
      window.isHidden = false
      if model.takesKeys { window.makeKey() }
      self.window = window
      self.host = host
      // It closes as the app goes to the background, not as it merely becomes inactive (Control Center, a banner,
      // an alert over it), as the system's menus and popovers stay.
      let center = NotificationCenter.default
      for name in [UIApplication.didEnterBackgroundNotification, UIScene.didEnterBackgroundNotification] {
        observers.append(
          center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
          })
      }
    }

    /// A text input in `window` is first responder (the keyboard is up for it).
    static func isTyping(in window: UIWindow?) -> Bool {
      guard let window else { return false }
      KitFirstResponder.found = nil
      UIApplication.shared.sendAction(#selector(UIResponder.kitFindFirstResponder), to: nil, from: nil, for: nil)
      defer { KitFirstResponder.found = nil }
      guard let responder = KitFirstResponder.found as? UIView, responder is UITextInput else { return false }
      return responder.window === window
    }

    func hide() {
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
      window?.isHidden = true
      window = nil
      host = nil
      model = nil
    }

    private func dismiss() {
      guard window != nil else { return }
      hide()
      close()
    }
  }
#endif
