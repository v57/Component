import SwiftUI

// MARK: - Notice

extension View {
  /// Tells the reader something that needs no decision (an error, what a finished job did), as a kit sheet: the
  /// still header with the message wrapping under the title, and a footer with OK (Return and Escape close it). It is
  /// `kitConfirmation`'s sheet with one button, in place of an `.alert` with only OK; on the Mac and iPad it is the
  /// kit's overlay (it stacks over a sheet it is shown from), on iPhone a system sheet. Closing it sets
  /// `isPresented` to false, so clear the error in the binding's setter.
  ///
  /// ```swift
  /// .kitNotice("Couldn't save the catalog", isPresented: hasError, message: error?.localizedDescription)
  /// .kitNotice("Moved 3 items to the Trash", isPresented: $showsReport, systemImage: "trash", hue: .green,
  ///            buttons: [KitConfirmationButton("Open Trash") { openTrash() }])
  /// ```
  ///
  /// - Parameter buttons: more ways out before OK ("Open Trash"), each closing the notice after its action.
  public func kitNotice(
    _ title: String, isPresented: Binding<Bool>, message: String? = nil,
    systemImage: String = "exclamationmark.triangle", hue: Hue = .orange, buttons: [KitConfirmationButton] = []
  ) -> some View {
    kitSheet(isPresented: isPresented) {
      ContNotice(
        title: title, message: message, systemImage: systemImage, hue: hue, buttons: buttons,
        dismiss: { isPresented.wrappedValue = false })
    }
  }
}

struct ContNotice: View {
  let title: String
  let message: String?
  let systemImage: String
  let hue: Hue
  let buttons: [KitConfirmationButton]
  let dismiss: @MainActor () -> Void

  var body: some View {
    var sheet = KitSheet(
      title: title, meta: message, width: buttons.isEmpty ? 380 : 440,
      icon: { LiveIcon(systemImage: systemImage, hue: hue, status: .idle, size: 32) },
      content: { EmptyView() },
      footer: {
        ForEach(buttons) { button in
          Button(button.title, role: button.role) {
            button.action()
            dismiss()
          }
        }
        Button("OK") { dismiss() }
          .buttonStyle(.kitPrimary)
          .keyboardShortcut(.defaultAction)
      })
    sheet.topAligned = true
    return sheet
  }
}

#Preview("Notice") {
  VStack(spacing: 24) {
    ContNotice(
      title: "Couldn't scan system folders", message: "Dev needs Full Disk Access to read /Library/Developer.",
      systemImage: "exclamationmark.triangle", hue: .orange, buttons: [], dismiss: {})
    ContNotice(
      title: "Moved 4.2 GB to the Trash", message: "12 items from 3 categories.", systemImage: "trash", hue: .green,
      buttons: [KitConfirmationButton("Open Trash") {}], dismiss: {})
  }
  .padding()
  .componentKit()
}
