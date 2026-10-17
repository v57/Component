import ComponentKit
import SwiftUI

/// What a long page usually is: one card repeated from a `ForEach`, here 500 repositories as section cards with
/// their branch rows, counts, chips and a progress bar, in the page's lazy stack.
struct LongListPage: View {
  @MainActor private static let repos: [LongRepo] = (0..<500).map { LongRepo($0) }

  var body: some View {
    CatalogPage(page: .longList, maxWidth: 720) {
      ForEach(Self.repos) { repo in
        LongRepoCard(repo: repo)
      }
    }
  }
}

/// A made-up repository for the long list.
struct LongRepo: Identifiable {
  let id: Int
  let name: String
  let hue: Hue
  let branches: [(name: String, changes: Int, ahead: Int, behind: Int)]
  let progress: Double?

  init(_ index: Int) {
    let names = ["atlas", "beacon", "harbor", "pebble", "lighthouse", "meadow", "quarry", "summit", "tundra", "willow"]
    let hues: [Hue] = [.blue, .green, .orange, .purple, .teal, .pink, .indigo, .red]
    id = index
    name = "\(names[index % names.count])-\(index)"
    hue = hues[index % hues.count]
    branches = (0..<(2 + index % 3)).map { b in
      (["main", "feature/maps", "release/1.\(b)", "fix/crash-\(index)"][b % 4], (index + b) % 5, b % 3, (index * b) % 4)
    }
    progress = index % 4 == 0 ? Double(index % 10) / 10 : nil
  }
}

struct LongRepoCard: View {
  let repo: LongRepo

  var body: some View {
    KitSection(
      repo.name, meta: [repo.branches[0].name, "\(repo.branches.count) branches"], systemImage: "shippingbox",
      hue: repo.hue
    ) {
      ForEach(repo.branches.indices, id: \.self) { index in
        let branch = repo.branches[index]
        SidebarRow(value: "\(repo.id)-\(index)", branch.name, systemImage: "arrow.triangle.branch") {
          HStack(spacing: 6) {
            if index == 0 { Chip(status: "Current") }
            SyncCounts(changes: branch.changes, ahead: branch.ahead, behind: branch.behind)
          }
        }
      }
      if let progress = repo.progress {
        KitProgressBar(value: progress).padding(.horizontal, 10).padding(.vertical, 6)
      }
    }
  }
}
