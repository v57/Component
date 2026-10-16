import SwiftUI

/// How a choice card lays out its content.
public enum KitChoiceCardStyle: Hashable, Sendable {
  /// A row: the content side by side, leading, 48pt tall (56 on iPad, 60 on iPhone).
  case row
  /// A tall card for something to look at (an app icon's appearance, a theme, a layout): the content stacked and
  /// centred, as tall as it needs.
  case tall
}

extension EnvironmentValues {
  @Entry var kitChoiceCardStyle: KitChoiceCardStyle = .row
}

extension View {
  /// Sets how the choice cards inside lay out: `.row` (the default) or `.tall` for visual choices.
  ///
  /// ```swift
  /// HStack(spacing: KitMetrics.gutter) {
  ///   ForEach(Appearance.allCases) { look in
  ///     ChoiceCard(isOn: $appearance.picks(look)) {
  ///       IconPreview(look).frame(width: 96, height: 96)
  ///       Text(look.title).kitFont(.callout)
  ///     }
  ///   }
  /// }
  /// .kitChoiceCardStyle(.tall)
  /// ```
  public func kitChoiceCardStyle(_ style: KitChoiceCardStyle) -> some View {
    environment(\.kitChoiceCardStyle, style)
  }
}

/// A selectable card (engines, locations, templates): on the field fill when off, lifted to a raised card with the
/// 2pt ring at half the accent when picked. Hover rises half-way, pressing settles it; keyboard focus gives the solid
/// ring and Space picks. VoiceOver reads a button, selected when picked.
///
/// ```swift
/// HStack(spacing: KitMetrics.gutter) {
///   ChoiceCard("PostgreSQL", subtitle: "Port 5432", letters: "PG", hue: .blue, isOn: $engine.picks(.postgres))
///   ChoiceCard("SQLite", subtitle: "A file on this Mac", systemImage: "doc", isOn: $engine.picks(.sqlite))
/// }
/// ChoiceCard(isOn: $custom) { Text("Custom…") }
/// ```
public struct ChoiceCard<Content: View>: View {
  @Binding var isOn: Bool
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @FocusState private var isFocused: Bool

  public init(isOn: Binding<Bool>, @ViewBuilder content: () -> Content) {
    _isOn = isOn
    self.content = content()
  }

  public var body: some View {
    let radius = Self.radius(idiom)
    Button {
      withKitAnimation { isOn = true }
    } label: {
      CtlChoiceCardBody(isOn: isOn, radius: radius) { content }
    }
    .buttonStyle(CtlPressStyle())
    .focused($isFocused)
    .focusEffectDisabled()
    .ctlStandaloneRing(isFocused, cornerRadius: radius)
    .opacity(isEnabled ? 1 : 0.45)
    .accessibilityAddTraits(isOn ? .isSelected : [])
  }

  static func radius(_ idiom: KitIdiom) -> CGFloat {
    switch idiom {
    case .mac: 12
    case .pad: 14
    case .phone: 16
    }
  }
}

struct CtlChoiceCardBody<Content: View>: View {
  let isOn: Bool
  let radius: CGFloat
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.ctlIsPressed) private var isPressed
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitChoiceCardStyle) private var style
  @State private var isHovered = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    let height: CGFloat =
      switch idiom {
      case .mac: 48
      case .pad: 56
      case .phone: 60
      }
    let layout =
      style == .tall
      ? AnyLayout(VStackLayout(alignment: .center, spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
    layout { content }
      .padding(.horizontal, 10)
      .padding(.vertical, style == .tall ? 10 : 0)
      .frame(maxWidth: .infinity, minHeight: style == .tall ? nil : height, alignment: style == .tall ? .center : .leading)
      .background {
        if isOn {
          CtlRaisedCard(cornerRadius: radius, flat: isPressed)
        } else {
          shape.fill(.kitField)
          if isEnabled && (isHovered || isPressed) { shape.fill(KitColor.ctlGhost) }
        }
      }
      .ctlFieldRing(isOn, cornerRadius: radius)
      .scaleEffect(isPressed && isEnabled ? 0.98 : 1)
      .onHover { isHovered = $0 }
      .animation(.kitFast, value: isHovered)
      .animation(.kitFast, value: isPressed)
  }
}

/// A choice card's usual content: a tile, the title and a line under it.
///
/// ```swift
/// ChoiceCard(isOn: $engine.picks(.duckdb)) {
///   ChoiceCardLabel("DuckDB", subtitle: "Download") { LiveIcon(systemImage: "arrow.down", status: download) }
/// }
/// ```
public struct ChoiceCardLabel<Icon: View>: View {
  var title: String
  var subtitle: String?
  @ViewBuilder var icon: Icon

  public init(_ title: String, subtitle: String? = nil, @ViewBuilder icon: () -> Icon) {
    self.title = title
    self.subtitle = subtitle
    self.icon = icon()
  }

  public var body: some View {
    HStack(spacing: 10) {
      icon
      VStack(alignment: .leading, spacing: 1) {
        Text(title).kitFont(.body).foregroundStyle(.kitLabel)
        if let subtitle {
          Text(subtitle).kitFont(.caption)
        }
      }
      .lineLimit(1)
    }
    .accessibilityElement(children: .combine)
  }
}

extension ChoiceCard where Content == ChoiceCardLabel<Tile<Image>> {
  /// A choice card with an SF Symbol tile, a title and a subtitle.
  public init(_ title: String, subtitle: String? = nil, systemImage: String, hue: Hue = .accent, isOn: Binding<Bool>) {
    self.init(isOn: isOn) {
      ChoiceCardLabel(title, subtitle: subtitle) { Tile(systemImage: systemImage, hue: hue, size: 26) }
    }
  }
}

extension ChoiceCard where Content == ChoiceCardLabel<Tile<Text>> {
  /// A choice card with a letters tile ("PG"), a title and a subtitle.
  public init(_ title: String, subtitle: String? = nil, letters: String, hue: Hue = .accent, isOn: Binding<Bool>) {
    self.init(isOn: isOn) {
      ChoiceCardLabel(title, subtitle: subtitle) { Tile(letters: letters, hue: hue, size: 26) }
    }
  }
}

extension Binding where Value: Equatable & Sendable {
  /// Whether the value is `option`; setting it to true picks `option`. For a row of choice cards (or chips) that
  /// pick one value: `ChoiceCard(…, isOn: $engine.picks(.postgres))`.
  public func picks(_ option: Value) -> Binding<Bool> {
    Binding<Bool>(
      get: { wrappedValue == option },
      set: { if $0 { wrappedValue = option } })
  }
}

#Preview("Tall choice cards") {
  @Previewable @State var look = "light"
  HStack(spacing: KitMetrics.gutter) {
    ForEach(["light", "dark", "tinted"], id: \.self) { name in
      ChoiceCard(isOn: $look.picks(name)) {
        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Hue.blue.fill).frame(width: 80, height: 80)
        Text(name.capitalized).kitFont(.callout)
      }
    }
  }
  .kitChoiceCardStyle(.tall)
  .padding(20)
  .componentKit()
}

#Preview("Choice cards") {
  @Previewable @State var engine = "pg"
  HStack(spacing: KitMetrics.gutter) {
    ChoiceCard("PostgreSQL", subtitle: "Port 5432", letters: "PG", hue: .blue, isOn: $engine.picks("pg"))
    ChoiceCard("MySQL", subtitle: "Port 3306", letters: "My", hue: .teal, isOn: $engine.picks("my"))
    ChoiceCard("DuckDB", subtitle: "Download", letters: "DK", hue: .orange, isOn: $engine.picks("dk")).disabled(true)
  }
  .padding(20)
  .frame(width: 600)
  .componentKit()
}
