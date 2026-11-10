import 'dart:io';

import 'package:home_widget/home_widget.dart';

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
      await HomeWidget.updateWidget(
        androidName: _androidWidget,
        iOSName: _iosWidget,
      );
    } catch (_) {
      // Widget not present / platform without the widget → ignore.
    }
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
      await HomeWidget.updateWidget(
        androidName: _androidWidget,
        iOSName: _iosWidget,
      );
    } catch (_) {
      // No widget / no prior push yet → ignore.
    }
  }
}
