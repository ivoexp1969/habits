import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/cloud/account_linker.dart';
import 'package:habits/services/cloud/cloud_identity.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';

/// ЕТАП 2 B3: merge-on-link (credential already in use → add counts).
void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  test('mergeLocalInto adds local counts onto the target account', () async {
    // Target account B already has some progress.
    final repoB = CloudProgressRepository(db: db, uid: 'B');
    await repoB.add('a', DateTime(2026, 11, 16), 1);
    await repoB.add('a', DateTime(2026, 11, 18), 3);

    // The anonymous device's local map (what it accumulated here).
    final localMap = {
      '2026-11-16': {'a': 2, 'b': 1}, // overlaps day+habit with B
      '2026-11-20': {'a': 5}, // new day
    };

    final linker = AccountLinker(
        db: db, identity: CloudIdentity(MockFirebaseAuth(signedIn: true)));
    await linker.mergeLocalInto('B', localMap);

    final merged = await repoB.load();
    expect(merged['2026-11-16'], {'a': 3, 'b': 1}); // 1+2, and b added
    expect(merged['2026-11-18'], {'a': 3}); // untouched
    expect(merged['2026-11-20'], {'a': 5}); // new day added
  });

  test('empty local map merges nothing (no-op, no crash)', () async {
    final repoB = CloudProgressRepository(db: db, uid: 'B');
    await repoB.add('a', DateTime(2026, 11, 16), 2);
    final linker = AccountLinker(
        db: db, identity: CloudIdentity(MockFirebaseAuth(signedIn: true)));
    await linker.mergeLocalInto('B', {});
    expect((await repoB.load())['2026-11-16'], {'a': 2}); // unchanged
  });
  // The full linkOrMerge flow (link → credential-already-in-use → signInWith →
  // mergeLocalInto) is thin orchestration over CloudIdentity (B1, tested) and
  // mergeLocalInto (above); FirebaseAuth's link/credential paths aren't exposed
  // by the mock, so that end-to-end switch is verified on the real two-device
  // test, not here.
}
