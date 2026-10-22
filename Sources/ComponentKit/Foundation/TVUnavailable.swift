import SwiftUI
import UniformTypeIdentifiers

// Apple TV lacks a few modifiers the kit uses on every other platform: keyboard shortcuts, swipe actions, drag and
// drop, hover, text selection. On tvOS these stand in for them and do nothing, so the components build unchanged (the
// compiler prefers an available declaration to SwiftUI's unavailable one). What they did has no TV equivalent: the
// remote has no keys to bind, no swipe on a row, nothing to drag, no pointer to hover. The modifiers are public, so an
// app's views shared with the Mac build for Apple TV as they are.

#if os(tvOS)
  /// Stands in for SwiftUI's, which tvOS lacks, so `.keyboardShortcut(.defaultAction)` still builds.
  public struct KeyboardShortcut: Hashable, Sendable {
    public static let defaultAction = KeyboardShortcut()
    public static let cancelAction = KeyboardShortcut()
    init() {}
    public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command) {}
  }

  /// Stands in for SwiftUI's text selectability: nothing on screen can be selected on Apple TV.
  public enum TVTextSelection { case enabled, disabled }

  /// Drag and drop: the kit's reorderable lists keep their drop delegates; on Apple TV nothing ever drops.
  struct DropInfo {
    var location: CGPoint { .zero }
    func hasItemsConforming(to contentTypes: [UTType]) -> Bool { false }
    func itemProviders(for contentTypes: [UTType]) -> [NSItemProvider] { [] }
  }

  enum DropOperation { case cancel, forbidden, copy, move }

  struct DropProposal {
    var operation: DropOperation
    init(operation: DropOperation) { self.operation = operation }
  }

  @MainActor protocol DropDelegate {
    func validateDrop(info: DropInfo) -> Bool
    func performDrop(info: DropInfo) -> Bool
    func dropEntered(info: DropInfo)
    func dropUpdated(info: DropInfo) -> DropProposal?
    func dropExited(info: DropInfo)
  }

  extension DropDelegate {
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropEntered(info: DropInfo) {}
    func dropUpdated(info: DropInfo) -> DropProposal? { nil }
    func dropExited(info: DropInfo) {}
  }

  /// Apple TV stand-ins for SwiftUI's modifiers that tvOS lacks: they do nothing (a popover is a sheet).
  extension View {
    public func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View { self }
    public func keyboardShortcut(_ shortcut: KeyboardShortcut) -> some View { self }
    public func keyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View { self }

    public func swipeActions<T: View>(
      edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> T
    ) -> some View { self }

    public func dropDestination<T: Transferable>(
      for payloadType: T.Type = T.self, action: @escaping ([T], CGPoint) -> Bool,
      isTargeted: @escaping (Bool) -> Void = { _ in }
    ) -> some View { self }

    public func listRowSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View { self }
    public func scrollContentBackground(_ visibility: Visibility) -> some View { self }

    func onDrop(of supportedContentTypes: [UTType], delegate: some DropDelegate) -> some View { self }
    func onDrag(_ data: @escaping () -> NSItemProvider, @ViewBuilder preview: () -> some View) -> some View { self }
    func onDrag(_ data: @escaping () -> NSItemProvider) -> some View { self }
    public func draggable<T: Transferable>(_ payload: @autoclosure @escaping () -> T) -> some View { self }
    public func draggable<T: Transferable>(_ payload: @autoclosure @escaping () -> T, @ViewBuilder preview: () -> some View)
      -> some View
    { self }

    /// No popovers on Apple TV: the content comes up as a sheet.
    public func popover<C: View>(
      isPresented: Binding<Bool>, arrowEdge: Edge? = nil, @ViewBuilder content: @escaping () -> C
    ) -> some View {
      sheet(isPresented: isPresented, content: content)
    }

    public func textSelection(_ selectability: TVTextSelection) -> some View { self }

    /// No pointer on Apple TV: focus lights views instead (`kitHoverEffect`).
    public func onHover(perform action: @escaping (Bool) -> Void) -> some View { self }
  }
#endif
