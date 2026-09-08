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
      await HomeWidget.updateWidget(
        androidName: _androidWidget,
        iOSName: _iosWidget,
      );
    } catch (_) {
      // Widget not present / platform without the widget → ignore.
    }
  }
}
