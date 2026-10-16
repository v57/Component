import ComponentKit
import SwiftUI

/// A pretend piece of work for the catalog: it runs (indeterminate, then with progress) and ends done or failed.
@MainActor @Observable
final class SimulatedWork {
  var status: WorkStatus = .idle
  var fails = false
  var indeterminateFirst = true
  private var task: Task<Void, Never>?

  var label: String {
    switch status {
    case .idle: "Idle"
    case .working(let p): p.map { "\(Int($0 * 100))%" } ?? "Working…"
    case .paused(let p): "Paused at \(Int((p ?? 0) * 100))%"
    case .done: "Done"
    case .failed(let message): message ?? "Failed"
    }
  }

  func start(duration: Double = 3) {
    task?.cancel()
    task = Task { @MainActor in
      if indeterminateFirst {
        status = .working
        try? await Task.sleep(for: .seconds(1))
      }
      let steps = 30
      for step in 0...steps {
        guard !Task.isCancelled else { return }
        status = .working(progress: Double(step) / Double(steps))
        try? await Task.sleep(for: .seconds(duration / Double(steps)))
      }
      guard !Task.isCancelled else { return }
      status = fails ? .failed("exit 1") : .done
    }
  }

  func pause() {
    task?.cancel()
    status = .paused(progress: status.progress)
  }

  func reset() {
    task?.cancel()
    status = .idle
  }
}

// MARK: - Live icon

struct LiveIconPage: View {
  @State private var indicatorStatus: WorkStatus = .working
  /// Plays a scripted run through the states (`--cycle` starts it, for captures).
  @State private var cycling = ProcessInfo.processInfo.arguments.contains("--cycle")
  let indicatorStates: [(String, WorkStatus)] = [
    ("Idle", .idle), ("Working", .working), ("30%", .working(progress: 0.3)), ("75%", .working(progress: 0.75)),
    ("Paused", .paused(progress: 0.75)), ("Done", .done), ("Failed", .failed("exit 1")),
  ]
  let states: [(String, WorkStatus)] = [
    ("Idle", .idle), ("Working", .working), ("40%", .working(progress: 0.4)), ("Paused", .paused(progress: 0.6)),
    ("Done", .done), ("Failed", .failed("exit 1")),
  ]

  var body: some View {
    CatalogPage(page: .liveIcon) {
      SpecimenSection("Tiles", note: "Soft for things, sections and rows; solid for apps; plain in compact sidebars.") {
        Specimen(
          "Styles and sizes",
          code: """
            Tile(systemImage: "folder", hue: .blue)
            Tile(systemImage: "hammer", hue: .orange, size: 32, style: .solid)
            Tile(letters: "Pg", hue: .indigo, shape: .circle)
            """
        ) {
          HStack(spacing: 18) {
            ForEach([Tile<Image>.Style.soft, .solid, .plain], id: \.self) { style in
              Labeled("\(style)") {
                HStack(spacing: 10) {
                  Tile(systemImage: "folder", hue: .blue, size: 18, style: style)
                  Tile(systemImage: "folder", hue: .blue, size: 24, style: style)
                  Tile(systemImage: "folder", hue: .blue, size: 32, style: style)
                }
              }
            }
            Labeled("letters") {
              HStack(spacing: 10) {
                Tile(letters: "A", hue: .pink)
                Tile(letters: "Pg", hue: .indigo, size: 32)
                Tile(letters: "Mo", hue: .teal, size: 32, shape: .circle)
              }
            }
          }
        }
      }
      SpecimenSection(
        "States", note: "State lives in the icon: a bloom while the amount is unknown, a ring with progress, then a check or red."
      ) {
        Specimen("Rounded", code: "LiveIcon(systemImage: \"arrow.up\", status: .working(progress: 0.4))") {
          statesRow(shape: .rounded, size: 24)
        }
        Specimen("Circle, 32pt", code: "LiveIcon(systemImage: \"arrow.down\", hue: .green, status: .done, size: 32, shape: .circle)") {
          statesRow(shape: .circle, size: 32)
        }
        Specimen("Inactive window", note: "The indicator holds still", code: "view.environment(\\.kitWindowIsActive, false)") {
          statesRow(shape: .rounded, size: 24).environment(\.kitWindowIsActive, false)
        }
      }
      SpecimenSection(
        "Work indicators",
        note: "Work of unknown length. Every style follows the tile's shape and morphs into the progress ring; pick one per app or per view."
      ) {
        HStack(spacing: 12) {
          KitSegmented(selection: $indicatorStatus, options: indicatorStates)
          Toggle("Cycle", isOn: $cycling).toggleStyle(.kitCheckbox)
          Spacer()
        }
        Specimen("Rounded", code: "LiveIcon(systemImage: \"arrow.up\", status: push).kitWorkIndicator(.comet)") {
          indicatorsRow(shape: .rounded, size: 24)
        }
        Specimen("Rounded, 32pt", code: "LiveIcon(systemImage: \"sparkles\", hue: .purple, status: push, size: 32)") {
          indicatorsRow(shape: .rounded, size: 32, hue: .purple, systemImage: "sparkles")
        }
        Specimen("Circle", code: "LiveIcon(systemImage: \"arrow.down\", status: push, shape: .circle).kitWorkIndicator(.ripple)") {
          indicatorsRow(shape: .circle, size: 24, hue: .green, systemImage: "arrow.down")
        }
      }
      .task(id: cycling) {
        guard cycling else { return }
        // A typical run: unknown at first, then known, then finished; every other run fails.
        let script: [(WorkStatus, Double)] = [
          (.idle, 0.8), (.working, 2.4), (.working(progress: 0.3), 0.9), (.working(progress: 0.65), 0.9),
          (.working(progress: 0.9), 0.7), (.done, 1.6), (.idle, 0.8), (.working, 1.8), (.paused(progress: nil), 1.2),
          (.working, 1.4), (.failed("exit 1"), 1.6),
        ]
        while !Task.isCancelled {
          for (status, seconds) in script {
            indicatorStatus = status
            try? await Task.sleep(for: .seconds(seconds))
            if Task.isCancelled { return }
          }
        }
      }
      SpecimenSection("Any glyph") {
        Specimen(
          "Custom content",
          code: "LiveIcon(hue: .purple, status: .working) { Text(\"AI\").fontWeight(.bold) }"
        ) {
          HStack(spacing: 18) {
            LiveIcon(hue: .purple, status: .working, size: 28) { Text("AI").fontWeight(.bold) }
            LiveIcon(hue: .orange, status: .working(progress: 0.7), size: 28) { Image(systemName: "hammer") }
            LiveIcon(hue: .teal, status: .idle, size: 28) { Text("7") }
          }
        }
      }
    }
  }

  private func indicatorsRow(
    shape: KitShape, size: CGFloat, hue: Hue = .accent, systemImage: String = "arrow.up"
  ) -> some View {
    // Strokes on the ring, then fills around or inside the tile.
    let rows: [[KitWorkIndicator]] = [
      [.trace, .comet, .pulse, .march, .ripple],
      [.breathe, .glow, .bloom, .heartbeat, .sonar],
    ]
    return VStack(alignment: .leading, spacing: 14) {
      ForEach(rows, id: \.self) { row in
        HStack(spacing: 22) {
          ForEach(row, id: \.self) { indicator in
            Labeled(indicator.rawValue) {
              LiveIcon(systemImage: systemImage, hue: hue, status: indicatorStatus, size: size, shape: shape)
                .kitWorkIndicator(indicator)
                .frame(width: size + 8, height: size + 8)
            }
            .frame(minWidth: 64)
          }
        }
      }
    }
  }

  private func statesRow(shape: KitShape, size: CGFloat) -> some View {
    HStack(spacing: 22) {
      ForEach(states, id: \.0) { label, status in
        Labeled(label) {
          LiveIcon(systemImage: "arrow.up", status: status, size: size, shape: shape)
            .frame(width: size + 8, height: size + 8)
        }
      }
    }
  }
}

// MARK: - Work status

struct WorkStatusPage: View {
  @State private var work = SimulatedWork()
  @State private var text = "https://github.com/v57/Component.git"

  var body: some View {
    CatalogPage(page: .workStatus) {
      SpecimenSection(
        "One piece of work, everywhere",
        note: "Start it and watch every component carry the same WorkStatus. Turn on Fail to end it red."
      ) {
        HStack(spacing: 10) {
          Button("Start", systemImage: "play.fill") { work.start() }.buttonStyle(.kitPrimary)
          Button("Pause", systemImage: "pause.fill") { work.pause() }.buttonStyle(.kit)
            .disabled(!work.status.isWorking)
          Button("Reset") { work.reset() }.buttonStyle(.kit)
          Toggle("Fail", isOn: $work.fails).toggleStyle(.kitCheckbox)
          Toggle("Unknown amount first", isOn: $work.indeterminateFirst).toggleStyle(.kitCheckbox)
          Spacer()
          Text(work.label).kitFont(.mono).foregroundStyle(.kitSecondary)
        }
        CodeSnippet(
          """
          enum WorkStatus { case idle, working(progress: Double?), paused(progress: Double?), done, failed(String?) }
          @State var push: WorkStatus = .idle
          """)
        SpecimenGrid(minWidth: 380) {
          Specimen("Live icon", code: "LiveIcon(systemImage: \"arrow.up\", status: push)") {
            LiveIcon(systemImage: "arrow.up", status: work.status, size: 32)
          }
          Specimen("Toolbar title", code: "KitTitle(\"History\", meta: [\"main\", status], systemImage: \"clock\", status: push)") {
            KitTitle("History", meta: ["main", work.label], systemImage: "clock", status: work.status)
          }
          Specimen("Section header", ground: .sidebar, code: "KitSection(\"Downloads\", meta: …, systemImage: \"arrow.down\", status: push) { … }") {
            KitSection("Downloads", meta: ["ubuntu.iso", work.label], systemImage: "arrow.down", hue: .red, status: work.status) {
              SidebarRow("ubuntu-26.04.iso", systemImage: "opticaldisc")
            }
          }
          Specimen("Field", code: "TextField(\"URL\", text: $url).kitField(status: .live(push, systemImage: \"link\"))") {
            TextField("URL", text: $text).kitField(status: .live(work.status, systemImage: "link"), mono: true)
          }
          Specimen("Search", code: "KitSearchField(text: $query, status: search, count: \"4 rows\")") {
            KitSearchField(text: .constant("Lisbon"), status: work.status, count: work.status == .done ? "4 rows" : nil)
          }
          Specimen("Sheet footer", code: "SheetStatus(\"Cloning…\", systemImage: \"arrow.down\", status: clone)") {
            SheetStatus(work.label, systemImage: "arrow.down", status: work.status)
          }
          Specimen("Status bar", ground: .window, padding: 0, code: "Editor().kitStatusBar(systemImage: \"hammer\", status: build) { Text(\"Building\") }") {
            StatusBar(systemImage: "hammer", status: work.status) {
              Text("Build")
              Spacer()
              Text(work.label)
            }
            .padding(.top, KitMetrics.gutter)
          }
          Specimen("Agent", code: "Avatar(name: \"coder-1\", kind: .agent, status: task)") {
            HStack(spacing: 12) {
              Avatar(name: "coder-1", kind: .agent, status: work.status, size: 32)
              MeterTile("Scan", value: work.label, systemImage: "magnifyingglass", status: work.status)
            }
          }
          Specimen("Run block", ground: .window, code: "RunBlock(\"Build\", command: \"swift build\", status: build) { stop() }") {
            RunBlocks {
              RunBlock("Build", command: "swift build", systemImage: "hammer", status: work.status, duration: work.label) {
                work.pause()
              }
            }
          }
          Specimen("Effect on finish", code: "Button(\"Push\") { … }.status(push)") {
            Button("Push", systemImage: "arrow.up") { work.start() }
              .buttonStyle(.kit)
              .status(work.status)
          }
        }
      }
    }
  }
}

// MARK: - Effects

struct EffectsPage: View {
  @State private var counts: [KitEffect: Int] = [:]
  /// Replays every effect on a loop (`--cycle` starts it, for captures).
  @State private var cycling = ProcessInfo.processInfo.arguments.contains("--cycle")

  let feedback: [(KitEffect, String, String)] = [
    (.success, "success", "It worked: a green wash and a small pop"),
    (.failure, "failure", "It didn't: a red wash and a shake"),
    (.pop, "pop", "Something arrived: a quick scale"),
    (.wash, "wash", "Something landed: an accent wash"),
    (.pulse, "pulse", "Look here: a ring that grows"),
  ]

  var body: some View {
    CatalogPage(page: .effects) {
      SpecimenSection(
        "Effects", note: "Apps report the event; the kit decides the look. Nothing plays in an inactive window."
      ) {
        SpecimenGrid(minWidth: 280) {
          ForEach(feedback, id: \.1) { effect, name, use in
            Specimen(".\(name)", note: use, code: "view.effect(.\(name), on: \(name)Count)") {
              HStack(spacing: 14) {
                Text("Trip to Lisbon")
                  .padding(.horizontal, 12)
                  .frame(height: 36)
                  .kitSurface(.card)
                  .effect(effect, on: counts[effect, default: 0], cornerRadius: KitMetrics.radiusCard)
                play(effect)
              }
            }
          }
        }
      }
      SpecimenSection(
        "Flourishes",
        note: "Bigger moments: pieces leave the view and fly off. They draw outside the view, so give it room; "
          + "Reduce Motion keeps only a wash of their colour."
      ) {
        SpecimenGrid(minWidth: 280) {
          Specimen(".burst", note: "Worth celebrating: confetti", padding: 40,
                   code: "Button(\"Publish\") { … }.effect(.burst, on: published)") {
            Button("Publish", systemImage: "checkmark.seal") { bump(.burst) }
              .buttonStyle(.kitPrimary)
              .effect(.burst, on: count(.burst))
          }
          Specimen(".float", note: "Kept or counted: the symbol rises", padding: 40,
                   code: "Button(\"Like\") { … }.effect(.float(\"heart.fill\", .pink), on: likes)") {
            HStack(spacing: 10) {
              Button("Like", systemImage: "heart") { bump(.float("heart.fill", .pink)) }
                .buttonStyle(.kit)
                .effect(.float("heart.fill", .pink), on: count(.float("heart.fill", .pink)))
              Button("Star", systemImage: "star") { bump(.float("star.fill", .yellow)) }
                .buttonStyle(.kit)
                .effect(.float("star.fill", .yellow), on: count(.float("star.fill", .yellow)))
              Button("Add", systemImage: "plus") { bump(.float()) }
                .buttonStyle(.kit)
                .effect(.float(), on: count(.float()))
            }
          }
          Specimen(".send", note: "Sent off: the symbol flies away", padding: 40,
                   code: "Button(\"Send\") { … }.effect(.send(\"paperplane.fill\"), on: sent)") {
            HStack(spacing: 10) {
              Button("Send", systemImage: "paperplane") { bump(.send()) }
                .buttonStyle(.kitPrimary)
                .effect(.send(), on: count(.send()))
              Button("Push", systemImage: "arrow.up") { bump(.send("arrow.up.circle.fill", .green)) }
                .buttonStyle(.kit)
                .effect(.send("arrow.up.circle.fill", .green), on: count(.send("arrow.up.circle.fill", .green)))
            }
          }
          Specimen(".sparkle", note: "New or generated: stars twinkle", padding: 40,
                   code: "Button(\"Summarize\") { … }.effect(.sparkle, on: summaries)") {
            Button("Summarize", systemImage: "sparkles") { bump(.sparkle) }
              .buttonStyle(.kit)
              .effect(.sparkle, on: count(.sparkle))
          }
          Specimen(".shimmer", note: "Refreshed: a band of light sweeps across", padding: 40,
                   code: "card.effect(.shimmer, on: lastRefresh)") {
            HStack(spacing: 14) {
              VStack(alignment: .leading, spacing: 2) {
                Text("Inbox")
                Text("Updated just now").kitFont(.caption).foregroundStyle(.kitSecondary)
              }
              .padding(.horizontal, 12)
              .frame(width: 160, height: 48, alignment: .leading)
              .kitSurface(.card)
              .effect(.shimmer, on: count(.shimmer), cornerRadius: KitMetrics.radiusCard)
              play(.shimmer)
            }
          }
          Specimen(".wiggle", note: "Not now: a short tilt", padding: 40,
                   code: "row.effect(.wiggle, on: lockedTaps)") {
            Button { bump(.wiggle) } label: {
              Label("Archive is locked", systemImage: "lock")
                .padding(.horizontal, 12)
                .frame(height: 36)
                .kitSurface(.card)
            }
            .buttonStyle(.plain)
            .effect(.wiggle, on: count(.wiggle), cornerRadius: KitMetrics.radiusCard)
          }
        }
      }
    }
    // Captures run in a background window, where effects never play.
    .transformEnvironment(\.kitWindowIsActive) { if cycling { $0 = true } }
    .task(id: cycling) {
      while cycling, !Task.isCancelled {
        for effect in Self.all { bump(effect) }
        try? await Task.sleep(for: .seconds(1.6))
      }
    }
  }

  private static let all: [KitEffect] = [
    .success, .failure, .pop, .wash, .pulse, .burst, .float("heart.fill", .pink), .float("star.fill", .yellow),
    .float(), .send(), .send("arrow.up.circle.fill", .green), .sparkle, .shimmer, .wiggle,
  ]

  private func count(_ effect: KitEffect) -> Int { counts[effect, default: 0] }
  private func bump(_ effect: KitEffect) { counts[effect, default: 0] += 1 }

  private func play(_ effect: KitEffect) -> some View {
    Button("Play") { bump(effect) }.buttonStyle(.kit).controlSize(.small)
  }
}
