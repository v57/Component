import SwiftUI

/// Output nobody types into (Shell's actions, Code's build, test and run console) as a stack of run blocks on a
/// field-filled track. Each `RunBlock` is headed by its live icon, the action and command, an exit chip and bare
/// figures, with Stop while it runs; a run that passed folds to its header, a failed one keeps its output open, and
/// the run you pick rises as the raised card. Interactive terminals stay a plain stream; this is only for runs.
///
/// ```swift
/// RunBlocks(selection: $selectedRun) {
///   RunBlock("Build", command: "swift build", status: .done, duration: "21 s", warnings: "1 warning")
///   RunBlock("Test", command: "swift test", status: .failed("exit 1"), duration: "4.2 s", output: log)
///   RunBlock("Build", command: "swift build", id: "build-2", status: .working(progress: 0.64),
///            progress: "31 of 48", duration: "12 s", output: tail) { build.cancel() }
/// }
/// ```
public struct RunBlocks<Content: View>: View {
  var selection: Binding<String?>?
  var content: Content

  /// A track of runs; with `selection`, clicking a block selects it (its `id`).
  public init(selection: Binding<String?>? = nil, @ViewBuilder content: () -> Content) {
    self.selection = selection
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 2) { content }
      .padding(4)
      .background(.kitField, in: RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous))
      .environment(\.dataRunSelection, selection)
  }
}

extension EnvironmentValues {
  @Entry var dataRunSelection: Binding<String?>? = nil
}

/// One run on a `RunBlocks` track. `status` drives its live icon and chip: `.working(progress:)` fills the ring
/// (`nil` turns the arc) and shows Stop, `.done` checks and folds it, `.failed("exit 1")` turns it red with the
/// message as a chip and keeps the output open, `.paused` reads as Stopped. Output lines starting `error:` or
/// `warning:` (or containing them after a location) are marked.
public struct RunBlock: View {
  var name: String?
  var command: String
  var id: String
  var systemImage: String
  var hue: Hue
  var status: WorkStatus
  var progress: String?
  var duration: String?
  var warnings: String?
  var output: String
  var stop: (() -> Void)?
  @State private var expanded: Bool?
  @Environment(\.dataRunSelection) private var selection
  @Environment(\.kitIdiom) private var idiom
  @Environment(\.colorScheme) private var scheme

  public init(
    _ name: String? = nil, command: String, id: String? = nil, systemImage: String = "terminal",
    hue: Hue = .accent, status: WorkStatus, progress: String? = nil, duration: String? = nil,
    warnings: String? = nil, output: String = "", stop: (() -> Void)? = nil
  ) {
    self.name = name
    self.command = command
    self.id = id ?? [name, command].compactMap { $0 }.joined(separator: " ")
    self.systemImage = systemImage
    self.hue = hue
    self.status = status
    self.progress = progress
    self.duration = duration
    self.warnings = warnings
    self.output = output
    self.stop = stop
  }

  private var isSelected: Bool { selection?.wrappedValue == id }
  /// Passed runs fold to their header; everything else shows its output.
  private var isExpanded: Bool { expanded ?? (status != .done) }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      if isExpanded, !output.isEmpty {
        RunOutputText(output: output)
          .padding(.leading, 34)
          .padding(.trailing, 10)
          .padding(.bottom, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .transition(.opacity)
      }
    }
    .background {
      if isSelected { SurfaceShape(surface: .raised, cornerRadius: KitMetrics.radius) }
    }
    .contentShape(Rectangle())
    .onTapGesture { withKitAnimation(.kitFast) { selection?.wrappedValue = id } }
    .animation(.kit, value: isExpanded)
    .animation(.kit, value: status)
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var header: some View {
    HStack(spacing: 8) {
      LiveIcon(systemImage: systemImage, hue: hue, status: status, size: 18)
      if let name {
        Text(name).font(.system(size: 12, weight: .semibold)).lineLimit(1).fixedSize()
      }
      Text(command)
        .font(.system(size: 12, weight: name == nil ? .semibold : .regular, design: .monospaced))
        .foregroundStyle(name == nil ? AnyShapeStyle(.kitLabel) : AnyShapeStyle(.kitSecondary))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .leading)
      if let warnings { Count(warnings, .attention) }
      if case .failed(let message) = status { Chip(message ?? "Failed", hue: .red) }
      if case .paused = status { Chip("Stopped") }
      if let figures { Count(figures) }
      if status.isWorking, let stop {
        Button("Stop", systemImage: "stop.fill", action: stop)
          .buttonStyle(.dataSoft)
          .controlSize(.small)
      }
    }
    .padding(.leading, 8)
    .padding(.trailing, 6)
    .frame(height: idiom.isTouch ? 40 : 30)
    .contentShape(Rectangle())
    .onTapGesture {
      withKitAnimation {
        selection?.wrappedValue = id
        if !output.isEmpty { expanded = !isExpanded }
      }
    }
    .accessibilityAddTraits(.isButton)
    .accessibilityHint(output.isEmpty ? "" : isExpanded ? "Folds the output" : "Shows the output")
  }

  /// "31 of 48 · 12 s".
  private var figures: String? {
    let parts = [progress, duration].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }
}

/// A run's output in mono, with `error:` and `warning:` marked in red and orange.
private struct RunOutputText: View {
  let output: String
  @Environment(\.self) private var environment

  var body: some View {
    Text(styled)
      .font(.system(size: 12, design: .monospaced))
      .lineSpacing(4)
      .textSelection(.enabled)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var styled: AttributedString {
    var text = AttributedString(output)
    for mark in RunOutput.marks(in: output) {
      let start = text.characters.index(text.startIndex, offsetBy: mark.range.lowerBound)
      let end = text.characters.index(text.startIndex, offsetBy: mark.range.upperBound)
      let hue: Hue = mark.isError ? .red : .orange
      text[start..<end].foregroundColor = hue.text.resolve(in: environment)
      text[start..<end].font = .system(size: 12, weight: .semibold, design: .monospaced)
    }
    return text
  }
}

enum RunOutput {
  struct Mark: Equatable {
    var range: Range<Int>
    var isError: Bool
  }

  /// Where `error:` and `warning:` appear as a compiler writes them: at the start of a line or after a location
  /// ("Trip.swift:42: error:"), as character offsets.
  static func marks(in output: String) -> [Mark] {
    var marks: [Mark] = []
    var offset = 0
    for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
      for (word, isError) in [("error:", true), ("warning:", false)] {
        if let range = line.range(of: word) {
          let before = line[line.startIndex..<range.lowerBound]
          if before.isEmpty || before.hasSuffix(": ") || before.hasSuffix(" ") && before.contains(":") {
            let start = offset + line.distance(from: line.startIndex, to: range.lowerBound)
            marks.append(Mark(range: start..<(start + word.count), isError: isError))
          }
        }
      }
      offset += line.count + 1
    }
    return marks
  }
}

#Preview("Run blocks") {
  @Previewable @State var selection: String? = "test"
  RunBlocks(selection: $selection) {
    RunBlock("Build", command: "swift build", systemImage: "hammer", status: .done, duration: "21 s", warnings: "1 warning")
    RunBlock(
      "Test", command: "swift test", id: "test", systemImage: "testtube.2", status: .failed("exit 1"),
      duration: "4.2 s",
      output: "Test Suite 'TripStoreTests' started.\nTripStoreTests.swift:42: error: testUpcoming: XCTAssertEqual failed: (2) is not equal to (3)\nExecuted 6 tests, with 1 failure in 0.412 seconds.")
    RunBlock(
      "Build", command: "swift build", id: "build-2", systemImage: "hammer", status: .working(progress: 0.64),
      progress: "31 of 48", duration: "12 s",
      output: "Building for debugging...\n[31/48] Compiling AtlasCore TripStore.swift", stop: {})
    RunBlock("Tail logs", command: "tail -f app.log", systemImage: "doc.text", status: .paused(), duration: "2 min")
  }
  .padding(8)
  .frame(width: 640)
  .background(.kitWindow)
  .componentKit()
}
