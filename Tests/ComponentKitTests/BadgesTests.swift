import Testing

@testable import ComponentKit

@Test func diffstatBlocks() {
  #expect(Diffstat.blocks(added: 0, removed: 0) == (0, 0))
  #expect(Diffstat.blocks(added: 12, removed: 3) == (4, 1))
  #expect(Diffstat.blocks(added: 38, removed: 0) == (5, 0))
  #expect(Diffstat.blocks(added: 0, removed: 120) == (0, 5))
  #expect(Diffstat.blocks(added: 54, removed: 122) == (2, 3))
  // Fewer than five lines colour fewer blocks.
  #expect(Diffstat.blocks(added: 2, removed: 2) == (2, 2))
  #expect(Diffstat.blocks(added: 1, removed: 0) == (1, 0))
  // A side that changed keeps a block, however lopsided.
  #expect(Diffstat.blocks(added: 1000, removed: 1) == (4, 1))
  #expect(Diffstat.blocks(added: 1, removed: 1000) == (1, 4))
}

@Test func refsArrangedInKitOrder() {
  let refs: [RefChip.Ref] = [
    .init(name: "origin/feature/maps", kind: .remote),
    .init(name: "v1.12.0", kind: .tag),
    .init(name: "release/2026.10"),
    .init(name: "main", isCurrent: true),
    .init(name: "v1.11.0", kind: .tag),
  ]
  #expect(RefChip.Ref.arranged(refs).map(\.name) == ["main", "release/2026.10", "v1.12.0", "v1.11.0", "origin/feature/maps"])
}

@Test func refsFoldUpstream() {
  let refs: [RefChip.Ref] = [
    .init(name: "origin/main", kind: .remote),
    .init(name: "main", isCurrent: true),
    .init(name: "origin/other", kind: .remote),
  ]
  let arranged = RefChip.Ref.arranged(refs)
  #expect(arranged.map(\.name) == ["main", "origin/other"])
  #expect(arranged[0].hasUpstream)
  #expect(!arranged[1].hasUpstream)
}

@Test func refNamespace() {
  let remote = RefChip.Ref(name: "origin/feature/offline-maps", kind: .remote)
  #expect(remote.parts.namespace == "origin/")
  #expect(remote.parts.name == "feature/offline-maps")
  #expect(RefChip.Ref(name: "feature/x").parts.namespace == "")
}

@Test func refChipsLayouts() {
  #expect(RefChips.layouts(count: 4, maxVisible: 2) == [2, 1, 0])
  #expect(RefChips.layouts(count: 1, maxVisible: 2) == [1, 0])
  #expect(RefChips.layouts(count: 4, maxVisible: 1) == [1, 0])
  #expect(RefChips.chipCap(maxVisible: 2) == 168)
  #expect(RefChips.chipCap(maxVisible: 1) == 128)
}

@Test func avatarLetters() {
  #expect(Avatar.initials("Maya Okafor") == "MO")
  #expect(Avatar.initials("coder-1") == "C1")
  #expect(Avatar.initials("artist") == "A")
  #expect(Avatar.initials("") == "?")
  #expect(Avatar.letter("atlas") == "A")
  #expect(Avatar.letter(".dotfiles") == "D")
}

@Test func syncLabel() {
  #expect(SyncCounts.label(changes: 0, ahead: 0, behind: 0) == "Up to date")
  #expect(SyncCounts.label(changes: 3, ahead: 2, behind: 1) == "3 changed, 2 to push, 1 to pull")
}

@Test func statusHues() {
  #expect(Hue.forStatus("Shipped") == .green)
  #expect(Hue.forStatus("pending") == .orange)
  #expect(Hue.forStatus("failed") == .red)
  #expect(Hue.forStatus("whatever") == nil)
  #expect(Hue.forTypeName("int32") == .purple)
  #expect(Hue.forTypeName("geometry") == .gray)
}

@Test func microBarClamps() {
  #expect(MicroBar.clamped(1.4) == 1)
  #expect(MicroBar.clamped(-1) == 0)
  #expect(MicroBar.clamped(.nan) == 0)
}

// MARK: - Progress bar

@Test func progressBarFillWidth() {
  #expect(KitProgressBar.fillWidth(0, in: 200, height: 4) == 0)
  #expect(KitProgressBar.fillWidth(0.5, in: 200, height: 4) == 100)
  // A sliver still shows as a dot; past the end stops at the end; NaN is empty.
  #expect(KitProgressBar.fillWidth(0.001, in: 200, height: 4) == 4)
  #expect(KitProgressBar.fillWidth(1.4, in: 200, height: 4) == 200)
  #expect(KitProgressBar.fillWidth(.nan, in: 200, height: 4) == 0)
}
