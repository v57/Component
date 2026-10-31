import SwiftUI

/// Read-only monospaced text on a field well: a command to confirm, a fingerprint, a file's contents, a live log. The
/// text is selectable; it wraps (or scrolls sideways with `wraps: false`); with `maxHeight` it hugs short text and
/// scrolls past that height (`.infinity` fills the pane); `followsEnd` keeps a growing log on its last line.
///
/// ```swift
/// KitCodeBlock(commands.joined(separator: "\n"))
/// KitCodeBlock(fingerprint, font: .monoSmall)
/// KitCodeBlock(session.output, wraps: false, maxHeight: .infinity, placeholder: "No output captured.")
/// KitCodeBlock(lines: runner.log, maxHeight: 240, followsEnd: true) { $0.contains("error") ? .red : nil }
/// ```
public struct KitCodeBlock: View {
  enum Source {
    case text(String)
    case lines([String], hue: ((String) -> Hue?)?)
  }

  var source: Source
  var wraps: Bool
  var maxHeight: CGFloat?
  var followsEnd: Bool
  var font: KitFont
  var placeholder: String?
  @Environment(\.kitIdiom) private var idiom
  @State private var contentHeight: CGFloat = 0

  /// One text, selectable as a whole. `placeholder` shows, quiet, while `text` is empty.
  public init(
    _ text: String, wraps: Bool = true, maxHeight: CGFloat? = nil, followsEnd: Bool = false, font: KitFont = .mono,
    placeholder: String? = nil
  ) {
    self.source = .text(text)
    self.wraps = wraps
    self.maxHeight = maxHeight
    self.followsEnd = followsEnd
    self.font = font
    self.placeholder = placeholder
  }

  /// A log, one view per line built lazily (thousands of lines stay cheap), each line selectable. `hue` colours a
  /// line (`nil`: the label colour), e.g. errors red.
  public init(
    lines: [String], wraps: Bool = true, maxHeight: CGFloat? = nil, followsEnd: Bool = false, font: KitFont = .mono,
    placeholder: String? = nil, hue: ((String) -> Hue?)? = nil
  ) {
    self.source = .lines(lines, hue: hue)
    self.wraps = wraps
    self.maxHeight = maxHeight
    self.followsEnd = followsEnd
    self.font = font
    self.placeholder = placeholder
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)
    framed
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .background { SurfaceShape(surface: .field, cornerRadius: KitMetrics.radiusCard) }
      .clipShape(shape)
  }

  @ViewBuilder
  private var framed: some View {
    if let maxHeight {
      let scroll = ScrollView(wraps ? .vertical : [.vertical, .horizontal]) {
        content
          .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
      }
      .scrollBounceBehavior(.basedOnSize, axes: [.vertical, .horizontal])
      if maxHeight == .infinity {
        scroll.frame(maxHeight: .infinity).kitFollowsEnd(followsEnd)
      } else {
        // Hugs short text; scrolls once it passes `maxHeight`.
        scroll.frame(height: min(max(contentHeight, 1), maxHeight)).kitFollowsEnd(followsEnd)
      }
    } else if wraps {
      content
    } else {
      ScrollView(.horizontal) { content }.scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }
  }

  private var content: some View {
    Group {
      switch source {
      case .text(let text):
        if text.isEmpty, let placeholder {
          Text(placeholder).foregroundStyle(.kitTertiary)
        } else {
          Text(text).textSelection(.enabled)
        }
      case .lines(let lines, let hue):
        if lines.isEmpty, let placeholder {
          Text(placeholder).foregroundStyle(.kitTertiary)
        } else {
          LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(lines.indices, id: \.self) { index in
              let line = lines[index]
              Text(line)
                .foregroundStyle(hue?(line).map { AnyShapeStyle($0.text) } ?? AnyShapeStyle(.kitLabel))
                .textSelection(.enabled)
            }
          }
        }
      }
    }
    .kitFont(font)
    .lineSpacing(2)
    .fixedSize(horizontal: !wraps, vertical: true)
    .frame(maxWidth: wraps ? .infinity : nil, alignment: .topLeading)
    .padding(idiom.size(10, touch: 12))
  }
}

extension View {
  /// Keeps a scroll view on its end as content arrives, the way a log reads: a short log starts at the top, a long
  /// one opens on its last line and follows new lines. Before macOS 15 and iOS 18 it keeps to the bottom only.
  ///
  /// ```swift
  /// ScrollView { RunBlocks { … } }.kitFollowsEnd()
  /// ```
  public func kitFollowsEnd(_ isOn: Bool = true) -> some View {
    modifier(KitFollowsEnd(isOn: isOn))
  }
}

private struct KitFollowsEnd: ViewModifier {
  let isOn: Bool

  func body(content: Content) -> some View {
    if !isOn {
      content
    } else if #available(macOS 15, iOS 18, tvOS 18, *) {
      content
        .defaultScrollAnchor(.top, for: .alignment)
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
    } else {
      content.defaultScrollAnchor(.bottom)
    }
  }
}
