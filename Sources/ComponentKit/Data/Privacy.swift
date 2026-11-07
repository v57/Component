import SwiftUI

// What every app's Security and Privacy panes repeat. Pane order, and what goes in each: Ideas/ComponentKit.md,
// "Security and Privacy panes". An app's automatic update check is UpdateKit's `UpdateCheckCard`.

/// The Privacy pane's promise, as a form row: the app sends nothing to the people who made it, to advertisers or to
/// trackers. Only for an app where that's true: every claim comes from the list of its real network calls
/// (`Ideas/Security/network-<app>.md`). `KitPrivacyParties` leads with it. An app with something to add, such as Hub's
/// playground, passes `message`.
///
/// ```swift
/// FormCard { KitNeverContacts("Git") }
/// ```
public struct KitNeverContacts: View {
  var app: String
  var message: KitString?

  /// The promise for `app` (its name, shown as it is); `message` is a key (a literal), looked up in the app's strings.
  public init(_ app: String, message: LocalizedStringKey? = nil) {
    self.init(app: app, message: KitString(message))
  }

  /// The same with a message shown as it is.
  @_disfavoredOverload
  public init(_ app: String, message: String? = nil) {
    self.init(app: app, message: KitString(verbatim: message))
  }

  init(app: String, message: KitString?) {
    self.app = app
    self.message = message
  }

  public var body: some View {
    FormRow(
      title: KitString("Nothing goes to us"),
      help: message
        ?? KitString("\(app) sends no requests to our servers, advertisers or trackers, and has no analytics."),
      systemImage: "hand.raised", hue: .green, error: nil, status: .idle, control: { EmptyView() },
      field: { EmptyView() })
  }
}

/// The Privacy pane's "What Git sends" card: the promise (`KitNeverContacts`), then every party the app talks to.
///
/// ```swift
/// KitPrivacyParties("Git", footer: "Links you click open in your browser.") {
///   KitPrivacyParty(
///     "Your Git servers", systemImage: "server.rack", hue: .blue,
///     when: "When you clone, fetch, pull or push.",
///     why: "They see your IP address and your sign-in, and receive what you push.")
///   KitPrivacyParty("Apple", systemImage: "icloud", hue: .teal, when: "…", why: "…")
/// }
/// ```
public struct KitPrivacyParties<Content: View>: View {
  var app: String
  var message: KitString?
  var footer: KitString?
  @ViewBuilder var content: Content

  /// The card for `app` (its name, shown as it is); `message` and `footer` are keys (literals), looked up in the app's
  /// strings.
  public init(
    _ app: String, message: LocalizedStringKey? = nil, footer: LocalizedStringKey? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.init(app: app, message: KitString(message), footer: KitString(footer), content: content())
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(_ app: String, message: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
    self.init(
      app: app, message: KitString(verbatim: message), footer: KitString(verbatim: footer), content: content())
  }

  init(app: String, message: KitString?, footer: KitString?, content: Content) {
    self.app = app
    self.message = message
    self.footer = footer
    self.content = content
  }

  public var body: some View {
    FormCard(title: KitString("What \(app) sends"), footer: footer) {
      KitNeverContacts(app: app, message: message)
      content
    }
  }
}

/// One party an app talks to, in `KitPrivacyParties`: who, when (one short sentence: "When you push or pull."), and what
/// they get and why. Say it to someone who isn't a security expert.
///
/// ```swift
/// KitPrivacyParty(
///   "GitHub", systemImage: "cloud", hue: .indigo,
///   when: "When you sign in or publish a repository.",
///   why: "It needs your sign-in to do what you asked.")
/// ```
public struct KitPrivacyParty: View {
  var name: KitString
  var systemImage: String
  var hue: Hue
  var when: KitString
  var why: KitString

  /// A party named and described by keys (literals), looked up in the app's strings.
  public init(
    _ name: LocalizedStringKey, systemImage: String, hue: Hue = .gray, when: LocalizedStringKey,
    why: LocalizedStringKey
  ) {
    self.init(name: KitString(name), systemImage: systemImage, hue: hue, when: KitString(when), why: KitString(why))
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(
    _ name: some StringProtocol, systemImage: String, hue: Hue = .gray, when: some StringProtocol,
    why: some StringProtocol
  ) {
    self.init(
      name: KitString(verbatim: String(name)), systemImage: systemImage, hue: hue,
      when: KitString(verbatim: String(when)), why: KitString(verbatim: String(why)))
  }

  init(name: KitString, systemImage: String, hue: Hue, when: KitString, why: KitString) {
    self.name = name
    self.systemImage = systemImage
    self.hue = hue
    self.when = when
    self.why = why
  }

  public var body: some View {
    FormRow(
      title: name, help: when, systemImage: systemImage, hue: hue, error: nil, status: .idle,
      control: { EmptyView() }, field: { EmptyView() })
      .detail {
        Text(why)
          .kitFont(.caption)
          .fixedSize(horizontal: false, vertical: true)
      }
  }
}

/// The Security pane's comparison: what this app does next to other apps of its kind. Each row names the apps, and
/// every sentence is a fact checked in that app's own documentation; say when in the `footer`, and keep the sources in
/// `Ideas/Security/network-<app>.md`. Say where another app does better too.
///
/// ```swift
/// KitSecurityComparison("Git", footer: "From each app’s documentation, November 2026.") {
///   KitComparisonRow(
///     "Your SSH key", systemImage: "key", hue: .green,
///     here: "Made in the Secure Enclave, which nothing can copy it out of.",
///     others: [("Tower", "A private key file you point it to.")])
/// }
/// ```
public struct KitSecurityComparison<Content: View>: View {
  var app: String
  var title: KitString
  var footer: KitString?
  @ViewBuilder var content: Content

  /// The comparison for `app` (its name, shown as it is); `title` and `footer` are keys (literals), looked up in the
  /// app's strings.
  public init(
    _ app: String, title: LocalizedStringKey = "Next to other apps", footer: LocalizedStringKey? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.init(app: app, title: KitString(title), footer: KitString(footer), content: content())
  }

  /// The same with strings shown as they are; a `nil` title is the kit's.
  @_disfavoredOverload
  public init(
    _ app: String, title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content
  ) {
    self.init(
      app: app, title: KitString(verbatim: title) ?? KitString("Next to other apps"),
      footer: KitString(verbatim: footer), content: content())
  }

  init(app: String, title: KitString, footer: KitString?, content: Content) {
    self.app = app
    self.title = title
    self.footer = footer
    self.content = content
  }

  public var body: some View {
    FormCard(title: title, footer: footer) {
      content.environment(\.kitComparisonApp, app)
    }
  }
}

/// One thing compared in `KitSecurityComparison`: what this app does (`here`, under the app's name), then what each
/// other app does. A row can name several apps that do the same: `("Tower, GitKraken", "…")`.
public struct KitComparisonRow: View {
  var title: KitString
  var systemImage: String
  var hue: Hue
  var here: KitString
  var others: [(app: String, text: KitString)]
  @Environment(\.kitComparisonApp) private var app

  /// A row whose title and texts are keys (literals), looked up in the app's strings; the other apps' names are
  /// shown as they are.
  public init(
    _ title: LocalizedStringKey, systemImage: String, hue: Hue = .green, here: LocalizedStringKey,
    others: [(app: String, text: LocalizedStringKey)]
  ) {
    self.init(
      title: KitString(title), systemImage: systemImage, hue: hue, here: KitString(here),
      others: others.map { ($0.app, KitString($0.text)) })
  }

  /// The same with strings shown as they are.
  @_disfavoredOverload
  public init(
    _ title: some StringProtocol, systemImage: String, hue: Hue = .green, here: some StringProtocol,
    others: [(app: String, text: some StringProtocol)]
  ) {
    self.init(
      title: KitString(verbatim: String(title)), systemImage: systemImage, hue: hue,
      here: KitString(verbatim: String(here)), others: others.map { ($0.app, KitString(verbatim: String($0.text))) })
  }

  init(title: KitString, systemImage: String, hue: Hue, here: KitString, others: [(app: String, text: KitString)]) {
    self.title = title
    self.systemImage = systemImage
    self.hue = hue
    self.here = here
    self.others = others
  }

  public var body: some View {
    FormRow(
      title: title, help: nil, systemImage: systemImage, hue: hue, error: nil, status: .idle,
      control: { EmptyView() }, field: { EmptyView() })
      .detail {
        VStack(alignment: .leading, spacing: 6) {
          KitComparisonLine(app: app, text: here, isHere: true)
          ForEach(others, id: \.app) { other in
            KitComparisonLine(app: other.app, text: other.text, isHere: false)
          }
        }
      }
  }
}

/// An app's name over what it does.
private struct KitComparisonLine: View {
  let app: String
  let text: KitString
  let isHere: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      // Inside kitFont: a caption brings its own colour.
      Text(app)
        .fontWeight(.semibold)
        .foregroundStyle(isHere ? .kitLabel : .kitSecondary)
        .kitFont(.caption)
      Text(text)
        .foregroundStyle(isHere ? .kitLabel : .kitSecondary)
        .kitFont(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

extension EnvironmentValues {
  @Entry var kitComparisonApp: String = ""
}

#Preview("Privacy and security") {
  ScrollView {
    VStack(alignment: .leading, spacing: 18) {
      KitPrivacyParties("Git") {
        KitPrivacyParty(
          "Your Git servers", systemImage: "server.rack", hue: .blue, when: "When you clone, fetch, pull or push.",
          why: "They see your IP address and your sign-in, and receive what you push.")
      }
      KitSecurityComparison("Git", footer: "From each app’s documentation, November 2026.") {
        KitComparisonRow(
          "Your SSH key", systemImage: "key", here: "Made in the Secure Enclave, which nothing can copy it out of.",
          others: [("Tower", "A private key file you point it to.")])
      }
    }
    .padding(24)
  }
  .frame(width: 460, height: 520)
  .componentKit()
}
