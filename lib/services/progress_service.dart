import '../models/habit.dart';
import 'habit_service.dart' show dateKeyFromDate, periodKeyFor;

/// Progress stored BY DATE instead of a per-habit counter that gets reset:
///   { "yyyy-MM-dd": { habitId: count } }
/// "Today" is simply the entry for today's LOCAL date; a missing entry is 0.
/// There is no reset and no `periodKey` — a new day just has no entry yet, so
/// changing the clock can never wipe progress (the whole data-model-v2 point).
///
/// This service is PURE read logic over such a map (data-model-v2, ЕТАП 1). The
/// map's persistence (local now, Firestore in ЕТАП 2) lives behind a separate
/// repository; here every method takes the map + an explicit date so the clock
/// is an injected dependency in tests (never the system clock).
typedef ProgressMap = Map<String, Map<String, int>>;

class ProgressService {
  /// A day counts as a "success" at or above this percent. Kept identical to
  /// `StreakService.successThreshold` (streak_service.dart:24) so the global
  /// streak/heatmap definition is unchanged.
  static const double successThreshold = 80.0;

  /// Check-ins for [habitId] on the single local day [date] (0 if none).
  static int countOn(ProgressMap map, String habitId, DateTime date) =>
      map[dateKeyFromDate(date)]?[habitId] ?? 0;

  /// Check-ins counting toward [h]'s CURRENT period containing [date]:
  ///   daily   → that day only;
  ///   weekly  → summed over the dates in the same ISO week;
  ///   monthly → summed over the dates in the same month.
  /// Period membership reuses [periodKeyFor] so weekly/monthly match the rest of
  /// the app exactly.
  static int periodCount(ProgressMap map, Habit h, DateTime date) {
    if (h.frequencyUnit == 'day') return countOn(map, h.id, date);
    final target = periodKeyFor(h.frequencyUnit, date);
    var sum = 0;
    map.forEach((dayKey, counts) {
      final c = counts[h.id];
      if (c == null || c == 0) return;
      final d = DateTime.tryParse(dayKey);
      if (d != null && periodKeyFor(h.frequencyUnit, d) == target) sum += c;
    });
    return sum;
  }

  /// Whether [h] has met its target for the period containing [date].
  static bool isCompleted(ProgressMap map, Habit h, DateTime date) =>
      h.timesPerDay > 0 && periodCount(map, h, date) >= h.timesPerDay;

  /// [h]'s fill 0..1 for the period containing [date] (period-aware, no reset).
  static double habitProgress(ProgressMap map, Habit h, DateTime date) {
    if (h.timesPerDay <= 0) return 0;
    return (periodCount(map, h, date) / h.timesPerDay).clamp(0.0, 1.0);
  }

  /// Was [h] live on the calendar day [date]? createdAt ≤ date < deletedAt.
  /// So a PAST day's percentage counts only the habits that existed that day —
  /// a habit added or soft-deleted later never distorts history.
  static bool activeOn(Habit h, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final created =
        DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
    if (created.isAfter(d)) return false;
    final del = h.deletedAt;
    if (del != null) {
      final deleted = DateTime(del.year, del.month, del.day);
      if (!deleted.isAfter(d)) return false; // deleted on or before this date
    }
    return true;
  }

  /// Average fill (0..100) over the habits ACTIVE on [date]. Empty active set
  /// (no habits that day) → 0. This is the day percentage the streak/heatmap use.
  static double dayPercent(ProgressMap map, List<Habit> habits, DateTime date) {
    final active = habits.where((h) => activeOn(h, date)).toList();
    if (active.isEmpty) return 0;
    var sum = 0.0;
    for (final h in active) {
      sum += habitProgress(map, h, date);
    }
    return sum / active.length * 100.0;
  }

  /// A day is a success when its percentage is at or above [successThreshold].
  static bool daySuccess(ProgressMap map, List<Habit> habits, DateTime date) =>
      dayPercent(map, habits, date) >= successThreshold;
}
