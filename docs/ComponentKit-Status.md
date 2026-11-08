# ComponentKit: Status and badges

How the kit shows work, events and small facts: `WorkStatus`, live icons, effects, counts, chips and progress. Part
of [ComponentKit](ComponentKit.md).

The rule: a piece of work's state lives in its live icon (the ring carries progress, then settles green with a check
or red), never in a spinner or a bare progress bar. Apps report the state; the kit decides how it looks.

```swift
@State private var build = WorkStatus.idle

HStack {
  LiveIcon(systemImage: "hammer", status: build)
  Text("Build").kitFont(.headline)
  Count(3, .attention)
}
.status(build)                                     // plays success or failure when the build finishes

Button("Push") { push() }.effect(.success, on: pushedCount)
```

## Work status

`WorkStatus` is what a piece of work is doing: `.idle`, `.waiting` (queued, not started), `.working(progress:)`
(`nil` progress shows the work indicator), `.paused(progress:)`, `.done`, `.failed(_:)`. `.working` and `.failed` are
shorthands without arguments. `isWorking`, `isFinished`, `progress` and `hue` read it.

Kit views that take `status:` (sections, rows, sheets, the toolbar title, form rows, fields, run blocks) draw it the
same way everywhere.

## Icons

| API | What it is |
|---|---|
| `LiveIcon(systemImage:hue:status:size:shape:)`, `LiveIcon(letters:…)` | A tile that carries work: the ring shows progress (or the work indicator), then a green check or a red mark. A generic initializer takes any glyph. |
| `Tile(systemImage:hue:size:style:)`, `Tile(letters:…)` | The icon tile without work: `.soft` (the hue at 15%), `.solid` or `.plain`. |
| `KitShape` | `.rounded` for agents and things, `.circle` for people. |
| `kitWorkIndicator(_:)`, `KitWorkIndicator` | How live icons below show work of unknown length: `.bloom` (the default), `.trace`, `.comet`, `.pulse`, `.breathe`, `.march`, `.ripple`, `.glow`, `.heartbeat`, `.sonar`. |
| `kitGlyphSize` (environment) | The size a drawn glyph should take inside a tile. |

## Effects

| API | What it is |
|---|---|
| `effect(_:on:cornerRadius:)` | Plays a `KitEffect` once each time a value changes. It draws in an overlay (layout never moves), plays nothing in an unfocused window, and keeps only the colour under Reduce Motion. |
| `status(_:cornerRadius:)` | Plays `.success` or `.failure` when a `WorkStatus` finishes. |
| `KitEffect` | `.success`, `.failure`, `.pop`, `.wash`, `.pulse`, `.burst` (confetti), `.fountain(_:_:)`, `.float(_:_:)`, `.send(_:_:)`. |

## Status lines and pills

| API | What it is |
|---|---|
| `KitStatusPill(_:systemImage:hue:status:)` | A short status floating over content ("Reconnecting…"). Generic forms take any icon and content. |
| `StatusLabel(_:hue:isHollow:)` | A dot and a word: a connection's state, a sync line. |
| `StatusDot(hue:isHollow:size:)` | A 7pt dot, or a hollow ring for "not yet". |
| `StepNumber(_:isCurrent:)` | A step's number in the tile shape. |

## Counts and chips

| API | What it is |
|---|---|
| `Count(_:_:)`, `Count.Meaning` | A bare number whose colour says what it means: `.info` gray, `.attention` orange, `.failed` red. A text form takes "31 of 48". |
| `SyncCounts(changes:ahead:behind:)` | Local changes, commits to push and to pull. |
| `LineCounts(added:removed:)`, `Diffstat(added:removed:showsCounts:)` | "+14 −2" and the five-block diffstat. |
| `Chip(_:systemImage:hue:style:)`, `Chip.Style` | A label in the tile shape: `.soft`, `.solid`, `.quiet`. `Chip(status:)` colours a status word, `Chip(type:)` a value's type; `Chip.production` and `Chip.readOnly` are ready-made. |
| `FilterToken` | An active filter in a filter bar, with its remove button. |
| `RefChip`, `RefChips`, `RefChip.Ref`, `BranchGlyph` | Git refs as chips (branch, remote, tag, HEAD), a commit's refs in a row with `+N`, and the branch glyph. |
| `Avatar(name:letters:kind:systemImage:hue:status:presence:size:)` | Who or what something is: the shape says the kind (`.person`, `.agent`, `.thing`, `.app`), `StableHue` picks the colour from the name. Other forms take an `Image`, image bytes or a URL. `Presence`: `.online`, `.away`, `.offline`. |

## Progress

| API | What it is |
|---|---|
| `KitProgressBar(value:secondary:hue:)`, `KitProgressBar(status:secondary:hue:)` | A bar that stretches to its width; the status form takes the state's hue. |
| `KitProgressEstimate(status:line:…)`, `KitProgressEstimate(status:startedAt:…)` | A bar with how it is going beside it: the app's own line, or the time left estimated from the start. |
| `MicroBar(value:hue:width:)`, `ProgressRow(value:)` | A small bar for rows and meta lines; a bar with its percent. |
| `SidebarRow.progress(_:secondary:status:)` | A row's progress under its title (see [Containers](ComponentKit-Containers.md#sidebar)). |
