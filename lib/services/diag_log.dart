import 'package:shared_preferences/shared_preferences.dart';

/// Tiny persisted ring buffers of the last diagnostic events. A problem seen in
/// the morning (new-day reset / cloud sync / account link) survives a restart
/// here, so it can be inspected on-device via the hidden diagnostics screen
/// (7 taps on the version row in Settings). Best-effort and silent on failure.
///
/// TWO channels so frequent widget / sync writes never push out the rarer but
/// critical AUTH events (account link / merge / sign-out):
///   * default — general events, cap [_max];
///   * auth    — account identity events, its OWN buffer, cap [_authMax] (200),
///               untouched by the default channel.
class DiagLog {
  static const String _key = 'diag_events';
  static const int _max = 50;
  static const String _authKey = 'diag_events_auth';
  static const int _authMax = 200;

  /// Logs [event]. Pass `auth: true` for account/identity events so they land in
  /// the separate, larger auth buffer (not displaced by widget/sync spam).
  static Future<void> add(String event, {bool auth = false}) async {
    await _addTo(auth ? _authKey : _key, auth ? _authMax : _max, event);
  }

  /// Convenience for account/identity events → the separate auth buffer.
  static Future<void> auth(String event) => add(event, auth: true);

  static Future<void> _addTo(String key, int max, String event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<String>.from(prefs.getStringList(key) ?? const []);
      final ts = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceFirst('T', ' ');
      list.add('$ts  $event');
      while (list.length > max) {
        list.removeAt(0);
      }
      await prefs.setStringList(key, list);
    } catch (_) {}
  }

  static Future<List<String>> _read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return List<String>.from(prefs.getStringList(key) ?? const []);
    } catch (_) {
      return const [];
    }
  }

  /// Both channels merged, most recent first (each line is timestamp-prefixed,
  /// so a descending string sort orders them chronologically).
  static Future<List<String>> recent() async {
    final all = [...await _read(_key), ...await _read(_authKey)];
    all.sort((a, b) => b.compareTo(a));
    return all;
  }

  /// Only the auth channel, most recent first.
  static Future<List<String>> recentAuth() async =>
      (await _read(_authKey)).reversed.toList();

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_authKey);
    } catch (_) {}
  }
}
