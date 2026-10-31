import SwiftUI

/// Picks a hue from a row of swatches: a connection's or a project's colour tag. The picked swatch wears a ring; with
/// an optional selection a dashed "no colour" swatch leads. Each swatch is a button VoiceOver reads by its hue.
///
/// ```swift
/// FormRow("Color", systemImage: "paintpalette", hue: tag ?? .gray) { KitHuePicker(selection: $tag) }
/// KitHuePicker(selection: $project.hue, hues: [.blue, .green, .orange, .purple])
/// ```
public struct KitHuePicker: View {
  /// The colour tags offered by default: every hue but the accent, in the spectrum's order.
  public static let tagHues: [Hue] = [.red, .orange, .yellow, .green, .teal, .blue, .indigo, .purple, .pink, .brown, .gray]

  @Binding var selection: Hue?
  var hues: [Hue]
  var allowsNone: Bool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled

  /// A picker whose first swatch is "no colour" (`nil`).
  public init(selection: Binding<Hue?>, hues: [Hue] = KitHuePicker.tagHues) {
    self._selection = selection
    self.hues = hues
    self.allowsNone = true
  }

  /// A picker that always has a hue.
  public init(selection: Binding<Hue>, hues: [Hue] = KitHuePicker.tagHues) {
    self._selection = Binding(get: { selection.wrappedValue }, set: { if let hue = $0 { selection.wrappedValue = hue } })
    self.hues = hues
    self.allowsNone = false
  }

  public var body: some View {
    HStack(spacing: idiom.size(2, touch: 4)) {
      if allowsNone { swatch(nil) }
      ForEach(hues, id: \.self) { swatch($0) }
    }
    .opacity(isEnabled ? 1 : 0.45)
  }

  private func swatch(_ hue: Hue?) -> some View {
    let size = idiom.size(16, touch: 24)
    let isSelected = selection == hue
    return Button {
      withKitAnimation { selection = hue }
    } label: {
      ZStack {
        if let hue {
          Circle().fill(hue.fill)
        } else {
          Circle().strokeBorder(.kitTertiary, style: StrokeStyle(lineWidth: 1, dash: [2]))
        }
      }
      .frame(width: size, height: size)
      .padding(3)
      .overlay { Circle().strokeBorder(isSelected ? AnyShapeStyle(.kitLabel) : AnyShapeStyle(Color.clear), lineWidth: 2) }
      .contentShape(Circle())
    }
    .buttonStyle(CtlPressStyle())
    .accessibilityLabel(hue.map { $0.rawValue.capitalized } ?? "No color")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
