import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/progress_service.dart';
import 'package:habits/services/streak_service.dart';

/// 5c: unified daily success (archive < migrationDate, map >= migrationDate).
void main() {
  Habit daily(String id,
          {int t = 1, DateTime? created, DateTime? deleted}) =>
      Habit(
          id: id,
          name: id,
          timesPerDay: t,
          frequencyUnit: 'day',
          createdAt: created ?? DateTime(2026, 1, 1),
          deletedAt: deleted);

  group('dayPercent clamps a habit to 100%', () {
    test('an over-achieved day still gives 100%', () {
      final date = DateTime(2026, 11, 17);
      // Over-achieved: 12 check-ins against a target of 8.
      final map = {
        '2026-11-17': {'a': 12}
      };
      final newPct = ProgressService.dayPercent(map, [daily('a', t: 8)], date);
      expect(newPct, 100.0); // clamped, not 150%
    });
  });

  group('past day uses only the habits active that date', () {
    test('a habit created later / deleted earlier is excluded', () {
      final map = {
        '2026-11-17': {'a': 1}
      };
      final a = daily('a');
      final later = daily('later', created: DateTime(2026, 11, 20));
      final gone = daily('gone', deleted: DateTime(2026, 11, 10));
      // 17.11: only 'a' active → 100% (later not created yet, gone already deleted).
      expect(
          ProgressService.daySuccessPercent(
              {}, map, [a, later, gone], DateTime(2026, 11, 17),
              migratedAt: '2026-11-17'),
          100.0);
    });
  });

  group('global streak is continuous across migrationDate', () {
    test('a run spanning archive + map counts through the boundary', () {
      final archive = {'2026-11-15': 100.0, '2026-11-16': 100.0};
      final map = {
        '2026-11-17': {'a': 1},
        '2026-11-18': {'a': 1},
      };
      final unified = ProgressService.unifiedHistory(
          archive, map, [daily('a')],
          migratedAt: '2026-11-17');
      // archive 15/16 + map-derived 17/18, all 100%.
      expect(unified.keys.toSet(),
          {'2026-11-15', '2026-11-16', '2026-11-17', '2026-11-18'});
      expect(unified['2026-11-17'], 100.0);
      // bestStreak (clock-independent) = 4 consecutive success days across the
      // migrationDate boundary.
      expect(StreakService.bestStreak(unified), 4);
    });

    test('daySuccessPercent reads archive before, map on/after migrationDate', () {
      final archive = {'2026-11-16': 79.0};
      final map = {
        '2026-11-17': {'a': 1}
      };
      final h = [daily('a')];
      expect(
          ProgressService.daySuccessPercent(archive, map, h, DateTime(2026, 11, 16),
              migratedAt: '2026-11-17'),
          79.0); // archive
      expect(
          ProgressService.daySuccessPercent(archive, map, h, DateTime(2026, 11, 17),
              migratedAt: '2026-11-17'),
          100.0); // map
    });
  });
}
