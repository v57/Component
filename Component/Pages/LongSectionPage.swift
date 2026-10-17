import ComponentKit
import SwiftUI

/// Thousands of rows in one `KitSection`, streamed in as a search finds them: Code's Find in Project, 5,000 matches
/// in 250-row batches. The section's rows are one lazy stack, so this is its worst case: every batch plans every row.
struct LongSectionPage: View {
  /// `--long-section-rows <n>` (DEBUG) sets how many.
  static let total: Int = {
    let arguments = ProcessInfo.processInfo.arguments
    if let index = arguments.firstIndex(of: "--long-section-rows"), index + 1 < arguments.count,
      let rows = Int(arguments[index + 1]), rows > 0
    {
      return rows
    }
    return 5_000
  }()
  static let batch = 250
  @State private var count = 0
  @State private var started = ContinuousClock.now
  @State private var took: Duration?

  var body: some View {
    CatalogPage(page: .longSection, maxWidth: 720) {
      KitSection(
        "Find Results", meta: [count == Self.total ? "\(count) matches" : "\(count) matches so far", timing],
        systemImage: "magnifyingglass", hue: .orange, status: count == Self.total ? .idle : .working()
      ) {
        ForEach(0..<count, id: \.self) { index in
          LongSectionRow(index: index)
        }
      }
    }
    .task {
      started = .now
      while count < Self.total {
        count += Self.batch
        // A search hands its results over as it goes; the next batch comes once this one is on screen.
        try? await Task.sleep(for: .milliseconds(30))
      }
      took = .now - started
    }
  }

  private var timing: String {
    guard let took else { return "streaming…" }
    return "streamed in \(took.formatted(.units(allowed: [.seconds, .milliseconds], width: .narrow)))"
  }
}

/// A file's row every 25 rows, its matches under it.
private struct LongSectionRow: View {
  let index: Int

  var body: some View {
    if index % 25 == 0 {
      SidebarRow(value: index, "Sources/Feature\(index / 25)/View\(index / 25).swift", systemImage: "swift") {
        Count(24)
      }
    } else {
      SidebarRow(value: index, "\(index % 25 * 7): let match = search(\"needle\", in: line\(index))", systemImage: "text.magnifyingglass")
    }
  }
}
