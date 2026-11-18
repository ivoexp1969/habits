import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habits/data/achievements.dart';
import 'package:habits/models/habit.dart';

/// 5c: achievements survive the switch to the unified history.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Habit h(String id, {int total = 0}) => Habit(
      id: id,
      name: id,
      timesPerDay: 1,
      totalCompletions: total,
      createdAt: DateTime(2026, 1, 1));

  test('an unlocked achievement is kept and NOT re-unlocked on recompute', () async {
    final habits = [h('a')]; // non-empty → first_step
    final first = await AchievementService.check(habits: habits, history: {});
    expect(first, contains('first_step')); // newly unlocked → congratulate once

    final second = await AchievementService.check(habits: habits, history: {});
    expect(second, isEmpty); // recompute → nothing NEW (no repeat congrats)

    expect(await AchievementService.getUnlocked(), contains('first_step')); // kept
  });

  test('centurion uses lifetime totalCompletions, not today completedTimes', () async {
    // 100 lifetime check-ins, 0 today — must still unlock centurion.
    final got =
        await AchievementService.check(habits: [h('a', total: 100)], history: {});
    expect(got, contains('centurion'));
  });
}
