import SwiftUI

// MARK: - Dialog

extension View {
  /// Asks before an action in a centered card over the screen, alert-style: the icon, the title and message centered,
  /// whatever the decision needs (a safety code to compare), then Cancel and the confirming button. It is the kit's
  /// overlay, in the middle on iPhone too (the window dims, a click on the dim cancels; it stacks over a sheet it is
  /// asked from). Return confirms and Escape cancels. For a plain yes/no, `kitConfirmation` is the sheet with the same buttons.
  ///
  /// ```swift
  /// .kitDialog("Approve ThinkPad X1?", isPresented: $approving, message: "Windows · wants to join Home Hub",
  ///            systemImage: "checkmark.shield", confirm: "Approve") {
  ///   KitSafetyCode(groups: ["702", "115"], columns: 2)
  /// } action: { approve() }
  /// ```
  ///
  /// The title, message and button are keys (literals), looked up in the app's strings.
  public func kitDialog<Content: View>(
    _ title: LocalizedStringKey, isPresented: Binding<Bool>, message: LocalizedStringKey? = nil,
    systemImage: String = "questionmark.circle", hue: Hue? = nil, confirm: LocalizedStringKey, role: ButtonRole? = nil,
    @ViewBuilder content: () -> Content, action: @escaping @MainActor () -> Void
  ) -> some View {
    kitDialog(
      title: KitString(title), isPresented: isPresented, message: KitString(message), systemImage: systemImage,
      hue: hue, confirm: KitString(confirm), role: role, content: content, action: action)
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public func kitDialog<Content: View>(
    _ title: some StringProtocol, isPresented: Binding<Bool>, message: String? = nil,
    systemImage: String = "questionmark.circle", hue: Hue? = nil, confirm: some StringProtocol,
    role: ButtonRole? = nil, @ViewBuilder content: () -> Content, action: @escaping @MainActor () -> Void
  ) -> some View {
    kitDialog(
      title: KitString(verbatim: String(title)), isPresented: isPresented, message: KitString(verbatim: message),
      systemImage: systemImage, hue: hue, confirm: KitString(verbatim: String(confirm)), role: role, content: content,
      action: action)
  }

  /// A dialog with only the title and message, titled by keys (literals), looked up in the app's strings.
  public func kitDialog(
    _ title: LocalizedStringKey, isPresented: Binding<Bool>, message: LocalizedStringKey? = nil,
    systemImage: String = "questionmark.circle", hue: Hue? = nil, confirm: LocalizedStringKey, role: ButtonRole? = nil,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    kitDialog(
      title: KitString(title), isPresented: isPresented, message: KitString(message), systemImage: systemImage,
      hue: hue, confirm: KitString(confirm), role: role, content: { EmptyView() }, action: action)
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public func kitDialog(
    _ title: some StringProtocol, isPresented: Binding<Bool>, message: String? = nil,
    systemImage: String = "questionmark.circle", hue: Hue? = nil, confirm: some StringProtocol,
    role: ButtonRole? = nil, action: @escaping @MainActor () -> Void
  ) -> some View {
    kitDialog(
      title: KitString(verbatim: String(title)), isPresented: isPresented, message: KitString(verbatim: message),
      systemImage: systemImage, hue: hue, confirm: KitString(verbatim: String(confirm)), role: role,
      content: { EmptyView() }, action: action)
  }

  func kitDialog<Content: View>(
    title: KitString, isPresented: Binding<Bool>, message: KitString?, systemImage: String, hue: Hue?,
    confirm: KitString, role: ButtonRole?, @ViewBuilder content: () -> Content, action: @escaping @MainActor () -> Void
  ) -> some View {
    modifier(
      KitDialogModifier(
        isPresented: isPresented,
        card: KitDialogCard(
          title: title, message: message, systemImage: systemImage, hue: hue ?? (role == .destructive ? .red : .accent),
          confirm: confirm, role: role, content: AnyView(content()), action: action)))
  }
}

/// The dialog's card: what every platform shows.
struct KitDialogCard: View {
  let title: KitString
  let message: KitString?
  let systemImage: String
  let hue: Hue
  let confirm: KitString
  let role: ButtonRole?
  let content: AnyView
  let action: @MainActor () -> Void
  /// Closes the dialog; `confirmed` runs the action first.
  var close: @MainActor (_ confirmed: Bool) -> Void = { _ in }
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    VStack(spacing: 14) {
      LiveIcon(systemImage: systemImage, hue: hue, status: .idle, size: 40)
      VStack(spacing: 4) {
        Text(title)
          .kitFont(idiom.isTouch ? .title2 : .title3)
          .multilineTextAlignment(.center)
        if let message {
          Text(message)
            .kitFont(.callout)
            .foregroundStyle(.kitSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .accessibilityElement(children: .combine)
      content
      // Side by side while both labels fit whole, else the confirming button over Cancel ("Trust and Connect" on
      // iPhone was "Trust and Co…").
      KitDialogButtons {
        cancelButton
        confirmButton
      }
      .controlSize(idiom.isTouch ? .large : .regular)
      .padding(.top, 4)
    }
    .padding(20)
    .frame(maxWidth: 340)
    .accessibilityAddTraits(.isModal)
  }

  private var cancelButton: some View {
    Button(role: .cancel) { close(false) } label: { Text("Cancel").frame(maxWidth: .infinity) }
      .buttonStyle(.kit)
      .keyboardShortcut(.cancelAction)
  }

  private var confirmButton: some View {
    Button(role: role) { close(true) } label: { Text(confirm).frame(maxWidth: .infinity) }
      .buttonStyle(.kitPrimary)
      .keyboardShortcut(.defaultAction)
  }
}

/// Cancel and the confirming button: side by side at one width while both labels fit whole at it, else the
/// confirming button over Cancel, each across the card.
struct KitDialogButtons: Layout {
  var spacing = KitMetrics.gutter

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
    let widest = ideal.map(\.width).max() ?? 0
    let sideBySide = widest * CGFloat(subviews.count) + spacing * CGFloat(max(0, subviews.count - 1))
    let width = proposal.width.map { $0.isFinite ? $0 : sideBySide } ?? sideBySide
    if sideBySide <= width + 0.5 {
      return CGSize(width: width, height: ideal.map(\.height).max() ?? 0)
    }
    let heights = ideal.map(\.height)
    return CGSize(
      width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(0, subviews.count - 1)))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
    let widest = ideal.map(\.width).max() ?? 0
    let count = CGFloat(subviews.count)
    if widest * count + spacing * (count - 1) <= bounds.width + 0.5 {
      let width = (bounds.width - spacing * (count - 1)) / count
      for (index, subview) in subviews.enumerated() {
        subview.place(
          at: CGPoint(x: bounds.minX + CGFloat(index) * (width + spacing), y: bounds.minY),
          proposal: ProposedViewSize(width: width, height: bounds.height))
      }
    } else {
      // The last (confirming) one on top, Cancel under it.
      var y = bounds.minY
      for subview in subviews.reversed() {
        let height = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
        subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: height))
        y += height + spacing
      }
    }
  }
}

struct KitDialogModifier: ViewModifier {
  @Binding var isPresented: Bool
  let card: KitDialogCard
  @Environment(\.kitOverlayHost) private var host

  func body(content: Content) -> some View {
    #if os(iOS)
      // Outside `componentKit()`: a cover with its own dim.
      if host == nil {
        content
          .fullScreenCover(isPresented: $isPresented) {
            KitDialogCover(card: card) { confirmed in
              if confirmed { card.action() }
              var transaction = Transaction()
              transaction.disablesAnimations = true
              withTransaction(transaction) { isPresented = false }
            }
            .presentationBackground(.clear)
          }
          // Shown and hidden without the system's slide: the dialog draws its own entrance.
          .transaction(value: isPresented) { $0.disablesAnimations = true }
      } else {
        overlay(content)
      }
    #else
      overlay(content)
    #endif
  }

  /// The kit's overlay: the card over the dimmed window, stacking over a sheet it is asked from.
  private func overlay(_ content: Content) -> some View {
    let binding = $isPresented
    var card = card
    card.close = { confirmed in
      if confirmed { card.action() }
      binding.wrappedValue = false
    }
    return content.modifier(
      KitOverlayPresenter(
        isPresented: binding, style: .dialog, onDismiss: nil,
        content: { [card] in KitDialogSheetGround(card: card) }))
  }
}

/// The dialog's card, on the panel ground only in a system sheet (the overlay's card is its own ground).
private struct KitDialogSheetGround: View {
  let card: KitDialogCard
  @Environment(\.kitPresentation) private var presentation

  var body: some View {
    card.background {
      if presentation == .systemSheet { Rectangle().fill(.kitPanel).ignoresSafeArea() }
    }
  }
}

#if os(iOS)
  /// The backdrop and the card, faded and scaled in, and out before the cover goes.
  struct KitDialogCover: View {
    let card: KitDialogCard
    let finish: @MainActor (_ confirmed: Bool) -> Void
    @State private var isShown = false

    var body: some View {
      var card = card
      let _ = card.close = { confirmed in dismiss(confirmed) }
      ZStack {
        Rectangle()
          .fill(.black.opacity(isShown ? 0.32 : 0))
          .ignoresSafeArea()
          .onTapGesture { dismiss(false) }
          .accessibilityHidden(true)
        card
          .background(
            RoundedRectangle(cornerRadius: KitMetrics.radiusOverlay, style: .continuous).fill(.kitPanel))
          .padding(KitMetrics.gutter * 3)
          .scaleEffect(isShown ? 1 : 0.94)
          .opacity(isShown ? 1 : 0)
      }
      .onAppear { withAnimation(.kit) { isShown = true } }
    }

    private func dismiss(_ confirmed: Bool) {
      withAnimation(.kitFast) { isShown = false } completion: { finish(confirmed) }
    }
  }
#endif

#Preview("Dialog") {
  KitDialogCard(
    title: KitString("Approve ThinkPad X1?"), message: KitString("Windows · wants to join Home Hub"),
    systemImage: "checkmark.shield", hue: .accent, confirm: KitString("Approve"), role: nil,
    content: AnyView(KitSafetyCode(groups: ["702", "115"], columns: 2)), action: {}
  )
  .background(RoundedRectangle(cornerRadius: KitMetrics.radiusOverlay).fill(.kitPanel))
  .padding()
  .componentKit()
}
