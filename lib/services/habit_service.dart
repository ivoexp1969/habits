import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';

const String kPrefsHabits = 'habits';
const String kPrefsHistory = 'history';
const String kPrefsProfile = 'profile';

String dateKeyFromDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

class HabitStore {
  HabitStore._();
  static final HabitStore instance = HabitStore._();
  List<Habit> currentHabits = const [];
  void setHabits(List<Habit> habits) => currentHabits = List<Habit>.from(habits);
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
