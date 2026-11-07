import Foundation
import SwiftUI
import Testing

@testable import ComponentKit

#if canImport(ObjectiveC)
  import ObjectiveC

  /// The main bundle with a German table in front, as a downloaded language pack puts one (PlatformLanguages' hook).
  final class GermanMainBundle: Bundle, @unchecked Sendable {
    static let table = [
      "New Note": "Neue Notiz",
      "Search": "Suchen",
      "Open in %@": "In %@ öffnen",
      "%lld of %@": "%lld von %@",
    ]

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
      Self.table[key] ?? super.localizedString(forKey: key, value: value, table: tableName)
    }
  }

  @MainActor @Suite(.serialized) struct KitStringTests {
    /// Runs `body` with the German table in front of the main bundle's own.
    func inGerman(_ body: () -> Void) {
      let original: AnyClass = object_getClass(Bundle.main)!
      object_setClass(Bundle.main, GermanMainBundle.self)
      defer { object_setClass(Bundle.main, original) }
      body()
    }

    @Test func aKitTitleIsLookedUpInTheMainBundle() {
      inGerman {
        // An app's literal is a key: the kit looks it up in the main bundle, where the language pack answers.
        #expect(WelcomeAction("New Note", systemImage: "square.and.pencil") {}.title.string == "Neue Notiz")
        // The kit's own default text goes through the main bundle too.
        #expect(KitSearchField(text: .constant("")).prompt.string == "Suchen")
        // A key with a value keeps the value in the translated sentence.
        let app = "Markdown"
        #expect(KitString("Open in \(app)").string == "In Markdown öffnen")
        #expect(KitString("\(3) of \(app)").string == "3 von Markdown")
      }
    }

    @Test func aStringValueIsShownAsItIs() {
      inGerman {
        let name = "New Note"
        let action = WelcomeAction(name, systemImage: "doc") {}
        #expect(action.title == KitString(verbatim: "New Note"))
        #expect(action.title.string == "New Note")
        #expect(KitSearchField(text: .constant(""), prompt: name).prompt.string == "New Note")
      }
    }

    @Test func literalsPickTheKeyOverload() {
      // A literal and a trailing closure: the key, not the String overload (a concrete `String` there would win).
      guard case .key = WelcomeAction("New Note", systemImage: "doc") {}.title.storage else {
        Issue.record("a literal title should be a key")
        return
      }
      let action = WelcomeAction("New Note", detail: "Start writing", systemImage: "doc") {}
      guard case .key = action.title.storage, case .key = action.detail?.storage else {
        Issue.record("literals should be keys")
        return
      }
      #expect(action.title.string == "New Note")
      #expect(action.detail?.string == "Start writing")
      let segment = KitSegment("Unified", value: 1)
      guard case .key = segment.label.storage else {
        Issue.record("a segment's literal should be a key")
        return
      }
      let title = "Split"
      #expect(KitSegment(title, value: 2).label == KitString(verbatim: "Split"))
      let options = KitSegmented(selection: .constant(1), options: [("One", 1), ("Two", 2)]).segments
      guard case .key = options[0].label.storage else {
        Issue.record("literal options should be keys")
        return
      }
      let names = ["One", "Two"]
      #expect(KitSegmented(selection: .constant(1), options: [(names[0], 1)]).segments[0].label == KitString(verbatim: "One"))
    }
  }
#endif

@Test func formatSpecifiersTakeTheValuesInOrder() {
  #expect(KitString.fill("Open in %@", with: ["Git"]) == "Open in Git")
  #expect(KitString.fill("%lld of %lld", with: ["3", "5"]) == "3 of 5")
  #expect(KitString.fill("%2$@ before %1$@", with: ["a", "b"]) == "b before a")
  #expect(KitString.fill("100%% done", with: []) == "100% done")
  #expect(KitString.fill("%.1f MB", with: ["2.5"]) == "2.5 MB")
  // A missing value leaves nothing rather than crashing.
  #expect(KitString.fill("%@ and %@", with: ["one"]) == "one and ")
}

@Test func aKeyWithoutValuesIsItsOwnText() {
  #expect(KitString("Plain words").string == "Plain words")
  #expect(KitString("").isEmpty)
  #expect(!KitString("x").isEmpty)
  #expect(KitString.empty.isEmpty)
}
