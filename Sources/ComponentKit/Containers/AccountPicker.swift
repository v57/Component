import SwiftUI

// Accounts: each window shows one account, a vault of its own for one organization (../Ideas/Accounts.md). The
// picker is the sidebar's first row, a card like the sections under it: the account's tile, its name, a quiet meta
// line and the up-down chevron. Its menu lists the accounts (⌃⌘1…⌃⌘9), then Open … in a New Window, New Account…
// and Manage Accounts…. It hides itself while there is only one account, so one account looks as before. In a
// device chooser (Get, Player) it is `.compact`, at the header's trailing edge. The account's colour is its tile
// only: the window keeps the app's accent.

/// An account as the picker shows it: the app maps its vault's accounts to these.
///
/// ```swift
/// KitAccount(id: account.id, name: account.name, hue: Hue(rawValue: account.color) ?? .blue)
/// ```
public struct KitAccount: Identifiable, Hashable, Sendable {
  public var id: String
  public var name: String
  public var hue: Hue

  public init(id: String, name: String, hue: Hue) {
    self.id = id
    self.name = name
    self.hue = hue
  }

  /// The tile's letter: the name's first letter.
  var letter: String { name.first.map { String($0).uppercased() } ?? "?" }
}

/// Picks the window's account. Put it first in a `KitSidebar`'s content (`.sidebar`) or at the trailing edge of a
/// device chooser's header (`.compact`); with fewer than two accounts it draws nothing.
///
/// ```swift
/// KitSidebar(selection: $selection) {
///   KitAccountPicker(accounts: accounts, selection: $accountID, meta: "9 projects",
///                    openInNewWindow: { openWindow(value: $0) }, newAccount: { showsNew = true },
///                    manage: { openSettings() })
///   KitSection("Projects", …) { … }
/// } bottomBar: { … }
/// ```
public struct KitAccountPicker: View {
  public enum Style: Hashable, Sendable {
    /// The sidebar's first row: a full-width card, 40pt (48 on touch).
    case sidebar
    /// In a header: as wide as its name, 28pt.
    case compact
  }

  var accounts: [KitAccount]
  @Binding var selection: String
  var meta: String?
  var style: Style
  var openInNewWindow: ((String) -> Void)?
  var newAccount: (() -> Void)?
  var manage: (() -> Void)?
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @State private var isOpen = false
  @State private var isHovered = false

  public init(
    accounts: [KitAccount], selection: Binding<String>, meta: String? = nil, style: Style = .sidebar,
    openInNewWindow: ((String) -> Void)? = nil, newAccount: (() -> Void)? = nil, manage: (() -> Void)? = nil
  ) {
    self.accounts = accounts
    _selection = selection
    self.meta = meta
    self.style = style
    self.openInNewWindow = openInNewWindow
    self.newAccount = newAccount
    self.manage = manage
  }

  private var current: KitAccount? { accounts.first { $0.id == selection } ?? accounts.first }

  public var body: some View {
    if accounts.count > 1, let current {
      picker(current)
        .background { shortcuts }
    }
  }

  private func picker(_ current: KitAccount) -> some View {
    let compact = style == .compact
    let height: CGFloat = compact ? idiom.size(28, touch: 32) : idiom.size(40, touch: 48)
    let radius: CGFloat = compact ? KitMetrics.radius : KitMetrics.radiusCard
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    return HStack(spacing: compact ? 6 : 8) {
      Avatar(name: current.name, letters: current.letter, kind: .thing, hue: current.hue,
             size: compact ? idiom.size(18, touch: 22) : idiom.size(24, touch: 30))
      VStack(alignment: .leading, spacing: 0) {
        Text(current.name)
          .font(.system(size: compact ? idiom.size(12, touch: 15) : idiom.size(13, touch: 16), weight: .semibold))
          .foregroundStyle(.kitLabel)
        if let meta, !compact {
          Text(meta)
            .font(.system(size: idiom.size(11, touch: 13)))
            .foregroundStyle(.kitSecondary)
        }
      }
      .lineLimit(1)
      .frame(maxWidth: compact ? nil : .infinity, alignment: .leading)
      Image(systemName: "chevron.up.chevron.down")
        .font(.system(size: idiom.size(9, touch: 11), weight: .semibold))
        .foregroundStyle(.kitSecondary)
    }
    .padding(.leading, compact ? 4 : idiom.size(8, touch: 10))
    .padding(.trailing, compact ? 6 : idiom.size(10, touch: 14))
    .frame(height: height)
    .frame(maxWidth: compact ? nil : .infinity)
    .background {
      if compact {
        CtlRaisedCard(cornerRadius: radius)
      } else {
        SurfaceShape(surface: .card, cornerRadius: radius)
      }
      shape.fill(Color.primary.opacity((isHovered || isOpen) && isEnabled ? 0.04 : 0))
    }
    .contentShape(shape)
    .kitHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
    .kitMenuTrigger(isPresented: $isOpen, matchesWidth: !compact) { menu(current) }
    .padding(.bottom, compact ? 0 : KitMetrics.gutter)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Account")
    .accessibilityValue(current.name)
    .accessibilityAddTraits(.isButton)
  }

  @ViewBuilder private func menu(_ current: KitAccount) -> some View {
    ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
      KitMenuRow(checked: account.id == current.id, trigger: { selection = account.id }) {
        Label {
          Text(account.name)
        } icon: {
          Avatar(name: account.name, letters: account.letter, kind: .thing, hue: account.hue, size: 16)
        }
        .labelStyle(KitMenuLabelStyle())
      }
      .kitMenuHint(index < 9 ? "⌃⌘\(index + 1)" : nil)
    }
    if openInNewWindow != nil || newAccount != nil || manage != nil {
      Divider()
    }
    if let openInNewWindow, let other = accounts.first(where: { $0.id != current.id }) {
      if accounts.count == 2 {
        Button("Open \(other.name) in a New Window") { openInNewWindow(other.id) }
      } else {
        KitSubmenu("Open in a New Window") {
          ForEach(accounts.filter { $0.id != current.id }) { account in
            Button(account.name) { openInNewWindow(account.id) }
          }
        }
      }
    }
    if let newAccount { Button("New Account…", action: newAccount) }
    if let manage { Button("Manage Accounts…", action: manage) }
  }

  /// ⌃⌘1…⌃⌘9 switch the window's account (⌘1…⌘9 are the apps' own tabs).
  @ViewBuilder private var shortcuts: some View {
    #if !os(tvOS)
      ForEach(Array(accounts.prefix(9).enumerated()), id: \.element.id) { index, account in
        Button("") { selection = account.id }
          .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.control, .command])
          .opacity(0)
          .frame(width: 0, height: 0)
          .accessibilityHidden(true)
      }
    #endif
  }
}
