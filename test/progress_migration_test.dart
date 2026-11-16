import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/habit_service.dart'
    show dateKeyFromDate, periodKeyFor;
import 'package:habits/services/progress_migration.dart';
import 'package:habits/services/progress_service.dart';

/// data-model-v2 ЕТАП 1 step 3: one-time migration.
///
/// The reference is NOT the live (corrupted) cloud blob — it is the real habit
/// DEFINITIONS (anonymised Навик1…8) with KNOWN given counts and expected
/// values, so `before = after` is checked against a clean, controlled state.
void main() {
  final today = DateTime(2026, 11, 16, 9); // Mon
  final todayKey = dateKeyFromDate(today);
  final yKey = dateKeyFromDate(DateTime(2026, 11, 15)); // Sun

  // Real definitions of the 8 habits, anonymised. All daily (the real data has
  // no weekly habit); Навик2 carries a monthly goal (like "Сън 8 часа").
  Habit mk(String id, int times,
          {String? last,
          int count = 0,
          String? periodKey,
          int streak = 0,
          int best = 0,
          int? goalTarget,
          String? goalPeriod,
          int goalCount = 0,
          String? goalPeriodKey,
          String freq = 'day'}) =>
      Habit(
        id: id,
        name: id,
        timesPerDay: times,
        frequencyUnit: freq,
        periodKey: periodKey,
        completedTimes: count,
        lastCompletedDate: last,
        streak: streak,
        bestStreak: best,
        goalTarget: goalTarget,
        goalPeriod: goalPeriod,
        goalCount: goalCount,
        goalPeriodKey: goalPeriodKey,
        createdAt: DateTime(2026, 1, 1),
      );

  group('dayPercent equals the old _dayProgress on the real structure', () {
    test('8 habits, mixed counts → new dayPercent == old avg(progress)', () {
      // periodKey == today for all → old progress = completedTimes/timesPerDay.
      final habits = <Habit>[
        mk('Навик1', 8, count: 3, periodKey: todayKey),
        mk('Навик2', 1, count: 0, periodKey: todayKey),
        mk('Навик3', 1, count: 1, periodKey: todayKey),
        mk('Навик4', 1, count: 0, periodKey: todayKey),
        mk('Навик5', 3, count: 1, periodKey: todayKey),
        mk('Навик6', 1, count: 1, periodKey: todayKey),
        mk('Навик7', 1, count: 1, periodKey: todayKey),
        mk('Навик8', 2, count: 1, periodKey: todayKey),
      ];
      // old _dayProgress (home_screen): average of h.progressAt(today) * 100.
      final old = habits
              .map((h) => h.progressAt(today))
              .reduce((a, b) => a + b) /
          habits.length *
          100;
      // equivalent by-date map (today → the same counts).
      final ProgressMap map = {
        todayKey: {
          for (final h in habits)
            if (h.completedTimes > 0) h.id: h.completedTimes
        }
      };
      final neu = ProgressService.dayPercent(map, habits, today);
      expect(neu, closeTo(old, 1e-9));
    });
  });

  group('seedMap (daily)', () {
    test('only habits completed TODAY (lastCompletedDate==today) land on today', () {
      final habits = [
        mk('Навик1', 8, count: 8, last: todayKey), // completed today → kept
        mk('Навик3', 1, count: 1, last: todayKey), // completed today → kept
        mk('Навик4', 1, count: 0, last: yKey), // nothing today
        mk('Навик5', 3, count: 2, last: yKey), // PARTIAL, not today → dropped
      ];
      final map = ProgressMigration.seedMap(habits, today);
      expect(map[todayKey], {'Навик1': 8, 'Навик3': 1});
      expect(map.length, 1);
    });

    test('corrupted cold-start state (periodKey=today, last=yesterday) → 0 today', () {
      final habits = [
        mk('Навик1', 8, count: 6, last: yKey, periodKey: todayKey),
      ];
      final map = ProgressMigration.seedMap(habits, today);
      expect(ProgressService.countOn(map, 'Навик1', today), 0);
      expect(map.isEmpty, isTrue);
    });
  });

  group('seedMap (weekly) — partial sum preserved (2/3 before = after)', () {
    test('weekly 2/3, period = current week → periodCount stays 2', () {
      // Wed 18.11 (ISO week W47); yesterday 17.11 is the same week.
      final wed = DateTime(2026, 11, 18, 9);
      final h = mk('НавикW', 3,
          freq: 'week', count: 2, periodKey: periodKeyFor('week', wed));
      final map = ProgressMigration.seedMap([h], wed);
      expect(ProgressService.periodCount(map, h, wed), 2);
      expect(ProgressService.isCompleted(map, h, wed), isFalse); // 2 < 3
      expect(ProgressService.habitProgress(map, h, wed), closeTo(2 / 3, 1e-9));
      // written on migrationDate-1 (17.11), inside the week.
      expect(map.containsKey('2026-11-17'), isTrue);
    });
  });

  group('stampBaselines', () {
    test('streakBaseline/baselineDate = old streak/lastCompletedDate; best kept', () {
      final habits = [
        mk('Навик1', 8, streak: 2, best: 2, last: yKey),
        mk('Навик4', 1, streak: 5, best: 5, last: '2026-11-12'),
        mk('Навик6', 1, streak: 3, best: 10, last: todayKey),
      ];
      ProgressMigration.stampBaselines(habits, today);
      expect(habits[0].streakBaseline, 2);
      expect(habits[0].baselineDate, yKey);
      expect(habits[1].streakBaseline, 5);
      expect(habits[1].baselineDate, '2026-11-12');
      expect(habits[2].streakBaseline, 3);
      expect(habits[2].bestStreak, 10); // untouched
    });

    test('goalBaseline = goalCount for the CURRENT goal period', () {
      final h = mk('Навик2', 1,
          goalTarget: 20,
          goalPeriod: 'month',
          goalCount: 22,
          goalPeriodKey: '2026-11');
      ProgressMigration.stampBaselines([h], today); // Nov → same month
      expect(h.goalBaseline, 22);
    });

    test('goalBaseline = 0 on a NEW goal period (month changed)', () {
      final h = mk('Навик2', 1,
          goalTarget: 20,
          goalPeriod: 'month',
          goalCount: 22,
          goalPeriodKey: '2026-11');
      ProgressMigration.stampBaselines([h], DateTime(2026, 12, 1)); // Dec
      expect(h.goalBaseline, 0);
    });
  });
}
