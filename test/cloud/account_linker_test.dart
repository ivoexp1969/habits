import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/cloud/account_linker.dart';
import 'package:habits/services/cloud/cloud_identity.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';
import 'package:habits/services/cloud/firestore_schema.dart';

/// ЕТАП 2 B3: idempotent merge-on-link + anonymous-data cleanup.
void main() {
  late FakeFirebaseFirestore db;
  AccountLinker linker() => AccountLinker(
      db: db, identity: CloudIdentity(MockFirebaseAuth(signedIn: true)));

  setUp(() => db = FakeFirebaseFirestore());

  test('mergeLocalInto adds local counts onto the target account', () async {
    final repoB = CloudProgressRepository(db: db, uid: 'B');
    await repoB.add('a', DateTime(2026, 11, 16), 1);
    await repoB.add('a', DateTime(2026, 11, 18), 3);

    final localMap = {
      '2026-11-16': {'a': 2, 'b': 1},
      '2026-11-20': {'a': 5},
    };
    await linker().mergeLocalInto('B', 'anon', localMap);

    final merged = await repoB.load();
    expect(merged['2026-11-16'], {'a': 3, 'b': 1}); // 1+2, b added
    expect(merged['2026-11-18'], {'a': 3}); // untouched
    expect(merged['2026-11-20'], {'a': 5}); // new day
  });

  test('repeated merge from the same anon uid does NOT double', () async {
    final repoB = CloudProgressRepository(db: db, uid: 'B');
    final localMap = {
      '2026-11-16': {'a': 2}
    };
    final l = linker();
    await l.mergeLocalInto('B', 'anon', localMap);
    await l.mergeLocalInto('B', 'anon', localMap); // idempotent guard
    expect((await repoB.load())['2026-11-16'], {'a': 2}); // NOT 4

    // The guard is recorded on the target's meta.
    final meta = await db.doc(FirestoreSchema.metaSchemaPath('B')).get();
    expect((meta.data()!['mergedFrom'] as List), ['anon']);
  });

  test('a different anon uid still merges (guard is per-source)', () async {
    final repoB = CloudProgressRepository(db: db, uid: 'B');
    final l = linker();
    await l.mergeLocalInto('B', 'anon1', {
      '2026-11-16': {'a': 1}
    });
    await l.mergeLocalInto('B', 'anon2', {
      '2026-11-16': {'a': 1}
    });
    expect((await repoB.load())['2026-11-16'], {'a': 2}); // both counted once
  });

  test('deleteUserData removes months/habits/meta of the anon uid', () async {
    final repoAnon = CloudProgressRepository(db: db, uid: 'anon');
    await repoAnon.add('a', DateTime(2026, 11, 16), 1);
    await db.doc(FirestoreSchema.habitDocPath('anon', 'a')).set({'name': 'x'});
    await db.doc(FirestoreSchema.metaSchemaPath('anon')).set({'version': 2});

    await linker().deleteUserData('anon');

    expect((await db.collection(FirestoreSchema.monthsPath('anon')).get()).docs, isEmpty);
    expect((await db.collection(FirestoreSchema.habitsPath('anon')).get()).docs, isEmpty);
    expect((await db.collection('users/anon/meta').get()).docs, isEmpty);
  });
}
