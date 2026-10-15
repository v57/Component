import SwiftUI

// Feedback (the Feedback board, pick A): what has to be read is a raised card. A banner floats inset at the top of its
// pane; a toast is a floating card with a plain Undo; an empty state leads with a soft accent tile.

// MARK: - Banner

/// A notice across a pane, as an inset card faintly tinted with its colour: an icon tile in that colour, a bold line
/// and a quiet line, the actions at the end. Put it at the top of the pane with the 8pt gutter around it.
///
/// ```swift
/// Banner("This project has no release.env yet.", message: "release.sh steps need one.",
///        systemImage: "exclamationmark.triangle", hue: .orange) {
///   Button("Set Up Release") { … }
/// }
/// ```
public struct Banner<Actions: View>: View {
  var title: String
  var message: String?
  var systemImage: String
  var hue: Hue
  var onDismiss: (() -> Void)?
  @ViewBuilder var actions: Actions
  @Environment(\.kitIdiom) private var idiom

  public init(
    _ title: String, message: String? = nil, systemImage: String = "info.circle", hue: Hue = .blue,
    onDismiss: (() -> Void)? = nil, @ViewBuilder actions: () -> Actions
  ) {
    self.title = title
    self.message = message
    self.systemImage = systemImage
    self.hue = hue
    self.onDismiss = onDismiss
    self.actions = actions()
  }

  public var body: some View {
    let tile: CGFloat = idiom.isTouch ? 32 : 28
    HStack(spacing: 10) {
      Image(systemName: systemImage)
        .font(.system(size: tile * 0.5, weight: .semibold))
        .foregroundStyle(hue.text)
        .frame(width: tile, height: tile)
        .background { RoundedRectangle(cornerRadius: tile * 0.29, style: .continuous).fill(hue.soft(0.16)) }
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 1) {
        Text(title).kitFont(.headline).lineLimit(2)
        if let message { Text(message).kitFont(.callout).foregroundStyle(.kitSecondary).lineLimit(2) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
      actions
        .buttonStyle(.kit)
        .controlSize(.small)
      if let onDismiss {
        Button("Dismiss", systemImage: "xmark", action: onDismiss)
          .buttonStyle(.kitIcon)
      }
    }
    .padding(KitMetrics.gutter)
    .background {
      let shape = RoundedRectangle(cornerRadius: ContMetrics.cardRadius(idiom), style: .continuous)
      SurfaceShape(surface: .card, cornerRadius: ContMetrics.cardRadius(idiom))
        .overlay { shape.fill(hue.soft(0.06)) }
    }
    .accessibilityElement(children: .contain)
  }
}

extension Banner where Actions == EmptyView {
  /// A banner with no actions.
  public init(
    _ title: String, message: String? = nil, systemImage: String = "info.circle", hue: Hue = .blue,
    onDismiss: (() -> Void)? = nil
  ) {
    self.init(title, message: message, systemImage: systemImage, hue: hue, onDismiss: onDismiss) { EmptyView() }
  }
}

// MARK: - Toasts

/// A short message about something that just happened, with an optional Undo. Show it through the environment's
/// `showToast` (installed by `.kitToasts()`).
public struct Toast: Identifiable {
  public let id = UUID()
  public var message: String
  public var systemImage: String?
  public var undo: (@MainActor () -> Void)?
  /// How long it stays (the pointer resting on it keeps it).
  public var duration: Duration

  public init(
    _ message: String, systemImage: String? = nil, duration: Duration = .seconds(4),
    undo: (@MainActor () -> Void)? = nil
  ) {
    self.message = message
    self.systemImage = systemImage
    self.duration = duration
    self.undo = undo
  }
}

/// Shows a toast: `showToast(Toast("Deleted harbor", systemImage: "trash", undo: { … }))`.
public struct ShowToastAction {
  let handler: @MainActor (Toast) -> Void

  @MainActor public func callAsFunction(_ toast: Toast) { handler(toast) }

  /// Shows a toast with just a message.
  @MainActor public func callAsFunction(_ message: String, systemImage: String? = nil) {
    handler(Toast(message, systemImage: systemImage))
  }
}

extension EnvironmentValues {
  /// Shows a toast in the nearest `.kitToasts()` host (nothing happens without one).
  ///
  /// ```swift
  /// @Environment(\.showToast) private var showToast
  /// …
  /// showToast(Toast("Deleted harbor", systemImage: "trash", undo: { restore(harbor) }))
  /// ```
  @Entry public var showToast = ShowToastAction { _ in }
}

extension View {
  /// Hosts toasts for the views below: one at a time at the bottom centre, springing in, gone after a few seconds
  /// (or on Undo, or the dismiss button). Put it once on a scene's root, inside `.componentKit()`.
  ///
  /// ```swift
  /// ContentView().kitToasts().componentKit()
  /// ```
  public func kitToasts() -> some View {
    modifier(ContToastHost())
  }
}

private struct ContToastHost: ViewModifier {
  @State private var current: Toast?
  @State private var isHovered = false

  func body(content: Content) -> some View {
    content
      .environment(\.showToast, ShowToastAction { toast in show(toast) })
      .overlay(alignment: .bottom) {
        if let current {
          ToastView(toast: current, dismiss: { dismiss(current.id) })
            .onHover { isHovered = $0 }
            .padding(.bottom, 16)
            .padding(.horizontal, 16)
            .id(current.id)
            .transition(.asymmetric(insertion: .offset(y: 12).combined(with: .opacity), removal: .opacity))
            .task(id: TimerKey(id: current.id, isHovered: isHovered)) {
              guard !isHovered else { return }
              try? await Task.sleep(for: current.duration)
              guard !Task.isCancelled else { return }
              dismiss(current.id)
            }
        }
      }
  }

  private struct TimerKey: Hashable {
    let id: UUID
    let isHovered: Bool
  }

  private func show(_ toast: Toast) {
    withAnimation(.kitSpring) { current = toast }
    AccessibilityNotification.Announcement(toast.message).post()
  }

  private func dismiss(_ id: UUID) {
    guard current?.id == id else { return }
    withKitAnimation { current = nil }
  }
}

/// A toast as drawn: a floating card with a gray icon tile, the message, a plain Undo and a dismiss button.
public struct ToastView: View {
  var toast: Toast
  var dismiss: () -> Void
  @Environment(\.kitIdiom) private var idiom

  public init(toast: Toast, dismiss: @escaping () -> Void) {
    self.toast = toast
    self.dismiss = dismiss
  }

  public var body: some View {
    HStack(spacing: 10) {
      if let systemImage = toast.systemImage {
        Image(systemName: systemImage)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Hue.gray.text)
          .frame(width: 22, height: 22)
          .background { RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Hue.gray.soft(0.16)) }
          .accessibilityHidden(true)
      }
      Text(toast.message)
        .kitFont(.body)
        .lineLimit(1)
      if let undo = toast.undo {
        Button("Undo") {
          undo()
          dismiss()
        }
        .buttonStyle(.kitPlain)
        .controlSize(.small)
        .fontWeight(.semibold)
      }
      Button("Dismiss", systemImage: "xmark", action: dismiss)
        .buttonStyle(.kitIcon)
        .padding(.leading, -4)
    }
    .padding(.leading, toast.systemImage == nil ? 14 : 8)
    .padding(.trailing, 6)
    .frame(height: idiom.isTouch ? 52 : 44)
    .background { SurfaceShape(surface: .floating, cornerRadius: KitMetrics.radiusCard) }
    .accessibilityElement(children: .contain)
  }
}

// MARK: - Empty state

/// What a pane will show and how to get there: a soft accent tile, the title, one line, and the action.
///
/// ```swift
/// EmptyState(systemImage: "tray", title: "No Stashes", message: "Stash your changes to set them aside.") {
///   Button("Stash Changes") { … }.buttonStyle(.kitPrimary)
/// }
/// ```
public struct EmptyState<Actions: View>: View {
  var systemImage: String
  var title: String
  var message: String?
  @ViewBuilder var actions: Actions
  @Environment(\.kitWindowIsActive) private var isActive

  public init(
    systemImage: String, title: String, message: String? = nil, @ViewBuilder actions: () -> Actions
  ) {
    self.systemImage = systemImage
    self.title = title
    self.message = message
    self.actions = actions()
  }

  public var body: some View {
    VStack(spacing: 6) {
      Image(systemName: systemImage)
        .font(.system(size: 24, weight: .medium))
        .foregroundStyle(isActive ? AnyShapeStyle(Hue.accent.fill) : AnyShapeStyle(.kitSecondary))
        .frame(width: 52, height: 52)
        .background {
          RoundedRectangle(cornerRadius: KitMetrics.radiusXL, style: .continuous)
            .fill(isActive ? AnyShapeStyle(Hue.accent.soft(0.14)) : AnyShapeStyle(.kitFill))
        }
        .padding(.bottom, 6)
        .accessibilityHidden(true)
      Text(title)
        .kitFont(.title3)
        .multilineTextAlignment(.center)
      if let message {
        Text(message)
          .kitFont(.callout)
          .foregroundStyle(.kitSecondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 300)
          .fixedSize(horizontal: false, vertical: true)
      }
      if Actions.self != EmptyView.self {
        HStack(spacing: 8) { actions }
          .controlSize(.small)
          .padding(.top, 8)
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

extension EmptyState where Actions == EmptyView {
  public init(systemImage: String, title: String, message: String? = nil) {
    self.init(systemImage: systemImage, title: title, message: message) { EmptyView() }
  }
}

#Preview("Feedback") {
  VStack(spacing: 12) {
    Banner("This project has no release.env yet.", message: "release.sh steps need one.", systemImage: "exclamationmark.triangle", hue: .orange) {
      Button("Set Up Release") {}
    }
    Banner("Couldn't reach origin.", message: "Check the network and try again.", systemImage: "wifi.slash", hue: .red, onDismiss: {})
    ToastView(toast: Toast("Deleted harbor", systemImage: "trash", undo: {}), dismiss: {})
    EmptyState(systemImage: "tray", title: "No Stashes", message: "Stash your changes to set them aside and come back later.") {
      Button("Stash Changes") {}.buttonStyle(.kitPrimary)
    }
    .frame(height: 240)
  }
  .padding()
  .frame(width: 520)
  .componentKit()
}
