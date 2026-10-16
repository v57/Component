import ComponentKit
import SwiftUI

/// The ComponentKit catalog: every component in every state, light and dark, with the code to use it.
@main
struct ComponentApp: App {
  @State private var model = CatalogModel()

  var body: some Scene {
    WindowGroup("Component") {
      CatalogView()
        .environment(model)
        .kitToasts()
        .environment(\.kitIncreaseContrast, model.increaseContrast)
        .preferredColorScheme(model.appearance.colorScheme)
        .componentKit(accent: model.accent.color)
        .frame(width: model.windowWidth, height: model.windowWidth.map { _ in 700 })
    }
    .defaultSize(width: 1320, height: 900)
    // A fixed width (`--width`) sizes the window to it.
    .windowResizability(model.windowWidth == nil ? .automatic : .contentSize)
  }
}

// MARK: - Model

/// What the catalog shows and how: the page, and the overrides the toolbar sets (appearance, accent, idiom, contrast,
/// an inactive window).
@MainActor @Observable
final class CatalogModel {
  var page: Page = .buttons
  var appearance: Appearance = .system
  var accent: Accent = .blue
  /// `nil` keeps the platform's own idiom.
  var idiom: KitIdiom?
  var increaseContrast = false
  var inactiveWindow = false
  /// The kit's bars (toolbar, sidebar) as `safeAreaBar`s instead of plain insets (`--toolbar-bar`).
  var toolbarBar = false
  /// The section a page opens scrolled to (`--section <title>`).
  var section: String?
  /// A fixed window width (`--width <points>`), to capture the toolbar as it compacts.
  var windowWidth: CGFloat?
  /// Opens with the sidebar hidden (`--no-sidebar`).
  var hidesSidebar = false
  /// Opens the sidebar scrolled to its middle (`--sidebar-middle`), so rows run under both of its bars.
  var sidebarMiddle = false

  init() {
    #if DEBUG
      applyLaunchArguments(ProcessInfo.processInfo.arguments)
    #endif
  }

  #if DEBUG
    /// `--page <id>`, `--section <title>`, `--dark`, `--light`, `--idiom mac|pad|phone`, `--accent <id>`, `--contrast`, `--inactive`,
    /// `--toolbar-bar`, `--sidebar-middle`, `--width <points>`, `--no-sidebar`: opens any page in any state without clicking (for window captures).
    func applyLaunchArguments(_ arguments: [String]) {
      func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
      }
      if let id = value(after: "--page"), let page = Page(rawValue: id) { self.page = page }
      if arguments.contains("--dark") { appearance = .dark }
      if arguments.contains("--light") { appearance = .light }
      switch value(after: "--idiom") {
      case "mac": idiom = .mac
      case "pad": idiom = .pad
      case "phone": idiom = .phone
      default: break
      }
      if let id = value(after: "--accent"), let accent = Accent(rawValue: id) { self.accent = accent }
      if arguments.contains("--contrast") { increaseContrast = true }
      if arguments.contains("--inactive") { inactiveWindow = true }
      if arguments.contains("--toolbar-bar") { toolbarBar = true }
      section = value(after: "--section")
      windowWidth = value(after: "--width").flatMap(Double.init).map { CGFloat($0) }
      hidesSidebar = arguments.contains("--no-sidebar")
      sidebarMiddle = arguments.contains("--sidebar-middle")
    }
  #endif
}

enum Appearance: String, CaseIterable, Hashable {
  case system, light, dark

  var title: String {
    switch self {
    case .system: "Auto"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var systemImage: String {
    switch self {
    case .system: "circle.lefthalf.filled"
    case .light: "sun.max"
    case .dark: "moon"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

/// The apps' accents.
enum Accent: String, CaseIterable, Hashable, Identifiable {
  case blue, git, database, red, v57

  var id: String { rawValue }

  var title: String {
    switch self {
    case .blue: "System Blue · Shell, Markdown, Code, Dev"
    case .git: "Git Orange"
    case .database: "Database Blue"
    case .red: "Red · Get, Player"
    case .v57: "v57 Red"
    }
  }

  var hex: UInt32 {
    switch self {
    case .blue: 0x007aff
    case .git: 0xf05434
    case .database: 0x0066cc
    case .red: 0xff3b30
    case .v57: 0xff2740
    }
  }

  var color: Color {
    Color(
      .sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255,
      blue: Double(hex & 0xff) / 255)
  }

  var hexString: String { "#" + String(format: "%06x", hex) }
}
