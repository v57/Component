import PlatformLanguages
import SwiftUI

// MARK: - Settings ▸ Languages

/// The Languages pane every app adds to its settings: the language the app runs in (and where to change it), then
/// every language it has, can download or has downloaded (PlatformLanguages' `LanguagePacks`), with Download, Update
/// and Remove. Nothing is downloaded or checked until the user asks.
///
/// ```swift
/// SettingsPane("Languages", systemImage: "globe", hue: .blue, section: "v57") { KitLanguagesSettings() }
/// ```
public struct KitLanguagesSettings: View {
  @State private var packs = LanguagePacks.shared
  @State private var checking = false
  @State private var failures: [String: String] = [:]

  public init() {}

  public var body: some View {
    FormCard("Language", footer: languageFooter) {
      #if os(Windows) || os(Linux)
        FormRow("\(KitLanguages.appName)'s language", systemImage: "globe", stacked: { AppLanguagePicker() })
      #else
        FormRow(
          "\(KitLanguages.appName)'s language", help: current.map { "\($0.ownName) · \($0.name)" },
          systemImage: "globe"
        ) {
          #if os(macOS) || os(iOS) || os(visionOS)
            Button("Change…") { KitDesktop.open(KitLanguages.systemSettings) }.buttonStyle(.kit)
          #endif
        }
      #endif
    }
    FormCard("Languages", footer: listFooter) {
      ForEach(packs.languages) { language in
        row(language)
      }
      FormRow(
        packs.checked == nil ? "Find more languages" : "Checked \(Self.time(packs.checked!))",
        help: "Reads the list of translations from GitHub", systemImage: "arrow.triangle.2.circlepath",
        error: failures[""], status: checking ? .working : .idle
      ) {
        Button(packs.checked == nil ? "Check" : "Check Again") { check() }
          .buttonStyle(.kit)
          .disabled(checking)
      }
    }
  }

  private var current: LanguagePacks.Language? { packs.languages.first { $0.isActive } }

  private var languageFooter: String {
    #if os(Windows) || os(Linux)
      "Applies the next time you open \(KitLanguages.appName)."
    #else
      "\(KitLanguages.appName) follows the language set for it in the system's settings."
    #endif
  }

  private var listFooter: String {
    "Translations come from github.com/v57/Localizations. Every line is checked before it's used; one that doesn't "
      + "fit shows in English."
  }

  @ViewBuilder private func row(_ language: LanguagePacks.Language) -> some View {
    let help = [language.name, Self.detail(language.state)].compactMap { $0 }.joined(separator: " · ")
    FormRow(
      language.ownName, help: help, systemImage: language.isActive ? "checkmark.circle" : "character.bubble",
      hue: language.isActive ? .accent : .gray, error: failures[language.code],
      status: language.state == .downloading ? .working : .idle
    ) {
      switch language.state {
      case .included:
        Chip("Included", style: .quiet)
      case .available:
        Button("Download") { download(language.code) }.buttonStyle(.kit)
      case .downloading:
        EmptyView()
      case .downloaded(_, let updateAvailable):
        HStack(spacing: 6) {
          if updateAvailable {
            Button("Update") { download(language.code) }.buttonStyle(.kitPrimary)
          }
          Button("Remove", role: .destructive) { packs.remove(language.code) }.buttonStyle(.kit)
        }
      }
    }
  }

  private static func detail(_ state: LanguagePacks.State) -> String? {
    switch state {
    case .included: nil
    case .available(let bytes): bytes.map(KitLanguages.size)
    case .downloading: "Downloading…"
    case .downloaded(let bytes, let updateAvailable):
      updateAvailable ? "Update available" : "Downloaded · \(KitLanguages.size(bytes))"
    }
  }

  private static func time(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
  }

  private func download(_ code: String) {
    failures[code] = nil
    Task {
      do { try await packs.download(code) } catch { failures[code] = error.localizedDescription }
    }
  }

  private func check() {
    checking = true
    failures[""] = nil
    Task {
      do { try await packs.checkForUpdates() } catch { failures[""] = error.localizedDescription }
      checking = false
    }
  }
}

// MARK: - The scene's side

extension View {
  /// For each scene's root: rebuilds the scene when the app's strings change (a language downloaded, updated or
  /// removed, so every text shows it at once), and asks once, after the window appears, whether to download the
  /// app's language when the app runs in one it doesn't include.
  ///
  /// ```swift
  /// WindowGroup { ContentView().kitLanguages() }
  /// ```
  public func kitLanguages() -> some View { modifier(KitLanguagesModifier()) }
}

struct KitLanguagesModifier: ViewModifier {
  @State private var packs = LanguagePacks.shared
  @State private var offer: LanguagePacks.Language?
  @State private var failure: String?

  func body(content: Content) -> some View {
    content
      .id(packs.revision)
      .kitDialog(
        "Show \(KitLanguages.appName) in \(offer?.ownName ?? "")?",
        isPresented: Binding(get: { offer != nil }, set: { if !$0 { offer = nil } }),
        message: offerMessage, systemImage: "globe", confirm: "Download"
      ) {
        guard let code = offer?.code else { return }
        Task {
          do { try await packs.download(code) } catch { failure = error.localizedDescription }
        }
      }
      .kitNotice("Couldn't Download the Translation", message: $failure)
      .task {
        guard packs.offer != nil else { return }
        // After the window: the question comes from the app, not before it.
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        guard let language = packs.offer else { return }
        packs.dismissOffer()
        offer = language
      }
  }

  private var offerMessage: String {
    guard let offer else { return "" }
    var size = ""
    if case .available(let bytes?) = offer.state { size = " (\(KitLanguages.size(bytes)))" }
    return "\(KitLanguages.appName) comes in English and a few languages. Download its \(offer.name) translation"
      + "\(size) from GitHub? You can do it later in Settings ▸ Languages."
  }
}

enum KitLanguages {
  static var appName: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? ProcessInfo.processInfo.processName
  }

  static func size(_ bytes: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
  }

  #if os(macOS)
    /// Language & Region, where macOS sets an app's language.
    static let systemSettings = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")!
  #else
    /// The app's page in Settings, which has its Language row.
    static let systemSettings = URL(string: "app-settings:")!
  #endif
}
