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
  var message: String?

  public init(_ app: String, message: String? = nil) {
    self.app = app
    self.message = message
  }

  public var body: some View {
    FormRow(
      "Nothing goes to us",
      help: message ?? "\(app) sends no requests to our servers, advertisers or trackers, and has no analytics.",
      systemImage: "hand.raised", hue: .green)
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
  var message: String?
  var footer: String?
  @ViewBuilder var content: Content

  public init(_ app: String, message: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
    self.app = app
    self.message = message
    self.footer = footer
    self.content = content()
  }

  public var body: some View {
    FormCard("What \(app) sends", footer: footer) {
      KitNeverContacts(app, message: message)
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
  var name: String
  var systemImage: String
  var hue: Hue
  var when: String
  var why: String

  public init(_ name: String, systemImage: String, hue: Hue = .gray, when: String, why: String) {
    self.name = name
    self.systemImage = systemImage
    self.hue = hue
    self.when = when
    self.why = why
  }

  public var body: some View {
    FormRow(name, help: when, systemImage: systemImage, hue: hue)
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
  var title: String
  var footer: String?
  @ViewBuilder var content: Content

  public init(
    _ app: String, title: String = "Next to other apps", footer: String? = nil, @ViewBuilder content: () -> Content
  ) {
    self.app = app
    self.title = title
    self.footer = footer
    self.content = content()
  }

  public var body: some View {
    FormCard(title, footer: footer) {
      content.environment(\.kitComparisonApp, app)
    }
  }
}

/// One thing compared in `KitSecurityComparison`: what this app does (`here`, under the app's name), then what each
/// other app does. A row can name several apps that do the same: `("Tower, GitKraken", "…")`.
public struct KitComparisonRow: View {
  var title: String
  var systemImage: String
  var hue: Hue
  var here: String
  var others: [(app: String, text: String)]
  @Environment(\.kitComparisonApp) private var app

  public init(
    _ title: String, systemImage: String, hue: Hue = .green, here: String, others: [(app: String, text: String)]
  ) {
    self.title = title
    self.systemImage = systemImage
    self.hue = hue
    self.here = here
    self.others = others
  }

  public var body: some View {
    FormRow(title, systemImage: systemImage, hue: hue)
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
  let text: String
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
