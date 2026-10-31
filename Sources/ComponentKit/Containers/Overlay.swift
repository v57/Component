import SwiftUI

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#endif

// Overlays (the Overlays board: "Sheet over the window", "Command palette"; the Hub board's iPhone sheets): sheets,
// confirmations, dialogs and the palette float over the whole window, never in a system sheet. The window dims
// (`kitScrim`), the card sits on the panel ground with the float shadow: centred with 20pt corners (sheets, dialogs)
// on the Mac, iPad and iPhone alike, or at the top (the palette). The root modifier hosts them, so a
// presenter anywhere in the window (a button deep in a sidebar, a toolbar's view, a card inside another overlay)
// covers the whole window, and overlays stack.

// MARK: - Presenters

extension View {
  /// Shows `content` over the whole window while `isPresented`, as the kit's sheet: the window dims and the content
  /// floats on a card (put a `KitSheet` in it), in the middle (on iPhone too, above the keyboard). The same bindings
  /// as `.sheet`, so moving to it is a rename. Escape, a click on the dim and the content's own
  /// Cancel close it; focus moves into the card (its first field on the Mac), and Tab stays inside it. Close it from
  /// inside with `@Environment(\.kitDismiss)` (SwiftUI's `dismiss` doesn't reach a kit overlay), or keep it open
  /// on a click on the dim with `.kitSheetDismissDisabled()`. The content gets the presenting view's environment.
  ///
  /// ```swift
  /// .kitSheet(isPresented: $cloning) {
  ///   KitSheet(title: "Clone Repository", meta: "Copies a repository from GitHub, GitLab or any URL.",
  ///            systemImage: "arrow.down.circle") {
  ///     FormCard { FormRow("Repository URL", systemImage: "link", field: TextField("https://", text: $url)) }
  ///   } footer: {
  ///     Button("Cancel") { cloning = false }.keyboardShortcut(.cancelAction)
  ///     Button("Clone") { clone() }.buttonStyle(.kitPrimary).keyboardShortcut(.defaultAction)
  ///   }
  /// }
  /// ```
  public func kitSheet<Content: View>(
    isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    modifier(
      KitOverlayPresenter(
        isPresented: isPresented, style: .sheet, onDismiss: onDismiss, content: content))
  }

  /// Shows `content` for `item` over the whole window while it isn't nil (`.sheet(item:)` as a kit overlay). A new
  /// item replaces the content in place.
  ///
  /// ```swift
  /// .kitSheet(item: $editing) { host in HostSheet(host: host) }
  /// ```
  public func kitSheet<Item: Identifiable, Content: View>(
    item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content
  ) -> some View {
    modifier(KitOverlayItemPresenter(item: item, onDismiss: onDismiss, content: content))
  }

  /// Keeps a kit sheet open on a click on the dim (a form with unsaved input); Escape and the sheet's
  /// own buttons still close it.
  ///
  /// ```swift
  /// KitSheet(…) { … }.kitSheetDismissDisabled(hasChanges)
  /// ```
  public func kitSheetDismissDisabled(_ isDisabled: Bool = true) -> some View {
    preference(key: KitOverlayDismissDisabled.self, value: isDisabled)
      .interactiveDismissDisabled(isDisabled)
  }
}

/// Closes the kit sheet, confirmation or dialog the view is in (the kit's `dismiss`): set by every kit presenter,
/// on the overlay and in a system sheet (a view outside `componentKit()`) alike. Outside one it does nothing.
///
/// ```swift
/// @Environment(\.kitDismiss) private var dismiss
/// Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
/// ```
public struct KitDismissAction: Sendable {
  let handler: @MainActor @Sendable () -> Void

  @MainActor public func callAsFunction() { handler() }
}

extension EnvironmentValues {
  /// Closes the kit sheet the view is in; see `KitDismissAction`.
  @Entry public var kitDismiss = KitDismissAction {}
  /// The window's overlay host, set by the root modifier; nil outside `componentKit()`.
  @Entry var kitOverlayHost: KitOverlayHost? = nil
  /// How the view is presented: in a kit overlay's card, in the system's sheet, or neither.
  @Entry var kitPresentation: KitPresentation = .none
}

enum KitPresentation: Hashable, Sendable {
  case none, overlay, systemSheet
}

/// A click on the dim leaves the overlay open (`kitSheetDismissDisabled`).
struct KitOverlayDismissDisabled: PreferenceKey {
  static let defaultValue = false
  static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

// MARK: - Host

/// How an overlay sits: a sheet in the middle on the kit's card, a dialog in the middle too, the palette at the top
/// drawing its own, a popover on the kit's card beside its anchor (in the host's space) with no dim.
enum KitOverlayStyle: Equatable, Sendable {
  case sheet
  case dialog
  case palette(width: CGFloat)
  /// The anchor follows the view as it moves (scrolling, a window resizing) without the presenter redrawing.
  case popover(anchor: ContPopoverAnchor, edge: VerticalEdge)

  static func == (a: Self, b: Self) -> Bool {
    switch (a, b) {
    case (.sheet, .sheet), (.dialog, .dialog): true
    case (.palette(let x), .palette(let y)): x == y
    case (.popover(let x, let e), .popover(let y, let f)): x === y && e == f
    default: false
    }
  }

  var isTop: Bool { if case .palette = self { true } else { false } }
  var isPopover: Bool { if case .popover = self { true } else { false } }
}

/// The overlays shown over one window, bottom to top. One that closes stays a moment, fading out, before it goes.
@MainActor @Observable
final class KitOverlayHost {
  struct Entry: Identifiable {
    let id: UUID
    var style: KitOverlayStyle
    var content: KitOverlayContent
    /// Closes the overlay as Escape or a click on the dim does (the presenter's binding goes false).
    var dismiss: @MainActor () -> Void
    /// Fading out; gone once `KitOverlayHost.fadeOut` has passed.
    var isClosing = false
    /// Leaves focus, keys and clicks where they are (`kitPopover(takesFocus: false)`): the window behind stays
    /// enabled, nothing catches a click beside it, and it is never the top overlay.
    var isPassive = false
  }

  /// How long a closing overlay stays, fading out.
  static let fadeOut: Duration = .milliseconds(160)

  private(set) var entries: [Entry] = []

  /// Shows an overlay over the others, or updates one already shown (or closing) in its place.
  func present(_ entry: Entry) {
    if let index = entries.firstIndex(where: { $0.id == entry.id }) {
      entries[index] = entry
    } else {
      entries.append(entry)
    }
  }

  /// Closes an overlay: it fades out, then leaves the stack (unless presented again meanwhile).
  func remove(_ id: UUID, animated: Bool = true) {
    guard let index = entries.firstIndex(where: { $0.id == id }), !entries[index].isClosing else { return }
    guard animated else {
      entries.remove(at: index)
      return
    }
    entries[index].isClosing = true
    Task { @MainActor in
      await kitSleep(for: Self.fadeOut)
      entries.removeAll { $0.id == id && $0.isClosing }
    }
  }

  /// The overlay that takes clicks and keys: the last one that isn't closing (or passive).
  var top: UUID? { entries.last { !$0.isClosing && !$0.isPassive }?.id }

  /// Whether any overlay shows (the window behind leaves VoiceOver).
  var isShowing: Bool { top != nil }
}

/// What an overlay's content takes from where it is drawn rather than from its presenter: whether it is enabled (a
/// card under another isn't) and the window's look. The presenter's environment is a copy from when it last redrew,
/// so an appearance forced after launch (`NSApp.appearance`, an app's own setting) never reached it.
struct KitOverlayLook: Equatable {
  var isEnabled = true
  var colorScheme: ColorScheme = .light
  var colorSchemeContrast: ColorSchemeContrast = .standard
  var windowIsActive = true

  func apply<Content: View>(to content: Content) -> some View {
    content
      .environment(\.isEnabled, isEnabled)
      .environment(\.colorScheme, colorScheme)
      .environment(\._colorSchemeContrast, colorSchemeContrast)
      .environment(\.kitWindowIsActive, windowIsActive)
  }
}

/// An overlay's content as its presenter last built it. The presenter rebuilds it whenever it redraws (its state
/// changed), and the overlay redraws on the next turn of the run loop; bindings and observed models inside update
/// the overlay directly.
@MainActor @Observable
final class KitOverlayContent {
  private(set) var version = 0
  /// Builds the content with the look of where it is drawn.
  @ObservationIgnored private(set) var make: (_ look: KitOverlayLook) -> AnyView = { _ in AnyView(EmptyView()) }
  @ObservationIgnored private var isPending = false

  func update(_ make: @escaping (_ look: KitOverlayLook) -> AnyView) {
    self.make = make
    guard !isPending else { return }
    isPending = true
    Task { @MainActor in
      self.isPending = false
      self.version &+= 1
    }
  }

  func set(_ make: @escaping (_ look: KitOverlayLook) -> AnyView) {
    self.make = make
    version &+= 1
  }
}

/// Installs the window's overlay host (in `componentKit()`): the overlays draw over everything under the root, and
/// the window behind them leaves VoiceOver while they show. A root inside an overlay's card adds no host of its own,
/// so what that card presents stacks over the window.
struct KitOverlayHostModifier: ViewModifier {
  @Environment(\.kitPresentation) private var presentation
  @State private var host = KitOverlayHost()

  func body(content: Content) -> some View {
    if presentation == .overlay {
      content
    } else {
      // The window behind an overlay is disabled: its buttons' shortcuts (Return, Escape, ⌘ keys) and its fields
      // stay out of the way, so only the top card's take keys (SwiftUI matches a shortcut anywhere in the window).
      content
        .disabled(host.isShowing)
        .accessibilityHidden(host.isShowing)
        .overlay { KitOverlayLayer(host: host) }
        .environment(\.kitOverlayHost, host)
    }
  }
}

/// The stack, bottom to top.
private struct KitOverlayLayer: View {
  let host: KitOverlayHost

  var body: some View {
    ZStack {
      ForEach(Array(host.entries.enumerated()), id: \.element.id) { index, entry in
        KitOverlayEntryView(
          entry: entry, isTop: entry.id == host.top,
          isInteractive: entry.id == host.top || (entry.isPassive && host.top == nil)
        )
        .zIndex(Double(index))
      }
    }
  }
}

/// One overlay: the dim and the card. Both fade in (the card also grows a little) when it appears, and out while it
/// closes, on iPhone as on the Mac.
private struct KitOverlayEntryView: View {
  let entry: KitOverlayHost.Entry
  let isTop: Bool
  /// Takes clicks: the top overlay, or a passive one while nothing else shows.
  let isInteractive: Bool
  @State private var hasAppeared = false
  @State private var isDismissDisabled = false
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    let isShown = hasAppeared && !entry.isClosing
    ZStack(alignment: entry.style.isTop ? .top : .center) {
      // A popover dims nothing; a click beside it still closes it (and goes no further, as a menu's). A passive one
      // leaves clicks beside it to the window.
      if !entry.isPassive {
        Rectangle()
          .fill(entry.style.isPopover ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.kitScrim))
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture { if !isDismissDisabled { entry.dismiss() } }
          .accessibilityAddTraits(.isButton)
          .accessibilityLabel("Close")
          .accessibilityHidden(isDismissDisabled)
          .opacity(isShown ? 1 : 0)
      }
      card
        .opacity(isShown ? 1 : 0)
        .scaleEffect(isShown ? 1 : entry.style.isTop ? 0.98 : 0.96, anchor: scaleAnchor)
    }
    .allowsHitTesting(isInteractive)
    .animation(.kitFast, value: isShown)
    .onAppear { hasAppeared = true }
  }

  private var scaleAnchor: UnitPoint {
    switch entry.style {
    case .palette: .top
    case .popover(_, let edge): edge == .bottom ? .top : .bottom
    case .sheet, .dialog: .center
    }
  }

  @ViewBuilder
  private var card: some View {
    // A card under another is disabled as the window is.
    let body = KitOverlayBody(content: entry.content, isEnabled: isInteractive)
      .onPreferenceChange(KitOverlayDismissDisabled.self) { value in
        MainActor.assumeIsolated { isDismissDisabled = value }
      }
      .modifier(KitOverlayFocus(isTop: isTop, dismiss: entry.dismiss))
      .accessibilityAddTraits(entry.isPassive ? [] : .isModal)
      .accessibilityAction(.escape) { if !isDismissDisabled { entry.dismiss() } }
    switch entry.style {
    case .palette(let width):
      body
        .frame(maxWidth: width)
        .padding(
          EdgeInsets(
            top: idiom.isTouch ? 16 : KitMetrics.gutter,
            leading: KitMetrics.gutter,
            bottom: 0,
            trailing: KitMetrics.gutter))
        .frame(maxHeight: .infinity, alignment: .top)
    case .sheet, .dialog:
      // The screen's width less 16pt each side on iPhone; on the Mac and iPad the content sets it.
      body
        .kitOverlayCard()
        .padding(idiom.size(20, pad: 24, phone: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .popover(let anchor, let edge):
      // The anchor is in the window's space; the layout places the card in its own.
      GeometryReader { proxy in
        let origin = proxy.frame(in: .global).origin
        ContPopoverLayout(anchor: anchor.frame.offsetBy(dx: -origin.x, dy: -origin.y), edge: edge) {
          body.kitOverlayCard()
        }
      }
    }
  }
}

private struct KitOverlayBody: View {
  let content: KitOverlayContent
  let isEnabled: Bool
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast
  @Environment(\.kitWindowIsActive) private var windowIsActive

  var body: some View {
    let _ = content.version
    content.make(
      KitOverlayLook(
        isEnabled: isEnabled, colorScheme: colorScheme, colorSchemeContrast: colorSchemeContrast,
        windowIsActive: windowIsActive))
  }
}

extension View {
  /// The kit overlays' card: the panel ground with 20pt corners, a hairline and the float shadow, the content clipped
  /// to it. Sheets, dialogs, popovers and the palette sit on it; use it for a floating panel of your own that dims
  /// nothing (a style panel over a video, a console hanging under the toolbar).
  ///
  /// ```swift
  /// SubtitleStyleForm()
  ///   .frame(width: 320)
  ///   .kitOverlayCard()
  /// ```
  public func kitOverlayCard() -> some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusOverlay, style: .continuous)
    return self
      .clipShape(shape)
      .overlay(shape.strokeBorder(.kitBorder, lineWidth: 0.5))
      .background { KitOverlayCardGround() }
  }
}

/// The card's ground and shadow, under content that clips itself (the palette).
struct KitOverlayCardGround: View {
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusOverlay, style: .continuous)
    SurfaceShape(surface: .floating, cornerRadius: KitMetrics.radiusOverlay)
      .overlay(shape.fill(.kitPanel))
      .overlay(shape.strokeBorder(.kitBorder, lineWidth: 0.5))
  }
}

// MARK: - Presenter

struct KitOverlayPresenter<Overlay: View>: ViewModifier {
  @Binding var isPresented: Bool
  var style: KitOverlayStyle
  var onDismiss: (() -> Void)?
  var identity: AnyHashable? = nil
  /// The overlay leaves focus and the window alone (`KitOverlayHost.Entry.isPassive`).
  var isPassive = false
  var content: () -> Overlay
  @Environment(\.kitOverlayHost) private var host
  @Environment(\.contMeasuringCopy) private var isMeasuringCopy
  @Environment(\.self) private var environment
  @State private var id = UUID()
  @State private var overlay = KitOverlayContent()

  func body(content view: Content) -> some View {
    if isMeasuringCopy {
      // A hidden copy for measuring (a kit toolbar's tools): the visible one presents.
      view
    } else if host == nil {
      // Outside `componentKit()` there is no host: the system's sheet.
      view.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
        content()
          .environment(\.kitDismiss, dismissAction)
          .environment(\.kitPresentation, .systemSheet)
      }
    } else {
      let _ = isPresented ? overlay.update(make) : ()
      view
        .onChange(of: isPresented) { _, shown in
          if shown {
            present()
          } else {
            host?.remove(id)
            onDismiss?()
          }
        }
        .onChange(of: identity) { if isPresented { overlay.set(make) } }
        .onAppear { if isPresented { present() } }
        .onDisappear { host?.remove(id, animated: false) }
    }
  }

  private var dismissAction: KitDismissAction {
    let binding = $isPresented
    return KitDismissAction { binding.wrappedValue = false }
  }

  /// The content with the presenting view's environment (its models, accent, idiom) and the kit's dismiss.
  private var make: (_ look: KitOverlayLook) -> AnyView {
    let content = content
    let environment = environment
    let dismiss = dismissAction
    return { look in
      AnyView(
        // The presenter is behind the overlay, so disabled while it shows (the top card isn't), and its look may be
        // older than the window's: both come from where the card is drawn.
        look.apply(
          to: content()
            .environment(\.kitDismiss, dismiss)
            .environment(\.kitPresentation, .overlay)
        )
        .environment(\.self, environment))
    }
  }

  private func present() {
    guard let host else { return }
    overlay.set(make)
    let dismiss = dismissAction
    host.present(.init(id: id, style: style, content: overlay, dismiss: { dismiss() }, isPassive: isPassive))
  }
}

struct KitOverlayItemPresenter<Item: Identifiable, Overlay: View>: ViewModifier {
  @Binding var item: Item?
  var onDismiss: (() -> Void)?
  var content: (Item) -> Overlay
  @Environment(\.kitOverlayHost) private var host

  func body(content view: Content) -> some View {
    if host == nil {
      view.sheet(item: $item, onDismiss: onDismiss) { item in
        let binding = $item
        content(item)
          .environment(\.kitDismiss, KitDismissAction { binding.wrappedValue = nil })
          .environment(\.kitPresentation, .systemSheet)
      }
    } else {
      let binding = $item
      let content = content
      view.modifier(
        KitOverlayPresenter(
          isPresented: Binding(get: { binding.wrappedValue != nil }, set: { if !$0 { binding.wrappedValue = nil } }),
          style: .sheet, onDismiss: onDismiss,
          identity: item.map { AnyHashable($0.id) },
          content: { KitOverlayItemContent(item: binding.wrappedValue, content: content) }))
    }
  }
}

private struct KitOverlayItemContent<Item: Identifiable, Overlay: View>: View {
  let item: Item?
  let content: (Item) -> Overlay

  var body: some View {
    if let item { content(item).id(item.id) }
  }
}

// MARK: - Focus

/// Moves focus into the top overlay's card and keeps it there. On the Mac its first text field takes focus (or the
/// card, when it has none), Tab cycles through the card's fields, and Escape goes to the card's Cancel button
/// (`.keyboardShortcut(.cancelAction)`) or, without one, closes the overlay. On iPad the field focused behind the
/// overlay lets go, and Escape from a field in the card closes it.
private struct KitOverlayFocus: ViewModifier {
  let isTop: Bool
  let dismiss: @MainActor () -> Void

  func body(content: Content) -> some View {
    #if os(macOS)
      content.background { KitOverlayFocusAnchor(isTop: isTop, dismiss: dismiss) }
    #elseif os(iOS)
      content
        .onKeyPress(.escape) {
          guard isTop else { return .ignored }
          dismiss()
          return .handled
        }
        .onAppear {
          // A passive overlay (never the top one) leaves the keyboard to the field behind.
          guard isTop else { return }
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    #else
      content
    #endif
  }
}

#if os(macOS)
  private struct KitOverlayFocusAnchor: NSViewRepresentable {
    let isTop: Bool
    let dismiss: @MainActor () -> Void

    func makeNSView(context: Context) -> KitOverlayFocusView { KitOverlayFocusView() }

    func updateNSView(_ view: KitOverlayFocusView, context: Context) {
      view.dismiss = dismiss
      view.setTop(isTop)
    }

    static func dismantleNSView(_ view: KitOverlayFocusView, coordinator: ()) {
      view.setTop(false)
    }
  }

  /// Spans the card. While the card is the top one it focuses the card's first field and watches the window's keys:
  /// Tab cycles through the card's fields (editable, inside the card and on top there, so never a field under the
  /// dim), Escape goes to the card's Cancel button (the window behind is disabled, so only the top card's buttons
  /// have shortcuts) or, without one, closes the overlay.
  final class KitOverlayFocusView: NSView {
    var dismiss: @MainActor () -> Void = {}
    private var isTop = false
    private var monitor: Any?
    /// The top card's view, for `_kitOverlayHandleKey`.
    nonisolated(unsafe) static weak var top: KitOverlayFocusView?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if isTop, window != nil { focusFirst() }
    }

    func setTop(_ top: Bool) {
      guard top != isTop else { return }
      isTop = top
      if top {
        Self.top = self
        // The window's field lets go now, so typing never reaches the view behind.
        if let window, !owns(window.firstResponder) { window.makeFirstResponder(nil) }
        focusFirst()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
          MainActor.assumeIsolated { self?.handle(event) ?? false } ? nil : event
        }
      } else {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if Self.top === self { Self.top = nil }
      }
    }

    /// Focuses the card's first field once it is laid out (a few turns of the run loop after the overlay appears).
    private func focusFirst(attempt: Int = 0) {
      DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0 : 0.05)) { [weak self] in
        guard let self, self.isTop, let window = self.window else { return }
        if self.owns(window.firstResponder) { return }
        if let field = self.fields().first {
          window.makeFirstResponder(field)
        } else if attempt < 8 {
          self.focusFirst(attempt: attempt + 1)
        }
      }
    }

    /// The overlay's answer to a key; true when it took it.
    func handle(_ event: NSEvent) -> Bool {
      guard isTop, let window, event.window === window else { return false }
      // A kit menu open over the card takes its own keys.
      if NSApp.windows.contains(where: { $0 is KitMenuPanel && $0.isVisible }) { return false }
      guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else { return false }
      switch event.keyCode {
      case 48:
        return moveFocus(backward: event.modifierFlags.contains(.shift))
      case 53:
        if window.performKeyEquivalent(with: event) { return true }
        dismiss()
        return true
      case 36, 76:
        // The card's default button (`.keyboardShortcut(.defaultAction)`); without one, the field's own submit.
        return window.performKeyEquivalent(with: event)
      default:
        return false
      }
    }

    private func moveFocus(backward: Bool) -> Bool {
      guard let window else { return false }
      let fields = fields()
      guard !fields.isEmpty else { return true }
      let current = fields.firstIndex { Self.isFocused($0, in: window) }
      let next: Int =
        if let current { (current + (backward ? fields.count - 1 : 1)) % fields.count } else { backward ? fields.count - 1 : 0 }
      window.makeFirstResponder(fields[next])
      return true
    }

    private func owns(_ responder: NSResponder?) -> Bool {
      guard let window else { return false }
      return fields().contains { Self.isFocused($0, in: window) }
    }

    private static func isFocused(_ field: NSView, in window: NSWindow) -> Bool {
      guard let responder = window.firstResponder else { return false }
      if responder === field { return true }
      if let editor = responder as? NSTextView, editor.isFieldEditor, (editor.delegate as? NSView) === field { return true }
      return (responder as? NSView)?.isDescendant(of: field) ?? false
    }

    /// The card's editable text fields and text views, top to bottom, then leading to trailing.
    func fields() -> [NSView] {
      guard let window, let root = window.contentView else { return [] }
      let card = convert(bounds, to: nil)
      var found: [(view: NSView, frame: CGRect)] = []
      func walk(_ view: NSView) {
        guard !view.isHidden, view.alphaValue > 0 else { return }
        let isInput: Bool =
          if let field = view as? NSTextField { field.isEditable && field.isEnabled }
          else if let text = view as? NSTextView { text.isEditable && !text.isFieldEditor }
          else { false }
        if isInput {
          let frame = view.convert(view.bounds, to: nil)
          if card.contains(CGPoint(x: frame.midX, y: frame.midY)), Self.isOnTop(view, at: frame, in: root) {
            found.append((view, frame))
          }
          return
        }
        view.subviews.forEach(walk)
      }
      walk(root)
      // Window coordinates grow upward: the top field has the largest y.
      return found.sorted { a, b in
        abs(a.frame.maxY - b.frame.maxY) > 4 ? a.frame.maxY > b.frame.maxY : a.frame.minX < b.frame.minX
      }.map(\.view)
    }

    /// The view is what a click at its middle reaches (a field under the dim isn't).
    private static func isOnTop(_ view: NSView, at frame: CGRect, in root: NSView) -> Bool {
      let point = CGPoint(x: frame.midX, y: frame.midY)
      let local = root.superview?.convert(point, from: nil) ?? point
      guard let hit = root.hitTest(local) else { return false }
      let target = (view as? NSTextView)?.enclosingScrollView ?? view
      return hit === view || hit.isDescendant(of: target)
    }
  }

  #if DEBUG
    /// Hands a key event to the top overlay as its event monitor would (the catalog's `--overlay-test`: events an
    /// app posts to itself never reach monitors). True when the overlay took it.
    @MainActor public func _kitOverlayHandleKey(_ event: NSEvent) -> Bool {
      KitOverlayFocusView.top?.handle(event) ?? false
    }
  #endif
#endif
