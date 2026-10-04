import "package:flutter/material.dart";

import "../l10n/app_localizations.dart";

class HabitIconOption {
  const HabitIconOption({
    required this.icon,
    required this.color,
    required this.labelKey,
  });

  final IconData icon;
  final Color color;

  /// Stable key resolved per-locale via [habitIconLabel] (never a display
  /// string, so the catalog stays language-independent).
  final String labelKey;
}

/// 20+ themed icons + a suggested color.
/// Used when creating a habit (icon/color picker).
const List<HabitIconOption> habitIconOptions = [
  HabitIconOption(icon: Icons.local_drink, color: Color(0xFF4FC3F7), labelKey: "water"),
  HabitIconOption(icon: Icons.menu_book, color: Color(0xFFFFB74D), labelKey: "reading"),
  HabitIconOption(icon: Icons.fitness_center, color: Color(0xFFA5D6A7), labelKey: "workout"),
  HabitIconOption(icon: Icons.directions_walk, color: Color(0xFF81D4FA), labelKey: "walk"),
  HabitIconOption(icon: Icons.directions_run, color: Color(0xFFFF8A65), labelKey: "run"),
  HabitIconOption(icon: Icons.self_improvement, color: Color(0xFFBA68C8), labelKey: "meditation"),
  HabitIconOption(icon: Icons.bedtime, color: Color(0xFF9575CD), labelKey: "sleep"),
  HabitIconOption(icon: Icons.fastfood, color: Color(0xFFFFCC80), labelKey: "eating"),
  HabitIconOption(icon: Icons.restaurant, color: Color(0xFFFFAB91), labelKey: "cooking"),
  HabitIconOption(icon: Icons.smoke_free, color: Color(0xFF4DB6AC), labelKey: "noSmoking"),
  HabitIconOption(icon: Icons.spa, color: Color(0xFF80CBC4), labelKey: "selfCare"),
  HabitIconOption(icon: Icons.brush, color: Color(0xFFCE93D8), labelKey: "creativity"),
  HabitIconOption(icon: Icons.music_note, color: Color(0xFF64B5F6), labelKey: "music"),
  HabitIconOption(icon: Icons.psychology, color: Color(0xFF90CAF9), labelKey: "mind"),
  HabitIconOption(icon: Icons.language, color: Color(0xFFB39DDB), labelKey: "language"),
  HabitIconOption(icon: Icons.timer, color: Color(0xFFFFF176), labelKey: "focus"),
  HabitIconOption(icon: Icons.work_outline, color: Color(0xFF90A4AE), labelKey: "work"),
  HabitIconOption(icon: Icons.savings, color: Color(0xFFA5D6A7), labelKey: "finance"),
  HabitIconOption(icon: Icons.cleaning_services, color: Color(0xFF80DEEA), labelKey: "cleaning"),
  HabitIconOption(icon: Icons.phone_iphone, color: Color(0xFF64B5F6), labelKey: "phone"),
  HabitIconOption(icon: Icons.check_circle, color: Color(0xFF4CAF50), labelKey: "habit"),
  HabitIconOption(icon: Icons.favorite_border, color: Color(0xFFF48FB1), labelKey: "family"),
  HabitIconOption(icon: Icons.pets, color: Color(0xFFA1887F), labelKey: "pet"),
  HabitIconOption(icon: Icons.park, color: Color(0xFF81C784), labelKey: "outdoors"),
];

/// Curated 12-colour brand palette for the habit colour picker (create + edit).
/// Independent of the per-icon colours above: the icon gives a default colour,
/// this list lets the user override it.
const List<Color> habitColorPalette = [
  Color(0xFF00E5FF), // cyan (brand)
  Color(0xFF7C4DFF), // purple (brand)
  Color(0xFFFF2D95), // pink (brand)
  Color(0xFFEF5350), // red
  Color(0xFFFF8A65), // coral
  Color(0xFFFFB74D), // amber
  Color(0xFFA5D6A7), // green
  Color(0xFF4DB6AC), // teal
  Color(0xFF4FC3F7), // light blue
  Color(0xFF5C6BC0), // indigo
  Color(0xFFBA68C8), // violet-pink
  Color(0xFF8D6E63), // brown/neutral
];

/// Resolves an icon option's localized label from its [labelKey].
String habitIconLabel(AppLocalizations l10n, String key) => switch (key) {
      "water" => l10n.iconWater,
      "reading" => l10n.iconReading,
      "workout" => l10n.iconWorkout,
      "walk" => l10n.iconWalk,
      "run" => l10n.iconRun,
      "meditation" => l10n.iconMeditation,
      "sleep" => l10n.iconSleep,
      "eating" => l10n.iconEating,
      "cooking" => l10n.iconCooking,
      "noSmoking" => l10n.iconNoSmoking,
      "selfCare" => l10n.iconSelfCare,
      "creativity" => l10n.iconCreativity,
      "music" => l10n.iconMusic,
      "mind" => l10n.iconMind,
      "language" => l10n.iconLanguage,
      "focus" => l10n.iconFocus,
      "work" => l10n.iconWork,
      "finance" => l10n.iconFinance,
      "cleaning" => l10n.iconCleaning,
      "phone" => l10n.iconPhone,
      "habit" => l10n.iconHabit,
      "family" => l10n.iconFamily,
      "pet" => l10n.iconPet,
      "outdoors" => l10n.iconOutdoors,
      _ => "",
    };
