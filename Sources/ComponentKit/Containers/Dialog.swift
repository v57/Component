import SwiftUI

// MARK: - Dialog

extension View {
  /// Asks before an action in a centered card over the screen, alert-style: the icon, the title and message centered,
  /// whatever the decision needs (a safety code to compare), then Cancel and the confirming button. On iPhone and iPad
  /// it covers the screen with a dimmed backdrop (a tap on it cancels); on the Mac it is a sheet, as Mac apps ask.
  /// Return confirms and Escape cancels. For a plain yes/no, `kitConfirmation` is the sheet with the same buttons.
  ///
  /// ```swift
  /// .kitDialog("Approve ThinkPad X1?", isPresented: $approving, message: "Windows · wants to join Home Hub",
  ///            systemImage: "checkmark.shield", confirm: "Approve") {
  ///   KitSafetyCode(groups: ["702", "115"], columns: 2)
  /// } action: { approve() }
  /// ```
  public func kitDialog<Content: View>(
    _ title: String, isPresented: Binding<Bool>, message: String? = nil, systemImage: String = "questionmark.circle",
    hue: Hue? = nil, confirm: String, role: ButtonRole? = nil, @ViewBuilder content: () -> Content,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    modifier(
      KitDialogModifier(
        isPresented: isPresented,
        card: KitDialogCard(
          title: title, message: message, systemImage: systemImage, hue: hue ?? (role == .destructive ? .red : .accent),
          confirm: confirm, role: role, content: AnyView(content()), action: action)))
  }

  /// A dialog with only the title and message.
  public func kitDialog(
    _ title: String, isPresented: Binding<Bool>, message: String? = nil, systemImage: String = "questionmark.circle",
    hue: Hue? = nil, confirm: String, role: ButtonRole? = nil, action: @escaping @MainActor () -> Void
  ) -> some View {
    kitDialog(
      title, isPresented: isPresented, message: message, systemImage: systemImage, hue: hue, confirm: confirm,
      role: role, content: { EmptyView() }, action: action)
  }
}

/// The dialog's card: what every platform shows.
struct KitDialogCard: View {
  let title: String
  let message: String?
  let systemImage: String
  let hue: Hue
  let confirm: String
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
      HStack(spacing: KitMetrics.gutter) {
        Button(role: .cancel) { close(false) } label: { Text("Cancel").frame(maxWidth: .infinity) }
          .buttonStyle(.kit)
          .keyboardShortcut(.cancelAction)
        Button(role: role) { close(true) } label: { Text(confirm).frame(maxWidth: .infinity) }
          .buttonStyle(.kitPrimary)
          .keyboardShortcut(.defaultAction)
      }
      .controlSize(idiom.isTouch ? .large : .regular)
      .padding(.top, 4)
    }
    .padding(20)
    .frame(maxWidth: 340)
    .accessibilityAddTraits(.isModal)
  }
}

struct KitDialogModifier: ViewModifier {
  @Binding var isPresented: Bool
  let card: KitDialogCard

  func body(content: Content) -> some View {
    #if os(iOS)
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
    #else
      content.sheet(isPresented: $isPresented) {
        var card = card
        let _ = card.close = { confirmed in
          if confirmed { card.action() }
          isPresented = false
        }
        card.background { Rectangle().fill(.kitPanel).ignoresSafeArea() }
      }
    #endif
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
    title: "Approve ThinkPad X1?", message: "Windows · wants to join Home Hub", systemImage: "checkmark.shield",
    hue: .accent, confirm: "Approve", role: nil,
    content: AnyView(KitSafetyCode(groups: ["702", "115"], columns: 2)), action: {}
  )
  .background(RoundedRectangle(cornerRadius: KitMetrics.radiusOverlay).fill(.kitPanel))
  .padding()
  .componentKit()
}
