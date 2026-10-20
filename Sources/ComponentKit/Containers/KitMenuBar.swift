#if os(Windows)
  import SwiftUI

  // The window's menu bar drawn by the kit, on Windows: the app's menus (its `.commands` in File, Edit, View, its own,
  // Window, Help; v57/SwiftUI's `windowMenuBar`) as tools at the leading end of the kit's bar in the title bar row,
  // each opening the kit's menu, so the menus look like the toolbar beside them. The Mac's menus are the system's, at
  // the top of the screen. Their keyboard shortcuts work through SwiftUI either way.

  /// The menu titles, each a tool opening its menu.
  struct ContMenuBar: View {
    let menus: [WindowMenu]

    var body: some View {
      ToolGroup {
        ForEach(menus) { menu in
          ContMenuBarItem(menu: menu)
        }
      }
    }
  }

  /// One menu title: the tool opens its menu (the button takes the click, so it opens the menu itself).
  struct ContMenuBarItem: View {
    let menu: WindowMenu
    @State private var isOpen = false

    var body: some View {
      Button(menu.title) { isOpen.toggle() }
        .kitMenu(isPresented: $isOpen) { ContMenuItems(items: menu.items) }
        .accessibilityHint("Menu")
    }
  }

  /// A menu's items as the kit's menu rows: buttons with their shortcut as the hint, toggles, submenus, sections.
  struct ContMenuItems: View {
    let items: [MenuItem]

    var body: some View {
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
        row(item)
      }
    }

    @ViewBuilder
    private func row(_ item: MenuItem) -> some View {
      switch item {
      case let .button(title, systemImage, shortcut, isEnabled, isDestructive, action):
        Group {
          if let systemImage {
            Button(title, systemImage: systemImage, role: isDestructive ? .destructive : nil, action: action)
          } else {
            Button(title, role: isDestructive ? .destructive : nil, action: action)
          }
        }
        .disabled(!isEnabled)
        .kitMenuHint(Self.hint(shortcut))
      case let .toggle(title, isOn, shortcut, isEnabled, set):
        Toggle(title, isOn: Binding(get: { isOn }, set: set))
          .disabled(!isEnabled)
          .kitMenuHint(Self.hint(shortcut))
      case let .submenu(title, systemImage, children):
        KitSubmenu(title, systemImage: systemImage) { AnyView(ContMenuItems(items: children)) }
      case let .section(title, children):
        if let title, !title.isEmpty {
          KitMenuSection(title) { AnyView(ContMenuItems(items: children)) }
        } else {
          Divider()
          AnyView(ContMenuItems(items: children))
          Divider()
        }
      case .divider:
        Divider()
      case .label(let text):
        Button(text) {}.disabled(true)
      }
    }

    /// A shortcut as Windows writes it: "Ctrl+Shift+N".
    static func hint(_ shortcut: KeyboardShortcut?) -> String? {
      guard let shortcut else { return nil }
      var keys: [String] = []
      if shortcut.modifiers.contains(.command) { keys.append("⌘") }
      if shortcut.modifiers.contains(.control) { keys.append("⌃") }
      if shortcut.modifiers.contains(.option) { keys.append("⌥") }
      if shortcut.modifiers.contains(.shift) { keys.append("⇧") }
      keys.append(key(shortcut.key))
      return Keycaps.ordered(keys).map(Keycaps.displayed).joined(separator: "+")
    }

    private static func key(_ key: KeyEquivalent) -> String {
      switch key {
      case .return: "Enter"
      case .escape: "Esc"
      case .delete: "Backspace"
      case .deleteForward: "Del"
      case .tab: "Tab"
      case .space: "Space"
      case .upArrow: "↑"
      case .downArrow: "↓"
      case .leftArrow: "←"
      case .rightArrow: "→"
      default:
        // AppKit's function keys (U+F704 on) are F1 on.
        if let scalar = key.character.unicodeScalars.first, (0xF704...0xF71B).contains(scalar.value) {
          "F\(scalar.value - 0xF704 + 1)"
        } else {
          key.character.uppercased()
        }
      }
    }
  }
#endif
