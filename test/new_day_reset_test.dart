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

  group('robust habit-level reset (no device-date guard)', () {
    final dYesterday = dateKeyFromDate(DateTime(2026, 11, 10));
    final dToday = dateKeyFromDate(DateTime(2026, 11, 11));
    final nowToday = DateTime(2026, 11, 11, 0, 2);

    test('23:55 check-in blob applied on a new day → completedTimes 0, '
        'even when last_active_date already reads today', () async {
      // Remote blob: habit checked at 23:55 yesterday.
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      await HabitService.saveHabits([
        Habit(name: 'Сън 8 часа', timesPerDay: 1, completedTimes: 1, periodKey: dYesterday),
      ]);
      await prefs.setString(kPrefsLastActiveDate, dYesterday);
      final blob = BackupService.validate(await BackupService.exportJson()).data!;

      // Local: the morning reset already ran (habit cleared, date = today).
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      await HabitService.saveHabits([
        Habit(name: 'Сън 8 часа', timesPerDay: 1, completedTimes: 0, periodKey: dToday),
      ]);
      await prefs.setString(kPrefsLastActiveDate, dToday);

      // Cloud download restores yesterday's checked habit...
      await BackupService.apply(blob);
      // ...and the device date is forced to today — the OLD guard would skip.
      await prefs.setString(kPrefsLastActiveDate, dToday);

      await maybeResetForNewDay(nowToday);

      final h = (await HabitService.loadHabits()).single;
      expect(h.completedTimes, 0,
          reason: 'per-habit reset fires regardless of last_active_date');
      expect(h.isCompletedAt(nowToday), isFalse);
    });

    test('5 consecutive new-day resets are idempotent (streak + XP intact)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kPrefsLastActiveDate, dYesterday);
      await prefs.setInt('xp', 150);
      await HabitService.saveHabits([
        Habit(
            name: 'Сън 8 часа',
            timesPerDay: 1,
            completedTimes: 1,
            periodKey: dYesterday,
            streak: 7,
            bestStreak: 9,
            lastCompletedDate: dYesterday),
      ]);

      for (var i = 0; i < 5; i++) {
        await maybeResetForNewDay(nowToday);
      }

      final h = (await HabitService.loadHabits()).single;
      expect(h.completedTimes, 0);
      expect(h.periodKey, dToday);
      expect(h.streak, 7, reason: 'streak untouched by the reset');
      expect(h.bestStreak, 9);
      expect(h.lastCompletedDate, dYesterday);
      expect(prefs.getInt('xp'), 150, reason: 'XP untouched by the reset');
    });
  });

  group('period-aware isCompleted / progress (safety net)', () {
    test('a stale periodKey never shows as complete', () {
      final now = DateTime(2026, 11, 11, 9, 0);
      final stale = Habit(
          name: 'X', timesPerDay: 1, completedTimes: 1, periodKey: '2000-01-01');
      expect(stale.isCompletedAt(now), isFalse);
      expect(stale.progressAt(now), 0);
      final fresh = Habit(
          name: 'Y',
          timesPerDay: 1,
          completedTimes: 1,
          periodKey: dateKeyFromDate(now));
      expect(fresh.isCompletedAt(now), isTrue);
      expect(fresh.progressAt(now), 1.0);
    });

    test('a weekly habit stays complete across a day within its week', () {
      final mon = DateTime(2026, 11, 9);
      final tue = DateTime(2026, 11, 10, 9, 0);
      final h = Habit(
          name: 'W',
          timesPerDay: 2,
          frequencyUnit: 'week',
          completedTimes: 2,
          periodKey: periodKeyFor('week', mon));
      expect(h.isCompletedAt(tue), isTrue);
    });
  });

  group('future periodKey realign + park (clock / timezone moved back)', () {
    test('FUTURE periodKey → realigned to today, counter kept, future parked', () {
      // Replaces the old "left intact" behaviour: today is the single source of
      // truth, so a future periodKey is snapped to today (keeping the counter)
      // and the future period is parked for a later roll-forward.
      final now = DateTime(2026, 11, 12, 9, 0);
      final h = [
        Habit(
            name: 'X',
            timesPerDay: 1,
            completedTimes: 1,
            periodKey: dateKeyFromDate(DateTime(2026, 11, 13))),
      ];
      expect(resetHabitsForPeriod(h, now), isTrue);
      expect(h.single.completedTimes, 1, reason: 'going back must not wipe');
      expect(h.single.periodKey, '2026-11-12', reason: 'single source = today');
      expect(h.single.parkedPeriodKey, '2026-11-13', reason: 'future parked');
    });

    test('a PAST periodKey still resets (and clears any park)', () {
      final now = DateTime(2026, 11, 12, 9, 0);
      final h = [
        Habit(
            name: 'X',
            timesPerDay: 1,
            completedTimes: 1,
            periodKey: dateKeyFromDate(DateTime(2026, 11, 11))),
      ];
      expect(resetHabitsForPeriod(h, now), isTrue);
      expect(h.single.completedTimes, 0);
      expect(h.single.periodKey, '2026-11-12');
      expect(h.single.parkedPeriodKey, isNull);
    });

    test('roll forward EXACTLY back to the parked period → counter kept, park cleared', () {
      final h = [
        Habit(name: 'X', timesPerDay: 8, completedTimes: 3, periodKey: '2026-11-15'),
      ];
      resetHabitsForPeriod(h, DateTime(2026, 11, 14, 10)); // back to 14: park 15
      expect(h.single.periodKey, '2026-11-14');
      expect(h.single.parkedPeriodKey, '2026-11-15');
      expect(h.single.completedTimes, 3);
      resetHabitsForPeriod(h, DateTime(2026, 11, 15, 10)); // forward to parked 15
      expect(h.single.periodKey, '2026-11-15');
      expect(h.single.parkedPeriodKey, isNull);
      expect(h.single.completedTimes, 3, reason: 'return to parked → no reset');
    });

    test('forward roll PAST the parked period → normal reset, park cleared', () {
      final h = [
        Habit(name: 'X', timesPerDay: 8, completedTimes: 3,
            periodKey: '2026-11-14', parkedPeriodKey: '2026-11-15'),
      ];
      resetHabitsForPeriod(h, DateTime(2026, 11, 16, 10)); // 16 != parked 15
      expect(h.single.completedTimes, 0);
      expect(h.single.periodKey, '2026-11-16');
      expect(h.single.parkedPeriodKey, isNull);
    });

    test('park survives a JSON round-trip (Hive / backup / sync payload)', () {
      final h = Habit(name: 'X', timesPerDay: 8, completedTimes: 3,
          periodKey: '2026-11-14', parkedPeriodKey: '2026-11-15');
      final back = Habit.fromJson(h.toJson());
      expect(back.parkedPeriodKey, '2026-11-15');
      // Old backup lacking the field → null, no crash.
      final old = Map<String, dynamic>.from(h.toJson())..remove('parkedPeriodKey');
      expect(Habit.fromJson(old).parkedPeriodKey, isNull);
    });
  });

  group('clock-change scenarios (single source = real today)', () {
    String dk(int day) => dateKeyFromDate(DateTime(2026, 11, day));

    test('14→15→14 then mark 5 habits → progressAt>0 & isCompletedAt=true (circles fill)', () {
      final hs = List.generate(5, (i) => Habit(
          name: 'H$i', timesPerDay: 1, completedTimes: 0, periodKey: dk(14)));
      resetHabitsForPeriod(hs, DateTime(2026, 11, 15, 9)); // → 15 (forward reset)
      resetHabitsForPeriod(hs, DateTime(2026, 11, 14, 9)); // back → realign + park 15
      for (final h in hs) {
        h.completedTimes = 1; // mark each (as _incrementHabit does: counter only)
      }
      final today = DateTime(2026, 11, 14, 12);
      for (final h in hs) {
        expect(h.isCompletedAt(today), isTrue, reason: 'circle filled on real today');
        expect(h.progressAt(today), greaterThan(0.0));
        expect(h.periodKey, '2026-11-14');
      }
    });

    test('Scenario B: real 15 (mark 5) → wrong 14 → back 15 keeps 5', () {
      final h = [Habit(name: 'Вода', timesPerDay: 8, completedTimes: 5, periodKey: dk(15))];
      resetHabitsForPeriod(h, DateTime(2026, 11, 14, 10)); // → 14: park 15, keep 5
      expect(h.single.completedTimes, 5);
      expect(h.single.parkedPeriodKey, '2026-11-15');
      resetHabitsForPeriod(h, DateTime(2026, 11, 15, 10)); // → 15 == parked: keep 5
      expect(h.single.completedTimes, 5);
      expect(h.single.periodKey, '2026-11-15');
      expect(h.single.parkedPeriodKey, isNull);
    });

    test('West travel: 15 (mark 2) → 14 (+1) → back 15 = 3', () {
      final h = [Habit(name: 'Вода', timesPerDay: 8, completedTimes: 2, periodKey: dk(15))];
      resetHabitsForPeriod(h, DateTime(2026, 11, 14, 23)); // → 14: park 15, keep 2
      expect(h.single.completedTimes, 2);
      h.single.completedTimes += 1; // +1 while the clock reads the 14th → 3
      resetHabitsForPeriod(h, DateTime(2026, 11, 15, 1)); // → 15 == parked: NO reset
      expect(h.single.completedTimes, 3);
      expect(h.single.periodKey, '2026-11-15');
      expect(h.single.parkedPeriodKey, isNull);
    });

    test('weekly habit: clock back across the ISO week boundary parks & keeps', () {
      final wk16 = periodKeyFor('week', DateTime(2026, 11, 16)); // Mon → W47
      final wk15 = periodKeyFor('week', DateTime(2026, 11, 15)); // Sun → W46
      expect(wk16 == wk15, isFalse);
      final h = [Habit(name: 'Спорт', timesPerDay: 3, frequencyUnit: 'week',
          completedTimes: 2, periodKey: wk16)];
      resetHabitsForPeriod(h, DateTime(2026, 11, 15, 10)); // back into W46: park W47
      expect(h.single.periodKey, wk15);
      expect(h.single.parkedPeriodKey, wk16);
      expect(h.single.completedTimes, 2);
      resetHabitsForPeriod(h, DateTime(2026, 11, 16, 10)); // forward to parked W47
      expect(h.single.completedTimes, 2);
      expect(h.single.periodKey, wk16);
      expect(h.single.parkedPeriodKey, isNull);
    });

    test('double step-back: 15 (mark 3) → 14 → 13 → 14 → 15 = 3, no reset', () {
      final h = [Habit(name: 'Вода', timesPerDay: 8, completedTimes: 3, periodKey: dk(15))];
      resetHabitsForPeriod(h, DateTime(2026, 11, 14, 10)); // → 14: park 15
      expect(h.single.parkedPeriodKey, '2026-11-15');
      resetHabitsForPeriod(h, DateTime(2026, 11, 13, 10)); // → 13: park = max(15,14) = 15
      expect(h.single.parkedPeriodKey, '2026-11-15', reason: 'farther future kept');
      expect(h.single.completedTimes, 3);
      resetHabitsForPeriod(h, DateTime(2026, 11, 14, 10)); // → 14 (< park 15): no reset
      expect(h.single.completedTimes, 3);
      expect(h.single.parkedPeriodKey, '2026-11-15', reason: 'still below park');
      resetHabitsForPeriod(h, DateTime(2026, 11, 15, 10)); // → 15 == park: keep, unpark
      expect(h.single.completedTimes, 3);
      expect(h.single.periodKey, '2026-11-15');
      expect(h.single.parkedPeriodKey, isNull);
    });

    test('counter, circle fill, widget now & zero all read one "today"', () {
      final now = DateTime(2026, 11, 14, 12);
      final daily = Habit(name: 'Вода', timesPerDay: 8, completedTimes: 5,
          periodKey: periodKeyFor('day', now));
      expect(daily.completedTimes, 5); // raw counter
      expect(daily.progressAt(now), closeTo(5 / 8, 1e-9)); // circle fill (now)
      expect(completedTimesAt(daily, now), 5); // widget "now" (today)
      expect(completedTimesAt(daily, nextLocalMidnight(now)), 0); // widget "zero" (tomorrow)
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
