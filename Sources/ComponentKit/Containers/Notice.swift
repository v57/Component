import SwiftUI

// MARK: - Notice

extension View {
  /// Tells the reader something that needs no decision (an error, what a finished job did), as a kit sheet: the
  /// still header with the message wrapping under the title, and a footer with OK (Return and Escape close it). It is
  /// `kitConfirmation`'s sheet with one button, in place of an `.alert` with only OK; on the Mac and iPad it is the
  /// kit's overlay (it stacks over a sheet it is shown from), on iPhone a system sheet. Closing it sets
  /// `isPresented` to false, so clear the error in the binding's setter.
  ///
  /// The message can be selected and copied. A long one (several lines, or past a few sentences: a tool's output)
  /// goes in the sheet's body, which scrolls, instead of under the title.
  ///
  /// ```swift
  /// .kitNotice("Couldn't save the catalog", isPresented: hasError, message: error?.localizedDescription)
  /// .kitNotice("Moved 3 items to the Trash", isPresented: $showsReport, systemImage: "trash", hue: .green,
  ///            buttons: [KitConfirmationButton("Open Trash") { openTrash() }])
  /// ```
  ///
  /// - Parameter buttons: more ways out before OK ("Open Trash"), each closing the notice after its action. One
  ///   marked `isDefault` takes Return and is drawn filled; OK then is plain (and takes Escape).
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

  /// A notice shown while `message` holds text (an error string the model sets): OK, Escape or any button clears it
  /// to `nil`. The rest is the `isPresented:` notice's.
  ///
  /// ```swift
  /// .kitNotice("Couldn't Complete the Action", message: $actions.error)
  /// .kitNotice("Couldn't Play the Video", message: $player.errorMessage, hue: .red)
  /// .kitNotice("Read-Only Folder", message: $readOnlyMessage, systemImage: "lock",
  ///            buttons: [KitConfirmationButton("Allow Editing…") { allowEditing() }])
  /// ```
  public func kitNotice(
    _ title: String, message: Binding<String?>, systemImage: String = "exclamationmark.triangle",
    hue: Hue = .orange, buttons: [KitConfirmationButton] = []
  ) -> some View {
    let isPresented = Binding(
      get: { message.wrappedValue != nil },
      set: { if !$0 { message.wrappedValue = nil } })
    return kitSheet(isPresented: isPresented) {
      ContNotice(
        title: title, message: message.wrappedValue, systemImage: systemImage, hue: hue, buttons: buttons,
        dismiss: { message.wrappedValue = nil })
    }
  }

  /// A notice for an item (a failure with its own title and message), shown while `item` isn't nil; OK, Escape or
  /// any button sets it back to `nil`. `buttons` may depend on the item (Grant Access… for one kind of failure).
  ///
  /// ```swift
  /// .kitNotice(item: $session.failure, title: \.title, message: \.message)
  /// .kitNotice(item: $session.failure, title: \.title, message: \.message) { failure in
  ///   failure.needsWorkflowScope ? [KitConfirmationButton("Grant Access…", isDefault: true) { grant() }] : []
  /// }
  /// ```
  public func kitNotice<Item: Identifiable>(
    item: Binding<Item?>, title: @escaping (Item) -> String, message: @escaping (Item) -> String?,
    systemImage: String = "exclamationmark.triangle", hue: Hue = .orange,
    buttons: @escaping (Item) -> [KitConfirmationButton] = { _ in [] }
  ) -> some View {
    kitSheet(item: item) { value in
      ContNotice(
        title: title(value), message: message(value), systemImage: systemImage, hue: hue, buttons: buttons(value),
        dismiss: { item.wrappedValue = nil })
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

  /// A message too long for the header: it goes in the body, which scrolls.
  static func isLong(_ message: String?) -> Bool {
    guard let message else { return false }
    return message.contains("\n") || message.count > 240
  }

  var body: some View {
    if Self.isLong(message), let message {
      sheet(meta: nil) {
        Text(message)
          .kitFont(.callout)
          .foregroundStyle(.kitSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 8)
      }
    } else {
      sheet(meta: message) { EmptyView() }
    }
  }

  private func sheet<Content: View>(meta: String?, @ViewBuilder content: () -> Content) -> some View {
    var sheet = KitSheet(
      title: title, meta: meta, width: buttons.isEmpty && Content.self == EmptyView.self ? 380 : 440,
      icon: { LiveIcon(systemImage: systemImage, hue: hue, status: .idle, size: 32) },
      content: content,
      footer: { footer })
    sheet.topAligned = true
    return sheet.textSelection(.enabled)
  }

  @ViewBuilder private var footer: some View {
    let defaultID = buttons.first { $0.isDefault }?.id
    ForEach(buttons) { button in
      if button.id == defaultID {
        Button(button.title, role: button.role) {
          button.action()
          dismiss()
        }
        .buttonStyle(.kitPrimary)
        .keyboardShortcut(.defaultAction)
      } else {
        Button(button.title, role: button.role) {
          button.action()
          dismiss()
        }
      }
    }
    if defaultID == nil {
      Button("OK") { dismiss() }
        .buttonStyle(.kitPrimary)
        .keyboardShortcut(.defaultAction)
    } else {
      Button("OK") { dismiss() }
        .keyboardShortcut(.cancelAction)
    }
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
