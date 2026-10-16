import SwiftUI

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#endif

// Small pieces the Data components share: the NULL chip, the soft header button, flat rendering for snapshots,
// keyboard navigation through `@ViewBuilder` content, the app's icon, name and version, and the merged-row shape.

// MARK: - NULL

/// NULL in a cell or a value: a small quiet chip, never the bare word.
struct DataNullChip: View {
  var body: some View {
    Text("NULL")
      .font(.system(size: 10, weight: .medium, design: .monospaced))
      .foregroundStyle(.kitQuiet)
      .padding(.horizontal, 5)
      .frame(height: 16)
      .background(.kitFill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
      .fixedSize()
      .accessibilityLabel("null")
  }
}

// MARK: - Buttons

/// The soft button of diff, conflict and run headers: the field fill without a border in light, a raised step in
/// dark (a button never reads as a hole). 24pt (22 with `.controlSize(.small)`), 12pt medium.
struct DataSoftButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    DataSoftButton(configuration: configuration)
  }
}

private struct DataSoftButton: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.colorScheme) private var scheme
  @Environment(\.controlSize) private var controlSize
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitIdiom) private var idiom
  @State private var isHovered = false

  var body: some View {
    let small = controlSize == .small || controlSize == .mini
    let shape = RoundedRectangle(cornerRadius: small ? 6 : 7, style: .continuous)
    configuration.label
      .font(.system(size: small ? 11 : 12, weight: .medium))
      .labelStyle(KitButtonLabelStyle(iconOnly: false))
      .lineLimit(1)
      .foregroundStyle(configuration.role == .destructive ? AnyShapeStyle(Hue.red.text) : AnyShapeStyle(.kitLabel))
      .padding(.horizontal, small ? 8 : 10)
      .frame(height: (small ? 22 : 24) + (idiom.isTouch ? 8 : 0))
      .background {
        if scheme == .dark {
          SurfaceShape(surface: .raised, cornerRadius: small ? 6 : 7)
        } else {
          shape.fill(.kitField)
        }
      }
      .overlay { shape.fill(Color.primary.opacity(configuration.isPressed ? 0.1 : isHovered ? 0.04 : 0)) }
      .opacity(isEnabled ? 1 : 0.45)
      .contentShape(shape)
      .onHover { isHovered = $0 }
      .animation(.kitFast, value: isHovered)
  }
}

extension ButtonStyle where Self == DataSoftButtonStyle {
  static var dataSoft: DataSoftButtonStyle { DataSoftButtonStyle() }
}

// MARK: - Rendering without scroll views

extension EnvironmentValues {
  /// Lays scrolling content out flat (no `ScrollView`), for snapshots: `ImageRenderer` draws scroll views blank.
  @Entry var dataRendersFlat: Bool = false
}

/// A scroll view, or its content laid out flat when `dataRendersFlat` is set.
struct DataScroll<Content: View>: View {
  var axes: Axis.Set = .vertical
  @ViewBuilder var content: Content
  @Environment(\.dataRendersFlat) private var flat

  var body: some View {
    if flat {
      content
    } else {
      ScrollView(axes) { content }
    }
  }
}

// MARK: - Keyboard navigation

/// The order of the selectable items in a container (a palette, the welcome window's recents), collected from the
/// items themselves so the container can move a selection through views it only knows as a `@ViewBuilder`.
struct DataNavItemsKey: PreferenceKey {
  static let defaultValue: [String] = []
  static func reduce(value: inout [String], nextValue: () -> [String]) { value.append(contentsOf: nextValue()) }
}

/// Shared between a navigable container and its items: which one is selected, and which one Return opened.
@MainActor @Observable final class DataNavModel {
  var ids: [String] = []
  var selected: String?
  /// Bumped when Return (or a click) opens `activated`; items watch it and run their own action.
  private(set) var activation = 0
  private(set) var activated: String?

  /// Keeps the selection on an item that exists: the first one when it went away.
  func update(ids: [String]) {
    self.ids = ids
    if let selected, ids.contains(selected) { return }
    selected = ids.first
  }

  func move(by offset: Int) {
    selected = DataNav.moved(selected, by: offset, in: ids)
  }

  func activate(_ id: String? = nil) {
    guard let id = id ?? selected else { return }
    selected = id
    activated = id
    activation += 1
  }
}

enum DataNav {
  /// The id `offset` steps from `current`, clamped to the ends; the first (or last) one when nothing is selected.
  static func moved(_ current: String?, by offset: Int, in ids: [String]) -> String? {
    guard !ids.isEmpty else { return nil }
    guard let current, let index = ids.firstIndex(of: current) else {
      return offset >= 0 ? ids.first : ids.last
    }
    return ids[min(max(index + offset, 0), ids.count - 1)]
  }
}

extension View {
  /// Registers an item with the navigable container around it and runs `action` when the container opens it.
  func dataNavItem(_ id: String, model: DataNavModel?, action: (() -> Void)?) -> some View {
    modifier(DataNavItem(id: id, model: model, action: action))
  }
}

private struct DataNavItem: ViewModifier {
  let id: String
  let model: DataNavModel?
  let action: (() -> Void)?

  func body(content: Content) -> some View {
    content
      .preference(key: DataNavItemsKey.self, value: [id])
      .onChange(of: model?.activation ?? 0) {
        if model?.activated == id { action?() }
      }
  }
}

// MARK: - Platform

/// What the kit reads from the platform for the welcome window and About: the app's icon, name and version.
enum DataPlatform {
  @MainActor static var appIcon: Image? {
    #if os(macOS)
      Image(nsImage: NSApplication.shared.applicationIconImage)
    #elseif os(iOS)
      let info = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
      let primary = info?["CFBundlePrimaryIcon"] as? [String: Any]
      let name = (primary?["CFBundleIconFiles"] as? [String])?.last
      return name.flatMap { UIImage(named: $0) }.map { Image(uiImage: $0) }
    #else
      nil
    #endif
  }

  static var appName: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ProcessInfo.processInfo.processName
  }

  static var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
  }
}

// MARK: - Window buttons

/// Hides the window's own close, minimize and zoom buttons while the view it backs fills the window (the welcome
/// window draws its own close button where they would sit), and shows them again when it goes. A view inside a
/// bigger window leaves them alone. Nothing on other platforms.
struct DataWindowButtonsHidden: View {
  var body: some View {
    #if os(macOS)
      DataWindowButtonsHiddenView().accessibilityHidden(true)
    #else
      Color.clear
    #endif
  }
}

#if os(macOS)
  private struct DataWindowButtonsHiddenView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DataWindowButtonsView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
  }

  private final class DataWindowButtonsView: NSView {
    private weak var hiddenIn: NSWindow?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window !== hiddenIn { setButtons(in: hiddenIn, hidden: false) }
      update()
    }

    override func layout() {
      super.layout()
      update()
    }

    private func update() {
      guard let window, let content = window.contentView else { return }
      let fills = abs(bounds.width - content.bounds.width) < 2 && abs(bounds.height - content.bounds.height) < 2
      setButtons(in: window, hidden: fills)
    }

    private func setButtons(in window: NSWindow?, hidden: Bool) {
      guard let window else { return }
      for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        window.standardWindowButton(kind)?.isHidden = hidden
      }
      hiddenIn = hidden ? window : nil
    }
  }
#endif

// MARK: - Shapes

/// A rounded rectangle whose top or bottom corners can be square, so consecutive selected rows merge into one shape.
struct DataRunShape: Shape {
  var radius: CGFloat
  var squareTop: Bool
  var squareBottom: Bool

  func path(in rect: CGRect) -> Path {
    let top = squareTop ? 0 : radius
    let bottom = squareBottom ? 0 : radius
    return UnevenRoundedRectangle(
      topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom, topTrailingRadius: top,
      style: .continuous
    ).path(in: rect)
  }
}
