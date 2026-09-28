import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/habit.dart';

/// The goal a starter pack belongs to. Packs are shown grouped under these
/// headers so the presets read as "pick a goal, then habits", not a flat list.
enum HabitGoal { energyBody, sleepRest, mindFocus, relationships, moneyOrder }

/// Display order of the goal groups in the presets sheet.
const List<HabitGoal> habitGoalOrder = [
  HabitGoal.energyBody,
  HabitGoal.sleepRest,
  HabitGoal.mindFocus,
  HabitGoal.relationships,
  HabitGoal.moneyOrder,
];

/// Localized goal-group title.
String goalName(AppLocalizations l10n, HabitGoal g) => switch (g) {
      HabitGoal.energyBody => l10n.goalEnergyBody,
      HabitGoal.sleepRest => l10n.goalSleepRest,
      HabitGoal.mindFocus => l10n.goalMindFocus,
      HabitGoal.relationships => l10n.goalRelationships,
      HabitGoal.moneyOrder => l10n.goalMoneyOrder,
    };

/// A single preset habit = the [Habit] to add plus a localized "why it helps"
/// [description]. The suggested frequency is the habit's own `timesPerDay`
/// (rendered via `timesPerDayShort`), so it never drifts out of sync.
class PresetHabit {
  const PresetHabit({required this.build, required this.description});
  final Habit Function(AppLocalizations l10n) build;
  final String Function(AppLocalizations l10n) description;
}

/// A starter pack. Its user-facing [name]/[description] and the habit names are
/// resolved per-locale so the standard habits switch language with the app.
class HabitTemplate {
  const HabitTemplate({
    required this.id,
    required this.goal,
    required this.icon,
    required this.color,
    required this.presets,
  });
  final String id;
  final HabitGoal goal;
  final IconData icon;
  final Color color;
  final List<PresetHabit> presets;

  /// The plain habits to add (used by the add flow + duplicate counting).
  List<Habit> buildHabits(AppLocalizations l10n) =>
      presets.map((p) => p.build(l10n)).toList();
}

/// Localized pack title for [id].
String templateName(AppLocalizations l10n, String id) => switch (id) {
      'morning' => l10n.templateMorningName,
      'health' => l10n.templateHealthName,
      'focus' => l10n.templateFocusName,
      'mindfulness' => l10n.templateMindfulnessName,
      'relationships' => l10n.templateRelationshipsName,
      'moneyOrder' => l10n.templateMoneyOrderName,
      _ => '',
    };

/// Localized pack description for [id].
String templateDescription(AppLocalizations l10n, String id) => switch (id) {
      'morning' => l10n.templateMorningDesc,
      'health' => l10n.templateHealthDesc,
      'focus' => l10n.templateFocusDesc,
      'mindfulness' => l10n.templateMindfulnessDesc,
      'relationships' => l10n.templateRelationshipsDesc,
      'moneyOrder' => l10n.templateMoneyOrderDesc,
      _ => '',
    };

// ── Reusable habit builders (name/icon/color/frequency unchanged) ──────────
Habit _water(AppLocalizations l) => Habit(
    name: l.tplWater, timesPerDay: 8, color: const Color(0xFF4FC3F7), icon: Icons.local_drink);
Habit _stretch(AppLocalizations l) => Habit(
    name: l.tplStretch, timesPerDay: 1, color: const Color(0xFFA5D6A7), icon: Icons.accessibility_new);
Habit _meditate(AppLocalizations l) => Habit(
    name: l.tplMeditate, timesPerDay: 1, color: const Color(0xFFBA68C8), icon: Icons.self_improvement);
Habit _journal(AppLocalizations l) => Habit(
    name: l.tplJournal, timesPerDay: 1, color: const Color(0xFFFFB74D), icon: Icons.menu_book);
Habit _sport(AppLocalizations l) => Habit(
    name: l.tplSport, timesPerDay: 1, color: const Color(0xFFA5D6A7), icon: Icons.fitness_center);
Habit _sleep(AppLocalizations l) => Habit(
    name: l.tplSleep, timesPerDay: 1, color: const Color(0xFF9575CD), icon: Icons.bedtime);
Habit _healthyFood(AppLocalizations l) => Habit(
    name: l.tplHealthyFood, timesPerDay: 3, color: const Color(0xFF81C784), icon: Icons.restaurant);
Habit _walk(AppLocalizations l) => Habit(
    name: l.tplWalk, timesPerDay: 1, color: const Color(0xFF81D4FA), icon: Icons.directions_walk);
Habit _read(AppLocalizations l) => Habit(
    name: l.tplRead, timesPerDay: 1, color: const Color(0xFFFFB74D), icon: Icons.menu_book);
Habit _focusWork(AppLocalizations l) => Habit(
    name: l.tplFocusWork, timesPerDay: 2, color: const Color(0xFF90A4AE), icon: Icons.work_outline);
Habit _study(AppLocalizations l) => Habit(
    name: l.tplStudy, timesPerDay: 1, color: const Color(0xFFB39DDB), icon: Icons.language);
Habit _noPhone(AppLocalizations l) => Habit(
    name: l.tplNoPhone, timesPerDay: 1, color: const Color(0xFF64B5F6), icon: Icons.phone_iphone);
Habit _joy(AppLocalizations l) => Habit(
    name: l.tplJoy, timesPerDay: 1, color: const Color(0xFFF48FB1), icon: Icons.favorite_border);
Habit _noSocial(AppLocalizations l) => Habit(
    name: l.tplNoSocial, timesPerDay: 1, color: const Color(0xFF80CBC4), icon: Icons.spa);
// New habits (icons chosen from habitIconOptions so icon (de)serialization is safe).
Habit _callLovedOne(AppLocalizations l) => Habit(
    name: l.tplCallLovedOne, timesPerDay: 1, color: const Color(0xFF64B5F6), icon: Icons.phone_iphone);
Habit _familyTime(AppLocalizations l) => Habit(
    name: l.tplFamilyTime, timesPerDay: 1, color: const Color(0xFFF48FB1), icon: Icons.favorite_border);
Habit _thankSomeone(AppLocalizations l) => Habit(
    name: l.tplThankSomeone, timesPerDay: 1, color: const Color(0xFF80CBC4), icon: Icons.spa);
Habit _trackExpenses(AppLocalizations l) => Habit(
    name: l.tplTrackExpenses, timesPerDay: 1, color: const Color(0xFFA5D6A7), icon: Icons.savings);
Habit _tidy(AppLocalizations l) => Habit(
    name: l.tplTidy, timesPerDay: 1, color: const Color(0xFF80DEEA), icon: Icons.cleaning_services);
Habit _reviewBudget(AppLocalizations l) => Habit(
    name: l.tplReviewBudget, timesPerDay: 1, color: const Color(0xFFFFB74D), icon: Icons.savings);

final List<HabitTemplate> habitTemplates = [
  HabitTemplate(
    id: 'morning',
    goal: HabitGoal.energyBody,
    icon: Icons.wb_sunny_outlined,
    color: const Color(0xFFFF9800),
    presets: [
      PresetHabit(build: _water, description: (l) => l.descWater),
      PresetHabit(build: _stretch, description: (l) => l.descStretch),
      PresetHabit(build: _meditate, description: (l) => l.descMeditate),
      PresetHabit(build: _journal, description: (l) => l.descJournal),
    ],
  ),
  HabitTemplate(
    id: 'health',
    goal: HabitGoal.energyBody,
    icon: Icons.favorite_border,
    color: const Color(0xFFE53935),
    presets: [
      PresetHabit(build: _sport, description: (l) => l.descSport),
      PresetHabit(build: _water, description: (l) => l.descWater),
      PresetHabit(build: _sleep, description: (l) => l.descSleep),
      PresetHabit(build: _healthyFood, description: (l) => l.descHealthyFood),
      PresetHabit(build: _walk, description: (l) => l.descWalk),
    ],
  ),
  HabitTemplate(
    id: 'mindfulness',
    goal: HabitGoal.sleepRest,
    icon: Icons.self_improvement,
    color: const Color(0xFF00897B),
    presets: [
      PresetHabit(build: _meditate, description: (l) => l.descMeditate),
      PresetHabit(build: _joy, description: (l) => l.descJoy),
      PresetHabit(build: _walk, description: (l) => l.descWalk),
      PresetHabit(build: _noSocial, description: (l) => l.descNoSocial),
    ],
  ),
  HabitTemplate(
    id: 'focus',
    goal: HabitGoal.mindFocus,
    icon: Icons.psychology_outlined,
    color: const Color(0xFF1565C0),
    presets: [
      PresetHabit(build: _read, description: (l) => l.descRead),
      PresetHabit(build: _focusWork, description: (l) => l.descFocusWork),
      PresetHabit(build: _study, description: (l) => l.descStudy),
      PresetHabit(build: _noPhone, description: (l) => l.descNoPhone),
    ],
  ),
  HabitTemplate(
    id: 'relationships',
    goal: HabitGoal.relationships,
    icon: Icons.favorite_border,
    color: const Color(0xFFEC407A),
    presets: [
      PresetHabit(build: _callLovedOne, description: (l) => l.descCallLovedOne),
      PresetHabit(build: _familyTime, description: (l) => l.descFamilyTime),
      PresetHabit(build: _thankSomeone, description: (l) => l.descThankSomeone),
    ],
  ),
  HabitTemplate(
    id: 'moneyOrder',
    goal: HabitGoal.moneyOrder,
    icon: Icons.savings,
    color: const Color(0xFF43A047),
    presets: [
      PresetHabit(build: _trackExpenses, description: (l) => l.descTrackExpenses),
      PresetHabit(build: _tidy, description: (l) => l.descTidy),
      PresetHabit(build: _reviewBudget, description: (l) => l.descReviewBudget),
    ],
  ),
];
