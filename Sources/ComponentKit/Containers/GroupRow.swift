import SwiftUI

// Plain rows in a card (the canvas's `.ck-group-row` and `.ck-form-row`): a label, then a value or a control at the
// end, with a full-width hairline above each row. They're `FormRow` without the icon tile, for settings that don't
// need one and for short lists in a card (a library of steps under a header row). In a `FormCard` the first row's
// hairline falls under the card's mask, as `FormRow`'s does.

/// A plain row of a `FormCard`: the title with a line of help under it, and the control or value at the end. With an
/// action the whole row is a button that washes on hover and press. At `.controlSize(.small)` the row is the dense
/// 28pt line of a list in a card.
///
/// ```swift
/// FormCard("Pipeline settings") {
///   GroupRow("Big sorts use disk") { Toggle("Big sorts use disk", isOn: $disk).toggleStyle(.kitSwitch).kitLabelsHidden() }
///   GroupRow("Time limit", help: "0 runs without one") { KitStepper(…) }
/// }
/// FormCard {
///   GroupRow { Label("Filter and shape", systemImage: "line.3.horizontal.decrease") } trailing: { Text("5") }
///   ForEach(steps) { step in
///     GroupRow(step.name, action: { add(step) }) { Text(step.op).kitFont(.monoSmall).foregroundStyle(.kitSecondary) }
///   }
/// }
/// .controlSize(.small)
/// ```
public struct GroupRow<Label: View, Trailing: View>: View {
  var action: (() -> Void)?
  @ViewBuilder var label: Label
  @ViewBuilder var trailing: Trailing
  @Environment(\.controlSize) private var controlSize
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled

  /// A row with its own label: a tile and a headline for a header row, or anything else.
  public init(action: (() -> Void)? = nil, @ViewBuilder label: () -> Label, @ViewBuilder trailing: () -> Trailing) {
    self.action = action
    self.label = label()
    self.trailing = trailing()
  }

  private var isCompact: Bool { controlSize == .small || controlSize == .mini }

  public var body: some View {
    Group {
      if let action {
        Button(action: action) { row }
          .buttonStyle(ContGroupRowButtonStyle())
      } else {
        row
      }
    }
    .overlay(alignment: .top) {
      Rectangle().fill(.kitSeparator).frame(height: 0.5)
    }
    .opacity(isEnabled ? 1 : 0.5)
    .accessibilityElement(children: .combine)
  }

  private var row: some View {
    HStack(spacing: 10) {
      label
        .frame(maxWidth: .infinity, alignment: .leading)
      trailing
    }
    .padding(.horizontal, idiom.isTouch && !isCompact ? 14 : 12)
    .padding(.vertical, isCompact ? 2 : 6)
    .frame(minHeight: isCompact ? 28 : idiom.isTouch ? 44 : 40)
    .contentShape(.rect)
  }
}

extension GroupRow {
  /// A row with a title, a line of help under it, and the control or value at the end.
  public init(_ title: String, help: String? = nil, action: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing)
  where Label == ContGroupRowTitle {
    self.init(action: action, label: { ContGroupRowTitle(title: title, help: help) }, trailing: trailing)
  }

  /// A row with only a title: a link in a list.
  public init(_ title: String, help: String? = nil, action: (() -> Void)? = nil)
  where Label == ContGroupRowTitle, Trailing == EmptyView {
    self.init(title, help: help, action: action) { EmptyView() }
  }
}

/// A `GroupRow`'s title and help.
public struct ContGroupRowTitle: View {
  let title: String
  let help: String?

  public var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).kitFont(.body).foregroundStyle(.kitLabel).lineLimit(1)
      if let help {
        Text(help).kitFont(.caption).fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

/// A row that washes while hovered or pressed.
private struct ContGroupRowButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    ContGroupRowButton(configuration: configuration)
  }
}

private struct ContGroupRowButton: View {
  let configuration: ButtonStyleConfiguration
  @State private var isHovered = false
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    configuration.label
      .background {
        if isEnabled && (isHovered || configuration.isPressed) {
          Rectangle().fill(configuration.isPressed ? AnyShapeStyle(.kitPress) : AnyShapeStyle(.kitHover))
        }
      }
      .kitHover { isHovered = $0 }
  }
}
