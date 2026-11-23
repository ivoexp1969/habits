import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/cloud/account_linker.dart';
import 'package:habits/services/cloud/cloud_account.dart';
import 'package:habits/services/cloud/cloud_progress_repository.dart';
import 'package:habits/services/progress_service.dart' show ProgressMap;
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth_backend.dart';

/// ЕТАП 2 — the sign-in path keeps the anon uid + data (fixes the new-uid bug).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  final cred = EmailAuthProvider.credential(email: 'a@b.c', password: 'pw12345');

  CloudAccountService svc(FakeAuthBackend auth, {ProgressMap local = const {}}) =>
      CloudAccountService(
          auth: auth,
          linker: AccountLinker(db: db, auth: auth),
          localMap: () async => local);

  setUp(() {
    db = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({});
  });

  test('register from anon with FREE credential → LINK, SAME uid kept', () async {
    final auth = FakeAuthBackend(uid: 'anon1', anonymous: true);
    final before = auth.currentUid;
    final r = await svc(auth).linkOrSignIn(cred, verifyEmail: true);
    expect(r, CloudAuthResult.linked);
    expect(auth.currentUid, before); // uid unchanged → data stays
    expect(auth.isAnonymous, isFalse); // now a real account
    expect(auth.verificationsSent, 1);
  });

  test('sign in to an EXISTING account → switch + merge (no doubling)', () async {
    // The existing account B already has progress.
    await CloudProgressRepository(db: db, uid: 'B').add('a', DateTime(2026, 11, 16), 1);
    final auth = FakeAuthBackend(uid: 'anon2', anonymous: true)..existingUid = 'B';

    final r = await svc(auth, local: {
      '2026-11-16': {'a': 2}
    }).linkOrSignIn(cred);

    expect(r, CloudAuthResult.merged);
    expect(auth.currentUid, 'B'); // switched to the existing account
    final merged = await CloudProgressRepository(db: db, uid: 'B').load();
    expect(merged['2026-11-16'], {'a': 3}); // 1 + 2, merged once
  });

  test('empty anon signing into existing → switchedEmptyAnon, no merge', () async {
    await CloudProgressRepository(db: db, uid: 'B').add('a', DateTime(2026, 11, 16), 5);
    final auth = FakeAuthBackend(uid: 'anon3', anonymous: true)..existingUid = 'B';
    final r = await svc(auth, local: const {}).linkOrSignIn(cred);
    expect(r, CloudAuthResult.switchedEmptyAnon);
    expect((await CloudProgressRepository(db: db, uid: 'B').load())['2026-11-16'], {'a': 5});
  });

  test('sign out → a fresh empty anonymous uid', () async {
    final auth = FakeAuthBackend(uid: 'real', anonymous: false);
    await svc(auth).signOutToNewAnon();
    expect(auth.currentUid, isNotNull);
    expect(auth.currentUid, isNot('real'));
    expect(auth.isAnonymous, isTrue);
  });

  test('delete profile → Firestore data gone, auth deleted, back to anon', () async {
    await CloudProgressRepository(db: db, uid: 'real').add('a', DateTime(2026, 11, 16), 1);
    final auth = FakeAuthBackend(uid: 'real', anonymous: false);
    await svc(auth).deleteProfile();
    expect(auth.deleted, isTrue);
    expect(auth.isAnonymous, isTrue); // fresh anon afterwards
    // 'real' profile's months are gone.
    final db2 = db;
    final snap = await db2.collection('users/real/months').get();
    expect(snap.docs, isEmpty);
  });

  test('Google/Apple use the same path (credential-agnostic) → link kept', () async {
    final auth = FakeAuthBackend(uid: 'anonG', anonymous: true);
    final gcred = GoogleAuthProvider.credential(idToken: 'x', accessToken: 'y');
    final r = await svc(auth).linkOrSignIn(gcred);
    expect(r, CloudAuthResult.linked);
    expect(auth.currentUid, 'anonG'); // same uid
  });
}
