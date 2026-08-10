import 'habit_service.dart';

/// Pure streak computation over the GLOBAL daily-success history
/// (`Map<"yyyy-MM-dd", dayPercent 0..100>`). A day counts as a success when
/// its percent is at least [successThreshold].
///
/// The app persists only this global (all-habits-combined) daily percentage —
/// there is no per-habit daily record — so both the current and the best
/// streak are derived here, giving Stats (and anywhere else) a single shared
/// definition instead of the old copy inlined in the Stats screen.
///
/// ## Streak freeze ([allowGrace])
/// When `allowGrace` is true (the product default), a single isolated missed
/// day does NOT break the streak — only two or more *consecutive* misses do.
/// Multiple separate single-day gaps are each tolerated. When false, any miss
/// breaks the streak (the strict, classic behaviour).
///
/// Either way, today is never counted as a miss while it is still in progress:
/// if today has not reached the threshold yet, it is skipped rather than
/// treated as a broken day, so an unfinished current day never zeroes a streak
/// the user has not actually lost.
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

  /// Length of the streak ending today (counted as a number of success days),
  /// walking backwards from today. Today-in-progress is skipped, not broken;
  /// with [allowGrace] a lone missed day is skipped too, and only two
  /// consecutive misses end the walk.
  static int currentStreak(Map<String, double> history,
      {bool allowGrace = true}) {
    DateTime cursor = _todayDate();
    // Today still in progress → don't let an unfinished day break the streak.
    if (!_isSuccess(history, cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    int current = 0;
    while (true) {
      if (_isSuccess(history, cursor)) {
        current++;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      // A missed day. Tolerate it only if it is a *single* gap (the day before
      // it is itself a success) and grace is enabled — otherwise the streak
      // ends here (two misses in a row always break it).
      final dayBefore = cursor.subtract(const Duration(days: 1));
      if (allowGrace && _isSuccess(history, dayBefore)) {
        cursor = dayBefore; // skip the lone gap day (it does not add to the count)
        continue;
      }
      break;
    }
    return current;
  }

  /// Longest run of success days anywhere in the history, counted as a number
  /// of success days. With [allowGrace] a run survives isolated single-day
  /// gaps and breaks only on two consecutive misses; without it, any miss
  /// breaks the run.
  static int bestStreak(Map<String, double> history, {bool allowGrace = true}) {
    final successDays = history.keys
        .map(_parseKey)
        .whereType<DateTime>()
        .where((d) => _isSuccess(history, d))
        .toList()
      ..sort();
    if (successDays.isEmpty) return 0;

    final DateTime start = successDays.first;
    final DateTime end = successDays.last;

    int best = 0;
    int run = 0;
    int consecutiveMisses = 0;
    for (DateTime day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      if (_isSuccess(history, day)) {
        run++;
        if (run > best) best = run;
        consecutiveMisses = 0;
      } else {
        consecutiveMisses++;
        // A single graced gap keeps the run alive (but does not extend it);
        // a second consecutive miss — or any miss in strict mode — resets it.
        if (!(allowGrace && consecutiveMisses == 1)) {
          run = 0;
        }
      }
    }
    return best;
  }
}
