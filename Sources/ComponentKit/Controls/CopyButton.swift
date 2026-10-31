import SwiftUI

/// A button that copies text and says so: its label turns to a green check and "Copied" for a moment, then back.
/// Style it as any button (`.buttonStyle(.kitPlain)`, `.kit`, `.kitIcon`); `isSecret` copies with
/// `KitPasteboard.copySecret` (kept off other devices, cleared after 90 seconds).
///
/// ```swift
/// KitCopyButton(value: command).buttonStyle(.kitPlain)
/// KitCopyButton("Copy Code", value: code.userCode).buttonStyle(.kit)
/// KitCopyButton("Copy Password", systemImage: "key", value: password, isSecret: true).buttonStyle(.kitIcon)
/// ```
///
/// When the app copies the value itself (a sign-in code copied as it arrives), `copiedWhen` says so: each time it
/// changes to a new non-nil value, and when the button appears with one, the button shows "Copied" as if pressed,
/// without copying again.
///
/// ```swift
/// KitCopyButton("Copy Code", value: code?.userCode ?? "", copiedWhen: code?.userCode).buttonStyle(.kit)
/// ```
public struct KitCopyButton: View {
  var title: String
  var systemImage: String?
  var copiedTitle: String
  var value: () -> String
  var isSecret: Bool
  var copiedWhen: AnyHashable?
  @State private var copied = 0
  @State private var showsCopied = false

  /// `value` is read when the button is pressed. `copiedWhen`: the app copied the value itself; the button shows
  /// "Copied" when it appears with it and each time it changes to another non-nil value.
  public init(
    _ title: String = "Copy", systemImage: String? = nil, copiedTitle: String = "Copied",
    value: @autoclosure @escaping () -> String, isSecret: Bool = false, copiedWhen: AnyHashable? = nil
  ) {
    self.title = title
    self.systemImage = systemImage
    self.copiedTitle = copiedTitle
    self.value = value
    self.isSecret = isSecret
    self.copiedWhen = copiedWhen
  }

  public var body: some View {
    Button {
      if isSecret { KitPasteboard.copySecret(value()) } else { KitPasteboard.copy(value()) }
      copied += 1
    } label: {
      Label {
        if showsCopied {
          Text(copiedTitle).foregroundStyle(Hue.green.text)
        } else {
          Text(title)
        }
      } icon: {
        if showsCopied {
          Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Hue.green.text)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
        } else if let systemImage {
          Image(systemName: systemImage)
        }
      }
    }
    .accessibilityLabel(showsCopied ? copiedTitle : title)
    .onChange(of: copiedWhen, initial: true) { _, trigger in
      if trigger != nil { copied += 1 }
    }
    .task(id: copied) {
      guard copied > 0 else { return }
      withKitAnimation { showsCopied = true }
      await kitSleep(for: .seconds(1.8))
      guard !Task.isCancelled else { return }
      withKitAnimation { showsCopied = false }
    }
  }
}
