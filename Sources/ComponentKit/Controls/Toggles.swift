import SwiftUI

/// The kit's toggles, drawn by the kit: a switch, a checkbox and a chip. Each is a style on SwiftUI's `Toggle`, so
/// VoiceOver reads a toggle with its state, Space flips it when it has keyboard focus, and `.disabled` dims it.
///
/// ```swift
/// Toggle("Sync with iCloud", isOn: $sync).toggleStyle(.kitSwitch)
/// Toggle("Show remote branches", isOn: $remote).toggleStyle(.kitCheckbox)
/// Toggle("Failed only", isOn: $failedOnly).toggleStyle(.kitChip)
/// ```
public struct KitToggleStyle: ToggleStyle {
  public enum Kind: Hashable, Sendable {
    /// A field track with a white knob; the track turns to the accent when on. The label leads.
    case `switch`
    /// A small filled box; the accent with a white check when on. The label follows.
    case checkbox
    /// A chip: on the field fill when off, a raised card with an accent dot when on. Put several on a `ChipTrack`.
    case chip
  }

  var kind: Kind

  public init(_ kind: Kind) { self.kind = kind }

  public func makeBody(configuration: Configuration) -> some View {
    CtlToggle(configuration: configuration, kind: kind)
  }
}

extension ToggleStyle where Self == KitToggleStyle {
  public static var kitSwitch: KitToggleStyle { KitToggleStyle(.switch) }
  public static var kitCheckbox: KitToggleStyle { KitToggleStyle(.checkbox) }
  public static var kitChip: KitToggleStyle { KitToggleStyle(.chip) }
}

struct CtlToggle: View {
  let configuration: ToggleStyleConfiguration
  let kind: KitToggleStyle.Kind
  @FocusState private var isFocused: Bool
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.ctlInChipTrack) private var inTrack

  var body: some View {
    Button {
      withKitAnimation { configuration.isOn.toggle() }
    } label: {
      switch kind {
      case .switch:
        HStack(spacing: 8) {
          CtlToggleLabel { configuration.label }
          CtlSwitchTrack(isOn: configuration.isOn, isFocused: isFocused)
        }
      case .checkbox:
        HStack(spacing: 8) {
          CtlCheckbox(isOn: configuration.isOn, isFocused: isFocused)
          CtlToggleLabel { configuration.label }
        }
      case .chip:
        CtlChip(isOn: configuration.isOn, isFocused: isFocused) { configuration.label }
      }
    }
    .buttonStyle(CtlPressStyle())
    .focused($isFocused)
    .focusEffectDisabled()
    .opacity(isEnabled || kind == .chip ? 1 : 0.45)
    .preference(key: CtlTrackFocusKey.self, value: isFocused && kind == .chip && inTrack)
    .accessibilityRepresentation {
      Toggle(isOn: configuration.$isOn) { configuration.label }
        .toggleStyle(.switch)
    }
  }
}

extension EnvironmentValues {
  @Entry var kitLabelsHidden: Bool = false
}

extension View {
  /// Hides the labels of the controls inside, the kit's (switches, checkboxes) on every OS version as well as the
  /// system's: `.labelsHidden()` alone reaches the kit's toggles only from macOS 15 and iOS 18, since before that
  /// SwiftUI doesn't tell a style. The labels stay for VoiceOver.
  ///
  /// ```swift
  /// FormRow("Sync with iCloud") { Toggle("Sync with iCloud", isOn: $sync).toggleStyle(.kitSwitch).kitLabelsHidden() }
  /// ```
  public func kitLabelsHidden() -> some View {
    environment(\.kitLabelsHidden, true).labelsHidden()
  }
}

/// A switch's or checkbox's label, hidden by `.kitLabelsHidden()` or (macOS 15 and iOS 18 on) `.labelsHidden()`; it
/// stays for VoiceOver through the toggle's accessibility representation.
struct CtlToggleLabel<Label: View>: View {
  @ViewBuilder var label: Label
  @Environment(\.kitLabelsHidden) private var kitHidden

  var body: some View {
    if kitHidden {
      EmptyView()
    } else if #available(macOS 15.0, iOS 18.0, *) {
      CtlHideableLabel { label }
    } else {
      label
    }
  }
}

@available(macOS 15.0, iOS 18.0, *)
private struct CtlHideableLabel<Label: View>: View {
  @ViewBuilder var label: Label
  @Environment(\.labelsVisibility) private var visibility

  var body: some View {
    if visibility != .hidden { label }
  }
}

struct CtlSwitchTrack: View {
  let isOn: Bool
  let isFocused: Bool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.kitMoreContrast) private var moreContrast

  var body: some View {
    let (width, height, inset): (CGFloat, CGFloat, CGFloat) =
      switch idiom {
      case .mac: (36, 20, 1)
      case .pad: (44, 26, 1)
      case .phone: (51, 31, 2)
      case .tv: (72, 40, 2)
      }
    let knob = height - inset * 2
    Capsule()
      .fill(isOn ? AnyShapeStyle(Hue.accent.fill) : AnyShapeStyle(.kitFill))
      .overlay {
        if moreContrast { Capsule().strokeBorder(.kitBorder, lineWidth: 1) }
      }
      .overlay(alignment: isOn ? .trailing : .leading) {
        Circle()
          .fill(KitColor.ctlKnob)
          .overlay(Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
          .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
          .frame(width: knob, height: knob)
          .padding(inset)
      }
      .frame(width: width, height: height)
      .ctlStandaloneRing(isFocused, cornerRadius: nil)
  }
}

struct CtlCheckbox: View {
  let isOn: Bool
  let isFocused: Bool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let size: CGFloat = idiom.size(14, touch: 20)
    let radius: CGFloat = idiom.size(4.5, touch: 6)
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    ZStack {
      if isOn {
        shape.fill(Hue.accent.fill)
        Image(systemName: "checkmark")
          .font(.system(size: size * 0.62, weight: .bold))
          .foregroundStyle(KitColor.ctlKnob)
          .transition(.scale(scale: 0.5).combined(with: .opacity))
      } else {
        shape.fill(.kitField)
          .overlay(shape.strokeBorder(scheme == .dark ? KitColor.border : KitColor.separator, lineWidth: 0.5))
      }
    }
    .frame(width: size, height: size)
    .ctlStandaloneRing(isFocused, cornerRadius: radius)
  }
}

/// A chip: on its own it sits on the field fill; on a track it is clear until hovered (the half-strength card) or
/// on (the raised card with an accent dot). Pressing settles it (98%, flat).
struct CtlChip<Label: View>: View {
  let isOn: Bool
  let isFocused: Bool
  @ViewBuilder var label: Label
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.ctlInChipTrack) private var inTrack
  @Environment(\.ctlIsPressed) private var isPressed
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  var body: some View {
    let radius = CtlChipMetrics.radius(idiom)
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    let isLit = isEnabled && (isHovered || isPressed || (isFocused && inTrack))
    HStack(spacing: 5) {
      if isOn {
        Circle().fill(Hue.accent.fill).frame(width: 6, height: 6)
          .transition(.scale.combined(with: .opacity))
      }
      label
        .fontWeight(isOn ? .semibold : .regular)
    }
    .kitFont(.callout)
    .lineLimit(1)
    .foregroundStyle(foreground(isLit: isLit))
    .padding(.horizontal, CtlChipMetrics.padding(idiom))
    .frame(height: CtlChipMetrics.height(idiom))
    .background {
      if isOn && isEnabled {
        CtlRaisedCard(cornerRadius: radius, flat: isPressed)
      } else if isLit {
        shape.fill(inTrack ? AnyShapeStyle(KitColor.ctlGhost) : AnyShapeStyle(.kitFill))
      } else if !inTrack {
        shape.fill(.kitField)
      }
    }
    // A chip on its own is a field, so it keeps the field ring; on a track the track wears it.
    .ctlFieldRing(isFocused && !inTrack, cornerRadius: radius)
    .scaleEffect(isPressed && isEnabled ? 0.98 : 1)
    .kitHover { isHovered = $0 }
    .animation(.kitFast, value: isLit)
  }

  private func foreground(isLit: Bool) -> KitColor {
    if !isEnabled { return .tertiary }
    if !inTrack || isOn || isLit { return .label }
    return .secondary
  }
}

enum CtlChipMetrics {
  static func height(_ idiom: KitIdiom) -> CGFloat {
    switch idiom {
    case .mac: 24
    case .pad: 32
    case .phone: 34
    case .tv: 48
    }
  }
  static func padding(_ idiom: KitIdiom) -> CGFloat {
    switch idiom {
    case .mac: 10
    case .pad: 12
    case .phone: 14
    case .tv: 20
    }
  }
  static func radius(_ idiom: KitIdiom) -> CGFloat {
    switch idiom {
    case .mac: 8
    case .pad: 10
    case .phone: 11
    case .tv: 16
    }
  }
}

/// Chips on one field track: language columns, filters. The toggles inside become chips; the on ones are raised
/// with an accent dot, and the track takes the field ring while one of them has keyboard focus. Chips wrap onto
/// more lines when the track runs out of width.
///
/// ```swift
/// ChipTrack {
///   Toggle("English", isOn: $english)
///   Toggle("German", isOn: $german)
///   Toggle("Japanese", isOn: $japanese)
/// }
/// ```
public struct ChipTrack<Content: View>: View {
  @ViewBuilder var content: Content
  /// One line, built lazily: only the chips on screen exist — for a track of many chips in a
  /// horizontal scroll view, where the flow layout would build every chip up front.
  let lazy: Bool
  @Environment(\.kitIdiom) private var idiom

  public init(lazy: Bool = false, @ViewBuilder content: () -> Content) {
    self.lazy = lazy
    self.content = content()
  }

  public var body: some View {
    let radius = CtlChipMetrics.radius(idiom) + 2
    Group {
      if lazy {
        // Only as tall as its chips: a lazy stack takes all the height it is offered.
        LazyHStack(spacing: 2) { content }.fixedSize(horizontal: false, vertical: true)
      } else {
        CtlFlowLayout(spacing: 2, lineSpacing: 2) { content }
      }
    }
    .toggleStyle(.kitChip)
    .environment(\.ctlInChipTrack, true)
    .padding(2)
    .background { CtlTrack(cornerRadius: radius) }
    .overlayPreferenceValue(CtlTrackFocusKey.self) { isFocused in
      Color.clear.ctlFieldRing(isFocused, cornerRadius: radius)
    }
    .accessibilityElement(children: .contain)
  }
}

#Preview("Toggles") {
  @Previewable @State var sync = true
  @Previewable @State var off = false
  @Previewable @State var remote = true
  @Previewable @State var english = true
  @Previewable @State var german = true
  @Previewable @State var japanese = false
  @Previewable @State var failed = true
  VStack(alignment: .leading, spacing: 14) {
    HStack(spacing: 20) {
      Toggle("Sync", isOn: $sync)
      Toggle("Off", isOn: $off)
      Toggle("Disabled", isOn: .constant(true)).disabled(true)
    }
    .toggleStyle(.kitSwitch)
    VStack(alignment: .leading) {
      Toggle("Show remote branches", isOn: $remote)
      Toggle("Off", isOn: $off)
    }
    .toggleStyle(.kitCheckbox)
    HStack {
      Toggle("Hidden label", isOn: $sync).toggleStyle(.kitSwitch).kitLabelsHidden()
      Toggle("Hidden label", isOn: $remote).toggleStyle(.kitCheckbox).kitLabelsHidden()
    }
    ChipTrack {
      Toggle("English", isOn: $english)
      Toggle("German", isOn: $german)
      Toggle("Japanese", isOn: $japanese)
      Toggle("Korean", isOn: .constant(false)).disabled(true)
    }
    HStack {
      Toggle("Video", isOn: $off)
      Toggle("Failed only", isOn: $failed)
    }
    .toggleStyle(.kitChip)
  }
  .padding(20)
  .componentKit()
}
