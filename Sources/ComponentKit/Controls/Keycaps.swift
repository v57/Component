import SwiftUI

/// A key drawn as a key: a raised cap with a bottom edge, for shortcuts in hints, tooltips and menus.
///
/// ```swift
/// Keycap("⌘")
/// Keycap("esc")
/// Keycap("⇧⌘P")   // one cap holding a whole shortcut, as tooltips show it
/// ```
public struct Keycap: View {
  var key: String
  @Environment(\.kitIdiom) private var idiom

  public init(_ key: String) { self.key = key }

  public var body: some View {
    let height: CGFloat =
      switch idiom {
      case .mac: 20
      case .pad: 24
      case .phone: 26
      case .tv: 40
      }
    let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
    Text(Keycaps.displayed(key))
      .foregroundStyle(.kitLabel)
      .kitFont(.caption)
      .fontWeight(.medium)
      .tracking(0.02 * 11)
      .lineLimit(1)
      .padding(.horizontal, 5)
      .frame(minWidth: height, minHeight: height)
      .background {
        // A key's bottom edge: the border tone 1pt below the cap.
        shape.fill(.kitBorder).offset(y: 1)
        shape.fill(.kitRaised)
        shape.strokeBorder(.kitBorder, lineWidth: 0.5)
      }
      .padding(.bottom, 1)
      .fixedSize()
      .accessibilityLabel(Keycaps.spoken(key))
  }
}

/// A shortcut as separate keys, 3pt apart: modifiers and symbols each get a cap, the rest of the string is one key.
///
/// ```swift
/// Keycaps("⇧⌘F")   // ⇧ ⌘ F
/// Keycaps("⌘↩")    // ⌘ ↩
/// Keycaps("Tab")   // Tab
/// ```
public struct Keycaps: View {
  var keys: String

  public init(_ keys: String) { self.keys = keys }

  public var body: some View {
    HStack(spacing: 3) {
      ForEach(Array(Self.ordered(Self.split(keys)).enumerated()), id: \.offset) { _, key in
        Keycap(key)
      }
    }
    .fixedSize()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.split(keys).map(Self.spoken).joined(separator: " "))
  }

  /// Symbols that are keys of their own (modifiers, Return, Tab, arrows…).
  nonisolated static let symbols: Set<Character> = ["⌘", "⇧", "⌥", "⌃", "↩", "⏎", "⇥", "⌫", "⌦", "⎋", "↑", "↓", "←", "→", "⇞", "⇟", "↖", "↘", "␣", "⇪"]

  /// Splits a shortcut into keys: each symbol from `symbols` alone, any other run of characters as one key.
  nonisolated static func split(_ keys: String) -> [String] {
    var result: [String] = []
    var run = ""
    for character in keys {
      if symbols.contains(character) {
        if !run.isEmpty { result.append(run) }
        run = ""
        result.append(String(character))
      } else if character == " " || character == "+" {
        if !run.isEmpty { result.append(run) }
        run = ""
      } else {
        run.append(character)
      }
    }
    if !run.isEmpty { result.append(run) }
    return result
  }

  nonisolated static let names: [String: String] = [
    "⌘": "Command", "⇧": "Shift", "⌥": "Option", "⌃": "Control", "↩": "Return", "⏎": "Return", "⇥": "Tab",
    "⌫": "Delete", "⌦": "Forward Delete", "⎋": "Escape", "esc": "Escape", "↑": "Up Arrow", "↓": "Down Arrow",
    "←": "Left Arrow", "→": "Right Arrow", "␣": "Space", "⇪": "Caps Lock",
  ]

  /// A key as this platform writes it: the Mac's symbols, or their names on Windows and Linux, where ⌘ shortcuts
  /// are Ctrl shortcuts, ⌃ is the Windows key and ⌥ is Alt (as v57/SwiftUI maps them).
  nonisolated static func displayed(_ key: String) -> String {
    #if os(Windows) || os(Linux)
      switch key {
      case "⌘": "Ctrl"
      case "⌃": "Win"
      case "⌥": "Alt"
      case "⇧": "Shift"
      case "↩", "⏎": "Enter"
      case "⌫": "Backspace"
      case "⌦": "Del"
      case "⎋": "Esc"
      case "⇥": "Tab"
      default: key
      }
    #else
      key
    #endif
  }

  /// Keys in this platform's order: the Mac's (⇧⌘F), or Ctrl, Win, Alt, Shift and then the key on Windows and Linux.
  nonisolated static func ordered(_ keys: [String]) -> [String] {
    #if os(Windows) || os(Linux)
      let order = ["⌘", "⌃", "⌥", "⇧"]
      let modifiers = keys.filter(order.contains).sorted { order.firstIndex(of: $0)! < order.firstIndex(of: $1)! }
      return modifiers + keys.filter { !order.contains($0) }
    #else
      keys
    #endif
  }

  /// How VoiceOver reads a key or a shortcut: "Shift Command F".
  nonisolated static func spoken(_ key: String) -> String {
    if let name = names[key.lowercased()] { return name }
    let keys = split(key)
    return keys.count > 1 ? keys.map(spoken).joined(separator: " ") : key
  }
}

/// A line of shortcut hints, "keys + what they do", wrapping when it runs out of width (an editor's footer, an
/// empty state, a palette).
///
/// ```swift
/// KeyHints([("⌘↩", "runs"), ("Tab", "completes"), ("⇧⌘F", "find in project"), ("esc", "closes")])
/// ```
public struct KeyHints: View {
  var hints: [(keys: String, action: String)]

  public init(_ hints: [(String, String)]) {
    self.hints = hints.map { (keys: $0.0, action: $0.1) }
  }

  public var body: some View {
    CtlFlowLayout(spacing: 14, lineSpacing: 6) {
      ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
        HStack(spacing: 5) {
          Keycaps(hint.keys)
          Text(hint.action).kitFont(.caption).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
      }
    }
  }
}

#Preview("Keycaps") {
  VStack(alignment: .leading, spacing: 12) {
    HStack { Keycap("⌘"); Keycap("esc"); Keycap("⇧⌘P"); Keycaps("⇧⌘F") }
    KeyHints([("⌘↩", "runs"), ("Tab", "completes"), ("⇧⌘F", "find in project"), ("esc", "closes")])
  }
  .padding(20)
  .componentKit()
}
