import SwiftUI

/// The Settings window: the kit sidebar listing the panes (the app's own first, then the shared ones under their
/// section, such as "v57": Updates, iCloud, About) with the selected pane's form beside it, under its title. The
/// same layout on macOS and iPad at touch sizes; on iPhone the list pushes the pane. Panes hold any view, usually
/// form cards; the kit only hosts shared panes such as UpdateKit's or Vault's, which their packages provide.
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
  var content: Content
  @State private var panes: [SettingsPaneInfo] = []
  @State private var showsPane = false
  @FocusState private var isSidebarFocused: Bool
  @Environment(\.kitIdiom) private var idiom

  public init(selection: Binding<String>, @ViewBuilder content: () -> Content) {
    self._selection = selection
    self.content = content()
  }

  /// The selected pane, or the first one when the selection names none.
  private var current: SettingsPaneInfo? { panes.first { $0.id == selection } ?? panes.first }

  public var body: some View {
    Group {
      if idiom == .phone {
        ZStack {
          if showsPane { detail.transition(.move(edge: .trailing)) } else { sidebar.transition(.opacity) }
        }
        .animation(.kitSlow, value: showsPane)
      } else {
        HStack(spacing: 0) {
          sidebar.frame(width: idiom.isTouch ? 260 : 190)
          detail
        }
      }
    }
    .environment(\.dataSettingsSelection, current?.id ?? "")
    .onPreferenceChange(SettingsPanesKey.self) { value in
      MainActor.assumeIsolated { panes = value }
    }
  }

  // MARK: Sidebar

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 2) {
      ForEach(sections, id: \.self) { section in
        if !section.isEmpty {
          Text(section)
            .kitFont(.sectionHeader)
            .padding(.leading, 10)
            .padding(.top, 14)
            .padding(.bottom, 4)
        }
        ForEach(panes.filter { $0.section == section }) { pane in
          SettingsSidebarRow(pane: pane, isSelected: pane.id == current?.id && (idiom != .phone || showsPane)) {
            withKitAnimation {
              selection = pane.id
              showsPane = true
            }
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, KitMetrics.gutter)
    .padding(.top, idiom == .mac ? KitMetrics.titlebarHeight : 20)
    .frame(maxHeight: .infinity, alignment: .top)
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

  // MARK: Detail

  private var detail: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        if idiom == .phone {
          Button("Settings", systemImage: "chevron.left") { withKitAnimation { showsPane = false } }
            .buttonStyle(.kitPlain)
        }
        Text(current?.title ?? "")
          .kitFont(idiom == .phone ? .title3 : .headline)
          .contentTransition(.opacity)
      }
      .padding(.horizontal, 24)
      .frame(height: idiom == .mac ? KitMetrics.titlebarHeight : 56, alignment: .center)
      ZStack(alignment: .topLeading) { content }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.kitWindow)
  }
}

struct SettingsPaneInfo: Identifiable, Hashable {
  var id: String
  var title: String
  var systemImage: String
  var hue: Hue
  var section: String
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
          size: idiom.isTouch ? 28 : 20, style: .solid)
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
    .onHover { isHovered = $0 }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// One pane of `KitSettings`: its sidebar row (title, glyph, tile hue, the section it's listed under) and its
/// content, shown beside the sidebar when selected, scrolling, with an 18pt rhythm between its cards.
///
/// ```swift
/// SettingsPane("Editor", systemImage: "character.cursor.ibeam", hue: .blue) {
///   FormCard { FormRow("Wrap lines") { Toggle("", isOn: $wrap) } }
/// }
/// ```
public struct SettingsPane<Content: View>: View {
  var info: SettingsPaneInfo
  var content: Content
  @Environment(\.dataSettingsSelection) private var selection
  @Environment(\.dataRendersFlat) private var flat

  public init(
    _ title: String, systemImage: String, hue: Hue = .gray, section: String? = nil, id: String? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.info = SettingsPaneInfo(
      id: id ?? title, title: title, systemImage: systemImage, hue: hue, section: section ?? "")
    self.content = content()
  }

  public var body: some View {
    ZStack(alignment: .topLeading) {
      if selection == info.id {
        let stack = VStack(alignment: .leading, spacing: 18) { content }
          .padding(.horizontal, 24)
          .padding(.top, 4)
          .padding(.bottom, 24)
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
