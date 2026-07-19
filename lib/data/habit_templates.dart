import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/habit.dart';

/// A starter pack of habits. The pack's user-facing [name] and [description]
/// are resolved per-locale from [id] via [templateName] / [templateDescription]
/// — the habit names built by [buildHabits] are NOT localized (they are stored
/// verbatim in prefs and matched by name during migrations / de-duplication).
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
  final List<Habit> Function() buildHabits;
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
    buildHabits: () => [
      Habit(name: 'Пия вода', timesPerDay: 8, color: const Color(0xFF4FC3F7), icon: Icons.local_drink),
      Habit(name: 'Разтягане', timesPerDay: 1, color: const Color(0xFFA5D6A7), icon: Icons.accessibility_new),
      Habit(name: 'Медитация', timesPerDay: 1, color: const Color(0xFFBA68C8), icon: Icons.self_improvement),
      Habit(name: 'Дневник', timesPerDay: 1, color: const Color(0xFFFFB74D), icon: Icons.menu_book),
    ],
  ),
  HabitTemplate(
    id: 'health',
    icon: Icons.favorite_border,
    color: const Color(0xFFE53935),
    buildHabits: () => [
      Habit(name: 'Спорт', timesPerDay: 1, color: const Color(0xFFA5D6A7), icon: Icons.fitness_center),
      Habit(name: 'Пия вода', timesPerDay: 8, color: const Color(0xFF4FC3F7), icon: Icons.local_drink),
      Habit(name: 'Сън 8 часа', timesPerDay: 1, color: const Color(0xFF9575CD), icon: Icons.bedtime),
      Habit(name: 'Здравословна храна', timesPerDay: 3, color: const Color(0xFF81C784), icon: Icons.restaurant),
      Habit(name: 'Разходка', timesPerDay: 1, color: const Color(0xFF81D4FA), icon: Icons.directions_walk),
    ],
  ),
  HabitTemplate(
    id: 'focus',
    icon: Icons.psychology_outlined,
    color: const Color(0xFF1565C0),
    buildHabits: () => [
      Habit(name: 'Четене 30мин', timesPerDay: 1, color: const Color(0xFFFFB74D), icon: Icons.menu_book),
      Habit(name: 'Фокусирана работа', timesPerDay: 2, color: const Color(0xFF90A4AE), icon: Icons.work_outline),
      Habit(name: 'Учене', timesPerDay: 1, color: const Color(0xFFB39DDB), icon: Icons.language),
      Habit(name: 'Без телефон 1ч', timesPerDay: 1, color: const Color(0xFF64B5F6), icon: Icons.phone_iphone),
    ],
  ),
  HabitTemplate(
    id: 'mindfulness',
    icon: Icons.self_improvement,
    color: const Color(0xFF00897B),
    buildHabits: () => [
      Habit(name: 'Медитация', timesPerDay: 1, color: const Color(0xFFBA68C8), icon: Icons.self_improvement),
      Habit(name: 'Намирам радост', timesPerDay: 1, color: const Color(0xFFF48FB1), icon: Icons.favorite_border),
      Habit(name: 'Разходка', timesPerDay: 1, color: const Color(0xFF81D4FA), icon: Icons.directions_walk),
      Habit(name: 'Пауза от мрежи', timesPerDay: 1, color: const Color(0xFF80CBC4), icon: Icons.spa),
    ],
  ),
];
