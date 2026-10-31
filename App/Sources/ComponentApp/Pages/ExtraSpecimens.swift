import ComponentKit
import SwiftUI

// Specimen sections for the smaller shared pieces apps used to write themselves (code blocks, copy buttons, picture
// avatars, …), each shown on its area's page.

// MARK: - Code block (Run Blocks page)

struct CodeBlockSpecimens: View {
  @State private var log: [String] = ["Starting VM atlas-dev…"]

  var body: some View {
    SpecimenSection(
      "Code and logs",
      note: "Read-only monospaced text on a field well: selectable, wrapping or scrolling sideways, a height it scrolls past, and a log that follows its end."
    ) {
      SpecimenGrid(minWidth: 360) {
        Specimen("KitCodeBlock", code: "KitCodeBlock(commands)\nKitCodeBlock(fingerprint, font: .monoSmall)") {
          VStack(alignment: .leading, spacing: 10) {
            KitCodeBlock("SET session:42 \"{\\\"user\\\": 7}\" EX 3600\nDEL cache:home")
            KitCodeBlock("SHA256:1q2w3e4r5t6y7u8i9o0pAaSsDdFfGgHhJjKkLlZx", font: .monoSmall)
          }
        }
        Specimen("No wrapping, a height", code: "KitCodeBlock(file.text, wraps: false, maxHeight: 120)") {
          KitCodeBlock(sampleBuildLog + "\n" + sampleTestLog, wraps: false, maxHeight: 120)
        }
      }
      Specimen(
        "A live log", note: "follows its end",
        code: "KitCodeBlock(lines: runner.log, maxHeight: 160, followsEnd: true) { $0.contains(\"error\") ? .red : nil }"
      ) {
        KitCodeBlock(lines: log, maxHeight: 160, followsEnd: true) { line in
          line.contains("error") ? .red : line.hasPrefix("::") ? .accent : nil
        }
        .task {
          var index = 0
          while !Task.isCancelled, index < 400 {
            try? await Task.sleep(for: .milliseconds(700))
            index += 1
            log.append(
              index % 9 == 0
                ? "error: step \(index) failed, retrying" : index % 5 == 0 ? ":: stage \(index / 5)" : "[\(index)] copying files…")
          }
        }
      }
    }
  }
}

// MARK: - Pictures from bytes and URLs, app icons (Avatars page)

struct PictureAvatarSpecimens: View {
  var body: some View {
    SpecimenSection(
      "From bytes, URLs and icons",
      note: "Avatar(imageData:) and Avatar(url:) draw the picture once it decodes or loads, and the drawn avatar until then or without one. KitAppIcon(image:) clips any square artwork to the app icon's squircle."
    ) {
      SpecimenGrid(minWidth: 360) {
        Specimen(
          "Avatar(imageData:) · Avatar(url:)", note: "no picture yet",
          code: "Avatar(name: agent.name, imageData: agent.portrait, kind: .agent)\nAvatar(name: account.login, url: account.avatarURL, size: 32)"
        ) {
          Flow(spacing: 14) {
            Labeled("no data") { Avatar(name: "planner", imageData: nil, kind: .agent, size: 32) }
            Labeled("not a picture") { Avatar(name: "Maya Okafor", imageData: Data([1, 2, 3]), presence: .online, size: 32) }
            Labeled("no URL") { Avatar(name: "octocat", url: nil, size: 32) }
          }
        }
        Specimen(
          "KitAppIcon(image:)",
          code: "KitAppIcon(image: project.iconImage, size: 44)\nKitAppIcon(data: project.icon, size: 44)\nKitAppIcon(image: nil, size: 44)"
        ) {
          Flow(spacing: 14, alignment: .bottom) {
            KitAppIcon(image: SquareArt.image(systemImage: "hammer.fill", hue: .orange), size: 18)
            KitAppIcon(image: SquareArt.image(systemImage: "hammer.fill", hue: .orange), size: 28)
            KitAppIcon(image: SquareArt.image(systemImage: "globe", hue: .teal), size: 44)
            KitAppIcon(image: SquareArt.image(systemImage: "camera.fill", hue: .indigo), size: 64)
            Labeled("none") { KitAppIcon(image: nil, size: 44) }
          }
        }
      }
    }
  }
}

/// Square, unclipped artwork, as a project's icon render comes: what KitAppIcon(image:) clips.
enum SquareArt {
  static func image(systemImage: String, hue: Hue) -> Image {
    let renderer = ImageRenderer(
      content: Rectangle().fill(hue.fill).frame(width: 64, height: 64)
        .overlay { Image(systemName: systemImage).font(.system(size: 30, weight: .semibold)).foregroundStyle(.white) })
    renderer.scale = 3
    guard let cgImage = renderer.cgImage else { return Image(systemName: systemImage) }
    return Image(decorative: cgImage, scale: 3)
  }
}

// MARK: - Copy and round primary buttons (Buttons page)

struct CopyAndRoundPrimarySpecimens: View {
  @State private var message = "Ship it"

  var body: some View {
    SpecimenSection(
      "Copy and lead",
      note: "KitCopyButton copies and says so for a moment. .kitRoundPrimary is the round button an input or a tool leads with: Send, Clean."
    ) {
      SpecimenGrid(minWidth: 320) {
        Specimen(
          "KitCopyButton", note: "click one",
          code: "KitCopyButton(value: command).buttonStyle(.kitPlain)\nKitCopyButton(\"Copy Code\", value: code).buttonStyle(.kit)"
        ) {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("claude mcp add dev -- dev-mcp").kitFont(.mono).lineLimit(1)
              Spacer()
              KitCopyButton(value: "claude mcp add dev -- dev-mcp").buttonStyle(.kitPlain)
            }
            HStack(spacing: 10) {
              KitCopyButton("Copy Code", systemImage: "doc.on.doc", value: "WDJB-MJHT").buttonStyle(.kit)
              KitCopyButton("Copy Password", systemImage: "key", value: "hunter2", isSecret: true).buttonStyle(.kitIcon)
            }
          }
        }
        Specimen(
          "kitRoundPrimary",
          code: "Button(\"Send\", systemImage: \"arrow.up\", action: send).buttonStyle(.kitRoundPrimary)\nButton(action: clean) { Text(\"Clean\").kitFont(.headline) }\n  .buttonStyle(KitRoundButtonStyle(prominent: true, size: 72))"
        ) {
          Flow(spacing: 14) {
            Button("Send", systemImage: "arrow.up") {}.buttonStyle(.kitRoundPrimary)
            Button("Send", systemImage: "arrow.up") {}.buttonStyle(.kitRoundPrimary).controlSize(.small)
            Button("Send", systemImage: "arrow.up") {}.buttonStyle(.kitRoundPrimary).disabled(true)
            Button("Stop", systemImage: "stop.fill", role: .destructive) {}.buttonStyle(.kitRoundPrimary)
            Button {} label: { Text("Clean").kitFont(.headline) }
              .buttonStyle(KitRoundButtonStyle(prominent: true, size: 72))
          }
        }
      }
    }
  }
}

// MARK: - Colours from hex, Hub red (Colours page)

struct HexColourSpecimens: View {
  var body: some View {
    SpecimenSection(
      "From hex",
      note: "For data that names its own colours (a syntax theme, a stored colour); components take tokens. .kitHubRed is Get's and Player's accent."
    ) {
      Flow(spacing: 20, alignment: .top) {
        Labeled("Color(rgb: 0xc678dd)") { RoundedRectangle(cornerRadius: 10).fill(Color(rgb: 0xc678dd)).frame(width: 96, height: 44) }
        Labeled("Color(rgb:opacity:)") {
          RoundedRectangle(cornerRadius: 10).fill(Color(rgb: 0x61afef, opacity: 0.35)).frame(width: 96, height: 44)
        }
        Labeled("Color(hex: \"#98c379\")") {
          RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#98c379") ?? .clear).frame(width: 96, height: 44)
        }
        Labeled(".kitHubRed") { RoundedRectangle(cornerRadius: 10).fill(Color.kitHubRed).frame(width: 96, height: 44) }
      }
      CodeSnippet(
        "Text(token).foregroundStyle(Color(rgb: 0xc678dd))\nlet ground = Color(hex: frame.background) ?? .black   // #RGB, #RRGGBB, #RRGGBBAA\nWindowGroup { ContentView().componentKit(accent: .kitHubRed) }"
      )
    }
  }
}

// MARK: - Flow layout (Metrics page)

struct FlowLayoutSpecimens: View {
  var body: some View {
    SpecimenSection("Flow", note: "KitFlowLayout wraps views into lines; each line leading, centred or trailing in the width.") {
      SpecimenGrid(minWidth: 300) {
        ForEach([("leading", HorizontalAlignment.leading), ("center", .center), ("trailing", .trailing)], id: \.0) { name, alignment in
          Specimen(".\(name)", code: "KitFlowLayout(spacing: 6, alignment: .\(name)) { ForEach(tags) { Chip($0) } }") {
            KitFlowLayout(spacing: 6, alignment: alignment) {
              ForEach(["swift", "ios", "macos", "networking", "ssh", "ui", "design system", "tvOS"], id: \.self) { tag in
                Chip(tag)
              }
            }
          }
        }
      }
    }
  }
}

// MARK: - Dates, dot labels and meta lines of views (Type page)

struct DateAndMetaSpecimens: View {
  private let now = Date.now

  var body: some View {
    SpecimenSection(
      "Dates and durations",
      note: "date.kitFormatted(_:) writes a date next to now the same way in every app; KitDuration writes lengths of time."
    ) {
      let dates: [(String, TimeInterval)] = [
        ("20 s ago", -20), ("3 min ago", -180), ("2 hr ago", -7_200), ("yesterday", -86_400 - 3_600),
        ("3 days ago", -3 * 86_400), ("40 days ago", -40 * 86_400), ("400 days ago", -400 * 86_400),
      ]
      Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
        GridRow {
          ForEach(["", ".ago", ".clock", ".day", ".dayAndTime", ".elapsed"], id: \.self) { Text($0).kitFont(.monoSmall) }
        }
        ForEach(dates, id: \.0) { name, offset in
          let date = now.addingTimeInterval(offset)
          GridRow {
            Text(name).kitFont(.caption)
            ForEach([KitDateStyle.ago, .clock, .day, .dayAndTime, .elapsed], id: \.self) { style in
              Text(date.kitFormatted(style, relativeTo: now)).kitFont(.callout)
            }
          }
        }
      }
      MetaLine(
        KitDuration.format(42, seconds: true), KitDuration.format(125, seconds: true), KitDuration.format(4_000),
        KitDuration.timeLeft(25), KitDuration.timeLeft(200), KitDuration.timeLeft(4_900)
      )
      .kitFont(.callout)
      CodeSnippet(
        "Text(commit.date.kitFormatted(.dayAndTime))   // \"Today, 10:42\"\nText(message.date.kitFormatted(.clock))       // \"10:42\", \"Yesterday\", \"Mon\"\nText(KitDuration.timeLeft(estimate.remaining)) // \"about 3 min left\""
      )
    }
    SpecimenSection("Dot labels and meta lines of views", note: "StatusLabel is a dot and a word; MetaLine { } puts the dot between any views.") {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 16) {
          StatusLabel("Connected · atlas", hue: .green)
          StatusLabel("Connecting…", hue: .orange)
          StatusLabel("Offline — local only", hue: .gray, isHollow: true)
        }
        .kitFont(.caption)
        MetaLine {
          Text("main")
          StatusLabel("3 changed", hue: .orange)
          SyncCounts(ahead: 2, behind: 1)
        }
        .kitFont(.caption)
        MetaLine {
          Text("Pass 3")
          Text("1 failed").foregroundStyle(Hue.red.text)
          Text("12 min")
        }
        .kitFont(.caption)
      }
      CodeSnippet(
        "StatusLabel(\"Connected\", hue: .green).kitFont(.caption)\nMetaLine {\n  Text(branch)\n  if changes > 0 { StatusLabel(\"\\(changes) changed\", hue: .orange) }\n  SyncCounts(ahead: ahead, behind: behind)\n}"
      )
    }
  }
}

// MARK: - Drop label (Drag & Drop page)

struct DropLabelSpecimens: View {
  @State private var isTargeted = true
  @State private var chosen: [URL] = []

  var body: some View {
    SpecimenSection(
      "A window as a drop target",
      note: "kitDropTarget(_:label:systemImage:) rings the window and floats what a drop will do over its middle. Drag a file over the sample, or flip the toggle."
    ) {
      Specimen(
        "kitDropTarget(_:label:systemImage:)", ground: .window,
        code: ".kitDropTarget(isTargeted, label: \"Drop to download\", systemImage: \"arrow.down\", cornerRadius: KitMetrics.radiusWindow)\n.onDrop(of: [.fileURL, .url], isTargeted: $isTargeted) { … }"
      ) {
        VStack(alignment: .leading, spacing: 10) {
          Toggle("Targeted", isOn: $isTargeted).toggleStyle(.kitCheckbox)
          EmptyState(systemImage: "arrow.down.circle", title: "No Downloads", message: "Paste a link or drop a file.")
            .frame(height: 200)
            .kitDropTarget(isTargeted, label: "Drop to download", systemImage: "arrow.down", cornerRadius: KitMetrics.radiusCard)
            .kitFileDrop(isTargeted: $isTargeted) { _ in }
        }
      }
    }
    SpecimenSection(
      "Files from the system",
      note: "KitDesktop asks for files and folders with the system's panels (Windows and Linux: their file dialogs), and gives the file manager's icons."
    ) {
      Specimen(
        "KitDesktop.chooseFiles", note: "opens the panel",
        code: "let urls = await KitDesktop.chooseFiles(prompt: \"Open\", contentTypes: [.movie], allowsMultipleSelection: true)\nlet folder = await KitDesktop.chooseFolders(prompt: \"Use for Notes\", canCreateDirectories: true).first\nKitDesktop.icon(forFile: \"/Applications/Safari.app\")"
      ) {
        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 10) {
            Button("Choose Files…", systemImage: "doc") {
              Task { chosen = await KitDesktop.chooseFiles(canChooseFolders: true, allowsMultipleSelection: true) }
            }
            .buttonStyle(.kit)
            Button("Choose a Folder…", systemImage: "folder") {
              Task { chosen = await KitDesktop.chooseFolders(canCreateDirectories: true) }
            }
            .buttonStyle(.kit)
            if let icon = KitDesktop.icon(forFile: "/Applications/Safari.app") {
              KitAppIcon(image: icon, size: 28, isShaped: true)
            }
          }
          Text(chosen.isEmpty ? "Nothing chosen" : chosen.map(\.lastPathComponent).joined(separator: ", "))
            .kitFont(.caption)
        }
      }
    }
  }
}

// MARK: - Status pill (Feedback page)

struct StatusPillSpecimens: View {
  var body: some View {
    SpecimenSection(
      "Status pills",
      note: "A short status floating over content: a live icon carrying the work and a line, or any content."
    ) {
      Specimen(
        "KitStatusPill",
        code: "KitStatusPill(\"Waiting for the download\", systemImage: \"arrow.down\", hue: .orange, status: .working)\nKitStatusPill { VStack(alignment: .trailing) { Text(\"60 fps\"); Text(\"12.4 Mbps\") } }"
      ) {
        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: KitMetrics.radiusCard, style: .continuous)
            .fill(Hue.indigo.soft(0.5))
            .frame(height: 170)
          KitStatusPill("Waiting for the download", systemImage: "arrow.down", hue: .orange, status: .working)
            .padding(KitMetrics.gutter * 2)
          KitStatusPill {
            VStack(alignment: .trailing, spacing: 2) {
              Text("60 fps")
              Text("2560×1440 MetalFX")
              Text("12.4 Mbps")
            }
            .kitFont(.caption)
            .monospacedDigit()
          }
          .padding(KitMetrics.gutter * 2)
          .frame(maxWidth: .infinity, alignment: .topTrailing)
          KitStatusPill("Reconnecting…", systemImage: "display", status: .working(progress: 0.4))
            .environment(\.colorScheme, .dark)
            .padding(KitMetrics.gutter * 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(height: 170)
      }
    }
  }
}

// MARK: - Letters on a live icon (Live Icon page)

struct LetterLiveIconSpecimens: View {
  var body: some View {
    SpecimenSection("Letters", note: "LiveIcon(letters:) draws one or two letters as Tile(letters:) does: an engine's monogram carrying its connection.") {
      Specimen("LiveIcon(letters:)", code: "LiveIcon(letters: \"Pg\", hue: .blue, status: .working, size: 28)") {
        Flow(spacing: 18, lineSpacing: 12, alignment: .top) {
          Labeled("idle") { LiveIcon(letters: "Pg", hue: .blue, status: .idle, size: 28) }
          Labeled("connecting") { LiveIcon(letters: "My", hue: .orange, status: .working, size: 28) }
          Labeled("failed") { LiveIcon(letters: "Rd", hue: .red, status: .failed("refused"), size: 28) }
          Labeled("one letter") { LiveIcon(letters: "D", hue: .yellow, status: .working(progress: 0.6), size: 28) }
          Labeled("18pt") { LiveIcon(letters: "Mg", hue: .green, status: .idle, size: 18) }
        }
      }
    }
  }
}

// MARK: - Mixed checkboxes (Toggles page)

struct MixedCheckboxSpecimens: View {
  @State private var items = [true, false, true]

  var body: some View {
    SpecimenSection("Mixed", note: "A checkbox over a group shows a dash while some of it is on: Toggle(sources:isOn:) on its own, or .kitMixed(_:).") {
      Specimen(
        "Toggle(sources:isOn:)",
        code: "Toggle(\"All\", sources: $items, isOn: \\.self).toggleStyle(.kitCheckbox)\nToggle(\"Group\", isOn: groupBinding).toggleStyle(.kitCheckbox).kitMixed(state == .mixed)"
      ) {
        VStack(alignment: .leading, spacing: 8) {
          Toggle("All caches", sources: $items, isOn: \.self).toggleStyle(.kitCheckbox)
          ForEach(items.indices, id: \.self) { index in
            Toggle(["Xcode", "Simulators", "SwiftPM"][index], isOn: $items[index]).toggleStyle(.kitCheckbox)
              .padding(.leading, 22)
          }
          Toggle("Always mixed", isOn: .constant(true)).toggleStyle(.kitCheckbox).kitMixed(true)
        }
      }
    }
  }
}

// MARK: - Hue picker (Hues page)

struct HuePickerSpecimens: View {
  @State private var tag: Hue? = .blue
  @State private var hue: Hue = .green

  var body: some View {
    SpecimenSection("Picking a hue", note: "KitHuePicker: a row of swatches for a colour tag, with or without \"no colour\".") {
      SpecimenGrid(minWidth: 360) {
        Specimen("KitHuePicker(selection: $tag)", note: "optional", code: "FormRow(\"Color\", systemImage: \"paintpalette\", hue: tag ?? .gray) {\n  KitHuePicker(selection: $tag)\n}") {
          FormCard {
            FormRow("Color", help: "A dot beside its name in the sidebar", systemImage: "paintpalette", hue: tag ?? .gray) {
              KitHuePicker(selection: $tag)
            }
          }
        }
        Specimen("KitHuePicker(selection: $hue, hues:)", code: "KitHuePicker(selection: $project.hue, hues: [.blue, .green, .orange, .purple])") {
          HStack(spacing: 12) {
            KitHuePicker(selection: $hue, hues: [.blue, .green, .orange, .purple])
            Tile(systemImage: "folder", hue: hue, size: 28)
          }
        }
      }
    }
  }
}
