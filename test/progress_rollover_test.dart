import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/progress_service.dart';

/// data-model-v2 ЕТАП 1 step 5b: the new-day / clock scenarios from
/// new_day_reset_test.dart, ported to the by-date model. In v2 there is NO
/// reset — a new day simply has no map entry yet (so it reads 0), and moving the
/// clock only changes which date is read. These replace the old reset tests
/// (removed in 5e). Clock is injected (explicit dates).
void main() {
  Habit h(String id, {int times = 1, String freq = 'day'}) => Habit(
      id: id,
      name: id,
      timesPerDay: times,
      frequencyUnit: freq,
      createdAt: DateTime(2026, 1, 1));

  group('midnight rollover — no reset needed', () {
    test('a daily habit done today reads 0 the next day (no entry yet)', () {
      final map = {
        '2026-11-16': {'a': 1}
      };
      final a = h('a');
      expect(ProgressService.isCompleted(map, a, DateTime(2026, 11, 16)), isTrue);
      expect(ProgressService.isCompleted(map, a, DateTime(2026, 11, 17)), isFalse);
      expect(ProgressService.periodCount(map, a, DateTime(2026, 11, 17)), 0);
    });

    test('a weekly habit keeps its count across a day in the same ISO week', () {
      final map = {
        '2026-11-16': {'w': 3}
      }; // Mon, W47
      final w = h('w', times: 3, freq: 'week');
      expect(ProgressService.isCompleted(map, w, DateTime(2026, 11, 17)), isTrue); // Tue, same week
      expect(ProgressService.isCompleted(map, w, DateTime(2026, 11, 23)), isFalse); // next Mon, W48
    });

    test('a monthly habit keeps its count within the month, zero next month', () {
      final map = {
        '2026-11-16': {'m': 5}
      };
      final m = h('m', times: 5, freq: 'month');
      expect(ProgressService.isCompleted(map, m, DateTime(2026, 11, 28)), isTrue);
      expect(ProgressService.periodCount(map, m, DateTime(2026, 12, 1)), 0);
    });
  });

  group('clock moved back/forward — data never wiped', () {
    test('moving the clock back shows that day its own count, today stays 0', () {
      final map = {
        '2026-11-15': {'a': 3},
        '2026-11-16': {'a': 0},
      };
      final a = h('a', times: 8);
      expect(ProgressService.periodCount(map, a, DateTime(2026, 11, 16)), 0);
      expect(ProgressService.periodCount(map, a, DateTime(2026, 11, 15)), 3);
    });

    test('a check-in on a future-dated day lands on THAT day only', () {
      // The old "23:55 check-in applied on a new day" concern: in v2 the count is
      // keyed by its own date, so nothing leaks into a neighbouring day.
      final map = {
        '2026-11-17': {'a': 1}
      };
      final a = h('a');
      expect(ProgressService.periodCount(map, a, DateTime(2026, 11, 16)), 0);
      expect(ProgressService.periodCount(map, a, DateTime(2026, 11, 17)), 1);
    });
  });

  group('per-habit streak across midnight (v2)', () {
    test('done yesterday, today unfinished → streak holds; a missed day → 0', () {
      final a = Habit(
          id: 'a',
          name: 'a',
          timesPerDay: 1,
          frequencyUnit: 'day',
          streakBaseline: 4,
          baselineDate: '2026-11-15',
          createdAt: DateTime(2026, 1, 1));
      // 16.11: yesterday (15) was done (baseline), today in progress → 4.
      expect(ProgressService.habitStreak({}, a, DateTime(2026, 11, 16)), 4);
      // 17.11: 16 was a full miss → streak 0.
      expect(ProgressService.habitStreak({}, a, DateTime(2026, 11, 17)), 0);
    });
  });
}
