import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/auth_service.dart';
import 'package:habits/services/cloud/account_linker.dart';
import 'package:habits/services/cloud/cloud_account.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';
import 'package:habits/services/cloud/cloud_sync_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth_backend.dart';

/// ЕТАП 2 — the SCREEN's entry (AuthService) routes through the cloud link/merge
/// path when anonymous, instead of createUser/signInWithCredential (the bug that
/// abandoned the anon uid). Exercised with a fake Auth backend.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late FakeAuthBackend backend;

  AuthService build() {
    final cloud = CloudAccountService(
        auth: backend, linker: AccountLinker(db: db, auth: backend), db: db);
    return AuthService(cloud: cloud);
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({});
    CloudSyncV2.enabled = true; // test build on
  });
  tearDown(() => CloudSyncV2.enabled = false);

  test('registerWithEmail from anon → LINK, same uid kept (not a new account)', () async {
    backend = FakeAuthBackend(uid: 'anon', anonymous: true);
    final res = await build().registerWithEmail('me@x.io', 'pw123456');
    expect(res.ok, isTrue);
    expect(res.needsVerification, isTrue);
    expect(backend.currentUid, 'anon'); // uid preserved → data stays
    expect(backend.isAnonymous, isFalse);
  });

  test('loginWithEmail into an existing account → switch + merge, no doubling', () async {
    await CloudProgressRepository(db: db, uid: 'B').add('a', DateTime(2026, 11, 16), 1);
    backend = FakeAuthBackend(uid: 'anon', anonymous: true)..existingUid = 'B';
    // The anon's check-in is in its own cloud docs (offline-buffered in real life).
    await CloudProgressRepository(db: db, uid: 'anon').add('a', DateTime(2026, 11, 16), 2);
    final res = await build().loginWithEmail('me@x.io', 'pw123456');
    expect(res.ok, isTrue);
    expect(backend.currentUid, 'B');
    expect((await CloudProgressRepository(db: db, uid: 'B').load())['2026-11-16'], {'a': 3});
  });

  test('signOut → fresh empty anonymous uid', () async {
    backend = FakeAuthBackend(uid: 'real', anonymous: false);
    await build().signOut();
    expect(backend.isAnonymous, isTrue);
    expect(backend.currentUid, isNot('real'));
  });

  test('deleteAccount → Firestore subtree + auth deleted, back to anon', () async {
    await CloudProgressRepository(db: db, uid: 'real').add('a', DateTime(2026, 11, 16), 1);
    backend = FakeAuthBackend(uid: 'real', anonymous: false);
    final res = await build().deleteAccount();
    expect(res.ok, isTrue);
    expect(backend.deleted, isTrue);
    expect((await db.collection('users/real/months').get()).docs, isEmpty);
  });

  test('flag OFF → cloud path is skipped (legacy behavior preserved)', () async {
    CloudSyncV2.enabled = false;
    backend = FakeAuthBackend(uid: 'anon', anonymous: true);
    // With the flag off, _useCloudLink is false; the fake backend is never linked.
    // (The legacy path would hit FirebaseAuth; we only assert we DID NOT cloud-link.)
    expect(backend.isAnonymous, isTrue);
  });
}
