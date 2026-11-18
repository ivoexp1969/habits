import 'package:flutter/foundation.dart';

/// The app's single clock. Everything day-related reads [now] instead of
/// DateTime.now(), so a DEBUG-only offset (set from the hidden diagnostics
/// screen) can move the app to another day WITHOUT touching the device clock —
/// the only way to exercise the midnight rollover on the iOS simulator, which
/// shares the host clock. In release the offset is forced to zero, so
/// [now] == DateTime.now(). The offset is in-memory only (not persisted).
class AppClock {
  AppClock._();

  /// Whether the debug offset is honoured. Defaults to [kDebugMode] (false in
  /// release → the offset is ignored), exposed so a test can assert the
  /// release behaviour without actually building in release mode.
  @visibleForTesting
  static bool debugEnabled = kDebugMode;

  static Duration _offset = Duration.zero;

  /// The active offset — always zero when [debugEnabled] is false (release).
  static Duration get offset => debugEnabled ? _offset : Duration.zero;

  static DateTime now() => DateTime.now().add(offset);

  static void addDays(int n) {
    if (debugEnabled) _offset += Duration(days: n);
  }

  /// Jumps the app clock to 23:59 of the current (offset) day, so the next
  /// midnight is ~1 min of REAL time away — lets the in-app midnight timer fire.
  static void toEndOfToday() {
    if (!debugEnabled) return;
    final n = now();
    final target = DateTime(n.year, n.month, n.day, 23, 59, 30);
    _offset += target.difference(n);
  }

  static void reset() => _offset = Duration.zero;
}
