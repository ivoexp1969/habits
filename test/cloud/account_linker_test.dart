import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'fake_auth_backend.dart';
import 'package:flutter_test/flutter_test.dart';
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

  // ---- crash-resume ---------------------------------------------------------
  void seedPending(Map<String, Map<String, int>> map) {
    SharedPreferences.setMockInitialValues({
      'pending_merge_v2': jsonEncode({'fromUid': 'anon', 'map': map})
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
