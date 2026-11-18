import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/progress_service.dart';

/// data-model-v2 ЕТАП 1 step 5b-iii-a: goal progress from the map (no counter).
void main() {
  final nov = DateTime(2026, 11, 16);
  final dec = DateTime(2026, 12, 1);

  Habit sun({int baseline = 22, String periodKey = '2026-11'}) => Habit(
      id: 'sun',
      name: 'Сън 8 часа',
      timesPerDay: 1,
      frequencyUnit: 'day',
      goalTarget: 20,
      goalPeriod: 'month',
      goalBaseline: baseline,
      goalPeriodKey: periodKey,
      goalBaselineKey: periodKey,
      createdAt: DateTime(2026, 1, 1));

  test('"Сън 8 часа": 22 before = 22 after (baseline, empty map, same month)', () {
    expect(ProgressService.goalCount({}, sun(), nov, migratedAt: '2026-11-16'), 22);
  });

  test('a new goal period (month changed) → 0', () {
    expect(ProgressService.goalCount({}, sun(), dec, migratedAt: '2026-11-16'), 0);
  });

  test('a post-migration check-in adds to the goal count', () {
    final map = {
      '2026-11-20': {'sun': 1}
    };
    expect(ProgressService.goalCount(map, sun(), nov, migratedAt: '2026-11-16'), 23);
  });

  test('the migration day itself is not double-counted', () {
    final map = {
      '2026-11-16': {'sun': 1}
    }; // seeded on the migration day → covered by baseline
    expect(ProgressService.goalCount(map, sun(), nov, migratedAt: '2026-11-16'), 22);
  });

  test("'ongoing' goal reads the lifetime totalCompletions", () {
    final h = Habit(
        id: 'x',
        name: 'x',
        timesPerDay: 1,
        goalTarget: 100,
        goalPeriod: 'ongoing',
        totalCompletions: 57,
        createdAt: DateTime(2026, 1, 1));
    expect(ProgressService.goalCount({}, h, nov), 57);
  });

  test('no goal → 0', () {
    final h = Habit(id: 'x', name: 'x', timesPerDay: 1, createdAt: DateTime(2026, 1, 1));
    expect(ProgressService.goalCount({}, h, nov), 0);
  });

  test('activeHabits excludes soft-deleted habits', () {
    final live = Habit(id: 'a', name: 'a', timesPerDay: 1, createdAt: DateTime(2026, 1, 1));
    final gone = Habit(
        id: 'b',
        name: 'b',
        timesPerDay: 1,
        createdAt: DateTime(2026, 1, 1),
        deletedAt: DateTime(2026, 11, 10));
    final active = ProgressService.activeHabits([live, gone], nov);
    expect(active.map((h) => h.id), ['a']);
  });
}
