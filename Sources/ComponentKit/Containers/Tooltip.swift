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
  /// It draws in the view's overlay, so put it on views whose container doesn't clip (a scroll view clips). In a
  /// `KitSidebar` the sidebar draws it, over every card and stuck title, kept inside the sidebar (above the row when
  /// there's no room under it).
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
  @State private var id = UUID()
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.contTooltipHost) private var hasHost

  func body(content: Content) -> some View {
    if idiom == .phone {
      content.help(title)
    } else if hasHost {
      content
        .kitHover(perform: hover)
        .simultaneousGesture(TapGesture().onEnded { hide() })
        // Drawn by the container (`ContTooltipHost`), over every card and title.
        .anchorPreference(key: ContTooltipKey.self, value: .bounds) { [isShown, card, id] bounds in
          isShown ? [ContTooltip(id: id, card: card, anchor: bounds)] : []
        }
        .accessibilityHint([meta, shortcut].compactMap { $0 }.joined(separator: ", "))
        .onAppear { if KitLaunchOptions.shownTooltip == title { isShown = true } }
        .onDisappear { pending?.cancel() }
    } else {
      content
        .kitHover(perform: hover)
        .simultaneousGesture(TapGesture().onEnded { hide() })
        .overlay(alignment: .bottom) {
          if isShown {
            card
              .fixedSize()
              .alignmentGuide(.bottom) { $0[.top] - ContTooltipHost.gap }
              .allowsHitTesting(false)
              .transition(.opacity)
          }
        }
        .zIndex(isShown ? 100 : 0)
        .accessibilityHint([meta, shortcut].compactMap { $0 }.joined(separator: ", "))
        .onAppear { if KitLaunchOptions.shownTooltip == title { isShown = true } }
        .onDisappear { pending?.cancel() }
    }
  }

  private var card: ContTooltipCard {
    ContTooltipCard(
      title: title, shortcut: shortcut, meta: meta, systemImage: systemImage, hue: isEnabled ? hue : .gray,
      status: status)
  }

  private func hover(_ inside: Bool) {
    pending?.cancel()
    if inside {
      if Date().timeIntervalSince(ContTooltipClock.lastHidden) < ContTooltipClock.carryOver {
        isShown = true
      } else {
        pending = Task { @MainActor in
          await kitSleep(for: ContTooltipClock.delay)
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

/// A shown tooltip on its way to its container: its card and the view it explains.
struct ContTooltip: Identifiable {
  let id: UUID
  let card: ContTooltipCard
  let anchor: Anchor<CGRect>
}

struct ContTooltipKey: PreferenceKey {
  static let defaultValue: [ContTooltip] = []
  static func reduce(value: inout [ContTooltip], nextValue: () -> [ContTooltip]) { value += nextValue() }
}

extension EnvironmentValues {
  /// Inside a container that draws its tooltips over itself (`ContTooltipHost`).
  @Entry var contTooltipHost = false
}

/// A container's tooltips (`kitHelp`), drawn over everything in it: each under the view it explains, centred on it and
/// kept 8pt inside the container's edges (no wider than it), or above the view when there's no room under it. Only where the views stay
/// in one hosting view: a system toolbar item's preferences never reach the window's root, so the root draws none.
struct ContTooltipHost: ViewModifier {
  static let gap: CGFloat = 6

  func body(content: Content) -> some View {
    content
      .environment(\.contTooltipHost, true)
      .overlayPreferenceValue(ContTooltipKey.self, alignment: .topLeading) { tooltips in
        GeometryReader { proxy in
          ForEach(tooltips) { tooltip in
            ContTooltipPlacement(anchor: proxy[tooltip.anchor]) { tooltip.card }
              .allowsHitTesting(false)
              .transition(.opacity)
          }
        }
      }
      .transformPreference(ContTooltipKey.self) { $0 = [] }
  }
}

/// Lays a tooltip's card out at its own size under (or over) the view it explains, inside the proposed bounds.
private struct ContTooltipPlacement: Layout {
  let anchor: CGRect

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    proposal.replacingUnspecifiedDimensions()
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard let card = subviews.first else { return }
    let gutter = KitMetrics.gutter
    // At its own width while that fits, else as wide as the container allows (its lines wrap): the container may
    // clip what reaches past it (a split view's sidebar column does).
    let ideal = card.sizeThatFits(.unspecified)
    let room = max(0, bounds.width - 2 * gutter)
    let size = ideal.width <= room ? ideal : card.sizeThatFits(ProposedViewSize(width: room, height: nil))
    let x = min(max(anchor.midX - size.width / 2, gutter), max(gutter, bounds.width - gutter - size.width))
    let below = anchor.maxY + ContTooltipHost.gap
    let y = below + size.height <= bounds.height - gutter || anchor.minY - ContTooltipHost.gap - size.height < gutter
      ? below : anchor.minY - ContTooltipHost.gap - size.height
    card.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(size))
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
    .padding(EdgeInsets(top: 7, leading: systemImage == nil ? 10 : 7, bottom: 7, trailing: 8))
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
