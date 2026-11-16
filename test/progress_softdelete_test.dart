import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/progress_service.dart';

/// data-model-v2 ЕТАП 1 step 5b-iii-c: soft delete. The home_screen UI methods
/// are not unit-testable directly, so these pin the underlying rule — every
/// "live habits" path goes through ProgressService.activeHabits — for each
/// side effect the audit called out. (A habit count limit does NOT exist in the
/// app, so that sub-case is not applicable.)
void main() {
  final now = DateTime(2026, 11, 16);
  Habit mk(String id,
          {int times = 1, String? after, DateTime? deleted, String? name}) =>
      Habit(
          id: id,
          name: name ?? id,
          timesPerDay: times,
          afterHabitId: after,
          createdAt: DateTime(2026, 1, 1),
          deletedAt: deleted);

  test('a soft-deleted incomplete habit does NOT block a perfect day', () {
    final a = mk('a');
    final b = mk('b', deleted: DateTime(2026, 11, 10)); // incomplete + deleted
    final map = {
      '2026-11-16': {'a': 1}
    };
    final perfect = ProgressService.activeHabits([a, b], now)
        .every((h) => ProgressService.isCompleted(map, h, now));
    expect(perfect, isTrue); // b excluded; a complete
  });

  test('a soft-deleted anchor breaks the stacking link', () {
    final anchor = mk('anchor', deleted: DateTime(2026, 11, 10));
    final dep = mk('dep', after: 'anchor');
    final active = ProgressService.activeHabits([anchor, dep], now);
    // _anchorNameFor: look the anchor up among ACTIVE habits only.
    final linked = active.where((h) => h.id == dep.afterHabitId);
    expect(linked.isEmpty, isTrue); // anchor gone → shown without the link
  });

  test('a soft-deleted template habit is re-addable (name not "already added")', () {
    final deletedWater =
        mk('w', times: 8, name: 'Пия вода', deleted: DateTime(2026, 11, 10));
    final activeNames = ProgressService.activeHabits([deletedWater], now)
        .map((h) => h.name.trim().toLowerCase())
        .toSet();
    expect(activeNames.contains('пия вода'), isFalse);
  });

  test('day percentage past date uses the habits active THAT day', () {
    // A habit created after a past date, or deleted before it, must not count.
    final old = mk('old'); // live since Jan
    final later = mk('later')..createdAt = DateTime(2026, 11, 20);
    final map = {
      '2026-11-16': {'old': 1}
    };
    // On 16.11 only 'old' is active → 100%, 'later' (created 20.11) excluded.
    expect(ProgressService.dayPercent(map, [old, later], DateTime(2026, 11, 16)),
        100.0);
  });
}
