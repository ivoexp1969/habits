import 'package:flutter/material.dart';
import '../models/habit.dart';

class HabitTemplate {
  const HabitTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.buildHabits,
  });
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<Habit> Function() buildHabits;
}

final List<HabitTemplate> habitTemplates = [
  HabitTemplate(
    id: 'morning',
    name: 'Сутрешна рутина',
    description: 'Започни деня с енергия и фокус',
    icon: Icons.wb_sunny_outlined,
    color: const Color(0xFFFF9800),
    buildHabits: () => [
      Habit(name: 'Пия вода', timesPerDay: 8, color: const Color(0xFF4FC3F7), icon: Icons.local_drink),
      Habit(name: 'Разтягане', timesPerDay: 1, color: const Color(0xFFA5D6A7), icon: Icons.self_improvement),
      Habit(name: 'Медитация', timesPerDay: 1, color: const Color(0xFFBA68C8), icon: Icons.spa),
      Habit(name: 'Дневник', timesPerDay: 1, color: const Color(0xFFFFB74D), icon: Icons.menu_book),
    ],
  ),
  HabitTemplate(
    id: 'health',
    name: 'Здравословен живот',
    description: 'Тяло и ум в баланс',
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
    name: 'Продуктивност',
    description: 'Постигни повече всеки ден',
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
    name: 'Равновесие',
    description: 'Спокойствие и осъзнатост',
    icon: Icons.self_improvement,
    color: const Color(0xFF00897B),
    buildHabits: () => [
      Habit(name: 'Медитация', timesPerDay: 1, color: const Color(0xFFBA68C8), icon: Icons.self_improvement),
      Habit(name: 'Намирам радост', timesPerDay: 1, color: const Color(0xFFF48FB1), icon: Icons.favorite_border),
      Habit(name: 'Разходка навън', timesPerDay: 1, color: const Color(0xFF81C784), icon: Icons.park),
      Habit(name: 'Пауза от мрежи', timesPerDay: 1, color: const Color(0xFF80CBC4), icon: Icons.spa),
    ],
  ),
];
