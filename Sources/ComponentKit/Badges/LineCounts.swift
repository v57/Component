import SwiftUI

/// Lines added and removed as "+14 −2", monospaced in green and red (a side with nothing is left out); "binary"
/// when there are no line counts.
///
/// ```swift
/// LineCounts(added: 14, removed: 2)
/// LineCounts(added: nil, removed: nil)   // binary
/// ```
public struct LineCounts: View {
  var added: Int?
  var removed: Int?
  @Environment(\.kitIdiom) private var idiom

  public init(added: Int?, removed: Int?) {
    self.added = added
    self.removed = removed
  }

  public var body: some View {
    let size = badgeFigureSize(idiom)
    if let added, let removed {
      // A side with nothing is left out (+38, −120); nothing at all reads +0 −0.
      let showsBoth = added == 0 && removed == 0
      HStack(spacing: 6) {
        if added > 0 || showsBoth {
          Text("+\(added)").foregroundStyle(Hue.green.text)
            .contentTransition(.numericText(value: Double(added)))
        }
        if removed > 0 || showsBoth {
          Text("−\(removed)").foregroundStyle(Hue.red.text)
            .contentTransition(.numericText(value: Double(removed)))
        }
      }
      .font(.system(size: size, design: .monospaced))
      .lineLimit(1)
      .fixedSize()
      .animation(.kit, value: [added, removed])
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(added) lines added, \(removed) removed")
    } else {
      Text("binary")
        .font(.system(size: size))
        .foregroundStyle(.kitSecondary)
    }
  }
}

/// Line counts that end in a five-block diffstat: "+14 −2 ■■■■■", the blocks split green and red in proportion
/// (fewer than five coloured when fewer lines changed).
///
/// ```swift
/// Diffstat(added: 14, removed: 2)
/// Diffstat(added: 54, removed: 122, showsCounts: false)   // the bar alone
/// ```
public struct Diffstat: View {
  var added: Int?
  var removed: Int?
  var showsCounts: Bool
  @Environment(\.kitIdiom) private var idiom

  public init(added: Int?, removed: Int?, showsCounts: Bool = true) {
    self.added = added
    self.removed = removed
    self.showsCounts = showsCounts
  }

  public var body: some View {
    HStack(spacing: 6) {
      if showsCounts { LineCounts(added: added, removed: removed) }
      if let added, let removed {
        let blocks = Self.blocks(added: added, removed: removed)
        let side: CGFloat = idiom.size(6, pad: 7, phone: 8)
        HStack(spacing: 1.5) {
          ForEach(0..<Self.blockCount, id: \.self) { index in
            RoundedRectangle(cornerRadius: idiom == .phone ? 2 : 1.5, style: .continuous)
              .fill(fill(index, blocks))
              .frame(width: side, height: side)
          }
        }
        .animation(.kit, value: blocks.added)
        .animation(.kit, value: blocks.removed)
        .accessibilityHidden(showsCounts)
        .accessibilityLabel("\(added) lines added, \(removed) removed")
      }
    }
  }

  private func fill(_ index: Int, _ blocks: (added: Int, removed: Int)) -> AnyShapeStyle {
    if index < blocks.added { return AnyShapeStyle(Hue.green.fill) }
    if index < blocks.added + blocks.removed { return AnyShapeStyle(Hue.red.fill) }
    return AnyShapeStyle(.kitFill)
  }

  nonisolated static let blockCount = 5

  /// How many of the five blocks are green and red: one block per changed line up to five, split in proportion,
  /// and a side that changed always keeps at least one block.
  nonisolated static func blocks(added: Int, removed: Int) -> (added: Int, removed: Int) {
    let added = max(added, 0)
    let removed = max(removed, 0)
    let total = added + removed
    guard total > 0 else { return (0, 0) }
    let colored = min(total, blockCount)
    var green = Int((Double(added) / Double(total) * Double(colored)).rounded())
    if added > 0 { green = max(green, 1) }
    if removed > 0 { green = min(green, colored - 1) }
    return (green, colored - green)
  }
}

/// A small progress bar for rows and meta lines (20×4pt; 24×5 on touch), in the accent or a hue. The work's state
/// lives in the group's live icon; a row keeps only this and its percent (`ProgressRow`).
///
/// ```swift
/// MicroBar(value: 0.4)
/// MicroBar(value: 1, hue: .green, width: 28)
/// ```
public struct MicroBar: View {
  var value: Double
  var hue: Hue
  var width: CGFloat?
  @Environment(\.kitIdiom) private var idiom

  public init(value: Double, hue: Hue = .accent, width: CGFloat? = nil) {
    self.value = value
    self.hue = hue
    self.width = width
  }

  public var body: some View {
    let height: CGFloat = idiom.size(4, touch: 5)
    let barWidth = width ?? (idiom.size(20, pad: 24, phone: 26))
    Capsule()
      .fill(.kitFill)
      .overlay(alignment: .leading) {
        Capsule()
          .fill(hue.fill)
          .frame(width: barWidth * Self.clamped(value))
      }
      .frame(width: barWidth, height: height)
      .clipShape(Capsule())
      .animation(.kit, value: value)
      .accessibilityElement()
      .accessibilityLabel("\(Int((Self.clamped(value) * 100).rounded())) percent")
  }

  nonisolated static func clamped(_ value: Double) -> Double { value.isFinite ? min(max(value, 0), 1) : 0 }
}

/// A row's progress: a microbar and its percent, in the accent (gray in an inactive window).
///
/// ```swift
/// ProgressRow(value: 0.25)   // ━──  25%
/// ```
public struct ProgressRow: View {
  var value: Double
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitWindowIsActive) private var isActive

  public init(value: Double) { self.value = value }

  public var body: some View {
    let percent = Int((MicroBar.clamped(value) * 100).rounded())
    HStack(spacing: 6) {
      MicroBar(value: value, hue: isActive ? .accent : .gray, width: idiom == .phone ? 40 : 36)
      Text("\(percent)%")
        .contentTransition(.numericText(value: Double(percent)))
        .frame(minWidth: 28, alignment: .trailing)
    }
    .font(.system(size: badgeFigureSize(idiom), weight: .semibold).monospacedDigit())
    .foregroundStyle(isActive ? AnyShapeStyle(Hue.accent.fill) : AnyShapeStyle(.kitSecondary))
    .animation(.kit, value: percent)
    .fixedSize()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(percent) percent")
  }
}

#Preview("Line counts") {
  VStack(alignment: .leading, spacing: 10) {
    Diffstat(added: 12, removed: 3)
    Diffstat(added: 38, removed: 0)
    Diffstat(added: 0, removed: 120)
    Diffstat(added: 2, removed: 2)
    LineCounts(added: 54, removed: 122)
    LineCounts(added: nil, removed: nil)
    HStack(spacing: 12) {
      MicroBar(value: 0.6)
      ProgressRow(value: 0.25)
    }
  }
  .padding()
  .componentKit()
}
