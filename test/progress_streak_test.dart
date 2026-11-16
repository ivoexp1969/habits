import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/progress_service.dart';

/// data-model-v2 ЕТАП 1 step 4: per-habit streak computed from the by-date map.
/// Clock injected (explicit `today`). Rules are strict (no grace), today-in-
/// progress never breaks, paused days are skipped, pre-migration uses the
/// baseline.
void main() {
  final today = DateTime(2026, 11, 16); // Mon (ISO week W47)

  Habit daily(String id,
          {int times = 1, int? streakBaseline, String? baselineDate, int best = 0}) =>
      Habit(
          id: id,
          name: id,
          timesPerDay: times,
          frequencyUnit: 'day',
          bestStreak: best,
          streakBaseline: streakBaseline,
          baselineDate: baselineDate,
          createdAt: DateTime(2026, 1, 1));
  Habit weekly(String id, {int times = 3}) => Habit(
      id: id,
      name: id,
      timesPerDay: times,
      frequencyUnit: 'week',
      createdAt: DateTime(2026, 1, 1));

  int streak(Map<String, Map<String, int>> map, Habit h,
          {Set<String> paused = const {}}) =>
      ProgressService.habitStreak(map, h, today, pausedKeys: paused);

  group('daily streak', () {
    test('mark → unmark → mark the same day is never corrupted (old bug gone)', () {
      final h = daily('a', streakBaseline: 2, baselineDate: '2026-11-15');
      final map = {
        '2026-11-16': {'a': 1}
      };
      expect(streak(map, h), 3); // baseline 2 + today
      map['2026-11-16'] = {}; // unmark
      expect(streak(map, h), 2); // today unfinished → chain to yesterday
      map['2026-11-16'] = {'a': 1}; // re-mark
      expect(streak(map, h), 3, reason: 'not 1 — the _unbumpStreak bug is gone');
    });

    test('a fully missed day → 0', () {
      final h = daily('a', streakBaseline: 5, baselineDate: '2026-11-12');
      expect(streak({}, h), 0); // 13–15 missed
    });

    test('today unfinished → shows the chain up to yesterday', () {
      final h = daily('a', streakBaseline: 4, baselineDate: '2026-11-15');
      expect(streak({}, h), 4);
    });

    test('a paused day in the middle keeps the chain whole', () {
      final h = daily('a');
      final map = {
        '2026-11-16': {'a': 1},
        '2026-11-15': {'a': 1},
        '2026-11-13': {'a': 1},
      };
      expect(streak(map, h, paused: {'2026-11-14'}), 3); // 16,15,(skip 14),13
    });

    test('baseline + map chain extends it', () {
      final h = daily('a', streakBaseline: 3, baselineDate: '2026-11-15');
      final map = {
        '2026-11-16': {'a': 1}
      };
      expect(streak(map, h), 4); // 3 + today
    });

    test('a gap after baselineDate drops the baseline (map only)', () {
      final h = daily('a', streakBaseline: 3, baselineDate: '2026-11-14');
      final map = {
        '2026-11-16': {'a': 1}
      }; // 15 missed
      expect(streak(map, h), 1); // today only; the baseline run is cut off
    });

    test('bestStreakOf never decreases', () {
      final h = daily('a', best: 10);
      expect(ProgressService.bestStreakOf(h, 3), 10);
      expect(ProgressService.bestStreakOf(h, 12), 12);
    });
  });

  group('weekly streak (consecutive ISO weeks with the goal met)', () {
    test('consecutive met weeks; current unfinished week does not break', () {
      final h = weekly('w', times: 3);
      final map = {
        '2026-11-16': {'w': 1}, // W47 (this week) partial → unfinished, skipped
        '2026-11-10': {'w': 3}, // W46 met
        '2026-11-05': {'w': 3}, // W45 met
      };
      expect(streak(map, h), 2); // W46 + W45
    });

    test('a missed week → 0', () {
      final h = weekly('w', times: 3);
      final map = {
        '2026-11-05': {'w': 3}
      }; // only W45; W46 missed
      expect(streak(map, h), 0);
    });
  });

  group('StreakCache', () {
    test('memoises until invalidate()', () {
      final h = daily('a', streakBaseline: 2, baselineDate: '2026-11-15');
      final map = {
        '2026-11-16': {'a': 1}
      };
      final c = StreakCache.instance..invalidate();
      expect(c.streak(map, h, today), 3);
      map['2026-11-16'] = {}; // underlying changed, but memoised
      expect(c.streak(map, h, today), 3);
      c.invalidate();
      expect(c.streak(map, h, today), 2); // recomputed
    });
  });
}
