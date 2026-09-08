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
}

struct HabitProvider: TimelineProvider {
  private func read() -> HabitEntry {
    let defaults = UserDefaults(suiteName: appGroupId)
    let title = defaults?.string(forKey: "widget_title") ?? "Навици"
    let count = defaults?.string(forKey: "widget_count_line") ?? "0 / 0"
    let percent = defaults?.integer(forKey: "widget_percent") ?? 0
    let streak = defaults?.string(forKey: "widget_streak_line") ?? ""
    return HabitEntry(
      date: Date(),
      title: title,
      countLine: count,
      percent: max(0, min(100, percent)),
      streakLine: streak)
  }

  func placeholder(in context: Context) -> HabitEntry {
    HabitEntry(
      date: Date(), title: "Навици", countLine: "0 / 0", percent: 0,
      streakLine: "")
  }

  func getSnapshot(
    in context: Context, completion: @escaping (HabitEntry) -> Void
  ) {
    completion(read())
  }

  func getTimeline(
    in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void
  ) {
    // A single entry; the Flutter app triggers a reload (home_widget's
    // updateWidget → WidgetCenter.reloadAllTimelines) whenever progress
    // changes, so the widget need not self-schedule frequent refreshes.
    completion(Timeline(entries: [read()], policy: .never))
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
      HStack(alignment: .firstTextBaseline) {
        Text(entry.title)
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(.white)
          .lineLimit(1)
        Spacer(minLength: 6)
        Text(entry.countLine)
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.white)
          .lineLimit(1)
      }
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
          .font(.system(size: 12))
          .foregroundColor(streakColor)
          .lineLimit(1)
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
