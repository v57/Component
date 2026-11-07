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
  ///
  /// The label is a key (a literal), looked up in the app's strings.
  public func kitDropTarget(
    _ isTargeted: Bool, label: LocalizedStringKey, systemImage: String, cornerRadius: CGFloat = KitMetrics.radius
  ) -> some View {
    kitDropTarget(isTargeted, label: KitString(label), systemImage: systemImage, cornerRadius: cornerRadius)
  }

  /// The same with a label shown as it is.
  @_disfavoredOverload
  public func kitDropTarget(
    _ isTargeted: Bool, label: some StringProtocol, systemImage: String, cornerRadius: CGFloat = KitMetrics.radius
  ) -> some View {
    kitDropTarget(
      isTargeted, label: KitString(verbatim: String(label)), systemImage: systemImage, cornerRadius: cornerRadius)
  }

  func kitDropTarget(
    _ isTargeted: Bool, label: KitString, systemImage: String, cornerRadius: CGFloat
  ) -> some View {
    kitDropTarget(isTargeted, cornerRadius: cornerRadius)
      .overlay {
        if isTargeted {
          KitDropLabel(title: label, systemImage: systemImage).transition(.opacity)
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
  var title: KitString
  var systemImage: String
  @Environment(\.kitIdiom) private var idiom

  /// A label whose title is a key (a literal), looked up in the app's strings.
  public init(_ title: LocalizedStringKey, systemImage: String) {
    self.init(title: KitString(title), systemImage: systemImage)
  }

  /// The same with a title shown as it is.
  @_disfavoredOverload
  public init(_ title: some StringProtocol, systemImage: String) {
    self.init(title: KitString(verbatim: String(title)), systemImage: systemImage)
  }

  init(title: KitString, systemImage: String) {
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
      .backgroundPreferenceValue(ContDropFrameKey.self) { frame in
        if isTargeted {
          ContDropFrame(frame: frame) { SurfaceShape(surface: .raised, cornerRadius: cornerRadius) }
            .transition(.opacity)
        }
      }
      .overlayPreferenceValue(ContDropFrameKey.self) { frame in
        if isTargeted {
          ContDropFrame(frame: frame) {
            RoundedRectangle(cornerRadius: cornerRadius + ContMetrics.ringWidth, style: .continuous)
              .strokeBorder(Hue.accent.soft(0.5), lineWidth: ContMetrics.ringWidth)
              .padding(-ContMetrics.ringWidth)
          }
          .allowsHitTesting(false)
          .transition(.opacity)
        }
      }
      // A drop target around this one rings its own view.
      .transformPreference(ContDropFrameKey.self) { $0 = nil }
      .animation(.kitFast, value: isTargeted)
  }
}

/// Where a drop target on a view draws, when the view is one that runs to the window's edges (a `KitSidebar`): its
/// cards' column inside the gutter, so the ring sits in the gap rather than past the edges.
struct ContDropFrameKey: PreferenceKey {
  static let defaultValue: Anchor<CGRect>? = nil
  static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = value ?? nextValue() }
}

/// A drop target's ground or ring: on the frame its view reports when that view fills the target (a sidebar the
/// modifier is on; not one deeper in a window the ring goes around), else on the whole target.
private struct ContDropFrame<Shape: View>: View {
  let frame: Anchor<CGRect>?
  @ViewBuilder let shape: Shape

  var body: some View {
    GeometryReader { proxy in
      let rect = frame.map { proxy[$0] }
      // Within the widest gutter (16pt, iPhone) of either side.
      if let rect, rect.width >= proxy.size.width - 2 * ContMetrics.sidebarInset(.phone) - 1 {
        shape.frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
      } else {
        shape
      }
    }
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
