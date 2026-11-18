import 'dart:math' as math;

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

  /// The day percentage for [date] from the single source of truth: the FROZEN
  /// archive (old global `history`) for days strictly BEFORE migrationDate, and
  /// the by-date map (via [dayPercent], which clamps each habit to 100% exactly
  /// like the old _dayProgress) on/after it. Used by stats / heatmap / calendar /
  /// the global streak so nothing double-counts across the boundary.
  static double daySuccessPercent(Map<String, double> archive, ProgressMap map,
      List<Habit> habits, DateTime date,
      {String? migratedAt}) {
    final key = dateKeyFromDate(date);
    if (migratedAt == null || key.compareTo(migratedAt) < 0) {
      return archive[key] ?? 0.0;
    }
    return dayPercent(map, habits, date);
  }

  /// The unified daily-success map (archive before migrationDate + map-derived
  /// percentages on/after it), consumed in place of the raw `history` by
  /// StreakService / the heatmap / stats / the calendar. Sparse: a day absent
  /// here is 0% (not a success), which is exactly what those consumers assume.
  static Map<String, double> unifiedHistory(
      Map<String, double> archive, ProgressMap map, List<Habit> habits,
      {String? migratedAt}) {
    final out = <String, double>{};
    archive.forEach((k, v) {
      if (migratedAt == null || k.compareTo(migratedAt) < 0) out[k] = v;
    });
    for (final dayKey in map.keys) {
      if (migratedAt != null && dayKey.compareTo(migratedAt) < 0) continue;
      final d = DateTime.tryParse(dayKey);
      if (d != null) out[dayKey] = dayPercent(map, habits, d);
    }
    return out;
  }

  /// The live habits at [now] — soft-deleted ones (deletedAt on or before now)
  /// are excluded. The ONE helper every `_habits` iteration goes through (UI
  /// lists, both views, day%, perfect-day/XP, reminders, widget, stats, share),
  /// so a deleted habit never blocks a perfect day or distorts a count.
  static List<Habit> activeHabits(List<Habit> habits, DateTime now) =>
      habits.where((h) => activeOn(h, now)).toList();

  /// Goal progress (for 'year'/'month' goals) under data-model-v2: no stored
  /// goalCount counter. It is the migration baseline for the goal period the
  /// baseline belongs to, plus the check-ins recorded in the map for the current
  /// goal period AFTER the migration day (so the baseline's own day is not
  /// double-counted). A rolled-over goal period starts from 0. 'ongoing' goals
  /// still read the lifetime totalCompletions counter.
  static int goalCount(ProgressMap map, Habit h, DateTime now,
      {String? migratedAt}) {
    if (!h.hasGoal) return 0;
    if (h.goalPeriod == 'ongoing') return h.totalCompletions;
    final targetKey = h.goalKeyFor(now);
    final base = h.goalBaselineKey == targetKey ? (h.goalBaseline ?? 0) : 0;
    var sum = 0;
    map.forEach((dayKey, counts) {
      final c = counts[h.id];
      if (c == null || c == 0) return;
      if (migratedAt != null && dayKey.compareTo(migratedAt) <= 0) {
        return; // covered by goalBaseline — don't double-count
      }
      final d = DateTime.tryParse(dayKey);
      if (d != null && h.goalKeyFor(d) == targetKey) sum += c;
    });
    return base + sum;
  }

  // ---------------------------------------------------------------------------
  // Per-habit streak (data-model-v2). Computed from the by-date map, NOT a
  // stored counter — so the mark→unmark→mark bug is gone. Rules (explicit,
  // different from the global StreakService which has grace):
  //  * STRICT, no grace: a fully missed day ends the streak (→ 0). The old code
  //    showed the stale stored value until the next check-in — a conscious
  //    change here.
  //  * Today, while unfinished, does NOT break it (shows the chain up to
  //    yesterday); completing today extends it.
  //  * paused_dates are skipped (neither success nor miss) — this function
  //    promises a protected streak, unlike the old _bumpStreak.
  //  * Pre-migration days use the per-habit baseline (streakBaseline ending on
  //    baselineDate = a run of that many consecutive completed days), since the
  //    old app kept no per-habit daily history.
  // There is NO per-weekday schedule in this app (frequencyUnit is day/week/
  // month only), so "skip off-schedule days" does not apply.

  static DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Effective per-habit streak at [today].
  static int habitStreak(ProgressMap map, Habit h, DateTime today,
      {Set<String> pausedKeys = const <String>{}}) {
    if (h.frequencyUnit == 'day') {
      return _dailyStreak(map, h, _d(today), pausedKeys);
    }
    return _periodStreak(map, h, _d(today), pausedKeys);
  }

  /// bestStreak never decreases: the stored best or the current streak.
  static int bestStreakOf(Habit h, int currentStreak) =>
      math.max(h.bestStreak, currentStreak);

  static int _dailyStreak(
      ProgressMap map, Habit h, DateTime today, Set<String> paused) {
    final base = h.streakBaseline ?? 0;
    final baseEndRaw = h.baselineDate == null ? null : DateTime.tryParse(h.baselineDate!);
    final baseEnd = baseEndRaw == null ? null : _d(baseEndRaw);
    final runStart = baseEnd == null ? null : baseEnd.subtract(Duration(days: base - 1));

    bool done(DateTime day) {
      if (baseEnd != null && base > 0 && !day.isAfter(baseEnd)) {
        // Pre-migration: the baseline run of `base` days ending baseEnd.
        return !day.isBefore(runStart!) && !day.isAfter(baseEnd);
      }
      return countOn(map, h.id, day) >= h.timesPerDay;
    }

    bool isPaused(DateTime day) => paused.contains(dateKeyFromDate(day));

    var cursor = today;
    if (!isPaused(cursor) && !done(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1)); // today in progress → skip
    }
    var count = 0;
    while (true) {
      if (isPaused(cursor)) {
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      if (done(cursor)) {
        count++;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      break; // a missed, non-paused day ends the streak (no grace)
    }
    return count;
  }

  // Weekly / monthly: consecutive ISO periods whose goal is met. The current,
  // still-unfinished period does not break it; a missed period ends it; a period
  // entirely within paused_dates is skipped. The baseline period (the one
  // containing baselineDate) counts as met iff streakBaseline > 0.
  static int _periodStreak(
      ProgressMap map, Habit h, DateTime today, Set<String> paused) {
    final unit = h.frequencyUnit;
    final basePk = h.baselineDate == null
        ? null
        : periodKeyFor(unit, DateTime.parse(h.baselineDate!));

    bool met(DateTime rep) {
      final pk = periodKeyFor(unit, rep);
      if (basePk != null && pk == basePk) return (h.streakBaseline ?? 0) > 0;
      if (basePk != null && pk.compareTo(basePk) < 0) return false; // pre-baseline
      return periodCount(map, h, rep) >= h.timesPerDay;
    }

    bool fullyPaused(DateTime rep) {
      for (final day in _periodDays(unit, rep)) {
        if (!paused.contains(day)) return false;
      }
      return true;
    }

    DateTime stepBack(DateTime rep) => unit == 'month'
        ? DateTime(rep.year, rep.month - 1, 15)
        : rep.subtract(const Duration(days: 7));

    var cursor = today;
    if (!fullyPaused(cursor) && !met(cursor)) {
      cursor = stepBack(cursor); // current period unfinished → don't break
    }
    var count = 0;
    while (true) {
      if (fullyPaused(cursor)) {
        cursor = stepBack(cursor);
        continue;
      }
      if (met(cursor)) {
        count++;
        cursor = stepBack(cursor);
        continue;
      }
      break;
    }
    return count;
  }

  /// All "yyyy-MM-dd" keys in the ISO week (Mon–Sun) or the month containing
  /// [rep] — used to detect a period that is entirely paused.
  static List<String> _periodDays(String unit, DateTime rep) {
    if (unit == 'month') {
      final first = DateTime(rep.year, rep.month, 1);
      final next = DateTime(rep.year, rep.month + 1, 1);
      final days = next.difference(first).inDays;
      return [for (var i = 0; i < days; i++) dateKeyFromDate(DateTime(rep.year, rep.month, 1 + i))];
    }
    final d = _d(rep);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return [for (var i = 0; i < 7; i++) dateKeyFromDate(monday.add(Duration(days: i)))];
  }
}

/// Memoises per-habit streaks so a repaint does not re-walk the map. The wiring
/// layer calls [invalidate] after any write (check-in / undo / midnight / sync).
class StreakCache {
  StreakCache._();
  static final StreakCache instance = StreakCache._();

  final Map<String, int> _memo = {};

  void invalidate() => _memo.clear();

  int streak(ProgressMap map, Habit h, DateTime today,
      {Set<String> pausedKeys = const <String>{}}) {
    final key = '${h.id}|${dateKeyFromDate(today)}';
    return _memo.putIfAbsent(
        key, () => ProgressService.habitStreak(map, h, today, pausedKeys: pausedKeys));
  }
}
