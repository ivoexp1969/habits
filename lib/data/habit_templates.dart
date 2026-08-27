import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/habit.dart';

/// A starter pack of habits. The pack's user-facing [name] and [description],
/// and the habit names built by [buildHabits], are all resolved per-locale so
/// the standard habits switch language with the app. Note: names are stored
/// verbatim when added, so de-duplication matches within the active language.
class HabitTemplate {
  const HabitTemplate({
    required this.id,
    required this.icon,
    required this.color,
    required this.buildHabits,
  });
  final String id;
  final IconData icon;
  final Color color;
  final List<Habit> Function(AppLocalizations l10n) buildHabits;
}

/// Localized pack title for [id].
String templateName(AppLocalizations l10n, String id) => switch (id) {
      'morning' => l10n.templateMorningName,
      'health' => l10n.templateHealthName,
      'focus' => l10n.templateFocusName,
      'mindfulness' => l10n.templateMindfulnessName,
      _ => '',
    };

/// Localized pack description for [id].
String templateDescription(AppLocalizations l10n, String id) => switch (id) {
      'morning' => l10n.templateMorningDesc,
      'health' => l10n.templateHealthDesc,
      'focus' => l10n.templateFocusDesc,
      'mindfulness' => l10n.templateMindfulnessDesc,
      _ => '',
    };

final List<HabitTemplate> habitTemplates = [
  HabitTemplate(
    id: 'morning',
    icon: Icons.wb_sunny_outlined,
    color: const Color(0xFFFF9800),
    buildHabits: (l10n) => [
      Habit(name: l10n.tplWater, timesPerDay: 8, color: const Color(0xFF4FC3F7), icon: Icons.local_drink),
      Habit(name: l10n.tplStretch, timesPerDay: 1, color: const Color(0xFFA5D6A7), icon: Icons.accessibility_new),
      Habit(name: l10n.tplMeditate, timesPerDay: 1, color: const Color(0xFFBA68C8), icon: Icons.self_improvement),
      Habit(name: l10n.tplJournal, timesPerDay: 1, color: const Color(0xFFFFB74D), icon: Icons.menu_book),
    ],
  ),
  HabitTemplate(
    id: 'health',
    icon: Icons.favorite_border,
    color: const Color(0xFFE53935),
    buildHabits: (l10n) => [
      Habit(name: l10n.tplSport, timesPerDay: 1, color: const Color(0xFFA5D6A7), icon: Icons.fitness_center),
      Habit(name: l10n.tplWater, timesPerDay: 8, color: const Color(0xFF4FC3F7), icon: Icons.local_drink),
      Habit(name: l10n.tplSleep, timesPerDay: 1, color: const Color(0xFF9575CD), icon: Icons.bedtime),
      Habit(name: l10n.tplHealthyFood, timesPerDay: 3, color: const Color(0xFF81C784), icon: Icons.restaurant),
      Habit(name: l10n.tplWalk, timesPerDay: 1, color: const Color(0xFF81D4FA), icon: Icons.directions_walk),
    ],
  ),
  HabitTemplate(
    id: 'focus',
    icon: Icons.psychology_outlined,
    color: const Color(0xFF1565C0),
    buildHabits: (l10n) => [
      Habit(name: l10n.tplRead, timesPerDay: 1, color: const Color(0xFFFFB74D), icon: Icons.menu_book),
      Habit(name: l10n.tplFocusWork, timesPerDay: 2, color: const Color(0xFF90A4AE), icon: Icons.work_outline),
      Habit(name: l10n.tplStudy, timesPerDay: 1, color: const Color(0xFFB39DDB), icon: Icons.language),
      Habit(name: l10n.tplNoPhone, timesPerDay: 1, color: const Color(0xFF64B5F6), icon: Icons.phone_iphone),
    ],
  ),
  HabitTemplate(
    id: 'mindfulness',
    icon: Icons.self_improvement,
    color: const Color(0xFF00897B),
    buildHabits: (l10n) => [
      Habit(name: l10n.tplMeditate, timesPerDay: 1, color: const Color(0xFFBA68C8), icon: Icons.self_improvement),
      Habit(name: l10n.tplJoy, timesPerDay: 1, color: const Color(0xFFF48FB1), icon: Icons.favorite_border),
      Habit(name: l10n.tplWalk, timesPerDay: 1, color: const Color(0xFF81D4FA), icon: Icons.directions_walk),
      Habit(name: l10n.tplNoSocial, timesPerDay: 1, color: const Color(0xFF80CBC4), icon: Icons.spa),
    ],
  ),
];
