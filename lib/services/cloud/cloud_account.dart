import 'package:firebase_auth/firebase_auth.dart';

import '../progress_service.dart' show ProgressMap;
import 'account_linker.dart';
import 'auth_backend.dart';

/// data-model-v2 ЕТАП 2 — the ONE entry the sign-in UI must use, so every path
/// keeps the anonymous uid (and its data) instead of creating a fresh, empty
/// account. Email register/login, Google and Apple all flow through here.
class CloudAccountService {
  CloudAccountService({
    required this.auth,
    required this.linker,
    required this.localMap,
  });

  final AuthBackend auth;
  final AccountLinker linker;
  final Future<ProgressMap> Function() localMap;

  /// Register or sign in with [cred]:
  ///   * anonymous + credential free  → LINK (same uid, data kept) → `linked`;
  ///   * anonymous + credential in use → switch to the existing account and
  ///     merge this device's data (crash-safe, idempotent) → `merged`, or
  ///     `switchedEmptyAnon` when the anon had nothing to merge;
  ///   * not anonymous (flag off / already a real account) → plain sign-in.
  /// [verifyEmail] sends a verification mail after a fresh email link.
  Future<CloudAuthResult> linkOrSignIn(AuthCredential cred,
      {bool verifyEmail = false}) async {
    if (auth.isAnonymous) {
      final map = await localMap();
      final wasEmpty = map.isEmpty;
      final res = await linker.linkOrMerge(cred, map);
      switch (res) {
        case LinkResult.linked:
          if (verifyEmail) await auth.sendEmailVerification();
          return CloudAuthResult.linked;
        case LinkResult.mergedAndSwitched:
          return wasEmpty
              ? CloudAuthResult.switchedEmptyAnon
              : CloudAuthResult.merged;
        case LinkResult.error:
          return CloudAuthResult.error;
      }
    }
    final uid = await auth.signInWith(cred);
    return uid != null ? CloudAuthResult.signedIn : CloudAuthResult.error;
  }

  /// Sign out → a fresh EMPTY anonymous profile. The cloud profile keeps its
  /// data, so signing back in restores it (the UI tells the user this).
  Future<void> signOutToNewAnon() async {
    await auth.signOut();
    await auth.ensureSignedIn();
  }

  /// Delete the profile: the Firestore subtree FIRST (Firestore does not cascade
  /// to subcollections), then the Auth user, then back to a fresh anonymous one.
  Future<void> deleteProfile() async {
    final uid = auth.currentUid;
    if (uid != null) await linker.deleteUserData(uid);
    await auth.deleteCurrentUser();
    await auth.ensureSignedIn();
  }
}

enum CloudAuthResult { linked, merged, switchedEmptyAnon, signedIn, error }
