import SwiftUI

// MARK: - Popover

extension View {
  /// Shows `content` on the kit's overlay card beside this view while `isPresented`, in place of `.popover`: under
  /// the view (or over it with `edge: .top`, or on whichever side has room), centred on it and kept 8pt inside the
  /// window. Nothing dims; a click or tap outside closes it (and goes no further), as do Escape and the content's own
  /// buttons (close it from inside with `@Environment(\.kitDismiss)` or the binding). On the Mac its first field takes
  /// focus and Tab stays in it, and the window behind waits, as under a kit sheet. On iPhone, where there's no room
  /// beside a view, it is a kit sheet in the middle of the screen. The content sizes the card: give it a width when
  /// it wraps text, and a `ScrollView` when it can run long (the card is never taller than the room it has). On a tool
  /// in a `kitToolbar` slot it opens once, under the tool you see (the bar's hidden measuring copies don't present).
  ///
  /// ```swift
  /// Button("Add Filter", systemImage: "plus") { addingFilter = true }
  ///   .buttonStyle(.kit)
  ///   .kitPopover(isPresented: $addingFilter) {
  ///     AddFilterView { filter in addingFilter = false; add(filter) }
  ///       .frame(width: 320)
  ///   }
  /// ```
  public func kitPopover<Content: View>(
    isPresented: Binding<Bool>, edge: VerticalEdge = .bottom, @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    modifier(KitPopoverPresenter(isPresented: isPresented, edge: edge, popover: content))
  }
}

/// Where the anchored view is, in the window's space. Only the open popover's card reads it, so scrolling the
/// view (which moves it every frame) redraws nothing else, and the card follows it.
@MainActor @Observable
final class ContPopoverAnchor {
  var frame: CGRect = .zero
}

struct KitPopoverPresenter<Popover: View>: ViewModifier {
  @Binding var isPresented: Bool
  let edge: VerticalEdge
  let popover: () -> Popover
  @State private var anchor = ContPopoverAnchor()
  @Environment(\.kitOverlayHost) private var host
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.contMeasuringCopy) private var isMeasuringCopy

  func body(content: Content) -> some View {
    if isMeasuringCopy {
      // A kit toolbar's hidden copy of its tools: the popover anchors to the visible tool alone.
      content
    } else if host == nil {
      // Outside `componentKit()`: the system's popover.
      content.popover(isPresented: $isPresented, arrowEdge: edge == .bottom ? .bottom : .top) { popover() }
    } else {
      let anchor = anchor
      let style: KitOverlayStyle = idiom == .phone ? .sheet : .popover(anchor: anchor, edge: edge)
      content
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
          if anchor.frame != frame { anchor.frame = frame }
        }
        .modifier(KitOverlayPresenter(isPresented: $isPresented, style: style, onDismiss: nil, content: popover))
    }
  }
}

/// Places a popover's card beside its anchor: on the preferred side when it fits there, else on the side that fits
/// (or has more room), centred on the anchor and kept `margin` inside; never taller than its side's room.
struct ContPopoverLayout: Layout {
  var anchor: CGRect
  var edge: VerticalEdge
  var gap: CGFloat = 6
  var margin: CGFloat = KitMetrics.gutter

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    proposal.replacingUnspecifiedDimensions()
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard let card = subviews.first else { return }
    let placed = Self.place(
      ideal: card.sizeThatFits(.unspecified), in: bounds.size, anchor: anchor, edge: edge, gap: gap, margin: margin)
    let size = card.sizeThatFits(ProposedViewSize(placed.size))
    let fitted = CGSize(width: min(size.width, placed.size.width), height: min(size.height, placed.size.height))
    card.place(
      at: CGPoint(x: bounds.minX + placed.origin.x, y: bounds.minY + placed.origin.y),
      proposal: ProposedViewSize(fitted))
  }

  /// The card's frame in a space of `bounds`: `ideal` cut to the room it has.
  static func place(
    ideal: CGSize, in bounds: CGSize, anchor: CGRect, edge: VerticalEdge, gap: CGFloat, margin: CGFloat
  ) -> CGRect {
    let below = bounds.height - anchor.maxY - gap - margin
    let above = anchor.minY - gap - margin
    let preferred = edge == .bottom ? below : above
    let other = edge == .bottom ? above : below
    let isBelow: Bool =
      if ideal.height <= preferred { edge == .bottom } else if ideal.height <= other { edge != .bottom } else {
        below >= above
      }
    let width = min(ideal.width, max(0, bounds.width - 2 * margin))
    let height = min(ideal.height, max(0, isBelow ? below : above))
    let x = min(max(anchor.midX - width / 2, margin), max(margin, bounds.width - width - margin))
    let y = isBelow ? anchor.maxY + gap : anchor.minY - gap - height
    return CGRect(x: x, y: y, width: width, height: height)
  }
}
