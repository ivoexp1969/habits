import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Outcome of validating a backup file before applying it.
enum BackupStatus {
  /// Valid and safe to restore.
  ok,

  /// Not a Навици backup, corrupted, or missing required fields.
  invalid,

  /// A backup written by a newer app version than this one understands.
  tooNew,
}

/// Result of [BackupService.validate]: a [status] plus the raw `data` map when
/// the status is [BackupStatus.ok].
class BackupResult {
  const BackupResult(this.status, [this.data]);
  final BackupStatus status;
  final Map<String, dynamic>? data;
}

/// Exports / imports the user's data (habits, history, XP, achievements,
/// profile) to a JSON file. The app stores everything locally, so this is the
/// only protection against losing data on uninstall / device change.
///
/// Note: the ad-free entitlement is deliberately NOT included — it is a
/// purchase, not user content, and must not be transferable via a backup file.
class BackupService {
  /// Bumped whenever the backup shape changes incompatibly. A file whose
  /// version is higher than this is rejected (see [BackupStatus.tooNew]) so an
  /// older app never half-reads a newer format.
  static const int backupVersion = 1;

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
      // 'version' kept for files read by older builds; 'backupVersion' is the
      // canonical field going forward.
      'version': backupVersion,
      'backupVersion': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  /// Suggested file name for the backup, e.g. `habits_backup_2026-08-10.json`.
  static String suggestedFileName() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'habits_backup_$y-$m-$d.json';
  }

  /// Parses and validates a backup file's contents WITHOUT modifying anything,
  /// so the caller can confirm with the user before replacing their data.
  static BackupResult validate(String content) {
    try {
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      if (decoded['app'] != 'navici_backup') {
        return const BackupResult(BackupStatus.invalid);
      }
      final rawVer = decoded['backupVersion'] ?? decoded['version'];
      final ver = rawVer is num ? rawVer.toInt() : null;
      if (ver == null) return const BackupResult(BackupStatus.invalid);
      if (ver > backupVersion) return const BackupResult(BackupStatus.tooNew);
      final data = decoded['data'];
      // Require at least the habits payload — a backup without it is unusable.
      if (data is! Map<String, dynamic> || data['habits'] is! String) {
        return const BackupResult(BackupStatus.invalid);
      }
      return BackupResult(BackupStatus.ok, data);
    } catch (_) {
      return const BackupResult(BackupStatus.invalid);
    }
  }

  /// Writes a validated backup's `data` map into storage, replacing the current
  /// values. Call only after [validate] returned [BackupStatus.ok].
  static Future<void> apply(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _keys.entries) {
      final k = entry.key;
      if (!data.containsKey(k)) continue;
      final v = data[k];
      if (entry.value == 'int' && v is num) {
        await prefs.setInt(k, v.toInt());
      } else if (entry.value == 'string' && v is String) {
        await prefs.setString(k, v);
      }
    }
  }
}
