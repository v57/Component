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

  /// `kitLifted`, its floating shadow left out (`hasShadow` false) where another card's shadow is drawn over it.
  func kitLifted(_ isLifted: Bool, cornerRadius: CGFloat, hasShadow: Bool) -> some View {
    modifier(ContLifted(isLifted: isLifted, cornerRadius: cornerRadius, hasShadow: hasShadow))
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

extension View {
  /// Draws a whole window or pane as a drop target with what a drop will do in its middle: the drop ring, and
  /// `KitDropLabel(title, systemImage:)` floating over the centre while `isTargeted`. Pass the window's corners
  /// (`KitMetrics.radiusWindow`) on a window's root.
  ///
  /// ```swift
  /// ContentView()
  ///   .kitDropTarget(isTargeted, label: "Drop to download", systemImage: "arrow.down", cornerRadius: KitMetrics.radiusWindow)
  ///   .onDrop(of: [.fileURL, .url], isTargeted: $isTargeted) { providers in … }
  /// ```
  public func kitDropTarget(
    _ isTargeted: Bool, label: String, systemImage: String, cornerRadius: CGFloat = KitMetrics.radius
  ) -> some View {
    kitDropTarget(isTargeted, cornerRadius: cornerRadius)
      .overlay {
        if isTargeted {
          KitDropLabel(label, systemImage: systemImage).transition(.opacity)
        }
      }
      .animation(.kit, value: isTargeted)
  }
}

/// What a drop will do, on the floating surface: "Drop to download", "Drop to Play". `kitDropTarget(_:label:systemImage:)`
/// shows it over a target's middle; put it yourself where a drop lands elsewhere. It takes no clicks.
///
/// ```swift
/// .overlay { if isTargeted { KitDropLabel("Drop to Play", systemImage: "play.fill") } }
/// ```
public struct KitDropLabel: View {
  var title: String
  var systemImage: String
  @Environment(\.kitIdiom) private var idiom

  public init(_ title: String, systemImage: String) {
    self.title = title
    self.systemImage = systemImage
  }

  public var body: some View {
    Label(title, systemImage: systemImage)
      .kitFont(.headline)
      .padding(EdgeInsets(horizontal: idiom.size(14, touch: 18), vertical: idiom.size(10, touch: 12)))
      .kitSurface(.floating, cornerRadius: KitMetrics.radiusCard)
      .allowsHitTesting(false)
  }
}

private struct ContLifted: ViewModifier {
  let isLifted: Bool
  let cornerRadius: CGFloat
  var hasShadow = true
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    content
      .background {
        if isLifted {
          SurfaceShape(surface: .raised, cornerRadius: cornerRadius)
            .shadow(color: .black.opacity(hasShadow ? (scheme == .dark ? 0.5 : 0.16) : 0), radius: 12, y: 8)
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
