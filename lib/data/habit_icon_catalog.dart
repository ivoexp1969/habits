import "package:flutter/material.dart";

class HabitIconOption {
  const HabitIconOption({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}

/// 20+ тематични иконки + препоръчан цвят.
/// Ползваме ги при създаване на навик (избор на иконка/цвят).
const List<HabitIconOption> habitIconOptions = [
  HabitIconOption(icon: Icons.local_drink, color: Color(0xFF4FC3F7), label: "Вода"),
  HabitIconOption(icon: Icons.menu_book, color: Color(0xFFFFB74D), label: "Четене"),
  HabitIconOption(icon: Icons.fitness_center, color: Color(0xFFA5D6A7), label: "Тренировка"),
  HabitIconOption(icon: Icons.directions_walk, color: Color(0xFF81D4FA), label: "Разходка"),
  HabitIconOption(icon: Icons.directions_run, color: Color(0xFFFF8A65), label: "Бягане"),
  HabitIconOption(icon: Icons.self_improvement, color: Color(0xFFBA68C8), label: "Медитация"),
  HabitIconOption(icon: Icons.bedtime, color: Color(0xFF9575CD), label: "Сън"),
  HabitIconOption(icon: Icons.fastfood, color: Color(0xFFFFCC80), label: "Хранене"),
  HabitIconOption(icon: Icons.restaurant, color: Color(0xFFFFAB91), label: "Готвене"),
  HabitIconOption(icon: Icons.smoke_free, color: Color(0xFF4DB6AC), label: "Без цигари"),
  HabitIconOption(icon: Icons.spa, color: Color(0xFF80CBC4), label: "Грижа"),
  HabitIconOption(icon: Icons.brush, color: Color(0xFFCE93D8), label: "Творчество"),
  HabitIconOption(icon: Icons.music_note, color: Color(0xFF64B5F6), label: "Музика"),
  HabitIconOption(icon: Icons.psychology, color: Color(0xFF90CAF9), label: "Ум"),
  HabitIconOption(icon: Icons.language, color: Color(0xFFB39DDB), label: "Език"),
  HabitIconOption(icon: Icons.timer, color: Color(0xFFFFF176), label: "Фокус"),
  HabitIconOption(icon: Icons.work_outline, color: Color(0xFF90A4AE), label: "Работа"),
  HabitIconOption(icon: Icons.savings, color: Color(0xFFA5D6A7), label: "Финанси"),
  HabitIconOption(icon: Icons.cleaning_services, color: Color(0xFF80DEEA), label: "Чистене"),
  HabitIconOption(icon: Icons.phone_iphone, color: Color(0xFF64B5F6), label: "Телефон"),
  HabitIconOption(icon: Icons.check_circle, color: Color(0xFF4CAF50), label: "Навик"),
  HabitIconOption(icon: Icons.favorite_border, color: Color(0xFFF48FB1), label: "Семейство"),
  HabitIconOption(icon: Icons.pets, color: Color(0xFFA1887F), label: "Домашен любимец"),
  HabitIconOption(icon: Icons.park, color: Color(0xFF81C784), label: "Навън"),
];
