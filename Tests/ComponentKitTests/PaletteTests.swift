import SwiftUI
import Testing

@testable import ComponentKit

@Test func stableHueIsStable() {
  #expect(StableHue.pick("atlas") == StableHue.pick("atlas"))
}

@Test func mixMatchesCSS() {
  let mixed = RGBA(0xff0000).mixed(with: .black(1), 0.5)
  #expect(abs(mixed.r - 0.5) < 0.001 && mixed.g == 0 && mixed.a == 1)
}

@Test func workStatusProgress() {
  #expect(WorkStatus.done.progress == 1)
  #expect(WorkStatus.working.progress == nil)
  #expect(WorkStatus.working(progress: 0.4).progress == 0.4)
}
