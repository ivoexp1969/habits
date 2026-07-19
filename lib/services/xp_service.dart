import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'habit_service.dart';

const String kPrefsXP = 'xp';
const String _kPrefsBonusDate = 'bonus_date';

class LevelInfo {
  const LevelInfo({
    required this.level,
    required this.emoji,
    required this.xp,
    required this.xpThisLevel,
    required this.xpNextLevel,
  });
  final int level;
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

// (level, emoji, xpRequired). Level titles are resolved per-locale from the
// level number via [levelTitle], so no user-facing text lives here.
const _levels = [
  (1, '🌱', 0),
  (2, '🌿', 100),
  (3, '🌳', 250),
  (4, '📚', 500),
  (5, '🧭', 800),
  (6, '💡', 1200),
  (7, '⚡', 1700),
  (8, '🔥', 2300),
  (9, '🎯', 3000),
  (10, '💎', 3800),
  (11, '🏆', 4700),
  (12, '⭐', 5700),
  (13, '🌟', 6800),
  (14, '👑', 8000),
  (15, '🦅', 9300),
  (16, '🛡️', 10700),
  (17, '🌠', 12200),
  (18, '🔮', 13800),
  (19, '⚜️', 15500),
  (20, '🏅', 17500),
];

/// Resolves a level's localized title (1..20) from the level number.
String levelTitle(AppLocalizations l10n, int level) => switch (level) {
      1 => l10n.level1,
      2 => l10n.level2,
      3 => l10n.level3,
      4 => l10n.level4,
      5 => l10n.level5,
      6 => l10n.level6,
      7 => l10n.level7,
      8 => l10n.level8,
      9 => l10n.level9,
      10 => l10n.level10,
      11 => l10n.level11,
      12 => l10n.level12,
      13 => l10n.level13,
      14 => l10n.level14,
      15 => l10n.level15,
      16 => l10n.level16,
      17 => l10n.level17,
      18 => l10n.level18,
      19 => l10n.level19,
      20 => l10n.level20,
      _ => l10n.level1,
    };

class XpService {
  static Future<int> getXP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(kPrefsXP) ?? 0;
  }

  static LevelInfo getLevelInfo(int xp) {
    int idx = 0;
    for (int i = 0; i < _levels.length; i++) {
      if (xp >= _levels[i].$3) {
        idx = i;
      } else {
        break;
      }
    }
    final isMax = idx == _levels.length - 1;
    return LevelInfo(
      level: _levels[idx].$1,
      emoji: _levels[idx].$2,
      xp: xp,
      xpThisLevel: _levels[idx].$3,
      xpNextLevel: isMax ? 0 : _levels[idx + 1].$3,
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
