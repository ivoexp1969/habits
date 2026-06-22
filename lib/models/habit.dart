import 'package:flutter/material.dart';

class Habit {
  Habit({
    String? id,
    required this.name,
    required this.timesPerDay,
    this.completedTimes = 0,
    this.color,
    this.icon,
    this.category,
    this.streak = 0,
    this.bestStreak = 0,
    this.lastCompletedDate,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  String id;
  String name;
  int timesPerDay;
  int completedTimes;
  final Color? color;
  final IconData? icon;
  String? category;
  int streak;
  int bestStreak;
  // Date (yyyy-MM-dd) the habit was last fully completed — used to maintain
  // [streak] across days.
  String? lastCompletedDate;
  DateTime createdAt;

  bool get isCompleted => completedTimes >= timesPerDay;

  double get progress {
    if (timesPerDay <= 0) return 0;
    return (completedTimes / timesPerDay).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'timesPerDay': timesPerDay,
        'completedTimes': completedTimes,
        'color': color?.value,
        'icon': icon?.codePoint,
        'category': category,
        'streak': streak,
        'bestStreak': bestStreak,
        'lastCompletedDate': lastCompletedDate,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Habit.fromJson(Map<String, dynamic> json) {
    final colorValue = json['color'];
    final iconCode = json['icon'];
    return Habit(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      timesPerDay: (json['timesPerDay'] as num?)?.toInt() ?? 1,
      completedTimes: (json['completedTimes'] as num?)?.toInt() ?? 0,
      color: colorValue is int ? Color(colorValue) : null,
      icon: iconCode is int
          ? IconData(iconCode, fontFamily: 'MaterialIcons')
          : null,
      category: json['category'] as String?,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
      lastCompletedDate: json['lastCompletedDate'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
