import 'package:home_widget/home_widget.dart';

/// Pushes today's habit progress to the Android home-screen widget
/// ([HabitWidgetProvider]). All strings are already localized by the caller;
/// this only stores them and asks the widget to redraw. A no-op / silent on
/// failure (e.g. no widget added, or non-Android platforms).
class WidgetService {
  static const String _androidWidget = 'HabitWidgetProvider';

  static Future<void> push({
    required String title,
    required String date,
    required String countLine,
    required int percent,
    required String streakLine,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('widget_title', title);
      await HomeWidget.saveWidgetData<String>('widget_date', date);
      await HomeWidget.saveWidgetData<String>('widget_count_line', countLine);
      await HomeWidget.saveWidgetData<int>(
          'widget_percent', percent.clamp(0, 100));
      await HomeWidget.saveWidgetData<String>('widget_streak_line', streakLine);
      await HomeWidget.updateWidget(androidName: _androidWidget);
    } catch (_) {
      // Widget not present / platform without the widget → ignore.
    }
  }
}
