import CoreGraphics
import Testing

@testable import ComponentKit

@Suite struct PreviewCardTests {
  @Test func aCardSettlesInTheCornerItWasDraggedTo() {
    let corner = KitPreviewCorner.bottomTrailing
    // A short drag stays where it was.
    #expect(corner.moved(by: CGSize(width: -40, height: -30)) == .bottomTrailing)
    // Past 80pt along an axis it changes side on that axis only.
    #expect(corner.moved(by: CGSize(width: -200, height: -10)) == .bottomLeading)
    #expect(corner.moved(by: CGSize(width: 10, height: -300)) == .topTrailing)
    #expect(corner.moved(by: CGSize(width: -200, height: -300)) == .topLeading)
    // And back.
    #expect(KitPreviewCorner.topLeading.moved(by: CGSize(width: 200, height: 300)) == .bottomTrailing)
    // Right to left, trailing is the left side.
    #expect(corner.moved(by: CGSize(width: 200, height: 0), isRightToLeft: true) == .bottomLeading)
  }

  @Test func aPictureFitsItsRoomAtItsShape() {
    let fit = KitPreviewScreen<Never>.fit(CGSize(width: 402, height: 874), in: CGSize(width: 300, height: 300))
    #expect(fit.height == 300)
    #expect(fit.width == 137)
    #expect(KitPreviewScreen<Never>.fit(.zero, in: CGSize(width: 10, height: 10)) == .zero)
  }
}
