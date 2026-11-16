# ComponentKit: Status and badges

How the kit shows work, events and small facts: `WorkStatus`, live icons, effects, counts, chips and progress. Part
of [ComponentKit](ComponentKit.md).

<!-- platforms: macos ios linux=partial windows=partial android=planned -->

The rule: a piece of work's state lives in its live icon (the ring carries progress, then settles green with a check
or red), never in a spinner or a bare progress bar. Apps report the state; the kit decides how it looks.

```swift
@State private var build = WorkStatus.idle
@State private var pushedCount = 0

HStack {
  LiveIcon(systemImage: "hammer", status: build)
  Text("Build").kitFont(.headline)
  Count(3, .attention)
}
.status(build)                                     // plays success or failure when the build finishes

Button("Push") { pushedCount += 1 }.effect(.success, on: pushedCount)
```
<!-- preview: build-status -->

## Work status

`WorkStatus` is what a piece of work is doing:

- `.idle`: nothing is happening.
- `.waiting`: queued, not started. A live icon draws a bare dashed circle, with no tile and no ring.
- `.working(progress:)`: running. A `nil` progress shows the work indicator.
- `.paused(progress:)`: stopped part way. The icon turns gray.
- `.done`: green with a check.
- `.failed(_:)`: red with an exclamation mark. The message is what VoiceOver reads.

`.working` and `.failed` are shorthands without arguments. `isWorking`, `isFinished`, `progress` and `hue` read it.

```swift
@State private var status = WorkStatus.idle

HStack {
  LiveIcon(systemImage: "arrow.up", status: status)
  LiveIcon(letters: "Pg", hue: .blue, status: status, size: 28)
  LiveIcon(systemImage: "sparkles", hue: .purple, status: status, size: 36)
}
```
<!-- preview: live-icon -->

Kit views that take `status:` draw it the same way everywhere: sections, rows, sheets, the toolbar title, form rows,
fields and run blocks.

## Icons

```swift
LiveIcon(systemImage: "arrow.up", status: .working(progress: 0.4))
LiveIcon(systemImage: "hammer", status: step.hasStarted ? step.status : .waiting, size: 22)
Tile(systemImage: "folder", hue: .blue)
LiveIcon(systemImage: "sparkles", status: .working).kitWorkIndicator(.pulse)
```

| API | What it is |
|---|---|
| `LiveIcon(systemImage:hue:status:size:shape:)`, `LiveIcon(letters:…)` | A tile that carries work: the ring shows progress (or the work indicator), then a green check or a red mark. A generic initializer takes any glyph. |
| `Tile(systemImage:hue:size:style:)`, `Tile(letters:…)` | The icon tile without work: `.soft` (the hue at 15%), `.solid` or `.plain`. |
| `KitShape` | `.rounded` for agents and things, `.circle` for people. |
| `kitWorkIndicator(_:)`, `KitWorkIndicator` | How live icons below show work of unknown length: `.bloom` (the default), `.trace`, `.comet`, `.pulse`, `.breathe`, `.march`, `.ripple`, `.glow`, `.heartbeat`, `.sonar`. |
| `kitGlyphSize` (environment) | The size a drawn glyph should take inside a tile. |

## Effects

An effect is a short event on a view: it worked, it failed, something arrived. The app says when; the kit draws it.
An effect draws in an overlay, so the layout never moves. Quick repeats restart it, nothing plays in a window that
isn't focused, and Reduce Motion keeps only the colour.

```swift
Button("Push") { push() }.effect(.success, on: pushedCount)
Button("Like", systemImage: "heart") { like() }.effect(.float("heart.fill", .pink), on: likes)
Button("Publish") { publish() }.effect(.burst, on: publishedCount)
```
<!-- preview: effects -->

| API | What it is |
|---|---|
| `effect(_:on:cornerRadius:)` | Plays a `KitEffect` once each time a value changes. |
| `status(_:cornerRadius:)` | Plays `.success` or `.failure` when a `WorkStatus` finishes. |
| `KitEffect` | The effects, below. |

`KitEffect` comes in four groups:

- **Feedback**: `.success` (a green wash and a small pop), `.failure` (a red wash and a shake), `.pop` (a quick
  scale), `.wash` (an accent wash that fades), `.pulse` (a ring that grows and fades).
- **Flourishes**, pieces that leave the view or land on it: `.burst` (confetti), `.fountain(_:_:)` (a symbol sprays
  up and falls back), `.float(_:_:)` (a symbol rises and fades), `.send(_:_:)` (a symbol flies off up and to the
  right), `.receive(_:_:)` (a symbol drops in and sinks), `.poof` (gray puffs), `.sparkle` (small stars),
  `.stamp(_:_:)` (a seal on the top-trailing corner).
- **Light** on or around the view's edge: `.shimmer` (a band of light sweeps across), `.glow` (a soft halo),
  `.ripple` (three rings), `.trace` (a light runs once around the edge).
- **Moves**, the view itself: `.wiggle` (not now), `.bounce` (here it is), `.jelly` (snapped in), `.heartbeat` (still
  alive), `.nudge` (this way).

## Status lines and pills

```swift
StatusLabel("Connected", hue: .green)
StatusLabel("Not yet", hue: .gray, isHollow: true)
StepNumber(2, isCurrent: true)

.overlay(alignment: .topLeading) {
  if isWaiting {
    KitStatusPill("Waiting for the download", systemImage: "arrow.down", hue: .orange, status: .working)
      .padding(KitMetrics.gutter * 2)
  }
}
```

| API | What it is |
|---|---|
| `KitStatusPill(_:systemImage:hue:status:)` | A short status floating over content ("Reconnecting…"), on the floating surface. Generic forms take any icon and content. |
| `StatusLabel(_:hue:isHollow:)` | A dot and a word: a connection's state, a sync line. |
| `StatusDot(hue:isHollow:size:)` | A 7pt dot, or a hollow ring for "not yet". |
| `StepNumber(_:isCurrent:)` | A step's number in the tile shape. |

## Counts and chips

```swift
Count(17)
Count(4, .attention)
Chip("Syncing", hue: .blue)
Chip.production
Chip(status: "shipped")                            // green, from the word
RefChip(name: "main", isCurrent: true)
RefChip(name: "v1.4.0", kind: .tag).controlSize(.small)
Avatar(name: "Maya Okafor", presence: .online)
Avatar(name: "coder-1", kind: .agent, status: .working)
SyncCounts(changes: 3, ahead: 2, behind: 1)
Diffstat(added: 14, removed: 2)
```
<!-- preview: badges -->

| API | What it is |
|---|---|
| `Count(_:_:)`, `Count.Meaning` | A bare number whose colour says what it means: `.info` gray, `.attention` orange, `.failed` red. A text form takes "31 of 48". A changing number rolls to its new value. |
| `SyncCounts(changes:ahead:behind:)` | Local changes, commits to push and to pull. |
| `LineCounts(added:removed:)`, `Diffstat(added:removed:showsCounts:)` | "+14 −2" and the five-block diffstat. |
| `Chip(_:systemImage:hue:style:)`, `Chip.Style` | A label in the tile shape: `.soft`, `.solid`, `.quiet`. `Chip(status:)` colours a status word, `Chip(type:)` a value's type; `Chip.production` and `Chip.readOnly` are ready-made. `.controlSize(.small)` makes the small chip for headers. |
| `FilterToken` | An active filter in a filter bar, with its remove button. |
| `RefChip`, `RefChips`, `RefChip.Ref`, `BranchGlyph` | Git refs as chips (branch, remote, tag, HEAD), a commit's refs in a row with `+N`, and the branch glyph. |
| `Avatar(name:letters:kind:systemImage:hue:status:presence:size:)` | Who or what something is: the shape says the kind (`.person`, `.agent`, `.thing`, `.app`), `StableHue` picks the colour from the name. An agent wears the live icon's ring while it works. Other forms take an `Image`, image bytes or a URL. `Presence`: `.online`, `.away`, `.offline`. |

## Progress

A bar never stands alone for a piece of work: the live icon carries the state, and the bar adds how far it is.

```swift
KitProgressBar(value: played, secondary: buffered, hue: .red)
KitProgressBar(status: .paused(progress: 0.6))     // gray; green when done, red when failed
KitProgressEstimate(status: upload.status, startedAt: upload.started)
```
<!-- preview: progress -->

| API | What it is |
|---|---|
| `KitProgressBar(value:secondary:hue:)`, `KitProgressBar(status:secondary:hue:)` | A bar that stretches to its width; the status form takes the state's hue. |
| `KitProgressEstimate(status:line:…)`, `KitProgressEstimate(status:startedAt:…)` | A bar with how it is going beside it: the app's own line, or the time left estimated from the start. |
| `MicroBar(value:hue:width:)`, `ProgressRow(value:)` | A small bar for rows and meta lines; a bar with its percent. |
| `SidebarRow.progress(_:secondary:status:)` | A row's progress under its title (see [Containers](ComponentKit-Containers.md#sidebar)). |

## Related

- [Foundation](ComponentKit-Foundation.md): hues, tokens and motion the status views use.
- [Containers](ComponentKit-Containers.md): sections, rows and sheets that take a `status:`.
- [Data](ComponentKit-Data.md): run blocks, which carry a run's status in their live icon.
