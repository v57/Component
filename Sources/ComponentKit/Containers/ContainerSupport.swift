import SwiftUI

#if canImport(AppKit)
  import AppKit
#elseif canImport(UIKit)
  import UIKit
#endif

// Internal pieces the containers share: per-idiom sizes the containers agree on, a flow layout, the scroll edge fade,
// the bar and tool button styles, the filled field, and the few platform calls (pasteboard, sidebar toggle, cursor).
// Candidates for Foundation once the other areas settle.

/// The containers' sizes per idiom (the stylesheet's `.ck[data-idiom]` values).
enum ContMetrics {
  /// The sidebar's inset from its edges, and the gap between its section cards.
  static func sidebarInset(_ idiom: KitIdiom) -> CGFloat { idiom == .phone ? 16 : idiom == .pad ? 12 : 10 }
  static func sectionSpacing(_ idiom: KitIdiom) -> CGFloat { idiom == .phone ? 16 : idiom == .pad ? 12 : 10 }
  /// A card section's corners: 12 on the Mac, 18 on iPad, 22 on iPhone.
  static func cardRadius(_ idiom: KitIdiom) -> CGFloat { idiom == .phone ? 22 : idiom == .pad ? 18 : KitMetrics.radiusCard }
  /// A row's corners (the selection card's).
  static func rowRadius(_ idiom: KitIdiom, compact: Bool = false) -> CGFloat {
    compact && !idiom.isTouch ? 6 : idiom == .phone ? 14 : idiom == .pad ? KitMetrics.radiusLarge : KitMetrics.radius
  }
  /// A row's icon tile and the glyph inside it.
  static func rowTile(_ idiom: KitIdiom) -> CGFloat { KitMetrics.rowTile(idiom) }
  static func rowGlyph(_ idiom: KitIdiom) -> CGFloat { idiom == .phone ? 18 : idiom == .pad ? 17 : 12 }
  /// The bottom bar's square search button and action card: 32, 40 on iPad, 44 on iPhone.
  static func barHeight(_ idiom: KitIdiom) -> CGFloat { idiom == .phone ? 44 : idiom == .pad ? 40 : 32 }
  static func barRadius(_ idiom: KitIdiom) -> CGFloat { idiom == .phone ? 16 : idiom == .pad ? 14 : KitMetrics.radiusCard }
  /// A button inside a bar card.
  static func barButton(_ idiom: KitIdiom) -> CGSize {
    idiom == .phone ? CGSize(width: 40, height: 36) : idiom == .pad ? CGSize(width: 36, height: 32) : CGSize(width: 28, height: 26)
  }
  static func barButtonRadius(_ idiom: KitIdiom) -> CGFloat { idiom == .phone ? 12 : idiom == .pad ? 10 : 9 }
  /// A tool group in a toolbar: 32 on the Mac, 44 on touch.
  static func toolGroupHeight(_ idiom: KitIdiom) -> CGFloat { idiom.isTouch ? 44 : 32 }
  static func toolGroupRadius(_ idiom: KitIdiom) -> CGFloat { idiom.isTouch ? 16 : KitMetrics.radiusCard }
  static func toolHeight(_ idiom: KitIdiom) -> CGFloat { idiom.isTouch ? 36 : 26 }
  static func toolIconWidth(_ idiom: KitIdiom) -> CGFloat { idiom.isTouch ? 40 : 28 }
  static func toolRadius(_ idiom: KitIdiom) -> CGFloat { idiom.isTouch ? 12 : 9 }
  /// The kit's toolbar: 52 on the Mac (the title bar's height), 60 on iPad, 56 on iPhone.
  static func toolbarHeight(_ idiom: KitIdiom) -> CGFloat { idiom == .phone ? 56 : idiom == .pad ? 60 : 52 }
  /// How far the Mac's traffic lights reach into the title bar from the window's leading edge.
  static let windowControlsWidth: CGFloat = 80
  /// The 2pt ring around a focused or wrong field, at half strength (the secondary level of its colour).
  static let ringWidth: CGFloat = 2
}

// MARK: - Flow layout

/// Lays its views out in lines, wrapping when the next one doesn't fit (tags, action bars).
struct ContFlowLayout: Layout {
  var spacing: CGFloat = 6
  var lineSpacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    return ContFlow.size(of: ContFlow.frames(sizes, maxWidth: proposal.width, spacing: spacing, lineSpacing: lineSpacing))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let frames = ContFlow.frames(sizes, maxWidth: bounds.width, spacing: spacing, lineSpacing: lineSpacing)
    for (subview, frame) in zip(subviews, frames) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
        proposal: ProposedViewSize(frame.size))
    }
  }
}

/// The flow layout's math, apart from views so it can be tested.
enum ContFlow {
  /// Frames for `sizes` in lines no wider than `maxWidth` (`nil`: one line). Each line is as tall as its tallest
  /// item, and items in a line are centred on it. An item wider than the line gets a line of its own.
  static func frames(_ sizes: [CGSize], maxWidth: CGFloat?, spacing: CGFloat, lineSpacing: CGFloat) -> [CGRect] {
    let limit = maxWidth ?? .infinity
    var frames: [CGRect] = []
    var lineStart = 0
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0

    func closeLine(upTo end: Int) {
      for i in lineStart..<end { frames[i].origin.y = y + (lineHeight - frames[i].height) / 2 }
    }

    for (i, size) in sizes.enumerated() {
      if i > lineStart, x + spacing + size.width > limit {
        closeLine(upTo: i)
        y += lineHeight + lineSpacing
        x = 0
        lineHeight = 0
        lineStart = i
      }
      let originX = i == lineStart ? 0 : x + spacing
      frames.append(CGRect(origin: CGPoint(x: originX, y: y), size: size))
      x = originX + size.width
      lineHeight = max(lineHeight, size.height)
    }
    closeLine(upTo: sizes.count)
    return frames
  }

  static func size(of frames: [CGRect]) -> CGSize {
    frames.reduce(.zero) { CGSize(width: max($0.width, $1.maxX), height: max($0.height, $1.maxY)) }
  }
}

// MARK: - Scroll edge

extension View {
  /// Fades the bottom `length` points out (clear for the last 6), so a rounded card that runs on under a bar or the
  /// window's edge never ends in a flat cut. Off while nothing is under the edge.
  func contScrollEdge(_ isActive: Bool, length: CGFloat = 32) -> some View {
    mask {
      VStack(spacing: 0) {
        Rectangle()
        LinearGradient(colors: [.black, isActive ? .clear : .black], startPoint: .top, endPoint: .bottom)
          .frame(height: length - 6)
        Rectangle().opacity(isActive ? 0 : 1).frame(height: 6)
      }
      .animation(.kitFast, value: isActive)
    }
  }
}

/// A vertical scroll view that fades its bottom edge while content runs on under it.
struct ContEdgeScroll<Content: View>: View {
  @ViewBuilder var content: Content
  @State private var viewport: CGFloat = 0
  @State private var contentBottom: CGFloat = 0
  @State private var space = UUID()
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    ScrollView {
      content.modifier(ContBottomReader(space: space, bottom: $contentBottom))
    }
    .coordinateSpace(.named(space))
    .modifier(ContHeightReader(height: $viewport))
    .contScrollEdge(contentBottom > viewport + 0.5, length: idiom == .phone ? 48 : idiom == .pad ? 40 : 32)
  }
}

/// Reports a view's bottom edge in a named coordinate space (a scroll view's), as the content scrolls.
struct ContBottomReader: ViewModifier {
  let space: UUID
  @Binding var bottom: CGFloat

  func body(content: Content) -> some View {
    let space = space
    return content.onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(space)).maxY } action: { bottom = $0 }
  }
}

/// Reports a view's height.
struct ContHeightReader: ViewModifier {
  @Binding var height: CGFloat

  func body(content: Content) -> some View {
    content.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
  }
}

// MARK: - Bar buttons

/// Buttons in a card bar: the sidebar's bottom bar (icon-only, quiet) and action bars (labelled, the label colour,
/// destructive red).
struct ContBarButtonStyle: ButtonStyle {
  var labeled = false

  func makeBody(configuration: Configuration) -> some View {
    ContBarButton(configuration: configuration, labeled: labeled)
  }
}

private struct ContBarButton: View {
  let configuration: ButtonStyleConfiguration
  let labeled: Bool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    let size = ContMetrics.barButton(idiom)
    let shape = RoundedRectangle(cornerRadius: ContMetrics.barButtonRadius(idiom), style: .continuous)
    configuration.label
      .kitFont(labeled ? .callout : .body)
      .fontWeight(labeled ? .medium : .regular)
      .lineLimit(1)
      .foregroundStyle(foreground)
      .padding(.horizontal, labeled ? (idiom.isTouch ? 12 : 8) : 4)
      .frame(minWidth: size.width, minHeight: size.height)
      .background {
        shape.fill(configuration.isPressed ? AnyShapeStyle(.kitPress) : isHovered && isEnabled ? AnyShapeStyle(.kitFill) : AnyShapeStyle(Color.clear))
      }
      .contentShape(shape)
      .opacity(isEnabled ? 1 : 0.4)
      .onHover { isHovered = $0 }
      .animation(.kitFast, value: isHovered)
  }

  private var foreground: AnyShapeStyle {
    if configuration.role == .destructive { return AnyShapeStyle(Hue.red.text) }
    if labeled || isHovered { return AnyShapeStyle(.kitLabel) }
    return AnyShapeStyle(.kitSecondary)
  }
}

private struct ContBarLabelStyle: LabelStyle {
  var iconOnly: Bool

  func makeBody(configuration: Configuration) -> some View {
    if iconOnly {
      configuration.icon
    } else {
      HStack(spacing: 5) {
        configuration.icon.imageScale(.small)
        configuration.title
      }
    }
  }
}

/// The card a bar's buttons share (the sidebar's actions, an inspector's action bar).
struct ContBarCard<Content: View>: View {
  var labeled = false
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    let inset: CGFloat = idiom.isTouch ? 4 : 3
    // The label style sits on the card rather than in the button style, so a button's own `.labelStyle(.iconOnly)`
    // is closer to its label and wins.
    content
      .labelStyle(ContBarLabelStyle(iconOnly: !labeled))
      .buttonStyle(ContBarButtonStyle(labeled: labeled))
      .padding(inset)
      .frame(minHeight: ContMetrics.barHeight(idiom))
      .kitSurface(.card, cornerRadius: ContMetrics.barRadius(idiom))
  }
}

// MARK: - Tools

/// A tool inside a tool group: 26pt (36 on touch), 9pt corners, a fill on hover and press.
struct ContToolButtonStyle: ButtonStyle {
  var iconOnly = false

  func makeBody(configuration: Configuration) -> some View {
    ContToolButton(configuration: configuration, iconOnly: iconOnly)
  }
}

private struct ContToolButton: View {
  let configuration: ButtonStyleConfiguration
  let iconOnly: Bool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.contToolIsOn) private var isOn
  @State private var isHovered = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: ContMetrics.toolRadius(idiom), style: .continuous)
    let height = ContMetrics.toolHeight(idiom)
    configuration.label
      .kitFont(.body)
      .fontWeight(.medium)
      .lineLimit(1)
      .foregroundStyle(
        configuration.role == .destructive ? AnyShapeStyle(Hue.red.text)
          : isEnabled ? AnyShapeStyle(.kitLabel) : AnyShapeStyle(.kitTertiary))
      .padding(.horizontal, iconOnly ? 0 : (idiom.isTouch ? 10 : 8))
      .frame(minWidth: iconOnly ? ContMetrics.toolIconWidth(idiom) : height, minHeight: height)
      .background {
        if isOn || configuration.isPressed {
          shape.fill(.kitFill)
        } else if isHovered && isEnabled {
          shape.fill(.kitHover)
        }
      }
      .contentShape(shape)
      .onHover { isHovered = $0 }
      .animation(.kitFast, value: isHovered)
  }
}

extension EnvironmentValues {
  /// A tool drawn as on (a toggled tool, the open overflow menu).
  @Entry var contToolIsOn: Bool = false
}

// MARK: - Filled field

/// The kit's filled field around a text field: 32pt, 9pt corners, the field well; focused it takes the control ground
/// and the 2pt half-accent ring, wrong the half-red ring. A trailing live icon sits as far from the right edge as from
/// the top and bottom.
struct ContFilledField<Field: View>: View {
  var isFocused: Bool
  var isError: Bool
  var status: WorkStatus = .idle
  var systemImage: String = "magnifyingglass"
  var hue: Hue = .accent
  @ViewBuilder var field: Field
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    let height: CGFloat = idiom.isTouch ? 40 : 32
    let shape = RoundedRectangle(cornerRadius: idiom.isTouch ? 11 : 9, style: .continuous)
    let icon: CGFloat = idiom.isTouch ? 22 : 18
    HStack(spacing: 8) {
      field
        .textFieldStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
      if status != .idle {
        LiveIcon(systemImage: systemImage, hue: hue, status: status, size: icon)
          .transition(.opacity)
      }
    }
    .padding(.leading, 10)
    .padding(.trailing, status != .idle ? (height - icon) / 2 : 10)
    .frame(height: height)
    .background {
      shape.fill(isFocused ? AnyShapeStyle(KitColor.control) : AnyShapeStyle(.kitField))
    }
    .overlay {
      if isFocused || isError {
        RoundedRectangle(cornerRadius: (idiom.isTouch ? 11 : 9) + ContMetrics.ringWidth, style: .continuous)
          .strokeBorder((isError ? Hue.red : Hue.accent).soft(0.5), lineWidth: ContMetrics.ringWidth)
          .padding(-ContMetrics.ringWidth)
          .allowsHitTesting(false)
      }
    }
    .animation(.kitFast, value: isFocused)
    .animation(.kit, value: status)
  }
}

// MARK: - Keycaps

/// A shortcut drawn as keys ("⌘⇧F" → ⌘ ⇧ F): raised caps on the card.
struct ContKeycaps: View {
  var shortcut: String

  var body: some View {
    HStack(spacing: 2) {
      ForEach(Array(ContKeycaps.keys(shortcut).enumerated()), id: \.offset) { _, key in
        Text(key)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.kitSecondary)
          .frame(minWidth: 18, minHeight: 18)
          .padding(.horizontal, key.count > 1 ? 4 : 0)
          .background { SurfaceShape(surface: .raised, cornerRadius: KitMetrics.radiusXS) }
      }
    }
    .accessibilityLabel(shortcut)
  }

  /// One key per modifier symbol; the rest is the key itself ("⌘⇧F" → ["⌘", "⇧", "F"], "⌘Return" → ["⌘", "Return"]).
  static func keys(_ shortcut: String) -> [String] {
    let modifiers: Set<Character> = ["⌘", "⇧", "⌥", "⌃"]
    var keys: [String] = []
    var rest = Substring(shortcut)
    while let first = rest.first, modifiers.contains(first) {
      keys.append(String(first))
      rest = rest.dropFirst()
    }
    let key = rest.trimmingCharacters(in: .whitespaces)
    if !key.isEmpty { keys.append(key) }
    return keys
  }
}

// MARK: - Platform

/// The few platform calls the containers need, kept out of their public API.
@MainActor
enum ContPlatform {
  static func copy(_ string: String) {
    #if canImport(AppKit)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(string, forType: .string)
    #elseif canImport(UIKit)
      UIPasteboard.general.string = string
    #endif
  }

  static func pastedString() -> String? {
    #if canImport(AppKit)
      NSPasteboard.general.string(forType: .string)
    #elseif canImport(UIKit)
      UIPasteboard.general.hasStrings ? UIPasteboard.general.string : nil
    #else
      nil
    #endif
  }

  /// Whether the Mac can show or hide the window's sidebar through the responder chain (a `NavigationSplitView`).
  static var canToggleSidebar: Bool {
    #if canImport(AppKit)
      true
    #else
      false
    #endif
  }

  /// Whether Shift is held (a ⇧-click extends a selection); always false on touch.
  static var isShiftDown: Bool {
    #if canImport(AppKit)
      NSEvent.modifierFlags.contains(.shift)
    #else
      false
    #endif
  }

  static func toggleSidebar() {
    #if canImport(AppKit)
      NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
    #endif
  }

  /// What a double click on the title bar does, per System Settings (Desktop & Dock): zoom (the default), minimize,
  /// or nothing.
  static func titleBarDoubleClick() {
    #if canImport(AppKit)
      guard let window = NSApp.keyWindow else { return }
      switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
      case "Minimize": window.performMiniaturize(nil)
      case "None": break
      default: window.performZoom(nil)
      }
    #endif
  }
}

extension View {
  /// The column-resize pointer over a divider's grab area (the row-resize one for a `vertical` split).
  @ViewBuilder
  func contResizeCursor(vertical: Bool = false) -> some View {
    #if canImport(AppKit)
      if #available(macOS 15.0, *) {
        pointerStyle(vertical ? .rowResize : .columnResize)
      } else {
        onHover { inside in
          if inside { (vertical ? NSCursor.resizeUpDown : NSCursor.resizeLeftRight).push() } else { NSCursor.pop() }
        }
      }
    #else
      self
    #endif
  }
}

// MARK: - Window title (macOS 14)

/// Hides the title of the window it sits in while `hides` is true, and shows it again when it goes (macOS 14, where
/// the toolbar's title can't be removed). Nothing on other platforms.
struct ContWindowTitleHidden: View {
  var hides: Bool

  var body: some View {
    #if os(macOS)
      ContWindowTitleRepresentable(hides: hides).accessibilityHidden(true)
    #else
      Color.clear
    #endif
  }
}

#if os(macOS)
  private struct ContWindowTitleRepresentable: NSViewRepresentable {
    var hides: Bool

    func makeNSView(context: Context) -> ContWindowTitleView { ContWindowTitleView() }

    func updateNSView(_ view: ContWindowTitleView, context: Context) {
      view.hides = hides
    }

    static func dismantleNSView(_ view: ContWindowTitleView, coordinator: ()) {
      view.hides = false
    }
  }

  private final class ContWindowTitleView: NSView {
    var hides = false {
      didSet { if hides != oldValue { apply() } }
    }
    private weak var hiddenIn: NSWindow?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window !== hiddenIn, let old = hiddenIn {
        old.titleVisibility = .visible
        hiddenIn = nil
      }
      apply()
    }

    private func apply() {
      if hides, let window {
        window.titleVisibility = .hidden
        hiddenIn = window
      } else if let old = hiddenIn {
        old.titleVisibility = .visible
        hiddenIn = nil
      }
    }
  }
#endif
