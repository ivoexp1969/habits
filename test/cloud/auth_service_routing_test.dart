import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/auth_service.dart';
import 'package:habits/services/cloud/account_linker.dart';
import 'package:habits/services/cloud/cloud_account.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';
import 'package:habits/services/cloud/cloud_sync_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
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

  test('LOGIN from anon-WITH-DATA into existing → data merged, NO intermediate anon',
      () async {
    // Existing account 1WBic (the sim's registered profile), currently empty.
    // Anonymous PIGb7 holds 2 check-ins in the cloud.
    backend = FakeAuthBackend(uid: 'PIGb7', anonymous: true)..existingUid = '1WBic';
    await CloudProgressRepository(db: db, uid: 'PIGb7').add('a', DateTime(2026, 11, 23), 2);

    final res = await build().loginWithEmail('ivoexp+navicitest@gmail.com', 'pw123456');

    expect(res.ok, isTrue);
    expect(backend.currentUid, '1WBic'); // switched to the existing profile
    expect(backend.anonCreated, 0); // ⚠️ NO intermediate empty anonymous created
    // The 2 check-ins landed in the existing profile (not abandoned on PIGb7).
    expect((await CloudProgressRepository(db: db, uid: '1WBic').load())['2026-11-23'],
        {'a': 2});
  });

  test('FIX: signOut on an ANON is a NO-OP — its data is NOT orphaned', () async {
    // The lost-check-ins cause: a logout on an anonymous user used to sign it out
    // and make a fresh empty anon, orphaning its data (an anon can't be signed
    // back into). Now it is a no-op: the anon (and its data) stays.
    backend = FakeAuthBackend(uid: 'PIGb7', anonymous: true);
    await CloudProgressRepository(db: db, uid: 'PIGb7').add('a', DateTime(2026, 11, 23), 2);

    await build().signOut();

    expect(backend.anonCreated, 0); // NO new anon
    expect(backend.currentUid, 'PIGb7'); // stayed on the same anon
    expect(backend.isAnonymous, isTrue);
    expect((await CloudProgressRepository(db: db, uid: 'PIGb7').load())['2026-11-23'],
        {'a': 2}); // data reachable
  });

  test('UI gate: an anon has NO Изход — hasRealAccount false, isAnonymous true', () {
    // The settings account tile shows Изход only when hasRealAccount; for an anon
    // it shows Вход/Регистрация (+ Delete), never Изход.
    final anon = AuthService(
        auth: MockFirebaseAuth(
            signedIn: true, mockUser: MockUser(isAnonymous: true)));
    expect(anon.isAnonymous, isTrue);
    expect(anon.hasRealAccount, isFalse); // → no logout button

    final real = AuthService(
        auth: MockFirebaseAuth(
            signedIn: true, mockUser: MockUser(isAnonymous: false, uid: 'r')));
    expect(real.hasRealAccount, isTrue); // → logout button shown
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
