import SwiftUI

// Drag and drop (the Drag, drop and tooltips board: dragging A, drop targets A). Selection, drag and drop are one
// object: a raised card that leaves a field-filled track and sits back into one.

extension View {
  /// Draws a dragged row: the raised card with the floating shadow, 3% larger, above its neighbours.
  ///
  /// ```swift
  /// MyRow(item).kitLifted(dragged == item.id)
  /// ```
  public func kitLifted(_ isLifted: Bool, cornerRadius: CGFloat = KitMetrics.radius) -> some View {
    modifier(ContLifted(isLifted: isLifted, cornerRadius: cornerRadius))
  }

  /// Draws a drop target: it rises to the raised card and wears the field ring (2pt, the accent at half strength). On a
  /// card section pass its corners (`KitMetrics.radiusCard`).
  ///
  /// ```swift
  /// SidebarRow(value: folder.id, folder.name, systemImage: "folder")
  ///   .kitDropTarget(isTargeted)
  ///   .onDrop(of: [.fileURL], isTargeted: $isTargeted) { … }
  /// ```
  public func kitDropTarget(_ isTargeted: Bool, cornerRadius: CGFloat = KitMetrics.radius) -> some View {
    modifier(ContDropTarget(isTargeted: isTargeted, cornerRadius: cornerRadius))
  }
}

private struct ContLifted: ViewModifier {
  let isLifted: Bool
  let cornerRadius: CGFloat
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    content
      .background {
        if isLifted {
          SurfaceShape(surface: .raised, cornerRadius: cornerRadius)
            .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.16), radius: 12, y: 8)
            .transition(.opacity)
        }
      }
      .scaleEffect(isLifted ? 1.03 : 1)
      .zIndex(isLifted ? 3 : 0)
      .animation(.kitFast, value: isLifted)
  }
}

private struct ContDropTarget: ViewModifier {
  let isTargeted: Bool
  let cornerRadius: CGFloat

  func body(content: Content) -> some View {
    content
      .background {
        if isTargeted {
          SurfaceShape(surface: .raised, cornerRadius: cornerRadius).transition(.opacity)
        }
      }
      .overlay {
        if isTargeted {
          RoundedRectangle(cornerRadius: cornerRadius + ContMetrics.ringWidth, style: .continuous)
            .strokeBorder(Hue.accent.soft(0.5), lineWidth: ContMetrics.ringWidth)
            .padding(-ContMetrics.ringWidth)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
      }
      .animation(.kitFast, value: isTargeted)
  }
}

/// The slot a dragged row will land in: the field-filled track the card sits back into, a row high (pass `height` for
/// a taller row). Put it where the row would drop in a hand-built list; `ReorderableSection` draws its own.
///
/// ```swift
/// if dropIndex == index { DropSlot() }
/// ```
public struct DropSlot: View {
  var height: CGFloat?
  @Environment(\.kitIdiom) private var idiom

  public init(height: CGFloat? = nil) { self.height = height }

  public var body: some View {
    RoundedRectangle(cornerRadius: ContMetrics.rowRadius(idiom), style: .continuous)
      .fill(.kitField)
      .frame(height: height ?? KitMetrics.row(idiom))
      .padding(.vertical, 1)
      .transition(.opacity.combined(with: .scale(scale: 1, anchor: .top)))
      .accessibilityHidden(true)
  }
}

#Preview("Drag and drop") {
  VStack(alignment: .leading, spacing: 2) {
    SidebarRow("atlas", systemImage: "shippingbox")
    DropSlot()
    SidebarRow("beacon", systemImage: "shippingbox").kitLifted(true)
    SidebarRow("harbor", systemImage: "folder").kitDropTarget(true)
    SidebarRow("pebble", systemImage: "shippingbox")
  }
  .padding(10)
  .frame(width: 240)
  .background(.kitSidebar)
  .componentKit()
}
