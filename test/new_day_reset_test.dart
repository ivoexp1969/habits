import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habits/main.dart' show maybeResetForNewDay;
import 'package:habits/models/habit.dart';
import 'package:habits/services/backup_service.dart';
import 'package:habits/services/habit_service.dart';

/// Covers the "new day" daily-reset path behind the two iOS bugs:
///   (1) widget showing yesterday, and
///   (2) "Сън 8 часа" shown full without being tapped today.
/// The reset keys off each habit's periodKey vs today, guarded by the global
/// last_active_date — these tests pin that behaviour, plus the midnight-timer
/// target used by the in-app rollover safety net.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String dayKey(int daysAgo) {
    final n = DateTime.now();
    return dateKeyFromDate(
        DateTime(n.year, n.month, n.day).subtract(Duration(days: daysAgo)));
  }

  Future<SharedPreferences> seed({
    required int lastActiveDaysAgo,
    required Habit habit,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsLastActiveDate, dayKey(lastActiveDaysAgo));
    await HabitService.saveHabits([habit]);
    return prefs;
  }

  group('maybeResetForNewDay — daily habit (Сън 8 часа)', () {
    test('new day → counter zeroed, periodKey + last_active_date advanced', () async {
      final prefs = await seed(
        lastActiveDaysAgo: 1,
        habit: Habit(
            name: 'Сън 8 часа',
            timesPerDay: 1,
            completedTimes: 1,
            periodKey: dayKey(1)), // completed yesterday
      );

      final didReset = await maybeResetForNewDay();

      expect(didReset, isTrue);
      final after = (await HabitService.loadHabits()).single;
      expect(after.completedTimes, 0, reason: 'yesterday\'s check-in cleared');
      expect(after.isCompleted, isFalse);
      expect(after.periodKey, dayKey(0));
      expect(prefs.getString(kPrefsLastActiveDate), dayKey(0));
    });

    test('same day → no reset, the check-in is preserved', () async {
      final prefs = await seed(
        lastActiveDaysAgo: 0,
        habit: Habit(
            name: 'Сън 8 часа',
            timesPerDay: 1,
            completedTimes: 1,
            periodKey: dayKey(0)),
      );

      final didReset = await maybeResetForNewDay();

      expect(didReset, isFalse);
      final after = (await HabitService.loadHabits()).single;
      expect(after.completedTimes, 1, reason: 'same-day progress untouched');
      expect(prefs.getString(kPrefsLastActiveDate), dayKey(0));
    });

    test('periodKey == null (fresh from a pack) is treated as reset-due', () async {
      await seed(
        lastActiveDaysAgo: 1,
        habit: Habit(
            name: 'Сън 8 часа',
            timesPerDay: 1,
            completedTimes: 1,
            periodKey: null),
      );

      final didReset = await maybeResetForNewDay();

      expect(didReset, isTrue);
      final after = (await HabitService.loadHabits()).single;
      expect(after.completedTimes, 0);
      expect(after.periodKey, dayKey(0));
    });
  });

  group('maybeResetForNewDay — period awareness', () {
    test('a weekly habit is NOT wiped by a mere day rollover in its week', () async {
      await seed(
        lastActiveDaysAgo: 1,
        habit: Habit(
            name: 'Седмичен',
            timesPerDay: 1,
            frequencyUnit: 'week',
            completedTimes: 1,
            periodKey: periodKeyFor('week', DateTime.now())),
      );

      final didReset = await maybeResetForNewDay();

      // The day rolled (last_active_date was yesterday) so the function reports
      // a reset ran, but the weekly counter stays because its period is current.
      expect(didReset, isTrue);
      final after = (await HabitService.loadHabits()).single;
      expect(after.completedTimes, 1,
          reason: 'weekly counter survives a new day within the same week');
    });
  });

  group('injected clock — app alive across midnight (scenario a)', () {
    // The real bug: the day turns while the app is foregrounded (common for the
    // bedtime "Сън" check-in). The new midnight timer fires maybeResetForNewDay
    // with "now" = just after 00:00; here we inject that clock so the crossing
    // is deterministic without touching the system time.
    test('crossing into tomorrow zeroes a habit completed today', () async {
      final n = DateTime.now();
      final today = DateTime(n.year, n.month, n.day);
      final justAfterMidnight = today.add(const Duration(days: 1, seconds: 10));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // State as left by an active session TODAY: Сън checked, day = today.
      await prefs.setString(kPrefsLastActiveDate, dateKeyFromDate(today));
      await HabitService.saveHabits([
        Habit(
            name: 'Сън 8 часа',
            timesPerDay: 1,
            completedTimes: 1,
            periodKey: dateKeyFromDate(today)),
      ]);

      final didReset = await maybeResetForNewDay(justAfterMidnight);

      expect(didReset, isTrue);
      final after = (await HabitService.loadHabits()).single;
      expect(after.completedTimes, 0, reason: 'cleared when the clock crosses 00:00');
      expect(after.periodKey, dateKeyFromDate(justAfterMidnight));
      expect(prefs.getString(kPrefsLastActiveDate),
          dateKeyFromDate(justAfterMidnight));
    });

    test('late-evening tick on the SAME day does not reset', () async {
      final n = DateTime.now();
      final today = DateTime(n.year, n.month, n.day);
      final late = today.add(const Duration(hours: 23, minutes: 59));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kPrefsLastActiveDate, dateKeyFromDate(today));
      await HabitService.saveHabits([
        Habit(
            name: 'Сън 8 часа',
            timesPerDay: 1,
            completedTimes: 1,
            periodKey: dateKeyFromDate(today)),
      ]);

      final didReset = await maybeResetForNewDay(late);

      expect(didReset, isFalse);
      expect((await HabitService.loadHabits()).single.completedTimes, 1);
    });
  });

  group('completedTimesAt — period-aware widget zeroing at midnight', () {
    // The widget's "new day" state must zero ONLY daily habits; weekly/monthly
    // (and period-goal) habits keep their progress until their own period rolls.
    test('daily habit drops to 0 at the next day', () {
      final mon = DateTime(2026, 11, 9); // a Monday
      final h = Habit(
          name: 'Сън 8 часа',
          timesPerDay: 1,
          completedTimes: 1,
          periodKey: periodKeyFor('day', mon));
      // Same day → kept; next day → zeroed.
      expect(completedTimesAt(h, mon), 1);
      expect(completedTimesAt(h, mon.add(const Duration(days: 1))), 0);
    });

    test('weekly habit keeps its count across a day in the same ISO week', () {
      final mon = DateTime(2026, 11, 9); // Monday
      final tue = DateTime(2026, 11, 10); // same ISO week
      final nextMon = DateTime(2026, 11, 16); // next ISO week
      final h = Habit(
          name: 'Седмичен',
          timesPerDay: 3,
          frequencyUnit: 'week',
          completedTimes: 3,
          periodKey: periodKeyFor('week', mon));
      expect(completedTimesAt(h, tue), 3, reason: 'kept within the week');
      expect(completedTimesAt(h, nextMon), 0, reason: 'zeroed on a new week');
    });

    test('monthly habit keeps its count within the month, zeroes next month', () {
      final mid = DateTime(2026, 11, 15);
      final later = DateTime(2026, 11, 16);
      final nextMonth = DateTime(2026, 12, 1);
      final h = Habit(
          name: 'Месечен',
          timesPerDay: 2,
          frequencyUnit: 'month',
          completedTimes: 2,
          periodKey: periodKeyFor('month', mid));
      expect(completedTimesAt(h, later), 2);
      expect(completedTimesAt(h, nextMonth), 0);
    });
  });

  group('cloud download + daily reset (_onCloudSynced fix)', () {
    // Fixed clock so week/day period keys are deterministic. Nov 10 (Tue) and
    // Nov 11 (Wed) share an ISO week (Mon Nov 9 – Sun Nov 15).
    final yesterday = DateTime(2026, 11, 10);
    final today = DateTime(2026, 11, 11);
    final nowToday = DateTime(2026, 11, 11, 8, 0);
    final dYesterday = dateKeyFromDate(yesterday);
    final dToday = dateKeyFromDate(today);
    final weekKey = periodKeyFor('week', yesterday);

    // Builds a remote cloud blob (what another device uploaded) via the real
    // export/validate round-trip, then clears prefs ready for the local state.
    Future<Map<String, dynamic>> remoteBlob(
        List<Habit> habits, String lastActive) async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      await HabitService.saveHabits(habits);
      await p.setString(kPrefsLastActiveDate, lastActive);
      final json = await BackupService.exportJson();
      return BackupService.validate(json).data!;
    }

    Future<SharedPreferences> setLocal(
        List<Habit> habits, String lastActive) async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      await HabitService.saveHabits(habits);
      await p.setString(kPrefsLastActiveDate, lastActive);
      return p;
    }

    Habit byName(List<Habit> hs, String n) => hs.firstWhere((h) => h.name == n);

    test('(a) YESTERDAY blob → daily zeroed, weekly kept', () async {
      // Remote: yesterday's completed daily + weekly (still this week).
      final blob = await remoteBlob([
        Habit(name: 'Сън 8 часа', timesPerDay: 1, completedTimes: 1, periodKey: dYesterday),
        Habit(name: 'Спорт 3x', timesPerDay: 3, frequencyUnit: 'week', completedTimes: 3, periodKey: weekKey),
      ], dYesterday);
      await setLocal([], dToday); // local already reset today
      // Simulate the download + the _onCloudSynced fix:
      await BackupService.apply(blob);
      final didReset = await maybeResetForNewDay(nowToday);

      expect(didReset, isTrue);
      final hs = await HabitService.loadHabits();
      expect(byName(hs, 'Сън 8 часа').completedTimes, 0, reason: 'daily zeroed');
      expect(byName(hs, 'Спорт 3x').completedTimes, 3, reason: 'weekly kept');
    });

    test('(b) blob from ANOTHER device with TODAY check-ins → kept, no reset', () async {
      final blob = await remoteBlob([
        Habit(name: 'Сън 8 часа', timesPerDay: 1, completedTimes: 1, periodKey: dToday),
        Habit(name: 'Вода', timesPerDay: 8, completedTimes: 5, periodKey: dToday),
      ], dToday);
      await setLocal([
        Habit(name: 'Сън 8 часа', timesPerDay: 1, completedTimes: 0, periodKey: dToday),
        Habit(name: 'Вода', timesPerDay: 8, completedTimes: 0, periodKey: dToday),
      ], dToday);
      await BackupService.apply(blob);
      final didReset = await maybeResetForNewDay(nowToday);

      expect(didReset, isFalse, reason: 'same day → no reset');
      final hs = await HabitService.loadHabits();
      expect(byName(hs, 'Сън 8 часа').completedTimes, 1, reason: "today's remote check-in kept");
      expect(byName(hs, 'Вода').completedTimes, 5);
    });

    test('(c) local TODAY check-in, then download of a blob lacking it', () async {
      // Local has today's check-in; the remote blob (another device, today) does
      // NOT have it. This documents the CURRENT behaviour of the whole-document
      // sync — see the report. Not the daily-reset bug; not fixed here.
      final blob = await remoteBlob([
        Habit(name: 'Сън 8 часа', timesPerDay: 1, completedTimes: 0, periodKey: dToday),
      ], dToday);
      await setLocal([
        Habit(name: 'Сън 8 часа', timesPerDay: 1, completedTimes: 1, periodKey: dToday),
      ], dToday);
      await BackupService.apply(blob);
      final didReset = await maybeResetForNewDay(nowToday);

      expect(didReset, isFalse);
      final hs = await HabitService.loadHabits();
      // ⚠️ LOST: BackupService.apply replaces the whole `habits` string with no
      // per-habit merge, so a concurrent remote write without today's check-in
      // overwrites it. maybeResetForNewDay cannot restore it. Reported, not fixed.
      expect(byName(hs, 'Сън 8 часа').completedTimes, 0);
    });
  });

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
