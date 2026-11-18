import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/app_clock.dart';
import 'package:habits/services/progress_service.dart';
import 'package:habits/services/xp_service.dart';

/// Tests for the behaviours added across 5b-iii-d … clock-offset (which shipped
/// without tests). Clock injected via AppClock / explicit dates.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppClock debug offset', () {
    tearDown(() {
      AppClock.reset();
      AppClock.debugEnabled = kDebugMode;
    });

    test('offset applies in debug, is IGNORED in release (kReleaseMode)', () {
      AppClock.debugEnabled = true;
      AppClock.reset();
      AppClock.addDays(3);
      expect(AppClock.offset, const Duration(days: 3));
      // Release: the offset is dropped even though it was set.
      AppClock.debugEnabled = false;
      expect(AppClock.offset, Duration.zero);
      expect(AppClock.now().difference(DateTime.now()).inSeconds.abs() < 2, isTrue);
    });

    test('toEndOfToday lands on 23:59 of the current offset day', () {
      AppClock.debugEnabled = true;
      AppClock.reset();
      AppClock.toEndOfToday();
      final n = AppClock.now();
      expect(n.hour, 23);
      expect(n.minute, 59);
    });
  });

  group('XpService perfect-day bonus (once/day, follows AppClock)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppClock.debugEnabled = true;
      AppClock.reset();
    });
    tearDown(() {
      AppClock.reset();
      AppClock.debugEnabled = kDebugMode;
    });

    test('counts once per day; a new (offset) day counts again', () async {
      expect((await XpService.onPerfectDay()).$3, isTrue); // first today → given
      expect((await XpService.onPerfectDay()).$3, isFalse); // same day → not again
      AppClock.addDays(1);
      expect((await XpService.onPerfectDay()).$3, isTrue); // new day → given again
    });
  });

  group('new day / resume — data behaviour (no reset)', () {
    Habit daily(String id, {int t = 1}) => Habit(
        id: id,
        name: id,
        timesPerDay: t,
        frequencyUnit: 'day',
        createdAt: DateTime(2026, 1, 1));

    test('crossing 23:59→00:00: the new day reads 0, yesterday is preserved', () {
      final map = {
        '2026-11-17': {'a': 8}
      };
      final h = daily('a', t: 8);
      // "today" 17 → complete.
      expect(ProgressService.periodCount(map, h, DateTime(2026, 11, 17)), 8);
      expect(ProgressService.isCompleted(map, h, DateTime(2026, 11, 17)), isTrue);
      // next day (18) → 0, nothing reset, 17 still there.
      expect(ProgressService.periodCount(map, h, DateTime(2026, 11, 18)), 0);
      expect(ProgressService.isCompleted(map, h, DateTime(2026, 11, 18)), isFalse);
      // resume back to 17 → still 8 (data durable, no wipe).
      expect(ProgressService.periodCount(map, h, DateTime(2026, 11, 17)), 8);
    });
  });
}
