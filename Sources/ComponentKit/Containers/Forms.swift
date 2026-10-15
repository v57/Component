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
        Text(title)
          .kitFont(.headline)
          .padding(.horizontal, 12)
          .accessibilityAddTraits(.isHeader)
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

/// A rich form row: an icon tile, the label with a line of help (or the current value) under it, and the control at
/// the end. With `error` the tile and the line turn red and the error replaces the help. A row made with `field:` opens
/// its text field (`field:`) as a full-width filled line under it, with a trailing live icon for `status` (checking a URL).
///
/// ```swift
/// FormRow("Open when done", help: "In its default app", systemImage: "arrow.up.forward.app", hue: .indigo) {
///   Toggle("Open when done", isOn: $open).labelsHidden()
/// }
/// FormRow("Repository URL", help: "GitHub, GitLab or any Git URL", systemImage: "link", error: urlError,
///         status: checking, field: TextField("https://", text: $url))
/// ```
public struct FormRow<Control: View, Field: View>: View {
  var title: String
  var help: String?
  var systemImage: String
  var hue: Hue
  var error: String?
  var status: WorkStatus
  @ViewBuilder var control: Control
  @ViewBuilder var field: Field
  @FocusState private var fieldFocused: Bool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled

  init(
    title: String, help: String?, systemImage: String, hue: Hue, error: String?, status: WorkStatus,
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

  public var body: some View {
    let tile: CGFloat = idiom.isTouch ? 30 : 24
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        ContFormTile(systemImage: systemImage, hue: error == nil ? hue : .red, size: tile)
        VStack(alignment: .leading, spacing: 1) {
          Text(title).kitFont(.body)
          if let error {
            Text(error).kitFont(.caption).foregroundStyle(Hue.red.text)
              .transition(.opacity)
          } else if let help {
            Text(help).kitFont(.caption)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        control
          .controlSize(.small)
      }
      .frame(minHeight: idiom.isTouch ? 48 : 40)
      if hasField {
        ContFilledField(
          isFocused: fieldFocused, isError: error != nil, status: status, systemImage: "checkmark", hue: hue
        ) {
          field
            .kitFont(.body)
            .focused($fieldFocused)
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(.kitSeparator)
        .frame(height: 0.5)
        .padding(.leading, 12 + tile + 12)
    }
    .opacity(isEnabled ? 1 : 0.5)
    .animation(.kit, value: error)
    .accessibilityElement(children: .contain)
  }
}

extension FormRow where Field == EmptyView {
  /// A row with its control at the end (a switch, a pop-up, a button).
  public init(
    _ title: String, help: String? = nil, systemImage: String, hue: Hue = .accent, error: String? = nil,
    @ViewBuilder control: () -> Control
  ) {
    self.init(
      title: title, help: help, systemImage: systemImage, hue: hue, error: error, status: .idle, control: control,
      field: { EmptyView() })
  }
}

extension FormRow where Control == EmptyView, Field == EmptyView {
  /// A row that only reads: the label and its value or help ("Status · Synced 2 min ago").
  public init(_ title: String, help: String? = nil, systemImage: String, hue: Hue = .accent, error: String? = nil) {
    self.init(
      title: title, help: help, systemImage: systemImage, hue: hue, error: error, status: .idle,
      control: { EmptyView() }, field: { EmptyView() })
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
