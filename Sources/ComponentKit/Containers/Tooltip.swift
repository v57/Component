import SwiftUI

extension View {
  /// The kit's tooltip: half a second after the pointer stops on the view, a small card with a rich header shows 6pt
  /// under it: the item's icon on a tinted tile (wearing `status`'s ring while it runs), its name, one line of status,
  /// then the shortcut as keycaps. Moving to the next item swaps it at once. On iPhone, with no pointer, it falls back
  /// to `.help`; everywhere the words also go to accessibility as a hint.
  ///
  /// ```swift
  /// Button("Pull", systemImage: "arrow.down") { … }
  ///   .kitHelp("Pull", shortcut: "⇧⌘P", meta: "1 behind origin/main", systemImage: "arrow.down")
  /// ```
  ///
  /// It draws in the view's overlay, so put it on views whose container doesn't clip (a scroll view clips).
  public func kitHelp(
    _ title: String, shortcut: String? = nil, meta: String? = nil, systemImage: String? = nil,
    hue: Hue = .accent, status: WorkStatus = .idle
  ) -> some View {
    modifier(
      ContHelpModifier(
        title: title, shortcut: shortcut, meta: meta, systemImage: systemImage, hue: hue, status: status))
  }
}

/// When a tooltip last went away: the next one within a moment shows at once.
@MainActor
enum ContTooltipClock {
  static var lastHidden = Date.distantPast
  static let delay: Duration = .milliseconds(500)
  static let carryOver: TimeInterval = 0.35
}

private struct ContHelpModifier: ViewModifier {
  let title: String
  let shortcut: String?
  let meta: String?
  let systemImage: String?
  let hue: Hue
  let status: WorkStatus
  @State private var isShown = false
  @State private var pending: Task<Void, Never>?
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled

  func body(content: Content) -> some View {
    if idiom == .phone {
      content.help(title)
    } else {
      content
        .kitHover(perform: hover)
        .simultaneousGesture(TapGesture().onEnded { hide() })
        .overlay(alignment: .bottom) {
          if isShown {
            ContTooltipCard(
              title: title, shortcut: shortcut, meta: meta, systemImage: systemImage, hue: isEnabled ? hue : .gray,
              status: status
            )
            .fixedSize()
            .alignmentGuide(.bottom) { $0[.top] - 6 }
            .allowsHitTesting(false)
            .transition(.opacity)
          }
        }
        .zIndex(isShown ? 100 : 0)
        .accessibilityHint([meta, shortcut].compactMap { $0 }.joined(separator: ", "))
        .onDisappear { pending?.cancel() }
    }
  }

  private func hover(_ inside: Bool) {
    pending?.cancel()
    if inside {
      if Date().timeIntervalSince(ContTooltipClock.lastHidden) < ContTooltipClock.carryOver {
        isShown = true
      } else {
        pending = Task { @MainActor in
          try? await Task.sleep(for: ContTooltipClock.delay)
          guard !Task.isCancelled else { return }
          withAnimation(.kitFast) { isShown = true }
        }
      }
    } else {
      hide()
    }
  }

  private func hide() {
    pending?.cancel()
    if isShown { ContTooltipClock.lastHidden = Date() }
    withAnimation(.kitFast) { isShown = false }
  }
}

/// The tooltip's card: a rich header at its smallest, and the shortcut as keys.
struct ContTooltipCard: View {
  let title: String
  let shortcut: String?
  let meta: String?
  let systemImage: String?
  let hue: Hue
  let status: WorkStatus
  @Environment(\.kitIdiom) private var idiom

  var body: some View {
    HStack(spacing: 9) {
      if let systemImage {
        LiveIcon(systemImage: systemImage, hue: hue, status: status, size: idiom.size(26, touch: 30))
      }
      VStack(alignment: .leading, spacing: 1) {
        Text(title).kitFont(.headline)
        if let meta { Text(meta).kitFont(.caption) }
      }
      .padding(.trailing, shortcut == nil ? 4 : 6)
      if let shortcut { ContKeycaps(shortcut: shortcut) }
    }
    .padding(.leading, systemImage == nil ? 10 : 7)
    .padding(.trailing, 8)
    .padding(.vertical, 7)
    .frame(minHeight: idiom.size(42, touch: 48))
    .background { SurfaceShape(surface: .floating, cornerRadius: idiom.isTouch ? KitMetrics.radiusXL : KitMetrics.radiusCard) }
  }
}

#Preview("Tooltip") {
  VStack(alignment: .leading, spacing: 12) {
    ContTooltipCard(title: "Pull", shortcut: "⇧⌘P", meta: "1 behind origin/main", systemImage: "arrow.down", hue: .accent, status: .idle)
    ContTooltipCard(title: "Fetch", shortcut: nil, meta: "Fetching origin…", systemImage: "arrow.clockwise", hue: .accent, status: .working)
    ContTooltipCard(title: "Push", shortcut: "⌘P", meta: "Nothing to push", systemImage: "arrow.up", hue: .gray, status: .idle)
    Button("Hover me", systemImage: "arrow.down") {}
      .buttonStyle(.kit)
      .kitHelp("Pull", shortcut: "⇧⌘P", meta: "1 behind origin/main", systemImage: "arrow.down")
  }
  .padding(40)
  .componentKit()
}
