import SwiftUI

/// The kit's icon tile: a glyph on a soft rounded square in its hue (15%), or solid for apps.
/// A `LiveIcon` is the same tile wearing a ring that carries work: progress, the work indicator (`.kitWorkIndicator(_:)`), done or failed.
public struct Tile<Content: View>: View {
  public enum Style: Hashable, Sendable {
    /// The hue at 15% under the hue: things, sections, rows.
    case soft
    /// Filled with the hue, white glyph: apps.
    case solid
    /// No ground, just the glyph in the hue (compact sidebars).
    case plain
  }

  var hue: Hue
  var size: CGFloat
  var style: Style
  var shape: KitShape
  @ViewBuilder var content: Content

  public init(
    hue: Hue = .accent, size: CGFloat = 24, style: Style = .soft, shape: KitShape = .rounded,
    @ViewBuilder content: () -> Content
  ) {
    self.hue = hue
    self.size = size
    self.style = style
    self.shape = shape
    self.content = content()
  }

  public var body: some View {
    content
      .font(.system(size: size * 0.58, weight: .semibold))
      .imageScale(.small)
      .foregroundStyle(style == .solid ? AnyShapeStyle(Color.white) : AnyShapeStyle(hue.fill))
      .frame(width: size, height: size)
      .environment(\.kitGlyphSize, size * 0.62)
      .background {
        switch style {
        case .soft: shape.shape(size: size).fill(hue.soft())
        case .solid: shape.shape(size: size).fill(hue.fill)
        case .plain: EmptyView()
        }
      }
      .accessibilityHidden(true)
  }
}

extension Tile where Content == Image {
  /// A tile with an SF Symbol.
  public init(systemImage: String, hue: Hue = .accent, size: CGFloat = 24, style: Style = .soft) {
    self.init(hue: hue, size: size, style: style) { Image(systemName: systemImage) }
  }
}

extension Tile where Content == Text {
  /// A tile with one or two letters ("Pg", "A").
  public init(letters: String, hue: Hue = .accent, size: CGFloat = 24, style: Style = .soft, shape: KitShape = .rounded) {
    self.init(hue: hue, size: size, style: style, shape: shape) { Self.letters(letters, size: size) }
  }

  /// One or two letters sized for a tile `size` wide.
  static func letters(_ letters: String, size: CGFloat) -> Text {
    Text(letters.prefix(2)).font(.system(size: size * (letters.count > 1 ? 0.42 : 0.5), weight: .bold))
  }
}

extension EnvironmentValues {
  /// The size a drawn glyph takes where it sits: set by `Tile`, `LiveIcon` and `RowTile` for the glyph inside them
  /// (an SF Symbol follows the font instead). A custom glyph view reads it to fit any tile; `BranchGlyph` does.
  ///
  /// ```swift
  /// struct PlugGlyph: View {
  ///   @Environment(\.kitGlyphSize) private var size
  ///   var body: some View { PlugShape().stroke(.foreground).frame(width: size ?? 16, height: size ?? 16) }
  /// }
  /// RowTile { PlugGlyph() }
  /// ```
  @Entry public var kitGlyphSize: CGFloat? = nil
}

/// Shape says kind: people are circles, agents and things rounded squares.
public enum KitShape: Hashable, Sendable {
  case rounded, circle

  /// The tile's corner: 7pt at 24, scaling with the size.
  func shape(size: CGFloat) -> AnyShape {
    switch self {
    case .circle: AnyShape(Circle())
    case .rounded: AnyShape(RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
    }
  }
}

/// A tile that carries work: the ring shows progress (or the work indicator while indeterminate), settles green with a check when
/// done and red when it failed. Put a `WorkStatus` on it and the kit does the rest.
///
/// ```swift
/// LiveIcon(systemImage: "arrow.up", status: .working(progress: 0.4))
/// ```
public struct LiveIcon<Content: View>: View {
  var hue: Hue
  var status: WorkStatus
  var size: CGFloat
  var shape: KitShape
  @ViewBuilder var content: Content

  public init(
    hue: Hue = .accent, status: WorkStatus, size: CGFloat = 24, shape: KitShape = .rounded,
    @ViewBuilder content: () -> Content
  ) {
    self.hue = hue
    self.status = status
    self.size = size
    self.shape = shape
    self.content = content()
  }

  public var body: some View {
    let tint = status.hue ?? hue
    Tile(hue: tint, size: size, shape: shape) {
      ZStack {
        switch status {
        case .done:
          Image(systemName: "checkmark").fontWeight(.bold).transition(.scale.combined(with: .opacity))
        case .failed:
          Image(systemName: "exclamationmark").fontWeight(.bold).transition(.scale.combined(with: .opacity))
        default:
          content.transition(.opacity)
        }
      }
    }
    .overlay { StatusRing(status: status, hue: tint, size: size, shape: shape) }
    .animation(.kit, value: status)
    .accessibilityElement()
    .accessibilityLabel(Self.label(status))
  }

  static func label(_ status: WorkStatus) -> String {
    switch status {
    case .idle: ""
    case .working(let p): p.map { "\(Int($0 * 100)) percent" } ?? "Working"
    case .paused: "Paused"
    case .done: "Done"
    case .failed(let message): message ?? "Failed"
    }
  }
}

extension LiveIcon where Content == Image {
  public init(systemImage: String, hue: Hue = .accent, status: WorkStatus, size: CGFloat = 24, shape: KitShape = .rounded) {
    self.init(hue: hue, status: status, size: size, shape: shape) { Image(systemName: systemImage) }
  }
}

extension LiveIcon where Content == Text {
  /// A live icon with one or two letters, as `Tile(letters:)` draws them: an engine's monogram carrying its
  /// connection's state.
  ///
  /// ```swift
  /// LiveIcon(letters: "Pg", hue: .blue, status: connection.isConnecting ? .working : .idle, size: 28)
  /// ```
  public init(letters: String, hue: Hue = .accent, status: WorkStatus, size: CGFloat = 24, shape: KitShape = .rounded) {
    self.init(hue: hue, status: status, size: size, shape: shape) { Tile<Text>.letters(letters, size: size) }
  }
}
