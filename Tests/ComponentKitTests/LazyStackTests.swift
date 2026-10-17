import Combine
import SwiftUI
import Testing

@testable import ComponentKit

// MARK: - Lazy stack

/// Thousands of rows streamed into one stack in batches (Code's Find with 3,500 matches), the rows on screen measuring
/// as they come with uneven heights, then scrolled through: planning stays quick, and the placeholders far from the
/// screen aren't drawn again on every plan (each of their changes is a redraw).
@MainActor @Test func lazyStackPlansThousandsOfRowsQuickly() {
  let model = ContLazyModel()
  model.update(ContLazyWindow(top: 0, bottom: 832, height: 832))
  var redraws = 0
  var subscriptions: [AnyCancellable] = []
  let clock = ContinuousClock()
  let start = clock.now
  var ids: [AnyHashable] = []
  for batch in 0..<20 {
    let new = (batch * 250..<(batch + 1) * 250).map(AnyHashable.init)
    ids += new
    // Each row's view subscribes to its flag, as SwiftUI does.
    for id in new { subscriptions.append(model.flag(id).objectWillChange.sink { redraws += 1 }) }
    model.setItems(ids, spacing: 0, parent: nil)
    // The rows on screen measure: a file's header row is taller than its matches, and grows batch by batch.
    for index in 0..<min(ids.count, 60) {
      model.measured(ids[index], index % 8 == 0 ? 40 + CGFloat(batch * 4) : 22)
    }
    model.plan()
  }
  // Scrolling down the list half a screen at a time plans again each step.
  for step in 0..<200 {
    let top = CGFloat(step) * 400
    model.update(ContLazyWindow(top: top, bottom: top + 832, height: 832))
  }
  let elapsed = clock.now - start
  print("lazy stack: \(elapsed), \(redraws) redraws")
  #expect(elapsed < .seconds(1), "planning 5,000 rows took \(elapsed)")
  #expect(redraws < 2 * ids.count, "\(redraws) placeholder redraws for \(ids.count) rows")
}
