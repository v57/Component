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
