import WidgetKit
import SwiftUI

// Home-screen widget for Навици — the iOS counterpart of the Android
// HabitWidgetProvider. The Flutter app pushes today's progress through
// home_widget, which stores each value under its plain key in the shared
// App Group's UserDefaults; this widget reads those keys directly. Every
// display string is already computed + localized in Flutter, so the widget
// only paints them (no logic, no localization here) — 1:1 with Android.

// Must match the App Group added to BOTH the Runner and this widget target
// in Xcode, and WidgetService._appGroupId on the Flutter side.
private let appGroupId = "group.com.ivoexp.habits"

// Brand violet, matching the Android widget_bg gradient (#5A4A9F → #7C4DFF).
// Note the 255.0 divisor: Color wants Double, and integer /255 would floor to 0.
private let brandStart = Color(red: 0x5A / 255.0, green: 0x4A / 255.0, blue: 0x9F / 255.0)
private let brandEnd = Color(red: 0x7C / 255.0, green: 0x4D / 255.0, blue: 0xFF / 255.0)
// Streak text tone, matching Android's #F3EFFF.
private let streakColor = Color(red: 0xF3 / 255.0, green: 0xEF / 255.0, blue: 0xFF / 255.0)

struct HabitEntry: TimelineEntry {
  let date: Date
  let title: String
  let countLine: String
  let percent: Int
  let streakLine: String
  let message: String
}

struct HabitProvider: TimelineProvider {
  // Today's progress as last pushed by the app, stamped at [date].
  private func read(at date: Date = Date()) -> HabitEntry {
    let defaults = UserDefaults(suiteName: appGroupId)
    let title = defaults?.string(forKey: "widget_title") ?? "Навици"
    let count = defaults?.string(forKey: "widget_count_line") ?? "0 / 0"
    let percent = defaults?.integer(forKey: "widget_percent") ?? 0
    let streak = defaults?.string(forKey: "widget_streak_line") ?? ""
    let message = defaults?.string(forKey: "widget_message") ?? ""
    return HabitEntry(
      date: date,
      title: title,
      countLine: count,
      percent: max(0, min(100, percent)),
      streakLine: streak,
      message: message)
  }

  // The "new day" state, painted at [date] (next midnight). Uses the
  // period-aware zero variants the app pushes: daily habits reset, but
  // weekly/monthly ones keep their fill — so count/percent are NOT a blind
  // "0 / N" but what progress actually survives into the new day. Streak is
  // kept — it still reflects the past until a day is actually missed.
  // [allZero] forces "0 / N" and 0% for ALL habits — used when a week/month
  // boundary was crossed, where the app's period-aware zero (weekly/monthly kept)
  // is no longer valid. The "0 / N" is derived from the pushed string (replace
  // the part before " / " with "0") so the localised format is preserved.
  private func readZero(at date: Date, hideStreak: Bool = false,
                        allZero: Bool = false) -> HabitEntry {
    let defaults = UserDefaults(suiteName: appGroupId)
    let title = defaults?.string(forKey: "widget_title") ?? "Навици"
    var count = defaults?.string(forKey: "widget_count_line_zero")
      ?? defaults?.string(forKey: "widget_count_line") ?? "0 / 0"
    if allZero, let r = count.range(of: " / ") { count = "0" + count[r.lowerBound...] }
    let percent = allZero ? 0 : (defaults?.integer(forKey: "widget_percent_zero") ?? 0)
    // 2+ days stale → the streak is no longer trustworthy, so hide it.
    let streak = hideStreak ? "" : (defaults?.string(forKey: "widget_streak_line") ?? "")
    let message = defaults?.string(forKey: "widget_message_zero") ?? ""
    return HabitEntry(
      date: date,
      title: title,
      countLine: count,
      percent: max(0, min(100, percent)),
      streakLine: streak,
      message: message)
  }

  // Local-only "yyyy-MM-dd" (en_US_POSIX, current time zone) — never UTC.
  private func todayKey() -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
  }

  // Mirrors WidgetService.widgetDayState (Dart) + dayState (Kotlin):
  //  -1 no key (old install) → old behaviour; 0 today/future; 1 yesterday;
  //  2 older. Lexicographic ISO compare + Calendar-built "yesterday".
  private func dayState(_ dataDay: String?) -> Int {
    guard let dd = dataDay, !dd.isEmpty else { return -1 }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    let cal = Calendar.current
    let today = f.string(from: Date())
    let yDate = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date())) ?? Date()
    let yesterday = f.string(from: yDate)
    if dd >= today { return 0 }
    if dd == yesterday { return 1 }
    return 2
  }

  // Mirrors WidgetService.widgetCrossedPeriodBoundary (Dart) + Kotlin: did an
  // ISO-week start (Monday) or a month start fall in (dataDay, today]? Uses the
  // .iso8601 calendar so weeks start on Monday. Local only.
  private func crossedPeriodBoundary(_ dataDay: String?) -> Bool {
    guard let dd = dataDay, !dd.isEmpty else { return false }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    guard let a = f.date(from: dd) else { return false }
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = .current
    let dataStart = cal.startOfDay(for: a)
    let todayStart = cal.startOfDay(for: Date())
    if dataStart >= todayStart { return false }
    let dc = cal.dateComponents([.year, .month], from: dataStart)
    let tc = cal.dateComponents([.year, .month], from: todayStart)
    if dc.year != tc.year || dc.month != tc.month { return true }
    let dMon = cal.dateInterval(of: .weekOfYear, for: dataStart)?.start
    let tMon = cal.dateInterval(of: .weekOfYear, for: todayStart)?.start
    return dMon != tMon
  }

  // Appends a line to a shared diagnostics log in the App Group (newline-joined
  // String under "widget_diag_log", capped at 20) — the Flutter app reads it via
  // home_widget and shows it on the hidden diagnostics screen, so we can see what
  // WidgetKit actually did overnight instead of guessing.
  private func widgetLog(_ msg: String) {
    guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
    let existing = defaults.string(forKey: "widget_diag_log") ?? ""
    var lines = existing.isEmpty ? [String]() : existing.components(separatedBy: "\n")
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
    lines.append("\(fmt.string(from: Date()))  [widget] \(msg)")
    if lines.count > 20 { lines.removeFirst(lines.count - 20) }
    defaults.set(lines.joined(separator: "\n"), forKey: "widget_diag_log")
  }

  func placeholder(in context: Context) -> HabitEntry {
    HabitEntry(
      date: Date(), title: "Навици", countLine: "0 / 0", percent: 0,
      streakLine: "", message: "")
  }

  func getSnapshot(
    in context: Context, completion: @escaping (HabitEntry) -> Void
  ) {
    completion(read())
  }

  func getTimeline(
    in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void
  ) {
    // Two entries: today's progress now, then a zeroed "new day" entry at the
    // next local midnight so the widget rolls over on its own even if the app
    // is never opened overnight. The app still pushes a reload (home_widget's
    // updateWidget → WidgetCenter.reloadAllTimelines) on every change, which
    // rebuilds this timeline with fresh data + the following midnight.
    let now = Date()
    let cal = Calendar.current
    let nextMidnight = cal.nextDate(
      after: now,
      matching: DateComponents(hour: 0, minute: 0, second: 5),
      matchingPolicy: .nextTime) ?? now.addingTimeInterval(24 * 60 * 60)
    // Is the pushed data for TODAY? If not, show the zeroed state NOW (not only
    // at the next-midnight entry) — read() alone would keep yesterday's numbers.
    let defaults = UserDefaults(suiteName: appGroupId)
    let dataDay = defaults?.string(forKey: "widget_data_day")
    let state = dayState(dataDay)
    // At a week/month boundary the pushed period-aware zero is invalid for
    // weekly/monthly habits → force "0 / N" for all.
    let boundary = crossedPeriodBoundary(dataDay)
    let cur: HabitEntry
    switch state {
    case 1: cur = readZero(at: now, hideStreak: false, allZero: boundary) // yesterday → 0/N, keep streak
    case 2: cur = readZero(at: now, hideStreak: true, allZero: boundary)  // 2+ days → 0/N, no streak
    default: cur = read(at: now)                                          // today/future OR no key → pushed values
    }
    let zero = readZero(at: nextMidnight)
    let entries = [cur, zero]
    let tf = DateFormatter()
    tf.dateFormat = "MM-dd HH:mm:ss"
    widgetLog(
      "getTimeline now=\(tf.string(from: now)) next=\(tf.string(from: nextMidnight)) "
        + "dataDay=\(dataDay ?? "nil") state=\(state) "
        + "cur=[\(cur.countLine) \(cur.percent)%] zero=[\(zero.countLine) \(zero.percent)%]")
    // Ask WidgetKit for a fresh timeline just after midnight, so the NEXT day's
    // midnight boundary gets scheduled even with the app still unopened.
    completion(Timeline(entries: entries, policy: .after(nextMidnight)))
  }
}

struct HabitWidgetEntryView: View {
  var entry: HabitEntry

  private var gradient: LinearGradient {
    LinearGradient(
      gradient: Gradient(colors: [brandStart, brandEnd]),
      startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(entry.title)
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundColor(.white)
        .lineLimit(1)
      Text(entry.countLine)
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundColor(.white)
        .lineLimit(1)
      // Horizontal progress bar: translucent-white track, white fill.
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.white.opacity(0.25))
          Capsule()
            .fill(Color.white)
            .frame(width: geo.size.width * CGFloat(entry.percent) / 100.0)
        }
      }
      .frame(height: 8)
      if !entry.streakLine.isEmpty {
        Text(entry.streakLine)
          .font(.system(size: 12, weight: .regular, design: .rounded))
          .foregroundColor(streakColor)
          .lineLimit(1)
      }
      if !entry.message.isEmpty {
        Text(entry.message)
          .font(.system(size: 12, weight: .regular, design: .rounded))
          .foregroundColor(.white.opacity(0.85))
          .lineLimit(2)
          .minimumScaleFactor(0.75) // свива текста да се побере на 2 реда, без отрязване
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetBrandBackground(gradient)
  }
}

// Paints the widget background across iOS versions: iOS 17 requires
// `containerBackground`; earlier versions use a plain `.background`.
extension View {
  @ViewBuilder
  func widgetBrandBackground(_ gradient: LinearGradient) -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(for: .widget) { gradient }
    } else {
      self.background(gradient)
    }
  }
}

struct HabitWidget: Widget {
  let kind: String = "HabitWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
      HabitWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Навици")
    .description("Днешен прогрес, брой и серия.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct HabitWidgetBundle: WidgetBundle {
  var body: some Widget {
    HabitWidget()
  }
}
