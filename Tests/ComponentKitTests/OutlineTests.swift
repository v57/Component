import SwiftUI
import Testing

@testable import ComponentKit

private struct Node: Identifiable {
  let id: String
  var children: [Node]?
}

private let tree = [
  Node(id: "a", children: [Node(id: "a1", children: nil), Node(id: "a2", children: [Node(id: "a2x", children: nil)])]),
  Node(id: "b", children: nil),
  Node(id: "c", children: []),
]

/// The open tree is one flat list, depth first, each row with its level (a stack finds the nth row at once).
@MainActor @Test func outlineFlattensTheOpenTree() {
  var open: Set<String> = ["a", "a2"]
  let expansion = ContOutlineExpansion.expanded(Binding(get: { open }, set: { open = $0 }))
  let keys = ContOutlineKeys<String>()
  let rows = ContOutlineEntry.flatten(tree, children: \.children, expansion: expansion, level: 0, keys: keys)
  #expect(rows.map(\.item.id) == ["a", "a1", "a2", "a2x", "b", "c"])
  #expect(rows.map(\.level) == [0, 1, 1, 2, 0, 0])
  #expect(rows.map(\.isLeaf) == [false, true, false, true, true, false])
}

/// A row keeps its key when folders open and close around it, so it keeps its identity; keys are small numbers.
@MainActor @Test func outlineKeysStayWithTheirItems() {
  var open: Set<String> = []
  let expansion = ContOutlineExpansion.expanded(Binding(get: { open }, set: { open = $0 }))
  let keys = ContOutlineKeys<String>()
  let closed = ContOutlineEntry.flatten(tree, children: \.children, expansion: expansion, level: 0, keys: keys)
  open = ["a", "a2"]
  let opened = ContOutlineEntry.flatten(tree, children: \.children, expansion: expansion, level: 0, keys: keys)
  let before = Dictionary(uniqueKeysWithValues: closed.map { ($0.item.id, $0.key) })
  for row in opened where before[row.item.id] != nil { #expect(row.key == before[row.item.id]) }
  #expect(Set(opened.map(\.key)) == Set(0..<opened.count))
}

/// An outline of 5,000 open rows flattens quickly (its body runs whenever a folder opens).
@MainActor @Test func outlineFlattensThousandsOfRowsQuickly() {
  let big = (0..<50).map { folder in
    Node(id: "f\(folder)", children: (0..<100).map { Node(id: "f\(folder)/\($0)", children: nil) })
  }
  let open = Set(big.map(\.id))
  let expansion = ContOutlineExpansion.expanded(.constant(open))
  let keys = ContOutlineKeys<String>()
  let clock = ContinuousClock()
  let elapsed = clock.measure {
    for _ in 0..<10 {
      _ = ContOutlineEntry.flatten(big, children: \.children, expansion: expansion, level: 0, keys: keys)
    }
  }
  #expect(elapsed < .milliseconds(500), "10 flattens of 5,050 rows took \(elapsed)")
}
