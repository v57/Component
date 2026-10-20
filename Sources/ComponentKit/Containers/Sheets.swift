import SwiftUI

// Sheets, dialogs and popovers (the Sheets and dialogs board, pick C): the panel ground with 20pt corners, so the cards
// inside read as raised; the header is the rich title, still; the fields' cards sit 8pt in from the edge; the footer is
// a raised card bar whose live icon and status line lead and whose filled buttons trail.

/// A sheet's content: the still rich header (an icon tile, the title, one line of meta that wraps), the body's cards
/// 8pt in from the edges, and the footer as a card bar. Buttons in the footer are filled and borderless; give the
/// primary one `.buttonStyle(.kitPrimary)`. Lead the footer with a `SheetStatus` to show the sheet's own state (the
/// arc while input is checked, red when wrong, a check when ready). On iPhone the sheet takes the height it's given
/// and its body scrolls between the header and the footer.
///
/// ```swift
/// .sheet(isPresented: $cloning) {
///   KitSheet(title: "Clone Repository", meta: "Copies a repository from GitHub, GitLab or any URL.",
///            systemImage: "arrow.down.circle") {
///     FormCard { FormRow("Repository URL", systemImage: "link", field: TextField("https://", text: $url)) }
///   } footer: {
///     SheetStatus("Ready · 12 MB", systemImage: "arrow.down", status: .done)
///     Button("Cancel") { cloning = false }.keyboardShortcut(.cancelAction)
///     Button("Clone") { clone() }.buttonStyle(.kitPrimary).keyboardShortcut(.defaultAction)
///   }
/// }
/// ```
public struct KitSheet<Icon: View, Content: View, Footer: View>: View {
  var title: String
  var meta: String?
  var isMetaError: Bool
  var width: CGFloat?
  var topAligned: Bool
  var onClose: (() -> Void)?
  @ViewBuilder var icon: Icon
  @ViewBuilder var content: Content
  @ViewBuilder var footer: Footer
  @Environment(\.kitIdiom) private var idiom

  /// A sheet with any icon (a thing's own tile, an avatar). `width` applies on the Mac; `onClose` adds the round close
  /// button at the header's end (for panels without a Cancel button).
  public init(
    title: String, meta: String? = nil, width: CGFloat? = 460, onClose: (() -> Void)? = nil,
    @ViewBuilder icon: () -> Icon, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer
  ) {
    self.title = title
    self.meta = meta
    self.isMetaError = false
    self.width = width
    self.topAligned = false
    self.onClose = onClose
    self.icon = icon()
    self.content = content()
    self.footer = footer()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      if Content.self != EmptyView.self {
        if idiom == .phone {
          ScrollView {
            sheetBody
              .padding(.bottom, Footer.self == EmptyView.self ? 0 : 4)
          }
          .scrollBounceBehavior(.basedOnSize)
          .frame(maxHeight: .infinity, alignment: .top)
        } else {
          sheetBody
        }
      }
      if Footer.self != EmptyView.self {
        footerBar
      } else {
        Spacer(minLength: KitMetrics.gutter).frame(height: KitMetrics.gutter)
      }
    }
    .frame(width: idiom == .mac ? width : nil)
    .background { Rectangle().fill(.kitPanel).ignoresSafeArea() }
  }

  private var sheetBody: some View {
    VStack(alignment: .leading, spacing: KitMetrics.gutter) { content }
      .padding(.horizontal, KitMetrics.gutter)
  }

  private var header: some View {
    HStack(alignment: topAligned ? .top : .center, spacing: 12) {
      icon
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .kitFont(idiom.isTouch ? .title2 : .title3)
          .lineLimit(topAligned ? 2 : 1)
        if let meta {
          Text(meta)
            .kitFont(.callout)
            .foregroundStyle(isMetaError ? AnyShapeStyle(Hue.red.text) : AnyShapeStyle(.kitSecondary))
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      if let onClose {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: idiom.isTouch ? 12 : 10, weight: .bold))
            .frame(width: idiom.isTouch ? 30 : 24, height: idiom.isTouch ? 30 : 24)
            .background { Circle().fill(.kitFill) }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.kitSecondary)
        .accessibilityLabel("Close")
      }
    }
    .padding([.horizontal, .top], 16)
    .padding(.bottom, 12)
  }

  private var footerBar: some View {
    HStack(spacing: 6) { footer }
      .buttonStyle(ContSheetButtonStyle())
      .controlSize(.small)
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(4)
      .frame(minHeight: idiom == .phone ? 52 : idiom == .pad ? 44 : 36)
      .kitSurface(.card, cornerRadius: idiom == .phone ? 18 : idiom == .pad ? KitMetrics.radiusXL : KitMetrics.radiusCard)
      .padding(KitMetrics.gutter)
  }
}

extension KitSheet where Icon == LiveIcon<Image> {
  /// A sheet with an SF Symbol tile; `status` puts the header's tile to work.
  public init(
    title: String, meta: String? = nil, systemImage: String, hue: Hue = .accent, status: WorkStatus = .idle,
    width: CGFloat? = 460, onClose: (() -> Void)? = nil, @ViewBuilder content: () -> Content,
    @ViewBuilder footer: () -> Footer
  ) {
    self.init(
      title: title, meta: meta, width: width, onClose: onClose,
      icon: { LiveIcon(systemImage: systemImage, hue: hue, status: status, size: 32) }, content: content,
      footer: footer)
  }
}

extension KitSheet where Icon == LiveIcon<Image>, Footer == EmptyView {
  /// A sheet (or panel) with no footer bar.
  public init(
    title: String, meta: String? = nil, systemImage: String, hue: Hue = .accent, status: WorkStatus = .idle,
    width: CGFloat? = 460, onClose: (() -> Void)? = nil, @ViewBuilder content: () -> Content
  ) {
    self.init(
      title: title, meta: meta, systemImage: systemImage, hue: hue, status: status, width: width, onClose: onClose,
      content: content, footer: { EmptyView() })
  }
}

/// The footer bar's lead: a small live icon and one line of status ("Ready · 12 MB", "Checking…", "Not a Git URL").
///
/// ```swift
/// SheetStatus("Checking the URL…", systemImage: "link", status: .working)
/// ```
public struct SheetStatus: View {
  var text: String
  var systemImage: String
  var hue: Hue
  var status: WorkStatus
  @Environment(\.kitIdiom) private var idiom

  public init(_ text: String, systemImage: String = "checkmark", hue: Hue = .accent, status: WorkStatus = .idle) {
    self.text = text
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
  }

  private var isFailed: Bool { if case .failed = status { true } else { false } }

  public var body: some View {
    HStack(spacing: 8) {
      LiveIcon(systemImage: systemImage, hue: hue, status: status, size: idiom.isTouch ? 26 : 22)
      Text(text)
        .kitFont(.callout)
        .foregroundStyle(isFailed ? AnyShapeStyle(Hue.red.text) : AnyShapeStyle(.kitSecondary))
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .padding(.leading, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// The overlays' buttons: filled and borderless (raised in dark), 28pt (36 on iPad, 44 on iPhone), red text for a
/// destructive role.
struct ContSheetButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    ContSheetButton(configuration: configuration)
  }
}

private struct ContSheetButton: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.colorScheme) private var scheme
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    let radius: CGFloat = idiom == .phone ? 14 : idiom == .pad ? KitMetrics.radiusLarge : KitMetrics.radius
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    configuration.label
      .kitFont(idiom.isTouch ? .body : .callout)
      .fontWeight(.medium)
      .lineLimit(1)
      .foregroundStyle(configuration.role == .destructive ? AnyShapeStyle(Hue.red.text) : AnyShapeStyle(.kitLabel))
      .padding(.horizontal, idiom.isTouch ? 16 : 12)
      .frame(minHeight: idiom == .phone ? 44 : idiom == .pad ? 36 : 28)
      .background { shape.fill(scheme == .dark ? KitColor.raised : KitColor.fill) }
      .overlay {
        shape.fill(configuration.isPressed ? AnyShapeStyle(.kitPress) : isHovered && isEnabled ? AnyShapeStyle(.kitHover) : AnyShapeStyle(Color.clear))
      }
      .opacity(isEnabled ? 1 : 0.45)
      .contentShape(shape)
      .kitHover { isHovered = $0 }
      .animation(.kitFast, value: isHovered)
  }
}

// MARK: - Confirmation

extension View {
  /// Asks before an action, as a kit sheet: the still header (a red tile for a destructive action) with the message
  /// wrapping under the title, and a footer bar with Cancel and the confirming button (filled red when destructive).
  /// Return confirms and Escape cancels.
  ///
  /// ```swift
  /// .kitConfirmation("Delete harbor?", isPresented: $confirming, message: "Its worktree and stashes go too.",
  ///                  systemImage: "trash", confirm: "Delete") { delete(harbor) }
  /// ```
  public func kitConfirmation(
    _ title: String, isPresented: Binding<Bool>, message: String? = nil,
    systemImage: String = "exclamationmark.triangle", confirm: String, role: ButtonRole? = .destructive,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    sheet(isPresented: isPresented) {
      ContConfirmation(
        title: title, message: message, systemImage: systemImage, confirm: confirm, role: role, action: action,
        dismiss: { isPresented.wrappedValue = false })
    }
  }
}

/// One button of a `kitConfirmation` with several choices.
///
/// ```swift
/// KitConfirmationButton("Force Delete", role: .destructive) { git.deleteBranch(name, force: true) }
/// ```
public struct KitConfirmationButton: Identifiable {
  public let id = UUID()
  public var title: String
  public var role: ButtonRole?
  /// The one Return presses, drawn filled; by default the last button.
  public var isDefault: Bool
  var action: @MainActor () -> Void

  public init(
    _ title: String, role: ButtonRole? = nil, isDefault: Bool = false, action: @escaping @MainActor () -> Void
  ) {
    self.title = title
    self.role = role
    self.isDefault = isDefault
    self.action = action
  }
}

extension View {
  /// Asks before an action with several ways to go (Delete / Force Delete / Delete Local and Remote): the same sheet
  /// as the one-button confirmation, with Cancel and each button; the default one (marked, or the last) is filled
  /// and takes Return, the others are plain (red when destructive). Any button closes the sheet.
  ///
  /// ```swift
  /// .kitConfirmation("Delete feature/login?", isPresented: $confirming, message: "It isn't merged into main.",
  ///                  systemImage: "trash", buttons: [
  ///   KitConfirmationButton("Delete Local and Remote", role: .destructive) { deleteBoth() },
  ///   KitConfirmationButton("Force Delete", role: .destructive, isDefault: true) { forceDelete() },
  /// ])
  /// ```
  public func kitConfirmation(
    _ title: String, isPresented: Binding<Bool>, message: String? = nil,
    systemImage: String = "exclamationmark.triangle", hue: Hue? = nil, buttons: [KitConfirmationButton]
  ) -> some View {
    sheet(isPresented: isPresented) {
      ContMultiConfirmation(
        title: title, message: message, systemImage: systemImage, hue: hue, buttons: buttons,
        dismiss: { isPresented.wrappedValue = false })
    }
  }
}

struct ContMultiConfirmation: View {
  let title: String
  let message: String?
  let systemImage: String
  let hue: Hue?
  let buttons: [KitConfirmationButton]
  let dismiss: @MainActor () -> Void

  var body: some View {
    let defaultID = (buttons.first { $0.isDefault } ?? buttons.last)?.id
    let tint = hue ?? (buttons.contains { $0.role == .destructive } ? .red : .accent)
    var sheet = KitSheet(
      title: title, meta: message, width: buttons.count > 2 ? 520 : 420,
      icon: { LiveIcon(systemImage: systemImage, hue: tint, status: .idle, size: 32) },
      content: { EmptyView() },
      footer: {
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        ForEach(buttons) { button in
          if button.id == defaultID {
            Button(button.title, role: button.role) {
              button.action()
              dismiss()
            }
            .buttonStyle(.kitPrimary)
            .keyboardShortcut(.defaultAction)
          } else {
            Button(button.title, role: button.role) {
              button.action()
              dismiss()
            }
          }
        }
      })
    sheet.topAligned = true
    return sheet
  }
}

struct ContConfirmation: View {
  let title: String
  let message: String?
  let systemImage: String
  let confirm: String
  let role: ButtonRole?
  let action: @MainActor () -> Void
  let dismiss: @MainActor () -> Void

  var body: some View {
    var sheet = KitSheet(
      title: title, meta: message, width: 380,
      icon: { LiveIcon(systemImage: systemImage, hue: role == .destructive ? .red : .accent, status: .idle, size: 32) },
      content: { EmptyView() },
      footer: {
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button(confirm, role: role) {
          action()
          dismiss()
        }
        .buttonStyle(.kitPrimary)
        .keyboardShortcut(.defaultAction)
      })
    sheet.topAligned = true
    return sheet
  }
}

#Preview("Sheet") {
  @Previewable @State var url = "https://github.com/v57/Component.git"
  VStack(spacing: 24) {
    KitSheet(title: "Clone Repository", meta: "Copies a repository from GitHub, GitLab or any URL.", systemImage: "arrow.down.circle") {
      FormCard {
        FormRow("Repository URL", help: "GitHub, GitLab or any Git URL", systemImage: "link", status: .done, field: TextField("https://", text: $url))
        FormRow("Location", help: "~/Developer/Component", systemImage: "folder", hue: .teal) {
          Button("Choose…") {}.buttonStyle(.kit)
        }
      }
    } footer: {
      SheetStatus("Ready · 12 MB", systemImage: "arrow.down", status: .done)
      Button("Cancel") {}
      Button("Clone") {}.buttonStyle(.kitPrimary)
    }
    ContConfirmation(
      title: "Delete harbor?", message: "Its worktree and 2 stashes are deleted too. This can't be undone.",
      systemImage: "trash", confirm: "Delete", role: .destructive, action: {}, dismiss: {})
    ContMultiConfirmation(
      title: "Delete feature/login?", message: "It isn't merged into main.", systemImage: "trash", hue: nil,
      buttons: [
        KitConfirmationButton("Delete Local and Remote", role: .destructive) {},
        KitConfirmationButton("Force Delete", role: .destructive) {},
      ], dismiss: {})
  }
  .padding()
  .componentKit()
}
