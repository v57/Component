import ComponentKit
import SwiftUI

// Made-up data the pages and scenarios share.

struct Repo: Identifiable, Hashable {
  var id: String { name }
  var name: String
  var branch: String
  var changes = 0
  var ahead = 0
  var behind = 0
}

let sampleRepos = [
  Repo(name: "atlas", branch: "main", changes: 4, ahead: 2),
  Repo(name: "beacon", branch: "feature/offline-maps", behind: 3),
  Repo(name: "harbor", branch: "main", changes: 1),
  Repo(name: "pebble", branch: "release/1.2"),
  Repo(name: "lighthouse", branch: "main", ahead: 1, behind: 1),
]

struct Commit: Identifiable, Hashable {
  var id: String { hash }
  var hash: String
  var message: String
  var author: String
  var date: String
  var refs: [RefChip.Ref] = []
  var added: Int
  var removed: Int
  var files: Int
}

let sampleCommits = [
  Commit(
    hash: "0dd2b54", message: "Changelog: Started 1.12", author: "Maya Okafor", date: "Today, 10:42",
    refs: [.init(name: "main", isCurrent: true), .init(name: "origin/main", kind: .remote)], added: 12, removed: 0,
    files: 1),
  Commit(
    hash: "330c484", message: "Sharing: Shared a trip as a file", author: "Rafael Silva", date: "Today, 09:15",
    refs: [.init(name: "v1.12.0-beta.3", kind: .tag), .init(name: "testflight/1.12.0-beta.3-1842", kind: .tag)],
    added: 148, removed: 22, files: 6),
  Commit(
    hash: "a91fe02", message: "TripStore: loaded trips in the background", author: "Maya Okafor",
    date: "Yesterday, 18:03", added: 54, removed: 31, files: 3),
  Commit(
    hash: "7b2c9d1", message: "Maps: prefetched the tiles along a route", author: "Aiko Tanaka", date: "Yesterday, 14:47",
    refs: [.init(name: "feature/offline-maps"), .init(name: "origin/feature/offline-maps", kind: .remote)], added: 310,
    removed: 12, files: 9),
  Commit(
    hash: "e4d0a77", message: "Fixed the date parsing for trips that cross midnight", author: "Jonas Berg",
    date: "Oct 13", added: 8, removed: 6, files: 2),
  Commit(
    hash: "19ac3f0", message: "Packing list: reordered items by dragging", author: "Rafael Silva", date: "Oct 12",
    added: 96, removed: 40, files: 4),
  Commit(
    hash: "c0ffee1", message: "Started the project", author: "Maya Okafor", date: "Oct 1",
    refs: [.init(name: "v0.1.0", kind: .tag)], added: 1204, removed: 0, files: 38),
]

struct Order: Identifiable, Hashable {
  var id: Int
  var customer: String
  var status: String
  var total: String
  var city: String?
  var note: String?
}

let sampleOrders = [
  Order(id: 10240, customer: "Maya Okafor", status: "pending", total: "128.00", city: "Lisbon", note: "Gift wrap"),
  Order(id: 10239, customer: "Rafael Silva", status: "shipped", total: "59.90", city: "Porto", note: nil),
  Order(id: 10238, customer: "Aiko Tanaka", status: "shipped", total: "312.40", city: "Tokyo", note: ""),
  Order(id: 10237, customer: "Jonas Berg", status: "refunded", total: "443.00", city: "Berlin", note: "Call before delivery"),
  Order(id: 10236, customer: "Lena Fischer", status: "refunded", total: "662.00", city: nil, note: nil),
  Order(id: 10235, customer: "Tom Hughes", status: "cancelled", total: "39.00", city: "London", note: nil),
  Order(id: 10234, customer: "Ines Costa", status: "pending", total: "136.00", city: "Lisbon", note: ""),
  Order(id: 10233, customer: "Sam Lee", status: "shipped", total: "177.00", city: "Toronto", note: "Leave at the door"),
  Order(id: 10232, customer: "Noor Haddad", status: "processing", total: "84.50", city: "Amman", note: nil),
  Order(id: 10231, customer: "Ola Nordmann", status: "shipped", total: "220.00", city: "Oslo", note: nil),
]

let sampleDiffLines: [DiffLine] = [
  DiffLine(.context, old: 23, new: 24, text: "    save()"),
  DiffLine(.context, old: 24, new: 25, text: "  }"),
  DiffLine(.added, new: 26, text: ""),
  DiffLine(.added, new: 27, text: "  /// Trips that haven't ended, soonest first."),
  DiffLine(.added, new: 28, text: "  public var upcoming: [Trip] {"),
  DiffLine(.added, new: 29, text: "    trips.filter { $0.end > .now }.sorted { $0.start < $1.start }"),
  DiffLine(.added, new: 30, text: "  }"),
  DiffLine(.removed, old: 26, text: "  private func load() {"),
  DiffLine(.removed, old: 27, text: "    guard let data = try? Data(contentsOf: url) else { return }", highlights: [4..<9]),
  DiffLine(.added, new: 32, text: "  private func load() throws {", highlights: [21..<28]),
  DiffLine(.added, new: 33, text: "    let data = try Data(contentsOf: url)"),
  DiffLine(.context, old: 28, new: 34, text: "    trips = (try? JSONDecoder().decode([Trip].self, from: data)) ?? []"),
  DiffLine(.context, old: 29, new: 35, text: "  }"),
]

let sampleBuildLog = """
  Building for debugging...
  [31/48] Compiling AtlasCore TripStore.swift
  TripStore.swift:42:9: warning: variable 'old' was never used
  [48/48] Linking Atlas
  Build complete! (21.04s)
  """

let sampleTestLog = """
  Test Suite 'TripStoreTests' started.
  TripStoreTests.swift:42: error: testUpcoming: XCTAssertEqual failed: (2) is not equal to (3)
  Executed 6 tests, with 1 failure in 0.412 seconds.
  """

let sampleNote = """
  # Trip to Lisbon

  Three days in **Lisbon** in late October, then the train to *Porto*.

  ## Packing

  - Light jacket and an umbrella
  - Walking shoes for the hills
  - Adapter (type F)

  ## Ideas

  Take tram 28 early, before the queues. Pastéis de nata at Manteigaria. Sunset at the Miradouro da Senhora do Monte.

  > The city of seven hills is best seen on foot.
  """
