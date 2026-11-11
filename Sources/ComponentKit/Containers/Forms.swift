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
  var title: KitString?
  var footer: KitString?
  @ViewBuilder var content: Content
  @Environment(\.kitIdiom) private var idiom

  /// A card titled by keys (literals), looked up in the app's strings.
  public init(
    _ title: LocalizedStringKey? = nil, footer: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content
  ) {
    self.init(title: KitString(title), footer: KitString(footer), content: content)
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
    self.init(title: KitString(verbatim: title), footer: KitString(verbatim: footer), content: content)
  }

  init(title: KitString?, footer: KitString?, @ViewBuilder content: () -> Content) {
    self.title = title
    self.footer = footer
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let title {
        FormHeading(title: title)
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

/// A live preview of what a group of settings does, as a row of its `FormCard`: the card's width, at the head of the
/// settings it shows. For one setting's preview, `FormRow.preview` puts it under that row.
///
/// ```swift
/// FormCard("Editor") {
///   FormPreview { CodeSample(font: font, wraps: wraps) }
///   FormRow("Font", systemImage: "textformat") { … }
///   FormRow("Wrap Lines", systemImage: "text.alignleft") { Toggle("Wrap Lines", isOn: $wraps).labelsHidden() }
/// }
/// ```
public struct FormPreview<Content: View>: View {
  var height: CGFloat
  @ViewBuilder var content: Content

  public init(height: CGFloat = 72, @ViewBuilder content: () -> Content) {
    self.height = height
    self.content = content()
  }

  public var body: some View {
    ContFormPreviewScene(height: height, content: content)
      .padding(EdgeInsets(horizontal: 12, vertical: 10))
  }
}

/// The scene a setting's preview draws in: a well in the card, its content clipped to 8pt corners.
private struct ContFormPreviewScene<Content: View>: View {
  let height: CGFloat
  let content: Content

  var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .frame(height: height)
      .background(.kitField)
      .clipShape(RoundedRectangle(cornerRadius: KitMetrics.radius, style: .continuous))
      .allowsHitTesting(false)
      .accessibilityHidden(true)
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
  var title: KitString

  /// A heading whose title is a key (a literal), looked up in the app's strings.
  public init(_ title: LocalizedStringKey) { self.init(title: KitString(title)) }

  /// The same with a string shown as it is.
  @_disfavoredOverload
  public init(_ title: some StringProtocol) { self.init(title: KitString(verbatim: String(title))) }

  init(title: KitString) { self.title = title }

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
/// controls under the row, lined up with its title, `.tile { }` a view in the tile's place (a project's icon).
///
/// ```swift
/// FormRow("Primary", help: "Runs this chat's agents", systemImage: "laptopcomputer", status: sync) { … }
///   .titleAccessory { Chip("Demo", style: .quiet) }
///   .detail { Toggle("Only with a config file", isOn: $needsConfig).toggleStyle(.kitCheckbox) }
/// ```
public struct FormRow<Control: View, Field: View>: View {
  var title: KitString
  var help: KitString?
  var systemImage: String?
  var hue: Hue
  var error: KitString?
  var status: WorkStatus
  /// The tile's work (`status:` on a row without a field).
  var tileStatus: WorkStatus = .idle
  var value: KitString?
  var isStacked = false
  var titleAccessory: AnyView?
  var detailView: AnyView?
  var previewView: AnyView?
  var customTile: AnyView?
  @ViewBuilder var control: Control
  @ViewBuilder var field: Field
  @FocusState private var fieldFocused: Bool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitFormHelpWhileEditing) private var helpWhileEditing

  init(
    title: KitString, help: KitString?, systemImage: String?, hue: Hue, error: KitString?, status: WorkStatus,
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

  /// Draws `content` in the tile's place, at the tile's size: a project's icon, an avatar. The row still takes a
  /// `systemImage` (the tile without it).
  ///
  /// ```swift
  /// FormRow(project.name, help: path, systemImage: "folder") { Chip("Repository") }
  ///   .tile { Avatar(name: project.name, image: icon, kind: .thing, size: 24) }
  /// ```
  public func tile<V: View>(@ViewBuilder _ content: () -> V) -> Self {
    var row = self
    row.customTile = AnyView(content())
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

  /// Shows what the setting does, live, in a scene under the row, lined up with its title: the row's value drawn on
  /// sample content (a colour scheme on a few lines of a terminal, a font on a line of code). It takes no clicks, and
  /// says nothing to VoiceOver: the row's title and help do.
  ///
  /// ```swift
  /// FormRow("Color Scheme", systemImage: "paintpalette") { KitMenuButton(…) }
  ///   .preview { TerminalSample(scheme: scheme, usesBackgroundColors: usesBackground) }
  /// ```
  public func preview<V: View>(height: CGFloat = 72, @ViewBuilder _ content: () -> V) -> Self {
    var row = self
    row.previewView = AnyView(ContFormPreviewScene(height: height, content: content()))
    return row
  }

  public var body: some View {
    let tile: CGFloat = idiom.size(24, touch: 30)
    let lead: CGFloat = systemImage == nil ? 0 : tile + 12
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        if let customTile, systemImage != nil {
          customTile.frame(width: tile, height: tile)
        } else if let systemImage {
          if tileStatus != .idle {
            LiveIcon(systemImage: systemImage, hue: error == nil ? hue : .red, status: tileStatus, size: tile)
          } else {
            ContFormTile(systemImage: systemImage, hue: error == nil ? hue : .red, size: tile)
          }
        }
        // The title beside the control, or over it when the control would squeeze the title (a colour picker, a
        // segmented control on iPhone left "C/o/l/o/u/r" one letter a line).
        ContFormLine {
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
      }
      .frame(minHeight: isStacked ? idiom.size(28, touch: 36) : idiom.size(40, touch: 48))
      .modifier(ContFocusesOnTap(isOn: hasField, focus: $fieldFocused))
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
            // Found by the row's title (VoiceOver, UI tests), not only by its placeholder.
            .accessibilityLabel(Text(title))
        }
        // The whole filled line takes the tap, not only the text in it: a tap in its padding left the focus in the
        // field before, and typing went there (S-007).
        .modifier(ContFocusesOnTap(isOn: true, focus: $fieldFocused))
        .padding(EdgeInsets(top: 2, leading: 0, bottom: 4, trailing: 0))
      }
      if let detailView {
        detailView
          .controlSize(.small)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(EdgeInsets(top: 0, leading: lead, bottom: 4, trailing: 0))
      }
      if let previewView {
        previewView
          .padding(EdgeInsets(top: 2, leading: lead, bottom: 6, trailing: 0))
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

/// A form row's title line and filled field focus the row's field when tapped: on iPad and iPhone a tap on the title,
/// the tile or the field's padding left the focus in the field before, so typing went into it (S-007). Rows without a
/// field are left alone (a row inside a button keeps its tap).
struct ContFocusesOnTap: ViewModifier {
  var isOn: Bool
  var focus: FocusState<Bool>.Binding

  func body(content: Content) -> some View {
    if isOn {
      content
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = true }
    } else {
      content
    }
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
  /// carrying it. Its texts are keys (literals), looked up in the app's strings.
  public init(
    _ title: LocalizedStringKey, help: LocalizedStringKey? = nil, systemImage: String, hue: Hue = .accent,
    error: LocalizedStringKey? = nil, status: WorkStatus = .idle, @ViewBuilder control: () -> Control
  ) {
    self.init(
      title: KitString(title), help: KitString(help), systemImage: systemImage, hue: hue, error: KitString(error),
      status: .idle, control: control, field: { EmptyView() })
    tileStatus = status
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(
    _ title: some StringProtocol, help: String? = nil, systemImage: String, hue: Hue = .accent, error: String? = nil,
    status: WorkStatus = .idle, @ViewBuilder control: () -> Control
  ) {
    self.init(
      title: KitString(verbatim: String(title)), help: KitString(verbatim: help), systemImage: systemImage, hue: hue,
      error: KitString(verbatim: error), status: .idle, control: control, field: { EmptyView() })
    tileStatus = status
  }

  /// A stacked row: the title (and `value` at its end, the control's current value) over the control, which takes
  /// the row's width: a slider, a wide segmented control. Without `systemImage` the row has no tile.
  ///
  /// ```swift
  /// FormRow("Size", value: "\(Int(size)) pt") { KitSlider("Size", value: $size, in: 12...48, step: 1) }
  /// FormRow("Width", stacked: { KitSegmented(selection: $width, options: widths).kitSegmentedStyle(.wide) })
  /// ```
  ///
  /// Its texts are keys (literals), looked up in the app's strings.
  public init(
    _ title: LocalizedStringKey, value: LocalizedStringKey? = nil, help: LocalizedStringKey? = nil,
    systemImage: String? = nil, hue: Hue = .accent, error: LocalizedStringKey? = nil,
    @ViewBuilder stacked control: () -> Control
  ) {
    self.init(
      title: KitString(title), value: KitString(value), help: KitString(help), systemImage: systemImage, hue: hue,
      error: KitString(error), stacked: control)
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(
    _ title: some StringProtocol, value: String? = nil, help: String? = nil, systemImage: String? = nil,
    hue: Hue = .accent, error: String? = nil, @ViewBuilder stacked control: () -> Control
  ) {
    self.init(
      title: KitString(verbatim: String(title)), value: KitString(verbatim: value), help: KitString(verbatim: help),
      systemImage: systemImage, hue: hue, error: KitString(verbatim: error), stacked: control)
  }

  init(
    title: KitString, value: KitString?, help: KitString?, systemImage: String?, hue: Hue, error: KitString?,
    @ViewBuilder stacked control: () -> Control
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
  /// the live icon carrying it. Its texts are keys (literals), looked up in the app's strings.
  public init(
    _ title: LocalizedStringKey, help: LocalizedStringKey? = nil, systemImage: String, hue: Hue = .accent,
    error: LocalizedStringKey? = nil, status: WorkStatus = .idle
  ) {
    self.init(
      title: KitString(title), help: KitString(help), systemImage: systemImage, hue: hue, error: KitString(error),
      status: .idle, control: { EmptyView() }, field: { EmptyView() })
    tileStatus = status
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(
    _ title: some StringProtocol, help: String? = nil, systemImage: String, hue: Hue = .accent, error: String? = nil,
    status: WorkStatus = .idle
  ) {
    self.init(
      title: KitString(verbatim: String(title)), help: KitString(verbatim: help), systemImage: systemImage, hue: hue,
      error: KitString(verbatim: error), status: .idle, control: { EmptyView() }, field: { EmptyView() })
    tileStatus = status
  }
}

extension FormRow {
  /// A row with both a text field opening under it and a control at its end (an address and its Connect button);
  /// `status` puts the live icon at the field's end. Its texts are keys (literals), looked up in the app's strings.
  public init(
    _ title: LocalizedStringKey, help: LocalizedStringKey? = nil, systemImage: String, hue: Hue = .accent,
    error: LocalizedStringKey? = nil, status: WorkStatus = .idle, field: Field, @ViewBuilder control: () -> Control
  ) {
    self.init(
      title: KitString(title), help: KitString(help), systemImage: systemImage, hue: hue, error: KitString(error),
      status: status, control: control, field: { field })
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(
    _ title: some StringProtocol, help: String? = nil, systemImage: String, hue: Hue = .accent, error: String? = nil,
    status: WorkStatus = .idle, field: Field, @ViewBuilder control: () -> Control
  ) {
    self.init(
      title: KitString(verbatim: String(title)), help: KitString(verbatim: help), systemImage: systemImage, hue: hue,
      error: KitString(verbatim: error), status: status, control: control, field: { field })
  }
}

extension FormRow where Control == EmptyView {
  /// A row whose text field opens under it as a full-width filled line; `status` puts the live icon at its end. Its
  /// texts are keys (literals), looked up in the app's strings.
  public init(
    _ title: LocalizedStringKey, help: LocalizedStringKey? = nil, systemImage: String, hue: Hue = .accent,
    error: LocalizedStringKey? = nil, status: WorkStatus = .idle, field: Field
  ) {
    self.init(
      title: KitString(title), help: KitString(help), systemImage: systemImage, hue: hue, error: KitString(error),
      status: status, control: { EmptyView() }, field: { field })
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(
    _ title: some StringProtocol, help: String? = nil, systemImage: String, hue: Hue = .accent, error: String? = nil,
    status: WorkStatus = .idle, field: Field
  ) {
    self.init(
      title: KitString(verbatim: String(title)), help: KitString(verbatim: help), systemImage: systemImage, hue: hue,
      error: KitString(verbatim: error), status: status, control: { EmptyView() }, field: { field })
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

/// A form row's line: the title column and the control beside it at the control's own width, the title taking the
/// rest; when that would leave the title under `minimumTitle`, the control goes under the title, as wide as it wants
/// up to the row's width.
struct ContFormLine: Layout {
  var spacing: CGFloat = 12
  var minimumTitle: CGFloat = 120

  /// Whether a control this wide leaves the title `minimumTitle` beside it in a line `width` wide.
  func fitsBeside(control: CGFloat, in width: CGFloat) -> Bool {
    control <= width - spacing - minimumTitle
  }

  private struct Plan {
    var title: CGSize
    var control: CGSize
    var isBeside: Bool
  }

  private func plan(_ width: CGFloat?, _ subviews: Subviews) -> Plan {
    guard subviews.count > 1 else {
      let title = subviews.first?.sizeThatFits(ProposedViewSize(width: width, height: nil)) ?? .zero
      return Plan(title: title, control: .zero, isBeside: true)
    }
    let control = subviews[1].sizeThatFits(.unspecified)
    guard let width else {
      return Plan(title: subviews[0].sizeThatFits(.unspecified), control: control, isBeside: true)
    }
    if fitsBeside(control: control.width, in: width) {
      let title = subviews[0].sizeThatFits(ProposedViewSize(width: width - spacing - control.width, height: nil))
      return Plan(title: title, control: control, isBeside: true)
    }
    let title = subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil))
    let under = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil))
    return Plan(title: title, control: CGSize(width: min(under.width, width), height: under.height), isBeside: false)
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let plan = plan(proposal.width, subviews)
    if plan.isBeside {
      let gap = subviews.count > 1 ? spacing : 0
      return CGSize(
        width: proposal.width ?? plan.title.width + gap + plan.control.width,
        height: max(plan.title.height, plan.control.height))
    }
    return CGSize(width: proposal.width ?? plan.title.width, height: plan.title.height + 6 + plan.control.height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let plan = plan(bounds.width, subviews)
    if plan.isBeside {
      let gap = subviews.count > 1 ? spacing : 0
      subviews.first?.place(
        at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
        proposal: ProposedViewSize(width: bounds.width - gap - plan.control.width, height: plan.title.height))
      if subviews.count > 1 {
        subviews[1].place(
          at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
          proposal: ProposedViewSize(plan.control))
      }
    } else {
      subviews[0].place(
        at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
        proposal: ProposedViewSize(width: bounds.width, height: plan.title.height))
      subviews[1].place(
        at: CGPoint(x: bounds.minX, y: bounds.minY + plan.title.height + 6), anchor: .topLeading,
        proposal: ProposedViewSize(plan.control))
    }
  }
}
