import SwiftUI

// Hover that holds still under a drag: as a dragged row passes over the window, the views under the pointer would
// light up and go out one after another.

/// Whether a kit row drag is under way (any list's), so hover effects hold still.
@MainActor @Observable
final class ContDragActivity {
  static let shared = ContDragActivity()
  var isDragging = false
}

extension View {
  /// `onHover` for the kit's views: under a row drag the pointer counts as away, so nothing lights up as the drag
  /// passes.
  func kitHover(perform action: @escaping (Bool) -> Void) -> some View {
    modifier(ContHover(action: action))
  }
}

private struct ContHover: ViewModifier {
  let action: (Bool) -> Void

  func body(content: Content) -> some View {
    let isDragging = ContDragActivity.shared.isDragging
    content
      .onHover { action($0 && !ContDragActivity.shared.isDragging) }
      .onChange(of: isDragging) { _, dragging in if dragging { action(false) } }
  }
}
