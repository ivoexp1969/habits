import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';
import 'package:habits/services/cloud/month_listener.dart';

/// ЕТАП 2 A3: live month listeners → merged ProgressMap.
void main() {
  late FakeFirebaseFirestore db;
  late CloudProgressRepository repo;
  late MonthListener listener;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = CloudProgressRepository(db: db, uid: 'u1');
    listener = MonthListener(db: db, uid: 'u1');
  });

  tearDown(() => listener.dispose());

  test('emits a merged map when a watched month changes', () async {
    listener.watch(DateTime(2026, 11, 18));
    final future = listener.stream.firstWhere((m) => m.containsKey('2026-11-16'));
    await repo.add('a', DateTime(2026, 11, 16), 2);
    final map = await future.timeout(const Duration(seconds: 5));
    expect(map['2026-11-16'], {'a': 2});
  });

  test('covers the previous month (rollover / yesterday read)', () async {
    await repo.add('a', DateTime(2026, 10, 31), 1); // previous month
    listener.watch(DateTime(2026, 11, 1));
    final map = await listener.stream
        .firstWhere((m) => m.containsKey('2026-10-31'))
        .timeout(const Duration(seconds: 5));
    expect(map['2026-10-31'], {'a': 1});
  });

  test('re-watching a far month drops the out-of-range one', () async {
    await repo.add('a', DateTime(2026, 11, 16), 1);
    listener.watch(DateTime(2026, 11, 18));
    await listener.stream
        .firstWhere((m) => m.containsKey('2026-11-16'))
        .timeout(const Duration(seconds: 5));
    // Jump far away: November is no longer adjacent → dropped from the view.
    listener.watch(DateTime(2027, 06, 15));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(listener.current.containsKey('2026-11-16'), isFalse);
  });
}
