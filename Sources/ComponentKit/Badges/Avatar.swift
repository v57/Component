import SwiftUI

/// Who or what something is, where the shape says the kind and `StableHue` picks the hue from the name (so the same
/// name always gets the same colour):
/// - a **person** is a solid circle in the hue's deep shade with white initials, and can show a presence dot;
/// - an **agent** is a soft rounded square with initials that wears the live icon's ring while it works (an arc, or
///   a ring that fills with progress, then green or red), so "Working" needs no chip;
/// - a **thing** (repository, connection, project) is a soft tile with its letter, or a glyph;
/// - an **app** is the only solid squircle, with a glyph and a shadow in proportion to its size.
/// Anything offline fades.
///
/// ```swift
/// Avatar(name: "Maya Okafor", presence: .online)
/// Avatar(name: "coder-1", kind: .agent, status: .working)
/// Avatar(name: "atlas", kind: .thing)
/// Avatar(name: "Postgres", letters: "Pg", kind: .thing, hue: .blue)
/// Avatar(name: "Git", kind: .app, systemImage: "arrow.triangle.branch", hue: .orange, size: 56)
/// ```
public struct Avatar: View {
  public enum Kind: Hashable, Sendable {
    case person, agent, thing, app
  }

  /// Whether someone is around. A person shows a green (online) or orange (away) dot; offline dims any kind.
  public enum Presence: Hashable, Sendable {
    case online, away, offline
  }

  var name: String
  var letters: String?
  var kind: Kind
  var hue: Hue?
  var systemImage: String?
  var status: WorkStatus
  var presence: Presence?
  var size: CGFloat
  @Environment(\.colorScheme) private var scheme

  public init(
    name: String, letters: String? = nil, kind: Kind = .person, systemImage: String? = nil, hue: Hue? = nil,
    status: WorkStatus = .idle, presence: Presence? = nil, size: CGFloat = 24
  ) {
    self.name = name
    self.letters = letters
    self.kind = kind
    self.hue = hue
    self.systemImage = systemImage
    self.status = status
    self.presence = presence
    self.size = size
  }

  /// The hue: the one given, the accent for a thing shown with a glyph, or one picked from the name.
  var resolvedHue: Hue {
    if let hue { return hue }
    if kind == .thing, systemImage != nil { return .accent }
    if kind == .app { return .accent }
    return StableHue.pick(name)
  }

  public var body: some View {
    let hue = resolvedHue
    face(hue)
      .frame(width: size, height: size)
      .mask { presenceCutout }
      .overlay(alignment: .bottomTrailing) {
        if let dot = presenceDotHue {
          Circle().fill(dot.fill)
            .frame(width: dotSize, height: dotSize)
            .offset(x: 1, y: 1)
            .transition(.scale.combined(with: .opacity))
        }
      }
      .overlay {
        if kind == .agent, status != .idle {
          StatusRing(status: status, hue: status.hue ?? hue, size: size, shape: .rounded)
        }
      }
      .opacity(presence == .offline ? 0.5 : 1)
      .animation(.kit, value: status)
      .animation(.kit, value: presence)
      .accessibilityElement()
      .accessibilityLabel(accessibilityText)
  }

  @ViewBuilder
  private func face(_ hue: Hue) -> some View {
    switch kind {
    case .person:
      Circle().fill(PersonFill(hue: hue))
        .overlay { initialsText(Self.initials(name), scale: 0.4).foregroundStyle(Color.white) }
    case .agent:
      KitShape.rounded.shape(size: size).fill(IdentityTint(hue: hue))
        .overlay { initialsText(Self.initials(name), scale: 0.38).foregroundStyle(IdentityInk(hue: hue)) }
    case .thing:
      if let systemImage {
        KitShape.rounded.shape(size: size).fill(IdentityTint(hue: hue))
          .overlay {
            Image(systemName: systemImage).font(.system(size: size * 0.5, weight: .semibold)).imageScale(.small)
              .foregroundStyle(hue.fill)
          }
      } else {
        let text = letters ?? Self.letter(name)
        KitShape.rounded.shape(size: size).fill(IdentityTint(hue: hue))
          .overlay {
            initialsText(text, scale: text.count > 1 ? 0.4 : 0.5, rounded: true).foregroundStyle(IdentityInk(hue: hue))
          }
      }
    case .app:
      let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
      shape.fill(hue.fill)
        .overlay {
          if let systemImage {
            Image(systemName: systemImage).font(.system(size: size * 0.5, weight: .semibold))
          } else {
            initialsText(letters ?? Self.letter(name), scale: 0.5, rounded: true)
          }
        }
        .foregroundStyle(Color.white)
        .overlay { TopHighlight(shape: shape, opacity: 0.25) }
        .overlay { shape.strokeBorder(scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12), lineWidth: 0.5) }
        .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.14), radius: size * 0.11, y: size * 0.09)
    }
  }

  private func initialsText(_ text: String, scale: CGFloat, rounded: Bool = false) -> some View {
    Text(letters ?? text)
      .font(.system(size: size * scale, weight: .bold, design: rounded ? .rounded : .default))
      .lineLimit(1)
      .minimumScaleFactor(0.6)
      .padding(.horizontal, size * 0.08)
  }

  // MARK: Presence

  private var presenceDotHue: Hue? {
    guard kind == .person else { return nil }
    switch presence {
    case .online: return .green
    case .away: return .orange
    default: return nil
    }
  }

  private var dotSize: CGFloat { max(6, (size * 0.28).rounded()) }

  /// Cuts a 2pt gap around the presence dot, so it reads on any ground.
  @ViewBuilder
  private var presenceCutout: some View {
    if presenceDotHue != nil {
      Rectangle()
        .overlay(alignment: .bottomTrailing) {
          Circle()
            .frame(width: dotSize + 4, height: dotSize + 4)
            .offset(x: 3, y: 3)
            .blendMode(.destinationOut)
        }
        .compositingGroup()
    } else {
      Rectangle()
    }
  }

  private var accessibilityText: String {
    var parts = [name]
    if kind == .agent, status != .idle { parts.append(LiveIcon<EmptyView>.label(status)) }
    switch presence {
    case .online: parts.append("online")
    case .away: parts.append("away")
    case .offline: parts.append("offline")
    case nil: break
    }
    return parts.joined(separator: ", ")
  }

  // MARK: Letters

  /// Two initials from a name's first two words ("Maya Okafor" → MO, "coder-1" → C1), "?" for none.
  nonisolated static func initials(_ name: String) -> String {
    let words = name.split { $0 == " " || $0 == "." || $0 == "-" || $0 == "_" }
    let letters = words.prefix(2).compactMap(\.first).map { String($0).uppercased() }
    return letters.isEmpty ? "?" : letters.joined()
  }

  /// A thing's one letter: the name's first letter or digit ("atlas" → A).
  nonisolated static func letter(_ name: String) -> String {
    name.first { $0.isLetter || $0.isNumber }.map { String($0).uppercased() } ?? "?"
  }
}

#Preview("Identity") {
  VStack(alignment: .leading, spacing: 16) {
    HStack(spacing: 10) {
      Avatar(name: "Maya Okafor", size: 16)
      Avatar(name: "Maya Okafor")
      Avatar(name: "Maya Okafor", size: 32)
      Avatar(name: "Rafael Silva", presence: .online)
      Avatar(name: "Aiko Tanaka", presence: .away)
      Avatar(name: "Jonas Berg", presence: .offline)
    }
    HStack(spacing: 14) {
      Avatar(name: "coder-1", kind: .agent, status: .working)
      Avatar(name: "artist", kind: .agent, status: .working(progress: 0.6))
      Avatar(name: "planner", kind: .agent)
      Avatar(name: "tester", kind: .agent, status: .done)
      Avatar(name: "qa", kind: .agent, status: .failed)
      Avatar(name: "coder-3", kind: .agent, presence: .offline)
    }
    HStack(spacing: 10) {
      Avatar(name: "atlas", kind: .thing)
      Avatar(name: "harbor", kind: .thing, size: 28)
      Avatar(name: "Catalog", letters: "Mg", kind: .thing, hue: .green)
      Avatar(name: "Analytics", letters: "Dk", kind: .thing, hue: .orange, size: 32)
      Avatar(name: "Database", kind: .thing, systemImage: "cylinder.split.1x2")
    }
    HStack(spacing: 10) {
      Avatar(name: "Git", kind: .app, systemImage: "arrow.triangle.branch", hue: .orange, size: 20)
      Avatar(name: "Markdown", kind: .app, systemImage: "text.alignleft", hue: .red, size: 28)
      Avatar(name: "Shell", kind: .app, systemImage: "terminal", hue: .gray, size: 40)
    }
  }
  .padding()
  .componentKit()
}
