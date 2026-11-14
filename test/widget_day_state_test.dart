import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/widget_service.dart';

/// Pins the widget midnight-rollover freshness logic (mirrored 1:1 in
/// HabitWidget.swift dayState and HabitWidgetProvider.kt dayState):
///   -1 no key → old behaviour; 0 today/future; 1 yesterday; 2 older.
void main() {
  group('WidgetService.widgetDayState', () {
    test('23:59 push → 00:01 next day = yesterday (1)', () {
      expect(
        WidgetService.widgetDayState('2026-11-13', DateTime(2026, 11, 14, 0, 1)),
        1,
      );
    });

    test('same day = fresh (0)', () {
      expect(
        WidgetService.widgetDayState('2026-11-14', DateTime(2026, 11, 14, 23, 59)),
        0,
      );
    });

    test('2 days old = stale, hide streak (2)', () {
      expect(
        WidgetService.widgetDayState('2026-11-12', DateTime(2026, 11, 14, 10, 0)),
        2,
      );
    });

    test('missing key (old install) = old behaviour (-1)', () {
      expect(WidgetService.widgetDayState(null, DateTime(2026, 11, 14, 8, 0)), -1);
      expect(WidgetService.widgetDayState('', DateTime(2026, 11, 14, 8, 0)), -1);
    });

    test('01:30 local is still TODAY (no UTC trap)', () {
      // If this used UTC, 01:30 EET would read as the previous UTC day → 1.
      // Local-only → 0 (fresh).
      expect(
        WidgetService.widgetDayState('2026-11-14', DateTime(2026, 11, 14, 1, 30)),
        0,
      );
    });

    test('future dataDay (clock moved back) = fresh (0), never stale', () {
      expect(
        WidgetService.widgetDayState('2026-11-15', DateTime(2026, 11, 14, 9, 0)),
        0,
      );
    });

    test('month boundary: 01.12 data on 02.12 = yesterday (1)', () {
      expect(
        WidgetService.widgetDayState('2026-11-30', DateTime(2026, 12, 1, 0, 2)),
        1,
      );
    });

    test('year boundary: 31.12 data on 01.01 = yesterday (1)', () {
      expect(
        WidgetService.widgetDayState('2026-12-31', DateTime(2027, 1, 1, 0, 2)),
        1,
      );
    });
  });

  group('WidgetService.widgetCrossedPeriodBoundary', () {
    // Nov 2026: 9=Mon 10=Tue 11=Wed 12=Thu 13=Fri 14=Sat 15=Sun 16=Mon 17=Tue.
    bool crossed(String? d, DateTime now) =>
        WidgetService.widgetCrossedPeriodBoundary(d, now);

    test('Sunday → Monday crosses the ISO week boundary', () {
      expect(crossed('2026-11-15', DateTime(2026, 11, 16, 0, 2)), isTrue);
    });

    test('31 → 1 crosses the month boundary', () {
      expect(crossed('2026-10-31', DateTime(2026, 11, 1, 0, 2)), isTrue);
    });

    test('3-day gap Sat → Tue crosses the Monday', () {
      expect(crossed('2026-11-14', DateTime(2026, 11, 17, 8, 0)), isTrue);
    });

    test('within the same ISO week → NO boundary', () {
      // Tue → Thu, both in the Mon(9)–Sun(15) week.
      expect(crossed('2026-11-10', DateTime(2026, 11, 12, 8, 0)), isFalse);
    });

    test('yesterday within the same week → NO boundary', () {
      expect(crossed('2026-11-11', DateTime(2026, 11, 12, 8, 0)), isFalse);
    });

    test('today / future / missing → NO boundary', () {
      expect(crossed('2026-11-12', DateTime(2026, 11, 12, 23, 59)), isFalse);
      expect(crossed('2026-11-13', DateTime(2026, 11, 12, 8, 0)), isFalse);
      expect(crossed(null, DateTime(2026, 11, 12, 8, 0)), isFalse);
    });
  });
}
