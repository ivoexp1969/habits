import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'habit_service.dart' show dateKeyFromDate;
import 'progress_service.dart' show ProgressMap;

/// Storage for the by-date progress map (data-model-v2):
///   { "yyyy-MM-dd": { habitId: count } }
/// Reads AND writes go only through here — there is no per-habit counter and no
/// reset. ЕТАП 1 is this local SharedPreferences implementation; ЕТАП 2 swaps in
/// a Firestore-backed one behind the same [ProgressRepository] interface.
abstract class ProgressRepository {
  /// The whole map (cached after the first read).
  Future<ProgressMap> load();

  /// Check-ins for [habitId] on the local day [date] (0 if none).
  Future<int> countOn(String habitId, DateTime date);

  /// Sets the absolute count for [habitId] on [date]. 0 or less removes the
  /// entry (and the day, when it becomes empty) so the map stays compact.
  Future<void> setCount(String habitId, DateTime date, int count);

  /// Adds [delta] (a check-in = +1, an undo = -1), clamped at 0.
  Future<void> add(String habitId, DateTime date, int delta);
}

class LocalProgressRepository implements ProgressRepository {
  LocalProgressRepository._();
  static final LocalProgressRepository instance = LocalProgressRepository._();

  static const String kPrefsProgress = 'progress_map_v2';

  ProgressMap? _cache;

  /// Clears the in-memory cache so the next [load] re-reads prefs — used after a
  /// migration or a backup import rewrites the stored map, and by tests.
  void resetCache() => _cache = null;

  @override
  Future<ProgressMap> load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    _cache = decode(prefs.getString(kPrefsProgress));
    return _cache!;
  }

  /// Parses the stored JSON into a typed map, dropping 0 / malformed entries.
  /// Pure (no I/O) so migration + tests can use it directly.
  @visibleForTesting
  static ProgressMap decode(String? s) {
    if (s == null || s.isEmpty) return <String, Map<String, int>>{};
    try {
      final raw = jsonDecode(s) as Map<String, dynamic>;
      final out = <String, Map<String, int>>{};
      raw.forEach((day, v) {
        if (v is! Map) return;
        final inner = <String, int>{};
        Map<String, dynamic>.from(v).forEach((id, c) {
          final n = c is num ? c.toInt() : 0;
          if (n != 0) inner[id] = n;
        });
        if (inner.isNotEmpty) out[day] = inner;
      });
      return out;
    } catch (_) {
      return <String, Map<String, int>>{};
    }
  }

  static String encode(ProgressMap map) => jsonEncode(map);

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsProgress, encode(_cache ?? const {}));
  }

  @override
  Future<int> countOn(String habitId, DateTime date) async {
    final m = await load();
    return m[dateKeyFromDate(date)]?[habitId] ?? 0;
  }

  @override
  Future<void> setCount(String habitId, DateTime date, int count) async {
    final m = await load();
    final k = dateKeyFromDate(date);
    final day = m.putIfAbsent(k, () => <String, int>{});
    if (count <= 0) {
      day.remove(habitId);
    } else {
      day[habitId] = count;
    }
    if (day.isEmpty) m.remove(k);
    await _persist();
  }

  @override
  Future<void> add(String habitId, DateTime date, int delta) async {
    final next = await countOn(habitId, date) + delta;
    await setCount(habitId, date, next < 0 ? 0 : next);
  }

  /// Replaces the whole map (used by the one-time migration in ЕТАП 1 step 5).
  Future<void> replaceAll(ProgressMap map) async {
    _cache = map;
    await _persist();
  }
}
