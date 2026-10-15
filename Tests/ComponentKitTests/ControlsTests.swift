import SwiftUI
import Testing

@testable import ComponentKit

@Test func flowWrapsBeforeTheItemThatWouldOverflow() {
  let sizes = [CGSize(width: 40, height: 24), CGSize(width: 40, height: 24), CGSize(width: 40, height: 20)]
  let frames = CtlFlow.frames(sizes, maxWidth: 90, spacing: 2, lineSpacing: 6)
  #expect(frames[0] == CGRect(x: 0, y: 0, width: 40, height: 24))
  #expect(frames[1] == CGRect(x: 42, y: 0, width: 40, height: 24))
  // 42 + 40 + 2 + 40 = 124 > 90: the third item starts a line, centred on its own height.
  #expect(frames[2] == CGRect(x: 0, y: 30, width: 40, height: 20))
  #expect(CtlFlow.size(of: frames) == CGSize(width: 82, height: 50))
}

@Test func flowKeepsOneLineWithoutAWidthAndCentresShortItems() {
  let sizes = [CGSize(width: 30, height: 20), CGSize(width: 50, height: 10)]
  let frames = CtlFlow.frames(sizes, maxWidth: nil, spacing: 14, lineSpacing: 6)
  #expect(frames[1] == CGRect(x: 44, y: 5, width: 50, height: 10))
  #expect(CtlFlow.frames([], maxWidth: 100, spacing: 2, lineSpacing: 2).isEmpty)
}

@Test func flowNeverLeavesAWideItemAlone() {
  // An item wider than the line still goes on the first line rather than leaving an empty one.
  let frames = CtlFlow.frames([CGSize(width: 120, height: 10)], maxWidth: 100, spacing: 2, lineSpacing: 2)
  #expect(frames[0].origin == .zero)
}

@Test func segmentNavigationSkipsDisabledAndWraps() {
  let enabled = [true, true, false, true]
  #expect(CtlSegmentNavigation.next(from: 1, by: 1, enabled: enabled) == 3)
  #expect(CtlSegmentNavigation.next(from: 3, by: 1, enabled: enabled) == 0)
  #expect(CtlSegmentNavigation.next(from: 0, by: -1, enabled: enabled) == 3)
  #expect(CtlSegmentNavigation.next(from: 0, by: 1, enabled: [true]) == nil)
  #expect(CtlSegmentNavigation.next(from: 0, by: 1, enabled: []) == nil)
}

@Test func stepperClampsToItsRange() {
  #expect(CtlStepperMath.stepped(13, by: 1, up: true, in: 9...24) == 14)
  #expect(CtlStepperMath.stepped(24, by: 1, up: true, in: 9...24) == 24)
  #expect(CtlStepperMath.stepped(9.5, by: 1, up: false, in: 9.0...24.0) == 9)
  #expect(CtlStepperMath.stepped(0.5, by: 0.25, up: true, in: 0.5...2) == 0.75)
}

@Test func numbersReadAsTheKitShowsThem() {
  let us = Locale(identifier: "en_US")
  #expect(CtlNumberText.string(13, locale: us) == "13")
  #expect(CtlNumberText.string(13.0, locale: us) == "13")
  #expect(CtlNumberText.string(0.25, locale: us) == "0.25")
  #expect(CtlNumberText.string(1.5 as Float, locale: us) == "1.5")
  #expect(CtlNumberText.string(12_000, locale: us) == "12000")
  #expect(CtlNumberText.string(0.25, locale: Locale(identifier: "de_DE")) == "0,25")
}

@Test func sliderMapsValuesInsideTheTrack() {
  #expect(CtlSliderMath.fraction(140, in: 50...200) == 0.6)
  #expect(CtlSliderMath.fraction(-1, in: 0...1) == 0)
  #expect(CtlSliderMath.fraction(1, in: 1...1) == 0)
  // The knob's centre travels from half a knob in to half a knob from the end.
  #expect(CtlSliderMath.knobCenter(fraction: 0, width: 124, knobWidth: 24) == 12)
  #expect(CtlSliderMath.knobCenter(fraction: 1, width: 124, knobWidth: 24) == 112)
  #expect(CtlSliderMath.fraction(atX: 62, width: 124, knobWidth: 24) == 0.5)
  #expect(CtlSliderMath.fraction(atX: 0, width: 124, knobWidth: 24) == 0)
  #expect(CtlSliderMath.fraction(atX: 500, width: 124, knobWidth: 24) == 1)
}

@Test func sliderSnapsToSteps() {
  #expect(CtlSliderMath.snap(0.43, step: 0.1, in: 0...1) == 0.4)
  #expect(abs(CtlSliderMath.snap(1.38, step: 0.25, in: 0.5...2) - 1.5) < 1e-9)
  #expect(CtlSliderMath.snap(3, step: nil, in: 0...2) == 2)
  #expect(CtlSliderMath.snap(1.9, step: 1, in: 0.5...2) == 1.5)
}

@Test func keycapsSplitSymbolsFromKeys() {
  #expect(Keycaps.split("⇧⌘F") == ["⇧", "⌘", "F"])
  #expect(Keycaps.split("⌘↩") == ["⌘", "↩"])
  #expect(Keycaps.split("Tab") == ["Tab"])
  #expect(Keycaps.split("esc") == ["esc"])
  #expect(Keycaps.split("⌃ Space") == ["⌃", "Space"])
  #expect(Keycaps.spoken("⇧⌘F") == "Shift Command F")
  #expect(Keycaps.spoken("esc") == "Escape")
}

@Test func fieldStatusRingsRedWhenWrong() {
  #expect(FieldStatus.error.isError)
  #expect(FieldStatus.live(.failed("No such host")).isError)
  #expect(!FieldStatus.checking.isError)
  #expect(!FieldStatus.valid.isError)
  #expect(!FieldStatus.none.isError)
}

final class Box: @unchecked Sendable {
  var value = "pg"
}

@MainActor @Test func picksBindsOneValue() {
  let box = Box()
  let binding = Binding(get: { box.value }, set: { box.value = $0 })
  #expect(binding.picks("pg").wrappedValue)
  binding.picks("my").wrappedValue = true
  #expect(box.value == "my")
  binding.picks("pg").wrappedValue = false
  #expect(box.value == "my")
}
