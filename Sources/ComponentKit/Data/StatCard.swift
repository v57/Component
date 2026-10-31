import SwiftUI

/// A number that sums something up, on a card: the icon tile and label, the value large, a delta in its meaning's
/// colour and a line under it, and an optional sparkline of its recent values. A row of them heads an overview (Hub's
/// APIs, Devices, Requests / s, Storage).
///
/// ```swift
/// KitStatCard("Requests / s", value: "1,204", systemImage: "waveform.path.ecg", hue: .purple,
///             delta: "+8%", detail: "this hour", sparkline: rates)
/// KitStatCard("Devices", value: "6", systemImage: "laptopcomputer", hue: .gray, detail: "5 online · 1 waiting")
/// ```
public struct KitStatCard: View {
  var label: String
  var value: String
  var systemImage: String
  var hue: Hue
  var delta: String?
  var deltaHue: Hue
  var detail: String?
  var sparkline: [Double]
  var action: (@MainActor () -> Void)?
  @Environment(\.kitIdiom) private var idiom

  /// - Parameters:
  ///   - delta: a change shown after the value ("+8%"), in `deltaHue` (green by default; red for a change for the worse).
  ///   - sparkline: recent values, oldest first; two or more draw a line with a soft fill under it.
  ///   - action: makes the card a button (it opens the page the number comes from).
  public init(
    _ label: String, value: String, systemImage: String, hue: Hue = .accent, delta: String? = nil,
    deltaHue: Hue = .green, detail: String? = nil, sparkline: [Double] = [], action: (@MainActor () -> Void)? = nil
  ) {
    self.label = label
    self.value = value
    self.systemImage = systemImage
    self.hue = hue
    self.delta = delta
    self.deltaHue = deltaHue
    self.detail = detail
    self.sparkline = sparkline
    self.action = action
  }

  public var body: some View {
    if let action {
      Button(action: action) { card }.buttonStyle(.plain)
    } else {
      card
    }
  }

  private var card: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Tile(systemImage: systemImage, hue: hue, size: idiom.size(20, touch: 22))
        Text(label).kitFont(.caption).lineLimit(1)
      }
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(value)
          .font(.system(size: idiom.size(24, touch: 26), weight: .bold))
          .monospacedDigit()
          .contentTransition(.numericText())
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        if let delta {
          Text(delta).kitFont(.caption).fontWeight(.semibold).foregroundStyle(deltaHue.text)
        }
        if let detail {
          Text(detail).kitFont(.caption).lineLimit(1)
        }
      }
      if sparkline.count > 1 {
        KitSparkline(values: sparkline, hue: hue)
          .frame(height: idiom.size(30, touch: 30))
      }
    }
    .padding(idiom.size(10, touch: 12))
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .kitSurface(.card)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

/// A line through recent values with a soft fill under it, scaled to its own range: a stat's trend at a glance.
///
/// ```swift
/// KitSparkline(values: [3, 5, 4, 8, 7, 9], hue: .purple).frame(height: 30)
/// ```
///
/// For a live graph, `range` fixes the scale (a percentage's 0…100), `capacity` keeps a fixed number of slots with the
/// newest value at the right edge (a ten-minute window filling from the right), and `axisLabel` writes the scale's
/// top, middle and bottom on the trailing edge, with a hairline across at each.
///
/// ```swift
/// KitSparkline(values: cpu, hue: .blue, range: 0...100, capacity: 600) { "\(Int($0))%" }.frame(height: 140)
/// ```
public struct KitSparkline: View {
  var values: [Double]
  var hue: Hue
  var range: ClosedRange<Double>?
  var capacity: Int?
  var axisLabel: ((Double) -> String)?

  public init(
    values: [Double], hue: Hue = .accent, range: ClosedRange<Double>? = nil, capacity: Int? = nil,
    axisLabel: ((Double) -> String)? = nil
  ) {
    self.values = values
    self.hue = hue
    self.range = range
    self.capacity = capacity
    self.axisLabel = axisLabel
  }

  public var body: some View {
    if let axisLabel {
      let scale = Self.scale(values, range: range)
      HStack(alignment: .center, spacing: 6) {
        chart
          .background {
            VStack(spacing: 0) {
              ForEach(0..<3) { index in
                if index > 0 { Spacer(minLength: 0) }
                Rectangle().fill(.kitSeparator).frame(height: 1)
              }
            }
          }
        VStack(alignment: .trailing, spacing: 0) {
          let marks = [scale.upperBound, (scale.lowerBound + scale.upperBound) / 2, scale.lowerBound]
          ForEach(0..<3) { index in
            if index > 0 { Spacer(minLength: 0) }
            Text(axisLabel(marks[index])).kitFont(.monoSmall).foregroundStyle(.kitTertiary).fixedSize()
          }
        }
      }
    } else {
      chart
    }
  }

  private var chart: some View {
    GeometryReader { proxy in
      let points = Self.points(values, in: proxy.size, range: range, capacity: capacity)
      ZStack {
        Path { path in
          guard let first = points.first, let last = points.last else { return }
          path.move(to: CGPoint(x: first.x, y: proxy.size.height))
          points.forEach { path.addLine(to: $0) }
          path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
          path.closeSubpath()
        }
        .fill(hue.soft())
        Path { path in
          guard let first = points.first else { return }
          path.move(to: first)
          points.dropFirst().forEach { path.addLine(to: $0) }
        }
        .stroke(hue.fill, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
      }
    }
    .accessibilityHidden(true)
  }

  /// The values' scale: `range`, or their own lowest to highest.
  static func scale(_ values: [Double], range: ClosedRange<Double>?) -> ClosedRange<Double> {
    if let range { return range }
    guard let low = values.min(), let high = values.max() else { return 0...1 }
    return low...high
  }

  static func points(
    _ values: [Double], in size: CGSize, range: ClosedRange<Double>? = nil, capacity: Int? = nil
  ) -> [CGPoint] {
    let values = capacity.map { Array(values.suffix(max($0, 2))) } ?? values
    guard values.count > 1 else { return [] }
    let scale = Self.scale(values, range: range)
    let span = scale.upperBound - scale.lowerBound
    let slots = max(capacity ?? values.count, values.count)
    let step = size.width / CGFloat(slots - 1)
    // With a capacity the newest value sits at the right edge and the window fills from the right.
    let start = slots - values.count
    return values.enumerated().map { index, value in
      let y = span > 0 ? min(max((value - scale.lowerBound) / span, 0), 1) : 0.5
      // A pixel of room at the top and bottom keeps the stroke whole
      return CGPoint(x: CGFloat(start + index) * step, y: 1 + (size.height - 2) * (1 - y))
    }
  }
}
