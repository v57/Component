import SwiftUI

// The preview pane (the canvas's Code page, "Preview" boards, 2026-11-16): a running app beside what makes it. A bar
// says what is shown and holds its buttons, the stage centres the picture, a foot says where the picture comes from.
// When the picture can't be had yet, the stage holds an `EmptyState` or a `KitGuide` instead.

/// A trailing pane that shows something running: a device's screen, another machine's window. The bar names it (a
/// live icon carries starting and failing), `tools` are its icon buttons, `stage` is the picture, centred, and the
/// foot says where it comes from. Put it in a `ResizableSplit`; it fills what it is given.
///
/// ```swift
/// KitPreviewPane("iPhone 17", meta: ["iOS 27.2", "Trips"], systemImage: "iphone", source: "Simulator on this Mac", stats: "60 fps") {
///   Button("Home", systemImage: "house") { … }
/// } stage: {
///   KitPreviewScreen(aspect: CGSize(width: 1206, height: 2622), cornerFraction: 0.13) { SimulatorScreen(device) }
/// }
/// ```
public struct KitPreviewPane<Tools: View, Stage: View>: View {
  var title: KitString
  var meta: [String]
  var systemImage: String
  var hue: Hue
  var status: WorkStatus
  var source: KitString?
  var sourceImage: String
  var stats: String?
  @ViewBuilder var tools: Tools
  @ViewBuilder var stage: Stage

  /// A pane titled by a key (a literal), looked up in the app's strings, as is `source`; `meta` and `stats` are
  /// shown as they are.
  public init(
    _ title: LocalizedStringKey, meta: [String] = [], systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, source: LocalizedStringKey? = nil, sourceImage: String = "bolt",
    stats: String? = nil, @ViewBuilder tools: () -> Tools, @ViewBuilder stage: () -> Stage
  ) {
    self.init(
      title: KitString(title), meta: meta, systemImage: systemImage, hue: hue, status: status,
      source: KitString(source), sourceImage: sourceImage, stats: stats, tools: tools, stage: stage)
  }

  /// The same with strings shown as they are (a device's or a window's name).
  @_disfavoredOverload
  public init(
    _ title: some StringProtocol, meta: [String] = [], systemImage: String, hue: Hue = .accent,
    status: WorkStatus = .idle, source: String? = nil, sourceImage: String = "bolt", stats: String? = nil,
    @ViewBuilder tools: () -> Tools, @ViewBuilder stage: () -> Stage
  ) {
    self.init(
      title: KitString(verbatim: String(title)), meta: meta, systemImage: systemImage, hue: hue, status: status,
      source: KitString(verbatim: source), sourceImage: sourceImage, stats: stats, tools: tools, stage: stage)
  }

  init(
    title: KitString, meta: [String], systemImage: String, hue: Hue, status: WorkStatus, source: KitString?,
    sourceImage: String, stats: String?, @ViewBuilder tools: () -> Tools, @ViewBuilder stage: () -> Stage
  ) {
    self.title = title
    self.meta = meta
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
    self.source = source
    self.sourceImage = sourceImage
    self.stats = stats
    self.tools = tools()
    self.stage = stage()
  }

  public var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        LiveIcon(systemImage: systemImage, hue: hue, status: status, size: 26)
        VStack(alignment: .leading, spacing: 0) {
          Text(title).kitFont(.headline).lineLimit(1)
          if !meta.isEmpty { MetaLine(meta).kitFont(.caption).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        HStack(spacing: 2) { tools }
          .buttonStyle(.kitIcon)
      }
      .padding(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
      .frame(height: 44)
      stage
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(EdgeInsets(top: 4, leading: 20, bottom: 16, trailing: 20))
      if source != nil || stats != nil {
        HStack(spacing: 6) {
          if let source {
            Image(systemName: sourceImage).imageScale(.small)
            Text(source).lineLimit(1)
          }
          Spacer(minLength: 8)
          if let stats { Text(stats).monospacedDigit().lineLimit(1) }
        }
        .kitFont(.caption)
        .foregroundStyle(.kitSecondary)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .accessibilityElement(children: .combine)
      }
    }
    .kitPane(.secondary)
  }
}

/// The picture in a preview's stage: `content` fitted to the room at `aspect`, its corners rounded as the device's
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
