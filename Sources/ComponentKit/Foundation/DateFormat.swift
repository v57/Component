import Foundation

/// How the kit writes a date next to now, the same in every app: a history's day and time, a list's clock column, a
/// row's "3 min ago". Months and weekdays follow the user's locale, and times the 12/24-hour setting.
///
/// ```swift
/// Text(commit.date.kitFormatted(.dayAndTime))   // "Today, 10:42"
/// Text(message.date.kitFormatted(.clock))       // "10:42", "Yesterday", "Mon", "Oct 8"
/// Text(fetch.date.kitFormatted(.ago))           // "3 min ago"
/// ```
public enum KitDateStyle: Hashable, Sendable {
  /// "just now", "3 min ago", "2 hr ago", "4 days ago"; from a week back the day, as `.day` writes it.
  case ago
  /// A list's clock: "now", "10:42" today, "Yesterday", the weekday within the week ("Mon"), then "Oct 8".
  case clock
  /// "Today", "Yesterday", "Oct 8"; "Oct 8, 2025" in another year.
  case day
  /// "Today, 10:42", "Yesterday, 18:03", "Oct 8, 17:20"; "Oct 8, 2025" in another year.
  case dayAndTime
  /// How long since: "1 min", "42 min", "3 h", "2 d" (how long an agent has worked, a session has run).
  case elapsed
}

extension Date {
  /// The date as `style` writes it, next to `now`.
  ///
  /// ```swift
  /// Text(session.started.kitFormatted(.elapsed))   // "42 min"
  /// ```
  public func kitFormatted(_ style: KitDateStyle, relativeTo now: Date = .now) -> String {
    let calendar = Calendar.current
    let seconds = now.timeIntervalSince(self)
    let thisYear = calendar.isDate(self, equalTo: now, toGranularity: .year)
    let day =
      thisYear
      ? formatted(.dateTime.month(.abbreviated).day()) : formatted(.dateTime.year().month(.abbreviated).day())
    let time = formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits))
    let isToday = calendar.isDate(self, inSameDayAs: now)
    let isYesterday = calendar.date(byAdding: .day, value: -1, to: now).map { calendar.isDate(self, inSameDayAs: $0) } ?? false
    switch style {
    case .ago:
      if seconds < 60 { return "just now" }
      if seconds < 3600 { return "\(Int(seconds / 60)) min ago" }
      if seconds < 86_400 { return "\(Int(seconds / 3600)) hr ago" }
      let days = Int(seconds / 86_400)
      if days < 7 { return days == 1 ? "1 day ago" : "\(days) days ago" }
      return day
    case .clock:
      if seconds < 60 { return "now" }
      if isToday { return time }
      if isYesterday { return "Yesterday" }
      if seconds < 6 * 86_400 { return formatted(.dateTime.weekday(.abbreviated)) }
      return day
    case .day:
      if isToday { return "Today" }
      if isYesterday { return "Yesterday" }
      return day
    case .dayAndTime:
      if isToday { return "Today, \(time)" }
      if isYesterday { return "Yesterday, \(time)" }
      return thisYear ? "\(day), \(time)" : day
    case .elapsed:
      return KitDuration.format(seconds)
    }
  }
}

/// Lengths of time as the kit writes them: "42 s", "3 min", "2 h 10 min" for how long something took or runs, and
/// "about 3 min left" for an estimate.
///
/// ```swift
/// Text(KitDuration.format(run.duration))       // "2 min 5 s"
/// Text(KitDuration.timeLeft(estimate.remaining)) // "about 3 min left"
/// ```
public enum KitDuration {
  /// "1 min" up to an hour (at least a minute), "3 h" up to a day, then "2 d"; with `seconds: true`, "42 s" under a
  /// minute and "2 min 5 s" under ten.
  public static func format(_ interval: TimeInterval, seconds showsSeconds: Bool = false) -> String {
    let total = max(0, Int(interval.rounded()))
    if showsSeconds {
      if total < 60 { return "\(total) s" }
      if total < 600 { return total % 60 == 0 ? "\(total / 60) min" : "\(total / 60) min \(total % 60) s" }
    }
    let minutes = max(1, total / 60)
    if minutes < 60 { return "\(minutes) min" }
    let hours = minutes / 60
    if hours < 24 { return minutes % 60 == 0 || hours >= 10 ? "\(hours) h" : "\(hours) h \(minutes % 60) min" }
    return "\(hours / 24) d"
  }

  /// An estimate of the time left, rounded as a person would say it: "less than a minute left", "about 3 min left",
  /// "about 1 h 20 min left", "about 2 d left".
  public static func timeLeft(_ interval: TimeInterval) -> String {
    let seconds = max(0, interval)
    if seconds < 60 { return "less than a minute left" }
    let minutes = Int((seconds / 60).rounded())
    if minutes < 60 { return "about \(minutes) min left" }
    let hours = minutes / 60
    if hours < 24 {
      let rest = (minutes % 60) / 10 * 10
      return rest == 0 || hours >= 10 ? "about \(hours) h left" : "about \(hours) h \(rest) min left"
    }
    return "about \(hours / 24) d left"
  }
}
