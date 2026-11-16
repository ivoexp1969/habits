import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/progress_service.dart';

/// data-model-v2 ЕТАП 1: pure read logic over the by-date progress map.
/// The clock is injected everywhere (explicit `date` args) — never the system
/// clock, never a periodKey reset.
void main() {
  // Nov 2026: 9=Mon 10 11 12 13 14=Sat 15=Sun 16=Mon 17=Tue.
  Habit daily(String id, {int times = 1, DateTime? created, DateTime? deleted}) =>
      Habit(
          id: id,
          name: id,
          timesPerDay: times,
          frequencyUnit: 'day',
          createdAt: created ?? DateTime(2026, 1, 1),
          deletedAt: deleted);
  Habit weekly(String id, {int times = 1}) => Habit(
      id: id,
      name: id,
      timesPerDay: times,
      frequencyUnit: 'week',
      createdAt: DateTime(2026, 1, 1));
  Habit monthly(String id, {int times = 1}) => Habit(
      id: id,
      name: id,
      timesPerDay: times,
      frequencyUnit: 'month',
      createdAt: DateTime(2026, 1, 1));

  group('countOn / periodCount', () {
    test('countOn reads the day entry, missing = 0', () {
      final map = {
        '2026-11-16': {'a': 3},
      };
      expect(ProgressService.countOn(map, 'a', DateTime(2026, 11, 16, 9)), 3);
      expect(ProgressService.countOn(map, 'a', DateTime(2026, 11, 15)), 0);
      expect(ProgressService.countOn(map, 'b', DateTime(2026, 11, 16)), 0);
    });

    test('daily periodCount = that day only', () {
      final map = {
        '2026-11-15': {'a': 2},
        '2026-11-16': {'a': 5},
      };
      expect(ProgressService.periodCount(map, daily('a'), DateTime(2026, 11, 16)), 5);
    });

    test('weekly periodCount sums the ISO week (Mon 9 – Sun 15)', () {
      final map = {
        '2026-11-09': {'w': 1}, // Mon
        '2026-11-13': {'w': 1}, // Fri
        '2026-11-15': {'w': 1}, // Sun
        '2026-11-16': {'w': 1}, // next Mon (different week)
      };
      // Any date in the Mon9–Sun15 week sums to 3; the 16th is a new week.
      expect(ProgressService.periodCount(map, weekly('w'), DateTime(2026, 11, 11)), 3);
      expect(ProgressService.periodCount(map, weekly('w'), DateTime(2026, 11, 16)), 1);
    });

    test('monthly periodCount sums the month, next month is separate', () {
      final map = {
        '2026-11-01': {'m': 2},
        '2026-11-30': {'m': 3},
        '2026-12-01': {'m': 9},
      };
      expect(ProgressService.periodCount(map, monthly('m'), DateTime(2026, 11, 20)), 5);
      expect(ProgressService.periodCount(map, monthly('m'), DateTime(2026, 12, 2)), 9);
    });
  });

  group('isCompleted / habitProgress', () {
    test('daily completion needs count >= timesPerDay', () {
      final map = {
        '2026-11-16': {'a': 5},
      };
      final h = daily('a', times: 8);
      expect(ProgressService.isCompleted(map, h, DateTime(2026, 11, 16)), isFalse);
      expect(ProgressService.habitProgress(map, h, DateTime(2026, 11, 16)),
          closeTo(5 / 8, 1e-9));
      map['2026-11-16']!['a'] = 8;
      expect(ProgressService.isCompleted(map, h, DateTime(2026, 11, 16)), isTrue);
      expect(ProgressService.habitProgress(map, h, DateTime(2026, 11, 16)), 1.0);
    });

    test('weekly goal 1/week met once in the week → complete all week', () {
      final map = {
        '2026-11-11': {'w': 1},
      };
      final h = weekly('w', times: 1);
      expect(ProgressService.isCompleted(map, h, DateTime(2026, 11, 9)), isTrue);
      expect(ProgressService.isCompleted(map, h, DateTime(2026, 11, 15)), isTrue);
      expect(ProgressService.isCompleted(map, h, DateTime(2026, 11, 16)), isFalse);
    });

    test('clock moved back is harmless — the other day keeps its own count', () {
      final map = {
        '2026-11-15': {'a': 3},
        '2026-11-16': {'a': 0},
      };
      final h = daily('a', times: 8);
      // "Today" = 16 shows 0; stepping the clock back to 15 shows 3. No wipe.
      expect(ProgressService.periodCount(map, h, DateTime(2026, 11, 16)), 0);
      expect(ProgressService.periodCount(map, h, DateTime(2026, 11, 15)), 3);
    });
  });

  group('activeOn / dayPercent (active set) / daySuccess', () {
    test('a habit counts only on days it was live (createdAt..deletedAt)', () {
      final h = daily('a',
          created: DateTime(2026, 11, 10), deleted: DateTime(2026, 11, 15));
      expect(ProgressService.activeOn(h, DateTime(2026, 11, 9)), isFalse); // before create
      expect(ProgressService.activeOn(h, DateTime(2026, 11, 10)), isTrue); // created that day
      expect(ProgressService.activeOn(h, DateTime(2026, 11, 14)), isTrue);
      expect(ProgressService.activeOn(h, DateTime(2026, 11, 15)), isFalse); // deleted that day
      expect(ProgressService.activeOn(h, DateTime(2026, 11, 16)), isFalse);
    });

    test('dayPercent averages only the habits active that date', () {
      final a = daily('a'); // live since Jan
      final b = daily('b', created: DateTime(2026, 11, 16)); // added today
      final map = {
        '2026-11-15': {'a': 1},
        '2026-11-16': {'a': 1, 'b': 0},
      };
      // 15th: only 'a' active → 100%. 16th: a(1/1)+b(0/1) over 2 → 50%.
      expect(ProgressService.dayPercent(map, [a, b], DateTime(2026, 11, 15)), 100.0);
      expect(ProgressService.dayPercent(map, [a, b], DateTime(2026, 11, 16)), 50.0);
    });

    test('daySuccess uses the 80% threshold', () {
      final hs = List.generate(5, (i) => daily('h$i'));
      final map = {
        '2026-11-16': {'h0': 1, 'h1': 1, 'h2': 1, 'h3': 1}, // 4/5 = 80%
      };
      expect(ProgressService.dayPercent(map, hs, DateTime(2026, 11, 16)), 80.0);
      expect(ProgressService.daySuccess(map, hs, DateTime(2026, 11, 16)), isTrue);
      map['2026-11-16']!.remove('h3'); // 3/5 = 60%
      expect(ProgressService.daySuccess(map, hs, DateTime(2026, 11, 16)), isFalse);
    });

    test('no active habits on a date → 0 percent, not a crash', () {
      final b = daily('b', created: DateTime(2026, 11, 16));
      expect(ProgressService.dayPercent({}, [b], DateTime(2026, 11, 10)), 0.0);
    });
  });
}
