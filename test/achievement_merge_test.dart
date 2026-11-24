import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:habits/data/achievements.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ЕТАП 2 — another device's unlocked achievements merge into the local set.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mergeUnlocked unions incoming ids, keeps existing, writes once', () async {
    SharedPreferences.setMockInitialValues(
        {'achievements': jsonEncode(['first_step'])});
    final merged = await AchievementService.mergeUnlocked({'centurion', 'first_step'});
    expect(merged, {'first_step', 'centurion'});
    // persisted
    final prefs = await SharedPreferences.getInstance();
    expect((jsonDecode(prefs.getString('achievements')!) as List).toSet(),
        {'first_step', 'centurion'});
  });

  test('mergeUnlocked with nothing new does not change the set', () async {
    SharedPreferences.setMockInitialValues(
        {'achievements': jsonEncode(['a', 'b'])});
    final merged = await AchievementService.mergeUnlocked({'a'});
    expect(merged, {'a', 'b'});
  });
}
