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
          Flow(spacing: 18, lineSpacing: 14, alignment: .top) {
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
        Flow(spacing: 12) {
          // Seven states don't fit an iPhone's width: there the track scrolls.
          ViewThatFits(in: .horizontal) {
            KitSegmented(selection: $indicatorStatus, options: indicatorStates)
            SideScroll { KitSegmented(selection: $indicatorStatus, options: indicatorStates) }
          }
          Toggle("Cycle", isOn: $cycling).toggleStyle(.kitCheckbox)
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
    // Five columns that narrow to fit an iPhone.
    let columns = Array(repeating: GridItem(.flexible(minimum: 52, maximum: 86), spacing: 10, alignment: .leading), count: 5)
    return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
      ForEach(Array(rows.joined()), id: \.self) { indicator in
        Labeled(indicator.rawValue) {
          LiveIcon(systemImage: systemImage, hue: hue, status: indicatorStatus, size: size, shape: shape)
            .kitWorkIndicator(indicator)
            .frame(width: size + 8, height: size + 8)
        }
      }
    }
  }

  private func statesRow(shape: KitShape, size: CGFloat) -> some View {
    Flow(spacing: 22, lineSpacing: 14, alignment: .top) {
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
        Flow(spacing: 10) {
          Button("Start", systemImage: "play.fill") { work.start() }.buttonStyle(.kitPrimary)
          Button("Pause", systemImage: "pause.fill") { work.pause() }.buttonStyle(.kit)
            .disabled(!work.status.isWorking)
          Button("Reset") { work.reset() }.buttonStyle(.kit)
          Toggle("Fail", isOn: $work.fails).toggleStyle(.kitCheckbox)
          Toggle("Unknown amount first", isOn: $work.indeterminateFirst).toggleStyle(.kitCheckbox)
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

/// One effect on the Effects page: what it's for, its code line and what it plays on.
private struct EffectDemo: Identifiable {
  enum Host {
    /// Buttons that play their own effect: title, symbol, effect, primary.
    case buttons([(String, String, KitEffect, Bool)])
    /// A card with a title and an optional second line, played by a Play button.
    case card(String, String?)
  }

  let name: String
  let effect: KitEffect
  let note: String
  let code: String
  let host: Host
  var id: String { name }

  static func button(
    _ name: String, _ effect: KitEffect, note: String, code: String, title: String, systemImage: String,
    primary: Bool = false
  ) -> EffectDemo {
    EffectDemo(name: name, effect: effect, note: note, code: code, host: .buttons([(title, systemImage, effect, primary)]))
  }

  static func card(_ name: String, _ effect: KitEffect, note: String, code: String, title: String = "Trip to Lisbon",
                   detail: String? = nil) -> EffectDemo {
    EffectDemo(name: name, effect: effect, note: note, code: code, host: .card(title, detail))
  }

  /// Every effect this demo plays (a host with several buttons plays several).
  var effects: [KitEffect] {
    switch host {
    case .buttons(let buttons): buttons.map(\.2)
    case .card: [effect]
    }
  }
}

struct EffectsPage: View {
  @State private var counts: [KitEffect: Int] = [:]
  /// Replays every effect on a loop (`--cycle` starts it, for captures).
  @State private var cycling = ProcessInfo.processInfo.arguments.contains("--cycle")

  private static let feedback: [EffectDemo] = [
    .card(".success", .success, note: "It worked: a green wash and a small pop", code: "view.effect(.success, on: saved)"),
    .card(".failure", .failure, note: "It didn't: a red wash and a shake", code: "view.effect(.failure, on: failures)"),
    .card(".pop", .pop, note: "Something arrived: a quick scale", code: "view.effect(.pop, on: arrivals)"),
    .card(".wash", .wash, note: "Something landed: an accent wash", code: "view.effect(.wash, on: drops)"),
    .card(".pulse", .pulse, note: "Look here: a ring that grows", code: "view.effect(.pulse, on: highlights)"),
  ]

  private static let flourishes: [EffectDemo] = [
    .button(".burst", .burst, note: "Worth celebrating: confetti", code: "Button(\"Publish\") { … }.effect(.burst, on: published)",
            title: "Publish", systemImage: "checkmark.seal", primary: true),
    .button(".fountain", .fountain(), note: "Earned: symbols spray up and fall back",
            code: "view.effect(.fountain(\"star.fill\", .yellow), on: streak)", title: "Claim", systemImage: "trophy"),
    EffectDemo(
      name: ".float", effect: .float(), note: "Kept or counted: the symbol rises",
      code: "Button(\"Like\") { … }.effect(.float(\"heart.fill\", .pink), on: likes)",
      host: .buttons([
        ("Like", "heart", .float("heart.fill", .pink), false), ("Star", "star", .float("star.fill", .yellow), false),
        ("Add", "plus", .float(), false),
      ])),
    EffectDemo(
      name: ".send", effect: .send(), note: "Sent off: the symbol flies away",
      code: "Button(\"Send\") { … }.effect(.send(\"paperplane.fill\"), on: sent)",
      host: .buttons([
        ("Send", "paperplane", .send(), true), ("Push", "arrow.up", .send("arrow.up.circle.fill", .green), false),
      ])),
    .card(".receive", .receive(), note: "Came in: the symbol drops in and sinks",
          code: "row.effect(.receive(\"arrow.down.circle.fill\"), on: downloads)", title: "Downloads",
          detail: "3 files"),
    .card(".poof", .poof, note: "Gone: grey puffs blow away", code: "list.effect(.poof, on: cleared)",
          title: "Drafts", detail: "Cleared"),
    .button(".sparkle", .sparkle, note: "New or generated: stars twinkle",
            code: "Button(\"Summarize\") { … }.effect(.sparkle, on: summaries)", title: "Summarize",
            systemImage: "sparkles"),
    .card(".stamp", .stamp(), note: "Approved: the symbol stamps down",
          code: "card.effect(.stamp(\"checkmark.seal.fill\", .green), on: approvals)", title: "Pull request #42",
          detail: "Review"),
  ]

  private static let light: [EffectDemo] = [
    .card(".shimmer", .shimmer, note: "Refreshed: a band of light sweeps across", code: "card.effect(.shimmer, on: lastRefresh)",
          title: "Inbox", detail: "Updated just now"),
    .card(".glow", .glow, note: "Ready: a soft halo blooms", code: "view.effect(.glow, on: connected)",
          title: "Studio Mac", detail: "Connected"),
    .card(".ripple", .ripple, note: "Reached: rings ripple out", code: "view.effect(.ripple, on: pings)",
          title: "Nearby", detail: "Pinged 2 devices"),
    .card(".trace", .trace, note: "Came full circle: a light runs around the edge", code: "view.effect(.trace, on: syncs)",
          title: "Vault", detail: "Synced"),
  ]

  private static let moves: [EffectDemo] = [
    .card(".wiggle", .wiggle, note: "Not now: a short tilt", code: "row.effect(.wiggle, on: lockedTaps)",
          title: "Archive is locked"),
    .card(".bounce", .bounce, note: "Here it is: a hop and a squash", code: "row.effect(.bounce, on: arrivals)",
          title: "New message", detail: "From Ana"),
    .card(".jelly", .jelly, note: "Snapped in: a wobble that settles", code: "tile.effect(.jelly, on: drops)",
          title: "Moved to Done"),
    .card(".heartbeat", .heartbeat, note: "Still alive: two quick beats", code: "view.effect(.heartbeat, on: heartbeats)",
          title: "Server", detail: "Live"),
    .card(".nudge", .nudge, note: "This way: a nudge to the trailing side", code: "view.effect(.nudge, on: hints)",
          title: "Swipe for more"),
  ]

  var body: some View {
    CatalogPage(page: .effects) {
      section(
        "Effects", note: "Apps report the event; the kit decides the look. Nothing plays in an inactive window.",
        Self.feedback)
      section(
        "Flourishes",
        note: "Bigger moments: pieces leave the view or land on it. They draw outside the view, so give it room; "
          + "Reduce Motion keeps only a wash of their colour.",
        Self.flourishes)
      section("Light", note: "Drawn on or around the view's edge.", Self.light)
      section("Moves", note: "The view itself moves; its layout doesn't.", Self.moves)
    }
    // Captures run in a background window, where effects never play.
    .transformEnvironment(\.kitWindowIsActive) { if cycling { $0 = true } }
    .task(id: cycling) {
      while cycling, !Task.isCancelled {
        for demo in Self.feedback + Self.flourishes + Self.light + Self.moves {
          for effect in demo.effects { bump(effect) }
        }
        try? await Task.sleep(for: .seconds(1.6))
      }
    }
  }

  private func section(_ title: String, note: String, _ demos: [EffectDemo]) -> some View {
    SpecimenSection(title, note: note) {
      SpecimenGrid(minWidth: 280) {
        ForEach(demos) { demo in
          Specimen(demo.name, note: demo.note, padding: title == "Effects" ? 16 : 40, code: demo.code) {
            host(demo)
          }
        }
      }
    }
  }

  @ViewBuilder private func host(_ demo: EffectDemo) -> some View {
    switch demo.host {
    case .buttons(let buttons):
      Flow(spacing: 10) {
        ForEach(buttons.indices, id: \.self) { i in
          let (title, symbol, effect, primary) = buttons[i]
          Button(title, systemImage: symbol) { bump(effect) }
            .buttonStyle(primary ? .kitPrimary : .kit)
            .effect(effect, on: count(effect))
        }
      }
    case .card(let title, let detail):
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
          if let detail { Text(detail).kitFont(.caption).foregroundStyle(.kitSecondary) }
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 150, minHeight: detail == nil ? 36 : 48, alignment: .leading)
        .kitSurface(.card)
        .effect(demo.effect, on: count(demo.effect), cornerRadius: KitMetrics.radiusCard)
        Button("Play") { bump(demo.effect) }.buttonStyle(.kit).controlSize(.small)
      }
    }
  }

  private func count(_ effect: KitEffect) -> Int { counts[effect, default: 0] }
  private func bump(_ effect: KitEffect) { counts[effect, default: 0] += 1 }
}
