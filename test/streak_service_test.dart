import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/habit_service.dart';
import 'package:habits/services/streak_service.dart';

/// Builds a history map from day-offsets relative to today (0 = today,
/// 1 = yesterday, ...) mapping each to a success percentage.
Map<String, double> historyFor(Map<int, double> offsets) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  return offsets.map((offset, pct) {
    final day = todayDate.subtract(Duration(days: offset));
    return MapEntry(dateKeyFromDate(day), pct);
  });
}

void main() {
  group('currentStreak', () {
    test('(a) unfinished today does NOT break the streak', () {
      // Today still 0%, but the previous 3 days were all successes.
      final h = historyFor({0: 0, 1: 100, 2: 100, 3: 100});
      expect(StreakService.currentStreak(h, allowGrace: true), 3);
      expect(StreakService.currentStreak(h, allowGrace: false), 3);
    });

    test('today counted when already a success', () {
      final h = historyFor({0: 100, 1: 100, 2: 100});
      expect(StreakService.currentStreak(h, allowGrace: true), 3);
    });

    test('(b) a single missed day is forgiven with grace, strict breaks', () {
      // today done, yesterday missed, then two more successes.
      final h = historyFor({0: 100, 1: 0, 2: 100, 3: 100});
      expect(StreakService.currentStreak(h, allowGrace: true), 3);
      expect(StreakService.currentStreak(h, allowGrace: false), 1);
    });

    test('multiple separate single gaps are each forgiven', () {
      final h = historyFor({0: 100, 1: 0, 2: 100, 3: 0, 4: 100});
      expect(StreakService.currentStreak(h, allowGrace: true), 3);
    });

    test('(c) two consecutive missed days break even with grace', () {
      final h = historyFor({0: 100, 1: 0, 2: 0, 3: 100});
      expect(StreakService.currentStreak(h, allowGrace: true), 1);
      expect(StreakService.currentStreak(h, allowGrace: false), 1);
    });

    test('empty history is a zero streak', () {
      expect(StreakService.currentStreak({}, allowGrace: true), 0);
    });
  });

  group('bestStreak', () {
    test('grace bridges single gaps, strict does not', () {
      // S . S S  (offsets 4..1, today unfinished)  → grace: 3, strict: 2
      final h = historyFor({1: 100, 2: 100, 3: 0, 4: 100});
      expect(StreakService.bestStreak(h, allowGrace: true), 3);
      expect(StreakService.bestStreak(h, allowGrace: false), 2);
    });

    test('two consecutive misses cap the best run', () {
      // days (old→new): 100,100,0,0,100  → best success-run with grace = 2
      final h = historyFor({5: 100, 4: 100, 3: 0, 2: 0, 1: 100});
      expect(StreakService.bestStreak(h, allowGrace: true), 2);
      expect(StreakService.bestStreak(h, allowGrace: false), 2);
    });
  });
}
