import ComponentKit
import SwiftUI

// MARK: - Counts

struct CountsPage: View {
  @State private var changes = 3
  @State private var step = 2

  var body: some View {
    CatalogPage(page: .counts) {
      SpecimenSection(
        "Counts", note: "A bare number: gray informs, orange waits on you, red failed. A changing number rolls."
      ) {
        Specimen("Meanings", code: "Count(17)\nCount(4, .attention)\nCount(1, .failed)\nCount(\"31 of 48\")") {
          Flow(spacing: 24, lineSpacing: 14, alignment: .top) {
            Labeled("info") { Count(17) }
            Labeled("attention") { Count(4, .attention) }
            Labeled("failed") { Count(1, .failed) }
            Labeled("text") { Count("31 of 48") }
            Labeled("disabled") { Count(12).disabled(true) }
            Labeled("rolling") {
              HStack(spacing: 8) {
                Count(changes, .attention)
                Button("Add", systemImage: "plus") { changes += 1 }.buttonStyle(.kitIcon)
                Button("Remove", systemImage: "minus") { changes = max(0, changes - 1) }.buttonStyle(.kitIcon)
              }
            }
          }
        }
        Specimen("Sync", note: "Zeros are left out: an up-to-date repository shows nothing", code: "SyncCounts(changes: 5, ahead: 2, behind: 1)") {
          Flow(spacing: 24, lineSpacing: 14, alignment: .top) {
            Labeled("all") { SyncCounts(changes: 5, ahead: 2, behind: 1) }
            Labeled("changes") { SyncCounts(changes: 12) }
            Labeled("to push") { SyncCounts(ahead: 3) }
            Labeled("to pull") { SyncCounts(behind: 7) }
            Labeled("up to date") { SyncCounts().frame(minWidth: 40, minHeight: 14) }
          }
        }
      }
      SpecimenSection("Steps and dots") {
        SpecimenGrid(minWidth: 320) {
          Specimen("Step numbers", code: "StepNumber(3, isCurrent: true)") {
            HStack(spacing: 6) {
              ForEach(1...5, id: \.self) { StepNumber($0, isCurrent: $0 == step) }
              Button("Next", systemImage: "chevron.right") { step = step % 5 + 1 }.buttonStyle(.kitIcon)
            }
          }
          Specimen("Status dots", code: "StatusDot(hue: .green)\nStatusDot(hue: .gray, isHollow: true)") {
            HStack(spacing: 14) {
              StatusDot(hue: .green)
              StatusDot(hue: .orange)
              StatusDot(hue: .red)
              StatusDot(hue: .blue)
              StatusDot(hue: .gray, isHollow: true)
              StatusDot(hue: .green, size: 10)
            }
          }
        }
      }
      SpecimenSection("In rows") {
        Specimen("Sidebar rows with counts", ground: .sidebar, code: "SidebarRow(\"Changes\", systemImage: \"pencil\") { Count(4, .attention) }") {
          VStack(spacing: 2) {
            SidebarRow("History", systemImage: "clock") { Count(17) }
            SidebarRow("Changes", systemImage: "pencil") { Count(4, .attention) }
            SidebarRow("Checks", systemImage: "checkmark.seal") { Count(1, .failed) }
            SidebarRow("atlas", subtitle: "main", systemImage: "shippingbox") { SyncCounts(changes: 2, ahead: 1, behind: 3) }
          }
          .frame(width: 280)
        }
      }
    }
  }
}

// MARK: - Labels (chips)

struct ChipsPage: View {
  @State private var filters = ["status = shipped", "city contains Lisbon"]
  var body: some View {
    CatalogPage(page: .chips) {
      SpecimenSection("Soft", note: "The hue at 16% (20% in dark) under the hue's text tone; neutral without a hue.") {
        Specimen("Status and neutral", code: "Chip(\"Syncing\", hue: .blue)\nChip(\"Swift\")") {
          VStack(alignment: .leading, spacing: 10) {
            Flow(spacing: 6) {
              Chip("Up to date", hue: .green)
              Chip("Syncing", hue: .blue)
              Chip("Pending", hue: .orange)
              Chip("Failed", hue: .red)
              Chip("Conflict", hue: .purple)
              Chip("Idle", hue: .gray)
              Chip("Draft", hue: .yellow)
            }
            Flow(spacing: 6) {
              Chip("Swift")
              Chip("+1")
              Chip("v1.1.0", systemImage: "tag")
              Chip("Pushing", systemImage: "arrow.up", hue: .blue)
            }
          }
        }
        Specimen("Safety", code: "Chip.production\nChip(\"Staging\", hue: .orange)\nChip.readOnly") {
          Flow(spacing: 6) {
            Chip.production
            Chip("Staging", hue: .orange)
            Chip("Local", hue: .green)
            Chip("Replica", hue: .purple)
            Chip.readOnly
          }
        }
      }
      SpecimenSection("Quiet and solid") {
        Specimen("Styles", code: "Chip(\"Draft\", style: .quiet)\nChip(Text(\"a1b2c3d\").monospaced(), style: .quiet)\nChip(\"Production\", systemImage: \"shield\", hue: .red, style: .solid)") {
          Flow(spacing: 6) {
            Chip("Draft", style: .quiet)
            Chip(Text("a1b2c3d").monospaced(), style: .quiet)
            Chip("Production", systemImage: "shield", hue: .red, style: .solid)
            Chip("Release", hue: .indigo, style: .solid)
          }
        }
      }
      SpecimenSection("From words and types") {
        Specimen("Status words, value types", code: "Chip(status: order.status)\nChip(type: column.type)") {
          VStack(alignment: .leading, spacing: 10) {
            Flow(spacing: 6) {
              ForEach(["shipped", "pending", "cancelled", "refunded", "running", "Lisbon"], id: \.self) { Chip(status: $0) }
            }
            Flow(spacing: 6) {
              ForEach(["TEXT", "INT32", "JSONB", "SET", "ZSET", "UUID", "BOOL", "BYTEA"], id: \.self) { Chip(type: $0) }
            }
          }
        }
      }
      SpecimenSection("Sizes and states") {
        SpecimenGrid(minWidth: 300) {
          Specimen("Small", note: "For section headers and toolbar titles", code: "Chip.production.controlSize(.small)") {
            Flow(spacing: 6) {
              Chip.production
              Chip("Pushing", hue: .blue)
              Chip("Draft", style: .quiet)
            }
            .controlSize(.small)
          }
          Specimen("Disabled", code: "Chip(\"Syncing\", hue: .blue).disabled(true)") {
            Flow(spacing: 6) {
              Chip("Syncing", hue: .blue)
              Chip("Staging", hue: .orange)
            }
            .disabled(true)
          }
          Specimen("Long text", code: "Chip(longName).frame(maxWidth: 160)") {
            Chip("refactor/sidebar-reorder-across-sections", hue: .orange).frame(maxWidth: 180, alignment: .leading)
          }
        }
      }
      SpecimenSection("Filter tokens", note: "An active filter with its remove button: the condition on a soft token.") {
        Specimen(
          "FilterToken",
          code: "FilterToken(filter.summary) { remove(filter) }\nFilterToken(Text(\"total > \") + Text(\"100\").bold(), hue: .orange) { … }"
        ) {
          Flow(spacing: 6) {
            ForEach(filters, id: \.self) { filter in
              FilterToken(filter) { withKitAnimation { filters.removeAll { $0 == filter } } }
            }
            FilterToken(Text("total > ") + Text("100").bold(), hue: .orange) {}
            if filters.isEmpty {
              Button("Reset") { withKitAnimation { filters = ["status = shipped", "city contains Lisbon"] } }.buttonStyle(.kitPlain)
            }
          }
        }
      }
    }
  }
}

// MARK: - Refs

struct RefsPage: View {
  @State private var picked = "none"

  let many: [RefChip.Ref] = [
    .init(name: "release/2026.10-hotfix-payments", detail: "Branch · not pushed"),
    .init(name: "main", isCurrent: true, detail: "HEAD · 2 to push"),
    .init(name: "origin/main", kind: .remote, detail: "fetched 2 hr ago"),
    .init(name: "v1.12.0-beta.3", kind: .tag, detail: "Tag · Oct 13"),
    .init(name: "testflight/1.12.0-beta.3-1842", kind: .tag, detail: "Tag · Oct 13"),
  ]

  var body: some View {
    CatalogPage(page: .refs) {
      SpecimenSection("Ref chips", note: "HEAD's branch in the accent, local branches orange, tags and remotes gray.") {
        Specimen(
          "Kinds",
          code: """
            RefChip(name: "main", isCurrent: true)
            RefChip(name: "origin/feature/offline-maps", kind: .remote)
            RefChip(name: "v1.4.0", kind: .tag)
            RefChip(name: "fix/date-parsing", hasUpstream: true)
            """
        ) {
          VStack(alignment: .leading, spacing: 10) {
            Flow(spacing: 6) {
              RefChip(name: "main", isCurrent: true)
              RefChip(name: "feature/sidebar")
              RefChip(name: "origin/main", kind: .remote)
              RefChip(name: "v1.4.0", kind: .tag)
              RefChip(name: "fix/date-parsing", hasUpstream: true)
              RefChip(name: "a1b2c3d", kind: .head)
            }
            Labeled("Small") {
              Flow(spacing: 6) {
                RefChip(name: "main", isCurrent: true)
                RefChip(name: "v1.4.0", kind: .tag)
                RefChip(name: "origin/main", kind: .remote)
              }
              .controlSize(.small)
            }
            Labeled("A long name is cut in the middle") {
              RefChip(name: "origin/release/2026.10-hotfix-payments-rounding", kind: .remote)
            }
          }
        }
      }
      SpecimenSection(
        "A commit's refs", note: "Hover the chips for half a second, or click +N, for the card with every ref."
      ) {
        Specimen(
          "RefChips", code: "RefChips(commit.refs, maxVisible: isNarrow ? 1 : 2, meta: [\"0dd2b54\", message]) { select($0) }"
        ) {
          VStack(alignment: .leading, spacing: 12) {
            Labeled("Two visible") { RefChips(many, meta: ["0dd2b54", "Changelog: Started 1.12"]) { picked = $0.name } }
            Labeled("One visible (narrow)") { RefChips(many, maxVisible: 1) { picked = $0.name } }
            Labeled("A branch and its upstream fold into one chip") {
              RefChips([.init(name: "main"), .init(name: "origin/main", kind: .remote)])
            }
            Labeled("Not enough room: fewer chips") { RefChips(many).frame(width: 150, alignment: .leading) }
            Text("Picked: \(picked)").kitFont(.caption)
          }
        }
      }
      SpecimenSection("Pieces", note: "The branch glyph on its own, and a chip's detail in its tooltip.") {
        Specimen("BranchGlyph and detail", code: "BranchGlyph(size: 16)\nRefChip(name: \"main\", isCurrent: true, detail: \"HEAD · 2 to push\")") {
          Flow(spacing: 14) {
            BranchGlyph(size: 16)
            BranchGlyph(size: 20).foregroundStyle(Hue.green.fill)
            RefChip(name: "main", isCurrent: true, detail: "HEAD · 2 to push")
            RefChip(name: "origin/main", kind: .remote, detail: "fetched 2 hr ago")
          }
        }
      }
    }
  }
}

// MARK: - Line counts and progress

struct LineCountsPage: View {
  @State private var progress = 0.25

  var body: some View {
    CatalogPage(page: .lineCounts) {
      SpecimenSection("Line counts and diffstats") {
        Specimen("LineCounts and Diffstat", code: "LineCounts(added: 14, removed: 2)\nDiffstat(added: 14, removed: 2)\nDiffstat(added: 54, removed: 122, showsCounts: false)") {
          VStack(alignment: .leading, spacing: 10) {
            Flow(spacing: 24, lineSpacing: 14, alignment: .top) {
              Labeled("both") { LineCounts(added: 14, removed: 2) }
              Labeled("added only") { LineCounts(added: 38, removed: 0) }
              Labeled("removed only") { LineCounts(added: 0, removed: 120) }
              Labeled("none") { LineCounts(added: 0, removed: 0) }
              Labeled("binary") { LineCounts(added: nil, removed: nil) }
            }
            Flow(spacing: 24, lineSpacing: 14, alignment: .top) {
              Labeled("diffstat") { Diffstat(added: 12, removed: 3) }
              Labeled("small change") { Diffstat(added: 2, removed: 1) }
              Labeled("bar alone") { Diffstat(added: 54, removed: 122, showsCounts: false) }
              Labeled("binary") { Diffstat(added: nil, removed: nil) }
            }
          }
        }
      }
      SpecimenSection("Progress in rows", note: "The work's state lives in the group's live icon; a row keeps a bar and its percent.") {
        Specimen("MicroBar and ProgressRow", code: "MicroBar(value: 0.4)\nMicroBar(value: 1, hue: .green, width: 28)\nProgressRow(value: 0.25)") {
          VStack(alignment: .leading, spacing: 12) {
            Flow(spacing: 18, lineSpacing: 12) {
              MicroBar(value: 0.4)
              MicroBar(value: 1, hue: .green, width: 28)
              MicroBar(value: 0.7, hue: .orange, width: 48)
              ProgressRow(value: progress)
              Labeled("inactive window") { ProgressRow(value: progress).environment(\.kitWindowIsActive, false) }
            }
            KitSlider("Progress", value: $progress).frame(width: 240)
          }
        }
        Specimen(
          "KitProgressBar", note: "Stretches to its width; a second value (buffered, available) sits softly behind.",
          code: "KitProgressBar(value: 0.4)\nKitProgressBar(value: played, secondary: buffered, hue: .red)\nKitProgressBar(status: .paused(progress: 0.6), secondary: 0.8)\nKitProgressBar(value: 0.55).controlSize(.large)"
        ) {
          VStack(alignment: .leading, spacing: 12) {
            KitProgressBar(value: progress)
            KitProgressBar(value: progress, secondary: min(progress + 0.3, 1), hue: .red)
            HStack(spacing: 12) {
              KitProgressBar(status: .paused(progress: 0.6), secondary: 0.8)
              KitProgressBar(status: .done)
              KitProgressBar(status: .failed)
            }
            KitProgressBar(value: progress).controlSize(.large)
          }
          .frame(maxWidth: 420)
        }
        Specimen("A download row", ground: .sidebar, code: "SidebarRow(file.name, systemImage: \"doc\") { ProgressRow(value: file.progress) }") {
          VStack(spacing: 2) {
            SidebarRow("ubuntu-26.04.iso", subtitle: "27.7 MB/s", systemImage: "opticaldisc") { ProgressRow(value: progress) }
            SidebarRow("Xcode.xip", subtitle: "Waiting", systemImage: "hammer") { ProgressRow(value: 0) }
          }
          .frame(maxWidth: 320)
        }
      }
      ProgressEstimateSpecimens()
    }
  }
}

// MARK: - Avatars

struct AvatarsPage: View {
  var body: some View {
    CatalogPage(page: .avatars) {
      SpecimenSection("People", note: "A solid circle in the hue's deep shade, picked from the name.") {
        Specimen("Sizes and presence", code: "Avatar(name: \"Maya Okafor\", presence: .online)") {
          Flow(spacing: 14, lineSpacing: 12) {
            Avatar(name: "Maya Okafor", size: 16)
            Avatar(name: "Maya Okafor")
            Avatar(name: "Maya Okafor", size: 32)
            Avatar(name: "Maya Okafor", size: 48)
            Labeled("online") { Avatar(name: "Rafael Silva", presence: .online, size: 32) }
            Labeled("away") { Avatar(name: "Aiko Tanaka", presence: .away, size: 32) }
            Labeled("offline") { Avatar(name: "Jonas Berg", presence: .offline, size: 32) }
          }
        }
      }
      SpecimenSection("Agents", note: "A soft square that wears the live icon's ring while it works.") {
        Specimen("States", code: "Avatar(name: \"coder-1\", kind: .agent, status: .working)") {
          Flow(spacing: 18, lineSpacing: 14, alignment: .top) {
            Labeled("idle") { Avatar(name: "planner", kind: .agent, size: 28) }
            Labeled("working") { Avatar(name: "coder-1", kind: .agent, status: .working, size: 28) }
            Labeled("60%") { Avatar(name: "artist", kind: .agent, status: .working(progress: 0.6), size: 28) }
            Labeled("done") { Avatar(name: "tester", kind: .agent, status: .done, size: 28) }
            Labeled("failed") { Avatar(name: "qa", kind: .agent, status: .failed, size: 28) }
            Labeled("offline") { Avatar(name: "coder-3", kind: .agent, presence: .offline, size: 28) }
          }
        }
      }
      SpecimenSection("Things and apps") {
        SpecimenGrid(minWidth: 360) {
          Specimen("Things", code: "Avatar(name: \"atlas\", kind: .thing)\nAvatar(name: \"Postgres\", letters: \"Pg\", kind: .thing, hue: .blue)") {
            Flow(spacing: 12) {
              Avatar(name: "atlas", kind: .thing)
              Avatar(name: "harbor", kind: .thing, size: 28)
              Avatar(name: "Catalog", letters: "Mg", kind: .thing, hue: .green)
              Avatar(name: "Analytics", letters: "Dk", kind: .thing, hue: .orange, size: 32)
              Avatar(name: "Database", kind: .thing, systemImage: "cylinder.split.1x2", size: 32)
            }
          }
          Specimen("Apps", code: "Avatar(name: \"Git\", kind: .app, systemImage: \"arrow.triangle.branch\", hue: .orange, size: 56)") {
            Flow(spacing: 12) {
              Avatar(name: "Git", kind: .app, systemImage: "arrow.triangle.branch", hue: .orange, size: 20)
              Avatar(name: "Markdown", kind: .app, systemImage: "text.alignleft", hue: .red, size: 28)
              Avatar(name: "Shell", kind: .app, systemImage: "terminal", hue: .gray, size: 40)
              Avatar(name: "Database", kind: .app, systemImage: "cylinder.split.1x2", hue: .blue, size: 56)
              Avatar(name: "Component", kind: .app, size: 56)
            }
          }
        }
      }
      SpecimenSection("Pictures", note: "A photo or an icon in the kind's shape; presence, rings and dimming as for drawn ones.") {
        Specimen("Avatar(name:image:)", code: "Avatar(name: user.name, image: photo, presence: .online, size: 32)\nAvatar(name: project.name, image: project.icon, kind: .thing)") {
          Flow(spacing: 14) {
            Avatar(name: "Maya Okafor", image: AppIcon.image(systemImage: "person.fill", hue: .pink), presence: .online, size: 32)
            Avatar(name: "atlas", image: AppIcon.image(systemImage: "shippingbox", hue: .blue), kind: .thing, size: 32)
            Avatar(name: "coder-1", image: AppIcon.image(systemImage: "cpu", hue: .purple), kind: .agent, status: .working, size: 32)
            Avatar(name: "Git", image: AppIcon.image(systemImage: "arrow.triangle.branch", hue: .orange), kind: .app, size: 44)
            Avatar(name: "Away", image: AppIcon.image(systemImage: "person.fill", hue: .teal), presence: .offline, size: 32)
          }
        }
      }
      PictureAvatarSpecimens()
    }
  }
}
