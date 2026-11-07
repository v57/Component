import Foundation
import SwiftUI

/// Text a component shows: a key looked up in the app's strings, or a string shown as it is.
///
/// Components take text the way SwiftUI's own views do: a literal is a `LocalizedStringKey`, looked up in the main
/// bundle when it shows (the app's strings, which merge its kits' strings, and a downloaded language pack first), and
/// a `String` value is shown verbatim (names, paths, text the app already localized). So each public initializer
/// that takes a title comes twice:
///
/// ```swift
/// public init(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, …) {
///   self.init(title: KitString(title), detail: KitString(detail), …)
/// }
/// @_disfavoredOverload
/// public init(_ title: some StringProtocol, detail: String? = nil, …) {
///   self.init(title: KitString(verbatim: String(title)), detail: KitString(verbatim: detail), …)
/// }
/// ```
///
/// and the component keeps a `KitString`, drawn with `Text(title)`. The `String` overload's required text must be
/// generic (`some StringProtocol`, as SwiftUI's `Text` does): with a plain `String` there, Swift picks that overload
/// for a literal despite `@_disfavoredOverload`. All texts of one call share the kind, so an app that mixes a literal
/// with a `String` value (`kitNotice("Couldn't Save", isPresented: $failed, message: error.localizedDescription)`)
/// gets the `String` overload, literal and all: interpolate the value (`message: "\(error.localizedDescription)"`) to
/// keep the literal a key. Keys are what the compiler extracts (`-emit-localized-strings` records literals typed
/// `LocalizedStringKey`), which is why the public API takes that type and not `KitString`. A literal in the kit itself
/// (a default title, a button's name) is a key too: `KitString("Cancel")`.
struct KitString: Equatable, @unchecked Sendable {
  enum Storage: Equatable {
    case key(LocalizedStringKey)
    case verbatim(String)
  }

  var storage: Storage

  init(_ key: LocalizedStringKey) { storage = .key(key) }

  init(verbatim string: String) { storage = .verbatim(string) }

  /// A key, or `nil` without one.
  init?(_ key: LocalizedStringKey?) {
    guard let key else { return nil }
    storage = .key(key)
  }

  /// A string shown as it is, or `nil` without one.
  init?(verbatim string: String?) {
    guard let string else { return nil }
    storage = .verbatim(string)
  }

  static let empty = KitString(verbatim: "")

  /// The text to draw: a key's localized string or the string itself (never Markdown or a key for a `String`).
  var text: Text {
    switch storage {
    case .key(let key): Text(key)
    case .verbatim(let string): Text(verbatim: string)
    }
  }

  /// The text as a string, for what can't take a `Text` (filtering, matching, a drop's name): a key looked up in the
  /// main bundle, with its interpolated values put back in.
  var string: String {
    switch storage {
    case .key(let key): KitString.resolve(key)
    case .verbatim(let string): string
    }
  }

  var isEmpty: Bool {
    switch storage {
    case .key(let key): KitString.parts(of: key)?.key.isEmpty ?? false
    case .verbatim(let string): string.isEmpty
    }
  }
}

extension KitString {
  /// A key's format string and its values. `LocalizedStringKey` keeps them private; SwiftUI's and v57/SwiftUI's both
  /// name them `key`, `hasFormatting` and `arguments`. Only for `string`: drawing always goes through `Text`.
  static func parts(of key: LocalizedStringKey) -> (key: String, arguments: [Any])? {
    var format: String?
    var hasFormatting = false
    var arguments: [Any] = []
    for child in Mirror(reflecting: key).children {
      switch child.label {
      case "key": format = child.value as? String
      case "hasFormatting": hasFormatting = child.value as? Bool ?? false
      case "arguments": arguments = Mirror(reflecting: child.value).children.map(\.value)
      default: break
      }
    }
    guard let format else { return nil }
    return (format, hasFormatting ? arguments : [])
  }

  static func resolve(_ key: LocalizedStringKey) -> String {
    guard let (format, arguments) = parts(of: key) else { return "" }
    let localized = Bundle.main.localizedString(forKey: format, value: nil, table: nil)
    return arguments.isEmpty ? localized : fill(localized, with: arguments.map(describe))
  }

  /// An argument as text: the first plain value inside SwiftUI's wrapper (a string, a number), else its description.
  static func describe(_ argument: Any) -> String {
    switch argument {
    case let string as String: return string
    case let value as any BinaryInteger: return "\(value)"
    case let value as Double: return value.formatted()
    case let value as Float: return value.formatted()
    case let value as CGFloat: return Double(value).formatted()
    default: break
    }
    for child in Mirror(reflecting: argument).children {
      let text = describe(child.value)
      if !text.isEmpty { return text }
    }
    return ""
  }

  /// Puts the values in a format string's specifiers (`%@`, `%lld`, `%2$@`…) as text; `%%` is a percent sign. Never
  /// `String(format:)`: a value of the wrong type there would crash.
  static func fill(_ format: String, with values: [String]) -> String {
    var result = ""
    var next = 0
    var index = format.startIndex
    while index < format.endIndex {
      let character = format[index]
      guard character == "%" else {
        result.append(character)
        index = format.index(after: index)
        continue
      }
      var cursor = format.index(after: index)
      guard cursor < format.endIndex else { result.append("%"); break }
      if format[cursor] == "%" {
        result.append("%")
        index = format.index(after: cursor)
        continue
      }
      // An optional position (`2$`), flags, width, precision and length, then the conversion.
      var digits = ""
      while cursor < format.endIndex, format[cursor].isNumber { digits.append(format[cursor]); cursor = format.index(after: cursor) }
      var position: Int?
      if cursor < format.endIndex, format[cursor] == "$", let number = Int(digits) {
        position = number - 1
        cursor = format.index(after: cursor)
      }
      while cursor < format.endIndex, "-+ #0123456789.hlqLzjt".contains(format[cursor]) { cursor = format.index(after: cursor) }
      guard cursor < format.endIndex else { break }
      let slot = position ?? next
      if position == nil { next += 1 }
      result += slot < values.count ? values[slot] : ""
      index = format.index(after: cursor)
    }
    return result
  }
}

extension Text {
  /// A component's text: its key localized, or its string as it is.
  init(_ string: KitString) { self = string.text }
}

extension Label where Title == Text, Icon == Image {
  init(_ title: KitString, systemImage: String) {
    self.init { Text(title) } icon: { Image(systemName: systemImage) }
  }
}

extension Button where Label == Text {
  init(_ title: KitString, role: ButtonRole? = nil, action: @escaping @MainActor () -> Void) {
    self.init(role: role, action: action) { Text(title) }
  }
}

extension TextField where Label == Text {
  init(_ title: KitString, text: Binding<String>, prompt: Text?) {
    self.init(text: text, prompt: prompt) { Text(title) }
  }
}

extension View {
  func accessibilityLabel(_ label: KitString) -> some View { accessibilityLabel(Text(label)) }

  func accessibilityLabel(_ label: KitString?) -> some View {
    modifier(KitOptionalAccessibilityLabel(label: label))
  }

  func help(_ text: KitString) -> some View { help(Text(text)) }
}

private struct KitOptionalAccessibilityLabel: ViewModifier {
  let label: KitString?

  func body(content: Content) -> some View {
    if let label { content.accessibilityLabel(Text(label)) } else { content }
  }
}

extension KitString {
  /// The text as written, in no language: a key's own words with its values put back in, or the string. The same in
  /// every language, for an id a title stands for (a selection an app stores or sets, such as a settings pane's).
  var sourceText: String {
    switch storage {
    case .key(let key):
      guard let (format, arguments) = KitString.parts(of: key) else { return "" }
      return arguments.isEmpty ? format : KitString.fill(format, with: arguments.map(KitString.describe))
    case .verbatim(let string): return string
    }
  }
}
