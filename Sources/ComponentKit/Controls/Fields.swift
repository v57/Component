import SwiftUI

/// What a text field says about its value: nothing, wrong (a red ring), or a piece of work shown by a live icon at
/// the field's end (the work indicator while checking, a green check when it's good, red when it failed).
///
/// ```swift
/// TextField("https://", text: $url).kitField(status: isChecking ? .checking : isValid ? .valid : .none)
/// ```
public enum FieldStatus: Hashable, Sendable {
  case none
  /// The value is wrong: the 2pt ring in red at half strength. Say why with `.kitFieldError(_:)`.
  case error
  /// A live icon at the end carries work on the value; a failed one also rings the field red.
  case live(WorkStatus, systemImage: String = "ellipsis")

  /// Checking the value: the live icon's work indicator.
  public static let checking = FieldStatus.live(.working)
  /// The value checked out: a green check.
  public static let valid = FieldStatus.live(.done)

  var isError: Bool {
    switch self {
    case .error: true
    case .live(.failed, _): true
    default: false
    }
  }
}

extension View {
  /// Puts a `TextField` on the kit: a filled, borderless field (the field well) that takes the 2pt ring at half the
  /// accent while focused, red when `status` is wrong, and an optional live icon at its end, inset as much from the
  /// right as from the top and bottom. `mono` sets values, URLs, ids and paths in the monospaced face.
  ///
  /// ```swift
  /// TextField("https://", text: $url).kitField(status: .valid, mono: true)
  /// TextField("Branch", text: $name).kitField(status: .error).kitFieldError("A branch with this name exists")
  /// ```
  ///
  /// `content` says what the field holds, for the keyboard on iPhone and iPad: a user name, an address or a key typed as
  /// prose would get a capital first letter, autocorrection ("wss://" → "Was://") and suggestions learnt from it. A
  /// `mono` field is `.verbatim` unless `content` says more.
  ///
  /// ```swift
  /// TextField("deploy", text: $user).kitField(content: .verbatim)
  /// TextField("https://", text: $url).kitField(mono: true, content: .url)
  /// SecureField("Secret access key", text: $secret).kitField(mono: true, content: .secret)
  /// ```
  public func kitField(status: FieldStatus = .none, mono: Bool = false, content: KitFieldContent = .text) -> some View {
    modifier(CtlFieldModifier(status: status, mono: mono, content: content, trailing: EmptyView()))
  }

  /// A kit field with its own view at the end (a clear button, a unit, a menu), before the status's live icon.
  ///
  /// ```swift
  /// TextField("Port", text: $port).kitField(content: .number) { Text("TCP").kitFont(.caption) }
  /// ```
  public func kitField<Trailing: View>(
    status: FieldStatus = .none, mono: Bool = false, content: KitFieldContent = .text,
    @ViewBuilder trailing: () -> Trailing
  ) -> some View {
    modifier(CtlFieldModifier(status: status, mono: mono, content: content, trailing: trailing()))
  }

  /// Says what is wrong with a field in red text under it; `nil` shows nothing. Pair it with `status: .error`. The
  /// message is a key (a literal), looked up in the app's strings.
  ///
  /// ```swift
  /// TextField("Repository URL", text: $url)
  ///   .kitField(status: urlError == nil ? .none : .error)
  ///   .kitFieldError(urlError)
  /// ```
  public func kitFieldError(_ message: LocalizedStringKey?) -> some View {
    kitFieldError(message: KitString(message))
  }

  /// The same with a message shown as it is (one the app put together or localized).
  @_disfavoredOverload
  public func kitFieldError(_ message: String?) -> some View {
    kitFieldError(message: KitString(verbatim: message))
  }

  func kitFieldError(message: KitString?) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      self
      if let message {
        Text(message)
          .foregroundStyle(Hue.red.text)
          .kitFont(.caption)
          .padding(.horizontal, 12)
          .transition(.opacity)
      }
    }
    .animation(.kitFast, value: message)
  }
}

/// A field for text with paragraphs: Return starts a new line, and the field grows with the text between `lines`, then
/// scrolls. Use it for a description, release notes, a script; a value that only wraps (a public key) or a one-line
/// message that submits stays a `TextField(axis: .vertical)`.
///
/// It exists for the Mac, where Return in a vertical `TextField` ends editing and selects the whole text, so the next
/// key replaces it. A `.defaultAction` button also fires on Return while this field has the focus, so the button of a
/// sheet with one takes Command-Return: `.keyboardShortcut(.return, modifiers: .command)`.
///
/// `prompt` is also its accessibility label, unless it has its own. Put it on the kit with `.kitField()` or a `FormRow`'s
/// `field:`. On Apple TV, which has no text views, it is a plain `TextField`. It is for prose: the Mac's smart quotes and
/// dashes stay on, even with `.autocorrectionDisabled()`, so code and commands go in a `KitLineEditor`. Its binding reads
/// the current value (`@State`, a store), not a copy the body took: the text view reads it back between keys, and a stale
/// value drops them.
///
/// ```swift
/// KitMultilineField("What changed", text: $notes, lines: 6...14).kitField()
/// FormRow("Description", systemImage: "text.alignleft", field: KitMultilineField("Description", text: $details))
/// ```
public struct KitMultilineField: View {
  let prompt: KitString
  @Binding var text: String
  let lines: ClosedRange<Int>

  /// A field prompted by a key (a literal), looked up in the app's strings.
  public init(_ prompt: LocalizedStringKey, text: Binding<String>, lines: ClosedRange<Int> = 3...14) {
    self.init(prompt: KitString(prompt), text: text, lines: lines)
  }

  /// The same with a prompt shown as it is.
  @_disfavoredOverload
  public init(_ prompt: some StringProtocol, text: Binding<String>, lines: ClosedRange<Int> = 3...14) {
    self.init(prompt: KitString(verbatim: String(prompt)), text: text, lines: lines)
  }

  init(prompt: KitString, text: Binding<String>, lines: ClosedRange<Int>) {
    self.prompt = prompt
    self._text = text
    self.lines = lines
  }

  public var body: some View {
    #if os(tvOS)
      TextField(prompt, text: $text, prompt: nil)
    #else
      // The text view takes the height of this hidden text; the space keeps a last empty line's height.
      Text(text + " ")
        .lineLimit(lines)
        .opacity(0)
        .accessibilityHidden(true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
          TextEditor(text: $text)
            .scrollContentBackground(.hidden)
            .accessibilityLabel(prompt)
            // The text view's own margins, so the text sits where the sizing text and the prompt do.
            #if os(iOS) || os(visionOS)
              .padding(EdgeInsets(top: -8, leading: -5, bottom: -8, trailing: -5))
            #elseif os(macOS)
              .padding(.horizontal, -5)
            #endif
        }
        .overlay(alignment: .topLeading) {
          if text.isEmpty {
            Text(prompt)
              .foregroundStyle(.kitTertiary)
              .allowsHitTesting(false)
              .accessibilityHidden(true)
          }
        }
    #endif
  }
}

/// What a kit field holds, for the keyboard, autocorrection, capitals and AutoFill on iPhone and iPad (the Mac only
/// turns autocorrection off where it says so).
public enum KitFieldContent: Hashable, Sendable {
  /// Prose: a title, a name, a sentence. The keyboard capitalises and corrects.
  case text
  /// Typed exactly: a user name, a host, a path, an id, a command. No capitals, corrections or suggestions.
  case verbatim
  /// A URL or an address with a scheme: verbatim, on the URL keyboard.
  case url
  /// An email address: verbatim, on the email keyboard.
  case email
  /// Digits and the odd separator (a port, an expiry "MM/YY", a card number): verbatim, on the numbers keyboard.
  case number
  /// A value the app keeps secret that isn't the user's password for a site (an access key's secret, a card's code):
  /// verbatim, and iOS neither offers a strong password nor asks to save it in Passwords.
  case secret
  /// A secret made of digits (a card number, a security code): `secret` on the numbers keyboard.
  case secretNumber

  /// What a field with this content and `mono` does: a `mono` field is verbatim unless it says more.
  func resolved(mono: Bool) -> KitFieldContent {
    self == .text && mono ? .verbatim : self
  }

  /// Whether the keyboard corrects, capitalises and suggests words.
  var isProse: Bool { self == .text }

  /// Whether iOS should keep away from it with passwords (the strong-password offer, Save Password).
  var isSecret: Bool { self == .secret || self == .secretNumber }
}

extension View {
  /// The keyboard side of `KitFieldContent` for a text view that isn't a `kitField`: a `TextEditor`, a
  /// `KitMultilineField`, a `FormRow`'s field. `kitField(content:)` sets it itself.
  ///
  /// ```swift
  /// TextEditor(text: $words).kitTextContent(.verbatim)
  /// FormRow("Team ID", systemImage: "person.2", field: TextField("ABCDE12345", text: $teamID).kitTextContent(.verbatim))
  /// ```
  public func kitTextContent(_ content: KitFieldContent) -> some View {
    modifier(CtlFieldContent(content: content))
  }
}

/// The keyboard side of `KitFieldContent`.
struct CtlFieldContent: ViewModifier {
  let content: KitFieldContent

  func body(content field: Content) -> some View {
    let styled = field.autocorrectionDisabled(!content.isProse)
    #if os(iOS) || os(visionOS)
      return styled
        .textInputAutocapitalization(content.isProse ? nil : .never)
        .keyboardType(keyboard)
        .textContentType(textContentType)
    #else
      return styled
    #endif
  }

  #if os(iOS) || os(visionOS)
    private var keyboard: UIKeyboardType {
      switch content {
      case .text: .default
      case .verbatim, .secret: .asciiCapable
      case .url: .URL
      case .email: .emailAddress
      case .number, .secretNumber: .numbersAndPunctuation
      }
    }

    /// A secret gets the one-time-code type: with none, iOS takes a secure field for a password, offers a strong one
    /// and asks to save what was typed in Passwords.
    private var textContentType: UITextContentType? {
      switch content {
      case .url: .URL
      case .email: .emailAddress
      case .secret, .secretNumber: .oneTimeCode
      default: nil
      }
    }
  #endif
}

struct CtlFieldModifier<Trailing: View>: ViewModifier {
  let status: FieldStatus
  let mono: Bool
  var content: KitFieldContent = .text
  let trailing: Trailing
  @FocusState private var isFocused: Bool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled

  func body(content: Content) -> some View {
    let height = CtlFieldMetrics.height(idiom)
    let icon = CtlFieldMetrics.icon(idiom)
    let radius: CGFloat = idiom.size(9, touch: 11)
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    HStack(spacing: 8) {
      content
        .textFieldStyle(.plain)
        .modifier(CtlFieldContent(content: self.content.resolved(mono: mono)))
        .kitFont(mono ? .mono : .body)
        .foregroundStyle(.kitLabel)
        .focused($isFocused)
        .frame(maxWidth: .infinity, alignment: .leading)
      trailing
      if case .live(let work, let systemImage) = status, work != .idle {
        LiveIcon(systemImage: systemImage, status: work, size: icon)
          .transition(.opacity.combined(with: .scale(scale: 0.8)))
      }
    }
    .padding(
      EdgeInsets(
        top: 6,
        leading: idiom.size(10, touch: 12),
        bottom: 6,
        trailing: hasIcon ? (height - icon) / 2 : idiom.size(10, touch: 12)))
    .frame(minHeight: height)
    .background {
      shape.fill(isFocused ? AnyShapeStyle(KitColor.control) : AnyShapeStyle(.kitField))
    }
    .ctlFieldRing(isFocused || status.isError, hue: status.isError ? .red : .accent, cornerRadius: radius)
    .contentShape(shape)
    .onTapGesture { isFocused = true }
    .opacity(isEnabled ? 1 : 0.45)
    .animation(.kit, value: status)
  }

  private var hasIcon: Bool {
    if case .live(let work, _) = status { return work != .idle }
    return false
  }
}

enum CtlFieldMetrics {
  static func height(_ idiom: KitIdiom) -> CGFloat {
    switch idiom {
    case .mac: 32
    case .pad: 40
    case .phone: 44
    case .tv: 64
    }
  }

  static func icon(_ idiom: KitIdiom) -> CGFloat {
    switch idiom {
    case .mac: 18
    case .pad: 22
    case .phone: 26
    case .tv: 36
    }
  }
}

#Preview("Fields") {
  @Previewable @State var empty = ""
  @Previewable @State var url = "https://github.com/v57/Component.git"
  @Previewable @State var wrong = "github.com/v57"
  VStack(alignment: .leading, spacing: 12) {
    TextField("https://", text: $empty).kitField()
    TextField("Repository URL", text: $url).kitField(status: .valid, mono: true)
    TextField("Repository URL", text: $url).kitField(status: .checking)
    TextField("Host", text: $wrong).kitField(status: .error).kitFieldError("Not a Git URL")
    TextField("Location", text: $empty).kitField().disabled(true)
    KitMultilineField("What changed", text: $empty).kitField()
  }
  .padding(20)
  .frame(width: 320)
  .componentKit()
}
