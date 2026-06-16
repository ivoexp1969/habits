import 'package:shared_preferences/shared_preferences.dart';
import 'habit_service.dart';

const String kPrefsXP = 'xp';
const String _kPrefsBonusDate = 'bonus_date';

class LevelInfo {
  const LevelInfo({
    required this.level,
    required this.title,
    required this.emoji,
    required this.xp,
    required this.xpThisLevel,
    required this.xpNextLevel,
  });
  final int level;
  final String title;
  final String emoji;
  final int xp;
  final int xpThisLevel;
  final int xpNextLevel; // 0 = max level

  double get progress {
    if (xpNextLevel == 0) return 1.0;
    final range = xpNextLevel - xpThisLevel;
    final done = xp - xpThisLevel;
    return (done / range).clamp(0.0, 1.0);
  }

  int get xpToNext => xpNextLevel == 0 ? 0 : xpNextLevel - xp;
}

// (level, title, emoji, xpRequired)
const _levels = [
  (1, 'Начинаещ', '🌱', 0),
  (2, 'Новак', '🌿', 100),
  (3, 'Стажант', '🌳', 250),
  (4, 'Ученик', '📚', 500),
  (5, 'Изследовател', '🧭', 800),
  (6, 'Любознателен', '💡', 1200),
  (7, 'Практик', '⚡', 1700),
  (8, 'Занаятчия', '🔥', 2300),
  (9, 'Умел', '🎯', 3000),
  (10, 'Опитен', '💎', 3800),
  (11, 'Вещ', '🏆', 4700),
  (12, 'Специалист', '⭐', 5700),
  (13, 'Майстор', '🌟', 6800),
  (14, 'Шампион', '👑', 8000),
  (15, 'Елит', '🦅', 9300),
  (16, 'Ветеран', '🛡️', 10700),
  (17, 'Легенда', '🌠', 12200),
  (18, 'Митичен', '🔮', 13800),
  (19, 'Безсмъртен', '⚜️', 15500),
  (20, 'Господар на навиците', '🏅', 17500),
];

class XpService {
  static Future<int> getXP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(kPrefsXP) ?? 0;
  }

  static LevelInfo getLevelInfo(int xp) {
    int idx = 0;
    for (int i = 0; i < _levels.length; i++) {
      if (xp >= _levels[i].$4) {
        idx = i;
      } else {
        break;
      }
    }
    final isMax = idx == _levels.length - 1;
    return LevelInfo(
      level: _levels[idx].$1,
      title: _levels[idx].$2,
      emoji: _levels[idx].$3,
      xp: xp,
      xpThisLevel: _levels[idx].$4,
      xpNextLevel: isMax ? 0 : _levels[idx + 1].$4,
    );
  }

  // Returns (newXP, leveledUp)
  static Future<(int, bool)> _addXP(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getInt(kPrefsXP) ?? 0;
    final after = before + amount;
    await prefs.setInt(kPrefsXP, after);
    return (after, getLevelInfo(after).level > getLevelInfo(before).level);
  }

  static Future<(int, bool)> onHabitCompleted() => _addXP(10);

  // Returns (newXP, leveledUp, bonusGiven)
  // bonusGiven = false when bonus was already given today
  static Future<(int, bool, bool)> onPerfectDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = dateKeyFromDate(DateTime.now());
    if (prefs.getString(_kPrefsBonusDate) == today) {
      return (prefs.getInt(kPrefsXP) ?? 0, false, false);
    }
    await prefs.setString(_kPrefsBonusDate, today);
    final (newXP, leveledUp) = await _addXP(50);
    return (newXP, leveledUp, true);
  }
}
