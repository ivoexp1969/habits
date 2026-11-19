import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/habit_service.dart' show nextLocalMidnight;

/// Pins the in-app midnight-rollover timer target (main.dart arms it; the home
/// screen re-arms it on reload). Kept from the old new_day_reset_test after the
/// data-model-v2 cleanup removed everything else there — nextLocalMidnight is a
/// pure helper, unaffected by the by-date map rewrite.
void main() {
  group('nextLocalMidnight — in-app rollover timer target', () {
    test('is strictly after now and within the next ~24h', () {
      final now = DateTime.now();
      final m = nextLocalMidnight(now);
      expect(m.isAfter(now), isTrue);
      final diff = m.difference(now);
      expect(diff.inHours, lessThanOrEqualTo(24));
      expect(diff.inSeconds, greaterThan(0));
    });

    test('lands at 00:00:05 of the following calendar day', () {
      final base = DateTime(2026, 11, 10, 23, 40);
      final m = nextLocalMidnight(base);
      expect(m, DateTime(2026, 11, 11, 0, 0, 5));
    });

    test('rolls the month correctly at end of month', () {
      final base = DateTime(2026, 11, 30, 10, 0);
      final m = nextLocalMidnight(base);
      expect(m, DateTime(2026, 12, 1, 0, 0, 5));
    });
  });
}
