import SwiftUI

/// The Settings window: the kit sidebar listing the panes (the app's own first, then the shared ones under their
/// section, such as "v57": Updates, iCloud, About) with the selected pane's form beside it, under its title. The
/// same layout on macOS and iPad at touch sizes. On iPhone the panes are rows in a card (a tile, the name, the
/// pane's `value`, a chevron), and a row pushes its pane on the `NavigationStack` the settings sit in (put one
/// around them where there's none), under the kit's toolbar (Back, the pane's name, "Settings"). Panes hold any view, usually form cards; the kit only hosts
/// shared panes such as UpdateKit's or Vault's, which their packages provide.
///
/// ```swift
/// @AppStorage("settings.pane") private var pane = "General"
///
/// KitSettings(selection: $pane) {
///   SettingsPane("General", systemImage: "gearshape") { FormCard { … } }
///   SettingsPane("Updates", systemImage: "arrow.down.circle", hue: .blue, section: "v57") { UpdatesSettings() }
///   SettingsPane("About", systemImage: "info.circle", section: "v57") { AboutSettings() }
/// }
/// ```
public struct KitSettings<Content: View>: View {
  @Binding var selection: String
  var window: KitSettingsWindow
  var content: Content
  @State private var panes: [SettingsPaneInfo] = []
  @State private var showsPane = false
  @FocusState private var isSidebarFocused: Bool
  @Environment(\.kitIdiom) private var idiom

  /// Settings with the panes in `content`; `window` says what the window around them looks like (on the Mac).
  ///
  /// Every Mac app's Settings window is one setup: `window: .hiddenTitleBar`, a fixed size, and the scene's
  /// `.windowStyle(.hiddenTitleBar)`. The kit clears the system title and bar itself, so the sidebar runs up under
  /// the window's buttons and the pane's title sits beside them, with no workaround in the app.
  ///
  /// ```swift
  /// Settings {
  ///   KitSettings(selection: $pane, window: .hiddenTitleBar) { … }
  ///     .frame(width: 640, height: 520)
  ///     .componentKit()
  /// }
  /// .windowStyle(.hiddenTitleBar)
  ///
  /// Settings { SettingsView().componentKit() }                                         // KitSettings(…, window: .titled)
  /// ```
  public init(
    selection: Binding<String>, window: KitSettingsWindow = .framed, @ViewBuilder content: () -> Content
  ) {
    self._selection = selection
    self.window = window
    self.content = content()
  }

  /// The room left at the top of the sidebar, and the height of the pane's title row.
  private var topInset: CGFloat {
    guard idiom == .mac else { return 20 }
    return window == .titled ? KitMetrics.gutter : KitMetrics.titlebarHeight
  }

  private var titleHeight: CGFloat {
    guard idiom == .mac else { return 56 }
    return window == .titled ? 40 : KitMetrics.titlebarHeight
  }

  /// The selected pane, or the first one when the selection names none.
  private var current: SettingsPaneInfo? { panes.first { $0.id == selection } ?? panes.first }

  public var body: some View {
    Group {
      if idiom == .phone {
        // The panes list themselves from `content`, so it stays in the hierarchy, out of sight, under the list.
        phoneList
          .background { ZStack { content }.hidden().accessibilityHidden(true) }
          .modifier(SettingsPush(isPresented: $showsPane) { phonePane })
      } else if isUnderTitleBar {
        // The reader stays in the safe area, so it sees the title bar's height; the columns run up under it.
        GeometryReader { proxy in
          columns(titleBar: proxy.safeAreaInsets.top)
            .ignoresSafeArea(.container, edges: .top)
        }
      } else {
        columns(titleBar: nil)
      }
    }
    .environment(\.dataSettingsSelection, current?.id ?? "")
    .onPreferenceChange(SettingsPanesKey.self) { value in
      MainActor.assumeIsolated { panes = value }
    }
    .modifier(SettingsTitleBarCleared(isOn: isUnderTitleBar))
  }

  /// The settings run up under the window's (hidden) title bar.
  private var isUnderTitleBar: Bool { window == .hiddenTitleBar && idiom == .mac }

  /// The sidebar and the selected pane; `titleBar` is the height of the title bar they run under, when they do.
  private func columns(titleBar: CGFloat?) -> some View {
    HStack(spacing: 0) {
      sidebar.frame(width: idiom.size(190, touch: 260))
      detail(titleBar: titleBar)
    }
  }

  // MARK: Sidebar

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 2) {
      ForEach(sections, id: \.self) { section in
        if !section.isEmpty {
          Text(section)
            .kitFont(.sectionHeader)
            .padding(EdgeInsets(top: 14, leading: 10, bottom: 4, trailing: 0))
        }
        ForEach(panes.filter { $0.section == section }) { pane in
          SettingsSidebarRow(pane: pane, isSelected: pane.id == current?.id) {
            withKitAnimation { selection = pane.id }
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(EdgeInsets(top: topInset, leading: KitMetrics.gutter, bottom: 0, trailing: KitMetrics.gutter))
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background(.kitSidebar)
    .focusable()
    .focused($isSidebarFocused)
    .focusEffectDisabled()
    .onKeyPress(.upArrow) { move(by: -1) }
    .onKeyPress(.downArrow) { move(by: 1) }
  }

  /// Section names in the order they first appear; "" (the app's own panes) leads.
  private var sections: [String] {
    var seen: [String] = []
    for pane in panes where !seen.contains(pane.section) { seen.append(pane.section) }
    return seen.sorted { $0.isEmpty && !$1.isEmpty }
  }

  private func move(by offset: Int) -> KeyPress.Result {
    let ordered = sections.flatMap { section in panes.filter { $0.section == section }.map(\.id) }
    guard let next = DataNav.moved(current?.id, by: offset, in: ordered) else { return .ignored }
    withKitAnimation { selection = next }
    return .handled
  }

  // MARK: iPhone

  /// The panes as rows in a card per section, under the section's name.
  private var phoneList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: KitMetrics.gutter) {
        ForEach(sections, id: \.self) { section in
          if !section.isEmpty {
            Text(section).kitFont(.sectionHeader).padding(.leading, 10).padding(.top, 6)
          }
          VStack(spacing: 0) {
            ForEach(panes.filter { $0.section == section }) { pane in
              SettingsPhoneRow(pane: pane) {
                selection = pane.id
                showsPane = true
              }
            }
          }
          .padding(4)
          .kitSurface(.card)
        }
      }
      .padding(EdgeInsets(top: 4, leading: KitMetrics.gutter + 4, bottom: 24, trailing: KitMetrics.gutter + 4))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.kitWindow)
  }

  /// The selected pane, pushed: its form under the kit's toolbar.
  private var phonePane: some View {
    ZStack(alignment: .topLeading) { content }
      .environment(\.dataSettingsSelection, current?.id ?? "")
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(.kitWindow)
      .kitPane(.content)
      .kitToolbar(
        current?.title ?? "", meta: ["Settings"], systemImage: current?.systemImage ?? "gearshape",
        hue: current?.hue ?? .gray
      ) {}
  }

  // MARK: Detail

  /// The pane under its title. Under a title bar the title is centred on the window's buttons (a Settings window's
  /// bar is 32pt, a window with a toolbar 52); the row keeps its height, so the panes start where they always do.
  private func detail(titleBar: CGFloat?) -> some View {
    let titleLine = titleBar.map { $0 > 0 ? min($0, titleHeight) : titleHeight } ?? titleHeight
    return VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Text(current?.title ?? "")
          .kitFont(.headline)
          .contentTransition(.opacity)
      }
      .padding(.horizontal, 24)
      .frame(height: titleLine, alignment: .center)
      .frame(height: titleHeight, alignment: .top)
      ZStack(alignment: .topLeading) { content }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.kitWindow)
  }
}

/// The window `KitSettings` sits in, on the Mac (iPad and iPhone ignore it).
public enum KitSettingsWindow: Hashable, Sendable {
  /// Room for a title bar drawn over the sidebar's top (52pt), as when the settings sit in a frame of their own or
  /// a window whose content already runs under its title bar.
  case framed
  /// A window with a hidden title bar (`.windowStyle(.hiddenTitleBar)`, a Settings scene too): the kit runs its
  /// sidebar and title row up under the window's buttons itself, no offset needed, and takes the system title and
  /// the bar's background out (a Settings scene keeps both whatever its style). The standard Settings window.
  case hiddenTitleBar
  /// A standard titled window (a plain `Settings` scene): the content starts under the title bar, so the sidebar
  /// starts 8pt down and the pane's title row is 40pt.
  case titled
}

/// Clears the title bar the settings run up under. A `Settings` scene keeps its title bar whatever its window style
/// (the system title over an opaque bar), so the kit clears it itself: no system title (the window keeps it for the
/// Window menu) and no bar background, so the sidebar and the pane's title show under the window's buttons. macOS 14
/// hides the window's title and the toolbar's background instead.
private struct SettingsTitleBarCleared: ViewModifier {
  let isOn: Bool

  func body(content: Content) -> some View {
    if isOn {
      content
        #if os(macOS)
          .kitHidesSystemTitle()
          .modifier(ContToolbarBackgroundHidden())
        #endif
    } else {
      content
    }
  }
}

struct SettingsPaneInfo: Identifiable, Hashable {
  var id: String
  var title: String
  var systemImage: String
  var hue: Hue
  var section: String
  var value: String?
}

/// Pushes the pane on iPhone, on the navigation stack around the settings.
private struct SettingsPush<Pane: View>: ViewModifier {
  @Binding var isPresented: Bool
  @ViewBuilder var pane: Pane

  func body(content: Content) -> some View {
    #if os(iOS)
      content.navigationDestination(isPresented: $isPresented) { pane.navigationBarBackButtonHidden(true) }
    #else
      content.navigationDestination(isPresented: $isPresented) { pane }
    #endif
  }
}

/// A pane's row on iPhone: its solid tile, the name, the pane's value and a chevron, at touch height.
private struct SettingsPhoneRow: View {
  let pane: SettingsPaneInfo
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Tile(systemImage: pane.systemImage, hue: pane.hue, size: 30, style: .solid)
        Text(pane.title).kitFont(.body).lineLimit(1)
        Spacer(minLength: 8)
        if let value = pane.value {
          Text(value).kitFont(.caption).foregroundStyle(.kitTertiary).lineLimit(1)
        }
        KitPushChevron()
      }
      .padding(.horizontal, 8)
      .frame(height: 52)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityValue(pane.value ?? "")
  }
}

struct SettingsPanesKey: PreferenceKey {
  static let defaultValue: [SettingsPaneInfo] = []
  static func reduce(value: inout [SettingsPaneInfo], nextValue: () -> [SettingsPaneInfo]) {
    value.append(contentsOf: nextValue())
  }
}

extension EnvironmentValues {
  @Entry var dataSettingsSelection: String = ""
}

/// A row of the settings sidebar: a solid tile (the accent when selected) and the name; the selected row is raised.
private struct SettingsSidebarRow: View {
  let pane: SettingsPaneInfo
  let isSelected: Bool
  let action: () -> Void
  @State private var isHovered = false
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitWindowIsActive) private var isActive

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Tile(
          systemImage: pane.systemImage, hue: isSelected && isActive ? .accent : pane.hue,
          size: idiom.size(20, touch: 28), style: .solid)
        Text(pane.title).lineLimit(1)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 6)
      .frame(height: KitMetrics.row(idiom))
      .background {
        if isSelected {
          SurfaceShape(surface: .raised, cornerRadius: KitMetrics.radius)
        } else if isHovered {
          RoundedRectangle(cornerRadius: KitMetrics.radius, style: .continuous).fill(.kitHover)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .kitHover { isHovered = $0 }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// One pane of `KitSettings`: its sidebar row (title, glyph, tile hue, the section it's listed under, and on
/// iPhone its `value`, such as "On" or "iCloud") and its content, shown beside the sidebar when selected (pushed on
/// iPhone), scrolling, with an 18pt rhythm between its cards.
///
/// ```swift
/// SettingsPane("Editor", systemImage: "character.cursor.ibeam", hue: .blue, value: wrap ? "Wrap" : nil) {
///   FormCard { FormRow("Wrap lines") { Toggle("", isOn: $wrap) } }
/// }
/// ```
public struct SettingsPane<Content: View>: View {
  var info: SettingsPaneInfo
  var content: Content
  @Environment(\.dataSettingsSelection) private var selection
  @Environment(\.dataRendersFlat) private var flat
  @Environment(\.kitIdiom) private var idiom

  public init(
    _ title: String, systemImage: String, hue: Hue = .gray, section: String? = nil, value: String? = nil,
    id: String? = nil, @ViewBuilder content: () -> Content
  ) {
    self.info = SettingsPaneInfo(
      id: id ?? title, title: title, systemImage: systemImage, hue: hue, section: section ?? "", value: value)
    self.content = content()
  }

  public var body: some View {
    ZStack(alignment: .topLeading) {
      if selection == info.id {
        let stack = VStack(alignment: .leading, spacing: 18) { content }
          .padding(
            EdgeInsets(
              top: 4,
              leading: idiom == .phone ? KitMetrics.gutter + 4 : 24,
              bottom: 24,
              trailing: idiom == .phone ? KitMetrics.gutter + 4 : 24))
          .frame(maxWidth: .infinity, alignment: .topLeading)
        Group {
          if flat { stack } else { ScrollView { stack } }
        }
        .transition(.opacity)
      }
    }
    .preference(key: SettingsPanesKey.self, value: [info])
  }
}

#Preview("Settings") {
  @Previewable @State var pane = "Updates"
  KitSettings(selection: $pane) {
    SettingsPane("General", systemImage: "gearshape") { Text("General settings") }
    SettingsPane("Updates", systemImage: "arrow.down", hue: .blue, section: "v57") {
      Text("Check for updates automatically").padding(12).frame(maxWidth: .infinity, alignment: .leading).kitCard()
    }
    SettingsPane("iCloud", systemImage: "icloud", section: "v57") { Text("Sync with iCloud") }
    SettingsPane("About", systemImage: "info", section: "v57") { Text("About") }
  }
  .frame(width: 640, height: 520)
  .componentKit()
}
