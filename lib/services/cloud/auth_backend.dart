import 'package:firebase_auth/firebase_auth.dart';

/// data-model-v2 ЕТАП 2 — the auth surface the cloud code depends on, abstracted
/// so it unit-tests with a fake (firebase_auth_mocks does not support
/// linkWithCredential, which is the whole point of the anon→account flow).
///
/// On first run the app signs in ANONYMOUSLY; later, registering / signing in
/// with email·Google·Apple LINKS that credential to the same anonymous uid, so
/// the uid and its data are KEPT. If the credential already belongs to another
/// account, [link] reports [LinkOutcome.alreadyInUse] and the caller switches +
/// merges (see AccountLinker).
abstract class AuthBackend {
  String? get currentUid;
  bool get isAnonymous;
  bool get isSignedIn;

  /// Ensures a signed-in user, creating an anonymous one if none. Returns the
  /// uid (null if anonymous sign-in failed — offline / provider disabled).
  Future<String?> ensureSignedIn();

  /// Links [credential] to the current (anonymous) user, keeping the uid.
  Future<LinkOutcome> link(AuthCredential credential);

  /// Switches to the account [credential] belongs to; returns its uid.
  Future<String?> signInWith(AuthCredential credential);

  Future<void> signOut();
  Future<void> deleteCurrentUser();
  Future<void> sendEmailVerification();
}

enum LinkOutcome { linked, alreadyInUse, noCurrentUser, error }

/// Production [AuthBackend] over FirebaseAuth.
class FirebaseAuthBackend implements AuthBackend {
  FirebaseAuthBackend(this._auth);
  final FirebaseAuth _auth;

  @override
  String? get currentUid => _auth.currentUser?.uid;
  @override
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;
  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  Future<String?> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;
    try {
      final cred = await _auth.signInAnonymously();
      return cred.user?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<LinkOutcome> link(AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) return LinkOutcome.noCurrentUser;
    try {
      await user.linkWithCredential(credential);
      return LinkOutcome.linked;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use' ||
          e.code == 'email-already-in-use') {
        return LinkOutcome.alreadyInUse;
      }
      return LinkOutcome.error;
    } catch (_) {
      return LinkOutcome.error;
    }
  }

  @override
  Future<String?> signInWith(AuthCredential credential) async {
    final cred = await _auth.signInWithCredential(credential);
    return cred.user?.uid;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteCurrentUser() async {
    await _auth.currentUser?.delete();
  }

  @override
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }
}
