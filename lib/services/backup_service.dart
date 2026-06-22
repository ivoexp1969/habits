import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Exports / imports the user's data (habits, history, XP, achievements,
/// profile) to a JSON file. The app stores everything locally, so this is the
/// only protection against losing data on uninstall / device change.
///
/// Note: the ad-free entitlement is deliberately NOT included — it is a
/// purchase, not user content, and must not be transferable via a backup file.
class BackupService {
  // key -> type ('string' | 'int')
  static const Map<String, String> _keys = {
    'habits': 'string',
    'history': 'string',
    'profile': 'string',
    'achievements': 'string',
    'bonus_date': 'string',
    'last_active_date': 'string',
    'xp': 'int',
    'habits_ver': 'int',
  };

  /// Builds the backup JSON string from the current stored data.
  static Future<String> exportJson() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    _keys.forEach((k, type) {
      final v = type == 'int' ? prefs.getInt(k) : prefs.getString(k);
      if (v != null) data[k] = v;
    });
    return jsonEncode({
      'app': 'navici_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  /// Suggested file name for the backup (date-stamped).
  static String suggestedFileName() {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'navici_backup_$stamp.json';
  }

  /// Restores data from a backup file's contents. Returns true on success.
  static Future<bool> importJson(String content) async {
    try {
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      if (decoded['app'] != 'navici_backup') return false;
      final data = decoded['data'] as Map<String, dynamic>?;
      if (data == null) return false;
      final prefs = await SharedPreferences.getInstance();
      _keys.forEach((k, type) {
        if (!data.containsKey(k)) return;
        final v = data[k];
        if (type == 'int' && v is num) {
          prefs.setInt(k, v.toInt());
        } else if (type == 'string' && v is String) {
          prefs.setString(k, v);
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
