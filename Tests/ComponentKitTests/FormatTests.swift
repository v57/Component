import Foundation
import SwiftUI
import Testing

@testable import ComponentKit

@Test func flowCentresAndTrailsEachLine() {
  let sizes = [CGSize(width: 40, height: 10), CGSize(width: 40, height: 10), CGSize(width: 40, height: 10)]
  let centred = KitFlow.frames(sizes, maxWidth: 100, spacing: 10, lineSpacing: 4, alignment: 0.5)
  // Line one: 40 + 10 + 40 = 90 wide, 5 free on each side; line two: one item, 30 on each side.
  #expect(centred[0].minX == 5)
  #expect(centred[1].minX == 55)
  #expect(centred[2].origin == CGPoint(x: 30, y: 14))
  let trailing = KitFlow.frames(sizes, maxWidth: 100, spacing: 10, lineSpacing: 4, alignment: 1)
  #expect(trailing[2].minX == 60)
}

@Test func hexColoursParseShortLongAndAlpha() {
  #expect(RGBA(hex: "#ff3b30") == RGBA(0xff3b30))
  #expect(RGBA(hex: " fff ") == RGBA(0xffffff))
  #expect(RGBA(hex: "#00000080") == RGBA(0x000000, 128.0 / 255))
  #expect(RGBA(hex: "#12345") == nil)
  #expect(RGBA(hex: "+12345") == nil)
  #expect(RGBA(hex: "zzzzzz") == nil)
}

@Test func datesReadNextToNow() {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  #expect(now.addingTimeInterval(-20).kitFormatted(.ago, relativeTo: now) == "just now")
  #expect(now.addingTimeInterval(-180).kitFormatted(.ago, relativeTo: now) == "3 min ago")
  #expect(now.addingTimeInterval(-7_200).kitFormatted(.ago, relativeTo: now) == "2 hr ago")
  #expect(now.addingTimeInterval(-3 * 86_400).kitFormatted(.ago, relativeTo: now) == "3 days ago")
  #expect(now.addingTimeInterval(-20).kitFormatted(.clock, relativeTo: now) == "now")
  #expect(now.kitFormatted(.day, relativeTo: now) == "Today")
  #expect(now.addingTimeInterval(-86_400).kitFormatted(.day, relativeTo: now) == "Yesterday")
  #expect(now.addingTimeInterval(-2_520).kitFormatted(.elapsed, relativeTo: now) == "42 min")
}

@Test func durationsRoundAsSaid() {
  #expect(KitDuration.format(42, seconds: true) == "42 s")
  #expect(KitDuration.format(125, seconds: true) == "2 min 5 s")
  #expect(KitDuration.format(20) == "1 min")
  #expect(KitDuration.format(3 * 3600) == "3 h")
  #expect(KitDuration.format(3600 + 1200) == "1 h 20 min")
  #expect(KitDuration.format(3 * 86_400) == "3 d")
  #expect(KitDuration.timeLeft(25) == "less than a minute left")
  #expect(KitDuration.timeLeft(200) == "about 3 min left")
  #expect(KitDuration.timeLeft(4_900) == "about 1 h 20 min left")
}
