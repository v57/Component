import SwiftUI

// Sheets, dialogs and popovers (the Sheets and dialogs board, pick C): the panel ground with 20pt corners, so the cards
// inside read as raised; the header is the rich title, still; the fields' cards sit 8pt in from the edge; the footer is
// a raised card bar whose live icon and status line lead and whose filled buttons trail; with no status it is as wide
// as its buttons, at the trailing side, like a window's status bar.

/// A sheet's content: the still rich header (an icon tile, the title, one line of meta that wraps), the body's cards
/// 8pt in from the edges, and the footer as a card bar. Buttons in the footer are filled and borderless; give the
/// primary one `.buttonStyle(.kitPrimary)` and `.keyboardShortcut(.defaultAction)` (Return), Cancel
/// `.keyboardShortcut(.cancelAction)` (Escape). Lead the footer with a `SheetStatus` to show the sheet's own state
/// (the arc while input is checked, red when wrong, a check when ready); the bar then spans the sheet. Without one it
/// is as wide as its buttons, at the trailing side: no `Spacer()` before them, which would stretch it again.
///
/// Present it with `.kitSheet(isPresented:)`: a card in the middle of the dimmed window, `width` wide on the Mac (80pt
/// wider on iPad, the screen's width less 16pt each side on iPhone), as tall as its content, its body scrolling
/// between the header and the footer when the window is too short for it.
///
/// ```swift
/// .kitSheet(isPresented: $cloning) {
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
  @Environment(\.kitPresentation) private var presentation
  @State private var bodyHeight: CGFloat = 0
  /// The body runs on past the bottom of its scroll view, which then fades that edge (with no footer bar there).
  @State private var bodyRunsOn = false
  @State private var scrollSpace = UUID()
  @State private var viewport: CGFloat = 0
  /// The body put the footer over its own scroll view (`kitSheetFooterBar`), so the sheet draws no footer row.
  @State private var footerIsInBody = false
  /// The footer bar's height, while it sits over the sheet's scrolling body.
  @State private var footerHeight: CGFloat = 0
  /// The header's height, while it is a bar over the sheet's scrolling body.
  @State private var headerHeight: CGFloat = 0

  /// A sheet with any icon (a thing's own tile, an avatar). `width` applies on the Mac (and 80pt wider on iPad, over
  /// the window); `onClose` adds the round close button at the header's end (for panels without a Cancel button).
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
      if !headerOverBody { header }
      if Content.self != EmptyView.self {
        if presentation == .overlay {
          // Over the window the card is as tall as its content, and its body scrolls when the window is shorter,
          // running on under the header and the footer bar, which fade it out behind themselves (as a window's title
          // bar and status bar).
          let space = scrollSpace
          let viewport = viewport
          ScrollView {
            sheetBody
              .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bodyHeight = $0 }
              .onGeometryChange(for: Bool.self) { $0.frame(in: .named(space)).maxY > viewport + 0.5 } action: {
                bodyRunsOn = $0
              }
          }
          .coordinateSpace(.named(space))
          .scrollBounceBehavior(.basedOnSize)
          .scrollIndicators(.automatic)
          .modifier(FooterOverBody(footer: footerOverBody ? footerBar : nil, height: $footerHeight))
          .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { self.viewport = $0 }
          .contEdgeBar(.top) { headerBar }
          .frame(maxHeight: bodyHeight + headerHeight + (footerOverBody ? footerHeight : 0))
          .contScrollEdge(!footerOverBody && bodyRunsOn, length: idiom.size(24, touch: 32))
        } else if idiom == .phone {
          ScrollView {
            sheetBody
              .padding(.bottom, Footer.self == EmptyView.self ? 0 : 4)
          }
          .scrollBounceBehavior(.basedOnSize)
          .modifier(FooterOverBody(footer: footerOverBody ? footerBar : nil, height: $footerHeight))
          .contEdgeBar(.top) { headerBar }
          .frame(maxHeight: .infinity, alignment: .top)
        } else {
          sheetBody
        }
      }
      if footerIsInBody || footerOverBody {
        // The body's scroll view runs on to the sheet's bottom edge, under its footer bar.
      } else if Footer.self != EmptyView.self {
        footerBar
      } else {
        Spacer(minLength: KitMetrics.gutter).frame(height: KitMetrics.gutter)
      }
    }
    .frame(width: sheetWidth)
    .background {
      // Over the window the overlay's card is the ground.
      if presentation != .overlay { Rectangle().fill(.kitPanel).ignoresSafeArea() }
    }
  }

  /// Whether the header is a bar over the sheet's own scrolling body (over the window, and on iPhone) rather than a
  /// row over it.
  private var headerOverBody: Bool {
    Content.self != EmptyView.self && (presentation == .overlay || idiom == .phone)
  }

  /// The header as a bar the body scrolls under and fades out behind.
  private var headerBar: some View {
    header
      .background { ContEdgeFade(edge: .top, ground: .panel) }
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
  }

  /// Whether the footer is a bar over the sheet's own scrolling body (over the window, and on iPhone) rather than a
  /// row under it.
  private var footerOverBody: Bool {
    Footer.self != EmptyView.self && Content.self != EmptyView.self && !footerIsInBody
      && (presentation == .overlay || idiom == .phone)
  }

  private var sheetWidth: CGFloat? {
    guard let width else { return nil }
    switch idiom {
    case .mac, .tv: return width
    case .pad: return presentation == .overlay ? width + 80 : nil
    case .phone: return nil
    }
  }

  private var sheetBody: some View {
    VStack(alignment: .leading, spacing: KitMetrics.gutter) { content }
      .padding(.horizontal, KitMetrics.gutter)
      .environment(\.kitSheetFooter, Footer.self == EmptyView.self ? nil : KitSheetFooter(view: AnyView(footerBar)))
      .onPreferenceChange(KitSheetFooterInBody.self) { footerIsInBody = $0 }
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
            .font(.system(size: idiom.size(10, touch: 12), weight: .bold))
            .frame(width: idiom.size(24, touch: 30), height: idiom.size(24, touch: 30))
            .background { Circle().fill(.kitFill) }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.kitSecondary)
        .accessibilityLabel("Close")
      }
    }
    .padding(EdgeInsets(top: 16, leading: 16, bottom: 12, trailing: 16))
  }

  private var footerBar: some View {
    HStack(spacing: 6) { footer }
      .buttonStyle(ContSheetButtonStyle())
      .controlSize(.small)
      .environment(\.kitInSheetFooter, true)
      .padding(4)
      .frame(minHeight: idiom.size(36, pad: 44, phone: 52))
      .background {
        SurfaceShape(surface: .card, cornerRadius: idiom == .pad ? KitMetrics.radiusXL : idiom == .phone ? 18 : KitMetrics.radiusCard)
      }
      // The card fits what it holds and trails; a SheetStatus fills the row and takes the card with it
      .frame(maxWidth: .infinity, alignment: .trailing)
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
      LiveIcon(systemImage: systemImage, hue: hue, status: status, size: idiom.size(22, touch: 26))
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

/// The footer bar's button size, shared with a `.kitPrimary` (or any kit button) placed in it, so Cancel and the
/// confirming button are one height, corner and type size.
enum SheetFooterButton {
  static func height(_ idiom: KitIdiom) -> CGFloat { idiom.size(28, pad: 36, phone: 44) }
  static func radius(_ idiom: KitIdiom) -> CGFloat {
    idiom == .phone ? 14 : idiom == .pad ? KitMetrics.radiusLarge : KitMetrics.radius
  }
  static func font(_ idiom: KitIdiom) -> KitFont { idiom.isTouch ? .body : .callout }
  static func padding(_ idiom: KitIdiom) -> CGFloat { idiom.size(12, touch: 16) }
  /// A footer button's ground, and a disabled primary's
  static func fill(_ scheme: ColorScheme) -> KitColor { scheme == .dark ? KitColor.raised : KitColor.fill }
}

extension EnvironmentValues {
  /// True inside a sheet's footer bar: kit buttons there take the footer's size.
  @Entry var kitInSheetFooter: Bool = false
  /// The sheet's footer bar, for a body that scrolls on its own to put over its scroll view (`kitSheetFooterBar`).
  @Entry var kitSheetFooter: KitSheetFooter? = nil
}

struct KitSheetFooter {
  var view: AnyView
}

/// Set by `kitSheetFooterBar`: the footer is in the body.
private struct KitSheetFooterInBody: PreferenceKey {
  static let defaultValue = false
  static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

extension View {
  /// Puts the sheet's footer over this scroll view as a bar its content scrolls under and fades out behind, as a
  /// window's status bar does, for a `KitSheet` body that scrolls on its own (one that keeps its height while its
  /// sections change). The sheet then draws no footer row, and the scroll view runs on to the sheet's bottom edge.
  /// Nothing outside a sheet with a footer.
  ///
  /// ```swift
  /// KitSheet(title: "New Connection", systemImage: "cylinder") {
  ///   ScrollView { fields }.frame(idealHeight: 620).kitSheetFooterBar()
  /// } footer: {
  ///   Button("Cancel") { … }
  ///   Button("Connect") { … }.buttonStyle(.kitPrimary)
  /// }
  /// ```
  public func kitSheetFooterBar() -> some View {
    modifier(SheetFooterBar())
  }
}

/// The sheet's footer as a bar over its scrolling body, with the fade behind it; `height` follows the bar's.
private struct FooterOverBody<Bar: View>: ViewModifier {
  let footer: Bar?
  @Binding var height: CGFloat

  func body(content: Content) -> some View {
    if let footer {
      content.contEdgeBar(.bottom) {
        footer
          .background { ContEdgeFade(edge: .bottom, ground: .panel) }
          .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
      }
    } else {
      content
    }
  }
}

private struct SheetFooterBar: ViewModifier {
  @Environment(\.kitSheetFooter) private var footer

  func body(content: Content) -> some View {
    if let footer {
      content
        .contEdgeBar(.bottom) {
          footer.view.background { ContEdgeFade(edge: .bottom, ground: .panel) }
        }
        .preference(key: KitSheetFooterInBody.self, value: true)
    } else {
      content
    }
  }
}

private struct ContSheetButton: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.colorScheme) private var scheme
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: SheetFooterButton.radius(idiom), style: .continuous)
    configuration.label
      .kitFont(SheetFooterButton.font(idiom))
      .fontWeight(.medium)
      .lineLimit(1)
      .foregroundStyle(configuration.role == .destructive ? AnyShapeStyle(Hue.red.text) : AnyShapeStyle(.kitLabel))
      .padding(.horizontal, SheetFooterButton.padding(idiom))
      .frame(minHeight: SheetFooterButton.height(idiom))
      .background { shape.fill(SheetFooterButton.fill(scheme)) }
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
  /// Asks before an action, as a kit sheet (over the window, at the bottom on iPhone; it stacks over a sheet it is
  /// asked from): the still header (a red tile for a destructive action) with the message
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
    kitSheet(isPresented: isPresented) {
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
    kitSheet(isPresented: isPresented) {
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
  @Environment(\.kitDismiss) private var kitDismiss

  /// The binding false, and the card off the stack even when its presenter is gone (`kitDismiss`).
  private func close() {
    dismiss()
    kitDismiss()
  }

  var body: some View {
    let defaultID = (buttons.first { $0.isDefault } ?? buttons.last)?.id
    let tint = hue ?? (buttons.contains { $0.role == .destructive } ? .red : .accent)
    var sheet = KitSheet(
      title: title, meta: message, width: buttons.count > 2 ? 520 : 420,
      icon: { LiveIcon(systemImage: systemImage, hue: tint, status: .idle, size: 32) },
      content: { EmptyView() },
      footer: {
        Button("Cancel", role: .cancel) { close() }
          .keyboardShortcut(.cancelAction)
        ForEach(buttons) { button in
          if button.id == defaultID {
            Button(button.title, role: button.role) {
              close()
              button.action()
            }
            .buttonStyle(.kitPrimary)
            .keyboardShortcut(.defaultAction)
          } else {
            Button(button.title, role: button.role) {
              close()
              button.action()
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
  @Environment(\.kitDismiss) private var kitDismiss

  /// The binding false, and the card off the stack even when its presenter is gone (`kitDismiss`).
  private func close() {
    dismiss()
    kitDismiss()
  }

  var body: some View {
    var sheet = KitSheet(
      title: title, meta: message, width: 380,
      icon: { LiveIcon(systemImage: systemImage, hue: role == .destructive ? .red : .accent, status: .idle, size: 32) },
      content: { EmptyView() },
      footer: {
        Button("Cancel", role: .cancel) { close() }
          .keyboardShortcut(.cancelAction)
        Button(confirm, role: role) {
          close()
          action()
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
