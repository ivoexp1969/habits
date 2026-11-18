import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habits/services/backup_service.dart';
import 'package:habits/services/habit_service.dart';
import 'package:habits/services/progress_migration.dart';
import 'package:habits/services/progress_repository.dart';

/// 5e: importing an OLD (v1) backup must flow through the SAME migration — it
/// must NOT be applied as-is (which would leave an empty by-date map).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('importing an old backup re-runs the migration (map + baselines)', () async {
    // The device has already migrated once (schema flag set).
    SharedPreferences.setMockInitialValues({
      ProgressMigration.kSchemaVersion: 2,
      'progress_map_v2': '{}',
    });
    LocalProgressRepository.instance.resetCache();

    // An OLD backup (v1): old per-habit fields, no by-date map.
    const today = '2026-11-17';
    final oldHabits = jsonEncode([
      {
        'id': 'a',
        'name': 'A',
        'timesPerDay': 1,
        'frequencyUnit': 'day',
        'completedTimes': 1,
        'periodKey': today,
        'lastCompletedDate': today,
        'streak': 4,
        'createdAt': '2026-01-01T00:00:00.000',
      }
    ]);
    final backup = jsonEncode({
      'app': 'navici_backup',
      'backupVersion': 1,
      'data': {'habits': oldHabits},
    });

    final res = BackupService.validate(backup);
    expect(res.status, BackupStatus.ok);
    await BackupService.apply(res.data!);

    // apply() cleared the schema flag → migration runs again on the imported data.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(ProgressMigration.kSchemaVersion), isNull);

    final migrated = await ProgressMigration.runIfNeeded(
        prefs, LocalProgressRepository.instance, DateTime(2026, 11, 17));
    expect(migrated, isTrue);

    // Map seeded from the old completedTimes (completed today → timesPerDay).
    final map = await LocalProgressRepository.instance.load();
    expect(map['2026-11-17'], {'a': 1});
    // Baselines stamped from the old streak / lastCompletedDate.
    final habits = await HabitService.loadHabits();
    expect(habits.single.streakBaseline, 4);
    expect(habits.single.baselineDate, today);
  });
}
