import 'habit_service.dart';

/// Pure streak computation over the GLOBAL daily-success history
/// (`Map<"yyyy-MM-dd", dayPercent 0..100>`). A day counts as a success when
/// its percent is at least [successThreshold].
///
/// The app persists only this global (all-habits-combined) daily percentage —
/// there is no per-habit daily record — so both the current and the best
/// streak are derived here, giving Stats (and anywhere else) a single shared
/// definition instead of the old copy inlined in the Stats screen.
class StreakService {
  /// A day is a "success" (extends the streak) at or above this percent.
  static const double successThreshold = 80.0;

  static DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool _isSuccess(Map<String, double> history, DateTime day) =>
      (history[dateKeyFromDate(day)] ?? 0.0) >= successThreshold;

  static DateTime? _parseKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Length of the streak ending today, counting consecutive success days
  /// backwards from today.
  static int currentStreak(Map<String, double> history) {
    int current = 0;
    DateTime cursor = _todayDate();
    while (_isSuccess(history, cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return current;
  }

  /// Longest run of consecutive success days anywhere in the history.
  static int bestStreak(Map<String, double> history) {
    final days = history.keys
        .map(_parseKey)
        .whereType<DateTime>()
        .toList()
      ..sort();

    int longest = 0;
    int streak = 0;
    DateTime? prev;
    for (final d in days) {
      if (_isSuccess(history, d)) {
        if (prev != null && d.difference(prev).inDays == 1) {
          streak++;
        } else {
          streak = 1;
        }
        if (streak > longest) longest = streak;
      } else {
        streak = 0;
      }
      prev = d;
    }
    return longest;
  }
}
