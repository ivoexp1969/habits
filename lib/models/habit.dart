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
    String? identity,
    this.totalCompletions = 0,
    String? miniVersion,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        identity = _cleanText(identity),
        miniVersion = _cleanText(miniVersion),
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
  // "Atomic Habits" identity this habit is a vote for, e.g. "здрав човек".
  // Stored trimmed; empty/blank is normalized to null. Optional — old records
  // and habits without an identity keep working exactly as before.
  String? identity;
  // Lifetime count of check-ins (increments), never reset on a new day. Used
  // to tally identity "votes" live. `completedTimes` resets daily and cannot
  // provide this, and the global `history` map holds no per-habit data.
  int totalCompletions;
  // "2-minute rule" mini version, e.g. "обувам маратонките". Doing the mini
  // version counts as a normal check-in so the streak survives a hard day.
  // Stored trimmed; blank → null. Optional.
  String? miniVersion;
  DateTime createdAt;

  // Trims a value and collapses blank strings to null so the stored value is
  // always either meaningful or absent.
  static String? _cleanText(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }

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
        'identity': identity,
        'totalCompletions': totalCompletions,
        'miniVersion': miniVersion,
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
      // Old records predate these keys → default null / 0 (backward compatible).
      identity: json['identity'] as String?,
      totalCompletions: (json['totalCompletions'] as num?)?.toInt() ?? 0,
      miniVersion: json['miniVersion'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
