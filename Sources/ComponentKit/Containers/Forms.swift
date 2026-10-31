import SwiftUI

// Forms with rich rows (the Forms page, pick C): a card per group, each row an icon tile, the label and a line of help
// or the value, the control at the end. A text field opens as a full-width filled line under its row; a focused or
// wrong field gets the 2pt half-strength ring, and the error itself is red text under the label.

/// A group of form rows as one card, with an optional title above it and a footnote under it. Rows are separated by a
/// hairline that starts at the label (after the tile).
///
/// ```swift
/// FormCard("Devices", footer: "Shared by Git, Shell, Database, Markdown, Code and Dev.") {
///   FormRow("This Mac", help: "Key in the Secure Enclave", systemImage: "laptopcomputer", hue: .gray)
///   FormRow("iPad Pro", help: "Last seen yesterday", systemImage: "ipad", hue: .gray) {
///     Button("Remove", role: .destructive) { … }.buttonStyle(.kit)
///   }
/// }
/// ```
public struct FormCard<Content: View>: View {
  var title: String?
  var footer: String?
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom

  public init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.footer = footer
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let title {
        FormHeading(title)
      }
      VStack(alignment: .leading, spacing: 0) { content }
        // Every row draws the hairline above it; the first row's falls under this 1pt mask.
        .mask {
          VStack(spacing: 0) {
            Color.clear.frame(height: 1)
            Rectangle()
          }
        }
        .kitSurface(.card, cornerRadius: ContMetrics.cardRadius(idiom))
      if let footer {
        Text(footer)
          .kitFont(.caption)
          .padding(.horizontal, 12)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

/// The title of a group of form rows, set as `FormCard`'s title is: a headline 12pt in from the card's edge. Put it
/// over a group that isn't a `FormCard` (a grid of choice cards) so it lines up with the form's other titles.
///
/// ```swift
/// VStack(alignment: .leading, spacing: 8) {
///   FormHeading("Location")
///   LazyVGrid(columns: columns, spacing: KitMetrics.gutter) { ChoiceCard(…) }
/// }
/// ```
public struct FormHeading: View {
  var title: String

  public init(_ title: String) { self.title = title }

  public var body: some View {
    Text(title)
      .kitFont(.headline)
      .padding(.horizontal, 12)
      .accessibilityAddTraits(.isHeader)
  }
}

/// A rich form row: an icon tile, the label with a line of help (or the current value) under it, and the control at
/// the end. With `error` the tile and the line turn red and the error replaces the help; with `status` the tile is the
/// live icon carrying the work (installing a tool). A row made with `field:` opens its text field as a full-width
/// filled line under it, with a trailing live icon for `status` (checking a URL); it can have a control at the end
/// too.
///
/// ```swift
/// FormRow("Open when done", help: "In its default app", systemImage: "arrow.up.forward.app", hue: .indigo) {
///   Toggle("Open when done", isOn: $open).labelsHidden()
/// }
/// FormRow("Repository URL", help: "GitHub, GitLab or any Git URL", systemImage: "link", error: urlError,
///         status: checking, field: TextField("https://", text: $url))
/// FormRow("Address", systemImage: "network", field: TextField("Address", text: $address)) {
///   Button("Connect") { … }.buttonStyle(.kitPrimary)
/// }
/// ```
///
/// A row without `systemImage` and a control is stacked: the title (and `value` at its end) over the control, which
/// takes the row's width (a slider, a wide segmented control).
///
/// ```swift
/// FormCard {
///   FormRow("Size", value: "\(Int(size)) pt") { KitSlider("Size", value: $size, in: 12...48) }
///   FormRow("Alignment") { KitSegmented(selection: $alignment, options: …).kitSegmentedStyle(.wide) }
/// }
/// ```
///
/// Chained on the row: `.titleAccessory { }` sets a chip right after the title, `.detail { }` a line of small
/// controls under the row, lined up with its title.
///
/// ```swift
/// FormRow("Primary", help: "Runs this chat's agents", systemImage: "laptopcomputer", status: sync) { … }
///   .titleAccessory { Chip("Demo", style: .quiet) }
///   .detail { Toggle("Only with a config file", isOn: $needsConfig).toggleStyle(.kitCheckbox) }
/// ```
public struct FormRow<Control: View, Field: View>: View {
  var title: String
  var help: String?
  var systemImage: String?
  var hue: Hue
  var error: String?
  var status: WorkStatus
  /// The tile's work (`status:` on a row without a field).
  var tileStatus: WorkStatus = .idle
  var value: String?
  var isStacked = false
  var titleAccessory: AnyView?
  var detailView: AnyView?
  @ViewBuilder var control: Control
  @ViewBuilder var field: Field
  @FocusState private var fieldFocused: Bool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitFormHelpWhileEditing) private var helpWhileEditing

  init(
    title: String, help: String?, systemImage: String?, hue: Hue, error: String?, status: WorkStatus,
    @ViewBuilder control: () -> Control, @ViewBuilder field: () -> Field
  ) {
    self.title = title
    self.help = help
    self.systemImage = systemImage
    self.hue = hue
    self.error = error
    self.status = status
    self.control = control()
    self.field = field()
  }

  private var hasField: Bool { Field.self != EmptyView.self }

  /// The help line shows, unless the form keeps it for while its field is being edited
  private var showsHelp: Bool { !helpWhileEditing || !hasField || fieldFocused }

  /// Sets a small view right after the title: a chip ("Primary", "Demo"), a dot, a count.
  ///
  /// ```swift
  /// FormRow(machine.name, help: detail, systemImage: "laptopcomputer") { StatusLabel(…) }
  ///   .titleAccessory { Chip("Primary", hue: .accent) }
  /// ```
  public func titleAccessory<V: View>(@ViewBuilder _ content: () -> V) -> Self {
    var row = self
    row.titleAccessory = AnyView(content())
    return row
  }

  /// Puts a line of small controls under the row, lined up with its title and running to its end (a formatter's
  /// "Only with a config file" and its custom command). Controls in it are small.
  ///
  /// ```swift
  /// FormRow(formatter.name, help: formatter.languages, systemImage: "text.alignleft", hue: .orange) { … }
  ///   .detail {
  ///     Toggle("Only with a config file", isOn: $needsConfig).toggleStyle(.kitCheckbox).fixedSize()
  ///     Spacer(minLength: 0)
  ///     TextField("Custom command", text: $command).kitField(mono: true).frame(width: 220)
  ///   }
  /// ```
  public func detail<V: View>(@ViewBuilder _ content: () -> V) -> Self {
    var row = self
    row.detailView = AnyView(HStack(spacing: 8) { content() })
    return row
  }

  public var body: some View {
    let tile: CGFloat = idiom.size(24, touch: 30)
    let lead: CGFloat = systemImage == nil ? 0 : tile + 12
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        if let systemImage {
          if tileStatus != .idle {
            LiveIcon(systemImage: systemImage, hue: error == nil ? hue : .red, status: tileStatus, size: tile)
          } else {
            ContFormTile(systemImage: systemImage, hue: error == nil ? hue : .red, size: tile)
          }
        }
        VStack(alignment: .leading, spacing: 1) {
          HStack(spacing: 6) {
            Text(title).kitFont(.body)
            if let titleAccessory {
              titleAccessory.kitFont(.caption).fixedSize()
            }
          }
          if let error {
            Text(error).kitFont(.caption).foregroundStyle(Hue.red.text)
              .transition(.opacity)
          } else if let help, showsHelp {
            Text(help).kitFont(.caption)
              .transition(.opacity)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        if isStacked {
          if let value {
            Text(value)
              .kitFont(.callout)
              .monospacedDigit()
              .foregroundStyle(.kitSecondary)
              .contentTransition(.numericText())
          }
        } else {
          control
            .controlSize(.small)
        }
      }
      .frame(minHeight: isStacked ? idiom.size(28, touch: 36) : idiom.size(40, touch: 48))
      if isStacked {
        control
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(EdgeInsets(top: 2, leading: lead, bottom: 6, trailing: 0))
      }
      if hasField {
        ContFilledField(
          isFocused: fieldFocused, isError: error != nil, status: status, systemImage: "checkmark", hue: hue
        ) {
          field
            .kitFont(.body)
            .focused($fieldFocused)
        }
        .padding(EdgeInsets(top: 2, leading: 0, bottom: 4, trailing: 0))
      }
      if let detailView {
        detailView
          .controlSize(.small)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(EdgeInsets(top: 0, leading: lead, bottom: 4, trailing: 0))
      }
    }
    .padding(EdgeInsets(horizontal: 12, vertical: 6))
    .overlay(alignment: .top) {
      Rectangle()
        .fill(.kitSeparator)
        .frame(height: 0.5)
        .padding(.leading, 12 + lead)
    }
    .opacity(isEnabled ? 1 : 0.5)
    .animation(.kit, value: error)
    .animation(.kit, value: showsHelp)
    .accessibilityElement(children: .contain)
  }
}

extension EnvironmentValues {
  @Entry var kitFormHelpWhileEditing: Bool = false
}

extension View {
  /// The form rows inside show a field's help only while that field is being edited, fading in under its title; an
  /// error still shows at all times, and rows without a field keep their help. For short forms whose fields explain
  /// themselves until someone starts typing.
  ///
  /// ```swift
  /// FormCard {
  ///   FormRow("Address", help: "mac.local or 192.168.1.5:1997", systemImage: "network",
  ///           field: TextField("Address", text: $address))
  /// }
  /// .kitFormHelpWhileEditing()
  /// ```
  public func kitFormHelpWhileEditing(_ enabled: Bool = true) -> some View {
    environment(\.kitFormHelpWhileEditing, enabled)
  }
}

extension FormRow where Field == EmptyView {
  /// A row with its control at the end (a switch, a pop-up, a button); `status` makes the tile the live icon
  /// carrying it.
  public init(
    _ title: String, help: String? = nil, systemImage: String, hue: Hue = .accent, error: String? = nil,
    status: WorkStatus = .idle, @ViewBuilder control: () -> Control
  ) {
    self.init(
      title: title, help: help, systemImage: systemImage, hue: hue, error: error, status: .idle, control: control,
      field: { EmptyView() })
    tileStatus = status
  }

  /// A stacked row: the title (and `value` at its end, the control's current value) over the control, which takes
  /// the row's width: a slider, a wide segmented control. Without `systemImage` the row has no tile.
  ///
  /// ```swift
  /// FormRow("Size", value: "\(Int(size)) pt") { KitSlider("Size", value: $size, in: 12...48, step: 1) }
  /// FormRow("Width", stacked: { KitSegmented(selection: $width, options: widths).kitSegmentedStyle(.wide) })
  /// ```
  @_disfavoredOverload
  public init(
    _ title: String, value: String? = nil, help: String? = nil, systemImage: String? = nil, hue: Hue = .accent,
    error: String? = nil, @ViewBuilder stacked control: () -> Control
  ) {
    self.init(
      title: title, help: help, systemImage: systemImage, hue: hue, error: error, status: .idle, control: control,
      field: { EmptyView() })
    self.value = value
    isStacked = true
  }
}

extension FormRow where Control == EmptyView, Field == EmptyView {
  /// A row that only reads: the label and its value or help ("Status · Synced 2 min ago"); `status` makes the tile
  /// the live icon carrying it.
  public init(
    _ title: String, help: String? = nil, systemImage: String, hue: Hue = .accent, error: String? = nil,
    status: WorkStatus = .idle
  ) {
    self.init(
      title: title, help: help, systemImage: systemImage, hue: hue, error: error, status: .idle,
      control: { EmptyView() }, field: { EmptyView() })
    tileStatus = status
  }
}

extension FormRow {
  /// A row with both a text field opening under it and a control at its end (an address and its Connect button);
  /// `status` puts the live icon at the field's end.
  public init(
    _ title: String, help: String? = nil, systemImage: String, hue: Hue = .accent, error: String? = nil,
    status: WorkStatus = .idle, field: Field, @ViewBuilder control: () -> Control
  ) {
    self.init(
      title: title, help: help, systemImage: systemImage, hue: hue, error: error, status: status,
      control: control, field: { field })
  }
}

extension FormRow where Control == EmptyView {
  /// A row whose text field opens under it as a full-width filled line; `status` puts the live icon at its end.
  public init(
    _ title: String, help: String? = nil, systemImage: String, hue: Hue = .accent, error: String? = nil,
    status: WorkStatus = .idle, field: Field
  ) {
    self.init(
      title: title, help: help, systemImage: systemImage, hue: hue, error: error, status: status,
      control: { EmptyView() }, field: { field })
  }
}

/// A form row's tile: the hue with a soft top light and a white glyph, like the sidebar's row tiles.
struct ContFormTile: View {
  let systemImage: String
  let hue: Hue
  let size: CGFloat

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
    Image(systemName: systemImage)
      .font(.system(size: size * 0.55, weight: .medium))
      .imageScale(.small)
      .foregroundStyle(Color.white)
      .frame(width: size, height: size)
      .background {
        shape.fill(hue.fill)
          .overlay { shape.fill(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom)) }
      }
      .animation(.kit, value: hue)
      .accessibilityHidden(true)
  }
}

#Preview("Forms") {
  @Previewable @State var url = "https://github.com/v57/Component.git"
  @Previewable @State var on = true
  VStack(spacing: 16) {
    FormCard {
      FormRow(
        "Repository URL", help: "GitHub, GitLab or any Git URL", systemImage: "link", status: .done,
        field: TextField("https://", text: $url))
      FormRow("Location", help: "~/Developer/Component", systemImage: "folder", hue: .teal) {
        Button("Choose…") {}.buttonStyle(.kit)
      }
    }
    FormCard("Devices", footer: "Shared by Git, Shell, Database, Markdown, Code and Dev.") {
      FormRow("Sync with iCloud", help: "Projects, hosts and notes", systemImage: "icloud") {
        Toggle("Sync", isOn: $on).labelsHidden()
      }
      FormRow("Status", help: "Synced 2 min ago", systemImage: "checkmark.circle", hue: .green)
      FormRow(
        "Repository URL", systemImage: "link", error: "Not a Git URL",
        field: TextField("https://", text: .constant("github.com/v57")))
    }
  }
  .padding(16)
  .frame(width: 460)
  .background(.kitPanel)
  .componentKit()
}
