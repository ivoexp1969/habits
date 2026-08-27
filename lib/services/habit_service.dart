import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

const String kPrefsHabits = 'habits';
const String kPrefsHistory = 'history';
const String kPrefsProfile = 'profile';
const String kPrefsLastActiveDate = 'last_active_date';

String dateKeyFromDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Key identifying the period [d] falls in for a habit whose frequency is
/// [unit] ('day' | 'week' | 'month'). Two dates in the same period share a key,
/// so a counter is reset exactly when the key changes:
///   day   -> 'YYYY-MM-DD'
///   week  -> 'YYYY-Www' (ISO-8601 week, Monday-based, Thursday rule)
///   month -> 'YYYY-MM'
String periodKeyFor(String unit, DateTime d) {
  switch (unit) {
    case 'week':
      final day = DateTime(d.year, d.month, d.day);
      // Thursday of this ISO week decides the ISO year + week number.
      final thursday = day.add(Duration(days: 4 - day.weekday));
      final firstThursday = DateTime(thursday.year, 1, 1);
      final week = 1 + (thursday.difference(firstThursday).inDays ~/ 7);
      return '${thursday.year.toString().padLeft(4, '0')}'
          '-W${week.toString().padLeft(2, '0')}';
    case 'month':
      return '${d.year.toString().padLeft(4, '0')}'
          '-${d.month.toString().padLeft(2, '0')}';
    default:
      return dateKeyFromDate(d);
  }
}

class HabitService {
  static Future<List<Habit>> loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(kPrefsHabits);
    if (str == null) return [];
    try {
      final List<dynamic> data = jsonDecode(str) as List<dynamic>;
      return data.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveHabits(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsHabits, jsonEncode(habits.map((h) => h.toJson()).toList()));
  }

  static Future<Map<String, double>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(kPrefsHistory);
    if (str == null) return {};
    try {
      final Map<String, dynamic> data = jsonDecode(str) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveProgress(double dayProgress) async {
    final prefs = await SharedPreferences.getInstance();
    final key = dateKeyFromDate(DateTime.now());
    final history = await loadHistory();
    history[key] = dayProgress * 100;
    await prefs.setString(kPrefsHistory, jsonEncode(history));
  }
}
