import SwiftUI

/// What a text field says about its value: nothing, wrong (a red ring), or a piece of work shown by a live icon at
/// the field's end (an arc while checking, a green check when it's good, red when it failed).
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

  /// Checking the value: the live icon's turning arc.
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
  public func kitField(status: FieldStatus = .none, mono: Bool = false) -> some View {
    modifier(CtlFieldModifier(status: status, mono: mono, trailing: EmptyView()))
  }

  /// A kit field with its own view at the end (a clear button, a unit, a menu), before the status's live icon.
  ///
  /// ```swift
  /// TextField("Port", text: $port).kitField { Text("TCP").kitFont(.caption) }
  /// ```
  public func kitField<Trailing: View>(
    status: FieldStatus = .none, mono: Bool = false, @ViewBuilder trailing: () -> Trailing
  ) -> some View {
    modifier(CtlFieldModifier(status: status, mono: mono, trailing: trailing()))
  }

  /// Says what is wrong with a field in red text under it; `nil` shows nothing. Pair it with `status: .error`.
  ///
  /// ```swift
  /// TextField("Repository URL", text: $url)
  ///   .kitField(status: urlError == nil ? .none : .error)
  ///   .kitFieldError(urlError)
  /// ```
  public func kitFieldError(_ message: String?) -> some View {
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

struct CtlFieldModifier<Trailing: View>: ViewModifier {
  let status: FieldStatus
  let mono: Bool
  let trailing: Trailing
  @FocusState private var isFocused: Bool
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled

  func body(content: Content) -> some View {
    let height = CtlFieldMetrics.height(idiom)
    let icon = CtlFieldMetrics.icon(idiom)
    let radius: CGFloat = idiom.isTouch ? 11 : 9
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    HStack(spacing: 8) {
      content
        .textFieldStyle(.plain)
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
    .padding(.leading, idiom.isTouch ? 12 : 10)
    .padding(.trailing, hasIcon ? (height - icon) / 2 : idiom.isTouch ? 12 : 10)
    .padding(.vertical, 6)
    .frame(minHeight: height)
    .background {
      shape.fill(isFocused ? AnyShapeStyle(KitColor.control) : AnyShapeStyle(.kitField))
    }
    .ctlFieldRing(isFocused || status.isError, hue: status.isError ? .red : .accent, cornerRadius: radius)
    .contentShape(shape)
    .onTapGesture { isFocused = true }
    .opacity(isEnabled ? 1 : 0.45)
    .animation(.kitFast, value: isFocused)
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
    }
  }

  static func icon(_ idiom: KitIdiom) -> CGFloat {
    switch idiom {
    case .mac: 18
    case .pad: 22
    case .phone: 26
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
  }
  .padding(20)
  .frame(width: 320)
  .componentKit()
}
