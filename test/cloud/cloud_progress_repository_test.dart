import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';
import 'package:habits/services/cloud/firestore_schema.dart';

/// ЕТАП 2 A2: CloudProgressRepository over a fake Firestore.
void main() {
  late FakeFirebaseFirestore db;
  late CloudProgressRepository repo;
  final nov16 = DateTime(2026, 11, 16);
  final nov17 = DateTime(2026, 11, 17);
  final dec01 = DateTime(2026, 12, 1);

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = CloudProgressRepository(db: db, uid: 'u1');
  });

  test('add increments and countOn reads it back (same day accumulates)', () async {
    await repo.add('a', nov16, 1);
    await repo.add('a', nov16, 1);
    expect(await repo.countOn('a', nov16), 2);
    // stored under the month doc as { "16": { "a": 2 } }
    final doc = await db.doc(FirestoreSchema.monthDocPath('u1', '2026-11')).get();
    expect((doc.data()!['16'] as Map)['a'], 2);
  });

  test('undo (add -1) brings it back down', () async {
    await repo.add('a', nov16, 1);
    await repo.add('a', nov16, -1);
    expect(await repo.countOn('a', nov16), 0);
  });

  test('setCount writes an absolute value; <=0 removes the field', () async {
    await repo.setCount('a', nov16, 5);
    expect(await repo.countOn('a', nov16), 5);
    await repo.setCount('a', nov16, 0);
    expect(await repo.countOn('a', nov16), 0);
    final doc = await db.doc(FirestoreSchema.monthDocPath('u1', '2026-11')).get();
    final day = (doc.data()?['16'] as Map?) ?? const {};
    expect(day.containsKey('a'), isFalse); // field deleted
  });

  test('load merges all month docs into one yyyy-MM-dd map', () async {
    await repo.add('a', nov16, 2);
    await repo.add('b', nov17, 1);
    await repo.add('a', dec01, 3); // next month → separate doc
    final map = await repo.load();
    expect(map['2026-11-16'], {'a': 2});
    expect(map['2026-11-17'], {'b': 1});
    expect(map['2026-12-01'], {'a': 3});
  });

  test('days live in the correct per-month document', () async {
    await repo.add('a', nov16, 1);
    await repo.add('a', dec01, 1);
    final nov = await db.doc(FirestoreSchema.monthDocPath('u1', '2026-11')).get();
    final dec = await db.doc(FirestoreSchema.monthDocPath('u1', '2026-12')).get();
    expect((nov.data()!['16'] as Map)['a'], 1);
    expect((dec.data()!['01'] as Map)['a'], 1);
    expect(nov.data()!.containsKey('01'), isFalse);
  });
}
