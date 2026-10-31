import SwiftUI

/// Lays its views out left to right in lines that wrap before a view that wouldn't fit: tags, chips, key hints,
/// action bars, a device code's groups. Views in a line are centred on its tallest; `alignment` places each line in
/// the width (`.center` for a centred cluster of buttons). A view wider than the line gets a line of its own.
///
/// ```swift
/// KitFlowLayout(spacing: 6) { ForEach(tags, id: \.self) { Chip($0) } }
/// KitFlowLayout(spacing: 8, lineSpacing: 8, alignment: .center) { actions }
/// ```
public struct KitFlowLayout: Layout {
  var spacing: CGFloat
  var lineSpacing: CGFloat
  var alignment: HorizontalAlignment

  /// `lineSpacing` defaults to `spacing`.
  public init(spacing: CGFloat = 6, lineSpacing: CGFloat? = nil, alignment: HorizontalAlignment = .leading) {
    self.spacing = spacing
    self.lineSpacing = lineSpacing ?? spacing
    self.alignment = alignment
  }

  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let size = KitFlow.size(of: KitFlow.frames(sizes, maxWidth: proposal.width, spacing: spacing, lineSpacing: lineSpacing))
    // Lines placed in the width need all of it.
    if alignment != .leading, let width = proposal.width, width.isFinite { return CGSize(width: width, height: size.height) }
    return size
  }

  public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let frames = KitFlow.frames(
      sizes, maxWidth: bounds.width, spacing: spacing, lineSpacing: lineSpacing, alignment: KitFlow.factor(alignment))
    for (subview, frame) in zip(subviews, frames) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
        proposal: ProposedViewSize(frame.size))
    }
  }
}

/// The flow layout's math, apart from SwiftUI so it can be tested.
enum KitFlow {
  /// How far into the free width a line moves: 0 leading, 0.5 centred, 1 trailing.
  static func factor(_ alignment: HorizontalAlignment) -> CGFloat {
    alignment == .center ? 0.5 : alignment == .trailing ? 1 : 0
  }

  /// Frames for items of `sizes`, wrapping to a new line before an item that would pass `maxWidth` (nil: one line).
  /// Items in a line are centred vertically on the line's tallest item; `alignment` (0…1) moves each line into the
  /// width it leaves free.
  static func frames(
    _ sizes: [CGSize], maxWidth: CGFloat?, spacing: CGFloat, lineSpacing: CGFloat, alignment: CGFloat = 0
  ) -> [CGRect] {
    var lines: [[Int]] = [[]]
    var x: CGFloat = 0
    for (index, size) in sizes.enumerated() {
      let start = lines[lines.count - 1].isEmpty ? 0 : x + spacing
      if let maxWidth, !lines[lines.count - 1].isEmpty, start + size.width > maxWidth + 0.5 {
        lines.append([index])
        x = size.width
      } else {
        lines[lines.count - 1].append(index)
        x = start + size.width
      }
    }
    var frames = [CGRect](repeating: .zero, count: sizes.count)
    var y: CGFloat = 0
    for line in lines where !line.isEmpty {
      let height = line.map { sizes[$0].height }.max() ?? 0
      let width = line.map { sizes[$0].width }.reduce(0, +) + spacing * CGFloat(line.count - 1)
      var x: CGFloat = 0
      if alignment > 0, let maxWidth, maxWidth.isFinite { x = max(0, maxWidth - width) * alignment }
      for index in line {
        let size = sizes[index]
        frames[index] = CGRect(x: x, y: y + (height - size.height) / 2, width: size.width, height: size.height)
        x += size.width + spacing
      }
      y += height + lineSpacing
    }
    return frames
  }

  static func size(of frames: [CGRect]) -> CGSize {
    CGSize(width: frames.map(\.maxX).max() ?? 0, height: frames.map(\.maxY).max() ?? 0)
  }
}
