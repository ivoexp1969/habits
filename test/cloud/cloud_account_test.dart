import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/cloud/account_linker.dart';
import 'package:habits/services/cloud/cloud_account.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth_backend.dart';

/// ЕТАП 2 — the sign-in path keeps the anon uid + data (fixes the new-uid bug);
/// the merge copy comes from the CLOUD repo (so offline-buffered check-ins ride
/// along), not LocalProgressRepository.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  final cred = EmailAuthProvider.credential(email: 'a@b.c', password: 'pw12345');

  CloudAccountService svc(FakeAuthBackend auth) => CloudAccountService(
      auth: auth, linker: AccountLinker(db: db, auth: auth), db: db);

  // A check-in made by [uid] (goes to Firestore — the cloud path, offline-buffered
  // in real life; synchronous in the fake).
  Future<void> checkIn(String uid, int day, String habit, int n) =>
      CloudProgressRepository(db: db, uid: uid)
          .add(habit, DateTime(2026, 11, day), n);

  setUp(() {
    db = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({});
  });

  test('register (free credential) from anon → LINK, same uid + data kept', () async {
    final auth = FakeAuthBackend(uid: 'anon1', anonymous: true);
    await checkIn('anon1', 16, 'a', 2);
    final r = await svc(auth).linkOrSignIn(cred, verifyEmail: true);
    expect(r, CloudAuthResult.linked);
    expect(auth.currentUid, 'anon1'); // uid kept → the check-in stays here
    expect((await CloudProgressRepository(db: db, uid: 'anon1').load())['2026-11-16'],
        {'a': 2});
  });

  test('OFFLINE check-in as anon → register into existing → lands in new profile',
      () async {
    // The target account B exists with its own progress.
    await checkIn('B', 16, 'a', 1);
    // The anonymous user made a check-in (buffered in the cloud cache).
    final auth = FakeAuthBackend(uid: 'anon2', anonymous: true)..existingUid = 'B';
    await checkIn('anon2', 16, 'a', 2);

    final r = await svc(auth).linkOrSignIn(cred);
    expect(r, CloudAuthResult.merged);
    expect(auth.currentUid, 'B');
    // The offline check-in (read from the anon's cloud cache) merged into B.
    expect((await CloudProgressRepository(db: db, uid: 'B').load())['2026-11-16'],
        {'a': 3});
  });

  test('empty anon into existing → switchedEmptyAnon, no merge', () async {
    await checkIn('B', 16, 'a', 5);
    final auth = FakeAuthBackend(uid: 'anon3', anonymous: true)..existingUid = 'B';
    final r = await svc(auth).linkOrSignIn(cred);
    expect(r, CloudAuthResult.switchedEmptyAnon);
    expect((await CloudProgressRepository(db: db, uid: 'B').load())['2026-11-16'],
        {'a': 5});
  });

  test('sign out → a fresh empty anonymous uid', () async {
    final auth = FakeAuthBackend(uid: 'real', anonymous: false);
    await svc(auth).signOutToNewAnon();
    expect(auth.currentUid, isNot('real'));
    expect(auth.isAnonymous, isTrue);
  });

  test('delete profile → Firestore data gone, auth deleted, back to anon', () async {
    await checkIn('real', 16, 'a', 1);
    final auth = FakeAuthBackend(uid: 'real', anonymous: false);
    await svc(auth).deleteProfile();
    expect(auth.deleted, isTrue);
    expect(auth.isAnonymous, isTrue);
    expect((await db.collection('users/real/months').get()).docs, isEmpty);
  });

  test('Google/Apple use the same path → link keeps the uid', () async {
    final auth = FakeAuthBackend(uid: 'anonG', anonymous: true);
    final gcred = GoogleAuthProvider.credential(idToken: 'x', accessToken: 'y');
    final r = await svc(auth).linkOrSignIn(gcred);
    expect(r, CloudAuthResult.linked);
    expect(auth.currentUid, 'anonG');
  });
}
