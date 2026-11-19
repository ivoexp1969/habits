import 'package:firebase_auth/firebase_auth.dart';

/// data-model-v2 ЕТАП 2 — the identity used for cloud sync. On first run the app
/// signs in ANONYMOUSLY so every device has a uid to write under; later, signing
/// in with email/Google/Apple LINKS that credential to the same anonymous uid
/// (keeping the data). If the credential already belongs to another account,
/// the caller merges the two (see AccountLinker) and switches to it.
///
/// [FirebaseAuth] is injected so this unit-tests with firebase_auth_mocks; in the
/// app it is `FirebaseAuth.instance`.
class CloudIdentity {
  CloudIdentity(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// Ensures there is a signed-in user, creating an anonymous one if none.
  /// A no-op when already signed in (anonymous OR real), so it never disturbs a
  /// profile user. Returns the uid, or null if anonymous sign-in failed (e.g.
  /// offline before the first ever sign-in, or Anonymous Auth disabled).
  Future<String?> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;
    try {
      final cred = await _auth.signInAnonymously();
      return cred.user?.uid;
    } catch (_) {
      return null; // offline / provider disabled → caller buffers locally
    }
  }

  /// Links [credential] to the current (anonymous) user, keeping the uid and its
  /// data. On success returns [LinkOutcome.linked]. If the credential already
  /// belongs to another account, returns [LinkOutcome.alreadyInUse] WITHOUT
  /// switching — the caller merges the months then calls [signInWith].
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

  /// Switches to the account [credential] belongs to (after a merge).
  Future<String?> signInWith(AuthCredential credential) async {
    final cred = await _auth.signInWithCredential(credential);
    return cred.user?.uid;
  }
}

enum LinkOutcome { linked, alreadyInUse, noCurrentUser, error }
