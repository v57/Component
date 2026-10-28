import SwiftUI

// MARK: - Secret value

/// A secret in a row (a password, a key, a token): dots until revealed, with Show and Copy beside it. The dots are
/// always the same number, so they don't tell the secret's length. The value is read only when it is shown or
/// copied, so a keychain item stays unread until the person asks; Copy puts it on the pasteboard as a secret
/// (`KitPasteboard.copySecret`: this device only, cleared after 90 s).
///
/// ```swift
/// FormRow("Password") { KitSecretValue { VaultSecrets.password(for: login.id) } }
/// KitSecretValue("hunter2", label: "Token")
/// KitSecretValue(isRevealed: $showsPassword) { password }
/// ```
public struct KitSecretValue: View {
  var label: String
  var value: () -> String?
  var isRevealedBinding: Binding<Bool>?
  var allowsCopy: Bool
  @State private var ownRevealed = false
  @State private var revealed: String?
  @State private var copies = 0
  @Environment(\.kitIdiom) private var idiom

  /// How many dots stand for any secret.
  nonisolated static let maskLength = 16

  /// A secret read on demand (from the keychain).
  ///
  /// - Parameters:
  ///   - label: what the secret is, for VoiceOver and the buttons' help ("Show Password").
  ///   - isRevealed: shows or hides it from outside (a ⌥ shortcut); without it the view keeps its own.
  ///   - copies: whether Copy is offered.
  public init(
    label: String = "Password", isRevealed: Binding<Bool>? = nil, copies: Bool = true,
    value: @escaping () -> String?
  ) {
    self.label = label
    self.value = value
    self.isRevealedBinding = isRevealed
    self.allowsCopy = copies
  }

  /// A secret the view already has.
  public init(_ value: String, label: String = "Password", isRevealed: Binding<Bool>? = nil, copies: Bool = true) {
    self.init(label: label, isRevealed: isRevealed, copies: copies) { value }
  }

  private var isRevealed: Binding<Bool> { isRevealedBinding ?? $ownRevealed }

  /// The dots shown in place of any secret.
  nonisolated static var mask: String { String(repeating: "•", count: maskLength) }
  /// The dots where a row has no room for sixteen.
  nonisolated static var shortMask: String { String(repeating: "•", count: 8) }

  public var body: some View {
    HStack(spacing: 6) {
      Group {
        if isRevealed.wrappedValue, let revealed {
          Text(revealed)
            .tracking(0)
            .textSelection(.enabled)
            .lineLimit(1)
            .truncationMode(.middle)
            .accessibilityLabel(revealed)
        } else {
          // Fewer dots where the row is narrow: the count never said anything about the secret.
          ViewThatFits(in: .horizontal) {
            Text(Self.mask).tracking(1).lineLimit(1).fixedSize()
            Text(Self.shortMask).tracking(1).lineLimit(1).fixedSize()
          }
          .accessibilityElement()
          .accessibilityLabel("\(label), hidden")
        }
      }
      .font(.system(size: idiom.size(13, touch: 15), design: .monospaced))
      .foregroundStyle(.kitLabel)
      Button(
        isRevealed.wrappedValue ? "Hide \(label)" : "Show \(label)",
        systemImage: isRevealed.wrappedValue ? "eye.slash" : "eye"
      ) {
        withKitAnimation { isRevealed.wrappedValue.toggle() }
      }
      .buttonStyle(.kitIcon)
      .help(isRevealed.wrappedValue ? "Hide \(label)" : "Show \(label)")
      if allowsCopy {
        Button("Copy \(label)", systemImage: "doc.on.doc") {
          guard let secret = revealed ?? value() else { return }
          KitPasteboard.copySecret(secret)
          copies += 1
        }
        .buttonStyle(.kitIcon)
        .help("Copy \(label)")
        .effect(.success, on: copies, cornerRadius: 6)
      }
    }
    .onChange(of: isRevealed.wrappedValue, initial: true) { _, shown in
      // Read only when shown, and drop the plain value when hidden again.
      revealed = shown ? value() : nil
    }
  }
}

// MARK: - One-time code

/// A one-time code (TOTP) with its countdown: the seconds left, a live icon whose ring empties as the code runs
/// out (orange in its last five seconds), the code in two groups, and Copy. The view ticks every second and asks
/// for the code of the current moment, so the app only says how to make it.
///
/// ```swift
/// KitOneTimeCode(period: 30) { date in totp.code(at: date) }
/// ```
public struct KitOneTimeCode: View {
  var period: TimeInterval
  var showsSeconds: Bool
  var code: (Date) -> String?
  @State private var copies = 0
  @Environment(\.kitIdiom) private var idiom

  /// - Parameters:
  ///   - period: how long each code lasts (30 s for most sites).
  ///   - showsSeconds: whether "19 s" leads the row (rows hide it where they're narrow).
  ///   - code: the code at a moment, `nil` while it can't be made (the secret hasn't arrived).
  public init(period: TimeInterval = 30, showsSeconds: Bool = true, code: @escaping (Date) -> String?) {
    self.period = period
    self.showsSeconds = showsSeconds
    self.code = code
  }

  /// Seconds left in the code's period at `date`: `period` at the start of a period, nearly 0 at its end.
  nonisolated static func remaining(at date: Date, period: TimeInterval) -> TimeInterval {
    guard period > 0 else { return 0 }
    let elapsed = date.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
    return period - elapsed
  }

  /// The code in two groups ("482 913", "1234 5678"); other lengths stay as they are.
  nonisolated static func grouped(_ code: String) -> String {
    guard code.count >= 6, code.count.isMultiple(of: 2) else { return code }
    let half = code.index(code.startIndex, offsetBy: code.count / 2)
    return "\(code[..<half]) \(code[half...])"
  }

  public var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let left = Self.remaining(at: context.date, period: period)
      let current = code(context.date)
      ViewThatFits(in: .horizontal) {
        row(left: left, current: current, seconds: showsSeconds)
        row(left: left, current: current, seconds: false)
      }
      .animation(.kit, value: current)
    }
  }

  private func row(left: TimeInterval, current: String?, seconds: Bool) -> some View {
    HStack(spacing: 6) {
      if seconds {
        Text("\(Int(left.rounded(.up))) s")
          .kitFont(.caption)
          .monospacedDigit()
          .contentTransition(.numericText(countsDown: true))
          .fixedSize()
      }
      LiveIcon(
        systemImage: "clock", hue: left <= 5 ? .orange : .accent,
        status: .working(progress: left / period), size: idiom.size(24, touch: 30))
      Text(current.map(Self.grouped) ?? "––– –––")
        .font(.system(size: idiom.size(17, touch: 20), weight: .semibold, design: .monospaced))
        .tracking(1)
        .monospacedDigit()
        .foregroundStyle(current == nil ? AnyShapeStyle(.kitTertiary) : AnyShapeStyle(.kitLabel))
        .contentTransition(.numericText())
        .fixedSize()
        .accessibilityLabel(current.map { "One-time code \($0.map(String.init).joined(separator: " ")), \(Int(left)) seconds left" } ?? "One-time code unavailable")
      Button("Copy Code", systemImage: "doc.on.doc") {
        guard let current else { return }
        KitPasteboard.copySecret(current, expiresAfter: left)
        copies += 1
      }
      .buttonStyle(.kitIcon)
      .help("Copy Code")
      .disabled(current == nil)
      .effect(.success, on: copies, cornerRadius: 6)
    }
  }
}

// MARK: - Safety code

/// A safety code two people compare to be sure they hold each other's real keys (like Signal's safety numbers):
/// sixty digits in twelve groups of five, four to a row, on a well. `.controlSize(.small)` packs it for an
/// inspector.
///
/// ```swift
/// KitSafetyCode("603919375512067304187729128814641028931722740519834062518874")
/// KitSafetyCode(groups: code.groups).controlSize(.small)
/// ```
public struct KitSafetyCode: View {
  var groups: [String]
  var columns: Int
  @Environment(\.controlSize) private var controlSize
  @Environment(\.kitIdiom) private var idiom

  /// The code as digits (anything else is ignored), grouped by five.
  public init(_ digits: String, columns: Int = 4) {
    self.init(groups: Self.groups(digits), columns: columns)
  }

  /// The code as its groups.
  public init(groups: [String], columns: Int = 4) {
    self.groups = groups
    self.columns = max(1, columns)
  }

  /// The digits of `text` in groups of five; a short last group stays short.
  nonisolated static func groups(_ text: String) -> [String] {
    let digits = Array(text.filter(\.isASCIIDigit))
    return stride(from: 0, to: digits.count, by: 5).map { String(digits[$0..<min($0 + 5, digits.count)]) }
  }

  public var body: some View {
    let small = controlSize == .small || controlSize == .mini
    let size: CGFloat = (small ? 11.5 : 13) + (idiom.size(0, touch: 2))
    Grid(alignment: .leading, horizontalSpacing: small ? 10 : 14, verticalSpacing: small ? 2 : 6) {
      ForEach(Array(stride(from: 0, to: groups.count, by: columns)), id: \.self) { start in
        GridRow {
          ForEach(start..<min(start + columns, groups.count), id: \.self) { index in
            Text(groups[index])
          }
        }
      }
    }
    .font(.system(size: size, design: .monospaced))
    .tracking(1)
    .monospacedDigit()
    .lineSpacing(small ? 15 - size : 18 - size)
    .foregroundStyle(.kitLabel)
    .textSelection(.enabled)
    .padding(EdgeInsets(horizontal: small ? 10 : 12, vertical: small ? 8 : 10))
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.kitFill, in: RoundedRectangle(cornerRadius: KitMetrics.radius, style: .continuous))
    .accessibilityElement()
    .accessibilityLabel("Safety code")
    .accessibilityValue(groups.joined(separator: ", "))
  }
}

extension Character {
  fileprivate var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}

// MARK: - Word grid

/// Numbered words on a well, read across: a recovery key's 24 words, a passphrase. Four columns on the Mac and
/// iPad, three on an iPhone.
///
/// ```swift
/// KitWordGrid(recoveryKey.words)
/// ```
public struct KitWordGrid: View {
  var words: [String]
  var columns: Int?
  @Environment(\.kitIdiom) private var idiom

  /// - Parameter columns: how many words to a row; `nil` picks four (three on an iPhone).
  public init(_ words: [String], columns: Int? = nil) {
    self.words = words
    self.columns = columns
  }

  /// The rows of `count` words in `columns` columns, as index ranges, read across.
  nonisolated static func rows(count: Int, columns: Int) -> [Range<Int>] {
    let columns = max(1, columns)
    return stride(from: 0, to: count, by: columns).map { $0..<min($0 + columns, count) }
  }

  public var body: some View {
    let columns = columns ?? (idiom == .phone ? 3 : 4)
    let size: CGFloat = idiom.size(12, touch: 14)
    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
      ForEach(Self.rows(count: words.count, columns: columns), id: \.lowerBound) { row in
        GridRow {
          ForEach(row, id: \.self) { index in
            HStack(spacing: 6) {
              Text("\(index + 1)")
                .foregroundStyle(.kitTertiary)
                .frame(minWidth: size * 1.3, alignment: .trailing)
              Text(words[index]).foregroundStyle(.kitLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
          }
        }
      }
    }
    .font(.system(size: size, design: .monospaced))
    .lineSpacing(18 - size)
    .textSelection(.enabled)
    .padding(EdgeInsets(horizontal: 12, vertical: 10))
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.kitFill, in: RoundedRectangle(cornerRadius: KitMetrics.radius, style: .continuous))
  }
}
