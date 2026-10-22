import SwiftUI
import Testing

@testable import ComponentKit

@Test func tvIdiomDoublesTheMac() {
  #expect(!KitIdiom.tv.isTouch)
  #expect(KitIdiom.tv.scale == 2)
  #expect(KitIdiom.mac.scale == 1 && KitIdiom.pad.scale == 1 && KitIdiom.phone.scale == 1)
  #expect(KitIdiom.tv.size(32, touch: 44) == 64)
  #expect(KitIdiom.mac.size(32, touch: 44) == 32)
  #expect(KitIdiom.pad.size(32, touch: 44) == 44)
  #expect(KitIdiom.tv.size(18, pad: 28, phone: 30) == 36)
  #expect(KitIdiom.phone.size(18, pad: 28, phone: 30) == 30)
  #expect(KitMetrics.row(.tv) == 64)
  #expect(KitMetrics.rowTile(.tv) == 36)
}

/// The canvas's Apple TV board: large title 52, title 2 34, headline and body 26, caption 22.
@Test func tvTypeScale() {
  #expect(KitFont.largeTitle.pointSize(scale: 1, idiom: .tv) == 52)
  #expect(KitFont.title2.pointSize(scale: 1, idiom: .tv) == 34)
  #expect(KitFont.headline.pointSize(scale: 1, idiom: .tv) == 26)
  #expect(KitFont.body.pointSize(scale: 1, idiom: .tv) == 26)
  #expect(KitFont.caption.pointSize(scale: 1, idiom: .tv) == 22)
  #expect(KitFont.body.pointSize(scale: 1, idiom: .mac) == 13)
  #expect(KitFont.body.pointSize(scale: 1, idiom: .phone) == 17)
}
