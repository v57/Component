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
