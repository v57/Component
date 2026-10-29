import ComponentKit
import SwiftUI

extension EnvironmentValues {
  /// The page is one item of the All Components page, not a window's page: no scroll view of its own.
  @Entry var catalogEmbedded = false
}

/// Every component page (all but the scenarios) one after the other on one long page: a page tens of thousands of
/// points tall of the heaviest views, where only what nears the screen is built.
struct AllComponentsPage: View {
  private var pages: [Page] { Page.allCases.filter { $0.area != .scenarios } }

  var body: some View {
    CatalogPage(page: .allComponents) {
      ForEach(pages) { page in
        PageContent(page: page)
          .environment(\.catalogEmbedded, true)
          .padding(.top, 24)
      }
    }
  }
}
