import SwiftUI
import Testing

@testable import ComponentKit

// MARK: - Overlay host

@MainActor
private func entry(_ id: UUID, style: KitOverlayStyle = .sheet, dismiss: @escaping @MainActor () -> Void = {})
  -> KitOverlayHost.Entry
{
  KitOverlayHost.Entry(id: id, style: style, content: KitOverlayContent(), dismiss: dismiss)
}

/// Waits until `done` holds, up to two seconds (other tests share the main actor).
@MainActor
private func eventually(_ done: () -> Bool) async throws {
  for _ in 0..<100 where !done() { try await Task.sleep(for: .milliseconds(20)) }
}

@MainActor @Test func overlaysStackInTheOrderTheyOpen() {
  let host = KitOverlayHost()
  let sheet = UUID()
  let confirmation = UUID()
  #expect(!host.isShowing)
  host.present(entry(sheet))
  host.present(entry(confirmation))
  #expect(host.entries.map(\.id) == [sheet, confirmation])
  #expect(host.top == confirmation)
  #expect(host.isShowing)
}

@MainActor @Test func presentingAgainUpdatesInPlace() {
  let host = KitOverlayHost()
  let sheet = UUID()
  let confirmation = UUID()
  host.present(entry(sheet))
  host.present(entry(confirmation))
  host.present(entry(sheet, style: .palette(width: 560)))
  #expect(host.entries.map(\.id) == [sheet, confirmation])
  #expect(host.entries[0].style == .palette(width: 560))
  #expect(host.top == confirmation)
}

@MainActor @Test func aClosingOverlayFadesOutBeforeItGoes() async throws {
  let host = KitOverlayHost()
  let sheet = UUID()
  let confirmation = UUID()
  host.present(entry(sheet))
  host.present(entry(confirmation))
  host.remove(confirmation)
  // Still drawn while it fades, but the sheet under it takes the keys again.
  #expect(host.entries.count == 2)
  #expect(host.entries[1].isClosing)
  #expect(host.top == sheet)
  try await eventually { host.entries.count == 1 }
  #expect(host.entries.map(\.id) == [sheet])
}

@MainActor @Test func reopeningWhileClosingKeepsTheOverlay() async throws {
  let host = KitOverlayHost()
  let sheet = UUID()
  host.present(entry(sheet))
  host.remove(sheet)
  #expect(!host.isShowing)
  host.present(entry(sheet))
  try await Task.sleep(for: KitOverlayHost.fadeOut * 3)
  #expect(host.entries.map(\.id) == [sheet])
  #expect(host.top == sheet)
}

@MainActor @Test func removingWithoutAnimationIsImmediate() {
  let host = KitOverlayHost()
  let sheet = UUID()
  host.present(entry(sheet))
  host.remove(sheet, animated: false)
  #expect(host.entries.isEmpty)
  host.remove(UUID())
  #expect(host.entries.isEmpty)
}

@MainActor @Test func overlayContentBuildsEnabledOnlyOnTop() {
  let content = KitOverlayContent()
  var built: [Bool] = []
  content.set { isEnabled in
    built.append(isEnabled)
    return AnyView(EmptyView())
  }
  let version = content.version
  _ = content.make(true)
  _ = content.make(false)
  #expect(built == [true, false])
  content.set { _ in AnyView(EmptyView()) }
  #expect(content.version == version + 1)
}

@MainActor @Test func overlayContentUpdatesCoalesce() async throws {
  let content = KitOverlayContent()
  let version = content.version
  content.update { _ in AnyView(EmptyView()) }
  content.update { _ in AnyView(EmptyView()) }
  content.update { _ in AnyView(EmptyView()) }
  #expect(content.version == version)
  try await eventually { content.version != version }
  #expect(content.version == version + 1)
}

@MainActor @Test func kitDismissRunsItsHandler() {
  var dismissed = 0
  let dismiss = KitDismissAction { dismissed += 1 }
  dismiss()
  #expect(dismissed == 1)
  // Outside a kit presentation it does nothing.
  EnvironmentValues().kitDismiss()
}
