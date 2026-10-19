import SwiftUI

/// A label in the icon-tile shape (5pt corners, like change kinds and row tiles), tinted in its meaning's hue with
/// dark text: a status ("Syncing", "Pending"), a safety tag ("Staging", "Read only"), a type ("Int32"), a language.
/// Without a hue it is the neutral fill ("Swift", "+1"). Production is the one solid label (`Chip.production`).
/// Small chips (15pt) for section headers and toolbar titles come from `.controlSize(.small)`.
///
/// ```swift
/// Chip("Syncing", hue: .blue)
/// Chip("Production", systemImage: "shield", hue: .red, style: .solid)
/// Chip("Draft", style: .quiet)
/// Chip(status: "shipped")      // green, from the word
/// Chip.readOnly.controlSize(.small)
/// ```
public struct Chip: View {
  public enum Style: Hashable, Sendable {
    /// The hue at 16% (20% in dark) under the hue's text tone; the neutral fill without a hue.
    case soft
    /// Filled, white text: only Production.
    case solid
    /// The faintest fill with secondary text ("Draft", a short hash).
    case quiet
  }

  var title: Text
  var systemImage: String?
  var hue: Hue?
  var style: Style
  @Environment(\.controlSize) private var controlSize
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.kitMoreContrast) private var moreContrast

  /// A chip with a title, an optional leading SF Symbol and the hue of its meaning.
  public init(_ title: some StringProtocol, systemImage: String? = nil, hue: Hue? = nil, style: Style = .soft) {
    self.init(Text(title), systemImage: systemImage, hue: hue, style: style)
  }

  /// A chip with styled text (a monospaced hash: `Chip(Text("a1b2c3d").monospaced(), style: .quiet)`).
  public init(_ title: Text, systemImage: String? = nil, hue: Hue? = nil, style: Style = .soft) {
    self.title = title
    self.systemImage = systemImage
    self.hue = hue
    self.style = style
  }

  /// A status word in a cell, coloured by what it says: done words green, waiting words orange, failures red,
  /// closed ones gray; other words get the neutral fill.
  public init(status word: some StringProtocol) {
    self.init(word, hue: Hue.forStatus(word))
  }

  /// A value's type next to a field ("Int32", "ZSET", "TEXT"), coloured by the kind of type.
  public init(type name: some StringProtocol) {
    self.init(name, hue: Hue.forTypeName(name))
  }

  /// The one solid label: a production connection or environment.
  public static var production: Chip { Chip("Production", systemImage: "shield", hue: .red, style: .solid) }
  /// A connection or file that can't be changed.
  public static var readOnly: Chip { Chip("Read only", systemImage: "lock", hue: .gray) }

  public var body: some View {
    let m = ChipMetrics(controlSize: controlSize, idiom: idiom)
    HStack(spacing: m.gap) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(.system(size: m.glyph, weight: .semibold))
          .imageScale(.small)
      }
      title
        .lineLimit(1)
    }
    .font(.system(size: m.fontSize, weight: .semibold))
    .foregroundStyle(ink)
    .padding(.horizontal, m.padding)
    .frame(height: m.height)
    .background(ground, in: m.shape)
    .overlay {
      if moreContrast, style != .solid {
        m.shape.strokeBorder((hue ?? .gray).fill.opacity(0.6), lineWidth: 1)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .opacity(isEnabled ? 1 : 0.45)
    .animation(.kit, value: hue)
    .accessibilityElement(children: .combine)
  }

  private var ink: AnyShapeStyle {
    switch style {
    case .solid: AnyShapeStyle(Color.white)
    case .quiet: AnyShapeStyle(.kitSecondary)
    case .soft: hue.map { AnyShapeStyle(BadgeInk(hue: $0)) } ?? AnyShapeStyle(.kitLabel)
    }
  }

  private var ground: AnyShapeStyle {
    switch style {
    case .solid:
      if let hue, hue != .red { AnyShapeStyle(PersonFill(hue: hue)) } else { AnyShapeStyle(KitColor.dangerSolid) }
    case .quiet: AnyShapeStyle(.kitFillSoft)
    case .soft: hue.map { AnyShapeStyle(BadgeTint(hue: $0)) } ?? AnyShapeStyle(.kitFill)
    }
  }
}

extension Hue {
  /// The hue a status word speaks in, or `nil` for the neutral fill (Database's `StatusPill`).
  public static func forStatus(_ word: some StringProtocol) -> Hue? {
    switch word.lowercased() {
    case "shipped", "done", "active", "paid", "completed", "success", "ok", "true", "up to date", "merged": .green
    case "pending", "waiting", "processing", "draft", "open", "staging": .orange
    case "cancelled", "canceled", "failed", "error", "rejected", "false", "conflict": .red
    case "refunded", "archived", "closed", "inactive", "idle", "stopped": .gray
    case "syncing", "running", "pushing", "pulling": .blue
    default: nil
    }
  }

  /// The hue for a value type's name (Database's `TypeBadge`): text blue, numbers purple, collections green…
  public static func forTypeName(_ name: some StringProtocol) -> Hue {
    switch name.uppercased() {
    case "STRING", "TEXT", "VARCHAR", "CHAR": .blue
    case "HASH", "INT", "INT32", "INT64", "INTEGER", "BIGINT", "DOUBLE", "FLOAT", "REAL", "DECIMAL", "DECIMAL128",
      "NUMBER", "NUMERIC":
      .purple
    case "LIST", "ARRAY", "OBJECT", "JSON", "JSONB": .green
    case "SET": .teal
    case "ZSET", "DATE", "TIMESTAMP", "TIMESTAMPTZ", "TIME": .orange
    case "STREAM", "OBJECTID", "KEY", "UUID": .brown
    case "BOOLEAN", "BOOL": .indigo
    default: .gray
    }
  }
}

#Preview("Chips") {
  VStack(alignment: .leading, spacing: 10) {
    HStack(spacing: 6) {
      Chip("Swift")
      Chip("Draft", style: .quiet)
      Chip(Text("a1b2c3d").monospaced(), style: .quiet)
      Chip("+1")
    }
    HStack(spacing: 6) {
      Chip("Up to date", hue: .green)
      Chip("Syncing", hue: .blue)
      Chip("Pending", hue: .orange)
      Chip("Failed", hue: .red)
      Chip("Conflict", hue: .purple)
      Chip("Idle", hue: .gray)
    }
    HStack(spacing: 6) {
      Chip.production
      Chip("Staging", hue: .orange)
      Chip("Local", hue: .green)
      Chip("Replica", hue: .purple)
      Chip.readOnly
    }
    HStack(spacing: 6) {
      Chip(status: "shipped")
      Chip(status: "pending")
      Chip(type: "Int32")
      Chip(type: "ZSET")
    }
    HStack(spacing: 6) {
      Chip.production
      Chip("Pushing", hue: .blue)
    }
    .controlSize(.small)
    HStack(spacing: 6) {
      Chip("Syncing", hue: .blue)
      Chip("Staging", hue: .orange)
    }
    .disabled(true)
  }
  .padding()
  .componentKit()
}

// MARK: - Filter token

/// An active filter in a filter bar: the condition on a soft accent token (24pt, 32 on touch) with its remove button
/// at the end. The whole condition reads as one element to VoiceOver, with a Remove action.
///
/// ```swift
/// HStack {
///   ForEach(filters) { filter in FilterToken(filter.summary) { remove(filter) } }
/// }
/// FilterToken(Text("status = ") + Text("shipped").bold(), hue: .green) { … }
/// ```
public struct FilterToken: View {
  var title: Text
  var systemImage: String?
  var hue: Hue
  var onRemove: () -> Void
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  public init(
    _ title: some StringProtocol, systemImage: String? = "line.3.horizontal.decrease", hue: Hue = .accent,
    onRemove: @escaping () -> Void
  ) {
    self.init(Text(title), systemImage: systemImage, hue: hue, onRemove: onRemove)
  }

  /// A token with styled text (the value in bold).
  public init(
    _ title: Text, systemImage: String? = "line.3.horizontal.decrease", hue: Hue = .accent,
    onRemove: @escaping () -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.hue = hue
    self.onRemove = onRemove
  }

  public var body: some View {
    let height: CGFloat = idiom.isTouch ? 32 : 24
    let radius: CGFloat = idiom.isTouch ? 10 : 7
    let close = height - 6
    HStack(spacing: 5) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(.system(size: idiom.isTouch ? 12 : 10, weight: .semibold))
          .imageScale(.small)
      }
      title
        .kitFont(.callout)
        .fontWeight(.medium)
        .lineLimit(1)
        .truncationMode(.middle)
      Button(action: onRemove) {
        Image(systemName: "xmark")
          .font(.system(size: close * 0.45, weight: .bold))
          .frame(width: close, height: close)
          .background {
            RoundedRectangle(cornerRadius: radius - 3, style: .continuous)
              .fill(isHovered ? AnyShapeStyle(hue.soft(0.22)) : AnyShapeStyle(Color.clear))
          }
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .kitHover { isHovered = $0 }
      .accessibilityLabel("Remove")
    }
    .foregroundStyle(BadgeInk(hue: hue))
    .padding(.leading, idiom.isTouch ? 10 : 8)
    .padding(.trailing, 3)
    .frame(height: height)
    .background(BadgeTint(hue: hue), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    .opacity(isEnabled ? 1 : 0.45)
    .animation(.kitFast, value: isHovered)
    .accessibilityElement(children: .combine)
    .accessibilityAction(named: "Remove", onRemove)
  }
}

#Preview("Filter tokens") {
  HStack {
    FilterToken("status = shipped") {}
    FilterToken(Text("total > ") + Text("100").bold(), hue: .orange) {}
    FilterToken("Any column contains “Lisbon”", systemImage: "magnifyingglass") {}
  }
  .padding(20)
  .componentKit()
}
