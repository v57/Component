import SwiftUI

// The preview's picture and the guide that takes its place (the canvas's Code page, "Preview" boards, 2026-11-16);
// the card they sit in is `KitPreviewCard` (PreviewCard.swift).

/// The picture in a preview: `content` fitted to the room at `aspect`, its corners rounded as the device's
/// (`cornerFraction` of its width; a window takes about 0.03), a hairline around it. `isStale` dims it while a new
/// picture is on its way or the connection is being made again.
///
/// ```swift
/// KitPreviewScreen(aspect: screen.pixelSize, cornerFraction: 0.13, isStale: isStarting) { screenView }
/// ```
public struct KitPreviewScreen<Content: View>: View {
  var aspect: CGSize
  var cornerFraction: CGFloat
  var isStale: Bool
  @ViewBuilder var content: Content

  public init(
    aspect: CGSize, cornerFraction: CGFloat = 0.13, isStale: Bool = false, @ViewBuilder content: () -> Content
  ) {
    self.aspect = aspect
    self.cornerFraction = cornerFraction
    self.isStale = isStale
    self.content = content()
  }

  public var body: some View {
    GeometryReader { room in
      let size = Self.fit(aspect, in: room.size)
      let shape = RoundedRectangle(cornerRadius: size.width * cornerFraction, style: .continuous)
      content
        .frame(width: size.width, height: size.height)
        .opacity(isStale ? 0.4 : 1)
        .saturation(isStale ? 0.4 : 1)
        .background(.kitWindow)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.kitBorder, lineWidth: 1))
        .contentShape(shape)
        .frame(width: room.size.width, height: room.size.height)
        .animation(.kit, value: isStale)
    }
  }

  /// The largest size with `aspect`'s proportions inside `room`, never larger than `aspect` itself read as points.
  static func fit(_ aspect: CGSize, in room: CGSize) -> CGSize {
    guard aspect.width > 0, aspect.height > 0, room.width > 0, room.height > 0 else { return .zero }
    let scale = min(room.width / aspect.width, room.height / aspect.height)
    return CGSize(width: (aspect.width * scale).rounded(.down), height: (aspect.height * scale).rounded(.down))
  }
}

/// One command to copy: monospaced on a field well, the Copy button at its end. A long command wraps.
///
/// ```swift
/// KitCommand("swift build --product RemoteHostLinux")
/// ```
public struct KitCommand: View {
  var command: String

  public init(_ command: String) { self.command = command }

  public var body: some View {
    HStack(alignment: .center, spacing: 4) {
      Text(command)
        .kitFont(.monoSmall)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
      KitCopyButton("Copy", systemImage: "doc.on.doc", value: command).buttonStyle(.kitIcon)
    }
    .padding(EdgeInsets(top: 0, leading: 9, bottom: 0, trailing: 2))
    .kitSurface(.field, cornerRadius: KitMetrics.radiusSmall)
  }
}

/// One step of a `KitGuide`: what to do, the command that does it, a note under it.
public struct KitGuideStep: Hashable, Sendable {
  public var title: String
  public var command: String?
  public var note: String?
  public var isDone: Bool

  public init(_ title: String, command: String? = nil, note: String? = nil, isDone: Bool = false) {
    self.title = title
    self.command = command
    self.note = note
    self.isDone = isDone
  }
}

/// Steps to set something up somewhere the app can't do it alone: a title and why, the numbered steps in one card
/// (each with a command to copy and a note when it has them; a done step shows a check), then the actions.
///
/// ```swift
/// KitGuide("Remote isn’t on studio-pc", message: "The preview comes through Remote…", steps: [
///   .init("Build the host", command: "swift build --product RemoteHostWindows", isDone: true),
///   .init("Start it on the desktop", command: "RemoteHostWindows --windows", note: "Not over SSH."),
/// ]) {
///   Button("Check Again") { … }.buttonStyle(.kitPrimary)
/// }
/// ```
public struct KitGuide<Header: View, Actions: View>: View {
  /// The steps' type, also by its short name.
  public typealias Step = KitGuideStep

  var title: KitString
  var message: KitString?
  var steps: [Step]
  @ViewBuilder var header: Header
  @ViewBuilder var actions: Actions

  /// The steps are data, shown as they are; `header` sits between the message and the steps (a picker of systems).
  /// The title and message are strings shown as they are, since they name a device.
  public init(
    _ title: String, message: String? = nil, steps: [Step], @ViewBuilder header: () -> Header,
    @ViewBuilder actions: () -> Actions
  ) {
    self.title = KitString(verbatim: title)
    self.message = KitString(verbatim: message)
    self.steps = steps
    self.header = header()
    self.actions = actions()
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(title).kitFont(.title3).fixedSize(horizontal: false, vertical: true)
          if let message {
            Text(message).kitFont(.callout).foregroundStyle(.kitSecondary).fixedSize(horizontal: false, vertical: true)
          }
        }
        .accessibilityElement(children: .combine)
        header
        VStack(alignment: .leading, spacing: 12) {
          ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
            row(step, number: index + 1)
          }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kitSurface(.card)
        HStack(spacing: 8) { actions }
          .controlSize(.small)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 4)
    }
    .scrollBounceBehavior(.basedOnSize)
  }

  private func row(_ step: Step, number: Int) -> some View {
    HStack(alignment: .top, spacing: 10) {
      ZStack {
        if step.isDone {
          Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Hue.green.text)
        } else {
          Text("\(number)").kitFont(.caption).fontWeight(.semibold).monospacedDigit().foregroundStyle(.kitSecondary)
        }
      }
      .frame(width: 18, height: 18)
      .background(step.isDone ? AnyShapeStyle(Hue.green.soft(0.18)) : AnyShapeStyle(.kitFill), in: RoundedRectangle(cornerRadius: KitMetrics.radiusXS, style: .continuous))
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 6) {
        Text(verbatim: step.title)
          .kitFont(.callout)
          .foregroundStyle(step.isDone ? AnyShapeStyle(.kitSecondary) : AnyShapeStyle(.kitLabel))
          .fixedSize(horizontal: false, vertical: true)
        if let command = step.command { KitCommand(command) }
        if let note = step.note {
          Text(verbatim: note).kitFont(.caption).foregroundStyle(.kitSecondary).fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(verbatim: step.isDone ? "\(number), done" : "\(number)"))
  }
}

extension KitGuide where Header == EmptyView {
  /// A guide with nothing between its message and its steps.
  public init(_ title: String, message: String? = nil, steps: [Step], @ViewBuilder actions: () -> Actions) {
    self.init(title, message: message, steps: steps, header: { EmptyView() }, actions: actions)
  }
}
