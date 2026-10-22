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
public struct KitSparkline: View {
  var values: [Double]
  var hue: Hue

  public init(values: [Double], hue: Hue = .accent) {
    self.values = values
    self.hue = hue
  }

  public var body: some View {
    GeometryReader { proxy in
      let points = Self.points(values, in: proxy.size)
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

  static func points(_ values: [Double], in size: CGSize) -> [CGPoint] {
    guard values.count > 1, let low = values.min(), let high = values.max() else { return [] }
    let range = high - low
    let step = size.width / CGFloat(values.count - 1)
    return values.enumerated().map { index, value in
      let y = range > 0 ? (value - low) / range : 0.5
      // A pixel of room at the top and bottom keeps the stroke whole
      return CGPoint(x: CGFloat(index) * step, y: 1 + (size.height - 2) * (1 - y))
    }
  }
}
