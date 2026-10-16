import SwiftUI

// Pop-ups: `KitPicker` (the forms' select, a filled field naming the value with the up-down chevrons) and
// `KitMenuButton` (a raised pill with a chevron that opens any menu: Find options, a scheme, a host). Both open the
// kit's menu (`Menu.swift`), so the menu looks the same on every platform.

/// The kit's pop-up picker (the select): the picked value's title on the field well, 30pt (36 on iPad, 44 on
/// iPhone), 9pt corners, the up-down chevrons at the end; it opens the kit's menu of options under it, at least as
/// wide, the picked one checked. For settings and forms: `FormRow("Theme") { KitPicker(selection: $theme) }`.
///
/// ```swift
/// KitPicker("Theme", selection: $theme)                                         // a KitOption & CaseIterable enum
/// KitPicker("Indent", selection: $indent, options: [("2 spaces", 2), ("4 spaces", 4), ("Tabs", 0)])
/// KitPicker("Branch", selection: $branch, segments: branches.map { KitSegment($0.name, value: $0.id, systemImage: "arrow.triangle.branch") })
/// ```
///
/// `title` names it for VoiceOver and the menu; it isn't drawn (a form row's label says what it is).
public struct KitPicker<Value: Hashable>: View {
  var title: String
  @Binding var selection: Value
  var segments: [KitSegment<Value>]
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @FocusState private var isFocused: Bool
  @State private var isHovered = false
  @State private var isOpen = false

  /// A picker over `segments` (titles, values, optional glyphs; disabled ones can't be picked).
  public init(_ title: String = "", selection: Binding<Value>, segments: [KitSegment<Value>]) {
    self.title = title
    _selection = selection
    self.segments = segments
  }

  /// A picker over titled values.
  public init(_ title: String = "", selection: Binding<Value>, options: [(String, Value)]) {
    self.init(title, selection: selection, segments: options.map { KitSegment($0.0, value: $0.1) })
  }

  private var current: KitSegment<Value>? { segments.first { $0.value == selection } }

  public var body: some View {
    let metrics = KitPickerMetrics(idiom)
    let shape = RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)
    HStack(spacing: 6) {
      if let systemImage = current?.systemImage {
        Image(systemName: systemImage)
          .imageScale(.small)
          .foregroundStyle(.kitSecondary)
      }
      Text(current?.title ?? "")
        .kitFont(.body)
        .foregroundStyle(.kitLabel)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.up.chevron.down")
        .font(.system(size: metrics.chevron, weight: .semibold))
        .foregroundStyle(.kitSecondary)
    }
    .padding(.leading, metrics.leading)
    .padding(.trailing, metrics.trailing)
    .frame(minWidth: metrics.minWidth, minHeight: metrics.height)
    .background {
      shape.fill(.kitField)
      if (isHovered || isOpen) && isEnabled { shape.fill(.kitHover) }
    }
    .contentShape(shape)
    .fixedSize(horizontal: true, vertical: false)
    .focusable()
    .kitMenuTrigger(isPresented: $isOpen, matchesWidth: true) {
      KitMenuOptions(selection: $selection, segments: segments)
    }
    .opacity(isEnabled ? 1 : 0.45)
    .focused($isFocused)
    .focusEffectDisabled()
    .ctlFieldRing(isFocused, cornerRadius: metrics.radius)
    .onHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
    .accessibilityLabel(title)
    .accessibilityValue(current?.title ?? "")
  }
}

extension KitPicker where Value: KitOption {
  /// A picker over `options`, titled (and given glyphs) by the options themselves.
  public init(_ title: String = "", selection: Binding<Value>, options: [Value]) {
    self.init(
      title, selection: selection,
      segments: options.map { KitSegment($0.title, value: $0, systemImage: $0.systemImage) })
  }
}

extension KitPicker where Value: KitOption & CaseIterable {
  /// A picker over every case of a `KitOption` enum.
  public init(_ title: String = "", selection: Binding<Value>) {
    self.init(title, selection: selection, options: Array(Value.allCases))
  }
}

struct KitPickerMetrics {
  var height: CGFloat
  var radius: CGFloat
  var leading: CGFloat
  var trailing: CGFloat
  var chevron: CGFloat
  var minWidth: CGFloat

  init(_ idiom: KitIdiom) {
    switch idiom {
    case .mac: (height, radius, leading, trailing, chevron, minWidth) = (30, 9, 10, 8, 9, 96)
    case .pad: (height, radius, leading, trailing, chevron, minWidth) = (36, 12, 12, 10, 10, 120)
    case .phone: (height, radius, leading, trailing, chevron, minWidth) = (44, 14, 14, 12, 11, 120)
    }
  }
}

// MARK: - Menu button

/// A pop-up button: a raised pill with an optional glyph, the title and a chevron; its content is the kit's menu
/// under it (Find options, the scheme, a host, "Sort by"): `Button`, `Toggle`, `Divider`, `KitMenuOptions`,
/// `KitSubmenu`. 26pt on the Mac (`.controlSize(.small)` 22), 32 on touch.
///
/// ```swift
/// KitMenuButton("Options", systemImage: "slider.horizontal.3") {
///   Toggle("Match Case", isOn: $matchCase)
///   Toggle("Whole Words", isOn: $wholeWords)
/// }
/// KitMenuButton(scheme.name, systemImage: "hammer") { ForEach(schemes) { s in Button(s.name) { pick(s) } } }
/// KitMenuButton("Match") { KitMenuOptions(selection: $match, options: [("Contains", .contains), ("Exact", .exact)]) }
/// ```
public struct KitMenuButton<Content: View>: View {
  var title: String
  var systemImage: String?
  var content: Content
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.controlSize) private var controlSize
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false
  @State private var isOpen = false

  public init(_ title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  public var body: some View {
    let small = controlSize == .small || controlSize == .mini
    let height: CGFloat = idiom.isTouch ? (small ? 28 : 32) : (small ? 22 : 26)
    HStack(spacing: 5) {
      if let systemImage {
        Image(systemName: systemImage).font(.system(size: height * 0.4, weight: .semibold))
      }
      Text(title)
        .font(.system(size: idiom.isTouch ? 15 : small ? 11 : 12, weight: .medium))
        .lineLimit(1)
      Image(systemName: "chevron.down")
        .font(.system(size: height * 0.3, weight: .bold))
        .foregroundStyle(.kitSecondary)
    }
    .foregroundStyle(.kitLabel)
    .padding(.horizontal, idiom.isTouch ? 10 : 8)
    .frame(height: height)
    .background {
      CtlRaisedCard(cornerRadius: height * 0.3)
        .overlay {
          RoundedRectangle(cornerRadius: height * 0.3, style: .continuous)
            .fill(Color.primary.opacity((isHovered || isOpen) && isEnabled ? 0.04 : 0))
        }
    }
    .contentShape(Rectangle())
    .fixedSize()
    .focusable()
    .focusEffectDisabled()
    .kitMenuTrigger(isPresented: $isOpen) { content }
    .opacity(isEnabled ? 1 : 0.45)
    .onHover { isHovered = $0 }
    .animation(.kitFast, value: isHovered)
    .accessibilityLabel(title)
  }
}

private enum PreviewTheme: String, KitOption, CaseIterable {
  case system = "System", light = "Light", dark = "Dark"
  var title: String { rawValue }
}

#Preview("Pickers") {
  @Previewable @State var theme = PreviewTheme.system
  @Previewable @State var indent = 4
  @Previewable @State var matchCase = true
  VStack(alignment: .leading, spacing: 14) {
    KitPicker("Theme", selection: $theme)
    KitPicker("Indent", selection: $indent, options: [("2 spaces", 2), ("4 spaces", 4), ("Tabs", 0)])
    KitPicker("Disabled", selection: $indent, options: [("4 spaces", 4)]).disabled(true)
    HStack {
      KitMenuButton("Options", systemImage: "slider.horizontal.3") { Toggle("Match Case", isOn: $matchCase) }
      KitMenuButton("Atlas", systemImage: "hammer") { Button("Atlas") {} }.controlSize(.small)
    }
  }
  .padding(20)
  .componentKit()
}
