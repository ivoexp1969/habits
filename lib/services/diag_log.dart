import 'package:shared_preferences/shared_preferences.dart';

/// Tiny persisted ring buffer of the last diagnostic events. A problem seen in
/// the morning (new-day reset / cloud sync) survives a restart here, so it can
/// be inspected on-device via the hidden diagnostics screen (7 taps on the
/// version row in Settings). Best-effort and silent on failure.
class DiagLog {
  static const String _key = 'diag_events';
  static const int _max = 20;

  static Future<void> add(String event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<String>.from(prefs.getStringList(_key) ?? const []);
      final ts = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceFirst('T', ' ');
      list.add('$ts  $event');
      while (list.length > _max) {
        list.removeAt(0);
      }
      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  /// Most recent first.
  static Future<List<String>> recent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? const []).reversed.toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
