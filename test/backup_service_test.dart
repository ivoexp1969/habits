import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export -> import round-trip restores identical data', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const habits = '[{"id":"1","name":"Вода","timesPerDay":3}]';
    const history = '{"2026-08-10":100.0}';
    await prefs.setString('habits', habits);
    await prefs.setString('history', history);
    await prefs.setInt('xp', 42);

    final exported = await BackupService.exportJson();

    // Simulate the current device having different data before restoring.
    await prefs.setString('habits', 'CHANGED');
    await prefs.setString('history', '{}');
    await prefs.setInt('xp', 0);

    final res = BackupService.validate(exported);
    expect(res.status, BackupStatus.ok);
    await BackupService.apply(res.data!);

    expect(prefs.getString('habits'), habits);
    expect(prefs.getString('history'), history);
    expect(prefs.getInt('xp'), 42);
  });

  test('ad-free entitlement is never exported', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('habits', '[]');
    await prefs.setBool('ads_removed', true);

    final exported = await BackupService.exportJson();
    final decoded = jsonDecode(exported) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    expect(data.containsKey('ads_removed'), isFalse);
  });

  test('a newer backup version is rejected', () {
    final content = jsonEncode({
      'app': 'navici_backup',
      'backupVersion': 999,
      'data': {'habits': '[]'},
    });
    expect(BackupService.validate(content).status, BackupStatus.tooNew);
  });

  test('garbage and missing-habits files are invalid', () {
    expect(BackupService.validate('not json').status, BackupStatus.invalid);
    expect(
      BackupService.validate(jsonEncode({'app': 'something_else'})).status,
      BackupStatus.invalid,
    );
    expect(
      BackupService.validate(jsonEncode({
        'app': 'navici_backup',
        'backupVersion': 1,
        'data': {'xp': 1},
      })).status,
      BackupStatus.invalid,
    );
  });

  test('suggested file name is habits_backup_YYYY-MM-DD.json', () {
    expect(
      BackupService.suggestedFileName(),
      matches(r'^habits_backup_\d{4}-\d{2}-\d{2}\.json$'),
    );
  });
}
