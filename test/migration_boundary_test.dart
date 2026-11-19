import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/progress_service.dart';

/// No double-counting across the migration day D. The migration seeds today's
/// (D's) progress into BOTH the baselines (goalBaseline / streakBaseline) AND —
/// for a daily habit completed on D — the by-date map. So every read must count
/// D exactly once: goalCount skips map days <= migratedAt, and the daily streak
/// takes days up to baselineDate from the baseline run, the map only after it.
void main() {
  // D = migration day. Month 2026-11; ISO week of 18.11 is W47 (Mon16–Sun22).
  const dKey = '2026-11-16';
  final dPlus1 = DateTime(2026, 11, 17);
  final dPlus2 = DateTime(2026, 11, 18);

  Habit goalHabit() => Habit(
        id: 'g',
        name: 'Книги',
        timesPerDay: 1,
        frequencyUnit: 'day',
        goalTarget: 5,
        goalPeriod: 'month',
        goalBaseline: 3, // goal count at D (INCLUDES D's check-in)
        goalBaselineKey: '2026-11',
        createdAt: DateTime(2026, 1, 1),
      );

  group('goal: D is in the baseline, never re-counted from the map', () {
    test('D+1 with another check-in → 4/5, not 5/5', () {
      // Map holds D's seeded check-in AND a real D+1 one.
      final map = {
        '2026-11-16': {'g': 1}, // seeded on D — must be ignored (in baseline)
        '2026-11-17': {'g': 1}, // the only post-migration check-in
      };
      expect(ProgressService.goalCount(map, goalHabit(), dPlus1, migratedAt: dKey), 4);
    });

    test('D+1 with NO new check-in → 3/5', () {
      final map = {
        '2026-11-16': {'g': 1}, // only D's seeded entry
      };
      expect(ProgressService.goalCount(map, goalHabit(), dPlus1, migratedAt: dKey), 3);
    });
  });

  Habit streakHabit() => Habit(
        id: 's',
        name: 'Вода',
        timesPerDay: 1,
        frequencyUnit: 'day',
        streakBaseline: 5, // 5-day run ending ON D
        baselineDate: dKey,
        createdAt: DateTime(2026, 1, 1),
      );

  group('daily streak: baseline ends ON D, map extends from D+1', () {
    test('check-in on D+1 → 6, not 7', () {
      final map = {
        '2026-11-16': {'s': 1}, // D seeded — already the baseline's last day
        '2026-11-17': {'s': 1}, // D+1 extends the run
      };
      expect(ProgressService.habitStreak(map, streakHabit(), dPlus1), 6);
    });

    test('no check-in on D+1, check-in on D+2 → 1 (chain broke at D+1)', () {
      final map = {
        '2026-11-16': {'s': 1},
        // 2026-11-17 missed
        '2026-11-18': {'s': 1},
      };
      expect(ProgressService.habitStreak(map, streakHabit(), dPlus2), 1);
    });
  });

  group('weekly habit across the migration week — no double-count', () {
    // Weekly 3×/week. Migration seeded 2/3 for the current week (W47) onto
    // migrationDate-1 (17.11, inside the week). migratedAt = D = 18.11.
    Habit weekly() => Habit(
        id: 'w',
        name: 'Спорт',
        timesPerDay: 3,
        frequencyUnit: 'week',
        createdAt: DateTime(2026, 1, 1));

    test('seeded 2/3 → periodCount 2 at D; +1 the same week → 3, complete', () {
      final seeded = {
        '2026-11-17': {'w': 2}, // the migration-seeded partial
      };
      expect(ProgressService.periodCount(seeded, weekly(), dPlus2), 2);
      expect(ProgressService.isCompleted(seeded, weekly(), dPlus2), isFalse);

      final afterCheckIn = {
        '2026-11-17': {'w': 2},
        '2026-11-19': {'w': 1}, // a real check-in later the same ISO week
      };
      expect(ProgressService.periodCount(afterCheckIn, weekly(), DateTime(2026, 11, 19)), 3);
      expect(ProgressService.isCompleted(afterCheckIn, weekly(), DateTime(2026, 11, 19)), isTrue);
    });
  });
}
