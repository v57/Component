import SwiftUI

// MARK: - Prompt

/// The one field of a `kitPrompt`: its label, the placeholder, a help line, the symbol on its tile, and whether it
/// hides what is typed (a password).
///
/// ```swift
/// KitPromptField("Name", help: "Use “/” to create folders along the way.")
/// KitPromptField("Message", systemImage: "text.bubble")
/// KitPromptField.secure("Password", placeholder: "Mac password", help: "v57 on build-mac")
/// KitPromptField("Key", systemImage: "key", mono: true)                  // a Redis key, an id
/// KitPromptField("Email", systemImage: "at", content: .email)            // the keyboard and AutoFill for it
/// ```
public struct KitPromptField: Sendable {
  /// What the field holds, for the keyboard, AutoFill (iPhone and iPad) and capitalisation.
  public enum Content: Hashable, Sendable {
    case plain, username, password, newPassword, oneTimeCode, email, url
  }

  public var label: String
  public var placeholder: String?
  public var help: String?
  public var systemImage: String
  public var isSecure: Bool
  public var content: Content
  /// Monospaced text without autocorrection (keys, ids, paths).
  public var isMono: Bool

  public init(
    _ label: String = "Name", placeholder: String? = nil, help: String? = nil,
    systemImage: String = "character.cursor.ibeam", isSecure: Bool = false, content: Content = .plain,
    mono: Bool = false
  ) {
    self.label = label
    self.placeholder = placeholder
    self.help = help
    self.systemImage = systemImage
    self.isSecure = isSecure
    self.content = content
    self.isMono = mono
  }

  /// A field that hides what is typed: a password AutoFill can fill (`content: .newPassword` to suggest one).
  public static func secure(
    _ label: String = "Password", placeholder: String? = nil, help: String? = nil,
    systemImage: String = "ellipsis.rectangle", content: Content = .password
  ) -> KitPromptField {
    KitPromptField(
      label, placeholder: placeholder, help: help, systemImage: systemImage, isSecure: true, content: content)
  }
}

extension View {
  /// Asks for one line of text (a name, a commit message, a password) as a kit sheet: the still header (title and
  /// message), the field in a form card (it takes focus), and a footer with Cancel and the confirming button, which
  /// stays disabled while the field is empty. Return confirms, Escape cancels. `action` gets the text (trimmed, unless
  /// the field is secure); if it throws, the sheet stays open and shows the error in its footer, otherwise it closes.
  /// `text` is the app's: set it before presenting to start from a value (the old name).
  ///
  /// ```swift
  /// .kitPrompt("Rename", isPresented: $renaming, text: $newName, message: "“Notes.md”", confirm: "Rename") { name in
  ///   try actions.rename(to: name)
  /// }
  /// .kitPrompt("Commit and Push", isPresented: $committing, text: $message, message: summary,
  ///            systemImage: "arrow.up", hue: .purple, field: KitPromptField("Message", systemImage: "text.bubble"),
  ///            confirm: "Push") { push($0) }
  /// .kitPrompt("Login Keychain", isPresented: $asking, text: $password, message: host.name,
  ///            systemImage: "key", hue: .indigo, field: .secure(placeholder: "Mac password"),
  ///            footnote: "Code unlocks it with this password before each build.", confirm: "Save") { try save($0) }
  /// ```
  ///
  /// - Parameter footnote: a line under the field's card (what the value is used for).
  public func kitPrompt(
    _ title: String, isPresented: Binding<Bool>, text: Binding<String>, message: String? = nil,
    systemImage: String = "pencil", hue: Hue = .accent, field: KitPromptField = KitPromptField(),
    footnote: String? = nil, confirm: String, action: @escaping @MainActor (String) throws -> Void
  ) -> some View {
    kitSheet(isPresented: isPresented) {
      ContPrompt(
        title: title, message: message, systemImage: systemImage, hue: hue, field: field, footnote: footnote,
        confirm: confirm, text: text, action: action, dismiss: { isPresented.wrappedValue = false })
    }
  }
}

/// A prompt field's content: monospaced, and on iPhone and iPad its AutoFill type, keyboard and capitalisation.
private struct ContPromptContent: ViewModifier {
  let content: KitPromptField.Content
  let isMono: Bool

  func body(content field: Content) -> some View {
    let plain = content == .plain && !isMono
    let styled = field
      .modifier(ContPromptMono(isOn: isMono))
      .autocorrectionDisabled(!plain)
    #if os(iOS) || os(visionOS)
      return styled
        .textContentType(textContentType)
        .keyboardType(keyboard)
        .textInputAutocapitalization(plain ? nil : .never)
    #else
      return styled
    #endif
  }

  #if os(iOS) || os(visionOS)
    private var textContentType: UITextContentType? {
      switch content {
      case .plain: nil
      case .username: .username
      case .password: .password
      case .newPassword: .newPassword
      case .oneTimeCode: .oneTimeCode
      case .email: .emailAddress
      case .url: .URL
      }
    }

    private var keyboard: UIKeyboardType {
      switch content {
      case .email: .emailAddress
      case .url: .URL
      case .oneTimeCode: .numberPad
      default: isMono ? .asciiCapable : .default
      }
    }
  #endif
}

private struct ContPromptMono: ViewModifier {
  let isOn: Bool

  func body(content: Content) -> some View {
    if isOn { content.kitFont(.mono) } else { content }
  }
}

struct ContPrompt: View {
  let title: String
  let message: String?
  let systemImage: String
  let hue: Hue
  let field: KitPromptField
  let footnote: String?
  let confirm: String
  @Binding var text: String
  let action: @MainActor (String) throws -> Void
  let dismiss: @MainActor () -> Void
  @State private var error: String?
  @State private var didSubmit = false
  @FocusState private var focused: Bool

  private var value: String {
    field.isSecure ? text : text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    KitSheet(title: title, meta: message, systemImage: systemImage, hue: hue, width: 420) {
      FormCard(footer: footnote) {
        FormRow(field.label, help: field.help, systemImage: field.systemImage, hue: hue, field: input)
      }
    } footer: {
      if let error {
        SheetStatus(error, systemImage: "exclamationmark.triangle", hue: .red, status: .failed(error))
      }
      Button("Cancel") { dismiss() }
        .keyboardShortcut(.cancelAction)
      Button(confirm) { submit() }
        .buttonStyle(.kitPrimary)
        .keyboardShortcut(.defaultAction)
        .disabled(value.isEmpty)
    }
    .onChange(of: text) { error = nil }
    .onAppear {
      didSubmit = false
      Task { @MainActor in focused = true }
    }
  }

  @ViewBuilder private var input: some View {
    let placeholder = field.placeholder ?? field.label
    Group {
      if field.isSecure {
        SecureField(placeholder, text: $text)
      } else {
        TextField(placeholder, text: $text)
      }
    }
    .modifier(ContPromptContent(content: field.content, isMono: field.isMono))
    .focused($focused)
    .onSubmit { submit() }
  }

  /// Return in the field and the button both land here (on iOS a hardware Return can do both): once.
  private func submit() {
    guard !value.isEmpty, !didSubmit else { return }
    didSubmit = true
    do {
      try action(value)
      dismiss()
    } catch {
      didSubmit = false
      self.error = error.localizedDescription
    }
  }
}

#Preview("Prompt") {
  @Previewable @State var name = "Notes.md"
  ContPrompt(
    title: "Rename", message: "“Notes.md”", systemImage: "pencil", hue: .accent, field: KitPromptField(),
    footnote: nil, confirm: "Rename", text: $name, action: { _ in }, dismiss: {}
  )
  .padding()
  .componentKit()
}
