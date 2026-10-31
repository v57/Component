import Foundation

/// What a piece of work is doing. The kit draws it the same way everywhere: a live icon's ring, a run block, a
/// toolbar title. State and progress live in the icon, never in a spinner or a bare bar.
public enum WorkStatus: Hashable, Sendable {
  case idle
  /// Not started yet, in line behind other work (a workflow's later step, a queued download): a `LiveIcon` draws a
  /// bare dashed circle in the secondary colour, no tile and no ring, until the work starts.
  ///
  /// ```swift
  /// LiveIcon(systemImage: "hammer", status: step.hasStarted ? step.status : .waiting, size: 22)
  /// ```
  case waiting
  /// Running; `progress` is 0…1 when it's known, `nil` for the work indicator (amount unknown).
  case working(progress: Double? = nil)
  /// Stopped part way, waiting to resume.
  case paused(progress: Double? = nil)
  case done
  case failed(String? = nil)

  public static let working = WorkStatus.working(progress: nil)
  public static let failed = WorkStatus.failed(nil)

  public var isWorking: Bool { if case .working = self { true } else { false } }
  public var isFinished: Bool {
    switch self {
    case .done, .failed: true
    default: false
    }
  }

  /// Progress for the ring: known progress, 1 when finished, `nil` while indeterminate, idle or waiting.
  public var progress: Double? {
    switch self {
    case .working(let p), .paused(let p): p
    case .done, .failed: 1
    case .idle, .waiting: nil
    }
  }

  /// The hue the state speaks in: green done, red failed, gray paused, `nil` keeps the icon's own.
  public var hue: Hue? {
    switch self {
    case .done: .green
    case .failed: .red
    case .paused: .gray
    default: nil
    }
  }
}
