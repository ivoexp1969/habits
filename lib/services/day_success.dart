import 'package:shared_preferences/shared_preferences.dart';

import 'cloud/sync_controller.dart';
import 'habit_service.dart';
import 'progress_migration.dart';
import 'progress_repository.dart';
import 'progress_service.dart';

/// Loads the unified daily-success map (frozen archive before migrationDate +
/// by-date map on/after it) that stats / calendar / heatmap / the global streak
/// consume in place of the raw `history`. See ProgressService.unifiedHistory.
Future<Map<String, double>> loadUnifiedHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final archive = await HabitService.loadHistory();
  final habits = await HabitService.loadHabits();
  // ЕТАП 2: cloud map when sync is live, else the local one (same path off-flag).
  final map = await SyncController.instance
      .activeRepository(LocalProgressRepository.instance)
      .load();
  final migratedAt = prefs.getString(ProgressMigration.kMigratedAt);
  return ProgressService.unifiedHistory(archive, map, habits,
      migratedAt: migratedAt);
}
