import SwiftUI

// Internal helpers the controls share: the tokens they need beyond the foundation, the focus rings of the
// Accessibility board (focus C) and Hover A's press state. Candidates for Foundation.

extension KitColor {
  /// A focused or hovered item that is not selected: the raised colour at half strength (white 8% in dark).
  static let ctlGhost = KitColor(.white(0.5), .white(0.08), more: .white(0.7), .white(0.14))
  /// A switch's and a slider's knob: white in both appearances.
  static let ctlKnob = KitColor(.white(1), .white(1))
  /// A slider's track over a video or a photo: white at 50% in both appearances.
  static let ctlOnMedia = KitColor(.white(0.5), .white(0.5))
}

extension EnvironmentValues {
  /// Set by `CtlPressStyle` on its label: whether the button is being pressed.
  @Entry var ctlIsPressed: Bool = false
  /// Whether a chip sits on a `ChipTrack` (transparent when off) or on its own (on the field fill).
  @Entry var ctlInChipTrack: Bool = false
}

/// A button style that draws nothing and tells its label whether it is pressed (`\.ctlIsPressed`), so a control can
/// keep a Button's keyboard focus, Space and accessibility and still draw its own press.
struct CtlPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .environment(\.ctlIsPressed, configuration.isPressed)
      .contentShape(Rectangle())
  }
}

/// Collects whether any item inside a track has keyboard focus, so the track can wear the field ring.
struct CtlTrackFocusKey: PreferenceKey {
  static let defaultValue = false
  static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

extension View {
  /// What stands alone (a switch, a checkbox, a tab, a choice card, the slider's knob) takes the solid accent ring
  /// outside a 2pt gap while it has keyboard focus. `cornerRadius` nil rings a capsule.
  func ctlStandaloneRing(_ isOn: Bool, cornerRadius: CGFloat?) -> some View {
    overlay {
      if isOn {
        Group {
          if let cornerRadius {
            RoundedRectangle(cornerRadius: cornerRadius + 3, style: .continuous).stroke(Hue.accent.fill, lineWidth: 2)
          } else {
            Capsule().stroke(Hue.accent.fill, lineWidth: 2)
          }
        }
        .padding(-3)
        .allowsHitTesting(false)
        .transition(.opacity)
      }
    }
  }

  /// The field ring: 2pt outside the shape, the accent (or red) at half strength; solid under Increase Contrast.
  /// Fields, tracks (while an item inside has focus) and a picked choice card wear it.
  func ctlFieldRing(_ isOn: Bool, hue: Hue = .accent, cornerRadius: CGFloat) -> some View {
    #if os(tvOS)
      // No rings on Apple TV: the focused item itself grows and lights.
      self
    #else
      overlay { CtlFieldRing(isOn: isOn, hue: hue, cornerRadius: cornerRadius) }
    #endif
  }
}

struct CtlFieldRing: View {
  var isOn: Bool
  var hue: Hue
  var cornerRadius: CGFloat
  @Environment(\.kitMoreContrast) private var moreContrast

  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius + 1, style: .continuous)
      .stroke(hue.soft(moreContrast ? 1 : 0.5), lineWidth: 2)
      .padding(-1)
      .opacity(isOn ? 1 : 0)
      .allowsHitTesting(false)
      .animation(.kitFast, value: isOn)
  }
}

/// The item that is on, on a field track: the raised card. Under Increase Contrast it adds a 1.5pt accent edge.
struct CtlRaisedCard: View {
  var cornerRadius: CGFloat
  /// Pressing settles the card: flat, no shadow (Hover A).
  var flat = false
  @Environment(\.kitMoreContrast) private var moreContrast

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    Group {
      if flat {
        shape.fill(.kitRaised)
      } else {
        SurfaceShape(surface: .raised, cornerRadius: cornerRadius)
      }
    }
    .overlay {
      if moreContrast { shape.strokeBorder(Hue.accent.fill, lineWidth: 1.5) }
    }
  }
}

/// A field track (segmented control, chip track, stepper): the field well, with a 1pt edge under Increase Contrast.
struct CtlTrack: View {
  var cornerRadius: CGFloat

  var body: some View {
    SurfaceShape(surface: .field, cornerRadius: cornerRadius)
  }
}

/// Lays out items in rows that wrap, left to right: chip tracks and key hints.
struct CtlFlowLayout: Layout {
  var spacing: CGFloat
  var lineSpacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    return CtlFlow.size(of: CtlFlow.frames(sizes, maxWidth: proposal.width, spacing: spacing, lineSpacing: lineSpacing))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    let frames = CtlFlow.frames(sizes, maxWidth: bounds.width, spacing: spacing, lineSpacing: lineSpacing)
    for (subview, frame) in zip(subviews, frames) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
    }
  }
}

/// The flow layout's math, apart from SwiftUI so it can be tested.
enum CtlFlow {
  /// Frames for items of `sizes`, wrapping to a new line before an item that would pass `maxWidth` (nil: one line).
  /// Items in a line are centred vertically on the line's tallest item.
  static func frames(_ sizes: [CGSize], maxWidth: CGFloat?, spacing: CGFloat, lineSpacing: CGFloat) -> [CGRect] {
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
      var x: CGFloat = 0
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
