import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits/services/cloud/cloud_identity.dart';

/// ЕТАП 2 B1: anonymous sign-in on start.
void main() {
  test('ensureSignedIn creates an anonymous user when none', () async {
    final auth = MockFirebaseAuth(); // starts signed out
    final id = CloudIdentity(auth);
    expect(id.isSignedIn, isFalse);
    final uid = await id.ensureSignedIn();
    expect(uid, isNotNull);
    expect(id.isSignedIn, isTrue);
    expect(id.isAnonymous, isTrue);
  });

  test('ensureSignedIn is a no-op when already signed in (keeps the uid)', () async {
    final auth = MockFirebaseAuth(
        signedIn: true, mockUser: MockUser(uid: 'real-uid', isAnonymous: false));
    final id = CloudIdentity(auth);
    final uid = await id.ensureSignedIn();
    expect(uid, 'real-uid');
    expect(id.isAnonymous, isFalse); // a profile user is never disturbed
  });
}
