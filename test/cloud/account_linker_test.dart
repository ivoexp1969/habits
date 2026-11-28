import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fake_auth_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/models/habit.dart';
import 'package:habits/services/cloud/account_linker.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';
import 'package:habits/services/cloud/firestore_schema.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ЕТАП 2 B3: crash-safe merge-on-link (durable copy + resume) + cleanup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;

  AccountLinker linkerAs(String uid, {bool anon = false}) =>
      AccountLinker(db: db, auth: FakeAuthBackend(uid: uid, anonymous: anon));

  setUp(() {
    db = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({});
  });

  test('mergeLocalInto sums, is idempotent per source', () async {
    final repoB = CloudProgressRepository(db: db, uid: 'B');
    await repoB.add('a', DateTime(2026, 11, 16), 1);
    final l = linkerAs('B');
    final map = {
      '2026-11-16': {'a': 2}
    };
    await l.mergeLocalInto('B', 'anon', map);
    await l.mergeLocalInto('B', 'anon', map); // repeat → no double
    expect((await repoB.load())['2026-11-16'], {'a': 3});
    final meta = await db.doc(FirestoreSchema.metaSchemaPath('B')).get();
    expect(meta.data()!['mergedFrom'], ['anon']);
  });

  test('deleteUserData clears months/habits/meta (idempotent)', () async {
    final repo = CloudProgressRepository(db: db, uid: 'anon');
    await repo.add('a', DateTime(2026, 11, 16), 1);
    await db.doc(FirestoreSchema.habitDocPath('anon', 'a')).set({'name': 'x'});
    await db.doc(FirestoreSchema.metaSchemaPath('anon')).set({'version': 2});
    final l = linkerAs('anon', anon: true);
    await l.deleteUserData('anon');
    await l.deleteUserData('anon'); // again → no crash
    expect((await db.collection(FirestoreSchema.monthsPath('anon')).get()).docs, isEmpty);
    expect((await db.collection('users/anon/meta').get()).docs, isEmpty);
  });

  test('guard: empty copy but anon HAS cloud data → abort, deletes nothing', () async {
    final auth = FakeAuthBackend(uid: 'anon', anonymous: true)..existingUid = 'B';
    await CloudProgressRepository(db: db, uid: 'anon')
        .add('a', DateTime(2026, 11, 23), 2);
    final linker = AccountLinker(db: db, auth: auth);
    // A bad read handed an EMPTY copy though the anon has cloud data → must abort.
    final res = await linker.linkOrMerge(
        EmailAuthProvider.credential(email: 'x@y.z', password: 'pw123456'),
        MergeBundle(map: const {}));
    expect(res, LinkResult.error);
    // The anon's data is untouched (NOT deleted).
    expect((await CloudProgressRepository(db: db, uid: 'anon').load())['2026-11-23'],
        {'a': 2});
  });

  test('merge carries habits + paused + achievements into the target (atomic)', () async {
    final auth = FakeAuthBackend(uid: 'anon', anonymous: true)..existingUid = 'B';
    final linker = AccountLinker(db: db, auth: auth);
    final bundle = MergeBundle(
      map: {
        '2026-11-24': {'a': 2}
      },
      habits: [
        Habit(id: 'A', name: 'Вода', timesPerDay: 1, createdAt: DateTime(2026, 1, 1))
      ],
      paused: {'2026-11-20'},
      achievements: {'centurion'},
    );
    final res = await linker.linkOrMerge(
        EmailAuthProvider.credential(email: 'x@y.z', password: 'pw123456'), bundle);
    expect(res, LinkResult.mergedAndSwitched);

    // Everything lands on the target B in the SAME merge (not an async push after).
    final habit = await db.doc(FirestoreSchema.habitDocPath('B', 'A')).get();
    expect(habit.data()!['name'], 'Вода');
    expect((await CloudProgressRepository(db: db, uid: 'B').load())['2026-11-24'],
        {'a': 2});
    final user = await db.doc(FirestoreSchema.userPath('B')).get();
    expect((user.data()!['pausedDates'] as List), contains('2026-11-20'));
    expect((user.data()!['achievements'] as List), contains('centurion'));
  });

  test('resume (after a kill) also restores habits into the target', () async {
    // Pending bundle persisted (step a) with a habit; app killed before d).
    SharedPreferences.setMockInitialValues({
      'pending_merge_v2': jsonEncode({
        'fromUid': 'anon',
        'bundle': {
          'map': {
            '2026-11-24': {'a': 2}
          },
          'habits': [
            Habit(id: 'A', name: 'Вода', timesPerDay: 1, createdAt: DateTime(2026, 1, 1))
                .toJson()
          ],
          'paused': ['2026-11-20'],
          'achievements': ['centurion'],
        }
      })
    });
    final auth = FakeAuthBackend(uid: 'B', anonymous: false); // already switched
    final done = await AccountLinker(db: db, auth: auth).resumePending();
    expect(done, isTrue);
    expect((await db.doc(FirestoreSchema.habitDocPath('B', 'A')).get()).data()!['name'],
        'Вода'); // the habit survived the kill
    expect((await CloudProgressRepository(db: db, uid: 'B').load())['2026-11-24'],
        {'a': 2});
  });

  // ---- crash-resume ---------------------------------------------------------
  void seedPending(Map<String, Map<String, int>> map) {
    SharedPreferences.setMockInitialValues({
      'pending_merge_v2': jsonEncode({
        'fromUid': 'anon',
        'bundle': {'map': map, 'habits': [], 'paused': [], 'achievements': []}
      })
    });
  }

  test('crash AFTER c (signed into target) → resume merges + clears copy', () async {
    seedPending({
      '2026-11-16': {'a': 2}
    });
    final repoB = CloudProgressRepository(db: db, uid: 'B');
    await repoB.add('a', DateTime(2026, 11, 16), 1);

    final done = await linkerAs('B').resumePending();
    expect(done, isTrue);
    expect((await repoB.load())['2026-11-16'], {'a': 3}); // merged from copy
    expect((await SharedPreferences.getInstance()).getString('pending_merge_v2'), isNull);
  });

  test('crash AFTER d (merge already applied) → resume does NOT double', () async {
    seedPending({
      '2026-11-16': {'a': 2}
    });
    final repoB = CloudProgressRepository(db: db, uid: 'B');
    await repoB.add('a', DateTime(2026, 11, 16), 1);
    // d) already ran before the crash: mergedFrom set, counts summed once.
    await linkerAs('B').mergeLocalInto('B', 'anon', {
      '2026-11-16': {'a': 2}
    });
    expect((await repoB.load())['2026-11-16'], {'a': 3});

    final done = await linkerAs('B').resumePending();
    expect(done, isTrue);
    expect((await repoB.load())['2026-11-16'], {'a': 3}); // NOT 5 — idempotent
    expect((await SharedPreferences.getInstance()).getString('pending_merge_v2'), isNull);
  });

  test('crash BEFORE c (still anon) → resume is a no-op, copy kept for retry', () async {
    seedPending({
      '2026-11-16': {'a': 2}
    });
    final done = await linkerAs('anon', anon: true).resumePending();
    expect(done, isFalse);
    // The durable copy survives (no data loss), so a later link completes it.
    expect((await SharedPreferences.getInstance()).getString('pending_merge_v2'),
        isNotNull);
  });
}
