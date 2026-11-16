import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import 'habit_service.dart' show HabitService, dateKeyFromDate, periodKeyFor;
import 'progress_repository.dart';
import 'progress_service.dart' show ProgressMap;

/// One-time migration from the old per-habit-counter model to the data-model-v2
/// by-date map + per-habit baselines. PURE (clock injected) so it is tested on a
/// fixture of the real habit definitions with known counts — never on the live
/// corrupted cloud blob.
///
/// The old global day-% `history` is kept untouched as a FROZEN archive for the
/// days BEFORE the migration; reads use the archive before migrationDate and the
/// by-date map on/after it, so migrating today's counters never disturbs past
/// percentages.
class ProgressMigration {
  /// Seeds the by-date map from the old counters.
  ///
  /// Daily habit → today's date, count = completedTimes, ONLY when it was
  /// actually completed today (`lastCompletedDate == today`). periodKey is NOT
  /// used as proof: the cold-start bug could stamp periodKey = today without
  /// resetting, so a stale count with yesterday's lastCompletedDate must NOT
  /// land on today. A partial today count (e.g. 3/8, never "completed") is
  /// dropped — accepted.
  ///
  /// Weekly / monthly partial → kept only when its stored periodKey is the
  /// current period, written on migrationDate-1 when that day is still inside
  /// the period (else on migrationDate). That day is read from the archive, so
  /// dayPercent is unchanged, while the period SUM (isCompleted / progress)
  /// stays correct.
  static ProgressMap seedMap(List<Habit> habits, DateTime now) {
    final map = <String, Map<String, int>>{};
    final today = dateKeyFromDate(now);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    void put(String dayKey, String id, int count) {
      if (count <= 0) return;
      (map[dayKey] ??= <String, int>{})[id] = count;
    }

    for (final h in habits) {
      if (h.completedTimes <= 0) continue;
      if (h.frequencyUnit == 'day') {
        if (h.lastCompletedDate == today) put(today, h.id, h.completedTimes);
      } else {
        if (h.periodKey == periodKeyFor(h.frequencyUnit, now)) {
          final target = periodKeyFor(h.frequencyUnit, yesterday) ==
                  periodKeyFor(h.frequencyUnit, now)
              ? yesterday // still inside the period → before migrationDate
              : now; // the period starts on migrationDate
          put(dateKeyFromDate(target), h.id, h.completedTimes);
        }
      }
    }
    return map;
  }

  /// Stamps the per-habit baselines (mutates [habits] in place). The displayed
  /// streak after migration = streakBaseline (= the old streak), so before =
  /// after; it is extended by the map from baselineDate on. goalBaseline is the
  /// old goalCount only when it belongs to the CURRENT goal period, else 0 (a
  /// rolled-over period starts the goal from 0).
  static void stampBaselines(List<Habit> habits, DateTime now) {
    for (final h in habits) {
      h.streakBaseline = h.streak;
      h.baselineDate = h.lastCompletedDate;
      h.goalBaseline =
          (h.hasGoal && h.goalPeriodKey == h.goalKeyFor(now)) ? h.goalCount : 0;
    }
  }

  /// Pref flag holding the completed progress-schema version (data-model-v2 = 2).
  static const String kSchemaVersion = 'progress_schema_version';
  static const int targetVersion = 2;

  /// Runs the one-time migration if this device has not reached [targetVersion]:
  /// seeds the by-date map from the old habits, stamps the baselines, persists
  /// both, and bumps the flag. Idempotent — a second call is a no-op. Returns
  /// true when it migrated now. (Firestore's transactional/first-writer-wins
  /// version of this lands in ЕТАП 2; here it is local and guarded by the flag.)
  static Future<bool> runIfNeeded(
      SharedPreferences prefs, LocalProgressRepository repo, DateTime now) async {
    if ((prefs.getInt(kSchemaVersion) ?? 1) >= targetVersion) return false;
    final habits = await HabitService.loadHabits();
    final map = seedMap(habits, now);
    stampBaselines(habits, now);
    await repo.replaceAll(map);
    await HabitService.saveHabits(habits); // persist the baselines
    await prefs.setInt(kSchemaVersion, targetVersion);
    return true;
  }
}
