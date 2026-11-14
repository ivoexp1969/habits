import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'diag_log.dart';

/// Pushes today's habit progress to the home-screen widget — Android
/// ([HabitWidgetProvider]) and iOS (WidgetKit `HabitWidget`, reading the same
/// keys from the shared App Group). All strings are already localized by the
/// caller; this only stores them and asks the widget to redraw. A no-op /
/// silent on failure (e.g. no widget added, or a platform without one).
class WidgetService {
  static const String _androidWidget = 'HabitWidgetProvider';
  static const String _iosWidget = 'HabitWidget';
  // Shared container between the app and the iOS widget extension. Must match
  // the App Group added to BOTH targets in Xcode (see IOS_WIDGET.md).
  static const String _appGroupId = 'group.com.ivoexp.habits';

  /// Local calendar day the pushed data belongs to, "yyyy-MM-dd". Deliberately
  /// LOCAL (DateTime.now()), never UTC — so a 01:30 local time isn't read as the
  /// previous UTC day. Written under `widget_data_day`; the native widgets
  /// compare it with their own local "today" to decide fresh vs. stale.
  static String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Freshness of pushed widget data given its [dataDay] ("yyyy-MM-dd") and the
  /// local clock [now]. SPEC mirrored 1:1 in HabitWidget.swift (dayState) and
  /// HabitWidgetProvider.kt (dayState):
  ///   -1 = no key (old installs) → keep OLD behaviour (show pushed values)
  ///    0 = today or future (incl. clock moved back) → show real values
  ///    1 = exactly yesterday → show 0 / N, keep the streak
  ///    2 = 2+ days old → show 0 / N, hide the streak
  /// Uses lexicographic compare of ISO date strings (correct ordering) + a
  /// Calendar-built "yesterday", so DST / API level never matter.
  @visibleForTesting
  static int widgetDayState(String? dataDay, DateTime now) {
    if (dataDay == null || dataDay.isEmpty) return -1;
    final f = DateFormat('yyyy-MM-dd');
    final today = f.format(DateTime(now.year, now.month, now.day));
    final yesterday = f.format(DateTime(now.year, now.month, now.day - 1));
    if (dataDay.compareTo(today) >= 0) return 0;
    if (dataDay == yesterday) return 1;
    return 2;
  }

  /// True if an ISO-week start (Monday) OR a month start fell in the interval
  /// (dataDay, today]. At such a boundary the period-aware zero the app pushed
  /// (computed for an earlier midnight) is no longer valid for weekly/monthly
  /// habits, so the native widgets show a plain "0 / N" for ALL. SPEC mirrored
  /// in HabitWidget.swift (crossedPeriodBoundary) + HabitWidgetProvider.kt.
  /// Local only. ISO week: Monday is the first day.
  @visibleForTesting
  static bool widgetCrossedPeriodBoundary(String? dataDay, DateTime now) {
    if (dataDay == null || dataDay.isEmpty) return false;
    final a = DateTime.tryParse(dataDay);
    if (a == null) return false;
    final data = DateTime(a.year, a.month, a.day);
    final today = DateTime(now.year, now.month, now.day);
    if (!data.isBefore(today)) return false; // today/future → no stale boundary
    // Month (or year) boundary.
    if (data.year != today.year || data.month != today.month) return true;
    // ISO week boundary: the Monday that starts each date's week differs.
    DateTime mondayOf(DateTime d) =>
        DateTime(d.year, d.month, d.day - (d.weekday - 1));
    return mondayOf(data) != mondayOf(today);
  }

  static Future<void> push({
    required String title,
    required String date,
    required String countLine,
    required int percent,
    required String streakLine,
    required String message,
    // The "new day" variants of the values that depend on today's progress.
    // The iOS widget paints these at the next local midnight (see
    // HabitWidget.swift) so a glanced widget rolls over on its own without the
    // app. PERIOD-AWARE: daily habits reset, weekly/monthly keep their fill, so
    // these are computed by the caller (not a blind "0 / N").
    required String countLineZero,
    required int percentZero,
    required String messageZero,
    // What triggered this push (check-in / load / new-day) — logged so the
    // diagnostics screen shows WHEN the app asked WidgetKit to reload.
    String reason = 'push',
  }) async {
    try {
      // iOS reads widget data from the App Group's UserDefaults; the group id
      // must be set before saving. No-op path on Android (uses its own store).
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(_appGroupId);
      }
      await HomeWidget.saveWidgetData<String>('widget_title', title);
      await HomeWidget.saveWidgetData<String>('widget_date', date);
      await HomeWidget.saveWidgetData<String>('widget_count_line', countLine);
      await HomeWidget.saveWidgetData<int>(
          'widget_percent', percent.clamp(0, 100));
      await HomeWidget.saveWidgetData<String>('widget_streak_line', streakLine);
      await HomeWidget.saveWidgetData<String>('widget_message', message);
      await HomeWidget.saveWidgetData<String>(
          'widget_count_line_zero', countLineZero);
      await HomeWidget.saveWidgetData<int>(
          'widget_percent_zero', percentZero.clamp(0, 100));
      await HomeWidget.saveWidgetData<String>('widget_message_zero', messageZero);
      // Local day the above values are for → native widgets flip to 0/N once
      // their own "today" differs from this (midnight rollover without the app).
      await HomeWidget.saveWidgetData<String>('widget_data_day', _todayKey());
      await HomeWidget.updateWidget(
        androidName: _androidWidget,
        iOSName: _iosWidget,
      );
      // On iOS updateWidget → WidgetCenter.reloadTimelines(ofKind:) — log that
      // the app asked WidgetKit to rebuild, with the trigger + the values sent.
      unawaited(DiagLog.add(
          'widget reloadTimelines ($reason) now=[$countLine $percent%] zero=[$countLineZero $percentZero%]'));
    } catch (_) {
      // Widget not present / platform without the widget → ignore.
    }
  }

  /// Reads the widget extension's own diagnostics log from the App Group (what
  /// WidgetKit did in getTimeline), newline-joined, most-recent first. iOS only.
  static Future<List<String>> readWidgetLog() async {
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(_appGroupId);
      }
      final raw = await HomeWidget.getWidgetData<String>('widget_diag_log');
      if (raw == null || raw.isEmpty) return const [];
      return raw.split('\n').reversed.toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clearWidgetLog() async {
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(_appGroupId);
      }
      await HomeWidget.saveWidgetData<String>('widget_diag_log', '');
    } catch (_) {}
  }

  /// Rolls the widget over to the "new day" state (0 / N, zero message, 0%)
  /// using the variants the app last pushed. Safe to call from a background
  /// isolate (the Android midnight alarm) where there is no l10n/UI — it only
  /// copies already-localized strings, computing nothing. On iOS the WidgetKit
  /// timeline handles midnight on its own, so this is mainly for Android.
  static Future<void> pushNewDayZero() async {
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(_appGroupId);
      }
      final countZero =
          await HomeWidget.getWidgetData<String>('widget_count_line_zero');
      final messageZero =
          await HomeWidget.getWidgetData<String>('widget_message_zero');
      // Period-aware percent at the new day (weekly/monthly keep their fill).
      final percentZero =
          await HomeWidget.getWidgetData<int>('widget_percent_zero') ?? 0;
      if (countZero != null) {
        await HomeWidget.saveWidgetData<String>('widget_count_line', countZero);
      }
      if (messageZero != null) {
        await HomeWidget.saveWidgetData<String>('widget_message', messageZero);
      }
      await HomeWidget.saveWidgetData<int>('widget_percent', percentZero);
      // The zeroed values are for TODAY (the new day) → stamp today.
      await HomeWidget.saveWidgetData<String>('widget_data_day', _todayKey());
      await HomeWidget.updateWidget(
        androidName: _androidWidget,
        iOSName: _iosWidget,
      );
    } catch (_) {
      // No widget / no prior push yet → ignore.
    }
  }
}
