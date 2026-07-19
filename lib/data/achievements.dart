import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';

const String kPrefsAchievements = 'achievements';

/// An achievement's stable identity + visuals. The user-facing title and
/// description are NOT stored here — they are resolved per-locale from [id] via
/// [achievementTitle] / [achievementDescription], so the same saved data works
/// in any language.
class Achievement {
  const Achievement({
    required this.id,
    required this.icon,
    required this.color,
  });
  final String id;
  final IconData icon;
  final Color color;
}

const List<Achievement> allAchievements = [
  Achievement(
    id: 'first_step',
    icon: Icons.emoji_flags,
    color: Color(0xFF69F0AE),
  ),
  Achievement(
    id: 'on_fire',
    icon: Icons.local_fire_department,
    color: Color(0xFFFF1744),
  ),
  Achievement(
    id: 'unstoppable',
    icon: Icons.bolt,
    color: Color(0xFFFFD740),
  ),
  Achievement(
    id: 'perfect_week',
    icon: Icons.workspace_premium,
    color: Color(0xFF00E5FF),
  ),
  Achievement(
    id: 'habit_master',
    icon: Icons.auto_awesome,
    color: Color(0xFFD500F9),
  ),
  Achievement(
    id: 'centurion',
    icon: Icons.military_tech,
    color: Color(0xFF2979FF),
  ),
];

/// Resolves an achievement's localized title by [id].
String achievementTitle(AppLocalizations l10n, String id) => switch (id) {
      'first_step' => l10n.achievementFirstStepTitle,
      'on_fire' => l10n.achievementOnFireTitle,
      'unstoppable' => l10n.achievementUnstoppableTitle,
      'perfect_week' => l10n.achievementPerfectWeekTitle,
      'habit_master' => l10n.achievementHabitMasterTitle,
      'centurion' => l10n.achievementCenturionTitle,
      _ => '',
    };

/// Resolves an achievement's localized description by [id].
String achievementDescription(AppLocalizations l10n, String id) => switch (id) {
      'first_step' => l10n.achievementFirstStepDesc,
      'on_fire' => l10n.achievementOnFireDesc,
      'unstoppable' => l10n.achievementUnstoppableDesc,
      'perfect_week' => l10n.achievementPerfectWeekDesc,
      'habit_master' => l10n.achievementHabitMasterDesc,
      'centurion' => l10n.achievementCenturionDesc,
      _ => '',
    };

class AchievementService {
  static Future<Set<String>> getUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(kPrefsAchievements);
    if (str == null) return {};
    try {
      return (jsonDecode(str) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<bool> _tryUnlock(String id, Set<String> unlocked) async {
    if (unlocked.contains(id)) return false;
    unlocked.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsAchievements, jsonEncode(unlocked.toList()));
    return true;
  }

  // Returns list of newly unlocked achievement ids
  static Future<List<String>> check({
    required List<Habit> habits,
    required Map<String, double> history,
  }) async {
    final unlocked = await getUnlocked();
    final newlyUnlocked = <String>[];

    // first_step
    if (habits.isNotEmpty) {
      if (await _tryUnlock('first_step', unlocked)) newlyUnlocked.add('first_step');
    }

    // habit_master
    if (habits.length >= 5) {
      if (await _tryUnlock('habit_master', unlocked)) newlyUnlocked.add('habit_master');
    }

    // centurion — total completions across habits
    final totalCompletions = habits.fold<int>(0, (sum, h) => sum + h.completedTimes);
    if (totalCompletions >= 100) {
      if (await _tryUnlock('centurion', unlocked)) newlyUnlocked.add('centurion');
    }

    // streak-based
    final today = DateTime.now();
    int streak80 = 0;
    int streak100 = 0;
    for (int i = 0; i < 30; i++) {
      final key = dateKeyFromDate(today.subtract(Duration(days: i)));
      final pct = history[key] ?? 0.0;
      if (pct >= 80) {
        streak80++;
        if (pct >= 100) streak100++;
        else streak100 = 0;
      } else {
        if (i == 0) break; // today not recorded yet — skip streak break
        streak80 = 0;
        break;
      }
    }

    if (streak80 >= 7) {
      if (await _tryUnlock('on_fire', unlocked)) newlyUnlocked.add('on_fire');
    }
    if (streak80 >= 30) {
      if (await _tryUnlock('unstoppable', unlocked)) newlyUnlocked.add('unstoppable');
    }
    if (streak100 >= 7) {
      if (await _tryUnlock('perfect_week', unlocked)) newlyUnlocked.add('perfect_week');
    }

    return newlyUnlocked;
  }
}
